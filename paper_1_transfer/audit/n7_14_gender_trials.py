"""N7, step 14: trial-level gender-agreement ERP measures and raw-marker lag counts.

First step of the precision projection (n7_14 to n7_20), which supports the Method's estimate of
how little a segmentation tolerant of one sample of trigger jitter would narrow the interval for
the language difference in the gender-agreement effect, and the N7 report's recommendation
against re-exporting every recording (option D). Written on 17 September 2026 as
``gaps/gap1/01_extract_gender_trials.py``; moved here with only its paths changed.

The projection was made before the October refit, so it follows the conventions of that time: the
cluster-level data of the legacy pipeline, and the Session-2 correction c + FCz/2, which was later
replaced (ISSUES.md N8). Its "gstrial" structure (a random intercept per trial and the
by-participant grammaticality x session slope) is the one closest to the model now fitted, which
averages the clusters of a macroregion within each trial and carries that slope (N9).

Reads PRIMARY files only (read-only):
  * Export/{id}_trialbytrial_S1_S10{1,2}.txt/.vmrk, Sessions 2, 3, 4, 6
    (VECTORIZED ASCII, one channel per line, decimal comma, 600 samples per segment).
    Only the 30 region electrodes and FCz are parsed, one line at a time.
  * Raw/{id}*.vmrk, Sessions 2, 3, 4, 6 (continuous-recording marker files).

Replicates the legacy pipeline's conventions (paper_1_transfer/scripts/01_extract_erp_single_trials.R
as of 17 September 2026, the legacy importer data/R_functions/import_trialbytrial_EEG_data.R and _config.R):
  * sample i of a segment is labelled -100 + 2 i ms;
  * baseline = mean over time < 0 (indices 0..49); windows inclusive 200..498, 300..598, 400..898 ms
    (indices 150..299, 200..349, 250..499);
  * region = mean over its electrodes (importer's nine-region map);
  * sentence marker per segment = the export .vmrk Marker-Infos lines matching
    S1[1-9][0-9]|S2[0-4][0-9]|S25[0-3], in order;
  * Session-2 reference correction c + FCz/2 (applied later in R from the FCz means written here).

Outputs (eeg_audit/precision/):
  gender_trials.csv.gz   one row per exported segment x region: session, participant, condition,
                         seg, marker, region, base, w200_500, w300_600, w400_900, and FCz means
                         fcz_base, fcz_200_500, fcz_300_600, fcz_400_900 (all sessions; used for S2 only)
  raw_lag_events.csv.gz  one row per S10x condition marker in the raw .vmrk files: session, participant,
                         raw_file, property marker, condition, sentence marker, lag in samples
  01_log.txt             file-level checks
Runtime: about 5 minutes.
"""
from __future__ import annotations

import gzip
import re
import sys
from pathlib import Path

import numpy as np

import audit_paths

EEG = audit_paths.eeg_root()
HERE = audit_paths.out_dir('precision')
SESSIONS = list(audit_paths.SESSIONS)
REGIONS = {
    'left anterior': ['Fp1', 'F3', 'F7', 'FT9', 'FC5'], 'midline anterior': ['Fz', 'FC1', 'FC2'],
    'right anterior': ['Fp2', 'F4', 'F8', 'FT10', 'FC6'], 'left medial': ['T7', 'C3', 'CP5'],
    'midline medial': ['Cz', 'CP1', 'CP2'], 'right medial': ['T8', 'C4', 'CP6'],
    'left posterior': ['P7', 'P3', 'O1'], 'midline posterior': ['Pz', 'Oz'],
    'right posterior': ['P8', 'P4', 'O2']}
EL2REG = {e: r for r, es in REGIONS.items() for e in es}
WIN = {'base': (0, 50), 'w200_500': (150, 300), 'w300_600': (200, 350), 'w400_900': (250, 500)}
EXPORT_RE = re.compile(r'^(\d+)_trialbytrial_S1_(S10[12])\.txt$')
SENT_RE = re.compile(r'S1[1-9][0-9]|S2[0-4][0-9]|S25[0-3]')   # the importer's regex
LAST3_RE = re.compile(r'.*S(\d{3}).*')                        # gsub('.*S(\\d{3}).*', '\\1')


def export_markers(vmrk: Path) -> tuple[list[str], int]:
    lines = vmrk.read_text(encoding='utf-8', errors='replace').splitlines()
    start = next(i for i, l in enumerate(lines) if '[Marker Infos]' in l)
    info = lines[start:]
    markers = [LAST3_RE.sub(r'\1', l) for l in info if SENT_RE.search(l)]
    nseg = sum(1 for l in info if '=New Segment,' in l)
    return markers, nseg


def window_means(x: np.ndarray) -> dict[str, np.ndarray]:
    cs = np.concatenate([np.zeros((x.shape[0], 1)), np.cumsum(x, axis=1)], axis=1)
    return {k: (cs[:, b] - cs[:, a]) / (b - a) for k, (a, b) in WIN.items()}


