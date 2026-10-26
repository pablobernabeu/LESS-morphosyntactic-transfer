# =============================================================================
# paper_1_transfer/scripts/_eeg_import.R
# Trial-by-trial EEG importer for Paper 1, vendored from the read-only data tree
# =============================================================================
#
# WHY A COPY
# ----------
# The validated legacy importer lives in the read-only data tree
# (data/R_functions/import_trialbytrial_EEG_data.R and merge_trialbytrial_EEG_data.R), so
# it cannot be edited. Three corrections found in September 2026 have to act at the point
# where each export file is read, which only a copy can do:
#
#   1. Session-2 reference (ISSUES.md, N8). Every Session-2 export was re-referenced to
#      (TP9 + TP10 + 0)/3 with FCz recovered, kept TP9 and TP10 against the online
#      reference, and was cleaned by an ICA over the 30 scalp electrodes plus TP9 and TP10
#      but not FCz. Sessions 3, 4 and 6 use the mean of the mastoids. les_p1_s2_rereference()
#      in _config.R brings each Session-2 file to that convention as the file is read, per
#      channel and sample, which needs no join and no extra memory.
#   2. Reprocessed and rebuilt files. Exports produced under
#      docs/eeg_filter_reprocessing_protocol.md, and marker files rebuilt from the Analyzer
#      histories, live outside the read-only tree in the overlay directory
#      (les_p1_eeg_overlay_root()), and are admitted only through the tracked manifest
#      (les_p1_eeg_overlay_manifest(); rules below). Each row carries an eeg_source column,
#      "overlay" for reprocessed exports and "legacy" otherwise, which the exclusions in
#      _config.R read.
#   3. Unpaired exports. The legacy importer inner-joins text and marker files, so an
#      export without a .vmrk vanished without a message (ISSUES.md, N7). Here every
#      unpaired export is reported by name.
#
# Everything else reproduces the legacy importer and merge: the same file discovery, marker
# parsing, time axis, labels, recodings, filters, z-scoring, factor levels and joins, and
# the same values. tests/test_eeg_import.R checks the output against the legacy functions on
# real exports. Three changes do not affect values: files are read in C-locale (radix)
# order of their path, so the row order is the same on every platform but can differ from
# the legacy importer's, whose list.files() order follows the locale (row-order-dependent
# sums such as scale() may then differ in the last bits); the per-file tables are bound
# once instead of after every file; and no copy of the growing table is assigned into the
# global environment.
#
# The merge step still reads the participant key and sources the legacy preprocessing
# scripts for the digit-span, Stroop, ASRT and LHQ3 joins through relative 'data/...'
# paths, while the exports are read through erp_single_trials_path(). The merge therefore
# stops unless 'data' in the working directory resolves to data_path(), so the two can
# never come from different trees.
#
# OVERLAY MANIFEST RULES (fail closed)
# ------------------------------------
# The manifest (paper_1_transfer/eeg_overlay_manifest.csv, tracked) has one row per overlay
# file, with columns file (path relative to the overlay root, "Session 3/Export/..."),
# participant_lab_ID, session, kind, status, conventions and sha256. The importer stops if:
#   * a file in the overlay directory has no manifest row, or a row names a file that is
#     absent, or a file is listed twice, or its SHA-256 differs from the manifest;
#   * a row's status is not "pass" or its conventions are not "as_legacy" (the same
#     channels and reference as the legacy export of its session, since the Session-2
#     correction is applied to every Session-2 file whatever its source);
#   * kind is "reprocessed" (a record rebuilt from its raw recording) and the overlay does
#     not hold a .txt AND a .vmrk for every legacy text export of that participant-session,
#     or holds an export with no legacy counterpart, so a record is never half legacy;
#   * kind is "markers_rebuilt" (a .vmrk rebuilt from the history for a legacy export that
#     lacks one) and the row is not a .vmrk, its legacy .txt is missing, or a legacy .vmrk
#     already exists;
#   * a reprocessed record is on neither LES_P1_MISFILTERED nor LES_P1_INVALID_EXPORTS;
#   * any record of LES_P1_MISFILTERED is listed as reprocessed but not all of them are, as
#     the protocol requires every reprocessed record to pass before any is used.
# =============================================================================

