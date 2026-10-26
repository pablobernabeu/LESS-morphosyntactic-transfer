"""N7, step 7: exported trials per export stem, from the primary Analyzer files.

First of three steps that build the cell table (n7_07 to n7_09) from which the retention of the
analysed trials by mini-language, session, property and condition is tabulated (n7_10), including
the Mini-English Session 6 grammatical-minus-ungrammatical gaps the Method reports. Written on
17 September 2026 as ``verify/C04_recompute/01_export_inventory.py`` (an independent recount that
reads no earlier audit table); moved here with only its paths changed, and run over all four
sessions when no session is given.

For every file in data/raw data/EEG/Session {2,3,4,6}/Export whose basename matches the
legacy importer pattern ^\\d+_trialbytrial_S[123]_S10[123]\\.(txt|vhdr|vmrk)$ :
  vhdr : NumberOfChannels, DataPoints, SegmentDataPoints, orientation, history path
  vmrk : New Segment count, Time 0 count, importer emulation (lines after [Marker Infos]
         matching S1[1-9][0-9]|S2[0-4][0-9]|S25[0-3]; number of such lines; n_distinct of the
         captured 3-digit code, as 'EEG data descriptives.R' counts), per-segment checks
  txt  : number of non-empty lines; whitespace tokens on line 1 minus the label; per-line
         decimal-comma count (min/max) as a cheap consistency check on all lines
It also lists every file in the Export folders containing 'trialbytrial' that does NOT match
the pattern (near misses), and scans the whole EEG tree for pattern matches outside Export
(the importer lists files recursively).
Streams each txt file line by line (binary) to stay within ~1 GB RAM.

Usage:   python n7_07_export_inventory.py [session ...]     (default: 2 3 4 6)
Writes:  eeg_audit/cells/export_stems_S<session>.csv, export_nearmiss_S<session>.csv
Runtime: about 10 minutes for the four sessions (it streams every text export).
"""
import csv
import os
import re
import sys
from collections import Counter, defaultdict

import audit_paths

EEG = str(audit_paths.eeg_root())
OUT = str(audit_paths.out_dir("cells"))
PAT = re.compile(r"^(\d+)_trialbytrial_S([123])_S10([123])\.(txt|vhdr|vmrk)$")
IMPORTER_SENT = re.compile(r"S1[1-9][0-9]|S2[0-4][0-9]|S25[0-3]")
IMPORTER_CODE = re.compile(r".*S(\d{3}).*")


