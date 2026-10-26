# =============================================================================
# paper_1_transfer/scripts/02_extract_accuracy.R
# Phase 2a -- Build the analysis-ready grammaticality-judgement ACCURACY dataset
#              for Paper 1 (one tidy file per morphosyntactic property)
# =============================================================================
#
# WHAT THIS SCRIPT PRODUCES
# -------------------------
# For each target property it writes paper_1_transfer/data_derived/accuracy_<property>.rds,
# one row per scored grammaticality-judgement trial, carrying the binary response
# `correct` (the DV for the Bayesian logistic GLMMs in step 04) together with the
# sum-coded / standardised design predictors (grammaticality, session, language) and the
# item identity item_id (language x sentence trigger, as in the ERP data).
# With LES_P1_ACC_DIVERSITY=1 it additionally attaches and standardises the LHQ3
# multilingual language diversity score and writes accuracy_<property>_diversity.rds
# instead (see .les_acc_join_diversity below); the default output is untouched.
# The data keep every judgement trial with a finite, positive response time. With
# LES_P1_ACC_RT_SCREEN=1 it applies the legacy (200, 4000) ms reaction-time screen as well
# and writes accuracy_<property>_rtscreen.rds, the sensitivity analysis since 19 October
# 2026 (ISSUES.md G06-03; until then the screen was primary). Both switches together give
# _diversity_rtscreen.
# It also writes these tables to paper_1_transfer/results/, each carrying the same tags
# (les_p1_acc_data_tag()): _accuracy_input_gaps.csv (the logfiles the extraction cannot
# read), _accuracy_rt_screen.csv (a one-row count of the de-duplicated, otherwise-valid
# trials the response-time filter removes, with their share, the bounds applied and the
# number of duplicate log rows removed before it), _accuracy_rt_bands.csv (those
# otherwise-valid trials counted in the legacy screen's three bands, by property, language,
# session and grammaticality, with the number answered correctly) and
# _accuracy_sentence_inventory.csv (distinct sentences against judgement trials per
# session), _accuracy_item_inventory.csv (per property, the items the judgement trials
# share with the ERP and how often each was judged), plus _accuracy_by_language.csv
# (participant-balanced descriptive accuracy
# by miniature language, property, grammaticality and session),
# _accuracy_sdt_by_language.csv (the same participants' d' and criterion) and
# _accuracy_language_check.csv (the language each log records against the assigned
# group). Participants in LES_P1_PROTOCOL_DEVIATION (_config.R) are excluded from every
# output except the language check.
#
# WHY THE EXTRACTION IS RE-IMPLEMENTED RATHER THAN SOURCED
# --------------------------------------------------------
# The legacy `data/importation and preprocessing/import and preprocess behavioural
# data from lab sessions.R` is a non-functional fragment: its first pipeline ends
# with a trailing ` %>% ` immediately before a new `behavioural_lab_data <- ...`
# assignment, which is a parse/eval error. We therefore reproduce its *documented*
# preprocessing decisions here, in a read-only-respecting Paper 1 script, instead
# of sourcing the broken file. The reproduced decisions are:
#   * participant <-> language mapping by lab-ID parity (odd = Mini-English),
#   * de-duplication of repeated OpenSesame trial numbers,
#   * reaction-time filter 200-4000 ms, applied to the de-duplicated trials. Since 19 October
#     2026 it is applied only under LES_P1_ACC_RT_SCREEN=1, as a sensitivity analysis.
#
# IDENTIFYING THE JUDGEMENT TRIALS
# --------------------------------
# The grammaticality judgement is made *concurrently* with the ERP recording rather
# than in a separate behavioural test. Inspection of the raw OpenSesame logfiles shows
# that every row carrying an explicit `grammatical_property` inside the Experiment
# block is a concurrent ERP trial, and each such row also carries `correct` and
# `response_time` for that same trial. The mapping is not an identity, though, which is
# why both filters below are needed:
#   * The ancillary "Test" rows (36 per session in Sessions 2-4) carry no property.
#     Session 6 has no test block but does have a "Gender assignment task" block whose
#     rows inherit stale OpenSesame property/trigger values from the final Experiment
#     trial, so they must be excluded on session_part or they would pass the property
#     filter as spurious Grammatical trials.
#   * Session 2 presents a further 96 unlabelled grammatical filler sentences per
#     participant. They sit in the Experiment block, carry no property and no sentence
#     trigger, and so are dropped by the property filter. They fall outside the
#     modelled Grammatical vs Ungrammatical contrast in any case. Sessions 3, 4 and 6
#     contain no such rows.
#
# TWO GAPS IN THE SESSION-4 INPUT (documented, not fixed here)
# -----------------------------------------------------------
# Both remove the affected participants from Session 4 silently:
#   * A few Session-4 runs are split across `subject-N-test.csv` and
#     `subject-N-experiment.csv` (participants 6 and 20). The `^subject-\\d+\\.csv$`
#     pattern used below does not match those names, so 6 and 20 contribute no
#     Session-4 trials. Script 00d reads the same files with the wider
#     `^subject-.*\\.csv$` and pools a subject's files.
#   * Two Session-4 logs (participants 3 and 5) were re-saved by hand in a spreadsheet
#     after the session: they are semicolon-delimited and unquoted, and their
#     opensesame_version field reads 03.03.2014 where OpenSesame wrote 3.3.14 in every
#     other log. Every other logfile in the study is the comma-delimited, quoted file
#     OpenSesame wrote, and the originals of these two are not in the repository
#     (ISSUES.md, X5-03). readr::read_csv() below is fixed to a comma, so those files
#     parse as one unnamed column, arrive with no `session_part`, and are dropped whole by
#     the Experiment filter.
# Widening the pattern or sniffing the delimiter would change the extracted data and
# every model fitted on it, so neither is done here.
#
# CONDITIONS ANALYSED
# -------------------
# To keep the grammaticality contrast identical to the ERP analysis (S101 vs S102),
# we model the canonical Grammatical vs Ungrammatical (gender/DOM/VOA) violation and
# drop the ancillary "number violation" / "article location violation" fillers.
#
# CUMULATIVE LONGITUDINAL DESIGN
# ------------------------------
# Each property is judged from its training session onward, mirroring the ERP:
# gender = Sessions 2,3,4,6; differential object marking = 3,4,6; verb-object number
# agreement = 4,6. `recoded_session` (0,1,2,3 for Sessions 2,3,4,6; Michael Clark's
# growth-curve time coding) is standardised WITHIN property so each model's session
# term spans that property's observed sessions.
#
# MODELLING NOTE (used by step 04)
# --------------------------------
# Trial-level accuracy is analysed with Bayesian mixed-effects LOGISTIC regression
# (Bernoulli), never with ANOVA on by-subject percentages, because the latter
# violates the binary nature of the data and inflates Type-I error (Jaeger, 2008,
# JML, https://doi.org/10.1016/j.jml.2007.11.007; Dixon, 2008,
# https://doi.org/10.1016/j.jml.2007.11.004).
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "03_data_manifest.R"))
  source(here::here("paper_1_transfer", "scripts", "_config.R"))
  library(dplyr)
  library(readr)
  library(stringr)
})

