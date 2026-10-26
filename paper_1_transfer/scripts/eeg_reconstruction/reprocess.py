"""Cluster entry point for the 0.1 Hz reprocessing of the nine Session-3 records.

Implements docs/eeg_filter_reprocessing_protocol.md (Amendments 1, 2 and 5) as three stages,
each fail-closed, run by paper_1_transfer/hpc/00e_reprocess_eeg.slurm (one array task per
recording) and 00f_assemble_eeg_overlay.slurm:

``validate --task K``   K = 0..12. Tasks 0-8 rebuild the archived 1 Hz exports of one of the
    nine records (validate.py) and push the rebuild through the export writer and back, so
    the files and not only the arrays are checked. Tasks 9-12 rebuild the 0.1 Hz exports of
    one of the four recordings that fixed the filter-margin rule (validate_margin.py). Each
    writes ``validation/<kind>/<id>/gate.json``.
``reprocess --task K``  K = 0..8. Refuses to run unless all 13 gates exist, passed, and were
    produced by this exact code (same digest). Rebuilds the record at 0.1 Hz with the adopted
    margin rule, keeps exactly the trials of the 1 Hz exports (trial identity is checked
    against the history and against the legacy marker files), writes the six exports to
    ``staging/`` and a provenance record to ``provenance/<id>.json``. As a side output for
    the trigger-rule check of Amendment 5 it writes ``trigger_check/<id>_events.npz``.
``assemble``            Checks all nine provenance records, copies the staged files into the
    overlay the importer reads (``data_derived/eeg_overlay``), and writes the provenance
    manifest and a candidate admission manifest for paper_1_transfer/eeg_overlay_manifest.csv.

Nothing here computes a condition average, a contrast or a model: the protocol forbids
inspecting 0.1 Hz outputs before the analyses are run from the accepted overlay.

Outputs live under ``$LES_STORE/paper_1_transfer/data_derived/eeg_reprocessing`` (``--out``
overrides it); the overlay is ``$LES_STORE/paper_1_transfer/data_derived/eeg_overlay``, the
path ``les_p1_eeg_overlay_root()`` in ../_config.R returns.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import platform
import shutil
import sys
from pathlib import Path

import numpy as np
import pandas as pd

import compare
import export_writer
import filters
import paths
import validate
import validate_margin
from bv_io import read_header, read_markers
from pipeline import AFFECTED_1HZ, Reconstruction

NINE = sorted(AFFECTED_1HZ)
MARGIN = validate_margin.MARGIN_IDS
VALIDATE_TASKS = [('1hz', p) for p in NINE] + [('margin', p) for p in MARGIN]
SESSION = 3
BRANCHES, CONDS = ('S1', 'S2'), ('S101', 'S102', 'S103')
TARGET_HP, TARGET_LP = 0.1, 30.0
#: Amendment 2: M = ceil(ln 1e-3 / ln r) for the single-pass 0.1 Hz section at 500 Hz.
EXPECTED_MARGIN_01HZ = 9691
#: Side output for the trigger-rule check: a window around each property trigger wide enough
#: to re-epoch on the word-onset trigger (-96..+1,096 ms, Amendment 5), which precedes the
#: property trigger by two serial triggers (~21 ms at the realised ~10.7 ms spacing).
EVENT_WINDOW_MS = (-200, 1150)
PRECEDING_MARKERS_MS = 60


# ----------------------------------------------------------------------------- helpers
def store_root() -> Path:
    return Path(os.environ.get('LES_STORE') or paths.CODE_ROOT)


def default_out() -> Path:
    return store_root() / 'paper_1_transfer' / 'data_derived' / 'eeg_reprocessing'


def overlay_root() -> Path:
    return store_root() / 'paper_1_transfer' / 'data_derived' / 'eeg_overlay'


def sha256(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def code_digest() -> str:
    """SHA-256 over this package's modules (name + bytes, sorted), line endings normalised."""
    h = hashlib.sha256()
    for p in sorted(Path(__file__).resolve().parent.glob('*.py')):
        h.update(p.name.encode())
        h.update(p.read_bytes().replace(b'\r\n', b'\n'))
    return h.hexdigest()


def software() -> dict:
    import olefile
    import scipy
    return dict(python=platform.python_version(), numpy=np.__version__, scipy=scipy.__version__,
                pandas=pd.__version__, olefile=olefile.__version__, platform=platform.platform(),
                modules=os.environ.get('LOADEDMODULES', ''))


