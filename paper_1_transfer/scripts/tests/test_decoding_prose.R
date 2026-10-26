# =============================================================================
# paper_1_transfer/scripts/tests/test_decoding_prose.R
# -----------------------------------------------------------------------------
# Checks the helpers that compute the decoding section's prose in
# paper_1_morphosyntax.qmd (the Results paragraph on the two correction layers, the
# appendix guard, the Discussion's three statements about gender agreement's
# separability and the robustness sentence) on synthetic confirmatory time-courses, one
# per case: no cluster, one cluster that does not pass, the pattern reported on 11
# October 2026 (four clusters passing the maximum-cluster test and none the second
# layer), one cluster at the permutation floor among many, one survivor beside a cluster
# that passes the first test only, two survivors, a surviving pre-stimulus cluster and a
# missing robustness arm. It also checks the gate that holds a property's run as
# unfinished until its temporal-generalization file is present.
#
# The helpers are taken from the manuscript itself: knitr::purl() extracts its R code, and
# only the named function definitions are evaluated, so nothing is rendered and no
# results file is read. The results folder is a fresh one under tempdir().
#
# Run from the project root:
#   Rscript --vanilla paper_1_transfer/scripts/tests/test_decoding_prose.R
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  # The property labels the helpers name, and apa_num().
  source(here::here("_shared", "R", "03_data_manifest.R"))
  source(here::here("_shared", "R", "06_manuscript_helpers.R"))
})

ok <- function(cond, msg) {
  if (!isTRUE(cond)) stop("FAIL: ", msg, call. = FALSE)
  cat("PASS:", msg, "\n")
}
has <- function(x, pattern) grepl(pattern, x, fixed = TRUE)

# --- The helpers, from the manuscript ----------------------------------------
code <- file.path(tempdir(), "paper_1_morphosyntax_purl.R")
invisible(suppressMessages(knitr::purl(here::here("paper_1_transfer", "paper_1_morphosyntax.qmd"),
                                       output = code, documentation = 0, quiet = TRUE)))
want <- c("decode_summary", ".decode_run_done", ".decode_runs_pending_props",
          ".decode_runs_pending_txt", ".dec_num_word", ".dec_and", ".dec_ms", ".dec_fwer_p_txt",
          ".dec_p3", "dec_fwer_spans", "dec_layers_sentence", "dec_m_sentence",
          "dec_prestim_guard", ".dec_rob_counts", "dec_robust_sentence", "dec_appx_guard",
          ".dec_gender_state", "dec_gender_sep_phrase", "dec_gender_profile_sentence",
          "dec_gender_grade_sentence", "dec_count", "dec_val", "dec_fdr_spans", "dec_span",
          "dec_min_p", "xprop_max", "xprop_max_pair", "dec_tgm_sentence")
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
.decode_props <- LES_PROPERTY_LABELS
res_dir <- file.path(tempdir(), "p1_decoding_prose_results")
unlink(res_dir, recursive = TRUE); dir.create(res_dir)
paper1_results <- function(f) file.path(res_dir, f)
decode_ready <- TRUE
decode_provisional <- function() FALSE

# A confirmatory overall time-course on the decoding grid (-98 to 1098 ms in 4 ms steps).
# Each cluster is c(start, end, cluster-level p); the second layer is applied as 09b does,
# Benjamini-Hochberg over the property's clusters.
times <- seq(-98, 1098, 4)
mk <- function(cl = list()) {
  d <- data.frame(time_ms = times, auc = 0.5, cluster_id = NA_integer_, cluster_p = NA_real_,
                  n_perm = 1000L, analysis = "overall", level = "all", inference = "confirmatory")
  for (k in seq_along(cl)) {
    i <- d$time_ms >= cl[[k]][1] & d$time_ms <= cl[[k]][2]
    d$cluster_id[i] <- k; d$cluster_p[i] <- cl[[k]][3]; d$auc[i] <- .53
  }
  u <- unique(d[!is.na(d$cluster_id), c("cluster_id", "cluster_p")])
  u$q <- p.adjust(u$cluster_p, "BH")
  d$cluster_p_fdr <- u$q[match(d$cluster_id, u$cluster_id)]
  d$significant_fdr <- !is.na(d$cluster_p_fdr) & d$cluster_p_fdr < .05
  d
}
# Gender agreement varies by case. Differential object marking keeps one surviving
# pre-stimulus cluster at the floor, and verb-object agreement none.
run <- function(g, rob = list(mk(), mk(), mk())) {
  decode_tc <<- list(gender_agreement = g,
                     differential_object_marking = mk(list(c(-98, -62, 1/1001))),
                     verb_object_number_agreement = mk())
  decode_gen <<- list(gender_agreement = NULL, differential_object_marking = NULL,
                      verb_object_number_agreement = data.frame(auc = .5))
  decode_tc_rob <<- setNames(rob, names(.decode_props))
  dec_gender <<- decode_summary("gender_agreement")
  dec_dom <<- decode_summary("differential_object_marking")
  dec_verb <<- decode_summary("verb_object_number_agreement")
  list(layers = dec_layers_sentence(dec_gender, "gender_agreement"), m = dec_m_sentence(),
       appx = dec_appx_guard(), state = .dec_gender_state(), sep = dec_gender_sep_phrase(),
       grade = dec_gender_grade_sentence(), robust = dec_robust_sentence())
}

