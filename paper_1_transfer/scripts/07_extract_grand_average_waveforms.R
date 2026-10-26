# =============================================================================
# paper_1_transfer/scripts/07_extract_grand_average_waveforms.R
# Grand-average, condition-averaged, time-resolved ERPs for the manuscript figures
# -----------------------------------------------------------------------------
# The single-trial extractor (01_extract_erp_single_trials.R) collapses each trial
# to a window mean. For the grand-average waveform and difference-wave figures we
# instead keep the time dimension: for each grammatical property, grammaticality
# condition, session, miniature language and electrode cluster (brain_region), we first
# average amplitude within participant over electrodes and trials at every 2 ms sample,
# then average those participant means. This gives each participant equal weight
# instead of weighting the display by retained-trial count. The extraction reuses the
# importer exactly as step 01 does (_eeg_import.R: the vendored copy of the validated
# loader, with the Session-2 reference correction and the overlay of reprocessed files).
#
# BASELINE. Each participant's condition waveform is baseline-corrected before the group
# mean, by subtracting its own mean over the pre-stimulus samples (-100 to -2 ms). The
# single-trial models adjust for each trial's pre-stimulus amplitude through a covariate
# (step 01), so uncorrected displays would show offsets the models remove. Differential
# object marking needs this most: its two conditions differ physically before the
# critical word (the violation omits the particle), which shifts the pre-stimulus
# interval.
#
# SESSIONS. Every quantity is written per session and once more pooled over sessions
# ("pooled"). Pooling first averages each participant's baseline-corrected waveforms over
# the sessions at which they contributed that condition, then averages participants, so
# a participant who attended more sessions does not weigh more.
#
# The EEG exclusions of step 01 (les_p1_apply_eeg_exclusions() in _config.R) are applied
# before aggregation, so the displays and the models share one sample.
#
# Output (one pair of CSVs per property x macroregion, combined at plot time):
#   store/paper_1_transfer/results/_grand_average_<property>_<macroregion>.csv
#     grammatical_property, grammaticality, mini_language, session, macroregion,
#     brain_region, hemisphere, caudality, time, mean_amp, sd_amp, se_amp,
#     n_participants, n_obs
#   store/paper_1_transfer/results/_difference_wave_<property>_<macroregion>.csv
#     the participant-paired ungrammatical-minus-grammatical waveform, with the same keys
#     (without grammaticality) and mean_difference, sd_difference, se_difference,
#     n_participants. The sign follows the ERP convention (violation minus control), so a
#     P600 is positive. It is the opposite of the grammaticality coefficient's sign in
#     the models, where grammatical is coded +0.5.
# The session column holds "2", "3", "4", "6" or "pooled". The second file's prefix
# deliberately does not match the `^_grand_average_` pattern the manuscript lists.
#
# USAGE
#   Rscript 07_extract_grand_average_waveforms.R gender_agreement lateral   # one load (array task)
#   Rscript 07_extract_grand_average_waveforms.R                            # all six loads
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "03_data_manifest.R"))
  source(here::here("paper_1_transfer", "scripts", "_config.R"))
  library(dplyr)
})

.les_ga_region_keys <- c("macroregion", "brain_region", "hemisphere", "caudality")

#' Participant x session x condition x region waveforms, baseline-corrected
#'
#' Separated from the heavy loader so the weighting, baseline and exclusion behaviour can
#' be unit-tested with synthetic data (tests/test_group_descriptives.R).
#' @param raw The un-aggregated importer output (one row per electrode x trial x sample),
#'   with participant_lab_ID, mini_language, session, grammatical_property,
#'   grammaticality, macroregion, brain_region, hemisphere, caudality, time and amplitude;
#'   stops naming any that are missing.
#' @return One row per participant x session x property x condition x cluster x sample
#'   (Grammatical and Ungrammatical only, after les_p1_apply_eeg_exclusions()), with amp
#'   the mean over the cluster's electrodes and the trials, minus that waveform's mean over
#'   the pre-stimulus samples, and n_obs the raw rows averaged.
.les_participant_waveforms <- function(raw) {
  needed <- c("participant_lab_ID", "mini_language", "session",
              "grammatical_property", "grammaticality", .les_ga_region_keys,
              "time", "amplitude")
  missing <- setdiff(needed, names(raw))
  if (length(missing)) stop("[ga] missing required columns: ", paste(missing, collapse = ", "))

  raw <- les_p1_apply_eeg_exclusions(raw)
  raw %>%
    filter(grammaticality %in% c("Grammatical", "Ungrammatical"), !is.na(amplitude)) %>%
    mutate(participant_lab_ID = as.character(participant_lab_ID),
           mini_language = as.character(mini_language),
           session = as.character(session)) %>%
    group_by(participant_lab_ID, mini_language, session, grammatical_property,
             grammaticality, across(all_of(.les_ga_region_keys)), time) %>%
    summarise(amp = mean(amplitude), n_obs = dplyr::n(), .groups = "drop") %>%
    group_by(participant_lab_ID, mini_language, session, grammatical_property,
             grammaticality, across(all_of(.les_ga_region_keys))) %>%
    mutate(amp = amp - mean(amp[time < 0])) %>%
    ungroup()
}

#' Append the "pooled" session: each participant's mean over their sessions, per key
#'
#' @param pm A participant-level table.
#' @param value Name of the column to average.
#' @param keys Its key columns, session included.
#' @return pm with rows for session "pooled" appended (n_obs summed when present).
.les_pool_sessions <- function(pm, value, keys) {
  pooled <- pm %>%
    group_by(across(all_of(setdiff(keys, "session")))) %>%
    summarise(!!value := mean(.data[[value]]),
              n_obs = if ("n_obs" %in% names(pm)) sum(n_obs) else NA_integer_,
              .groups = "drop") %>%
    mutate(session = "pooled")
  bind_rows(pm, pooled)
}

