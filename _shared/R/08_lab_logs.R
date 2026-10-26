# =============================================================================
# 08_lab_logs.R  --  One listing rule and one reader for the OpenSesame lab logs
# =============================================================================
#
# Four scripts read the same OpenSesame logfiles of lab Sessions 2, 3, 4 and 6
# (behavioural_lab_path("Session <n>")): Paper 1's training-gate flow (00d), accuracy
# extraction (02) and RSVP timing census (01b), and the task durations of both papers
# (07_task_durations.R). Until October 2026 each listed, named and parsed the files its
# own way, so the same two Session-4 logs were read by one script and silently dropped by
# others (ISSUES.md X6-01). This module gives them one rule:
#
#   * Listing. Every *.csv directly inside a session folder, from disk or, in the sparse
#     rendering checkout, from HEAD (les_data_list() in 03_data_manifest.R). A
#     '*.csv.filepart' left by an interrupted download does not end in .csv and is not
#     listed.
#   * Naming. A logfile is subject-<lab ID>.csv, or subject-<lab ID>-<part>.csv when a
#     Session-4 run was saved in two parts (participants 6 and 20: "-test" and
#     "-experiment"; participant 15 has a "-test" file beside subject-15.csv). Any other
#     name is listed with no lab ID and a warning.
#   * Delimiter. Every log is comma-delimited except subject-3.csv and subject-5.csv of
#     Session 4, which are semicolon-delimited. They were re-saved outside OpenSesame:
#     they carry no quoting and record opensesame_version as "03.03.2014" where every
#     other log has "3.3.14" (ISSUES.md X5-03). By default the reader takes the
#     delimiter from the header line, comparing its counts of ";" and ",". A caller that
#     must reproduce an output built with the comma-only reader passes delim = ",", and
#     those two files then come back as a single unnamed column.
#
# Which files a script reads (plain logs only, or the split parts too) and which
# delimiter rule it applies remain the script's choice, made visibly at its call.
# =============================================================================

if (!exists("data_path")) source(here::here("_shared", "R", "00_paths.R"))
if (!exists("les_data_list")) source(here::here("_shared", "R", "03_data_manifest.R"))

# subject-<lab ID>[-<part>].csv; the first group is the lab ID, the second the part.
LES_LAB_LOG_NAME_RE <- "^subject-([0-9]+)(-[A-Za-z]+)?\\.csv$"

# The logfiles of the lab sessions in `sessions` (numeric session labels, by default the
# four ERP sessions). Returns a data frame with one row per file: path (under the data
# root; it may exist only in HEAD, which les_read_lab_log() handles), file (base name),
# session (integer), participant_lab_ID (integer, NA for a name the rule does not
# recognise) and part ("" for a plain subject-<n>.csv, otherwise the lower-case suffix
# such as "test"). Stops when a session folder is in neither place or lists no .csv
# file, and warns, naming them, about files whose names give no lab ID.
les_lab_log_files <- function(sessions = LES_ERP_SESSIONS) {
  rows <- lapply(sessions, function(s) {
    f <- les_data_list(behavioural_lab_path(paste("Session", s)), "\\.csv$")
    if (!length(f)) stop("[lab-logs] no logfile listed for Session ", s, call. = FALSE)
    data.frame(path = f, file = basename(f), session = as.integer(s),
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  named <- grepl(LES_LAB_LOG_NAME_RE, out$file, ignore.case = TRUE)
  out$participant_lab_ID <- NA_integer_
  out$participant_lab_ID[named] <- as.integer(sub(LES_LAB_LOG_NAME_RE, "\\1", out$file[named],
                                                  ignore.case = TRUE))
  out$part <- NA_character_
  out$part[named] <- tolower(sub("^-", "", sub(LES_LAB_LOG_NAME_RE, "\\2", out$file[named],
                                               ignore.case = TRUE)))
  if (any(!named)) {
    warning("[lab-logs] logfile name(s) without a lab ID (expected subject-<n>[-<part>].csv): ",
            paste0("Session ", out$session[!named], "/", out$file[!named], collapse = ", "),
            call. = FALSE)
  }
  rownames(out) <- NULL
  out
}

# Delimiter of a logfile from its header line: ";" when the line holds more semicolons
# than commas, otherwise ",".
les_lab_log_delim <- function(header) {
  n_semi  <- lengths(regmatches(header, gregexpr(";", header, fixed = TRUE)))
  n_comma <- lengths(regmatches(header, gregexpr(",", header, fixed = TRUE)))
  if (isTRUE(n_semi > n_comma)) ";" else ","
}

# Read one logfile. `path` is a path as les_lab_log_files() returns it. `cols` is a
# character vector of the columns to keep (those the file lacks are skipped), or NULL for
# all of them. `delim` is NULL to take the delimiter from the header line, or a fixed
# delimiter. `na` gives the strings read as missing. Every column is read as character,
# so the caller converts what it needs and no value is lost to readr's type guessing.
# Returns a tibble with the attribute "delim" set to the delimiter used. Reads from disk,
# or from HEAD when the file is absent (les_data_source()), and stops when it is in
# neither place.
les_read_lab_log <- function(path, cols = NULL, delim = NULL, na = c("", "NA")) {
  src <- les_data_source(path)
  if (is.null(delim)) delim <- les_lab_log_delim(.les_data_first_line(src))
  d <- if (is.null(cols)) {
    readr::read_delim(src, delim = delim, na = na,
                      col_types = readr::cols(.default = readr::col_character()),
                      show_col_types = FALSE, progress = FALSE, name_repair = "unique")
  } else {
    readr::read_delim(src, delim = delim, na = na,
                      col_types = readr::cols(.default = readr::col_character()),
                      col_select = tidyselect::any_of(cols),
                      show_col_types = FALSE, progress = FALSE, name_repair = "unique")
  }
  attr(d, "delim") <- delim
  d
}
