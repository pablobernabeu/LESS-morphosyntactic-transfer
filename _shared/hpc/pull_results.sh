#!/usr/bin/env bash
# =============================================================================
# pull_results.sh  --  bring result CSVs back from the cluster store, with a record
# -----------------------------------------------------------------------------
# WHY THIS EXISTS
# The manuscripts read only <paper>/results/, and those files come from the store on the
# cluster, which keeps whatever every run left there: outputs of superseded runs,
# variant-tagged files, and aggregates such as _projpred_path.csv that whichever job
# finished last has overwritten. A glob copy of the store therefore imports whatever mix
# is there on the day and records nothing about it. This script compares first, copies
# only what you choose, checks what arrived, and appends one row per copied file to
# <paper>/results/_pulls/pull_log.csv, so that a committed result can be traced to the
# store file and the moment it came from. Nothing reads _pulls/: the manuscripts list
# results/ without recursion.
#
# USAGE (from the dev box)
#   bash _shared/hpc/pull_results.sh <paper_1_transfer|paper_2_plasticity> [file.csv ...]
#
#   With no LES_PULL_APPLY it only reports, for every CSV at the top of the store's
#   results/ directory, whether the local copy is the same, changed or missing, and which
#   local CSVs the store does not hold. It writes nothing.
#   LES_PULL_APPLY=1      copy the named files, or with none named every changed file
#                         (one the repository already holds), then verify and log them.
#                         A file only the store holds is copied only when named: those
#                         are typically variant-tagged outputs or superseded files (on
#                         3 October 2026, Paper 1's store held the six _diversity variant
#                         files and the retired _exclusions.csv). Local files the store
#                         lacks are reported and never deleted.
#   LES_CLUSTER_HOST      ssh alias (default arc-agent, the author's own; anyone else sets
#                         the alias HPC_RUNBOOK.md asks them to define).
#
# "Same" means that the store file has the git blob id the local file would be committed
# with. git stores these CSVs LF-normalised and the store's copies are written on Linux,
# so the comparison is unaffected by the CRLF this checkout may write.
#
# Review the report before applying it. The store can hold files that are older than the
# committed copies, or that a later run will replace (ISSUES.md X5-05; the Paper 2 pull
# of 18 September 2026 kept back _projpred_path.csv for that reason), so name the files
# to bring when the report shows anything you did not expect.
#
# EXIT STATUS: 0 on success (report or pull), 1 on a failed query, copy or check, 2 on a
# usage error.
# =============================================================================
set -o errexit
set -o nounset
set -o pipefail

PAPER="${1:-}"
case "$PAPER" in
  paper_1_transfer|paper_2_plasticity) shift ;;
  *)
    echo "usage: bash _shared/hpc/pull_results.sh <paper_1_transfer|paper_2_plasticity> [file.csv ...]" >&2
    exit 2 ;;
esac
HOST="${LES_CLUSTER_HOST:-arc-agent}"
APPLY="${LES_PULL_APPLY:-0}"
# The store root is the value LES_STORE takes in _shared/hpc/arc_env.sh, written out
# because this runs on the dev box, where that file is not sourced.
STORE_DIR="/data/educ-intract/educ1242/new_LESS/store/${PAPER}/results"
LOCAL_DIR="${PAPER}/results"

