"""Readers shared by n7_10_aligned_events.py and n7_11_aligned_table.py.

Written on 17 September 2026 as ``verify/C09_recompute/c09_io.py``, from scratch against the
primary files; moved here with only its paths changed. Positions are kept 1-based, exactly as
BrainVision writes them; only differences are used.
"""
from __future__ import annotations

import csv
import io
import re
from pathlib import Path

import audit_paths

EEG = audit_paths.eeg_root()
BEH = audit_paths.behaviour_root()
KEY = audit_paths.participant_key()
OUT = audit_paths.out_dir('aligned')
SESSIONS = audit_paths.SESSIONS

MK = re.compile(r'^Mk(\d+)=([^,]*),([^,]*),(-?\d+),(-?\d+),(-?\d+)(?:,(\d*))?')


def markers(path: Path):
    """List of (type, code_or_None, desc, pos1, date) in file order."""
    out = []
    with open(path, 'r', encoding='utf-8', errors='replace') as fh:
        for ln in fh:
            m = MK.match(ln.strip())
            if not m:
                continue
            typ, desc, pos, date = m.group(2), m.group(3), int(m.group(4)), (m.group(7) or '')
            cm = re.fullmatch(r'S\s*(\d+)', desc.strip())
            out.append((typ, int(cm.group(1)) if cm else None, desc, pos, date))
    return out


def raw_files(session: int, pid: str):
    d = EEG / f'Session {session}' / 'Raw'
    fs = []
    if (d / f'{pid}.vmrk').exists():
        fs.append(d / f'{pid}.vmrk')
    for p in sorted(d.glob(f'{pid}-*.vmrk')):
        if 'Copy' not in p.name:
            fs.append(p)
    return fs


def raw_ids(session: int):
    d = EEG / f'Session {session}' / 'Raw'
    ids = set()
    for p in d.glob('*.vmrk'):
        m = re.fullmatch(r'(\d+)(-continued)?\.vmrk', p.name)
        if m:
            ids.add(m.group(1))
    return ids


def read_header_cols(path: Path):
    with open(path, 'r', encoding='utf-8', errors='replace') as fh:
        h = fh.readline()
    sep = ';' if h.count(';') > h.count(',') else ','
    return sep, next(csv.reader(io.StringIO(h), delimiter=sep))


def vhdr_segments(path: Path):
    txt = path.read_text(encoding='utf-8', errors='replace')
    dp = re.search(r'^DataPoints=(\d+)', txt, re.M)
    sp = re.search(r'^SegmentDataPoints=(\d+)', txt, re.M)
    if not dp or not sp:
        return None
    return int(dp.group(1)) / int(sp.group(1))
