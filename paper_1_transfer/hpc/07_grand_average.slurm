#!/bin/bash
# =============================================================================
# 07_grand_average.slurm -- grand-average time-resolved ERP extraction (job array)
# One array task per (property x macroregion) = 6 tasks. Each loads the full-epoch
# single-trial data and writes a condition-averaged grand-average CSV, electrodes
# averaged within the nine brain_region clusters, for the manuscript's waveform and
# difference-wave figures. Same heavy importer as step 01, so it uses the same generous
# memory. The interpolated scalp topography needs the electrode dimension instead and
# is fed by 07b_grand_average_electrode.slurm.
#
# Submit (HTC):  sbatch --clusters=htc --account=educ-intract paper_1_transfer/hpc/07_grand_average.slurm
# =============================================================================
#SBATCH --job-name=p1_grandavg
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=48G
#SBATCH --time=06:00:00
#SBATCH --array=0-5
#SBATCH -o paper_1_transfer/hpc/logs/07_grand_average_%a.out

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

Rscript "paper_1_transfer/scripts/07_extract_grand_average_waveforms.R" "${PROP}" "${MACRO}" \
    > "paper_1_transfer/hpc/logs/07_grand_average_${PROP}_${MACRO}.Rout" 2>&1

echo "[array ${SLURM_ARRAY_TASK_ID}] finished $(date)"
