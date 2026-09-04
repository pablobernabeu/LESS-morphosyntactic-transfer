# =============================================================================
# paper_1_transfer/scripts/test_exclusion_guard.R
# Regression tests for the mis-filtered-dataset exclusion and its staleness guard
# =============================================================================
#
# WHY THIS FILE EXISTS
# --------------------
# The Methods of Paper 1 state that four Session-3 recordings, high-pass filtered
# offline at 1 Hz instead of 0.1 Hz, are excluded from the reported analyses. That
# sentence is a claim about the fitted models the manuscript reads, so the
# manuscript checks it before printing it, and prints a visible marker when it
# cannot be substantiated.
#
# An earlier version of that check tested only whether results/_exclusions.csv
# existed. The extraction scripts wrote that file as a side effect, so re-running
# an extraction cleared the marker even when the fits being reported were older
# than the exclusion and still contained all four datasets. The manuscript then
# asserted an exclusion that had not been applied, silently. These tests pin down
# the replacement behaviour so that failure cannot recur unnoticed.
#
# The checks cover three things: that the row-matching survives the factor-level
# trap documented in _config.R, that the fit-time metadata records what the models
# were actually fitted to, and that the manuscript's decision rule refuses to clear
# the marker on partial, exempt, or sensitivity-only evidence.
#
# USAGE
#   Rscript paper_1_transfer/scripts/test_exclusion_guard.R
# Exits non-zero if any check fails, so it can gate a render or a commit hook.
# =============================================================================

source(here::here("paper_1_transfer", "scripts", "_config.R"))

.pass <- 0L; .fail <- 0L
ck <- function(label, got, want) {
  ok <- isTRUE(all.equal(got, want))
  cat(sprintf("%-66s %s\n", label,
              if (ok) "PASS" else sprintf("FAIL (got %s, want %s)",
                                          paste(got, collapse = ","),
                                          paste(want, collapse = ","))))
  if (ok) .pass <<- .pass + 1L else .fail <<- .fail + 1L
}

# --- Fixtures ----------------------------------------------------------------
# Both identifying columns are FACTORS in the extracted cell data, with session
# levels "2","3","4","6". A naive as.integer() would map session 3 to level 2 and
# session 4 to level 3, so the fixtures deliberately include session 4 rows for
# excluded participants to catch that off-by-one.
mk <- function(pids, sess) data.frame(
  participant_lab_ID = factor(pids, levels = as.character(sort(unique(c(pids, 7, 8, 9, 16, 20))))),
  session            = factor(sess, levels = c("2", "3", "4", "6")))

# 7@3, 8@3 and 16@3 are mis-filtered. 7@4, 20@3 and 20@4 are not.
d_with <- mk(c(7, 7, 8, 20, 20, 16), c(3, 4, 3, 3, 4, 3))

# --- The row-matching helper -------------------------------------------------
ck("misfiltered_rows counts factor-coded rows correctly",
   les_p1_misfiltered_rows(d_with), 3L)
ck("session 4 is never mistaken for session 3 (factor level-index trap)",
   les_p1_misfiltered_rows(mk(c(7, 8, 9, 16), c(4, 4, 4, 4))), 0L)
ck("an unlisted participant in session 3 is retained",
   les_p1_misfiltered_rows(mk(c(20, 20), c(3, 3))), 0L)
ck("misfiltered_rows is NA when the identifying columns are absent",
   les_p1_misfiltered_rows(data.frame(x = 1)), NA_integer_)
ck("the drop removes exactly the mis-filtered rows",
   nrow(les_p1_drop_misfiltered(d_with)), nrow(d_with) - 3L)
ck("nothing is mis-filtered after the drop",
   les_p1_misfiltered_rows(les_p1_drop_misfiltered(d_with)), 0L)

# --- The fit-time metadata writer --------------------------------------------
r_clean <- les_p1_write_fit_meta(les_p1_drop_misfiltered(d_with), "erp_clean",
                                 tempfile(fileext = ".rds"))
