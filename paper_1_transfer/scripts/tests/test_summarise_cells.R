# =============================================================================
# paper_1_transfer/scripts/tests/test_summarise_cells.R
# -----------------------------------------------------------------------------
# Unit test for the pure post-merge transform .les_summarise_cells() in
# 01_extract_erp_single_trials.R. It builds a SMALL synthetic version of the
# un-aggregated merge output (with known amplitudes) and checks the windowing,
# baseline matching, within-participant z-scoring and item_id construction --
# i.e. the error-prone parts of the transform -- WITHOUT the memory-heavy EEG load.
#
# Run:  Rscript --vanilla paper_1_transfer/scripts/tests/test_summarise_cells.R
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
  # Sourcing the extractor defines .les_scale + .les_summarise_cells. The heavy
  # loader is lazy-sourced inside the loader function, and .run() is guarded by
  # sys.nframe(), so this source has no side effects.
  source(here::here("paper_1_transfer", "scripts", "01_extract_erp_single_trials.R"))
})

ok <- function(cond, msg) {
  if (!isTRUE(cond)) stop("FAIL: ", msg, call. = FALSE)
  cat("PASS:", msg, "\n")
}
near <- function(a, b, tol = 1e-8) all(abs(a - b) < tol)

# --- Build a synthetic un-aggregated merge output ----------------------------
# amplitude = time/100 + grammaticality_effect + electrode_offset.
# The electrode offsets (+/-0.1) cancel under electrode averaging, so the window
# mean is a known function of time; a grammaticality effect (+0.5 for
# ungrammatical) gives genuine within-participant variance to z-score.
grid <- expand.grid(
  participant_lab_ID = c(1L, 2L),
  grammaticality     = c("Grammatical", "Ungrammatical"),
  sentence_marker    = c("m1", "m2"),
  electrode          = c("e1", "e2"),
  time               = c(-100, -50, 200, 300, 400, 500, 600, 700, 898),
  stringsAsFactors   = FALSE
)

raw <- grid %>%
  mutate(
    session                = 2L,
    grammatical_property   = "gender_agreement",
    brain_region           = "central",
    macroregion            = "midline",
    hemisphere             = NA_character_,
    caudality              = "medial",
    recoded_grammaticality = ifelse(grammaticality == "Grammatical", 0.5, -0.5),
    recoded_session        = 0,
    recoded_hemisphere     = NA_real_,                       # midline: no hemisphere
    recoded_caudality      = 0,
    recoded_brain_region   = 1,
    mini_language          = ifelse(participant_lab_ID == 1L, "Mini-English", "Mini-Norwegian"),
    recoded_mini_language  = ifelse(mini_language == "Mini-English", -0.5, 0.5),
    multilingual_language_diversity = ifelse(participant_lab_ID == 1L, 1.0, 2.0),
    gram_effect = ifelse(grammaticality == "Ungrammatical", 0.5, 0.0),
    elec_offset = ifelse(electrode == "e1", 0.1, -0.1),
    amplitude   = time / 100 + gram_effect + elec_offset
  ) %>%
  select(-gram_effect, -elec_offset)

cells <- .les_summarise_cells(raw, "gender_agreement", "midline")

# --- 1. Structure ------------------------------------------------------------
ok(identical(names(cells), c("200_500", "300_600", "400_900")),
   "returns the three named windows")

# One row per participant x grammaticality x sentence_marker x brain_region (8);
# electrodes and time-points are collapsed.
ok(all(vapply(cells, nrow, integer(1)) == 8L),
   "each window collapses electrodes/time to 8 trial-region rows")

# --- 2. Correct windowing (the key legacy-bug fix) ---------------------------
# For Grammatical/m1/P1, the window mean amplitude must equal mean(time/100) over
# the EXACT window samples -- and differ between overlapping windows.
get_amp <- function(w, gram) {
  cells[[w]] %>%
    filter(participant_lab_ID == 1L, grammaticality == gram, sentence_marker == "m1") %>%
    pull(amplitude)
}
ok(near(get_amp("200_500", "Grammatical"), mean(c(200, 300, 400) / 100)),   # 3.0
   "200_500 window mean uses only samples in [200,498]")
ok(near(get_amp("300_600", "Grammatical"), mean(c(300, 400, 500) / 100)),   # 4.0
   "300_600 window mean uses only samples in [300,598]")
ok(near(get_amp("400_900", "Grammatical"), mean(c(400, 500, 600, 700, 898) / 100)), # 6.196
   "400_900 window mean uses only samples in [400,898]")
ok(!near(get_amp("200_500", "Grammatical"), get_amp("300_600", "Grammatical")),
   "overlapping windows yield DIFFERENT means (no first-match splitting)")
ok(near(get_amp("200_500", "Ungrammatical") - get_amp("200_500", "Grammatical"), 0.5),
   "grammaticality effect (+0.5) preserved after electrode averaging")

# --- 3. Baseline covariate matched 1:1 ---------------------------------------
# Baseline = mean over time<0 samples = mean(-1, -0.5) + gram_effect.
bl <- cells[["200_500"]] %>%
  filter(participant_lab_ID == 1L, sentence_marker == "m1") %>%
  arrange(grammaticality)
ok(near(bl$baseline_amplitude[bl$grammaticality == "Grammatical"], -0.75) &&
   near(bl$baseline_amplitude[bl$grammaticality == "Ungrammatical"], -0.25),
   "baseline_amplitude is the matched pre-stimulus mean per grammaticality")

# --- 4. Within-participant z-scoring of DV -----------------------------------
zc <- cells[["200_500"]]
ok(all(zc %>% group_by(participant_lab_ID) %>%
         summarise(m = mean(z_amplitude), .groups = "drop") %>% pull(m) |> abs() < 1e-8),
   "z_amplitude has mean 0 within each participant")
ok(stats::sd(zc$z_amplitude) > 0,
   "z_amplitude is genuinely scaled (non-constant), not collapsed to 0")

# --- 5. item_id, recoded predictors, provenance tags -------------------------
ok(all(as.character(zc$item_id) == paste0(zc$mini_language, "_", zc$sentence_marker)),
   "item_id = <mini_language>_<sentence_marker>")
ok(dplyr::n_distinct(zc$z_recoded_grammaticality) == 2,
   "z_recoded_grammaticality retains its two contrast levels")
ok(all(is.na(zc$z_recoded_hemisphere)),
   "z_recoded_hemisphere is all-NA on midline (correctly unused)")
ok(all(zc$time_window == "200_500" & zc$window_min_ms == 200 & zc$window_max_ms == 498),
   "provenance tags (time_window/min/max) are correct")

cat("\nAll .les_summarise_cells unit tests passed.\n")
