# Changelog

This file records the changes that could alter what the compendium produces. They are
changes to dependencies and the environment, to seeds, to algorithms and scoring, to
exclusions and to data versions, and changes to what an artefact contains. Edits to prose,
citations and documentation are left out. The file was started in September 2026, and every
entry up to then is reconstructed from the git history and from the project's own records
(`AUTHOR_TASKS.txt`, `ISSUES.md`, `METHODS_FIGURES_AUDIT_2026-07.md`,
`POLISH_FLAGGED_2026-08.md` and the READMEs). The project has made no releases, so entries
are grouped by commit date, and each one cites its commit or the document it comes from.
The entries start at commit `c4222a7` of 3 July 2026, the earliest commit in the shallow
clone they were rebuilt from, and earlier project history is not recorded here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

Nothing beyond the entries of 2026-10-27 below, which were written before their commit.

## 2026-10-27

### Changed

- Every numeric table column of both papers is centred and aligned on the decimal point,
  under a centred head. `_shared/lua/apa-table-heads.lua` pads each number to the width of
  its column's widest with invisible copies of the characters it lacks (`\phantom` in the
  PDF; figure, punctuation and hair spaces in Word, whose Times New Roman widths match
  them to 0.02 em). The numbers had been set flush right in columns wider than they are,
  off to the right of their heads (13.5 pt in Paper 1's Table 1), and a pd of ".995" or
  "> .999" broke the decimal alignment of its column. `les_grid_table()` loses its
  `decimals` argument, which the filter supersedes, and Paper 2's `.p2_num_align()` marks
  every column after the text columns as numeric. No value changes.
- The participant-flow diagrams of both papers (`_shared/R/05_funnel.R`) leave 0.12 in
  between a section's rule and its boxes, the space above each heading, where they left
  0.20 in.
- Paper 1's grand-average and difference-wave figures set their two electrode-cluster
  blocks further apart (a 12 pt top margin on the lower block, against 4 pt), so the
  second block's title no longer sits as close to the block above as to its own panels.
- In the PDFs of both papers and of the supplement, a page holding only floats sets them
  from its top.
  LaTeX had centred them vertically, which left Paper 1's Figures 11, 12, E2 and E3,
  Paper 2's Figures 2 and 3 and Figures S1 to S4 partway down their pages.
- The supplement's reference list starts on a new page (APA 7, Section 2.12), as the two
  articles' lists already did.
- `paper_1_transfer/submission/declarations.md` matches the manuscript again: the funding
  statement names the grant holder, and the acknowledgements take the wording of the
  18 September edit.

## 2026-10-26

### Changed

- `_shared/hpc/arc_env.sh` exports `LES_REQUIRE_CMDSTANR=1` unless a job sets it, so a
  cluster job whose library lacks cmdstanr stops instead of sampling through rstan without
  threading (`ISSUES.md` X2-04). Every reported fit sampled through cmdstanr, so no result
  changes.
- Paper 1's ERP forest plot (Figure 7) labels its horizontal axis at pretty values inside
  the panel limits. The extended-breaks rule had chosen ±0.1 for limits of about ±0.07,
  so only zero was labelled. No estimate changes.
- Paper 1 prints the mean retained trials per condition to two decimals, as it prints
  their difference, and in the retention paragraph, from which it had become detached.
- The tracked Paper 1 PDF and Word file are the current render again. The 18 September
  drafts sent to the co-authors remain as the root-level `*_review_draft.*` files.
- Paper 1's prior predictive figure is drawn at render time from
  `results/_prior_predictive_check.csv` and its one-row record, written by the new
  `scripts/03b_export_prior_predictive.R` (HTC 9193225) from the same prior-only model as
  step 3's check. It was a bayesplot PNG that only a refit could redraw
  (`figures/prior_predictive_check.png`, now removed). Its note takes its numbers from the
  record.
- Both availability statements say what each repository holds. They had said the scripts
  (and, in Paper 2, the summary tables and the supplement) were archived on OSF, which holds
  the raw recordings and task data and no code. `CITATION.cff` names OSF as the
  repository-artifact for the same reason.

## 2026-10-25

### Changed

- Paper 2's results now come from the refits on every judgement (code `5fe1e94`): the Part A
  tables, the PSIS-LOO and participant-grouped K-fold comparisons (09c, HTC 9145182), the
  descriptives, the reliability and the prior-sensitivity tables. They were pulled with
  `pull_results.sh`, and the six order-diagnostic files by hand, verified against the
  store's SHA-256 and git blob ids (`results/_pulls/pull_log.csv`).
- 08c's order diagnostic (HTC 9149498) finds the same ties: exact for the pooled and
  aperiodic models and within 1.8e-16 relative for gender agreement. The pooled search
  follows the supplied order, and the gender-agreement and aperiodic searches depart from it
  differently in each run. On the screened trials (18 October) all three followed it.
  Supplement S5 states the new pattern from the files, and `test_odiag.R` pins it.
- The two predictor-by-session interactions nearest credibility are now delta by session in
  the gender-agreement model and adjusted alpha by session in its aperiodic refit (pd .96 and
  .94). On the screened trials they were the two statistical-learning terms.
- Paper 2's clause on the companion paper's by-item refits is computed from Paper 1's
  signal-detection contrasts (six of 108 comparisons change credibility, five for gender
  agreement, all within 0.06 logits of zero). It used to be typed as "changed none of its
  gender-agreement conclusions", which the refits on every judgement do not support.

## 2026-10-22

### Added

- `_accuracy_sdt_contrasts.csv` gains `mcse_low` and `mcse_high`, the Monte Carlo standard
  error of each interval bound (05; HTC 9149392, code `daa5a89`). Every other column of every
  table 05 writes is unchanged.
- `paper_1_transfer/results/_trigger_check_cells.csv`: Amendment 5's check of the trials
  the trigger rule discards (HTC 9149457-9149459, code `a29f215`).
  - It ran on all seventeen recordings, after the four raw Session 2 recordings were placed
    from OSF tq7vy with their SHA-256 checked.
  - Three of its twelve cells pass the 0.91 µV bound.
  - The events stage now rebuilds Session 2 with the export reference settings and S2/12
    from its two raw files joined, as the 16 September validation did. It first failed
    without them.
- `_shared/data_manifest/inputs.tsv` (8,369 files, data tree `0750de4`) and
  `_shared/hpc/00_verify_data.slurm`, which checks the cluster's data copy against it
  (`ISSUES.md` X5-02).

### Changed

- 09's `p_pointwise` is NA where a time point is unscorable, and no longer the floor
  1/(B + 1) (`ISSUES.md` G08-06). No deposited time-course has such a point, so nothing was
  rerun.

- **Paper 1's accuracy results are now fitted on every judgement** (`ISSUES.md` G06-03;
  HTC 9145163-9145175, code `5fe1e94`, run 21 October).
  - Pulled into `paper_1_transfer/results/`: `_pooled_convergence.csv`,
    `_pooled_fit_metadata.csv`, `_pooled_posterior_summaries.csv`,
    `_accuracy_sdt_contrasts.csv`, `_first_session_language_advantage.csv`,
    `_retention_contrasts.csv`, `_prior_sensitivity.csv`, the `_accuracy_*` side tables of
    02, and the descriptives 00 rewrites.
  - `_accuracy_rt_screen_nortscreen.csv` is replaced by `_accuracy_rt_screen_rtscreen.csv`,
    and `_accuracy_rt_bands.csv` is new.
  - All 21 accuracy fits converge, and every ERP row is unchanged.
  - The reported fits have the same credible set as the unscreened refits of 18 October.
    Their summaries differ within Monte Carlo error, as reruns under adaptive `reduce_sum`
    threading do (`_shared/R/01_bayesian_settings.R`): by up to 0.04 in a median and 0.09 in
    an interval bound.
  - `_flow_inconsistencies.csv` gains six incomplete-predictor rows. They come from Paper
    2's Stroop screen of 17 October, which the descriptives had not been rerun on.
  - `_pooled_fit_metadata.csv` no longer has a `keep_misfiltered` column, since no pooled
    fit records it any more. `les_p1_misfilter_status()` reads the column only when present.
