#!/bin/bash
# =============================================================================
# 00g_recover_eeg.slurm  --  recover two misaligned exports, rebuild three marker files (HTC)
# -----------------------------------------------------------------------------
# Runs one stage of paper_1_transfer/scripts/eeg_reconstruction/recover.py, selected by
# LES_RECOVER_STAGE (docs/eeg_filter_reprocessing_protocol.md, Amendments 2, 3, 5 and 6):
#
#   gate       array 0-1: 0 = Session 6 of lab ID 5, 1 = Session 2 of lab ID 7. Rebuild the
#              legacy exports from the record's own raw signal and the history's markers.
#   resegment  array 0-1: refuses unless the record's gate passed under the same code;
#              re-segments the record at its own events and writes all its exports.
#   markers    single task: rebuilds the marker files of three legacy exports lacking one.
#   assemble   single task: checks everything and copies it into the overlay.
#
# Outputs go to $LES_STORE/paper_1_transfer/data_derived/eeg_reprocessing/recovery; the
# assembly adds to .../eeg_overlay but never overwrites a file there. Submitted by
# 00g_submit_recovery.sh, which splits the arrays across the two accounts and chains
# gate -> resegment -> assemble with afterok. (Standard QoS only -- never --qos=priority.)
#
# Resources as 00e_reprocess_eeg.slurm: one recording at a time, ~3 GB peak, minutes.
# =============================================================================
#SBATCH --job-name=p1_recover_eeg
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH -o paper_1_transfer/hpc/logs/00g_recover_eeg_%x_%j.out

source _shared/hpc/arc_env.sh
source _shared/hpc/py_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

: "${LES_RECOVER_STAGE:?set LES_RECOVER_STAGE=gate, resegment, markers or assemble (use 00g_submit_recovery.sh)}"
TASK=()
if [ -n "${SLURM_ARRAY_TASK_ID:-}" ]; then TASK=(--task "${SLURM_ARRAY_TASK_ID}"); fi

cd paper_1_transfer/scripts/eeg_reconstruction
python recover.py "${LES_RECOVER_STAGE}" "${TASK[@]}"
echo "00g ${LES_RECOVER_STAGE} ${SLURM_ARRAY_TASK_ID:-} finished $(date)"
