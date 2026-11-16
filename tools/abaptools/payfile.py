#!/usr/bin/env python3
"""Offline reference model of the payment file lifecycle (shared engine, tools/abaptools).

Mirrors the rules of ZCL_CA_OPS_PF_LIFECYCLE (status of every configured milestone, where a file stopped, its state and
deadline, payment- and batch-level acknowledgements, conflicting answers of the bank, the result of a business day) and
of ZCL_CA_OPS_CHK_PAYFILE (which finding a file raises, its severity and its exception-contract figures), so that the
fixtures of ops-framework/config/payfile/fixtures.json can be run offline for any integration setup.

A setup is a *profile*: which source ID evidences each role (FILE, TRANSFER, ACK, SCHED, STMT) and the status mapping
rows (ZCA_OPS_PFMAP: source, native status -> milestone, outcome). The fixture's events are canonical (role, milestone,
outcome); a profile encodes each into its native status (an event a setup cannot express - e.g. a middleware pickup in a
setup without middleware - is not observed there), the model decodes it through the profile's mapping exactly like the
ingestion does, and evaluates. Two profiles that are configured correctly give the same business results on the same
fixture: state, stage reached, next milestone, statuses of the required milestones, finding codes, payments, amounts per
currency and duplicate exposure.

Calendar: weekends and the fixture's holidays. Time zone: every time of the fixtures is UTC (the ABAP unit tests cover
time-zone conversion separately).

Used by ops-framework/tools/payfile.py (house check payfile) and ops-suite/tools/tests (the first customer's profile).

Modification log:
2026-11-15 | Initial version (build K: payment file lifecycle).
"""
import csv
import datetime as dt
import json
import os
import re

ORDER = ['PAYRUN', 'GENERATED', 'PICKUP', 'DELIVERED', 'RECEIPT', 'ACCEPTED', 'SETTLED']
REACHED = ('REACHED', 'LATE', 'IMPLIED')
SEVERITY = {'REJECTED': 4, 'FAILED': 3, 'PARTIAL': 2, 'OK': 1}
MISSING_CODE = {'ACCEPTED': 'PF_ACK_MISSING', 'RECEIPT': 'PF_RECEIPT_MISSING', 'PICKUP': 'PF_NOT_TRANSFERRED',
                'DELIVERED': 'PF_NOT_TRANSFERRED', 'GENERATED': 'PF_NOT_GENERATED', 'SETTLED': 'PF_NOT_SETTLED'}
ROLES = ('FILE', 'TRANSFER', 'ACK', 'SCHED', 'STMT')


class FixtureError(ValueError):
    pass


def ts(text):
    return dt.datetime.strptime(text, '%Y-%m-%dT%H:%M:%S') if text else None


def day(text):
    return dt.datetime.strptime(text, '%Y-%m-%d').date() if text else None


def minutes(a, b):
    """Whole minutes from a to b (truncated toward zero, as the ABAP TRUNC of seconds / 60)."""
    if a is None or b is None:
        return 0
    return int((b - a).total_seconds() / 60)


class Calendar:
    def __init__(self, holidays):
        self.holidays = {day(h) for h in holidays}

    def is_business(self, d):
        return d.weekday() < 5 and d not in self.holidays

    def add_business_days(self, d, n):
        while not self.is_business(d):
            d += dt.timedelta(days=1)
        for _ in range(max(0, n)):
            d += dt.timedelta(days=1)
            while not self.is_business(d):
                d += dt.timedelta(days=1)
        return d


def rank(ms):
    return ORDER.index(ms) + 1 if ms in ORDER else 0


def business_date(ftype, gen_at, cal):
    d = gen_at.date()
    cutoff = ftype.get('day_cutoff')
    if cutoff and gen_at.time() >= dt.datetime.strptime(cutoff, '%H:%M:%S').time():
        d += dt.timedelta(days=1)
    return cal.add_business_days(d, 0)


