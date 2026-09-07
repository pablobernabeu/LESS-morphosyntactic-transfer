# =============================================================================
# paper_1_transfer/scripts/03_fit_brms_erp.R
# Phase 2b -- Fit the Bayesian single-trial ERP models for Paper 1
# =============================================================================
#
# MODEL (one fit per analysis cell: property x window x macroregion)
# ------------------------------------------------------------------
# Response : z_amplitude  (within-participant z-scored mean amplitude in the window)
# Family   : Gaussian (identity link) -- ERP mean amplitudes are continuous and
#            approximately Gaussian after within-participant scaling.
#
# Fixed effects (lateral cells):
#   z_baseline_predictor
#   + z_recoded_grammaticality * z_recoded_session * z_recoded_mini_language
#   + z_recoded_grammaticality * z_recoded_hemisphere
#   + z_recoded_grammaticality * z_recoded_caudality
#   + z_multilingual_language_diversity
# Midline cells drop the hemisphere term (midline clusters have no left/right
# contrast), exactly as in the legacy lateral/midline split.
#
# WHY THIS FIXED-EFFECT STRUCTURE?
#   * z_baseline_predictor implements regression-based baseline correction
#     (Alday, 2019, https://doi.org/10.1111/psyp.13451).
#   * The grammaticality x session x language three-way interaction is the core
#     test of Paper 1: whether the neural grammaticality response (grammatical vs
#     ungrammatical) CHANGES over training (session) and whether that change
#     DIFFERS by the language of exposure (Mini-Norwegian vs Mini-English) -- the
#     signature of longitudinal morphosyntactic transfer (Rothman, 2015,
#     https://doi.org/10.1017/S136672891300059X; Gonzalez Alonso et al., 2020,
#     https://doi.org/10.1016/j.jneuroling.2020.100939).
#   * grammaticality x hemisphere / x caudality probe the scalp topography of the
#     effect (e.g., posterior P600 vs anterior negativities; Osterhout & Holcomb,
#     1992, https://doi.org/10.1016/0749-596X(92)90039-Z).
#   * z_multilingual_language_diversity is a control for prior multilingual
#     experience (the preregistration fixed the design and materials but named no
#     statistical covariates, so this is an analyst-chosen control, not a
#     preregistered one); it is NOT a cognitive individual-difference predictor
#     (those belong exclusively to Paper 2).
#
# Random effects (Barr, Levy, Scheepers & Tily, 2013, JML,
# https://doi.org/10.1016/j.jml.2012.11.001):
#   (1 + z_recoded_grammaticality + z_recoded_session | participant_lab_ID)
#   (1 + z_recoded_session | item_id)
# with `+ z_recoded_grammaticality` added to the item term under LES_P1_ITEM_SLOPE=1.
# By-participant slopes are included for the two predictors that vary WITHIN a
# participant (grammaticality and session). The item grouping `item_id`
# (= language x sentence-marker) is a single unique sentence. Language is nested
# within item, so no by-item language slope is estimable.
#
# THE BY-ITEM GRAMMATICALITY SLOPE. Grammaticality is CROSSED with item: counted on the
# extracted data, all 288 items appear under both grammaticality levels and none under
# only one (see the note in 01_extract_erp_single_trials.R). An earlier version of this
# header claimed the opposite, that S101/S102 occupy disjoint marker ranges and that
# grammaticality was therefore nested within item, and used that to justify omitting the
# by-item grammaticality slope. The script now fits either structure. Under
# LES_P1_ITEM_SLOPE=1 the item term carries the grammaticality slope; this is the
# maximal structure the design justifies, it caches under the `_itemslope` tag, and it
# is what the manuscript reports as primary. Without the variable the item term carries
# only an intercept and a session slope, and that simpler fit is retained as the
# reported comparison rather than discarded, because the slope in question is for the
# effect under test and omitting it is anticonservative rather than merely imprecise.
#
# Unlike the frequentist legacy, which used uncorrelated (||)
# slopes to obtain ML convergence (Brauer & Curtin, 2018,
# https://doi.org/10.1037/met0000159), the Bayesian models estimate CORRELATED
# random effects under an LKJ(2) prior that shrinks the correlations toward zero
# (Lewandowski, Kurowicka & Joe, 2009, https://doi.org/10.1016/j.jmva.2009.04.008),
# retaining the information that the || structure discards while remaining
# identifiable. The structure is kept parsimonious where slopes are not supported
# by the design, following Matuschek et al. (2017,
# https://doi.org/10.1016/j.jml.2017.01.001).
#
# Sampler, backend and threading settings come from _shared/R/01_bayesian_settings.R.
# Priors are INFORMATIVE (literature-derived), and sign-informed only where the
# literature fixes a sign (les_priors_gaussian()). The grammaticality main effect
# receives a NEGATIVE prior in the 400-900 ms window for every property, because the
# P600 makes the ungrammatical condition more positive and grammaticality is coded
# grammatical = +0.5, and a milder negative prior in the 300-600 ms window for the two
# agreement properties. Differential object marking is left neutral in that window, its
# late signature being ambiguous between an N400 and a P600. In the same two windows the
# grammaticality x caudality interaction receives a POSITIVE prior, which encodes the
# posterior-maximal P600. Everything else is zero-centred, above all the grammaticality
# x session x language transfer interaction, and the variance priors are generous. Run
# with LES_PRIOR_SET=weak to refit under the weakly-informative sensitivity baseline.
# See 01_bayesian_settings.R for the full justification and citations.
#
# USAGE
#   Rscript 03_fit_brms_erp.R                                    # all 18 cells
#   Rscript 03_fit_brms_erp.R gender_agreement 400_900 lateral   # one cell (HPC)
# Environment variables (all off by default):
#   LES_P1_ITEM_SLOPE=1     fit the maximal by-item structure, which is what the
#                           manuscript reports; caches under the `_itemslope` tag
#   LES_PRIOR_SET=weak      refit under the weakly-informative sensitivity baseline
#   LES_P1_RETENTION_FREE=1 add the explicit Session-6 offset; caches under `_retfree`
#   LES_P1_KEEP_MISFILTERED=1
#                           retain the four 1 Hz Session-3 datasets; caches under
#                           `_keepmisfiltered` (see _config.R)
#   LES_PRIOR_PREDICTIVE=1  write a prior predictive check before fitting
#   LES_P1_PRIORPC_REPRESENTATIVE=<cell_tag>
#                           with LES_PRIOR_PREDICTIVE=1, also copy that cell's check to
#                           figures/prior_predictive_check.png, the file the manuscript
#                           shows (see figures/README.md)
#   LES_PROVENANCE_SKIP=1   leave results/_provenance.csv untouched at the end of the
#                           run, so a sensitivity run does not overwrite the record of
#                           the reported fits
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "01_bayesian_settings.R"))
  source(here::here("_shared", "R", "02_diagnostics.R"))
  source(here::here("_shared", "R", "04_provenance.R"))
  source(here::here("paper_1_transfer", "scripts", "_config.R"))
  library(dplyr)
})

