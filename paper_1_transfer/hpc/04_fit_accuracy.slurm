#!/bin/bash
# =============================================================================
# 04_fit_accuracy.slurm  --  fit the Bayesian accuracy models (SLURM job array, ARC)
# -----------------------------------------------------------------------------
# One array task per grammatical property (3 tasks). Each reads
# accuracy_<property>.rds and fits the brms Bernoulli (logit) model, writing the
# fit plus convergence/summary/PPC artefacts into $LES_STORE/paper_1_transfer/results.
#
# Submit AFTER 02 completes:  sbatch paper_1_transfer/hpc/04_fit_accuracy.slurm
# The crossed by-item variant (LES_P1_ACC_ITEM=1) needs the item_id column that 02 writes;
# 04 stops with a message when the derived file predates it.
# =============================================================================
#SBATCH --job-name=p1_fit_accuracy
#SBATCH --partition=long
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=6G
#SBATCH --time=2-00:00:00
#SBATCH --array=0-2
#SBATCH -o paper_1_transfer/hpc/logs/04_fit_accuracy_%A_%a.out

source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

# 4 chains x 2 threads/chain = 8 CPUs. The thread count also sets brms's grainsize in the
# Stan data, so it is pinned (changing it invalidates the cached fits) and a mismatch with
# the allocation is only reported.
export LES_THREADS_PER_CHAIN=2
if [ $((4 * LES_THREADS_PER_CHAIN)) -ne "${SLURM_CPUS_PER_TASK:-8}" ]; then
  echo "WARNING: 4 chains x ${LES_THREADS_PER_CHAIN} threads differs from --cpus-per-task=${SLURM_CPUS_PER_TASK:-?}" >&2
fi

PARAMS=(
  "gender_agreement"
  "differential_object_marking"
  "verb_object_number_agreement"
)
PROP="${PARAMS[$SLURM_ARRAY_TASK_ID]}"

# Variant fits (e.g. LES_PRIOR_SET=weak, LES_P1_ACC_DIVERSITY=1, LES_P1_ACC_ITEM=1) write
# their own logs so the mainline fit logs are never overwritten by a resubmission. The
# order follows model_tag in 04_fit_brms_accuracy.R.
TAG=""
[ "${LES_P1_ACC_DIVERSITY:-0}" = "1" ] && TAG="${TAG}_diversity"
[ "${LES_P1_ACC_RT_SCREEN:-0}" = "1" ] && TAG="${TAG}_rtscreen"
[ "${LES_P1_ACC_MAXRANEF:-0}" = "1" ]  && TAG="${TAG}_maxranef"
[ "${LES_P1_ACC_ITEM:-0}" = "1" ]      && TAG="${TAG}_byitem"
[ "${LES_PRIOR_SET:-informative}" = "weak" ] && TAG="${TAG}_weakprior"
echo "[array ${SLURM_ARRAY_TASK_ID}] ${PROP} | threads/chain=${LES_THREADS_PER_CHAIN} | start $(date)"

Rscript "paper_1_transfer/scripts/04_fit_brms_accuracy.R" "${PROP}" \
    > "paper_1_transfer/hpc/logs/04_fit_accuracy_${PROP}${TAG}.Rout" 2>&1

echo "[array ${SLURM_ARRAY_TASK_ID}] finished $(date)"