def clock_due(bus_date, stage, cal):
    d = cal.add_business_days(bus_date, int(stage.get('day_offset', 0)))
    t = dt.datetime.strptime(stage.get('due_time', '00:00:00'), '%H:%M:%S').time()
    return dt.datetime.combine(d, t)


def observe(ms, events):
    best = None
    conflict = False
    for e in events:
        if e['milestone'] != ms or e['outcome'] in ('INFO', ''):
            continue
        if best is None:
            best = dict(outcome=e['outcome'], at=e['occurred_at'])
            continue
        if ms == 'ACCEPTED' and e['outcome'] != best['outcome'] and 'OK' in (e['outcome'], best['outcome']):
            conflict = True
        if e['occurred_at'] > best['at'] or (e['occurred_at'] == best['at']
                                             and SEVERITY.get(e['outcome'], 0) > SEVERITY.get(best['outcome'], 0)):
            best = dict(outcome=e['outcome'], at=e['occurred_at'])
    if best:
        best['at'] = min(e['occurred_at'] for e in events if e['milestone'] == ms and e['outcome'] == best['outcome'])
        best['conflict'] = conflict
        best['incomplete'] = False
    return best, conflict


def observe_scoped(ftype, events, payments, counts):
    by_payment = ftype['ack_level'] == 'P'
    scopes = {}
    for p in payments:
        scopes.setdefault(p['pay_key'] if by_payment else p.get('batch_id', ''), dict(outcome='', at=None, conflict=False))
    file_events = []
    for e in events:
        if e['milestone'] != 'ACCEPTED' or e['outcome'] in ('INFO', ''):
            continue
        key = e.get('pay_key', '') if by_payment else e.get('batch_id', '')
        if not key:
            file_events.append(e)
            continue
        sc = scopes.get(key)
        if sc is None:
            continue
        if sc['outcome'] and sc['outcome'] != e['outcome']:
            sc['conflict'] = True
        if not sc['outcome'] or e['occurred_at'] > sc['at'] or (
                e['occurred_at'] == sc['at'] and SEVERITY.get(e['outcome'], 0) > SEVERITY.get(sc['outcome'], 0)):
            sc['outcome'], sc['at'] = e['outcome'], e['occurred_at']
    file_level, file_conflict = observe('ACCEPTED', file_events) if file_events else (None, False)
    obs = dict(outcome='', at=None, conflict=file_conflict, incomplete=False)
    for sc in scopes.values():
        if not sc['outcome'] and file_level:
            sc['outcome'], sc['at'] = file_level['outcome'], file_level['at']
        if sc['conflict']:
            obs['conflict'] = True
        if sc['outcome'] == 'OK':
            counts['accepted'] += 1
        elif sc['outcome'] in ('REJECTED', 'FAILED'):
            counts['rejected'] += 1
        else:
            counts['open'] += 1
        if sc['at'] and (obs['at'] is None or sc['at'] > obs['at']):
            obs['at'] = sc['at']
    if counts['accepted'] + counts['rejected'] == 0:
        return None, obs['conflict']
    if counts['open'] == 0 and counts['rejected'] == 0:
        obs['outcome'] = 'OK'
    elif counts['open'] == 0 and counts['accepted'] == 0:
        obs['outcome'] = 'REJECTED'
    else:
        obs['outcome'] = 'PARTIAL'
    obs['incomplete'] = counts['open'] > 0
    return obs, obs['conflict']