# --- By-item grammaticality slope: the maximal structure the design justifies --
# Set LES_P1_ITEM_SLOPE=1 to add `z_recoded_grammaticality` to the by-item term. The
# default is off, so an unadorned run reproduces the simpler structure exactly; the
# manuscript reports the maximal one and therefore needs the variable set. Each variant
# writes to its own cache tag, so both structures exist side by side and can be
# compared rather than one silently replacing the other.
les_p1_item_slope <- function() identical(Sys.getenv("LES_P1_ITEM_SLOPE"), "1")
les_p1_item_tag   <- function() if (les_p1_item_slope()) "_itemslope" else ""

# --- Free the retention step from the training trend --------------------------
# Session enters the default model as a single linear predictor, so the fitted
# grammaticality effect is constrained to change at one rate across every session. The
# Session 4 -> Session 6 contrast computed in step 05 is then that one slope rescaled to
# the width of the retention step (dz * b_gram:session, dz constant), which is why its
# probability of direction is numerically identical to the grammaticality x session term
# in every cell. It therefore cannot separate an offline gain specific to the unrehearsed
# interval from continued improvement at the training rate.
#
# Setting LES_P1_RETENTION_FREE=1 adds an indicator for the retention session, interacted
# with grammaticality and language. The linear term then carries the training trend and
# the indicator carries the deviation at Session 6, which is the quantity the consolidation
# claim is about. Its own cache tag keeps it beside the reported fits rather than replacing
# them, so the two can be compared.
#
# NOT APPLICABLE where a property has only two sessions: with two levels the indicator is
# collinear with the linear term (the "trend" is already the two-point difference), and the
# design matrix is rank deficient. Verb-object number agreement is sampled at Sessions 4
# and 6 only, so for that property the existing linear term already IS the retention
# change and this variant is refused rather than silently fitted.
les_p1_retention_free <- function() identical(Sys.getenv("LES_P1_RETENTION_FREE"), "1")
les_p1_retention_tag  <- function() if (les_p1_retention_free()) "_retfree" else ""

