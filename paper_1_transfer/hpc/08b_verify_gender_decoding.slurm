#!/bin/bash
# =============================================================================
# 08b_verify_gender_decoding.slurm  --  report what the gender decoding element
# actually produced, the moment it terminates.
# -----------------------------------------------------------------------------
# WHY afterany AND NOT afterok
# ----------------------------
# Array element 12664261_0 is expected to exit NON-ZERO even on complete success.
# It has been executing 09_run_decoding.R since 1 Aug, and that file was overwritten
# in place on 6 Aug. Rscript parses and evaluates one expression at a time, holding a
# byte offset into the file, so once the analysis finishes the interpreter reads a
# fragment of a shifted line and dies with a parse error. Element _1 (differential
# object marking) did exactly this on 9 Aug: it wrote all three CSVs, then exited 1:0.
# An afterok dependency would therefore never fire. See HPC_RUNBOOK.md, "Do not scp a
# script that a running job is executing".
#
# This job only READS. It submits nothing, deletes nothing, and touches no results.
# Its purpose is to capture the state at the instant the decoding element terminates,
# so the outcome does not depend on a login-node process surviving (a watcher in /tmp
# is node-local and is lost when the login node rotates).
#
# SUBMIT (arc cluster; standard QoS). Pass the job being watched: this script used
# to hardcode 12664261, so once that run was superseded it kept reporting a job
# cancelled weeks earlier, with stale July artefact dates, while appearing healthy.
#   sbatch --export=ALL,LES_DECODE_WATCH_JOB=<id>_0 --dependency=afterany:<id>_0 \
#         paper_1_transfer/hpc/08b_verify_gender_decoding.slurm
# =============================================================================
#SBATCH --job-name=p1_verify_decode
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=4G
#SBATCH --time=00:20:00
#SBATCH -o paper_1_transfer/hpc/logs/08b_verify_gender_decoding_%j.out

source _shared/hpc/arc_env.sh
# Deliberately no errexit: a missing file is a finding to report, not a reason to abort.
set -o nounset

STATUS="${HOME}/new_LESS/GENDER_DECODING_STATUS.txt"
RES="${LES_STORE}/paper_1_transfer/results"
PROPS=(gender_agreement differential_object_marking verb_object_number_agreement)

{
  echo "gender decoding verification -- written $(date)"
  echo "triggered by the termination of ${LES_DECODE_WATCH_JOB:-<unset>} (afterany)"
  echo
  echo "--- slurm outcome of the decoding array ---"
  sacct -j "${LES_DECODE_WATCH_JOB%%_*}" --format=JobID%18,State%14,ExitCode,Elapsed,End%20 2>&1 | head -12
  echo
  echo "--- gender artefacts (all three must be present) ---"
  for suffix in timecourse generalization temporal_generalization; do
      f="${RES}/gender_agreement_decoding_${suffix}.csv"
      if [ -f "${f}" ]; then
          printf '  %-26s rows=%-7s %s\n' "${suffix}" \
              "$(( $(wc -l < "${f}") - 1 ))" "$(date -r "${f}" '+%Y-%m-%d %H:%M')"
      else
          printf '  %-26s MISSING\n' "${suffix}"
      fi
  done
  echo
  echo "--- permutation count per property (n_perm, column 10 of the timecourse CSV) ---"
  # Every property must read 1000 before the CSVs are pulled back together: the
  # manuscript reads n_perm out of these files and prints "mixed; re-run incomplete"
  # if the three disagree.
  # A property counts as ready only if every row of its timecourse CSV reads exactly
  # 1000, so a partially rewritten file cannot pass.
  READY=0
  for p in "${PROPS[@]}"; do
      f="${RES}/${p}_decoding_timecourse.csv"
      if [ -f "${f}" ]; then
          v=$(awk -F, 'NR>1{gsub(/"/,""); print $10}' "${f}" | sort -u | tr '\n' ' ')
          printf '  %-32s %s\n' "${p}" "${v}"
          [ "${v}" = "1000 " ] && READY=$(( READY + 1 ))
      else
          printf '  %-32s MISSING\n' "${p}"
      fi
  done
  echo
  echo "properties at n_perm=1000: ${READY} of ${#PROPS[@]}"
  if [ "${READY}" = "${#PROPS[@]}" ]; then
      echo "RESULT: READY -- all three properties at n_perm=1000."
      echo "Next: pull all three properties' CSVs together (HPC_RUNBOOK.md section 2),"
      echo "re-render both manuscripts, then cancel the stale 12664262."
  else
      echo "RESULT: NOT READY -- the three properties do not all read n_perm=1000."
      echo "Do not pull piecemeal. Investigate before collecting anything."
  fi
} > "${STATUS}" 2>&1

cat "${STATUS}"
