# =============================================================================
# paper_1_transfer/scripts/04_fit_brms_accuracy.R
# Phase 2b -- Fit the Bayesian grammaticality-judgement ACCURACY models (Paper 1)
# =============================================================================
#
# MODEL (one fit per property: gender / DOM / verb-object number agreement)
# ------------------------------------------------------------------------
# Response : correct  (0/1 per trial)
# Family   : Bernoulli (logit link) -- the principled model for binary accuracy;
#            modelling by-subject percentages with ANOVA is avoided because it
#            mistreats the binary response and inflates Type-I error (Jaeger, 2008,
#            JML, https://doi.org/10.1016/j.jml.2007.11.007; Dixon, 2008,
#            https://doi.org/10.1016/j.jml.2007.11.004).
#
# Fixed effects:
#   z_recoded_grammaticality * z_recoded_session * z_recoded_mini_language
# READ THESE TERMS IN SIGNAL-DETECTION TERMS. With `correct` as the response and
# grammaticality among the predictors, the model is a reparameterisation of a logistic
# signal-detection model (DeCarlo, 1998, https://doi.org/10.1037/1082-989X.3.2.186).
# With grammatical coded +1 and ungrammatical -1 on the z scale (the data are balanced),
# logit P(correct) on a grammatical trial is logit(H) and on an ungrammatical trial it is
# -logit(FA), H and FA being the rates of answering "grammatical". Hence:
#   intercept, session, language, session:language
#       -> sensitivity, logit(H) - logit(FA), halved, and its change with session and
#          language (a participant who discriminates better is more accurate on both
#          sentence types);
#   grammaticality and every interaction containing it
#       -> response bias, logit(H) + logit(FA), halved: a tendency to answer
#          "grammatical" raises accuracy on grammatical trials and lowers it on
#          ungrammatical ones.
# So grammaticality:session:language is a group difference in how response bias changes
# across sessions, not in discrimination. Until 16 September 2026 the manuscript read
# the grammaticality terms as discrimination, which this mapping corrects without a refit.
# 05_posterior_summaries_and_contrasts.R derives both quantities per group and session
# from the draws (results/_accuracy_sdt_contrasts.csv).
#
# Random effects (by-participant; Barr et al., 2013,
# https://doi.org/10.1016/j.jml.2012.11.001):
#   (1 + z_recoded_grammaticality + z_recoded_session | participant_lab_ID)
# Participants vary in both their overall accuracy and in how strongly grammaticality
# and session affect them, hence the by-participant slopes.
#
# THE ITEM FACTOR. The reported fits carry no by-item term. Until 3 October 2026 this header
# justified that by saying the judgement sentences recur too rarely to form an item factor.
# The logs say otherwise. The judgement trials are the ERP trials, and every log row carries
# the trial's sentence trigger, the code the EEG records as the sentence marker. Language x
# trigger is therefore the ERP's item_id (step 01), and the trigger codes of the modelled
# trials are the same 144 per language as the ERP's. Counted on ARC over the 33,022 modelled
# trials, each property has 288 such items, every one presented in every session of its
# property and under both grammaticality levels, recurring across 23-31 participants
# (median 27) for gender agreement, 17-27 (22) for differential object marking and 10-20
# (16) for verb-object number agreement, with 13-62 trials per item. A trigger is a sentence
# frame: its lexical filling varies with the counterbalancing list and the session (6, 2-4
# and 2 distinct sentences per trigger), and no logged sentence is presented in both
# grammaticality versions, so the sentence text, which recurs across 3-17 participants, is
# nested within grammaticality and the frame is the unit that crosses it.
#
# Omitting that factor does not move its variance into a residual; a Bernoulli model has
# none. The trials of one item are treated as independent, so the interval of any term
# whose effect varies across items leaves that variation out. The language terms are the
# clearest case, because each item belongs to one language: the group contrasts in
# sensitivity (language, session x language) and in criterion (grammaticality x language
# and its session interaction) are then also contrasts between two sets of items (Baayen,
# Davidson & Bates, 2008, https://doi.org/10.1016/j.jml.2007.12.005; Barr et al., 2013).
# LES_P1_ACC_ITEM=1 adds
#   (1 + z_recoded_grammaticality + z_recoded_session | item_id)
# which is the by-item term of the ERP models' reported (maximal) structure: grammaticality
# and session vary within item, language does not. Read in signal-detection terms, the item
# intercept is item variation in sensitivity and the item grammaticality slope item
# variation in response bias. The variant caches under the `_byitem` tag, composes with
# _diversity and _maxranef, and reads the item_id that 02_extract_accuracy.R writes into
# the derived files; the reported fits are untouched.
#
# Random-effect correlations use the shared LKJ(2) prior (Lewandowski et al., 2009,
# https://doi.org/10.1016/j.jmva.2009.04.008), and the item standard deviations the shared
# half-Student-t, both of which les_acc_prior() sets for every grouping factor.
#
# Sampler, backend and threading are inherited from _shared/R/01_bayesian_settings.R.
# Priors are INFORMATIVE: intercept clearly above chance and a POSITIVE session slope,
# since grammaticality-judgement accuracy is well above chance and improves with training
# (Mueller, Oberecker & Friederici, 2009, https://doi.org/10.1186/1471-2202-10-89) and
# session is coded later = higher. The grammaticality x session x language transfer
# interaction is kept zero-centred and weakly informative. Run with LES_PRIOR_SET=weak
# for the weakly-informative sensitivity baseline. See 01_bayesian_settings.R for the
# full justification.
#
# USAGE
#   Rscript 04_fit_brms_accuracy.R                     # all three properties
#   Rscript 04_fit_brms_accuracy.R gender_agreement    # one property (HPC)
#   LES_P1_ACC_DIVERSITY=1 Rscript 04_fit_brms_accuracy.R gender_agreement
#                                                      # + diversity covariate (_diversity)
#   LES_PRIOR_PREDICTIVE=1 Rscript 04_fit_brms_accuracy.R gender_agreement
#                                                      # + prior predictive check (_priorpc.png)
#   LES_P1_ACC_MAXRANEF=1 Rscript 04_fit_brms_accuracy.R gender_agreement
#                                                      # + by-participant gram x session slope (_maxranef)
#   LES_P1_ACC_ITEM=1 Rscript 04_fit_brms_accuracy.R gender_agreement
#                                                      # + crossed by-item term (_byitem)
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "01_bayesian_settings.R"))
  source(here::here("_shared", "R", "02_diagnostics.R"))
  source(here::here("paper_1_transfer", "scripts", "_config.R"))
  library(dplyr)
})

