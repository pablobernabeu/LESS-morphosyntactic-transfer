#!/bin/bash
# =============================================================================
# _shared/hpc/arc_env.sh  --  Oxford cluster runtime environment for the LESS pipelines
# -----------------------------------------------------------------------------
# SOURCED at the top of every SLURM job script in both papers. It is the single place
# that encodes the cluster layout decided for this project:
#
#   * CORE SCRIPTS live on personal disk   ->  $HOME/new_LESS            (code root)
#   * HEAVY MATERIAL lives in LESS's OWN folder inside the (shared, multi-project)
#     project /data area -- $LES_BASE, defined below -- kept self-contained
#     like the other projects there (the shared root is left untouched):
#       packages       ->  new_LESS/Rlib/R-4.5         (R library, R_LIBS_USER)
#       CmdStan        ->  new_LESS/cmdstan/cmdstan-*   (Stan C++ toolchain, CMDSTAN)
#       input data     ->  new_LESS/data/              (read-only, LES_DATA_ROOT)
#       model outputs  ->  new_LESS/store/             (derived/results/figures, LES_STORE)
#
# Both Oxford clusters use ENVIRONMENT MODULES, not Singularity: we `module load` R
# (the -gfbf-2025a build brings the gfbf/2025a toolchain, GCC 14.2.0 with OpenBLAS,
# FlexiBLAS and FFTW, needed to compile the Stan models at run time; gfbf is not foss,
# which adds OpenMPI and ScaLAPACK on top of it) and point R at the project-space
# library + CmdStan via R_LIBS_USER / CMDSTAN. The project space is mounted at the same
# path on ARC and on HTC, so the settings below serve both clusters. The file name
# predates the 2026-06-30 move to HTC and is kept because every job script sources it by
# that path.
#
# What differs between the two is the submission line, which this file does not control.
# ARC needs no --account flag, project access coming through the `educ-intract` unix
# group, whereas HTC requires `sbatch --clusters=htc --account=educ-intract`. The
# per-paper hpc/README.md files carry the recipes.
#
# The two versions of record, the R module and the CmdStan release every reported fit was
# compiled by, are written once, just below. The R library's "R-4.5" label is derived from
# the module name, because packages built for one minor version (4.5.x) will not load under
# another (e.g. the legacy 4.4 library), and the R that the module actually supplies is
# checked against it before anything runs.
#
# SIDE EFFECTS, worth knowing before sourcing this in an interactive shell: it runs
# `module purge`, which unloads whatever modules the shell had; it cds to the code root
# (LES_CODE_ROOT); it creates the R library and store directories when they are missing,
# and a `data` symlink in the code root (below); and on the first run after CmdStan is
# built it appends the -O1 pin to CmdStan's make/local. When a check fails it stops a
# batch job with `exit 1`, but in an interactive shell it returns instead, so the login
# session survives.
# =============================================================================

LES_R_MODULE="R/4.5.1-gfbf-2025a"
LES_CMDSTAN_RECORD="2.39.0"
export LES_CMDSTAN_RECORD

# _les_fatal <message>
#   Prints the message to stderr and ends the job. In an interactive shell, where `exit`
#   would close the user's session, it returns 1 instead, and every caller below follows it
#   with `|| return 1`, which then leaves this sourced file.
_les_fatal() {
  echo "[arc_env] FATAL: $*" >&2
  if [[ $- == *i* ]]; then return 1; else exit 1; fi
}

# --- Software environment ----------------------------------------------------
module purge 2>/dev/null || true
module load "${LES_R_MODULE}" || { _les_fatal "module load ${LES_R_MODULE} failed" || return 1; }
# Record what that single module load actually brought in. With no container image, the
# loaded module list is this project's closest equivalent to an image tag, and the GCC it
# supplies is what the -O1 pin below works around. The resolved Rscript is echoed at the
# foot of this file, so between the two the log says both which R ran and which toolchain
# stood behind it.
echo "[arc_env] modules   : ${LOADEDMODULES:-<none loaded>}"
# A module that loads without error can still leave no Rscript, or another R, on PATH
# (a renamed module, a stale Lmod cache on a node). Either would surface much later as
# "Rscript: command not found", or as packages built for 4.5 failing to load, or, if the
# minor version happened to match, as a run on an unrecorded build of R.
[[ "${LES_R_MODULE}" =~ ^R/([0-9]+\.[0-9]+) ]] || { _les_fatal "cannot read a major.minor version from ${LES_R_MODULE}" || return 1; }
LES_R_SERIES="${BASH_REMATCH[1]}"
command -v Rscript >/dev/null 2>&1 || { _les_fatal "no Rscript on PATH after module load ${LES_R_MODULE}" || return 1; }
_les_r_running="$(Rscript --vanilla -e 'cat(R.version$major, ".", sub("[.].*", "", R.version$minor), sep = "")' 2>/dev/null || true)"
[ "${_les_r_running}" = "${LES_R_SERIES}" ] ||
  { _les_fatal "R on PATH is ${_les_r_running:-unknown}, but ${LES_R_MODULE} and the library label expect ${LES_R_SERIES}" || return 1; }
