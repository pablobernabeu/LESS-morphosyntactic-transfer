# N7, step 20: summarise calibration, variance components, projections and the extrapolation test.
# Supports the Method's estimate that a lag-tolerant re-export would narrow the interval for the
# language difference in the gender-agreement effect (term z_g:z_l) by only a few per cent: the
# "Range of % narrowing under D" table and projection_summary.csv. Written on 17 September 2026 as
# gaps/gap1/07_summarise.R; moved here with its paths changed and the brms summaries it calibrates
# against read from a file named below, because the repository's results/ copy has since been
# replaced by the October refits.
# Inputs: eeg_audit/precision/fits/*.rds (n7_16), projection.csv (n7_18), and the 20 August 2026
#         posterior summaries, read from LES_AUDIT_CALIBRATION_SUMMARIES or, when that is unset, from
#         eeg_audit/precision/pooled_posterior_summaries_2026-08-20.csv, extracted with
#         git show c785f15:paper_1_transfer/results/_pooled_posterior_summaries.csv
# Outputs: eeg_audit/precision/07_summary.txt, calibration.csv, variance_components.csv,
#          projection_summary.csv, extrapolation_test.csv, decision_metrics.csv
# Runtime: a few minutes.
source(here::here("paper_1_transfer", "audit", "precision_common.R"))
options(width = 200)
sink(file.path(G1, "07_summary.txt"), split = TRUE)
fits <- lapply(list.files(file.path(G1, "fits"), full.names = TRUE), readRDS)
names(fits) <- vapply(fits, `[[`, "", "tag")
term_map <- c(z_g = "z_recoded_grammaticality",
              `z_g:z_l` = "z_recoded_grammaticality:z_recoded_mini_language",
              `z_g:z_s` = "z_recoded_grammaticality:z_recoded_session",
              `z_g:z_s:z_l` = "z_recoded_grammaticality:z_recoded_session:z_recoded_mini_language")
win_lab <- function(w) sub("^w", "", w)

# ---- 1. Calibration: lme4 REML SE vs brms posterior SD (95% CrI width / 3.92), stale sample ----
cal_file <- Sys.getenv("LES_AUDIT_CALIBRATION_SUMMARIES")
if (!nzchar(cal_file)) cal_file <- file.path(G1, "pooled_posterior_summaries_2026-08-20.csv")
if (!file.exists(cal_file)) {
  stop("The 20 August 2026 posterior summaries are needed for the calibration: run\n",
       "  git show c785f15:paper_1_transfer/results/_pooled_posterior_summaries.csv > ", cal_file,
       "\nor point LES_AUDIT_CALIBRATION_SUMMARIES at a copy.", call. = FALSE)
}
bs <- fread(cal_file)
cal <- rbindlist(lapply(fits[vapply(fits, function(f) f$variant == "stale" && f$thin == 1, TRUE)], function(f) {
  mid <- paste0("erp_gender_agreement_", win_lab(f$window), "_", f$macro, if (f$structure == "max") "_itemslope" else "")
  b <- bs[model == mid & parameter %in% term_map]
  data.table(window = f$window, macro = f$macro, structure = f$structure, term = KEY,
             lme4_est = f$fixef[KEY], brms_median = b$median[match(term_map[KEY], b$parameter)],
             lme4_se = sqrt(diag(f$vcov))[KEY],
             brms_sd = (b$ci_high - b$ci_low)[match(term_map[KEY], b$parameter)] / 3.92)
}))
cal[, ratio := brms_sd / lme4_se]
fwrite(cal, file.path(G1, "calibration.csv"))
cat("== 1. Calibration on the stale sample (the only brms fits on disk) ==\n")
print(cal[, .(window, macro, structure, term, lme4_est = round(lme4_est, 4), brms_median = round(brms_median, 4),
              lme4_se = round(lme4_se, 5), brms_sd = round(brms_sd, 5), ratio = round(ratio, 3))])
calr <- cal[, .(ratio_median = median(ratio), ratio_min = min(ratio), ratio_max = max(ratio)), by = .(structure, term)]
print(calr)