- **Paper 1 grades the gender-agreement criterion difference as suggestive.** On every
  judgement, the refit with a by-participant slope for the change in bias leaves the
  difference credible at no session, whereas on the screened trials it stayed credible. The
  abstract, Results, Discussion, Strength of evidence, Conclusion, highlight 4 and the cover
  letter say so. `maxranef_claims_guard()` checks the new typed claims, and
  `rtscreen_weight_paragraph()` now covers the six contrasts the screen decides.
- Paper 2's refits are run and converge but are not yet pulled: 09c and 08c are still
  running.

## 2026-10-19

### Changed

- **Both papers now analyse every judgement trial, and the legacy (200, 4000) ms
  reaction-time screen is a sensitivity analysis** (`ISSUES.md` G06-03, at the author's
  request for the most rigorous resolution). The screen has no recorded rationale. It
  selects on the outcome, since its fast trials are the most accurate and its slow trials
  the least. It also removes more of the Mini-English group's trials than of the
  Mini-Norwegian group's.
  - The code swap:
    - `02_extract_accuracy.R` keeps every de-duplicated trial with a finite, positive
      response time.
    - `LES_P1_ACC_RT_SCREEN=1` applies the screen under a `_rtscreen` tag.
    - The retired `LES_P1_ACC_NO_RT_SCREEN` stops any script that reads the accuracy tags.
  - New output: `_accuracy_rt_bands.csv` counts the trials in the screen's three bands.
  - Paper 2's trajectory inherits the change through `build_paper1_accuracy()`.
  - Until `paper_1_transfer/hpc/submit_rt_screen_switch.sh` has run and its results are
    pulled, every accuracy result in the repository is still from the screened data. The
    manuscripts mark this.
  - Paper 2's pooled tables on the screened trials are frozen as
    `_pooled_posterior_summaries_rtscreen.csv` and `_pooled_fit_metadata_rtscreen.csv`.
    The Stroop comparison now uses them as its reference, so it is made on the same trials.
- Paper 1's pooled tables now carry the three accuracy refits without the reaction-time
  screen (`_nortscreen`; HTC 9134777-9134779, code `4d35c9d`, 18 October). These are
  `_pooled_convergence.csv`, `_pooled_fit_metadata.csv`, `_pooled_posterior_summaries.csv`,
  `_accuracy_sdt_contrasts.csv`, `_first_session_language_advantage.csv` and
  `_retention_contrasts.csv`, plus the new `_accuracy_rt_screen_nortscreen.csv`. Every
  other row of those tables is unchanged. The refits keep 41,181 trials against the
  screen's 33,022. Two of their 54 signal-detection contrasts differ in credibility from
  the reported fits, and none of their 24 population-level terms does.

## 2026-10-18

### Added

- `LES_P1_ACC_NO_RT_SCREEN=1`, a Paper 1 accuracy variant without the (200, 4000) ms
  reaction-time screen. It keeps every de-duplicated judgement trial with a finite,
  positive response time, and its derived files, side files and fits carry the
  `_nortscreen` tag. This is the sensitivity analysis the author decided on 17 October
  (`ISSUES.md` G06-03). Step 05 enumerates the tag. Paper 2's trajectory extraction refuses
  the switch, because it would change Paper 2's trials. With the switch unset, every
  output is unchanged. (`4d35c9d`)

- Gender agreement's cross-language and temporal-generalisation CSVs from its finished run on
  the corrected sample (HTC 8960051_0, resumed as 9060385 and 9124642, finished 18 October
  20:01). All three properties' decoding runs are now complete. Paper 1 prints gender's
  cross-language peak. Like verb-object number agreement's, its temporal-generalisation matrix
  is left to the deposited artefacts.

### Changed

- `gender_agreement_decoding_timecourse.csv` now holds every block of the finished run, where
  the copy assembled by `09b` held the confirmatory block and Session 2. Those 600 rows are
  byte-identical in the new file. `_decoding_provenance.csv` changes only in its timestamps.
- Paper 2's Stroop index is screened for task performance and scored on correct trials,
  judged against the ink colour read from the stimulus name. A session with incongruent
  accuracy below .70 gets no score. At Session 1 that is four participants who answered with
  the word and two with low accuracy on both trial types, and at Session 5 one (`ISSUES.md`
  G10-01, the author's decision of 17 October). Every Paper 2 stage downstream of the index
  was refitted (HTC 9124806-9124820, code `724d946`), and the tables in `results/` are those
  fits:
  - Samples: the raw-band Part A models have 50 participants (55 before), the aperiodic ones
    44 (49), and Part B's Stroop model 62 (63).
  - Stroop split-half reliability: .35 (.32).
  - No individual-difference term changes its relation to zero. The session-by-property term
    of verb-object number agreement in the pooled model no longer excludes zero.
  - The order diagnostic finds every tie exact and all three searches following the supplied
    order.
  The unscreened tables are kept under a `_stroop_noscreen` tag for the sensitivity
  analysis (`445f002`).

### Fixed

- Three rows of the Gorilla Stroop spreadsheet were wrongly coded, each one trial per
  participant per session: row 114 is keyed to the word, and rows 70 and 85 carry the wrong
  congruency code. The screened scoring reads both from the stimulus. (`16fed74`)

## 2026-10-15

### Added

- Differential object marking's cross-language and temporal-generalisation CSVs from its
  finished run on the corrected sample (HTC 8960052_1, 14 October). Paper 1 now describes
  the temporal-generalisation matrix from the file, through `dec_tgm_sentence()`, and prints
  its cross-language peak.

### Changed

- `differential_object_marking_decoding_timecourse.csv` now holds every block of the
  finished run, the session and session-by-language breakdowns included, where the copy
  assembled by `09b` held the confirmatory block and one session. The 300 confirmatory rows
  are identical in every column. `_decoding_provenance.csv` changes only in its timestamps.

## 2026-10-12

### Changed

- Paper 2's signal-detection refits (`p2_predictive_trajectory_sdt` and
  `p2_predictive_trajectory_gender_sdt`) in `_pooled_posterior_summaries.csv`,
  `_pooled_convergence.csv`, `_pooled_fit_metadata.csv` and `_prior_specification.csv` come
  from the refit with the by-participant grammaticality-by-session slope of `d55790d` (HTC
  9016531 and 06 as 9016532, 11 October). Both converge. None of the 18
  predictor-by-session-by-grammaticality terms excludes zero, where 7 did in the first fit,
  and the population-level grammaticality-by-session terms no longer exclude zero either.
  The medians of working memory's sensitivity and bias terms move by at most 0.02. The Discussion
  reports the drift terms' null from the summaries. (`ISSUES.md` N20)

