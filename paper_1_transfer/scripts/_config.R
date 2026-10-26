# =============================================================================
# paper_1_transfer/scripts/_config.R
# Analysis grid and shared constants for Paper 1
#   "The Neurocognition of Longitudinal L3 Morphosyntactic Transfer"
# =============================================================================
#
# PURPOSE
# -------
# This file is the single source of truth for *what* Paper 1 analyses, kept
# separate from *how* it is analysed (the numbered pipeline scripts). It enumerates
# the event-related potential (ERP) analysis cells and the design constants shared
# by the extraction, modelling and reporting steps. Centralising the grid here
# prevents the silent drift between scripts that affected the legacy, per-cell
# `EEG_*_lmerTest.R` files (where windows, regions and file patterns were re-typed
# in every script).
#
# DESIGN OF THE ERP ANALYSIS
# --------------------------
# Paper 1 models single-trial mean ERP amplitudes in three theory-driven time
# windows, separately for lateral and midline electrode clusters, and separately
# for each of the three target morphosyntactic properties. This 3 (property) x 3
# (window) x 2 (macroregion) = 18-cell grid reproduces the spatiotemporal
# decomposition of the established LESS pipeline.
#
# CHOICE OF THE THREE TIME WINDOWS
# --------------------------------
# The windows are chosen a priori to capture the ERP components that index
# morphosyntactic processing, rather than being selected from the data (which
# would inflate Type-I error; Luck & Gaspelin, 2017, Psychophysiology,
# https://doi.org/10.1111/psyp.12639):
#   * 200-500 ms : the LAN / early negativity window (early, often automatic
#                  morphosyntactic agreement processing).
#   * 300-600 ms : the N400 window (lexical-semantic / form-based retrieval).
#   * 400-900 ms : the P600 window (controlled syntactic reanalysis and repair).
# These components and their latencies for agreement and word-order violations
# are documented by Osterhout & Holcomb (1992, JML,
# https://doi.org/10.1016/0749-596X(92)90039-Z); Friederici (2002, TiCS,
# https://doi.org/10.1016/S1364-6613(00)01839-8); and, for L2/L3 learners,
# Morgan-Short et al. (2012, JoCN, https://doi.org/10.1162/jocn_a_00119) and
# Gonzalez Alonso et al. (2020, J. Neurolinguistics,
# https://doi.org/10.1016/j.jneuroling.2020.100939). The windows intentionally
# overlap because the underlying components do; each cell is modelled separately,
# so the overlap does not introduce any statistical dependency between cells.
#
# WINDOW UPPER BOUNDS (498/598/898, not 500/600/900)
# --------------------------------------------------
# The bounds are inherited from the validated importer, whose own `time_window` label
# is assigned with time <= 498 / 598 / 898 (see the time_window case_when in
# data/R_functions/import_trialbytrial_EEG_data.R). Reusing them means this pipeline
# averages exactly the samples the established descriptive pipeline assigned to each
# window, so the two remain directly comparable. The nominal 500, 600 and 900 ms
# samples do exist on the acquisition grid, seq(-100, 1098, by = 2). They are left out
# by that inherited convention rather than by anything in the sampling.
# =============================================================================

# --- Shared infrastructure ----------------------------------------------------
if (!exists("data_path"))            source(here::here("_shared", "R", "00_paths.R"))
if (!exists("erp_single_trials_path")) source(here::here("_shared", "R", "03_data_manifest.R"))

# --- Target morphosyntactic properties ---------------------------------------
# Reuse the canonical property <-> marker-code map from the data manifest so that
# the file-name codes (S1/S2/S3) are defined in exactly one place.
LES_P1_PROPERTIES <- LES_PROPERTY_CODES   # c(gender_agreement = "S1", ...)

# --- ERP analysis time windows (inclusive bounds, in ms) ---------------------
LES_P1_WINDOWS <- list(
  "200_500" = c(min_ms = 200, max_ms = 498),
  "300_600" = c(min_ms = 300, max_ms = 598),
  "400_900" = c(min_ms = 400, max_ms = 898)
)

# --- Acquisition epoch (ms) ---------------------------------------------------
# The importer samples every epoch on the fixed grid seq(-100, 1098, by = 2). The
# full-epoch extractions (07, 07b) and the decoding tensor (08) load these bounds; the
# single-trial extraction (01) loads only the span of LES_P1_WINDOWS plus the baseline.
# Kept unnamed: 08 places the two values in its tensor fingerprint, which is compared
# with identical(), so a names attribute would invalidate every cached tensor.
LES_P1_EPOCH_MS <- c(-100, 1098)

# --- Grammaticality-judgement reaction-time screen (ms) ----------------------
# The legacy screen: under LES_P1_ACC_RT_SCREEN=1, 02_extract_accuracy.R drops the trials
# with a response time outside (200, 4000) ms, after de-duplication. The bounds are the ones
# written into the legacy behavioural import script, which cannot run as committed and
# records no rationale for them (see the header of 02_extract_accuracy.R). On 17 October
# 2026 they stayed the primary rule, with an unscreened sensitivity analysis. On 19 October
# the author asked for the most rigorous resolution, and the roles were swapped
# (ISSUES.md G06-03):
#   * the screen selects on the outcome (the trials of 200 ms or less are the most accurate,
#     those of 4000 ms or more the least);
#   * it removes unequal shares of the two language groups' trials;
#   * the 200 ms bound has no basis here, because the judgement is prompted only after the
#     sentence has ended.
# The primary extraction therefore keeps every judgement, and the screen is the sensitivity
# analysis (LES_P1_ACC_RT_SCREEN below).
LES_P1_ACC_RT_MS <- c(200, 4000)

# --- RSVP timing census (ms; 01b_extract_rsvp_timing.R) ----------------------
# Subsequent word onsets are counted within (0, LES_P1_RSVP_WINDOW_MS] of the critical
# onset. 900 is the late window's NOMINAL upper bound, matching the manuscript's "within
# 900 ms", and deliberately not its inclusive sample bound of 898 ms (LES_P1_WINDOWS; see
# WINDOW UPPER BOUNDS in the header): the census is about when words appear on screen, not
# about which samples a window averages. An onset-to-onset step above
# LES_P1_RSVP_SOA_MAX_MS marks a corrupt log row and excludes the trial.
LES_P1_RSVP_WINDOW_MS  <- 900
LES_P1_RSVP_SOA_MAX_MS <- 5000

