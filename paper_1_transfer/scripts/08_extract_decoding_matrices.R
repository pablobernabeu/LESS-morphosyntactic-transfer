# =============================================================================
# paper_1_transfer/scripts/08_extract_decoding_matrices.R
# Phase 4a -- Build the analysis-ready single-trial DECODING matrices for Paper 1
# -----------------------------------------------------------------------------
# WHAT THIS SCRIPT PRODUCES
# -------------------------
# For each grammatical property it writes one compact `.rds` to paper1_derived()
# holding, per single trial, a full 31-channel x time-point amplitude PATTERN plus
# the trial metadata needed for multivariate pattern analysis (MVPA) decoding. Unlike
# the univariate ERP pipeline (steps 01/07), which collapses the scalp to one mean per
# electrode cluster, decoding needs the JOINT spatial pattern across all sensors at
# each moment: the discriminative information lives in the covariance structure across
# channels, not in any single averaged region (Haxby et al., 2001, Science,
# https://doi.org/10.1126/science.1063736; Kriegeskorte et al., 2008 -- see step 09;
# Grootswagers et al., 2017, JoCN, https://doi.org/10.1162/jocn_a_01068).
#
# OUTPUT LAYOUT (two files per property, both in paper1_derived(); under
# LES_P1_EXCLUDE_REPROCESSED=1 both names carry _exclreproc after the property):
#   _decoding_<property>.rds, a list with:
#   * X       : numeric array [trial x channel x time]  (the decoding tensor)
#   * meta    : data.frame, one row per trial (aligned to dim 1 of X), columns:
#                 trial_uid, participant_lab_ID, session, mini_language,
#                 grammaticality (Grammatical/Ungrammatical), item_id, sentence_marker,
#                 grammatical_property, n_valid_samples
#   * channels: character vector of the retained EEG channel labels (dim 2 order;
#               LES_DECODE_N_EEG = 31 of them, see step (1b) below)
#   * times    : numeric vector of retained time points in ms (dim 3 order)
#   * property : the property string
#   * time_step_ms, baseline_corrected : the two build options, as used
#   * x_digest : digest::digest() of X. Step 09 appends its first 12 characters to the
#                fingerprint that keys every permutation checkpoint, so a tensor rebuilt
#                with different values but the same counts can never resume old blocks.
#   _decoding_<property>_fingerprint.rds, the cache record (see "Tensor cache" below):
#     list(fingerprint, tensor_size, tensor_mtime, written_at).
# Storing a dense array (rather than a long tidy frame) keeps the file small and lets
# step 09 slice a [trial x channel] pattern at each time point with zero reshaping.
#
# DEFINITION OF A "TRIAL"
# -----------------------
# The importer has no explicit trial id. One presented sentence (epoch) is uniquely
# identified by participant x session x grammaticality x sentence_marker. Every
# electrode x sample cell of that epoch shares those keys, so we build
#   trial_uid = participant | session | property | grammaticality | sentence_marker
# and pivot the (electrode, time) pairs of each trial_uid into the pattern tensor.
#
# ITEM CODES ARE REUSED ACROSS LANGUAGES (data quirk)
# ---------------------------------------------------
# sentence_marker (S110-S253) is a condition/position code, reused across the two
# artificial languages, so the same marker denotes DIFFERENT stimuli for Mini-English
# vs Mini-Norwegian participants (see step 01's item_id note). We namespace it:
#   item_id = mini_language | sentence_marker
# so cross-language analyses in step 09 never treat two different items as one.
#
# TWO CHOICES MADE FOR SPEED AND STABILITY (both optional to revert)
# ------------------------------------------------------------------
# 1. LIGHT TIME DOWNSAMPLING (default: every 4 ms, i.e. average each adjacent pair of
#    2 ms samples into one 4 ms bin; see step (4) below).
#    ERP decoding accuracy is smooth in time and adjacent 2 ms samples are highly
#    redundant; decoding at ~250 Hz rather than 500 Hz halves the per-property fitting
#    cost with negligible loss of temporal information, a standard MVPA economy
#    (Grootswagers et al., 2017, https://doi.org/10.1162/jocn_a_01068; King & Dehaene,
#    2014, TiCS, https://doi.org/10.1016/j.tics.2014.01.002). Controlled by the
#    environment variable LES_DECODE_TIME_STEP_MS; set it to 2 to keep every sample.
# 2. PER-TRIAL BASELINE CORRECTION (subtract each trial's own pre-stimulus mean, per
#    channel). A classifier intercept is one constant for every trial, so it cannot
#    absorb an offset that differs from trial to trial (slow drift, a shifted channel
#    baseline), and step 09's discriminant has no intercept in any case. Subtracting the
#    per-trial, per-channel pre-stimulus mean is what removes such offsets: it equalises
#    the channel baselines across trials and conditions and prevents a decoder from
#    exploiting baseline-period differences as if they were evoked signal -- a
#    conservative guard consistent with standard ERP practice (Luck, 2014). We use the
#    pre-stimulus window (time < 0) exactly as the univariate pipeline does.
#
# WHAT THIS SCRIPT DOES NOT DO
# ----------------------------
# No classification, no cross-validation, no averaging across trials: this step is a
# pure, deterministic reshape of the validated read-only load. All modelling choices
# (LOPO CV, permutation, generalisation) live in step 09, keeping extraction cheap to
# re-run and the decoder auditable.
#
# USAGE
#   Rscript 08_extract_decoding_matrices.R gender_agreement          # one property
#   Rscript 08_extract_decoding_matrices.R                           # all three
#   LES_DECODE_TIME_STEP_MS=2 Rscript 08_extract_decoding_matrices.R gender_agreement
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))          # anchors root + paths
  source(here::here("_shared", "R", "03_data_manifest.R"))  # logical data map
  source(here::here("paper_1_transfer", "scripts", "_config.R"))
  library(dplyr)
  library(tidyr)
})

