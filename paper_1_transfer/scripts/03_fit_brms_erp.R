# =============================================================================
# paper_1_transfer/scripts/03_fit_brms_erp.R
# Phase 2b -- Fit the Bayesian single-trial ERP models for Paper 1
# =============================================================================
#
# MODEL (one fit per analysis cell: property x window x macroregion)
# ------------------------------------------------------------------
# Response : z_amplitude  (within-participant z-scored mean amplitude in the window,
#            one value per trial: the equally weighted mean of the macroregion's clusters;
#            see 01_extract_erp_single_trials.R)
# Family   : Gaussian (identity link) -- ERP mean amplitudes are continuous and
#            approximately Gaussian after within-participant scaling.
#
# Fixed effects (lateral and midline cells alike):
#   z_baseline_predictor
#   + z_recoded_grammaticality * z_recoded_session * z_recoded_mini_language
#   + z_multilingual_language_diversity      (holds the LHQ3 L1 Dominance Score; see below)
#
# WHY THIS FIXED-EFFECT STRUCTURE?
#   * z_baseline_predictor implements regression-based baseline correction
#     (Alday, 2019, https://doi.org/10.1111/psyp.13451).
#   * Until 17 September 2026 the models took one row per trial x cluster and added
#     grammaticality x hemisphere and grammaticality x caudality terms. Those rows are not
#     independent (ISSUES.md, N9), so the models now take one row per trial, and the
#     hemisphere and caudality terms, which exist only between rows of the same trial,
#     leave with them. The scalp distribution is described by the group topographies.
#   * The grammaticality x session x language three-way interaction is the core
#     test of Paper 1: whether the neural grammaticality response (grammatical vs
#     ungrammatical) CHANGES over training (session) and whether that change
#     DIFFERS by the language of exposure (Mini-Norwegian vs Mini-English) -- the
#     signature of longitudinal morphosyntactic transfer (Rothman, 2015,
#     https://doi.org/10.1017/S136672891300059X; Gonzalez Alonso et al., 2020,
#     https://doi.org/10.1016/j.jneuroling.2020.100939).
#   * z_multilingual_language_diversity holds the LHQ3 L1 Dominance Score. The legacy
#     LHQ3 loader reads the workbook by column position, and the column it takes is the
#     L1 Dominance Score, so the variable name is a legacy label (see the manuscript
#     Method). It is a control for prior language experience (the preregistration fixed
#     the design and materials but named no statistical covariates, so this is an
#     analyst-chosen control, not a preregistered one); it is NOT a cognitive
#     individual-difference predictor (those belong exclusively to Paper 2).
#
# Random effects (Barr, Levy, Scheepers & Tily, 2013, JML,
# https://doi.org/10.1016/j.jml.2012.11.001):
#   (1 + z_recoded_grammaticality * z_recoded_session | participant_lab_ID)
#   (1 + z_recoded_session | item_id)
# with `+ z_recoded_grammaticality` added to the item term under LES_P1_ITEM_SLOPE=1.
# By-participant slopes are included for the two predictors that vary WITHIN a
# participant (grammaticality and session) and for their interaction. The interaction slope
# was added on 17 September 2026: both factors vary within participants, and a model that
# tests an interaction of within-unit factors needs a random slope for that interaction,
# because omitting it inflates the false-positive rate for the interaction and every term
# built on it, here the grammaticality x session x language test (Barr, 2013,
# https://doi.org/10.3389/fpsyg.2013.00328; Brauer & Curtin, 2018,
# https://doi.org/10.1037/met0000159). The accuracy models carry the same slope in their
# maximal refit for the same reason. The item grouping `item_id`
# (= language x sentence-marker) indexes a sentence frame, one sentence-marker code
# within one language. Across participants and sessions a frame carries several lexical
# fillings, and it is presented in both grammaticality conditions (see below). Language
# is nested within item, so no by-item language slope is estimable.
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
# late signature being ambiguous between an N400 and a P600. Everything else is
# zero-centred, above all the grammaticality
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
#   LES_P1_EXCLUDE_REPROCESSED=1
#                           the protocol's robustness analysis: drop every reprocessed or
#                           recovered participant-session; caches under `_exclreproc`
#                           (see _config.R)
#   LES_PRIOR_PREDICTIVE=1  write a prior predictive check before fitting
#   LES_P1_PRIORPC_REPRESENTATIVE=<cell_tag>
#                           with LES_PRIOR_PREDICTIVE=1, also copy that cell's check to
#                           figures/prior_predictive_check.png, the file the manuscript
#                           shows (see figures/README.md)
#   LES_PROVENANCE_SKIP=1   leave results/_provenance.csv untouched at the end of the
#                           run, so a sensitivity run does not overwrite the record of
#                           the reported fits
#   LES_ITER_WARMUP=<n>, LES_ITER_SAMPLING=<n>
#                           run one cell longer than the defaults when it misses the
#                           R-hat gate through slow mixing (_shared/R/01_bayesian_settings.R;
#                           never lower). The cached fit must be moved aside first, since
#                           brms does not refit on an iteration change. The fit metadata
#                           records the iterations used, and the Method states them.
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
# Returns the brms formula for one cell. `macroregion` is "lateral" or "midline". The item
# and retention terms follow LES_P1_ITEM_SLOPE and LES_P1_RETENTION_FREE.
les_p1_erp_formula <- function(macroregion) {
  stopifnot(macroregion %in% LES_P1_MACROREGIONS)
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
    " + z_multilingual_language_diversity",
    " + (1 + z_recoded_grammaticality * z_recoded_session | participant_lab_ID)",
    " + ", item
  ))
}

