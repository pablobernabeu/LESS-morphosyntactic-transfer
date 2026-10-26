# =============================================================================
# paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R
# Per-ELECTRODE grand-average ERPs, for the interpolated scalp-topography figure
# -----------------------------------------------------------------------------
# 07_extract_grand_average_waveforms.R averages electrodes WITHIN each of the nine
# brain_region clusters. That is the right resolution for the region-wise models and
# the waveform figure, but too coarse for a scalp map: a topography interpolated from
# nine cluster means would invent spatial detail the aggregation has already
# destroyed. This script keeps the electrode dimension instead, so the topography can
# be interpolated from the 30 actual sensor positions of the recording montage
# (a standard 10-20 layout: Fp1/F3/F7/FT9/FC5, Fz/FC1/FC2, Fp2/F4/F8/FT10/FC6,
# T7/C3/CP5, Cz/CP1/CP2, T8/C4/CP6, P7/P3/O1, Pz/Oz, P8/P4/O2).
#
# Everything else mirrors 07 -- the same importer (_eeg_import.R), the same full
# -100..1098 ms epoch, the same condition filter, the same within-participant baseline
# correction (-100 to -2 ms) and the same pooling over sessions -- so this changes only
# the aggregation, never data/. Amplitudes are averaged within participant before the
# group mean, and miniature language and session remain explicit. Electrodes the montage
# map leaves unassigned (the online reference FCz, the mastoid pair TP9/TP10 and the
# LiveAmp accelerometer traces) carry brain_region = NA and are dropped.
#
# The EEG exclusions of step 01 are applied before aggregation through
# les_p1_apply_eeg_exclusions().
#
# Output (one partial CSV per property x macroregion, combined at plot time):
#   store/paper_1_transfer/results/_electrode_grand_average_<property>_<macroregion>.csv
# with columns: grammatical_property, grammaticality, mini_language, session,
#               electrode, brain_region, macroregion, hemisphere, caudality, time,
#               mean_amp, sd_amp, se_amp, n_participants, n_obs.
# NOTE the `_electrode_grand_average_` prefix deliberately does NOT match the
# `^_grand_average_` glob the waveform figure uses, so the two sets never mix.
# A second, smaller output is written for each property x macroregion:
#   store/paper_1_transfer/results/_electrode_window_difference_<property>_<macroregion>.csv
# It contains participant-paired ungrammatical-minus-grammatical window amplitudes (the
# ERP convention, violation minus control) for every a priori window, language, session
# and electrode, with group SD/SE and participant n. As in 07, the session column holds
# "2", "3", "4", "6" or "pooled".
#
# USAGE
#   Rscript 07b_extract_grand_average_by_electrode.R gender_agreement lateral  # HPC array task
#   Rscript 07b_extract_grand_average_by_electrode.R                           # all six loads
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "03_data_manifest.R"))
  source(here::here("paper_1_transfer", "scripts", "_config.R"))
  library(dplyr)
})

#' Participant x session x condition x electrode waveforms, baseline-corrected
#'
#' @param raw The un-aggregated importer output, with the columns listed in `needed`
#'   below; stops naming any that are missing.
#' @return One row per participant x session x property x condition x mapped electrode x
#'   sample (Grammatical and Ungrammatical only, after les_p1_apply_eeg_exclusions()), with
#'   participant_mean_amp the mean over trials minus that waveform's pre-stimulus mean, and
#'   n_obs the raw rows averaged.
.les_electrode_participant_means <- function(raw) {
  needed <- c("participant_lab_ID", "mini_language", "session",
              "grammatical_property", "grammaticality", "electrode",
              "brain_region", "macroregion", "hemisphere", "caudality",
              "time", "amplitude")
  missing <- setdiff(needed, names(raw))
  if (length(missing)) stop("[ga-elec] missing required columns: ",
                            paste(missing, collapse = ", "))

  raw <- les_p1_apply_eeg_exclusions(raw)
  raw %>%
    filter(grammaticality %in% c("Grammatical", "Ungrammatical"),
           !is.na(brain_region), !is.na(amplitude)) %>%
    mutate(participant_lab_ID = as.character(participant_lab_ID),
           mini_language = as.character(mini_language),
           session = as.character(session)) %>%
    group_by(participant_lab_ID, mini_language, session, grammatical_property,
             grammaticality, electrode, brain_region, macroregion, hemisphere,
             caudality, time) %>%
    summarise(participant_mean_amp = mean(amplitude), n_obs = dplyr::n(),
              .groups = "drop") %>%
    # Baseline-correct each participant's condition waveform at each electrode (see 07).
    group_by(participant_lab_ID, mini_language, session, grammatical_property,
             grammaticality, electrode) %>%
    mutate(participant_mean_amp = participant_mean_amp -
             mean(participant_mean_amp[time < 0])) %>%
    ungroup()
}