# --- Default seed of the decoding stage --------------------------------------
# 09_run_decoding.R reads LES_DECODE_SEED from the environment with its own literal
# default, and hpc/08_decoding.slurm exports the same literal. The three must agree so that
# a decoding job that exports no seed runs under this configured default;
# test_exclusion_guard.R checks the two literals against it. The seed a decoding run
# actually used is recorded by hpc/08_decoding.slurm in results/_decoding_provenance.csv,
# which the manuscript reads. The ERP fitting run's results/_provenance.csv carries only
# this default and records nothing about any decoding run.
LES_P1_DECODE_SEED_DEFAULT <- 20260702L

# --- Electrode macro-regions --------------------------------------------------
# "lateral" = the six left/right clusters; "midline" = the three midline clusters. Each
# macroregion is modelled separately, on one row per trial whose amplitude is the equally
# weighted mean of the macroregion's clusters, with the same fixed effects in both (see
# 01_extract_erp_single_trials.R).
LES_P1_MACROREGIONS <- c("lateral", "midline")

# --- Version of the ERP model specification -----------------------------------
# Recorded in every ERP fit's metadata and required by the pooling step (05) and the
# manuscript's audit, so fits of different specifications can never be pooled together.
# "trial_level_2026-09-17" is one row per trial per macroregion, no hemisphere or caudality
# terms, and the by-participant grammaticality x session slope (ISSUES.md, N9). Fits
# without this value are the superseded cluster-row models.
LES_P1_ERP_MODEL_VERSION <- "trial_level_2026-09-17"

# --- Grammaticality conditions analysed --------------------------------------
# Paper 1 contrasts the canonical grammatical (S101) vs. ungrammatical (S102)
# sentences. The ancillary S103 violation conditions are excluded so that the
# grammaticality contrast has the same meaning across all three properties.
LES_P1_GRAMMATICALITY_REGEX <- "S10[12]"

# --- Datasets excluded for an incompatible offline filter ---------------------
# Nine Session-3 recordings were high-pass filtered offline at 1 Hz rather than the
# 0.1 Hz used for every other dataset in the study (recovered from the archived
# BrainVision Analyzer histories; the live node postdates the switch elsewhere, so it is
# a processing oversight rather than a superseded branch). Four of them (7, 8, 9, 16)
# were identified in July 2026. The other five (53, 60, 61, 62, 65) were found by the
# September 2026 audit (ISSUES.md, G04-01): their histories hold the same single 1 Hz
# IIR node and their exports descend from it. A scripted rebuild from the raw recordings
# reproduces all nine exports only at 1 Hz. The Session-2 history of participant 10 also
# reads 1 Hz today, but its nodes were edited after the export was written: the rebuild
# reproduces that export at 0.1 Hz, to export precision, and fails at 1 Hz by 4.5-6.0 µV,
# including on the accelerometer channels, which no reference or ICA step touches
# (ISSUES.md, N6). It is therefore not listed. A history's text is not enough evidence on
# its own; the rebuild is.
#
# The exclusion is interim. docs/eeg_filter_reprocessing_protocol.md fixes the plan: the
# raw recordings are reprocessed at 0.1 Hz, the reprocessed data enter the primary
# analysis, and this exclusion becomes the one prespecified sensitivity analysis. Until
# the reprocessed overlay has passed that protocol's validation gates, the legacy 1 Hz
# derivatives stay out of every analysis.
#
# The mismatch bears directly on the components this paper measures. Tanner,
# Morgan-Short and Luck (2015, https://doi.org/10.1111/psyp.12437) filtered data from a
# syntactic- and semantic-violation paradigm, the same design class as ours, at a range
# of cutoffs. They found that high-pass cutoffs of 0.3 Hz and above introduced
# artefactual effects of opposite polarity preceding the true N400 and P600 effects. A
# 1 Hz cutoff is well inside that range. See also Widmann, Schroger and Maess (2015,
# https://doi.org/10.1016/j.jneumeth.2014.08.002) on filter-induced distortion.
#
# These participant-sessions' legacy 1 Hz derivatives are therefore always dropped. The
# justification is a priori, resting on the documented behaviour of the filter rather than
# on anything observed in these participants' data, so the exclusion is not contingent on
# the results. The drop keys on where each row came from as well as on participant and
# session: rows read from the overlay of reprocessed 0.1 Hz exports (column eeg_source,
# written by _eeg_import.R) are kept, because the protocol makes them primary. The
# robustness analysis the protocol prespecifies drops these participant-sessions whatever
# their source, under LES_P1_EXCLUDE_REPROCESSED=1 (see below).
LES_P1_MISFILTERED <- data.frame(
  participant_lab_ID = c(7L, 8L, 9L, 16L, 53L, 60L, 61L, 62L, 65L),
  session            = 3L,
  stringsAsFactors   = FALSE
)

# NOTE: participant_lab_ID and session are FACTORS in the extracted data (session has
# levels "2","3","4","6"). as.integer() on a factor returns the LEVEL INDEX, not the
# value, so as.integer(session) would give 1,2,3,4 and silently match the wrong rows --
# "session 3" would resolve to level 3, i.e. session 4. Always go via as.character().
.les_p1_as_int <- function(x) suppressWarnings(as.integer(as.character(x)))

# Participant-session keys of `d` ("<participant> <session>", one per row), or NULL when
# `d` lacks either identifying column.
.les_p1_keys <- function(d) {
  if (!all(c("participant_lab_ID", "session") %in% names(d))) return(NULL)
  paste(.les_p1_as_int(d$participant_lab_ID), .les_p1_as_int(d$session))
}

# TRUE for rows read from the overlay of reprocessed exports. Data without the eeg_source
# column (derived files written before it existed, test fixtures) are legacy throughout.
.les_p1_from_overlay <- function(d) {
  if (!"eeg_source" %in% names(d)) return(rep(FALSE, nrow(d)))
  as.character(d$eeg_source) %in% "overlay"
}

