"""N7, step 2: summary of the mechanism audit (``n7_01_mechanism.py``).

Supports the Method's segmentation and artefact-screening paragraph and ISSUES.md N7: the fate
of every history event by lag (exported, lost to the five-sample rule, in a removed parent, no
parent); the decisive tests (no five-sample event with a kept parent went unexported, no event at
another lag was exported, every exported epoch has five samples between the two triggers); the
artefact nodes, their criteria and how many flagged epochs were removed or kept; and the trigger
spacing and the position of the word-onset trigger in each exported epoch, which give the
realised spacing (about 10.7 ms) and the 0-6 ms label offset. Written on 16 September 2026 as
``mechanism/summarise.py``; the artefact-node section (run inline on 16 September, its output
saved as ``ar_nodes_all_stdout.txt``) and the trigger-spacing section (``trigger_spacing.py``) were
folded in when it was moved here.

Reads   eeg_audit/mechanism/{exports,events,ar_nodes}_<run>.csv
Writes  eeg_audit/mechanism/summary_<run>.txt and prints it

Usage:  python n7_02_summarise_mechanism.py [all|only]     (default: all)
Runtime: under a minute.
"""
import sys
from collections import Counter

import pandas as pd

import audit_paths

OUT = audit_paths.out_dir('mechanism')
run = sys.argv[1] if len(sys.argv) > 1 else 'all'
pd.set_option('display.width', 250)
pd.set_option('display.max_columns', 50)
pd.set_option('display.max_rows', 500)
pd.set_option('display.max_colwidth', 80)
lines = []


def p(*a):
    s = ' '.join(str(x) for x in a)
    print(s)
    lines.append(s)


x = pd.read_csv(OUT / f'exports_{run}.csv')
e = pd.read_csv(OUT / f'events_{run}.csv', low_memory=False)
if 'error' in x.columns:
    err = x[x.error.notna()]
    p(f'exports/participants with errors: {len(err)}')
    if len(err):
        p(err[['session', 'participant', 'export', 'error']].to_string())
    x = x[x.error.isna()]
xo = x[~x.is_copy]
p(f'participant-sessions: {xo.groupby(["session", "participant"]).ngroups}; exports (non-copy): {len(xo)}; copies: {int(x.is_copy.sum())}')
p(f'exports where history T count == file segment count: {(xo.n_T == xo.n_file).sum()} / {len(xo)}')
p(f'exported segments (file segment counts): {int(xo.n_file.sum())}')
p(f'exports with .vmrk: {xo.vmrk_present.sum()}; every T entry content-matched to the file: '
  f'{((xo.n_content_match == xo.n_file) & (xo.n_T == xo.n_file)).sum()} / {xo.vmrk_present.sum()}')
bad = xo[xo.vmrk_present & ~((xo.n_content_match == xo.n_file) & (xo.n_T == xo.n_file))]
if len(bad):
    p('exports NOT fully reproduced by the history:')
    p(bad[['session', 'participant', 'export', 'n_T', 'n_file', 'n_content_match', 'n_content_mismatch', 'date_residual_us', 'n_candidates', 'n_candidates_reproducing_export']].to_string())
p('date residual (us) distribution over exports: ' + str(Counter(' '.join(xo.date_residual_us.dropna().astype(str)).split())))
p('in-file S k -> S10x distance over exported segments (all exports incl. copies): ' +
  str(sum((Counter({k: int(v) for k, v in (t.split(':') for t in s.split())}) for s in x.export_lags.dropna().astype(str) if s), Counter())))
p('in-file Time 0 position: ' + str(sum((Counter({k: int(v) for k, v in (t.split(':') for t in s.split())}) for s in x.export_time0_rel.dropna().astype(str) if s), Counter())))
p('in-file word-ID marker position (0-based sample, Time 0 = 65): ' + str(sorted(sum((Counter({k: int(v) for k, v in (t.split(':') for t in s.split())}) for s in x.export_word_rel.dropna().astype(str) if s), Counter()).items())))
p(f'Bad Interval markers: F (feeding node) total {int(xo.n_bad_interval_markers_F.sum())} in {int((xo.n_bad_interval_markers_F > 0).sum())} exports; '
  f'parent segmentation node {int(xo.n_bad_interval_markers_S.sum())}; nodes between parent and child {int(xo.n_bad_interval_markers_mids.sum())}; child node {int(xo.n_bad_interval_markers_T.sum())}')
