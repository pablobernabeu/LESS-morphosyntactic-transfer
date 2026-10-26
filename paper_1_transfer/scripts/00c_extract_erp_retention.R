# =============================================================================
# paper_1_transfer/scripts/00c_extract_erp_retention.R
#
# PURPOSE
# -------
# Derive the ERP single-trial *retention* descriptives that the Method section of
# paper_1_morphosyntax.qmd injects through erp_ret(): the mean and SD of trials retained
# per condition cell, against the 48 presented. This script is the source of those
# numbers. It writes both the canonical and the overall scope (see below), so the choice
# the manuscript makes is auditable in the artefact.
#
# SOURCE
# ------
# The canonical figures are counted from the analysed sample itself: the eighteen
# single-trial cell files step 01 writes (les_p1_cell_rds() in _config.R), which are the
# data frames step 03 fits. Each holds one row per retained Grammatical or Ungrammatical
# trial in one window and macroregion, after every EEG exclusion of _config.R, with the
# reprocessed and recovered records read from the overlay of
# docs/eeg_filter_reprocessing_protocol.md. The six files of a property hold the same
# trials, and the script stops if they do not. On the October 2026 store, the rows of
# these files equal the n_obs recorded for every fitted ERP model.
#
# Until October 2026 every figure here came from the legacy count table
# 'data/EEG_trial_count_per_condition.csv', written by 'data/EEG data descriptives.R'
# from the original exports, so it described the datasets as first exported: it still
# counted the duplicated export (Session 3 of lab ID 48) and the participant excluded for a
# protocol deviation, lacked the two exports whose marker files were rebuilt, and held the
# misaligned original exports of the two recovered records in place of their
# re-segmentations (ISSUES.md, N15). Counted from the analysed sample, the canonical pooled
# row moved from 891 cells (mean 31.438, SD 5.804, 34.505% not retained) to 874 cells
# (31.519, 5.766, 34.334%).
#
# The legacy table is still read for the 'overall' scope alone, because that scope pools
# the third violation condition of each property (S103), which step 01 does not extract
# and no analysis uses. The overall row therefore keeps describing the datasets as first
# exported, and its 'source' column says so. The table's columns are
#     mini_language, participant_lab_ID, session, grammatical_property,
#     grammaticality, n_trials
# with one row per participant x session x property x grammaticality cell.
#
# Most of the trial loss is not artefact rejection: the two-step segmentation keeps a
# trial only when its condition trigger falls exactly five samples after its property
# trigger, which fails for about a third of trials, and semi-automatic inspection removed
# under 1% (ISSUES.md, N7). The experiment presented 48 trials per cell (this constant is
# documented in the legacy script, which computes "% discarded" as
# 100*(1 - mean(n_trials)/48), and was confirmed against all 1,350 logged property x
# condition x session cells on 17 Sep 2026).
#
# WHAT "CANONICAL" vs "OVERALL" MEANS
# -----------------------------------
# Paper 1 models the canonical Grammatical vs Ungrammatical contrast only (see
# _config.R: LES_P1_GRAMMATICALITY_REGEX = "S10[12]"; the ancillary S103 violation
# conditions -- here "Number agreement violation" and "Article location violation"
# -- are excluded). We therefore report TWO pooled summaries and tag them in a
# 'scope' column:
#   * scope == "canonical": the Grammatical + Ungrammatical cells that are actually
#                           modelled, counted from the analysed sample; the row erp_ret()
#                           reads.
#   * scope == "overall":   ALL grammaticality categories pooled, the figure the legacy
#                           descriptives script reported, from the legacy table.
# The expected headline values are not asserted here, where a regenerated table would
# fail the script before anyone saw its numbers; they are pinned in
# tests/test_erp_retention_artefact.R, which reads the written table.
#
# OUTPUT
# ------
# paper_1_transfer/results/_erp_trial_retention.csv
#   Per-condition rows (scope == "per_condition_canonical") plus two pooled
#   summary rows (scope == "canonical" and scope == "overall"). Columns:
#     scope, grammatical_property, session, mini_language, grammaticality,
#     mean_retained, sd_retained, n_cells, presented_per_cell, pct_discarded, source
#   `source` is "extracted_single_trials" on the per-condition and canonical rows and
#   "legacy_trial_count_table" on the overall row.
# paper_1_transfer/results/_misfiltered_share.csv
#   One row per property recorded at the session of the reprocessed 1 Hz datasets
#   (_config.R, LES_P1_MISFILTERED): the retained trials those datasets contribute to the
#   analysed sample, the retained trials of every analysed dataset at that session, and
#   their ratio as a percentage. The Method quotes that share, so it is computed here from
#   the same retained-trial counts and not typed.
#
# This script is idempotent: re-running it fully regenerates both CSVs. Sourcing it only
# defines its functions, so 00_extract_participants.R and 00b_audit_participant_flow.R
# reuse les_p1_retained_trials() for the usable-ERP stage of the participant flow.
# =============================================================================

