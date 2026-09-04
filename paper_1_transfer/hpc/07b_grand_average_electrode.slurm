#!/bin/bash
# =============================================================================
# 07b_grand_average_electrode.slurm -- per-ELECTRODE grand-average ERP extraction
# One array task per (property x macroregion) = 6 tasks, mirroring 07 exactly (same
# heavy importer, same memory profile) but keeping the electrode dimension instead of
# averaging within the nine brain_region clusters. Feeds the interpolated scalp
# topography figure, which needs the actual sensor positions rather than nine cluster
# means. Splitting by macroregion (rather than loading all electrodes at once) keeps
# each task's footprint at 07's proven 192G; the array runs the six loads in parallel,
# so the split costs no wall-clock.
#
# Submit (HTC):  sbatch --clusters=htc --account=educ-intract paper_1_transfer/hpc/07b_grand_average_electrode.slurm
# (Standard QoS only -- never --qos=priority.)
# =============================================================================
#SBATCH --job-name=p1_ga_electrode
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=48G
#SBATCH --time=06:00:00
#SBATCH --array=0-5
#SBATCH -o paper_1_transfer/hpc/logs/07b_ga_electrode_%a.out

source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

PARAMS=(
  "gender_agreement lateral"
  "gender_agreement midline"
  "differential_object_marking lateral"
  "differential_object_marking midline"
  "verb_object_number_agreement lateral"
  "verb_object_number_agreement midline"
)
read -r PROP MACRO <<< "${PARAMS[$SLURM_ARRAY_TASK_ID]}"
echo "[array ${SLURM_ARRAY_TASK_ID}] ${PROP} ${MACRO} | start $(date)"

Rscript "paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R" "${PROP}" "${MACRO}" \
    > "paper_1_transfer/hpc/logs/07b_ga_electrode_${PROP}_${MACRO}.Rout" 2>&1

echo "[array ${SLURM_ARRAY_TASK_ID}] finished $(date)"
