#!/bin/bash
# =============================================================================
# 00g_submit_recovery.sh  --  submit the recovery chain (HTC), after 00e has admitted the nine
# -----------------------------------------------------------------------------
# Run on the login node from the code root:
#
#   cd ~/new_LESS && LES_CODE_COMMIT=<git commit of the deployed code> \
#     bash paper_1_transfer/hpc/00g_submit_recovery.sh
#
# Needs the Python environment 00e_submit_reprocessing.sh builds, and the two raw
# recordings in the data tree (HPC_RUNBOOK.md, section 0). Submits, at standard QoS, each
# two-task array split across the project accounts:
#   gate       task 0 educ-lift, task 1 educ-intract
#   markers    educ-lift                                   (independent of the gates)
#   resegment  task 0 educ-lift, task 1 educ-intract       each afterok on its own gate
#   assemble   educ-intract                                afterok on resegment and markers
# A failed gate leaves its record's resegment and the assembly pending with
# DependencyNeverSatisfied: read the log, then cancel them. A record whose gate fails stays
# excluded (Amendments 2 and 3); assemble the other alone by resubmitting only its stages.
# =============================================================================
set -o errexit
set -o nounset
cd "${LES_CODE_ROOT:-$HOME/new_LESS}"
source _shared/hpc/arc_env.sh >/dev/null

[ -x "${LES_BASE}/pyenv/eeg-recon-py3.13/bin/python" ] || { echo "[00g] FATAL: run 00e_submit_reprocessing.sh first (Python environment)" >&2; exit 1; }
for f in "Session 6/Raw/5" "Session 2/Raw/7"; do
  for x in vhdr vmrk eeg; do
    [ -s "${LES_DATA_ROOT}/raw data/EEG/${f}.${x}" ] || { echo "[00g] FATAL: ${f}.${x} missing from the data tree" >&2; exit 1; }
  done
done

mkdir -p paper_1_transfer/hpc/logs
: "${LES_CODE_COMMIT:=unknown}"
SB=(sbatch --parsable --clusters=htc)
EV="ALL,LES_CODE_COMMIT=${LES_CODE_COMMIT}"
S=paper_1_transfer/hpc/00g_recover_eeg.slurm
jid() { cut -d';' -f1; }   # --parsable on HTC prints "<id>;htc"

G1=$("${SB[@]}" --account=educ-lift    --array=0 --export="${EV},LES_RECOVER_STAGE=gate" "${S}" | jid)
G2=$("${SB[@]}" --account=educ-intract --array=1 --export="${EV},LES_RECOVER_STAGE=gate" "${S}" | jid)
M=$("${SB[@]}"  --account=educ-lift              --export="${EV},LES_RECOVER_STAGE=markers" "${S}" | jid)
R1=$("${SB[@]}" --account=educ-lift    --array=0 --dependency="afterok:${G1}" --export="${EV},LES_RECOVER_STAGE=resegment" "${S}" | jid)
R2=$("${SB[@]}" --account=educ-intract --array=1 --dependency="afterok:${G2}" --export="${EV},LES_RECOVER_STAGE=resegment" "${S}" | jid)
A=$("${SB[@]}"  --account=educ-intract --dependency="afterok:${R1}:${R2}:${M}" --export="${EV},LES_RECOVER_STAGE=assemble" "${S}" | jid)

echo "[00g] gate ${G1} (educ-lift, ID 5 S6), ${G2} (educ-intract, ID 7 S2); markers ${M} (educ-lift)"
echo "[00g] resegment ${R1} (educ-lift), ${R2} (educ-intract); assemble ${A} (educ-intract)"
