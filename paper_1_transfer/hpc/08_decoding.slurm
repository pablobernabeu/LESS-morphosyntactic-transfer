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
# at a time), and it, not the decoding, sets the memory: on HTC it peaked at 195 GB for
# differential object marking and 117 GB for verb-object number agreement (8829254_1/_2),
# and gender agreement's was killed at 254 GiB of 256 (8829254_0). The 32 GB per CPU below
# is therefore a floor; hpc/submit_eeg_rerun.sh raises it to 60 GB (480 GB) for gender
# and 40 GB for the other two. Decoding is CPU-bound but single-threaded: per property we
# fit LDA at ~300 time points x (LOPO folds) x (1 + LES_DECODE_NPERM permutations), in
# plain R loops. stats::cov() does not call BLAS, and the 31 x 31 solve() is too small to
# gain from threads; the finished B = 1000 elements kept about one of their eight CPUs
# busy (sacct TotalCPU 7-11:27:48 over Elapsed 7-12:12:32 for 8829254_1, 4-20:06:59 over
# 4-20:37:10 for 8829254_2). The 8 CPUs buy memory through --mem-per-cpu, not speed, so
# the walltime has to come from the permutation count alone. Standard QoS only.
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
#
# NO SMOKE TEST THROUGH THIS SCRIPT. arc_env.sh points LES_STORE at the shared store
# unconditionally, and no decoding artefact is tagged by its settings: the tensor, the
# block checkpoints and partials, the CSVs and the provenance record all keep their
# reported names whatever B or time step produced them. A reduced run would therefore
# overwrite the reported tensor and CSVs and replace banked B = 1000 blocks, whose
# fingerprints it does not match, with its own. This script refuses LES_DECODE_NPERM
# below 1000 and LES_DECODE_TIME_STEP_MS other than 4 for that reason. Smoke-test steps
# 08 and 09 by hand instead, in a job of your own that re-points the store after
# sourcing arc_env.sh, e.g.
#   source _shared/hpc/arc_env.sh && export LES_STORE="${LES_BASE}/store_smoke" \
#     LES_DECODE_NPERM=25 LES_DECODE_TIME_STEP_MS=10 &&
#   Rscript paper_1_transfer/scripts/08_extract_decoding_matrices.R verb_object_number_agreement &&
#   Rscript paper_1_transfer/scripts/09_run_decoding.R verb_object_number_agreement timecourse
# The extraction still needs the full merge's memory (see WHY THIS RESOURCING), and at
# B = 25 the confirmatory FDR stops the time-course at its end once the overall
# time-course has two or more clusters, which is that guard working as intended.
# =============================================================================
#SBATCH --job-name=p1_decoding
#SBATCH --partition=long
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem-per-cpu=32G
# Walltime. Measured at B = 1000, whole elements on 8 CPUs: verb-object number agreement
# 4 d 15 h (ARC 12664261_2, August 2026) and 4 d 21 h (HTC 8829254_2, September);
# differential object marking 7 d 15 h (ARC 12664261_1) and 7 d 12 h (HTC 8829254_1).
# Gender agreement, the largest property, has not yet run start to finish in one element:
# its overall block (about 44% of a property's permutation work, 09_run_decoding.R) was
# banked across several ARC elements in August, and the remaining twelve blocks,
# cross-language and temporal generalisation then took 7 d 17 h on their own (HTC
# 8736986_0, September), so a whole gender run is of the order of 13-14 days, at this
# wall. Hitting the wall costs little: every finished block is banked and the running one
# is saved every LES_DECODE_CKPT_EVERY permutations (09_run_decoding.R), so resubmitting
# the same element resumes where it stopped, bit-identically. The `long` partition allows
# up to 30 days if a longer single run is preferred.
#SBATCH --time=14-00:00:00
#SBATCH --array=0-2
#SBATCH -o paper_1_transfer/hpc/logs/08_decoding_%a.out

source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

# Which stage? Defaults to the per-property extract+decode array. Anything else used to
# fall through to the per-property stage, so a mistyped stage-2 submission
# (LES_DECODE_STAGE=crossprop, the R stage name) silently re-ran element 0's whole
# property (ISSUES.md G09-03). LES_DECODE_ANALYSES is checked for the same reason: an
# unknown value used to make step 09 run nothing and still report success, and `crossprop`
# made every array element race to write the cross-property CSVs.
STAGE="${LES_DECODE_STAGE:-per_property}"
case "${STAGE}" in
  per_property|cross_property) ;;
  *) echo "[decoding] unknown LES_DECODE_STAGE=${STAGE} (expected per_property or cross_property)" >&2
     exit 1 ;;
esac
case "${LES_DECODE_ANALYSES:-all}" in
  all|timecourse|crosslang|temporalgen) ;;
  *) echo "[decoding] unknown LES_DECODE_ANALYSES=${LES_DECODE_ANALYSES} (expected all, timecourse, crosslang or temporalgen)" >&2
     exit 1 ;;
esac

