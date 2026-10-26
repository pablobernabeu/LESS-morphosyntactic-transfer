#!/bin/bash
# =============================================================================
# submit_rt_screen_switch.sh  --  every stage of both papers the reaction-time-screen switch changes (HTC)
# -----------------------------------------------------------------------------
# On 19 October 2026 the author asked for the most rigorous resolution of ISSUES.md G06-03,
# and the roles of the legacy (200, 4000) ms reaction-time screen were swapped. Both papers
# now analyse every judgement. Paper 1 refits its accuracy models with the screen as a
# sensitivity analysis (LES_P1_ACC_RT_SCREEN=1, tag _rtscreen). Paper 2's Part A fits on
# the screened trials are frozen in the repository (its _rtscreen tables) and are not
# refitted. This script reruns every stage whose input changes, in one submission. Run it
# on the login node from the code root:
#
#   bash paper_1_transfer/hpc/submit_rt_screen_switch.sh          # dry run: prints everything
#   LES_SUBMIT=1 LES_CODE_COMMIT=<deployed commit> \
#     bash paper_1_transfer/hpc/submit_rt_screen_switch.sh        # archive, then submit
#
# WHAT IT SUBMITS (HTC, standard QoS, alternating educ-lift and educ-intract)
#   Paper 2
#     02  learning trajectory on every judgement         -> P1 00, 10, Part A
#     10  descriptives and gamma attenuation (12)
#     04  Part A: raw (writes _provenance.csv), aperiodic, signal-detection, weak priors,
#         IAF-resolved gender stratum
#     09b common-sample comparison                       -> 09c, 08c, 06
#     09c participant-grouped comparison
#     08c projpred order diagnostic (supplement S5)
#     06  summaries, after every Part A fit and 09b
#   Paper 1
#     00  descriptives (00c, 02 on every judgement, 00, 00b), after Paper 2's 02, because 00
#         counts participants in both papers' trial files -> 04 on the reported data
#     02  accuracy with the diversity covariate          -> 04 diversity
#     02  accuracy with the legacy screen (_rtscreen)    -> 04 _rtscreen
#     04  the three accuracy models, seven arrays of three: reported, weak priors, added
#         slope, by-item term, slope and by-item term, diversity covariate, legacy screen
#     05  summaries and contrasts, after every 04
# Part B (05_fit_prepost) reads only the cognitive indices, which do not change, so its fits
# stay. The ERP fits and the decoding do not read the judgement trials and stay. Paper 1's
# reported accuracy data come from 00's run of 02, not from a separate 02 job, so no 04 can
# read a file another job is rewriting.
#
# BEFORE SUBMITTING it moves what the switch supersedes into
# <store>/<paper>/<folder>/_archive_<date>_rt_screened/. It moves files and deletes nothing.
# Steps 05 (Paper 1) and 06 (Paper 2) list results/ non-recursively, so archived fits are
# never pooled. The moves:
#   Paper 1: every accuracy fit and its artefacts (results/ and figures/ accuracy_*), the
#            derived accuracy files, and the side files of the retired unscreened variant
#            (_accuracy_*_nortscreen.csv).
#   Paper 2: every Part A fit (p2_predictive_trajectory*) and learning_trajectory.rds.
#
# TIME LIMITS. Each job asks for a limit that covers its runtime in September and October
# 2026 with a margin, instead of its script's own. Paper 1's 04 tasks took 9 to 24 minutes
# on the screened trials, and every judgement adds a quarter more. Paper 2's limits are those
# of submit_stroop_screen_refit.sh. A job is started only when its limit ends before a
# maintenance reservation, so the long defaults would hold every one back until it had passed.
# =============================================================================
set -o errexit
set -o nounset
cd "${LES_CODE_ROOT:-$HOME/new_LESS}"
source _shared/hpc/arc_env.sh >/dev/null

SUBMIT="${LES_SUBMIT:-0}"
H1=paper_1_transfer/hpc
H2=paper_2_plasticity/hpc
S1="${LES_STORE}/paper_1_transfer"
S2="${LES_STORE}/paper_2_plasticity"
ARCH="_archive_$(date +%F)_rt_screened"