def run_info() -> dict:
    return dict(utc=dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds'),
                host=platform.node(), slurm_job=os.environ.get('SLURM_JOB_ID', ''),
                slurm_array_job=os.environ.get('SLURM_ARRAY_JOB_ID', ''),
                slurm_task=os.environ.get('SLURM_ARRAY_TASK_ID', ''),
                code_commit=os.environ.get('LES_CODE_COMMIT', ''), code_digest=code_digest())


def write_json(p: Path, obj: dict) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(p.suffix + '.tmp')
    tmp.write_text(json.dumps(obj, indent=2, default=_json_default), encoding='utf-8')
    tmp.replace(p)


def _json_default(o):
    if isinstance(o, (np.integer,)):
        return int(o)
    if isinstance(o, (np.floating,)):
        return float(o)
    if isinstance(o, (np.bool_,)):
        return bool(o)
    if isinstance(o, Path):
        return str(o)
    raise TypeError(type(o))


def input_hashes(pid: int) -> dict:
    raw = paths.raw_dir(pid, SESSION)
    out = {f'raw/{pid}.{x}': sha256(raw / f'{pid}.{x}') for x in ('vhdr', 'vmrk', 'eeg')}
    out[f'history/{pid}.ehst2'] = sha256(paths.history_path(pid, SESSION))
    for br in BRANCHES:
        for cond in CONDS:
            for x in ('vhdr', 'vmrk', 'txt'):
                f = paths.export_dir(SESSION) / f'{pid}_trialbytrial_{br}_{cond}.{x}'
                out[f'legacy_export/{f.name}'] = sha256(f)
    return out


def gate_path(out: Path, kind: str, pid: int) -> Path:
    return out / 'validation' / kind / str(pid) / 'gate.json'


# ------------------------------------------------------------------------ stage 1: gates
def validate_1hz(pid: int, out: Path) -> dict:
    d = out / 'validation' / '1hz' / str(pid)
    d.mkdir(parents=True, exist_ok=True)
    rows, ars, rec = validate.validate_id(pid)
    pd.DataFrame(rows).to_csv(d / 'metrics_per_file.csv', index=False)
    pd.DataFrame(ars).to_csv(d / 'artifact_rejection.csv', index=False)
    pd.DataFrame([rec]).to_csv(d / 'metrics_per_recording.csv', index=False)

    # Writer round trip at 1 Hz: the files a 0.1 Hz run would write, checked against the
    # legacy export they would replace (same gates) and against the array written.
    r = Reconstruction(pid, low_cutoff=1.0)
    tmp = d / 'roundtrip'
    errs_legacy, max_file_vs_array, vmrk_identical = [], 0.0, True
    for br in BRANCHES:
        b = r.branch(br)
        for cond in CONDS:
            _, data = r.trials(br, cond, b)
            legacy = r.export_dir / f'{pid}_trialbytrial_{br}_{cond}.vhdr'
            files = export_writer.write_export(legacy, tmp, data, r.names, 'round-trip test, 1 Hz')
            back = export_writer.round_trip(files['vhdr'])
            max_file_vs_array = max(max_file_vs_array, float(np.abs(back - data).max()))
            errs_legacy.append((back - validate.read_export(legacy)[1]).ravel())
            vmrk_identical &= files['vmrk'].read_bytes() == (legacy.with_suffix('.vmrk')).read_bytes()
    shutil.rmtree(tmp)
    rt = compare.metrics(np.concatenate(errs_legacy), prefix='roundtrip_vs_legacy_')
    rt['roundtrip_max_file_vs_array'] = max_file_vs_array
    rt['roundtrip_vmrk_identical'] = bool(vmrk_identical)
    ok_rt = (rt['roundtrip_vs_legacy_rmse'] <= validate.RMSE_GATE and rt['roundtrip_vs_legacy_p9999'] <= validate.P9999_GATE
             and max_file_vs_array <= 0.0005 + 1e-9 and vmrk_identical)
    gate = dict(kind='1hz', participant_lab_ID=pid, session=SESSION,
                passed=bool(rec.get('pass', False) and ok_rt), recording=rec, roundtrip=rt,
                gates=dict(rmse=validate.RMSE_GATE, p9999=validate.P9999_GATE),
                inputs=input_hashes(pid), software=software(), run=run_info())
    write_json(gate_path(out, '1hz', pid), gate)
    return gate


