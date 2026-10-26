"""N7, step 10: one row per recorded S101/S102/S103 marker, aligned to the logs by trial key.

The event table of the retention-by-group analyses (n7_11 to n7_13), which give the odds ratio of
losing a grammatical rather than an ungrammatical trial in the Mini-English group at Session 6.
Written on 17 September 2026 as ``verify/C09_recompute/01_build.py``, a verifier's independent
rebuild; moved here with only its paths changed. It and n7_04_events.py build the same recorded
events (64,427, with the same lags) by different routes: this one matches exports and logs by trial
key, n7_04 by clock and code sequence. Each is kept because the analyses that read it were run on
it. They differ in one known place: the key match here includes the property code, which the
history recoded in Session 4 of lab ID 7, so 48 of that recording's exported trials are not
matched (the N7 report, section 2.4). n7_13 shows the effect of dropping that recording.

recorded  : EEG/Session k/Raw/{id}.vmrk (+ {id}-continued.vmrk); '- Copy' files skipped (byte-identical, checked)
exported  : EEG/Session k/Export/{id}_trialbytrial_S{p}_S10{c}.vmrk; each segment's Time 0 marker and the word,
            sentence and property markers inside the segment give a trial key that is matched to the raw events
presented : behavioural logs subject-{id}.csv (or subject-{id}-experiment.csv), Experiment rows with a sentence trigger

Lag = samples from the property marker (S 1/2/3) to the condition marker, looking back within the trial
(stopping at the previous condition marker or at codes 5, 6, 7, 8, 254, 255). lag_any is the lag to the nearest
preceding property marker with no stopping rule.

Behavioural alignment: key match on (word, sentence, property trigger, condition) within a participant-session,
k-th raw occurrence to k-th logged occurrence; unmatched raw events are retried on (word, sentence, condition).

Writes eeg_audit/aligned/01_events.csv (14 MB; it holds recording start times, so it stays in the
output store), 01_recordings.csv, 01_export_counts.csv, 01_build_log.txt
Runtime: about 4 minutes.
"""
from __future__ import annotations

import datetime as dt
from collections import defaultdict, deque

import numpy as np
import pandas as pd

from aligned_io import BEH, EEG, KEY, OUT, SESSIONS, markers, raw_files, raw_ids, read_header_cols, vhdr_segments

LOG = []


def say(*a):
    s = ' '.join(str(x) for x in a)
    LOG.append(s)
    print(s, flush=True)


STOP = {101, 102, 103, 5, 6, 7, 8, 254, 255}


def parse_date(s):
    return dt.datetime.strptime(s[:14], '%Y%m%d%H%M%S') + dt.timedelta(microseconds=int(s[14:20]))


def raw_events(session, pid):
    ev = []
    for fi, p in enumerate(raw_files(session, pid)):
        mk = markers(p)
        ns = [(pos, parse_date(d)) for typ, _, _, pos, d in mk if typ == 'New Segment' and d]
        stim = sorted([(pos, c) for typ, c, _, pos, _ in mk if typ == 'Stimulus' and c is not None], key=lambda t: t[0])
        last_prop = None
        for i, (pos, c) in enumerate(stim):
            if c in (101, 102, 103):
                prop = sent = word = None
                j = i - 1
                while j >= 0 and stim[j][1] not in STOP:
                    pj, cj = stim[j]
                    if cj in (1, 2, 3) and prop is None:
                        prop = (pj, cj)
                    elif 110 <= cj <= 253 and sent is None:
                        sent = (pj, cj)
                    elif 40 <= cj <= 99 and word is None:
                        word = (pj, cj)
                    j -= 1
                # date of the child-segment start (S10x - 65 samples) on the recording clock
                prev_ns = [t for t in ns if t[0] <= pos]
                cdate = ''
                if prev_ns:
                    p0, d0 = prev_ns[-1]
                    cdate = (d0 + dt.timedelta(microseconds=round((pos - 65 - p0) * 2000))).strftime('%Y%m%d%H%M%S%f')
                ev.append(dict(session=session, participant=pid, file_index=fi, file=p.name, pos=pos, condition=c,
                               prop=prop[1] if prop else None, sent=sent[1] if sent else None,
                               word=word[1] if word else None,
                               lag=(pos - prop[0]) if prop else None,
                               lag_sent_prop=(prop[0] - sent[0]) if (prop and sent) else None,
                               lag_any=(pos - last_prop[0]) if last_prop else None,
                               child_date=cdate, rec_start=ns[0][1].strftime('%Y%m%d%H%M%S') if ns else ''))
            if c in (1, 2, 3):
                last_prop = (pos, c)
    return ev