suppressPackageStartupMessages({
  if (!exists("erp_single_trials_path")) source(here::here("_shared", "R", "03_data_manifest.R"))
  if (!exists("les_p1_s2_rereference")) source(here::here("paper_1_transfer", "scripts", "_config.R"))
})

# --- File discovery ------------------------------------------------------------------
# Files matching `pattern` (with its extension appended) under `root`, keyed by the path
# relative to `root` ("Session 3/Export/17_trialbytrial_S1_S101.txt").
.les_eeg_list <- function(root, pattern, ext) {
  if (is.null(root) || !dir.exists(root)) return(character(0))
  f <- list.files(root, pattern = paste0(pattern, ext, "$"), recursive = TRUE)
  gsub("\\\\", "/", f)
}

# Participant-session record key of an export path ("3 7" for Session 3, participant 7).
.les_eeg_record <- function(rel) {
  paste(sub(".*Session (\\d)/.*", "\\1", rel), sub(".*Export/([0-9]+)_.*", "\\1", rel))
}

# Validates the overlay against the manifest (rules in the header) and returns the admitted
# manifest rows, or an empty data frame when there is no overlay.
.les_eeg_overlay_validated <- function() {
  root <- gsub("\\\\", "/", les_p1_eeg_overlay_root())
  man_path <- les_p1_eeg_overlay_manifest()
  on_disk <- .les_eeg_list(root, "", "(txt|vmrk|vhdr)")
  empty <- data.frame(file = character(0), kind = character(0), stringsAsFactors = FALSE)
  if (!file.exists(man_path)) {
    if (length(on_disk))
      stop("The overlay directory ", root, " holds files but the manifest ", man_path,
           " does not exist.", call. = FALSE)
    return(empty)
  }
  man <- utils::read.csv(man_path, stringsAsFactors = FALSE, colClasses = "character")
  need <- c("file", "participant_lab_ID", "session", "kind", "status", "conventions", "sha256")
  if (!all(need %in% names(man)))
    stop("Overlay manifest lacks column(s): ", paste(setdiff(need, names(man)), collapse = ", "),
         call. = FALSE)
  if (!nrow(man)) {
    if (length(on_disk)) stop("The overlay holds files but the manifest lists none.", call. = FALSE)
    return(empty)
  }
  .fail <- function(msg, files) stop(msg, paste(utils::head(files, 10), collapse = ", "), call. = FALSE)
  if (anyDuplicated(man$file)) .fail("Overlay manifest lists a file twice: ", man$file[duplicated(man$file)])
  bad <- man$file[!(man$status %in% "pass" & man$conventions %in% "as_legacy")]
  if (length(bad)) .fail("Overlay manifest row(s) not passing with 'as_legacy' conventions: ", bad)
  if (length(setdiff(on_disk, man$file))) .fail("Overlay file(s) missing from the manifest: ", setdiff(on_disk, man$file))
  if (length(setdiff(man$file, on_disk))) .fail("Manifest file(s) missing from the overlay: ", setdiff(man$file, on_disk))
  if (!requireNamespace("digest", quietly = TRUE)) stop("Package 'digest' is required to verify the overlay.", call. = FALSE)
  got <- vapply(file.path(root, man$file), function(p) digest::digest(file = p, algo = "sha256"), character(1))
  if (any(got != man$sha256)) .fail("Overlay file(s) whose SHA-256 differs from the manifest: ", man$file[got != man$sha256])
  rec_ok <- .les_eeg_record(man$file) == paste(man$session, man$participant_lab_ID)
  if (!all(rec_ok)) .fail("Manifest participant/session disagree with the file path: ", man$file[!rec_ok])

  legacy_root <- gsub("\\\\", "/", erp_single_trials_path())
  legacy_txt  <- .les_eeg_list(legacy_root, "^\\d+_trialbytrial_S[123]_S10[123]\\.", "txt")
  legacy_vmrk <- .les_eeg_list(legacy_root, "^\\d+_trialbytrial_S[123]_S10[123]\\.", "vmrk")
  if (any(!man$kind %in% c("reprocessed", "markers_rebuilt")))
    .fail("Unknown overlay kind for: ", man$file[!man$kind %in% c("reprocessed", "markers_rebuilt")])

  rb <- man[man$kind == "markers_rebuilt", , drop = FALSE]
  if (nrow(rb)) {
    not_vmrk <- rb$file[!grepl("\\.vmrk$", rb$file)]
    if (length(not_vmrk)) .fail("markers_rebuilt rows must be .vmrk files: ", not_vmrk)
    no_txt <- rb$file[!sub("\\.vmrk$", ".txt", rb$file) %in% legacy_txt]
    if (length(no_txt)) .fail("Rebuilt marker file(s) with no legacy text export: ", no_txt)
    has_vmrk <- rb$file[rb$file %in% legacy_vmrk]
    if (length(has_vmrk)) .fail("Rebuilt marker file(s) that would replace an existing legacy one: ", has_vmrk)
  }

  rp <- man[man$kind == "reprocessed", , drop = FALSE]
  if (nrow(rp)) {
    exports <- sub("\\.(txt|vmrk|vhdr)$", "", rp$file)
    stray <- unique(exports[!paste0(exports, ".txt") %in% legacy_txt])
    if (length(stray)) .fail("Reprocessed export(s) with no legacy counterpart (path, case or ID padding): ", stray)
    # Only the records the protocol reprocesses or recovers may be replaced; any other
    # record would enter the robustness analysis, which drops exactly those two lists.
    in_scope <- paste(c(LES_P1_MISFILTERED$session, LES_P1_INVALID_EXPORTS$session),
                      c(LES_P1_MISFILTERED$participant_lab_ID, LES_P1_INVALID_EXPORTS$participant_lab_ID))
    out_scope <- rp$file[!.les_eeg_record(rp$file) %in% in_scope]
    if (length(out_scope)) .fail("Reprocessed file(s) for a participant-session outside the protocol's scope: ", out_scope)
    for (rec in unique(.les_eeg_record(rp$file))) {
      want <- legacy_txt[.les_eeg_record(legacy_txt) == rec]
      want <- c(want, sub("\\.txt$", ".vmrk", want))
      miss <- setdiff(want, rp$file)
      if (length(miss)) .fail(sprintf("Reprocessed record %s is incomplete in the overlay; missing: ", rec), miss)
    }
    mis_keys <- paste(LES_P1_MISFILTERED$session, LES_P1_MISFILTERED$participant_lab_ID)
    got_mis <- intersect(mis_keys, unique(.les_eeg_record(rp$file)))
    if (length(got_mis) && length(setdiff(mis_keys, got_mis)))
      .fail("The protocol admits the reprocessed 1 Hz records only together; missing: ",
            setdiff(mis_keys, got_mis))
  }
  man
}

