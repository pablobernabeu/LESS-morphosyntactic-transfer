# =============================================================================
# 04_provenance.R  --  Capture the computational environment at fit time
# =============================================================================
#
# WHY THIS EXISTS
# Reporting guidelines require the software and versions used for the MCMC, and a
# Stan model's results are version-sensitive: brms formula translation, default
# priors and NUTS adaptation have all changed across releases, and projpred's search
# and suggest_size behaviour changed between major versions. The manuscripts
# previously said only "a versioned R environment", which is not reproducible
# information.
#
# WHY NOT renv.lock ALONE
# renv.lock does record the fitting library, brms, cmdstanr, rstan, projpred and loo
# among them, at the versions these models were fitted under, and it is how a
# reproducer rebuilds the R side of the environment. It still cannot stand in for this
# file. A lockfile records what a library held when it was snapshotted, not what a given
# run loaded, and it carries no seeds. Nor can it record CmdStan, the GCC toolchain or
# the CXXFLAGS_OPTIM = -O1 pin, none of which is an R package; those are set by
# _shared/hpc/arc_env.sh. Versions and seeds are therefore recorded by the process that
# actually fits the models, at the moment it fits them, with renv.lock restoring the
# library those versions name. les_check_lockfile() below compares the library a run
# loads with renv.lock, so a library changed after the restore shows in the record.
#
# HOW IT IS USED
# Paper 1's ERP fitting script (03_fit_brms_erp.R) and Paper 2's predictor fitting script
# (04_fit_brms_predictors.R) each call les_write_provenance() once per run. The other
# scripts that fit or refit models do not write this run-level file: Paper 1's
# 04_fit_brms_accuracy.R, and Paper 2's 05_fit_brms_prepost.R, 08_projpred_selection.R,
# 09b_compare_aperiodic_commonsample.R and 09c_compare_aperiodic_grouped.R. Each brms fit
# does, however, leave a per-fit record (les_p1_write_fit_meta() and
# les_p2_write_fit_meta() in the papers' _config.R, pooled into
# _pooled_fit_metadata.csv), so the gap is confined to the run-level file. Each call writes
# results/_provenance.csv, which each manuscript reads and injects inline, so the
# reported versions are those of the run that produced the results being reported,
# not of whatever machine happens to render the document. Where no provenance file
# exists yet the manuscripts print a marked placeholder, consistent with the
# render-anytime design.
#
# Paper 2's opt-in 06b_recover_provenance.R can also write results/_provenance.csv. It
# rebuilds the record from the version stamps the fitted objects carry and, for packages
# that leave no stamp, from the project library. Its file adds a `source` column and a
# `record_source` row saying the record was recovered.
# =============================================================================

# Packages whose version materially affects the results and must be reported: the
# fitting stack, and the data-handling packages the extraction and reshaping steps use.
LES_PROVENANCE_PKGS <- c("brms", "cmdstanr", "rstan", "StanHeaders", "posterior",
                         "loo", "projpred", "bayesplot", "mgcv", "MASS", "dplyr",
                         "tidyr", "readr", "readxl", "data.table", "stringr", "purrr")

# LES_* environment variables that hold paths. They locate the run, they do not
# configure it, and they would publish the cluster's directory layout, so the record
# leaves them out (as it leaves out any LES_* value that looks like a path).
.LES_PROVENANCE_PATH_VARS <- c("LES_PROJECT", "LES_BASE", "LES_DATA_ROOT", "LES_STORE",
                               "LES_RLIB", "LES_CODE_ROOT")