# --- Build the cell-specific model formula ------------------------------------
les_p1_erp_formula <- function(macroregion) {
  spatial <- if (macroregion == "lateral") {
    paste0("z_recoded_grammaticality * z_recoded_hemisphere",
           " + z_recoded_grammaticality * z_recoded_caudality")
  } else {
    "z_recoded_grammaticality * z_recoded_caudality"
  }
  item <- if (les_p1_item_slope()) {
    "(1 + z_recoded_grammaticality + z_recoded_session | item_id)"
  } else {
    "(1 + z_recoded_session | item_id)"
  }
  # With the retention step freed, the linear session term carries the training trend and
  # z_retention carries the Session-6 deviation from it, each crossed with grammaticality
  # and language so the retention offset can differ by language exactly as the reported
  # contrast does.
  retention <- if (les_p1_retention_free()) {
    " + z_recoded_grammaticality * z_retention * z_recoded_mini_language"
  } else {
    ""
  }
  stats::as.formula(paste0(
    "z_amplitude ~ z_baseline_predictor",
    " + z_recoded_grammaticality * z_recoded_session * z_recoded_mini_language",
    retention,
    " + ", spatial,
    " + z_multilingual_language_diversity",
    " + (1 + z_recoded_grammaticality + z_recoded_session | participant_lab_ID)",
    " + ", item
  ))
}

# Predictors that must be complete for a row to enter a given cell's model.
les_p1_erp_model_vars <- function(macroregion) {
  base <- c("z_amplitude", "z_baseline_predictor",
            "z_recoded_grammaticality", "z_recoded_session", "z_recoded_mini_language",
            "z_recoded_caudality", "z_multilingual_language_diversity",
            "participant_lab_ID", "item_id")
  if (macroregion == "lateral") base <- c(base, "z_recoded_hemisphere")
  if (les_p1_retention_free()) base <- c(base, "z_retention")
  base
}

