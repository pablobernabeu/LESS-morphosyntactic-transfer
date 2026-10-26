"""Sample-level comparison metrics between reconstructed and exported trials.

The exports carry 3 decimals, so rounding alone contributes a uniform error with
RMSE 0.001/sqrt(12) = 0.00029 µV and |error| <= 0.0005 µV.
"""
from __future__ import annotations

import numpy as np


def metrics(err: np.ndarray, prefix: str = '') -> dict:
    a = np.abs(err).ravel()
    if a.size == 0:
        return {f'{prefix}n': 0, f'{prefix}rmse': np.nan, f'{prefix}p9999': np.nan, f'{prefix}max': np.nan}
    return {f'{prefix}n': int(a.size),
            f'{prefix}rmse': float(np.sqrt(np.mean(a ** 2))),
            f'{prefix}p9999': float(np.quantile(a, 0.9999)),
            f'{prefix}max': float(a.max())}


def distance_to_edges(abs_positions: np.ndarray, edges: list[int]) -> np.ndarray:
    """Distance (samples) from each absolute sample position to the nearest edge."""
    e = np.asarray(sorted(edges))
    idx = np.searchsorted(e, abs_positions)
    lo = e[np.clip(idx - 1, 0, len(e) - 1)]
    hi = e[np.clip(idx, 0, len(e) - 1)]
    return np.minimum(np.abs(abs_positions - lo), np.abs(hi - abs_positions))
