# =============================================================================
# paper_1_transfer/scripts/09_run_decoding.R
# Phase 4b -- Multivariate pattern analysis (MVPA) decoding of grammaticality
# -----------------------------------------------------------------------------
# WHAT THIS SCRIPT PRODUCES (tidy CSVs in paper1_results())
# ---------------------------------------------------------
#   <property>_decoding_timecourse.csv
#       Per-time-point Grammatical-vs-Ungrammatical decoding AUC with a permutation
#       chance distribution and cluster-based permutation significance, computed with
#       leave-one-participant-out (LOPO) cross-validation. Also the session-resolved
#       and language-resolved variants (the multivariate transfer test).
#   <property>_decoding_generalization.csv
#       Cross-language generalisation (train Mini-Norwegian -> test Mini-English and
#       vice versa).
#   <train_property>_decoding_generalization_crossproperty.csv
#       Cross-property generalisation (train one property -> test another), written to
#       its own file by the separate crossprop stage.
#   <property>_decoding_temporal_generalization.csv
#       Temporal-generalisation matrix (train time t, test time t') for the pooled
#       decoder (King & Dehaene, 2014, TiCS, https://doi.org/10.1016/j.tics.2014.01.002).
#
# WHY THESE METHODS
# -----------------
# Decoding asks whether the *joint scalp pattern* separates grammatical from
# ungrammatical sentences at each moment -- the multivariate analogue of the
# univariate ERP contrast, sensitive to information distributed across sensors that
# region-averaged ERPs miss (Haxby et al., 2001, Science,
# https://doi.org/10.1126/science.1063736; Kriegeskorte, Mur & Bandettini, 2008, RSA
# foundations, https://doi.org/10.3389/neuro.06.004.2008 -- here we decode rather than
# build RDMs, but the multivariate-pattern logic is the same).
# A ridge-regularised linear discriminant
# (regularised LDA; the Fisher discriminant with a ridged pooled covariance, cf.
# MASS::lda) is the default classifier: it is the standard, well-calibrated choice for
# time-resolved EEG decoding and is fast enough for a per-sample x LOPO x permutation
# grid (Grootswagers et al., 2017, JoCN, https://doi.org/10.1162/jocn_a_01068). We
# hand-roll it (rather than call MASS::lda in the innermost loop) purely for speed and
# to add the ridge; MASS is still loaded as the reference implementation.
#
# GUARDING AGAINST DOUBLE-DIPPING AND OPTIMISTIC CV
# -------------------------------------------------
# * LEAVE-ONE-PARTICIPANT-OUT CV. Trials from the SAME participant are correlated;
#   splitting trials at random across folds leaks participant identity and inflates
#   accuracy. We hold out ALL of one participant's trials per fold, so every test score
#   generalises to an unseen participant (Varoquaux et al., 2017, NeuroImage,
#   https://doi.org/10.1016/j.neuroimage.2016.10.038; on the wide error bars that
#   cross-validation carries at these sample sizes, Varoquaux, 2018, NeuroImage,
#   https://doi.org/10.1016/j.neuroimage.2017.06.061). This is the analysis unit for all
#   decoders here.
# * NO PEEKING. Any standardisation / class balancing is fit on the TRAIN fold only and
#   applied to the held-out participant; nothing about the test participant informs the
#   model (Kriegeskorte et al., 2009, "circular analysis"; Varoquaux et al., 2017).
# * CLASS BALANCE. Grammatical and ungrammatical counts differ per participant and
#   decline by session. We balance classes by random undersampling WITHIN the training
#   set of each fold, and score with AUC, which is insensitive to the decision threshold
#   and to class prevalence, so neither the fit nor the metric can exploit a
#   class-prevalence shortcut (Grootswagers et al., 2017; Varoquaux et al., 2017).
# * CHANCE BY PERMUTATION. The null is built by shuffling the labels WITHIN participant
#   (preserving per-participant class counts) and re-running the whole LOPO decoder
#   (>= 1000 permutations; LES_DECODE_NPERM). Comparing observed accuracy to this
#   empirical null is more valid than the nominal 0.5 when folds/classes are unbalanced
#   (Combrisson & Jerbi, 2015; Varoquaux et al., 2017).
# * MULTIPLE COMPARISONS OVER TIME. Significance over the ~300 time points of the
#   default 4 ms decoding grid (600 at LES_DECODE_TIME_STEP_MS=2) uses cluster-based
#   permutation inference: form clusters of temporally contiguous above-threshold
#   samples, take the summed cluster statistic, and compare to the max-cluster null from
#   the label permutations (Maris & Oostenveld, 2007, J. Neurosci. Methods,
#   https://doi.org/10.1016/j.jneumeth.2007.03.024).
#
# THE ANALYSIS SPANS THE WHOLE EPOCH, INCLUDING THE BASELINE
# ----------------------------------------------------------
# Nothing here restricts the analysis to post-stimulus time: the decoder, the cluster
# test and the temporal-generalisation matrix all run over every retained sample of the
# -100..1098 ms epoch that step 08 wrote. Clusters can therefore form before stimulus
# onset, and one that did would be evidence of a baseline-period difference between the
# conditions rather than of an evoked effect, so a pre-stimulus cluster should be read
# as a warning rather than as a result. Step 08 baseline-corrects each trial by
# subtracting its own pre-stimulus mean per channel, which constrains those samples to
# average to zero within a trial and channel but does not equalise them across trials.
#
# DECLINING N BY SESSION / MISSING PROPERTY-SESSIONS
# --------------------------------------------------
# Attrition thins the later sessions and some participant x session cells lack a given
# property. Every routine (a) drops trials with incomplete patterns, (b) requires each
# LOPO fold's training set to contain >= 2 participants with BOTH classes, and (c) omits
# any (session/language/property) cell that cannot be balanced rather than emitting an
# optimistic score. An omitted cell is simply absent from the output CSV. The by-session
# skips are announced in the log, whereas the by-session-by-language skips are silent.
#
# USAGE
#   Rscript 09_run_decoding.R gender_agreement                 # one property, core analyses
#   Rscript 09_run_decoding.R gender_agreement timecourse      # a single analysis stage
#   Rscript 09_run_decoding.R                                   # all properties (+ cross-property)
# Analysis stages: timecourse | crosslang | crossprop | temporalgen | all (default).
# There is no separate session stage: the session-resolved and session-by-language
# time-courses are produced by `timecourse`, into the same CSV as the overall one.
# =============================================================================

suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "03_data_manifest.R"))
  source(here::here("paper_1_transfer", "scripts", "_config.R"))
  source(here::here("paper_1_transfer", "scripts", "08_extract_decoding_matrices.R"))  # les_decode_rds()
  # MASS is attached for reference rather than use: the LDA is hand-rolled below (see
  # the note at "We roll a tiny LDA"), so no MASS function is called in this file.
  # dplyr is attached after MASS so that dplyr::select stays ahead of MASS::select.
  library(MASS)
  library(dplyr)
})

# --- Reproducibility / tunables ----------------------------------------------
# A fixed seed makes the (random) undersampling and label permutations reproducible.
LES_DECODE_SEED   <- as.integer(Sys.getenv("LES_DECODE_SEED", unset = "20260702"))
# >= 1000 permutations for the chance/cluster null, so the minimum attainable cluster
# p (1/(nperm+1)) and the tail feeding the Benjamini-Hochberg FDR are stable near
# alpha (Maris & Oostenveld, 2007; Nichols & Holmes, 2002,
# https://doi.org/10.1002/hbm.1058). That is the standard. What a given artefact was
# produced under is carried in its own n_perm column, per row, which the manuscript
# reads, and it can differ between the confirmatory and exploratory strata while a
# rerun is in flight (see 09b_assemble_confirmatory_timecourse.R). A reduced count is
# usable only for the stages that do not run the confirmatory FDR (crosslang, crossprop,
# temporalgen); run_timecourse() enforces the admissibility guard in
# .les_fdr_confirmatory(), which stops below roughly m / alpha permutations.
LES_DECODE_NPERM  <- as.integer(Sys.getenv("LES_DECODE_NPERM", unset = "1000"))
# Permutations between within-block checkpoints. Block-level checkpointing alone is
# not enough on this cluster: the pooled "overall" block is ~44% of a property's run
# (4+ days at B = 1000), and a NODE_FAIL partway through it discards everything: one
# such failure cost a run 3 d 23 h of permutations. Saving the partially
# filled null every LES_DECODE_CKPT_EVERY permutations caps the loss at that many
# permutations instead of a whole block. The cost is one rds write per 50 permutations,
# negligible beside the permutation itself.
LES_DECODE_CKPT_EVERY <- as.integer(Sys.getenv("LES_DECODE_CKPT_EVERY", unset = "50"))
# Alpha for the cluster test. .les_cluster_perm() forms clusters at the 1 - alpha
# quantile of the permutation null, so the conventional 0.05 gives the usual 95th
# percentile. The same value is deliberately reused as the cluster-level decision
# criterion and, in .les_fdr_confirmatory(), as the FDR level, so one knob moves all
# three. The forming threshold governs how sensitive the test is to broad versus focal
# effects. What controls the false-positive rate is the max-cluster permutation null,
# not this value.
LES_DECODE_CLUSTER_ALPHA <- as.numeric(Sys.getenv("LES_DECODE_CLUSTER_ALPHA", unset = "0.05"))
# Ridge added to the pooled covariance for numerical stability with LES_DECODE_N_EEG
# (31) channels and thin folds (regularised LDA; standard for high-dimensional EEG
# decoding).
LES_DECODE_RIDGE  <- as.numeric(Sys.getenv("LES_DECODE_RIDGE", unset = "1e-3"))
# Temporal-generalisation coarsening: keep every `stride`-th retained sample on BOTH
# axes (the TGM is O(nT^2 x folds), so a stride keeps it tractable). 2 by default.
LES_DECODE_TGM_STRIDE <- as.integer(Sys.getenv("LES_DECODE_TGM_STRIDE", unset = "2"))

set.seed(LES_DECODE_SEED)

# =============================================================================
# Low-level classifier: regularised LDA on a [n x p] pattern matrix.
# -----------------------------------------------------------------------------
# We roll a tiny LDA rather than call MASS::lda inside the innermost loop for two
# reasons: (i) we need a numeric decision score for AUC (MASS::lda's posterior is fine
# but slower across thousands of fits); (ii) we add an explicit ridge to the pooled
# within-class covariance so the 31-channel fits stay invertible when a fold is thin. The
# projection is the Fisher linear discriminant; the score is the projection onto it.
# Returns NULL if the ridged pooled covariance is still singular, so the caller can
# skip that (degenerate) fold rather than emit a spurious score.
# =============================================================================
.les_lda_fit <- function(Xtr, ytr, ridge = LES_DECODE_RIDGE) {
  cls <- unique(as.character(ytr))
  stopifnot(all(c("Grammatical", "Ungrammatical") %in% cls))
  # Fix the sign convention explicitly: the discriminant points from Grammatical toward
  # Ungrammatical, so a HIGHER score means "more ungrammatical" and Ungrammatical is the
  # AUC positive class. This keeps above-chance decoding as AUC > 0.5 rather than < 0.5.
  G <- Xtr[ytr == "Grammatical",   , drop = FALSE]
  U <- Xtr[ytr == "Ungrammatical", , drop = FALSE]
  mG <- colMeans(G); mU <- colMeans(U)
  p  <- ncol(Xtr)
  # Pooled within-class covariance, ridged toward its diagonal for numerical stability
  # (regularised LDA: essential with this many sensors and thin folds).
  Sw <- (stats::cov(G) * (nrow(G) - 1) + stats::cov(U) * (nrow(U) - 1)) /
        (nrow(G) + nrow(U) - 2)
  Sw <- Sw + diag(ridge * mean(diag(Sw)) + 1e-8, p)
  w  <- tryCatch(solve(Sw, (mU - mG)), error = function(e) NULL)
  if (is.null(w) || any(!is.finite(w))) return(NULL)
  list(w = w)
}

