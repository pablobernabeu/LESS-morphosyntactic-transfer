#!/bin/bash
# =============================================================================
# 99b_test_O2.slurm -- follow-up to 99_diagnose_ice.slurm, testing whether -O2 or -O3
# escapes the reduce_sum ICE. -O1 works but costs sampling speed, and -O2 would have
# kept both within-chain threading and most of the optimisation.
# -----------------------------------------------------------------------------
# SETTLED, 2026-08-04 (job 12684918): neither does. With threading on, -O2 ICEs after
# 4 s and -O3 after 19 s, so -O1 remains the only workable level and _shared/hpc/arc_env.sh
# pins it. Retained only to re-measure after a toolchain upgrade.
#
# PREREQUISITE: this script rebuilds $LES_STORE/../ice_diag/threaded, so it needs the
# threaded.stan that 99_diagnose_ice.slurm generates in that scratch directory. Run 99
# first. On its own this job has nothing to compile.
#
# Submit:  sbatch paper_1_transfer/hpc/99b_test_O2.slurm
# =============================================================================
#SBATCH --job-name=p1_ice_O2
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=12G
#SBATCH --time=00:30:00
#SBATCH -o paper_1_transfer/hpc/logs/99b_test_O2.out
source _shared/hpc/arc_env.sh
set -o nounset
D=$LES_STORE/../ice_diag
echo "[O2] node=$(hostname)"
for OPT in -O2 -O3; do
  rm -f "$D/threaded" "$D/threaded.hpp" "$D/threaded.o"
  t0=$SECONDS
  ( cd "$CMDSTAN" && make STAN_THREADS=true CXXFLAGS_OPTIM=$OPT "$D/threaded" ) > "$D/opt$OPT.log" 2>&1
  rc=$?
  echo "[O2] threaded $OPT -> rc=$rc elapsed=$((SECONDS-t0))s"
  [ $rc -ne 0 ] && tail -4 "$D/opt$OPT.log"
done
echo "[O2] done"