## 2026-10-11

The first entry records `3ac6cd1` (10 and 11 October), which added no entry of its own.

### Changed

- Paper 1's decoding CSVs come from the October 2026 rerun on the corrected sample (HTC
  8960051-8960055, cross-property 9013904) at 1,000 permutations, pulled on 10 October with
  the robustness arm (`*_exclreproc_decoding_timecourse.csv`) and the two decoding
  provenance records. Verb-object number agreement's files are final. The confirmatory
  time-courses of gender agreement and differential object marking were assembled from
  their banked pooled blocks by `09b_assemble_confirmatory_timecourse.R` (HTC 9029773),
  while their runs finish the secondary analyses. On the corrected sample no
  gender-agreement cluster survives both correction layers. Four pass the maximum-cluster
  test, and the smallest Benjamini-Hochberg value is q = .051, where six clusters survived
  on the earlier sample. The two-layer rule the Method stated is kept (`ISSUES.md`
  G08-05), and the clusters that pass the first layer are reported beside it. (`3ac6cd1`)

### Removed

- The cross-language and temporal-generalisation CSVs of gender agreement and differential
  object marking from the earlier, uncorrected sample. They carry no record of their
  sample, and they return when the two runs finish. (`3ac6cd1`)

### Fixed

- Paper 1's docx and HTML renders printed the Abstract heading followed directly by the
  keywords, with no abstract between them, and only the PDF carried the text, as Paper 2's
  did until 8 October. The abstract is now a folded string (`abstract: >-`), as in Paper 2.
  (`paper_1_morphosyntax.qmd`)

## 2026-10-08

The changes below were made on 7 and 8 October. `d55790d` holds the signal-detection
formula and the amendment in `04_fit_brms_predictors.R`, and the other entries were written
before their commit, so they cite the records they come from.

### Changed

- Paper 2 no longer reports the projection-predictive ranking of the individual-difference
  predictors, or a suggested submodel size, for any of the three reference models the
  selection was run on. The order diagnostic `08c_projpred_order_diagnostic.R` (added in
  `2352752`, run as HTC 8976038) found that once the by-participant intercept and session
  slope are in a submodel, every participant-level candidate gives the same projection
  criterion. The largest relative difference is 0 among the nine candidates of the pooled
  model and the seven of the aperiodic model, and 1.69e-16 among the nine of the
  gender-agreement model. With the candidates supplied in formula order, reversed and in a
  seeded permutation, the pooled and aperiodic searches admitted them in the order
  supplied each time, and the gender-agreement search in a different order each time. The
  ranking and the suggested size leave the Results and the Discussion. The abstract and the
  Discussion now say that inhibitory control, statistical learning and the resting-state
  measures showed no credible association with accuracy, where they said that these
  measures added little, a claim about incremental prediction that only the selection had
  addressed. The Method points to supplement S5, which reports the diagnostic through
  `odiag_sentence()` in `manuscript_setup.R`, and `04_fit_brms_predictors.R` records the
  withdrawal as a dated amendment to its pre-specified reporting commitments (`d55790d`).
  Decided on 7 October. (`ISSUES.md` G13-01, `AUTHOR_TASKS.txt`, item 2.7)
- `_aperiodic_kfold_compare.csv` comes from the rerun of `09c_compare_aperiodic_grouped.R`
  in which every fold refit is seeded and checked against the convergence gate (HTC
  8976040), and all 40 refits pass. The aperiodic-minus-raw difference is -84.02
  (clustered SE 53.29) in the pooled stratum and 20.98 (33.69) for gender agreement,
  against -92.44 (54.45) and 21.67 (33.53) in the unseeded run pulled on 18 September, so
  neither stratum prefers either parameterisation, as before. The file gains a `seed`
  column, which holds 20260607. (`ISSUES.md` G13-06, G13-07)
- Paper 2's pooled tables, `_pooled_convergence.csv`, `_pooled_posterior_summaries.csv`,
  `_pooled_fit_metadata.csv` and `_prior_specification.csv`, come from the summaries rerun
  (HTC 8976041) that followed the signal-detection refits of Part A (`LES_P2_SDT=1`, added
  in `2352752`, run as HTC 8976036). Both refits, pooled and gender-agreement, converged
  (largest R-hat 1.0007, no divergent transition). Of the 14 models now pooled, 13 pass the
  convergence gate, and the exception is `p2_cognition_prepost_stroop_interference`, with
  one divergent transition, as before. The same pull brought the refits' priors into
  `_prior_specification.csv`, which the article's prior check did not yet recognise (see
  Fixed). The fit metadata also gains the `listwise_dropped` and `fit_record` columns that
  `2352752` added to the fit record. (`ISSUES.md`, "The pass of 7 October 2026")
- Paper 2 reads the fitted sample sizes it prints in the Participants section, the flow
  figure, the descriptive overview, the PSIS-LOO paragraph and the Limitations from the
  fit record, `_pooled_fit_metadata.csv`, through `fit_n()`. `proj_n()`, which read them
  from the projpred path files, went with the ranking. The counts are unchanged, 55 for the
  raw-band model and 49 for the aperiodic model. (`ISSUES.md` G15-02)
- The opt-in signal-detection variant of Paper 2's Part A model (`LES_P2_SDT=1`) gains a
  by-participant slope for grammaticality by session, so its random effects are
  `(1 + z_session_time * recoded_grammaticality | participant_lab_ID)`. Without that
  slope, each learner's own drift in response bias was attributed to the
  between-participant predictor-by-session-by-grammaticality terms, and in the first fit
  (HTC 8976036) 7 of those 18 terms excluded zero across the two strata, against none of
  the 18 predictor-by-session terms. The reported models' formulas are unchanged. The
  refit is approved but not yet submitted, so the signal-detection rows of the pooled
  tables still come from the fit without the slope. (`d55790d`, `ISSUES.md` N20)
- Paper 2's Discussion reports working memory's terms from both signal-detection refits,
  pooled and gender-agreement, where it printed a pending marker until the pull and then
  the pooled refit's terms alone. `p2_sdt_sentence()` in `manuscript_setup.R` gives the
  sensitivity and bias terms of each stratum as an interim report and draws no reading
  from them until the refit of `d55790d` lands. The Method defines their scale once. A
  predictor's term without grammaticality is its association with sensitivity, on the
  scale of half the difference between the logits of the hit and false-alarm rates, and
  its interaction with grammaticality is its association with response bias, the sum of
  those logits. The Discussion says that the terms for the change in bias are not
  interpreted, because without the matching by-participant slope such terms are estimated
  too confidently (Barr et al., 2013). `p2_sdt_drift_ok()` asks for them with a marker
  once `_prior_specification.csv` holds, for both refits, an `sd` row for
  `z_session_time:recoded_grammaticality` under `participant_lab_ID`, which the first fits
  lack. (`ISSUES.md` N20)
- Paper 2's Table A1 lists the two signal-detection refits as "Signal-detection refit"
  under each Part A group, a label its note defines, where it showed their raw ids under
  "Other models".

### Added

- `paper_2_plasticity/results/diagnostics/`, holding the order diagnostic's two tables for
  each of the pooled, gender-agreement and aperiodic reference models,
  `projpred_ties_<model>.csv` and `projpred_order_<model>.csv`, which supplement S5 reads.
  `pull_results.sh` reaches only the top level of `results/`, so the six tables were
  copied by hand, checked against the store's SHA-256 and logged in
  `results/_pulls/pull_log.csv`. (`ISSUES.md` G13-01, `HPC_RUNBOOK.md`, section 2)

