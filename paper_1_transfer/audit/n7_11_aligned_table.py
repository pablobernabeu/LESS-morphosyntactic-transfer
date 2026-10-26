"""N7, step 11: analysis table and descriptive checks from n7_10_aligned_events.py.

Builds the trial table that n7_13_retention_models.R fits, and prints the recorded-level checks of
the N7 report (lag-5 share by condition, trial position and session; item structure; block sizes;
exported S101 - S102 count differences against a binomial null). Written on 17 September 2026 as
``verify/C09_recompute/02_prepare.py``; moved here with only its paths changed and a line removed
that printed a total from an earlier, superseded audit table for orientation.

Reads   eeg_audit/aligned/01_events.csv, 01_export_counts.csv; the behavioural logs (block sizes)
Writes  eeg_audit/aligned/02_analysis.csv (aligned events with lag 5 or 6 plus all aligned events
        flagged; 12 MB), 02_describe.txt, 02_export_pairs.csv
Runtime: about 2 minutes.
"""
import numpy as np
import pandas as pd
from scipy import stats

from aligned_io import BEH, OUT, read_header_cols

out = []


def say(*a):
    s = ' '.join(str(x) for x in a)
    out.append(s)
    print(s, flush=True)


pd.set_option('display.width', 250)
pd.set_option('display.max_columns', 40)
E = pd.read_csv(OUT / '01_events.csv', dtype={'participant': str}, low_memory=False)
say('recorded S10x events (raw .vmrk):', len(E), '| participant-sessions:', E.groupby(['session', 'participant']).ngroups,
    '| participants:', E.participant.nunique())
say('lag (within-trial) distribution:', E.lag.value_counts(dropna=False).sort_index().to_dict())
say('lag_any == lag for', int((E.lag_any == E.lag).sum()), 'of', len(E))

# ---------------- raw lag shares by condition (recorded level, no behaviour needed)
say('\n== A. lag-5 share by condition, all recorded events ==')
tab = pd.crosstab(E.condition, E.lag == 5)
say(tab.to_string())
say('share lag5:', (tab[True] / tab.sum(axis=1)).round(4).to_dict())
chi = stats.chi2_contingency(tab.to_numpy())
say(f'chi2({chi[2]}) = {chi[0]:.3f}, p = {chi[1]:.4f}')
L56 = E[E.lag.isin([5, 6])]
tab2 = pd.crosstab(L56.condition, L56.lag == 5)
chi2_ = stats.chi2_contingency(tab2.to_numpy())
say('restricted to lag 5 or 6: share lag5', (tab2[True] / tab2.sum(axis=1)).round(4).to_dict(),
    f'chi2({chi2_[2]}) = {chi2_[0]:.3f}, p = {chi2_[1]:.4f}')
say('exported (key-matched) share by condition, all recorded events:', E.groupby('condition').exported.mean().round(4).to_dict())
tab3 = pd.crosstab(E.condition, E.exported)
chi3 = stats.chi2_contingency(tab3.to_numpy())
say(f'  exported x condition chi2({chi3[2]}) = {chi3[0]:.3f}, p = {chi3[1]:.4f}')
say('exported but lag != 5:', int((E.exported & (E.lag != 5)).sum()), '| lag 5 but not exported:', int((~E.exported & (E.lag == 5)).sum()))

# ---------------- analysis table
A = E[E.beh_idx.notna()].copy()
A['recording'] = 'S' + A.session.astype(str) + '_' + A.participant
A['language'] = A.language_key.fillna(A.b_language)
A['property'] = A.b_grammatical_property.map({'gender agreement': 1, 'differential object marking': 2, 'verb-object agreement': 3})
say('\naligned events:', len(A), '| property name unmapped:', int(A.property.isna().sum()),
    '| logged property trigger != name-derived property:', int((A.b_grammatical_property_trigger != A.property).sum()),
    A.loc[A.b_grammatical_property_trigger != A.property].groupby('recording').size().to_dict())
