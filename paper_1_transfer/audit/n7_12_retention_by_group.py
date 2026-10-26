"""N7, step 12: retention by mini-language x session (x property x condition) for the analysed sample.

Supports the Method's statement that retention was not perfectly even across groups and sessions,
and its figures for the largest imbalance: in the Mini-English group at Session 6, grammatical
retention fell below ungrammatical retention for every property (table T1, scope with_P20; the
Session-6 Mini-English rows are the same in both scopes, because participant 20 is in the
Mini-Norwegian group). Written on 17 September 2026 as ``gaps/gap5/01_tabulate.py``; moved here with
only its paths changed.

Inputs (read-only; built from primary files by the earlier steps)
  eeg_audit/cells/c04_cells.csv        one row per export stem (session x participant x property x condition):
                                       n_exported (.vhdr segments), importable (what the legacy importer yields),
                                       presented (distinct trials in the OpenSesame log; 48 by design when no log),
                                       exclusion flags, language (from the participant key)       [n7_09]
  eeg_audit/aligned/01_events.csv      one row per recorded S101/S102/S103 marker in the raw .vmrk, with the lag
                                       (samples from the property marker) and a key-matched 'exported' flag [n7_10]
Primary files read directly
  data/raw data/Participant IDs and session progress.csv    language per lab ID (to check the parity rule)

Definitions (same as n7_09)
  presented  = trials in the behavioural log (design value 48 where no usable log; flagged)
  exported   = segments in the Analyzer export
  analysed   = importable S101/S102 trials of participant-sessions not in the decided exclusions
               (nine 1 Hz Session-3 recordings; S2/7, S3/48, S6/5; participant 14)
  without P20 = additionally drops participant 20, whose rows 03_fit_brms_erp.R removes through drop_na()
               on the LHQ3 covariate

Writes (eeg_audit/retention/)
  01_T1_lang_sess_prop_cond.csv   pooled counts and cell summaries by language x session x property x condition
  01_T2_lang_sess_cond.csv        the same pooled over property, with S101 - S102 differences
  01_T3_precision.csv             per-participant trial-count precision factor sqrt(1/n101 + 1/n102) by group x session x property
  01_T4_recording_retention.csv   one row per recording: retention by scope
  01_T4b_group_tests.csv          Welch and Mann-Whitney tests of the language difference per session
  01_T5_funnel_all_sessions.csv   presented -> recorded -> lag 5 -> exported -> importable per recording
  01_T5_s4_decomposition.csv      the same for Session 4, S101/S102
  01_results.txt                  everything printed
Runtime: seconds.
"""
import os

import numpy as np
import pandas as pd
from scipy import stats

import audit_paths

HERE = str(audit_paths.out_dir("retention"))
CELLS = str(audit_paths.out_dir("cells") / "c04_cells.csv")
EVENTS = str(audit_paths.out_dir("aligned") / "01_events.csv")
KEY = str(audit_paths.participant_key())
OUT = []
pd.set_option("display.width", 250); pd.set_option("display.max_columns", 40); pd.set_option("display.max_rows", 500)


def say(*a):
    s = " ".join(str(x) for x in a)
    print(s, flush=True)
    OUT.append(s)


# ------------------------------------------------------------------ language
C = pd.read_csv(CELLS)
K = pd.read_csv(KEY, dtype=str)
K = K[K.participant_lab_ID.notna()].copy()
K["participant"] = K.participant_lab_ID.str.strip().astype(int)
keylang = K.set_index("participant").language.str.strip()
E = pd.read_csv(EVENTS, usecols=["session", "participant", "condition", "lag", "exported", "b_language"], low_memory=False)
loglang = E.dropna(subset=["b_language"]).groupby("participant").b_language.agg(lambda x: sorted(set(x)))
parts = sorted(C.participant.unique())
lang_rows = []
for p in parts:
    lang_rows.append(dict(participant=p, parity="Mini-English" if p % 2 == 1 else "Mini-Norwegian",
                          key=keylang.get(p, np.nan), log="|".join(loglang.get(p, [])) or np.nan))
LG = pd.DataFrame(lang_rows)
say("== Language assignment ==")
say("participants in c04_cells:", len(parts), "| missing from the key:", LG[LG.key.isna()].participant.tolist(),
    "| key != parity:", LG[LG.key.notna() & (LG.key != LG.parity)].participant.tolist(),
    "| log != parity:", LG[LG.log.notna() & (LG.log != LG.parity)].participant.tolist(),
    "| no log language:", LG[LG.log.isna()].participant.tolist())