# --- Decoding-grid constants (kept local; step 09 reads them back off the rds) ----
# Full epoch, every EEG sensor, sampled on the fixed seq(-100, 1098, by = 2) grid (600
# samples) documented by the importer. The bounds are LES_P1_EPOCH_MS in _config.R; the
# two scalars are part of the tensor fingerprint below, so they stay unnamed doubles.
LES_DECODE_MIN_MS <- LES_P1_EPOCH_MS[1]
LES_DECODE_MAX_MS <- LES_P1_EPOCH_MS[2]

# Channels the LiveAmp writes alongside the electrodes: its built-in accelerometer.
# These are head-movement traces, not brain signal, and are excluded from the decoder.
LES_DECODE_NON_EEG <- c("x_dir", "y_dir", "z_dir")

# EEG sensors expected after that exclusion and after intersecting across sessions:
# the 30 scalp sites the region map uses, plus FCz (the restored online reference).
# The mastoid pair TP9/TP10 is exported for Session 2 only and so drops out.
LES_DECODE_N_EEG <- 31L

# Time step (ms) between retained samples. Must be a multiple of 2 (native step).
#' Decoding time step in ms, from LES_DECODE_TIME_STEP_MS (default "4").
#' @param cli_arg optional override; no caller passes it (.run() reads the environment
#'   only), so it is kept only for interactive use.
#' @return integer, an even number >= 2; stops on anything else.
les_decode_time_step_ms <- function(cli_arg = NA_character_) {
  v <- if (!is.na(cli_arg)) cli_arg else Sys.getenv("LES_DECODE_TIME_STEP_MS", unset = "4")
  step <- suppressWarnings(as.integer(v))
  if (is.na(step) || step < 2 || step %% 2 != 0) {
    stop("LES_DECODE_TIME_STEP_MS must be an even integer >= 2 (got '", v, "').")
  }
  step
}

# The robustness analysis (LES_P1_EXCLUDE_REPROCESSED=1) writes its own tensor, fingerprint
# and results under the "_exclreproc" tag, so it never overwrites the primary analysis.
#' Path of one property's decoding tensor; step 09 and 09b read the tensor through it.
#' @param property one of names(LES_P1_PROPERTIES).
#' @return paper1_derived("_decoding_<property><tag>.rds"), <tag> being "" or "_exclreproc".
les_decode_rds <- function(property)
  paper1_derived(paste0("_decoding_", property, les_p1_exclreproc_tag(), ".rds"))

# =============================================================================
# Tensor cache
# -----------------------------------------------------------------------------
# Rebuilding the tensor takes up to about two hours and is the memory peak of the decode
# job, not the decoding itself: on HTC the extraction peaked at 195 GB for differential
# object marking and 117 GB for verb-object number agreement (8829254, September 2026),
# and gender agreement's was killed at 254 GiB of a 256 GB request, which is why
# hpc/submit_eeg_rerun.sh gives gender 480 GB (built in 2 h 07 min on 2 October 2026).
# Because a decode job that hits its walltime is resubmitted (resuming from the
# permutation checkpoints), that extraction would otherwise be repaid on every restart
# for no gain.
#
# A cache here is dangerous in one specific direction. Failing CLOSED (rebuilding when
# it need not) merely wastes a couple of hours. Failing OPEN -- reusing a tensor after an
# input changed -- silently feeds a ten-day permutation analysis, and therefore a
# published p value, from the wrong data. Every check below is written to fail closed:
# anything unverifiable is treated as a miss.
#
# The fingerprint must cover VALUES, not just references. The sharpest instance is
# LES_P1_EXCLUDE_REPROCESSED: `les_p1_drop_misfiltered()` branches on it at run time, so
# deparsing that function is not enough. The robustness tensor is also written under its
# own _exclreproc name, so the two arms never share a cache file; recording the switch in
# the fingerprint as well means that even a tensor moved or copied between the two names
# is refused rather than reused. _config.R records this variable in per-fit metadata for
# the same reason.
#
# Set LES_DECODE_FORCE_EXTRACT (1/true/yes) to rebuild regardless.
# =============================================================================
LES_DECODE_TENSOR_VERSION <- 2L   # bump to invalidate every cached tensor by hand

