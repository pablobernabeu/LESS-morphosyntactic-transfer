"""New Reference transform (Analyzer "New Reference").

Sessions 3, 4 and 6 (and Session-2 ID 10's current history text)::

    Selected channels to include into the new reference: TP10 TP9
    The implicit reference is not included in the calculation of the new reference.
    Channels to which the new reference applies to: <30 channels>
    Remaining (non rereferenced) channels are discarded.
    The old implicit reference is reused as channel FCz

so each output channel is ``x_ch - mean(TP9, TP10)`` and the recovered implicit reference
(recorded as identically zero) becomes ``FCz = 0 - mean(TP9, TP10)``; output order is the
recorded order restricted to ``applies_to``, FCz last.

Session 2 (all other histories, task and resting state) differs in two settings::

    The implicit reference is included in the calculation of the new reference.
    Remaining (non rereferenced) channels are kept.

Including the implicit (zero) reference makes the new reference (TP9 + TP10 + 0) / 3, so
channels become ``x_ch - (TP9 + TP10) / 3`` and ``FCz = -(TP9 + TP10) / 3``. Keeping the
remaining channels leaves TP9, TP10 and the accelerometer channels in the output unchanged,
i.e. still referenced to the online reference. Output order is the full recorded order, FCz last.
"""
from __future__ import annotations

import numpy as np


def rereference(data: np.ndarray, names: list[str], reference: list[str], applies_to: list[str],
                implicit_name: str | None, implicit_included: bool = False,
                keep_remaining: bool = False) -> tuple[np.ndarray, list[str]]:
    """Return (rereferenced data, output channel names). ``data`` is channels x samples in µV."""
    missing = [c for c in reference + applies_to if c not in names]
    if missing:
        raise ValueError(f'channels not in recording: {missing}')
    if implicit_included:
        ref = np.sum([data[names.index(c)] for c in reference], axis=0) / (len(reference) + 1)
    else:
        ref = np.mean([data[names.index(c)] for c in reference], axis=0)
    targets = set(applies_to)
    out_names = [n for n in names if n in targets or keep_remaining]
    out = [data[names.index(n)] - ref if n in targets else data[names.index(n)] for n in out_names]
    if implicit_name:
        out.append(-ref)
        out_names.append(implicit_name)
    return np.vstack(out), out_names
