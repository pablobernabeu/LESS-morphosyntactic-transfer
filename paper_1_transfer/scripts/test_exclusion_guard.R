# =============================================================================
# paper_1_transfer/scripts/test_exclusion_guard.R
# Regression tests for the mis-filtered-dataset exclusion and its staleness guard
# =============================================================================
#
# WHY THIS FILE EXISTS
# --------------------
# The Methods of Paper 1 state that the legacy derivatives of nine Session-3 recordings,
# high-pass filtered offline at 1 Hz instead of 0.1 Hz, and of three invalid exports are
# excluded from the reported analyses. That
# sentence is a claim about the fitted models the manuscript reads, so the
# manuscript checks it before printing it, and prints a visible marker when it
# cannot be substantiated.
#
# An earlier version of that check tested only whether results/_exclusions.csv
# existed. The extraction scripts wrote that file as a side effect, so re-running
# an extraction cleared the marker even when the fits being reported were older
# than the exclusion and still contained the excluded datasets. The manuscript then
# asserted an exclusion that had not been applied, silently. These tests pin down
# the replacement behaviour so that failure cannot recur unnoticed.
#
# The checks cover six things: that the row-matching survives the factor-level
# trap documented in _config.R, that the drops key on each row's source (legacy exports
# always go, rows read from the reprocessed overlay stay in the primary analysis) and stop
# on data they cannot key, that the fit-time metadata records what the models were
# actually fitted to, that the manuscript's decision rule refuses to clear the marker on
# partial, exempt, superseded or sensitivity-only evidence (the retention-free refits and
# repeated records included), that the robustness switch (LES_P1_EXCLUDE_REPROCESSED=1)
# selects its own tag and derived file and drops the reprocessed rows, and that the
# decoding seed's, permutation count's and time step's defaults are typed identically
# wherever they have to be repeated, as is the analysis grid in the job arrays. The
# Session-2 reference correction is checked on a synthetic export with known algebra.
# LES_P1_EXCLUDE_REPROCESSED, LES_P1_ITEM_SLOPE,
# LES_PRIOR_SET, LES_P1_ACC_DIVERSITY, LES_P1_ACC_RT_SCREEN and the retired
# LES_P1_ACC_NO_RT_SCREEN are cleared before the checks run, so a shell prepared for one of
# those refits does not change what is tested.
#
# USAGE
#   Rscript paper_1_transfer/scripts/test_exclusion_guard.R
# Exits non-zero if any check fails, so it can gate a render or a commit hook.
# =============================================================================

source(here::here("paper_1_transfer", "scripts", "_config.R"))

# The checks below assume the default variant. A shell prepared for a sensitivity refit may
# export these switches, and LES_P1_EXCLUDE_REPROCESSED=1 alone would make the drop checks
# fail although the code is correct. They are cleared for this R process only, which is
# the whole run when the script is invoked through Rscript as USAGE shows.
Sys.unsetenv(c("LES_P1_EXCLUDE_REPROCESSED", "LES_P1_ITEM_SLOPE", "LES_PRIOR_SET",
               "LES_P1_ACC_DIVERSITY", "LES_P1_ACC_RT_SCREEN", "LES_P1_ACC_NO_RT_SCREEN"))

.pass <- 0L; .fail <- 0L
ck <- function(label, got, want) {
  ok <- isTRUE(all.equal(got, want))
  cat(sprintf("%-66s %s\n", label,
              if (ok) "PASS" else sprintf("FAIL (got %s, want %s)",
                                          paste(got, collapse = ","),
                                          paste(want, collapse = ","))))
  if (ok) .pass <<- .pass + 1L else .fail <<- .fail + 1L
}

# --- Fixtures ----------------------------------------------------------------
# Both identifying columns are FACTORS in the extracted cell data, with session
# levels "2","3","4","6". A naive as.integer() would map session 3 to level 2 and
# session 4 to level 3, so the fixtures deliberately include session 4 rows for
# excluded participants to catch that off-by-one.
mk <- function(pids, sess) data.frame(
  participant_lab_ID = factor(pids, levels = as.character(sort(unique(c(pids, 7, 8, 9, 16, 20))))),
  session            = factor(sess, levels = c("2", "3", "4", "6")))

# 7@3, 8@3 and 16@3 are mis-filtered. 7@4, 20@3 and 20@4 are not.
d_with <- mk(c(7, 7, 8, 20, 20, 16), c(3, 4, 3, 3, 4, 3))

