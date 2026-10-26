"""Write the two manuscript-facing tables of the EEG export audit from the stage outputs.

The Method (segmentation, artefact screening, trial loss and the export checks) and ISSUES.md N6
and N7 quote these figures; the manuscript reads them through small helpers instead of typing
them. Every value is computed here from the outputs of the audit stages, never typed, so a
re-run of a stage changes the table and nothing else.

Reads (eeg_audit/<stage>/, see README.md for the stage that writes each):
    identity/audit_trial_identity_wide.csv, screen_exports.csv, duplicate_pairs.csv
    mechanism/events_all.csv, exports_all.csv, ar_nodes_all.csv, alternatives_all.csv
    independence/01_events.csv, 03_pooled.csv
    retention/01_T1_lang_sess_prop_cond.csv, 02_contrasts.csv
    precision/projection_summary.csv
Writes (results/, tracked):
    _audit_export_identity.csv   N6: trial identity and the stimulus-locked screen
    _audit_trial_loss.csv        N7: recorded, segmented, screened and exported events, the
                                 condition and group checks, and what a tolerant re-export buys
Both are long: quantity, value, ci_low, ci_high, unit, source_script, note. ci_low and ci_high hold
a 95% confidence interval only; ranges are separate quantities (suffixes _min and _max). No
recording time and no name enters either table.

Runtime: under a minute.
"""
from __future__ import annotations

import numpy as np
import pandas as pd

import audit_paths

SRC = 'paper_1_transfer/audit/'


def stage(name: str):
    return audit_paths.audit_root() / name


class Table:
    def __init__(self):
        self.rows = []

    def add(self, quantity, value, unit, script, note='', ci=(np.nan, np.nan)):
        self.rows.append(dict(quantity=quantity, value=value, ci_low=ci[0], ci_high=ci[1], unit=unit,
                              source_script=SRC + script, note=note))

    def write(self, name):
        out = pd.DataFrame(self.rows)
        dup = out.quantity[out.quantity.duplicated()]
        if len(dup):
            raise RuntimeError(f'duplicated quantities in {name}: {sorted(set(dup))}')
        path = audit_paths.results_dir() / name
        out.to_csv(path, index=False, float_format='%.6g')
        print(f'wrote {path} ({len(out)} rows)')


def range_rows(t: Table, stem, x, unit, script, note):
    t.add(f'{stem}_min', float(np.min(x)), unit, script, note)
    t.add(f'{stem}_median', float(np.median(x)), unit, script, note)
    t.add(f'{stem}_max', float(np.max(x)), unit, script, note)