# --- Cases -------------------------------------------------------------------
o <- run(mk())
ok(identical(o$layers, " No sample of its time-course exceeded the cluster-forming threshold."),
   "no cluster: the layers sentence says no sample crossed the threshold")
ok(o$state == "none" && o$sep == "no detectable pattern separability" &&
     has(o$grade, "has no cluster passing either correction layer"),
   "no cluster: the Discussion grades gender agreement as not separable")
ok(o$m == "" && has(o$appx, "[Check:"),
   "no cluster: no m sentence, and the appendix guard asks for a revision")

o <- run(mk(list(c(500, 520, .4))))
ok(has(o$layers, "Its one cluster did not pass the maximum-cluster test either (cluster-level $p = .400$)."),
   "one cluster that does not pass: named with its p value")
ok(o$state == "none", "one cluster that does not pass: state none")

# The pattern reported on 11 October 2026: four clusters pass the maximum-cluster test,
# thirteen do not, and the second layer removes them all.
o <- run(mk(c(list(c(378, 418, .00899), c(438, 474, .00599), c(534, 602, .03), c(950, 1062, .003)),
              lapply(1:13, function(i) c(90 + i * 8, 92 + i * 8, .7)))))
ok(has(o$layers, paste0("Of its 17 clusters, four passed the maximum-cluster test on its own ",
                        "(378 to 418 ms, 438 to 474 ms, 534 to 602 ms and 950 to 1062 ms, with ",
                        "cluster-level $p$ from .003 to .030), but the second layer removed them all, ",
                        "the smallest adjusted value being $q = .051$.")),
   "reported pattern: extents, p range and smallest q")
ok(identical(o$m, " With its 17 confirmatory clusters, the smallest cluster-level $p = .003$ becomes $q = .051$."),
   "reported pattern: the m sentence")
ok(o$appx == "", "reported pattern: the appendix guard is silent")
ok(o$state == "first" && has(o$sep, "which we grade as suggestive"),
   "reported pattern: graded suggestive")
ok(has(o$grade, "although four clusters, and none in the robustness analysis, passed the maximum-cluster test") &&
     has(o$grade, "Its pre-stimulus baseline sat at chance"),
   "reported pattern: the grade sentence counts both analyses")
ok(has(o$robust, "(four, one and zero in the primary analysis)") && has(o$robust, "[Check:"),
   "reported pattern: a robustness arm that differs is flagged")

o <- run(mk(c(list(c(400, 420, 1/1001)), lapply(1:59, function(i) c(-98 + i * 8, -96 + i * 8, .9)))))
ok(has(o$layers, "Of its 60 clusters, one passed the maximum-cluster test on its own (402 to 418 ms, with cluster-level $p < .001$), but the second layer removed it, the smallest adjusted value being $q = .060$."),
   "one floor cluster among 60: singular wording and p < .001")
ok(has(o$m, "the smallest cluster-level $p < .001$ becomes $q = .060$"),
   "one floor cluster among 60: the m sentence")

# One survivor (q = .003) beside a cluster that passes the first test only (p = .045,
# q = .0675) and one that passes neither.
o <- run(mk(list(c(400, 420, 1/1001), c(600, 640, .045), c(800, 820, .9))))
ok(has(o$layers, "It spans 402 to 418 ms.") &&
     has(o$layers, "A further cluster passed the maximum-cluster test but not the second layer (602 to 638 ms, with cluster-level $p = .045$)."),
   "one survivor plus a first-test-only cluster: both named")
ok(o$state == "both" && o$sep == "reliable pattern separability",
   "one survivor plus a first-test-only cluster: graded reliable")
ok(has(o$appx, "[Check:"), "one survivor: the appendix guard asks for a revision")

o <- run(mk(list(c(400, 420, 1/1001), c(600, 640, 1/1001))))
ok(identical(o$layers, " They span 402 to 418 ms and 602 to 638 ms."), "two survivors: both extents")
ok(has(o$grade, "Gender agreement's two clusters surviving the confirmatory correction rest on"),
   "two survivors: plural grade sentence")
