"""Settle the on-demand chunk margin and discontinuity handling at 0.1 Hz on unaffected recordings.

Usage::  python validate_margin.py --out DIR ID [ID ...]   (IDs must not be among the nine 1 Hz recordings)

The cluster stage calls ``validate_recording`` through reprocess.py, one recording per task.

Each recording's archived history must show a 0.1 Hz high-pass; the reconstruction uses exactly
the history's settings (no cutoff is changed). For every candidate filter rule the six
trial-by-trial exports are rebuilt and compared sample by sample. Candidates:

* ``decay e=1e-3``: margin = ceil(ln 1e-3 / ln r), r = pole radius of the single-pass high-pass
  section (the hypothesis from the 1 Hz recordings, where it gives 970);
* the same rule with e = 1e-2 and 1e-4;
* fixed multiples: 970 samples (the 1 Hz value), 970 x (1 Hz / 0.1 Hz) = 9,700, and 5/10/15
  time constants of the nominal cutoff (tau = 1/(2 pi fc));
* a scan of margins around the best candidates;
* whole-record filtering (``filter_mode='continuous'``).

Discontinuities are handled either by ignoring New Segment markers (``recording``) or by
treating them as filter boundaries (``new_segment``). Metrics are pooled over all channels and
exports of a recording, and separately over trials whose +/-10,000-sample neighbourhood
contains a New Segment marker.

Writes margin_validation.csv (one row per recording x rule) and margin_validation_trials.csv
(per-trial maximum error for the adopted rule and each block mode).

The rule adopted by Amendment 2 is ``decay e=1e-3`` with the filter restarted at New Segment
markers (row ``decay e=1e-3 / new_segment``; on a recording without such a marker the two
block modes coincide and the row is ``decay e=1e-3``). ``adopted_rule_row`` picks it out.
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
import pandas as pd

import compare
import filters
import paths
from bv_io import read_export
from pipeline import AFFECTED_1HZ, Reconstruction

#: The four Session-3 recordings outside the scope whose 0.1 Hz exports fixed the margin rule
#: (Amendment 2): two ordinary recordings (10, 51) and two with LostSamples discontinuities (58, 59).
MARGIN_IDS = [10, 51, 58, 59]
NEAR = 10_000


def history_cutoffs(pid: int) -> tuple[float, float]:
    from history import History
    from bv_io import read_header
    h = History(pid)
    hp = read_header(paths.export_dir(3) / f'{pid}_trialbytrial_S1_S101.vhdr').comment_first_line.split('history path: ')[1]
    ica = hp.split('/Ocular Correction ICA/')[0] + '/Ocular Correction ICA'
    d = h.xml(h.parent_path(ica)).find('DefaultFilter')
    return float(d.findtext('LowCutoffFrequency')), float(d.findtext('HighCutoffFrequency'))


def evaluate(r: Reconstruction, exports: dict, label: str) -> tuple[dict, list]:
    errs, near_errs, trial_rows = [], [], []
    bounds = [lo for lo, _ in r.blocks[1:]]
    for br in ('S1', 'S2'):
        b = r.branch(br)
        if not b.seg_table_match:
            raise RuntimeError(f'{r.pid} {br}: parent segmentation differs from history')
        for cond in ('S101', 'S102', 'S103'):
            starts, data = r.trials(br, cond, b)
            ex = exports[(br, cond)]
            e = data - ex
            errs.append(e.ravel())
            for k, s in enumerate(starts):
                near = any(s - NEAR <= q <= s + 600 + NEAR for q in bounds)
                d = min((min(abs(q - s), abs(q - s - 600)) for q in bounds), default=None)
                if near:
                    near_errs.append(e[:, k].ravel())
                trial_rows.append(dict(id=int(r.pid), rule=label, branch=br, cond=cond, start=s,
                                       dist_to_new_segment=d, max_abs_err=float(np.abs(e[:, k]).max()),
                                       rmse=float(np.sqrt(np.mean(e[:, k] ** 2)))))
    row = dict(id=int(r.pid), rule=label, margin=r.margin if r.filter_mode == 'on_demand' else None,
               filter_mode=r.filter_mode, block_mode=r.block_mode, n_new_segment_markers=len(bounds))
    row.update(compare.metrics(np.concatenate(errs)))
    row.update(compare.metrics(np.concatenate(near_errs) if near_errs else np.zeros(0), prefix='near_disc_'))
    row['pass'] = bool(row['rmse'] <= 0.001 and row['p9999'] <= 0.002)
    return row, trial_rows


def adopted_rule_row(rows: list[dict]) -> dict:
    """The row of the rule Amendment 2 adopted (see the module docstring)."""
    by = {r['rule']: r for r in rows}
    return by.get('decay e=1e-3 / new_segment') or by['decay e=1e-3']


def validate_recording(pid: int) -> tuple[list[dict], list[dict]]:
    """Every candidate rule on one recording: (rows per rule, per-trial rows)."""
    rows, trials = [], []
    if pid in AFFECTED_1HZ:
        raise PermissionError(f'{pid} is one of the nine affected recordings')
    lo, hi = history_cutoffs(pid)
    if lo != 0.1 or hi != 30.0:
        raise RuntimeError(f'{pid}: history high-pass {lo} Hz / low-pass {hi} Hz, expected 0.1 / 30')
    r = Reconstruction(pid, low_cutoff=lo, high_cutoff=hi, margin=0)
    exports = {}
    for br in ('S1', 'S2'):
        for cond in ('S101', 'S102', 'S103'):
            eh, ex, _ = read_export(r.export_dir / f'{pid}_trialbytrial_{br}_{cond}.vhdr')
            if eh.channel_names != r.names:
                raise RuntimeError('channel order differs from export')
            exports[(br, cond)] = ex
    fs = r.fs
    tau_pts = fs / (2 * math.pi * lo)
    cands = {f'decay e=1e-3': filters.decay_margin(r.sos['hp'], 1e-3),
             f'decay e=1e-2': filters.decay_margin(r.sos['hp'], 1e-2),
             f'decay e=1e-4': filters.decay_margin(r.sos['hp'], 1e-4),
             'fixed 970 (1 Hz value)': 970,
             'fixed 9700 (970 x 1Hz/fc)': 9700,
             'fixed 5 tau': int(round(5 * tau_pts)),
             'fixed 10 tau': int(round(10 * tau_pts)),
             'fixed 15 tau': int(round(15 * tau_pts))}
    hyp = cands['decay e=1e-3']
    for m in (hyp - 50, hyp - 10, hyp - 2, hyp - 1, hyp + 1, hyp + 2, hyp + 10, hyp + 50, 2 * hyp, 3 * hyp):
        cands.setdefault(f'scan {m}', m)
    print(pid, 'history HP', lo, 'candidates', cands, flush=True)
    for label, m in cands.items():
        r.filter_mode, r.block_mode, r.margin = 'on_demand', 'recording', m
        row, tr = evaluate(r, exports, label)
        rows.append(row)
        print({k: row[k] for k in ('id', 'rule', 'margin', 'rmse', 'p9999', 'max', 'near_disc_rmse', 'near_disc_max', 'pass')}, flush=True)
        if label == 'decay e=1e-3':
            trials += tr
    for fm, bm in (('continuous', 'recording'), ('continuous', 'new_segment'), ('on_demand', 'new_segment')):
        if bm == 'new_segment' and len(r.blocks) == 1:
            continue
        r.filter_mode, r.block_mode, r.margin = fm, bm, hyp
        r._continuous = None
        label = f'{"whole-record" if fm == "continuous" else "decay e=1e-3"} / {bm}'
        row, tr = evaluate(r, exports, label)
        rows.append(row)
        if fm == 'on_demand':
            trials += tr
        print({k: row[k] for k in ('id', 'rule', 'margin', 'rmse', 'p9999', 'max', 'near_disc_rmse', 'near_disc_max', 'pass')}, flush=True)
        r._continuous = None
    del r
    return rows, trials


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('ids', nargs='*', type=int, default=MARGIN_IDS)
    ap.add_argument('--out', type=Path, required=True)
    a = ap.parse_args()
    rows, trials = [], []
    for pid in a.ids:
        r, t = validate_recording(pid)
        rows += r
        trials += t
    a.out.mkdir(parents=True, exist_ok=True)
    pd.DataFrame(rows).to_csv(a.out / 'margin_validation.csv', index=False)
    pd.DataFrame(trials).to_csv(a.out / 'margin_validation_trials.csv', index=False)


if __name__ == '__main__':
    main()