# ---- 2. Variance components, current sample ----
vc <- rbindlist(lapply(fits[vapply(fits, function(f) f$variant == "current" && f$thin == 1, TRUE)], function(f) {
  v <- as.data.table(f$varcorr)[is.na(var2)]
  data.table(window = f$window, macro = f$macro, structure = f$structure, grp = v$grp, term = v$var1,
             sd = v$sdcor, singular = f$singular, n_rows = f$n_rows, n_trials = f$n_trials, n_pid = f$n_pid,
             trials_per_cell = f$trials_per_cell)
}))
fwrite(vc, file.path(G1, "variance_components.csv"))
cat("\n== 2. Variance components (SD), current analysed sample ==\n")
print(dcast(vc, window + macro + structure ~ grp + term, value.var = "sd", fun.aggregate = function(x) round(x[1], 4)))

# ---- 3. Projection ----
pr <- unique(fread(file.path(G1, "projection.csv")), by = c("tag", "design", "term"))
cur <- pr[variant == "current" & thin == 1]
w <- dcast(cur, window + macro + structure + term ~ design, value.var = "se")
w <- merge(w, dcast(cur, window + macro + structure + term ~ design, value.var = "trials_per_cell")[
  , .(window, macro, structure, term, tpc_now = fitted, tpc_D = D_lag6)], by = c("window", "macro", "structure", "term"))
stopifnot(max(abs(w$fitted - w$gls_fitted) / w$fitted) < 1e-6)
w[, `:=`(pct_narrower_D = 100 * (1 - D_lag6 / fitted), pct_narrower_x1.506 = 100 * (1 - x1.506 / fitted))]
w <- merge(w, calr[, .(structure = fifelse(structure == "max", "max", structure), term, ratio_median)],
           by = c("structure", "term"), all.x = TRUE)
# The robustness structures have no brms counterpart; carry the primary structure's ratio.
w[is.na(ratio_median), ratio_median := calr[structure == "max"][match(w[is.na(ratio_median)]$term, term), ratio_median]]
w[, `:=`(post_sd_now = fitted * ratio_median, post_sd_D = D_lag6 * ratio_median)]
fwrite(w, file.path(G1, "projection_summary.csv"))
cat("\n== 3. Projected SE / posterior SD, current sample, now vs option D ==\n")
print(w[order(term, structure, macro, window), .(term, structure, macro, window, tpc_now = round(tpc_now, 2), tpc_D = round(tpc_D, 2),
          se_now = round(fitted, 5), se_D = round(D_lag6, 5), pct_D = round(pct_narrower_D, 1),
          pct_x1.506 = round(pct_narrower_x1.506, 1), post_sd_now = round(post_sd_now, 5), post_sd_D = round(post_sd_D, 5))])
cat("\nRange of % narrowing under D, by term and structure:\n")
print(w[, .(min = round(min(pct_narrower_D), 1), median = round(median(pct_narrower_D), 1), max = round(max(pct_narrower_D), 1)),
        by = .(term, structure)][order(term, structure)])
cat(sprintf("Noise-only ceiling at the analysed counts: 1 - sqrt(%.2f / %.2f) = %.1f%%\n",
            w$tpc_now[1], w$tpc_D[1], 100 * (1 - sqrt(w$tpc_now[1] / w$tpc_D[1]))))

# ---- 4. Extrapolation test: thinned fits projected back to the full cell ----
th <- pr[thin < 1]
if (nrow(th)) {
  full_se <- cur[window == "w400_900" & macro == "midline" & design == "fitted", .(structure, term, se_full_actual = se)]
  et <- merge(dcast(th, structure + thin + seed + term ~ design, value.var = "se"), full_se, by = c("structure", "term"))
  tpc <- unique(th[design == "fitted", .(structure, thin, seed, tpc_thin = trials_per_cell)])
  et <- merge(et, tpc, by = c("structure", "thin", "seed"))
  et[, `:=`(pct_narrowing_predicted = 100 * (1 - full / fitted),
            pct_narrowing_actual = 100 * (1 - se_full_actual / fitted),
            pred_error_pct = 100 * (full / se_full_actual - 1))]
  fwrite(et, file.path(G1, "extrapolation_test.csv"))
  cat("\n== 4. Extrapolation test (midline 400-900): refit on a random 2/3 or 1/2 of trials, project to the full cell ==\n")
  print(et[order(structure, term, thin, seed), .(structure, term, thin, seed, tpc_thin = round(tpc_thin, 1),
            se_thin = round(fitted, 5), se_full_pred = round(full, 5), se_full_actual = round(se_full_actual, 5),
            narrowing_pred = round(pct_narrowing_predicted, 1), narrowing_actual = round(pct_narrowing_actual, 1),
            pred_error_pct = round(pred_error_pct, 1))])
}