#' Number of legacy 1 Hz rows in a data frame
#'
#' @param d A data frame of extracted EEG rows (factor or integer participant_lab_ID and
#'   session; eeg_source optional, its absence meaning legacy throughout).
#' @return The number of rows of `d` (integer) that hold the legacy (1 Hz) derivative of a
#'   participant-session in LES_P1_MISFILTERED, or NA_integer_ when `d` lacks
#'   participant_lab_ID or session. les_p1_write_fit_meta() relies on that NA for data the
#'   exclusion does not apply to. Rows read from the overlay are not counted. A primary
#'   fit must have none.
les_p1_misfiltered_rows <- function(d) {
  key <- .les_p1_keys(d)
  if (is.null(key)) return(NA_integer_)
  sum(key %in% paste(LES_P1_MISFILTERED$participant_lab_ID, LES_P1_MISFILTERED$session) &
        !.les_p1_from_overlay(d))
}

# Drop listed participant-sessions: their legacy rows always, their overlay rows only in
# the robustness analysis. `list_df` is LES_P1_MISFILTERED or LES_P1_INVALID_EXPORTS and
# `what` names it in the log. Data without the identifying columns stop the run: returning
# them unchanged would let an exclusion silently do nothing (ISSUES.md, G04-11). No caller
# passes such data.
.les_p1_drop_listed <- function(d, list_df, what) {
  key <- .les_p1_keys(d)
  if (is.null(key)) {
    stop("Cannot drop the ", what, ": the data lack participant_lab_ID and/or session.",
         call. = FALSE)
  }
  listed  <- key %in% paste(list_df$participant_lab_ID, list_df$session)
  overlay <- .les_p1_from_overlay(d)
  drop <- listed & (!overlay | les_p1_exclude_reprocessed())
  if (any(drop)) {
    # Count the datasets actually found, not the number on the list: a property that
    # was never presented in a given session legitimately matches none of its datasets.
    message(sprintf("[config] dropped %d rows from %d of the %d %s%s.",
                    sum(drop), length(unique(key[drop])), nrow(list_df), what,
                    if (les_p1_exclude_reprocessed() && any(drop & overlay))
                      " (reprocessed rows included: LES_P1_EXCLUDE_REPROCESSED=1)" else ""))
  }
  if (any(listed & overlay & !drop)) {
    message(sprintf("[config] kept %d reprocessed rows from %d of the %d %s.",
                    sum(listed & overlay & !drop),
                    length(unique(key[listed & overlay & !drop])), nrow(list_df), what))
  }
  d[!drop, , drop = FALSE]
}

#' Drop the legacy rows of the 1 Hz datasets
#'
#' @param d A data frame of extracted EEG rows with participant_lab_ID and session.
#' @return `d` without the rows of LES_P1_MISFILTERED: their legacy rows always, their
#'   overlay rows too under LES_P1_EXCLUDE_REPROCESSED=1 (read at call time). Messages the
#'   number of rows and datasets dropped and kept, and stops when `d` lacks either column.
les_p1_drop_misfiltered <- function(d) .les_p1_drop_listed(d, LES_P1_MISFILTERED, "mis-filtered (1 Hz) datasets")

# --- Participants excluded for a protocol deviation ---------------------------
# Participant 14 was assigned to Mini-Norwegian, and their Sessions 3, 4 and 6 ran the
# Norway experiment files in Mini-Norwegian. Their Session 2, however, ran the Spanish
# site's experiment file (Spain_Session_2.osexp) on the Tromso workstation. That file
# hard-codes the Spain site and so read row 14 of the Spain parameter table, which
# assigns Mini-English. The logfile records Mini-English throughout, and all 144 target
# trigger quartets it logs occur, in order, in the raw EEG marker stream, so the wrong
# language was genuinely presented rather than mislabelled (ISSUES.md, X5-01).
#
# Session 2 is where the lexicon and gender agreement are first trained, so this
# participant learned one miniature language's vocabulary and then continued in the
# other. Their trajectory belongs to neither group, and relabelling a session cannot
# make it comparable. They are excluded from every analysis that involves the language
# group or the learning trajectory: the ERP, accuracy and decoding analyses and the
# group displays in Paper 1, and both parts of Paper 2. They remain in the enrolment and
# attrition counts. The decision was taken on 16 September 2026, before any analysis of
# this participant's data, on the design argument above.
LES_P1_PROTOCOL_DEVIATION <- data.frame(
  participant_lab_ID = 14L,
  reason             = "Session 2 ran the Spanish-site experiment (Mini-English) for a Mini-Norwegian participant",
  stringsAsFactors   = FALSE
)

#' Number of rows of an excluded participant
#'
#' @param d A data frame with a factor, integer or character participant_lab_ID.
#' @return The number of rows (integer) that belong to a participant in
#'   LES_P1_PROTOCOL_DEVIATION, or NA_integer_ when `d` has no participant_lab_ID column.
#'   Factor-safe for the same reason as les_p1_misfiltered_rows().
les_p1_deviation_rows <- function(d) {
  if (!"participant_lab_ID" %in% names(d)) return(NA_integer_)
  id <- suppressWarnings(as.integer(as.character(d$participant_lab_ID)))
  sum(id %in% LES_P1_PROTOCOL_DEVIATION$participant_lab_ID)
}

#' Drop the participant excluded for a protocol deviation
#'
#' Used by both papers (Paper 2 through les_p2_drop_protocol_deviation()).
#' @param d A data frame.
#' @return `d` without the rows of LES_P1_PROTOCOL_DEVIATION, with a message giving the
#'   number dropped. `d` is returned unchanged when it has no participant_lab_ID column,
#'   which some Paper 2 tables legitimately lack.
les_p1_drop_protocol_deviation <- function(d) {
  n_bad <- les_p1_deviation_rows(d)
  if (is.na(n_bad) || n_bad == 0L) return(d)
  id <- suppressWarnings(as.integer(as.character(d$participant_lab_ID)))
  message(sprintf("[config] dropped %d rows of %d participant(s) excluded for a protocol deviation.",
                  n_bad, length(unique(id[id %in% LES_P1_PROTOCOL_DEVIATION$participant_lab_ID]))))
  d[!(id %in% LES_P1_PROTOCOL_DEVIATION$participant_lab_ID), , drop = FALSE]
}

