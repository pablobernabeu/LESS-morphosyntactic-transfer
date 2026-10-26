"""N7, step 4: one row per recorded S101/S102/S103 event, built from the primary files only.

Supports the recorded-event count and lag distribution the Method quotes (64,427 events in the
raw marker files, 21,508 of them at a lag other than five samples) and is the event table of the
within-recording condition tests (``n7_05``, ``n7_06``). Written on 17 September 2026 as
``gaps/gap6/01_build.py``, the third independent event build of the N7 assessment (it agrees event
for event with the verifiers' builds in the analysed recordings); moved here with only its paths
changed.

Sources (read-only), Sessions 2, 3, 4 and 6:
  recorded  EEG/Session k/Raw/{id}.vmrk, then {id}-continued.vmrk ('- Copy' and 'rs-' files ignored).
            For each S10x the markers since the last trial boundary (S5 fixation, S6/S7/S8, S254/S255 or a
            previous S10x) are scanned backwards for the property (1-3), sentence (110-253) and word (40-99)
            markers. lag = S10x position - property-marker position, in samples.
  exported  EEG/Session k/Export/{id}_trialbytrial_S{b}_S10{c}.vmrk. Each 'New Segment' is one epoch; its
            Time 0 marker is placed on the absolute clock (segment date + samples) and matched to the recorded
            S10x of the same code within +-1 sample on the raw file's clock (New Segment date + samples).
            Segments that fail the clock match are matched by identity instead: same condition, same sentence
            code, same property as the file's branch, unused, and unique within the participant-session.
            A .vhdr without .vmrk leaves its (branch, condition) with unknown export status.
  presented Behavioural log 'subject-{id}.csv' (or 'subject-{id}-experiment.csv' when the plain file holds no
            Experiment rows): session_part == 'Experiment' rows; first occurrence of each trial number.
            Target trials are rows with a sentence_trigger. Recorded events are aligned to logged target
            trials on the (word, sentence, condition) code sequence with difflib.SequenceMatcher.

Writes to ``eeg_audit/independence/``:
  01_events.csv      one row per recorded S10x event (with log fields where aligned; 12 MB)
  01_unrecorded.csv  logged target trials with no aligned recorded event
  01_recordings.csv  one row per participant-session
  01_log.txt         console log

Runtime: about 5 minutes.
"""
from __future__ import annotations

import csv
import datetime as dt
import difflib
import io
import re
from collections import Counter, defaultdict

import numpy as np
import pandas as pd

import audit_paths

EEG = audit_paths.eeg_root()
BEH = audit_paths.behaviour_root()
OUT = audit_paths.out_dir('independence')
SESSIONS = audit_paths.SESSIONS
US = 2000  # microseconds per sample; every .vhdr is checked below
LOGCOLS = ['session_part', 'trial', 'grammatical_property', 'grammatical_property_trigger', 'grammaticality_trigger',
           'sentence_trigger', 'target_word_trigger', 'target_word_location',
           'correct_grammaticality_judgement_response', 'response_grammaticality_judgement_response',
           'response_time_grammaticality_judgement_response', 'language']
BOUNDARY = {5, 6, 7, 8, 101, 102, 103, 254, 255}
UNCOLS = ['session', 'participant'] + LOGCOLS[1:] + ['n_experiment_trials', 'target_index']


EPOCH = dt.datetime(2020, 1, 1)
EVCOLS = ['session', 'participant', 'part', 'pos', 'abs_us', 'condition', 'prop_marker', 'lag', 'prev_is_prop', 'sentence',
          'word', 'exp_method', 'exp_branch', 'exp_file_cond', 'exp_sentence', 'exp_onset_offset', 'aligned'] + \
         ['log_' + c for c in LOGCOLS[1:]] + ['log_n_experiment_trials', 'log_target_index', 'export_status']


def when_us(stamp: str) -> int:
    # naive clock difference from a fixed epoch: no time-zone or daylight-saving conversion
    t = dt.datetime.strptime(stamp[:14], '%Y%m%d%H%M%S')
    return int((t - EPOCH).total_seconds()) * 1_000_000 + int(stamp[14:20] or 0)


