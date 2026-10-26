"""N6, step 4: do two exports that share event times also share their EEG?

Supports ISSUES.md N6 items 2 and 3 and protocol Amendment 2. The identity audit (n6_01) found
two pairs of participant-sessions whose histories start from the same recording or marker file:
Session 3 of lab IDs 48 and 58, and Session 6 and Session 4 of lab ID 5. This step pairs their
exported trials by the New Segment time stamp each export's marker file carries, and correlates
the paired trials' EEG at Pz. Trials cut from the same EEG correlate highly even after different
processing; trials that only share event times do not. As a control, each trial is also
correlated with the partner of the next time stamp, a pairing that shares neither events nor EEG.
The 16 September figures (all 198 time stamps shared, median r = .90 for 48/58; r = .00 for
5's Session 6 against its Session 4) were computed in the session and not archived. This script
was written when the audit was moved into the repository, as their reproducible source; on
3 October 2026 it gave 198 of 198 and a median of .91 for 48/58, and 183 of 184 paired trials
with a median of -.03 for lab ID 5.

Reads   Export/{id}_trialbytrial_S{k}_S10{x}.vhdr/.vmrk/.txt of the four participant-sessions
Writes  eeg_audit/identity/duplicate_pairs.csv, one row per pair and condition file plus a
        pooled row per pair: trials in each export, trials paired by time stamp, and the median
        (and quartiles) of the paired and control correlations

Runtime: under a minute.
"""
from __future__ import annotations

import re

import numpy as np
import pandas as pd

import audit_paths

PAIRS = [((3, 48), (3, 58)), ((6, 5), (4, 5))]
CHANNEL = 'Pz'


def read_export(session: int, pid: int, branch: str, cond: str):
    """Pz trials (trials x samples) and the New Segment time stamp of each, or None."""
    base = audit_paths.eeg_dir(session) / 'Export' / f'{pid}_trialbytrial_{branch}_{cond}'
    vhdr, vmrk, txt = (base.with_suffix(s) for s in ('.vhdr', '.vmrk', '.txt'))
    if not (vhdr.exists() and vmrk.exists() and txt.exists()):
        return None
    seg = int(re.search(r'SegmentDataPoints=(\d+)', vhdr.read_text(encoding='utf-8', errors='replace')).group(1))
    dates = []
    for ln in vmrk.read_text(encoding='utf-8', errors='replace').splitlines():
        m = re.match(r'^Mk\d+=New Segment,[^,]*,\d+,\d+,-?\d+,(\d+)', ln)
        if m:
            dates.append(m.group(1))
    with open(txt, 'rb') as fh:
        for line in fh:
            parts = line.replace(b',', b'.').split()
            if parts and parts[0].decode('ascii', 'replace') == CHANNEL:
                x = np.array(parts[1:], dtype=np.float64)
                break
        else:
            return None
    x = x.reshape(-1, seg)
    if len(dates) != len(x):
        raise RuntimeError(f'{base.name}: {len(dates)} New Segment markers, {len(x)} segments')
    return x, dates


def corr_rows(a, b):
    a = a - a.mean(axis=1, keepdims=True)
    b = b - b.mean(axis=1, keepdims=True)
    return (a * b).sum(axis=1) / np.sqrt((a * a).sum(axis=1) * (b * b).sum(axis=1))


def main():
    rows = []
    for (sa, pa), (sb, pb) in PAIRS:
        pooled_r, pooled_c, n_a, n_b, n_pair = [], [], 0, 0, 0
        for branch in ('S1', 'S2', 'S3'):
            for cond in ('S101', 'S102', 'S103'):
                A, B = read_export(sa, pa, branch, cond), read_export(sb, pb, branch, cond)
                if A is None or B is None:
                    continue
                (xa, da), (xb, db) = A, B
                where_b = {d: i for i, d in enumerate(db)}
                ia = [i for i, d in enumerate(da) if d in where_b]
                ib = [where_b[da[i]] for i in ia]
                r = corr_rows(xa[ia], xb[ib]) if ia else np.array([])
                # control: the partner of the next paired time stamp
                c = corr_rows(xa[ia], xb[np.roll(ib, 1)]) if len(ia) > 1 else np.array([])
                rows.append(dict(pair=f'S{sa}/{pa} vs S{sb}/{pb}', export=f'{branch}_{cond}', n_a=len(da), n_b=len(db),
                                 n_paired=len(ia), median_r=np.median(r) if len(r) else np.nan,
                                 median_r_control=np.median(c) if len(c) else np.nan))
                pooled_r.append(r)
                pooled_c.append(c)
                n_a += len(da)
                n_b += len(db)
                n_pair += len(ia)
        r, c = np.concatenate(pooled_r), np.concatenate(pooled_c)
        rows.append(dict(pair=f'S{sa}/{pa} vs S{sb}/{pb}', export='all', n_a=n_a, n_b=n_b, n_paired=n_pair,
                         median_r=np.median(r), q25_r=np.quantile(r, .25), q75_r=np.quantile(r, .75),
                         median_r_control=np.median(c), q25_r_control=np.quantile(c, .25),
                         q75_r_control=np.quantile(c, .75)))
    out = pd.DataFrame(rows)
    out.to_csv(audit_paths.out_dir('identity') / 'duplicate_pairs.csv', index=False)
    print(out.round(3).to_string(index=False))


if __name__ == '__main__':
    main()