say("c04_cells.csv rows with language NaN (key lookup failed):", int(C.language.isna().sum()),
    C[C.language.isna()].groupby(["session", "participant"]).size().to_dict())
say("-> language taken from the parity rule (as the repo's 02_extract_accuracy.R does); it agrees with the key for every keyed ID and with "
    "the logs for every participant except 14 (excluded from all analyses)")
C["language"] = np.where(C.participant % 2 == 1, "Mini-English", "Mini-Norwegian")
C["lang"] = C.language.str.replace("Mini-", "")

A = C[C.canonical & ~C.excluded].copy()
SCOPES = {"with_P20": A, "without_P20": A[A.participant != 20]}
say("\nP20 language:", LG.set_index("participant").loc[20].to_dict(),
    "| P20 analysed cells:", int((A.participant == 20).sum()), "importable:", int(A[A.participant == 20].importable.sum()),
    "| sessions:", sorted(A[A.participant == 20].session.unique()))


def pooled(df, by):
    df = df.assign(rec=df.session * 1000 + df.participant)
    g = df.groupby(by)
    t = g.agg(n_recordings=("rec", "nunique"), n_cells=("importable", "size"), presented=("presented", "sum"),
              exported=("n_exported", "sum"), importable=("importable", "sum"), cell_mean=("importable", "mean"),
              cell_sd=("importable", "std"), cell_min=("importable", "min"),
              cells_lt20=("importable", lambda x: int((x < 20).sum())),
              cells_design_presented=("presented_from_log", lambda x: int((~x).sum()))).reset_index()
    t["pct_exported"] = 100 * t.exported / t.presented
    t["pct_analysed"] = 100 * t.importable / t.presented
    return t


# ------------------------------------------------------------------ T1 / T2
T1, T2 = [], []
for sc, df in SCOPES.items():
    t1 = pooled(df, ["lang", "session", "property", "condition"]); t1.insert(0, "scope", sc); T1.append(t1)
    t2 = pooled(df, ["lang", "session", "condition"]); t2.insert(0, "scope", sc)
    t2b = pooled(df, ["lang", "session"]); t2b.insert(0, "scope", sc); t2b["condition"] = "S101+S102"
    t2c = pooled(df, ["lang", "condition"]); t2c.insert(0, "scope", sc); t2c["session"] = "all"
    t2d = pooled(df, ["session", "condition"]); t2d.insert(0, "scope", sc); t2d["lang"] = "both"
    T2 += [t2, t2b, t2c, t2d]
T1 = pd.concat(T1, ignore_index=True)
T2 = pd.concat(T2, ignore_index=True)
T1.round(3).to_csv(os.path.join(HERE, "01_T1_lang_sess_prop_cond.csv"), index=False)
T2.round(3).to_csv(os.path.join(HERE, "01_T2_lang_sess_cond.csv"), index=False)
cols = ["lang", "session", "property", "condition", "n_recordings", "presented", "exported", "importable", "pct_exported",
        "pct_analysed", "cell_mean", "cell_sd", "cell_min", "cells_lt20", "cells_design_presented"]
for sc in SCOPES:
    say(f"\n== T1 analysed S101/S102, {sc}: language x session x property x condition ==")
    say(T1[T1.scope == sc][cols].round(2).to_string(index=False))

for sc in SCOPES:
    t = T2[T2.scope == sc]
    say(f"\n== T2 {sc}: pooled over property ==")
    w = t[(t.condition == "S101+S102") & (t.session != "all") & (t.lang != "both")].copy()
    w["session"] = w.session.astype(int)
    piv = w.pivot_table(index="session", columns="lang", values=["pct_analysed", "pct_exported", "n_recordings", "cell_mean"])
    say("language x session (S101+S102):"); say(piv.round(2).to_string())
    c2 = t[t.condition.isin(["S101", "S102"]) & (t.session != "all") & (t.lang != "both")].copy()
    c2["session"] = c2.session.astype(int)
    p2 = c2.pivot_table(index=["session", "lang"], columns="condition", values="pct_analysed")
    p2["S101_minus_S102_pp"] = p2.S101 - p2.S102
    say("language x session x condition (% analysed of presented) and S101 - S102 difference in percentage points:")
    say(p2.round(2).to_string())
    d = p2.S101_minus_S102_pp.unstack("lang")
    d["ME_minus_MN_pp"] = d.English - d.Norwegian
    say("difference of differences (the condition x language contrast within session):"); say(d.round(2).to_string())
    c3 = t[(t.session == "all")]
    say("language x condition, all sessions:", c3[["lang", "condition", "presented", "importable", "pct_analysed"]].round(2).to_dict("records"))