.les_lda_score <- function(fit, Xte) as.numeric(Xte %*% fit$w)

# =============================================================================
# AUC (Mann-Whitney U form). Insensitive to the decision threshold and to class
# prevalence, so chance = 0.5 by construction regardless of the balance of the TEST fold.
# =============================================================================
.les_auc <- function(score, y_pos) {
  # y_pos: logical, TRUE for the positive class. Higher score should mean positive.
  n1 <- sum(y_pos); n0 <- sum(!y_pos)
  if (n1 == 0 || n0 == 0) return(NA_real_)
  r <- rank(score)
  (sum(r[y_pos]) - n1 * (n1 + 1) / 2) / (n1 * n0)
}

# =============================================================================
# Class-balanced training index: undersample the majority class WITHIN one fold's
# training set, separately for each participant, so that no participant carries a
# class-prevalence imbalance into the fit. Participants still contribute in proportion
# to their own trial counts; nothing here caps one participant's share of the training
# set relative to another's.
# Returns row indices into the supplied meta/label vectors.
# =============================================================================
.les_balance_train <- function(part, y) {
  keep <- integer(0)
  for (pp in unique(part)) {
    idx <- which(part == pp)
    yg  <- y[idx]
    n_per <- min(table(factor(yg, levels = c("Grammatical", "Ungrammatical"))))
    if (is.na(n_per) || n_per == 0) next          # participant lacks a class -> skip
    for (cl in c("Grammatical", "Ungrammatical")) {
      cand <- idx[yg == cl]
      keep <- c(keep, if (length(cand) > n_per) sample(cand, n_per) else cand)
    }
  }
  keep
}

# =============================================================================
# One LOPO decoding pass at a SINGLE time point.
# -----------------------------------------------------------------------------
# P: [trial x channel] pattern at this time; part: participant vector; y: labels
# (Grammatical/Ungrammatical). Trains on all-but-one participant (balanced) and scores
# the held-out participant with AUC; returns the mean AUC over folds (NA if no fold was
# scorable). If `perm_within_part` is TRUE the labels are first shuffled within each
# participant (the permutation null).
# =============================================================================
# Shuffle grammaticality labels WITHIN each participant (one consistent draw). The null
# for the cluster test is built by applying ONE such shuffle per permutation and holding
# it across ALL time points, so each permuted time-course preserves the temporal
# autocorrelation of the data under H0 and the max-cluster-mass null is calibrated
# (Maris & Oostenveld, 2007). Shuffling independently at each time point would flatten the
# null's temporal structure and make the cluster test anti-conservative.
.les_perm_labels <- function(part, y) {
  for (pp in unique(part)) { i <- which(part == pp); y[i] <- sample(y[i]) }
  y
}

.les_decode_timepoint <- function(P, part, y) {
  ok <- stats::complete.cases(P)
  P <- P[ok, , drop = FALSE]; part <- part[ok]; y <- y[ok]
  if (length(unique(part)) < 3) return(NA_real_)

  aucs <- c()
  for (held in unique(part)) {
    tr <- which(part != held); te <- which(part == held)
    # Train fold must have >= 2 participants carrying BOTH classes.
    tr_part <- part[tr]
    both <- names(which(tapply(y[tr], tr_part,
                               function(v) length(unique(v)) == 2)))
    if (length(both) < 2) next
    ytr <- y[tr]; yte <- y[te]
    if (length(unique(yte)) < 2) next            # test participant needs both classes
    bal <- .les_balance_train(tr_part, ytr)
    if (length(bal) < 4) next
    fit <- .les_lda_fit(P[tr[bal], , drop = FALSE], ytr[bal])
    if (is.null(fit)) next
    s <- .les_lda_score(fit, P[te, , drop = FALSE])
    # positive class = Ungrammatical (the "violation" the decoder detects)
    auc <- .les_auc(s, yte == "Ungrammatical")
    if (!is.na(auc)) aucs <- c(aucs, auc)
  }
  if (length(aucs) == 0) NA_real_ else mean(aucs)
}

# =============================================================================
# Cluster-based permutation inference over the time axis (Maris & Oostenveld, 2007).
# -----------------------------------------------------------------------------
# obs   : observed AUC per time point (length nT)
# null  : [nPerm x nT] permutation AUCs (labels shuffled within participant)
# Returns per-time-point p (pointwise, vs the null) and the surviving-cluster mask with
# each cluster's mass and cluster-level p (mass vs the max-cluster null distribution).
# The cluster-forming threshold is the (1 - alpha) quantile of the pooled null AUC.
# =============================================================================
.les_cluster_perm <- function(obs, null, alpha = LES_DECODE_CLUSTER_ALPHA) {
  nT <- length(obs)
  thr <- stats::quantile(as.numeric(null), probs = 1 - alpha, na.rm = TRUE)

  # Pointwise p per time point, as (b + 1) / (m + 1) rather than the intuitive b / m.
  # The observed statistic is itself one draw from the null, so the exact permutation
  # p-value carries the +1 on both terms (Phipson & Smyth, 2010,
  # https://doi.org/10.2202/1544-6115.1585, Sections 4-5). Two consequences matter here.
  # A permutation p can then never be exactly 0, which b / m allows and which is
  # inferentially meaningless: no finite subset of permutations can establish that no
  # permutation is as extreme. And b / m understates every p by about 1 / m, which is
  # negligible for a single test but not under the FDR correction applied across the
  # confirmatory clusters below, where a systematically understated p propagates.
  # The floor is therefore 1 / (m + 1), which the manuscript reports as the resolution
  # limit on near-threshold cluster p-values.
  p_point <- vapply(seq_len(nT), function(t) {
    (1 + sum(null[, t] >= obs[t], na.rm = TRUE)) / (nrow(null) + 1)
  }, numeric(1))

  # Cluster statistic = summed (AUC - threshold) over contiguous supra-threshold runs.
  cluster_mass <- function(stat) {
    above <- !is.na(stat) & stat > thr
    if (!any(above)) return(list(mass = numeric(0), runs = list()))
    r <- rle(above)
    ends <- cumsum(r$lengths); starts <- ends - r$lengths + 1
    sel <- which(r$values)
    masses <- numeric(length(sel)); runs <- vector("list", length(sel))
    for (k in seq_along(sel)) {
      rng <- starts[sel[k]]:ends[sel[k]]
      masses[k] <- sum(stat[rng] - thr); runs[[k]] <- rng
    }
    list(mass = masses, runs = runs)
  }

  obs_cl <- cluster_mass(obs)
  # Null distribution of the MAXIMUM cluster mass across permutations.
  max_null <- vapply(seq_len(nrow(null)), function(i) {
    m <- cluster_mass(null[i, ])$mass
    if (length(m) == 0) 0 else max(m)
  }, numeric(1))

  sig_mask <- rep(FALSE, nT); clust_p <- rep(NA_real_, nT); clust_id <- rep(NA_integer_, nT)
  if (length(obs_cl$mass) > 0) {
    for (k in seq_along(obs_cl$mass)) {
      # Same (b + 1) / (m + 1) exact form as the pointwise p above.
      pk <- (1 + sum(max_null >= obs_cl$mass[k])) / (length(max_null) + 1)
      if (pk < alpha) sig_mask[obs_cl$runs[[k]]] <- TRUE
      clust_p[obs_cl$runs[[k]]]  <- pk
      clust_id[obs_cl$runs[[k]]] <- k
    }
  }
  list(threshold = as.numeric(thr), p_point = p_point,
       sig = sig_mask, cluster_p = clust_p, cluster_id = clust_id)
}

