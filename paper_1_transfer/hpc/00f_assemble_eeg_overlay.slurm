#!/bin/bash
# =============================================================================
# 00f_assemble_eeg_overlay.slurm  --  admit the nine reprocessed records to the overlay (HTC)
# -----------------------------------------------------------------------------
# Runs once, after every task of 00e_reprocess_eeg.slurm (stage reprocess) has succeeded.
# It re-checks all nine provenance records and the SHA-256 of every staged file, refuses to
# write into an overlay that already holds files, copies the 162 files (six exports x three
# files x nine records) into $LES_STORE/paper_1_transfer/data_derived/eeg_overlay, and
# writes to eeg_reprocessing/:
#   provenance_manifest.csv             one row per participant-session (protocol,
#                                       "Fail-closed validation")
#   eeg_overlay_manifest.candidate.csv  the admission rows for
#                                       paper_1_transfer/eeg_overlay_manifest.csv
# The importer refuses the overlay until that candidate is pulled, reviewed and committed as
# the tracked manifest and deployed (paper_1_transfer/hpc/README.md, "EEG reprocessing").
#
# Submitted by 00e_submit_reprocessing.sh. (Standard QoS only -- never --qos=priority.)
# =============================================================================
#SBATCH --job-name=p1_assemble_eeg
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --time=00:30:00
#SBATCH -o paper_1_transfer/hpc/logs/00f_assemble_eeg_overlay_%j.out

source _shared/hpc/arc_env.sh
source _shared/hpc/py_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

cd paper_1_transfer/scripts/eeg_reconstruction
python reprocess.py assemble
echo "00f assemble finished $(date)"
