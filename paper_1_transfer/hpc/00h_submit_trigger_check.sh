#!/bin/bash
# =============================================================================
# 00h_submit_trigger_check.sh  --  submit the trigger-rule check of Amendment 5 (HTC)
# -----------------------------------------------------------------------------
# Run on the login node from the code root, after 00e has written the nine records' events:
#
#   cd ~/new_LESS && LES_CODE_COMMIT=<git commit of the deployed code> \
#     bash paper_1_transfer/hpc/00h_submit_trigger_check.sh
#
# Needs the Python environment 00e_submit_reprocessing.sh builds and the raw signal of the
# eight comparison recordings in the data tree: Session 3 of lab IDs 10, 51, 58 and 59 (placed
# for the margin gate of 00e) and Session 2 of lab IDs 10, 11, 12 and 20, which come from OSF
# project tq7vy like every other raw file (HPC_RUNBOOK.md, section 0). Submits, at standard
# QoS:
#   events   tasks 0-3 educ-lift, tasks 4-7 educ-intract
#   analyse  educ-intract, afterok on both halves of events
# A failed gate leaves analyse pending with DependencyNeverSatisfied: read the log first. The
# analysis is computed once, on all seventeen recordings, so it is never run on a subset.
# =============================================================================
set -o errexit
set -o nounset
cd "${LES_CODE_ROOT:-$HOME/new_LESS}"
source _shared/hpc/arc_env.sh >/dev/null

[ -x "${LES_BASE}/pyenv/eeg-recon-py3.13/bin/python" ] || { echo "[00h] FATAL: run 00e_submit_reprocessing.sh first (Python environment)" >&2; exit 1; }
for f in "Session 2/Raw/10" "Session 2/Raw/11" "Session 2/Raw/12" "Session 2/Raw/20" \
         "Session 3/Raw/10" "Session 3/Raw/51" "Session 3/Raw/58" "Session 3/Raw/59"; do
  for x in vhdr vmrk eeg; do
    [ -s "${LES_DATA_ROOT}/raw data/EEG/${f}.${x}" ] || { echo "[00h] FATAL: ${f}.${x} missing from the data tree" >&2; exit 1; }
  done
done
TC="${LES_STORE}/paper_1_transfer/data_derived/eeg_reprocessing/trigger_check"
for id in 7 8 9 16 53 60 61 62 65; do
  [ -s "${TC}/${id}_events.npz" ] || { echo "[00h] FATAL: ${TC}/${id}_events.npz missing (00e reprocess)" >&2; exit 1; }
done

mkdir -p paper_1_transfer/hpc/logs
: "${LES_CODE_COMMIT:=unknown}"
SB=(sbatch --parsable --clusters=htc)
EV="ALL,LES_CODE_COMMIT=${LES_CODE_COMMIT}"
S=paper_1_transfer/hpc/00h_trigger_check.slurm
jid() { cut -d';' -f1; }   # --parsable on HTC prints "<id>;htc"

E1=$("${SB[@]}" --account=educ-lift    --array=0-3 --export="${EV},LES_TRIGGER_STAGE=events" "${S}" | jid)
E2=$("${SB[@]}" --account=educ-intract --array=4-7 --export="${EV},LES_TRIGGER_STAGE=events" "${S}" | jid)
A=$("${SB[@]}"  --account=educ-intract --dependency="afterok:${E1}:${E2}" --export="${EV},LES_TRIGGER_STAGE=analyse" "${S}" | jid)

echo "[00h] events ${E1} (educ-lift, Session 2), ${E2} (educ-intract, Session 3); analyse ${A} (educ-intract)"
