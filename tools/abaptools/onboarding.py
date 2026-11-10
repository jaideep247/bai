#!/usr/bin/env python3
"""Offline completeness check of the registered business processes of a component (process onboarding of
the operations framework ZCA_OPS; the runtime twin is the class ZCL_CA_OPS_CHK_ONBOARD).

Reads the seed files of a component's config/ folder - the same columns as the tables, one row per table
row (written by tools/abaptools/new_process.py):

  process_register.csv   ZCA_OPS_PROC     AREA, PROCESS_ID, DESCRIPTION, OWNER, BACKUP, RUNBOOK_URL, AUTH_ROLE,
                                          OWN_DATA, PURGE_TARGET, ACTIVE, SEQ
  check_registry.csv     ZCA_OPS_CHECK    AREA, CHECK_ID, PROCESS_ID, DESCRIPTION, CLASS_NAME, SCHED_GROUP,
                                          BUKRS_AWARE, ACTIVE, SEQ
  check_aggregates.csv   ZCA_OPS_AGG      AREA, CHECK_ID, AGG_ID, ... TABNAME ... ACTIVE
  approved_tables.csv    ZCA_OPS_TABWL    AREA, TABLE_NAME, ACTIVE, APPROVED_BY, DESCRIPTION
  control_register.csv   ZCA_OPS_CONTROL  AREA, CONTROL_ID, ..., ACTIVE
  control_checks.csv     ZCA_OPS_CTLCHK   AREA, CONTROL_ID, CHECK_AREA, MATCH_FIELD, MATCH_VALUE
  alert_rules*.csv       ZCA_OPS_ALRULE   RULE_ID, AREA, ..., ACTIVE        (any file of that name under config/)
  purge_targets.csv      ZCA_OPS_PURGE    TARGET, CLASS_NAME, PARAM_AREA, PARAM_NAME, ACTIVE
  param_areas*.csv       ZCA_PARAM_AREA   AREA, ..., ACTIVE                 (any file of that name under config/)

and fails when a registered process is not integrated end to end:

  checks        at least one check row of the process (an active process: an active one); every check of a
                process names an existing process; a class that is a file of the component or of the
                framework's src/ (the class of an inactive row may still be a skeleton outside src/)
  control       every check of the process covered by a control_checks row (CHECK_AREA = area, MATCH_FIELD =
                GROUP2, MATCH_VALUE = check ID) of a control of control_register.csv
  alert rule    an alert rule row of the process's own area (active for an active process)
  ownership     OWNER filled, or the process's document docs/processes/<AREA>_<PROCESS_ID>.md with a line
                'Owner team: <team>' (seed files name no person; the runtime check needs a real user)
  purge         OWN_DATA = X needs PURGE_TARGET; a named target is a row of purge_targets.csv
  authorisation AUTH_ROLE filled and named in an authorisation sheet of the component (auth_docs); the area
                a row of a param_areas file of the component or of the framework
  placeholders  a row with a placeholder (text between the angle quotes U+2039 / U+203A) or a VERIFY marker
                is never active; aggregate rows name an approved table of the area and a check of class
                ZCL_CA_OPS_CHK_AGG

Offline evidence of configuration completeness only - not SAP activation or DDIC existence.

Modification log:
2026-11-10 | Initial version (process onboarding framework).
"""
import csv
import os
import re

AGG_CLASS = 'ZCL_CA_OPS_CHK_AGG'
PLACEHOLDER = re.compile('‹[^›]*›|VERIFY-')
OWNER_LINE = re.compile(r'^Owner team:[ \t]*(\S.*)$', re.M)
YES = 'X'


def rows(path):
    """Rows of a CSV seed file as dicts (upper-case keys); a missing file has no rows."""
    if not os.path.isfile(path):
        return []
    with open(path, encoding='utf-8', newline='') as handle:
        return [{k.strip().upper(): (v or '').strip() for k, v in row.items() if k} for row in csv.DictReader(handle)]


def rows_like(config, prefix):
    """Rows of every CSV under config/ whose name starts with prefix (e.g. alert_rules*.csv)."""
    out = []
    for d, _, names in os.walk(config):
        for name in sorted(names):
            if name.startswith(prefix) and name.endswith('.csv'):
                out += rows(os.path.join(d, name))
    return out


def active(row):
    return row.get('ACTIVE', '') == YES


def has_placeholder(row):
    return any(PLACEHOLDER.search(v) for v in row.values())


def class_exists(name, source_roots):
    file_name = name.lower() + '.clas.abap'
    for root in source_roots:
        for _, _, names in os.walk(root):
            if file_name in names:
                return True
    return False


def load(root, extra_roots=()):
    """The seed rows of a component (and the areas of the components it builds on)."""
    config = os.path.join(root, 'config')
    data = {
        'processes': rows(os.path.join(config, 'process_register.csv')),
        'checks': rows(os.path.join(config, 'check_registry.csv')),
        'aggregates': rows(os.path.join(config, 'check_aggregates.csv')),
        'tables': rows(os.path.join(config, 'approved_tables.csv')),
        'controls': rows(os.path.join(config, 'control_register.csv')),
        'covered': rows(os.path.join(config, 'control_checks.csv')),
        'rules': rows_like(config, 'alert_rules'),
        'targets': rows(os.path.join(config, 'purge_targets.csv')),
        'areas': rows_like(config, 'param_areas'),
    }
    for extra in extra_roots:
        data['areas'] += rows_like(os.path.join(extra, 'config'), 'param_areas')
    return data


