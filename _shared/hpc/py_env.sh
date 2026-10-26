#!/bin/bash
# =============================================================================
# _shared/hpc/py_env.sh  --  Python environment for the EEG reconstruction jobs
# -----------------------------------------------------------------------------
# SOURCED after _shared/hpc/arc_env.sh by the jobs that run Python
# (paper_1_transfer/hpc/00e_reprocess_eeg.slurm, 00f_assemble_eeg_overlay.slurm).
#
# The numerical stack comes from the cluster's SciPy-bundle module built on the same
# gfbf/2025a toolchain as the R module arc_env.sh loads, so the two load side by side
# (both bring Python/3.13.1-GCCcore-14.2.0). The one package the bundle lacks, olefile
# (the reader for Analyzer's .ehst2 history files), is pinned in
# paper_1_transfer/scripts/eeg_reconstruction/requirements.txt and installed into a
# virtual environment in LESS's own project-space folder, which sees the bundle through
# --system-site-packages. This follows the cluster's own guidance of loading a Python
# module and creating the environment in project space, not in $HOME.
#
# The environment is built once, on the login node (compute nodes may lack outbound
# network), by paper_1_transfer/hpc/00e_submit_reprocessing.sh; a job never creates it,
# because thirteen array tasks starting together would race to build it.
# The versions actually used are recorded in each provenance record.
# =============================================================================

LES_PY_MODULE="SciPy-bundle/2025.06-gfbf-2025a"
export LES_PYENV="${LES_BASE}/pyenv/eeg-recon-py3.13"

# _les_py_fatal <message>
#   Prints the message and ends a batch job, or returns 1 in an interactive shell, as
#   arc_env.sh does. The jobs source this file before `set -o errexit`, so a plain
#   `return` would let them carry on with the wrong Python.
_les_py_fatal() {
  echo "[py_env] FATAL: $*" >&2
  if [[ $- == *i* ]]; then return 1; else exit 1; fi
}

module load "${LES_PY_MODULE}" || { _les_py_fatal "module load ${LES_PY_MODULE} failed" || return 1; }
echo "[py_env] modules  : ${LOADEDMODULES:-<none>}"

if [ ! -x "${LES_PYENV}/bin/python" ]; then
  _les_py_fatal "${LES_PYENV} does not exist; run paper_1_transfer/hpc/00e_submit_reprocessing.sh on the login node first" || return 1
fi
unset -f _les_py_fatal
# shellcheck disable=SC1091
source "${LES_PYENV}/bin/activate"
# One thread per task: the work is sequential filtering, and the array supplies the
# parallelism. Stops a BLAS pool from oversubscribing the allocation.
export OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 FLEXIBLAS_NUM_THREADS=1
echo "[py_env] python   : $(command -v python) ($(python --version 2>&1))"
