"""N7, step 6: does trial loss depend on grammaticality, trial position, accuracy or response time?

Supports the Method's statements that, within recordings, loss was unrelated to grammaticality,
response accuracy and item, and only weakly and inconsistently related to response time and trial
position, and the odds ratio it quotes for losing an ungrammatical rather than a grammatical trial
(the Mantel-Haenszel odds ratio pooled over sessions, strata = recording x property, written to
03_pooled.csv). Written on 17 September 2026 as ``gaps/gap6/03_tests.py``; moved here with only its
paths changed and the pooled odds ratios, which it printed, also written to a table.

A. Session 2, analysed recordings: is loss different for S102 than for S101 within a recording?
   Outcomes: lost by any route (known status, not exported), lost to the lag rule (lag != 5), removed by hand
   (lag 5, known, not exported). Tests: Mantel-Haenszel OR with Cochran-Mantel-Haenszel p (strata = recording),
   logistic regression with recording fixed effects (likelihood-ratio p), the same adjusted for trial position,
   and a within-recording permutation of the condition labels (10,000 draws). Reconciled with the earlier
   three-level result, with all Session-2 recordings, and set beside the same S101-vs-S102 test in Sessions 3,
   4 and 6 for a Holm correction over the four sessions, and pooled over the four sessions.
B. Trial position within condition, per session (analysed recordings, events aligned to the log, known status):
   lost ~ trial position (fraction of the session's experiment trials) with recording fixed effects; MH OR for
   second vs first half; within-recording permutation of the loss labels (2,000 draws) for the covariance with
   position; condition x position interaction; the same without the five recordings whose lag-6 share steps
   down mid-session; the same by loss route.
C. Lost vs kept within condition, per session, on accuracy and within-recording standardised log RT.
D. How much retention re-weights position: mean trial position of recorded vs exported events per condition.

Reads   eeg_audit/independence/02_table.csv and 01_unrecorded.csv
Writes  eeg_audit/independence/03_results.txt, 03_session2.csv, 03_family.csv, 03_pooled.csv,
        03_position.csv, 03_interaction.csv, 03_acc_rt.csv, 03_reweight.csv
Runtime: about 15 minutes (the permutations dominate; the seed is fixed).
"""

import numpy as np
import pandas as pd
import statsmodels.api as sm
from scipy.stats import chi2, wilcoxon, binomtest
from statsmodels.stats.contingency_tables import StratifiedTable
from statsmodels.stats.multitest import multipletests

import audit_paths

OUT = audit_paths.out_dir('independence')
RNG = np.random.default_rng(20260917)
STEP = {'S6_22', 'S4_23', 'S4_21', 'S4_47', 'S4_9'}
lines = []


def say(*a):
    s = ' '.join(str(x) for x in a)
    print(s, flush=True)
    lines.append(s)


d = pd.read_csv(OUT / '02_table.csv', dtype={'participant': str}, low_memory=False)
d['viol'] = (d.condition == 102).astype(int)
d['rec_prop'] = d.recording + ':P' + d.prop.astype('Int64').astype(str)


# ---------------------------------------------------------------- helpers
def mh(df, y, x, strata='recording'):
    """MH OR for y ~ binary x, stratified. Returns dict."""
    tabs = []
    for _, g in df.groupby(strata):
        a = g[g[x] == 1][y]
        b = g[g[x] == 0][y]
        t = np.array([[a.sum(), len(a) - a.sum()], [b.sum(), len(b) - b.sum()]], dtype=float)
        if t.sum(axis=1).min() > 0 and t.sum(axis=0).min() > 0:
            tabs.append(t)
    if not tabs:
        return dict(mh_or=np.nan, mh_lo=np.nan, mh_hi=np.nan, cmh_p=np.nan, mh_strata=0)
    st = StratifiedTable(tabs)
    lo, hi = st.oddsratio_pooled_confint()
    return dict(mh_or=st.oddsratio_pooled, mh_lo=lo, mh_hi=hi, cmh_p=st.test_null_odds().pvalue, mh_strata=len(tabs))


