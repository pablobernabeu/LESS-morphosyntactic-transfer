# Open issues

This file tracks every finding of the strong-codebase audit run on the working tree of
`methods-figures-audit` between 12 and 14 September 2026. The audit covered both papers'
analysis scripts and job scripts, the shared modules, the manuscripts' R code, the
environment records and the documentation. Twenty-three reviewers read the live code, sixteen
by file group and seven by theme (environment, seeds, documentation drift, data versioning,
redundancy, outputs and privacy, and dead code). Independent verifiers then tried to refute
every finding, two of them for each BLOCKING finding. A scratch rebuild re-ran the local
extraction stages twice and compared the outputs with each other and with the committed
artefacts.

347 findings stand: 20 BLOCKING, 134 MAJOR (106 of them HIGH-RISK) and 193 MINOR (94 HIGH-RISK). 99 were resolved in whole or in part in this pass by documentation, comment and tooling changes that alter no reported number. The rest were proposals. Their state on 8 October 2026 is summarised under "The pass of 7 October 2026" below, which updates "The pass of 3 and 4 October 2026", and each entry's status line gives it. A further 53 reports were merged into the entry they duplicated, 9 restated something already known and 1 was refuted. The table near the end lists all of them.

## How to read an entry

- **Severity.** BLOCKING means the defect breaks reproducibility or can silently produce a
  wrong result. MAJOR covers dead code, missing pins and undocumented behaviour, structural
  drift, and unchecked assumptions that fail loudly. MINOR covers stale wording, naming and
  style. Where a verifier changed the severity, the entry gives the severity as first reported.
- **HIGH-RISK.** The defect touches code behind a reported, submitted or archived result. The
  fix waits for the author's sign-off, and none was applied in this pass.
- **Fix could change a reported number.** Whether applying the fix would move a value printed
  in either manuscript, once the affected stage is re-run.
- **Status.** Resolved entries name the commit. Open entries await sign-off. Deferred entries
  give the reason, which is usually that the change lands in the author's uncommitted edits of
  10 and 11 September, in a manuscript source, or in the four files coupled to the decoding
  tensor fingerprint while the gender decoding job runs on HTC.

## The pass of 7 October 2026

Four Paper 2 jobs submitted in the pass of 3 and 4 October ended on 4 and 5 October, and
their outputs were pulled on 7 October. Both signal-detection refits of Part A converged
(HTC 8976036, largest R-hat 1.0007, no divergent transition), and the summaries rerun after
them (8976041) pooled 14 models, 13 of which pass the convergence gate. The exception is
`p2_cognition_prepost_stroop_interference`, with one divergent transition, as before. The
participant-grouped comparison (8976040) was rerun with every fold refit seeded and checked,
and all 40 refits pass the gate (largest R-hat 1.0009, smallest bulk ESS 6,346 and tail ESS
11,632, no divergent transition). The aperiodic-minus-raw difference is -84.02 (clustered SE
53.29) in the pooled stratum and 20.98 (33.69) for gender agreement, against -92.44 (54.45)
and 21.67 (33.53) in the unseeded run pulled on 18 September, so neither stratum prefers
either parameterisation, as before. The signal-detection run also exposed a defect in the
shared posterior predictive check helpers, entered as N18.

The render and review of that pull found two more problems with the signal-detection
refits, entered as N19 and N20. The re-pulled `_prior_specification.csv` carries their bias
priors, which the article's check against supplement S6 did not recognise, so the render
printed a PRIOR-SPECIFICATION MISMATCH block in the Method (N19, resolved on 8 October). The
variant also lacked a by-participant slope for grammaticality by session, and 7 of its 18
bias-drift terms excluded zero, against none of its 18 predictor-by-session terms (N20).
Commit `d55790d` of 8 October adds that slope to the variant's formula and leaves the
reported models' formulas unchanged. The refit is approved, and until it lands the
Discussion reports working memory's sensitivity and bias terms in both strata without
interpreting them. It withholds the bias-drift terms, and a structural gate asks for them
once both refits carry the new slope (N20).

The order diagnostic (8976038) settles G13-01. Its six tables are in
`paper_2_plasticity/results/diagnostics/`. `pull_results.sh` reaches only the top level of
`results/`, so they were copied by hand, checked against the store's SHA-256 and logged in
`results/_pulls/pull_log.csv`. In every solution path the by-participant intercept and slope
enter at steps 1 and 3, before any participant-level predictor. At the first step where a
participant-level predictor can enter (step 6, or 4 in the gender-agreement model), every
candidate brings the submodel equally close to the reference model. The largest relative
difference in the projection criterion is 0 among the 9 candidates of the
pooled model, 0 among the 7 of the aperiodic model, whose fold-constant adjusted theta and
beta are left out as in step 8, and 1.69e-16 among the 9 of the gender-agreement model. Rerun
with the candidates supplied in formula order, reversed and in a seeded permutation, the
pooled and aperiodic searches admitted the participant-level main effects in exactly the
supplied order all three times. The gender-agreement search departed from the supplied order
each time and gave three different orders, with digit span first under two of them and the
individual alpha frequency first under the third, as ties broken by rounding error would.
Once the by-participant terms are in the projection, a predictor that is constant within
participant adds nothing to it, so the ranking of the individual-difference predictors
reflects the order they were listed in, and the suggested submodel size inherits that order.

The author decided on 7 October 2026 to drop the ranking and say why. The ranking and the
suggested size are gone from the Results, and the three Discussion sentences that relied on
them are gone or rewritten. The full Part A posterior and the participant-grouped K-fold
comparison carry the conclusions, the Method points to supplement S5, and S5 reports the
diagnostic and why no ranking is given. The Method's review callout went with it. A
redesigned search, which would admit the participant-level terms before the by-participant
terms can absorb them, was offered and declined. G13-01 is resolved, and G13-03 is obsolete
because no submodel size is reported. G15-04 stayed partly resolved on 7 October, because
one typed verdict remained, the Discussion's statement that aligning the Stroop polarity
lowered the Stroop contrast's probability of direction. On 8 October `signaligned_guard()`
began to check that statement, so G15-04 is resolved. The status lines of G13-02,
G13-06, G13-07, G13-08, G15-02 and X6-04 record the reruns and the other consequences, and
N10, N11 and the carried-over items 1 to 3 are brought up to date as well.

The counts are taken from the status lines under one rule, which reproduces those of
4 October exactly (288, 32, 11, 11, one and one). A status of "resolved in part" counts as
partly resolved, "obsolete" and "no change needed" count as resolved, "proposed: do not
apply" counts as declined, and the three DET entries stay outside the 344, as they were then.
The N entries, N18 to N20 among them, carry their own statuses and stay outside the counts
too. On 8 October, after G15-04 was resolved and G15-15 became obsolete, 292 of the 344
audit entries are resolved, 31 partly resolved, 10 await an author decision, 10 are open,
none is deferred and one was declined. Of the 20 BLOCKING entries, 19 are resolved, and
G10-01 (the Stroop index's error trials) awaits its decision. The author decisions left are
G03-17, G04-25, G06-03, G08-05, G10-01, G11-14, G12-05, X4-13, X4-14 and X6-02. The open
entries are G01-14, G05-04, G08-06, G08-07, G14-08, G15-17, X2-01, X6-03, X6-07 and X7-01,
each with its proposal in the entry.

On 10 October G08-05 was decided (see its status line), so the author decisions left are
G03-17, G04-25, G06-03, G10-01, G11-14, G12-05, X4-13, X4-14 and X6-02, and 293 of the 344
entries are resolved, with 9 awaiting a decision. On 17 October the author asked for the remaining decisions to be taken, and G10-01 was put to the author and decided (screen the Stroop index and drop the screened participants from Part A). Every entry's status line gives its decision. 306 of the 344 entries are now resolved, 33 partly resolved, 3 open (G08-06, X2-01 and G15-17, none needing the author), one deferred (G01-14) and one declined, and all 20 BLOCKING entries are resolved. No author decision remains. The same day the decoding rerun's
confirmatory time-courses were pulled into Paper 1. Gender agreement and differential object
marking were assembled from their banked pooled blocks by
`09b_assemble_confirmatory_timecourse.R` (HTC 9029773). Verb-object number agreement's run
had finished, and the robustness arm and the cross-property stage were also complete. The
cross-language and temporal-generalisation files of gender agreement and differential object
marking from the earlier, uncorrected sample were removed from `results/`. Those files carry
no record of their sample, and the manuscript discloses the analyses as pending until the
two runs finish. On the corrected sample, no gender-agreement cluster survives both
correction layers (four pass the maximum-cluster test), where six survived on the earlier
sample.

On 18 October gender agreement's run finished (HTC 8960051_0, resumed as 9060385 and
9124642, at 20:01), so all three properties' decoding runs are complete and pulled. Its
confirmatory and Session 2 rows are byte-identical to the copy assembled by `09b`, and Paper 1
now prints all three cross-language peaks with no pending disclosure. No decoding job is left
on the cluster. The entries whose status lines waited for the decoding run to end can
therefore go ahead: G06-03 (the unscreened accuracy fit, run and reported the same night, so 307 entries are now resolved and 32 partly resolved), G08-06, G08-10, G08-17, X2-03 and
X2-04, as can the deployment of the files the deploy script held back, which was done the same night (all but the decoding pair, which stays held back by default).

On 19 October the author asked for the most rigorous resolution of G06-03, which is reopened as partly resolved (306 resolved, 33 partly resolved). Both papers now analyse every judgement, the reaction-time screen becomes Paper 1's sensitivity analysis, and the refits wait for the end of the ARC outage on 22 October (see its status line).

On 22 October, after a pass over what remained open, the author chose four further fixes. G01-01 is now also resolved in the manuscripts, with Monte Carlo standard errors reported for Paper 1's signal-detection bounds. G08-06 and G15-17 are resolved, and so is X5-02 (the data manifest and its verification job). Amendment 5's trigger-rule check was run (see N7). That makes 309 resolved and 32 partly resolved. The open entries left are documentation, refactoring and hygiene of finished code, none of which bears on a reported number.

On 25 October Paper 2's refits on every judgement were pulled (09c 9145182 and 08c's backup 9149498 had finished), which resolves G06-03 and DET-02: 311 resolved and 31 partly resolved.

On 26 October a pre-submission pass resolved G11-10, G16-10, X2-01 and X2-04, which makes 315 resolved and 28 partly resolved, with DET-10 the one entry still open. The status lines that waited for the decoding run to end (G08-02, G08-10, G08-13, G08-17) now record why those changes are deferred to the next decoding run.

The cluster could not be reached by SSH from about midnight to 11:00 on 8 October. At 11:15
the signal-detection refit of N20 was submitted as HTC 9016531, with the summaries (06)
chained after it as 9016532. On the poll of that hour, Paper 1's decoding jobs 8960051_0,
8960052_1, 8960052_2 and 8960054_0 were still running on HTC, and every primary
confirmatory block was banked (gender agreement and differential object marking on 8
October, verb-object number agreement on 6 October). The robustness tasks 8960055_1 and
8960055_2 had ended on 6 and 7 October. The cross-property stage, 9013904, ran on 8
October from 01:36 to 01:38 and wrote its three CSVs to the store, which are not yet
pulled. Everything the section below lists as waiting for the decoding run therefore
still waits.

## The pass of 3 and 4 October 2026

*The counts and lists in this section are those of 4 October. The section above gives them as
of 8 October 2026.*

Every entry below now carries a status checked against the tree on 3-4 October 2026. Of the
344 audit entries, 288 are resolved, 32 partly resolved, 11 await an author decision, 11
are open, one is deferred and one was declined. Of the 20 BLOCKING entries, 17 are
resolved; G10-01 (the Stroop index's error trials) awaits a decision, G13-01 (whether the
projpred order is a tie artefact) waits on its diagnostic, HTC 8976038, and G15-04 is
partly resolved behind it. Statuses name the commit (4a545e7 to 470c446). Where a fix
needed a rerun, the status says whether it ran (HTC 8976030-8976041) and where it was
pulled.

What is left, by kind:

- **Author decisions:** G03-17 (default host alias), G04-25 (`sex_*` to `gender_*`), G06-03
  (an analysis without the reaction-time screen), G08-05 (whether the second-layer BH
  correction decides anything), G10-01 (Stroop on correct trials), G11-14 (reliability
  estimator), G12-05 (specparam peak refinement), G13-03 (disclosing that submodels beat
  the reference), X4-13 (the supplement's author block), X4-14 (privacy) and X6-02 (the
  p_d format).
- **Waiting for the decoding run (HTC 8960051-8960055) to end:** the 09 code patches
  (G08-02, G08-06, G08-07, G08-10, G08-13, G08-17) and the deployment of the five files the
  deploy script holds back while those jobs can read them: Paper 1's `_config.R` and
  `08_extract_decoding_matrices.R`, and the shared `00_paths.R`, `03_data_manifest.R` and
  `arc_env.sh` (X2-03, X2-04).
  Paper 2's step 13 cannot run on the cluster until then either (G02-12, X7-03, N16).
- **Waiting for queued Paper 2 jobs:** the signal-detection refit (HTC 8976036, then 06 as
  8976041), the order diagnostic (8976038; G13-01, G15-04) and the participant-grouped
  comparison (8976040; G13-06, G13-07).
- **Open:** G01-14, G05-04, G14-08, G15-17, X2-01, X6-03, X6-07 and X7-01, each with its
  proposal in the entry.

## Added 15 October 2026

- **N21. Paper 1 read differential object marking's pre-stimulus separability as a bound on
  what a violation response could add, and did not say that the decoder's input is
  baseline-subtracted (MAJOR, resolved in the commit after `40083cb`. Fix would change a
  reported number: no, the prose only).** The Results said that "the post-stimulus peak set
  against the pre-stimulus mean bounds how much separability the violation response could
  add", and the Discussion that the two clusters "bound the separability a violation response
  could contribute". Both assume that the pre-stimulus difference keeps its strength after
  onset, and AUCs do not add. Two facts undo the assumption. First, the violation omits
  *fi*, so in the baseline window the conditions show the response to different words,
  405 to 505 ms after their onset, and that response continues into the epoch. Second, step
  08 subtracts each trial's baseline mean per channel, which moves the conditions' difference
  in that mean into every later sample with its sign reversed. The amplitude models enter
  the mean as a covariate instead, which the Method did not contrast. The finished matrix
  (HTC 8960052_1, pulled in `40083cb`) shows the pattern. Decoders trained in the first third
  of the baseline classify its last third at 0.44, a reversal that subtraction produces
  whenever the difference changes across the window. The last third carries into the first
  100 ms after onset (0.52, and 0.53 in reverse). From 200 ms a different, sustained pattern
  holds (0.54 off the diagonal), on which the last third of the baseline scores 0.50. The
  sentence written on 15 October in `40083cb` reported that decoders trained before onset
  classified the post-stimulus period at 0.50. That is true as an average, but it hid the
  carry-over into the first 100 ms. The fix removes both "bound" claims and states the
  subtraction in the Method beside the covariate treatment (Alday, 2019).
  `dec_tgm_sentence()` now computes the three-part description from the matrix and says
  that the matrix cannot attribute the late pattern to a violation response. A marker
  replaces it if a later matrix stops fitting it. The Discussion now says that no part of
  the separability can be attributed to a violation response. A rerun without subtraction
  would not settle the question, because the preceding-word difference is in the design,
  not in the preprocessing. `test_decoding_prose.R` covers the helper. Decided on 17 October
  2026: that rerun is not done now. It cannot change the claim, and it would need an edit
  to `08_extract_decoding_matrices.R`, which is held back from ARC while the gender run uses
  it. It is kept for a reviewer who asks, after the gender run.

## Added 7 October 2026

- **N18. The posterior predictive check helpers fail on exit, after writing the figure,
  because the colour scheme they save cannot be restored (MINOR, open: the fix is proposed
  below and not applied. Fix would change a reported number: no).** The signal-detection
  refit (HTC 8976036) logged `PPC failed: 'scheme' should be a character vector of length 1
  or 6` for both of its fits. `les_save_ppc()` and `les_prior_predictive_check()` in
  `_shared/R/02_diagnostics.R` (lines 199-200 and 264-265) save the caller's colour scheme
  with `bayesplot::color_scheme_get()` and put it back on exit with `color_scheme_set()`.
  The getter returns the scheme as a list of six colours, and the setter takes only a scheme
  name or a character vector of six, so the restore fails on every call. This was reproduced
  on the render box with bayesplot 1.15.0, the version `renv.lock` pins. The exit handler
  runs after `ggsave()`, so the figure is written whenever `pp_check()` succeeds, and both
  signal-detection figures are in the store's `paper_2_plasticity/figures/`, written at
  04:20 and 04:46 BST on 4 October. The session is left on the `darkgray` scheme. The RNG
  restore registered after the failing handler still runs, so the guarantee G01-12 added
  holds (checked under R 4.6.1, not under the cluster's 4.5.1). The failing handler's error
  also replaces any error the body raised, so the warning reads the same whether
  `pp_check()` failed or succeeded, and only the figure's presence tells the two apart. The
  restore dates from 7d8bafd (7 September), so every check run with that code has ended
  this way. It stayed hidden while the callers wrapped the helpers in `try(silent = TRUE)`,
  which G06-06 replaced with a warning on 3 October (4a545e7 for Paper 1, 2352752 for
  Paper 2). Paper 1's steps 03 and 04 wrap the same helpers the same way, so their fits
  report the same failure. No reported value is affected. Paper 2 reads no predictive check
  figure, and Paper 1's step 03 copies the representative prior-predictive panel whenever
  the file exists, which the failure does not prevent, because the panel is written first.
  Until the fix lands, 04's header is wrong to say that a failed check "leaves no figure".
  The fix is one line in each helper,
  `old_scheme <- unlist(bayesplot::color_scheme_get(), use.names = FALSE)`, which leaves
  the `on.exit()` call as it is. Its comment should say why, and that it assumes a scheme of
  six-digit colours. On the render box it restores the default scheme's six colours and
  raises nothing, but it cannot restore the viridis family, whose getter returns eight-digit
  `#RRGGBBAA` colours that the setter rejects (checked with bayesplot 1.15.0). No project
  code sets such a scheme, because the only `color_scheme_set()` calls are the helpers' own.
  Wrapping the restore in `tryCatch()`, with a warning in its handler, makes it safe for any
  scheme and stops it from ever replacing an error the body raised. The change is to the
  shared module, which no running job sources, and it needs no refit, because it changes
  only what happens after the figure is written.

- **N19. The re-pulled prior specification carries the signal-detection refits' bias
  priors, which the article's check against supplement S6 did not recognise (MAJOR,
  resolved in the working tree on 8 October 2026: `.s6_prior()` has the rule and S6 states
  the priors. Fix would change a reported number: no).** The pull of 7 October brought the
  summaries rerun after the signal-detection refits (HTC 8976041), so
  `paper_2_plasticity/results/_prior_specification.csv` now holds the priors of
  `p2_predictive_trajectory_sdt` and `p2_predictive_trajectory_gender_sdt`. In both, each
  of the nine predictors' interaction with grammaticality has a normal(0, 0.25) prior and
  its interaction with grammaticality and session a normal(0, 0.15) prior, whatever the
  predictor's own prior (`les_p2_partA_priors()` in `04_fit_brms_predictors.R`). The
  prior-spec-check chunk of `paper_2_neuroplasticity.qmd` compares every explicitly set
  prior of every pooled model with the rules of S6 through `.s6_prior()`, which had no rule
  for a coefficient beginning `recoded_grammaticality:`. The render of 7 October therefore
  printed a visible PRIOR-SPECIFICATION MISMATCH block in the Method's Priors section, a
  paragraph of 377 words listing 36 rows (two models, nine predictors, two terms each) as
  "S6 no rule", on pages 17 to 19 of the PDF and in the docx and HTML. The check did what
  G15-23 built it to do, because S6 did not describe these priors. The pass of 8 October
  gave `.s6_prior()` the rule and stated the priors in S6. Run against the pulled table, the
  check now finds no mismatch among the 220 rows it compares, and the render of 8 October
  no longer prints the block. The variant models stay in the check, because the article
  prints estimates from both of them.

- **N20. The signal-detection variant's random effects lacked a by-participant slope for
  grammaticality by session (MAJOR, resolved: fixed in `d55790d` and refitted on 11 October
  2026 as HTC 9016531, with the summaries (06) as 9016532. Fix would change a reported
  number: yes, the signal-detection estimates in the Discussion).** `LES_P2_SDT=1` crosses every fixed term of Part A with grammaticality, so each
  predictor-by-session term gains a twin that relates the predictor to the change in
  response bias over training. The first fit (HTC 8976036, 4 October) carried
  by-participant intercepts and slopes for session and for grammaticality, but none for
  grammaticality by session, so each learner's own drift in bias could be absorbed only by
  the between-participant terms. In the two fits now in `results/`, 7 of the 18 bias-drift
  terms exclude zero, the Stroop and ASRT terms in both strata and the working-memory,
  alpha and theta terms in the pooled stratum, against none of the 18 predictor-by-session
  terms, whose drift the by-participant session slope absorbs. Those seven intervals are
  probably too narrow (Barr et al., 2013). Commit `d55790d` (8 October) gives the variant
  `(1 + z_session_time * recoded_grammaticality | participant_lab_ID)` and leaves the
  reported models' formulas unchanged. Until the refit lands, the Discussion reports
  working memory's sensitivity and bias terms in both strata and deliberately draws no
  interpretation from them. The Method defines the scale of both terms once, under
  *Learning outcome and model structure*, and the Discussion points there. The Discussion
  also says that the bias-drift terms are not interpreted, because without the matching
  by-participant slope such terms are estimated too confidently (Barr et al., 2013). The
  gate on them is `.p2_sdt_has_slope()` in `manuscript_setup.R`, which looks in
  `_prior_specification.csv`, for each signal-detection model, for an `sd` row with coef
  `z_session_time:recoded_grammaticality` under `participant_lab_ID`. brms writes that row
  for the formula of `d55790d`, and the rows of the first fits lack it. Once both models
  have it, `p2_sdt_drift_ok()` turns the statement into a marker asking for the drift
  terms. If only one stratum has been refitted, the statement covers the other and a marker
  asks for the refitted stratum's terms, and a missing or incomplete record prints a
  pending marker. This gate replaced one on the fit dates in `_pooled_fit_metadata.csv`,
  which a fit made after 8 October from a stale formula would have passed. Once the refit
  lands, rerun `06`, pull the pooled tables and describe the drift terms.
  **Outcome, 12 October 2026.** The refit ran on 11 October (07:47-11:17) and 06 at 11:18.
  Both models converge (maximum R-hat 1.0008 pooled and 1.0005 gender, minimum bulk ESS
  7,131, no divergences), and both prior records carry the new `sd` row. None of the 18
  bias-drift terms now excludes zero, so the seven of the first fit came from the missing
  slope. The population-level grammaticality-by-session terms also lose credibility
  (pooled -0.20 [-0.36, -0.03] became 0.08 [-0.32, 0.48], and gender 0.55 [0.37, 0.73]
  became 0.36 [-0.05, 0.76]). Working memory's terms barely move: sensitivity 0.29
  [-0.02, 0.59] pooled and 0.37 [0.03, 0.70] gender, bias -0.14 [-0.48, 0.21] and -0.30
  [-0.68, 0.09]. The four tables were pulled with `pull_results.sh` and logged.
  `.p2_sdt_drift_sentence()` now reports the drift terms' null from the summaries, with a
  marker if a later refit makes any of them credible. The reading of working memory's
  sensitivity and bias terms is still the author's to write (`AUTHOR_TASKS.txt`, 12
  October).

## Added 4 October 2026

- **N16. The tracked task-duration tables paired each Gorilla home ID with its lab ID
  (MAJOR, resolved in f455211 in the tracked files; the cluster store and this repository's
  history still hold the old copies).** All four `_task_durations_{home,lab}.csv` carried a
  `participant_home_ID` column beside `participant_lab_ID`. The writer had stopped writing it
  (c672bb5, 9c5c273), and the codebook said it is not written, but the tables were last
  regenerated on 11 September by the older code. Step 13 cannot be rerun on the cluster until
  the decoding jobs end, because it needs the held-back `03_data_manifest.R`, so the column
  was removed in place, with every other cell verified identical. Two consequences remain.
  The store's copies still hold the column, so `pull_results.sh` reports both files as
  changed: do not pull them until step 13 has rerun. And the column is in this private
  repository's history; check that no public copy of the repository carries these files.

- **N17. Supplement S4 called the filter's bias on the aperiodic parameters "close to a
  constant", and script 07 quoted measurements under the superseded filter model (MAJOR,
  resolved in f455211).** Script 12 now writes `_aperiodic_filter_sensitivity.csv`, script 07's
  own decomposition of each spectrum as recorded and with the realised filter divided out.
  Correcting flattens the exponent by 0.52 on average, the exponents correlate r = .955 (median
  shift 0.12 SD, largest 1.0 SD), and the peak count changes for one participant, not the 29
  the earlier model gave. S4 prints these values from the artefact.

## Added 3 October 2026

- **N15. The trial-retention descriptives still read the legacy count table, so they miss
  the two recovered records (MINOR, resolved: 00c counts retained trials from the extracted
  single-trial cell files (aad57ed); the rerun, HTC 8976030, was pulled in 2e89d05, and the
  Method reports 31.5 trials per cell, 34.3% not retained, over 874 cells).**
  `00c_extract_erp_retention.R` takes its counts from `data/EEG_trial_count_per_condition.csv`,
  which the legacy descriptives script wrote from the original exports. The nine reprocessed
  Session 3 records keep exactly the trials of their 1 Hz exports, so their counts are right,
  but the two records recovered under Amendment 6 of the reprocessing protocol were
  re-segmented at their own events and now hold different numbers of trials (Session 6 of lab
  ID 5 and Session 2 of lab ID 7). The table also still counts the excluded duplicate export
  (Session 3 of lab ID 48). The Method and the note of the trial-retention table now say that
  the figures describe the datasets as first exported. Fix: count retained trials from the
  extracted single-trial data, or from the overlay manifest and its provenance record, so
  that the descriptives describe the analysed sample; then re-run 00c and re-render.

## Added 18 September 2026

These findings arose while checking a handoff note against the artefacts and the cluster,
after Paper 2's results were pulled from the store.

- **N14. The Discussion proposed a test the materials cannot support (MAJOR, resolved in the
  working tree. Fix changed a reported claim: yes, in the Discussion).** The Discussion
  attributed part of the criterion difference to misanalysis arising where "Norwegian gender
  assignments or agreement patterns ... do not match those of the miniature language", and
  proposed "an item-level analysis relating false alarms to the Norwegian gender of each
  noun" as a direct test. The gender-assignment half of that mechanism cannot operate, and
  the proposed analysis cannot be run, because congruency with Norwegian is constant by
  construction. Read out of the deposited stimulus lists: every noun takes the gender of its
  Norwegian translation equivalent, checked over all 24 gender-agreement nouns of the design
  (12 in Session 2, 12 from Session 3 on), and the check does not rest on the reader's
  Norwegian, because all 144 `noun_adj_ID` entries carry identical gender in the
  Mini-Norwegian and Mini-English lists, so gender is a property of the concept rather than
  of the surface language. The two languages therefore differ in where gender is marked, not
  in which gender a noun takes. Fixed by narrowing the mechanism in the Discussion to
  agreement patterns, stating why the assignment route is closed and the item analysis
  unavailable, and adding the assignment rule to the Materials, which described the
  common/neuter system but not how nouns were assigned to it. The finding supports the
  paper's existing argument that Norwegian gender remains available to both groups, and it
  is a design limitation worth keeping in view: with congruency at ceiling, this design
  cannot detect gender transfer through assignment at all.

- **N10. Two of the aperiodic parameterisation's six predictors are structural zeros
  (MAJOR, resolved: kept in the reference model and held out of the projection's search, as
  decided on 18 September 2026 and implemented in 50cb919. Fix would change a reported
  number: yes, but only if the model is respecified).** *Corrected on the day of writing: an earlier draft of this entry rated
  the finding BLOCKING and said the two coefficients were reported as band-power effects.
  That is wrong, and the manuscript is in the clear. `paper_2_neuroplasticity.qmd:866-870`
  already prints the fitted-peak counts and then states that "the adjusted theta and beta
  predictors are therefore close to constant, and we do not interpret their coefficients or
  their positions in the selection path", and `:1586` restricts the de-confounding argument
  to "the one adjusted band with a fitted peak in most recordings". The disclosure is
  accurate and sufficient. What follows is the mechanism behind it and its one live
  consequence.*
  `07_extract_aperiodic.R:309-313` defines the oscillation-adjusted band power as the summed
  height of the specparam peaks whose centre falls inside the band, and returns exactly `0`
  when the band holds no peak. `n_peaks` is 1 for 56 of the 60 eyes-closed recordings and 2
  for 3 of them, and that single peak is almost always the alpha peak. In
  `results/07_aperiodic_features.csv`, `theta_adj` is exactly zero for 59 of 60 recordings
  (the one non-zero value is 0.726) and `beta_adj` for 51 of 60, which matches the counts
  the manuscript prints for the post-exclusion sample (1 and 9 of 59). `alpha_adj` is zero
  for 8 of 60 and is usable, though zero-inflated. Collinearity is not the problem: over the
  six predictors the correlation matrix has condition number 3.9 and full rank, the largest
  correlation being .83 between exponent and offset.
  The live consequence is that two near-constant terms are nonetheless carried into the
  projection, which is what makes the cross-validated variable selection fail (N11).
  **Decided and implemented, 18 September 2026: keep them in the reference model, exclude
  them from the projection's search.** The specparam FAQ and @donoghue2020 are explicit
  that a band with no fitted peak carries no evidence of periodic activity at that
  frequency, so the zero is the correct measurement and not a missing value; the variables
  are simply unusable as individual-differences predictors here. Dropping them from the
  reference model was rejected because the raw-band and aperiodic reference models must
  carry the same terms for the leave-one-out and K-fold comparison between them to be like
  for like, and that comparison is a reported result. Restricting the forward search
  changes no reported coefficient. `08_projpred_selection.R` now tests every
  population-level term for constancy within each cross-validation fold and passes the
  survivors to `cv_varsel()` as `search_terms`. The test is stated as the numerical
  condition that causes the failure rather than as a list of variable names, so it follows
  the decomposition if a different band turns out to be empty and is a no-op on the pooled
  and gender selections. Documented in the Method and in supplement Section S5.
  *Note of 7 October 2026.* No selection path is reported any more (G13-01), so nothing in
  either document depends on where the adjusted bands would enter one, and the Method no
  longer describes the restriction. It stays in 08, because the aperiodic search cannot run
  without it, and 08c applied it too, searching 7 of that model's 9 participant-level
  predictors.
- **N11. HTC 8826762 (`p2_projpred`, aperiodic) failed on 18 September, and N10 is why
  (MAJOR, resolved: the search now uses projpred's default blocks when a term is fold-constant
  (50cb919), and the aperiodic selection completed on 28 September, HTC 8910229, pulled in
  fc6fccc).** The job ran 34 h and died with `Error: solve(): solution not found`
  during `cv_varsel`'s per-fold performance evaluation, at about the fifth of ten folds
  (`paper_2_plasticity/hpc/logs/08_projpred_aperiodic.Rout`). The grouped CV splits 49
  participants into folds of 5, and a fold drawn at random is entirely zero on `theta_adj`
  with probability about .92 and on `beta_adj` with probability about .43. A predictor with
  no variance inside a fold makes the projection's weighted least squares singular, which is
  what Armadillo's `solve()` reports. The failure is therefore deterministic, not transient,
  and resubmitting unchanged will fail again. The ten reference refits that cost most of the
  34 h all succeeded and are cached in
  `store/.../p2_predictive_trajectory_aperiodic_cvfits.rds` (17 September 05:29, newer than
  the reference fit of 16 September 19:48, so the cache is current), so a rerun after N10 is
  settled need not repeat them.
  **Fix committed and the rerun chained, 18 September 2026 (see N10).** Job 8826760 (the
  pooled selection) is executing `paper_2_plasticity/scripts/08_projpred_selection.R`, the
  very file the fix edits. Overwriting it in place is unsafe: `deploy_to_cluster.sh` extracts
  with `tar -xf`, which truncates the target and keeps its inode, so a running job can see
  the file change underneath it. Replacing it by atomic rename would be safe on a local
  filesystem but not reliably so here, where `/home/educ1242` is NFS and the compute node
  holding the old inode open can be handed a stale file handle.
  It is therefore chained rather than forced. The fixed script is staged, untouched by
  anything, at `~/new_LESS/.staged_2026-09-18/08_projpred_selection.R`
  (md5 `d1f82bd554e480f00903fa28c7035b2a`, verified after transfer). Job **8843694**
  (`p2_swap_launch`, short partition, standard QoS, `afterany:8826760`) swaps it into place
  once the pooled selection has ended and then submits
  `paper_2_plasticity/hpc/08_projpred.slurm aperiodic`. It re-checks the md5 before moving
  anything and keeps the superseded copy beside the staged one, so a partial or corrupted
  stage cannot clobber the deployed script. Slurm holds its own copy of the batch script, so
  the chain survives a `/tmp` clean during the wait.
  The cached `cvfits` means the rerun should not repeat the ten reference refits. Confirm
  the guard fired by looking for "excluded from the search" in
  `paper_2_plasticity/hpc/logs/08_projpred_aperiodic.Rout`, and the swap in
  `paper_2_plasticity/hpc/logs/00_swap_launch.out`. Afterwards, fold the staged file into a
  normal deploy so the cluster and the repository agree, and delete
  `.staged_2026-09-18/`.
  **The 18 September fix was itself defective, and its run is void (26 September 2026).**
  The swap and the guard both fired (8843694, then 8861266, which ended on 20 September),
  but the guard passed the surviving population-level labels as `search_terms`. projpred
  2.10.0 reads a custom `search_terms` as the entire candidate set (`?varsel`, Details), so
  the by-participant intercept and slope entered no submodel. The forward search also lost
  the default blocks that keep an interaction behind its main effects:
  `z_session_time:grammatical_property` was chosen at step 1 and `z_session_time` at step 17.
  No submodel came within one SE of the reference model, so `suggest_size()` failed and 17
  was recorded. `08_projpred_selection.R` now starts from projpred's own default blocks
  (`split_formula()`, as `parse_args_varsel()` builds them) and drops only the blocks that
  touch a fold-constant variable, which keeps 21 of 25 blocks for this model. It refuses to
  run if a group-level block would be dropped, and it is a no-op when no predictor is
  constant. The void outputs and logs are archived under
  `store/.../results/_archive_2026-09-26_aperiodic_search_defect/`. The corrected rerun is
  HTC **8910229**, which reuses the cached `cvfits` (17 September, newer than the reference
  fit). Once it lands, pull all three path CSVs together. Then revise the prose it touches:
  the pooled suggested size moves from 6 to 7, so "exactly the suggested size" no longer
  holds; the aperiodic sentences about the path cap change; and supplement Section S5 still
  describes the defective mechanism.
  **Resolved 30 September 2026.** 8910229 ended on 28 September with no warning: 21 of 25
  default blocks searched, the by-participant intercept and slope at steps 1 and 3, every
  interaction after its main effects, suggested size 6 (the scaffold and digit span), the
  aperiodic exponent and offset at steps 12 and 14, the specparam IAF last at 18. The three
  path CSVs (pooled and gender from 8826760/8826761, all post-exclusion, n = 55, 55 and 49)
  and `_projpred_path.csv` were pulled together, md5-verified, and the three passages above
  were rewritten, the pooled one behind a render-time check that prints a marker if a later
  path stops matching its wording.
  *Note of 7 October 2026.* Those passages and their render-time check left the manuscript
  with the ranking (G13-01). The three path files stay in `results/` as the record of
  8826760, 8826761 and 8910229.
- **N12. Six stages of the participant-flow table were one participant too high (MAJOR,
  resolved in the working tree. Fix changed reported numbers: yes).**
  `_sample_flow.csv` was written at
  16 September 14:46 and `paper_2_plasticity/data_derived/learning_trajectory.rds` was
  re-extracted at 15:42, so the flow read the pre-exclusion trajectory. Counted directly
  from the current artefacts, the trajectory holds 63 participants with participant 14
  already absent, the Session-1 battery holds 63 including participant 14 (62 after
  `.drop_dev()`), and their intersection is 61. The shipped rows read 64, 63 and 62. The
  code at `00_extract_participants.R:187, 236-237` is correct; only a run was missing.
  **Resolved 18 September 2026.** `00_extract_participants.R` was re-run alone on HTC
  (job 8842405, 13 s; the existing `00_descriptives.slurm` also re-runs script 02, which
  needs no change, so a one-off job ran script 00 by itself). The store copies it replaced
  are archived under `store/_archive_2026-09-18_before_flow_regen/`. Six rows moved, all by
  one participant: battery_baseline 63 to 62, trajectory 64 to 63, joint_predictor 62 to
  61, usable_erp 63 to 62 (Mini-Norwegian 30 to 29) and usable_rseeg 57 to 56
  (Mini-Norwegian 28 to 27); usable_accuracy stayed at 63, and the enrolment and attendance
  stages are unchanged by design. Both papers' copies are now byte-identical, which closes
  the 63-versus-64 divergence commit 7068299 opened. `_participants.csv` and
  `_participants_other_languages.csv` were regenerated in the same pass and proved
  byte-identical to the committed copies, so the concern that they were stale does not
  hold: they describe the enrolled sample, which keeps participant 14.
- **N13. Three entries above are stale and should not be re-derived (housekeeping).** G15-07
  ("Figure S1 plots nine battery records with no participant linkage") is resolved by the
  18 September store pull, not by a code guard: the regenerated `_predictor_values.csv` is
  an inner join over the linked, post-exclusion sample, with zero unlinked rows, zero
  participant-14 rows and 57 records per predictor (56 for Stroop), against 66/65/66 before.
  The one-line `!is.na(participant_lab_ID)` filter its fix proposed is no longer needed. The
  chunk comment and the figure note at `supplement.qmd` were stale in the opposite direction
  once the artefact landed and have been rewritten. G15-03's
  "the supplement renders ... to .16, presenting the superseded with-practice value as the
  test-block result" no longer holds: the `stroop_scoring` guard its own fix (3) proposed is
  implemented at `manuscript_setup.R:251-256` and `:277-281`, so before the pull both
  accessors printed visible pending markers, and after it they print .16 and .32 as the
  prose claims. G02-01 was resolved on 18 September when `les_funnel()` was deleted in favour
  of `les_flow()`; only its header comment survives at `_shared/R/05_funnel.R:29`.

## Added 16 September 2026

These findings arose while acting on the PI's feedback of 14 September and on the author's
decisions of 16 September about the 1 Hz recordings and participant 14.

- **N1. The accuracy models' grammaticality terms were read as discrimination (BLOCKING,
  resolved in the working tree).** With `correct` as the response, every term containing
  grammaticality indexes response bias, and the terms without it index sensitivity
  (DeCarlo, 1998). Paper 1 reported the gender grammaticality x language and
  grammaticality x session x language terms as a Mini-Norwegian "advantage" in
  discrimination. They are a criterion difference: Mini-Norwegian learners judged
  gender-agreement sentences grammatical more readily, with no credible group difference in
  sensitivity. Fixed by `accuracy_sdt_contrasts()` in script 05
  (`results/_accuracy_sdt_contrasts.csv`), participant-level d' and c in script 02
  (`_accuracy_sdt_by_language.csv`), a maximal-slope sensitivity refit
  (`LES_P1_ACC_MAXRANEF=1`), and a rewrite of the manuscript's behavioural Results,
  Discussion and abstract. No reported model was changed.
- **N2. The group displays were not comparable between groups (MAJOR, resolved in the
  working tree).** Scripts 07 and 07b wrote uncorrected amplitudes, grammatical-minus-
  ungrammatical differences and Session 6 only, and the manuscript scaled each group's row
  separately. They now baseline-correct within participant, write violation-minus-control
  differences, add a participant-balanced pooled session and a difference-wave file, and the
  figures share one scale and show the groups side by side, with a group-difference
  topography.
- **N3. `_shared/hpc/deploy_to_cluster.sh` hangs on Windows while LESS jobs are live
  (MAJOR, resolved in 5b50d49: the "hang" was the per-file process cost under Git Bash, and the
  script was rewritten to batch its cluster calls and hold back the files live jobs read).** The live-job matching loop (`files_of_job`, a `sed ... | head -1` inside
  a command substitution) deadlocked under Git Bash on 16 September with the Paper 1 chain
  live; the first deploy that day, with no jobs live, never entered the loop. Replace the
  `head -1` pipe with `sed -n '...{p;q}'`, or run the deploy from the cluster side.
- **N4. The usable-data counts disagreed about participant 14 (MAJOR, resolved in the
  working tree).** `00_extract_participants.R` counted judgement participants from the
  accuracy files, which now exclude participant 14, but ERP and resting-state participants
  from tables that do not. Every usable-data stage now removes the protocol-deviation
  exclusion.
- **N5. Paper 1's tracked results were older than the store (MINOR, resolved).** The pooled
  summaries in `paper_1_transfer/results/` dated from 20 August, while the store held the
  11 September pooling, so the review draft of 15 September rendered superseded numbers.
  Resolved by commit 7068299 and verified on 18 September: every Paper 1 results CSV now
  matches the store byte for byte once line endings are normalised, with three deliberate
  exceptions. `_pooled_posterior_summaries.csv`, `_retention_contrasts.csv` and
  `_prior_sensitivity.csv` are the store's files with the `erp_` rows removed, which is the
  withholding the review draft's own callout describes; the repository copy of the first is
  byte-identical to the store's minus those rows (99 of 1,443). Two further apparent
  differences are not differences: `_provenance.csv` differs only in the recorded
  timestamp, and the six `_electrode_grand_average_*` files are newer in the store but are
  read by neither manuscript. Note when comparing that the repository copies use CRLF and
  the store's use LF, so a raw checksum reports every file as changed.
- **N6. Three task-EEG exports are not what their labels say, and Session 2 used another
  reference (BLOCKING, resolved; the ERP refits are in (a09e259), and the decoding rerun,
  HTC 8960051-8960055, was still running on 4 October 2026).** A
  trial-identity audit of all 1,344 trial-by-trial exports (210 participant-sessions,
  Sessions 2, 3, 4 and 6) matched every exported trial to its recording through the export
  marker timestamps and the Analyzer histories, and a screen of the same exports checked each
  for a stimulus-locked response (split-half reliability of the posterior average, 0-600 ms;
  mean .88). Scripts and outputs: `tmp/recon/audit_trial_identity.py`,
  `audit_trial_identity_all.csv`, `audit_summary.txt`, `tmp/screen_exports.py` and
  `screen_exports.csv` in the 16 September job scratch (to be moved into the repo with the
  reprocessing code). Each finding below was then checked on the exported EEG, and the
  exclusions are fixed in `docs/eeg_filter_reprocessing_protocol.md`, Amendments 2 and 3.
  1. *Session 2 of participant 10 looked 1 Hz but is 0.1 Hz (retracted).* Its history's
     filter and New Reference nodes now read 1 Hz and "implicit not included", but they were
     edited after export: rebuilt from raw, the export matches at 0.1 Hz with the majority
     Session-2 settings (RMSE 0.00029 µV) and fails at 1 Hz by 4.5-6.0 µV, accelerometer
     channels included. It was briefly added to `LES_P1_MISFILTERED` and to the protocol
     (Amendment 2) and withdrawn (Amendment 4, 2f8ad4a). History text alone is not evidence.
  2. *Session 3 of participant 48 duplicates participant 58's Session 3.* The history's root
     is 58's recording; all 198 trial timestamps coincide with 58's, and timestamp-paired
     trials correlate at median r = .90 at Pz (other pairs: chance). Excluded through
     `LES_P1_INVALID_EXPORTS`. No processing decision behind it was made on 48's own
     recording, so the protocol (Amendment 2) cannot recover it.
  3. *Session 6 of participant 5 is cut at Session-4 event times.* Its history reads the
     Session-4 marker file, so its export timestamps are Session 4's, but its EEG does not
     match Session 4's (paired r = .00) and carries no stimulus-locked response (split-half
     reliability of the posterior average, 0-600 ms: r = .28, against .75-.96 in the other
     recordings checked). Excluded through `LES_P1_INVALID_EXPORTS`; the Session-6 raw
     recording exists and can be reprocessed.
  3b. *Session 2 of participant 7 has no stimulus-locked response.* Its history starts from a
     recording made at 10:38, while the archived raw file starts at 11:27, and carries
     marker-edit and segmentation nodes before inspection. Split-half reliability .00
     (-.07 on S101/S102), correlation with the leave-one-out Session-2 grand average -.02;
     the participant's Sessions 3, 4 and 6 reach .96-.98. Excluded through
     `LES_P1_INVALID_EXPORTS`. The next-lowest export, Session 2 of participant 63
     (split-half .32), correlates with the grand average like the rest and is retained.
  4. *Session 2 used a different New Reference setting.* All 63 Session-2 task exports were
     referenced to (TP9 + TP10 + 0) / 3 with FCz recovered and the unreferenced channels
     (TP9, TP10, accelerometer) kept; the ICA ran on the 32 electrodes but not on FCz. No
     Session-3, -4 or -6 history does this. The exact correction to the linked-mastoid
     convention was first implemented on 16 September as `c + FCz_export / 2`, validated
     against rebuilds of IDs 10, 11, 12 and 20 (condition means within 0.00003 µV;
     uncorrected, the ROI-averaged difference is off by 0.44-2.32 µV). That validation was
     circular and the formula is superseded by `c - (TP9 + TP10) / 6`, FCz × 1.5 (N8).
     *Paper 2 (open, author decision):* the Session-2
     resting-state exports use their own nodes with the same settings, so every resting-state
     feature is computed against (TP9 + TP10 + FCz) / 3. The reference is the same for every
     participant, so there is no between-participant confound, but it is not the linked
     mastoids; either the Method states the actual reference or `03_extract_resting_state_eeg.R`
     applies the same correction and the resting-state models are refitted.
  5. *Provenance anomalies with no effect on the exported data:* Session 4 of participant 7
     (the archived raw marker file codes 144 property-3 events as `S  2`; the history holds
     the corrected `S  3`, so the export is right); Session 2 of participant 12 (the
     recording was appended from a continuation file); Session 4 of participant 16 (38
     exported trials lie in segments the history now lists as removed, so the exports predate
     the final manual inspection); Session 6 of participants 31 and 38 (the property-1
     exports were baseline-corrected before export, which the baseline-as-covariate models
     absorb). These are recorded for the data paper, not acted on.
- **N7. A third of the presented trials never reached the exports, for a segmentation
  reason the Method did not describe (MAJOR, resolved: the audit is in the repository with its
  tables (a548a3b), the Method reports them from those tables (2e89d05), and the reprocessing
  decision was taken under the protocol. The trigger-rule check of Amendment 5 is written
  (2bc1c09) and ran on 22 October 2026, HTC 9149457-9149459, once the four raw Session 2
  recordings were placed from OSF tq7vy with their SHA-256 checked. It first failed the
  reconstruction gates of S2/10 and S2/12, because the events stage lacked two things the
  16 September validation had used: the Session-2 export reference settings and S2/12's
  continuation file. It was corrected before the analysis stage had run (a29f215). All
  seventeen recordings then passed. Three of the twelve cells pass the 0.91 µV bound, and
  one interval excludes zero (gender agreement, 200-500 ms, lateral, D = -0.55 µV [-1.07,
  -0.03]). Paper 1 reports the failure as a limitation, as the amendment requires).** Assessed on 17 September from the
  behavioural logs, raw markers, exports, histories and OSF materials, with two independent
  recomputations per central claim (job scratch `tmp/trial_audit/`, report
  `report/N7_assessment_report.md`). The design presented 48 trials per property ×
  condition per session (all 1,350 logged cells). Each critical word sends four serial
  triggers (word identity at onset, sentence, property, condition) with a nominal 10 ms but
  realised ~10.7 ms spacing (`send_trigger`: write byte, sleep 10 ms, write 0; identical in
  all 15 materials versions). The child segmentation (−130..1070 ms around S10x) keeps an
  epoch only inside a parent (−120..1080 ms around `S  k`), i.e. only when the
  property→condition interval is exactly 5 samples: 21,520 of 64,427 recorded events failed
  that rule and none was exported. The artefact step was *semi-automatic*, not absent: all
  448 inspection nodes flagged segments by criteria (30 µV/ms step, 100 µV range in 200 ms,
  0.5 µV activity in 100 ms) without writing markers, and 473 flagged segments were removed
  on review (the 16 Sep figures 21,341/486 and "no automatic criterion" were wrong). Within
  recordings, loss is unrelated to S102 vs S101 (OR 1.01 [0.97, 1.06]), accuracy and item;
  weak single-session associations with response time and trial position; the Mini-English
  group at Session 6 retained 4 points fewer grammatical than ungrammatical trials (p = .003).
  Epoch labels understate time since the word trigger by 0-6 ms (mean 1.6; negligible). A
  lag-tolerant re-export of all recordings (52 GB of raw data, weeks) would give ~1.5× trials
  but narrow the key gender language-difference interval by only ~3-10%; recommended
  against. Still to do: move the audit scripts into the repo and read the Method's numbers
  from their artefacts; add the language × session retention breakdown; correct Amendment 1's
  wording on artefact rejection in the next protocol amendment. Side findings of the same
  assessment: seven exports lack a `.vmrk` and are silently dropped by the importer (S3/17
  gender S101, S4/34 number agreement, plus S3/14 and S3/19 S103); participant 20 lacks the
  LHQ3 covariate; `_misfiltered_share.csv` is stale (4 datasets); the Session-2 correction
  and the ERP random-effect structure were verified separately and changed (N8, N9). The
  importer now reports unpaired exports by name (`scripts/_eeg_import.R`), and the marker
  files of S3/17 and S4/34 are to be rebuilt from their histories and admitted through the
  overlay manifest as `markers_rebuilt` (protocol Amendment 5, pending). Participant 20's
  missing covariate still needs an author decision (impute, or report their trials' loss).
- **N8. The Session-2 reference correction of 16 September used the wrong formula (MAJOR,
  fixed in the working tree; refits pending).** `c + FCz_export / 2` equals the correct map
  before the ICA, but after it re-references ICA-cleaned scalp channels to *uncleaned*
  mastoids and adds back a third of each removed component's FCz potential. Its validation
  built the target with the same map, so it could not see this. The replacement,
  `c_export - (TP9_export + TP10_export) / 6` for the 30 scalp electrodes and
  `1.5 × FCz_export`, re-references the analyst's cleaned data to the cleaned mastoids, an
  identity that holds on the exports to quantisation precision. Three checks on
  17 September favoured it (job scratch `tmp/trial_audit/verify2`): operator error 0.063
  against 0.247 on a never-exported linked-mastoid ICA branch in participant 45's Session-2
  history; closer to a linked-mastoid refit in 21 of 24 condition cells of an independent
  replication with another ICA implementation (median absolute error in S102 - S101: 0.03
  against 0.13 µV). The two formulas differ in the Session-2 S102 - S101 contrast by a median
  of 0.26 µV per participant and about 0.02 µV in the group mean. Implemented as
  `les_p1_s2_rereference()` in `_config.R`, applied per file by the vendored importer
  `scripts/_eeg_import.R` (which replaced the join-based correction that ran out of memory
  on the decoding extraction), tested algebraically in `test_exclusion_guard.R` and on real
  exports in `tests/test_eeg_import.R`. The 16 September grand averages and fits are
  superseded. Paper 2's resting-state question (N6.4) is unchanged by the formula choice.
- **N9. The ERP models treated a trial's cluster rows as independent observations (MAJOR,
  fixed in the working tree; refits pending).** Each trial entered six (lateral) or three
  (midline) rows, one per electrode cluster, with no term for the trial. Rows of a trial
  correlate at 0.45-0.64, so the rows pseudoreplicate it (Lazic, 2010), and the intervals of
  trial-level terms that no random slope protects were 1.4-2.0 times too narrow
  (grammaticality × session and its three-way interaction with language above all). Checked
  in lme4 on all 18 cells, in glmmTMB and in a brms benchmark. On the pre-reprocessing sample,
  all three credible three-way cells and the DOM and VOA grammaticality × session cells
  would lose credibility; gender grammaticality × session at 400-900 ms survives, and the
  gender null tightens. Author decision of 17 September: one row per trial per macroregion
  (the equally weighted mean of the clusters), with the by-participant grammaticality ×
  session slope `(1 + G * S | participant)` (Barr et al., 2013; Brauer & Curtin, 2018).
  Hemisphere and caudality leave the models, with the caudality prior; topography is
  described by the group topographies. Implemented in `01_extract_erp_single_trials.R` and
  `03_fit_brms_erp.R`; fits are stamped with `LES_P1_ERP_MODEL_VERSION`, and script 05 and
  the manuscript's exclusion rule refuse fits without the current version. The fit is run
  once, after the 1 Hz records are reprocessed (protocol Amendment 5, pending). The same
  change retired `LES_P1_KEEP_MISFILTERED` for `LES_P1_EXCLUDE_REPROCESSED`, the robustness
  analysis the protocol prespecifies.

## Before the queued Stroop refit chain is pulled back

Three findings bore on the chain queued on HTC on 11 September. G11-01 (no Paper 2 writer
for `_prior_sensitivity.csv`) and G11-02 (stage 06 pooling fits of different vintages) are
fixed in the working tree by a vintage gate and a prior-sensitivity writer in
`paper_2_plasticity/scripts/06_summaries.R`, and the whole Paper 2 chain was resubmitted on
16 September with participant 14 excluded (HTC 8826747-8826762). G15-03 (the reliability
prose) still needs the author's rewrite once the new `_predictor_reliability.csv` lands.

*Updated 8 October 2026.* That chain landed, and its results were pulled on 18 September in
`df4008e`, so nothing in this section is pending. All three findings are resolved. The main
text reads the test-block reliability, .32, from `_predictor_reliability.csv`, and
supplement S1 prints the rise from the with-practice value, .16, to .32.

## BLOCKING (20)
### G02-01. les_funnel reports net stage difference as 'lost'; Paper 2 figure shows '-18 67% kept' at S5->S6, where 19 were lost

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `_shared/R/05_funnel.R:148`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:482`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:487`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:476`, `_shared/R/05_funnel.R:28-35`, `_shared/R/05_funnel.R:136-137`
- **What goes wrong:** Rendering Paper 2 with the committed _sample_flow.csv labels the S5->S6 transition '-18 67% kept' and draws it as a nested narrowing. Participant 20 skipped S5 and came back for S6, so 19 were actually lost and 64.8% kept. The published figure misstates attrition, and no warning is raised.
- **Evidence:** 05_funnel.R:148-150 `lost = utils::head(s$n, -1) - utils::tail(s$n, -1), kept = utils::tail(s$n, -1) / utils::head(s$n, -1)` and :197 `label = sprintf("-%d %.0f%% kept", lost, 100 * kept)` work only from stage totals. :136-137 also draws a tapering ribbon between every consecutive pair. The header (:28-35) says ribbons appear only 'where the subset relation genuinely holds' and that '"attended S6" is not a subset of "attended S5"', but nothing checks this.
- **Fix:** les_funnel cannot detect non-nesting from totals, so pass membership-based transition counts in. (1) Add optional per-stage columns to les_funnel (for example `lost`, `gained` and `kept_n`, each relative to the previous stage in the tier). When they are supplied, use them in place of the totals-based head/tail differences. Where gained > 0, drop the tapering ribbon (or mark it) and label the drop, for example '-19 (+1 returned) 65% kept'. Defaults stay as they are, so Paper 1's figure is unchanged; re-render it to confirm. (2) In paper_2_neuroplasticity.qmd, read results/_participant_matrix.csv and compute, for each consecutive attendance pair, lost = sum(prev & !cur), gained = sum(!prev & cur) and kept_n = sum(prev & cur). Fall back to the current behaviour, with a warning, when the matrix is missing. A simpler alternative that needs no helper change is to move 'Attended Session 6' into its own tier, which removes the ribbon and the loss label.
- **Status:** resolved in the working tree on 18 September 2026 (presentation pass), by a different fix. `les_funnel()` is deleted, and both flow figures are drawn by `les_flow()`, a CONSORT-style diagram. Attendance is one box per group with a line per session, each giving that session's absences against the group's enrolment, and no arrow or loss label joins two sessions, so no nesting is implied. Arrows and exclusion counts appear only in Paper 2's Part A chain, which is nested, and `les_flow()` warns and draws that chain without them if a count ever rises. The Paper 2 note states that absences are not cumulative.

### G04-01. Exclusion list names 4 of the 9 Session-3 datasets whose Analyzer history records only a 1 Hz high-pass

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/_config.R:138`, `paper_1_transfer/scripts/_config.R:162`, `paper_1_transfer/scripts/_config.R:176`, `paper_1_transfer/scripts/00c_extract_erp_retention.R:175`, `paper_1_transfer/results/_misfiltered_share.csv:2`, `paper_1_transfer/scripts/08_extract_decoding_matrices.R:305`
- **What goes wrong:** Participants 53, 60, 61, 62 and 65 enter every Session-3 ERP fit, the decoding tensor (08 calls les_p1_drop_misfiltered) and the retention share. Their data carry the same 1 Hz filter the Method says was excluded because of artefactual opposite-polarity N400/P600 effects. The manuscript's exclusion guard still clears, because les_p1_misfiltered_rows() only matches the four listed IDs, so the Method's claim that 0.1 Hz was used for every other dataset is printed without a marker.
- **Evidence:** _config.R:113-116: "Four Session-3 recordings were high-pass filtered offline at 1 Hz rather than the 0.1 Hz used for every other dataset in the study (recovered from the archived BrainVision Analyzer history...)"; :138-142 hard-codes `participant_lab_ID = c(7L, 8L, 9L, 16L), session = 3L`. No script derives or checks the list against the tracked histories (git ls-files lists data/raw data/EEG/Session */History/*.ehst2).
- **Fix:** 1) Maintainer confirmation first. Show them the evidence: the Session-3 histories of 53, 60, 61, 62 and 65 contain only a 1 Hz IIR high-pass node, their exports descend from it, and the exported epochs show the same sub-1 Hz variance suppression as 7, 8, 9 and 16. Ask them to verify in BrainVision Analyzer. 2) Extend LES_P1_MISFILTERED (_config.R:138-142) to participant_lab_ID c(7, 8, 9, 16, 53, 60, 61, 62, 65), session 3. Do not generate it from a string grep of .ehst2 alone. Add a read-only audit script that writes a tracked results/_offline_filter_audit.csv with, per participant-session, the high-pass cutoff(s) found in the history and the empirical export diagnostic (per-epoch DC variance / within-epoch variance on the trialbytrial exports, threshold about 0.03). Have test_exclusion_guard.R assert that the set flagged by the diagnostic equals LES_P1_MISFILTERED. 3) Replace the literal counts with nrow(LES_P1_MISFILTERED) in the messages at _config.R:162 and :176.
- **Status:** resolved before this pass (verified 3 October 2026): The 9 records are listed (`_config.R:158`). They were reprocessed, validated (protocol l.140) and admitted (6953772, 4fa6da5); the ERP refit is in (a09e259); decoding is running. `_misfiltered_share.csv` was the last stale artefact and is fixed under N15.
  nine records, the message counts use `nrow()`, `test_exclusion_guard.R` asserts the list,
  and the ERP grid, accuracy models, group displays and decoding were resubmitted on that
  sample (HTC 8826186-8826204, 8826320). The raw `.eeg` files of all nine sessions were
  recovered from OSF (components tq7vy and be3nt) and hash-verified. The planned remedy is
  in `docs/eeg_filter_reprocessing_protocol.md`: reprocess at 0.1 Hz, make the reprocessed
  data primary, keep the exclusion as the sole sensitivity analysis. The finding stays open
  until the reprocessed overlay passes that protocol's validation and the affected
  artefacts are regenerated.

### G04-03. LHQ3 item-7 zero placeholders enter the reported English age of exposure and years of use as real zeros

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/00_extract_participants.R:94`, `paper_1_transfer/scripts/00_extract_participants.R:323`, `paper_1_transfer/results/_participants.csv:14`, `paper_1_transfer/paper_1_morphosyntax.qmd:1582`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:460`
- **What goes wrong:** Both manuscripts print English age of first exposure and years of use computed with an unanswered record counted as exposure from birth and 0 years of use. The means are biased down and the SDs inflated, with nothing flagging it.
- **Evidence:** 00:94-98 converts the slot values with `.num()` and accepts 0: `mods <- .num(c(row[[base_en + 1]], ...)); aoa_listen <- mods[1]; ... years <- .num(row[[base_en + 5]])`. In LHQ3 Raw Data.xlsx the record monr7 (in the key, Mini-English) reads: 'German | 0 | 1 | 6 | 6 | 18', 'English | 0 | 0 | 0 | 0 | 0', 'Norwegian | 0 | 0 | 0 | 0 | 0', 'N/A | 0 | 0 | 0 | 0 | 0'. The form's blank default is therefore 0, and this Norwegian-English participant's English and Norwegian entries are unanswered, not zero years of use. results/_participants.csv: 'eng_aoa_listen',6.7778,3.9897,63,0,22;
- **Fix:** 1. In .les_lhq3_english (00_extract_participants.R:93-99), set the English entry to missing (aoa_listen, aoa_4mod and years all NA) when its five numeric fields are all 0. Justify the rule in a comment: an onset at birth with zero years of use is internally impossible. Do not justify it as an export blank default, because the export leaves unused slots NA. 2. Warn about, and list by lhq3_id, any English entry that has years of use 0 but is not all zeros, so a partial anomaly is not silently kept. 3. Record the number of entries set to missing in the note of the eng_aoa_listen, eng_aoa_4mod and eng_years rows, or in a new count row. If you add a row, also update the codebook entries (_shared/R/codebook_descriptions.csv and both results/CODEBOOK.md). 4. Update the header wording at lines 37-41: 'reproduces the ~6.8 previously reported' will no longer hold (6.9). 5. Have the maintainer confirm that monr7's English entry is invalid before regenerating. 6. Re-run 00 only where the derived objects it also reads are available.
- **Status:** resolved in aad57ed: `00:.les_lhq3_english()`: an English entry whose 5 numbers are all 0 becomes NA, with the reason in the comment (an onset at birth with 0 years of use cannot both hold). An entry with 0 years but other values non-zero triggers a warning, after the key filter. The rerun is done (HTC 8976030-8976031) and its tables were pulled in 2e89d05.

### G06-02. RT screen runs before de-duplication, so duplicate log rows are reported as valid trials and RT exclusions

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/02_extract_accuracy.R:293`, `paper_1_transfer/scripts/02_extract_accuracy.R:318`, `paper_1_transfer/paper_1_morphosyntax.qmd:1872`
- **What goes wrong:** The Method reports 42,116 valid trials, 8,504 RT exclusions and 20.2%. The correct figures are 42,048, 8,436 and 20.1%. The de-duplication step it describes does nothing: the second logging, with a stale multi-million-ms response_time and a wrong correct = 0, is disposed of only because the RT screen happens to reject it. Any sensitivity run without the upper RT bound would keep those corrupt rows until distinct(), and the screen's denominators are silently inflated in the published text.
- **Evidence:** 02:293-295: `n_valid <- nrow(acc)`; `acc <- acc %>% filter(response_time > LES_P1_ACC_RT_MS[1], response_time < LES_P1_ACC_RT_MS[2])`. De-duplication comes only afterwards, at 02:318: `distinct(participant_lab_ID, session, grammatical_property, trial, .keep_all = TRUE)`. Committed results/_accuracy_rt_screen.csv: 42116,33612,8504,20.1918510779751. Committed _accuracy_sentence_inventory.csv n_trials: 4936+8794+11541+8341 = 33,612 = n_kept. So distinct() removes zero rows, and every duplicate was removed by the RT screen and counted as an RT exclusion.
- **Fix:** (1) Code. In 02_extract_accuracy.R, move the distinct() at 02:318, keeping the first occurrence, ahead of `n_valid <- nrow(acc)` at 02:293, so that the screen counts de-duplicated trials. Optionally record the number of duplicate rows removed, and assert that the generic response_time equals response_time_grammaticality_judgement_response on the retained rows. (2) Rerun and re-render. Re-run 02 to rewrite _accuracy_rt_screen.csv (expected 42,048 / 33,612 / 8,436 / 20.06%), then re-render Paper 1. The inline values at qmd:1872-1875 update themselves, and the de-duplication sentence at qmd:1876-1878 becomes accurate as written. The re-run also rewrites accuracy_&lt;property>.rds with identical content; before resubmitting, confirm that les_brm's file cache does not trigger a refit. (3) Codebook. Update CODEBOOK.md:22-25 to define n_valid_trials as de-duplicated trials, and document any new column. No refit is needed.
- **Status:** resolved in aad57ed: `02`: `distinct()` now runs before `n_valid`, so the RT screen counts de-duplicated trials. A new column `n_duplicates_removed` is added. On ARC: 68 duplicates, all with RT 2.6–7.6 million ms and correct = 0. The rerun is done (HTC 8976030-8976031) and its tables were pulled in 2e89d05.

### G08-01. 09b copies gender's exploratory rows from an older tensor that still has the 4 mis-filtered datasets, unchecked

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/09b_assemble_confirmatory_timecourse.R:147`
- **What goes wrong:** On 2026-09-04 (checkpoint mtime 13:21, CSV mtime 15:06) 09b merged the B=1000 overall block, which excludes the four 1 Hz Session-3 datasets, with gender exploratory blocks from an earlier run that included them (3493 Session-3 trials against the 3277 left after exclusion). The time-grid, column and n_perm checks all passed. The published CSV therefore holds gender session-3 and session-3-by-language cells computed on data the Method says were excluded. Two manuscript passages depend on these rows.
- **Evidence:** 09b:144-153 copies the old CSV's exploratory rows into the new CSV, checking only their column names: `explor <- old[!is_conf_old, , drop = FALSE]` / `missing <- setdiff(keep, names(explor))` / `res <- dplyr::bind_rows(banked[, keep, drop = FALSE], explor[, keep, drop = FALSE])`. Nothing compares their n_trials or n_participants with the banked block. In the committed paper_1_transfer/results/gender_agreement_decoding_timecourse.csv (Rscript read): overall n_perm=1000, n_trials=12882, n_participants=63.
- **Note (16 September 2026):** the artefact is being superseded. The decoding stage was
  resubmitted in full on the corrected sample (all nine 1 Hz records and participant 14
  excluded; HTC 8826320), so the new CSVs will not contain the mixed blocks. The guard below
  is still worth adding before 09b is used again.
- **Fix:** The proposed guard needs tightening. 'Exploratory participants must be a subset of the banked participants' cannot be checked from the n_participants counts; at most max(n_participants) &lt;= banked. In 09b, before the bind at 152: (a) sum the by_session levels' n_trials and stop unless the sum equals the banked n_trials when every LES_ERP_SESSIONS level is present, or is at most the banked n_trials otherwise; also require each session's by_session_language cells to sum to that session's by_session n_trials. (b) Where the old confirmatory rows are not already the banked block, require their n_trials and n_participants to equal the banked values. Check (a) is the one that also catches a re-assembly from the already-assembled CSV, whose overall rows now match the banked block. Optionally, load the tensor through .les_complete_trials() and compare every level's n_trials exactly. For the artefact (needs sign-off): before submission or deposit, replace paper_1_transfer/results/gender_agreement_decoding_timecourse.csv with the full CSV from 8736986_0.
- **Status:** resolved in d9d9fab: Artefact: superseded by 8960051_0, which writes gender's whole CSV at B = 1000 from the 2 Oct tensor; pull it (and `_decoding_provenance*.csv`) when 08b reports READY. The decoding rerun (HTC 8960051-8960055) is still running; its output has not been pulled.

### G09-01. 08_decoding.slurm does not guard LES_P1_KEEP_MISFILTERED, so it can silently overwrite reported decoding artefacts

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/08_decoding.slurm:62`
- **What goes wrong:** sbatch propagates the submitting shell's environment by default (--export=ALL). Suppose an operator ran `export LES_P1_KEEP_MISFILTERED=1` in the login shell for the mis-filter-retained refits of 01/03, then submits or resubmits 08_decoding.slurm from that shell. The tensor and every &lt;property>_decoding_*.csv are then rebuilt with the four 1 Hz Session-3 datasets included and written under the reported names. After a pull, the manuscript reports decoding on the wrong sample. Nothing fails and nothing is flagged, because no manuscript check inspects the decoding sample.
- **Evidence:** 08_decoding.slurm:62-68 sources arc_env.sh, sets errexit/nounset, reads LES_DECODE_STAGE, and never unsets or refuses LES_P1_KEEP_MISFILTERED. The extractor honours the switch: 08_extract_decoding_matrices.R:220 `keep_misfiltered = identical(Sys.getenv("LES_P1_KEEP_MISFILTERED"), "1")` and :305 `raw <- les_p1_drop_misfiltered(raw)`, and _config.R:161-164 returns the data unfiltered when `les_p1_keep_misfiltered()` is true.
- **Fix:** Minimal, now: (a) in paper_1_transfer/hpc/08_decoding.slurm, directly after `set -o nounset` (line 64), refuse instead of silently unsetting: `if [ "${LES_P1_KEEP_MISFILTERED:-0}" = "1" ]; then echo '[decoding] refusing: LES_P1_KEEP_MISFILTERED=1, but the decoding tensor, checkpoints and CSVs are untagged and would overwrite the reported artefacts' >&2; exit 1; fi`. It must run before either Rscript call and so covers both stages. (b) For defence in depth that also covers direct Rscript runs, and without editing the held-back 09_run_decoding.R, add `if (les_p1_keep_misfiltered()) stop(...)` inside les_decode_rds() in 08_extract_decoding_matrices.R. 09 obtains the tensor path through it, and it is not part of any deparsed fingerprint: the tensor fingerprint deparses only .les_build_decoding_tensor and les_p1_drop_misfiltered and stats _config.R, so the banked tensor cache stays valid. Do not put the check inside .les_build_decoding_tensor, whose deparse is fingerprinted.
- **Status:** obsolete: `LES_P1_KEEP_MISFILTERED` was retired in 8f0fb8b and nothing reads it. Its successor, `LES_P1_EXCLUDE_REPROCESSED`, tags every decoding output (d9d9fab).

### G10-01. Stroop index averages RT over error trials with no accuracy screen; S1 word-readers enter as ordinary values

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:158`
- **What goes wrong:** At least four enrolled participants (gxac7, kwly7, rqed8, sjnh6) answered incongruent trials with the word, not the ink colour. Their 'incongruent' mean RT is about 90-96% error responses, and a further two (swbd5, idyh6) are near chance on both trial types. Their interference scores (80-165 ms) sit inside the normal range, pass every check, and enter z_stroop in Part A, the Part B Stroop and joint pre/post models, and the split-half reliability. This probably contributes to the index's near-zero reliability.
- **Evidence:** 01:149-168: the trim groups by `participant_home_ID, Correct` (152), then `trimmed %>% select(rt, participant_home_ID, Congruency) %>% ... summarise(mean_rt = mean(rt, na.rm = TRUE))` (158-164). No filter on `Correct` and no accuracy criterion anywhere; the only exclusion is `filter(n() >= LES_P2_MIN_OBS_STROOP)` (151). The header (16-28) gives no rationale beyond 'taken VERBATIM from the validated legacy scripts'. Read-only base-R check of the new_LESS Session 1 batch exports, test trials only.
- **Fix:** Needs author sign-off; do not apply autonomously. 1. Choose and justify a performance criterion. No analysis plan was preregistered, so present it as a data-quality screen and report the result both with and without it. For example: exclude a session's Stroop index when incongruent-trial accuracy is below a stated threshold, or when fewer than a minimum number of correct trials remain in either congruency cell. 2. Compute accuracy as `tolower(Response) == tolower(Answer)`, or `dplyr::coalesce(Correct, 0) == 1`. Never use mean(Correct, na.rm = TRUE), because Stroop 3.csv codes errors as a blank Correct. 3. Apply the screen per session, since Session 5 has its own cases (jpxp4). Decide whether RT means use correct trials only, and if so update the 'averaged over correct and incorrect responses alike' sentence at qmd:533-534 and supplement.qmd:144. 4. Decide how an excluded Stroop score enters Part A. NA means listwise deletion of the whole participant (04:349); the alternative is a documented handling. Update the participant-flow counts to match. 5.
- **Clarified (17 October 2026, from the committed exports, test trials only):** The task is four-colour Stroop colour naming. The keyed answer is the ink colour, the capitalised colour of the stimulus file name (`REDgreen.jpg` is keyed `red`). Two different failures occur, in seven sessions.
  (a) *Responding to the word instead of the ink colour* (Session 1: gxac7, kwly7, rqed8 and sjnh6). On incongruent trials they pressed the word's colour on 73% to 98% of trials and the ink colour on 2% to 8%. On congruent trials, where the two coincide, they were 88% to 96% correct.
  (b) *Low accuracy on both trial types* (Session 1: swbd5 and idyh6; Session 5: jpxp4). They were 42% to 60% correct on both, above the 25% of chance with four response colours but far below the sample's median of 94%, with errors spread over the non-target colours, which points to inattentive or mis-mapped responding and not to reading. The sample median is 94% on incongruent trials. Every other session is at 78% or above, so an incongruent-accuracy screen at .70 separates the two groups.
  A further Session-1 record (ltsl3, 18 incongruent trials) is already excluded by the minimum trial count.
  *Why the code let them through:* `les_p2_stroop()` (01:226-264) averages reaction times over correct and incorrect trials alike. Its only participant-level filter is `n() >= LES_P2_MIN_OBS_STROOP`, and no stage computes Stroop accuracy (01, 02, 04, 10 and 11 included). The rule was carried over verbatim from the legacy scripts. Fast, consistent word reading yields an ordinary interference score (26 to 178 ms for group a), so neither the range checks nor the split-half reliability nor the descriptives, which count trials but not accuracy, could flag it.
  *A keying error found in the same check:* Gorilla spreadsheet row 114 (`BLUEyellow.jpg`, a test trial) is keyed `yellow`, the word, and not `blue`, the ink. Gorilla therefore scores ink responses on that trial as errors, for every participant in both sessions (65 of 66 and 53 of 54). The reaction-time index ignores `Correct`, so it is unaffected, but any accuracy screen or correct-trials-only scoring must score that trial against the ink colour.
  Among the remaining sessions, the current index and a correct-trials-only index correlate at .965 (Session 1) and .982 (Session 5).
- **Status:** resolved (author decision of 17 October 2026, implemented in 16fed74 and 724d946): the Stroop index is scored on correct trials judged against the ink colour, and a session with incongruent accuracy below .70 gets no score; the screened participants leave Part A, and the unscreened results are kept as a sensitivity analysis (frozen in 445f002). Refit chain HTC 9124806-9124820 ran on 17-18 October and is pulled; every fit converges. The Method states the screen, the Participants section computes who listwise deletion removes, supplement S1 gives the failures, the keying corrections, the reliabilities (.16, .32, .35) and the screened-against-unscreened comparison, and the Results point to it. No individual-difference term changes its relation to zero.

### G11-01. _prior_sensitivity.csv, which the manuscript quotes, has no writer and will be stale after the queued Stroop refit

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/06_summaries.R:9`
- **What goes wrong:** When 8782459 lands and the CSVs are pulled back, report_effect() at qmd:1131 prints the refitted gender-agreement estimates. sens_effect("p2_predictive_trajectory_gender","z_iaf","inf") at qmd:1144 still prints the July informative-prior estimate for the same term from the superseded fit, and qmd:1150 claims "the level-not-rate asymmetry ... does not depend on the prior specification" from pd values of fits that are no longer reported. Nothing flags the disagreement.
- **Evidence:** 06_summaries.R:9-16 lists the eight outputs of the summaries stage, and _prior_sensitivity.csv is not among them. .run() at 277-285 calls pool_artefacts, derive_attainment, slope_reliability, prepost_ns, prior_specification and derive_predictor_contrasts, and none of these computes it. git grep finds no writer anywhere under paper_2_plasticity/scripts or hpc. results/CODEBOOK.md:243 says: "No pipeline stage writes this file; its columns follow les_prior_sensitivity()".
- **Fix:** (1) Operational, before 06 (8782459) output is pulled: submit the weak-prior Part A refit on the new index, chained afterok on 8782457: sbatch --clusters=htc --account=educ-intract --export=ALL,LES_PRIOR_SET=weak,LES_PROVENANCE_SKIP=1 paper_2_plasticity/hpc/04_fit_predictors.slurm. Then re-run 06_summaries.slurm. (2) Code: add collect_prior_sensitivity() to 06_summaries.R, modelled on Paper 1's 05_posterior_summaries_and_contrasts.R:381-472. Pair LES_P2_MODELS[["predictive"]] and [["predictive_gender"]] with their _weakprior ids, call les_prior_sensitivity(paper2_results(), id), set s$model &lt;- id, and skip any pair whose fitmeta n_obs differ or whose weak fit has no fitmeta record. Write _prior_sensitivity.csv, or delete a stale copy when no pair qualifies so the manuscript prints its pending marker. Call it from .run(). Once the fit record carries an upstream-input fingerprint (see G11-02), also require the fingerprints to match. (3) Optionally make sens_effect(..., "inf") read post_tbl, or print a pending marker when sens_tbl's informative values disagree with post_tbl.
- **Also reported as:** G15-01
- **Status:** resolved before this pass (verified 3 October 2026): b07f553: `collect_prior_sensitivity()` 06:263-314, called in `.run()`; pulled in df4008e; 44/44 rows match pooled summaries; both pairs share n_obs and input digest.

### G11-02. 06 pools every artefact with no input-vintage check, so tables will mix new-Stroop fits with old-Stroop variants

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/06_summaries.R:60`
- **What goes wrong:** After 8782459, _pooled_posterior_summaries.csv holds p2_cognition_prepost_joint scored on the test block alone next to p2_cognition_prepost_joint_signaligned scored with the practice block. signaligned_sentence() then includes or omits its interpretive clause from a pd gap between fits on different Stroop scorings. The IAF-resolved and weak-prior rows likewise rest on the superseded z_stroop, and nothing in 06 or the manuscript can tell.
- **Evidence:** 06:60-62 globs every `_convergence\.rds$`, `_summary\.rds$` and `_fitmeta\.rds$` in results/, and 06:73-86 binds them unconditionally. hpc/README.md:183: "Re-run 06_summaries.slurm after any variant run: it pools every fit artefact present". The fit metadata records no input identity: _config.R:119-131 stores only model, n_obs, n_participants, prior_set, versions and fitted_utc. The queued Stroop chain (AUTHOR_TASKS.txt:437-441) submits the default 04 and 05 only.
- **Fix:** (1) Operational, before the post-rescore CSVs are pulled and rendered, chained afterok on 8782457/8782458. Run sbatch --export=ALL,LES_PRIOR_SET=weak,LES_PROVENANCE_SKIP=1 04_fit_predictors.slurm; sbatch --export=ALL,LES_P2_IAF_RESOLVED=1,LES_PROVENANCE_SKIP=1 04_fit_predictors.slurm gender; sbatch --export=ALL,LES_P2_SIGN_ALIGNED=1 05_fit_prepost.slurm joint. Also run the planned 09 with LES_PROVENANCE_SKIP=1 (ISSUES.md #3). brms file_refit = on_change refits each on the changed data. Then re-run 06. If the author prefers not to refit a variant, set its artefacts aside on the store so the manuscript prints its pending marker; that is the author's decision. (2) Code: extend les_p2_write_fit_meta() with a stroop_scoring field and a content digest of each shared upstream input the fit read: cognitive_indices.rds, learning_trajectory.rds, and resting_state_eeg.rds or 07_aperiodic_features.csv where used. Do not digest the per-variant brms data frame. In 06, compare each pooled fit's upstream fingerprint with its reference fit's, and write a stale_inputs flag into the pooled tables.
- **Also reported as:** G10-06
- **Status:** resolved before this pass (verified 3 October 2026): b07f553: `vintage_gate()` 06:113-197, input digest + exclusions in every fit record; all 14 pooled records pass. Residual: 09b's `_commonsample` records carry no digest (mtime fallback)

### G11-03. 04 silently fits a cognitive-only model under the reported id when resting_state_eeg.rds is missing

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/04_fit_brms_predictors.R:209`
- **What goes wrong:** Suppose resting_state_eeg.rds is absent from the store while learning_trajectory.rds is present, for example after a cleanup or a 03 re-run that has not yet written. A routine `sbatch 04_fit_predictors.slurm` then changes the Stan code, so brms refits and overwrites p2_predictive_trajectory.rds with a model lacking z_alpha to z_iaf. That model is fitted on a larger sample, because no rs-EEG listwise deletion applies. The multi-day reference fit is lost.
- **Evidence:** 04:186 `if (file.exists(rseeg_path)) {`, then 04:208-211 `} else { message("[p2-partA] resting_state_eeg.rds not found -- fitting with cognitive predictors only ", "(run 03 on the HPC to add the rs-EEG predictors).") }`. The model id does not depend on the predictor set (04:351-356). The fit is cached at `file = paper2_results(model_tag)` (04:379) with les_brm's `file_refit = "on_change"` (01_bayesian_settings.R:313). The header at 04:28-31 still presents this as intended: "Until 03 has run on the HPC, the model is fit with the cognitive predictors only;
- **Fix:** 1. Script 04. In les_p2_load_partA_data, stop (not message) when resting_state_eeg.rds is absent and aperiodic = FALSE. If a cognitive-only model is ever wanted, gate it behind an explicit switch with its own model tag. 2. Assertion. In fit_paper2_partA, after les_p2_partA_predictors, stop unless setequal(preds, cand), naming any missing term. This also catches the silent-drop path of the all-NA guard when a join matches no rows (see G11-04). 3. Submit chain. In submit_all.sh, when 03 is submitted, add afterok:${JID_EEG} to 04's dependency. With LES_SKIP_RSEEG=1 the new stop in 04 covers a missing file. 4. Documentation. Update 04:28-31, submit_all.sh:10-14, hpc/README.md:68 and 116-121, and HPC_RUNBOOK.md:192-194 so 03 is no longer described as optional for Part A. 5. Deployment. Do not deploy the edited 04 while the queued Stroop refit chain's 04 is pending or running (HPC_RUNBOOK: do not scp a script a running job is executing). With the file present, preds and the Stan code are unchanged, so file_refit does not refit and no banked fit is invalidated.
- **Status:** resolved in 2352752: 04:247-254 stops when `resting_state_eeg.rds` is absent; 04:310-319 requires every predictor; header 04:26-34 and 04 slurm header updated. `submit_all.sh` afterok on 03: patch P3 (hpc_docs owns, = G14-04)

### G12-01. 12's observed/extrapolated gamma ratio uses a background fitted to low-pass-attenuated bins, inflating it about 6x

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/12_extract_gamma_attenuation.R:99`
- **What goes wrong:** The committed artefact and the rendered Method compare 60% against the 6.5% the filter passes (about 9x). An unattenuated background estimate gives 7-10% against 6-6.5% (about 1.1-1.5x), so 'far exceeds' and the mains-energy explanation rest on a fitting artefact.
- **Evidence:** 12:76 keeps bins within LES_AP_SETTINGS$fit_range (2-40 Hz); 12:88 fits them; 12:99-100 `obs_ratio <- sum(band$power) / sum(10^(params[1] - params[3] * log10(band$freq_hz)))`. By the script's own two-pass response (12:64), T(f) is 0.658/0.403/0.250 at 25/28/30 Hz (-1.8/-4.0/-6.0 dB), and 45% of the 2-40 Hz bins have T&lt;0.8. So the 'extrapolated background' is fitted partly to already-filtered power. A read-only in-memory rerun of 12's code on the committed results/_resting_state_psd.csv reproduced _gamma_attenuation.csv exactly (max|diff| 7e-16).
- **Fix:** The proposal (swap in a 2-20 Hz or P/T background and keep the sentence) is incomplete: the replacement number is assumption-dependent, ranging from about 0.4x to 2x depending on filter reading and extrapolation. Minimal correct remedy, needing author sign-off: (1) In 12, replace or supplement observed_over_extrapolated with a background that uses no roll-off bins. Either fit 2 Hz to a passband bound where two-pass T(f) > 0.9 (about 20 Hz), or fit log10(P/T) over 2-40 Hz. Report the observed / T-weighted-background excess under both the single- and two-pass readings. Document the method and its T(f) dependence in the header (and add the missing column to 12:41-43) and in CODEBOOK.md:103. (2) Regenerate _gamma_attenuation.csv. (3) Have the author revise qmd:570-572, via gamma_att_obs_clause() at manuscript_setup.R:193-200. The 'far exceeds' wording and the 50 Hz mains attribution should go, or be replaced with a range that says the excess is modest and depends on the assumed filter response.
- **Status:** resolved: script 12 models Analyzer's filter as it is applied (2352752). The rerun (HTC 8976035) was pulled in 51bdb75, and the Method and supplement were rewritten: the filter passes a median 28% of the background's 30-45 Hz power, and the observed power is no more than it would pass.

### G12-03. LES_AP_FIT_MAX_HZ leaks into 12 via source(07), silently overwriting the untagged reported _gamma_attenuation.csv

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/12_extract_gamma_attenuation.R:76`, `paper_2_plasticity/hpc/10_descriptives.slurm:33`, `paper_2_plasticity/scripts/07_extract_aperiodic.R:121`
- **What goes wrong:** Someone runs `export LES_AP_FIT_MAX_HZ=30` for 07's passband sensitivity pass, then submits 10_descriptives.slurm from the same shell. _gamma_attenuation.csv is regenerated from 2-30 Hz fits under the reported name (retained median 0.060 instead of 0.065; observed/extrapolated median 0.21 instead of 0.60), and the manuscript injects it with the codebook still saying 2-40 Hz.
- **Evidence:** 12:56 `source(... "07_extract_aperiodic.R")`. 07:121-124 reads LES_AP_FIT_MAX_HZ at source time, and 07:131 sets LES_AP_SETTINGS$fit_range from it. 12:76 filters on `freq_hz <= LES_AP_SETTINGS$fit_range[2]`, but 12:112 always writes the untagged `paper2_results("_gamma_attenuation.csv")`. The wrapper hpc/10_descriptives.slurm:32-33 says 'The variant switches must be unset' yet unsets only LES_P2_STROOP_KEEP_PRACTICE. _shared/hpc/arc_env.sh has no unset of LES_ vars, and sbatch exports the submitting environment by default. 12's header (line 20) and CODEBOOK.md:99 hard-code 'over 2-40 Hz'.
- **Fix:** 1. In 12_extract_gamma_attenuation.R:112, write `paper2_results(sprintf("_gamma_attenuation%s.csv", les_ap_range_tag()))`, so a passband-only run lands beside the reported file as 07's outputs do. Include the fit range in the message at 115-124. Add one header line (near 20 and 41) saying the output is tagged when LES_AP_FIT_MAX_HZ is set. 2. Add `unset LES_AP_FIT_MAX_HZ` next to the existing unset at 10_descriptives.slurm:33. 3. Add a LES_AP_FIT_MAX_HZ row to the variant-switch table in paper_2_plasticity/hpc/README.md. It should say the switch affects 07 and 12, give the tag `_fit<max>hz`, and give the `--export=ALL,LES_AP_FIT_MAX_HZ=30` recipe. Do not change the codebook text. With the variable unset, the output is byte-identical to the current file.
- **Status:** resolved in 2352752: 12 writes `_gamma_attenuation<les_ap_range_tag()>.csv`, logs the fit range and documents the tag in its header. `10_descriptives.slurm` now unsets `LES_AP_FIT_MAX_HZ` (with a comment). Tested: with the variable at 30, it writes `_gamma_attenuation_fit30hz.csv` beside the untagged file.

### G13-01. projpred ranking of individual-difference terms reproduces the formula's candidate order exactly in all 3 paths

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/08_projpred_selection.R:301`
- **What goes wrong:** Once the by-participant intercept and slope are in the submodel, adding any participant-constant predictor changes the in-sample latent projection by almost nothing. If the forward search then breaks near-ties by candidate position, the reported ranking (working memory first, gamma and IAF last) is an artefact of the order the formula lists terms in. It would come out the same whatever the predictors' predictive value, and it would still read as a real result. The cv_prop_diag values of 0.8-1 in the gender path fit near-ties settled by noise just as well as they fit a real ordering.
- **Evidence:** Candidate order is fixed in 04_fit_brms_predictors.R:245-251: c("z_digit_span", "z_stroop", "z_asrt", paste0("z_", .les_p2_rs_terms)), with .les_p2_rs_terms &lt;- c("alpha", "theta", "beta", "delta", "gamma", "iaf") at 04:110. For the aperiodic model it is digit_span, stroop, asrt, aperiodic_exponent, aperiodic_offset, theta_adj, alpha_adj, beta_adj, specparam_iaf. The shipped paths follow that order exactly, and each interaction comes immediately after its own main effect.
- **Fix:** 1. Diagnose on ARC (cheap, no CV). For each reference fit, build refmodel &lt;- get_refmodel(fit, latent = TRUE) and run varsel() with nterms_max set to the full term count, twice: with search_terms listing the individual-difference terms and their session interactions in reversed order, and in one random permutation. If the ranking follows the supplied order, the artefact is confirmed. vs$search_path keeps only the chosen terms, not every candidate's criterion. To look for ties, project the scaffold plus each single candidate with projpred::project(refmodel, predictor_terms = ...) and compare the projections directly. 2. If confirmed, do not simply force the scaffold including (1 + z_session_time | participant_lab_ID) through search_terms. Those group terms are what absorb the participant-constant predictors, so forcing them in leaves the problem in place.
- **Status:** resolved by the author's decision of 7 October 2026, after the order diagnostic (`08c_order_diagnostic.slurm`, HTC 8976038, pulled on 7 October into `results/diagnostics/`). With the by-participant intercept and slope in the submodel, every participant-level candidate reaches the same projection criterion (largest relative difference 0 among 9 pooled, 0 among 7 aperiodic and 1.69e-16 among 9 gender-agreement candidates), and the pooled and aperiodic searches admit the main effects in whatever order they are supplied. The ranking and the suggested size left the Results and the Discussion, the Method points to supplement S5, S5 reports the diagnostic and why no ranking is given, and the review note of 51bdb75 is gone (this pass). A redesigned search that admits the participant-level terms before the by-participant terms was offered and declined.

### G13-02. nterms_max behind the committed gender path is unrecorded; comments wrongly say NULL means all terms

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/08_projpred_selection.R:241`, `paper_2_plasticity/scripts/08_projpred_selection.R:105`, `paper_2_plasticity/scripts/08_projpred_selection.R:154`, `paper_2_plasticity/hpc/08_projpred.slurm:32-38`, `paper_2_plasticity/hpc/09_aperiodic_model.slurm:48-49`, `paper_2_plasticity/manuscript_setup.R:320-339`
- **What goes wrong:** After the Stroop-rescore refits, stage 08 is resubmitted with hpc/08_projpred.slurm as documented. The gender search is then truncated at 19 terms, so z_gamma and z_iaf are never evaluated, and projpred_gender_result() silently drops its 'full candidate set ... rank last of all' sentence. The committed gender artefact cannot be reproduced from the documented recipe, and nothing on disk says it needed LES_PROJPRED_NTERMS=23.
- **Evidence:** 08:105 '# LES_PROJPRED_NTERMS max solution-path size (default: all candidate terms)'. 08:239-241 '(nterms_max counts terms; leave NULL to let projpred use the full set.) nterms_max &lt;- if (length(.les_nterms) && !is.na(.les_nterms)) .les_nterms else NULL'. hpc/08_projpred.slurm:32-34 'leaves nterms_max NULL, i.e. every candidate term, unless LES_PROJPRED_NTERMS is set, and nothing here sets it'.
- **Fix:** The proposed fix is incomplete and, in one branch, harmful. Setting LES_PROJPRED_NTERMS in both slurm files, or defaulting 08 to the full term count, would lengthen the pooled and aperiodic paths from 19 to 23 terms on rerun. That would falsify the hard-coded sentences 'The forward search was capped at projpred's default path length ...' (qmd:1166-1169) and 'The same path cap left the adjusted beta power and the specparam individual alpha frequency unreached' (qmd:1175-1177). Instead: (a) Correct the comments at 08:105, 08:239-240 and 08_projpred.slurm:32-38 to say that NULL gives projpred's min(19, D). Documentation only. (b) Make the per-stratum setting explicit and reproducible: gender full-length (LES_PROJPRED_NTERMS=21 or 23, projpred caps at D), pooled and aperiodic at the default. Document that in the slurm and hpc/README with the exact sbatch --export line. Alternatively, decide to run every stratum full-length and make the cap sentences conditional.
- **Status:** resolved in 2352752: 08 header and comments now say NULL means projpred's min(19, D). The 8826760 log shows "Cutting off the search at size 19". The 8826761 gender log has no cut-off and a 21-term path, so that run had LES_PROJPRED_NTERMS exported (value unrecorded). Since 7 October 2026 neither document reports a path (G13-01), so the path-cap sentences this entry protected are gone, and neither prints `nterms_max`.

### G15-03. Stroop reliability: 'close to zero' will be false at .32, and supplement now prints the superseded .16 as the rescored value

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/paper_2_neuroplasticity.qmd:1553`, `paper_2_plasticity/supplement.qmd:151`, `paper_2_plasticity/manuscript_setup.R:206`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:1326`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:1456`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:1507`
- **What goes wrong:** Now: the supplement renders 'raises ... from \*[pending the practice-block variant run]* to .16', presenting the superseded with-practice value as the test-block result. After the rescored CSV lands: the main text renders 'Its split-half reliability is .32, which is close to zero. ... Almost none of its between-participant variance is systematic', and the Stroop is still called too unreliable to compare at qmd:1326, 1456, 1507 and 1605.
- **Evidence:** qmd:1553-1558: 'Its split-half reliability is `r predrel("stroop_interference")`, which is close to zero ... Almost none of its between-participant variance is systematic'. 01_extract_cognitive_indices.R:111-113 (uncommitted): 'at Session 1 the permutation split-half rises from .16 to .32 when practice is excluded'. The committed results/_predictor_reliability.csv:3 still holds the with-practice value, `"stroop_interference",1,62,0.0887553731727161,0.163040064572221,500,20260724`.
- **Fix:** (1) Author rewrite, no code: once the test-block _predictor_reliability.csv (8782464) is pulled back, rewrite qmd:1553-1558. Drop 'which is close to zero', 'Almost none of its between-participant variance is systematic' and 'uninformative however large the true effect'. Describe the index as poorly reliable instead: about a third of observed variance systematic, with associations attenuated to roughly .56 of their true size. Re-check that the Rouder (2023) framing still fits, and revisit the matching verdicts at qmd:1326, 1456-1457, 1507 and 1605 so they agree with the number. (2) Add this to AUTHOR_TASKS.txt item 2.7 beside the existing supplement warning, so the main-text prose is on the post-refit checklist. (3) Optional guard, forward-looking only: have 11 write a stroop_scoring column ('test_only' / 'with_practice'). Make predrel() return a visible marker when a Stroop row lacks 'test_only', and predrel_prev() require 'with_practice'.
- **Status:** resolved: the Stroop reliability is read from the test-block index (verified 4 October 2026).

### G15-04. Projpred and K-fold verdicts are hard-coded around inline values and never checked against them

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/paper_2_neuroplasticity.qmd:1163`, `paper_2_plasticity/manuscript_setup.R:324`, `paper_2_plasticity/manuscript_setup.R:459`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:1173`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:1196`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:920`
- **What goes wrong:** The queued Stroop refit plus a stage-08 rerun moves z_stroop to step 5 with a suggested size of 6, or a full-length search adds z_iaf to the raw path, or a kfold refit turns one elpd difference positive. The document would still render 'Inhibitory control (step 5) ... entered only beyond the suggested size', 'fell below that cap', or 'both differences favour the raw bands'. Each sentence reads as plausible, is wrong, and carries no marker.
- **Evidence:** qmd:1163-1169 (sprintf inside p2-selection): 'Digit span was the first individual-difference predictor selected, entering at step %s of the forward search, exactly the suggested size. Inhibitory control (step %s), statistical learning (step %s) and the resting-state band predictors entered only beyond the suggested size ... the lowest-ranked terms, including the individual alpha frequency ... fell below that cap'. qmd:1173-1174: 'The same path cap left the adjusted beta power and the specparam individual alpha frequency unreached'. qmd:1196: 'so the near-zero difference'.
- **Fix:** Leave the reviewed prose unchanged. In manuscript_setup.R add one guard, e.g. projpred_verdicts_hold(), that works out each assumed pattern from the artefacts already loaded: (1) Raw and aperiodic paths: rank(z_digit_span) == suggested_size and it is the first non-scaffold term; the terms before it are exactly the five scaffold terms (four in the gender path); ranks of z_stroop, z_asrt and every band or aperiodic main effect are > suggested_size or absent; z_digit_span &lt; z_stroop &lt; z_asrt in both paths ('reproduced this ordering'). (2) Raw path: no z_iaf row. Aperiodic path: no z_beta_adj or z_specparam_iaf row. (3) Gender path: z_gamma and z_iaf are the two highest-ranked main effects. (4) K-fold: all elpd_diff_aperiodic_minus_raw &lt; 0 whenever aper_kf_tie() is TRUE. (5) pd(joint) > pd(signaligned) for session_prepost:measurestroop_interference. At each site where a check fails, emit a visible marker in the project's existing convention (e.g.
- **Status:** resolved in the working tree on 8 October 2026: the K-fold direction is computed (51bdb75), and the selection verdicts of fix points 1 to 3 left the manuscript with the ranking on 7 October 2026 (G13-01). Fix point 5 is now checked too. The Discussion types "lowered" between the joint and the sign-aligned probability of direction of the Stroop contrast, which holds on the tables pulled on 7 October (93.2% against 81.1%), and `signaligned_guard()` in `manuscript_setup.R` prints a marker after it unless the alignment lowers that probability by more than a tenth, the rule `signaligned_sentence()` applies in the Results.

### G15-19. 'Change in task units' compares Session 1 and Session 5 means over different participant sets

- **Severity:** BLOCKING (reported as MINOR), HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/manuscript_setup.R:122`
- **What goes wrong:** If the nine participants missing at Session 5 differ systematically at baseline, as attrition often does, the unpaired difference (for example +2.4 items) misstates the size of the within-participant change the model reports. It is labelled as that change.
- **Evidence:** cog_mean() (manuscript_setup.R:122-127) reads the per-session mean from _cognitive_descriptives.csv, which covers every participant with a value: row 2 `1,digit_span,63,25.95...` and row 3 `5,digit_span,54,28.35...`, and Stroop 62 against 54. qmd:1328-1332 presents these as 'In task units, the digit-span change was from 25.95 items correct at Session 1 to 28.35 at Session 5'. The Part B model it glosses estimates a change within participants (qmd:445-447).
- **Fix:** Have 10_extract_descriptives.R also write paired summaries over participants with a value at both sessions, e.g. extra rows with `sample = "paired"` and their n, or a separate _cognitive_change_descriptives.csv. Read those in cog_mean() and inject the paired n into the qmd:1327-1332 sentence. As an interim step only, reword the sentence as unpaired session means with each session's n, and drop the word 'change'. Both options change reported numbers or wording in the Results, so author sign-off is needed.
- **Status:** resolved in 51bdb75.

### G16-01. Accessors and appendix tables let _keepmisfiltered/_diversity refits into reported counts, ranges and tables

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:943`, `paper_1_transfer/paper_1_morphosyntax.qmd:902`, `paper_1_transfer/paper_1_morphosyntax.qmd:917`, `paper_1_transfer/paper_1_morphosyntax.qmd:1258`, `paper_1_transfer/paper_1_morphosyntax.qmd:2356`, `paper_1_transfer/paper_1_morphosyntax.qmd:3512`
- **What goes wrong:** The queued mis-filter-retained ERP refit and the accuracy diversity refit land and script 05 is re-run. cred_cells("...:z_recoded_mini_language") then prints a count over 36 cells (for example "4 of 36") and pd_range spans two samples. tbl-retention gains rows for `accuracy_<p>_diversity` and `<cell>_keepmisfiltered_itemslope`: .retention_labels() cannot parse these ids, so they print with an NA Property. tbl-retention-free gains the `_keepmisfiltered_itemslope_retfree` rows. The forest plot draws the refits in an NA row. The Method and Results would read plausibly with none of this visible.
- **Evidence:** cred_cells() 942-945: `is_item <- grepl("_itemslope$", tbl$model); k <- tbl$parameter == term & grepl(paste0("^erp_", property), tbl$model) & !grepl("_weakprior", tbl$model) & !grepl("_retfree", tbl$model) & (if (structure == "itemslope") is_item else !is_item)`. There is no _keepmisfiltered or _diversity exclusion. pd_range 901-904, itemslope_width_ratio 917-918, cred_cells_guard 1257-1260, the fig-erp-forest filter 2353-2356, tbl-retention 3510-3512 (`model == vapply(sub("_itemslope$", "", model), .mid, "")`) and tbl-retention-free 3536-3538 have the same gap.
- **Fix:** Define one predicate in the setup chunk, e.g. `.is_variant <- function(m) grepl("_(weakprior|keepmisfiltered|diversity|commonsample)", m)`. Use it with a structure test that allows a trailing _retfree: `grepl("_itemslope(_retfree)?$", m)`. Route these through it: cred_cells, cred_cells_guard, pd_range, itemslope_width_ratio, the fig-erp-forest filter, tbl-retention and tbl-retention-free. The retfree table keeps _retfree but excludes the other tags. Make .mid() return an id untouched when it carries _keepmisfiltered or _diversity anywhere. Do not anchor that test on the end of the id. Three sites the finding missed: - conv_n("_retfree$") at 3670-3671 would count mis-filter-retained retfree refits into a sentence that describes 12 cells under 2 structures. Tighten its pattern to exclude the tags. - retfree_weak_note (776) tests any(grepl("_retfree", ...)). A pooled _keepmisfiltered_weakprior_itemslope_retfree pair would silently drop the qualification that the reported retfree fits have no weak-prior counterpart. Exclude the data-variant tags there too.
- **Also reported as:** G07-01
- **Status:** resolved in 2e89d05: every accessor and table sets the variant refits aside through `.is_variant()`.

### X5-01. Participant 14's Session-2 log ran the Mini-English experiment, but every pipeline codes it Mini-Norwegian

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/02_extract_accuracy.R:280`
- **What goes wrong:** In Session 2, participant 14 was trained and tested on Mini-English stimuli from the Spanish-site experiment, then switched to Mini-Norwegian from Session 3. Paper 1's gender-agreement accuracy model counts those 83 Session-2 judgements as Mini-Norwegian. So do the language x session terms, the ERP cells built from that EEG session (language comes from the key), the decoding meta, and Paper 2's Part A trajectory (02 sources Paper 1's extractor). The cross-language transfer estimates quietly absorb one participant-session from the other language, and no exclusion or disclosure records it.
- **Evidence:** The Session-2 logfile is internally consistent: its first row records
  `Spain_Session_2.osexp`, the Tromsø workstation path, `study_site = Spain`,
  `language = Mini-English`, and English-like stimuli. The raw EEG markers match all 144
  target trigger quartets, so this is not a renamed or corrupt logfile. The Spanish
  experiment file hard-codes `var.study_site = 'Spain'` and then loads the Spain parameter
  table; row 14 of that table specifies Mini-English (training list 1, test list 2), whereas
  row 14 of the Norway table specifies Mini-Norwegian (training list 2, test list 1). Both
  site-specific experiment files were stored in the same Session-2 materials folder. The
  participant's Session-3, Session-4 and Session-6 logs instead record the Norway experiment
  files and Mini-Norwegian. This makes accidental launch of the Spanish executable on the
  Norway workstation the supported proximate cause; why it was selected cannot be recovered
  because no contemporaneous lab note exists. Separately, 02_extract_accuracy.R:116-117
  omits the logfile's `language` and `experiment_file`, then :318-319 overwrites language by
  parity. The legacy ERP loader takes language from the key instead (git HEAD
  data/R_functions/merge_trialbytrial_EEG_data.R:16-17). That missing provenance guard did
  not cause the acquisition error, but it allowed the mismatch to pass silently.
- **Fix:** 1) In 02_extract_accuracy.R, add `language` and `experiment_file` to .les_acc_cols. Per participant x session, compare the log's language with the key's language, not only with parity. Write any disagreement to _accuracy_input_gaps.csv under reason `language_mismatch`, and a missing log language under a separate reason (the semicolon-delimited logs). Do not stop, and do not change mini_language yet. 2) Extend 00b_audit_participant_flow.R's language check to compare the logs as well as the key. 3) With the author, decide the treatment and encode it once, in a table in paper_1_transfer/scripts/_config.R modelled on LES_P1_MISFILTERED (e.g. LES_P1_LANGUAGE_DEVIATION = data.frame(participant_lab_ID = 14L, session = 2L)). Options are to exclude Session 2 only, or the whole participant from language-contrast terms, because Sessions 3-6 followed a Mini-English Session 2. Apply the table after loading, in 01 (ERP), 02 (accuracy), 08 (decoding) and, through the sourced extractor, Paper 2's 02. data/ stays read-only. Record it in the fit metadata, as the mis-filter exclusion is.
- **Status:** resolved in the working tree, 16 September 2026. The author decided to exclude
  participant 14 from every analysis involving the language group or the learning
  trajectory, in both papers, while keeping them in the enrolment and attendance counts.
  `LES_P1_PROTOCOL_DEVIATION` in Paper 1's `_config.R` holds the decision and its rationale;
  it is applied in 01, 02, 07, 07b and 08 (through `les_p1_apply_eeg_exclusions()` for the
  EEG), in 00's usable-data counts, and in Paper 2's 02, 04, 05, 10 and manuscript setup.
  Fix step 1 is also in: 02 keeps the logs' `language` and `experiment_file` and writes
  `_accuracy_language_check.csv`, which on the full data flags this participant-session
  alone, and warns on any mismatch without a recorded treatment. Both refit chains were
  resubmitted on the new sample.

### X6-01. No shared lab-log reader: 07 silently drops Session-4 participants 3 and 5, whom 02 records as an input gap

- **Severity:** BLOCKING, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `_shared/R/07_task_durations.R:224`, `paper_1_transfer/scripts/00d_extract_training_gate_flow.R:116`, `paper_1_transfer/scripts/00d_extract_training_gate_flow.R:165`, `paper_1_transfer/scripts/02_extract_accuracy.R:127`, `paper_1_transfer/scripts/02_extract_accuracy.R:205`, `paper_1_transfer/scripts/02_extract_accuracy.R:236`
- **What goes wrong:** Both manuscripts render Figure fig-lab-phase-duration and the Session-4 median training, test and experiment durations over 54 participants, labelled as the distribution across participants. Participants 3 and 5 attended and have complete logs, yet are absent with no warning or disclosure. Paper 1 discloses the same two logs as lost for accuracy, so the two artefacts silently disagree about which Session-4 data exist. Any future export with another delimiter or naming variant will be treated differently by each of the four readers.
- **Evidence:** Four scripts read the same OpenSesame folders, behavioural_lab_path("Session N"), and each uses its own listing rule, ID regex and delimiter handling. - Listing rules. 00d_extract_training_gate_flow.R:165 uses pattern = "^subject-.*\\.csv$". 02_extract_accuracy.R:236 uses "^subject-\\d+\\.csv$" and its census at :196 uses "^subject-.*\\.csv$". 01b_extract_rsvp_timing.R:149-150 and 07_task_durations.R:224 both use "\\.csv$". - ID regexes. 00d:116 uses str_extract(basename(path), "\\d+"). 02:127, :200 and :217 use "(?&lt;=subject-)[0-9]+". 07:231 uses sub("^subject-([0-9]+).*$", ...).
- **Fix:** Minimal fix, needs sign-off because it changes an end product. In _shared/R/07_task_durations.R, make .les_duration_read sniff the delimiter, as 01b_extract_rsvp_timing.R:126-135 already does: count ';' against ',' in the first header line and call readr::read_delim(delim = ...). The sniff must work on both input paths: readLines(path, n = 1) for a file on disk and raw[1] for the git-show text on the sparse-checkout path. Also have les_extract_lab_phase_durations() emit a message counting any file that produced no phase row, so a future silent skip is visible. Then re-run stage 13 and regenerate _task_durations_lab.csv in both papers' results/. This should add Session-4 rows for participants 3 and 5 and move the Session-4 test median, which is about 20.08 to 18.54 min on my estimate. Re-render both manuscripts. Do NOT change 02_extract_accuracy.R or 00d in the same change: sniffing there changes the modelled accuracy data and the reported gate counts, which POLISH_FLAGGED_2026-08.md:540-548 leaves as a separate author decision.
- **Status:** resolved in the shared reader (9c5c273). Making it take each log's delimiter by default would add two Session 4 participants' rows and change the reported duration medians, so it is the author's decision.


## MAJOR, HIGH-RISK (106)
### DET-02. Committed _accuracy_trajectory_descriptives.csv predates the Session-6 Experiment-block filter

- **Severity:** MAJOR (reported as MINOR), HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/results/_accuracy_trajectory_descriptives.csv:1`, `paper_1_transfer/scripts/02_extract_accuracy.R:251`, `paper_2_plasticity/manuscript_setup.R:85`
- **What goes wrong:** The main-text trajectory figure is drawn from the stale table. If the learning_trajectory.rds behind the reported Part A fits on HTC was also built before the filter, the fits carry 24 extra Session-6 rows and this becomes BLOCKING.
- **Evidence:** Determinism gate, 2026-09-13: regenerating the table from the current code gives 33,612 trials against the committed 33,636, one extra Session-6 trial for each of 24 participants; 54 of 663 rows differ, all in Session 6 (largest group-cell mean shift 0.0015, largest participant-level shift 0.0135).
- **Fix:** Check the n_obs recorded in _pooled_fit_metadata.csv, or nrow() of the fitted objects' data on HTC, against 33,612. Regenerate the table with hpc/10_descriptives.slurm (it runs 10 and 12), pull it back and re-render. If the fits are pre-filter, fold the correction into the queued Stroop refit chain, which rebuilds learning_trajectory.rds at stage 02.
- **Status:** resolved 2026-10-25. The switch to every judgement (5fe1e94) rebuilt the trajectory at stage 02 (HTC 9145163) and the table at stage 10 (HTC 9145167) with the current code, and both the Part A fits and the table were pulled on 25 October. The table's group cells and participant rows each total 41,181 trials, the count the current code reproduces from the raw logs, so it no longer predates the filter. The 33,612 of the evidence was on the screened trials.

### G01-01. Seed does not give exact reproducibility: les_brm uses adaptive reduce_sum (threading static = FALSE)

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `_shared/R/01_bayesian_settings.R:299`, `_shared/R/01_bayesian_settings.R:34`, `_shared/R/01_bayesian_settings.R:86`, `_shared/R/04_provenance.R:48`, `_shared/hpc/arc_env.sh:100`, `paper_2_plasticity/supplement.qmd:292`
- **What goes wrong:** Resubmit 03_fit_erp.slurm for one cell with the same data, seed, LES_THREADS_PER_CHAIN=2 and CmdStan 2.39.0. The adaptive partitioning can differ between runs, so the draws are not bit-identical and results/_pooled_posterior_summaries.csv differs at the level of Monte Carlo error. A rebuild-and-compare gate therefore cannot pass.
- **Evidence:** 01_bayesian_settings.R:299 `threads = if (.les_backend == "cmdstanr") brms::threading(threads) else NULL,`. No grainsize is set, so static takes its FALSE default. 01:86 `LES_SEED <- 20260607L # fixed for exact reproducibility`. 01:34-36 say threading was kept because 'dropping it changes the reduce_sum reduction order and so the exact draws, whereas the optimisation level does not'.
- **Fix:** Minimal fix, needing sign-off because it touches the manuscripts; no refit. Reword the determinism claims: - _shared/R/01_bayesian_settings.R:34-36 and :86 - _shared/R/04_provenance.R:47-49 - _shared/hpc/arc_env.sh:98-103 - HPC_RUNBOOK.md:246-248 - paper_2_plasticity/supplement.qmd:292-299 - paper_1_transfer/paper_1_morphosyntax.qmd:3317-3318 They should say that adaptive reduce_sum makes reruns reproducible up to Monte Carlo error, not bit-identical. Give the real reason for keeping threading: removing it changes the generated Stan code, so every cached fit would be refitted and the sampler configuration of the reported fits would change. Document a comparison tolerance for any rebuild-and-compare check, for example posterior summaries within a small multiple of their MCSE.
- **Status:** resolved (22 October 2026). The comments were reworded in 9c5c273. Both manuscripts now say that a rerun reproduces the summaries to within Monte Carlo error, not draw for draw: Paper 1's software paragraph and Paper 2's supplement S7. Paper 1 also reports the Monte Carlo standard errors of its signal-detection bounds, which 05 now writes (mcse_low, mcse_high), and its Strength of evidence reads a margin within two of them as unsettled. Static `reduce_sum` is not adopted: it would change the Stan code and refit every model, for draw-level reproducibility no reported result needs.

### G01-02. Legacy EEG loader reads &lt;code root>/data while data_path() reads LES_DATA_ROOT; no check they are the same tree

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/00_paths.R:72`, `_shared/R/00_paths.R:27`, `_shared/R/03_data_manifest.R:54`, `_shared/hpc/arc_env.sh:134`
- **What goes wrong:** LES_DATA_ROOT points at one data tree while &lt;code root>/data exists and differs. Examples: a full clone with a tracked data/ checkout and LES_DATA_ROOT set to the complete EEG store, or a cluster code root that already holds a data/ directory, so arc_env.sh leaves it alone. Paper 1's single-trial ERP extraction (01, 07, 07b, 08) then silently reads the participant key, LHQ3 and EEG exports from &lt;code root>/data.
- **Evidence:** 00_paths.R:27-31 says that after setwd 'both (a) the legacy root-relative paths and (b) our own here::here() calls resolve correctly from any starting location'. 00_paths.R:72 `.les_data_root <- Sys.getenv("LES_DATA_ROOT", unset = here::here("data"))`. 03_data_manifest.R:54 `legacy_eeg_loader <- function() data_path("R_functions", "merge_trialbytrial_EEG_data.R")`.
- **Fix:** Add the guard in _shared/R/03_data_manifest.R rather than 00_paths.R. legacy_eeg_loader() should stop() with both paths in the message unless identical(normalizePath("data", winslash = "/", mustWork = FALSE), normalizePath(data_path(), winslash = "/", mustWork = FALSE)). That covers callers 01, 07, 07b and 08's extraction. Then let 08's .les_decode_paths_agree() reuse the shared helper. In _shared/hpc/arc_env.sh:134, replace the silent link line: if `data` exists (-e or -L) and its resolved path is not the resolved LES_DATA_ROOT, print a FATAL message and exit 1; if ln -s fails, print a FATAL message and exit 1 instead of `|| true`. Deploy through deploy_to_cluster.sh only when no job is live.
- **Status:** resolved before this pass (verified 3 October 2026): `_eeg_import.R:397-402` (8f0fb8b) stops when `./data` ≠ `data_path()`, and 08:225-229 refuses the cache. `legacy_eeg_loader()` had no caller and is removed from 03. The 00_paths header now states the condition. arc_env.sh patch below is optional.

### G01-03. Read-only guard is documented as applied to every write path, but 30 live writes bypass it, including the shared modules' own

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/03_data_manifest.R:124`, `_shared/R/02_diagnostics.R:71`, `_shared/R/02_diagnostics.R:131`, `_shared/README.md:19`, `_shared/R/README.md:13`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:116`
- **What goes wrong:** A write routed through les_check_convergence(save_to=), les_posterior_summary(save_to=), les_save_ppc(), les_brm(file=) or any pooling CSV is never checked against data/. If a caller passes a path under data/, nothing stops it, contrary to the contract the READMEs describe.
- **Evidence:** 03_data_manifest.R:22-24: 'every pipeline write path is passed through it before the write'. _shared/README.md:19-21 and _shared/R/README.md:13 make the same claim. An awk scan of write calls with no les_assert_readonly_data on the same or the three preceding lines found 30.
- **Fix:** Two parts. (1) Now, documentation only: narrow the five claims (03_data_manifest.R:22-24, _shared/README.md:19-21, _shared/R/README.md:13 and both scripts READMEs) to say which stages call the guard, until part 2 lands. Also drop _shared/R/README.md:13's claim that the header names the call sites that still reach the tree, since the 03 header names none. (2) With sign-off, code: harden les_assert_readonly_data. For each path, walk up to the nearest existing ancestor, normalizePath that ancestor with mustWork = TRUE, and re-append the remainder. Resolve the data root the same way. Flag a path when `p == root || startsWith(p, paste0(root, "/"))`.
- **Status:** resolved in 9c5c273: The guard now resolves each path through its nearest existing ancestor and folds `..`; it was tested on 10 cases. The shared writers now call it: `les_brm()` cache, `les_check_convergence`/`les_posterior_summary(save_to=)`, `les_save_ppc`, `les_prior_predictive_check`, 04 and 07.

### G01-05. Provenance record omits backend, threads, sampler control, compiler flags and variant switches its docs imply

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/04_provenance.R:56`, `_shared/R/04_provenance.R:17`, `_shared/R/R/README.md:14`, `paper_1_transfer/results/_provenance.csv:1`, `paper_1_transfer/scripts/_config.R:248`, `paper_2_plasticity/scripts/_config.R:119`
- **What goes wrong:** A refit under LES_THREADS_PER_CHAIN=4, under a make/local with a different CXXFLAGS_OPTIM, or silently on rstan because cmdstanr failed to load writes a _provenance.csv indistinguishable from the reported run's. The manuscripts inject it as the fitting environment, so the record cannot show the draws came from a different configuration.
- **Evidence:** 04_provenance.R:17-22 names CmdStan, the GCC toolchain and CXXFLAGS_OPTIM = -O1 as things renv.lock cannot record, then says 'Versions and seeds are therefore recorded by the process that actually fits'. The writer (04:57-78) records only R, platform, LES_PROVENANCE_PKGS, the CmdStan version, the seeds and `extra`.
- **Fix:** All of this needs sign-off. In les_write_provenance, add rows computed inside the function, so they do not depend on callers passing `extra`: `backend` (.les_backend); `threads_per_chain` (.les_threads_per_chain); `modules` (Sys.getenv("LOADEDMODULES")); `CXXFLAGS_OPTIM`, read from file.path(cmdstanr::cmdstan_path(), "make", "local") and labelled as the value at write time; the LES_* variant switches actually set (names(Sys.getenv()) matching ^LES_P[12]_ plus LES_PRIOR_SET); and a code identifier. There is no .git on the cluster, so have deploy_to_cluster.sh, which already computes md5sums at :196, leave a manifest file whose hash is recorded. Drop the packageVersion/getNamespaceVersion change, which is not needed. Optionally add a column from isNamespaceLoaded(p).
- **Also reported as:** G03-13
- **Status:** resolved in 9c5c273: 04 now records these rows itself: backend, threads_per_chain, chains, iter_warmup/iter_sampling, adapt_delta/max_treedepth, CXXFLAGS_OPTIM (from make/local), modules (LOADEDMODULES), `env:LES_*` switches (path variables excluded), lockfile_check/lockfile_differs and code_md5/code_files (LF-normalised MD5 of `_shared/R` and both `scripts/`).

### G01-06. les_check_convergence is described as a hard gate, but `passed` is never enforced and failed fits flow into pooled results

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/02_diagnostics.R:66`, `_shared/R/README.md:12`, `paper_2_plasticity/scripts/05_fit_brms_prepost.R:188`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:120`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:920`
- **What goes wrong:** A refit that fails the R-hat or ESS thresholds, or has divergences, still writes its _summary.rds. Script 05/06 pools it into _pooled_posterior_summaries.csv, and the manuscripts render its estimates, gated only by prose counts. Paper 2's sentence then attributes the thresholds to the models as a group.
- **Evidence:** 02_diagnostics.R:19 'A model is accepted only if ALL of the following hold'. _shared/R/README.md:12 'a hard pass/fail gate'. 02:66-69 compute `out$passed` and return it; nothing stops or tags a failure. Callers only print it: 03_fit_brms_erp.R:298-300 `message(sprintf("[erp] %s | converged = %s ...", cell_id, conv$passed, ...))`, 04_fit_brms_accuracy.R:134-137 and 04_fit_brms_predictors.R:390-391.
- **Fix:** Split the fix. (1) Docs, safe on its own: reword 02_diagnostics.R:17-19 and _shared/R/README.md:12 to say the function records a pass/fail flag that the pipeline reports and counts but does not enforce, or else enforce it at the pooling step as in (3). (2) Manuscripts, end products that need sign-off: in paper_2_neuroplasticity.qmd:918-921, keep 'with rank-normalised R-hat below 1.01 ...' only when np == nrow(conv_tbl) and build the divergence wording separately. In paper_1_morphosyntax.qmd:2292, make 'no model produced a divergent transition' conditional on sum(conv_tbl$n_divergent) == 0. Generate or guard the static note at :3681 and the claim at :3431 from conv_tbl.
- **Status:** resolved in 9c5c273: Reworded the 02 header and README: the flag is recorded, not enforced. The manuscripts are already conditional (P1 qmd:3063-3093, P2 qmd:948-977).

### G02-02. les_zscore zero/undefined-SD branch turns NA entries into 0, contradicting 'a missing measure stays missing'

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/06_helpers.R:29`, `paper_1_transfer/scripts/01_extract_erp_single_trials.R:86`, `paper_1_transfer/scripts/02_extract_accuracy.R:100`
- **What goes wrong:** Suppose a standardisation frame holds only one non-NA value, or a constant value plus NAs. Examples: a covariate within a small modelled cell, or a resting-state measure recorded for one participant. The NA rows receive z = 0 (the mean) and are kept by brms instead of being dropped by listwise deletion. The model silently fits a larger n with imputed predictor values.
- **Evidence:** 06_helpers.R:21-23: 'Paper 1 keeps it NA (`all_na = "na"`, the default), so a missing measure stays missing'. But :28-29 `s <- stats::sd(x, na.rm = TRUE); if (is.na(s) || s == 0) return(rep(0, length(x)))` returns zeros for EVERY position, NA positions included, whatever all_na is set to. Examples: les_zscore(c(NA, 5, 5)) gives c(0, 0, 0); les_zscore(c(NA, 3)) (a single non-NA value, so sd is NA) gives c(0, 0).
- **Fix:** In the degenerate-SD branch of les_zscore (06_helpers.R:29) and both .les_scale copies (01_extract_erp_single_trials.R:86, 02_extract_accuracy.R:100), keep zeros at non-NA positions and NA at NA positions, whatever all_na is: `out <- rep(0, length(x)); out[is.na(x)] <- NA_real_; return(out)`. This matches the non-degenerate scale() path, which also keeps NA. Do not stop(), since constant contrast columns rely on the branch. Optionally warn when fewer than two non-NA values remain. Reword 06_helpers.R:19-24 to say that NA entries stay NA in every branch except an all-NA input with all_na = "zero", and that Paper 1 uses its own .les_scale copies. Add a unit test for c(NA, 5, 5) and c(NA, 3). On current inputs this should change no derived value;
- **Status:** resolved in 9c5c273: `les_zscore`'s degenerate branch keeps NA at NA positions. No current input reaches it with an NA, because every standardised P2 measure varies (`les_p2_assert_predictors_vary`).

### G02-03. les_zscore claims to be Paper 1's standardiser, but Paper 1 keeps two private copies; the 'na' default has no caller

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/06_helpers.R:21`, `_shared/R/README.md:16`, `paper_1_transfer/scripts/01_extract_erp_single_trials.R:83`, `paper_1_transfer/scripts/02_extract_accuracy.R:97`
- **What goes wrong:** Someone fixing the z-score logic in the documented 'one' standardiser (for example the NA-to-zero defect above) changes Paper 2 only. Paper 1's ERP and accuracy predictors keep the old behaviour, and the two papers diverge silently.
- **Evidence:** 06_helpers.R:21-23 'An all-NA vector is the one case the two papers treat differently. Paper 1 keeps it NA (`all_na = "na"`, the default)'. _shared/R/README.md:16 calls it '`les_zscore()`, the one z-score standardiser (Paper 1 keeps an all-NA column NA...)'. No Paper 1 file sources 06_helpers.R; grep finds callers only in paper_2_plasticity/scripts/02, 04, 05, 08 and 09c.
- **Fix:** Step 1, documentation only, can be applied now. Rewrite 06_helpers.R:19-24 and _shared/R/README.md:16 so they say that only Paper 2 calls les_zscore (always with all_na = "zero"), and that Paper 1's 01_extract_erp_single_trials.R:83 and 02_extract_accuracy.R:97 carry private .les_scale copies matching les_zscore(all_na = "na"). Drop the words 'the one z-score standardiser'. Step 2, code, needs sign-off because it is HIGH-RISK. Add source(here::here("_shared", "R", "06_helpers.R")) to the source blocks of Paper 1's 01 and 02, replace every .les_scale(x) with les_zscore(x, all_na = "na"), delete both .les_scale definitions, and update the comment at tests/test_summarise_cells.R:16. Then run that unit test, and check identical() on one extraction's z_* columns before and after.
- **Also reported as:** G06-14, X1-06
- **Status:** resolved in the docs (9c5c273). Paper 1's local scaling copies remain.

### G02-10. 07_task_durations.R: subject_nr fallback is unreachable because subject_nr is never read

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/07_task_durations.R:233`
- **What goes wrong:** A logfile whose name does not start with subject-&lt;n> is silently dropped from the lab-duration table instead of being identified from subject_nr, as the code intends.
- **Evidence:** :226-227 `lab_cols <- unique(c(unname(.les_duration_phase_start), unlist(.les_duration_phase_end, use.names = FALSE)))` holds only time_* columns. :229 `d <- .les_duration_read(files$path[i], files$rel[i], cols = lab_cols)` reads with `col_select = tidyselect::any_of(cols)` (:66), so `subject_nr` is never in `names(d)`.
- **Fix:** Delete the unreachable branch at :233-235. Replace the silent `next` at :236 with a warning() naming the skipped file (basename(files$rel[i])). If the author prefers to keep the fallback, add "subject_nr" to lab_cols at :226-227 and warn whenever it is used. Either way, output for the current inputs is unchanged: all 215 tracked lab files are named subject-N. Regenerating the CSVs is not needed.
- **Status:** resolved in 9c5c273: The ID now comes from `les_lab_log_files()`; an unparsable name warns. The unreachable `subject_nr` branch is removed.

### G02-11. Duration writer overwrites both papers' CSVs even when reads fail; git fallback swallows errors in a blob:none clone

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/07_task_durations.R:290`, `_shared/R/07_task_durations.R:37-40`, `_shared/R/07_task_durations.R:74-77`, `_shared/R/07_task_durations.R:168-169`
- **What goes wrong:** Script 13 is run locally (paper_2_plasticity/README.md:38 says 'local/HPC') on the sparse, blob-less clone, either offline or where git is not on R's PATH. Every read returns NULL, so the committed _task_durations_home/lab.csv in both papers are replaced by empty files. If only some blobs fail, individual exports are dropped silently and the reported medians rest on a subset of participants.
- **Evidence:** :37-40 `tryCatch(system2("git", git_args, stdout = TRUE, stderr = FALSE), error = function(e) character())`. :75-76 `raw <- .les_duration_git_lines(c("show", paste0("HEAD:", rel))); if (!length(raw)) return(NULL)`. :106/:109 bind_rows silently drops NULL reads. :168-169 `out <- if (length(rows)) dplyr::bind_rows(rows) else data.frame(); if (!nrow(out)) return(out)`.
- **Fix:** Make failures loud and gate the write, with no change to what a successful run computes: (1) In .les_duration_git_lines, drop the catch-all error handler, check attr(out, "status"), and stop() with the git arguments when git is missing or exits non-zero. (2) In .les_duration_read, stop() instead of returning NULL when a listed file exists neither on disk nor as a readable git object. (3) In .les_duration_list, stop() when a requested session yields an empty listing. (4) In both extractors, stop() when .les_duration_key() returns NULL or lacks participant_lab_ID; do not fall through to the unfiltered branch at :174-177 or :272-275.
- **Also reported as:** G14-12
- **Status:** resolved in 9c5c273: These now stop instead of returning empty: git failure or absence, a missing file or folder, an empty session or task listing, and a key that fails its checks. The writer checks all four targets before any write.

### G02-13. Median-duration prose hard-codes which phases each session recorded; session and phase lists repeated 3 times

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/07_task_durations.R:329`, `_shared/R/07_task_durations.R:122`, `_shared/R/07_task_durations.R:216`, `_shared/R/07_task_durations.R:345-350`, `_shared/R/07_task_durations.R:377-382`
- **What goes wrong:** If a re-extraction recovers Session 4 pretraining markers, or loses a Session 6 phase, the manuscript still states 'pretraining was not recorded' or prints 'NA min' in running text, with no warning.
- **Evidence:** :329-332 `lab_med(4, "training"), ... " min for training, test and experiment in Session 4, ", "where pretraining was not recorded; and ", lab_med(6, "experiment"), " min for the experiment in Session 6, where the other phases were not recorded."`. These claims about absent data are literals. The committed lab table does have 0 pretraining rows in S4 and only experiment rows in S6, but nothing checks it.
- **Fix:** (1) Hoist module-level constants in 07_task_durations.R: home sessions c(1L, 5L); home task levels and labels (stroop/digit_span/asrt -> Stroop/Digit span/ASRT); lab sessions c(2L, 3L, 4L, 6L); phase levels from names(.les_duration_phase_start) with labels. Use them as the extractor defaults (:122, :216) and in both plot helpers (:345-350, :377-382). (2) In les_task_duration_median_text, derive the set of (session, phase) cells with at least one finite duration and compare it with the cells the sentence names (S2 and S3 all four phases, S4 training/test/experiment, S6 experiment; all six home cells). If they differ, emit a warning() and return a \*[...]* pending marker, or a sentence built from the observed cells. That keeps today's rendered sentence byte-identical.
- **Status:** resolved in 9c5c273: Sessions, tasks and phases are now module constants. The median sentence warns and returns a `*[median durations pending…]*` marker when the observed cells differ from the ones it names. Today's sentence is identical (tested).

### G03-01. Deploy holds back a live job's entry script but ships the helpers it sources, so queued work runs mixed code

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/hpc/deploy_to_cluster.sh:126`, `_shared/hpc/deploy_to_cluster.sh:114-120`, `_shared/hpc/deploy_to_cluster.sh:165-178`
- **What goes wrong:** Say the p2 refit chain is PENDING on HTC, or 03_fit_erp.slurm (--array=0-17) still has tasks waiting, and `deploy_to_cluster.sh _shared` or `all` runs for the pending reconciliation deploy. The script holds back 04_fit_brms_predictors.R or 03_fit_brms_erp.R but copies a changed _shared/R/01_bayesian_settings.R or _config.R.
- **Evidence:** Uncommitted change. Before: `*) PREFIX='^p[12]_'`, and any live job of the paper made the script refuse and `exit 1`. Now files_of_job (126-137) marks as busy only the .slurm file plus the paths on its Rscript lines: `echo "$s"`, `sed -n 's/.*Rscript[^"]*"\([^"]*\.R\)".*/\1/p' "$s"`. Lines 169-173 hold back only those files: `echo "holding them back; everything else will still be deployed."`.
- **Fix:** Make the held-back set closed. In deploy_to_cluster.sh: (a) when any p1_/p2_ job is RUNNING, PENDING or SUSPENDED, add _shared/hpc/arc_env.sh and every _shared/R/*.R to BUSY, and for jobs whose job script matches, add that paper's scripts/_config.R. The simplest correct form reinstates the old rule for _shared: hold back all of _shared/R and arc_env.sh while any p[12]_ job is live. (b) Extend files_of_job to follow `source(here::here("a","b","c.R"))` calls transitively, joining the quoted segments with '/'. This must include cross-paper and script-to-script sources: P2 02 -> P1 02_extract_accuracy.R, P2 11 -> 01, P2 12 -> 07 -> 03, P2 10 -> 03, P2 08b -> 08, P1 09b -> 09_run_decoding.R.
- **Status:** resolved in 5b50d49: `deploy_to_cluster.sh` step 5 (`CLOSURE_AWK`). Each live job is resolved from its batch script (`squeue %o`), or from its `--job-name`/`-J` directive if that fails.

### G03-06. No job pins CmdStan: LES_CMDSTAN_VERSION is set nowhere, so the newest tree silently wins, restore route included

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/hpc/arc_env.sh:81`, `_shared/hpc/00_restore_environment.slurm:58`, `_shared/hpc/00_restore_environment.slurm:60`, `paper_1_transfer/hpc/submit_all.sh:56-60`, `paper_2_plasticity/hpc/submit_all.sh:57-60`
- **What goes wrong:** A reproducer, or the author after a toolchain refresh, has a newer tree beside 2.39.0, for instance from `submit_all.sh with_install`, which per HPC_RUNBOOK.md:83 calls install_cmdstan() with no version. They then run `submit_all.sh with_restore`, the documented reproduction route.
- **Evidence:** arc_env.sh:80-81: `else export CMDSTAN="$(ls -d "${LES_BASE}"/cmdstan/cmdstan-* 2>/dev/null | sort -V | tail -1)"`. A repository-wide grep finds LES_CMDSTAN_VERSION set only at 00_restore_environment.slurm:60, after arc_env.sh has been sourced and only inside that job.
- **Fix:** In both submit_all.sh scripts, inside the with_restore branch only and AFTER the restore job has been submitted, pass the pin to every chained job. Use an explicit variable such as `PIN=--export=ALL,LES_CMDSTAN_VERSION=2.39.0` added to each subsequent submit (P1 01-05; P2 01-06), or `export LES_CMDSTAN_VERSION=2.39.0`, relying on sbatch's default --export=ALL. Never export it before the restore job's submit, or arc_env.sh:74-78 stops that job on a fresh environment. Optionally, add a non-fatal warning to arc_env.sh when LES_CMDSTAN_VERSION is unset and more than one cmdstan-* tree exists. Correct README.md:40 so it does not imply that arc_env.sh pins the CmdStan version, and fix README.md:52-53, which wrongly says _provenance.csv cannot carry CmdStan.
- **Also reported as:** G02-21, G09-04
- **Status:** resolved in 5b50d49: `arc_env.sh`: `LES_CMDSTAN_RECORD=2.39.0` is defined once. Selection order: `LES_CMDSTAN_VERSION` (fatal if missing), then the record tree, then the highest tree with a WARNING. `submit_all.sh` needs no change. Tested on ARC: CMDSTAN is still `cmdstan-2.39.0`. Both papers' `_provenance.csv` record 2.39.0.

### G03-07. arc_env.sh continues after a failed module load, yet stops on a missing CmdStan tree

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/hpc/arc_env.sh:39`
- **What goes wrong:** The module is renamed or retired, or Lmod's cache is stale on a node. The job then runs whatever Rscript sits on PATH, or none. With no R it fails later on a less obvious 'Rscript: command not found'. With a system R of another minor version, R_LIBS_USER=.../Rlib/R-4.5 (line 57-58) is picked up and packages built for 4.5 fail to load, or if the minor version happens to match, the job runs on an unrecorded build of R.
- **Evidence:** 38-39: `module purge 2>/dev/null || true` / `module load R/4.5.1-gfbf-2025a`, with no status check. It is sourced before `set -o errexit` in every job (e.g. 00_restore_environment.slurm:42-43, rebuild_cmdstan.slurm:25-26). Lines 44-46 acknowledge the case without handling it: 'An empty list means the module load failed and the job is about to run against whatever Rscript is on PATH.' Line 136 only echoes `$(command - ...
- **Fix:** arc_env.sh:39 -> `module load R/4.5.1-gfbf-2025a || { echo "[arc_env] FATAL: module load R/4.5.1-gfbf-2025a failed" >&2; exit 1; }`. Optionally follow it with `command -v Rscript >/dev/null || { echo "[arc_env] FATAL: no Rscript after module load" >&2; exit 1; }` and a major.minor check, e.g. `[ "$(Rscript --vanilla -e 'cat(R.version$major, sub("[.].*", "", R.version$minor), sep = ".")')" = "4.5" ] || { echo "[arc_env] FATAL: R is not 4.5.x, but LES_RLIB is R-4.5" >&2; exit 1; }`. Do not move nounset ahead of the source line.
- **Also reported as:** G09-11
- **Status:** resolved in 5b50d49: `module load … \.

### G04-06. 00b's cross-check copies 00's criteria from the same files and no manuscript reads its outputs, contrary to its comments

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/00b_audit_participant_flow.R:195`, `paper_1_transfer/scripts/00b_audit_participant_flow.R:79`, `paper_1_transfer/scripts/00b_audit_participant_flow.R:217`, `paper_1_transfer/scripts/00_extract_participants.R:246`, `paper_1_transfer/scripts/00b_audit_participant_flow.R:107`
- **What goes wrong:** An error in the shared Paper 2 usability criterion is reproduced in both scripts and passes the 'genuine cross-check'. When the joint sample is empty, 00 reports all rs-EEG participants under the same label while 00b reports 0, so the two disagree about what the stage means rather than exposing a data error.
- **Evidence:** 00b:195-200: 'Recording the IDs here is what lets the manuscripts explain the stage-vs-fitted gap.' A repo-wide grep finds _participant_matrix.csv and _flow_inconsistencies.csv referenced only inside 00b; no qmd or manuscript_setup.R reads them, and no slurm runs 00b. 00b:217-220: 'The per-participant matrix and _sample_flow.csv are produced by different code from different sources'.
- **Fix:** (1) Comments only: reword 00b:79-83, 195-200 and 217-220 to say that check (8) re-derives the Paper 2 stage counts from the same derived objects, using a separately maintained copy of 00's criteria. It therefore detects drift between the two scripts, not errors in the criteria. Also say that the manuscripts' flow notes were transcribed from _flow_inconsistencies.csv, so they need re-checking whenever it changes. (2) Code (touches the HIGH-RISK 00): extract the stage criteria (S1 battery, trajectory IDs, joint intersection, eyes-closed complete-case rs-EEG, accuracy file set) into one function in _shared/R, called by both 00 and 00b. Settle one semantics for the rs-EEG stage (always intersect with joint_ids, or not) and one accuracy file set (the three default files).
- **Status:** resolved in aad57ed: One definition of the stages, `les_flow_stage_ids()` in 00, which 00b sources and uses. rs-EEG semantics settled: the stage always intersects joint and is NULL/NA when its inputs are absent. Accuracy file set settled: the 3 untagged files.

### G04-07. Participant flow silently writes 0 or drops stages when an input is renamed or not yet built, and the audit cannot see it

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/00_extract_participants.R:173`, `paper_1_transfer/scripts/00_extract_participants.R:202`, `paper_1_transfer/scripts/00_extract_participants.R:229`, `paper_1_transfer/scripts/00b_audit_participant_flow.R:57`, `paper_1_transfer/scripts/README.md:3`, `paper_1_transfer/paper_1_morphosyntax.qmd:1618`
- **What goes wrong:** On a fresh clone, running the numbered scripts in order runs 00 first. _sample_flow.csv is written without the accuracy and Paper 2 stages and with NA ERP/rs counts. The manuscripts print a truncated flow figure and 'NN' counts, with no error. A renamed SessionN column yields a plausible attrition step to 0 that 00b does not flag.
- **Evidence:** 00:173-175: `present <- if (col %in% names(key)) {...} else rep(FALSE, n_enrolled)`, so a missing date column becomes 'Attended Session k' = 0. 00b:57-58 sets NA for the same case (`if (is.na(col)) NA`), and the reconciliation (:225) uses `sum(m[[st]] %in% TRUE)`, which also gives 0, so no flow_total_mismatch fires. Usable stages are added only when inputs exist: :202 `if (length(acc_ids))`, :229-237.
- **Fix:** Do not make 00 stop() when an upstream derived artefact is absent. That breaks the documented NA-when-absent design (00:180-181, :243, codebook :158), and an extra status column would change a manuscript-read CSV's schema. Instead: (1) always emit every stage row, writing NA n_total when its input is missing, as the codebook already states, and message() the missing inputs by name. (2) stop() when any name in .les_session_date_cols is absent from the key (00:173-175). (3) In scripts/README.md and paper_1_transfer/README.md, state that step 0 runs after step 2 and after Paper 2's stages that write cognitive_indices.rds, learning_trajectory.rds and resting_state_eeg.rds, as the slurm already does.
- **Status:** resolved in aad57ed: 00 writes every stage row and writes NA with a message naming the missing input. It stops if a `Session*_date` column is missing, if the accuracy extraction is incomplete, or if a derived file lacks a needed column.

### G04-08. 00 reads LHQ3 columns by position, falls back to column 1 for IDs and never checks uniqueness, unlike 02

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/00_extract_participants.R:300`, `paper_1_transfer/scripts/00_extract_participants.R:78`, `paper_1_transfer/scripts/00_extract_participants.R:289`, `paper_1_transfer/scripts/00_extract_participants.R:319`, `paper_1_transfer/scripts/00_extract_participants.R:344`
- **What goes wrong:** A re-exported or re-ordered LHQ3 workbook, or a second record for a participant, silently produces wrong handedness, AoA, years or n_lhq3 in both manuscripts. This is the same failure class as the positional LHQ3 read that swapped the ERP covariate.
- **Evidence:** The raw workbook is read positionally: :78 `.les_english_slot_bases <- c(9, 15, 21, 27)`, :86 `hand <- trimws(as.character(row[[8]]))`, :94-98 offsets base+1..+5, and nothing asserts the header text. :289 `id_agg <- .first_or(names(agg)[grepl("^Participant ID$", names(agg))][1], names(agg)[1])` silently falls back to the first column.
- **Fix:** Make the proposed assertions robust and complete. The raw cells carry line breaks, and identical() on untrimmed values over slot 1 alone is fragile and incomplete. After :301: `stopifnot(grepl("Participant ID", raw_all[[1]][2]), grepl("Handedness", raw_all[[8]][2]))`, then `for (b in .les_english_slot_bases) stopifnot(grepl("^Language [1-4]$", trimws(raw_all[[b]][3])), identical(trimws(unname(unlist(raw_all[3, b + 1:5]))), c("Listening","Speaking","Reading","Writing","Years of use")))`. Drop three leading rows (`raw_all[-(1:3), ]`) and fix the comment at :298-299. At :289, replace the .first_or fallback with a stop() when '^Participant ID$' is not found, as 02:160-161 does. After the key filters at :291 and :304, `stopifnot(!anyDuplicated(agg[[id_agg]]), !anyDuplicated(eng$lhq3_id))`.
- **Status:** resolved in aad57ed: `.les_check_lhq3_raw_header()` asserts "Participant ID"/"Handedness" and the four "Language n / Listening…Years of use" slots (header text verified on ARC). Three header rows are dropped; previously the sub-header row leaked in and was filtered out by the key.

### G04-14. 00 and 00b count 'usable accuracy' from different file sets; 00 hard-codes the three file names

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/00_extract_participants.R:192`, `paper_1_transfer/scripts/00b_audit_participant_flow.R:65`
- **What goes wrong:** A renamed property silently gives an empty usable_accuracy stage in 00, because missing files return character(0) (:196). Once the diversity extraction has run in the same store, 00b counts the union of the reported and variant files while 00 counts only the reported ones, so the reconciliation compares different definitions.
- **Evidence:** 00:192-193 lists `c("accuracy_gender_agreement.rds", "accuracy_differential_object_marking.rds", "accuracy_verb_object_number_agreement.rds")` instead of using les_p1_accuracy_rds() over names(LES_P1_PROPERTIES) (_config.R:217-219). 00 does not source _config.R.
- **Fix:** 1. In both 00 (:191-193) and 00b (:65), build the list as `paper1_derived(paste0("accuracy_", names(LES_PROPERTY_CODES), ".rds"))`. This names the reported, untagged files explicitly and needs no _config.R. 2. In 00, warn with message() naming any absent file; stop only when some of the three are present and others are not, which signals an incomplete store. 3. In 00b, apply the same explicit list so the reconciliation compares like with like. No reported count changes with the current store contents. Because 00 writes _sample_flow.csv, regenerate and diff it before committing.
- **Status:** resolved in aad57ed: 00 uses `paper1_derived(paste0("accuracy_", names(LES_P1_PROPERTIES), ".rds"))`, stops when only some files exist and gives NA when none do. 00b uses the same list through the shared function.

### G04-18. _config.R's public helpers lack roxygen docstrings; the misfiltered_rows comment misstates its return value

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/_config.R:151`, `paper_1_transfer/scripts/_config.R:144`
- **What goes wrong:** Callers (qmd:320, 03, 05, 08) must read the bodies to learn, for example, that les_p1_misfiltered_rows returns NA when the columns are absent, or that les_p1_write_fit_meta reads four env vars and writes to disk.
- **Evidence:** None of the exported helpers has a #' block with parameters, return value and side effects: les_p1_misfiltered_rows (:151), les_p1_drop_misfiltered (:160, which emits a message), les_p1_keep_misfiltered and les_p1_misfiltered_tag (:199-200), les_p1_acc_diversity and les_p1_acc_diversity_tag (:211-212), les_p1_accuracy_rds (:217, which creates a directory via paper1_derived), les_p1_write_fit_meta (:244, which writes ...
- **Fix:** Add roxygen #' blocks above each public helper (purpose, @param with type, @return, side effects: environment variables read, directories created via paper1_derived, the .rds written by les_p1_write_fit_meta, messages emitted). Keep the blocks outside function bodies. Reword :144 to 'Number of rows of `d` (integer) that belong to a mis-filtered participant-session, or NA_integer_ when...'. Keep the edit out of any ARC sync until the decoding jobs that rely on the cached tensors have finished. Otherwise, because _config.R's size and mtime sit in the tensor fingerprint (08_extract_decoding_matrices.R:187, :226), the next decode job rebuilds the tensor. The cat() at :367 is a separate MINOR style point.
- **Status:** resolved in aad57ed: `#'` blocks on every public `_config.R` helper. `misfiltered_rows` now documented as "Number of rows … or NA_integer_". Comments only.

### G05-01. ERP time axis is hard-coded to -100 ms at sample 1; the exports' own Time 0 marker sits 30 ms later

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `data/R_functions/import_trialbytrial_EEG_data.R:78`, `paper_1_transfer/scripts/_config.R:72-78`, `paper_1_transfer/scripts/01_extract_erp_single_trials.R:205-222`, `paper_1_transfer/scripts/07_extract_grand_average_waveforms.R:43-44`, `paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R:49-50`, `paper_1_transfer/scripts/08_extract_decoding_matrices.R:88-92`
- **What goes wrong:** In 72.5% of segments (20,312 of 28,011), critical-word onset falls 2-6 ms before the importer's 0 ms. Every window in 01, 07, 07b and 08 is therefore shifted 2-6 ms late relative to onset on those trials, and the time&lt;0 'baseline' in 01:121 includes up to three samples at or after onset. Anyone who took Analyzer's own Time 0 marker as the onset, for example in a re-export or cross-check, would be 30 ms out.
- **Evidence:** Legacy loader (sourced by live code via legacy_eeg_loader()), git show HEAD: L77-78 `# Define hard-coded time points` / `time_points <- seq(-100, 1098, by = 2)`; L124 `time = as.numeric(rep(time_points, times = length(sentence_markers) * length(electrode_names)))`. The loader never reads a marker position. The exports' marker files disagree with that grid.
- **Fix:** No re-timing and no refit. (1) In the _config.R comment above LES_P1_EPOCH_MS (L72-78), record that sample 1 is -100 ms relative to the nominal critical-word onset. Define that as 30 ms before the S101/S102 grammaticality trigger, i.e. the export's Time 0 marker minus 15 samples; Analyzer segments span -130 to +1068 ms around that trigger. The word-ID trigger precedes it by 0-6 ms (47-50 samples after segment start across all 28,011 segments). Point CODEBOOK.md's `time` definitions at that note. (2) Optionally add a read-only check (e.g. an 00-series or _shared script) that parses the export .vmrk files, stops unless every S101/S102 segment has Time 0 at offset 65 and the word-ID trigger within 47-50, and writes a small tabulation.
- **Status:** partly resolved: verified on 61 Session-2 segments (the label offset against the raw markers is 0-6 ms), and the Method and N7 disclose it. The importer keeps its fixed time grid, which is intended. The documentation patches are not yet applied.

### G05-02. Within-participant z-scoring of the DV pins the between-participant covariate and language main effect near zero

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/01_extract_erp_single_trials.R:145`, `paper_1_transfer/scripts/03_fit_brms_erp.R:34-38`, `paper_1_transfer/scripts/03_fit_brms_erp.R:176`, `paper_1_transfer/paper_1_morphosyntax.qmd:1922`, `paper_1_transfer/paper_1_morphosyntax.qmd:1903-1904`
- **What goes wrong:** Every participant's mean response is zero by construction, so a participant-level predictor entering only as a main effect has almost no between-participant variance to explain. Its posterior is a tight null by construction, not evidence. It also adjusts none of the grammaticality terms the paper interprets, because it does not interact with them.
- **Evidence:** 01:145-150 `group_by(participant_lab_ID) %>% mutate(z_amplitude = .les_scale(amplitude), ...)`, so each participant's z_amplitude has mean exactly 0 over the cell's rows. 01:164 standardises the participant-level score globally. 03_fit_brms_erp.R:176 enters it only as a main effect, `" + z_multilingual_language_diversity"`, with no interaction with grammaticality.
- **Fix:** Author sign-off required (manuscript). Reword qmd:1921-1923 to say the L1-dominance score enters as a between-participant main effect. The response is z-scored within participant, so it and the language main effect are identified only through design imbalance and adjust none of the grammaticality terms. Correct qmd:3256-3260 accordingly: the covariate absorbs none of any experience-driven difference in grammaticality effects, because it enters no interaction. Record the same rationale in the 01 header next to the Faust et al. note and in 03:34-38. Whether to enter the covariate x grammaticality (x session) as a real control, or to drop it and so recover the listwise-deleted participant, is a refit decision for the author. It is not part of the minimal fix.
- **Status:** resolved in part: 01's header explains what within-participant scaling implies (aad57ed), and the Method says the L1-dominance covariate's between-participant effect is not identified (2e89d05). Whether to change the scaling is the author's decision.

### G05-04. 07's cluster grand averages are exactly derivable from 07b's per-electrode output, yet run as a separate heavy array

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/07_extract_grand_average_waveforms.R:50`, `paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R:56-62`, `paper_1_transfer/hpc/07_grand_average.slurm`, `paper_1_transfer/hpc/07b_grand_average_electrode.slurm`
- **What goes wrong:** The duplicated code paths can drift: a change such as adding les_p1_drop_misfiltered() to one script and not the other would make the waveform and topography figures silently describe different samples. Every refresh also spends a second six-task, 192 GB-per-task HPC array recomputing numbers 07b already holds.
- **Evidence:** 07:38-64 and 07b:44-72 are the same function apart from `electrode` in group_by and the `!is.na(brain_region)` filter. Both repeat the full importer load: hpc/07_grand_average.slurm and hpc/07b_grand_average_electrode.slurm are each `--array=0-5`, `--mem-per-cpu=48G`, `--cpus-per-task=4`. Every electrode in a cluster carries the same n_obs (e.g.
- **Fix:** Derive the cluster table from 07b's output: either locally or by having 07b write both CSVs from its single load. Keep 07's exact filenames (`_grand_average_<property>_<macroregion>.csv`, since the qmd globs `^_grand_average_` and needs 6 files) and its column set and order (grammatical_property, grammaticality, macroregion, brain_region, hemisphere, caudality, time, mean_amp, n_obs). Compute mean_amp as the n_obs-weighted mean and n_obs as the sum over electrodes. Before replacing the committed CSVs, verify the result against them (max |diff| &lt; 1e-12). Then retire 07_extract_grand_average_waveforms.R and hpc/07_grand_average.slurm.
- **Status:** no change needed (decided 17 October 2026): 07 now writes participant-level waves that 07b cannot reproduce, and the drift risk is closed by the single les_p1_apply_eeg_exclusions() entry point.

### G05-05. 07c hand-copies the importer's electrode-to-region map and hard-codes 30 electrodes instead of deriving them

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/07c_extract_electrode_coordinates.R:55`, `paper_1_transfer/scripts/07c_extract_electrode_coordinates.R:188`, `paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R:11-12`, `paper_1_transfer/paper_1_morphosyntax.qmd:2518`
- **What goes wrong:** If the importer's case_when map changes, or a copy is mistyped, _electrode_coordinates.csv assigns sensors to regions that disagree with the data. The topography figure's join on `electrode` (qmd:2534) would still succeed and draw a plausible map. The 30L check only catches a change in count, not a reassignment.
- **Evidence:** 07c:52-54: "reproduced here because data/ is read-only and the map is defined inline there rather than exported". 07c:55-65 re-types the nine clusters, and 07c:188 has `nrow(elec) == 30L`. The same map lives in import_trialbytrial_EEG_data.R:169-180 (git show HEAD).
- **Fix:** Minimal fix, with no change to outputs. (a) In 07c, keep the map but cross-check it before writing: when paper1_results('^_electrode_grand_average_.*\\.csv$') files exist, read their unique (electrode, brain_region) pairs and stop() unless they set-equal 07c's `elec[, c('electrode', 'brain_region')]`. Replace `nrow(elec) == 30L` with a check against that derived count, or against length(unlist(montage)) plus the cross-check. (b) In the qmd topography chunk, fail loudly instead of filtering: stop, or render the pending placeholder, if any electrode in `ed` has no coordinates, instead of silently dropping rows at qmd:2535. Leave the '30 electrodes' prose at qmd:1734/2518 unchanged unless the author signs off on wiring it to an inline count.
- **Status:** resolved in aad57ed: 07c: `.les_check_montage_against_importer()` parses the `electrode %in% c(...) ~ "region"` lines of `_eeg_import.R` and stops on any disagreement, a duplicate, or an unreadable map. Tested: it passes on the real importer and catches a reassigned sensor. `nrow == 30L` replaced by `length(unlist(montage))`.

### G05-18. 07 lacks a roxygen docstring on grand_average_one, which writes a results CSV

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/07_extract_grand_average_waveforms.R:38`
- **What goes wrong:** Parameter domains, the output file and the full-sample (mis-filtered-inclusive) behaviour are documented only in the module header, not at the public function.
- **Evidence:** No `#'` lines. `grand_average_one <- function(property, macroregion)` (L38) has no comment at all. It sources the legacy loader into the global environment (L39), writes `_grand_average_<property>_<macroregion>.csv` (L56-58) and returns the path invisibly (L63). `.run` (L66) is also undocumented.
- **Fix:** Add a function-level comment block (roxygen, if the codebase adopts it under the convention decision in G05-16) to grand_average_one AND to the identical 07b grand_average_electrode_one. Cover the @param domains (names(LES_P1_PROPERTIES), LES_P1_MACROREGIONS), @return (the output CSV path, invisibly), and the side effects: sourcing the legacy loader into the global environment, and writing the CSV to paper1_results(). Note that no les_p1_drop_misfiltered() call is made, so the sample is the full one. Give each .run a one-line entry-point note. The change is comment-only.
- **Status:** resolved in aad57ed: `#'` on all 07 functions; the stale "full sample" point is now "exclusions applied".

### G06-01. Accuracy models omit an item factor the same logs carry, and the stated rationale is contradicted by the data

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/04_fit_brms_accuracy.R:28`, `paper_1_transfer/paper_1_morphosyntax.qmd:2000`, `paper_1_transfer/paper_1_morphosyntax.qmd:3285`, `paper_1_transfer/scripts/02_extract_accuracy.R:107`, `paper_1_transfer/scripts/04_fit_brms_accuracy.R:72`
- **What goes wrong:** Grammaticality varies within items, and items recur across participants and sessions: about 23-55 trials and 16-28 participants per item. The accuracy GLMMs pool item variance into the fixed effects, so posterior intervals for the grammaticality, session and transfer terms are plausibly too narrow. That is the anticonservative case the paper itself uses to justify the ERP by-item slope.
- **Evidence:** 04:28-36: "There is deliberately NO by-item random effect. The judgement sentences are generated combinatorially ... Each sentence is presented only a few times across the sample, so item variance is thinly sampled and no by-item term is carried; its variance is absorbed into the residual ... This contrasts with the ERP task, which uses a fixed sentence-marker stimulus set".
- **Fix:** (1) Text. This needs sign-off because it touches the manuscript. Correct the rationale at 04_fit_brms_accuracy.R:28-36, 02_extract_accuracy.R:345-349, paper_1_transfer/README.md:214-216, qmd:1999-2003 and qmd:3285-3287. The judgement trials are the ERP trials and share their 144 language-specific sentence-trigger items, each crossed with grammaticality and participants. Remove 'absorbed into the residual' and 'slightly less precise': a Bernoulli model has no residual, and omission tends to narrow within-item intervals. Remove the claim that the inventory records recurrence across participants. (2) Sensitivity refit.
- **Status:** resolved. The item factor is the sentence frame (language x trigger, 288 per property). The `_byitem` and `_maxranef_byitem` refits are fitted and pooled (HTC 8976031-8976034; 4a545e7, aad57ed, 07b2ea5), and the manuscript reports them (2e89d05, 07b2ea5): 4 of 108 signal-detection comparisons change credibility, none for gender agreement.

### G06-03. The RT bounds' only rationale is a legacy script 02 calls non-functional, and the screen selects on the DV

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/02_extract_accuracy.R:287`, `paper_1_transfer/scripts/_config.R:81`, `paper_1_transfer/paper_1_morphosyntax.qmd:1870`
- **What goes wrong:** A fifth of judgement trials are removed on cutoffs with no stated source. Their removal correlates with the outcome in both directions: fast responses are more accurate and slow ones less accurate than those kept. The fast trials are clearly not random anticipations. Accuracy intercepts and session trends can shift with the screen, yet the Method describes it as removing implausible responses.
- **Evidence:** 02:287-290: "Reaction-time bounds ... carried over unchanged from the legacy import script so that both pipelines analyse the same trials. That script records no rationale for 200 and 4000 ms". _config.R:82-84 says the same. The same file, 02:19-22, calls that script "a non-functional fragment ... which is a parse/eval error". No second pipeline can analyse "the same trials".
- **Fix:** (a) Add a tagged sensitivity variant, following the _diversity pattern: an env switch such as LES_P1_ACC_NO_RT_SCREEN=1 sets a tag threaded through les_p1_accuracy_rds(), _accuracy_rt_screen&lt;tag>.csv and model_id in 04. The variant drops only non-finite RTs, plus at most gross logging artefacts (the maximum RT is 7,621,513 ms); a lower bound alone would still remove the 87%-accurate fast trials. Refit the three accuracy models under the tag and compare the grammaticality, session and three-way terms. Adopt only with sign-off. (b) With sign-off, write per-band accuracy (and by grammaticality) into _accuracy_rt_screen.csv, replace 'implausible' at qmd:1871, and disclose that the excluded trials differ in accuracy and in the grammaticality asymmetry.
- **Status:** resolved (re-decided 19 October 2026; refitted 21 October; Paper 1 pulled 22 October, Paper 2 pulled 25 October, after 09c and 08c's backup finished; supplement S9 compares Paper 2's Part A fits on the two trial sets, and no individual-difference term changes its relation to zero). HTC 9145163-9145184 (code 5fe1e94) ran every affected stage of both papers. All of Paper 1's 21 accuracy fits and Paper 2's 14 converge. On every judgement, Paper 1's reported fits keep the credible set of the unscreened refits of 18 October. The screen now decides six of the 54 signal-detection contrasts, four of them by less than 0.01. More consequentially, the refit with the by-participant slope for the change in bias leaves the gender-agreement criterion difference credible at no session (Session 6: -1.05 [-2.18, 0.11]), where on the screened trials it stayed credible. The author chose on 22 October to keep the reported model and grade the criterion difference as suggestive throughout Paper 1 (abstract, Results, Discussion, Strength of evidence, Conclusion, highlight 4, cover letter), guarded by maxranef_claims_guard(). Paper 2's Part A changes no cognitive-predictor term (3 of 240 terms flip, all session-time terms); its prose waits for the pull. The author asked for the most rigorous resolution. A raw-log check found that the screen also removes unequal shares of the two groups' trials (22.9% of the Mini-English group's against 16.5% of the Mini-Norwegian group's, mostly responses of 200 ms or less, which are prepared responses to a prompt that follows the sentence and the most accurate in the data at 87.5% correct). The roles were therefore swapped. Both papers analyse every judgement with a finite, positive response time, and LES_P1_ACC_RT_SCREEN=1 (tag _rtscreen) applies the screen as Paper 1's sensitivity analysis. The retired LES_P1_ACC_NO_RT_SCREEN stops every script that reads the accuracy tags. Part (b) is adopted: 02 writes _accuracy_rt_bands.csv, and the Method reports the screen's per-band accuracy and group shares in place of 'implausible'. Paper 2's Part A fits on the screened trials are frozen as _pooled_*_rtscreen.csv (supplement S9). Paper 1's Strength of evidence grades as suggestive the two contrasts only one fit supports (the Session 3 criterion difference and the Session 6 sensitivity difference). paper_1_transfer/hpc/submit_rt_screen_switch.sh reruns every affected stage of both papers. Until its results are pulled, the manuscripts print a pending marker. Before 19 October: resolved (decided 17 October 2026, fitted 18 October): the 200-4000 ms screen stays the primary rule, being the pipeline's own; the unscreened variant the entry proposes is to be fitted as a sensitivity analysis once the gender decoding run has ended, because the switch has to be threaded through Paper 1's _config.R, which the decoding tensor cache keys on. The gender run ended on 18 October. The variant is implemented as LES_P1_ACC_NO_RT_SCREEN=1 (tag _nortscreen; it drops only trials without a finite, positive response time) and submitted by paper_1_transfer/hpc/submit_rt_screen_sensitivity.sh, which runs 02, the three 04 fits and 05. HTC 9134777-9134779 ran it on 18 October. The three refits converged, and the pooled tables were pulled with every other row unchanged. Without the screen, 41,181 trials enter the models (8,159 more). Two of the 54 signal-detection contrasts change credibility, both for gender agreement and both within 0.10 of zero, and none of the 24 population-level terms does. The gender groups' criterion difference averaged over sessions stays credible (-0.55 [-1.06, -0.04], against -0.76). The Results report this through rt_screen_sentence(). Part (b) of the fix (per-band accuracy, rewording 'implausible') was not adopted.

### G06-05. file_refit='on_change' ignores sampler settings, and fit records stamp the current environment onto reused fits

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/03_fit_brms_erp.R:269`, `paper_1_transfer/scripts/04_fit_brms_accuracy.R:113`, `_shared/R/01_bayesian_settings.R:313`, `paper_1_transfer/scripts/_config.R:263`
- **What goes wrong:** Suppose a sampler setting changes (iterations, seed, adapt_delta) and 03 or 04 is resubmitted. brms returns the old cached fit without refitting. The per-fit record is rewritten with today's timestamp and toolchain versions, and _provenance.csv reports the new seed. The pooled metadata and the manuscript would then describe draws that were never produced under those settings, with nothing to reveal it.
- **Evidence:** 03:269-276 calls les_brm(..., file = paper1_results(cell_tag)). 01_bayesian_settings.R:313 sets `file_refit = "on_change"`. In the installed brms 2.23.0, brm() does `needs_refit <- brmsfit_needs_refit(x_from_file, scode = model, sdata = sdata, data = data, algorithm = algorithm, silent = silent); if (!needs_refit) return(x_from_file)`.
- **Fix:** Do NOT put a settings fingerprint in the cache file name. That would orphan every banked fit in both papers and force full refits. Instead, in les_brm (_shared/R/01_bayesian_settings.R, so Paper 2's fits are covered too), once brm() returns with a non-NULL file, read `sa <- fit$fit@stan_args[[1]]` and compare it with the constants: `length(fit$fit@stan_args)` against LES_CHAINS; sa$iter and sa$warmup against LES_ITER_WARMUP + LES_ITER_SAMPLING and LES_ITER_WARMUP; sa$seed against LES_SEED; sa$control$adapt_delta and max_treedepth against LES_CONTROL. stop() on any mismatch, naming the file. In les_p1_write_fit_meta and les_p2_write_fit_meta, take seed, iter, warmup and chains from the fit, versions from fit$version, and the sampling start time from sa$start_datetime.
- **Status:** resolved: the fit records carry the settings read from each fit (4a545e7), and `les_brm()` refuses a cached fit sampled under other settings (9c5c273).

### G06-06. try(silent = TRUE) hides failures of the provenance write and of the figures the manuscript includes

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/03_fit_brms_erp.R:325`, `paper_1_transfer/scripts/03_fit_brms_erp.R:244`, `paper_1_transfer/scripts/03_fit_brms_erp.R:282`, `paper_1_transfer/scripts/04_fit_brms_accuracy.R:106`, `paper_1_transfer/scripts/04_fit_brms_accuracy.R:125`
- **What goes wrong:** If les_write_provenance or les_prior_predictive_check errors (a CmdStan path problem, a package missing on the node, a full disk), the job exits cleanly with no warning in the .Rout. _provenance.csv and prior_predictive_check.png keep an earlier run's content. The manuscript then reports versions and seeds, or shows a figure, that do not belong to the fits it presents.
- **Evidence:** 03:325-330 wraps the provenance write in `try(les_write_provenance(paper1_results(), seeds = list(...)), silent = TRUE)`. 03:244-252 wraps the prior predictive check in `try(les_prior_predictive_check(...), silent = TRUE)`, and the copy to the manuscript's figure is then guarded by `if (file.exists(src))` (03:261), with no else branch or message.
- **Fix:** (1) Provenance, in both papers (P1 03:325-330, P2 04:412-413): remove the try() so a failed write fails the job. Fits are already cached, so the rerun is cheap. (2) Representative prior predictive check (03:244-266): unlink the cell's _priorpc.png before calling les_prior_predictive_check, so a stale panel can never be copied. Wrap the call in tryCatch(error = function(e) warning(...)). When LES_P1_PRIORPC_REPRESENTATIVE equals cell_tag and src is missing after the call, stop(). Add the else branch at 03:261. (3) Diagnostic PPCs (P1 03:282, 04:106-110, 04:125-126; P2 04:385-386): replace try(silent = TRUE) with tryCatch(error = function(e) warning("&lt;artefact>: ", conditionMessage(e))) and unlink the target before writing, so a failure leaves no misleading file.
- **Also reported as:** G11-11
- **Status:** resolved in 4a545e7 (Paper 1) and 2352752 (Paper 2).

### G07-02. Reported ERP retention contrasts read z-values from a data path that flips with LES_P1_KEEP_MISFILTERED

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:292`, `paper_1_transfer/hpc/05_summaries.slurm:25`, `paper_1_transfer/scripts/_config.R:298`
- **What goes wrong:** Suppose step 5 runs with LES_P1_KEEP_MISFILTERED=1 in its environment. sbatch exports the submitting shell's environment by default, and this is the switch used for the mis-filter-retained grid. Every reported ERP fit (variants '', _itemslope, _weakprior, _weakprior_itemslope, _retfree, _itemslope_retfree) is then paired with erp_&lt;cell>_keepmisfiltered.rds.
- **Evidence:** 05:292-294: `fdat <- c(reported = les_p1_cell_rds(grid$property[i], grid$window[i], grid$macroregion[i]), keepmisfiltered = paper1_derived(paste0(cell, "_keepmisfiltered.rds")))`. _config.R:298-300: les_p1_cell_rds() appends les_p1_misfiltered_tag(), which returns "_keepmisfiltered" whenever LES_P1_KEEP_MISFILTERED=1 (_config.R:199-200). z4, z6 and the language z are read off that data (05:192-193, 215, 249).
- **Fix:** 1. In 05_posterior_summaries_and_contrasts.R:292-293, spell the reported path explicitly: `reported = paper1_derived(paste0(cell, ".rds"))`. grid$cell_id is les_p1_cell_id(property, window, macroregion) (_config.R:314), so this is byte-identical to the current path when the switch is unset. 2. Amend the comment at 05:289-291 to say why les_p1_cell_rds() is not used: it follows LES_P1_KEEP_MISFILTERED, and this script enumerates both variants itself. 3. Optional belt-and-braces: mirror 00_descriptives.slurm:33-34 in hpc/05_summaries.slurm with `unset LES_P1_KEEP_MISFILTERED LES_P1_ACC_DIVERSITY`. - Unsetting LES_PRIOR_SET, LES_P1_ITEM_SLOPE or LES_P1_RETENTION_FREE is unnecessary, because 05 reads tags from file names and passes explicit ids.
- **Status:** resolved before this pass (verified 3 October 2026): 8f0fb8b replaced `les_p1_cell_rds()` with explicit `paper1_derived(paste0(cell,".rds"))` and `_exclreproc` paths (now 05:424-425). `LES_P1_KEEP_MISFILTERED` is retired (`_config.R`:421-424). 05 calls no env-reading tag helper. I added a comment saying why the path is spelt out.

### G07-05. Prior-sensitivity same-data guard checks n_obs only and passes silently on missing or duplicate records

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:440`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:433`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:451`
- **What goes wrong:** (a) An informative fit that predates the fit-time record, paired with a weak refit on a different sample, is written to _prior_sensitivity.csv; the manuscript reports its largest shift (qmd:2066-2072). (b) Two fits with equal n_obs but different participants or trials pass the check. (c) A malformed summary .rds silently removes a pair, shrinking the set over which the reported largest shift is taken.
- **Evidence:** 05:379-380 claims 'the guard below refuses to emit a comparison whose two sides were not fitted to the same data'. The code does less. 05:433 `if (!is.null(meta) && "structure" %in% names(meta))` means there is no check at all when the metadata is absent or old. 05:440 `if (length(n_inf) == 1 && length(n_weak) == 1 && !identical(n_inf, n_weak))` compares n_obs only.
- **Fix:** In collect_prior_sensitivity(): (1) If meta is NULL or lacks structure or retention_free (a stale pre-fix table), message and skip every pair; do not proceed unchecked. Alternatively have pool_artefacts() return meta invisibly and pass it in. (2) Require exactly one record per side (length(n_inf) == 1 && length(n_weak) == 1), otherwise message the counts and skip. (3) Compare both n_obs and n_participants. If a data digest is later added to les_p1_write_fit_meta(), compare it only when both records carry it. (4) Replace the silent try with tryCatch that messages the error before skipping. (5) Reword the 05:379-380 comment to state what is actually compared.
- **Status:** resolved in 4a545e7: `collect_prior_sensitivity(meta)` now takes meta from `pool_artefacts()` (no stale CSV). It skips every pair when meta is absent or old, requires exactly one record per side, compares `n_obs` and `n_participants`, and replaces the silent `try` with a messaging `tryCatch`.

### G07-07. Variant list hard-coded in collect_retention omits weak-prior retention-free and accuracy weak-prior fits

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:284`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:310`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:406`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:113`
- **What goes wrong:** A weak-prior retention-free refit produces convergence, summary and prior-sensitivity rows but no retention contrasts, and no message says so. Adding a new tag to 03 requires edits in at least five places in 05; each one missed is a silent omission.
- **Evidence:** 05:284-286: `base_variants <- c("", "_itemslope", "_weakprior", "_weakprior_itemslope", "_retfree", "_itemslope_retfree")`, with no `_weakprior_retfree` or `_weakprior_itemslope_retfree`. The comments claim completeness: 05:272 'for every random-effect structure and prior set that has been fitted', and 05:281-283 'Every variant must be enumerated here or its contrasts never reach _retention_contrasts.csv'.
- **Fix:** Minimal, confined to 05. (1) Extend base_variants at 05:284-286 with '_weakprior_retfree' and '_weakprior_itemslope_retfree'. The _keepmisfiltered twins follow from 05:286. (2) Loop the accuracy block over the model tag c('', '_diversity') crossed with the prior tag c('', '_weakprior'). Build mid from both tags, but build the derived path from the diversity tag only (accuracy_&lt;p>&lt;diversity>.rds, as _config.R:218 does), so a weak fit pairs with the data it was fitted to. (3) After both loops, list paper1_results() for '^(erp|accuracy)_.*\\.rds$', drop the artefact suffixes (_summary, _convergence, _fitmeta and any other per-fit artefact 03/04 write), and message() every fit id not in names(out). New tags then surface loudly and are not silently omitted.
- **Status:** resolved in 4a545e7: ERP variants gain `_weakprior_retfree` and `_weakprior_itemslope_retfree`. Accuracy loops now cover every 04 tag combination, built in `.les_acc_variants()` with the old tags first. `.les_unlisted_fits()` names any fit whose tags are not enumerated. Base retention-free prior pairs are added (none exist).

### G07-08. first_session_advantage hard-codes coefficient names and skips silently, the trap .les_draw_term exists for

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:351`
- **What goes wrong:** A formula in which z_recoded_mini_language or z_recoded_session first appears earlier than in the product (for example a covariate-by-language term placed first) renames the coefficient. The row is then dropped with a message saying no models were found, and the manuscript prints '\*[first-session contrast not found]*' (qmd:1042).
- **Evidence:** 05:351-353: `b_gl <- draws[["b_z_recoded_grammaticality:z_recoded_mini_language"]]`; `b_gsl <- draws[["b_z_recoded_grammaticality:z_recoded_session:z_recoded_mini_language"]]`; `if (is.null(b_gl) || is.null(b_gsl)) next`. The same file warns against exactly this at 05:172-174 ('Hard-coding either order is a silent trap: the lookup returns NULL and the contrast is quietly dropped rather than erroring.
- **Fix:** At 05:351-352, replace the literal lookups with `b_gl <- .les_draw_term(draws, "z_recoded_grammaticality", "z_recoded_mini_language")` and `b_gsl <- .les_draw_term(draws, "z_recoded_grammaticality", "z_recoded_session", "z_recoded_mini_language")`. On both skip paths (05:353 and 05:356), emit `message("[first-session] ", mid, ": ... -- skipped")`, as retention_contrast() does at 05:195 and 05:236. Change the 05:367 message so that it separates 'no fits found' from 'fits found but every one skipped'. Output is unchanged under the current formula. Re-run step 05 only when its other inputs next change.
- **Status:** resolved in 4a545e7: `.les_draw_term()` replaces the literal lookups. Each skip path gives its own message, and "none found" is separated from "all skipped".

### G07-09. Live Scopus counts record no retrieval date or package version, yet are described as reproducible

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/10_extract_literature_trend.R:83`, `paper_1_transfer/paper_1_morphosyntax.qmd:3334`, `paper_1_transfer/scripts/10_extract_literature_trend.R:17`
- **What goes wrong:** Re-running step 10 with the fixed 2005:2025 window returns different n values, because Scopus indexes back-content and corrects records. The committed CSV is overwritten and the inline totals change at the next render. Neither the old nor the new version can be dated or tied to a scopusflow release.
- **Evidence:** 10:17-19: 'records the exact query alongside each count so the search is inspectable and repeatable.' 10:83-85 writes only `data.frame(stratum = s, year = y, n = as.integer(scopusflow::scopus_count(q)), query = q, stringsAsFactors = FALSE)`, and 10:90 overwrites the file. The committed header is `"stratum","year","n","query"`, with no retrieval timestamp, scopusflow version or database identifier.
- **Fix:** (1) Script, for future runs: have 10 add retrieved_utc (from Sys.time(), formatted in UTC) and scopusflow_version columns, or better, call scopusflow::scopus_search_report() or write a sidecar provenance file. Refuse to overwrite an existing _literature_trend.csv unless an explicit switch (for example LES_P1_LIT_REFRESH=1) is set. Update CODEBOOK and codebook_descriptions.csv to match. (2) Existing file: do not hand-fill a timestamp or a version. Record in results/README.md and CODEBOOK.md that the counts were retrieved on or before 2026-07-24 (commit f2b1818) with a scopusflow build that predates v0.4.0 and whose version was not recorded. The alternative is a deliberate re-run with author sign-off, accepting that the Introduction totals (369/50/5 at commit time) will change.
- **Status:** resolved in b2f67f0: the script stops rather than replace the dated counts unless `LES_P1_LIT_REFRESH=1`, and records the retrieval time and scopusflow version.

### G07-10. scopusflow install hint is unpinned (default branch) while renv.lock pins v0.4.0

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/10_extract_literature_trend.R:61`, `paper_1_transfer/README.md:31`, `paper_1_transfer/scripts/README.md:49`
- **What goes wrong:** A fresh render-box setup that follows the hint installs the default-branch HEAD. A later scopusflow release that changes scopus_count() (query encoding, retries or count semantics) would then change the counts silently, and the output records no version to reveal it.
- **Evidence:** 10:60-61: `if (!requireNamespace("scopusflow", quietly = TRUE)) stop("scopusflow is required: pak::pak('pablobernabeu/scopusflow')")`. README.md:31 and scripts/README.md:48-49 give the same untagged `pak::pak('pablobernabeu/scopusflow')`. renv.lock:13616-13625 pins `"Version": "0.4.0"`, `"RemoteRef": "v0.4.0"` and `"RemoteSha": "623649a2f4812da1a4850bf2c58d4fac4fc771f3"`.
- **Fix:** Use `pak::pak('pablobernabeu/scopusflow@v0.4.0')` at 10:61, paper_1_transfer/README.md:31 and scripts/README.md:49. Correct scripts/README.md:47-49 so it no longer implies the lockfile lacks scopusflow, and state that the lockfile is not restored on the box where step 10 runs. In 10, record packageVersion('scopusflow') and, when present, packageDescription('scopusflow')$RemoteSha in the output (see G07-09). Warn, rather than stop, when the version differs from the locked 0.4.0. Do not claim that the pin reproduces the committed counts, which predate v0.4.0. The documentation-only subset (both README hints and the scripts/README.md wording) could be applied without sign-off. The guard and the stop-message edit in 10 should go through review.
- **Status:** resolved 2026-09-16: CRAN now carries `scopusflow` 0.4.0, and every active
  installation hint names that exact CRAN release. Retrieval-time package provenance
  remains tracked separately under G07-09.

### G08-02. Decoding checkpoint fingerprint omits ridge, cluster alpha and decoder code, so stale blocks resume silently

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/09_run_decoding.R:621`, `paper_1_transfer/scripts/09_run_decoding.R:431`, `paper_1_transfer/scripts/09_run_decoding.R:645`, `HPC_RUNBOOK.md:226`, `AUTHOR_TASKS.txt:520`
- **What goes wrong:** A run with LES_DECODE_RIDGE=1e-2 or LES_DECODE_CLUSTER_ALPHA=0.01, or with a corrected classifier or cluster function, finds `_tc_ckpt_<property>_*.rds` or `_tc_part_*` with a matching fingerprint. It restores blocks and partial nulls computed under the old settings and writes a CSV that mixes them with new blocks. .les_fdr_confirmatory then applies the new alpha to clusters formed at the old threshold.
- **Evidence:** 09:621-633 builds the fingerprint from counts, B, seed and an optional digest only: `paste0("n", nrow(d$meta), "_p", ..., "_t", length(d$times), "_B", LES_DECODE_NPERM, "_s", LES_DECODE_SEED, if (!is.null(d$x_digest)) ...)`. LES_DECODE_RIDGE (143) and LES_DECODE_CLUSTER_ALPHA (139) are read from the environment.
- **Fix:** Keep the fingerprint string unchanged. Add fields to each new block checkpoint and partial: ridge (both), alpha (block checkpoints only; partials do not depend on it), and a manually bumped LES_DECODE_CODE_VERSION integer, mirroring LES_DECODE_TENSOR_VERSION in 08. A hand-bumped integer is preferable to a deparse digest, which is fragile across R versions. On resume, a checkpoint that lacks these fields is legacy: accept it only if the current ridge == 1e-3 and alpha == 0.05, the values it was necessarily written under, and warn that code identity is unverifiable. A checkpoint that carries the fields must match exactly, or the script stops. Apply the same check in 09b before .les_fdr_confirmatory.
- **Also reported as:** X1-01
- **Status:** partly resolved in d9d9fab: the gap is documented in 09. Deferred to the next decoding run (decided 26 October 2026): the October run ended on 18 October and every reported decoding file is final, so the guard would protect only a future resume. A rerun from a fresh clone has no checkpoints to resume. Changing 09 now would leave the archived decoding code differing from the code that produced the reported results, with no run to verify the change.

### G08-05. Per-property BH corrects clusters again that the max-cluster null already FWER-controls; rationale cites cross-property

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/09_run_decoding.R:395`, `paper_1_transfer/scripts/09_run_decoding.R:351`, `paper_1_transfer/paper_1_morphosyntax.qmd:2174`
- **What goes wrong:** Within a property, BH over max-statistic-adjusted p-values is a second correction of the same family. It changes no false-positive guarantee and only removes clusters: gender's 38-ms cluster 7 (614-658 ms) is dropped. The manuscript describes the layer as controlling 'the false-discovery rate across clusters' (qmd:2174-2177). The code's rationale fits a cross-property family that was never implemented.
- **Evidence:** 09:330-332 says cluster_p 'is already family-wise-error-controlled ACROSS TIME within one cell, via the max-cluster permutation null'. Each cluster's p is taken against the same max-mass null (319: `pk <- (1 + sum(max_null >= obs_cl$mass[k])) / (length(max_null) + 1)`).
- **Fix:** Maintainer decision; no code change without sign-off. Option A: take the within-property max-cluster decision (`significant`) as the confirmatory decision, drop the BH layer and its admissibility guard (or keep cluster_p_fdr only as a descriptive column), and update the manuscript count (gender 6 -> 7), the figure shading at qmd:2727, the codebook rows for cluster_p_fdr/significant_fdr, and the appendix at qmd:3481-3490. Option B: if a second layer is wanted, apply BH across the three properties' overall clusters jointly, which is the family 09:351-355 describes. That needs a cross-property assembly step, since each property's CSV is written separately, and a check on the admissibility guard with m = 31 clusters.
- **Status:** resolved (decided 10 October 2026 at the author's request to "assess and proceed rigorously"; the author may override): the second layer is kept as specified, and the clusters that pass the maximum-cluster test are reported beside it in the Method, the Results, the figure (grey bars), the appendix and the Discussion. The decision was taken on these grounds. The two-layer rule was implemented and stated in the Method before the corrected sample was decoded. It is conservative, not invalid, since family-wise control implies false-discovery control and BH over family-wise-adjusted p values can only remove clusters. On the corrected sample it is decisive for gender agreement: four clusters pass the maximum-cluster test (378-418, 438-474, 534-602 and 950-1062 ms, p = .003-.030), and none survives both layers, the smallest adjusted value being q = .051. Switching rules after seeing that would have made the confirmatory decision depend on the outcome. Option B (a cross-property BH family) would have given two clusters, and Option A four, which shows how close to the threshold gender agreement sits under any rule. So the manuscript grades its separability as suggestive. The appendix on the correction family states what the second layer does, and computed wording (`dec_layers_sentence()`, `dec_gender_*()` with guards) keeps the prose tied to the counts. A maintainer who prefers Option A can adopt it with that disclosure. The code is unchanged, but the comment at `09_run_decoding.R` lines 462-467 still calls this an open question for the authors. It should be updated with the next change to 09, once no decoding job can read the file. An adversarial review on 11 October recomputed every printed decoding value from the CSVs and confirmed the timeline: BH has been in 09 since 3 July 2026, the overall-only family since 23 July (4ebee70) and the Method statement since 19 August (c8f20a5). The corrected-sample run was submitted on 2 October. Following that review, the appendix and the Transparency section now disclose that the layer was kept after the corrected results were seen, and that the family was narrowed in July after a run under the wider family had been inspected.

### G08-06. An unscorable time point (NA AUC) gets the minimum pointwise p, 1/(B+1)

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/09_run_decoding.R:290`
- **What goes wrong:** A thin exploratory cell, or a time point where every fold's ridged covariance fails, gets auc = NA with p_pointwise = 0.000999 in a deposited results CSV. A reader or later script would take that as the strongest possible evidence.
- **Evidence:** 09:289-291 `p_point <- vapply(seq_len(nT), function(t) { (1 + sum(null[, t] >= obs[t], na.rm = TRUE)) / (nrow(null) + 1) }, numeric(1))`. When obs[t] is NA, every comparison is NA and is removed, so p = 1/(B+1), the most significant value possible. NA permutation rows still count in the denominator.
- **Fix:** In .les_cluster_perm (09:289-291): `p_point <- vapply(seq_len(nT), function(t) { if (is.na(obs[t])) return(NA_real_); ok <- !is.na(null[, t]); (1 + sum(null[ok, t] >= obs[t])) / (sum(ok) + 1) }, numeric(1))`. Update the codebook description of p_pointwise to say it is NA where the bin was unscorable. Hold the edit back from any ARC deployment until the gender decoding job and the banked checkpoint are no longer in use (deploy_to_cluster.sh already holds back the decoding pair).
- **Status:** resolved (22 October 2026): 09 applies the proposed fix, and the codebook describes it. No deposited time-course has an unscorable bin (checked on all six), so no reported or deposited value changes and nothing is rerun. The decoding pair stays held back from ARC by default.

### G08-07. One process-wide RNG stream makes cross-language and TGM output depend on stage order; key tunables go unrecorded

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/09_run_decoding.R:148`, `paper_1_transfer/hpc/08_decoding.slurm:112`, `paper_1_transfer/paper_1_morphosyntax.qmd:3322`
- **What goes wrong:** Rerunning only the crosslang or temporalgen stage, for example after a crash, or rerunning at a different B, changes the reported cross-language peak AUCs (qmd:2808-2810) without any setting changing. A reader cannot recover the ridge, forming alpha or stride behind the deposited CSVs. The seed printed in the manuscript comes from a literal, not from a record of the run.
- **Evidence:** 09:148 `set.seed(LES_DECODE_SEED)` is the only seeding. The undersampler draws with sample() at every fold and time point (212), in timecourse, crosslang (508) and TGM (534). .run executes the stages in one process (842-844: `if (stage %in% c("timecourse", "all")) run_timecourse(property)` then crosslang, then temporalgen).
- **Fix:** After gender rerun 8736986 lands (09_run_decoding.R and 08_decoding.slurm stay held back until then, per AUTHOR_TASKS.txt:519-526 and SETTLED item 3): (1) Leave run_timecourse's documented, checkpointed single stream untouched. If it is ever reseeded, add a scheme token to .les_tc_fingerprint and accept a full B=1000 rerun. (2) Give run_crosslang, run_temporalgen and run_crossprop each its own seed at function entry, e.g. `withr::with_seed(LES_DECODE_SEED + <fixed stage offset>, ...)` (withr 3.0.2 is in renv.lock) or an explicit save and restore of .Random.seed. Their output then depends on neither stage order nor B.
- **Status:** resolved by decision (17 October 2026): the single seeded stream stays, because per-stage seeds would change the reported descriptive values and need every tensor reloaded; the dependence on stage order is documented in 09 (d9d9fab), and a whole-run rerun reproduces the values.

### G09-02. _decoding_provenance.csv was never produced for any reported decoding run, yet the manuscript prints its seed as recorded

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/08_decoding.slurm:107`, `paper_1_transfer/paper_1_morphosyntax.qmd:331`, `paper_1_transfer/paper_1_morphosyntax.qmd:3322`, `paper_1_transfer/scripts/test_exclusion_guard.R:138`
- **What goes wrong:** On today's render the Methods state that the decoding seed was "recorded by that script beside the decoding artefacts", but no such record exists. The number shown is a literal typed into the qmd, and it would stay the same even if a decoding run had exported a different LES_DECODE_SEED.
- **Evidence:** 08_decoding.slurm:107-114 writes `${LES_STORE}/paper_1_transfer/results/_decoding_provenance.csv`, and its comment says "the manuscript reads the decoding seed from this record". `git log -S"_decoding_provenance"` shows the step and its reader first arrived in 7d8bafd on 2026-09-07. The shipped decoding CSVs came from runs in July and August (hpc/README.md:4-6).
- **Fix:** (1) Manuscript, needs sign-off: at qmd:3321-3323, stop asserting a record that does not exist. Print the seed from the record when .dprov_tbl is present. Otherwise print as.character(LES_P1_DECODE_SEED_DEFAULT), which is already in scope because the qmd sources _config.R at line 211, and word it as the default the decoding scripts set, without 'recorded by that script'. Do not switch to the bare pending marker alone: no run will write the record until 08_decoding.slurm can be redeployed after the gender rerun, so the Data availability section would show a pending marker indefinitely. (2) 08_decoding.slurm, applied locally but deployed only after the decoding hold lifts: skip the write, or write it under a tag, when LES_DECODE_NPERM is below 1000.
- **Also reported as:** G16-04
- **Status:** resolved: 08_decoding.slurm refuses a reduced permutation count or another time step (d9d9fab), and the Method's seed sentence reads the decoding record (2e89d05).

### G09-03. LES_DECODE_STAGE is not validated, so any value other than exactly cross_property runs the 14-day per-property stage

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/08_decoding.slurm:68`
- **What goes wrong:** An operator submits the documented stage-2 line with `--array=0 --export=ALL,LES_DECODE_STAGE=crossprop` (or `cross-property`). The job silently runs the per_property stage for array element 0, gender agreement. It re-extracts the gender tensor and starts a full permutation run that writes the same checkpoints and gender_agreement_decoding_*.csv as the gender element already running (8736986_0 in AUTHOR_TASKS.txt:473 ...
- **Evidence:** 08:68 `STAGE="${LES_DECODE_STAGE:-per_property}"`; 08:83 `if [ "${STAGE}" = "cross_property" ]; then ... exit 0 fi`. Every other value falls through to 08:91-105, which extracts the tensor and runs `09_run_decoding.R "${PROP}" all`. The stage names are easy to confuse: the same file passes the R stage name `crossprop` (08:85 `09_run_decoding.R _ crossprop`), and HPC_RUNBOOK.md:201 quotes `stage == "crossprop"`.
- **Fix:** As proposed. Right after 08:68 add `case "${STAGE}" in per_property|cross_property) ;; *) echo "[decoding] unknown LES_DECODE_STAGE=${STAGE} (expected per_property or cross_property)" >&2; exit 1;; esac`. Apply locally only. 08_decoding.slurm is held back by deploy_to_cluster.sh while the banked gender rerun runs (HPC_RUNBOOK.md:225-228; SETTLED item 3), so deploy with the post-rerun reconciliation. The check does not enter the checkpoint fingerprint (09_run_decoding.R:621-626).
- **Status:** resolved in d9d9fab: slurm validates LES_DECODE_STAGE and also LES_DECODE_ANALYSES (an unknown value ran nothing and reported success; `crossprop` made every element race on the crossproperty CSVs); 09 `.run()` stops on an unknown stage. Sandbox: typos refused, default/robustness/cross_property invoke exactly the HEAD Rscript commands.

### G09-06. 01_extract_erp.slurm builds a variant log TAG but never uses it, contradicting its own comment

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/01_extract_erp.slurm:30`
- **What goes wrong:** A mis-filter-retained extraction (`sbatch --export=ALL,LES_P1_KEEP_MISFILTERED=1 01_extract_erp.slurm`, the first step of the September sensitivity refits) overwrites all six mainline 01_extract_erp_&lt;prop>_&lt;macro>.Rout logs. The row counts and the 'dropped N rows from K datasets' messages for the extraction behind the reported fits are then lost from the cluster.
- **Evidence:** 01:27-29 `# Variant extractions (LES_P1_KEEP_MISFILTERED=1) write their own logs so the / # mainline extraction logs are never overwritten by a resubmission.`; 01:30-31 `TAG=""` / `[ "${LES_P1_KEEP_MISFILTERED:-0}" = "1" ] && TAG="${TAG}_keepmisfiltered"`. The log line at 01:46-47, `> "paper_1_transfer/hpc/logs/01_extract_erp_${PROP}_${MACRO}.Rout" 2>&1`, has no ${TAG}.
- **Fix:** Change 01:47 to `> "paper_1_transfer/hpc/logs/01_extract_erp_${PROP}_${MACRO}${TAG}.Rout" 2>&1`, matching 02/03/04. Optionally add to the LES_P1_KEEP_MISFILTERED row of hpc/README.md:178 that a variant submission should pass `-o paper_1_transfer/hpc/logs/01_extract_erp_keepmisfiltered_%a.out` if the mainline .out should survive. Deploy only with the Paper 1 reconciliation after 8704930/8704934 finish (AUTHOR_TASKS.txt:505-513).
- **Status:** resolved: 01's .Rout log carries the variant tag, and its Slurm log is named per job (1533b4a).

### G09-07. The 18-cell grid is hand-copied into six SLURM arrays instead of being read from _config.R

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/03_fit_erp.slurm:49`, `paper_1_transfer/hpc/01_extract_erp.slurm:35`, `paper_1_transfer/hpc/04_fit_accuracy.slurm:28`, `paper_1_transfer/hpc/07_grand_average.slurm:27`, `paper_1_transfer/hpc/07b_grand_average_electrode.slurm:29`, `paper_1_transfer/hpc/08_decoding.slurm:81`
- **What goes wrong:** If a window is renamed or a property is added in _config.R, the arrays silently omit the new cell: no task is created and no error is raised. Anyone who maps a task ID onto les_p1_erp_grid() rows, as a resubmit-by-row helper would, picks the wrong cell, because the two orders differ.
- **Evidence:** 03:26 `#SBATCH --array=0-17` and 03:49-68 list 18 literal `"<property> <window> <macroregion>"` strings. The same information is duplicated at 01:19 and 01:35-42 (six pairs), 04:17 and 04:28-32, 07:19 and 07:27-34, 07b:21 and 07b:29-36, 08:59 and 08:81, and 08b:42.
- **Fix:** Minimal fix: add a check to paper_1_transfer/scripts/test_exclusion_guard.R, following the .seed_literal precedent at :142-155. It should parse the PARAMS blocks of hpc/03_fit_erp.slurm, 01_extract_erp.slurm, 07_grand_average.slurm, 07b_grand_average_electrode.slurm and 04_fit_accuracy.slurm, and the PROPS line of 08_decoding.slurm, read-only. It should assert that each block, as a set, equals the matching projection of les_p1_erp_grid() (all 18 cells; unique property x macroregion; names(LES_P1_PROPERTIES)), and that each `#SBATCH --array=0-N` has N = length - 1. It should also assert that the arrays follow names(LES_PROPERTY_CODES) order, not the grid's row order.
- **Also reported as:** G04-13
- **Status:** resolved in 1533b4a: test_exclusion_guard.R checks the six job arrays' grids against the configured grid.

### G10-02. Paper 2 stage 02 rewrites Paper 1's manuscript-read _accuracy_input_gaps.csv and _accuracy_rt_screen.csv

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/02_extract_learning_trajectory.R:56`
- **What goes wrong:** Paper 2's 02 job runs on the cluster from a Paper 1 extractor that has drifted from the copy that produced Paper 1's reported artefacts (settled item 8 says local and ARC copies differ). It silently overwrites $LES_STORE/paper_1_transfer/results/_accuracy_input_gaps.csv and _accuracy_rt_screen.csv.
- **Evidence:** 02:19-23: 'Sourcing it defines build_paper1_accuracy() WITHOUT side effects (its .run() is guarded ...), so we reuse the validated extraction verbatim'. 02:56: `acc <- build_paper1_accuracy() %>%`. Inside build_paper1_accuracy() (paper_1_transfer/scripts/02_extract_accuracy.R): line 244 calls `.les_write_input_gaps(files, sessions)`, which writes `utils::write.csv(gaps, gap_path, ...)` (222) to paper1_results("_accur ...
- **Fix:** The proposed fix is right in substance. Add `write_side_files = TRUE` to build_paper1_accuracy() and guard the two writes (P1 02:244 and :293-310) with it, with Paper 2's 02:56 calling `build_paper1_accuracy(write_side_files = FALSE)`. Paper 1's .run() and 00_descriptives.slurm keep the default, so no Paper 1 artefact changes. Until then, and in any case, correct 02:20-23 to say that CALLING the builder writes those two results files, and do the same in 02_extract_trajectory.slurm:4-6. Also add `unset LES_P1_ACC_DIVERSITY` to 02_extract_trajectory.slurm, as 00_descriptives.slurm:34 does. Deployment constraint: 02_extract_accuracy.R is a Paper 1 script, so the code change must wait for the pending Paper 1 reconciliation deployment (AUTHOR_TASKS.txt:505-527).
- **Status:** resolved: the trajectory extraction calls Paper 1's builder with `write_side_files = FALSE` (b2f67f0), after the docs were corrected in 2352752.

### G10-03. Paper 2 trajectory silently inherits Paper 1's Session-4 input gaps; Paper 2 never discloses the lost S4 data

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/02_extract_learning_trajectory.R:17`
- **What goes wrong:** The Part A joint trajectory model and the attainment/rate reliabilities for participants 3, 5, 6 and 20 are fitted without their Session-4 judgement trials. Readers of Paper 2 are told nothing, although the same data loss is disclosed in Paper 1.
- **Evidence:** 02:17-23 lists what the reused extractor provides ('the documented RT filter, de-duplication, canonical property/grammaticality mapping, language-by-parity coding and 0/1/2/3 growth-curve session coding'), without the input gaps. paper_1_transfer/scripts/02_extract_accuracy.R:48-57: 'TWO GAPS IN THE SESSION-4 INPUT (documented, not fixed here) ...
- **Fix:** Add the inherited Session-4 gaps to 02_extract_learning_trajectory.R's header (lines 15-23), citing P1 02:48-62. In Paper 2's Method, near the Part A description or the flow figure, add one sentence injected from paper1_results("_accuracy_input_gaps.csv") through a manuscript_setup.R accessor. It should count distinct participant_lab_ID over reason %in% c("split_export", "semicolon_delimited") only, excluding 'unread_extra_export' (participant 15) exactly as Paper 1 does. State that those participants contribute no Session-4 judgement trials because of an export-format issue, and cite the companion paper. No refit is needed and no reported statistic changes, but the manuscript text changes, so author sign-off is required.
- **Status:** resolved: documented in 02 (2352752), and the Method now says four participants contribute no Session 4 judgements (b2f67f0).

### G10-05. LES_P2_STROOP_KEEP_PRACTICE is honoured only by 01 and 11; 02, 05 and 10 read untagged indices without a guard

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/02_extract_learning_trajectory.R:76`
- **What goes wrong:** A user follows hpc/README's recipe (`--export=ALL,LES_P2_STROOP_KEEP_PRACTICE=1`) with the variable still exported in their shell, then runs submit_all.sh (sbatch exports the environment by default). 01 writes cognitive_indices_stroop_withpractice.rds. 02 and 05 silently read whatever untagged cognitive_indices.rds is in the store, possibly the pre-rescore file, and 04/05 write the reported, untagged model ids.
- **Evidence:** 01:275 writes `paper2_derived(paste0("cognitive_indices", les_p2_stroop_tag(), ".rds"))`, and 11:180 reads the tagged name. 02:76 `cog <- readRDS(paper2_derived("cognitive_indices.rds"))`, 05_fit_brms_prepost.R:108 and :148, and 10_extract_descriptives.R:420 all read the untagged name and never consult the switch.
- **Fix:** Move les_p2_stroop_keep_practice(), les_p2_stroop_tag() and a single practice-row predicate into paper_2_plasticity/scripts/_config.R, and have 01, 11 and 10's write_task_specs() call that one predicate. It selects identical rows on the current exports, so no number changes. Make 02 (before :76) and 05 (fit_cognition_prepost and fit_cognition_prepost_joint) fail closed with stop() when the switch is set, stating that the variant is scoped to 01 and 11. Do not add tagged trajectory or model ids unless the author wants with-practice Part A/B fits, which would need a model-id tag in les_p2_model_id and a refit. Correct or remove the misleading comment at 10_descriptives.slurm:32-33, since 10 ignores the variable.
- **Also reported as:** G14-16
- **Status:** resolved in 2352752: switch, tag and practice predicate moved to `_config.R:66-102`; 02:91 and 05:133/187 stop under `LES_P2_STROOP_KEEP_PRACTICE=1` (`les_p2_refuse_stroop_variant`); 10 now calls `.les_drop_practice` (extraction_b). README row: P4.

### G10-07. 03 fails open: no recordings, unreadable files, missing ROI channels or bad IDs never stop the job

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/03_extract_resting_state_eeg.R:189`
- **What goes wrong:** On the cluster, LES_DATA_ROOT points at a tree without the Session-2 exports, or a re-export changes names. 03 logs a message and exits 0, leaving a stale resting_state_eeg.rds or none. With none, 04 refits Part A without the rs-EEG predictors under p2_predictive_trajectory. Alternatively, a handful of unreadable recordings shrink the rs-EEG sample, visible only in the .Rout.
- **Evidence:** 03:189-192: `if (!length(vhdrs)) { message("[rs-eeg] no resting-state .vhdr under ", root); return(invisible(NULL)) }` exits 0 and writes nothing. 03:202-205 swallows any per-recording error: `tryCatch(.summarise_recording(vhdr), error = function(e) { message(" skip ", ...); NULL })`.
- **Fix:** In 03_extract_resting_state_eeg.R: (a) Stop when length(vhdrs) == 0 while LES_STRICT_INPUTS=1. Keep the message otherwise, which preserves the documented 'optional 03' behaviour. (b) Under LES_STRICT_INPUTS=1, stop when any recording was skipped; collect the skipped names and report them. (c) Before saveRDS, always run stopifnot(!anyNA(out_tbl$participant_lab_ID), !anyDuplicated(out_tbl[c("participant_lab_ID", "session", "condition")])). (d) Return the number of ROI channels actually averaged (length(psds), counted after welch_psd has dropped any) and write it as a column. warning() when it is below length(LES_RS_POSTERIOR), and stop under strict mode. Apply the same (a)-(c) guards to 07_extract_aperiodic.R:386-406.
- **Status:** resolved in 2352752: 03:220-235 ROI-channel warning (stop under strict); 03:249-264 `.les_rs_assert_one_per_recording` (NA id, duplicate recording) used by 03 and 07:567; 03:276-318 and 07:497-562 strict-mode stops and a warning naming skipped recordings.

### G10-08. 01 input-shape assumptions checked by message only: practice columns, batch duplication, blank-Correct encoding

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:124`
- **What goes wrong:** A Gorilla re-export that renames the practice column, or blanks `Correct` for unscored or timed-out trials, or a participant present in two batch exports with different timestamps, would silently (a) re-admit practice trials, (b) double a participant's digit-span sum, or (c) count unscored trials as incorrect. Each still produces plausible indices and passes the downstream checks.
- **Evidence:** (a) 01:124-129 `.les_drop_practice`: if neither `Practice` nor `display` exists, `keep` stays all TRUE and only `message("[cog] Stroop: dropping ", 0, ...)` is emitted. Both columns exist in the current S1/S5 exports (display 'Practice Trials' = Practice 1: 1005 S1 rows, 810 S5 rows). (b) 01:83-100 de-duplicates only named against batch exports;
- **Fix:** (a) In .les_drop_practice, which runs only on the default test-block branch, stop() when neither `Practice` nor `display` is present. Apply the same stop to the fallback in 10_extract_descriptives.R:389-395. 11 inherits it by calling .les_drop_practice. (b) After de-duplication, stop() when any participant has more than LES_P2_DS_TRIALS (48) digit-span text-entry trials, or more than LES_P2_STROOP_TEST_TRIALS (100) Stroop rows. Run the Stroop check after .les_drop_practice, and skip it or use 115 when les_p2_stroop_keep_practice() is TRUE. Define both constants in _config.R and reuse them in the notes at 10:381 and 10:398. (c) Add a comment that a blank Correct is scored as incorrect, as in the legacy script, and assert that no blank-Correct row has a Response equal to its answer.
- **Status:** resolved in 2352752: (a) 01:152-160 stops with neither `Practice` nor `display`; (b) 01:169-181 stops above `LES_P2_DS_TRIALS` = 48 / `LES_P2_STROOP_TEST_TRIALS` = 100 (`_config.R:62-63`); (c) 01:183-212 documents blank `Correct` and warns when a blank row matches `Answer`. Maxima not checked on the real exports.

### G10-09. 02 joins baseline cognition to trials with no cardinality check

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/02_extract_learning_trajectory.R:84`
- **What goes wrong:** A participant who completed the Session-1 battery under two Gorilla public IDs, both mapped in the key to the same lab ID, yields two S1 rows. Every one of that participant's judgement trials is then duplicated in learning_trajectory.rds, doubling their weight in the Part A likelihood and the reliability summaries, with no error.
- **Evidence:** 02:77-82 `base_cog <- cog %>% filter(session == 1, !is.na(participant_lab_ID)) %>% transmute(participant_lab_ID = as.integer(participant_lab_ID), z_digit_span = ..., ...)` then 02:84-85 `traj <- acc %>% left_join(base_cog, by = "participant_lab_ID")`. There is no anyDuplicated() or row-count check, and nothing in 01 guarantees one Session-1 row per lab ID (01:257-259 joins the key by home ID only).
- **Fix:** In 02, add `stopifnot(!anyDuplicated(base_cog$participant_lab_ID))` after building base_cog, and `stopifnot(nrow(traj) == nrow(acc))` after the join. Add the same duplicate check on cog_s1 and rs_ec in 10_extract_descriptives.R:105-113. Better still, also assert unique (participant_lab_ID, session) in 01 before saveRDS (see G10-08(d)), which protects every consumer at once. No number changes on current data.
- **Status:** resolved in 2352752: 02:123-136 duplicate-baseline stop and `nrow(traj) == nrow(acc)`; 01:393-400 stops on two rows per lab ID x session. `_prepost_ns.csv` has n_obs = n_participants for every per-index fit, so current data pass. 10's check: patch P10.

### G10-10. Band and session literals duplicate config: 03 hard-codes band columns, 02 hard-codes Session 1

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/03_extract_resting_state_eeg.R:206`, `paper_2_plasticity/scripts/02_extract_learning_trajectory.R:78`
- **What goes wrong:** Say a band is renamed or added in LES_P2_EEG_BANDS (e.g. splitting gamma). `s$gamma` becomes NULL, and `tibble(gamma = NULL)` silently omits the column, so resting_state_eeg.rds lacks a measure the config promises; 04's `all_of(LES_P2_RS_MEASURES)` then errors, or a new band is never written. Likewise, if the baseline session in the manifest changed, 02 would keep z-scoring Session 1.
- **Evidence:** 03:206-209 `tibble::tibble(participant_lab_ID = pid, session = sess, condition = cond, delta = s$delta, theta = s$theta, alpha = s$alpha, beta = s$beta, gamma = s$gamma, iaf = s$iaf)` restates names(LES_P2_EEG_BANDS) plus "iaf", i.e. LES_P2_RS_MEASURES (_config.R:98), which _config.R:96-97 describes as 'The resting-state measures script 03 writes'.
- **Fix:** In 03:206-209: stopifnot(all(LES_P2_RS_MEASURES %in% names(s))) tibble::tibble(participant_lab_ID = pid, session = sess, condition = cond, !!!s[LES_P2_RS_MEASURES]) In 02:78 and 10_extract_descriptives.R:106, use `session == LES_P2_COG_SESSIONS[1]`. In paper_1_transfer/scripts/00_extract_participants.R:257 and 00b_audit_participant_flow.R:105, take the measure list from LES_P2_RS_MEASURES, or at least stop when any expected measure is missing instead of silently intersect()ing it away. In _shared/hpc/validate_rseeg.R:34 and :43, build the column list from the config. Leave 04:110 as it is (deliberate and guarded). Every change is byte-identical on current data.
- **Status:** resolved in 2352752: 03:303-306 builds the row from `LES_P2_RS_MEASURES` (`!!!`), tested byte-identical; 02:115 uses `LES_P2_COG_SESSIONS[1]`. 10, P1 00/00b and validate_rseeg are not mine.

### G10-21. 03 functions lack roxygen docstrings

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/03_extract_resting_state_eeg.R:47`, `paper_2_plasticity/scripts/03_extract_resting_state_eeg.R:70`, `paper_2_plasticity/scripts/03_extract_resting_state_eeg.R:112`, `paper_2_plasticity/scripts/03_extract_resting_state_eeg.R:127`, `paper_2_plasticity/scripts/03_extract_resting_state_eeg.R:163`, `paper_2_plasticity/scripts/03_extract_resting_state_eeg.R:169`
- **What goes wrong:** 07 and 10 reuse welch_psd/les_band_power/les_iaf. A change of window length or band-edge rule here silently changes the aperiodic features and the descriptive PSD, with no documented contract to review against.
- **Evidence:** .parse_vhdr (47), .read_bv_ascii (70), welch_psd (112), les_band_power (127), les_iaf (163), .summarise_recording (169), extract_resting_state_eeg (185) and .run (224) have no #' blocks. welch_psd does not document its units (input microvolts, output µV²/Hz, one-sided), `seconds`, or its NULL return when length(x) &lt; fs. les_band_power does not document that it returns µV² over [lo, hi-df].
- **Fix:** Add #' roxygen blocks to the public functions without changing any code. (a) welch_psd: @param x numeric vector in µV (non-finite samples are dropped before segmentation, which splices across gaps); @param fs sampling rate in Hz; @param seconds segment length in s (Hann window, 50% overlap, per-segment mean removal); @return list(freqs, power), a one-sided PSD in µV²/Hz on a fs/round(seconds*fs) grid (0.5 Hz for these 500 Hz recordings), or NULL when fewer than fs finite samples remain. (b) les_band_power: @param freqs and power as returned by welch_psd; @param bands named list of c(lo, hi) in Hz; @return named numeric of absolute band power in µV², the trapezoidal integral over bins with lo &lt;= f &lt; hi, which spans [lo, hi - df] and so leaves out the top half-bin;
- **Status:** resolved in 2352752: plain `#` blocks (house style, `_shared/R/README.md:46-48`, b111348) on every 03 function: units (uV, uV^2/Hz, uV^2), Welch scaling, NULL return, `[lo, hi - df]`.

### G11-04. The all-NA predictor guard can never fire, so a constant zero column would enter Part A and report its prior as a null

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/04_fit_brms_predictors.R:253`
- **What goes wrong:** If a re-run of 03 wrote gamma = NA for every recording, for instance after a change to the band limits or filter, z_gamma would be 0 for every participant. The guard keeps it, and brms fits a zero column whose coefficients are identified only by their priors, normal(0, 0.25) and normal(0, 0.15).
- **Evidence:** 04:242 comment: "Which standardised predictors are actually present (and not all-NA) in the data." 04:253: `present[vapply(present, function(p) any(!is.na(dat[[p]])), logical(1))]`. Every candidate column is built with les_zscore(all_na = "zero"): 04:200 for the rs-EEG measures, 04:227-232 for the aperiodic measures, and 02_extract_learning_trajectory.R:80-82 for the cognitive indices.
- **Fix:** 1. Guard. Replace the guard in les_p2_partA_predictors with a check on participant-level values: reduce dat to one row per participant, then require at least two distinct non-NA values for each candidate. This catches both a zero column created by les_zscore (all-NA or constant input) and a column left all-NA by the join, so all_na = 'zero' can stay and 02 and 05 are left untouched. 2. Stop, don't drop. For the reported models, a failing candidate should stop with a message naming it. One assertion, stopifnot(setequal(preds, cand)), covers this and the G11-03 fix together. 3. Comment. Correct the comment at 04:242. 4. Related. 05_fit_brms_prepost.R:64 and :168 have the same zeros behaviour; handle that separately.
- **Status:** resolved in 2352752: 04:330-338 `les_p2_assert_predictors_vary()` after listwise deletion (fewer than two distinct values stops); candidates required, not dropped. Current data pass (z_theta_adj varies through participant 23)

### G11-05. A cache-hit re-run re-dates _provenance.csv and every fitmeta, recording an environment that did not fit the models

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/04_fit_brms_predictors.R:411`, `paper_2_plasticity/scripts/04_fit_brms_predictors.R:388`, `paper_2_plasticity/scripts/05_fit_brms_prepost.R:102`, `paper_2_plasticity/scripts/05_fit_brms_prepost.R:192`, `paper_2_plasticity/scripts/_config.R:129`
- **What goes wrong:** The Part A models were refitted on 2026-09-11. A later `sbatch 04_fit_predictors.slurm`, run with no data change to regenerate a lost summary or PPC, performs no sampling, yet it rewrites _provenance.csv with that day's date and the library installed that day. The manuscript then states the reported models were fitted on that date, and _pooled_fit_metadata.csv carries the same fitted_utc and versions.
- **Evidence:** 04:407 comment: "Record the environment that actually produced these fits". 04:411-414 calls les_write_provenance() on every run unless LES_PROVENANCE_SKIP=1. That function takes utils::packageVersion() and `out$recorded_utc <- format(Sys.time(), ...)` from the running session (04_provenance.R:63-81).
- **Fix:** 1. In fit_paper2_partA(), record file.mtime(paste0(paper2_results(model_tag), '.rds')) before and after les_brm(), and return whether the fit was sampled (new file, or mtime changed). 2. Call les_p2_write_fit_meta() only when the fit was sampled, or when no &lt;model>_fitmeta.rds exists yet. In that fallback, take versions from fit$version, set fitted_utc to the .rds mtime, and mark the row as recovered. 3. In .run(), call les_write_provenance() only if at least one fit in the invocation sampled, and add an `extra` row naming the models actually sampled. If nothing sampled, print a message and leave the file untouched. 4. Apply the same mtime check to 05 (.fit_prepost_one and fit_cognition_prepost_joint) and to 09b:84-89. 5.
- **Also reported as:** G13-10
- **Status:** resolved in 2352752: `_config.R:226-346`: `les_p2_cache_mtime/_sampled`; `les_p2_write_fit_meta(sampled, fit, cache, dropped)` keeps fitted_utc and versions on a reload (`fit_record` = sampled / reloaded / recovered); 04:571-584 and 05:113-123, 05:233-243 track sampling.

### G11-06. 06b's premise is now false: its documented remedy would make the manuscript say the refitted Part A models predate provenance

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/06b_recover_provenance.R:9`, `paper_2_plasticity/scripts/README.md:16`, `paper_2_plasticity/hpc/README.md:31`, `paper_2_plasticity/hpc/README.md:168`, `paper_2_plasticity/hpc/06b_recover_provenance.slurm:8`
- **What goes wrong:** The next time a stage-04 variant or stage 09 overwrites _provenance.csv, ISSUES.md item 3 applies. Following the README remedy then produces a recovered record, and the rendered availability statement tells the journal that the Part A models were fitted before the provenance mechanism existed, which is false for the 2026-09-11 refits.
- **Evidence:** 06b:9-12: "The Part A fits reported in the manuscript were produced before that mechanism existed, and no later run of script 04 has completed against them, so the file is absent and the manuscript prints "pending"". This is contradicted on three counts. The file is tracked and committed (git ls-files lists paper_2_plasticity/results/_provenance.csv, whose record_source row 06b itself wrote).
- **Fix:** 1. Make 06b stop by default, with a message that its premise no longer holds, unless LES_FORCE_RECOVER=1 is set. Optionally also stop when any target fit's .rds mtime is later than the provenance mechanism's deployment (commit 4d4a5a0, 2026-07-25). Treat that as advisory, since copies can reset mtimes. 2. Correct 06b's header (lines 9-13) and the premise in hpc/README.md:31-34, :94-97 and :166-172, scripts/README.md:16-19 and :70-71, results/README.md:49-53 and paper_2_plasticity/README.md:29 and :159-160. 3. Replace the remedy: keep a copy of the fit-time _provenance.csv made right after the reference run (on the store, or committed once pulled back, which ISSUES.md item 4 already calls for), and restore that copy. Do not rebuild with 06b, and do not restore HEAD's current copy.
- **Status:** resolved: 06b stops unless `LES_FORCE_RECOVER=1` (2352752), and the READMEs say the record was written at fit time on 16 September (b2f67f0).

### G11-08. The sign-aligned flip matches a literal index name; a renamed index turns _signaligned into a copy of the joint model

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/05_fit_brms_prepost.R:161`, `paper_2_plasticity/scripts/05_fit_brms_prepost.R:171`, `paper_2_plasticity/manuscript_setup.R:633`
- **What goes wrong:** If the Stroop index in LES_P2_TASKS is renamed (for example to stroop_interference_ms), then under LES_P2_SIGN_ALIGNED=1 `flip` is all FALSE. The job logs "(0 values)" and fits p2_cognition_prepost_joint_signaligned on unflipped data. The manuscript's sign-aligned sentence then reports a 'sign-aligned' contrast identical to the reported one, and its pd gap of 0 suppresses the polarity clause.
- **Evidence:** 05:154 derives the measures from config: `measures <- unname(LES_P2_COG_INDICES[c("digit_span", "stroop", "asrt")])`. The flip and the reference level are literals: 05:161 `flip <- long$measure == "stroop_interference"` and 05:171 `measure = stats::relevel(factor(measure), ref = "digit_span")`. _config.R:34-36 states the convention these lines break: "Scripts that need a different order ...
- **Fix:** 1. In 05_fit_brms_prepost.R: - :161 becomes `stroop_idx <- LES_P2_COG_INDICES[["stroop"]]; flip <- long$measure == stroop_idx; stopifnot(any(flip))` - :163 uses stroop_idx in the message. - :171 becomes `ref = LES_P2_COG_INDICES[["digit_span"]]`. 2. Optionally, at manuscript_setup.R:633, use `term <- paste0("session_prepost:measure", LES_P2_COG_INDICES[["stroop"]])`. The many qmd literals and the 01 column literals are wider drift for a separate pass. No numeric output changes and no cached fit is invalidated.
- **Status:** resolved in 2352752: 05:202-209 flip by `LES_P2_COG_INDICES[["stroop"]]` with `stopifnot(any(flip))`; 05:216 reference from config. `manuscript_setup.R:705` optional: patch P8.

### G11-09. Part A predictor names are hard-coded three times in 04 and again in 06; a new predictor could silently miss its prior

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/04_fit_brms_predictors.R:247`, `paper_2_plasticity/scripts/04_fit_brms_predictors.R:224`, `paper_2_plasticity/scripts/04_fit_brms_predictors.R:305`, `paper_2_plasticity/scripts/06_summaries.R:103`, `paper_2_plasticity/scripts/02_extract_learning_trajectory.R:80`
- **What goes wrong:** If a feature such as gamma_adj is added to the candidate list at 04:249 but not to the prior list at 04:305-307, the new predictor silently takes the class-b default normal(0, 1) instead of the near-zero evidence-gap prior. The fit succeeds and the manuscript's prior prose (qmd:726-727, "near-zero normals for ... every resting-state predictor") becomes false.
- **Evidence:** The six aperiodic names are typed three times: at 04:224-232 (summarise over `c(aperiodic_exponent, aperiodic_offset, theta_adj, alpha_adj, beta_adj, specparam_iaf)` plus six separate les_zscore mutate lines), at 04:247-249 (the candidate vector) and at 04:305-307 (the prior loop, `"z_aperiodic_exponent","z_aperiodic_offset","z_theta_adj","z_alpha_adj","z_beta_adj","z_specparam_iaf"`).
- **Fix:** (a) Minimal, output-neutral guard first. At the end of les_p2_partA_priors (and only when the informative set is used), stop if any element of `predictors`, or its `z_session_time:` interaction, lacks a coef-specific prior row, e.g. `missing <- setdiff(c(predictors, paste0("z_session_time:", predictors)), pr$coef); if (length(missing)) stop(...)`. (b) Then consolidate the names in fitted order. Add to _config.R a key-indexed cognitive predictor vector, `LES_P2_COG_PREDICTORS <- paste0("z_", c("digit_span", "stroop", "asrt"))`, with a stopifnot that the keys setequal names(LES_P2_COG_TASKS). Add an ordered LES_P2_APERIODIC_MEASURES vector matching 04:224-225.
- **Status:** resolved in 2352752: `_config.R:46-47` `LES_P2_COG_PREDICTORS`, `_config.R:219-220` `LES_P2_APERIODIC_MEASURES`; 04 candidates, aperiodic block, prior loop use them; 04:443-447 stops on a predictor without a coefficient prior; 06:322; 02:122 asserts. Priors and formulas equal HEAD's (test)

### G11-10. The listwise-deletion account is hand-typed in the manuscript, and 04 writes nothing recording who was dropped or why

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/04_fit_brms_predictors.R:349`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:436`
- **What goes wrong:** The 2026-09-11 rescore drops the practice rows before the LES_P2_MIN_OBS_STROOP = 50 trial minimum is applied (_config.R:44). If that leaves a different set of participants without a Stroop score, the count and cause in the sentence at qmd:436-438 go wrong. proj_n() beside it still updates, so the paragraph would contradict itself without any warning.
- **Evidence:** 04:347-349 drops incomplete rows silently: `tidyr::drop_na(dplyr::all_of(c("correct", "z_session_time", preds)))`, logging no count. The fit record keeps only the totals (_config.R:121-122, n_obs and n_participants). The manuscript nonetheless types the cause at qmd:436-438: "The difference is one participant with usable resting-state EEG and no baseline Stroop score, whom listwise deletion removes." The project's st ...
- **Fix:** Make the record name the predictor, and let the manuscript derive or at least check the sentence. (a) In 00b_audit_participant_flow.R check (7), which already runs over learning_trajectory.rds, write the missing cognitive predictor(s) per participant into the detail text or a new column (e.g. 'missing: z_stroop'). No model output changes. (b) In the qmd, compute the gap as flow_n("usable_rseeg") minus proj_n(projpath_raw) and the cause from _participant_matrix.csv (usable_rseeg) joined to _flow_inconsistencies.csv, or at minimum add a render-time guard that prints the usual \*[...]* marker when the gap is not the transcribed one or the missing predictor is not Stroop. Optionally log per-predictor NA counts before 04:349 in a message() for the job log.
- **Status:** resolved 2026-10-26: 04 logs and records the participants listwise deletion removes (2352752), and since the Stroop screen the Participants sentence is computed from that record (`p2_rseeg_gap_sentence()` in manuscript_setup.R): it counts the participants whose only missing column is z_stroop and prints a marker when they do not account for the gap between the resting-state candidates and the fitted sample.

### G12-02. 07's claim that z-scoring removes the 2-40 Hz roll-off bias is false: exponent ranks and peak sets change with range

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/07_extract_aperiodic.R:60`, `paper_2_plasticity/scripts/07_extract_aperiodic.R:123`, `paper_2_plasticity/scripts/07_extract_aperiodic.R:131`, `paper_2_plasticity/supplement.qmd:216`, `paper_2_plasticity/scripts/04_fit_brms_predictors.R:138`
- **What goes wrong:** Part A's aperiodic variant, its projpred ranks, the reported peak counts and the IAF-resolved exclusion list all depend on bins inside the filter's roll-off. The documented mitigation does not hold (between-participant z differences up to 1.8-2.6 SD), so those reported values look plausible but are range artefacts.
- **Evidence:** The default is still a 2-40 Hz fit: 07:123 `if (is.finite(v) && v > 2) v else 40` and 07:131 `fit_range = c(2, .les_ap_fit_max_hz)`. 07:60-65 says the bias 'is close to a constant shared across participants, which the z-scoring applied before modelling removes'; supplement.qmd:216-219 repeats it. 07:51-52 says only 'the top quarter of the fitted bins sits in the filter's roll-off'.
- **Fix:** Minimal remedy, needing author sign-off because it touches the supplement: (1) Correct 07_extract_aperiodic.R:60-65 and supplement.qmd:216-219. Remove the statement that z-scoring removes the bias and state the measured result: under the two-pass reading, correcting for the filter shifts the z-scored exponent by up to 1.3 SD (r = .88 with the reported values; .96 under the single-pass reading), because the robust trimming and peak steps respond to the roll-off differently for each participant. Also fix 07:51-52, since attenuation starts well below 30 Hz (two-pass T &lt; 0.8 from about 23 Hz, about 45% of the fitted bins), not only in 'the top quarter'.
- **Status:** resolved, then superseded: 07's header (2352752) quoted measurements under the old filter model. They were re-measured under the realised filter, written as an artefact by script 12, and reported in supplement S4 (f455211).

### G12-04. Aperiodic/gamma steps never check one eyes-closed spectrum per participant; duplicates or NA IDs pass silently

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/12_extract_gamma_attenuation.R:86`, `paper_2_plasticity/scripts/07_extract_aperiodic.R:397`, `paper_2_plasticity/scripts/10_extract_descriptives.R:228`
- **What goes wrong:** A re-export copied into a subfolder of raw data/EEG (for example 'Session 2/Export/old/') is picked up recursively. 10 writes two spectra under one ID. 12 fits the concatenated bins as one spectrum and doubles the observed band power in obs_ratio. 07 writes two rows that 04 averages. No step warns, and the results look plausible.
- **Evidence:** 12:86 `group_by(participant_lab_ID)` pools all eyes-closed rows for an ID into one .fit_aperiodic() call (12:88), and 12:96-99 sums every matching band row into obs_ratio. There is no uniqueness check. Recordings come from a recursive listing (07:384-385, 10:222-223 `recursive = TRUE`), and IDs are parsed with warnings suppressed (07:397, 10:228 `suppressWarnings(as.integer(sub("^([0-9]+)_RS.*", ...)))`), so a non-ma ...
- **Fix:** Add fail-closed assertions only; none changes a number with the current, verified-clean inputs. 1. In 03_extract_resting_state_eeg.R (after 208), 07_extract_aperiodic.R (after 439) and 10_extract_descriptives.R write_resting_state_psd (after 238): `stopifnot(!anyNA(out$participant_lab_ID))`, and stop if `anyDuplicated(out[c("participant_lab_ID", "session", "condition")])` is non-zero. In 10, carry `session` into the PSD rows so the key exists, or keep only `sess == LES_P2_NEURAL_SESSIONS[1]`. 2. In 12_extract_gamma_attenuation.R before line 85: stop if the eyes-closed PSD has any NA participant_lab_ID or any `anyDuplicated(psd_full[c("participant_lab_ID", "freq_hz")])`. Filter to Session 2 if a session column is added in 10.
- **Status:** resolved in 2352752: 10 `write_resting_state_psd()` keeps `LES_P2_NEURAL_SESSIONS[1]` only and stops on an unparsable lab ID or a duplicated participant x condition x bin. 12 stops on an NA ID, a duplicated participant x bin, or an incomplete 30-45 Hz band. The committed PSD is clean (118 spectra x 89 bins, no duplicates).

### G12-05. peak_width_limits claims to reject bad peaks, but out-of-limit Gaussian fits fall back silently to argmax guesses

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/07_extract_aperiodic.R:240`, `paper_2_plasticity/scripts/07_extract_aperiodic.R:134`, `paper_2_plasticity/scripts/07_extract_aperiodic.R:210`
- **What goes wrong:** For about 37% of recordings the reported specparam IAF is the argmax bin of the flattened spectrum, not a fitted centre. Broad humps the width limit should exclude enter theta_adj/alpha_adj/beta_adj and the beta-peak count, contrary to the stated method.
- **Evidence:** 07:134 `peak_width_limits = c(1, 12), # Hz; reject implausibly narrow/broad "peaks"` and 07:210 'Guards (peak_width_limits, ...) reject noise ripples'. In code, 07:240-245 overwrites (ctr, hgt, wid0) only when the nls fit is within limits; otherwise 07:247 still appends the half-max guess (bin centre, residual height, width clamped at 229).
- **Fix:** Mirror specparam: do the refinement as a bounded fit, e.g. stats::nls(algorithm = "port", lower = c(ctr = ctr - 2*wid0, hgt = 0, wid = peak_width_limits[1]/2.355), upper = c(ctr = ctr + 2*wid0, hgt = Inf, wid = peak_width_limits[2]/2.355)). Fall back only on a genuine nls error, and count the fallbacks in the output. Do not drop out-of-limit peaks: specparam does not, and dropping would change the theta/alpha/beta peak counts injected at qmd:563 and 832-834. Correct the comments at 07:134 and 07:210 ('bound', not 'reject'). This changes specparam_iaf, the adjusted band powers and the refitted exponent/offset for about 23 recordings.
- **Status:** resolved by decision (17 October 2026): the unrefined-peak rule stays, because bounding the refinement on these spectra moves many alpha peaks above 13 Hz (07's header); supplement S4 now states the departure from specparam and the count (23 of 59 recordings), and the article's alpha-frequency predictor does not depend on it.

### G12-06. 12 says it uses 07's fit, but skips 07's peak-removal refit: two different 'aperiodic_exponent' columns

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/12_extract_gamma_attenuation.R:20`, `paper_2_plasticity/scripts/07_extract_aperiodic.R:56`, `paper_2_plasticity/results/CODEBOOK.md:99`
- **What goes wrong:** A reader or later script joining the two results files on aperiodic_exponent, or trusting the header, treats different quantities as identical (differences up to 0.27). The retained fraction is computed from an exponent the manuscript never reports.
- **Evidence:** 12:19-21: 'fitted ... with the same robust outlier-trimmed fit as 07_extract_aperiodic.R'. 12:88 calls only `.fit_aperiodic(.x$freq_hz, log10(.x$power), ...)` on the peak-bearing spectrum. 07's reported exponent comes from the refit after removing the Gaussians (07:271-275). 07:56-58 says 12's 'retained fraction is a function of this exponent'.
- **Fix:** Minimal fix, with no numeric change: state in 12:19-28 that the fit is a single robust fit to the peak-bearing spectrum, without 07's peak-removal refit, so its exponent and offset differ from 07_aperiodic_features.csv (median exponent +0.04, offset +0.19). Make the same point in the codebook_descriptions.csv entries behind CODEBOOK.md:99-100. Preferably also rename the two columns (e.g. ap_exponent_fullfit, ap_offset_fullfit) in 12 and the codebook; no manuscript reader uses them. Switching 12 to 07's refit parameters is a separate analysis decision. It would change the injected gamma figures (6.5% to 6.4%; 60.2% to 77.4%) and import the G12-05 fallback into the refit, so it needs author sign-off.
- **Status:** resolved in 2352752: 12's columns are now `background_offset`/`background_exponent`. The header says they come from a single robust fit, without 07's peak-removal refit, on the filter-corrected spectrum, so they are not 07's parameters. The rerun is done (HTC 8976035) and was pulled in 51bdb75.

### G12-09. The posterior-ROI PSD reduction exists as three near-identical copies in 03, 07 and 10

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/10_extract_descriptives.R:207`, `paper_2_plasticity/scripts/07_extract_aperiodic.R:327`, `paper_2_plasticity/scripts/03_extract_resting_state_eeg.R:169`
- **What goes wrong:** A change to channel handling or the Welch call in one copy (say, dropping bad channels in 03) leaves 07's decomposition and 10's persisted PSD (which 12 also reads) describing a different spectrum from 03's band powers, and nothing detects it.
- **Evidence:** 03:169-177 .summarise_recording, 07:327-337 .posterior_psd and 10:207-217 .roi_psd_one each repeat `h <- .parse_vhdr(vhdr); sig <- .read_bv_ascii(vhdr, h); post <- intersect(LES_RS_POSTERIOR, colnames(sig)); psds <- Filter(Negate(is.null), lapply(post, ... welch_psd ...)); rowMeans(matrix(unlist(...)))`. The listing and session/ID-parsing loop is also copied (03:186-201, 07:383-397, 10:221-229).
- **Fix:** In 03, define one `les_posterior_psd(vhdr)` returning `list(freqs, power)` or NULL, with a single warning policy, and optionally one `les_rs_recordings(root)` returning vhdr/session/pid/condition. Call them from 03's `.summarise_recording`, 07's `.posterior_psd` (which keeps its `raw_band`) and 10's `.roi_psd_one` (which keeps its 1-to-fmax trim). 07 and 10 already source 03, so no new file is needed. Gate the change on byte-comparing the regenerated resting_state_eeg.rds, 07_aperiodic_features.csv and _resting_state_psd.csv against the banked copies. If the author prefers not to touch these scripts before submission, a cheaper interim guard fits in 10: recompute `les_band_power()` from the persisted PSD and `stopifnot()` agreement with resting_state_eeg.rds.
- **Status:** partly resolved: 10 checks the spectra against 03's band powers and stops on a mismatch (2352752). The full refactor remains a proposal.

### G13-03. Submodels beat the reference by up to 7.7 SE and the path is non-monotone; nothing checks the premise

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/08_projpred_selection.R:321`
- **What goes wrong:** suggest_size with baseline 'ref' assumes the reference model sets the ceiling. Here some submodels predict held-out participants far better than the reference does. That can happen when the reference refits (cvfits) and the latent-projected submodels handle new participant levels differently.
- **Evidence:** 08:58-63 says a submodel row 'of roughly zero means that submodel has recovered the reference model's predictive performance'. 08:317-322 then takes suggest_size(vs, stat = "elpd") with baseline = "ref" as given. The shipped paths show submodels well above the reference. Pooled, size 7: elpd_diff 219.10, SE 28.64 (7.7 SE). Aperiodic, size 7: 159.06, SE 25.10 (6.3 SE). Gender, size 4: 135.47, SE 20.57 (6.6 SE).
- **Fix:** Add a diagnostic to .les_projpred_path, which both 08 and 08b use. It should write ref_beaten = any(elpd_diff - elpd_diff_se > 0) and max_z = max(elpd_diff / elpd_diff_se), and log a warning when ref_beaten is TRUE. Record the new columns in CODEBOOK.md. With the author, also report suggest_size(vs, stat = "elpd", baseline = "best") as a sensitivity value, and look at how the reference's out-of-fold elpd is formed under latent = TRUE with the cvfits. Then disclose in the Method/Results (or S5) that submodels exceed the reference, and read the suggested size as a range, as M7 already asked. The cached varsel objects predate the 2026-09-11 Stroop refit (ISSUES.md #1), so compute the sensitivity during the stage-08 rerun, not from the stale objects. All prose changes need author sign-off.
- **Status:** obsolete since 7 October 2026: the manuscript reports no submodel size or ranking (G13-01), so whether submodels beat the reference no longer bears on any reported value, and there is nothing left to disclose in S5. The diagnostics 2352752 added to the selection summary are kept.

### G13-06. 09b common-sample refits and 09c kfold refits never pass the convergence gate the manuscript reports

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/09b_compare_aperiodic_commonsample.R:84`, `paper_2_plasticity/scripts/09c_compare_aperiodic_grouped.R:131`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:917-923`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:934-937`
- **What goes wrong:** A common-sample refit with divergences or low ESS would still feed both _aperiodic_loo_compare.csv and, as the raw model 09c refits, _aperiodic_kfold_compare.csv. The only trace would be a Stan warning in the job log, while the Results say every reported model passed the gate.
- **Evidence:** 09b:84-89 calls les_brm(...) and then les_p2_write_fit_meta(...), with no les_check_convergence. By contrast 04_fit_brms_predictors.R:382 does 'conv &lt;- les_check_convergence(fit, label = model_id, save_to = ...)'. results/_pooled_convergence.csv lists 12 models, and neither p2_predictive_trajectory_commonsample nor p2_predictive_trajectory_gender_commonsample is among them.
- **Fix:** In 09b, after les_brm, run les_check_convergence(fit_raw_c, label = paste0(raw_id, "_commonsample")). Save it under a name 06_summaries.R's '_convergence\\.rds$' glob does not match (e.g. paste0(raw_common_cache, "_diagnostics.rds")), or add max_rhat/min_ess/n_divergent/passed columns for the raw refit to _aperiodic_loo_compare.csv. Log a warning or stop when it fails. In 09c, collect per-fold R-hat, ESS and divergences with a custom loop over the folds (update() + log_lik with allow_new_levels = TRUE, sample_new_levels = "gaussian", mirroring brms .kfold). Otherwise use save_fits = TRUE and extract the diagnostics before dropping the fits, noting the memory cost. Store them with the kfold cache. Leave qmd:1650 and .expected unchanged unless the author chooses to list these fits.
- **Status:** resolved in 2352752. 09b runs `les_check_convergence` on each common-sample refit and saves `<raw_id>_commonsample_diagnostics.rds`, a name outside 06's `_convergence.rds` glob, so `_pooled_convergence.csv` is unchanged, and it logs and warns on failure (rerun as HTC 8976039, pulled in 51bdb75). 09c refits with `save_fits = TRUE`, checks every fold refit against the same gate, warns on any failure and keeps one diagnostics row per fold in its kfold cache. Its rerun (HTC 8976040, pulled on 7 October 2026) passed all 40 fold refits (largest R-hat 1.0009, smallest bulk ESS 6,346 and tail ESS 11,632, no divergent transition).

### G13-07. 09c's 40 kfold refits carry no explicit seed; reproducibility rests on undocumented brms and global-RNG state

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/09c_compare_aperiodic_grouped.R:131`
- **What goes wrong:** Whether a rerun reproduces elpd_diff -56.49 (clustered SE 51.30) pooled and -20.90 (31.39) gender depends on how brms::kfold/update() picks each refit's seed. If it draws from R's RNG, the result also depends on whatever consumed the RNG after the helper's set.seed. A reordering of calls, or a brms change in update()'s seed handling, changes the reported numbers with nothing in the code to show why.
- **Evidence:** 09c:131 'kf &lt;- brms::kfold(fit, folds = fd$folds, save_fits = FALSE)' passes no seed and sets none. The only seeding nearby is the side effect of les_participant_folds(): _shared/R/06_helpers.R:48 'set.seed(seed)' followed by sample(uid). 08 seeds its equivalent refits explicitly: 08:283 'run_cvfun(refmodel, folds = fold_info$folds, seed = LES_SEED)' and 08:310 'seed = LES_SEED'.
- **Fix:** Pass seed = LES_SEED to brms::kfold at 09c:131. seed is not a log_lik argument, so .kfold forwards it through up_args to update() and brm(), and it overrides cmdstanr's RNG-drawn seed for every fold. This makes each model's refits independent of cache history. Store the seed in the kfold cache stamp, which should also carry the fit identity per ISSUES.md #2, and add a seed column to _aperiodic_kfold_compare.csv (CODEBOOK update). Document in les_participant_folds() that it resets the global RNG, or have it restore .Random.seed on exit as 02_diagnostics.R:123-127 does. Restoring would not change any fold assignment. Note in 09c that non-static reduce_sum limits exact reproducibility.
- **Status:** resolved in 2352752. 09c's `kf_cached` sets the global RNG to LES_SEED and passes `seed = LES_SEED` to `brms::kfold`. The global seed matters because `.kfold` hard-sets `future.seed = TRUE` and `log_lik(sample_new_levels = "gaussian")` draws from that stream. The caller's RNG is restored afterwards, and the cache stamp is the folds, a hash of the fit and the seed. The seeded rerun (HTC 8976040, pulled on 7 October 2026) recomputed every cache and wrote the seed, 20260607, into the new `seed` column of `_aperiodic_kfold_compare.csv`. It gives -84.02 (clustered SE 53.29) pooled and 20.98 (33.69) for gender agreement, against -92.44 (54.45) and 21.67 (33.53) from the unseeded run pulled on 18 September, and neither stratum prefers either model. A further rerun would reproduce these values only up to Monte Carlo error, because `reduce_sum` partitions adaptively (G01-01).

### G13-08. 08 swallows errors silently: suggest_size to NA (manuscript prints 'NA'), plus positional and dead fallbacks

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/08_projpred_selection.R:321`, `paper_2_plasticity/scripts/08b_recover_projpred_path.R:92-93`, `paper_2_plasticity/manuscript_setup.R:362`
- **What goes wrong:** If suggest_size errors (for example on an incomplete path), the CSV carries suggested_size NA, is_suggested is FALSE everywhere, and the Results print 'the suggested size was NA'. If a projpred version renames the size column, sizes are assigned by row position with no warning.
- **Evidence:** 08:321-322 'sug &lt;- tryCatch(projpred::suggest_size(vs, stat = "elpd"), error = function(e) NA_integer_)' emits no message (08b:92-93 repeats it). manuscript_setup.R:362 then does 'proj_size &lt;- function(tbl) ... as.character(tbl$suggested_size[1])', which renders the string 'NA' in place of a pending marker. At 08:385-393 a tryCatch catches ANY summary() error and relabels it as ''acc' unavailable'.
- **Fix:** Minimal and complete: (1) In 08 (and 08b), replace the silent handler with one that message()s conditionMessage(e) before returning NA_integer_, and add an explicit check after the call: `if (is.na(sug)) warning("[projpred] ", model_id, ": suggest_size returned NA; the path may be truncated (nterms_max) or the criterion unmet")`. This catches projpred's own NA return, which the tryCatch cannot. (2) In manuscript_setup.R:362, treat NA as pending in the house style of the neighbouring proj_* helpers: `if (is.null(tbl) || !nrow(tbl) || is.na(tbl$suggested_size[1])) "NN" else ...`. Make the qmd:1163-1164 claim 'exactly the suggested size' conditional on the step equalling proj_size() instead of hard-coding it. That last change is an end-product edit and needs sign-off.
- **Status:** resolved in 2352752: New `.les_suggest_size()` (used by 08 and 08b) messages the error, warns on NA, and returns NA when no size meets the 1-SE criterion. projpred otherwise returns nterms_max silently: the void 20 Sep run recorded 17. All three shipped sizes meet the criterion, so nothing changes. The positional size fallback now stops. Since 7 October 2026 the manuscript prints no suggested size (G13-01).

### G13-09. The search-draw count (20) and evaluation draws (400) are hard-coded in 5 places, including the supplement

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/08_projpred_selection.R:307`, `paper_2_plasticity/hpc/08_projpred.slurm:60`, `paper_2_plasticity/hpc/09_aperiodic_model.slurm:49`, `paper_2_plasticity/supplement.qmd:258-259`
- **What goes wrong:** A rerun with LES_PROJPRED_NDRAWS=40, or an edit to ndraws_pred, leaves the supplement still stating 20/400, and no artefact shows which values produced the shipped paths.
- **Evidence:** 08:153 '.les_ndraws &lt;- as.integer(Sys.getenv("LES_PROJPRED_NDRAWS", unset = "20"))' is passed as 'nclusters = .les_ndraws' (08:308), so an env var named NDRAWS actually sets nclusters (explained only at 08:102-104). 08:307 'ndraws_pred = 400' is a bare literal. The 20 is repeated at hpc/08_projpred.slurm:60 and hpc/09_aperiodic_model.slurm:49.
- **Fix:** (1) In 08, hoist the evaluation draws beside the search setting: `.les_ndraws_pred <- as.integer(Sys.getenv("LES_PROJPRED_NDRAWS_PRED", unset = "400"))`. Add a WHY-comment that 20 and 400 match projpred's cv_varsel defaults, and validate both values as positive integers. Passing `ndraws_pred = .les_ndraws_pred` keeps the default behaviour. (2) Record `nclusters_search = .les_ndraws` and `ndraws_pred = .les_ndraws_pred` (and nterms_max) in &lt;model>_projpred_summary.rds and as columns of the path CSV. Add matching entries to codebook_descriptions.csv and regenerate CODEBOOK.md. Do this at the rerun that ISSUES.md item 1 already requires, not as a separate job.
- **Status:** resolved in 2352752: `LES_PROJPRED_NDRAWS_PRED` added (default 400, validated). The draw counts are no longer exported in the slurms. The path CSV gains `nterms_max`, `nclusters_search` and `ndraws_pred`, read back from the vsel object (`vs$nterms_max`, `nprjdraws_search`, `nprjdraws_eval`), so 08b records them too.

### G13-11. 09c runs its ~40 h computation at top level, with no sys.nframe() guard, unlike its sibling scripts

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/09c_compare_aperiodic_grouped.R:195`
- **What goes wrong:** Anyone who sources 09c to reuse compare_grouped() (as 08b sources 08) starts 40 brms refits, sets a global mc.cores, and overwrites _aperiodic_kfold_compare.csv.
- **Evidence:** 09c:82 'options(mc.cores = LES_CHAINS)' and 09c:195-222 (out &lt;- ...; STRATA &lt;- ...; for (s in STRATA) { row &lt;- compare_grouped(...) ... utils::write.csv(res, out, ...) }) run at top level. The sibling scripts guard their drivers: 08:480, 08b:126, 09:153 and 09b:137 all use 'if (sys.nframe() == 0L)'.
- **Fix:** Wrap lines 195-222 in `.run <- function() { old <- options(mc.cores = LES_CHAINS); on.exit(options(old), add = TRUE); ... }` and delete the top-level options() call at 09c:82, keeping its WHY-comment beside the call inside .run. End the file with `if (sys.nframe() == 0L) .run()`. Add a header line matching 09b:34-35. Keep LES_KFOLD_GROUPED_K and compare_grouped() at top level so that sourcing still defines them. Apply it together with the ISSUES.md item 2 cache-stamp fix, before the next 09c submission.
- **Status:** resolved in 2352752: The 09c driver is now in `.run()` behind `if (sys.nframe()==0L)`. `options(mc.cores)` moved inside, with on.exit restore.

### G13-14. Missing docstrings in 09b (.les_loo, compare_common, .run); undocumented rewrites of reference-fit caches

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/09b_compare_aperiodic_commonsample.R:54`
- **What goes wrong:** After 09b, the aperiodic reference fit's rds carries a newer mtime and a changed object. This muddies the date comparison ISSUES.md uses to judge whether cvfits and kfold caches predate a refit ('reference fit refitted' column), and nothing in 09b warns of it.
- **Evidence:** 09b:54 '.les_loo &lt;- function(fit, cache) brms::add_criterion(fit, "loo", file = cache)$criteria$loo' and 09b:91-92 '.les_loo(fit_aper, aper_cache)'. With file = aper_cache, add_criterion saves the updated brmsfit back to the aperiodic reference model's own cache (paper2_results(aper_id).rds), which belongs to stage 04/09. compare_common (56) also writes &lt;raw_id>_commonsample.rds and _commonsample_fitmeta.rds.
- **Fix:** Minimal, documentation only. Add a comment at 09b:54 saying that add_criterion(file=) re-saves the whole brmsfit to the given cache whenever loo is not already attached, and that for fit_aper this rewrites the stage-04/09 reference fit &lt;aper_id>.rds (moving its mtime) on the first run after a refit. Add &lt;raw_id>_commonsample_fitmeta.rds and the in-place loo attachment to &lt;aper_id>.rds and &lt;raw_id>_commonsample.rds to the Outputs list at 09b:24-27. Also give the mtime caveat in the stale-cache notes that ISSUES.md #1-#2 rely on. Optional behavioural change, needing sign-off because it alters banked cluster state and adds loo compute time on every run: use loo_aper &lt;- brms::loo(fit_aper) for the reference fit, or set fit_aper$file &lt;- NULL before add_criterion.
- **Status:** resolved in 2352752: Added docstrings for `.les_loo`, `compare_common` and `.run`. The Outputs list now includes the fitmeta, the diagnostics, and the in-place loo re-save of `<aper_id>.rds`. Store mtimes confirm the issue: aperiodic fits written 16:27/16:36 were re-dated 19:48/20:10 by 09b.

### G14-01. Reliability self-validation checks values only on the joined participants, never the participant set or n

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/11_extract_predictor_reliability.R:209`, `paper_2_plasticity/scripts/11_extract_predictor_reliability.R:175`, `paper_2_plasticity/scripts/11_extract_predictor_reliability.R:203`, `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:267`
- **What goes wrong:** Suppose 01 changes which participants carry an index, for example an exclusion that sets a participant's value to NA or drops a key row whose lab ID is pending, and 11 does not follow. The mirror still recomputes that participant, the inner join and finite filter hide the mismatch, and validation passes.
- **Evidence:** 11:210-215 `cmp <- merge(full, shipped[, c("participant_home_ID", s$name)], by = "participant_home_ID")` (inner join) ... `cmp <- cmp[is.finite(cmp$v) & is.finite(cmp$shipped), ]` ... `if (!nrow(cmp) || max_dev > 1e-6) stop(...)`. Participants present in only one of the two sets, or non-finite in the shipped index, are dropped before the comparison.
- **Fix:** In les_predictor_reliability() in paper_2_plasticity/scripts/11_extract_predictor_reliability.R: (a) build key_ids with 01's enrolment rule, `key_ids <- unique(key$participant_home_ID[!is.na(key$participant_home_ID) & !is.na(key$participant_lab_ID)])`. (b) Before the value check at line 210, stop if `anyDuplicated(shipped$participant_home_ID)` is non-zero. (c) Also stop unless `setequal(full$participant_home_ID[is.finite(full$v)], shipped$participant_home_ID[is.finite(shipped[[s$name]])])`, and print both set differences in the error message. (d) Report `n_participants = sum(is.finite(full$v))`, not nrow(a) from .split_half(), and optionally add the median number of participants entering each split's correlation as a separate column.
- **Status:** resolved in 2352752: 11 builds `key_ids` with 01's rule (home ID with a lab ID). It stops on duplicated shipped IDs, and on `!setequal(finite mirror IDs, finite shipped IDs)` with both differences printed. `n_participants` = finite full-set count. Synthetic tests: it catches the missing-row and NA-value cases the old code passed.

### G14-04. Default chain runs 03 concurrently with 04/05 although both read the resting_state_eeg.rds that 03 rewrites

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/hpc/submit_all.sh:79`, `paper_2_plasticity/hpc/README.md:116`, `paper_2_plasticity/scripts/04_fit_brms_predictors.R:208`
- **What goes wrong:** Resubmitting the whole chain after a change to 03's code or inputs, without LES_SKIP_RSEEG=1, can go three ways. 04 may start while saveRDS is truncating or writing the file, giving a readRDS error that wastes a 3-day allocation. It may read the previous version, giving Part A fits and summaries built on stale rs-EEG predictors while data_derived holds the new ones, silently.
- **Evidence:** submit_all.sh:75 `JID_EEG=$(submit ${DEP_INSTALL} "${HPC_DIR}/03_extract_rseeg.slurm")` has no dependency. :79 `submit --dependency=afterok:${JID_COG}:${JID_TRAJ} ... 04_fit_predictors.slurm` and :81 (05) do not wait for it. The uncommitted comment :31-35 and README:129-133 acknowledge that '04 can read the file mid-write', but the remedy is an opt-out flag (LES_SKIP_RSEEG=1), and the default still races.
- **Fix:** 1. In submit_all.sh, set `DEP_EEG=""` before the `if` at :72. In the else branch, after :75, set `DEP_EEG=",afterany:${JID_EEG}"`. 2. Change :79 to `submit --dependency=afterok:${JID_COG}:${JID_TRAJ}${DEP_EEG} ...`. The comma joins the two conditions with AND, and afterany keeps the documented rule that a failed 03 does not stall 04. Do not reference `${JID_EEG}` directly: under `set -o nounset` it aborts the script when LES_SKIP_RSEEG=1 leaves it unset. 3. 05 needs no change. 4. Update the header at :10-13 and :31-35, and README:116-121 and :129-133, so they describe the enforced order. 5.
- **Status:** resolved in 1533b4a (Part A waits for 03 when 03 is submitted) and b2f67f0 (docs).

### G14-06. 09_aperiodic_model.slurm claims its resources mirror 08, but 08 was resized after OOM and walltime failures and 09 was not

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/hpc/09_aperiodic_model.slurm:22`, `paper_2_plasticity/hpc/08_projpred.slurm:30`
- **What goes wrong:** Stage 09 fits two aperiodic Part A models and then runs the same sequential cv_varsel over two reference models. That runs 8 PSOCK workers, each with a full copy, in 96 G against 08's 168 G for 6, within 3 days against 08's measured more-than-3-days per model. The job can be killed by OOM or walltime part-way through the multi-day search, and the aperiodic selection the manuscript reports is not regenerated.
- **Evidence:** 09:22-23 'Resourcing mirrors 04 (the Bernoulli fit: 4 chains x 2 threads = 8 CPUs) and 08, whose allocation goes to run_cvfun's K reference refits'. 09:32-34 `--cpus-per-task=8`, `--mem-per-cpu=12G`, `--time=3-00:00:00`, and :43 `LES_PROJPRED_CORES="${SLURM_CPUS_PER_TASK:-8}"`. 08:30-31 `--cpus-per-task=6` and `--mem-per-cpu=28G`, :39 `--time=7-00:00:00`. 08:42-46: 'earlier runs OOM'd ...
- **Fix:** Make --time cover both fits plus two 10-fold, search-validated cv_varsel runs: at least 08's 7-00:00:00 plus 04's fit time, e.g. 10-00:00:00 on `long`, which allows 30 days. Keep --cpus-per-task=8 for the fit step (LES_THREADS_PER_CHAIN=2). Raising --mem-per-cpu to 28G is optional, since the evidence for OOM is weak. Replace the 'mirrors 04 and 08' comment with the actual sizing rationale: the fit step needs 8 CPUs; the projpred step needs 08's walltime at K=10. A cleaner minimal alternative that needs no new wrapper: restrict 09 to step (1) at 04's resources, and run step (2) with the existing `sbatch ... 08_projpred.slurm aperiodic aperiodic_gender`. 08 already forwards strata (08_projpred.slurm:62-79) and carries the 7-day allocation.
- **Status:** resolved in 913c035: 8 x 21 GB for 10 days, with the sizing history in the header.

### G14-08. 11 re-implements all three of 01's trial-cleaning pipelines and uses 01's private helpers instead of shared builders

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/11_extract_predictor_reliability.R:92`, `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:135`, `paper_2_plasticity/scripts/11_extract_predictor_reliability.R:61`
- **What goes wrong:** Every future change to trimming, enrolment or practice handling in 01 must be copied by hand into 11. Changes that alter only the participant set pass the value-only self-validation (see the BLOCKING finding). Changes that alter values stop the reliability job, but only after the refit chain has already regenerated the indices.
- **Evidence:** 11:104-129 `.trials_stroop` repeats 01:140-162 step for step: rename, `filter(`Zone Type` == "response_keyboard") |> distinct()`, make.names, `.les_drop_practice`, RT bounds, `filter(n() >= LES_P2_MIN_OBS_STROOP)`, the `group_by(participant_home_ID, Correct)` 3-SD trim, drop_na and the factor recode. 11:131-154 `.trials_asrt` repeats 01:197-215, and 11:92-102 `.trials_digit_span` repeats 01:180-184.
- **Fix:** As proposed, with the safeguards a change to the index producer needs: 1. Split each task function in 01 into a documented public trial builder, `les_p2_<task>_trials(files)` returning the trimmed trial frame (the exact frame 11 builds now), plus a summariser, so that `les_p2_stroop(files) == summarise(les_p2_stroop_trials(files))`. Leave the batch-priority reader and the practice switch where they are. 2. Have 11 call those builders through `.les_p2_files(session, ...)` and delete 11:92-154. Keep the full-set self-validation as a regression test, and add the participant-set check from G14-01. 3.
- **Status:** partly resolved (17 October 2026): the Stroop's trial builder, les_p2_stroop_trials() in 01, is now shared with 11 (16fed74), because the Stroop screen changed it. 11 still mirrors the digit-span and ASRT pipelines, under its self-validation.

### G14-13. Baseline session hard-coded as session = 1 in 11 and 02; changing it would overwrite the Session-1 table

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/11_extract_predictor_reliability.R:179`, `paper_2_plasticity/scripts/02_extract_learning_trajectory.R:78`
- **What goes wrong:** If the baseline mapping in _config.R changes, 02 and 11 keep using session 1. If someone calls `les_predictor_reliability(5)` to inspect Session-5 reliability, it overwrites results/_predictor_reliability.csv, and the manuscript renders those numbers under the 'Session 1' caption.
- **Evidence:** 11:179 `les_predictor_reliability <- function(session = 1) {`. _config.R:20 defines `LES_P2_COG_SESSIONS <- LES_COG_PREPOST # c(1, 5)`, from which the baseline is derivable. 02_extract_learning_trajectory.R:78 repeats the literal: `filter(session == 1, !is.na(participant_lab_ID))`.
- **Fix:** Replace the literal with the config constant at all three sites: 11:179 `function(session = LES_P2_COG_SESSIONS[1])`, 02:78 `filter(session == LES_P2_COG_SESSIONS[1], ...)`, 10:106 likewise, and update the 'Session 1' wording in the comments at 02:63 and 10:104. In 11, either stop() when `session != LES_P2_COG_SESSIONS[1]` or add a `_s<session>` suffix to the output name at :231 for non-baseline sessions, so the manuscript-facing _predictor_reliability.csv can only hold baseline values. Optionally have manuscript_setup.R assert that unique(predrel_tbl$session) is the baseline, which touches the render path and needs sign-off.
- **Status:** resolved in 2352752: 10:131 `session == LES_P2_COG_SESSIONS[1]`. 11 defaults to `LES_P2_COG_SESSIONS[1]`, and a non-baseline session writes `_predictor_reliability<tag>_s<session>.csv`. 02 was already fixed by another agent (02:115).

### G15-02. Fitted Part A sample size (proj_n) comes from projpred path CSVs whose n is typed into 08b, not read from the fit

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/manuscript_setup.R:363`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:436`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:499`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:955`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:1198`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:1531`
- **What goes wrong:** The queued Stroop refit lands and 06 re-pools the posterior summaries, but stage 08 stays held and 08b is re-run or left untouched. The refitted raw-band model might now use 55 or 57 participants. The Participants section, the flow figure's last bar and the Limitations sentence would still print 56 beside estimates from the new fit, and nothing would mark the mismatch.
- **Evidence:** manuscript_setup.R:363 `proj_n <- function(tbl) ... as.character(tbl$n_participants[1])`. It supplies the primary model's N at qmd:436 ('the fitted raw-band model comprises `r proj_n(projpath_raw)`'), qmd:439, the flow figure's final stage at qmd:499 (`suppressWarnings(as.integer(proj_n(projpath_raw)))`), qmd:505, 955, 1198 and 1531.
- **Fix:** Keep proj_n reading the path CSV, which is the N of the reference fit the reported selection was run on. Add a cross-check only. In manuscript_setup.R, read paper2_results('_pooled_fit_metadata.csv') if present. When it holds a row with model_tag == LES_P2_MODELS[['predictive']] (or [['predictive_aperiodic']]) whose n_participants differs from the path CSV's, make proj_n return a visible marker such as '\*[N mismatch: path CSV vs fit record]*'. When the file or row is absent, return the path value unchanged. Guard the flow-figure call at qmd:499 against a non-integer return. Leave 08b untouched (a documented one-off).
- **Also reported as:** G13-05
- **Status:** resolved in 51bdb75: `proj_n()` checks the selection's N against the fit record. Since 7 October 2026 the manuscript reads the fitted Ns from the fit record itself, through `fit_n()` and `_pooled_fit_metadata.csv`, and `proj_n()` is gone with the ranking (G13-01), so the path files no longer supply any N.

### G15-07. Committed _predictor_values.csv includes 9 rows from unlinked, non-enrolled people, and Figure S1 plots them

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/supplement.qmd:318`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:517`, `paper_2_plasticity/manuscript_setup.R:30`, `paper_2_plasticity/supplement.qmd:315`
- **What goes wrong:** Rendering the supplement today plots three extra points in each cognitive panel of Figure S1. Those points belong to people with no consent linkage, which the Method says were excluded. Re-running step 10 would silently change the figure, and its note would then be wrong.
- **Evidence:** A read-only Rscript on results/_predictor_values.csv finds 9 rows with NA participant_lab_ID (rows 271-273, 379-384): digit_span, stroop_interference and asrt_learning for three unlinked individuals (for example `NA digit_span 19`, `NA asrt_learning 162.79`).
- **Fix:** 1. Do not submit a new run. Pull the output of the queued job 8782463, which already runs step 10 on the test-block Stroop index. Before committing it, check that no participant_lab_ID is NA and that every panel's ids are the inner-joined frame, i.e. match the n in the refreshed _predictor_descriptives.csv. 2. Add a guard in the fig-s1 chunk: `pred_vals <- pred_vals[!is.na(pred_vals$participant_lab_ID), ]`. A guard in .les_vif() is optional, since complete.cases already drops those rows. 3. With author sign-off, rewrite the note at supplement.qmd:315 so it describes the joint baseline frame of participants with both a Session 1 battery and eyes-closed rs-EEG, instead of 'the stored records for that measure'. 4.
- **Also reported as:** G10-13
- **Status:** resolved: the descriptives run of September left no unlinked rows, and Figure S1 drops any (913c035).

### G15-09. Naive K-fold SE: main text points to the supplement, the supplement points back, and neither prints it

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/manuscript_setup.R:423`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:850`, `paper_2_plasticity/supplement.qmd:245`
- **What goes wrong:** A reader or reviewer following either cross-reference finds no naive standard error in either document, although both documents say the other reports it.
- **Evidence:** qmd:849-851: 'Why the trial-level criterion cannot settle the comparison on its own, and the naive standard error alongside, are given in the online supplementary material (Section S5)'. supplement.qmd:245-247: 'the naive independent-observation standard error is reported alongside in the main article so the size of the clustering correction is visible'.
- **Fix:** 1. In aper_kf_sentence() (manuscript_setup.R:449-454), print the naive SEs beside the ratios, for example: "...clustered on participants (%s and %s), which exceed the naive independent-observation standard errors (%s and %s) by factors of %s and %s...", with aper_kf("pooled","se_naive") and aper_kf("gender","se_naive"). 2. Edit qmd:849-851 to drop "and the naive standard error alongside," so it reads: "Why the trial-level criterion cannot settle the comparison on its own is given in the online supplementary material (Section S5)." 3. supplement.qmd:245-247 is then accurate as written. The alternative is to remove the se_naive branch and reword both sentences to refer to the inflation factor. Either route is author-signoff material, because it changes rendered manuscript text.
- **Status:** resolved in 51bdb75.

### G15-12. Counts the artefacts already hold are typed into the prose and the setup file, in several places

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/paper_2_neuroplasticity.qmd:566`, `paper_2_plasticity/manuscript_setup.R:599`, `paper_2_plasticity/manuscript_setup.R:605`, `paper_2_plasticity/manuscript_setup.R:609`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:1667`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:437`
- **What goes wrong:** The Stroop rescore changes which rs-EEG participants have a Stroop score, so 'one participant' becomes wrong. An IAF re-extraction changes the floor-pinned set, and 'two' becomes wrong in four places while the iafres refit excludes a different number. A minimum-age change leaves 'The 16-year-old participant' in place.
- **Evidence:** qmd:566 'Two of them are pinned at the 7 Hz floor with no fitted peak'. The same count appears at manuscript_setup.R:599 ('drops the two recordings'), :605 and :609 ('excludes the two floor-pinned recordings') and qmd:1667 ('excluding the two floor-pinned IAF recordings'). Joining 07_aperiodic_features.csv (specparam_iaf NA) with the iaf rows of _predictor_values.csv (value == 7) gives ids 12 and 41 today;
- **Fix:** All edits are in manuscript_setup.R and the qmd, and all need sign-off. (a) Add iaf_unresolved_n(): the count of eyes-closed Session-2 ids with is.na(specparam_iaf) in aper_feat whose iaf in _predictor_values.csv equals LES_P2_IAF_SEARCH_HZ[1], the same rule as 04:159-162. Spell it as a word. Use it at qmd:566, in iafres_sentence() (:605, :609) and in the .cml label at qmd:1667 via sprintf. Fix the :599 comment. (b) For qmd:436-438, add a render-time check, or derive the sentence, so the count and the named cause come from the data. Either print flow_n('usable_rseeg') minus proj_n(projpath_raw), with a visible marker when the dropped participants are not all Stroop-missing, or emit the sentence from _predictor_values.csv. (c) Correct the manuscript_setup.R:588-590 comment.
- **Status:** partly resolved: K, the projpred settings and several counts are read from artefacts (51bdb75). Other typed counts remain.

### G15-13. Sampler, trimming, band, fold and specparam settings are re-typed in the prose of both documents

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/paper_2_neuroplasticity.qmd:784`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:921`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:532`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:845`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:552`, `paper_2_plasticity/supplement.qmd:140`
- **What goes wrong:** A run with LES_PROJPRED_NDRAWS=40, a changed trimming constant or a changed K leaves the Method and supplement describing settings the run did not use, with no marker. The duplicated copies can also drift apart from each other.
- **Evidence:** qmd:784-787 'four chains of 10,000 iterations each, the first 2,000 discarded as warm-up, giving 32,000 post-warm-up draws, with `adapt_delta` = 0.95 and `max_treedepth` = 12', which repeats _shared/R/01_bayesian_settings.R:81-87 (LES_CHAINS 4L, LES_ITER_WARMUP 2000L, LES_ITER_SAMPLING 8000L, LES_CONTROL).
- **Fix:** Keep the rendered wording unchanged and do it in two steps. (a) Now, from artefacts that already exist: replace '$K = 10$' at qmd:844 with `r aper_kf("pooled", "k")` plus a pending marker, and replace '48' at supplement.qmd:150 with `r task_spec("digit_span", "scored_trials")`. (b) Record the other settings at the time they are used, not from the render box's constants. Add chains, warm-up, sampling iterations, adapt_delta, max_treedepth and threads per chain to les_p2_write_fit_meta(), and rhat_max and ess_min to the les_check_convergence() output. Have 08 write nclusters and ndraws_pred into its path CSV, and 07 write LES_AP_SETTINGS into its artefact. Have 01 write the RT window, SD cutoff and minimum trial counts into _task_specs.csv or the index artefact.
- **Also reported as:** G01-09, G13-22
- **Status:** partly resolved: K and the projpred settings are read from the artefacts (51bdb75). Sampler and band settings are still typed.

### G15-14. Convergence completeness check leaves out the variant models whose estimates the text reports

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/paper_2_neuroplasticity.qmd:934`, `paper_2_plasticity/manuscript_setup.R:604`, `paper_2_plasticity/manuscript_setup.R:630`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:1650`
- **What goes wrong:** An opt-in refit, such as the queued sign-aligned or IAF-resolved variants, is pooled into the posterior summaries without its _convergence.rds, or fails the gate. Its estimates print in Results and Method, the appendix claim stays in place, and no marker or missing-diagnostics sentence appears.
- **Evidence:** qmd:934-937 `.expected` lists only the four base Part A ids, three .prepost_id() and cog_prepost_joint. Estimates are also reported from p2_predictive_trajectory_gender_iafres (iafres_sentence, manuscript_setup.R:602-612, at qmd:567), both _weakprior fits (sens_effect(..., 'weak'), qmd:1142 and 1148) and p2_cognition_prepost_joint_signaligned (signaligned_sentence at qmd:1326;
- **Fix:** In the qmd:933-944 chunk, build the expected set from the models the document can actually report, so that opt-in variants are expected only once their summaries exist: `.expected <- union(<current base ids>, if (!is.null(post_tbl)) unique(post_tbl$model))`. Also add the _weakprior ids of the models in sens_tbl, since _prior_sensitivity.csv reads their summaries. Change the message's cause wording ('whose fits predate the current diagnostic artefact') to something neutral, because a partial sync produces the same state. Leave report_effect() unchanged. Nothing renders differently today, because every model has a convergence row.
- **Status:** resolved in 913c035.

### G15-18. Four figures bypass the 'set once' base font size: two hard-code 10, two default to 9

- **Severity:** MAJOR (reported as MINOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/paper_2_neuroplasticity.qmd:1272`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:1370`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:603`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:612`
- **What goes wrong:** Changing LES_FIG_BASE_SIZE leaves fig-predictor-forest and fig-prepost at 10 pt. The two duration figures already render at 9 pt, the size the comment calls too small, so type sizes are inconsistent across the paper's figures.
- **Evidence:** The setup comment at qmd:279-284 says 'Figure text size, set once and inherited by every figure through les_theme() ... the 9 pt previously set here arrived as roughly 7.3 pt, below what is legible in print', and qmd:284 sets `LES_FIG_BASE_SIZE <- 10`. Yet qmd:1272 and qmd:1370 call `les_theme(10)` with a literal.
- **Fix:** Change the defaults at _shared/R/07_task_durations.R:338 and :370 to `base_size = LES_FIG_BASE_SIZE`, matching les_theme(). It is evaluated lazily, so the pipeline scripts that source 07 without plotting are unaffected. That one change fixes both papers' duration figures. Also replace `les_theme(10)` with `les_theme()` at Paper 2 qmd:1272 and 1370. The duration figures in both manuscripts would change from 9 pt to 10 pt, so this needs sign-off.
- **Status:** resolved in the working tree (figure pass, 18 September 2026). Both duration helpers in `_shared/R/07_task_durations.R` default to `base_size = LES_FIG_BASE_SIZE`, every call in both papers passes it, and no `les_theme(10)` call remains in either manuscript.

### G16-02. Convergence prose and caption assert 'no divergent transition' and 'all met the criteria' without checking conv_tbl

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:2292`, `paper_1_transfer/paper_1_morphosyntax.qmd:3681`, `paper_1_transfer/paper_1_morphosyntax.qmd:3431`
- **What goes wrong:** Any pooled refit (the queued sensitivity refits are pooled into the same _pooled_convergence.csv) reports divergences. The Results then say "101 of the 102 fitted models met the convergence criteria ... and no model produced a divergent transition", and the appendix caption still says every model met the criteria. That is a false diagnostic claim in the submitted text.
- **Evidence:** 2289-2298: `"%s met the convergence criteria. ... the smallest bulk and tail effective sample sizes were %s and %s, and no model produced a divergent transition. ..."`. The clause is fixed text even in the `sprintf("%d of the %d fitted models", np, n_fit)` branch, and n_divergent is never read.
- **Fix:** In the chunk at 2284-2305, compute `nd <- sum(conv_tbl$n_divergent > 0, na.rm = TRUE)`. Emit 'and no model produced a divergent transition' only when nd == 0; otherwise emit 'and %d model(s) produced divergent transitions'. Replace the last sentence of the tbl-convergence-appendix apa-note (3681) with a statement of the criteria alone, e.g. 'The criteria were a maximum R-hat below 1.01, both effective sample sizes above 400 and no divergent transitions.' Compliance then comes only from the injected Results paragraph. apa-note is a static chunk option, and whether an `!expr` value passes through knitr into apaquarto is unverified, so do not rely on it. Derive 3431 ('All eighteen cells ...
- **Status:** resolved: the convergence prose and caption are conditional on the pooled diagnostics (verified 4 October 2026).

### G16-03. Exclusion guard counts records rather than grid cells; erp_model_n's _retfree filter can never match

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:320`, `paper_1_transfer/scripts/_config.R:360`, `paper_1_transfer/paper_1_morphosyntax.qmd:309`
- **What goes wrong:** After re-pooling, a partial maximal refit (say the six verb cells missing or stale) still yields nrow(m) = 12 + 12 = 24 >= 18 once the 12 retention-free maximal records are present. The guard returns "", and the Method's exclusion sentence loses its Pending marker over an incomplete grid. That is the case the _config.R comment at 333-335 says the check exists to catch.
- **Evidence:** misfilter_status() 319-324 delegates to les_p1_misfilter_status(), whose completeness test (_config.R:360-362) is `if (nrow(m) < n_expected) { return(sprintf("only %d of the %d ERP models have been refitted under it", ...`. It checks a record count, not a set of distinct cell ids, and never filters retention-free fits.
- **Fix:** In les_p1_misfilter_status() (_config.R:341-363), after the keep_misfiltered filter add `if ("retention_free" %in% names(m)) m <- m[!(m$retention_free %in% TRUE), , drop = FALSE]`. Replace the row-count test with a cell-coverage test: `missing <- setdiff(les_p1_erp_grid()$cell_id, unique(m$model)); if (length(missing)) return(sprintf("only %d of the %d ERP models have been refitted under it", n_expected - length(missing), n_expected))`, or at minimum compare `length(unique(m$model))` with n_expected. In erp_model_n() (qmd:308-311), drop the dead `_retfree` grep and apply the same column-guarded retention_free filter. Add test_exclusion_guard.R cases: 18 clean maximal plus 12 clean retention-free maximal clears the marker, and 12 maximal plus 12 retention-free maximal keeps it.
- **Also reported as:** G04-04, G07-04
- **Status:** resolved: the guard counts distinct cells (aad57ed), and `erp_model_n()` sets the retention-free refits aside (2e89d05).

### G16-09. Window bounds, session schedule and grid dimensions are literals duplicated across figures, tables and prose

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:2411`, `paper_1_transfer/paper_1_morphosyntax.qmd:3792`, `paper_1_transfer/paper_1_morphosyntax.qmd:2526`, `paper_1_transfer/paper_1_morphosyntax.qmd:1813`, `paper_1_transfer/paper_1_morphosyntax.qmd:3608`, `paper_1_transfer/paper_1_morphosyntax.qmd:1451`
- **What goes wrong:** A change to LES_P1_WINDOWS or the grid (for example restoring the nominal 500/600/900 bounds) refits the models, but the shaded windows, topography averaging window, prior table and prose keep the old bounds. The figures then silently describe windows the models no longer use.
- **Evidence:** The window bounds are typed in four places. Waveforms 2411-2413: `annotate("rect", xmin = 200, xmax = 498, ...)`, `xmin = 300, xmax = 598`, `xmin = 400, xmax = 898`. Difference waves 3792-3794 repeat them. The topography uses `ega$time >= 400 & ega$time <= 898` (2526), and the prose says "up to 498, 598 and 898 ms" (1813). All duplicate LES_P1_WINDOWS (_config.R:66-70).
- **Fix:** Build the three annotate("rect") layers at qmd:2411-2413 and 3792-3794 from LES_P1_WINDOWS (min_ms/max_ms). Take the topography bounds at qmd:2526 from LES_P1_WINDOWS[["400_900"]]. Loop the prior table over names(LES_P1_WINDOWS), keep the single macroregion, and reword the comment at 3606 to say priors are not graded by macroregion (citing 01_bayesian_settings.R:169-172). Replace 9L with length(LES_P1_WINDOWS) * length(LES_P1_PROPERTIES). Derive win_ord from names(LES_P1_WINDOWS). Set `.sess <- LES_ERP_SESSIONS` in fig-design. Either put the property-entry sessions in the manifest or add a stopifnot that .entry is a subset of LES_ERP_SESSIONS. Inject the '498, 598 and 898' prose from LES_P1_WINDOWS or guard it at render time. Re-render and confirm the figures are byte-identical.
- **Status:** resolved: the window bounds in the Method and the design figure's sessions are read from the configuration (913c035), and a render-time check ties the figures' windows to the models' (2e89d05).

### G16-10. Sample- and artefact-derived values are typed in the abstract, Method, figure notes and decoding prose

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:81`, `paper_1_transfer/paper_1_morphosyntax.qmd:1750`, `paper_1_transfer/paper_1_morphosyntax.qmd:1768`, `paper_1_transfer/paper_1_morphosyntax.qmd:1711`, `paper_1_transfer/paper_1_morphosyntax.qmd:1613`, `paper_1_transfer/paper_1_morphosyntax.qmd:2128`
- **What goes wrong:** A refit, re-extraction or decoding rerun changes a count (for example a third DOM cluster survives, or the usable-ERP N changes). The injected numbers update but these typed statements do not. The abstract then contradicts the body, and the render-anytime design promises something it does not deliver.
- **Evidence:** Abstract 81-84: "in 65 ... 64 contributed usable judgement data and 63 usable ERP data". These duplicate _sample_flow.csv enrolled 65, usable_accuracy 64 and usable_erp 63, which the body injects with flow_n(). Other typed values: "(lab IDs 7, 8, 9 and 16)" (1750, duplicating LES_P1_MISFILTERED, _config.R:139);
- **Fix:** Add render-time guards on the pattern of cred_cells_guard or misfilter_status(), each emitting a visible *\*[Check: ...]** marker on mismatch. (1) Compare the abstract's 65/64/63 with flow_n("enrolled"/"usable_accuracy"/"usable_erp"); a guard does not depend on Quarto evaluating inline R in YAML and leaves the 235-word abstract unchanged. (2) Check that the DOM overall time-course has exactly 2 surviving clusters, the first ending before 0 ms and the second starting before 0 ms. (3) Check dec_gender$pre_n_fdr == 0 and dec_verb$pre_n_fdr == 0. (4) Check _rsvp_timing.csv min_onsets_within_900ms == max_onsets_within_900ms == 1.
- **Status:** resolved 2026-10-26: the abstract's count is guarded (2e89d05). The decoding section was rewritten after the October rerun with every count computed from the time-course files (`dec_count()`), so no typed decoding count is left to guard. The RSVP sentence's typed "exactly one" is now guarded by `rsvp_one_guard()`, which checks the census's minimum and maximum onset counts.

### G16-11. Typed accuracy claims ('held or grew', 'improving') contradict the credibly negative DOM gram × session estimate

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:3110`, `paper_1_transfer/paper_1_morphosyntax.qmd:2668`
- **What goes wrong:** A reader takes 'held or grew' as covering all three properties. For differential object marking the modelled grammaticality effect declined credibly across sessions, so the inference drawn from the sentence (knowledge intact, decline only in level) is not what the artefacts show.
- **Evidence:** 3106-3112: "Overall accuracy fell across sessions for every property ... That the grammaticality effect held or grew while the level fell indicates that the decline reflects task difficulty or a drift in response criterion". At 2668-2669: "Discrimination is therefore present, and improving, where the level falls." In _pooled_posterior_summaries.csv, `accuracy_differential_object_marking` has `z_recoded_grammaticality ...
- **Fix:** Restrict the three statements to what the estimates show, and add the third site at qmd:2659-2660. Say that the grammaticality effect grew across sessions for gender agreement (report_effect("accuracy_gender_agreement", "z_recoded_grammaticality:z_recoded_session")), declined credibly for differential object marking (report_effect("accuracy_differential_object_marking", "z_recoded_grammaticality:z_recoded_session")), and did not change credibly for verb--object number agreement. In the Discussion (qmd:3110-3113), limit the 'task difficulty or response-criterion drift with knowledge intact' reading to gender agreement, or remove it, and note that the DOM decline in discrimination is consistent with forgetting.
- **Status:** resolved: the accuracy results were rewritten in signal-detection terms (e8c91a5, 2e89d05), and the claims are gone.

### G16-17. Dead code in setup chunk: .n_perm_used, retfree_val, gate_tbl, the 'commonsample' tag, a redundant ternary

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:516`, `paper_1_transfer/paper_1_morphosyntax.qmd:1054`, `paper_1_transfer/paper_1_morphosyntax.qmd:358`, `paper_1_transfer/paper_1_morphosyntax.qmd:295`, `paper_1_transfer/paper_1_morphosyntax.qmd:441`, `paper_1_transfer/paper_1_morphosyntax.qmd:1338`
- **What goes wrong:** The unused accessors and tag alternative suggest code paths (a common-sample ERP variant, a pooled permutation count, a gate table) that do not exist, and they would silently drift if revived.
- **Evidence:** Several objects in the setup chunk are never used. `.n_perm_used <- function() {` (516-520) has zero call sites (grep count 0). `retfree_val <- function(cell_id, which = "overall")` (1054-1057) appears only in the comment at 1050, never in inline R. `gate_tbl <- .read_csv_if(paper1_results("_training_gate_flow.csv"))` (358) is never read, and 2264-2267 says gate outcomes are not reported.
- **Fix:** In paper_1_morphosyntax.qmd: delete .n_perm_used (516-520), retfree_val (1054-1057) and the retfree_val clause of the comment at 1050-1051, and gate_tbl (358). Drop `commonsample` from the .mid() regex at 295 and from its comment at 291. Collapse line 441 to `digits = 1`. In fig-literature (1338-1340), use `.lit_tbl` in place of the second read. Confirm with a re-render that the PDF/HTML are unchanged. Separately, and not as a silent deletion: record in paper_1_transfer/README.md:18 that neither manuscript reads _training_gate_flow.csv (it is a descriptive audit artefact only), and leave keeping or retiring 00d's output to the author.
- **Also reported as:** X1-07
- **Status:** resolved: the dead code is removed, and `retfree_val()` is now used.

### X1-05. Result-changing env vars read by P1 decoding and P2 stages 06/07/08/09c/11 are absent from every README

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/hpc/README.md:157`, `paper_1_transfer/hpc/README.md:162-182`, `paper_2_plasticity/scripts/06_summaries.R:249`, `paper_2_plasticity/manuscript_setup.R:617`, `paper_1_transfer/scripts/09_run_decoding.R:112-146`
- **What goes wrong:** A reader reproducing Paper 2 from the READMEs cannot learn that the manuscript's direct-contrast sentence needs 06_summaries under LES_P2_DERIVED_CONTRASTS=1. The README's 'Re-run 06_summaries.slurm' recipe never produces it. A Paper 1 decoding sensitivity run under LES_DECODE_RIDGE, LES_DECODE_CLUSTER_ALPHA or LES_DECODE_TGM_STRIDE overwrites the reported *_decoding_*.csv at their reported names, because none of the ...
- **Evidence:** Both hpc READMEs open their switch tables with 'Every variant is opt-in through the environment' (P2 :159, P1 paper_1_transfer/hpc/README.md:164). A token inventory of every README, HPC_RUNBOOK.md and CODEBOOK found none of the following. Paper 2: LES_P2_DERIVED_CONTRASTS (06_summaries.R:249;
- **Fix:** Documentation only. (1) paper_2_plasticity/hpc/README.md switch table: add a row for LES_P2_DERIVED_CONTRASTS=1 (stage 3, `06`; writes the untagged new file _predictor_contrasts.csv, which manuscript_setup.R reads for the direct-contrast sentence and prints nothing without; no slurm exports it, so submit with --export=ALL,LES_P2_DERIVED_CONTRASTS=1). Add a row for LES_AP_FIT_MAX_HZ=&lt;Hz> (stage 4, `07`; tag _fit&lt;max>hz; the passband-only sensitivity the supplement mentions). Extend the 'Re-run 06_summaries.slurm' sentence to name the contrast switch.
- **Also reported as:** X4-15
- **Status:** partly resolved: Paper 2's switch table has rows for every result-changing switch (1533b4a, b2f67f0). Paper 1's decoding switches beyond `LES_DECODE_ANALYSES` and `LES_DECODE_CONFIRMATORY_ONLY` are documented only in the header of 08_decoding.slurm.

### X2-01. Vendored apaquarto says 5.0.18 in both papers, but each copy has different unmarked local patches

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/_extensions/wjschne/apaquarto/frontmatter.lua:370`, `paper_1_transfer/_extensions/wjschne/apaquarto/frontmatter.lua:366`, `paper_2_plasticity/_extensions/wjschne/apaquarto/title.tex:141`, `paper_1_transfer/_extensions/wjschne/apaquarto/_extension.yml:3`, `paper_2_plasticity/_extensions/wjschne/apaquarto/_extension.yml:3`, `AUTHOR_TASKS.txt:539`
- **What goes wrong:** The two manuscripts are rendered by different code under the same declared extension version, so the author-note and CRediT paragraphs are built differently: Paper 1 uses bold names from the patched frontmatter.lua and the stock title.tex template, Paper 2 uses different role parsing and a different LaTeX CRediT block.
- **Evidence:** Both paper_1_transfer/_extensions/wjschne/apaquarto/_extension.yml:3 and paper_2_plasticity/_extensions/wjschne/apaquarto/_extension.yml:3 read `version: 5.0.18`. Yet `git diff --no-index` of the two trees differs in 2 files: frontmatter.lua (35 changed lines, hunk @@ -367,23 +367,36 @@. Paper 2 adds `local role_name_meta = nil ...
- **Fix:** 1. Add a `-- LOCAL PATCH (2026-09-07), not upstream apaquarto 5.0.18` Lua comment block, with its rationale, above the patched hunks of frontmatter.lua in both papers. Cover the Strong author name, the separate role-introduction paragraph and the stringified correspondence note in both copies, plus the role_name_meta/degree_meta parsing in Paper 2 only. 2. Do not put a `%` comment into title.tex:141. Either record that patch in a note only, or add a pandoc `$--` comment on its own line before `$if(suppress-author-note)$` (title.tex:~137). 3. List every modified file against upstream 5.0.18 in one place, per paper: apafloatlatex.lua and frontmatter.lua, plus title.tex for Paper 2.
- **Status:** resolved 2026-10-26: both papers' vendored `frontmatter.lua` now carry a `LOCAL PATCH (2026-09-07; ISSUES.md X2-01)` comment above the bold CRediT names with the separate role-introduction paragraph, and above the stringified correspondence note, and Paper 2's comment names its role/degree parsing. The Paper 1 README says the copies differ (470c446), and both copies of `apafloatlatex.lua` already carried their LOCAL PATCH marks (2026-09-04 and 2026-09-18). Paper 2's patched `title.tex` (around line 141, the CRediT block) is recorded here and not in the file, since a `%` comment there would reach the LaTeX. Modified against upstream 5.0.18: Paper 1, `apafloatlatex.lua` and `frontmatter.lua`; Paper 2, those two and `title.tex`. Comments only, so no rendered output changes.

### X2-02. Render environment recorded only in prose, without package or toolchain versions, though figures and tables are computed at render time

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/README.md:183`, `README.md:56`, `paper_1_transfer/paper_1_morphosyntax.qmd:2546`, `paper_1_transfer/paper_1_morphosyntax.qmd:3587`, `paper_2_plasticity/README.md:149`
- **What goes wrong:** A later render on an updated box (a new ggplot2, mgcv, depictr, papaja, pandoc or TeX Live) can change the topography interpolation, figure appearance, number formatting or LaTeX layout of the submitted manuscripts. No record would show which versions produced the submitted PDFs. A reader following README.md:60 would wrongly conclude that render-side versions cannot affect reported output.
- **Evidence:** paper_1_transfer/README.md:183-199 is the only render-side record (paper_2_plasticity/README.md:149-150 defers to it). It gives versions for R 4.6.1, Quarto 1.10.18, knitr 1.51 and the Stan stack, all of which match this box. But it lists `rmarkdown, knitr, here, dplyr, ggplot2, papaja, tinytex, pdftools, plus depictr` with no versions, records no apaquarto version (5.0.18, locally patched), and no pandoc or TeX vers ...
- **Fix:** 1. Documentation, now: extend paper_1_transfer/README.md:183-199 with the render-box versions of every package the qmd files and manuscript_setup.R load (ggplot2, dplyr, papaja, depictr, mgcv, brms, knitr, rmarkdown, here, tinytex), plus pandoc (`quarto pandoc --version`), the TinyTeX/TeX Live release and the vendored apaquarto 5.0.18 with its local patches. 2. Rewrite README.md:60-61 to say that the result CSVs are not produced at render time, but the figures (including the render-time mgcv interpolation of the topography map), the prior table and the number formatting are, so render-side versions can change the rendered output. 3.
- **Status:** partly resolved: the render machine's package, Quarto, pandoc and TeX Live versions are recorded in paper_1_transfer/README.md (470c446). Recording them with each render remains open.

### X2-03. No job checks the loaded library against renv.lock; unpinned installers write the library the restore fills

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/04_provenance.R:41`, `_shared/hpc/arc_env.sh:58`, `_shared/hpc/00_restore_environment.slurm:57`, `_shared/install_bayesian_dependencies.R:100`, `paper_2_plasticity/hpc/install_eegutils.slurm:34`, `paper_1_transfer/scripts/_config.R:269`
- **What goes wrong:** The bootstrap job or install_eegutils.slurm is run after a restore (the eegUtils job is documented as 'Use this script when 00 has already run'). Or a dependency is installed or upgraded in $LES_RLIB for any other reason. Later extraction or fitting jobs then run against a library that no longer matches renv.lock, and nothing notices.
- **Evidence:** arc_env.sh:57-58 `export LES_RLIB="${LES_BASE}/Rlib/R-4.5"` / `export R_LIBS_USER="${LES_RLIB}"` is the one library every job reads. It is also where 00_restore_environment.slurm:57 (`renv::restore(lockfile = "renv.lock", library = .libPaths(), prompt = FALSE)`) restores and where the unpinned routes install: install_bayesian_dependencies.R:45 ('packages into .libPaths()[1] (R_LIBS_USER on the cluster)'), with :100 ` ...
- **Fix:** 1. Add a shared helper, for example les_check_lockfile() in 04_provenance.R. It reads renv.lock with jsonlite when the file is present beside LES_CODE_ROOT and compares utils::packageVersion() for the lockfile's packages, or at least those the stage loads. It writes the mismatch count and list into the fitmeta and provenance records. 2. Make it stop only under an opt-in switch (for example LES_REQUIRE_LOCKFILE=1), and warn loudly when renv.lock is absent. Deploy renv.lock with the code if the gate is to be enforced. 3. Call it from the fitting and extraction stages, and add readxl, data.table, tidyr, readr and stringr (or a per-stage package list) to the recorded versions. 4.
- **Status:** partly resolved: `les_check_lockfile()` records whether a lockfile was found (9c5c273). The cluster copy has no renv.lock, and the arc_env.sh change waits until the decoding run ends.

### X2-04. LES_REQUIRE_CMDSTANR is exported by no job, so a missing cmdstanr silently switches fits to rstan without threading

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/01_bayesian_settings.R:37`, `_shared/R/01_bayesian_settings.R:27`, `_shared/R/01_bayesian_settings.R:299`, `paper_1_transfer/hpc/03_fit_erp.slurm:72`, `paper_2_plasticity/hpc/04_fit_predictors.slurm:33`, `paper_1_transfer/scripts/_config.R:270`
- **What goes wrong:** The library lacks cmdstanr or it fails to load: the bootstrap installer treats cmdstanr as optional (install_bayesian_dependencies.R:111 'brms falls back to the rstan backend'), or a partial restore leaves it out. Every fitting job then samples through rstan 2.32.7 without reduce_sum threading and writes results that differ from the reported draws.
- **Evidence:** 01_bayesian_settings.R:37 `.les_backend <- if (requireNamespace("cmdstanr", quietly = TRUE)) "cmdstanr" else "rstan"`. Lines 38-40 say 'a refit under the other backend does not reproduce the reported draws. LES_REQUIRE_CMDSTANR=1, which a fitting job script can export, makes a missing cmdstanr stop the run here'.
- **Fix:** 1. Add `export LES_REQUIRE_CMDSTANR="${LES_REQUIRE_CMDSTANR:-1}"` to _shared/hpc/arc_env.sh. This covers every fitting job in both papers, and a deliberate rstan run can still override it. 2. Record the backend actually used: add `backend = .les_backend` to les_p1_write_fit_meta and les_p2_write_fit_meta (with an exists() guard), and add a 'backend' row via les_write_provenance's `extra`. First confirm that the 06 pooling step binds records with differing columns safely. 3. Rewrite the header comment at 01_bayesian_settings.R:27-28 to say that the rstan fallback runs without reduce_sum threading and does not reproduce the reported draws, matching :38-40. Step 3 alone is a comment change, but the job-environment and record changes need sign-off.
- **Status:** resolved 2026-10-26: `_shared/hpc/arc_env.sh` now exports `LES_REQUIRE_CMDSTANR=1` unless a job sets it, so a cluster job without cmdstanr stops instead of sampling through rstan; the record and comment parts were done in 9c5c273. It reaches the cluster with the next deployment and changes no reported fit, all of which sampled through cmdstanr.

### X3-01. Figure S1 jitter is unseeded and moves points vertically: digit span by up to 0.4, IAF floor values below 7 Hz

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/supplement.qmd:336`
- **What goes wrong:** Every Quarto render of the supplement draws Figure S1 with different point positions, so two renders of the same commit never match. In addition, each render moves the integer digit-span scores up to 0.4 items off their true values and scatters the 7 Hz floor IAF points below the search floor, which contradicts the figure note.
- **Evidence:** supplement.qmd:334-337: `ggplot(pred_vals, aes(x = "", y = value)) + geom_violin(...) + geom_jitter(width = 0.12, size = 0.5, alpha = 0.5, colour = "grey25") + geom_boxplot(...)`. No `height` and no `seed` are given. A grep for `cache:|freeze:|knitr::opts_chunk|seed` over supplement.qmd, _quarto.yml and manuscript_setup.R matches only prose at supplement.qmd:294, so nothing seeds the render.
- **Fix:** At supplement.qmd:336, replace the layer with `geom_point(position = position_jitter(width = 0.12, height = 0, seed = 20260607L), size = 0.5, alpha = 0.5, colour = "grey25")`. Add a WHY-comment that `height = 0` keeps integer digit-span scores and the 7 Hz IAF floor at their true values, and that the fixed seed (the project's LES_SEED, written as a literal because the supplement does not source 01_bayesian_settings.R) makes the horizontal spread identical on every render. Do not source 01_bayesian_settings.R for this. Re-rendering the supplement afterwards needs author sign-off.
- **Status:** resolved: the jitter is seeded and vertical only, so each point shows its exact value (verified 4 October 2026).

### X3-02. 08 registers a PSOCK/doParallel backend for run_cvfun's refits, but brms 2.23.0 kfold uses future.apply

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/08_projpred_selection.R:269`, `paper_2_plasticity/scripts/08_projpred_selection.R:133`, `paper_2_plasticity/scripts/08_projpred_selection.R:157`, `paper_2_plasticity/scripts/08_projpred_selection.R:292`, `paper_2_plasticity/hpc/08_projpred.slurm:15`, `paper_2_plasticity/hpc/08_projpred.slurm:42`
- **What goes wrong:** The job starts 6 or 8 idle PSOCK R workers and sizes its memory for them (08_projpred.slurm:42-46: "each PSOCK worker carries a full copy"). A maintainer who believes the refits run in parallel over foreach could add doRNG or reseed the workers to 'fix' reproducibility, which would have no effect. Or they could remove mc.cores, thinking PSOCK does the work, and quadruple the refit time.
- **Evidence:** 08:269-275 `if (.les_want_parallel) { .les_cl <- parallel::makeCluster(.les_projpred_cores); doParallel::registerDoParallel(.les_cl); options(mc.cores = .les_projpred_cores) ...}`. The comment at 08:263-264 says the refits parallelise "through mc.cores/mclapply and/or the foreach backend", and 08:133 says "doParallel (with foreach) backs the K brms::kfold refits inside run_cvfun".
- **Fix:** 1. In 08_projpred_selection.R, delete the makeCluster/registerDoParallel block (269-275) and its teardown (292-296), and drop the foreach/doParallel conditions from .les_want_parallel, or remove the gate. 2. Keep `options(mc.cores = .les_projpred_cores)` around run_cvfun, reset to 1L afterwards. Add a WHY-comment that update() and brm() take chain cores from mc.cores, and that sequential futures preserve that option. 3. Rewrite the comments at 133-139, 157-158, 261-268 and 287-291 to say what actually happens. brms 2.23.0's kfold dispatches folds through future.apply::future_lapply with future.seed = TRUE. With no future::plan the folds run one after another.
- **Status:** resolved in 2352752: PSOCK/doParallel block, teardown and gate removed. The brms 2.23.0 source confirms `.kfold` uses `future_lapply` (sequential with no plan), so the workers were idle. mc.cores is kept around run_cvfun (6 chains, as the logs show) and reset to 1 for cv_varsel. Comments in 08 and both slurms rewritten.

### X4-01. Paper 1's 'run in order' table puts steps 0 and 0b before the step-2 and Paper 2 outputs they read

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/README.md:15`, `paper_1_transfer/scripts/README.md:56`, `paper_1_transfer/hpc/submit_all.sh:13`
- **What goes wrong:** On a fresh clone (data_derived/ is gitignored), a reproducer follows the authoritative table and runs 00 and 00b first. The accuracy and Paper 2 files are absent, so the usable-accuracy, battery, trajectory and rs-EEG stages are skipped (the file.exists branches at 00:214, 223, 249).
- **Evidence:** paper_1_transfer/README.md:10 '## Pipeline (`scripts/`, run in order)' lists step 0 (line 15) and 0b (line 16) before step 2 (line 21, which writes the accuracy .rds). paper_1_transfer/scripts/README.md:5 calls that table 'the authority', :56 says 'Run the local stages in numerical order', and submit_all.sh:13 repeats that it is the authority.
- **Fix:** Documentation only. (1) In paper_1_transfer/README.md, move rows 0 and 0b below row 2, or add a 'Needs' column: 0 needs 02's accuracy_*.rds, Paper 2's 01-03 derived .rds and data/EEG_trial_count_per_condition.csv; 0b needs the same plus step 0's _sample_flow.csv. Mark both as run where both papers' data_derived/ exist (the store), not purely 'local'. (2) Replace 'Run the local stages in numerical order' at scripts/README.md:56 with the dependency order, and cross-reference hpc/00_descriptives.slurm. (3) In submit_all.sh:17, give 00 and 00b their prerequisites ('after 02, and after Paper 2's 01-03'). (4) State the cross-paper dependency once in paper_2_plasticity/results/README.md:17-21, where the six shared files are described.
- **Status:** resolved in 1533b4a: the pipeline table says it is in script order and when steps 0 and 0b run, and both job headers agree.

### X4-03. The runbook's generic prior-sensitivity recipe omits LES_PROVENANCE_SKIP=1, so following it overwrites _provenance.csv

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `HPC_RUNBOOK.md:157`, `paper_1_transfer/README.md:96`, `paper_1_transfer/README.md:99`, `paper_1_transfer/figures/README.md:27`
- **What goes wrong:** A user copies the runbook line onto 04_fit_predictors.slurm or 03_fit_erp.slurm. results/_provenance.csv is replaced by the weak-prior run's record, and after the next pull-back and render the manuscript reports the sensitivity run's date and environment as those of the reported fits.
- **Evidence:** HPC_RUNBOOK.md:156-158: 'Prior-sensitivity run ... submit with `--export=ALL,LES_PRIOR_SET=weak` (e.g. `sbatch --export=ALL,LES_PRIOR_SET=weak …`); cached fits are tagged `*_weakprior*` so the two runs never clash.' Both fitting scripts rewrite the untagged run-level record unless it is skipped: 03_fit_brms_erp.R:324 `if (!identical(Sys.getenv("LES_PROVENANCE_SKIP"), "1")) { try(les_write_provenance(...` and 04_fit_b ...
- **Fix:** Documentation only. Add LES_PROVENANCE_SKIP=1 to the export list in HPC_RUNBOOK.md:157, paper_1_transfer/README.md:96 and :99, and paper_1_transfer/figures/README.md:27. For example: `sbatch --export=ALL,LES_PRIOR_SET=weak,LES_PROVENANCE_SKIP=1 paper_1_transfer/hpc/03_fit_erp.slurm`. At the runbook line, add one sentence pointing to each paper's hpc/README 'Analysis-variant switches' table as the authority, and say that stage 03 (Paper 1) and stages 04 and 09 (Paper 2) rewrite results/_provenance.csv. Optionally extend paper_1_transfer/hpc/README.md:180 to note that a LES_PRIOR_PREDICTIVE=1 run refits or reloads and so also needs the guard.
- **Status:** resolved in 5b50d49: The HPC_RUNBOOK prior-sensitivity paragraph now carries `LES_PROVENANCE_SKIP=1`, names the stages that rewrite `_provenance.csv` (P1 03, P2 04; P2's 09 job sets the skip itself) and points to the variant tables. `paper_1_transfer/README.md` already had it. `figures/README.md:27` needs patch #3.

### X4-04. No CHANGELOG; result-changing decisions are scattered across working logs, some untracked or unnamed

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `README.md:18`
- **What goes wrong:** A reader or reviewer comparing a pulled Paper 2 table after the queued Stroop refit with the submitted draft, or a Paper 1 decoding CSV at n_perm 200 with one at 1000, has no dated, versioned entry saying which change moved which numbers or why. The only traces sit in to-do logs that are rewritten or left untracked.
- **Evidence:** git ls-files lists no CHANGELOG/NEWS file (a search for change|news|history matched only legacy data/ files). README.md:18-19 lists two working logs (METHODS_FIGURES_AUDIT_2026-07.md, POLISH_FLAGGED_2026-08.md) as its only record of change. The decisions that change reported results are found only piecemeal: the Stroop test-block rescore in AUTHOR_TASKS.txt:401-403 ('DECIDED 11 September');
- **Fix:** Add a root CHANGELOG.md in Keep a Changelog form, link it from the README.md table, and write dated entries whose rationale comes from the existing logs. Cover at least: the confirmatory decoding FDR family (decided 2026-07-23, switch LES_DECODE_CONFIRMATORY='overall'); B raised to 1000 (2026-08-06; gender's exploratory blocks still pending); the maximal random-effects structure made primary (2026-08-08); the mis-filtered Session-3 exclusion and removal of _exclusions.csv; the prior sets and LES_PRIOR_SET; the Stroop test-block rescore (decided 2026-09-11, uncommitted, refit pending); the dropped start_ms/end_ms in the home task-duration table (2026-09-10); and the relabelling of the ERP covariate as L1 dominance (2026-09-03). List the affected artefacts for each entry.
- **Status:** resolved in 5b50d49: Rewrote `CHANGELOG.md`'s stale `[Unreleased]` ("not yet committed", 10 and 11 September). The infrastructure changes it then listed under `[Unreleased]` were committed in 5b50d49 itself, and since 8 October 2026 they sit under 2026-10-03, citing that commit.

### X5-02. No raw input is checksummed or versioned; provenance records software only; the cluster data copy is never verified

- **Severity:** MAJOR (reported as BLOCKING), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/03_data_manifest.R:18`
- **What goes wrong:** Any input changes, on the cluster store or through a re-export or hand edit (LHQ3 regeneration, participant-key edits, a re-saved log). Extraction then runs, the fits converge, and the manuscripts report plausible numbers from different data. No artefact can show which version of the inputs a result came from. The LHQ3 column shift is a concrete case.
- **Evidence:** Searching the live surface for md5sum|digest::|sha256|checksum finds only _shared/hpc/deploy_to_cluster.sh:191-197 (code files) and 08_extract_decoding_matrices.R:487 `built$x_digest <- digest::digest(built$X)` (a derived tensor). 03_data_manifest.R:18-24 states a read-only contract but records no content identity. 04_provenance.R:56-88 writes R, platform, packages, CmdStan, `seed:` rows and `extra`;
- **Fix:** 1) Derive the manifest from the git-tracked data, not a hand-built schema. Once per data commit, the author writes a tracked file outside data/ (e.g. _shared/data_manifest/inputs.tsv) listing path, bytes and SHA-256 of the LF-normalised content for the files live code reads. Also record the data tree ID (`git rev-parse HEAD:data`) so any reported result can name its input version. 2) Add one verification job, _shared/hpc/00_verify_data.slurm, run after every data sync. It hashes `$LES_DATA_ROOT` against the manifest the same way and exits non-zero on any mismatch or missing file. Gate each submit_all.sh chain on it with afterok. Do not rehash about 8,100 EEG exports inside every extraction script.
- **Status:** resolved (22 October 2026). `_shared/data_manifest/inputs.tsv` is committed: 8,369 files, data tree 0750de4, at e9a7c09. `_shared/hpc/00_verify_data.slurm` checks the cluster's copy against it. Its first run (HTC 9149414) found:
  - every export, log, behavioural file and questionnaire identical (7,776 files);
  - 545 Analyzer history files (.ehst2, .hfinf2) differing, and 48 grand-average history files missing.

  Five of the differing files were compared: the .ehst2 files stream by stream, the text .hfinf2 line by line. Four differ only in machine-specific metadata: the stored path of the raw file, the user and the computer, written when the RA's workspace was last opened. The fifth, S6/5's history, also carries the labels of three per-participant average nodes. No script reads any of these.

  The missing files are read by nothing. The cluster's copies are kept, because the reprocessing's provenance records hash them.

### X5-03. Session-4 logs of participants 3 and 5 were re-saved by hand, not 'exported' semicolon-delimited; no original kept

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/02_extract_accuracy.R:56`
- **What goes wrong:** The committed raw inputs are hand-modified files presented as instrument exports. A reader cannot tell whether other cells changed in the re-save, and the G06-04 remedy (sniff the delimiter) would bring into the models data of unknown provenance. The originals are not archived or checksummed, so a later re-export could differ without anyone noticing.
- **Evidence:** 02_extract_accuracy.R:56-57 `Two Session-4 logs (participants 3 and 5) were exported with a semicolon delimiter`. Read-only fread of new_LESS Session 4 logs: subject-3.csv and subject-5.csv have sep ';', and `opensesame_version` reads '03.03.2014'. subject-7.csv (comma) and every other lab log read '3.3.14' (sweep: 'Session 4 | 03.03.2014 :: Norway_Session_4.osexp | 2 files'). OpenSesame writes 3.3.14;
- **Fix:** (1) Change the wording at 02_extract_accuracy.R:56-57 and :187, 00d:72, 01b:63 and :124, and the 'semicolon_delimited' description in results/CODEBOOK.md to say the logs were re-saved by hand in a spreadsheet, not exported. Cite the evidence: the separator, the missing quoting, and opensesame_version shown as 03.03.2014. Also state that 01b already reads them. (2) Add a provenance note outside data/ with the two blob hashes. It should say that a full-file scan found no change besides the version field, and that the originals are not in the repository. (3) Ask the author to recover the original OpenSesame .csv files from the lab PC or OSF and archive them outside data/. Compare them cell by cell with the committed copies.
- **Status:** resolved in wording (aad57ed). For the author: a provenance note with the two blob hashes of the semicolon-delimited Session 4 logs (participants 3 and 5), and recovery of the originals.

### X5-04. Inputs produced outside the pipeline or edited by hand (trial counts, participant key, LHQ3 re-export) have no provenance

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/00c_extract_erp_retention.R:16`
- **What goes wrong:** The retention figures the Method prints (00c), the enrolled set and group mapping (key), and the demographics and covariates (LHQ3) all rest on files whose generation date, generating code version and manual edits are unrecorded. A regenerated trial-count table or a further key edit would change reported counts, and nothing would show when or why.
- **Evidence:** 00c:16-17 `script 'data/EEG data descriptives.R' has already reduced them to a per-cell trial-count table, 'data/EEG_trial_count_per_condition.csv'`, and :90 `Run the legacy 'data/EEG data descriptives.R' first to generate it.` That script (git HEAD) writes into data/ itself (`write.csv(EEG_trial_count, 'data/EEG_trial_count_per_condition.csv'`), counts `n_trials = n_distinct(sentence_marker)`, and no job runs it.
- **Fix:** Documentation only, outside data/: a provenance note with one entry per input and its current git blob hash. Record: (a) that repository history begins at root commit c4222a7 (2026-07-03) and anything earlier is unrecorded; (b) that EEG_trial_count_per_condition.csv was produced by data/EEG data descriptives.R through merge_trialbytrial_EEG_data.R, with the date and version if the author knows them; (c) that an earlier (2025-03-24) copy of the participant key differs from the committed one in 19 rows, including participant_lab_ID and language in 3 rows, and the author should state what those edits were; (d) the LHQ3 export date, confirmed by the author and not inferred from file modification times.
- **Status:** partly resolved: the retention descriptives are counted from the analysed data (aad57ed; rerun HTC 8976030, pulled in 2e89d05). A provenance note for the participant key and the LHQ3 export needs the author's dates.

### X5-05. Pull-back recipe copies every CSV from the mutable cluster store and records nothing about what or when

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `HPC_RUNBOOK.md:170`
- **What goes wrong:** The store keeps artefacts from superseded runs, such as the pre-rescore Stroop outputs (settled item 2) and variant-tagged files. A glob pull overwrites results/ with whatever mix is there on the day. Once committed, results cannot be traced to the store contents or the jobs behind them. This is distinct from G11-02 and G13-17, which concern pooling inside the pipeline, not the transfer step.
- **Evidence:** HPC_RUNBOOK.md:170-171 `scp "arc:/data/educ-intract/educ1242/new_LESS/store/paper_1_transfer/results/*.csv" paper_1_transfer/results/` (the same for paper_2). :178 `paper_1_transfer/results/ and paper_2_plasticity/results/ are the only trees the manuscripts read.` No script or file records the pull time, the state of the store, per-file hashes or the job that wrote each file.
- **Fix:** Add a pull script under _shared/hpc/ modelled on deploy_to_cluster.sh:191-197. It copies the same *.csv set the recipe pulls, not a hand-kept subset. Before copying it records, for every store file, the sha256 on the cluster, the cluster mtime (UTC) and the store path. After copying it checks the hashes locally. It writes a manifest (file, sha256, cluster_mtime_utc, pulled_utc, store_path, and job_id where _provenance.csv or the logs give it) alongside results/ or in a _pulls/ directory, so that no manuscript reads it. It reports, without deleting, local results files that are absent from the store (such as _exclusions.csv) and store files older than their upstream inputs. Update HPC_RUNBOOK.md:170-171, AUTHOR_TASKS.txt:531 and paper_2_plasticity/hpc/README.md:188 to call the script.
- **Status:** resolved in 5b50d49: New `_shared/hpc/pull_results.sh`. By default it only reports, comparing by git blob id so CRLF in the checkout does not matter. With `LES_PULL_APPLY=1` it copies the changed files, or the files named; files that exist only in the store are copied only when named.

### X6-02. Probability of direction prints as a proportion in Paper 1 but a percentage in Paper 2, despite 'one set of rules'

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/manuscript_setup.R:562`, `paper_1_transfer/paper_1_morphosyntax.qmd:864`, `paper_1_transfer/paper_1_morphosyntax.qmd:885`, `paper_2_plasticity/manuscript_setup.R:571`, `paper_2_plasticity/manuscript_setup.R:581`, `_shared/R/02_diagnostics.R:5`
- **What goes wrong:** A reader of the two companion papers sees the same index as '$p_d = .96$' in one and '$p_d = 95.7\%$' in the other, with the same citations (makowski2019, kruschke2018). That is exactly the misreading of borderline values Paper 1's comment says the single format was introduced to prevent.
- **Evidence:** Paper 1 (paper_1_morphosyntax.qmd:858-863): "pd is bounded by 1 like a p value, so the leading zero is dropped (APA 7) and it is reported as a proportion everywhere ... It previously appeared as a percentage in some places and a proportion in others, which invited misreading of borderline values". Its .fmt_pd (:864-870) prints ".95" or "> .999", and report_effect (:885-887) emits "$p_d = .95$".
- **Fix:** With author sign-off, adopt Paper 1's documented proportion rule in Paper 2. Either move .fmt_pd and .pd_math from paper_1_morphosyntax.qmd:864-876 into _shared/R/06_manuscript_helpers.R, rewording that file's 'byte-identical' header, or have Paper 2 define the same rule. Then: (1) In manuscript_setup.R, make report_effect emit "$%s$" with .pd_math(row$pd), delete .fmt_pd_pct, have pd_of return .fmt_pd(row$pd), and fix the comment at :556. (2) Delete the trailing literal % after the six pd_of calls at paper_2_neuroplasticity.qmd:1318, 1319, 1501, 1502, 1505 and 1506. (3) Optionally route sens_max_rate_pd (:516) through .fmt_pd so the three-decimal rule near 1 also applies there. Re-render both documents and diff the text. Only the pd strings in Paper 2 should change.
- **Status:** resolved 17 October 2026: Paper 2 adopts Paper 1's proportion format; .fmt_pd() and .pd_math() now live in _shared/R/06_manuscript_helpers.R for both papers, Paper 2's report_effect(), pd_of() and sens_max_rate_pd() call them, .fmt_pd_pct() is gone, and the six literal % signs after pd_of() are removed.

### X6-04. Per-fit pooling and the draw summariser are rewritten in Paper 2's 06, and its pooled tables lack Paper 1's variant columns

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/06_summaries.R:54`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:88`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:113`, `paper_2_plasticity/scripts/06_summaries.R:121`, `paper_2_plasticity/scripts/06_summaries.R:258`, `_shared/R/02_diagnostics.R:85`
- **What goes wrong:** The interval level or pd definition is changed in les_posterior_summary(), for example to add a ci argument or handle ties, or a new variant tag gets classified in Paper 1's pooling. Paper 2's contrasts, attainment and pooled tables keep the old rule without error, so the two papers' pooled CSVs, which the manuscripts read, stop being comparable.
- **Evidence:** Paper 1's pool_artefacts (05_posterior_summaries_and_contrasts.R:88-140) and Paper 2's (06_summaries.R:54-101) are near-identical. Both use a radix-sorted list.files over _convergence/_summary/_fitmeta .rds, take the model id from the file name, and write the same _pooled_convergence.csv, _pooled_posterior_summaries.csv and _pooled_fit_metadata.csv.
- **Fix:** Minimal fix: add les_summarise_draws(x, ci = 0.95), returning median, ci_low, ci_high and pd, to _shared/R/02_diagnostics.R, and make les_posterior_summary() call it for each b_ column. Replace P1 .les_summarise_draws (05:77-85) and P2 06:258-265 with that function. For attainment (06:121-123), take only its median and interval columns so _attainment.csv keeps its current schema. Optionally, move pool_artefacts into a shared les_pool_fit_artefacts(results_fn, exclude = NULL, classify = NULL). Paper 2 would pass exclude = '_projpred_summary\\.rds$' and classify = NULL, so its pooled CSVs stay byte-identical, and Paper 1 would pass its tag classifier. Do not add prior_variant to Paper 2's tables without sign-off, since no consumer needs it.
- **Status:** partly resolved: the shared `les_summarise_draw_vector()` exists (9c5c273). Adopting it in Paper 2's 06 waited for the queued 06 job (HTC 8976041), which ran on 4 October and whose tables were pulled on 7 October, so 06 can adopt it now. The output should not change, which a rerun that reproduces those tables byte for byte would confirm.

### X6-05. Participant key is read by six separate readers with different 'enrolled' rules; language also comes from ID parity

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/03_data_manifest.R:49`, `paper_1_transfer/scripts/00_extract_participants.R:153`, `paper_1_transfer/scripts/02_extract_accuracy.R:147`, `paper_1_transfer/scripts/02_extract_accuracy.R:280`, `paper_1_transfer/scripts/00b_audit_participant_flow.R:37`, `_shared/R/07_task_durations.R:80`
- **What goes wrong:** Suppose the key gains a row with home and lab IDs but a blank language, for example a withdrawn or pilot participant. 00 and 02 exclude that person, but P2 01 writes them into cognitive_indices.rds, 11 includes their trials, and 07 adds them to both duration tables. The Paper 2 standardisation frame and the duration figures then silently cover a different sample from the flow counts.
- **Evidence:** participant_key_csv() (03_data_manifest.R:49) returns only a path, so each script parses and filters the key itself: - 00_extract_participants.R:153-155: readr, then `filter(language %in% c("Mini-English", "Mini-Norwegian"))`. - 02_extract_accuracy.R:147-154: readr, the same language filter, and a duplicate-lab-ID stop.
- **Fix:** Add les_participant_key(enrolled_only = TRUE) to _shared/R/03_data_manifest.R. It should: - read the key once with readr; - drop rows where every ID field is blank; - cast participant_lab_ID to integer and participant_home_ID to character; - stop() on duplicate lab or home IDs, on a row with a lab ID but no mini-language (or the reverse), and on any parity mismatch, so the parity assumption in 02_extract_accuracy.R:279-280 becomes a hard check; - with enrolled_only = TRUE, return rows whose language is Mini-English or Mini-Norwegian. Use it in 00 (:153-155), 02 (:147-149), 07 (:80-95, keeping the git-show fallback), P2 01 (:230-234) and P2 11 (:188-191). In 02, either keep parity behind the new assertion or join mini_language from the key with an anti-join stop for unmatched lab IDs.
- **Status:** resolved in the shared key reader (9c5c273). Other readers still read the key directly.

### X6-06. Paper 1's flow scripts re-type Paper 2's index names, band list, baseline session and condition test

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/00_extract_participants.R:217`, `paper_1_transfer/scripts/00_extract_participants.R:253`, `paper_1_transfer/scripts/00_extract_participants.R:257`, `paper_1_transfer/scripts/00b_audit_participant_flow.R:89`, `paper_1_transfer/scripts/00b_audit_participant_flow.R:104`, `paper_2_plasticity/manuscript_setup.R:34`
- **What goes wrong:** Paper 2 renames or extends an index or measure in _config.R, as its comment invites, or 03 starts writing a second resting session. 00's intersect() silently drops the renamed column, or counts the extra session, so the battery_baseline, joint_predictor and usable_rseeg counts in _sample_flow.csv, and the flow figure and prose in both manuscripts, stop matching the samples 04 fits.
- **Evidence:** The flow artefact's Paper 2 stages (battery_baseline, joint_predictor, usable_rseeg), which both manuscripts inject, are computed in Paper 1's scripts from literals instead of Paper 2's configuration. - 00_extract_participants.R:217-218: `ci1 <- ci[ci$session %in% 1, ]` and `idx <- intersect(c("stroop_interference", "digit_span", "asrt_learning"), names(ci1))`.
- **Fix:** In 00_extract_participants.R and 00b_audit_participant_flow.R, source paper_2_plasticity/scripts/_config.R (its guarded sources of 00_paths.R and the manifest are idempotent). Alternatively, move LES_P2_COG_INDICES, LES_P2_RS_MEASURES and the baseline sessions into _shared/R/03_data_manifest.R and have _config.R reuse them. Then replace the literals: - idx &lt;- intersect(unname(LES_P2_COG_INDICES), names(ci1)), with the session test on LES_P2_COG_SESSIONS[1]. - rs filtered by session == LES_P2_NEURAL_SESSIONS[1] & condition == "eyes_closed". - bnd &lt;- LES_P2_RS_MEASURES. Add a stop() when any expected column is missing, not a silent intersect(). In manuscript_setup.R:34, use unname(LES_P2_COG_INDICES[c("digit_span","stroop","asrt")]), and likewise stop or warn on missing columns.
- **Status:** resolved in aad57ed: 00 sources `paper_2_plasticity/scripts/_config.R` and uses `LES_P2_COG_INDICES`, `LES_P2_COG_SESSIONS[1]`, `LES_P2_NEURAL_SESSIONS[1]`, `condition == "eyes_closed"` and `LES_P2_RS_MEASURES`, stopping on missing columns. ARC: battery 62, trajectory 63, joint 61, rs 56; old and new criteria give identical results.

### X6-07. Property display labels are re-typed in both manuscripts despite the manifest's single source; Paper 1 has two short forms

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/paper_2_neuroplasticity.qmd:992`, `paper_1_transfer/paper_1_morphosyntax.qmd:968`, `paper_1_transfer/paper_1_morphosyntax.qmd:3712`, `_shared/R/03_data_manifest.R:96`
- **What goes wrong:** A property label, or the order, is revised in the manifest, for example after a copy-edit of the en-dash form. Paper 2's accuracy-trajectory figure and Paper 1's retention and convergence appendix tables keep the old strings. Readers already see 'Number agreement' in one Paper 1 table and 'Number agr.' in another for verb-object number agreement.
- **Evidence:** 03_data_manifest.R:96-101 declares "Property display labels (single source of the order and the wording) ... Every figure, table and list in both manuscripts follows this order", and Paper 1's qmd:469-471 repeats that the manifest "is the single source of the property order for both manuscripts".
- **Fix:** 1. Add LES_PROPERTY_LABELS_SHORT, keyed by names(LES_PROPERTY_CODES), to 03_data_manifest.R, and extend its header comment to list a fourth form. 2. In paper_2_neuroplasticity.qmd:992-996, use .prop_order &lt;- names(LES_PROPERTY_LABELS) and prop_lab &lt;- as_labeller(LES_PROPERTY_LABELS). The figure output is unchanged. 3. In paper_1_morphosyntax.qmd, build pmap (:968) and .propmap (:3712) from LES_PROPERTY_LABELS_SHORT, keeping the factor levels in manifest order. 4. With author sign-off, pick one short form for verb-object number agreement. Check that the convergence table still fits its 15% Property column if "Number agreement" is chosen. Make the two apa-notes (:3503 and :3681) match the chosen cells; ideally build their abbreviation sentence from the same vector.
- **Status:** resolved: both manuscripts now take the property labels from the manifest (LES_PROPERTY_LABELS_TABLE and the data's own labels), and no label is typed in either; checked 17 October 2026.

### X7-01. Paper 1's prior-predictive figure is a July image the current generator cannot redraw; caption and README describe it inconsistently

- **Severity:** MAJOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/figures/prior_predictive_check.png:1`
- **What goes wrong:** A rerun of the documented recipe (figures/README.md:26-31, LES_PRIOR_PREDICTIVE=1 plus LES_P1_PRIORPC_REPRESENTATIVE) replaces the manuscript figure with a clipped (-8 to 8 SD), labelled, untitled panel. The caption rendered next to it would then describe an axis range the figure no longer has.
- **Evidence:** The blob is identical at every ref: `git rev-parse c4222a7:…/prior_predictive_check.png HEAD:… remotes/paper1/main:…` all return 02bae3ca54a628fb73455e3bf9675685c72edb07. `git log` gives the file's last change as c4222a7 (2026-07-03). Viewed directly, the image has an in-image title "Prior predictive check", an x-axis from -150 to 150 and no axis labels.
- **Fix:** Documentation now, with author sign-off because the finding is HIGH-RISK. (1) Replace figures/README.md:21-24 with the provenance recorded in AUTHOR_TASKS 1.8: tag erp_gender_agreement_400_900_midline, base random-effect structure, informative priors. State that the PNG was drawn by the generator as it stood before 8685d30, with a full-range axis, an in-image title and no axis labels, so the current recipe would produce a different panel. (2) Add the same note to the chunk comment at paper_1_morphosyntax.qmd:2085, the comment only and not the caption. (3) In the README recipe, warn that 03:244 swallows errors from the prior-only fit and that 03:261-263 copies any existing _priorpc.png, so the PNG's mtime must be checked after a rerun.
- **Status:** resolved 17 October 2026: the committed figure is the panel the October rerun drew for erp_gender_agreement_400_900_midline_itemslope (checksum equal to the store's), and the figure note and figures/README.md now describe its axis, limited to 8 SD either side of zero. Superseded 26 October 2026: the figure is drawn at render time, in the house style, from `results/_prior_predictive_check.csv`, which `scripts/03b_export_prior_predictive.R` writes from the same prior-only model of the same cell, and the note takes its numbers from that run's record. The PNG left version control.


## MAJOR (28)
### G01-07. les_brm's default-prior branch is dead, and if used would silently ignore LES_PRIOR_SET

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `_shared/R/01_bayesian_settings.R:283`
- **What goes wrong:** A new caller omits `prior` and runs with LES_PRIOR_SET=weak. The fit uses informative priors but is cached as &lt;id>_weakprior.rds, so les_prior_sensitivity() reports a near-zero shift from comparing informative with informative. A Bernoulli model without z_recoded_session errors inside brms on the unused coefficient prior.
- **Evidence:** 01:283-290 `if (is.null(prior)) { prior <- switch(family$family, gaussian = les_priors_gaussian(), bernoulli = les_priors_bernoulli(), binomial = les_priors_bernoulli(), les_priors_gaussian()) }`. Every call site passes `prior` explicitly: 03_fit_brms_erp.R:274, 04_fit_brms_accuracy.R:118, 04_fit_brms_predictors.R:378, 05_fit_brms_prepost.R:94 and :185, 09b_compare_aperiodic_commonsample.R:86.
- **Fix:** Replace 01:283-290 with `if (is.null(prior)) stop("les_brm(): pass `prior` explicitly (les_erp_prior(), les_acc_prior() or a paper-specific set) so LES_PRIOR_SET and the cache tag stay consistent.", call. = FALSE)`. Do not route the default through les_erp_prior()/les_acc_prior(), since a silent default is the hazard. Reword 01:275-276 to say les_brm centralises chains, iterations, seed, control, backend, threading and caching, while priors are supplied per call by each paper. Deploy it with the pending ARC reconciliation, not mid-chain.
- **Status:** resolved in 285fb3f

### G01-16. _shared/R/README.md is stale: 'seven modules' misses 06_manuscript_helpers.R and 07_task_durations.R; several claims contradict code

- **Severity:** MAJOR (reported as MINOR). Fix could change a reported number: no.
- **Where:** `_shared/R/README.md:3`
- **What goes wrong:** A reader relying on the module table cannot find the helpers both manuscripts source. Someone following the stated source order would source _config.R before 00_paths.R, and _config.R:57 would then source 00_paths.R implicitly.
- **Evidence:** README.md:3 'Seven modules'. The table lists 00-04, 05_funnel.R and 06_helpers.R, but _shared/R also holds 06_manuscript_helpers.R (sourced by paper_1_morphosyntax.qmd:214 and paper_2_neuroplasticity.qmd:293) and 07_task_durations.R (sourced by paper_1_morphosyntax.qmd:215, paper_2_neuroplasticity.qmd:304 and paper_2_plasticity/scripts/13_extract_task_durations.R:9). Two modules share the 06 prefix.
- **Fix:** Edit documentation only. 1. In _shared/R/README.md: - Change 'Seven modules' to nine, or drop the count. - Add a row for 06_manuscript_helpers.R: reporting helpers sourced by both manuscripts' setup chunks and by supplement.qmd, which read results CSVs through .read_csv_if. - Add a row for 07_task_durations.R: reads the raw Gorilla and OpenSesame exports through the manifest accessors, falls back to git objects in the sparse checkout, and writes _task_durations_{home,lab}.csv into both papers' results/ through Paper 2 step 13. - Note the shared 06_ prefix in prose. Do NOT rename the files: that would break the source() calls in both qmds, the supplement and the scripts, and the ARC deployment.
- **Also reported as:** G02-24
- **Status:** resolved in commits b111348, 9a11c65

### G02-15. 07_task_durations.R functions lack docstrings; plot helpers need les_theme() from an unsourced module

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `_shared/R/07_task_durations.R:281`
- **What goes wrong:** Calling les_task_duration_home_plot() after sourcing only 07_task_durations.R fails with 'could not find function les_theme'. A reader cannot tell from the file that the writer overwrites both papers' results.
- **Evidence:** Only two one-line #' titles, and neither has params or a return value: les_extract_home_task_durations (:121) and les_extract_lab_phase_durations (:215). None at all for les_write_task_duration_artifacts (:281), which writes four CSVs into two papers; les_task_duration_median_text (:299); les_task_duration_home_plot (:338); les_task_duration_lab_plot (:370); or the private helpers :22-119 and :199-213.
- **Fix:** Comments and documentation only. (1) Give every public function in 07_task_durations.R a comment header in the existing house style (as in 02_diagnostics.R and 05_funnel.R; roxygen is not used elsewhere in _shared/R), stating: the arguments; the returned table's columns (home: participant_home_ID, session, task, duration_min, n_events, participant_lab_ID, language; lab: participant_lab_ID, session, phase, start_ms, end_ms, duration_min, boundary, source_file, participant_home_ID, language); side effects (a git subprocess via system2 when data/ is absent locally; les_write_task_duration_artifacts writes four CSVs, two per paper, after les_assert_readonly_data); and, for the two plot helpers, that les_theme() from 06_manuscript_helpers.R must already be defined in the calling environment.
- **Status:** resolved in 9c5c273: `#` headers on every public 07 function: arguments, columns, side effects.

### G02-17. codebook_descriptions.csv has no rows for the manuscript-facing _task_durations_home/lab.csv

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `_shared/R/codebook_descriptions.csv:1`
- **What goes wrong:** The next codebook regeneration prints '(description pending)' for 19 columns of two published tables. It also documents neither the privacy change nor the difference in units between the home and lab start_ms/end_ms.
- **Evidence:** A column-by-column comparison of each results CSV header with the description rows, using write_codebook.R's own matching rules, shows every column 'pending' for paper_1_transfer and paper_2_plasticity _task_durations_home.csv (participant_home_ID, session, task, start_ms, end_ms, duration_min, n_events, participant_lab_ID, language) and _task_durations_lab.csv (participant_lab_ID, session, phase, start_ms, end_ms, d ...
- **Fix:** In _shared/R/codebook_descriptions.csv, add exact-name rows for BOTH paper values. Use writer_script 'paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R)'. (a) _task_durations_home.csv, post-change schema only: participant_home_ID (Gorilla public ID); session (1 or 5); task (stroop, digit_span or asrt); duration_min ((last - first Gorilla UTC timestamp) / 60000, so idle time is included); n_events (distinct timestamps for that participant, session and task after de-duplication, batch exports taking priority over named exports, 07_task_durations.R:100-119 and :146-150); participant_lab_ID and language (joined from the participant key; rows with no lab ID are dropped, :171-173). Do NOT add start_ms/end_ms rows for the home file.
- **Also reported as:** G02-18, G15-21, G16-13
- **Status:** resolved before this pass (verified 3 October 2026): Rows added in 9a11c65; home CSV regenerated in c672bb5; CODEBOOK.md:849-878 regenerated. The rows are now updated for X7-03 and G02-12.

### G02-20. Installer does not install projpred, doParallel, depictr or scopusflow, though 08 says it provisions projpred

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `_shared/install_bayesian_dependencies.R:54`, `paper_2_plasticity/scripts/08_projpred_selection.R:121-129`
- **What goes wrong:** A fresh cluster library bootstrapped as 08's error message instructs still lacks projpred. Step 08 stops again with the same message pointing back at the same script.
- **Evidence:** :54-76 required_packages is here, renv, brms, posterior, bayesplot, loo, dplyr, tidyr, stringr, readr, readxl, data.table, purrr, ggplot2, ggtext, scales, patchwork, papaja, quarto. It also installs cmdstanr and eegUtils (:116-170). There is no 'projpred', 'doParallel', 'foreach', 'depictr' or 'scopusflow' anywhere in the file.
- **Fix:** Minimal fix: in paper_2_plasticity/scripts/08_projpred_selection.R:121-123 and :128-130, stop claiming the installer provisions projpred. Name the reproduction route instead, for example: "Restore the pinned environment (sbatch _shared/hpc/00_restore_environment.slurm, or submit_all.sh with_restore) so that the selection runs under the recorded version." Separately, and with author sign-off because POLISH_FLAGGED_2026-08.md:491-492 treats the installer's package list as a reproducibility decision: add "projpred" to required_packages in _shared/install_bayesian_dependencies.R, and optionally "doParallel" and "foreach" with a note that they are optional. Do NOT add depictr or scopusflow to the cluster installer.
- **Status:** resolved in 5b50d49: The installer now installs `projpred` (P2 08/09) and `digest` (used by the decoding fingerprint, the overlay check and P2 08). No script uses doParallel or foreach.
  instruction are corrected; changing the bootstrap package set remains an author decision

### G03-02. Live-job query swallows squeue and ssh failures, and its filters drop LESS jobs, so it can report no live jobs wrongly

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `_shared/hpc/deploy_to_cluster.sh:121`
- **What goes wrong:** Suppose `squeue -M htc` fails from the login node behind the ssh alias: federation is unavailable, a slurmctld timeout occurs, or the alias points at a host with no route to HTC. LIVE is then empty and every file is copied over the running HTC jobs with no warning. The same happens to a job in CONFIGURING state, which is just starting, and to a LESS job submitted with a -J name that does not begin p1_/p2_.
- **Evidence:** 121-124: `LIVE=$(ssh "$HOST" "squeue -M htc -u \$(whoami) -h -o '%i %T %j' 2>/dev/null; squeue -M arc -u \$(whoami) -h -o '%i %T %j' 2>/dev/null" | awk '{print $1, $2, $3}' | grep -E " (RUNNING|PENDING|SUSPENDED) " | grep -E ' p[12]_' || true)`. The stderr of both squeue calls goes to /dev/null and the whole pipeline ends in `|| true`, so a failed query cannot be told apart from an empty queue.
- **Fix:** Query first and fail closed, then filter. For example: `RAW=$(ssh "$HOST" "squeue -M htc,arc -u \$(whoami) -h -o '%i %T %j %Z'") || { echo "could not query live jobs on $HOST; refusing to deploy" >&2; exit 1; }` The calls are combined, or chained with `&&` rather than `;`, so that ssh returns a failure from either cluster. Then filter: `LIVE=$(printf '%s\n' "$RAW" | grep -v '^CLUSTER:' | awk '$3 ~ /^(p[12]|les)_/ || $4 ~ /new_LESS/ {print $1, $2, $3}' || true)` This applies `|| true` only to the filter. Scoping on the job's working directory (%Z) as well as the name catches LESS jobs whatever their name, and still ignores other projects. Drop the RUNNING|PENDING|SUSPENDED grep, because squeue without -t already omits finished jobs, or add STOPPED to it.
- **Status:** resolved in 5b50d49: One survey call runs `squeue -M htc && squeue -M arc`. Either failure, or an ssh failure, refuses the deploy (exit 1). There is no state filter. A LESS job is one whose name matches `^(p1\.

### G03-04. Deploy docs still say it refuses while any job of the paper is live, which the uncommitted rewrite no longer does

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `_shared/hpc/README.md:22`, `HPC_RUNBOOK.md:225`, `_shared/hpc/deploy_to_cluster.sh:27-33`, `AUTHOR_TASKS.txt:255`
- **What goes wrong:** A user who trusts the README or the runbook deploys while a Paper 2 job is pending, expecting the deploy to be refused. Instead part of the tree is copied (see the mixed-version finding), and nothing in the documentation warned of that.
- **Evidence:** _shared/hpc/README.md:22: 'It refuses while a job of that paper is running or pending ... `LES_DEPLOY_ANYWAY=1` overrides the live-job check.' HPC_RUNBOOK.md:225: 'It refuses to copy anything while a job of that paper is running or pending'. deploy_to_cluster.sh:30, in its own header: '2. no job of the target paper is running or pending;'.
- **Fix:** First settle the intended semantics, because the mixed-version finding may bring back refusal by default. Then describe them in every location: - Header lines 23-24: the new meaning of LES_DEPLOY_ANYWAY. - Header lines 27-33: the checks in execution order (file list, decoding hold-back, CRLF on .sh/.slurm only, live-job hold-back, copy and md5). - Comment 119-120: what happens to unmatched jobs. - _shared/hpc/README.md:22 and HPC_RUNBOOK.md:225-231. - AUTHOR_TASKS.txt is a dated log, so add a dated note under item 1.14 (253-257) and correct the forward-looking instruction at 519-520, rather than rewriting the historical entry. - Outside the repository, update memory file less-strong-study-2026-09.md:25.
- **Also reported as:** X1-03
- **Status:** resolved in 5b50d49: Updated the deploy header, the `_shared/hpc/README.md` row and the HPC_RUNBOOK deploy section. AUTHOR_TASKS.txt has dated notes under 1.14 and after the Part 3 recipe (the historical text is unchanged). The memory file `less-strong-study-2026-09.md:25` is outside the repo and was not updated.

### G03-05. Deploy route never ships R files that deployed job scripts run: check_arc_env.R, install_bayesian_dependencies.R

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `_shared/hpc/deploy_to_cluster.sh:64`, `_shared/hpc/rebuild_cmdstan.slurm:34`, `paper_1_transfer/hpc/00_install_dependencies.slurm:41`, `paper_2_plasticity/hpc/00_install_dependencies.slurm:34`
- **What goes wrong:** On a fresh cluster checkout built through the recommended route, rebuild_cmdstan.slurm fails with 'cannot open file _shared/hpc/check_arc_env.R'. On the existing cluster those files silently stay at whatever older copy was scp'd by hand, so check_arc_env.R and the installer drift from the repository with no checksum ever comparing them.
- **Evidence:** collect() line 64: `_shared) ls _shared/R/*.R _shared/hpc/*.sh _shared/hpc/*.slurm`. Scripts the deploy does ship call files outside those globs: rebuild_cmdstan.slurm:34 `Rscript _shared/hpc/check_arc_env.R`; paper_1_transfer/hpc/00_install_dependencies.slurm:41 and paper_2_plasticity/hpc/00_install_dependencies.slurm:34 `Rscript "_shared/install_bayesian_dependencies.R"`.
- **Fix:** In collect(), change the _shared branch to `ls _shared/*.R _shared/R/*.R _shared/hpc/*.R _shared/hpc/*.sh _shared/hpc/*.slurm 2>/dev/null || true`. Keep the reconnaissance filter, which now covers nothing and becomes relevant only if the globs ever recurse. Widen the live-job filter at line 124 to `grep -E ' (p[12]|les)_'`, so that a running les_rebuild_cmdstan or les_restore_env job holds back check_arc_env.R and the scripts it runs. For renv.lock and 'LESS Project.Rproj', add a header line saying they are copied by hand per HPC_RUNBOOK.md section 0 and 00_restore_environment.slurm:11-13. Do not add them to the file list.
- **Also reported as:** X1-02
- **Status:** resolved in 5b50d49: The file list now comes from `git ls-files` (tracked or staged, present on disk) and also covers `_shared/*.R`, `_shared/hpc/*.R`, `eeg_reconstruction/*.py` + `requirements.txt` and `paper_1_transfer/eeg_overlay_*.csv`. `les_` jobs count as LESS jobs. The header says renv.lock and the .Rproj are copied by hand.

### G03-10. The renv cache is never relocated, although .Rprofile says the cluster must set it because $HOME is quota-limited

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `.Rprofile:13`, `_shared/hpc/00_restore_environment.slurm:57`, `_shared/hpc/arc_env.sh:48-59`
- **What goes wrong:** The reproduction job restores about 420 packages. With the cache on, renv builds them into its default user cache under $HOME and links them into Rlib/R-4.5. On a quota-limited $HOME, which is what .Rprofile asserts, the restore either fails partway with a disk-quota error or leaves the /data library as links into a personal home directory.
- **Evidence:** .Rprofile:12-14: 'on the cluster set it in _shared/hpc/arc_env.sh, for instance export RENV_PATHS_CACHE="${LES_BASE}/renv-cache", because $HOME there is quota-limited.' A grep of the live tree finds RENV_PATHS_CACHE only in that comment, not in arc_env.sh or 00_restore_environment.slurm.
- **Fix:** In _shared/hpc/00_restore_environment.slurm, before the renv lines (54-57), add `export RENV_CONFIG_CACHE_ENABLED=FALSE`. The library then holds plain copies and nothing is written under $HOME. Alternatively, use `export RENV_PATHS_CACHE="${LES_BASE}/renv-cache"` if a reusable cache is wanted. Either way, rewrite .Rprofile:12-14 to describe what is actually done and where (the restore job, not arc_env.sh), and drop the stated need for a relocated cache if caching is disabled.
- **Status:** resolved in commits 744f10c, 9c1d808

### G03-12. Restore job dies if the submitter already exported LES_CMDSTAN_VERSION, as runbook section 0 recommends

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `_shared/hpc/00_restore_environment.slurm:42`
- **What goes wrong:** On a fresh environment the user exports LES_CMDSTAN_VERSION=2.39.0 in the login shell and runs `submit_all.sh with_restore`. The restore job exits 1 inside arc_env.sh before it installs anything, and every afterok stage in the chain stays pending until it is cancelled as DependencyNeverSatisfied.
- **Evidence:** 42: `source _shared/hpc/arc_env.sh`. arc_env.sh:74-78 exits FATAL when LES_CMDSTAN_VERSION names an absent tree. sbatch's default --export=ALL passes the submitter's environment through. HPC_RUNBOOK.md:116-117 recommends exporting it: 'or export `LES_CMDSTAN_VERSION=2.39.0`, which pins the tree and fails the job outright if it is absent'.
- **Fix:** In _shared/hpc/00_restore_environment.slurm, add `unset LES_CMDSTAN_VERSION` immediately before `source _shared/hpc/arc_env.sh` (line 42), and extend the header at 20-23 to say an inherited value is cleared because the tree does not yet exist. Line 60 already re-exports 2.39.0. Make the same change before the `source` line in both 00_install_dependencies.slurm files (paper_1_transfer/hpc:33, paper_2_plasticity/hpc:27). In HPC_RUNBOOK.md:116-118, say the export belongs on the fitting jobs once the tree exists.
- **Status:** resolved in commits 744f10c, 9c1d808

### G03-14. Runbook says both submit_all.sh chains run plain sbatch on ARC, but Paper 2's chain now defaults to HTC

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `HPC_RUNBOOK.md:16`, `HPC_RUNBOOK.md:128`, `HPC_RUNBOOK.md:131-133`, `paper_2_plasticity/hpc/submit_all.sh:87`
- **What goes wrong:** A user follows the runbook and expects Paper 2's chain on ARC. It goes to HTC under the educ-intract account, and `squeue -u $USER` on the ARC login node shows nothing, which looks as if submission failed and tempts a resubmit that duplicates the chain.
- **Evidence:** HPC_RUNBOOK.md:16-23: 'A plain `sbatch`, which is what every recipe below and both `submit_all.sh` scripts use, goes to the login node's default cluster, ARC ... so the chains as they stand run on ARC.' Working tree paper_2_plasticity/hpc/submit_all.sh:45-54: `LES_CLUSTER="${LES_CLUSTER-htc}"` ... `CLUSTER_ARGS="--clusters=${LES_CLUSTER} --account=${LES_ACCOUNT}"` ...
- **Fix:** HPC_RUNBOOK.md:14-24: Paper 1's submit_all.sh uses plain sbatch (default cluster, ARC). Paper 2's submits to HTC under educ-intract by default, overridable with LES_CLUSTER and LES_ACCOUNT, and LES_CLUSTER="" restores the site default. HPC_RUNBOOK.md:128: `squeue -M htc,arc -u "$USER"`. HPC_RUNBOOK.md:131-133: say `with_restore` chains the pinned restore on both scripts. Also change the echo at paper_2_plasticity/hpc/submit_all.sh:87 to `squeue -M ${LES_CLUSTER:-<default>} -u \$USER`, or simply `squeue -M htc,arc -u \$USER`. That echo is cosmetic but is the same drift in code.
- **Also reported as:** G14-07, X1-04
- **Status:** resolved before this pass (verified 3 October 2026): Runbook fixed in 218ccb9/744f10c. The echo at `paper_2_plasticity/hpc/submit_all.sh:87` needs patch #4b.

### G04-05. 00d writes a gate table no manuscript reads or job runs; its header contradicts the Method and the logs

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/00d_extract_training_gate_flow.R:6`, `paper_1_transfer/scripts/00d_extract_training_gate_flow.R:189`, `paper_1_transfer/scripts/00d_extract_training_gate_flow.R:209`, `paper_1_transfer/paper_1_morphosyntax.qmd:358`
- **What goes wrong:** A reader or later author takes the header as the description of the gate and reports it as attrition-generating missingness, contrary to the protocol. Two tracked CSVs (paper_1 and paper_2 results/_training_gate_flow.csv) go stale unnoticed. If test_passed is ever renamed, every session is written up as a gate-free retention session with n_attempted = 0, with no error.
- **Evidence:** 00d:6-12: 'participants who never passed drop out of later sessions ... which both manuscripts need to describe'. qmd:2257-2258: 'after the second attempt, participants proceeded to the experiment regardless of their score'. qmd:2264-2267: 'Per-session gate outcomes are not reported ...
- **Fix:** Split the fix. (1) Without numeric effect: rewrite 00d:6-12 to the documented protocol. The >80% threshold is the first-attempt gate. A failed first attempt was followed by re-training and a second test, after which the participant proceeded regardless. The reconstruction is not reported because it does not reconcile with Session-4 attendance. Correct paper_1_transfer/README.md:18 the same way, and state there that neither manuscript reads _training_gate_flow.csv. (2) With author sign-off: retire 00d and its two tracked CSVs, and remove the codebook rows in _shared/R/codebook_descriptions.csv:162-168 and 392-398 and the README mentions. Alternatively keep it as a documented audit artefact. In either case delete the unused `gate_tbl` assignment at qmd:358 (a manuscript edit).
- **Status:** resolved in part (aad57ed): 00d stops when no training-session log carries `test_passed`. Retiring 00d and its table is the author's decision.
  the protocol and the unused audit table accurately; retiring the artefact and removing
  the unused manuscript setup read remain author decisions

### G05-03. The unit test claims to check within-participant z-scoring but would pass under global scaling

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/tests/test_summarise_cells.R:60`
- **What goes wrong:** A regression that moved the `group_by(participant_lab_ID)` at 01:146, or dropped it, or scaled the baseline covariate globally, would still print 'All .les_summarise_cells unit tests passed.'. The within-participant scaling the manuscript argues for (qmd:1929-1938) would silently stop being applied.
- **Evidence:** Header L6-7: "checks the windowing, baseline matching, within-participant z-scoring and item_id construction". The synthetic response has no participant term, L60: `amplitude = time / 100 + gram_effect + elec_offset`, so participants 1 and 2 have identical amplitude distributions. The only z-score check, L104-107, asserts `mean(z_amplitude)` is 0 within each participant, and L108 asserts sd > 0.
- **Fix:** In test_summarise_cells.R, give participant 2 a different location and scale (e.g. amplitude * 2 + 5, applied to baseline samples too). Assert: per-participant mean 0 and SD 1 for z_amplitude and for z_baseline_predictor; z_amplitude differs from as.numeric(scale(amplitude)) over all rows. For the mis-filter, add participant 7 with rows at session 2 and session 3, making the session-3 amplitudes clearly different (e.g. +10). Assert that no session-3 rows for participant 7 survive, and that participant 7's session-2 z_amplitude and z_baseline_predictor equal those computed from its session-2 rows alone. Optionally assert that the globally scaled z_recoded_* columns match a computation that excludes the mis-filtered rows. Keep the header claim aligned with what is asserted.
- **Status:** resolved in aad57ed: Remaining part added: `test_summarise_cells.R` asserts that `z_recoded_mini_language` and `z_multilingual_language_diversity` are z-scores of the surviving rows only. Passes.

### G06-07. Comments say the _diversity variant mirrors the ERP covariate, but the ERP models carry L1 dominance

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/04_fit_brms_accuracy.R:63`, `paper_1_transfer/scripts/02_extract_accuracy.R:134`, `paper_1_transfer/scripts/02_extract_accuracy.R:13`, `paper_1_transfer/scripts/03_fit_brms_erp.R:34`
- **What goes wrong:** Someone running LES_P1_ACC_DIVERSITY=1 to address the asymmetry the Limitations section names would add a different LHQ3 score from the one in the ERP models, while the code comments tell them it is the same control. Any statement derived from that variant about accuracy "controlling for the ERP covariate" would be wrong.
- **Evidence:** 04:63-64: "the LHQ3 multilingual language diversity score enters as a main effect, exactly as in the ERP models". 02:134-135: "The ERP models carry `z_multilingual_language_diversity` as a between-participant control". 02:13-14 describes the variant as attaching "the LHQ3 multilingual language diversity score". 03:34-35: "z_multilingual_language_diversity is a control for prior multilingual experience".
- **Fix:** Comments only. Leave 02:13-14 as it is. - 03_fit_brms_erp.R:34-38 (optionally also the formula list at :17): say the variable holds the LHQ3 L1 Dominance Score. The legacy LHQ3 loader reads the workbook by column position, so the name is a legacy label (see the manuscript Method). It is a control for prior language experience. - 02_extract_accuracy.R:134-137, 04_fit_brms_accuracy.R:63-65 and _config.R:204-205: say that LES_P1_ACC_DIVERSITY adds the header-matched Multilingual Language Diversity Score as a main effect. That is a different LHQ3 score from the ERP control, even though both share the variable name z_multilingual_language_diversity, so the variant does not mirror the ERP covariate. - 02_extract_accuracy.R:388-389: optionally scope "exactly as" to the z-scoring procedure.
- **Status:** resolved in the comments (4a545e7, aad57ed). An accuracy variant with the L1 Dominance Score is the author's decision.

### G06-08. Missing roxygen docstrings on every function in 02_extract_accuracy.R, several with hidden file-write side effects

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/02_extract_accuracy.R:231`
- **What goes wrong:** A caller sourcing 02 to reuse build_paper1_accuracy(), for example an audit or test, silently overwrites two manuscript-read results CSVs. Nothing in the function's documentation warns of this.
- **Evidence:** No #' roxygen block on .les_scale (97), .read_one_logfile (116), .les_acc_join_diversity (146), .les_write_input_gaps (193), build_paper1_accuracy (231), .les_write_sentence_inventory (350) or .run (371). The banner comments give no parameter types, return values or side effects.
- **Fix:** Documentation only: 1. Add a #' block to build_paper1_accuracy(): purpose; no parameters; return value (one row per de-duplicated scored judgement trial, with the recoded predictors and factors, plus multilingual_language_diversity under the switch); side effects (writes results/_accuracy_input_gaps[_diversity].csv and results/_accuracy_rt_screen[_diversity].csv; reads LES_P1_ACC_DIVERSITY; reads the participant key and LHQ3 workbook when the switch is set). 2. Convert the existing banners of the private helpers into one-line #' purpose docstrings. 3. Extend the header "WHAT THIS SCRIPT PRODUCES" (7-15) to list _accuracy_input_gaps, _accuracy_rt_screen and _accuracy_sentence_inventory. 4.
- **Status:** partly resolved: every function in 02 is documented (aad57ed), and Paper 2's call no longer writes Paper 1's tables (b2f67f0). Moving the writes out of the builder altogether remains open.

### G08-14. No function in 09_run_decoding.R has a docstring stating parameters, return value, RNG use or global state

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/09_run_decoding.R:161`
- **What goes wrong:** The global RNG mutation and the checkpoint file writes are what make resume correctness subtle, and a maintainer changing a helper has no per-function statement of either.
- **Evidence:** Undocumented in #' roxygen form: .les_lda_fit (161), .les_lda_score (181), .les_auc (187), .les_balance_train (203, draws from the RNG), .les_perm_labels (233, draws from the RNG), .les_decode_timepoint (238), .les_cluster_perm (274), .les_fdr_confirmatory (371, can stop()), .les_decode_timecourse (410, writes the partial checkpoint and assigns .Random.seed in .GlobalEnv at 438), .les_generalize_timepoint (503), .les ...
- **Fix:** Add #' headers (purpose, @param with types, @return, side effects) to the public drivers run_timecourse, run_crosslang, run_crossprop, run_temporalgen and .run, stating the CSV each writes and that it consumes the global RNG. Add side-effect lines to .les_decode_timecourse and .les_tc_block: the .Random.seed assignment in .GlobalEnv, the checkpoint and partial files written or unlinked, and the stop conditions. Move the .les_decode_timepoint header back above that function. Convert the existing block headers of the other helpers to #' form rather than rewriting them. Decide the roxygen convention once for the whole repo, not file by file. Edit locally only; do not deploy 09 until the gender rerun lands.
- **Status:** resolved in d9d9fab: `#'` docstrings (purpose, @param, @return, RNG use, .GlobalEnv assignment, files read/written, stop conditions) on every function in 09; `.les_decode_timepoint` header moved back above it; stale `perm_within_part` reference removed.

### G08-15. No function in 08_extract_decoding_matrices.R has a docstring

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/08_extract_decoding_matrices.R:296`
- **What goes wrong:** The tensor builder's input contract (the columns and types of `raw`) and the extractor's file side effects are documented only in prose far from the functions.
- **Evidence:** Undocumented in #' form: les_decode_time_step_ms (104), les_decode_rds (113), .les_decode_fp_path (141), .les_truthy (144), .les_stat (151), .les_decode_source_files (167), .les_decode_input_scripts (182), .les_decode_paths_agree (201), .les_decode_fingerprint (207), .les_decode_cache_ok (240), .les_decode_write_fingerprint (267, writes a file), .les_save_atomic (279, writes a file), .les_build_decoding_tensor (296), ...
- **Fix:** Add #' headers to extract_paper1_decoding: @param property, time_step_ms and baseline_correct; @return the invisible tensor path; side effects, namely writes _decoding_&lt;property>.rds and its _fingerprint.rds, sources the legacy loader into the global environment, and stops on a missing digest. Add #' headers to les_decode_rds and les_decode_time_step_ms, and note or remove the unreachable cli_arg per POLISH_FLAGGED_2026-08.md:568. On .les_build_decoding_tensor, spell out the required columns of `raw` and the returned list. Give .les_decode_write_fingerprint a one-line purpose and side-effect header. Convert the existing block headers of the other helpers to #' form without rewriting their content. Settle the roxygen convention repo-wide.
- **Status:** resolved in d9d9fab: `#'` docstrings on every function in 08, including the input contract of `.les_build_decoding_tensor` (placed above the fingerprinted function; its body untouched).

### G09-05. 99_diagnose_ice.slurm 'default' builds now inherit the -O1 pin, so the retained diagnostic cannot re-measure -O3

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/99_diagnose_ice.slurm:89`
- **What goes wrong:** After a GCC upgrade the maintainer reruns 99 as the runbook says. "A_threaded_default" builds, because it is really -O1, and the log reads as though threading at -O3 now compiles. The -O1 pin could then be removed on false evidence, and the ERP array would start crashing again.
- **Evidence:** 99:89 `try_build "A_threaded_default" "$D/threaded" STAN_THREADS=true` and 99:91 `try_build "C_serial_default" "$D/serial"` pass no CXXFLAGS_OPTIM. The header (lines 7-9) says the job compiles "at the CmdStan default (-O3) and at -O1", and lines 22-23 say it is "retained to re-measure after a toolchain upgrade" (as does HPC_RUNBOOK.md:250-252).
- **Fix:** Pass the level explicitly so make/local cannot supply it: 99:89 `try_build "A_threaded_O3" "$D/threaded" STAN_THREADS=true CXXFLAGS_OPTIM=-O3` and 99:91 `try_build "C_serial_O3" "$D/serial" CXXFLAGS_OPTIM=-O3`. Command-line variables override make/local assignments. Update the header at lines 7-9 to say the levels are forced on the command line because arc_env.sh pins -O1 in make/local. Correct the '96 GB allocation' at 99:17 only after checking sacct for job 12684901. Deploy with the Paper 1 reconciliation, not while Paper 1 jobs are live (AUTHOR_TASKS.txt:505-507).
- **Status:** resolved: the builds force their optimisation level on the command line, and the header no longer calls 96 GB this job's allocation (1533b4a).

### G09-08. In-job `mkdir -p logs` runs after SLURM has opened -o, so a hand-submitted job on a fresh deployment fails with no log

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/README.md:128`, `paper_1_transfer/hpc/00_descriptives.slurm:31`, `paper_1_transfer/hpc/08b_verify_gender_decoding.slurm:32`, `paper_1_transfer/hpc/99b_test_O2.slurm:23`
- **What goes wrong:** On a fresh deployment (new account, or a cluster copy without logs/), `sbatch paper_1_transfer/hpc/07_grand_average.slurm`, or any stage the README says to submit by hand (00_descriptives, 07, 07b, 08, 08b), cannot open its output file. The job ends FAILED with no .out and no .Rout, and an afterok dependant never starts.
- **Evidence:** Every job directs its output into the logs directory (for example 07:20 `#SBATCH -o paper_1_transfer/hpc/logs/07_grand_average_%a.out`) and only creates that directory later, inside the job body (07:25 `mkdir -p paper_1_transfer/hpc/logs`). 08b has no mkdir at all (08b:32-36). The directory is untracked and ignored (.gitignore:43 `/paper_1_transfer/hpc/logs/`; `git ls-files paper_1_transfer/hpc` lists no logs/).
- **Fix:** Documentation only. In HPC_RUNBOOK.md section 0, directly after the scp step (around :59-60) and before the first sbatch at :70, add `mkdir -p paper_1_transfer/hpc/logs paper_2_plasticity/hpc/logs`, with one sentence saying that Slurm opens the -o file before the job body runs. Add the same line to paper_1_transfer/hpc/README.md, next to the hand-submission advice at :127-129 and the bootstrap block at :58-62, and to paper_2_plasticity/hpc/README.md. As an optional tooling fix that cannot alter results, add both logs directories to the remote `mkdir -p` at deploy_to_cluster.sh:189. Leave the in-job mkdir lines alone, and do not touch 08_decoding.slurm.
- **Status:** resolved: the runbook creates both log folders before the first submission, and the HPC README says why (1533b4a).

### G10-11. README describes the Part A outcome as 'training accuracy'; 02 builds grammaticality-judgement accuracy

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/README.md:24`, `paper_2_plasticity/README.md:4`, `paper_2_plasticity/README.md:26`, `paper_2_plasticity/README.md:52`
- **What goes wrong:** A reader or reviewer reproducing Part A from the README believes the dependent variable is accuracy on the feedback-training trials. That is exactly the data 02 says cannot be used, so they misinterpret the learning-rate and attainment estimates.
- **Evidence:** README.md:24 step 2: 'tidy trial-/session-level training-accuracy data (feeds the Part A joint model)'. :26 'joint Bernoulli multilevel model of the training-accuracy trajectory'. :52 'A single Bayesian multilevel Bernoulli model of trial-level training accuracy'. :4 'the artificial-language training trajectory'.
- **Fix:** In paper_2_plasticity/README.md make three replacements. At line 24, change 'training-accuracy data' to 'grammaticality-judgement accuracy data'. At line 26, change 'training-accuracy trajectory' to 'grammaticality-judgement accuracy trajectory'. At line 52, change 'trial-level training accuracy' to 'trial-level grammaticality-judgement accuracy'. Line 4 can optionally become 'learning trajectory' but is not wrong. Leave line 68 ('end-of-training accuracy') unchanged, since it matches qmd:666.
- **Status:** resolved: the remaining optional wording ('training trajectory') is not wrong.

### G10-20. 02 functions lack roxygen docstrings (build_learning_trajectory, .run)

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/02_extract_learning_trajectory.R:54`, `paper_2_plasticity/scripts/02_extract_learning_trajectory.R:101`
- **What goes wrong:** A caller reading only the function assumes it writes one derived file, and does not anticipate the Paper 1 artefacts it rewrites (see the separate finding).
- **Evidence:** 02:54 `build_learning_trajectory <- function() {` and 02:101 `.run <- function() {` have no #' block. The file header documents the output table but not the function's inputs (paper2_derived("cognitive_indices.rds"), the behavioural logs via build_paper1_accuracy()), its env-var sensitivity (LES_P1_ACC_DIVERSITY), or its side effects (writes learning_trajectory.rds and, through the Paper 1 builder, two Paper 1 result ...
- **Fix:** Add a #' block to build_learning_trajectory. It should cover: inputs (the behavioural logs via build_paper1_accuracy(), and paper2_derived("cognitive_indices.rds"), whose Session 1 rows are used); @return, an invisible trial-level data.frame with participant_lab_ID (factor), session (integer), session_time (0-3), grammatical_property (factor), grammaticality, recoded_grammaticality, mini_language, correct (0/1), z_digit_span, z_stroop, z_asrt and z_session_time; side effects: it writes paper2_derived("learning_trajectory.rds"), and through build_paper1_accuracy() it also rewrites paper_1_transfer/results/_accuracy_input_gaps.csv and _accuracy_rt_screen.csv (suffixed _diversity when LES_P1_ACC_DIVERSITY=1, which does not change the trajectory).
- **Status:** resolved in 2352752: 02:79-90 doc names the three Paper 1 files; `.run()` documented.

### G12-10. LES_AP_FIT_MAX_HZ is undocumented outside 07, has no consumer, misreads silently, and '30' isn't passband

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/07_extract_aperiodic.R:122`
- **What goes wrong:** A value such as '30Hz' or '2' is ignored without warning and the untagged reported files are rewritten at 40 Hz. Setting 30 as documented still fits attenuated bins. No documented route turns the sensitivity decomposition into a model.
- **Evidence:** 07:122-123 `v <- suppressWarnings(as.numeric(Sys.getenv("LES_AP_FIT_MAX_HZ", unset = ""))); if (is.finite(v) && v > 2) v else 40`. A repo-wide grep finds LES_AP_FIT_MAX_HZ only in 07: not in 07_aperiodic.slurm (33-35 passes only MODE), submit_all.sh, HPC_RUNBOOK.md, any README or the codebook.
- **Fix:** (1) In 07:121-124, keep 40 when LES_AP_FIT_MAX_HZ is unset or empty. When it is set but non-numeric or outside (fit_range lower bound 2, the PSD's usable maximum], call stop() with a clear message instead of falling back silently. (2) Add a row to paper_2_plasticity/hpc/README.md's 'Analysis-variant switches' table covering: stage 07, tag `_fit<max>hz`, a submission line using `sbatch --export=ALL,LES_AP_FIT_MAX_HZ=<hz>`, and the facts that the output is descriptive only, is not read by 04 or the manuscript, and that 12 must not run with the variable set. (3) Reword 07:66-68: drop 'passband-only' for 30, or state the two-pass attenuation at the chosen bound (about 6 dB at 30 Hz), so a reader can pick a lower bound if negligible attenuation is the aim.
- **Status:** resolved in 2352752, with the README row in 1533b4a.

### G14-02. Uncommitted submit() pipes sbatch into cut without pipefail, so a failed submission no longer stops the chain

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/hpc/submit_all.sh:54`
- **What goes wrong:** On HTC, sbatch rejects 01 (for example a bad LES_ACCOUNT, an unavailable partition or a transient controller error). JID_COG is set to empty, and every later call gets `--dependency=afterok:` or `afterok::`, which sbatch also rejects, with those failures masked the same way. The script still prints each stage with a blank id and 'All jobs queued'.
- **Evidence:** submit_all.sh:54 (uncommitted) `submit() { sbatch --parsable ${CLUSTER_ARGS} "$@" | cut -d';' -f1; }`. Lines 39-40 set only `set -o errexit` and `set -o nounset`, not pipefail. HEAD had `submit() { sbatch --parsable "$@"; }` (git diff), where a failing sbatch inside `JID_COG=$(submit ...)` made the assignment fail and errexit abort. With the pipe, the assignment's status is cut's (0).
- **Fix:** Add `set -o pipefail` beside errexit at submit_all.sh:39-40. Better still, drop the pipe from submit() and check the id. `exit` inside `$(...)` leaves only the subshell, but the non-zero status then fails the assignment and errexit stops the script: submit() { local out id out=$(sbatch --parsable ${CLUSTER_ARGS} "$@") || { echo "sbatch failed: $*" >&2; exit 1; } id=${out%%;*} [[ "$id" =~ ^[0-9]+$ ]] || { echo "unexpected sbatch output: '$out'" >&2; exit 1; } printf '%s\n' "$id" }
- **Status:** resolved in 913c035 for both papers: a failed submission stops the chain (tested).

### G14-03. submit_all.sh with_restore submits a job whose log directory it never creates, so the chain can wedge

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/hpc/submit_all.sh:58`, `_shared/hpc/00_restore_environment.slurm:40`
- **What goes wrong:** On a fresh code copy where Paper 1's logs directory does not yet exist, `bash paper_2_plasticity/hpc/submit_all.sh with_restore` submits the restore job. It fails at start because it cannot open its stdout file, leaving no log. Every afterok dependant (01 to 06) then sits in DependencyNeverSatisfied. This is the documented reproduction route (README:43-45).
- **Evidence:** submit_all.sh:43 `mkdir -p "${HPC_DIR}/logs"` creates only paper_2_plasticity/hpc/logs. :57-60 then submits `_shared/hpc/00_restore_environment.slurm` and chains everything with `--dependency=afterok:${JID_INSTALL}`. 00_restore_environment.slurm:40 `#SBATCH -o paper_1_transfer/hpc/logs/00_restore_environment.out`, and its header :30-32 warns: 'Slurm opens that file when the job starts, so on a fresh checkout create t ...
- **Fix:** In the `with_restore` branch of submit_all.sh (:57-58), add `mkdir -p paper_1_transfer/hpc/logs` before the submit call. Alternatively, override the log path on that call: `submit -o "${HPC_DIR}/logs/00_restore_environment.out" "_shared/hpc/00_restore_environment.slurm"`. A command-line -o overrides the #SBATCH line. Separately, HPC_RUNBOOK.md:131-133 still says the pinned route is submitted on its own before the chain, which contradicts the `with_restore` option; worth aligning at the same time.
- **Status:** resolved in 913c035.

### G14-11. 13_extract_task_durations.R and its outputs are barely documented: no usage/IO header, not in either CODEBOOK

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/13_extract_task_durations.R:1`, `paper_1_transfer/results/CODEBOOK.md:1`, `paper_2_plasticity/results/CODEBOOK.md:362`, `_shared/R/07_task_durations.R:281`
- **What goes wrong:** A reader of Paper 1's compendium cannot find which step produces the durations its manuscript reports, or what the columns mean. Once the CSVs are regenerated without start_ms/end_ms, nothing documents the schema change.
- **Evidence:** 13:1-4 is the whole header ('Observed participant-level durations for the home tasks and lab-session phases. The artefacts are shared with Paper 1 ...'). It has no USAGE line and does not name its inputs (Gorilla EF exports for S1/S5, OpenSesame lab CSVs for S2/3/4/6, the participant key, a `git show HEAD:` fallback) or its outputs.
- **Fix:** (1) Give 13 a header in the style of 11: purpose; inputs (Gorilla EF exports for S1/S5 via cognitive_ef_path, OpenSesame lab CSVs for S2/3/4/6 via behavioural_lab_path, the participant key, and the HEAD git-object fallback, pointing to 07_task_durations.R:5-12); the four outputs and the cross-paper write; usage (Rscript, or hpc/13_extract_task_durations.slurm). (2) Add codebook_descriptions.csv rows for both tables, writer_script paper_2_plasticity/scripts/13_extract_task_durations.R, for both papers. The home table gets the post-change columns (participant_home_ID, session, task, duration_min, n_events, participant_lab_ID, language). The lab table keeps start_ms/end_ms, described as within-session offsets, plus boundary and source_file.
- **Status:** resolved before this pass (verified 3 October 2026): 9a11c65: 13's header and the codebook rows. Both CODEBOOK.md files carry the `_task_durations_*` tables. P1 README:43-47 names the writer. (Not my file in any case.)

### G15-08. journal_requirements.json records five figures; the manuscript has seven, over the journal's limit of five

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/journal_requirements.json:22`, `AUTHOR_TASKS.txt:63`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:598`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:607`
- **What goes wrong:** The submission goes in believing it meets Bilingualism: Language and Cognition's figure limit when it carries seven figures, and is returned at technical check.
- **Evidence:** journal_requirements.json:22 "... Five figures and four tables, within the limit of five each." and :29 "max_figures": 5. AUTHOR_TASKS.txt:63-64 repeats 'the display items are five figures and four tables, within the limit of five of each'. The main qmd has seven figure chunks: fig-flow (474), fig-home-task-duration (598), fig-lab-phase-duration (607), fig-accuracy-trajectory (977), fig-predictor-corr (1023), fig-pre ...
- **Fix:** 1. Correct journal_requirements.json:22 and AUTHOR_TASKS.txt:63-64 to 'seven figures and four tables (eleven display items)'. Say that this exceeds both the recorded figure limit of five and the display-item limit of ten. 2. Before the author decides, re-read the limit on the journal's guidelines page. 3. Add an author decision item: move the two task-duration figures (and one more if the limit of five is confirmed) to the supplement, or combine figures. Correcting the record is documentation only. Moving figures changes the manuscript and needs sign-off.
- **Status:** resolved on 18 September 2026: five main-text figures and four tables.

### G15-10. results/README says the manuscript never reads 07_aperiodic_features.csv, but three accessors do

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/results/README.md:13`, `paper_2_plasticity/manuscript_setup.R:94`, `_shared/R/write_codebook.R:52`
- **What goes wrong:** Someone trusts the README, renames the file or changes its columns, and the specparam peak counts in the Method silently turn to 'NN'. Its columns also have no codebook entry. A future eyes-open decomposition would inflate the 'of the N eyes-closed recordings' count.
- **Evidence:** results/README.md:13: '`07_aperiodic_features.csv` | The one pipeline-internal table. Step 07 writes it and step 04 reads it, and the manuscript never touches it.' manuscript_setup.R:94 `aper_feat <- .read_csv_if(paper2_results("07_aperiodic_features.csv"))` feeds specparam_rec_n(), specparam_peak_n() and n_peak_band() (95-105), which print at qmd:563-564 and 832-834.
- **Fix:** Documentation and tooling, safe to apply: 1. Rewrite results/README.md:13 so it says step 07 writes the file, step 04's aperiodic variant reads it, and manuscript_setup.R reads it for the specparam peak and recording counts in the Method. Keep the "leave the name alone" advice, now naming three consumers. 2. Remove it from LES_CODEBOOK_SKIP (write_codebook.R:52) and fix the header comment at :30-31. 3. Add codebook_descriptions.csv rows for its 16 columns (writer 07_extract_aperiodic.R), then regenerate CODEBOOK.md. Separately, needing sign-off because it touches manuscript-feeding code, though no current value changes: filter aper_feat once at manuscript_setup.R:94 to `session == LES_P2_NEURAL_SESSIONS[1] & condition == "eyes_closed"`, mirroring 04:222.
- **Also reported as:** G02-19, G12-11
- **Status:** resolved: the specparam counts read the baseline eyes-closed rows only (913c035), and the codebook covers the file (f455211).

### X2-05. CmdStan 2.39.0 and R/4.5.1 versions of record are typed in many scripts and docs, never derived or compared

- **Severity:** MAJOR. Fix could change a reported number: no.
- **Where:** `_shared/hpc/00_restore_environment.slurm:58`, `_shared/hpc/00_restore_environment.slurm:60`, `_shared/install_bayesian_dependencies.R:18`, `HPC_RUNBOOK.md:107`, `README.md:40`, `_shared/hpc/README.md:20`
- **What goes wrong:** After a module or CmdStan bump (for example the cluster retires R/4.5.1-gfbf-2025a, or someone edits one of the nine 2.39.0 literals), the restore route and the docs can name different versions. A restore under a newer R module proceeds against a lockfile snapshotted under 4.5.1 with no stop from the job, and the R-4.5 library label keeps pointing at packages built for another minor version.
- **Evidence:** The CmdStan version literal appears at 00_restore_environment.slurm:58 `cmdstanr::install_cmdstan(version = "2.39.0", ...)` and again at :60 `export LES_CMDSTAN_VERSION=2.39.0`. It also appears at install_bayesian_dependencies.R:18, HPC_RUNBOOK.md:68, 87, 107, 115 and 117, README.md:40 and _shared/hpc/README.md:20. arc_env.sh has no version of record: :81 takes `ls -d .../cmdstan-* | sort -V | tail -1`.
- **Fix:** Confine the change to _shared/hpc/00_restore_environment.slurm. Leave arc_env.sh and the documentation alone, since the docs correctly state the environment of record. (a) Move `export LES_CMDSTAN_VERSION=2.39.0` so it comes after `source _shared/hpc/arc_env.sh`, where it already is, but before the install line. Change :58 to `cmdstanr::install_cmdstan(version = Sys.getenv("LES_CMDSTAN_VERSION"), dir = Sys.getenv("CMDSTAN_INSTALL_DIR"))` so the literal is written once. (b) After renv has been installed (:54) and before the restore (:57), add a guard: `Rscript --vanilla -e 'rec <- renv::lockfile_read("renv.lock")$R$Version; cur <- format(getRversion());
- **Status:** partly resolved in 5b50d49: arc_env.sh holds the R module and CmdStan record once, and the restore job checks the built version.


## MINOR, HIGH-RISK (94)
### G01-04. here::here() never errors, so the tryCatch fallback is unreachable; root comes from renv.lock, not the Rproj

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/00_paths.R:54`, `_shared/R/00_paths.R:16`, `_shared/R/README.md:10`, `_shared/README.md:27`
- **Fix:** Minimal, comments and docs: rewrite 00_paths.R:16-17 and :48-53 to say that here::here() searches upwards for any of its root criteria (an .Rproj, renv.lock, .git and others). Say that here itself falls back to the working directory when none matches, and that the resolved root is announced at the foot of the file.
- **Status:** resolved in 9c5c273: Dead `tryCatch` removed. The header and README give `here`'s real root criteria; the cluster has only the `.Rproj` (checked).

### G01-10. les_write_provenance overwrites a shared file non-atomically from 18 array tasks; callers hide failures with try(silent)

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/04_provenance.R:85`, `paper_1_transfer/scripts/03_fit_brms_erp.R:325`, `paper_2_plasticity/scripts/04_fit_brms_predictors.R:412`
- **Fix:** In both callers (03_fit_brms_erp.R:325, 04_fit_brms_predictors.R:412), replace try(..., silent = TRUE) with tryCatch(..., error = function(e) warning('[provenance] write failed: ', conditionMessage(e))), so a failed write is visible in the .Rout log.
- **Status:** resolved in 9c5c273: Atomic write. The callers have since been changed by other agents: P1 03:453 now calls without `try`; P2 04:645 calls without `try` and passes `extra`.

### G01-12. PPC helpers leave the global RNG seeded when the caller had none, and fall back silently to seed 1 / rstan

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/02_diagnostics.R:123`, `_shared/R/02_diagnostics.R:163`, `_shared/R/02_diagnostics.R:181`
- **Fix:** In both helpers, change the on.exit to `if (is.null(old_seed)) rm(".Random.seed", envir = .GlobalEnv) else assign(".Random.seed", old_seed, envir = .GlobalEnv)`. It runs after ggsave, so the figure is unchanged. Replace the `exists()` fallbacks at 02:126, 163 and 164 with stop() naming 01_bayesian_settings.R. Use base R, not withr::with_seed, to avoid a new dependency.
- **Status:** resolved in 9c5c273: RNG state restored or removed on exit. A missing `LES_SEED` or `.les_backend` now stops instead of falling back to seed 1 or rstan.

### G01-13. LES_PRIOR_SET value is not validated and is normalised differently in R, fit metadata and job scripts

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/01_bayesian_settings.R:261`, `paper_1_transfer/scripts/_config.R:256`, `paper_2_plasticity/scripts/_config.R:115`, `paper_1_transfer/hpc/03_fit_erp.slurm:45`, `paper_1_transfer/hpc/04_fit_accuracy.slurm:39`
- **Fix:** In 01_bayesian_settings.R, after line 261, stop() with a clear message if LES_PRIOR_SET() is not in c("informative", "weak"). Change P1 _config.R:256 and the P2 _config.R:115-116 default to `prior_set = LES_PRIOR_SET()`, keeping 05's explicit "weak". Optionally, use one lowercased test and one `_weakprior` log tag in the three slurm scripts.
- **Also reported as:** G11-16
- **Status:** resolved in 9c5c273.

### G01-14. .ensure_dir turns every extensionless path into a directory, including brms cache stems and read-only lookups

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/00_paths.R:121`, `paper_1_transfer/scripts/03_fit_brms_erp.R:275`, `paper_2_plasticity/scripts/09b_compare_aperiodic_commonsample.R:57`
- **Fix:** At the call sites, build stems with file.path(), which creates only results/ and not a model-named directory: `file = file.path(paper1_results(), cell_tag)` in 03:275 and 04_fit_brms_accuracy.R:119, and `file.path(paper2_results(), model_tag)` or `model_id` in P2 04:379, 05:95 and 186, 08:186, and 09b:57-58 and 81.
- **Also reported as:** G06-15, G11-13
- **Status:** deferred until after submission (decided 17 October 2026): the call-site patches change the brms cache stems, so a stem that moved would refit every model.

### G01-15. LES_DATA_ROOT/LES_STORE are not validated: an exported empty or relative value is accepted silently

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/00_paths.R:73`
- **Fix:** After 00_paths.R:73, for each of LES_DATA_ROOT and LES_STORE, stop() if the variable is set but empty (`!is.na(Sys.getenv(v, unset = NA)) && !nzchar(Sys.getenv(v))`). Skip the absolute-path and LES_CODE_ROOT checks, which the existing setwd and the cd in arc_env.sh already cover.
- **Status:** resolved in 9c5c273: Set-but-empty `LES_DATA_ROOT`/`LES_STORE` now stops. Logic reviewed; it cannot be exercised on Windows, where an empty variable cannot exist.

### G02-04. les_participant_folds partition depends on row order (unsorted unique) and resets the global RNG

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `_shared/R/06_helpers.R:48`, `_shared/R/06_helpers.R:44`, `paper_2_plasticity/scripts/08_projpred_selection.R:208`, `paper_2_plasticity/scripts/09c_compare_aperiodic_grouped.R:112`
- **Fix:** Now, comments only. Document at 06_helpers.R:36-38 and :48 that the partition depends on the first-appearance order of participant_lab_ID in the rows passed in. Also document that the global set.seed is deliberate, because 09c's brms::kfold refits draw their cmdstanr seeds from R's RNG. Change the message prefix at :41/:46 to a neutral '[folds]'.
- **Status:** resolved in 9c5c273: Comments on the row-order dependence and on why the RNG is not restored (corrected for the current 08 and 09c, which seed themselves). Messages now prefixed `[folds]`. Output identical (tested).

### G02-05. Base-R apa_num/apa_p fallbacks print different numbers from papaja; apa_p has no caller

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/06_manuscript_helpers.R:56`, `_shared/R/06_manuscript_helpers.R:52-58`
- **Fix:** Choose one of two options. (a) Recommended and simplest: since papaja 0.1.5 is pinned and installed on the render box, replace the else-branch with stop("papaja is required to format reported numbers; install the pinned papaja 0.1.5"). Update the comment at :50-51 to match.
- **Status:** resolved in 9c5c273: papaja is now required (0.1.5 is installed). The unused `apa_p` is removed. No rendered change.

### G02-07. pstat() prints whole-valued non-count statistics without decimals, giving mixed precision

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/06_manuscript_helpers.R:90`
- **Fix:** Replace :90 with `if (is.numeric(v)) apa_num(v, digits = digits) else as.character(v)`. Every count call already passes digits = 0, and apa_num(n, 0) prints the same string as as.character(n), so no current rendered value changes. Re-render both papers and diff the demographic paragraphs to confirm.
- **Status:** resolved in 9c5c273: `pstat` formats every numeric value with `apa_num(digits)`. All 19 calls in both papers give identical output on the committed `_participants.csv`.

### G02-12. n_events in _task_durations_home.csv counts distinct timestamps, not events (ahsw7 Stroop: 237 events, 120 written)

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `_shared/R/07_task_durations.R:146`
- **Fix:** Add 'Event Index' to the cols read at :135. Carry it into d, then de-duplicate on (participant_home_ID, Event Index, event_ts_ms) before counting. This still removes identical rows duplicated across export files. Alternatively, rename the column n_distinct_timestamps. Either way, document the column, and preferably add the whole _task_durations_home table to the codebook.
- **Status:** resolved in 9c5c273: `n_events` now counts distinct (Event Index, timestamp) pairs. On the current data: 108/351 rows change, total 416,641→427,048. Durations are identical. Codebook updated. Step 13 cannot run on the cluster until the decoding jobs end, because it needs the held-back 03_data_manifest.R.

### G02-14. Local and git file listings differ: local non-recursive and case-sensitive, git recursive and case-insensitive

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/07_task_durations.R:53`, `_shared/R/07_task_durations.R:45-46`, `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:57`
- **Fix:** In the git route, keep only direct children: `tracked <- tracked[dirname(tracked) == rel_dir]` after :54, or drop -r from ls-tree and append a trailing '/' to rel_dir. Use one case rule in both routes, for example list.files(..., ignore.case = TRUE) locally, or drop ignore.case in the git route.
- **Status:** resolved in 9c5c273: One rule for both routes (`les_data_list`): direct children only, ignoring case. git and disk listings are identical (tested).

### G03-08. The -O1 pin test is a bare prefix match, so a CXXFLAGS_OPTIM_* line would suppress the pin and fake the log

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/hpc/arc_env.sh:116`
- **Fix:** Anchor the name in both places: `grep -qsE '^[[:space:]]*CXXFLAGS_OPTIM[[:space:]]*[:+?]?='` at arc_env.sh:116 and :120. Update the 111-115 comment to say the test matches the exact variable, not CXXFLAGS_OPTIM_TBB or CXXFLAGS_OPTIM_SUNDIALS.
- **Status:** resolved in 5b50d49: The check uses the anchored ERE `^[[:space:]]*CXXFLAGS_OPTIM[[:space:]]*[:+?]?=`. On ARC it matches `make/local` line 3 and does not match `CXXFLAGS_OPTIM_TBB`.

### G03-09. arc_env.sh uses `exit` and `module purge` though the docs tell users to source it in an interactive shell

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/hpc/arc_env.sh:77`, `_shared/hpc/arc_env.sh:127`
- **Fix:** Exit only in non-interactive shells, so batch jobs still stop: `if [[ $- == *i* ]]; then return 1; else exit 1; fi` at arc_env.sh:77 and :127. Add a header note that sourcing it purges loaded modules, cds to LES_CODE_ROOT and creates a `data` symlink there. Alternatively, as a docs-only fix, add that warning to HPC_RUNBOOK.md:79/105 and reconnaissance/README.md:22.
- **Status:** resolved in 5b50d49: `_les_fatal` returns in an interactive shell and exits in batch. Every call is followed by `\.

### G04-11. les_p1_drop_misfiltered() silently returns its input unchanged when the ID columns are absent

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/_config.R:166`, `paper_1_transfer/scripts/_config.R:152`, `paper_1_transfer/scripts/08_extract_decoding_matrices.R:305`, `paper_1_transfer/scripts/01_extract_erp_single_trials.R:116`
- **Fix:** 1. Do not change the helper while the banked decoding checkpoints are in use. 2. When the change is acceptable, replace _config.R:166 with `if (is.na(n_bad)) stop("les_p1_drop_misfiltered: input lacks participant_lab_ID and/or session", call. = FALSE)`. 3. Keep les_p1_misfiltered_rows() returning NA, because les_p1_write_fit_meta() relies on that for exempt data. 4.
- **Status:** resolved in aad57ed: `.les_p1_drop_listed()` stops when ID columns are absent. No caller passes such data, and the running decoding never takes the path. `les_p1_misfiltered_rows()` keeps NA. `les_p1_drop_protocol_deviation()` is deliberately unchanged because Paper 2 tables may lack the column. 2 tests added.

### G04-17. Fit-time metadata records structure from an env var that script 05 overwrites, and omits the retention-free tag

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/_config.R:261`, `paper_1_transfer/scripts/_config.R:277`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:139`, `paper_1_transfer/scripts/03_fit_brms_erp.R:295`
- **Fix:** (1) In qmd:308-310, exclude variants by the columns 05 now writes, not by the bare model id: filter on retention_free %in% FALSE and keep_misfiltered %in% FALSE, falling back to model_tag when present. (2) Re-run 05 on the pulled fits to regenerate _pooled_fit_metadata.csv with its structure, retention_free and model_tag columns.
- **Status:** resolved in aad57ed: 05:162-169 already re-derives structure/retention_free/model_tag from the cache tag. Remaining bug: `les_p1_misfilter_status()` counted the 12 informative-maximal retention-free records towards the 18. On the repo table that is 30 rows, so 6 primary + 12 retfree would have passed.

### G04-19. 00_extract_participants.R functions lack roxygen docstrings

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/00_extract_participants.R:80`
- **Fix:** Add one roxygen or plain comment block above les_extract_participants. It should state: no arguments; the files it reads (participant key, LHQ3 Aggregate and Raw workbooks, accuracy_*.rds, cognitive_indices.rds, learning_trajectory.rds, resting_state_eeg.rds, EEG_trial_count_per_condition.csv); the three CSVs written to both papers' results/;
- **Status:** resolved in aad57ed: `#'` on every 00 function.

### G04-21. 00d_extract_training_gate_flow.R functions lack roxygen docstrings

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/00d_extract_training_gate_flow.R:109`
- **Fix:** Extend the existing comments rather than restating them. Above classify_gate, list the five return labels and state the precedence (passed_attempt2 > passed_attempt1 > failed_gate > completed_test_no_gate, with no_data when no sequence and no scored judgements exist), including that any unrecognised sequence falls through to completed_test_no_gate.
- **Status:** resolved in aad57ed: `#'` on 00d functions, including `classify_gate`'s 5 labels, precedence and fall-through.

### G04-23. 00c uses dplyr::recode(), superseded in the pinned dplyr 1.2.1

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/00c_extract_erp_retention.R:96`
- **Fix:** Optional, with sign-off: `grammatical_property = replace_values(grammatical_property, from = names(PROPERTY_LABEL_TO_KEY), to = unname(PROPERTY_LABEL_TO_KEY))`. Do not use the `!!!` splice, which errors. Keep the stopifnot at :105 as the unmapped-label guard, then re-run 00c and confirm both CSVs are byte-identical.
- **Status:** resolved in aad57ed: `recode()` replaced by base indexing on `PROPERTY_LABEL_TO_KEY` in 00c; unmapped labels give NA, which the checks refuse.

### G04-25. Demographic metrics are named sex_* but are read from the LHQ3 'Gender' item

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/00_extract_participants.R:339`
- **Fix:** Make one coordinated change with sign-off: rename the metrics to gender_female, gender_male, gender_nonbinary and gender_undisclosed in 00_extract_participants.R:339-343 and fix the header at :42. Regenerate both _participants.csv files by re-running 00.
- **Status:** resolved by decision (17 October 2026): the keys keep their names, since renaming them changes both manuscripts, both participant tables and the codebook for no change a reader sees; the codebook now says the sex_* rows count the LHQ3 Gender item (self-reported gender), and Paper 2 now says 'identified as', as Paper 1 does.

### G05-06. The legacy importer leaks a full raw copy into .GlobalEnv that rm(raw); gc() in 01/07/07b never frees

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/01_extract_erp_single_trials.R:245`, `paper_1_transfer/scripts/07_extract_grand_average_waveforms.R:62`, `paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R:70`, `paper_1_transfer/scripts/01_extract_erp_single_trials.R:208-209`
- **Fix:** Immediately after each merge_trialbytrial_EEG_data() call in 01 (L214), 07 (L41), 07b (L47) and 08 (L460), not only before the final gc(), add `if (exists("trialbytrial_EEG_data_temp", envir = .GlobalEnv, inherits = FALSE)) rm("trialbytrial_EEG_data_temp", envir = .GlobalEnv)`.
- **Status:** obsolete: every caller uses the vendored `les_p1_merge_trialbytrial()` (8f0fb8b), which assigns nothing to the global environment.

### G05-08. Hemisphere coding differs between sibling outputs: 07c writes 'midline', 07/07b write NA

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/07c_extract_electrode_coordinates.R:173`, `paper_1_transfer/results/CODEBOOK.md:49`, `paper_1_transfer/results/CODEBOOK.md:67`
- **Fix:** Least invasive: note the coding difference in CODEBOOK.md:49 (07c writes 'midline' where the grand-average files carry NA). To unify, change 07c:173-174 to NA_character_, rewrite L199-200 with `%in%` (for example `elec$x[elec$hemisphere %in% "left"]`) so the checks still pass, regenerate _electrode_coordinates.csv locally with sign-off, and update CODEBOOK.md:49.
- **Status:** resolved in aad57ed: 07c writes `hemisphere = NA` for the midline clusters, matching the importer and 07/07b; checks use `%in%`. The qmd uses only electrode/x/y/theta from the file (3402-3405). 07c still has to be rerun on the cluster, where the data tree is; 00_descriptives does not run it.

### G05-09. 07c departs from the pipeline conventions: no sys.nframe() entry guard and no les_assert_readonly_data before its write

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/07c_extract_electrode_coordinates.R:211`
- **Fix:** Add `les_assert_readonly_data(out)` between 07c:211 and :212. Optionally, for consistency, wrap L96-215 in `.run <- function() {...}` behind `if (sys.nframe() == 0L) .run()`. Output is unchanged either way.
- **Status:** resolved in aad57ed: 07c is wrapped in `.run()` behind `sys.nframe()` and calls `les_assert_readonly_data(out)` before the write.

### G05-10. Dead variable `key` in 07c is computed and never used

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/07c_extract_electrode_coordinates.R:124`
- **Fix:** Delete 07c:124.
- **Status:** resolved in aad57ed: Dead `key` in 07c deleted.

### G05-11. 01b drops rows with fewer than two displayed words without counting them in any exclusion tally

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/01b_extract_rsvp_timing.R:203`
- **Fix:** Delete 01b:203 so that such rows fall through to missing_onset (L206) or no_following_word (L207). Both exits handle n_words of 0 or 1 safely: seq_len(0) gives an empty onset vector, and cp >= n_words then holds. Alternatively, add a too_few_words entry to `excl` at L166-167 and document it in CODEBOOK.md. On current data neither changes any value.
- **Status:** resolved in aad57ed: 01b `if (n_words < 2L) next` deleted; such rows now fall to `missing_onset`/`no_following_word`. No value changes on current data (per entry; 01b is a census, not ERP/decoding extraction).

### G05-12. n_duplicate_rows is documented as byte-identical repeats but keyed only on file x trial x critical onset

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/01b_extract_rsvp_timing.R:218`, `paper_1_transfer/results/CODEBOOK.md:478`
- **Fix:** Do not change the key. Reword 01b:82-86 and CODEBOOK.md:478 to say: n_duplicate_rows counts rows that repeat another row's file, trial number and critical-word onset. In practice this is the final row of 107 logfiles, which re-logs the last trial at session close with its response, accuracy and session-end timing fields rewritten, so the rows are not byte-identical.
- **Status:** resolved in aad57ed: 01b header reworded (repeat of file × trial × onset; 107 logfiles; not byte-identical). Codebook patch below.

### G05-13. RSVP counting window of 900 ms is a separate literal from the late window's inclusive bound of 898 ms

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/_config.R:90`, `paper_1_transfer/scripts/01b_extract_rsvp_timing.R:241`, `paper_1_transfer/scripts/01b_extract_rsvp_timing.R:217`
- **Fix:** Change only the comment at _config.R:87-88 to say that 900 is the late window's nominal upper bound, matching the manuscript's 'within 900 ms', and that it is deliberately not the inclusive sample bound 898 (see :45-53). Do not derive the value from max_ms. Schedule the edit with the decoding cache in mind: it changes _config.R's mtime, which 08's tensor fingerprint stats.
- **Also reported as:** G04-24
- **Status:** resolved in aad57ed: `_config.R` RSVP comment: 900 = nominal bound, deliberately not 898.

### G05-16. 01 lacks roxygen docstrings on its functions, including the file-writing extract_paper1_property_macroregion

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/01_extract_erp_single_trials.R:200`
- **Fix:** Treat this as a single codebase-wide convention decision, not a per-file patch. Either adopt roxygen for non-trivial functions across the live surface, or record in _shared/R/README.md that script-local functions use banner comments. If 01 is edited, extend the existing banners instead of duplicating them.
- **Status:** resolved in aad57ed: `#'` on 01's 4 functions (comments only; nothing extracted changes).

### G05-17. 01b lacks roxygen docstrings on build_rsvp_timing and its helpers

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/01b_extract_rsvp_timing.R:145`
- **Fix:** Fold this into the codebase-wide convention decision described under G05-16. If 01b is edited, add to build_rsvp_timing's banner a short return description: a 16-field named list, noting that n_trials_by_session is a table and n_rows_excluded a named integer vector.
- **Status:** resolved in aad57ed: `#'` on `build_rsvp_timing` (16-field list, table/named vector), `.read_one_logfile`, `.les_rsvp_timing_row`.

### G05-19. 07b lacks a roxygen docstring on grand_average_electrode_one, which writes a results CSV

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R:44`
- **Fix:** Add a short roxygen block to grand_average_electrode_one (07b:44) that does not repeat the file header: - a one-line purpose; - @param property: one of the property values in les_p1_erp_grid(); - @param macroregion: 'lateral' or 'midline'; - @return: the output CSV path, returned invisibly;
- **Status:** resolved in aad57ed: `#'` on all 07b functions.

### G06-13. 03 .run() silently fits the full 18-cell grid when given one or two positional arguments

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/03_fit_brms_erp.R:309`
- **Fix:** In .run(), accept exactly 0 or 3 trailing arguments and otherwise stop with the usage line, for example: `if (!length(args) %in% c(0L, 3L)) stop("Usage: Rscript 03_fit_brms_erp.R [property window macroregion]")`. A cheap `stopifnot(args[[1]] %in% names(LES_P1_PROPERTIES), args[[2]] %in% names(LES_P1_WINDOWS), args[[3]] %in% LES_P1_MACROREGIONS)` is optional;
- **Status:** resolved in 4a545e7: 03 `.run()` accepts exactly 0 or 3 arguments and checks the cell against `les_p1_erp_grid()` (tested: 1 or 2 arguments and a misspelt cell all stop).

### G07-03. Retention-free rows reuse the S4->S6 contrast keys for a different estimand (Session-6 deviation from trend)

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:208`, `_shared/R/codebook_descriptions.csv:151`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:15`
- **Fix:** Documentation only. (a) Reword _shared/R/codebook_descriptions.csv:151 so the estimand depends on the model tag. Suggested text: 'For untagged fits, the change in the grammaticality effect from Session 4 to Session 6, (z6 - z4) * (b_gram:session + b_gram:session:lang * l).
- **Status:** resolved in 4a545e7 and the codebook.

### G07-06. Step 5 deletes the tracked _prior_sensitivity.csv when no fits are present but leaves its other outputs stale

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:466`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:98`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:324`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:366`
- **Fix:** At the top of .run() in 05, stop() with a clear message when paper1_results() holds no *_summary.rds and no *_convergence.rds (for example 'no fitted artefacts under &lt;dir>; step 5 runs where the fits are, see HPC_RUNBOOK.md'). The script then fails closed without touching any output.
- **Status:** resolved in 4a545e7: `.run()` stops before writing anything when results/ holds no `*_summary.rds` or `*_convergence.rds` (tested).

### G07-11. Nine functions in step 5 lack roxygen docstrings (parameters, return value, file writes and deletion)

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:77`
- **Fix:** Decide once, codebase-wide, whether R functions take roxygen #' blocks or keep the established banner-comment convention, and record the decision. For 05 specifically, and in whichever format is chosen, add the missing parameter and return descriptions to retention_contrast (fit: a brmsfit;
- **Status:** resolved in 4a545e7: `#'` blocks (purpose, @param, @return, files written or deleted) on all 13 functions in 05.

### G07-12. les_literature_trend() has no docstring; API calls, readRenviron side effect and CSV write undocumented

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/10_extract_literature_trend.R:59`
- **Fix:** Use the repo's plain `#` comment style, not roxygen (no file in the repo uses #'). Extend the comment block at 10:55-58 so it also says: - years: integer vector of completed publication years. - Return value: invisibly, a data.frame with columns stratum, year, n and query, 3 x length(years) rows. - Side effects: one Scopus count request per row (63 with the default);
- **Status:** resolved in b2f67f0.

### G07-14. Step 5 comments: incomplete output and tag lists, a hard-coded '75 cells' count, a misleading skip message

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:13`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:52`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:100`, `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:195`
- **Fix:** Edit comments only: (1) add '(6) first-session language advantage -> results/_first_session_language_advantage.csv' to the header at 05:13-17. (2) At 05:100-101, add _diversity: an accuracy-only data tag that composes before _weakprior (04:96-97).
- **Status:** resolved in 4a545e7: Header lists outputs (6) and (7). The hard-coded "75 cells" is gone. The pool tag list includes `_diversity`, `_maxranef` and `_byitem`. The retention skip message is accurate ("absent, or z code not unique").

### G07-16. .les_summarise_draws duplicates les_posterior_summary's CI and pd definitions

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:77`, `_shared/R/02_diagnostics.R:89`
- **Fix:** Add one exported draw-vector summariser to _shared/R/02_diagnostics.R, for example les_summarise_draw_vector(x, ci = 0.95), returning median, ci_low, ci_high and pd. Call it from les_posterior_summary(), from 05's .les_summarise_draws (or replace that helper), and from 06_summaries.R derive_predictor_contrasts().
- **Status:** resolved: `les_summarise_draw_vector()` in 02_diagnostics.R is the one summariser (9c5c273).

### G07-21. Literature script header says it is skipped without an API key, but it stops with an error

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/10_extract_literature_trend.R:39`, `paper_1_transfer/README.md:31`, `paper_1_transfer/scripts/10_extract_literature_trend.R:62`
- **Fix:** Edit the header at 10:39-41: without scopusflow or an Elsevier key the script stops with an error and writes nothing, the manuscript keeps reading the committed _literature_trend.csv, and it shows placeholders only if that file is absent.
- **Status:** resolved 2026-09-16: the script header and both live README descriptions now
  state that a missing package or key stops extraction without replacing the committed
  counts, and that placeholders appear only if the committed file is absent.

### G08-03. 09b skips the tensor-provenance check where it is documented to run, and its size check cannot catch a rebuild

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/09b_assemble_confirmatory_timecourse.R:107`
- **Fix:** Reword the stops at 09b:110-111 and 114-115 to say the tensor was modified or copied after step 08 recorded it (not 'after the block was banked'). Leave the mtime ordering at 116 as the rebuild guard and say so in the comment at 101-104.
- **Status:** resolved in d9d9fab: Superseded by the 09b rewrite: the provenance check is now mandatory (missing sidecar stops), messages say "modified or copied after step 08 wrote it", and the digest is recomputed. Also found: the old mtime check used `all.equal(tolerance = 1e-6)`, a RELATIVE tolerance of ~30 min on an mtime of 1.8e9 s.

### G08-04. Pooled permutation shuffles within participant across sessions, so null ignores session–class imbalance

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/09_run_decoding.R:233`, `paper_1_transfer/scripts/09_run_decoding.R:203`, `paper_1_transfer/scripts/09_run_decoding.R:448`
- **Fix:** No rerun. Add a short note to the 09 header (at the CHANCE BY PERMUTATION bullet, 09:57-61) and to the manuscript's decoding method or the analytic-decisions appendix. It should state that labels are exchangeable within participant rather than within participant x session, and that the per-session Ungrammatical share is balanced across participants (about 0.49-0.51 in every ses ...
- **Status:** resolved: 09's header (d9d9fab) and the Method (2e89d05) say the labels were exchangeable within participant, not within participant and session.

### G08-08. Cross-language/property AUC pools participants, so prevalence and offsets can move it, unlike the per-participant time-course AUC

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/09_run_decoding.R:512`, `paper_1_transfer/scripts/09_run_decoding.R:746`, `paper_1_transfer/scripts/09_run_decoding.R:790`
- **Fix:** Minimal: state that the generalisation AUC is pooled over test participants, and is therefore not prevalence-free or on the same footing as the per-participant time-course AUC, in 09:52-56 and 09:501, codebook_descriptions.csv:194 and 200, and the manuscript (qualify qmd:2184-2186 so the prevalence claim covers the time-course only, and add a clause at qmd:2806-2813).
- **Status:** resolved: 09 (d9d9fab), the Method (2e89d05) and the codebook (b2f67f0) say the generalisation AUCs are pooled over test participants.

### G08-17. A channel count other than the documented 31 only warns, and the tensor is written anyway

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/08_extract_decoding_matrices.R:363`
- **Fix:** Enforce the count outside the fingerprinted builder: in extract_paper1_decoding() after the build (stop if dim(built$X)[2] != LES_DECODE_N_EEG unless an explicit override env var is set), and/or in 09's .les_load_decoding()/.les_complete_trials(), which also covers cached tensors (09's checkpoint fingerprint does not deparse code). Keep the builder's warning as is.
- **Status:** partly resolved: 08 stops before writing a tensor of the wrong width (d9d9fab), so 09 can load only a tensor 08 accepted. The matching check in 09's loader is deferred to the next decoding run, for the reason given under G08-02 (decided 26 October 2026).

### G08-18. 09b header and READMEs describe checks it lacks (plural checkpoints, column-set match)

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/09b_assemble_confirmatory_timecourse.R:148`, `paper_1_transfer/README.md:30`, `paper_1_transfer/scripts/README.md:74`
- **Fix:** Reword README.md:30 and scripts/README.md:74 to describe what 09b does: one banked overall checkpoint, whose fingerprint B is checked against its own n_perm, plus exploratory rows carried from the existing CSV. Fix 09b:42-44 to match the one-directional column check, or make the check symmetric.
- **Status:** resolved: 09b's header (d9d9fab) and both READMEs (b2f67f0) describe what it checks.

### G09-09. SLURM .out logs are untagged in 01-04, so variant resubmissions overwrite the mainline environment record

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/03_fit_erp.slurm:27`, `paper_1_transfer/hpc/01_extract_erp.slurm:20`, `paper_1_transfer/hpc/02_extract_accuracy.slurm:17`, `paper_1_transfer/hpc/04_fit_accuracy.slurm:18`
- **Fix:** Change the four -o paths to `%A_%a` (01, 03, 04), or add `%j` to the single-job 02 (for example `02_extract_accuracy_%j.out`), as 08b:32 and 08:37 already do. Alternatively, narrow the comments at 01:27-28, 02:24-25, 03:37-39 and 04:35-36 so they say only the .Rout logs are tagged. No documentation references these .out names, so nothing else needs updating.
- **Status:** resolved in 1533b4a.

### G09-10. Log tag names and order differ from the artefact tags, and the log extensions are inconsistent

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/04_fit_accuracy.slurm:39`, `paper_1_transfer/hpc/03_fit_erp.slurm:42`, `paper_1_transfer/hpc/00_install_dependencies.slurm:42`
- **Fix:** In 03, build TAG in cell_tag order: _keepmisfiltered, _weakprior, _itemslope, _retfree. In 04, use `_weakprior`. Compare case-insensitively in both, for example `[ "${LES_PRIOR_SET,,}" = "weak" ]` with a `:-informative` default in each file.
- **Status:** resolved in 1533b4a.

### G09-14. 08's walltime comment freezes a live-run projection and keeps a 14-day wall it describes as the bare minimum

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/08_decoding.slurm:53`
- **Fix:** Replace 08:53-57 with the measured outcome of the B=1000 run for each property: VONA 4 d 15 h, DOM 7 d 15 h, and what actually happened to the gender element. State that per-block and within-block checkpoints (LES_DECODE_CKPT_EVERY) make a timeout resumable.
- **Status:** resolved in d9d9fab: Walltime comment replaced by measured outcomes (VOA 4 d 15 h / 4 d 21 h, DOM 7 d 15 h / 7 d 12 h, gender's remainder 7 d 17 h on 8736986_0) and the resumability statement.

### G09-15. 08's resourcing rationale (BLAS threads for small cov/solve calls) is not supported by the decoder, which is single-threaded

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/08_decoding.slurm:26`
- **Fix:** First, rewrite the comment at 08:25-28 to say what is known: the decoder is single-threaded R, stats::cov does not use BLAS, and the 8 CPUs mainly buy memory through --mem-per-cpu. Once the banked decoding work has finished, measure CPU efficiency with `seff` or sacct TotalCPU/Elapsed.
- **Status:** resolved in d9d9fab: Resourcing comment now states the measured single-threadedness (TotalCPU ~ Elapsed on 8 CPUs for 8829254_1/_2), that the CPUs buy memory, and the measured extraction peaks (195 GB, 117 GB, gender killed at 254 GiB).

### G09-16. Carpenter et al. (2017) is cited for reduce_sum within-chain threading, which it predates

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/03_fit_erp.slurm:13`, `paper_1_transfer/hpc/README.md:148`
- **Fix:** At 03_fit_erp.slurm:13 and hpc/README.md:148, follow 01_bayesian_settings.R:25-27. Cite the Stan User's Guide chapter on reduce_sum/within-chain parallelisation (and optionally brms's threading() vignette) for the thread arithmetic, and keep Carpenter et al. (2017) for Stan in general only.
- **Status:** resolved in 1533b4a.

### G09-17. Job headers and the README pipeline table under-list what 00_descriptives, 02 and 05 write

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/05_summaries.slurm:5`, `paper_1_transfer/hpc/README.md:80`, `paper_1_transfer/hpc/00_descriptives.slurm:8`, `paper_1_transfer/hpc/02_extract_accuracy.slurm:5`
- **Fix:** List every results file in the headers of 05_summaries.slurm, 02_extract_accuracy.slurm and 00_descriptives.slurm, and in hpc/README.md:80, copying paper_1_transfer/README.md:21 and :24. Or replace the lists with a pointer to that table, so the list lives in one place.
- **Also reported as:** G07-15
- **Status:** resolved: 00_descriptives' header lists every file, the README points to it, and 02's header names its tables (1533b4a, b2f67f0).

### G09-19. submit_all.sh ignores an unrecognised first argument and submits the chain unprovisioned

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/submit_all.sh:50`
- **Fix:** Add `'') ;; *) echo "unknown option: $1 (expected with_restore or with_install)" >&2; exit 1 ;;` to the case at submit_all.sh:50-61. Add the matching `else` branch (`elif [[ -n "${1:-}" ]]; then echo ... >&2; exit 1`) to paper_2_plasticity/hpc/submit_all.sh:57-65.
- **Status:** resolved in 1533b4a for both papers.

### G09-21. 00_descriptives gives script 02 plus two others 1 hour, where 02's own job requests 2 hours

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/00_descriptives.slurm:25`
- **Fix:** Pull sacct Elapsed for 8723088, 8723344 and 8725134 and record it in the header of 00_descriptives.slurm. Then reconcile the two walltimes against those measurements. Most likely 02_extract_accuracy.slurm's 2 hours is simply generous; raise 00_descriptives' 1 hour only if the measured total approaches it.
- **Status:** resolved in 1533b4a: the four scripts took 98 s (HTC 8976030).

### G09-22. The threads-per-chain and CPU request are hand-coupled to LES_CHAINS in R, not derived

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/03_fit_erp.slurm:35`, `paper_1_transfer/hpc/04_fit_accuracy.slurm:26`
- **Fix:** Do not derive the thread count from the allocation. Keep LES_THREADS_PER_CHAIN pinned. Add a non-fatal check, in les_brm() or in the slurm before Rscript, that warns when LES_CHAINS * threads differs from SLURM_CPUS_PER_TASK. Add a comment beside the export saying the thread count sets brms's grainsize in the Stan data, so changing it invalidates the cached fits under file_refi ...
- **Status:** resolved in 1533b4a: the thread count stays pinned, and a mismatch is reported.

### G09-23. Decoding defaults for NPERM and time step are repeated as literals, but only the seed copy is cross-checked

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/08_decoding.slurm:75`, `paper_1_transfer/scripts/09_run_decoding.R:123`, `paper_1_transfer/scripts/08_extract_decoding_matrices.R:105`, `paper_1_transfer/hpc/08b_verify_gender_decoding.slurm:74`
- **Fix:** Keep the slurm exports, which the provenance printf needs under nounset. Extend test_exclusion_guard.R to read back and compare the NPERM literal in 08_decoding.slurm and 09_run_decoding.R, and the TIME_STEP literal in 08_decoding.slurm and 08_extract_decoding_matrices.R.
- **Status:** resolved: 08_decoding.slurm names its defaults once (d9d9fab), and test_exclusion_guard.R checks the copies in 09, 08b and 08 (b2f67f0).

### G10-04. IAF note says only participants 12 and 41 lack a specparam peak; committed artefact shows six, so the _iafres scope is too narrow

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/03_extract_resting_state_eeg.R:155`
- **Fix:** Documentation only. Reword 03:155-159 to say that specparam fits no alpha peak in six eyes-closed recordings (12, 20, 28, 41, 51, 65; 07_aperiodic_features.csv), that 12 and 41 are also floor-pinned by the argmax while the other four carry interior values, and that the IAF-resolved refit excludes the floor-pinned pair because they sit at the extreme of the predictor range.
- **Status:** resolved in 2352752: 03:187-206 and 04:117-129: six recordings without a specparam alpha peak (12, 20, 28, 41, 51, 65), 12 and 41 floor-pinned; verified in `07_aperiodic_features.csv` and `_predictor_values.csv`. Also corrects the G12-18 wording about 10's count.

### G10-12. Band power integrates [lo, hi-0.5 Hz]: 0.5 Hz gaps between adjacent bands; comment and main text say [lo, hi)

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/03_extract_resting_state_eeg.R:126`
- **Fix:** Take this to the author, because both options touch an end product. (a) Keep the code. Reword the comment at 03:126 to say the trapezoid runs over bins in [lo, hi), so the integral covers [lo, hi - df] (0.5 Hz short at the top of each band). Have the main-text Method (qmd:552-553) point to S2 for the exact integration rule.
- **Status:** resolved: 03 states the integration range (2352752), and supplement S2 says each integral stops 0.5 Hz below the band's upper edge (b2f67f0). Keeping the range is recommended, because changing it refits every Part A model.

### G11-12. 04 labels convergence records and log lines of variant fits with the untagged model id

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/04_fit_brms_predictors.R:382`
- **Fix:** Compute `model_tag` before the 04:357 message. Use it in that message, in `label = model_tag` at 04:382, and in the 04:390 message. Make the same change in paper_1_transfer/scripts/03_fit_brms_erp.R:280 (`label = cell_tag`) and 04_fit_brms_accuracy.R:122 (`label = model_tag`) so the convention is uniform.
- **Status:** resolved in 2352752 (Paper 2) and b2f67f0 (Paper 1's convergence labels).

### G11-14. Reliability divides by the squared posterior mean of the SD rather than the posterior mean of the variance

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/06_summaries.R:159`
- **Fix:** Have the author choose the tau^2 point estimate explicitly. If it changes, use `var(ui) / mean(sd_draws^2)`, with the draws taken from `sd_participant_lab_ID__<term>` via `as_draws_df`. Do not average the per-draw ratios. State the choice in the comments at 06:146 and 06:155-159 and in the Method sentence at qmd:673-675.
- **Status:** resolved by decision (17 October 2026): the squared posterior mean of tau stays (the alternative lowers the reliabilities by about .01), and the Method now states it.

### G12-07. Fit-quality flags are emitted but never used; QC plots show only fits with R2 > 0.9

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/07_extract_aperiodic.R:86`, `paper_2_plasticity/scripts/07_extract_aperiodic.R:430`, `paper_2_plasticity/figures/README.md:13`
- **Fix:** Do not adopt a post hoc R2 exclusion rule, least of all before G12-05 is fixed. Rewrite 07:86-88 to say r_squared and fit_error are diagnostics, not a selection criterion. Change the QC plot selection at 07:430 to a deterministic spread (e.g. the lowest, median and highest r_squared) so poor fits are drawn, and update figures/README.md:13-18 to match.
- **Status:** resolved in 2352752: 07:98-111 r_squared/fit_error are diagnostics, not a criterion; 07:569-583 plots lowest, median and highest R^2. Found: every QC plot had failed, because `grDevices::capabilities()` does not exist (07:456 now `base::capabilities`); the store holds two 0-byte PNGs from July.

### G12-08. write_task_specs reads exports differently from 01: batch-only, no de-dup, ASRT practice rows counted

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/10_extract_descriptives.R:343`, `paper_2_plasticity/scripts/10_extract_descriptives.R:361`, `paper_2_plasticity/scripts/10_extract_descriptives.R:391`, `paper_2_plasticity/scripts/10_extract_descriptives.R:401`, `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:83`
- **Fix:** In write_task_specs, reuse 01's .les_read_bind (batch-priority plus named-only participants) and its participant-key filter, so descriptives and indices describe the same participant set. Compute ASRT trials per block on is_practice == 0 rows.
- **Status:** resolved in 2352752: `write_task_specs()` reads through 01's `.les_p2_files`/`.les_read_bind` (batch priority, named-only, distinct), keeps enrolled participants (key) less P14, drops ASRT `is_practice == 1` rows and drops Stroop practice with 01's `.les_drop_practice`. The rerun is done (HTC 8976035) and was pulled in 51bdb75.

### G12-15. ASRT trials_per_block = 85 is a literal injected as a task spec; data give 87 rows or 74 H/L triplets per block

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/10_extract_descriptives.R:371`
- **Fix:** Keep 85. Rewrite the note as a design value with its source, for example 'design value: 85 trials per block after two leading random warm-up trials (session_materials/README.md; osf.io/tjr54)', and drop 'scored'. Optionally, emit a warning when an observed modal count (digit span, Stroop) differs from its expected literal. Do not derive trials_per_block from the export.
- **Status:** resolved in 2352752: The 85 stays as a design value. Note: "design value, not counted from the export: 25 blocks of 85 trials (session_materials/README.md; preregistration osf.io/tjr54)". `add(expected=)` warns when an observed count departs from the design (25, 48, 100, 50, 50).

### G12-16. Committed _task_specs.csv (2026-07-06) was not written by the current code: its ASRT note text differs

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/results/_task_specs.csv:4`
- **Fix:** When job 8782463 (10_descriptives.slurm) lands, pull back its _task_specs.csv and commit it with author approval. Scope the pull to this file, or commit it together with the rest of the Stroop refit chain: the same job also rewrites _cognitive_descriptives.csv and the other descriptives under the new Stroop index (SETTLED item 2).
- **Status:** resolved: _task_specs.csv was rewritten by the current code (HTC 8976035) and pulled in 51bdb75.

### G12-18. The 'resolvable alpha peak' count counts participant 23, whom 03 says has a genuine peak, as lacking one

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/10_extract_descriptives.R:169`, `paper_2_plasticity/scripts/03_extract_resting_state_eeg.R:157`
- **Fix:** Now, comments only: correct 10:155-156 and 10:169-173 to say the count is of recordings whose argmax lies strictly inside 7-13 Hz, and that participant 23 is excluded from it despite a genuine low peak. Correct 03:157-158 so it no longer says the descriptives report exactly 12 and 41.
- **Status:** resolved in 2352752: 10:201-208: the count is of argmax strictly inside 7-13 Hz, and P23 is excluded despite a genuine 7.2 Hz specparam peak. Verified in `07_aperiodic_features.csv`: 23 -> 7.205; 12 and 41 NA.

### G12-19. Robust 1/f trimming and peak-threshold constants are unsourced, attributed generically to Donoghue 2020

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/07_extract_aperiodic.R:195`
- **Fix:** Now: reword 07:74-76, 07:167-169 and 07:258-259 to describe the actual rule (iteratively drop points more than 1 SD above the current fit, at most max_iter times, never keeping fewer than max(5, 25%) of the bins, with the final refit robust as well) as this project's adaptation of the approach in Donoghue et al. (2020), not as its published procedure.
- **Status:** resolved in 2352752: 07:88-97, 07:210-219 describe the actual rule (one-SD trim, max_iter, max(5, 25%) floor) as this project's adaptation; specparam's percentile rule contrasted.

### G12-20. Low-pass corner and order are unsourced literals repeated in prose; 12 passes mode but hard-codes fixed

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/12_extract_gamma_attenuation.R:59`
- **Fix:** In 12, fit with mode = "fixed" explicitly, or add `stopifnot(identical(LES_AP_SETTINGS$aperiodic_mode, "fixed"))` before the fit. Add a comment at 12:59-60 pointing to the Analyzer record as reported in Paper 1's Method and supplement S2. A shared config constant is optional. No output value changes.
- **Status:** resolved in 2352752: The corner and order are sourced to the history node and filters.py. `.fit_background()` names `mode = "fixed"`. The transfer function is corrected (see G12-01). The rerun is done (HTC 8976035) and was pulled in 51bdb75.

### G12-22. Accuracy-trajectory n_participants is computed then dropped; the PSD writer lacks the empty-input guard 03/07 have

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/10_extract_descriptives.R:282`
- **Fix:** Delete 10:282, or with sign-off emit n_participants and add it to the codebook. In write_resting_state_psd, add `if (!length(rows)) stop("[descriptives] no eligible Session-2 resting-state recordings under ", root)` after the loop. Use stop(), not a return, so that a stale _resting_state_psd.csv is never left looking current for script 12.
- **Status:** resolved in 2352752: Deleted the dead `n_participants` in `group_cell` (dropped by `select`); the block comment says the participant_cell rows give the count. The PSD writer stops when no recording qualifies.

### G13-13. Missing roxygen docstrings in 08b_recover_projpred_path.R (.recover_fold_count, .recover_projpred_paths)

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/08b_recover_projpred_path.R:61`
- **Fix:** Do not add roxygen blocks to this file alone. Follow the project's plain-comment convention, or make a repo-wide decision to adopt roxygen. Minimal change: add one line to the existing comment at 08b:47-60 giving the return value, list(k = &lt;int>, n_participants = &lt;int>, source = '08 summary' | 'transcribed').
- **Status:** resolved in 2352752: 08b: plain-comment contracts for `.recover_fold_count` (return list) and `.recover_projpred_paths`.

### G13-15. Missing docstrings in 09c (compare_grouped, kf_cached, .pw)

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/09c_compare_aperiodic_grouped.R:89`
- **Fix:** Do not add roxygen blocks to the nested closures. Document kf_cached's cache format and invalidation rule as part of applying ISSUES.md #2's fit-identity stamp, so the comment describes the contract that will actually hold. Separately, add results/_kfold_&lt;model>.rds (list(kf, folds), reused when the folds match) to the Outputs section at 09c:53-55.
- **Status:** resolved in 2352752: 09c: contracts for `compare_grouped`, `kf_cached` (cache format and invalidation rule) and `.pw`. `_kfold_<model>.rds` added to Outputs.

### G13-18. 09c's per-stratum write rebuilds the CSV from this run only, dropping a valid prior row on a partial run

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/09c_compare_aperiodic_grouped.R:214`
- **Fix:** Do not add a stratum-keyed merge now. Add a comment at 09c:197-200 (and the slurm note) saying that each run rewrites _aperiodic_kfold_compare.csv from the strata it completes, so a partial run leaves only those rows and the manuscript prints its pending sentence.
- **Status:** resolved in 2352752: Comment in 09c `.run()` and the slurm: each run rewrites the CSV from its own strata.

### G13-19. 09b's raw_model column names the 56-participant fit, not the common-sample refit that 09c names

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/09b_compare_aperiodic_commonsample.R:111`
- **Fix:** Change 09b:111 to raw_model = paste0(raw_id, "_commonsample"), matching 09c:185. Update _shared/R/codebook_descriptions.csv:227 to the 09c wording and regenerate CODEBOOK.md:46. The committed CSV changes only when 09b next runs, which is already due after the Stroop refit; no number changes.
- **Status:** resolved in 2352752: 09b `raw_model = "<raw_id>_commonsample"`. The manuscript does not read this column. Codebook patch below.

### G13-23. 09b duplicates 04's resting-state term list and checks it only for set-equality with config

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/09b_compare_aperiodic_commonsample.R:51`
- **Fix:** Correct the comment at 09b:46-50: the order is irrelevant here because the formula comes from the cached fit. Optionally replace line 51 with RAW_NEURAL &lt;- paste0("z_", LES_P2_RS_MEASURES), and replace the silent intersect at 09b:67 with stopifnot(all(RAW_NEURAL %in% names(fit_raw$data))). Neither change alters the Stan data or code, so no refit or number change follows;
- **Status:** resolved in 2352752: RAW_NEURAL removed. The joined columns are now `setdiff(all.vars(fit_raw$formula$formula), names(fit_aper$data))`, with asserts that they exist and are constant within participant. Same columns, same order, so the brms cache still hits (tested).

### G14-05. submit_all.sh omits stages 10, 11 and 13, so re-running the chain after a change to 01 leaves their CSVs stale

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/hpc/submit_all.sh:83`, `paper_2_plasticity/hpc/README.md:112`
- **Fix:** Minimal fix, documentation only: - Rewrite hpc/README.md:112-114 to say that stages 10, 11 and 13 are outside the chain and submitted by hand, and that 10 and 11 must be re-run whenever 01, 02 or 03 is. Name stage 13 there too. - Add 10, 11 and 13 to Paper 2's list of hand-submitted stages in HPC_RUNBOOK.md:146-150.
- **Status:** resolved: the runbook lists the hand-submitted stages, and the HPC README says when to rerun them (913c035).

### G14-15. Split-half aggregation: n_splits column reports requested splits not splits averaged; unguarded SB; unexplained 10

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/scripts/11_extract_predictor_reliability.R:170`
- **Fix:** 1. Record the number of splits actually averaged: either write `n_splits = length(rs)`, or add a separate `n_splits_used` column and keep the requested count. 2. Emit a `warning()` naming the predictor whenever `length(rs) < LES_REL_SPLITS`. 3. Add a one-line comment giving the rationale for the 10-pair floor.
- **Status:** resolved in 2352752: `n_splits` = splits actually averaged; a warning when fewer than `LES_REL_SPLITS`; `.sb()` NA at r <= -1; `LES_REL_MIN_PAIRS <- 10` with its rationale.

### G15-05. Gamma-attenuation fallback text prints 'about a third' when the artefact's median is 6.5%

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/manuscript_setup.R:183`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:570`
- **Fix:** Replace the else branch at manuscript_setup.R:183-185 with a pure pending marker that has no numbers, for example "the retained power across that band \*[pending the gamma-attenuation artefact]*". Also change the header comment at lines 159-160, which says the prose 'falls back to a marked approximation', to say it falls back to a pending marker.
- **Also reported as:** G12-17
- **Status:** resolved: the fallback prints a marker.

### G15-06. Seed fallback prints the literal 20260607 where every other provenance field prints a pending marker

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/paper_2_neuroplasticity.qmd:805`
- **Fix:** In both manuscripts (paper_2_plasticity/paper_2_neuroplasticity.qmd:805 and paper_1_transfer/paper_1_morphosyntax.qmd:3320), replace the literal fallback with a marker, e.g. `r prov("seed:LES_SEED", "*[seed pending a pipeline run]*")`. Current renders do not change, because the provenance row is committed.
- **Status:** resolved in 51bdb75.

### G15-11. Availability statement says pre/post and CV refits keep no environment record, but fit-meta records are written

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/paper_2_neuroplasticity.qmd:1630`, `paper_2_plasticity/scripts/05_fit_brms_prepost.R:102`, `_shared/R/04_provenance.R:29`
- **Fix:** 1. Add a helper in manuscript_setup.R, e.g. fitmeta_sentence(). It reads _pooled_fit_metadata.csv when present. - If the file holds the pre/post (p2_cognition_prepost_*) or *_commonsample ids, say those fits carry a per-fit record of the R, brms, cmdstanr and CmdStan versions. - If it is absent, or lacks them, say the fits reported here predate that record.
- **Status:** resolved in 913c035.

### G15-16. Largest weak-prior rate p_d prints as '.96' while every other p_d prints as a percentage like '95.3%'

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/manuscript_setup.R:516`
- **Fix:** Have sens_max_rate_pd() emit the whole maths expression on success, e.g. `paste0("$p_d ", .fmt_pd_pct(max(r$pd_weak, na.rm = TRUE), math = TRUE), "\\%$")`, and keep its current fallbacks. Change qmd:1150 from '(largest $p_d$ = `r sens_max_rate_pd()`)' to '(largest `r sens_max_rate_pd()`)'.
- **Status:** resolved in 51bdb75.

### G15-17. Four leading-zero strippers disagree on negatives, attainment keeps its leading zero, and fallbacks are mixed

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_2_plasticity/paper_2_neuroplasticity.qmd:1213`, `paper_2_plasticity/manuscript_setup.R:210`, `paper_2_plasticity/manuscript_setup.R:357`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:1217`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:1285`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:1502`
- **Fix:** Add one leading-zero stripper that preserves the sign, e.g. `.strip0 <- function(x, d = 2) sub("^(-?)0\\.", "\\1.", formatC(x, format = "f", digits = d))`. Put it in manuscript_setup.R, or add it (without changing anything existing) to _shared/R/06_manuscript_helpers.R, which Paper 1 also sources.
- **Status:** resolved (22 October 2026). The one stripper that can meet a negative value, the correlation in `manuscript_setup.R`'s filter-response sentence, now keeps the sign. The others format reliabilities and accuracies, which cannot be negative, and are left as they are.

### G15-23. prior-spec-check covers one model and blames the supplement for mismatches it never compares against

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/paper_2_neuroplasticity.qmd:746`, `paper_2_plasticity/supplement.qmd:268`
- **Fix:** Loop the check over every model in _prior_specification.csv, with expected sets keyed by family: informative Part A with the aperiodic terms added, weak-prior Part A (b and Intercept normal(0, 1.5)), and Part B (b and Intercept normal(0, 1), sd and sigma student_t(3, 0, 2.5), L lkj_corr_cholesky(2) for the joint models).
- **Status:** resolved in 913c035: every pooled model's priors are checked against supplement S6.

### G15-24. Participants prose counts Paper 1's usable_accuracy stage; the flow figure counts Paper 2's trajectory stage

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/paper_2_neuroplasticity.qmd:427`, `paper_2_plasticity/paper_2_neuroplasticity.qmd:498`
- **Fix:** Use flow_n('trajectory') for the total at qmd:427-428. For the language split, either have 00_extract_participants.R fill n_mini_english and n_mini_norwegian for the 'trajectory' stage, which fig-flow does not read for that tier so the figure is unaffected, or keep usable_accuracy and add a guard in manuscript_setup.R that prints a visible marker when flow_n('usable_accuracy') ...
- **Status:** resolved in 913c035: the two counts agree (63), and a guard flags any divergence.

### G16-05. dec_min_p takes the minimum over all decoding analyses but the gender sentence calls it the pooled time-course p

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:2797`, `paper_1_transfer/paper_1_morphosyntax.qmd:715`, `paper_1_transfer/paper_1_morphosyntax.qmd:1226`
- **Fix:** In decode_summary() add `min_clp_overall`, computed on the confirmatory rows (`d$inference == "confirmatory"` when that column exists, else `analysis == "overall"`). Give dec_min_p() and dec_at_floor() a field argument, and use min_clp_overall in the gender sentence (2796-2797) and in dec_at_floor. Keep min_clp for the verb sentence's 'across all its analyses'.
- **Status:** resolved in 2e89d05.

### G16-06. decode_provisional() retires on any() property having inference, not all as documented, and hard-codes B = 1000

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:588`, `paper_1_transfer/paper_1_morphosyntax.qmd:621`
- **Fix:** Replace qmd:588-589 with `tcs <- Filter(Negate(is.null), decode_tc); finalised <- length(tcs) > 0 && all(vapply(tcs, function(d) "inference" %in% names(d), logical(1)))`. Define the planned count once as a constant, for example `LES_P1_DECODE_NPERM_PLANNED <- 1000L` in scripts/_config.R beside LES_P1_DECODE_SEED_DEFAULT.
- **Status:** resolved in 2e89d05.

### G16-07. acc_gap_sentence ignores the third gap reason 'unread_extra_export' and hard-codes 'Two features' and 'Session 4'

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:1187`, `paper_1_transfer/results/CODEBOOK.md:11`
- **Fix:** Leave acc_gap_sentence() unchanged. In _shared/R/codebook_descriptions.csv:2, add to the `reason` description: "or 'unread_extra_export' (a suffixed export beside a plain subject-N.csv for the same participant and session; the plain file carries the run, so no judgements are lost and the manuscript's count of lost participants excludes it)".
- **Also reported as:** G06-12
- **Status:** resolved in 913c035.

### G16-08. 'The 16-year-old participant' is typed although minors_note's comment says that clause is data-conditioned

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:1605`
- **Fix:** Correct the comments at paper_1_morphosyntax.qmd:426-427 and paper_2_plasticity/manuscript_setup.R:589-590. They should say that the ethics sentence naming the 16-year-old is typed on purpose, to stay word-for-word identical to submission/declarations.md, and that only the demographic clause (minors_note() / minor_age()) is emitted from the data.
- **Also reported as:** G04-09
- **Status:** no change needed: the ethics sentence quotes the declaration word for word, which the comment beside `minors_note()` now says.

### G16-12. Pooled convergence and fit-metadata CSVs label the 12 _itemslope_retfree fits as base (stale vs script 05)

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/results/_pooled_convergence.csv:1`, `paper_1_transfer/results/_pooled_fit_metadata.csv:1`, `paper_1_transfer/paper_1_morphosyntax.qmd:3687`, `paper_1_transfer/results/CODEBOOK.md:378`
- **Fix:** With sign-off, re-run the pooling block of script 05 on the cluster where the fit caches live and pull the three pooled CSVs back. Before committing, diff them against the committed files: only structure, retention_free and model_tag should differ.
- **Also reported as:** G07-13
- **Status:** resolved by the pooling rerun (HTC 8976034, pulled in 07b2ea5): the `_itemslope_retfree` fits are labelled maximal.

### G16-14. Generated Transparency text renders 'where it isreported.' (missing space in paste0)

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:646`, `paper_1_transfer/paper_1_morphosyntax.qmd:655`
- **Fix:** Change `where it is",` to `where it is ",` at both qmd:646 and qmd:655, then re-render.
- **Status:** resolved: the generated sentence now reads 'where it is reported' (verified 4 October 2026).

### G16-15. The same permutation floor 1/1001 prints as '.0010' in the Method and 'p = .001' in the Results

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:1218`, `paper_1_transfer/paper_1_morphosyntax.qmd:563`
- **Fix:** In dec_min_p, format with apa_p() and build the operator from its result. apa_p returns "&lt; .001" without an equals sign, so emit `$p < .001$` when that is the result and `$p = .xxx$` otherwise. In min_cluster_p, state the floor so it agrees, e.g. as the exact fraction '1/1,001' or as '&lt; .001' at B >= 1000, not as '.0010'.
- **Status:** resolved in 2e89d05.

### G16-16. .fmt_est minus-sign substitution is a no-op (ASCII '-' for '-') despite its comment

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:853`
- **Fix:** Replace the substitution with `sub("^-", "−", ...)`. The \u escape keeps the source ASCII, so a later text-cleaning pass cannot strip it again. lualatex (qmd:116) handles U+2212 as long as the body font has the glyph. Re-render and check the PDF, DOCX and HTML tables.
- **Status:** resolved: `.fmt_est()` uses `les_minus()`.

### G16-19. Missing-artefact placeholders mix unmarked 'NN' with \*[pending]* markers; lit_n turns a true zero into 'NN'

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:238`
- **Fix:** Needs author sign-off, since it changes what the manuscripts print when an artefact is missing. If adopted: (a) Define one marker constant in _shared/R/06_manuscript_helpers.R, e.g. LES_PENDING_N &lt;- "\*[n pending]*", and return it from flow_n/pstat and from every bare-"NN" accessor in paper_1_morphosyntax.qmd (including conv_n at 342 and the inline expression at 3674) and in pap ...
- **Also reported as:** G02-06
- **Status:** resolved: the placeholder convention is documented (2e89d05), and `lit_n()` prints a true zero (913c035).

### G16-21. retfree_tally and other_lang_sentence assume at most nine cells and a pre-sorted CSV

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:1077`, `paper_1_transfer/paper_1_morphosyntax.qmd:378`
- **Fix:** In retfree_tally, make .word fall back to digits as dec_count does: `.word <- function(i) if (i <= 9L) c("none", ..., "nine")[i + 1L] else as.character(i)`. For other_lang_sentence, no fix is needed. At most, add a defensive `other_lang_tbl[order(-other_lang_tbl$n_participants, other_lang_tbl$language), ]` that mirrors the writer's rule, or a comment citing 00_extract_participa ...
- **Status:** resolved in 913c035.

### X3-05. _rsvp_timing.csv carries a wall-clock generated_utc column, so identical inputs never reproduce the tracked file

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/01b_extract_rsvp_timing.R:255`
- **Fix:** Leave the tracked CSV unchanged. When the §2.5 rebuild-and-compare gate is written, give it one documented exclusion list of wall-clock provenance columns covering every results file (generated_utc, recorded_utc, fitted_utc, written_at), so regenerated artefacts are compared on their deterministic columns.
- **Status:** no change needed now: `generated_utc` is documented as wall-clock time that a comparison must exclude (aad57ed). No rebuild-and-compare gate exists yet to hold that exclusion.

### X3-07. Seed defaults retyped outside config: LES_REL_SEED in 4 places, LES_SEED as Paper 1's fallback literal

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/11_extract_predictor_reliability.R:66`, `paper_2_plasticity/scripts/11_extract_predictor_reliability.R:54`, `_shared/R/codebook_descriptions.csv:311`, `paper_2_plasticity/results/CODEBOOK.md:214`, `paper_1_transfer/paper_1_morphosyntax.qmd:3320`
- **Fix:** (1) Documentation only: reword codebook_descriptions.csv:311, and the generated CODEBOOK.md:214, to "Seed the random splits were drawn under (LES_REL_SEED; the value used is in this column)", dropping the literal. Point the 11 header :54 at the variable.
- **Also reported as:** X5-08, X6-10
- **Status:** resolved in 2352752 and the codebook.

### X4-02. Paper 2's ordered table lists the aperiodic Part A fit at step 4, before step 7 writes its input; the refit row is missing

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/README.md:26`, `paper_2_plasticity/scripts/README.md:68`
- **Fix:** Documentation only. In paper_2_plasticity/README.md, change row 4 to 'Part A: raw-band reference models (pooled + gender-only)'. After row 7, add a row for the aperiodic Part A pass: '04_fit_brms_predictors.R aperiodic aperiodic_gender, then 08 over those fits (hpc stage 6, 09_aperiodic_model.slurm); needs 07_aperiodic_features.csv from step 7'.
- **Status:** resolved in 470c446.

### X4-13. Supplement author block gives Silva the UTEP affiliation and no ORCID, unlike the Paper 2 article

- **Severity:** MINOR, HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/supplement.qmd:31`
- **Fix:** With author sign-off, align supplement.qmd's author block with the article: Silva gets the ORCID and ref: nebrija, and UTEP is defined under Ivanova. Rothman's affiliations take the article's order, and DeLuca's name takes one form everywhere. Confirm with the author whether 'Vincent F.' or 'Vincent' is intended and apply it to both qmds, the supplement and CITATION.cff.
- **Status:** resolved 17 October 2026: the supplement's author block now matches the article (Silva with her ORCID and Nebrija; Rothman's affiliations in the article's order; UTEP defined under Ivanova), and DeLuca's name takes the articles' form, 'Vincent DeLuca', in the supplement and CITATION.cff.

### X6-03. Manuscript reporting helpers are copied between Paper 1's qmd and Paper 2's setup, bypassing 06_manuscript_helpers.R

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:879`, `paper_2_plasticity/manuscript_setup.R:557`, `paper_1_transfer/paper_1_morphosyntax.qmd:824`, `paper_2_plasticity/manuscript_setup.R:541`, `paper_1_transfer/paper_1_morphosyntax.qmd:803`, `paper_2_plasticity/manuscript_setup.R:519`
- **Fix:** Resolve the pd formatter under X6-02 and leave .les_digits and .pretty_term local, as manuscript_setup.R:538-540 already documents. Optionally: (1) Give prov() a table argument, prov(component, fallback, tbl = .prov_tbl), and make P1's prov_dec a call to it with tbl = .dprov_tbl.
- **Status:** resolved with X6-02: the pd formatter is shared; .les_digits stays local, as manuscript_setup.R documents.

### X7-03. Results tables publish the unused Gorilla participant_home_ID next to the lab ID, a join key into timestamped raw exports

- **Severity:** MINOR (reported as MAJOR), HIGH-RISK. Fix could change a reported number: no.
- **Where:** `_shared/R/07_task_durations.R:164`, `paper_1_transfer/scripts/00b_audit_participant_flow.R:44`, `paper_1_transfer/scripts/00b_audit_participant_flow.R:244`, `_shared/R/07_task_durations.R:271`, `paper_1_transfer/results/_participant_matrix.csv:1`, `paper_2_plasticity/results/_participant_matrix.csv:1`
- **Fix:** With author sign-off, because the change regenerates shipped results files. In 07_task_durations.R: after the join at :172, drop participant_home_ID and order by session, task and participant_lab_ID instead (:179). In les_extract_lab_phase_durations, join only c("participant_lab_ID", "language") from the key (:268-271).
- **Status:** resolved in 9c5c273: The home ID is dropped from both duration tables. The home table is now ordered by lab ID, so the seeded jitter falls on different points (cosmetic). Codebook rows removed. The `_participant_matrix` patch is below. Step 13 cannot run on the cluster until the decoding jobs end, because it needs the held-back 03_data_manifest.R.


## MINOR (99)
### DET-05. hpc/README says the manuscript does not read the _stroop_withpractice variant, but the supplement quotes it

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/hpc/README.md:180`, `paper_2_plasticity/manuscript_setup.R:212`
- **Fix:** Reword README.md:180 to say the supplement's S1 reliability comparison reads the variant's _predictor_reliability_stroop_withpractice.csv.
- **Status:** deferred: the file is among the author's uncommitted edits

### DET-10. Mixed CSV writers make artefact bytes depend on the platform

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/02_extract_accuracy.R:222`, `paper_1_transfer/scripts/00_extract_participants.R:360`, `paper_1_transfer/scripts/01b_extract_rsvp_timing.R:291`, `paper_2_plasticity/scripts/11_extract_predictor_reliability.R:233`, `paper_1_transfer/scripts/07c_extract_electrode_coordinates.R:212`, `paper_1_transfer/scripts/00b_audit_participant_flow.R:246`
- **Fix:** Standardise the results writers on readr::write_csv, or pass eol = "\n" to utils::write.csv, in a change of its own; confirm the regenerated CSVs are byte-identical to the committed copies before committing. Until then, any verification gate should compare after CRLF to LF normalisation.
- **Status:** open: proposed fix awaiting author sign-off

### G01-08. A broken CMDSTAN only message()s and falls back to auto-detection, contradicting the adjacent comment

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `_shared/R/01_bayesian_settings.R:61`
- **Fix:** Comment-only. Reword 01:47-57 to say that cmdstanr's load-time initialiser already honours CMDSTAN, and that a missing or version-less tree leaves the CmdStan path unset (or pointing at the broken tree), so the first compile stops with an error and never falls back to another installation.
- **Status:** resolved in 9c5c273: See X2-04.

### G01-17. 'Every fitting run writes results/_provenance.csv' is false; the 04_provenance header omits the second writer and its extra column

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/README.md:46`, `_shared/R/04_provenance.R:26`, `_shared/R/04_provenance.R:53`
- **Fix:** Change _shared/README.md:46-47 to name the two scripts that write the run-level record (Paper 1's 03_fit_brms_erp.R and Paper 2's 04_fit_brms_predictors.R), mention LES_PROVENANCE_SKIP=1, and note that per-fit versions are in _pooled_fit_metadata.csv.
- **Status:** resolved in commit b111348

### G01-18. Prior-block comment claims every cited source is in references.bib; Betancourt (2017), McElreath (2020) and the Stan User's Guide are not

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/R/01_bayesian_settings.R:93`
- **Fix:** Narrow 01_bayesian_settings.R:93-94 to 'Every DOI cited below is recorded in paper_1_transfer/references.bib', matching 01:163. Optionally note that the arXiv preprint (Betancourt, 2017), the Stan documentation and McElreath (2020) are cited for background and are not in the bibliography. Adding bib entries is the author's choice only if a manuscript cites them.
- **Status:** resolved in 9c5c273: Note added. All 23 DOIs in 01 were checked present in `paper_1_transfer/references.bib`.

### G01-19. 00_paths.R: no roxygen docstrings on any path helper; undocumented directory-creation and setwd side effects

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `_shared/R/00_paths.R:85`
- **Fix:** Add one grouped #' block above the path helpers rather than thirteen near-identical ones. It should state: - @param ... is character path components joined by file.path(). - @return is a single character path. - The helpers are not vectorised: pass one path, because a length>1 result errors inside .ensure_dir.
- **Status:** partly resolved (9c5c273).

### G01-20. 01_bayesian_settings.R: public prior builders, selectors and les_brm lack roxygen docstrings

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `_shared/R/01_bayesian_settings.R:173`
- **Fix:** Documentation only. Add #' blocks, or complete the existing prose headers under whichever convention the author chooses for _shared/R. For les_priors_gaussian and les_erp_prior: - @param window: one of '200_500', '300_600', '400_900' or NULL; any other value gives the neutral grammaticality and caudality prior.
- **Status:** partly resolved (9c5c273).

### G01-21. 02_diagnostics.R: the five exported diagnostics helpers lack roxygen docstrings (params, returns, file writes, RNG use)

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `_shared/R/02_diagnostics.R:35`
- **Fix:** Comments only. First decide once, project-wide, whether R docstrings are roxygen (#') or the existing # prose headers; do not patch file by file. Then extend the five headers so each states: parameter types; return shape with the column names (les_check_convergence at 56-65; les_posterior_summary at 94-100;
- **Status:** partly resolved (9c5c273).

### G01-22. 03_data_manifest.R: accessors and les_assert_readonly_data lack roxygen docstrings

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `_shared/R/03_data_manifest.R:33`
- **Fix:** Comments only. Drop the legacy_eeg_loader item (already documented at 51-53). Leave the one-line accessors as they are, or add at most a note that `...` is passed to data_path() as path components. Add a short header above les_assert_readonly_data at line 124 covering: purpose; output_paths as a character vector of intended write paths;
- **Status:** partly resolved (9c5c273).

### G01-23. 04_provenance.R: les_write_provenance lacks a roxygen docstring (param types, overwrite semantics, try-wrapped callers)

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `_shared/R/04_provenance.R:56`
- **Fix:** Comments only, as an addition to the existing header at 44-55; do not rewrite it. Add: results_dir is a character scalar; values in seeds and extra are coerced with as.character; the file is overwritten on every call, never appended;
- **Status:** partly resolved (9c5c273).

### G02-08. Stale comments in 06_manuscript_helpers.R: 'Two helpers' lists four; fallback blue is not an RdBu colour

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/R/06_manuscript_helpers.R:12`, `_shared/R/06_manuscript_helpers.R:43-48`
- **Fix:** Reword :12 to 'Four helpers read document-level inputs' (or 'Two kinds of helper'). Reword :44-45 to 'the fallback repeats depictr's diverging endpoints and midpoint (#005B96 is depictr's blue; the red and the midpoint coincide with ColorBrewer RdBu)'. Leave the hex values unchanged.
- **Status:** resolved in commit b111348

### G02-09. 06_manuscript_helpers.R functions lack docstrings (params, returns, global lookups)

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `_shared/R/06_manuscript_helpers.R:24`
- **Fix:** Extend the existing # comment blocks in place, following the repository's convention, with no roxygen conversion and no code change: - flow_n: name the valid `col` values (n_total, n_mini_english, n_mini_norwegian), and say it returns a character count, or "NN" when flow_tbl is NULL or `stage` does not match exactly one row with a non-NA value. - pstat: document `digits`;
- **Status:** resolved in commit b111348

### G02-16. 06_helpers.R functions lack full docstrings (types, return shape, RNG side effect)

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `_shared/R/06_helpers.R:39`
- **Fix:** Comment-only edit to _shared/R/06_helpers.R in the existing header style (roxygen optional). For les_zscore: state that a vector with zero or undefined SD returns a numeric vector of zeros of length(x) in which any NA elements also become 0, whereas otherwise NA elements stay NA.
- **Status:** partly resolved (9c5c273).

### G02-22. Installer comments are stale: 'extends' a legacy script, fallbacks 'in the .qmd', failures 'reported'

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/install_bayesian_dependencies.R:4`, `_shared/install_bayesian_dependencies.R:71-74`, `_shared/install_bayesian_dependencies.R:92`, `_shared/install_bayesian_dependencies.R:99-102`
- **Fix:** Delete the 'Extends ...' sentence at :4-6 or reword it to 'Supersedes the container-era HPC scripts/check_and_install_packages.R'. At :71-74 say 'the apa_num formatter used in the manuscripts; _shared/R/06_manuscript_helpers.R carries a base-R fallback'. For :92-102, either reword to 'install.packages() signals most failures as warnings;
- **Status:** resolved in 5b50d49: Updated the installer header. `install_if_missing()` now judges success by `requireNamespace()` after install and prints FAIL even when the failure was only a warning.

### G02-23. 05_funnel.R comments disagree with the calls and the default base_size; supplement sources it unused

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/R/05_funnel.R:49`, `_shared/R/05_funnel.R:52`, `_shared/R/05_funnel.R:198-201`, `paper_2_plasticity/supplement.qmd:112`
- **Fix:** Reword :49-51 to 'Both manuscripts call it as les_funnel(d, base_size = LES_FIG_BASE_SIZE), 10 pt, in ...'. That comment edit is safe. Optionally, with sign-off because it edits the figure function, change the default to base_size = 10 so it matches the floor cited at :198-201; no current render changes because both callers pass the size explicitly.
- **Status:** resolved. The comments were reworded in commit b111348. In the working tree (18 September 2026) `les_funnel()` is replaced by `les_flow()`, which defaults to `base_size = LES_FIG_BASE_SIZE`, and the unused `05_funnel.R` source is removed from `supplement.qmd`.

### G03-03. Deploy exits 0 after holding back files, but exits 1 when it holds back all of them

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `_shared/hpc/deploy_to_cluster.sh:169`
- **Fix:** Keep exit 0 as a documented convention, or introduce exit 3 for a partial deploy and document it in the header's USAGE block. In either case, after the checksum verdict print a final summary such as "deployed N files; held back M because a live job uses them: ..." so the partial state is the last thing on screen.
- **Status:** resolved in 5b50d49: Exit status is 0 when the target is fully current, 3 when something was held back, 1 on a refusal, 2 on a usage error. A closing summary is printed last. Documented in the header.

### G03-11. Restore job installs renv unpinned from CRAN, and its comment miscounts the Rscript lines it shares with the runbook

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `_shared/hpc/00_restore_environment.slurm:54`, `HPC_RUNBOOK.md:105-110`
- **Fix:** (1) Line 7: say the job runs the two Rscript lines of HPC_RUNBOOK.md section 0, preceded by a renv bootstrap. (2) Lines 52-53: add that renv::restore() reinstalls the lockfile's renv (1.2.3), so only the engine doing the restore is unpinned. (3) HPC_RUNBOOK.md:105-110: add the bootstrap line to the manual route and correct "exactly those two lines".
- **Status:** resolved in 5b50d49: The restore job installs the renv version renv.lock pins (1.2.3; current URL 404, CRAN Archive 200, download tested). If neither is reachable it falls back to the current CRAN release and logs a warning. Comments and runbook updated. bash -n and R parse pass.

### G03-15. Deploy comments get line endings and overwrite behaviour wrong, and .gitattributes gives a false checksum rationale

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/hpc/deploy_to_cluster.sh:95`, `.gitattributes:12-16`, `_shared/hpc/deploy_to_cluster.sh:28-29`, `_shared/hpc/deploy_to_cluster.sh:175-176`
- **Fix:** Make header :28-29 agree with :93-96: job scripts must be LF, and .R files are not checked. Keep the autocrlf note, reworded to 'files checked out before .gitattributes pinned *.R to LF; a fresh checkout renormalises them'. Give .gitattributes:12-15 an accurate reason: working-tree bytes match the committed LF bytes, so hand checksum comparisons against cluster copies agree.
- **Status:** resolved in 5b50d49: Deploy header rewritten. LF staging replaces the CRLF refusal, so cluster copies equal the committed bytes. The `.gitattributes` rationale was already accurate (744f10c).

### G03-16. Decoding hold-back rationale is wrong: the fingerprint covers tensor shape, B, seed and x digest, not file content

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/hpc/deploy_to_cluster.sh:14`, `_shared/hpc/README.md:22`, `HPC_RUNBOOK.md:227-228`
- **Fix:** Reword deploy_to_cluster.sh:13-15, _shared/hpc/README.md:22, HPC_RUNBOOK.md:227-228 and AUTHOR_TASKS.txt:520. The fingerprint is built from the tensor's shape, B, the seed and a digest of X. 09_run_decoding.R defines that formula, 08_decoding.slurm sets B and the seed, and a deployed copy that changes either invalidates the banked checkpoints.
- **Status:** resolved in 5b50d49: The deploy header, `_shared/hpc/README.md`, the runbook and the AUTHOR_TASKS note now give the right reason. The block key is the tensor's counts plus digest, B and the seed. It does not cover 09's code, and `08_decoding.slurm` sets B and the seed.

### G03-17. Deploy defaults to the personal ssh alias arc-agent; the runbook tells users to define arc; LES_CLUSTER_HOST undocumented

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/hpc/deploy_to_cluster.sh:41`
- **Fix:** Documentation only: in HPC_RUNBOOK.md:218-231 and _shared/hpc/README.md:22, document the optional [ssh-alias] argument and LES_CLUSTER_HOST, and say the default is the author's arc-agent alias. Whether to change the default to `arc` or require an alias is the author's call, since it would change their own automated deploy workflow.
- **Status:** resolved by decision (17 October 2026): the default stays the author's arc-agent alias, which HPC_RUNBOOK.md documents together with the alias argument and LES_CLUSTER_HOST.

### G03-18. check_arc_env.R exits 0 on FAIL, so rebuild_cmdstan.slurm completes on a broken toolchain; section heading contradicts comment

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/hpc/check_arc_env.R:59`, `_shared/hpc/rebuild_cmdstan.slurm:34-35`, `_shared/hpc/check_arc_env.R:36-41`
- **Fix:** Append `if (!ok) quit(status = 1)` to check_arc_env.R, after line 59. Rename the heading at :39 to '== output store resolves (created on demand) =='. Reword :37-38 to say the helpers may create missing directories but write no files.
- **Status:** resolved in commit 9c1d808

### G03-19. Runbook's list of hand-submitted stages leaves out eight job scripts, and it describes a root store/ that doesn't exist

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `HPC_RUNBOOK.md:146`, `HPC_RUNBOOK.md:180-182`
- **Fix:** At HPC_RUNBOOK.md:146-150, add 00_descriptives (Paper 1) and 10_descriptives, 11_predictor_reliability and 13_extract_task_durations (Paper 2), or replace the enumeration with a pointer to the stage tables. Do not add 10_compare_aperiodic, which must not be submitted.
- **Status:** resolved in commit 744f10c

### G03-20. Reconnaissance README says the probes write no file and only two need network; probe_rseeg.R uses OSF and downloads

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/hpc/reconnaissance/README.md:15`, `_shared/hpc/reconnaissance/probe_rseeg2.R:5`, `_shared/hpc/reconnaissance/probe_rseeg4_osf.R:7`
- **Fix:** In reconnaissance/README.md:26-27, name probe_rseeg.R alongside probe_rseeg2.R and probe_rseeg4_osf.R as needing outbound network. At :15, say the three OSF probes download small header files into R's session tempdir() and write nothing else. Change the 'prints to stdout only' header notes in probe_rseeg2.R:5 and probe_rseeg4_osf.R:7 to match.
- **Status:** resolved in commit cebe08c

### G03-21. .gitignore typo leaves desktop.ini unignored; comments are stale; PDFs it ignores are tracked while .docx renders are not ignored

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `.gitignore:10`, `.gitignore:39`, `.gitignore:46-48`
- **Fix:** Now: fix line 10 to `desktop.ini` and reword the :39 comment, e.g. '# Legacy container images and rendered HTML; HPC job logs'. For the author: decide one policy for rendered .pdf/.docx files (the manuscripts and supplement.pdf). Either track them deliberately and drop :46-48, or untrack them.
- **Status:** resolved before this pass (verified 3 October 2026): Typo and comment fixed in 411a78c; the tracking policy was set in e872b6e and recorded in `.gitignore`. I added one sentence on the root `*_review_draft.*` snapshots.

### G03-22. Script helpers lack structured docs: deploy's collect, has_cr, files_of_job, norm_sums; check_arc_env.R's say

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/hpc/deploy_to_cluster.sh:57`, `_shared/hpc/check_arc_env.R:24`
- **Fix:** Add one comment above files_of_job (:126): it prints the job script path and each .R it runs, repo-relative and spelled as collect() prints them, because :159-163 compares them as exact strings. Comment-line matches only widen the hold-back. Optionally note at :98 that has_cr succeeds when the file contains a CR. No #' block for say().
- **Status:** resolved in 5b50d49: Purpose comments added for `norm_sums`, `summary`, `CLOSURE_AWK` and the file list. `collect`, `has_cr` and `files_of_job` are gone. `check_arc_env.R`'s `say()` has a one-line comment (parse ok).

### G04-10. Retention test's ±0.5-trial tolerance cannot detect changes at the one-decimal precision the Method prints

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/tests/test_erp_retention_artefact.R:39`, `paper_1_transfer/scripts/tests/test_erp_retention_artefact.R:37`, `paper_1_transfer/scripts/tests/test_erp_retention_artefact.R:43`
- **Fix:** 1. In tests/test_erp_retention_artefact.R, compare at reported precision: `round(canonical$mean_retained, 1) == 31.4`, `round(canonical$sd_retained, 1) == 5.8`, `round(canonical$pct_discarded, 1) == 34.5`, and `canonical$n_cells == 891L`. 2. Drop the tautological :37 check, or relabel it as structural. 3. Reword the header so it says exactly what is pinned. 4.
- **Status:** resolved in aad57ed: The test now pins the post-N15 values at print precision, the overall row, the `source` column, the shares, and the share totals against the per-condition rows. `hpc/00_descriptives.slurm` runs it last (the "not applied" part). It fails on the committed table by design until 00c is rerun.

### G04-12. scripts/README claims every script sources _config.R and that _provenance.csv describes the run behind the results

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/README.md:10`, `paper_1_transfer/scripts/README.md:59`
- **Fix:** 1. scripts/README.md:10: say that _config.R is sourced by the scripts that need the grid, the exclusion list or the variant tags (00c, 01, 01b, 02, 03, 04, 05, 07, 07b, 08, 09, and 09b through 09). Say that 00, 00b, 00d, 07c and 10 source only _shared/R/00_paths.R and 03_data_manifest.R. 2. scripts/README.md:59-60: keep _provenance.csv as the file the manuscript reads.
- **Status:** resolved in commit 05688a1

### G04-15. Decoding-seed comments give a rationale the manuscript has abandoned: 03's provenance does not record the decoding seed

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/_config.R:95`, `paper_1_transfer/scripts/test_exclusion_guard.R:139`
- **Fix:** Reword _config.R:95-97 and test_exclusion_guard.R:139-141. The literals must agree so that a decoding job that exports no seed runs under the configured default. The seed a decoding run actually used is recorded by hpc/08_decoding.slurm in results/_decoding_provenance.csv, which the manuscript reads. The ERP record carries only the default. Keep this to comments.
- **Status:** resolved in aad57ed: `_config.R` decoding-seed comment now says the seed actually used is recorded in `_decoding_provenance.csv`, and `_provenance.csv` holds only the default. The test's comment was already right.

### G04-16. Exclusion-guard test contains a tautological check and does not neutralise the env vars it depends on

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/test_exclusion_guard.R:134`, `paper_1_transfer/scripts/test_exclusion_guard.R:65`
- **Fix:** Near the top of the test, after sourcing _config.R, add Sys.unsetenv(c("LES_P1_KEEP_MISFILTERED", "LES_P1_ITEM_SLOPE", "LES_PRIOR_SET", "LES_P1_ACC_DIVERSITY")). The script runs as its own Rscript process, so this is process-local.
- **Status:** resolved in commit 9c357cd

### G04-20. 00b_audit_participant_flow.R functions lack roxygen docstrings

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/00b_audit_participant_flow.R:35`
- **Fix:** Add short comment blocks above les_participant_matrix, les_flow_inconsistencies and les_write_flow_audit. They should name the files each reads and writes, the columns of `m` that les_flow_inconsistencies expects, and the returned data frame (check, severity, participant_lab_ID, detail).
- **Status:** resolved in aad57ed: `#'` on 00b's three functions. README ordering note: patch below.

### G04-22. 00c_extract_erp_retention.R's pooled_row() lacks a docstring

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/00c_extract_erp_retention.R:130`
- **Fix:** Extend the existing comment at :127-129 with one sentence: scope_label also sets the grammaticality label ("canonical" gives "Grammatical+Ungrammatical", anything else "ALL"), so df must hold exactly the rows that label describes. Adding an explicit grammaticality argument is optional, touches results-producing code and needs sign-off.
- **Status:** resolved in aad57ed: `pooled_row(n_trials, scope_label, grammaticality_label, source)` takes the label explicitly, with `#'`.

### G05-07. 07c header says every Raw BrainVision header carries the montage; 20 Raw headers have no [Coordinates]

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/07c_extract_electrode_coordinates.R:7`
- **Fix:** Reword 07c:6-9 to say that most BrainVision headers under data/raw data/EEG (Raw and Export) carry a [Coordinates] section, that some Raw headers from Sessions 2-4 do not, and that positions are checked across the headers that do (the count is reported at run time by the '[coords] ... without' message).
- **Status:** resolved in commit 05688a1

### G05-15. The test says sourcing the extractor has no side effects; it changes the working directory and prints

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/tests/test_summarise_cells.R:18`
- **Fix:** Reword test:16-18 to: sourcing the extractor defines .les_scale and .les_summarise_cells without loading EEG data or running the extraction (the loader is sourced lazily and .run() is guarded by sys.nframe()). It does anchor the working directory at the project root (00_paths.R) and print the path and config banners.
- **Status:** resolved in commit 9c357cd

### G05-20. 07c helper functions have no docstrings, including the coordinate-projection convention

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/07c_extract_electrode_coordinates.R:104`
- **Fix:** Add a short comment block, not roxygen, above 07c:77. It should say that .parse_vhdr_montage returns a data frame (electrode, radius, theta, phi) of EEG channels with radius > 0, sorted by electrode, or NULL when the header lacks [Coordinates] or [Channel Infos] or has malformed coordinate lines. Leave .project, gx and gy as they are.
- **Status:** resolved in commit 05688a1

### G06-09. Missing roxygen docstrings on every function in 03_fit_brms_erp.R

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/03_fit_brms_erp.R:196`
- **Fix:** Comments only, and ideally as part of a single repo-wide roxygen decision so these files do not diverge from the rest of the codebase: - fit_paper1_erp_cell(): add a #' block with purpose; @param property, window and macroregion (character scalars from les_p1_erp_grid()); @return the brmsfit, invisibly; environment variables read (refer to the header USAGE list);
- **Status:** resolved in commit 05688a1

### G06-10. Missing roxygen docstrings on every function in 04_fit_brms_accuracy.R

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/04_fit_brms_accuracy.R:85`
- **Fix:** Comments only: - fit_paper1_accuracy(): add a #' block with purpose; @param property (character scalar, one of names(LES_P1_PROPERTIES)); @return the brmsfit, invisibly; environment variables read (LES_P1_ACC_DIVERSITY, LES_PRIOR_SET, LES_PRIOR_PREDICTIVE);
- **Status:** resolved in commit 05688a1

### G06-11. 03 header calls item_id 'a single unique sentence'; it is a frame spanning conditions and several sentences

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/03_fit_brms_erp.R:46`
- **Fix:** Reword 03_fit_brms_erp.R:46-48 to something like: "The item grouping `item_id` (= language x sentence-marker) indexes a sentence frame: a marker slot within one language. Across participants and sessions it carries several lexical fillings, and it is presented in both grammaticality conditions (see below).
- **Status:** resolved in commit 05688a1

### G07-17. README priors section: wrong env-var source, weak recipe refits base ERP only, manual step now automated

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/README.md:90`, `paper_1_transfer/README.md:95`, `paper_1_transfer/README.md:159`
- **Fix:** (1) At README.md:90, say that LES_PRIOR_SET is read in 01_bayesian_settings.R and LES_PRIOR_PREDICTIVE in scripts 03 and 04. (2) Replace the weak-prior line with the three submissions behind the committed table: `sbatch --export=ALL,LES_PRIOR_SET=weak,LES_PROVENANCE_SKIP=1 paper_1_transfer/hpc/03_fit_erp.slurm` (base structure), `sbatch --export=ALL,LES_P1_ITEM_SLOPE=1,LES_PRIO ...
- **Status:** resolved in commit 05688a1

### G07-18. figures/README says the diagnostic PNGs are read through les_check_convergence(), which reads no image

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/figures/README.md:35`
- **Fix:** Rewrite figures/README.md:35-38. Say that one _ppc image, and one _priorpc image when LES_PRIOR_PREDICTIVE=1, is written per fitted cell_tag or model_tag, variants included. They are inspected by eye. les_check_convergence() is the separate numerical gate (R-hat, ESS, divergences) computed from the fits, and none of the images is needed to render the paper.
- **Status:** resolved in commit 05688a1

### G07-19. results/README omits the two task-duration CSVs written into both papers and read by Paper 1

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/results/README.md:38`, `paper_1_transfer/README.md:12`
- **Fix:** At results/README.md:38-41, say eight files and add _task_durations_home.csv and _task_durations_lab.csv. Name their writer, _shared/R/07_task_durations.R, run by paper_2_plasticity/scripts/13_extract_task_durations.R and submitted as paper_2_plasticity/hpc/13_extract_task_durations.slurm.
- **Status:** resolved: results/README.md names both task-duration tables and their writer (verified 4 October 2026).

### G07-20. Codebook descriptions of step-5 outputs omit the _diversity, _keepmisfiltered and _retfree ids the code emits

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/R/codebook_descriptions.csv:54`, `_shared/R/codebook_descriptions.csv:99`, `_shared/R/codebook_descriptions.csv:131`, `_shared/R/codebook_descriptions.csv:144`
- **Fix:** Update rows 54, 99, 131 and 144 of _shared/R/codebook_descriptions.csv. Name every tag step 5 can emit: _keepmisfiltered (ERP, data variant), _diversity (accuracy, data variant), _weakprior, _itemslope and _retfree. Say they compose in the order used at 03:204-205 and 04:96-97, and match the wording of row 109.
- **Status:** resolved in 9c5c273: Codebook rows now name `_exclreproc` and the accuracy tags `_diversity`, `_maxranef`, `_byitem`, `_weakprior` in order. The structure note explains why accuracy variants are recorded as `base`.

### G08-09. Header says every routine requires >=2 training participants with both classes; TGM and generalisation do not

- **Severity:** MINOR. Fix could change a reported number: yes.
- **Where:** `paper_1_transfer/scripts/09_run_decoding.R:84`, `paper_1_transfer/scripts/09_run_decoding.R:503`, `paper_1_transfer/scripts/09_run_decoding.R:531`
- **Fix:** Narrow 09:83-85 to say the >= 2-participants-with-both-classes guard is enforced by the time-course decoder, while the TGM and generalisation routines require only a balanced training set of >= 4 rows and a test set with both classes.
- **Status:** resolved in d9d9fab: 09 header DECLINING N rewritten per routine (time-course vs TGM vs generalisation guards, verified against the code).

### G08-10. Checkpoint writes skip the PID-unique atomic idiom 08 says 09 shares; 'clean run' recipe leaves partials

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/09_run_decoding.R:655`, `paper_1_transfer/scripts/09_run_decoding.R:456`, `paper_1_transfer/scripts/09_run_decoding.R:609`, `paper_1_transfer/scripts/08_extract_decoding_matrices.R:276`
- **Fix:** Documentation now: extend 09:609-610 to also delete _tc_part_&lt;property>_*.rds, and correct 08:277-278 to say 09's partial write uses a fixed temp name without a checked rename. Code, at the reconciliation deployment and not while HTC job 8736986_0 holds 09 under the deploy freeze: route both the partial (456-460) and the block checkpoint (655-656) through .les_save_atomic.
- **Status:** partly resolved: the comments are corrected (d9d9fab). Atomic writes in 09 are deferred to the next decoding run, for the reason given under G08-02 (decided 26 October 2026).

### G08-12. 09 comments disagree with the code (ridge target, standardisation) and a ridge constant has no source

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/09_run_decoding.R:175`, `paper_1_transfer/scripts/09_run_decoding.R:140`, `paper_1_transfer/scripts/09_run_decoding.R:49`
- **Fix:** At 09:171-172, describe the regularisation as a scaled identity (ridge x mean channel variance) added to the pooled covariance, and say the 1e-8 keeps the matrix positive definite when every channel variance is zero. At 09:140-142, either cite a verified source for 1e-3 or state it as a fixed, untuned choice, with no claim that it is 'standard'.
- **Status:** resolved in d9d9fab: Ridge described as a scaled identity (Tikhonov), 1e-8 explained, 1e-3 stated as fixed since the first commit (git log -S), untuned, unsourced; "standardisation" claim removed (there is none).

### G08-13. Language and class labels hard-coded in the decoder; other meta values silently drop out

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/09_run_decoding.R:706`, `paper_1_transfer/scripts/09_run_decoding.R:736`, `paper_1_transfer/scripts/09_run_decoding.R:687`
- **Fix:** In run_timecourse and run_crosslang, stop if any d$meta$mini_language is NA or outside c('Mini-English','Mini-Norwegian'), instead of deriving the levels from data. Treating the class labels and the 20-trial/3-participant floors as named constants is optional tidying. Do it at the reconciliation deployment, since 09 is under the ARC deploy freeze.
- **Status:** partly resolved: the behaviour is documented (d9d9fab). The guard on unexpected language labels is deferred to the next decoding run, for the reason given under G08-02 (decided 26 October 2026). The October run's cross-language files carry both mini-languages, so no label dropped out of the reported results.

### G08-16. 08 docs are stale: output list incomplete, cli_arg never passed, a wrong claim about intercepts

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/08_extract_decoding_matrices.R:58`, `paper_1_transfer/scripts/08_extract_decoding_matrices.R:17`, `paper_1_transfer/scripts/08_extract_decoding_matrices.R:104`
- **Fix:** Rewrite 08:58-60 to say a per-trial offset is not removed by an intercept and that per-trial baseline correction is what removes pre-stimulus offsets. Add time_step_ms, baseline_corrected and x_digest to the header output list, noting that x_digest keys 09's checkpoints. Either document cli_arg as unused or drop it;
- **Status:** resolved in d9d9fab: 08 header output list (time_step_ms, baseline_corrected, x_digest and what keys 09's checkpoints, the sidecar), intercept claim corrected (an intercept cannot absorb trial-varying offsets and the discriminant has none), cli_arg documented as unused (removal proposed, trivial), cache-cost figures updated, stale KEEP_MISFILTERED-era rationale rewritten.

### G09-12. 08b reads n_perm by column position, splits the CSV on raw commas and hard-codes 1000

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/08b_verify_gender_decoding.slurm:72`
- **Fix:** Locate n_perm by header name in awk. Take the expected count from `${RES}/_decoding_provenance.csv` (row `LES_DECODE_NPERM`), falling back to 1000. If the constant is kept instead, state in the header that it is deliberate. Add `[ -n "${LES_DECODE_WATCH_JOB:-}" ] || { echo 'LES_DECODE_WATCH_JOB unset' >&2; exit 1;
- **Status:** resolved in commits 9c357cd, 05688a1

### G09-13. 08b and the README give only the ARC submission form for a watcher that must share the cluster of the HTC decoding job

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/08b_verify_gender_decoding.slurm:23`, `paper_1_transfer/hpc/README.md:101`, `paper_1_transfer/hpc/README.md:17`
- **Fix:** In the 08b header and hpc/README.md:101, give the HTC form (`sbatch --clusters=htc --account=educ-intract --export=ALL,LES_DECODE_WATCH_JOB=<id>_0 --dependency=afterany:<id>_0 ...`). State that the watcher must go to the same cluster as the decoding job, because both the dependency and the sacct call at 08b:49 are cluster-local.
- **Status:** resolved in commits 9c357cd, 05688a1

### G09-18. The submit_all.sh header calls script 00 a local script with no job, but 00_descriptives.slurm runs it

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/submit_all.sh:17`
- **Fix:** Change submit_all.sh:14-17 so that 00 and 00c are described as 'run locally or through 00_descriptives.slurm' and the 'local, no job' list reads 00b, 00d, 01b, 07c, 09b, 10. Replace 'after 02' with the job's real prerequisites: data/, the accuracy logfiles, and the Paper 2 derived cognitive_indices.rds, learning_trajectory.rds and resting_state_eeg.rds in the store.
- **Status:** resolved in commit 05688a1

### G09-20. hpc/README's account of where the gender decoding went is stale against the logged HTC jobs

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/README.md:12`, `paper_1_transfer/README.md:44`
- **Fix:** In paper_1_transfer/README.md:41-44, replace the instruction to resubmit. Say that the gender element was resubmitted on HTC on 2026-09-06 at the script's own memory request, and point to AUTHOR_TASKS.txt Part 3 for its state. Keep the sentence that the manuscript discloses the lagging exploratory count programmatically.
- **Also reported as:** X4-10
- **Status:** resolved in commit 05688a1

### G09-24. scripts/README lists the letter-suffix scripts incompletely and names _provenance.csv as the manuscript's only provenance source

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/scripts/README.md:59`, `paper_1_transfer/scripts/README.md:15`
- **Fix:** In scripts/README.md:59-60, name both records: `_provenance.csv`, written by step 3, supplies the software versions and the model-fitting seed; `_decoding_provenance.csv`, written by hpc/08_decoding.slurm, supplies the decoding seed, permutation count and time step. Complete the suffix list at :15-16 (00b, 00c, 00d, 01b, 07b, 07c, 09b), or introduce it with "for example".
- **Status:** resolved before this pass (verified 3 October 2026): `scripts/README.md:15-20, 59-70` already list the suffix scripts and both provenance files. The remaining `_config.R` comment is fixed (G04-15). The README sourcing list and tests list have since drifted: patch below.

### G10-14. 01 comments are stale since the test-block rescore: 'verbatim' legacy index, 'ONE' fix, unsourced reliabilities

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:16`, `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:30`, `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:110`
- **Fix:** Reword the 01 header (lines 14-30): - Say the index formulas and trimming thresholds come from the legacy scripts. - List two deliberate departures: (1) batch-priority de-duplication, and (2) Stroop scored on the test block only, because the legacy zone filter keeps practice rows despite its 'Remove practice trials' comment.
- **Status:** resolved in 2352752: 01:14-36 formulas and thresholds from the legacy scripts, two named departures (legacy zone filter verified to keep practice rows), reliabilities sourced to the two `_predictor_reliability*.csv`.

### G10-15. scripts/README says _config.R is sourced first by every script; 01-03 source shared modules first

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/README.md:10`
- **Fix:** Reword scripts/README.md:10-13 as: 'Each script sources the shared modules it needs from ../../_shared/R/ (at least 00_paths.R) and then _config.R, which sources 00_paths.R and 03_data_manifest.R itself when they are absent. _config.R defines the session mapping, the task definitions and the model-ID naming.
- **Status:** resolved in commit 475dd3b

### G10-16. les_p2_write_fit_meta duplicates Paper 1's writer and alone guards the read-only check with exists()

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/_config.R:114`
- **Fix:** Drop the exists()-guard point, or apply it to all five call sites together (both _config.R files, 06_summaries.R:269, 06b:140 and 04_provenance.R:84) for consistency, as a cosmetic cleanup. Consolidating into a shared `les_write_fit_meta(dat, model_id, path, extra = list())` in _shared/R/04_provenance.R is optional.
- **Also reported as:** X6-12
- **Status:** resolved in 2352752.

### G10-17. Mixed logging: cat at source time, print/cat in .run, message elsewhere; P1 config banner in P2 logs

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/_config.R:137`, `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:287`, `paper_2_plasticity/scripts/02_extract_learning_trajectory.R:103`, `paper_2_plasticity/scripts/03_extract_resting_state_eeg.R:173`
- **Fix:** Use message() for progress and diagnostics, and warning() or stop() for data problems, consistently. Either make 03:173 a message(), or promote both 03:173 and 03:203 to warnings. Keep print() only for the .run() validation tables, with their headers also sent through message(), or leave the tables as they are.
- **Also reported as:** X6-11
- **Status:** resolved in 2352752.

### G10-18. _config.R functions lack roxygen docstrings (les_p2_model_id, les_p2_write_fit_meta)

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/_config.R:82`, `paper_2_plasticity/scripts/_config.R:114`
- **Fix:** Add #' roxygen blocks to both functions. For les_p2_model_id: @param key, a character scalar naming an entry of LES_P2_MODELS; @param tags, a character vector of suffixes concatenated in order; @return, a character scalar; it stops on an unknown key. For les_p2_write_fit_meta: @param dat, the data.frame passed to brms, which must contain participant_lab_ID;
- **Status:** resolved in commit 475dd3b

### G10-19. 01 functions lack roxygen docstrings

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:63`, `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:83`, `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:118`, `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:121`, `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:124`, `paper_2_plasticity/scripts/01_extract_cognitive_indices.R:135`
- **Fix:** Add short #' blocks for the five functions that 11 uses across files (.les_p2_files, .les_read_bind, .les_drop_practice, les_p2_stroop_keep_practice and les_p2_stroop_tag). Each should state its parameters and types and its return value: character paths; NULL or a raw export tibble; a filtered tibble plus a message; logical; character.
- **Status:** resolved in 2352752: plain `#` blocks on every 01 function (params, returns, stops, callers 10/11)

### G11-07. fit_rseeg_prepost is dead code that runs on every default call and would average eyes-open with eyes-closed

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/05_fit_brms_prepost.R:197`, `paper_2_plasticity/scripts/_config.R:76`
- **Fix:** Either option is an author decision, since the retention is documented. - Minimal: at 05:204, add `filter(condition == "eyes_closed")` before group_by(), and change the comment to match Part A (04:187-196). The branch cannot then silently average conditions if it is ever reactivated.
- **Status:** resolved in 2352752: 05:247-265 filters eyes-closed before averaging; header 05:26. Removing the branch stays the author's option.

### G11-15. LES_P2_DERIVED_CONTRASTS is read by 06 but missing from the hpc switch table and the 06 slurm header

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/06_summaries.R:249`, `paper_2_plasticity/hpc/06_summaries.slurm:4`
- **Fix:** Add a row to the table at hpc/README.md:174-181: `LES_P2_DERIVED_CONTRASTS` | `1` | stage 06 | no tag | derives the working-memory minus statistical-learning main-effect contrast from the existing raw-band Part A draws, writing results/_predictor_contrasts.csv, which the Discussion sentence reads;
- **Status:** resolved: documented in the 06 job header (475dd3b) and the switch table (b2f67f0).

### G11-17. Magic thresholds and transcribed counts in comments have no stated source

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/05_fit_brms_prepost.R:68`, `paper_2_plasticity/scripts/05_fit_brms_prepost.R:173`, `paper_2_plasticity/scripts/04_fit_brms_predictors.R:73`
- **Fix:** Comments only. At 05:68, add a WHY comment saying the five-participant floor is a guard against fitting an empty or degenerate frame, not a power or estimability criterion. At 05:173, refer back to it. At 04:72-73, keep the dated wording and add a pointer such as "(50 as of 2026-07; the current common-sample n is n_participants in results/_aperiodic_kfold_compare.csv)".
- **Status:** resolved in 2352752: `_config.R:135-138` `LES_P2_PREPOST_MIN_PARTICIPANTS` with its rationale, used at 05:84 and 05:219; 04:72-74 pointer already present (475dd3b)

### G11-18. 04_fit_brms_predictors.R: no function has a roxygen docstring with parameters, return value and side effects

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/04_fit_brms_predictors.R:147`
- **Fix:** Add short comment blocks where none exist: a one-line purpose above les_p2_partA_formula, and above fit_paper2_partA its arguments (gender_only, aperiodic; logical), return value (the brmsfit, invisibly), files written (paper2_results(&lt;model_tag>), _convergence.rds, _summary.rds, _fitmeta.rds;
- **Status:** resolved in 2352752: remaining 04 functions documented in plain `#` (house style; roxygen conversion moot)

### G11-19. 05_fit_brms_prepost.R: no function has a roxygen docstring

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/05_fit_brms_prepost.R:61`
- **Fix:** Add a one-line purpose comment above fit_cognition_prepost (05:107) and fit_rseeg_prepost (05:197). Extend the comment at 05:58-60 to name the arguments (dat data.frame; measure column name; sessions length-2 numeric; model_id character), the return value (the brmsfit invisibly, or invisible NULL with a message when fewer than 5 participants or 2 sessions remain) and the four f ...
- **Status:** resolved in 2352752: 05 joint model and switch helpers documented.

### G11-20. 06_summaries.R: no function has a roxygen docstring

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/06_summaries.R:54`
- **Fix:** Do not convert this one file to roxygen in isolation. Log a single repo-wide item and decide it once: (a) Keep plain # comments as the house style and say so in _shared/R/README.md. (b) Or adopt roxygen across all live scripts consistently.
- **Status:** resolved before this pass (verified 3 October 2026): house style stated in `_shared/R/README.md:46-48` (b111348); two helpers documented (06:103-113)

### G11-21. 06b_recover_provenance.R: no function has a roxygen docstring

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/06b_recover_provenance.R:53`
- **Fix:** Handle this under the same single repo-wide docstring-convention decision as G11-20, not as a one-off roxygen conversion. Minimal fix in the existing # style: add a short comment above les_recover_provenance (line 80) stating: - `models`: character vector of model ids, defaulting to .les_prov_models.
- **Status:** resolved before this pass (verified 3 October 2026): 06b functions were documented (475dd3b); the new guard is documented.

### G12-12. 07_extract_aperiodic.R has no roxygen docstrings on any function

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/07_extract_aperiodic.R:156`
- **Fix:** Convert the existing comment blocks to roxygen `#'` with @param (types and units), @return and side effects. Start with the functions other scripts call: `specparam_decompose` (document `s` as a LES_AP_SETTINGS-shaped list), `.fit_aperiodic` (state that it is the single robust aperiodic fit without peak removal, and that the reported exponent comes from `specparam_decompose`'s ...
- **Status:** resolved in 2352752: `.ap_predict`, `.gaussian`, `.fit_peaks`, `.posterior_psd`, `.plot_example_fit`, `.run` documented.

### G12-13. 12_extract_gamma_attenuation.R functions lack roxygen docstrings

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/12_extract_gamma_attenuation.R:72`
- **Fix:** Add a `#'` block to `.retained_fraction` covering: exponent as the log10-log10 slope, `response` as a power transfer function of f in Hz, integration by a 0.01 Hz Riemann sum over LES_GAMMA_BAND, and a unitless fraction as return value. Add one to `extract_gamma_attenuation` covering: no arguments; reads results/_resting_state_psd.csv;
- **Status:** resolved in 2352752: The remaining "leak guard" is done (G12-03), and every function in 12 has a `#` doc block (house style; Paper 2 uses no `#'`).

### G12-14. 10_extract_descriptives.R functions lack roxygen docstrings

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/10_extract_descriptives.R:65`
- **Fix:** Keep the '#' comment convention used throughout the codebase; do not convert this one file to roxygen. Add a one-line purpose comment above .read_many_csv (row-binds the Session-1 batch exports, reading them with warnings suppressed) and above .modal (returns the most frequent value as numeric;
- **Status:** resolved in 2352752: Header line on `write_*` returning `list(path, tbl)` (+peak, has_prop/has_lang), and doc blocks on all functions.

### G12-21. Where 10 and 12 run is inconsistent: README says 'local', slurm runs on ARC; USAGE uses --vanilla; mixed logging

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/10_extract_descriptives.R:44`, `paper_2_plasticity/README.md:35`, `paper_2_plasticity/README.md:37`
- **Fix:** Change the 'local' labels at paper_2_plasticity/README.md:35-37 to 'HPC' (or 'local/HPC') and name the wrapper (hpc/10_descriptives.slurm for 10 and 12, hpc/11_predictor_reliability.slurm for 11). Reconcile hpc/README.md:81-83 with the wording chosen. Optionally, note in 10's USAGE block that the cluster route is the slurm wrapper. The logging change is optional.
- **Status:** resolved in 2352752: The USAGE blocks of 10 and 11 name the cluster wrappers. The README was already "local/HPC" (475dd3b), and hpc/README:81-83 is consistent. Optional logging change not made.

### G13-12. Missing roxygen docstrings in 08_projpred_selection.R (7 functions), including file-write side effects

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/08_projpred_selection.R:197`
- **Fix:** Add a short contract to run_projpred_one and .les_projpred_path in the repo's existing banner-comment style, or in roxygen if the author adopts it repo-wide; do not do it for this file alone. For run_projpred_one, state that it takes model_id (character, a LES_P2_MODELS value), returns invisible(path_df) or NULL when the cache is missing, and writes &lt;model>_cvfits.rds (reused i ...
- **Status:** resolved in commit 475dd3b

### G13-16. 09c comments contradict each other and the slurm on refit cost, fold identity with 08, and 'design effect'

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/09c_compare_aperiodic_grouped.R:42`
- **Fix:** In 09c: replace lines 42-44 with the slurm's measured figures (about 1 h per refit with concurrent chains, about 40 h for 40 refits; see the slurm header). Reconcile or drop the '~18 min / ~4.5 min' figures at 78-80 but keep the mc.cores rationale. Reword 86-87 to 'the same fold-building algorithm; the partitions differ because the samples differ (see WHY NOT REUSE above)'.
- **Status:** resolved in 2352752: 09c and slurm costs now use the 8826758 measurements (pooled about 52/42 min per refit, gender 12/9 min, 19 h 10 min total; the "1 h each / 40 h" figure was wrong for gender). Log label changed from "design effect" to "SE inflation".

### G13-17. _projpred_path.csv is billed as manuscript-facing but nothing reads it, and it re-pools stale per-model files

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/08_projpred_selection.R:446`
- **Fix:** Documentation only: reword 08:89 and 08:444 to say the pooled CSV is a convenience concatenation of whatever per-model path files are in the results store, not read by the manuscript, and possibly mixing runs. Note the exception in results/README.md:11 and in the _projpred_path.csv description in _shared/R/codebook_descriptions.csv, then regenerate CODEBOOK.md.
- **Status:** resolved before this pass (verified 3 October 2026): 08:95-97 and pool_paths comment, results/README.md:11, codebook row 457, CODEBOOK.md:305 (475dd3b/9a11c65).

### G13-20. Stage 09 spends multi-day projpred compute on aperiodic_gender, whose path no reader consumes

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/08_projpred_selection.R:471`
- **Fix:** Drop aperiodic_gender from the projpred step only (09_aperiodic_model.slurm:56), keeping it on the 04 fit step at :52. Update the slurm header (lines 7 and 14-17), 08:96-98 and hpc/README.md:74 accordingly. Alternatively, record why the aperiodic gender selection is computed and where it will be reported. Decide before stage 09 is submitted.
- **Status:** resolved in 2352752: 09_aperiodic_model.slurm now runs projpred on `aperiodic` only. Both aperiodic fits are kept, because 09b/09c need them. Header and 08 usage updated.

### G13-21. 08 and 08b comments claim a base rate is reported, a 'rank' column and summaries in results/; none holds

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/08_projpred_selection.R:75`, `paper_2_plasticity/scripts/08b_recover_projpred_path.R:24-25`, `paper_2_plasticity/scripts/08_projpred_selection.R:84-86`, `paper_2_plasticity/scripts/08_projpred_selection.R:357-358`
- **Fix:** Comments only. At 08:73-75, say the base rate is recorded in &lt;model>_projpred_summary.rds (not in the path CSV, and left NA by 08b). Correct the 08:84-86 column list: size is the forward-search step, there is no rank column, and add cv_prop_diag, suggested_size, is_suggested, n_folds and n_participants.
- **Status:** resolved in 2352752: The rest of it: "across projpred versions" wording; 08b's stale STATUS (it claimed it produced the shipped CSVs, which 08 wrote in 8826760/8826761/8910229) and its stale n=56/50 corrected. Later that day 08b itself (HTC 8976037) rewrote the three path CSVs from those runs' cached varsel objects, adding the search-setting columns, and 51bdb75 pulled them, so the STATUS was corrected again on 8 October 2026.

### G14-09. install_eegutils.slurm installs an unpinned eegUtils and exits 0 even when the install fails

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/hpc/install_eegutils.slurm:34`
- **Fix:** Preferred, pending the author's keep-or-retire decision already raised in POLISH_FLAGGED_2026-08.md:587: retire the script, since the restore job (00_restore_environment.slurm:57) installs the pinned eegUtils. If it is kept: 1. Drop the r-universe route, which keeps no archive and cannot deliver the pin. 2.
- **Status:** partly resolved (1246e9b). Retiring the script is the author's decision.

### G14-10. 11_extract_predictor_reliability.R: no function has a docstring; header omits the Stroop switch and tagged output

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/11_extract_predictor_reliability.R:160`
- **Fix:** 1. Add LES_P2_STROOP_KEEP_PRACTICE to the header's Env knobs, with a line saying it tags both the indices file read and the CSV written. 2. Name both tagged files in OUTPUT and in the self-validation paragraph. 3. Add a short `#` comment block above les_predictor_reliability(): the `session` argument (default 1, the baseline);
- **Status:** resolved in 2352752: 11's header documents `LES_P2_STROOP_KEEP_PRACTICE`, the tagged input and output, the `_s<session>` suffix and the participant-set check, and every function has a doc block.

### G14-17. Stale wording in submit_all.sh: stage graph wrong, 'two' settings lists three, squeue hint misses HTC jobs

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/hpc/submit_all.sh:6`
- **Fix:** 1. **`submit_all.sh:28`:** change 'Two' to 'Three'. Drop "both with the values this project actually uses", or scope it to the first two. 2. **Graph at `:6-8`:** redraw as 01 -> 02 -> 04 and 01 -> 05, with 04 and 05 feeding 06 and 03 shown unlinked (optional, no dependency). 3.
- **Also reported as:** X1-10
- **Status:** resolved in 1533b4a.

### G14-18. hpc/README.md has stale claims: IAF refit 'queued', osfr installed, stage 06 output list incomplete

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/hpc/README.md:9`, `paper_2_plasticity/hpc/00_install_dependencies.slurm:6`, `paper_2_plasticity/hpc/06_summaries.slurm:4`, `paper_2_plasticity/hpc/README.md:154`
- **Fix:** 1. **IAF status, `README:8-9`:** say the IAF-resolved gender-only refit ran on HTC (job 8699736, 2026-09-06) and its artefacts are in the pooled CSVs. 2. **osfr, `README:50-52` and `00_install_dependencies.slurm:6-7`:** stop saying the shared installer installs or guarantees osfr. Say instead that osfr is pinned in `renv.lock` and used only by the reconnaissance probes.
- **Status:** resolved in 913c035.

### G14-19. Sample sizes hard-coded in HPC comments and README (56/29,565 and 50/26,454) that the Stroop refit may change

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/hpc/09b_compare_commonsample.slurm:8`, `paper_2_plasticity/hpc/README.md:75`, `paper_2_plasticity/hpc/10_compare_aperiodic.slurm:6`, `paper_2_plasticity/hpc/09c_compare_grouped.slurm:23`
- **Fix:** 1. Leave the historical narratives (the naive loo_compare failure, the 09c cost measurement, 08b's quoted log lines) as they are, but date them, for example "in the 2026-07/08 fits". 2. Where a count is written in the present tense (`hpc/README.md:75`, `paper_2_plasticity/README.md:33`, `09b_compare_commonsample.slurm:6`), either drop the literal N ("the aperiodic model's small ...
- **Status:** partly resolved (475dd3b). The historical counts in a few comments are still undated. On 8 October 2026 the 09b row of `hpc/README.md` replaced its present-tense count of 50 with 49, dated to the exclusion of participant 14.

### G14-20. Log-name tags drift from artefact tags (04 slurm '_weak' vs '_weakprior'); 07 slurm logs a typo mode as if it ran

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/hpc/04_fit_predictors.slurm:30`, `paper_2_plasticity/hpc/07_aperiodic.slurm:33`, `paper_2_plasticity/scripts/07_extract_aperiodic.R:464`
- **Fix:** 1. **`04_fit_predictors.slurm:29-31`:** build the log tag in the artefact order and spelling: IAF first (`_iafres`), then `_weakprior`. 2. **`07_aperiodic.slurm`:** after `MODE="${1:-fixed}"`, add `case "$MODE" in fixed|knee) ;; *) echo "unknown mode '$MODE' (expected fixed or knee)" >&2; exit 1;; esac`.
- **Status:** resolved in 1246e9b and 913c035.

### G15-15. manuscript_setup.R: none of its ~50 functions has a roxygen docstring

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/manuscript_setup.R:26`
- **Fix:** First decide one convention for the whole codebase: roxygen everywhere, or the current comment blocks everywhere. Until then, in manuscript_setup.R: add a one-line purpose comment to .pretty_term, and to gamma_att_ready, aper_kf_ready, proj_n and signaligned_ready if wanted;
- **Status:** obsolete (8 October 2026). `.pretty_term()`, the one function the fix required a comment on, had no call site in the setup file, the article or the supplement, and the pass of 8 October deleted it from `manuscript_setup.R` in the working tree. `proj_n()` went with the projection-predictive ranking, and `gamma_att_ready()`, `aper_kf_ready()` and `signaligned_ready()` sit directly under the comment blocks of what they test. The convention the fix asks to settle is the one `_shared/R/README.md` has stated since 9c5c273, plain `#` comment blocks with no roxygen2 documentation built from them.

### G15-20. Stale comments: header dependency list, the .005 example, and the supplement's 'identical setup' claim

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/manuscript_setup.R:12`, `paper_2_plasticity/manuscript_setup.R:534`, `paper_2_plasticity/manuscript_setup.R:274`, `paper_2_plasticity/supplement.qmd:100`
- **Fix:** Rewrite manuscript_setup.R:11-13 to list what the file uses (.read_csv_if, apa_num and prov from 06; paper2_results from 00_paths.R; LES_P2_MODELS, les_p2_model_id and LES_P2_RS_MEASURES from _config.R) and to say that flow_n() and pstat() read the tables loaded here. Make the .005 example name its model ('the aperiodic model's working-memory lower bound is .005').
- **Status:** resolved in 913c035.

### G15-22. results/README names a nonexistent section and its writer map omits files the manuscript reads

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/results/README.md:42`
- **Fix:** Replace the section name at README.md:42-44 with the actual locations (the Part A Results and tbl-reliability; Limitations, the 'Reliability of the baseline predictors' appendix and supplement S1). Extend the outline to step 13 (_task_durations_home.csv, _task_durations_lab.csv, both papers).
- **Status:** resolved: the README names the locations, and says step 06 writes _prior_sensitivity.csv (b2f67f0).

### G16-18. None of the ~60 setup-chunk functions has a roxygen docstring with parameters, return value and inputs

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:235`
- **Fix:** Do not add roxygen blocks to ~60 functions. Add one short convention comment at the head of the setup chunk (after qmd:199). It should state what an accessor returns when its artefact is missing ('NN' for bare counts, a \*[...]* marker for estimates and sentences, "" for optional clauses, NULL for internal row selectors) and which global tables (post_tbl, retention_tbl, sens_tbl ...
- **Status:** partly resolved: the accessors' conventions are documented in one block (2e89d05).

### G16-20. Stale or misplaced comments in the setup chunk and table chunks

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/paper_1_morphosyntax.qmd:264`, `paper_1_transfer/paper_1_morphosyntax.qmd:1002`, `paper_1_transfer/paper_1_morphosyntax.qmd:1033`, `paper_1_transfer/paper_1_morphosyntax.qmd:2347`, `paper_1_transfer/paper_1_morphosyntax.qmd:3507`
- **Fix:** Move the provenance comment (264-266) down to `.prov_tbl` at 326 and drop 'Absent until the pipeline is next run'. Move the exclusion-guard rationale (267-278) to sit by misfilter_status() at 317-319. At 1002-1005 and 1033-1035, reword the comments to say the marker prints only when the row or artefact is missing, without calling the run 'queued'.
- **Status:** resolved in 2e89d05.

### X1-09. Installer docs claim tidybayes, bayestestR and osfr are installed; install_bayesian_dependencies.R does not install them

- **Severity:** MINOR (reported as MAJOR). Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/hpc/README.md:50`, `paper_1_transfer/hpc/README.md:54-55`, `paper_1_transfer/hpc/00_install_dependencies.slurm:5-6`, `paper_2_plasticity/hpc/00_install_dependencies.slurm:6-7`
- **Fix:** Documentation only. Make the four descriptions match required_packages plus the non-CRAN steps of install_bayesian_dependencies.R: brms + CmdStan, posterior, bayesplot, loo, papaja, quarto, cmdstanr and eegUtils. The four sites are P2 hpc README:50-51, P1 hpc README:54-55, paper_1_transfer/hpc/00_install_dependencies.slurm:5-6 and paper_2_plasticity/hpc/00_install_dependencies. ...
- **Status:** resolved: the installer descriptions match its package list (470c446 for Paper 2's HPC README; the others in cebe08c, 05688a1 and 475dd3b).

### X2-06. README says all 422 renv.lock packages are what the cluster library holds; depictr and scopusflow never were

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `README.md:46`, `README.md:74`, `renv.lock`
- **Fix:** Reword README.md:45-48 to say renv.lock holds the 420 packages snapshotted from the cluster library (module library plus R_LIBS_USER), plus two records added by hand for the render-side and literature-count packages depictr and scopusflow, which are not installed on the cluster. Align AUTHOR_TASKS.txt:570 and HPC_RUNBOOK.md:89 with that wording.
- **Also reported as:** X4-05
- **Status:** resolved in 5b50d49: AUTHOR_TASKS glossary entry for renv.lock (422 = 420 snapshotted + depictr and scopusflow added by hand). README and runbook were already right. renv.lock checked: 422 records, R 4.5.1, renv 1.2.3, depictr/scopusflow/cmdstanr/eegUtils from GitHub, no Bioconductor block, so no hand fix is needed.

### X2-07. Installer's hand-kept package list provisions ggtext, patchwork, purrr and the quarto R package, which no cluster code loads

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/install_bayesian_dependencies.R:64`, `_shared/install_bayesian_dependencies.R:75`, `_shared/install_bayesian_dependencies.R:100`
- **Fix:** Drop "ggtext", "patchwork" and the "quarto" R package from required_packages. Rendering uses the Quarto CLI on the Windows box, per paper_1_transfer/README.md:193. Rewrite the :63 comment so it no longer claims the new code uses these packages. Removing purrr and scales is optional, since other packages Import them anyway.
- **Status:** resolved in 5b50d49: Dropped `ggtext`, `patchwork` and the `quarto` R package from the bootstrap. No cluster code loads them; renv.lock still pins them, so the restore route is unchanged. Kept `purrr`: it is in 08's tensor fingerprint package list.

### X4-06. Root README says Paper 2 prints versions as pending and that no record can carry CmdStan; both are false

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `README.md:51`
- **Fix:** Rewrite README.md:50-54 to say three things. Paper 2's current _provenance.csv was recovered from the fitted objects by 06b_recover_provenance.R, as its record_source row states, and the next run of 04 overwrites it. _provenance.csv records the CmdStan version. renv.lock does not, and neither file records the GCC toolchain or the -O1 pin, which live in arc_env.sh.
- **Status:** resolved in commit 744f10c

### X4-07. Runbook names only with_install and says the restore job goes on its own, but both chains take with_restore

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `HPC_RUNBOOK.md:131`
- **Fix:** In HPC_RUNBOOK.md section 1, and in the section-0 note at :110-112, name `submit_all.sh with_restore` as the pinned route that chains the pipeline on 00_restore_environment.slurm with afterok. Keep `with_install` as the unpinned bootstrap. Say that a restore submitted by hand has to finish before the chain is started with no argument.
- **Status:** resolved in commit 744f10c

### X4-08. Runbook and Paper 2 submit_all.sh say 05 gains rs-EEG predictors when the rds exists; Part B has none

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `HPC_RUNBOOK.md:193`, `paper_2_plasticity/hpc/submit_all.sh:10`
- **Fix:** Change HPC_RUNBOOK.md:192-194 to say that only 04 picks up the Session-2 rs-EEG baseline predictors once resting_state_eeg.rds exists, and that 05's rs-EEG pre/post block skips because no Session-6 recording exists. Reword submit_all.sh:10-13 the same way ('04 includes the rs-EEG predictors when present; 05 fits cognition only'), keeping its existing Part B sentence.
- **Status:** resolved before this pass (verified 3 October 2026): Runbook fixed (744f10c). `paper_2_plasticity/hpc/submit_all.sh:8-13` needs patch #4a.

### X4-09. Paper 1 stage labels collide: hpc/README's '1b' and 'stage 3' are different scripts in the README

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_1_transfer/hpc/README.md:77`, `paper_1_transfer/README.md:20`, `HPC_RUNBOOK.md:153`
- **Fix:** In paper_1_transfer/hpc/README.md, drop the 1a/1b/2a/... stage labels and use the job-script numbers as identifiers in the table, at :39, :126-127 and in the variant table. Alternatively, add a sentence saying the stage labels are job stages and are unrelated to the script step numbers in ../README.md. No change to the authority statements is needed.
- **Status:** resolved in commit 05688a1

### X4-11. Root README says every per-paper folder has a README, but data_derived/ has none; root files unlisted

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `README.md:24`
- **Fix:** Take data_derived/ out of the README.md:24 sentence, for example: '... Each of scripts/, hpc/, results/ and figures/ carries a README.md of its own; data_derived/ is not in version control and is described in the paper README.' Optionally add AUTHOR_TASKS.txt to the root table beside the other working logs.
- **Status:** resolved in 5b50d49: README rows for CHANGELOG.md, ISSUES.md, AUTHOR_TASKS.txt and CITATION.cff.

### X4-12. CITATION.cff lists OSF as the code repository while both manuscripts cite GitHub; Silva's ORCID is missing

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `CITATION.cff:39`
- **Fix:** Add `orcid: "https://orcid.org/0000-0002-5349-7036"` to Silva in CITATION.cff. Optionally add the two per-paper GitHub repositories as `identifiers` entries and update the :3-6 comment to record that they exist. Leave repository-code as OSF, which the manuscripts name as the archive, unless the author decides otherwise under AUTHOR_TASKS 2.3.
- **Status:** resolved in 5b50d49: Silva's ORCID was already present. Added both per-paper GitHub repos as `identifiers` and rewrote the header comment. Validated with `yaml::read_yaml` (10 authors, 4 identifiers).

### X4-14. Private email draft to a co-author (PI_EMAIL_UPDATED.md) is tracked in the compendium

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `PI_EMAIL_UPDATED.md:3`
- **Fix:** Optional hygiene for the author to decide: untrack the draft (git rm --cached PI_EMAIL_UPDATED.md, plus a .gitignore entry) and keep it outside the repository. The copy in 7d8bafd stays in this branch's history, but that history is only in the private archive and not in the public per-paper repositories.
- **Status:** resolved 17 October 2026: PI_EMAIL_UPDATED.md and PI_REPLY_2026-09-16_es.md are no longer tracked (git rm --cached; the files stay on disk), and .gitignore excludes PI_*.md. The earlier copies remain in this private repository's history.

### X5-06. les_assert_readonly_data prefix test is case-sensitive and has no path boundary, so it misses and misfires

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `_shared/R/03_data_manifest.R:126`
- **Fix:** In les_assert_readonly_data(): (1) normalise each output path as file.path(normalizePath(dirname(p), winslash = "/", mustWork = FALSE), basename(p)) so existing parents are canonicalised; (2) on Windows (.Platform$OS.type == "windows") compare tolower() of both sides;
- **Status:** resolved in commit edbdeff

### X5-07. `* text=auto` rewrites line endings of the raw data exports, so repo and cluster copies differ byte for byte

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `.gitattributes:2`
- **Fix:** Documentation only (no blob rewrite). Add a comment under the `* text=auto` rule in .gitattributes, and a sentence in HPC_RUNBOOK.md's data section, saying: the text inputs under data/ (CSVs, BrainVision .vhdr/.vmrk/.txt exports, lab logs) are stored LF-normalised, so they match the CRLF instrument originals and the cluster copy only after CRLF->LF conversion;
- **Status:** proposed: do not apply. Renormalising `data/**` would rewrite about 8,300 blobs and could not recover the CRLF originals. Every reader is line-based, and the comparison rule is documented.

### X6-08. No glossary: the same entities carry different names, types and scalings across scripts and papers

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/02_extract_learning_trajectory.R:59`, `paper_1_transfer/scripts/02_extract_accuracy.R:332`, `paper_1_transfer/scripts/02_extract_accuracy.R:382`, `paper_1_transfer/scripts/00d_extract_training_gate_flow.R:116`, `_shared/R/07_task_durations.R:231`, `paper_2_plasticity/scripts/06_summaries.R:196`
- **Fix:** Add a naming glossary (docs/glossary.md as the skill specifies, or a Glossary section in the root README if no docs/ folder is wanted). For each entity it should give the canonical name, the legacy aliases, the type and the defining file:line: - Participant: participant_lab_ID; participant_home_ID;
- **Status:** resolved before this pass (verified 3 October 2026): `docs/glossary.md` (926e4e9) covers every listed entity incl. the `subject` alias; the VOA expansion is still missing: patch P12.

### X6-09. Paper 2's config and banner still describe an S2-vs-S6 neural pre/post the manifest says cannot exist

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/scripts/_config.R:19`, `paper_2_plasticity/scripts/_config.R:137`, `_shared/R/03_data_manifest.R:82`
- **Fix:** Change wording only and leave the constant alone. - _config.R:19: say that cognitive pre/post is S1 vs S5, that resting-state EEG was recorded at S2 only, and that LES_P2_NEURAL_SESSIONS = c(2, 6) names the pair a neural pre/post would use;
- **Status:** resolved in 2352752.

### X7-04. Paper 2 results/README says its cross-paper copies keep cohort numbers aligned; Paper 2 reads 2 of 6

- **Severity:** MINOR. Fix could change a reported number: no.
- **Where:** `paper_2_plasticity/results/README.md:17`, `paper_1_transfer/scripts/00_extract_participants.R:363`, `paper_1_transfer/scripts/00b_audit_participant_flow.R:245`, `paper_1_transfer/scripts/00d_extract_training_gate_flow.R:236`
- **Fix:** Change only paper_2_plasticity/results/README.md; the rest needs sign-off. At :17-21, say that Paper 1's steps 0, 0b and 0d write the six cohort files into both papers' results/, but Paper 2's manuscript reads only _sample_flow.csv and _participants.csv (manuscript_setup.R:77-78).
- **Status:** partly resolved in commit 9a11c65. Not applied: Delete the four unread Paper 2 copies (remove paper2_results targets in 00/00b/00d, untrac; Removing the paper2_results targets from 00_extract_participants.R, 00b_audit_participant_; Whole finding


## Carried over from the 2026-09-12 pass
These six items were logged on 2026-09-12, before this audit, from a pass over the Paper 2 HPC stages queued for submission. They keep their original numbering. Items 1 and 2 are the cache-invalidation defects in `08_projpred_selection.R` and `09c_compare_aperiodic_grouped.R`; the audit found nothing that supersedes them.

### BLOCKING

#### 1. `08_projpred_selection.R` reuses a cvfits cache built from a superseded reference model

**Severity:** BLOCKING, HIGH-RISK (the projpred solution path is reported in the manuscript).
**Where:** `paper_2_plasticity/scripts/08_projpred_selection.R:276-285`.

The `<model>_cvfits.rds` cache is keyed on the model name alone:

```r
cvfits_path <- paper2_results(paste0(model_id, "_cvfits.rds"))
if (file.exists(cvfits_path)) {
  message("[projpred] ", model_id, " | reusing cached participant-grouped cvfits")
  cvfits <- readRDS(cvfits_path)
}
```

Nothing records which reference model the cached refits were built from. brms invalidates
the reference fit itself through `file_refit = "on_change"`, so when the fit is refitted on
changed data the cvfits cache beside it is left untouched and is silently reused.

This is live rather than hypothetical. On HTC at the time of the audit:

| cvfits cache | built | reference fit refitted |
|---|---|---|
| `p2_predictive_trajectory_cvfits.rds` | 2026-07-07 | 2026-09-11 20:57 |
| `p2_predictive_trajectory_gender_cvfits.rds` | 2026-08-09 | 2026-09-11 21:11 |
| `p2_predictive_trajectory_aperiodic_cvfits.rds` | 2026-07-07 | (refit by stage 09) |

The 2026-09-11 refits followed the Stroop rescore, and `z_stroop` is a Part A predictor
(`04_fit_brms_predictors.R:247`), so the cached refits rest on superseded predictor values.

There is a second consequence. `cv_varsel()` reads the fold vector back out of the `cvfits`
object rather than from `fold_info` (see the note at `08_projpred_selection.R:243-260`), so
a reused cache also reinstates its own fold assignment while the job log prints the fold
sizes computed fresh at line 208. The log would describe a fold structure the analysis did
not use.

**Proposed fix.** Stamp the cache with the reference model's data and formula plus the fold
vector, and refuse to reuse it on a mismatch, mirroring the guard that
`09c_compare_aperiodic_grouped.R:121-134` already applies to its own kfold cache. `digest`
is pinned in `renv.lock` at 0.6.37, so no new dependency is needed. Reading an old-format
cache yields a `NULL` stamp, which fails the comparison and triggers a recompute, so the
change degrades safely.

**Cost of the fix.** `run_cvfun` is the expensive step in stage 08 and would be recomputed
for every affected model. Stage 08 is already on the `long` partition.

**Status:** resolved in 2352752. The cache carries a stamp, `attr(cvfits, "les_stamp")`,
holding a hash of the reference fit's draws, the folds and the seed, and is reused only when
all three match. A cache written before the stamp existed is reused only when its folds
match and the file is newer than the reference fit, and the log says which rule applied.
Since 7 October 2026 the manuscript reports no solution path (G13-01), so a stale cache
could no longer reach a reported ranking in any case.

### MAJOR

#### 2. `09c` kfold cache validates the folds but not the model

**Severity:** MAJOR, HIGH-RISK (feeds `_aperiodic_kfold_compare.csv`, the criterion the
Discussion rests on).
**Where:** `paper_2_plasticity/scripts/09c_compare_aperiodic_grouped.R:121-134`.

`kf_cached()` stores `list(kf, folds)` and reuses the cache when
`identical(ck$folds, fd$folds)`. That correctly catches a changed fold assignment, but not a
changed *fit*. Where the participant set is unchanged the folds are identical, so a kfold
computed from a superseded model passes the guard. `_kfold_p2_predictive_trajectory_commonsample.rds`
(2026-08-15) and `_kfold_p2_predictive_trajectory_aperiodic.rds` (2026-08-16) both predate
the 2026-09-11 refits.

**Proposed fix.** Extend the existing stamp to carry the fit identity alongside the folds,
the same stamp used for finding 1.

**Status:** resolved in 2352752. The kfold cache holds the folds, a hash of the refitted
model's draws and the seed, and is reused only when all three match, so a cache written
before the stamp is recomputed. The rerun that ended on 4 October 2026 (HTC 8976040, pulled
on 7 October) ignored every older cache and recomputed it.

#### 3. `09_aperiodic_model.slurm` overwrites the provenance record

**Severity:** MAJOR.
**Where:** `paper_2_plasticity/hpc/09_aperiodic_model.slurm:52`.

The job's first step runs `04_fit_brms_predictors.R`, which writes `results/_provenance.csv`
unless `LES_PROVENANCE_SKIP=1` is exported. The script does not set it. `hpc/README.md:177`
scopes the guard to "stage 2a (`04`)" recipes only, so this path is not covered by the
documented rule, and the same class of error was recorded on 2026-09-06.

The record currently on HTC is a fit-time record written at 2026-09-11 20:11:38 UTC, and it
is truthful: the Part A fits it describes were genuinely produced that evening. A stage-09
run finishing up to three days later would replace it with a record describing the aperiodic
fit, after which the manuscript's availability sentence would date the reported Part A models
to that later day.

**Proposed fix.** Submit stage 09 with `--export=ALL,LES_PROVENANCE_SKIP=1`, and add the
guard to the stage-09 recipe in `hpc/README.md` so the rule is not scoped to stage 04 alone.

**Status:** resolved in 2352752. `09_aperiodic_model.slurm` exports `LES_PROVENANCE_SKIP=1`
unless the submitter sets it otherwise, and `HPC_RUNBOOK.md` says so.

#### 4. Documentation drift: the provenance record is under version control

**Severity:** MAJOR (documentation), no result affected.

`paper_2_plasticity/results/_provenance.csv` is tracked and was committed in `7d8bafd`
(2026-09-07) carrying the recovered record, including its `record_source`,
`fits_written_utc` and `fits_recorded` rows. Working notes from the September sensitivity
pass state the file is untracked and that restoring it from version control is not a
remedy. That is incorrect: `git show HEAD:paper_2_plasticity/results/_provenance.csv`
recovers the recovered record without a cluster job.

Note that the committed copy now describes the superseded June–July fits. Once the current
CSVs are pulled back it should be replaced by the 2026-09-11 fit-time record, which is an
end-product change for the author to make.

**Status:** open; documentation to be corrected.

### MINOR

#### 5. Stage numbering drift between `hpc/` and `scripts/`

**Severity:** MINOR.

- `10_compare_aperiodic.slurm` runs `09_compare_aperiodic.R`, so the stage number differs
  between the wrapper and the script it runs.
- Two wrappers share the `10_` prefix: `10_compare_aperiodic.slurm` and
  `10_descriptives.slurm`.
- `10_descriptives.slurm` runs both `10_extract_descriptives.R` and
  `12_extract_gamma_attenuation.R`, so stage 12 has no wrapper of its own.

Every script does have a wrapper, so nothing here is dead code; the numbering is simply not
a reliable index. **Status:** open, cosmetic.

#### 6. `renv.lock` lists r-universe repositories it deliberately does not rely on

**Severity:** MINOR.

`renv.lock` records `stan-dev` and `craddm` r-universe URLs under `Repositories`, while
`cmdstanr` and `eegUtils` are pinned by GitHub commit precisely because, as `README.md`
explains, r-universe keeps no archive and such a pin stops resolving. The entries are
harmless, since restore uses the GitHub records, but they invite the pin the README warns
against. **Status:** open, cosmetic.


## Reported but not carried as open
Recorded so that nothing reported is silently dropped. Duplicates were merged into the entry named; the known and refuted items were checked against the code and the project's records.

| Finding | Outcome | Where | Title |
|---|---|---|---|
| G01-09 | duplicate of G15-13 | `_shared/R/01_bayesian_settings.R:81` | Sampler settings and convergence thresholds are retyped as literals in both manuscripts, not injected |
| G01-11 | already known (POLISH_FLAGGED_2026-08.md:636-644 logs that n_treedepth is NA under cmdstanr and that the ...) | `_shared/R/02_diagnostics.R:48` | Default max_treedepth lookup reads an rstan-only slot, so n_treedepth is NA in every shipped row; |
| G02-06 | duplicate of G16-19 | `_shared/R/06_manuscript_helpers.R:78` | Pending-marker idioms are mixed: prov() prints \*[...]* but flow_n()/pstat() print bare 'NN' |
| G02-18 | duplicate of G02-17 | `_shared/R/codebook_descriptions.csv:108` | results/CODEBOOK.md is stale in both papers; some description rows name columns the committed CSVs lack |
| G02-19 | duplicate of G15-10 | `_shared/R/write_codebook.R:52` | write_codebook.R skips 07_aperiodic_features.csv as 'pipeline-internal', but the manuscript reads it |
| G02-21 | duplicate of G03-06 | `_shared/install_bayesian_dependencies.R:141` | Installer builds an unversioned CmdStan in the directory where arc_env.sh picks the newest tree |
| G02-24 | duplicate of G01-16 | `_shared/R/README.md:3` | _shared/R/README.md: 'Seven modules' omits 06_manuscript_helpers.R and 07_task_durations.R; |
| G03-13 | duplicate of G01-05 | `_shared/hpc/arc_env.sh:46` | Module, GCC, BLAS and -O1 pin of record are captured only in gitignored SLURM logs, not in any committed prove ... |
| G04-02 | already known (Disclosed deliberately in the manuscript (commit 7d8bafd, 2026-09-07).) | `paper_1_transfer/scripts/00c_extract_erp_retention.R:145` | 'Canonical' ERP retention, printed as per modelled cell, includes the 16 cells of the excluded datasets |
| G04-04 | duplicate of G16-03 | `paper_1_transfer/scripts/_config.R:360` | Exclusion guard's completeness test counts rows, not distinct cells, and ignores retention-free duplicates |
| G04-09 | duplicate of G16-08 | `paper_1_transfer/paper_1_morphosyntax.qmd:1605` | Both manuscripts hard-code 'The 16-year-old participant', contradicting comments that the clause is derived fr ... |
| G04-13 | duplicate of G09-07 | `paper_1_transfer/scripts/_config.R:315` | ERP grid is re-typed in the SLURM arrays and sorted alphabetically, contrary to its single-source claim |
| G04-24 | duplicate of G05-13 | `paper_1_transfer/scripts/_config.R:90` | RSVP window constant duplicates the late-window bound and misdescribes it (900 vs the configured 898) |
| G05-14 | duplicate of G06-14 | `paper_1_transfer/scripts/01_extract_erp_single_trials.R:83` | .les_scale() is defined verbatim in both 01 and 02 instead of once in _shared/R |
| G06-04 | already known (POLISH_FLAGGED_2026-08.md:529-548 logs both gaps as "REAL DATA LOSS" needing the author's ...) | `paper_1_transfer/scripts/02_extract_accuracy.R:48` | Session-4 judgements of participants 3, 5, 6 and 20 are still discarded (now disclosed) while their S4 ERP is ... |
| G06-12 | duplicate of G16-07 | `_shared/R/codebook_descriptions.csv:2` | Codebook lists two 'reason' values for _accuracy_input_gaps.csv, but 02 writes and ships a third |
| G06-14 | duplicate of G02-03 | `paper_1_transfer/scripts/02_extract_accuracy.R:97` | Duplicated helpers: .les_scale defined in both 01 and 02; item-slope switch re-read in _config.R |
| G06-15 | duplicate of G01-14 | `paper_1_transfer/scripts/03_fit_brms_erp.R:275` | Extensionless brms cache paths make paper1_results() create an empty directory per model tag |
| G07-01 | duplicate of G16-01 | `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:121` | Pooled CSVs mark variants only in model id; manuscript selectors admit _keepmisfiltered and _diversity rows |
| G07-04 | duplicate of G16-03 | `paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R:139` | Retention-free fit records now classed maximal count toward the exclusion guard's 18-cell completeness check |
| G07-13 | duplicate of G16-12 | `paper_1_transfer/results/_pooled_convergence.csv:1` | Committed pooled CSVs predate current step 5: 12 maximal retention-free fits labelled base structure |
| G07-15 | duplicate of G09-17 | `paper_1_transfer/hpc/05_summaries.slurm:5` | 05_summaries.slurm header lists three of step 5's six outputs |
| G08-11 | already known (POLISH_FLAGGED_2026-08.md:410-415 ('library(MASS) ... attached but never used ...) | `paper_1_transfer/scripts/09_run_decoding.R:106` | MASS is attached but never called (dead dependency) |
| G09-04 | duplicate of G03-06 | `paper_1_transfer/hpc/submit_all.sh:56` | submit_all.sh with_restore, 'the reproduction route', does not pin CmdStan for the fits it chains |
| G09-11 | duplicate of G03-07 | `paper_1_transfer/hpc/99b_test_O2.slurm:24` | Strict mode starts only after arc_env.sh is sourced, pipefail is never set, and 99b omits errexit without sayi ... |
| G10-06 | duplicate of G11-02 | `paper_2_plasticity/scripts/_config.R:119` | Per-fit record lacks data-version fields: which Stroop scoring or input file a Paper 2 fit used is unrecorded |
| G10-13 | duplicate of G15-07 | `paper_2_plasticity/results/_predictor_values.csv:273` | Committed _predictor_values.csv predates 01's unenrolled-record drop; |
| G11-11 | duplicate of G06-06 | `paper_2_plasticity/scripts/04_fit_brms_predictors.R:412` | Silent try() hides failures of the PPC figure and the provenance write, leaving the previous artefacts in plac ... |
| G11-13 | duplicate of G01-14 | `paper_2_plasticity/scripts/04_fit_brms_predictors.R:379` | Passing an extension-less path to paper2_results() creates an empty directory per model in results/ |
| G11-16 | duplicate of G01-13 | `paper_2_plasticity/scripts/_config.R:115` | The fitmeta prior_set is the raw env var while file tagging lowercases it, so records can disagree with the pr ... |
| G12-11 | duplicate of G15-10 | `paper_2_plasticity/results/README.md:13` | results/README says the manuscript never reads 07_aperiodic_features.csv; manuscript_setup injects from it |
| G12-17 | duplicate of G15-05 | `paper_2_plasticity/manuscript_setup.R:183` | Gamma fallback prose ('about a third, IQR a quarter to a half') contradicts 12's artefact (6.5%, single-pass 2 ... |
| G13-04 | already known (ISSUES.md #1, 'There is a second consequence' paragraph (lines 40-44).) | `paper_2_plasticity/scripts/08_projpred_selection.R:438` | n_folds reported to the manuscript comes from fold_info, not from the cvfits cv_varsel actually used |
| G13-05 | duplicate of G15-02 | `paper_2_plasticity/scripts/08b_recover_projpred_path.R:43` | Manuscript sample sizes come from participant counts 08b hard-coded (56L/50L) into two path CSVs |
| G13-10 | duplicate of G11-05 | `paper_2_plasticity/scripts/09b_compare_aperiodic_commonsample.R:88` | 09b's fitmeta is rewritten on cache hits, stamping today's time and package versions onto an older fit |
| G13-22 | duplicate of G15-13 | `paper_2_plasticity/paper_2_neuroplasticity.qmd:844` | The Method hard-codes K = 10 for 09c while K is env-configurable and recorded in the artefact |
| G14-07 | duplicate of G03-14 | `paper_2_plasticity/hpc/README.md:15` | hpc README and HPC_RUNBOOK say submit_all.sh submits to ARC with plain sbatch; |
| G14-12 | duplicate of G02-11 | `paper_2_plasticity/scripts/13_extract_task_durations.R:14` | Task-duration job writes whatever the extraction returns, even empty or partial, over both papers' tables |
| G14-14 | already known (POLISH_FLAGGED_2026-08.md:852-858 lists 10_compare_aperiodic.slurm with 09_compare_aperiod ...) | `paper_2_plasticity/hpc/10_compare_aperiodic.slurm:22` | Superseded 10_compare_aperiodic.slurm and 09_compare_aperiodic.R kept live; |
| G14-16 | duplicate of G10-05 | `paper_2_plasticity/hpc/10_descriptives.slurm:33` | 10_descriptives.slurm unsets a Stroop switch that neither script reads; |
| G15-01 | duplicate of G11-01 | `paper_2_plasticity/manuscript_setup.R:69` | _prior_sensitivity.csv feeds five reported values but no Paper 2 pipeline step writes it |
| G15-21 | duplicate of G02-17 | `paper_2_plasticity/results/CODEBOOK.md:3` | CODEBOOK.md is stale: the manuscript-facing _task_durations_home/lab.csv are missing |
| G16-04 | duplicate of G09-02 | `paper_1_transfer/paper_1_morphosyntax.qmd:3322` | Decoding seed is printed from a typed fallback literal because _decoding_provenance.csv is never pulled |
| G16-13 | duplicate of G02-17 | `paper_1_transfer/results/CODEBOOK.md:3` | CODEBOOK.md omits the task-duration CSVs the manuscript reads; _rsvp_timing row description is wrong |
| X1-01 | duplicate of G08-02 | `paper_1_transfer/scripts/09_run_decoding.R:621` | Decoding checkpoints omit LES_DECODE_RIDGE and LES_DECODE_CLUSTER_ALPHA, so changed values silently reuse stal ... |
| X1-02 | duplicate of G03-05 | `_shared/hpc/deploy_to_cluster.sh:64` | deploy_to_cluster.sh file list omits files cluster jobs run, and its live-job filter drops les_* jobs |
| X1-03 | duplicate of G03-04 | `_shared/hpc/README.md:22` | Deploy docs still say it refuses while a paper's job is live; uncommitted code now withholds only clashing fil ... |
| X1-04 | duplicate of G03-14 | `paper_2_plasticity/hpc/README.md:14` | P2 hpc README and runbook say submit_all.sh uses plain sbatch to ARC; the uncommitted script defaults to HTC |
| X1-06 | duplicate of G02-03 | `_shared/R/06_helpers.R:21` | Paper 1 defines .les_scale twice, duplicating les_zscore(); shared docs claim Paper 1 uses les_zscore |
| X1-07 | duplicate of G16-17 | `paper_1_transfer/paper_1_morphosyntax.qmd:516` | Two Paper 1 manuscript helpers have zero call sites: .n_perm_used() and retfree_val() |
| X1-08 | duplicate of G02-24 | `_shared/R/README.md:3` | _shared/R READMEs list seven modules and omit sourced 06_manuscript_helpers.R and 07_task_durations.R |
| X1-10 | duplicate of G14-17 | `paper_2_plasticity/hpc/submit_all.sh:28` | Stale orchestration comments: P2 submit_all.sh says 'Two' env settings but lists three; |
| X3-03 | refuted ([refuted] Checked: 08_decoding.slurm:59 (`--array=0-2`), :79 (`export LES_DECODE_SEED="${LES_DECODE_SEED:-20260702}"`), ...) | `paper_1_transfer/hpc/08_decoding.slurm:79` | All three decoding array tasks start from the same RNG state, set.seed(20260702), with no per-task seed or rat ... |
| X3-04 | already known (METHODS_FIGURES_AUDIT_2026-07.md:259 ("Undersampling is not a bug ...) | `paper_1_transfer/scripts/09_run_decoding.R:253` | Observed decoding AUC uses a fresh random undersample at every time point and fold, so the reported time cours ... |
| X3-06 | already known (Partly logged. ISSUES.md item 1 (around lines 40-48) records that a reused cvfits cache br ...) | `paper_2_plasticity/scripts/08_projpred_selection.R:329` | Projpred and grouped-kfold outputs record neither the seed nor the fold assignment; |
| X4-05 | duplicate of X2-06 | `README.md:46` | README says renv.lock holds only cluster-library versions, yet says depictr and scopusflow are not on the clus ... |
| X4-10 | duplicate of G09-20 | `paper_1_transfer/README.md:41` | Paper 1 README still says the gender exploratory decoding needs resubmitting, though the rerun is submitted |
| X4-15 | duplicate of X1-05 | `_shared/install_bayesian_dependencies.R:133` | LES_INSTALL_CORES and LES_CODE_ROOT are read by shared code but documented nowhere |
| X5-08 | duplicate of X3-07 | `paper_2_plasticity/scripts/11_extract_predictor_reliability.R:66` | Split-half seed LES_REL_SEED is a literal in 11 and in codebook prose, outside config and provenance |
| X6-10 | duplicate of X3-07 | `paper_2_plasticity/scripts/11_extract_predictor_reliability.R:66` | Seeds live in three places with three override mechanisms and no registry |
| X6-11 | duplicate of G10-17 | `_shared/R/03_data_manifest.R:136` | Shared modules and both _config.R files print banners with cat() on source, while scripts log with message() |
| X6-12 | duplicate of G10-16 | `paper_1_transfer/scripts/_config.R:277` | exists('les_assert_readonly_data') guards can never be false; both papers' writers have one, contrary to G10-1 ... |
| X7-02 | already known (SETTLED item 2 (committed Paper 2 results still reflect the old index until the refit land ...) | `paper_2_plasticity/paper_2_neuroplasticity.docx:1` | Tracked Paper 2 .docx/.pdf still print the superseded Stroop Method; |

## Audit steps and their outcome

The strong-codebase workflow has nine steps. This section records what each produced, and
what could not be done, so that the audit is not read as more complete than it is.

**1. Inventory.** R only: 60 live R files, 34 SLURM job scripts and 4 shell scripts in
`_shared/` and the two paper folders, three Quarto documents (both manuscripts and the Paper 2
supplement) with their setup code, and the documentation. No Python, Julia or container
definition is in use; the Singularity image of the retired `lmerTest` pipeline is kept for
reference only. The legacy trees (`analyses/`, `HPC scripts/`, `stimulus_preparation/`,
`session_materials/`) were read only where live code sources them.

**2. Reproducibility pins.**

| Pin | Result | Findings |
|---|---|---|
| R packages (`renv.lock`) | Pass, with gaps. 422 records, R 4.5.1, snapshotted on ARC; every package live code loads is pinned. No job checks the loaded library against the lockfile, and the unpinned installers write into the library the restore fills. | X2-03, X2-06, X2-07 |
| CmdStan | Partial. 2.39.0 is pinned by the restore job, but the version is typed in several places and `arc_env.sh` picks the newest `cmdstan-*` tree. | G03-06, X2-05 |
| Stan backend | Partial. `LES_REQUIRE_CMDSTANR` is exported by no job, so a missing cmdstanr falls back to rstan. | X2-04 |
| Render environment | Fail. Recorded only in prose, without the versions of the packages that draw the figures and format the numbers at render time. The vendored apaquarto carries unmarked local patches that differ between the papers. | X2-01, X2-02 |
| Seeds | Partial. `LES_SEED` is set in config and recorded in `_provenance.csv`, but adaptive `reduce_sum` makes the draws reproducible only up to Monte Carlo error; the three decoding array tasks share one RNG state; the 09c K-fold refits and the Figure S1 jitter are unseeded. | G01-01, X3-01, X3-03, G13-07 |
| Containers | Not applicable. No image is used by the current pipelines. | |
| Data inputs | Fail. No raw input is checksummed or versioned, and the cluster's copy of the data is never verified. | X5-02, X5-04, X5-05 |

**3. Code-health sweep.** The entries above, with file and line evidence, severity and the
HIGH-RISK flag.

**4. Determinism gate.** Run on 13 September on the Windows render box under R 4.6.1, which is
not the `renv.lock` environment; rebuilding from the lockfile is a cluster operation and was
not attempted. Two independent scratch copies of the code, pointed read-only at the data in
`new_LESS`, ran the local extraction and descriptive stages: Paper 1 steps 00, 00b, 00c, 00d,
01b, 02 and 07c, and Paper 2 steps 01, 02, 10 (without its resting-state PSD writer), 11, 12
and 13. The EEG-scale stages, every model fit, projpred, decoding and the Scopus query were
skipped. Of 41 outputs, 39 were byte-identical between the two copies; the other two differ
only in the wall-clock `generated_utc` stamp (X3-05). Against the committed artefacts, every
content difference is explained by the Stroop test-block rescore or the removal of `start_ms`
and `end_ms`, apart from three stale committed files (G15-07, DET-02, G12-16). All three
repository test scripts passed: `test_exclusion_guard.R` 26 checks, `test_summarise_cells.R`
14, `test_erp_retention_artefact.R` 5. The 248 non-EEG input files the local stages read
matched HEAD's tracked blobs; the EEG exports were not hashed.

**5. Data and configuration versioning.** See X5-02 (no checksum manifest), X5-04 (inputs
edited by hand or produced outside the pipeline, with no provenance), X5-05 (the pull-back
recipe records nothing) and X5-01 (participant 14's Session-2 language).

**6-7. Documentation and comments.** The fixes that alter no reported number were applied in
this pass, each in the commit its entry names, and were checked before committing: no
executable token changed in any analysis script, the job scripts pass `bash -n`, and the
repository tests pass in a scratch copy. Fixes that land in the author's uncommitted files,
in a manuscript source or in a decoding-coupled file are marked deferred. The repository's
functions are documented with plain `#` comment blocks, not roxygen, and the new
documentation follows that convention, which `_shared/R/README.md` now states.

**8. Style and lint.** Not applied. A `lintr` 3.4.0 run over the 60 live R files under the
committed `.lintr` found 1,798 lints: 993 from `object_usage_linter`, almost all the
non-standard evaluation and cross-file definitions that the linter cannot resolve; 236
`pipe_consistency` (sixteen files use `%>%` and nine use `|>`, mixed within one file only in
`tests/test_summarise_cells.R`); 153 semicolons; 135 indentation; 81 braces; 62 object names;
44 commented-out code; 44 pipe continuation; 31 line length; and a handful of others. Two
genuinely unused assignments were found, `n_subjects` at
`00d_extract_training_gate_flow.R:181` and `conv` at `05_fit_brms_prepost.R:97`. No formatter
was run, for three reasons: `styler` is not installed on the render box; reformatting every
script would change the checksums that `deploy_to_cluster.sh` verifies while cluster jobs are
running and a reconciliation deployment is pending; and a mass reformat of scripts behind
reported results should come after the HIGH-RISK fixes, in a commit of its own.

**9. Report.** This file.

**What the audit could not reach.** The cluster copies of the code, data and fits (no ssh from
the audit); the fitted brms objects, none of which is on the render box; projpred, eegUtils
and osfr, which are not installed here, so their behaviour was checked against documentation
and source reading only; the EEG exports, which were not hashed; and anything needing the
network. The completeness pass that would have commissioned further reviewers was cut when a
usage limit interrupted the run, and only the six thematic sweeps it had lost were re-run.
