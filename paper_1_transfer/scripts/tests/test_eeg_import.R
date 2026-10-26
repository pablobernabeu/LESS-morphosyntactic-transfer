# =============================================================================
# paper_1_transfer/scripts/tests/test_eeg_import.R
# -----------------------------------------------------------------------------
# Checks the vendored importer (_eeg_import.R) against the legacy importer it copies, on
# real exports, and checks the three things it does differently:
#   1. On exports outside Session 2 the output is identical to the legacy importer's.
#   2. On a Session-2 export every scalp electrode equals the legacy value minus a sixth of
#      the exported TP9 + TP10, FCz equals 1.5 times the legacy value, and TP9, TP10 and
#      the accelerometer rows are unchanged.
#   3. The overlay is admitted only through the manifest: a validated reprocessed record
#      replaces the legacy files of its own participant-session and is labelled "overlay";
#      a missing manifest or row, a wrong hash, a failed status, a path that disagrees with
#      its participant, a duplicate row, an unknown kind, an incomplete record, a record on
#      neither exclusion list, and a 1 Hz record without the other eight each stop the import; a rebuilt marker file pairs with
#      its legacy export but may not replace an existing marker file; an export without a
#      marker file is reported and skipped.
# It needs the data tree, so it skips (exit 0 with a message) when the tree is absent.
# Kept to a few files because the full import is memory-heavy.
#
# Run from the project root, with LES_DATA_ROOT pointing at the data tree:
#   Rscript --vanilla paper_1_transfer/scripts/tests/test_eeg_import.R
# =============================================================================

suppressPackageStartupMessages({
  library(here)
  library(dplyr)
})
data_root <- Sys.getenv("LES_DATA_ROOT", unset = here::here("data"))
if (!dir.exists(file.path(data_root, "raw data", "EEG"))) {
  cat("SKIP: no EEG data tree at", data_root, "\n")
  quit(status = 0)
}
# The overlay tests write into a temporary store and a temporary manifest, so neither the
# real store nor the tracked manifest is ever touched.
store <- file.path(tempdir(), "les_store_test")
dir.create(store, showWarnings = FALSE)
Sys.setenv(LES_STORE = store)
suppressPackageStartupMessages({
  source(here::here("_shared", "R", "00_paths.R"))
  source(here::here("_shared", "R", "03_data_manifest.R"))
  source(here::here("paper_1_transfer", "scripts", "_config.R"))
  source(here::here("paper_1_transfer", "scripts", "_eeg_import.R"))
})

ok <- function(cond, msg) {
  if (!isTRUE(cond)) stop("FAIL: ", msg, call. = FALSE)
  cat("PASS:", msg, "\n")
}

# The legacy importer reads the relative path 'data/raw data/EEG' and sources nothing else,
# so it is run with the parent of the data tree as the working directory.
legacy_import <- function(pattern, ...) {
  old <- setwd(dirname(data_root)); on.exit(setwd(old))
  source(file.path("data", "R_functions", "import_trialbytrial_EEG_data.R"), local = TRUE)
  utils::capture.output(d <- import_trialbytrial_EEG_data(EEG_file_pattern = pattern, ...))
  if (exists("trialbytrial_EEG_data_temp", envir = .GlobalEnv))
    rm("trialbytrial_EEG_data_temp", envir = .GlobalEnv)
  d
}
as_plain <- function(d) {
  d <- as.data.frame(d)
  d[] <- lapply(d, function(x) if (is.factor(x)) as.character(x) else x)
  d
}

# --- 1. Identical output outside Session 2 -------------------------------------------
# Participant 10's differential-object-marking grammatical exports: Sessions 3, 4 and 6.
pat_dom <- "^10_trialbytrial_S2_S101\\."
for (mr in list(NULL, "lateral")) {
  a <- as_plain(legacy_import(pat_dom, min_time = 200, max_time = 898,
                              include_baseline = TRUE, selected_macroregion = mr))
  b <- as_plain(suppressMessages(les_p1_import_trialbytrial(pat_dom, min_time = 200, max_time = 898,
                                                            include_baseline = TRUE,
                                                            selected_macroregion = mr)))
  ok(all(b$eeg_source == "legacy"), "rows read from the data tree are labelled legacy")
  b$eeg_source <- NULL
  ok(identical(names(a), names(b)) && nrow(a) == nrow(b) && isTRUE(all.equal(a, b, check.attributes = FALSE)),
     sprintf("identical to the legacy importer outside Session 2 (macroregion %s; %d rows)",
             if (is.null(mr)) "none" else mr, nrow(a)))
  rm(a, b); invisible(gc())
}