suppressWarnings(suppressMessages({
  library(dplyr)
  library(readr)
}))

# --- Shared infrastructure (paths, manifest, read-only guard, exclusion list) --
if (!exists("data_path"))            source(here::here("_shared", "R", "00_paths.R"))
if (!exists("LES_PROPERTY_CODES"))   source(here::here("_shared", "R", "03_data_manifest.R"))
if (!exists("LES_P1_MISFILTERED"))   source(here::here("paper_1_transfer", "scripts", "_config.R"))

# --- Design constants --------------------------------------------------------
PRESENTED_PER_CELL <- 48L   # trials presented per condition cell (see header)

# The modelled grammaticality contrast (canonical Grammatical vs Ungrammatical).
CANONICAL_GRAMMATICALITY <- c("Grammatical", "Ungrammatical")

# Values of the `source` column.
RETENTION_SOURCE_EXTRACTED <- "extracted_single_trials"
RETENTION_SOURCE_LEGACY    <- "legacy_trial_count_table"

# Map the human-readable property labels used in the legacy CSV and in the extracted cell
# files onto the canonical snake_case property names of the data manifest,
# names(LES_PROPERTY_CODES), so that downstream code and the manuscript share one
# vocabulary. Both sources label each property in the same words as the manuscript's
# figures, so the map is derived from the manifest's display labels (LES_PROPERTY_LABELS,
# keyed by property in design order) and the two cannot drift apart. A label the map does
# not know comes back NA, which the checks below refuse.
stopifnot(setequal(names(LES_PROPERTY_LABELS), names(LES_PROPERTY_CODES)))
PROPERTY_LABEL_TO_KEY <- stats::setNames(names(LES_PROPERTY_LABELS),
                                         unname(LES_PROPERTY_LABELS))