# --- The row-matching helper -------------------------------------------------
ck("misfiltered_rows counts factor-coded rows correctly",
   les_p1_misfiltered_rows(d_with), 3L)
ck("session 4 is never mistaken for session 3 (factor level-index trap)",
   les_p1_misfiltered_rows(mk(c(7, 8, 9, 16), c(4, 4, 4, 4))), 0L)
ck("an unlisted participant in session 3 is retained",
   les_p1_misfiltered_rows(mk(c(20, 20), c(3, 3))), 0L)
ck("misfiltered_rows is NA when the identifying columns are absent",
   les_p1_misfiltered_rows(data.frame(x = 1)), NA_integer_)
ck("the drop removes exactly the mis-filtered rows",
   nrow(les_p1_drop_misfiltered(d_with)), nrow(d_with) - 3L)
ck("nothing is mis-filtered after the drop",
   les_p1_misfiltered_rows(les_p1_drop_misfiltered(d_with)), 0L)
# A drop that cannot see the identifying columns must stop, not return its input unchanged.
ck("the drop stops on data without the identifying columns",
   inherits(tryCatch(les_p1_drop_misfiltered(data.frame(x = 1)), error = function(e) e),
            "error"), TRUE)
ck("so does the combined EEG exclusion",
   inherits(tryCatch(les_p1_apply_eeg_exclusions(data.frame(participant_lab_ID = 1)),
                     error = function(e) e), "error"), TRUE)

# --- The full nine-record list and the protocol deviation (September 2026) -----
ck("all nine 1 Hz Session-3 records are listed",
   sort(LES_P1_MISFILTERED$participant_lab_ID), c(7L, 8L, 9L, 16L, 53L, 60L, 61L, 62L, 65L))
ck("the five records found in September are matched at Session 3 only",
   les_p1_misfiltered_rows(data.frame(participant_lab_ID = factor(c(53, 60, 61, 62, 65, 53)),
                                      session = factor(c(3, 3, 3, 3, 3, 4),
                                                       levels = c("2", "3", "4", "6")))), 5L)
# Participant 10's Session-2 history reads 1 Hz, but the export rebuilds only at 0.1 Hz.
ck("participant 10's Session 2 is not treated as mis-filtered",
   les_p1_misfiltered_rows(data.frame(participant_lab_ID = factor(10),
                                      session = factor(2, levels = c("2", "3", "4", "6")))), 0L)
d_dev <- data.frame(participant_lab_ID = factor(c(14, 14, 14, 15, 7)),
                    session = factor(c(2, 3, 6, 2, 3), levels = c("2", "3", "4", "6")))
ck("participant 14 is matched at every session",   les_p1_deviation_rows(d_dev), 3L)
ck("the combined EEG exclusion drops both kinds",
   as.character(les_p1_apply_eeg_exclusions(d_dev)$participant_lab_ID), "15")
ck("deviation_rows is recorded at fit time",
   les_p1_write_fit_meta(d_dev, "erp_dev", tempfile(fileext = ".rds"))$deviation_rows, 3L)

# --- The invalid exports (September 2026) -------------------------------------
d_inv <- data.frame(participant_lab_ID = factor(c(48, 48, 58, 5, 5, 5, 7, 7)),
                    session = factor(c(3, 4, 3, 4, 6, 6, 2, 4), levels = c("2", "3", "4", "6")))
ck("the three invalid exports are listed",
   sort(paste(LES_P1_INVALID_EXPORTS$participant_lab_ID, LES_P1_INVALID_EXPORTS$session)),
   c("48 3", "5 6", "7 2"))
ck("the invalid exports are matched at their own session only",
   les_p1_invalid_export_rows(d_inv), 4L)
ck("the combined EEG exclusion drops them and keeps the source recording",
   paste(les_p1_apply_eeg_exclusions(d_inv)$participant_lab_ID,
         les_p1_apply_eeg_exclusions(d_inv)$session), c("48 4", "58 3", "5 4", "7 4"))
ck("invalid_export_rows is recorded at fit time",
   les_p1_write_fit_meta(d_inv, "erp_inv", tempfile(fileext = ".rds"))$invalid_export_rows, 4L)

