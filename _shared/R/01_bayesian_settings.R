# =============================================================================
# 01_bayesian_settings.R  --  Shared brms / Stan configuration for both papers
# =============================================================================
#
# This module centralises every modelling choice that should be IDENTICAL across
# the two manuscripts so that the analyses are mutually consistent and each
# decision is justified exactly once. Each block cites the methodological source
# that motivates it (statistics or domain), per the project's requirement that
# all choices be defensible.
# =============================================================================

suppressPackageStartupMessages({
  if (!requireNamespace("brms", quietly = TRUE)) {
    stop("brms is required. Run _shared/install_bayesian_dependencies.R first.")
  }
  library(brms)
})

# -----------------------------------------------------------------------------
# 1. STAN BACKEND  --  cmdstanr with within-chain threading
# -----------------------------------------------------------------------------
# We use cmdstanr rather than rstan because it tracks the current Stan release
# and enables within-chain parallelisation via `reduce_sum` (the `threads`
# argument below), which materially shortens runtime for the large single-trial
# models on the HPC nodes (Carpenter et al., 2017, J. Stat. Soft.,
# https://doi.org/10.18637/jss.v076.i01; Stan Development Team, Stan User's Guide,
# "Reduce-sum" threading). If cmdstanr is unavailable the code falls back to
# rstan, which runs without reduce_sum threading (les_brm() passes no `threads` to it)
# and therefore samples a different Stan program, so such a run does not reproduce the
# reported draws.
#
# How exactly a rerun reproduces the draws: brms::threading() is called with its defaults
# (no grainsize, static = FALSE), which generates Stan's adaptive reduce_sum. Its
# scheduler splits the log-likelihood sum into partial sums at run time, so the order in
# which floating-point terms are added can differ between two runs with the same seed,
# data, thread count and CmdStan version (Stan Development Team, Stan Functions Reference,
# "Reduce-sum function"). The chains then diverge from rounding onwards, and a rerun
# reproduces the reported posterior summaries to within Monte Carlo error, not draw for
# draw. A rebuild-and-compare check therefore compares summaries against a tolerance of a
# few Monte Carlo standard errors rather than bytes. brms::threading(static = TRUE) with
# a fixed grainsize would make the partition, and so the draws, deterministic, but it
# changes the generated Stan code, so brms would refit every cached model and the
# reported fits would no longer be the ones the pipeline reproduces (ISSUES.md G01-01).
#
# On ARC the threading choice carries a compile-time cost. GCC 14.2.0, the compiler in the
# R/4.5.1-gfbf-2025a toolchain, crashes while instantiating Stan's reduce_sum templates at
# -O2 and above, so keeping threading pins the CmdStan build at -O1 (see
# _shared/hpc/arc_env.sh, which applies the pin and records the measurements). Threading
# was kept in preference to raising the optimisation level because dropping it changes the
# generated Stan code, so every cached fit would be refitted under a sampler configuration
# different from the reported fits', whereas the optimisation level leaves the Stan
# program, and so brms's cache, unchanged.
.les_backend <- if (requireNamespace("cmdstanr", quietly = TRUE)) "cmdstanr" else "rstan"
# That fallback is announced only by the cat() at the foot of this file and recorded in
# results/_provenance.csv (04_provenance.R). LES_REQUIRE_CMDSTANR=1, which a fitting job
# script can export, makes a missing cmdstanr stop the run here, and makes a CMDSTAN that
# cmdstanr cannot use stop it below.
if (identical(Sys.getenv("LES_REQUIRE_CMDSTANR"), "1") && .les_backend != "cmdstanr") {
  stop("LES_REQUIRE_CMDSTANR=1 but cmdstanr is not installed, so the fit would fall back ",
       "to rstan and not reproduce the reported draws. Restore the pinned environment.",
       call. = FALSE)
}