# --- Second-layer FDR: the CONFIRMATORY family of cluster tests ---------------
# .les_cluster_perm()'s cluster_p is already family-wise-error-controlled ACROSS TIME
# within one cell, via the max-cluster permutation null (Maris & Oostenveld, 2007).
# That is the correct control for the time axis and is not in question here. The
# question is what family a SECOND layer should span.
#
# This previously spanned every cell decoded for one property: the overall
# time-course plus each per-session and each per-session-by-language cell. That family
# is not well defined. Those cells are nested, overlapping re-analyses of the SAME
# trials (the overall time-course is a superset of each session cell, itself a superset
# of each session-by-language cell), so:
#   * m is arbitrary: it could be the 7-13 cells a property yields or the 71-155
#     distinct clusters they contain. The q-values move substantially with that choice,
#     and nothing in the design fixes it;
#   * the positive-dependence (PRDS) condition that licenses plain BH under
#     dependence (Benjamini & Yekutieli, 2001, https://doi.org/10.1214/aos/1013699998)
#     was asserted for this nesting, never established. Correcting across nested
#     subsets of one dataset does not yield an interpretable false-discovery rate.
# The hierarchical/tree-FDR procedures sometimes proposed for such cases do not rescue
# it either: they assume independent p-values across DISJOINT subfamilies, which is a
# strictly stronger assumption than the one that fails here.
#
# We therefore fix the FAMILY rather than the correction. The CONFIRMATORY family is
# the overall (all-sessions-pooled) time-course, one per property. Across properties
# these rest on disjoint trial sets, so the family is well defined and its dependence
# structure benign; within a property the time axis is already FWER-controlled. BH is
# applied across the distinct clusters of the confirmatory analyses (cluster_p is
# repeated across every time-point row of a cluster, and cluster_id restarts in every
# cell, so clusters are keyed by analysis + level + cluster_id).
#
# The per-session and per-session-by-language decompositions are retained and reported,
# but as EXPLORATORY breakdowns of the same trials: each keeps its own cluster-level p
# (FWER-controlled over time), and none enters the confirmatory family. They are
# labelled in the `inference` column so the manuscript cannot silently promote them.
#
# ADMISSIBILITY. BH can reject at rank 1 only if the smallest attainable p-value is
# below alpha/m, i.e. 1/(B+1) < alpha/m. Keeping the confirmatory family small keeps
# this satisfiable: it is why the permutation count and the family size must be chosen
# together. The guard below fails loudly rather than silently returning a family in
# which no single cluster could ever be declared significant.
LES_DECODE_CONFIRMATORY <- "overall"

.les_fdr_confirmatory <- function(res) {
  res$cluster_p_fdr   <- NA_real_
  res$significant_fdr <- FALSE
  res$inference <- ifelse(res$analysis == LES_DECODE_CONFIRMATORY,
                          "confirmatory", "exploratory")
  is_conf <- !is.na(res$cluster_id) & res$analysis == LES_DECODE_CONFIRMATORY
  if (!any(is_conf)) return(res)

  clusters <- unique(res[is_conf, c("analysis", "level", "cluster_id", "cluster_p")])
  m <- nrow(clusters)
  # The floor that matters is the one the CONFIRMATORY rows were computed at. Taking the
  # maximum over every row was equivalent while run_timecourse() wrote all of a property's
  # blocks at one B, but an assembled frame can mix the strata (see
  # 09b_assemble_confirmatory_timecourse.R), and a larger exploratory B would then mask a
  # confirmatory family in which no cluster could be declared significant at rank 1.
  nperm <- suppressWarnings(max(res$n_perm[is_conf], na.rm = TRUE))
  if (is.finite(nperm) && 1 / (nperm + 1) >= LES_DECODE_CLUSTER_ALPHA / m)
    stop(sprintf(paste0("[decode] FDR is inadmissible: p-floor 1/(B+1) = %.5f exceeds ",
                        "alpha/m = %.5f (B = %d permutations, m = %d confirmatory ",
                        "clusters). No cluster could be declared significant at rank 1. ",
                        "Raise LES_DECODE_NPERM to at least %d."),
                 1 / (nperm + 1), LES_DECODE_CLUSTER_ALPHA / m, nperm, m,
                 ceiling(m / LES_DECODE_CLUSTER_ALPHA)))

  clusters$cluster_p_fdr <- stats::p.adjust(clusters$cluster_p, method = "BH")
  key <- function(d) paste(d$analysis, d$level, d$cluster_id, sep = "|")
  lut <- stats::setNames(clusters$cluster_p_fdr, key(clusters))
  res$cluster_p_fdr[is_conf]   <- lut[key(res[is_conf, ])]
  res$significant_fdr[is_conf] <- res$cluster_p_fdr[is_conf] < LES_DECODE_CLUSTER_ALPHA
  res
}

