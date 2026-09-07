# Codebook for `paper_1_transfer/results`

This file is machine-written by `_shared/R/write_codebook.R` and is not edited by hand. It lists every manuscript-facing CSV in this folder and, for each column, the R class that `read.csv()` infers from the first 200 rows (a column that is entirely NA within those rows reads as `logical`), a description taken from `_shared/R/codebook_descriptions.csv`, and the script that writes the file. To regenerate it after pulling the CSVs from the cluster, run `Rscript _shared/R/write_codebook.R` from the project root. Descriptions are added or corrected in `_shared/R/codebook_descriptions.csv`; a column still marked `(description pending)` needs one. The row counts are those of the files present when the codebook was generated.

## `_accuracy_input_gaps.csv`

7 data row(s), 4 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `reason` | character | Why the extraction cannot read the logfile: 'split_export' (the run is split across subject-N-test.csv and subject-N-experiment.csv, which the file pattern does not match) or 'semicolon_delimited' (the comma-delimited reader parses the export as a single column). One row per affected logfile. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `file` | character | Base name of the OpenSesame logfile. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `session` | integer | Session number parsed from the folder name (2, 3, 4 or 6). | paper_1_transfer/scripts/02_extract_accuracy.R |
| `participant_lab_ID` | integer | Integer lab ID parsed from the file name. | paper_1_transfer/scripts/02_extract_accuracy.R |

## `_accuracy_rt_screen.csv`

1 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `n_valid_trials` | integer | Scored grammaticality-judgement trials before the response-time screen: Experiment-block rows with a canonical property and grammaticality and a 0/1 correctness value, pooled over the three properties and Sessions 2, 3, 4 and 6. The file holds one row. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_kept` | integer | Trials whose response time lies strictly between rt_min_ms and rt_max_ms. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_rt_excluded` | integer | n_valid_trials minus n_kept. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `pct_rt_excluded` | numeric | 100 * n_rt_excluded / n_valid_trials. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `rt_min_ms` | integer | Lower response-time bound in milliseconds (200); a trial must exceed it to be kept. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `rt_max_ms` | integer | Upper response-time bound in milliseconds (4000); a trial must fall below it to be kept. | paper_1_transfer/scripts/02_extract_accuracy.R |

## `_accuracy_sentence_inventory.csv`

4 data row(s), 4 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `session` | integer | ERP session (2, 3, 4 or 6). One row per session. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_trials` | integer | Scored judgement trials in that session after the response-time screen and de-duplication, pooled over the three properties; these are the trials that reach the accuracy models. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_participants` | integer | Distinct participants contributing those trials. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_distinct_sentences` | integer | Distinct sentence strings logged among those trials; NA when the logfiles carry no sentence column. | paper_1_transfer/scripts/02_extract_accuracy.R |

## `_electrode_coordinates.csv`

30 data row(s), 9 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `electrode` | character | 10-20 electrode label. One row per scalp electrode in the study's region map (30 electrodes). | paper_1_transfer/scripts/07c_extract_electrode_coordinates.R |
| `brain_region` | character | Electrode cluster used by the importer and the ERP models: left, midline or right crossed with anterior, medial or posterior. | paper_1_transfer/scripts/07c_extract_electrode_coordinates.R |
| `macroregion` | character | 'lateral' (the left and right clusters) or 'midline'. | paper_1_transfer/scripts/07c_extract_electrode_coordinates.R |
| `hemisphere` | character | 'left', 'right' or 'midline'. | paper_1_transfer/scripts/07c_extract_electrode_coordinates.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07c_extract_electrode_coordinates.R |
| `theta` | integer | BrainVision polar angle from the vertex in degrees, read from the recording headers; Cz is 0 and the equator is 90; the sign distinguishes the hemispheres. | paper_1_transfer/scripts/07c_extract_electrode_coordinates.R |
| `phi` | integer | BrainVision azimuth in degrees, read from the recording headers. | paper_1_transfer/scripts/07c_extract_electrode_coordinates.R |
| `x` | numeric | Planar projection of the sensor: radius \|theta\| / 90 at azimuth phi (theta >= 0) or 180 + phi (theta < 0). Positive is right; the unit circle is the equator. | paper_1_transfer/scripts/07c_extract_electrode_coordinates.R |
| `y` | numeric | Planar projection of the sensor; positive is anterior. | paper_1_transfer/scripts/07c_extract_electrode_coordinates.R |

## `_electrode_grand_average_differential_object_marking_lateral.csv`

26400 data row(s), 10 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per grammaticality x electrode x sample. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `time` | integer | Sample time in milliseconds from critical-word onset, -100 to 1098 in 2 ms steps. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_amp` | numeric | Mean amplitude in microvolts over every retained trial of every participant at that electrode and sample, as exported. Computed on the full sample, so the four mis-filtered Session-3 datasets are included. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_obs` | integer | Number of single-trial observations averaged. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_grand_average_differential_object_marking_midline.csv`

9600 data row(s), 10 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per grammaticality x electrode x sample. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `time` | integer | Sample time in milliseconds from critical-word onset, -100 to 1098 in 2 ms steps. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_amp` | numeric | Mean amplitude in microvolts over every retained trial of every participant at that electrode and sample, as exported. Computed on the full sample, so the four mis-filtered Session-3 datasets are included. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_obs` | integer | Number of single-trial observations averaged. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_grand_average_gender_agreement_lateral.csv`

26400 data row(s), 10 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per grammaticality x electrode x sample. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `time` | integer | Sample time in milliseconds from critical-word onset, -100 to 1098 in 2 ms steps. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_amp` | numeric | Mean amplitude in microvolts over every retained trial of every participant at that electrode and sample, as exported. Computed on the full sample, so the four mis-filtered Session-3 datasets are included. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_obs` | integer | Number of single-trial observations averaged. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_grand_average_gender_agreement_midline.csv`

