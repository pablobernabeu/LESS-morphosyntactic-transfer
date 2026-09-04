#!/bin/bash
# =============================================================================
# 99_diagnose_ice.slurm -- measure the cc1plus segfault that once killed 03_fit_erp
# -----------------------------------------------------------------------------
# In August 2026 tasks 0-11 of the p1_fit_erp array died with
#   g++: internal compiler error: Segmentation fault signal terminated program cc1plus
# while compiling the generated Stan model. This job compiles ONE such cell four ways
# on a compute node -- with and without within-chain threading, at the CmdStan default
# (-O3) and at -O1 -- and reports which combinations build. Read-only with respect to
# results/: it writes only into a scratch directory ($LES_STORE/../ice_diag).
#
# WHAT IT FOUND (2026-08-04, job 12684901; 99b_test_O2.slurm added -O2 afterwards)
#   threading    + -O3  ICE after 19 s     threading    + -O2  ICE after 4 s
#   threading    + -O1  builds in 90 s
#   no threading + -O3  builds in 82 s     no threading + -O1  builds in 38 s
# So it is a GCC 14.2.0 bug instantiating Stan's reduce_sum templates above -O1, not a
# resource limit: peak RSS was under 2 GB against a 96 GB allocation. les_brm() uses
# within-chain threading, so -O1 is the only workable level, and _shared/hpc/arc_env.sh
# now appends `CXXFLAGS_OPTIM = -O1` to $CMDSTAN/make/local on every job. The ERP fits
# completed on 2026-08-06 with no recurrence.
#
# The script is retained to re-measure after a toolchain upgrade (HPC_RUNBOOK.md,
# "internal compiler error"). Run it on a compute node: login nodes cap ulimit -v at
# 2 GB, so any large compile fails there for an unrelated reason.
#
# Submit:  sbatch paper_1_transfer/hpc/99_diagnose_ice.slurm
# =============================================================================
#SBATCH --job-name=p1_ice_diag
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=12G
#SBATCH --time=00:40:00
#SBATCH -o paper_1_transfer/hpc/logs/99_diagnose_ice.out

source _shared/hpc/arc_env.sh
# NO errexit: the whole point is to run compiles that are expected to fail.
set -o nounset

D=$LES_STORE/../ice_diag
mkdir -p "$D" paper_1_transfer/hpc/logs
echo "[diag] node=$(hostname) date=$(date)"
echo "[diag] ulimit -s = $(ulimit -s) | ulimit -v = $(ulimit -v)"
echo "[diag] TMPDIR=${TMPDIR:-unset} | /tmp free = $(df -h /tmp | tail -1)"
echo "[diag] CMDSTAN=$CMDSTAN"
g++ --version | head -1

# --- Generate the Stan code for one failing cell, threaded and serial ---------
Rscript -e "
suppressPackageStartupMessages({
  source(here::here(\"_shared\",\"R\",\"00_paths.R\"))
  source(here::here(\"_shared\",\"R\",\"01_bayesian_settings.R\"))
  source(here::here(\"_shared\",\"R\",\"02_diagnostics.R\"))
  source(here::here(\"paper_1_transfer\",\"scripts\",\"_config.R\"))
  source(here::here(\"paper_1_transfer\",\"scripts\",\"03_fit_brms_erp.R\"))
  library(dplyr)
})
d <- readRDS(les_p1_cell_rds(\"gender_agreement\",\"200_500\",\"lateral\")) |>
  mutate(participant_lab_ID = factor(participant_lab_ID), item_id = factor(item_id)) |>
  tidyr::drop_na(dplyr::all_of(les_p1_erp_model_vars(\"lateral\")))
cat(\"[diag] cell rows =\", nrow(d), \"\n\")
f  <- les_p1_erp_formula(\"lateral\")
pr <- les_erp_prior(\"200_500\",\"gender_agreement\",\"lateral\")
writeLines(as.character(brms::make_stancode(f, d, gaussian(), prior = pr,
           threads = brms::threading(2))), \"$D/threaded.stan\")
writeLines(as.character(brms::make_stancode(f, d, gaussian(), prior = pr)), \"$D/serial.stan\")
cat(\"[diag] wrote Stan code\n\")
" 2>&1 | tail -5

wc -l "$D"/threaded.stan "$D"/serial.stan

# --- Compile each variant, timing it and recording the outcome ----------------
try_build () {         # $1 label   $2 stan stem   $3... extra make vars
  local label="$1"; shift
  local stem="$1";  shift
  rm -f "${stem}" "${stem}.hpp" "${stem}.o"
  echo; echo "########## $label ##########"
  local t0=$SECONDS
  ( cd "$CMDSTAN" && make "$@" "${stem}" ) > "$D/${label}.log" 2>&1
  local rc=$?
  echo "[diag] $label rc=$rc elapsed=$((SECONDS-t0))s"
  if [ $rc -ne 0 ]; then
    echo "[diag] --- tail of $label.log ---"; tail -12 "$D/${label}.log"
  else
    echo "[diag] BUILT: $(ls -la "${stem}" 2>/dev/null)"
  fi
}

try_build "A_threaded_default" "$D/threaded" STAN_THREADS=true
try_build "B_threaded_O1"      "$D/threaded" STAN_THREADS=true CXXFLAGS_OPTIM=-O1
try_build "C_serial_default"   "$D/serial"
try_build "D_serial_O1"        "$D/serial"   CXXFLAGS_OPTIM=-O1

echo; echo "[diag] done $(date)"