#' Retained trials per cell of the analysed ERP sample
#'
#' Counts the trials of each participant x session x property x grammaticality cell in the
#' single-trial data step 01 writes and step 03 fits, i.e. after every EEG exclusion and
#' with the reprocessed and recovered records read from the overlay.
#'
#' @param properties Character vector of property keys, a subset of
#'   names(LES_P1_PROPERTIES).
#' @return A data frame with columns participant_lab_ID and session (integer),
#'   mini_language, grammatical_property (snake_case key), grammaticality and n_trials
#'   (integer), one row per cell holding at least one retained trial; NULL when none of
#'   the properties' cell files exists yet (a fresh clone, or a store step 01 has not
#'   reached).
#' @details Reads every cell file of each property, les_p1_cell_rds() for its three
#'   windows and two macroregions, and requires the six to give identical counts, since
#'   each holds one row per retained trial. Stops when only some of the files exist, when
#'   a file is not one row per trial or lacks a column the count needs, when it holds a
#'   label the property map does not know or a condition outside Grammatical and
#'   Ungrammatical, or when it holds a row the primary analysis excludes (a legacy 1 Hz or
#'   invalid export, or the participant excluded for a protocol deviation). les_p1_cell_rds()
#'   reads LES_P1_EXCLUDE_REPROCESSED, so a caller describing the primary analysis must
#'   refuse that switch, as .run() below does.
les_p1_retained_trials <- function(properties = names(LES_P1_PROPERTIES)) {
  grid <- les_p1_erp_grid()
  grid <- grid[grid$property %in% properties, , drop = FALSE]
  paths <- unname(mapply(les_p1_cell_rds, grid$property, grid$window, grid$macroregion))
  have <- file.exists(paths)
  if (!any(have)) return(NULL)
  if (!all(have)) {
    stop("[retention] the single-trial extraction is incomplete; missing ",
         paste(basename(paths[!have]), collapse = ", "),
         ". Rerun 01_extract_erp_single_trials.R.", call. = FALSE)
  }

  cell_key  <- c("participant_lab_ID", "session", "mini_language", "grammaticality")
  trial_key <- c("participant_lab_ID", "session", "grammaticality", "sentence_marker")
  out <- list()
  for (p in unique(grid$property)) {
    ref <- NULL
    for (f in paths[grid$property == p]) {
      d <- as.data.frame(readRDS(f))
      miss <- setdiff(c(trial_key, "mini_language", "grammatical_property", "eeg_source"),
                      names(d))
      if (length(miss)) {
        stop("[retention] ", basename(f), " lacks ", paste(miss, collapse = ", "),
             "; rerun 01_extract_erp_single_trials.R.", call. = FALSE)
      }
      if (anyDuplicated(d[trial_key])) {
        stop("[retention] ", basename(f), " is not one row per trial (a pre-17-September ",
             "cluster-row extraction?); rerun 01_extract_erp_single_trials.R.", call. = FALSE)
      }
      if (!all(PROPERTY_LABEL_TO_KEY[as.character(d$grammatical_property)] %in% p) ||
          !all(as.character(d$grammaticality) %in% CANONICAL_GRAMMATICALITY)) {
        stop("[retention] ", basename(f), " holds a property other than ", p,
             " or a condition other than Grammatical and Ungrammatical.", call. = FALSE)
      }
      excluded <- c(legacy_1hz       = les_p1_misfiltered_rows(d),
                    legacy_invalid   = les_p1_invalid_export_rows(d),
                    deviation        = les_p1_deviation_rows(d))
      if (any(excluded != 0L)) {
        stop("[retention] ", basename(f), " holds rows the primary analysis excludes (",
             paste(names(excluded), excluded, sep = " = ", collapse = ", "), ").",
             call. = FALSE)
      }
      cnt <- stats::aggregate(list(n_trials = rep(1L, nrow(d))),
                              lapply(d[cell_key], as.character), FUN = sum)
      cnt <- cnt[do.call(order, unname(as.list(cnt[cell_key]))), , drop = FALSE]
      rownames(cnt) <- NULL
      if (is.null(ref)) {
        ref <- cnt
      } else if (!identical(ref, cnt)) {
        stop("[retention] the cell files of ", p, " disagree about the retained trials (",
             basename(f), "); rerun 01_extract_erp_single_trials.R for that property.",
             call. = FALSE)
      }
    }
    ref$grammatical_property <- p
    out[[p]] <- ref
  }
  res <- do.call(rbind, out)
  rownames(res) <- NULL
  res$participant_lab_ID <- as.integer(res$participant_lab_ID)
  res$session            <- as.integer(res$session)
  res[, c("participant_lab_ID", "session", "mini_language", "grammatical_property",
          "grammaticality", "n_trials")]
}

#' The legacy per-cell trial-count table, as first exported
#'
#' @return The table of erp_trial_count_csv() (data/EEG_trial_count_per_condition.csv) with
#'   grammatical_property mapped to the snake_case keys and session as integer, or NULL
#'   when the file is absent. Stops on a missing column, an unmapped property label or a
#'   session outside LES_ERP_SESSIONS.
.les_legacy_trial_counts <- function() {
  src_csv <- erp_trial_count_csv()
  if (!file.exists(src_csv)) return(NULL)
  message("[00c] reading the legacy count table for the overall scope: ", src_csv)
  trials <- read_csv(src_csv, show_col_types = FALSE)
  stopifnot(all(c("mini_language", "participant_lab_ID", "session", "grammatical_property",
                  "grammaticality", "n_trials") %in% names(trials)))
  trials$grammatical_property <- unname(PROPERTY_LABEL_TO_KEY[trials$grammatical_property])
  trials$session <- as.integer(trials$session)
  stopifnot(all(!is.na(trials$grammatical_property)),
            all(trials$session %in% LES_ERP_SESSIONS))
  trials
}

