#!/bin/bash
# =============================================================================
# 00e_reprocess_eeg.slurm  --  0.1 Hz reprocessing of the nine Session-3 records (HTC)
# -----------------------------------------------------------------------------
# One array task per recording, for the two gated stages of
# docs/eeg_filter_reprocessing_protocol.md, selected by LES_REPROCESS_STAGE:
#
#   validate   tasks 0-12. 0-8 rebuild the archived 1 Hz exports of lab IDs 7, 8, 9, 16,
#              53, 60, 61, 62, 65 and round-trip them through the export writer; 9-12
#              rebuild the 0.1 Hz exports of IDs 10, 51, 58, 59 that fixed the filter-margin
#              rule (Amendment 2). Each writes a gate record.
#   reprocess  tasks 0-8. Refuses to start unless all thirteen gates passed under the same
#              code; then writes the record's six 0.1 Hz exports to staging, its provenance
#              record and the trigger-check side output (Amendment 5).
#
# Outputs go to $LES_STORE/paper_1_transfer/data_derived/eeg_reprocessing. Nothing is
# written to the overlay the importer reads until 00f_assemble_eeg_overlay.slurm has checked
# all nine records. The code is in paper_1_transfer/scripts/eeg_reconstruction/.
#
# Do not submit by hand: 00e_submit_reprocessing.sh builds the Python environment, splits
# each stage across the educ-lift and educ-intract accounts and chains validate ->
# reprocess -> assemble with afterok, so a failed gate stops everything after it.
# (Standard QoS only -- never --qos=priority.)
#
# Resources: one recording is at most ~0.4 GB of float32 samples, held as float64 plus a
# rereferenced copy (~3 GB peak). Measured on a laptop on 27 September 2026: 1.5-3.5 min
# per 1 Hz gate, 12-20 min per margin scan (about twenty filter rules), 2-4.5 min per
# 0.1 Hz record. Two hours on the short partition leave a wide margin; one CPU, because
# the array is the parallelism.
# =============================================================================
#SBATCH --job-name=p1_reprocess_eeg
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH -o paper_1_transfer/hpc/logs/00e_reprocess_eeg_%x_%A_%a.out

source _shared/hpc/arc_env.sh
source _shared/hpc/py_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

: "${LES_REPROCESS_STAGE:?set LES_REPROCESS_STAGE=validate or reprocess (use 00e_submit_reprocessing.sh)}"
: "${SLURM_ARRAY_TASK_ID:?this script runs as an array job}"

cd paper_1_transfer/scripts/eeg_reconstruction
python reprocess.py "${LES_REPROCESS_STAGE}" --task "${SLURM_ARRAY_TASK_ID}"
echo "00e ${LES_REPROCESS_STAGE} task ${SLURM_ARRAY_TASK_ID} finished $(date)"