# Absolute paths of the text exports to read and their paired marker files. A reprocessed
# record is read entirely from the overlay (its text and marker files); a rebuilt marker file
# pairs with its legacy text export. Unpaired text exports are reported and skipped, as the
# legacy inner join skipped them.
.les_eeg_pairs <- function(pattern) {
  legacy_root  <- gsub("\\\\", "/", erp_single_trials_path())
  overlay_root <- gsub("\\\\", "/", les_p1_eeg_overlay_root())
  man <- .les_eeg_overlay_validated()
  over_txt  <- man$file[man$kind == "reprocessed" & grepl(paste0(pattern, "txt$"), basename(man$file))]
  over_vmrk <- man$file[grepl(paste0(pattern, "vmrk$"), basename(man$file))]
  txt_legacy  <- .les_eeg_list(legacy_root, pattern, "txt")
  vmrk_legacy <- .les_eeg_list(legacy_root, pattern, "vmrk")
  rel_txt <- sort(unique(c(txt_legacy, over_txt)), method = "radix")
  from_overlay <- rel_txt %in% over_txt
  txt_path <- ifelse(from_overlay, file.path(overlay_root, rel_txt), file.path(legacy_root, rel_txt))
  rel_vmrk <- sub("\\.txt$", ".vmrk", rel_txt)
  vmrk_path <- ifelse(rel_vmrk %in% over_vmrk, file.path(overlay_root, rel_vmrk),
               ifelse(rel_vmrk %in% vmrk_legacy & !from_overlay, file.path(legacy_root, rel_vmrk),
                      NA_character_))
  unpaired <- is.na(vmrk_path)
  if (any(unpaired)) {
    message("[eeg-import] ", sum(unpaired), " export(s) have no marker file and are skipped: ",
            paste(rel_txt[unpaired], collapse = "; "))
  }
  data.frame(rel = rel_txt[!unpaired], txt_file = txt_path[!unpaired],
             vmrk_file = vmrk_path[!unpaired], from_overlay = from_overlay[!unpaired],
             stringsAsFactors = FALSE)
}

