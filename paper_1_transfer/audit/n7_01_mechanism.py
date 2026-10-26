"""N7, step 1: event-by-event account of how the trial-by-trial exports lost trials.

Supports the Method's account of segmentation and artefact screening and ISSUES.md N7: that a
trial yields an epoch only when its condition trigger falls exactly five samples after its
property trigger (no event at any other lag was exported, and no five-sample event with a kept
parent was lost); how many first-step epochs the semi-automatic artefact step removed, and that
every one of them had been flagged by the criteria; and where the word-onset trigger sits in
each exported epoch. Written on 16 September 2026 as ``mechanism/mechanism_audit.py``, run with
``--all``; moved here with only its input and output paths changed and its exploratory
``--selection`` mode removed.

Everything is read directly (read-only), from Sessions 2, 3, 4 and 6 of the data tree:
  * the Analyzer history (.ehst2, an OLE compound file) with olefile. Nodes are resolved by the
    OLE storage nesting and each storage's own ``Name`` stream, starting from the history path
    written in the export header, because ``FullPath`` strings are NOT unique in these files
    (Reprocess Backups share paths with live nodes, and some histories hold two identically named
    sibling pipelines). When several storages match, every candidate is evaluated and the one
    whose child segments reproduce the export file is used (``n_candidates`` records this).
  * the export .vhdr/.vmrk of every ``{id}_trialbytrial_S{k}_S10{x}`` export (``- Copy`` files are
    compared with the history but not counted as events).
  * the raw recording's .vmrk in ``Raw/`` (for an independent lag measurement).
No EEG sample values are read.

For each export the chain is: feeding node F -> parent segmentation S (on ``S  k``) -> one or more
nodes between S and the export node (Artifact Rejection, sometimes Baseline Correction) -> the
export node T (segmentation on ``S10x``). For every S10x marker in F whose immediately preceding
property marker is this branch's ``S  k`` it records:
    lag                 S10x position - S k position in F (samples)
    parent              index of the S segment whose start equals S k pos + S.MarkerStartPoints
    parent_kept         parent survives every intermediate SegmentTable
    child_fits          T window (S10x pos + T.MarkerStartPoints, T.MarkerSegmentPoints) lies
                        wholly inside the parent window (arithmetic prediction)
    in_T                a T SegmentTable entry maps back to exactly this S10x position
    in_export           the export segment in the same order as that T entry carries exactly the
                        Stimulus markers of F inside the T window, at the same relative positions
                        (None when the export has no .vmrk)
    export_lag          S10x - S k measured inside the export .vmrk segment
    date_residual_us    export New Segment date minus the date computed from F's New Segment

Writes to ``eeg_audit/mechanism/`` (suffixed by the run name, ``all`` or ``only``):
    events_<run>.csv (64,287 rows, 12 MB), seg_nodes_<run>.csv, ar_nodes_<run>.csv, exports_<run>.csv

Usage:
    python n7_01_mechanism.py --all               # every participant-session with tbt exports
    python n7_01_mechanism.py --only 2:1 3:20     # explicit session:participant pairs

Runtime: about 5 minutes for ``--all``.
"""
from __future__ import annotations

import argparse
import datetime as dt
import re
import struct
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path

import numpy as np
import olefile
import pandas as pd

import audit_paths

BASE = audit_paths.eeg_root()
OUT = audit_paths.out_dir('mechanism')
MARKER_GUID = bytes.fromhex('4173ab496f31d0118d7200409505398a')
REFS = ('S  1', 'S  2', 'S  3')
CONDS = ('S101', 'S102', 'S103')
FS = 500.0


