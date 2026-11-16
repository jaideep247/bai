#!/usr/bin/env python3
"""Reference model of the expected runs and of the FI-CA mass activity check of the operations framework ZCA_OPS
(ops-framework/docs/EXPECTED_RUNS_AND_MASS_ACTIVITIES.md, build P; runtime twins ZCL_CA_OPS_XRUN_MONITOR,
ZCL_CA_OPS_CHK_XRUN and ZCL_CA_OPS_CHK_MA_INTERVAL). Offline and pure: the fixture spec
ops-framework/config/expected_runs/fixtures.json is run through it by the root test tools/tests/test_expected_runs.py,
which also checks the codes against the types interfaces and that every scenario names an existing ABAP Unit method.

First principle: a run the scheduler planned is expected until SAP shows its job; a run that ended is only complete
when its intervals finished and its documents are there. A stale or unreadable plan is never "nothing expected".

Times of the fixtures are the server clock, equal to UTC in the spec.

Modification log:
2026-11-16 | Initial version (build P: expected runs and FI-CA mass-activity intervals).
"""
import datetime

from . import evaluation

FMT = '%Y-%m-%dT%H:%M:%S'
WAITING = {'P', 'S', 'Y'}
ACTIVE = {'R', 'Z'}


def ts(text):
    return datetime.datetime.strptime(text, FMT) if text else None


def text(stamp):
    return stamp.strftime(FMT) if stamp else ''


# ------------------------------------------------------------------------------------------------ expected runs
def _job_point(job):
    for key in ('start', 'planned', 'created'):
        if job.get(key):
            return ts(job[key])
    return None


def _match(run, jobs, used, cfg):
    import re
    plan = ts(run['plan'])
    low = plan - datetime.timedelta(minutes=cfg['early_min'])
    high = plan + datetime.timedelta(minutes=cfg['match_min'])
    started, waiting = None, None
    for job in jobs:
        key = (job['name'], job['count'])
        if key in used or not re.fullmatch(run['pattern'], job['name'], re.I):
            continue
        point = _job_point(job)
        if point is None or point < low or point > high:
            continue
        if job.get('start'):
            if started is None or point <= ts(started['start']):
                started = job
        elif waiting is None:
            waiting = job
    return started or waiting