ok(!has(o$grade, "[Check:"), "two survivors after onset: no pre-stimulus marker")

o <- run(mk(list(c(-18, 40, 1/1001))))
ok(identical(o$layers, " It spans $-18$ to 38 ms."),
   "pre-stimulus survivor: the negative time is set in math mode")
ok(has(o$grade, "[Check: a cluster that passes the maximum-cluster test now reaches into the pre-stimulus interval"),
   "pre-stimulus survivor: the grade sentence is flagged")
ok(identical(unname(dec_span("differential_object_marking", 1)), "$-98$ to $-62$ ms"),
   "dec_span(): both negative times in math mode")

o <- run(mk(list(c(400, 420, .01))), rob = list(NULL, mk(), mk()))
ok(has(o$robust, "will be reported here once all three properties have run"),
   "missing robustness arm: pending marker")

# --- The run-done gate ----------------------------------------------------------
ok(!.decode_run_done("verb_object_number_agreement") &&
     .decode_runs_pending_txt() == "gender agreement, differential object marking and verb--object number agreement",
   "a run without its temporal-generalization file is unfinished")
invisible(file.create(paper1_results("verb_object_number_agreement_decoding_temporal_generalization.csv")))
ok(.decode_run_done("verb_object_number_agreement") &&
     .decode_runs_pending_txt() == "gender agreement and differential object marking",
   "the temporal-generalization file finishes the run")

ok(.dec_num_word(NA) == "NN" && .dec_num_word(4L) == "four" && .dec_num_word(17L) == "17",
   ".dec_num_word(): words below ten, digits above, the NN placeholder for NA")

# --- The temporal-generalisation description -----------------------------------
# A synthetic matrix on the 8 ms grid of 09's matrices, built to the pattern the sentences
# describe: decoders from the first third of the baseline below chance on its last third
# (the reversal that baseline subtraction produces), the last third's pattern carried into
# the first 100 ms, a sustained block from 200 ms, and the last third of the baseline at
# chance on that block. Each case rewrites the one file the helper reads.
tg <- expand.grid(train_time_ms = seq(-98, 1094, 8), test_time_ms = seq(-98, 1094, 8))
tgm <- function(rev = 0.44, carry = 0.53, late = 0.54, cross = 0.50) {
  tr <- tg$train_time_ms; te <- tg$test_time_ms
  first_bl <- tr > -100 & tr < -65; last_bl <- function(x) x > -35 & x < 0
  d <- tg; d$auc <- 0.5
  d$auc[first_bl & last_bl(te)] <- rev
  d$auc[last_bl(tr) & te > 0 & te <= 100] <- carry
  d$auc[tr >= 200 & te >= 200] <- late
  d$auc[last_bl(tr) & te >= 200] <- cross
  utils::write.csv(d, paper1_results("differential_object_marking_decoding_temporal_generalization.csv"),
                   row.names = FALSE)
}
ok(identical(dec_tgm_sentence("differential_object_marking"), ""), "no matrix: no sentence")
tgm()
s <- dec_tgm_sentence("differential_object_marking")
ok(!has(s, "[Check") && has(s, "last third at a mean AUC of 0.44, below chance") &&
     has(s, "first 100 ms after onset at 0.53") && has(s, "that span at 0.54") &&
     has(s, "classified it at 0.50.") && has(s, "cannot attribute that later pattern"),
   "the described pattern: the sentences, their numbers and the limit they state")
tgm(rev = 0.50)
ok(has(dec_tgm_sentence("differential_object_marking"), "[Check:"),
   "no reversal within the baseline: a marker")
tgm(carry = 0.50)
ok(has(dec_tgm_sentence("differential_object_marking"), "[Check:"),
   "no carry-over across onset: a marker")
tgm(cross = 0.53)
ok(has(dec_tgm_sentence("differential_object_marking"), "[Check:"),
   "the baseline pattern generalising to the late block: a marker")
real_tgm <- here::here("paper_1_transfer", "results",
                       "differential_object_marking_decoding_temporal_generalization.csv")
if (file.exists(real_tgm)) {
  file.copy(real_tgm, paper1_results(basename(real_tgm)), overwrite = TRUE)
  s <- dec_tgm_sentence("differential_object_marking")
  ok(!has(s, "[Check") && has(s, "mean AUC of 0.44") && has(s, "after onset at 0.52") &&
       has(s, "that span at 0.54") && has(s, "classified it at 0.50."),
     "the committed DOM matrix gives the sentences of 15 October 2026")
}
unlink(res_dir, recursive = TRUE)
cat("\nAll decoding-prose checks passed.\n")
