#!/bin/bash
# =============================================================================
# 00_descriptives.slurm  --  the raw-data descriptives the manuscripts inject (ARC)
# -----------------------------------------------------------------------------
# Runs the three light extraction scripts that read only data/ and the derived files
# already in the store, and write the descriptive tables both manuscripts read:
#   00c_extract_erp_retention.R   _erp_trial_retention.csv, _misfiltered_share.csv
#   02_extract_accuracy.R         accuracy_<property>.rds (unchanged content),
#                                 _accuracy_rt_screen.csv, _accuracy_sentence_inventory.csv
#   00_extract_participants.R     _sample_flow.csv, _participants.csv and
#                                 _participants_other_languages.csv, to both papers
# Script 00 runs last because it counts participants in the accuracy files script 02
# writes. No model is fitted and no fit is invalidated: script 02 rewrites the accuracy
# data with the content the reported fits were computed from, which brms's on-change
# cache check recognises.
#
#   sbatch --clusters=htc --account=educ-intract paper_1_transfer/hpc/00_descriptives.slurm
# (Standard QoS only -- never --qos=priority.)
# =============================================================================
#SBATCH --job-name=p1_descriptives
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=8G
#SBATCH --time=01:00:00
#SBATCH -o paper_1_transfer/hpc/logs/00_descriptives.out

source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

# The variant switches must be unset: this job regenerates the reported artefacts.
unset LES_P1_ACC_DIVERSITY LES_P1_KEEP_MISFILTERED

Rscript "paper_1_transfer/scripts/00c_extract_erp_retention.R" \
    > "paper_1_transfer/hpc/logs/00c_extract_erp_retention.Rout" 2>&1
Rscript "paper_1_transfer/scripts/02_extract_accuracy.R" \
    > "paper_1_transfer/hpc/logs/02_extract_accuracy.Rout" 2>&1
Rscript "paper_1_transfer/scripts/00_extract_participants.R" \
    > "paper_1_transfer/hpc/logs/00_extract_participants.Rout" 2>&1

echo "00 descriptives finished $(date)"