9600 data row(s), 10 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per grammaticality x electrode x sample. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `time` | integer | Sample time in milliseconds from critical-word onset, -100 to 1098 in 2 ms steps. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_amp` | numeric | Mean amplitude in microvolts over every retained trial of every participant at that electrode and sample, as exported. Computed on the full sample, so the four mis-filtered Session-3 datasets are included. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_obs` | integer | Number of single-trial observations averaged. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_grand_average_verb_object_number_agreement_lateral.csv`

26400 data row(s), 10 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per grammaticality x electrode x sample. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `time` | integer | Sample time in milliseconds from critical-word onset, -100 to 1098 in 2 ms steps. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_amp` | numeric | Mean amplitude in microvolts over every retained trial of every participant at that electrode and sample, as exported. Computed on the full sample, so the four mis-filtered Session-3 datasets are included. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_obs` | integer | Number of single-trial observations averaged. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_grand_average_verb_object_number_agreement_midline.csv`

9600 data row(s), 10 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per grammaticality x electrode x sample. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `time` | integer | Sample time in milliseconds from critical-word onset, -100 to 1098 in 2 ms steps. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_amp` | numeric | Mean amplitude in microvolts over every retained trial of every participant at that electrode and sample, as exported. Computed on the full sample, so the four mis-filtered Session-3 datasets are included. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_obs` | integer | Number of single-trial observations averaged. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_erp_trial_retention.csv`

38 data row(s), 10 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `scope` | character | 'per_condition_canonical' (one modelled Grammatical or Ungrammatical cell), 'canonical' (every Grammatical and Ungrammatical cell pooled) or 'overall' (every grammaticality category pooled, ancillary violations included). One row per per-condition cell plus the two pooled rows. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `grammatical_property` | character | snake_case property key; 'ALL' on the pooled rows. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `session` | integer | ERP session (2, 3, 4 or 6); NA on the pooled rows. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `mini_language` | character | 'Mini-English', 'Mini-Norwegian' or 'ALL' on the pooled rows. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `grammaticality` | character | 'Grammatical', 'Ungrammatical', 'Grammatical+Ungrammatical' (the canonical pooled row) or 'ALL' (the overall pooled row). | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `mean_retained` | numeric | Mean number of EEG trials retained after artefact rejection per participant x session x property x grammaticality cell, every cell weighted equally; rounded to 3 decimals. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `sd_retained` | numeric | Standard deviation of that count across cells. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `n_cells` | integer | Number of participant-level cells summarised. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `presented_per_cell` | integer | Trials presented per cell by design (48). | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `pct_discarded` | numeric | 100 * (presented_per_cell - mean_retained) / presented_per_cell. | paper_1_transfer/scripts/00c_extract_erp_retention.R |

## `_first_session_language_advantage.csv`

3 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `model` | character | Accuracy model id, 'accuracy_<property>'. One row per model. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `contrast` | character | 'gram_x_language_at_first_session': the grammaticality x mini-language coefficient evaluated at the property's earliest measured session, b_gram:lang + z_first * b_gram:session:lang, where z_first is the standardised code of that session. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `median` | numeric | Posterior median of the contrast on the logit scale. Mini-language is coded Mini-Norwegian = +0.5 and Mini-English = -0.5 before standardisation, so a positive value is a larger grammaticality effect in the Mini-Norwegian group. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_low` | numeric | 2.5th percentile of the posterior (lower bound of the equal-tailed 95% credible interval). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_high` | numeric | 97.5th percentile of the posterior (upper bound of the equal-tailed 95% credible interval). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `pd` | numeric | Probability of direction: the larger of the posterior mass above zero and below zero. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |

## `_flow_inconsistencies.csv`

5 data row(s), 4 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `check` | character | Name of the consistency check that fired: 'data_without_attendance:<stage>', 'non_monotonic_attendance', 'language_parity_mismatch', 'duplicate_lab_ID', 'duplicate_home_ID', 'missing_lab_ID', 'enrolled_no_attendance', 'erp_without_accuracy', 'accuracy_without_erp', 'incomplete_predictor_set' or 'flow_total_mismatch'. One row per detected inconsistency. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `severity` | character | 'error', 'warning' or 'info'. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `participant_lab_ID` | integer | Lab ID of the participant concerned; NA for 'flow_total_mismatch', which is a property of a stage. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `detail` | character | Free-text statement of the inconsistency. | paper_1_transfer/scripts/00b_audit_participant_flow.R |

## `_grand_average_differential_object_marking_lateral.csv`

7200 data row(s), 9 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per grammaticality x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled: left, midline or right crossed with anterior, medial or posterior. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds from critical-word onset, -100 to 1098 in 2 ms steps. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_amp` | numeric | Mean amplitude in microvolts over the electrodes of the cluster, every retained trial and every participant at that sample, as exported. Computed on the full sample, so the four mis-filtered Session-3 datasets are included. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_obs` | integer | Number of electrode-by-trial observations averaged. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_grand_average_differential_object_marking_midline.csv`

3600 data row(s), 9 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per grammaticality x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled: left, midline or right crossed with anterior, medial or posterior. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds from critical-word onset, -100 to 1098 in 2 ms steps. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_amp` | numeric | Mean amplitude in microvolts over the electrodes of the cluster, every retained trial and every participant at that sample, as exported. Computed on the full sample, so the four mis-filtered Session-3 datasets are included. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_obs` | integer | Number of electrode-by-trial observations averaged. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_grand_average_gender_agreement_lateral.csv`

7200 data row(s), 9 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per grammaticality x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled: left, midline or right crossed with anterior, medial or posterior. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds from critical-word onset, -100 to 1098 in 2 ms steps. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_amp` | numeric | Mean amplitude in microvolts over the electrodes of the cluster, every retained trial and every participant at that sample, as exported. Computed on the full sample, so the four mis-filtered Session-3 datasets are included. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_obs` | integer | Number of electrode-by-trial observations averaged. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_grand_average_gender_agreement_midline.csv`