def export_segments(session, pid):
    d = EEG / f'Session {session}' / 'Export'
    segs, counts = [], []
    for s in (1, 2, 3):
        for c in (101, 102, 103):
            vh = d / f'{pid}_trialbytrial_S{s}_S{c}.vhdr'
            vm = vh.with_suffix('.vmrk')
            row = dict(session=session, participant=pid, branch=s, condition=c, has_vhdr=vh.exists(), has_vmrk=vm.exists(),
                       n_vhdr=vhdr_segments(vh) if vh.exists() else None, n_vmrk=None)
            if vm.exists():
                mk = markers(vm)
                cur = []
                groups = []
                for typ, code, _, pos, date in mk:
                    if typ == 'New Segment':
                        cur = dict(date=date, pos=pos, stim=[], t0=None)
                        groups.append(cur)
                    elif typ == 'Stimulus' and groups:
                        cur['stim'].append((pos, code))
                    elif typ == 'Time 0' and groups:
                        cur['t0'] = pos
                row['n_vmrk'] = len(groups)
                for g in groups:
                    st = sorted(g['stim'])
                    t0c = [x for x in st if x[0] == g['t0'] and x[1] in (101, 102, 103)]
                    if not t0c:
                        segs.append(dict(branch=s, file_cond=c, key=None, date=g['date'], t0_offset=None))
                        continue
                    i = st.index(t0c[0])
                    prop = sent = word = None
                    j = i - 1
                    while j >= 0 and st[j][1] not in STOP:
                        cj = st[j][1]
                        if cj in (1, 2, 3) and prop is None:
                            prop = cj
                        elif cj is not None and 110 <= cj <= 253 and sent is None:
                            sent = cj
                        elif cj is not None and 40 <= cj <= 99 and word is None:
                            word = cj
                        j -= 1
                    segs.append(dict(branch=s, file_cond=c, key=(word, sent, prop, t0c[0][1]), date=g['date'],
                                     t0_offset=g['t0'] - g['pos']))
            counts.append(row)
    return segs, counts


BCOLS = ['session_part', 'trial', 'grammatical_property', 'grammaticality', 'grammatical_property_trigger',
         'grammaticality_trigger', 'sentence_trigger', 'target_word_trigger', 'target_word_location',
         'correct_grammaticality_judgement_response', 'response_grammaticality_judgement_response',
         'response_time_grammaticality_judgement_response', 'language']


def behaviour(session, pid):
    d = BEH / f'Session {session}'
    f = None
    for n in (f'subject-{pid}.csv', f'subject-{pid}-experiment.csv'):
        if (d / n).exists():
            f = d / n
            break
    if f is None:
        return None, 'no log'
    sep, cols = read_header_cols(f)
    keep = [c for c in BCOLS if c in cols]
    df = pd.read_csv(f, sep=sep, usecols=keep, low_memory=False, na_values=['NA', 'None', 'undefined', ''])
    note = f'{f.name} rows={len(df)}'
    if 'session_part' in df:
        df = df[df.session_part == 'Experiment']
    else:
        note += ' NO session_part'
    df = df.copy()
    df['trial'] = pd.to_numeric(df['trial'], errors='coerce')
    n0 = len(df)
    df = df.drop_duplicates('trial', keep='first')
    n_exp = len(df)
    t = df[pd.to_numeric(df.sentence_trigger, errors='coerce').notna()].copy()
    for c in ('sentence_trigger', 'target_word_trigger', 'grammatical_property_trigger', 'grammaticality_trigger'):
        t[c] = pd.to_numeric(t[c], errors='coerce')
    t['n_exp_rows'] = n_exp
    t['n_targets'] = len(t)
    t['max_trial'] = df.trial.max()
    note += f' experiment rows {n0} -> dedup {n_exp}; targets {len(t)}; trial range {df.trial.min()}-{df.trial.max()}'
    return t.reset_index(drop=True), note


key = pd.read_csv(KEY, dtype=str)
lang_key = dict(zip(key.participant_lab_ID.str.strip(), key.language.str.strip()))