def main() -> None:
    log = open(HERE / '01_log.txt', 'w', encoding='utf-8')
    out = gzip.open(HERE / 'gender_trials.csv.gz', 'wt', newline='')
    out.write('session,participant,condition,seg,marker,region,base,w200_500,w300_600,w400_900,'
              'fcz_base,fcz_200_500,fcz_300_600,fcz_400_900\n')
    n_files = 0
    for s in SESSIONS:
        exp_dir = EEG / f'Session {s}' / 'Export'
        for txt in sorted(exp_dir.iterdir()):
            m = EXPORT_RE.match(txt.name)
            if not m:
                continue
            pid, cond = m.group(1), m.group(2)
            if not txt.with_suffix('.vmrk').exists():
                # The importer pairs .txt and .vmrk by an inner join, so it skips such a file too.
                print(f'NO VMRK (skipped, as the importer does) S{s} {txt.name}', file=log)
                continue
            markers, nseg_vmrk = export_markers(txt.with_suffix('.vmrk'))
            nseg = len(markers)
            acc = {r: None for r in REGIONS}
            cnt = {r: 0 for r in REGIONS}
            fcz = None
            with open(txt, 'r', encoding='utf-8', errors='replace') as fh:
                for line in fh:
                    sp = line.find(' ')
                    name = line[:sp].strip()
                    if name not in EL2REG and name != 'FCz':
                        continue
                    vals = np.array(line[sp:].replace(',', '.').split(), dtype=float)
                    if vals.size != nseg * 600:
                        print(f'SIZE MISMATCH S{s} {txt.name} {name}: {vals.size} values, '
                              f'{nseg} markers, {nseg_vmrk} New Segment', file=log)
                        nseg = vals.size // 600
                    arr = vals.reshape(-1, 600)
                    if name == 'FCz':
                        fcz = arr
                        continue
                    r = EL2REG[name]
                    acc[r] = arr.copy() if acc[r] is None else acc[r] + arr
                    cnt[r] += 1
            bad = [r for r in REGIONS if cnt[r] != len(REGIONS[r])]
            if bad:
                print(f'MISSING ELECTRODES S{s} {txt.name}: {bad}', file=log)
                continue
            if nseg != len(markers) or nseg != nseg_vmrk:
                print(f'MARKER/SEGMENT COUNT S{s} {txt.name}: markers {len(markers)}, New Segment '
                      f'{nseg_vmrk}, data segments {nseg}', file=log)
            fz = window_means(fcz) if fcz is not None else None
            if fz is None:
                print(f'NO FCz S{s} {txt.name}', file=log)
            rows = []
            for r in REGIONS:
                wm = window_means(acc[r] / cnt[r])
                for i in range(nseg):
                    mk = markers[i] if i < len(markers) else 'NA'
                    fzv = [fz[k][i] for k in WIN] if fz is not None else [np.nan] * 4
                    rows.append(f'{s},{pid},{cond},{i},{mk},{r},' +
                                ','.join(f'{wm[k][i]:.5f}' for k in WIN) + ',' +
                                ','.join(f'{v:.5f}' for v in fzv))
            out.write('\n'.join(rows) + '\n')
            n_files += 1
            print(f'S{s} {txt.name}: {nseg} segments', file=log, flush=True)
        print('session', s, 'done', file=sys.stderr, flush=True)
    out.close()
    print(f'files processed: {n_files}', file=log)

    # --- Raw marker streams: lag between property marker and condition marker ---------------
    lag = gzip.open(HERE / 'raw_lag_events.csv.gz', 'wt', newline='')
    lag.write('session,participant,raw_file,prop,condition,sentence,word,lag\n')
    stim_re = re.compile(r'^Mk\d+=Stimulus,S\s*(\d+),(\d+),')
    for s in SESSIONS:
        raw_dir = EEG / f'Session {s}' / 'Raw'
        for vm in sorted(raw_dir.glob('*.vmrk')):
            pm = re.match(r'^(\d+)', vm.stem)
            if not pm:
                print(f'RAW NAME UNPARSED S{s} {vm.name}', file=log)
                continue
            ev = []
            for l in vm.read_text(encoding='utf-8', errors='replace').splitlines():
                mm = stim_re.match(l)
                if mm:
                    ev.append((int(mm.group(1)), int(mm.group(2))))
            rows = []
            for j, (code, pos) in enumerate(ev):
                if code in (101, 102, 103) and j >= 1 and ev[j - 1][0] in (1, 2, 3):
                    prop, ppos = ev[j - 1]
                    sent = ev[j - 2][0] if j >= 2 and 110 <= ev[j - 2][0] <= 253 else -1
                    word = ev[j - 3][0] if j >= 3 and 40 <= ev[j - 3][0] <= 99 else -1
                    rows.append(f'{s},{pm.group(1)},{vm.name},S{prop},S{code},{sent},{word},{pos - ppos}')
            if rows:
                lag.write('\n'.join(rows) + '\n')
    lag.close()
    log.close()


if __name__ == '__main__':
    main()
