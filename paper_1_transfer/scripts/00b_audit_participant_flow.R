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
# WHY
# The counts reported in the participant-flow figure are stage TOTALS. A total can
# be correct while the underlying membership is not: a participant can appear in an
# analysis without an attendance record, attendance can be non-monotonic, or the
# language assignment recorded in the key can disagree with the parity rule the
# extraction scripts use to derive it. None of that is visible in a count, so it is
# checked per participant here.
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
  library(dplyr)
})

.blank <- function(x) is.na(x) | trimws(as.character(x)) == ""

les_participant_matrix <- function() {

  key <- utils::read.csv(data_path("Participant IDs and session progress.csv"),
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
  present <- function(ids) m$participant_lab_ID %in% suppressWarnings(as.integer(as.character(ids)))

  acc_ids <- unique(unlist(lapply(
    list.files(paper1_derived(), pattern = "^accuracy_.*\\.rds$", full.names = TRUE),
    function(f) as.character(readRDS(f)$participant_lab_ID))))
  m$usable_accuracy <- present(acc_ids)

  # Presence anywhere in the per-cell retained-trial table. 00_extract_participants.R
  # first restricts that table to the modelled Grammatical/Ungrammatical rows. The two
  # criteria currently pick out the same 63 participants, so the flow_total_mismatch
  # check below compares like with like, but they are not identical by construction:
  # a participant contributing only ancillary-violation cells would count here and not
  # there.
  erp_f <- data_path("EEG_trial_count_per_condition.csv")
  m$usable_erp <- if (file.exists(erp_f))
    present(unique(utils::read.csv(erp_f, stringsAsFactors = FALSE)$participant_lab_ID)) else NA

  # These stages use the SAME usability criteria as 00_extract_participants.R, not mere
  # presence in a file. Counting presence over-states them (by 1 and 3 respectively),
  # because a participant can appear in a derived file without meeting the criterion the
  # models actually apply. Replicating the criteria is what makes the comparison against
  # the flow artefact a genuine cross-check rather than a category error.
  .rds <- function(file) { f <- paper2_derived(file); if (file.exists(f)) readRDS(f) else NULL }

  ci <- .rds("cognitive_indices.rds")
  cog_ids_s1 <- character(0)
  if (!is.null(ci) && "participant_lab_ID" %in% names(ci)) {
    ci1 <- ci[ci$session %in% 1, , drop = FALSE]
    idx <- intersect(c("stroop_interference", "digit_span", "asrt_learning"), names(ci1))
    cog_ids_s1 <- as.character(unique(ci1$participant_lab_ID[rowSums(!is.na(ci1[idx])) > 0]))
  }
  tj <- .rds("learning_trajectory.rds")
  traj_ids <- if (!is.null(tj)) {
    idc <- intersect(c("participant_lab_ID", "participant_home_ID"), names(tj))[1]
    if (!is.na(idc)) as.character(unique(tj[[idc]])) else character(0)
  } else character(0)
  joint_ids <- intersect(cog_ids_s1, traj_ids)

  rs <- .rds("resting_state_eeg.rds")
  rs_ids <- character(0)
  if (!is.null(rs) && "participant_lab_ID" %in% names(rs)) {
    if ("condition" %in% names(rs))
      rs <- rs[grepl("closed", rs$condition, ignore.case = TRUE), , drop = FALSE]
    bnd <- intersect(c("delta", "theta", "alpha", "beta", "gamma", "iaf"), names(rs))
    if (length(bnd)) rs <- rs[stats::complete.cases(rs[, bnd, drop = FALSE]), , drop = FALSE]
    rs_ids <- intersect(as.character(unique(rs$participant_lab_ID)), joint_ids)
  }

  m$battery_baseline <- present(cog_ids_s1)
  m$trajectory       <- present(traj_ids)
  m$joint_predictor  <- present(joint_ids)
  m$usable_rseeg     <- present(rs_ids)

  m[order(m$participant_lab_ID), ]
}

# -----------------------------------------------------------------------------
# Consistency checks. Each returns zero or more rows describing a violation.
# -----------------------------------------------------------------------------
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
  stage_needs <- list(
    usable_accuracy  = c("attended_S2", "attended_S3", "attended_S4", "attended_S6"),
    usable_erp       = c("attended_S2", "attended_S3", "attended_S4", "attended_S6"),
    battery_baseline = "attended_S1",
    usable_rseeg     = "attended_S2",
    trajectory       = c("attended_S2", "attended_S3", "attended_S4", "attended_S6")
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
  dup_home <- m$participant_home_ID[duplicated(m$participant_home_ID) & !.blank(m$participant_home_ID)]
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
    add("erp_without_accuracy", m$participant_lab_ID[m$usable_erp %in% TRUE & !(m$usable_accuracy %in% TRUE)],
        "has usable ERP data but no usable grammaticality-judgement data", "warning")
    add("accuracy_without_erp", m$participant_lab_ID[m$usable_accuracy %in% TRUE & !(m$usable_erp %in% TRUE)],
        "has usable judgement data but no usable ERP data", "warning")
  }

  # (7) Cognitive predictors missing at fit time (Paper 2). The joint-predictor
  #     flow stage counts participants with BOTH a battery and a trajectory, but the
  #     joint model listwise-deletes on the complete predictor set, so a participant
  #     with any NA cognitive predictor is in the stage yet absent from the fit
  #     (e.g. a baseline Stroop below the minimum-observation rule). Recording the
  #     IDs here is what lets the manuscripts explain the stage-vs-fitted gap.
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

  # (8) Reconciliation against the shipped flow artefact. The per-participant matrix and
  #     _sample_flow.csv are produced by different code from different sources, so a
  #     disagreement means one of them is wrong. Recorded with participant_lab_ID = NA
  #     because it is a property of the stage, not of a participant.
  fl_path <- paper1_results("_sample_flow.csv")
  if (file.exists(fl_path)) {
    fl <- utils::read.csv(fl_path, stringsAsFactors = FALSE)
    for (st in intersect(fl$stage, names(m))) {
      mine <- sum(m[[st]] %in% TRUE)
      ship <- fl$n_total[fl$stage == st][1]
      if (!is.na(ship) && ship != mine)
        out[[length(out) + 1]] <- data.frame(
          check = "flow_total_mismatch", severity = "error",
          participant_lab_ID = NA_integer_,
          detail = sprintf("stage '%s': participant matrix gives %d, _sample_flow.csv gives %d",
                           st, mine, ship), stringsAsFactors = FALSE)
    }
  }

  if (!length(out)) return(data.frame(check = character(), severity = character(),
                                      participant_lab_ID = integer(), detail = character()))
  do.call(rbind, out)
}

les_write_flow_audit <- function() {
  m <- les_participant_matrix()
  inc <- les_flow_inconsistencies(m)
  for (f in c(paper1_results("_participant_matrix.csv"), paper2_results("_participant_matrix.csv"))) {
    les_assert_readonly_data(f); utils::write.csv(m, f, row.names = FALSE)
  }
  for (f in c(paper1_results("_flow_inconsistencies.csv"), paper2_results("_flow_inconsistencies.csv"))) {
    les_assert_readonly_data(f); utils::write.csv(inc, f, row.names = FALSE)
  }
  message(sprintf("[flow-audit] %d participants; %d inconsistency row(s) across %d check(s)",
                  nrow(m), nrow(inc), length(unique(inc$check))))
  invisible(list(matrix = m, inconsistencies = inc))
}

if (sys.nframe() == 0L) les_write_flow_audit()