all_ev, recs, cnts = [], [], []
for s in SESSIONS:
    ids = raw_ids(s) | {p.name.split('-')[1].split('.')[0] for p in (BEH / f'Session {s}').glob('subject-*.csv')}
    for pid in sorted(ids, key=int):
        ev = pd.DataFrame(raw_events(s, pid))
        segs, cn = export_segments(s, pid)
        cnts += cn
        b, bnote = behaviour(s, pid)
        rec = dict(session=s, participant=pid, n_raw_files=len(raw_files(s, pid)), n_s10x=len(ev), beh_note=bnote,
                   n_log_targets=0 if b is None else len(b), n_export_segs=len(segs), language_key=lang_key.get(pid))
        if ev.empty:
            recs.append(rec)
            say(rec)
            continue
        # ---- export matching by trial key
        ev['key'] = list(zip(ev.word, ev.sent, ev.prop, ev.condition))
        by_key = defaultdict(deque)
        for i, k in zip(ev.index, ev.key):
            by_key[k].append(i)
        ev['exported'] = False
        ev['export_branch'] = np.nan
        ev['export_date_match'] = np.nan
        n_seg_unmatched = 0
        n_seg_dupkey = 0
        for g in segs:
            k = g['key']
            if k is None or not by_key.get(k):
                n_seg_unmatched += 1
                continue
            cand = list(by_key[k])
            if len(cand) > 1:
                n_seg_dupkey += 1
                # prefer the candidate whose child-start date matches the segment date
                dm = [i for i in cand if ev.at[i, 'child_date'] == g['date']]
                i = dm[0] if dm else cand[0]
            else:
                i = cand[0]
            by_key[k].remove(i)
            ev.at[i, 'exported'] = True
            ev.at[i, 'export_branch'] = g['branch']
            ev.at[i, 'export_date_match'] = float(ev.at[i, 'child_date'] == g['date'])
        rec.update(n_seg_unmatched=n_seg_unmatched, n_seg_dupkey=n_seg_dupkey, n_exported_matched=int(ev.exported.sum()),
                   n_raw_dup_keys=int(ev.key.duplicated(keep=False).sum()))
        # ---- behavioural alignment
        ev['beh_idx'] = np.nan
        ev['match_type'] = ''
        if b is not None and len(b):
            lk = defaultdict(deque)
            lk2 = defaultdict(deque)
            for j, r in b.iterrows():
                w, se, pr, co = (r.target_word_trigger, r.sentence_trigger, r.grammatical_property_trigger, r.grammaticality_trigger)
                w = None if pd.isna(w) else int(w)
                se = None if pd.isna(se) else int(se)
                pr = None if pd.isna(pr) else int(pr)
                co = None if pd.isna(co) else int(co)
                lk[(w, se, pr, co)].append(j)
                lk2[(w, se, co)].append(j)
            used = set()
            for i, r in ev.iterrows():
                k = (None if pd.isna(r.word) else int(r.word), None if pd.isna(r.sent) else int(r.sent),
                     None if pd.isna(r.prop) else int(r.prop), int(r.condition))
                q = lk.get(k)
                while q and q[0] in used:
                    q.popleft()
                if q:
                    j = q.popleft()
                    used.add(j)
                    ev.at[i, 'beh_idx'] = j
                    ev.at[i, 'match_type'] = 'full'
            for i, r in ev[ev.beh_idx.isna()].iterrows():
                k = (None if pd.isna(r.word) else int(r.word), None if pd.isna(r.sent) else int(r.sent), int(r.condition))
                q = lk2.get(k)
                while q and q[0] in used:
                    q.popleft()
                if q:
                    j = q.popleft()
                    used.add(j)
                    ev.at[i, 'beh_idx'] = j
                    ev.at[i, 'match_type'] = 'no_property'
            m = ev.beh_idx.notna()
            bb = b.loc[ev.loc[m, 'beh_idx'].astype(int)].reset_index(drop=True)
            for c in ('trial', 'grammatical_property', 'grammaticality', 'grammatical_property_trigger',
                      'correct_grammaticality_judgement_response', 'response_grammaticality_judgement_response',
                      'response_time_grammaticality_judgement_response', 'target_word_location', 'language',
                      'n_exp_rows', 'n_targets', 'max_trial'):
                ev.loc[m, 'b_' + c] = bb[c].values if c in bb else np.nan
            tr = ev.loc[m].sort_values(['file_index', 'pos']).b_trial.to_numpy()
            rec.update(n_aligned=int(m.sum()), n_aligned_noprop=int((ev.match_type == 'no_property').sum()),
                       n_order_inversions=int((np.diff(tr) < 0).sum()) if len(tr) > 1 else 0,
                       n_log_unmatched=len(b) - int(m.sum()))
        else:
            rec.update(n_aligned=0)
        lag = ev.lag
        rec.update(n_lag5=int((lag == 5).sum()), n_lag6=int((lag == 6).sum()), n_lag_other=int((lag.notna() & ~lag.isin([5, 6])).sum()),
                   n_lag_na=int(lag.isna().sum()))
        recs.append(rec)
        say({k: rec.get(k) for k in ('session', 'participant', 'n_s10x', 'n_log_targets', 'n_aligned', 'n_order_inversions',
                                      'n_export_segs', 'n_exported_matched', 'n_seg_unmatched', 'n_lag5', 'n_lag6', 'n_lag_other', 'n_lag_na', 'beh_note')})
        all_ev.append(ev.drop(columns=['key']))

E = pd.concat(all_ev, ignore_index=True)
E['language_key'] = E.participant.map(lang_key)
E.to_csv(OUT / '01_events.csv', index=False)
pd.DataFrame(recs).to_csv(OUT / '01_recordings.csv', index=False)
pd.DataFrame(cnts).to_csv(OUT / '01_export_counts.csv', index=False)
say('events', len(E), 'recordings with S10x', E.groupby(['session', 'participant']).ngroups)
say('lag distribution', E.lag.value_counts(dropna=False).sort_index().to_dict())
(OUT / '01_build_log.txt').write_text('\n'.join(LOG), encoding='utf-8')
