# Codebook for `paper_1_transfer/results`

This file is machine-written by `_shared/R/write_codebook.R` and is not edited by hand. It lists every manuscript-facing CSV in this folder and, for each column, the R class that `read.csv()` infers from the first 200 rows (a column that is entirely NA within those rows reads as `logical`), a description taken from `_shared/R/codebook_descriptions.csv`, and the script that writes the file. To regenerate it after pulling the CSVs from the cluster, run `Rscript _shared/R/write_codebook.R` from the project root. Descriptions are added or corrected in `_shared/R/codebook_descriptions.csv`; a column still marked `(description pending)` needs one. The row counts are those of the files present when the codebook was generated.

## `_accuracy_by_language.csv`

36 data row(s), 11 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-Norwegian' or 'Mini-English'. One row per group x session x property x grammaticality. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `session` | integer | ERP/grammaticality-judgement session (2, 3, 4 or 6). | paper_1_transfer/scripts/02_extract_accuracy.R |
| `grammatical_property` | character | snake_case property key. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; ancillary violation conditions are excluded. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `mean_accuracy` | numeric | Arithmetic mean of participant-level accuracy proportions in the cell; each participant has equal weight regardless of retained-trial count. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `sd_accuracy` | numeric | Standard deviation of participant-level accuracy proportions in the cell. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_participants` | integer | Participants contributing at least one retained trial to the cell. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_trials` | integer | Retained, de-duplicated trials contributing across those participants. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `se_accuracy` | numeric | Standard error of mean_accuracy over participant-level proportions: sd_accuracy / sqrt(n_participants); NA when n_participants is one. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `ci_low` | numeric | Lower bound of a two-sided 95% t interval for mean_accuracy over participant proportions, truncated at zero. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `ci_high` | numeric | Upper bound of a two-sided 95% t interval for mean_accuracy over participant proportions, truncated at one. | paper_1_transfer/scripts/02_extract_accuracy.R |

## `_accuracy_input_gaps.csv`

7 data row(s), 4 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `reason` | character | Why the extraction cannot read the logfile: 'split_export' (the run is split across subject-N-test.csv and subject-N-experiment.csv, which the file pattern does not match) or 'semicolon_delimited' (the comma-delimited reader parses the export as a single column). One row per affected logfile. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `file` | character | Base name of the OpenSesame logfile. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `session` | integer | Session number parsed from the folder name (2, 3, 4 or 6). | paper_1_transfer/scripts/02_extract_accuracy.R |
| `participant_lab_ID` | integer | Integer lab ID parsed from the file name. | paper_1_transfer/scripts/02_extract_accuracy.R |

## `_accuracy_item_inventory.csv`

3 data row(s), 11 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | Property, as in the manifest (gender_agreement, differential_object_marking, verb_object_number_agreement). One row per property. An item is a sentence frame within one miniature language (item_id = language x sentence trigger), the item factor the ERP models carry. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_trials` | integer | Modelled judgement trials of the property (after the de-duplication, the reaction-time screen and the exclusions). | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_trials_without_item` | integer | Of those, trials whose log carries no sentence trigger, so that no item can be assigned. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_items` | integer | Distinct items among the property's trials. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `share_items_both_grammaticality` | integer | Proportion (0-1) of the items judged under both grammaticality levels. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `participants_per_item_min` | integer | Fewest distinct participants who judged any one item. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `participants_per_item_median` | integer | Median over items of the distinct participants who judged the item. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `participants_per_item_max` | integer | Most distinct participants who judged any one item. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `trials_per_item_min` | integer | Fewest trials on any one item. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `trials_per_item_median` | numeric | Median over items of the trials on the item. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `trials_per_item_max` | integer | Most trials on any one item. | paper_1_transfer/scripts/02_extract_accuracy.R |

## `_accuracy_language_check.csv`

207 data row(s), 7 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `participant_lab_ID` | integer | Lab participant ID. One row per participant x session with scored judgement trials, including participants excluded for a protocol deviation. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `session` | integer | Laboratory session (2, 3, 4 or 6). | paper_1_transfer/scripts/02_extract_accuracy.R |
| `mini_language` | character | Group assigned by lab-ID parity: 'Mini-Norwegian' or 'Mini-English'. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `logged_language` | character | Language value(s) the OpenSesame log records for that session, '\|'-separated; empty when the log carries no parsable column. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `experiment_file` | character | Base name(s) of the OpenSesame experiment file the log records, '\|'-separated. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `status` | character | 'match', 'mismatch' (the log records the other miniature language) or 'not_logged'. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `excluded` | logical | TRUE when the participant is listed in LES_P1_PROTOCOL_DEVIATION (_config.R). | paper_1_transfer/scripts/02_extract_accuracy.R |

## `_accuracy_rt_bands.csv`

111 data row(s), 7 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `grammatical_property` | character | snake_case property key. One row per property x mini_language x session x grammaticality x band, counted over the de-duplicated, otherwise-valid judgement trials before any response-time filter, so the Method can report what the legacy (200, 4000) ms screen removes (ISSUES.md G06-03). Counts only. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `mini_language` | character | Group assigned by lab-ID parity: 'Mini-Norwegian' or 'Mini-English'. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `session` | integer | Judgement session (2, 3, 4 or 6). | paper_1_transfer/scripts/02_extract_accuracy.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `band` | character | 'no_time' (no finite, positive response time; dropped under every rule), 'fast' (at or below 200 ms), 'kept' (strictly between 200 and 4000 ms, the trials the legacy screen keeps) or 'slow' (at or above 4000 ms). | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_trials` | integer | Trials in the cell. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_correct` | integer | Trials in the cell answered correctly. | paper_1_transfer/scripts/02_extract_accuracy.R |

## `_accuracy_rt_screen.csv`

1 data row(s), 8 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `n_valid_trials` | integer | Scored grammaticality-judgement trials before any response-time filter: Experiment-block rows with a canonical property and grammaticality and a 0/1 correctness value, pooled over the three properties and Sessions 2, 3, 4 and 6. The file holds one row. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_kept` | integer | Trials whose response time lies strictly between rt_min_ms and rt_max_ms. Since 19 October 2026 (ISSUES.md G06-03) these are all trials with a finite, positive response time, the data of the reported accuracy models; until then the file recorded the legacy (200, 4000) ms screen. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_rt_excluded` | integer | n_valid_trials minus n_kept: the trials without a finite, positive response time. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `pct_rt_excluded` | numeric | 100 * n_rt_excluded / n_valid_trials. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `rt_min_ms` | integer | Lower response-time bound in milliseconds, 0: a trial must exceed it to be kept. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `rt_max_ms` | numeric | Upper response-time bound in milliseconds, Inf: no upper bound. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_duplicates_removed` | integer | Rows removed before the response-time filter because their participant x session x property x trial number repeated an earlier row: the session-close re-logging of a file's last trial. They are not among n_valid_trials (ISSUES.md G06-02). | paper_1_transfer/scripts/02_extract_accuracy.R |
| `max_rt_kept_ms` | integer | The slowest response time among the trials kept, in milliseconds. | paper_1_transfer/scripts/02_extract_accuracy.R |

## `_accuracy_rt_screen_rtscreen.csv`

1 data row(s), 8 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `n_valid_trials` | integer | The legacy screen's copy of _accuracy_rt_screen.csv, written under LES_P1_ACC_RT_SCREEN=1, the sensitivity analysis since 19 October 2026 (ISSUES.md G06-03): scored grammaticality-judgement trials before any response-time filter, the same count as in the reported file. The file holds one row. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_kept` | integer | Trials whose response time lies strictly between 200 and 4000 ms, which the screened accuracy models (_rtscreen) are fitted to. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_rt_excluded` | integer | n_valid_trials minus n_kept. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `pct_rt_excluded` | numeric | 100 * n_rt_excluded / n_valid_trials. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `rt_min_ms` | integer | Lower response-time bound in milliseconds (200); a trial must exceed it to be kept. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `rt_max_ms` | integer | Upper response-time bound in milliseconds (4000); a trial must fall below it to be kept. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_duplicates_removed` | integer | Rows the presentation software logged twice under one trial number, removed before the count, as in the reported file. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `max_rt_kept_ms` | integer | The slowest response time among the trials kept, in milliseconds. | paper_1_transfer/scripts/02_extract_accuracy.R |

## `_accuracy_sdt_by_language.csv`