def fe_logit(df, y, xcols, test, strata='recording'):
    """Logistic regression with stratum fixed effects; LR test of the `test` columns. Uninformative strata dropped."""
    D = df.dropna(subset=[y] + xcols)
    m = D.groupby(strata)[y].transform('mean')
    D = D[(m > 0) & (m < 1)]
    if D.empty:
        return dict(n=0)
    S = pd.get_dummies(D[strata], dtype=float)
    fam = sm.families.Binomial()
    X1 = pd.concat([D[xcols].astype(float), S], axis=1)
    m1 = sm.GLM(D[y].astype(float), X1, family=fam).fit()
    keep = [c for c in xcols if c not in test]
    X0 = pd.concat([D[keep].astype(float), S], axis=1)
    m0 = sm.GLM(D[y].astype(float), X0, family=fam).fit()
    lr = m0.deviance - m1.deviance
    out = dict(n=len(D), strata=S.shape[1], lr=lr, lr_df=len(test), lr_p=chi2.sf(lr, len(test)))
    for c in xcols:
        b, se = m1.params[c], m1.bse[c]
        out[f'{c}_or'] = np.exp(b)
        out[f'{c}_lo'] = np.exp(b - 1.96 * se)
        out[f'{c}_hi'] = np.exp(b + 1.96 * se)
        out[f'{c}_p'] = m1.pvalues[c]
    return out


def perm_codes(groups):
    codes, _ = pd.factorize(groups)
    base = np.lexsort((np.arange(len(codes)), codes))
    return codes, base


def within_perm(values, codes, base):
    order = np.lexsort((RNG.random(len(codes)), codes))
    out = np.empty_like(values)
    out[base] = values[order]
    return out


def perm_condition(df, y, nperm=10000, strata='recording'):
    """Permute the S102 label within strata; statistic = lost count among S102."""
    D = df.dropna(subset=[y]).sort_values([strata]).reset_index(drop=True)
    codes, base = perm_codes(D[strata])
    lab = D.viol.to_numpy()
    yy = D[y].to_numpy()
    obs = float(np.sum(yy * lab))
    null = np.array([np.sum(yy * within_perm(lab, codes, base)) for _ in range(nperm)])
    dev = abs(obs - null.mean())
    p = (1 + np.sum(np.abs(null - null.mean()) >= dev - 1e-9)) / (nperm + 1)
    return dict(perm_obs_lost_s102=obs, perm_null_mean=null.mean(), perm_p=p)


def perm_position(df, y, nperm=2000, strata='recording'):
    D = df.dropna(subset=[y, 'trial_prop']).sort_values([strata]).reset_index(drop=True)
    codes, base = perm_codes(D[strata])
    tp = D.trial_prop.to_numpy() - D.groupby(strata).trial_prop.transform('mean').to_numpy()
    yy = D[y].to_numpy()
    obs = float(np.sum(yy * tp))
    null = np.array([np.sum(within_perm(yy, codes, base) * tp) for _ in range(nperm)])
    p = (1 + np.sum(np.abs(null - null.mean()) >= abs(obs - null.mean()) - 1e-12)) / (nperm + 1)
    return dict(perm_cov=obs, perm_cov_z=(obs - null.mean()) / null.std(), perm_p=p)


def fmt(x, k=3):
    return '' if pd.isna(x) else f'{x:.{k}f}'


# ---------------------------------------------------------------- A. Session 2
say('A. SESSION 2: S101 vs S102 loss within recording')
s2 = d[d.session == 2]
rec2 = s2.groupby('recording').agg(eligible=('eligible', 'first'), n=('condition', 'size'), known=('known', 'mean'),
                                   aligned=('aligned', 'mean'))
say(f'Session-2 recordings with recorded S10x events: {len(rec2)}; eligible (analysed): {int(rec2.eligible.sum())}; '
    f'not eligible: {sorted(rec2.index[rec2.eligible == 0])}')
say(f'  eligible recordings with any unknown export status: {sorted(rec2.index[(rec2.eligible == 1) & (rec2.known < 1)])}')
un = pd.read_csv(OUT / '01_unrecorded.csv', dtype={'participant': str}) if (OUT / '01_unrecorded.csv').exists() else pd.DataFrame()
un2 = un[(un.session == 2)] if len(un) else un
say(f'  Session-2 logged target trials with no aligned recorded event: {len(un2)}; by participant: '
    f'{un2.participant.value_counts().to_dict() if len(un2) else {}}')

A = s2[(s2.eligible == 1) & s2.condition.isin([101, 102]) & (s2.known == 1)].copy()
say(f'analysed set: {len(A)} S101/S102 events, {A.recording.nunique()} recordings')
cnt = A.groupby('condition').agg(recorded=('lost', 'size'), exported=('exported', 'sum'), lost=('lost', 'sum'),
                                 lag_not5=('lagrule_lost', 'sum'), hand_removed=('hand_removed', 'sum'))
