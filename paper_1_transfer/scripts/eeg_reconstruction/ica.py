"""Apply the stored "Ocular Correction ICA" solution (no refitting).

The node's ``InternalData`` holds (see history.ICAData): an offset vector o, a component
mask m (0 = removed), and two square matrices stored in the order W, A with A = W^-1
(max |W A - I| ~ 1e-14). Channels not enabled for ICA (FCz) have identity rows/columns.

Tested on ID 53, all 31 channels of 53_trialbytrial_S1_S101 (with the filter emulation in
filters.py)::

    x_clean = A @ diag(m) @ W @ (x - o) + o      RMSE 0.00029 µV  (export quantisation)
    same without the offset                      RMSE 0.0052 µV
    W @ diag(m) @ A, or either transpose         RMSE 14-17 µV

so the first stored matrix is the unmixing matrix, the second the mixing matrix, and the
offset (a per-channel mean removed before unmixing) must be subtracted and added back.
The components set to zero agree with the node's Description2 text.
"""
from __future__ import annotations

import numpy as np

from history import ICAData


def projection(ica: ICAData) -> np.ndarray:
    return ica.mixing @ np.diag(ica.mask) @ ica.unmixing


def apply(x: np.ndarray, ica: ICAData) -> np.ndarray:
    """x: channels x samples, channel order as in the ICA node's output (checked by caller)."""
    if x.shape[0] != ica.mixing.shape[0]:
        raise ValueError(f'{x.shape[0]} channels vs ICA matrices {ica.mixing.shape}')
    o = ica.offset[:, None]
    return projection(ica) @ (x - o) + o


def removed_components(ica: ICAData) -> list[int]:
    return [int(i) for i in np.where(ica.mask == 0)[0]]


def transport(ica: ICAData, Q: np.ndarray) -> ICAData:
    """Express a stored ICA solution in data transformed by an invertible linear map ``x' = Q x``.

    With W' = W Q^-1, A' = Q A and o' = Q o the same components are estimated from x' and
    removed, and the cleaned data are Q times the cleaned original data:
    A' diag(m) W' (x' - o') + o' = Q [A diag(m) W (x - o) + o]. This is the exact way to apply a
    solution fitted under one reference to data under another (re-referencing is linear and,
    when the full channel set is kept, invertible).
    """
    Qi = np.linalg.inv(Q)
    return ICAData(offset=Q @ ica.offset, mask=ica.mask.copy(), unmixing=ica.unmixing @ Qi,
                   mixing=Q @ ica.mixing, trailing=ica.trailing)
