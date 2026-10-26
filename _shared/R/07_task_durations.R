# =============================================================================
# 07_task_durations.R -- observed duration summaries for home and lab sessions
# =============================================================================
#
# The two manuscripts use the same duration summaries.  Home-task duration is the
# elapsed time between the first and last Gorilla event for a participant and task.
# Lab-phase duration is taken from OpenSesame's phase markers: the next phase marker
# ends a phase, and the last phase-specific event ends the final phase in a file.
#
# The raw data are read-only.  During local rendering the sparse checkout may omit
# them, so the readers fall back to the committed copy through git (les_data_list() and
# les_data_source() in 03_data_manifest.R).  On a full data or cluster checkout the
# ordinary file path is used instead.  A folder or file that can be read in neither way,
# a git call that fails and a participant key that fails its checks all stop the run,
# so les_write_task_duration_artifacts() never replaces the committed tables with a
# partial extraction.
#
# The lab logs are listed and read through 08_lab_logs.R, the reader the other lab-log
# scripts share.  Two Session-4 logs (lab IDs 3 and 5) are semicolon-delimited.  The
# committed _task_durations_lab.csv was built with a comma-only reader, which reads them
# as one unnamed column, so they contribute no rows; the lab extractor still reads them
# that way by default, so that a re-run reproduces the reported medians, and warns that
# they gave no rows.  LES_DURATIONS_SNIFF_DELIM=1 takes each log's delimiter from its
# header instead and adds their Session-4 rows (ISSUES.md X6-01, awaiting sign-off).
# =============================================================================

if (!exists("data_path")) {
  source(here::here("_shared", "R", "00_paths.R"))
}
if (!exists("les_data_list")) {
  source(here::here("_shared", "R", "03_data_manifest.R"))
}
if (!exists("les_read_lab_log")) {
  source(here::here("_shared", "R", "08_lab_logs.R"))
}

# --- Design of the two tables -----------------------------------------------------
# The sessions, tasks and phases the tables cover, used by the extractors, the median
# sentence and the plots alike.  The home tasks are keyed by the stem of their Gorilla
# export names, which a batch export carries at its start ("Stroop 1.csv") and a named
# export after the home ID ("qdvg4 Stroop.csv").
LES_DURATION_HOME_SESSIONS <- c(1L, 5L)
.les_duration_task_files <- c(stroop = "Stroop", digit_span = "digit span",
                              asrt = "serial reaction time")
LES_DURATION_TASK_LABELS <- c(stroop = "Stroop", digit_span = "Digit span", asrt = "ASRT")
LES_DURATION_LAB_SESSIONS <- c(2L, 3L, 4L, 6L)
LES_DURATION_PHASE_LABELS <- c(pretraining = "Pretraining", training = "Training",
                               test = "Test", experiment = "Experiment")

.les_duration_num <- function(x) {
  suppressWarnings(as.numeric(as.character(x)))
}

# Read the requested columns of one Gorilla export as text, so that no value is lost to
# readr's type guessing and the exports bind whatever types their columns would guess.
.les_duration_read_export <- function(path, cols) {
  suppressWarnings(readr::read_csv(les_data_source(path),
                                   col_types = readr::cols(.default = readr::col_character()),
                                   col_select = tidyselect::any_of(cols),
                                   show_col_types = FALSE, progress = FALSE,
                                   name_repair = "unique"))
}

# Read a task's batch and named exports with the same batch-priority rule as the
# cognitive-index pipeline.  It prevents a participant present in both export kinds
# from contributing twice, which matters for a duration based on the first/last event.
# `files` are the export paths and `task_pattern` the task's file-name stem.  Returns the
# distinct rows of the requested columns.
.les_duration_task_raw <- function(files, task_pattern, cols) {
  is_batch <- grepl(paste0("^", task_pattern, " [0-9]+\\.csv$"), basename(files),
                    ignore.case = TRUE)
  read_set <- function(f) dplyr::bind_rows(lapply(f, .les_duration_read_export, cols = cols))
  batch <- if (any(is_batch)) read_set(files[is_batch]) else NULL
  named <- if (any(!is_batch)) read_set(files[!is_batch]) else NULL
  if (is.null(batch)) return(dplyr::distinct(named))
  if (is.null(named)) return(dplyr::distinct(batch))
  id <- "Participant Public ID"
  if (id %in% names(batch) && id %in% names(named)) {
    named <- named[!(as.character(named[[id]]) %in% unique(as.character(batch[[id]]))), ,
                   drop = FALSE]
  }
  dplyr::distinct(dplyr::bind_rows(batch, named))
}