#' Standardise a vector (shared rationale with the ERP extraction)
#'
#' @param x Numeric vector.
#' @return x z-scored over all its values. An all-NA vector comes back as numeric NAs and
#'   a constant or single-valued one as zeros.
.les_scale <- function(x) {
  if (all(is.na(x))) return(as.numeric(x))
  s <- stats::sd(x, na.rm = TRUE)
  if (is.na(s) || s == 0) return(rep(0, length(x)))
  as.numeric(scale(x))
}

# Columns we keep from the (very wide) OpenSesame logfiles.
# `session_part` is needed to exclude the Session-6 "Gender assignment task" block
# (see IDENTIFYING THE JUDGEMENT TRIALS above); it must survive the intersect() subset.
# `language` and `experiment_file` are kept only for the provenance check in
# .les_write_language_check(): the group is still assigned by lab-ID parity, but a log
# that records the other miniature language is now reported rather than silently
# recoded (participant 14's Session 2 was, before September 2026; ISSUES.md X5-01).
# `sentence_trigger` is the code the EEG records as the sentence marker (110-253); with the
# language it gives item_id, the item factor the judgement trials share with the ERP.
.les_acc_cols <- c("correct", "response_time", "grammaticality",
                   "grammatical_property", "trial", "subject_nr", "session_part",
                   "language", "experiment_file", "sentence_trigger")

# The logged sentence, if the logfile carries one under this name. It feeds the sentence
# inventory below and is dropped before any derived file is written, so the modelled
# data are unchanged by it.
.les_acc_sentence_col <- "sentence"

#' Read one subject x session logfile, keeping only the needed columns
#'
#' @param file One logfile path.
#' @param session_label Its session number.
#' @return The file's rows with every kept column as character (those in .les_acc_cols
#'   that the file has, plus sentence_text when it logs a sentence), with the session and
#'   the integer participant_lab_ID parsed from the file name appended.
.read_one_logfile <- function(file, session_label) {
  df <- suppressWarnings(readr::read_csv(
    file, na = c("", "NA", "undefined"),
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE, progress = FALSE
  ))
  sent <- names(df)[tolower(names(df)) == .les_acc_sentence_col][1]
  df <- df[, intersect(names(df), c(.les_acc_cols, sent)), drop = FALSE]
  if (!is.na(sent)) names(df)[names(df) == sent] <- "sentence_text"
  df$session <- session_label
  # Lab ID from the file name (robust; matches the EEG participant_lab_ID space).
  df$participant_lab_ID <- as.integer(stringr::str_extract(basename(file), "(?<=subject-)[0-9]+"))
  df
}

# =============================================================================
# Opt-in covariate: LHQ3 multilingual language diversity (LES_P1_ACC_DIVERSITY=1)
# -----------------------------------------------------------------------------
# The ERP models carry a between-participant control named
# `z_multilingual_language_diversity` (03_fit_brms_erp.R), which holds the LHQ3 L1
# Dominance Score under a legacy name. The accuracy models do not, because the legacy
# behavioural import never joined the questionnaire. With LES_P1_ACC_DIVERSITY=1 the
# per-participant "Multilingual Language Diversity Score" is attached here from the
# LHQ3 Aggregate Scores export, matched by column NAME (as 00_extract_participants.R
# does for the demographics table) and linked to the lab ID through the participant
# key, and 04_fit_brms_accuracy.R adds it as a main effect. That is a different LHQ3
# score from the ERP control, although both enter their models under the name
# z_multilingual_language_diversity, so this variant does not mirror the ERP covariate.
# The switch writes its own derived files (accuracy_<property>_diversity.rds; see
# les_p1_accuracy_rds() in _config.R), so the default extraction and the reported fits
# are untouched. Trials of participants without a score keep NA and are dropped at fit
# time by listwise deletion. (The ERP extraction instead gives a participant without the
# L1-dominance score the participant mean; see 01_extract_erp_single_trials.R.)
# =============================================================================