# --- One export file -----------------------------------------------------------------
# Long table for one text export and its marker file, in the legacy importer's row order
# (electrode by electrode, and within an electrode trial by trial and sample by sample)
# and with its column order, plus eeg_source. Session-2 files are brought to the
# linked-mastoid reference before reshaping.
.les_eeg_read_one <- function(txt_file, vmrk_file, rel, from_overlay = FALSE) {
  markers <- readLines(vmrk_file)
  marker_start <- grep("\\[Marker Infos\\]", markers)
  if (length(marker_start) == 0) stop("The [Marker Infos] section is missing in ", vmrk_file)
  marker_infos <- markers[marker_start:length(markers)]
  sentence_markers <- marker_infos[grep("S1[1-9][0-9]|S2[0-4][0-9]|S25[0-3]", marker_infos)]
  if (length(sentence_markers) == 0)
    stop("No valid sentence markers (S110-S253) found in ", vmrk_file)
  sentence_markers <- gsub(".*S(\\d{3}).*", "\\1", sentence_markers)

  time_points <- seq(-100, 1098, by = 2)
  parsed <- lapply(readLines(txt_file), function(line) strsplit(line, "\\s+")[[1]])
  electrode_names <- vapply(parsed, `[[`, character(1), 1)
  data_values <- do.call(rbind, lapply(parsed, function(x) x[-1]))
  if (any(is.na(data_values))) stop("NAs detected in data values of ", txt_file)
  if (length(electrode_names) != nrow(data_values))
    stop("Mismatch between electrode names and data rows in ", txt_file)
  if (ncol(data_values) != length(time_points) * length(sentence_markers))
    stop("Data structure mismatch in ", txt_file,
         ": the number of columns does not align with trials and time points.")

  base_path <- paste0("Export/", sub("^.*Export/", "", sub("\\.txt$", "", rel)))
  session <- sub(".*Session (\\d).*", "\\1", rel)
  participant <- sub(".*Export/([0-9]+)_.*", "\\1", base_path)
  if (!grepl("^[0-9]+$", participant) || !session %in% c("2", "3", "4", "6"))
    stop("Cannot parse participant and session from ", rel, call. = FALSE)

  values <- matrix(as.numeric(gsub(",", ".", data_values)), nrow = nrow(data_values))
  if (identical(session, "2")) values <- les_p1_s2_rereference(values, electrode_names)

  n_e <- length(electrode_names); n_m <- length(sentence_markers); n_t <- length(time_points)
  dplyr::tibble(
    electrode            = rep(electrode_names, each = ncol(values)),
    amplitude            = as.vector(t(values)),
    participant_lab_ID   = participant,
    session              = session,
    grammatical_property = sub(".*_(S[1-3])_.*", "\\1", base_path),
    grammaticality       = sub(".*_(S10[1-3])$", "\\1", base_path),
    time                 = as.numeric(rep(time_points, times = n_m * n_e)),
    sentence_marker      = as.character(rep(rep(sentence_markers, each = n_t), times = n_e)),
    eeg_source           = if (isTRUE(from_overlay)) "overlay" else "legacy"
  )
}