#' Append the "pooled" session
#'
#' Each participant's mean over the sessions at which they contributed, per remaining key,
#' so attendance does not set a participant's weight.
#' @param d A participant-level table.
#' @param value Name of the column to average.
#' @param keys Its key columns, session included.
#' @return d with rows for session "pooled" appended (n_obs summed when present).
.les_pool_electrode_sessions <- function(d, value, keys) {
  pooled <- d %>%
    group_by(across(all_of(setdiff(keys, "session")))) %>%
    summarise(!!value := mean(.data[[value]]),
              n_obs = if ("n_obs" %in% names(d)) sum(n_obs) else NA_integer_,
              .groups = "drop") %>%
    mutate(session = "pooled")
  bind_rows(d, pooled)
}

#' Group waveforms per electrode
#'
#' @param participant_means The output of .les_electrode_participant_means().
#' @return The table written to _electrode_grand_average_<property>_<macroregion>.csv
#'   (columns in the header), with the pooled session included.
.les_group_electrode_waveforms <- function(participant_means) {
  keys <- c("participant_lab_ID", "mini_language", "session", "grammatical_property",
            "grammaticality", "electrode", "brain_region", "macroregion", "hemisphere",
            "caudality", "time")
  .les_pool_electrode_sessions(participant_means, "participant_mean_amp", keys) %>%
    group_by(mini_language, session, grammatical_property, grammaticality,
             electrode, brain_region, macroregion, hemisphere, caudality, time) %>%
    summarise(
      mean_amp = mean(participant_mean_amp),
      sd_amp = stats::sd(participant_mean_amp),
      n_participants = dplyr::n(),
      n_obs = sum(n_obs),
      .groups = "drop"
    ) %>%
    mutate(se_amp = if_else(n_participants > 1L,
                            sd_amp / sqrt(n_participants), NA_real_)) %>%
    arrange(grammatical_property, mini_language, session, grammaticality,
            macroregion, electrode, time)
}

#' Group window differences per electrode, for the topographies
#'
#' @param participant_means The output of .les_electrode_participant_means().
#' @return The table written to _electrode_window_difference_<property>_<macroregion>.csv:
#'   per a priori window (LES_P1_WINDOWS, inclusive bounds), language, session (pooled
#'   included) and electrode, the mean, SD and SE over participants of the
#'   participant-paired ungrammatical-minus-grammatical window amplitude.
.les_group_electrode_window_differences <- function(participant_means) {
  by_window <- dplyr::bind_rows(lapply(names(LES_P1_WINDOWS), function(window) {
    bounds <- LES_P1_WINDOWS[[window]]
    participant_means %>%
      filter(time >= bounds[["min_ms"]], time <= bounds[["max_ms"]]) %>%
      group_by(participant_lab_ID, mini_language, session, grammatical_property,
               grammaticality, electrode, brain_region, macroregion, hemisphere,
               caudality) %>%
      summarise(condition_mean_amp = mean(participant_mean_amp), .groups = "drop") %>%
      mutate(window = window,
             window_min_ms = unname(bounds[["min_ms"]]),
             window_max_ms = unname(bounds[["max_ms"]]))
  }))

  pair_keys <- c("participant_lab_ID", "mini_language", "session",
                 "grammatical_property", "electrode", "brain_region", "macroregion",
                 "hemisphere", "caudality", "window", "window_min_ms", "window_max_ms")
  gram <- by_window %>%
    filter(grammaticality == "Grammatical") %>%
    select(all_of(pair_keys), grammatical_amp = condition_mean_amp)
  ungram <- by_window %>%
    filter(grammaticality == "Ungrammatical") %>%
    select(all_of(pair_keys), ungrammatical_amp = condition_mean_amp)

  paired <- inner_join(gram, ungram, by = pair_keys) %>%
    mutate(participant_difference = ungrammatical_amp - grammatical_amp) %>%
    select(all_of(pair_keys), participant_difference)
  .les_pool_electrode_sessions(paired, "participant_difference", pair_keys) %>%
    group_by(mini_language, session, grammatical_property, electrode, brain_region,
             macroregion, hemisphere, caudality, window, window_min_ms, window_max_ms) %>%
    summarise(
      mean_difference = mean(participant_difference),
      sd_difference = stats::sd(participant_difference),
      n_participants = dplyr::n(),
      .groups = "drop"
    ) %>%
    mutate(se_difference = if_else(n_participants > 1L,
                                   sd_difference / sqrt(n_participants), NA_real_)) %>%
    arrange(grammatical_property, mini_language, session, window, macroregion, electrode)
}

