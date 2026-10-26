"""Write a reprocessed trial-by-trial export in the format of the legacy Analyzer exports.

The legacy "Generic Data Export" writes three files per export. The importer
(``paper_1_transfer/scripts/_eeg_import.R``) reads the text file and the marker file; the
header describes them. A reprocessed export keeps exactly the trials of its legacy
counterpart (Amendment 1), so:

* the marker file (``.vmrk``) is the legacy file, byte for byte. Its trial positions, codes
  and New Segment timestamps are those of the reconstruction, which the caller checks
  before writing;
* the header (``.vhdr``) is the legacy file with one comment line added after the
  ``history path`` line, saying how the data file was produced. Comment lines (``;``) are
  ignored by BrainVision readers and by the importer;
* the data file (``.txt``) is written as Analyzer writes it (checked on the legacy files):
  one CRLF-terminated line per channel, in header order, holding the channel name
  left-justified to six characters followed by every sample of every trial, trial after
  trial ("VECTORIZED"), with three decimals, a decimal comma and single spaces. Analyzer
  never writes a negative zero, so values that round to zero are written ``0,000``.

``round_trip`` reads the written export back and returns its samples, so the caller can
check the files and not only the arrays that were meant to go into them.
"""
from __future__ import annotations

from pathlib import Path

import numpy as np

from bv_io import read_export, read_header

NAME_WIDTH = 6


def format_line(name: str, values: np.ndarray) -> str:
    if len(name) >= NAME_WIDTH:
        raise ValueError(f'channel name {name!r} is wider than the legacy column')
    txt = ' '.join('0.000' if v == '-0.000' else v for v in (f'{x:.3f}' for x in values))
    return name.ljust(NAME_WIDTH) + txt.replace('.', ',') + '\r\n'


def write_export(legacy_vhdr: Path, out_dir: Path, data: np.ndarray, channel_names: list[str],
                 note: str, vmrk: bytes | None = None) -> dict[str, Path]:
    """Write ``<stem>.{vhdr,vmrk,txt}`` to ``out_dir`` beside nothing else.

    legacy_vhdr   : header of the legacy export this one replaces (same stem).
    data          : channels x trials x points, in µV, in the order of ``channel_names``.
    note          : one line (no newline) recorded as a header comment.
    vmrk          : the marker file's bytes for an export whose trials differ from the legacy
                    one (a re-segmented record); the header's DataPoints then follows ``data``.
                    None keeps the legacy trials and marker file, and requires the same count.
    Returns the three written paths keyed by extension.
    """
    legacy_vhdr = Path(legacy_vhdr)
    h = read_header(legacy_vhdr)
    if channel_names != h.channel_names:
        raise ValueError('channel order differs from the legacy export')
    n_ch, n_tr, n_pt = data.shape
    if n_ch != h.n_channels or n_pt != h.segment_data_points or (vmrk is None and n_tr * n_pt != h.data_points):
        raise ValueError(f'shape {data.shape} disagrees with the legacy header '
                         f'({h.n_channels} channels, {h.data_points} points, {h.segment_data_points} per segment)')
    if not h.marker_file and vmrk is None:
        raise ValueError('legacy export has no marker file to keep')
    if h.decimal_symbol != ',' or h.orientation != 'VECTORIZED':
        raise ValueError('legacy export is not a decimal-comma VECTORIZED ASCII export')
    if '\n' in note or '\r' in note:
        raise ValueError('note must be one line')
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = legacy_vhdr.stem
    out = {ext: out_dir / f'{stem}.{ext}' for ext in ('vhdr', 'vmrk', 'txt')}

    # Header: the legacy bytes plus one comment line after the history-path comment.
    raw = legacy_vhdr.read_bytes()
    nl = b'\r\n' if b'\r\n' in raw else b'\n'
    lines = raw.split(nl)
    at = next(i for i, ln in enumerate(lines) if ln.startswith(b'; Data created from history path'))
    lines.insert(at + 1, b'; ' + note.encode('utf-8'))
    if vmrk is not None:
        lines = [f'DataPoints={n_tr * n_pt}'.encode() if ln.startswith(b'DataPoints=') else ln for ln in lines]
        if not any(ln.startswith(b'MarkerFile=') for ln in lines):
            at = next(i for i, ln in enumerate(lines) if ln.startswith(b'DataFile='))
            lines.insert(at + 1, f'MarkerFile={stem}.vmrk'.encode())
    out['vhdr'].write_bytes(nl.join(lines))

    out['vmrk'].write_bytes(vmrk if vmrk is not None else (legacy_vhdr.parent / h.marker_file).read_bytes())

    flat = data.reshape(n_ch, n_tr * n_pt)
    with open(out['txt'], 'w', encoding='utf-8', newline='') as f:
        for name, row in zip(channel_names, flat):
            f.write(format_line(name, row))
    return out


def round_trip(vhdr: Path) -> np.ndarray:
    """Samples of a written export as the reader sees them (channels x trials x points)."""
    return read_export(vhdr)[1]