def failures(root, auth_docs, source_roots, extra_roots=()):
    """Failures of the completeness check of the component at root.

    auth_docs     authorisation sheets (paths relative to root) a role must be named in
    source_roots  folders whose ABAP classes a check may name (the component's src/, the framework's src/)
    extra_roots   components whose parameter areas count (the framework for a consumer)
    """
    data = load(root, extra_roots)
    out = []
    auth_text = ''
    for rel in auth_docs:
        path = os.path.join(root, rel)
        if os.path.isfile(path):
            with open(path, encoding='utf-8') as handle:
                auth_text += handle.read() + '\n'
    areas = {a['AREA'] for a in data['areas']}
    processes = {(p['AREA'], p['PROCESS_ID']): p for p in data['processes']}
    controls = {(c['AREA'], c['CONTROL_ID']) for c in data['controls']}
    covered = {(c['CHECK_AREA'], c['MATCH_VALUE']) for c in data['covered']
               if c.get('MATCH_FIELD') == 'GROUP2' and (c['AREA'], c['CONTROL_ID']) in controls}
    targets = {t['TARGET'] for t in data['targets']}
    approved = {(t['AREA'], t['TABLE_NAME']) for t in data['tables']}
    checks = {(c['AREA'], c['CHECK_ID']): c for c in data['checks']}

    # placeholders and VERIFY markers only in inactive rows
    for kind in ('processes', 'checks', 'aggregates', 'tables', 'rules'):
        for row in data[kind]:
            if active(row) and has_placeholder(row):
                out.append(f'{kind}: active row with a placeholder or VERIFY marker: {list(row.values())[:3]}')

    for key, check in checks.items():
        label = '/'.join(key)
        if check.get('PROCESS_ID') and (check['AREA'], check['PROCESS_ID']) not in processes:
            out.append(f'check {label}: process {check["PROCESS_ID"]} is not registered')
        name = check.get('CLASS_NAME', '')
        if not name:
            out.append(f'check {label}: no class')
        elif active(check) and not class_exists(name, [os.path.join(root, r) for r in source_roots]):
            out.append(f'check {label}: class {name} is not a class of the component or the framework')

    for agg in data['aggregates']:
        label = f'{agg["AREA"]}/{agg["CHECK_ID"]}/{agg["AGG_ID"]}'
        check = checks.get((agg['AREA'], agg['CHECK_ID']))
        if check is None:
            out.append(f'aggregate {label}: check not registered')
        elif check.get('CLASS_NAME', '').upper() != AGG_CLASS:
            out.append(f'aggregate {label}: check class is not {AGG_CLASS}')
        if (agg['AREA'], agg.get('TABNAME', '')) not in approved:
            out.append(f'aggregate {label}: table {agg.get("TABNAME", "")} not approved for the area')

    for key, proc in processes.items():
        label = '/'.join(key)
        is_active = active(proc)
        own = [c for c in checks.values() if (c['AREA'], c.get('PROCESS_ID')) == key]
        if not own or (is_active and not any(active(c) for c in own)):
            out.append(f'process {label}: no {"active " if is_active else ""}check')
        for check in own:
            if (check['AREA'], check['CHECK_ID']) not in covered:
                out.append(f'process {label}: check {check["CHECK_ID"]} covered by no control (GROUP2 row)')
        area_rules = [r for r in data['rules'] if r.get('AREA') == proc['AREA']]
        if not area_rules or (is_active and not any(active(r) for r in area_rules)):
            out.append(f'process {label}: no alert rule for area {proc["AREA"]}')
        if not proc.get('OWNER'):
            doc = os.path.join(root, 'docs', 'processes', f'{proc["AREA"]}_{proc["PROCESS_ID"]}.md')
            text = open(doc, encoding='utf-8').read() if os.path.isfile(doc) else ''
            if not OWNER_LINE.search(text):
                out.append(f'process {label}: no owner (OWNER, or "Owner team:" in docs/processes/'
                           f'{proc["AREA"]}_{proc["PROCESS_ID"]}.md)')
        target = proc.get('PURGE_TARGET', '')
        if proc.get('OWN_DATA') == YES and not target:
            out.append(f'process {label}: own tables without a purge target')
        if target and target not in targets:
            out.append(f'process {label}: purge target {target} not in purge_targets.csv')
        role = proc.get('AUTH_ROLE', '')
        if not role:
            out.append(f'process {label}: no role (AUTH_ROLE)')
        elif not re.search(r'(?<![\w])' + re.escape(role) + r'(?![\w])', auth_text):
            out.append(f'process {label}: role {role} not in the authorisation sheet ({", ".join(auth_docs)})')
        if proc['AREA'] not in areas:
            out.append(f'process {label}: area {proc["AREA"]} is not a parameter area (param_areas)')
    return out
