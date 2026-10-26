"""N7, step 9: the cell table: exported, importable and presented trials per export stem.

Third step of the cell table (n7_07 to n7_09), read by n7_10 and n7_13. It supports the analysed
counts of the N7 report (26,109 of 39,840 presented grammatical and ungrammatical trials in the
194 analysed participant-sessions) and the per-cell retention the Method reports by group and
session. Written on 17 September 2026 as ``verify/C04_recompute/03_combine.py``; moved here with
only its paths changed.

Inputs (from n7_07 and n7_08): eeg_audit/cells/export_stems_S{2,3,4,6}.csv, presented_cells.csv,
presented_files.csv
Primary/reference inputs (read-only):
  Participant key                  data/raw data/Participant IDs and session progress.csv
  Exclusion lists                  paper_1_transfer/scripts/_config.R (parsed): the legacy exports of
                                   these participant-sessions enter no analysis
  Legacy retained-trial table      data/EEG_trial_count_per_condition.csv   (only to test the repo artefact claims)
  Repo artefacts                   paper_1_transfer/results/_erp_trial_retention.csv, _misfiltered_share.csv
                                   (printed for comparison only; they have been regenerated since
                                   17 September, so that part of the log differs from the archived one)
Definitions
  exported    = segments in the export (.vhdr DataPoints / SegmentDataPoints), cross-checked against
                the .vmrk New Segment count and the .txt value count / 600
  importable  = what merge_trialbytrial_EEG_data() -> import_trialbytrial_EEG_data() yields: 0 if the
                stem lacks .txt or .vmrk (inner_join by path), otherwise n_distinct(sentence code), which
                is also the unit the repo pipeline aggregates on (sentence_marker)
  presented   = distinct experimental trials in the participant-session's OpenSesame log (label-based
                property, grammaticality trigger); where no usable log exists, the design value 48 (flagged)
  analysed    = importable S101/S102 trials of participant-sessions not in the decided exclusions
Writes: eeg_audit/cells/c04_cells.csv, c04_results.txt
Runtime: seconds.
"""
import os
import re

import numpy as np
import pandas as pd

import audit_paths

HERE = str(audit_paths.out_dir("cells"))
KEY = str(audit_paths.participant_key())
LEGACY = str(audit_paths.data_root() / "EEG_trial_count_per_condition.csv")
CONFIG = str(audit_paths.CODE_ROOT / "paper_1_transfer" / "scripts" / "_config.R")
REPO_RET = str(audit_paths.results_dir() / "_erp_trial_retention.csv")
REPO_MIS = str(audit_paths.results_dir() / "_misfiltered_share.csv")
out_lines = []


def say(*a):
    s = " ".join(str(x) for x in a)
    print(s)
    out_lines.append(s)


pd.set_option("display.width", 250); pd.set_option("display.max_columns", 40); pd.set_option("display.max_rows", 500)

# ------------------------------------------------------------------ exclusions from _config.R
cfg = open(CONFIG, encoding="utf-8").read()


def df_block(name):
    m = re.search(name + r"\s*<-\s*data\.frame\((.*?)\n\)", cfg, re.S)
    body = m.group(1)
    ids = [int(x) for x in re.findall(r"(\d+)L", re.search(r"participant_lab_ID\s*=\s*(c\([^)]*\)|\d+L)", body).group(1))]
    sm = re.search(r"session\s*=\s*(c\([^)]*\)|\d+L)", body)
    sess = [int(x) for x in re.findall(r"(\d+)L", sm.group(1))] if sm else None
    return ids, sess


mis_ids, mis_s = df_block("LES_P1_MISFILTERED")
inv_ids, inv_s = df_block("LES_P1_INVALID_EXPORTS")
dev_ids, _ = df_block("LES_P1_PROTOCOL_DEVIATION")
MIS = {(p, mis_s[0] if len(mis_s) == 1 else s) for p, s in zip(mis_ids, mis_s * len(mis_ids) if len(mis_s) == 1 else mis_s)}
INV = set(zip(inv_ids, inv_s))
DEV = set(dev_ids)
say("_config.R exclusions: misfiltered", sorted(MIS), "| invalid", sorted(INV), "| deviation", sorted(DEV))

# ------------------------------------------------------------------ exports
E = pd.concat([pd.read_csv(os.path.join(HERE, f"export_stems_S{s}.csv")) for s in (2, 3, 4, 6)], ignore_index=True)
say("\n== Exports ==")
say("stems:", len(E), "| participant-sessions:", E.groupby(["session", "participant"]).ngroups,
    "| pid strings with leading zero:", int((E.pid_str.astype(str) != E.participant.astype(str)).sum()))
