"""Validation entry point: recreate the existing 1 Hz trial-by-trial exports from raw data.

Usage::

    python validate.py [IDs ...] --out DIR [--block-mode recording|new_segment]
                       [--filter-mode on_demand|continuous] [--margin N] [--tag name]

Writes ``metrics_per_file{_tag}.csv``, ``metrics_per_recording{_tag}.csv`` and
``artifact_rejection{_tag}.csv`` to DIR. The cluster stage calls ``validate_id`` through
reprocess.py, which adds the export-writer round trip and the pass record.

For every ID and every export ``{id}_trialbytrial_S{1,2}_S10{1,2,3}`` it

1. rebuilds the S1/S2 segmentation from the history's markers and checks it against the node's
   stored SegmentTable;
2. reruns the artefact-rejection criteria on the reconstructed segments and matches the
   detections with the node's stored ArtifactIntervals (and lists manual UserEditIntervals and
   manually removed segments);
3. rebuilds the trial-by-trial segmentation under three rules and compares each with the stored
   SegmentTable: ``stored`` (skip segments overlapping stored intervals), ``auto`` (skip segments
   overlapping re-detected intervals) and ``removal_only`` (no interval skipping; only the lag
   rule and the segments removed in the Artifact Rejection node). The exported trials are then
   checked against the export marker file (segment count, New Segment timestamps, stimulus
   marker positions);
4. compares samples with the export (RMSE, 99.99th percentile and maximum absolute error), over
   all samples and over samples more than 1 s from a recording edge or discontinuity.

It is run only at the archived 1 Hz high-pass and computes no averages or condition contrasts.
"""
from __future__ import annotations

import argparse
import datetime as dt
from collections import Counter
from pathlib import Path

import numpy as np
import pandas as pd

import artifact_rejection as ar
import compare
import segmentation as sg
from bv_io import read_export
from pipeline import AFFECTED_1HZ, Reconstruction

IDS = sorted(AFFECTED_1HZ)
RMSE_GATE, P9999_GATE = 0.001, 0.002
ARTIFACT_CODE = {'Difference': 'di', 'Gradient': 'gr', 'Low Activity': 'ac', 'LowActivity': 'ac'}
TBT_RULES = ('stored', 'auto', 'removal_only')


# ----------------------------------------------------------------------------- helpers
def parse_date(s: str) -> dt.datetime:
    return dt.datetime.strptime(s[:14], '%Y%m%d%H%M%S') + dt.timedelta(microseconds=int(s[14:20]))


def sample_dates(markers, fs: float):
    """Map a 0-based sample to the timestamp Analyzer writes for a segment starting there.

    Uses the history's New Segment markers (not the raw .vmrk): for ID 65 an Edit Markers node
    moved the 'LostSamples: 3' New Segment marker to position 0, and Analyzer's export times
    are counted from that marker's timestamp. With several New Segment markers at one position
    the last one in the list applies.
    """
    ns = [(m.pos, parse_date(m.date)) for m in markers if m.type == 'New Segment' and m.date]

    def f(pos: int) -> str:
        p0, d0 = [t for t in ns if t[0] <= pos][-1]
        d = d0 + dt.timedelta(microseconds=round((pos - p0) * 1e6 / fs))
        return d.strftime('%Y%m%d%H%M%S') + f'{d.microsecond:06d}'
    return f


def detection_runs(det: list) -> list[tuple]:
    """Runs of consecutive offending positions per (criterion, channel): (crit, ch, first, last)."""
    by = {}
    for crit, ch, a, _ in det:
        by.setdefault((crit, ch), []).append(a)
    out = []
    for (crit, ch), v in sorted(by.items()):
        v = sorted(v)
        first = prev = v[0]
        for a in v[1:]:
            if a != prev + 1:
                out.append((crit, ch, first, prev))
                first = a
            prev = a
        out.append((crit, ch, first, prev))
    return out


