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
# Trials with a response time outside (200, 4000) ms are dropped by 02_extract_accuracy.R.
# The bounds are carried over unchanged from the legacy behavioural import so that both
# pipelines analyse the same trials; that script records no rationale for them.
LES_P1_ACC_RT_MS <- c(200, 4000)

# --- RSVP timing census (ms; 01b_extract_rsvp_timing.R) ----------------------
# Subsequent word onsets are counted within (0, LES_P1_RSVP_WINDOW_MS] of the critical
# onset, the upper bound of the late analysis window. An onset-to-onset step above
# LES_P1_RSVP_SOA_MAX_MS marks a corrupt log row and excludes the trial.
LES_P1_RSVP_WINDOW_MS  <- 900
LES_P1_RSVP_SOA_MAX_MS <- 5000

# --- Default seed of the decoding stage --------------------------------------
# 09_run_decoding.R reads LES_DECODE_SEED from the environment with its own literal
# default, and hpc/08_decoding.slurm exports the same literal. The three must agree,
# because 03_fit_brms_erp.R records this value in results/_provenance.csv as the seed
# the decoding ran under. test_exclusion_guard.R checks the two literals against it.
LES_P1_DECODE_SEED_DEFAULT <- 20260702L

# --- Electrode macro-regions --------------------------------------------------
# "lateral" = the six left/right clusters (carry the hemisphere contrast);
# "midline" = the three midline clusters (no hemisphere contrast -> midline models
# omit the hemisphere term, exactly as in the legacy lateral/midline split).
LES_P1_MACROREGIONS <- c("lateral", "midline")

# --- Grammaticality conditions analysed --------------------------------------
# Paper 1 contrasts the canonical grammatical (S101) vs. ungrammatical (S102)
# sentences. The ancillary S103 violation conditions are excluded so that the
# grammaticality contrast has the same meaning across all three properties.
LES_P1_GRAMMATICALITY_REGEX <- "S10[12]"

# --- Datasets excluded for an incompatible offline filter ---------------------
# Four Session-3 recordings were high-pass filtered offline at 1 Hz rather than the
# 0.1 Hz used for every other dataset in the study (recovered from the archived
# BrainVision Analyzer history; the live node postdates the switch elsewhere, so it is
# a processing oversight rather than a superseded branch).
#
# The mismatch bears directly on the components this paper measures. Tanner,
# Morgan-Short and Luck (2015, https://doi.org/10.1111/psyp.12437) filtered data from a
# syntactic- and semantic-violation paradigm, the same design class as ours, at a range
# of cutoffs. They found that high-pass cutoffs of 0.3 Hz and above introduced
# artefactual effects of opposite polarity preceding the true N400 and P600 effects. A
# 1 Hz cutoff is well inside that range. See also Widmann, Schroger and Maess (2015,
# https://doi.org/10.1016/j.jneumeth.2014.08.002) on filter-induced distortion.
#
# These four participant-sessions are therefore dropped from the primary analysis. The
# justification is a priori, resting on the documented behaviour of the filter rather
# than on anything observed in these participants' data, so the exclusion is not
# contingent on the results. Set LES_P1_KEEP_MISFILTERED=1 to retain them and refit on the
# full sample. That comparison is NOT currently reported: every fit behind the manuscript
# has the exclusion applied, as `results/_pooled_fit_metadata.csv` records
# (`exclusion_applied` TRUE and `keep_misfiltered` FALSE in every row it holds, across the
# random-effect structures, prior sets and retention-free variants that have been fitted,
# and the three accuracy models for which the exclusion does not apply). An earlier
# version of the Method described a
# full-sample sensitivity analysis that had never been run; the manuscript now points here
# instead. Running the grid under this variable is what would make that claim true again.
LES_P1_MISFILTERED <- data.frame(
  participant_lab_ID = c(7L, 8L, 9L, 16L),
  session            = 3L,
  stringsAsFactors   = FALSE
)

# Rows of `d` that belong to a mis-filtered participant-session, or NA when `d`
# does not carry the two identifying columns.
#
# NOTE: both columns are FACTORS in the extracted data (session has levels
# "2","3","4","6"). as.integer() on a factor returns the LEVEL INDEX, not the value,
# so as.integer(session) would give 1,2,3,4 and silently match the wrong rows --
# "session 3" would resolve to level 3, i.e. session 4. Always go via as.character().
les_p1_misfiltered_rows <- function(d) {
  if (!all(c("participant_lab_ID", "session") %in% names(d))) return(NA_integer_)
  .as_int <- function(x) suppressWarnings(as.integer(as.character(x)))
  bad <- paste(LES_P1_MISFILTERED$participant_lab_ID, LES_P1_MISFILTERED$session)
  key <- paste(.as_int(d$participant_lab_ID), .as_int(d$session))
  sum(key %in% bad)
}