# --- Exports that do not contain the participant-session they are named for -------
# The 16 September 2026 audit matched every exported trial to its own recording through
# the export's marker timestamps and the processing history, and a screen of all 210
# exports then checked that each carries a stimulus-locked response (ISSUES.md, N6). Three
# exports failed, and each failure was confirmed on the EEG itself:
#
# * Session 3 of participant 48. The history processed participant 58's Session-3
#   recording (its root markers start at 58's recording time, not at 48's), so the
#   export is a second copy of 58's EEG. All 198 trial timestamps coincide with 58's,
#   and trials paired by timestamp correlate at a median r = .90 at Pz, where trials of
#   two different participants correlate at chance. The copy would count one person's
#   brain activity twice and attribute half of it to someone else.
# * Session 6 of participant 5. The history reads the Session-4 marker file, so the
#   Session-6 EEG was segmented at Session-4 event times. The epochs are not
#   time-locked to any stimulus: the split-half reliability of the posterior average
#   over 0-600 ms is r = .28, against .75-.96 for the other recordings screened, and
#   trials paired by timestamp with the Session-4 export correlate at r = .00.
# * Session 2 of participant 7. The history starts from a different recording (10:38)
#   from the archived raw file (11:27) and carries marker-edit and segmentation nodes
#   before inspection. The epochs carry no stimulus-locked response: split-half
#   reliability r = .00 (-.07 on the grammatical and ungrammatical trials alone), and the
#   average correlates at r = -.02 with the leave-one-out Session-2 grand average, where
#   the same participant's Sessions 3, 4 and 6 reach split-half r = .96-.98.
#
# None of these exports measures what its label says, so none can enter any analysis.
# docs/eeg_filter_reprocessing_protocol.md (Amendments 2 and 3) fixes which of them can be
# recovered from the raw recordings. As for the 1 Hz datasets, the legacy exports are
# always dropped, a recovered export read from the overlay enters the primary analysis,
# and the robustness analysis (LES_P1_EXCLUDE_REPROCESSED=1) drops the participant-session
# whatever its source. No switch ever admits the legacy exports: there is no analysis in
# which a duplicated or misaligned epoch is admissible data.
LES_P1_INVALID_EXPORTS <- data.frame(
  participant_lab_ID = c(48L, 5L, 7L),
  session            = c(3L, 6L, 2L),
  reason             = c("export duplicates participant 58's Session-3 recording",
                         "Session-6 EEG segmented at the Session-4 marker times; not time-locked",
                         "history starts from another recording; epochs not time-locked"),
  stringsAsFactors   = FALSE
)

#' Number of legacy invalid-export rows in a data frame
#'
#' @param d As for les_p1_misfiltered_rows().
#' @return The number of rows (integer) that hold the legacy export of a participant-session
#'   in LES_P1_INVALID_EXPORTS, or NA_integer_ without the identifying columns. Overlay rows
#'   are not counted. No fit may contain any.
les_p1_invalid_export_rows <- function(d) {
  key <- .les_p1_keys(d)
  if (is.null(key)) return(NA_integer_)
  sum(key %in% paste(LES_P1_INVALID_EXPORTS$participant_lab_ID, LES_P1_INVALID_EXPORTS$session) &
        !.les_p1_from_overlay(d))
}

#' Number of reprocessed or recovered rows in a data frame
#'
#' @param d As for les_p1_misfiltered_rows().
#' @return The number of rows (integer) read from the overlay for a participant-session on
#'   LES_P1_MISFILTERED or LES_P1_INVALID_EXPORTS, or NA_integer_ without the identifying
#'   columns. The robustness analysis must have none; the primary analysis includes them.
les_p1_reprocessed_rows <- function(d) {
  key <- .les_p1_keys(d)
  if (is.null(key)) return(NA_integer_)
  listed <- rbind(LES_P1_MISFILTERED[c("participant_lab_ID", "session")],
                  LES_P1_INVALID_EXPORTS[c("participant_lab_ID", "session")])
  sum(key %in% paste(listed$participant_lab_ID, listed$session) & .les_p1_from_overlay(d))
}

#' Drop the legacy rows of the invalid exports
#'
#' @param d As for les_p1_drop_misfiltered().
#' @return `d` without the rows of LES_P1_INVALID_EXPORTS, on the same rules and with the
#'   same messages and stop as les_p1_drop_misfiltered().
les_p1_drop_invalid_exports <- function(d) .les_p1_drop_listed(d, LES_P1_INVALID_EXPORTS, "invalid exports")

#' Apply every EEG exclusion
#'
#' Every EEG extraction applies the exclusions through this one entry point, so the ERP
#' models, the grand averages, the topographies and the decoding tensor cannot disagree
#' about who is in the sample.
#' @param d A data frame of extracted EEG rows with participant_lab_ID and session.
#' @return `d` after les_p1_drop_misfiltered(), les_p1_drop_invalid_exports() and
#'   les_p1_drop_protocol_deviation(), in that order.
les_p1_apply_eeg_exclusions <- function(d) {
  les_p1_drop_protocol_deviation(les_p1_drop_invalid_exports(les_p1_drop_misfiltered(d)))
}

