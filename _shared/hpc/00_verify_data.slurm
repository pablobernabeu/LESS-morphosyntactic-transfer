#!/bin/bash
# =============================================================================
# 00_verify_data.slurm  --  check the cluster's data copy against the data manifest
# -----------------------------------------------------------------------------
# Hashes every file _shared/data_manifest/inputs.tsv lists under $LES_DATA_ROOT the way git
# hashes it, and fails when any is missing or differs from the committed content (ISSUES.md
# X5-02; _shared/R/write_data_manifest.R explains the comparison). Files the manifest does
# not list, such as the raw .eeg signal placed from OSF, are not checked. Hashing reads
# every byte of the tree, which is why this is a job and not a login-node command. Run it
# after every data sync, and write the manifest again after every commit that changes
# data/:
#
#   sbatch --clusters=htc _shared/hpc/00_verify_data.slurm
# =============================================================================
#SBATCH --job-name=les_verify_data
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --time=01:00:00
#SBATCH -o _shared/hpc/logs/00_verify_data_%j.out

source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p _shared/hpc/logs

Rscript _shared/R/write_data_manifest.R verify _shared/data_manifest/inputs.tsv

echo "Data verification finished at $(date)"
