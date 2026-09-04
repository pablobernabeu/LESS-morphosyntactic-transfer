# Paper 1 — HPC / SLURM submission scripts (Oxford ARC / HTC)

Bayesian model fitting for Paper 1 (*The Neurocognition of Longitudinal L3
Morphosyntactic Transfer*) runs on Oxford's SLURM clusters. Steps 01-05 (the
core ERP/accuracy models) were submitted on ARC, and every heavy job to date has in
fact run there: as of 2026-08 the ERP fits, the decoding array and the summaries are
all ARC jobs. HTC was adopted in principle on 2026-06-30, on the grounds that every
job here is single-node, which is HTC's high-throughput remit, and that HTC is far
less loaded. The move was deliberately not made at the time, because CmdStan would
have to be rebuilt on HTC first. Treat HTC as the intended destination for new work
rather than as a description of where the current results came from. To send a job
there, submit with `sbatch --clusters=htc --account=educ-intract <script>.slurm`,
standard QoS only and never `--qos=priority`. The `--account` flag is required on HTC
even though ARC does not need one. A plain `sbatch` with no `--clusters` goes to the
login node's default cluster, which is ARC, so the recipes below submit to ARC as
they stand. Both clusters
use environment modules rather than a container: each job sources
[`_shared/hpc/arc_env.sh`](../../_shared/hpc/arc_env.sh),
which `module load`s R, points the R library + CmdStan + data + output store at
the project `/data` space (shared across both clusters at the same path), and
`cd`s to the code root (`~/new_LESS`). `here::here()` then anchors on the
`LESS Project.Rproj` sentinel. Project access is via the `educ-intract` unix group.

See [`../../HPC_RUNBOOK.md`](../../HPC_RUNBOOK.md) for the full layout and the
dev-box → HPC transfer / render workflow.

### Software environment

`_shared/hpc/arc_env.sh` is the single source of truth for the toolchain. It runs
`module load R/4.5.1-gfbf-2025a` (R 4.5.1, GCC 14.2.0), points `CMDSTAN` at the
highest-numbered CmdStan installed under `$LES_BASE/cmdstan/` unless `LES_CMDSTAN_VERSION`
pins one, and appends `CXXFLAGS_OPTIM = -O1` to `$CMDSTAN/make/local`, because GCC 14.2.0
raises an internal compiler error on Stan's `reduce_sum` templates at `-O2` and above.

Two records say what the fits ran under. `results/_provenance.csv` records the versions in
force at fit time (R, platform, brms, cmdstanr, rstan, StanHeaders, posterior, loo, projpred,
bayesplot, mgcv, MASS, dplyr, CmdStan, and the seeds), written by `_shared/R/04_provenance.R`.
Only stage 2a (`03_fit_erp.slurm`) writes it, so a run confined to `04`, `05`, `07`, `07b` or
`08` leaves the file as the last ERP fitting run left it; per-fit versions are carried
alongside it in `results/_pooled_fit_metadata.csv`. The repository's `renv.lock` pins the R
side of the same environment, snapshotted on the cluster across both the project library and
the R module's own, so `renv::restore()` rebuilds it. CmdStan, the compiler and the `-O1` pin
are not R packages and are not in the lockfile; `00_install_dependencies.slurm` installs
unpinned from CRAN and is a bootstrap rather than a restore.

## One-time setup

The project R library (`/data/educ-intract/educ1242/new_LESS/Rlib/R-4.5`) initially held
only the legacy frequentist stack (lme4/lmerTest). Install the Bayesian toolchain
(brms + CmdStan, posterior, bayesplot, tidybayes, bayestestR, papaja, and the Paper 2
resting-state packages) once. It is shared with Paper 2, so run only one of the two `00`
scripts:

```bash
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

| Stage | Script | Array | Partition | What it does |
|------:|--------|:-----:|:---------:|--------------|
| 1a | `01_extract_erp.slurm` | 0–5 | medium | single-trial ERP `.rds` per property × macroregion |
| 1b | `02_extract_accuracy.slurm` | — | short | accuracy `.rds` per property |
| 2a | `03_fit_erp.slurm` | 0–17 | long | brms Gaussian model per property × window × macroregion |
| 2b | `04_fit_accuracy.slurm` | 0–2 | long | brms Bernoulli model per property |
| 3  | `05_summaries.slurm` | — | short | pooled diagnostics, posterior summaries, retention contrasts |
| 4  | `07_grand_average.slurm` | 0–5 | short | condition-averaged, time-resolved ERP waveforms per property × macroregion, averaged within the nine `brain_region` clusters (grand-average waveform and difference-wave figures) |
| 4b | `07b_grand_average_electrode.slurm` | 0–5 | short | the same extraction keeping the electrode dimension, which the interpolated scalp topography needs (a map built from nine cluster means would invent spatial detail) |
| 5a | `08_decoding.slurm` (per_property, default) | 0–2 | long | per-property: extract the 31-channel decoding tensor, then run LOPO decoding (timecourse + session/language + cross-language + temporal generalisation) — see the script header for a fast smoke-test override |
| 5b | `08_decoding.slurm` (`--export=ALL,LES_DECODE_STAGE=cross_property`) | single task | long | cross-property generalisation (needs all 3 tensors from 5a) |

Stage 5b takes two mandatory overrides, `--array=0` and an explicit
`-o paper_1_transfer/hpc/logs/08_decoding_crossproperty_%A.out`. The script header
explains both. Submit it as soon as the three tensors exist in `data_derived/`, which
takes a couple of hours. Never chain it on the 5a array with `afterok`. It reads only
the tensors, so chaining leaves a three-minute analysis queued behind a fortnight of
permutation runs.

Two further scripts sit outside the linear pipeline and are submitted by hand:

- `08b_verify_gender_decoding.slurm` — a read-only watcher, submitted as
  `sbatch --export=ALL,LES_DECODE_WATCH_JOB=<id>_0 --dependency=afterany:<id>_0 paper_1_transfer/hpc/08b_verify_gender_decoding.slurm`.
  Both halves are mandatory. The script runs under `set -o nounset` and expands
  `LES_DECODE_WATCH_JOB` unguarded when it queries `sacct`, so a submission without the
  export aborts there and leaves a truncated status file with no artefact audit in it; the
  export is also what stops the watcher reporting on a superseded job. It records what a
  terminating
  decoding element actually produced (the array's `sacct` outcome, the three gender
  CSVs, the per-property `n_perm`) into `~/new_LESS/GENDER_DECODING_STATUS.txt`.
  `afterany` rather than `afterok` because an element whose script file was
  overwritten mid-run exits non-zero even after writing every artefact.
- `99_diagnose_ice.slurm`, and its follow-up `99b_test_O2.slurm` — the retained
  compiler diagnostics for the GCC 14.2.0 `reduce_sum` crash, kept for re-measuring
  after a toolchain upgrade. See [`../../HPC_RUNBOOK.md`](../../HPC_RUNBOOK.md),
  "internal compiler error".

### Submit everything with dependency chaining

```bash
cd ~/new_LESS
bash paper_1_transfer/hpc/submit_all.sh                # toolchain already installed
bash paper_1_transfer/hpc/submit_all.sh with_install   # install toolchain first
```

`--dependency=afterok` so fitting starts only after the matching extraction succeeds,
and the summary job only after all fits succeed. The chain covers stages 1a to 3 only.
Stages 4, 4b, 5a and 5b (`07`, `07b`, `08`) are submitted by hand. Submit individual
stages with plain `sbatch paper_1_transfer/hpc/<script>.slurm` if preferred.

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
  threads → 4 × 2 = 8 CPUs (Carpenter et al., 2017, *J. Stat. Soft.* 76(1)). Memory is
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
default artefacts exactly. Each variant writes its own tagged files, so a variant run never
clashes with the reported one or with another variant.

| Variable | Value | Export it to | Artefact tag | What it selects |
|----------|-------|--------------|--------------|-----------------|
| `LES_P1_ITEM_SLOPE` | `1` | 2a (`03`) | `_itemslope` | the maximal by-item random-effect structure. **This is the structure the manuscript reports as primary** (`LES_P1_PRIMARY <- "maximal"` in `paper_1_morphosyntax.qmd`), and `submit_all.sh` does not set it, so the reported ERP fits have to be submitted as `sbatch --export=ALL,LES_P1_ITEM_SLOPE=1 paper_1_transfer/hpc/03_fit_erp.slurm`. Without it the simpler base fits are produced and kept as the structural sensitivity comparison. |
| `LES_PRIOR_SET` | `weak` | 2a (`03`), 2b (`04`) | `_weakprior` | the weakly-informative sensitivity baseline instead of the informative priors |
| `LES_P1_RETENTION_FREE` | `1` | 2a (`03`) | `_retfree` | an explicit Session-6 offset, freeing the retention step from the training trend. Refused for verb–object number agreement, which has only two sessions. |
| `LES_P1_KEEP_MISFILTERED` | `1` | 1a (`01`), 2a (`03`) | `_keepmisfiltered` | retain the four 1 Hz Session-3 datasets the primary analysis drops. It changes the data, so the extraction stage must be re-run under it before the fit stage. Do not export it to the decoding stage (`08`): that stage honours it, but neither its tensor nor its `*_decoding_*.csv` outputs are tagged, so a decoding run under this variable overwrites the reported decoding artefacts at their reported names. |
| `LES_P1_ACC_DIVERSITY` | `1` | 1b (`02`), 2b (`04`) | `_diversity` | add the LHQ3 multilingual language diversity score to the accuracy models. Also data-changing: re-run `02` under it before `04`. |
| `LES_PRIOR_PREDICTIVE` | `1` | 2a (`03`), 2b (`04`) | `*_priorpc.png` | write a prior predictive check before fitting; changes no fit |

The tags compose, in the order `_keepmisfiltered`, `_weakprior`, `_itemslope`, `_retfree`
(see `cell_tag` in `scripts/03_fit_brms_erp.R`), so every combination caches to its own
file. Re-run `05_summaries.slurm` after any variant run: it pools every fit artefact
present, so the summary CSVs come to carry both the reported fits and the variants.