# Point cmdstanr at the CmdStan installation. On the cluster the job scripts export
# CMDSTAN=$LES_BASE/cmdstan/cmdstan-<version> (the C++ toolchain is kept in the project
# /data space, not on the personal disk). cmdstanr's load-time initialiser, which ran when
# requireNamespace() loaded the package above, already honours CMDSTAN, and it searches
# the default install locations only when CMDSTAN is unset. A CMDSTAN that names a missing
# folder leaves the CmdStan path unset. One that names a folder without a CmdStan makefile
# ends with the path pointing at that folder, and a half-built tree that keeps its
# makefile is accepted as it stands. In each case the first compile stops with an error,
# and cmdstanr does not move to another installation.
if (.les_backend == "cmdstanr") {
  .cmdstan_env <- Sys.getenv("CMDSTAN", unset = "")
  if (nzchar(.cmdstan_env)) {
    # This call repeats the assignment explicitly. A failure is only reported, because the
    # first compile stops anyway (see above), except under LES_REQUIRE_CMDSTANR=1, where
    # it stops here with the reason. The CmdStan version a fit used is recorded by the
    # per-fit metadata writers in each paper's _config.R and, for the runs that write it,
    # in results/_provenance.csv.
    .report_cmdstan <- function(e) {
      msg <- paste0("[bayes] CMDSTAN=", .cmdstan_env, " could not be set: ", conditionMessage(e))
      if (identical(Sys.getenv("LES_REQUIRE_CMDSTANR"), "1")) stop(msg, call. = FALSE)
      message(msg)
    }
    tryCatch(cmdstanr::set_cmdstan_path(.cmdstan_env),
             warning = .report_cmdstan, error = .report_cmdstan)
  }
}

# Number of threads PER CHAIN. On a SLURM node we request `--cpus-per-task`
# equal to CHAINS * THREADS_PER_CHAIN; here we read an env var so the same R
# code adapts to the cluster allocation without edits.
.les_threads_per_chain <- as.integer(Sys.getenv("LES_THREADS_PER_CHAIN", unset = "2"))

# -----------------------------------------------------------------------------
# 2. SAMPLER CONTROL  --  4 chains, NUTS, conservative adapt_delta / max_treedepth
# -----------------------------------------------------------------------------
# Four independent chains are the de-facto standard for assessing mixing via the
# rank-normalised split-Rhat (Vehtari, Gelman, Simpson, Carpenter & Bürkner,
# 2021, Bayesian Analysis, https://doi.org/10.1214/20-BA1221). We raise
# `adapt_delta` to 0.95 and `max_treedepth` to 12 because maximal random-effect
# models induce a challenging posterior geometry; higher adapt_delta reduces the
# step size and thereby the risk of divergent transitions (Betancourt, 2017,
# arXiv:1701.02434; Stan Dev. Team divergence guidance).
LES_CHAINS        <- 4L
LES_ITER_WARMUP   <- 2000L
LES_ITER_SAMPLING <- 8000L          # 4 * 8000 = 32000 post-warmup draws, raised from
                                    # 1000/2000 so the hardest single-trial ERP cells clear
                                    # the gate in 02_diagnostics.R (Rhat < 1.01, ESS > 400)
LES_SEED          <- 20260607L      # fixed, so a rerun reproduces the reported summaries
                                    # to within Monte Carlo error (see section 1)
LES_CONTROL       <- list(adapt_delta = 0.95, max_treedepth = 12L)

# Opt-in longer runs for a fit that misses the R-hat gate through slow mixing. The remedy
# for an R-hat above threshold with low ESS is to run the chains longer (Vehtari et al.,
# 2021); changing the seed instead would select a run that happens to pass. Only the
# warm-up and sampling lengths can be raised, never lowered, and the seed and control
# settings are untouched. A fit run this way records its iterations in its fit metadata
# (Paper 1: les_p1_write_fit_meta), so the deviation is visible per fit. Note that brms's
# on_change cache does not see iteration counts: move the cached fit aside to refit.
.les_iter_env <- function(var, default) {
  v <- Sys.getenv(var, unset = "")
  if (!nzchar(v)) return(default)
  n <- suppressWarnings(as.integer(v))
  if (is.na(n) || n < default)
    stop(var, "=", v, " is not an integer of at least the default ", default, call. = FALSE)
  n
}
LES_ITER_WARMUP   <- .les_iter_env("LES_ITER_WARMUP", LES_ITER_WARMUP)
LES_ITER_SAMPLING <- .les_iter_env("LES_ITER_SAMPLING", LES_ITER_SAMPLING)