say("stems lacking txt / vhdr / vmrk:", int((E.has_txt == 0).sum()), int((E.has_vhdr == 0).sum()), int((E.has_vmrk == 0).sum()))
say(E.loc[(E.has_txt == 0) | (E.has_vhdr == 0) | (E.has_vmrk == 0), ["session", "participant", "property", "condition", "has_txt", "has_vhdr", "has_vmrk", "n_seg_vhdr"]].to_string(index=False))
E["n_exported"] = E["n_seg_vhdr"]
chk = E[E.has_vmrk == 1]
say("vhdr segments integer:", bool((E.n_seg_vhdr % 1 == 0).all()),
    "| vhdr==txt:", int((E.n_seg_vhdr == E.n_seg_txt).sum()), "of", len(E),
    "| vhdr==vmrk New Segment:", int((chk.n_seg_vhdr == chk.n_newseg).sum()), "of", len(chk),
    "| txt lines==channels:", int((E.txt_lines == E.vhdr_channels).sum()),
    "| comma count constant across lines:", int((E.txt_commas_min == E.txt_commas_max).sum()),
    "| commas == values on line 1:", int((E.txt_commas_min == E.txt_values_line1).sum()))
say("importer sentence lines == segments:", int((chk.imp_sentence_lines == chk.n_newseg).sum()), "of", len(chk),
    "| distinct codes == segments:", int((chk.imp_distinct_codes == chk.n_newseg).sum()),
    "| segs with exactly one sentence marker == segments:", int((chk.segs_one_sentence == chk.n_newseg).sum()),
    "| one cond marker:", int((chk.segs_one_cond == chk.n_newseg).sum()), "| one prop marker:", int((chk.segs_one_prop == chk.n_newseg).sum()),
    "| one Time 0:", int((chk.segs_one_time0 == chk.n_newseg).sum()),
    "| files with wrong cond/prop markers:", int((chk.wrong_cond_markers > 0).sum()), int((chk.wrong_prop_markers > 0).sum()))
say("other marker types inside exports:", chk.other_marker_types.dropna().value_counts().to_dict())
E["importable"] = np.where((E.has_txt == 1) & (E.has_vmrk == 1), E.imp_distinct_codes.fillna(0), 0).astype(int)
E["n_exported"] = E["n_exported"].astype(int)
say("TOTAL exported:", int(E.n_exported.sum()), "| by condition:", E.groupby("condition").n_exported.sum().to_dict(),
    "| by session:", E.groupby("session").n_exported.sum().to_dict())
say("S101+S102 exported:", int(E[E.condition.isin(["S101", "S102"])].n_exported.sum()))

# completeness of stems within exported participant-sessions
EXPECTED = {2: ["S1"], 3: ["S1", "S2"], 4: ["S1", "S2", "S3"], 6: ["S1", "S2", "S3"]}
inc = []
for (s, p), g in E.groupby(["session", "participant"]):
    exp_n = len(EXPECTED[s]) * 3
    have = set(zip(g.property, g.condition))
    missing = [f"{pr}_{c}" for pr in EXPECTED[s] for c in ("S101", "S102", "S103") if (pr, c) not in have]
    extra = [f"{pr}_{c}" for pr, c in have if pr not in EXPECTED[s]]
    if missing or extra:
        inc.append((s, p, missing, extra))
say("participant-sessions with missing/extra stems:", inc)

# ------------------------------------------------------------------ presented
P = pd.read_csv(os.path.join(HERE, "presented_cells.csv"))
PF = pd.read_csv(os.path.join(HERE, "presented_files.csv"))
P = P[P.suffix.isna() | (P.suffix == "-experiment")]           # drop -test and .filepart
P = P.rename(columns={"session_folder": "session"})
dupf = P.groupby(["session", "participant"]).file.nunique()
say("\n== Presented ==")
say("participant-sessions with >1 usable log:", dupf[dupf > 1].to_dict())
say("usable-log cells:", len(P), "| n_presented values:", P.n_presented.value_counts().to_dict())

# ------------------------------------------------------------------ key
K = pd.read_csv(KEY, dtype=str)
K["participant"] = pd.to_numeric(K.participant_lab_ID, errors="coerce")
say("key rows with no lab ID (blank rows):", int(K.participant.isna().sum()),
    "| duplicated lab IDs:", K.loc[K.participant.notna() & K.participant.duplicated(keep=False), "participant"].tolist())
