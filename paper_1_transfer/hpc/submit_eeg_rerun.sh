#!/bin/bash
# =============================================================================
# submit_eeg_rerun.sh  --  every Paper 1 EEG stage, once, from the admitted overlay (HTC)
# -----------------------------------------------------------------------------
# docs/eeg_filter_reprocessing_protocol.md ("Downstream release gate") requires the
# single-trial extracts, grand averages, decoding tensors, fits and pooled summaries to be
# regenerated from one clean provenance state once the overlay is accepted, with the
# robustness analysis tagged and never overwriting the primary artefacts. This script does
# that in one submission. Run it on the login node from the code root:
#
#   bash paper_1_transfer/hpc/submit_eeg_rerun.sh                    # dry run: prints everything
#   LES_SUBMIT=1 LES_CODE_COMMIT=<deployed commit> \
#     bash paper_1_transfer/hpc/submit_eeg_rerun.sh                  # archive, then submit
#
# WHAT IT SUBMITS (HTC, standard QoS; every array split across educ-lift and educ-intract)
#   00  descriptives                         single
#   01  single-trial extraction, primary     6 tasks
#   01  single-trial extraction, robustness  6 tasks   LES_P1_EXCLUDE_REPROCESSED=1
#   07  / 07b grand averages                 6 + 6     primary only, by design
#   03  ERP fits, after their 01 array:
#         maximal (_itemslope), PRIMARY      18        writes _provenance.csv and the
#                                                      prior predictive check figure
#         base structure                     18        structural comparison
#         maximal, weak priors               18        prior sensitivity
#         maximal, retention-free            12        gender and DOM only (VOA has 2 sessions)
#         base, weak priors                  18        } the Method states the prior and
#         base, retention-free               12        } retention refits for both structures
#         maximal, robustness                18        after the robustness 01 array
#   08  decoding, primary, all analyses      3 tasks   gender 480 GB, DOM 320 GB, VOA 256 GB
#   08b watcher on the gender element
#   08  decoding, robustness, confirmatory   3 tasks   overall time-course only (Amendment 5)
#   05  pooled summaries                     single    after every 03 array
# The cross-property decoding stage (08 with LES_DECODE_STAGE=cross_property) needs the
# three primary tensors, which the primary 08 tasks write within hours of starting; it is
# submitted separately once they exist (README.md, "Pipeline").
#
# BEFORE SUBMITTING it archives the superseded ERP and decoding artefacts (the 16 and
# 17 September cluster-row fits, grand averages and decoding outputs) into
# results/_archive_<date>_before_trial_level_rerun/ and the matching data_derived/ folder,
# so the store holds one provenance state. Moves only; nothing is deleted. Script 05 lists
# results/ non-recursively, so archived fits are never pooled.
#
# Resources and memory: the gender decoding tensor extraction peaked at 254 GiB of 256 when
# it was killed on 16 September, with the nine records still excluded; with them and the
# recovered records admitted it gets 480 GB, which HTC's 515 GB and larger long nodes hold.
# DOM's peak was 195 GB and VOA's 117 GB on the same date.
# =============================================================================
set -o errexit
set -o nounset
cd "${LES_CODE_ROOT:-$HOME/new_LESS}"
source _shared/hpc/arc_env.sh >/dev/null

SUBMIT="${LES_SUBMIT:-0}"
HPC=paper_1_transfer/hpc
LOG=paper_1_transfer/hpc/logs
STORE="${LES_STORE}/paper_1_transfer"
TODAY="$(date +%F)"
ARCH="_archive_${TODAY}_before_trial_level_rerun"

# --- Preconditions -------------------------------------------------------------
if squeue --clusters=htc,arc -u "$USER" -h -o '%j' | grep -q '^p1_'; then
  echo "[rerun] FATAL: a Paper 1 job is live; this chain must start from a quiet queue" >&2; exit 1
fi
MAN=paper_1_transfer/eeg_overlay_manifest.csv
n_man=$(($(wc -l < "$MAN") - 1))
n_ov=$(find "${STORE}/data_derived/eeg_overlay" -type f | wc -l)
if [ "$n_man" -ne "$n_ov" ] || [ "$n_man" -lt 1 ]; then
  echo "[rerun] FATAL: overlay holds ${n_ov} files, the deployed manifest lists ${n_man}" >&2; exit 1
fi
echo "[rerun] overlay: ${n_ov} files, all listed in the deployed manifest"

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
  echo "[rerun] archive ${dir#${LES_STORE}/}: ${n} entries -> ${ARCH}$([ "$SUBMIT" = "1" ] || echo ' (dry run)')"
}
archive "${STORE}/results" 'erp_*' '*_decoding_*' '_grand_average_*' '_electrode_grand_average_*' \
        '_electrode_window_difference_*' '_difference_wave_*' '_decoding_provenance*'