# --- Session-2 reference: bring the exports to the linked-mastoid convention -----------
# Every analysis in this paper assumes data referenced to the mean of TP9 and TP10, with
# the online reference recovered as FCz. The Session-3, -4 and -6 exports meet that: their
# New Reference node averaged the two mastoids and discarded them, and their ocular ICA
# ran on the remaining 30 electrodes. The Session-2 exports do not (ISSUES.md, N6). In all
# 63 Session-2 histories the node also averaged in the implicit online reference, which is
# identically zero, and kept TP9 and TP10 against the online reference; the ICA then ran on
# the 30 scalp electrodes plus TP9 and TP10, but not on FCz. With t the mean of the two
# mastoids against the online reference, a Session-2 electrode leaves re-referencing as
# c - 2t/3, TP9 and TP10 as themselves and FCz as -2t/3, and the ICA then removes its
# components from everything except FCz.
#
# The correction applied here, per channel and sample of every Session-2 export, is
#
#     c_conv   = c_export - (TP9_export + TP10_export) / 6     (the 30 scalp electrodes)
#     FCz_conv = 1.5 * FCz_export
#
# with TP9, TP10 and the accelerometer channels left as exported (no analysis uses them).
# The scalp formula re-references the analyst's ICA-cleaned data to the ICA-cleaned
# mastoids, an identity that needs no assumption about the ICA; FCz bypassed the ICA, so
# 1.5 times its exported value is exactly -t, as in the other sessions.
#
# An earlier version added FCz_export / 2 to every channel. Before the ICA that is the same
# map, but after it the formula re-references cleaned scalp channels to UNCLEANED mastoids
# and adds back a third of each removed component's FCz potential. Its 16 September
# validation could not detect this, because its target was built with the same map. Three
# checks on 17 September favoured the present formula (trial_audit/verify2 in the job
# scratch): the identity above holds on the exports to quantisation precision; against a
# never-exported linked-mastoid ICA branch that the analyst built in participant 45's
# Session-2 history, its operator error is 0.063 against 0.247; and in an independent
# replication with a different ICA implementation on four Session-3 recordings it was
# closer to a linked-mastoid refit in 21 of 24 condition cells (median absolute error in
# the S102 - S101 contrast 0.03 against 0.13 microvolts). No export-level correction can
# reproduce what a 30-channel ICA would have removed where the Session-2 analyst removed a
# non-ocular component, and in one such recording the earlier formula is closer. Across
# the 61 analysed participants the two formulas differ in the Session-2 S102 - S101
# contrast by a median of 0.26 microvolts, and by about 0.02 microvolts in the group mean.
#
# The correction is applied inside the importer (_eeg_import.R) as each file is read.
LES_P1_S2_REFERENCE_CHANNELS <- c("TP9", "TP10", "FCz")
LES_P1_NON_EEG_CHANNELS      <- c("x_dir", "y_dir", "z_dir")

#' Bring one Session-2 export to the linked-mastoid convention
#'
#' @param values Numeric matrix with one row per channel and one column per sample, as
#'   exported (vectorised orientation).
#' @param channels Character vector naming the rows of `values`.
#' @return The corrected matrix: the 30 scalp electrodes minus (TP9 + TP10) / 6, FCz times
#'   1.5, every other row unchanged. Stops if the export lacks a channel the correction
#'   needs, because a Session-2 export without them was not produced by the Session-2
#'   reference node, or if a channel name is repeated.
les_p1_s2_rereference <- function(values, channels) {
  missing <- setdiff(LES_P1_S2_REFERENCE_CHANNELS, channels)
  if (length(missing))
    stop("Session-2 export lacks ", paste(missing, collapse = "/"),
         ", so the Session-2 reference correction cannot be applied.", call. = FALSE)
  if (anyDuplicated(channels)) stop("Duplicated channel names in a Session-2 export.", call. = FALSE)
  sixth <- (values[match("TP9", channels), ] + values[match("TP10", channels), ]) / 6
  scalp <- which(!(channels %in% c(LES_P1_S2_REFERENCE_CHANNELS, LES_P1_NON_EEG_CHANNELS)))
  values[scalp, ] <- values[scalp, , drop = FALSE] -
    matrix(sixth, nrow = length(scalp), ncol = length(sixth), byrow = TRUE)
  fcz <- match("FCz", channels)
  values[fcz, ] <- 1.5 * values[fcz, ]
  values
}

# --- Overlay of reprocessed and rebuilt export files ---------------------------------
# Exports produced under docs/eeg_filter_reprocessing_protocol.md, and marker files rebuilt
# from the Analyzer histories, are written to this directory in the output store and never
# into the read-only data tree. A file here replaces the legacy file with the same path
# relative to the EEG root ("Session 3/Export/..."). Which files may be used, and their
# SHA-256 hashes, are fixed by the tracked manifest (les_p1_eeg_overlay_manifest()), which
# _eeg_import.R validates before reading anything. Resolved like paper1_derived() in
# _shared/R/00_paths.R, but without creating the directory.

#' Path of the overlay directory in the output store (not created)
#' @return A character scalar: <store>/paper_1_transfer/data_derived/eeg_overlay.
les_p1_eeg_overlay_root <- function() {
  store <- if (exists(".les_store")) .les_store else Sys.getenv("LES_STORE", unset = here::here())
  file.path(store, "paper_1_transfer", "data_derived", "eeg_overlay")
}
#' Path of the tracked overlay manifest
#' @return A character scalar: paper_1_transfer/eeg_overlay_manifest.csv in the code tree.
les_p1_eeg_overlay_manifest <- function() {
  here::here("paper_1_transfer", "eeg_overlay_manifest.csv")
}

# --- Cache tag for the robustness analysis that excludes the reprocessed records -------
#
# docs/eeg_filter_reprocessing_protocol.md makes the reprocessed data primary and
# prespecifies one robustness analysis that drops every participant-session the protocol
# reprocessed or recovered (LES_P1_MISFILTERED and LES_P1_INVALID_EXPORTS), whatever its
# source. LES_P1_EXCLUDE_REPROCESSED=1 selects it. Until the overlay holds reprocessed data
# the two analyses read identical data.
#
# The switch changes the DATA, not the priors, so tagging the fit alone is not enough.
# Script 01 would otherwise overwrite the derived single-trial files every cached fit was
# computed from, and script 03 the fits themselves. brms caches with file_refit =
# "on_change" (see les_brm), so different data does not skip the cache: it refits and
# writes over what is there, and nothing fails closed. The tag is therefore threaded
# through les_p1_cell_rds() (the derived data) and cell_tag in 03_fit_brms_erp.R (the fit
# and its artefacts). It is placed FIRST among the tags, ahead of the prior, item and
# retention tags, because several accessors in the manuscript and in script 05 read the
# random-effect structure off the END of a model id (grepl("_itemslope(_retfree)?$", ...)).
#
# It replaces LES_P1_KEEP_MISFILTERED (tag `_keepmisfiltered`), which retained the legacy
# 1 Hz derivatives to reproduce the September 2026 mixed-filter fits for audit. Those fits
# used the superseded cluster-row model, so they could no longer be reproduced, and the
# protocol bars the 1 Hz derivatives from every inferential analysis.
#
# Both helpers read LES_P1_EXCLUDE_REPROCESSED at call time and take no arguments.
#' @return TRUE when LES_P1_EXCLUDE_REPROCESSED is exactly "1".
les_p1_exclude_reprocessed <- function() identical(Sys.getenv("LES_P1_EXCLUDE_REPROCESSED"), "1")
#' @return "_exclreproc" under the switch, otherwise "".
les_p1_exclreproc_tag      <- function() if (les_p1_exclude_reprocessed()) "_exclreproc" else ""

