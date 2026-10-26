# =============================================================================
# paper_1_transfer/scripts/00d_extract_training_gate_flow.R
#
# PURPOSE
# -------
# The pre-registered design used an >80% post-training comprehension threshold on
# the first attempt. A participant who failed retrained and took a second test, then
# proceeded to the experiment regardless of that score. This script reconstructs
# the attempt outcomes from the OpenSesame lab-session logs and writes an audit
# table to BOTH papers' results/ folders. Neither manuscript reports the table: its
# counts do not reconcile with Session-4 attendance and must not be treated as an
# attrition mechanism.
#
# SOURCE & KEY FIELDS
# -------------------
# data/raw data/behavioural data from lab sessions/Session {2,3,4,6}/subject-*.csv
# One CSV = one participant's run of one session (OpenSesame long log). Inspection
# of these logs established how the gate is actually recorded:
#
#   * test_passed : the TERMINAL gate flag, written once the post-training test is
#                   scored. Its per-file value(s), read in row order, encode the
#                   whole attempt history:
#                       "yes"          -> passed on the FIRST attempt
#                       "no" -> "yes"  -> failed attempt 1, then PASSED attempt 2
#                       "no"           -> failed BOTH attempts -> FAILED the gate
#     (Cross-tabulating this against the test_attempt markers below confirms the
#      mapping: every "no"->... file also carries a 2nd-attempt marker, and no
#      "yes"-only file does.)
#
#   * test_attempt (values 1 / 2) : marks which attempt a test block belongs to. It is
#                   carried on every row of a test block and is empty on the experiment
#                   rows. This script never reads it; it served only in the manual
#                   reconnaissance that established the test_passed mapping above.
#
#   * correct_grammaticality_judgement_response (0/1) and grammatical_property :
#                   the per-trial judgements of the ERP EXPERIMENT block. Both are
#                   empty on the test-block rows, where the scoring is instead carried
#                   by `correct` (0/1 per trial) and `acc` (the running percentage).
#                   The first is used below only as a "this file holds scored
#                   judgements at all" flag, so `has_test` is not specific to the
#                   post-training test.
#
# The PASS/FAIL DECISION itself is recorded only at the session (aggregate) level via
# test_passed, and there is no per-property gate flag, so the reconstruction below is
# per SESSION, not per property (see the 'note' column).
#
# WHAT CAN AND CANNOT BE RECONSTRUCTED
# ------------------------------------
#   CAN  : per session -- n_attempted, n_passed_attempt1, n_passed_attempt2,
#          n_failed_gate, derived cleanly from test_passed.
#   CANNOT (cleanly):
#     - A per-GRAMMATICAL-PROPERTY gate. The gate is applied on the aggregate test
#       for the session, so grammatical_property is left as "ALL" here.
#     - Session 6 gate flow. Session 6 is the post-consolidation RETENTION session.
#       Its logs carry no test_passed value, no 2nd-attempt markers and in fact no test
#       block at all (the only session_part values are "Experiment" and "Gender
#       assignment task"), so there was no >80% gate at Session 6. n_attempted for that
#       row therefore counts subjects with scored judgements in the ERP experiment
#       block, and pass/fail counts are left at 0 rather than invented. The note
#       written into the CSV still calls this "subjects with a completed post-training
#       test", which overstates what the number is.
#
# SPLIT / NON-STANDARD FILES
# --------------------------
# A few Session-4 participants have their run split across files (e.g.
# subject-6-test.csv + subject-6-experiment.csv, subject-15-test.csv, subject-20-
# test.csv). The gate outcome lives in whichever of a subject's files carries a
# non-empty test_passed. We therefore key by SUBJECT NUMBER and pool a subject's
# files within a session, taking the gate signal from the file(s) that have it.
# The transient '*.filepart' (an incomplete download) is ignored.
#
# Two Session-4 logs (participants 3 and 5) were re-saved by hand in a spreadsheet after
# the session: they are semicolon-delimited and unquoted, and their opensesame_version
# field reads 03.03.2014 where OpenSesame wrote 3.3.14 in every other log, whereas every
# other logfile in the study is the comma-delimited, quoted file OpenSesame wrote. The
# original exports are not in the repository (ISSUES.md, X5-03). The comma-delimited
# reader below returns a single unnamed column for them, so neither test_passed nor the
# judgement column is found, they are classified 'no_data', and they drop out of the
# Session-4 counts altogether. Session 4 has data for 56 subjects, but n_attempted
# reports 54. Sniffing the delimiter per file would change the reported counts, so the
# reader is left as it is and the gap is recorded here instead.
#
# OUTPUT (written to BOTH papers)
# -------------------------------
# paper_1_transfer/results/_training_gate_flow.csv
# paper_2_plasticity/results/_training_gate_flow.csv
#   Columns: session, grammatical_property, n_attempted, n_passed_attempt1,
#            n_passed_attempt2, n_failed_gate, note
#
# Idempotent: re-running fully regenerates both CSVs.
# =============================================================================