cnt['lost_share'] = cnt.lost / cnt.recorded
cnt['lagrule_share'] = cnt.lag_not5 / cnt.recorded
cnt['hand_share_of_lag5'] = cnt.hand_removed / (cnt.recorded - cnt.lag_not5)
say(cnt.round(4).to_string())
pres = A[A.aligned == 1].groupby('condition').size()
say(f'  aligned to the log (presented and recorded): {pres.to_dict()}; unrecorded logged S101/S102 in these recordings: '
    f'{int(un2[un2.participant.isin(A.participant.unique()) & un2.grammaticality_trigger.isin([101, 102])].shape[0]) if len(un2) else 0}')

rows = []
for y, lab in (('lost', 'lost, any route'), ('lagrule_lost', 'lost to the lag rule (lag != 5)'),
               ('hand_removed', 'removed by hand (among lag-5)')):
    r = dict(set='Session 2, analysed recordings', outcome=lab)
    sub = A.dropna(subset=[y])
    r['n'] = len(sub)
    r['share_s101'] = sub[sub.condition == 101][y].mean()
    r['share_s102'] = sub[sub.condition == 102][y].mean()
    r.update(mh(sub, y, 'viol'))
    f = fe_logit(sub, y, ['viol'], ['viol'])
    r.update(fe_or=f.get('viol_or'), fe_lo=f.get('viol_lo'), fe_hi=f.get('viol_hi'), fe_lr_p=f.get('lr_p'), fe_strata=f.get('strata'))
    fa = fe_logit(sub[sub.aligned == 1], y, ['viol', 'trial_prop'], ['viol'])
    r.update(fe_adj_or=fa.get('viol_or'), fe_adj_lr_p=fa.get('lr_p'), fe_adj_pos_or=fa.get('trial_prop_or'), fe_adj_pos_p=fa.get('trial_prop_p'))
    r.update(perm_condition(sub, y))
    rows.append(r)

# reconciliation: all Session-2 recordings; three-level condition
Aall = s2[s2.condition.isin([101, 102]) & (s2.known == 1)]
r = dict(set='Session 2, all recordings', outcome='lost, any route', n=len(Aall),
         share_s101=Aall[Aall.condition == 101].lost.mean(), share_s102=Aall[Aall.condition == 102].lost.mean())
r.update(mh(Aall, 'lost', 'viol'))
f = fe_logit(Aall, 'lost', ['viol'], ['viol'])
r.update(fe_or=f.get('viol_or'), fe_lo=f.get('viol_lo'), fe_hi=f.get('viol_hi'), fe_lr_p=f.get('lr_p'), fe_strata=f.get('strata'))
r.update(perm_condition(Aall, 'lost'))
rows.append(r)
for eligible_only in (True, False):
    T = s2[(s2.known == 1) & ((s2.eligible == 1) if eligible_only else True)].copy()
    T['c102'] = (T.condition == 102).astype(int)
    T['c103'] = (T.condition == 103).astype(int)
    for y in ('lost', 'lagrule_lost'):
        f = fe_logit(T, y, ['c102', 'c103'], ['c102', 'c103'])
        rows.append(dict(set=f"Session 2, {'analysed' if eligible_only else 'all'} recordings, three conditions",
                         outcome=y, n=f['n'], fe_lr_p=f['lr_p'], fe_or=f['c102_or'], fe_lo=f['c102_lo'], fe_hi=f['c102_hi'],
                         note=f"S102 vs S101 OR {f['c102_or']:.3f} p {f['c102_p']:.3f}; S103 vs S101 OR {f['c103_or']:.3f} p {f['c103_p']:.3f}; "
                              f"shares 101/102/103 {T[T.condition == 101][y].mean():.4f}/{T[T.condition == 102][y].mean():.4f}/{T[T.condition == 103][y].mean():.4f}"))
    # all recorded lag 5/6 (no export status needed), as in the earlier chi-square
    L = s2[(s2.eligible == 1) if eligible_only else (s2.session == 2)]
    L = L[L.lag.isin([5, 6])].copy()
    L['c102'] = (L.condition == 102).astype(int)
    L['c103'] = (L.condition == 103).astype(int)
    f = fe_logit(L, 'lagrule_lost', ['c102', 'c103'], ['c102', 'c103'])
    tab = pd.crosstab(L.condition, L.lagrule_lost)
    from scipy.stats import chi2_contingency
    c2 = chi2_contingency(tab)
    rows.append(dict(set=f"Session 2, {'analysed' if eligible_only else 'all'} recordings, lag 5/6 only, three conditions",
                     outcome='lag 6', n=len(L), fe_lr_p=f['lr_p'],
                     note=f'pooled chi2(2) {c2[0]:.2f} p {c2[1]:.4f}; FE S102 vs S101 OR {f["c102_or"]:.3f} p {f["c102_p"]:.3f}; '
                          f'S103 vs S101 OR {f["c103_or"]:.3f} p {f["c103_p"]:.3f}'))