ck("a clean fit records exclusion_applied = TRUE",  r_clean$exclusion_applied, TRUE)
ck("a clean fit records misfiltered_rows = 0",      r_clean$misfiltered_rows,  0L)
r_stale <- les_p1_write_fit_meta(d_with, "erp_stale", tempfile(fileext = ".rds"))
ck("a fit that still contains them is flagged",     r_stale$exclusion_applied, FALSE)
r_acc <- les_p1_write_fit_meta(d_with, "accuracy_x", tempfile(fileext = ".rds"),
                               exclusion_applicable = FALSE)
ck("the accuracy models are exempt, not flagged",   r_acc$exclusion_applied,    TRUE)
ck("and are recorded as out of scope",              r_acc$exclusion_applicable, FALSE)

# --- The manuscript's decision rule ------------------------------------------
# Kept in step with the misfilter_status() body in paper_1_morphosyntax.qmd: if
# that rule changes, change this one and the expectations below with it.
status_for <- function(tbl) {
  if (is.null(tbl)) return("PENDING: no record")
  m <- tbl[tbl$exclusion_applicable %in% TRUE & tbl$prior_variant %in% "informative", , drop = FALSE]
  if ("keep_misfiltered" %in% names(m)) m <- m[!(m$keep_misfiltered %in% TRUE), , drop = FALSE]
  if (nrow(m) == 0) return("PENDING: nothing applicable")
  n_stale <- sum(!(m$exclusion_applied %in% TRUE))
  if (n_stale > 0) return(sprintf("PENDING: %d of %d stale", n_stale, nrow(m)))
  if (nrow(m) < nrow(les_p1_erp_grid()))
    return(sprintf("PENDING: only %d of %d refitted", nrow(m), nrow(les_p1_erp_grid())))
  ""
}
row_for <- function(i, applied, applicable = TRUE, variant = "informative",
                    keep = FALSE)
  data.frame(model = paste0("erp_", i, if (keep) "_keepmisfiltered" else ""),
             exclusion_applicable = applicable,
             misfiltered_rows = if (applied) 0L else 12L,
             exclusion_applied = applied, prior_variant = variant,
             keep_misfiltered = keep)
rows <- function(n, ...) do.call(rbind, lapply(seq_len(n), row_for, ...))

ck("a complete set of clean informative fits clears the marker",
   status_for(rows(18, applied = TRUE)), "")
ck("no metadata at all keeps the marker",
   grepl("^PENDING", status_for(NULL)), TRUE)
ck("a partial refit keeps the marker",
   grepl("only 6 of 18", status_for(rows(6, applied = TRUE))), TRUE)
ck("a single stale cell among 18 keeps the marker",
   grepl("1 of 18 stale", status_for(rbind(rows(17, applied = TRUE),
                                           row_for(18, applied = FALSE)))), TRUE)
ck("the exempt accuracy fits alone cannot clear the marker",
   grepl("^PENDING", status_for(rows(3, applied = TRUE, applicable = FALSE))), TRUE)
ck("the weak-prior sensitivity refits alone cannot clear the marker",
   grepl("^PENDING", status_for(rows(18, applied = TRUE, variant = "weak"))), TRUE)

# The mis-filter-retained variant (LES_P1_KEEP_MISFILTERED=1) deliberately keeps the four
# datasets, so its records read as stale by construction. They must not be counted against
# the reported grid, and they must not be able to stand in for it either.
ck("a mis-filter-retained refit does not make a clean grid look stale",
   status_for(rbind(rows(18, applied = TRUE),
                    rows(18, applied = FALSE, keep = TRUE))), "")
ck("the mis-filter-retained refits alone cannot clear the marker",
   grepl("^PENDING", status_for(rows(18, applied = FALSE, keep = TRUE))), TRUE)
ck("the variant carries its own tagged model id",
   row_for(1, applied = FALSE, keep = TRUE)$model, "erp_1_keepmisfiltered")

cat(sprintf("\n%d passed, %d failed\n", .pass, .fail))
if (.fail > 0) quit(status = 1)
