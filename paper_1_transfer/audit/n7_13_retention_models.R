# N7, step 13: does ERP trial loss depend on condition x session x mini-language?
#
# Supports the Method's report of the largest condition imbalance in trial retention: in the
# Mini-English group at Session 6, the odds of losing an ungrammatical rather than a grammatical
# trial (scope "lost | S101/S102 analysed, with P20", Session 6 row "S102 vs S101 within
# Mini-English" of 02_contrasts.csv; OR 0.83, 95% CI [0.73, 0.94] on 17 September 2026), and the
# condition x session x language tests behind "not perfectly even across groups and sessions".
# Written on 17 September 2026 as gaps/gap5/02_models.R; moved here with only its paths changed.
#
# Inputs (read-only, built by the earlier steps from the raw .vmrk, the Analyzer exports and the logs)
#   eeg_audit/aligned/02_analysis.csv   one row per recorded S10x marker aligned to a logged trial:   [n7_11]
#                                       exported (key-matched to an export segment), lag (samples from the
#                                       property marker), language, session, property, condition, excluded
#   eeg_audit/cells/c04_cells.csv       one row per export stem: presented (log), importable (legacy importer) [n7_09]
# Responses
#   lost  = recorded-and-aligned trial with no matching export segment          (02_analysis.csv)
#   lag6  = condition marker 6 samples after the property marker (lag 5 or 6 only; the lag rule)
#   cells = presented - importable per recording x property x condition        (c04_cells.csv; every loss source)
# Model: cbind(lost, kept) ~ cond * sess * lang + (1 | participant) + (1 | recording) [+ (1 | cell)]
#   Every predictor is constant within recording x property x condition, so the Bernoulli GLMM and the binomial
#   GLMM on those cells have the same likelihood up to a constant; section 0 checks this on the primary scope.
#   LRTs: 3-way (full vs all 2-ways); each 2-way against the all-2-ways model. Sum-to-zero contrasts.
# Output: eeg_audit/retention/02_models.txt, 02_lrt.csv, 02_contrasts.csv
# Runtime: about 8 minutes (lme4 2.0.1, R 4.6.1).
suppressPackageStartupMessages({library(lme4); library(data.table)})
source(here::here("paper_1_transfer", "audit", "audit_paths.R"))
HERE <- audit_dir("retention")
setwd(HERE)
sink("02_models.txt", split = TRUE)
options(contrasts = c("contr.sum", "contr.poly"), width = 200)
cat(R.version.string, "| lme4", as.character(packageVersion("lme4")), "\n")
ctl <- glmerControl(optimizer = "bobyqa", optCtrl = list(maxfun = 2e5))
t0 <- Sys.time()

d <- fread(file.path(audit_dir("aligned"), "02_analysis.csv"),
           colClasses = list(character = c("participant", "recording", "item", "word")))
d[, lost := as.integer(!exported)]
cat("02_analysis.csv rows", nrow(d), "| recordings", uniqueN(d$recording), "| exported TRUE", sum(d$exported), "\n")

agg <- function(x, y) {
  x[, .(lost = sum(get(y)), kept = sum(1L - get(y)), n = .N),
    by = .(participant, recording, session, language, property, condition)]
}
prep <- function(x) {
  x <- copy(x)
  x[, `:=`(cond = factor(condition), sess = factor(session), lang = factor(language),
           cell = paste(recording, property, condition, sep = "_"))]
  x
}

LRT <- list(); CON <- list()
fixed_rhs <- c(m3 = "cond * sess * lang",
               m2 = "(cond + sess + lang)^2",
               m2_no_cs = "cond + sess + lang + cond:lang + sess:lang",
               m2_no_cl = "cond + sess + lang + cond:sess + sess:lang",
               m2_no_sl = "cond + sess + lang + cond:sess + cond:lang")

