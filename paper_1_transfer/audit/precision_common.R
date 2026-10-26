# Shared helpers of the precision projection (n7_15 to n7_20): build the gender-agreement ERP cell
# data the way the pipeline did on 17 September 2026 (paper_1_transfer/scripts/01_extract_erp_single_trials.R,
# 03_fit_brms_erp.R, _config.R and the legacy importer/merger in data/R_functions), starting from
# gender_trials.csv.gz, which n7_14_gender_trials.py computes from the primary Analyzer exports.
# Written as gaps/gap1/gap1_common.R; moved here with only its paths changed.
#
# Two sample variants:
#   "stale"   : the sample of the 20 Aug 2026 fits whose posterior summaries were the only brms
#               summaries on disk on 17 September: 4 mis-filtered S3 sets (7, 8, 9, 16) dropped, no
#               invalid-export or P14 exclusion, no Session-2 reference correction. Used only to
#               calibrate lme4 standard errors against brms posterior SDs (n7_20).
#   "current" : the sample the manuscript described on 17 September: 9 mis-filtered S3 sets, 3 invalid
#               exports (48/S3, 5/S6, 7/S2) and participant 14 dropped; Session 2 brought to linked
#               mastoids by c + FCz/2 (since replaced by the correction of ISSUES.md N8).
suppressPackageStartupMessages({
  library(data.table)
  library(lme4)
  library(Matrix)
})

source(here::here("paper_1_transfer", "audit", "audit_paths.R"))
G1 <- audit_dir("precision")
DATA <- audit_data_root()

MIS_STALE   <- data.table(pid = c(7L, 8L, 9L, 16L), session = 3L)
MIS_CURRENT <- data.table(pid = c(7L, 8L, 9L, 16L, 53L, 60L, 61L, 62L, 65L), session = 3L)
INVALID     <- data.table(pid = c(48L, 5L, 7L), session = c(3L, 6L, 2L))
MIDLINE <- c("midline anterior", "midline medial", "midline posterior")

.zs <- function(x) { s <- sd(x, na.rm = TRUE); if (is.na(s) || s == 0) rep(0, length(x)) else as.numeric(scale(x)) }

participant_covariates <- function() {
  key <- fread(file.path(DATA, "Participant IDs and session progress.csv"))
  key <- key[, .(pid = as.integer(participant_lab_ID), participant_LHQ3_ID, mini_language = language)]
  agg <- suppressMessages(readxl::read_excel(file.path(DATA, "raw data/language history/LHQ3 Aggregate Scores.xlsx"),
                                             sheet = "Sheet1", col_names = FALSE, skip = 1))[-1, ]
  agg <- data.table(participant_LHQ3_ID = agg[[1]], mld = suppressWarnings(as.numeric(agg[[14]])))
  raw <- suppressMessages(readxl::read_excel(file.path(DATA, "raw data/language history/LHQ3 Raw Data.xlsx"),
                                             sheet = "Sheet1", col_names = FALSE, skip = 1))
  raw_ids <- raw[[1]][-(1:2)]
  # Legacy: merge(LHQ3 raw, aggregate) is an inner join, so a score needs both files.
  agg <- agg[participant_LHQ3_ID %in% raw_ids]
  # Legacy left_join is many-to-many; report duplicates rather than silently multiplying rows.
  dup <- agg[duplicated(participant_LHQ3_ID)]
  if (nrow(dup)) message("duplicate LHQ3 ids in aggregate scores: ", paste(dup$participant_LHQ3_ID, collapse = ", "))
  merge(key, unique(agg, by = "participant_LHQ3_ID"), by = "participant_LHQ3_ID", all.x = TRUE)
}

read_trials <- function() {
  d <- fread(file.path(G1, "gender_trials.csv.gz"))
  setnames(d, "participant", "pid")
  d[, marker := as.character(marker)]
  d
}

