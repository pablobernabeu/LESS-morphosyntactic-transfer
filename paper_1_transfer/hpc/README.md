# Paper 1 — HPC / SLURM submission scripts (Oxford ARC / HTC)

> [!NOTE]
> The author approved treatments for `ISSUES.md` G04-01 and X5-01 on 16 September 2026: the
> 1 Hz records and participant 14 are excluded, through `LES_P1_MISFILTERED` and
> `LES_P1_PROTOCOL_DEVIATION` in `scripts/_config.R`. The same day's export audit
> (`ISSUES.md` N6) added three exports that do not contain their participant-session
> (`LES_P1_INVALID_EXPORTS`) and a correction bringing the Session-2 exports to the
> linked-mastoid reference, applied as each export is read (`les_p1_s2_rereference()`, called
> by the vendored importer `scripts/_eeg_import.R`). Every EEG stage, including 07, 07b and
> 08, reads the exports through that importer and applies the exclusions through `_config.R`. The exclusions are interim until the raw
> recordings are reprocessed under `docs/eeg_filter_reprocessing_protocol.md` (Amendments
> 2-4). ERP jobs submitted before the
> audit (HTC 8826186-8826204, 8826320-8826321) predate these exclusions and must not be pulled.

Bayesian model fitting for Paper 1 (*The Neurocognition of Longitudinal L3
Morphosyntactic Transfer*) runs on Oxford's SLURM clusters. Steps 01 to 05 (the core ERP
and accuracy models), the decoding array and the summaries behind the shipped results were
all ARC jobs, run in July and August 2026. HTC was adopted in principle on 2026-06-30, on
the grounds that every job here is single-node, which is HTC's high-throughput remit, and
that HTC is far less loaded. The move was deferred at the time in the expectation that
CmdStan would need rebuilding on HTC. The sensitivity refits submitted on 2026-09-01 and
2026-09-02 then ran on HTC against the existing CmdStan tree, the project `/data` space
being mounted at the same path on both clusters, so no rebuild was needed. The
gender-agreement decoding element resubmitted to ARC on 2026-09-03 ended out of memory,
and its rerun went to HTC. To send a job to
HTC, submit with `sbatch --clusters=htc --account=educ-intract <script>.slurm`, standard
QoS only and never `--qos=priority`. The `--account` flag is required on HTC even though
ARC does not need one. A plain `sbatch` with no `--clusters`, which is what
`submit_all.sh` issues, goes to the login node's default cluster, which is ARC, so the
recipes below submit to ARC as they stand. The headers of `07`, `07b`, `08`, `08b` and
`00_descriptives` give the HTC form. Both clusters use environment modules,
with no container: each job sources
[`_shared/hpc/arc_env.sh`](../../_shared/hpc/arc_env.sh),
which `module load`s R, points the R library + CmdStan + data + output store at
the project `/data` space, and `cd`s to the code root. `here::here()` then anchors on the
`LESS Project.Rproj` sentinel. Project access is via the `educ-intract` unix group.

See [`../../HPC_RUNBOOK.md`](../../HPC_RUNBOOK.md) for the full layout and the
dev-box → HPC transfer / render workflow.

### Software environment

`_shared/hpc/arc_env.sh` is the single source of truth for the toolchain. It runs
`module load R/4.5.1-gfbf-2025a` (R 4.5.1, GCC 14.2.0), points `CMDSTAN` at the
highest-numbered CmdStan installed under `$LES_BASE/cmdstan/` unless `LES_CMDSTAN_VERSION`
pins one, and builds CmdStan at `-O1` because of a GCC 14.2.0 compiler crash; see the
header of `_shared/hpc/arc_env.sh`.

Two records say what the fits ran under. `results/_provenance.csv` records the versions in
force at fit time (R, platform, brms, cmdstanr, rstan, StanHeaders, posterior, loo, projpred,
bayesplot, mgcv, MASS, dplyr, CmdStan, and the seeds), written by `_shared/R/04_provenance.R`.
Only `03_fit_erp.slurm` writes it, so a run confined to `04`, `05`, `07`, `07b` or
`08` leaves the file as the last ERP fitting run left it; per-fit versions are carried
alongside it in `results/_pooled_fit_metadata.csv`. The repository's `renv.lock` pins the R
side of the same environment, snapshotted on the cluster across both the project library and
the R module's own. `_shared/hpc/00_restore_environment.slurm` restores it with
`renv::restore()` and installs the pinned CmdStan, and `submit_all.sh with_restore` chains on
that job. CmdStan, the compiler and the `-O1` pin are not R packages and are not in the
lockfile. `00_install_dependencies.slurm` bootstraps a library where none exists, unpinned
from CRAN, and is not the reproduction route.

