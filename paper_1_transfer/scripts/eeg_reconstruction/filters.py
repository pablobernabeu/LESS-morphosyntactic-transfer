"""Emulation of Analyzer 2's "IIR Filters" transform (zero-phase Butterworth).

What was established empirically (ID 53, FCz, which the ICA leaves untouched)
-----------------------------------------------------------------------------
1. Order compensation. The history says "order 4" (24 dB/oct). Analyzer realises this as a
   2nd-order Butterworth run forwards and backwards, so the total order is 4. Running a
   4th-order design forwards and backwards (RMSE 0.95 µV over all channels of ID 53) or a
   2nd-order design at the nominal cutoffs (0.74 µV) does not match.
2. Cutoff compensation. The single-pass cutoff is moved so that the *two-pass* response is
   -3 dB at the nominal cutoff, with the adjustment made on the bilinear (tan-warped)
   frequency axis:  tan(pi*f'/fs) = tan(pi*f/fs) * c^(+/-1),  c = (sqrt(2)-1)^(1/(2N)),
   N = single-pass order (2). For 1 Hz / 30 Hz at 500 Hz this gives 0.802247 Hz and
   37.154425 Hz; a free 1-D search for the low-pass cutoff on FCz returned 37.154426 Hz.
   Scaling on the linear axis (0.0127 µV) or a bilinear transform without pre-warping
   (0.035 µV) is clearly worse than the warped design (0.0019 µV when filtering the whole
   record, before point 3).
3. On-demand (uncached) evaluation. The node's ``CompleteCache`` parameter is false, so
   Analyzer did not filter the whole recording. Each request for samples [a, b) is served
   by filtering the parent's samples [a - M, b + M] and returning the middle part. The
   exported trials therefore carry chunk-edge transients. Filtering the continuous record
   (scipy ``sosfiltfilt``) leaves a smooth residual of 0.0019 µV RMSE (0.036 µV max, all
   channels of ID 53), growing towards the segment edges; the chunk model with M = 970
   samples reduces it to export quantisation (0.00029 µV RMSE). M is sharp: 969 or 971 give
   ~0.0008 µV, 965 or 975 ~0.0014 µV, 1000 gives 0.0022 µV (explore_filters.py). The same
   M holds for all nine recordings.
4. Pass structure inside a chunk: the high-pass is applied forwards then backwards, then
   the low-pass forwards then backwards (not one combined cascade: 0.0009 µV), and every pass
   starts from the steady state of its first input sample (``sosfilt_zi * x[0]``). Zero
   initial state (0.0015 µV after removing the first sample, 0.33 µV on raw values) or
   float32 arithmetic (0.077 µV) does not reach quantisation level. Results for IDs 53 and 60
   are in filter_variants.csv.

5. The margin rule. M = ceil(ln(1e-3) / ln(r)), r = largest pole radius of the single-pass
   high-pass section (``decay_margin``): 970 at 1 Hz, 9,691 at 0.1 Hz (500 Hz sampling).
   Confirmed at 0.1 Hz on four unaffected Session-3 recordings (IDs 10, 51, 58, 59;
   validate_margin.py, margin_validation.csv): RMSE 0.00030-0.00034 µV, p99.99 <= 0.0017 µV.
   At 0.1 Hz M +/- 1 sample raises RMSE 10-30 fold; fixed alternatives (970, 9,700, 5/10/15
   time constants), e = 1e-2 or 1e-4, and whole-record filtering (0.007-0.009 µV) all fail.
6. Discontinuities. A New Segment marker bounds the chunk: the chunk is clipped at the
   marker and filtering restarts there from the steady state of the first sample after it
   (IDs 58 and 59, trials 8-16 s from a "LostSamples" marker: 0.14-0.34 µV RMSE if the
   marker is ignored, quantisation level if it bounds the chunk). A segment that spans a
   marker was not observed and is handled part by part as an assumption.
"""
from __future__ import annotations

import numpy as np
from scipy import signal

