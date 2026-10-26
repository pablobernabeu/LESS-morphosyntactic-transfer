#!/bin/bash
# =============================================================================
# 00e_submit_reprocessing.sh  --  build the Python environment and submit the chain (HTC)
# -----------------------------------------------------------------------------
# Run on the login node from the code root:
#
#   cd ~/new_LESS && LES_CODE_COMMIT=<git commit of the deployed code> \
#     bash paper_1_transfer/hpc/00e_submit_reprocessing.sh
#
# 1. Builds the virtual environment _shared/hpc/py_env.sh expects, once (login node, which
#    has network), from paper_1_transfer/scripts/eeg_reconstruction/requirements.txt.
# 2. Checks that the thirteen raw recordings are in the data tree.
# 3. Submits, on HTC and at standard QoS, with each stage split across the two project
#    accounts so neither carries it alone:
#      validate   13 tasks: educ-lift 0-6, educ-intract 7-12
#      reprocess   9 tasks: educ-lift 0-4, educ-intract 5-8   afterok on both validate arrays
#      assemble    1 job  : educ-lift                         afterok on both reprocess arrays
#    afterok on an array waits for every task, so one failed gate leaves the rest of the
#    chain pending with DependencyNeverSatisfied; cancel it once the failure is read.
#
# LES_CODE_COMMIT is written into every gate and provenance record. The cluster copy is
# not a git checkout, so the commit has to be passed in; the code digest recorded beside it
# is computed on the node either way.
# =============================================================================
set -o errexit
set -o nounset
cd "${LES_CODE_ROOT:-$HOME/new_LESS}"

# The environment variables the jobs set (LES_BASE, LES_DATA_ROOT) are needed here too.
source _shared/hpc/arc_env.sh >/dev/null
module load SciPy-bundle/2025.06-gfbf-2025a
PYENV="${LES_BASE}/pyenv/eeg-recon-py3.13"
if [ ! -x "${PYENV}/bin/python" ]; then
  echo "[00e] building ${PYENV}"
  python -m venv --system-site-packages "${PYENV}"
  "${PYENV}/bin/pip" install --no-cache-dir -r paper_1_transfer/scripts/eeg_reconstruction/requirements.txt
fi
"${PYENV}/bin/python" -c "import numpy, scipy, pandas, olefile; print('[00e] numpy', numpy.__version__, 'scipy', scipy.__version__, 'pandas', pandas.__version__, 'olefile', olefile.__version__)"

RAW="${LES_DATA_ROOT}/raw data/EEG/Session 3/Raw"
for p in 7 8 9 16 53 60 61 62 65 10 51 58 59; do
  for x in vhdr vmrk eeg; do
    [ -s "${RAW}/${p}.${x}" ] || { echo "[00e] FATAL: ${RAW}/${p}.${x} missing (HPC_RUNBOOK.md, section 0)" >&2; exit 1; }
  done
done

mkdir -p paper_1_transfer/hpc/logs
: "${LES_CODE_COMMIT:=unknown}"
SB=(sbatch --parsable --clusters=htc)
EV="ALL,LES_CODE_COMMIT=${LES_CODE_COMMIT}"
S00E=paper_1_transfer/hpc/00e_reprocess_eeg.slurm
jid() { cut -d';' -f1; }   # --parsable on HTC prints "<id>;htc"

V1=$("${SB[@]}" --account=educ-lift    --array=0-6  --export="${EV},LES_REPROCESS_STAGE=validate" "${S00E}" | jid)
V2=$("${SB[@]}" --account=educ-intract --array=7-12 --export="${EV},LES_REPROCESS_STAGE=validate" "${S00E}" | jid)
R1=$("${SB[@]}" --account=educ-lift    --array=0-4  --dependency="afterok:${V1}:${V2}" --export="${EV},LES_REPROCESS_STAGE=reprocess" "${S00E}" | jid)
R2=$("${SB[@]}" --account=educ-intract --array=5-8  --dependency="afterok:${V1}:${V2}" --export="${EV},LES_REPROCESS_STAGE=reprocess" "${S00E}" | jid)
A=$("${SB[@]}"  --account=educ-lift    --dependency="afterok:${R1}:${R2}" --export="${EV}" paper_1_transfer/hpc/00f_assemble_eeg_overlay.slurm | jid)

echo "[00e] validate ${V1} (educ-lift 0-6), ${V2} (educ-intract 7-12)"
echo "[00e] reprocess ${R1} (educ-lift 0-4), ${R2} (educ-intract 5-8)"
echo "[00e] assemble ${A} (educ-lift)"
