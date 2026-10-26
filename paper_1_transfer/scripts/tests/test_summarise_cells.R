# =============================================================================
# paper_1_transfer/scripts/tests/test_summarise_cells.R
# -----------------------------------------------------------------------------
# Unit test for the pure post-merge transform .les_summarise_cells() in
# 01_extract_erp_single_trials.R. It builds a SMALL synthetic version of the
# un-aggregated merge output (with known amplitudes) and checks the windowing, the
# equal-weight averaging of clusters into one row per trial, baseline matching,
# within-participant z-scoring of the DV and the baseline covariate, the drop of a
# mis-filtered dataset before that z-scoring and before the global scaling of the
# predictors, and item_id construction -- i.e. the
# error-prone parts of the transform -- WITHOUT the memory-heavy EEG load.
#
# Run:  Rscript --vanilla paper_1_transfer/scripts/tests/test_summarise_cells.R
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  # Sourcing the extractor defines .les_scale and .les_summarise_cells without loading
  # EEG data or running the extraction (the loader is sourced lazily and .run() is
  # guarded by sys.nframe()). It does anchor the working directory at the project root
  # (_shared/R/00_paths.R) and print the path, manifest and config banners.
  source(here::here("paper_1_transfer", "scripts", "01_extract_erp_single_trials.R"))
})

ok <- function(cond, msg) {
  if (!isTRUE(cond)) stop("FAIL: ", msg, call. = FALSE)
  cat("PASS:", msg, "\n")
}
near <- function(a, b, tol = 1e-8) all(abs(a - b) < tol)

# --- Build a synthetic un-aggregated merge output ----------------------------
# amplitude = time/100 + grammaticality_effect + electrode_offset + cluster_offset.
# The electrode offsets (+/-0.1) cancel within a cluster, and the cluster offsets
# (+0.3, 0, -0.3) cancel across the three midline clusters, but only under EQUAL cluster
# weighting: the anterior cluster has three electrodes here and the other two have two,
# so an electrode-weighted mean would not cancel them. A grammaticality effect (+0.5 for
# ungrammatical) gives genuine within-participant variance to z-score.
#
# Participant 2's amplitudes, baseline samples included, are rescaled to
# 2 * amplitude + 5. The participants therefore differ in location and scale, which a
# global z-score would leave visible in each participant's mean and SD.
#
# Participant 9 contributes Session 2 and Session 3. Its Session-3 recording is one of
# the mis-filtered datasets in LES_P1_MISFILTERED (_config.R), and its Session-3 samples
# are shifted by +10, so any of them that reached the within-participant z-scoring would
# move participant 9's Session-2 z-values.
electrodes <- data.frame(
  electrode    = c("a1", "a2", "a3", "m1", "m2", "p1", "p2"),
  brain_region = c(rep("midline anterior", 3), rep("midline medial", 2),
                   rep("midline posterior", 2)),
  elec_offset  = c(0.1, -0.1, 0, 0.1, -0.1, 0.1, -0.1),
  clus_offset  = c(rep(0.3, 3), rep(0, 2), rep(-0.3, 2)),
  stringsAsFactors = FALSE
)
grid <- expand.grid(
  participant_lab_ID = c(1L, 2L, 9L),
  grammaticality     = c("Grammatical", "Ungrammatical"),
  sentence_marker    = c("m1", "m2"),
  electrode          = electrodes$electrode,
  time               = c(-100, -50, 200, 300, 400, 500, 600, 700, 898),
  stringsAsFactors   = FALSE
)
grid$session <- 2L
grid <- bind_rows(grid, grid %>% filter(participant_lab_ID == 9L) %>% mutate(session = 3L))

raw <- grid %>%
  left_join(electrodes, by = "electrode") %>%
  mutate(
    grammatical_property   = "gender_agreement",
    macroregion            = "midline",
    recoded_grammaticality = ifelse(grammaticality == "Grammatical", 0.5, -0.5),
    recoded_session        = ifelse(session == 2L, 0, 1),
    mini_language          = ifelse(participant_lab_ID == 1L, "Mini-English", "Mini-Norwegian"),
    recoded_mini_language  = ifelse(mini_language == "Mini-English", -0.5, 0.5),
    multilingual_language_diversity = ifelse(participant_lab_ID == 1L, 1.0, 2.0),
    gram_effect = ifelse(grammaticality == "Ungrammatical", 0.5, 0.0),
    amplitude   = time / 100 + gram_effect + elec_offset + clus_offset,
    amplitude   = case_when(participant_lab_ID == 2L ~ 2 * amplitude + 5,
                            session == 3L            ~ amplitude + 10,
                            TRUE                     ~ amplitude)
  ) %>%
  select(-gram_effect, -elec_offset, -clus_offset)

