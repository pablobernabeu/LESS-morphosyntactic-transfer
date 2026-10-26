# N7, step 18: project the standard error (the frequentist counterpart of the posterior SD) of the
# key gender-agreement ERP terms at the current trial counts and under option D, holding the
# variance components of each fit fixed. Written on 17 September 2026 as gaps/gap1/05_project.R;
# moved here with only its paths changed.
# Usage: Rscript n7_18_project.R <fit tag> [<fit tag> ...]   (fits/<tag>.rds from n7_16_fit_one.R)
# Appends to eeg_audit/precision/projection.csv one row per tag x term x design:
#   design "fitted"      lme4 vcov on the fitted data
#   design "gls_fitted"  gls_vcov() on the fitted data (must equal "fitted"; checks the algebra)
#   design "D_lag6"      fitted data + recovered trials: per cell, the raw lag-6 events scaled by the
#                        cell's exported/lag-5 share, each assigned to its own raw sentence frame
#   design "x1.506"      every cell scaled by 47.6/31.6, items resampled within the cell
#   design "full"        (thinned fits only) the full current cell, to test extrapolation
# Runtime: a few minutes per tag.
source(here::here("paper_1_transfer", "audit", "precision_common.R"))
tags <- commandArgs(trailingOnly = TRUE)
cov <- participant_covariates(); trials <- read_trials()
lagc <- fread(file.path(G1, "lag_counts_current.csv"))
lag6 <- fread(file.path(G1, "lag6_items.csv"))

augment <- function(d, n_target, item_source = c("lag6", "cell"), seed = 20260917L) {
  item_source <- match.arg(item_source)
  set.seed(seed)
  tr <- unique(d[, .(trial, pidi = as.integer(as.character(pid)), session, condition, mini_language, item)])
  tr <- merge(tr, n_target, by.x = c("pidi", "session", "condition"), by.y = c("pid", "session", "condition"))
  add <- tr[, {
    k <- n_new[1] - .N
    if (k <= 0) NULL else {
      src <- trial[sample.int(.N, k, replace = TRUE)]
      if (item_source == "lag6") {
        pool <- lag6[pid == pidi[1] & session == session[1] & condition == condition[1], sentence]
        pool <- pool[pool > 0]
        it <- if (length(pool) >= k) sample(pool, k) else if (length(pool)) sample(pool, k, replace = TRUE)
              else sub("^.*_", "", as.character(item[sample.int(.N, k, replace = TRUE)]))
        it <- paste0(mini_language[1], "_", it)
      } else {
        it <- as.character(item[sample.int(.N, k, replace = TRUE)])
      }
      .(src_trial = src, new_item = it)
    }
  }, by = .(pidi, session, condition)]
  if (!nrow(add)) return(d)
  add[, new_trial := paste0("aug", seq_len(.N))]
  new <- merge(add[, .(src_trial, new_item, new_trial)], d, by.x = "src_trial", by.y = "trial",
               allow.cartesian = TRUE)
  new[, `:=`(item = new_item, trial = new_trial)]
  new[, c("src_trial", "new_item", "new_trial") := NULL]
  out <- rbind(d[, trial := as.character(trial)], new, use.names = TRUE, fill = TRUE)
  out[, `:=`(item = factor(as.character(item)), trial = factor(trial))]
  out
}

res <- list()
for (tag in tags) {
  fr <- readRDS(file.path(G1, "fits", paste0(tag, ".rds")))
  full <- build_cell(trials, cov, fr$window, fr$macro, fr$variant)
  d <- if (fr$thin < 1) full[trial %in% fr$kept_trials] else copy(full)
  se <- function(V) sqrt(diag(V))[KEY]
  rows <- list(fitted = se(fr$vcov))
  cnt <- function(x) x[, .(n = uniqueN(trial)), by = .(pid, session, g)][, mean(n)]
  ntr <- c(fitted = cnt(d))
  rows$gls_fitted <- se(gls_vcov(fr$formula, fr$theta, fr$sigma, d)); ntr["gls_fitted"] <- cnt(d)
  if (fr$variant == "current") {
    cur <- unique(d[, .(pid = as.integer(as.character(pid)), session, condition, trial)])[, .(n_cur = .N), by = .(pid, session, condition)]
    if (fr$thin == 1) {
      tgtD <- lagc[, .(pid, session, condition, n_new = n_D)]
      dD <- augment(copy(d), tgtD, "lag6")
      rows$D_lag6 <- se(gls_vcov(fr$formula, fr$theta, fr$sigma, dD)); ntr["D_lag6"] <- cnt(dD)
      tgtG <- cur[, .(pid, session, condition, n_new = round(n_cur * 47.6 / 31.6))]
      dG <- augment(copy(d), tgtG, "cell")
      rows[["x1.506"]] <- se(gls_vcov(fr$formula, fr$theta, fr$sigma, dG)); ntr["x1.506"] <- cnt(dG)
      rm(dD, dG)
    } else {
      rows$full <- se(gls_vcov(fr$formula, fr$theta, fr$sigma, full)); ntr["full"] <- cnt(full)
    }
  }
  for (nm in names(rows)) {
    res[[length(res) + 1]] <- data.table(tag = tag, window = fr$window, macro = fr$macro,
      variant = fr$variant, structure = fr$structure, thin = fr$thin, seed = fr$seed,
      design = nm, trials_per_cell = ntr[[nm]], term = KEY, se = rows[[nm]],
      estimate = fr$fixef[KEY])
  }
  cat(tag, "done\n")
  this_tag <- tag
  print(dcast(rbindlist(res)[tag == this_tag], term ~ design, value.var = "se"))
}
out <- rbindlist(res)
fn <- file.path(G1, "projection.csv")
fwrite(out, fn, append = file.exists(fn))
