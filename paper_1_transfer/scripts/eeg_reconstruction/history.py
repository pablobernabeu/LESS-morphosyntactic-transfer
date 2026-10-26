"""Parser for BrainVision Analyzer 2 history files (``.ehst2``, OLE compound documents).

Layout (reverse-engineered from the LESS Session-3 files, Analyzer 2.3.0.8300)
------------------------------------------------------------------------------
Every processing node is an OLE storage; children are nested storages named ``Stg_<k>``.
The root storage is the raw-data node. Streams used here:

``FullPath``          NUL-terminated path such as ``53/Raw Data/Raw Data Inspection/...``.
``Parameters``        XML (declared utf-16 but stored as single-byte text) for most
                      transforms; the New Reference node uses a binary format instead.
``Description``/``Description2``  plain-text summaries shown in Analyzer.
``MarkerIndex``       int32 records of 5: ``(channel, position, length, offset, levels_up)``.
                      ``channel`` is -1 for markers related to all channels, otherwise a
                      0-based channel index. ``position`` is 0-based. ``offset`` is the byte
                      offset of the marker body in the ``MarkerData`` stream of the
                      ``levels_up``-th marker-carrying ancestor (0 = this node; ancestors
                      without a MarkerIndex, such as IIR Filters, are not counted). Markers
                      that a transform inherits unchanged are therefore not copied.
``MarkerData``        concatenated marker bodies: GUID ``49ab7341-316f-11d0-8d72-00409505398a``,
                      uint32 body size, then tagged fields ``(uint32 tag, uint32 size, bytes)``:
                      0x100 type (text), 0x102 description (text), 0x002 OLE date (double),
                      0x103 .NET ticks (int64), 0x004 int32 (always 1 here).
``SegmentTable``      int32 pairs ``(start, length)``: for a segmentation node the start is the
                      0-based sample in the parent's data; for nodes under a segmentation it
                      is the offset in the parent's concatenated segments.
``ArtifactIntervals`` XML list of ``BadInterval`` (nChannel, nStart, nLength, nSegment, Artifact).
``InternalData``      binary; for "Ocular Correction ICA" see :func:`History.ica`.
"""
from __future__ import annotations

import datetime
import io
import struct
import xml.etree.ElementTree as ET
from dataclasses import dataclass

import numpy as np
import olefile

import paths

MARKER_GUID = bytes.fromhex('4173ab496f31d0118d7200409505398a')