def evaluate(ftype, stages, file, events, payments, health, now, cal):
    """The lifecycle of one file (ZCL_CA_OPS_PF_LIFECYCLE=>EVALUATE)."""
    active = [s for s in stages if s.get('active', True) and rank(s['milestone'])
              and not (ftype['ack_level'] == 'N' and s['milestone'] in ('RECEIPT', 'ACCEPTED'))]
    active.sort(key=lambda s: rank(s['milestone']))
    counts = dict(accepted=0, rejected=0, open=0)
    res = dict(milestones=[], conflict=False, late_ms='', late_min=0, eval_state='', eval_reason='',
               pay_accepted=0, pay_rejected=0, pay_open=0)
    observed = {}
    for s in active:
        if s['milestone'] == 'ACCEPTED' and ftype['ack_level'] in ('P', 'B'):
            o, c = observe_scoped(ftype, events, payments, counts)
        else:
            o, c = observe(s['milestone'], events)
        observed[s['milestone']] = o
        res['conflict'] = res['conflict'] or c
    res.update(pay_accepted=counts['accepted'], pay_rejected=counts['rejected'], pay_open=counts['open'])
    done = {}
    for s in active:
        ms = s['milestone']
        o = observed[ms]
        due = None
        if s.get('due_kind') == 'T' and file.get('bus_date'):
            due = clock_due(file['bus_date'], s, cal)
        elif s.get('due_kind') == 'O':
            if s['basis'] == 'PAYRUN' and file.get('gen_at') and 'PAYRUN' not in done:
                due = file['gen_at'] + dt.timedelta(minutes=int(s.get('offset_min', 0)))
            elif done.get(s['basis']) and done[s['basis']]['observed_at']:
                due = done[s['basis']]['observed_at'] + dt.timedelta(minutes=int(s.get('offset_min', 0)))
        passed = due is not None and now > due
        row = dict(milestone=ms, required=bool(s.get('required')), due_at=due, outcome=o['outcome'] if o else '',
                   observed_at=o['at'] if o else None, late_min=0)
        if o and not (o.get('incomplete') and not passed):
            row['status'] = {'REJECTED': 'REJECTED', 'PARTIAL': 'PARTIAL', 'FAILED': 'FAILED'}.get(o['outcome'], 'REACHED')
            if row['status'] == 'REACHED' and due is not None and o['at'] > due:
                row['status'] = 'LATE'
                row['late_min'] = minutes(due, o['at'])
                if not res['late_ms']:
                    res['late_ms'], res['late_min'] = ms, row['late_min']
        else:
            implied = any(observed[m] and observed[m]['outcome'] and rank(m) > rank(ms) for m in observed)
            if implied:
                row['status'] = 'IMPLIED'
            elif passed and ms in health:
                row['status'] = 'UNKNOWN'
                res['eval_state'] = health[ms]
            elif passed:
                row['status'] = 'MISSING'
            else:
                row['status'] = 'PENDING'
        done[ms] = row
        res['milestones'].append(row)
    # conclude
    stage, failed = '', False
    for r in res['milestones']:
        if r['status'] in REACHED:
            stage, failed = r['milestone'], False
        elif r['status'] == 'FAILED':
            failed = True
    res['stage'], res['next_ms'], res['deadline_at'], res['overdue_min'] = stage, '', None, 0
    open_required = False
    for r in res['milestones']:
        if not r['required'] or r['status'] in REACHED:
            continue
        open_required = True
        res['next_ms'], res['deadline_at'] = r['milestone'], r['due_at']
        if r['due_at'] is not None and now > r['due_at'] and r['status'] != 'UNKNOWN':
            res['overdue_min'] = minutes(r['due_at'], now)
        break
    statuses = {r['milestone']: r['status'] for r in res['milestones']}
    if statuses.get('ACCEPTED') == 'REJECTED':
        res['state'] = 'REJECTED'
    elif 'PARTIAL' in statuses.values():
        res['state'] = 'PARTIAL'
    elif failed:
        res['state'] = 'FAILED'
    elif not open_required:
        res['state'] = 'DONE'
    else:
        res['state'] = 'OPEN'
    if not res['eval_state']:
        res['eval_state'] = 'P' if file.get('pay_partial') else 'C'
    return res