say('raw property marker != logged property trigger:', int((A.prop != A.b_grammatical_property_trigger).sum()))
A['lag6'] = np.where(A.lag == 6, 1.0, np.where(A.lag == 5, 0.0, np.nan))
A['correct'] = A.b_correct_grammaticality_judgement_response.astype(int)
A['rt'] = pd.to_numeric(A.b_response_time_grammaticality_judgement_response, errors='coerce')
say('RT summary:', A.rt.describe().round(1).to_dict(), '| RT <= 0:', int((A.rt <= 0).sum()))
A['log_rt'] = np.log(A.rt + 1)
A['rt_z'] = A.groupby('recording').log_rt.transform(lambda x: (x - x.mean()) / x.std())
A['log_rt_c'] = A.log_rt - A.log_rt.mean()
A['trial'] = A.b_trial.astype(int)
say('n_exp_rows == n_targets for all aligned events:', bool((A.b_n_exp_rows == A.b_n_targets).all()),
    '| max_trial == n_exp_rows:', bool((A.b_max_trial == A.b_n_exp_rows).all()))
A['trial_prop'] = A.trial / A.b_n_exp_rows
A['trial_prop_c'] = A.trial_prop - 0.5
A['bs'] = np.where(A.session == 2, 40, 50)
A['pos_in_block'] = (A.trial - 1) % A.bs
A['block'] = (A.trial - 1) // A.bs
A['first_after_break'] = ((A.pos_in_block == 0) & (A.block > 0)).astype(int)
to_break = A.bs - 1 - A.pos_in_block
has_next_break = (A.trial + to_break) < A.b_n_exp_rows
dist = np.minimum(np.where(A.block > 0, A.pos_in_block, 999), np.where(has_next_break, to_break, 999))
A['near_break'] = (dist <= 2).astype(int)
A['wloc'] = A.b_target_word_location
A['item'] = 'S' + A.session.astype(str) + ':P' + A.property.astype('Int64').astype(str) + ':' + A.sent.astype('Int64').astype(str)
A['word'] = A.language.str.replace('Mini-', '') + ':' + A.word.astype('Int64').astype(str)
A['excluded'] = (A.participant.eq('14') | A.recording.isin(['S2_7', 'S3_48', 'S6_5']) |
                 A.recording.isin([f'S3_{x}' for x in (7, 8, 9, 16, 53, 60, 61, 62, 65)])).astype(int)
A.to_csv(OUT / '02_analysis.csv', index=False,
         columns=['session', 'participant', 'recording', 'language', 'property', 'condition', 'lag', 'lag6', 'exported',
                  'correct', 'rt', 'log_rt', 'rt_z', 'log_rt_c', 'trial', 'trial_prop', 'trial_prop_c', 'first_after_break',
                  'near_break', 'wloc', 'item', 'word', 'sent', 'excluded', 'match_type'])
M = A[A.lag6.notna()]
say('\n== B. model set (aligned, lag 5 or 6) ==')
say('n =', len(M), '| recordings:', M.recording.nunique(), '| participants:', M.participant.nunique(),
    '| lag-6 share:', round(M.lag6.mean(), 4))
say('recordings with S10x but no aligned events:', sorted(set('S' + E.session.astype(str) + '_' + E.participant) - set(A.recording)))
say('language missing:', int(M.language.isna().sum()), '| language counts (recordings):', M.groupby('language').recording.nunique().to_dict())
say('lag-5 share by condition in model set:', (1 - M.groupby('condition').lag6.mean()).round(4).to_dict())
t = pd.crosstab(M.condition, M.lag6)
c = stats.chi2_contingency(t.to_numpy())
say(f'  chi2({c[2]}) = {c[0]:.3f}, p = {c[1]:.4f}')
say('lag-6 share by tenth of trial position:', M.groupby(np.minimum((M.trial_prop * 10).astype(int), 9)).lag6.mean().round(4).to_dict())
say('  (tenth defined by ceil(10*trial/N)):', M.groupby(np.ceil(10 * M.trial_prop).astype(int)).lag6.mean().round(4).to_dict())
say('lag-6 share by trial third:', M.groupby(np.minimum((M.trial_prop * 3).astype(int), 2)).lag6.mean().round(4).to_dict())
say('lag-6 share by condition within session:')
say((M.groupby(['session', 'condition']).lag6.mean().unstack().round(4)).to_string())
for s in sorted(M.session.unique()):
    tt = pd.crosstab(M[M.session == s].condition, M[M.session == s].lag6)
    cc = stats.chi2_contingency(tt.to_numpy())
    say(f'  session {s}: chi2({cc[2]}) = {cc[0]:.2f}, p = {cc[1]:.4f}, n = {int(tt.to_numpy().sum())}')

