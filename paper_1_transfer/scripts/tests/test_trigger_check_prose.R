# =============================================================================
# paper_1_transfer/scripts/tests/test_trigger_check_prose.R
# -----------------------------------------------------------------------------
# Checks the manuscript's prose about the trigger-rule check of protocol Amendment 5
# (results/_trigger_check_cells.csv): trigger_check_sentence() in the appendix and
# trigger_limit_sentence() in the Limitations, on the committed table, on one in which every
# cell passes, and on a missing one. The table is written by pandas, whose "True"/"False"
# read.csv leaves as text, so the reader's coercion is tested too.
#
# The helpers are taken from the manuscript itself: knitr::purl() extracts its R code, and
# only the named definitions are evaluated, so nothing is rendered.
#
# Run from the project root:
#   Rscript --vanilla paper_1_transfer/scripts/tests/test_trigger_check_prose.R
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  source(here::here("_shared", "R", "03_data_manifest.R"))
  source(here::here("_shared", "R", "06_manuscript_helpers.R"))
})

ok <- function(cond, msg) {
  if (!isTRUE(cond)) stop("FAIL: ", msg, call. = FALSE)
  cat("PASS:", msg, "\n")
}
has <- function(x, pattern) grepl(pattern, x, fixed = TRUE)

code <- file.path(tempdir(), "paper_1_morphosyntax_purl_trigger.R")
invisible(suppressMessages(knitr::purl(here::here("paper_1_transfer", "paper_1_morphosyntax.qmd"),
                                       output = code, documentation = 0, quiet = TRUE)))
want <- c(".trig_primary", "trigger_check_sentence", "trigger_limit_sentence")
got <- character()
for (e in parse(code, keep.source = FALSE)) {
  if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]) &&
      as.character(e[[2]]) %in% want) {
    eval(e, globalenv())
    got <- c(got, as.character(e[[2]]))
  }
}
ok(setequal(got, want), paste("every helper is defined in the manuscript; missing:",
                              paste(setdiff(want, got), collapse = ", ")))

# The reader as the manuscript's setup chunk runs it.
read_trig <- function(path) {
  t <- utils::read.csv(path, stringsAsFactors = FALSE)
  t$passes <- as.logical(t$passes)
  t
}
committed <- read_trig(here::here("paper_1_transfer", "results", "_trigger_check_cells.csv"))
ok(is.logical(committed$passes) && !anyNA(committed$passes), "the pandas logicals are read as logical")

trig_tbl <- committed
d <- .trig_primary()
n_pass <- sum(d$passes)
ex <- d[d$ci90_low > 0 | d$ci90_high < 0, ]
s <- trigger_check_sentence()
ok(!has(s, "*[") && !has(s, "**[") && has(s, "of the twelve cells passed"),
   "the appendix sentence gives the cells passed")
ok(nrow(ex) != 1L || (has(s, "The interval excluded zero in") && has(s, "Across twelve cells, 1.2 such intervals")),
   "a cell whose interval excludes zero is named, with the number expected by chance")
l <- trigger_limit_sentence()
ok(n_pass == nrow(d) || (has(l, "passed in") && has(l, "(@tbl-trigger-check)") && has(l, "0.33")),
   "a failed check is reported as a limitation")
ok(nrow(ex) != 1L || ex$D_int > 0 || has(l, "understates any violation negativity"),
   "the limitation says which way the omission biases the one differing cell")

# Every cell passing: no limitation, and the appendix says so.
t <- committed; t$passes <- TRUE
t$ci90_low <- pmin(t$ci90_low, -0.01); t$ci90_high <- pmax(t$ci90_high, 0.01); trig_tbl <- t
ok(trigger_limit_sentence() == "", "a check that passes everywhere adds no limitation")
ok(has(trigger_check_sentence(), "All twelve cells passed.") &&
     has(trigger_check_sentence(), "No interval excluded zero"),
   "the appendix says every cell passed and no interval excluded zero")

# Two cells excluding zero in opposite directions are flagged in the limitation.
t <- committed
p <- t$discarded_set == "all lags other than 5"
i <- which(p)[1:2]
t$ci90_low[i] <- c(0.1, -2); t$ci90_high[i] <- c(1.5, -0.1); t$D_int[i] <- c(0.8, -1)
t$passes[i] <- FALSE; trig_tbl <- t
ok(has(trigger_limit_sentence(), "[Check:"), "differing cells the sentence does not cover are flagged")

trig_tbl <- NULL
ok(has(trigger_check_sentence(), "will appear here") && trigger_limit_sentence() == "",
   "without the table the appendix prints its marker and the Limitations say nothing")

cat("\nAll trigger-check prose checks passed.\n")
