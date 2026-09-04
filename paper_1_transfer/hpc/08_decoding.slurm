#!/bin/bash
# =============================================================================
# 08_decoding.slurm  --  Paper 1 MVPA decoding pipeline (SLURM job array, HTC)
# -----------------------------------------------------------------------------
# Multivariate (31-channel) decoding of Grammatical vs Ungrammatical over the epoch,
# with LOPO cross-validation, permutation and cluster inference, and session,
# cross-language, cross-property and temporal generalisation.
#
# TWO STAGES, selected by the LES_DECODE_STAGE environment variable:
#   * per_property (default) -- array 0-2, one task per grammatical property. Each task
#         (1) extracts that property's decoding tensor (08_extract_decoding_matrices.R)
#         then (2) runs its per-property decoders (09_run_decoding.R <property> all:
#         time-course + session/language + cross-language + temporal generalisation).
#   * cross_property        -- a single (non-array) task that runs the multi-tensor
#         cross-property generalisation. It reads the three extracted tensors and
#         nothing else: no per-property decoding output, and no permutation null. It
#         therefore needs only step (1) of each array task, which finishes within a
#         couple of hours of the array starting, and can run alongside the decoders
#         rather than after them. Chaining it on the whole array with afterok is what
#         left a three-minute analysis waiting a week behind the permutation runs.
#
# WHY THIS RESOURCING
# -------------------
# Extraction reuses the same memory-bound single-trial merge as step 01 (one property
# at a time) -> generous mem-per-cpu. Decoding is CPU-bound: per property we fit LDA at
# ~300 time points x (LOPO folds) x (1 + LES_DECODE_NPERM permutations); the permutation
# null dominates the cost, so we give a long walltime and several CPUs (R's BLAS uses
# them for the many small solve()/cov() calls). Standard QoS only.
#
# SUBMIT (do NOT run priority QoS):
#   # Stage 1 (extraction + per-property decoding), capture the array job id:
#   JID=$(sbatch --parsable --clusters=htc --account=educ-intract \
#         paper_1_transfer/hpc/08_decoding.slurm)
#   # Stage 2 (cross-property), once the three tensors exist in data_derived/:
#   sbatch --clusters=htc --account=educ-intract --array=0 \
#         --export=ALL,LES_DECODE_STAGE=cross_property \
#         -o paper_1_transfer/hpc/logs/08_decoding_crossproperty_%A.out \
#         paper_1_transfer/hpc/08_decoding.slurm
# Stage 2 needs both of those overrides. Without --array=0 the job inherits
# --array=0-2 below and starts three identical single-shot tasks, which race to write
# the same three crossproperty CSVs. Without the -o override its log path expands to
# 08_decoding_0.out, the file a running array element 0 already holds open.
# A fast smoke test: prepend --export=ALL,LES_DECODE_NPERM=25,LES_DECODE_TIME_STEP_MS=10.
# =============================================================================
#SBATCH --job-name=p1_decoding
#SBATCH --partition=long
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=32G
# Walltime was calibrated from the B=200 run, in which differential object marking took
# ~45 h (2-4 Jul 2026), on the reasoning that the permutation-bound part of the work
# scales with LES_DECODE_NPERM while the temporal-generalisation matrix does not.
# The B=1000 run then showed 14 days to be close to the minimum rather than generous:
# verb-object number agreement finished in 4 d 15 h and differential object marking in
# 7 d 15 h, but gender agreement was still running at 9 days and is projected to land
# within about a day of the wall. The `long` partition allows up to 30 days, so give a
# re-run of gender more than 14 if the queue permits.
#SBATCH --time=14-00:00:00
#SBATCH --array=0-2
#SBATCH -o paper_1_transfer/hpc/logs/08_decoding_%a.out

source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

# Which stage? Defaults to the per-property extract+decode array.
STAGE="${LES_DECODE_STAGE:-per_property}"

# Decoding tunables (exported to R via the environment; see 09_run_decoding.R).
# 1000 permutations, matching the standard documented in 09_run_decoding.R. The previous
# default of 200 silently contradicted that standard and put the p-floor (1/201 = .00497)
# above the level at which a cluster could clear the second-layer correction. Overridable
# DOWN only for a smoke test (see the header).
export LES_DECODE_NPERM="${LES_DECODE_NPERM:-1000}"
export LES_DECODE_TIME_STEP_MS="${LES_DECODE_TIME_STEP_MS:-4}"   # 4 ms decoding grid
export LES_DECODE_SEED="${LES_DECODE_SEED:-20260702}"

PROPS=(gender_agreement differential_object_marking verb_object_number_agreement)

if [ "${STAGE}" = "cross_property" ]; then
  echo "[decoding] STAGE=cross_property | start $(date)"
  Rscript "paper_1_transfer/scripts/09_run_decoding.R" _ crossprop \
      > "paper_1_transfer/hpc/logs/08_decoding_crossproperty.Rout" 2>&1
  echo "[decoding] cross_property finished $(date)"
  exit 0
fi

# --- per_property stage (array element = one property) -----------------------
PROP="${PROPS[$SLURM_ARRAY_TASK_ID]}"
echo "[decoding array ${SLURM_ARRAY_TASK_ID}] property=${PROP} | start $(date)"

# (1) Extract this property's decoding tensor (the EEG sensors common to every session
#     it was recorded in; the extractor drops the LiveAmp accelerometer and any channel
#     a contributing session lacks, so every property yields the same 31 sensors).
Rscript "paper_1_transfer/scripts/08_extract_decoding_matrices.R" "${PROP}" \
    > "paper_1_transfer/hpc/logs/08_extract_${PROP}.Rout" 2>&1

# (2) Run this property's decoders (time-course + session/language + cross-language +
#     temporal generalisation). Cross-property is deliberately excluded here; it is the
#     separate cross_property stage above.
Rscript "paper_1_transfer/scripts/09_run_decoding.R" "${PROP}" all \
    > "paper_1_transfer/hpc/logs/09_decoding_${PROP}.Rout" 2>&1

echo "[decoding array ${SLURM_ARRAY_TASK_ID}] ${PROP} finished $(date)"
