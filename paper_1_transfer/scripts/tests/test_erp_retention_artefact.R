# =============================================================================
# paper_1_transfer/scripts/tests/test_erp_retention_artefact.R
# -----------------------------------------------------------------------------
# Pins the headline ERP retention values to the artefact 00c_extract_erp_retention.R
# writes, results/_erp_trial_retention.csv, which the Method injects through erp_ret().
# The script itself checks only the structure of its table, so a regenerated table with
# different artefact rejection is written and reported; this test is where a change in
# the numbers becomes visible. The expectations are the values the manuscript has
# reported: a canonical-scope pooled mean near 31.4 retained trials of the 48 presented,
# with an SD near 5.8.
#
# Run:  Rscript --vanilla paper_1_transfer/scripts/tests/test_erp_retention_artefact.R
# Exits non-zero if the artefact is absent or any expectation fails.
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
if (!file.exists(path)) {
  stop("results/_erp_trial_retention.csv is absent; run 00c_extract_erp_retention.R first.",
       call. = FALSE)
}
ret <- utils::read.csv(path, stringsAsFactors = FALSE)

canonical <- ret[ret$scope == "canonical", , drop = FALSE]
overall   <- ret[ret$scope == "overall",   , drop = FALSE]
ok(nrow(canonical) == 1L && nrow(overall) == 1L,
   "one canonical and one overall pooled row are present")
ok(all(ret$presented_per_cell == 48L),
   "48 trials were presented per condition cell")
ok(abs(canonical$mean_retained - 31.4) < 0.5,
   "canonical pooled mean of retained trials is close to 31.4")
ok(abs(canonical$sd_retained - 5.8) < 0.5,
   "canonical pooled SD of retained trials is close to 5.8")
ok(canonical$mean_retained > 0 && canonical$mean_retained <= 48,
   "canonical pooled mean lies within the presented range")

cat("\nAll ERP retention artefact checks passed.\n")