archive "${STORE}/data_derived" 'erp_*.rds' '_decoding_*' '_tc_ckpt_*' '_tc_part_*'

# --- Submission helpers --------------------------------------------------------
: "${LES_CODE_COMMIT:=unknown}"
mkdir -p "$LOG"
EV="ALL,LES_CODE_COMMIT=${LES_CODE_COMMIT}"
FIT="${EV},LES_CMDSTAN_VERSION=2.39.0"
# sub runs inside $(...), a subshell, so its count is kept in a file, not a variable.
COUNT=$(mktemp); trap 'rm -f "$COUNT"' EXIT
sub() {   # sub <name> <sbatch args...>; echoes the job id (or a named placeholder in a dry run)
  local name="$1"; shift
  echo >> "$COUNT"
  if [ "$SUBMIT" = "1" ]; then
    local id; id=$(sbatch --parsable --clusters=htc "$@" | cut -d';' -f1)
    echo "[rerun] ${name}: ${id}" >&2; echo "$id"
  else
    echo "[rerun] ${name}: sbatch --clusters=htc $*" >&2; echo "<${name// /_}>"
  fi
}
L=--account=educ-lift
I=--account=educ-intract

# --- 00 descriptives, 01 extraction, 07 / 07b grand averages ---------------------
sub "00 descriptives" $I "${HPC}/00_descriptives.slurm" >/dev/null
P1=$(sub "01 primary 0-2"     $L --array=0-2 --export="$EV" "${HPC}/01_extract_erp.slurm")
P2=$(sub "01 primary 3-5"     $I --array=3-5 --export="$EV" "${HPC}/01_extract_erp.slurm")
X1=$(sub "01 robustness 0-2"  $I --array=0-2 --export="${EV},LES_P1_EXCLUDE_REPROCESSED=1" \
         -o "${LOG}/01_extract_erp_exclreproc_%a.out" "${HPC}/01_extract_erp.slurm")
X2=$(sub "01 robustness 3-5"  $L --array=3-5 --export="${EV},LES_P1_EXCLUDE_REPROCESSED=1" \
         -o "${LOG}/01_extract_erp_exclreproc_%a.out" "${HPC}/01_extract_erp.slurm")
sub "07 0-2"  $L --array=0-2 --export="$EV" "${HPC}/07_grand_average.slurm" >/dev/null
sub "07 3-5"  $I --array=3-5 --export="$EV" "${HPC}/07_grand_average.slurm" >/dev/null
sub "07b 0-2" $I --array=0-2 --export="$EV" "${HPC}/07b_grand_average_electrode.slurm" >/dev/null
sub "07b 3-5" $L --array=3-5 --export="$EV" "${HPC}/07b_grand_average_electrode.slurm" >/dev/null