#' Attach the LHQ3 Multilingual Language Diversity Score (LES_P1_ACC_DIVERSITY=1 only)
#'
#' @param acc The trial frame, with an integer participant_lab_ID.
#' @return acc with a numeric multilingual_language_diversity column added and the row
#'   count unchanged.
#' @details Reads participant_key_csv() and "LHQ3 Aggregate Scores.xlsx", and stops on
#'   duplicated IDs or a missing column.
.les_acc_join_diversity <- function(acc) {
  key <- suppressWarnings(readr::read_csv(participant_key_csv(), show_col_types = FALSE,
                                          progress = FALSE))
  key <- key[key$language %in% c("Mini-English", "Mini-Norwegian"), , drop = FALSE]
  map <- data.frame(participant_lab_ID  = as.integer(key$participant_lab_ID),
                    participant_LHQ3_ID = as.character(key$participant_LHQ3_ID),
                    stringsAsFactors = FALSE)
  if (anyDuplicated(map$participant_lab_ID))
    stop("[accuracy] duplicated lab IDs in the participant key; cannot attach LHQ3 scores")

  agg <- suppressMessages(readxl::read_excel(lhq3_path("LHQ3 Aggregate Scores.xlsx"), skip = 1))
  names(agg) <- trimws(names(agg))
  id_col  <- names(agg)[grepl("^Participant ID$", names(agg))][1]
  div_col <- names(agg)[grepl("Multilingual Language Diversity", names(agg), ignore.case = TRUE)][1]
  if (is.na(id_col) || is.na(div_col))
    stop("[accuracy] LHQ3 Aggregate Scores: participant-ID or diversity column not found")
  lhq3 <- data.frame(participant_LHQ3_ID = as.character(agg[[id_col]]),
                     multilingual_language_diversity = suppressWarnings(as.numeric(agg[[div_col]])),
                     stringsAsFactors = FALSE)
  lhq3 <- lhq3[!is.na(lhq3$participant_LHQ3_ID), , drop = FALSE]
  if (anyDuplicated(lhq3$participant_LHQ3_ID))
    stop("[accuracy] duplicated participant IDs in the LHQ3 aggregate export")

  map <- dplyr::left_join(map, lhq3, by = "participant_LHQ3_ID")
  n_before <- nrow(acc)
  acc <- dplyr::left_join(acc, map[, c("participant_lab_ID", "multilingual_language_diversity")],
                          by = "participant_lab_ID")
  stopifnot(nrow(acc) == n_before)
  have    <- !is.na(acc$multilingual_language_diversity)
  missing <- sort(unique(acc$participant_lab_ID[!have]))
  message(sprintf(
    paste0("[accuracy] LES_P1_ACC_DIVERSITY=1: diversity score attached for %d participants;",
           " missing for %d%s"),
    dplyr::n_distinct(acc$participant_lab_ID[have]), length(missing),
    if (length(missing)) paste0(" (lab ID ", paste(missing, collapse = ", "), ")") else ""))
  acc
}

# --- Census of unreadable logfiles -------------------------------------------
# Two file forms leave a participant-session out of the extraction: a run split across
# subject-N-test.csv and subject-N-experiment.csv, which the file pattern does not match,
# and a log re-saved by hand as semicolon-delimited (see the header), which the
# comma-delimited reader parses as one column and the Experiment filter then drops whole.
# Both are recorded here, one row per affected file, in results/_accuracy_input_gaps.csv.
# A suffixed file beside a plain subject-N.csv for the same participant and session is an
# unread extra export, not a gap, because the plain file carries that participant's run;
# it is recorded under its own reason so that the manuscript's count of lost participants
# excludes it.

#' Write the census of logfiles the extraction cannot read
#'
#' @param files The logfile paths the extraction reads.
#' @param sessions The session numbers whose folders are scanned.
#' @return The census (reason, file, session, participant_lab_ID), invisibly.
#' @details Writes results/_accuracy_input_gaps.csv, with the tags of
#'   les_p1_acc_data_tag(), through les_assert_readonly_data().
.les_write_input_gaps <- function(files, sessions) {
  all_files <- unlist(lapply(sessions, function(s) {
    list.files(behavioural_lab_path(paste("Session", s)),
               pattern = "^subject-.*\\.csv$", full.names = TRUE)
  }))
  unmatched <- setdiff(all_files, files)
  has_plain <- vapply(unmatched, function(f) {
    id <- stringr::str_extract(basename(f), "(?<=subject-)[0-9]+")
    file.exists(file.path(dirname(f), paste0("subject-", id, ".csv")))
  }, logical(1))
  split_files <- unmatched[!has_plain]
  extra_files <- unmatched[has_plain]
  is_semi <- vapply(files, function(f) {
    h <- readLines(f, n = 1L, warn = FALSE)
    lengths(regmatches(h, gregexpr(";", h, fixed = TRUE))) >
      lengths(regmatches(h, gregexpr(",", h, fixed = TRUE)))
  }, logical(1))
  gap_files <- c(split_files, files[is_semi], extra_files)
  gaps <- data.frame(
    reason  = c(rep("split_export", length(split_files)),
                rep("semicolon_delimited", sum(is_semi)),
                rep("unread_extra_export", length(extra_files))),
    file    = basename(gap_files),
    session = as.integer(stringr::str_extract(gap_files, "(?<=Session )[0-9]+")),
    participant_lab_ID = as.integer(stringr::str_extract(basename(gap_files),
                                                         "(?<=subject-)[0-9]+")),
    stringsAsFactors = FALSE)
  gap_path <- paper1_results(paste0("_accuracy_input_gaps", les_p1_acc_data_tag(), ".csv"))
  les_assert_readonly_data(gap_path)
  utils::write.csv(gaps, gap_path, row.names = FALSE)
  message(sprintf("[accuracy] input-gap census: %d split exports, %d semicolon-delimited logs",
                  length(split_files), sum(is_semi)))
  invisible(gaps)
}

# --- Log-recorded language against the assigned group ------------------------
# The group is assigned by lab-ID parity, which matches the participant key for every
# participant. What parity cannot see is a session run with the wrong experiment file,
# which is what happened to participant 14 at Session 2. This census compares the
# `language` column each OpenSesame log records with the assigned group, one row per
# participant x session, and writes results/_accuracy_language_check.csv (with the
# tags of les_p1_acc_data_tag()). status is "match", "mismatch" or
# "not_logged" (the semicolon-delimited logs carry no parsable column). It stops nothing:
# the treatment of a mismatch is a decision recorded in _config.R, and the census is what
# makes a new one visible.

