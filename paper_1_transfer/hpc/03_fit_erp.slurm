#!/bin/bash
# =============================================================================
# 03_fit_erp.slurm  --  fit the per-cell Bayesian ERP models (SLURM job array, ARC)
# -----------------------------------------------------------------------------
# One array task per ERP cell = grammatical property x time window x macroregion
# (3 x 3 x 2 = 18 tasks). Each task reads the corresponding .rds produced by
# 01_extract_erp.slurm and fits the brms Gaussian single-trial model, writing the
# fitted object plus convergence/summary/PPC artefacts into
# $LES_STORE/paper_1_transfer/results.
#
# Resourcing: les_brm() runs LES_CHAINS = 4 chains in parallel, each with
# LES_THREADS_PER_CHAIN within-chain threads, so --cpus-per-task = 4 * THREADS
# (Stan reduce_sum; Carpenter et al., 2017, https://doi.org/10.18637/jss.v076.i01).
# The `long` partition is required (its maximum is 30 days, but the default is 1 day,
# so --time is set explicitly). --mem-per-cpu multiplies by --cpus-per-task, so the
# request is 8 x 12G = 96 GB per task, ample for the single-trial models.
#
# Submit AFTER 01 completes:  sbatch paper_1_transfer/hpc/03_fit_erp.slurm
# =============================================================================
#SBATCH --job-name=p1_fit_erp
#SBATCH --partition=long
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=12G
#SBATCH --time=5-00:00:00
#SBATCH --array=0-17
#SBATCH -o paper_1_transfer/hpc/logs/03_fit_erp_%a.out

source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

# 4 chains x 2 threads/chain = 8 CPUs (matches --cpus-per-task above).
export LES_THREADS_PER_CHAIN=2

# Variant fits (e.g. LES_P1_RETENTION_FREE=1) write their own logs so the
# mainline fit logs are never overwritten by a resubmission. The mis-filter-
# retained tag comes first, mirroring cell_tag in 03_fit_brms_erp.R.
TAG=""
[ "${LES_P1_KEEP_MISFILTERED:-0}" = "1" ] && TAG="${TAG}_keepmisfiltered"
[ "${LES_P1_RETENTION_FREE:-0}" = "1" ] && TAG="${TAG}_retfree"
[ "${LES_P1_ITEM_SLOPE:-0}" = "1" ]     && TAG="${TAG}_itemslope"

# Array index -> (property window macroregion). Enumerated property-major, then
# window, then macroregion, so the mapping is stable across resubmissions.
PARAMS=(
  "gender_agreement 200_500 lateral"
  "gender_agreement 200_500 midline"
  "gender_agreement 300_600 lateral"
  "gender_agreement 300_600 midline"
  "gender_agreement 400_900 lateral"
  "gender_agreement 400_900 midline"
  "differential_object_marking 200_500 lateral"
  "differential_object_marking 200_500 midline"
  "differential_object_marking 300_600 lateral"
  "differential_object_marking 300_600 midline"
  "differential_object_marking 400_900 lateral"
  "differential_object_marking 400_900 midline"
  "verb_object_number_agreement 200_500 lateral"
  "verb_object_number_agreement 200_500 midline"
  "verb_object_number_agreement 300_600 lateral"
  "verb_object_number_agreement 300_600 midline"
  "verb_object_number_agreement 400_900 lateral"
  "verb_object_number_agreement 400_900 midline"
)
read -r PROP WIN MACRO <<< "${PARAMS[$SLURM_ARRAY_TASK_ID]}"
echo "[array ${SLURM_ARRAY_TASK_ID}] ${PROP} ${WIN} ${MACRO} | threads/chain=${LES_THREADS_PER_CHAIN} | start $(date)"

Rscript "paper_1_transfer/scripts/03_fit_brms_erp.R" "${PROP}" "${WIN}" "${MACRO}" \
    > "paper_1_transfer/hpc/logs/03_fit_erp_${PROP}_${WIN}_${MACRO}${TAG}.Rout" 2>&1

echo "[array ${SLURM_ARRAY_TASK_ID}] finished $(date)"
