#!/usr/bin/env bash
# =============================================================================
# deploy_to_cluster.sh  --  copy code to the cluster without changing what a live job runs
# -----------------------------------------------------------------------------
# WHY THIS EXISTS
# Two things go wrong when code is copied over files that live LESS jobs use. Rscript
# does not read a script in one go: it parses and evaluates one expression at a time,
# holding a byte offset into the file, and tar extracts by truncating the target in
# place, so overwriting a script a job is executing shifts the content underneath the
# offset and the interpreter dies on a fragment of a line (HPC_RUNBOOK.md records the
# August 2026 case). And a job that has not reached a file yet, a pending array task or a
# module sourced late in a run, reads the new copy, so one result comes from two versions
# of the code. The script therefore works out every file a live job can still read,
# holds those back, and copies the rest.
#
# It also holds back the decoding pair, 09_run_decoding.R and 08_decoding.slurm, unless
# LES_ALLOW_DECODING_DEPLOY=1 is exported deliberately, whether or not a decoding job is
# live. 09_run_decoding.R resumes banked permutation blocks keyed to the tensor's trial,
# participant and time-bin counts, a digest of its values, the permutation count B and
# the seed. The key does not cover the script's own code, so a changed copy would resume
# blocks computed by the old one, and 08_decoding.slurm sets B and the seed, so a changed
# copy can orphan every banked block.
#
# USAGE
#   bash _shared/hpc/deploy_to_cluster.sh <target> [ssh-alias]
#     target       paper_1_transfer | paper_2_plasticity | _shared | all
#     ssh-alias    defaults to $LES_CLUSTER_HOST, else arc-agent (the author's own alias;
#                  anyone else passes the alias HPC_RUNBOOK.md asks them to define)
#
#   LES_DEPLOY_DRY_RUN=1         report what would be copied and held back; copy nothing.
#   LES_DEPLOY_ANYWAY=1          also overwrite files a live job can still read, and deploy
#                                despite live jobs whose scripts cannot be identified. Only
#                                for a job you have checked by hand.
#   LES_ALLOW_DECODING_DEPLOY=1  include the decoding pair. Read the note above.
#
# WHAT IT DOES, IN ORDER
#   1. Lists the files of the target that git tracks and that are on disk: R and job
#      scripts, plus Paper 1's EEG reconstruction (Python) and the overlay manifests its
#      importer reads. Untracked files are never sent, so stage a new file with git add
#      first. renv.lock and "LESS Project.Rproj" are copied by hand once, as
#      HPC_RUNBOOK.md section 0 describes, and belong to no target.
#   2. Holds back the decoding pair unless LES_ALLOW_DECODING_DEPLOY=1.
#   3. Makes an LF-only copy of every file in a temporary directory. That is the form git
#      stores, so what lands on the cluster matches the committed bytes whatever line
#      endings this checkout writes (core.autocrlf), and a job script never reaches bash
#      with the carriage returns that make it fail with "$'\r': command not found".
#   4. In one connection, lists your jobs on HTC and ARC and checksums the cluster's
#      copies. It refuses to go on if either job query fails, because an empty answer must
#      mean an empty queue. The LESS jobs are those whose name begins p1_, p2_ or les_, or
#      whose working directory is the code root.
#   5. Works out what those jobs can still read: each job's batch script (from squeue, or
#      from the --job-name directives when squeue names none under the code root) and,
#      transitively, every file it runs or sources (see CLOSURE_AWK below). That is done
#      on both sides and the results combined, because a job runs the cluster's copies,
#      which may reference files the new ones no longer do. A live job whose script
#      cannot be identified on either side stops the deploy.
#   6. Keeps only the files whose content differs from the cluster's copy, or that the
#      cluster lacks. An R, Python or CSV file that differs only in line endings counts as
#      current (the readers ignore them), whereas a job script must match exactly. A file
#      that is not copied keeps its modification time on the cluster, which matters: the
#      decoding tensor cache keys on the size and mtime of _config.R, _eeg_import.R and
#      the overlay manifest, so a needless copy would make the next decoding job rebuild
#      its tensor.
#   7. Holds back the changed files from step 5, copies the others in one tar stream, and
#      checks every copied file's checksum on the cluster.
#
# EXIT STATUS
#   0  every file of the target is current on the cluster (copied now or already there)
#   1  refused or failed: a query, the copy or the checksum check went wrong, or a live
#      job could not be identified
#   2  usage error
#   3  partial: every other file is current, but changed files a live job can still read
#      were held back. Run the script again once those jobs have ended.
#   A dry run exits with the status the real run would end with.
#
# Every remote step goes through one ssh call, because each new connection through the
# gateway costs tens of seconds, and nothing loops over files with a process per file:
# under Git Bash on Windows each process start costs about a second, which is what made
# the previous version appear to hang while jobs were live (ISSUES.md N3).
#
# It copies code only. Nothing here touches data/, the store, or any fit.
# =============================================================================
set -o errexit
set -o nounset
set -o pipefail

