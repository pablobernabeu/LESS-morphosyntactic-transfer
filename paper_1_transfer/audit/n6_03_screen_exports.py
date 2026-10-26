"""N6, step 3: screen every participant-session's export for a stimulus-locked response.

Supports ISSUES.md N6 (items 3 and 3b), protocol Amendment 3 and the Method's statement that
every export was checked for a stimulus-locked response. Written on 16 September 2026 as
``tmp/screen_exports.py``. Two columns were added when it was moved here,
``split_half_r_s101_s102`` and ``loo_grand_average_r``, because the figures N6 and Amendment 3
quote for Session 2 of lab ID 7 (-.07 on the grammatical and ungrammatical trials, and -.02
against the leave-one-out grand average) were computed in the session and not archived. With the
definitions below they come out at -.05 and .01; no variant tried on 3 October 2026 (all
channels, other windows, the grammatical and ungrammatical average) reproduced both quoted
figures. The leave-one-out correlation also separates recordings less sharply than the
split-half: a few recordings with a reliable response correlate near zero with their session's
grand average. The original columns are computed as before; only the text parser is faster
(numpy instead of a Python loop, the same float64 values).

Reads   Export/{id}_trialbytrial_S[123]_S10[123].vhdr and .txt, Sessions 2, 3, 4 and 6
Writes  eeg_audit/identity/screen_exports.csv, one row per participant-session:
    n_trials                    trials over all of the participant-session's exports
    split_half_r                correlation of the odd-trial and even-trial averages over 0-600 ms
                                after the condition marker, baseline-corrected on the samples
                                before it, averaged over O1, O2, Oz, Pz, P7 and P8
    split_half_r_s101_s102      the same on the grammatical and ungrammatical trials only
    loo_grand_average_r         correlation of the participant's average with the average of the
                                other participants' averages in the same session, same channels
                                and window
    peak_uv                     largest absolute posterior amplitude of the average, 80-250 ms
    rms_tp9_plus_tp10, rms_tp9_plus_tp10_plus_fcz
                                reference arithmetic where TP9 and TP10 are exported (Session 2):
                                under the (TP9 + TP10 + 0) / 3 reference with FCz recovered, the
                                three channels sum to zero before ocular correction

Runtime: about 20 minutes (it parses every trial-by-trial text export, about 5 GB).
"""
from __future__ import annotations

import csv
import re

import numpy as np

import audit_paths

OUT = audit_paths.out_dir('identity') / 'screen_exports.csv'
POSTERIOR = ['O1', 'O2', 'Oz', 'Pz', 'P7', 'P8']
FNAME = re.compile(r'^(\d+)_trialbytrial_S[123]_S(10[123])\.vhdr$')


def load(path):
    hdr = open(path, encoding='utf-8', errors='replace').read()
    seg = int(re.search(r'SegmentDataPoints=(\d+)', hdr).group(1))
    chans, rows = [], []
    with open(str(path)[:-5] + '.txt', 'rb') as fh:
        for line in fh:
            parts = line.replace(b',', b'.').split()
            if not parts:
                continue
            chans.append(parts[0].decode('ascii', 'replace'))
            rows.append(np.array(parts[1:], dtype=np.float64))
    x = np.vstack(rows)
    return chans, x.reshape(len(chans), x.shape[1] // seg, seg)


def split_half(xb, post, m):
    odd, even = xb[:, 0::2].mean(axis=1), xb[:, 1::2].mean(axis=1)
    return float(np.mean([np.corrcoef(odd[i, m], even[i, m])[0, 1] for i in post]))


def main():
    rows, averages = [], {}
    for sess in audit_paths.SESSIONS:
        exp_dir = audit_paths.eeg_dir(sess) / 'Export'
        files = [f for f in exp_dir.glob('*_trialbytrial_S*_S10*.vhdr') if FNAME.match(f.name)]
        ids = sorted({int(f.name.split('_')[0]) for f in files})
        for pid in ids:
            xs, conds, chans = [], [], None
            for f in sorted(f for f in files if f.name.startswith(f'{pid}_')):
                try:
                    c, x = load(f)
                except Exception as e:  # recorded, not hidden
                    print('fail', f, e)
                    continue
                if chans is None:
                    chans = c
                if c != chans:
                    common = [k for k in chans if k in c]
                    x = x[[c.index(k) for k in common]]
                    xs = [xx[[chans.index(k) for k in common]] for xx in xs]
                    chans = common
                xs.append(x)
                conds.append(np.full(x.shape[1], int(FNAME.match(f.name).group(2))))
            x = np.concatenate(xs, axis=1)
            cond = np.concatenate(conds)
            t = np.arange(x.shape[2]) * 2 - 130  # ms from the condition marker (child segment -130..1070)
            # reference arithmetic (before any baseline step)
            ref_sum = ref_fcz = np.nan
            if all(k in chans for k in ['TP9', 'TP10', 'FCz']):
                s = x[chans.index('TP9')] + x[chans.index('TP10')]
                ref_sum = float(np.sqrt((s ** 2).mean()))
                ref_fcz = float(np.sqrt(((s + x[chans.index('FCz')]) ** 2).mean()))
            xb = x - x[:, :, t < 0].mean(axis=2, keepdims=True)
            post = [chans.index(k) for k in POSTERIOR if k in chans]
            m = (t >= 0) & (t <= 600)
            r = split_half(xb, post, m)
            r12 = split_half(xb[:, np.isin(cond, (101, 102))], post, m)
            avg = xb.mean(axis=1)
            peak = float(np.abs(avg[post][:, (t >= 80) & (t <= 250)]).max())
            averages[(sess, pid)] = {chans[i]: avg[i, m] for i in post}
            rows.append(dict(session=sess, participant=pid, n_trials=x.shape[1], split_half_r=round(r, 3),
                             split_half_r_s101_s102=round(r12, 3), loo_grand_average_r=np.nan,
                             peak_uv=round(peak, 2), rms_tp9_plus_tp10=round(ref_sum, 4),
                             rms_tp9_plus_tp10_plus_fcz=round(ref_fcz, 4)))
            print(rows[-1], flush=True)
    # each participant-session against the mean of the other participants' averages in its session
    for row in rows:
        mine = averages[(row['session'], row['participant'])]
        others = [v for (s, p), v in averages.items() if s == row['session'] and p != row['participant']]
        rs = [np.corrcoef(mine[ch], np.mean([o[ch] for o in others if ch in o], axis=0))[0, 1] for ch in mine]
        row['loo_grand_average_r'] = round(float(np.mean(rs)), 3)
    with open(OUT, 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print('wrote', OUT)


if __name__ == '__main__':
    main()