# --------------------------------------------------------------------------- history access
class Hist:
    def __init__(self, session: int, stem: str):
        self.path = BASE / f'Session {session}' / 'History' / f'{stem}.ehst2'
        self.ole = olefile.OleFileIO(str(self.path))
        self.entries = self.ole.listdir(streams=True, storages=False)
        self.storages = sorted({tuple(e[:-1]) for e in self.entries}, key=lambda p: (len(p), p))
        self.children = {}
        for st in self.storages:
            if st:
                self.children.setdefault(st[:-1], []).append(st)

    def raw(self, st, s):
        p = '/'.join(list(st) + [s])
        return self.ole.openstream(p).read() if self.ole.exists(p) else None

    def text(self, st, s):
        b = self.raw(st, s)
        return None if b is None else b.decode('utf-8', 'replace').replace('\x00', '')

    def name(self, st):
        return self.text(st, 'Name') if st else (self.text(st, 'FullPath') or '').split('/')[-1]

    def xml(self, st, s='Parameters'):
        t = self.text(st, s)
        if not t or not t.lstrip().startswith('<?xml'):
            return None
        return ET.fromstring(t[t.index('?>') + 2:].strip())

    def resolve(self, history_path: str):
        parts = history_path.split('/')
        cands = [()]
        for name in parts[2:]:
            cands = [c2 for c in cands for c2 in self.children.get(c, []) if self.name(c2) == name]
        return cands

    def segtable(self, st):
        b = self.raw(st, 'SegmentTable')
        return None if b is None else np.frombuffer(b, '<i4').reshape(-1, 2).copy()

    def markers(self, st):
        idx = self.raw(st, 'MarkerIndex')
        if idx is None:
            return None
        arr = np.frombuffer(idx, '<i4').reshape(-1, 5)
        chain = [st[:k] for k in range(len(st), -1, -1) if self.raw(st[:k], 'MarkerIndex') is not None]
        data = {}
        out = []
        for ch, pos, ln, off, up in arr:
            up = int(up)
            if up not in data:
                data[up] = self.raw(chain[up], 'MarkerData') or b''
            d = data[up]
            if d[off:off + 16] != MARKER_GUID:
                raise ValueError(f'no GUID at {off} in {chain[up]}')
            n = struct.unpack_from('<I', d, off + 16)[0]
            body = d[off + 20: off + 20 + n]
            p, f = 0, {}
            while p < len(body):
                tag, size = struct.unpack_from('<II', body, p)
                f[tag] = body[p + 8: p + 8 + size]
                p += 8 + size
            ticks = struct.unpack('<q', f[0x103])[0] if len(f.get(0x103, b'')) == 8 else 0
            out.append(dict(type=f[0x100].decode('utf-8', 'replace'), desc=f.get(0x102, b'').decode('utf-8', 'replace'),
                            pos=int(pos), length=int(ln), channel=int(ch), ticks=ticks))
        return out


