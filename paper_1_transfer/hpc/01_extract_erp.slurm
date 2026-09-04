#!/bin/bash
# =============================================================================
# 01_extract_erp.slurm  --  single-trial ERP extraction (SLURM job array, ARC)
# -----------------------------------------------------------------------------
# Builds the per-cell single-trial ERP data frames for Paper 1. One array task per
# (grammatical property x macroregion) -- six in total -- because the legacy merge
# reads the full single-trial EEG for one property at a time (the memory-bound
# step). Each task writes the three time-window .rds files for its property/
# macroregion into the project-space store ($LES_STORE/paper_1_transfer/data_derived).
#
# Submit:  sbatch paper_1_transfer/hpc/01_extract_erp.slurm
# =============================================================================
#SBATCH --job-name=p1_extract_erp
#SBATCH --partition=medium
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=48G
#SBATCH --time=1-00:00:00
#SBATCH --array=0-5
#SBATCH -o paper_1_transfer/hpc/logs/01_extract_erp_%a.out

source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

# Variant extractions (LES_P1_KEEP_MISFILTERED=1) write their own logs so the
# mainline extraction logs are never overwritten by a resubmission. The derived
# files themselves are tagged by les_p1_cell_rds() in _config.R.
TAG=""
[ "${LES_P1_KEEP_MISFILTERED:-0}" = "1" ] && TAG="${TAG}_keepmisfiltered"

# Array index -> (property macroregion). Order is fixed and documented here so
# that a given %a always maps to the same cell across resubmissions.
PARAMS=(
  "gender_agreement lateral"
  "gender_agreement midline"
  "differential_object_marking lateral"
  "differential_object_marking midline"
  "verb_object_number_agreement lateral"
  "verb_object_number_agreement midline"
)
read -r PROP MACRO <<< "${PARAMS[$SLURM_ARRAY_TASK_ID]}"
echo "[array ${SLURM_ARRAY_TASK_ID}] property=${PROP} macroregion=${MACRO} | start $(date)"

Rscript "paper_1_transfer/scripts/01_extract_erp_single_trials.R" "${PROP}" "${MACRO}" \
    > "paper_1_transfer/hpc/logs/01_extract_erp_${PROP}_${MACRO}.Rout" 2>&1

echo "[array ${SLURM_ARRAY_TASK_ID}] finished $(date)"