# ---- 5. Decision metrics for the terms that carry the conclusion ----
cov <- participant_covariates(); trials <- read_trials()
dm <- rbindlist(lapply(split(w[structure %in% c("max", "gstrial") & term %in% c("z_g:z_l", "z_g:z_s:z_l")],
                             by = c("window", "macro"), keep.by = TRUE), function(x) {
  d <- build_cell(trials, cov, x$window[1], x$macro[1], "current")
  sc <- attr(d, "scaling")
  uv <- d[, .(sd_uv = sd(amp)), by = pid][, mean(sd_uv)]           # mean within-participant SD, µV
  f <- fits[[paste(x$window[1], x$macro[1], "current_max", sep = "_")]]
  b_g <- f$fixef[["z_g"]]; b_gs <- f$fixef[["z_g:z_s"]]
  # z-code distances: grammatical - ungrammatical = 1/sd_g; Mini-Norwegian - Mini-English = 1/sd_l;
  # Session 2 -> 6 = 3/sd_s.
  dG <- 1 / sc$g[2]; dL <- 1 / sc$l[2]; dS <- 3 / sc$s[2]
  x[, `:=`(sd_within_uV = uv, avg_gram_effect_z = b_g * dG, gram_change_S2_S6_z = b_gs * dG * dS)]
  x[term == "z_g:z_l", `:=`(scale = dG * dL, label = "group difference in the grammaticality effect")]
  x[term == "z_g:z_s:z_l", `:=`(scale = dG * dL * dS, label = "group difference in its Session 2-6 change")]
  x[, `:=`(hw95_now_z = 1.96 * post_sd_now * scale, hw95_D_z = 1.96 * post_sd_D * scale,
           mdd80_now_z = 2.80 * post_sd_now * scale, mdd80_D_z = 2.80 * post_sd_D * scale)]
  x[, `:=`(hw95_now_uV = hw95_now_z * uv, hw95_D_uV = hw95_D_z * uv)]
  x[term == "z_g:z_l", `:=`(ratio_hw_to_effect_now = hw95_now_z / abs(avg_gram_effect_z), ratio_hw_to_effect_D = hw95_D_z / abs(avg_gram_effect_z))]
  x[term == "z_g:z_s:z_l", `:=`(ratio_hw_to_effect_now = hw95_now_z / abs(gram_change_S2_S6_z), ratio_hw_to_effect_D = hw95_D_z / abs(gram_change_S2_S6_z))]
  # Participants that would buy the same narrowing, if SE ~ 1/sqrt(J): extra J = J ((se_now/se_D)^2 - 1)
  x[, extra_participants_equiv := f$n_pid * ((fitted / D_lag6)^2 - 1)]
  x
}))
fwrite(dm, file.path(G1, "decision_metrics.csv"))
cat("\n== 5. Decision metrics (posterior-SD scale; z = within-participant SD units of single-trial amplitude) ==\n")
print(dm[order(structure, term, macro, window), .(structure, term, macro, window, pct_D = round(pct_narrower_D, 1),
         hw95_now_z = round(hw95_now_z, 3), hw95_D_z = round(hw95_D_z, 3), hw95_now_uV = round(hw95_now_uV, 2), hw95_D_uV = round(hw95_D_uV, 2),
         effect_ref_z = round(fifelse(term == "z_g:z_l", avg_gram_effect_z, gram_change_S2_S6_z), 3),
         hw_over_effect_now = round(ratio_hw_to_effect_now, 2), hw_over_effect_D = round(ratio_hw_to_effect_D, 2),
         extra_participants_equiv = round(extra_participants_equiv, 1), sd_within_uV = round(sd_within_uV, 2))])
sink()