p(f'T entries not paired to a branch event: {int(xo.T_entries_not_paired_to_branch_event.sum())}')
p(f'exports whose path matched >1 storage: {int((xo.n_candidates > 1).sum())}; of which >1 reproduce the export: {int((xo.n_candidates_reproducing_export > 1).sum())}, '
  f'all candidates with identical child starts: {int(((xo.n_candidates > 1) & xo.candidates_identical_child_starts).sum())}')
p('intermediate nodes between parent and child segmentation: ' + str(Counter(xo.mids)))

p('\n=== events ===')
e['fate'] = 'exported'
e.loc[e.parent.isna(), 'fate'] = 'no parent segment'
e.loc[e.parent.notna() & (e.parent_kept == False), 'fate'] = 'parent removed by hand'  # noqa: E712
e.loc[e.parent.notna() & (e.parent_kept == True) & ~e.in_T, 'fate'] = 'kept parent, no child'  # noqa: E712
e.loc[e.in_T & (e.in_export == False), 'fate'] = 'in T but not matched in file'  # noqa: E712
e.loc[e.in_T & e.in_export.isna(), 'fate'] = 'in T (export has no vmrk)'
p(f'events: {len(e)}')
p(pd.crosstab(e.lag, e.fate, margins=True).to_string())
p('\nper recording (lag x fate):')
g = e.groupby(['session', 'participant', 'lag', 'fate']).size().unstack(['lag', 'fate'], fill_value=0)
p(g.to_string())
k = e.parent_kept == True  # noqa: E712
t1 = e[(e.lag == 5) & k & ~e.in_T]
t2 = e[(e.lag != 5) & e.in_T]
t3 = e[e.in_T & (e.export_lag.notna()) & (e.export_lag != 5)]
t4 = e[k & (e.child_fits != e.in_T)]
p(f'\nTEST 1 lag-5 events with a kept parent and no child/export: {len(t1)}')
p(f'TEST 2 lag != 5 events with a child/export: {len(t2)}')
p(f'TEST 3 exported events whose in-file S k -> S10x distance != 5: {len(t3)}')
p(f'TEST 4 events with a kept parent where window arithmetic (child inside parent) disagrees with the history child table: {len(t4)}')
p('child start - parent start by lag: ' + str(e.groupby('lag').child_start_minus_parent_start.agg(['min', 'max']).to_dict('index')))
p('child end - parent end by lag: ' + str(e.groupby('lag').child_end_minus_parent_end.agg(['min', 'max']).to_dict('index')))
np_ = e[e.parent.isna()]
p(f'\nno-parent events: {len(np_)}; lag: {dict(Counter(np_.lag))}; parent window overlaps a Bad Interval marker in F: {dict(Counter(np_.parent_window_overlaps_bad_interval_in_F))}')
p(f'events with a parent whose window overlaps a Bad Interval in F: {int((e.parent.notna() & e.parent_window_overlaps_bad_interval_in_F).sum())}')
rr = e[e.raw_vmrk_lag.notna()]
p(f'\nraw .vmrk lag available for {len(rr)} / {len(e)} events; equal to history lag: {int((rr.raw_vmrk_lag == rr.lag).sum())}; '
  f'raw reference marker equal: {int((rr.raw_vmrk_ref == ("S  " + rr.branch.str[1])).sum())}')
p(f'removed parents: lag-5 events {int(((e.fate == "parent removed by hand") & (e.lag == 5)).sum())}, other lags {int(((e.fate == "parent removed by hand") & (e.lag != 5)).sum())}')
if 'parent_removal' in e.columns:
    rm = e[e.fate == 'parent removed by hand']
    p('how removed parents were recorded (events; lag-5 events):')
    p(pd.crosstab(rm.parent_removal.str.split(': ').str[-1], rm.lag == 5).rename(columns={True: 'lag5', False: 'lag!=5'}).to_string())
    p(rm[~rm.parent_removal.str.contains('Userdefined')].groupby(['session', 'participant', 'branch', 'parent_removal']).size().to_string())
