#!/bin/bash
# =============================================================================
# 00h_trigger_check.slurm  --  trigger-rule check of protocol Amendment 5 (HTC)
# -----------------------------------------------------------------------------
# Runs one stage of paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py, selected
# by LES_TRIGGER_STAGE (docs/eeg_filter_reprocessing_protocol.md, Amendment 5):
#
#   events   array 0-7: one of the eight 0.1 Hz comparison recordings (0-3 = Session 2 of
#            lab IDs 10, 11, 12, 20; 4-7 = Session 3 of lab IDs 10, 51, 58, 59). Rebuilds it
#            from the raw data, gates the rebuild against its archived exports, and writes
#            its events beside the nine that 00e's reprocess stage wrote.
#   analyse  single task: refuses unless all seventeen event files exist; writes the tables
#            to .../eeg_reprocessing/trigger_check/results/.
#
# Outputs go to $LES_STORE/paper_1_transfer/data_derived/eeg_reprocessing/trigger_check.
# Nothing here is read by any analysis. Submitted by 00h_submit_trigger_check.sh, which
# splits the array across the two accounts and chains analyse with afterok. (Standard QoS
# only -- never --qos=priority.)
#
# Resources as 00g_recover_eeg.slurm: one recording at a time, a few GB, minutes. The
# analysis reads seventeen ~22 MB event files.
# =============================================================================
#SBATCH --job-name=p1_trigger_check
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --time=01:00:00
#SBATCH -o paper_1_transfer/hpc/logs/00h_trigger_check_%x_%j.out

source _shared/hpc/arc_env.sh
source _shared/hpc/py_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

: "${LES_TRIGGER_STAGE:?set LES_TRIGGER_STAGE=events or analyse (use 00h_submit_trigger_check.sh)}"
TASK=()
if [ -n "${SLURM_ARRAY_TASK_ID:-}" ]; then TASK=(--task "${SLURM_ARRAY_TASK_ID}"); fi

cd paper_1_transfer/scripts/eeg_reconstruction
python checks/trigger_check.py "${LES_TRIGGER_STAGE}" "${TASK[@]}"
echo "00h ${LES_TRIGGER_STAGE} ${SLURM_ARRAY_TASK_ID:-} finished $(date)"