# ------------------------------------------------------------------ T3 precision factor
say("\n== T3 per-participant trial-count precision: sqrt(1/n101 + 1/n102) per participant x session x property ==")
say("(the sampling SE of a participant's S102 - S101 mean difference scales with this factor for fixed trial-level SD;"
    " full design 48+48 gives %.4f)" % np.sqrt(2 / 48))
T3 = []
for sc, df in SCOPES.items():
    w = df.pivot_table(index=["lang", "session", "participant", "property"], columns="condition", values="importable").reset_index()
    w["zero"] = (w.S101 == 0) | (w.S102 == 0)
    w["f"] = np.where(w.zero, np.nan, np.sqrt(1 / w.S101.where(w.S101 > 0) + 1 / w.S102.where(w.S102 > 0)))
    g = w.groupby(["lang", "session", "property"]).agg(n_participants=("participant", "size"), zero_cells=("zero", "sum"),
                                                     f_mean=("f", "mean"), f_median=("f", "median"), f_max=("f", "max"),
                                                     n101_mean=("S101", "mean"), n102_mean=("S102", "mean")).reset_index()
    # participant-weighted precision of the group mean difference with trial-level variance only: sqrt(mean(f^2)/n)
    g["se_group_mean_trial_only"] = w.groupby(["lang", "session", "property"]).f.apply(lambda x: np.sqrt(np.nanmean(x ** 2) / x.notna().sum())).values
    g.insert(0, "scope", sc)
    T3.append(g)
T3 = pd.concat(T3, ignore_index=True)
T3.round(4).to_csv(os.path.join(HERE, "01_T3_precision.csv"), index=False)
for sc in SCOPES:
    t = T3[T3.scope == sc]
    p = t.pivot_table(index=["session", "property"], columns="lang", values=["f_mean", "n_participants"])
    p[("ratio", "E/N f_mean")] = p[("f_mean", "English")] / p[("f_mean", "Norwegian")]
    say(f"{sc}:"); say(p.round(4).to_string())

# ------------------------------------------------------------------ T4 recording-level retention and group tests per session
say("\n== T4 recording-level retention by session and language ==")
rec_an = A.groupby(["session", "participant", "lang"]).agg(pres=("presented", "sum"), imp=("importable", "sum"),
                                                           exp=("n_exported", "sum")).reset_index()
rec_an["pct_analysed"] = 100 * rec_an.imp / rec_an.pres
# the exports investigator's scope: all conditions, every exported recording (no exclusions), exported / presented
rec_all = C.groupby(["session", "participant", "lang"]).agg(pres=("presented", "sum"), exp=("n_exported", "sum"),
                                                            excluded=("excluded", "max")).reset_index()
rec_all["pct_exported_allcond"] = 100 * rec_all.exp / rec_all.pres
R = rec_all.merge(rec_an[["session", "participant", "pct_analysed", "imp"]], on=["session", "participant"], how="left")
R.round(3).to_csv(os.path.join(HERE, "01_T4_recording_retention.csv"), index=False)


def grouptest(df, val):
    a = df[df.lang == "English"][val].dropna(); b = df[df.lang == "Norwegian"][val].dropna()
    return dict(nE=len(a), meanE=a.mean(), medE=a.median(), sdE=a.std(), nN=len(b), meanN=b.mean(), medN=b.median(), sdN=b.std(),
                welch_p=stats.ttest_ind(a, b, equal_var=False).pvalue, mwu_p=stats.mannwhitneyu(a, b).pvalue)


rows = []
specs = [("exported/presented, all conditions, all exported recordings (investigator scope)", R, "pct_exported_allcond"),
         ("analysed S101+S102 / presented, with P20", R[R.pct_analysed.notna()], "pct_analysed"),
         ("analysed S101+S102 / presented, without P20", R[R.pct_analysed.notna() & (R.participant != 20)], "pct_analysed")]
for label, df, val in specs:
    say(f"-- {label}")
    for s, sub in df.groupby("session"):
        r = grouptest(sub, val); r.update(scope=label, session=s); rows.append(r)
        say(f"  S{s}: ME n={r['nE']} mean={r['meanE']:.2f} median={r['medE']:.2f} SD={r['sdE']:.2f} | MN n={r['nN']} mean={r['meanN']:.2f} "
            f"median={r['medN']:.2f} SD={r['sdN']:.2f} | Welch p={r['welch_p']:.3f} MWU p={r['mwu_p']:.3f}")
    r = grouptest(df, val)
    say(f"  all sessions (recordings not independent): ME mean={r['meanE']:.2f} MN mean={r['meanN']:.2f} Welch p={r['welch_p']:.3f}")