# -----------------------------------------------------------------------------
# les_check_lockfile()  --  does the loaded library match renv.lock?
# -----------------------------------------------------------------------------
# Compares the installed version of each package pinned in `lockfile` (the project's
# renv.lock by default) with the version the lockfile pins, taking for each package the
# first copy along .libPaths(), which is the one library() loads. `packages` restricts
# the check to a character vector of package names; NULL checks every pinned package.
# Returns, invisibly, a list with status ("checked", "absent" or "unreadable"),
# n_checked, differ (a character vector "<pkg> <installed> (locked <version>)") and
# not_installed (pinned packages absent from the library). An absent or unreadable
# lockfile, and any version that differs, raise a warning; with LES_REQUIRE_LOCKFILE=1
# they stop the run instead. A pinned package that is not installed is only reported,
# because the lockfile also pins packages that only the rendering box uses. The cluster
# copy of the code holds no renv.lock unless the deploy ships it, so the check can only
# be enforced there once it does. Reads the lockfile with jsonlite and the library
# with installed.packages(); writes nothing.
les_check_lockfile <- function(lockfile = file.path(if (exists(".les_root")) .les_root
                                                    else here::here(), "renv.lock"),
                               packages = NULL) {
  strict <- identical(Sys.getenv("LES_REQUIRE_LOCKFILE"), "1")
  complain <- function(msg) if (strict) stop(msg, call. = FALSE) else warning(msg, call. = FALSE)
  out <- list(status = "absent", n_checked = 0L, differ = character(0),
              not_installed = character(0))
  if (!file.exists(lockfile)) {
    complain(paste0("[lockfile] ", lockfile, " is absent, so the library this run loads ",
                    "cannot be checked against the pinned versions."))
    return(invisible(out))
  }
  lock <- tryCatch(jsonlite::fromJSON(lockfile, simplifyVector = FALSE),
                   error = function(e) NULL)
  if (is.null(lock) || is.null(lock$Packages)) {
    out$status <- "unreadable"
    complain(paste0("[lockfile] ", lockfile, " could not be read (is jsonlite installed?)."))
    return(invisible(out))
  }
  locked <- vapply(lock$Packages, function(p) as.character(p$Version), character(1))
  if (!is.null(packages)) locked <- locked[names(locked) %in% packages]
  inst <- utils::installed.packages(lib.loc = .libPaths(), fields = "Version")
  inst <- inst[!duplicated(inst[, "Package"]), , drop = FALSE]
  have <- stats::setNames(inst[, "Version"], inst[, "Package"])
  present <- names(locked) %in% names(have)
  out$status <- "checked"
  out$n_checked <- sum(present)
  out$not_installed <- sort(names(locked)[!present])
  diff <- present & have[names(locked)] != locked
  diff[is.na(diff)] <- FALSE
  out$differ <- sprintf("%s %s (locked %s)", names(locked)[diff], have[names(locked)[diff]],
                        locked[diff])
  if (length(out$differ)) {
    complain(paste0("[lockfile] ", length(out$differ), " installed package version(s) differ ",
                    "from renv.lock: ", paste(out$differ, collapse = "; ")))
  }
  invisible(out)
}

# MD5 of the analysis code a run sources: every .R file directly in _shared/R and in both
# papers' scripts/, with line endings normalised to LF so that a Windows checkout and the
# cluster copy of the same commit give the same value. Returns c(md5 = , n_files = ). The
# cluster copy holds no .git, so this is the identifier a run can record for the code it
# ran; recompute it over a checkout to find the commit.
.les_code_md5 <- function(root = if (exists(".les_root")) .les_root else here::here()) {
  dirs  <- file.path(root, c("_shared/R", "paper_1_transfer/scripts", "paper_2_plasticity/scripts"))
  files <- sort(unlist(lapply(dirs, list.files, pattern = "\\.R$", full.names = TRUE)),
                method = "radix")
  if (!length(files)) return(c(md5 = NA_character_, n_files = "0"))
  tmp <- tempfile()
  on.exit(unlink(tmp), add = TRUE)
  one <- vapply(files, function(f) {
    b <- readBin(f, "raw", n = file.info(f)$size)
    writeBin(b[b != as.raw(13)], tmp)
    unname(tools::md5sum(tmp))
  }, character(1))
  rel <- substring(files, nchar(root) + 2L)
  writeLines(paste(rel, one), tmp, sep = "\n", useBytes = TRUE)
  c(md5 = unname(tools::md5sum(tmp)), n_files = as.character(length(files)))
}

