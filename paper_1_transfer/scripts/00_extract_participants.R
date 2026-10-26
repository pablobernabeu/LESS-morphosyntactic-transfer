# =============================================================================
# 00_extract_participants.R  --  Shared participant flow & demographics extractor
# -----------------------------------------------------------------------------
# WHAT THIS PRODUCES (written to BOTH papers' results/ so neither can drift)
# ------------------------------------------------------------------------
#   _sample_flow.csv       One row per pipeline stage, with the total N and the
#                          per-mini-language N, from enrolment through per-session
#                          attendance to the per-analysis usable samples. This is
#                          the single source for the participant-flow figure and
#                          every attrition/participant-count number in prose.
#   _participants.csv      One row per demographic metric (long format:
#                          metric,value,sd,n,vmin,vmax,note) over the analysed
#                          sample, so the Method's demographics are injected, not
#                          transcribed.
#   _participants_other_languages.csv
#                          One row per language named in LHQ3 item 7 beyond Norwegian
#                          and English, with the number of participants naming it, so
#                          the Participants section can count that knowledge.
#
# WHY
# ---
# Both manuscripts previously hand-typed the sample size, the session-by-session
# attrition chain, and the demographics. Hand-typed descriptives are the dominant
# reproducibility failure mode (transcription error, staleness, cross-paper
# divergence): the two papers disagreed on the Mini-Norwegian count, the sex
# breakdown summed to 60 not 65, and the handedness/AoA figures were computed over
# an undocumented sample by an undocumented rule. Deriving them here, once, from
# the read-only sources and injecting them inline removes that whole class of
# error (Marwick, Boettiger & Mullen, 2018, https://doi.org/10.1080/00031305.2017.1375986).
#
# DEFINITIONS PINNED DOWN HERE (previously implicit in prose)
# -----------------------------------------------------------
#   * Analysed sample = the participant-key rows carrying a Mini-language
#     assignment (65: 33 Mini-English, 32 Mini-Norwegian). Demographics are over
#     the subset of these with an LHQ3 record. That subset's size is written out as
#     the `n_lhq3` row and injected into both manuscripts, so it is not fixed here.
#   * English age of acquisition = the LHQ3 item-7 LISTENING onset age for the
#     participant's English entry (the "age of first exposure"). The 4-modality mean
#     (listening/speaking/reading/writing) is also written, as `eng_aoa_4mod_*`, for
#     transparency. An English entry whose five numbers are all 0 is treated as
#     unanswered (see .les_lhq3_english() below). Counting it as exposure from birth
#     with no years of use, as this script did until October 2026, put the mean listening
#     onset at 6.8 years; without it the mean is 6.9 (ISSUES.md, G04-03).
#   * English years of use = the LHQ3 item-7 "Years of use" for the English entry.
#   * Handedness/sex are reported over the analysed sample with the denominator
#     stated, NOT over the wider screened set the earlier "61 of 67" used.
#   * Usable-data stages: the criteria live in one function, les_flow_stage_ids()
#     below, which 00b_audit_participant_flow.R reuses, so the flow and its per-participant
#     audit cannot apply different definitions. Each stage is written in every run; a stage
#     whose input has not been built yet has n_total = NA and the run names the missing
#     input. The Paper 2 stages take the index names, resting-state measures and sessions
#     from paper_2_plasticity/scripts/_config.R, the configuration Paper 2's models use.
#
# ORDER
# -----
# Run after the stages whose outputs it counts: 01 (the single-trial cell files), 02 (the
# accuracy files) and Paper 2's 01, 02 and 03 (cognitive_indices.rds,
# learning_trajectory.rds and resting_state_eeg.rds). hpc/00_descriptives.slurm runs it
# after 02 on the cluster store, where all of them live.
#
# READ-ONLY: reads only data/ (participant key + LHQ3 workbooks) and the derived
# rds objects; writes only under each paper's results/ (never inside data/).
#
# USAGE
#   Rscript --vanilla paper_1_transfer/scripts/00_extract_participants.R
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "03_data_manifest.R"))
  source(here::here("paper_1_transfer", "scripts", "_config.R"))   # LES_P1_PROTOCOL_DEVIATION
  # LES_P2_COG_INDICES, LES_P2_RS_MEASURES and the Paper 2 sessions, so the Paper 2 stages
  # count with the names and sessions Paper 2's models use (ISSUES.md, X6-06).
  source(here::here("paper_2_plasticity", "scripts", "_config.R"))
  # les_p1_retained_trials(): the analysed single-trial ERP sample.
  source(here::here("paper_1_transfer", "scripts", "00c_extract_erp_retention.R"))
  library(readxl)
  library(dplyr)
  library(readr)
})