def validate_margin_task(pid: int, out: Path) -> dict:
    d = out / 'validation' / 'margin' / str(pid)
    d.mkdir(parents=True, exist_ok=True)
    rows, trials = validate_margin.validate_recording(pid)
    pd.DataFrame(rows).to_csv(d / 'margin_validation.csv', index=False)
    pd.DataFrame(trials).to_csv(d / 'margin_validation_trials.csv', index=False)
    adopted = validate_margin.adopted_rule_row(rows)
    gate = dict(kind='margin', participant_lab_ID=pid, session=SESSION, passed=bool(adopted['pass']),
                adopted_rule=adopted, n_rules=len(rows),
                other_rules_passing=[r['rule'] for r in rows if r['pass'] and r['rule'] != adopted['rule']],
                software=software(), run=run_info())
    write_json(gate_path(out, 'margin', pid), gate)
    return gate


# ------------------------------------------------------------------- stage 2: 0.1 Hz run
def require_all_gates(out: Path) -> dict:
    """Protocol: if any recording fails any gate, the scripted route is rejected for all nine."""
    digest, gates, problems = code_digest(), {}, []
    for kind, pid in VALIDATE_TASKS:
        p = gate_path(out, kind, pid)
        if not p.exists():
            problems.append(f'{kind}/{pid}: no gate record')
            continue
        g = json.loads(p.read_text(encoding='utf-8'))
        if not g.get('passed'):
            problems.append(f'{kind}/{pid}: gate failed')
        if g['run']['code_digest'] != digest:
            problems.append(f'{kind}/{pid}: gate produced by other code ({g["run"]["code_digest"][:12]})')
        gates[(kind, pid)] = g
    if problems:
        raise SystemExit('Refusing to produce any 0.1 Hz derivative:\n  ' + '\n  '.join(problems))
    return gates