# The accuracy model formula. With LES_P1_ACC_DIVERSITY=1 (see _config.R) the LHQ3
# Multilingual Language Diversity Score, which 02_extract_accuracy.R matches by column
# name, enters as a between-participant main effect with no interaction term. That is a
# different LHQ3 score from the ERP control in 03_fit_brms_erp.R, which holds the L1
# Dominance Score, although both carry the name z_multilingual_language_diversity, so this
# variant does not mirror the ERP covariate. It is read from the tagged derived file that
# 02_extract_accuracy.R writes under the same switch, and the fit and its artefacts carry
# the _diversity tag, so the reported fits are never touched. LES_P1_ACC_MAXRANEF=1 adds the
# by-participant grammaticality x session slope and LES_P1_ACC_ITEM=1 the crossed by-item
# term (see the header).
les_p1_accuracy_formula <- function() {
  stats::as.formula(paste0(
    "correct ~ z_recoded_grammaticality * z_recoded_session * z_recoded_mini_language",
    if (les_p1_acc_diversity()) " + z_multilingual_language_diversity" else "",
    if (les_p1_acc_maxranef())
      " + (1 + z_recoded_grammaticality * z_recoded_session | participant_lab_ID)"
    else
      " + (1 + z_recoded_grammaticality + z_recoded_session | participant_lab_ID)",
    if (les_p1_acc_item())
      " + (1 + z_recoded_grammaticality + z_recoded_session | item_id)"
    else ""
  ))
}