### Fixed

- Two prior-sensitivity sentences in Paper 2's Results said that the 95% interval under the
  weakly informative prior excluded zero, for the individual alpha frequency in the
  gender-agreement model and for working memory in the pooled model. Since the refits of
  16 to 18 September, both intervals reach just past zero, at [-0.002, 0.968] and [-0.02,
  0.82]. `sens_zero()` in `manuscript_setup.R` now computes the clause from
  `_prior_sensitivity.csv`, saying also whether the interval under the regularising prior
  agrees, and both sentences now read "still included zero". (`manuscript_setup.R`)
- The article's check of the fitted priors against supplement S6 had no rule for the
  signal-detection refits' bias terms, so once their priors were pulled, the render of
  7 October printed a PRIOR-SPECIFICATION MISMATCH block of 36 rows in the Method.
  `.s6_prior()` in the prior-spec-check chunk now applies the rule that
  `les_p2_partA_priors()` sets, normal(0, 0.25) on each predictor's interaction with
  grammaticality and normal(0, 0.15) on its interaction with grammaticality and session,
  and S6 states it. Run against the pulled table, the check finds no mismatch.
  (`ISSUES.md` N19)
- The docx and HTML renders of Paper 2 printed the Abstract heading followed directly by
  the keywords, with no abstract between them, and only the PDF carried the text. The YAML
  block scalar `abstract: |` reached apaquarto's `frontmatter.lua` as a paragraph, which
  its docx and HTML front matter drops. The abstract is now a folded string
  (`abstract: >-`), which a test render with the vendored extension prints in both. The
  docx is the file the word counts are taken from. (`paper_2_neuroplasticity.qmd`)

## 2026-10-03

### Changed

- Paper 1's ERP-stage results come from the October rerun: the grand averages, difference
  waves and electrode-window differences (steps 07 and 07b) and the pooled summaries of all
  114 ERP fits in seven families, regenerated on HTC on 2 October 2026 from the admitted
  EEG overlay under the trial-level model. All 114 fits meet the convergence criteria. The
  prior predictive check figure is regenerated for the trial-level model. The decoding CSVs
  are not part of this pull; the repository keeps the 4 September results until the
  decoding rerun lands. (`a09e259`)
- `_shared/hpc/arc_env.sh` selects CmdStan by a fixed order: `LES_CMDSTAN_VERSION` when it
  is set, otherwise the version of record, `LES_CMDSTAN_RECORD` (2.39.0), when its tree is
  installed, and only otherwise the highest installed version, with a warning. Until now
  the highest installed version always won. Only `cmdstan-2.39.0` was installed when the
  rule changed, so no fit is affected. The file also stops a job when the R module fails to
  load or supplies an R other than the 4.5 series its library is built for, and it tests
  for the `CXXFLAGS_OPTIM` pin by the exact variable name. (`5b50d49`, `ISSUES.md` G03-06,
  G03-07, G03-08)
