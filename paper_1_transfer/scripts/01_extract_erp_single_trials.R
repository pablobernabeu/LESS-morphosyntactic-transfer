# =============================================================================
# paper_1_transfer/scripts/01_extract_erp_single_trials.R
# Phase 2a -- Build the analysis-ready single-trial ERP datasets for Paper 1
# =============================================================================
#
# WHAT THIS SCRIPT PRODUCES
# -------------------------
# For each of the 18 analysis cells (3 properties x 3 windows x 2 macroregions;
# see _config.R) it writes one tidy `.rds` to paper_1_transfer/data_derived/.
# Each row is one retained single trial in one macroregion, carrying:
#   * z_amplitude            : the modelled DV (mean ERP amplitude in the window,
#                              averaged over the macroregion's clusters and z-scored
#                              within participant; Faust et al., 1999).
#   * z_baseline_predictor   : the trial's own pre-stimulus mean amplitude over the same
#                              clusters, z-scored within participant -- a covariate that
#                              implements baseline correction *as regression* (Alday, 2019).
#   * the recoded / z-scored morphosyntactic predictors needed by the Bayesian models in
#     step 03.
#
# ONE ROW PER TRIAL, NOT PER CLUSTER
# ----------------------------------
# Until 17 September 2026 each trial contributed one row per electrode cluster (six in the
# lateral macroregion, three in the midline one), and the models treated those rows as
# independent. They are not: rows of the same trial correlated at 0.45-0.64, so the rows
# pseudoreplicated the trial (Lazic, 2010, https://doi.org/10.1186/1471-2202-11-5), and the
# intervals of every trial-level term that no random slope protected, grammaticality x
# session and its interaction with language above all, were 1.4-2.0 times too narrow
# (ISSUES.md, N9; checked in lme4 on all 18 cells, in glmmTMB and in brms). Averaging the
# clusters within each trial gives one observation per trial, which reproduces the
# intervals of a model with a trial random intercept to within 0.5% at a fraction of the
# cost, and is the usual convention for single-trial ERP models in psycholinguistics
# (e.g. Nieuwland et al., 2018, https://doi.org/10.7554/eLife.33468). The clusters are
# weighted equally, so the three to five electrodes per cluster do not weight the
# macroregion mean towards the larger clusters. Hemisphere and caudality therefore leave
# the models; the scalp distribution is described by the group topographies (step 07b).
#
# BASELINE CORRECTION AS A REGRESSION COVARIATE
# ---------------------------------------------
# Classical baseline subtraction injects the noise of the (short) baseline window
# into every sample and can bias condition differences. Including the mean
# baseline amplitude as a trial-level covariate is a less biased, higher-powered
# alternative that lets the model estimate (rather than assume) the baseline's
# influence (Alday, 2019, Psychophysiology, https://doi.org/10.1111/psyp.13451).
# We match each analysis-window observation to *its own* baseline (same
# participant x session x item x grammaticality, over the same clusters) and standardise it
# within participant, consistent with the within-participant scaling of all other
# continuous predictors (Brauer & Curtin, 2018,
# https://doi.org/10.1037/met0000159).
#
# WHAT WITHIN-PARTICIPANT SCALING OF THE RESPONSE IMPLIES FOR THE BETWEEN-PARTICIPANT TERMS
# -------------------------------------------------------------------------------------
# z_amplitude has mean 0 within every participant over a cell's rows. A predictor that is
# constant within participant -- the language group and the L1-dominance covariate
# (z_multilingual_language_diversity; see 03's header) -- therefore has almost no
# between-participant variance left to explain when it enters only as a main effect. Its
# coefficient is identified only through the imbalance of trials across a participant's
# conditions and sessions, and its posterior is a near-null by construction, not evidence
# about the participants. The covariate enters no interaction, so it also adjusts none of
# the grammaticality terms the paper interprets. The language contrasts the paper reports
# are interactions with grammaticality, which within-participant scaling leaves estimable
# (ISSUES.md, G05-02). Whether the covariate should enter the grammaticality terms, or be
# dropped, is a refit decision for the author.
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
# All three changes are made after import. The import itself uses the vendored copy of
# the validated loader in _eeg_import.R, which reproduces the legacy output except for
# the Session-2 reference correction and the overlay of reprocessed files.
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

# NB: the EEG loader (les_p1_merge_trialbytrial in _eeg_import.R) is sourced
# lazily inside extract_paper1_property_macroregion() rather than here, so that
# merely sourcing this file (e.g. from the unit test) defines the transform
# functions WITHOUT pulling in the heavy importer and its preprocessing chain.

