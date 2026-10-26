#!/bin/bash
# =============================================================================
# 08b_verify_gender_decoding.slurm  --  report what the gender decoding element
# actually produced, the moment it terminates.
# -----------------------------------------------------------------------------
# WHY afterany AND NOT afterok
# ----------------------------
# A decoding array element can exit NON-ZERO on complete success. Rscript parses and
# evaluates one expression at a time, holding a byte offset into the file, so when
# 09_run_decoding.R is overwritten in place while an element is executing it, the
# interpreter reads a fragment of a shifted line once the analysis finishes and dies
# with a parse error after writing every artefact. An afterok dependency would then
# never fire. See HPC_RUNBOOK.md, "Do not scp a script that a running job is executing".
#
# This job only READS. It submits nothing, deletes nothing, and touches no results.
# Its purpose is to capture the state at the instant the decoding element terminates,
# so the outcome does not depend on a login-node process surviving (a watcher in /tmp
# is node-local and is lost when the login node rotates).
#
# SUBMIT (standard QoS) to the cluster the decoding job runs on. The afterany dependency
# and the sacct query below both resolve job IDs only on the cluster the watcher runs on.
# For a decoding job submitted in the HTC form that the header of 08_decoding.slurm gives:
#   sbatch --clusters=htc --account=educ-intract \
#         --export=ALL,LES_DECODE_WATCH_JOB=<id>_0 --dependency=afterany:<id>_0 \
#         paper_1_transfer/hpc/08b_verify_gender_decoding.slurm
# For a decoding job on ARC, drop --clusters and --account. Pass the job being watched.
# The job exits at once without it, and the export is what stops the watcher reporting
# on a superseded job, with stale artefact dates, while appearing healthy.
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
# The status block expands the watched job under nounset, so refuse to start without it,
# before any status file is opened.
[ -n "${LES_DECODE_WATCH_JOB:-}" ] || { echo 'LES_DECODE_WATCH_JOB unset' >&2; exit 1; }

# arc_env.sh has changed directory to the code root, so the status file lands beside the
# repository's top-level files.
STATUS="${PWD}/GENDER_DECODING_STATUS.txt"
RES="${LES_STORE}/paper_1_transfer/results"
PROPS=(gender_agreement differential_object_marking verb_object_number_agreement)

# Every timecourse row must carry the permutation count the decoding job recorded as
# LES_DECODE_NPERM in _decoding_provenance.csv. Without that record, or when it holds no
# whole number, the expected count is 1000, the default in 08_decoding.slurm.
PROV="${RES}/_decoding_provenance.csv"
EXPECT=""
EXPECT_SRC="${PROV}"
if [ -f "${PROV}" ]; then
    EXPECT=$(awk -F, '{gsub(/["\r]/, "")} $1 == "LES_DECODE_NPERM" {print $2; exit}' "${PROV}")
fi
case "${EXPECT}" in
    ''|*[!0-9]*) EXPECT=1000; EXPECT_SRC="default, no usable ${PROV}" ;;
esac

{
  echo "gender decoding verification -- written $(date)"
  echo "triggered by the termination of ${LES_DECODE_WATCH_JOB:-<unset>} (afterany)"
  echo
  echo "--- slurm outcome of the decoding array ---"
  sacct -j "${LES_DECODE_WATCH_JOB%%_*}" --format=JobID%18,State%14,ExitCode,Elapsed,End%20 2>&1 | head -12
  echo
  echo "--- gender artefacts (all three must be present) ---"
  # A time-course assembled early by 09b from the banked confirmatory block carries the full
  # permutation count without the generalisation files, so READY below also needs all three
  # files. The count test alone once reported READY on a run stopped at its wall, beside a
  # line advising the cancellation of the queued resubmission that was to finish it.
  GENDER_FILES=0
  for suffix in timecourse generalization temporal_generalization; do
      f="${RES}/gender_agreement_decoding_${suffix}.csv"
      if [ -f "${f}" ]; then
          printf '  %-26s rows=%-7s %s\n' "${suffix}" \
              "$(( $(wc -l < "${f}") - 1 ))" "$(date -r "${f}" '+%Y-%m-%d %H:%M')"
          GENDER_FILES=$(( GENDER_FILES + 1 ))
      else
          printf '  %-26s MISSING\n' "${suffix}"
      fi
  done
  echo
  echo "--- permutation count per property (the n_perm column of each timecourse CSV) ---"
  echo "expected n_perm: ${EXPECT} (from ${EXPECT_SRC})"
  # Every property must read the expected count before the CSVs are pulled back together:
  # the manuscript reads n_perm out of these files and prints "mixed; re-run incomplete"
  # if the three disagree.
  # A property counts as ready only if every row of its timecourse CSV reads exactly
  # that count, so a partially rewritten file cannot pass. The column is located by its
  # header name, so a reordered CSV is still read correctly.
  READY=0
  for p in "${PROPS[@]}"; do
      f="${RES}/${p}_decoding_timecourse.csv"
      if [ -f "${f}" ]; then
          v=$(awk -F, 'NR == 1 {for (i = 1; i <= NF; i++) {h = $i; gsub(/"/, "", h); if (h == "n_perm") c = i}; next}
                       c {gsub(/"/, ""); print $c}' "${f}" | sort -u | tr '\n' ' ')
          printf '  %-32s %s\n' "${p}" "${v:-<no n_perm column or no rows>}"
          [ "${v}" = "${EXPECT} " ] && READY=$(( READY + 1 ))
      else
          printf '  %-32s MISSING\n' "${p}"
      fi
  done
  echo
  echo "properties at n_perm=${EXPECT}: ${READY} of ${#PROPS[@]}"
  if [ "${READY}" = "${#PROPS[@]}" ] && [ "${GENDER_FILES}" = 3 ]; then
      echo "RESULT: READY -- all three properties at n_perm=${EXPECT}, and gender's three files present."
      echo "Next: pull all three properties' CSVs together (HPC_RUNBOOK.md section 2),"
      echo "re-render both manuscripts, then cancel any superseded decoding job still queued."
  elif [ "${READY}" = "${#PROPS[@]}" ]; then
      echo "RESULT: NOT READY -- the counts agree, but gender's run has not written all three files."
      echo "Its time-course may be the early 09b assembly. A run stopped at its wall resumes from"
      echo "its banked blocks when resubmitted, so do not cancel a queued gender resubmission."
  else
      echo "RESULT: NOT READY -- the three properties do not all read n_perm=${EXPECT}."
      echo "Do not pull piecemeal. Investigate before collecting anything."
  fi
} > "${STATUS}" 2>&1

cat "${STATUS}"