# -----------------------------------------------------------------------------
# 3. PRIORS  --  INFORMATIVE on the standardised (z) scale (literature-derived)
# -----------------------------------------------------------------------------
# Paper 1 uses informative priors derived from a literature review carried out in June
# 2026, replacing the weakly-informative defaults used before then. Every DOI cited
# below is recorded in paper_1_transfer/references.bib, where the DOIs were checked
# against Crossref when they were added. The former defaults are retained below as
# `*_weak()` to serve as the documented prior-sensitivity baseline (Depaoli & van de
# Schoot, 2017, Psychological Methods,
# https://doi.org/10.1037/met0000065). All continuous predictors are z-scored and
# dichotomous predictors are +/-0.5 contrast-coded then z-scored (Brauer & Curtin,
# 2018, https://doi.org/10.1037/met0000159; Schielzeth, 2010,
# https://doi.org/10.1111/j.2041-210X.2010.00012.x), so coefficients share a common
# scale. The ERP response z_amplitude is standardised within participant, so every ERP
# coefficient is already in within-participant-SD units.
#
# STRATEGY = "selective, sign-informed, magnitude-regularising":
#   * The one robustly-evidenced DIRECTIONAL fact is encoded as a prior MEAN: a
#     posterior P600 in which the UNGRAMMATICAL condition is MORE POSITIVE than the
#     grammatical one in the ~400-900 ms window, reliable across native speakers and
#     artificial/miniature-language learners (Mueller, Hahne, Fujii & Friederici, 2005,
#     https://doi.org/10.1162/0898929055002463; Mueller, Hirotani & Friederici, 2007,
#     https://doi.org/10.1186/1471-2202-8-18; Chen, Shu, Liu, Zhao & Li, 2007,
#     https://doi.org/10.1017/S136672890700291X; Silva, Folia, Hagoort & Petersson,
#     2017, https://doi.org/10.1111/cogs.12343; Morgan-Short, Steinhauer, Sanz &
#     Ullman, 2012, https://doi.org/10.1162/jocn_a_00119).
#   * SIGN derivation from the data coding (import_trialbytrial_EEG_data.R):
#     grammaticality is coded Grammatical = +0.5, Ungrammatical = -0.5, so
#     z_recoded_grammaticality is HIGHER for GRAMMATICAL. Because the P600 makes the
#     ungrammatical condition MORE positive (higher amplitude), the grammaticality
#     slope in the P600 window is NEGATIVE  ->  prior normal(-0.2, 0.3).
#   * WINDOW GRADING of the grammaticality prior. The P600 onsets ~500 ms and is a
#     broad late positivity, so it occupies both the 400-900 ms window (full P600;
#     prior mean -0.2) AND the upper part of the 300-600 ms window (rising P600; milder
#     mean -0.1) for AGREEMENT violations, whose canonical late signature is a posterior
#     positivity, not an N400 (Chen, Shu, Liu, Zhao & Li, 2007: posterior P600 at
#     500-700 ms, https://doi.org/10.1017/S136672890700291X; Osterhout & Holcomb, 1992,
#     https://doi.org/10.1016/0749-596X(92)90039-Z). For DIFFERENTIAL OBJECT MARKING the
#     300-600 ms window is left NEUTRAL: case/DOM violations can elicit an N400 (opposite
#     sign) alongside the P600 (Mueller, Hahne, Fujii & Friederici, 2005,
#     https://doi.org/10.1162/0898929055002463), so the sign is ambiguous there. The
#     200-500 ms LAN window stays NEUTRAL for all properties: the anterior negativity is
#     small and present in only ~46-55% of subjects/items, so its sign is not safely
#     predictable (Caffarra, Mendoza & Davidson, 2019,
#     https://doi.org/10.1016/j.bandl.2019.01.003).
#   * TOPOGRAPHY: no longer modelled. Until 17 September 2026 the ERP models carried
#     grammaticality x caudality (with a positive prior encoding the posterior-maximal P600;
#     Mueller, Hirotani & Friederici, 2007, https://doi.org/10.1186/1471-2202-8-18) and
#     grammaticality x hemisphere (neutral) terms. The models now take one row per trial,
#     averaged over each macroregion's clusters, because the cluster rows of a trial are
#     not independent (Paper 1 ISSUES.md, N9), so both terms and the caudality prior were
#     removed.
#   * EVERYTHING ELSE stays zero-centred and weakly informative -- above all the
#     grammaticality x session x language TRANSFER interaction (the hypothesis under
#     test), which the literature shows is qualitatively CONTESTED in learners (Chen
#     et al., 2007; Mueller, Oberecker & Friederici, 2009,
#     https://doi.org/10.1186/1471-2202-10-89). Zero-centred priors there keep the
#     hypothesis test unbiased.
#   * VARIANCE components stay generous (heavy-tailed half-Student-t) to absorb the
#     large, systematic between-participant negativity<->positivity continuum (Tanner
#     & Van Hell, 2014, https://doi.org/10.1016/j.neuropsychologia.2014.02.002);
#     correlations keep LKJ(2) (Lewandowski, Kurowicka & Joe, 2009,
#     https://doi.org/10.1016/j.jmva.2009.04.008).
#   * MAGNITUDE: the review found no defensible microvolt effect size (the only numeric
#     uV anchor was refuted in verification), so prior MEANS are set on SIGN and kept
#     modest; the implied amplitudes are checked with PRIOR PREDICTIVE simulation
#     (Schad, Betancourt & Vasishth, 2021, https://doi.org/10.1037/met0000275) and the
#     weakly-informative baseline is reported as a sensitivity analysis (LES_PRIOR_SET).
# General prior-choice rationale: Gelman et al. (2008,
# https://doi.org/10.1214/08-AOAS191); Gelman (2006, https://doi.org/10.1214/06-BA117A);
# McElreath (2020, Statistical Rethinking).
# Every DOI above is present in paper_1_transfer/references.bib and was Crossref-verified
# when the entry was added (see the block headers in that file). The sources cited here
# without a DOI (Betancourt, 2017, an arXiv preprint; McElreath, 2020; the Stan User's
# Guide and Functions Reference) are background for these comments and are not in either
# paper's bibliography.