# =============================================================================
# Full time-course decoder with permutation + cluster inference.
# -----------------------------------------------------------------------------
# X: [trial x channel x time]; meta: aligned metadata. Returns a tidy data.frame with
# one row per time point (observed AUC, null mean, pointwise p, cluster p, sig flag).
# `tag` holds constant descriptor columns (e.g. analysis = "overall").
# =============================================================================
.les_decode_timecourse <- function(X, meta, nperm = LES_DECODE_NPERM, tag = list(),
                                   part_file = NULL, fp = NULL) {
  times <- as.numeric(dimnames(X)[[3]]); nT <- length(times)
  part  <- meta$participant_lab_ID; y <- meta$grammaticality

  # Guard: need both classes and >= 3 participants overall.
  if (length(unique(y)) < 2 || length(unique(part)) < 3 || nT == 0) {
    return(data.frame())
  }

  obs <- vapply(seq_len(nT), function(t)
    .les_decode_timepoint(X[, , t], part, y), numeric(1))

  # Resume a partially completed permutation null if one was left by an interrupted
  # run of the SAME analysis (fingerprint and dimensions must both match, or the
  # partial file is ignored and the block recomputed from scratch). The RNG state is
  # restored with the partial, so resuming reproduces the uninterrupted stream.
  null  <- matrix(NA_real_, nrow = nperm, ncol = nT)
  start <- 1L
  if (!is.null(part_file) && file.exists(part_file)) {
    pk <- try(readRDS(part_file), silent = TRUE)
    ok <- !inherits(pk, "try-error") && identical(pk$fingerprint, fp) &&
      is.matrix(pk$null) &&
      identical(dim(pk$null), c(as.integer(nperm), as.integer(nT))) &&
      is.numeric(pk$done) && pk$done >= 1L && pk$done <= nperm
    if (ok) {
      null  <- pk$null
      start <- as.integer(pk$done) + 1L
      assign(".Random.seed", pk$rng, envir = .GlobalEnv)
      message(sprintf("    [perm] resumed from partial checkpoint at %d/%d",
                      pk$done, nperm))
    } else {
      message("    [perm] partial checkpoint ignored (does not match this analysis)")
    }
  }

  if (start <= nperm) {
    for (b in start:nperm) {
      y_perm <- .les_perm_labels(part, y) # ONE within-participant shuffle, held across time
      null[b, ] <- vapply(seq_len(nT), function(t)
        .les_decode_timepoint(X[, , t], part, y_perm), numeric(1))
      if (b %% 25 == 0) message(sprintf("    [perm] %d/%d", b, nperm))
      # Write the partial atomically: a NODE_FAIL during the write itself must not
      # leave a truncated file that the next run would rightly refuse but that also
      # destroyed the previous good one.
      if (!is.null(part_file) && b %% LES_DECODE_CKPT_EVERY == 0 && b < nperm) {
        tmp <- paste0(part_file, ".tmp")
        saveRDS(list(null = null, done = b,
                     rng = get(".Random.seed", envir = .GlobalEnv),
                     fingerprint = fp), tmp)
        file.rename(tmp, part_file)
      }
    }
  }

  cl <- .les_cluster_perm(obs, null)
  out <- data.frame(
    time_ms       = times,
    auc           = obs,
    null_mean     = colMeans(null, na.rm = TRUE),
    # Descriptive only: the 97.5th percentile of this time point's own permutation null,
    # kept beside null_mean to record the spread of the null. No decision in this script
    # uses it, and it is NOT the cluster test's threshold, which is the 1 - alpha
    # quantile of the POOLED null and is reported below as cluster_threshold.
    null_q975     = apply(null, 2, stats::quantile, probs = 0.975, na.rm = TRUE),
    p_pointwise   = cl$p_point,
    cluster_id    = cl$cluster_id,
    cluster_p     = cl$cluster_p,
    significant   = cl$sig,
    cluster_threshold = cl$threshold,
    n_perm        = nperm,
    n_trials      = nrow(meta),                 # trials entering this cell (post-completeness)
    n_participants = length(unique(part)),
    stringsAsFactors = FALSE
  )
  for (nm in names(tag)) out[[nm]] <- tag[[nm]]
  out
}

# =============================================================================
# Cross-condition generalisation at a single time point.
# -----------------------------------------------------------------------------
# NOTE ON PARTICIPANT DISJOINTNESS. For the cross-LANGUAGE case the train and test
# sets are drawn from disjoint participant groups (Mini-English vs Mini-Norwegian), so
# no cross-validation is needed and the result is participant-independent by
# construction. For the cross-PROPERTY case this is NOT so: the same participants
# contribute trials to every property, so cross-property train/test sets share
# participants and the analysis is not participant-independent. Cross-property
# generalisation is therefore reported descriptively only (see the manuscript), and a
# positive result could in principle reflect participant-idiosyncratic topography
# shared across properties within a person rather than a property-general code.
# Class-balances the training set, scores the whole test set with AUC.
# =============================================================================
.les_generalize_timepoint <- function(Ptr, ytr, part_tr, Pte, yte) {
  ok_tr <- stats::complete.cases(Ptr); ok_te <- stats::complete.cases(Pte)
  Ptr <- Ptr[ok_tr, , drop = FALSE]; ytr <- ytr[ok_tr]; part_tr <- part_tr[ok_tr]
  Pte <- Pte[ok_te, , drop = FALSE]; yte <- yte[ok_te]
  if (length(unique(ytr)) < 2 || length(unique(yte)) < 2) return(NA_real_)
  bal <- .les_balance_train(part_tr, ytr)
  if (length(bal) < 4) return(NA_real_)
  fit <- .les_lda_fit(Ptr[bal, , drop = FALSE], ytr[bal])
  if (is.null(fit)) return(NA_real_)
  .les_auc(.les_lda_score(fit, Pte), yte == "Ungrammatical")
}