#' One pooled summary row of _erp_trial_retention.csv
#'
#' A pooled row treats every retained cell equally (each cell = one observation), matching
#' how the legacy script computed the headline mean and SD.
#'
#' @param n_trials Integer vector, the retained trials of every cell pooled.
#' @param scope_label "canonical" or "overall".
#' @param grammaticality_label The grammaticality the pooled cells cover:
#'   "Grammatical+Ungrammatical" for the canonical scope, "ALL" for the overall one. The
#'   caller passes exactly the cells that label describes.
#' @param source RETENTION_SOURCE_EXTRACTED or RETENTION_SOURCE_LEGACY.
#' @return A one-row tibble with the columns of the written table.
pooled_row <- function(n_trials, scope_label, grammaticality_label, source) {
  tibble(
    scope                = scope_label,
    grammatical_property = "ALL",
    session              = NA_integer_,
    mini_language        = "ALL",
    grammaticality       = grammaticality_label,
    mean_retained        = mean(n_trials),
    sd_retained          = sd(n_trials),
    n_cells              = length(n_trials),
    presented_per_cell   = PRESENTED_PER_CELL,
    pct_discarded        = 100 * (PRESENTED_PER_CELL - mean(n_trials)) / PRESENTED_PER_CELL,
    source               = source
  )
}