# =============================================================================
# Fit one cell
# =============================================================================
fit_paper1_erp_cell <- function(property, window, macroregion) {

  cell_id  <- les_p1_cell_id(property, window, macroregion)
  # "" (informative) / "_weakprior" (prior sensitivity) / "_itemslope" (maximal by-item
  # structure) / "_retfree" (explicit Session-6 offset). The tags compose, so each
  # combination caches to its own file. The mis-filter-retained tag comes FIRST, because
  # the accessors that read a random-effect structure off a model id anchor on the end of
  # the string; see les_p1_misfiltered_tag() in _config.R for why it exists at all.
  cell_tag <- paste0(cell_id, les_p1_misfiltered_tag(),
                     les_prior_tag(), les_p1_item_tag(), les_p1_retention_tag())
  rds_path <- les_p1_cell_rds(property, window, macroregion)
  if (!file.exists(rds_path)) {
    stop("Missing derived data for ", cell_id, " -- run 01_extract_erp_single_trials.R first.")
  }

  message("[erp] fitting ", cell_id, " ...")
  dat <- readRDS(rds_path)

  # Retention indicator: +0.5 at the last session the property was sampled in, -0.5
  # elsewhere, on the same +/-0.5 convention as the other dichotomous predictors. It
  # departs from that convention in two respects, both harmless for the quantity it
  # carries. It is not z-standardised, so its name follows its neighbours in the formula
  # rather than describing it; and because the sessions contribute unequal numbers of
  # trials, its sample mean is not zero and it is not exactly orthogonal to the
  # intercept. The two codes remain one unit apart, so the coefficient is still the
  # deviation at the retention session. Derived from recoded_session rather than added
  # upstream, so no re-extraction is needed. Refuse the variant where it would be
  # collinear.
  if (les_p1_retention_free()) {
    n_sessions <- length(unique(dat$recoded_session))
    if (n_sessions < 3L) {
      stop("[erp] ", cell_id, ": LES_P1_RETENTION_FREE needs >= 3 sessions to separate a ",
           "retention offset from the linear trend; this cell has ", n_sessions,
           ". For a two-session property the linear term already is the retention change.")
    }
    last_session    <- max(dat$recoded_session, na.rm = TRUE)
    dat$z_retention <- as.numeric(dat$recoded_session == last_session) - 0.5
  }

  model_vars <- les_p1_erp_model_vars(macroregion)
  dat <- dat %>%
    mutate(participant_lab_ID = factor(participant_lab_ID),
           item_id            = factor(item_id)) %>%
    tidyr::drop_na(dplyr::all_of(model_vars))

  # Optional prior predictive check (set LES_PRIOR_PREDICTIVE=1): confirm the priors
  # generate plausible amplitudes BEFORE fitting. Off by default to keep the HPC run lean.
  if (Sys.getenv("LES_PRIOR_PREDICTIVE") == "1") {
    try(les_prior_predictive_check(
      formula = les_p1_erp_formula(macroregion), data = dat, family = gaussian(),
      prior   = les_erp_prior(window, property, macroregion),
      save_to = paper1_figures(paste0(cell_tag, "_priorpc.png")),
      # The response is z-scored within participant, so state the unit on the axis, and
      # clip the view: unconstrained prior draws reach far beyond the observed range and
      # would otherwise compress the data to an unreadable spike at zero.
      x_lab = "Single-trial amplitude (within-participant SD units)",
      xlim  = c(-8, 8)), silent = TRUE)
    # Opt-in: the manuscript includes figures/prior_predictive_check.png from disk, and no
    # default run writes that name. Naming the representative cell's tag in
    # LES_P1_PRIORPC_REPRESENTATIVE makes this run copy that cell's panel to it, so the
    # committed figure has a recorded source. With the variable unset nothing is copied.
    rep_tag <- Sys.getenv("LES_P1_PRIORPC_REPRESENTATIVE", unset = "")
    if (nzchar(rep_tag) && identical(cell_tag, rep_tag)) {
      src <- paper1_figures(paste0(cell_tag, "_priorpc.png"))
      dst <- paper1_figures("prior_predictive_check.png")
      if (file.exists(src)) {
        les_assert_readonly_data(dst)
        file.copy(src, dst, overwrite = TRUE)
        message("[erp] ", cell_tag, ": prior predictive check copied to ", basename(dst))
      }
    }
  }

  fit <- les_brm(
    formula = les_p1_erp_formula(macroregion),
    data    = dat,
    family  = gaussian(),
    # Informative; LES_PRIOR_SET=weak selects the sensitivity baseline.
    prior   = les_erp_prior(window, property, macroregion),
    file    = paper1_results(cell_tag)     # brms caches <cell_tag>.rds here
  )

  # --- Diagnostics & reporting artefacts --------------------------------------
  conv <- les_check_convergence(fit, label = cell_id,
                                save_to = paper1_results(paste0(cell_tag, "_convergence.rds")))
  les_posterior_summary(fit, save_to = paper1_results(paste0(cell_tag, "_summary.rds")))
  try(les_save_ppc(fit, paper1_figures(paste0(cell_tag, "_ppc.png"))), silent = TRUE)

  # Record what this fit was actually fitted to, measured on `dat` itself. The
  # manuscript uses the pooled version of these records to decide whether it may
  # state that the mis-filtered datasets were excluded, so the claim is tied to
  # the models being reported rather than to a marker file that any extraction
  # run could create (see les_p1_write_fit_meta in _config.R).
  # The recorded model id carries the mis-filtered tag, unlike the prior and structure
  # tags, which script 05 recovers from the file name. Without it a mis-filter-retained
  # record would land in _pooled_fit_metadata.csv under the reported cell's id, with the
  # same prior_variant and structure, where the manuscript's exclusion guard would read it
  # as a stale primary fit and the prior-sensitivity same-data check would see a duplicate
  # key and stop firing.
  les_p1_write_fit_meta(dat, paste0(cell_id, les_p1_misfiltered_tag()),
                        paper1_results(paste0(cell_tag, "_fitmeta.rds")))

  message(sprintf("[erp] %s | converged = %s | max Rhat = %.4f | min ESS = %.0f | divergences = %d",
                  cell_id, conv$passed, conv$max_rhat,
                  min(conv$min_ess_bulk, conv$min_ess_tail), conv$n_divergent))
  invisible(fit)
}

# =============================================================================
# Entry point
# =============================================================================
.run <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) >= 3) {
    fit_paper1_erp_cell(args[[1]], args[[2]], args[[3]])
  } else {
    grid <- les_p1_erp_grid()
    for (i in seq_len(nrow(grid))) {
      fit_paper1_erp_cell(grid$property[i], grid$window[i], grid$macroregion[i])
    }
  }
  # Record the environment that actually produced these fits, so the manuscript can
  # report versions and seeds instead of describing the environment in the abstract.
  # The file is untagged and is rewritten by every run whatever variant switches are set,
  # so a sensitivity run leaves it describing that run. LES_PROVENANCE_SKIP=1 keeps the
  # existing record in place for such runs. The decoding seed recorded here is the
  # default the decoding stage falls back on when its job exports none (see
  # LES_P1_DECODE_SEED_DEFAULT in _config.R).
  if (!identical(Sys.getenv("LES_PROVENANCE_SKIP"), "1")) {
    try(les_write_provenance(
      paper1_results(),
      seeds = list(LES_SEED = LES_SEED,
                   LES_DECODE_SEED = Sys.getenv("LES_DECODE_SEED",
                                                unset = as.character(LES_P1_DECODE_SEED_DEFAULT)))),
      silent = TRUE)
  }
  message("[erp] done.")
}

if (sys.nframe() == 0L) .run()