# --- 2. The Session-2 correction -------------------------------------------------------
# Participant 11's gender grammatical exports include Session 2; compare that session only.
pat_g <- "^11_trialbytrial_S1_S101\\."
a <- as_plain(legacy_import(pat_g, min_time = -100, max_time = 1098, include_baseline = TRUE))
b <- as_plain(suppressMessages(les_p1_import_trialbytrial(pat_g, min_time = -100, max_time = 1098,
                                                          include_baseline = TRUE)))
b$eeg_source <- NULL
ok(identical(dim(a), dim(b)), "the Session-2 file keeps the legacy row and column structure")
key <- c("session", "electrode", "sentence_marker", "time")
a <- a[do.call(order, a[key]), ]; b <- b[do.call(order, b[key]), ]
s2 <- a$session == "2"
mast <- a[s2 & a$electrode %in% c("TP9", "TP10"), ]
ok(sum(s2) > 0 && nrow(mast) > 0, "the fixture holds Session-2 rows, mastoids included")
sixth <- tapply(mast$amplitude, paste(mast$sentence_marker, mast$time), sum) / 6
k <- paste(a$sentence_marker, a$time)
scalp <- s2 & !(a$electrode %in% c("TP9", "TP10", "FCz", "x_dir", "y_dir", "z_dir"))
ok(max(abs(b$amplitude[scalp] - (a$amplitude[scalp] - sixth[k[scalp]]))) < 1e-9,
   "Session-2 scalp electrodes lose a sixth of the exported TP9 + TP10")
fcz <- s2 & a$electrode == "FCz"
ok(max(abs(b$amplitude[fcz] - 1.5 * a$amplitude[fcz])) < 1e-9, "Session-2 FCz is 1.5 times the export")
keep <- s2 & a$electrode %in% c("TP9", "TP10", "x_dir", "y_dir", "z_dir")
ok(identical(b$amplitude[keep], a$amplitude[keep]), "Session-2 mastoid and accelerometer rows are unchanged")
ok(identical(b$amplitude[!s2], a$amplitude[!s2]), "the same participant's other sessions are unchanged")
num <- setdiff(names(a), c("amplitude", "z_amplitude"))
ok(isTRUE(all.equal(a[num], b[num], check.attributes = FALSE)),
   "every column other than the amplitudes is identical")
rm(a, b); invisible(gc())

# --- 3. Overlay admission, precedence and unpaired exports ------------------------------
# The tracked manifest is never touched: the manifest accessor is pointed at a file in the
# temporary store for the rest of this script.
man_path <- file.path(store, "eeg_overlay_manifest_test.csv")
les_p1_eeg_overlay_manifest <- function() man_path
legacy_root <- erp_single_trials_path()
over_root <- les_p1_eeg_overlay_root()
reset_overlay <- function() {
  unlink(over_root, recursive = TRUE); unlink(man_path)
  dir.create(file.path(over_root, "Session 3", "Export"), recursive = TRUE, showWarnings = FALSE)
}
# Copies every legacy Session-3 export of a participant into the overlay and returns the
# relative paths ("Session 3/Export/...").
copy_record <- function(pid) {
  rel <- file.path("Session 3", "Export",
                   list.files(file.path(legacy_root, "Session 3", "Export"),
                              paste0("^", pid, "_trialbytrial_S[123]_S10[123]\\.(txt|vmrk)$")))
  ok(length(rel) > 0 && all(file.copy(file.path(legacy_root, rel), file.path(over_root, rel))),
     sprintf("fixture: participant %s's Session-3 record copied into the overlay (%d files)",
             pid, length(rel)))
  rel
}
manifest_rows <- function(rel, pid, kind = "reprocessed", session = "3") {
  data.frame(file = rel, participant_lab_ID = as.character(pid), session = session, kind = kind,
             status = "pass", conventions = "as_legacy",
             sha256 = vapply(file.path(over_root, rel),
                             function(p) digest::digest(file = p, algo = "sha256"), character(1)),
             stringsAsFactors = FALSE, row.names = NULL)
}
write_man <- function(m) utils::write.csv(m, man_path, row.names = FALSE)
refused <- function(pattern, msg) {
  err <- tryCatch({ .les_eeg_overlay_validated(); "" }, error = function(e) conditionMessage(e))
  ok(grepl(pattern, err), msg)
}

# A record the protocol may recover: participant 48's Session 3 (LES_P1_INVALID_EXPORTS),
# with a recognisable value at Pz in one export. The legacy files stand in for the
# recovered ones; only the admission rules are under test.
reset_overlay()
rel48 <- copy_record(48)
target <- file.path(over_root, "Session 3", "Export", "48_trialbytrial_S2_S101.txt")
lines <- readLines(target)
pz <- match("Pz", sub("\\s.*$", "", lines))
vals <- strsplit(lines[pz], "\\s+")[[1]]
vals[-1] <- "7,000"
lines[pz] <- paste(vals, collapse = " ")
writeLines(lines, target)

