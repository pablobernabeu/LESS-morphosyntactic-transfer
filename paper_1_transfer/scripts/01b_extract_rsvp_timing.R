# =============================================================================
# paper_1_transfer/scripts/01b_extract_rsvp_timing.R
# Phase 1b -- Recover the RSVP timing of the post-critical word onsets
#             from the OpenSesame presentation logs
# =============================================================================
#
# WHAT THIS SCRIPT PRODUCES
# -------------------------
# paper_1_transfer/data_derived/rsvp_timing_overlap.rds -- a small named list
# holding, for every critical-word trial in the raw presentation logs:
#   * n_trials                  : number of critical-word trials entering the count,
#   * next_onset_min_ms         : minimum   onset latency of the FIRST word after the
#   * next_onset_max_ms         : maximum   critical word, relative to critical-word
#   * next_onset_median_ms      : median    onset (ms),
#   * max_onsets_within_900ms   : the largest number of subsequent word onsets any
#                                 trial shows within (0, 900] ms of the critical
#                                 onset (the manuscript's claim is exactly one),
# together with supporting context (per-session counts, the minimum onset of the
# SECOND subsequent word, exclusion tallies, and provenance fields).
#
# paper_1_transfer/results/_rsvp_timing.csv -- the same census as ONE row, which the
# manuscript reads. data_derived/ is not in version control, so a fresh clone would
# otherwise render the timing sentences as pending; results/ is tracked, and the values
# can be checked against the archive. Its columns are every scalar field of the list
# above, under the same names, plus the per-session counts as n_trials_s<session>, the
# exclusion tallies as n_rows_excluded_<reason>, and n_files_skipped.
#
# WHY THIS QUANTITY MATTERS
# -------------------------
# Paper 1's late analysis window runs 400--900 ms after critical-word onset. The
# presentation script held the critical word's stimulus-onset asynchrony fixed at
# approximately 750 ms, so on every trial the FOLLOWING word appears inside the
# final roughly 150 ms of that window. The manuscript therefore states (Method,
# "the final ~150 ms of the 400--900 ms window contains the beginning of the
# response to the following word") that across all critical-word trials exactly
# one subsequent word onset falls within 900 ms of the critical word, at
# 743--864 ms. Those numbers were first computed ad hoc in an exploratory session
# (2026-07-25) and never persisted; this script is their reproducible source.
#
# INPUTS (READ-ONLY)
# ------------------
# data/raw data/behavioural data from lab sessions/Session {2,3,4,6}/*.csv
# -- every OpenSesame logfile, one per participant x session (including the
# "-test" and "-experiment" split files that the accuracy extraction's stricter
# ^subject-\d+\.csv$ pattern deliberately leaves out). The relevant columns are
# session_part (the "Experiment" block), target_word_location ("word3"/"word4"
# on critical-word trials; empty on Session 2's locative fillers), word1..word10
# (the displayed tokens), word{i}_duration (nominal display duration, ms) and
# time_word{i} (the logged onset timestamp of word i, ms).
#
# WHY ALL *.csv, AND WHY THE DELIMITER IS SNIFFED
# -----------------------------------------------
# The statement being reproduced is about the stimulus presentation itself, so
# its denominator is every logged critical-word trial, not the modelled subset:
# the manuscript's 64,907 was derived from the full raw logs, before any of the
# EEG-side exclusions (the 1 Hz mis-filtered Session-3 datasets, participants
# with unusable trigger streams, artefact rejection) and with no de-duplication.
# This differs from 02_extract_accuracy.R on two documented points, both
# deliberate there and both reversed here because the question is different:
#   * 02 reads only ^subject-\d+\.csv$; here the split "-test"/"-experiment"
#     files are timing evidence like any other log, so all *.csv are read.
#   * 02 fixes the delimiter to a comma, silently dropping the two Session-4
#     logs (participants 3 and 5) that were exported semicolon-delimited; a
#     timing census must not lose 864 trials to a delimiter, so the separator
#     is sniffed from each file's header line. Neither choice writes anything
#     back, so the modelled datasets are unaffected.
#
# DERIVATION (mirrors the original 2026-07-25 computation)
# --------------------------------------------------------
# For every row with session_part == "Experiment" and target_word_location in
# {"word3", "word4"}: count the displayed words (stopping at the first empty
# word slot), require every onset time_word1..time_word{n} to parse and the
# critical word's nominal duration to be present, and require the onset-to-onset
# step to the next word to lie in (0, 5000] ms (a guard against corrupt rows;
# in practice it excludes nothing). The trial then contributes
#   * offsets time_word{j} - time_word{cp} for all j > cp (cp = 3 or 4), of
#     which those in (0, 900] are counted, and
#   * the first subsequent onset latency, whose min/median/max are reported.
# Session 2's locative filler sentences log no target word and are excluded by
# the target_word_location filter, exactly as in the original computation.
#
# The raw logs carry a known blemish that the original computation did not
# remove and this script therefore keeps, counting it separately: a minority of
# files close by re-writing their final trial row verbatim, so a handful of
# critical-word rows are session-close duplicates. n_duplicate_rows reports how
# many of the counted trials are such byte-identical repeats.
#
# NOTE ON THE MEDIAN
# ------------------
# This extraction reproduces the manuscript's 64,907 trials and 743--864 ms
# range exactly, but the median of the full 64,907-trial set is 747 ms, not the
# 748 ms the text carried. The 748 traces to a companion run on the curated
# subset (data/behavioural data from lab sessions/, 46,578 trials, median 748);
# the exploratory session recorded the full-set value as "median 747-748" and
# the drafted wording kept 748. The middle rank of the full set (32,454 of
# 64,907) falls well inside the block of 747 ms values (33,118 trials are at or
# below 747 ms), so 747 is not a rounding knife-edge. The artefact stores the
# full-set value; the manuscript should be wired to it rather than corrected by
# hand.
#
# OUTPUT CONTRACT
# ---------------
# Idempotent; writes the .rds under paper_1_transfer/data_derived/ and the one-row CSV
# under paper_1_transfer/results/ (both guarded by les_assert_readonly_data), and runs
# locally via
#   Rscript paper_1_transfer/scripts/01b_extract_rsvp_timing.R
# The counting window and the plausibility bound on the onset-to-onset step are
# LES_P1_RSVP_WINDOW_MS and LES_P1_RSVP_SOA_MAX_MS in _config.R.
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "03_data_manifest.R"))
  source(here::here("paper_1_transfer", "scripts", "_config.R"))
  library(readr)
})