# --- Cache tag for the diversity-covariate variant of the accuracy models ------
#
# LES_P1_ACC_DIVERSITY=1 adds the LHQ3 Multilingual Language Diversity Score to the
# accuracy models as a main effect. That is a different LHQ3 score from the ERP models'
# control, the L1 Dominance Score, although both enter their models under the name
# z_multilingual_language_diversity, so the variant does not mirror the ERP covariate
# (see 02_extract_accuracy.R). It changes both the DATA (script 02 joins the
# questionnaire) and the FORMULA (script 04), so the tag is threaded through
# les_p1_accuracy_rds() (the derived files) and into model_id in 04_fit_brms_accuracy.R
# (the fit and its artefacts). As with the robustness tag, it sits ahead of the prior tag.
# With the variable unset the tag is "" and every path is exactly what it was.
#
# Both helpers read LES_P1_ACC_DIVERSITY at call time and take no arguments.
#' @return TRUE when LES_P1_ACC_DIVERSITY is exactly "1".
les_p1_acc_diversity     <- function() identical(Sys.getenv("LES_P1_ACC_DIVERSITY"), "1")
#' @return "_diversity" under the switch, otherwise "".
les_p1_acc_diversity_tag <- function() if (les_p1_acc_diversity()) "_diversity" else ""

# --- Cache tag for the accuracy models with the legacy reaction-time screen ------
#
# The primary extraction keeps every de-duplicated judgement trial with a finite, positive
# response time. LES_P1_ACC_RT_SCREEN=1 applies the legacy (200, 4000) ms screen
# (LES_P1_ACC_RT_MS) as well, the sensitivity analysis since 19 October 2026 (ISSUES.md
# G06-03). Until then the roles were the other way round: the screen was primary and
# LES_P1_ACC_NO_RT_SCREEN=1 gave the unscreened variant under a _nortscreen tag. That
# switch is retired, and les_p1_acc_rt_screen() stops if it is still set, so a job script
# that sets it cannot silently fit the primary models under a sensitivity tag. The screen
# changes the DATA, so, like the diversity tag, its tag is threaded through
# les_p1_accuracy_rds(), every side file 02 writes (through les_p1_acc_data_tag()) and
# model_id in 04_fit_brms_accuracy.R. The formula is unchanged.
#
# Both helpers read LES_P1_ACC_RT_SCREEN at call time and take no arguments.
#' @return TRUE when LES_P1_ACC_RT_SCREEN is exactly "1". Stops while the retired
#'   LES_P1_ACC_NO_RT_SCREEN is set to anything.
les_p1_acc_rt_screen <- function() {
  if (nzchar(Sys.getenv("LES_P1_ACC_NO_RT_SCREEN"))) {
    stop("LES_P1_ACC_NO_RT_SCREEN is retired: since 19 October 2026 the primary accuracy ",
         "data keep every judgement, and LES_P1_ACC_RT_SCREEN=1 applies the legacy screen ",
         "(ISSUES.md G06-03). Unset it.", call. = FALSE)
  }
  identical(Sys.getenv("LES_P1_ACC_RT_SCREEN"), "1")
}
#' @return "_rtscreen" under the switch, otherwise "".
les_p1_acc_rt_screen_tag <- function() if (les_p1_acc_rt_screen()) "_rtscreen" else ""

#' The data tags of the accuracy pipeline, in the order they compose
#'
#' The tags that change the data 02 writes, and so the names of its derived and side files
#' and the first tags of a model id in 04: _diversity, then _rtscreen.
#' @return "" with neither switch set.
les_p1_acc_data_tag <- function() paste0(les_p1_acc_diversity_tag(), les_p1_acc_rt_screen_tag())

# --- Cache tag for the maximal by-participant structure of the accuracy models ---
#
# The reported accuracy models carry by-participant slopes for grammaticality and session
# but not for their interaction, although both vary within participant. Read in
# signal-detection terms (see 04_fit_brms_accuracy.R), that interaction is the change in
# response bias across sessions, and its three-way extension with language is one of the
# two credible group terms. Omitting a by-participant slope for a within-participant
# effect can make that effect's interval too narrow (Barr, Levy, Scheepers & Tily, 2013,
# https://doi.org/10.1016/j.jml.2012.11.001). LES_P1_ACC_MAXRANEF=1 adds the missing
# slope, as a sensitivity analysis added on 16 September 2026 after that reading, and
# writes accuracy_<property>_maxranef artefacts. The data are unchanged, so it reads the
# reported derived files.
#
# Both helpers read LES_P1_ACC_MAXRANEF at call time and take no arguments.
#' @return TRUE when LES_P1_ACC_MAXRANEF is exactly "1".
les_p1_acc_maxranef     <- function() identical(Sys.getenv("LES_P1_ACC_MAXRANEF"), "1")
#' @return "_maxranef" under the switch, otherwise "".
les_p1_acc_maxranef_tag <- function() if (les_p1_acc_maxranef()) "_maxranef" else ""

#' Path of one property's accuracy dataset
#'
#' The file written by 02_extract_accuracy.R and read by 04_fit_brms_accuracy.R. The
#' diversity and screened variants read and write their own files, so an opt-in
#' extraction can never overwrite the data behind the reported fits.
#' @param property A property key, one of names(LES_P1_PROPERTIES).
#' @return paper1_derived("accuracy_<property>[_diversity][_rtscreen].rds"), the tags read
#'   from LES_P1_ACC_DIVERSITY and LES_P1_ACC_RT_SCREEN at call time. paper1_derived()
#'   creates the folder if needed.
les_p1_accuracy_rds <- function(property) {
  paper1_derived(paste0("accuracy_", property, les_p1_acc_data_tag(), ".rds"))
}

