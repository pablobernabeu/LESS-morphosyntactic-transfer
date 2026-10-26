# =============================================================================
# paper_1_transfer/scripts/tests/test_retained_trials.R
# -----------------------------------------------------------------------------
# Unit test for the retention descriptives of 00c_extract_erp_retention.R, on a small
# synthetic store: that les_p1_retained_trials() counts the trials of each participant x
# session x property x grammaticality cell from the single-trial cell files, that it stops
# when the six files of a property disagree, when the data hold a row the primary analysis
# excludes, or when only some files exist, and that .run() writes the canonical rows from
# those counts, the overall row from the legacy count table, and the reprocessed datasets'
# share from the same counts.
#
# Everything is written to temporary directories (LES_STORE and LES_DATA_ROOT point there
# for this process only), so neither the real store nor the data tree is touched.
#
# Run:  Rscript --vanilla paper_1_transfer/scripts/tests/test_retained_trials.R
# =============================================================================

store     <- file.path(tempdir(), "les_retention_store")
data_root <- file.path(tempdir(), "les_retention_data")
unlink(c(store, data_root), recursive = TRUE)
dir.create(store, recursive = TRUE); dir.create(data_root, recursive = TRUE)
Sys.setenv(LES_STORE = store, LES_DATA_ROOT = data_root)
Sys.unsetenv("LES_P1_EXCLUDE_REPROCESSED")

suppressPackageStartupMessages({
  library(here)
  # Sourcing 00c defines its functions without running it (its entry point is guarded).
  source(here::here("paper_1_transfer", "scripts", "00c_extract_erp_retention.R"))
})

ok <- function(cond, msg) {
  if (!isTRUE(cond)) stop("FAIL: ", msg, call. = FALSE)
  cat("PASS:", msg, "\n")
}
# TRUE when `expr` stops with a message matching `pattern`, so a refusal is checked for
# its reason and not merely for some error.
fails <- function(expr, pattern) {
  msg <- tryCatch({ expr; "" }, error = function(e) conditionMessage(e))
  grepl(pattern, msg)
}

# --- A synthetic analysed sample ----------------------------------------------
# Participant 7 is a reprocessed 1 Hz record at Session 3 (read from the overlay) and
# participant 11 an ordinary one. Each (participant, session, grammaticality) cell gets a
# known number of trials.
cells <- data.frame(
  participant_lab_ID = c(7L, 7L, 11L, 11L, 11L, 11L),
  session            = c(3L, 3L, 2L, 2L, 3L, 3L),
  mini_language      = "Mini-English",
  grammaticality     = rep(c("Grammatical", "Ungrammatical"), 3),
  n_trials           = c(4L, 3L, 5L, 2L, 6L, 1L),
  stringsAsFactors   = FALSE
)
# One row per trial, numbered 110, 111, ... within its cell, as the cell files hold them.
make_trials <- function(property, cells) {
  rows <- cells[rep(seq_len(nrow(cells)), cells$n_trials), ]
  data.frame(
    participant_lab_ID   = factor(rows$participant_lab_ID),
    session              = factor(rows$session, levels = c(2, 3, 4, 6)),
    grammatical_property = factor(LES_PROPERTY_LABELS[[property]]),
    grammaticality       = factor(rows$grammaticality),
    sentence_marker      = factor(109 + sequence(cells$n_trials)),
    mini_language        = factor(rows$mini_language),
    eeg_source           = factor(ifelse(rows$participant_lab_ID == 7L, "overlay", "legacy")),
    stringsAsFactors     = FALSE
  )
}
write_store <- function(trials_of) {
  for (i in seq_len(nrow(g <- les_p1_erp_grid()))) {
    saveRDS(trials_of(g$property[i], g$window[i], g$macroregion[i]),
            les_p1_cell_rds(g$property[i], g$window[i], g$macroregion[i]))
  }
}
props <- names(LES_P1_PROPERTIES)
write_store(function(p, w, m) make_trials(p, cells))

# --- 1. Counting ---------------------------------------------------------------
cnt <- les_p1_retained_trials()
ok(nrow(cnt) == nrow(cells) * length(props),
   "one count per participant x session x property x grammaticality cell")
