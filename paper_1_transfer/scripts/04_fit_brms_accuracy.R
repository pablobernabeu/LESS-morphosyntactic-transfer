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
# The three-way interaction is the behavioural analogue of the ERP test. It asks whether
# the accuracy advantage for detecting (un)grammaticality grows over training, and
# whether that growth differs between the Mini-Norwegian and Mini-English groups. The
# main effect of grammaticality additionally indexes any response bias (grammatical vs
# ungrammatical) in the judgement task.
#
# Random effects (by-participant; Barr et al., 2013,
# https://doi.org/10.1016/j.jml.2012.11.001):
#   (1 + z_recoded_grammaticality + z_recoded_session | participant_lab_ID)
# Participants vary in both their overall accuracy and in how strongly grammaticality
# and session affect them, hence the by-participant slopes. There is deliberately NO
# by-item random effect: inspection of the logfiles shows the judgement sentences are
# generated combinatorially, so almost every trial is a unique string (in a
# representative session, 479 distinct sentences across 576 trials) rather than a
# member of a fixed, shared item set. That count comes from a one-off inspection of the
# OpenSesame logfiles rather than from the pipeline, which keeps no sentence column
# (see .les_acc_cols in 02_extract_accuracy.R). A by-item grouping would therefore be at (or
# near) the observation level and is not identifiable; this contrasts with the ERP
# task, which uses a fixed sentence-marker stimulus set and so retains by-item
# effects (step 03). Random-effect correlations use the shared LKJ(2) prior
# (Lewandowski et al., 2009, https://doi.org/10.1016/j.jmva.2009.04.008).
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
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "01_bayesian_settings.R"))
  source(here::here("_shared", "R", "02_diagnostics.R"))
  source(here::here("paper_1_transfer", "scripts", "_config.R"))
  library(dplyr)
})

# With LES_P1_ACC_DIVERSITY=1 (see _config.R) the LHQ3 multilingual language diversity
# score enters as a main effect, exactly as in the ERP models (03_fit_brms_erp.R): a
# between-participant control, not an interaction term. It is read from the tagged
# derived file that 02_extract_accuracy.R writes under the same switch, and the fit and
# its artefacts carry the _diversity tag, so the reported fits are never touched.
les_p1_accuracy_formula <- function() {
  stats::as.formula(paste0(
    "correct ~ z_recoded_grammaticality * z_recoded_session * z_recoded_mini_language",
    if (les_p1_acc_diversity()) " + z_multilingual_language_diversity" else "",
    " + (1 + z_recoded_grammaticality + z_recoded_session | participant_lab_ID)"
  ))
}

.les_acc_model_vars <- c("correct", "z_recoded_grammaticality", "z_recoded_session",
                         "z_recoded_mini_language", "participant_lab_ID")
les_p1_acc_model_vars <- function() {
  c(.les_acc_model_vars, if (les_p1_acc_diversity()) "z_multilingual_language_diversity")
}

# =============================================================================
# Fit one property
# =============================================================================
fit_paper1_accuracy <- function(property) {

  rds_path <- les_p1_accuracy_rds(property)      # accuracy_<property>[_diversity].rds
  if (!file.exists(rds_path)) {
    stop("Missing accuracy data for ", property, " -- run 02_extract_accuracy.R first",
         if (les_p1_acc_diversity()) " (with LES_P1_ACC_DIVERSITY=1)" else "", ".")
  }

  # The diversity tag is a distinct model identity (different data AND formula), so it
  # is part of model_id and reaches the convergence label and the fit-time record; the
  # prior tag is a cache tag on top of it, as elsewhere.
  model_id  <- paste0("accuracy_", property, les_p1_acc_diversity_tag())
  model_tag <- paste0(model_id, les_prior_tag())   # "" (informative) or "_weakprior" (sensitivity)
  message("[acc] fitting ", model_id, " ...")

  dat <- readRDS(rds_path) %>%
    mutate(participant_lab_ID = factor(participant_lab_ID)) %>%
    tidyr::drop_na(dplyr::all_of(les_p1_acc_model_vars()))

  # Optional prior predictive check (set LES_PRIOR_PREDICTIVE=1); off by default.
  if (Sys.getenv("LES_PRIOR_PREDICTIVE") == "1") {
    try(les_prior_predictive_check(
      formula = les_p1_accuracy_formula(), data = dat, family = bernoulli(),
      prior   = les_acc_prior(property),
      save_to = paper1_figures(paste0(model_tag, "_priorpc.png")), type = "bars",
      x_lab = "Response (0 = incorrect, 1 = correct)"), silent = TRUE)
  }

  fit <- les_brm(
    formula = les_p1_accuracy_formula(),
    data    = dat,
    family  = bernoulli(),
    prior   = les_acc_prior(property),     # informative; LES_PRIOR_SET=weak -> sensitivity baseline
    file    = paper1_results(model_tag)
  )

  conv <- les_check_convergence(fit, label = model_id,
                                save_to = paper1_results(paste0(model_tag, "_convergence.rds")))
  les_posterior_summary(fit, save_to = paper1_results(paste0(model_tag, "_summary.rds")))
  try(les_save_ppc(fit, paper1_figures(paste0(model_tag, "_ppc.png")), type = "bars"), silent = TRUE)

  # Fit-time record of the analysed sample (see _config.R). exclusion_applicable is
  # FALSE here: the 1 Hz offline filter affects the EEG, not the behavioural
  # judgements, so these models keep all Session-3 data by design.
  les_p1_write_fit_meta(dat, model_id, paper1_results(paste0(model_tag, "_fitmeta.rds")),
                        exclusion_applicable = FALSE)

  message(sprintf("[acc] %s | converged = %s | max Rhat = %.4f | min ESS = %.0f | divergences = %d",
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
