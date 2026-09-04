# Paper 1 — The Neurocognition of Longitudinal L3 Morphosyntactic Transfer

Bayesian (brms) reanalysis of single-trial ERP amplitude and grammaticality-judgement
accuracy for three morphosyntactic properties (subject–verb gender agreement, differential
object marking [DOM], verb–object number agreement) across sessions S2/3/4/6, replacing the
legacy frequentist `lmerTest` pipeline. Target venue: *Journal of Neurolinguistics*, whose
requirements are recorded in [`journal_requirements.json`](journal_requirements.json).

> Provenance: the operational notes below were consolidated from the project's migration
> handoff (since retired, 2026-06-10). Authoritative detail lives in the script headers, the
> manuscript Methods, and `../_shared/R/`.

## Pipeline (`scripts/`, run in order)

| Step | Script | Runs | What |
|---|---|---|---|
| config | `scripts/_config.R` | — | analysis grid: 3 properties × 3 windows (200–500 / 300–600 / 400–900 ms) × 2 macroregions (lateral, midline) = **18 ERP cells**; model-ID naming |
| 0 | `scripts/00_extract_participants.R` | local | participant flow and demographics (`_sample_flow.csv`, `_participants.csv`), written to both papers' `results/` so the two cannot drift |
| 0b | `scripts/00b_audit_participant_flow.R` | local | per-participant × per-stage presence matrix and a consistency check on the stage totals (`_participant_matrix.csv`, `_flow_inconsistencies.csv`) |
| 0c | `scripts/00c_extract_erp_retention.R` | local | retained single-trial EEG per modelled cell (`_erp_trial_retention.csv`), so the Method injects the retention numbers rather than hard-coding them |
| 0d | `scripts/00d_extract_training_gate_flow.R` | local | the >80% post-training comprehension gate reconstructed per session (`_training_gate_flow.csv`), a non-random missingness mechanism both papers describe |
| 1 | `scripts/01_extract_erp_single_trials.R` | **HPC** | 18 single-trial ERP `.rds` (per-participant z-scored amplitude; baseline-as-covariate; unit-tested in `scripts/tests/`) |
| 1b | `scripts/01b_extract_rsvp_timing.R` | local | census of post-critical word-onset latencies over the raw OpenSesame logs (`rsvp_timing_overlap.rds`), the reproducible source of the Method's RSVP stimulus-overlap disclosure |
| 2 | `scripts/02_extract_accuracy.R` | local/HPC | 3 accuracy `.rds`, one per property, written to `data_derived/` |
| 3 | `scripts/03_fit_brms_erp.R` | **HPC** | Gaussian brms per cell |
| 4 | `scripts/04_fit_brms_accuracy.R` | **HPC** | Bernoulli brms per property |
| 5 | `scripts/05_posterior_summaries_and_contrasts.R` | **HPC** | pooled CSVs + S4→S6 retention contrast |
| 7 | `scripts/07_extract_grand_average_waveforms.R` | **HPC** | condition-averaged, time-resolved ERP waveforms, averaged within the nine `brain_region` clusters, for the grand-average and difference-wave figures |
| 7b | `scripts/07b_extract_grand_average_by_electrode.R` | **HPC** | the same extraction keeping the electrode dimension, which the interpolated scalp topography needs |
| 7c | `scripts/07c_extract_electrode_coordinates.R` | local | scalp coordinates of the recording montage, read from the study's own BrainVision headers (`_electrode_coordinates.csv`), for the topography figure |
| 8 | `scripts/08_extract_decoding_matrices.R` | **HPC** | per-trial [trial × 31-channel × time] decoding tensor per property (the 30 region-assigned scalp sites plus FCz; the accelerometer channels are excluded) |
| 9 | `scripts/09_run_decoding.R` | **HPC** | LOPO regularised-LDA decoding with permutation + Maris-Oostenveld cluster inference. Each cell's cluster test is family-wise-error controlled over time; a second BH-FDR layer then spans the confirmatory family alone, which is the pooled all-sessions time-course, one per property. The session-resolved, session-by-language, cross-language, cross-property and temporal-generalisation analyses are kept and reported as exploratory breakdowns, labelled in the `inference` column |
| 9b | `scripts/09b_assemble_confirmatory_timecourse.R` | local | **Opt-in, and called by nothing.** Assembles a decoding time-course CSV from step 9's per-block checkpoints, so that a confirmatory block recomputed at a higher permutation count can be combined with exploratory blocks still at the lower one. It fails closed on any disagreement between the checkpoints, and it changes no default code path |
| 10 | `scripts/10_extract_literature_trend.R` | local | Scopus counts of the L3-transfer literature by year and method (`_literature_trend.csv`), which the Introduction figure reads. Needs the non-CRAN package `scopusflow` (`pak::pak('pablobernabeu/scopusflow')`) and an Elsevier key in `SCOPUS_API_KEY`, read from `~/.Renviron` if the variable is not already set. Without both, the script stops and the manuscript falls back to its placeholders |

