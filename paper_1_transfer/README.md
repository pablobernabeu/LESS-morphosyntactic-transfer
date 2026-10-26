# Paper 1 — The Neurocognition of Longitudinal L3 Morphosyntactic Transfer

Bayesian (brms) reanalysis of single-trial ERP amplitude and grammaticality-judgement
accuracy for three morphosyntactic properties (subject–verb gender agreement, differential
object marking [DOM], verb–object number agreement) across sessions S2/3/4/6, replacing the
legacy frequentist `lmerTest` pipeline. Target venue: *Journal of Neurolinguistics*, whose
requirements are recorded in [`journal_requirements.json`](journal_requirements.json).
Authoritative detail lives in the script headers, the manuscript Methods, and `../_shared/R/`.

> [!NOTE]
> The two source-data policies that once held back the figures are decided and encoded
> once, in `scripts/_config.R`, for the behavioural, ERP and decoding pipelines alike: the
> nine Session-3 records filtered at 1 Hz (`LES_P1_MISFILTERED`; reprocessed at 0.1 Hz
> and admitted through `eeg_overlay_manifest.csv`, `ISSUES.md` G04-01) and participant
> 14's Session-2 language deviation (`LES_P1_PROTOCOL_DEVIATION`, X5-01). Every EEG stage
> was rerun under both in October 2026, and the last decoding run finished on 18 October.

## Pipeline (`scripts/`, run in order)

