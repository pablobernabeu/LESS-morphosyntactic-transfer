#!/bin/bash
# =============================================================================
# submit_all.sh  --  submit the whole Paper 1 Bayesian pipeline with SLURM
#                    dependency chaining (afterok), in the correct order.
# -----------------------------------------------------------------------------
# Stage graph:
#   01 extract ERP ----\
#                       >-- 03 fit ERP ------\
#   02 extract accuracy >-- 04 fit accuracy --\
#                                              >-- 05 summaries
#
# The dependency 'install -> everything' is optional: pass `with_install` as the
# first argument to also (re)provision the Bayesian toolchain first.
#
# Usage:
#   bash paper_1_transfer/hpc/submit_all.sh                # assumes deps present
#   bash paper_1_transfer/hpc/submit_all.sh with_install   # install deps first
# =============================================================================

set -o errexit
set -o nounset

HPC_DIR="paper_1_transfer/hpc"
mkdir -p "${HPC_DIR}/logs"

# Helper: submit a job and echo only the numeric job id (for --dependency).
submit() { sbatch --parsable "$@"; }

DEP_INSTALL=""
if [[ "${1:-}" == "with_install" ]]; then
  JID_INSTALL=$(submit "${HPC_DIR}/00_install_dependencies.slurm")
  echo "00 install dependencies : ${JID_INSTALL}"
  DEP_INSTALL="--dependency=afterok:${JID_INSTALL}"
fi

# Stage 1: extraction (can start immediately, or after install).
JID_EXTRACT_ERP=$(submit ${DEP_INSTALL} "${HPC_DIR}/01_extract_erp.slurm")
echo "01 extract ERP          : ${JID_EXTRACT_ERP}"
JID_EXTRACT_ACC=$(submit ${DEP_INSTALL} "${HPC_DIR}/02_extract_accuracy.slurm")
echo "02 extract accuracy     : ${JID_EXTRACT_ACC}"

# Stage 2: fitting (each waits for its own extraction array to finish OK).
JID_FIT_ERP=$(submit --dependency=afterok:${JID_EXTRACT_ERP} "${HPC_DIR}/03_fit_erp.slurm")
echo "03 fit ERP              : ${JID_FIT_ERP}"
JID_FIT_ACC=$(submit --dependency=afterok:${JID_EXTRACT_ACC} "${HPC_DIR}/04_fit_accuracy.slurm")
echo "04 fit accuracy         : ${JID_FIT_ACC}"

# Stage 3: pooling/contrasts (waits for both fitting arrays).
JID_SUMMARIES=$(submit --dependency=afterok:${JID_FIT_ERP}:${JID_FIT_ACC} "${HPC_DIR}/05_summaries.slurm")
echo "05 summaries/contrasts  : ${JID_SUMMARIES}"

echo
echo "All jobs queued. Track with:  squeue -u \$USER"