TARGET="${1:-}"
HOST="${2:-${LES_CLUSTER_HOST:-arc-agent}}"
REMOTE_ROOT="new_LESS"
DRY_RUN="${LES_DEPLOY_DRY_RUN:-0}"
ANYWAY="${LES_DEPLOY_ANYWAY:-0}"

case "$TARGET" in
  paper_1_transfer|paper_2_plasticity|_shared|all) ;;
  *)
    echo "usage: bash _shared/hpc/deploy_to_cluster.sh <paper_1_transfer|paper_2_plasticity|_shared|all> [ssh-alias]" >&2
    exit 2
    ;;
esac

cd "$(dirname "$0")/../.."          # project root, wherever the clone lives

# --- (1) The file list -------------------------------------------------------
# KNOWN holds every file any target ships, one repo-relative path per line: the ones git
# tracks (or has staged) and that exist on disk, the latter because this clone may be a
# sparse checkout. The :(glob) magic keeps `*` within one directory level, so
# _shared/hpc/reconnaissance/ is left out. Each paper's scripts/tests/ is listed on its
# own, because a job runs tests there (00_descriptives.slurm checks the retention table
# it has just written).
# Manuscripts, results and figures stay on the dev box; the cluster never renders and
# never reads them. The search for what live jobs read (step 5) runs over all of KNOWN
# whatever the target, because a job of one paper can source files of the other (Paper
# 2's trajectory step sources Paper 1's accuracy extraction).
KNOWN=$(git ls-files -- \
          ':(glob)paper_1_transfer/scripts/*.R' ':(glob)paper_1_transfer/hpc/*.slurm' \
          ':(glob)paper_1_transfer/hpc/*.sh' ':(glob)paper_1_transfer/scripts/tests/*.R' \
          ':(glob)paper_1_transfer/scripts/eeg_reconstruction/checks/*.py' \
          ':(glob)paper_1_transfer/scripts/eeg_reconstruction/*.py' \
          'paper_1_transfer/scripts/eeg_reconstruction/requirements.txt' \
          ':(glob)paper_1_transfer/eeg_overlay_*.csv' \
          ':(glob)paper_2_plasticity/scripts/*.R' ':(glob)paper_2_plasticity/hpc/*.slurm' \
          ':(glob)paper_2_plasticity/hpc/*.sh' ':(glob)paper_2_plasticity/scripts/tests/*.R' \
          ':(glob)_shared/*.R' ':(glob)_shared/R/*.R' ':(glob)_shared/hpc/*.R' \
          ':(glob)_shared/hpc/*.sh' ':(glob)_shared/hpc/*.slurm' |
        while IFS= read -r f; do if [ -f "$f" ]; then printf '%s\n' "$f"; fi; done)
# Paths are passed around as whitespace-separated words and quoted inside remote
# commands, so a path with whitespace or a quote in it would be split or break the quoting.
if printf '%s\n' "$KNOWN" | grep -q "[[:space:]\"']"; then
  echo "refusing to deploy: a path contains whitespace or a quote:" >&2
  printf '%s\n' "$KNOWN" | grep "[[:space:]\"']" | sed 's/^/  /' >&2
  exit 1
fi

# The target's files, less the decoding pair unless it is allowed (step 2).
DECODING='^paper_1_transfer/(scripts/09_run_decoding\.R|hpc/08_decoding\.slurm)$'
case "$TARGET" in all) PREFIX='' ;; *) PREFIX="$TARGET/" ;; esac
FILES=$(printf '%s\n' "$KNOWN" | grep "^$PREFIX" || true)
if [ "${LES_ALLOW_DECODING_DEPLOY:-0}" != "1" ]; then
  FILES=$(printf '%s\n' "$FILES" | grep -vE "$DECODING" || true)