# Drop the mis-filtered participant-sessions unless explicitly retained.
les_p1_drop_misfiltered <- function(d) {
  if (les_p1_keep_misfiltered()) {
    message("[config] LES_P1_KEEP_MISFILTERED=1: retaining the four 1 Hz Session-3 datasets.")
    return(d)
  }
  n_bad <- les_p1_misfiltered_rows(d)
  if (is.na(n_bad)) return(d)
  .as_int <- function(x) suppressWarnings(as.integer(as.character(x)))
  bad <- paste(LES_P1_MISFILTERED$participant_lab_ID, LES_P1_MISFILTERED$session)
  key <- paste(.as_int(d$participant_lab_ID), .as_int(d$session))
  out <- d[!(key %in% bad), , drop = FALSE]
  if (n_bad > 0) {
    # Count the datasets actually found, not the number on the list: a property that
    # was never presented in Session 3 legitimately matches none of them, and a log
    # line claiming four every time would hide that.
    n_sets <- length(unique(key[key %in% bad]))
    message(sprintf("[config] dropped %d rows from %d of the %d mis-filtered (1 Hz) Session-3 datasets.",
                    n_bad, n_sets, nrow(LES_P1_MISFILTERED)))
  }
  out
}

# --- Cache tag for the mis-filter-retained variant ----------------------------
#
# LES_P1_KEEP_MISFILTERED changes the DATA, not the priors, so tagging the fit alone is
# not enough. Script 01 would otherwise overwrite the 18 derived single-trial files that
# every cached fit was computed from, and script 03 would overwrite the fits themselves,
# together with their convergence, summary, PPC and fit-metadata artefacts, at the
# reported names. brms caches with file_refit = "on_change" (see les_brm), so genuinely
# different data does not skip the cache: it refits and writes over what is there, and
# nothing fails closed.
#
# The tag is therefore threaded through les_p1_cell_rds() (the derived data) and through
# cell_tag in 03_fit_brms_erp.R (the fit and its artefacts). It is placed FIRST among the
# tags, ahead of the prior, item and retention tags, because several accessors in the
# manuscript and in script 05 read the random-effect structure off the END of a model id
# (grepl("_itemslope(_retfree)?$", ...)); a fourth tag appended after those would silently
# reclassify every maximal variant fit as base. With the variable unset the tag is "" and
# every path is exactly what it was.
les_p1_keep_misfiltered <- function() identical(Sys.getenv("LES_P1_KEEP_MISFILTERED"), "1")
les_p1_misfiltered_tag  <- function() if (les_p1_keep_misfiltered()) "_keepmisfiltered" else ""

# --- Cache tag for the diversity-covariate variant of the accuracy models ------
#
# LES_P1_ACC_DIVERSITY=1 adds the LHQ3 multilingual language diversity score to the
# accuracy models as a main effect, mirroring its role in the ERP models. It changes
# both the DATA (script 02 joins the questionnaire) and the FORMULA (script 04), so the
# tag is threaded through les_p1_accuracy_rds() (the derived files) and into model_id
# in 04_fit_brms_accuracy.R (the fit and its artefacts). As with the mis-filter tag, it
# sits ahead of the prior tag. With the variable unset the tag is "" and every path is
# exactly what it was.
les_p1_acc_diversity     <- function() identical(Sys.getenv("LES_P1_ACC_DIVERSITY"), "1")
les_p1_acc_diversity_tag <- function() if (les_p1_acc_diversity()) "_diversity" else ""