# The mis-filter checks in section 5 need the default behaviour, so a shell prepared for
# the robustness refit must not carry LES_P1_EXCLUDE_REPROCESSED=1 into this run.
Sys.unsetenv("LES_P1_EXCLUDE_REPROCESSED")

cells <- .les_summarise_cells(raw, "gender_agreement", "midline")

# --- 1. Structure ------------------------------------------------------------
ok(identical(names(cells), c("200_500", "300_600", "400_900")),
   "returns the three named windows")

# One row per participant x session x grammaticality x sentence_marker that survives the
# mis-filter drop, i.e. three participants at Session 2 (12); electrodes, clusters and
# time-points are collapsed.
ok(all(vapply(cells, nrow, integer(1)) == 12L),
   "each window collapses electrodes, clusters and time to 12 trial rows")
ok(all(cells[["200_500"]]$n_clusters == 3L),
   "every trial row averages the three midline clusters")
ok(!any(c("brain_region", "hemisphere", "caudality", "z_recoded_hemisphere",
          "z_recoded_caudality") %in% names(cells[["200_500"]])),
   "no cluster-level columns remain")

# --- 2. Correct windowing and equal cluster weighting --------------------------
# For Grammatical/m1/P1, the window mean amplitude must equal mean(time/100) over the
# EXACT window samples, because the electrode and cluster offsets cancel only when the
# clusters are weighted equally.
get_amp <- function(w, gram) {
  cells[[w]] %>%
    filter(participant_lab_ID == 1L, grammaticality == gram, sentence_marker == "m1") %>%
    pull(amplitude)
}
ok(near(get_amp("200_500", "Grammatical"), mean(c(200, 300, 400) / 100)),   # 3.0
   "200_500 window mean uses only samples in [200,498], clusters weighted equally")
ok(near(get_amp("300_600", "Grammatical"), mean(c(300, 400, 500) / 100)),   # 4.0
   "300_600 window mean uses only samples in [300,598]")
ok(near(get_amp("400_900", "Grammatical"), mean(c(400, 500, 600, 700, 898) / 100)), # 6.196
   "400_900 window mean uses only samples in [400,898]")
ok(!near(get_amp("200_500", "Grammatical"), get_amp("300_600", "Grammatical")),
   "overlapping windows yield DIFFERENT means (no first-match splitting)")
ok(near(get_amp("200_500", "Ungrammatical") - get_amp("200_500", "Grammatical"), 0.5),
   "grammaticality effect (+0.5) preserved after averaging")

# --- 3. Baseline covariate matched 1:1 ---------------------------------------
# Baseline = mean over time<0 samples = mean(-1, -0.5) + gram_effect, again only under
# equal cluster weighting.
bl <- cells[["200_500"]] %>%
  filter(participant_lab_ID == 1L, sentence_marker == "m1") %>%
  arrange(grammaticality)
ok(near(bl$baseline_amplitude[bl$grammaticality == "Grammatical"], -0.75) &&
   near(bl$baseline_amplitude[bl$grammaticality == "Ungrammatical"], -0.25),
   "baseline_amplitude is the matched pre-stimulus mean per trial")

# --- 4. Within-participant z-scoring of the DV and the baseline covariate ----
# Participants 1 and 2 differ in location and scale (see the synthetic data), so mean 0
# and SD 1 within every participant hold only under within-participant scaling.
zc <- cells[["200_500"]]
by_pid <- zc %>%
  group_by(participant_lab_ID) %>%
  summarise(m_amp = mean(z_amplitude),          sd_amp = stats::sd(z_amplitude),
            m_bl  = mean(z_baseline_predictor), sd_bl  = stats::sd(z_baseline_predictor),
            .groups = "drop")
ok(near(by_pid$m_amp, 0) && near(by_pid$sd_amp, 1),
   "z_amplitude has mean 0 and SD 1 within each participant")
ok(near(by_pid$m_bl, 0) && near(by_pid$sd_bl, 1),
   "z_baseline_predictor has mean 0 and SD 1 within each participant")
ok(!near(zc$z_amplitude, as.numeric(scale(zc$amplitude))),
   "z_amplitude differs from a global z-score over all participants")
ok(stats::sd(zc$z_amplitude) > 0,
   "z_amplitude is genuinely scaled (non-constant), not collapsed to 0")