# =============================================================================
# Temporal generalisation matrix (King & Dehaene, 2014): train at time t, test at t'.
# -----------------------------------------------------------------------------
# Pooled decoder (all trials), LOPO across participants; the [t x t'] AUC is averaged
# over folds. Time is coarsened (`stride`) to keep the t x t x fold grid tractable.
# =============================================================================
.les_temporal_generalization <- function(X, meta, stride = 2L) {
  times <- as.numeric(dimnames(X)[[3]]); nT <- length(times)
  keep_t <- seq(1L, nT, by = stride)
  tt <- times[keep_t]; m <- length(keep_t)
  part <- meta$participant_lab_ID; y <- meta$grammaticality
  parts <- unique(part)
  if (length(parts) < 3) return(data.frame())

  # Accumulate AUC[t_train, t_test] over LOPO folds.
  acc <- array(0, dim = c(m, m)); cnt <- array(0, dim = c(m, m))
  for (held in parts) {
    tr <- which(part != held); te <- which(part == held)
    if (length(unique(y[te])) < 2) next
    bal <- .les_balance_train(part[tr], y[tr])
    if (length(bal) < 4) next
    tr_idx <- tr[bal]
    # Fit one LDA per training time; then score every test time with each.
    fits <- vector("list", m)
    for (a in seq_len(m)) {
      Ptr <- X[tr_idx, , keep_t[a]]
      okr <- stats::complete.cases(Ptr)
      fits[[a]] <- if (sum(okr) >= 4 && length(unique(y[tr_idx][okr])) == 2)
        .les_lda_fit(Ptr[okr, , drop = FALSE], y[tr_idx][okr]) else NULL
    }
    for (b in seq_len(m)) {
      Pte <- X[te, , keep_t[b]]; oke <- stats::complete.cases(Pte)
      if (sum(oke) < 2 || length(unique(y[te][oke])) < 2) next
      yb <- y[te][oke] == "Ungrammatical"
      for (a in seq_len(m)) {
        if (is.null(fits[[a]])) next
        auc <- .les_auc(.les_lda_score(fits[[a]], Pte[oke, , drop = FALSE]), yb)
        if (!is.na(auc)) { acc[a, b] <- acc[a, b] + auc; cnt[a, b] <- cnt[a, b] + 1 }
      }
    }
  }
  mat <- ifelse(cnt > 0, acc / cnt, NA_real_)
  data.frame(
    train_time_ms = rep(tt, times = m),
    test_time_ms  = rep(tt, each = m),
    auc           = as.numeric(mat),
    n_folds       = as.numeric(cnt),
    stringsAsFactors = FALSE
  )
}

# =============================================================================
# Loaders and per-property drivers
# =============================================================================
.les_load_decoding <- function(property) {
  path <- les_decode_rds(property)
  if (!file.exists(path)) stop("Missing decoding tensor: ", path,
                               " -- run 08_extract_decoding_matrices.R first.")
  readRDS(path)
}

# Drop trials with any incomplete channel-time cell (guards the CV/AUC math). We keep a
# trial only if every channel-time is observed, so a fold never silently loses samples.
.les_complete_trials <- function(built) {
  X <- built$X
  full <- apply(X, 1, function(m) all(!is.na(m)))
  # x_digest must be carried through: run_timecourse() fingerprints the object this
  # function RETURNS, so omitting it here silently disabled the staleness guard on
  # every permutation checkpoint (the field was stored by 08 but never read).
  list(X = X[full, , , drop = FALSE], meta = built$meta[full, , drop = FALSE],
       channels = built$channels, times = built$times, property = built$property,
       x_digest = built$x_digest)
}

# --- (0) overall + (a) session-resolved / language-resolved time-courses ----------
# --- Per-block checkpointing -------------------------------------------------
# A time-course block costs hours and the whole stage used to write nothing until every
# block had finished, so an interruption threw away the lot: one node drain partway
# through a run discarded 11 days and 22 hours of work, with 11 of 13 blocks complete and
# nothing on disk.
#
# WHY THE RNG STATE IS CACHED TOO, AND NOT JUST THE RESULT
# set.seed(LES_DECODE_SEED) is called once when this file loads, and every block draws from
# that single stream (the undersampler and the label permuter both call sample()). The state
# each block starts from therefore depends on all the blocks before it. Restoring cached
# results alone would leave the remaining blocks drawing from a different point in the
# stream, so a resumed run would not equal an uninterrupted one. Saving .Random.seed with
# each block and restoring it on resume makes the two bit-identical, which is the only
# version worth having: an artefact must not depend on how often the scheduler killed the
# job.
#
# STALENESS: a checkpoint is keyed to a fingerprint of the tensor it was computed from and
# of the tunables that change the numbers. A cache whose fingerprint does not match is
# ignored and recomputed, so re-extracting the tensor or changing B cannot silently produce
# a mixture of old and new results. To force a clean run, delete
# data_derived/_tc_ckpt_<property>_*.rds.
.les_tc_fingerprint <- function(d) {
  # length(times) already moves when LES_DECODE_TIME_STEP_MS changes, since the step
  # determines how many bins the epoch is divided into, so the step needs no separate
  # term (and is a property of the stored tensor rather than a variable in this script).
  # The counts below do not distinguish two tensors built from different amplitudes,
  # so a corrected export that leaves the trial/participant/time counts unchanged
  # would otherwise let a completed block be resumed from the previous values. 08
  # stores a digest of X for exactly this; it is appended only when present, so
  # tensors written before that field existed keep the fingerprint they already have
  # and their in-flight checkpoints stay valid.
  paste0("n", nrow(d$meta),
         "_p", length(unique(d$meta$participant_lab_ID)),
         "_t", length(d$times),
         "_B", LES_DECODE_NPERM,
         "_s", LES_DECODE_SEED,
         if (!is.null(d$x_digest)) paste0("_x", substr(d$x_digest, 1, 12)) else {
           warning("tensor carries no x_digest: checkpoints for this property are keyed ",
                   "on trial/participant/time COUNTS only, so a rebuilt tensor with the ",
                   "same shape would be resumed from stale permutations. Re-extract with ",
                   "the current 08_extract_decoding_matrices.R to restore the guard.",
                   call. = FALSE)
           ""
         })
}