The decoding CSVs in `results/` carry two strata, which the `n_perm` column distinguishes.
The confirmatory rows, which are the pooled all-sessions time-course and the only family
the second-layer FDR spans, stand at 1000 permutations. The exploratory breakdowns are
still at 200, and the job that brings them up is on the cluster. That split is deliberate
and it settles the reported inference: the confirmatory family is complete, so no
cluster-level conclusion in the manuscript is waiting on the remaining job.

Two facts about earlier copies of these files are worth keeping in mind when comparing
against an older render. Their `cluster_p_fdr` column came from a superseded family that
pooled every cell of a property together, where the Method describes correcting over the
confirmatory family alone. They were also written at 200 permutations throughout, and at
200 step 9's admissibility guard refuses to compute the confirmatory FDR at all, because
the permutation floor 1/(B+1) reaches alpha/m. Both are fixed in the files now shipped.

The numbering has no step 6. `scripts/test_exclusion_guard.R` sits outside the pipeline
as the regression test for the mis-filtered-dataset exclusion and its staleness guard.
Run it after touching that logic.

Each folder below this one carries a readme of its own:
[`scripts/`](scripts/README.md) for the conventions and the opt-in script,
[`results/`](results/README.md) for what the manuscript reads and what writes it,
[`figures/`](figures/README.md) for the diagnostic images, and
[`hpc/`](hpc/README.md) for the submission recipes.

`data_derived/` is not in version control, so a fresh clone has none of it. Once step 2 has
run it holds the three accuracy datasets (gender agreement: 15916 trials /
64 ppts / acc 0.860; DOM: 11133 / 57 / 0.747; verb–object number: 6587 / 56 / 0.672). The ERP
single-trial `.rds` are produced on the HPC. The full EEG merge is HPC-scale, so do **not** run
`01_extract_erp` locally (its transform is validated synthetically by the unit test instead:
`Rscript --vanilla scripts/tests/test_summarise_cells.R`).

Heavy steps run on Oxford's SLURM clusters via environment modules, with no container.
See [`hpc/README.md`](hpc/README.md) for submission, resourcing, and cluster-specific
notes. Access is via the `educ-intract` unix group. Since 2026-06-30 the preferred
target for these single-node brms fits is HTC, submitted as
`sbatch --clusters=htc --account=educ-intract <script>.slurm`, standard QoS only and
never `--qos=priority`. A plain `sbatch`, which is what `hpc/submit_all.sh` uses, goes
to the login node's default cluster, ARC, where no `--account` is needed. The project
`/data` space is mounted at the same path on both clusters.

## Informative priors (+ sensitivity / prior-predictive runs)

Priors are informative and literature-derived: selective, sign-informed and
magnitude-regularising. They are defined in
[`../_shared/R/01_bayesian_settings.R`](../_shared/R/01_bayesian_settings.R) and justified in
full in the manuscript *Priors* section. In brief, the grammaticality prior in the 400–900 ms
window is negative, for the P600, and milder at 300–600 ms for the agreement properties. It is
neutral and wider for DOM, whose case-marking response is configuration-dependent. The
grammaticality × caudality prior is positive, the P600 being posterior-maximal. Priors are
centred on zero for the grammaticality × session × language transfer interaction, which is the
hypothesis under test, and for the early/LAN and hemisphere terms. Variance priors are generous,
and the accuracy intercept and session slope are positive. Because the ERP response is
per-participant z-scored, coefficients are already in within-participant SD units. The
literature supplies no defensible microvolt effect size, so magnitudes are set on sign and
regularisation, then validated with prior predictive checks.

Two optional runs (off by default), via env vars read in `01_bayesian_settings.R`:

```bash
# Both are cluster jobs: the ERP fits run on the HPC, not on the dev box. Submit them from
# the code root on the cluster, as in hpc/README.md, which lists every variant switch.
# Weakly-informative SENSITIVITY baseline, refitting everything into *_weakprior_* files:
sbatch --export=ALL,LES_PRIOR_SET=weak paper_1_transfer/hpc/03_fit_erp.slurm

# Prior PREDICTIVE checks before fitting, writing *_priorpc.png:
sbatch --export=ALL,LES_PRIOR_PREDICTIVE=1 paper_1_transfer/hpc/03_fit_erp.slurm
```

