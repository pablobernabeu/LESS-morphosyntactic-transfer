"""Trigger-rule check of docs/eeg_filter_reprocessing_protocol.md, Amendment 5.

Are the critical words that the five-sample trigger rule discards exchangeable with the ones
it keeps? Within each property, window and macroregion, the check estimates

    D_int = (discarded S102 - S101) - (kept S102 - S101)

on epochs locked to the word-onset trigger, and passes where |D_int| <= 0.91 µV: omitting the
discarded trials shifts the analysed contrast by (discarded share) x D_int, about 0.36 x D_int,
so the bound keeps that shift within 0.33 µV. Nothing here admits a trial to any analysis or
changes a model; a failure is reported as a limitation.

The design is the one the power analysis behind the amendment assumed (ISSUES.md, N7, and
its gap-4 analysis): each recording x property is a unit; within a unit the window mean is
adjusted for the pre-stimulus baseline by a common within-cell slope (the ERP models carry
the baseline as a covariate), and D_int is formed from the adjusted cell means; units are
averaged with equal weight over recordings, and the mean is tested with t on (recordings - 1)
degrees of freedom by two one-sided tests at alpha = .05, i.e. the check passes when the 90%
interval lies inside +-0.91 µV.

Seventeen recordings enter, as the amendment fixes: the nine reprocessed Session-3 records,
whose events reprocess.py wrote as a side output (``trigger_check/<id>_events.npz``), and eight
0.1 Hz recordings rebuilt from the raw data (Session 2 of lab IDs 10, 11, 12 and 20; Session 3
of lab IDs 10, 51, 58 and 59), whose events the ``events`` stage below writes in the same
format (``trigger_check/s<session>_<id>_events.npz``).

``events --task K``   K = 0..7, one comparison recording. Rebuilds it at its own 0.1 Hz from
    the raw data, gates the rebuild against its archived exports under the 1 Hz gate's limits
    (RMSE <= 0.001 µV, 99.99th percentile <= 0.002 µV, identical trials), and only then writes
    its events. Session 2 of lab ID 10 is rebuilt at 0.1 Hz although its history's filter node
    reads 1 Hz: that node was edited after the export was written (Amendment 4), and the gate
    is what shows the export is a 0.1 Hz derivative. Session 2 is rebuilt as the validation of
    16 September 2026 rebuilt it: with the New Reference settings every Session-2 task export
    was written with (S2_EXPORT_REFERENCE), and, for lab ID 12, from its two raw files joined
    end to end (joined_raw()). Neither changes the gate, which still decides whether the
    rebuild is the export.
``analyse``           Reads the seventeen event files and writes the tables. Refuses to run on
    fewer, so the check is computed once, on the set the amendment fixed.

Session-2 data are brought to the linked-mastoid convention of the other sessions as the
importer does (les_p1_s2_rereference() in ../_config.R: subtract a sixth of TP9 + TP10 from
each scalp electrode). Electrode clusters and macroregions are the importer's
(../_eeg_import.R): a macroregion value is the equally weighted mean of its clusters' means.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy import stats

# The reconstruction modules live one level up. This check sits in its own folder because
# reprocess.code_digest() hashes every module of that folder, and the digest is what the
# gate and provenance records of the reprocessing and the recovery were checked against;
# a new module there would stop those records verifying against the current code.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import compare  # noqa: E402
import paths  # noqa: E402
import validate  # noqa: E402
from bv_io import read_header  # noqa: E402
from pipeline import AFFECTED_1HZ, Reconstruction  # noqa: E402
from reprocess import default_out, run_info, software, trigger_events, write_json  # noqa: E402

EIGHT = [(2, 10), (2, 11), (2, 12), (2, 20), (3, 10), (3, 51), (3, 58), (3, 59)]
NINE = sorted(AFFECTED_1HZ)
#: The New Reference settings every Session-2 task export was written with: the implicit
#: reference included in the average and the remaining channels kept, which the validation of
#: 16 September 2026 established on all 63 Session-2 task exports (ISSUES.md N6). Most
#: histories record them in their own text, but S2/10's history was edited after its export
#: was written (Amendment 4), and the channel order its text implies is not the export's, so
#: the settings are passed for every Session-2 recording.
S2_EXPORT_REFERENCE = {'implicit_included': True, 'keep_remaining': True}
#: Session-2 recordings whose history was computed on the raw file followed by a continuation.
S2_CONTINUED = {12: '12-continued'}
HP, LP = 0.1, 30.0
BOUND_UV = 0.91           # |D_int| bound (Amendment 5)
ALPHA = 0.05              # two one-sided tests
PROPERTY = {'S1': 'gender_agreement', 'S2': 'differential_object_marking'}
CONDS = ('S101', 'S102')  # grammatical, ungrammatical; S103 is not analysed
#: Importer clusters (../_eeg_import.R) and the macroregions the ERP models use.
CLUSTERS = {
    'left anterior': ['Fp1', 'F3', 'F7', 'FT9', 'FC5'], 'midline anterior': ['Fz', 'FC1', 'FC2'],
    'right anterior': ['Fp2', 'F4', 'F8', 'FT10', 'FC6'], 'left medial': ['T7', 'C3', 'CP5'],
    'midline medial': ['Cz', 'CP1', 'CP2'], 'right medial': ['T8', 'C4', 'CP6'],
    'left posterior': ['P7', 'P3', 'O1'], 'midline posterior': ['Pz', 'Oz'],
    'right posterior': ['P8', 'P4', 'O2']}
MACROREGIONS = {'lateral': [c for c in CLUSTERS if not c.startswith('midline')],
                'midline': [c for c in CLUSTERS if c.startswith('midline')]}
#: Windows on the word-locked axis, inclusive, as the importer labels them (time 200-498 etc.).
WINDOWS = {'200_500': (200, 498), '300_600': (300, 598), '400_900': (400, 898)}
BASELINE_MS = (-96, -2)   # Amendment 5
EPOCH_MS = (-96, 1096)    # Amendment 5: inside every parent segment
#: The word-identity trigger precedes the property trigger by two serial triggers (~21 ms at
#: the realised ~10.7 ms spacing); offsets outside this range mean a trigger was lost.
WORD_OFFSET_SAMPLES = (-15, -8)
#: A condition trigger follows its property trigger by one serial trigger (5 or 6 samples). A
#: condition marker found much later in the parent segment belongs to another word, so it is
#: not one of this word's events, kept or discarded.
MAX_LAG_SAMPLES = 20


def tc_dir(out: Path) -> Path:
    return out / 'trigger_check'


def events_path(out: Path, session: int, pid: int) -> Path:
    return tc_dir(out) / (f'{pid}_events.npz' if session == 3 and pid in AFFECTED_1HZ
                          else f's{session}_{pid}_events.npz')


def joined_raw(pid: int, session: int, out: Path) -> Path:
    """Directory holding ``<pid>.{eeg,vhdr,vmrk}``: the raw file followed by its continuation.

    History 12 of Session 2 was computed on 12.eeg followed by 12-continued.eeg, its markers
    being those of 12.vmrk and of 12-continued.vmrk shifted by the first file's length (the
    second file's New Segment marks the join). The rebuild reads them joined the same way: the
    two float32 multiplexed files byte for byte, the first file's header and both marker files.
    Both headers must list the same channels, resolutions and sampling interval. It is written
    into the check's own folder, since the data tree is read-only, and rebuilt on every run.
    """
    src, cont = paths.raw_dir(pid, session), S2_CONTINUED[pid]
    dst = tc_dir(out) / 'raw_joined' / f'Session {session}'
    dst.mkdir(parents=True, exist_ok=True)
    a, b = read_header(src / f'{pid}.vhdr'), read_header(src / f'{cont}.vhdr')
    for key in ('n_channels', 'sampling_interval_us', 'channel_names', 'binary_format', 'orientation'):
        if getattr(a, key) != getattr(b, key):
            raise RuntimeError(f'S{session}/{pid}: the continuation header differs in {key}')
    if list(a.resolutions) != list(b.resolutions):
        raise RuntimeError(f'S{session}/{pid}: the continuation header differs in its resolutions')
    n_a = (src / f'{pid}.eeg').stat().st_size // (4 * a.n_channels)
    with open(dst / f'{pid}.eeg', 'wb') as fo:
        for part in (f'{pid}.eeg', f'{cont}.eeg'):
            with open(src / part, 'rb') as fh:
                while chunk := fh.read(1 << 24):
                    fo.write(chunk)
    (dst / f'{pid}.vhdr').write_text((src / f'{pid}.vhdr').read_text(encoding='utf-8', errors='replace'),
                                     encoding='utf-8')
    la = (src / f'{pid}.vmrk').read_text(encoding='utf-8', errors='replace').splitlines()
    lb = (src / f'{cont}.vmrk').read_text(encoding='utf-8', errors='replace').splitlines()
    mks = [ln.split('=', 1)[1] for ln in la if ln.startswith('Mk')]
    for ln in lb:
        if ln.startswith('Mk'):
            f = ln.split('=', 1)[1].split(',')
            f[2] = str(int(f[2]) + n_a)
            mks.append(','.join(f))
    body = [ln for ln in la if not ln.startswith('Mk')] + [f'Mk{i + 1}={m}' for i, m in enumerate(mks)]
    (dst / f'{pid}.vmrk').write_text('\n'.join(body) + '\n', encoding='utf-8')
    return dst


# ------------------------------------------------------------------------ stage 1: events
def events(k: int, out: Path) -> dict:
    session, pid = EIGHT[k]
    kw = dict(session=session, low_cutoff=HP, high_cutoff=LP)
    if session == 2:
        kw['reference_override'] = S2_EXPORT_REFERENCE
        if pid in S2_CONTINUED:
            kw['raw_dir'] = joined_raw(pid, session, out)
    r = Reconstruction(pid, **kw)
    errs, files = [], {}
    branches = sorted({b for b, _ in r.export_nodes})
    ev = {key: [] for key in ('data', 'cond', 'lag', 'kept', 'property_pos', 'preceding', 'branch')}
    for br in branches:
        b = r.branch(br)
        if not b.seg_table_match:
            raise RuntimeError(f'S{session}/{pid} {br}: parent segmentation differs from the history')
        for cond in sorted(c for bb, c in r.export_nodes if bb == br):
            starts, data = r.trials(br, cond, b)   # raises if trial identity differs
            eh, ex, _ = validate.read_export(r.export_dir / f'{pid}_trialbytrial_{br}_{cond}.vhdr')
            if eh.channel_names != r.names:
                raise RuntimeError(f'S{session}/{pid} {br} {cond}: channel order differs from the export')
            m = compare.metrics(data - ex)
            files[f'{br}_{cond}'] = dict(n_trials=len(starts), rmse=m['rmse'], p9999=m['p9999'], max=m['max'])
            errs.append((data - ex).ravel())
        e = trigger_events(r, br, b)
        for key in e:
            ev[key] += e[key]
        ev['branch'] += [br] * len(e['cond'])
    allm = compare.metrics(np.concatenate(errs))
    passed = bool(allm['rmse'] <= validate.RMSE_GATE and allm['p9999'] <= validate.P9999_GATE)
    rec = dict(kind='trigger_check_events', session=session, participant_lab_ID=pid, passed=passed,
               history_high_pass_hz=r.hist_low, rebuilt_high_pass_hz=HP, margin_samples=r.margin,
               reference_override=kw.get('reference_override'),
               raw_files=[f'{pid}.eeg'] + ([f'{S2_CONTINUED[pid]}.eeg'] if 'raw_dir' in kw else []),
               overall=allm, files=files, gates=dict(rmse=validate.RMSE_GATE, p9999=validate.P9999_GATE),
               software=software(), run=run_info())
    write_json(tc_dir(out) / 'gate' / f's{session}_{pid}.json', rec)
    if not passed:
        print(f'[events] S{session}/{pid}: gate FAILED (rmse {allm["rmse"]:.5f}, p9999 {allm["p9999"]:.5f}); '
              'no events written', flush=True)
        return rec
    p = events_path(out, session, pid)
    p.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(p, data=np.stack(ev['data']), channel_names=np.array(r.names),
                        branch=np.array(ev['branch']), cond=np.array(ev['cond']),
                        lag_samples=np.array(ev['lag']), kept_by_rule=np.array(ev['kept']),
                        property_trigger_pos=np.array(ev['property_pos']),
                        preceding_markers=np.array(ev['preceding']),
                        window_ms=np.array([-200, 1150]), sampling_rate=np.array(r.fs))
    rec['events'] = dict(file=p.name, n_events=len(ev['cond']), n_kept_by_rule=int(np.sum(ev['kept'])))
    write_json(tc_dir(out) / 'gate' / f's{session}_{pid}.json', rec)
    return rec


# ----------------------------------------------------------------------- stage 2: analyse
def _word_offset(preceding: str, fs: float) -> tuple[int | None, str]:
    """Offset in samples of the word-identity trigger from the property trigger, or None."""
    marks = [m.rsplit('@', 1) for m in str(preceding).split('; ') if '@' in m]
    pos = sorted(int(p) for _, p in marks)
    if len(pos) != 2:
        return None, f'{len(pos)} stimulus markers in the 60 ms before the property trigger (2 expected)'
    w = pos[0]
    if not WORD_OFFSET_SAMPLES[0] <= w <= WORD_OFFSET_SAMPLES[1]:
        return None, f'word trigger {w} samples before the property trigger'
    return w, ''


def unit_rows(session: int, pid: int, z: np.lib.npyio.NpzFile) -> tuple[list[dict], list[dict]]:
    """Per-trial window and baseline means for one recording, and the events left out."""
    fs = float(z['sampling_rate'])
    names = [str(n) for n in z['channel_names']]
    idx = {n: i for i, n in enumerate(names)}
    win_ms = z['window_ms']
    p0 = int(round(-win_ms[0] * fs / 1000))          # property trigger's index in each event
    data = z['data'].astype(np.float64)                # events x channels x samples
    if session == 2:                                   # les_p1_s2_rereference(), scalp electrodes
        sixth = (data[:, idx['TP9'], :] + data[:, idx['TP10'], :]) / 6
        for c in {e for es in CLUSTERS.values() for e in es}:
            data[:, idx[c], :] -= sixth
    cl = {c: data[:, [idx[e] for e in es], :].mean(axis=1) for c, es in CLUSTERS.items()}
    mr = {m: np.mean([cl[c] for c in cs], axis=0) for m, cs in MACROREGIONS.items()}
    ms = lambda t: int(round(t * fs / 1000))          # noqa: E731
    rows, dropped = [], []
    for i in range(data.shape[0]):
        cond, br = str(z['cond'][i]), str(z['branch'][i])
        if cond not in CONDS:
            continue
        if int(z['lag_samples'][i]) > MAX_LAG_SAMPLES:
            dropped.append(dict(session=session, participant_lab_ID=pid, branch=br, cond=cond,
                                lag=int(z['lag_samples'][i]), reason='condition marker of another word'))
            continue
        w, why = _word_offset(z['preceding_markers'][i], fs)
        if w is None:
            dropped.append(dict(session=session, participant_lab_ID=pid, branch=br, cond=cond,
                                lag=int(z['lag_samples'][i]), reason=why))
            continue
        w0 = p0 + w
        a, b = w0 + ms(EPOCH_MS[0]), w0 + ms(EPOCH_MS[1])
        if a < 0 or b >= data.shape[2]:
            dropped.append(dict(session=session, participant_lab_ID=pid, branch=br, cond=cond,
                                lag=int(z['lag_samples'][i]), reason='epoch runs past the stored window'))
            continue
        row = dict(session=session, participant_lab_ID=pid, branch=br, property=PROPERTY[br], cond=cond,
                   lag=int(z['lag_samples'][i]), kept=bool(z['kept_by_rule'][i]))
        for m, x in mr.items():
            row[f'{m}|base'] = x[i, w0 + ms(BASELINE_MS[0]): w0 + ms(BASELINE_MS[1]) + 1].mean()
            for wn, (lo, hi) in WINDOWS.items():
                row[f'{m}|{wn}'] = x[i, w0 + ms(lo): w0 + ms(hi) + 1].mean()
        rows.append(row)
    return rows, dropped


def unit_estimate(g: pd.DataFrame, col: str, base: str) -> dict | None:
    """Baseline-adjusted D_int and D_main for one unit (recording x property); None if a cell is thin."""
    cells = {(c, k): g[(g.cond == c) & (g.kept == k)] for c in CONDS for k in (True, False)}
    n = {key: len(v) for key, v in cells.items()}
    if min(n.values()) < 2:
        return None
    yc = np.concatenate([v[col].to_numpy() - v[col].mean() for v in cells.values()])
    bc = np.concatenate([v[base].to_numpy() - v[base].mean() for v in cells.values()])
    slope = float(bc @ yc / (bc @ bc))
    bbar = g[base].mean()
    adj = {key: v[col].mean() - slope * (v[base].mean() - bbar) for key, v in cells.items()}
    s2 = float(((yc - slope * bc) ** 2).sum() / (len(yc) - len(cells) - 1))
    d_int = (adj[('S102', False)] - adj[('S101', False)]) - (adj[('S102', True)] - adj[('S101', True)])
    d_main = np.mean([adj[(c, False)] - adj[(c, True)] for c in CONDS])
    return dict(D_int=d_int, var_int=s2 * sum(1 / v for v in n.values()), D_main=d_main, slope=slope,
                trial_sd=np.sqrt(s2), n_kept_S101=n[('S101', True)], n_kept_S102=n[('S102', True)],
                n_disc_S101=n[('S101', False)], n_disc_S102=n[('S102', False)])


def summarise(units: pd.DataFrame, label: str) -> list[dict]:
    out = []
    for (prop, mreg, win), g in units.groupby(['property', 'macroregion', 'window']):
        d = g.D_int.to_numpy()
        k = len(d)
        mean, se = float(d.mean()), float(d.std(ddof=1) / np.sqrt(k))
        t90, t95 = stats.t.ppf(1 - ALPHA, k - 1), stats.t.ppf(1 - ALPHA / 2, k - 1)
        nk = int(g[['n_kept_S101', 'n_kept_S102']].to_numpy().sum())
        nd = int(g[['n_disc_S101', 'n_disc_S102']].to_numpy().sum())
        share = nd / (nk + nd)
        lo90, hi90 = mean - t90 * se, mean + t90 * se
        dm = g.D_main.to_numpy()
        out.append(dict(discarded_set=label, property=prop, macroregion=mreg, window=win, n_recordings=k,
                        n_kept=nk, n_discarded=nd, share_discarded=share, D_int=mean, se=se, df=k - 1,
                        ci90_low=lo90, ci90_high=hi90, ci95_low=mean - t95 * se, ci95_high=mean + t95 * se,
                        bound=BOUND_UV, passes=bool(-BOUND_UV < lo90 and hi90 < BOUND_UV),
                        implied_shift=share * mean, implied_shift_ci95_low=share * (mean - t95 * se),
                        implied_shift_ci95_high=share * (mean + t95 * se),
                        D_main=float(dm.mean()), D_main_se=float(dm.std(ddof=1) / np.sqrt(k))))
    return out


def analyse(out: Path) -> None:
    want = [(3, p) for p in NINE] + EIGHT
    missing = [f'S{s}/{p}' for s, p in want if not events_path(out, s, p).exists()]
    if missing:
        raise SystemExit('Not running the check: it is computed once, on the seventeen recordings '
                         'Amendment 5 names, and these have no event file: ' + ', '.join(missing))
    rows, dropped, inputs = [], [], {}
    for s, p in want:
        f = events_path(out, s, p)
        inputs[f.name] = f.stat().st_size
        with np.load(f) as z:
            r, d = unit_rows(s, p, z)
        rows += r
        dropped += d
    T = pd.DataFrame(rows)
    res = tc_dir(out) / 'results'
    res.mkdir(parents=True, exist_ok=True)
    pd.DataFrame(dropped, columns=['session', 'participant_lab_ID', 'branch', 'cond', 'lag', 'reason']).to_csv(
        res / 'trigger_check_dropped_events.csv', index=False, lineterminator='\n')
    counts = (T.assign(lag_group=np.where(T.kept, 'lag 5 (kept)', np.where(T.lag == 6, 'lag 6', 'other lag')))
               .groupby(['session', 'participant_lab_ID', 'property', 'cond', 'lag_group']).size()
               .unstack('lag_group', fill_value=0).reset_index())
    counts.to_csv(res / 'trigger_check_counts.csv', index=False, lineterminator='\n')
    cells = []
    for label, keep in (('all lags other than 5', lambda d: d), ('lag 6 only', lambda d: d[d.kept | (d.lag == 6)])):
        U = []
        for (s, p, prop), g in keep(T).groupby(['session', 'participant_lab_ID', 'property']):
            for mreg in MACROREGIONS:
                for wn in WINDOWS:
                    e = unit_estimate(g, f'{mreg}|{wn}', f'{mreg}|base')
                    if e is not None:
                        U.append(dict(discarded_set=label, session=s, participant_lab_ID=p, property=prop,
                                      macroregion=mreg, window=wn, **e))
        U = pd.DataFrame(U)
        if label == 'all lags other than 5':
            U.to_csv(res / 'trigger_check_units.csv', index=False, lineterminator='\n')
        cells += summarise(U, label)
    C = pd.DataFrame(cells)
    C.to_csv(res / 'trigger_check_cells.csv', index=False, lineterminator='\n')
    prim = C[C.discarded_set == 'all lags other than 5']
    write_json(res / 'trigger_check.json',
               dict(bound_uV=BOUND_UV, alpha=ALPHA, n_recordings=len(want), n_events_used=len(T),
                    n_events_dropped=len(dropped), n_cells=len(prim), n_cells_passing=int(prim.passes.sum()),
                    inputs=inputs, software=software(), run=run_info()))
    print(prim[['property', 'macroregion', 'window', 'n_recordings', 'D_int', 'ci90_low', 'ci90_high',
                'passes']].round(3).to_string(index=False), flush=True)
    print(f'[analyse] {int(prim.passes.sum())} of {len(prim)} cells pass the +-{BOUND_UV} µV bound', flush=True)


# ------------------------------------------------------------------------------- driver
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('stage', choices=['events', 'analyse', 'ntasks'])
    ap.add_argument('--task', type=int, help='events: 0-7')
    ap.add_argument('--out', type=Path, default=None)
    a = ap.parse_args(argv)
    out = a.out or default_out()
    if a.stage == 'ntasks':
        print(len(EIGHT))
        return
    if a.stage == 'analyse':
        analyse(out)
        return
    if a.task is None or not 0 <= a.task < len(EIGHT):
        raise SystemExit(f'--task must be 0..{len(EIGHT) - 1}')
    s, p = EIGHT[a.task]
    print(f'[events] task {a.task}: S{s}/{p} -> {out}', flush=True)
    rec = events(a.task, out)
    print(f'[events] S{s}/{p}: {"PASS" if rec["passed"] else "FAIL"}', flush=True)
    sys.exit(0 if rec['passed'] else 3)


if __name__ == '__main__':
    main()
