"""Readers for BrainVision Core Data Format files (raw recordings and Analyzer exports).

Raw recordings
--------------
The Session-3 recordings were written by BrainVision Recorder 1.26 from a LiveAmp as
``IEEE_FLOAT_32``, ``MULTIPLEXED``. Although the samples are stored as float32, they hold
integer ADC counts (every first difference is an integer), so the per-channel resolution
from the ``.vhdr`` (0.0406901 µV for EEG channels) must be applied to obtain µV. This was
checked empirically: without the factor, the rereferenced, filtered data are ~24.6 times
larger than Analyzer's exports.

Analyzer's own raw-data node stores the resolutions as XML ``<float>`` (single precision),
so the multiplication is done with the float32 value of the resolution. The difference
from the double value is a relative gain of ~5e-9, far below the export quantisation.

Exports
-------
Analyzer "Generic Data Export" with ASCII, VECTORIZED orientation, decimal comma and the
channel name in the first column (SkipColumns=1). Each line holds one channel with all
segments concatenated (``SegmentDataPoints`` per segment).
"""
from __future__ import annotations

import configparser
import re
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np


@dataclass
class Marker:
    """One marker, with a 0-based sample position (the files store 1-based positions)."""
    type: str
    description: str
    pos: int
    length: int
    channel: int  # 0 = all channels, as in the .vmrk convention
    date: str = ''


@dataclass
class Header:
    path: Path
    n_channels: int
    sampling_interval_us: float
    channel_names: list[str]
    resolutions: np.ndarray
    ref_names: list[str]
    data_file: str
    marker_file: str
    orientation: str
    binary_format: str | None
    data_points: int | None = None
    segment_data_points: int | None = None
    decimal_symbol: str = '.'
    comment_first_line: str = ''
    extra: dict = field(default_factory=dict)

    @property
    def sfreq(self) -> float:
        return 1e6 / self.sampling_interval_us


def _read_ini(path: Path) -> tuple[configparser.ConfigParser, list[str]]:
    text = Path(path).read_bytes().decode('utf-8', errors='replace')
    lines = text.splitlines()
    # Drop the identification line and keep comments separately; configparser cannot
    # parse the free-text [Comment] section so it is cut off.
    comments = [ln for ln in lines if ln.startswith(';')]
    body = []
    for ln in lines[1:]:
        if ln.strip() == '[Comment]':
            break
        body.append(ln)
    cp = configparser.ConfigParser(interpolation=None, strict=False, comment_prefixes=(';',))
    cp.optionxform = str
    cp.read_string('\n'.join(body))
    return cp, comments


def read_header(path: str | Path) -> Header:
    path = Path(path)
    cp, comments = _read_ini(path)
    ci = cp['Common Infos']
    n = int(ci['NumberOfChannels'])
    names, refs, res = [], [], []
    for i in range(1, n + 1):
        parts = cp['Channel Infos'][f'Ch{i}'].split(',')
        names.append(parts[0].replace('\\1', ','))
        refs.append(parts[1] if len(parts) > 1 else '')
        r = parts[2] if len(parts) > 2 and parts[2] != '' else '1'
        res.append(float(r))
    binfmt = cp['Binary Infos']['BinaryFormat'] if cp.has_section('Binary Infos') else None
    dec = cp['ASCII Infos'].get('DecimalSymbol', '.') if cp.has_section('ASCII Infos') else '.'
    return Header(
        path=path, n_channels=n, sampling_interval_us=float(ci['SamplingInterval']),
        channel_names=names, resolutions=np.array(res, dtype=np.float32), ref_names=refs,
        data_file=ci['DataFile'], marker_file=ci.get('MarkerFile', ''),
        orientation=ci.get('DataOrientation', 'MULTIPLEXED'), binary_format=binfmt,
        data_points=int(ci['DataPoints']) if 'DataPoints' in ci else None,
        segment_data_points=int(ci['SegmentDataPoints']) if 'SegmentDataPoints' in ci else None,
        decimal_symbol=dec,
        comment_first_line=next((c for c in comments if 'history path' in c), ''),
    )


def read_markers(path: str | Path) -> list[Marker]:
    """Parse a .vmrk file. Positions are converted to 0-based sample indices."""
    out = []
    text = Path(path).read_bytes().decode('utf-8', errors='replace')
    for ln in text.splitlines():
        m = re.match(r'^Mk\d+=(.*)$', ln)
        if not m:
            continue
        f = m.group(1).split(',')
        out.append(Marker(type=f[0].replace('\\1', ','), description=f[1].replace('\\1', ','),
                          pos=int(f[2]) - 1, length=int(f[3]), channel=int(f[4]) if len(f) > 4 and f[4] else 0,
                          date=f[5] if len(f) > 5 else ''))
    return out


def read_raw(vhdr: str | Path, dtype=np.float64) -> tuple[Header, np.ndarray, list[Marker]]:
    """Read a raw BrainVision recording and return (header, data[channels, samples] in µV, markers)."""
    h = read_header(vhdr)
    if h.binary_format != 'IEEE_FLOAT_32' or h.orientation != 'MULTIPLEXED':
        raise NotImplementedError(f'{h.binary_format} / {h.orientation}')
    raw = np.fromfile(h.path.parent / h.data_file, dtype='<f4')
    if raw.size % h.n_channels:
        raise ValueError('data size is not a multiple of the channel count')
    raw = raw.reshape(-1, h.n_channels).T
    # float32 counts x float32 resolution (see module docstring), then promote.
    data = (raw * h.resolutions[:, None]).astype(dtype)
    markers = read_markers(h.path.parent / h.marker_file)
    return h, data, markers


def read_export(vhdr: str | Path) -> tuple[Header, np.ndarray, list[Marker]]:
    """Read an Analyzer ASCII vectorised export.

    Returns (header, data[channels, segments, points], markers).
    """
    h = read_header(vhdr)
    if h.orientation != 'VECTORIZED':
        raise NotImplementedError(h.orientation)
    rows = {}
    text = (h.path.parent / h.data_file).read_bytes().decode('utf-8', errors='replace')
    for ln in text.splitlines():
        if not ln.strip():
            continue
        parts = ln.split()
        name = parts[0]
        vals = np.array([float(v.replace(h.decimal_symbol, '.')) for v in parts[1:]])
        rows[name] = vals
    names = list(rows)
    if names != h.channel_names:
        raise ValueError(f'channel order in data file {names} differs from header {h.channel_names}')
    data = np.vstack([rows[n] for n in names])
    if data.shape[1] != h.data_points:
        raise ValueError(f'{data.shape[1]} points, header says {h.data_points}')
    seg = h.segment_data_points or data.shape[1]  # continuous exports (resting state) have no segments
    data = data.reshape(h.n_channels, data.shape[1] // seg, seg)
    markers = read_markers(h.path.parent / h.marker_file) if h.marker_file else []
    return h, data, markers