# --- INFORMATIVE priors: GAUSSIAN ERP models ---------------------------------
# `window`/`property` select the sign-informed P600 priors, graded by window and
# property (see the strategy notes above). Called per cell by step 03.
# `macroregion` is accepted so that the four prior builders share one call signature
# behind les_erp_prior() and les_acc_prior(). Step 03 does pass the cell's macroregion,
# but no prior is currently graded by it, so the argument is unused in the body. The same
# holds for `property` on the two bernoulli builders, which take it for parity only.
# `window` is one of "400_900", "300_600" or "200_500", or NULL, which leaves the
# grammaticality prior neutral. `property` is a property name as in LES_PROPERTY_CODES,
# or NULL. "differential_object_marking" gets the DOM grading below, and the two agreement
# properties the agreement grading. Any other window or property stops the call, because a
# misspelt one would otherwise fall through to the neutral or the agreement prior without
# a trace. Returns a brmsprior.
LES_ERP_PRIOR_WINDOWS <- c("200_500", "300_600", "400_900")
.les_check_prior_args <- function(window, property) {
  if (!is.null(window) && !(length(window) == 1L && window %in% LES_ERP_PRIOR_WINDOWS)) {
    stop("prior builder: unknown window '", paste(window, collapse = ", "), "'; expected one of ",
         paste(LES_ERP_PRIOR_WINDOWS, collapse = ", "), " or NULL.", call. = FALSE)
  }
  known <- if (exists("LES_PROPERTY_CODES")) names(LES_PROPERTY_CODES) else NULL
  if (!is.null(property) && !is.null(known) &&
      !(length(property) == 1L && property %in% known)) {
    stop("prior builder: unknown property '", paste(property, collapse = ", "),
         "'; expected one of ", paste(known, collapse = ", "), " or NULL.", call. = FALSE)
  }
  invisible(TRUE)
}
les_priors_gaussian <- function(window = NULL, property = NULL, macroregion = NULL) {
  .les_check_prior_args(window, property)
  pr <- c(
    # zero-centred default (incl. transfer interaction)
    brms::prior(normal(0, 0.5),       class = "b"),
    # DV is within-participant z -> ~0
    brms::prior(normal(0, 0.5),       class = "Intercept"),
    # generous RE SDs (Tanner & Van Hell, 2014)
    brms::prior(student_t(3, 0, 2.5), class = "sd"),
    # RE correlations (Lewandowski et al., 2009)
    brms::prior(lkj(2),               class = "cor"),
    # residual SD
    brms::prior(student_t(3, 0, 2.5), class = "sigma")
  )
  is_dom <- !is.null(property) && property == "differential_object_marking"
  # Window-graded P600 grammaticality mean (NEGATIVE: ungrammatical more positive,
  # grammatical coded +0.5). 400_900 = full P600; 300_600 = rising P600 (agreement only;
  # DOM left neutral, N400/P600 ambiguous); 200_500 = LAN window (neutral).
  # The SD is widened from 0.3 to 0.4 for DOM even in the full-P600 window because
  # case-marking violations are configuration-dependent, eliciting a P600, an N400 or a
  # biphasic response according to animacy and markedness. The sign is still the P600 one,
  # but it is held with less confidence than for the agreement properties. The manuscript
  # sets out this reasoning with its sources (paper_1_morphosyntax.qmd, prior section).
  gram_mean <- 0; gram_sd <- 0.3
  if (!is.null(window)) {
    if (window == "400_900") {
      gram_mean <- -0.2; gram_sd <- if (is_dom) 0.4 else 0.3
    } else if (window == "300_600" && !is_dom) {
      gram_mean <- -0.1; gram_sd <- 0.3
    }
  }
  if (gram_mean != 0) {
    pr <- c(pr, brms::prior_string(sprintf("normal(%s, %s)", gram_mean, gram_sd),
                                   class = "b", coef = "z_recoded_grammaticality"))
  }
  # The positive grammaticality x caudality prior that encoded a posterior-maximal P600 was
  # removed on 17 September 2026 with the caudality term itself: the models now take one
  # row per trial, averaged over the macroregion's clusters (01_extract_erp_single_trials.R).
  pr
}