36 data row(s), 10 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-Norwegian' or 'Mini-English'. One row per group x session x property x measure. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `session` | integer | Judgement session (2, 3, 4 or 6). | paper_1_transfer/scripts/02_extract_accuracy.R |
| `grammatical_property` | character | snake_case property key. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `measure` | character | 'd_prime' (z(H) - z(FA)) or 'criterion' (-(z(H) + z(FA)) / 2, negative for a bias towards answering grammatical). Hit and false-alarm rates take the log-linear correction (Hautus, 1995). | paper_1_transfer/scripts/02_extract_accuracy.R |
| `mean_value` | numeric | Mean over participants of the participant-level measure; each participant with both sentence types in the cell has equal weight. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `sd_value` | numeric | Standard deviation of the participant-level measure. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_participants` | integer | Participants with at least one grammatical and one ungrammatical retained trial in the cell. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `se_value` | numeric | sd_value / sqrt(n_participants); NA when n_participants is one. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `ci_low` | numeric | Lower bound of a two-sided 95% t interval for mean_value. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `ci_high` | numeric | Upper bound of a two-sided 95% t interval for mean_value. | paper_1_transfer/scripts/02_extract_accuracy.R |

## `_accuracy_sdt_contrasts.csv`

714 data row(s), 11 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `model` | character | Accuracy model id: accuracy_<property> followed by any of '_diversity' (diversity covariate, LES_P1_ACC_DIVERSITY=1), '_rtscreen' (the legacy reaction-time screen, LES_P1_ACC_RT_SCREEN=1), '_maxranef' (by-participant grammaticality x session slope), '_byitem' (crossed by-item term) and '_weakprior' (weakly informative priors), in that order. One row per model x measure x contrast x group x session. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `measure` | character | 'sensitivity' (d_L = logit(H) - logit(FA)) or 'criterion' (c_L = -(logit(H) + logit(FA)) / 2), derived from the model's fixed effects at the design's exact z codes. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `contrast` | character | 'value' (one group at one session), 'language_difference' (Mini-Norwegian minus Mini-English), 'change_first_to_last' or 'change_s4_to_s6' (a group's change between two sessions), or either change with '_language_difference' appended. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `mini_language` | character | 'Mini-Norwegian', 'Mini-English', or 'Mini-Norwegian - Mini-English' for a difference. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `session` | character | Session ('2', '3', '4', '6'), 'average' for the mean z-scored session, or a span such as '2->6' for a change. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `median` | numeric | Posterior median. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_low` | numeric | 2.5th percentile of the posterior draws. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_high` | numeric | 97.5th percentile of the posterior draws. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `pd` | numeric | Probability of direction: the share of draws with the median's sign. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `mcse_low` | numeric | Monte Carlo standard error of ci_low (posterior::mcse_quantile over the chains), the sampling error a refit could move that bound by. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `mcse_high` | numeric | Monte Carlo standard error of ci_high (posterior::mcse_quantile over the chains), the sampling error a refit could move that bound by. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |

## `_accuracy_sentence_inventory.csv`

4 data row(s), 4 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `session` | integer | ERP session (2, 3, 4 or 6). One row per session. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_trials` | integer | Scored judgement trials in that session after the response-time screen and de-duplication, pooled over the three properties; these are the trials that reach the accuracy models. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_participants` | integer | Distinct participants contributing those trials. | paper_1_transfer/scripts/02_extract_accuracy.R |
| `n_distinct_sentences` | integer | Distinct sentence strings logged among those trials; NA when the logfiles carry no sentence column. | paper_1_transfer/scripts/02_extract_accuracy.R |

## `_audit_export_identity.csv`

25 data row(s), 7 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `quantity` | character | Name of the quantity. One row per quantity of the export-identity audit (whether each analysed export holds the trials its file name and markers say it does, and how far the exported trials' labels sit from the raw markers). The audit's README defines each. | paper_1_transfer/audit/make_audit_tables.py |
| `value` | numeric | The quantity's value, in the unit given. | paper_1_transfer/audit/make_audit_tables.py |
| `ci_low` | logical | Lower bound of its 95% interval where the quantity is an estimate; empty for a count. | paper_1_transfer/audit/make_audit_tables.py |
| `ci_high` | logical | Upper bound of that interval; empty for a count. | paper_1_transfer/audit/make_audit_tables.py |
| `unit` | character | Unit of value. | paper_1_transfer/audit/make_audit_tables.py |
| `source_script` | character | Audit script, under paper_1_transfer/audit/, that computed the value. | paper_1_transfer/audit/make_audit_tables.py |
| `note` | character | What was counted or estimated, and over which records. | paper_1_transfer/audit/make_audit_tables.py |

## `_audit_trial_loss.csv`

43 data row(s), 7 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `quantity` | character | Name of the quantity. One row per quantity the trial-loss audit reports (how many trials the five-sample trigger rule discards, and whether their loss is related to condition, group or session). The audit's README defines each. | paper_1_transfer/audit/make_audit_tables.py |
| `value` | numeric | The quantity's value, in the unit given. | paper_1_transfer/audit/make_audit_tables.py |
| `ci_low` | numeric | Lower bound of its 95% interval where the quantity is an estimate; empty for a count. | paper_1_transfer/audit/make_audit_tables.py |
| `ci_high` | numeric | Upper bound of that interval; empty for a count. | paper_1_transfer/audit/make_audit_tables.py |
| `unit` | character | Unit of value (events, trials, percent, odds ratio, ms and so on). | paper_1_transfer/audit/make_audit_tables.py |
| `source_script` | character | Audit script, under paper_1_transfer/audit/, that computed the value. | paper_1_transfer/audit/make_audit_tables.py |
| `note` | character | What was counted or estimated, and over which records. | paper_1_transfer/audit/make_audit_tables.py |

## `_decoding_provenance.csv`

3 data row(s), 3 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `component` | character | Decoding setting the record holds: 'seed:LES_DECODE_SEED', 'LES_DECODE_NPERM' (permutations in the null) or 'LES_DECODE_TIME_STEP_MS' (decoding grid in ms). The file without a tag records the primary decoding and the '_exclreproc' file the robustness run that leaves out the reprocessed and recovered records. Every per-property job writes its arm's file, so the last job to finish leaves it; the settings are the same across properties. | paper_1_transfer/hpc/08_decoding.slurm |
| `version` | integer | Value of the setting in the job that wrote the file. | paper_1_transfer/hpc/08_decoding.slurm |
| `recorded_utc` | character | UTC time of the write; the same on every row. | paper_1_transfer/hpc/08_decoding.slurm |

## `_decoding_provenance_exclreproc.csv`

3 data row(s), 3 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `component` | character | Decoding setting the record holds: 'seed:LES_DECODE_SEED', 'LES_DECODE_NPERM' (permutations in the null) or 'LES_DECODE_TIME_STEP_MS' (decoding grid in ms). The file without a tag records the primary decoding and the '_exclreproc' file the robustness run that leaves out the reprocessed and recovered records. Every per-property job writes its arm's file, so the last job to finish leaves it; the settings are the same across properties. | paper_1_transfer/hpc/08_decoding.slurm |
| `version` | integer | Value of the setting in the job that wrote the file. | paper_1_transfer/hpc/08_decoding.slurm |
| `recorded_utc` | character | UTC time of the write; the same on every row. | paper_1_transfer/hpc/08_decoding.slurm |

## `_difference_wave_differential_object_marking_lateral.csv`

28800 data row(s), 12 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-Norwegian' or 'Mini-English'. One row per group x session x property x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over their sessions, averaged over participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammatical_property` | character | Property label as the importer writes it. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_difference` | numeric | Mean participant-paired ungrammatical-minus-grammatical amplitude in microvolts, baseline-corrected within participant (violation minus control, the opposite sign to the models' grammaticality coefficient). | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `sd_difference` | numeric | Standard deviation of the participant-level differences. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_participants` | integer | Participants with both grammatical and ungrammatical waveforms in the cell. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `se_difference` | numeric | sd_difference / sqrt(n_participants); NA when n_participants is one. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_difference_wave_differential_object_marking_midline.csv`

14400 data row(s), 12 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-Norwegian' or 'Mini-English'. One row per group x session x property x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over their sessions, averaged over participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammatical_property` | character | Property label as the importer writes it. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_difference` | numeric | Mean participant-paired ungrammatical-minus-grammatical amplitude in microvolts, baseline-corrected within participant (violation minus control, the opposite sign to the models' grammaticality coefficient). | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `sd_difference` | numeric | Standard deviation of the participant-level differences. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_participants` | integer | Participants with both grammatical and ungrammatical waveforms in the cell. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `se_difference` | numeric | sd_difference / sqrt(n_participants); NA when n_participants is one. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_difference_wave_gender_agreement_lateral.csv`

36000 data row(s), 12 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-Norwegian' or 'Mini-English'. One row per group x session x property x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over their sessions, averaged over participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammatical_property` | character | Property label as the importer writes it. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_difference` | numeric | Mean participant-paired ungrammatical-minus-grammatical amplitude in microvolts, baseline-corrected within participant (violation minus control, the opposite sign to the models' grammaticality coefficient). | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `sd_difference` | numeric | Standard deviation of the participant-level differences. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_participants` | integer | Participants with both grammatical and ungrammatical waveforms in the cell. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `se_difference` | numeric | sd_difference / sqrt(n_participants); NA when n_participants is one. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_difference_wave_gender_agreement_midline.csv`

18000 data row(s), 12 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-Norwegian' or 'Mini-English'. One row per group x session x property x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over their sessions, averaged over participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammatical_property` | character | Property label as the importer writes it. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_difference` | numeric | Mean participant-paired ungrammatical-minus-grammatical amplitude in microvolts, baseline-corrected within participant (violation minus control, the opposite sign to the models' grammaticality coefficient). | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `sd_difference` | numeric | Standard deviation of the participant-level differences. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_participants` | integer | Participants with both grammatical and ungrammatical waveforms in the cell. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `se_difference` | numeric | sd_difference / sqrt(n_participants); NA when n_participants is one. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_difference_wave_verb_object_number_agreement_lateral.csv`

21600 data row(s), 12 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-Norwegian' or 'Mini-English'. One row per group x session x property x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over their sessions, averaged over participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammatical_property` | character | Property label as the importer writes it. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_difference` | numeric | Mean participant-paired ungrammatical-minus-grammatical amplitude in microvolts, baseline-corrected within participant (violation minus control, the opposite sign to the models' grammaticality coefficient). | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `sd_difference` | numeric | Standard deviation of the participant-level differences. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_participants` | integer | Participants with both grammatical and ungrammatical waveforms in the cell. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `se_difference` | numeric | sd_difference / sqrt(n_participants); NA when n_participants is one. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_difference_wave_verb_object_number_agreement_midline.csv`

10800 data row(s), 12 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-Norwegian' or 'Mini-English'. One row per group x session x property x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over their sessions, averaged over participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammatical_property` | character | Property label as the importer writes it. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_difference` | numeric | Mean participant-paired ungrammatical-minus-grammatical amplitude in microvolts, baseline-corrected within participant (violation minus control, the opposite sign to the models' grammaticality coefficient). | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `sd_difference` | numeric | Standard deviation of the participant-level differences. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_participants` | integer | Participants with both grammatical and ungrammatical waveforms in the cell. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `se_difference` | numeric | sd_difference / sqrt(n_participants); NA when n_participants is one. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

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