# -----------------------------------------------------------------------------
# les_write_provenance()  --  record R, package and Stan versions plus the seeds
# -----------------------------------------------------------------------------
# `results_dir` is the paper's results directory, a character scalar. `seeds` is a named
# list of the seed constants in force for this run, so the reproducibility claim in the
# manuscript is backed by a recorded value rather than by a constant in a script that may
# later change. `extra` is a named list of any further key/value pairs to record, written
# as further component/version rows (Paper 2's 04 passes models_sampled).
#
# Besides those, every call records, computed here so that no caller has to pass them:
# R and the platform; the version of each package in LES_PROVENANCE_PKGS that is
# installed; CmdStan; the sampling configuration of 01_bayesian_settings.R when it is
# loaded (backend, threads_per_chain, chains, iter_warmup, iter_sampling, adapt_delta,
# max_treedepth); CXXFLAGS_OPTIM as read from CmdStan's make/local at write time;
# the environment modules loaded (LOADEDMODULES, on the cluster); every LES_* variable
# set for the run other than the paths (as env:<NAME>), which names the variant switches;
# the outcome of les_check_lockfile(); and code_md5 and code_files from .les_code_md5().
#
# The file written is <results_dir>/_provenance.csv, with columns component, version and
# recorded_utc (the UTC time of the write, the same for every row). The same table is
# returned invisibly. Each value is converted with as.character(). Every call replaces the
# file whole and never appends to it; the table is written to a temporary file in the
# same folder and renamed over the old one, so a reader, or another array task writing at
# the same moment, never sees a half-written file (the last writer wins). With
# LES_PROVENANCE_SKIP=1 the function writes nothing and returns NULL invisibly; the two
# calling scripts also test that variable before calling. When les_assert_readonly_data()
# is defined, the target path is passed through it before the write, and a message giving
# the row count and the path follows the write.
les_write_provenance <- function(results_dir, seeds = list(), extra = list()) {
  if (identical(Sys.getenv("LES_PROVENANCE_SKIP"), "1")) {
    message("[provenance] LES_PROVENANCE_SKIP=1: results/_provenance.csv left untouched")
    return(invisible(NULL))
  }
  rows <- list()
  add <- function(component, version) {
    if (length(version) == 1L && !is.na(version) && nzchar(as.character(version))) {
      rows[[length(rows) + 1L]] <<- data.frame(component = component,
                                               version = as.character(version),
                                               stringsAsFactors = FALSE)
    }
  }
  add("R", paste0(R.version$major, ".", R.version$minor))
  add("platform", R.version$platform)

  for (p in LES_PROVENANCE_PKGS) {
    add(p, tryCatch(as.character(utils::packageVersion(p)), error = function(e) NA_character_))
  }

  # CmdStan itself is versioned separately from the cmdstanr interface.
  add("CmdStan", tryCatch(as.character(cmdstanr::cmdstan_version()),
                          error = function(e) NA_character_))

  for (nm in names(seeds)) add(paste0("seed:", nm), seeds[[nm]])

  # The sampling configuration actually in force (01_bayesian_settings.R).
  if (exists(".les_backend")) add("backend", .les_backend)
  if (exists(".les_threads_per_chain")) add("threads_per_chain", .les_threads_per_chain)
  if (exists("LES_CHAINS")) add("chains", LES_CHAINS)
  if (exists("LES_ITER_WARMUP")) add("iter_warmup", LES_ITER_WARMUP)
  if (exists("LES_ITER_SAMPLING")) add("iter_sampling", LES_ITER_SAMPLING)
  if (exists("LES_CONTROL")) {
    add("adapt_delta", LES_CONTROL$adapt_delta)
    add("max_treedepth", LES_CONTROL$max_treedepth)
  }

  # The optimisation pin of the CmdStan build, as make/local holds it now. It is the
  # value at write time; arc_env.sh writes it before the first compile.
  make_local <- tryCatch(file.path(cmdstanr::cmdstan_path(), "make", "local"),
                         error = function(e) NA_character_)
  if (!is.na(make_local) && file.exists(make_local)) {
    opt <- grep("^\\s*CXXFLAGS_OPTIM\\s*[:+?]?=", readLines(make_local, warn = FALSE),
                value = TRUE)
    add("CXXFLAGS_OPTIM", if (length(opt)) trimws(sub("^[^=]*=", "", opt[length(opt)]))
                          else "not set in make/local")
  }
  add("modules", Sys.getenv("LOADEDMODULES"))

  env <- Sys.getenv()
  les <- sort(names(env)[startsWith(names(env), "LES_")], method = "radix")
  les <- les[!les %in% .LES_PROVENANCE_PATH_VARS &
               !grepl("^(/|~|[A-Za-z]:[/\\\\])", env[les])]
  for (nm in les) add(paste0("env:", nm), env[[nm]])

  lk <- tryCatch(suppressWarnings(les_check_lockfile()), error = function(e) NULL)
  if (!is.null(lk)) {
    add("lockfile_check", if (lk$status != "checked") paste("renv.lock", lk$status) else
      sprintf("%d pinned packages installed; %d differ from renv.lock", lk$n_checked,
              length(lk$differ)))
    if (length(lk$differ)) add("lockfile_differs", paste(lk$differ, collapse = "; "))
  }

  code <- tryCatch(.les_code_md5(), error = function(e) c(md5 = NA_character_, n_files = NA))
  add("code_md5", code[["md5"]])
  add("code_files", code[["n_files"]])

  # A caller's own rows are written as given, an empty value included.
  for (nm in names(extra)) rows[[length(rows) + 1L]] <-
    data.frame(component = nm, version = as.character(extra[[nm]]), stringsAsFactors = FALSE)

  out <- do.call(rbind, rows)
  out$recorded_utc <- format(Sys.time(), tz = "UTC", usetz = TRUE)

  f <- file.path(results_dir, "_provenance.csv")
  if (exists("les_assert_readonly_data")) les_assert_readonly_data(f)
  tmp <- tempfile(pattern = "._provenance_", tmpdir = results_dir, fileext = ".csv")
  utils::write.csv(out, tmp, row.names = FALSE)
  if (!file.rename(tmp, f)) {
    ok <- file.copy(tmp, f, overwrite = TRUE)
    unlink(tmp)
    if (!ok) stop("[provenance] could not write ", f, call. = FALSE)
  }
  message("[provenance] wrote ", nrow(out), " rows to ", f)
  invisible(out)
}
