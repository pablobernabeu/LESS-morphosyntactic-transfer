# =============================================================================
# paper_1_transfer/scripts/tests/test_rt_screen_prose.R
# -----------------------------------------------------------------------------
# Checks the manuscript's prose about the legacy reaction-time screen, which since
# 19 October 2026 is a sensitivity analysis (tag _rtscreen; ISSUES.md G06-03), against the
# reported fits on every judgement:
#   * rt_screen_sentence(), the Results sentence comparing the screened refits with the
#     reported ones: the refits missing, every contrast unchanged, one contrast that stops
#     being credible and one that becomes so, and a screened sample that is not the smaller
#     one;
#   * rtscreen_weight_paragraph() (Strength of evidence) and sens_difference_concession()
#     (the misanalysis account), on the expected pattern and on cases that leave it;
#   * the claims about the refit with the by-participant grammaticality x session slope
#     (maxranef_claims_guard(), crit_direction_clause(), crit_maxranef_shift()) and the
#     differential-object-marking sentences (dom_edge_clause(), dom_sens_guard());
#   * rt_legacy_sentence() (the Method), on the band counts and on a table that no longer
#     adds up.
# The expected pattern is the one the fits pulled on 22 October 2026 show, read from the
# committed table.
#
# The helpers are taken from the manuscript itself: knitr::purl() extracts its R code, and
# only the named function definitions are evaluated, so nothing is rendered.
#
# Run from the project root:
#   Rscript --vanilla paper_1_transfer/scripts/tests/test_rt_screen_prose.R
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  # The property labels the helpers name, apa_num() and .pd_math().
  source(here::here("_shared", "R", "03_data_manifest.R"))
  source(here::here("_shared", "R", "06_manuscript_helpers.R"))
})

ok <- function(cond, msg) {
  if (!isTRUE(cond)) stop("FAIL: ", msg, call. = FALSE)
  cat("PASS:", msg, "\n")
}
has <- function(x, pattern) grepl(pattern, x, fixed = TRUE)

# --- The helpers, from the manuscript ----------------------------------------
code <- file.path(tempdir(), "paper_1_morphosyntax_purl_rt.R")
invisible(suppressMessages(knitr::purl(here::here("paper_1_transfer", "paper_1_morphosyntax.qmd"),
                                       output = code, documentation = 0, quiet = TRUE)))
want <- c(".has_sdt_model", ".sdt_contrast_label", ".clause_list", ".rt_comparison",
          ".rt_term_flips", "rt_screen_sentence", ".sdt_row", "report_sdt", ".les_digits",
          "rtscreen_weight_paragraph", "sens_difference_concession", "sdt_credible_sessions",
          "sdt_language_clause", "sdt_language_clause_model", "sens_gender_clause",
          "sdt_claims_guard", "rt_legacy_sentence", "rt_screen", "crit_direction_clause",
          "crit_maxranef_shift", "maxranef_claims_guard", "dom_edge_clause", "dom_sens_guard",
          ".SDT_REFIT_LABELS", ".and_list", "sdt_mcse_sentence")
got <- character()
for (e in parse(code, keep.source = FALSE)) {
  if (is.call(e) && identical(e[[1]], as.name("<-")) && is.name(e[[2]]) &&
      as.character(e[[2]]) %in% want) {
    eval(e, globalenv())
    got <- c(got, as.character(e[[2]]))
  }
}
ok(setequal(got, want), paste("every helper is defined in the manuscript; missing:",
                              paste(setdiff(want, got), collapse = ", ")))

# --- The state the setup chunks would leave ----------------------------------
LES_P1_PROPERTIES <- c(gender_agreement = "S1", differential_object_marking = "S2",
                       verb_object_number_agreement = "S3")
ids <- paste0("accuracy_", names(LES_P1_PROPERTIES))
committed <- utils::read.csv(here::here("paper_1_transfer", "results", "_accuracy_sdt_contrasts.csv"),
                             stringsAsFactors = FALSE)
