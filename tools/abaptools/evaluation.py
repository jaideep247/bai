#!/usr/bin/env python3
"""Reference model of the evaluation state, the period-close rule and the monitor coverage of the operations
framework ZCA_OPS (docs/EVALUATION_AND_COVERAGE.md; runtime twins ZCL_CA_OPS_EVAL, ZCL_CA_OPS_EVAL_PERIOD and
ZCL_CA_OPS_COVERAGE). Offline and pure: the fixture spec ops-framework/config/evaluation/fixtures.json is run through
it by the root test tools/tests/test_evaluation.py, which also checks that the codes are those of
ZIF_CA_OPS_EVAL_TYPES and of the domains, and that every scenario names an existing ABAP Unit method.

First principle: unknown is never green. A check run is complete (C), partial (P) or not evaluated (N); its result
class is OK, ZERO_OK, HOLIDAY, PER_CLOSED, STALE, NOT_EVAL or FINDINGS; support sees one display state, completeness
first.

Modification log:
2026-11-16 | Initial version (build O: evaluation state, delivery confirmation, monitor coverage).
"""
import datetime

STATES = ('OK', 'ZERO_OK', 'HOLIDAY', 'PER_CLOSED', 'FINDINGS', 'PARTIAL', 'STALE', 'NOT_EVAL')
RANK = {state: rank for rank, state in enumerate(STATES)}
COMPLETENESS = ('C', 'P', 'N')
COVERAGE = ('DISABLED', 'REFUSED', 'NOT_RUN', 'IMPAIRED', 'WARNED', 'RAN')
EXCEPTION_SEVERITIES = {'B', 'E', 'W'}
BLOCKING = {'B', 'E'}

# Terms of the earlier vocabularies: (class, evaluated, unevaluated); None = no contribution (PENDING, unknown)
TERMS = {
    'OK': ('OK', True, False), 'ZERO_OK': ('ZERO_OK', True, False), 'HOLIDAY': ('HOLIDAY', True, False),
    'PER_CLOSED': ('PER_CLOSED', True, False), 'STALE': ('STALE', True, False), 'FINDINGS': ('FINDINGS', True, False),
    'NOT_EVAL': (None, False, True),
    # build K: day results
    'MISSING': ('FINDINGS', True, False), 'PARTIAL': ('FINDINGS', True, False), 'PENDING': None,
    # build N: evaluations of the cash checks
    'OBSERVED': ('OK', True, False), 'ZERO_VOLUME': ('ZERO_OK', True, False), 'NOT_EXPECTED': ('HOLIDAY', True, False),
    'NOT_EVALUATED': (None, False, True),
}


def rank(state):
    return RANK.get(state or '', RANK['NOT_EVAL'])


def worse_of(one, other):
    return other if rank(other) > rank(one) else one


def of_term(term, exception=False):
    """(class, evaluated, unevaluated) of a term; OBSERVED with an owned exception is FINDINGS."""
    found = TERMS.get((term or '').strip().upper())
    if not found:
        return None, False, False
    state, evaluated, unevaluated = found
    if term.upper() in ('OK', 'OBSERVED') and exception:
        state = 'FINDINGS'
    return state, evaluated, unevaluated


def merge(terms):
    """Fold [(term, exception)] into the optional result part: class, evaluated and unevaluated counts."""
    part = {'class': '', 'evaluated': 0, 'unevaluated': 0}
    for term, exception in terms:
        state, evaluated, unevaluated = of_term(term, exception)
        if evaluated:
            part['evaluated'] += 1
            part['class'] = state if not part['class'] else worse_of(part['class'], state)
        elif unevaluated:
            part['unevaluated'] += 1
    return part


def display_state(result_class, completeness):
    if completeness == 'N' or not result_class or result_class == 'NOT_EVAL':
        return 'NOT_EVAL'
    if result_class == 'STALE':
        return 'STALE'
    if completeness == 'P':
        return 'PARTIAL'
    return result_class


def is_unknown(state):
    return not state or state in ('NOT_EVAL', 'STALE', 'PARTIAL')