211200 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per miniature language x session x grammaticality x electrode x sample. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_amp` | numeric | Mean of participant-level amplitudes in microvolts at that electrode and sample, baseline-corrected within participant (-100 to -2 ms). Trials are averaged within participant first; the EEG exclusions of step 01 are applied before aggregation. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `sd_amp` | numeric | Standard deviation of participant-level mean amplitudes. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_participants` | integer | Participants contributing a retained observation to the cell. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_obs` | integer | Number of raw electrode-by-trial observations averaged within the contributing participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `se_amp` | numeric | Standard error of mean_amp over participants; NA when n_participants is one. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_grand_average_differential_object_marking_midline.csv`

76800 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per miniature language x session x grammaticality x electrode x sample. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_amp` | numeric | Mean of participant-level amplitudes in microvolts at that electrode and sample, baseline-corrected within participant (-100 to -2 ms). Trials are averaged within participant first; the EEG exclusions of step 01 are applied before aggregation. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `sd_amp` | numeric | Standard deviation of participant-level mean amplitudes. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_participants` | integer | Participants contributing a retained observation to the cell. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_obs` | integer | Number of raw electrode-by-trial observations averaged within the contributing participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `se_amp` | numeric | Standard error of mean_amp over participants; NA when n_participants is one. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_grand_average_gender_agreement_lateral.csv`

264000 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per miniature language x session x grammaticality x electrode x sample. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_amp` | numeric | Mean of participant-level amplitudes in microvolts at that electrode and sample, baseline-corrected within participant (-100 to -2 ms). Trials are averaged within participant first; the EEG exclusions of step 01 are applied before aggregation. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `sd_amp` | numeric | Standard deviation of participant-level mean amplitudes. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_participants` | integer | Participants contributing a retained observation to the cell. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_obs` | integer | Number of raw electrode-by-trial observations averaged within the contributing participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `se_amp` | numeric | Standard error of mean_amp over participants; NA when n_participants is one. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_grand_average_gender_agreement_midline.csv`

96000 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per miniature language x session x grammaticality x electrode x sample. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_amp` | numeric | Mean of participant-level amplitudes in microvolts at that electrode and sample, baseline-corrected within participant (-100 to -2 ms). Trials are averaged within participant first; the EEG exclusions of step 01 are applied before aggregation. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `sd_amp` | numeric | Standard deviation of participant-level mean amplitudes. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_participants` | integer | Participants contributing a retained observation to the cell. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_obs` | integer | Number of raw electrode-by-trial observations averaged within the contributing participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `se_amp` | numeric | Standard error of mean_amp over participants; NA when n_participants is one. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_grand_average_verb_object_number_agreement_lateral.csv`

158400 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per miniature language x session x grammaticality x electrode x sample. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_amp` | numeric | Mean of participant-level amplitudes in microvolts at that electrode and sample, baseline-corrected within participant (-100 to -2 ms). Trials are averaged within participant first; the EEG exclusions of step 01 are applied before aggregation. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `sd_amp` | numeric | Standard deviation of participant-level mean amplitudes. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_participants` | integer | Participants contributing a retained observation to the cell. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_obs` | integer | Number of raw electrode-by-trial observations averaged within the contributing participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `se_amp` | numeric | Standard error of mean_amp over participants; NA when n_participants is one. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_grand_average_verb_object_number_agreement_midline.csv`

57600 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per miniature language x session x grammaticality x electrode x sample. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_amp` | numeric | Mean of participant-level amplitudes in microvolts at that electrode and sample, baseline-corrected within participant (-100 to -2 ms). Trials are averaged within participant first; the EEG exclusions of step 01 are applied before aggregation. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `sd_amp` | numeric | Standard deviation of participant-level mean amplitudes. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_participants` | integer | Participants contributing a retained observation to the cell. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_obs` | integer | Number of raw electrode-by-trial observations averaged within the contributing participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `se_amp` | numeric | Standard error of mean_amp over participants; NA when n_participants is one. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_window_difference_differential_object_marking_lateral.csv`