# --- 5. The mis-filtered dataset is dropped before standardisation -----------
ok(all(vapply(cells, function(d) !any(d$participant_lab_ID == 9L & d$session == 3L),
              logical(1))),
   "no row of participant 9's mis-filtered Session 3 survives in any window")
# Had the Session-3 rows been dropped only after the z-scoring, participant 9's Session-2
# z-values would be computed together with the shifted Session-3 values. Recomputing them
# from the Session-2 rows alone must reproduce the output.
p9 <- zc[zc$participant_lab_ID == 9L, , drop = FALSE]
ok(nrow(p9) == 4L &&
     near(p9$z_amplitude, as.numeric(scale(p9$amplitude))) &&
     near(p9$z_baseline_predictor, as.numeric(scale(p9$baseline_amplitude))),
   "participant 9's z-values are computed from its Session-2 rows alone")
# The globally scaled predictors must also be computed without the dropped rows. The
# Session-3 rows add four Mini-Norwegian trials of participant 9 and its diversity score,
# so scaling before the drop would shift both of these away from a z-score of the
# surviving rows.
ok(near(zc$z_recoded_mini_language, as.numeric(scale(zc$recoded_mini_language))) &&
     near(zc$z_multilingual_language_diversity,
          as.numeric(scale(zc$multilingual_language_diversity))),
   "the globally scaled predictors are z-scores of the surviving rows only")

# --- 6. item_id, recoded predictors, provenance tags -------------------------
ok(all(as.character(zc$item_id) == paste0(zc$mini_language, "_", zc$sentence_marker)),
   "item_id = <mini_language>_<sentence_marker>")
ok(dplyr::n_distinct(zc$z_recoded_grammaticality) == 2,
   "z_recoded_grammaticality retains its two contrast levels")
ok(all(zc$time_window == "200_500" & zc$window_min_ms == 200 & zc$window_max_ms == 498),
   "provenance tags (time_window/min/max) are correct")

# --- 7. A trial missing a cluster stops the extraction -------------------------
short <- raw %>% filter(!(participant_lab_ID == 1L & sentence_marker == "m1" &
                          grammaticality == "Grammatical" & brain_region == "midline medial" &
                          time >= 200))
ok(inherits(tryCatch(suppressMessages(.les_summarise_cells(short, "gender_agreement", "midline")),
                     error = function(e) e), "error"),
   "a trial whose window samples lack a cluster stops the extraction")

# --- 8. The row source is carried through, and reprocessed rows are kept ------------
# Participant 9's Session 3 read from the reprocessed overlay is primary data: it must
# survive the exclusion, keep its eeg_source, and leave one row per trial.
src <- raw %>% mutate(eeg_source = ifelse(participant_lab_ID == 9L & session == 3L,
                                          "overlay", "legacy"))
zs <- suppressMessages(.les_summarise_cells(src, "gender_agreement", "midline"))[["200_500"]]
ok(identical(sort(unique(as.character(zs$eeg_source[zs$participant_lab_ID == 9L &
                                                      zs$session == 3L]))), "overlay") &&
     all(zs$eeg_source[!(zs$participant_lab_ID == 9L & zs$session == 3L)] == "legacy") &&
     nrow(zs) == nrow(zc) + 4L,
   "eeg_source is carried per trial and reprocessed Session-3 rows are kept")
ok(les_p1_misfiltered_rows(zs) == 0L && les_p1_reprocessed_rows(zs) == 4L,
   "the fit-time counts read the carried source correctly")

# --- 9. A participant without the L1-dominance score keeps their trials -------------
# Participant 2 loses the score. It is filled with the mean of the other participants'
# scores (participant 1: 1.0, participant 9: 2.0), one value per participant however many
# trials each has, and flagged.
nod <- raw %>% mutate(multilingual_language_diversity =
                        ifelse(participant_lab_ID == 2L, NA_real_, multilingual_language_diversity))
zi <- suppressMessages(.les_summarise_cells(nod, "gender_agreement", "midline"))[["200_500"]]
ok(nrow(zi) == nrow(zc) && !anyNA(zi$z_multilingual_language_diversity),
   "no trial is lost and no covariate value is missing")
ok(near(unique(zi$multilingual_language_diversity[zi$participant_lab_ID == 2L]), 1.5) &&
     all(zi$l1_dominance_imputed == (zi$participant_lab_ID == 2L)),
   "the missing score is the participant-level mean and is flagged")

cat("\nAll .les_summarise_cells unit tests passed.\n")