.num <- function(x) suppressWarnings(as.numeric(x))

# --- Session attendance from the participant key -----------------------------
# A participant "attended" a session if that session's date/time cell is filled.
.les_session_date_cols <- c(
  S1 = "Session1_date",      S2 = "Session2_date_time", S3 = "Session3_date_time",
  S4 = "Session4_date_time", S5 = "Session5_date",      S6 = "Session6_date_time"
)

# --- English entry finder in the LHQ3 item-7 language-history block -----------
# The block holds up to four language slots; each slot is
#   [name, Listening, Speaking, Reading, Writing, YearsOfUse]
# at 1-based column offsets 9, 15, 21, 27 (name), name+1..+4 (modality onset ages),
# name+5 (years). We pick the slot whose name contains "English". The positions are
# checked against the workbook's own header rows before any value is read
# (.les_check_lhq3_raw_header()).
.les_english_slot_bases <- c(9, 15, 21, 27)
.les_lhq3_modalities    <- c("Listening", "Speaking", "Reading", "Writing", "Years of use")

#' Stop unless the LHQ3 raw workbook still has the column layout the positional reads assume
#'
#' @param raw_all The raw workbook as read with col_names = FALSE: row 1 the title, row 2
#'   the item texts, row 3 the language-slot and modality labels, data from row 4.
#' @return invisible(TRUE); stops naming the first header cell that does not match. The
#'   cells carry line breaks, so they are trimmed and matched by pattern.
.les_check_lhq3_raw_header <- function(raw_all) {
  cell <- function(r, c) trimws(gsub("[\r\n]+", " ", as.character(raw_all[[c]][r])))
  if (!grepl("Participant ID", cell(2, 1)) || !grepl("Handedness", cell(2, 8))) {
    stop("LHQ3 Raw Data.xlsx: column 1 or 8 of the item row is no longer 'Participant ID' ",
         "or 'Handedness'; the positional reads below would take the wrong columns.",
         call. = FALSE)
  }
  for (b in .les_english_slot_bases) {
    labels <- vapply(b + 0:5, function(c) cell(3, c), character(1))
    if (!grepl("^Language [1-4]$", labels[1]) || !identical(labels[-1], .les_lhq3_modalities)) {
      stop("LHQ3 Raw Data.xlsx: columns ", b, "-", b + 5, " are not an item-7 language slot (",
           paste(labels, collapse = " / "), ").", call. = FALSE)
    }
  }
  invisible(TRUE)
}

#' English entry of each LHQ3 record's item-7 language-history block
#'
#' @param raw_mat Character data frame of the raw workbook's data rows (header rows
#'   removed), columns positional as exported (checked by .les_check_lhq3_raw_header()).
#' @return A data frame keyed by lhq3_id with handedness, eng_aoa_listen,
#'   eng_aoa_4mod, eng_years and eng_unanswered (logical: an English entry whose five
#'   numbers are all 0). A record with no English slot has NA throughout.
#' @details An entry with all five numbers 0 says the participant began listening,
#'   speaking, reading and writing English at birth and has used it for 0 years, which
#'   cannot both hold; the same records carry all-zero entries for languages they plainly
#'   use (one gives 0 years of Norwegian), so the zeros are the form's unanswered state and
#'   the entry is set to NA. An entry with 0 years of use but other non-zero values is kept;
#'   les_extract_participants() names any such entry of an analysed participant in a
#'   warning, so a partial anomaly is seen rather than silently used.
.les_lhq3_english <- function(raw_mat) {
  out <- lapply(seq_len(nrow(raw_mat)), function(i) {
    row <- raw_mat[i, ]
    id  <- trimws(as.character(row[[1]]))
    hand <- trimws(as.character(row[[8]]))
    base_en <- NA_integer_
    for (b in .les_english_slot_bases) {
      nm <- as.character(row[[b]])
      if (!is.na(nm) && grepl("english", nm, ignore.case = TRUE)) { base_en <- b; break }
    }
    aoa_listen <- aoa_4mod <- years <- NA_real_
    unanswered <- FALSE
    if (!is.na(base_en)) {
      vals <- .num(unlist(row[base_en + 1:5], use.names = FALSE))
      unanswered <- all(vals %in% 0)
      if (!unanswered) {
        mods <- vals[1:4]
        aoa_listen <- mods[1]
        if (any(!is.na(mods))) aoa_4mod <- mean(mods, na.rm = TRUE)
        years <- vals[5]
      }
    }
    data.frame(lhq3_id = id, handedness = hand,
               eng_aoa_listen = aoa_listen, eng_aoa_4mod = aoa_4mod,
               eng_years = years, eng_unanswered = unanswered, stringsAsFactors = FALSE)
  })
  do.call(rbind, out)
}