528 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. One row per group x session x property x electrode x a priori window. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `session` | character | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammatical_property` | character | Property label as written by the ERP importer. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window` | character | A priori window key: '200_500', '300_600' or '400_900'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window_min_ms` | integer | Inclusive lower sample bound of the a priori window in nominal milliseconds. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window_max_ms` | integer | Inclusive upper sample bound of the a priori window in nominal milliseconds. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_difference` | numeric | Mean participant-paired ungrammatical-minus-grammatical amplitude in microvolts over the window (violation minus control, the opposite sign to the models' grammaticality coefficient), baseline-corrected within participant; the EEG exclusions of step 01 are applied first. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `sd_difference` | numeric | Standard deviation of the participant-level ungrammatical-minus-grammatical amplitudes. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_participants` | integer | Participants with both grammatical and ungrammatical amplitudes in the cell. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `se_difference` | numeric | Standard error of mean_difference over participants; NA when n_participants is one. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_window_difference_differential_object_marking_midline.csv`

192 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. One row per group x session x property x electrode x a priori window. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `session` | character | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammatical_property` | character | Property label as written by the ERP importer. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window` | character | A priori window key: '200_500', '300_600' or '400_900'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window_min_ms` | integer | Inclusive lower sample bound of the a priori window in nominal milliseconds. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window_max_ms` | integer | Inclusive upper sample bound of the a priori window in nominal milliseconds. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_difference` | numeric | Mean participant-paired ungrammatical-minus-grammatical amplitude in microvolts over the window (violation minus control, the opposite sign to the models' grammaticality coefficient), baseline-corrected within participant; the EEG exclusions of step 01 are applied first. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `sd_difference` | numeric | Standard deviation of the participant-level ungrammatical-minus-grammatical amplitudes. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_participants` | integer | Participants with both grammatical and ungrammatical amplitudes in the cell. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `se_difference` | numeric | Standard error of mean_difference over participants; NA when n_participants is one. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_window_difference_gender_agreement_lateral.csv`

660 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. One row per group x session x property x electrode x a priori window. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammatical_property` | character | Property label as written by the ERP importer. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window` | character | A priori window key: '200_500', '300_600' or '400_900'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window_min_ms` | integer | Inclusive lower sample bound of the a priori window in nominal milliseconds. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window_max_ms` | integer | Inclusive upper sample bound of the a priori window in nominal milliseconds. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_difference` | numeric | Mean participant-paired ungrammatical-minus-grammatical amplitude in microvolts over the window (violation minus control, the opposite sign to the models' grammaticality coefficient), baseline-corrected within participant; the EEG exclusions of step 01 are applied first. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `sd_difference` | numeric | Standard deviation of the participant-level ungrammatical-minus-grammatical amplitudes. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_participants` | integer | Participants with both grammatical and ungrammatical amplitudes in the cell. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `se_difference` | numeric | Standard error of mean_difference over participants; NA when n_participants is one. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_window_difference_gender_agreement_midline.csv`

240 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. One row per group x session x property x electrode x a priori window. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `session` | character | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammatical_property` | character | Property label as written by the ERP importer. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window` | character | A priori window key: '200_500', '300_600' or '400_900'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window_min_ms` | integer | Inclusive lower sample bound of the a priori window in nominal milliseconds. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window_max_ms` | integer | Inclusive upper sample bound of the a priori window in nominal milliseconds. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_difference` | numeric | Mean participant-paired ungrammatical-minus-grammatical amplitude in microvolts over the window (violation minus control, the opposite sign to the models' grammaticality coefficient), baseline-corrected within participant; the EEG exclusions of step 01 are applied first. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `sd_difference` | numeric | Standard deviation of the participant-level ungrammatical-minus-grammatical amplitudes. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_participants` | integer | Participants with both grammatical and ungrammatical amplitudes in the cell. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `se_difference` | numeric | Standard error of mean_difference over participants; NA when n_participants is one. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_window_difference_verb_object_number_agreement_lateral.csv`

396 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. One row per group x session x property x electrode x a priori window. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `session` | character | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammatical_property` | character | Property label as written by the ERP importer. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window` | character | A priori window key: '200_500', '300_600' or '400_900'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window_min_ms` | integer | Inclusive lower sample bound of the a priori window in nominal milliseconds. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window_max_ms` | integer | Inclusive upper sample bound of the a priori window in nominal milliseconds. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_difference` | numeric | Mean participant-paired ungrammatical-minus-grammatical amplitude in microvolts over the window (violation minus control, the opposite sign to the models' grammaticality coefficient), baseline-corrected within participant; the EEG exclusions of step 01 are applied first. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `sd_difference` | numeric | Standard deviation of the participant-level ungrammatical-minus-grammatical amplitudes. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_participants` | integer | Participants with both grammatical and ungrammatical amplitudes in the cell. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `se_difference` | numeric | Standard error of mean_difference over participants; NA when n_participants is one. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_electrode_window_difference_verb_object_number_agreement_midline.csv`

144 data row(s), 15 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. One row per group x session x property x electrode x a priori window. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `session` | character | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `grammatical_property` | character | Property label as written by the ERP importer. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `electrode` | character | 10-20 electrode label. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `brain_region` | character | Cluster label of the electrode (see _electrode_coordinates.csv). | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window` | character | A priori window key: '200_500', '300_600' or '400_900'. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window_min_ms` | integer | Inclusive lower sample bound of the a priori window in nominal milliseconds. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `window_max_ms` | integer | Inclusive upper sample bound of the a priori window in nominal milliseconds. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `mean_difference` | numeric | Mean participant-paired ungrammatical-minus-grammatical amplitude in microvolts over the window (violation minus control, the opposite sign to the models' grammaticality coefficient), baseline-corrected within participant; the EEG exclusions of step 01 are applied first. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `sd_difference` | numeric | Standard deviation of the participant-level ungrammatical-minus-grammatical amplitudes. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `n_participants` | integer | Participants with both grammatical and ungrammatical amplitudes in the cell. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |
| `se_difference` | numeric | Standard error of mean_difference over participants; NA when n_participants is one. | paper_1_transfer/scripts/07b_extract_grand_average_by_electrode.R |

## `_erp_trial_retention.csv`

38 data row(s), 11 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `scope` | character | 'per_condition_canonical' (one modelled Grammatical or Ungrammatical cell), 'canonical' (every Grammatical and Ungrammatical cell pooled) or 'overall' (every grammaticality category pooled, ancillary violations included). One row per per-condition cell plus the two pooled rows. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `grammatical_property` | character | snake_case property key; 'ALL' on the pooled rows. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `session` | integer | ERP session (2, 3, 4 or 6); NA on the pooled rows. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `mini_language` | character | 'Mini-English', 'Mini-Norwegian' or 'ALL' on the pooled rows. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `grammaticality` | character | 'Grammatical', 'Ungrammatical', 'Grammatical+Ungrammatical' (the canonical pooled row) or 'ALL' (the overall pooled row). | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `mean_retained` | numeric | Mean number of EEG trials exported per participant x session x property x grammaticality cell (losses come from the segmentation trigger rule and manual removal; no automatic artefact criterion removed a trial, see ISSUES.md N7), every cell weighted equally; rounded to 3 decimals. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `sd_retained` | numeric | Standard deviation of that count across cells. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `n_cells` | integer | Number of participant-level cells summarised. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `presented_per_cell` | integer | Trials presented per cell by design (48). | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `pct_discarded` | numeric | 100 * (presented_per_cell - mean_retained) / presented_per_cell. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
| `source` | character | Where the retained-trial counts come from: 'extracted_single_trials' (counted in step 01's single-trial cell files, so they describe the analysed sample) or 'legacy_trial_count_table' (data/EEG_trial_count_per_condition.csv, the datasets as first exported; the fallback when the cell files are absent). ISSUES.md N15. | paper_1_transfer/scripts/00c_extract_erp_retention.R |

## `_first_session_language_advantage.csv`

21 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `model` | character | Accuracy model id: accuracy_<property> followed by any of '_diversity' (diversity covariate, LES_P1_ACC_DIVERSITY=1), '_rtscreen' (the legacy reaction-time screen, LES_P1_ACC_RT_SCREEN=1), '_maxranef' (by-participant grammaticality x session slope), '_byitem' (crossed by-item term) and '_weakprior' (weakly informative priors), in that order. One row per model. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `contrast` | character | 'gram_x_language_at_first_session': the grammaticality x mini-language coefficient evaluated at the property's earliest measured session, b_gram:lang + z_first * b_gram:session:lang, where z_first is the standardised code of that session. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `median` | numeric | Posterior median of the contrast on the logit scale. Mini-language is coded Mini-Norwegian = +0.5 and Mini-English = -0.5 before standardisation, so a positive value is a larger grammaticality effect in the Mini-Norwegian group. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_low` | numeric | 2.5th percentile of the posterior (lower bound of the equal-tailed 95% credible interval). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_high` | numeric | 97.5th percentile of the posterior (upper bound of the equal-tailed 95% credible interval). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `pd` | numeric | Probability of direction: the larger of the posterior mass above zero and below zero. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |

## `_flow_inconsistencies.csv`

11 data row(s), 4 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `check` | character | Name of the consistency check that fired: 'data_without_attendance:<stage>', 'non_monotonic_attendance', 'language_parity_mismatch', 'duplicate_lab_ID', 'duplicate_home_ID', 'missing_lab_ID', 'enrolled_no_attendance', 'erp_without_accuracy', 'accuracy_without_erp', 'incomplete_predictor_set' or 'flow_total_mismatch'. One row per detected inconsistency. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `severity` | character | 'error', 'warning' or 'info'. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `participant_lab_ID` | integer | Lab ID of the participant concerned; NA for 'flow_total_mismatch', which is a property of a stage. | paper_1_transfer/scripts/00b_audit_participant_flow.R |
| `detail` | character | Free-text statement of the inconsistency. | paper_1_transfer/scripts/00b_audit_participant_flow.R |

## `_grand_average_differential_object_marking_lateral.csv`

57600 data row(s), 14 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per miniature language x session x grammaticality x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled: left, midline or right crossed with anterior, medial or posterior. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_amp` | numeric | Mean of participant-level amplitudes in microvolts after averaging trials and electrodes within participant and subtracting that participant's pre-stimulus mean (-100 to -2 ms); the EEG exclusions of step 01 are applied first. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `sd_amp` | numeric | Standard deviation of participant-level mean amplitudes. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_participants` | integer | Participants contributing a retained observation to the cell. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_obs` | integer | Number of raw electrode-by-trial observations averaged within the contributing participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `se_amp` | numeric | Standard error of mean_amp over participants; NA when n_participants is one. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_grand_average_differential_object_marking_midline.csv`

28800 data row(s), 14 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per miniature language x session x grammaticality x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled: left, midline or right crossed with anterior, medial or posterior. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_amp` | numeric | Mean of participant-level amplitudes in microvolts after averaging trials and electrodes within participant and subtracting that participant's pre-stimulus mean (-100 to -2 ms); the EEG exclusions of step 01 are applied first. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `sd_amp` | numeric | Standard deviation of participant-level mean amplitudes. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_participants` | integer | Participants contributing a retained observation to the cell. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_obs` | integer | Number of raw electrode-by-trial observations averaged within the contributing participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `se_amp` | numeric | Standard error of mean_amp over participants; NA when n_participants is one. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_grand_average_gender_agreement_lateral.csv`

72000 data row(s), 14 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per miniature language x session x grammaticality x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled: left, midline or right crossed with anterior, medial or posterior. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_amp` | numeric | Mean of participant-level amplitudes in microvolts after averaging trials and electrodes within participant and subtracting that participant's pre-stimulus mean (-100 to -2 ms); the EEG exclusions of step 01 are applied first. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `sd_amp` | numeric | Standard deviation of participant-level mean amplitudes. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_participants` | integer | Participants contributing a retained observation to the cell. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_obs` | integer | Number of raw electrode-by-trial observations averaged within the contributing participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `se_amp` | numeric | Standard error of mean_amp over participants; NA when n_participants is one. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_grand_average_gender_agreement_midline.csv`

36000 data row(s), 14 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per miniature language x session x grammaticality x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled: left, midline or right crossed with anterior, medial or posterior. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_amp` | numeric | Mean of participant-level amplitudes in microvolts after averaging trials and electrodes within participant and subtracting that participant's pre-stimulus mean (-100 to -2 ms); the EEG exclusions of step 01 are applied first. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `sd_amp` | numeric | Standard deviation of participant-level mean amplitudes. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_participants` | integer | Participants contributing a retained observation to the cell. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_obs` | integer | Number of raw electrode-by-trial observations averaged within the contributing participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `se_amp` | numeric | Standard error of mean_amp over participants; NA when n_participants is one. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_grand_average_verb_object_number_agreement_lateral.csv`

43200 data row(s), 14 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per miniature language x session x grammaticality x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled: left, midline or right crossed with anterior, medial or posterior. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | character | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_amp` | numeric | Mean of participant-level amplitudes in microvolts after averaging trials and electrodes within participant and subtracting that participant's pre-stimulus mean (-100 to -2 ms); the EEG exclusions of step 01 are applied first. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `sd_amp` | numeric | Standard deviation of participant-level mean amplitudes. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_participants` | integer | Participants contributing a retained observation to the cell. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_obs` | integer | Number of raw electrode-by-trial observations averaged within the contributing participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `se_amp` | numeric | Standard error of mean_amp over participants; NA when n_participants is one. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

## `_grand_average_verb_object_number_agreement_midline.csv`

21600 data row(s), 14 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `mini_language` | character | Miniature-language group: 'Mini-English' or 'Mini-Norwegian'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `session` | integer | ERP session ('2', '3', '4' or '6'), or 'pooled' for each participant's mean over the sessions at which they contributed, averaged over participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammatical_property` | character | Property label as the importer writes it: 'Gender agreement', 'Differential object marking' or 'Verb-object number agreement'. One row per miniature language x session x grammaticality x cluster x sample. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `grammaticality` | character | 'Grammatical' or 'Ungrammatical'; the ancillary violation conditions are excluded. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `macroregion` | character | 'lateral' or 'midline'; the file name carries the same value. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `brain_region` | character | Electrode cluster over which the electrodes are pooled: left, midline or right crossed with anterior, medial or posterior. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `hemisphere` | logical | 'left' or 'right'; NA for the midline clusters. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `caudality` | character | 'anterior', 'medial' or 'posterior'. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `time` | integer | Sample time in milliseconds, -100 to 1098 in 2 ms steps, on the exports' nominal grid: 0 ms is the critical-word onset inferred from the trigger sequence, 30 ms before the grammaticality trigger (the export's Time 0 marker, minus 15 samples). The recorded word-identity trigger falls 0 to 6 ms before 0 ms (1.6 ms on average), so the labels understate the time since that trigger by as much. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `mean_amp` | numeric | Mean of participant-level amplitudes in microvolts after averaging trials and electrodes within participant and subtracting that participant's pre-stimulus mean (-100 to -2 ms); the EEG exclusions of step 01 are applied first. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `sd_amp` | numeric | Standard deviation of participant-level mean amplitudes. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_participants` | integer | Participants contributing a retained observation to the cell. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `n_obs` | integer | Number of raw electrode-by-trial observations averaged within the contributing participants. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |
| `se_amp` | numeric | Standard error of mean_amp over participants; NA when n_participants is one. | paper_1_transfer/scripts/07_extract_grand_average_waveforms.R |

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
| `session` | integer | A session holding mis-filtered recordings (2 or 3); one row per property recorded at that session. | paper_1_transfer/scripts/00c_extract_erp_retention.R |
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
| `metric` | character | Name of the demographic quantity: n_enrolled, n_mini_english, n_mini_norwegian, n_lhq3, age_years, sex_female, sex_male, sex_nonbinary, sex_undisclosed, hand_right, hand_left, hand_reported_n, eng_aoa_listen, eng_aoa_4mod, eng_years, eng_l2_proficiency, multilingual_diversity, n_other_language. The sex_* rows count the answers to the LHQ3 Gender item, which records self-reported gender, not sex; the keys keep their earlier names (ISSUES.md G04-25). One row per metric, computed over the analysed participants with an LHQ3 record unless the note says otherwise. | paper_1_transfer/scripts/00_extract_participants.R |
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

135 data row(s), 10 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `model` | character | Model id taken from the artefact file name: 'erp_<property>_<window>_<macroregion>' for the 18 ERP cells and 'accuracy_<property>' for the judgement models. The id carries the tags of the fit in the order they compose: a data-variant tag, either '_exclreproc' for an ERP cell of the robustness analysis that drops every reprocessed or recovered participant-session (LES_P1_EXCLUDE_REPROCESSED=1) or '_diversity' (the diversity covariate, LES_P1_ACC_DIVERSITY=1) and '_rtscreen' (the legacy reaction-time screen, LES_P1_ACC_RT_SCREEN=1) for an accuracy model, then '_weakprior' (weakly informative priors), '_itemslope' (maximal by-item structure) and '_retfree' (explicit Session-6 offset). An accuracy id is accuracy_<property> followed by any of '_diversity' (diversity covariate, LES_P1_ACC_DIVERSITY=1), '_rtscreen' (the legacy reaction-time screen, LES_P1_ACC_RT_SCREEN=1), '_maxranef' (by-participant grammaticality x session slope), '_byitem' (crossed by-item term) and '_weakprior' (weakly informative priors), in that order. One row per fitted model. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `max_rhat` | numeric | Largest rank-normalised split R-hat over every parameter of the fit. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `min_ess_bulk` | numeric | Smallest bulk effective sample size over every parameter of the fit. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `min_ess_tail` | numeric | Smallest tail effective sample size over every parameter of the fit. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `n_divergent` | integer | Divergent transitions after warm-up, summed over chains. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `n_treedepth` | logical | Iterations that saturated max_treedepth; NA under the cmdstanr backend, where the ceiling cannot be read from the fit object. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `passed` | logical | TRUE when max_rhat < 1.01, min_ess_bulk > 400, min_ess_tail > 400 and n_divergent == 0. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `structure` | character | Random-effect structure read from the file name: 'maximal' when the by-item term carries a grammaticality slope (the '_itemslope' tag), otherwise 'base'. The accuracy structure variants ('_maxranef', '_byitem') are recorded as 'base': this column describes the ERP models' by-item term, and an accuracy fit's structure is read from its id. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `retention_free` | logical | TRUE for a '_retfree' fit, in which an indicator for the last sampled session is added to the linear session trend. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `prior_variant` | character | 'weak' for a '_weakprior' fit, otherwise 'informative'. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |

## `_pooled_fit_metadata.csv`

135 data row(s), 29 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `model` | character | Model id recorded at fit time: the ERP cell id, carrying '_exclreproc' for the robustness analysis but not the prior or structure tags; or the accuracy id accuracy_<property> followed by any of '_diversity', '_rtscreen', '_maxranef' and '_byitem', but not '_weakprior'. One row per fitted model. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `n_obs` | integer | Rows of the data frame passed to brms after listwise deletion: single trials for an ERP cell, judgement trials for an accuracy model. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `n_participants` | integer | Distinct participants in that data frame. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `exclusion_applicable` | logical | TRUE for ERP fits, where the EEG exclusions bear on the data; FALSE for accuracy fits, whose behavioural judgements are unaffected by the EEG filter. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `misfiltered_rows` | integer | Rows of the fitted data that hold the legacy (1 Hz) derivative of a participant-session listed in LES_P1_MISFILTERED; rows read from the reprocessed overlay are not counted. NA when the exclusion is not applicable. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `exclusion_applied` | logical | TRUE when the exclusion is not applicable or misfiltered_rows is 0. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `exclude_reprocessed` | logical | Whether LES_P1_EXCLUDE_REPROCESSED=1 was set for the fit: TRUE for the robustness analysis that drops every participant-session in LES_P1_MISFILTERED or LES_P1_INVALID_EXPORTS whatever its source. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `invalid_export_rows` | integer | Rows of the fitted data read from the legacy exports that do not contain their participant-session (LES_P1_INVALID_EXPORTS); rows of a recovered export read from the overlay are not counted. NA when the exclusion is not applicable, and absent from records written before 16 September 2026. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `reprocessed_rows` | integer | Rows of the fitted data read from the overlay of reprocessed or recovered exports for a participant-session in LES_P1_MISFILTERED or LES_P1_INVALID_EXPORTS: part of the primary analysis, and 0 in the robustness analysis. NA when the exclusion is not applicable. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `erp_model_version` | character | LES_P1_ERP_MODEL_VERSION at fit time for ERP fits ('trial_level_2026-09-17': one row per trial per macroregion); NA for accuracy fits and absent from records of the superseded cluster-row model. Script 05 pools only ERP fits carrying the current version. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `deviation_rows` | integer | Rows of the fitted data belonging to the participant excluded for a protocol deviation (LES_P1_PROTOCOL_DEVIATION). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `prior_set` | character | Value of LES_PRIOR_SET at fit time: 'informative' (the default) or 'weak'. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `structure` | character | 'base' or 'maximal', recomputed from the artefact file name when the records are pooled. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `r_version` | character | R version loaded by the fitting process. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `brms_version` | character | brms version the fit was made with: read from the fit object for records written from 3 October 2026, and the version loaded by the fitting process for earlier records. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `cmdstanr_version` | character | cmdstanr version the fit was made with: read from the fit object for records written from 3 October 2026, and the version loaded by the fitting process for earlier records. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `cmdstan_version` | character | CmdStan version the fit was made with: read from the fit object for records written from 3 October 2026, and the version loaded by the fitting process for earlier records. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `fitted_utc` | character | UTC timestamp at which the fit record was written. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `chains` | integer | Number of chains, read from the fitted object; NA in records written before 3 October 2026. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `iter_warmup` | integer | Warm-up iterations per chain, read from the fitted object. NA in records written before the field existed, which ran the default of 2000. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `iter_sampling` | integer | Post-warm-up iterations per chain, read from the fitted object. NA in records written before the field existed, which ran the default of 8000; a larger value marks a fit run longer to clear the R-hat gate (LES_ITER_SAMPLING). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `seed` | integer | Seed the fit was sampled with, read from the fitted object; NA in records written before 3 October 2026. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `adapt_delta` | numeric | NUTS target acceptance rate (adapt_delta) the fit was sampled with, read from the fitted object; NA in records written before 3 October 2026. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `max_treedepth` | integer | Maximum NUTS tree depth the fit was sampled with, read from the fitted object; NA in records written before 3 October 2026. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `sampling_started_utc` | character | UTC time at which sampling started, from the fitted object's start_datetime; NA in records written before 3 October 2026 or when the object does not record it. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `formula` | character | The brms model formula as fitted, deparsed to one line; NA in records written before 3 October 2026. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `prior_variant` | character | 'weak' or 'informative', recomputed from the artefact file name when the records are pooled. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `retention_free` | logical | TRUE for a '_retfree' fit, recomputed from the artefact file name. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `model_tag` | character | Full artefact name without the '_fitmeta.rds' suffix, so every prior, structure and data-variant tag is visible. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |

## `_pooled_posterior_summaries.csv`

1407 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `parameter` | character | brms population-level term with the 'b_' prefix removed, for example 'Intercept' or 'z_recoded_grammaticality:z_recoded_session'. The recoded predictors are sum-coded contrasts standardised within the modelled cell: grammaticality Grammatical = +0.5 and Ungrammatical = -0.5; mini-language Mini-Norwegian = +0.5 and Mini-English = -0.5; session 0, 1, 2, 3 for Sessions 2, 3, 4, 6. Fits of the superseded cluster-row model (before 17 September 2026) also carried hemisphere and caudality terms, coded likewise; the trial-level models have none. z_baseline_predictor is the trial's own standardised pre-stimulus mean over the macroregion's clusters, z_multilingual_language_diversity the standardised LHQ3 covariate, and z_retention is +0.5 at the last sampled session and -0.5 elsewhere. One row per parameter per model. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `median` | numeric | Posterior median. ERP models: change in within-participant standardised amplitude (SD units) per unit of the standardised predictor. Accuracy models: change on the logit scale. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_low` | numeric | 2.5th percentile of the posterior (lower bound of the equal-tailed 95% credible interval). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `ci_high` | numeric | 97.5th percentile of the posterior (upper bound of the equal-tailed 95% credible interval). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `pd` | numeric | Probability of direction: the larger of the posterior mass above zero and below zero. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `model` | character | Model id from the artefact file name, with its tags in the order they compose: for an ERP cell '_exclreproc', '_weakprior', '_itemslope' and '_retfree'; for an accuracy model '_diversity', '_maxranef', '_byitem' and '_weakprior' (see _pooled_convergence.csv). | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |

## `_prior_predictive_check.csv`

40501 data row(s), 4 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `series` | character | 'observed' for the representative cell's single-trial amplitudes, 'prior' for a dataset simulated from its priors alone (the likelihood switched off). One row per series, draw and grid point. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `draw` | integer | 0 for the observed amplitudes; 1 to ndraws (see _prior_predictive_check_meta.csv) for the simulated datasets. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `x` | numeric | Grid point, in within-participant SD units of single-trial amplitude, over the displayed range x_min to x_max. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `density` | numeric | Gaussian kernel density of the series at x (stats::density, bw = 'nrd0'), estimated on every value of the series and evaluated on the grid. | paper_1_transfer/scripts/03b_export_prior_predictive.R |

## `_prior_predictive_check_meta.csv`

1 data row(s), 17 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `model_tag` | character | Cache tag of the model the check describes (erp_gender_agreement_400_900_midline_itemslope: maximal random-effect structure, informative priors). One row. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `n_obs` | integer | Trials in the cell's data after the complete-case filter of step 3. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `n_participants` | integer | Participants in the cell's data. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `n_items` | integer | Items (language x sentence frame) in the cell's data. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `ndraws` | integer | Datasets simulated from the priors and drawn in the figure. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `chains` | integer | Chains of the prior-only model. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `iter` | integer | Iterations per chain of the prior-only model, warm-up included. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `warmup` | integer | Warm-up iterations per chain. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `seed` | integer | Seed of the prior-only model and of the choice of simulated datasets (LES_SEED). | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `backend` | character | brms backend used: 'cmdstanr' or 'rstan'. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `x_min` | integer | Lower end of the displayed range, in within-participant SD units. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `x_max` | integer | Upper end of the displayed range, in within-participant SD units. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `abs_q99` | numeric | 99th percentile of the absolute simulated amplitudes, over every simulated dataset. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `abs_max` | numeric | Largest absolute simulated amplitude. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `share_within` | numeric | Share of the simulated amplitudes inside [x_min, x_max]. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `brms_version` | character | brms version that ran the check. | paper_1_transfer/scripts/03b_export_prior_predictive.R |
| `code_commit` | character | Commit of the deployed code (LES_CODE_COMMIT); NA when the job exported none. | paper_1_transfer/scripts/03b_export_prior_predictive.R |

## `_prior_sensitivity.csv`

384 data row(s), 14 column(s).

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
| `model` | character | Id of the informative fit: the ERP cell id or 'accuracy_<property>', with the tags that fit carries. An ERP id can add '_exclreproc' (reprocessed participant-sessions dropped), '_itemslope' (maximal structure) and, after '_itemslope' only, '_retfree' (explicit Session-6 offset). An accuracy id can add '_diversity' (diversity covariate). Each is paired with the weak-prior fit carrying the same tags, whose id has '_weakprior' after the cell or accuracy id and any data-variant tag. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `structure` | character | 'base' or 'maximal'. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |

## `_provenance.csv`

16 data row(s), 3 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `component` | character | What the row records: 'R', 'platform', an R package name (brms, cmdstanr, rstan, StanHeaders, posterior, loo, projpred, bayesplot, mgcv, MASS, dplyr), 'CmdStan', or 'seed:<name>' for a seed constant in force; and, in records written from October 2026, the data-handling packages (tidyr, readr, readxl, data.table, stringr, purrr), the sampling configuration (backend, threads_per_chain, chains, iter_warmup, iter_sampling, adapt_delta, max_treedepth), CXXFLAGS_OPTIM as read from CmdStan's make/local, modules (the loaded environment modules), env:<NAME> for each LES_* switch set for the run (paths left out), lockfile_check and lockfile_differs (the loaded library against renv.lock) and code_md5 and code_files (an MD5 over the analysis code, line endings normalised). One row per component. | _shared/R/04_provenance.R (called by paper_1_transfer/scripts/03_fit_brms_erp.R) |
| `version` | character | Version string as loaded by the run that fitted the ERP models, or the seed value. | _shared/R/04_provenance.R (called by paper_1_transfer/scripts/03_fit_brms_erp.R) |
| `recorded_utc` | character | UTC time of the write; the same on every row. | _shared/R/04_provenance.R (called by paper_1_transfer/scripts/03_fit_brms_erp.R) |

## `_retention_contrasts.csv`

540 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `model` | character | Fitted model id with its tags. One row per model x contrast. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
| `contrast` | character | 'overall' (at the standardised language mean), 'within_Mini-Norwegian', 'within_Mini-English' or 'language_difference' (Mini-Norwegian minus Mini-English). For a '_retfree' fit the same keys label the Session-6 deviation from the training trend. | paper_1_transfer/scripts/05_posterior_summaries_and_contrasts.R |
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

## `_task_durations_home.csv`

351 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `session` | integer | Home session: 1 (baseline) or 5 (post-training). One row per participant x session x task. Written to both papers by Paper 2's step 13. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |
| `task` | character | 'stroop', 'digit_span' or 'asrt' (the serial reaction time task), matched on the name of the Gorilla export. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |
| `duration_min` | numeric | Elapsed minutes between the first and the last 'UTC Timestamp' of the participant's events in that task and session, (last - first) / 60000, so any idle time between events is included. The timestamps themselves are not written, because beside the participant IDs they would disclose when each participant sat the task. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |
| `n_events` | integer | Events behind that duration: the distinct (Event Index, UTC Timestamp) pairs of the participant's rows in that task and session, so an event repeated in two export files counts once and two events logged in the same millisecond count twice. A participant who appears in both a numbered batch export (for example 'Stroop 1.csv') and a named export is counted from the batch export only. Tables written before October 2026 counted distinct timestamps. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |
| `participant_lab_ID` | integer | Lab ID joined from the participant key on the Gorilla home ID ('Participant Public ID'), which is not itself written: beside the lab ID it would link the row to the timestamped raw exports. Rows whose home ID has no lab ID in the key are dropped. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |
| `language` | character | Mini-language from the participant key: 'Mini-English' or 'Mini-Norwegian'. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |

## `_task_durations_lab.csv`

677 data row(s), 9 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `participant_lab_ID` | integer | Lab ID parsed from the OpenSesame logfile name ('subject-<n>...'). One row per participant x session x phase. Written to both papers by Paper 2's step 13. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |
| `session` | integer | Lab session (2, 3, 4 or 6), from the folder holding the logfile. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |
| `phase` | character | 'pretraining', 'training', 'test' or 'experiment'. A phase appears only when the logfile carries its start marker and an end later than that start. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |
| `start_ms` | integer | Smallest value of the phase's start marker (time_PRETRAINING, time_TRAINING, time_TEST or time_EXPERIMENT) in the logfile, in milliseconds. OpenSesame's time_ values are offsets within the session, so this is not a wall-clock time. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |
| `end_ms` | integer | End of the phase on the same clock, in milliseconds: the earliest start marker of a later phase that falls after start_ms or, when no later phase starts after it, the latest of the phase's own event markers after start_ms. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |
| `duration_min` | numeric | (end_ms - start_ms) / 60000. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |
| `boundary` | character | 'next phase start' when end_ms is a later phase's start marker, or 'last phase event' when it is the phase's own last event. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |
| `source_file` | character | Base name of the OpenSesame logfile. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |
| `language` | character | Mini-language from the participant key: 'Mini-English' or 'Mini-Norwegian'. Empty when the key has no match. | paper_2_plasticity/scripts/13_extract_task_durations.R (via _shared/R/07_task_durations.R) |

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

## `_trigger_check_cells.csv`

24 data row(s), 22 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `discarded_set` | character | Which critical words count as discarded by the five-sample trigger rule: 'all lags other than 5' (the check protocol Amendment 5 fixes) or 'lag 6 only' (a sensitivity analysis keeping only the commonest discarded lag). One row per discarded set, property, macroregion and window. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `property` | character | Grammatical property: 'differential_object_marking', 'gender_agreement' or 'verb_object_number_agreement'. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `macroregion` | character | Electrode macroregion of the ERP models: 'lateral' or 'midline', the equally weighted mean of its clusters' means. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `window` | character | Analysis window in ms after critical-word onset, as '<start>_<end>' (200_500, 300_600 or 400_900). | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `n_recordings` | integer | Recordings (session x participant) contributing a unit to the cell, that is with at least two epochs in each of the four kept/discarded x grammatical/ungrammatical cells. At most 17, the recordings Amendment 5 fixes. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `n_kept` | integer | Critical-word epochs the trigger rule keeps, summed over the contributing recordings and both grammaticality conditions. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `n_discarded` | integer | Critical-word epochs the trigger rule discards (those of the discarded set), summed as for n_kept. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `share_discarded` | numeric | n_discarded / (n_kept + n_discarded): the share of critical words that the rule leaves out of the analysed contrast. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `D_int` | numeric | Mean over recordings, with equal weight, of D_int = (discarded ungrammatical - grammatical) - (kept ungrammatical - grammatical), in µV, each cell mean adjusted for the pre-stimulus baseline by one slope common to the recording's four kept/discarded x condition cells. Zero when the discarded critical words are exchangeable with the kept ones. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `se` | numeric | Standard error of D_int across recordings (SD / sqrt(n_recordings)), in µV. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `df` | integer | Degrees of freedom of the t intervals: n_recordings - 1. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `ci90_low` | numeric | Lower limit of the 90% t interval for D_int, in µV; with ci90_high, the interval the two one-sided tests at alpha = .05 compare with the bound. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `ci90_high` | numeric | Upper limit of the 90% t interval for D_int, in µV. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `ci95_low` | numeric | Lower limit of the 95% t interval for D_int, in µV; the interval the manuscript reports. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `ci95_high` | numeric | Upper limit of the 95% t interval for D_int, in µV. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `bound` | numeric | Equivalence bound on \|D_int\| fixed by Amendment 5, in µV (0.91): at the expected discarded share of about 0.36 it keeps the shift in the analysed contrast within 0.33 µV. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `passes` | character | TRUE when the 90% interval lies strictly inside +-bound (the two one-sided tests reject both limits), FALSE otherwise. Written by pandas as True/False. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `implied_shift` | numeric | share_discarded x D_int, in µV: how far leaving out the discarded critical words moves the analysed grammaticality contrast. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `implied_shift_ci95_low` | numeric | share_discarded x ci95_low, in µV. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `implied_shift_ci95_high` | numeric | share_discarded x ci95_high, in µV. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `D_main` | numeric | Mean over recordings of the discarded-minus-kept difference averaged over the two grammaticality conditions, in µV, baseline-adjusted as D_int: whether the discarded words differ in overall amplitude, which the check does not test. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |
| `D_main_se` | numeric | Standard error of D_main across recordings, in µV. | paper_1_transfer/scripts/eeg_reconstruction/checks/trigger_check.py |

## `differential_object_marking_decoding_generalization.csv`

600 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `property` | character | snake_case key of the property decoded; the file name carries the same value. One row per train/test direction per time bin. | paper_1_transfer/scripts/09_run_decoding.R |
| `generalization` | character | 'cross_language'. | paper_1_transfer/scripts/09_run_decoding.R |
| `train_set` | character | Mini-language whose trials trained the decoder. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_set` | character | Mini-language whose trials were scored; its participants are disjoint from the training participants. | paper_1_transfer/scripts/09_run_decoding.R |
| `time_ms` | integer | Nominal centre of the time bin in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv). | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | AUC of a decoder trained on every train_set trial (class-balanced within participant) and scored on every test_set trial at that bin; NA when either set lacks both classes. Computed once over test trials pooled across participants, so unlike the time-course AUC it is not computed within participant and can be moved by participant-level differences in class share or score offset. | paper_1_transfer/scripts/09_run_decoding.R |

