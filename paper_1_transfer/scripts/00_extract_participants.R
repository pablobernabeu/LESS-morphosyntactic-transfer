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
#     participant's English entry (the "age of first exposure"); reproduces the
#     ~6.8 previously reported. The 4-modality mean (listening/speaking/reading/
#     writing) is also written, as `eng_aoa_4mod_*`, for transparency.
#   * English years of use = the LHQ3 item-7 "Years of use" for the English entry.
#   * Handedness/sex are reported over the analysed sample with the denominator
#     stated, NOT over the wider screened set the earlier "61 of 67" used.
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
  library(readxl)
  library(dplyr)
  library(readr)
})

# The first argument unless it is NULL, empty or NA, otherwise the second. Named so as
# not to shadow base R's %||% (R >= 4.4.0), which treats NA as a value.
.first_or <- function(a, b) if (is.null(a) || length(a) == 0 || is.na(a)) b else a

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
# name+5 (years). We pick the slot whose name contains "English".
.les_english_slot_bases <- c(9, 15, 21, 27)

.les_lhq3_english <- function(raw_mat) {
  # raw_mat: character matrix, one row per participant (data rows only), columns
  # positional as exported. Returns a data.frame keyed by lhq3_id.
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
    if (!is.na(base_en)) {
      mods <- .num(c(row[[base_en + 1]], row[[base_en + 2]],
                     row[[base_en + 3]], row[[base_en + 4]]))
      aoa_listen <- mods[1]
      if (any(!is.na(mods))) aoa_4mod <- mean(mods, na.rm = TRUE)
      years <- .num(row[[base_en + 5]])
    }
    data.frame(lhq3_id = id, handedness = hand,
               eng_aoa_listen = aoa_listen, eng_aoa_4mod = aoa_4mod,
               eng_years = years, stringsAsFactors = FALSE)
  })
  do.call(rbind, out)
}

# --- Every language named in the item-7 block ----------------------------------
# The same four slots, read for their names alone. Returns one row per (participant,
# named language), so that the languages participants report beyond Norwegian and
# English can be counted, which the Participants section does in place of an uncounted
# "some participants".
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

# --- Count distinct participants in a derived rds (if present) ----------------
.les_n_participants_rds <- function(path, id_col = "participant_lab_ID",
                                    filter_fun = NULL) {
  if (!file.exists(path)) return(NA_integer_)
  d <- tryCatch(readRDS(path), error = function(e) NULL)
  if (is.null(d)) return(NA_integer_)
  if (is.list(d) && !is.data.frame(d)) d <- dplyr::bind_rows(d)
  if (!is.data.frame(d) || !id_col %in% names(d)) return(NA_integer_)
  if (!is.null(filter_fun)) d <- filter_fun(d)
  length(unique(d[[id_col]][!is.na(d[[id_col]])]))
}

# =============================================================================
# Main
# =============================================================================
les_extract_participants <- function() {
  key <- suppressWarnings(readr::read_csv(participant_key_csv(), show_col_types = FALSE,
                                          progress = FALSE))
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
    present <- if (col %in% names(key)) {
      !is.na(key[[col]]) & trimws(as.character(key[[col]])) != ""
    } else rep(FALSE, n_enrolled)
    add_stage(paste0("attended_", nm), i, paste0("Attended Session ", sub("^S", "", nm)),
              present, "participant key")
  }

  # Usable-data stages from derived objects (those that exist locally; the ERP and
  # resting-state usable samples are computed wherever their derived objects live).
  add_usable <- function(stage, order, label, n_total, n_me, n_mn, source) {
    flow[[length(flow) + 1]] <<- data.frame(
      stage = stage, order = order, label = label,
      n_total = n_total, n_mini_english = n_me, n_mini_norwegian = n_mn,
      source = source, stringsAsFactors = FALSE)
  }

  # Behavioural accuracy usable (Paper 1) -- distinct participants across the three
  # per-property accuracy objects.
  acc_ids <- unique(unlist(lapply(
    c("accuracy_gender_agreement.rds", "accuracy_differential_object_marking.rds",
      "accuracy_verb_object_number_agreement.rds"),
    function(f) {
      p <- paper1_derived(f)
      if (!file.exists(p)) return(character(0))
      d <- tryCatch(readRDS(p), error = function(e) NULL)
      if (is.null(d) || !"participant_lab_ID" %in% names(d)) return(character(0))
      as.character(unique(d$participant_lab_ID))
    })))
  acc_ids <- acc_ids[!is.na(acc_ids) & acc_ids != ""]
  if (length(acc_ids)) {
    acc_lang <- key$language[match(acc_ids, as.character(key$participant_lab_ID))]
    add_usable("usable_accuracy", 10, "Usable grammaticality-judgement data (Paper 1)",
               length(acc_ids), sum(acc_lang == "Mini-English", na.rm = TRUE),
               sum(acc_lang == "Mini-Norwegian", na.rm = TRUE), "accuracy_*.rds")
  }

  # Cognitive battery (Paper 2) -- S1 with any index; and the joint (both trajectory
  # and battery) sample.
  cog_p <- paper2_derived("cognitive_indices.rds")
  traj_p <- paper2_derived("learning_trajectory.rds")
  cog_ids_s1 <- traj_ids <- character(0)
  if (file.exists(cog_p)) {
    ci <- tryCatch(readRDS(cog_p), error = function(e) NULL)
    if (!is.null(ci) && "participant_lab_ID" %in% names(ci)) {
      ci1 <- ci[ci$session %in% 1, , drop = FALSE]
      idx <- intersect(c("stroop_interference", "digit_span", "asrt_learning"), names(ci1))
      has_idx <- rowSums(!is.na(ci1[idx])) > 0
      cog_ids_s1 <- as.character(unique(ci1$participant_lab_ID[has_idx]))
    }
  }
  if (file.exists(traj_p)) {
    tj <- tryCatch(readRDS(traj_p), error = function(e) NULL)
    idc <- intersect(c("participant_lab_ID", "participant_home_ID"), names(tj))[1]
    if (!is.null(tj) && !is.na(idc)) traj_ids <- as.character(unique(tj[[idc]]))
  }
  cog_ids_s1 <- cog_ids_s1[!is.na(cog_ids_s1) & cog_ids_s1 != ""]
  if (length(cog_ids_s1))
    add_usable("battery_baseline", 11, "Usable baseline cognitive battery (Paper 2)",
               length(cog_ids_s1), NA, NA, "cognitive_indices.rds")
  if (length(traj_ids))
    add_usable("trajectory", 12, "Contributed a learning trajectory (Paper 2)",
               length(traj_ids), NA, NA, "learning_trajectory.rds")
  if (length(cog_ids_s1) && length(traj_ids))
    add_usable("joint_predictor", 13, "Had baseline battery and learning trajectory (Paper 2)",
               length(intersect(cog_ids_s1, traj_ids)), NA, NA, "derived intersection")

  # Resting-state usable (Paper 2): the rs-EEG *predictor* sample, i.e. participants
  # who entered the joint predictor model AND have usable eyes-closed baseline rs-EEG.
  # This is the figure the manuscripts inject for the rs-EEG predictor sample; it is
  # smaller than the number of rs-EEG recordings, which is not what the models use.
  # NA until resting_state_eeg.rds exists.
  rs_p <- paper2_derived("resting_state_eeg.rds")
  rs_n <- rs_me <- rs_mn <- NA_integer_
  joint_ids <- if (length(cog_ids_s1) && length(traj_ids)) {
    intersect(cog_ids_s1, traj_ids)
  } else character(0)
  if (file.exists(rs_p)) {
    rs <- tryCatch(readRDS(rs_p), error = function(e) NULL)
    if (!is.null(rs) && "participant_lab_ID" %in% names(rs)) {
      if ("condition" %in% names(rs)) {
        rs <- rs[grepl("closed", rs$condition, ignore.case = TRUE), , drop = FALSE]
      }
      # A participant counts as usable rs-EEG only with a complete predictor vector
      # (all band powers + IAF non-missing) -- the listwise criterion the model applies.
      bnd <- intersect(c("delta", "theta", "alpha", "beta", "gamma", "iaf"), names(rs))
      if (length(bnd)) rs <- rs[stats::complete.cases(rs[, bnd, drop = FALSE]), , drop = FALSE]
      rs_ids <- as.character(unique(rs$participant_lab_ID[!is.na(rs$participant_lab_ID)]))
      ids <- if (length(joint_ids)) intersect(rs_ids, joint_ids) else rs_ids
      rl  <- key$language[match(ids, as.character(key$participant_lab_ID))]
      rs_n <- length(ids); rs_me <- sum(rl == "Mini-English", na.rm = TRUE)
      rs_mn <- sum(rl == "Mini-Norwegian", na.rm = TRUE)
    }
  }
  # ERP-usable (Paper 1): distinct participants contributing usable single-trial
  # EEG in the modelled Grammatical/Ungrammatical conditions, from the per-cell
  # retained-trial table. (The ancillary violation conditions are excluded.)
  erp_n <- erp_me <- erp_mn <- NA_integer_
  tc_path <- erp_trial_count_csv()
  if (file.exists(tc_path)) {
    tc <- suppressWarnings(readr::read_csv(tc_path, show_col_types = FALSE, progress = FALSE))
    tc <- tc[tc$grammaticality %in% c("Grammatical", "Ungrammatical"), , drop = FALSE]
    erp_n  <- length(unique(tc$participant_lab_ID))
    erp_me <- length(unique(tc$participant_lab_ID[tc$mini_language == "Mini-English"]))
    erp_mn <- length(unique(tc$participant_lab_ID[tc$mini_language == "Mini-Norwegian"]))
  }
  add_usable("usable_erp", 14, "Usable single-trial ERP data (Paper 1)",
             erp_n, erp_me, erp_mn, "EEG_trial_count_per_condition.csv")
  add_usable("usable_rseeg", 15, "Usable baseline resting-state EEG (Paper 2)",
             rs_n, rs_me, rs_mn, "resting_state_eeg.rds")

  flow_df <- do.call(rbind, flow)

  # ---- Demographics from the LHQ3 --------------------------------------------
  agg <- suppressMessages(readxl::read_excel(
    lhq3_path("LHQ3 Aggregate Scores.xlsx"), skip = 1))
  names(agg) <- trimws(names(agg))
  id_agg <- .first_or(names(agg)[grepl("^Participant ID$", names(agg))][1], names(agg)[1])
  keep_agg <- agg[[id_agg]] %in% key$participant_LHQ3_ID
  agg <- agg[keep_agg, , drop = FALSE]
  gcol <- function(sub) names(agg)[grepl(sub, names(agg), ignore.case = TRUE)][1]
  age  <- .num(agg[[gcol("^Age$")]])
  sex  <- tolower(trimws(as.character(agg[[gcol("^Gender$")]])))
  prof <- .num(agg[[gcol("L2 Proficiency")]])
  divv <- .num(agg[[gcol("Multilingual Language Diversity")]])

  # Raw workbook, read positionally (its item-7 block has a two-row header the
  # tidy reader cannot name); data rows begin after the title + two header rows.
  raw_all <- suppressMessages(readxl::read_excel(
    lhq3_path("LHQ3 Raw Data.xlsx"), col_names = FALSE))
  raw_mat <- as.data.frame(raw_all[-(1:2), , drop = FALSE], stringsAsFactors = FALSE)
  eng <- .les_lhq3_english(raw_mat)
  eng <- eng[eng$lhq3_id %in% key$participant_LHQ3_ID, , drop = FALSE]
  hand <- tolower(trimws(eng$handedness))

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
    row_m("eng_aoa_listen", al, "English age of first exposure (LHQ3 item-7 listening onset)"),
    row_m("eng_aoa_4mod", a4, "English AoA, mean over listening/speaking/reading/writing"),
    row_m("eng_years", yr, "English years of use (LHQ3 item-7)"),
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
.run <- function() {
  res <- les_extract_participants()
  cat("\n--- sample flow ---\n"); print(res$flow, row.names = FALSE)
  cat("\n--- demographics ---\n"); print(res$participants, row.names = FALSE)
  cat("\n--- further languages reported ---\n"); print(res$other_languages, row.names = FALSE)
  message("[participants] done.")
}

if (sys.nframe() == 0L) .run()