stopifnot(all(c(ids, paste0(ids, "_rtscreen")) %in% committed$model))
reported <- committed[committed$model %in% ids, ]
screened_pulled <- committed[committed$model %in% paste0(ids, "_rtscreen"), ]
screened <- function(rows = reported) { rows$model <- paste0(rows$model, "_rtscreen"); rows }
.rt_tbl    <- data.frame(n_valid_trials = 41184, n_kept = 41181, n_rt_excluded = 3)
.rt_tbl_sc <- data.frame(n_valid_trials = 41184, n_kept = 33022, rt_min_ms = 200, rt_max_ms = 4000)
n_contrasts <- sum(reported$contrast != "value")
post_rep <- utils::read.csv(here::here("paper_1_transfer", "results", "_pooled_posterior_summaries.csv"),
                            stringsAsFactors = FALSE)
post_rep <- post_rep[post_rep$model %in% ids, ]
post_tbl <- NULL

# --- rt_screen_sentence() --------------------------------------------------------
sdt_tbl <- reported
ok(has(rt_screen_sentence(), "pending"), "the refits missing print the pending marker")

sdt_tbl <- rbind(reported, screened())
s <- rt_screen_sentence()
ok(has(s, "On the 33,022 judgement trials the screen keeps (8,159 fewer)"),
   "the sentence gives the screened sample and what the screen removes")
ok(has(s, sprintf("the %d signal-detection contrasts", n_contrasts)) &&
     has(s, "all kept their credibility."), "identical refits keep every contrast's credibility")
ok(has(s, "criteria averaged over sessions was $\\Delta =") && has(s, "without it."),
   "the gender criterion difference is reported from the screened refit, beside the reported one")
ok(!has(s, "population-level"), "without the pooled summaries the term clause is left out")
post_tbl <- rbind(post_rep, transform(post_rep, model = paste0(model, "_rtscreen")))
ok(has(rt_screen_sentence(), sprintf("None of the %d population-level terms", nrow(post_rep))),
   "identical terms are reported as unchanged")
pt <- post_tbl; j <- which(pt$model == "accuracy_gender_agreement_rtscreen" &
                             (pt$ci_low > 0 | pt$ci_high < 0))[1]
pt$ci_low[j] <- -abs(pt$ci_high[j]); post_tbl <- pt
ok(has(rt_screen_sentence(), "One of the"), "a term that changes is counted")
post_tbl <- NULL

# One credible contrast loses its credibility, and one that was not credible gains it.
cr <- function(d) d$ci_low > 0 | d$ci_high < 0
sc <- screened()
i_lose <- which(sc$contrast != "value" & cr(sc))[1]
i_gain <- which(sc$contrast != "value" & !cr(sc))[1]
sc$ci_low[i_lose] <- -0.01; sc$ci_high[i_lose] <- abs(sc$ci_high[i_lose])
w <- sc$ci_high[i_gain] - sc$ci_low[i_gain]
sc$ci_low[i_gain] <- 0.02; sc$ci_high[i_gain] <- 0.02 + w
sdt_tbl <- rbind(reported, sc)
s <- rt_screen_sentence()
ok(has(s, "kept their credibility in all but two") && has(s, "ceased to be credible") &&
     has(s, "became credible"), "a contrast that changes either way is named")
ok(has(s, "credible, and the") && !has(s, "; and"), "two changed contrasts are joined by a comma and 'and'")
ok(has(s, "by no more than"), "the sentence bounds the margin of the changed contrasts")

# The screened sample must be the reported trials less those the screen removes.
sdt_tbl <- rbind(reported, screened())
.rt_tbl_sc$n_kept <- 41181
ok(has(rt_screen_sentence(), "[Check:"), "a screened sample no smaller than the reported one is flagged")
.rt_tbl_sc$n_kept <- 33022; .rt_tbl_sc$n_valid_trials <- 41000
ok(has(rt_screen_sentence(), "[Check:"), "a different count of valid trials is flagged")
.rt_tbl_sc$n_valid_trials <- 41184

# --- Strength of evidence, the misanalysis concession and the opening clause --------
sdt_tbl <- rbind(reported, screened_pulled)
p <- rtscreen_weight_paragraph()
ok(!has(p, "[Check:") && !has(p, "pending"), "the expected pattern fits the paragraph")
ok(has(p, "for gender agreement at Sessions 3, 4 and 6") && has(p, "the six results") &&
     has(p, "the criterion difference at Session 3, credible only with the screen") &&
     has(p, "lower sensitivity at Session 6, credible only without it") &&
     has(p, "between Sessions 2 and 6 for gender agreement, credible only without it") &&
     has(p, "larger at every session") &&
     has(p, "Each interval excluded zero, in the fit that supports it, by no more than") &&
     has(p, "and four of them by less than two Monte Carlo standard errors of that bound") &&
     has(p, "The gender-agreement sensitivity differences run against") &&
     has(p, "Those for differential object marking concern a property absent"),
   "the paragraph names every contrast the screen decides, the screen once")