K = K[K.participant.notna()].drop_duplicates("participant")
lang = K.set_index("participant")["language"]
say("key rows:", len(K), "| languages:", K.language.value_counts(dropna=False).to_dict(),
    "| odd->", K[K.participant % 2 == 1].language.value_counts().to_dict(), "| even->", K[K.participant % 2 == 0].language.value_counts().to_dict())

# ------------------------------------------------------------------ cells S101/S102
KEYC = ["session", "participant", "property", "condition"]
C = E[KEYC + ["n_exported", "importable", "has_txt", "has_vmrk"]].merge(P[KEYC + ["n_presented", "file"]], on=KEYC, how="left")
C["presented_from_log"] = C.n_presented.notna()
C["presented"] = C.n_presented.fillna(48).astype(int)
C["ps"] = list(zip(C.participant, C.session))
C["x_mis"] = C.ps.isin(MIS)
C["x_inv"] = C.ps.isin(INV)
C["x_dev"] = C.participant.isin(DEV)
C["excluded"] = C.x_mis | C.x_inv | C.x_dev
C["canonical"] = C.condition.isin(["S101", "S102"])
C["language"] = C.participant.map(lang)
C.drop(columns="ps").to_csv(os.path.join(HERE, "c04_cells.csv"), index=False)
say("export cells without a usable log (presented = 48 by design):",
    C[~C.presented_from_log].groupby(["session", "participant"]).size().to_dict())
say("cells with exported > presented:", int((C.n_exported > C.presented).sum()))
# presented-but-not-exported participant-sessions
pe = set(zip(P.session, P.participant)) - set(zip(E.session, E.participant))
say("participant-sessions with a usable log but no export:", sorted(pe))

A = C[C.canonical & ~C.excluded].copy()
say("\n== Analysed sample (S101+S102, decided exclusions applied) ==")
say("participant-sessions:", A.groupby(["session", "participant"]).ngroups, "| participants:", A.participant.nunique(),
    "| cells:", len(A), "| by session p-s:", A.groupby("session").participant.nunique().to_dict())
tot_p, tot_a = int(A.presented.sum()), int(A.importable.sum())
say(f"analysed {tot_a} of {tot_p} presented = {100 * tot_a / tot_p:.2f}%")
for c in ("S101", "S102"):
    s_ = A[A.condition == c]
    say(f"  {c}: {int(s_.importable.sum())} of {int(s_.presented.sum())} = {100 * s_.importable.sum() / s_.presented.sum():.2f}%")
say("  cells whose presented count is the design value (no log):", int((~A.presented_from_log).sum()),
    "holding", int(A.loc[~A.presented_from_log, "importable"].sum()), "analysed trials")
Alog = A[A.presented_from_log]
say(f"  restricted to cells with a usable log: {int(Alog.importable.sum())} of {int(Alog.presented.sum())} = {100 * Alog.importable.sum() / Alog.presented.sum():.2f}%")
say("  S101+S102 exported in analysed p-s:", int(A.n_exported.sum()), "| lost to missing .vmrk/.txt:", int((A.n_exported - A.importable).sum()))
say(A[A.importable != A.n_exported][KEYC + ["n_exported", "importable", "has_txt", "has_vmrk"]].to_string(index=False))
nz = A[A.importable > 0]
say("non-empty cells:", len(nz), "| empty cells:", int((A.importable == 0).sum()),
    "| non-empty cells < 20 trials:", int((nz.importable < 20).sum()), "| <24:", int((nz.importable < 24).sum()),
    "| min/median/max:", int(nz.importable.min()), float(nz.importable.median()), int(nz.importable.max()))
say("cells < 20 by participant-session:", nz[nz.importable < 20].groupby(["session", "participant"]).size().to_dict())
say("pooled mean/SD per cell (all 830-type cells, incl. empty):", round(A.importable.mean(), 3), round(A.importable.std(), 3),
    "| non-empty:", round(nz.importable.mean(), 3), round(nz.importable.std(), 3))

say("\n== What the exclusions remove ==")
X = C[C.excluded]
say("excluded participant-sessions present in exports:", X.groupby(["session", "participant"]).ngroups,
    sorted(set(zip(X.session, X.participant))))
for name, m in (("1Hz", C.x_mis), ("invalid", C.x_inv), ("P14", C.x_dev), ("any", C.excluded)):
    s_ = C[m]
    say(f"  {name}: p-s={s_.groupby(['session', 'participant']).ngroups} exported_all={int(s_.n_exported.sum())} "
        f"exported_S101S102={int(s_[s_.canonical].n_exported.sum())} importable_S101S102={int(s_[s_.canonical].importable.sum())}")