#' Write the census of log-recorded language against the assigned group
#'
#' @param acc The trial frame, carrying language, experiment_file, mini_language, session
#'   and participant_lab_ID.
#' @return The census, invisibly.
#' @details Writes results/_accuracy_language_check.csv (tagged _diversity under the
#'   switch) and warns when a mismatch belongs to a participant with no recorded treatment.
.les_write_language_check <- function(acc) {
  if (!"language" %in% names(acc)) acc$language <- NA_character_
  if (!"experiment_file" %in% names(acc)) acc$experiment_file <- NA_character_
  chk <- acc %>%
    dplyr::group_by(participant_lab_ID, session, mini_language) %>%
    dplyr::summarise(
      logged_language = paste(sort(unique(stats::na.omit(language))), collapse = "|"),
      experiment_file = paste(sort(unique(basename(gsub("\\\\", "/",
                                                         stats::na.omit(experiment_file))))),
                              collapse = "|"),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      status = dplyr::case_when(
        logged_language == "" ~ "not_logged",
        logged_language == mini_language ~ "match",
        TRUE ~ "mismatch"
      ),
      excluded = participant_lab_ID %in% LES_P1_PROTOCOL_DEVIATION$participant_lab_ID
    ) %>%
    dplyr::arrange(participant_lab_ID, session)
  chk_path <- paper1_results(paste0("_accuracy_language_check", les_p1_acc_data_tag(), ".csv"))
  les_assert_readonly_data(chk_path)
  utils::write.csv(chk, chk_path, row.names = FALSE)
  n_mis <- sum(chk$status == "mismatch")
  message(sprintf("[accuracy] language check: %d participant-sessions, %d mismatch(es)%s",
                  nrow(chk), n_mis,
                  if (n_mis) paste0(" (lab ID ", paste(unique(chk$participant_lab_ID[chk$status == "mismatch"]),
                                                       collapse = ", "), ")") else ""))
  unexplained <- chk$status == "mismatch" & !chk$excluded
  if (any(unexplained)) {
    warning("[accuracy] a log records a language other than the assigned group for a ",
            "participant with no recorded treatment: lab ID ",
            paste(unique(chk$participant_lab_ID[unexplained]), collapse = ", "),
            ". Decide the treatment and record it in _config.R.", call. = FALSE)
  }
  invisible(chk)
}

# --- What the legacy reaction-time screen removes ----------------------------------
# The legacy screen (LES_P1_ACC_RT_MS) became the sensitivity analysis on 19 October 2026
# because it is not neutral (ISSUES.md G06-03). It removes the fastest and the slowest
# judgements, which differ in accuracy from the rest, and it removes unequal shares of the
# two groups' trials. This table records what it removes, counted over the de-duplicated
# trials before any response-time filter, so the Method reports that selection from an
# artefact. It holds counts only, with no participant identifiers.

#' Write the counts of judgement trials in the legacy screen's bands
#'
#' @param acc The de-duplicated trial frame inside build_paper1_accuracy(), before the
#'   response-time filter, carrying grammatical_property, mini_language, session,
#'   grammaticality, correct and response_time.
#' @return The table, invisibly.
#' @details Writes results/_accuracy_rt_bands.csv (with the tags of les_p1_acc_data_tag()),
#'   one row per property x mini_language x session x grammaticality x band, with n_trials
#'   and n_correct. The band is one of:
#'   * "no_time": no finite, positive response time, dropped under every rule;
#'   * "fast": at or below LES_P1_ACC_RT_MS[1];
#'   * "kept": strictly between the two bounds;
#'   * "slow": at or above LES_P1_ACC_RT_MS[2].
.les_write_rt_bands <- function(acc) {
  rt <- acc$response_time
  band <- ifelse(!is.finite(rt) | rt <= 0, "no_time",
          ifelse(rt <= LES_P1_ACC_RT_MS[1], "fast",
          ifelse(rt >= LES_P1_ACC_RT_MS[2], "slow", "kept")))
  tab <- acc %>%
    dplyr::mutate(band = band) %>%
    dplyr::group_by(grammatical_property, mini_language, session, grammaticality, band) %>%
    dplyr::summarise(n_trials = dplyr::n(), n_correct = sum(correct), .groups = "drop") %>%
    dplyr::arrange(grammatical_property, mini_language, session, grammaticality, band)
  path <- paper1_results(paste0("_accuracy_rt_bands", les_p1_acc_data_tag(), ".csv"))
  les_assert_readonly_data(path)
  utils::write.csv(as.data.frame(tab), path, row.names = FALSE)
  invisible(tab)
}

# =============================================================================
# Build and preprocess the pooled judgement dataset
# =============================================================================