# Path of the WITHIN-block partial for one analysis, so the permutation loop and the
# block wrapper agree on where an interrupted null is parked.
.les_tc_partfile <- function(property, block)
  paper1_derived(paste0("_tc_part_", property, "_", block, ".rds"))

.les_tc_block <- function(property, block, fp, compute) {
  f <- paper1_derived(paste0("_tc_ckpt_", property, "_", block, ".rds"))
  if (file.exists(f)) {
    ck <- try(readRDS(f), silent = TRUE)
    if (!inherits(ck, "try-error") && identical(ck$fingerprint, fp)) {
      # Restore the stream exactly where the original computation left it.
      assign(".Random.seed", ck$rng, envir = .GlobalEnv)
      message("[decode] ", property, " :: ", block, " -- resumed from checkpoint")
      return(ck$result)
    }
    message("[decode] ", property, " :: ", block,
            " -- checkpoint ignored (fingerprint changed); recomputing")
  }
  res <- compute()
  saveRDS(list(result = res, rng = get(".Random.seed", envir = .GlobalEnv),
               fingerprint = fp), f)
  # The block is complete and its own checkpoint written, so the within-block partial
  # is now dead weight and must not be left to confuse a later run.
  pf <- .les_tc_partfile(property, block)
  if (file.exists(pf)) unlink(pf)
  res
}

run_timecourse <- function(property) {
  d <- .les_complete_trials(.les_load_decoding(property))
  fp <- .les_tc_fingerprint(d)
  out <- list()

  # Overall time-course.
  message("[decode] ", property, " :: overall time-course")
  out[["overall"]] <- .les_tc_block(property, "overall", fp, function()
    .les_decode_timecourse(
      d$X, d$meta, tag = list(property = property, analysis = "overall",
                              level = "all", session = NA, mini_language = NA),
      part_file = .les_tc_partfile(property, "overall"), fp = fp))

  # (a) Session-resolved: decode within each session separately (attrition permitting)
  #     to test whether decoding grows across Sessions 2, 3, 4 and 6, so that the
  #     accuracy trajectory serves as a multivariate index of learning.
  #     The floor of 20 trials is a pragmatic minimum rather than a derived one. It is
  #     set above what the fold guards below strictly need (>= 3 participants, and a
  #     balanced training set of >= 4 rows from >= 2 participants carrying both classes),
  #     so that a cell scraping past those guards on a handful of trials is dropped
  #     rather than reported as a near-unestimable AUC.
  for (s in LES_ERP_SESSIONS) {
    sel <- d$meta$session == as.character(s)
    if (sum(sel) < 20 || length(unique(d$meta$participant_lab_ID[sel])) < 3) {
      message("[decode] ", property, " :: session ", s, " -- too few trials/participants, skipped")
      next
    }
    message("[decode] ", property, " :: session ", s, " time-course")
    tc <- .les_tc_block(property, paste0("session_", s), fp, function()
      .les_decode_timecourse(
        d$X[sel, , , drop = FALSE], d$meta[sel, , drop = FALSE],
        tag = list(property = property, analysis = "by_session",
                   level = paste0("session_", s), session = s, mini_language = NA)))
    out[[paste0("session_", s)]] <- tc
  }

  # (a', transfer) Session x language: decode within each session x language cell, so
  #     that the language contrast in the session slope tests whether the growth differs
  #     by language. That contrast is the multivariate transfer test. The same 20-trial
  #     and 3-participant floors apply, but a cell that fails them is dropped silently
  #     here, because a property is not presented before its own training session and so
  #     several of these cells are empty by design rather than by attrition.
  for (s in LES_ERP_SESSIONS) for (lg in c("Mini-English", "Mini-Norwegian")) {
    sel <- d$meta$session == as.character(s) & d$meta$mini_language == lg
    if (sum(sel) < 20 || length(unique(d$meta$participant_lab_ID[sel])) < 3) next
    message("[decode] ", property, " :: session ", s, " / ", lg)
    blk <- paste0("session_", s, "_", gsub("[^A-Za-z0-9]", "", lg))
    tc <- .les_tc_block(property, blk, fp, function()
      .les_decode_timecourse(
        d$X[sel, , , drop = FALSE], d$meta[sel, , drop = FALSE],
        tag = list(property = property, analysis = "by_session_language",
                   level = paste0("session_", s, "_", lg), session = s, mini_language = lg)))
    out[[paste0("session_", s, "_", lg)]] <- tc
  }

  res <- dplyr::bind_rows(out)
  res <- .les_fdr_confirmatory(res)   # cluster_p_fdr / significant_fdr / inference (see above)
  path <- paper1_results(paste0(property, "_decoding_timecourse.csv"))
  les_assert_readonly_data(path); utils::write.csv(res, path, row.names = FALSE)
  message("[decode] wrote ", basename(path), " (rows=", nrow(res), ")")
  invisible(path)
}

