"""Where the EEG export audit reads its inputs and writes its outputs.

Inputs come from the project's read-only data tree: the raw BrainVision marker files
(``raw data/EEG/Session <s>/Raw``), the Analyzer histories (``.../History``), the legacy
trial-by-trial exports (``.../Export``), the OpenSesame logs (``raw data/behavioural data from
lab sessions/Session <s>``) and the participant key. On the cluster the tree is
``$LES_DATA_ROOT`` (set by ``_shared/hpc/arc_env.sh``); elsewhere it defaults to ``data/`` beside
the code root, as the R pipeline's ``data_path()`` and the reconstruction's ``paths.py`` do.

Intermediate outputs (event tables of up to 25 MB, per-node tables, logs) go to
``<store>/paper_1_transfer/data_derived/eeg_audit/<stage>/``, where ``<store>`` is ``$LES_STORE``
or, when that is unset, the code root, exactly as ``paper1_derived()`` resolves it. That folder
is not under version control. ``$LES_AUDIT_OUT`` replaces the whole ``.../eeg_audit`` root when
the audit is to run against another output tree. The two small manuscript-facing tables go to
``<store>/paper_1_transfer/results/`` like every other results file.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

#: code root: paper_1_transfer/audit/audit_paths.py -> two levels up
CODE_ROOT = Path(__file__).resolve().parents[2]
SESSIONS = (2, 3, 4, 6)


def data_root() -> Path:
    env = os.environ.get('LES_DATA_ROOT')
    return Path(env) if env else CODE_ROOT / 'data'


def eeg_root() -> Path:
    return data_root() / 'raw data' / 'EEG'


def eeg_dir(session: int) -> Path:
    return eeg_root() / f'Session {session}'


def behaviour_root() -> Path:
    return data_root() / 'raw data' / 'behavioural data from lab sessions'


def participant_key() -> Path:
    """The key copy under ``raw data/``, which the cell table (n7_09) has always read."""
    return data_root() / 'raw data' / 'Participant IDs and session progress.csv'


def store_root() -> Path:
    env = os.environ.get('LES_STORE')
    return Path(env) if env else CODE_ROOT


def audit_root() -> Path:
    env = os.environ.get('LES_AUDIT_OUT')
    return Path(env) if env else store_root() / 'paper_1_transfer' / 'data_derived' / 'eeg_audit'


def out_dir(stage: str) -> Path:
    """Folder of one audit stage, created on demand."""
    d = audit_root() / stage
    d.mkdir(parents=True, exist_ok=True)
    return d


def results_dir() -> Path:
    d = store_root() / 'paper_1_transfer' / 'results'
    d.mkdir(parents=True, exist_ok=True)
    return d


def use_reconstruction_modules() -> None:
    """Make ``bv_io``, ``history`` and ``paths`` of ``scripts/eeg_reconstruction`` importable.

    The trial-identity stage reads exports and histories with the same parsers as the
    reconstruction, which were validated against Analyzer's own output (that folder's README).
    """
    p = str(CODE_ROOT / 'paper_1_transfer' / 'scripts' / 'eeg_reconstruction')
    if p not in sys.path:
        sys.path.insert(0, p)