def evaluate_day(ftype, inp, stale_min, now, cal):
    """The result of a business day (ZCL_CA_OPS_PF_LIFECYCLE=>EVALUATE_DAY)."""
    if not cal.is_business(inp['bus_date']):
        return 'HOLIDAY'
    if inp['source_status'] == 'F':
        return 'NOT_EVAL'
    expected = int(ftype.get('expected_files', 0))
    if inp['observed'] > 0 and inp['observed'] >= expected:
        return 'OK'
    due = inp.get('due_at') or now
    if now <= due:
        return 'PENDING'
    as_of = inp.get('as_of')
    if as_of is None or as_of < due:
        base = as_of if as_of is not None else due
        return 'STALE' if base + dt.timedelta(minutes=stale_min) < now else 'PENDING'
    if inp['observed'] == 0 and (ftype.get('zero_ok') or expected == 0):
        return 'ZERO_OK'
    return 'MISSING' if inp['observed'] == 0 else 'PARTIAL'


def amount_limit(limits, currency, bukrs):
    general = 0
    for entry in re.split(r'[,;]', limits or ''):
        entry = entry.strip().upper()
        if not entry:
            continue
        scope = ''
        if ':' in entry:
            scope, entry = entry.split(':', 1)
        parts = entry.split()
        if len(parts) != 2 or parts[0] != currency.upper():
            continue
        try:
            value = float(parts[1])
        except ValueError:
            continue
        if not scope:
            general = value
        elif scope.strip() == bukrs:
            return value
    return general


def issues(file, res, predecessor_res=None, successor_created=None):
    """The finding codes of one file (ZCL_CA_OPS_CHK_PAYFILE=>ISSUES), in order."""
    out = []
    if file.get('state_override') != 'REPLACED':
        for r in res['milestones']:
            if not r['required'] or r['status'] in REACHED:
                continue
            if r['status'] == 'MISSING':
                out.append((MISSING_CODE[r['milestone']], ''))
            elif r['status'] == 'FAILED':
                out.append(('PF_JOB_FAILED' if r['milestone'] == 'GENERATED' else 'PF_TRANSFER_FAILED', 'E'))
            elif r['status'] == 'REJECTED':
                out.append(('PF_ACK_REJECTED', 'E'))
            elif r['status'] == 'PARTIAL':
                out.append(('PF_ACK_PARTIAL', 'E'))
            break
    if res['conflict']:
        out.append(('PF_ACK_CONFLICT', 'E'))
    if res['late_ms'] and not out:
        out.append(('PF_STAGE_LATE', 'I'))
    if predecessor_res is not None:
        if any(r['status'] in REACHED and r['milestone'] in ('DELIVERED', 'RECEIPT', 'ACCEPTED')
               for r in predecessor_res['milestones']):
            out.append(('PF_DUP_EXPOSURE', 'B'))
    if file.get('state_override') == 'REPLACED' and successor_created is not None:
        if any(r['milestone'] in ('RECEIPT', 'ACCEPTED') and r['observed_at'] and r['observed_at'] > successor_created
               for r in res['milestones']):
            out.append(('PF_ORIG_ACK_AFTER_REISSUE', 'B'))
    return out


def severity(code_sev, overdue, amount, currency, bukrs, limits, grace, red_min):
    big = 0 < amount_limit(limits, currency, bukrs) <= abs(amount)
    if code_sev in ('B', 'I'):
        return code_sev
    if code_sev:
        return 'B' if big else code_sev
    if big or (red_min > 0 and overdue >= red_min):
        return 'B'
    return 'W' if overdue < (grace or 30) else 'E'


# --------------------------------------------------------------------------------------------------- profiles
def load_profile(path):
    """A profile: JSON {name, sources {role: source_id}} next to a status mapping CSV (ZCA_OPS_PFMAP columns), or one
    JSON with 'statuses'. The mapping CSV path is 'map' relative to the JSON."""
    with open(path, encoding='utf-8') as f:
        prof = json.load(f)
    if 'map' in prof:
        with open(os.path.join(os.path.dirname(path), prof['map']), newline='', encoding='utf-8') as f:
            prof['statuses'] = [dict(source_id=r['SOURCE_ID'], status=r['STATUS'], milestone=r['MILESTONE'],
                                     outcome=r['OUTCOME']) for r in csv.DictReader(f)]
    return prof