contrasts_by_session <- function(m, dd, label) {
  lv <- list(cond = levels(dd$cond), sess = levels(dd$sess), lang = levels(dd$lang))
  if (!all(c("101", "102") %in% lv$cond)) return(NULL)
  g <- CJ(cond = factor(lv$cond, levels = lv$cond), sess = factor(lv$sess, levels = lv$sess),
          lang = factor(lv$lang, levels = lv$lang))
  X <- model.matrix(~ cond * sess * lang, g, contrasts.arg = attr(getME(m, "X"), "contrasts"))
  b <- fixef(m); V <- as.matrix(vcov(m)); stopifnot(identical(colnames(X), names(b)))
  row <- function(c, s, l) which(g$cond == c & g$sess == s & g$lang == l)
  out <- list()
  for (s in lv$sess) {
    for (l in lv$lang) {
      L <- X[row("102", s, l), ] - X[row("101", s, l), ]
      est <- sum(L * b); se <- sqrt(drop(t(L) %*% V %*% L))
      p101 <- plogis(sum(X[row("101", s, l), ] * b)); p102 <- plogis(sum(X[row("102", s, l), ] * b))
      out[[length(out) + 1]] <- data.table(scope = label, session = s, contrast = paste0("S102 vs S101 within ", l),
        log_or = est, se = se, OR = exp(est), lo = exp(est - 1.96 * se), hi = exp(est + 1.96 * se),
        p = 2 * pnorm(-abs(est / se)), loss_S101_re0 = p101, loss_S102_re0 = p102)
    }
    ls <- lv$lang
    L <- (X[row("102", s, ls[1]), ] - X[row("101", s, ls[1]), ]) - (X[row("102", s, ls[2]), ] - X[row("101", s, ls[2]), ])
    est <- sum(L * b); se <- sqrt(drop(t(L) %*% V %*% L))
    out[[length(out) + 1]] <- data.table(scope = label, session = s, contrast = paste0("(S102 vs S101) ", ls[1], " minus ", ls[2]),
      log_or = est, se = se, OR = exp(est), lo = exp(est - 1.96 * se), hi = exp(est + 1.96 * se), p = 2 * pnorm(-abs(est / se)),
      loss_S101_re0 = NA_real_, loss_S102_re0 = NA_real_)
    # language main contrast within session, averaged over the two conditions
    L <- (X[row("101", s, ls[1]), ] + X[row("102", s, ls[1]), ] - X[row("101", s, ls[2]), ] - X[row("102", s, ls[2]), ]) / 2
    est <- sum(L * b); se <- sqrt(drop(t(L) %*% V %*% L))
    out[[length(out) + 1]] <- data.table(scope = label, session = s, contrast = paste0("loss odds ", ls[1], " vs ", ls[2], " (mean of S101, S102)"),
      log_or = est, se = se, OR = exp(est), lo = exp(est - 1.96 * se), hi = exp(est + 1.96 * se), p = 2 * pnorm(-abs(est / se)),
      loss_S101_re0 = NA_real_, loss_S102_re0 = NA_real_)
  }
  rbindlist(out)
}

fit_scope <- function(dd, label, olre = FALSE) {
  dd <- prep(dd)
  re <- if (olre) " + (1 | participant) + (1 | recording) + (1 | cell)" else " + (1 | participant) + (1 | recording)"
  lab <- paste0(label, if (olre) " [+ (1|cell)]" else "")
  cat("\n==============================", lab, "\n")
  cat("cells", nrow(dd), "| trials", sum(dd$n), "| lost", sum(dd$lost), sprintf("(%.2f%%)", 100 * sum(dd$lost) / sum(dd$n)),
      "| recordings", uniqueN(dd$recording), "| participants", uniqueN(dd$participant),
      "| conditions", paste(levels(dd$cond), collapse = "/"), "\n")
  fits <- list()
  for (nm in names(fixed_rhs)) {
    f <- as.formula(paste("cbind(lost, kept) ~", fixed_rhs[[nm]], re))
    w <- NULL
    fits[[nm]] <- withCallingHandlers(glmer(f, data = dd, family = binomial, control = ctl),
                                      warning = function(x) { w <<- c(w, conditionMessage(x)); invokeRestart("muffleWarning") })
    msg <- c(w, fits[[nm]]@optinfo$conv$lme4$messages)
    if (length(msg) || isSingular(fits[[nm]])) cat("  [", nm, "] singular:", isSingular(fits[[nm]]), "| messages:", paste(unique(msg), collapse = " ; "), "\n")
  }
  lrt <- function(a, b, term) {
    an <- anova(fits[[a]], fits[[b]])
    data.table(scope = lab, term = term, chisq = an$Chisq[2], df = an$Df[2], p = an$`Pr(>Chisq)`[2],
               logLik_small = as.numeric(logLik(fits[[a]])), logLik_big = as.numeric(logLik(fits[[b]])))
  }
  res <- rbind(lrt("m2", "m3", "cond:sess:lang"),
               lrt("m2_no_cs", "m2", "cond:sess (given all 2-ways)"),
               lrt("m2_no_cl", "m2", "cond:lang (given all 2-ways)"),
               lrt("m2_no_sl", "m2", "sess:lang (given all 2-ways)"))
  print(res[, .(term, chisq = round(chisq, 3), df, p = signif(p, 3))])
  cat("random-effect SDs (full model):\n"); print(VarCorr(fits$m3))
  cc <- contrasts_by_session(fits$m3, dd, lab)
  if (!is.null(cc)) {
    cat("within-session contrasts from the full model (OR for loss; loss probabilities at random effects = 0):\n")
    print(cc[, .(session, contrast, OR = round(OR, 3), lo = round(lo, 3), hi = round(hi, 3), p = signif(p, 3),
                 loss_S101 = round(loss_S101_re0, 4), loss_S102 = round(loss_S102_re0, 4))])
    CON[[lab]] <<- cc
  }
  LRT[[lab]] <<- res
  cat("elapsed", format(Sys.time() - t0), "\n")
  invisible(fits)
}