say("  per excluded p-s (all / S101+S102 exported):")
for (s, p), g in X.groupby(["session", "participant"]):
    say(f"    S{s}/{p}: {int(g.n_exported.sum())} / {int(g[g.canonical].n_exported.sum())}")
say("overlap between exclusion lists (p-s in >1 list):", int(((C.x_mis.astype(int) + C.x_inv.astype(int) + C.x_dev.astype(int)) > 1).sum()), "cells")
can = C[C.canonical]
say("S101+S102 exported total:", int(can.n_exported.sum()), "- excluded", int(can[can.excluded].n_exported.sum()),
    "- missing-file loss among kept", int((can[~can.excluded].n_exported - can[~can.excluded].importable).sum()),
    "=", int(can.n_exported.sum() - can[can.excluded].n_exported.sum() - (can[~can.excluded].n_exported - can[~can.excluded].importable).sum()))

# ------------------------------------------------------------------ legacy table and repo artefacts
say("\n== Legacy table vs primary counts ==")
L = pd.read_csv(LEGACY)
PROPL = {"Gender agreement": "S1", "Differential object marking": "S2", "Verb-object number agreement": "S3"}
L["property"] = L.grammatical_property.map(PROPL)
L["condition"] = np.where(L.grammaticality == "Grammatical", "S101", np.where(L.grammaticality == "Ungrammatical", "S102", "S103"))
L = L.rename(columns={"participant_lab_ID": "participant"})
M = C.merge(L[KEYC + ["n_trials", "mini_language"]], on=KEYC, how="outer", indicator=True)
say("merge:", M._merge.value_counts().to_dict(), "| legacy n_trials == importable:", int((M.n_trials == M.importable).sum()), "of", int((M._merge == "both").sum()))
say("export cells not in legacy:", M[M._merge == "left_only"][KEYC + ["n_exported", "importable"]].to_string(index=False))
Lc = L[L.condition.isin(["S101", "S102"])].copy()
Lc["ps"] = list(zip(Lc.participant, Lc.session))
Lc["excluded"] = Lc.ps.isin(MIS) | Lc.ps.isin(INV) | Lc.participant.isin(DEV)
say(f"legacy canonical: cells={len(Lc)} mean={Lc.n_trials.mean():.3f} sd={Lc.n_trials.std():.3f} pct_discarded={100 * (48 - Lc.n_trials.mean()) / 48:.3f}")
say("  excluded participant-sessions represented in it:", Lc[Lc.excluded].groupby(["session", "participant"]).ngroups,
    "cells:", int(Lc.excluded.sum()), "trials:", int(Lc[Lc.excluded].n_trials.sum()), sorted(set(Lc[Lc.excluded].ps)))
Lk = Lc[~Lc.excluded]
say(f"  legacy canonical without the excluded: cells={len(Lk)} mean={Lk.n_trials.mean():.3f} sd={Lk.n_trials.std():.3f} "
    f"pct_discarded={100 * (48 - Lk.n_trials.mean()) / 48:.3f} trials={int(Lk.n_trials.sum())}")
R = pd.read_csv(REPO_RET)
say("repo _erp_trial_retention.csv canonical row:", R[R.scope == "canonical"].to_dict("records"))
say("repo overall row:", R[R.scope == "overall"].to_dict("records"), f"| legacy all rows: cells={len(L)} mean={L.n_trials.mean():.3f}")

say("\n== Mis-filtered share (Session 3, S101+S102) ==")
say("repo _misfiltered_share.csv:", pd.read_csv(REPO_MIS).to_dict("records"))
for label, ids in (("four", {7, 8, 9, 16}), ("nine", {p for p, s in MIS})):
    for src, df, col in (("legacy table", Lc, "n_trials"), ("primary importable", C[C.canonical].rename(columns={"importable": "imp"}), "imp")):
        d3 = df[df.session == 3]
        for pr, g in d3.groupby("property"):
            m = g.participant.isin(ids)
            say(f"  {label} ({src}) {pr}: datasets {g[m].participant.nunique()}/{g.participant.nunique()} "
                f"trials {int(g[m][col].sum())}/{int(g[col].sum())} share={100 * g[m][col].sum() / g[col].sum():.3f}%")

with open(os.path.join(HERE, "c04_results.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(out_lines))