#' Load one property x macroregion and write its two per-electrode CSVs
#'
#' @param property A property key, one of the property values in les_p1_erp_grid().
#' @param macroregion "lateral" or "midline" (LES_P1_MACROREGIONS).
#' @return The path of _electrode_grand_average_<property>_<macroregion>.csv, invisibly.
#' @details Sources _eeg_import.R and reads every export of the property over the full
#'   epoch through les_p1_merge_trialbytrial(); the EEG exclusions are applied by
#'   .les_electrode_participant_means(). Writes _electrode_grand_average_ and
#'   _electrode_window_difference_<property>_<macroregion>.csv to paper1_results(), each
#'   through les_assert_readonly_data(). Memory-heavy: run as an HPC array task.
grand_average_electrode_one <- function(property, macroregion) {
  source(here::here("paper_1_transfer", "scripts", "_eeg_import.R"))   # lazy: heavy loader (see _eeg_import.R)
  message("[ga-elec] loading ", property, " / ", macroregion, " ...")
  raw <- les_p1_merge_trialbytrial(
    EEG_file_pattern      = les_p1_file_pattern(property),
    min_time              = LES_P1_EPOCH_MS[1],   # full epoch for a continuous waveform
    max_time              = LES_P1_EPOCH_MS[2],
    include_baseline      = TRUE,
    aggregate_electrodes  = FALSE,  # keep the electrode dimension (the point of 07b)
    aggregate_time_points = FALSE,
    selected_macroregion  = macroregion
  )
  participant_means <- .les_electrode_participant_means(raw)
  ga <- .les_group_electrode_waveforms(participant_means)
  window_diff <- .les_group_electrode_window_differences(participant_means)
  out_path <- paper1_results(paste0("_electrode_grand_average_", property, "_",
                                    macroregion, ".csv"))
  diff_path <- paper1_results(paste0("_electrode_window_difference_", property, "_",
                                     macroregion, ".csv"))
  les_assert_readonly_data(out_path)
  les_assert_readonly_data(diff_path)
  utils::write.csv(ga, out_path, row.names = FALSE)
  utils::write.csv(window_diff, diff_path, row.names = FALSE)
  message(sprintf("[ga-elec] wrote %s (rows=%d, groups=%d, sessions=%d, electrodes=%d, times=%d)",
                  basename(out_path), nrow(ga),
                  dplyr::n_distinct(ga$mini_language), dplyr::n_distinct(ga$session),
                  dplyr::n_distinct(ga$electrode), dplyr::n_distinct(ga$time)))
  message(sprintf("[ga-elec] wrote %s (paired window-difference rows=%d)",
                  basename(diff_path), nrow(window_diff)))
  rm(raw); gc()
  invisible(out_path)
}

# Entry point: one property x macroregion from the command line (an array task), or all six.
.run <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  if (length(args) >= 2) {
    grand_average_electrode_one(args[[1]], args[[2]])
  } else {
    pairs <- unique(les_p1_erp_grid()[, c("property", "macroregion")])
    for (i in seq_len(nrow(pairs))) {
      grand_average_electrode_one(pairs$property[i], pairs$macroregion[i])
    }
  }
  message("[ga-elec] done.")
}

if (sys.nframe() == 0L) .run()
