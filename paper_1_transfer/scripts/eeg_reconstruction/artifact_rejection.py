"""Analyzer "Artifact Rejection" (semi-automatic inspection) criteria on segmented data.

Node parameters in the LESS histories (Method 2 = semi-automatic, IndividualChannelMode false,
CheckIntervalsInSegments false, WriteOnlyMarkers false) on 30 channels (FCz excluded):

* Gradient:     |x[i] - x[i-1]| / sampling interval (ms) > 30 µV/ms
* Max-Min:      max - min > 100 µV within a 200 ms (100-point) window
* Low activity: max - min < 0.5 µV within a 100 ms (50-point) window
* "mark as bad" 200 ms before and after the event.

What the nine 1 Hz histories show (validate.py, artifact_rejection.csv)
-----------------------------------------------------------------------
* The node's ``ArtifactIntervals`` stream holds per-channel intervals (``nChannel`` = 0-based
  index in the 31-channel data order, ``nStart`` in the concatenated segments). Rerunning the
  criteria on the reconstructed data reproduces all 68 stored intervals and finds no others:
  every detection is Max-Min; Gradient and Low activity never fire. See
  ``validate.auto_intervals`` for the interval-extent convention (ends reproduced to +/-1 sample).
* Those intervals were not turned into markers: none of the 18 Artifact Rejection nodes on the
  export chains carries a single ``Bad Interval`` marker. The downstream "Skip bad intervals"
  therefore removed nothing, and 15 exported trials (IDs 7, 62, 65) lie in segments with
  stored detections.
* Manual decisions are the only ones that took effect: whole segments removed by hand, recorded
  as their absence from the node's ``SegmentTable`` (ID 7 S2 segment 56; ID 65 S1 49, 50 and
  S2 101, 120), mostly accompanied by all-channel "Userdefined" ``UserEditIntervals`` in the
  node's Parameters (not for ID 65 S1 segment 50).
"""
from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np
from numpy.lib.stride_tricks import sliding_window_view


@dataclass
class ARParams:
    channels: list[str]
    check_gradient: bool = True
    max_gradient: float = 30.0          # µV/ms
    check_difference: bool = True
    max_difference: float = 100.0       # µV
    difference_ms: float = 200.0
    check_activity: bool = True
    min_activity: float = 0.5           # µV
    activity_ms: float = 100.0
    before_ms: dict = field(default_factory=lambda: {'gr': 200.0, 'di': 200.0, 'ac': 200.0})
    after_ms: dict = field(default_factory=lambda: {'gr': 200.0, 'di': 200.0, 'ac': 200.0})

    @classmethod
    def from_xml(cls, root) -> 'ARParams':
        g = lambda k: root.findtext(k)
        b = lambda k: g(k) == 'true'
        f = lambda k: float(g(k))
        if b('IndividualChannelMode') or b('CheckIntervalsInSegments') or b('CheckAmplitude'):
            raise NotImplementedError('artefact-rejection options not seen in the LESS histories')
        return cls(channels=[e.text for e in root.findall('Enabled_x0020_Channels')],
                   check_gradient=b('CheckGradient'), max_gradient=f('MaxGradient'),
                   check_difference=b('CheckDifference'), max_difference=f('MaxDifference'),
                   difference_ms=f('DiIntervalLength'), check_activity=b('CheckActivity'),
                   min_activity=f('MinActivity'), activity_ms=f('AcIntervalLength'),
                   before_ms={'gr': f('GrBefore'), 'di': f('DiBefore'), 'ac': f('AcBefore')},
                   after_ms={'gr': f('GrAfter'), 'di': f('DiAfter'), 'ac': f('AcAfter')})


def _window_range(x: np.ndarray, n: int) -> np.ndarray:
    """max - min over every window of n points lying fully inside the segment."""
    if x.shape[-1] < n:
        return np.zeros(x.shape[:-1] + (0,))
    w = sliding_window_view(x, n, axis=-1)
    return w.max(-1) - w.min(-1)


def detect(seg: np.ndarray, p: ARParams, fs: float) -> list[tuple]:
    """Detections in one segment (channels x points, restricted to ``p.channels`` in that order).

    Returns (criterion, channel_index, first_sample, last_sample): the two samples of a gradient
    step, or the window of a Max-Min / Low-activity violation.
    """
    dt_ms = 1000.0 / fs
    det = []
    if p.check_gradient:
        g = np.abs(np.diff(seg, axis=-1)) / dt_ms
        for c, i in zip(*np.nonzero(g > p.max_gradient)):
            det.append(('gr', int(c), int(i), int(i) + 1))
    if p.check_difference:
        n = int(round(p.difference_ms / dt_ms))
        for c, i in zip(*np.nonzero(_window_range(seg, n) > p.max_difference)):
            det.append(('di', int(c), int(i), int(i) + n - 1))
    if p.check_activity:
        n = int(round(p.activity_ms / dt_ms))
        for c, i in zip(*np.nonzero(_window_range(seg, n) < p.min_activity)):
            det.append(('ac', int(c), int(i), int(i) + n - 1))
    return det