# --- Crossed by-item term (LES_P1_ACC_ITEM=1) ---------------------------------
# The switch and its tag live here rather than in _config.R beside the other accuracy
# switches, because _config.R is part of the decoding tensor fingerprint
# (08_extract_decoding_matrices.R) and editing it would invalidate tensors built under the
# current file. The data are the reported derived files, so no data tag is needed; step 05
# reads the tag from the file names.
les_p1_acc_item     <- function() identical(Sys.getenv("LES_P1_ACC_ITEM"), "1")
les_p1_acc_item_tag <- function() if (les_p1_acc_item()) "_byitem" else ""

# Columns that must be complete for a trial to enter the fit, with the diversity covariate
# added under LES_P1_ACC_DIVERSITY=1 and the item under LES_P1_ACC_ITEM=1.
.les_acc_model_vars <- c("correct", "z_recoded_grammaticality", "z_recoded_session",
                         "z_recoded_mini_language", "participant_lab_ID")
les_p1_acc_model_vars <- function() {
  c(.les_acc_model_vars, if (les_p1_acc_diversity()) "z_multilingual_language_diversity",
    if (les_p1_acc_item()) "item_id")
}

# --- What the fit actually ran ------------------------------------------------
# les_brm() caches with file_refit = "on_change", which compares the Stan code, the Stan data
# and the factor levels but not the seed, the iterations, the chains or the control settings,
# so a rerun can return a fit sampled under other settings than the session's. The fit-time
# record must describe the draws, not the session that reloaded them, so these fields are
# read from the brmsfit and overwrite the session-derived versions les_p1_write_fit_meta()
# records. They are added here and not in les_p1_write_fit_meta() for the fingerprint
# reason given above; 03_fit_brms_erp.R does the same. r_version and fitted_utc remain the
# session's: a brmsfit does not store the R version, and fitted_utc is when the record was
# written. `fit` is a brmsfit; returns a one-row list of the fields.
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
# Fit one property
# -----------------------------------------------------------------------------
# property is a character scalar, one of names(LES_P1_PROPERTIES). Reads the derived file
# les_p1_accuracy_rds(property) and stops when it is missing, or when LES_P1_ACC_ITEM=1 and
# the file carries no item_id. It reads LES_P1_ACC_DIVERSITY (data file, formula and the
# _diversity tag), LES_P1_ACC_RT_SCREEN (data file and the _rtscreen tag),
# LES_P1_ACC_MAXRANEF and LES_P1_ACC_ITEM (formula and the _maxranef and
# _byitem tags), LES_PRIOR_SET (priors and the _weakprior tag) and LES_PRIOR_PREDICTIVE (the
# optional prior predictive check). The fit-time record written by les_p1_write_fit_meta()
# (_config.R) also stores the values of LES_P1_EXCLUDE_REPROCESSED and LES_P1_ITEM_SLOPE,
# and les_check_convergence() reads LES_TREEDEPTH_FROM_CONTROL. With <model_tag> =
# accuracy_<property>[_diversity][_rtscreen][_maxranef][_byitem][_weakprior] it writes
# results/<model_tag>.rds (the brms cache), results/<model_tag>_convergence.rds,
# _summary.rds and _fitmeta.rds, figures/<model_tag>_ppc.png and, under
# LES_PRIOR_PREDICTIVE=1, figures/<model_tag>_priorpc.png. A figure that fails is removed
# and reported with a warning, so no earlier run's panel is left under its name. Sampling
# runs under LES_SEED through les_brm(). Returns the brmsfit, invisibly.
# =============================================================================
fit_paper1_accuracy <- function(property) {

  rds_path <- les_p1_accuracy_rds(property)      # accuracy_<property>[_diversity][_rtscreen].rds
  if (!file.exists(rds_path)) {
    sw <- c(if (les_p1_acc_diversity()) "LES_P1_ACC_DIVERSITY=1",
            if (les_p1_acc_rt_screen()) "LES_P1_ACC_RT_SCREEN=1")
    stop("Missing accuracy data for ", property, " -- run 02_extract_accuracy.R first",
         if (length(sw)) paste0(" (with ", paste(sw, collapse = " and "), ")") else "", ".")
  }

  # The data tags (les_p1_acc_data_tag(): _diversity, a different covariate and formula, and
  # _rtscreen, the trials inside the legacy reaction-time screen) are distinct model identities,
  # so they are part of model_id and reach the convergence label and the fit-time record;
  # the prior tag is a cache tag on top of it, as elsewhere.
  # The structure tags (_maxranef, _byitem) change the formula only, and likewise belong to
  # model_id.
  model_id  <- paste0("accuracy_", property, les_p1_acc_data_tag(), les_p1_acc_maxranef_tag(),
                      les_p1_acc_item_tag())
  model_tag <- paste0(model_id, les_prior_tag())   # "" (informative) or "_weakprior" (sensitivity)
  message("[acc] fitting ", model_id, " ...")

  dat <- readRDS(rds_path)
  if (les_p1_acc_item() && !"item_id" %in% names(dat)) {
    stop("[acc] LES_P1_ACC_ITEM=1 but ", basename(rds_path), " carries no item_id; rerun ",
         "02_extract_accuracy.R, which writes it from the logged sentence trigger.", call. = FALSE)
  }
  dat <- dat %>%
    mutate(participant_lab_ID = factor(participant_lab_ID)) %>%
    tidyr::drop_na(dplyr::all_of(les_p1_acc_model_vars()))
  if (les_p1_acc_item()) dat$item_id <- factor(dat$item_id)

  # Optional prior predictive check (set LES_PRIOR_PREDICTIVE=1); off by default. The old
  # panel is removed first, so a failed check cannot leave an earlier run's figure under
  # this name.
  if (Sys.getenv("LES_PRIOR_PREDICTIVE") == "1") {
    priorpc <- paper1_figures(paste0(model_tag, "_priorpc.png"))
    unlink(priorpc)
    tryCatch(les_prior_predictive_check(
      formula = les_p1_accuracy_formula(), data = dat, family = bernoulli(),
      prior   = les_acc_prior(property),
      save_to = priorpc, type = "bars",
      x_lab = "Response (0 = incorrect, 1 = correct)"),
      error = function(e) warning("[acc] ", model_tag, ": prior predictive check failed: ",
                                  conditionMessage(e), call. = FALSE))
  }

  fit <- les_brm(
    formula = les_p1_accuracy_formula(),
    data    = dat,
    family  = bernoulli(),
    # Informative; LES_PRIOR_SET=weak selects the sensitivity baseline.
    prior   = les_acc_prior(property),
    file    = paper1_results(model_tag)
  )

  conv <- les_check_convergence(fit, label = model_tag,
                                save_to = paper1_results(paste0(model_tag, "_convergence.rds")))
  les_posterior_summary(fit, save_to = paper1_results(paste0(model_tag, "_summary.rds")))
  ppc <- paper1_figures(paste0(model_tag, "_ppc.png"))
  unlink(ppc)
  tryCatch(les_save_ppc(fit, ppc, type = "bars"),
           error = function(e) warning("[acc] ", model_tag, ": posterior predictive check failed: ",
                                       conditionMessage(e), call. = FALSE))

  # Fit-time record of the analysed sample (see _config.R). exclusion_applicable is
  # FALSE here: the 1 Hz offline filter affects the EEG, not the behavioural
  # judgements, so these models keep all Session-3 data by design. The sampler settings
  # and toolchain are then taken from the fit itself (.les_p1_fit_settings() above).
  meta_path <- paper1_results(paste0(model_tag, "_fitmeta.rds"))
  les_p1_write_fit_meta(dat, model_id, meta_path, exclusion_applicable = FALSE)
  meta <- readRDS(meta_path)
  settings <- .les_p1_fit_settings(fit)
  meta[names(settings)] <- settings
  saveRDS(meta, meta_path)

  message(sprintf(
    "[acc] %s | converged = %s | max Rhat = %.4f | min ESS = %.0f | divergences = %d",
    model_id, conv$passed, conv$max_rhat,
    min(conv$min_ess_bulk, conv$min_ess_tail), conv$n_divergent))
  invisible(fit)
}

# =============================================================================
# Entry point
# =============================================================================
.run <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  props <- if (length(args) >= 1) args[1] else names(LES_P1_PROPERTIES)
  for (p in props) fit_paper1_accuracy(p)
  message("[acc] done.")
}

if (sys.nframe() == 0L) .run()