refused("manifest.*does not exist", "overlay files without a manifest stop the import")
m48 <- manifest_rows(rel48, 48)
write_man(m48[-1, ])
refused("missing from the manifest", "an overlay file without a manifest row stops the import")
write_man(transform(m48, sha256 = replace(sha256, 1, strrep("0", 64))))
refused("SHA-256", "a file whose hash differs from the manifest stops the import")
write_man(transform(m48, status = replace(status, 2, "fail")))
refused("not passing", "a row that did not pass validation stops the import")
write_man(transform(m48, participant_lab_ID = "11"))
refused("disagree with the file path", "a row whose participant disagrees with its path stops the import")
write_man(rbind(m48, m48[1, ]))
refused("twice", "a file listed twice stops the import")
write_man(transform(m48, kind = "other"))
refused("Unknown overlay kind", "an unknown kind stops the import")
drop_vmrk <- grep("S1_S102\\.vmrk$", rel48, value = TRUE)
unlink(file.path(over_root, drop_vmrk))
write_man(m48[m48$file != drop_vmrk, ])
refused("incomplete", "a reprocessed record missing one of its files stops the import")
file.copy(file.path(legacy_root, drop_vmrk), file.path(over_root, drop_vmrk))

write_man(m48)
d <- as_plain(suppressMessages(les_p1_import_trialbytrial("^48_trialbytrial_S2_S101\\.")))
ok(all(d$amplitude[d$electrode == "Pz" & d$session == "3"] == 7) &&
     !all(d$amplitude[d$electrode == "Pz" & d$session == "4"] == 7),
   "a validated overlay record replaces the legacy file of its own session only")
ok(all(d$eeg_source[d$session == "3"] == "overlay") && all(d$eeg_source[d$session != "3"] == "legacy"),
   "rows are labelled with their source")
rm(d); invisible(gc())

# A record outside the protocol's scope cannot be replaced.
reset_overlay()
rel_out <- copy_record(10)
write_man(manifest_rows(rel_out, 10))
refused("outside the protocol's scope", "a reprocessed record on neither exclusion list stops the import")

# The protocol admits the reprocessed 1 Hz records only together.
reset_overlay()
rel7 <- copy_record(7)
write_man(manifest_rows(rel7, 7))
refused("only together", "one reprocessed 1 Hz record without the other eight stops the import")

# A marker file rebuilt for a legacy export that lacks one, and the refusals around it.
reset_overlay()
msg <- character(0)
withCallingHandlers(
  invisible(les_p1_import_trialbytrial("^17_trialbytrial_S1_S101\\.", min_time = 400, max_time = 402)),
  message = function(m) { msg <<- c(msg, conditionMessage(m)); invokeRestart("muffleMessage") })
ok(any(grepl("no marker file.*Session 3/Export/17_trialbytrial_S1_S101.txt", msg)),
   "an export without a marker file is reported by name")

# The importer reads only the sentence-marker labels, one per trial, and 600 samples per trial.
rel17 <- "Session 3/Export/17_trialbytrial_S1_S101"
n_trials <- (length(strsplit(readLines(file.path(legacy_root, paste0(rel17, ".txt")), n = 1),
                             "\\s+")[[1]]) - 1) / 600
writeLines(c("Brain Vision Data Exchange Marker File, Version 1.0", "[Marker Infos]",
             sprintf("Mk%d=Stimulus,S%d,%d,1,0", seq_len(n_trials), 109 + seq_len(n_trials),
                     600 * (seq_len(n_trials) - 1) + 51)),
           file.path(over_root, paste0(rel17, ".vmrk")))
m17 <- manifest_rows(paste0(rel17, ".vmrk"), 17, kind = "markers_rebuilt")
write_man(transform(m17, kind = "reprocessed"))
refused("outside the protocol's scope|incomplete", "a lone marker file cannot be admitted as a reprocessed record")
write_man(m17)
msg <- character(0)
d <- withCallingHandlers(
  as_plain(les_p1_import_trialbytrial("^17_trialbytrial_S1_S101\\.", min_time = 400, max_time = 402)),
  message = function(m) { msg <<- c(msg, conditionMessage(m)); invokeRestart("muffleMessage") })
ok(!any(grepl("no marker file", msg)) && any(d$session == "3") && all(d$eeg_source == "legacy"),
   "a rebuilt marker file pairs with its legacy export, whose rows stay legacy")
rm(d); invisible(gc())
rel10v <- "Session 3/Export/10_trialbytrial_S2_S101.vmrk"
file.copy(file.path(legacy_root, rel10v), file.path(over_root, rel10v))
write_man(rbind(m17, manifest_rows(rel10v, 10, kind = "markers_rebuilt")))
refused("replace an existing legacy one", "a rebuilt marker file may not replace an existing one")
unlink(over_root, recursive = TRUE); unlink(man_path)

cat("\nAll importer tests passed.\n")
