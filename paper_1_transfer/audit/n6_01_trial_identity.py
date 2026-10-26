"""N6, step 1: trial identity of every trial-by-trial export, from the exports and histories.

Supports ISSUES.md N6 and the Method's statement that every exported trial was traced to its
source recording: which recording each export's history starts from (and whether that is the
archived raw file of the same participant-session), which exports share a recording, the
filter and New Reference settings each history records, and how every S10x event of the
branch fared. Written on 16 September 2026 as ``recon/audit_trial_identity.py``; moved here
with only its input and output paths changed.

Reads (read-only), for Sessions 2, 3, 4 and 6 of the data tree (``audit_paths``):
    Export/{id}_trialbytrial_S{k}_S10{x}.vhdr/.vmrk   ("- Copy" files are skipped)
    History/{root}.ehst2 (and split files such as ``12-continued.ehst2``)
    Raw/{id}.vmrk                                      (identity of the history's root recording)

Writes to ``eeg_audit/identity/``:
    audit_trial_identity_wide.csv  one row per export (participant-session x branch x condition)
    audit_trial_identity_all.csv   the same in long format
    audit_lag_events.csv           one row per S10x event in the history (64,287 rows)
These hold recording start times, so they stay in the output store and out of the repository.

For each export the history named in the export header is read, and every S10x of the branch
is accounted for:

    n_events                         S10x markers whose preceding reference marker is S  k, in the
                                     node feeding the parent segmentation ("feeding node")
    lost_before_parent_segmentation  not inside any parent (S k) segment; split into
                                     lost_parent_skip_bad (overlaps a Raw Data Inspection Bad
                                     Interval while the parent segmentation skips bad intervals)
                                     and lost_parent_other (out of range, overlap disallowed, ...)
    lost_to_manual_removal           inside a parent segment removed in Artifact Rejection
    lost_to_lag_rule                 child window does not fit inside its parent segment
    lost_to_bad_interval_skip        fits, but overlaps a Bad Interval marker in the tbt node's
                                     parent while the tbt segmentation skips bad intervals
    unexplained                      remainder (0 in every export)
    exported                         entries of the tbt node's SegmentTable (checked against the
                                     export's own segment count)

The split between lost_to_manual_removal and lost_to_lag_rule is superseded. History nodes are
looked up here by their FullPath string, which is not unique in these files, and for Session 4
of lab ID 16 that lookup reads a July 2024 pipeline instead of the October 2024 one that wrote
the exports (13 events counted as removed by hand that were not). ``n7_01_mechanism.py``
resolves nodes by storage nesting and keeps the node that reproduces the export; the trial-loss
figures are taken from it. The identity columns are unaffected.

Runtime: about 10 minutes on a laptop (one pass over 1,344 exports and 210 histories).
"""
from __future__ import annotations

import argparse
import re
from collections import Counter

import pandas as pd

import audit_paths

audit_paths.use_reconstruction_modules()
from bv_io import read_header, read_markers  # noqa: E402
from history import History  # noqa: E402

BASE = audit_paths.eeg_root()
OUT = audit_paths.out_dir('identity')
REFS = ('S  1', 'S  2', 'S  3')
CONDS = ('S101', 'S102', 'S103')
MAX_LAG = 100  # samples; an S10x further than this from its reference marker is not paired


def sample_dates(markers, fs: float = 500.0):
    """Timestamp Analyzer writes for a segment starting at a sample (see validate.sample_dates)."""
    import datetime as dt
    ns = [(m.pos, dt.datetime.strptime(m.date[:14], '%Y%m%d%H%M%S') + dt.timedelta(microseconds=int(m.date[14:20])))
          for m in markers if m.type == 'New Segment' and m.date]

    def f(pos: int) -> str:
        prev = [t for t in ns if t[0] <= pos]
        if not prev:
            return ''
        p0, d0 = prev[-1]
        d = d0 + dt.timedelta(microseconds=round((pos - p0) * 1e6 / fs))
        return d.strftime('%Y%m%d%H%M%S') + f'{d.microsecond:06d}'
    return f


def seg_params(h: History, path: str) -> dict | None:
    x = h.xml(path)
    if x is None or x.findtext('Operation') != 'Marker':
        return None
    sel = x.find('SelectedMarkers/SelectedMarker')
    return dict(desc=sel.findtext('Description') if sel is not None else None,
                start_ms=float(x.findtext('MarkerStartTime')), len_ms=float(x.findtext('MarkerSegmentTime')),
                start_pts=int(x.findtext('MarkerStartPoints')), len_pts=int(x.findtext('MarkerSegmentPoints')),
                overlap=x.findtext('AllowOverlap') == 'true', skip_bad=x.findtext('MarkerSkipBadIntervals') == 'true',
                abe=x.findtext('MarkerABE') or '')


