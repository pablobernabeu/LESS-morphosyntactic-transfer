# =============================================================================
# paper_1_transfer/scripts/tests/test_erp_retention_artefact.R
# -----------------------------------------------------------------------------
# Pins the headline ERP retention values to the artefacts 00c_extract_erp_retention.R
# writes: results/_erp_trial_retention.csv, which the Method injects through erp_ret(), and
# results/_misfiltered_share.csv, which misfilter_share_sentence() prints. The script
# itself checks only the structure of its tables, so a regenerated table with different
# retention is written and reported. This test fails when such a table changes a headline
# value as the Method prints it.
#
# What is pinned, each compared after rounding to the one decimal the manuscript prints:
#   * the canonical pooled row, counted from the analysed single-trial data: a mean of 31.5
#     retained trials of the 48 presented, SD 5.8, 34.3% not retained, over 874 cells;
#   * the overall pooled row, still read from the legacy count table as first exported:
#     a mean of 31.6 over 1,337 cells;
#   * the reprocessed 1 Hz datasets' share of the analysed Session 3 trials: 16.0% for
#     gender agreement and 16.6% for differential object marking.
# These are the values expected once 00c is re-run on the October 2026 store, counted
# there from the cell files on 3 October 2026. Until then the committed table, written
# from the legacy count table for every row, gives 31.4, 5.8, 34.5% and 891 cells, and
# shares of 15.9% and 16.0%, and this test fails on it by design (ISSUES.md, N15). If a
# table is regenerated on purpose with other values, update these expectations in the
# same commit.
#
# Run:  Rscript --vanilla paper_1_transfer/scripts/tests/test_erp_retention_artefact.R
# Exits non-zero if an artefact is absent or any expectation fails.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  source(here::here("_shared", "R", "00_paths.R"))
})

ok <- function(cond, msg) {
  if (!isTRUE(cond)) stop("FAIL: ", msg, call. = FALSE)
  cat("PASS:", msg, "\n")
}

path <- paper1_results("_erp_trial_retention.csv")
share_path <- paper1_results("_misfiltered_share.csv")
for (p in c(path, share_path)) {
  if (!file.exists(p)) {
    stop(basename(p), " is absent; run 00c_extract_erp_retention.R first.", call. = FALSE)
  }
}
ret   <- utils::read.csv(path, stringsAsFactors = FALSE)
share <- utils::read.csv(share_path, stringsAsFactors = FALSE)

# --- Structure: which rows come from which source ----------------------------
ok("source" %in% names(ret),
   "the retention table records the source of every row")
canonical <- ret[ret$scope == "canonical", , drop = FALSE]
overall   <- ret[ret$scope == "overall",   , drop = FALSE]
per_cond  <- ret[ret$scope == "per_condition_canonical", , drop = FALSE]
ok(nrow(canonical) == 1L && nrow(overall) == 1L,
   "one canonical and one overall pooled row are present")
ok(all(c(canonical$source, per_cond$source) == "extracted_single_trials"),
   "the canonical and per-condition rows are counted from the analysed single-trial data")
ok(overall$source == "legacy_trial_count_table",
   "the overall row is read from the legacy count table")
ok(sum(per_cond$n_cells) == canonical$n_cells,
   "the per-condition rows partition the canonical cells")

# --- Headline values, at the precision the Method prints ---------------------
ok(round(canonical$mean_retained, 1) == 31.5,
   "canonical pooled mean of retained trials rounds to 31.5")
ok(round(canonical$sd_retained, 1) == 5.8,
   "canonical pooled SD of retained trials rounds to 5.8")
ok(round(canonical$pct_discarded, 1) == 34.3,
   "canonical pooled percentage not retained rounds to 34.3")
ok(canonical$n_cells == 874L,
   "canonical pooled row covers 874 cells")
ok(round(overall$mean_retained, 1) == 31.6 && overall$n_cells == 1337L,
   "overall pooled row (legacy, as first exported) is 31.6 over 1,337 cells")

# --- The reprocessed datasets' share, and its agreement with the retention table --
ok(identical(sort(share$grammatical_property),
             c("differential_object_marking", "gender_agreement")) && all(share$session == 3L),
   "the share covers the two properties recorded at Session 3")
pct <- stats::setNames(round(share$share_pct, 1), share$grammatical_property)
ok(pct[["gender_agreement"]] == 16.0 && pct[["differential_object_marking"]] == 16.6,
   "the reprocessed datasets hold 16.0% (gender) and 16.6% (DOM) of the Session 3 trials")
s3 <- per_cond[per_cond$session == 3L, , drop = FALSE]
trials_s3 <- tapply(s3$mean_retained * s3$n_cells, s3$grammatical_property, sum)
ok(all(abs(trials_s3[share$grammatical_property] - share$n_trials_all) < 0.5),
   "the share's Session 3 totals equal those of the per-condition retention rows")

cat("\nAll ERP retention artefact checks passed.\n")