def ticks_to_dt(t):
    return dt.datetime(1, 1, 1) + dt.timedelta(microseconds=t // 10)


def parse_date(s):
    return dt.datetime.strptime(s[:14], '%Y%m%d%H%M%S') + dt.timedelta(microseconds=int(s[14:20]))


# --------------------------------------------------------------------------- BrainVision text files
def read_vmrk(path: Path):
    out = []
    for ln in path.read_bytes().decode('utf-8', 'replace').splitlines():
        m = re.match(r'^Mk\d+=(.*)$', ln)
        if m:
            f = m.group(1).split(',')
            out.append(dict(type=f[0], desc=f[1], pos=int(f[2]) - 1, length=int(f[3]),
                            channel=int(f[4]) if len(f) > 4 and f[4] else 0, date=f[5] if len(f) > 5 else ''))
    return out


def read_vhdr_common(path: Path):
    txt = path.read_bytes().decode('utf-8', 'replace')

    def get(k):
        m = re.search(rf'^{k}=(.*)$', txt, re.M)
        return m.group(1).strip() if m else None
    return dict(history_path=re.search(r'history path: (.+)', txt).group(1).strip(),
                data_points=int(get('DataPoints')), seg_points=int(get('SegmentDataPoints') or 0),
                sampling_interval=float(get('SamplingInterval')), marker_file=get('MarkerFile'),
                orientation=get('DataOrientation'), n_channels=int(get('NumberOfChannels')))


# --------------------------------------------------------------------------- node parameters
SEG_TAGS = ['Operation', 'MarkerSegmentIsTimeBased', 'MarkerStartTime', 'MarkerSegmentTime', 'MarkerStartPoints',
            'MarkerSegmentPoints', 'MarkerABE', 'AllowOverlap', 'MarkerSkipBadIntervals', 'FixedSkipBadIntervals',
            'FrameSkipBadIntervals', 'FrameStart', 'FrameEnd', 'ManualSegments', 'DataStorageType', 'CacheOnRequest',
            'MaximumIntervalLength', 'NodePerSegment']


def seg_node(h: Hist, st):
    x = h.xml(st)
    if x is None or x.findtext('Operation') != 'Marker':
        return None
    sel = [(e.findtext('Type'), e.findtext('Description')) for e in x.findall('SelectedMarkers/SelectedMarker')]
    known = set(SEG_TAGS) | {'SelectedMarkers', 'FixedSizeSegmentIsTimeBased', 'FixedSizeOverlapIsTimeBased',
                             'FixedSizeSegmentTime', 'FixedSizeOverlapTime', 'FixedSizeSegmentPoints',
                             'FixedSizeOverlapPoints', 'CompressionResolution'}
    d = {t: x.findtext(t) for t in SEG_TAGS}
    d['selected_markers'] = ';'.join(f'{a}/{b}' for a, b in sel)
    d['all_xml_tags'] = ' '.join(c.tag for c in x)
    d['unknown_tags'] = ';'.join(sorted({c.tag for c in x} - known))
    desc = (h.text(st, 'Description') or '').replace('\r', '')
    m = re.search(r'Start:\s*([-\d.]+) ms, End:\s*([-\d.]+) ms, Length:\s*([-\d.]+) ms', desc)
    d['desc_start_ms'], d['desc_end_ms'], d['desc_len_ms'] = (m.groups() if m else (None, None, None))
    m = re.search(r'Allow overlapped segments\?\s*(\w+)', desc)
    d['desc_allow_overlap'] = m.group(1) if m else None
    m = re.search(r'Skip bad intervals\?\s*(\w+)', desc)
    d['desc_skip_bad'] = m.group(1) if m else None
    m = re.search(r'Reference markers:\s*\n\s*\n((?:[ \t]+\S.*\n)+)', desc)
    d['desc_reference'] = ' | '.join(' '.join(ln.split()) for ln in m.group(1).splitlines() if ln.strip()) if m else None
    m = re.search(r'Advanced Boolean Expression:\s*\n\s*\n\s*(\S.*)', desc)
    d['desc_abe'] = m.group(1).strip() if m else None
    m = re.search(r'Number of segments:\s*(\d+)', h.text(st, 'Description2') or '')
    d['desc2_n_segments'] = int(m.group(1)) if m else None
    tab = h.segtable(st)
    d['n_segtable'] = None if tab is None else len(tab)
    d['version'] = h.text(st, 'Version')
    d['creation_time'] = h.text(st, 'Internal.CreationTime')
    return d


def ar_node(h: Hist, st, parent_markers, own_markers):
    x = h.xml(st)
    d = dict(node=h.name(st), version=h.text(st, 'Version'), creation_time=h.text(st, 'Internal.CreationTime'))
    desc = h.text(st, 'Description') or ''
    d['desc_title'] = desc.strip().splitlines()[0] if desc.strip() else ''
    if x is None:
        return d, set()
    for t in ['GUID', 'Method', 'IndividualChannelMode', 'WriteOnlyMarkers', 'CheckIntervalsInSegments',
              'IntervalsBasedOnTime', 'CheckGradient', 'MaxGradient', 'GrBefore', 'GrAfter', 'CheckDifference',
              'MaxDifference', 'DiIntervalLength', 'DiBefore', 'DiAfter', 'CheckActivity', 'MinActivity',
              'AcIntervalLength', 'AcBefore', 'AcAfter', 'CheckAmplitude', 'MinAmp', 'MaxAmp', 'DefaultInterval']:
        d[t] = x.findtext(t)
    d['all_xml_tags'] = ' '.join(sorted({c.tag for c in x}))
    gi = x.find('GeneralInterval')
    d['GeneralInterval_ms'] = f"{gi.findtext('StartInMS')}+{gi.findtext('LengthInMS')}" if gi is not None else None
    d['n_enabled_channels'] = len(x.findall('Enabled_x0020_Channels'))
    ue = x.findall('UserEditIntervals/BadInterval')
    d['n_user_edit_intervals'] = len(ue)
    d['user_edit_types'] = ' '.join(f'{k}:{v}' for k, v in Counter(b.findtext('Artifact') for b in ue).items())
    d['user_edit_segments0'] = ' '.join(map(str, sorted({int(b.findtext('nSegment')) for b in ue})))
    d['user_edit_whole_segments'] = all(int(b.findtext('nLength')) == 600 and int(b.findtext('nStart')) % 600 == 0 for b in ue) if ue else None
    ai = h.xml(st, 'ArtifactIntervals')
    bis = ai.findall('BadInterval') if ai is not None else []
    d['n_stored_artifact_intervals'] = len(bis)
    d['stored_types'] = ' '.join(f'{k}:{v}' for k, v in Counter(b.findtext('Artifact') for b in bis).items())
    auto_segs = sorted({int(b.findtext('nSegment')) for b in bis if b.findtext('Artifact') != 'Userdefined'})
    d['auto_segments0'] = ' '.join(map(str, auto_segs))
    d2 = h.text(st, 'Description2') or ''
    m = re.search(r'Number of kept segments:\s*(\d+)', d2)
    d['desc2_kept'] = int(m.group(1)) if m else None
    m = re.search(r'Number of removed segments:\s*(\d+)', d2)
    d['desc2_removed'] = int(m.group(1)) if m else None
    m = re.search(r'The following segments have been removed:\s*([\d,\s]+)', d2)
    d['desc2_removed_list1'] = ' '.join(re.findall(r'\d+', m.group(1))) if m else ''
    for art in ['Low Activity', 'Amplitude', 'Difference', 'Gradient', 'Userdefined']:
        m = re.search(rf'^{art}\s+([\d.]+)\s+([\d.]+) %', d2, re.M)
        d[f'stat_s_{art.replace(" ", "")}'] = float(m.group(1)) if m else None
    tab = h.segtable(st)
    d['n_segtable'] = None if tab is None else len(tab)
    removed_by_table = sorted(set(range(len(h.segtable(st[:-1])))) - {int(a) // 600 for a in tab[:, 0]}) if tab is not None and h.segtable(st[:-1]) is not None else []
    d['removed_by_segtable0'] = ' '.join(map(str, removed_by_table))
    d['removed_segments_with_auto_detection'] = len(set(removed_by_table) & set(auto_segs))
    d['kept_segments_with_auto_detection'] = len(set(auto_segs) - set(removed_by_table))
    d['removed_segments_without_user_edit'] = len(set(removed_by_table) - {int(b.findtext('nSegment')) for b in ue})
    d['n_bad_interval_markers_own'] = sum(1 for mk in own_markers if mk['type'] == 'Bad Interval') if own_markers is not None else None
    d['n_markers_parent'] = len(parent_markers) if parent_markers is not None else None
    d['n_markers_own'] = len(own_markers) if own_markers is not None else None
    d['marker_types_own'] = ' '.join(f'{k}:{v}' for k, v in sorted(Counter(mk['type'] for mk in own_markers).items())) if own_markers else ''
    return d, set(auto_segs)


# --------------------------------------------------------------------------- events
def pair_events(markers):
    """S10x markers with the nearest preceding property marker, word ID and sentence ID."""
    stim = sorted((m for m in markers if m['type'] == 'Stimulus'), key=lambda m: m['pos'])
    out, last_ref, last_word, last_sent = [], None, None, None
    for m in stim:
        dsc = m['desc']
        if dsc in REFS:
            last_ref = m
        elif dsc in CONDS:
            out.append(dict(cond=dsc, pos=m['pos'], ref=last_ref['desc'] if last_ref else None,
                            ref_pos=last_ref['pos'] if last_ref else None,
                            word=last_word['desc'] if last_word else None, word_pos=last_word['pos'] if last_word else None,
                            sent=last_sent['desc'] if last_sent else None, sent_pos=last_sent['pos'] if last_sent else None))
        else:
            digits = re.sub(r'\D', '', dsc)
            code = int(digits) if digits else -1
            if 40 <= code <= 99:
                last_word = m
            elif 110 <= code <= 253:
                last_sent = m
    return out


def process_export(session, pid, vh, hd, h: Hist, T, branch, cond, is_copy, raw_lag, exp_dir):
    ev_rows, seg_rows, ar_rows = [], [], []
    chain = [T[:k] for k in range(len(T) + 1)]
    tp = seg_node(h, T)
    S = None
    for st in reversed(chain[:-1]):
        sp = seg_node(h, st)
        if sp is not None and (sp['selected_markers'] or '').startswith('Stimulus/S  '):
            S = st
            break
    sp = seg_node(h, S)
    F = S[:-1]
    mids = chain[len(S) + 1:len(T)]  # nodes strictly between S and T (chain[k] == T[:k])
    base = dict(session=session, participant=pid, export=vh.name, is_copy=is_copy, branch=branch, cond=cond,
                history_file=h.path.name)
    seg_rows.append(dict(base, level='parent', storage='/'.join(S), node=h.name(S), **sp))
    seg_rows.append(dict(base, level='child', storage='/'.join(T), node=h.name(T), **tp))
    fm = h.markers(F)
    sm = h.markers(S)
    start_pts_S, n_S = int(sp['MarkerStartPoints']), int(sp['MarkerSegmentPoints'])
    start_pts_T, n_T = int(tp['MarkerStartPoints']), int(tp['MarkerSegmentPoints'])
    s_tab = h.segtable(S)
    kept = list(range(len(s_tab)))
    auto_segs_by_node = []
    removal_reason = {}  # parent index -> how the node that dropped it recorded the decision
    for st in mids:
        tab = h.segtable(st)
        x = h.xml(st)
        is_ar = x is not None and x.find('Method') is not None
        before = kept
        if tab is not None:
            if np.any(tab[:, 0] % n_S) or np.any(tab[:, 1] != n_S):
                raise RuntimeError(f'{vh.name}: intermediate {h.name(st)} has non-whole segments')
            kept = [kept[int(a) // n_S] for a in tab[:, 0]]
        if is_ar:
            d, autos = ar_node(h, st, h.markers(st[:-1]), h.markers(st))
            ar_rows.append(dict(base, storage='/'.join(st), **d))
            # ArtifactIntervals / UserEditIntervals index the node's input segments
            auto_segs_by_node.append({before[i] for i in autos if i < len(before)})
            ue = {int(b.findtext('nSegment')) for b in x.findall('UserEditIntervals/BadInterval')}
            ai = h.xml(st, 'ArtifactIntervals')
            auto_in = {int(b.findtext('nSegment')) for b in (ai.findall('BadInterval') if ai is not None else [])
                       if b.findtext('Artifact') != 'Userdefined'}
            kept_here = set(kept)
            for i, j in enumerate(before):
                if j not in kept_here:
                    removal_reason[j] = (f'{h.name(st)}: ' + ('Userdefined whole-segment edit' if i in ue else
                                         'no user edit; automatic detection stored' if i in auto_in else
                                         'no user edit; no stored detection'))
        elif tab is not None:
            for j in set(before) - set(kept):
                removal_reason[j] = f'{h.name(st)}: not an Artifact Rejection node'
    kept_set = set(kept)
    removed = sorted(set(range(len(s_tab))) - kept_set)
    t_tab = h.segtable(T)
    t_child_start = [int(s_tab[kept[int(a) // n_S], 0]) + int(a) % n_S for a, _ in t_tab]
    tmk = h.markers(T)
    emk = read_vmrk(exp_dir / hd['marker_file']) if hd['marker_file'] and (exp_dir / hd['marker_file']).exists() else None
    n_file = hd['data_points'] // hd['seg_points']
    exp_segments = []
    if emk is not None:
        for nsm in (mk for mk in emk if mk['type'] == 'New Segment'):
            lo, hi = nsm['pos'], nsm['pos'] + hd['seg_points']
            inside = [mk for mk in emk if lo <= mk['pos'] < hi]
            dk = [(mk['desc'], mk['pos'] - lo) for mk in inside if mk['type'] == 'Stimulus']
            t0 = [mk['pos'] - lo for mk in inside if mk['type'] == 'Time 0']
            refs = [p for dsc, p in dk if dsc == f'S  {branch[1]}']
            cnd = [p for dsc, p in dk if dsc == cond]
            words = [p for dsc, p in dk if re.sub(r'\D', '', dsc) and 40 <= int(re.sub(r'\D', '', dsc)) <= 99]
            exp_segments.append(dict(start=lo, date=nsm['date'], stim=dk, time0=t0[0] if t0 else None,
                                     lag=(cnd[0] - refs[-1]) if refs and cnd else None,
                                     cond_rel=cnd[0] if cnd else None,
                                     word_rel=words[-1] if words else None,
                                     other_types=' '.join(sorted({mk['type'] for mk in inside} - {'Stimulus', 'Time 0', 'New Segment'}))))
    fns = sorted((mk for mk in fm if mk['type'] == 'New Segment'), key=lambda mk: mk['pos'])

    def date_at(pos):
        prev = [mk for mk in fns if mk['pos'] <= pos and mk['ticks']]
        if not prev:
            return None
        p0 = prev[-1]
        return ticks_to_dt(p0['ticks']) + dt.timedelta(microseconds=(pos - p0['pos']) * 1e6 / FS)

    f_stim = sorted(((mk['pos'], mk['desc']) for mk in fm if mk['type'] == 'Stimulus'))
    f_stim_pos = np.array([p for p, _ in f_stim])

    def f_content(cs):
        i0, i1 = np.searchsorted(f_stim_pos, cs), np.searchsorted(f_stim_pos, cs + n_T)
        return [(f_stim[i][1], f_stim[i][0] - cs) for i in range(i0, i1)]

    content_match, date_res = [], []
    for i, cs in enumerate(t_child_start):
        if emk is None or i >= len(exp_segments):
            content_match.append(None)
            date_res.append(None)
            continue
        content_match.append(f_content(cs) == exp_segments[i]['stim'])
        d = date_at(cs)
        date_res.append(None if d is None or not exp_segments[i]['date'] else
                        round((parse_date(exp_segments[i]['date']) - d).total_seconds() * 1e6))
    exp_by_ref = {}
    for i, cs in enumerate(t_child_start):
        exp_by_ref.setdefault(cs - start_pts_T, []).append(i)
    fmt = lambda c: ' '.join(f'{k}:{v}' for k, v in sorted(c.items(), key=lambda kv: str(kv[0])))  # noqa: E731
    ex_row = dict(base, n_T=len(t_tab), n_file=n_file, n_vmrk_segments=len(exp_segments) if emk is not None else None,
                  vmrk_present=emk is not None, n_content_match=sum(1 for c in content_match if c),
                  n_content_mismatch=sum(1 for c in content_match if c is False),
                  date_residual_us=fmt(Counter(date_res)),
                  export_lags=fmt(Counter(s['lag'] for s in exp_segments)),
                  export_time0_rel=fmt(Counter(s['time0'] for s in exp_segments)),
                  export_cond_rel=fmt(Counter(s['cond_rel'] for s in exp_segments)),
                  export_word_rel=fmt(Counter(s['word_rel'] for s in exp_segments)),
                  export_other_marker_types=fmt(Counter(s['other_types'] for s in exp_segments)),
                  n_parents=len(s_tab), parents_removed=len(removed), removed0=' '.join(map(str, removed)),
                  n_bad_interval_markers_F=sum(1 for mk in fm if mk['type'] == 'Bad Interval'),
                  n_bad_interval_markers_S=sum(1 for mk in sm if mk['type'] == 'Bad Interval'),
                  n_bad_interval_markers_mids=sum(sum(1 for mk in (h.markers(st) or []) if mk['type'] == 'Bad Interval') for st in mids),
                  n_bad_interval_markers_T=sum(1 for mk in tmk if mk['type'] == 'Bad Interval'),
                  mids=' > '.join(h.name(st) for st in mids), storage_T='/'.join(T))
    s_start = {int(a): j for j, (a, _) in enumerate(s_tab)}
    bad_F = [(mk['pos'], mk['length']) for mk in fm if mk['type'] == 'Bad Interval']
    for e in pair_events(fm):
        if e['cond'] != cond or e['ref'] != f'S  {branch[1]}':
            continue
        lag = e['pos'] - e['ref_pos']
        ps = e['ref_pos'] + start_pts_S
        j = s_start.get(ps)
        cs = e['pos'] + start_pts_T
        fits = (j is not None) and cs >= ps and cs + n_T <= ps + n_S
        idx = exp_by_ref.get(e['pos'], [])
        in_export = None if emk is None else (bool(idx) and all(content_match[i] for i in idx))
        exp_lag = exp_segments[idx[0]]['lag'] if idx and emk is not None and idx[0] < len(exp_segments) else None
        rl = raw_lag.get(e['pos'])
        ev_rows.append(dict(base, ref_pos=e['ref_pos'], event_pos=e['pos'], lag=lag,
                            word=e['word'], word_to_cond=None if e['word_pos'] is None else e['pos'] - e['word_pos'],
                            sent=e['sent'], sent_to_ref=None if e['sent_pos'] is None else e['ref_pos'] - e['sent_pos'],
                            parent=j, parent_kept=(j in kept_set) if j is not None else None,
                            parent_removal=removal_reason.get(j) if j is not None else None,
                            parent_window_overlaps_bad_interval_in_F=any(b0 < ps + n_S and ps < b0 + bl for b0, bl in bad_F),
                            parent_window_in_recording=ps >= 0,
                            child_fits=fits, child_start_minus_parent_start=cs - ps,
                            child_end_minus_parent_end=(cs + n_T) - (ps + n_S),
                            in_T=bool(idx), n_T_entries=len(idx), in_export=in_export, export_lag=exp_lag,
                            date_residual_us=date_res[idx[0]] if idx else None,
                            parent_has_auto_artifact=any(j in s for s in auto_segs_by_node) if j is not None else False,
                            raw_vmrk_ref=rl[0] if rl else None, raw_vmrk_lag=rl[1] if rl else None))
    paired = {r['event_pos'] for r in ev_rows}
    ex_row['T_entries_not_paired_to_branch_event'] = sum(1 for c in t_child_start if (c - start_pts_T) not in paired)
    # first-bad-sample position: a New Segment (discontinuity) inside the parent window
    ns_pos = np.array(sorted(mk['pos'] for mk in fm if mk['type'] == 'New Segment'))
    for r in ev_rows:
        ps = r['ref_pos'] + start_pts_S
        r['new_segment_inside_parent_window'] = bool(np.any((ns_pos > ps) & (ns_pos < ps + n_S)))
        # windows of alternative single-level segmentations, for n7_03_alternatives.py
        cs = r['event_pos'] + start_pts_T
        r['child_window_overlaps_bad_interval_in_F'] = any(b0 < cs + n_T and cs < b0 + bl for b0, bl in bad_F)
        r['new_segment_inside_child_window'] = bool(np.any((ns_pos > cs) & (ns_pos < cs + n_T)))
        if r['word'] is not None:
            wp = r['event_pos'] - r['word_to_cond']
            ws = wp - 50  # -100 ms at 500 Hz
            r['word_window_overlaps_bad_interval_in_F'] = any(b0 < ws + 600 and ws < b0 + bl for b0, bl in bad_F)
            r['new_segment_inside_word_window'] = bool(np.any((ns_pos > ws) & (ns_pos < ws + 600)))
        r['parent_skip_bad_intervals'] = sp['MarkerSkipBadIntervals'] == 'true'
        r['parent_allow_overlap'] = sp['AllowOverlap'] == 'true'
    score = (ex_row['n_content_match'] == n_file == len(t_tab), ex_row['n_content_match'], -ex_row['n_content_mismatch'])
    return ev_rows, seg_rows, ar_rows, ex_row, score, tuple(t_child_start)


def audit_participant(session: int, pid: str):
    exp_dir = BASE / f'Session {session}' / 'Export'
    vhdrs = sorted(v for v in exp_dir.glob(f'{pid}_trialbytrial_S*_S10*.vhdr')
                   if re.match(rf'^{re.escape(pid)}_trialbytrial_S\d_S10\d( - Copy)?\.vhdr$', v.name))
    E, SG, AR, EX = [], [], [], []
    hist_cache = {}
    raw_vmrk = BASE / f'Session {session}' / 'Raw' / f'{pid}.vmrk'
    raw_lag = {}
    if raw_vmrk.exists():
        for e in pair_events(read_vmrk(raw_vmrk)):
            raw_lag[e['pos']] = (e['ref'], None if e['ref_pos'] is None else e['pos'] - e['ref_pos'])
    pending = []  # (vh, is_copy, branch, cands, results)
    for vh in vhdrs:
        is_copy = ' - Copy' in vh.name
        m = re.match(r'^(.+?)_trialbytrial_(S\d)_(S10\d)', vh.name)
        branch, cond = m.group(2), m.group(3)
        hd = read_vhdr_common(vh)
        stem = hd['history_path'].split('/')[0]
        cands = []
        hdir = BASE / f'Session {session}' / 'History'
        # the history named after the root, plus split files such as "12-continued"; a file only
        # qualifies if its own root node carries the same root name as the export's history path
        for cand in [stem] + sorted(p.stem for p in hdir.glob(f'{stem}-*.ehst2')):
            if not (hdir / f'{cand}.ehst2').exists():
                continue
            if (session, cand) not in hist_cache:
                hist_cache[(session, cand)] = Hist(session, cand)
            hh = hist_cache[(session, cand)]
            if (hh.text((), 'FullPath') or '').split('/')[0] != stem:
                continue
            cands += [(hh, T) for T in hh.resolve(hd['history_path'])]
        if not cands:
            EX.append(dict(session=session, participant=pid, export=vh.name, error='history path not found'))
            continue
        results = [process_export(session, pid, vh, hd, hh, T, branch, cond, is_copy, raw_lag, exp_dir) for hh, T in cands]
        pending.append((vh, is_copy, branch, cands, results))
    # choose one candidate per export. Among candidates that reproduce the export equally well, prefer
    # the pipeline (history file + storage of the node above T) that is the unique reproducer for a
    # sibling export of the same branch; otherwise the most recently created export node.
    unique_parent = {}
    for vh, is_copy, branch, cands, results in pending:
        top = max(r[4] for r in results)
        winners = [i for i, r in enumerate(results) if r[4] == top]
        if len(winners) == 1:
            hh, T = cands[winners[0]]
            unique_parent.setdefault(branch, set()).add((hh.path.name, T[:-1]))
    for vh, is_copy, branch, cands, results in pending:
        top = max(r[4] for r in results)
        winners = [i for i, r in enumerate(results) if r[4] == top]
        rule = 'unique'
        if len(winners) > 1:
            pref = [i for i in winners if (cands[i][0].path.name, cands[i][1][:-1]) in unique_parent.get(branch, set())]
            if len(pref) == 1:
                winners, rule = pref, 'sibling export pipeline'
            else:
                winners = [max(winners, key=lambda i: cands[i][0].text(cands[i][1], 'Internal.CreationTime') or '')]
                rule = 'latest creation time'
        best = winners[0]
        ev, sg, ar, ex, score, starts = results[best]
        ex['n_candidates'] = len(cands)
        ex['candidates'] = ' | '.join(f"{hh.path.name}:{'/'.join(T)}" for hh, T in cands)
        ex['n_candidates_reproducing_export'] = sum(1 for r in results if r[4][0])
        ex['candidates_identical_child_starts'] = len({r[5] for r in results}) == 1
        ex['candidate_rule'] = rule
        EX.append(ex)
        if not is_copy:
            E += ev
            SG += sg
            AR += ar
    for hh in hist_cache.values():
        hh.ole.close()
    return E, SG, AR, EX


def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument('--all', action='store_true')
    g.add_argument('--only', nargs='+')
    a = ap.parse_args()
    if a.only:
        todo, run = [(int(x.split(':')[0]), x.split(':')[1]) for x in a.only], 'only'
    else:
        todo, run = [], 'all'
        for s in audit_paths.SESSIONS:
            pids = sorted({re.match(r'^(\d+)_trialbytrial_', p.name).group(1)
                           for p in (BASE / f'Session {s}' / 'Export').glob('*_trialbytrial_S*_S10*.vhdr')
                           if re.match(r'^(\d+)_trialbytrial_', p.name)}, key=int)
            todo += [(s, p) for p in pids]
    E, S, A, X = [], [], [], []
    for s, p in todo:
        try:
            e, sg, ar, ex = audit_participant(s, p)
        except Exception as exc:  # recorded, not hidden
            X.append(dict(session=s, participant=p, error=repr(exc)))
            print(f'S{s}/{p}: ERROR {exc!r}', flush=True)
            continue
        E += e
        S += sg
        A += ar
        X += ex
        ed = pd.DataFrame(e)
        if len(ed):
            k = ed.parent_kept == True  # noqa: E712
            print(f'S{s}/{p}: events={len(ed)} lag={dict(sorted(Counter(ed.lag).items()))} in_T={int(ed.in_T.sum())} '
                  f'in_export={int((ed.in_export == True).sum())} '  # noqa: E712
                  f'lag5_keptparent_notinT={int(((ed.lag == 5) & k & ~ed.in_T).sum())} '
                  f'lag!=5_inT={int(((ed.lag != 5) & ed.in_T).sum())} '
                  f'candidates={[x.get("n_candidates") for x in ex]}', flush=True)
    OUT.mkdir(parents=True, exist_ok=True)  # made at import; made again in case it was cleared during the run
    pd.DataFrame(E).to_csv(OUT / f'events_{run}.csv', index=False)
    pd.DataFrame(S).to_csv(OUT / f'seg_nodes_{run}.csv', index=False)
    pd.DataFrame(A).to_csv(OUT / f'ar_nodes_{run}.csv', index=False)
    pd.DataFrame(X).to_csv(OUT / f'exports_{run}.csv', index=False)


if __name__ == '__main__':
    main()