@dataclass
class HMarker:
    type: str
    description: str
    pos: int
    length: int
    channel: int  # -1 = all channels
    levels_up: int
    ticks: int = 0  # .NET DateTime ticks (100 ns since 0001-01-01); 0 if no date

    @property
    def date(self) -> str:
        """Date in the .vmrk format YYYYMMDDhhmmssuuuuuu ('' when the marker has none)."""
        if not self.ticks:
            return ''
        d = datetime.datetime(1, 1, 1) + datetime.timedelta(microseconds=self.ticks // 10)
        return d.strftime('%Y%m%d%H%M%S') + f'{d.microsecond:06d}'


@dataclass
class ICAData:
    """Stored ICA solution of an "Ocular Correction ICA" node.

    ``InternalData`` layout: uint32 n, n doubles (``offset``); uint32 n, n doubles (``mask``,
    1 = keep component, 0 = component removed); uint32 r, uint32 c, r*c doubles (``unmixing``,
    row-major); uint32 r, uint32 c, r*c doubles (``mixing``); 13 trailing zero bytes.
    The matrices are square over all data channels (31 here); rows/columns for channels not
    enabled for ICA (FCz) are identity, so those channels pass through unchanged.
    Which matrix is mixing and which unmixing was established empirically (see ica.py).
    """
    offset: np.ndarray
    mask: np.ndarray
    unmixing: np.ndarray
    mixing: np.ndarray
    trailing: bytes


def load_history_bytes(pid: int | str, session: int = 3) -> bytes:
    """Return the .ehst2 bytes from the data tree (paths.history_path).

    The version-controlled copy and the working copies differ only in the ``DataPath``
    streams of the root node (checked for all nine IDs on 16 September 2026), which nothing
    here reads.
    """
    return paths.history_path(pid, session).read_bytes()


class History:
    def __init__(self, pid: int | str, session: int = 3):
        self.pid = str(pid)
        self.ole = olefile.OleFileIO(io.BytesIO(load_history_bytes(pid, session)))
        self.storages = sorted({tuple(e[:-1]) for e in self.ole.listdir()}, key=lambda p: (len(p), p))
        self.by_path: dict[str, tuple] = {}
        for s in self.storages:
            fp = self._raw(s, 'FullPath')
            if fp is not None:
                self.by_path[fp.decode('utf-8', 'replace').rstrip('\x00')] = s

    # ------------------------------------------------------------------ basics
    def _raw(self, storage: tuple, stream: str) -> bytes | None:
        p = '/'.join(list(storage) + [stream])
        return self.ole.openstream(p).read() if self.ole.exists(p) else None

    def node(self, full_path: str) -> tuple:
        if full_path not in self.by_path:
            raise KeyError(f'{full_path} not in history; known: {sorted(self.by_path)}')
        return self.by_path[full_path]

    def paths(self) -> list[str]:
        return sorted(self.by_path, key=lambda p: (p.count('/'), p))

    def parent_path(self, full_path: str) -> str:
        return full_path.rsplit('/', 1)[0]

    def text(self, full_path: str, stream: str) -> str | None:
        b = self._raw(self.node(full_path), stream)
        return None if b is None else b.decode('utf-8', 'replace').replace('\x00', '')

    def xml(self, full_path: str, stream: str = 'Parameters') -> ET.Element | None:
        t = self.text(full_path, stream)
        if t is None or not t.lstrip().startswith('<?xml'):
            return None
        return ET.fromstring(t[t.index('?>') + 2:].strip())

    # ----------------------------------------------------------------- markers
    @staticmethod
    def _parse_marker_body(d: bytes, off: int) -> dict:
        if d[off:off + 16] != MARKER_GUID:
            raise ValueError(f'no marker GUID at offset {off}')
        n = struct.unpack_from('<I', d, off + 16)[0]
        body = d[off + 20: off + 20 + n]
        p, fields = 0, {}
        while p < len(body):
            tag, size = struct.unpack_from('<II', body, p)
            fields[tag] = body[p + 8: p + 8 + size]
            p += 8 + size
        return fields

    def markers(self, full_path: str) -> list[HMarker]:
        """Resolve the full marker list of a node (bodies may live in ancestors)."""
        st = self.node(full_path)
        idx = self._raw(st, 'MarkerIndex')
        if idx is None:
            return []
        arr = np.frombuffer(idx, '<i4').reshape(-1, 5)
        # levels_up counts only ancestors that carry a MarkerIndex (e.g. an IIR Filters node
        # has none and is skipped), starting with this node as level 0.
        chain = [st[:k] for k in range(len(st), -1, -1) if self._raw(st[:k], 'MarkerIndex') is not None]
        cache: dict[int, bytes] = {}
        out = []
        for ch, pos, ln, off, up in arr:
            if int(up) not in cache:
                cache[int(up)] = self._raw(chain[int(up)], 'MarkerData') or b''
            f = self._parse_marker_body(cache[int(up)], int(off))
            ticks = struct.unpack('<q', f[0x103])[0] if len(f.get(0x103, b'')) == 8 else 0
            out.append(HMarker(type=f[0x100].decode('utf-8', 'replace'),
                               description=f.get(0x102, b'').decode('utf-8', 'replace'),
                               pos=int(pos), length=int(ln), channel=int(ch), levels_up=int(up), ticks=ticks))
        return out

    # ---------------------------------------------------------------- segments
    def segment_table(self, full_path: str) -> np.ndarray:
        b = self._raw(self.node(full_path), 'SegmentTable')
        return np.frombuffer(b, '<i4').reshape(-1, 2).copy() if b else np.zeros((0, 2), int)

    def artifact_intervals(self, full_path: str, stream: str = 'ArtifactIntervals') -> list[dict]:
        root = self.xml(full_path, stream)
        if root is None:
            return []
        out = []
        for bi in root.iter('BadInterval'):
            out.append({k: (int(bi.findtext(k)) if k != 'Artifact' else bi.findtext(k))
                        for k in ('nChannel', 'nStart', 'nLength', 'nSegment', 'Artifact')})
        return out

    # --------------------------------------------------------------------- ICA
    def ica(self, full_path: str) -> ICAData:
        d = self._raw(self.node(full_path), 'InternalData')
        off = 0

        def vec():
            nonlocal off
            n = struct.unpack_from('<I', d, off)[0]
            v = np.frombuffer(d, '<f8', n, off + 4).copy()
            off += 4 + 8 * n
            return v

        def mat():
            nonlocal off
            r, c = struct.unpack_from('<II', d, off)
            m = np.frombuffer(d, '<f8', r * c, off + 8).reshape(r, c).copy()
            off += 8 + 8 * r * c
            return m

        offset, mask, m1, m2 = vec(), vec(), mat(), mat()
        return ICAData(offset=offset, mask=mask, unmixing=m1, mixing=m2, trailing=d[off:])

    # -------------------------------------------------------- new reference node
    def new_reference(self, full_path: str) -> dict:
        """Parse the reference/apply channel lists from the node's Description text.

        The binary Parameters stream holds the same lists; the Description is the documented
        human-readable form and is cross-checked against the export channel list downstream.
        """
        t = self.text(full_path, 'Description')
        lines = [ln.strip() for ln in t.splitlines()]
        i = lines.index('Selected channels to include into the new reference:')
        ref = lines[i + 1].split()
        j = lines.index('Channels to which the new reference applies to:')
        applies = []
        k = j + 1
        while k < len(lines) and lines[k] and not lines[k].startswith('Remaining'):
            applies += lines[k].split()
            k += 1
        implicit_name = None
        for ln in lines:
            if ln.startswith('The old implicit reference is reused as channel'):
                implicit_name = ln.split()[-1]
        return {'reference': ref, 'applies_to': applies,
                'discard_remaining': any('are discarded' in ln for ln in lines),
                'implicit_name': implicit_name,
                'implicit_included': not any('implicit reference is not included' in ln for ln in lines),
                'text': t}