def read_markers(path):
    out = []
    with open(path, encoding='utf-8', errors='replace') as fh:
        for ln in fh:
            if not re.match(r'Mk\d+=', ln):
                continue
            f = ln.rstrip('\r\n').split('=', 1)[1].split(',')
            m = re.fullmatch(r'S\s*(\d+)', f[1].strip())
            out.append((f[0], int(m.group(1)) if m else None, int(f[2]), f[5] if len(f) > 5 else ''))
    return out


def check_interval(vhdr, notes: list):
    if not vhdr.exists():
        return
    for ln in open(vhdr, encoding='utf-8', errors='replace'):
        if ln.startswith('SamplingInterval='):
            if float(ln.split('=')[1]) != US:
                notes.append(f'{vhdr.name} SamplingInterval {ln.strip()}')
            return


def recorded(session: int, pid: str, notes: list):
    rows = []
    raw = EEG / f'Session {session}' / 'Raw'
    for part, name in enumerate((f'{pid}.vmrk', f'{pid}-continued.vmrk')):
        f = raw / name
        if not f.exists():
            continue
        check_interval(f.with_suffix('.vhdr'), notes)
        mk = read_markers(f)
        segs = [(pos, when_us(d)) for t, _, pos, d in mk if t == 'New Segment' and d]
        if len(segs) != 1:
            notes.append(f'{name}: {len(segs)} dated New Segment markers')
        since = []
        for t, c, pos, _ in mk:
            if t != 'Stimulus' or c is None:
                continue
            if c in (101, 102, 103):
                prop = next(((p, x) for p, x in reversed(since) if x in (1, 2, 3)), (None, None))
                sent = next((x for p, x in reversed(since) if 110 <= x <= 253), None)
                word = next((x for p, x in reversed(since) if 40 <= x <= 99), None)
                seg = [s for s in segs if s[0] <= pos]
                rows.append(dict(session=session, participant=pid, part=part, pos=pos,
                                 abs_us=(seg[-1][1] + (pos - seg[-1][0]) * US) if seg else None,
                                 condition=c, prop_marker=prop[1], lag=(pos - prop[0]) if prop[0] is not None else None,
                                 prev_is_prop=bool(since) and since[-1][1] in (1, 2, 3),
                                 sentence=sent, word=word))
            if c in BOUNDARY:
                since = []
            else:
                since.append((pos, c))
    return rows


def exported(session: int, pid: str, notes: list):
    segs, have_vmrk, vhdr_only = [], set(), set()
    d = EEG / f'Session {session}' / 'Export'
    for vh in sorted(d.glob(f'{pid}_trialbytrial_S?_S10?.vhdr')):
        m = re.fullmatch(rf'{pid}_trialbytrial_S([123])_S(10[123])\.vhdr', vh.name)
        if not m:
            continue
        key = (int(m.group(1)), int(m.group(2)))
        check_interval(vh, notes)
        vm = vh.with_suffix('.vmrk')
        if not vm.exists():
            vhdr_only.add(key)
            continue
        have_vmrk.add(key)
        cur = None
        for t, c, pos, date in read_markers(vm):
            if t == 'New Segment':
                cur = dict(branch=key[0], fcond=key[1], seg_pos=pos, seg_us=when_us(date) if date else None,
                           stim=[], t0=None, file=vm.name)
                segs.append(cur)
            elif cur is not None and t == 'Time 0':
                cur['t0'] = pos
            elif cur is not None and t == 'Stimulus' and c is not None:
                cur['stim'].append((pos, c))
    for g in segs:
        at = [c for p, c in g['stim'] if p == g['t0'] and c in (101, 102, 103)]
        g['code'] = at[0] if at else None
        before = [(p, c) for p, c in g['stim'] if g['t0'] is not None and p < g['t0']]
        g['sentence'] = next((c for p, c in reversed(before) if 110 <= c <= 253), None)
        g['t0_us'] = g['seg_us'] + (g['t0'] - g['seg_pos']) * US if (g['seg_us'] and g['t0']) else None
        g['onset_offset'] = (g['t0'] - g['seg_pos']) if g['t0'] else None
    return segs, have_vmrk, vhdr_only


