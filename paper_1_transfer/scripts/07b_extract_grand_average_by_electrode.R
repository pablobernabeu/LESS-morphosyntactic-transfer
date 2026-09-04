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
# Everything else mirrors 07 -- the same validated, read-only importer, the same full
# -100..1098 ms epoch and the same condition filter -- so this changes only the
# aggregation, never data/. Electrodes the montage map leaves unassigned (the online
# reference FCz, the mastoid pair TP9/TP10 and the LiveAmp accelerometer traces) carry
# brain_region = NA and are dropped.
#
# Mirroring 07 includes its one departure from step 01: neither script calls
# les_p1_drop_misfiltered(), so the topography figure, like the waveform figure, is
# computed on the full sample rather than on the sample the models were fitted to (see
# LES_P1_MISFILTERED in _config.R and the note in 07).
#
# Output (one partial CSV per property x macroregion, combined at plot time):
#   store/paper_1_transfer/results/_electrode_grand_average_<property>_<macroregion>.csv
# with columns: grammatical_property, grammaticality, electrode, brain_region,
#               macroregion, hemisphere, caudality, time, mean_amp, n_obs.
# NOTE the `_electrode_grand_average_` prefix deliberately does NOT match the
# `^_grand_average_` glob the waveform figure uses, so the two sets never mix.
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

grand_average_electrode_one <- function(property, macroregion) {
  source(data_path("R_functions", "merge_trialbytrial_EEG_data.R"))   # lazy: heavy loader
  message("[ga-elec] loading ", property, " / ", macroregion, " ...")
  raw <- merge_trialbytrial_EEG_data(
    EEG_file_pattern      = les_p1_file_pattern(property),
    min_time              = -100,   # full epoch for a continuous waveform
    max_time              = 1098,
    include_baseline      = TRUE,
    aggregate_electrodes  = FALSE,  # keep the electrode dimension (the point of 07b)
    aggregate_time_points = FALSE,
    selected_macroregion  = macroregion
  )
  ga <- raw %>%
    filter(grammaticality %in% c("Grammatical", "Ungrammatical"),
           !is.na(brain_region)) %>%   # drop channels the montage map leaves unassigned
    group_by(grammatical_property, grammaticality, electrode, brain_region,
             macroregion, hemisphere, caudality, time) %>%
    summarise(mean_amp = mean(amplitude, na.rm = TRUE), n_obs = dplyr::n(),
              .groups = "drop")
  out_path <- paper1_results(paste0("_electrode_grand_average_", property, "_",
                                    macroregion, ".csv"))
  les_assert_readonly_data(out_path)
  utils::write.csv(ga, out_path, row.names = FALSE)
  message(sprintf("[ga-elec] wrote %s (rows=%d, electrodes=%d, times=%d)",
                  basename(out_path), nrow(ga),
                  dplyr::n_distinct(ga$electrode), dplyr::n_distinct(ga$time)))
  rm(raw); gc()
  invisible(out_path)
}

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