def parse_vhdr(p):
    d = {}
    with open(p, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.strip()
            if line.startswith("; Data created from history path:"):
                d["history_path"] = line.split(":", 1)[1].strip()
            for k in ("NumberOfChannels", "DataPoints", "SegmentDataPoints", "DataOrientation", "DataFile", "MarkerFile", "SamplingInterval", "DecimalSymbol"):
                if line.startswith(k + "="):
                    d[k] = line.split("=", 1)[1]
    return d


def parse_vmrk(p, prop, cond):
    with open(p, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()
    start = [i for i, l in enumerate(lines) if "[Marker Infos]" in l]
    r = dict(vmrk_has_marker_infos=int(bool(start)))
    if not start:
        return r
    mi = lines[start[0]:]
    sent_lines = [l for l in mi if IMPORTER_SENT.search(l)]
    codes = [IMPORTER_CODE.sub(r"\1", l) for l in sent_lines]
    r["imp_sentence_lines"] = len(sent_lines)
    r["imp_distinct_codes"] = len(set(codes))
    # structured parse
    segs = []
    cur = None
    for l in mi:
        m = re.match(r"^Mk(\d+)=([^,]*),([^,]*),(\d+),", l)
        if not m:
            continue
        typ, desc, pos = m.group(2), m.group(3), int(m.group(4))
        if typ == "New Segment":
            cur = dict(pos=pos, markers=[])
            segs.append(cur)
        else:
            if cur is None:
                cur = dict(pos=None, markers=[])
                segs.append(cur)
            cur["markers"].append((typ, desc.replace(" ", ""), pos))
    r["n_newseg"] = sum(1 for s in segs if s["pos"] is not None)
    r["n_time0"] = sum(1 for s in segs for t, _, _ in s["markers"] if t == "Time 0")
    cond_code = f"S10{cond}"
    prop_code = f"S{prop}"
    n1 = n_cond1 = n_prop1 = n_time01 = 0
    other = Counter()
    for s in segs:
        stim = [dsc for t, dsc, _ in s["markers"] if t == "Stimulus"]
        sent = [x for x in stim if re.fullmatch(r"S(1[1-9]\d|2[0-4]\d|25[0-3])", x)]
        n1 += len(sent) == 1
        n_cond1 += sum(1 for x in stim if x == cond_code) == 1
        n_prop1 += sum(1 for x in stim if x == prop_code) == 1
        n_time01 += sum(1 for t, _, _ in s["markers"] if t == "Time 0") == 1
        for x in stim:
            if re.fullmatch(r"S10[123]", x) and x != cond_code:
                other["wrong_cond"] += 1
            if re.fullmatch(r"S[123]", x) and x != prop_code:
                other["wrong_prop"] += 1
        for t, _, _ in s["markers"]:
            if t not in ("Stimulus", "Time 0"):
                other["type_" + t] += 1
    r.update(segs_one_sentence=n1, segs_one_cond=n_cond1, segs_one_prop=n_prop1, segs_one_time0=n_time01,
             wrong_cond_markers=other["wrong_cond"], wrong_prop_markers=other["wrong_prop"],
             other_marker_types="|".join(f"{k}:{v}" for k, v in sorted(other.items()) if k.startswith("type_")),
             dup_codes_in_file=sum(1 for c, n in Counter(codes).items() if n > 1))
    return r


def scan_txt(p):
    n_lines = 0
    first_tokens = None
    cmin, cmax = None, None
    labels = []
    with open(p, "rb") as fh:
        for line in fh:
            if not line.strip():
                continue
            n_lines += 1
            if first_tokens is None:
                first_tokens = len(line.split()) - 1
            c = line.count(b",")
            cmin = c if cmin is None else min(cmin, c)
            cmax = c if cmax is None else max(cmax, c)
            labels.append(line[:12].split()[0].decode("ascii", "replace"))
    return dict(txt_lines=n_lines, txt_values_line1=first_tokens, txt_commas_min=cmin, txt_commas_max=cmax,
                txt_first_label=labels[0] if labels else None)


def main(session):
    exp_dir = os.path.join(EEG, f"Session {session}", "Export")
    stems = defaultdict(dict)
    near = []
    for fn in sorted(os.listdir(exp_dir)):
        m = PAT.match(fn)
        if m:
            key = (int(m.group(1)), int(m.group(2)), int(m.group(3)))
            stems[key][m.group(4)] = os.path.join(exp_dir, fn)
            stems[key]["pid_str"] = m.group(1)
        elif "trialbytrial" in fn.lower():
            near.append(dict(session=session, file=fn))
    rows = []
    for (pid, prop, cond), files in sorted(stems.items()):
        r = dict(session=session, participant=pid, pid_str=files["pid_str"], property=f"S{prop}", condition=f"S10{cond}",
                 has_txt=int("txt" in files), has_vhdr=int("vhdr" in files), has_vmrk=int("vmrk" in files))
        if "vhdr" in files:
            v = parse_vhdr(files["vhdr"])
            r.update(vhdr_channels=v.get("NumberOfChannels"), vhdr_datapoints=v.get("DataPoints"), vhdr_segpoints=v.get("SegmentDataPoints"),
                     vhdr_orientation=v.get("DataOrientation"), vhdr_decimal=v.get("DecimalSymbol"), vhdr_datafile=v.get("DataFile"),
                     vhdr_history=v.get("history_path"))
            try:
                r["n_seg_vhdr"] = int(v["DataPoints"]) / int(v["SegmentDataPoints"])
            except Exception:
                r["n_seg_vhdr"] = None
        if "vmrk" in files:
            r.update(parse_vmrk(files["vmrk"], prop, cond))
        if "txt" in files:
            t = scan_txt(files["txt"])
            r.update(t)
            r["n_seg_txt"] = t["txt_values_line1"] / 600 if t["txt_values_line1"] is not None else None
        rows.append(r)
        print(session, pid, prop, cond, r.get("n_seg_vhdr"), r.get("n_newseg"), r.get("n_seg_txt"), flush=True)
    keys = []
    for r in rows:
        for k in r:
            if k not in keys:
                keys.append(k)
    with open(os.path.join(OUT, f"export_stems_S{session}.csv"), "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=keys)
        w.writeheader()
        w.writerows(rows)
    with open(os.path.join(OUT, f"export_nearmiss_S{session}.csv"), "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=["session", "file"])
        w.writeheader()
        w.writerows(near)
    # pattern matches anywhere else in the session tree (importer is recursive)
    elsewhere = []
    for dp, dn, fns in os.walk(os.path.join(EEG, f"Session {session}")):
        if os.path.normpath(dp) == os.path.normpath(exp_dir):
            continue
        for fn in fns:
            if PAT.match(fn):
                elsewhere.append(os.path.join(dp, fn))
    print("pattern matches outside Export:", len(elsewhere), elsewhere[:5])


if __name__ == "__main__":
    for s in [int(a) for a in sys.argv[1:]] or audit_paths.SESSIONS:
        main(s)