def auto_intervals(runs: list[tuple], seg_len: int) -> list[tuple]:
    """Bad intervals as Analyzer stores them for Max-Min detections, per channel.

    Empirical convention: with offending 100-point windows [i, i+99], the stored interval is
    [first window end - 101, last window end + 100] = [first i - 2, last i + 199], clipped to
    the segment, overlapping intervals of one channel merged. All 65 unclipped stored starts
    follow it exactly (for any assumed window length the offset is constant). Of 23 unclipped
    ends, 12 follow it and 11 end one sample earlier; no position, rounding or parity rule
    separated the two groups (the same window position on two channels of one segment gave
    both), so the end is reproduced to +/-1 sample only. Only Max-Min ever fired.
    Returns (crit, ch, start, length).
    """
    by = {}
    for crit, ch, first, last in runs:
        by.setdefault((crit, ch), []).append((max(0, first - 2), min(seg_len - 1, last + 199)))
    out = []
    for (crit, ch), iv in sorted(by.items()):
        iv.sort()
        merged = [list(iv[0])]
        for s, e in iv[1:]:
            if s <= merged[-1][1] + 1:
                merged[-1][1] = max(merged[-1][1], e)
            else:
                merged.append([s, e])
        out += [(crit, ch, s, e - s + 1) for s, e in merged]
    return out