# --- Rows read from the reprocessed overlay (September 2026) --------------------
# The same participant-sessions, once reprocessed or recovered, are primary data. The drop
# must key on eeg_source as well as on participant and session.
d_src <- data.frame(participant_lab_ID = factor(c(7, 7, 48, 48, 20)),
                    session   = factor(c(3, 3, 3, 3, 3), levels = c("2", "3", "4", "6")),
                    eeg_source = c("legacy", "overlay", "legacy", "overlay", "legacy"))
ck("overlay rows are not counted as mis-filtered",      les_p1_misfiltered_rows(d_src), 1L)
ck("overlay rows are not counted as invalid exports",   les_p1_invalid_export_rows(d_src), 1L)
ck("overlay rows of listed records are counted as reprocessed", les_p1_reprocessed_rows(d_src), 2L)
ck("the primary exclusion keeps the overlay rows and drops the legacy ones",
   paste(les_p1_apply_eeg_exclusions(d_src)$participant_lab_ID,
         les_p1_apply_eeg_exclusions(d_src)$eeg_source),
   c("7 overlay", "48 overlay", "20 legacy"))
ck("an overlay row of an unlisted record is not counted as reprocessed",
   les_p1_reprocessed_rows(transform(d_src, eeg_source = "overlay")[5, ]), 0L)
Sys.setenv(LES_P1_EXCLUDE_REPROCESSED = "1")
ck("the robustness analysis drops listed records whatever their source",
   as.character(les_p1_apply_eeg_exclusions(d_src)$participant_lab_ID), "20")
ck("the robustness analysis still drops the invalid exports",
   les_p1_invalid_export_rows(les_p1_apply_eeg_exclusions(d_inv)), 0L)
ck("reprocessed_rows and exclude_reprocessed are recorded at fit time",
   unlist(les_p1_write_fit_meta(les_p1_apply_eeg_exclusions(d_src), "erp_rob",
                                tempfile(fileext = ".rds"))[c("reprocessed_rows",
                                                              "exclude_reprocessed")]),
   c(reprocessed_rows = 0L, exclude_reprocessed = 1L))
Sys.unsetenv("LES_P1_EXCLUDE_REPROCESSED")
ck("a fit's ERP model version is recorded when given",
   les_p1_write_fit_meta(d_src, "erp_v", tempfile(fileext = ".rds"),
                         erp_model_version = LES_P1_ERP_MODEL_VERSION)$erp_model_version,
   LES_P1_ERP_MODEL_VERSION)

# --- The Session-2 reference correction --------------------------------------
# A synthetic Session-2 export built exactly as the Analyzer chain wrote it. Channels are
# generated against the online reference FCz: r_c for scalp electrodes, r_TP9 and r_TP10
# for the mastoids, with t = (r_TP9 + r_TP10) / 2. New Reference gives y_c = r_c - 2t/3,
# keeps the mastoids as r_TP9 and r_TP10, and recovers FCz as -2t/3. The ICA then removes
# a known "ocular" source s with topography a from every channel except FCz. The target
# is the Sessions 3/4/6 convention applied to the same cleaning: (r - a s) re-referenced to
# the mean of the cleaned mastoids, and FCz = -t. The correction must reproduce it exactly
# and leave the mastoid and accelerometer rows as exported.
set.seed(1)
chans <- c("Fp1", "Pz", "TP9", "TP10", "x_dir", "FCz")
n_s <- 50
r <- rbind(Fp1 = rnorm(n_s, 0, 20), Pz = rnorm(n_s, 0, 10),
           TP9 = rnorm(n_s, 5, 8), TP10 = rnorm(n_s, -3, 8))
s <- rnorm(n_s, 0, 30)                                  # removed source
a <- c(Fp1 = 1, Pz = 0.1, TP9 = -0.2, TP10 = -0.25)     # its topography against FCz
t_raw <- (r["TP9", ] + r["TP10", ]) / 2
y <- rbind(Fp1 = r["Fp1", ] - 2 * t_raw / 3, Pz = r["Pz", ] - 2 * t_raw / 3,
           TP9 = r["TP9", ], TP10 = r["TP10", ])
# Removing the source in Session-2 channel space: its topography there is a_c - 2 a_t / 3 on
# scalp channels and a on the mastoids.
a_t <- (a["TP9"] + a["TP10"]) / 2
a_s2 <- c(Fp1 = a[["Fp1"]] - 2 * a_t / 3, Pz = a[["Pz"]] - 2 * a_t / 3,
          TP9 = a[["TP9"]], TP10 = a[["TP10"]])