unset _les_r_running

# --- LESS's own folder inside the SHARED project area ------------------------
# LES_PROJECT is a shared, multi-project personal area, and the line below is the single
# place in the compendium where that root is written out; every other file refers to
# $LES_BASE. LESS keeps ALL of its heavy material self-contained under its own folder
# there, so the shared root is never cluttered.
export LES_PROJECT="/data/educ-intract/educ1242"   # shared multi-project area (do NOT clutter root)
export LES_BASE="${LES_PROJECT}/new_LESS"           # LESS's own folder -- all heavy material here
export LES_DATA_ROOT="${LES_BASE}/data"
export LES_STORE="${LES_BASE}/store"
export LES_RLIB="${LES_BASE}/Rlib/R-${LES_R_SERIES}"
export R_LIBS_USER="${LES_RLIB}"
mkdir -p "${LES_RLIB}" "${LES_STORE}"
# R also reads ${LES_CODE_ROOT}/.Rprofile at startup, and that file hands the library
# paths to renv once renv/activate.R exists AND renv/library is populated, which would
# override the R_LIBS_USER just set. The cluster copy is scp'd without .Rprofile or renv/
# (HPC_RUNBOOK.md, section 0), so this does not arise here, and on a full git clone the
# guard stays false until someone runs renv::restore(). Either restore into the renv
# library and let renv own the paths, or keep ${LES_RLIB} and leave renv/library empty.

# CmdStan toolchain, chosen in this order:
#   1. LES_CMDSTAN_VERSION, when set: that exact tree, and the job stops here if it is
#      absent rather than falling back to a different CmdStan;
#   2. the version of record, LES_CMDSTAN_RECORD above, when its tree exists;
#   3. otherwise the highest installed version, with a warning in the log, which is the
#      case on a library bootstrapped by the unpinned installer.
# Before 3 October 2026 the highest installed version always won, so a newer CmdStan
# installed beside 2.39.0 would have re-pointed every later fit without saying so. On that
# date cmdstan-2.39.0 was the only tree installed, and both papers' results/_provenance.csv
# record it (component "CmdStan"), so the change of rule changes no fit. The version a run
# actually used is always in that file.
_les_trees=( "${LES_BASE}"/cmdstan/cmdstan-* )
if [ -n "${LES_CMDSTAN_VERSION:-}" ]; then
  [ -d "${LES_BASE}/cmdstan/cmdstan-${LES_CMDSTAN_VERSION}" ] ||
    { _les_fatal "LES_CMDSTAN_VERSION=${LES_CMDSTAN_VERSION} requested but ${LES_BASE}/cmdstan/cmdstan-${LES_CMDSTAN_VERSION} is absent" || return 1; }
  export CMDSTAN="${LES_BASE}/cmdstan/cmdstan-${LES_CMDSTAN_VERSION}"
elif [ -d "${LES_BASE}/cmdstan/cmdstan-${LES_CMDSTAN_RECORD}" ]; then
  export CMDSTAN="${LES_BASE}/cmdstan/cmdstan-${LES_CMDSTAN_RECORD}"
elif [ -d "${_les_trees[0]}" ]; then
  export CMDSTAN="$(printf '%s\n' "${_les_trees[@]}" | sort -V | tail -1)"
  echo "[arc_env] WARNING: CmdStan ${LES_CMDSTAN_RECORD}, the version of record, is not installed; using ${CMDSTAN##*/}" >&2
else
  export CMDSTAN=""
fi
unset _les_trees
# Where 00_install builds CmdStan if it is missing (see install_bayesian_dependencies.R).
export CMDSTAN_INSTALL_DIR="${LES_BASE}/cmdstan"
# Every reported fit sampled through cmdstanr with reduce_sum threading (both papers'
# _provenance.csv record cmdstanr 0.9.0). Without cmdstanr, brms would fall back to rstan,
# which runs without that threading and does not reproduce the reported draws, so a job
# that sources _shared/R/01_bayesian_settings.R stops there instead (ISSUES.md X2-04). A
# deliberate rstan run can still export LES_REQUIRE_CMDSTANR=0. The install route
# (install_bayesian_dependencies.R) does not source that file, so it is unaffected.
export LES_REQUIRE_CMDSTANR="${LES_REQUIRE_CMDSTANR:-1}"