# --------------------------------------------------------------------------- per branch
def validate_branch(r: Reconstruction, br: str):
    b = r.branch(br)
    arn = r.ar_node(br)
    p = ar.ARParams.from_xml(r.h.xml(arn))
    chi = [b.channel_names.index(c) for c in p.channels]
    nseg = len(b.segments)
    seglen = b.segments[0].length
    datef = sample_dates(r.cont_markers, r.fs)

    # --- artefact rejection: automatic re-detection vs stored intervals
    auto = {}
    for i in range(nseg):
        det = ar.detect(b.data[chi, i, :], p, r.fs)
        det = [(c, b.channel_names.index(p.channels[ch]), a, e) for c, ch, a, e in det]  # data-order index
        auto[i] = auto_intervals(detection_runs(det), seglen)
    stored = r.h.artifact_intervals(arn)
    user = r.h.artifact_intervals(arn, 'Parameters')
    auto_list = [(i, g) for i in range(nseg) for g in auto[i]]
    used, exact, end_off, stored_only = set(), 0, Counter(), []
    for s in stored:
        i = s['nSegment']
        ls = s['nStart'] - i * seglen
        code = ARTIFACT_CODE.get(s['Artifact'], s['Artifact'])
        hit = [k for k, (j, g) in enumerate(auto_list)
               if k not in used and j == i and g[0] == code and g[1] == s['nChannel'] and g[2] == ls]
        if hit:
            used.add(hit[0])
            g = auto_list[hit[0]][1]
            end_off[(ls + s['nLength']) - (g[2] + g[3])] += 1
            exact += (s['nLength'] == g[3])
        else:
            stored_only.append(s)
    auto_only = [auto_list[k] for k in range(len(auto_list)) if k not in used]

    ar_tab = r.h.segment_table(arn)
    ar_keep = (ar_tab[:, 0] // seglen).tolist()
    removed = sorted(set(range(nseg)) - set(ar_keep))
    kept_segs = [b.segments[i] for i in ar_keep]
    kept_mks = [b.markers_by_segment[i] for i in ar_keep]
    bad = {'stored': {i: [] for i in range(nseg)}, 'auto': {i: [(g[2], g[3]) for g in auto[i]] for i in range(nseg)}}
    for s in stored + user:
        bad['stored'][s['nSegment']].append((s['nStart'] - s['nSegment'] * seglen, s['nLength']))

    rows = []
    n_flagged_but_exported = 0
    for cond in ('S101', 'S102', 'S103'):
        tn = r.tbt_node(br, cond)
        tx = r.h.xml(tn)
        if tx.find('SelectedMarkers/SelectedMarker').findtext('Description') != cond:
            raise RuntimeError(f'{tn} does not segment on {cond}')
        start_ms, len_ms = float(tx.findtext('MarkerStartTime')), float(tx.findtext('MarkerSegmentTime'))
        hist_tab = r.h.segment_table(tn)
        subs = {}
        for rule in TBT_RULES:
            bbs = [bad[rule][i] for i in ar_keep] if rule in bad else None
            subs[rule] = sg.sub_segments(kept_segs, kept_mks, cond, start_ms, len_ms, r.fs, bbs)
        n_cond = sum(1 for mks in kept_mks for m in mks if m.type == 'Stimulus' and m.description == cond)
        chosen = subs['removal_only']
        n_flagged_but_exported += sum(1 for s in chosen if bad['stored'][ar_keep[s.parent_index]])

        eh, ex, emk = read_export(r.export_dir / f'{r.pid}_trialbytrial_{br}_{cond}.vhdr')
        offsets = np.cumsum([0] + [k.length for k in kept_segs])
        starts_abs = [kept_segs[s.parent_index].start + s.start - offsets[s.parent_index] for s in chosen]
        exp_dates = [m.date for m in emk if m.type == 'New Segment']
        exp_mk = Counter((m.description, m.pos % seglen) for m in emk if m.type == 'Stimulus')
        rec_mk = Counter()
        for s in chosen:
            off = s.start - offsets[s.parent_index]
            rec_mk.update((m.description, m.pos - off) for m in kept_mks[s.parent_index]
                          if m.type == 'Stimulus' and off <= m.pos < off + s.length)
        row = dict(id=int(r.pid), branch=br, cond=cond, export=f'{r.pid}_trialbytrial_{br}_{cond}',
                   n_parent_segments=nseg, parent_table_match=b.seg_table_match,
                   ar_removed_segments=' '.join(map(str, removed)), n_cond_markers_in_kept_parents=n_cond,
                   lost_to_marker_lag=n_cond - len(subs['removal_only']),
                   n_export_segments=ex.shape[1], n_recon_segments=len(chosen),
                   **{f'tbt_table_match_{k}': bool(np.array_equal(sg.table(v), hist_tab)) for k, v in subs.items()},
                   **{f'n_recon_{k}': len(v) for k, v in subs.items()},
                   export_dates_match=[datef(a) for a in starts_abs] == exp_dates,
                   export_markers_match=exp_mk == rec_mk,
                   channel_order_match=eh.channel_names == b.channel_names)
        if row['n_export_segments'] == row['n_recon_segments'] and row['channel_order_match']:
            if any(s.start - offsets[s.parent_index] != 0 or s.length != seglen for s in chosen):
                raise RuntimeError('tbt segment not aligned with its parent segment')
            recon = np.stack([b.data[:, ar_keep[s.parent_index], :] for s in chosen], axis=1)
            if row['tbt_table_match_removal_only']:
                t_starts, t_data = r.trials(br, cond, b)  # the rule a 0.1 Hz run would use
                if t_starts != starts_abs or not np.array_equal(t_data, recon):
                    raise RuntimeError('Reconstruction.trials disagrees with the validation rule')
            err = recon - ex
            edges = [0, r.x.shape[1]] + [lo for lo, _ in r.blocks[1:]]
            pos = np.stack([np.arange(a, a + seglen) for a in starts_abs])
            dist = compare.distance_to_edges(pos, edges)
            far = dist > r.fs
            row.update(compare.metrics(err))
            row.update(compare.metrics(err[:, far], prefix='far_'))
            row['min_dist_to_edge_s'] = float(dist.min() / r.fs)
            ch_rmse = np.sqrt(np.mean(err ** 2, axis=(1, 2)))
            row['worst_channel'] = b.channel_names[int(np.argmax(ch_rmse))]
            row['worst_channel_rmse'] = float(ch_rmse.max())
            t_rmse = np.sqrt(np.mean(err ** 2, axis=(0, 1)))
            row['rmse_first_50'] = float(np.sqrt(np.mean(t_rmse[:50] ** 2)))
            row['rmse_mid'] = float(np.sqrt(np.mean(t_rmse[50:-50] ** 2)))
            row['rmse_last_50'] = float(np.sqrt(np.mean(t_rmse[-50:] ** 2)))
            row['_err'], row['_far'] = err, far
        rows.append(row)

    ar_summary = dict(
        id=int(r.pid), branch=br, n_parent_segments=nseg,
        n_stored_intervals=len(stored), n_auto_intervals=len(auto_list),
        n_stored_matched_auto=len(stored) - len(stored_only), n_matched_same_length=exact,
        end_offset_counts=' '.join(f'{k}:{v}' for k, v in sorted(end_off.items())),
        n_stored_only=len(stored_only), n_auto_only=len(auto_only),
        criteria_auto=' '.join(f'{k}:{v}' for k, v in Counter(g[0] for _, g in auto_list).items()),
        segs_with_stored=' '.join(map(str, sorted({s['nSegment'] for s in stored}))),
        segs_with_auto=' '.join(map(str, sorted({i for i, _ in auto_list}))),
        n_user_edit_intervals=len(user), segs_with_user_edits=' '.join(map(str, sorted({s['nSegment'] for s in user}))),
        ar_removed_segments=' '.join(map(str, removed)),
        n_exported_trials_in_segments_with_stored_intervals=n_flagged_but_exported,
        stored_only_detail='; '.join(f"seg{s['nSegment']} ch{s['nChannel']} {s['Artifact']} {s['nStart'] - s['nSegment'] * seglen}+{s['nLength']}" for s in stored_only),
        auto_only_detail='; '.join(f'seg{i} ch{g[1]} {g[0]} {g[2]}+{g[3]}' for i, g in auto_only))
    return rows, ar_summary


def validate_id(pid, **kw):
    r = Reconstruction(pid, **kw)
    rows, ars = [], []
    for br in ('S1', 'S2'):
        rr, a = validate_branch(r, br)
        rows += rr
        ars.append(a)
    errs = [row.pop('_err') for row in rows if '_err' in row]
    fars = [row.pop('_far') for row in rows if '_far' in row]
    rec = dict(id=int(pid), filter_mode=r.filter_mode, block_mode=r.block_mode, margin=r.margin,
               n_files=len(rows), n_files_compared=len(errs),
               segment_identity_ok=all(x['tbt_table_match_removal_only'] and x['export_dates_match']
                                       and x['export_markers_match'] for x in rows),
               channel_order_ok=all(x['channel_order_match'] for x in rows),
               n_export_segments=sum(x['n_export_segments'] for x in rows),
               n_recon_segments=sum(x['n_recon_segments'] for x in rows))
    if errs:
        allerr = np.concatenate([e.ravel() for e in errs])
        farerr = np.concatenate([e[:, f].ravel() for e, f in zip(errs, fars)])
        rec.update(compare.metrics(allerr))
        rec.update(compare.metrics(farerr, prefix='far_'))
        rec['pass_rmse'] = bool(rec['rmse'] <= RMSE_GATE)
        rec['pass_p9999'] = bool(rec['p9999'] <= P9999_GATE)
        rec['pass'] = bool(rec['pass_rmse'] and rec['pass_p9999'] and rec['segment_identity_ok']
                           and rec['channel_order_ok'] and len(errs) == len(rows))
    return rows, ars, rec


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('ids', nargs='*', type=int, default=IDS)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--block-mode', default='new_segment', choices=['recording', 'new_segment'])
    ap.add_argument('--filter-mode', default='on_demand', choices=['on_demand', 'continuous'])
    ap.add_argument('--margin', type=int, default=None)
    ap.add_argument('--tag', default='')
    a = ap.parse_args()
    all_rows, all_ar, all_rec = [], [], []
    for pid in a.ids:
        rows, ars, rec = validate_id(pid, block_mode=a.block_mode, filter_mode=a.filter_mode, margin=a.margin)
        all_rows += rows
        all_ar += ars
        all_rec.append(rec)
        print({k: rec[k] for k in ('id', 'segment_identity_ok', 'n_files_compared', 'rmse', 'p9999', 'max', 'pass') if k in rec}, flush=True)
    tag = f'_{a.tag}' if a.tag else ''
    a.out.mkdir(parents=True, exist_ok=True)
    pd.DataFrame(all_rows).to_csv(a.out / f'metrics_per_file{tag}.csv', index=False)
    pd.DataFrame(all_ar).to_csv(a.out / f'artifact_rejection{tag}.csv', index=False)
    pd.DataFrame(all_rec).to_csv(a.out / f'metrics_per_recording{tag}.csv', index=False)


if __name__ == '__main__':
    main()