# --- Importer: same arguments and output as import_trialbytrial_EEG_data() ----------
les_p1_import_trialbytrial <- function(EEG_file_pattern = "^\\d+_trialbytrial_S[123]_S10[123]\\.",
                                       min_time = -100, max_time = 1100,
                                       include_baseline = TRUE,
                                       aggregate_electrodes = FALSE,
                                       aggregate_time_points = FALSE,
                                       selected_macroregion = NULL) {
  suppressPackageStartupMessages({
    library(dplyr); library(tidyr); library(stringr)
  })
  pairs <- .les_eeg_pairs(EEG_file_pattern)
  if (!nrow(pairs)) stop("No paired exports match ", EEG_file_pattern)
  n_s2 <- sum(sub(".*Session (\\d).*", "\\1", pairs$rel) == "2")
  message(sprintf("[eeg-import] reading %d export(s) (%d from the overlay); %d Session-2 file(s) re-referenced to linked mastoids.",
                  nrow(pairs), sum(pairs$from_overlay), n_s2))
  pieces <- vector("list", nrow(pairs))
  for (i in seq_len(nrow(pairs))) {
    pieces[[i]] <- .les_eeg_read_one(pairs$txt_file[i], pairs$vmrk_file[i], pairs$rel[i],
                                     pairs$from_overlay[i])
  }
  d <- dplyr::bind_rows(pieces)
  rm(pieces); gc()

  # From here on the legacy importer, unchanged.
  d <- d %>%
    mutate(
      grammatical_property = as.character(case_when(
        grammatical_property == "S1" ~ "Gender agreement",
        grammatical_property == "S2" ~ "Differential object marking",
        grammatical_property == "S3" ~ "Verb-object number agreement",
        TRUE ~ NA_character_
      )),
      grammaticality = as.character(case_when(
        grammaticality == "S101" ~ "Grammatical",
        grammaticality == "S102" ~ "Ungrammatical",
        grammatical_property == "Gender agreement" & grammaticality == "S103" ~ "Number agreement violation",
        grammatical_property != "Gender agreement" & grammaticality == "S103" ~ "Article location violation",
        TRUE ~ NA_character_
      )),
      time_window = as.character(case_when(
        time >= 200 & time <= 498 ~ "200_500",
        time >= 300 & time <= 598 ~ "300_600",
        time >= 400 & time <= 898 ~ "400_900",
        TRUE ~ NA_character_
      )),
      brain_region = as.character(case_when(
        electrode %in% c("Fp1", "F3", "F7", "FT9", "FC5") ~ "left anterior",
        electrode %in% c("Fz", "FC1", "FC2") ~ "midline anterior",
        electrode %in% c("Fp2", "F4", "F8", "FT10", "FC6") ~ "right anterior",
        electrode %in% c("T7", "C3", "CP5") ~ "left medial",
        electrode %in% c("Cz", "CP1", "CP2") ~ "midline medial",
        electrode %in% c("T8", "C4", "CP6") ~ "right medial",
        electrode %in% c("P7", "P3", "O1") ~ "left posterior",
        electrode %in% c("Pz", "Oz") ~ "midline posterior",
        electrode %in% c("P8", "P4", "O2") ~ "right posterior",
        TRUE ~ NA_character_
      )),
      macroregion = as.character(case_when(
        str_detect(brain_region, "left|right") ~ "lateral",
        str_detect(brain_region, "midline") ~ "midline",
        TRUE ~ NA_character_
      )),
      hemisphere = as.character(case_when(
        str_detect(brain_region, "left") ~ "left",
        str_detect(brain_region, "right") ~ "right",
        TRUE ~ NA_character_
      )),
      caudality = as.character(case_when(
        str_detect(brain_region, "anterior") ~ "anterior",
        str_detect(brain_region, "medial") ~ "medial",
        str_detect(brain_region, "posterior") ~ "posterior",
        TRUE ~ NA_character_
      )),
      recoded_grammaticality = as.numeric(case_when(
        grammaticality == "Grammatical" ~ 0.5,
        grammaticality == "Number agreement violation" ~ 0,
        grammaticality == "Article location violation" ~ 0,
        grammaticality == "Ungrammatical" ~ -0.5,
        TRUE ~ NA_real_
      )),
      recoded_session = as.numeric(case_when(
        session == 2 ~ 0, session == 3 ~ 1, session == 4 ~ 2, session == 6 ~ 3,
        TRUE ~ NA_real_
      )),
      recoded_brain_region = as.numeric(case_when(
        brain_region == "left anterior" ~ 1, brain_region == "midline anterior" ~ 0.75,
        brain_region == "right anterior" ~ 0.5, brain_region == "left medial" ~ 0.25,
        brain_region == "midline medial" ~ 0, brain_region == "right medial" ~ -0.25,
        brain_region == "left posterior" ~ -0.5, brain_region == "midline posterior" ~ -0.75,
        brain_region == "right posterior" ~ -1,
        TRUE ~ NA_real_
      )),
      recoded_hemisphere = as.numeric(case_when(
        hemisphere == "right" ~ 0.5, hemisphere == "left" ~ -0.5, TRUE ~ NA_real_
      )),
      recoded_caudality = as.numeric(case_when(
        caudality == "anterior" ~ 0.5, caudality == "medial" ~ 0, caudality == "posterior" ~ -0.5,
        TRUE ~ NA_real_
      ))
    )

  if (include_baseline) {
    d <- d %>%
      filter(time < 0 | time >= min_time & time <= max_time) %>%
      mutate(time_window = case_when(time < 0 ~ "baseline", TRUE ~ time_window))
  } else {
    d <- d %>% filter(time >= min_time & time <= max_time)
  }

  d <- d %>%
    group_by(participant_lab_ID) %>%
    mutate(z_amplitude = ifelse(is.na(amplitude) | amplitude == "", NA, as.numeric(scale(amplitude)))) %>%
    ungroup()

  if (aggregate_electrodes & aggregate_time_points) {
    d <- d %>% select(-electrode, -time) %>% group_by(across(-amplitude)) %>%
      summarise(amplitude = mean(amplitude, na.rm = TRUE), .groups = "drop")
  } else if (aggregate_electrodes) {
    d <- d %>% select(-electrode) %>% group_by(across(-amplitude)) %>%
      summarise(amplitude = mean(amplitude, na.rm = TRUE), .groups = "drop")
  } else if (aggregate_time_points) {
    d <- d %>% select(-time) %>% group_by(across(-amplitude)) %>%
      summarise(amplitude = mean(amplitude, na.rm = TRUE), .groups = "drop")
  }

  if (!is.null(selected_macroregion)) {
    d <- d %>% filter(macroregion == selected_macroregion)
  }

  d %>%
    mutate(across(where(is.factor), as.character),
           across(where(is.character), ~ na_if(.x, "")),
           across(where(is.character), as.factor)) %>%
    filter(if_any(everything(), ~ !is.na(.))) %>%
    mutate(
      session = factor(session, levels = c(2, 3, 4, 6)),
      grammatical_property = factor(grammatical_property,
        levels = c("Gender agreement", "Differential object marking", "Verb-object number agreement")),
      brain_region = factor(brain_region,
        levels = c("left anterior", "midline anterior", "right anterior",
                   "left medial", "midline medial", "right medial",
                   "left posterior", "midline posterior", "right posterior"))
    )
}

