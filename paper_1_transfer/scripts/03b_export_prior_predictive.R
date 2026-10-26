# =============================================================================
# paper_1_transfer/scripts/03b_export_prior_predictive.R
# Export the prior predictive check of the representative ERP model as data
# =============================================================================
#
# The manuscript's prior predictive figure was a PNG that step 03 draws through bayesplot
# (les_prior_predictive_check(), under LES_PRIOR_PREDICTIVE=1). It could be redrawn only by
# rerunning the fitting script, and it did not follow the house style of the other figures,
# all of which the manuscript draws at render time from committed tables. This script runs
# the same check and writes what the figure needs as data, so the manuscript can draw it
# the same way. The check is the one step 03 runs: a prior-only brms model of the
# representative cell (gender agreement, 400-900 ms, midline) under its informative priors
# and the maximal structure the manuscript reports (cache tag
# erp_gender_agreement_400_900_midline_itemslope), sampled with sample_prior = "only", two
# chains of 1,000 iterations and LES_SEED. The reported fit is neither read nor touched.
#
# OUTPUTS (results/):
#   _prior_predictive_check.csv       series ("observed" or "prior"), draw (0 for the
#                                     observed data, 1 to ndraws for the prior draws), x
#                                     (amplitude in within-participant SD units) and density
#   _prior_predictive_check_meta.csv  one row: model_tag, n_obs, n_participants, n_items,
#                                     ndraws, chains, iter, warmup, seed, backend, x_min,
#                                     x_max, abs_q99 and abs_max (the 99th percentile and the
#                                     maximum of |prior draw|), share_within (the share of
#                                     prior draws inside [x_min, x_max]), brms_version and
#                                     code_commit
#
# Each density is a Gaussian kernel estimate with the default bandwidth (stats::density(),
# bw = "nrd0"), which is how bayesplot's ppc_dens_overlay() draws the panel. It is computed
# on every value of the series and evaluated on a grid over the displayed range, so that
# limiting the view to +/-8 SD does not truncate the estimate.
#
# USAGE (cluster; needs the cell's derived data from step 01):
#   LES_P1_ITEM_SLOPE=1 Rscript paper_1_transfer/scripts/03b_export_prior_predictive.R
# Submitted by hpc/03b_prior_predictive.slurm, which sets the switch.
# =============================================================================

# Step 03 defines the cell's formula, its complete-case variables and the variant tags,
# and sources the shared settings and Paper 1's configuration. Its entry point runs only
# when it is called as a script, so sourcing it here fits nothing.
suppressPackageStartupMessages({
  source(here::here("paper_1_transfer", "scripts", "03_fit_brms_erp.R"))
})

# The representative cell, the number of prior draws drawn (as in the earlier panel) and
# the displayed range, which the figure note states.
LES_P1_PRIORPC_CELL <- list(property = "gender_agreement", window = "400_900",
                            macroregion = "midline")
LES_P1_PRIORPC_NDRAWS <- 100L
LES_P1_PRIORPC_GRID <- seq(-8, 8, length.out = 401L)