# --- INFORMATIVE priors: BERNOULLI accuracy models ---------------------------
# Grammaticality-judgement accuracy is well above chance and improves with training
# (Mueller, Oberecker & Friederici, 2009, https://doi.org/10.1186/1471-2202-10-89:
# learners 89%, natives 99%, significant gain across blocks). session is coded
# 0,1,2,3 (later = higher), so the training effect on accuracy is a POSITIVE session
# slope; the intercept sits clearly above chance (logit ~ +1.5..2). `property` is unused
# (see above). Returns a brmsprior.
les_priors_bernoulli <- function(property = NULL) {
  c(
    # zero-centred default (incl. transfer interaction)
    brms::prior(normal(0, 1),         class = "b"),
    # Sign-informed only: the cited percentages establish that accuracy improves with
    # training, not a logit-per-standardised-session slope, so 0.3 is a modest positive
    # shift chosen under the MAGNITUDE policy above rather than a derived quantity.
    brms::prior(normal(0.3, 0.5),     class = "b", coef = "z_recoded_session"),
    # accuracy >> chance
    brms::prior(normal(1.5, 1),       class = "Intercept"),
    brms::prior(student_t(3, 0, 2.5), class = "sd"),
    brms::prior(lkj(2),               class = "cor")
  )
}

# --- WEAKLY-INFORMATIVE baselines (retained for the prior-SENSITIVITY analysis) -
# The pre-2026 defaults: normal(0,1) (ERP) / normal(0,1.5) (logit) on every slope and
# intercept. Re-running the pipeline with LES_PRIOR_SET=weak refits every model under
# these priors so the informative-vs-weak posterior shift can be reported. Both builders
# return a brmsprior and ignore their arguments, which exist only so that they share the
# informative builders' call signatures.
les_priors_gaussian_weak <- function(window = NULL, property = NULL, macroregion = NULL) {
  c(
    brms::prior(normal(0, 1),         class = "b"),
    brms::prior(normal(0, 1),         class = "Intercept"),
    brms::prior(student_t(3, 0, 2.5), class = "sd"),
    brms::prior(lkj(2),               class = "cor"),
    brms::prior(student_t(3, 0, 2.5), class = "sigma")
  )
}
les_priors_bernoulli_weak <- function(property = NULL) {
  c(
    brms::prior(normal(0, 1.5),       class = "b"),
    brms::prior(normal(0, 1.5),       class = "Intercept"),
    brms::prior(student_t(3, 0, 2.5), class = "sd"),
    brms::prior(lkj(2),               class = "cor")
  )
}

