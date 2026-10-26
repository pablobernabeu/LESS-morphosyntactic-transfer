# =============================================================================
# 09b_assemble_confirmatory_timecourse.R
# -----------------------------------------------------------------------------
# Write one property's *_decoding_timecourse.csv from the block checkpoints step 09 has
# already banked, before every block has finished, and apply the second-layer FDR.
#
# WHY THIS EXISTS
# ---------------
# 09_run_decoding.R writes the CSV only after every block of run_timecourse() has been
# computed: the pooled "overall" block, the per-session blocks and the session-by-language
# cells. It banks each block as it finishes, though (.les_tc_block()), and the
# CONFIRMATORY family is the overall block alone (LES_DECODE_CONFIRMATORY <- "overall");
# the exploratory blocks are labelled as such in the `inference` column and cannot change
# whether a confirmatory cluster survives. When a run is cut short, by the walltime or a
# node failure, and the CSV is needed before the resubmitted job finishes, this script
# writes it from the blocks already banked, WITHOUT recomputing anything and WITHOUT
# touching any default code path. It is opt-in: nothing sources it. When run_timecourse()
# completes, it writes the whole CSV in the ordinary way and supersedes this one.
# (LES_DECODE_CONFIRMATORY_ONLY=1 makes step 09 itself write the overall block alone; this
# script also carries every exploratory block that is already banked.)
#
# WHERE THE ROWS COME FROM, AND WHY NOT FROM THE EXISTING CSV
# -----------------------------------------------------------
# Every row written here comes from a block checkpoint, and from nowhere else. A first
# version took the exploratory rows from the CSV already in results/. A CSV row does not
# record the tensor it was computed from, and on 4 September 2026 that version merged a
# B = 1000 overall block with exploratory rows computed months earlier on a tensor that
# still held datasets the Method excludes, with nothing to detect it (ISSUES.md G08-01).
# A block checkpoint, by contrast, stores the fingerprint it was computed under
# (.les_tc_fingerprint() in step 09): the tensor's trial, participant and time counts, B,
# the seed and the leading characters of a digest of the tensor's values. This script
# requires every block's fingerprint to equal that of the tensor now on disk in
# everything but B, recomputes the tensor's digest to confirm the stored one, and checks
# each block's trial and participant counts against the tensor. Rows computed on any
# other tensor, or on the same tensor under another seed, are therefore refused.
#
# THE PERMUTATION COUNT MAY DIFFER BETWEEN BLOCKS
# -----------------------------------------------
# B is the one fingerprint field allowed to differ, so a confirmatory block recomputed at
# a higher B can be combined with exploratory blocks still at a lower one. Each block's B
# is read from its own fingerprint and must equal the block's n_perm column, which the
# manuscript reads per row. Two reported quantities span blocks and must then be read
# with the mixture in mind: the smallest cluster-level p "across all analyses", and
# whether it sits at the permutation floor, 1/(B+1), which differs between the strata.
#
# FAILS CLOSED
# ------------
# The script stops, writing nothing, when: the tensor has no stored digest or its values
# no longer match it; the tensor's size or mtime differs from what step 08 recorded beside
# it, or that record is missing; the overall checkpoint is absent; any checkpoint cannot
# be read, holds the wrong property or analysis, or carries a fingerprint that disagrees
# with the tensor (other than in B) or a B that disagrees with its n_perm column; a block's
# trial or participant count differs from the tensor's; a checkpoint exists for a block
# the tensor would not produce; the blocks' column sets differ; or an existing CSV holds
# a block this assembly would drop or a block at a higher B than this assembly carries
# (move such a CSV aside first if it came from another tensor). The FDR admissibility
# guard in .les_fdr_confirmatory() is the pipeline's own and is not bypassed.
#
# With every block banked, the CSV written here is identical to the one run_timecourse()
# writes, because both bind the same block results in the same order and apply the same
# correction.
#
# USAGE
#   Rscript 09b_assemble_confirmatory_timecourse.R [property] [overall_checkpoint.rds]
# Defaults: property = gender_agreement, overall checkpoint = paper1_derived(
#   "_tc_ckpt_<property>_overall.rds"), overridable with LES_P1_CKPT. The other blocks are
#   looked for beside the overall checkpoint, under step 09's names. Under
#   LES_P1_EXCLUDE_REPROCESSED=1 every path carries the _exclreproc tag after the property,
#   as in steps 08 and 09, so the robustness run is assembled from and into its own files.
#   Run it with the LES_DECODE_SEED the decoding job used (the default unless overridden).
#   It loads and digests the tensor (about 1 GB in memory for gender agreement), so run it
#   on a compute node, not a login node.
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("paper_1_transfer", "scripts", "09_run_decoding.R"))
})