# --- (b) cross-language generalisation ---------------------------------------
# Train on one language, test on the other, per time point. Because the train and test
# populations are disjoint, generalisation above chance means the grammaticality code is
# SHARED across the two artificial languages -- a strong, double-dipping-proof transfer
# signature. Item codes are language-namespaced upstream, so no item leaks between sets.
run_crosslang <- function(property) {
  d <- .les_complete_trials(.les_load_decoding(property))
  times <- d$times; nT <- length(times)
  rows <- list()
  pairs <- list(c("Mini-Norwegian", "Mini-English"), c("Mini-English", "Mini-Norwegian"))
  for (pr in pairs) {
    tr_lg <- pr[1]; te_lg <- pr[2]
    itr <- which(d$meta$mini_language == tr_lg); ite <- which(d$meta$mini_language == te_lg)
    if (length(unique(d$meta$participant_lab_ID[itr])) < 2 ||
        length(unique(d$meta$participant_lab_ID[ite])) < 2) {
      message("[decode] ", property, " :: crosslang ", tr_lg, "->", te_lg, " skipped (too few)")
      next
    }
    message("[decode] ", property, " :: crosslang train=", tr_lg, " test=", te_lg)
    auc <- vapply(seq_len(nT), function(t) {
      .les_generalize_timepoint(
        d$X[itr, , t], d$meta$grammaticality[itr], d$meta$participant_lab_ID[itr],
        d$X[ite, , t], d$meta$grammaticality[ite])
    }, numeric(1))
    rows[[paste(tr_lg, te_lg)]] <- data.frame(
      property = property, generalization = "cross_language",
      train_set = tr_lg, test_set = te_lg, time_ms = times, auc = auc,
      stringsAsFactors = FALSE)
  }
  res <- dplyr::bind_rows(rows)
  path <- paper1_results(paste0(property, "_decoding_generalization.csv"))
  les_assert_readonly_data(path); utils::write.csv(res, path, row.names = FALSE)
  message("[decode] wrote ", basename(path), " (rows=", nrow(res), ")")
  invisible(path)
}

# --- (c) cross-property generalisation ---------------------------------------
# Train the grammaticality decoder on property A, test on property B (all pairs). A
# shared cross-property code would indicate a domain-general grammaticality/violation
# response rather than a property-specific one. Needs ALL three tensors, so this runs
# once (not a per-property array task) and writes one
# <train_property>_decoding_generalization_crossproperty.csv per train property.
run_crossprop <- function() {
  props <- names(LES_P1_PROPERTIES)
  built <- setNames(lapply(props, function(p) .les_complete_trials(.les_load_decoding(p))), props)
  # Common time axis (intersection) so train/test patterns align sample-for-sample.
  common <- Reduce(intersect, lapply(built, function(b) b$times))
  if (length(common) == 0) stop("No common time axis across properties for cross-property.")
  rows <- list()
  for (a in props) for (b in props) {
    if (a == b) next
    ba <- built[[a]]; bb <- built[[b]]
    # Channels are matched POSITIONALLY in the slices below, unlike time which is
    # matched by value. The two tensors are built independently: order comes from
    # sort(unique(electrode)) (collation-dependent) and membership from a
    # per-property session intersection, and now that tensors are cached one can be
    # far older than the other. A mismatch would silently decode channel i of A
    # against channel i of B.
    if (!identical(ba$channels, bb$channels))
      stop("cross-property decoding needs identical channel axes, but ", a, " and ", b,
           " differ; re-extract both with LES_DECODE_FORCE_EXTRACT=1.")
    ia <- match(common, ba$times); ib <- match(common, bb$times)
    message("[decode] crossprop train=", a, " test=", b)
    auc <- vapply(seq_along(common), function(k) {
      .les_generalize_timepoint(
        ba$X[, , ia[k]], ba$meta$grammaticality, ba$meta$participant_lab_ID,
        bb$X[, , ib[k]], bb$meta$grammaticality)
    }, numeric(1))
    rows[[paste(a, b)]] <- data.frame(
      property = a, generalization = "cross_property",
      train_set = a, test_set = b, time_ms = common, auc = auc,
      stringsAsFactors = FALSE)
  }
  res <- dplyr::bind_rows(rows)
  # Write one cross-property generalization CSV per train property. Kept in a separate
  # file from the cross-language generalization (written by run_crosslang) so the two
  # transfer analyses never overwrite each other and a per-property array task and this
  # multi-tensor task can run independently.
  for (a in props) {
    sub <- res[res$train_set == a, , drop = FALSE]
    if (nrow(sub) == 0) next
    path <- paper1_results(paste0(a, "_decoding_generalization_crossproperty.csv"))
    les_assert_readonly_data(path)
    utils::write.csv(sub, path, row.names = FALSE)
  }
  message("[decode] wrote cross-property generalization CSVs")
  invisible(TRUE)
}

# --- (d) temporal generalisation ---------------------------------------------
run_temporalgen <- function(property) {
  d <- .les_complete_trials(.les_load_decoding(property))
  message("[decode] ", property, " :: temporal generalisation")
  res <- .les_temporal_generalization(d$X, d$meta, stride = LES_DECODE_TGM_STRIDE)
  res$property <- property
  path <- paper1_results(paste0(property, "_decoding_temporal_generalization.csv"))
  les_assert_readonly_data(path); utils::write.csv(res, path, row.names = FALSE)
  message("[decode] wrote ", basename(path), " (rows=", nrow(res), ")")
  invisible(path)
}

# =============================================================================
# Entry point
# =============================================================================
.run <- function() {
  args  <- commandArgs(trailingOnly = TRUE)
  stage <- if (length(args) >= 2) args[[2]] else "all"

  if (stage == "crossprop") {                 # needs all three tensors; property-free
    run_crossprop(); message("[decode] done."); return(invisible())
  }

  if (length(args) >= 1) {
    property <- args[[1]]
    stopifnot(property %in% names(LES_P1_PROPERTIES))
    if (stage %in% c("timecourse", "all"))   run_timecourse(property)
    if (stage %in% c("crosslang",  "all"))   run_crosslang(property)
    if (stage %in% c("temporalgen","all"))   run_temporalgen(property)
    # cross-property is intentionally NOT part of a single-property "all": it is a
    # multi-tensor job; submit it as its own array element (stage = crossprop).
  } else {
    for (property in names(LES_P1_PROPERTIES)) {
      run_timecourse(property); run_crosslang(property); run_temporalgen(property)
    }
    run_crossprop()
  }
  message("[decode] done.")
}

if (sys.nframe() == 0L) .run()
