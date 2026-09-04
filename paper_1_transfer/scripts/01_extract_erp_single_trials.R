# =============================================================================
# paper_1_transfer/scripts/01_extract_erp_single_trials.R
# Phase 2a -- Build the analysis-ready single-trial ERP datasets for Paper 1
# =============================================================================
#
# WHAT THIS SCRIPT PRODUCES
# -------------------------
# For each of the 18 analysis cells (3 properties x 3 windows x 2 macroregions;
# see _config.R) it writes one tidy `.rds` to paper_1_transfer/data_derived/.
# Each row is one retained single trial at one electrode cluster (brain_region),
# carrying:
#   * z_amplitude            : the modelled DV (mean ERP amplitude in the window,
#                              z-scored within participant; Faust et al., 1999).
#   * z_baseline_predictor   : the trial's own pre-stimulus mean amplitude, z-scored
#                              within participant -- a covariate that implements
#                              baseline correction *as regression* (Alday, 2019).
#   * the recoded / z-scored morphosyntactic and spatial predictors needed by the
#     Bayesian models in step 03.
#
# BASELINE CORRECTION AS A REGRESSION COVARIATE
# ---------------------------------------------
# Classical baseline subtraction injects the noise of the (short) baseline window
# into every sample and can bias condition differences. Including the mean
# baseline amplitude as a trial-level covariate is a less biased, higher-powered
# alternative that lets the model estimate (rather than assume) the baseline's
# influence (Alday, 2019, Psychophysiology, https://doi.org/10.1111/psyp.13451).
# We match each analysis-window observation to *its own* baseline (same
# participant x session x item x grammaticality x region) and standardise it
# within participant, consistent with the within-participant scaling of all other
# continuous predictors (Brauer & Curtin, 2018,
# https://doi.org/10.1037/met0000159).
#
# THREE DELIBERATE CORRECTIONS RELATIVE TO THE LEGACY `*_data.R` SCRIPTS
# ---------------------------------------------------------------------
# 1. CORRECT WINDOWING. The validated importer assigns its `time_window` label by
#    first-match over OVERLAPPING ranges, which silently splits the 300-600 and
#    400-900 windows into disjoint sub-windows. To obtain ONE mean amplitude per
#    trial over the exact window we instead load the un-aggregated samples and
#    average over the raw `time` column ourselves.
# 2. CORRECT AGGREGATION + DV. The importer computes `z_amplitude` per sample and
#    then keeps it inside the aggregation `group_by`, which prevents genuine
#    averaging across electrodes/samples. We therefore aggregate electrodes and
#    time-points ourselves and recompute `z_amplitude` on the trial-level means.
# 3. ANALYSIS-WINDOW ROWS ONLY. Baseline samples enter the model solely through
#    the `z_baseline_predictor` covariate; they are not left in the response
#    vector.
# All three changes are made WITHOUT editing the read-only `data/` loaders: we
# reuse `merge_trialbytrial_EEG_data()` purely for its validated importing and
# metadata joins, and post-process its output here.
#
# PAPER SEPARATION (distinctness contract)
# ----------------------------------------
# Paper 1 is about morphosyntactic transfer, NOT individual cognitive differences.
# The cognitive predictors (digit span, Stroop, ASRT) that the legacy ERP models
# carried are therefore DROPPED here so that they cannot leak into Paper 1; they
# are the exclusive domain of Paper 2.
#
# USAGE
# -----
#   Rscript 01_extract_erp_single_trials.R                  # all 18 cells
#   Rscript 01_extract_erp_single_trials.R gender_agreement lateral   # one load
# (one (property x macroregion) load yields all three window files for that pair).
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))          # anchors root + paths
  source(here::here("_shared", "R", "03_data_manifest.R"))  # logical data map
  source(here::here("paper_1_transfer", "scripts", "_config.R"))
  library(dplyr)
})

# NB: the validated, read-only EEG loader (merge_trialbytrial_EEG_data) is sourced
# lazily inside extract_paper1_property_macroregion() rather than here, so that
# merely sourcing this file (e.g. from the unit test) defines the transform
# functions WITHOUT pulling in the heavy importer and its preprocessing chain.