- `_shared/hpc/00_restore_environment.slurm` restores with the renv version that
  `renv.lock` pins (1.2.3, from CRAN's archive) and checks that the CmdStan it built reports
  the version asked for. (`5b50d49`, `ISSUES.md` G03-11, X2-05)
- `_shared/install_bayesian_dependencies.R`, the unpinned bootstrap, now installs
  `projpred` and `digest`, which Paper 2's selection and Paper 1's decoding and importer
  require, and no longer installs `ggtext`, `patchwork` or the `quarto` R package, which no
  cluster stage loads. `renv.lock` is unchanged. (`5b50d49`, `ISSUES.md` G02-20, X2-07)
- `_shared/hpc/deploy_to_cluster.sh` holds back every file a live LESS job can still read,
  traced from its batch script through what it runs and sources, copies text files in the
  LF form git stores, and skips files whose content already matches the cluster's copy.
  `_shared/hpc/pull_results.sh` brings result CSVs back with a per-file record in
  `<paper>/results/_pulls/pull_log.csv`. Neither changes what a stage computes.
  (`5b50d49`, `ISSUES.md` G03-01 to G03-05, N3, X5-05)

### Added

- `LES_P1_ACC_ITEM=1` in `04_fit_brms_accuracy.R`, a by-item accuracy variant under a
  `_byitem` tag that step 05 pools with its signal-detection contrasts. Steps 03 and 04
  record the sampler settings from the fitted object, so a reloaded fit is not stamped
  with the settings of the session that reloads it, and the next run of step 05 adds
  retention and first-session rows for the existing `_weakprior` and `_maxranef` accuracy
  fits. (`4a545e7`)

## 2026-10-02

### Added

- `paper_1_transfer/hpc/submit_eeg_rerun.sh`, which archives the superseded store artefacts
  and regenerates every Paper 1 EEG artefact from the admitted overlay in one submission:
  descriptives, the primary and robustness extractions, the grand averages, the ERP fit
  families, primary decoding of all three properties, robustness decoding of the
  confirmatory family, and the summaries. `09_run_decoding.R` gains
  `LES_DECODE_CONFIRMATORY_ONLY` and `08_decoding.slurm` gains `LES_DECODE_ANALYSES`; both
  default to the full run. (`da90ee7`, `c2a181b`, `34346a1`)
- `LES_ITER_WARMUP` and `LES_ITER_SAMPLING` in `_shared/R/01_bayesian_settings.R`, which can
  only raise the default iterations. Step 03 records the iterations each fit ran. One
  base-structure weak-prior cell (gender agreement, 200-500 ms, lateral), whose R-hat was
  1.0121 at the default length, was refitted longer. (`4a97b41`)

### Changed

- The EEG overlay manifest admits the two recovered records (Session 6 of lab ID 5 with 266
  trials, Session 2 of lab ID 7 with 50) and three rebuilt marker files: 39 rows, 201 in
  all. (`4fa6da5`)

## 2026-09-30

### Changed

- The EEG overlay manifest admits the nine Session-3 records reprocessed at 0.1 Hz (162
  files, the 1,678 trials of the legacy exports), and the reprocessing provenance is tracked
  beside it. (`6953772`)
- Paper 2's three projpred selection paths, pooled, gender and aperiodic, all
  post-exclusion, are pulled together. The pooled suggested size is 7 where it was 6.
  (`fc6fccc`)

### Added

- Amendment 6 of the reprocessing protocol and `recover.py`, which re-segments the two
  mislabelled exports at their own events and rebuilds three missing marker files.
  (`31d95c3`)

## 2026-09-28

### Added

- The EEG reconstruction (`paper_1_transfer/scripts/eeg_reconstruction/`), its job scripts
  and `_shared/hpc/py_env.sh`. (`b9d9d28`)

### Fixed

- `08_projpred_selection.R` searches projpred's default blocks minus those touching a
  fold-constant variable. The 18 September guard had passed bare term labels as
  `search_terms`, which projpred 2.10.0 reads as the whole candidate set, so the aperiodic
  selection run on it (HTC 8861266) left the participant terms out of every submodel; that
  run is void and archived in the store. (`50cb919`, `ISSUES.md` N11)

## 2026-09-18

### Changed

- The figures and tables of both papers and the Paper 2 supplement follow one house
  style, defined in `_shared/R/06_manuscript_helpers.R` (presentation pass of 18
  September 2026, `5630413`). A colour registry fixes blue and vermilion to Mini-Norwegian and
  Mini-English in every figure, `les_theme()` drops the legend boxes and strip fills that
  depictr's theme added and keeps the major grid in one direction, signed axes and table
  cells print a true minus sign, and `les_grid_table()` writes each table as a Pandoc grid
  table, so column spanners and group rows reach both the PDF and Word. Table bodies and
  long-table notes are single-spaced (the latter through a local patch to apaquarto's
  `apafloatlatex.lua` in both paper folders), the double bottom rule under every table is
  gone, and `_shared/lua/apa-table-heads.lua` centres spanners and numeric column heads.
  Word figures are drawn with ragg at 600 dpi, and the supplement is typeset with LuaLaTeX
  like the article. In `_shared/R/05_funnel.R`, `les_flow()`, a CONSORT-style
  participant-flow diagram, replaces the ghost-bar `les_funnel()`, whose step labels
  misstated attrition where attendance was not nested (`ISSUES.md` G02-01). The two
  duration figures of `_shared/R/07_task_durations.R` put session on the horizontal axis
  within one panel per task or phase, draw every participant under the boxes, and mark
  the home-task durations beyond the axis with a computed count; both helpers now default
  to the manuscripts' base size and warn when a duration falls outside their fixed axis
  range. No datum, model or reported number changes.
- Paper 1's tables are rebuilt on `les_grid_table()`. Table 1 has a Session spanner and
  blank cells for sessions before a property entered the design; the retention tables
  (B1, B2) and the signal-detection contrasts (B3) have property and window or block group
  rows with Lateral/Midline or Sensitivity/Criterion spanners and separate *LL* and *UL*
  columns; the priors table (C1) is generated from the informative and weakly informative
  builders side by side; and the convergence table is split into the ERP fits (D1, maximal
  and base structures side by side) and the judgement-accuracy fits (new D2), with a
  superscript *a* on every fit that failed a criterion. Column widths are set exactly,
  with separate widths for Word's 12 pt tables, through an opt-in span that
  `_shared/lua/apa-table-heads.lua` reads: Pandoc otherwise stretches any grid table wider
  than 72 characters across the full measure. In the PDF, a table that fits in three
  quarters of a page moves to the next page whole with its note, a longer table breaks
  only between blocks of rows, and a note follows its table's last row, split only with
  at least two lines on each page (a Paper 1-only addition to the local
  `apafloatlatex.lua` patch). No model or reported number changes. (`5630413`)
- Paper 1's `results/` takes the 31 store CSVs the 17 September review drafts were
  rendered from, which carry the 16 September sample (participant 14 out). The ERP fits
  among them predate the trial-level model and were replaced on 3 October. (`7068299`)
- Paper 2's `results/` is reconciled with the store after the 16 September refit chain:
  every pre/post sample size falls by one (participant 14), the Stroop split-half
  reliability reads .32 (test block) where the committed file held .16 (with practice),
  and the pooled convergence table reports 11 of 12 fits passing, one Part B model having a
  divergent transition. The participant flow is regenerated from the post-exclusion
  trajectory, which moves six stages down by one participant. The projpred paths were held
  back until all three selections had run (see 2026-09-30). (`df4008e`)
- `_shared/hpc/deploy_to_cluster.sh` holds back only the files a live job executes, where
  it had refused while any job of the target paper was live. (`218ccb9`)

### Security

- `start_ms` and `end_ms` are no longer written to `_task_durations_home.csv` in either
  paper by `_shared/R/07_task_durations.R` (changed on 10 September), and both papers'
  committed tables are regenerated without them. Both columns held absolute times from
  the Gorilla export's `UTC Timestamp` field, which beside two linked participant IDs
  disclose when each participant sat each task. `duration_min` and `n_events` are
  unchanged, and `_task_durations_lab.csv` keeps its `start_ms` and `end_ms`, which are
  offsets within a session. The two public per-paper repositories had their histories
  rewritten the same day so that no version carries the columns. (`c672bb5`, `f8d357d`,
  `AUTHOR_TASKS.txt`, item 2.0)

## 2026-09-17

### Changed

- The ERP models enter each trial once: step 01 averages the electrode clusters within a
  trial with equal weight, and step 03 fits `(1 + G * S | participant)` without
  topographic terms, the caudality prior removed. Cluster rows of one trial correlate at
  .45 to .64, so the earlier intervals of trial-level terms were 1.4 to 2.0 times too
  narrow. Fits are stamped with `LES_P1_ERP_MODEL_VERSION` (`trial_level_2026-09-17`), and
  step 05 refuses fits of the superseded specification. (`8f0fb8b`, `ISSUES.md` N9)
- The task-EEG exports are read by `paper_1_transfer/scripts/_eeg_import.R`, a copy of the
  legacy importer that brings every Session-2 export to the linked-mastoid reference
  (scalp minus (TP9 + TP10) / 6, FCz times 1.5) and admits reprocessed or rebuilt files
  only through the tracked, SHA-256-keyed `eeg_overlay_manifest.csv`.
  `LES_P1_EXCLUDE_REPROCESSED=1` (tag `_exclreproc`), the prespecified robustness analysis,
  replaces the retired `LES_P1_KEEP_MISFILTERED`. (`8f0fb8b`, `ISSUES.md` N8)
- Participant 20, who has no LHQ3 record, stays in the ERP models with the mean
  L1-dominance score of the other participants, flagged in `l1_dominance_imputed`, where
  listwise deletion had removed every trial. (`9a27aa9`)
- `_misfiltered_share.csv` is regenerated for the nine mis-filtered datasets: 15.9% and
  16.0%, not 6.2%. (`952b251`)

## 2026-09-16

### Changed

- `LES_P1_MISFILTERED` lists all nine Session-3 recordings high-pass filtered at 1 Hz, as an
  interim exclusion until their reprocessing at 0.1 Hz (superseded by the overlay of
  30 September), and `LES_P1_PROTOCOL_DEVIATION` excludes participant 14, trained in
  Mini-English at Session 2 by the other site's experiment file. Both reach every EEG
  extraction, the accuracy data and the usable-data counts. (`084a037`, `ISSUES.md` G04-01,
  X5-01)
- The accuracy models are read in signal-detection terms: step 05 derives sensitivity and
  criterion per group and session from the draws (`_accuracy_sdt_contrasts.csv`), step 02
  writes participant-level d' and c (`_accuracy_sdt_by_language.csv`), and
  `LES_P1_ACC_MAXRANEF=1` adds a sensitivity refit. Steps 07 and 07b baseline-correct within
  participant, write violation-minus-control differences, and add a participant-balanced
  pooled session and a difference-wave file. (`084a037`, `ISSUES.md` N1, N2)
- `LES_P1_INVALID_EXPORTS` drops three exports that do not hold the participant-session
  they are named for (Session 3 of lab ID 48, Session 6 of lab ID 5, Session 2 of lab ID 7),
  and Session-2 exports were first brought to the linked-mastoid reference with
  `c + FCz / 2`, a formula replaced the next day. (`d456267`, `ISSUES.md` N6)
- The Stroop interference index is scored on the test block alone.
  `paper_2_plasticity/scripts/01_extract_cognitive_indices.R` now drops the rows the
  Gorilla export marks as practice by default, and `11_extract_predictor_reliability.R`
  mirrors the filter. `LES_P2_STROOP_KEEP_PRACTICE=1` reproduces the superseded index,
  which the first circulated drafts reported, under a `_stroop_withpractice` tag. The
  switch replaces the opt-in `LES_P2_STROOP_TEST_ONLY=1` and its `_stroop_testonly` tag.
  The index enters Part A through the learning trajectory and Part B directly. The
  recorded Session 1 Spearman-Brown reliability is .163 with practice and .315 without.
  Decided on 11 September. (`b07f553`, `AUTHOR_TASKS.txt`, item 2.7)
- Paper 2 removes participant 14 wherever it reads an input, before any z-scoring, and
  step 06 pools a fit only when its record matches the current inputs and exclusions. It
  also writes `_prior_sensitivity.csv`. (`b07f553`, `ISSUES.md` G11-01, G11-02)
- The Part A refits of 11 September that followed the Stroop rescore leave older caches
  behind. The projpred cvfits caches and the grouped K-fold caches of `09c` predate them
  and are not invalidated by a refitted reference model. (`ISSUES.md`, items 1 and 2 of the
  section carried over from the 2026-09-12 pass)

### Added

- `docs/eeg_filter_reprocessing_protocol.md`, which fixes how the nine 1 Hz Session-3
  records are reprocessed before any reprocessed output exists, with Amendments 1 to 4.
  (`7cb4cfd`, `77413b3`, `b0c6be5`, `b383766`, `2f8ad4a`)

## 2026-09-08

### Added

- `_task_durations_home.csv` and `_task_durations_lab.csv` in both papers' `results/`,
  written by `_shared/R/07_task_durations.R` through
  `paper_2_plasticity/scripts/13_extract_task_durations.R` and its job script. The home
  table carried the `start_ms` and `end_ms` columns that the 2026-09-18 entry removes.
  (`107a569`)

## 2026-09-07

Commit `7d8bafd` has no message body, so these entries come from its diff and from the
documents cited.

### Changed

- `renv.lock` was regenerated by snapshotting the cluster library under R 4.5.1 across the
  whole `.libPaths()`. The lockfile it replaced held 37 package records under the same R
  version, none of them brms, cmdstanr or projpred. It now holds 422 package records, 420 from the snapshot and `depictr` (v0.3.0)
  and `scopusflow` (v0.4.0) added by hand, and pins `cmdstanr` (v0.9.0) and `eegUtils` to
  GitHub commits. (`7d8bafd`, `POLISH_FLAGGED_2026-08.md` resolved 2026-09-02, and
  `README.md`)
- `.Rprofile` activates renv only when `renv/library` is populated, so a clone with an
  empty renv library keeps R on the system library. (`7d8bafd`)
- `_shared/install_bayesian_dependencies.R` no longer installs `tidybayes`, `bayestestR`,
  `marginaleffects`, `emmeans` or `osfr`, and its header states that `renv.lock` takes
  precedence over its package list. (`7d8bafd`)
- `.gitattributes` pins `*.sh`, `*.slurm` and `*.R` to LF line endings in the working tree.
  (`7d8bafd` and `AUTHOR_TASKS.txt`, item 1.14)
- Paper 1's ERP covariate is described as what it is, the LHQ3 L1 dominance score. The
  legacy loader reads the LHQ3 table by column position, and the column it reads holds L1
  dominance, not the multilingual language diversity score that the variable name and the
  earlier drafts gave. Every ERP fit had used that score, so no model changed; the
  descriptions did. Found on 3 September. (`7d8bafd`, `ISSUES.md` G06-07)
- `paper_2_plasticity/scripts/06_summaries.R` excludes the projpred summaries
  (`*_projpred_summary.rds`) from `_pooled_posterior_summaries.csv`, where they had been
  expanded into malformed rows. The table went from 229 rows to 170. (`7d8bafd` and
  `AUTHOR_TASKS.txt`, item 1.10)
- The participant-grouped fold assignment moved into `_shared/R/06_helpers.R` as
  `les_participant_folds()`, still seeded by `LES_SEED` by default. (`7d8bafd`)
- The three decoding time-course CSVs in `paper_1_transfer/results/` were replaced.
  Differential object marking and verb-object number agreement carry `n_perm` = 1000 in
  every row. Gender agreement carries 1000 in its confirmatory `overall` rows and 200 in its
  exploratory `by_session` and `by_session_language` rows.
  `09b_assemble_confirmatory_timecourse.R` was added to assemble a time course from the
  decoding checkpoints. (`7d8bafd`, the committed CSVs and
  `paper_1_transfer/results/CODEBOOK.md`)
- Paper 2's IAF-resolved refit, which drops the two participants whose alpha peak the
  specparam decomposition cannot resolve and writes under an `_iafres` tag, ran on
  6 September. (`AUTHOR_TASKS.txt`, item 1.10 and Part 4)

### Added

- A `seed` column in `paper_2_plasticity/results/_predictor_reliability.csv`, recording
  `LES_REL_SEED` (20260724). The reliability values are unchanged. (`7d8bafd` and
  `AUTHOR_TASKS.txt`, item 1.12)
- `LES_P1_DECODE_SEED_DEFAULT` (20260702) in `paper_1_transfer/scripts/_config.R`, which
  `03_fit_brms_erp.R` records into the provenance record and which equals the default
  `09_run_decoding.R` gives `LES_DECODE_SEED`. (`7d8bafd`)
- The opt-in `LES_P1_ACC_DIVERSITY=1` accuracy variant, which attaches the LHQ3 diversity
  score and writes under a `_diversity` tag. (`7d8bafd`)
- `paper_2_plasticity/scripts/06b_recover_provenance.R`, which rebuilt Paper 2's
  `_provenance.csv` from the version stamps in the cached Part A fits and adds
  `record_source`, `fits_written_utc` and `fits_recorded` rows. The IAF-resolved refit had
  been submitted without `LES_PROVENANCE_SKIP=1` and had overwritten the record.
  (`7d8bafd` and `AUTHOR_TASKS.txt`, item 1.13)
- `_shared/hpc/00_restore_environment.slurm`, which restores `renv.lock` and builds
  CmdStan 2.39.0. (`7d8bafd`)
- New results files. Paper 1 gains `_accuracy_input_gaps.csv`,
  `_accuracy_sentence_inventory.csv`, `_misfiltered_share.csv`,
  `_participants_other_languages.csv` and `_rsvp_timing.csv`. Paper 2 gains
  `07_aperiodic_features.csv`, `_participants_other_languages.csv` and `_provenance.csv`.
  Each `results/` gains a `CODEBOOK.md`. (`7d8bafd`)

### Removed

- `paper_1_transfer/results/_exclusions.csv`, the superseded exclusion marker, which no
  code writes or reads. (`7d8bafd` and `AUTHOR_TASKS.txt`, item 1.6)

## 2026-08-31

### Changed

- Paper 2's figures use the Okabe-Ito palette. (`4c308c5`)

### Fixed

- `cred_cells()` counted the 24 retention-free refits as base-structure cells, so four
  injected counts in Paper 1 read "12 of 42" against a grid of 18. (`4c308c5`)
- Paper 1's ERP forest plot drew all 54 point-ranges on one row labelled "NA, NA", because
  its label parser predated the `_itemslope` model ids. (`4c308c5`)

## 2026-08-22

### Added

- `08_extract_decoding_matrices.R` caches the decoding tensor and reuses it only when a
  fingerprint of its inputs matches. The fingerprint covers the matched raw exports by
  relative path, size and modification time, `LES_P1_KEEP_MISFILTERED`, the exclusion
  table, the epoch, channel, downsampling and baseline settings, the resolved data root,
  the import and preprocessing code with `_config.R`, and the R version and collation. A
  digest of the tensor values is stored beside it and appended to the block-checkpoint
  fingerprint in `09_run_decoding.R`. Both writes are atomic. (`b45341d`)
- `09_run_decoding.R` saves the partially filled permutation null every
  `LES_DECODE_CKPT_EVERY` permutations (default 50) together with the RNG state, and
  resumes from it. The commit records a test in which an interrupted and resumed run
  reproduces an uninterrupted one bit for bit. (`c6ebc08`)

### Fixed

- `.les_complete_trials()` did not carry the tensor digest through, so the guard on the
  permutation checkpoints could never fire. The digest is now carried, package versions
  join the tensor fingerprint, and `run_crossprop()` checks that the two tensors agree on
  their channel axis before slicing it by position. (`7d3f503`)

## 2026-08-20

### Added

- Paper 1's `tbl-retention-free`, reporting the retention-free fits of all 18 cells, which
  were fitted and pooled under both random-effect structures. (`c785f15`)

## 2026-08-19

### Changed

- Three Session 1 Gorilla records whose home IDs map to no enrolled participant are
  dropped at source in `01_extract_cognitive_indices.R`, and `05_fit_brms_prepost.R`
  asserts that none can re-enter. They had entered the predictor-reliability and
  descriptives tables (n = 66 against 65 enrolled) and the Part B z-scoring. The
  reliability script filters its raw trial frames to enrolled IDs, and Part B was refitted.
  (`ace9d2e`)
- The accuracy models were re-pooled from the current extraction, from which eight stale
  Session 6 rows are gone, and the Part B models from their refit. `06_summaries.R` no
  longer loads cached K-fold objects when writing the prior-specification artefact.
  (`6e8dd0e`)
- The weak-prior accuracy fits were refitted against the current extraction, and Paper 1's
  prior sensitivity now covers 39 models, up from 36. (`fedbcff`)

### Added

- `paper_2_plasticity/results/_prior_specification.csv`, the brms `prior_summary` rows of
  the ten Paper 2 models. (`4b1cebc`)
- Artefacts for statistics previously typed by hand. They are the post-critical onset
  census from `01b_extract_rsvp_timing.R`, `_accuracy_rt_screen.csv` from
  `02_extract_accuracy.R` (the 200 to 4000 ms screen removes 8,504 of 42,116 valid trials),
  the gamma attenuation from `12_extract_gamma_attenuation.R`, the between-language
  retention difference and the first-session gender advantage in Paper 1's step 05, and the
  fitted pre/post sample sizes and realised prior specification in Paper 2's
  `06_summaries.R`. The commit records the accuracy `.rds` outputs as bit-identical to the
  pipeline before the change. (`a61ce9a`)

### Fixed

- `collect_retention()` enumerated no `_retfree` cache tag, so the retention-free fits
  were never read. The three-way retention lookup used the term name in the order written
  in the formula, which R's `terms()` reorders, so the within-language and
  between-language contrasts were dropped. Pooling now yields all 24 retention-free
  contrasts, up from 6. (`00f2fbc`)

## 2026-08-18

### Added

- `LES_P1_RETENTION_FREE=1` in `03_fit_brms_erp.R` adds an explicit Session 6 offset
  crossed with grammaticality and language, and refuses a two-session property. Step 05
  reports the offset where those fits exist. (`12972e8`)

### Fixed

- Paper 1's forest plot drew 216 point-ranges where it should draw 54, and its retention
  table printed 225 rows, because both filtered on parameter but not on random-effect
  structure or prior set. Both now follow `LES_P1_PRIMARY`. (`12972e8`)

## 2026-08-16

### Changed

- Paper 1's prior table is generated by calling `les_erp_prior()` and `les_acc_prior()`
  over the fitted grid. Three values in the hand-transcribed table it replaced were wrong.
  (`c3a3eb9`)
- Figure type is set once as `LES_FIG_BASE_SIZE` and inherited through `les_theme()`, every
  figure is authored at the 6.5-inch text width, and table columns that never vary are
  dropped when constant. (`252bfaa`)

## 2026-08-15

### Added

- `09c_compare_aperiodic_grouped.R` writes a participant-clustered standard error of the
  elpd difference beside the `loo_compare` one, with their ratio, and decides on the
  clustered one. Each kfold object is cached with the fold vector it was built from, and a
  cache whose folds differ is not reused. (`a46ab54`) `ISSUES.md` (item 2 of the section
  carried over from the 2026-09-12 pass) records that this guard does not detect a
  refitted model.
- Each decoding block is cached as it completes, with the RNG state it left behind, and
  keyed to a fingerprint of the tensor and of n, participants, time points, B and seed. The
  commit records resumed runs as bit-identical to an uninterrupted one. (`8a6efb2`)

## 2026-08-12

### Added

- `09c_compare_aperiodic_grouped.R`, which refits the raw-band and aperiodic Part A models
  on their common sample under one participant-grouped fold assignment and writes a
  separate artefact. (`867d58e`)
- Paper 1's pooled convergence artefacts take each fit's name from its file name and gain
  `structure` and `prior_variant` columns. Paper 2's posterior summaries gain 21 rows from
  the gender-stratum projpred selection, whose artefact had never been pooled. The commit
  records the other pooled artefacts as byte-identical. (`70dad55`)

### Changed

- Cross-property generalisation was recomputed from the post-exclusion tensors. The peak
  post-stimulus AUC moved from .533 to .531. (`7d4fba7`)

## 2026-08-10

### Added

- The projection-predictive selection was run on the gender-agreement stratum over the
  full candidate set of 22 terms. (`1464fd3`)

## 2026-08-09

### Changed

- Paper 1 was refitted without the four mis-filtered Session 3 datasets, in 72 fits over
  18 cells, two prior sets and two random-effect structures. The exclusion moved three
  differential object marking parameters into credibility. (`942f84a`)
- The maximal crossed random-effect structure is reported as primary, selected through the
  single `LES_P1_PRIMARY` constant. Interval precision is chosen so that no non-zero
  quantity prints as zero, and four statistics typed into the prose are now read from the
  artefacts. (`99f5299`)

## 2026-08-08

### Changed

- `_shared/hpc/arc_env.sh` appends `CXXFLAGS_OPTIM = -O1` to CmdStan's `make/local`,
  because GCC 14.2.0 crashed compiling Stan's `reduce_sum` templates above `-O1`. Threading
  is kept, so the sampler configuration matches the cached fits. (`e242a6e`)

### Added

- `LES_P1_ITEM_SLOPE=1` adds a by-item grammaticality slope to the ERP models, cached under
  an `_itemslope` tag and off by default at that commit. (`4aa3cb5`)
- Per-fit metadata records, pooled into `_pooled_fit_metadata.csv`, count the mis-filtered
  rows in each fitted frame and record the random-effect structure and the R, brms and
  CmdStan versions. The exclusion claim is keyed on these records. Step 05 builds
  `_prior_sensitivity.csv`, which had no producing script, and declines any comparison
  whose two sides cannot be confirmed to share their data. (`b2fc1e2`)

## 2026-07-31

### Fixed

- The mis-filter exclusion applied `as.integer()` to factor keys, which returns level
  indices, so it removed the wrong participant-sessions. All 648 Session 3 rows of
  participants 7, 8, 9 and 16 remained, and participant 16 lost every Session 4 row. The
  keys now pass through `as.character()` first. The extraction, the 18 ERP refits, the
  summaries, both grand-average arrays and the B = 1000 decoding were resubmitted.
  (`914f726`)

### Added

- `00b_audit_participant_flow.R`, which writes `_participant_matrix.csv` and
  `_flow_inconsistencies.csv` to both papers, and participant-flow figures for both papers
  from a shared `les_funnel()` generator. (`0c80807`, `2c0f0ef`)

## 2026-07-30

### Changed

- Paper 2's summaries were rerun against the fitted models under the corrected reliability
  formula. Pooled attainment reliability moved from .875 to .841, the pooled learning rate
  from .810 to .749, gender-only attainment from .852 to .794 and the gender-only learning
  rate from .642 to .416. The convergence artefact now covers ten fits and the posterior
  summaries twelve models. (`b983b4c`)

### Fixed

- Pooled convergence rows take the model name from the file name, so a sensitivity fit no
  longer carries its base model's label. (`b983b4c`)

## 2026-07-29

### Changed

- The four Session 3 recordings of lab IDs 7, 8, 9 and 16, high-pass filtered at 1 Hz, are
  excluded from the primary analysis, session-specifically. The drop is applied in the ERP
  extraction before baselines and standardisation are computed, and in the decoding tensor
  build. `LES_P1_KEEP_MISFILTERED=1` retains them. (`be26677`)
- The decoding submit script's `LES_DECODE_NPERM` default went from 200 to 1000, and the
  job's walltime from 2 to 14 days. (`4be9bae`)

## 2026-07-25

### Added

- `_shared/R/04_provenance.R`, which writes `results/_provenance.csv` at fit time with the
  R version, platform, version-sensitive packages, CmdStan version and seeds in force.
  (`4d4a5a0`)
- `paper_2_plasticity/scripts/11_extract_predictor_reliability.R`, which estimates
  predictor reliability by permutation split-half with a Spearman-Brown correction over
  500 within-participant splits, and refuses to proceed unless it reproduces the indices in
  `cognitive_indices.rds`. (`5da710a`)

### Changed

- ERP trial-retention rows are split by grammaticality, and the mean artefact-rejection
  rate and the differential loss between conditions are added. (`c6502aa`)
- `les_prior_predictive_check()` takes its axis label and view range as arguments and draws
  no in-image title. (`8685d30`)

## 2026-07-24

### Added

- `paper_1_transfer/scripts/10_extract_literature_trend.R`, which counts the L3-transfer
  literature in Scopus through `scopusflow` and writes `results/_literature_trend.csv`
  with the query beside each count. (`f2b1818`)

## 2026-07-23

### Added

- `depictr` supplies the shared figure theme and palette through `les_theme()`, which falls
  back to `theme_minimal()` when the package is absent. (`572500b`)

### Changed

- The decoding FDR family spans the confirmatory analyses only. Rows carry an `inference`
  column, and a guard requires 1/(B + 1) < alpha/m before the correction runs. (`4ebee70`)
- Properties are ordered in figures and tables by the session in which each was introduced.
  (`4ebee70`)
- Accuracy-trajectory intervals are between-participant standard errors over participant
  means, and cell means are means of participant means. The previous intervals were
  trial-level binomial standard errors. `_accuracy_trajectory_descriptives.csv` gains a
  `participant_cell` block. (`d476f9c`)

### Removed

- The interior-local-maximum IAF estimator added on 22 July was reverted to the plain
  argmax over 7 to 13 Hz, after testing against the specparam alpha peak. (`8952241`)

## 2026-07-22

### Changed

- The decoding peak is taken post-stimulus, and the pre-stimulus interval is reported as a
  negative control. (`6357ba7`)
- Random-effect reliability is computed as Var(E[u_i]) / tau^2. The previous computation
  used the posterior SD of the shrunken random effect as the sampling SE. (`6357ba7`)
- The accuracy dataset is filtered to the Experiment block, which removes the Session 6
  "Gender assignment task" rows. (`6357ba7`)
- The projpred path extractor keeps the fold-wise ranking-stability diagnostic, and docx
  figures are written at 600 dpi. (`6357ba7`)
- `les_iaf()` was changed to return NA unless an interior local maximum exists. It was
  reverted the next day. (`6357ba7` and `METHODS_FIGURES_AUDIT_2026-07.md`, M9)

## 2026-07-19

### Changed

- Gender-agreement decoding was rerun on the 31 EEG channels, over 13,098 trials from
  Sessions 2, 3, 4 and 6. The missing-channel filter had previously left only the 3,915
  Session 2 trials. Cross-property generalisation ran for the first time. (`20e0dfe`)

## 2026-07-15

### Changed

- The decoding tensor takes the channels common to the sessions contributing to each
  property and drops the accelerometer channels, leaving 31 EEG sensors. Only gender
  agreement was affected. (`739fd54`)
- Electrode positions for the topography are read from the recorded montage in the
  BrainVision headers, and the `eegkit` dependency is dropped. (`8e6cecd`)

### Added

- `07b_extract_grand_average_by_electrode.R` and `07c_extract_electrode_coordinates.R`,
  for electrode-level grand averages, difference waves and an interpolated topography.
  (`ba99bad`)

## 2026-07-11

### Added

- `09b_compare_aperiodic_commonsample.R`, which refits the raw-band model on the aperiodic
  model's participants and compares the two on identical observations.
  `09_compare_aperiodic.R` and `10_compare_aperiodic.slurm` are marked superseded.
  (`312e391`, `f104342`)
- `08b_recover_projpred_path.R`, which re-extracts the projpred path from the cached varsel
  objects. (`312e391`)

### Fixed

- The projpred path extractor reads `summary()$perf_sub`, where projpred 2.10 stores the
  per-size performance table. (`312e391`)

## 2026-07-06

### Added

- Extractors `00_extract_participants.R`, `00c_extract_erp_retention.R` and
  `00d_extract_training_gate_flow.R` in Paper 1 and `10_extract_descriptives.R` in Paper 2,
  which write the sample-flow, participant, ERP trial-retention, training-gate and Paper 2
  descriptive artefacts. (`3bf2e8d`)
- `cluster_p_fdr` and `significant_fdr` columns, written back into the decoding CSVs post
  hoc with `.les_fdr_within_property()`. (`d24d1f8`)

### Changed

- projpred uses participant-grouped 10-fold cross-validation with FORK workers, and the
  commit raises the decoding permutation default from 200 to 1000. The entry for 29 July
  records that the submit script still defaulted to 200. (`3bf2e8d`)
- The FORK parallel backend is registered only around `cv_varsel()`. (`9a93c0f`)

## 2026-07-03

### Changed

- projpred uses the latent projection, `get_refmodel(fit, latent = TRUE)`. This first
  commit already defines `LES_SEED` as 20260607 and `LES_DECODE_SEED` with the default
  20260702, and both values stand at HEAD, in `_shared/R/01_bayesian_settings.R` and
  `paper_1_transfer/scripts/09_run_decoding.R`. It also already selects the prior set
  through `LES_PRIOR_SET`, whose value `weak` gives the weakly informative sensitivity
  baseline under `_weakprior` tags. (`c4222a7`)
