# =============================================================================
# 03_data_manifest.R  --  Logical -> physical map for the shared, read-only data
# =============================================================================
#
# The project brief describes the shared data under three logical names:
#     data/eeg_erp_single_trials/   data/eeg_resting_state/   data/cognitive_behavioral/
# The established workspace, however, already stores these under their own
# (heavier, validated) folder names. Rather than MOVE hundreds of gigabytes of
# EEG data -- which would break the legacy pipeline and risk data loss -- this
# manifest maps each logical name onto the real location, so that a change in the
# physical layout can be absorbed here and not in every script. The scripts reach the
# tree through the accessors below: erp_single_trials_path() and resting_state_eeg_path()
# for the EEG exports, cognitive_ef_path(), behavioural_lab_path() and lhq3_path() for the
# behavioural and questionnaire data, participant_key_csv() for the participant key and
# erp_trial_count_csv() for the retained-trial table. les_participant_key() reads and
# checks the participant key, and les_data_list() and les_data_source() list and open
# files of the tree on disk or, in the sparse rendering checkout, from the committed copy.
# The OpenSesame lab-session logs have their own listing rule and reader in
# 08_lab_logs.R.
#
# READ-ONLY CONTRACT
# ------------------
# The paper pipelines must never WRITE inside data/. All derived datasets are
# written under paper_1_transfer/data_derived/ or paper_2_plasticity/data_derived/
# (see 00_paths.R). `les_assert_readonly_data()` stops the script when a path it is given
# resolves inside the data root. The extraction stages pass their output paths through it
# before writing, and so do the shared writers: les_brm()'s model cache, the convergence,
# summary and figure writers of 02_diagnostics.R, 04_provenance.R and
# 07_task_durations.R. Some pooling and fit-metadata writes in the paper scripts do not yet
# call it (ISSUES.md G01-03), and a write whose path is never passed to it is not
# protected. The comment above the guard at the foot of this file says how a path is
# resolved before the comparison.
# =============================================================================

if (!exists("data_path")) source(here::here("_shared", "R", "00_paths.R"))

# --- Logical data stores ------------------------------------------------------
# Each accessor joins its `...` (character path components) under its folder with
# data_path() and returns the path as a character string. None reads or creates anything.

# (1) ERP single-trial data (Gorilla/BrainVision exports for the sentence task),
#     used by Paper 1. Real location: data/raw data/EEG/Session {2,3,4,6}/Export.
erp_single_trials_path <- function(...) data_path("raw data", "EEG", ...)

# (2) Resting-state EEG (Paper 2). Recorded at SESSION 2 ONLY (baseline; confirmed by
#     direct reconnaissance 2026-06-13 -- there is no Session-6 resting recording). The
#     per-condition BrainVision ASCII exports live INSIDE the task-EEG tree at
#     data/raw data/EEG/Session 2/Export/<ppt>_RS_eyes_{closed,open}.{vhdr,txt}; script 03
#     reads them directly (base R), so this accessor points at that same tree.
resting_state_eeg_path <- function(...) data_path("raw data", "EEG", ...)

# (3) Cognitive & behavioural data (Paper 2 indices + Paper 1 accuracy).
cognitive_ef_path     <- function(...) data_path("raw data", "executive functions", ...)
behavioural_lab_path  <- function(...) data_path("raw data", "behavioural data from lab sessions", ...)

# --- Shared keys --------------------------------------------------------------
# Participant <-> session <-> group lookup table (lab IDs; odd = Mini-English,
# even = Mini-Norwegian) used across both papers. les_participant_key() below reads it.
participant_key_csv <- function() data_path("Participant IDs and session progress.csv")

# Retained-trial counts per participant, session and condition after artefact rejection,
# written by the legacy preprocessing and read by Paper 1's 00, 00b and 00c.
erp_trial_count_csv <- function() data_path("EEG_trial_count_per_condition.csv")

# Language History Questionnaire (LHQ3) exports, used for the participant
# demographics table (age, sex, handedness, English age-of-acquisition and
# years-of-use, self-rated proficiency, multilingual diversity). Two workbooks:
# "Aggregate Scores" holds the derived per-participant scores (Age, Gender,
# L2 Proficiency, Multilingual Language Diversity); "Raw Data" holds the raw
# item responses, including the item-7 language-history block (per-language,
# per-modality age of first use and years of use) and item-6 handedness.
lhq3_path <- function(...) data_path("raw data", "language history", ...)

# --- Session design (single source of truth) ---------------------------------
# ERP / sentence task: Sessions 2, 3, 4 (training) + 6 (post-consolidation
# retention). Executive-function tasks: Sessions 1 (baseline) and 5 (post).
# Cognitive pre/post (Paper 2) uses S1 vs S5 (see plan / manuscript Methods).
# LES_NEURAL_PREPOST names the two sessions a resting-state pre/post would use if both
# recordings existed. Only Session 2 was recorded (see (2) above), so in practice it acts
# as a session filter in Paper 2's scripts 03, 04, 07 and 10, and the rs-EEG pre/post
# models exit at the two-session guard in 05_fit_brms_prepost.R.
LES_ERP_SESSIONS        <- c(2, 3, 4, 6)
LES_RETENTION_SESSIONS  <- c(4, 6)   # Paper 1 retention contrast. Records the design only:
                                     # 05_posterior_summaries_and_contrasts.R reads its
                                     # session codes off each cell's own data instead.
LES_COG_PREPOST         <- c(1, 5)   # Paper 2 cognitive pre/post
LES_NEURAL_PREPOST      <- c(2, 6)   # Paper 2 neural pre/post (S6 not recorded; see above)

# Grammatical properties and their sentence-marker codes in the file names.
# These S1/S2/S3 are markers inside the export file names, not sessions. A file is named
# <participant>_<property>_<grammaticality>, e.g. Session 2/Export/1_S1_S101.vhdr, where
# the folder gives the session, "S1" the grammatical property and "S101" the
# grammaticality marker (data/R_functions/import_trialbytrial_EEG_data.R). They are
# unrelated to the S1..S6 session labels used above.
LES_PROPERTY_CODES <- c(
  "gender_agreement"            = "S1",
  "differential_object_marking" = "S2",
  "verb_object_number_agreement" = "S3"
)

# --- Property display labels (single source of the order and the wording) -----
# The properties are listed in the order they entered the design across sessions:
# gender agreement (Session 2), differential object marking (Session 3) and verb-object
# number agreement (Session 4). Every figure, table and list in both manuscripts follows
# this order. Alphabetical ordering would scramble the design and is never used. Three
# forms are kept, because the strings reach the page by different routes.
#   LES_PROPERTY_LABELS       data key. This hyphenated form is the key the importer
#                             writes; figures convert it to an en dash at display
#                             (les_prop_label() in 06_manuscript_helpers.R).
#   LES_PROPERTY_LABELS_TABLE table form. Pandoc typesets the tables, so the en dash
#                             of the running text is written as "--".
#   LES_PROPERTY_LABELS_PROSE running-text form, in lower case with the same "--".
LES_PROPERTY_LABELS <- c(
  gender_agreement             = "Gender agreement",
  differential_object_marking  = "Differential object marking",
  verb_object_number_agreement = "Verb-object number agreement"
)
LES_PROPERTY_LABELS_TABLE <- c(
  gender_agreement             = "Gender agreement",
  differential_object_marking  = "Differential object marking",
  verb_object_number_agreement = "Verb--object number agreement"
)
LES_PROPERTY_LABELS_PROSE <- c(
  gender_agreement             = "gender agreement",
  differential_object_marking  = "differential object marking",
  verb_object_number_agreement = "verb--object number agreement"
)

# --- Reading the tree on disk or from the committed copy -----------------------
# The pipelines read data/ from disk. The rendering box holds a sparse checkout in which
# most of data/ is tracked but absent, so a reader that also has to run there (Paper 2's
# step 13, through 07_task_durations.R) takes the committed copy from git instead. Both
# routes list only the direct children of a folder and match the file-name pattern
# without regard to case, so they return the same files. Neither route returns an empty
# result in place of a failure: a file or folder missing from both disk and HEAD, or a
# git call that fails, stops the run, so a read that failed cannot pass for a participant
# without data. On the cluster there is no .git, so the fallback stops there too.

# Path of a file under the data root as git names it ("data/<path below the root>").
.les_data_rel <- function(path) {
  root <- sub("/+$", "", gsub("\\\\", "/", .les_data_root))
  p <- gsub("\\\\", "/", path)
  inside <- startsWith(p, paste0(root, "/"))
  if (!all(inside)) {
    stop("[data] not under the data root ", root, ": ",
         paste(p[!inside], collapse = ", "), call. = FALSE)
  }
  paste0("data/", substring(p, nchar(root) + 2L))
}

# Output lines of a git command run in the project root. system2() on Windows does not
# keep an argument containing a space together, so such arguments are quoted. Stops when
# git is missing or exits non-zero.
.les_git_lines <- function(args) {
  quoted <- vapply(c("-C", .les_root, "-c", "core.quotePath=false", args), function(x) {
    if (grepl("[[:space:]]", x)) shQuote(x) else x
  }, character(1))
  out <- tryCatch(
    suppressWarnings(system2("git", quoted, stdout = TRUE, stderr = FALSE)),
    error = function(e) structure(character(0), status = 127L)
  )
  status <- attr(out, "status")
  if (!is.null(status) && !identical(as.integer(status), 0L)) {
    stop("[data] `git ", paste(args, collapse = " "), "` failed (exit status ", status,
         "). The file or folder is absent from disk, so it was to be read from the ",
         "committed copy: check that git is on the PATH and that the object can be fetched.",
         call. = FALSE)
  }
  out
}

# Files directly inside `dir` (a path under the data root) whose names match `pattern`, a
# regular expression applied to the base name without regard to case. Listed from disk
# when the folder exists and from HEAD otherwise; a folder in neither place stops the
# run. Returns a character vector of paths under the data root, sorted, which may be empty
# when no name matches. A path listed from HEAD does not exist on disk;
# les_data_source() opens it.
les_data_list <- function(dir, pattern) {
  if (dir.exists(dir)) {
    files <- list.files(dir, pattern = pattern, ignore.case = TRUE, full.names = TRUE)
    return(sort(files[!dir.exists(files)], method = "radix"))
  }
  rel_dir <- .les_data_rel(dir)
  tree <- .les_git_lines(c("ls-tree", "HEAD", "--", paste0(rel_dir, "/")))
  if (!length(tree)) {
    stop("[data] folder not found on disk or in HEAD: ", dir, call. = FALSE)
  }
  # ls-tree prints "<mode> <type> <object>\t<path>"; subfolders are type "tree".
  rel <- sub("^[^\t]*\t", "", tree[grepl("^[0-9]+ blob ", tree)])
  rel <- rel[grepl(pattern, basename(rel), ignore.case = TRUE)]
  sort(file.path(dir, basename(rel)), method = "radix")
}

# What a readr reader should open for `path`, a file under the data root: the path itself
# when the file is on disk, otherwise its committed text wrapped in I(), which readr reads
# as literal data. Stops when the file is in neither place.
les_data_source <- function(path) {
  if (file.exists(path)) return(path)
  I(paste(.les_git_lines(c("show", paste0("HEAD:", .les_data_rel(path)))), collapse = "\n"))
}

# First line of what les_data_source() returned, for sniffing a delimiter.
.les_data_first_line <- function(src) {
  if (inherits(src, "AsIs")) return(sub("\r?\n.*$", "", src))
  readLines(src, n = 1L, warn = FALSE)
}

# --- The participant key ---------------------------------------------------------
# One reader for the participant key, so that every script counts the same people as
# enrolled. The spreadsheet carries trailing rows with no ID at all, and those are
# dropped. The remaining rows are checked, and the run stops on any of: a lab ID that is
# not a whole number; a lab ID or home ID that appears twice; a lab ID whose language is
# not one of the two mini-languages, or a mini-language with no lab ID (a lab ID is
# assigned at the first lab session, where every participant was assigned a group); and
# a lab ID whose parity disagrees with its language (odd = Mini-English, even =
# Mini-Norwegian, the assignment rule several scripts rely on).
# With `enrolled_only = TRUE` (the default) only the rows of the two mini-language groups
# are returned, which on the current key are all the rows with a lab ID. Returns the key
# as a data frame with every column of the file, participant_lab_ID as integer and
# participant_home_ID, participant_LHQ3_ID and language as character (NA when blank). The
# other columns keep readr's guessed types. Reads participant_key_csv() through
# les_data_source(), so it also runs in the sparse rendering checkout.
les_participant_key <- function(enrolled_only = TRUE) {
  key <- suppressWarnings(readr::read_csv(les_data_source(participant_key_csv()),
                                          show_col_types = FALSE, progress = FALSE))
  key <- as.data.frame(key, stringsAsFactors = FALSE)
  need <- c("participant_home_ID", "participant_lab_ID", "language")
  if (length(miss <- setdiff(need, names(key)))) {
    stop("[key] the participant key lacks the column(s): ", paste(miss, collapse = ", "),
         call. = FALSE)
  }
  blank <- function(x) is.na(x) | !nzchar(trimws(as.character(x)))
  id_cols <- intersect(c("participant_home_ID", "participant_LHQ3_ID", "participant_lab_ID"),
                       names(key))
  key <- key[!Reduce(`&`, lapply(key[id_cols], blank)), , drop = FALSE]

  for (col in intersect(c("participant_home_ID", "participant_LHQ3_ID", "language"), names(key))) {
    v <- trimws(as.character(key[[col]]))
    v[blank(v)] <- NA_character_
    key[[col]] <- v
  }
  lab_num <- suppressWarnings(as.numeric(as.character(key$participant_lab_ID)))
  not_whole <- !blank(key$participant_lab_ID) & (is.na(lab_num) | lab_num != round(lab_num))
  lab  <- as.integer(ifelse(not_whole, NA, lab_num))
  lang <- key$language
  groups <- c("Mini-English", "Mini-Norwegian")
  parity <- ifelse(lab %% 2L == 1L, "Mini-English", "Mini-Norwegian")

  problems <- c(
    if (any(not_whole)) paste("lab ID not a whole number:",
                              paste(key$participant_lab_ID[not_whole], collapse = ", ")),
    if (anyDuplicated(stats::na.omit(lab))) paste("duplicated lab ID:",
      paste(unique(lab[!is.na(lab) & duplicated(lab)]), collapse = ", ")),
    if (anyDuplicated(stats::na.omit(key$participant_home_ID))) paste("duplicated home ID:",
      paste(unique(stats::na.omit(key$participant_home_ID[duplicated(key$participant_home_ID)])),
            collapse = ", ")),
    if (any(!is.na(lab) & !lang %in% groups)) paste("lab ID without a mini-language:",
      paste(lab[!is.na(lab) & !lang %in% groups], collapse = ", ")),
    if (any(is.na(lab) & lang %in% groups)) paste("mini-language without a lab ID, home ID:",
      paste(key$participant_home_ID[is.na(lab) & lang %in% groups], collapse = ", ")),
    if (any(lang %in% groups & !is.na(lab) & parity != lang)) paste(
      "lab ID whose parity disagrees with its mini-language:",
      paste(lab[lang %in% groups & !is.na(lab) & parity != lang], collapse = ", "))
  )
  if (length(problems)) {
    stop("[key] the participant key fails its checks:\n  ", paste(problems, collapse = "\n  "),
         call. = FALSE)
  }
  key$participant_lab_ID <- lab
  if (enrolled_only) key <- key[lang %in% groups, , drop = FALSE]
  rownames(key) <- NULL
  key
}

# --- Read-only guard ----------------------------------------------------------
# A path resolved for the comparison below: made absolute against the working directory
# (which 00_paths.R sets to the project root), then resolved through its nearest existing
# ancestor, which normalizePath() can follow through links, with the part that does not
# exist yet appended and its "." and ".." segments folded.
.les_resolve_path <- function(p) {
  p <- gsub("\\\\", "/", path.expand(p))
  if (!grepl("^(/|[A-Za-z]:/)", p)) p <- paste0(gsub("\\\\", "/", getwd()), "/", p)
  cur <- p
  rest <- character(0)
  while (!file.exists(cur)) {
    parent <- dirname(cur)
    if (identical(parent, cur)) break
    rest <- c(basename(cur), rest)
    cur <- parent
  }
  base <- gsub("\\\\", "/", normalizePath(cur, winslash = "/", mustWork = FALSE))
  prefix <- regmatches(base, regexpr("^(//|/|[A-Za-z]:/)", base))
  segs <- c(strsplit(substring(base, nchar(prefix) + 1L), "/+")[[1]], rest)
  out <- character(0)
  for (s in segs) {
    if (!nzchar(s) || s == ".") next
    if (s == "..") {
      if (length(out)) out <- out[-length(out)]
      next
    }
    out <- c(out, s)
  }
  paste0(prefix, paste(out, collapse = "/"))
}

# Stops the script when any intended write path lies inside the data root, and returns
# invisible(TRUE) otherwise. `output_paths` is a character vector of the paths about to be
# written, and the error lists every offending one. Each path, and the data root itself,
# is resolved by .les_resolve_path(), so a link or a relative spelling is recognised even
# when the file and some of its parent folders do not exist yet. A path counts as inside
# when it equals the data root or continues it after a "/", so a sibling folder such as
# data_backup/ passes. On Windows the comparison ignores case. The guard cannot protect a
# write whose path is never passed to it, and it does not resolve a link that is created
# after the call.
les_assert_readonly_data <- function(output_paths) {
  if (!length(output_paths)) return(invisible(TRUE))
  data_root <- .les_resolve_path(data_path())
  resolved  <- vapply(output_paths, .les_resolve_path, character(1), USE.NAMES = FALSE)
  if (.Platform$OS.type == "windows") {
    data_root <- tolower(data_root)
    resolved  <- tolower(resolved)
  }
  inside <- resolved == data_root | startsWith(resolved, paste0(data_root, "/"))
  bad <- output_paths[inside]
  if (length(bad)) {
    stop("Pipeline output must not be written inside read-only data/: \n  ",
         paste(bad, collapse = "\n  "))
  }
  invisible(TRUE)
}

cat("[manifest] logical data stores mapped; data/ is read-only.\n")
