#!/bin/bash
# =============================================================================
# 04_fit_accuracy.slurm  --  fit the Bayesian accuracy models (SLURM job array, ARC)
# -----------------------------------------------------------------------------
# One array task per grammatical property (3 tasks). Each reads
# accuracy_<property>.rds and fits the brms Bernoulli (logit) model, writing the
# fit plus convergence/summary/PPC artefacts into $LES_STORE/paper_1_transfer/results.
#
# Submit AFTER 02 completes:  sbatch paper_1_transfer/hpc/04_fit_accuracy.slurm
# =============================================================================
#SBATCH --job-name=p1_fit_accuracy
#SBATCH --partition=long
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=6G
#SBATCH --time=2-00:00:00
#SBATCH --array=0-2
#SBATCH -o paper_1_transfer/hpc/logs/04_fit_accuracy_%a.out

source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

# 4 chains x 2 threads/chain = 8 CPUs.
export LES_THREADS_PER_CHAIN=2

PARAMS=(
  "gender_agreement"
  "differential_object_marking"
  "verb_object_number_agreement"
)
PROP="${PARAMS[$SLURM_ARRAY_TASK_ID]}"

# Variant fits (e.g. LES_PRIOR_SET=weak, LES_P1_ACC_DIVERSITY=1) write their own
# logs so the mainline fit logs are never overwritten by a resubmission.
TAG=""
[ "${LES_P1_ACC_DIVERSITY:-0}" = "1" ] && TAG="${TAG}_diversity"
[ "${LES_PRIOR_SET:-}" = "weak" ]      && TAG="${TAG}_weak"
echo "[array ${SLURM_ARRAY_TASK_ID}] ${PROP} | threads/chain=${LES_THREADS_PER_CHAIN} | start $(date)"

Rscript "paper_1_transfer/scripts/04_fit_brms_accuracy.R" "${PROP}" \
    > "paper_1_transfer/hpc/logs/04_fit_accuracy_${PROP}${TAG}.Rout" 2>&1

echo "[array ${SLURM_ARRAY_TASK_ID}] finished $(date)"