3600 data row(s), 9 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per grammaticality x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled: left, midline or right crossed with anterior, medial or posterior. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds from critical-word onset, -100 to 1098 in 2 ms steps. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_amp` | numeric | Mean amplitude in microvolts over the electrodes of the cluster, every retained trial and every participant at that sample, as exported. Computed on the full sample, so the four mis-filtered Session-3 datasets are included. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_obs` | integer | Number of electrode-by-trial observations averaged. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_grand_average_verb_object_number_agreement_lateral.csv`

7200 data row(s), 9 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per grammaticality x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled: left, midline or right crossed with anterior, medial or posterior. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds from critical-word onset, -100 to 1098 in 2 ms steps. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_amp` | numeric | Mean amplitude in microvolts over the electrodes of the cluster, every retained trial and every participant at that sample, as exported. Computed on the full sample, so the four mis-filtered Session-3 datasets are included. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_obs` | integer | Number of electrode-by-trial observations averaged. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_grand_average_verb_object_number_agreement_midline.csv`

3600 data row(s), 9 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per grammaticality x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled: left, midline or right crossed with anterior, medial or posterior. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds from critical-word onset, -100 to 1098 in 2 ms steps. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_amp` | numeric | Mean amplitude in microvolts over the electrodes of the cluster, every retained trial and every participant at that sample, as exported. Computed on the full sample, so the four mis-filtered Session-3 datasets are included. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_obs` | integer | Number of electrode-by-trial observations averaged. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_literature_trend.csv`

63 data row(s), 4 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `stratum` | character | Literature subset counted: 'All L3-transfer research', 'Acceptability/grammaticality judgement' or 'Electrophysiology (ERP/EEG)'. One row per stratum x publication year. | paper_1_transfer/scripts/10_extract_literature_trend.R |
| `year` | integer | Publication year, 2005 to 2025. | paper_1_transfer/scripts/10_extract_literature_trend.R |
| `n` | integer | Number of Scopus documents matching the query. | paper_1_transfer/scripts/10_extract_literature_trend.R |
| `query` | character | The exact Scopus Search API query string, every term scoped to TITLE-ABS-KEY. | paper_1_transfer/scripts/10_extract_literature_trend.R |

## `_misfiltered_share.csv`

2 data row(s), 7 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | snake_case key of a property recorded at the session of the mis-filtered datasets. One row per such property. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `session` | integer | Session of the mis-filtered recordings (3). | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `n_datasets_misfiltered` | integer | Number of the mis-filtered participant-sessions (LES_P1_MISFILTERED in scripts/_config.R) with retained Grammatical or Ungrammatical trials of that property. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `n_datasets_all` | integer | Participants with retained Grammatical or Ungrammatical trials of that property at that session. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `n_trials_misfiltered` | integer | Retained Grammatical and Ungrammatical trials contributed by the mis-filtered datasets. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `n_trials_all` | integer | Retained Grammatical and Ungrammatical trials from every dataset at that session. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `share_pct` | numeric | 100 * n_trials_misfiltered / n_trials_all, rounded to 3 decimals. | paper_1_transfer/scripts/00c_extract_erp_retention.R |

## `_participant_matrix.csv`

65 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `participant_lab_ID` | integer | Integer lab ID from the participant key. One row per participant in the key. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `participant_home_ID` | character | Home (online-battery) ID string from the participant key. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `language_recorded` | character | Mini-language recorded in the participant key: 'Mini-English' or 'Mini-Norwegian'. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `attended_S1` | logical | TRUE when the Session-1 date cell in the participant key is filled. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `attended_S2` | logical | TRUE when the Session-2 date cell in the participant key is filled. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `attended_S3` | logical | TRUE when the Session-3 date cell in the participant key is filled. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `attended_S4` | logical | TRUE when the Session-4 date cell in the participant key is filled. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `attended_S5` | logical | TRUE when the Session-5 date cell in the participant key is filled. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `attended_S6` | logical | TRUE when the Session-6 date cell in the participant key is filled. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `usable_accuracy` | logical | TRUE when the participant appears in any accuracy_<property>.rds (Paper 1 judgement data). | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `usable_erp` | logical | TRUE when the participant appears in EEG_trial_count_per_condition.csv, in any grammaticality category. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `battery_baseline` | logical | TRUE when at least one Session-1 cognitive index is present. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `trajectory` | logical | TRUE when the participant appears in learning_trajectory.rds. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `joint_predictor` | logical | TRUE when both battery_baseline and trajectory hold. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `usable_rseeg` | logical | TRUE when joint_predictor holds and the eyes-closed resting-state record carries every band power and the IAF. | paper_1_transfer/scripts/00b_audit_participant_flow.R |

## `_participants.csv`

18 data row(s), 7 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `metric` | character | Name of the demographic quantity: n_enrolled, n_mini_english, n_mini_norwegian, n_lhq3, age_years, sex_female, sex_male, sex_nonbinary, sex_undisclosed, hand_right, hand_left, hand_reported_n, eng_aoa_listen, eng_aoa_4mod, eng_years, eng_l2_proficiency, multilingual_diversity, n_other_language. One row per metric, computed over the analysed participants with an LHQ3 record unless the note says otherwise. | paper_1_transfer/scripts/00_extract_participants.R |
| `value` | numeric | A count for the n_*, sex_* and hand_* rows; the mean over participants with a value for the continuous rows (years for age_years, eng_aoa_listen, eng_aoa_4mod and eng_years; a 0 to 1 self-rating for eng_l2_proficiency; the LHQ3 score for multilingual_diversity). | paper_1_transfer/scripts/00_extract_participants.R |
| `sd` | numeric | Standard deviation across participants for the continuous rows; NA for counts. | paper_1_transfer/scripts/00_extract_participants.R |
| `n` | integer | Denominator: participants with a value (continuous rows) or the reference count of a count row (n_lhq3 for the sex rows, participants with a handedness response for the hand rows); NA where no denominator is stated. | paper_1_transfer/scripts/00_extract_participants.R |
| `vmin` | numeric | Minimum across participants for the continuous rows; NA for counts. | paper_1_transfer/scripts/00_extract_participants.R |
| `vmax` | numeric | Maximum across participants for the continuous rows; NA for counts. | paper_1_transfer/scripts/00_extract_participants.R |
| `note` | character | Source and definition of the metric. | paper_1_transfer/scripts/00_extract_participants.R |

## `_participants_other_languages.csv`

8 data row(s), 2 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `language` | character | A language named in LHQ3 item 7 beyond Norwegian and English, with any parenthetical qualifier dropped and in title case. One row per language, ordered by n_participants. | paper_1_transfer/scripts/00_extract_participants.R |
| `n_participants` | integer | Distinct analysed participants naming that language. | paper_1_transfer/scripts/00_extract_participants.R |

## `_pooled_convergence.csv`

102 data row(s), 9 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `model` | character | Model id taken from the artefact file name: 'erp_<property>_<window>_<macroregion>' for the 18 ERP cells and 'accuracy_<property>' for the judgement models, with the suffix tags '_weakprior' (weakly informative priors), '_itemslope' (maximal by-item structure) and '_retfree' (explicit Session-6 offset) where fitted. One row per fitted model. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `max_rhat` | numeric | Largest rank-normalised split R-hat over every parameter of the fit. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `min_ess_bulk` | numeric | Smallest bulk effective sample size over every parameter of the fit. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `min_ess_tail` | numeric | Smallest tail effective sample size over every parameter of the fit. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `n_divergent` | integer | Divergent transitions after warm-up, summed over chains. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `n_treedepth` | logical | Iterations that saturated max_treedepth; NA under the cmdstanr backend, where the ceiling cannot be read from the fit object. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `passed` | logical | TRUE when max_rhat < 1.01, min_ess_bulk > 400, min_ess_tail > 400 and n_divergent == 0. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `structure` | character | Random-effect structure read from the file name: 'maximal' when the by-item term carries a grammaticality slope (the '_itemslope' tag), otherwise 'base'. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `prior_variant` | character | 'weak' for a '_weakprior' fit, otherwise 'informative'. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |

## `_pooled_fit_metadata.csv`

102 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `model` | character | Model id recorded at fit time: the ERP cell id or 'accuracy_<property>', carrying the '_keepmisfiltered' or '_diversity' data-variant tag when one was set, but not the prior or structure tag. One row per fitted model. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `n_obs` | integer | Rows of the data frame passed to brms after listwise deletion: single trials for an ERP cell, judgement trials for an accuracy model. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `n_participants` | integer | Distinct participants in that data frame. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `exclusion_applicable` | logical | TRUE for ERP fits, where the 1 Hz mis-filter exclusion bears on the data; FALSE for accuracy fits, whose behavioural judgements are unaffected by the EEG filter. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `misfiltered_rows` | integer | Rows of the fitted data belonging to the four mis-filtered Session-3 datasets; NA when the exclusion is not applicable. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `exclusion_applied` | logical | TRUE when the exclusion is not applicable or misfiltered_rows is 0. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `keep_misfiltered` | logical | Whether LES_P1_KEEP_MISFILTERED=1 was set for the fit. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `prior_set` | character | Value of LES_PRIOR_SET at fit time: 'informative' (the default) or 'weak'. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `structure` | character | 'base' or 'maximal', recomputed from the artefact file name when the records are pooled. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `r_version` | character | R version loaded by the fitting process. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `brms_version` | character | brms version loaded by the fitting process. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `cmdstanr_version` | character | cmdstanr version loaded by the fitting process. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `cmdstan_version` | character | CmdStan version used by the fitting process. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `fitted_utc` | character | UTC timestamp at which the fit record was written. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `prior_variant` | character | 'weak' or 'informative', recomputed from the artefact file name when the records are pooled. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |

## `_pooled_posterior_summaries.csv`

1392 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `parameter` | character | brms population-level term with the 'b_' prefix removed, for example 'Intercept' or 'z_recoded_grammaticality:z_recoded_session'. The recoded predictors are sum-coded contrasts standardised within the modelled cell: grammaticality Grammatical = +0.5 and Ungrammatical = -0.5; mini-language Mini-Norwegian = +0.5 and Mini-English = -0.5; session 0, 1, 2, 3 for Sessions 2, 3, 4, 6; hemisphere and caudality likewise. z_baseline_predictor is the trial's own standardised pre-stimulus mean, z_multilingual_language_diversity the standardised LHQ3 covariate, and z_retention is +0.5 at the last sampled session and -0.5 elsewhere. One row per parameter per model. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `median` | numeric | Posterior median. ERP models: change in within-participant standardised amplitude (SD units) per unit of the standardised predictor. Accuracy models: change on the logit scale. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_low` | numeric | 2.5th percentile of the posterior (lower bound of the equal-tailed 95% credible interval). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_high` | numeric | 97.5th percentile of the posterior (upper bound of the equal-tailed 95% credible interval). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `pd` | numeric | Probability of direction: the larger of the posterior mass above zero and below zero. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `model` | character | Model id from the artefact file name, with the '_weakprior', '_itemslope' and '_retfree' tags where fitted. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |

## `_prior_sensitivity.csv`

492 data row(s), 14 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `parameter` | character | brms population-level term with the 'b_' prefix removed (see _pooled_posterior_summaries.csv). One row per parameter per informative/weak model pair, ordered by absolute median_shift within a pair. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `median_inf` | numeric | Posterior median under the informative priors. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_low_inf` | numeric | 2.5th percentile of the posterior under the informative priors. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_high_inf` | numeric | 97.5th percentile of the posterior under the informative priors. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `pd_inf` | numeric | Probability of direction under the informative priors. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `median_weak` | numeric | Posterior median under the weakly informative priors (the '_weakprior' fit on the same data). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_low_weak` | numeric | 2.5th percentile of the posterior under the weakly informative priors. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_high_weak` | numeric | 97.5th percentile of the posterior under the weakly informative priors. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `pd_weak` | numeric | Probability of direction under the weakly informative priors. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `median_shift` | numeric | median_inf minus median_weak, in the model's response units (SD units for ERP cells, logit for accuracy models). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_width_inf` | numeric | ci_high_inf minus ci_low_inf. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_width_weak` | numeric | ci_high_weak minus ci_low_weak. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `model` | character | Id of the informative fit: the cell or accuracy id, with '_itemslope' for the maximal structure. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `structure` | character | 'base' or 'maximal'. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |

## `_provenance.csv`

16 data row(s), 3 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `component` | character | What the row records: 'R', 'platform', an R package name (brms, cmdstanr, rstan, StanHeaders, posterior, loo, projpred, bayesplot, mgcv, MASS, dplyr), 'CmdStan', or 'seed:<name>' for a seed constant in force. One row per component. | _shared/R/04_provenance.R (called by paper_1_transfer/scripts/03_fit_brms_erp.R) |
| `version` | character | Version string as loaded by the run that fitted the ERP models, or the seed value. | _shared/R/04_provenance.R (called by paper_1_transfer/scripts/03_fit_brms_erp.R) |
| `recorded_utc` | character | UTC time of the write; the same on every row. | _shared/R/04_provenance.R (called by paper_1_transfer/scripts/03_fit_brms_erp.R) |

## `_retention_contrasts.csv`

396 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `model` | character | Fitted model id with its tags. One row per model x contrast. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `contrast` | character | 'overall' (at the standardised language mean), 'within_Mini-Norwegian', 'within_Mini-English' or 'language_difference' (Mini-Norwegian minus Mini-English). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `median` | numeric | Posterior median of the change in the grammaticality effect from Session 4 to Session 6. For the default fits it is (z6 - z4) * (b_gram:session + b_gram:session:lang * l), the fitted linear trend evaluated over the retention step; for '_retfree' fits it is the z_retention offset. Units follow the model: SD units for ERP cells, logit for accuracy models. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_low` | numeric | 2.5th percentile of the posterior (lower bound of the equal-tailed 95% credible interval). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_high` | numeric | 97.5th percentile of the posterior (upper bound of the equal-tailed 95% credible interval). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `pd` | numeric | Probability of direction: the larger of the posterior mass above zero and below zero. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |

## `_rsvp_timing.csv`

1 data row(s), 22 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `n_trials` | integer | Critical-word trials entering the census, over every OpenSesame logfile of Sessions 2, 3, 4 and 6, before any EEG-side exclusion and without de-duplication. One row per file, so this is the whole census. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `next_onset_min_ms` | integer | Minimum onset latency, in milliseconds, of the first word displayed after the critical word, relative to critical-word onset. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `next_onset_max_ms` | integer | Maximum of that same latency. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `next_onset_median_ms` | integer | Median of that same latency. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `max_onsets_within_900ms` | integer | Largest number of subsequent word onsets that any trial shows within the counting window; the manuscript's claim is that it is one. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `min_onsets_within_900ms` | integer | Smallest such number, over the same trials. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `n_trials_exactly_one_onset_within_900ms` | integer | Trials showing exactly one subsequent onset in the window. Equal to n_trials when every trial does. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `second_onset_min_ms` | integer | Minimum onset latency of the SECOND subsequent word, which is what places that word beyond the late analysis window. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `n_trials_s2` | integer | Critical-word trials contributed by Session 2. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `n_trials_s3` | integer | Critical-word trials contributed by Session 3. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `n_trials_s4` | integer | Critical-word trials contributed by Session 4. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `n_trials_s6` | integer | Critical-word trials contributed by Session 6, the retention test. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `n_duplicate_rows` | integer | Counted trials that are byte-identical repeats of another row. A minority of logfiles close by rewriting their final trial verbatim. They are counted rather than removed, because the census counts logged presentations. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `n_files_read` | integer | Logfiles read, that is, the files found less those skipped. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `n_files_skipped` | integer | Logfiles found but not read, because they could not be parsed or lacked the required columns. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `n_rows_excluded_missing_onset` | integer | Rows dropped because the critical word carried no logged onset timestamp. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `n_rows_excluded_missing_duration` | integer | Rows dropped because the critical word carried no nominal display duration. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `n_rows_excluded_no_following_word` | integer | Rows dropped because no word followed the critical word in the trial, so no subsequent onset exists to measure. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `n_rows_excluded_soa_out_of_range` | integer | Rows dropped because the recovered stimulus-onset asynchrony fell outside the plausible range, which would indicate a logging fault rather than a presentation timing. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `source_dir` | character | The read-only input directory, relative to the project root, that the census was computed from. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `window_rule` | character | The rule by which a subsequent onset was counted, written out so that the census can be reproduced without reading the script. Its 900 ms comes from LES_P1_RSVP_WINDOW_MS. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |
| `generated_utc` | character | When the census was written, in UTC. | paper_1_transfer/scripts/01b_extract_rsvp_timing.R |

## `_sample_flow.csv`

13 data row(s), 7 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `stage` | character | Participant-flow stage key: 'enrolled', 'attended_S1' to 'attended_S6', 'usable_accuracy', 'battery_baseline', 'trajectory', 'joint_predictor', 'usable_erp' or 'usable_rseeg'. One row per stage. | paper_1_transfer/scripts/00_extract_participants.R |
| `order` | integer | Display order of the stage in the flow figure. | paper_1_transfer/scripts/00_extract_participants.R |
| `label` | character | Stage label printed in the flow figure. | paper_1_transfer/scripts/00_extract_participants.R |
| `n_total` | integer | Participants at that stage; NA when the source object is absent. | paper_1_transfer/scripts/00_extract_participants.R |
| `n_mini_english` | integer | Participants at that stage assigned Mini-English; NA where the stage is not split by language. | paper_1_transfer/scripts/00_extract_participants.R |
| `n_mini_norwegian` | integer | Participants at that stage assigned Mini-Norwegian; NA where the stage is not split by language. | paper_1_transfer/scripts/00_extract_participants.R |
| `source` | character | The file or rule the count derives from. | paper_1_transfer/scripts/00_extract_participants.R |

## `_training_gate_flow.csv`

4 data row(s), 7 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `session` | integer | ERP session (2, 3, 4 or 6). One row per session. | paper_1_transfer/scripts/00d_extract_training_gate_flow.R |
| `grammatical_property` | character | Always 'ALL': the comprehension gate was applied per session and cannot be resolved per property. | paper_1_transfer/scripts/00d_extract_training_gate_flow.R |
| `n_attempted` | integer | Subjects with an interpretable gate outcome (n_passed_attempt1 + n_passed_attempt2 + n_failed_gate). At Session 6, which had no gate, subjects with scored judgements. | paper_1_transfer/scripts/00d_extract_training_gate_flow.R |
| `n_passed_attempt1` | integer | Subjects who passed the >80% post-training comprehension test on the first attempt. | paper_1_transfer/scripts/00d_extract_training_gate_flow.R |
| `n_passed_attempt2` | integer | Subjects who failed the first attempt and passed the second. | paper_1_transfer/scripts/00d_extract_training_gate_flow.R |
| `n_failed_gate` | integer | Subjects who failed both attempts. | paper_1_transfer/scripts/00d_extract_training_gate_flow.R |
| `note` | character | Session-specific statement of how the counts were reconstructed and what they exclude. | paper_1_transfer/scripts/00d_extract_training_gate_flow.R |

## `differential_object_marking_decoding_generalization.csv`

600 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `property` | character | snake_case key of the property decoded; the file name carries the same value. One row per train/test direction per time bin. | paper_1_transfer/scripts/09_run_decoding.R |
| `generalization` | character | 'cross_language'. | paper_1_transfer/scripts/09_run_decoding.R |
| `train_set` | character | Mini-language whose trials trained the decoder. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_set` | character | Mini-language whose trials were scored; its participants are disjoint from the training participants. | paper_1_transfer/scripts/09_run_decoding.R |
| `time_ms` | integer | Nominal centre of the time bin in milliseconds from critical-word onset. | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | AUC of a decoder trained on every train_set trial (class-balanced within participant) and scored on every test_set trial at that bin; NA when either set lacks both classes. | paper_1_transfer/scripts/09_run_decoding.R |

