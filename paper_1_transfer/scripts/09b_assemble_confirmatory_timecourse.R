# =============================================================================
# 09b_assemble_confirmatory_timecourse.R
# -----------------------------------------------------------------------------
# Rebuild one property's *_decoding_timecourse.csv from a BANKED block checkpoint
# plus the exploratory rows already in the CSV, and re-apply the second-layer FDR.
#
# WHY THIS EXISTS
# ---------------
# 09_run_decoding.R writes the CSV only after every block of run_timecourse() has been
# computed: the pooled "overall" block, the four session blocks and the eight
# session-by-language cells (see the bind_rows at the end of run_timecourse). That is the
# right design for a single uninterrupted run, but it couples the CONFIRMATORY inference
# to twelve EXPLORATORY blocks that cannot change it.
#
# The confirmatory family is the pooled overall time-course, one per property
# (LES_DECODE_CONFIRMATORY <- "overall"). The per-session and session-by-language
# decompositions are labelled exploratory in the `inference` column and never enter the
# family, so their permutation count cannot affect whether a confirmatory cluster
# survives. For gender agreement the overall block finished at B = 1000 and was banked by
# .les_tc_block(); the twelve exploratory blocks are still running. Waiting for them
# before reporting an admissible confirmatory result would be waiting on work that, by the
# analysis's own definition of the family, cannot change that result.
#
# This script therefore assembles the CSV from what exists, WITHOUT recomputing anything
# and WITHOUT touching any default code path. It is opt-in: nothing sources it, and
# 09_run_decoding.R is unchanged. When the exploratory blocks finish, run_timecourse()
# writes the whole CSV at one permutation count in the ordinary way and supersedes this.
#
# THE RESULTING ARTEFACT IS DELIBERATELY MIXED, AND SAYS SO
# ---------------------------------------------------------
# The confirmatory rows carry the banked block's n_perm; the exploratory rows keep the
# count they were computed at. n_perm is a per-row column that the manuscript reads rather
# than assumes, so the artefact is self-describing, but two reported quantities span
# analyses and must be read with the mixture in mind: the smallest cluster-level p "across
# all analyses", and whether that p sits at the permutation floor, which is 1/(B+1) and so
# differs between the two strata.
#
# FAILS CLOSED
# ------------
# Every mismatch stops the script rather than writing a plausible-looking CSV: a checkpoint
# recorded against a different property, a checkpoint that is not the overall block, a
# fingerprint whose permutation count contradicts the block's own n_perm column, a count
# that would DOWNGRADE the stored rows, a time grid that disagrees with the stored one, or a
# column set that does not match. The FDR admissibility guard in .les_fdr_confirmatory() is
# the pipeline's own and is not bypassed.
#
# ON TENSOR PROVENANCE. The block fingerprint records trial, participant and time counts,
# the permutation count and the seed, but no digest of the tensor's contents (see the
# no-digest branch of .les_tc_fingerprint()), so counts alone cannot prove that the block
# was computed against the tensor now on disk. Where step 08's own
# `_decoding_<property>_fingerprint.rds` is available, this script closes that gap by
# requiring the tensor's size and mtime to match what step 08 recorded, and the checkpoint
# to postdate the tensor. That is a cheap check on a 660 MB file, and it fails closed.
#
# USAGE
#   Rscript 09b_assemble_confirmatory_timecourse.R [property] [checkpoint.rds]
# Defaults: property = gender_agreement, checkpoint = paper1_derived(
#   "_tc_ckpt_<property>_overall.rds"), overridable with LES_P1_CKPT.
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("paper_1_transfer", "scripts", "09_run_decoding.R"))
})