## `differential_object_marking_decoding_generalization_crossproperty.csv`

600 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `property` | character | snake_case key of the property the decoder was trained on; the file name carries the same value. One row per test property per time bin. | paper_1_transfer/scripts/09_run_decoding.R |
| `generalization` | character | 'cross_property'. | paper_1_transfer/scripts/09_run_decoding.R |
| `train_set` | character | Property whose trials trained the decoder. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_set` | character | Property whose trials were scored. | paper_1_transfer/scripts/09_run_decoding.R |
| `time_ms` | integer | Nominal centre of the bin on the time axis common to the two properties' tensors, in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv). | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | AUC of a decoder trained on every trial of train_set and scored on every trial of test_set at that bin. The same participants contribute to both sets, so the value is descriptive only. Computed over test trials pooled across participants, so it can be moved by participant-level differences in class share or score offset. | paper_1_transfer/scripts/09_run_decoding.R |

## `differential_object_marking_decoding_temporal_generalization.csv`

22500 data row(s), 5 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `train_time_ms` | integer | Bin at which the decoder was trained, in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv), on a grid coarsened to every second bin (8 ms by default). One row per train x test bin pair. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_time_ms` | integer | Bin at which the decoder was scored, on the same coarsened grid. | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | Mean AUC over leave-one-participant-out folds of a decoder trained at train_time_ms and scored at test_time_ms; NA where no fold was scorable. | paper_1_transfer/scripts/09_run_decoding.R |
| `n_folds` | integer | Number of held-out participants contributing to the mean. | paper_1_transfer/scripts/09_run_decoding.R |
| `property` | character | snake_case property key; the file name carries the same value. | paper_1_transfer/scripts/09_run_decoding.R |