#' The pooled, de-duplicated judgement trials
#'
#' Paper 2's 02_extract_learning_trajectory.R calls it as well.
#' @param write_side_files TRUE (the default) writes the four results files listed under
#'   details; FALSE writes none of them. Paper 2's trajectory extraction passes FALSE, so it
#'   never rewrites Paper 1's reported artefacts (ISSUES.md G10-02). The returned data are
#'   the same either way.
#' @return One row per de-duplicated scored judgement trial with a finite, positive response
#'   time (and, under LES_P1_ACC_RT_SCREEN=1, inside the legacy reaction-time screen),
#'   carrying the kept log columns, the lower-cased helper columns prop_lc and
#'   gram_lc, the recoded predictors recoded_grammaticality, recoded_mini_language and
#'   recoded_session, participant_lab_ID, session and mini_language as factors,
#'   sentence_text when the logs carry it, and multilingual_language_diversity under
#'   LES_P1_ACC_DIVERSITY=1. The predictors are standardised later, within each property,
#'   by .run().
#' @details Reads every subject-N.csv logfile of the sessions in LES_ERP_SESSIONS, and,
#'   under LES_P1_ACC_DIVERSITY=1, the participant key and the LHQ3 workbook. With
#'   write_side_files = TRUE it writes four Paper 1 results files:
#'   results/_accuracy_input_gaps.csv (.les_write_input_gaps()),
#'   results/_accuracy_language_check.csv (.les_write_language_check()),
#'   results/_accuracy_rt_bands.csv (.les_write_rt_bands()) and
#'   results/_accuracy_rt_screen.csv, each with the tags of les_p1_acc_data_tag().
build_paper1_accuracy <- function(write_side_files = TRUE) {

  sessions <- LES_ERP_SESSIONS                      # c(2, 3, 4, 6)
  files <- unlist(lapply(sessions, function(s) {
    list.files(behavioural_lab_path(paste("Session", s)),
               pattern = "^subject-\\d+\\.csv$", full.names = TRUE)
  }))
  if (!length(files)) stop("No behavioural logfiles found under ", behavioural_lab_path())

  # Census of the logfiles this extraction cannot read (see TWO GAPS IN THE SESSION-4
  # INPUT above), written so that the Method reports the participants concerned from an
  # artefact. The reader and the file pattern stay as they are, so the extracted data are
  # unchanged by it.
  if (write_side_files) .les_write_input_gaps(files, sessions)

  session_of <- as.integer(stringr::str_extract(files, "(?<=Session )[0-9]+"))

  message("[accuracy] reading ", length(files), " logfiles ...")
  raw <- dplyr::bind_rows(Map(.read_one_logfile, files, session_of))

  acc <- raw %>%
    # Restrict to the concurrent ERP experiment block, excluding the Session-6
    # "Gender assignment task" rows that inherit stale property/trigger values.
    filter(session_part == "Experiment") %>%
    # Keep only scored judgement trials (explicit grammatical property logged).
    filter(!is.na(grammatical_property)) %>%
    mutate(
      correct       = suppressWarnings(as.numeric(correct)),
      response_time = suppressWarnings(as.numeric(response_time)),
      trial         = suppressWarnings(as.numeric(trial)),
      prop_lc       = str_to_lower(grammatical_property),
      gram_lc       = str_to_lower(grammaticality),

      # Map to canonical property keys (shared with the ERP pipeline).
      grammatical_property = case_when(
        str_detect(prop_lc, "gender")              ~ "gender_agreement",
        str_detect(prop_lc, "differential object") ~ "differential_object_marking",
        str_detect(prop_lc, "verb")                ~ "verb_object_number_agreement",
        TRUE ~ NA_character_
      ),

      # Canonical grammaticality contrast; ancillary fillers -> NA (dropped).
      grammaticality = case_when(
        gram_lc == "grammatical" ~ "Grammatical",
        gram_lc %in% c("gender violation", "dom violation", "voa violation") ~ "Ungrammatical",
        TRUE ~ NA_character_
      ),

      # Language group from lab-ID parity (odd = Mini-English).
      mini_language = ifelse(participant_lab_ID %% 2 == 1, "Mini-English", "Mini-Norwegian")
    ) %>%
    filter(
      !is.na(grammatical_property), !is.na(grammaticality),
      !is.na(correct), correct %in% c(0, 1)
    )

  # Compare the language each log records with the assigned group before any exclusion,
  # so the census covers the participant the exclusion is about.
  if (write_side_files) .les_write_language_check(acc)

  # The participant excluded for a protocol deviation (LES_P1_PROTOCOL_DEVIATION in
  # _config.R) leaves before the response-time filter, so the filter's counts describe the
  # analysed sample. Paper 2's trajectory extraction calls this function and so inherits
  # the exclusion.
  acc <- les_p1_drop_protocol_deviation(acc)
  acc$language <- NULL
  acc$experiment_file <- NULL

  # Trial numbers are sometimes repeated in the OpenSesame logs, so keep the first row per
  # participant x session x property x trial. Only Experiment rows reach this point. The
  # repeats are the session-close re-logging of a file's last trial, with a stale
  # response_time of millions of milliseconds and correct = 0. De-duplicating BEFORE the
  # reaction-time screen keeps those rows out of the screen's counts: until October 2026
  # the screen ran first and removed all 68 of them, so they were counted as valid trials
  # and as RT exclusions, and the de-duplication removed nothing (ISSUES.md, G06-02). The
  # trials kept are the same either way.
  n_before_dedup <- nrow(acc)
  acc <- acc %>% distinct(participant_lab_ID, session, grammatical_property, trial,
                          .keep_all = TRUE)
  n_duplicates <- n_before_dedup - nrow(acc)

  # Response-time bounds. The primary data keep every judgement the participant made: only
  # trials without a finite, positive response time are dropped, and the de-duplication
  # above has already removed the stale session-close rows of millions of milliseconds.
  # Under LES_P1_ACC_RT_SCREEN=1 the legacy screen (LES_P1_ACC_RT_MS in _config.R) applies
  # as well. Its bounds are the ones written into the legacy behavioural import script,
  # which cannot run as committed (see the header) and records no rationale for 200 and
  # 4000 ms. Until 19 October 2026 they were the primary rule. They are now the sensitivity
  # analysis (ISSUES.md G06-03), because the screen selects on the outcome and removes
  # unequal shares of the two groups' trials, as _accuracy_rt_bands.csv records. The share
  # of otherwise-valid judgement trials the filter removes is written to
  # results/_accuracy_rt_screen.csv, so the manuscript reports the step with a quantity.
  n_valid <- nrow(acc)
  if (write_side_files) .les_write_rt_bands(acc)
  rt_bounds <- if (les_p1_acc_rt_screen()) LES_P1_ACC_RT_MS else c(0, Inf)
  acc <- acc %>% filter(is.finite(response_time),
                        response_time > rt_bounds[1],
                        response_time < rt_bounds[2])
  rt_screen <- data.frame(
    n_valid_trials       = n_valid,
    n_kept               = nrow(acc),
    n_rt_excluded        = n_valid - nrow(acc),
    pct_rt_excluded      = 100 * (n_valid - nrow(acc)) / n_valid,
    rt_min_ms            = rt_bounds[1],
    rt_max_ms            = rt_bounds[2],
    n_duplicates_removed = n_duplicates,
    max_rt_kept_ms       = max(acc$response_time)
  )
  # The diversity and screened variants write the file under their own names, so the
  # reported file is never rewritten by an opt-in run.
  if (write_side_files) {
    rt_path <- paper1_results(paste0("_accuracy_rt_screen", les_p1_acc_data_tag(), ".csv"))
    les_assert_readonly_data(rt_path)
    utils::write.csv(rt_screen, rt_path, row.names = FALSE)
  }
  message(sprintf("[accuracy] %d duplicate log rows removed; the response-time filter (%g, %g) ms removed %d of %d valid trials (%.2f%%)",
                  n_duplicates, rt_bounds[1], rt_bounds[2], rt_screen$n_rt_excluded, n_valid,
                  rt_screen$pct_rt_excluded))

  # Opt-in: attach the LHQ3 diversity score by lab ID (still an integer here).
  if (les_p1_acc_diversity()) acc <- .les_acc_join_diversity(acc)

  # Every log of the ERP sessions carries sentence_trigger; a log that did not would leave
  # its trials without an item (NA), counted in the item inventory.
  if (!"sentence_trigger" %in% names(acc)) acc$sentence_trigger <- NA_character_
  acc <- acc %>%
    mutate(
      # Sum-coded predictors (Brauer & Curtin, 2018; https://doi.org/10.1037/met0000159).
      recoded_grammaticality = case_when(
        grammaticality == "Grammatical"  ~ 0.5,
        grammaticality == "Ungrammatical" ~ -0.5
      ),
      recoded_mini_language = case_when(
        mini_language == "Mini-Norwegian" ~ 0.5,
        mini_language == "Mini-English"   ~ -0.5
      ),
      # Session time coding 0,1,2,3 for Sessions 2,3,4,6 (growth-curve coding,
      # Michael Clark; matches the ERP `recoded_session`): the session's position in
      # LES_ERP_SESSIONS, counted from zero.
      recoded_session = match(session, LES_ERP_SESSIONS) - 1,
      # Item identity, built as 01_extract_erp_single_trials.R builds the ERP item_id
      # (e.g. "Mini-English_141"), so the two analyses share one item factor: a sentence
      # frame within one language, crossed with grammaticality. The reported accuracy
      # fits do not use it; the opt-in by-item variant of step 04 does.
      item_id = factor(ifelse(is.na(sentence_trigger), NA_character_,
                              paste0(mini_language, "_", sentence_trigger))),
      participant_lab_ID = factor(participant_lab_ID),
      session            = factor(session, levels = LES_ERP_SESSIONS),
      mini_language      = factor(mini_language, levels = c("Mini-Norwegian", "Mini-English"))
    )

  acc
}