## `differential_object_marking_decoding_generalization_crossproperty.csv`

600 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `property` | character | snake_case key of the property the decoder was trained on; the file name carries the same value. One row per test property per time bin. | paper_1_transfer/scripts/09_run_decoding.R |
| `generalization` | character | 'cross_property'. | paper_1_transfer/scripts/09_run_decoding.R |
| `train_set` | character | Property whose trials trained the decoder. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_set` | character | Property whose trials were scored. | paper_1_transfer/scripts/09_run_decoding.R |
| `time_ms` | integer | Nominal centre of the bin on the time axis common to the two properties' tensors, in milliseconds from critical-word onset. | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | AUC of a decoder trained on every trial of train_set and scored on every trial of test_set at that bin. The same participants contribute to both sets, so the value is descriptive only. | paper_1_transfer/scripts/09_run_decoding.R |

## `differential_object_marking_decoding_temporal_generalization.csv`

22500 data row(s), 5 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `train_time_ms` | integer | Bin at which the decoder was trained, in milliseconds from critical-word onset, on a grid coarsened to every second bin (8 ms by default). One row per train x test bin pair. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_time_ms` | integer | Bin at which the decoder was scored, on the same coarsened grid. | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | Mean AUC over leave-one-participant-out folds of a decoder trained at train_time_ms and scored at test_time_ms; NA where no fold was scorable. | paper_1_transfer/scripts/09_run_decoding.R |
| `n_folds` | integer | Number of held-out participants contributing to the mean. | paper_1_transfer/scripts/09_run_decoding.R |
| `property` | character | snake_case property key; the file name carries the same value. | paper_1_transfer/scripts/09_run_decoding.R |

