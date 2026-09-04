#!/bin/bash
# =============================================================================
# 02_extract_accuracy.slurm  --  grammaticality-judgement accuracy extraction (ARC)
# -----------------------------------------------------------------------------
# Reads the OpenSesame logfiles for Sessions 2/3/4/6 and writes one accuracy .rds
# per grammatical property into $LES_STORE/paper_1_transfer/data_derived. Light,
# single (non-arrayed) job (no EEG).
#
# Submit:  sbatch paper_1_transfer/hpc/02_extract_accuracy.slurm
# =============================================================================
#SBATCH --job-name=p1_extract_accuracy
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=8G
#SBATCH --time=02:00:00
#SBATCH -o paper_1_transfer/hpc/logs/02_extract_accuracy.out

source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

# Variant extractions (LES_P1_ACC_DIVERSITY=1) write their own logs so the mainline
# extraction log is never overwritten by a resubmission. The derived files themselves
# are tagged by les_p1_accuracy_rds() in _config.R.
TAG=""
[ "${LES_P1_ACC_DIVERSITY:-0}" = "1" ] && TAG="${TAG}_diversity"

Rscript "paper_1_transfer/scripts/02_extract_accuracy.R" \
    > "paper_1_transfer/hpc/logs/02_extract_accuracy${TAG}.Rout" 2>&1

echo "Accuracy extraction finished at $(date)"
