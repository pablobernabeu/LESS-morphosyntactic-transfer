#!/bin/bash
# =============================================================================
# 05_summaries.slurm  --  pool diagnostics, posterior summaries & contrasts (ARC)
# -----------------------------------------------------------------------------
# Aggregates every per-model artefact written by 03/04 into the pooled CSVs
# (_pooled_convergence.csv, _pooled_posterior_summaries.csv, _pooled_fit_metadata.csv) and
# computes the S4 -> S6 retention contrasts, the prior sensitivity, the first-session
# language advantage and the signal-detection contrasts (the header of the R script lists
# the files). Light, single job; run only after all fitting jobs have completed. The script
# stops without writing when the results directory holds no fits.
#
# Submit AFTER 03 and 04 complete:  sbatch paper_1_transfer/hpc/05_summaries.slurm
# =============================================================================
#SBATCH --job-name=p1_summaries
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=12G
#SBATCH --time=04:00:00
#SBATCH -o paper_1_transfer/hpc/logs/05_summaries.out

source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

Rscript "paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R" \
    > "paper_1_transfer/hpc/logs/05_summaries.Rout" 2>&1

echo "Posterior summaries & contrasts finished at $(date)"