# Predictors that must be complete for a row to enter a given cell's model.
# `macroregion` is "lateral" or "midline" and no longer changes the set, since both
# macroregions are now modelled on one row per trial. Returns the column names as a
# character vector, with z_retention added under LES_P1_RETENTION_FREE=1.
les_p1_erp_model_vars <- function(macroregion) {
  base <- c("z_amplitude", "z_baseline_predictor",
            "z_recoded_grammaticality", "z_recoded_session", "z_recoded_mini_language",
            "z_multilingual_language_diversity",
            "participant_lab_ID", "item_id")
  if (les_p1_retention_free()) base <- c(base, "z_retention")
  base
}

# =============================================================================
# Fit one cell
# -----------------------------------------------------------------------------
# property, window and macroregion are character scalars naming one row of
# les_p1_erp_grid(). Reads the derived cell file les_p1_cell_rds() gives and stops when it
# is missing. Every switch listed under USAGE in the header except LES_PROVENANCE_SKIP,
# which .run() reads, is read here. LES_P1_EXCLUDE_REPROCESSED, LES_PRIOR_SET,
# LES_P1_ITEM_SLOPE and LES_P1_RETENTION_FREE each add a tag to <cell_tag> (see the
# comment below), and <cell_tag> names every file written: results/<cell_tag>.rds (the
# brms cache), results/<cell_tag>_convergence.rds, _summary.rds and _fitmeta.rds, and
# figures/<cell_tag>_ppc.png. Under LES_PRIOR_PREDICTIVE=1 it also writes
# figures/<cell_tag>_priorpc.png, and copies it to figures/prior_predictive_check.png when
# LES_P1_PRIORPC_REPRESENTATIVE names this cell. A figure that fails is removed and reported
# with a warning; when it is the representative cell's prior check, the function stops once
# the fit's other artefacts are written. Sampling runs under LES_SEED through les_brm().
# Returns the brmsfit, invisibly.
# =============================================================================
fit_paper1_erp_cell <- function(property, window, macroregion) {

  cell_id  <- les_p1_cell_id(property, window, macroregion)
  # "" (informative) / "_weakprior" (prior sensitivity) / "_itemslope" (maximal by-item
  # structure) / "_retfree" (explicit Session-6 offset). The tags compose, so each
  # combination caches to its own file. The robustness tag ("_exclreproc") comes FIRST,
  # because the accessors that read a random-effect structure off a model id anchor on the
  # end of the string; see les_p1_exclreproc_tag() in _config.R for why it exists at all.
  cell_tag <- paste0(cell_id, les_p1_exclreproc_tag(),
                     les_prior_tag(), les_p1_item_tag(), les_p1_retention_tag())
  rds_path <- les_p1_cell_rds(property, window, macroregion)
  if (!file.exists(rds_path)) {
    stop("Missing derived data for ", cell_id, " -- run 01_extract_erp_single_trials.R first.")
  }

  message("[erp] fitting ", cell_id, " ...")
  dat <- readRDS(rds_path)
  # Refuse derived files of the superseded cluster-row extraction: fitting the trial-level
  # formula to them would bring back the pseudoreplication the change removed, silently.
  trial_key <- c("participant_lab_ID", "session", "grammaticality", "sentence_marker")
  # eeg_source is required too, because the fit-time record below counts legacy 1 Hz rows by
  # it; without the column every reprocessed row would be recorded as a legacy one.
  if (!all(c("n_clusters", "eeg_source") %in% names(dat)) || "brain_region" %in% names(dat) ||
      anyDuplicated(dat[trial_key])) {
    stop("[erp] ", cell_id, ": ", rds_path, " is not one row per trial (a pre-17-September ",
         "cluster-row extraction?); rerun 01_extract_erp_single_trials.R",
         if (nzchar(les_p1_exclreproc_tag())) " with LES_P1_EXCLUDE_REPROCESSED=1" else "",
         ".", call. = FALSE)
  }

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
  # The robustness analysis must hold no row of a reprocessed or recovered record; a derived
  # file extracted without the switch would otherwise be fitted and recorded under its tag.
  if (les_p1_exclude_reprocessed() && isTRUE(les_p1_reprocessed_rows(dat) > 0L)) {
    stop("[erp] ", cell_id, ": LES_P1_EXCLUDE_REPROCESSED=1 but the data hold ",
         les_p1_reprocessed_rows(dat), " reprocessed rows; rerun 01 under the switch.",
         call. = FALSE)
  }

  # Optional prior predictive check (set LES_PRIOR_PREDICTIVE=1): confirm the priors
  # generate plausible amplitudes BEFORE fitting. Off by default to keep the HPC run lean.
  # The cell's old panel is removed first, so a failed check cannot leave an earlier run's
  # figure under this name, and the failure is reported as a warning in the .Rout.
  priorpc_failed <- NULL
  if (Sys.getenv("LES_PRIOR_PREDICTIVE") == "1") {
    src <- paper1_figures(paste0(cell_tag, "_priorpc.png"))
    unlink(src)
    tryCatch(les_prior_predictive_check(
      formula = les_p1_erp_formula(macroregion), data = dat, family = gaussian(),
      prior   = les_erp_prior(window, property, macroregion),
      save_to = src,
      # The response is z-scored within participant, so state the unit on the axis, and
      # clip the view: unconstrained prior draws reach far beyond the observed range and
      # would otherwise compress the data to an unreadable spike at zero.
      x_lab = "Single-trial amplitude (within-participant SD units)",
      xlim  = c(-8, 8)),
      error = function(e) warning("[erp] ", cell_tag, ": prior predictive check failed: ",
                                  conditionMessage(e), call. = FALSE))
    # Opt-in: the manuscript includes figures/prior_predictive_check.png from disk, and no
    # default run writes that name. Naming the representative cell's tag in
    # LES_P1_PRIORPC_REPRESENTATIVE makes this run copy that cell's panel to it, so the
    # committed figure has a recorded source. With the variable unset nothing is copied.
    # When this IS the representative cell and its panel was not written, the job fails once
    # the fit and its artefacts are written (end of this function): the manuscript would
    # otherwise go on showing a panel from an earlier run.
    rep_tag <- Sys.getenv("LES_P1_PRIORPC_REPRESENTATIVE", unset = "")
    if (nzchar(rep_tag) && identical(cell_tag, rep_tag)) {
      dst <- paper1_figures("prior_predictive_check.png")
      if (file.exists(src)) {
        les_assert_readonly_data(dst)
        file.copy(src, dst, overwrite = TRUE)
        message("[erp] ", cell_tag, ": prior predictive check copied to ", basename(dst))
      } else {
        priorpc_failed <- basename(dst)
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
  conv <- les_check_convergence(fit, label = cell_tag,
                                save_to = paper1_results(paste0(cell_tag, "_convergence.rds")))
  les_posterior_summary(fit, save_to = paper1_results(paste0(cell_tag, "_summary.rds")))
  # As for the prior check: remove the old panel, and warn rather than stay silent on failure.
  ppc <- paper1_figures(paste0(cell_tag, "_ppc.png"))
  unlink(ppc)
  tryCatch(les_save_ppc(fit, ppc),
           error = function(e) warning("[erp] ", cell_tag, ": posterior predictive check failed: ",
                                       conditionMessage(e), call. = FALSE))

  # Record what this fit was actually fitted to, measured on `dat` itself. The
  # manuscript uses the pooled version of these records to decide whether it may
  # state that the mis-filtered datasets were excluded, so the claim is tied to
  # the models being reported rather than to a marker file that any extraction
  # run could create (see les_p1_write_fit_meta in _config.R).
  # The recorded model id carries the robustness tag, unlike the prior and structure tags,
  # which script 05 recovers from the file name. Without it a robustness record would land
  # in _pooled_fit_metadata.csv under the primary cell's id, with the same prior_variant and
  # structure, where the manuscript's exclusion guard would read it as a primary fit and the
  # prior-sensitivity same-data check would see a duplicate key and stop firing. The model
  # version lets script 05 refuse fits of a superseded specification.
  les_p1_write_fit_meta(dat, paste0(cell_id, les_p1_exclreproc_tag()),
                        paper1_results(paste0(cell_tag, "_fitmeta.rds")),
                        erp_model_version = LES_P1_ERP_MODEL_VERSION)
  # Sampler settings and toolchain as the fit actually ran them, read from the fitted object
  # (.les_p1_fit_settings() below), so a cell run longer than the defaults
  # (LES_ITER_WARMUP / LES_ITER_SAMPLING) is visible per fit and the Method can state it, and
  # a cached fit reloaded by a later session is not stamped with that session's seed and
  # versions. Added here and not in les_p1_write_fit_meta() because _config.R is part of the
  # decoding tensor fingerprint (08_extract_decoding_matrices.R), so editing it would
  # invalidate tensors built under the current file. Records without iter_warmup and
  # iter_sampling predate them and ran the defaults, since no override existed before; records
  # without seed and chains predate 3 October 2026.
  .meta_path <- paper1_results(paste0(cell_tag, "_fitmeta.rds"))
  .meta <- readRDS(.meta_path)
  .settings <- .les_p1_fit_settings(fit)
  .meta[names(.settings)] <- .settings
  saveRDS(.meta, .meta_path)

  message(sprintf("[erp] %s | converged = %s | max Rhat = %.4f | min ESS = %.0f | divergences = %d",
                  cell_id, conv$passed, conv$max_rhat,
                  min(conv$min_ess_bulk, conv$min_ess_tail), conv$n_divergent))
  if (!is.null(priorpc_failed)) {
    stop("[erp] ", cell_tag, " is LES_P1_PRIORPC_REPRESENTATIVE but its prior predictive ",
         "check was not written (see the warning above), so ", priorpc_failed,
         " was left unchanged.", call. = FALSE)
  }
  invisible(fit)
}

# --- What the fit actually ran ------------------------------------------------
# les_brm() caches with file_refit = "on_change", which compares the Stan code, the Stan data
# and the factor levels but not the seed, the iterations, the chains or the control settings,
# so a rerun can return a fit sampled under other settings than the session's. These fields
# are read from the brmsfit and overwrite the session-derived versions that
# les_p1_write_fit_meta() records. r_version and fitted_utc remain the session's: a brmsfit
# does not store the R version, and fitted_utc is when the record was written. The same
# helper is defined in 04_fit_brms_accuracy.R. `fit` is a brmsfit; returns a list of the
# fields, one value each.
.les_p1_fit_settings <- function(fit) {
  sa <- fit$fit@stan_args[[1]]
  .chr <- function(x) if (is.null(x) || !length(x)) NA_character_ else as.character(x)
  .num <- function(x) if (is.null(x) || !length(x)) NA_real_ else as.numeric(x)
  started <- suppressWarnings(as.POSIXct(.chr(sa$start_datetime), format = "%Y-%m-%d%H:%M:%S",
                                         tz = "UTC"))
  list(
    chains           = length(fit$fit@stan_args),
    iter_warmup      = as.integer(fit$fit@sim$warmup),
    iter_sampling    = as.integer(fit$fit@sim$iter - fit$fit@sim$warmup),
    seed             = .chr(sa$seed),
    adapt_delta      = .num(sa$control$adapt_delta),
    max_treedepth    = .num(sa$control$max_treedepth),
    brms_version     = .chr(fit$version$brms),
    cmdstanr_version = .chr(fit$version$cmdstanr),
    cmdstan_version  = .chr(fit$version$cmdstan),
    sampling_started_utc = if (is.na(started)) NA_character_
                           else format(started, tz = "UTC", usetz = TRUE),
    formula          = paste(deparse(fit$formula$formula, width.cutoff = 500L), collapse = " ")
  )
}

# =============================================================================
# Entry point
# -----------------------------------------------------------------------------
# Fits the one cell named by three arguments, or all 18 cells without them, then rewrites
# results/_provenance.csv unless LES_PROVENANCE_SKIP=1. Any other number of arguments, or a
# name outside the grid, stops with the usage line rather than silently fitting the grid.
# =============================================================================
.run <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  usage <- "Usage: Rscript 03_fit_brms_erp.R [property window macroregion]"
  if (!length(args) %in% c(0L, 3L)) stop(usage, call. = FALSE)
  if (length(args) == 3L) {
    grid <- les_p1_erp_grid()
    if (!any(grid$property == args[[1]] & grid$window == args[[2]] &
             grid$macroregion == args[[3]])) {
      stop("No such cell: ", paste(args, collapse = " "), ". ", usage, call. = FALSE)
    }
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
  # LES_P1_DECODE_SEED_DEFAULT in _config.R). A failed write fails the job: the fits are
  # cached, so the rerun is cheap, whereas a silent failure would leave an earlier run's
  # record standing beside these fits.
  if (!identical(Sys.getenv("LES_PROVENANCE_SKIP"), "1")) {
    les_write_provenance(
      paper1_results(),
      seeds = list(LES_SEED = LES_SEED,
                   LES_DECODE_SEED = Sys.getenv("LES_DECODE_SEED",
                                                unset = as.character(LES_P1_DECODE_SEED_DEFAULT))))
  }
  message("[erp] done.")
}

if (sys.nframe() == 0L) .run()