#: chunk margin (samples) found for the 1 Hz / 30 Hz nodes at 500 Hz
MARGIN_1HZ_500HZ = 970


def compensated_cutoff(fc: float, fs: float, single_pass_order: int, kind: str) -> float:
    """Single-pass cutoff giving a -3 dB two-pass (forward-backward) response at ``fc``."""
    c = (np.sqrt(2.0) - 1.0) ** (1.0 / (2 * single_pass_order))
    w = np.tan(np.pi * fc / fs)
    w = w * c if kind == 'highpass' else w / c
    return float(np.arctan(w) * fs / np.pi)


def design(low_cutoff: float | None, high_cutoff: float | None, fs: float,
           nominal_order: int = 4) -> dict:
    """Return second-order sections for the high-pass ('hp') and low-pass ('lp') stages.

    ``nominal_order`` is the order shown by Analyzer (Slope24 -> 4); each pass uses half.
    """
    if nominal_order % 2:
        raise ValueError('odd nominal orders are not handled')
    n = nominal_order // 2
    out = {}
    if low_cutoff:
        f = compensated_cutoff(low_cutoff, fs, n, 'highpass')
        out['hp'] = signal.butter(n, f, 'highpass', fs=fs, output='sos')
        out['hp_single_pass_hz'] = f
    if high_cutoff:
        f = compensated_cutoff(high_cutoff, fs, n, 'lowpass')
        out['lp'] = signal.butter(n, f, 'lowpass', fs=fs, output='sos')
        out['lp_single_pass_hz'] = f
    return out


def decay_margin(sos: np.ndarray, eps: float = 1e-3) -> int:
    """Analyzer's on-demand chunk margin: samples for the slowest pole to decay to ``eps``.

    Validated for the 1 Hz (970) and 0.1 Hz (9,691) Slope24 high-pass at 500 Hz (point 5 above).
    Other cutoffs, orders or sampling rates are untested.
    """
    _, p, _ = signal.sos2zpk(sos)
    return int(np.ceil(np.log(eps) / np.log(np.abs(p).max())))


def _pass_steady(sos: np.ndarray, x: np.ndarray) -> np.ndarray:
    """One forward pass over the last axis starting from the steady state of x[..., 0]."""
    zi = signal.sosfilt_zi(sos)                       # (sections, 2)
    zi = zi[:, None, :] * x[None, :, 0][:, :, None]  # (sections, channels, 2)
    return signal.sosfilt(sos, x, axis=-1, zi=zi)[0]


def zero_phase_steady(sos: np.ndarray, x: np.ndarray) -> np.ndarray:
    y = _pass_steady(sos, x)
    return _pass_steady(sos, y[:, ::-1])[:, ::-1]


def filter_chunk(x: np.ndarray, sos: dict) -> np.ndarray:
    """High-pass forward-backward, then low-pass forward-backward (x: channels x samples)."""
    y = x
    if 'hp' in sos:
        y = zero_phase_steady(sos['hp'], y)
    if 'lp' in sos:
        y = zero_phase_steady(sos['lp'], y)
    return y


def on_demand(x: np.ndarray, start: int, length: int, sos: dict, margin: int,
              lo_limit: int = 0, hi_limit: int | None = None) -> np.ndarray:
    """Emulate an uncached Analyzer filter request for samples [start, start+length).

    The chunk [start-margin, start+length+margin) is clipped to [lo_limit, hi_limit), which
    are the bounds of the data block the request is served from (the recording, or a
    discontinuity-delimited part of it; see pipeline.py for which applies).
    """
    hi_limit = x.shape[1] if hi_limit is None else hi_limit
    a = max(lo_limit, start - margin)
    b = min(hi_limit, start + length + margin)
    if start < a or start + length > b:
        raise ValueError('request outside the permitted block')
    y = filter_chunk(x[:, a:b], sos)
    return y[:, start - a: start - a + length]


def continuous(x: np.ndarray, sos: dict) -> np.ndarray:
    """Whole-record zero-phase filtering (what cached Analyzer filtering would approximate)."""
    return filter_chunk(x, sos)