g <- cnt[cnt$grammatical_property == "gender_agreement", ]
g <- g[order(g$participant_lab_ID, g$session, g$grammaticality), ]
ok(identical(g$n_trials, cells$n_trials) && is.integer(g$session) &&
     is.integer(g$participant_lab_ID),
   "the counts equal the trials in each cell, with integer IDs and sessions")
ok(setequal(unique(cnt$grammatical_property), props),
   "the property comes back as its snake_case key")

# --- 2. Refusals -----------------------------------------------------------------
gp <- les_p1_erp_grid()[1, ]
f1 <- les_p1_cell_rds(gp$property, gp$window, gp$macroregion)
good <- readRDS(f1)
saveRDS(good[-1, ], f1)
ok(fails(les_p1_retained_trials(), "disagree"),
   "files of one property that disagree stop the count")
saveRDS(rbind(good, good[1, ]), f1)
ok(fails(les_p1_retained_trials(), "not one row per trial"),
   "a file that is not one row per trial stops the count")
legacy_1hz <- good; legacy_1hz$eeg_source[legacy_1hz$participant_lab_ID == "7"] <- "legacy"
saveRDS(legacy_1hz, f1)
ok(fails(les_p1_retained_trials(), "legacy_1hz = [1-9]"), "a legacy 1 Hz row stops the count")
p14 <- good[1, ]; p14$participant_lab_ID <- factor("14"); p14$sentence_marker <- factor("999")
saveRDS(rbind(good, p14), f1)
ok(fails(les_p1_retained_trials(), "deviation = [1-9]"),
   "a row of the excluded participant stops the count")
invisible(file.remove(f1))
ok(fails(les_p1_retained_trials(), "incomplete"), "an incomplete extraction stops the count")
saveRDS(good, f1)
unlink(paper1_derived(), recursive = TRUE)
ok(is.null(les_p1_retained_trials()), "no cell file at all returns NULL")
write_store(function(p, w, m) make_trials(p, cells))

# --- 3. The written tables -------------------------------------------------------
# The legacy table counts a duplicated export (participant 48 at Session 3) and an S103
# cell that the analysed sample does not hold; only the overall row may reflect them.
legacy <- data.frame(
  mini_language = "Mini-English",
  participant_lab_ID = c(11L, 11L, 48L, 11L),
  session = c(2L, 2L, 3L, 2L),
  grammatical_property = "Gender agreement",
  grammaticality = c("Grammatical", "Ungrammatical", "Grammatical", "Number agreement violation"),
  n_trials = c(5L, 2L, 30L, 9L)
)
utils::write.csv(legacy, file.path(data_root, "EEG_trial_count_per_condition.csv"),
                 row.names = FALSE)
out <- suppressMessages(utils::capture.output(res <- .run()))
ret <- utils::read.csv(paper1_results("_erp_trial_retention.csv"), stringsAsFactors = FALSE)
can <- ret[ret$scope == "canonical", ]
ov  <- ret[ret$scope == "overall", ]
all_n <- rep(cells$n_trials, length(props))
ok(can$n_cells == length(all_n) && abs(can$mean_retained - round(mean(all_n), 3)) < 1e-9 &&
     can$source == "extracted_single_trials",
   "the canonical row pools the analysed cells and says so")
ok(ov$n_cells == nrow(legacy) && abs(ov$mean_retained - round(mean(legacy$n_trials), 3)) < 1e-9 &&
     ov$source == "legacy_trial_count_table",
   "the overall row pools the legacy table and says so")
sh <- utils::read.csv(paper1_results("_misfiltered_share.csv"), stringsAsFactors = FALSE)
gs <- sh[sh$grammatical_property == "gender_agreement", ]
ok(gs$n_trials_misfiltered == 7L && gs$n_trials_all == 14L && gs$share_pct == 50 &&
     gs$n_datasets_misfiltered == 1L && gs$n_datasets_all == 2L,
   "the reprocessed datasets' share is counted from the analysed sample")
Sys.setenv(LES_P1_EXCLUDE_REPROCESSED = "1")
ok(fails(suppressMessages(.run()), "LES_P1_EXCLUDE_REPROCESSED"),
   "the robustness switch is refused")
Sys.unsetenv("LES_P1_EXCLUDE_REPROCESSED")

unlink(c(store, data_root), recursive = TRUE)
cat("\nAll retained-trial tests passed.\n")
