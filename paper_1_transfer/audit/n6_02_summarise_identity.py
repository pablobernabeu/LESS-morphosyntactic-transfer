"""N6, step 2: summary of the trial-identity audit (``n6_01_trial_identity.py``).

Supports ISSUES.md N6: how many exports and participant-sessions were audited, which exports
share a recording, which histories start from a recording other than the archived raw file,
which histories record a filter or New Reference setting other than the majority's, and every
other exception the audit raised. Written on 16 September 2026 as ``recon/summarise_audit.py``.
Its loss totals and its exploration of the lag structure are left out: the loss split it
printed is superseded (see the header of n6_01), and the lag structure is analysed in the N7
stages.

Reads   eeg_audit/identity/audit_trial_identity_wide.csv
Writes  eeg_audit/identity/audit_summary.txt (holds recording start times, so it stays in the
        output store)

Runtime: seconds.
"""
from __future__ import annotations

import pandas as pd

import audit_paths

HERE = audit_paths.out_dir('identity')


def main():
    w = pd.read_csv(HERE / 'audit_trial_identity_wide.csv')
    out = []
    p = out.append
    ps = w.groupby(['session', 'participant'])
    p(f'exports audited: {len(w)}; participant-sessions: {ps.ngroups}; per session: '
      + ', '.join(f'S{s}: {n}' for s, n in w.groupby("session").participant.nunique().items()))
    failed = w[w.exceptions.fillna('').str.startswith('AUDIT FAILED')]
    p(f'exports whose audit failed: {len(failed)}')
    p(f'exports whose segment count differs from the history tbt node: '
      f'{int((w.exported_in_file != w.exported_history_tbt_node).sum())}')
    p(f'non-standard windows: {int((~w.windows_standard.astype(bool)).sum())} exports')
    hp = w.groupby(['session', 'participant']).high_pass_hz.first().reset_index()
    p('high-pass per participant-session (history text): ' + '; '.join(
        f'S{s}: ' + ', '.join(f'{k} Hz x{v}' for k, v in g.high_pass_hz.value_counts().items()) for s, g in hp.groupby('session')))
    one = hp[hp.high_pass_hz.astype(str) != '0.1']
    p('participant-sessions not at 0.1 Hz (history text): ' + ', '.join(f'S{r.session}/{r.participant} ({r.high_pass_hz})' for r in one.itertuples()))
    p('implicit reference included in New Reference: ' + ', '.join(
        f'S{s}: {int(g.groupby("participant").implicit_reference_in_new_reference.max().sum())}/{g.participant.nunique()}'
        for s, g in w.groupby('session')))

    # duplicated recordings: the same recording start used by more than one participant-session
    rs = w.groupby(['session', 'participant']).recording_start_history.first().reset_index()
    dup = rs.groupby('recording_start_history').filter(lambda g: len(g) > 1)
    p('\nrecordings used by more than one participant-session (history root start time):')
    for d, g in dup.groupby('recording_start_history'):
        p(f'  {d}: ' + ', '.join(f'S{r.session}/{r.participant}' for r in g.itertuples()))
    mism = w[w.raw_vmrk_matches_history.astype(str) == 'False'].groupby(['session', 'participant']).size()
    p('\nparticipant-sessions whose history root markers differ from Raw/{id}.vmrk: '
      + ', '.join(f'S{s}/{q}' for s, q in mism.index))
    exc = w[w.exceptions.notna()].groupby(['session', 'participant']).exceptions.agg(lambda s: ' || '.join(sorted(set(s))))
    p('\nexceptions per participant-session:\n' + '\n'.join(f'  S{k[0]}/{k[1]}: {v}' for k, v in exc.items()))
    text = '\n'.join(out)
    (HERE / 'audit_summary.txt').write_text(text, encoding='utf-8')
    print(text)


if __name__ == '__main__':
    main()