.les_assemble_confirmatory <- function(property = "gender_agreement",
                                       ckpt_path = NULL) {

  if (is.null(ckpt_path) || !nzchar(ckpt_path)) {
    ckpt_path <- Sys.getenv("LES_P1_CKPT", unset = "")
    if (!nzchar(ckpt_path))
      ckpt_path <- paper1_derived(paste0("_tc_ckpt_", property, "_overall.rds"))
  }
  if (!file.exists(ckpt_path))
    stop("[assemble] no banked checkpoint at ", ckpt_path)

  ck <- readRDS(ckpt_path)
  if (!is.list(ck) || !all(c("result", "fingerprint") %in% names(ck)))
    stop("[assemble] ", basename(ckpt_path), " is not a block checkpoint")
  banked <- ck$result
  if (!is.data.frame(banked) || !nrow(banked))
    stop("[assemble] checkpoint carries no result rows")

  # The checkpoint must be THIS property's OVERALL block, and nothing else.
  if (!all(banked$property == property))
    stop("[assemble] checkpoint is for property '", unique(banked$property)[1],
         "', not '", property, "'")
  if (!identical(unique(banked$analysis), LES_DECODE_CONFIRMATORY))
    stop("[assemble] checkpoint holds analysis '", paste(unique(banked$analysis), collapse = "/"),
         "', not the confirmatory '", LES_DECODE_CONFIRMATORY, "' block")

  b_new <- unique(banked$n_perm)
  if (length(b_new) != 1L || is.na(b_new))
    stop("[assemble] checkpoint mixes permutation counts: ",
         paste(b_new, collapse = ", "))
  # The fingerprint records the count the block was computed under. If it disagrees with
  # the n_perm column, one of the two is stale and the block cannot be trusted.
  fp_b <- sub(".*_B([0-9]+)_.*", "\\1", as.character(ck$fingerprint)[1])
  if (!grepl("^[0-9]+$", fp_b) || as.integer(fp_b) != b_new)
    stop("[assemble] fingerprint (", ck$fingerprint, ") and n_perm (", b_new, ") disagree")

  # Tensor provenance. The block fingerprint carries counts, not contents, so on its own it
  # cannot tie the banked permutations to the tensor now on disk. Step 08 records the
  # tensor's size and mtime beside it; where that record is present, require both to match
  # and require the block to postdate the tensor.
  tfp_path <- paper1_derived(paste0("_decoding_", property, "_fingerprint.rds"))
  ten_path <- paper1_derived(paste0("_decoding_", property, ".rds"))
  if (file.exists(tfp_path) && file.exists(ten_path)) {
    tfp <- readRDS(tfp_path)
    if (!isTRUE(all.equal(as.numeric(tfp$tensor_size), as.numeric(file.size(ten_path)))))
      stop("[assemble] tensor size (", file.size(ten_path), ") differs from the ",
           tfp$tensor_size, " step 08 recorded: the tensor changed after the block was banked")
    if (!isTRUE(all.equal(as.numeric(tfp$tensor_mtime), as.numeric(file.mtime(ten_path)),
                          tolerance = 1e-6)))
      stop("[assemble] tensor mtime differs from the one step 08 recorded: the tensor was ",
           "rebuilt after the block was banked")
    if (file.mtime(ckpt_path) < file.mtime(ten_path))
      stop("[assemble] the banked block predates the tensor on disk")
    message("[assemble] tensor provenance verified against step 08's record")
  } else {
    message("[assemble] NOTE: no tensor record beside the checkpoint, so tensor provenance ",
            "was NOT verified here. Verify it where the tensor lives before reporting.")
  }

  path <- paper1_results(paste0(property, "_decoding_timecourse.csv"))
  if (!file.exists(path))
    stop("[assemble] no existing time-course CSV at ", path,
         " -- there are no exploratory rows to carry over; run 09 instead")
  old <- utils::read.csv(path, stringsAsFactors = FALSE)

  is_conf_old <- old$analysis == LES_DECODE_CONFIRMATORY
  b_old <- suppressWarnings(max(old$n_perm[is_conf_old], na.rm = TRUE))
  if (is.finite(b_old) && b_new < b_old)
    stop("[assemble] refusing to downgrade the confirmatory rows from B = ", b_old,
         " to B = ", b_new)

  # The banked block must describe the same epoch as the rows it replaces. A different
  # time grid means the tensor changed under the checkpoint.
  t_old <- sort(unique(old$time_ms[is_conf_old]))
  t_new <- sort(unique(banked$time_ms))
  if (length(t_old) && !isTRUE(all.equal(t_old, t_new)))
    stop("[assemble] time grid differs from the stored confirmatory rows (",
         length(t_new), " vs ", length(t_old), " points)")

  # Drop the derived columns from both sides; .les_fdr_confirmatory() recreates them.
  derived <- c("cluster_p_fdr", "significant_fdr", "inference")
  keep    <- setdiff(names(banked), derived)
  explor  <- old[!is_conf_old, , drop = FALSE]
  missing <- setdiff(keep, names(explor))
  if (length(missing))
    stop("[assemble] exploratory rows lack column(s): ", paste(missing, collapse = ", "))

  res <- dplyr::bind_rows(banked[, keep, drop = FALSE],
                          explor[, keep, drop = FALSE])
  res <- .les_fdr_confirmatory(res)   # the pipeline's own guard and correction

  les_assert_readonly_data(path)
  utils::write.csv(res, path, row.names = FALSE)

  conf <- unique(res[res$inference == "confirmatory" & !is.na(res$cluster_id),
                     c("analysis", "level", "cluster_id", "cluster_p", "significant_fdr")])
  old_conf <- unique(old[is_conf_old & !is.na(old$cluster_id),
                         c("cluster_id", "significant_fdr")])
  message("[assemble] ", basename(path), ": ", nrow(res), " rows (",
          sum(res$inference == "confirmatory"), " confirmatory at B = ", b_new, ", ",
          sum(res$inference == "exploratory"), " exploratory at B = ",
          paste(sort(unique(res$n_perm[res$inference == "exploratory"])), collapse = "/"), ")")
  message("[assemble] confirmatory clusters surviving FDR: ",
          sum(conf$significant_fdr), " of ", nrow(conf),
          "  (previously ", sum(old_conf$significant_fdr), " of ", nrow(old_conf), ")")
  invisible(path)
}

if (sys.nframe() == 0L) {
  a <- commandArgs(trailingOnly = TRUE)
  .les_assemble_confirmatory(property  = if (length(a) >= 1) a[1] else "gender_agreement",
                             ckpt_path = if (length(a) >= 2) a[2] else NULL)
}