# --------------------------------------------------------------------------- marker files
# Analyzer's marker-file template, as every legacy trial-by-trial export carries it. Only the
# history path and the data-file name vary between files.
_VMRK_HEAD = [
    'BrainVision Data Exchange Marker File Version 2.0',
    '; Data created from history path: {history_path}',
    '; The channel numbers are related to the channels in the exported file.',
    '',
    '[Common Infos]',
    'Codepage=UTF-8',
    'DataFile={data_file}',
    '',
    '[Marker Infos]',
    '; Each entry: Mk<Marker number>=<Type>,<Description>,<Position in data points>,',
    '; <Size in data points>, <Channel number (0 = marker is related to all channels)>,',
    '; <Date (YYYYMMDDhhmmssuuuuuu)>, Visible',
    '; Fields are delimited by commas, some fields may be omitted (empty).',
    '; Commas in type or description text are coded as "\\1".',
]
_VMRK_TAIL = [
    '',
    '[Marker User Infos]',
    '; Each entry: Prop<Number>=Mk<Marker number>,<Type>,<Name>,<Value>,<Value2>,...,<ValueN>',
    '; Property number must be unique. Types can be int, single, string, bool, byte, double, uint',
    '; or arrays of those, indicated int-array etc',
    '; Array types have more than one value, number of values determines size of array.',
    '; Fields are delimited by commas, commas in strings are written \\1',
    '; Properties are assigned to markers using their marker number.',
]
#: Marker types a trial-by-trial export does not carry from its parent: segment boundaries
#: and bad intervals, and the parent segmentation's own Time 0 (each trial gets its own).
_NOT_CARRIED = ('New Segment', 'Bad Interval', 'Time 0')


def vmrk_bytes(history_path: str, data_file: str, entries: list[tuple], note: str | None = None) -> bytes:
    """A trial-by-trial export's marker file in Analyzer's layout.

    history_path : the tbt node's path (the export header's comment names it).
    entries      : (type, description, 1-based position, size, file channel, date or None),
                   from ``entries_from_node`` or ``entries_by_rule``.
    note         : optional comment line, added after the history-path line.
    """
    head = [ln.format(history_path=history_path, data_file=data_file) for ln in _VMRK_HEAD]
    if note:
        head.insert(2, '; ' + note)
    body = []
    for k, (typ, desc, pos, ln, ch, date) in enumerate(entries, start=1):
        f = [typ.replace(',', '\\1'), desc.replace(',', '\\1'), str(pos), str(ln), str(ch)]
        if date:
            f.append(date)
        body.append(f'Mk{k}=' + ','.join(f))
    return ('\r\n'.join(head + body + _VMRK_TAIL) + '\r\n').encode('utf-8')


def entries_from_node(h, tbt_node: str) -> list[tuple]:
    """The markers an existing tbt node holds, in the order the history stores them.

    This is exactly what Analyzer's export writes, including the order of markers that
    share a position (Time 0 and the condition trigger fall either way round, following
    Analyzer's internal sort), so it rebuilds a missing legacy marker file exactly.
    """
    return [(m.type, m.description, m.pos + 1, m.length, _vmrk_channel(m), m.date or None)
            for m in h.markers(tbt_node)]


def entries_by_rule(trial_starts: list[int], ref_offset: int, seglen: int, markers, datef) -> list[tuple]:
    """Marker entries for a segmentation no history node records (a re-segmented record).

    Per trial: a dated New Segment marker at its first sample, every carried marker that
    overlaps it in position order, and Time 0 at the reference marker. A marker with a
    duration (the analyst's "Blink" intervals) is clipped to the trial, so one that began
    earlier starts at the trial's first sample, as Analyzer writes it. Where Time 0 and
    another marker share a position, Time 0 is written after it; Analyzer's own order at ties
    follows its internal sort and carries no information (the importer reads only the
    sentence codes). ``markers`` use the history convention (channel -1 = all channels).
    """
    out = []
    for t, s in enumerate(trial_starts):
        base, e = t * seglen, s + seglen
        inside = sorted((m for m in markers if m.pos < e and m.pos + max(m.length, 1) > s
                         and m.type not in _NOT_CARRIED), key=lambda m: max(m.pos, s))
        out.append(('New Segment', '', base + 1, 1, 0, datef(s)))
        placed = False
        for m in inside:
            a = max(m.pos, s)
            if not placed and a - s > ref_offset:
                out.append(('Time 0', '', base + ref_offset + 1, 1, 0, None))
                placed = True
            ln = min(m.pos + m.length, e) - a if m.length > 1 else m.length
            out.append((m.type, m.description, base + a - s + 1, ln, _vmrk_channel(m), None))
        if not placed:
            out.append(('Time 0', '', base + ref_offset + 1, 1, 0, None))
    return out


def _vmrk_channel(m) -> int:
    """History markers use -1 for all channels and 0-based indices otherwise; files use 0 and 1-based."""
    return 0 if m.channel == -1 else m.channel + 1
