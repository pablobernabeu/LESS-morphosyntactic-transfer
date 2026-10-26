# Scripted reconstruction of the Session-3 EEG exports

This folder rebuilds BrainVision Analyzer's trial-by-trial exports from the raw recordings,
and uses that route to reprocess the nine Session-3 records that were high-pass filtered at
1 Hz instead of 0.1 Hz (lab IDs 7, 8, 9, 16, 53, 60, 61, 62, 65). What may be done, in what
order and under which checks is fixed by `docs/eeg_filter_reprocessing_protocol.md`
(Amendments 1, 2 and 5 in particular). The code was written and validated on
16 September 2026, and moved here unchanged apart from where it reads its inputs and writes
its outputs, as Amendment 1 requires before the 0.1 Hz stage runs.

## What each module does

| Module | Role |
|---|---|
| `paths.py` | Where inputs are read: the data tree (`$LES_DATA_ROOT`, else `data/`), and optionally `LES_EEG_RAW_DIR` for raw signal files kept outside it |
| `bv_io.py` | Readers for raw BrainVision recordings and Analyzer ASCII exports |
| `history.py` | Parser for Analyzer's `.ehst2` history files: markers, segment tables, filter and reference settings, the stored ICA |
| `rereference.py`, `filters.py`, `ica.py`, `segmentation.py` | The four processing steps, each emulating the Analyzer transform it replaces; the docstrings record how each was established |
| `artifact_rejection.py` | Re-detection of the archived artefact criteria (validation only; Amendment 1 keeps the trials of the 1 Hz exports) |
| `pipeline.py` | `Reconstruction`: one recording from raw samples to trial-by-trial data |
| `compare.py` | Error metrics against the exports |
| `validate.py` | The 1 Hz gate: rebuild the archived exports of the nine records |
| `validate_margin.py` | The filter-margin gate: rebuild the 0.1 Hz exports of IDs 10, 51, 58 and 59 under every candidate rule |
| `export_writer.py` | Writes an export in the legacy format (same marker file, annotated header, Analyzer's text layout) |
| `reprocess.py` | Cluster entry point: `validate`, `reprocess` and `assemble` stages, provenance records |
| `recover.py` | Cluster entry point for Amendments 2, 3, 5 and 6: recovery `gate` and `resegment` of Session 6 of lab ID 5 and Session 2 of lab ID 7, the `markers` rebuild of three missing marker files, and their `assemble` |
| `checks/trigger_check.py` | Cluster entry point for the trigger-rule check of Amendment 5: `events` rebuilds and gates the eight 0.1 Hz comparison recordings and writes their events; `analyse` compares the epochs the five-sample rule discards with those it keeps, over all seventeen recordings. It sits in its own folder because the code digest hashes only the modules above |

## Gates (all fail-closed)

1. **1 Hz gate** (per record): trial identity, channel order, sampling rate and epoch length
   match the archived export; RMSE ≤ 0.001 µV and 99.99th percentile absolute error
   ≤ 0.002 µV. The rebuild is also written with `export_writer.py` and read back, so the
   files themselves are checked against the legacy export under the same two limits.
2. **Margin gate** (IDs 10, 51, 58, 59): the rule adopted by Amendment 2 (margin
   ⌈ln 10⁻³ / ln r⌉, filter restarted at New Segment markers) reproduces their 0.1 Hz exports
   under the same limits. The other candidate rules are rerun and recorded, not required
   to fail.
3. **0.1 Hz stage** runs only if all thirteen gates passed under the same code (the code
   digest in each gate record must equal the running code's). A failure in any record stops
   all nine, as the protocol requires.
4. **Assembly** copies the nine records into the overlay only if every provenance record
   passed and every staged file still has the hash recorded for it, and never into an
   overlay that already holds files.

## Recovery and rebuilt marker files

Two exports hold another recording's markers (Session 6 of lab ID 5, Session 2 of lab ID
7). `recover.py` first rebuilds each legacy export from the record's own signal and the
history's markers (same two limits, identical trials), which shows the analyst's decisions
were made on that signal; it then segments the record at its own events inside the
analyst's frame, with the history's bad intervals and no manual removal (Amendment 6), and
writes new marker files. Some histories frame the recording before inspecting it (an Edit
Markers node and a single-segment Segmentation above the inspection); `pipeline.py` crops
the raw samples to that frame. Three legacy exports lack a marker file (Session 3 of lab ID
17, Session 4 of lab ID 34); their marker files are serialised from the history's
trial-by-trial nodes, a rebuild that reproduces every existing marker file of those records
byte for byte. Outputs sit under `eeg_reprocessing/recovery/`, and the assembly adds them
to the overlay as `reprocessed` and `markers_rebuilt` rows.

## Trigger-rule check

Amendment 5 asks whether the critical words the five-sample trigger rule discards are
exchangeable with the ones it keeps. `trigger_check.py` answers it on the seventeen
recordings the amendment names: the nine reprocessed records, whose events the reprocess
stage wrote, and eight 0.1 Hz recordings (Session 2 of lab IDs 10, 11, 12 and 20; Session 3
of lab IDs 10, 51, 58 and 59), which `checks/trigger_check.py events` rebuilds from the raw data and gates
against their archived exports before writing their events. Its `analyse` stage locks every
grammatical and ungrammatical epoch to the word-onset trigger (−96 to +1,096 ms, baseline
−96 to −2 ms), adjusts each window mean for the baseline within each recording, and
estimates, per property, window and macroregion, the difference D between discarded and
kept trials in the ungrammatical-minus-grammatical contrast. Recordings are weighted
equally, and the check passes where the 90% interval of D lies inside ±0.91 µV (two
one-sided tests at α = .05). It refuses to run on fewer than seventeen recordings, so it is
computed once. Its outputs feed no analysis. The module lives in `checks/` so that the code
digest, which hashes only the modules of this folder and which every gate and provenance
record of `reprocess.py` and `recover.py` carries, still matches the code that produced them.

## Outputs

Under `$LES_STORE/paper_1_transfer/data_derived/eeg_reprocessing/`:
`validation/{1hz,margin}/<id>/` (metrics and `gate.json`), `staging/` (the 162 new files: 54 exports of three files each),
`provenance/<id>.json` and `provenance_manifest.csv` (input and output hashes, filter
settings, validation errors, trial counts, software versions, code digest and commit),
`trigger_check/<id>_events.npz` (the side output of Amendment 5: every condition trigger in
the retained parent segments, kept or discarded by the five-sample rule, with 0.1 Hz data
from −200 to +1,150 ms around its property trigger and the markers of the preceding 60 ms,
so that the check can lock to the word-onset trigger exactly; `checks/trigger_check.py events`
adds `s<session>_<id>_events.npz` for the eight comparison recordings, with their gate
records in `trigger_check/gate/`, and `analyse` writes `trigger_check/results/`), and
`eeg_overlay_manifest.candidate.csv`. The files the importer reads are copied to
`$LES_STORE/paper_1_transfer/data_derived/eeg_overlay/`.

Nothing here computes a condition average, a contrast or a model.

## Running

On the cluster: `paper_1_transfer/hpc/00e_submit_reprocessing.sh` (see
`paper_1_transfer/hpc/README.md`, "EEG reprocessing"). Locally, from this folder, with the
raw signal files outside the data tree:

```bash
export LES_DATA_ROOT=/path/to/data LES_EEG_RAW_DIR=/path/to/raw_s3
python reprocess.py validate --task 0 --out /tmp/recon   # tasks 0-12, then
python reprocess.py reprocess --task 0 --out /tmp/recon  # tasks 0-8, then
LES_STORE=/tmp/store python reprocess.py assemble --out /tmp/recon
```

Python 3.13 with numpy, scipy, pandas and `olefile` (`requirements.txt`).