#' Path of a tensor's cache record, the sidecar step 08 writes beside it.
#' @param property one of names(LES_P1_PROPERTIES).
#' @return paper1_derived("_decoding_<property><tag>_fingerprint.rds").
.les_decode_fp_path <- function(property)
  paper1_derived(paste0("_decoding_", property, les_p1_exclreproc_tag(), "_fingerprint.rds"))

#' TRUE for the usual spellings of an affirmative switch value ("1", "true", "yes", ...).
#' @param x character vector, typically Sys.getenv() output.
#' @return logical vector.
.les_truthy <- function(x) tolower(trimws(x)) %in% c("1", "true", "yes", "y", "t")

# Stat a set of files. Paths are recorded RELATIVE to `root` where given, because the
# importer parses participant and session out of the directory path -- basenames alone
# are not unique (837 gender exports share only 252 basenames across session folders),
# so a file refiled between sessions would otherwise look unchanged. row.names are
# stripped so nothing depends on list.files() ordering as an accidental guard.
#' Size and mtime of a set of files, for the cache fingerprint.
#' @param paths character vector of file paths; missing files are dropped.
#' @param root optional directory the labels are made relative to.
#' @return data.frame(file, size, mtime) sorted by file, or NULL when no file exists or
#'   any stat fails (which the cache treats as unverifiable).
.les_stat <- function(paths, root = NULL) {
  paths <- paths[file.exists(paths)]
  if (!length(paths)) return(NULL)
  lab <- if (is.null(root)) basename(paths)
         else sub(paste0("^", gsub("([.|()\\^{}+$*?\\[\\]])", "\\\\\\1", root), "/?"), "", paths)
  inf <- file.info(paths)
  if (any(is.na(inf$size))) return(NULL)          # stat failed: unverifiable -> miss
  out <- data.frame(file = lab, size = as.numeric(inf$size),
                    mtime = as.numeric(inf$mtime), stringsAsFactors = FALSE)
  out <- out[order(out$file), , drop = FALSE]
  rownames(out) <- NULL
  out
}

# The raw exports this property's pattern actually matches, keyed by path relative to
# the EEG root. NULL when none are found, which the cache treats as unverifiable.
#' Stat the exports that feed one property's tensor.
#' @param property one of names(LES_P1_PROPERTIES).
#' @return .les_stat() table of the legacy exports and marker files, plus the overlay
#'   files and the overlay manifest (labelled "overlay/..."); NULL when none is found.
.les_decode_source_files <- function(property) {
  pat <- les_p1_file_pattern(property)
  dir <- erp_single_trials_path()
  if (!dir.exists(dir)) return(NULL)
  f <- c(list.files(dir, pattern = paste0(pat, "txt$"), full.names = TRUE, recursive = TRUE),
         list.files(dir, pattern = paste0(pat, "vmrk$"), full.names = TRUE, recursive = TRUE))
  if (!length(f)) return(NULL)
  legacy <- .les_stat(f, root = dir)
  # Reprocessed or rebuilt files in the overlay replace legacy files at import
  # (_eeg_import.R), so they and the tracked manifest that admits them are part of the
  # tensor's identity. Labelled with an "overlay/" prefix so they never collide with legacy
  # paths.
  over_root <- les_p1_eeg_overlay_root()
  if (dir.exists(over_root)) {
    over <- .les_stat(list.files(over_root, pattern = paste0(pat, "(txt|vmrk)$"),
                                 full.names = TRUE, recursive = TRUE), root = over_root)
    if (!is.null(over)) {
      over$file <- paste0("overlay/", over$file)
      legacy <- rbind(legacy, over)
    }
  }
  man <- les_p1_eeg_overlay_manifest()
  if (file.exists(man)) {
    m <- .les_stat(man, root = dirname(man))
    m$file <- paste0("overlay/", m$file)
    legacy <- rbind(legacy, m)
  }
  legacy
}

