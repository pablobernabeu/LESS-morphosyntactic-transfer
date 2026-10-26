# =============================================================================
# Tests for participant-balanced, group-disaggregated descriptive summaries
#
# Run: Rscript --vanilla paper_1_transfer/scripts/tests/test_group_descriptives.R
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  source(here::here("paper_1_transfer", "scripts", "02_extract_accuracy.R"))
  source(here::here("paper_1_transfer", "scripts", "07_extract_grand_average_waveforms.R"))
  source(here::here("paper_1_transfer", "scripts", "07b_extract_grand_average_by_electrode.R"))
})

Sys.unsetenv("LES_P1_EXCLUDE_REPROCESSED")

ok <- function(cond, msg) {
  if (!isTRUE(cond)) stop("FAIL: ", msg, call. = FALSE)
  cat("PASS:", msg, "\n")
}
near <- function(a, b, tol = 1e-10) length(a) == length(b) && all(abs(a - b) < tol)

# --- Accuracy ------------------------------------------------------------------
# One participant contributes one retained trial and another contributes nine.
# The participant-balanced mean is .5, whereas the trial-weighted mean would be .1.
acc <- data.frame(
  participant_lab_ID = factor(c(1L, rep(2L, 9))),
  mini_language = factor(rep("Mini-English", 10)),
  session = factor(rep(2L, 10), levels = c(2, 3, 4, 6)),
  grammatical_property = "gender_agreement",
  grammaticality = "Grammatical",
  correct = c(1, rep(0, 9))
)
ad <- .les_accuracy_by_language(acc)
ok(nrow(ad) == 1L && near(ad$mean_accuracy, 0.5),
   "accuracy gives each participant equal weight")
ok(ad$n_participants == 2L && ad$n_trials == 10L,
   "accuracy records participant and retained-trial counts")

# --- Signal detection ----------------------------------------------------------
# Participant 1 answers "grammatical" to 3 of 4 grammatical and 1 of 4 ungrammatical
# sentences: a symmetric, unbiased profile, so c = 0. Participant 2 answers "grammatical"
# to everything: maximal liberal bias and zero sensitivity after the log-linear
# correction. Hand values: H1 = 3.5/5, FA1 = 1.5/5; H2 = FA2 = 4.5/5.
sdt_in <- data.frame(
  participant_lab_ID = factor(rep(c(1L, 2L), each = 8)),
  mini_language = factor("Mini-Norwegian"),
  session = factor(6L, levels = c(2, 3, 4, 6)),
  grammatical_property = "gender_agreement",
  grammaticality = rep(rep(c("Grammatical", "Ungrammatical"), each = 4), 2),
  correct = c(1, 1, 1, 0,  1, 1, 1, 0,   1, 1, 1, 1,  0, 0, 0, 0)
)
sd_out <- .les_accuracy_sdt_by_language(sdt_in)
d1 <- stats::qnorm(3.5 / 5) - stats::qnorm(1.5 / 5)
c2 <- -(stats::qnorm(4.5 / 5) + stats::qnorm(4.5 / 5)) / 2
ok(near(sd_out$mean_value[sd_out$measure == "d_prime"], (d1 + 0) / 2),
   "d' uses the log-linear correction and averages participants")
ok(near(sd_out$mean_value[sd_out$measure == "criterion"], (0 + c2) / 2),
   "criterion is negative for a bias towards answering grammatical")

# --- The protocol-deviation exclusion reaches the accuracy data ---------------------
p14 <- data.frame(participant_lab_ID = c(13L, 14L, 15L), x = 1:3)
ok(identical(les_p1_drop_protocol_deviation(p14)$participant_lab_ID, c(13L, 15L)),
   "participant 14 is dropped by the protocol-deviation exclusion")

# --- ERP waveforms ---------------------------------------------------------------
# The same imbalance in raw rows must also yield the participant mean; a mis-filtered
# participant-session (53 at Session 3) and the excluded participant (14) must be absent.
# Every participant also has a pre-stimulus sample, so the baseline can be checked: its
# amplitude is subtracted from the waveform.
wave_base <- data.frame(
  participant_lab_ID = c(1L, rep(2L, 9), 53L, 14L),
  mini_language = "Mini-English",
  session = c(rep(2L, 10), 3L, 2L),
  grammatical_property = "gender_agreement",
  grammaticality = "Grammatical",
  electrode = "Pz",
  brain_region = "midline posterior",
  macroregion = "midline",
  hemisphere = NA_character_,
  caudality = "posterior"
)
wave <- rbind(
  cbind(wave_base, time = 400, amplitude = c(0, rep(10, 9), 1000, 1000)),
  cbind(wave_base, time = -50, amplitude = c(-2, rep(2, 9), 0, 0))
)
pm <- .les_participant_waveforms(wave)
wd <- .les_group_waveforms(pm)
w400 <- wd[wd$time == 400 & wd$session == "2", ]
ok(nrow(w400) == 1L && near(w400$mean_amp, ((0 + 2) + (10 - 2)) / 2),
   "ERP waveform is baseline-corrected within participant and gives equal weight")