#' Write _erp_trial_retention.csv and _misfiltered_share.csv
#'
#' Takes no arguments. Refuses LES_P1_EXCLUDE_REPROCESSED=1, because both tables are
#' untagged and describe the primary analysis. Reads the cell files through
#' les_p1_retained_trials() and the legacy table through .les_legacy_trial_counts(), writes
#' the two CSVs to paper1_results() (guarded by les_assert_readonly_data()) and prints them.
#' Stops when no cell file exists. Without the legacy table the overall row is left out and
#' a message says so. Returns the retention table invisibly.
.run <- function() {
  if (les_p1_exclude_reprocessed()) {
    stop("[00c] LES_P1_EXCLUDE_REPROCESSED=1 is set, but the retention tables describe the ",
         "primary analysis and carry no robustness tag. Unset it and rerun.", call. = FALSE)
  }
  counts <- les_p1_retained_trials()
  if (is.null(counts)) {
    stop("[00c] no single-trial cell file under ", paper1_derived(),
         "; run 01_extract_erp_single_trials.R first.", call. = FALSE)
  }
  message(sprintf("[00c] counted %d retained trials in %d cells of %d participants from the analysed sample",
                  sum(counts$n_trials), nrow(counts), dplyr::n_distinct(counts$participant_lab_ID)))
  stopifnot(all(counts$n_trials >= 1L & counts$n_trials <= PRESENTED_PER_CELL))
  legacy <- .les_legacy_trial_counts()

  # --- Per-condition table (canonical cells only) ------------------------------
  # One summary row per (property x session x mini_language x grammaticality).
  per_condition <- counts %>%
    group_by(grammatical_property, session, mini_language, grammaticality) %>%
    summarise(
      mean_retained = mean(n_trials),
      sd_retained   = sd(n_trials),
      n_cells       = n(),
      .groups       = "drop"
    ) %>%
    mutate(
      scope              = "per_condition_canonical",
      presented_per_cell = PRESENTED_PER_CELL,
      pct_discarded      = 100 * (PRESENTED_PER_CELL - mean_retained) / PRESENTED_PER_CELL,
      source             = RETENTION_SOURCE_EXTRACTED
    )

  # --- Pooled summary rows ------------------------------------------------------
  canonical_pooled <- pooled_row(counts$n_trials, "canonical", "Grammatical+Ungrammatical",
                                 RETENTION_SOURCE_EXTRACTED)
  overall_pooled <- if (!is.null(legacy)) {
    pooled_row(legacy$n_trials, "overall", "ALL", RETENTION_SOURCE_LEGACY)
  } else {
    message("[00c] ", erp_trial_count_csv(), " is absent, so the overall row is left out.")
    NULL
  }

  # --- Assemble and write -------------------------------------------------------
  out <- bind_rows(
    overall_pooled,
    canonical_pooled,
    per_condition %>%
      select(scope, grammatical_property, session, mini_language, grammaticality,
             mean_retained, sd_retained, n_cells, presented_per_cell, pct_discarded, source)
  ) %>%
    mutate(
      mean_retained = round(mean_retained, 3),
      sd_retained   = round(sd_retained, 3),
      pct_discarded = round(pct_discarded, 3)
    )

  out_csv <- paper1_results("_erp_trial_retention.csv")
  les_assert_readonly_data(out_csv)   # never write inside read-only data/
  write_csv(out, out_csv)
  message("[00c] wrote: ", out_csv, "  (", nrow(out), " rows)")

  # --- Share of the session's analysed trials held by the reprocessed 1 Hz datasets ----
  # In the primary analysis these datasets are the reprocessed 0.1 Hz exports, which keep
  # exactly the trials of the 1 Hz exports, so their share of the retained canonical trials
  # at their session is a direct ratio within the analysed sample. One row per property
  # recorded at that session; a property not yet introduced then has no row, which is the
  # correct statement about it.
  mis_key <- paste(LES_P1_MISFILTERED$participant_lab_ID, LES_P1_MISFILTERED$session)
  mis_share <- counts %>%
    filter(session %in% unique(LES_P1_MISFILTERED$session)) %>%
    mutate(misfiltered = paste(participant_lab_ID, session) %in% mis_key) %>%
    group_by(grammatical_property, session) %>%
    summarise(
      n_datasets_misfiltered = n_distinct(participant_lab_ID[misfiltered]),
      n_datasets_all         = n_distinct(participant_lab_ID),
      n_trials_misfiltered   = sum(n_trials[misfiltered]),
      n_trials_all           = sum(n_trials),
      .groups = "drop"
    ) %>%
    mutate(share_pct = round(100 * n_trials_misfiltered / n_trials_all, 3))

  share_csv <- paper1_results("_misfiltered_share.csv")
  les_assert_readonly_data(share_csv)
  write_csv(mis_share, share_csv)
  message("[00c] wrote: ", share_csv, "  (", nrow(mis_share), " rows)")

  # --- Validate the structure of the written table -------------------------------
  # Structural checks only: the canonical row is present (the overall one too whenever the
  # legacy table is), the presented count is the design constant, each pooled mean lies
  # within the presented range, and the per-condition rows partition the canonical cells.
  # The headline values themselves are asserted by tests/test_erp_retention_artefact.R
  # against the written artefact, so a regenerated table with different numbers is
  # reported, not refused.
  pooled <- out[out$scope %in% c("overall", "canonical"), , drop = FALSE]
  stopifnot(
    setequal(pooled$scope, c(if (!is.null(legacy)) "overall", "canonical")),
    all(pooled$presented_per_cell == PRESENTED_PER_CELL),
    all(pooled$mean_retained > 0 & pooled$mean_retained <= PRESENTED_PER_CELL),
    sum(per_condition$n_cells) == canonical_pooled$n_cells
  )

  # --- Report ------------------------------------------------------------------
  cat("\n===== ERP trial retention =====\n")
  cat(sprintf(paste0("CANONICAL pooled (Grammatical+Ungrammatical, analysed sample): ",
                     "mean = %.3f, SD = %.3f, cells = %d, %% discarded = %.2f\n"),
              canonical_pooled$mean_retained, canonical_pooled$sd_retained,
              canonical_pooled$n_cells, canonical_pooled$pct_discarded))
  if (!is.null(overall_pooled)) {
    cat(sprintf(paste0("OVERALL   pooled (all categories, legacy table as first exported): ",
                       "mean = %.3f, SD = %.3f, cells = %d, %% discarded = %.2f\n"),
                overall_pooled$mean_retained, overall_pooled$sd_retained,
                overall_pooled$n_cells, overall_pooled$pct_discarded))
  }
  cat("\nhead of output table:\n")
  print(utils::head(out, 8))
  cat("\npooled/canonical summary rows:\n")
  print(out %>% filter(scope %in% c("overall", "canonical")) %>% as.data.frame())
  cat("\nreprocessed 1 Hz datasets' share of the session's analysed canonical trials:\n")
  print(as.data.frame(mis_share))
  cat("\n[00c] done.\n")
  invisible(out)
}

if (sys.nframe() == 0L) .run()
