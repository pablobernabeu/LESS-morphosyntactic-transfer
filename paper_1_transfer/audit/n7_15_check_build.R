# N7, step 15: does the rebuilt cell data match the fitted models' row and participant counts?
# A check on the precision projection's data build (gaps/gap1/02_check_build.R, moved here with only
# its paths changed). Reference: the 20 August 2026 fits' metadata (gender midline n_obs 37,827,
# lateral 75,654, 62 participants). Writes eeg_audit/precision/02_check_build.txt. Runtime: a minute.
source(here::here("paper_1_transfer", "audit", "precision_common.R"))
cov <- participant_covariates()
tr <- read_trials()
sink(file.path(G1, "02_check_build.txt"), split = TRUE)
cat("participants in key:", nrow(cov), "; with an L1-dominance score:", sum(!is.na(cov$mld)), "\n")
cat("exported gender S101/S102 segments (all participants, before exclusions):",
    nrow(tr[region == "midline medial"]), "\n")
for (variant in c("stale", "current")) for (macro in c("midline", "lateral")) {
  d <- build_cell(tr, cov, "w400_900", macro, variant)
  cat(sprintf("%-7s %-7s rows %6d | participants %2d | items %3d | merged duplicate-marker rows %d | trials %d\n",
              variant, macro, nrow(d), uniqueN(d$pid), uniqueN(d$item), sum(d$n_seg > 1),
              uniqueN(d$trial)))
  if (macro == "midline") {
    cell <- d[, .(n = uniqueN(trial)), by = .(pid, session, g)]
    cat(sprintf("        trials per participant x session x condition: mean %.2f, SD %.2f, cells %d\n",
                mean(cell$n), sd(cell$n), nrow(cell)))
    print(d[, .(participants = uniqueN(pid), trials = uniqueN(trial)), by = .(session)][order(session)])
    print(d[, .(participants = uniqueN(pid)), by = mini_language])
    cat("participants without L1 dominance among exported (dropped):",
        paste(setdiff(unique(tr$pid), as.integer(as.character(unique(d$pid)))), collapse = " "), "\n")
    cat("SD of standardised-predictor codes (raw +/-0.5 codes): g", attr(d, "scaling")$g[2],
        " l", attr(d, "scaling")$l[2], " s", attr(d, "scaling")$s[2], "\n")
  }
}
sink()
