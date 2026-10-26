#!/bin/bash
# =============================================================================
# 03b_prior_predictive.slurm  --  export the prior predictive check as data (HTC)
# -----------------------------------------------------------------------------
# Runs scripts/03b_export_prior_predictive.R: a prior-only brms model of the representative
# ERP cell (gender agreement, 400-900 ms, midline) under the informative priors and the
# maximal structure the manuscript reports, and writes results/_prior_predictive_check.csv
# and results/_prior_predictive_check_meta.csv, from which the manuscript draws its prior
# predictive figure. It reads the cell's derived data from step 01 and does not read or
# write any fitted model.
#
# Resourcing: two chains in parallel without within-chain threading, so two CPUs. The
# prior-only model samples no likelihood, so the run is short.
#
# Submit from the code root, standard QoS:
#   sbatch --clusters=htc --account=educ-lift \
#     --export=ALL,LES_CODE_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo unknown) \
#     paper_1_transfer/hpc/03b_prior_predictive.slurm
# =============================================================================
#SBATCH --job-name=p1_priorpc
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=8G
#SBATCH --time=02:00:00
#SBATCH -o paper_1_transfer/hpc/logs/03b_prior_predictive_%j.out

source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

# The manuscript reports the maximal structure, and the script refuses to run without it.
export LES_P1_ITEM_SLOPE=1
echo "[priorpc] start $(date) | commit ${LES_CODE_COMMIT:-unset}"
Rscript "paper_1_transfer/scripts/03b_export_prior_predictive.R" \
    > "paper_1_transfer/hpc/logs/03b_prior_predictive_${SLURM_JOB_ID}.Rout" 2>&1
echo "[priorpc] finished $(date)"