# The jobs export the submitting shell's environment, so a variant switch left set would
# reach every stage. Each variant is set below on the jobs it belongs to.
unset LES_P1_ACC_RT_SCREEN LES_P1_ACC_NO_RT_SCREEN LES_P1_ACC_DIVERSITY LES_P1_ACC_MAXRANEF \
      LES_P1_ACC_ITEM LES_PRIOR_SET LES_PRIOR_PREDICTIVE LES_P1_EXCLUDE_REPROCESSED \
      LES_P1_ITEM_SLOPE LES_P2_STROOP_NO_SCREEN LES_P2_STROOP_KEEP_PRACTICE LES_P2_SDT \
      LES_P2_IAF_RESOLVED LES_P2_SIGN_ALIGNED LES_PROVENANCE_SKIP LES_P2_DERIVED_CONTRASTS

# --- Preconditions -------------------------------------------------------------
if squeue --clusters=htc,arc -u "$USER" -h -o '%j' | grep -q '^p[12]_'; then
  echo "[rt-switch] FATAL: a Paper 1 or Paper 2 job is live; this chain must start from a quiet queue" >&2
  exit 1
fi
grep -q 'les_p1_acc_rt_screen <- function' paper_1_transfer/scripts/_config.R &&
  grep -q '_rtscreen' paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R &&
  grep -q '.les_write_rt_bands' paper_1_transfer/scripts/02_extract_accuracy.R &&
  grep -q 'les_p1_acc_rt_screen()' paper_2_plasticity/scripts/02_extract_learning_trajectory.R || {
  echo "[rt-switch] FATAL: the deployed code predates the switch (G06-03, 19 October); deploy first" >&2; exit 1; }

# --- Archive -------------------------------------------------------------------
archive() {   # archive <dir> <glob...>: move matching top-level entries into <dir>/$ARCH
  local dir="$1"; shift
  local n=0
  for g in "$@"; do
    for f in "${dir}"/$g; do
      [ -e "$f" ] || continue
      n=$((n + 1))
      [ "$SUBMIT" = "1" ] && { mkdir -p "${dir}/${ARCH}"; mv -n "$f" "${dir}/${ARCH}/"; }
    done
  done
  echo "[rt-switch] archive ${dir#${LES_STORE}/}: ${n} entries -> ${ARCH}$([ "$SUBMIT" = "1" ] || echo ' (dry run)')"
}
archive "${S1}/results" 'accuracy_*' '_accuracy_*_nortscreen.csv'
archive "${S1}/figures" 'accuracy_*'
archive "${S1}/data_derived" 'accuracy_*.rds'
archive "${S2}/results" 'p2_predictive_trajectory*'
archive "${S2}/data_derived" 'learning_trajectory.rds'

# --- Submission helpers --------------------------------------------------------
: "${LES_CODE_COMMIT:=unknown}"
mkdir -p "${H1}/logs" "${H2}/logs"
EV="ALL,LES_CODE_COMMIT=${LES_CODE_COMMIT}"
NS="${EV},LES_PROVENANCE_SKIP=1"
COUNT=$(mktemp); trap 'rm -f "$COUNT"' EXIT
sub() {   # sub <name> <sbatch args...>; echoes the job id (or a named placeholder in a dry run)
  local name="$1"; shift
  echo >> "$COUNT"
  if [ "$SUBMIT" = "1" ]; then
    local id; id=$(sbatch --parsable --clusters=htc "$@" | cut -d';' -f1)
    [[ "$id" =~ ^[0-9]+$ ]] || { echo "[rt-switch] FATAL: sbatch gave '${id}' for ${name}" >&2; exit 1; }
    echo "[rt-switch] ${name}: ${id}" >&2; echo "$id"
  else
    echo "[rt-switch] ${name}: sbatch --clusters=htc $*" >&2; echo "<${name// /_}>"
  fi
}
L=--account=educ-lift
I=--account=educ-intract

# --- Extraction ------------------------------------------------------------------
T2=$(sub "P2 02 trajectory" $I --export="$EV" --time=00:30:00 "${H2}/02_extract_trajectory.slurm")
D0=$(sub "P1 00 descriptives" $L --export="$EV" --dependency="afterok:${T2}" --time=00:30:00 \
         "${H1}/00_descriptives.slurm")
DD=$(sub "P1 02 accuracy, diversity" $I --export="${EV},LES_P1_ACC_DIVERSITY=1" --time=00:30:00 \
         "${H1}/02_extract_accuracy.slurm")
