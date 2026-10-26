# =============================================================================
# 00b_audit_participant_flow.R
# -----------------------------------------------------------------------------
# PURPOSE
# Build a per-participant x per-stage presence matrix for the whole longitudinal
# pipeline, and check it for logical inconsistencies. Writes
#   results/_participant_matrix.csv   one row per participant, one column per stage
#   results/_flow_inconsistencies.csv one row per detected inconsistency
# to BOTH papers' results directories, because the cohort is shared.
#
# ORDER
# Run it after 00_extract_participants.R, on the same store (hpc/00_descriptives.slurm
# runs it last). Check (8) compares the matrix with Paper 1's results/_sample_flow.csv,
# which that script writes. The check is skipped without a message when the file is
# absent, and otherwise uses whatever copy is on disk.
#
# WHY
# The counts reported in the participant-flow figure are stage TOTALS. A total can
# be correct while the underlying membership is not: a participant can appear in an
# analysis without an attendance record, attendance can be non-monotonic, or the
# language assignment recorded in the key can disagree with the parity rule the
# extraction scripts use to derive it. None of that is visible in a count, so it is
# checked per participant here.
#
# WHAT THE CHECKS CAN AND CANNOT SEE
# The usable-data stages are taken from les_flow_stage_ids() in
# 00_extract_participants.R, the one definition both scripts use, so this audit cannot
# disagree with the flow about what a stage means. Until October 2026 it kept its own
# copy of those criteria, which could drift from 00's and in two cases already had (the
# accuracy file set and the resting-state stage; ISSUES.md, G04-06 and G04-14). The audit
# therefore checks membership against attendance, identity and language, and check (8)
# detects a _sample_flow.csv that no longer matches the inputs on disk, which is how the
# stale flow of September 2026 arose (ISSUES.md, N12). It does not test whether the
# criteria themselves are right. The manuscripts' notes on individual participants in the
# flow (such as the participant who missed Session 5 and returned for Session 6) report
# what this audit finds, so re-check them whenever _flow_inconsistencies.csv changes.
#
# GROUND TRUTH
# `data/Participant IDs and session progress.csv` carries one row per participant
# with a date per attended session. A non-empty date is taken as attendance; this is
# the same source the flow artefact uses, so the two are directly comparable.
# data/ is read-only and is only read here.
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "03_data_manifest.R"))
  # les_flow_stage_ids(); sourcing runs nothing, because the script guards its entry point.
  source(here::here("paper_1_transfer", "scripts", "00_extract_participants.R"))
  library(dplyr)
})

.blank <- function(x) is.na(x) | trimws(as.character(x)) == ""

#' One row per participant in the key, with attendance and per-stage presence flags
#'
#' Takes no arguments.
#' @return A data frame sorted by participant_lab_ID, holding the key rows that carry an
#'   integer lab ID, with columns participant_lab_ID (integer), participant_home_ID and
#'   language_recorded (character), attended_S1 to attended_S6 (logical, NA when the key
#'   has no date column for that session), and the logical stage flags usable_accuracy,
#'   battery_baseline, trajectory, joint_predictor, usable_erp and usable_rseeg. A stage
#'   whose input has not been built is NA for everyone.
#' @details Reads the participant key (participant_key_csv()) and, through
#'   les_flow_stage_ids() in 00_extract_participants.R, the derived files the flow counts.
les_participant_matrix <- function() {

  key <- utils::read.csv(participant_key_csv(),
                         stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM",
                         check.names = TRUE)
  names(key)[1] <- sub("^X\\.U\\.FEFF\\.", "", names(key)[1])

  m <- data.frame(
    participant_lab_ID  = suppressWarnings(as.integer(key$participant_lab_ID)),
    participant_home_ID = as.character(key$participant_home_ID),
    language_recorded   = as.character(key$language),
    stringsAsFactors = FALSE
  )
  # The spreadsheet carries trailing blank rows below the last participant. They are
  # not participants and must be dropped before anything is counted or checked,
  # otherwise every per-participant check fires once per empty row.
  n_blank <- sum(is.na(m$participant_lab_ID))
  if (n_blank) message("[flow-audit] dropped ", n_blank, " blank row(s) from the participant key.")
  m <- m[!is.na(m$participant_lab_ID), , drop = FALSE]
  key <- key[!is.na(suppressWarnings(as.integer(key$participant_lab_ID))), , drop = FALSE]
  # Attendance: a session counts as attended when its date cell is non-empty.
  for (s in 1:6) {
    col <- grep(paste0("^Session", s, "_date"), names(key), value = TRUE)[1]
    m[[paste0("attended_S", s)]] <- if (is.na(col)) NA else !.blank(key[[col]])
  }

  # ---- Data presence per analysis stage --------------------------------------
  # The same membership the flow counts (les_flow_stage_ids()); NA throughout for a stage
  # whose input has not been built. The columns keep the order the matrix has always had.
  stage_ids <- les_flow_stage_ids()
  for (st in c("usable_accuracy", "usable_erp", "battery_baseline", "trajectory",
               "joint_predictor", "usable_rseeg")) {
    m[[st]] <- if (is.null(stage_ids[[st]])) NA else
      m$participant_lab_ID %in% suppressWarnings(as.integer(stage_ids[[st]]))
  }

  m[order(m$participant_lab_ID), ]
}