#' Every language named in the item-7 block
#'
#' The same four slots, read for their names alone, so that the languages participants
#' report beyond Norwegian and English can be counted, which the Participants section does
#' in place of an uncounted "some participants".
#'
#' @param raw_mat As for .les_lhq3_english().
#' @return A data frame with one row per (lhq3_id, named language); "NA", "N/A", "none"
#'   and empty slots are dropped.
.les_lhq3_languages <- function(raw_mat) {
  out <- lapply(seq_len(nrow(raw_mat)), function(i) {
    row <- raw_mat[i, ]
    id  <- trimws(as.character(row[[1]]))
    nms <- vapply(.les_english_slot_bases,
                  function(b) trimws(as.character(row[[b]])), character(1))
    nms <- nms[!is.na(nms) & nzchar(nms) & !tolower(nms) %in% c("na", "n/a", "none")]
    if (!length(nms)) return(NULL)
    data.frame(lhq3_id = id, language = nms, stringsAsFactors = FALSE)
  })
  do.call(rbind, Filter(Negate(is.null), out))
}

# A language name as the questionnaire recorded it, reduced to a comparable form: any
# parenthetical qualifier dropped, then title case. "Norwegian" and "English" in any of
# their spellings are the two languages every participant has, so they are not "further"
# languages.
.les_language_norm <- function(x) {
  x <- gsub("\\s*\\(.*\\)\\s*$", "", trimws(x))
  tools::toTitleCase(tolower(x))
}
.les_is_prior_language <- function(x) {
  grepl("^(english|norw|norsk|bokm|nynorsk)", tolower(x))
}

#' Read a derived .rds a flow stage needs, or note that it is absent
#'
#' @param path Path of the derived file.
#' @param needed Columns the stage reads.
#' @return The object read, or NULL (with a message naming the file) when it does not
#'   exist. Stops when it exists but lacks a needed column, because a renamed column would
#'   otherwise turn into a plausible-looking count of 0.
.les_flow_read <- function(path, needed) {
  if (!file.exists(path)) {
    message("[participants] not yet built, so its stage is written as NA: ", path)
    return(NULL)
  }
  d <- readRDS(path)
  miss <- setdiff(needed, names(d))
  if (length(miss)) {
    stop("[participants] ", basename(path), " lacks ", paste(miss, collapse = ", "), ".",
         call. = FALSE)
  }
  d
}