e <- y - outer(a_s2, s)
exported <- rbind(e, x_dir = rnorm(n_s), FCz = -2 * t_raw / 3)[chans, ]
clean <- r - outer(a, s)                                # cleaned, against FCz
t_clean <- (clean["TP9", ] + clean["TP10", ]) / 2
target_scalp <- rbind(Fp1 = clean["Fp1", ] - t_clean, Pz = clean["Pz", ] - t_clean)
corrected <- les_p1_s2_rereference(exported, chans)
ck("scalp channels reach the cleaned linked-mastoid reference exactly",
   max(abs(corrected[c("Fp1", "Pz"), ] - target_scalp)) < 1e-10, TRUE)
ck("FCz becomes minus the uncleaned mastoid mean, as in Sessions 3/4/6",
   max(abs(corrected["FCz", ] + t_raw)) < 1e-10, TRUE)
ck("the mastoid and accelerometer rows are left as exported",
   identical(corrected[c("TP9", "TP10", "x_dir"), ], exported[c("TP9", "TP10", "x_dir"), ]), TRUE)
# The earlier formula (add FCz/2 everywhere) misses the target by a third of the removed
# source's mastoid loading, which is what the correction exists to avoid.
k1 <- exported[c("Fp1", "Pz"), ] + matrix(exported["FCz", ] / 2, 2, n_s, byrow = TRUE)
ck("the superseded FCz/2 formula does not reach the target when a source is removed",
   max(abs(k1 - target_scalp)) > 1, TRUE)
ck("a Session-2 export without the mastoids stops the correction",
   inherits(tryCatch(les_p1_s2_rereference(exported[c("Fp1", "Pz", "FCz"), ],
                                           c("Fp1", "Pz", "FCz")),
                     error = function(e) e), "error"), TRUE)

# --- The fit-time metadata writer --------------------------------------------
r_clean <- les_p1_write_fit_meta(les_p1_drop_misfiltered(d_with), "erp_clean",
                                 tempfile(fileext = ".rds"))
ck("a clean fit records exclusion_applied = TRUE",  r_clean$exclusion_applied, TRUE)
ck("a clean fit records misfiltered_rows = 0",      r_clean$misfiltered_rows,  0L)
r_stale <- les_p1_write_fit_meta(d_with, "erp_stale", tempfile(fileext = ".rds"))
ck("a fit that still contains them is flagged",     r_stale$exclusion_applied, FALSE)
r_acc <- les_p1_write_fit_meta(d_with, "accuracy_x", tempfile(fileext = ".rds"),
                               exclusion_applicable = FALSE)
ck("the accuracy models are exempt, not flagged",   r_acc$exclusion_applied,    TRUE)
ck("and are recorded as out of scope",              r_acc$exclusion_applicable, FALSE)

# --- The manuscript's decision rule ------------------------------------------
# les_p1_misfilter_status() in _config.R is the rule the manuscript applies, so the
# checks exercise that function directly. It returns "" when the claim may stand and
# the reason otherwise; the manuscript wraps a non-empty reason in its pending marker.
status_for <- function(tbl) les_p1_misfilter_status(tbl, primary = "maximal")
pending    <- function(x) nzchar(x)
row_for <- function(i, applied, applicable = TRUE, variant = "informative",
                    exclreproc = FALSE, structure = "maximal",
                    version = LES_P1_ERP_MODEL_VERSION)
  data.frame(model = paste0("erp_", i, if (exclreproc) "_exclreproc" else ""),
             exclusion_applicable = applicable,
             misfiltered_rows = if (applied) 0L else 12L,
             exclusion_applied = applied, prior_variant = variant,
             exclude_reprocessed = exclreproc, structure = structure,
             invalid_export_rows = 0L, erp_model_version = version)
rows <- function(n, ...) do.call(rbind, lapply(seq_len(n), row_for, ...))

ck("a complete set of clean informative fits clears the marker",
   status_for(rows(18, applied = TRUE)), "")
ck("fits recorded before the invalid-export count keep the marker",
   pending(status_for(rows(18, applied = TRUE)[, setdiff(names(row_for(1, TRUE)),
                                                         "invalid_export_rows")])), TRUE)
ck("a fit containing an invalid export keeps the marker",
   pending(status_for(transform(rows(18, applied = TRUE),
                                invalid_export_rows = c(40L, rep(0L, 17))))), TRUE)
ck("fits of the superseded cluster-row model keep the marker",
   grepl("superseded", status_for(rows(18, applied = TRUE, version = NA_character_))), TRUE)