def find_history(session: int, root_name: str, export_path: str) -> tuple[History, str]:
    """Open the history file containing the export path (handles split files such as 12-continued)."""
    hdir = BASE / f'Session {session}' / 'History'
    cands = [hdir / f'{root_name}.ehst2'] + sorted(p for p in hdir.glob(f'{root_name}*.ehst2') if p.stem != root_name)
    for c in cands:
        if c.exists():
            h = History(c.stem, session=session)
            if export_path in h.by_path:
                return h, c.name
    raise FileNotFoundError(f'no history in {hdir} contains {export_path}')


def amplifier(h: History, root: str) -> tuple[str, str]:
    t = h.text(root, 'RecordingInfos') or h.text(root, 'RecordingInfosW') or ''
    sn = re.search(r'LiveAmp SN:\s*(?:LA-)?([\d-]+)', t)
    rec = re.search(r'BrainVision Recorder\s+\S+\s+-\s+V\.\s*([\d.]+)', t)
    return (sn.group(1) if sn else ''), (rec.group(1) if rec else '')


def iir_nodes(h: History, chain: list[str]) -> list[dict]:
    out = []
    for p in chain:
        d = h.text(p, 'Description') or ''
        if '*** IIR Filters' not in d:
            continue
        x = h.xml(p)
        df = x.find('DefaultFilter')
        item = dict(node=p.split('/')[-1], individual=x.findtext('IndividualFilters') == 'true',
                    complete_cache=x.findtext('CompleteCache') == 'true',
                    low=float(df.findtext('LowCutoffFrequency')) if df.findtext('LowCutoffEnable') == 'true' else None,
                    high=float(df.findtext('HighCutoffFrequency')) if df.findtext('HighCutoffEnable') == 'true' else None,
                    notch=df.findtext('NotchEnable') == 'true')
        if item['individual']:
            item['channel_lows'] = sorted({cf.findtext('LowCutoffFrequency') for cf in x.find('ChannelFilters')})
        out.append(item)
    return out


def paired_events(markers) -> list[tuple]:
    """(ref_desc, cond, ref_pos, event_pos, lag, item_code) for every S10x with a preceding reference."""
    stim = sorted((m for m in markers if m.type == 'Stimulus'), key=lambda m: m.pos)
    out, last_ref, last_item = [], None, None
    for m in stim:
        if m.description in REFS:
            last_ref = m
        elif m.description in CONDS:
            if last_ref is not None and 0 <= m.pos - last_ref.pos <= MAX_LAG:
                out.append((last_ref.description, m.description, last_ref.pos, m.pos, m.pos - last_ref.pos, last_item))
            else:
                out.append((None, m.description, None, m.pos, None, last_item))
        else:
            last_item = m.description
    return out