## `differential_object_marking_decoding_timecourse.csv`

3000 data row(s), 20 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `time_ms` | integer | Nominal centre of the decoding time bin in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv); 4 ms bins over the -100 to 1098 ms epoch by default. One row per bin per analysis block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `auc` | numeric | Observed area under the ROC curve for Grammatical against Ungrammatical at that bin, averaged over leave-one-participant-out folds; Ungrammatical is the positive class and 0.5 is chance. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_mean` | numeric | Mean AUC over the within-participant label permutations at that bin. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_q975` | numeric | 97.5th percentile of that bin's permutation null; descriptive only, not the cluster-forming threshold. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `p_pointwise` | numeric | Exact permutation p-value for the bin, (b + 1) / (m + 1), with b the permutations at or above the observed AUC and m the permutations scored at that bin. NA where the bin itself is unscorable (auc NA; ISSUES.md G08-06), which no deposited file contains. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
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

## `differential_object_marking_exclreproc_decoding_timecourse.csv`

300 data row(s), 20 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `time_ms` | integer | Nominal centre of the decoding time bin in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv); 4 ms bins over the -100 to 1098 ms epoch by default. One row per bin per analysis block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `auc` | numeric | Observed area under the ROC curve for Grammatical against Ungrammatical at that bin, averaged over leave-one-participant-out folds; Ungrammatical is the positive class and 0.5 is chance. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_mean` | numeric | Mean AUC over the within-participant label permutations at that bin. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_q975` | numeric | 97.5th percentile of that bin's permutation null; descriptive only, not the cluster-forming threshold. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `p_pointwise` | numeric | Exact permutation p-value for the bin, (b + 1) / (m + 1), with b the permutations at or above the observed AUC and m the permutations scored at that bin. NA where the bin itself is unscorable (auc NA; ISSUES.md G08-06), which no deposited file contains. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
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
| `time_ms` | integer | Nominal centre of the time bin in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv). | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | AUC of a decoder trained on every train_set trial (class-balanced within participant) and scored on every test_set trial at that bin; NA when either set lacks both classes. Computed once over test trials pooled across participants, so unlike the time-course AUC it is not computed within participant and can be moved by participant-level differences in class share or score offset. | paper_1_transfer/scripts/09_run_decoding.R |