def judge(runs, jobs, cfg, now):
    """Verdict of every run: OK, LATE, PENDING, HELD, PRED_OPEN, NEVER (stage SCHEDULER / HANDOVER / SAP_QUEUE)."""
    used, results = set(), []
    for run in sorted(runs, key=lambda r: (r['plan'], r['folder'], r['job'])):
        job = _match(run, jobs, used, cfg)
        if job:
            used.add((job['name'], job['count']))
        late = run.get('late_min') or cfg['late_min']
        results.append({'run': run, 'job': job, 'due': ts(run['plan']) + datetime.timedelta(minutes=late)})
    for res in results:
        run, job, plan = res['run'], res['job'], ts(res['run']['plan'])
        res['stage'] = ''
        if job and job.get('start'):
            start = ts(job['start'])
            res['late_minutes'] = max(0, int((start - plan).total_seconds() // 60))
            res['verdict'] = 'OK' if start <= res['due'] else 'LATE'
            res['stage'] = '' if res['verdict'] == 'OK' else 'LATE_START'
            continue
        if now < plan:
            res['verdict'] = 'PENDING'
            continue
        if run.get('state') == 'HELD':
            res['verdict'], res['stage'] = 'HELD', 'SCHEDULER'
            continue
        if now <= res['due']:
            res['verdict'] = 'PENDING'
            continue
        pred = None
        if run.get('pred_job'):
            for other in results:
                if (other['run']['folder'], other['run']['job']) == (run['pred_folder'], run['pred_job']) \
                        and other['run']['plan'][:10] == run['plan'][:10]:
                    done = (other['job'] or {}).get('status') == 'F' or \
                        (not other['job'] and other['run'].get('state') == 'ENDED_OK')
                    if not done:
                        pred = other
                        break
        if pred:
            res['verdict'], res['stage'], res['pred'] = 'PRED_OPEN', 'WAIT_PRED', pred
            continue
        res['verdict'] = 'NEVER'
        if job:
            res['stage'] = 'SAP_QUEUE'
        elif run.get('state') in ('STARTED', 'ENDED_OK', 'ENDED_NOK'):
            res['stage'] = 'HANDOVER'
        else:
            res['stage'] = 'SCHEDULER'
    return results


XRUN_CODE = {'NEVER': ('XRUN_NEVER_STARTED', 'E'), 'PRED_OPEN': ('XRUN_PRED_NOT_FINISHED', 'E'),
             'HELD': ('XRUN_HELD', 'W'), 'LATE': ('XRUN_STARTED_LATE', 'W')}


def _notice(code, key):
    return {'check_code': code, 'severity': 'W', 'action': 'NOTIFY', 'stage': 'SOURCE', 'object_key': key,
            'item_count': 0, 'unknown_count': 1, 'amount': '0.00', 'currency': '', 'deadline': '',
            'owner': 'ZT_OWNER'}


def xrun(fixture, spec):
    """Findings, evaluation and partial flag of the expected-run check for one fixture."""
    cfg = dict(spec['defaults']['xrun'])
    cfg.update(fixture.get('parameters', {}))
    now = ts(spec['now'])
    given = fixture['given']
    findings, terms, partial, runs = [], [], False, []
    plan = given.get('plan')
    if given.get('source_fails'):
        findings.append(_notice('XRUN_SOURCE_FAILED', given['source']))
        terms.append(('NOT_EVAL', False))
        partial = True
    else:
        stale_min = plan.get('stale_min') or cfg['stale_min']
        newest = ts(plan['newest_at'])
        if newest is None or (now - newest).total_seconds() > stale_min * 60:
            findings.append(_notice('XRUN_SOURCE_STALE', given['source']))
            terms.append(('STALE', False))
        terms.extend(('HOLIDAY', False) for _ in plan.get('not_expected', []))
        runs = plan.get('runs', [])
    for res in judge(runs, given.get('TBTCO', []), cfg, now):
        if res['verdict'] == 'PENDING':
            continue
        if res['verdict'] == 'OK':
            terms.append(('OK', False))
            continue
        code, severity = XRUN_CODE[res['verdict']]
        run = res['run']
        evidence = [{'kind': 'SCHD', 'type': 'RUN', 'quality': 'C'},
                    {'kind': 'SAP', 'type': 'JOB', 'quality': 'P' if res['job'] else 'U'}]
        if res.get('pred'):
            evidence += [{'kind': 'SCHD', 'type': 'RUN', 'quality': 'C'},
                         {'kind': 'SAP', 'type': 'JOB', 'quality': 'P' if res['pred']['job'] else 'U'}]
        findings.append({'check_code': code, 'severity': severity, 'action': 'EXCEPTION', 'stage': res['stage'],
                         'object_key': f"{run['job']}/{run['plan'][:10].replace('-', '')}"
                                       f"{run['plan'][11:16].replace(':', '')}",
                         'item_count': 1, 'unknown_count': 1, 'amount': '0.00', 'currency': '',
                         'deadline': text(res['due']), 'owner': 'ZT_OWNER', 'evidence': evidence})
        terms.append(('OBSERVED', True))
    part = evaluation.merge(terms)
    return findings, part['class'] or ('NOT_EVAL' if part['unevaluated'] else ''), partial


# ------------------------------------------------------------------------------------------------ mass activities
def _state(status):
    return {'F': 'OK', 'A': 'FAILED'}.get(status, 'RUNNING' if status in ACTIVE else 'WAITING')


def intervals(parent, jobs):
    children = sorted((j for j in jobs if j.get('parent') == f"{parent['name']}/{parent['count']}"),
                      key=lambda j: (j.get('created', ''), j['name'], j['count']))
    return [{'number': n, 'job': j, 'state': _state(j['status']), 'minutes': j.get('minutes', 0)}
            for n, j in enumerate(children, start=1)]


def payment_output(rows, run_date, run_id, order_methods=(), with_proposal=False):
    """The payment run check's sum (ZCL_CA_OPS_CHK_CASH_PAYRUN=>SUM_BY_RUN) and the expectation of the output."""
    sums = {}
    for row in rows:
        key = (row['LAUFD'], row['LAUFI'], bool(row.get('XVORL')), row['BBUKR'], row['WAERS'])
        cur = sums.setdefault(key, {'count': 0, 'amount': 0.0, 'nodoc': 0, 'nodoc_amount': 0.0})
        amount = float(row['RWBTR'])
        cur['count'] += 1
        cur['amount'] += amount
        if not row.get('DOC1R') and row.get('RZAWE', '') not in order_methods:
            cur['nodoc'] += 1
            cur['nodoc_amount'] += amount
    out = []
    for (laufd, laufi, proposal, bukrs, waers), cur in sorted(sums.items()):
        if proposal or laufd != run_date or (run_id and laufi != run_id):
            continue
        item = {'run_id': laufi, 'company_code': bukrs, 'currency': waers, 'expected': cur['count'],
                'expected_amount': cur['amount'], 'observed': cur['count'] - cur['nodoc'],
                'observed_amount': cur['amount'] - cur['nodoc_amount'], 'with_amount': True}
        prop = sums.get((laufd, laufi, True, bukrs, waers))
        if with_proposal and prop and prop['count'] > item['expected']:
            item['expected'], item['expected_amount'] = prop['count'], prop['amount']
        out.append(item)
    return out


def ma(fixture, spec):
    """Findings, evaluation and partial flag of the mass activity check for one fixture."""
    cfg = dict(spec['defaults']['ma'])
    cfg.update(fixture.get('parameters', {}))
    given, act = fixture['given'], fixture['given']['activity']
    if given.get('source_fails'):
        return [{'check_code': 'CASH_NOT_EVALUATED', 'severity': 'W', 'action': 'NOTIFY', 'stage': 'INTERVAL'}], \
            'NOT_EVAL', True
    findings, terms, judged = [], [], set()
    jobs = given.get('TBTCO', [])
    for parent in (j for j in jobs if j.get('role') == 'parent'):
        run_date = parent['start'][:10].replace('-', '')
        ended = parent['status'] in ('F', 'A')
        parent_ok = parent['status'] == 'F'
        limit = act.get('run_limit_min') or cfg['run_limit_min']
        bad, long_ = [], []
        for itv in intervals(parent, jobs):
            if itv['state'] == 'FAILED' or (ended and itv['state'] in ('RUNNING', 'WAITING')):
                bad.append(itv)
            elif itv['state'] == 'RUNNING' and itv['minutes'] > limit:
                long_.append(itv)
        raised = False
        outputs = []
        if ended and (act['act_id'], run_date) not in judged:
            judged.add((act['act_id'], run_date))
            if act['output_kind'] == 'PAYDOC':
                outputs = payment_output(given.get('DPAYH', []), run_date, '', cfg.get('order_methods', ()),
                                         cfg.get('with_proposal', False))
            elif act['output_kind'] == 'DUNNING' and act.get('min_output', 0) > 0:
                count = sum(1 for r in given.get('FKKMAKO', []) if r['LAUFD'] == run_date)
                outputs = [{'run_id': '', 'company_code': '', 'currency': '', 'expected': act['min_output'],
                            'expected_amount': 0.0, 'observed': count, 'observed_amount': 0.0,
                            'with_amount': False}]
        for out in outputs:
            if out['observed'] >= out['expected']:
                continue
            short = out['expected'] - out['observed']
            amount = out['expected_amount'] - out['observed_amount'] if out['with_amount'] else 0.0
            key = '/'.join(x for x in (act['act_id'], run_date, out['run_id']) if x)
            if out['company_code'] or out['currency']:
                key += f"/{out['company_code']}/{out['currency'] if out['with_amount'] else ''}"
            findings.append({'check_code': 'MA_OUTPUT_SHORT', 'severity': 'E', 'action': 'EXCEPTION',
                             'stage': 'JOB_OK' if parent_ok else 'OUTPUT', 'object_key': key,
                             'company_code': out['company_code'],
                             'currency': out['currency'] if out['with_amount'] else '',
                             'item_count': short, 'amount': f'{amount:.2f}',
                             'unknown_count': 0 if out['with_amount'] else short, 'owner': 'ZT_OWNER',
                             'evidence': _ma_evidence(act, parent, run_date, out['run_id'], bad)})
            raised = True
        if not raised and bad:
            findings.append({'check_code': 'MA_INTERVAL_FAILED', 'severity': 'E', 'action': 'EXCEPTION',
                             'stage': 'JOB_OK' if ended and parent_ok else 'INTERVAL',
                             'object_key': f"{act['act_id']}/{run_date}", 'company_code': '', 'currency': '',
                             'item_count': len(bad), 'amount': '0.00', 'unknown_count': len(bad),
                             'owner': 'ZT_OWNER', 'evidence': _ma_evidence(act, parent, run_date, '', bad)})
            raised = True
        if long_:
            findings.append({'check_code': 'MA_INTERVAL_OVERRUN', 'severity': 'W', 'action': 'EXCEPTION',
                             'stage': 'INTERVAL', 'object_key': f"{act['act_id']}/{run_date}",
                             'company_code': '', 'currency': '', 'item_count': len(long_), 'amount': '0.00',
                             'unknown_count': len(long_), 'owner': 'ZT_OWNER',
                             'evidence': _ma_evidence(act, parent, run_date, '', long_)})
            raised = True
        if raised:
            terms.append(('OBSERVED', True))
        elif ended:
            terms.append(('OK', False))
    part = evaluation.merge(terms)
    return findings, part['class'] or 'OK', False


def _ma_evidence(act, parent, run_date, run_id, itvs):
    rows = [{'name': 'AKTYP/LAUFD/LAUFI', 'value': f"{act['aktyp']}/{run_date}/{run_id}"},
            {'name': 'JOBNAME/JOBCOUNT', 'value': f"{parent['name']}/{parent['count']}"}]
    if act['output_kind'] == 'PAYDOC':
        rows.append({'name': 'LAUFD/LAUFI', 'value': f'{run_date}/{run_id}'})
    for itv in itvs:
        rows.append({'name': 'INTERVAL', 'value': str(itv['number'])})
        rows.append({'name': 'JOBNAME/JOBCOUNT', 'value': f"{itv['job']['name']}/{itv['job']['count']}"})
    return rows


def run(fixture, spec):
    return (xrun if fixture['kind'] == 'xrun' else ma)(fixture, spec)