# One cell (window x macroregion) in one sample variant, following .les_summarise_cells().
build_cell <- function(trials, cov, window = "w400_900", macro = "midline", variant = "current") {
  d <- trials[if (macro == "midline") region %in% MIDLINE else !(region %in% MIDLINE)]
  fz <- sub("^w", "fcz_", window)
  d <- d[, .(pid, session, condition, seg, marker, region, base, amp = get(window),
             fcz_b = fcz_base, fcz_w = get(fz))]
  if (variant == "current") {
    # Session-2 reference: c_convention = c_export + FCz_export / 2 (sample-wise, so also for means).
    d[session == 2L, `:=`(amp = amp + fcz_w / 2, base = base + fcz_b / 2)]
    d <- d[!paste(pid, session) %in% MIS_CURRENT[, paste(pid, session)]]
    d <- d[!paste(pid, session) %in% INVALID[, paste(pid, session)]]
    d <- d[pid != 14L]
  } else {
    d <- d[!paste(pid, session) %in% MIS_STALE[, paste(pid, session)]]
  }
  # The pipeline identifies a trial by (participant, session, grammaticality, sentence marker,
  # region) and averages rows sharing that key; a marker repeated within one export is merged.
  d <- d[, .(amp = mean(amp), base = mean(base), n_seg = .N, seg = min(seg)),
         by = .(pid, session, condition, marker, region)]
  d <- merge(d, cov[, .(pid, mini_language, mld)], by = "pid", all.x = TRUE)
  d[, `:=`(
    g = fifelse(condition == "S101", 0.5, -0.5),
    s = c(`2` = 0, `3` = 1, `4` = 2, `6` = 3)[as.character(session)],
    l = fifelse(mini_language == "Mini-Norwegian", 0.5, -0.5),
    caud = fifelse(grepl("anterior", region), 0.5, fifelse(grepl("medial", region), 0, -0.5)),
    hemi = fifelse(grepl("left", region), -0.5, fifelse(grepl("right", region), 0.5, NA_real_))
  )]
  d[, `:=`(z_amp = .zs(amp), z_base = .zs(base)), by = pid]
  sc <- list()
  for (v in c("g", "s", "l", "caud", "hemi", "mld")) {
    mu <- mean(d[[v]], na.rm = TRUE); sdv <- sd(d[[v]], na.rm = TRUE)
    sc[[v]] <- c(mu, sdv)
    d[, paste0("z_", v) := if (is.na(sdv) || sdv == 0) 0 else (get(v) - mu) / sdv]
  }
  d[, item := factor(paste0(mini_language, "_", marker))]
  d[, trial := factor(paste(pid, session, condition, marker, sep = "_"))]
  d[, pid := factor(pid)]
  keep <- c("z_amp", "z_base", "z_g", "z_s", "z_l", "z_caud", "z_mld", "pid", "item")
  if (macro == "lateral") keep <- c(keep, "z_hemi")
  d <- d[complete.cases(d[, ..keep])]
  attr(d, "scaling") <- sc
  d
}

erp_formula <- function(macro, item_slope = TRUE, extra_part = "", trial_re = FALSE) {
  spatial <- if (macro == "lateral") "z_g * z_hemi + z_g * z_caud" else "z_g * z_caud"
  item <- if (item_slope) "(1 + z_g + z_s | item)" else "(1 + z_s | item)"
  part <- paste0("(1 + z_g + z_s", extra_part, " | pid)")
  as.formula(paste0("z_amp ~ z_base + z_g * z_s * z_l + ", spatial, " + z_mld + ", part, " + ", item,
                    if (trial_re) " + (1 | trial)" else ""))
}

KEY <- c("z_g", "z_g:z_l", "z_g:z_s", "z_g:z_s:z_l")

# Fixed-effect covariance for a design `nd` under FIXED variance components (theta, sigma) taken
# from a fitted lmer `fit`: Cov = sigma^2 (X'X - X'ZL (L'Z'ZL + I)^-1 L'Z'X)^-1, which equals
# sigma^2 (X' V^-1 X)^-1 with V = I + Z L L' Z'. This is the GLS covariance lme4's vcov() reports
# at the fitted theta, so on the fitted data it must reproduce vcov(fit).
gls_vcov <- function(f, th, sig, nd) {
  lf <- lFormula(f, data = nd, REML = TRUE,
                 control = lmerControl(check.nobs.vs.nRE = "ignore", check.nobs.vs.nlev = "ignore",
                                       check.nobs.vs.rankZ = "ignore", check.nlev.gtreq.5 = "ignore"))
  X <- lf$X
  Lt <- lf$reTrms$Lambdat
  stopifnot(length(th) == length(unique(lf$reTrms$Lind)))
  Lt@x <- th[lf$reTrms$Lind]
  ZL <- t(Lt %*% lf$reTrms$Zt)                       # n x q
  A <- crossprod(ZL) + Diagonal(ncol(ZL))            # q x q, sparse
  B <- crossprod(ZL, X)                              # q x p
  CA <- Cholesky(forceSymmetric(A), LDL = FALSE)
  M <- crossprod(X) - crossprod(B, solve(CA, B))
  V <- sig^2 * solve(as.matrix(M))
  dimnames(V) <- list(colnames(X), colnames(X))
  V
}