s2tab = pd.DataFrame(rows)
s2tab.to_csv(OUT / '03_session2.csv', index=False)
say(s2tab.drop(columns=['note'], errors='ignore').round(4).to_string(index=False))
for _, r in s2tab[s2tab.get('note', pd.Series(dtype=str)).notna()].iterrows():
    say(f"  {r['set']} [{r['outcome']}]: LR p {r['fe_lr_p']:.4f}; {r['note']}")

# per-recording exported count difference in analysed Session 2
pc = A.groupby(['recording', 'condition']).exported.sum().unstack()
diff = (pc[101] - pc[102])
w = wilcoxon(diff[diff != 0])
say(f'per-recording exported S101 - S102 (analysed S2): recordings {len(diff)}, mean {diff.mean():.3f}, median {diff.median():.1f}, '
    f'S101>S102 {int((diff > 0).sum())}, equal {int((diff == 0).sum())}, S102>S101 {int((diff < 0).sum())}; '
    f'Wilcoxon p {w.pvalue:.4f}; sign test p {binomtest(int((diff > 0).sum()), int((diff != 0).sum())).pvalue:.4f}')
say(f'  total exported S101 {int(pc[101].sum())}, S102 {int(pc[102].sum())}; mean per recording {pc[101].mean():.2f} vs {pc[102].mean():.2f}')

# ---------------------------------------------------------------- A-family: same test in every session
say('\nA2. THE SAME S101-vs-S102 TEST IN EACH SESSION (analysed recordings, known status; strata = recording x property)')
fam = []
for s in (2, 3, 4, 6):
    X = d[(d.session == s) & (d.eligible == 1) & d.condition.isin([101, 102]) & (d.known == 1)]
    for y in ('lost', 'lagrule_lost', 'hand_removed'):
        sub = X.dropna(subset=[y])
        r = dict(session=s, outcome=y, n=len(sub), recordings=sub.recording.nunique(),
                 share_s101=sub[sub.condition == 101][y].mean(), share_s102=sub[sub.condition == 102][y].mean())
        r.update(mh(sub, y, 'viol', strata='rec_prop'))
        if y != 'hand_removed':
            f = fe_logit(sub, y, ['viol'], ['viol'], strata='rec_prop')
            r.update(fe_or=f['viol_or'], fe_lo=f['viol_lo'], fe_hi=f['viol_hi'], fe_lr_p=f['lr_p'])
        pcs = sub.groupby(['rec_prop', 'condition']).exported.sum().unstack()
        if y == 'lost' and pcs.shape[1] == 2:
            dd = (pcs[101] - pcs[102]).dropna()
            r.update(count_pairs=len(dd), count_mean_diff=dd.mean(), count_s101_more=int((dd > 0).sum()),
                     count_s102_more=int((dd < 0).sum()), count_wilcoxon_p=wilcoxon(dd[dd != 0]).pvalue)
        fam.append(r)
fam = pd.DataFrame(fam)
for y in ('lost', 'lagrule_lost', 'hand_removed'):
    ix = fam.outcome == y
    fam.loc[ix, 'cmh_p_holm4'] = multipletests(fam.loc[ix, 'cmh_p'], method='holm')[1]
    if y == 'lost':
        fam.loc[ix, 'count_wilcoxon_p_holm4'] = multipletests(fam.loc[ix, 'count_wilcoxon_p'], method='holm')[1]
ix = fam.outcome.isin(['lost', 'lagrule_lost', 'hand_removed'])
fam.loc[ix, 'cmh_p_holm12'] = multipletests(fam.loc[ix, 'cmh_p'], method='holm')[1]
fam.to_csv(OUT / '03_family.csv', index=False)
say(fam.round(4).to_string(index=False))
# pooled over sessions
P = d[(d.eligible == 1) & d.condition.isin([101, 102]) & (d.known == 1)]
pooled = []
for y in ('lost', 'lagrule_lost', 'hand_removed'):
    sub = P.dropna(subset=[y])
    r = mh(sub, y, 'viol', strata='rec_prop')
    say(f'  all sessions pooled [{y}]: MH OR {r["mh_or"]:.3f} [{r["mh_lo"]:.3f}, {r["mh_hi"]:.3f}] p {r["cmh_p"]:.4f} strata {r["mh_strata"]}')
    pooled.append(dict(outcome=y, n=len(sub), recordings=sub.recording.nunique(), **r))