`../_shared/R/02_diagnostics.R` provides `les_prior_predictive_check()` and `les_prior_sensitivity()`
(informative-vs-weak posterior shift per coefficient).

## Rendering the manuscript

The manuscript renders at any time. Before the HPC fits, it shows `*[pending model fit]*`
placeholders and a "Reproducible draft" callout, which is the intended behaviour. Once the
HPC result CSVs are in `results/`, the placeholders populate themselves.

```bash
cd /path/to/your/clone     # the directory holding "LESS Project.Rproj"
quarto render paper_1_transfer/paper_1_morphosyntax.qmd --to html   # or --to pdf, or omit --to for both
```

Two blockers worth knowing about:

1. **The project `.Rprofile` and the R library.** It used to activate renv unconditionally,
   running `.libPaths("Rcache")` and `source("renv/activate.R")` in every R session Quarto or
   knitr started, which hid the real library. It is now guarded on both `renv/activate.R`
   existing and `renv/library/` being populated. A fresh clone has the first and not the
   second, because `renv/.gitignore` excludes the library, so R stays on the system library
   until someone runs `renv::restore()`. Do not run it here. `renv.lock` records the R side
   of the cluster fitting environment (Linux, R 4.5.1, brms 2.23.0, cmdstanr 0.9.0), and this
   box runs R 4.6.1 on Windows, so a restore would try to build packages pinned for a
   different R and platform. One lockfile cannot serve both. CmdStan and the compiler are not
   R packages and so are not in the lockfile at all; they are pinned in `../HPC_RUNBOOK.md`
   and recorded per run in `results/_provenance.csv`. The render environment is recorded in
   prose under **Environment (Windows dev box)** below. To be certain a render ignores renv,
   point `R_PROFILE_USER` at `paper_1_transfer/.render_profile.R`, which is kept empty for
   exactly that purpose. `Rscript` is not on this box's PATH, so call the interpreter by full
   path and add `--vanilla`: in PowerShell,
   `& "C:\Program Files\R\R-4.6.1\bin\Rscript.exe" --vanilla <script>.R`; in Git Bash,
   `"/c/Program Files/R/R-4.6.1/bin/Rscript.exe" --vanilla <script>.R`. Every bare `Rscript`
   elsewhere in this file is shorthand for that call.

2. **PDF needs LaTeX packages TinyTeX lacked, and its default mirror fails.** On this Windows/MINGW64
   box `tlmgr` exists only as `tlmgr.bat`, so `command -v tlmgr` fails and Quarto's auto-install does
   not trigger. Install manually, by full path, against the frozen historic mirror:
   ```bash
   TLMGR="$HOME/AppData/Roaming/TinyTeX/bin/windows/tlmgr.bat"
   "$TLMGR" option repository https://texlive.info/historic/systems/texlive/2025/tlnet-final
   "$TLMGR" install koma-script footnotehyper fontawesome5 pdfcol
   ```
   If a new "File `x.sty` not found" appears, install that package and re-render (a `mktexlsr` refresh
   once cleared a stale "tikzfill.image.sty not found"). The PDF engine is lualatex.

> Tip: `grep | tail` buffers all output until a long render finishes, so poll the `.log`/`.tex`
> artefacts instead. Quarto deletes the intermediate `.log` and `.tex` on success and keeps them
> on failure, so their absence is a good sign.

## Finishing Paper 1

1. Run the HPC chain (see [`hpc/README.md`](hpc/README.md)) → produces `results/*.csv`.
2. Pull `results/*.csv` back to the dev box.
3. Re-render (recipe above) → placeholders become real posterior medians, 95% CrIs, probabilities of
   direction, the convergence table, the ERP forest plot, and the retention table.
4. Sanity-check via `../_shared/R/02_diagnostics.R`: every model should show R̂ < 1.01, healthy
   bulk/tail ESS, 0 divergences, and an acceptable `pp_check`.
5. (Optional) run the `LES_PRIOR_SET=weak` sensitivity pass and report `les_prior_sensitivity()`.

## Environment (fitting: Oxford ARC / HTC)

