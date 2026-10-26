"""N7, step 3: trials each alternative segmentation would have produced, event by event.

Supports the Method's statement of how many trials a segmentation tolerant of one sample of
trigger jitter would recover, and the reprocessing decision in ISSUES.md N7 (option D of the N7
report). Written on 16 September 2026 as ``mechanism/alternatives.py``; moved here with only its
paths changed.

Reads   eeg_audit/mechanism/events_<run>.csv (``n7_01_mechanism.py``)
Writes  eeg_audit/mechanism/alternatives_<run>.csv (one row per event, a column per rule) and
        alternatives_<run>.txt (the table printed below)

Rules used (all observed in the LESS histories, see summary_<run>.txt):
  * a parent segment is not created when its window overlaps a Bad Interval marker while "Skip bad
    intervals" is on (S1/S2 branches), or when a New Segment marker (recording discontinuity) falls
    inside it (all branches);
  * a child segment on segmented data is created only if its window lies wholly inside its parent;
  * hand-removed parents (Artifact Rejection) are assumed to be removed again whatever the windows.
Nothing else is assumed. For the single-level alternatives the same Bad Interval / New Segment rules
are applied to the new window, with the branch's own "Skip bad intervals" setting.

Alternatives (time relative to the marker named; 500 Hz, 2 ms per sample):
  actual       parent S k -120..1080 (600 pts), child S10x -130..1070 (600 pts)
  child599     parent as actual, child S10x -130..1068 (599 pts): tolerates a lag of 6
  child598     parent as actual, child S10x -128..1068 (598 pts): tolerates lags of 4 and 6,
               i.e. one sample of jitter either way
  parent610    parent S k -130..1090 (610 pts), child S10x -130..1070 (600 pts)
  single_S10x  one segmentation on S10x -130..1070, restricted to S10x preceded by S k (e.g. by an
               Advanced Boolean Expression or recoded markers)
  single_word  one segmentation on the word-ID trigger -100..1100 (600 pts), restricted likewise

Usage:  python n7_03_alternatives.py [all|only]     (default: all)
Runtime: seconds.
"""
import sys

import pandas as pd

import audit_paths

OUT = audit_paths.out_dir('mechanism')
run = sys.argv[1] if len(sys.argv) > 1 else 'all'
e = pd.read_csv(OUT / f'events_{run}.csv', low_memory=False)
b = lambda c: e[c].fillna(False).astype(bool)  # noqa: E731

removed = e.parent.notna() & (e.parent_kept == False)  # noqa: E712
skip = b('parent_skip_bad_intervals')
parent_ok = e.parent.notna()  # actual parent exists (reproduces Bad Interval / New Segment / edge rules)
L = e.lag


def nested(p_start, p_len, c_start, c_len):
    """child inside parent, in samples relative to S k: parent [p_start, p_start+p_len), child [L+c_start, ...)."""
    return (L + c_start >= p_start) & (L + c_start + c_len <= p_start + p_len)


# parent610 changes the parent window by 5 samples before and 5 after; re-check discontinuities/bad
# intervals approximately with the child-window flags (child lies inside the widened parent).
alts = {
    'actual': parent_ok & nested(-60, 600, -65, 600) & ~removed,
    'child599': parent_ok & nested(-60, 600, -65, 599) & ~removed,
    'child598': parent_ok & nested(-60, 600, -64, 598) & ~removed,
    'parent610': parent_ok & nested(-65, 610, -65, 600) & ~removed,
    'single_S10x': ~(skip & b('child_window_overlaps_bad_interval_in_F')) & ~b('new_segment_inside_child_window') & ~removed,
    'single_word': e.word.notna() & ~(skip & b('word_window_overlaps_bad_interval_in_F')) & ~b('new_segment_inside_word_window') & ~removed,
}
res = e[['session', 'participant', 'branch', 'cond', 'event_pos', 'lag', 'in_T']].copy()
for k, v in alts.items():
    res[k] = v
res.to_csv(OUT / f'alternatives_{run}.csv', index=False)
check = (res.actual == res.in_T).all()
print(f'events: {len(res)}; "actual" rule reproduces the history child tables for every event: {check} '
      f'(mismatches: {int((res.actual != res.in_T).sum())})')
tab = pd.DataFrame({k: [int(v.sum()), round(100 * v.mean(), 1)] + [int(v[L == lg].sum()) for lg in sorted(L.unique())]
                    for k, v in alts.items()},
                   index=['trials', 'percent of events'] + [f'lag {lg} kept' for lg in sorted(L.unique())])
tab.insert(0, 'events', [len(e), 100.0] + [int((L == lg).sum()) for lg in sorted(L.unique())])
print(tab.to_string())
cond = res[res.cond.isin(['S101', 'S102'])]
cond_tab = pd.DataFrame({k: [int(cond[k].sum()), round(100 * cond[k].mean(), 1)] for k in alts}, index=['trials', 'percent'])
print('\nS101/S102 only (the conditions Paper 1 models):')
print(cond_tab.to_string())
(OUT / f'alternatives_{run}.txt').write_text(tab.to_string() + '\n\nS101/S102 only (the conditions Paper 1 models):\n'
                                             + cond_tab.to_string(), encoding='utf-8')