if 'new_segment_inside_parent_window' in e.columns:
    p(f'no-parent events with a New Segment marker (discontinuity) inside the parent window: {int(np_.new_segment_inside_parent_window.sum())}; '
      f'with a Bad Interval overlap: {int(np_.parent_window_overlaps_bad_interval_in_F.sum())}; with neither: '
      f'{int((~np_.new_segment_inside_parent_window & ~np_.parent_window_overlaps_bad_interval_in_F.astype(bool)).sum())}')
    p(f'events WITH a parent whose window contains a New Segment marker: {int((e.parent.notna() & e.new_segment_inside_parent_window).sum())}')
    p('no-parent events by session/participant/branch/reason:')
    np_ = np_.assign(reason=np_.apply(lambda r: 'Bad Interval overlap' if r.parent_window_overlaps_bad_interval_in_F else ('New Segment inside window' if r.new_segment_inside_parent_window else 'other'), axis=1))
    p(np_.groupby(['session', 'participant', 'branch', 'reason', 'lag']).size().to_string())
p(f'auto-detected artefact in parent (stored ArtifactIntervals) among exported events: {int((e.parent_has_auto_artifact & (e.fate == "exported")).sum())}')

# --- artefact nodes: one row per distinct node (each serves its branch's three condition exports)
p('\n=== artefact rejection nodes on the export chains ===')
a = pd.read_csv(OUT / f'ar_nodes_{run}.csv', low_memory=False)
a = a.drop_duplicates(['session', 'participant', 'history_file', 'storage'])
p(f'AR nodes: {len(a)}')
for col in ('desc_title', 'Method', 'IndividualChannelMode', 'WriteOnlyMarkers', 'CheckGradient', 'MaxGradient',
            'CheckDifference', 'MaxDifference', 'DiIntervalLength', 'CheckActivity', 'MinActivity', 'AcIntervalLength',
            'CheckAmplitude', 'GrBefore', 'GrAfter', 'DiBefore', 'DiAfter', 'AcBefore', 'AcAfter',
            'n_bad_interval_markers_own'):
    p(f'  {col}: {a[col].astype(str).value_counts().to_dict()}')
p(f'nodes with removed segments: {int((a.desc2_removed > 0).sum())}; removed segments (Description2): {int(a.desc2_removed.sum())}')
p(f'removed segments with a stored automatic detection: {int(a.removed_segments_with_auto_detection.sum())}; '
  f'kept segments with a stored automatic detection: {int(a.kept_segments_with_auto_detection.sum())}; '
  f'removed segments without a user edit: {int(a.removed_segments_without_user_edit.sum())}')
p(f'Description2 kept count == SegmentTable length: {dict(Counter(a.desc2_kept == a.n_segtable))}')

# --- trigger spacing and the word-onset trigger inside the exported epochs
p('\n=== trigger spacing (samples at 500 Hz) ===')
e['word_to_ref'] = e.word_to_cond - e.lag
p('word -> S10x (samples), all events: ' + str(e.word_to_cond.value_counts().sort_index().to_dict()))
p('word -> S k (samples), all events: ' + str(e.word_to_ref.value_counts().sort_index().to_dict()))
p('sentence -> S k (samples), all events: ' + str(e.sent_to_ref.value_counts().sort_index().to_dict()))
p('mean word -> S10x: %.3f samples = %.2f ms (three trigger steps, %.2f ms each); mean lag %.3f samples = %.2f ms'
  % (e.word_to_cond.mean(), 2 * e.word_to_cond.mean(), 2 * e.word_to_cond.mean() / 3, e.lag.mean(), 2 * e.lag.mean()))
xe = e[e.in_T]
p('exported events: word -> S10x ' + str(xe.word_to_cond.value_counts().sort_index().to_dict()))
# The importer labels sample 0 of an epoch -100 ms; the epoch starts 130 ms before S10x, so a label
# understates the time since the word-onset trigger by 2 * word_to_cond - 30 ms.
off = 2 * xe.word_to_cond - 30
p('label offset from the word-onset trigger (ms), exported events: ' + str(off.value_counts().sort_index().to_dict())
  + f'; mean {off.mean():.3f} ms')

(OUT / f'summary_{run}.txt').write_text('\n'.join(lines), encoding='utf-8')