#' The blocks run_timecourse() would produce on this tensor, in its order.
#' @param meta the meta data.frame of .les_complete_trials().
#' @return data.frame(block, analysis, level, n_trials, n_participants), one row per
#'   block, with the counts .les_decode_timecourse() records for it.
#' Mirrors the loops and floors of run_timecourse() in 09_run_decoding.R (>= 20 trials
#' and >= 3 participants per session or session x language cell); change both together.
.les_expected_blocks <- function(meta) {
  row <- function(block, analysis, level, sel)
    data.frame(block = block, analysis = analysis, level = level, n_trials = sum(sel),
               n_participants = length(unique(meta$participant_lab_ID[sel])),
               stringsAsFactors = FALSE)
  keep <- function(sel) sum(sel) >= 20 && length(unique(meta$participant_lab_ID[sel])) >= 3
  out <- list(row("overall", "overall", "all", rep(TRUE, nrow(meta))))
  for (s in LES_ERP_SESSIONS) {
    sel <- meta$session == as.character(s)
    if (keep(sel)) out[[length(out) + 1L]] <- row(paste0("session_", s), "by_session",
                                                  paste0("session_", s), sel)
  }
  for (s in LES_ERP_SESSIONS) for (lg in c("Mini-English", "Mini-Norwegian")) {
    sel <- meta$session == as.character(s) & meta$mini_language == lg
    if (keep(sel)) out[[length(out) + 1L]] <- row(
      paste0("session_", s, "_", gsub("[^A-Za-z0-9]", "", lg)), "by_session_language",
      paste0("session_", s, "_", lg), sel)
  }
  do.call(rbind, out)
}

#' A block fingerprint with its permutation count blanked, for comparison across B.
#' @param fp character fingerprint from .les_tc_fingerprint().
#' @return `fp` with "_B<digits>_" replaced by "_B*_".
.les_fp_sans_b <- function(fp) sub("_B[0-9]+_", "_B*_", as.character(fp)[1])