# Columns consumed below (the logfiles are far wider).
.les_word_cols  <- paste0("word", 1:10)
.les_dur_cols   <- paste0("word", 1:10, "_duration")
.les_onset_cols <- paste0("time_word", 1:10)

# --- Read one logfile with its delimiter sniffed from the header line ---------
# Two Session-4 exports are semicolon-delimited (see header); everything else is
# comma-delimited. Sniffing keeps both without touching any other pipeline.
.read_one_logfile <- function(file) {
  header <- readLines(file, n = 1L, warn = FALSE)
  n_semi  <- lengths(regmatches(header, gregexpr(";", header, fixed = TRUE)))
  n_comma <- lengths(regmatches(header, gregexpr(",", header, fixed = TRUE)))
  delim <- if (isTRUE(n_semi > n_comma)) ";" else ","
  df <- suppressWarnings(readr::read_delim(
    file, delim = delim, na = c("", "NA", "undefined"),
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE, progress = FALSE
  ))
  keep <- intersect(names(df),
                    c("session_part", "target_word_location", "trial",
                      .les_word_cols, .les_dur_cols, .les_onset_cols))
  df[, keep, drop = FALSE]
}

# =============================================================================
# Walk every critical-word trial and collect the post-critical onset offsets
# =============================================================================
build_rsvp_timing <- function() {

  sessions <- LES_ERP_SESSIONS                       # c(2, 3, 4, 6)
  files <- unlist(lapply(sessions, function(s) {
    list.files(behavioural_lab_path(paste("Session", s)),
               pattern = "\\.csv$", full.names = TRUE)
  }))
  if (!length(files)) stop("No behavioural logfiles found under ", behavioural_lab_path())
  session_of <- as.integer(regmatches(files, regexpr("(?<=Session )[0-9]+", files, perl = TRUE)))

  message("[rsvp_timing] reading ", length(files), " logfiles ...")

  # Per-file accumulators (bound into flat vectors after the loop, so that no
  # vector is grown 65,000 times).
  acc <- list(first_onset  = list(),  # first post-critical onset latency, per trial
              second_onset = list(),  # second post-critical onset latency (context)
              n_within_900 = list(),  # subsequent onsets in (0, 900] ms, per trial
              session      = list(),  # session of each counted trial
              dup_key      = list())  # file x trial x critical onset (duplicates)

  skipped_files <- character(0)
  excl <- c(missing_onset = 0L, missing_duration = 0L,
            no_following_word = 0L, soa_out_of_range = 0L)

  for (k in seq_along(files)) {
    df <- .read_one_logfile(files[[k]])
    if (!all(c("session_part", "target_word_location", "time_word1") %in% names(df))) {
      skipped_files <- c(skipped_files, files[[k]])
      next
    }

    df <- df[!is.na(df$session_part) & df$session_part == "Experiment" &
               !is.na(df$target_word_location) &
               df$target_word_location %in% c("word3", "word4"), , drop = FALSE]
    if (!nrow(df)) next

    # Ensure all ten word/onset/duration slots exist as columns (short logs may
    # omit trailing ones); absent slots behave as empty.
    for (col in c(.les_word_cols, .les_dur_cols, .les_onset_cols))
      if (!col %in% names(df)) df[[col]] <- NA_character_

    W <- as.matrix(df[, .les_word_cols])                              # tokens
    O <- suppressWarnings(matrix(as.numeric(as.matrix(df[, .les_onset_cols])),
                                 nrow = nrow(df)))                     # onsets (ms)
    D <- suppressWarnings(matrix(as.numeric(as.matrix(df[, .les_dur_cols])),
                                 nrow = nrow(df)))                     # durations (ms)
    cp <- ifelse(df$target_word_location == "word3", 3L, 4L)

    n_i   <- nrow(df)
    f_on  <- rep(NA_real_, n_i); s_on <- rep(NA_real_, n_i)
    n_900 <- rep(NA_integer_, n_i); d_key <- rep(NA_character_, n_i)

    for (i in seq_len(n_i)) {
      # Number of displayed words: stop at the first empty word slot (matches
      # the original computation; trailing content after a gap is ignored).
      present <- !is.na(W[i, ]) & trimws(W[i, ]) != ""
      first_gap <- match(FALSE, present)
      n_words <- if (is.na(first_gap)) 10L else first_gap - 1L
      if (n_words < 2L) next

      ons <- O[i, seq_len(n_words)]
      if (anyNA(ons)) { excl["missing_onset"] <- excl["missing_onset"] + 1L; next }
      if (cp[i] >= n_words) { excl["no_following_word"] <- excl["no_following_word"] + 1L; next }
      if (is.na(D[i, cp[i]])) { excl["missing_duration"] <- excl["missing_duration"] + 1L; next }

      offsets <- ons[(cp[i] + 1L):n_words] - ons[cp[i]]
      if (offsets[1L] <= 0 || offsets[1L] > LES_P1_RSVP_SOA_MAX_MS) {
        excl["soa_out_of_range"] <- excl["soa_out_of_range"] + 1L; next
      }

      f_on[i]  <- offsets[1L]
      s_on[i]  <- if (length(offsets) >= 2L) offsets[2L] else NA_real_
      n_900[i] <- sum(offsets > 0 & offsets <= LES_P1_RSVP_WINDOW_MS)
      d_key[i] <- paste(files[[k]], df$trial[i], ons[cp[i]])
    }

    counted <- !is.na(f_on)
    acc$first_onset[[k]]  <- f_on[counted]
    acc$second_onset[[k]] <- s_on[counted]     # NA when only one word followed
    acc$n_within_900[[k]] <- n_900[counted]
    acc$session[[k]]      <- rep(session_of[[k]], sum(counted))
    acc$dup_key[[k]]      <- d_key[counted]
  }

  first_onset   <- unlist(acc$first_onset,  use.names = FALSE)
  second_onset  <- unlist(acc$second_onset, use.names = FALSE)
  n_within_900  <- unlist(acc$n_within_900, use.names = FALSE)
  trial_session <- unlist(acc$session,      use.names = FALSE)
  dup_key       <- unlist(acc$dup_key,      use.names = FALSE)

  list(
    # --- the manuscript's four numbers ---------------------------------------
    n_trials                = length(first_onset),
    next_onset_min_ms       = min(first_onset),
    next_onset_max_ms       = max(first_onset),
    next_onset_median_ms    = stats::median(first_onset),
    max_onsets_within_900ms = max(n_within_900),
    # --- supporting context --------------------------------------------------
    min_onsets_within_900ms = min(n_within_900),
    n_trials_exactly_one_onset_within_900ms = sum(n_within_900 == 1L),
    second_onset_min_ms     = min(second_onset, na.rm = TRUE),
    n_trials_by_session     = table(trial_session),
    n_duplicate_rows        = sum(duplicated(dup_key)),
    n_files_read            = length(files) - length(skipped_files),
    skipped_files           = basename(skipped_files),
    n_rows_excluded         = excl,
    # --- provenance ----------------------------------------------------------
    source_dir    = "data/raw data/behavioural data from lab sessions",
    window_rule   = sprintf("subsequent onsets counted when offset is in (0, %d] ms",
                            LES_P1_RSVP_WINDOW_MS),
    generated_utc = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
}

# --- The census as one row, for results/_rsvp_timing.csv ----------------------
# Every scalar field keeps its name. The per-session table becomes n_trials_s<session>,
# the exclusion tallies n_rows_excluded_<reason>, and the skipped-file list its length.
.les_rsvp_timing_row <- function(timing) {
  row <- list()
  for (nm in names(timing)) {
    v <- timing[[nm]]
    if (nm == "n_trials_by_session") {
      for (s in names(v)) row[[paste0("n_trials_s", s)]] <- as.integer(v[[s]])
    } else if (nm == "n_rows_excluded") {
      for (r in names(v)) row[[paste0("n_rows_excluded_", r)]] <- as.integer(v[[r]])
    } else if (nm == "skipped_files") {
      row[["n_files_skipped"]] <- length(v)
    } else if (is.atomic(v) && length(v) == 1L) {
      row[[nm]] <- v
    }
  }
  as.data.frame(row, stringsAsFactors = FALSE, check.names = FALSE)
}

# =============================================================================
# Entry point
# =============================================================================
.run <- function() {
  timing <- build_rsvp_timing()

  out_path <- paper1_derived("rsvp_timing_overlap.rds")
  les_assert_readonly_data(out_path)
  saveRDS(timing, out_path)

  csv_path <- paper1_results("_rsvp_timing.csv")
  les_assert_readonly_data(csv_path)
  utils::write.csv(.les_rsvp_timing_row(timing), csv_path, row.names = FALSE)
  message("[rsvp_timing] wrote ", basename(csv_path))

  message(sprintf(
    paste0("[rsvp_timing] saved %s: n_trials=%d, first subsequent onset ",
           "%d--%d ms (median %s), onsets within 900 ms per trial: min=%d max=%d ",
           "(exactly one on %d trials), second onset earliest %d ms."),
    basename(out_path), timing$n_trials,
    timing$next_onset_min_ms, timing$next_onset_max_ms,
    format(timing$next_onset_median_ms),
    timing$min_onsets_within_900ms, timing$max_onsets_within_900ms,
    timing$n_trials_exactly_one_onset_within_900ms,
    timing$second_onset_min_ms
  ))
  message("[rsvp_timing] trials by session: ",
          paste(names(timing$n_trials_by_session), unname(timing$n_trials_by_session),
                sep = "=", collapse = ", "),
          "; duplicate session-close rows counted: ", timing$n_duplicate_rows,
          "; files skipped: ",
          if (length(timing$skipped_files)) {
            paste(timing$skipped_files, collapse = ", ")
          } else "none",
          "; rows excluded: ",
          paste(names(timing$n_rows_excluded), unname(timing$n_rows_excluded),
                sep = "=", collapse = ", "))
}

if (sys.nframe() == 0L) .run()
