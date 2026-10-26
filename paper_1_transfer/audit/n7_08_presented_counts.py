"""N7, step 8: presented trials per participant x session x property x condition, from the logs.

Second step of the cell table (n7_07 to n7_09): the denominator of every retention percentage.
Written on 17 September 2026 as ``verify/C04_recompute/02_presented_counts.py``; moved here with
only its paths changed.

Experimental trial = row with session_part == 'Experiment' (case-insensitive), a grammatical_property
LABEL of gender agreement / differential object marking / verb-object agreement (mapped to S1/S2/S3;
the trigger column is only cross-checked, because it is wrong in one Session-4 log) and a
grammaticality trigger in {101,102,103}. Logger duplicates are removed as
exact duplicates over the columns read (which include count_experiment_sequence and
time_fixation_trigger); the script also reports whether count_experiment_sequence still repeats.

Reads    raw data/behavioural data from lab sessions/Session {2,3,4,6}/subject-*.csv
Writes   eeg_audit/cells/presented_files.csv (one row per file) and presented_cells.csv
         (one row per file x cell)
Runtime: about a minute.
"""
import os
import re

import pandas as pd

import audit_paths

BEH = str(audit_paths.behaviour_root())
OUT = str(audit_paths.out_dir("cells"))
COLS = ["session_part", "session", "subject_nr", "language", "experiment_file", "grammatical_property_trigger",
        "grammaticality_trigger", "sentence_trigger", "target_word_trigger", "count_experiment_sequence",
        "time_fixation_trigger", "time_send_word3_triggers", "time_send_word4_triggers", "grammatical_property", "grammaticality"]
PROP = {"gender agreement": "S1", "differential object marking": "S2", "verb-object agreement": "S3"}
FN = re.compile(r"^subject-(\d+)(-experiment|-test)?\.csv(\.filepart)?$")

files, cells = [], []
for s in audit_paths.SESSIONS:
    d = os.path.join(BEH, f"Session {s}")
    for fn in sorted(os.listdir(d)):
        m = FN.match(fn)
        rec = dict(session_folder=s, file=fn, participant=int(m.group(1)) if m else None,
                   suffix=(m.group(2) or "") + (m.group(3) or "") if m else "unparsed")
        p = os.path.join(d, fn)
        try:
            df = pd.read_csv(p, usecols=lambda c: c in COLS, dtype=str, keep_default_na=False, on_bad_lines="warn")
        except pd.errors.EmptyDataError:
            rec.update(n_rows=0, note="empty file")
            files.append(rec)
            continue
        except pd.errors.ParserError as err:
            # truncated transfer (e.g. .filepart): keep the complete records only
            import csv, io
            csv.field_size_limit(10**9)
            with open(p, newline="", encoding="utf-8", errors="replace") as fh:
                txt = fh.read()
            recs = []
            rdr = csv.reader(io.StringIO(txt))
            try:
                hdr = next(rdr)
                for row in rdr:
                    recs.append(row)
            except csv.Error:
                pass
            # drop a last record that is shorter than the header (cut mid-row)
            if recs and len(recs[-1]) < len(hdr):
                recs = recs[:-1]
            idx = [i for i, c in enumerate(hdr) if c in COLS]
            df = pd.DataFrame([[r[i] if i < len(r) else "" for i in idx] for r in recs], columns=[hdr[i] for i in idx])
            rec["note"] = f"parser error ({err.__class__.__name__}); complete records kept"
        rec["n_rows"] = len(df)
        rec["missing_cols"] = "|".join(c for c in COLS if c not in df.columns)
        if "session_part" not in df.columns:
            rec["note"] = "no session_part column"
            files.append(rec)
            continue
        e = df[df["session_part"].str.lower() == "experiment"].copy()
        rec["n_exp_rows"] = len(e)
        # Property from the logged LABEL: in Session-4 subject-7.csv the verb-object trials carry
        # property trigger 2 (see 02c_label_vs_trigger.py / label_vs_trigger.csv).
        e["prop"] = e["grammatical_property"].map(PROP)
        e = e[e["prop"].notna() & e["grammaticality_trigger"].isin(["101", "102", "103"])]
        rec["n_exp_target_rows"] = len(e)
        rec["n_label_trigger_disagree"] = int((e["prop"].str[1] != e["grammatical_property_trigger"]).sum())
        ed = e.drop_duplicates()
        rec["n_exp_target_dedup"] = len(ed)
        rec["n_seq_repeats_after_dedup"] = int(ed.duplicated("count_experiment_sequence").sum()) if "count_experiment_sequence" in ed else None
        rec["n_distinct_seq"] = ed["count_experiment_sequence"].nunique() if "count_experiment_sequence" in ed else None
        for c in ("subject_nr", "session", "language", "experiment_file"):
            rec[c + "_values"] = "|".join(sorted(set(df[c]) - {"", "NA"})) if c in df else None
        files.append(rec)
        g = ed.groupby(["prop", "grammaticality_trigger"]).size()
        graw = e.groupby(["prop", "grammaticality_trigger"]).size()
        for (pt, gt), n in g.items():
            cells.append(dict(session_folder=s, file=fn, participant=rec["participant"], suffix=rec["suffix"],
                              property=pt, condition=f"S{gt}", n_presented=int(n), n_rows_raw=int(graw.get((pt, gt), 0))))
        print(s, fn, len(df), rec["n_exp_target_rows"], rec["n_exp_target_dedup"], flush=True)

pd.DataFrame(files).to_csv(os.path.join(OUT, "presented_files.csv"), index=False)
pd.DataFrame(cells).to_csv(os.path.join(OUT, "presented_cells.csv"), index=False)