ck("a single superseded fit among 18 keeps the marker",
   pending(status_for(rbind(rows(17, applied = TRUE),
                            row_for(18, applied = TRUE, version = "cluster_rows")))), TRUE)
ck("records without the model-version column keep the marker",
   pending(status_for(rows(18, applied = TRUE)[, setdiff(names(row_for(1, TRUE)),
                                                         "erp_model_version")])), TRUE)
ck("no metadata at all keeps the marker",
   pending(status_for(NULL)), TRUE)
ck("a partial refit keeps the marker",
   grepl("only 6 of the 18", status_for(rows(6, applied = TRUE))), TRUE)
ck("a single stale cell among 18 keeps the marker",
   grepl("1 of 18 fitted", status_for(rbind(rows(17, applied = TRUE),
                                            row_for(18, applied = FALSE)))), TRUE)
ck("the exempt accuracy fits alone cannot clear the marker",
   pending(status_for(rows(3, applied = TRUE, applicable = FALSE))), TRUE)
ck("the weak-prior sensitivity refits alone cannot clear the marker",
   pending(status_for(rows(18, applied = TRUE, variant = "weak"))), TRUE)

# The base-structure fits are the structural sensitivity comparison, so a clean grid of
# them cannot substantiate a claim about the maximal fits the manuscript reports, and
# records that predate the structure column cannot be assigned to either structure.
ck("the other random-effect structure alone cannot clear the marker",
   pending(status_for(rows(18, applied = TRUE, structure = "base"))), TRUE)
ck("both structures clean, the reported one is audited on its own 18 rows",
   status_for(rbind(rows(18, applied = TRUE, structure = "base"),
                    rows(18, applied = TRUE))), "")
no_structure <- function(d) d[, setdiff(names(d), "structure"), drop = FALSE]
ck("records without a structure column keep the marker for a maximal primary",
   grepl("predate the random-effect-structure column",
         status_for(no_structure(rows(18, applied = TRUE)))), TRUE)
ck("records without a structure column still clear a base primary",
   les_p1_misfilter_status(no_structure(rows(18, applied = TRUE)), primary = "base"), "")

# The robustness refits (LES_P1_EXCLUDE_REPROCESSED=1) are a sensitivity analysis with their
# own records. They must not be counted against the reported grid, and they must not be
# able to stand in for it either.
ck("robustness refits do not disturb a clean primary grid",
   status_for(rbind(rows(18, applied = TRUE),
                    rows(18, applied = FALSE, exclreproc = TRUE))), "")
ck("the robustness refits alone cannot clear the marker",
   pending(status_for(rows(18, applied = TRUE, exclreproc = TRUE))), TRUE)
# The retention-free refits share the primary cells' model ids, structure and prior, so
# only their retention_free column tells them apart. Twelve of them must not complete a
# primary grid of six, and a repeated record must not stand in for a missing cell.
ck("retention-free refits do not disturb a clean primary grid",
   status_for(rbind(transform(rows(18, applied = TRUE), retention_free = FALSE),
                    transform(rows(12, applied = TRUE), retention_free = TRUE))), "")
ck("retention-free refits cannot complete a partial primary grid",
   grepl("only 6 of the 18",
         status_for(transform(rows(18, applied = TRUE),
                              retention_free = rep(c(FALSE, TRUE), c(6, 12))))), TRUE)
ck("a repeated record cannot stand in for a missing cell",
   grepl("only 17 of the 18", status_for(rbind(rows(17, applied = TRUE),
                                                row_for(17, applied = TRUE)))), TRUE)
# A pooled table from before September 2026 may still hold the retired
# mis-filter-retained refits; they are set aside rather than read as stale primary fits.
old_keep <- transform(rows(18, applied = FALSE), keep_misfiltered = TRUE)
ck("retired mis-filter-retained records do not disturb a clean primary grid",
   status_for(rbind(transform(rows(18, applied = TRUE), keep_misfiltered = FALSE),
                    old_keep)), "")

# The switch is read from the environment at call time, so its tag and derived file name
# are checked on the production helpers.
Sys.setenv(LES_P1_EXCLUDE_REPROCESSED = "1")
g <- les_p1_erp_grid()[1, ]
ck("LES_P1_EXCLUDE_REPROCESSED=1 selects the _exclreproc tag",
   les_p1_exclreproc_tag(), "_exclreproc")