#' Assemble one property's time-course CSV from its banked block checkpoints.
#' @param property one of names(LES_P1_PROPERTIES).
#' @param ckpt_path path of the overall block's checkpoint, or NULL for the default
#'   (LES_P1_CKPT, else paper1_derived("_tc_ckpt_<property><tag>_overall.rds")).
#' @return invisibly, the path of the CSV written,
#'   paper1_results("<property><tag>_decoding_timecourse.csv").
#' Reads the tensor and its step-08 record, the checkpoints and any existing CSV; writes
#' only the CSV. Draws nothing from the RNG. Stops on any of the conditions in the
#' header's FAILS CLOSED list.
.les_assemble_confirmatory <- function(property = "gender_agreement",
                                       ckpt_path = NULL) {
  stopifnot(property %in% names(LES_P1_PROPERTIES))
  tag <- les_p1_exclreproc_tag()
  if (is.null(ckpt_path) || !nzchar(ckpt_path)) {
    ckpt_path <- Sys.getenv("LES_P1_CKPT", unset = "")
    if (!nzchar(ckpt_path))
      ckpt_path <- paper1_derived(paste0("_tc_ckpt_", property, tag, "_overall.rds"))
  }
  if (!file.exists(ckpt_path))
    stop("[assemble] no banked overall checkpoint at ", ckpt_path, call. = FALSE)

  # --- The tensor now on disk, and its provenance --------------------------------------
  # Step 08 records the tensor's size and mtime beside it when it writes it; a mismatch
  # means the file was modified, replaced or copied after step 08 recorded it, so the
  # inputs that record lists are not known to be the ones that built it.
  ten_path <- les_decode_rds(property)
  tfp_path <- .les_decode_fp_path(property)
  if (!file.exists(ten_path)) stop("[assemble] no tensor at ", ten_path, call. = FALSE)
  if (!file.exists(tfp_path))
    stop("[assemble] no step-08 record beside the tensor (", basename(tfp_path),
         "), so the inputs that built it cannot be stated", call. = FALSE)
  # Compared exactly, as step 08's own cache check compares them. The earlier version used
  # all.equal(), whose RELATIVE tolerance of 1e-6 on an mtime near 1.8e9 seconds let any
  # rewrite within about half an hour of the record pass.
  tfp <- readRDS(tfp_path)
  inf <- file.info(ten_path)
  if (!identical(as.numeric(tfp$tensor_size), as.numeric(inf$size)))
    stop("[assemble] tensor size (", inf$size, ") differs from the ", tfp$tensor_size,
         " step 08 recorded: the tensor was modified or copied after step 08 wrote it",
         call. = FALSE)
  if (!identical(as.numeric(tfp$tensor_mtime), as.numeric(inf$mtime)))
    stop("[assemble] tensor mtime differs from the one step 08 recorded: the tensor was ",
         "modified or copied after step 08 wrote it", call. = FALSE)

  built <- .les_load_decoding(property)
  if (is.null(built$x_digest))
    stop("[assemble] the tensor carries no x_digest, so no checkpoint can be tied to its ",
         "values; re-extract it with the current step 08", call. = FALSE)
  # The stored digest is what the checkpoints were keyed on; recomputing it confirms that
  # the values on disk are still the ones it describes.
  if (!identical(digest::digest(built$X), built$x_digest))
    stop("[assemble] the tensor's values no longer match its stored digest", call. = FALSE)
  d <- .les_complete_trials(built)
  rm(built)
  fp_now <- .les_fp_sans_b(.les_tc_fingerprint(d))
  expected <- .les_expected_blocks(d$meta)
  message("[assemble] tensor ", basename(ten_path), ": fingerprint ", fp_now,
          "; ", nrow(expected), " blocks expected")

  # --- The banked blocks -----------------------------------------------------------------
  # The overall checkpoint as named; every other block under step 09's name beside it.
  ck_dir <- dirname(ckpt_path)
  pat <- paste0("^_tc_ckpt_", property, tag, "_(session_[0-9]+(_[A-Za-z0-9]+)?)\\.rds$")
  found <- list.files(ck_dir, pattern = pat)
  found_blocks <- sub(pat, "\\1", found)
  stray <- setdiff(found_blocks, expected$block)
  if (length(stray))
    stop("[assemble] checkpoint(s) for block(s) this tensor would not produce: ",
         paste(stray, collapse = ", "), call. = FALSE)
  paths <- c(overall = ckpt_path,
             stats::setNames(file.path(ck_dir, found), found_blocks))

  banked <- list()
  for (i in seq_len(nrow(expected))) {
    e <- expected[i, ]
    f <- paths[e$block]
    if (is.na(f)) next                                    # not banked yet
    ck <- try(readRDS(f), silent = TRUE)
    if (inherits(ck, "try-error") || !is.list(ck) ||
        !all(c("result", "fingerprint") %in% names(ck)))
      stop("[assemble] ", basename(f), " is not a readable block checkpoint (it may still ",
           "be being written)", call. = FALSE)
    r <- ck$result
    if (!is.data.frame(r))
      stop("[assemble] ", basename(f), " carries no result table", call. = FALSE)
    if (!identical(.les_fp_sans_b(ck$fingerprint), fp_now))
      stop("[assemble] ", basename(f), " was computed under fingerprint ", ck$fingerprint,
           ", which does not match the tensor on disk (", fp_now, ")", call. = FALSE)
    # .les_decode_timecourse() banks an empty table for a cell with one class only, and
    # run_timecourse() binds it as no rows; do the same.
    if (!nrow(r)) { banked[[e$block]] <- r; next }
    if (!all(r$property == property) || !all(r$analysis == e$analysis) ||
        !all(r$level == e$level))
      stop("[assemble] ", basename(f), " holds ", paste(unique(r$property), collapse = "/"),
           " / ", paste(unique(r$analysis), collapse = "/"), " / ",
           paste(unique(r$level), collapse = "/"), ", not ", property, " / ", e$analysis,
           " / ", e$level, call. = FALSE)
    b <- unique(r$n_perm)
    fp_b <- sub(".*_B([0-9]+)_.*", "\\1", as.character(ck$fingerprint)[1])
    if (length(b) != 1L || is.na(b) || !grepl("^[0-9]+$", fp_b) || as.integer(fp_b) != b)
      stop("[assemble] ", basename(f), ": fingerprint (", ck$fingerprint, ") and n_perm (",
           paste(b, collapse = ", "), ") disagree", call. = FALSE)
    if (!all(r$n_trials == e$n_trials) || !all(r$n_participants == e$n_participants))
      stop("[assemble] ", basename(f), " counts ",
           paste(unique(r$n_trials), collapse = "/"), " trials of ",
           paste(unique(r$n_participants), collapse = "/"), " participants; the tensor ",
           "gives ", e$n_trials, " of ", e$n_participants, call. = FALSE)
    banked[[e$block]] <- r
  }
  if (is.null(banked[["overall"]]) || !nrow(banked[["overall"]]))
    stop("[assemble] the overall block is not banked, or holds no rows", call. = FALSE)
  cols <- lapply(Filter(nrow, banked), names)
  if (!all(vapply(cols, identical, logical(1), cols[[1]])))
    stop("[assemble] the banked blocks do not share one column set", call. = FALSE)

  res <- dplyr::bind_rows(banked)
  res <- .les_fdr_confirmatory(res)   # the pipeline's own guard and correction

  # --- Never downgrade what is already written ------------------------------------
  path <- paper1_results(paste0(property, tag, "_decoding_timecourse.csv"))
  if (file.exists(path)) {
    old <- utils::read.csv(path, stringsAsFactors = FALSE)
    key <- function(x) paste(x$analysis, x$level, sep = "|")
    b_old <- tapply(old$n_perm, key(old), max)
    b_new <- tapply(res$n_perm, key(res), max)
    dropped <- setdiff(names(b_old), names(b_new))
    if (length(dropped))
      stop("[assemble] ", basename(path), " already holds block(s) this assembly lacks (",
           paste(dropped, collapse = ", "), "); move it aside first if it came from ",
           "another tensor", call. = FALSE)
    lower <- names(b_new)[names(b_new) %in% names(b_old) &
                            b_new[names(b_new)] < b_old[names(b_new)]]
    if (length(lower))
      stop("[assemble] refusing to lower the permutation count of ",
           paste(lower, collapse = ", "), call. = FALSE)
  }

  les_assert_readonly_data(path)
  utils::write.csv(res, path, row.names = FALSE)

  missing <- setdiff(expected$block, names(banked))
  conf <- unique(res[res$inference == "confirmatory" & !is.na(res$cluster_id),
                     c("cluster_id", "significant", "significant_fdr")])
  message("[assemble] ", basename(path), ": ", nrow(res), " rows from ", length(banked),
          " of ", nrow(expected), " blocks (B = ",
          paste(sort(unique(res$n_perm)), collapse = "/"), ")",
          if (length(missing))
            paste0("; not yet banked: ", paste(missing, collapse = ", ")))
  message("[assemble] confirmatory clusters: ", nrow(conf), "; significant against the ",
          "max-cluster null: ", sum(conf$significant), "; surviving FDR: ",
          sum(conf$significant_fdr))
  invisible(path)
}

if (sys.nframe() == 0L) {
  a <- commandArgs(trailingOnly = TRUE)
  .les_assemble_confirmatory(property  = if (length(a) >= 1) a[1] else "gender_agreement",
                             ckpt_path = if (length(a) >= 2) a[2] else NULL)
}