## One-time setup

The project R library (`$LES_BASE/Rlib/R-4.5`) initially held only the legacy frequentist
stack (lme4/lmerTest). The pinned route to the recorded environment is
`_shared/hpc/00_restore_environment.slurm`. The bootstrap below is for a library that does
not yet exist: it installs the Bayesian toolchain (brms, cmdstanr with CmdStan, posterior,
bayesplot, loo, papaja and the quarto R package, plus `eegUtils` for Paper 2) once, unpinned. It is shared with
Paper 2, so run only one of the two `00` scripts. Slurm opens a job's `-o` log before the
job body runs, so on a fresh deployment create the log directory first, or the job fails
without writing a log:

```bash
mkdir -p paper_1_transfer/hpc/logs
# as written this goes to the default cluster (ARC); prepend
# --clusters=htc --account=educ-intract to build on HTC instead
sbatch paper_1_transfer/hpc/00_install_dependencies.slurm
```

It builds into `Rlib/R-4.5` and `cmdstan/` using the gfbf/2025a toolchain (GCC 14.2.0 with
OpenBLAS, FlexiBLAS and FFTW) that the `R/4.5.1-gfbf-2025a` module brings in. That is not
the `foss` toolchain, which adds OpenMPI and ScaLAPACK on top of gfbf, so loading `foss`
instead would provision a different compiler stack from the one that built this library.
If a compute node lacks outbound network, run it on the `interactive` partition instead
(`srun -p interactive --pty bash`, then `source _shared/hpc/arc_env.sh && Rscript
_shared/install_bayesian_dependencies.R`).

## Pipeline (in order)

