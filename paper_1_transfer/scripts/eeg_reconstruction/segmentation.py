"""Marker-based segmentation as in Analyzer's "Segmentation" transform.

Two levels are used in the LESS histories:

* ``Segmentation S1``/``S2`` on continuous data: reference marker ``Stimulus/S  1`` (``S  2``),
  -120..1080 ms (600 points). Candidates are generated in marker order; a segment is kept if it
  lies inside the recording, does not overlap the previously kept segment when overlap is
  disallowed, and, where "Skip bad intervals" is set (ID 16 only, which also allows overlap),
  does not overlap a Bad Interval marker from the manual Raw Data Inspection. The result equals the stored SegmentTable for
  all 18 nodes. No S-segment of the nine recordings lies across a New Segment marker, so how
  Analyzer treats that case is untested.
* ``[S1_]Segmentation S10x tbt`` on the segmented output of Artifact Rejection: reference marker
  ``S101``/``S102``/``S103``, -130..1070 ms. On segmented data a new segment must lie completely
  inside one parent segment, so a trial exists only if S10x follows S  1/S  2 by exactly 5
  samples (10 ms). A lag of 6 samples (or 4) puts the window 1 sample outside the parent and the
  trial is not created. This rule alone removes 909 of the 2,587 S10x events in the retained
  parent segments of the nine recordings (see ``lost_to_marker_lag`` in metrics_per_file.csv).
"""
from __future__ import annotations

from dataclasses import dataclass

import numpy as np


@dataclass
class Segment:
    start: int          # 0-based first sample in the parent's data
    length: int
    ref_pos: int        # 0-based reference marker position in the parent's data
    parent_index: int = -1


def ms_to_points(ms: float, fs: float) -> int:
    return int(round(ms * fs / 1000.0))


def marker_segments(markers, n_samples: int, desc: str, start_ms: float, length_ms: float, fs: float,
                    allow_overlap: bool, mtype: str = 'Stimulus') -> list[Segment]:
    s0 = ms_to_points(start_ms, fs)
    n = ms_to_points(length_ms, fs)
    out: list[Segment] = []
    for m in sorted((m for m in markers if m.type == mtype and m.description == desc), key=lambda m: m.pos):
        a = m.pos + s0
        if a < 0 or a + n > n_samples:
            continue
        if not allow_overlap and out and a < out[-1].start + out[-1].length:
            continue
        out.append(Segment(start=a, length=n, ref_pos=m.pos))
    return out


def sub_segments(parent_segments: list[Segment], markers_by_segment: list[list], desc: str,
                 start_ms: float, length_ms: float, fs: float, bad_by_segment: list[list] | None = None,
                 mtype: str = 'Stimulus') -> list[Segment]:
    """Segment already-segmented data.

    ``markers_by_segment[i]`` are the markers of parent segment i, positions relative to its
    start. ``bad_by_segment[i]`` are (start, length) bad intervals in the same frame, or None to
    skip nothing (what the LESS exports amount to; see pipeline.Reconstruction.trials).
    The returned ``start`` is relative to the concatenated parents, as in a SegmentTable.
    """
    s0 = ms_to_points(start_ms, fs)
    n = ms_to_points(length_ms, fs)
    out = []
    offset = 0
    for i, (ps, mks) in enumerate(zip(parent_segments, markers_by_segment)):
        for m in sorted((m for m in mks if m.type == mtype and m.description == desc), key=lambda m: m.pos):
            a = m.pos + s0
            if a < 0 or a + n > ps.length:
                continue
            if bad_by_segment is not None and any(b0 < a + n and a < b0 + bl for b0, bl in bad_by_segment[i]):
                continue
            out.append(Segment(start=offset + a, length=n, ref_pos=m.pos, parent_index=i))
        offset += ps.length
    return out


def table(segments: list[Segment]) -> np.ndarray:
    return np.array([[s.start, s.length] for s in segments], dtype=np.int64).reshape(-1, 2)