def encode(prof, role, milestone, outcome):
    """The native status a setup's source of the role uses for a canonical event (None = the setup cannot say it)."""
    src = prof['sources'].get(role)
    if not src:
        return None
    for r in prof['statuses']:
        if r['source_id'] == src and r['milestone'] == milestone and r['outcome'] == outcome:
            return src, r['status']
    return None


def decode(prof, source_id, status):
    for r in prof['statuses']:
        if r['source_id'] == source_id and r['status'] == status:
            return r['milestone'], r['outcome']
    return '', 'INFO'


def _events(prof, scenario_events):
    out = []
    for e in scenario_events:
        if e['role'] == 'FILE':
            # the file source itself evidences the payment run (the ingestion emits it, no mapping)
            out.append(dict(milestone=e['milestone'], outcome=e['outcome'], occurred_at=ts(e['occurred_at']),
                            pay_key='', batch_id='', source_id='FILE', native_status=''))
            continue
        native = encode(prof, e['role'], e['milestone'], e['outcome'])
        if native is None:
            continue
        ms, oc = decode(prof, *native)
        out.append(dict(milestone=ms, outcome=oc, occurred_at=ts(e['occurred_at']), pay_key=e.get('pay_key', ''),
                        batch_id=e.get('batch_id', ''), source_id=native[0], native_status=native[1]))
    return out


def _file(fx, f, cal):
    gen_at = ts(f.get('gen_at'))
    bus = day(f['bus_date']) if f.get('bus_date') else business_date(fx['file_type'], gen_at, cal)
    return dict(native_key=f['native_key'], gen_at=gen_at, bus_date=bus, bukrs=f.get('bukrs', ''),
                payments=f.get('payments', []), created_at=ts(f.get('created_at') or f.get('gen_at')))


def run_scenario(fx, sc, prof, cal=None):
    """Business result of one scenario in one setup."""
    cal = cal or Calendar(fx.get('holidays', []))
    ftype, stages = dict(fx['file_type'], **sc.get('file_type', {})), fx['stages']
    now = ts(sc['now'])
    health = {ms: flag for ms, flag in sc.get('health', {}).items()}
    files = {}
    for f in sc['files']:
        files[f['native_key']] = _file(fx, f, cal)
    results = {}
    for key, f in files.items():
        evts = _events(prof, [e for e in sc['events']
                              if (not e.get('covers') and e.get('file', sc['files'][0]['native_key']) == key)
                              or key in e.get('covers', [])])
        f['res'] = evaluate(ftype, stages, f, evts, f['payments'], health, now, cal)
    for spec in sc['files']:
        key = spec['native_key']
        f = files[key]
        pred = files.get(spec.get('predecessor')) if spec.get('predecessor') else None
        succ = next((files[s['native_key']] for s in sc['files'] if s.get('predecessor') == key), None)
        if succ is not None:
            f['state_override'] = 'REPLACED'
        codes = issues(f, f['res'], pred['res'] if pred else None, succ['created_at'] if succ else None)
        shared = {p['pay_key'] for p in f['payments']} & (
            {p['pay_key'] for p in pred['payments']} if pred else set()) | (
            {p['pay_key'] for p in f['payments']} & {p['pay_key'] for p in succ['payments']} if succ else set())
        totals = {}
        for p in f['payments']:
            t = totals.setdefault(p['currency'], dict(payments=0, amount=0.0, dup_amount=0.0, dup_payments=0))
            t['payments'] += 1
            t['amount'] = round(t['amount'] + float(p['amount']), 2)
            if p['pay_key'] in shared:
                t['dup_payments'] += 1
                t['dup_amount'] = round(t['dup_amount'] + float(p['amount']), 2)
        findings = []
        for code, sev in codes:
            exposure = code in ('PF_DUP_EXPOSURE', 'PF_ORIG_ACK_AFTER_REISSUE')
            for cur, t in sorted(totals.items()):
                findings.append(dict(
                    code=code, currency=cur,
                    severity=severity(sev, f['res']['overdue_min'], t['amount'], cur, f['bukrs'],
                                      fx.get('amount_red', ''), _grace(fx, stages, f['res']['next_ms']),
                                      int(fx.get('red_min', 240))),
                    payments=t['dup_payments'] if exposure else t['payments'],
                    amount=0.0 if exposure else t['amount'],
                    dup_amount=t['dup_amount'] if exposure else 0.0))
        r = f['res']
        results[key] = dict(state='REPLACED' if succ is not None else r['state'], stage=r['stage'], next_ms=r['next_ms'],
                            overdue_min=r['overdue_min'], eval_state=r['eval_state'],
                            required={m['milestone']: m['status'] for m in r['milestones'] if m['required']},
                            findings=findings)
    return results


