# =============================================================================
# paper_1_transfer/scripts/07_extract_grand_average_waveforms.R
# Grand-average, condition-averaged, time-resolved ERPs for the manuscript figures
# -----------------------------------------------------------------------------
# The single-trial extractor (01_extract_erp_single_trials.R) collapses each trial
# to a window mean. For the grand-average waveform and scalp-distribution figures we
# instead keep the time dimension: for each grammatical property, grammaticality
# condition and electrode-cluster (brain_region) we average the raw amplitude over
# electrodes-within-cluster, trials and participants at every 2 ms sample across the
# full -100..1098 ms epoch. This reuses the validated, read-only importer exactly as
# step 01 does (no edits to data/), changing the aggregation.
#
# ONE FURTHER DIFFERENCE FROM STEP 01, worth knowing before reading the figures. Step 01
# calls les_p1_drop_misfiltered() before it aggregates, so the modelled sample excludes
# the four Session-3 datasets high-pass filtered at 1 Hz (see LES_P1_MISFILTERED in
# _config.R). This script does not, so the grand averages below are computed on the full
# sample and the waveform figure is therefore drawn from slightly more data than the
# models it accompanies. Applying the exclusion here would be a change of behaviour and
# is left to the operator.
#
# Output (one partial CSV per property x macroregion, combined at plot time):
#   store/paper_1_transfer/results/_grand_average_<property>_<macroregion>.csv
# with columns: grammatical_property, grammaticality, macroregion, brain_region,
#               hemisphere, caudality, time, mean_amp, n_obs.
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

grand_average_one <- function(property, macroregion) {
  source(legacy_eeg_loader())   # lazy: heavy loader
  message("[ga] loading ", property, " / ", macroregion, " ...")
  raw <- merge_trialbytrial_EEG_data(
    EEG_file_pattern      = les_p1_file_pattern(property),
    min_time              = LES_P1_EPOCH_MS[1],   # full epoch for a continuous waveform
    max_time              = LES_P1_EPOCH_MS[2],
    include_baseline      = TRUE,
    aggregate_electrodes  = FALSE,
    aggregate_time_points = FALSE,
    selected_macroregion  = macroregion
  )
  ga <- raw %>%
    filter(grammaticality %in% c("Grammatical", "Ungrammatical")) %>%
    group_by(grammatical_property, grammaticality, macroregion, brain_region,
             hemisphere, caudality, time) %>%
    summarise(mean_amp = mean(amplitude, na.rm = TRUE), n_obs = dplyr::n(),
              .groups = "drop")
  out_path <- paper1_results(paste0("_grand_average_", property, "_", macroregion, ".csv"))
  les_assert_readonly_data(out_path)
  utils::write.csv(ga, out_path, row.names = FALSE)
  message(sprintf("[ga] wrote %s (rows=%d, regions=%d, times=%d)",
                  basename(out_path), nrow(ga),
                  dplyr::n_distinct(ga$brain_region), dplyr::n_distinct(ga$time)))
  rm(raw); gc()
  invisible(out_path)
}

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
