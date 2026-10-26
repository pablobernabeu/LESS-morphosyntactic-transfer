"""Scripted reconstruction of the LESS Session-3 Analyzer chain up to the trial-by-trial exports.

Chain (node names as in the histories; ID 65 has an extra "Edit Markers" node first)::

    Raw Data [/Edit Markers] /Raw Data Inspection /New Reference /Filters
      /Ocular Correction ICA /Segmentation S{1,2} /Artifact Rejection
      /[S1_]Segmentation S10{1,2,3} tbt /Generic Data Export

Markers (including the manual Raw Data Inspection bad intervals and the Edit Markers change
for ID 65) are taken from the history of the node feeding the segmentation, resolved through
``History.markers``. They do not depend on the signal processing, so they carry over unchanged
to a re-run with another high-pass cutoff.

Signal path per S-segment (validated on all 54 exports of the nine recordings):
    raw float32 counts x resolution -> New Reference (TP9/TP10 mean, FCz recovered)
    -> on-demand IIR chunk [start-M, end+M], clipped at New Segment markers, with
       M = ceil(ln 1e-3 / ln r) (970 at 1 Hz, 9,691 at 0.1 Hz): 2nd-order Butterworth high-pass
       forwards and backwards, then low-pass forwards and backwards, steady-state initial
       conditions, cutoffs compensated for the two passes (filters.py)
    -> stored ICA projection A diag(m) W (x - o) + o (ica.py) -> 600-sample segment.
The 0.1 Hz behaviour (margin rule, discontinuities) was validated on unaffected recordings
10, 51, 58 and 59 (validate_margin.py).

Trial identity: see ``Reconstruction.trials``.

Known limits: a segment spanning a New Segment marker, a file edge inside a chunk, and other
cutoffs, orders or sampling rates were not observed.
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np

import filters
import ica as ica_mod
import paths
import segmentation as sg
from bv_io import read_raw
from history import History
from rereference import rereference

#: Session-3 recordings preprocessed at 1 Hz in error (docs/eeg_filter_reprocessing_protocol.md,
#: which must list the same IDs as LES_P1_MISFILTERED in ../_config.R). The protocol allows
#: them only the archived 1 Hz (to validate the route) and the intended 0.1 Hz; any other
#: cutoff is refused. That every validation gate has passed before a 0.1 Hz run is checked
#: by reprocess.py, which is the only entry point that requests one.
AFFECTED_1HZ = {7, 8, 9, 16, 53, 60, 61, 62, 65}
PERMITTED_CUTOFFS_AFFECTED = {1.0, 0.1}


@dataclass
class BranchResult:
    branch: str
    seg_node: str
    segments: list                       # S-level segments (continuous positions)
    seg_table_match: bool
    data: np.ndarray                     # channels x segments x 600 (after ICA)
    channel_names: list
    markers_by_segment: list             # per segment, positions relative to its start


class Reconstruction:
    def __init__(self, pid: int | str, low_cutoff: float = 1.0, high_cutoff: float = 30.0,
                 margin: int | None = None, filter_mode: str = 'on_demand', block_mode: str = 'new_segment',
                 raw_dir: Path | None = None, export_dir: Path | None = None,
                 session: int = 3, reference_override: dict | None = None, signal: bool = True):
        """
        session      : LESS session (histories and exports are read from that session's tree).
        raw_dir, export_dir : default to the data tree (paths.py).
        signal       : False reads only the history (markers, segment tables) and no samples,
                       which is all a marker file needs (export_writer.vmrk_bytes); parent
                       segments are then taken from the stored SegmentTable.
        reference_override : replaces fields of the New Reference settings parsed from the
                       history (keys as in History.new_reference), for testing alternatives.
        low_cutoff   : high-pass cutoff in Hz as Analyzer displays it (default 1.0 for validation).
        margin       : chunk margin for on-demand filtering; None = filters.decay_margin of the
                       high-pass design (validated at 1 Hz and 0.1 Hz, filters.py point 5).
        filter_mode  : 'on_demand' (emulate uncached Analyzer) or 'continuous'.
        block_mode   : bounds for filtering: 'new_segment' (default, validated on IDs 58 and 59:
                       chunks are clipped at New Segment markers; a segment spanning one would
                       be filtered part by part, untested) or 'recording' (ignore the markers).
        """
        self.pid = str(pid)
        self.session = session
        if session == 3 and int(pid) in AFFECTED_1HZ and low_cutoff not in PERMITTED_CUTOFFS_AFFECTED:
            raise PermissionError(f'ID {pid} may only be run at 1 Hz (validation) or 0.1 Hz (protocol)')
        self.h = History(pid, session=session)
        self.low_cutoff, self.high_cutoff = low_cutoff, high_cutoff
        self._margin_arg = margin
        self.filter_mode = filter_mode
        self.block_mode = block_mode
        self.reference_override = reference_override or {}
        self.raw_dir = Path(raw_dir) if raw_dir else paths.raw_dir(pid, session)
        self.export_dir = Path(export_dir) if export_dir else paths.export_dir(session)
        self._find_chain()
        if signal:
            self._load()
        else:
            self._load_markers_only()

    def _load_markers_only(self):
        from bv_io import read_header
        self.header = read_header(self.raw_dir / f'{self.pid}.vhdr')
        self.fs = self.header.sfreq
        br, cond = next(iter(self.export_nodes))   # the exports share one channel list
        self.names = read_header(self.export_dir / f'{self.pid}_trialbytrial_{br}_{cond}.vhdr').channel_names
        self.x = None
        self.cont_markers = self.h.markers(self.ica_node)

    # ------------------------------------------------------------------ chain
    def _find_chain(self):
        # Take the chain from the export headers: some histories contain side branches
        # (e.g. ID 7 "Raw Data Inspection Reprocess Backup") with their own ICA node.
        from bv_io import read_header
        import re
        paths = set()
        self.export_nodes = {}
        for f in sorted(self.export_dir.glob(f'{self.pid}_trialbytrial_S*_S10*.vhdr')):
            if 'Copy' in f.name:
                continue
            hp = read_header(f).comment_first_line.split('history path: ', 1)[1].strip()
            paths.add(hp.split('/Ocular Correction ICA/')[0] + '/Ocular Correction ICA')
            m = re.search(r'_trialbytrial_(S\d)_(S10\d)\.vhdr$', f.name)
            self.export_nodes[(m.group(1), m.group(2))] = hp
        if len(paths) != 1:
            raise RuntimeError(f'exports do not share one ICA node: {paths}')
        self.ica_node = paths.pop()
        if self.ica_node not in self.h.by_path:
            raise RuntimeError(f'{self.ica_node} not in history')
        self.filter_node = self.h.parent_path(self.ica_node)
        self.reref_node = self.h.parent_path(self.filter_node)
        self.inspection_node = self.h.parent_path(self.reref_node)
        if not (self.filter_node.endswith('/Filters') and self.reref_node.endswith('/New Reference')
                and self.inspection_node.endswith('/Raw Data Inspection')):
            raise RuntimeError('unexpected chain above ICA: ' + self.ica_node)
        # A few histories frame the recording before inspecting it: an Edit Markers node adds
        # Start/End markers and a "Segmentation" node keeps the one segment between them
        # (Session 6 of lab ID 5). Every position below that node is relative to the frame,
        # so the raw samples are cropped to it before anything else. The nine Session-3
        # records inspect the raw data directly and have no frame.
        # Analysts sometimes suffixed node names ("Segmentation - do not change"), so the node
        # type is read from the start of the name.
        self.frame = None
        above = self.h.parent_path(self.inspection_node)
        kind = above.rsplit('/', 1)[1]
        if kind.startswith('Segmentation'):
            st = self.h.segment_table(above)
            if len(st) != 1:
                raise NotImplementedError(f'{above}: {len(st)} segments; only a single frame is handled')
            self.frame = (int(st[0, 0]), int(st[0, 1]))
        elif not (kind == 'Raw Data' or kind.startswith('Edit Markers')):
            raise RuntimeError('unexpected node above the raw-data inspection: ' + above)

    def _load(self):
        h = self.h
        self.header, raw, _ = read_raw(self.raw_dir / f'{self.pid}.vhdr')
        if self.frame:
            a, n = self.frame
            if a + n > raw.shape[1]:
                raise RuntimeError(f'frame {self.frame} runs past the recording ({raw.shape[1]} samples)')
            raw = raw[:, a:a + n]
        self.fs = self.header.sfreq
        rr = h.new_reference(self.reref_node)
        rr['keep_remaining'] = 'channels are kept' in rr['text']
        rr.update(self.reference_override)
        self.reref_info = rr
        self.x, self.names = rereference(raw, self.header.channel_names, rr['reference'], rr['applies_to'],
                                         rr['implicit_name'], rr['implicit_included'], rr['keep_remaining'])
        del raw
        fx = h.xml(self.filter_node)
        dflt = fx.find('DefaultFilter')
        if fx.findtext('IndividualFilters') != 'false' or dflt.findtext('NotchEnable') != 'false':
            raise NotImplementedError('per-channel filters or notch not handled')
        self.hist_low = float(dflt.findtext('LowCutoffFrequency')) if dflt.findtext('LowCutoffEnable') == 'true' else None
        self.hist_high = float(dflt.findtext('HighCutoffFrequency')) if dflt.findtext('HighCutoffEnable') == 'true' else None
        slopes = {dflt.findtext('LowCutoffSlope'), dflt.findtext('HighCutoffSlope')}
        if slopes != {'Slope24'}:
            raise NotImplementedError(slopes)
        self.complete_cache = fx.findtext('CompleteCache') == 'true'
        self.sos = filters.design(self.low_cutoff, self.high_cutoff, self.fs, nominal_order=4)
        self.margin = filters.decay_margin(self.sos['hp']) if self._margin_arg is None else self._margin_arg
        self.ica = h.ica(self.ica_node)
        ica_names = [e.text for e in h.xml(self.ica_node).find('NamesChosenChannels')]
        if [n for n in self.names if n in ica_names] != ica_names:
            raise RuntimeError('ICA channel order differs from data order')
        self.cont_markers = h.markers(self.ica_node)  # input markers of the segmentations
        n = self.x.shape[1]
        cuts = sorted({m.pos for m in self.cont_markers if m.type == 'New Segment' and m.pos > 0})
        self.blocks = list(zip([0] + cuts, cuts + [n]))
        self._continuous = None

    # ---------------------------------------------------------------- filters
    def filtered_segment(self, start: int, length: int) -> np.ndarray:
        blocks = [(0, self.x.shape[1])] if self.block_mode == 'recording' else self.blocks
        if self.filter_mode == 'continuous':
            if self._continuous is None:
                self._continuous = np.hstack([filters.continuous(self.x[:, lo:hi], self.sos) for lo, hi in blocks])
            y = self._continuous[:, start:start + length]
        else:
            parts = []
            for lo, hi in blocks:  # a segment spanning a boundary is served block by block
                a, b = max(lo, start), min(hi, start + length)
                if a < b:
                    parts.append(filters.on_demand(self.x, a, b - a, self.sos, self.margin, lo, hi))
            y = np.hstack(parts)
        return ica_mod.apply(y, self.ica)

    # ----------------------------------------------------------- segmentation
    def branch(self, branch: str, with_data: bool = True) -> BranchResult:
        seg_node = f'{self.ica_node}/Segmentation {branch}'
        x = self.h.xml(seg_node)
        sel = x.find('SelectedMarkers/SelectedMarker')
        desc, mtype = sel.findtext('Description'), sel.findtext('Type')
        if x.findtext('MarkerABE') or x.findtext('Operation') != 'Marker':
            raise NotImplementedError('only plain marker segmentation handled')
        allow_overlap = x.findtext('AllowOverlap') == 'true'
        skip_bad = x.findtext('MarkerSkipBadIntervals') == 'true'
        stored = self.h.segment_table(seg_node)
        if self.x is None:
            # Markers-only mode: the recording length is unknown, so the stored table is the
            # segmentation (it is Analyzer's own record of it).
            s0 = sg.ms_to_points(float(x.findtext('MarkerStartTime')), self.fs)
            segs = [sg.Segment(start=int(a), length=int(n), ref_pos=int(a) - s0) for a, n in stored]
        else:
            segs = sg.marker_segments(self.cont_markers, self.x.shape[1], desc, float(x.findtext('MarkerStartTime')),
                                      float(x.findtext('MarkerSegmentTime')), self.fs, allow_overlap, mtype)
            if skip_bad:
                bad = [(m.pos, m.length) for m in self.cont_markers if m.type == 'Bad Interval']
                segs = [s for s in segs if not any(b0 < s.start + s.length and s.start < b0 + bl for b0, bl in bad)]
        match = np.array_equal(sg.table(segs), stored)
        data = (np.stack([self.filtered_segment(s.start, s.length) for s in segs], axis=1)
                if with_data and self.x is not None else None)
        mbs = []
        for s in segs:
            mbs.append([type(m)(m.type, m.description, m.pos - s.start, m.length, m.channel, m.levels_up)
                        for m in self.cont_markers
                        if s.start <= m.pos < s.start + s.length and m.type not in ('Bad Interval', 'New Segment')])
        return BranchResult(branch, seg_node, segs, match, data, list(self.names), mbs)

    def trials(self, branch: str, cond: str, b: BranchResult | None = None) -> tuple[list[int], np.ndarray]:
        """Trials of ``{id}_trialbytrial_{branch}_{cond}`` under the rule the archived exports follow.

        Established on all 54 exports of the nine recordings (validate.py):

        * parent segments removed by hand in the Artifact Rejection node are dropped (their
          absence from that node's SegmentTable is the record; IDs 7 and 65 only);
        * a trial exists only if the S10x marker lies exactly 5 samples after S  1/S  2, because
          the -130..1070 ms window must fit inside the -120..1080 ms parent segment;
        * the Artifact Rejection node's detected intervals are NOT applied: the node wrote no
          Bad Interval markers, so "Skip bad intervals" in the tbt segmentation had nothing to
          skip (15 exported trials lie in segments with stored detections).

        Returns (absolute 0-based start samples, data[channels, trials, points]).
        """
        b = b or self.branch(branch)
        seglen = b.segments[0].length
        keep = (self.h.segment_table(self.ar_node(branch))[:, 0] // seglen).tolist()
        tx = self.h.xml(self.tbt_node(branch, cond))
        subs = sg.sub_segments([b.segments[i] for i in keep], [b.markers_by_segment[i] for i in keep], cond,
                               float(tx.findtext('MarkerStartTime')), float(tx.findtext('MarkerSegmentTime')),
                               self.fs, None)
        starts, data = [], []
        for s in subs:
            local = s.start - s.parent_index * seglen
            if local != 0 or s.length != seglen:
                raise RuntimeError('trial not aligned with its parent segment')
            starts.append(b.segments[keep[s.parent_index]].start)
            if b.data is not None:
                data.append(b.data[:, keep[s.parent_index], :])
        if not np.array_equal(sg.table(subs), self.h.segment_table(self.tbt_node(branch, cond))):
            raise RuntimeError(f'{self.pid} {branch} {cond}: trial identity differs from the history')
        return starts, (np.stack(data, axis=1) if b.data is not None else None)

    def tbt_node(self, branch: str, cond: str) -> str:
        """The segmentation node the export ``{id}_trialbytrial_{branch}_{cond}`` was written from."""
        p = self.export_nodes[(branch, cond)]
        if p not in self.h.by_path:
            raise KeyError(p)
        return p

    def ar_node(self, branch: str) -> str:
        """Parent of the branch's tbt nodes ("Artifact Rejection"; "Artifact rejection tbt" in Session 2)."""
        parents = {self.h.parent_path(p) for (br, _), p in self.export_nodes.items() if br == branch}
        if len(parents) != 1:
            raise RuntimeError(f'{branch}: tbt exports have different parents {parents}')
        p = parents.pop()
        if p != f'{self.ica_node}/Segmentation {branch}/' + p.rsplit('/', 1)[1]:
            raise RuntimeError(f'unexpected artefact-rejection node {p}')
        return p