# --- Compiler workaround: GCC 14.2.0 ICE on reduce_sum above -O1 -------------
# GCC 14.2.0 (the compiler in the R/4.5.1-gfbf-2025a toolchain) segfaults in cc1plus
# while instantiating Stan's reduce_sum templates at -O2 and -O3. It is a compiler
# crash, not a resource limit: it reproduces in 2-19 s on a compute node with an
# unlimited stack, unlimited virtual memory and 100 GB free in /tmp, and the peak
# RSS is under 2 GB against a 96 GB allocation. Measured on 2026-08-04 on one ERP cell
# by paper_1_transfer/hpc/99_diagnose_ice.slurm (-O3 and -O1, threaded and serial) and
# by its follow-up 99b_test_O2.slurm (-O2, threaded):
#
#     threading + -O3  ICE (19 s)     threading + -O2  ICE (4 s)
#     threading + -O1  builds (90 s)  no threading + -O3  builds (82 s)
#
# The models use within-chain threading (les_brm passes brms::threading()), so -O1
# is the only optimisation level that compiles. Sampling is correspondingly slower;
# the alternative would be to drop threading and keep -O3, which changes the
# reduce_sum reduction order and so the exact draws, whereas the optimisation level
# does not. Pinning -O1 therefore keeps the sampler configuration identical to the
# fits already in results/. Revisit if the cluster's GCC is upgraded.
#
# Note the sequencing on a fresh install: the pin is written only once CmdStan is on
# disk, so the 00_install job, which sources this file before building it, leaves
# make/local alone and the first fitting job afterwards adds the line. Nothing is lost
# by that, since the ICE arises when a generated model's reduce_sum templates are
# instantiated and the CmdStan core built without incident at the default level.
if [ -n "${CMDSTAN}" ] && [ -d "${CMDSTAN}/make" ]; then
  # The test below is for the presence of a CXXFLAGS_OPTIM assignment, not for its value,
  # so a make/local that already sets it to anything else is left alone. That is
  # intentional, since a deliberate override should survive, but it means the pin can be
  # silently absent. The echo after it reports the value actually in force, which is also
  # what puts the optimisation level into the log of every run rather than only the first.
  # The pattern names the variable exactly: a bare prefix would also match
  # CXXFLAGS_OPTIM_TBB or CXXFLAGS_OPTIM_SUNDIALS, CmdStan variables of their own, and
  # would then suppress the pin and report the wrong line.
  _les_optim='^[[:space:]]*CXXFLAGS_OPTIM[[:space:]]*[:+?]?='
  if ! grep -qsE "${_les_optim}" "${CMDSTAN}/make/local" 2>/dev/null; then
    echo 'CXXFLAGS_OPTIM = -O1' >> "${CMDSTAN}/make/local"
    echo "[arc_env] pinned CXXFLAGS_OPTIM = -O1 in ${CMDSTAN}/make/local (GCC 14.2.0 reduce_sum ICE)"
  fi
  echo "[arc_env] CXXFLAGS  : $(grep -sE "${_les_optim}" "${CMDSTAN}/make/local" 2>/dev/null || echo '<unset -- CmdStan default>')"
  unset _les_optim
fi

# --- Code (personal-disk) root -----------------------------------------------
# Jobs are submitted from the code root; default to ~/new_LESS but respect the
# SLURM submit directory if the user keeps the code elsewhere.
export LES_CODE_ROOT="${LES_CODE_ROOT:-${SLURM_SUBMIT_DIR:-$HOME/new_LESS}}"
cd "${LES_CODE_ROOT}" || { _les_fatal "cannot cd to LES_CODE_ROOT=${LES_CODE_ROOT}" || return 1; }

# Legacy single-trial loaders (data/R_functions, data/importation and preprocessing)
# read the data tree by paths RELATIVE to the code root (e.g. "data/Participant IDs
# and session progress.csv") -- a convention predating the code/heavy split. Expose
# the project-space data here as a symlink (a pointer, not a copy) so those relative
# reads resolve without modifying the validated loaders.
if [ ! -e data ]; then ln -s "${LES_DATA_ROOT}" data 2>/dev/null || true; fi

echo "[arc_env] Rscript   : $(command -v Rscript) (R ${LES_R_SERIES}, ${LES_R_MODULE})"
echo "[arc_env] code root : ${LES_CODE_ROOT}"
echo "[arc_env] data root : ${LES_DATA_ROOT}"
echo "[arc_env] store     : ${LES_STORE}"
echo "[arc_env] R_LIBS_USER: ${R_LIBS_USER}"
echo "[arc_env] CMDSTAN   : ${CMDSTAN:-<none installed yet>}"
unset -f _les_fatal