# --- Prior-set selector (informative by default; "weak" for the sensitivity run) -
# Set the env var LES_PRIOR_SET=weak to refit every model under the weakly-informative
# baseline; les_prior_tag() then suffixes the cached files so the two runs never clash.
# LES_PRIOR_SET() returns "informative" or "weak", lower-cased, so either word in any
# letter case is accepted; an unset or empty variable means "informative". Any other value
# stops the call: it used to select the informative priors silently, so a misspelt "weak"
# refitted the reported models under the reported priors. Paper code should record
# LES_PRIOR_SET(), not the raw variable, so the fit metadata and the cache tag agree.
# les_erp_prior() and les_acc_prior() take the arguments of the builders they dispatch to
# and return a brmsprior.
LES_PRIOR_SET <- function() {
  v <- tolower(trimws(Sys.getenv("LES_PRIOR_SET", unset = "")))
  if (!nzchar(v)) return("informative")
  if (!v %in% c("informative", "weak")) {
    stop("LES_PRIOR_SET='", Sys.getenv("LES_PRIOR_SET"), "' is neither 'informative' nor ",
         "'weak'.", call. = FALSE)
  }
  v
}
les_prior_tag <- function() if (LES_PRIOR_SET() == "weak") "_weakprior" else ""
les_erp_prior <- function(window = NULL, property = NULL, macroregion = NULL) {
  if (LES_PRIOR_SET() == "weak") les_priors_gaussian_weak(window, property, macroregion)
  else                           les_priors_gaussian(window, property, macroregion)
}
les_acc_prior <- function(property = NULL) {
  if (LES_PRIOR_SET() == "weak") les_priors_bernoulli_weak(property)
  else                           les_priors_bernoulli(property)
}

# -----------------------------------------------------------------------------
# 4. ONE ENTRY POINT  --  fit a brms model with all shared settings applied
# -----------------------------------------------------------------------------
# Centralising the call guarantees that every model in both papers uses the same chains,
# iterations, seed, control, backend, threading and cache policy. Each paper supplies its
# own explicit `prior` brmsprior so that LES_PRIOR_SET and the cache tag cannot disagree.
# `formula` is a brms formula, `data` a data frame and `family` a brms family. `file` is the
# cache path without extension, or NULL for no cache. `threads` is the number of threads
# per chain and is used only under cmdstanr.
# Further arguments in `...` go to brms::brm().
# Returns the brmsfit. The fit uses LES_CHAINS chains on as many cores, LES_ITER_WARMUP
# and LES_ITER_SAMPLING, LES_SEED and LES_CONTROL, adaptive reduce_sum threading under
# cmdstanr (see section 1 for what that means for reproducing the draws), and stores
# prior draws beside the posterior. With `file` set, <file>.rds is first passed through
# les_assert_readonly_data() when 03_data_manifest.R is loaded, and brms reloads it, and
# refits and overwrites it only when the generated Stan code, the Stan data (including the
# data's factor levels) or the algorithm differ from the stored fit (file_refit =
# "on_change"). brms does not compare the iterations, control settings, seed or chain
# count, so a reloaded fit is checked against them here (.les_check_cached_settings())
# and the call stops, naming the file to move aside, when it was sampled with other
# chains, seed or control settings, or with fewer warm-up or sampling iterations than the
# current ones. A longer run is accepted (see .les_iter_env() above). Without `file`,
# every call compiles and samples.
les_brm <- function(formula, data, family,
                    prior   = NULL,
                    file    = NULL,          # path WITHOUT extension; brms caches here
                    threads = .les_threads_per_chain,
                    ...) {

  if (is.null(prior)) {
    stop(
      "les_brm(): pass `prior` explicitly (les_erp_prior(), les_acc_prior() or ",
      "a paper-specific set) so LES_PRIOR_SET and the cache tag stay consistent.",
      call. = FALSE
    )
  }
  if (!is.null(file) && exists("les_assert_readonly_data")) {
    les_assert_readonly_data(paste0(file, ".rds"))
  }

  fit <- brms::brm(
    formula  = formula,
    data     = data,
    family   = family,
    prior    = prior,
    chains   = LES_CHAINS,
    cores    = LES_CHAINS,
    threads  = if (.les_backend == "cmdstanr") brms::threading(threads) else NULL,
    iter     = LES_ITER_WARMUP + LES_ITER_SAMPLING,
    warmup   = LES_ITER_WARMUP,
    seed     = LES_SEED,
    control  = LES_CONTROL,
    backend  = .les_backend,
    # Prior draws are stored alongside the posterior. Nothing in either pipeline reads
    # them at present: the reported prior predictive check refits with sample_prior =
    # "only" (02_diagnostics.R) and the prior sensitivity analysis compares this run with
    # the separate LES_PRIOR_SET=weak run. Leave the argument in place regardless, because
    # les_brm caches with file_refit = "on_change" and changing the model configuration
    # would invalidate every fit already in results/.
    sample_prior = "yes",
    file     = file,
    file_refit = "on_change",
    ...
  )
  if (!is.null(file)) .les_check_cached_settings(fit, file)
  fit
}