pd.DataFrame(rows).round(4).to_csv(os.path.join(HERE, "01_T4b_group_tests.csv"), index=False)

say("\n-- Session 4 leave-one-out: Welch p after dropping each single recording (lowest five p-maximising drops shown)")
for label, df, val in specs:
    s4 = df[df.session == 4]
    base = grouptest(s4, val)["welch_p"]
    loo = []
    for p in s4.participant:
        r = grouptest(s4[s4.participant != p], val)
        loo.append((p, s4.loc[s4.participant == p, "lang"].iloc[0], round(float(s4.loc[s4.participant == p, val].iloc[0]), 2), r["welch_p"],
                    r["meanE"] - r["meanN"]))
    loo = pd.DataFrame(loo, columns=["participant", "lang", "retention", "welch_p_without", "diff_E_minus_N_without"]).sort_values("welch_p_without", ascending=False)
    both = grouptest(s4[~s4.participant.isin([9, 33])], val)
    say(f"  {label}: base p={base:.3f}; drops giving p>.05: {int((loo.welch_p_without > .05).sum())} of {len(loo)}; "
        f"drop S4/9 and S4/33 together -> ME mean {both['meanE']:.2f}, MN mean {both['meanN']:.2f}, Welch p={both['welch_p']:.3f}, MWU p={both['mwu_p']:.3f}")
    say(loo.head(6).round(4).to_string(index=False))
    lows = s4.sort_values(val).head(8)[["participant", "lang", val]]
    say("  lowest eight recordings:", lows.round(2).to_dict("records"))

# ------------------------------------------------------------------ T5 Session 4 funnel per recording (analysed S101/S102)
say("\n== T5 Session 4 funnel, analysed S101/S102: presented -> recorded -> lag 5 -> exported (key-matched) -> importable ==")
E12 = E[E.condition.isin([101, 102])]
ev = E12.groupby(["session", "participant"]).agg(recorded=("lag", "size"), lag5=("lag", lambda x: int((x == 5).sum())),
                                                 lag6=("lag", lambda x: int((x == 6).sum())),
                                                 lag_other=("lag", lambda x: int((x.notna() & ~x.isin([5, 6])).sum())),
                                                 exported_matched=("exported", "sum")).reset_index()
F = rec_an.merge(ev, on=["session", "participant"], how="left")
F["pct_lag6_of_recorded"] = 100 * F.lag6 / F.recorded
F["lag5_not_imported"] = F.lag5 - F.imp
F["not_recorded"] = F.pres - F.recorded
F.round(3).to_csv(os.path.join(HERE, "01_T5_funnel_all_sessions.csv"), index=False)
F4 = F[F.session == 4].sort_values("pct_analysed")
say(F4[["participant", "lang", "pres", "recorded", "not_recorded", "lag5", "lag6", "lag_other", "exported_matched", "imp",
        "lag5_not_imported", "pct_lag6_of_recorded", "pct_analysed"]].round(2).to_string(index=False))
F4.round(3).to_csv(os.path.join(HERE, "01_T5_s4_decomposition.csv"), index=False)
say("\nfunnel pooled by session x language (analysed S101/S102):")
G = F.groupby(["session", "lang"])[["pres", "recorded", "lag5", "lag6", "lag_other", "exported_matched", "imp"]].sum()
G["pct_recorded"] = 100 * G.recorded / G.pres
G["pct_lag5_of_recorded"] = 100 * G.lag5 / G.recorded
G["pct_imp_of_lag5"] = 100 * G.imp / G.lag5
G["pct_imp_of_presented"] = 100 * G.imp / G.pres
say(G.round(2).to_string())
say("\nrecording-level lag-6 share by session x language (mean, median; recordings):")
say(F.groupby(["session", "lang"]).pct_lag6_of_recorded.agg(["size", "mean", "median", "min", "max"]).round(2).to_string())
for s, sub in F.groupby("session"):
    a = sub[sub.lang == "English"].pct_lag6_of_recorded; b = sub[sub.lang == "Norwegian"].pct_lag6_of_recorded
    say(f"  S{s} lag-6 share ME vs MN: Welch p={stats.ttest_ind(a, b, equal_var=False).pvalue:.3f} MWU p={stats.mannwhitneyu(a, b).pvalue:.3f}")

with open(os.path.join(HERE, "01_results.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(OUT))