# item structure: does a (session, property, sentence) item carry a fixed condition across participants?
ic = M.groupby('item').condition.nunique()
say('\nitems:', len(ic), '| items seen in >1 condition across participants:', int((ic > 1).sum()),
    '| participants per item median:', M.groupby('item').participant.nunique().median())
wc = M.groupby('word').condition.nunique()
say('target words:', M.word.nunique(), '| words seen in >1 condition:', int((wc > 1).sum()))

# ---------------- block size check from logs (breaks)
say('\n== C. break positions in logs (checks the 40/50 block size assumption) ==')
rows = []
for s in (2, 3, 4, 6):
    for f in sorted((BEH / f'Session {s}').glob('subject-*.csv')):
        if 'test' in f.name:
            continue
        sep, cols = read_header_cols(f)
        bc = [c for c in cols if c.startswith('count_break_') and 'trials' in c]
        if not bc or 'trial' not in cols:
            continue
        df = pd.read_csv(f, sep=sep, usecols=['trial', 'session_part'] + bc if 'session_part' in cols else ['trial'] + bc, low_memory=False)
        if 'session_part' in df:
            df = df[df.session_part == 'Experiment']
        v = df[bc].apply(pd.to_numeric, errors='coerce').max(axis=1)
        ch = df.trial[v.diff().fillna(0) > 0].tolist()
        rows.append(dict(session=s, file=f.name, break_trials=' '.join(str(int(x)) for x in ch[:4])))
br = pd.DataFrame(rows)
say(br.groupby(['session', 'break_trials']).size().to_string())

# ---------------- exported-count pairs S101 - S102 per participant x session x property
say('\n== D. exported counts (export .vhdr DataPoints/SegmentDataPoints; .vmrk New Segment count where present) ==')
C = pd.read_csv(OUT / '01_export_counts.csv', dtype={'participant': str})
C['n'] = C.n_vhdr
say('files with vhdr:', int(C.has_vhdr.sum()), '| vmrk-vhdr disagreements:',
    int((C.has_vmrk & C.has_vhdr & (C.n_vmrk != C.n_vhdr)).sum()), '| total exported segments (vhdr):', int(C.n.sum()))
W = C[C.has_vhdr].pivot_table(index=['session', 'participant', 'branch'], columns='condition', values='n', aggfunc='sum')
W = W.rename(columns=lambda x: f'S{x}').reset_index()
W = W[W.S101.notna() & W.S102.notna() & ((W.S101 + W.S102) > 0)].copy()
W['diff'] = W.S101 - W.S102
p = (W.S101 + W.S102) / 96
W['binom_var'] = 2 * 48 * p * (1 - p)
W.to_csv(OUT / '02_export_pairs.csv', index=False)


def pair_summary(w, label):
    d = w['diff']
    wil = stats.wilcoxon(d[d != 0]).pvalue
    say(f'{label}: pairs {len(w)}, mean {d.mean():.3f}, SD {d.std():.3f}, binomial SD sqrt(mean var) {np.sqrt(w.binom_var.mean()):.3f}, '
        f'Wilcoxon p {wil:.3f}, S101>S102 {int((d > 0).sum())}, equal {int((d == 0).sum())}, S102>S101 {int((d < 0).sum())}')


pair_summary(W, 'all exported participant-sessions')
Wn = W[~(W.participant.eq('14') | (W.session.astype(str) + '_' + W.participant).isin(
    ['2_7', '3_48', '6_5'] + [f'3_{x}' for x in (7, 8, 9, 16, 53, 60, 61, 62, 65)]))]
pair_summary(Wn, 'excluding decided exclusions')
for s in (2, 3, 4, 6):
    pair_summary(W[W.session == s], f'  session {s}')
# a less generous null: 48 presented is an assumption; use presented counts from the logs where known
PL = A.groupby(['session', 'participant', 'property', 'condition']).size().unstack()
say('logged-and-aligned presented per cell (S101/S102) distribution:', PL[101].value_counts().head(5).to_dict(), PL[102].value_counts().head(5).to_dict())
(OUT / '02_describe.txt').write_text('\n'.join(out), encoding='utf-8')
