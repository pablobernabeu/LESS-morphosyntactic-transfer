# N7, step 16: fit one gender-agreement ERP cell with lme4 (REML) and save its variance components.
# Written on 17 September 2026 as gaps/gap1/03_fit_one.R; moved here with only its paths changed.
# Usage: Rscript n7_16_fit_one.R <window w200_500|w300_600|w400_900> <midline|lateral> <stale|current>
#                                <structure max|base|gs|trial|gstrial> [thin fraction] [seed]
# structure: max     = the primary structure of the August fits (by-item grammaticality slope)
#            base    = without the by-item grammaticality slope
#            gs      = max + by-participant grammaticality x session slope (the slope for the three-way
#                      term's within-participant component, which the August fits omitted)
#            trial   = max + a random intercept per trial (the 3 or 6 region rows of one trial are
#                      not independent observations)
#            gstrial = gs + trial; the closest to the October model, which averages the region rows
#                      within each trial and carries the grammaticality x session slope (ISSUES.md N9)
# Writes eeg_audit/precision/fits/<tag>.rds (formula, theta, sigma, VarCorr, fixef, vcov, counts, timing).
# Runtime: under a minute to about eight minutes per fit (the 56 fits took 56 minutes in all).
source(here::here("paper_1_transfer", "audit", "precision_common.R"))
a <- commandArgs(trailingOnly = TRUE)
window <- a[1]; macro <- a[2]; variant <- a[3]; structure <- a[4]
thin <- if (length(a) >= 5) as.numeric(a[5]) else 1
seed <- if (length(a) >= 6) as.integer(a[6]) else 1L
dir.create(file.path(G1, "fits"), showWarnings = FALSE)
tag <- paste(window, macro, variant, structure, sep = "_")
if (thin < 1) tag <- paste0(tag, "_thin", thin, "_seed", seed)

d <- build_cell(read_trials(), participant_covariates(), window, macro, variant)
if (thin < 1) {
  # Keep a random fraction of the TRIALS (all region rows of a kept trial) within every
  # participant x session x condition cell, as a trial loss that is independent of condition would.
  set.seed(seed)
  tr <- unique(d[, .(trial, pid, session, g)])
  kept <- tr[, .SD[sample.int(.N, max(1L, round(.N * thin)))], by = .(pid, session, g)]$trial
  d <- d[trial %in% kept]
  # Standardisation is left as in the full cell, so coefficients stay on the same scale.
}
f <- erp_formula(macro, item_slope = structure != "base",
                 extra_part = if (structure %in% c("gs", "gstrial")) " + z_g:z_s" else "",
                 trial_re = structure %in% c("trial", "gstrial"))
t0 <- proc.time()[["elapsed"]]
fit <- lmer(f, data = d, REML = TRUE,
            control = lmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5),
                                  calc.derivs = FALSE))
el <- proc.time()[["elapsed"]] - t0
V <- as.matrix(vcov(fit))
out <- list(tag = tag, window = window, macro = macro, variant = variant, structure = structure,
            thin = thin, seed = seed, formula = f, theta = getME(fit, "theta"), sigma = sigma(fit),
            varcorr = as.data.frame(VarCorr(fit)), fixef = fixef(fit), vcov = V,
            n_rows = nrow(d), n_trials = uniqueN(d$trial), n_pid = uniqueN(d$pid),
            trials_per_cell = d[, .(n = uniqueN(trial)), by = .(pid, session, g)][, mean(n)],
            singular = isSingular(fit), messages = fit@optinfo$conv$lme4$messages, seconds = el,
            kept_trials = if (thin < 1) as.character(unique(d$trial)) else NULL)
saveRDS(out, file.path(G1, "fits", paste0(tag, ".rds")))
cat(sprintf("%s: %.0f s, rows %d, singular %s\n", tag, el, nrow(d), isSingular(fit)))
print(out$varcorr[, c("grp", "var1", "var2", "sdcor")])
print(cbind(est = out$fixef[KEY], se = sqrt(diag(V))[KEY]))