def audit_export(session: int, vhdr, cache: dict) -> tuple[list[dict], list[dict]]:
    eh = read_header(vhdr)
    ex_path = eh.comment_first_line.split('history path: ', 1)[1].strip()
    m = re.match(r'^(.+?)_trialbytrial_(S\d)_(S10\d)\.vhdr$', vhdr.name)
    pid, branch, cond = m.group(1), m.group(2), m.group(3)
    root_name = ex_path.split('/')[0]
    key = (session, root_name)
    if key not in cache:
        cache[key] = find_history(session, root_name, ex_path)
    h, hfile = cache[key]
    parts = ex_path.split('/')
    chain = ['/'.join(parts[:i]) for i in range(2, len(parts) + 1)]
    T = ex_path
    tp = seg_params(h, T)
    P = h.parent_path(T)
    # parent segmentation: nearest ancestor that is a marker segmentation on S  k
    S = P
    while seg_params(h, S) is None or not (seg_params(h, S)['desc'] or '').startswith('S  '):
        S = h.parent_path(S)
    sp = seg_params(h, S)
    F = h.parent_path(S)
    intermediates = chain[chain.index(S) + 1: chain.index(T)]  # S's children down to P
    L = sp['len_pts']
    exceptions = []
    if tp is None:
        raise RuntimeError(f'{T} is not a marker segmentation')
    if not T.endswith('tbt'):
        exceptions.append('export node is not a "tbt" node')
    extra = [p.split('/')[-1] for p in chain[:chain.index(S)]
             if p.split('/')[-1] not in ('Raw Data', 'Raw Data Inspection', 'New Reference', 'Filters', 'Ocular Correction ICA')]
    if extra:
        exceptions.append('extra nodes before segmentation: ' + ', '.join(extra))
    if any('Baseline' in p.split('/')[-1] for p in intermediates):
        exceptions.append('baseline-corrected branch exported')
    if tp['desc'] != cond:
        exceptions.append(f'tbt node segments on {tp["desc"]}, file named {cond}')
    if sp['desc'] != f'S  {branch[1]}':
        exceptions.append(f'parent segmentation on {sp["desc"]!r}, file named {branch}')
    if sp['abe'] or tp['abe']:
        exceptions.append('advanced Boolean expression used')

    # --- events and lags in the feeding node
    fm = h.markers(F)
    ev = [e for e in paired_events(fm) if e[1] == cond]
    ev_branch = [e for e in ev if e[0] == sp['desc']]
    unpaired = sum(1 for e in ev if e[0] is None)
    lags = Counter(e[4] for e in ev_branch)
    bad_F = [(mk.pos, mk.length) for mk in fm if mk.type == 'Bad Interval']

    # --- parent segments (feeding-node frame) and the parents kept by Artifact Rejection
    s_tab = h.segment_table(S)
    n_S = len(s_tab)
    start_to_parent = {int(a): j for j, (a, _) in enumerate(s_tab)}
    keep = None
    for node in [P] + list(reversed(intermediates[:-1] if intermediates and intermediates[-1] == P else intermediates)):
        tab = h.segment_table(node)
        if len(tab):
            keep = [int(tab[k, 0] // L) for k in (range(len(tab)) if keep is None else keep)]
    removed = sorted(set(range(n_S)) - set(keep)) if keep is not None else []

    # --- export identity from the export file itself (New Segment timestamps), not the history
    n_file = eh.data_points // eh.segment_data_points
    vmrk_path = vhdr.parent / eh.marker_file if eh.marker_file else None
    if vmrk_path is not None and vmrk_path.is_file():
        emk = read_markers(vmrk_path)
        exp_dates = Counter(mk.date for mk in emk if mk.type == 'New Segment')
        datef = sample_dates(fm)
        identity_source = 'export vmrk timestamps'
    else:
        # no marker file: exported child starts from the tbt SegmentTable, mapped to the feeding frame
        t_tab = h.segment_table(T)
        kp = keep if keep is not None else list(range(n_S))
        exp_dates = Counter(str(int(s_tab[kp[int(a) // L], 0] + int(a) % L)) for a in t_tab[:, 0])
        datef = lambda x: str(int(x))  # noqa: E731
        identity_source = 'history tbt SegmentTable (export .vmrk missing)'
        exceptions.append('export .vmrk missing; identity from history')
    pm = h.markers(P)
    bad_P = [(mk.pos, mk.length) for mk in pm if mk.type == 'Bad Interval']

    lost_before = lost_parent_skip_bad = lost_manual = lag_lost = bad_lost = unexplained = 0
    exported_match = exported_from_removed = 0
    matched_dates = Counter()
    for ref, _, ref_pos, pos, lag, _ in ev_branch:
        pstart = ref_pos + sp['start_pts']
        j = start_to_parent.get(pstart)
        cs = pos + tp['start_pts']  # child start, feeding-node frame
        d = datef(cs)
        is_exported = exp_dates[d] - matched_dates[d] > 0
        if is_exported:
            matched_dates[d] += 1
            exported_match += 1
            if j is not None and j in removed:
                exported_from_removed += 1
            continue
        if j is None:
            lost_before += 1
            if sp['skip_bad'] and any(b0 < pstart + L and pstart < b0 + bl for b0, bl in bad_F):
                lost_parent_skip_bad += 1
        elif j in removed:
            lost_manual += 1
        elif cs < pstart or cs + tp['len_pts'] > pstart + L:
            lag_lost += 1
        elif tp['skip_bad'] and bad_P:
            bad_lost += 1  # refined below only if Bad Interval markers exist (never in LESS)
        else:
            unexplained += 1
    unmatched_export_segments = n_file - exported_match
    n_exported_history = len(h.segment_table(T))
    if bad_P:
        exceptions.append(f'{len(bad_P)} Bad Interval markers in the tbt parent (skip bad = {tp["skip_bad"]})')
    if exported_from_removed:
        exceptions.append(f'{exported_from_removed} exported trials lie in parents listed as removed')
    if unmatched_export_segments:
        exceptions.append(f'{unmatched_export_segments} export segments not matched to an event')
    ev_in_S = [e for e in ev_branch if start_to_parent.get(e[2] + sp['start_pts']) is not None]

    root = parts[0] + '/Raw Data'
    sn, rec = amplifier(h, root)
    filt = iir_nodes(h, chain)
    rr = h.text(next(p for p in chain if p.endswith('New Reference')), 'Description') if any(p.endswith('New Reference') for p in chain) else ''
    ar_nodes = [p for p in intermediates + [P] if 'Artifact' in p.split('/')[-1]]
    ar = ar_nodes[-1] if ar_nodes else None
    n_stored = len(h.artifact_intervals(ar)) if ar else None
    n_user = len(h.artifact_intervals(ar, 'Parameters')) if ar else None
    ar_x = h.xml(ar) if ar else None

    # raw-file consistency: history root markers vs Raw/{pid}.vmrk
    raw_vmrk = BASE / f'Session {session}' / 'Raw' / f'{pid}.vmrk'
    raw_match, raw_start, raw_detail = '', '', ''
    hm = h.markers(root)
    root_ns = [x for x in hm if x.type == 'New Segment']
    rec_start = root_ns[0].date if root_ns else ''
    if raw_vmrk.exists():
        rm = read_markers(raw_vmrk)
        rns = [x for x in rm if x.type == 'New Segment']
        raw_start = rns[0].date if rns else ''
        rs = [(x.description, x.pos) for x in rm if x.type == 'Stimulus']
        hs = [(x.description, x.pos) for x in hm if x.type == 'Stimulus']
        raw_match = str(rs == hs)
        if rs != hs:
            if len(rs) == len(hs) and [p for _, p in rs] == [p for _, p in hs]:
                c = Counter((a[0], b[0]) for a, b in zip(hs, rs) if a != b)
                raw_detail = 'same positions; history vs raw codes ' + ', '.join(f'{k[0]!r}->{k[1]!r} x{v}' for k, v in c.items())
            elif rec_start != raw_start:
                raw_detail = f'different recording: history starts {rec_start}, Raw/{pid}.vmrk starts {raw_start}'
            else:
                raw_detail = f'same start, {len(hs)} vs {len(rs)} stimuli, {len(root_ns)} vs {len(rns)} New Segment markers'
            exceptions.append(f'history root markers differ from Raw/{pid}.vmrk: {raw_detail}')
    else:
        raw_match = 'no local vmrk'

    if n_file != n_exported_history:
        exceptions.append(f'export file has {n_file} segments, history tbt node {n_exported_history}')
    if unexplained:
        exceptions.append(f'{unexplained} unexplained')

    wide = dict(
        session=session, participant=pid, history_file=hfile, branch=branch, condition=cond,
        export_file=vhdr.name, export_history_path=ex_path,
        amplifier_sn=sn, recorder_version=rec, raw_vmrk_matches_history=raw_match,
        recording_start_history=rec_start, recording_start_raw_vmrk=raw_start, n_root_new_segments=len(root_ns),
        history_header_path=(h.text(root, 'HeaderPath') or '').rstrip('\x00'),
        n_events_all_refs=len(ev), n_events_unpaired=unpaired, n_events=len(ev_branch),
        lag_distribution=' '.join(f'{k}:{v}' for k, v in sorted(lags.items())),
        n_lag5=lags.get(5, 0),
        parent_window_ms=f'{sp["start_ms"]:g}..{sp["start_ms"] + sp["len_ms"]:g}',
        child_window_ms=f'{tp["start_ms"]:g}..{tp["start_ms"] + tp["len_ms"]:g}',
        windows_standard=(sp['start_ms'], sp['len_ms'], tp['start_ms'], tp['len_ms']) == (-120, 1200, -130, 1200),
        parent_overlap=sp['overlap'], parent_skip_bad=sp['skip_bad'], child_overlap=tp['overlap'], child_skip_bad=tp['skip_bad'],
        n_parent_segments=n_S, parent_segments_removed_manually=len(removed),
        removed_parent_segments=' '.join(map(str, removed)),
        n_events_in_parent_segments=len(ev_in_S),
        lost_before_parent_segmentation=lost_before, lost_parent_skip_bad=lost_parent_skip_bad,
        lost_parent_other=lost_before - lost_parent_skip_bad,
        lost_to_manual_removal=lost_manual, lost_to_lag_rule=lag_lost,
        lost_to_bad_interval_skip=bad_lost, unexplained=unexplained,
        exported=exported_match, exported_in_file=n_file, exported_history_tbt_node=n_exported_history,
        unmatched_export_segments=unmatched_export_segments, exported_from_removed_parents=exported_from_removed,
        export_identity_source=identity_source,
        ar_node=ar.split('/')[-1] if ar else '', ar_method=ar_x.findtext('Method') if ar_x is not None else '',
        ar_write_only_markers=ar_x.findtext('WriteOnlyMarkers') if ar_x is not None else '',
        ar_stored_intervals=n_stored, ar_user_edit_intervals=n_user,
        bad_interval_markers_in_tbt_parent=len(bad_P),
        high_pass_hz=';'.join(f"{f['low']:g}" if f['low'] is not None else 'off' for f in filt),
        low_pass_hz=';'.join(f"{f['high']:g}" if f['high'] is not None else 'off' for f in filt),
        iir_individual_channel_filters=any(f['individual'] for f in filt),
        iir_complete_cache=';'.join(str(f['complete_cache']) for f in filt),
        n_iir_nodes=len(filt),
        implicit_reference_in_new_reference=('implicit reference is included' in (rr or '')),
        exceptions='; '.join(exceptions))
    events = [dict(session=session, participant=pid, branch=branch, amplifier_sn=sn, recorder_version=rec,
                   recording_start=rec_start, ref=e[0], condition=e[1], item_code=e[5], ref_pos=e[2],
                   event_pos=e[3], lag=e[4]) for e in ev_branch]
    return [wide], events


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--sessions', nargs='*', type=int, default=list(audit_paths.SESSIONS))
    ap.add_argument('--redo-failed', action='store_true',
                    help='re-audit only rows marked AUDIT FAILED in the existing outputs and merge')
    a = ap.parse_args()
    redo = None
    if a.redo_failed:
        old = pd.read_csv(OUT / 'audit_trial_identity_wide.csv')
        old_ev = pd.read_csv(OUT / 'audit_lag_events.csv')
        failed = old[old.exceptions.fillna('').str.startswith('AUDIT FAILED')]
        redo = set(zip(failed.session, failed.export_file))
        a.sessions = sorted(failed.session.unique())
    rows, events, cache = [], [], {}
    for s in a.sessions:
        files = sorted((BASE / f'Session {s}' / 'Export').glob('*_trialbytrial_S*_S10*.vhdr'),
                       key=lambda f: (int(re.match(r'\d+', f.name).group()), f.name))
        for f in files:
            if 'Copy' in f.name or (redo is not None and (s, f.name) not in redo):
                continue
            for attempt in range(6):
                try:
                    w, e = audit_export(s, f, cache)
                    break
                except PermissionError as exc:  # transient locks on a synchronised working copy
                    import time
                    time.sleep(2 * (attempt + 1))
                    w, e = [dict(session=s, participant=f.name.split('_')[0], export_file=f.name, exceptions=f'AUDIT FAILED: {exc!r}')], []
                except Exception as exc:  # recorded, not hidden
                    w, e = [dict(session=s, participant=f.name.split('_')[0], export_file=f.name, exceptions=f'AUDIT FAILED: {exc!r}')], []
                    break
            rows += w
            events += e
            print(s, f.name, w[0].get('n_events'), w[0].get('exported'), w[0].get('lost_to_lag_rule'), w[0].get('exceptions'), flush=True)
        cache.clear()
    wide = pd.DataFrame(rows)
    ev_df = pd.DataFrame(events)
    if redo is not None:
        keep = ~old.set_index(['session', 'export_file']).index.isin(list(redo))
        wide = pd.concat([old[keep], wide], ignore_index=True)
        ev_df = pd.concat([old_ev, ev_df], ignore_index=True)
        wide['_n'] = wide.participant.astype(str).str.extract(r'(\d+)')[0].astype(int)
        wide = wide.sort_values(['session', '_n', 'export_file']).drop(columns='_n').reset_index(drop=True)
        ev_df = ev_df.drop_duplicates()
    wide.to_csv(OUT / 'audit_trial_identity_wide.csv', index=False)
    id_cols = ['session', 'participant', 'branch', 'condition']
    long = wide.melt(id_vars=id_cols, var_name='property', value_name='value')
    long.to_csv(OUT / 'audit_trial_identity_all.csv', index=False)
    ev_df.to_csv(OUT / 'audit_lag_events.csv', index=False)


if __name__ == '__main__':
    main()
