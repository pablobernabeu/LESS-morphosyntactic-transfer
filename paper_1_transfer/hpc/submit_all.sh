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
# NOT IN THE CHAIN. The remaining stages are submitted by hand. The pipeline table in
# paper_1_transfer/README.md describes each; it is in script-number order, not run order:
#   00_descriptives.slurm               scripts 00c, 02, 00 and 00b, the raw-data
#                                       descriptive tables both manuscripts inject, with
#                                       every variant switch unset. Submit it after 01,
#                                       whose cell files 00c reads. It needs data/,
#                                       including the behavioural logfiles script 02
#                                       reads, and Paper 2's cognitive_indices.rds,
#                                       learning_trajectory.rds and resting_state_eeg.rds
#                                       in the store, without which script 00 cannot
#                                       count the Paper 2 rows of the sample flow
#   00d, 01b, 07c, 09b, 10              local scripts, no job
#   00h_submit_trigger_check.sh         the trigger-rule check (Amendment 5); feeds no
#                                       analysis
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
#
# Two environment settings, with the values this project actually uses:
#   LES_CLUSTER   cluster to submit to        (default htc)
#   LES_ACCOUNT   account to charge           (default educ-intract)
# Set LES_CLUSTER to an empty string to submit to the site default (the arc cluster)
# instead, which is what this script did before the setting existed; the October 2026
# rerun ran on HTC.
# =============================================================================

set -o errexit
set -o nounset

HPC_DIR="paper_1_transfer/hpc"
mkdir -p "${HPC_DIR}/logs"

LES_CLUSTER="${LES_CLUSTER-htc}"
LES_ACCOUNT="${LES_ACCOUNT-educ-intract}"
CLUSTER_ARGS=""
if [[ -n "${LES_CLUSTER}" ]]; then
  CLUSTER_ARGS="--clusters=${LES_CLUSTER} --account=${LES_ACCOUNT}"
fi

# Helper: submit a job and echo only the numeric job id (for --dependency). With
# --clusters, sbatch --parsable returns "<jobid>;<cluster>", and a dependency spec will not
# take the suffix, so it is trimmed. The id is checked rather than piped through cut,
# because a pipe would hide a failed sbatch from errexit and let the chain carry on with an
# empty dependency.
submit() {
  local out id
  out=$(sbatch --parsable ${CLUSTER_ARGS} "$@") || { echo "sbatch failed: $*" >&2; exit 1; }
  id=${out%%;*}
  [[ "$id" =~ ^[0-9]+$ ]] || { echo "unexpected sbatch output: '$out'" >&2; exit 1; }
  printf '%s\n' "$id"
}

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
  '') ;;
  # A mistyped option would otherwise submit the whole chain against whatever library is
  # there, unprovisioned.
  *) echo "unknown option: $1 (expected with_restore or with_install)" >&2; exit 1 ;;
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
echo "All jobs queued. Track with:  squeue -M htc,arc -u \$USER"