The fits and the render run under different R versions on different platforms, and the two
should not be conflated. Fitting uses environment modules, with no container involved.
[`../_shared/hpc/arc_env.sh`](../_shared/hpc/arc_env.sh) loads `R/4.5.1-gfbf-2025a` (R 4.5.1
on `x86_64-pc-linux-gnu`, with the gfbf/2025a toolchain built on GCC 14.2.0) and points
`R_LIBS_USER` at the project library `/data/educ-intract/educ1242/new_LESS/Rlib/R-4.5`. It
also pins `CXXFLAGS_OPTIM = -O1` in CmdStan's `make/local`, because GCC 14.2.0 crashes while
instantiating Stan's `reduce_sum` templates at higher optimisation levels (see
[`../HPC_RUNBOOK.md`](../HPC_RUNBOOK.md)). CmdStan and that compiler flag are not R packages,
so no lockfile can record them, and those two files are where they are written down.

Package versions are not restated here, because the run records them itself.
`results/_provenance.csv` (`component, version, recorded_utc`) is written by
[`../_shared/R/04_provenance.R`](../_shared/R/04_provenance.R) from
`scripts/03_fit_brms_erp.R`, and holds the R, brms, cmdstanr, rstan, StanHeaders, posterior,
loo, projpred, bayesplot and CmdStan versions of the run that produced the results, together
with the seeds `LES_SEED` and `LES_DECODE_SEED`. The manuscript injects those values inline,
so that file is the authority wherever any list disagrees with it. The R side of the same
environment is pinned in the repository's `renv.lock`.

## Environment (Windows dev box)

- R 4.6.1 at `C:\Program Files\R\R-4.6.1\bin\Rscript.exe`, which is not on PATH, so call it
  by full path. Local packages include `rmarkdown, knitr, here, dplyr, ggplot2, papaja,
  tinytex, pdftools`, plus `depictr` (not on CRAN), which supplies the figure theme and the
  Okabe–Ito palette both manuscripts use. The `depictr` load is guarded, so a render without
  it still succeeds, but every figure silently falls back to `theme_minimal()` and a
  hand-coded palette while the Methods still credit depictr. `brms` and `cmdstanr` happen to
  be installed here too, at the same versions as the cluster, but the Stan stack under them
  is not: this box has rstan and StanHeaders 2.39.0.9000 and loo 2.10.1 against the cluster's
  2.32.7, 2.32.10 and 2.9.0. Nothing in this compendium fits models locally, and `projpred`,
  `eegUtils` and `osfr` are absent here.
- Quarto 1.10.18 at `C:\Program Files\Quarto\bin\quarto.exe`, which is the `quarto` found on
  PATH and therefore the one the render recipe above invokes. An older standalone 1.9.37 also
  sits under `C:\Users\pablob\AppData\Local\Programs\Quarto\bin` and is not what renders these
  manuscripts. knitr 1.51 supplies the render engine. The `apaquarto` extension the `.qmd`
  format depends on is vendored under each paper's `_extensions/`, so it needs no separate
  install. These versions are recorded here in prose on purpose: `renv.lock` pins the cluster
  fitting environment and must not be restored on this box.
- TinyTeX at `~/AppData/Roaming/TinyTeX`.
- Legacy data loaders assume the working directory is the project root, so leave them
  alone and anchor new scripts with `here::here()` / `setwd(here::here())`.
- Data-path note: behavioural data exists under both `data/behavioural...` and
  `data/raw data/behavioural...`. The `data/raw data/` copy is canonical, being the one the
  importers read.

## Design rationale & references

The main methodological choices are documented with citations in the manuscript Methods and
in the script headers. They fall into three groups. The model: Bayesian brms replacing
`lmerTest`, the combined language × grammaticality × session specification (typological
proximity *is* an interaction), a single-trial DV with the baseline as a covariate, and a
Bernoulli GLMM for accuracy. The random-effects and predictor structure: maximal-by-design
correlated random effects, z-scored predictors, and by-participant random effects only for
accuracy, with no by-item term because those sentences are procedurally generated, whereas
the ERP models keep by-item terms because that sentence-marker set is fixed. The
computational and reporting policy: the cmdstanr backend with `reduce_sum` threading, the
diagnostics (R̂, ESS, divergences, `pp_check`, PSIS-LOO), and reporting as median, 95% CrI and
probability of direction. All cited works are in `references.bib` (Crossref-verified).
The original design notes named some further anchor references that the manuscript text does
not currently cite: Bates et al. 2015 (lme4), Smith & Kutas 2015, Nalborczyk et al. 2019, and
Aust & Barth (papaja). Add one only if a specific Methods claim comes to need it, never for
its own sake. Boettiger 2015 and a general HMC/NUTS conceptual reference are already covered
by citations in current use (`marwick2018`, `schad2021`).