ok(w400$n_participants == 2L && w400$n_obs == 10L,
   "ERP waveform records participant and raw-observation counts")
ok(!any(wd$session == "3") && !any(pm$participant_lab_ID == "14"),
   "ERP waveform applies both EEG exclusions before averaging")

# Pooling over sessions weights participants, not sessions attended. Participant 1 has
# Sessions 2 and 4 (5 and 1 uV), participant 2 only Session 2 (10 uV): pooled = (3 + 10) / 2.
pool_base <- data.frame(
  participant_lab_ID = c(1L, 1L, 2L), mini_language = "Mini-Norwegian",
  session = c(2L, 4L, 2L), grammatical_property = "gender_agreement",
  grammaticality = "Ungrammatical", electrode = "Pz", brain_region = "midline posterior",
  macroregion = "midline", hemisphere = NA_character_, caudality = "posterior")
pool_in <- rbind(cbind(pool_base, time = 400, amplitude = c(5, 1, 10)),
                 cbind(pool_base, time = -50, amplitude = 0))
pooled <- .les_group_waveforms(.les_participant_waveforms(pool_in))
pp <- pooled[pooled$session == "pooled" & pooled$time == 400, ]
ok(nrow(pp) == 1L && near(pp$mean_amp, 6.5) && pp$n_participants == 2L,
   "pooled waveform averages each participant's sessions before averaging participants")

# Difference waves are ungrammatical minus grammatical, paired within participant.
dw_base <- data.frame(
  participant_lab_ID = rep(c(1L, 2L), each = 2), mini_language = "Mini-Norwegian",
  session = 6L, grammatical_property = "gender_agreement",
  grammaticality = rep(c("Grammatical", "Ungrammatical"), 2), electrode = "Pz",
  brain_region = "midline posterior", macroregion = "midline",
  hemisphere = NA_character_, caudality = "posterior")
dw_in <- rbind(cbind(dw_base, time = 400, amplitude = c(1, 2, 4, 8)),
               cbind(dw_base, time = -50, amplitude = 0))
dw <- .les_group_difference_waves(.les_participant_waveforms(dw_in))
d6 <- dw[dw$session == "6" & dw$time == 400, ]
ok(nrow(d6) == 1L && near(d6$mean_difference, 2.5) && near(d6$se_difference, 1.5),
   "difference wave is violation minus control, paired within participant")

# --- Topography --------------------------------------------------------------------
# Differences are paired within participant before the group mean. Participant
# differences (ungrammatical minus grammatical) are -1 and -4 microvolts, so every window
# containing the 400-ms sample is -2.5.
topo_base <- data.frame(
  participant_lab_ID = c(1L, 1L, 2L, 2L),
  mini_language = "Mini-Norwegian",
  session = 6L,
  grammatical_property = "gender_agreement",
  grammaticality = rep(c("Grammatical", "Ungrammatical"), 2),
  electrode = "Pz",
  brain_region = "midline posterior",
  macroregion = "midline",
  hemisphere = NA_character_,
  caudality = "posterior"
)
topo <- rbind(cbind(topo_base, time = 400, amplitude = c(2, 1, 8, 4)),
              cbind(topo_base, time = -50, amplitude = 0))
tpm <- .les_electrode_participant_means(topo)
td <- .les_group_electrode_window_differences(tpm)
late <- td[td$window == "400_900" & td$session == "6", , drop = FALSE]
ok(nrow(late) == 1L && near(late$mean_difference, -2.5),
   "topographic contrast is violation minus control, paired within participant")
ok(late$n_participants == 2L && near(late$se_difference, 1.5),
   "topographic contrast reports participant-level uncertainty")
ok(any(td$session == "pooled"),
   "topographic contrast is also written pooled over sessions")

cat("\nAll group-descriptive tests passed.\n")