# =============================================================================
# Entry point: write one standardised file per property
# =============================================================================
# --- Sentence inventory --------------------------------------------------------
# Distinct logged sentences against judgement trials per session, written from the logged
# sentence text over the trials that reach the models. A logged sentence is one
# grammaticality version of one lexicalised frame, so its count says how often a surface
# string recurs, not whether the trials share items: they do, because the frames recur
# across participants and sessions, and the item factor the judgement trials share with the
# ERP is that frame, item_id (see the item inventory below). When the logfiles carry no
# sentence column every count is NA, and the manuscript prints its marker in place of the
# number.

#' Write the sentence inventory
#'
#' @param acc The frame build_paper1_accuracy() returns.
#' @return The inventory, invisibly: one row per session with n_trials, n_participants and
#'   n_distinct_sentences.
#' @details Writes results/_accuracy_sentence_inventory.csv, with the tags of
#'   les_p1_acc_data_tag().
.les_write_sentence_inventory <- function(acc) {
  has_text <- "sentence_text" %in% names(acc) && any(!is.na(acc$sentence_text))
  inv <- acc %>%
    dplyr::mutate(session = as.integer(as.character(session))) %>%
    dplyr::group_by(session) %>%
    dplyr::summarise(
      n_trials             = dplyr::n(),
      n_participants       = dplyr::n_distinct(participant_lab_ID),
      n_distinct_sentences = if (has_text) dplyr::n_distinct(sentence_text[!is.na(sentence_text)])
                             else NA_integer_,
      .groups = "drop"
    )
  inv_path <- paper1_results(paste0("_accuracy_sentence_inventory",
                                    les_p1_acc_data_tag(), ".csv"))
  les_assert_readonly_data(inv_path)
  utils::write.csv(inv, inv_path, row.names = FALSE)
  message(sprintf("[accuracy] sentence inventory written (%s)",
                  if (has_text) "sentence text found" else "no sentence column in the logs"))
  invisible(inv)
}

# --- Item inventory ------------------------------------------------------------
# The census behind the item factor the judgement trials share with the ERP: per
# property, how many items (item_id, a sentence frame within one language) the analysed
# trials hold, the share of them judged under both grammaticality levels, and how many
# participants and trials judged each. It is grouped by property as well as item, because
# the trigger codes recur across properties.

