# =============================================================================
# 10_extract_literature_trend.R
# -----------------------------------------------------------------------------
# PURPOSE
# Quantify the methodological composition of the L3 morphosyntactic-transfer
# literature, so the Introduction's claim that most of that evidence comes from
# offline acceptability judgements is supported by counts rather than by assertion.
#
# For each publication year we count (a) the L3-transfer literature as a whole,
# (b) the subset using acceptability or grammaticality judgements, and (c) the
# subset using electrophysiology. Counts are written to
# results/_literature_trend.csv, which the manuscript reads; no number is
# transcribed by hand.
#
# METHOD
# Retrieval uses the Scopus Search API through scopusflow (Bernabeu, 2026,
# https://CRAN.R-project.org/package=scopusflow), which handles pagination, rate limits
# and retries, and records the exact query alongside each count so the search is
# inspectable; the counts are dated by retrieved_utc, because Scopus keeps indexing.
#
# Every term is scoped to TITLE-ABS-KEY. This matters: an unscoped term is matched
# against the default (broader) field set and inflates the count several-fold, which
# would understate how specialised the electrophysiological subset is.
#
# LIMITATIONS, to be stated wherever these counts are reported.
#   * Scopus coverage of linguistics is good but not exhaustive, and it under-covers
#     books and chapters, which carry real weight in this field. Counts are a lower
#     bound and index relative composition rather than an exhaustive census.
#   * Keyword matching is imperfect in both directions: a study can use ERPs without
#     "ERP" or "EEG" appearing in title, abstract or keywords, and "EEG" can appear
#     in a paper that merely cites electrophysiological work.
#   * The window is fixed at 2005-2025 (see the `years` default below), so the counts
#     describe a closed range rather than the literature up to the retrieval date. If
#     the upper bound is moved to the current year, that year will be incomplete and
#     the last point of the trend will reflect the retrieval date rather than the
#     literature.
#
# REQUIREMENTS
# scopusflow 0.4.0 and an Elsevier API key in SCOPUS_API_KEY (e.g. in ~/.Renviron).
# Without either, this script stops without writing; the manuscript continues to use
# the committed counts, or placeholders if that file is absent.
#
# USAGE
#   Rscript paper_1_transfer/scripts/10_extract_literature_trend.R
# It takes no arguments and uses the `years` default below; the only output is
# results/_literature_trend.csv.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "03_data_manifest.R"))  # les_assert_readonly_data()
})

#' Count the L3-transfer literature by year and method in Scopus
#'
#' @param years Integer vector of completed publication years. It is a fixed range rather
#'   than one anchored to Sys.Date(), so the counts the manuscript reports do not shift
#'   with the date the script is re-run; extending it to the current year would make the
#'   last point partial (see LIMITATIONS above).
#' @return Invisibly, a data frame with 3 x length(years) rows: stratum, year, n, query,
#'   retrieved_utc and scopusflow_version.
#' @details Side effects: one Scopus count request per row (63 by default);
#'   readRenviron("~/.Renviron") when SCOPUS_API_KEY is unset; a write of
#'   results/_literature_trend.csv through les_assert_readonly_data(). Stops without
#'   scopusflow or a key. Scopus counts change as records are indexed, so a re-run replaces
#'   the reported counts with new ones; it therefore stops when the file exists unless
#'   LES_P1_LIT_REFRESH=1 is set (ISSUES.md G07-09). The committed counts were retrieved on
#'   or before 24 July 2026 (f2b1818) with a scopusflow release before 0.4.0, which the
#'   file did not then record.
les_literature_trend <- function(years = 2005:2025) {
  f <- paper1_results("_literature_trend.csv")
  if (file.exists(f) && !identical(Sys.getenv("LES_P1_LIT_REFRESH"), "1"))
    stop("results/_literature_trend.csv exists. Scopus counts change as records are ",
         "indexed, so a re-run replaces the reported counts; set LES_P1_LIT_REFRESH=1 to ",
         "do so deliberately.")
  if (!requireNamespace("scopusflow", quietly = TRUE))
    stop(paste0(
      "scopusflow is required; install the recorded CRAN release with ",
      "pak::pkg_install('scopusflow@0.4.0')."
    ))
  # Rscript does not always read ~/.Renviron before the package is consulted.
  if (!nzchar(Sys.getenv("SCOPUS_API_KEY")) && file.exists("~/.Renviron"))
    readRenviron("~/.Renviron")
  if (!scopusflow::scopus_has_key())
    stop("No Elsevier API key found in SCOPUS_API_KEY.")

  base <- paste0(
    'TITLE-ABS-KEY(("third language" OR "L3 acquisition" OR "L3 transfer" OR ',
    '"L3 learners") AND (transfer OR "crosslinguistic influence" OR ',
    '"cross-linguistic influence"))')

  strata <- c(
    "All L3-transfer research"               = "",
    "Acceptability/grammaticality judgement" =
      ' AND TITLE-ABS-KEY("acceptability judg*" OR "grammaticality judg*")',
    "Electrophysiology (ERP/EEG)"            =
      ' AND TITLE-ABS-KEY("event-related potential*" OR ERP OR EEG)')

  out <- do.call(rbind, lapply(names(strata), function(s)
    do.call(rbind, lapply(years, function(y) {
      q <- paste0(base, strata[[s]], " AND PUBYEAR = ", y)
      data.frame(stratum = s, year = y,
                 n = as.integer(scopusflow::scopus_count(q)),
                 query = q, stringsAsFactors = FALSE)
    }))))

  out$retrieved_utc <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  out$scopusflow_version <- as.character(utils::packageVersion("scopusflow"))
  les_assert_readonly_data(f)
  utils::write.csv(out, f, row.names = FALSE)
  message("[literature] wrote ", nrow(out), " rows to ", f)
  invisible(out)
}

if (sys.nframe() == 0L) les_literature_trend()