ok(lengths(regmatches(p, gregexpr("the screen (", p, fixed = TRUE))) == 1L,
   "the screen is named in the first item only")
ok(sens_difference_concession() ==
     "which was credible only at Session 6, and not in the refit with the reaction-time screen",
   "with the screened refit alone, the concession says the difference is credible only without the screen")
ok(sens_gender_clause() ==
     "the Mini-Norwegian group was credibly less sensitive to gender agreement only at Session 6",
   "the Discussion's opening clause gives the session and the direction")
ok(sdt_claims_guard() == "", "the typed claims of the abstract, Discussion and Conclusion hold")
sdt_tbl <- reported
ok(has(rtscreen_weight_paragraph(), "pending"), "the paragraph is pending without the refits")
ok(sens_difference_concession() == "which was credible only at Session 6",
   "without the screened refit the concession names only the session")
sdt_tbl <- rbind(reported, screened())
ok(has(rtscreen_weight_paragraph(), "[Check:"),
   "identical refits leave the pattern (nothing changes, nothing grows) and are flagged")
ok(sens_difference_concession() ==
     "which was credible only at Session 6, in the reported fit and in every refit",
   "a sensitivity difference credible in every refit is said to be")
# A gender sensitivity difference credible in the Mini-Norwegian group's favour is flagged.
rp <- reported
k <- rp$measure == "sensitivity" & rp$contrast == "language_difference" &
  rp$model == "accuracy_gender_agreement" & rp$session == "2"
rp$median[k] <- 1; rp$ci_low[k] <- 0.1; rp$ci_high[k] <- 2
sdt_tbl <- rbind(rp, screened_pulled)
ok(has(sens_difference_concession(), "[Check:"), "a credible Mini-Norwegian advantage is flagged")
ok(has(rtscreen_weight_paragraph(), "[Check:"), "and the paragraph flags it too")
ok(has(sens_gender_clause(), "[Check:"), "and the opening clause flags it too")
ok(has(sdt_claims_guard(), "credibly more sensitive"), "and the claims guard names it")

# --- The refit with the added slope and the differential-object-marking sentences ----
LES_ERP_SESSIONS <- c(2, 3, 4, 6)
sdt_tbl <- committed
ok(maxranef_claims_guard() == "", "the typed claims about the refit with the added slope hold")
ok(crit_maxranef_shift() == "0.06", "the largest shift of the criterion difference is rounded up")
d <- crit_direction_clause()
ok(has(d, "at least .96 in each") && has(d, "more liberal at Sessions 4 and 6"),
   "the direction clause gives the lowest probability over every fit, floored")
t <- committed
k <- t$model == "accuracy_gender_agreement" & t$measure == "sensitivity" &
  t$contrast == "change_s4_to_s6_language_difference"
t$ci_high[k] <- -0.00004; sdt_tbl <- t
ok(has(report_sdt("gender_agreement", "sensitivity", "change_s4_to_s6_language_difference", "4->6"),
       ", -0.0000]$"), "a bound within rounding of zero keeps its sign")
sdt_tbl <- committed
ok(has(dom_edge_clause(), "Its interval included zero, as it did in the refit with the added slope ("),
   "the differential-object-marking sentence says every interval includes zero")
ok(dom_sens_guard() == "", "the Discussion's differential-object-marking clause holds")
ok(sens_difference_concession() == paste0(
     "which was credible only at Session 6, and not in three of the six refits (with the ",
     "reaction-time screen, with the diversity covariate and with both the added slope and the ",
     "by-item term)"),
   "over every refit, the concession names the three in which the Session 6 difference is not credible")