suppressWarnings(suppressMessages({
  library(dplyr)
  library(readr)
  library(stringr)
}))

# --- Shared infrastructure ----------------------------------------------------
if (!exists("data_path"))             source(here::here("_shared", "R", "00_paths.R"))
if (!exists("behavioural_lab_path"))  source(here::here("_shared", "R", "03_data_manifest.R"))

GATE_THRESHOLD_PCT <- 80         # pre-registered pass mark (> 80%)
# The sessions reconstructed are the ERP sessions, LES_ERP_SESSIONS in the manifest. The
# training sessions carry the post-training test; the last ERP session is the retention
# session, which has none (see WHAT CAN AND CANNOT BE RECONSTRUCTED).
GATED_SESSIONS <- utils::head(LES_ERP_SESSIONS, -1L)   # Sessions 2, 3 and 4

#' Gate signal of one OpenSesame logfile
#'
#' @param path Path of one subject-*.csv logfile.
#' @return A one-row tibble: subject (integer, from the file name), has_test (any scored
#'   grammaticality judgements present, whichever block they came from), tp_seq (the
#'   run-length sequence of the test_passed values in row order: "yes", "no->yes", "no",
#'   or NA when the file records no gate outcome) and has_tp_column (whether the file has
#'   a test_passed column at all). A file the reader cannot parse yields has_test = FALSE,
#'   tp_seq = NA and has_tp_column = FALSE, which classify_gate() reports as "no_data".
read_gate_signal <- function(path) {
  df <- tryCatch(
    suppressWarnings(suppressMessages(
      read_csv(path, col_types = cols(.default = col_character()), progress = FALSE)
    )),
    error = function(e) NULL
  )
  subj <- suppressWarnings(as.integer(str_extract(basename(path), "\\d+")))
  if (is.null(df)) {
    return(tibble(subject = subj, has_test = FALSE, tp_seq = NA_character_,
                  has_tp_column = FALSE))
  }

  # Terminal gate flag, read in row order, collapsed to its run-length sequence.
  tp_seq <- NA_character_
  if ("test_passed" %in% names(df)) {
    tp <- df[["test_passed"]]
    tp <- tp[!is.na(tp) & tp != ""]
    if (length(tp) > 0) tp_seq <- paste(rle(tp)$values, collapse = "->")
  }

  # Did this file contain any scored grammaticality judgements? The column is populated
  # on the experiment-block rows and is empty on the test-block rows, so this is not
  # specific to the post-training test (see SOURCE & KEY FIELDS in the header).
  has_test <- FALSE
  if ("correct_grammaticality_judgement_response" %in% names(df)) {
    j <- df[["correct_grammaticality_judgement_response"]]
    has_test <- any(!is.na(j) & j != "")
  }

  tibble(subject = subj, has_test = has_test, tp_seq = tp_seq,
         has_tp_column = "test_passed" %in% names(df))
}

#' Gate outcome of one subject in one session, pooled over the subject's files
#'
#' We take the single most informative signal: a file that reached a pass ("...->yes" or
#' "yes") dominates a file that only recorded a fail, because the pass is the later,
#' terminal event.
#'
#' @param tp_seqs Character vector, the tp_seq of each of the subject's files in the
#'   session (NA where a file records no outcome).
#' @param any_test Logical scalar, whether any of those files holds scored judgements.
#' @return One of five labels, by precedence: "passed_attempt2" (a sequence ending in
#'   "yes" after a "no"), "passed_attempt1" (a "yes" alone), "failed_gate" ("no" alone),
#'   "completed_test_no_gate" (scored judgements but no recorded outcome), and "no_data"
#'   (neither). Any other recorded sequence also falls through to
#'   "completed_test_no_gate", so an unexpected value is never read as a pass or a fail.
classify_gate <- function(tp_seqs, any_test) {
  seqs <- tp_seqs[!is.na(tp_seqs)]
  if (length(seqs) == 0) {
    # No gate outcome recorded at all.
    return(if (any_test) "completed_test_no_gate" else "no_data")
  }
  passed_first  <- any(seqs == "yes")
  passed_second <- any(str_detect(seqs, "->\\s*yes$") | str_detect(seqs, "no->yes"))
  failed_only   <- any(seqs == "no")

  if (passed_second) return("passed_attempt2")   # failed attempt 1, passed attempt 2
  if (passed_first)  return("passed_attempt1")   # passed on first attempt
  if (failed_only)   return("failed_gate")       # only "no": failed both attempts
  "completed_test_no_gate"
}