## `differential_object_marking_decoding_timecourse.csv`

3000 data row(s), 20 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `time_ms` | integer | Nominal centre of the decoding time bin in milliseconds from critical-word onset; 4 ms bins over the -100 to 1098 ms epoch by default. One row per bin per analysis block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `auc` | numeric | Observed area under the ROC curve for Grammatical against Ungrammatical at that bin, averaged over leave-one-participant-out folds; Ungrammatical is the positive class and 0.5 is chance. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_mean` | numeric | Mean AUC over the within-participant label permutations at that bin. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_q975` | numeric | 97.5th percentile of that bin's permutation null; descriptive only, not the cluster-forming threshold. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `p_pointwise` | numeric | Exact permutation p-value for the bin, (b + 1) / (m + 1), with b the permutations at or above the observed AUC and m the permutation count. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `cluster_id` | integer | Index of the contiguous supra-threshold cluster the bin belongs to, restarting at 1 in every block; NA outside clusters. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `cluster_p` | numeric | Cluster-level p-value of that cluster against the maximum-cluster-mass permutation null, repeated on every bin of the cluster; NA outside clusters. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `significant` | logical | TRUE when cluster_p < 0.05; the family-wise error rate is controlled over time within the block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `cluster_threshold` | numeric | Cluster-forming threshold for the block: the 95th percentile of the pooled permutation null AUC. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `n_perm` | integer | Number of label permutations the block was computed with. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `n_trials` | integer | Trials entering the block after dropping trials with any incomplete channel-time pattern. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `n_participants` | integer | Distinct participants in the block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `property` | character | snake_case property key; the file name carries the same value. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `analysis` | character | 'overall' (every session pooled), 'by_session' or 'by_session_language'. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `level` | character | Block label: 'all', 'session_<s>' or 'session_<s>_<mini-language>'. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `session` | logical | Session of the block; NA for the overall block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `mini_language` | logical | Mini-language of the block; NA unless analysis is 'by_session_language'. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `cluster_p_fdr` | numeric | Benjamini-Hochberg adjusted cluster_p across the confirmatory clusters, which are those of the overall block; NA on exploratory rows and outside clusters. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `significant_fdr` | logical | TRUE when cluster_p_fdr < 0.05. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `inference` | character | 'confirmatory' for the overall block, 'exploratory' for the session-resolved breakdowns. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |

## `gender_agreement_decoding_generalization.csv`

600 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `property` | character | snake_case key of the property decoded; the file name carries the same value. One row per train/test direction per time bin. | paper_1_transfer/scripts/09_run_decoding.R |
| `generalization` | character | 'cross_language'. | paper_1_transfer/scripts/09_run_decoding.R |
| `train_set` | character | Mini-language whose trials trained the decoder. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_set` | character | Mini-language whose trials were scored; its participants are disjoint from the training participants. | paper_1_transfer/scripts/09_run_decoding.R |
| `time_ms` | integer | Nominal centre of the time bin in milliseconds from critical-word onset. | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | AUC of a decoder trained on every train_set trial (class-balanced within participant) and scored on every test_set trial at that bin; NA when either set lacks both classes. | paper_1_transfer/scripts/09_run_decoding.R |

## `gender_agreement_decoding_generalization_crossproperty.csv`

600 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `property` | character | snake_case key of the property the decoder was trained on; the file name carries the same value. One row per test property per time bin. | paper_1_transfer/scripts/09_run_decoding.R |
| `generalization` | character | 'cross_property'. | paper_1_transfer/scripts/09_run_decoding.R |
| `train_set` | character | Property whose trials trained the decoder. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_set` | character | Property whose trials were scored. | paper_1_transfer/scripts/09_run_decoding.R |
| `time_ms` | integer | Nominal centre of the bin on the time axis common to the two properties' tensors, in milliseconds from critical-word onset. | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | AUC of a decoder trained on every trial of train_set and scored on every trial of test_set at that bin. The same participants contribute to both sets, so the value is descriptive only. | paper_1_transfer/scripts/09_run_decoding.R |