#' Write the item inventory
#'
#' @param acc The frame build_paper1_accuracy() returns.
#' @return The inventory, invisibly: one row per property with n_trials,
#'   n_trials_without_item (trials whose log carries no sentence trigger), n_items,
#'   share_items_both_grammaticality (proportion, 0-1), and the minimum, median and maximum
#'   of participants and of trials per item.
#' @details Writes results/_accuracy_item_inventory.csv, with the tags of
#'   les_p1_acc_data_tag(), through les_assert_readonly_data().
.les_write_item_inventory <- function(acc) {
  d <- acc %>%
    dplyr::mutate(participant_lab_ID = as.character(participant_lab_ID),
                  item_id = as.character(item_id))
  per_item <- d %>%
    dplyr::filter(!is.na(item_id)) %>%
    dplyr::group_by(grammatical_property, item_id) %>%
    dplyr::summarise(n_participants = dplyr::n_distinct(participant_lab_ID),
                     n_trials       = dplyr::n(),
                     both           = dplyr::n_distinct(grammaticality) == 2L,
                     .groups = "drop")
  inv <- d %>%
    dplyr::group_by(grammatical_property) %>%
    dplyr::summarise(n_trials = dplyr::n(), n_trials_without_item = sum(is.na(item_id)),
                     .groups = "drop") %>%
    dplyr::left_join(
      per_item %>%
        dplyr::group_by(grammatical_property) %>%
        dplyr::summarise(
          n_items                         = dplyr::n(),
          share_items_both_grammaticality = mean(both),
          participants_per_item_min       = min(n_participants),
          participants_per_item_median    = stats::median(n_participants),
          participants_per_item_max       = max(n_participants),
          trials_per_item_min             = min(n_trials),
          trials_per_item_median          = stats::median(n_trials),
          trials_per_item_max             = max(n_trials),
          .groups = "drop"),
      by = "grammatical_property") %>%
    dplyr::arrange(match(grammatical_property, names(LES_P1_PROPERTIES)))
  inv_path <- paper1_results(paste0("_accuracy_item_inventory",
                                    les_p1_acc_data_tag(), ".csv"))
  les_assert_readonly_data(inv_path)
  utils::write.csv(inv, inv_path, row.names = FALSE)
  message(sprintf("[accuracy] item inventory written (%s items)",
                  paste(inv$n_items, collapse = "/")))
  invisible(inv)
}

# --- Participant-balanced accuracy descriptives ------------------------------
# The manuscript's group display must not give participants with more retained trials
# more influence. Collapse the binary trials within participant x condition first, then
# average those participant proportions. The 95% intervals describe uncertainty in the
# mean participant proportion (t interval, bounded to [0, 1]); inferential claims remain
# with the trial-level Bernoulli multilevel models.

#' Participant-balanced accuracy by group, session, property and grammaticality
#'
#' @param acc The de-duplicated frame returned by build_paper1_accuracy().
#' @return A group table with no participant identifiers: mean_accuracy, sd_accuracy,
#'   n_participants, n_trials, se_accuracy, ci_low and ci_high. Writes nothing;
#'   .les_write_accuracy_by_language() persists it.
.les_accuracy_by_language <- function(acc) {
  participant_means <- acc %>%
    dplyr::mutate(
      participant_lab_ID = as.character(participant_lab_ID),
      mini_language = as.character(mini_language),
      session = as.integer(as.character(session))
    ) %>%
    dplyr::group_by(participant_lab_ID, mini_language, session,
                    grammatical_property, grammaticality) %>%
    dplyr::summarise(
      participant_accuracy = mean(correct),
      n_trials = dplyr::n(),
      .groups = "drop"
    )

  out <- participant_means %>%
    dplyr::group_by(mini_language, session, grammatical_property, grammaticality) %>%
    dplyr::summarise(
      mean_accuracy = mean(participant_accuracy),
      sd_accuracy = stats::sd(participant_accuracy),
      n_participants = dplyr::n(),
      n_trials = sum(n_trials),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      se_accuracy = dplyr::if_else(n_participants > 1L,
                                   sd_accuracy / sqrt(n_participants), NA_real_),
      critical_t = dplyr::if_else(n_participants > 1L,
                                  stats::qt(0.975, n_participants - 1L), NA_real_),
      ci_low = pmax(0, mean_accuracy - critical_t * se_accuracy),
      ci_high = pmin(1, mean_accuracy + critical_t * se_accuracy)
    ) %>%
    dplyr::select(-critical_t) %>%
    dplyr::arrange(grammatical_property, mini_language, session, grammaticality)

  out
}

# --- Participant-balanced signal-detection descriptives ----------------------
# Accuracy on grammatical and on ungrammatical trials mixes two things: how well a
# learner separates the two classes (sensitivity) and how readily they answer
# "grammatical" whatever the sentence (bias). A learner who accepts more sentences gains
# accuracy on grammatical trials and loses it on ungrammatical ones without discriminating
# any better, so the two must be separated before groups are compared (Macmillan &
# Creelman, 2005; for acceptability judgements, Huang & Ferreira, 2020).
#
# Per participant x session x property, a hit is a "grammatical" response to a grammatical
# sentence and a false alarm a "grammatical" response to an ungrammatical one. Both rates
# take the log-linear correction, adding 0.5 to each count and 1 to each denominator
# (Hautus, 1995, https://doi.org/10.3758/BF03203619), so a participant at ceiling keeps a
# finite score instead of being dropped. d' = z(H) - z(FA) and c = -(z(H) + z(FA)) / 2,
# so a negative c is a bias towards answering "grammatical". Only participant-sessions
# with both sentence types enter. Group means carry 95% t intervals over participants and
# are descriptive; the inferential estimates are the trial-level models of step 04, whose
# terms map onto these two quantities (see paper_1_morphosyntax.qmd, Judgement data).