# --- Standardisation helpers --------------------------------------------------
# Brauer & Curtin (2018): z-score continuous predictors and the recoded
# (sum-coded) categorical predictors so that coefficients share a common scale and
# the random-effect covariance matrix is better conditioned (Schielzeth, 2010,
# https://doi.org/10.1111/j.2041-210X.2010.00012.x). For a balanced two-level
# +/-0.5 contrast this is a linear rescaling that leaves inferences unchanged.
.les_scale <- function(x) {
  if (all(is.na(x))) return(as.numeric(x))            # e.g. hemisphere on midline
  s <- stats::sd(x, na.rm = TRUE)
  if (is.na(s) || s == 0) return(rep(0, length(x)))   # constant -> no variance
  as.numeric(scale(x))
}

# =============================================================================
# Pure transform: window, baseline-match and standardise one merged load.
# -----------------------------------------------------------------------------
# Factored out of the loader below so this (error-prone) windowing / baseline /
# z-scoring logic can be unit-tested on small synthetic input WITHOUT the
# memory-heavy EEG load (see paper_1_transfer/scripts/tests/test_summarise_cells.R).
# Input `raw` is the un-aggregated merge output (one row per electrode x sample);
# output is a named list (window -> tidy per-trial-per-region data frame).
# =============================================================================
.les_summarise_cells <- function(raw, property, macroregion) {

  # Design/metadata columns that are constant within a trial x region and must be
  # carried through aggregation. (Cognitive predictors are deliberately absent.)
  trial_keys <- c(
    "participant_lab_ID", "session", "grammatical_property", "grammaticality",
    "sentence_marker", "brain_region", "macroregion", "hemisphere", "caudality",
    "recoded_grammaticality", "recoded_session",
    "recoded_hemisphere", "recoded_caudality", "recoded_brain_region",
    "mini_language", "recoded_mini_language", "multilingual_language_diversity"
  )

  # Drop the four Session-3 datasets that were offline high-pass filtered at 1 Hz
  # rather than 0.1 Hz (see LES_P1_MISFILTERED in _config.R for the rationale and the
  # literature). Applied here, before baselines and standardisation are computed, so
  # that no downstream quantity -- including the within-participant z-scoring -- is
  # derived from the mis-filtered samples.
  raw <- les_p1_drop_misfiltered(raw)

  # Pre-compute each trial's baseline (pre-stimulus mean over electrodes x samples).
  # Keyed by the full trial identity so it matches its analysis-window row 1:1.
  baseline_tbl <- raw %>%
    filter(time < 0) %>%
    group_by(participant_lab_ID, session, grammaticality, sentence_marker, brain_region) %>%
    summarise(baseline_amplitude = mean(amplitude, na.rm = TRUE), .groups = "drop")

  cells <- list()

  for (window in names(LES_P1_WINDOWS)) {
    lo <- LES_P1_WINDOWS[[window]][["min_ms"]]
    hi <- LES_P1_WINDOWS[[window]][["max_ms"]]

    # (1) One mean amplitude per trial x region: average over electrodes AND the
    #     exact [lo, hi] samples (correct window mean; corrects legacy splitting).
    cell <- raw %>%
      filter(time >= lo, time <= hi) %>%
      group_by(across(all_of(trial_keys))) %>%
      summarise(amplitude = mean(amplitude, na.rm = TRUE), .groups = "drop")

    # (2) Attach the matched baseline covariate.
    cell <- cell %>%
      left_join(baseline_tbl,
                by = c("participant_lab_ID", "session", "grammaticality",
                       "sentence_marker", "brain_region"))

    # (3) Within-participant standardisation of the DV and the baseline covariate.
    cell <- cell %>%
      group_by(participant_lab_ID) %>%
      mutate(
        z_amplitude          = .les_scale(amplitude),           # Faust et al., 1999
        z_baseline_predictor = .les_scale(baseline_amplitude)   # Alday, 2019
      ) %>%
      ungroup()

    # (4) Global standardisation of the recoded predictors and the continuous
    #     between-participant covariate (Brauer & Curtin, 2018; Schielzeth, 2010).
    #     z_recoded_hemisphere is all-NA for midline cells (no hemisphere contrast)
    #     and is simply not used by the midline models.
    cell <- cell %>%
      mutate(
        z_recoded_grammaticality = .les_scale(recoded_grammaticality),
        z_recoded_session        = .les_scale(recoded_session),
        z_recoded_mini_language  = .les_scale(recoded_mini_language),
        z_recoded_hemisphere     = .les_scale(recoded_hemisphere),
        z_recoded_caudality      = .les_scale(recoded_caudality),
        z_multilingual_language_diversity = .les_scale(multilingual_language_diversity),
        # Item identity for the by-item random effects. The sentence-marker codes
        # are condition/position-based and are reused across the two artificial
        # languages, so the same code can denote different stimuli for Mini-English
        # vs Mini-Norwegian participants. Pasting the language onto the marker makes
        # each random-effect level a single item WITHIN one language, and makes the
        # language-within-item nesting explicit (so no by-item language slope is
        # estimable).
        #
        # Grammaticality, by contrast, is CROSSED with item, not nested. An earlier
        # version of this comment claimed the opposite, on the grounds that S101 and
        # S102 occupy disjoint marker ranges. That is wrong: the marker distinguishes
        # the condition, not the sentence frame, and each frame is presented in both a
        # grammatical and an ungrammatical version. Counted directly on the extracted
        # data, all 288 items (144 sentence-marker codes x 2 languages) appear under
        # both levels, and none under only one. The maximal structure justified by the
        # design therefore includes a by-item grammaticality slope (Barr et al., 2013,
        # https://doi.org/10.1016/j.jml.2012.11.001); step 03 fits it under
        # LES_P1_ITEM_SLOPE=1, and that maximal structure is what the manuscript reports
        # as primary, the simpler structure being retained as the reported comparison.
        item_id = factor(paste0(mini_language, "_", sentence_marker)),
        # Provenance tags (handy for pooled summaries / plotting facets).
        time_window  = window,
        window_min_ms = lo,
        window_max_ms = hi
      )

    cells[[window]] <- cell
  }

  cells
}