#' Participant IDs in each usable-data stage of the flow
#'
#' The single definition of the usable-data stages, used by les_extract_participants() and
#' by 00b_audit_participant_flow.R. Every stage describes an analysis sample, so the
#' participant excluded for a protocol deviation (LES_P1_PROTOCOL_DEVIATION in _config.R)
#' is removed from each, including the counts read from files that still carry them.
#'
#' @return A named list, in the order the flow table writes the stages: usable_accuracy,
#'   battery_baseline, trajectory, joint_predictor, usable_erp and usable_rseeg. Each
#'   element is a character vector of lab IDs, or NULL when an input the stage needs has
#'   not been built.
#' @details Reads, in Paper 1's data_derived/, accuracy_<property>.rds for every property
#'   (the reported, untagged files; stops when only some exist) and the single-trial cell
#'   files through les_p1_retained_trials(); in Paper 2's data_derived/,
#'   cognitive_indices.rds, learning_trajectory.rds and resting_state_eeg.rds. Criteria:
#'   * usable_accuracy: in any accuracy file.
#'   * battery_baseline: a non-missing value of any LES_P2_COG_INDICES at the baseline
#'     cognitive session, LES_P2_COG_SESSIONS[1].
#'   * trajectory: in the learning trajectory. joint_predictor: in both.
#'   * usable_erp: at least one retained Grammatical or Ungrammatical trial in the analysed
#'     single-trial data.
#'   * usable_rseeg: in joint_predictor, with an eyes-closed recording at the baseline
#'     neural session, LES_P2_NEURAL_SESSIONS[1], complete on LES_P2_RS_MEASURES (the
#'     rs-EEG predictor sample, not every recording). NULL whenever joint_predictor is.
#'   Refuses LES_P1_EXCLUDE_REPROCESSED=1, which would make usable_erp count the robustness
#'   sample.
les_flow_stage_ids <- function() {
  if (les_p1_exclude_reprocessed()) {
    stop("[participants] LES_P1_EXCLUDE_REPROCESSED=1 is set; the flow describes the ",
         "primary analysis. Unset it and rerun.", call. = FALSE)
  }
  .drop_dev <- function(ids) {
    ids <- as.character(ids[!is.na(ids) & as.character(ids) != ""])
    unique(ids[!(suppressWarnings(as.integer(ids)) %in% LES_P1_PROTOCOL_DEVIATION$participant_lab_ID)])
  }
  ids <- list()

  # Behavioural accuracy (Paper 1): the three reported per-property files, named here so
  # that a tagged sensitivity variant (_diversity) is never counted.
  acc_files <- paper1_derived(paste0("accuracy_", names(LES_P1_PROPERTIES), ".rds"))
  have <- file.exists(acc_files)
  if (any(have) && !all(have)) {
    stop("[participants] the accuracy extraction is incomplete; missing ",
         paste(basename(acc_files[!have]), collapse = ", "), ". Rerun 02_extract_accuracy.R.",
         call. = FALSE)
  }
  ids["usable_accuracy"] <- list(if (all(have)) {
    .drop_dev(unlist(lapply(acc_files, function(f)
      as.character(.les_flow_read(f, "participant_lab_ID")$participant_lab_ID))))
  } else {
    message("[participants] not yet built, so its stage is written as NA: ",
            paste(basename(acc_files), collapse = ", "))
    NULL
  })

  # Cognitive battery and learning trajectory (Paper 2), and their intersection.
  ci <- .les_flow_read(paper2_derived("cognitive_indices.rds"),
                       c("participant_lab_ID", "session", unname(LES_P2_COG_INDICES)))
  ids["battery_baseline"] <- list(if (!is.null(ci)) {
    ci1 <- ci[ci$session %in% LES_P2_COG_SESSIONS[1], , drop = FALSE]
    has_idx <- rowSums(!is.na(ci1[unname(LES_P2_COG_INDICES)])) > 0
    .drop_dev(unique(ci1$participant_lab_ID[has_idx]))
  })
  tj <- .les_flow_read(paper2_derived("learning_trajectory.rds"), "participant_lab_ID")
  ids["trajectory"] <- list(if (!is.null(tj)) .drop_dev(unique(tj$participant_lab_ID)))
  ids["joint_predictor"] <- list(
    if (!is.null(ids$battery_baseline) && !is.null(ids$trajectory))
      intersect(ids$battery_baseline, ids$trajectory))

  # ERP (Paper 1): the analysed single-trial sample.
  counts <- les_p1_retained_trials()
  if (is.null(counts)) message("[participants] the single-trial cell files are not yet built, ",
                               "so the usable-ERP stage is written as NA.")
  ids["usable_erp"] <- list(if (!is.null(counts)) .drop_dev(unique(counts$participant_lab_ID)))

  # Resting-state EEG (Paper 2): the rs-EEG predictor sample.
  rs <- .les_flow_read(paper2_derived("resting_state_eeg.rds"),
                       c("participant_lab_ID", "session", "condition", LES_P2_RS_MEASURES))
  ids["usable_rseeg"] <- list(if (!is.null(rs) && !is.null(ids$joint_predictor)) {
    rs <- rs[rs$session %in% LES_P2_NEURAL_SESSIONS[1] & rs$condition %in% "eyes_closed", ,
             drop = FALSE]
    rs <- rs[stats::complete.cases(rs[, LES_P2_RS_MEASURES, drop = FALSE]), , drop = FALSE]
    intersect(.drop_dev(unique(rs$participant_lab_ID)), ids$joint_predictor)
  })

  ids[c("usable_accuracy", "battery_baseline", "trajectory", "joint_predictor",
        "usable_erp", "usable_rseeg")]
}