| Script | Array | Partition | What it does |
|--------|:-----:|:---------:|--------------|
| `00e_reprocess_eeg.slurm` | 0–12, then 0–8 | short | the protocol's gates, then the nine records at 0.1 Hz (see "EEG reprocessing" below; submitted only through `00e_submit_reprocessing.sh`) |
| `00f_assemble_eeg_overlay.slurm` | — | short | checks the nine records and copies them into the overlay the importer reads |
| `00g_recover_eeg.slurm` | 0–1, or single | short | recovery gates and re-segmentation of two misaligned records, rebuilt marker files, their assembly (see below; submitted only through `00g_submit_recovery.sh`) |
| `00h_trigger_check.slurm` | 0–7, then single | short | the trigger-rule check of Amendment 5: rebuilds and gates the eight 0.1 Hz comparison recordings and writes their events, then compares discarded with kept trials over all seventeen recordings (submitted only through `00h_submit_trigger_check.sh`; it feeds no analysis) |
| `01_extract_erp.slurm` | 0–5 | medium | single-trial ERP `.rds` per property × macroregion |
| `02_extract_accuracy.slurm` | — | short | accuracy `.rds` per property and participant-balanced group descriptives |
| `03_fit_erp.slurm` | 0–17 | long | brms Gaussian model per property × window × macroregion |
| `03b_prior_predictive.slurm` | — | short | the representative cell's prior predictive check exported as data for the manuscript's figure (sets `LES_P1_ITEM_SLOPE=1` itself; reads step 1's data for that cell and no fit) |
| `04_fit_accuracy.slurm` | 0–2 | long | brms Bernoulli model per property |
| `05_summaries.slurm` | — | short | pooled diagnostics, posterior summaries, retention contrasts, prior sensitivity, and the sensitivity and criterion contrasts of the accuracy models |
| `07_grand_average.slurm` | 0–5 | short | participant-balanced, time-resolved ERP waveforms per property × macroregion × miniature language × session, averaged within the nine `brain_region` clusters, baseline-corrected within participant, per session and pooled over sessions, plus the paired violation-minus-control difference waves (grand-average waveform and difference-wave figures) |
| `07b_grand_average_electrode.slurm` | 0–5 | short | participant-balanced electrode waveforms and participant-paired violation-minus-control differences for every a priori window, miniature language and session, baseline-corrected and pooled as in 07 (group-separated scalp topographies) |
| `08_decoding.slurm` (per_property, default) | 0–2 | long | per-property: extract the 31-channel decoding tensor, then run LOPO decoding (timecourse + session/language + cross-language + temporal generalisation). The job refuses a reduced permutation count or time step, which would overwrite the reported artefacts; the script header gives a by-hand recipe for a smoke test against a separate store |
| `08_decoding.slurm` (`--export=ALL,LES_DECODE_STAGE=cross_property`) | single task | long | cross-property generalisation (needs all 3 tensors from the per_property stage) |

Each job in the table runs the script of the same number in [`../README.md`](../README.md),
except `08_decoding.slurm`, whose per_property stage runs scripts 08 and 09 and whose
cross_property stage runs script 09.

The cross_property stage takes two mandatory overrides, `--array=0` and an explicit
`-o paper_1_transfer/hpc/logs/08_decoding_crossproperty_%A.out`. The script header
explains both. Submit it as soon as the three tensors exist in `data_derived/`, which
takes a couple of hours. Never chain it on the per_property array with `afterok`. It reads only
the tensors, so chaining leaves a three-minute analysis queued behind a fortnight of
permutation runs.

Three further scripts sit outside the linear pipeline and are submitted by hand:

- `00_descriptives.slurm` regenerates the light descriptive tables both manuscripts inject
  by running scripts 00c, 02, 00 and 00b in that order, then the retention test; its
  header lists every file each writes. It reads the single-trial cell files of step 01, so
  it runs after step 01. It fits nothing and must run with every variant switch unset.
  Slurm opens a job's `-o` file before the job's own `mkdir` runs, so on a fresh deployment
  create `paper_1_transfer/hpc/logs` once before submitting anything by hand.
- `08b_verify_gender_decoding.slurm` is a read-only watcher. Submit it to the cluster the
  decoding job runs on, because its `afterany` dependency and its `sacct` query both
  resolve job IDs only on the cluster the watcher runs on. For a decoding job submitted in
  the HTC form that the header of `08_decoding.slurm` gives, the command is
  `sbatch --clusters=htc --account=educ-intract --export=ALL,LES_DECODE_WATCH_JOB=<id>_0 --dependency=afterany:<id>_0 paper_1_transfer/hpc/08b_verify_gender_decoding.slurm`.
  Both halves are mandatory. Without the export the script exits before writing any status
  file, and the export is also what stops the watcher reporting on a superseded job. It
  records what a terminating decoding element actually produced (the array's `sacct`
  outcome, the three gender CSVs and each property's `n_perm` checked against the count in
  `_decoding_provenance.csv`, or 1000 without that record) into `GENDER_DECODING_STATUS.txt`
  at the code root.
  `afterany` rather than `afterok` because an element whose script file was
  overwritten mid-run exits non-zero even after writing every artefact.
- `99_diagnose_ice.slurm`, and its follow-up `99b_test_O2.slurm` — the retained
  compiler diagnostics for the GCC 14.2.0 `reduce_sum` crash, kept for re-measuring
  after a toolchain upgrade. See [`../../HPC_RUNBOOK.md`](../../HPC_RUNBOOK.md),
  "internal compiler error".

### EEG reprocessing (run before any EEG stage)

The nine Session-3 records filtered at 1 Hz are rebuilt from their raw recordings at 0.1 Hz
under `docs/eeg_filter_reprocessing_protocol.md`, by the Python code in
[`../scripts/eeg_reconstruction/`](../scripts/eeg_reconstruction/README.md). One command, on
the login node, builds the Python environment if it is missing and submits the chain:

```bash
cd ~/new_LESS && LES_CODE_COMMIT=<deployed commit> bash paper_1_transfer/hpc/00e_submit_reprocessing.sh
```

| Stage | Tasks | Accounts | Waits for |
|---|---|---|---|
| validate (`00e`) | 13: the nine records' 1 Hz gate, then the four margin-rule recordings | educ-lift 0–6, educ-intract 7–12 | — |
| reprocess (`00e`) | 9: one per record | educ-lift 0–4, educ-intract 5–8 | `afterok` on both validate arrays |
| assemble (`00f`) | 1 | educ-lift | `afterok` on both reprocess arrays |

Each stage is fail-closed. A reprocess task refuses to start unless all thirteen gates
passed under the same code, and the assembly refuses unless all nine records passed and
their staged files are unchanged. A failed gate therefore leaves everything after it
pending with `DependencyNeverSatisfied`. Read the failing task's log, then cancel the
remainder. Gate records, provenance and staging are in
`$LES_STORE/paper_1_transfer/data_derived/eeg_reprocessing/`, and the admitted files go to
`.../data_derived/eeg_overlay/`.

The importer will not read the overlay until its admission manifest is tracked, so after
the assembly: pull `eeg_reprocessing/eeg_overlay_manifest.candidate.csv` and
`provenance_manifest.csv`, review them, commit the first as
`paper_1_transfer/eeg_overlay_manifest.csv` and the second as
`paper_1_transfer/eeg_overlay_provenance.csv`, and deploy. Until then, any EEG stage run
with the importer stops with "The overlay holds files but the manifest lists none", which
is intended. The robustness analysis (`LES_P1_EXCLUDE_REPROCESSED=1`) drops the same
records whatever their source. The nine records were admitted this way on 30 September
2026 from the chain HTC 8920748-8920752 (code b9d9d28).

### Recovered records and rebuilt marker files (after the reprocessing)

Amendments 2, 3, 5 and 6 of the protocol add two recovered records (Session 6 of lab ID 5,
Session 2 of lab ID 7) and three rebuilt marker files (Session 3 of lab ID 17, Session 4 of
lab ID 34) to the overlay. `00g_submit_recovery.sh` submits the chain on HTC, each array
split across the accounts (gate and resegment: task 0 educ-lift, task 1 educ-intract;
markers educ-lift; assemble educ-intract), with each re-segmentation waiting for its own
gate:

```bash
cd ~/new_LESS && LES_CODE_COMMIT=<deployed commit> bash paper_1_transfer/hpc/00g_submit_recovery.sh
```

The assembly writes `eeg_reprocessing/recovery/eeg_overlay_manifest.recovery.candidate.csv`
and `recovery_provenance.csv`. Append the candidate rows to
`paper_1_transfer/eeg_overlay_manifest.csv`, track the provenance as
`paper_1_transfer/eeg_overlay_recovery_provenance.csv`, and deploy, before any EEG stage runs;
until then the importer refuses the overlay because it holds files the manifest does not list.
Both records and the three marker files were admitted this way on 2 October 2026 from the
chain HTC 8941218-8941223 (code 31d95c3).

### The trigger-rule check (Amendment 5)

`00h_submit_trigger_check.sh` runs the check of whether the trials the five-sample trigger
rule discards are exchangeable with those it keeps (see
`../scripts/eeg_reconstruction/README.md`). It needs the raw signal of the eight comparison
recordings in the data tree: Session 3 of lab IDs 10, 51, 58 and 59, placed for the margin
gate of 00e, and Session 2 of lab IDs 10, 11, 12 (two files, `12.eeg` and
`12-continued.eeg`) and 20, which come from OSF project tq7vy and are checked against OSF's
SHA-256. The submitter refuses to start without them. Its events stage runs one recording
per task (tasks 0-3 educ-lift, 4-7 educ-intract) and the analysis runs once, on all
seventeen recordings, after both halves:

```bash
cd ~/new_LESS && LES_CODE_COMMIT=<deployed commit> bash paper_1_transfer/hpc/00h_submit_trigger_check.sh
```

Pull `eeg_reprocessing/trigger_check/results/trigger_check_cells.csv` into
`paper_1_transfer/results/_trigger_check_cells.csv`; the manuscript's appendix reads it.

### Rerun every EEG stage from the admitted overlay

Once the overlay is admitted, `submit_eeg_rerun.sh` regenerates every Paper 1 EEG artefact
in one submission, as the protocol's release gate requires: descriptives, both
single-trial extractions (primary and robustness), the grand averages, the seven ERP fit
families the manuscript describes (maximal primary, base, weak-prior and retention-free
under both structures, maximal robustness), the primary decoding of all three properties, the
robustness decoding of the confirmatory family only, and the pooled summaries. It splits
every array across the two accounts, archives the superseded ERP and decoding artefacts
first, and prints everything without submitting unless `LES_SUBMIT=1` is set:

```bash
cd ~/new_LESS && bash paper_1_transfer/hpc/submit_eeg_rerun.sh            # dry run
cd ~/new_LESS && LES_SUBMIT=1 LES_CODE_COMMIT=<deployed commit> bash paper_1_transfer/hpc/submit_eeg_rerun.sh
```

The cross-property decoding stage is submitted afterwards, once the three primary tensors
exist.

### Submit everything with dependency chaining

```bash
cd ~/new_LESS
bash paper_1_transfer/hpc/submit_all.sh                # toolchain already installed
bash paper_1_transfer/hpc/submit_all.sh with_restore   # restore renv.lock first (pinned)
bash paper_1_transfer/hpc/submit_all.sh with_install   # bootstrap an unpinned library first
```

`--dependency=afterok` so fitting starts only after the matching extraction succeeds,
and the summary job only after all fits succeed. The chain covers `01` to `05` only.
`07`, `07b`, both stages of `08`, `08b` and `00_descriptives.slurm` are submitted by
hand, and the header of `submit_all.sh` lists them with their prerequisites. Submit individual
stages with plain `sbatch paper_1_transfer/hpc/<script>.slurm` if preferred. `submit_all.sh`
creates `paper_1_transfer/hpc/logs/` before its first `sbatch`, but a hand submission does
not. On a fresh deployment run `mkdir -p paper_1_transfer/hpc/logs` first, because Slurm
opens the job's `-o` log in that directory before the job body runs.

The chain exports no variant switches, so it produces the base random-effect ERP fits. The
`_itemslope` fits the manuscript reports as primary are not part of it: once `01` has
finished, submit
`sbatch --export=ALL,LES_P1_ITEM_SLOPE=1 paper_1_transfer/hpc/03_fit_erp.slurm`, then
re-run `05_summaries.slurm`, which pools every fit artefact present, so the summary CSVs
carry both structures. See "Analysis-variant switches" below.

`submit_all.sh` calls plain `sbatch`, so the whole chain goes to the default cluster
(ARC), and it takes no option for redirecting it. Running the chain on HTC would mean
editing the script to pass `--clusters=htc --account=educ-intract` at every call site.
Note that `sbatch --parsable` then returns `<jobid>;htc` rather than a bare number, and
that has to be trimmed before it can go into a `--dependency` spec.

## Resourcing rationale

- Fitting jobs request `--cpus-per-task=8` and set `LES_THREADS_PER_CHAIN=2`:
  `les_brm()` runs `LES_CHAINS = 4` chains, each with 2 within-chain (`reduce_sum`)
  threads → 4 × 2 = 8 CPUs (the Stan User's Guide on within-chain parallelisation, and the
  brms `threading()` vignette). The thread count also sets brms's grainsize, so it is pinned
  and the jobs only warn when it does not match the allocation. Memory is
  set via ARC's `--mem-per-cpu` (12 G/cpu × 8 = 96 G for the single-trial ERP fits).
- ERP extraction requests 48 G/cpu × 4 (192 G): the legacy merge loads the full
  single-trial EEG for one property at a time (the memory-bound step).
- Walltime for the single-trial ERP fits uses the `long` partition (5 days), which is
  well inside its 30-day maximum. Maximal random-effect models on tens of thousands of
  trials sample slowly, and the `-O1` compiler pin (see the runbook) slows them further.

## Outputs

- Derived data → `$LES_STORE/paper_1_transfer/data_derived/` (`/data/.../store/...`)
- Fitted models + diagnostics → `$LES_STORE/paper_1_transfer/results/`
- Per-job logs → `paper_1_transfer/hpc/logs/` (`.out` = SLURM, `.Rout` = R console)

## Analysis-variant switches

Every variant is opt-in through the environment, exported on the submission line
(`sbatch --export=ALL,VAR=value …`). With none of them set the pipeline reproduces the
default artefacts exactly. Every variant writes its own tagged fit, convergence, summary and
metadata files. One file is not tagged. `results/_provenance.csv` is rewritten at the end of
every fitting run whatever switches are set, so a sensitivity run leaves it describing that
run, and `recorded_utc` says which run wrote it. Restore the file from version control after
a variant run, submit the reported stage last, or export `LES_PROVENANCE_SKIP=1` with the
variant run.

| Variable | Value | Export it to | Artefact tag | What it selects |
|----------|-------|--------------|--------------|-----------------|
| `LES_P1_ITEM_SLOPE` | `1` | `03` | `_itemslope` | the maximal by-item random-effect structure. **This is the structure the manuscript reports as primary** (`LES_P1_PRIMARY <- "maximal"` in `paper_1_morphosyntax.qmd`), and `submit_all.sh` does not set it, so the reported ERP fits have to be submitted as `sbatch --export=ALL,LES_P1_ITEM_SLOPE=1 paper_1_transfer/hpc/03_fit_erp.slurm`. Without it the simpler base fits are produced and kept as the structural sensitivity comparison. |
| `LES_PRIOR_SET` | `weak` | `03`, `04` | `_weakprior` | the weakly-informative sensitivity baseline instead of the informative priors |
| `LES_P1_RETENTION_FREE` | `1` | `03` | `_retfree` | an explicit Session-6 offset, freeing the retention step from the training trend. Refused for verb–object number agreement, which has only two sessions. |
| `LES_P1_EXCLUDE_REPROCESSED` | `1` | `01`, `03`, `08` | `_exclreproc` | the robustness analysis prespecified by `docs/eeg_filter_reprocessing_protocol.md`: drop every participant-session in `LES_P1_MISFILTERED` or `LES_P1_INVALID_EXPORTS` whatever its source, including the reprocessed or recovered exports that the primary analysis reads from the overlay. It changes the data, so the extraction stage must be re-run under it before the fit stage. The decoding tensor and every `*_decoding_*.csv` output carry the tag, so a decoding run under it never overwrites the primary artefacts. It replaces `LES_P1_KEEP_MISFILTERED` (`_keepmisfiltered`), retired on 17 September 2026 with the cluster-row model it reproduced. |
| `LES_DECODE_ANALYSES` | `timecourse`, `crosslang`, `temporalgen` or `all` (default) | `08` | none | which per-property decoding stages run |
| `LES_DECODE_CONFIRMATORY_ONLY` | `1` | `08` (with `LES_DECODE_ANALYSES=timecourse`) | none | compute only the confirmatory overall time-course and skip the exploratory session blocks; used for the robustness arm, which reruns the confirmatory family only. `08_decoding.slurm` refuses it unless `LES_P1_EXCLUDE_REPROCESSED=1` is also set, because the primary artefacts carry no tag and would be cut to the overall block |
| `LES_P1_ACC_DIVERSITY` | `1` | `02`, `04` | `_diversity` | add the LHQ3 multilingual language diversity score to the accuracy models. Also data-changing: re-run `02` under it before `04`. |
| `LES_P1_ACC_RT_SCREEN` | `1` | `02`, `04` | `_rtscreen` | apply the legacy (200, 4000) ms reaction-time screen to the judgement trials. Since 19 October 2026 this is the sensitivity analysis of `ISSUES.md` G06-03, and the reported data keep every judgement with a finite, positive response time. Data-changing: re-run `02` under it before `04`. `submit_rt_screen_switch.sh` reruns every stage of both papers that the switch changes. Paper 2's trajectory extraction refuses it. The retired `LES_P1_ACC_NO_RT_SCREEN` (`_nortscreen`, the unscreened variant from when the screen was primary) now stops every script that reads the accuracy tags. |
| `LES_P1_ACC_MAXRANEF` | `1` | `04` | `_maxranef` | add the by-participant grammaticality x session slope to the accuracy models, the within-participant change in response bias that the reported structure omits (see the header of `scripts/04_fit_brms_accuracy.R`). Reads the reported data, so no re-extraction is needed; script 05 derives its sensitivity and criterion contrasts alongside the reported models'. |
| `LES_P1_ACC_ITEM` | `1` | `04` | `_byitem` | add the crossed by-item term `(1 + z_recoded_grammaticality + z_recoded_session \| item_id)`, the ERP models' item term, where an item is a sentence frame (language x sentence trigger; see the header of `scripts/04_fit_brms_accuracy.R`). Needs the `item_id` column step 02 writes; composes with `LES_P1_ACC_MAXRANEF` (`_maxranef_byitem`); script 05 derives its signal-detection contrasts. Pass an explicit `-o` per variant, as for every 04 variant. |
| `LES_PRIOR_PREDICTIVE` | `1` | `03`, `04` | `*_priorpc.png` | write a prior predictive check before fitting; changes no fit |
| `LES_P1_PRIORPC_REPRESENTATIVE` | `<cell_tag>` | `03`, with `LES_PRIOR_PREDICTIVE=1` | `prior_predictive_check.png` | copy the named cell's prior predictive check to the file the manuscript shows; see `../figures/README.md` |
| `LES_ITER_WARMUP`, `LES_ITER_SAMPLING` | an integer not below the default (2000, 8000) | `03` | none | run one cell longer when it misses the R-hat gate through slow mixing; move its cached fit aside first (brms does not refit on an iteration change). The fit metadata records the iterations, and the Method states any fit run longer |
| `LES_PROVENANCE_SKIP` | `1` | `03` | none | skip the run-level provenance write, so `results/_provenance.csv` keeps describing the reported fits |

The tags compose, in the order `_exclreproc`, `_weakprior`, `_itemslope`, `_retfree`
(see `cell_tag` in `scripts/03_fit_brms_erp.R`), so every combination caches to its own
file. Re-run `05_summaries.slurm` after any variant run: it pools every fit artefact
present, so the summary CSVs come to carry both the reported fits and the variants.