DS=$(sub "P1 02 accuracy, legacy screen" $L --export="${EV},LES_P1_ACC_RT_SCREEN=1" --time=00:30:00 \
         "${H1}/02_extract_accuracy.slurm")
sub "P2 10 descriptives" $I --export="$EV" --dependency="afterok:${T2}" --time=01:00:00 \
    "${H2}/10_descriptives.slurm" >/dev/null

# --- Paper 1 accuracy models -------------------------------------------------------
F="${H1}/04_fit_accuracy.slurm"
P1=$(sub "P1 04 reported" $I --export="$EV" --dependency="afterok:${D0}" --time=03:00:00 "$F")
P2=$(sub "P1 04 weak priors" $L --export="${EV},LES_PRIOR_SET=weak" --dependency="afterok:${D0}" --time=03:00:00 "$F")
P3=$(sub "P1 04 added slope" $I --export="${EV},LES_P1_ACC_MAXRANEF=1" --dependency="afterok:${D0}" --time=03:00:00 "$F")
P4=$(sub "P1 04 by-item term" $L --export="${EV},LES_P1_ACC_ITEM=1" --dependency="afterok:${D0}" --time=03:00:00 "$F")
P5=$(sub "P1 04 slope and by-item term" $I --export="${EV},LES_P1_ACC_MAXRANEF=1,LES_P1_ACC_ITEM=1" \
         --dependency="afterok:${D0}" --time=03:00:00 "$F")
P6=$(sub "P1 04 diversity" $L --export="${EV},LES_P1_ACC_DIVERSITY=1" --dependency="afterok:${DD}" --time=03:00:00 "$F")
P7=$(sub "P1 04 legacy screen" $I --export="${EV},LES_P1_ACC_RT_SCREEN=1" --dependency="afterok:${DS}" --time=03:00:00 "$F")
sub "P1 05 summaries" $L --export="$EV" --dependency="afterok:${P1}:${P2}:${P3}:${P4}:${P5}:${P6}:${P7}" \
    --time=02:00:00 "${H1}/05_summaries.slurm" >/dev/null

# --- Paper 2 Part A, comparisons, diagnostic and summaries --------------------------
D2="--dependency=afterok:${T2}"
A1=$(sub "P2 04 Part A raw, pooled + gender" $L --export="$EV" $D2 --time=10:00:00 "${H2}/04_fit_predictors.slurm")
A2=$(sub "P2 04 Part A aperiodic" $I --export="$NS" $D2 --time=10:00:00 "${H2}/04_fit_predictors.slurm" aperiodic aperiodic_gender)
A3=$(sub "P2 04 Part A signal-detection" $L --export="${NS},LES_P2_SDT=1" $D2 --time=12:00:00 "${H2}/04_fit_predictors.slurm")
A4=$(sub "P2 04 Part A weak priors" $I --export="${NS},LES_PRIOR_SET=weak" $D2 --time=10:00:00 "${H2}/04_fit_predictors.slurm")
A5=$(sub "P2 04 Part A IAF-resolved gender" $L --export="${NS},LES_P2_IAF_RESOLVED=1" $D2 --time=06:00:00 "${H2}/04_fit_predictors.slurm" gender)
C1=$(sub "P2 09b common-sample comparison" $I --export="$EV" --dependency="afterok:${A1}:${A2}" \
         "${H2}/09b_compare_commonsample.slurm")
sub "P2 09c grouped comparison" $L --export="$EV" --dependency="afterok:${C1}" --time=1-04:00:00 \
    "${H2}/09c_compare_grouped.slurm" >/dev/null
sub "P2 08c order diagnostic" $I --export="$EV" --dependency="afterok:${C1}" --time=1-06:00:00 \
    "${H2}/08c_order_diagnostic.slurm" >/dev/null
sub "P2 06 summaries" $L --export="$EV" \
    --dependency="afterok:${A1}:${A2}:${A3}:${A4}:${A5}:${C1}" "${H2}/06_summaries.slurm" >/dev/null

echo "[rt-switch] $(wc -l < "$COUNT") submissions$([ "$SUBMIT" = "1" ] || echo ' (dry run: nothing submitted, nothing moved)')"