#' Participant-balanced d' and criterion by group, session and property
#'
#' @param acc The de-duplicated frame returned by build_paper1_accuracy().
#' @return One row per group x session x property x measure (d_prime, criterion), without
#'   participant identifiers. Writes nothing; .les_write_accuracy_sdt_by_language()
#'   persists it.
.les_accuracy_sdt_by_language <- function(acc) {
  per_participant <- acc %>%
    dplyr::mutate(
      participant_lab_ID = as.character(participant_lab_ID),
      mini_language = as.character(mini_language),
      session = as.integer(as.character(session)),
      said_grammatical = dplyr::if_else(grammaticality == "Grammatical", correct, 1 - correct)
    ) %>%
    dplyr::group_by(participant_lab_ID, mini_language, session, grammatical_property) %>%
    dplyr::summarise(
      n_gram   = sum(grammaticality == "Grammatical"),
      n_ungram = sum(grammaticality == "Ungrammatical"),
      hits     = sum(said_grammatical[grammaticality == "Grammatical"]),
      fas      = sum(said_grammatical[grammaticality == "Ungrammatical"]),
      .groups = "drop"
    ) %>%
    dplyr::filter(n_gram > 0, n_ungram > 0) %>%
    dplyr::mutate(
      z_h = stats::qnorm((hits + 0.5) / (n_gram + 1)),
      z_f = stats::qnorm((fas + 0.5) / (n_ungram + 1)),
      d_prime = z_h - z_f,
      criterion = -(z_h + z_f) / 2
    )

  per_participant %>%
    tidyr::pivot_longer(c(d_prime, criterion), names_to = "measure", values_to = "value") %>%
    dplyr::group_by(mini_language, session, grammatical_property, measure) %>%
    dplyr::summarise(
      mean_value = mean(value),
      sd_value = stats::sd(value),
      n_participants = dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      se_value = dplyr::if_else(n_participants > 1L, sd_value / sqrt(n_participants), NA_real_),
      critical_t = dplyr::if_else(n_participants > 1L,
                                  stats::qt(0.975, n_participants - 1L), NA_real_),
      ci_low = mean_value - critical_t * se_value,
      ci_high = mean_value + critical_t * se_value
    ) %>%
    dplyr::select(-critical_t) %>%
    dplyr::arrange(grammatical_property, measure, mini_language, session)
}

#' Write results/_accuracy_sdt_by_language.csv (tagged _diversity under the switch)
#'
#' @param acc As for .les_accuracy_sdt_by_language().
#' @return The table written, invisibly.
.les_write_accuracy_sdt_by_language <- function(acc) {
  out <- .les_accuracy_sdt_by_language(acc)
  out_path <- paper1_results(paste0("_accuracy_sdt_by_language",
                                    les_p1_acc_data_tag(), ".csv"))
  les_assert_readonly_data(out_path)
  utils::write.csv(out, out_path, row.names = FALSE)
  message(sprintf("[accuracy] participant-balanced d' and criterion written (%d rows)", nrow(out)))
  invisible(out)
}

#' Write results/_accuracy_by_language.csv (tagged _diversity under the switch)
#'
#' @param acc As for .les_accuracy_by_language().
#' @return The table written, invisibly.
.les_write_accuracy_by_language <- function(acc) {
  out <- .les_accuracy_by_language(acc)
  out_path <- paper1_results(paste0("_accuracy_by_language",
                                    les_p1_acc_data_tag(), ".csv"))
  les_assert_readonly_data(out_path)
  utils::write.csv(out, out_path, row.names = FALSE)
  message(sprintf("[accuracy] participant-balanced group descriptives written (%d cells)",
                  nrow(out)))
  invisible(out)
}

#' Entry point: build the pooled dataset and write every output
#'
#' Takes no arguments and returns nothing useful. Builds the pooled dataset (which writes
#' the census, language-check, RT-band and RT-filter tables), writes the sentence and item
#' inventories and the two group descriptives, then z-scores the recoded predictors within
#' each property and writes les_p1_accuracy_rds(property) for every property that has
#' trials.
.run <- function() {
  acc <- build_paper1_accuracy()
  .les_write_sentence_inventory(acc)
  .les_write_item_inventory(acc)
  .les_write_accuracy_by_language(acc)
  .les_write_accuracy_sdt_by_language(acc)
  acc$sentence_text <- NULL          # never carried into the derived files

  for (property in names(LES_P1_PROPERTIES)) {
    cell <- acc %>%
      filter(grammatical_property == property) %>%
      # Standardise the recoded predictors WITHIN this property's data.
      mutate(
        z_recoded_grammaticality = .les_scale(recoded_grammaticality),
        z_recoded_session        = .les_scale(recoded_session),
        z_recoded_mini_language  = .les_scale(recoded_mini_language)
      )

    if (!nrow(cell)) { message("[accuracy] no trials for ", property, " -- skipped"); next }

    # Opt-in covariate, standardised over this property's trials by the same procedure
    # the ERP extraction applies to its covariate (an ungrouped, global z-score); the score
    # itself is a different LHQ3 score (see .les_acc_join_diversity()).
    if (les_p1_acc_diversity()) {
      cell <- cell %>%
        mutate(z_multilingual_language_diversity = .les_scale(multilingual_language_diversity))
    }

    out_path <- les_p1_accuracy_rds(property)   # accuracy_<property>[_diversity][_rtscreen].rds
    les_assert_readonly_data(out_path)
    saveRDS(cell, out_path)

    message(sprintf(
      "[accuracy] saved %s (trials=%d, participants=%d, sessions={%s}, mean acc=%.3f)",
      basename(out_path), nrow(cell),
      dplyr::n_distinct(cell$participant_lab_ID),
      paste(sort(unique(as.integer(as.character(cell$session)))), collapse = ","),
      mean(cell$correct)
    ))
  }
  message("[accuracy] done.")
}

if (sys.nframe() == 0L) .run()