def trigger_events(r: Reconstruction, br: str, b) -> dict:
    """Every condition trigger in the retained parents of branch ``br``, kept or not.

    Parent segments removed by hand are left out: those are manual removals, not the trigger
    rule. Each event stores the 0.1 Hz data from EVENT_WINDOW_MS around its property trigger
    and the markers in the PRECEDING_MARKERS_MS before it, so the check can lock to the
    word-onset trigger exactly. The lag is in samples; the rule keeps lag == 5.
    """
    fs = r.fs
    a_pts = int(round(EVENT_WINDOW_MS[0] * fs / 1000))
    n_pts = int(round((EVENT_WINDOW_MS[1] - EVENT_WINDOW_MS[0]) * fs / 1000)) + 1
    pre = int(round(PRECEDING_MARKERS_MS * fs / 1000))
    seglen = b.segments[0].length
    keep = (r.h.segment_table(r.ar_node(br))[:, 0] // seglen).tolist()
    stim = sorted((m for m in r.cont_markers if m.type == 'Stimulus'), key=lambda m: m.pos)
    ev = dict(data=[], cond=[], lag=[], kept=[], property_pos=[], preceding=[])
    for i in keep:
        s = b.segments[i]
        for m in b.markers_by_segment[i]:
            if m.type != 'Stimulus' or m.description not in CONDS:
                continue
            lag = s.start + m.pos - s.ref_pos
            if lag <= 0:
                continue  # a condition trigger before its property trigger belongs to another event
            start = s.ref_pos + a_pts
            if start < 0 or start + n_pts > r.x.shape[1]:
                continue
            ev['data'].append(r.filtered_segment(start, n_pts).astype(np.float32))
            ev['cond'].append(m.description)
            ev['lag'].append(lag)
            ev['kept'].append(lag == 5)
            ev['property_pos'].append(s.ref_pos)
            ev['preceding'].append('; '.join(f'{q.description}@{q.pos - s.ref_pos}' for q in stim
                                             if s.ref_pos - pre <= q.pos < s.ref_pos))
    return ev


def reprocess(pid: int, out: Path, task_index: int) -> dict:
    if pid not in AFFECTED_1HZ:
        raise PermissionError(f'{pid} is not one of the nine records')
    gates = require_all_gates(out)
    r = Reconstruction(pid, low_cutoff=TARGET_HP, high_cutoff=TARGET_LP)
    if r.margin != EXPECTED_MARGIN_01HZ or r.block_mode != 'new_segment' or r.filter_mode != 'on_demand':
        raise RuntimeError(f'filter rule differs from Amendment 2: margin {r.margin}, {r.block_mode}, {r.filter_mode}')
    stage = out / 'staging' / f'Session {SESSION}' / 'Export'
    datef = validate.sample_dates(r.cont_markers, r.fs)
    note = (f'Reprocessed at a {TARGET_HP} Hz high-pass (docs/eeg_filter_reprocessing_protocol.md) by '
            f'paper_1_transfer/scripts/eeg_reconstruction, code digest {code_digest()[:16]}; same trials as the legacy export.')
    trials, outputs, events = {}, {}, {k: [] for k in ('data', 'cond', 'lag', 'kept', 'property_pos', 'preceding', 'branch')}
    for br in BRANCHES:
        b = r.branch(br)
        if not b.seg_table_match:
            raise RuntimeError(f'{pid} {br}: parent segmentation differs from the history')
        for cond in CONDS:
            starts, data = r.trials(br, cond, b)   # raises if trial identity differs from the history
            legacy = r.export_dir / f'{pid}_trialbytrial_{br}_{cond}.vhdr'
            lh = read_header(legacy)
            legacy_dates = [m.date for m in read_markers(legacy.with_suffix('.vmrk')) if m.type == 'New Segment']
            if len(starts) * lh.segment_data_points != lh.data_points or [datef(s) for s in starts] != legacy_dates:
                raise RuntimeError(f'{pid} {br} {cond}: trials differ from the legacy export')
            files = export_writer.write_export(legacy, stage, data, r.names, note)
            back = export_writer.round_trip(files['vhdr'])
            if float(np.abs(back - data).max()) > 0.0005 + 1e-9:
                raise RuntimeError(f'{files["txt"].name}: written file does not read back')
            trials[legacy.stem] = len(starts)
            for f in files.values():
                outputs[f'Session {SESSION}/Export/{f.name}'] = sha256(f)
        ev = trigger_events(r, br, b)
        for k in ev:
            events[k] += ev[k]
        events['branch'] += [br] * len(ev['cond'])

    tc = out / 'trigger_check' / f'{pid}_events.npz'
    tc.parent.mkdir(parents=True, exist_ok=True)
    np.savez_compressed(tc, data=np.stack(events['data']), channel_names=np.array(r.names),
                        branch=np.array(events['branch']), cond=np.array(events['cond']),
                        lag_samples=np.array(events['lag']), kept_by_rule=np.array(events['kept']),
                        property_trigger_pos=np.array(events['property_pos']),
                        preceding_markers=np.array(events['preceding']),
                        window_ms=np.array(EVENT_WINDOW_MS), sampling_rate=np.array(r.fs))
    g = gates[('1hz', pid)]
    prov = dict(
        participant_lab_ID=pid, session=SESSION, status='pass',
        method='scripted reconstruction (paper_1_transfer/scripts/eeg_reconstruction); Analyzer fallback not used',
        filter=dict(high_pass_hz=TARGET_HP, low_pass_hz=TARGET_LP, nominal_order=4,
                    realisation='2nd-order Butterworth forwards and backwards, pre-warped cutoff compensation',
                    single_pass_high_pass_hz=r.sos['hp_single_pass_hz'], single_pass_low_pass_hz=r.sos['lp_single_pass_hz'],
                    margin_samples=r.margin, margin_rule='ceil(ln 1e-3 / ln r), restart at New Segment markers',
                    filter_mode=r.filter_mode, block_mode=r.block_mode),
        validation_1hz=dict(rmse=g['recording']['rmse'], p9999=g['recording']['p9999'], max=g['recording']['max'],
                            roundtrip_vs_legacy_rmse=g['roundtrip']['roundtrip_vs_legacy_rmse']),
        margin_validation={str(p): dict(rmse=gates[('margin', p)]['adopted_rule']['rmse'],
                                        p9999=gates[('margin', p)]['adopted_rule']['p9999'])
                           for p in MARGIN},
        trials=trials, n_trials=int(sum(trials.values())),
        trigger_check=dict(file=tc.name, sha256=sha256(tc), n_events=len(events['cond']),
                           n_kept_by_rule=int(np.sum(events['kept']))),
        inputs=input_hashes(pid), outputs=outputs, software=software(), run=run_info())
    write_json(out / 'provenance' / f'{pid}.json', prov)
    return prov


# ---------------------------------------------------------------------- stage 3: assemble
def assemble(out: Path) -> None:
    digest, provs, problems = code_digest(), {}, []
    stage = out / 'staging'
    for pid in NINE:
        p = out / 'provenance' / f'{pid}.json'
        if not p.exists():
            problems.append(f'{pid}: no provenance record')
            continue
        pr = json.loads(p.read_text(encoding='utf-8'))
        if pr.get('status') != 'pass' or pr['run']['code_digest'] != digest:
            problems.append(f'{pid}: not passed, or produced by other code')
        for rel, h in pr['outputs'].items():
            if not (stage / rel).exists() or sha256(stage / rel) != h:
                problems.append(f'{pid}: staged {rel} missing or changed')
        provs[pid] = pr
    if len(provs) == len(NINE):
        want = {f'{p}_trialbytrial_{br}_{c}.{x}' for p in NINE for br in BRANCHES for c in CONDS for x in ('vhdr', 'vmrk', 'txt')}
        got = {f.name for f in (stage / f'Session {SESSION}' / 'Export').iterdir()}
        if got != want:
            problems.append(f'staging holds {len(got)} files, expected exactly {len(want)}')
    if problems:
        raise SystemExit('Not assembling the overlay:\n  ' + '\n  '.join(problems))

    ov = overlay_root()
    if ov.exists() and any(f.is_file() for f in ov.rglob('*')):
        raise SystemExit(f'{ov} already holds files; move them aside (never overwrite an overlay in place).')
    rows = []
    for pid, pr in provs.items():
        for rel, h in sorted(pr['outputs'].items()):
            dst = ov / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(stage / rel, dst)
            if sha256(dst) != h:
                raise SystemExit(f'copy of {rel} does not match its hash')
            rows.append(dict(file=rel, participant_lab_ID=str(pid), session=str(SESSION), kind='reprocessed',
                             status='pass', conventions='as_legacy', sha256=h))
    man = pd.DataFrame(rows).sort_values('file', kind='stable')
    man.to_csv(out / 'eeg_overlay_manifest.candidate.csv', index=False, lineterminator='\n')
    prov_rows = []
    for pid, pr in provs.items():
        row = dict(participant_lab_ID=pid, session=SESSION, status=pr['status'], method=pr['method'],
                   n_trials=pr['n_trials'], **{f'filter_{k}': v for k, v in pr['filter'].items()},
                   **{f'validation_1hz_{k}': v for k, v in pr['validation_1hz'].items()},
                   trigger_check_events=pr['trigger_check']['n_events'],
                   trigger_check_kept=pr['trigger_check']['n_kept_by_rule'],
                   **{f'sha256_{k}': v for k, v in pr['inputs'].items()},
                   **{f'software_{k}': v for k, v in pr['software'].items() if k != 'modules'},
                   code_digest=pr['run']['code_digest'], code_commit=pr['run']['code_commit'],
                   slurm_job=pr['run']['slurm_job'], utc=pr['run']['utc'])
        prov_rows.append(row)
    pd.DataFrame(prov_rows).to_csv(out / 'provenance_manifest.csv', index=False, lineterminator='\n')
    write_json(out / 'assemble.json', dict(overlay=str(ov), n_files=len(rows), run=run_info()))
    print(f'[assemble] {len(rows)} files for {len(provs)} records copied to {ov}', flush=True)


# ------------------------------------------------------------------------------- driver
def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('stage', choices=['validate', 'reprocess', 'assemble', 'ntasks'])
    ap.add_argument('--task', type=int, help='array task index (validate: 0-12; reprocess: 0-8)')
    ap.add_argument('--of', choices=['validate', 'reprocess'], help='with ntasks: which stage')
    ap.add_argument('--out', type=Path, default=None)
    a = ap.parse_args(argv)
    out = a.out or default_out()
    if a.stage == 'ntasks':
        print(len(VALIDATE_TASKS) if a.of == 'validate' else len(NINE))
        return
    if a.stage == 'assemble':
        assemble(out)
        return
    tasks = VALIDATE_TASKS if a.stage == 'validate' else [('reprocess', p) for p in NINE]
    if a.task is None or not 0 <= a.task < len(tasks):
        raise SystemExit(f'--task must be 0..{len(tasks) - 1} for {a.stage}')
    kind, pid = tasks[a.task]
    print(f'[{a.stage}] task {a.task}: {kind} {pid} -> {out}', flush=True)
    if kind == '1hz':
        res = validate_1hz(pid, out)
    elif kind == 'margin':
        res = validate_margin_task(pid, out)
    else:
        res = reprocess(pid, out, a.task)
    ok = res.get('passed', res.get('status') == 'pass')
    print(f'[{a.stage}] {kind} {pid}: {"PASS" if ok else "FAIL"}', flush=True)
    sys.exit(0 if ok else 3)


if __name__ == '__main__':
    main()