cd "$(dirname "$0")/../.."          # project root, wherever the clone lives
for f in "$@"; do
  case "$f" in
    */*|*[[:space:]\"\']*|'') echo "a file is named by its base name, without spaces or quotes: '$f'" >&2; exit 2 ;;
    *.csv) ;;
    *) echo "only CSVs are pulled: '$f'" >&2; exit 2 ;;
  esac
done

# --- (1) The store's side, in one connection ------------------------------------
# One line per CSV: git blob id, sha256, mtime (UTC) and name. The blob id is the SHA-1
# of "blob <size>\0" followed by the content, which is how git names a file's content.
echo "listing ${HOST}:${STORE_DIR}"
STORE=$(ssh -n "$HOST" "cd '$STORE_DIR' && for f in *.csv; do
    [ -f \"\$f\" ] || continue
    printf '%s %s %s %s\n' \
      \"\$( { printf 'blob %s\\0' \"\$(stat -c %s \"\$f\")\"; cat \"\$f\"; } | sha1sum | cut -c1-40)\" \
      \"\$(sha256sum < \"\$f\" | cut -c1-64)\" \
      \"\$(date -u -r \"\$f\" +%Y-%m-%dT%H:%M:%SZ)\" \"\$f\"
  done") || { echo "could not list ${STORE_DIR} on ${HOST}." >&2; exit 1; }
[ -n "$STORE" ] || { echo "the store holds no CSVs at ${STORE_DIR}." >&2; exit 1; }

# --- (2) The local side --------------------------------------------------------
# git hash-object applies the path's attributes, so a CRLF working copy hashes to the LF
# blob a commit would store. A file named on the command line but absent locally is new.
LOCAL=""
LOCAL_FILES=$(cd "$LOCAL_DIR" 2>/dev/null && ls -1 -- *.csv 2>/dev/null || true)
if [ -n "$LOCAL_FILES" ]; then
  LOCAL=$(printf "${LOCAL_DIR}/%s\n" $LOCAL_FILES | git hash-object --stdin-paths |
          paste -d ' ' - <(printf '%s\n' $LOCAL_FILES))
fi

# --- (3) Compare ---------------------------------------------------------------
# Prints "status file cluster_mtime" with status same, changed, new (store only) or
# local-only, sorted by file.
TABLE=$(awk '
  NR == FNR { if (NF == 2) loc[$2] = $1; next }
  NF == 4 { seen[$4] = 1; st = !($4 in loc) ? "new" : (loc[$4] == $1 ? "same" : "changed"); print st, $4, $3 }
  END { for (f in loc) if (!(f in seen)) print "local-only", f, "-" }
' <(printf '%s\n' "$LOCAL") <(printf '%s\n' "$STORE") | sort -k2)

echo
printf '%s\n' "$TABLE" | awk '{ printf "  %-10s %-20s  %s\n", $1, $3, $2 }'
echo
printf '%s\n' "$TABLE" | awk '{ n[$1]++ } END { printf "same %d, changed %d, new %d, local-only %d\n", n["same"], n["changed"], n["new"], n["local-only"] }'

# The files to copy: the named ones, or every changed one.
if [ "$#" -gt 0 ]; then
  WANT=$(printf '%s\n' "$@" | sort -u)
  MISSING=$(comm -23 <(printf '%s\n' "$WANT") <(printf '%s\n' "$STORE" | awk 'NF == 4 { print $4 }' | sort))
  [ -z "$MISSING" ] || { echo "not in the store:" >&2; printf '  %s\n' $MISSING >&2; exit 1; }
  PULL=$(printf '%s\n' "$TABLE" | awk 'NR == FNR { w[$0] = 1; next } ($2 in w) && $1 != "same" { print $2 }' \
           <(printf '%s\n' "$WANT") -)
else
  PULL=$(printf '%s\n' "$TABLE" | awk '$1 == "changed" { print $2 }')
fi

if [ "$APPLY" != "1" ]; then
  echo "report only; nothing was copied. LES_PULL_APPLY=1 would copy $(printf '%s\n' "$PULL" | grep -c . || true) file(s)$([ "$#" -gt 0 ] || echo ', the changed ones; name a new file to bring it')."
  exit 0
fi
if [ -z "$PULL" ]; then
  echo "nothing to copy: every file asked for is already the same as the store's."
  exit 0
fi

# --- (4) Copy, verify, record --------------------------------------------------------
echo "copying $(printf '%s\n' "$PULL" | grep -c .) file(s) into ${LOCAL_DIR}/"
# shellcheck disable=SC2086  # the list is meant to split; names have no whitespace
ssh "$HOST" "cd '$STORE_DIR' && tar -cf - $(printf '%s ' $PULL)" | tar -C "$LOCAL_DIR" -xf - ||
  { echo "the copy from ${HOST} failed." >&2; exit 1; }

# shellcheck disable=SC2086
GOT_BLOB=$(printf "${LOCAL_DIR}/%s\n" $PULL | git hash-object --stdin-paths | paste -d ' ' - <(printf '%s\n' $PULL))
# shellcheck disable=SC2086
GOT_SHA=$(cd "$LOCAL_DIR" && sha256sum $PULL | sed -e 's/ \*/  /')
BAD=$(awk '
  FILENAME == ARGV[1] { blob[$4] = $1; sha[$4] = $2; next }
  FILENAME == ARGV[2] { if (blob[$2] != $1) print $2 " (git blob)"; next }
  { if (sha[$2] != $1) print $2 " (sha256)" }
' <(printf '%s\n' "$STORE") <(printf '%s\n' "$GOT_BLOB") <(printf '%s\n' "$GOT_SHA"))
if [ -n "$BAD" ]; then
  echo "MISMATCH after copying; these files are not what the store holds:" >&2
  printf '  %s\n' "$BAD" >&2
  exit 1
fi

LOG_DIR="${LOCAL_DIR}/_pulls"
LOG="${LOG_DIR}/pull_log.csv"
mkdir -p "$LOG_DIR"
[ -f "$LOG" ] || echo 'pulled_utc,file,status,store_path,cluster_mtime_utc,sha256,git_blob,host' > "$LOG"
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
awk -v now="$NOW" -v dir="$STORE_DIR" -v host="$HOST" '
  FILENAME == ARGV[1] { st[$2] = $1; next }
  FILENAME == ARGV[2] { pull[$0] = 1; next }
  ($4 in pull) { printf "%s,%s,%s,%s/%s,%s,%s,%s,%s\n", now, $4, st[$4], dir, $4, $3, $2, $1, host }
' <(printf '%s\n' "$TABLE") <(printf '%s\n' "$PULL") <(printf '%s\n' "$STORE") >> "$LOG"
echo "verified every copied file and logged them in ${LOG}."
echo "Commit the CSVs together with ${LOG}, and re-render the manuscript."