def match(ev: pd.DataFrame, segs: list):
    status = {}
    by_code = defaultdict(list)
    for i, r in ev.iterrows():
        if r.abs_us is not None and not pd.isna(r.abs_us):
            by_code[int(r.condition)].append((int(r.abs_us), i))
    for k in by_code:
        by_code[k].sort()
    used, left = set(), []
    for g in segs:
        hit = None
        if g['t0_us'] is not None and g['code'] is not None:
            arr = by_code.get(g['code'], [])
            ts = np.array([a for a, _ in arr]) if arr else np.array([])
            if len(ts):
                j = int(np.searchsorted(ts, g['t0_us']))
                for jj in (j - 1, j, j + 1):
                    if 0 <= jj < len(ts) and abs(ts[jj] - g['t0_us']) <= US and arr[jj][1] not in used:
                        hit = arr[jj][1]
                        break
        if hit is None:
            left.append(g)
        else:
            used.add(hit)
            status[hit] = (g, 'clock')
    still = []
    for g in left:
        cand = ev.index[(ev.condition == g['code']) & (ev.sentence == g['sentence']) &
                        ((ev.prop_marker == g['branch']) | ev.prop_marker.isna())]
        cand = [i for i in cand if i not in used]
        if len(cand) == 1:
            used.add(cand[0])
            status[cand[0]] = (g, 'identity')
        else:
            still.append(g)
    return status, still


def load_log(session: int, pid: str):
    d = BEH / f'Session {session}'
    for name in (f'subject-{pid}.csv', f'subject-{pid}-experiment.csv'):
        f = d / name
        if not f.exists():
            continue
        with open(f, encoding='utf-8', errors='replace') as fh:
            head = fh.readline()
        sep = ';' if head.count(';') > head.count(',') else ','
        cols = next(csv.reader(io.StringIO(head), delimiter=sep))
        x = pd.read_csv(f, sep=sep, usecols=[c for c in LOGCOLS if c in cols], low_memory=False)
        if 'session_part' not in x or not (x.session_part == 'Experiment').any():
            continue
        x = x[x.session_part == 'Experiment'].copy()
        x['trial'] = pd.to_numeric(x.trial, errors='coerce')
        n_rows = len(x)
        x = x.drop_duplicates('trial', keep='first')
        n_exp = len(x)
        x = x[x.sentence_trigger.notna()].reset_index(drop=True)
        for c in ('sentence_trigger', 'target_word_trigger', 'grammaticality_trigger', 'grammatical_property_trigger',
                  'correct_grammaticality_judgement_response', 'response_grammaticality_judgement_response',
                  'response_time_grammaticality_judgement_response'):
            if c in x:
                x[c] = pd.to_numeric(x[c], errors='coerce')
        x['n_experiment_trials'] = n_exp
        x['target_index'] = np.arange(len(x))
        return x, f'{name}: experiment rows {n_rows}, unique trials {n_exp}, targets {len(x)}'
    return None, 'no log with Experiment rows'


def ids(session: int):
    a = {m.group(1) for p in (EEG / f'Session {session}' / 'Raw').glob('*.vmrk')
         if (m := re.fullmatch(r'(\d+)(?:-continued)?\.vmrk', p.name))}
    b = {m.group(1) for p in (BEH / f'Session {session}').glob('subject-*.csv')
         if (m := re.fullmatch(r'subject-(\d+)(?:-experiment)?\.csv', p.name))}
    return sorted(a | b, key=int)


