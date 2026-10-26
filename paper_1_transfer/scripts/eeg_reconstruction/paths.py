"""Where the reconstruction reads its inputs.

Every input comes from the project's data tree, which is read-only: the raw BrainVision
recordings (``raw data/EEG/Session <s>/Raw``), the Analyzer histories (``.../History``) and
the legacy trial-by-trial exports (``.../Export``). On the cluster the tree is
``$LES_DATA_ROOT`` (set by ``_shared/hpc/arc_env.sh``); elsewhere it defaults to ``data/``
beside the code root, as the R pipeline's ``data_path()`` does.

The raw signal files (``.eeg``) are too large for version control and are archived on OSF
(component ``tq7vy``). On the cluster they sit in the data tree beside their headers
(HPC_RUNBOOK.md, section 0). A development machine that keeps them elsewhere can point
``LES_EEG_RAW_DIR`` at one or more directories (separated by ``os.pathsep``); the first
that holds ``<id>.vhdr`` is used, and the data tree's ``Raw`` folder is the fallback.
"""
from __future__ import annotations

import os
from pathlib import Path

#: code root: paper_1_transfer/scripts/eeg_reconstruction/paths.py -> three levels up
CODE_ROOT = Path(__file__).resolve().parents[3]


def data_root() -> Path:
    env = os.environ.get('LES_DATA_ROOT')
    return Path(env) if env else CODE_ROOT / 'data'


def eeg_dir(session: int) -> Path:
    return data_root() / 'raw data' / 'EEG' / f'Session {session}'


def export_dir(session: int) -> Path:
    return eeg_dir(session) / 'Export'


def history_path(pid: int | str, session: int) -> Path:
    return eeg_dir(session) / 'History' / f'{pid}.ehst2'


def raw_dir(pid: int | str, session: int) -> Path:
    """Directory holding ``<pid>.vhdr``/``.vmrk``/``.eeg`` (see the module docstring).

    ``LES_EEG_RAW_DIR`` does not know sessions: point it only at directories of the session
    being run (lab ID 7, for one, has raw recordings in Sessions 2 and 3).
    """
    for d in filter(None, os.environ.get('LES_EEG_RAW_DIR', '').split(os.pathsep)):
        if (Path(d) / f'{pid}.vhdr').exists():
            return Path(d)
    return eeg_dir(session) / 'Raw'
