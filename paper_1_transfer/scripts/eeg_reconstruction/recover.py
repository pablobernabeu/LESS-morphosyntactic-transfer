"""Recovery of two misaligned exports and rebuild of three missing marker files.

Implements docs/eeg_filter_reprocessing_protocol.md, Amendments 2, 3, 5 and 6, as four
fail-closed stages run by paper_1_transfer/hpc/00g_recover_eeg.slurm:

``gate --task K``        K = 0 (Session 6 of lab ID 5), 1 (Session 2 of lab ID 7). Rebuilds
    the legacy exports from the record's own raw signal and the history's markers. Passing
    both gates, with identical trials, shows the history's data-derived decisions (raw-data
    inspection, reference, filters, ICA) were made on that signal and only its markers were
    another recording's (Amendments 2 and 3). Also checks the rule-based marker writer
    against the legacy marker files up to the order of markers sharing a position.
``resegment --task K``   Refuses to run unless the record's gate passed under this code.
    Segments the record at its own events: its own stimulus markers replace the history's,
    inside the analyst's frame (Amendment 6), with the history's bad intervals and blink
    annotations kept, the parent segmentation and five-sample trigger rule of the history's
    nodes, every parent segment overlapping a bad interval dropped, and no manual removal
    transferred. Writes every export of the record, with new marker files.
``markers``              Rebuilds the marker files of three legacy exports that have none
    (Session 3 of lab ID 17, gender agreement S101; Session 4 of lab ID 34, verb-object
    number agreement S101 and S102; Amendment 5) from their tbt nodes, after the same
    rebuild has reproduced every existing marker file of both records byte for byte.
``assemble``             Checks the three provenance records and every staged hash, copies
    the files into the overlay (never over an existing file) and writes the candidate
    admission rows (``reprocessed`` and ``markers_rebuilt``) and the provenance manifest.

Outputs: ``$LES_STORE/paper_1_transfer/data_derived/eeg_reprocessing/recovery/``. Nothing
here computes a condition average, a contrast or a model.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import numpy as np
import pandas as pd

import compare
import export_writer as ew
import paths
import segmentation as sg
import validate
from bv_io import Marker, read_export, read_header, read_markers
from history import HMarker
from pipeline import Reconstruction
from reprocess import code_digest, default_out, overlay_root, run_info, sha256, software, write_json

RECOVER = [(5, 6), (7, 2)]
MARKERS = [(17, 3, [('S1', 'S101')]), (34, 4, [('S3', 'S101'), ('S3', 'S102')])]
HP, LP = 0.1, 30.0
#: History marker types kept when the record's own events replace its stimulus markers:
#: the analyst's decisions made on this signal. Its Stimulus markers (including the frame's
#: Start/End) and New Segment markers belong to the other recording and are replaced.
KEPT_HISTORY_TYPES = ('Bad Interval', 'UserDefined', 'Comment')


def root(out: Path) -> Path:
    return out / 'recovery'


def rec_key(pid: int, session: int) -> str:
    return f'{pid}_s{session}'


def load(pid: int, session: int, signal: bool = True) -> Reconstruction:
    r = Reconstruction(pid, session=session, low_cutoff=HP, high_cutoff=LP, signal=signal)
    if signal and (r.hist_low != HP or r.hist_high != LP):
        raise RuntimeError(f'{pid} S{session}: history filters {r.hist_low}/{r.hist_high} Hz, expected {HP}/{LP}')
    return r


def tbt_geometry(r: Reconstruction, br: str, cond: str) -> tuple[int, int]:
    """(segment length, samples from trial start to its reference marker) of a tbt node."""
    tx = r.h.xml(r.tbt_node(br, cond))
    return (sg.ms_to_points(float(tx.findtext('MarkerSegmentTime')), r.fs),
            -sg.ms_to_points(float(tx.findtext('MarkerStartTime')), r.fs))


def _rows(b: bytes) -> list[str]:
    rows = [ln.split('=', 1)[1] for ln in b.decode('utf-8').splitlines() if ln.startswith('Mk')]
    return sorted(rows, key=lambda x: (int(x.split(',')[2]), x))


def input_hashes(r: Reconstruction) -> dict:
    out = {f'raw/{r.pid}.{x}': sha256(r.raw_dir / f'{r.pid}.{x}') for x in ('vhdr', 'vmrk', 'eeg')
           if (r.raw_dir / f'{r.pid}.{x}').exists()}
    out[f'history/{r.pid}.ehst2'] = sha256(paths.history_path(r.pid, r.session))
    for br, cond in sorted(r.export_nodes):
        for x in ('vhdr', 'vmrk', 'txt'):
            f = r.export_dir / f'{r.pid}_trialbytrial_{br}_{cond}.{x}'
            if f.exists():
                out[f'legacy_export/{f.name}'] = sha256(f)
    return out


# ------------------------------------------------------------------------------ gate
def gate(k: int, out: Path) -> dict:
    pid, session = RECOVER[k]
    r = load(pid, session)
    datef = validate.sample_dates(r.cont_markers, r.fs)
    errs, files, ok_dates, ok_vmrk = [], {}, True, True
    for br in sorted({b for b, _ in r.export_nodes}):
        b = r.branch(br)
        if not b.seg_table_match:
            raise RuntimeError(f'{pid} S{session} {br}: parent segmentation differs from the history')
        for cond in sorted(c for bb, c in r.export_nodes if bb == br):
            starts, data = r.trials(br, cond, b)    # raises if trial identity differs
            stem = f'{pid}_trialbytrial_{br}_{cond}'
            _, ex, emk = read_export(r.export_dir / f'{stem}.vhdr')
            d_ok = [datef(s) for s in starts] == [m.date for m in emk if m.type == 'New Segment']
            seglen, ref = tbt_geometry(r, br, cond)
            rule = ew.vmrk_bytes(r.export_nodes[(br, cond)], f'{stem}.txt',
                                 ew.entries_by_rule(starts, ref, seglen, r.cont_markers, datef))
            v_ok = _rows(rule) == _rows((r.export_dir / f'{stem}.vmrk').read_bytes())
            m = compare.metrics(data - ex)
            files[stem] = dict(n_trials=len(starts), dates_match=d_ok, vmrk_rule_match=v_ok,
                               rmse=m['rmse'], p9999=m['p9999'], max=m['max'])
            errs.append((data - ex).ravel())
            ok_dates &= d_ok
            ok_vmrk &= v_ok
    allm = compare.metrics(np.concatenate(errs))
    passed = bool(allm['rmse'] <= validate.RMSE_GATE and allm['p9999'] <= validate.P9999_GATE and ok_dates and ok_vmrk)
    g = dict(kind='recovery_gate', participant_lab_ID=pid, session=session, passed=passed, overall=allm,
             files=files, frame=r.frame, gates=dict(rmse=validate.RMSE_GATE, p9999=validate.P9999_GATE),
             inputs=input_hashes(r), software=software(), run=run_info())
    write_json(root(out) / 'gate' / f'{rec_key(pid, session)}.json', g)
    return g


# ------------------------------------------------------------------------- resegment
def _require_gate(out: Path, pid: int, session: int) -> dict:
    p = root(out) / 'gate' / f'{rec_key(pid, session)}.json'
    if not p.exists():
        raise SystemExit(f'{pid} S{session}: no gate record; run the gate stage first')
    g = json.loads(p.read_text(encoding='utf-8'))
    if not g['passed'] or g['run']['code_digest'] != code_digest():
        raise SystemExit(f'{pid} S{session}: gate failed or was produced by other code; not re-segmenting')
    return g


def own_markers(r: Reconstruction) -> tuple[list, callable, dict]:
    """The record's own markers in frame coordinates (history convention), a date function,
    and counts of what the frame excludes."""
    a, n = r.frame if r.frame else (0, r.x.shape[1])
    own = read_markers(r.raw_dir / f'{r.pid}.vmrk')
    conv = [HMarker(m.type, m.description, m.pos - a, m.length, -1 if m.channel == 0 else m.channel - 1, 0)
            for m in own]
    inside = [m for m in conv if 0 <= m.pos < n]
    kept = [m for m in r.cont_markers if m.type in KEPT_HISTORY_TYPES]
    markers = sorted([m for m in inside if m.type != 'New Segment'] + kept +
                     [m for m in inside if m.type == 'New Segment' and m.pos > 0], key=lambda m: m.pos)
    dates = [Marker(m.type, m.description, m.pos - a, m.length, m.channel, m.date)
             for m in own if m.type == 'New Segment']
    datef = validate.sample_dates(dates, r.fs)
    conds = [m for m in conv if m.type == 'Stimulus' and m.description in ('S101', 'S102', 'S103')]
    counts = dict(own_condition_triggers=len(conds),
                  outside_frame=sum(1 for m in conds if not 0 <= m.pos < n),
                  history_markers_kept=len(kept))
    return markers, datef, counts


def resegment(k: int, out: Path) -> dict:
    pid, session = RECOVER[k]
    g = _require_gate(out, pid, session)
    r = load(pid, session)
    markers, datef, counts = own_markers(r)
    n = r.x.shape[1]
    r.cont_markers = markers
    cuts = sorted({m.pos for m in markers if m.type == 'New Segment' and m.pos > 0})
    r.blocks = list(zip([0] + cuts, cuts + [n]))
    bad = [(m.pos, m.length) for m in markers if m.type == 'Bad Interval']
    stage = root(out) / 'staging' / f'Session {session}' / 'Export'
    note = (f'Re-segmented at its own events under Amendments 3/6 of docs/eeg_filter_reprocessing_protocol.md '
            f'by paper_1_transfer/scripts/eeg_reconstruction, code digest {code_digest()[:16]}.')
    trials, outputs, per_branch = {}, {}, {}
    for br in sorted({b for b, _ in r.export_nodes}):
        x = r.h.xml(f'{r.ica_node}/Segmentation {br}')
        sel = x.find('SelectedMarkers/SelectedMarker')
        segs = sg.marker_segments(markers, n, sel.findtext('Description'), float(x.findtext('MarkerStartTime')),
                                  float(x.findtext('MarkerSegmentTime')), r.fs, x.findtext('AllowOverlap') == 'true',
                                  sel.findtext('Type'))
        n_all = len(segs)
        segs = [s for s in segs if not any(b0 < s.start + s.length and s.start < b0 + bl for b0, bl in bad)]
        mbs = [[HMarker(m.type, m.description, m.pos - s.start, m.length, m.channel, m.levels_up)
                for m in markers if s.start <= m.pos < s.start + s.length and m.type not in ('Bad Interval', 'New Segment')]
               for s in segs]
        per_branch[br] = dict(parent_segments=n_all, dropped_for_bad_interval=n_all - len(segs))
        for cond in sorted(c for bb, c in r.export_nodes if bb == br):
            seglen, ref = tbt_geometry(r, br, cond)
            tx = r.h.xml(r.tbt_node(br, cond))
            subs = sg.sub_segments(segs, mbs, cond, float(tx.findtext('MarkerStartTime')),
                                   float(tx.findtext('MarkerSegmentTime')), r.fs, None)
            if not subs:
                raise RuntimeError(f'{pid} S{session} {br} {cond}: no trial survives; the importer needs every export')
            offsets = np.cumsum([0] + [s.length for s in segs])
            if any(s.start - offsets[s.parent_index] != 0 or s.length != seglen for s in subs):
                raise RuntimeError('trial not aligned with its parent segment')
            starts = [segs[s.parent_index].start for s in subs]
            data = np.stack([r.filtered_segment(s0, seglen) for s0 in starts], axis=1)
            stem = f'{pid}_trialbytrial_{br}_{cond}'
            vmrk = ew.vmrk_bytes(r.export_nodes[(br, cond)], f'{stem}.txt',
                                 ew.entries_by_rule(starts, ref, seglen, markers, datef), note=note)
            files = ew.write_export(r.export_dir / f'{stem}.vhdr', stage, data, r.names, note, vmrk=vmrk)
            if float(np.abs(ew.round_trip(files['vhdr']) - data).max()) > 0.0005 + 1e-9:
                raise RuntimeError(f'{files["txt"].name}: written file does not read back')
            n_in_parents = sum(1 for mk in mbs for m in mk if m.type == 'Stimulus' and m.description == cond)
            trials[stem] = dict(n_trials=len(starts), lost_to_trigger_rule=n_in_parents - len(starts),
                                legacy_n_trials=read_header(r.export_dir / f'{stem}.vhdr').data_points // seglen)
            for f in files.values():
                outputs[f'Session {session}/Export/{f.name}'] = sha256(f)
    prov = dict(kind='reprocessed', participant_lab_ID=pid, session=session, status='pass',
                method='re-segmented at its own events (Amendments 2/3/6); scripted reconstruction',
                filter=dict(high_pass_hz=HP, low_pass_hz=LP, margin_samples=r.margin, filter_mode=r.filter_mode,
                            block_mode=r.block_mode, blocks=len(r.blocks)),
                frame=r.frame, gate=dict(rmse=g['overall']['rmse'], p9999=g['overall']['p9999']),
                marker_counts=counts, branches=per_branch, trials=trials,
                n_trials=int(sum(t['n_trials'] for t in trials.values())),
                inputs=input_hashes(r), outputs=outputs, software=software(), run=run_info())
    write_json(root(out) / 'provenance' / f'{rec_key(pid, session)}.json', prov)
    return prov


# ---------------------------------------------------------------------------- markers
def markers_stage(out: Path) -> dict:
    stage = root(out) / 'staging'
    recs, outputs, ok = [], {}, True
    for pid, session, targets in MARKERS:
        r = load(pid, session, signal=False)
        checked, exact = 0, 0
        for (br, cond), hp in sorted(r.export_nodes.items()):
            stem = f'{pid}_trialbytrial_{br}_{cond}'
            legacy = r.export_dir / f'{stem}.vmrk'
            if legacy.exists():
                checked += 1
                exact += ew.vmrk_bytes(hp, f'{stem}.txt', ew.entries_from_node(r.h, r.tbt_node(br, cond))) == legacy.read_bytes()
        rec = dict(participant_lab_ID=pid, session=session, existing_checked=checked, existing_exact=exact, rebuilt={})
        ok &= checked > 0 and exact == checked
        if checked and exact == checked:
            for br, cond in targets:
                stem = f'{pid}_trialbytrial_{br}_{cond}'
                if (r.export_dir / f'{stem}.vmrk').exists() or not (r.export_dir / f'{stem}.txt').exists():
                    raise RuntimeError(f'{stem}: expected a legacy text export without a marker file')
                entries = ew.entries_from_node(r.h, r.tbt_node(br, cond))
                n_seg = sum(1 for e in entries if e[0] == 'New Segment')
                seglen, _ = tbt_geometry(r, br, cond)
                if n_seg * seglen != read_header(r.export_dir / f'{stem}.vhdr').data_points:
                    raise RuntimeError(f'{stem}: node holds {n_seg} trials, the text export another count')
                f = stage / f'Session {session}' / 'Export' / f'{stem}.vmrk'
                f.parent.mkdir(parents=True, exist_ok=True)
                f.write_bytes(ew.vmrk_bytes(r.export_nodes[(br, cond)], f'{stem}.txt', entries))
                outputs[f'Session {session}/Export/{f.name}'] = sha256(f)
                rec['rebuilt'][stem] = n_seg
        recs.append(rec)
    prov = dict(kind='markers_rebuilt', status='pass' if ok else 'fail', records=recs, outputs=outputs,
                software=software(), run=run_info())
    write_json(root(out) / 'provenance' / 'markers.json', prov)
    return prov


# --------------------------------------------------------------------------- assemble
def assemble(out: Path) -> None:
    digest, problems, provs = code_digest(), [], []
    for name in [rec_key(p, s) for p, s in RECOVER] + ['markers']:
        p = root(out) / 'provenance' / f'{name}.json'
        if not p.exists():
            problems.append(f'{name}: no provenance record')
            continue
        pr = json.loads(p.read_text(encoding='utf-8'))
        if pr['status'] != 'pass' or pr['run']['code_digest'] != digest:
            problems.append(f'{name}: not passed, or produced by other code')
        for rel, h in pr['outputs'].items():
            f = root(out) / 'staging' / rel
            if not f.exists() or sha256(f) != h:
                problems.append(f'{name}: staged {rel} missing or changed')
        provs.append(pr)
    ov = overlay_root()
    clash = [rel for pr in provs for rel in pr['outputs'] if (ov / rel).exists()]
    if clash:
        problems.append(f'{len(clash)} file(s) already in the overlay, e.g. {clash[0]}')
    if problems:
        raise SystemExit('Not assembling:\n  ' + '\n  '.join(problems))
    rows = []
    for pr in provs:
        for rel, h in sorted(pr['outputs'].items()):
            dst = ov / rel
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root(out) / 'staging' / rel, dst)
            if sha256(dst) != h:
                raise SystemExit(f'copy of {rel} does not match its hash')
            pid = rel.split('/')[-1].split('_')[0]
            rows.append(dict(file=rel, participant_lab_ID=pid, session=rel.split('/')[0].split()[-1],
                             kind=pr['kind'], status='pass', conventions='as_legacy', sha256=h))
    pd.DataFrame(rows).sort_values('file', kind='stable').to_csv(
        root(out) / 'eeg_overlay_manifest.recovery.candidate.csv', index=False, lineterminator='\n')
    prov_rows = [dict(participant_lab_ID=pr['participant_lab_ID'], session=pr['session'], kind=pr['kind'],
                      status=pr['status'], n_trials=pr['n_trials'], frame=pr['frame'],
                      gate_rmse=pr['gate']['rmse'], gate_p9999=pr['gate']['p9999'],
                      **pr['marker_counts'], **{f'sha256_{k}': v for k, v in pr['inputs'].items() if not k.startswith('legacy')},
                      code_digest=pr['run']['code_digest'], code_commit=pr['run']['code_commit'], utc=pr['run']['utc'])
                 for pr in provs if pr['kind'] == 'reprocessed']
    for pr in provs:
        if pr['kind'] == 'markers_rebuilt':
            for rec in pr['records']:
                prov_rows.append(dict(participant_lab_ID=rec['participant_lab_ID'], session=rec['session'],
                                      kind='markers_rebuilt', status=pr['status'],
                                      n_trials=int(sum(rec['rebuilt'].values())),
                                      existing_marker_files_reproduced=f"{rec['existing_exact']}/{rec['existing_checked']}",
                                      code_digest=pr['run']['code_digest'], code_commit=pr['run']['code_commit'],
                                      utc=pr['run']['utc']))
    pd.DataFrame(prov_rows).to_csv(root(out) / 'recovery_provenance.csv', index=False, lineterminator='\n')
    write_json(root(out) / 'assemble.json', dict(overlay=str(ov), n_files=len(rows), run=run_info()))
    print(f'[assemble] {len(rows)} files copied to {ov}', flush=True)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('stage', choices=['gate', 'resegment', 'markers', 'assemble'])
    ap.add_argument('--task', type=int)
    ap.add_argument('--out', type=Path, default=None)
    a = ap.parse_args(argv)
    out = a.out or default_out()
    if a.stage in ('gate', 'resegment') and (a.task is None or not 0 <= a.task < len(RECOVER)):
        raise SystemExit(f'--task must be 0..{len(RECOVER) - 1}')
    if a.stage == 'assemble':
        assemble(out)
        return
    res = {'gate': lambda: gate(a.task, out), 'resegment': lambda: resegment(a.task, out),
           'markers': lambda: markers_stage(out)}[a.stage]()
    ok = res.get('passed', res.get('status') == 'pass')
    print(f'[{a.stage}] {a.task if a.task is not None else ""}: {"PASS" if ok else "FAIL"}', flush=True)
    sys.exit(0 if ok else 3)


if __name__ == '__main__':
    main()