pd.DataFrame(pooled).to_csv(OUT / '03_pooled.csv', index=False)

# ---------------------------------------------------------------- B. trial position within condition
say('\nB. LOST vs KEPT ON TRIAL POSITION, WITHIN CONDITION, PER SESSION (analysed recordings, aligned, known status)')
B = d[(d.eligible == 1) & (d.known == 1) & (d.aligned == 1) & d.trial_prop.notna()].copy()
pos = []
for scope, Bs in (('all analysed recordings', B), ('without the five step recordings', B[~B.recording.isin(STEP)])):
    for s in (2, 3, 4, 6, 'all'):
        for c in (101, 102, 103):
            X = Bs[(Bs.condition == c) & ((Bs.session == s) if s != 'all' else True)]
            for y in ('lost', 'lagrule_lost', 'hand_removed'):
                sub = X.dropna(subset=[y])
                if sub.empty:
                    continue
                r = dict(scope=scope, session=s, condition=c, outcome=y, n=len(sub), recordings=sub.recording.nunique(),
                         lost_n=int(sub[y].sum()), share_first_half=sub[sub.second_half == 0][y].mean(),
                         share_second_half=sub[sub.second_half == 1][y].mean())
                r.update(mh(sub, y, 'second_half'))
                if y != 'hand_removed':
                    f = fe_logit(sub, y, ['trial_prop'], ['trial_prop'])
                    r.update(pos_or_per_session=f.get('trial_prop_or'), pos_lo=f.get('trial_prop_lo'),
                             pos_hi=f.get('trial_prop_hi'), pos_lr_p=f.get('lr_p'))
                if scope == 'all analysed recordings' and y == 'lost' and s != 'all':
                    r.update(perm_position(sub, y))
                pos.append(r)
pos = pd.DataFrame(pos)
# Holm over the eight primary tests: sessions 2/3/4/6 x S101/S102, any-route loss, FE LR p
prim = (pos.scope == 'all analysed recordings') & (pos.outcome == 'lost') & pos.condition.isin([101, 102]) & (pos.session != 'all')
pos.loc[prim, 'pos_lr_p_holm8'] = multipletests(pos.loc[prim, 'pos_lr_p'], method='holm')[1]
pos.loc[prim, 'half_cmh_p_holm8'] = multipletests(pos.loc[prim, 'cmh_p'], method='holm')[1]
pos.to_csv(OUT / '03_position.csv', index=False)
cols = ['scope', 'session', 'condition', 'outcome', 'n', 'recordings', 'lost_n', 'share_first_half', 'share_second_half',
        'mh_or', 'cmh_p', 'pos_or_per_session', 'pos_lo', 'pos_hi', 'pos_lr_p', 'perm_cov_z', 'perm_p', 'pos_lr_p_holm8', 'half_cmh_p_holm8']
for y in ('lost', 'lagrule_lost', 'hand_removed'):
    say(f'\n  outcome = {y}')
    say(pos[pos.outcome == y][[c for c in cols if c in pos]].round(4).to_string(index=False))

# condition x position interaction (does the position gradient differ between S101 and S102?)
say('\n  condition x trial-position interaction, S101/S102, lost by any route (recording FE)')
inter = []
for s in (2, 3, 4, 6, 'all'):
    X = B[B.condition.isin([101, 102]) & ((B.session == s) if s != 'all' else True)].copy()
    X['viol_x_pos'] = X.viol * (X.trial_prop - 0.5)
    X['pos_c'] = X.trial_prop - 0.5
    f = fe_logit(X, 'lost', ['viol', 'pos_c', 'viol_x_pos'], ['viol_x_pos'])
    inter.append(dict(session=s, n=f['n'], viol_or_mid=f['viol_or'], viol_p=f['viol_p'], pos_or=f['pos_c_or'],
                      interaction_ratio=f['viol_x_pos_or'], int_lo=f['viol_x_pos_lo'], int_hi=f['viol_x_pos_hi'], int_lr_p=f['lr_p']))