## `gender_agreement_decoding_temporal_generalization.csv`

22500 data row(s), 5 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `train_time_ms` | integer | Bin at which the decoder was trained, in milliseconds from critical-word onset, on a grid coarsened to every second bin (8 ms by default). One row per train x test bin pair. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_time_ms` | integer | Bin at which the decoder was scored, on the same coarsened grid. | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | Mean AUC over leave-one-participant-out folds of a decoder trained at train_time_ms and scored at test_time_ms; NA where no fold was scorable. | paper_1_transfer/scripts/09_run_decoding.R |
| `n_folds` | integer | Number of held-out participants contributing to the mean. | paper_1_transfer/scripts/09_run_decoding.R |
| `property` | character | snake_case property key; the file name carries the same value. | paper_1_transfer/scripts/09_run_decoding.R |

## `gender_agreement_decoding_timecourse.csv`

3900 data row(s), 20 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `time_ms` | integer | Nominal centre of the decoding time bin in milliseconds from critical-word onset; 4 ms bins over the -100 to 1098 ms epoch by default. One row per bin per analysis block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `auc` | numeric | Observed area under the ROC curve for Grammatical against Ungrammatical at that bin, averaged over leave-one-participant-out folds; Ungrammatical is the positive class and 0.5 is chance. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_mean` | numeric | Mean AUC over the within-participant label permutations at that bin. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_q975` | numeric | 97.5th percentile of that bin's permutation null; descriptive only, not the cluster-forming threshold. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `p_pointwise` | numeric | Exact permutation p-value for the bin, (b + 1) / (m + 1), with b the permutations at or above the observed AUC and m the permutation count. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `cluster_id` | integer | Index of the contiguous supra-threshold cluster the bin belongs to, restarting at 1 in every block; NA outside clusters. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `cluster_p` | numeric | Cluster-level p-value of that cluster against the maximum-cluster-mass permutation null, repeated on every bin of the cluster; NA outside clusters. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `significant` | logical | TRUE when cluster_p < 0.05; the family-wise error rate is controlled over time within the block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `cluster_threshold` | numeric | Cluster-forming threshold for the block: the 95th percentile of the pooled permutation null AUC. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `n_perm` | integer | Number of label permutations the block was computed with. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `n_trials` | integer | Trials entering the block after dropping trials with any incomplete channel-time pattern. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `n_participants` | integer | Distinct participants in the block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `property` | character | snake_case property key; the file name carries the same value. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `analysis` | character | 'overall' (every session pooled), 'by_session' or 'by_session_language'. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `level` | character | Block label: 'all', 'session_<s>' or 'session_<s>_<mini-language>'. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `session` | logical | Session of the block; NA for the overall block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `mini_language` | logical | Mini-language of the block; NA unless analysis is 'by_session_language'. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `cluster_p_fdr` | numeric | Benjamini-Hochberg adjusted cluster_p across the confirmatory clusters, which are those of the overall block; NA on exploratory rows and outside clusters. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `significant_fdr` | logical | TRUE when cluster_p_fdr < 0.05. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `inference` | character | 'confirmatory' for the overall block, 'exploratory' for the session-resolved breakdowns. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |

## `verb_object_number_agreement_decoding_generalization.csv`

600 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `property` | character | snake_case key of the property decoded; the file name carries the same value. One row per train/test direction per time bin. | paper_1_transfer/scripts/09_run_decoding.R |
| `generalization` | character | 'cross_language'. | paper_1_transfer/scripts/09_run_decoding.R |
| `train_set` | character | Mini-language whose trials trained the decoder. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_set` | character | Mini-language whose trials were scored; its participants are disjoint from the training participants. | paper_1_transfer/scripts/09_run_decoding.R |
| `time_ms` | integer | Nominal centre of the time bin in milliseconds from critical-word onset. | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | AUC of a decoder trained on every train_set trial (class-balanced within participant) and scored on every test_set trial at that bin; NA when either set lacks both classes. | paper_1_transfer/scripts/09_run_decoding.R |