# Fits the prior-only model of `cell` and writes the two tables. Stops under any switch that
# would make the check describe a model other than the reported one. Returns the path of
# the density table, invisibly.
export_prior_predictive <- function(cell = LES_P1_PRIORPC_CELL,
                                    ndraws = LES_P1_PRIORPC_NDRAWS,
                                    grid = LES_P1_PRIORPC_GRID) {
  if (!les_p1_item_slope()) {
    stop("Set LES_P1_ITEM_SLOPE=1: the manuscript reports the maximal structure, and the ",
         "check must describe that model.", call. = FALSE)
  }
  if (nzchar(les_prior_tag()) || nzchar(les_p1_exclreproc_tag()) || les_p1_retention_free()) {
    stop("Unset LES_PRIOR_SET, LES_P1_EXCLUDE_REPROCESSED and LES_P1_RETENTION_FREE: the ",
         "check describes the reported model.", call. = FALSE)
  }
  cell_tag <- paste0(les_p1_cell_id(cell$property, cell$window, cell$macroregion),
                     les_p1_item_tag())
  rds_path <- les_p1_cell_rds(cell$property, cell$window, cell$macroregion)
  if (!file.exists(rds_path)) {
    stop("Missing derived data for ", cell_tag, ": run 01_extract_erp_single_trials.R first.",
         call. = FALSE)
  }
  dat <- readRDS(rds_path)
  # The same refusal as step 03: a derived file of the superseded cluster-row extraction
  # would give the check a different data structure from the reported model's.
  trial_key <- c("participant_lab_ID", "session", "grammaticality", "sentence_marker")
  if (!all(c("n_clusters", "eeg_source") %in% names(dat)) || "brain_region" %in% names(dat) ||
      anyDuplicated(dat[trial_key])) {
    stop(rds_path, " is not one row per trial; rerun 01_extract_erp_single_trials.R.",
         call. = FALSE)
  }
  dat <- dat %>%
    mutate(participant_lab_ID = factor(participant_lab_ID), item_id = factor(item_id)) %>%
    tidyr::drop_na(dplyr::all_of(les_p1_erp_model_vars(cell$macroregion)))

  message("[priorpc] ", cell_tag, ": sampling the prior-only model on ", nrow(dat), " trials")
  fit_prior <- brms::brm(
    formula = les_p1_erp_formula(cell$macroregion), data = dat, family = gaussian(),
    prior = les_erp_prior(cell$window, cell$property, cell$macroregion),
    sample_prior = "only",
    # As in les_prior_predictive_check(): the panel is an order-of-magnitude check, not
    # inference, so a short run is enough.
    chains = 2L, iter = 1000L, warmup = 500L, cores = 2L, refresh = 0,
    seed = LES_SEED, backend = .les_backend
  )
  # Which prior draws are taken is random, so it is seeded too.
  set.seed(LES_SEED)
  yrep <- brms::posterior_predict(fit_prior, ndraws = ndraws)

  dens <- function(v) {
    d <- stats::density(v, bw = "nrd0", n = length(grid), from = grid[1],
                        to = grid[length(grid)])
    d$y
  }
  out <- rbind(
    data.frame(series = "observed", draw = 0L, x = grid, density = dens(dat$z_amplitude)),
    do.call(rbind, lapply(seq_len(nrow(yrep)), function(i)
      data.frame(series = "prior", draw = i, x = grid, density = dens(yrep[i, ]))))
  )
  meta <- data.frame(
    model_tag = cell_tag, n_obs = nrow(dat),
    n_participants = length(unique(dat$participant_lab_ID)),
    n_items = length(unique(dat$item_id)), ndraws = nrow(yrep), chains = 2L, iter = 1000L,
    warmup = 500L, seed = LES_SEED, backend = .les_backend,
    x_min = grid[1], x_max = grid[length(grid)],
    abs_q99 = unname(stats::quantile(abs(yrep), 0.99)), abs_max = max(abs(yrep)),
    share_within = mean(yrep >= grid[1] & yrep <= grid[length(grid)]),
    brms_version = as.character(utils::packageVersion("brms")),
    code_commit = Sys.getenv("LES_CODE_COMMIT", unset = NA_character_),
    stringsAsFactors = FALSE)

  f_dens <- paper1_results("_prior_predictive_check.csv")
  f_meta <- paper1_results("_prior_predictive_check_meta.csv")
  les_assert_readonly_data(c(f_dens, f_meta))
  utils::write.csv(out, f_dens, row.names = FALSE)
  utils::write.csv(meta, f_meta, row.names = FALSE)
  message(sprintf("[priorpc] wrote %s (%d rows) and %s; |prior draw| 99th percentile %.1f, max %.1f, %.1f%% within [%g, %g]",
                  basename(f_dens), nrow(out), basename(f_meta), meta$abs_q99, meta$abs_max,
                  100 * meta$share_within, meta$x_min, meta$x_max))
  invisible(f_dens)
}

if (sys.nframe() == 0L) export_prior_predictive()
