# Audit of the legacy EEG exports (ISSUES.md N6 and N7)

The ERP analyses read trial-by-trial exports that BrainVision Analyzer wrote in 2024 and 2025.
On 16 and 17 September 2026 every one of them was audited against the behavioural logs, the raw
marker files and the Analyzer processing histories. The audit established two things the
manuscript relies on:

- **N6, export identity.** Every exported trial was traced to its source recording, and every
  export was screened for a stimulus-locked response. Three exports did not hold the
  participant-session they are named for (Session 3 of lab ID 48, Session 6 of lab ID 5,
  Session 2 of lab ID 7). They are excluded through `LES_P1_INVALID_EXPORTS` in
  `scripts/_config.R`, and two were later recovered (`docs/eeg_filter_reprocessing_protocol.md`,
  Amendments 2, 3 and 6).
- **N7, trial loss.** About a third of the critical words never reached an export. The cause was
  the two-step segmentation: an epoch was kept only when the condition trigger fell exactly five
  samples after the property trigger. The artefact step was semi-automatic. Loss within a
  recording was unrelated to grammaticality, and a segmentation tolerant of one sample of
  trigger jitter would have bought little precision for the term behind the paper's central
  conclusion.

The scripts here are the ones that produced the figures the Method, N6 and N7 quote. They were
moved from the job scratch area with their input and output paths changed, a header added to
each, and nothing else altered except where a header says so. `make_audit_tables.py` then writes
the two small tables the manuscript reads, so the Method's numbers come from these outputs
instead of being typed.

## Inputs

Everything is read from the project's read-only data tree, `$LES_DATA_ROOT` (on ARC, set by
`source _shared/hpc/arc_env.sh`), or `data/` beside the code root when that variable is unset:

| Input | Path under the data tree | Read by |
|---|---|---|
| Raw marker files and headers | `raw data/EEG/Session {2,3,4,6}/Raw/{id}.vmrk`, `.vhdr` | n6_01, n7_01, n7_04, n7_10, n7_14 |
| Analyzer histories | `raw data/EEG/Session {s}/History/{id}.ehst2` | n6_01, n7_01 |
| Trial-by-trial exports | `raw data/EEG/Session {s}/Export/{id}_trialbytrial_S{k}_S10{x}.vhdr/.vmrk/.txt` | n6_01, n6_03, n6_04, n7_01, n7_04, n7_07, n7_10, n7_14 |
| Behavioural logs | `raw data/behavioural data from lab sessions/Session {s}/subject-*.csv` | n7_04, n7_08, n7_10, n7_11 |
| Participant key | `raw data/Participant IDs and session progress.csv`, and the copy at the root of the tree | n7_09, n7_10, n7_12; precision_common.R |
| LHQ3 scores | `raw data/language history/LHQ3 Raw Data.xlsx`, `LHQ3 Aggregate Scores.xlsx` | precision_common.R |
| Legacy retained-trial table | `EEG_trial_count_per_condition.csv` | n7_09 (comparison only) |

No raw signal file (`.eeg`) is read. The exclusion lists are parsed from
`paper_1_transfer/scripts/_config.R`. `n7_20` also needs the brms summaries of the 20 August 2026
fits, which the repository no longer holds in `results/`. Extract them once:

```bash
git show c785f15:paper_1_transfer/results/_pooled_posterior_summaries.csv \
  > "$LES_STORE/paper_1_transfer/data_derived/eeg_audit/precision/pooled_posterior_summaries_2026-08-20.csv"
```

You can also point `LES_AUDIT_CALIBRATION_SUMMARIES` at a copy.

## Outputs

Intermediate outputs go to `<store>/paper_1_transfer/data_derived/eeg_audit/<stage>/`. `<store>`
is `$LES_STORE`, or the code root when that is unset, and `$LES_AUDIT_OUT` replaces the whole
`eeg_audit` folder. The folder is not under version control. Several of its tables hold
recording start times, so it must stay out of the repository. The two tracked tables carry no
times and no names:

- `results/_audit_export_identity.csv`: exports and participant-sessions audited, recordings
  shared by two participant-sessions, histories built on another recording, exports the history
  reproduces, the stimulus-locked screen (split-half reliability, leave-one-out grand-average
  correlation) and the paired-trial correlations of the two duplicate pairs.
- `results/_audit_trial_loss.csv`: recorded and history events and their five-sample intervals,
  exported trials, the artefact screen (epochs flagged, removed, kept), the trigger spacing and
  label offset, the within-recording odds ratio for losing an ungrammatical rather than a
  grammatical trial, the Mini-English Session 6 retention gaps and their odds ratio, what a
  tolerant segmentation would keep, and the projected narrowing of the grammaticality ×
  language interval.

Both tables are long, with the columns `quantity`, `value`, `ci_low`, `ci_high`, `unit`,
`source_script` and `note`. `ci_low` and `ci_high` hold a 95% confidence interval and nothing
else; a range is given as separate `_min` and `_max` quantities.

## Run order

Run from anywhere inside the repository; the R stages find the code root with `here`. The last
column gives two runtimes where both are known: on a laptop with the data tree on a local disk on
16 and 17 September 2026, and on 3 October 2026 on the same laptop, which other jobs were sharing
at the time. The 3 October times are upper bounds.

| Step | Script | Stage folder | Supports | Runtime |
|---|---|---|---|---|
| 1 | `n6_01_trial_identity.py` | `identity/` | N6: identity of every export, shared recordings, history settings | 50 min (3 Oct) |
| 2 | `n6_02_summarise_identity.py` | `identity/` | N6 summary (`audit_summary.txt`) | seconds |
| 3 | `n6_03_screen_exports.py` | `identity/` | N6, Amendment 3: stimulus-locked screen | 73 min (3 Oct) |
| 4 | `n6_04_duplicate_pairs.py` | `identity/` | N6 items 2 and 3: paired-trial correlations | 2 min |
| 5 | `n7_01_mechanism.py --all` | `mechanism/` | five-sample rule, artefact screen, label offset | 5 min; 43 min (3 Oct) |
| 6 | `n7_02_summarise_mechanism.py` | `mechanism/` | summary of step 5 (`summary_all.txt`) | 1 min |
| 7 | `n7_03_alternatives.py` | `mechanism/` | trials a tolerant segmentation would keep | 1 min |
| 8 | `n7_04_events.py` | `independence/` | recorded events and their intervals | 21 min (3 Oct) |
| 9 | `n7_05_events_table.py` | `independence/` | table for step 10 | 2 min |
| 10 | `n7_06_condition_tests.py` | `independence/` | loss vs grammaticality, position, accuracy, response time | 74 min (3 Oct) |
| 11 | `n7_07_export_inventory.py` | `cells/` | exported and importable trials per export | 10 min; 37 min (3 Oct) |
| 12 | `n7_08_presented_counts.py` | `cells/` | presented trials per cell | 16 min (3 Oct) |
| 13 | `n7_09_cells.py` | `cells/` | the cell table | 1 min |
| 14 | `n7_10_aligned_events.py` | `aligned/` | events aligned to the logs by trial key | 4 min; 13 min (3 Oct) |
| 15 | `n7_11_aligned_table.py` | `aligned/` | table for steps 16 and 17 | 2 min |
| 16 | `n7_12_retention_by_group.py` | `retention/` | retention by language, session, property and condition | 1 min |
| 17 | `n7_13_retention_models.R` | `retention/` | Mini-English Session 6 odds ratio; condition × session × language tests | 8 min; 46 min (3 Oct) |
| 18 | `n7_14_gender_trials.py` | `precision/` | gender-agreement single-trial data and raw lags | 30 min (3 Oct) |
| 19 | `n7_15_check_build.R` | `precision/` | the rebuilt data match the August fits | 18 min (3 Oct) |
| 20 | `n7_17_lag_counts.R` | `precision/` | trials a tolerant re-export adds per cell | a few minutes |
| 21 | `n7_19_run_precision.R` | `precision/` | runs every fit (`n7_16_fit_one.R`) and projection (`n7_18_project.R`) | a few hours |
| 22 | `n7_20_summarise_precision.R` | `precision/` | narrowing of the grammaticality × language interval | a few minutes |
| 23 | `make_audit_tables.py` | `results/` | the two tracked tables | seconds |