#' Group waveforms: the mean of the participant waveforms per group, session and condition
#'
#' @param pm The output of .les_participant_waveforms().
#' @return The table written to _grand_average_<property>_<macroregion>.csv (columns in
#'   the header), with the pooled session included.
.les_group_waveforms <- function(pm) {
  keys <- c("participant_lab_ID", "mini_language", "session", "grammatical_property",
            "grammaticality", .les_ga_region_keys, "time")
  .les_pool_sessions(pm, "amp", keys) %>%
    group_by(mini_language, session, grammatical_property, grammaticality,
             across(all_of(.les_ga_region_keys)), time) %>%
    summarise(mean_amp = mean(amp), sd_amp = stats::sd(amp),
              n_participants = dplyr::n(), n_obs = sum(n_obs), .groups = "drop") %>%
    mutate(se_amp = if_else(n_participants > 1L, sd_amp / sqrt(n_participants), NA_real_)) %>%
    arrange(grammatical_property, mini_language, session, grammaticality,
            macroregion, brain_region, time)
}

#' Group difference waves: ungrammatical minus grammatical, paired within participant
#'
#' @param pm The output of .les_participant_waveforms().
#' @return The table written to _difference_wave_<property>_<macroregion>.csv, with the
#'   pooled session included. A participant contributes only where both conditions exist.
.les_group_difference_waves <- function(pm) {
  keys <- c("participant_lab_ID", "mini_language", "session", "grammatical_property",
            .les_ga_region_keys, "time")
  paired <- inner_join(
    pm %>% filter(grammaticality == "Grammatical") %>% select(all_of(keys), gram = amp),
    pm %>% filter(grammaticality == "Ungrammatical") %>% select(all_of(keys), ungram = amp),
    by = keys
  ) %>%
    mutate(difference = ungram - gram) %>%
    select(all_of(keys), difference)
  .les_pool_sessions(paired, "difference", keys) %>%
    group_by(mini_language, session, grammatical_property,
             across(all_of(.les_ga_region_keys)), time) %>%
    summarise(mean_difference = mean(difference), sd_difference = stats::sd(difference),
              n_participants = dplyr::n(), .groups = "drop") %>%
    mutate(se_difference = if_else(n_participants > 1L,
                                   sd_difference / sqrt(n_participants), NA_real_)) %>%
    arrange(grammatical_property, mini_language, session, macroregion, brain_region, time)
}

#' Load one property x macroregion and write its two grand-average CSVs
#'
#' @param property A property key, one of names(LES_P1_PROPERTIES).
#' @param macroregion One of LES_P1_MACROREGIONS.
#' @return The path of _grand_average_<property>_<macroregion>.csv, invisibly.
#' @details Sources _eeg_import.R and reads every export of the property over the full
#'   epoch (LES_P1_EPOCH_MS) through les_p1_merge_trialbytrial(), with the overlay and the
#'   Session-2 reference correction; the EEG exclusions are applied by
#'   .les_participant_waveforms(), so the sample is the one the models use. Writes
#'   _grand_average_ and _difference_wave_<property>_<macroregion>.csv to paper1_results(),
#'   each through les_assert_readonly_data(). Memory-heavy: run as an HPC array task.
grand_average_one <- function(property, macroregion) {
  source(here::here("paper_1_transfer", "scripts", "_eeg_import.R"))   # lazy: heavy loader (see _eeg_import.R)
  message("[ga] loading ", property, " / ", macroregion, " ...")
  raw <- les_p1_merge_trialbytrial(
    EEG_file_pattern      = les_p1_file_pattern(property),
    min_time              = LES_P1_EPOCH_MS[1],   # full epoch for a continuous waveform
    max_time              = LES_P1_EPOCH_MS[2],
    include_baseline      = TRUE,
    aggregate_electrodes  = FALSE,
    aggregate_time_points = FALSE,
    selected_macroregion  = macroregion
  )
  pm <- .les_participant_waveforms(raw)
  rm(raw); gc()
  ga <- .les_group_waveforms(pm)
  dw <- .les_group_difference_waves(pm)
  out_path  <- paper1_results(paste0("_grand_average_", property, "_", macroregion, ".csv"))
  diff_path <- paper1_results(paste0("_difference_wave_", property, "_", macroregion, ".csv"))
  les_assert_readonly_data(out_path)
  les_assert_readonly_data(diff_path)
  utils::write.csv(ga, out_path, row.names = FALSE)
  utils::write.csv(dw, diff_path, row.names = FALSE)
  message(sprintf("[ga] wrote %s (rows=%d, groups=%d, sessions=%s, regions=%d, times=%d)",
                  basename(out_path), nrow(ga), dplyr::n_distinct(ga$mini_language),
                  paste(sort(unique(ga$session)), collapse = ","),
                  dplyr::n_distinct(ga$brain_region), dplyr::n_distinct(ga$time)))
  message(sprintf("[ga] wrote %s (rows=%d)", basename(diff_path), nrow(dw)))
  invisible(out_path)
}

# Entry point: one property x macroregion from the command line (an array task), or all six.
.run <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) >= 2) {
    grand_average_one(args[[1]], args[[2]])
  } else {
    pairs <- unique(les_p1_erp_grid()[, c("property", "macroregion")])
    for (i in seq_len(nrow(pairs))) grand_average_one(pairs$property[i], pairs$macroregion[i])
  }
  message("[ga] done.")
}

if (sys.nframe() == 0L) .run()