## `verb_object_number_agreement_decoding_generalization_crossproperty.csv`

600 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `property` | character | snake_case key of the property the decoder was trained on; the file name carries the same value. One row per test property per time bin. | paper_1_transfer/scripts/09_run_decoding.R |
| `generalization` | character | 'cross_property'. | paper_1_transfer/scripts/09_run_decoding.R |
| `train_set` | character | Property whose trials trained the decoder. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_set` | character | Property whose trials were scored. | paper_1_transfer/scripts/09_run_decoding.R |
| `time_ms` | integer | Nominal centre of the bin on the time axis common to the two properties' tensors, in milliseconds from critical-word onset. | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | AUC of a decoder trained on every trial of train_set and scored on every trial of test_set at that bin. The same participants contribute to both sets, so the value is descriptive only. | paper_1_transfer/scripts/09_run_decoding.R |

## `verb_object_number_agreement_decoding_temporal_generalization.csv`

22500 data row(s), 5 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `train_time_ms` | integer | Bin at which the decoder was trained, in milliseconds from critical-word onset, on a grid coarsened to every second bin (8 ms by default). One row per train x test bin pair. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_time_ms` | integer | Bin at which the decoder was scored, on the same coarsened grid. | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | Mean AUC over leave-one-participant-out folds of a decoder trained at train_time_ms and scored at test_time_ms; NA where no fold was scorable. | paper_1_transfer/scripts/09_run_decoding.R |
| `n_folds` | integer | Number of held-out participants contributing to the mean. | paper_1_transfer/scripts/09_run_decoding.R |
| `property` | character | snake_case property key; the file name carries the same value. | paper_1_transfer/scripts/09_run_decoding.R |

## `verb_object_number_agreement_decoding_timecourse.csv`

2100 data row(s), 20 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `time_ms` | integer | Nominal centre of the decoding time bin in milliseconds from critical-word onset; 4 ms bins over the -100 to 1098 ms epoch by default. One row per bin per analysis block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `auc` | numeric | Observed area under the ROC curve for Grammatical against Ungrammatical at that bin, averaged over leave-one-participant-out folds; Ungrammatical is the positive class and 0.5 is chance. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_mean` | numeric | Mean AUC over the within-participant label permutations at that bin. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_q975` | numeric | 97.5th percentile of that bin's permutation null; descriptive only, not the cluster-forming threshold. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `p_pointwise` | numeric | Exact permutation p-value for the bin, (b + 1) / (m + 1), with b the permutations at or above the observed AUC and m the permutation count. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `cluster_id` | integer | Index of the contiguous supra-threshold cluster the bin belongs to, restarting at 1 in every block; NA outside clusters. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `cluster_p` | numeric | Cluster-level p-value of that cluster against the maximum-cluster-mass permutation null, repeated on every bin of the cluster; NA outside clusters. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `significant` | logical | TRUE when cluster_p < 0.05; the family-wise error rate is controlled over time within the block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `cluster_threshold` | numeric | Cluster-forming threshold for the block: the 95th percentile of the pooled permutation null AUC. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `n_perm` | integer | Number of label permutations the block was computed with. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `n_trials` | integer | Trials entering the block after dropping trials with any incomplete channel-time pattern. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `n_participants` | integer | Distinct participants in the block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `property` | character | snake_case property key; the file name carries the same value. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `analysis` | character | 'overall' (every session pooled), 'by_session' or 'by_session_language'. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `level` | character | Block label: 'all', 'session_<s>' or 'session_<s>_<mini-language>'. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `session` | logical | Session of the block; NA for the overall block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `mini_language` | logical | Mini-language of the block; NA unless analysis is 'by_session_language'. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `cluster_p_fdr` | numeric | Benjamini-Hochberg adjusted cluster_p across the confirmatory clusters, which are those of the overall block; NA on exploratory rows and outside clusters. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `significant_fdr` | logical | TRUE when cluster_p_fdr < 0.05. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `inference` | character | 'confirmatory' for the overall block, 'exploratory' for the session-resolved breakdowns. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |

