#!/bin/bash
# =============================================================================
# _shared/hpc/00_restore_environment.slurm  --  rebuild the recorded environment
# -----------------------------------------------------------------------------
# The reproduction route. Restores the project R library from the repository's
# renv.lock at the recorded versions and builds CmdStan at the version of record
# (LES_CMDSTAN_RECORD in arc_env.sh, 2.39.0), the release every reported fit was compiled
# by. It runs the renv bootstrap, restore and CmdStan build lines that HPC_RUNBOOK.md
# gives in section 0, with three additions: the renv that carries out the restore is the
# version renv.lock pins, the running R is checked against the version renv.lock records
# before anything is installed, and the built CmdStan is checked against the version
# asked for. The 00_install_dependencies.slurm job in either paper's hpc/ is the
# bootstrap for a library where none exists yet; it pins nothing and is not this route.
#
# Before submitting, put renv.lock beside the code root, from the dev box:
#   scp renv.lock arc:new_LESS/
# The code scp carries neither renv.lock nor .Rprofile nor renv/, so renv is never
# activated on the cluster and both the lockfile and the target library are named
# explicitly. The library argument is the whole search path, .libPaths(), because the
# snapshot was taken across the R module's own library as well as R_LIBS_USER; a restore
# confined to R_LIBS_USER would reinstall every package the lockfile pinned from the
# module.
#
# renv::restore() (checked in renv 1.2.3) does not compare the running R with the R
# version renv.lock records, so this job does, and stops before restoring when the two
# differ. Export LES_RESTORE_ALLOW_R_MISMATCH=1 to restore under a different R anyway.
#
# LES_CMDSTAN_VERSION is exported after arc_env.sh has been sourced. With the variable
# set, arc_env.sh stops when the named tree is absent, which on a fresh environment it
# still is at that point. sbatch passes the submitting shell's environment through by
# default, so an inherited value is cleared before arc_env.sh is sourced. Later jobs need
# no export: arc_env.sh selects the version-of-record tree built here whenever it exists,
# and exporting LES_CMDSTAN_VERSION in a fitting job only makes its absence fatal. The
# CXXFLAGS_OPTIM = -O1 pin is written to the new tree's make/local by the first job that
# sources arc_env.sh after this one.
#
# Needs outbound network and the gfbf/2025a compiler that the R module supplies.
#   sbatch _shared/hpc/00_restore_environment.slurm
#
# LOG: paper_1_transfer/hpc/logs/00_restore_environment.out, as rebuild_cmdstan.slurm
# does. Slurm opens that file when the job starts, so on a fresh checkout create the
# directory before submitting:  mkdir -p paper_1_transfer/hpc/logs
# =============================================================================
#SBATCH --job-name=les_restore_env
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=4G
#SBATCH --time=08:00:00
#SBATCH -o paper_1_transfer/hpc/logs/00_restore_environment.out

# An inherited LES_CMDSTAN_VERSION is cleared here and set again after the restore (see
# the header).
unset LES_CMDSTAN_VERSION
source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

if [ ! -f renv.lock ]; then
  echo "[restore] FATAL: no renv.lock beside the code root (${LES_CODE_ROOT}); scp it from the dev box first" >&2
  exit 1
fi

# renv's package cache defaults to a directory under $HOME, which is quota-limited on the
# cluster. With the cache disabled the restore installs plain copies into the library and
# puts nothing into that cache.
export RENV_CONFIG_CACHE_ENABLED=FALSE

# renv has to be present before it can restore anything, and the restore engine is itself
# a source of variation: how renv resolves sources and records versions changes between
# releases. So the renv installed here is the version renv.lock pins, read from the
# lockfile, from CRAN or, once superseded, from CRAN's archive. Only if neither can be
# reached does it fall back to CRAN's current release, saying so in the log; the restore
# then reinstalls the pinned renv along with everything else.
Rscript --vanilla - <<'RS'
txt <- paste(readLines("renv.lock", warn = FALSE), collapse = "\n")
pin <- regmatches(txt, regexec('"renv"\\s*:\\s*\\{\\s*"Package"\\s*:\\s*"renv"\\s*,\\s*"Version"\\s*:\\s*"([^"]+)"', txt))[[1]][2]
if (is.na(pin)) stop("renv.lock records no renv version")
have <- if (requireNamespace("renv", quietly = TRUE)) as.character(packageVersion("renv")) else NA
if (!identical(have, pin)) {
  cran <- "https://cloud.r-project.org/src/contrib"
  for (u in sprintf(c("%s/renv_%s.tar.gz", "%s/Archive/renv/renv_%s.tar.gz"), cran, pin)) {
    tgz <- file.path(tempdir(), basename(u))
    if (!inherits(try(download.file(u, tgz, quiet = TRUE), silent = TRUE), "try-error")) {
      install.packages(tgz, repos = NULL, type = "source")
      break
    }
  }
  if (!requireNamespace("renv", quietly = TRUE) || as.character(packageVersion("renv")) != pin) {
    message("[restore] WARNING: renv ", pin, " could not be installed; restoring with CRAN's current renv")
    install.packages("renv", repos = "https://cloud.r-project.org")
  }
}
message("[restore] restore engine: renv ", as.character(packageVersion("renv")), " (renv.lock pins ", pin, ")")
RS

# Stop before restoring when this R is not the one renv.lock records (see the header).
Rscript --vanilla -e 'rec <- renv::lockfile_read("renv.lock")$R$Version; cur <- format(getRversion()); if (!identical(rec, cur) && Sys.getenv("LES_RESTORE_ALLOW_R_MISMATCH") != "1") stop(sprintf("renv.lock was snapshotted under R %s but this job runs R %s", rec, cur))'

echo "[restore] restoring renv.lock into R_LIBS_USER=${R_LIBS_USER} on $(hostname)"
Rscript --vanilla -e 'renv::restore(lockfile = "renv.lock", library = .libPaths(), prompt = FALSE)'
export LES_CMDSTAN_VERSION="${LES_CMDSTAN_RECORD}"
Rscript --vanilla -e 'cmdstanr::install_cmdstan(version = Sys.getenv("LES_CMDSTAN_VERSION"), dir = Sys.getenv("CMDSTAN_INSTALL_DIR"))'

if [ ! -d "${LES_BASE}/cmdstan/cmdstan-${LES_CMDSTAN_VERSION}" ]; then
  echo "[restore] FATAL: ${LES_BASE}/cmdstan/cmdstan-${LES_CMDSTAN_VERSION} was not built" >&2
  exit 1
fi
# The directory can exist after a build that failed part-way, so ask CmdStan itself.
Rscript --vanilla -e 'want <- Sys.getenv("LES_CMDSTAN_VERSION"); cmdstanr::set_cmdstan_path(file.path(Sys.getenv("CMDSTAN_INSTALL_DIR"), paste0("cmdstan-", want))); got <- cmdstanr::cmdstan_version(); if (!identical(got, want)) stop(sprintf("CmdStan reports version %s, not %s", got, want))'
echo "[restore] library restored from renv.lock and CmdStan ${LES_CMDSTAN_VERSION} built, $(date)"