m <- sdt_mcse_sentence()
ok(grepl("^For the signal-detection contrasts, the Monte Carlo standard error of an interval bound had a median of 0\\.0[0-9]{2} and a maximum of 0\\.0[0-9]{2} on the logit scale\\.$", m),
   "the Monte Carlo sentence gives the median and largest standard error of the bounds")
sdt_tbl <- committed[, setdiff(names(committed), c("mcse_low", "mcse_high"))]
ok(has(sdt_mcse_sentence(), "pending"), "without the standard errors the sentence is a marker")
sdt_tbl <- committed
# Each typed claim fails on its own when the estimates move.
mx <- function(t, session, contrast = "language_difference") {
  t$model == "accuracy_gender_agreement_maxranef" & t$measure == "criterion" &
    t$contrast == contrast & t$session == session
}
t <- committed; t$ci_high[mx(t, "6")] <- -0.01; sdt_tbl <- t
ok(has(maxranef_claims_guard(), "credible at some session with the added slope"),
   "a criterion difference credible at a session with the slope is named")
t <- committed; t$ci_high[mx(t, "2->6", "change_first_to_last_language_difference")] <- -0.01
sdt_tbl <- t
ok(has(maxranef_claims_guard(), "no longer credible only in the reported fit"),
   "growth credible with the slope is named")
t <- committed
k <- t$model == "accuracy_gender_agreement_weakprior" & t$measure == "criterion" &
  t$contrast == "language_difference" & t$session == "6"
t$median[k] <- 0.1; sdt_tbl <- t
ok(has(crit_direction_clause(), "[Check:") &&
     has(maxranef_claims_guard(), "no longer has the Mini-Norwegian criterion as the more liberal"),
   "a fit with the difference the other way is flagged in the clause and named by the guard")
t <- committed
k <- t$model == "accuracy_differential_object_marking" & t$measure == "sensitivity" &
  t$contrast == "change_first_to_last_language_difference" & t$session == "3->6"
t$ci_low[k] <- 0.01; sdt_tbl <- t
ok(has(dom_sens_guard(), "[Check:") && has(dom_edge_clause(), "Its interval excluded zero, and it included"),
   "a credible differential-object-marking contrast is flagged and the sentence follows it")

# --- The Method's account of the legacy screen --------------------------------------
bands <- expand.grid(grammatical_property = names(LES_P1_PROPERTIES)[1],
                     mini_language = c("Mini-English", "Mini-Norwegian"), session = 2,
                     grammaticality = "Grammatical", band = c("fast", "kept", "slow"),
                     stringsAsFactors = FALSE)
bands$n_trials <- c(500, 300, 3000, 3000, 500, 300)
bands$n_correct <- round(bands$n_trials * c(.9, .9, .8, .8, .7, .7))
.rt_bands <- bands
.rt_tbl$n_kept <- sum(bands$n_trials); .rt_tbl_sc$n_kept <- 6000
s <- rt_legacy_sentence()
ok(has(s, "200 ms or less or of 4,000 ms or more") && has(s, "a further 1,600 trials") &&
     has(s, "90.0% correct") && has(s, "70.0%") && has(s, "80.0% for the judgements"),
   "the Method gives the bounds, the trials the screen removes and each band's accuracy")
ok(has(s, "25.0% of the Mini-English group's") && has(s, "16.7% of the Mini-Norwegian") &&
     has(s, "(12.5% against 8.3%)"),
   "the Method gives the two groups' shares and their fast responses")
.rt_tbl_sc$n_kept <- 5999
ok(has(rt_legacy_sentence(), "[Check:"), "bands that do not add up to the extractions are flagged")
# More of the Mini-Norwegian group's fast responses, with the counts still adding up.
.rt_bands$n_trials[.rt_bands$mini_language == "Mini-Norwegian" & .rt_bands$band == "fast"] <- 600
.rt_bands$n_trials[.rt_bands$mini_language == "Mini-Norwegian" & .rt_bands$band == "kept"] <- 2900
.rt_tbl$n_kept <- sum(.rt_bands$n_trials)
.rt_tbl_sc$n_kept <- sum(.rt_bands$n_trials[.rt_bands$band == "kept"])
s <- rt_legacy_sentence()
ok(has(s, "[Check:") && has(s, "group imbalance"), "a fast-response imbalance the other way is flagged")

cat("\nAll reaction-time-screen prose checks passed.\n")