Steps 1 to 4, 5 to 7, 8 to 10, 11 to 17 and 18 to 22 are independent chains, and step 23 reads the
outputs of all of them. Step 16 needs steps 13 and 14, and step 17 needs steps 13 and 15.
`aligned_io.py` holds the readers of steps 14 and 15, `precision_common.R` the helpers of steps 19
to 22, and `audit_paths.py` and `audit_paths.R` the paths of every step. Step 1 reads exports and
histories with the parsers of `scripts/eeg_reconstruction/` (`bv_io.py`, `history.py`).

## Environment

Python 3.13.7 with pandas 2.3.2, numpy 2.3.2, scipy 1.17.1, statsmodels 0.14.6 and olefile 0.47
(`scripts/eeg_reconstruction/requirements.txt`). R 4.6.1 with lme4 2.0.1, data.table 1.18.4,
Matrix, readxl and here, as pinned in `renv.lock`. Only `n7_06` draws random numbers in Python,
and it uses a fixed seed (20260917). The R projections fix theirs (`n7_18`, `n7_16` when thinning).

## Two event tables

Steps 8 and 14 each build one row per recorded condition marker (64,427, with identical lags), by
different routes. Step 8 matches exports by clock and logs by code sequence; step 14 matches both
by trial key. The N7 assessment recommended keeping a single builder. Both are kept because the
archived figures of steps 10, 16 and 17 were computed on them, and moving an analysis to the other
builder would change its numbers slightly. They differ in one known place. Step 14's key includes
the property code, which the history recoded in Session 4 of lab ID 7, so 48 of that recording's
exported trials are unmatched there. Step 17 reports the effect of dropping that recording.

## What this audit concerns, and what it does not

The audit describes the legacy exports. Its "analysed" set is the one decided on 17 September
2026, which excludes the nine Session 3 records filtered at 1 Hz, the three invalid exports and
participant 14. The nine records have since been reprocessed and two of the invalid exports
recovered, and those enter the October fits. Their trials are not part of these counts. The
precision projection (steps 18 to 22) was made on the data and model conventions of
17 September: the cluster rows of the legacy pipeline, and the Session 2 correction c + FCz/2,
which ISSUES.md N8 replaced. Its `gstrial` structure, with a trial intercept and the
grammaticality × session slope, is the one closest to the October model. That model averages the
clusters of a macroregion within each trial and carries that slope (ISSUES.md N9).

Several analyses of the N7 assessment are not here, because no statement in the manuscript rests
on them or because they live elsewhere:

- the Session 2 reference correction, which is in `scripts/_config.R` and its tests (N8);
- the trial-dependence check of the ERP models, which was settled by the October model (N9);
- the check that discarded and kept trials are exchangeable. Amendment 5 specifies it, and its
  data come from the reprocessing code (`scripts/eeg_reconstruction/`);
- the amplitude consequence of the label offset, the OSF raw-data inventory, the design checks of
  target position, the Paper 2 resting-state reference, and the claim-by-claim verifier
  recomputations. Their results are in the N7 assessment report of 17 September 2026, which
  ISSUES.md cites and which is not in the repository.

## Verification

On 3 October 2026 steps 1 to 19 were run against a local copy of the data tree and their outputs
compared with the archived outputs of 16 and 17 September. Every table matched: byte for byte
once line endings were normalised, or with identical values where the archived file had been
assembled differently (one column of the archived identity table was empty, and its rows were in
another order). The text summaries differ only where a header says the script was changed. The
split-half on the grammatical and ungrammatical trials, the leave-one-out grand-average correlation
(step 3) and the paired-trial correlations (step 4) were never archived, so they had nothing to be
compared with; step 3's header gives the figures quoted in 2026 beside the reproducible ones.
Steps 20 to 22 were not re-run in full, because the lme4 fits take hours; `make_audit_tables.py`
takes the projection from the archived `projection_summary.csv` of 17 September.