ck("the robustness derived cell file carries that tag",
   endsWith(les_p1_cell_rds(g$property, g$window, g$macroregion), "_exclreproc.rds"), TRUE)
Sys.unsetenv("LES_P1_EXCLUDE_REPROCESSED")
ck("with the switch unset the tag is empty",
   les_p1_exclreproc_tag(), "")
ck("and the primary derived cell file is untagged",
   basename(les_p1_cell_rds(g$property, g$window, g$macroregion)), paste0(g$cell_id, ".rds"))

# --- The decoding seed's default, repeated by necessity ----------------------
# 09_run_decoding.R and hpc/08_decoding.slurm each carry the literal default of
# LES_DECODE_SEED. Both must equal LES_P1_DECODE_SEED_DEFAULT so that a decoding job that
# exports no seed runs under the configured default. The seed a decoding run actually used
# is recorded by hpc/08_decoding.slurm in results/_decoding_provenance.csv, which the
# manuscript reads. The LES_DECODE_SEED entry that 03_fit_brms_erp.R writes to
# results/_provenance.csv comes from the ERP job's environment, falling back on this
# default, and records nothing about any decoding run. The two literals are read back and
# compared here.
.seed_literal <- function(file, pattern) {
  hit <- grep(pattern, readLines(here::here("paper_1_transfer", file), warn = FALSE),
              value = TRUE)
  if (length(hit) != 1L) return(NA_character_)
  regmatches(hit, regexpr("[0-9]{6,}", hit))
}
ck("09_run_decoding.R defaults LES_DECODE_SEED to LES_P1_DECODE_SEED_DEFAULT",
   .seed_literal(file.path("scripts", "09_run_decoding.R"),
                 '^LES_DECODE_SEED\\s*<-.*Sys\\.getenv\\("LES_DECODE_SEED"'),
   as.character(LES_P1_DECODE_SEED_DEFAULT))
ck("hpc/08_decoding.slurm exports the same default",
   .seed_literal(file.path("hpc", "08_decoding.slurm"),
                 '^export LES_DECODE_SEED='),
   as.character(LES_P1_DECODE_SEED_DEFAULT))

# --- The decoding permutation count and time step, repeated by necessity ------
# hpc/08_decoding.slurm names both defaults and refuses anything below them, so a copy
# that drifted would make the job refuse its own scripts' defaults or run the R side at
# another B. 09_run_decoding.R repeats the permutation count, 08b_verify_gender_decoding.slurm
# the count it expects when no provenance record says otherwise, and
# 08_extract_decoding_matrices.R the time step. Each literal is read back as typed.
.literal <- function(file, pattern, value_rx) {
  hit <- grep(pattern, readLines(here::here("paper_1_transfer", file), warn = FALSE),
              value = TRUE)
  if (length(hit) != 1L || !grepl(value_rx, hit)) return(NA_character_)
  sub(value_rx, "\\1", hit)
}
.slurm <- file.path("hpc", "08_decoding.slurm")
nperm_default <- .literal(.slurm, "^DECODE_NPERM_DEFAULT=", "^DECODE_NPERM_DEFAULT=([0-9]+).*$")
step_default  <- .literal(.slurm, "^DECODE_TIME_STEP_DEFAULT=",
                          "^DECODE_TIME_STEP_DEFAULT=([0-9]+).*$")
ck("hpc/08_decoding.slurm names its permutation-count default",
   grepl("^[0-9]+$", nperm_default), TRUE)
ck("hpc/08_decoding.slurm names its time-step default",
   grepl("^[0-9]+$", step_default), TRUE)
ck("09_run_decoding.R defaults LES_DECODE_NPERM to the slurm default",
   .literal(file.path("scripts", "09_run_decoding.R"),
            '^LES_DECODE_NPERM\\s*<-.*Sys\\.getenv\\("LES_DECODE_NPERM"',
            '^.*unset = "([0-9]+)".*$'), nperm_default)
ck("08b expects the slurm default when no provenance record says otherwise",
   .literal(file.path("hpc", "08b_verify_gender_decoding.slurm"),
            "EXPECT=[0-9]+; EXPECT_SRC=", "^.*EXPECT=([0-9]+);.*$"), nperm_default)
ck("08_extract_decoding_matrices.R defaults the time step to the slurm default",
   .literal(file.path("scripts", "08_extract_decoding_matrices.R"),
            'Sys\\.getenv\\("LES_DECODE_TIME_STEP_MS"', '^.*unset = "([0-9]+)".*$'),
   step_default)