# =============================================================================
# Main
# =============================================================================

#' Write the participant flow and the demographics to both papers
#'
#' Takes no arguments.
#' @return A list (flow, participants, other_languages) of the three tables written.
#' @details Reads the participant key, LHQ3 Aggregate Scores.xlsx and LHQ3 Raw Data.xlsx,
#'   and the derived files listed under les_flow_stage_ids(). Writes _sample_flow.csv,
#'   _participants.csv and _participants_other_languages.csv to both papers' results/
#'   (paper1_results(), paper2_results()), each through les_assert_readonly_data(). Stops
#'   when the key lacks a session date column, when the LHQ3 workbooks lack a column the
#'   reads rely on or repeat a participant, or when les_flow_stage_ids() stops.
les_extract_participants <- function() {
  key <- suppressWarnings(readr::read_csv(participant_key_csv(), show_col_types = FALSE,
                                          progress = FALSE))
  miss_cols <- setdiff(.les_session_date_cols, names(key))
  if (length(miss_cols)) {
    stop("[participants] the participant key lacks ", paste(miss_cols, collapse = ", "),
         "; attendance cannot be counted for that session.", call. = FALSE)
  }
  key <- key %>% filter(language %in% c("Mini-English", "Mini-Norwegian"))
  lang <- key$language
  is_me <- lang == "Mini-English"; is_mn <- lang == "Mini-Norwegian"
  n_enrolled <- nrow(key)

  # ---- Sample-flow stages ----------------------------------------------------
  flow <- list()
  add_stage <- function(stage, order, label, sel, source) {
    flow[[length(flow) + 1]] <<- data.frame(
      stage = stage, order = order, label = label,
      n_total = sum(sel), n_mini_english = sum(sel & is_me),
      n_mini_norwegian = sum(sel & is_mn), source = source,
      stringsAsFactors = FALSE)
  }
  add_stage("enrolled", 0, "Enrolled (assigned a mini-language)",
            rep(TRUE, n_enrolled), "participant key")
  for (i in seq_along(.les_session_date_cols)) {
    col <- .les_session_date_cols[[i]]; nm <- names(.les_session_date_cols)[i]
    present <- !is.na(key[[col]]) & trimws(as.character(key[[col]])) != ""
    add_stage(paste0("attended_", nm), i, paste0("Attended Session ", sub("^S", "", nm)),
              present, "participant key")
  }

  # Usable-data stages (definitions in les_flow_stage_ids()). Every stage is written; one
  # whose input is not yet built carries NA counts. The language split is given for the
  # three stages the manuscripts break down by group.
  stage_ids <- les_flow_stage_ids()
  stage_meta <- data.frame(
    stage  = names(stage_ids),
    order  = c(10, 11, 12, 13, 14, 15),
    label  = c("Usable grammaticality-judgement data (Paper 1)",
               "Usable baseline cognitive battery (Paper 2)",
               "Contributed a learning trajectory (Paper 2)",
               "Had baseline battery and learning trajectory (Paper 2)",
               "Usable single-trial ERP data (Paper 1)",
               "Usable baseline resting-state EEG (Paper 2)"),
    by_language = c(TRUE, FALSE, FALSE, FALSE, TRUE, TRUE),
    source = c("accuracy_*.rds", "cognitive_indices.rds", "learning_trajectory.rds",
               "derived intersection", "erp_*.rds (analysed single trials)",
               "resting_state_eeg.rds"),
    stringsAsFactors = FALSE
  )
  for (i in seq_len(nrow(stage_meta))) {
    ids <- stage_ids[[stage_meta$stage[i]]]
    n_tot <- n_me <- n_mn <- NA_integer_
    if (!is.null(ids)) {
      n_tot <- length(ids)
      if (stage_meta$by_language[i]) {
        l <- key$language[match(ids, as.character(key$participant_lab_ID))]
        n_me <- sum(l == "Mini-English", na.rm = TRUE)
        n_mn <- sum(l == "Mini-Norwegian", na.rm = TRUE)
      }
    }
    flow[[length(flow) + 1]] <- data.frame(
      stage = stage_meta$stage[i], order = stage_meta$order[i], label = stage_meta$label[i],
      n_total = n_tot, n_mini_english = n_me, n_mini_norwegian = n_mn,
      source = stage_meta$source[i], stringsAsFactors = FALSE)
  }

  flow_df <- do.call(rbind, flow)

  # ---- Demographics from the LHQ3 --------------------------------------------
  agg <- suppressMessages(readxl::read_excel(
    lhq3_path("LHQ3 Aggregate Scores.xlsx"), skip = 1))
  names(agg) <- trimws(names(agg))
  # Every column is located by its header text, never by position or by a fallback.
  gcol <- function(pattern) {
    hit <- names(agg)[grepl(pattern, names(agg), ignore.case = TRUE)]
    if (!length(hit)) stop("[participants] LHQ3 Aggregate Scores: no column matches '",
                           pattern, "'.", call. = FALSE)
    hit[1]
  }
  id_agg <- gcol("^Participant ID$")
  agg <- agg[agg[[id_agg]] %in% key$participant_LHQ3_ID, , drop = FALSE]
  if (anyDuplicated(agg[[id_agg]])) {
    stop("[participants] LHQ3 Aggregate Scores holds an analysed participant twice.",
         call. = FALSE)
  }
  age  <- .num(agg[[gcol("^Age$")]])
  sex  <- tolower(trimws(as.character(agg[[gcol("^Gender$")]])))
  prof <- .num(agg[[gcol("L2 Proficiency")]])
  divv <- .num(agg[[gcol("Multilingual Language Diversity")]])

  # Raw workbook, read positionally (its item-7 block has a two-row header the tidy reader
  # cannot name): row 1 is the title, rows 2 and 3 the header, data from row 4. The header
  # is checked against the positions first.
  raw_all <- suppressMessages(readxl::read_excel(
    lhq3_path("LHQ3 Raw Data.xlsx"), col_names = FALSE))
  .les_check_lhq3_raw_header(raw_all)
  raw_mat <- as.data.frame(raw_all[-(1:3), , drop = FALSE], stringsAsFactors = FALSE)
  eng <- .les_lhq3_english(raw_mat)
  eng <- eng[eng$lhq3_id %in% key$participant_LHQ3_ID, , drop = FALSE]
  if (anyDuplicated(eng$lhq3_id)) {
    stop("[participants] LHQ3 Raw Data holds an analysed participant twice.", call. = FALSE)
  }
  partial <- eng$lhq3_id[eng$eng_years %in% 0]
  if (length(partial)) {
    warning("[participants] LHQ3 English entries with 0 years of use but other non-zero ",
            "values, kept as given: ", paste(partial, collapse = ", "), call. = FALSE)
  }
  hand <- tolower(trimws(eng$handedness))
  n_eng_unanswered <- sum(eng$eng_unanswered)
  unanswered_note <- if (n_eng_unanswered) {
    sprintf("; %d all-zero English %s treated as unanswered", n_eng_unanswered,
            if (n_eng_unanswered == 1L) "entry" else "entries")
  } else ""

  # Languages reported beyond Norwegian and English, for the Participants section and
  # the Limitations, which note that such knowledge was not screened out.
  langs <- .les_lhq3_languages(raw_mat)
  langs <- langs[langs$lhq3_id %in% key$participant_LHQ3_ID, , drop = FALSE]
  langs$language <- .les_language_norm(langs$language)
  other <- langs[!.les_is_prior_language(langs$language), , drop = FALSE]
  n_other_language <- length(unique(other$lhq3_id))
  other_tbl <- other %>%
    dplyr::distinct(lhq3_id, language) %>%
    dplyr::count(language, name = "n_participants") %>%
    dplyr::arrange(dplyr::desc(n_participants), language)

  n_lhq3 <- nrow(agg)
  msd <- function(x) { x <- x[!is.na(x)]; c(mean = mean(x), sd = sd(x),
                                            min = min(x), max = max(x), n = length(x)) }
  a <- msd(age); p <- msd(prof); d <- msd(divv)
  al <- msd(eng$eng_aoa_listen); a4 <- msd(eng$eng_aoa_4mod); yr <- msd(eng$eng_years)

  row_m <- function(metric, m, note = "") data.frame(
    metric = metric, value = unname(m["mean"]), sd = unname(m["sd"]),
    n = unname(m["n"]), vmin = unname(m["min"]), vmax = unname(m["max"]),
    note = note, stringsAsFactors = FALSE)
  row_c <- function(metric, value, n = NA, note = "") data.frame(
    metric = metric, value = value, sd = NA_real_, n = n, vmin = NA_real_,
    vmax = NA_real_, note = note, stringsAsFactors = FALSE)

  parts <- dplyr::bind_rows(
    row_c("n_enrolled", n_enrolled, n_enrolled, "participant key, Mini-language assigned"),
    row_c("n_mini_english", sum(is_me)),
    row_c("n_mini_norwegian", sum(is_mn)),
    row_c("n_lhq3", n_lhq3, n_lhq3, "analysed participants with an LHQ3 record"),
    row_m("age_years", a, "LHQ3 Age"),
    row_c("sex_female", sum(sex == "female"), n_lhq3),
    row_c("sex_male", sum(sex == "male"), n_lhq3),
    row_c("sex_nonbinary", sum(sex == "non-binary"), n_lhq3),
    row_c("sex_undisclosed", sum(!sex %in% c("female", "male", "non-binary")), n_lhq3,
          "gender not disclosed / non-relevant"),
    row_c("hand_right", sum(grepl("right", hand)), sum(hand != "" & hand != "n/a")),
    row_c("hand_left", sum(grepl("left", hand)), sum(hand != "" & hand != "n/a")),
    row_c("hand_reported_n", sum(hand != "" & hand != "n/a"), n_lhq3,
          "participants with a handedness response"),
    row_m("eng_aoa_listen", al, paste0("English age of first exposure (LHQ3 item-7 listening onset)",
                                       unanswered_note)),
    row_m("eng_aoa_4mod", a4, paste0("English AoA, mean over listening/speaking/reading/writing",
                                     unanswered_note)),
    row_m("eng_years", yr, paste0("English years of use (LHQ3 item-7)", unanswered_note)),
    row_m("eng_l2_proficiency", p, "LHQ3 L2 (English) self-rated proficiency, 0-1"),
    row_m("multilingual_diversity", d, "LHQ3 Multilingual Language Diversity Score"),
    row_c("n_other_language", n_other_language, n_lhq3,
          "participants naming a language beyond Norwegian and English in LHQ3 item 7")
  )

  # ---- Write to BOTH papers' results/ ----------------------------------------
  for (res in list(paper1_results, paper2_results)) {
    fp <- res("_sample_flow.csv");   les_assert_readonly_data(fp)
    utils::write.csv(flow_df, fp, row.names = FALSE)
    pp <- res("_participants.csv");  les_assert_readonly_data(pp)
    utils::write.csv(parts, pp, row.names = FALSE)
    lp <- res("_participants_other_languages.csv"); les_assert_readonly_data(lp)
    utils::write.csv(other_tbl, lp, row.names = FALSE)
  }
  message("[participants] wrote _sample_flow.csv, _participants.csv and ",
          "_participants_other_languages.csv to both papers")
  list(flow = flow_df, participants = parts, other_languages = other_tbl)
}

# =============================================================================
# Entry point + validation
# =============================================================================
# Runs les_extract_participants() and prints its three tables. Entry point only.
.run <- function() {
  res <- les_extract_participants()
  cat("\n--- sample flow ---\n"); print(res$flow, row.names = FALSE)
  cat("\n--- demographics ---\n"); print(res$participants, row.names = FALSE)
  cat("\n--- further languages reported ---\n"); print(res$other_languages, row.names = FALSE)
  message("[participants] done.")
}

if (sys.nframe() == 0L) .run()