# --- 03 ERP fits -----------------------------------------------------------------
DP="--dependency=afterok:${P1}:${P2}"
DX="--dependency=afterok:${X1}:${X2}"
F=()
PRI="${FIT},LES_P1_ITEM_SLOPE=1,LES_PRIOR_PREDICTIVE=1,LES_P1_PRIORPC_REPRESENTATIVE=erp_gender_agreement_400_900_midline_itemslope"
F+=($(sub "03 maximal (primary) 0-8"  $L --array=0-8  $DP --export="$PRI" -o "${LOG}/03_fit_erp_itemslope_%a.out" "${HPC}/03_fit_erp.slurm"))
F+=($(sub "03 maximal (primary) 9-17" $I --array=9-17 $DP --export="$PRI" -o "${LOG}/03_fit_erp_itemslope_%a.out" "${HPC}/03_fit_erp.slurm"))
BAS="${FIT},LES_PROVENANCE_SKIP=1"
F+=($(sub "03 base 0-8"  $I --array=0-8  $DP --export="$BAS" -o "${LOG}/03_fit_erp_%a.out" "${HPC}/03_fit_erp.slurm"))
F+=($(sub "03 base 9-17" $L --array=9-17 $DP --export="$BAS" -o "${LOG}/03_fit_erp_%a.out" "${HPC}/03_fit_erp.slurm"))
WEA="${FIT},LES_PROVENANCE_SKIP=1,LES_P1_ITEM_SLOPE=1,LES_PRIOR_SET=weak"
F+=($(sub "03 maximal weak prior 0-8"  $L --array=0-8  $DP --export="$WEA" -o "${LOG}/03_fit_erp_itemslope_weakprior_%a.out" "${HPC}/03_fit_erp.slurm"))
F+=($(sub "03 maximal weak prior 9-17" $I --array=9-17 $DP --export="$WEA" -o "${LOG}/03_fit_erp_itemslope_weakprior_%a.out" "${HPC}/03_fit_erp.slurm"))
RET="${FIT},LES_PROVENANCE_SKIP=1,LES_P1_ITEM_SLOPE=1,LES_P1_RETENTION_FREE=1"
F+=($(sub "03 maximal retention-free 0-5"  $I --array=0-5  $DP --export="$RET" -o "${LOG}/03_fit_erp_retfree_itemslope_%a.out" "${HPC}/03_fit_erp.slurm"))
F+=($(sub "03 maximal retention-free 6-11" $L --array=6-11 $DP --export="$RET" -o "${LOG}/03_fit_erp_retfree_itemslope_%a.out" "${HPC}/03_fit_erp.slurm"))
BWE="${FIT},LES_PROVENANCE_SKIP=1,LES_PRIOR_SET=weak"
F+=($(sub "03 base weak prior 0-8"  $L --array=0-8  $DP --export="$BWE" -o "${LOG}/03_fit_erp_weakprior_%a.out" "${HPC}/03_fit_erp.slurm"))
F+=($(sub "03 base weak prior 9-17" $I --array=9-17 $DP --export="$BWE" -o "${LOG}/03_fit_erp_weakprior_%a.out" "${HPC}/03_fit_erp.slurm"))
BRE="${FIT},LES_PROVENANCE_SKIP=1,LES_P1_RETENTION_FREE=1"
F+=($(sub "03 base retention-free 0-5"  $I --array=0-5  $DP --export="$BRE" -o "${LOG}/03_fit_erp_retfree_%a.out" "${HPC}/03_fit_erp.slurm"))
F+=($(sub "03 base retention-free 6-11" $L --array=6-11 $DP --export="$BRE" -o "${LOG}/03_fit_erp_retfree_%a.out" "${HPC}/03_fit_erp.slurm"))
EXC="${FIT},LES_PROVENANCE_SKIP=1,LES_P1_ITEM_SLOPE=1,LES_P1_EXCLUDE_REPROCESSED=1"
F+=($(sub "03 maximal robustness 0-8"  $I --array=0-8  $DX --export="$EXC" -o "${LOG}/03_fit_erp_exclreproc_itemslope_%a.out" "${HPC}/03_fit_erp.slurm"))
F+=($(sub "03 maximal robustness 9-17" $L --array=9-17 $DX --export="$EXC" -o "${LOG}/03_fit_erp_exclreproc_itemslope_%a.out" "${HPC}/03_fit_erp.slurm"))

# --- 08 decoding -----------------------------------------------------------------
G=$(sub "08 primary gender (480 GB)" $L --array=0 --mem-per-cpu=60G --export="$EV" "${HPC}/08_decoding.slurm")
sub "08 primary DOM + VOA (320 GB)" $I --array=1-2 --mem-per-cpu=40G --export="$EV" "${HPC}/08_decoding.slurm" >/dev/null
sub "08b watcher on gender" $I --dependency="afterany:${G}_0" \
    --export="${EV},LES_DECODE_WATCH_JOB=${G}_0" "${HPC}/08b_verify_gender_decoding.slurm" >/dev/null
CON="${EV},LES_P1_EXCLUDE_REPROCESSED=1,LES_DECODE_ANALYSES=timecourse,LES_DECODE_CONFIRMATORY_ONLY=1"
sub "08 robustness gender, confirmatory (480 GB)" $I --array=0 --mem-per-cpu=60G --time=7-00:00:00 \
    --export="$CON" -o "${LOG}/08_decoding_exclreproc_%a.out" "${HPC}/08_decoding.slurm" >/dev/null
sub "08 robustness DOM + VOA, confirmatory" $L --array=1-2 --time=7-00:00:00 \
    --export="$CON" -o "${LOG}/08_decoding_exclreproc_%a.out" "${HPC}/08_decoding.slurm" >/dev/null

# --- 05 summaries ----------------------------------------------------------------
DEP05="afterok$(printf ':%s' "${F[@]}")"
sub "05 summaries" $L --dependency="$DEP05" --export="$EV" "${HPC}/05_summaries.slurm" >/dev/null

echo "[rerun] $(wc -l < "$COUNT") submissions $([ "$SUBMIT" = "1" ] && echo 'made' || echo 'printed (dry run; LES_SUBMIT=1 to submit)')"