def _grace(fx, stages, milestone):
    stage = next((s for s in stages if s['milestone'] == milestone), {})
    return int(stage.get('grace_min') or fx.get('grace_min', 30))


def run_day(fx, d, cal=None):
    cal = cal or Calendar(fx.get('holidays', []))
    stage = next((s for s in sorted(fx['stages'], key=lambda s: rank(s['milestone'])) if s.get('due_kind') == 'T'), None)
    bus = day(d['date'])
    due = clock_due(bus, stage, cal) if stage else dt.datetime.combine(bus, dt.time(23, 59, 59))
    inp = dict(bus_date=bus, observed=d['observed'], source_status=d.get('source_status', 'S'),
               as_of=ts(d.get('as_of')), due_at=due)
    ftype = dict(fx['file_type'], **d.get('file_type', {}))
    return evaluate_day(ftype, inp, int(ftype.get('stale_min', 120)), ts(d['now']), cal)


def check_fixtures(fixture_path, profile_paths):
    """Failures: a scenario whose result in a profile differs from its expectation, or two profiles that differ."""
    with open(fixture_path, encoding='utf-8') as f:
        fx = json.load(f)
    failures = []
    profiles = [load_profile(p) for p in profile_paths]
    cal = Calendar(fx.get('holidays', []))
    for sc in fx['scenarios']:
        seen = None
        for prof in profiles:
            res = run_scenario(fx, sc, prof, cal)
            for key, exp in sc['expect'].items():
                got = res.get(key)
                if got is None:
                    failures.append(f"{sc['id']} / {prof['name']}: file {key} not evaluated")
                    continue
                for field, value in exp.items():
                    if field == 'codes':
                        actual = sorted({x['code'] for x in got['findings']})
                        if actual != sorted(value):
                            failures.append(f"{sc['id']} / {prof['name']} / {key}: codes {actual} != {sorted(value)}")
                    elif field == 'findings':
                        actual = [{k: x[k] for k in v} for x, v in zip(got['findings'], value)]
                        if actual != value:
                            failures.append(f"{sc['id']} / {prof['name']} / {key}: findings {got['findings']} != {value}")
                    elif got.get(field) != value and not (field == 'required' and
                                                          {k: got['required'].get(k) for k in value} == value):
                        failures.append(f"{sc['id']} / {prof['name']} / {key}: {field} {got.get(field)!r} != {value!r}")
            if seen is not None and res != seen[1]:
                failures.append(f"{sc['id']}: profiles {seen[0]} and {prof['name']} give different business results")
            seen = (prof['name'], res)
    for d in fx.get('days', []):
        got = run_day(fx, d, cal)
        if got != d['expect']:
            failures.append(f"day {d['id']}: {got} != {d['expect']}")
    return failures