#' Gate counts of one session
#'
#' @param sess Session number, one of LES_ERP_SESSIONS.
#' @return A one-row tibble with the columns of the written table (see OUTPUT).
#' @details Reads every subject-*.csv logfile of the session (behavioural_lab_path()),
#'   pooling a subject's files. Stops when no logfile of a training session
#'   (GATED_SESSIONS) has a test_passed column, because a renamed or missing flag would
#'   otherwise write that session up as a gate-free retention session with no error.
session_flow <- function(sess) {
  dir <- behavioural_lab_path(paste0("Session ", sess))
  files <- list.files(dir, pattern = "^subject-.*\\.csv$", full.names = TRUE)
  # Drop transient partial downloads.
  files <- files[!str_detect(files, "\\.filepart$")]

  sig <- bind_rows(lapply(files, read_gate_signal)) %>%
    filter(!is.na(subject))
  if (sess %in% GATED_SESSIONS && !any(sig$has_tp_column)) {
    stop("[00d] no Session-", sess, " logfile has a test_passed column; the gate flag ",
         "may have been renamed. Check the logs before reading this session as gate-free.",
         call. = FALSE)
  }

  # Pool a subject's files (handles split test/experiment logs).
  per_subject <- sig %>%
    group_by(subject) %>%
    summarise(
      any_test = any(has_test),
      outcome  = classify_gate(tp_seq, any(has_test)),
      .groups  = "drop"
    )

  n_subjects   <- nrow(per_subject)
  n_pass1      <- sum(per_subject$outcome == "passed_attempt1")
  n_pass2      <- sum(per_subject$outcome == "passed_attempt2")
  n_failed     <- sum(per_subject$outcome == "failed_gate")
  n_no_gate    <- sum(per_subject$outcome == "completed_test_no_gate")
  n_gated      <- n_pass1 + n_pass2 + n_failed

  # Compose an honest, session-specific note.
  if (n_gated > 0) {
    # n_attempted counts every subject with an interpretable gate outcome. A few
    # subjects completed the test but their terminal 'test_passed' flag was never
    # written (a logging gap); they cannot be classified as pass/fail, so they are
    # surfaced in the note rather than silently folded into a pass/fail bucket.
    note <- paste0(
      "Gate reconstructed from terminal 'test_passed' flag (>", GATE_THRESHOLD_PCT,
      "% to pass, max 2 attempts). Session-level (aggregate) gate; not resolvable ",
      "per grammatical property. n_attempted = subjects with an interpretable gate ",
      "outcome (pass1 + pass2 + failed)."
    )
    if (n_no_gate > 0) {
      note <- paste0(
        note, " Additionally, ", n_no_gate,
        " subject(s) completed the test but no 'test_passed' flag was logged; their ",
        "gate outcome is unrecoverable and they are excluded from the counts above."
      )
    }
    n_attempted <- n_gated
  } else {
    note <- paste0(
      "Retention session: logs carry no 'test_passed' gate flag and no 2nd-attempt ",
      "markers, i.e. no >", GATE_THRESHOLD_PCT, "% gate was applied at this session. ",
      "n_attempted = subjects with a completed post-training test; pass/attempt ",
      "counts are not defined (left 0) rather than fabricated."
    )
    n_attempted <- n_no_gate
  }

  tibble(
    session              = sess,
    grammatical_property = "ALL",
    n_attempted          = n_attempted,
    n_passed_attempt1    = n_pass1,
    n_passed_attempt2    = n_pass2,
    n_failed_gate        = n_failed,
    note                 = note
  )
}

message("[00d] reconstructing training-gate flow for sessions ",
        paste(LES_ERP_SESSIONS, collapse = ", "))
flow <- bind_rows(lapply(LES_ERP_SESSIONS, session_flow))

# --- Write to BOTH papers -----------------------------------------------------
out_paths <- c(
  paper1_results("_training_gate_flow.csv"),
  paper2_results("_training_gate_flow.csv")
)
les_assert_readonly_data(out_paths)   # never write inside read-only data/
for (p in out_paths) {
  write_csv(flow, p)
  message("[00d] wrote: ", p)
}

# --- Report -------------------------------------------------------------------
cat("\n===== Training-gate flow (per session) =====\n")
print(as.data.frame(flow[, c("session", "n_attempted", "n_passed_attempt1",
                             "n_passed_attempt2", "n_failed_gate")]))
cat("\nnotes:\n")
for (i in seq_len(nrow(flow))) {
  cat(sprintf("  Session %d: %s\n", flow$session[i], flow$note[i]))
}
cat("\n[00d] done.\n")
