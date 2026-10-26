#!/bin/bash
# =============================================================================
# 00_descriptives.slurm  --  the raw-data descriptives the manuscripts inject (ARC)
# -----------------------------------------------------------------------------
# Runs the light extraction scripts that read only data/ and the derived files already in
# the store, and write the descriptive tables both manuscripts read:
#   00c_extract_erp_retention.R   _erp_trial_retention.csv, _misfiltered_share.csv, from
#                                 the single-trial cell files step 01 wrote
#   02_extract_accuracy.R         accuracy_<property>.rds (the same trials and model
#                                 variables, plus item_id), _accuracy_rt_screen.csv,
#                                 _accuracy_sentence_inventory.csv,
#                                 _accuracy_item_inventory.csv and the other tables
#                                 its header lists
#   00_extract_participants.R     _sample_flow.csv, _participants.csv and
#                                 _participants_other_languages.csv, to both papers
#   00b_audit_participant_flow.R  _participant_matrix.csv and _flow_inconsistencies.csv,
#                                 to both papers (an audit no manuscript reads)
# Script 00 runs after 02 because it counts participants in the accuracy files script 02
# writes, and 00b after 00 because it reconciles the flow 00 writes. The retention test
# then checks the headline values of the table 00c wrote; if it fails, the job is marked
# failed after every table has been written. No model is fitted and no fit is
# invalidated: script 02 rewrites the accuracy data with the trials and model variables
# the reported fits were computed from, and brms's on-change cache check compares the
# Stan code and Stan data, which an unused column such as item_id does not enter.
#
# Run time: 1 min 38 s for all four scripts on HTC on 3 October 2026 (8976030), so the one
# hour requested below is ample; 02_extract_accuracy.slurm's two hours for script 02 alone
# is generous for the same reason.
#
#   sbatch --clusters=htc --account=educ-intract paper_1_transfer/hpc/00_descriptives.slurm
# (Standard QoS only -- never --qos=priority.)
# =============================================================================
#SBATCH --job-name=p1_descriptives
#SBATCH --partition=short
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=2
#SBATCH --mem-per-cpu=8G
#SBATCH --time=01:00:00
#SBATCH -o paper_1_transfer/hpc/logs/00_descriptives.out

source _shared/hpc/arc_env.sh
set -o errexit
set -o nounset
mkdir -p paper_1_transfer/hpc/logs

# The variant switches must be unset: this job regenerates the reported artefacts.
unset LES_P1_ACC_DIVERSITY LES_P1_ACC_RT_SCREEN LES_P1_ACC_NO_RT_SCREEN LES_P1_EXCLUDE_REPROCESSED

Rscript "paper_1_transfer/scripts/00c_extract_erp_retention.R" \
    > "paper_1_transfer/hpc/logs/00c_extract_erp_retention.Rout" 2>&1
Rscript "paper_1_transfer/scripts/02_extract_accuracy.R" \
    > "paper_1_transfer/hpc/logs/02_extract_accuracy.Rout" 2>&1
Rscript "paper_1_transfer/scripts/00_extract_participants.R" \
    > "paper_1_transfer/hpc/logs/00_extract_participants.Rout" 2>&1
Rscript "paper_1_transfer/scripts/00b_audit_participant_flow.R" \
    > "paper_1_transfer/hpc/logs/00b_audit_participant_flow.Rout" 2>&1

# Check on the retention table just written; its output goes to this job's log.
Rscript "paper_1_transfer/scripts/tests/test_erp_retention_artefact.R"

echo "00 descriptives finished $(date)"