# -----------------------------------------------------------------------------
# Consistency checks. Each returns zero or more rows describing a violation.
# -----------------------------------------------------------------------------

#' Check the participant matrix for logical inconsistencies
#'
#' @param m The data frame les_participant_matrix() returns. The checks use its columns
#'   participant_lab_ID, participant_home_ID, language_recorded, attended_S1 to
#'   attended_S6 and the stage flags usable_accuracy, usable_erp, battery_baseline,
#'   trajectory and usable_rseeg, and check (8) compares every column of `m` named after a
#'   stage in _sample_flow.csv.
#' @return A data frame with columns check, severity ("error", "warning" or "info"),
#'   participant_lab_ID (NA on the stage-level rows of check (8)) and detail, with zero
#'   rows when no check fires.
#' @details Beyond `m` it reads LES_ERP_SESSIONS from the data manifest, Paper 2's
#'   learning_trajectory.rds for check (7) and Paper 1's results/_sample_flow.csv for check
#'   (8). Each of those two checks is skipped without a message when its file is absent.
#'   The file check (8) reads is written by 00_extract_participants.R, which is why the
#'   script runs after it (see ORDER in the header).
les_flow_inconsistencies <- function(m) {
  out <- list()
  add <- function(check, ids, detail, severity = "warning") {
    if (!length(ids)) return(invisible(NULL))
    out[[length(out) + 1]] <<- data.frame(
      check = check, severity = severity,
      participant_lab_ID = ids, detail = detail, stringsAsFactors = FALSE)
  }

  # (1) Data without attendance. An analysis stage that contains a participant who
  #     never attended the session producing it cannot be right.
  erp_attendance <- paste0("attended_S", LES_ERP_SESSIONS)
  stage_needs <- list(
    usable_accuracy  = erp_attendance,
    usable_erp       = erp_attendance,
    battery_baseline = "attended_S1",
    usable_rseeg     = "attended_S2",
    trajectory       = erp_attendance
  )
  for (st in names(stage_needs)) {
    if (all(is.na(m[[st]]))) next
    any_att <- Reduce(`|`, lapply(stage_needs[[st]], function(a) m[[a]] %in% TRUE))
    bad <- m$participant_lab_ID[m[[st]] %in% TRUE & !any_att]
    add(paste0("data_without_attendance:", st), bad,
        paste0("present in ", st, " but attended none of: ",
               paste(stage_needs[[st]], collapse = "/")), "error")
  }

  # (2) Non-monotonic attendance: a gap followed by a return. Not impossible in a
  #     longitudinal study, but it breaks the subset reading a funnel implies, so a
  #     flow diagram must not present these stages as nested.
  att <- as.matrix(m[, paste0("attended_S", 1:6)])
  gap_return <- apply(att, 1, function(r) {
    r <- r %in% TRUE
    if (!any(r)) return(FALSE)
    any(diff(which(r)) > 1)
  })
  add("non_monotonic_attendance", m$participant_lab_ID[gap_return],
      "attended a later session after missing an earlier one", "info")

  # (3) Language assignment. The extraction scripts derive mini-language from lab-ID
  #     parity (odd = Mini-English). If the recorded language disagrees, every
  #     language-based grouping downstream is wrong for that participant.
  parity <- ifelse(m$participant_lab_ID %% 2 == 1, "Mini-English", "Mini-Norwegian")
  mismatch <- !.blank(m$language_recorded) & m$language_recorded != parity
  add("language_parity_mismatch", m$participant_lab_ID[mismatch],
      "recorded language disagrees with the odd/even lab-ID rule used downstream", "error")

  # (4) Identity integrity.
  add("duplicate_lab_ID", unique(m$participant_lab_ID[duplicated(m$participant_lab_ID)]),
      "lab ID appears more than once in the participant key", "error")
  dup_home <- m$participant_home_ID[duplicated(m$participant_home_ID) &
                                      !.blank(m$participant_home_ID)]
  add("duplicate_home_ID", m$participant_lab_ID[m$participant_home_ID %in% dup_home],
      "home ID maps to more than one lab ID", "error")
  add("missing_lab_ID", which(is.na(m$participant_lab_ID)),
      "row in the participant key has no usable lab ID", "error")

  # (5) Enrolled but contributing nothing: attended no session at all.
  none <- !Reduce(`|`, lapply(paste0("attended_S", 1:6), function(a) m[[a]] %in% TRUE))
  add("enrolled_no_attendance", m$participant_lab_ID[none],
      "in the participant key but no session date recorded", "info")

  # (6) ERP data but no behavioural data, and vice versa. The two are collected on
  #     the SAME trials, so a participant in one and not the other needs explaining.
  if (!all(is.na(m$usable_erp))) {
    add("erp_without_accuracy",
        m$participant_lab_ID[m$usable_erp %in% TRUE & !(m$usable_accuracy %in% TRUE)],
        "has usable ERP data but no usable grammaticality-judgement data", "warning")
    add("accuracy_without_erp",
        m$participant_lab_ID[m$usable_accuracy %in% TRUE & !(m$usable_erp %in% TRUE)],
        "has usable judgement data but no usable ERP data", "warning")
  }

  # (7) Cognitive predictors missing at fit time (Paper 2). The joint-predictor
  #     flow stage counts participants with BOTH a battery and a trajectory, but the
  #     joint model listwise-deletes on the complete predictor set, so a participant
  #     with any NA cognitive predictor is in the stage yet absent from the fit
  #     (e.g. a baseline Stroop below the minimum-observation rule). The IDs are
  #     recorded here so that the stage-versus-fitted gap has a documented source.
  traj_path <- paper2_derived("learning_trajectory.rds")
  if (file.exists(traj_path)) {
    tr <- readRDS(traj_path)
    cogcols <- intersect(c("z_digit_span", "z_stroop", "z_asrt"), names(tr))
    if (length(cogcols)) {
      per <- stats::aggregate(tr[cogcols], by = list(participant_lab_ID = tr$participant_lab_ID),
                              FUN = function(x) any(is.na(x)))
      bad <- per$participant_lab_ID[Reduce(`|`, per[cogcols])]
      add("incomplete_predictor_set",
          bad,
          paste("has a learning trajectory but at least one missing cognitive predictor,",
                "so listwise deletion removes them from the Paper 2 joint predictor model"),
          "info")
    }
  }

  # (8) Reconciliation against the shipped flow artefact. Both apply les_flow_stage_ids(),
  #     so a disagreement means _sample_flow.csv was written from other inputs than the
  #     ones on disk now (a stale or hand-edited flow), not that a criterion is wrong.
  #     A stage the matrix cannot evaluate, because its input is not built here, is
  #     reported as unverifiable rather than read as zero. Recorded with
  #     participant_lab_ID = NA because it is a property of the stage, not of a participant.
  fl_path <- paper1_results("_sample_flow.csv")
  stage_row <- function(check, severity, detail) {
    out[[length(out) + 1]] <<- data.frame(check = check, severity = severity,
                                          participant_lab_ID = NA_integer_, detail = detail,
                                          stringsAsFactors = FALSE)
  }
  if (file.exists(fl_path)) {
    fl <- utils::read.csv(fl_path, stringsAsFactors = FALSE)
    for (st in intersect(fl$stage, names(m))) {
      ship <- fl$n_total[fl$stage == st][1]
      if (all(is.na(m[[st]]))) {
        if (!is.na(ship))
          stage_row("flow_stage_unverifiable", "warning",
                    sprintf("stage '%s': _sample_flow.csv gives %d, but its input is not built here",
                            st, ship))
        next
      }
      mine <- sum(m[[st]] %in% TRUE)
      if (is.na(ship) || ship != mine)
        stage_row("flow_total_mismatch", "error",
                  sprintf("stage '%s': participant matrix gives %d, _sample_flow.csv gives %s",
                          st, mine, if (is.na(ship)) "NA" else as.character(ship)))
    }
  }

  if (!length(out)) return(data.frame(check = character(), severity = character(),
                                      participant_lab_ID = integer(), detail = character()))
  do.call(rbind, out)
}

#' Build the participant matrix and its inconsistency table, and write both to both papers
#'
#' Takes no arguments.
#' @return list(matrix, inconsistencies), invisibly.
#' @details Writes _participant_matrix.csv and _flow_inconsistencies.csv to both papers'
#'   results/ folders (paper1_results() and paper2_results()), four files in all, each
#'   through les_assert_readonly_data(). Neither manuscript reads them.
les_write_flow_audit <- function() {
  m <- les_participant_matrix()
  inc <- les_flow_inconsistencies(m)
  for (f in c(paper1_results("_participant_matrix.csv"),
              paper2_results("_participant_matrix.csv"))) {
    les_assert_readonly_data(f); utils::write.csv(m, f, row.names = FALSE)
  }
  for (f in c(paper1_results("_flow_inconsistencies.csv"),
              paper2_results("_flow_inconsistencies.csv"))) {
    les_assert_readonly_data(f); utils::write.csv(inc, f, row.names = FALSE)
  }
  message(sprintf("[flow-audit] %d participants; %d inconsistency row(s) across %d check(s)",
                  nrow(m), nrow(inc), length(unique(inc$check))))
  invisible(list(matrix = m, inconsistencies = inc))
}

if (sys.nframe() == 0L) les_write_flow_audit()