# Everything outside this script that shapes the tensor or its metadata: the whole
# import/merge chain and the preprocessing scripts it sources, the participant key
# (which supplies the language assignment in `meta`), and _config.R (which defines
# les_p1_misfiltered_rows(), the exclusion table and the file patterns -- deparsing
# les_p1_drop_misfiltered() does not reach its callees).
#' Stat the scripts and key files outside this script that shape the tensor.
#' @return .les_stat() table of the data-side loaders and participant key and of
#'   _config.R and _eeg_import.R; NULL when either side cannot be stated.
.les_decode_input_scripts <- function() {
  data_side <- c(list.files(data_path("R_functions"), pattern = "\\.R$", full.names = TRUE),
                 list.files(data_path("importation and preprocessing"), pattern = "\\.R$",
                            full.names = TRUE),
                 participant_key_csv())
  code_side <- here::here("paper_1_transfer", "scripts", c("_config.R", "_eeg_import.R"))
  # Rooted separately so both sets keep short, portable labels: the data tree lives
  # under $LES_DATA_ROOT on the cluster and beside the code locally.
  a <- .les_stat(data_side, root = normalizePath(data_path(), winslash = "/", mustWork = FALSE))
  b <- .les_stat(code_side, root = normalizePath(here::here(), winslash = "/", mustWork = FALSE))
  if (is.null(a) || is.null(b)) return(NULL)
  rbind(a, b)
}

# The vendored importer reads the exports through data_path(), but the merge still reads
# the participant key and the preprocessing scripts through the relative path 'data' in
# the working directory. On the cluster those coincide only because arc_env.sh creates a
# `data` symlink, and it skips that if any `data` entry already exists. The merge itself
# stops when they diverge (_eeg_import.R); refusing the cache here as well means a stale
# tensor is never served from a tree the analysis would not read.
#' Whether the relative 'data' path and data_path() are the same tree.
#' @return TRUE when ./data and data_path() resolve to the same directory.
.les_decode_paths_agree <- function() {
  a <- normalizePath("data", winslash = "/", mustWork = FALSE)
  b <- normalizePath(data_path(), winslash = "/", mustWork = FALSE)
  identical(a, b)
}

#' Everything that could change a property's tensor, as one comparable list.
#' @param property one of names(LES_P1_PROPERTIES).
#' @param time_step_ms,baseline_correct the build options passed to
#'   .les_build_decoding_tensor().
#' @return named list: version, options, grid constants, exclusion tables, the
#'   exclude-reprocessed switch, data root, stats of the inputs and loaders (NULL entries
#'   when they cannot be stated), deparsed builder and exclusion functions, collation,
#'   R and package versions. Compared with identical() against the stored record.
.les_decode_fingerprint <- function(property, time_step_ms, baseline_correct) {
  list(
    version          = LES_DECODE_TENSOR_VERSION,
    property         = property,
    time_step_ms     = as.integer(time_step_ms),
    baseline_correct = isTRUE(baseline_correct),
    min_ms           = LES_DECODE_MIN_MS,
    max_ms           = LES_DECODE_MAX_MS,
    n_eeg            = LES_DECODE_N_EEG,
    non_eeg          = LES_DECODE_NON_EEG,
    misfiltered      = LES_P1_MISFILTERED,
    deviation        = LES_P1_PROTOCOL_DEVIATION,
    invalid_exports  = LES_P1_INVALID_EXPORTS,
    # Read at build time and therefore part of the tensor's identity, not merely of
    # the code that consults it. See the section header.
    exclude_reprocessed = les_p1_exclude_reprocessed(),
    file_pattern     = les_p1_file_pattern(property),
    data_root        = normalizePath(data_path(), winslash = "/", mustWork = FALSE),
    sources          = .les_decode_source_files(property),
    builder          = deparse(.les_build_decoding_tensor),
    drop_misfiltered = deparse(les_p1_drop_misfiltered),
    drop_deviation   = deparse(les_p1_drop_protocol_deviation),
    drop_invalid     = deparse(les_p1_drop_invalid_exports),
    apply_exclusions = deparse(les_p1_apply_eeg_exclusions),
    s2_rereference   = deparse(les_p1_s2_rereference),
    loaders          = .les_decode_input_scripts(),
    # Channel order comes from sort(unique(electrode)), so collation matters; the
    # reshaping stack can also change output across R and package versions.
    collate          = Sys.getlocale("LC_COLLATE"),
    r_version        = R.version.string,
    # The reshaping stack itself can change the tensor across releases, and
    # $LES_RLIB is a directory the install job writes into.
    pkg_versions     = vapply(
      c("dplyr", "tidyr", "data.table", "stringr", "purrr", "readxl"),
      function(pk) if (requireNamespace(pk, quietly = TRUE))
        as.character(utils::packageVersion(pk)) else NA_character_, character(1))
  )
}