# =============================================================================
# Core: load one (property x macroregion) pair and write its three window files
# =============================================================================
extract_paper1_property_macroregion <- function(property, macroregion) {

  stopifnot(property %in% names(LES_P1_PROPERTIES),
            macroregion %in% LES_P1_MACROREGIONS)

  # Bound the load to [200, 898] ms (covers all three windows) plus the baseline
  # (include_baseline keeps time < 0). Load samples un-aggregated so we can window
  # and aggregate correctly ourselves; the importer's own aggregation/z-scoring is
  # intentionally bypassed (see header). Memory peak equals a single-property load,
  # well within the established descriptive pipeline's footprint.
  source(data_path("R_functions", "merge_trialbytrial_EEG_data.R"))  # lazy: heavy loader
  message("[extract] loading ", property, " / ", macroregion, " ...")
  raw <- merge_trialbytrial_EEG_data(
    EEG_file_pattern      = les_p1_file_pattern(property),
    min_time              = 200,
    max_time              = 898,
    include_baseline      = TRUE,
    aggregate_electrodes  = FALSE,
    aggregate_time_points = FALSE,
    selected_macroregion  = macroregion
  )

  cells <- .les_summarise_cells(raw, property, macroregion)

  written <- character(0)
  for (window in names(cells)) {
    cell     <- cells[[window]]
    out_path <- les_p1_cell_rds(property, window, macroregion)
    les_assert_readonly_data(out_path)   # never write inside read-only data/
    saveRDS(cell, out_path)
    written <- c(written, out_path)

    # NB: the `items` field below counts sentence-marker codes. The by-item
    # random-effect level is item_id (marker x language), of which there are twice as
    # many; see the item_id note in .les_summarise_cells() above.
    message(sprintf(
      "[extract] saved %s  (rows=%d, participants=%d, items=%d)",
      basename(out_path), nrow(cell),
      dplyr::n_distinct(cell$participant_lab_ID),
      dplyr::n_distinct(cell$sentence_marker)
    ))
  }

  rm(raw, cells); gc()
  invisible(written)
}

# =============================================================================
# Entry point
# =============================================================================
.run <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  if (length(args) >= 2) {
    # Single (property x macroregion) load -- one HPC task.
    extract_paper1_property_macroregion(args[[1]], args[[2]])
  } else {
    # All six (property x macroregion) loads -> all 18 cell files.
    pairs <- unique(les_p1_erp_grid()[, c("property", "macroregion")])
    for (i in seq_len(nrow(pairs))) {
      extract_paper1_property_macroregion(pairs$property[i], pairs$macroregion[i])
    }
  }
  message("[extract] done.")
}

if (sys.nframe() == 0L) .run()