# --- Fit-time record of what the exclusion actually did to a modelled dataset --
#
# WHY THIS IS RECORDED AT FIT TIME, NOT AT EXTRACTION TIME
# An earlier version of this file wrote results/_exclusions.csv from inside
# les_p1_drop_misfiltered(), and the manuscript treated that file's existence as
# proof that the exclusion was in force. That test was unsound. The function runs
# in the extraction scripts (01, 08), so re-running an extraction created the
# marker even when the fitted models the manuscript actually reads were older than
# the exclusion and still contained the four datasets. The marker then cleared
# silently while the reported numbers were stale, which is the failure it existed
# to prevent.
#
# The fix is to key the claim on the data each model was fitted to. This function
# is called by the fitting scripts with the data frame passed to brms, after all
# filtering and listwise deletion, so `misfiltered_rows` is a direct measurement of
# the analysed sample rather than an inference from a side-effect file. Pooling
# these records (script 05) gives the manuscript a per-cell audit trail: it can
# state the exclusion only when every fit it reports was computed under it.
# `exclusion_applicable` marks whether the EEG exclusions have any bearing on
# this model. It is FALSE for the accuracy models: those fit the behavioural
# grammaticality judgements, which are unaffected by how the EEG was processed, so they
# legitimately retain the excluded EEG sessions and must not be read as evidence that the
# exclusion failed. `erp_model_version` is LES_P1_ERP_MODEL_VERSION for ERP fits and NA
# otherwise; script 05 pools only ERP fits that carry the current version.

#' Write the fit-time record of one model
#'
#' @param dat The data frame passed to brms, after all filtering and listwise deletion.
#' @param model_id Character scalar recorded as `model` (03 passes the cell id with the
#'   robustness tag only; 05 restores the structure and retention tags from the file name).
#' @param path The .rds path to write.
#' @param exclusion_applicable Logical scalar; FALSE for the accuracy models (see above).
#' @param erp_model_version Character scalar, LES_P1_ERP_MODEL_VERSION for ERP fits.
#' @return The one-row record, invisibly.
#' @details Reads LES_P1_EXCLUDE_REPROCESSED, LES_PRIOR_SET and LES_P1_ITEM_SLOPE at call
#'   time, the installed brms and cmdstanr versions, and cmdstanr::cmdstan_version()
#'   (recorded as NA when that fails). Runs les_assert_readonly_data(path) when the guard
#'   is defined and overwrites `path` with saveRDS().
les_p1_write_fit_meta <- function(dat, model_id, path, exclusion_applicable = TRUE,
                                  erp_model_version = NA_character_) {
  n_bad <- if (exclusion_applicable) les_p1_misfiltered_rows(dat) else NA_integer_
  n_inv <- if (exclusion_applicable) les_p1_invalid_export_rows(dat) else NA_integer_
  n_rep <- if (exclusion_applicable) les_p1_reprocessed_rows(dat) else NA_integer_
  n_dev <- les_p1_deviation_rows(dat)
  .ver <- function(p) tryCatch(as.character(utils::packageVersion(p)),
                               error = function(e) NA_character_)
  rec <- data.frame(
    model                = model_id,
    n_obs                = nrow(dat),
    n_participants       = length(unique(as.character(dat$participant_lab_ID))),
    exclusion_applicable = exclusion_applicable,
    # Legacy 1 Hz rows; no fit of either analysis may contain any.
    misfiltered_rows     = n_bad,
    exclusion_applied    = !exclusion_applicable || (!is.na(n_bad) && n_bad == 0L),
    exclude_reprocessed  = les_p1_exclude_reprocessed(),
    # Legacy invalid exports; no fit may contain any.
    invalid_export_rows  = n_inv,
    # Reprocessed or recovered rows read from the overlay: part of the primary analysis,
    # and none in the robustness analysis.
    reprocessed_rows     = n_rep,
    erp_model_version    = erp_model_version,
    # Applies to every model, behavioural included: the deviation concerns the
    # language a participant was trained in, not how their EEG was filtered.
    deviation_rows       = n_dev,
    prior_set           = Sys.getenv("LES_PRIOR_SET", unset = "informative"),
    # Random-effect structure. Without this the pooled table cannot tell a base fit
    # from a maximal one -- they share a model id and a prior set, and the resulting
    # duplicate keys silently disable the same-data check in the prior-sensitivity
    # step and inflate the count the exclusion guard reads. Script 05 overwrites it, and
    # adds retention_free and model_tag, from the file name the fit was cached under, so the
    # pooled table follows the cache tag even for a record whose environment was wrong.
    structure            = if (identical(Sys.getenv("LES_P1_ITEM_SLOPE"), "1"))
                             "maximal" else "base",
    # The environment is recorded per fit, not only in the run-level
    # results/_provenance.csv. That file is written once per invocation by whichever
    # array task finishes last, so when some cells refit and others reuse a cached
    # fit it can end up describing an environment that produced none of the results
    # beside it. Carrying the versions on each fit makes the pairing unambiguous and
    # lets the pooled table show whether all reported fits share one environment.
    r_version            = paste0(R.version$major, ".", R.version$minor),
    brms_version         = .ver("brms"),
    cmdstanr_version     = .ver("cmdstanr"),
    cmdstan_version      = tryCatch(as.character(cmdstanr::cmdstan_version()),
                                    error = function(e) NA_character_),
    fitted_utc           = format(Sys.time(), tz = "UTC", usetz = TRUE),
    stringsAsFactors     = FALSE
  )
  if (exists("les_assert_readonly_data")) les_assert_readonly_data(path)
  saveRDS(rec, path)
  invisible(rec)
}

# --- File-pattern builder -----------------------------------------------------

#' File-name pattern of one property's analysed exports
#'
#' Matches BOTH artificial-language groups (any participant number), e.g. for gender
#' ^\d+_trialbytrial_S1_S10[12]\.
#' @param property A property key, one of names(LES_P1_PROPERTIES); stops otherwise.
#' @return A regular expression (character scalar).
les_p1_file_pattern <- function(property) {
  code <- LES_P1_PROPERTIES[[property]]
  if (is.null(code)) stop("Unknown property: ", property)
  paste0("^\\d+_trialbytrial_", code, "_", LES_P1_GRAMMATICALITY_REGEX, "\\.")
}

# --- Canonical cell identifier and derived-file path --------------------------

#' Identifier of one ERP cell
#' @param property,window,macroregion A property key, a name of LES_P1_WINDOWS and one of
#'   LES_P1_MACROREGIONS (not checked).
#' @return "erp_<property>_<window>_<macroregion>".
les_p1_cell_id <- function(property, window, macroregion) {
  paste("erp", property, window, macroregion, sep = "_")
}

