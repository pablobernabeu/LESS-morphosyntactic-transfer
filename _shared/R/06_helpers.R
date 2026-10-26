# =============================================================================
# 06_helpers.R  --  Small helpers shared by the two paper pipelines
# =============================================================================
#
# WHAT THIS PROVIDES
#   les_zscore()             standardise a numeric vector, with the treatment of an
#                            all-NA input chosen at the call site
#   les_participant_folds()  participant-grouped fold ids for cross-validation
#
# The paper scripts source this file with source(here::here("_shared", "R", "06_helpers.R"))
# after _config.R has set the project root. les_participant_folds() takes its default
# seed from LES_SEED, which 01_bayesian_settings.R defines, so that module has to be
# sourced first wherever the default is relied on. Only Paper 2's scripts source this file
# at present (02, 04, 05, 08 and 09c).
# =============================================================================

# -----------------------------------------------------------------------------
# les_zscore()  --  z-score a numeric vector
# -----------------------------------------------------------------------------
# Returns as.numeric(scale(x)). A vector whose non-missing values have zero or undefined
# SD (constant, or fewer than two of them) returns zeros at those values, so a predictor
# without variance enters a model as a constant column and never as NaN. A missing value
# stays NA in every case except one: an all-NA vector, which the call site decides about.
# `all_na = "na"` (the default) keeps it NA, so a missing measure stays missing, and
# `all_na = "zero"` returns zeros, which is what Paper 2's scripts, the only callers, do
# with such a column (each then stops on a predictor without variance). The choice is
# made at the call site so that it is visible there.
# Paper 1 does not call this function: its extraction scripts 01 and 02 each carry a
# private .les_scale() with the same rules as les_zscore(all_na = "na"), so a change here
# reaches Paper 1 only once those copies are replaced (ISSUES.md G02-03).
# `x` is a numeric vector and the result a numeric vector of the same length. Uses no
# random numbers.
les_zscore <- function(x, all_na = c("na", "zero")) {
  all_na <- match.arg(all_na)
  if (all(is.na(x))) return(if (all_na == "na") as.numeric(x) else rep(0, length(x)))
  s <- stats::sd(x, na.rm = TRUE)
  if (is.na(s) || s == 0) {
    # Until October 2026 this branch returned zeros at the NA positions too, imputing the
    # mean for a missing value. No input the pipelines standardise reached it with an NA
    # (every standardised measure varies), so no derived value changed with the fix.
    out <- rep(0, length(x))
    out[is.na(x)] <- NA_real_
    return(out)
  }
  as.numeric(scale(x))
}

# -----------------------------------------------------------------------------
# Build a participant-level fold id aligned to the reference model's data rows.
# -----------------------------------------------------------------------------
# Every row of a given participant_lab_ID gets the SAME fold, so no participant's
# trials straddle the train/test boundary (grouped K-fold; Roberts et al. 2017).
# Participants (not rows) are shuffled into K balanced groups with a fixed seed.
# `dat` is a data frame with a participant_lab_ID column. The function stops when that
# column is missing or there are fewer than two participants. `k` is the requested fold
# count and is capped at the number of participants, so callers use the k returned. `seed`
# defaults to LES_SEED. The result is a list of `folds` (an integer fold id for each row of
# `dat`, in row order), `k`, `n_participants` and `fold_sizes` (the number of participants
# in each fold).
#
# The partition depends on the order in which participants first appear in `dat`,
# because the shuffle permutes unique(participant_lab_ID) as it comes: the same rows in a
# different order give a different, equally valid partition. Callers pass a fitted
# model's own data (fit$data), whose row order is fixed by the fit, so the folds are
# reproducible. Sorting the ids first would remove the dependence but change the folds of
# the reported projpred and K-fold results.
#
# set.seed(seed) replaces the caller's global RNG state and does not restore it. The
# reported projpred and grouped K-fold runs were made with this behaviour, so any random
# draw a caller makes after it without a seed of its own depends on it. The two callers
# now seed their own draws (08_projpred_selection.R passes seed = LES_SEED to
# run_cvfun() and cv_varsel(); 09c_compare_aperiodic_grouped.R sets LES_SEED before
# kfold()), but restoring the state here would still change any unseeded draw between
# the two, so the behaviour is kept.
les_participant_folds <- function(dat, k, seed = LES_SEED) {
  if (!"participant_lab_ID" %in% names(dat)) {
    stop("[folds] the data have no participant_lab_ID column.")
  }
  ids <- as.character(dat$participant_lab_ID)
  uid <- unique(ids)
  n_p <- length(uid)
  if (n_p < 2L) stop("[folds] need >= 2 participants for grouped CV; found ", n_p)
  k <- min(k, n_p)                       # never more folds than participants
  set.seed(seed)
  # Round-robin assignment over a shuffled participant list -> near-equal fold sizes:
  # shuffle the participants, then deal them out 1..k, 1..k, ... so folds differ by
  # at most one participant. Every row of a participant inherits that participant's fold.
  perm   <- sample(uid)
  p_fold <- setNames(((seq_len(n_p) - 1L) %% k) + 1L, perm)
  folds  <- unname(p_fold[ids])
  list(folds = as.integer(folds), k = k, n_participants = n_p,
       fold_sizes = as.integer(table(factor(p_fold, levels = seq_len(k)))))
}