# The accuracy datasets written by 02_extract_accuracy.R and read by
# 04_fit_brms_accuracy.R. The diversity variant reads and writes its own files, so an
# opt-in extraction can never overwrite the data behind the reported fits.
les_p1_accuracy_rds <- function(property) {
  paper1_derived(paste0("accuracy_", property, les_p1_acc_diversity_tag(), ".rds"))
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
# `exclusion_applicable` marks whether the 1 Hz filter exclusion has any bearing on
# this model. It is FALSE for the accuracy models: those fit the behavioural
# grammaticality judgements, which are unaffected by how the EEG was filtered
# offline, so they legitimately retain the four Session-3 participants and must not
# be read as evidence that the exclusion failed.
les_p1_write_fit_meta <- function(dat, model_id, path, exclusion_applicable = TRUE) {
  n_bad <- if (exclusion_applicable) les_p1_misfiltered_rows(dat) else NA_integer_
  .ver <- function(p) tryCatch(as.character(utils::packageVersion(p)),
                               error = function(e) NA_character_)
  rec <- data.frame(
    model                = model_id,
    n_obs                = nrow(dat),
    n_participants       = length(unique(as.character(dat$participant_lab_ID))),
    exclusion_applicable = exclusion_applicable,
    misfiltered_rows     = n_bad,
    exclusion_applied    = !exclusion_applicable || (!is.na(n_bad) && n_bad == 0L),
    keep_misfiltered     = les_p1_keep_misfiltered(),
    prior_set            = Sys.getenv("LES_PRIOR_SET", unset = "informative"),
    # Random-effect structure. Without this the pooled table cannot tell a base fit
    # from a maximal one -- they share a model id and a prior set, and the resulting
    # duplicate keys silently disable the same-data check in the prior-sensitivity
    # step and inflate the count the exclusion guard reads.
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
# Matches BOTH artificial-language groups (any participant number) for one
# property, e.g. gender:  ^\d+_trialbytrial_S1_S10[12]\.
les_p1_file_pattern <- function(property) {
  code <- LES_P1_PROPERTIES[[property]]
  if (is.null(code)) stop("Unknown property: ", property)
  paste0("^\\d+_trialbytrial_", code, "_", LES_P1_GRAMMATICALITY_REGEX, "\\.")
}

# --- Canonical cell identifier and derived-file path --------------------------
les_p1_cell_id <- function(property, window, macroregion) {
  paste("erp", property, window, macroregion, sep = "_")
}

# The mis-filter-retained variant reads and writes its own derived files, so an opt-in
# extraction can never overwrite the data behind the reported fits.
les_p1_cell_rds <- function(property, window, macroregion) {
  paper1_derived(paste0(les_p1_cell_id(property, window, macroregion),
                        les_p1_misfiltered_tag(), ".rds"))
}

# --- The full 18-cell analysis grid ------------------------------------------
# One row per (property x window x macroregion) cell. Pipeline scripts iterate
# over (or subset, for per-cell HPC jobs) this table.
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
# The decision rule behind the Method's exclusion sentence. `tbl` is the pooled fit
# metadata (results/_pooled_fit_metadata.csv, or NULL when it is absent) and `primary`
# the random-effect structure the manuscript reports. Returns "" when every reported ERP
# fit carries a clean record, otherwise the reason the claim cannot yet stand, which the
# manuscript wraps in its pending marker. It lives here, beside the helpers it audits, so
# that the manuscript and test_exclusion_guard.R apply one rule.
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
  # The mis-filter-retained refits are excluded here for the same reason. They are a
  # sensitivity analysis that deliberately keeps the four datasets, so their records carry
  # exclusion_applied = FALSE by design; counting them would make the reported grid look
  # stale and print a Pending marker over results that are in fact clean. Their model ids
  # carry a "_keepmisfiltered" tag, and the boolean column is the direct test.
  m <- tbl[tbl$exclusion_applicable %in% TRUE &
             tbl$prior_variant %in% "informative", , drop = FALSE]
  if ("keep_misfiltered" %in% names(m)) {
    m <- m[!(m$keep_misfiltered %in% TRUE), , drop = FALSE]
  }
  if ("structure" %in% names(m)) {
    m <- m[m$structure %in% primary, , drop = FALSE]
  } else if (!identical(primary, "base")) {
    return(paste0("the fit records predate the random-effect-structure column, ",
                  "so the structure behind the reported fits cannot be confirmed"))
  }
  if (nrow(m) == 0) return("no fitted model carries a record of this exclusion")
  n_stale <- sum(!(m$exclusion_applied %in% TRUE))
  if (n_stale > 0) {
    return(sprintf("%d of %d fitted ERP models still contain these datasets",
                   n_stale, nrow(m)))
  }
  # Every fit that reported in is clean, but a partial refit would also look clean.
  # Require the audit to cover the whole grid before the claim is allowed to stand.
  if (nrow(m) < n_expected) {
    return(sprintf("only %d of the %d ERP models have been refitted under it",
                   nrow(m), n_expected))
  }
  ""
}

cat("[paper1/_config] ERP grid:",
    length(LES_P1_PROPERTIES), "properties x",
    length(LES_P1_WINDOWS), "windows x",
    length(LES_P1_MACROREGIONS), "macroregions =",
    nrow(les_p1_erp_grid()), "cells.\n")