## `gender_agreement_decoding_generalization_crossproperty.csv`

600 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `property` | character | snake_case key of the property the decoder was trained on; the file name carries the same value. One row per test property per time bin. | paper_1_transfer/scripts/09_run_decoding.R |
| `generalization` | character | 'cross_property'. | paper_1_transfer/scripts/09_run_decoding.R |
| `train_set` | character | Property whose trials trained the decoder. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_set` | character | Property whose trials were scored. | paper_1_transfer/scripts/09_run_decoding.R |
| `time_ms` | integer | Nominal centre of the bin on the time axis common to the two properties' tensors, in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv). | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | AUC of a decoder trained on every trial of train_set and scored on every trial of test_set at that bin. The same participants contribute to both sets, so the value is descriptive only. Computed over test trials pooled across participants, so it can be moved by participant-level differences in class share or score offset. | paper_1_transfer/scripts/09_run_decoding.R |

## `gender_agreement_decoding_temporal_generalization.csv`

22500 data row(s), 5 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `train_time_ms` | integer | Bin at which the decoder was trained, in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv), on a grid coarsened to every second bin (8 ms by default). One row per train x test bin pair. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_time_ms` | integer | Bin at which the decoder was scored, on the same coarsened grid. | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | Mean AUC over leave-one-participant-out folds of a decoder trained at train_time_ms and scored at test_time_ms; NA where no fold was scorable. | paper_1_transfer/scripts/09_run_decoding.R |
| `n_folds` | integer | Number of held-out participants contributing to the mean. | paper_1_transfer/scripts/09_run_decoding.R |
| `property` | character | snake_case property key; the file name carries the same value. | paper_1_transfer/scripts/09_run_decoding.R |