# --------------------------------------------------------------------------- N7: trial loss
def trial_loss() -> Table:
    t = Table()
    # recorded events, from the raw marker files (n7_04)
    ev = pd.read_csv(stage('independence') / '01_events.csv', usecols=['session', 'participant', 'lag'], low_memory=False)
    n_rec = len(ev)
    t.add('events_recorded', n_rec, 'events', 'n7_04_events.py',
          f'S101/S102/S103 markers in the raw .vmrk files of {ev.groupby(["session", "participant"]).ngroups} '
          'participant-sessions (Sessions 2, 3, 4, 6)')
    not5 = int((ev.lag != 5).sum())
    lags = ev.lag.value_counts().sort_index()
    t.add('events_recorded_lag_not5', not5, 'events', 'n7_04_events.py',
          'property-to-condition interval other than five samples, raw markers; by lag: '
          + ', '.join(f'{int(k)}: {v}' for k, v in lags.items() if k != 5))
    t.add('events_recorded_lag_not5_pct', 100 * not5 / n_rec, 'percent of recorded events', 'n7_04_events.py')
    share = ev.assign(l5=ev.lag == 5).groupby(['session', 'participant']).l5.mean() * 100
    t.add('lag5_share_recording_min', share.min(), 'percent of a recording\'s events', 'n7_04_events.py',
          'lowest per-recording share of five-sample intervals')
    t.add('lag5_share_recording_max', share.max(), 'percent of a recording\'s events', 'n7_04_events.py',
          'highest per-recording share of five-sample intervals')

    # history events and their fate (n7_01, n7_02)
    e = pd.read_csv(stage('mechanism') / 'events_all.csv', low_memory=False)
    x = pd.read_csv(stage('mechanism') / 'exports_all.csv', low_memory=False)
    x = x[~x.is_copy.astype(bool)]
    in_t = e.in_T.astype(bool)
    kept = e.parent_kept.eq(True)
    removed = e.parent.notna() & e.parent_kept.eq(False)
    t.add('events_history', len(e), 'events', 'n7_01_mechanism.py',
          'S10x events in the node feeding the first-step segmentation of every export history; differs from '
          'events_recorded where a history holds another recording (S2/7, S3/48, S6/5)')
    hn5 = e.lag != 5
    t.add('events_history_lag_not5', int(hn5.sum()), 'events', 'n7_01_mechanism.py',
          'by lag: ' + ', '.join(f'{int(k)}: {v}' for k, v in e.lag.value_counts().sort_index().items() if k != 5))
    t.add('events_history_lag_not5_exported', int((hn5 & in_t).sum()), 'events', 'n7_01_mechanism.py',
          'events at a lag other than five samples that reached an export')
    t.add('events_history_lag5_kept_parent_not_exported', int(((e.lag == 5) & kept & ~in_t).sum()), 'events',
          'n7_01_mechanism.py', 'five-sample events whose first-step epoch survived and that still did not reach an export')
    t.add('events_history_lag_rule_lost', int((hn5 & kept & ~in_t).sum()), 'events', 'n7_01_mechanism.py',
          'lost to the five-sample rule with the first-step epoch kept (removal assigned first)')
    t.add('events_history_no_parent', int(e.parent.isna().sum()), 'events', 'n7_01_mechanism.py',
          'no first-step epoch: window over a bad interval marked at raw-data inspection, or across a recording gap')
    t.add('trials_exported', int(x.n_file.sum()), 'trials', 'n7_01_mechanism.py',
          f'segments in the {len(x)} trial-by-trial exports')
    t.add('trials_exported_with_vmrk', int(x[x.vmrk_present.astype(bool)].n_file.sum()), 'trials', 'n7_01_mechanism.py',
          f'segments in the {int(x.vmrk_present.astype(bool).sum())} exports that have a marker file, which is what '
          'the legacy importer reads')
    t.add('exports_without_vmrk', int((~x.vmrk_present.astype(bool)).sum()), 'exports', 'n7_01_mechanism.py',
          f'{int(x[~x.vmrk_present.astype(bool)].n_file.sum())} trials; S3/14 (S1_S101, S1_S102), S3/17 (S1_S101), '
          'S3/19 (S2_S103), S4/34 (S3_S101 to S3_S103)')

    # first-step artefact screening (n7_01 ar_nodes, summarised in n7_02)
    a = pd.read_csv(stage('mechanism') / 'ar_nodes_all.csv', low_memory=False)
    a = a.drop_duplicates(['session', 'participant', 'history_file', 'storage'])
    rm_flag, kept_flag = int(a.removed_segments_with_auto_detection.sum()), int(a.kept_segments_with_auto_detection.sum())
    crit = a[['MaxGradient', 'MaxDifference', 'DiIntervalLength', 'MinActivity', 'AcIntervalLength', 'GrBefore']].drop_duplicates()
    if len(crit) != 1:
        raise RuntimeError('artefact nodes do not share one set of criteria')
    c = crit.iloc[0]
    t.add('artefact_nodes', len(a), 'nodes', 'n7_02_summarise_mechanism.py',
          f'semi-automatic inspection nodes on the export chains; criteria: step {c.MaxGradient:g} uV/ms, range '
          f'{c.MaxDifference:g} uV within {c.DiIntervalLength:g} ms, activity {c.MinActivity:g} uV within '
          f'{c.AcIntervalLength:g} ms, each marked {c.GrBefore:g} ms either side')
    t.add('epochs_removed', int(a.desc2_removed.sum()), 'first-step epochs', 'n7_02_summarise_mechanism.py',
          'removed after review (one critical word each)')
    t.add('epochs_removed_flagged', rm_flag, 'first-step epochs', 'n7_02_summarise_mechanism.py',
          'removed epochs that carried a stored automatic detection')
    t.add('epochs_flagged_kept', kept_flag, 'first-step epochs', 'n7_02_summarise_mechanism.py',
          'flagged by the criteria and kept on review')
    t.add('epochs_flagged', rm_flag + kept_flag, 'first-step epochs', 'n7_02_summarise_mechanism.py')
    t.add('epochs_removed_lag5', int((removed & (e.lag == 5)).sum()), 'events', 'n7_02_summarise_mechanism.py',
          'removed epochs whose critical word had a five-sample interval, i.e. trials lost to the review alone')
    t.add('epochs_removed_pct_of_history_events', 100 * int(removed.sum()) / len(e), 'percent of events_history',
          'n7_02_summarise_mechanism.py')

    # trigger spacing and the label offset (n7_02)
    t.add('trigger_step_mean_ms', 2 * e.word_to_cond.mean() / 3, 'ms', 'n7_02_summarise_mechanism.py',
          'mean of the three steps from the word-identity to the condition trigger, history events (nominal 10 ms)')
    xe = e[in_t]
    off = 2 * xe.word_to_cond - 30
    t.add('label_offset_mean_ms', off.mean(), 'ms', 'n7_02_summarise_mechanism.py',
          'how far epoch labels understate time since the word-identity trigger, exported epochs')
    t.add('label_offset_min_ms', off.min(), 'ms', 'n7_02_summarise_mechanism.py')
    t.add('label_offset_max_ms', off.max(), 'ms', 'n7_02_summarise_mechanism.py',
          f'{int((off > 6).sum())} of {len(off)} exported epochs exceed 6 ms')

    # tolerant segmentation (n7_03)
    alt = pd.read_csv(stage('mechanism') / 'alternatives_all.csv', low_memory=False)
    n_ev, act, tol = len(alt), int(alt.actual.sum()), int(alt.child598.sum())
    t.add('actual_events_kept_pct', 100 * act / n_ev, 'percent of events_history', 'n7_03_alternatives.py',
          'events the actual two-step segmentation kept')
    t.add('tolerant_events_kept_pct', 100 * tol / n_ev, 'percent of events_history', 'n7_03_alternatives.py',
          'child epoch -128..1068 ms, which tolerates one sample of jitter either way')
    t.add('tolerant_events_recovered_pct', 100 * (tol - act) / n_ev, 'percent of events_history', 'n7_03_alternatives.py',
          'events the tolerant rule would keep and the actual rule did not')
    t.add('tolerant_trials_ratio', tol / act, 'ratio to the trials kept', 'n7_03_alternatives.py',
          'trials under the tolerant rule over trials exported, all conditions')
    g = alt[alt.cond.isin(['S101', 'S102'])]
    t.add('tolerant_trials_ratio_s101_s102', g.child598.sum() / g.actual.sum(), 'ratio to the trials kept',
          'n7_03_alternatives.py', 'grammatical and ungrammatical trials only')

    # within-recording condition test (n7_06)
    p = pd.read_csv(stage('independence') / '03_pooled.csv').set_index('outcome')
    r = p.loc['lost']
    t.add('or_loss_ungrammatical_vs_grammatical', r.mh_or, 'odds ratio', 'n7_06_condition_tests.py',
          f'Mantel-Haenszel, strata = recording x property ({int(r.mh_strata)}), analysed recordings as decided on '
          f'17 September 2026, Sessions 2-6 pooled, {int(r.n)} events; CMH p = {r.cmh_p:.3f}',
          (r.mh_lo, r.mh_hi))
    r = p.loc['hand_removed']
    t.add('or_review_removal_ungrammatical_vs_grammatical', r.mh_or, 'odds ratio', 'n7_06_condition_tests.py',
          f'removal on review among five-sample events; CMH p = {r.cmh_p:.3f}', (r.mh_lo, r.mh_hi))

    # Mini-English Session 6 imbalance (n7_12, n7_13)
    t1 = pd.read_csv(stage('retention') / '01_T1_lang_sess_prop_cond.csv')
    s6 = t1[(t1.scope == 'with_P20') & (t1.lang == 'English') & (t1.session == 6)]
    w = s6.pivot(index='property', columns='condition', values='pct_analysed')
    gaps = w.S101 - w.S102
    names = {'S1': 'gender', 'S2': 'dom', 'S3': 'voa'}
    n_rec6 = int(s6.n_recordings.iloc[0])
    for prop, gap in gaps.items():
        t.add(f's6_me_gap_{names[prop]}_pp', gap, 'percentage points of presented trials', 'n7_12_retention_by_group.py',
              f'grammatical minus ungrammatical retention of the legacy exports, Mini-English, Session 6, {n_rec6} '
              'recordings analysed as decided on 17 September 2026 (without the misaligned export of lab ID 5, '
              'whose re-segmented record entered later)')
    t.add('s6_me_gap_mean_pp', gaps.mean(), 'percentage points of presented trials', 'n7_12_retention_by_group.py',
          'mean of the three properties (equal to the pooled gap, since every cell presented the same number)')
    con = pd.read_csv(stage('retention') / '02_contrasts.csv')
    r = con[(con.scope == 'lost | S101/S102 analysed, with P20') & (con.session == 6)
            & (con.contrast == 'S102 vs S101 within Mini-English')].iloc[0]
    t.add('s6_me_or_loss_ungrammatical_vs_grammatical', r.OR, 'odds ratio', 'n7_13_retention_models.R',
          f'binomial GLMM, condition x session x language with participant and recording intercepts; p = {r.p:.4f}',
          (r.lo, r.hi))

    # precision of the language difference in the gender-agreement effect (n7_20)
    ps = pd.read_csv(stage('precision') / 'projection_summary.csv')
    gl = ps[ps.term == 'z_g:z_l']
    range_rows(t, 'gl_narrowing_trialdep_pct', gl[gl.structure == 'gstrial'].pct_narrower_D, 'percent of the interval',
               'n7_20_summarise_precision.R',
               'projected narrowing of the grammaticality x language interval under a tolerant re-export, 6 window x '
               'macroregion cells, with a trial intercept and the grammaticality x session slope (the dependence the '
               'October model handles); lme4, 17 September sample')
    range_rows(t, 'gl_narrowing_clusterrows_pct', gl[gl.structure == 'max'].pct_narrower_D, 'percent of the interval',
               'n7_20_summarise_precision.R',
               'the same under the August structure, which treated the cluster rows of a trial as independent')
    return t