# Decoding tunables (exported to R via the environment; see 09_run_decoding.R).
# 1000 permutations, matching the standard documented in 09_run_decoding.R. The previous
# default of 200 silently contradicted that standard and put the p-floor (1/201 = .00497)
# above the level at which a cluster could clear the second-layer correction. The two
# defaults are also typed in 09_run_decoding.R (LES_DECODE_NPERM), in
# 08_extract_decoding_matrices.R (the time step) and in 08b_verify_gender_decoding.slurm
# (the expected n_perm); keep them in step.
DECODE_NPERM_DEFAULT=1000
DECODE_TIME_STEP_DEFAULT=4                                         # 4 ms decoding grid
export LES_DECODE_NPERM="${LES_DECODE_NPERM:-${DECODE_NPERM_DEFAULT}}"
export LES_DECODE_TIME_STEP_MS="${LES_DECODE_TIME_STEP_MS:-${DECODE_TIME_STEP_DEFAULT}}"
# Nothing this job writes is tagged by B or by the time step (see "NO SMOKE TEST" in the
# header), so a reduced count or another grid would overwrite the reported tensor and
# CSVs and replace banked blocks. A larger B is allowed: it is a deliberate upgrade of the
# reported analysis, and n_perm records it in every row.
case "${LES_DECODE_NPERM}" in
  ''|*[!0-9]*) echo "[decoding] LES_DECODE_NPERM=${LES_DECODE_NPERM} is not a whole number" >&2; exit 1 ;;
esac
if [ "${LES_DECODE_NPERM}" -lt "${DECODE_NPERM_DEFAULT}" ] ||
   [ "${LES_DECODE_TIME_STEP_MS}" != "${DECODE_TIME_STEP_DEFAULT}" ]; then
  echo "[decoding] refusing LES_DECODE_NPERM=${LES_DECODE_NPERM}, LES_DECODE_TIME_STEP_MS=${LES_DECODE_TIME_STEP_MS}: this job writes the reported, untagged decoding artefacts in the shared store; smoke-test by hand against another store (see the header)" >&2
  exit 1
fi
# The seed default is LES_P1_DECODE_SEED_DEFAULT in scripts/_config.R, repeated here and in
# 09_run_decoding.R; scripts/test_exclusion_guard.R checks that the three agree.
export LES_DECODE_SEED="${LES_DECODE_SEED:-20260702}"

PROPS=(gender_agreement differential_object_marking verb_object_number_agreement)

# The robustness analysis (LES_P1_EXCLUDE_REPROCESSED=1) tags its tensors and CSVs in the R
# scripts; its logs and its provenance record are tagged here, so that neither overwrites
# the primary run's.
TAG=""
[ "${LES_P1_EXCLUDE_REPROCESSED:-0}" = "1" ] && TAG="${TAG}_exclreproc"

# LES_DECODE_CONFIRMATORY_ONLY=1 writes a time-course CSV holding the overall block alone,
# under the same name as the full one. Protocol Amendment 5 uses it for the robustness
# arm only, whose files carry the _exclreproc tag. Exported for the primary arm, for
# instance inherited from a shell prepared for the robustness submission, it would replace
# the reported primary CSV with its confirmatory rows: the failure ISSUES.md G09-01
# described for the retired LES_P1_KEEP_MISFILTERED, an untagged switch inherited from the
# submitting shell. To report the primary confirmatory family before the exploratory
# blocks finish, assemble it from the banked checkpoints with
# paper_1_transfer/scripts/09b_assemble_confirmatory_timecourse.R instead.
# The values tested are the ones 09_run_decoding.R treats as on (.les_truthy).
CONF_ONLY="$(printf '%s' "${LES_DECODE_CONFIRMATORY_ONLY:-}" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]')"
case "${CONF_ONLY}" in
  1|true|yes|y|t)
    if [ -z "${TAG}" ]; then
      echo "[decoding] refusing LES_DECODE_CONFIRMATORY_ONLY=${LES_DECODE_CONFIRMATORY_ONLY} without LES_P1_EXCLUDE_REPROCESSED=1: it would overwrite the primary time-course CSV with the overall block alone" >&2
      exit 1
    fi ;;
esac

if [ "${STAGE}" = "cross_property" ]; then
  echo "[decoding] STAGE=cross_property | start $(date)"
  Rscript "paper_1_transfer/scripts/09_run_decoding.R" _ crossprop \
      > "paper_1_transfer/hpc/logs/08_decoding_crossproperty${TAG}.Rout" 2>&1
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
    > "paper_1_transfer/hpc/logs/08_extract_${PROP}${TAG}.Rout" 2>&1

# (2) Run this property's decoders (time-course + session/language + cross-language +
#     temporal generalisation). Cross-property is deliberately excluded here; it is the
#     separate cross_property stage above. LES_DECODE_ANALYSES narrows the stages
#     (timecourse | crosslang | temporalgen | all); the robustness arm exports
#     LES_DECODE_ANALYSES=timecourse with LES_DECODE_CONFIRMATORY_ONLY=1, which together
#     compute the confirmatory (overall) family alone (protocol Amendment 5).
Rscript "paper_1_transfer/scripts/09_run_decoding.R" "${PROP}" "${LES_DECODE_ANALYSES:-all}" \
    > "paper_1_transfer/hpc/logs/09_decoding_${PROP}${TAG}.Rout" 2>&1

# (3) Record the settings this job exported, beside the decoding artefacts. The ERP
#     fitting run's provenance record carries only a default for the decoding seed, since
#     no decoding job sets it there, so the manuscript reads the decoding seed from this
#     record. Every array element writes the same values, so the file is idempotent.
NOW="$(date -u +%FT%TZ)"
printf 'component,version,recorded_utc\nseed:LES_DECODE_SEED,%s,%s\nLES_DECODE_NPERM,%s,%s\nLES_DECODE_TIME_STEP_MS,%s,%s\n' \
    "${LES_DECODE_SEED}" "${NOW}" "${LES_DECODE_NPERM}" "${NOW}" "${LES_DECODE_TIME_STEP_MS}" "${NOW}" \
    > "${LES_STORE}/paper_1_transfer/results/_decoding_provenance${TAG}.csv"

echo "[decoding array ${SLURM_ARRAY_TASK_ID}] ${PROP} finished $(date)"
