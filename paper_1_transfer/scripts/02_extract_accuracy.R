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
# sum-coded / standardised design predictors (grammaticality, session, language).
# With LES_P1_ACC_DIVERSITY=1 it additionally attaches and standardises the LHQ3
# multilingual language diversity score and writes accuracy_<property>_diversity.rds
# instead (see .les_acc_join_diversity below); the default output is untouched.
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
#   * reaction-time plausibility filter 200-4000 ms,
#   * de-duplication of repeated OpenSesame trial numbers.
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
#   * Two Session-4 logs (participants 3 and 5) were exported with a semicolon
#     delimiter, where every other logfile in the study is comma-delimited.
#     readr::read_csv() below is fixed to a comma, so those files parse as one unnamed
#     column, arrive with no `session_part`, and are dropped whole by the Experiment
#     filter.
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

# Standardisation helper (shared rationale with the ERP extraction).
.les_scale <- function(x) {
  if (all(is.na(x))) return(as.numeric(x))
  s <- stats::sd(x, na.rm = TRUE)
  if (is.na(s) || s == 0) return(rep(0, length(x)))
  as.numeric(scale(x))
}

# Columns we keep from the (very wide) OpenSesame logfiles.
# `session_part` is needed to exclude the Session-6 "Gender assignment task" block
# (see IDENTIFYING THE JUDGEMENT TRIALS above); it must survive the intersect() subset.
.les_acc_cols <- c("correct", "response_time", "grammaticality",
                   "grammatical_property", "trial", "subject_nr", "session_part")

# The logged sentence, if the logfile carries one under this name. It feeds the sentence
# inventory below and is dropped before any derived file is written, so the modelled
# data are unchanged by it.
.les_acc_sentence_col <- "sentence"

# --- Read one subject x session logfile, keeping only the needed columns ------
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
# The ERP models carry `z_multilingual_language_diversity` as a between-participant
# control (03_fit_brms_erp.R); the accuracy models do not, because the legacy
# behavioural import never joined the questionnaire. With LES_P1_ACC_DIVERSITY=1 the
# per-participant "Multilingual Language Diversity Score" is attached here from the
# LHQ3 Aggregate Scores export, matched by column NAME (as 00_extract_participants.R
# does for the demographics table) and linked to the lab ID through the participant
# key, and 04_fit_brms_accuracy.R adds it as a main effect. The switch writes its own
# derived files (accuracy_<property>_diversity.rds; see les_p1_accuracy_rds() in
# _config.R), so the default extraction and the reported fits are untouched. Trials
# of participants without a score keep NA and are dropped at fit time by the same
# listwise deletion the ERP models apply.
# =============================================================================
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
# Two export formats leave a participant-session out of the extraction: a run split
# across subject-N-test.csv and subject-N-experiment.csv, which the file pattern does not
# match, and a semicolon-delimited export, which the comma-delimited reader parses as one
# column and the Experiment filter then drops whole. Both are recorded here, one row per
# affected file, in results/_accuracy_input_gaps.csv. A suffixed file beside a plain
# subject-N.csv for the same participant and session is an unread extra export, not a
# gap, because the plain file carries that participant's run; it is recorded under its
# own reason so that the manuscript's count of lost participants excludes it.
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
  gap_path <- paper1_results(paste0("_accuracy_input_gaps", les_p1_acc_diversity_tag(), ".csv"))
  les_assert_readonly_data(gap_path)
  utils::write.csv(gaps, gap_path, row.names = FALSE)
  message(sprintf("[accuracy] input-gap census: %d split exports, %d semicolon-delimited logs",
                  length(split_files), sum(is_semi)))
  invisible(gaps)
}

# =============================================================================
# Build and preprocess the pooled judgement dataset
# =============================================================================
build_paper1_accuracy <- function() {

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
  .les_write_input_gaps(files, sessions)

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

  # Reaction-time bounds (LES_P1_ACC_RT_MS in _config.R) carried over unchanged from the
  # legacy import script so that both pipelines analyse the same trials. That script
  # records no rationale for 200 and 4000 ms, and none is derived here; they are kept
  # for comparability. The share of otherwise-valid judgement trials the screen removes
  # is written to results/_accuracy_rt_screen.csv so the manuscript reports the
  # screening step with a quantity.
  n_valid <- nrow(acc)
  acc <- acc %>% filter(response_time > LES_P1_ACC_RT_MS[1],
                        response_time < LES_P1_ACC_RT_MS[2])
  rt_screen <- data.frame(
    n_valid_trials  = n_valid,
    n_kept          = nrow(acc),
    n_rt_excluded   = n_valid - nrow(acc),
    pct_rt_excluded = 100 * (n_valid - nrow(acc)) / n_valid,
    rt_min_ms       = LES_P1_ACC_RT_MS[1],
    rt_max_ms       = LES_P1_ACC_RT_MS[2]
  )
  # The diversity variant writes the same screen under its own name, so the reported
  # file is never rewritten by an opt-in run (its content would be identical).
  rt_path <- paper1_results(paste0("_accuracy_rt_screen", les_p1_acc_diversity_tag(), ".csv"))
  les_assert_readonly_data(rt_path)
  utils::write.csv(rt_screen, rt_path, row.names = FALSE)
  message(sprintf("[accuracy] RT screen removed %d of %d valid trials (%.2f%%)",
                  rt_screen$n_rt_excluded, n_valid, rt_screen$pct_rt_excluded))

  # Opt-in: attach the LHQ3 diversity score by lab ID (still an integer here).
  if (les_p1_acc_diversity()) acc <- .les_acc_join_diversity(acc)

  acc <- acc %>%
    # Trial numbers are sometimes repeated in the OpenSesame logs, so keep one row per
    # participant x session x property x trial. Only Experiment rows reach this point.
    distinct(participant_lab_ID, session, grammatical_property, trial, .keep_all = TRUE) %>%
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
# The Method says the judgement sentences are generated combinatorially and so form no
# shared item factor. The count behind that claim, distinct sentences against judgement
# trials per session, is written here from the logged sentence text, over the trials that
# reach the models. When the logfiles carry no sentence column every count is NA, and the
# manuscript prints its marker in place of the number.
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
                                    les_p1_acc_diversity_tag(), ".csv"))
  les_assert_readonly_data(inv_path)
  utils::write.csv(inv, inv_path, row.names = FALSE)
  message(sprintf("[accuracy] sentence inventory written (%s)",
                  if (has_text) "sentence text found" else "no sentence column in the logs"))
  invisible(inv)
}

.run <- function() {
  acc <- build_paper1_accuracy()
  .les_write_sentence_inventory(acc)
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

    # Opt-in covariate, standardised over this property's trials exactly as the ERP
    # extraction standardises it over a cell's rows (an ungrouped, global z-score).
    if (les_p1_acc_diversity()) {
      cell <- cell %>%
        mutate(z_multilingual_language_diversity = .les_scale(multilingual_language_diversity))
    }

    out_path <- les_p1_accuracy_rds(property)   # accuracy_<property>[_diversity].rds
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