def _ts(text):
    return datetime.datetime.strptime(text, '%Y-%m-%dT%H:%M:%S')


def is_stale(newest_at, now, limit_min):
    if not newest_at:
        return True
    if limit_min <= 0:
        return False
    return (_ts(now) - _ts(newest_at)).total_seconds() > limit_min * 60


def derive(scenario):
    """The evaluation record of one check run: {completeness, class, state, finding_count}. The scenario carries
    terms [[term, exception]], findings [severities], partial, raised, period_closed, sources [{newest_at, stale_min}],
    now, source_stale_min, and optionally the check's own class / completeness."""
    part = merge([(t[0], bool(t[1])) for t in scenario.get('terms', [])])
    if scenario.get('class'):
        part['class'] = scenario['class']
    findings = scenario.get('findings', [])
    finding_count = sum(1 for s in findings if s in EXCEPTION_SEVERITIES)
    blocking = any(s in BLOCKING for s in findings)
    partial = bool(scenario.get('partial'))
    if scenario.get('raised'):
        completeness = 'N'
    elif scenario.get('completeness'):
        completeness = 'P' if scenario['completeness'] == 'C' and partial else scenario['completeness']
    elif part['unevaluated'] and not part['evaluated']:
        completeness = 'N'
    elif part['unevaluated'] or partial:
        completeness = 'P'
    else:
        completeness = 'C'
    stale_sources = [s for s in scenario.get('sources', [])
                     if is_stale(s.get('newest_at'), scenario.get('now', ''),
                                 s.get('stale_min') or scenario.get('source_stale_min', 0))]
    if completeness == 'N':
        result_class = 'NOT_EVAL'
    else:
        result_class = part['class']
        if not result_class or result_class == 'NOT_EVAL':
            result_class = 'FINDINGS' if finding_count else 'OK'
        elif blocking and rank(result_class) < rank('FINDINGS'):
            result_class = 'FINDINGS'
        if result_class in ('OK', 'ZERO_OK'):
            if stale_sources:
                result_class = 'STALE'
            elif scenario.get('period_closed'):
                result_class = 'PER_CLOSED'
    return {'completeness': completeness, 'class': result_class,
            'state': display_state(result_class, completeness), 'finding_count': finding_count}


def period_closed(entries, area, period, bukrs_list=''):
    """The rule of ZCL_CA_OPS_EVAL_PERIOD=>CLOSED_IN on the entries of EVAL_PERIOD_CLOSED."""
    def closes(entry, bukrs):
        parts = [p.strip().upper() for p in entry.split(':')]
        if len(parts) == 2:
            return parts[0] in (area.upper(), '*') and parts[1] == period
        if len(parts) == 3:
            return bool(bukrs) and parts[0] in (area.upper(), '*') and parts[1] == bukrs.upper() and parts[2] == period
        return False
    if not entries or not period:
        return False
    codes = [b.strip() for b in bukrs_list.split(',') if b.strip()]
    if not codes:
        return any(closes(e, '') for e in entries)
    return all(any(closes(e, b) for e in entries) for b in codes)


def coverage_state(case):
    """The rule of ZCL_CA_OPS_COVERAGE=>STATE: active, lic_allowed, lic_warned, evaluated_at, eval_state, now,
    window_min."""
    if not case.get('active', True):
        return 'DISABLED'
    if not case.get('lic_allowed', True):
        return 'REFUSED'
    evaluated_at = case.get('evaluated_at')
    window = case.get('window_min', 0)
    if not evaluated_at or (window > 0 and is_stale(evaluated_at, case['now'], window)):
        return 'NOT_RUN'
    if is_unknown(case.get('eval_state')):
        return 'IMPAIRED'
    if case.get('lic_warned'):
        return 'WARNED'
    return 'RAN'


def delivery_state(answer):
    """The state stored for a channel's answer (ZCL_CA_OPS_ALERT_CONFIRM=>APPLY): no answer = cannot confirm."""
    return answer if answer in ('P', 'D', 'F', 'N') else 'N'