## `gender_agreement_decoding_timecourse.csv`

3900 data row(s), 20 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `time_ms` | integer | Nominal centre of the decoding time bin in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv); 4 ms bins over the -100 to 1098 ms epoch by default. One row per bin per analysis block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `auc` | numeric | Observed area under the ROC curve for Grammatical against Ungrammatical at that bin, averaged over leave-one-participant-out folds; Ungrammatical is the positive class and 0.5 is chance. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_mean` | numeric | Mean AUC over the within-participant label permutations at that bin. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_q975` | numeric | 97.5th percentile of that bin's permutation null; descriptive only, not the cluster-forming threshold. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `p_pointwise` | numeric | Exact permutation p-value for the bin, (b + 1) / (m + 1), with b the permutations at or above the observed AUC and m the permutations scored at that bin. NA where the bin itself is unscorable (auc NA; ISSUES.md G08-06), which no deposited file contains. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
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

## `gender_agreement_exclreproc_decoding_timecourse.csv`

300 data row(s), 20 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `time_ms` | integer | Nominal centre of the decoding time bin in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv); 4 ms bins over the -100 to 1098 ms epoch by default. One row per bin per analysis block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `auc` | numeric | Observed area under the ROC curve for Grammatical against Ungrammatical at that bin, averaged over leave-one-participant-out folds; Ungrammatical is the positive class and 0.5 is chance. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_mean` | numeric | Mean AUC over the within-participant label permutations at that bin. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_q975` | numeric | 97.5th percentile of that bin's permutation null; descriptive only, not the cluster-forming threshold. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `p_pointwise` | numeric | Exact permutation p-value for the bin, (b + 1) / (m + 1), with b the permutations at or above the observed AUC and m the permutations scored at that bin. NA where the bin itself is unscorable (auc NA; ISSUES.md G08-06), which no deposited file contains. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
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
| `time_ms` | integer | Nominal centre of the time bin in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv). | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | AUC of a decoder trained on every train_set trial (class-balanced within participant) and scored on every test_set trial at that bin; NA when either set lacks both classes. Computed once over test trials pooled across participants, so unlike the time-course AUC it is not computed within participant and can be moved by participant-level differences in class share or score offset. | paper_1_transfer/scripts/09_run_decoding.R |

## `verb_object_number_agreement_decoding_generalization_crossproperty.csv`

600 data row(s), 6 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `property` | character | snake_case key of the property the decoder was trained on; the file name carries the same value. One row per test property per time bin. | paper_1_transfer/scripts/09_run_decoding.R |
| `generalization` | character | 'cross_property'. | paper_1_transfer/scripts/09_run_decoding.R |
| `train_set` | character | Property whose trials trained the decoder. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_set` | character | Property whose trials were scored. | paper_1_transfer/scripts/09_run_decoding.R |
| `time_ms` | integer | Nominal centre of the bin on the time axis common to the two properties' tensors, in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv). | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | AUC of a decoder trained on every trial of train_set and scored on every trial of test_set at that bin. The same participants contribute to both sets, so the value is descriptive only. Computed over test trials pooled across participants, so it can be moved by participant-level differences in class share or score offset. | paper_1_transfer/scripts/09_run_decoding.R |

## `verb_object_number_agreement_decoding_temporal_generalization.csv`

22500 data row(s), 5 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `train_time_ms` | integer | Bin at which the decoder was trained, in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv), on a grid coarsened to every second bin (8 ms by default). One row per train x test bin pair. | paper_1_transfer/scripts/09_run_decoding.R |
| `test_time_ms` | integer | Bin at which the decoder was scored, on the same coarsened grid. | paper_1_transfer/scripts/09_run_decoding.R |
| `auc` | numeric | Mean AUC over leave-one-participant-out folds of a decoder trained at train_time_ms and scored at test_time_ms; NA where no fold was scorable. | paper_1_transfer/scripts/09_run_decoding.R |
| `n_folds` | integer | Number of held-out participants contributing to the mean. | paper_1_transfer/scripts/09_run_decoding.R |
| `property` | character | snake_case property key; the file name carries the same value. | paper_1_transfer/scripts/09_run_decoding.R |

## `verb_object_number_agreement_decoding_timecourse.csv`

2100 data row(s), 20 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `time_ms` | integer | Nominal centre of the decoding time bin in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv); 4 ms bins over the -100 to 1098 ms epoch by default. One row per bin per analysis block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `auc` | numeric | Observed area under the ROC curve for Grammatical against Ungrammatical at that bin, averaged over leave-one-participant-out folds; Ungrammatical is the positive class and 0.5 is chance. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_mean` | numeric | Mean AUC over the within-participant label permutations at that bin. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_q975` | numeric | 97.5th percentile of that bin's permutation null; descriptive only, not the cluster-forming threshold. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `p_pointwise` | numeric | Exact permutation p-value for the bin, (b + 1) / (m + 1), with b the permutations at or above the observed AUC and m the permutations scored at that bin. NA where the bin itself is unscorable (auc NA; ISSUES.md G08-06), which no deposited file contains. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
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

## `verb_object_number_agreement_exclreproc_decoding_timecourse.csv`

300 data row(s), 20 column(s).

| Column | Class | Description | Writer script |
|---|---|---|---|
| `time_ms` | integer | Nominal centre of the decoding time bin in milliseconds from the nominal critical-word onset (see the time column of _grand_average_*.csv); 4 ms bins over the -100 to 1098 ms epoch by default. One row per bin per analysis block. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `auc` | numeric | Observed area under the ROC curve for Grammatical against Ungrammatical at that bin, averaged over leave-one-participant-out folds; Ungrammatical is the positive class and 0.5 is chance. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_mean` | numeric | Mean AUC over the within-participant label permutations at that bin. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `null_q975` | numeric | 97.5th percentile of that bin's permutation null; descriptive only, not the cluster-forming threshold. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
| `p_pointwise` | numeric | Exact permutation p-value for the bin, (b + 1) / (m + 1), with b the permutations at or above the observed AUC and m the permutations scored at that bin. NA where the bin itself is unscorable (auc NA; ISSUES.md G08-06), which no deposited file contains. | paper_1_transfer/scripts/09_run_decoding.R (09b_assemble_confirmatory_timecourse.R when assembled from checkpoints) |
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