# The participant key's lab IDs and mini-language, as character, for the joins below.
.les_duration_key <- function() {
  key <- les_participant_key(enrolled_only = TRUE)
  data.frame(participant_home_ID = key$participant_home_ID,
             participant_lab_ID = as.character(key$participant_lab_ID),
             language = key$language, stringsAsFactors = FALSE)
}

# -----------------------------------------------------------------------------
# les_extract_home_task_durations()  --  one row per participant, session and task
# -----------------------------------------------------------------------------
# `sessions` are the home sessions to read (integer; Sessions 1 and 5 by default). Reads
# the Gorilla Stroop, digit span and serial reaction time exports of each session from
# cognitive_ef_path("Session <n>"), keeping only "Participant Public ID", "Event Index"
# and "UTC Timestamp" (all read as text), and the participant key
# (les_participant_key()).  Rows with no home ID or no finite timestamp are dropped, and
# an event repeated across export files (same home ID, Event Index and timestamp) is
# counted once.  Returns a data frame with columns session (integer), task (factor:
# stroop, digit_span, asrt), duration_min ((last - first timestamp) / 60000, so idle time
# is included), n_events (the events behind that duration), participant_lab_ID
# (character) and language, ordered by session, task and lab ID.  Only participants whose
# home ID has a lab ID in the key are kept, and the home ID itself is not returned (see
# the note inside).  Stops when a session folder, a task's exports or their columns are
# missing.
les_extract_home_task_durations <- function(sessions = LES_DURATION_HOME_SESSIONS) {
  cols <- c("Participant Public ID", "Event Index", "UTC Timestamp")
  rows <- list()
  for (session in sessions) {
    dir <- cognitive_ef_path(paste0("Session ", session))
    for (task in names(.les_duration_task_files)) {
      files <- les_data_list(dir, paste0(.les_duration_task_files[[task]], ".*\\.csv$"))
      if (!length(files)) {
        stop("[durations] no ", task, " export listed for home Session ", session, call. = FALSE)
      }
      raw <- .les_duration_task_raw(files, .les_duration_task_files[[task]], cols)
      if (!all(c("Participant Public ID", "UTC Timestamp") %in% names(raw))) {
        stop("[durations] the Session ", session, " ", task, " exports lack ",
             "'Participant Public ID' or 'UTC Timestamp'", call. = FALSE)
      }
      d <- data.frame(
        participant_home_ID = as.character(raw[["Participant Public ID"]]),
        event_index = if ("Event Index" %in% names(raw)) as.character(raw[["Event Index"]])
                      else NA_character_,
        event_ts_ms = .les_duration_num(raw[["UTC Timestamp"]]),
        stringsAsFactors = FALSE
      )
      d <- d[!is.na(d$participant_home_ID) & nzchar(d$participant_home_ID) &
               is.finite(d$event_ts_ms), , drop = FALSE]
      if (!nrow(d)) {
        stop("[durations] the Session ", session, " ", task, " exports hold no event with ",
             "a home ID and a timestamp", call. = FALSE)
      }
      # Gorilla can log two events in the same millisecond, so an event is identified by
      # its Event Index as well as its timestamp; an identical event in two exports is
      # still counted once.
      d <- dplyr::distinct(d)
      one <- dplyr::summarise(
        dplyr::group_by(d, participant_home_ID),
        start_ms = min(event_ts_ms), end_ms = max(event_ts_ms),
        n_events = dplyr::n(), .groups = "drop"
      )
      one$duration_min <- (one$end_ms - one$start_ms) / 60000
      one$session <- as.integer(session)
      one$task <- task
      # Neither the timestamps (start_ms, end_ms) nor the home ID are carried into the
      # written table.  The timestamps come from the Gorilla export's "UTC Timestamp"
      # column, so they are absolute wall-clock times, and the home ID is the export's
      # own participant key: beside the lab ID, either would let a reader of the
      # published table find when each participant sat each task, which in a cohort of
      # this size is re-identifying.  The manuscripts read the difference, which carries
      # no date.  The lab table keeps its start_ms and end_ms because those are offsets
      # within a session, not wall-clock times.
      rows[[length(rows) + 1L]] <- one[, c("participant_home_ID", "session", "task",
                                           "duration_min", "n_events")]
    }
  }
  out <- dplyr::bind_rows(rows)
  if (!nrow(out)) stop("[durations] no home-task duration could be computed", call. = FALSE)
  out <- dplyr::inner_join(out, .les_duration_key(), by = "participant_home_ID")
  out$task <- factor(out$task, levels = names(.les_duration_task_files))
  out <- out[order(out$session, out$task, out$participant_lab_ID),
             c("session", "task", "duration_min", "n_events", "participant_lab_ID", "language"),
             drop = FALSE]
  rownames(out) <- NULL
  out
}

.les_duration_phase_start <- c(
  pretraining = "time_PRETRAINING",
  training    = "time_TRAINING",
  test        = "time_TEST",
  experiment  = "time_EXPERIMENT"
)
.les_duration_phase_end <- list(
  pretraining = c("time_pretraining_loop", "time_pretraining_instructions",
                  "time_pretraining_instructions_en"),
  training    = c("time_training_sequence", "time_training_loop",
                  "time_training_instructions", "time_training_instructions_en"),
  test        = c("time_test_sequence", "time_process_Test_response",
                  "time_test_instructions", "time_test_instructions_en"),
  experiment  = c("time_experiment_sequence", "time_experiment_end_trigger",
                  "time_stop_recording", "time_end_of_task")
)
stopifnot(identical(names(.les_duration_phase_start), names(LES_DURATION_PHASE_LABELS)),
          identical(names(.les_duration_phase_end), names(LES_DURATION_PHASE_LABELS)))

.les_duration_first <- function(d, col) {
  if (!col %in% names(d)) return(NA_real_)
  x <- .les_duration_num(d[[col]])
  x <- x[is.finite(x)]
  if (length(x)) min(x) else NA_real_
}

.les_duration_last <- function(d, cols, after = -Inf) {
  cols <- intersect(cols, names(d))
  if (!length(cols)) return(NA_real_)
  x <- unlist(lapply(cols, function(col) .les_duration_num(d[[col]])),
              use.names = FALSE)
  x <- x[is.finite(x) & x > after]
  if (length(x)) max(x) else NA_real_
}

# The delimiter rule of the lab extractor: "," (the rule the committed table was built
# with) unless LES_DURATIONS_SNIFF_DELIM=1, in which case NULL, so that
# les_read_lab_log() takes each log's delimiter from its header line.
.les_duration_lab_delim <- function() {
  if (identical(Sys.getenv("LES_DURATIONS_SNIFF_DELIM"), "1")) NULL else ","
}

# -----------------------------------------------------------------------------
# les_extract_lab_phase_durations()  --  one row per participant, lab session and phase
# -----------------------------------------------------------------------------
# `sessions` are the lab sessions to read (integer; Sessions 2, 3, 4 and 6 by default).
# `delim` is the delimiter rule passed to les_read_lab_log(): "," by default, NULL to take
# each log's delimiter from its header (see the file header and LES_DURATIONS_SNIFF_DELIM).
# Reads every logfile that les_lab_log_files() lists, split parts included, keeping only
# the time_ phase markers, and the participant key.  Returns a data frame with columns
# participant_lab_ID (character, from the file name), session (integer), phase (factor:
# pretraining, training, test, experiment), start_ms and end_ms (offsets within the
# session, in ms), duration_min, boundary ("next phase start" or "last phase event"),
# source_file and language (from the key; NA when the key has no such lab ID), ordered by
# session, phase and lab ID.  A phase gets a row only when its start marker is present and
# an end follows it.  Warns, naming them, about logfiles that gave no row, because a
# silent loss there is how two Session-4 participants went missing (ISSUES.md X6-01).
les_extract_lab_phase_durations <- function(sessions = LES_DURATION_LAB_SESSIONS,
                                            delim = .les_duration_lab_delim()) {
  logs <- les_lab_log_files(sessions)       # warns about names without a lab ID
  logs <- logs[!is.na(logs$participant_lab_ID), , drop = FALSE]
  lab_cols <- unique(c(unname(.les_duration_phase_start),
                       unlist(.les_duration_phase_end, use.names = FALSE)))
  phase_order <- names(.les_duration_phase_start)
  rows <- list()
  no_rows <- character(0)
  for (i in seq_len(nrow(logs))) {
    d <- suppressWarnings(les_read_lab_log(logs$path[i], cols = lab_cols, delim = delim))
    n_before <- length(rows)
    starts <- vapply(.les_duration_phase_start,
                     function(col) .les_duration_first(d, col), numeric(1))
    for (phase in phase_order) {
      start <- starts[[phase]]
      if (!is.finite(start)) next
      idx <- match(phase, phase_order)
      later <- if (idx < length(phase_order)) starts[(idx + 1L):length(phase_order)] else numeric()
      later <- later[is.finite(later) & later > start]
      if (length(later)) {
        end <- min(later)
        boundary <- "next phase start"
      } else {
        end <- .les_duration_last(d, .les_duration_phase_end[[phase]], after = start)
        boundary <- "last phase event"
      }
      if (!is.finite(end) || end <= start) next
      rows[[length(rows) + 1L]] <- data.frame(
        participant_lab_ID = as.character(logs$participant_lab_ID[i]),
        session = logs$session[i], phase = phase,
        start_ms = start, end_ms = end,
        duration_min = (end - start) / 60000,
        boundary = boundary, source_file = logs$file[i],
        stringsAsFactors = FALSE
      )
    }
    if (length(rows) == n_before) {
      no_rows <- c(no_rows, paste0("Session ", logs$session[i], "/", logs$file[i],
                                   " (read with delimiter '", attr(d, "delim"), "')"))
    }
  }
  if (length(no_rows)) {
    warning("[durations] ", length(no_rows), " lab logfile(s) gave no phase row: ",
            paste(no_rows, collapse = ", "),
            if (identical(delim, ",")) paste0(". A semicolon-delimited log reads as one ",
              "column under the comma rule; LES_DURATIONS_SNIFF_DELIM=1 reads it.") else ".",
            call. = FALSE)
  }
  out <- dplyr::bind_rows(rows)
  if (!nrow(out)) stop("[durations] no lab-phase duration could be computed", call. = FALSE)
  key <- .les_duration_key()[, c("participant_lab_ID", "language")]
  out <- dplyr::left_join(out, key, by = "participant_lab_ID")
  out$phase <- factor(out$phase, levels = phase_order)
  out <- out[order(out$session, out$phase, out$participant_lab_ID), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# -----------------------------------------------------------------------------
# les_write_task_duration_artifacts()  --  write both tables into both papers
# -----------------------------------------------------------------------------
# Takes no arguments; run by Paper 2's step 13 (13_extract_task_durations.R). Extracts
# both tables, checks the four target paths with les_assert_readonly_data() and only then
# writes _task_durations_home.csv and _task_durations_lab.csv into paper1_results() and
# paper2_results(), overwriting the copies there, so either paper renders on its own.  Any
# read failure stops the run before the first write.  Returns list(home, lab) invisibly.
les_write_task_duration_artifacts <- function() {
  home <- les_extract_home_task_durations()
  lab  <- les_extract_lab_phase_durations()
  targets <- list(
    home = c(paper1_results("_task_durations_home.csv"),
             paper2_results("_task_durations_home.csv")),
    lab  = c(paper1_results("_task_durations_lab.csv"),
             paper2_results("_task_durations_lab.csv"))
  )
  les_assert_readonly_data(c(targets$home, targets$lab))
  for (p in targets$home) readr::write_csv(home, p, na = "")
  for (p in targets$lab)  readr::write_csv(lab, p, na = "")
  message(sprintf("[durations] home rows=%d; lab rows=%d", nrow(home), nrow(lab)))
  invisible(list(home = home, lab = lab))
}

# -----------------------------------------------------------------------------
# les_task_duration_median_text()  --  the median-duration sentence of both papers
# -----------------------------------------------------------------------------
# `home` and `lab` are the two tables as the manuscripts read them from results/ (NULL
# when absent); `digits` sets the decimals.  Returns one character string for inline use:
# the sentence, or a placeholder sentence when either table is absent or empty.  The
# sentence names which phases each lab session recorded, so it is built only when the
# cells with a finite duration are exactly the ones it describes (every home task in
# Sessions 1 and 5; all four phases in Sessions 2 and 3; training, test and experiment in
# Session 4; the experiment in Session 6).  Otherwise it warns and returns a visible
# pending marker, so a re-extraction that gains or loses a phase cannot print a false
# statement or "NA min".  The medians are computed over the tables' rows, never typed.
les_task_duration_median_text <- function(home, lab, digits = 2) {
  if (is.null(home) || !nrow(home) || is.null(lab) || !nrow(lab)) {
    return("Median task and phase durations will be reported once the duration artefacts are available.")
  }
  cells <- function(d, by) {
    ok <- is.finite(.les_duration_num(d$duration_min))
    sort(unique(paste(d$session[ok], d[[by]][ok])))
  }
  named_home <- sort(paste(rep(LES_DURATION_HOME_SESSIONS, each = 3),
                           rep(names(.les_duration_task_files), 2)))
  named_lab <- sort(c(paste(2, names(LES_DURATION_PHASE_LABELS)),
                      paste(3, names(LES_DURATION_PHASE_LABELS)),
                      paste(4, c("training", "test", "experiment")),
                      paste(6, "experiment")))
  if (!identical(cells(home, "task"), named_home) || !identical(cells(lab, "phase"), named_lab)) {
    warning("les_task_duration_median_text(): the sessions and phases with a recorded ",
            "duration no longer match those the sentence names; rewrite the sentence.",
            call. = FALSE)
    return("*[median durations pending: the recorded sessions and phases have changed]*")
  }
  fmt <- function(x) formatC(stats::median(x[is.finite(x)]),
                              format = "f", digits = digits)
  home_med <- function(session, task) {
    x <- .les_duration_num(home$duration_min[
      as.character(home$session) == as.character(session) &
        as.character(home$task) == task])
    fmt(x)
  }
  lab_med <- function(session, phase) {
    x <- .les_duration_num(lab$duration_min[
      as.character(lab$session) == as.character(session) &
        as.character(lab$phase) == phase])
    fmt(x)
  }
  paste0(
    "The median home-task durations were ",
    home_med(1, "stroop"), " min for Stroop, ",
    home_med(1, "digit_span"), " min for digit span and ",
    home_med(1, "asrt"), " min for ASRT in Session 1, and ",
    home_med(5, "stroop"), ", ", home_med(5, "digit_span"), " and ",
    home_med(5, "asrt"), " min, respectively, in Session 5. Median laboratory-phase ",
    "durations (pretraining, training, test and experiment) were ",
    lab_med(2, "pretraining"), ", ", lab_med(2, "training"), ", ",
    lab_med(2, "test"), " and ", lab_med(2, "experiment"), " min in Session 2; ",
    lab_med(3, "pretraining"), ", ", lab_med(3, "training"), ", ",
    lab_med(3, "test"), " and ", lab_med(3, "experiment"), " min in Session 3; ",
    lab_med(4, "training"), ", ", lab_med(4, "test"), " and ",
    lab_med(4, "experiment"), " min for training, test and experiment in Session 4, ",
    "where pretraining was not recorded; and ", lab_med(6, "experiment"),
    " min for the experiment in Session 6, where the other phases were not recorded."
  )
}

# The two duration figures of both manuscripts. Keeping the geometry here gives the two
# papers identical axes, facet order and dispersion summaries. Both draw session on x
# within one panel per task or phase, on a logarithmic duration axis, because the
# durations span two orders of magnitude between tasks and are right-skewed within them.
# They call les_theme(), les_placeholder(), les_lab_num() and LES_INK, so
# 06_manuscript_helpers.R has to be sourced first, and base_size defaults to the
# manuscripts' LES_FIG_BASE_SIZE.  Each takes the table as the manuscripts read it from
# results/ (`data`, NULL when absent) and returns a ggplot, or the placeholder when there
# is nothing to draw; neither writes a file.

# Participants as jittered grey points beneath an unfilled box per session. The jitter
# is seeded, so the points do not move between renders. `cap` limits the points to the
# visible range; the boxes are computed over every row, so a value beyond the axis
# still enters the median, quartiles and whiskers.
.les_duration_layers <- function(cap = Inf) list(
  ggplot2::geom_point(data = function(d) d[d$duration_min <= cap, , drop = FALSE],
                      position = ggplot2::position_jitter(width = 0.13, height = 0,
                                                          seed = 2026),
                      shape = 16, size = 0.9, colour = "grey60"),
  ggplot2::geom_boxplot(width = 0.5, fill = NA, colour = "black", linewidth = 0.4,
                        median.linewidth = 0.9, staplewidth = 0, outlier.shape = NA))

.les_duration_pending <- function(what) les_placeholder(paste(what, "data pending"))

# The axis limits are fixed so the two papers' figures match. coord_cartesian() drops a
# point outside them without a warning (and no off-scale marker counts it), so a
# re-extraction that produced such a duration must say so.
.les_duration_check_range <- function(x, lo, hi, what) {
  out <- sum(x < lo | x > hi)
  if (out > 0)
    warning(sprintf("%s: %d duration(s) fall outside the axis range %s to %s min and are not drawn as points; widen the limits.",
                    what, out, format(lo), format(hi)), call. = FALSE)
  invisible(out)
}

# `cap` is the top of the axis, in minutes: durations above it are counted by the marker.
les_task_duration_home_plot <- function(data, base_size = LES_FIG_BASE_SIZE, cap = 100) {
  if (is.null(data) || !nrow(data)) return(.les_duration_pending("Home-task duration"))
  d <- data |>
    dplyr::filter(is.finite(duration_min), session %in% LES_DURATION_HOME_SESSIONS) |>
    dplyr::mutate(
      task = factor(task, levels = names(LES_DURATION_TASK_LABELS),
                    labels = unname(LES_DURATION_TASK_LABELS)),
      session = factor(session, levels = LES_DURATION_HOME_SESSIONS))
  if (!nrow(d)) return(.les_duration_pending("Home-task duration"))
  # A few exports contain a multi-hour idle gap. Drawn to scale, those durations would
  # compress every other point into the bottom of the panel, so they sit beyond the top
  # of the axis, and a triangle with their number marks each task and session that has
  # any. The count is computed here, never typed.
  off <- dplyr::count(d[d$duration_min > cap, , drop = FALSE], task, session, .drop = TRUE)
  # 2 to 130 min with the default cap; the top leaves room for the marker at cap * 1.18.
  ylim <- c(2, max(130, cap * 1.3))
  # Durations above the cap are counted by the marker; only the lower limit can lose one.
  .les_duration_check_range(d$duration_min[d$duration_min <= cap], ylim[1], cap,
                            "les_task_duration_home_plot()")
  ggplot2::ggplot(d, ggplot2::aes(x = session, y = duration_min)) +
    .les_duration_layers(cap) +
    ggplot2::geom_point(data = off, ggplot2::aes(x = session, y = cap * 1.18),
                        inherit.aes = FALSE, shape = 17, size = 1.9, colour = "black") +
    ggplot2::geom_text(data = off, ggplot2::aes(x = session, y = cap * 1.18, label = n),
                       inherit.aes = FALSE, hjust = 0, nudge_x = 0.09, colour = LES_INK) +
    ggplot2::facet_grid(. ~ task) +
    # No vertical expansion: the limits leave the headroom the off-scale marker needs.
    ggplot2::scale_y_log10(breaks = c(2, 5, 10, 20, 50, 100), labels = les_lab_num,
                           expand = c(0, 0)) +
    ggplot2::coord_cartesian(ylim = ylim) +
    ggplot2::labs(x = "Session", y = "Duration (min)") +
    les_theme(base_size, grid = "y") +
    ggplot2::theme(legend.position = "none")
}

les_task_duration_lab_plot <- function(data, base_size = LES_FIG_BASE_SIZE) {
  if (is.null(data) || !nrow(data)) return(.les_duration_pending("Laboratory-phase duration"))
  d <- data |>
    dplyr::filter(is.finite(duration_min), session %in% LES_DURATION_LAB_SESSIONS) |>
    dplyr::mutate(
      phase = factor(phase, levels = names(LES_DURATION_PHASE_LABELS),
                     labels = unname(LES_DURATION_PHASE_LABELS)),
      session = factor(session, levels = LES_DURATION_LAB_SESSIONS))
  if (!nrow(d)) return(.les_duration_pending("Laboratory-phase duration"))
  # Pretraining was not recorded at Session 4 and only the experiment phase at Session
  # 6, so each panel spans only the sessions its phase has; free widths keep one session
  # step the same physical width in every panel.
  ylim <- c(0.6, 150)
  .les_duration_check_range(d$duration_min, ylim[1], ylim[2], "les_task_duration_lab_plot()")
  ggplot2::ggplot(d, ggplot2::aes(x = session, y = duration_min)) +
    .les_duration_layers() +
    ggplot2::facet_grid(. ~ phase, scales = "free_x", space = "free_x") +
    ggplot2::scale_y_log10(breaks = c(1, 2, 5, 10, 20, 50, 100), labels = les_lab_num,
                           expand = c(0, 0)) +
    ggplot2::coord_cartesian(ylim = ylim) +
    ggplot2::labs(x = "Session", y = "Duration (min)") +
    les_theme(base_size, grid = "y") +
    ggplot2::theme(legend.position = "none")
}