| Step | Script | Runs | What |
|---|---|---|---|
| config | `scripts/_config.R` | — | analysis grid: 3 properties × 3 windows (200–500 / 300–600 / 400–900 ms) × 2 macroregions (lateral, midline) = **18 ERP cells**; model-ID naming |
| 0 | `scripts/00_extract_participants.R` | HPC (store) | participant flow, demographics and the further languages reported (`_sample_flow.csv`, `_participants.csv`, `_participants_other_languages.csv`), written to both papers' `results/` so the two cannot drift. **Runs after step 2**: it counts participants in step 2's accuracy files, Paper 2's derived files (its steps 01-03) and `data/EEG_trial_count_per_condition.csv`, so it runs where both papers' `data_derived/` exist |
| 0b | `scripts/00b_audit_participant_flow.R` | HPC (store) | per-participant × per-stage presence matrix and a consistency check on the stage totals (`_participant_matrix.csv`, `_flow_inconsistencies.csv`), written to both papers' `results/`. Runs after step 0, whose flow it reconciles, and needs the same inputs |
| 0c | `scripts/00c_extract_erp_retention.R` | local/HPC | retained single-trial EEG per modelled cell (`_erp_trial_retention.csv`) and the share of the Session-3 observations held by the mis-filtered datasets (`_misfiltered_share.csv`), so the Method injects both numbers |
| 0d | `scripts/00d_extract_training_gate_flow.R` | local | audit reconstruction of first- and second-attempt post-training comprehension outcomes (`_training_gate_flow.csv`), written to both papers' `results/`; neither manuscript reports it because its counts do not reconcile with Session-4 attendance |
| 1 | `scripts/01_extract_erp_single_trials.R` | **HPC** | 18 single-trial ERP `.rds`, one row per trial (the equally weighted mean of the macroregion's clusters; per-participant z-scored amplitude; baseline-as-covariate; unit-tested in `scripts/tests/`). Reads the exports through the vendored importer `scripts/_eeg_import.R`, which applies the Session-2 reference correction and admits reprocessed files only through `eeg_overlay_manifest.csv` |
| 1b | `scripts/01b_extract_rsvp_timing.R` | local | census of post-critical word-onset latencies over the raw OpenSesame logs (`rsvp_timing_overlap.rds`, with its scalar fields as one tracked row in `_rsvp_timing.csv`), the reproducible source of the Method's RSVP stimulus-overlap disclosure |
| 2 | `scripts/02_extract_accuracy.R` | local/HPC | 3 accuracy `.rds`, one per property, written to `data_derived/` (with the `item_id` the by-item accuracy variant uses), plus the reaction-time screen (`_accuracy_rt_screen.csv`), per-session sentence inventory (`_accuracy_sentence_inventory.csv`), item inventory (`_accuracy_item_inventory.csv`), input-gap census (`_accuracy_input_gaps.csv`) and participant-balanced group descriptives (`_accuracy_by_language.csv`) |
| 3 | `scripts/03_fit_brms_erp.R` | **HPC** | Gaussian brms per cell |
| 3b | `scripts/03b_export_prior_predictive.R` | **HPC** | the representative cell's prior predictive check as data (`_prior_predictive_check.csv` and `_prior_predictive_check_meta.csv`), from which the manuscript draws its prior predictive figure; a prior-only model that reads the cell's step-1 data and no fit |
| 4 | `scripts/04_fit_brms_accuracy.R` | **HPC** | Bernoulli brms per property |
| 5 | `scripts/05_posterior_summaries_and_contrasts.R` | **HPC** | pooled CSVs (`_pooled_convergence.csv`, `_pooled_posterior_summaries.csv`, `_pooled_fit_metadata.csv`), the S4→S6 retention contrasts (`_retention_contrasts.csv`), the first-session language advantage (`_first_session_language_advantage.csv`), the prior sensitivity (`_prior_sensitivity.csv`) and the accuracy models' sensitivity and criterion contrasts (`_accuracy_sdt_contrasts.csv`) |
| 7 | `scripts/07_extract_grand_average_waveforms.R` | **HPC** | participant-balanced, time-resolved ERP waveforms by miniature language and session, averaged within the nine `brain_region` clusters, for the grand-average and difference-wave figures; uses the configured primary EEG exclusions |
| 7b | `scripts/07b_extract_grand_average_by_electrode.R` | **HPC** | participant-balanced waveforms by miniature language, session and electrode, plus participant-paired ungrammatical-minus-grammatical summaries (violation minus control) for all a priori windows; feeds the group-separated scalp topographies and uses the configured primary EEG exclusions |
| 7c | `scripts/07c_extract_electrode_coordinates.R` | local | scalp coordinates of the recording montage, read from the study's own BrainVision headers (`_electrode_coordinates.csv`), for the topography figure |
| 8 | `scripts/08_extract_decoding_matrices.R` | **HPC** | per-trial [trial × 31-channel × time] decoding tensor per property (the 30 region-assigned scalp sites plus FCz; the accelerometer channels are excluded) |
| 9 | `scripts/09_run_decoding.R` | **HPC** | LOPO regularised-LDA decoding with permutation + Maris-Oostenveld cluster inference. Each cell's cluster test is family-wise-error controlled over time; a second BH-FDR layer then spans the confirmatory family alone, which is the pooled all-sessions time-course, one per property. The session-resolved, session-by-language, cross-language, cross-property and temporal-generalisation analyses are kept and reported as exploratory breakdowns, labelled in the `inference` column |
| 9b | `scripts/09b_assemble_confirmatory_timecourse.R` | local | **Opt-in, and called by nothing.** Writes a decoding time-course CSV from step 9's banked per-block checkpoints before every block has finished, each tied by its fingerprint to the tensor on disk, so that a confirmatory block recomputed at a higher permutation count can sit beside exploratory blocks at a lower one. It never carries rows over from an existing CSV, fails closed on any disagreement, and changes no default code path |
| 10 | `scripts/10_extract_literature_trend.R` | local | Scopus counts of the L3-transfer literature by year and method (`_literature_trend.csv`), which the Introduction figure reads. Needs `scopusflow` 0.4.0 from [CRAN](https://CRAN.R-project.org/package=scopusflow) (`pak::pkg_install("scopusflow@0.4.0")`) and an Elsevier key in `SCOPUS_API_KEY`, read from `~/.Renviron` if the variable is not already set. Without either requirement, the script stops without replacing the committed counts |

The table is in script-number order, not run order. Steps 0 and 0b read step 2's output,
and 0c reads step 1's. The light descriptive tables of rows 0, 0b, 0c and 2 are
regenerated on the cluster, after step 1, by `hpc/00_descriptives.slurm`. It runs scripts
00c, 02, 00 and 00b in that order with every variant switch unset, and fits nothing.

Two files the manuscript reads come from Paper 2's pipeline. `results/_task_durations_home.csv`
and `results/_task_durations_lab.csv` are written into both papers' `results/` by
`../_shared/R/07_task_durations.R`, which Paper 2's stage 13 runs
(`../paper_2_plasticity/scripts/13_extract_task_durations.R`, submitted as
`../paper_2_plasticity/hpc/13_extract_task_durations.slurm`). No Paper 1 step rewrites them.

The decoding CSVs in `results/` come from the October 2026 rerun on the corrected sample
(HTC 8960051-8960055, cross-property 9013904) at 1000 permutations, with the robustness
arm (`*_exclreproc_decoding_timecourse.csv`). Every property's run has finished, and all
of its files are final. Verb-object number agreement's files were pulled on 10 October,
differential object marking's (8960052_1) on 15 October, and gender agreement's
(8960051_0, resumed past its wall as 9060385 and then 9124642) on 18 October. The
confirmatory rows of the last two had first been assembled from their banked pooled blocks
by `scripts/09b_assemble_confirmatory_timecourse.R` (HTC 9029773), and the finished runs
reproduced them exactly.

The numbering has no step 6. `scripts/test_exclusion_guard.R` sits outside the pipeline
as the regression test for the mis-filtered-dataset exclusion and its staleness guard.
Run it after touching that logic. `scripts/tests/` holds the synthetic unit test of step
1's transform and the check that pins the headline values of the retention artefact step
0c writes.

Each folder below this one carries a readme of its own:
[`scripts/`](scripts/README.md) for the conventions and the opt-in script,
[`results/`](results/README.md) for what the manuscript reads and what writes it,
[`figures/`](figures/README.md) for the diagnostic images, and
[`hpc/`](hpc/README.md) for the submission recipes.

`data_derived/` is not in version control, so a fresh clone has none of it. Once step 2 has
run it holds the three accuracy datasets, one per property. Their trial and participant
counts are recorded per fit in `results/_pooled_fit_metadata.csv` (columns `n_obs`,
`n_participants`) and are not restated here. The ERP single-trial `.rds` are produced on
the HPC. The full EEG merge is HPC-scale, so do **not** run `01_extract_erp` locally (its
transform is validated synthetically by the unit test instead:
`Rscript --vanilla scripts/tests/test_summarise_cells.R`).

Heavy steps run on Oxford's SLURM clusters via environment modules, with no container.
See [`hpc/README.md`](hpc/README.md) for submission, resourcing, and cluster-specific
notes. Access is via the `educ-intract` unix group. Which cluster a job goes to, and the
submit line for each, is set out once in [`../HPC_RUNBOOK.md`](../HPC_RUNBOOK.md) under
"ARC or HTC".

## Informative priors (+ sensitivity / prior-predictive runs)

Priors are informative and literature-derived: selective, sign-informed and
magnitude-regularising. They are defined in
[`../_shared/R/01_bayesian_settings.R`](../_shared/R/01_bayesian_settings.R) and justified in
full in the manuscript *Priors* section. In brief, the grammaticality prior in the 400–900 ms
window is negative, for the P600, and milder at 300–600 ms for the agreement properties. It is
neutral and wider for DOM, whose case-marking response is configuration-dependent. Priors are
centred on zero for the grammaticality × session × language transfer interaction, which is the
hypothesis under test, and for the early/LAN terms. The models carry no topographic terms: since
17 September 2026 they take one row per trial per macroregion (the clusters' mean), so the
positive grammaticality × caudality prior went with the caudality term. Variance priors are generous,
and the accuracy intercept and session slope are positive. Because the ERP response is
per-participant z-scored, coefficients are already in within-participant SD units. The
literature supplies no defensible microvolt effect size, so magnitudes are set on sign and
regularisation, then validated with prior predictive checks.

Two optional runs are off by default and selected through environment variables.
`LES_PRIOR_SET` is read in `01_bayesian_settings.R`, and `LES_PRIOR_PREDICTIVE` in scripts
03 and 04.

```bash
# Both are cluster jobs: the fits run on the HPC, not on the dev box. Submit them from
# the code root on the cluster, as in hpc/README.md, which lists every variant switch.
# Weakly-informative SENSITIVITY baseline, written to *_weakprior* files. The committed
# results/_prior_sensitivity.csv pairs the base and maximal ERP structures and the accuracy
# models with their weak-prior refits, so it takes three runs. LES_PROVENANCE_SKIP=1 keeps
# results/_provenance.csv describing the reported fits. Script 04 writes no provenance.
sbatch --export=ALL,LES_PRIOR_SET=weak,LES_PROVENANCE_SKIP=1 paper_1_transfer/hpc/03_fit_erp.slurm                      # base
sbatch --export=ALL,LES_P1_ITEM_SLOPE=1,LES_PRIOR_SET=weak,LES_PROVENANCE_SKIP=1 paper_1_transfer/hpc/03_fit_erp.slurm  # maximal (primary)
sbatch --export=ALL,LES_PRIOR_SET=weak paper_1_transfer/hpc/04_fit_accuracy.slurm
# Then re-run step 5, which pairs each fit with its weak-prior refit and writes
# results/_prior_sensitivity.csv:
sbatch paper_1_transfer/hpc/05_summaries.slurm

# Prior PREDICTIVE checks before fitting, writing *_priorpc.png:
sbatch --export=ALL,LES_PRIOR_PREDICTIVE=1 paper_1_transfer/hpc/03_fit_erp.slurm
# The manuscript's prior predictive figure: the representative cell's check exported as
# data (results/_prior_predictive_check*.csv), which the figure is drawn from at render time:
sbatch --clusters=htc --account=educ-lift paper_1_transfer/hpc/03b_prior_predictive.slurm
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

1. **The project `.Rprofile` and the R library.** `.Rprofile` activates renv only when
   `renv/activate.R` exists and `renv/library/` is populated, for the reasons the file itself
   gives. A fresh clone has the first and not the second, because `renv/.gitignore` excludes
   the library, so R stays on the system library until someone runs `renv::restore()`. Do not
   run it here. `renv.lock` records the R side
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
5. Once the weak-prior refits above exist, re-run pipeline step 5 (`hpc/05_summaries.slurm`). It
   writes `results/_prior_sensitivity.csv`, which the manuscript reports inline.

## Environment (fitting: Oxford ARC / HTC)

The fits and the render run under different R versions on different platforms, and the two
should not be conflated. Fitting uses environment modules, with no container involved.
[`../_shared/hpc/arc_env.sh`](../_shared/hpc/arc_env.sh) loads `R/4.5.1-gfbf-2025a` (R 4.5.1
on `x86_64-pc-linux-gnu`, with the gfbf/2025a toolchain built on GCC 14.2.0) and points
`R_LIBS_USER` at the project library `$LES_BASE/Rlib/R-4.5`. CmdStan is built at `-O1`
because of a GCC 14.2.0 compiler crash; see `../_shared/hpc/arc_env.sh`. CmdStan and that
compiler flag are not R packages, so no lockfile can record them, and `arc_env.sh` and
[`../HPC_RUNBOOK.md`](../HPC_RUNBOOK.md) are where they are written down.

Package versions are not restated here, because the run records them itself.
`results/_provenance.csv` (`component, version, recorded_utc`) is written by
[`../_shared/R/04_provenance.R`](../_shared/R/04_provenance.R) from
`scripts/03_fit_brms_erp.R`, and holds the R and platform versions, the versions of every
package in `LES_PROVENANCE_PKGS` (`_shared/R/04_provenance.R`), the CmdStan version and
the seeds. The manuscript injects those values inline,
so that file is the authority wherever any list disagrees with it. Every run of step 3
rewrites it, sensitivity runs included, unless `LES_PROVENANCE_SKIP=1` is set, so its
`recorded_utc` says which run wrote it last. The per-fit R, brms, cmdstanr and CmdStan
versions are in `results/_pooled_fit_metadata.csv`. The decoding seed the manuscript
reports is read from `results/_decoding_provenance.csv`, which `hpc/08_decoding.slurm`
writes. The R side of the same environment is pinned in the repository's `renv.lock`.

## Environment (Windows dev box)

- R 4.6.1 at `C:\Program Files\R\R-4.6.1\bin\Rscript.exe`, which is not on PATH, so call it
  by full path. The packages the manuscripts load were, on 4 October 2026: ggplot2 4.0.3,
  dplyr 1.2.1, readr 2.2.0, scales 1.4.0, patchwork 1.3.2, papaja 0.1.5, mgcv 1.9.4,
  posterior 1.7.0, brms 2.23.0, knitr 1.51, rmarkdown 2.31, here 1.0.2, tinytex 0.60 and
  pdftools, plus [`depictr` 0.3.0](https://CRAN.R-project.org/package=depictr),
  which supplies the figure theme and the
  Okabe–Ito palette both manuscripts use. The `depictr` load is guarded, so a render without
  it still succeeds, but every figure silently falls back to `theme_minimal()` and a
  hand-coded palette while the Methods still credit depictr. `brms` and `cmdstanr` happen to
  be installed here too, at the same versions as the cluster, but the Stan stack under them
  is not: this box has rstan and StanHeaders 2.39.0.9000 and loo 2.10.1 against the cluster's
  2.32.7, 2.32.10 and 2.9.0. Nothing in this compendium fits models locally, and `projpred`,
  `eegUtils` and `osfr` are absent here.
- Quarto 1.10.18 at `C:\Program Files\Quarto\bin\quarto.exe`, which is the `quarto` found on
  PATH and therefore the one the render recipe above invokes. An older standalone 1.9.37 also
  sits under the user profile and is not what renders these manuscripts. It bundles pandoc
  3.10. knitr 1.51 supplies the render engine. The `apaquarto` extension the `.qmd`
  format depends on is vendored under each paper's `_extensions/` (5.0.18, with local
  patches to `frontmatter.lua` that differ between the two papers; ISSUES.md X2-01), so it
  needs no separate install. These versions are recorded here in prose on purpose:
  `renv.lock` pins the cluster fitting environment and must not be restored on this box.
  The figures and tables are computed at render time from the tracked CSVs, so these are
  the versions behind them; the fitted numbers come from the cluster environment recorded
  in `results/_provenance.csv`.
- TinyTeX at `~/AppData/Roaming/TinyTeX` (TeX Live 2026, tlmgr revision 79639).
- Legacy data loaders assume the working directory is the project root, so leave them
  alone and anchor new scripts with `here::here()` / `setwd(here::here())`.
- Data-path note: behavioural data exists under both `data/behavioural...` and
  `data/raw data/behavioural...`. The `data/raw data/` copy is canonical, being the one the
  importers read.

## Design rationale & references

The main methodological choices are documented with citations in the manuscript Methods and
in the script headers. They fall into three groups. The model: Bayesian brms replacing
`lmerTest`, the combined language × grammaticality × session specification (typological
proximity *is* an interaction), a single-trial DV with the baseline as a covariate and one row
per trial (cluster rows of a trial are not independent observations), and a
Bernoulli GLMM for accuracy. The random-effects and predictor structure: maximal-by-design
correlated random effects, z-scored predictors, and by-participant random effects only in the
reported accuracy models. The ERP models carry a crossed by-item term over the sentence
frame (language × sentence trigger). The accuracy trials share that item factor: each frame
recurs across sessions, under both grammaticality levels, for 10 to 31 participants. The
accuracy models were therefore refitted with the same item term as a sensitivity analysis
(`LES_P1_ACC_ITEM=1`), and the manuscript reports the refits beside the reported fits. The
computational and reporting policy: the cmdstanr backend with `reduce_sum` threading, the
diagnostics (R̂, ESS, divergences, `pp_check`, PSIS-LOO), and reporting as median, 95% CrI and
probability of direction. All cited works are in `references.bib` (Crossref-verified).
The original design notes named some further anchor references that the manuscript text does
not currently cite: Bates et al. 2015 (lme4), Smith & Kutas 2015, Nalborczyk et al. 2019, and
Aust & Barth (papaja). Add one only if a specific Methods claim comes to need it, never for
its own sake. Boettiger 2015 and a general HMC/NUTS conceptual reference are already covered
by citations in current use (`marwick2018`, `schad2021`).