#' Whether the tensor on disk may be reused instead of rebuilt.
#' @param property one of names(LES_P1_PROPERTIES).
#' @param fp the current .les_decode_fingerprint().
#' @return TRUE only when LES_DECODE_FORCE_EXTRACT is unset, every input could be stated,
#'   ./data agrees with data_path(), and the stored record matches `fp` and the tensor's
#'   current size and mtime; FALSE otherwise (fails closed). Reads the tensor's sidecar.
.les_decode_cache_ok <- function(property, fp) {
  if (.les_truthy(Sys.getenv("LES_DECODE_FORCE_EXTRACT"))) {
    message("[decode-extract] LES_DECODE_FORCE_EXTRACT set -- rebuilding regardless of cache")
    return(FALSE)
  }
  if (is.null(fp$sources) || is.null(fp$loaders)) {
    message("[decode-extract] inputs could not be stated for ", property,
            " -- cannot verify a cached tensor; rebuilding")
    return(FALSE)
  }
  if (!.les_decode_paths_agree()) {
    message("[decode-extract] 'data' does not resolve to the fingerprinted data root",
            " -- refusing to trust the cache; rebuilding")
    return(FALSE)
  }
  rds  <- les_decode_rds(property)
  side <- .les_decode_fp_path(property)
  if (!file.exists(rds) || !file.exists(side)) return(FALSE)
  prev <- try(readRDS(side), silent = TRUE)
  if (inherits(prev, "try-error") || !is.list(prev)) return(FALSE)
  inf <- file.info(rds)
  if (is.na(inf$size)) return(FALSE)
  identical(prev$fingerprint, fp) &&
    identical(prev$tensor_size,  as.numeric(inf$size)) &&
    identical(prev$tensor_mtime, as.numeric(inf$mtime))
}