# --- Standardisation helpers --------------------------------------------------
# Brauer & Curtin (2018): z-score continuous predictors and the recoded
# (sum-coded) categorical predictors so that coefficients share a common scale and
# the random-effect covariance matrix is better conditioned (Schielzeth, 2010,
# https://doi.org/10.1111/j.2041-210X.2010.00012.x). For a balanced two-level
# +/-0.5 contrast this is a linear rescaling that leaves inferences unchanged.

#' Standardise a vector
#' @param x Numeric vector.
#' @return x z-scored over its values; an all-NA vector as numeric NAs, a constant one as
#'   zeros.
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
# output is a named list (window -> tidy data frame with one row per trial).
# =============================================================================

# Clusters per macroregion in the importer's region map; every trial must supply all of
# them, so that no trial's macroregion mean silently rests on a subset.
LES_P1_CLUSTERS_PER_MACROREGION <- c(lateral = 6L, midline = 3L)

#' Window, baseline-match and standardise one merged load
#'
#' @param raw The un-aggregated merge output for one property and macroregion (one row
#'   per electrode x trial x sample, baseline samples included), with the trial-identity
#'   and design columns listed in `trial_keys` below plus brain_region, time and amplitude.
#' @param property A property key (used in messages only).
#' @param macroregion "lateral" or "midline"; sets how many clusters each trial must have.
#' @return A named list, one element per window of LES_P1_WINDOWS, each a data frame with
#'   one row per retained trial: the design columns, n_clusters, amplitude (the equally
#'   weighted mean of the cluster window means), baseline_amplitude, the within-participant
#'   z_amplitude and z_baseline_predictor, the globally z-scored z_recoded_* and
#'   z_multilingual_language_diversity, item_id, l1_dominance_imputed and the window tags.
#' @details Applies les_p1_apply_eeg_exclusions() first, so no excluded sample enters any
#'   baseline or standardisation; imputes a missing L1-dominance score at the participant
#'   mean (with a message); stops when a trial lacks one of the macroregion's clusters.
#'   Pure: reads and writes nothing (tests/test_summarise_cells.R).
.les_summarise_cells <- function(raw, property, macroregion) {

  # Design/metadata columns that are constant within a trial and must be carried through
  # aggregation. (Cognitive predictors are deliberately absent.) eeg_source (legacy or
  # overlay, written by _eeg_import.R) is constant within a participant-session and is
  # carried so that step 03's fit-time record can tell reprocessed rows from legacy 1 Hz
  # ones; synthetic inputs without it are read as legacy throughout.
  trial_keys <- c(
    "participant_lab_ID", "session", "grammatical_property", "grammaticality",
    "sentence_marker", "macroregion",
    "recoded_grammaticality", "recoded_session",
    "mini_language", "recoded_mini_language", "multilingual_language_diversity",
    intersect("eeg_source", names(raw))
  )
  n_clusters <- LES_P1_CLUSTERS_PER_MACROREGION[[macroregion]]

  # Drop the Session-3 datasets that were offline high-pass filtered at 1 Hz rather than
  # 0.1 Hz, and the participant excluded for a protocol deviation (LES_P1_MISFILTERED and
  # LES_P1_PROTOCOL_DEVIATION in _config.R give the rationale). Applied here, before
  # baselines and standardisation are computed, so that no downstream quantity --
  # including the within-participant z-scoring -- is derived from the excluded samples.
  raw <- les_p1_apply_eeg_exclusions(raw)

  # The L1-dominance covariate (named multilingual_language_diversity; see 03's header) is a
  # participant-level score. A participant without an LHQ3 record would otherwise lose every
  # trial to listwise deletion at fit time, although the models use the score only as a
  # control. Such a participant is given the mean of the other participants' scores (one
  # value per participant, so trial counts do not weight it), which is 0 after
  # standardisation, and is flagged in l1_dominance_imputed. Participant 20 is the only case
  # (docs/eeg_filter_reprocessing_protocol.md, Amendment 5).
  scores <- unique(raw[c("participant_lab_ID", "multilingual_language_diversity")])
  missing_ids <- unique(scores$participant_lab_ID[is.na(scores$multilingual_language_diversity)])
  raw$l1_dominance_imputed <- raw$participant_lab_ID %in% missing_ids
  if (length(missing_ids)) {
    fill <- mean(scores$multilingual_language_diversity, na.rm = TRUE)
    raw$multilingual_language_diversity[raw$l1_dominance_imputed] <- fill
    message(sprintf("[extract] L1-dominance score imputed at the participant mean (%.3f) for participant(s) %s.",
                    fill, paste(sort(as.character(missing_ids)), collapse = ", ")))
  }
  trial_keys <- c(trial_keys, "l1_dominance_imputed")

  # Pre-compute each trial's baseline: the pre-stimulus mean over each cluster's electrodes
  # and samples, then the equally weighted mean of the clusters, as for the window means
  # below. Keyed by the trial identity so it matches its analysis-window row 1:1.
  baseline_tbl <- raw %>%
    filter(time < 0) %>%
    group_by(participant_lab_ID, session, grammaticality, sentence_marker, brain_region) %>%
    summarise(baseline_amplitude = mean(amplitude, na.rm = TRUE), .groups = "drop") %>%
    group_by(participant_lab_ID, session, grammaticality, sentence_marker) %>%
    summarise(baseline_amplitude = mean(baseline_amplitude), .groups = "drop")

  cells <- list()

  for (window in names(LES_P1_WINDOWS)) {
    lo <- LES_P1_WINDOWS[[window]][["min_ms"]]
    hi <- LES_P1_WINDOWS[[window]][["max_ms"]]

    # (1) One mean amplitude per trial: average over each cluster's electrodes AND the
    #     exact [lo, hi] samples (correct window mean; corrects legacy splitting), then
    #     over the macroregion's clusters with equal weight (see the header).
    cell <- raw %>%
      filter(time >= lo, time <= hi) %>%
      group_by(across(all_of(c(trial_keys, "brain_region")))) %>%
      summarise(amplitude = mean(amplitude, na.rm = TRUE), .groups = "drop") %>%
      group_by(across(all_of(trial_keys))) %>%
      summarise(n_clusters = dplyr::n(), amplitude = mean(amplitude), .groups = "drop")
    if (any(cell$n_clusters != n_clusters)) {
      stop(sprintf("[extract] %s %s %s: %d trial(s) lack some of the %d clusters.",
                   property, window, macroregion, sum(cell$n_clusters != n_clusters),
                   n_clusters), call. = FALSE)
    }

    # (2) Attach the matched baseline covariate.
    cell <- cell %>%
      left_join(baseline_tbl,
                by = c("participant_lab_ID", "session", "grammaticality", "sentence_marker"))

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
    cell <- cell %>%
      mutate(
        z_recoded_grammaticality = .les_scale(recoded_grammaticality),
        z_recoded_session        = .les_scale(recoded_session),
        z_recoded_mini_language  = .les_scale(recoded_mini_language),
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

#' Load one property x macroregion and write its three window files
#'
#' @param property A property key, one of names(LES_P1_PROPERTIES); stops otherwise.
#' @param macroregion One of LES_P1_MACROREGIONS; stops otherwise.
#' @return The three paths written, invisibly.
#' @details Sources _eeg_import.R and reads the property's Grammatical and Ungrammatical
#'   exports through les_p1_merge_trialbytrial() (overlay and Session-2 correction
#'   included), from the baseline to the end of the latest window. Writes
#'   les_p1_cell_rds(property, window, macroregion) for each window, through
#'   les_assert_readonly_data(); under LES_P1_EXCLUDE_REPROCESSED=1 those paths, and the
#'   exclusions, are the robustness analysis's. Memory-heavy: run as an HPC task.
extract_paper1_property_macroregion <- function(property, macroregion) {

  stopifnot(property %in% names(LES_P1_PROPERTIES),
            macroregion %in% LES_P1_MACROREGIONS)

  # Bound the load to the span of the three analysis windows (200 to 898 ms, read off
  # LES_P1_WINDOWS) plus the baseline (include_baseline keeps time < 0). Load samples
  # un-aggregated so we can window and aggregate correctly ourselves; the importer's own
  # aggregation/z-scoring is intentionally bypassed (see header). Memory peak equals a
  # single-property load, well within the established descriptive pipeline's footprint.
  load_min <- min(vapply(LES_P1_WINDOWS, function(w) w[["min_ms"]], numeric(1)))
  load_max <- max(vapply(LES_P1_WINDOWS, function(w) w[["max_ms"]], numeric(1)))
  # Lazy: the importer (vendored from the read-only data tree, see _eeg_import.R) brings
  # the Session-2 exports to the linked-mastoid reference and reads the overlay of
  # reprocessed files as each file is read.
  source(here::here("paper_1_transfer", "scripts", "_eeg_import.R"))
  message("[extract] loading ", property, " / ", macroregion, " ...")
  raw <- les_p1_merge_trialbytrial(
    EEG_file_pattern      = les_p1_file_pattern(property),
    min_time              = load_min,
    max_time              = load_max,
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
# With two trailing arguments (property, macroregion) extracts that pair, otherwise all six.
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