# --- The analysis grid, hand-copied into the job arrays ------------------------
# Each array job maps SLURM_ARRAY_TASK_ID to a cell through a literal PARAMS list, since
# bash cannot read _config.R. A property, window or macroregion added to the configuration
# but not to a job would never be fitted, and nothing would say so. Each list is read back
# as a set of cells, with no cell listed twice, and compared with the configured grid
# projected onto its columns. The order is the job's own (its header fixes it, so an array
# index keeps naming the same cell across resubmissions) and is not compared.
.slurm_params <- function(file, open = "^PARAMS=\\(") {
  x <- readLines(here::here("paper_1_transfer", "hpc", file), warn = FALSE)
  start <- grep(open, x)
  if (length(start) != 1L) return(character())
  end <- start + which(grepl("^\\)", x[-seq_len(start)]))[1]
  gsub('^\\s*"|"\\s*$', "", x[(start + 1L):(end - 1L)])
}
.grid <- les_p1_erp_grid()
.cells <- function(cols) sort(unique(do.call(paste, unname(.grid[cols]))))
.as_set <- function(p) if (anyDuplicated(p)) "a cell listed twice" else sort(p)
ck("hpc/03_fit_erp.slurm fits every configured cell once",
   .as_set(.slurm_params("03_fit_erp.slurm")), .cells(c("property", "window", "macroregion")))
for (f in c("01_extract_erp.slurm", "07_grand_average.slurm",
            "07b_grand_average_electrode.slurm")) {
  ck(sprintf("hpc/%s covers every property x macroregion once", f),
     .as_set(.slurm_params(f)), .cells(c("property", "macroregion")))
}
ck("hpc/04_fit_accuracy.slurm covers every property once",
   .as_set(.slurm_params("04_fit_accuracy.slurm")), sort(names(LES_P1_PROPERTIES)))
.props <- grep("^PROPS=\\(", readLines(here::here("paper_1_transfer", "hpc",
                                                  "08_decoding.slurm"), warn = FALSE),
               value = TRUE)
ck("hpc/08_decoding.slurm decodes every property once",
   .as_set(strsplit(gsub("^PROPS=\\(|\\)\\s*$", "", .props), "\\s+")[[1]]),
   sort(names(LES_P1_PROPERTIES)))
# The accuracy data tags (G06-03): the screened variant reads and writes its own derived
# file and model id, and leaves the reported ones untouched when unset.
ck("the accuracy data tag is empty with no switch set", les_p1_acc_data_tag(), "")
ck("the reported accuracy file keeps its name",
   basename(les_p1_accuracy_rds("gender_agreement")), "accuracy_gender_agreement.rds")
Sys.setenv(LES_P1_ACC_RT_SCREEN = "1")
ck("the screen switch tags the derived file",
   basename(les_p1_accuracy_rds("gender_agreement")), "accuracy_gender_agreement_rtscreen.rds")
Sys.setenv(LES_P1_ACC_DIVERSITY = "1")
ck("the data tags compose as _diversity_rtscreen", les_p1_acc_data_tag(), "_diversity_rtscreen")
Sys.unsetenv(c("LES_P1_ACC_DIVERSITY", "LES_P1_ACC_RT_SCREEN"))
# The retired switch stops the run, so a job script that still sets it cannot fit the
# primary models under a sensitivity tag or the reverse.
Sys.setenv(LES_P1_ACC_NO_RT_SCREEN = "1")
ck("the retired unscreened switch stops the run",
   inherits(tryCatch(les_p1_acc_data_tag(), error = function(e) e), "error"), TRUE)
Sys.unsetenv("LES_P1_ACC_NO_RT_SCREEN")
.acc_tags <- sub("^TAG=.*|.*TAG=\"\\$\\{TAG\\}(_[a-z]+)\".*$", "\\1",
                 grep("TAG=\"\\$\\{TAG\\}_", readLines(here::here("paper_1_transfer", "hpc",
                      "04_fit_accuracy.slurm"), warn = FALSE), value = TRUE))
ck("hpc/04_fit_accuracy.slurm composes the log tags in model_tag's order",
   .acc_tags, c("_diversity", "_rtscreen", "_maxranef", "_byitem", "_weakprior"))

cat(sprintf("\n%d passed, %d failed\n", .pass, .fail))
if (.fail > 0) quit(status = 1)
