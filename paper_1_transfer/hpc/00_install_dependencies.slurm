#!/bin/bash
# =============================================================================
# 00_install_dependencies.slurm  --  bootstrap the Bayesian toolchain where none exists (ARC)
# -----------------------------------------------------------------------------
# Installs brms + the CmdStan C++ toolchain, posterior/bayesplot/tidybayes/
# bayestestR, papaja and the Paper 2 resting-state stack INTO the project-space R
# library ($LES_BASE/Rlib/R-4.5) and builds CmdStan under $LES_BASE/cmdstan. Run a
# SINGLE time before any model-fitting job (it is shared with Paper 2 -- do not run both
# 00 scripts).
#
# This is a bootstrap for a library that does not yet exist, resolved against whatever
# CRAN ships on the day, and it is not the reproduction route. To rebuild the recorded
# environment, restore renv.lock through _shared/hpc/00_restore_environment.slurm
# (submit_all.sh with_restore chains on it), which pins the packages and the CmdStan
# version.
#
# Package installation + the CmdStan build need OUTBOUND NETWORK and a compiler.
# The R/4.5.1-gfbf-2025a module brings the gfbf/2025a toolchain (GCC 14.2.0 with
# OpenBLAS, FlexiBLAS and FFTW), which is not foss. ARC compute nodes
# normally have network; if a build node does not, run this on the `interactive`
# partition instead:  srun -p interactive --pty bash  then  source the env + Rscript.
#
# Submit:  sbatch paper_1_transfer/hpc/00_install_dependencies.slurm
# =============================================================================
#SBATCH --job-name=p1_install_bayes
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=4G
#SBATCH --time=08:00:00
#SBATCH -o paper_1_transfer/hpc/logs/00_install_dependencies.out

source _shared/hpc/arc_env.sh        # module load R + project-space R_LIBS_USER / CMDSTAN_INSTALL_DIR
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

# CmdStan + packages build faster with all allocated cores.
export LES_INSTALL_CORES="${SLURM_CPUS_PER_TASK:-8}"

Rscript "_shared/install_bayesian_dependencies.R" \
    > "paper_1_transfer/hpc/logs/00_install_dependencies.log" 2>&1

echo "Dependency provisioning finished at $(date)"