# The sampler settings a brmsfit was drawn with, read from the stanfit it carries (the
# first chain's stan_args, which brms fills under both backends): chains, warm-up and
# post-warm-up iterations, seed, adapt_delta and max_treedepth.
.les_fit_settings <- function(fit) {
  sa <- fit$fit@stan_args
  a  <- sa[[1]]
  list(chains = length(sa), warmup = a$warmup, sampling = a$iter - a$warmup,
       seed = a$seed, adapt_delta = a$control$adapt_delta,
       max_treedepth = a$control$max_treedepth)
}

# Stops when a fit returned for the cache stem `file` was sampled with settings other
# than the current ones (see les_brm()). A fit sampled by this call passes by
# construction, so in practice the check bites on a cache brms reused. The fourteen
# cached Paper 2 fits and a Paper 1 accuracy fit in the cluster store were read on
# 3 October 2026 and all match: 4 chains, 2000 + 8000 iterations, seed 20260607,
# adapt_delta 0.95, max_treedepth 12. When the settings cannot be read the fit is
# returned with a warning.
.les_check_cached_settings <- function(fit, file) {
  s <- tryCatch(.les_fit_settings(fit), error = function(e) NULL)
  if (is.null(s) || !length(s$chains) || is.null(s$warmup) || is.null(s$seed)) {
    warning("les_brm(): could not read the sampler settings of ", paste0(file, ".rds"),
            ", so a cached fit could not be checked against the current settings.",
            call. = FALSE)
    return(invisible(FALSE))
  }
  num <- function(x) if (is.null(x)) NA_real_ else suppressWarnings(as.numeric(x))
  bad <- c(
    if (!isTRUE(num(s$chains) == LES_CHAINS))
      sprintf("%s chains (now %d)", s$chains, LES_CHAINS),
    if (!isTRUE(num(s$warmup) >= LES_ITER_WARMUP))
      sprintf("%s warm-up iterations (now %d)", s$warmup, LES_ITER_WARMUP),
    if (!isTRUE(num(s$sampling) >= LES_ITER_SAMPLING))
      sprintf("%s sampling iterations (now %d)", s$sampling, LES_ITER_SAMPLING),
    if (!isTRUE(num(s$seed) == LES_SEED))
      sprintf("seed %s (now %d)", s$seed, LES_SEED),
    if (!isTRUE(all.equal(num(s$adapt_delta), LES_CONTROL$adapt_delta)))
      sprintf("adapt_delta %s (now %s)", format(s$adapt_delta), LES_CONTROL$adapt_delta),
    if (!isTRUE(num(s$max_treedepth) == LES_CONTROL$max_treedepth))
      sprintf("max_treedepth %s (now %d)", format(s$max_treedepth), LES_CONTROL$max_treedepth)
  )
  if (length(bad)) {
    stop("les_brm(): the cached fit ", paste0(file, ".rds"), " was sampled with ",
         paste(bad, collapse = ", "), ". brms reuses a cache whenever the Stan code and ",
         "data match, whatever the sampler settings, so move that file aside to refit ",
         "under the current settings.", call. = FALSE)
  }
  invisible(TRUE)
}

cat(sprintf("[bayes] backend = %s | chains = %d | threads/chain = %d | warm-up %d + sampling %d per chain\n",
            .les_backend, LES_CHAINS, .les_threads_per_chain, LES_ITER_WARMUP, LES_ITER_SAMPLING))
