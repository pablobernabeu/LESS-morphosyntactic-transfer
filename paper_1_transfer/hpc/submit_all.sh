#!/bin/bash
# =============================================================================
# submit_all.sh  --  submit the model-fitting stages of the Paper 1 pipeline (01 to 05)
#                    with SLURM dependency chaining (afterok), in the correct order.
# -----------------------------------------------------------------------------
# Stage graph:
#   01 extract ERP ----\
#                       >-- 03 fit ERP ------\
#   02 extract accuracy >-- 04 fit accuracy --\
#                                              >-- 05 summaries
#
# NOT IN THE CHAIN. The remaining stages are submitted by hand, in the order of the
# pipeline table in paper_1_transfer/README.md, which is the authority:
#   00_descriptives.slurm               scripts 00c, 02 and 00, the raw-data descriptive
#                                       tables both manuscripts inject; after 02, with
#                                       every variant switch unset
#   00, 00b, 00d, 01b, 07c, 09b, 10     local scripts, no job
#   07_grand_average.slurm              after 01 (the same merge, aggregated over time)
#   07b_grand_average_electrode.slurm   after 01, keeping the electrode dimension
#   08_decoding.slurm                   extraction plus decoding, one task per property;
#                                       then the cross_property stage once the three
#                                       tensors exist
#   08b_verify_gender_decoding.slurm    the read-only watcher, chained on 08 (afterany)
#
# The chain exports no variant switch, so it produces the base random-effect fits; the
# `_itemslope` fits the manuscript reports are submitted separately (see README.md).
#
# Provisioning is optional and comes in two forms, chosen by the first argument:
#   with_restore   restore the recorded environment from renv.lock, pinned, through
#                  _shared/hpc/00_restore_environment.slurm (the reproduction route)
#   with_install   bootstrap an unpinned library where none exists, through
#                  00_install_dependencies.slurm
#
# Usage:
#   bash paper_1_transfer/hpc/submit_all.sh                # assumes deps present
#   bash paper_1_transfer/hpc/submit_all.sh with_restore   # restore renv.lock first
#   bash paper_1_transfer/hpc/submit_all.sh with_install   # bootstrap deps first
# =============================================================================

set -o errexit
set -o nounset

HPC_DIR="paper_1_transfer/hpc"
mkdir -p "${HPC_DIR}/logs"

# Helper: submit a job and echo only the numeric job id (for --dependency).
submit() { sbatch --parsable "$@"; }

DEP_INSTALL=""
case "${1:-}" in
  with_install)
    JID_INSTALL=$(submit "${HPC_DIR}/00_install_dependencies.slurm")
    echo "00 install dependencies : ${JID_INSTALL}"
    DEP_INSTALL="--dependency=afterok:${JID_INSTALL}"
    ;;
  with_restore)
    JID_RESTORE=$(submit "_shared/hpc/00_restore_environment.slurm")
    echo "00 restore environment  : ${JID_RESTORE}"
    DEP_INSTALL="--dependency=afterok:${JID_RESTORE}"
    ;;
esac

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