# --------------------------------------------------------------------------- N6: export identity
def export_identity() -> Table:
    t = Table()
    w = pd.read_csv(stage('identity') / 'audit_trial_identity_wide.csv', low_memory=False)
    t.add('exports_audited', len(w), 'exports', 'n6_01_trial_identity.py', 'trial-by-trial exports, copies excluded')
    ps = w.groupby(['session', 'participant']).size()
    t.add('participant_sessions_audited', len(ps), 'participant-sessions', 'n6_01_trial_identity.py',
          'by session: ' + ', '.join(f'S{s}: {n}' for s, n in ps.groupby(level=0).size().items()))
    rs = w.groupby(['session', 'participant']).recording_start_history.first().reset_index()
    shared = rs.groupby('recording_start_history').filter(lambda g: len(g) > 1)
    t.add('recordings_shared', shared.recording_start_history.nunique(), 'recordings', 'n6_01_trial_identity.py',
          'recordings whose histories serve two participant-sessions: '
          + '; '.join(' and '.join(f'S{r.session}/{r.participant}' for r in g.itertuples())
                      for _, g in shared.groupby('recording_start_history')))
    diff = w[w.exceptions.fillna('').str.contains('different recording')].groupby(['session', 'participant']).size()
    t.add('histories_with_other_recordings_markers', len(diff), 'participant-sessions', 'n6_01_trial_identity.py',
          'the history root carries the markers and start time of another recording than the archived raw '
          'file of the same participant-session: ' + ', '.join(f'S{s}/{q}' for s, q in diff.index)
          + '. For S3/48 the signal is another participant\'s too; for S6/5 and S2/7 only the markers are '
          '(protocol Amendments 2 and 6)')

    x = pd.read_csv(stage('mechanism') / 'exports_all.csv', low_memory=False)
    x = x[~x.is_copy.astype(bool)]
    v = x[x.vmrk_present.astype(bool)]
    t.add('exports_reproduced_by_history', int(((v.n_content_match == v.n_file) & (v.n_T == v.n_file)).sum()), 'exports',
          'n7_01_mechanism.py', f'of {len(v)} exports with a marker file, every segment reproduced by the history node, '
          'markers and positions included')

    s = pd.read_csv(stage('identity') / 'screen_exports.csv')
    s['ps'] = 'S' + s.session.astype(str) + '/' + s.participant.astype(str)
    t.add('split_half_r_mean', s.split_half_r.mean(), 'correlation', 'n6_03_screen_exports.py',
          f'odd- vs even-trial posterior average, 0-600 ms, over {len(s)} participant-sessions')
    for ps_, tag in (('S6/5', 's6_5'), ('S2/7', 's2_7'), ('S2/63', 's2_63')):
        r = s[s.ps == ps_].iloc[0]
        t.add(f'split_half_r_{tag}', r.split_half_r, 'correlation', 'n6_03_screen_exports.py', f'{ps_}, all trials')
        t.add(f'split_half_r_s101_s102_{tag}', r.split_half_r_s101_s102, 'correlation', 'n6_03_screen_exports.py',
              f'{ps_}, grammatical and ungrammatical trials')
        t.add(f'loo_grand_average_r_{tag}', r.loo_grand_average_r, 'correlation', 'n6_03_screen_exports.py',
              f'{ps_} against the leave-one-out grand average of its session')
    others = s[~s.ps.isin(['S6/5', 'S2/7'])]
    low = others.loc[others.split_half_r.idxmin()]
    t.add('split_half_r_others_min', low.split_half_r, 'correlation', 'n6_03_screen_exports.py',
          f'lowest among the exports not found misaligned ({low.ps})')
    s2 = s[(s.session == 2) & (s.ps != 'S2/7')]
    low = s2.loc[s2.loo_grand_average_r.idxmin()]
    t.add('loo_grand_average_r_s2_others_min', low.loo_grand_average_r, 'correlation', 'n6_03_screen_exports.py',
          f'lowest Session 2 grand-average correlation among the other participants ({low.ps}); median '
          f'{s2.loo_grand_average_r.median():.2f}')
    p7 = s[(s.participant == 7) & (s.session != 2)].split_half_r
    t.add('split_half_r_id7_other_sessions_min', p7.min(), 'correlation', 'n6_03_screen_exports.py',
          'lab ID 7, Sessions 3, 4 and 6')
    t.add('split_half_r_id7_other_sessions_max', p7.max(), 'correlation', 'n6_03_screen_exports.py')

    d = pd.read_csv(stage('identity') / 'duplicate_pairs.csv')
    d = d[d.export == 'all'].set_index('pair')
    for pair, tag in (('S3/48 vs S3/58', 'id48_id58_s3'), ('S6/5 vs S4/5', 'id5_s6_s4')):
        r = d.loc[pair]
        t.add(f'pair_{tag}_trials', r.n_a, 'trials', 'n6_04_duplicate_pairs.py', f'{pair}: trials in the first export')
        t.add(f'pair_{tag}_paired', r.n_paired, 'trials', 'n6_04_duplicate_pairs.py',
              f'{pair}: trials of the first export whose time stamp occurs in the second')
        t.add(f'pair_{tag}_median_r', r.median_r, 'correlation', 'n6_04_duplicate_pairs.py',
              f'{pair}: median correlation of time-stamp-paired trials at Pz; quartiles {r.q25_r:.2f} to {r.q75_r:.2f}; '
              f'control (next time stamp) median {r.median_r_control:.2f}')
    return t


if __name__ == '__main__':
    export_identity().write('_audit_export_identity.csv')
    trial_loss().write('_audit_trial_loss.csv')
