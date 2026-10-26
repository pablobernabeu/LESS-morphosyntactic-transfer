"""N7, step 5: compact analysis table for the condition tests, from ``n7_04_events.py``.

Supports the within-recording odds ratio of losing an ungrammatical rather than a grammatical
trial, and the trial-position, accuracy and response-time checks behind the Method's statement
that loss was unrelated to grammaticality, accuracy and item and only weakly related to response
time and trial position. Written on 17 September 2026 as ``gaps/gap6/02_prepare.py``; moved here
with only its paths changed.

One row per recorded S10x event with columns used by n7_06_condition_tests.py:
  recording, session, participant, condition, eligible (analysed recording), known (export status known),
  exported, lost (= known and not exported), lag5, lagrule_lost (lag != 5), hand_removed (lag 5, known, not exported),
  aligned, trial, n_trials, trial_prop, second_half, correct, rt_ms, log_rt, rt_z (within recording), sentence, prop.

Eligible = not one of the EEG exclusions decided by 17 September 2026: the nine Session-3 1 Hz recordings
(7, 8, 9, 16, 53, 60, 61, 62, 65), the three invalid exports (S3/48, S6/5, S2/7) and participant 14. These
are the participant-sessions whose legacy exports no analysis reads (``_config.R``: LES_P1_MISFILTERED,
LES_P1_INVALID_EXPORTS, LES_P1_PROTOCOL_DEVIATION); the audit concerns the legacy exports, so the
reprocessed and recovered records that later replaced some of them do not enter it. Rows whose recording has
no export file for the event's (property, condition) keep known = 0.

Reads   eeg_audit/independence/01_events.csv
Writes  eeg_audit/independence/02_table.csv (11 MB) and 02_log.txt
Runtime: about a minute.
"""
import numpy as np
import pandas as pd

import audit_paths

OUT = audit_paths.out_dir('independence')
ONE_HZ = {(3, p) for p in ('7', '8', '9', '16', '53', '60', '61', '62', '65')}
INVALID = {(3, '48'), (6, '5'), (2, '7')}

ev = pd.read_csv(OUT / '01_events.csv', dtype={'participant': str}, low_memory=False)
d = pd.DataFrame({'session': ev.session.astype(int), 'participant': ev.participant})
d['recording'] = 'S' + d.session.astype(str) + '_' + d.participant
d['condition'] = ev.condition.astype(int)
key = list(zip(d.session, d.participant))
d['one_hz'] = [k in ONE_HZ for k in key]
d['invalid_export'] = [k in INVALID for k in key]
d['eligible'] = (~d.one_hz & ~d.invalid_export & (d.participant != '14')).astype(int)
d['known'] = ev.export_status.isin(['exported', 'not exported']).astype(int)
d['exported'] = (ev.export_status == 'exported').astype(int)
d['lost'] = np.where(d.known == 1, 1 - d.exported, np.nan)
d['lag'] = ev.lag
d['lag5'] = (ev.lag == 5).astype(int)
d['lagrule_lost'] = 1 - d.lag5
d['hand_removed'] = np.where((d.known == 1) & (d.lag5 == 1), 1 - d.exported, np.nan)
d['exp_method'] = ev.exp_method
d['aligned'] = ev.aligned.astype(str).eq('True').astype(int)
d['trial'] = ev.log_trial
d['n_trials'] = ev.log_n_experiment_trials
d['trial_prop'] = d.trial / d.n_trials
d['second_half'] = np.where(d.trial_prop.notna(), (d.trial_prop > 0.5).astype(float), np.nan)
d['correct'] = ev.log_correct_grammaticality_judgement_response
d['rt_ms'] = ev.log_response_time_grammaticality_judgement_response
d['log_rt'] = np.log(d.rt_ms.clip(lower=0) + 1)
d['rt_z'] = d.groupby('recording').log_rt.transform(lambda x: (x - x.mean()) / x.std())
# property: raw property marker, else logged property trigger; logged property name wins where they disagree
name_map = {'gender agreement': 1, 'differential object marking': 2, 'verb-object agreement': 3}
d['prop_marker'] = ev.prop_marker
d['prop_logname'] = ev.log_grammatical_property.map(name_map)
d['prop'] = d.prop_logname.fillna(d.prop_marker).fillna(ev.log_grammatical_property_trigger)
d['sentence'] = ev.sentence
d['event_order'] = d.groupby('recording').cumcount()
d['order_prop'] = (d.event_order + 1) / d.groupby('recording').event_order.transform('size')
d.to_csv(OUT / '02_table.csv', index=False)
with open(OUT / '02_log.txt', 'w', encoding='utf-8') as fh:
    fh.write(f'rows {len(d)}, recordings {d.recording.nunique()}\n')
    fh.write(d.describe(include='all').T.to_string())
print(open(OUT / '02_log.txt', encoding='utf-8').read())