# --- Merge: same arguments and output as merge_trialbytrial_EEG_data() -------------
# Identical to the legacy merge apart from calling les_p1_import_trialbytrial().
les_p1_merge_trialbytrial <- function(EEG_file_pattern = "^\\d+_trialbytrial_S[123]_S10[123]\\.",
                                      min_time = -100, max_time = 1100,
                                      include_baseline = TRUE,
                                      aggregate_electrodes = FALSE,
                                      aggregate_time_points = FALSE,
                                      selected_macroregion = NULL) {
  suppressPackageStartupMessages({ library(dplyr); library(readxl) })

  # The key and the preprocessing scripts are read through ./data, the exports through
  # data_path(); refuse to mix trees (see the header).
  if (!identical(normalizePath("data", winslash = "/", mustWork = FALSE),
                 normalizePath(data_path(), winslash = "/", mustWork = FALSE))) {
    stop("'data' in the working directory (", normalizePath("data", winslash = "/", mustWork = FALSE),
         ") does not resolve to data_path() (", normalizePath(data_path(), winslash = "/", mustWork = FALSE),
         "), so the exports and the participant key would come from different trees.", call. = FALSE)
  }

  IDs_session_progress <-
    read.csv("data/Participant IDs and session progress.csv") %>%
    rename(mini_language = language) %>%
    select(-contains(c("inspector", "conductor", "supervision"))) %>%
    mutate(participant_lab_ID = as.factor(participant_lab_ID))

  source("data/importation and preprocessing/preprocess digit span task.R")
  source("data/importation and preprocessing/preprocess Stroop task.R")
  source("data/importation and preprocessing/preprocess alternating serial reaction time task.R")
  source("data/importation and preprocessing/preprocess Language History Questionnaire.R")

  d <- les_p1_import_trialbytrial(
    EEG_file_pattern = EEG_file_pattern, min_time = min_time, max_time = max_time,
    aggregate_electrodes = aggregate_electrodes, aggregate_time_points = aggregate_time_points,
    include_baseline = include_baseline, selected_macroregion = selected_macroregion
  )
  gc()

  d <- d %>%
    mutate(
      grammatical_property = factor(grammatical_property,
        levels = c("Gender agreement", "Differential object marking", "Verb-object number agreement")),
      brain_region = factor(brain_region,
        levels = c("left anterior", "midline anterior", "right anterior",
                   "left medial", "midline medial", "right medial",
                   "left posterior", "midline posterior", "right posterior")),
      session = factor(session, levels = c(2, 3, 4, 6))
    ) %>%
    mutate(participant_lab_ID = as.factor(participant_lab_ID)) %>%
    left_join(IDs_session_progress, by = "participant_lab_ID") %>%
    left_join(session1_digit_span, by = "participant_home_ID", relationship = "many-to-many") %>%
    left_join(session1_Stroop, by = "participant_home_ID", relationship = "many-to-many") %>%
    left_join(session1_ASRT, by = "participant_home_ID", relationship = "many-to-many") %>%
    left_join(LHQ3_aggregate_scores, by = "participant_LHQ3_ID", relationship = "many-to-many") %>%
    mutate(
      Session2_datetime_parsed = as.POSIXct(Session2_date_time, format = "%Y-%m-%d %H:%M", tz = "UTC"),
      Session1_datetime_parsed = as.POSIXct(Session1_date, format = "%Y-%m-%d", tz = "UTC"),
      Session3_datetime_parsed = as.POSIXct(Session3_date_time, format = "%Y-%m-%d %H:%M", tz = "UTC"),
      Session4_datetime_parsed = as.POSIXct(Session4_date_time, format = "%Y-%m-%d %H:%M", tz = "UTC"),
      Session5_datetime_parsed = as.POSIXct(Session5_date, format = "%Y-%m-%d", tz = "UTC"),
      Session6_datetime_parsed = as.POSIXct(Session6_date_time, format = "%Y-%m-%d %H:%M", tz = "UTC"),
      Session2_days_temp = 0,
      Session3_days_temp = round(as.numeric(difftime(Session3_datetime_parsed, Session2_datetime_parsed, units = "days")), 1),
      Session4_days_temp = round(as.numeric(difftime(Session4_datetime_parsed, Session2_datetime_parsed, units = "days")), 1),
      Session6_days_temp = round(as.numeric(difftime(Session6_datetime_parsed, Session2_datetime_parsed, units = "days")), 1),
      days_from_session2 = case_when(
        session == 2 ~ Session2_days_temp, session == 3 ~ Session3_days_temp,
        session == 4 ~ Session4_days_temp, session == 6 ~ Session6_days_temp,
        TRUE ~ NA_real_
      )
    ) %>%
    select(-ends_with("_datetime_parsed"), -ends_with("_days_temp")) %>%
    mutate(
      recoded_mini_language = as.numeric(case_when(
        mini_language == "Mini-Norwegian" ~ 0.5, mini_language == "Mini-English" ~ -0.5,
        TRUE ~ NA_real_
      )),
      z_session1_digit_span = ifelse(is.na(session1_digit_span) | session1_digit_span == "", NA,
                                     as.numeric(scale(session1_digit_span))),
      z_session1_Stroop = ifelse(is.na(session1_Stroop) | session1_Stroop == "", NA,
                                 as.numeric(scale(session1_Stroop))),
      z_session1_ASRT = ifelse(is.na(session1_ASRT) | session1_ASRT == "", NA,
                               as.numeric(scale(session1_ASRT))),
      z_multilingual_language_diversity = ifelse(is.na(multilingual_language_diversity) |
                                                   multilingual_language_diversity == "", NA,
                                                 as.numeric(scale(multilingual_language_diversity))),
      z_days_from_session2 = ifelse(is.na(days_from_session2), NA, as.numeric(scale(days_from_session2))),
      across(where(is.character), as.factor)
    ) %>%
    select(amplitude, participant_lab_ID, session, grammatical_property,
           grammaticality, sentence_marker, brain_region, macroregion,
           hemisphere, caudality, time_window, everything()) %>%
    mutate(across(where(is.factor), as.character),
           across(where(is.character), ~ na_if(.x, "")),
           across(where(is.character), as.factor)) %>%
    filter(if_any(everything(), ~ !is.na(.)))
}
