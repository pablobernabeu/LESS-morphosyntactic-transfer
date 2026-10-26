# N7, step 17: per participant x session x condition, how many gender-agreement trials a
# lag-tolerant re-export (option D) would add, from the raw .vmrk marker streams.
# Written on 17 September 2026 as gaps/gap1/04_lag_counts.R; moved here with only its paths changed.
# Inputs: eeg_audit/precision/raw_lag_events.csv.gz (n7_14), the rebuilt "current" cell.
# Output: eeg_audit/precision/lag_counts_current.csv, lag6_items.csv, 04_lag_counts.txt. Runtime: a minute.
source(here::here("paper_1_transfer", "audit", "precision_common.R"))
sink(file.path(G1, "04_lag_counts.txt"), split = TRUE)
ev <- fread(file.path(G1, "raw_lag_events.csv.gz"))
ev <- ev[prop == "S1" & condition %in% c("S101", "S102")]
cat("raw S1 S101/S102 events, all participant-sessions:", nrow(ev), "\n")
print(ev[, .N, by = lag][order(lag)][, share := round(100 * N / sum(N), 2)][])
raw <- ev[, .(n_raw = .N, n5 = sum(lag == 5), n6 = sum(lag == 6), n_other = sum(!lag %in% 5:6),
              raw_files = uniqueN(raw_file)), by = .(pid = participant, session, condition)]

d <- build_cell(read_trials(), participant_covariates(), "w400_900", "midline", "current")
cur <- unique(d[, .(pid = as.integer(as.character(pid)), session, condition, trial)])[
  , .(n_cur = .N), by = .(pid, session, condition)]
m <- merge(cur, raw, by = c("pid", "session", "condition"), all.x = TRUE)
m[is.na(n_raw), `:=`(n_raw = 0L, n5 = 0L, n6 = 0L, n_other = 0L, raw_files = 0L)]
m[, ratio_exported_to_lag5 := n_cur / n5]
cat("\nanalysed cells (participant x session x condition):", nrow(m), "\n")
cat("cells with no raw S1 condition markers found:", sum(m$n5 == 0), "\n")
print(m[n5 == 0])
cat("cells where analysed trials exceed raw lag-5 events (export not explained by lag-5 rule):",
    sum(m$n_cur > m$n5 & m$n5 > 0), "\n")
print(m[n_cur > n5 & n5 > 0])
cat("cells with more than one raw .vmrk:", sum(m$raw_files > 1), "\n")
ok <- m[n5 > 0 & n_cur <= n5]
cat(sprintf("\nexported/lag-5 ratio over well-matched cells: median %.3f, mean %.3f, total %.4f\n",
            median(ok$ratio_exported_to_lag5), mean(ok$ratio_exported_to_lag5), sum(ok$n_cur) / sum(ok$n5)))
glob <- sum(ok$n_cur) / sum(ok$n5)
# Option D keeps lag-5 and lag-6 events; assume lag-6 events lose the same share to hand
# removal as lag-5 events did in that cell (or the global share where the cell is unmatched).
m[, n_D := n_cur + round(n6 * fifelse(n5 > 0 & n_cur <= n5, n_cur / pmax(n5, 1), glob))]
m[n5 == 0, n_D := round(n_cur * mean(ok[, (n5 + n6) / n5]))]
cat(sprintf("trials per analysed cell: current mean %.2f (SD %.2f); under D mean %.2f (SD %.2f); ratio of totals %.4f\n",
            mean(m$n_cur), sd(m$n_cur), mean(m$n_D), sd(m$n_D), sum(m$n_D) / sum(m$n_cur)))
cat(sprintf("presented-trial ceiling: raw events per cell mean %.2f\n", mean(m$n_raw)))
print(m[, .(cur = mean(n_cur), D = mean(n_D), raw = mean(n_raw)), by = session][order(session)])
fwrite(m, file.path(G1, "lag_counts_current.csv"))
# Items of lag-6 events, for assigning recovered trials to their actual sentence frames.
fwrite(ev[lag == 6, .(pid = participant, session, condition, sentence)], file.path(G1, "lag6_items.csv"))
sink()