#' Path of one cell's single-trial data, written by step 01 and fitted by step 03
#'
#' The robustness analysis reads and writes its own derived files, so its extraction can
#' never overwrite the data behind the primary fits.
#' @param property,window,macroregion As for les_p1_cell_id().
#' @return paper1_derived("<cell id>[_exclreproc].rds"), the tag read from
#'   LES_P1_EXCLUDE_REPROCESSED at call time. paper1_derived() creates the folder if needed.
les_p1_cell_rds <- function(property, window, macroregion) {
  paper1_derived(paste0(les_p1_cell_id(property, window, macroregion),
                        les_p1_exclreproc_tag(), ".rds"))
}

# --- The full 18-cell analysis grid ------------------------------------------

#' The 18-cell ERP analysis grid
#'
#' Pipeline scripts iterate over (or subset, for per-cell HPC jobs) this table.
#' @return A data frame with one row per (property x window x macroregion) cell, columns
#'   property, window, macroregion and cell_id, sorted by property, window and macroregion.
les_p1_erp_grid <- function() {
  grid <- expand.grid(
    property    = names(LES_P1_PROPERTIES),
    window      = names(LES_P1_WINDOWS),
    macroregion = LES_P1_MACROREGIONS,
    KEEP.OUT.ATTRS = FALSE,
    stringsAsFactors = FALSE
  )
  grid$cell_id <- with(grid, mapply(les_p1_cell_id, property, window, macroregion))
  grid[order(grid$property, grid$window, grid$macroregion), , drop = FALSE]
}

# --- May the manuscript state that the mis-filtered datasets were excluded? -----
#
# The decision rule behind the Method's exclusion sentence. It lives here, beside the
# helpers it audits, so that the manuscript and test_exclusion_guard.R apply one rule.

#' Whether the Method may state that the excluded datasets are out of every reported fit
#'
#' @param tbl The pooled fit metadata (results/_pooled_fit_metadata.csv as a data frame),
#'   or NULL when it is absent.
#' @param primary The random-effect structure the manuscript reports ("maximal" or "base").
#' @param n_expected The number of ERP cells the reported grid holds.
#' @return "" when every reported ERP fit carries a clean record and the grid is complete,
#'   otherwise the reason the claim cannot yet stand, which the manuscript wraps in its
#'   pending marker.
les_p1_misfilter_status <- function(tbl, primary, n_expected = nrow(les_p1_erp_grid())) {
  if (is.null(tbl)) {
    return("the results currently shown were computed before this exclusion was applied")
  }
  # The primary analysis is the informative-prior set fitted under the primary
  # random-effect structure. The weak-prior refits and the other structure are
  # sensitivity analyses, reported separately and audited with their own records.
  # Filtering on structure matters: base and maximal fits share a model id, so without
  # it every cell matches twice and the completeness check below passes on 36 rows that
  # are really 18 cells fitted two ways.
  # The robustness refits that exclude the reprocessed records are audited separately for
  # the same reason. Their model ids carry the "_exclreproc" tag, and the boolean column is
  # the direct test; records written before the column existed are superseded cluster-row
  # fits, which the model-version check below rejects.
  m <- tbl[tbl$exclusion_applicable %in% TRUE &
             tbl$prior_variant %in% "informative", , drop = FALSE]
  if ("exclude_reprocessed" %in% names(m)) {
    m <- m[!(m$exclude_reprocessed %in% TRUE), , drop = FALSE]
  }
  # Pooled tables written before September 2026 may still hold the retired
  # mis-filter-retained refits (LES_P1_KEEP_MISFILTERED); they are set aside the same way.
  if ("keep_misfiltered" %in% names(m)) {
    m <- m[!(m$keep_misfiltered %in% TRUE), , drop = FALSE]
  }
  # So are the retention-free refits (LES_P1_RETENTION_FREE), a sensitivity analysis of
  # twelve cells. Their records carry the bare cell id, the primary structure and the
  # informative prior, so without this filter twelve of them would count towards the
  # eighteen cells the completeness check below requires (ISSUES.md, G04-17). Script 05
  # writes the column from the cache tag.
  if ("retention_free" %in% names(m)) {
    m <- m[!(m$retention_free %in% TRUE), , drop = FALSE]
  }
  if ("structure" %in% names(m)) {
    m <- m[m$structure %in% primary, , drop = FALSE]
  } else if (!identical(primary, "base")) {
    return(paste0("the fit records predate the random-effect-structure column, ",
                  "so the structure behind the reported fits cannot be confirmed"))
  }
  if (nrow(m) == 0) return("no fitted model carries a record of this exclusion")
  # Fits of the superseded cluster-row specification cannot stand behind any claim.
  if (!"erp_model_version" %in% names(m) ||
      any(!(m$erp_model_version %in% LES_P1_ERP_MODEL_VERSION))) {
    return("some fitted ERP models use the superseded cluster-row specification")
  }
  # Fits made before the invalid exports were identified carry no count of them and may
  # contain them, so a missing column, like a non-zero count, keeps the marker.
  if (!"invalid_export_rows" %in% names(m) || any(!(m$invalid_export_rows %in% 0L))) {
    return("some fitted ERP models predate the removal of the invalid exports")
  }
  n_stale <- sum(!(m$exclusion_applied %in% TRUE))
  if (n_stale > 0) {
    return(sprintf("%d of %d fitted ERP models still contain these datasets",
                   n_stale, nrow(m)))
  }
  # Every fit that reported in is clean, but a partial refit would also look clean.
  # Require the audit to cover the whole grid before the claim is allowed to stand,
  # counting distinct cells, so that two records of one cell cannot stand in for another.
  n_cells <- length(unique(m$model))
  if (n_cells < n_expected) {
    return(sprintf("only %d of the %d ERP models have been refitted under it",
                   n_cells, n_expected))
  }
  ""
}

cat("[paper1/_config] ERP grid:",
    length(LES_P1_PROPERTIES), "properties x",
    length(LES_P1_WINDOWS), "windows x",
    length(LES_P1_MACROREGIONS), "macroregions =",
    nrow(les_p1_erp_grid()), "cells.\n")