fi
case "$TARGET" in
  paper_1_transfer|all)
    if [ "${LES_ALLOW_DECODING_DEPLOY:-0}" = "1" ]; then
      echo "WARNING: LES_ALLOW_DECODING_DEPLOY=1, so the decoding pair WILL be copied if it differs."
      echo "         Banked permutation blocks computed by the old code may be resumed or orphaned."
    else
      echo "note: holding back the decoding pair (export LES_ALLOW_DECODING_DEPLOY=1 to include it)"
    fi ;;
esac
[ -n "$FILES" ] || { echo "nothing to deploy for target '$TARGET'" >&2; exit 1; }
N_ALL=$(printf '%s\n' "$FILES" | grep -c .)

# --- (3) LF-only copies --------------------------------------------------------
# One awk pass writes every copy. sub() drops the CR of a CRLF line, and RT, gawk's
# record terminator, is "\n" except after a last line with no newline, which therefore
# stays without one, as git stores it.
STAGE=$(mktemp -d "${TMPDIR:-/tmp}/les_deploy.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
STAGE_DIRS=""
for f in $FILES; do
  case "$f" in */*) STAGE_DIRS="$STAGE_DIRS $STAGE/${f%/*}" ;; esac
done
# shellcheck disable=SC2086  # these lists are meant to split; no path has whitespace
mkdir -p $STAGE_DIRS
# shellcheck disable=SC2086
awk -v dest="$STAGE" '
  FNR == 1 { if (out != "") close(out); out = dest "/" FILENAME }
  { sub(/\r$/, ""); printf "%s%s", $0, RT > out }
' $FILES
# An empty file gives awk no record, so it has no copy yet.
for f in $FILES; do [ -e "$STAGE/$f" ] || : > "$STAGE/$f"; done
# Local checksums as "hash  path", sorted by path. md5sum under Git Bash defaults to
# binary mode and writes "hash *path", which the sed brings to the coreutils form.
# shellcheck disable=SC2086
LOCAL_SUMS=$(cd "$STAGE" && md5sum $FILES | sed -e 's/ \*/  /' | sort -k2)

# shellcheck disable=SC2086
UNCOMMITTED=$(git diff --name-only HEAD -- $FILES 2>/dev/null || true)
if [ -n "$UNCOMMITTED" ]; then
  echo "note: these files differ from HEAD, so the cluster would run code no commit holds:"
  printf '  %s\n' $UNCOMMITTED
fi

# --- (4) One survey of the cluster: live jobs and checksums -----------------------
# The remote side reads the file list on stdin. Its output has two sections: the squeue
# lines (id|state|name|working dir|batch script), or @@SQUEUE_FAILED, then, after
# @@SUMS, "raw-md5 lf-md5 path" for every listed file the cluster has, where lf-md5 is
# taken with every CR removed. The two queries are chained with && so that the failure
# of either is reported, and squeue without -t already omits finished jobs.
echo "surveying $HOST: live jobs and the checksums of the cluster's copies"
REMOTE_SURVEY='
if ! { squeue -M htc -u "$(whoami)" -h -o "%i|%T|%j|%Z|%o" &&
       squeue -M arc -u "$(whoami)" -h -o "%i|%T|%j|%Z|%o"; }; then echo "@@SQUEUE_FAILED"; fi
echo "@@SUMS"
if cd "'"$REMOTE_ROOT"'" 2>/dev/null; then
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    printf "%s %s %s\n" "$(md5sum < "$f" | cut -c1-32)" "$(tr -d "\r" < "$f" | md5sum | cut -c1-32)" "$f"
  done
fi'
SURVEY=$(printf '%s\n' "$FILES" | ssh "$HOST" "$REMOTE_SURVEY") || {
  echo "could not survey $HOST (ssh failed), so cannot tell which files are in use." >&2
  echo "Refusing to deploy." >&2
  exit 1
}
if printf '%s\n' "$SURVEY" | grep -q '^@@SQUEUE_FAILED$'; then
  echo "squeue failed on $HOST, so cannot tell which files are in use. Refusing to deploy." >&2
  exit 1
fi
RAW=$(printf '%s\n' "$SURVEY" | awk '/^@@SUMS$/ { exit } { print }')
REMOTE_SUMS=$(printf '%s\n' "$SURVEY" | awk 'seen { print } /^@@SUMS$/ { seen = 1 }')

# "id state name script" for each LESS job, script being the batch script's path relative
# to the code root, or "-" when squeue names none under it (a job submitted on standard
# input, for instance). Names and paths are reduced to safe characters because they are
# later quoted into a remote command.
LIVE=$(printf '%s\n' "$RAW" | awk -F'|' -v root="$REMOTE_ROOT" '
  /^CLUSTER:/ || NF < 5 { next }
  {
    name = $3; wd = $4; cmd = $5
    if (name !~ /^(p1|p2|les)_/ && wd !~ ("/" root "(/|$)")) next
    path = "-"
    if (cmd ~ ("/" root "/")) { path = cmd; sub(".*/" root "/", "", path); sub(/[[:space:]].*/, "", path) }
    gsub(/[^A-Za-z0-9_.\/-]/, "", path); gsub(/[^A-Za-z0-9_.-]/, "_", name)
    if (path == "") path = "-"
    print $1, $2, name, path
  }')

# --- (5) What live jobs can still read -------------------------------------------
# CLOSURE_AWK, run with -v known="<paths>" -v want="<script>,<name> ...", prints every
# file in `known` that the live jobs can reach, then "UNKNOWN <name>" for each job whose
# script is not in `known` and whose name matches no --job-name directive there. Each
# job starts from its batch script, or, failing that, every job script declaring its
# name. A file reaches another when one of its non-comment lines carries
#   * here::here(), here() or file.path() with quoted arguments, joined with "/", or
#     source() of a quoted path (how every R script here sources another or opens a
#     tracked CSV);
#   * outside R, a path-like word ending in .R, .sh, .slurm, .py, .csv or .txt (Rscript,
#     source and python lines, sbatch of another job script, a file a module opens);
#   * in Python, an import of a module of that name.
# Free-standing words are not followed out of R files, where they only occur in messages
# (08_projpred_selection.R names submit_all.sh in one, which would otherwise pull in both
# chains). A word without a directory resolves to the file of that name in the same
# directory, or else to every file of that name. Otherwise the rules over-match rather
# than miss: holding back a file needlessly costs a deferred copy and nothing else.
read -r -d '' CLOSURE_AWK <<'AWK' || true
function add(p) { if (!(p in seen)) { seen[p] = 1; queue[++nq] = p } }
function dir_of(p) { return (p ~ /\//) ? substr(p, 1, match(p, /\/[^\/]*$/) - 1) : "" }
function resolve(r, from,    k, c, j, here, hits) {
  sub(/^\.\//, "", r); sub(/^\/+/, "", r)
  if (r in isknown) { add(r); return }
  if (index(r, "/") == 0) {
    here = dir_of(from); here = (here == "") ? r : here "/" r
    if (here in isknown) { add(here); return }
    if (r in bybase) { c = split(bybase[r], hits, " "); for (j = 1; j <= c; j++) add(hits[j]) }
    return
  }
  for (k in isknown) if (length(k) > length(r) && substr(k, length(k) - length(r)) == "/" r) add(k)
}
function scan(f,    line, rest, call, s, path, tok, is_r) {
  is_r = (f ~ /\.R$/)
  while ((getline line < f) > 0) {
    sub(/\r$/, "", line)
    if (line ~ /^[[:space:]]*#/) continue
    gsub(/\\"/, "\"", line)
    rest = line
    while (match(rest, /(here::here|here|file\.path|source)\([^)]*\)/)) {
      call = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); path = ""
      while (match(call, /"[^"]*"/)) {
        s = substr(call, RSTART + 1, RLENGTH - 2); call = substr(call, RSTART + RLENGTH)
        path = (path == "") ? s : path "/" s
      }
      if (path != "") resolve(path, f)
    }
    rest = is_r ? "" : line
    while (match(rest, /[A-Za-z0-9_.\/-]*[A-Za-z0-9_]\.(R|sh|slurm|py|csv|txt)([^A-Za-z0-9_]|$)/)) {
      tok = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
      sub(/[^A-Za-z0-9_]$/, "", tok); resolve(tok, f)
    }
    if (f ~ /\.py$/ && match(line, /^[[:space:]]*(from|import)[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/)) {
      tok = substr(line, RSTART, RLENGTH); sub(/^[[:space:]]*(from|import)[[:space:]]+/, "", tok)
      resolve(tok ".py", f)
    }
  }
  close(f)
}
BEGIN {
  n = split(known, K, " ")
  for (i = 1; i <= n; i++) {
    isknown[K[i]] = 1; b = K[i]; sub(/.*\//, "", b)
    bybase[b] = (b in bybase) ? bybase[b] " " K[i] : K[i]
    if (K[i] !~ /\.slurm$/) continue
    while ((getline line < K[i]) > 0) {
      sub(/\r$/, "", line)
      if (match(line, /^#SBATCH[[:space:]]+(--job-name=|-J[[:space:]]*)[^[:space:]]+/)) {
        nm = substr(line, RSTART, RLENGTH); sub(/^#SBATCH[[:space:]]+(--job-name=|-J[[:space:]]*)/, "", nm)
        jobs[nm] = (nm in jobs) ? jobs[nm] " " K[i] : K[i]; break
      }
    }
    close(K[i])
  }
  m = split(want, W, " ")
  for (i = 1; i <= m; i++) {
    split(W[i], pn, ","); p = pn[1]; nm = pn[2]
    if (p in isknown) add(p)
    else if (nm in jobs) { c = split(jobs[nm], J, " "); for (j = 1; j <= c; j++) add(J[j]) }
    else unknown[nm] = 1
  }
  for (h = 1; h <= nq; h++) scan(queue[h])
  for (h = 1; h <= nq; h++) print queue[h]
  for (nm in unknown) print "UNKNOWN " nm
}
AWK

BUSY="" UNKNOWN=""
if [ -n "$LIVE" ]; then
  WANT=$(printf '%s\n' "$LIVE" | awk '{ printf "%s%s,%s", (NR > 1 ? " " : ""), $4, $3 }')
  KNOWN_SP=$(printf '%s\n' "$KNOWN" | tr '\n' ' ')
  LOCAL_REACH=$(awk -v known="$KNOWN_SP" -v want="$WANT" "$CLOSURE_AWK")
  echo "reading the cluster's copies of the live jobs' scripts"
  REMOTE_REACH=$(ssh "$HOST" "cd '$REMOTE_ROOT' && awk -v known='$KNOWN_SP' -v want='$WANT' -f /dev/stdin" \
                   <<<"$CLOSURE_AWK") || {
    echo "could not read the cluster's copies of the job scripts on $HOST. Refusing to deploy." >&2
    exit 1
  }
  BUSY=$(printf '%s\n%s\n' "$LOCAL_REACH" "$REMOTE_REACH" | grep -v '^UNKNOWN ' | grep . | sort -u || true)
  # A job is unidentified only when neither side can resolve it.
  UNKNOWN=$(comm -12 <(printf '%s\n' "$LOCAL_REACH" | sed -n 's/^UNKNOWN //p' | sort -u) \
                     <(printf '%s\n' "$REMOTE_REACH" | sed -n 's/^UNKNOWN //p' | sort -u))
fi

if [ -n "$UNKNOWN" ]; then
  echo "these live jobs match no job script on either side, so what they read is unknown:" >&2
  printf '  %s\n' $UNKNOWN >&2
  if [ "$ANYWAY" != "1" ]; then
    echo "refusing to deploy. Identify them, or export LES_DEPLOY_ANYWAY=1." >&2
    exit 1
  fi
fi

# --- (6) Which files differ from the cluster's copies ------------------------------
# Prints the changed paths, then "@@EOL <n>" with the number of files that differ from
# the cluster's copy only in line endings and are left as they are. A job script counts
# as changed in that case, since bash needs it LF-only.
COMPARE=$(awk '
  NR == FNR { raw[$3] = $1; lf[$3] = $2; next }
  {
    shell = ($2 ~ /\.(sh|slurm)$/)
    if (!($2 in raw)) print $2
    else if (raw[$2] != $1) { if (!shell && lf[$2] == $1) eol++; else print $2 }
  }
  END { print "@@EOL " eol + 0 }
' <(printf '%s\n' "$REMOTE_SUMS") <(printf '%s\n' "$LOCAL_SUMS"))
CHANGED=$(printf '%s\n' "$COMPARE" | grep -v '^@@EOL ' || true)
N_EOL=$(printf '%s\n' "$COMPARE" | sed -n 's/^@@EOL //p')
N_CHANGED=$(printf '%s\n' "$CHANGED" | grep -c . || true)

# --- (7) Hold back, copy, verify ---------------------------------------------------
HELD=""
if [ -n "$CHANGED" ] && [ -n "$BUSY" ]; then
  HELD=$(comm -12 <(printf '%s\n' "$CHANGED" | sort) <(printf '%s\n' "$BUSY" | sort))
fi
SEND="$CHANGED"
if [ -n "$HELD" ]; then
  echo "live LESS jobs:" >&2
  printf '%s\n' "$LIVE" | awk '{ print "  " $1, $2, $3 }' >&2
  echo "these changed files can still be read by one of them:" >&2
  printf '  %s\n' $HELD >&2
  if [ "$ANYWAY" = "1" ]; then
    echo "LES_DEPLOY_ANYWAY=1, so they will be overwritten. A running Rscript, which reads" >&2
    echo "its file incrementally, can fail, and a pending job will run the new code." >&2
    HELD=""
  else
    echo "holding them back; the other changed files will still be deployed." >&2
    SEND=$(comm -23 <(printf '%s\n' "$CHANGED" | sort) <(printf '%s\n' "$HELD" | sort))
  fi
fi
N_HELD=$(printf '%s\n' "$HELD" | grep -c . || true)
N_SEND=$(printf '%s\n' "$SEND" | grep -c . || true)

# summary <verb>
#   Prints the closing counts and the held-back list, so that a partial deploy is the
#   last thing on screen, then exits with the status the header documents.
summary() {
  echo "$1 $N_SEND of $N_ALL files; $((N_ALL - N_CHANGED)) already current on $HOST."
  if [ "$N_EOL" -gt 0 ]; then
    echo "($N_EOL of those differ from the cluster's copy only in line endings, which their R and Python readers ignore.)"
  fi
  if [ "$N_HELD" -gt 0 ]; then
    echo "held back $N_HELD file(s) that a live job can still read; deploy again once it has ended:"
    printf '  %s\n' $HELD
    exit 3
  fi
  exit 0
}

if [ "$DRY_RUN" = "1" ]; then
  if [ "$N_SEND" -gt 0 ]; then
    echo "LES_DEPLOY_DRY_RUN=1: these files would be copied:"
    printf '  %s\n' $SEND
  fi
  summary "dry run: would copy"
fi

if [ "$N_SEND" -gt 0 ]; then
  echo "deploying $N_SEND files to $HOST:$REMOTE_ROOT/"
  # One tar stream over one connection, which then checksums what it extracted. A loop
  # of one scp per file costs a connection per file, and invites the stdin trap: ssh
  # reads standard input by default, so an ssh inside a loop fed by a pipe swallows the
  # rest of the list and the loop stops after one iteration in silence.
  DIRS=""
  for f in $SEND; do
    case "$f" in */*) DIRS="$DIRS ${f%/*}" ;; esac
  done
  # shellcheck disable=SC2086
  AFTER_SUMS=$(tar -C "$STAGE" -cf - $SEND |
               ssh "$HOST" "mkdir -p '$REMOTE_ROOT' && cd '$REMOTE_ROOT' && mkdir -p $DIRS && tar -xf - && md5sum $(printf '%s ' $SEND)" |
               sort -k2) || { echo "the copy to $HOST failed." >&2; exit 1; }
  SENT_SUMS=$(awk 'NR == FNR { s[$0] = 1; next } ($2 in s)' <(printf '%s\n' "$SEND") <(printf '%s\n' "$LOCAL_SUMS"))
  if [ "$SENT_SUMS" != "$AFTER_SUMS" ]; then
    echo "MISMATCH after copying. Differences:" >&2
    diff <(printf '%s\n' "$SENT_SUMS") <(printf '%s\n' "$AFTER_SUMS") >&2 || true
    exit 1
  fi
  echo "all copied files match."
fi
summary "deployed"