# ---------------------------------------------------------------- 0. Bernoulli vs aggregated binomial, primary scope
P <- d[condition %in% c(101, 102) & excluded == 0]
cat("\n== 0. equivalence check on the primary scope (S101/S102, analysed recordings, response = not exported) ==\n")
Pt <- prep(P[, .(participant, recording, session, language, property, condition, lost)])
mt3 <- glmer(lost ~ cond * sess * lang + (1 | participant) + (1 | recording), data = Pt, family = binomial, control = ctl)
mt2 <- glmer(lost ~ (cond + sess + lang)^2 + (1 | participant) + (1 | recording), data = Pt, family = binomial, control = ctl)
an_t <- anova(mt2, mt3)
Pa <- prep(agg(P, "lost"))
ma3 <- glmer(cbind(lost, kept) ~ cond * sess * lang + (1 | participant) + (1 | recording), data = Pa, family = binomial, control = ctl)
ma2 <- glmer(cbind(lost, kept) ~ (cond + sess + lang)^2 + (1 | participant) + (1 | recording), data = Pa, family = binomial, control = ctl)
an_a <- anova(ma2, ma3)
cat(sprintf("trial-level: n=%d  3-way LRT chi2=%.4f df=%d p=%.4g | aggregated: cells=%d  chi2=%.4f df=%d p=%.4g\n",
            nrow(Pt), an_t$Chisq[2], an_t$Df[2], an_t$`Pr(>Chisq)`[2], nrow(Pa), an_a$Chisq[2], an_a$Df[2], an_a$`Pr(>Chisq)`[2]))
cat("max |fixef difference| full model:", signif(max(abs(fixef(mt3) - fixef(ma3))), 3),
    "| RE SDs trial:", paste(round(sapply(VarCorr(mt3), function(v) attr(v, "stddev")), 4), collapse = " "),
    "aggregated:", paste(round(sapply(VarCorr(ma3), function(v) attr(v, "stddev")), 4), collapse = " "), "\n")
cat("elapsed", format(Sys.time() - t0), "\n")
rm(Pt, mt3, mt2); invisible(gc())

# ---------------------------------------------------------------- 1. not exported, 02_analysis.csv
S12 <- d[condition %in% c(101, 102) & excluded == 0]
fit_scope(agg(S12, "lost"), "lost | S101/S102 analysed, with P20")
fit_scope(agg(S12, "lost"), "lost | S101/S102 analysed, with P20", olre = TRUE)
fit_scope(agg(S12[participant != "20"], "lost"), "lost | S101/S102 analysed, without P20")
fit_scope(agg(S12[participant != "20"], "lost"), "lost | S101/S102 analysed, without P20", olre = TRUE)
fit_scope(agg(S12[participant != "20" & recording != "S4_7"], "lost"), "lost | S101/S102 analysed, without P20 and S4/7 (export key-match failure)")
fit_scope(agg(S12[!recording %in% c("S4_9", "S4_33")], "lost"), "lost | S101/S102 analysed, with P20, without S4/9 and S4/33")
fit_scope(agg(S12[!recording %in% c("S6_9")], "lost"), "lost | S101/S102 analysed, with P20, without S6/9")

# ---------------------------------------------------------------- 2. lag rule (lag 6 vs 5)
L12 <- S12[!is.na(lag6)]
fit_scope(agg(L12, "lag6"), "lag6 | S101/S102 analysed, with P20")
fit_scope(agg(L12[participant != "20"], "lag6"), "lag6 | S101/S102 analysed, without P20")

# ---------------------------------------------------------------- 3. comparability with C09 (all conditions, all recordings)
fit_scope(agg(d[!is.na(lag6)], "lag6"), "lag6 | S101/S102/S103, all recordings (C09 set)")
fit_scope(agg(d, "lost"), "lost | S101/S102/S103, all recordings")

# ---------------------------------------------------------------- 4. presented denominator, c04_cells.csv
cc <- fread(file.path(audit_dir("cells"), "c04_cells.csv"))
cc <- cc[canonical == TRUE & excluded == FALSE]
cc[, `:=`(participant = as.character(participant), recording = paste0("S", session, "_", participant),
          language = ifelse(participant %% 2 == 1, "Mini-English", "Mini-Norwegian"),
          condition = as.integer(sub("S", "", condition)), lost = presented - importable, kept = importable, n = presented)]
cat("\nc04 analysed cells:", nrow(cc), "| presented", sum(cc$presented), "| importable", sum(cc$importable),
    "| cells with design presented (no log):", sum(!cc$presented_from_log), "\n")
fit_scope(cc, "presented - importable | c04 cells, with P20")
fit_scope(cc, "presented - importable | c04 cells, with P20", olre = TRUE)
fit_scope(cc[participant != "20"], "presented - importable | c04 cells, without P20")
fit_scope(cc[participant != "20"], "presented - importable | c04 cells, without P20", olre = TRUE)
fit_scope(cc[presented_from_log == TRUE], "presented - importable | c04 cells with a usable log, with P20")

fwrite(rbindlist(LRT), "02_lrt.csv")
fwrite(rbindlist(CON), "02_contrasts.csv")
cat("\n== LRT summary ==\n")
print(rbindlist(LRT)[, .(scope, term, chisq = round(chisq, 2), df, p = signif(p, 3))])
cat("total elapsed", format(Sys.time() - t0), "\n")
sink()
