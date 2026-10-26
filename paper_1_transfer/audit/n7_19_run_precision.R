# N7, step 19: run every fit and projection of the precision projection, one R process at a time.
#
# On 17 September 2026 this was four PowerShell batch files (gaps/gap1/06_run_batch.ps1, 06b, 06c
# and 06d), run partly in parallel; this script runs the same fits and projections with the same
# arguments and seeds, sequentially, so that one machine's memory holds one fit at a time. A fit
# whose .rds exists is not refitted, and a tag already in projection.csv is not projected again, so
# an interrupted run resumes where it stopped.
#
#   calibration  stale sample, structures max and base, 3 windows x 2 macroregions (fits only)
#   current      structures max, base, gs, trial and gstrial, 3 windows x 2 macroregions,
#                each fitted (n7_16_fit_one.R) and projected (n7_18_project.R)
#   thinning     midline 400-900, structures max and gs, 2/3 and 1/2 of the trials, seeds 1-3;
#                structures trial and gstrial, 2/3 of the trials, seed 1
#
# Needs n7_14_gender_trials.py and n7_17_lag_counts.R to have run. Writes eeg_audit/precision/fits/
# and projection.csv, and logs each call to 19_run_log.txt.
# Runtime: a few hours. The 56 fits took about an hour in all on 17 September 2026, the
# lateral trial and gstrial fits longest; the projections of the current fits take longer.
source(here::here("paper_1_transfer", "audit", "audit_paths.R"))
G1 <- audit_dir("precision")
HERE <- file.path(AUDIT_CODE_ROOT, "paper_1_transfer", "audit")
RSCRIPT <- file.path(R.home("bin"), "Rscript")
LOG <- file.path(G1, "19_run_log.txt")

run <- function(script, args) {
  cat("===", script, paste(args, collapse = " "), "\n", file = LOG, append = TRUE)
  out <- system2(RSCRIPT, c("--vanilla", shQuote(file.path(HERE, script)), args), stdout = TRUE, stderr = TRUE)
  cat(out, sep = "\n", file = LOG, append = TRUE)
  status <- attr(out, "status")
  if (!is.null(status) && status != 0) cat("    exit status", status, "\n", file = LOG, append = TRUE)
}
tag_of <- function(w, m, v, s, thin = NULL, seed = NULL) {
  tag <- paste(w, m, v, s, sep = "_")
  if (!is.null(thin)) tag <- paste0(tag, "_thin", thin, "_seed", seed)
  tag
}
fit <- function(w, m, v, s, thin = NULL, seed = NULL) {
  if (!file.exists(file.path(G1, "fits", paste0(tag_of(w, m, v, s, thin, seed), ".rds"))))
    run("n7_16_fit_one.R", c(w, m, v, s, thin, seed))
}
projected <- function(tag) {
  fn <- file.path(G1, "projection.csv")
  file.exists(fn) && any(data.table::fread(fn, select = "tag")$tag == tag)
}
project <- function(tag) if (!projected(tag)) run("n7_18_project.R", tag)

wins <- c("w200_500", "w300_600", "w400_900")
macros <- c("midline", "lateral")
for (m in macros) for (w in wins) for (s in c("max", "base")) fit(w, m, "stale", s)
for (m in macros) for (w in wins) for (s in c("max", "base", "gs", "trial", "gstrial")) {
  fit(w, m, "current", s)
  project(tag_of(w, m, "current", s))
}
for (seed in 1:3) for (thin in c("0.6667", "0.5")) for (s in c("max", "gs")) {
  fit("w400_900", "midline", "current", s, thin, seed)
  project(tag_of("w400_900", "midline", "current", s, thin, seed))
}
for (s in c("trial", "gstrial")) {
  fit("w400_900", "midline", "current", s, "0.6667", 1)
  project(tag_of("w400_900", "midline", "current", s, "0.6667", 1))
}
cat("=== done\n", file = LOG, append = TRUE)