inter = pd.DataFrame(inter)
say(inter.round(4).to_string(index=False))
inter.to_csv(OUT / '03_interaction.csv', index=False)

# ---------------------------------------------------------------- C. accuracy and RT within condition
say('\nC. LOST vs KEPT ON ACCURACY AND LOG RT (z within recording), WITHIN CONDITION, PER SESSION (lost by any route)')
ar = []
for s in (2, 3, 4, 6, 'all'):
    for c in (101, 102):
        X = B[(B.condition == c) & ((B.session == s) if s != 'all' else True)]
        for x in ('correct', 'rt_z'):
            f = fe_logit(X, 'lost', [x], [x])
            ar.append(dict(session=s, condition=c, predictor=x, n=f['n'], or_=f[f'{x}_or'], lo=f[f'{x}_lo'], hi=f[f'{x}_hi'],
                           lr_p=f['lr_p']))
ar = pd.DataFrame(ar)
for x in ('correct', 'rt_z'):
    ix = (ar.predictor == x) & (ar.session != 'all')
    ar.loc[ix, 'lr_p_holm8'] = multipletests(ar.loc[ix, 'lr_p'], method='holm')[1]
ar.to_csv(OUT / '03_acc_rt.csv', index=False)
say(ar.round(4).to_string(index=False))

# hand removal by half and by accuracy, per session (S101/S102, lag-5 events)
say('\n  hand removal (lag-5 S101/S102 events): second vs first half and correct vs incorrect, per session (MH, strata = recording)')
for s in (2, 3, 4, 6, 'all'):
    X = B[B.condition.isin([101, 102]) & ((B.session == s) if s != 'all' else True)].dropna(subset=['hand_removed'])
    h = mh(X, 'hand_removed', 'second_half')
    X2 = X.dropna(subset=['correct']).assign(correct=lambda z: z.correct.astype(int))
    a = mh(X2, 'hand_removed', 'correct')
    say(f'  session {s}: removed {int(X.hand_removed.sum())} of {len(X)}; half: share {X[X.second_half == 0].hand_removed.mean():.4f} -> '
        f'{X[X.second_half == 1].hand_removed.mean():.4f}, OR {h["mh_or"]:.3f} [{h["mh_lo"]:.3f}, {h["mh_hi"]:.3f}] p {h["cmh_p"]:.4f}; '
        f'correct: OR {a["mh_or"]:.3f} [{a["mh_lo"]:.3f}, {a["mh_hi"]:.3f}] p {a["cmh_p"]:.4f}')

# ---------------------------------------------------------------- D. re-weighting of position
say('\nD. MEAN TRIAL POSITION (fraction of session) OF RECORDED vs EXPORTED S101/S102 EVENTS (analysed, aligned, known)')
rw = []
for s in (2, 3, 4, 6):
    X = B[(B.session == s) & B.condition.isin([101, 102])]
    ntr = X.groupby('recording').n_trials.first().mean()
    per = X.groupby(['recording', 'condition']).apply(
        lambda g: pd.Series(dict(all=g.trial_prop.mean(), exp=g[g.exported == 1].trial_prop.mean(),
                                 exp_second=g[g.exported == 1].second_half.mean(), all_second=g.second_half.mean())),
        include_groups=False).reset_index()
    per['shift'] = per.exp - per['all']
    wide = per.pivot(index='recording', columns='condition', values='shift').dropna()
    dd = wide[101] - wide[102]
    boots = [dd.sample(len(dd), replace=True, random_state=int(RNG.integers(1e9))).mean() for _ in range(2000)]
    for c in (101, 102):
        q = per[per.condition == c]
        rw.append(dict(session=s, condition=c, recordings=len(q), mean_trials=ntr, pos_recorded=q['all'].mean(),
                       pos_exported=q.exp.mean(), shift=q['shift'].mean(), shift_trials=q['shift'].mean() * ntr,
                       second_half_share_recorded=q.all_second.mean(), second_half_share_exported=q.exp_second.mean()))
    rw.append(dict(session=s, condition='101-102', recordings=len(dd), mean_trials=ntr, shift=dd.mean(),
                   shift_trials=dd.mean() * ntr, shift_lo=np.quantile(boots, .025), shift_hi=np.quantile(boots, .975)))
rw = pd.DataFrame(rw)
rw.to_csv(OUT / '03_reweight.csv', index=False)
say(rw.round(4).to_string(index=False))

(OUT / '03_results.txt').write_text('\n'.join(lines), encoding='utf-8')