def main():
    logf = open(OUT / '01_log.txt', 'w', encoding='utf-8')

    def say(*a):
        s = ' '.join(str(x) for x in a)
        print(s, flush=True)
        logf.write(s + '\n')

    ev_path, un_path = OUT / '01_events.csv', OUT / '01_unrecorded.csv'
    for p in (ev_path, un_path):
        p.unlink(missing_ok=True)
    recs = []
    for s in SESSIONS:
        for pid in ids(s):
            notes = []
            ev = pd.DataFrame(recorded(s, pid, notes))
            log, lnote = load_log(s, pid)
            segs, have_vmrk, vhdr_only = exported(s, pid, notes)
            rec = dict(session=s, participant=pid, n_recorded=len(ev), log_note=lnote,
                       n_logged_targets=0 if log is None else len(log), n_segments=len(segs),
                       vhdr_without_vmrk=' '.join(f'S{b}_S{c}' for b, c in sorted(vhdr_only)))
            if ev.empty:
                rec['notes'] = '; '.join(notes)
                recs.append(rec)
                if log is not None:
                    log.assign(session=s, participant=pid).reindex(columns=UNCOLS).to_csv(un_path, mode='a', header=not un_path.exists(), index=False)
                say(rec)
                continue
            st, unmatched = match(ev, segs)
            ev['exp_method'] = [st[i][1] if i in st else '' for i in ev.index]
            ev['exp_branch'] = [st[i][0]['branch'] if i in st else np.nan for i in ev.index]
            ev['exp_file_cond'] = [st[i][0]['fcond'] if i in st else np.nan for i in ev.index]
            ev['exp_sentence'] = [st[i][0]['sentence'] if i in st else np.nan for i in ev.index]
            ev['exp_onset_offset'] = [st[i][0]['onset_offset'] if i in st else np.nan for i in ev.index]
            rec.update(n_matched=len(st), n_unmatched_segments=len(unmatched),
                       match_methods=dict(Counter(v[1] for v in st.values())),
                       onset_offsets=dict(Counter(v[0]['onset_offset'] for v in st.values())))
            # alignment with the log
            ev['aligned'] = False
            if log is not None and len(log):
                A = [tuple(None if pd.isna(v) else int(v) for v in (r.word, r.sentence, r.condition)) for r in ev.itertuples()]
                B = [tuple(None if pd.isna(v) else int(v) for v in (r.target_word_trigger, r.sentence_trigger, r.grammaticality_trigger))
                     for r in log.itertuples()]
                sm = difflib.SequenceMatcher(None, A, B, autojunk=False)
                ia, ib = [], []
                for blk in sm.get_matching_blocks():
                    ia += list(range(blk.a, blk.a + blk.size))
                    ib += list(range(blk.b, blk.b + blk.size))
                for c in log.columns:
                    if c == 'session_part':
                        continue
                    ev['log_' + c] = np.nan if c not in ('grammatical_property', 'target_word_location', 'language') else None
                    ev.loc[ev.index[ia], 'log_' + c] = log[c].to_numpy()[ib]
                ev.loc[ev.index[ia], 'aligned'] = True
                rec['n_aligned'] = len(ia)
                un = log.drop(index=log.index[ib])
                if len(un):
                    un.assign(session=s, participant=pid).reindex(columns=UNCOLS).to_csv(un_path, mode='a', header=not un_path.exists(), index=False)
            else:
                rec['n_aligned'] = 0
            # export status
            prop = ev.prop_marker.copy()
            if 'log_grammatical_property_trigger' in ev:
                prop = prop.fillna(ev.log_grammatical_property_trigger)
            stat = []
            for i, r in ev.iterrows():
                if i in st:
                    stat.append('exported')
                elif pd.isna(prop[i]):
                    stat.append('unknown: no property')
                else:
                    k = (int(prop[i]), int(r.condition))
                    stat.append('not exported' if k in have_vmrk else ('unknown: vmrk missing' if k in vhdr_only else 'unknown: no export file'))
            ev['export_status'] = stat
            rec.update({'status_' + k: v for k, v in Counter(stat).items()})
            rec['notes'] = '; '.join(notes)
            ev.reindex(columns=EVCOLS).to_csv(ev_path, mode='a', header=not ev_path.exists(), index=False)
            recs.append(rec)
            say({k: rec.get(k) for k in ('session', 'participant', 'n_recorded', 'n_logged_targets', 'n_aligned', 'n_segments',
                                         'n_matched', 'n_unmatched_segments', 'match_methods', 'onset_offsets', 'notes')})
    pd.DataFrame(recs).to_csv(OUT / '01_recordings.csv', index=False)
    logf.close()


if __name__ == '__main__':
    main()