#' Record the inputs a tensor was built from, beside the tensor.
#' @param property one of names(LES_P1_PROPERTIES).
#' @param fp the .les_decode_fingerprint() the tensor was built under.
#' @return invisibly, the sidecar path. Writes .les_decode_fp_path(property) atomically,
#'   capturing the tensor file's size and mtime; call it only after the tensor is saved.
.les_decode_write_fingerprint <- function(property, fp) {
  inf <- file.info(les_decode_rds(property))
  .les_save_atomic(list(fingerprint  = fp,
                        tensor_size  = as.numeric(inf$size),
                        tensor_mtime = as.numeric(inf$mtime),
                        written_at   = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")),
                   .les_decode_fp_path(property))
}

# Write via a temp file and rename, so an interrupted write cannot leave a truncated
# artefact that a later run would accept. 09_run_decoding.R does NOT share this idiom:
# its within-block partials go through a fixed temp name with an unchecked rename, and
# its block checkpoints are written in place (ISSUES.md G08-10).
#' saveRDS() through a process-unique temp file and a checked rename.
#' @param object any R object.
#' @param path destination .rds path.
#' @return invisibly, `path`; stops when the rename fails.
.les_save_atomic <- function(object, path) {
  # Process-unique: two runs for the same property can overlap under the resubmission
  # regime, and a shared temp path would let them interleave into one file that the
  # rename then publishes as valid.
  tmp <- paste0(path, ".tmp.", Sys.getpid())
  saveRDS(object, tmp)
  if (!file.rename(tmp, path)) stop("could not move ", tmp, " into place at ", path)
  invisible(path)
}

# =============================================================================
# Pure transform: reshape one merged, un-aggregated load into the decoding tensor.
# -----------------------------------------------------------------------------
# Factored out so the (index-sensitive) tensor assembly can be unit-tested on small
# synthetic input without the heavy EEG load. Input `raw` is the merge output (one row
# per electrode x sample x trial); output is the list described in the header.
#
# This function's deparsed code is part of the tensor fingerprint, so editing its body
# invalidates every cached tensor. Rscript deparses without source references, so its
# comments do not enter the fingerprint. The comment at step (0) predates the overlay of
# reprocessed records; the description of step (0) below is the current one.
# =============================================================================
#' Reshape one merged single-trial load into the decoding tensor (pure; no file I/O).
#' @param raw data.frame from les_p1_merge_trialbytrial(), one row per electrode x sample
#'   x trial, with columns participant_lab_ID, session, electrode, sentence_marker,
#'   mini_language, grammaticality, grammatical_property, amplitude (numeric) and time
#'   (ms, numeric), plus eeg_source where the overlay was read. Factors are accepted.
#' @param property the property string, written into trial_uid and the result.
#' @param time_step_ms integer, the bin width (an even number of ms).
#' @param baseline_correct logical, subtract each trial's per-channel pre-stimulus mean.
#' @return list(X, meta, channels, times, property, time_step_ms, baseline_corrected) as
#'   described in the header (x_digest is added by the caller). Step (0) applies
#'   les_p1_apply_eeg_exclusions(): legacy rows of the listed mis-filtered and invalid
#'   exports and every row of the protocol-deviation participant are dropped, while
#'   overlay rows of reprocessed or recovered records stay unless
#'   LES_P1_EXCLUDE_REPROCESSED=1. Warns, without stopping, when the channel count is
#'   not LES_DECODE_N_EEG; extract_paper1_decoding() stops on it.
.les_build_decoding_tensor <- function(raw, property, time_step_ms = 4L,
                                        baseline_correct = TRUE) {

  # (0) Drop the Session-3 datasets high-pass filtered at 1 Hz instead of 0.1 Hz
  #     (see LES_P1_MISFILTERED in _config.R). The decoder is at least as exposed to
  #     this as the amplitude models: a filter that introduces an artifactual
  #     opposite-polarity deflection changes the multivariate pattern, and because the
  #     mis-filtered datasets belong to one session only, that change is confounded
  #     with session in exactly the session-resolved analyses. The same call drops the
  #     participant excluded for a protocol deviation (LES_P1_PROTOCOL_DEVIATION).
  raw <- les_p1_apply_eeg_exclusions(raw)

  # (1) Keep only the two canonical grammaticality conditions we decode between.
  raw <- raw[raw$grammaticality %in% c("Grammatical", "Ungrammatical"), , drop = FALSE]
  if (nrow(raw) == 0L) stop("No Grammatical/Ungrammatical rows for property ", property)

  # (1b) Restrict to EEG sensors recorded in EVERY session that contributes to this
  #      property. Two things make this necessary rather than cosmetic. First, the
  #      LiveAmp writes its built-in accelerometer (x_dir/y_dir/z_dir) alongside the
  #      electrodes: those are head-movement traces, not brain signal, and must never be
  #      decodable features. Second, the exports are not uniform -- the Session-2 export
  #      carries the mastoid reference pair (TP9/TP10) and the accelerometer, whereas the
  #      Session-3/4/6 exports carry neither. Taking the union of whatever happens to be
  #      present (which is what sort(unique(electrode)) does downstream) would therefore
  #      give a property recorded across those sessions a feature space containing
  #      channels that exist for its Session-2 trials only, leaving those channels
  #      structurally unobserved for every other trial and distorting both the decoder
  #      and the per-trial completeness count computed below. Intersecting across
  #      sessions keeps the tensor rectangular and brain-only.
  # (table() does its own factor coding internally; passing the columns straight in
  #  avoids materialising two extra full-length factors on a ~10^8-row load.)
  .present <- table(raw$electrode, raw$session, useNA = "no") > 0
  .common  <- rownames(.present)[rowSums(.present) == ncol(.present)]
  .keep    <- setdiff(.common, LES_DECODE_NON_EEG)
  .dropped <- setdiff(rownames(.present), .keep)
  if (length(.dropped))
    message("[decode-extract] ", property, ": dropping ", length(.dropped),
            " channel(s) -- ", paste(sort(.dropped), collapse = ", "),
            " (non-EEG, or not recorded in every contributing session)")
  raw <- raw[raw$electrode %in% .keep, , drop = FALSE]
  if (nrow(raw) == 0L) stop("No EEG channels left for property ", property)

  # (2) Trial / channel / time keys as plain vectors. trial_uid uniquely tags one epoch.
  #     The whole reshape is done on integer indices via C-level rowsum() (below): the
  #     merged load is ~10^8 rows (trials x 31 channels x ~600 samples) with millions of
  #     (trial x electrode x time) groups, and a dplyr group_by/summarise carrying the
  #     string metadata across those groups does not scale (it wedges for the smallest
  #     property). rowsum() block-aggregates in a single sorted pass instead.
  participant <- as.character(raw$participant_lab_ID)
  session     <- as.character(raw$session)
  electrode   <- as.character(raw$electrode)
  smarker     <- as.character(raw$sentence_marker)
  mlang       <- as.character(raw$mini_language)
  gram        <- as.character(raw$grammaticality)
  gprop       <- as.character(raw$grammatical_property)
  amp         <- as.numeric(raw$amplitude)
  tm          <- as.numeric(raw$time)
  trial_uid   <- paste(participant, session, property, gram, smarker, sep = "|")
  item_id     <- paste(mlang, smarker, sep = "|")
  rm(raw)

  # Canonical, stable ordering for the three tensor dimensions + integer indices into it.
  channels <- sort(unique(electrode))
  trials   <- sort(unique(trial_uid))
  nC  <- length(channels); nTr <- length(trials)
  # After the restriction in (1b) the montage yields 31 EEG sensors: the 30 scalp sites
  # the region map uses, plus FCz (the online reference, restored when the data were
  # re-referenced to linked mastoids). A different count means the exports changed.
  if (nC != LES_DECODE_N_EEG)
    warning("Expected ", LES_DECODE_N_EEG, " EEG channels for ", property,
            " but found ", nC, " -- proceeding with the channels present.")
  .tr <- match(trial_uid, trials)
  .ch <- match(electrode, channels)

  # (3) Per-trial, per-channel baseline correction (subtract the pre-stimulus mean),
  #     BEFORE downsampling so the baseline uses every native sample. rowsum() over the
  #     (trial x channel) linear cell replaces the old group_by + left_join; cells with
  #     no pre-stimulus sample get a 0 offset (matches the previous is.na(.bl) -> 0).
  if (baseline_correct) {
    te     <- .tr + (.ch - 1L) * nTr                 # 1..(nTr*nC): trial x channel cell
    pre    <- tm < 0 & !is.na(amp)
    bl_sum <- rowsum(ifelse(pre, amp, 0), te)        # sum of pre-stim amplitudes per cell
    bl_cnt <- rowsum(as.numeric(pre), te)            # n pre-stim samples per cell
    lut    <- numeric(nTr * nC)                      # 0 where a cell has no pre-stim sample
    gid    <- as.integer(rownames(bl_sum))
    lut[gid] <- bl_sum[, 1] / pmax(bl_cnt[, 1], 1)
    amp    <- amp - lut[te]
  }

  # (4) Downsample time by block-averaging within each `time_step_ms` bin (a light
  #     anti-alias low-pass for smooth ERP signals; Grootswagers et al., 2017) and fill
  #     the [trial x channel x bin] tensor in one pass via a linear-index rowsum(). The
  #     linear index is built in double precision so nTr*nC*nT never overflows integer.
  time_bin <- floor((tm - LES_DECODE_MIN_MS) / time_step_ms)
  bins     <- sort(unique(time_bin))
  nT       <- length(bins)
  times    <- LES_DECODE_MIN_MS + (bins + 0.5) * time_step_ms   # nominal bin-centre (ms)
  .ti      <- match(time_bin, bins)

  lin  <- .tr + (.ch - 1) * as.numeric(nTr) + (.ti - 1) * (as.numeric(nTr) * nC)
  s    <- rowsum(amp, lin, na.rm = TRUE)
  cnt  <- rowsum(as.numeric(!is.na(amp)), lin)
  vals <- s[, 1] / cnt[, 1]                           # NaN where the cell had no non-NA sample
  vals[!is.finite(vals)] <- NA_real_

  X <- array(NA_real_, dim = c(nTr, nC, nT),
             dimnames = list(trials, channels, as.character(times)))
  X[as.numeric(rownames(s))] <- vals                 # column-major linear fill; unfilled -> NA

  # (5) One metadata row per trial, aligned to dim 1 of X.
  keep <- !duplicated(trial_uid)
  meta <- data.frame(
    trial_uid            = trial_uid[keep],
    participant_lab_ID   = participant[keep],
    session              = session[keep],
    mini_language        = mlang[keep],
    grammaticality       = gram[keep],
    item_id              = item_id[keep],
    sentence_marker      = smarker[keep],
    grammatical_property = gprop[keep],
    stringsAsFactors     = FALSE
  )
  meta <- meta[match(trials, meta$trial_uid), , drop = FALSE]
  rownames(meta) <- NULL
  stopifnot(identical(meta$trial_uid, trials))

  # Per-trial completeness (observed channel x time cells), recorded as a diagnostic.
  # Step 09 does not read it: its .les_complete_trials() recomputes completeness from X
  # itself, so this column is for inspecting an extraction, not for driving one.
  meta$n_valid_samples <- as.integer(rowSums(!is.na(matrix(X, nrow = nTr))))

  list(X = X, meta = meta, channels = channels,
       times = times, property = property, time_step_ms = time_step_ms,
       baseline_corrected = baseline_correct)
}

# =============================================================================
# Core: load one property (every channel present) and write its decoding tensor.
# =============================================================================
#' Build, or reuse from the cache, one property's decoding tensor.
#' @param property one of names(LES_P1_PROPERTIES).
#' @param time_step_ms integer bin width in ms (les_decode_time_step_ms() from .run()).
#' @param baseline_correct logical, per-trial per-channel baseline correction.
#' @return invisibly, the tensor path les_decode_rds(property).
#' Side effects: on a cache miss, sources _eeg_import.R and the legacy preprocessing
#' scripts into the global environment, runs the full single-trial merge, then writes
#' les_decode_rds(property) and its sidecar .les_decode_fp_path(property), both
#' atomically and in that order. On a cache hit it writes nothing.
#' Stops when digest is missing or the tensor does not have LES_DECODE_N_EEG channels,
#' before anything is written.
extract_paper1_decoding <- function(property, time_step_ms = 4L, baseline_correct = TRUE) {

  stopifnot(property %in% names(LES_P1_PROPERTIES))

  # Reuse an existing tensor when every input that could change it is unchanged
  # (see the Tensor cache section). This is what lets the decode job be resubmitted
  # under a short walltime without repaying ~90 minutes and ~220 GB each time.
  .fp <- .les_decode_fingerprint(property, time_step_ms, baseline_correct)
  if (.les_decode_cache_ok(property, .fp)) {
    message("[decode-extract] ", property,
            " -- cached tensor matches current inputs; skipping extraction (",
            basename(les_decode_rds(property)), ")")
    return(invisible(les_decode_rds(property)))
  }

  # Full-epoch, ALL-CHANNEL load (required for the joint spatial pattern).
  # selected_macroregion = NULL applies no regional filter at all, so the load returns
  # every channel in the export, including the ones the importer's region map leaves
  # unassigned: the accelerometer, the mastoid pair and the restored FCz reference. The
  # map itself covers 30 scalp sites. Step (1b) of .les_build_decoding_tensor() then
  # reduces this to the 31 EEG channels recorded in every contributing session.
  # include_baseline keeps time < 0 for the per-trial baseline step. The importer's own
  # aggregation/z-scoring is bypassed (aggregate_* = FALSE); we reshape the raw samples.
  source(here::here("paper_1_transfer", "scripts", "_eeg_import.R"))  # lazy: heavy loader (see _eeg_import.R)
  message("[decode-extract] loading ", property,
          " (every channel present; non-EEG and session-inconsistent ones dropped after load) ...")
  raw <- les_p1_merge_trialbytrial(
    EEG_file_pattern      = les_p1_file_pattern(property),
    min_time              = LES_DECODE_MIN_MS,
    max_time              = LES_DECODE_MAX_MS,
    include_baseline      = TRUE,
    aggregate_electrodes  = FALSE,
    aggregate_time_points = FALSE,
    selected_macroregion  = NULL          # <- ALL channels (lateral + midline)
  )

  built <- .les_build_decoding_tensor(raw, property,
                                      time_step_ms = time_step_ms,
                                      baseline_correct = baseline_correct)

  # The montage is documented, and reported, as 31 EEG sensors. The builder only warns
  # on another count (its body is fingerprinted, so it is left as it is), and a warning
  # in a two-week job's log is easily missed, so the tensor is refused here instead. If
  # the montage change is intended, set LES_DECODE_N_EEG to the new count: it is part of
  # the cache fingerprint, so every cached tensor is then rebuilt (ISSUES.md G08-17).
  if (dim(built$X)[2] != LES_DECODE_N_EEG)
    stop("[decode-extract] ", property, ": ", dim(built$X)[2], " EEG channels (",
         paste(built$channels, collapse = ", "), "), but LES_DECODE_N_EEG is ",
         LES_DECODE_N_EEG, "; no tensor written.", call. = FALSE)

  out_path <- les_decode_rds(property)
  les_assert_readonly_data(out_path)      # never write inside read-only data/
  # A digest of the tensor values themselves. 09's block-checkpoint fingerprint keys
  # only on trial/participant/time COUNTS, so without this a corrected export that
  # leaves those counts unchanged would let 09 resume permutation blocks computed
  # from the previous amplitudes. Read back conditionally there, so tensors written
  # before this field existed keep their current fingerprint. digest is pinned in
  # renv.lock, so its absence is an environment fault and the extraction stops here,
  # before a tensor whose checkpoints could not key on its contents is written.
  if (!requireNamespace("digest", quietly = TRUE)) {
    stop("[decode-extract] package 'digest' is required so that 09's checkpoints key on ",
         "the tensor's contents; restore the pinned environment.", call. = FALSE)
  }
  built$x_digest <- digest::digest(built$X)
  .les_save_atomic(built, out_path)
  # Written only after the tensor is safely on disk, and capturing that file's own
  # size and mtime, so a later run cannot trust a fingerprint whose tensor has since
  # been replaced, truncated or removed.
  .les_decode_write_fingerprint(property, .fp)

  message(sprintf(
    paste0("[decode-extract] saved %s  (trials=%d, channels=%d, times=%d @ %d ms; ",
           "participants=%d; G=%d/UG=%d)"),
    basename(out_path), dim(built$X)[1], dim(built$X)[2], dim(built$X)[3],
    time_step_ms, dplyr::n_distinct(built$meta$participant_lab_ID),
    sum(built$meta$grammaticality == "Grammatical"),
    sum(built$meta$grammaticality == "Ungrammatical")
  ))

  rm(raw, built); gc()
  invisible(out_path)
}

# =============================================================================
# Entry point
# =============================================================================
#' Command-line entry: Rscript 08_extract_decoding_matrices.R [property]; every
#' property when none is given. The time step comes from LES_DECODE_TIME_STEP_MS only.
.run <- function() {
  args <- commandArgs(trailingOnly = TRUE)
  step <- les_decode_time_step_ms()      # env-driven; default 4 ms

  if (length(args) >= 1) {
    extract_paper1_decoding(args[[1]], time_step_ms = step)
  } else {
    for (property in names(LES_P1_PROPERTIES)) {
      extract_paper1_decoding(property, time_step_ms = step)
    }
  }
  message("[decode-extract] done.")
}

if (sys.nframe() == 0L) .run()
