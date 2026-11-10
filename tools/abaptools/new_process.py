#!/usr/bin/env python3
"""Scaffold of a new business process for the process onboarding of the operations framework ZCA_OPS.

Given an area, a process and its checks (no-code aggregate rows and / or check classes), writes into a
component folder (the framework or a consumer) every configuration row the process needs end to end -
seed files with the columns of the tables, one row per table row - and its document:

  config/process_register.csv   the process (ZCA_OPS_PROC: owner blank - filled in DV1, role, purge)
  config/check_registry.csv     one row per check (ZCA_OPS_CHECK: class, schedule group, company-code aware)
  config/check_aggregates.csv   one row per aggregate (ZCA_OPS_AGG: COUNT / AGE, status condition, limits)
  config/approved_tables.csv    the tables the aggregates read (ZCA_OPS_TABWL, per area)
  config/control_register.csv   a new control (ZCA_OPS_CONTROL) - or an existing control is named
  config/control_guidance.csv   its guidance (ZCA_OPS_CTLT, language E)
  config/control_checks.csv     the checks the control covers (ZCA_OPS_CTLCHK, GROUP2 = check ID)
  config/alert_rules.csv        the alert rule of the area (ZCA_OPS_ALRULE)
  config/purge_targets.csv      the purge target of own tables (ZCA_OPS_PURGE), when the process has any
  config/param_areas.csv        the area, when it is new and the process active (ZCA_PARAM_AREA; an inactive
                                process names it in its document only)
  docs/processes/<AREA>_<PROCESS>.md   the document: owner team, role, checks, Fiori apps, job, parameters to
                                deliver, VERIFY items
  <skeleton_dir>/zcl_..._c_....clas.abap + .clas.testclasses.abap   a check class skeleton (ZIF_CA_OPS_CHECK)
                                with its test class, for every check that names a class with "skeleton"

Rows are appended once (a row whose key is already in the file is left as it is), so the scaffold can run
again after the specification grew. "active": false delivers every row inactive (placeholders allowed:
text between the angle quotes U+2039 / U+203A, e.g. "‹status table›"); the offline check
tools/abaptools/onboarding.py refuses an active row with a placeholder or a VERIFY marker.

Usage:
  python3 tools/abaptools/new_process.py --root <component> --spec <process.json> [--dry-run]
  python3 tools/abaptools/new_process.py --root <component> --area ZPE_OPS --process PAY_LIFE \\
      --name "Payment lifecycle" --role Z_PE_OPS_OPERATOR --owner-team "Payment operations" \\
      --agg "R1:COUNT:ZPE_REQUEST:STATUS:EQ:PENDING" --class "R3:ZCL_PE_C_REFUND" [--inactive] [--dry-run]

Specification (JSON): area, process, name, owner_team, auth_role, schedule_group (default DAILY), active
(default true), own_data, purge_target, purge_class, purge_param (retention parameter in area CA_OPS),
new_area {description, owner_team}, control {area, id, create, description, category, guidance},
alert_rule {id, min_severity, destination, template_id}, checks [ {id, description, bukrs_aware,
class, skeleton, skeleton_dir} | {id, description, bukrs_aware, aggregates [ {id, description, table,
func, date_field, min_age_days, bukrs_field, status_field, status_op, status_value, cond_field, cond_op,
cond_value, amber, red, check_code} ]} ], verify [text].

Modification log:
2026-11-10 | Initial version (process onboarding framework).
"""
import argparse
import csv
import io
import json
import os
import re
import sys

AGG_CLASS = 'ZCL_CA_OPS_CHK_AGG'
COLUMNS = {
    'process_register.csv': ['AREA', 'PROCESS_ID', 'DESCRIPTION', 'OWNER', 'BACKUP', 'RUNBOOK_URL', 'AUTH_ROLE',
                             'OWN_DATA', 'PURGE_TARGET', 'ACTIVE', 'SEQ'],
    'check_registry.csv': ['AREA', 'CHECK_ID', 'PROCESS_ID', 'DESCRIPTION', 'CLASS_NAME', 'SCHED_GROUP',
                           'BUKRS_AWARE', 'ACTIVE', 'SEQ'],
    'check_aggregates.csv': ['AREA', 'CHECK_ID', 'AGG_ID', 'DESCRIPTION', 'TABNAME', 'AGG_FUNC', 'DATE_FIELD',
                             'MIN_AGE_DAYS', 'BUKRS_FIELD', 'STATUS_FIELD', 'STATUS_OP', 'STATUS_VALUE',
                             'COND_FIELD', 'COND_OP', 'COND_VALUE', 'AMBER', 'RED', 'CHECK_CODE', 'ACTIVE'],
    'approved_tables.csv': ['AREA', 'TABLE_NAME', 'ACTIVE', 'APPROVED_BY', 'DESCRIPTION'],
    'control_register.csv': ['AREA', 'CONTROL_ID', 'DESCRIPTION', 'CATEGORY', 'OWNER', 'BACKUP', 'TEAM',
                             'CUTOFF_TIME', 'RUNBOOK_URL', 'ACTIVE', 'SEQ'],
    'control_guidance.csv': ['LANGU', 'AREA', 'CONTROL_ID', 'GUIDANCE'],
    'control_checks.csv': ['AREA', 'CONTROL_ID', 'CHECK_AREA', 'MATCH_FIELD', 'MATCH_VALUE'],
    'alert_rules.csv': ['RULE_ID', 'AREA', 'MIN_SEVERITY', 'RULE_PATTERN', 'CHECK_PATTERN', 'GROUP1_PATTERN',
                        'GROUP2_PATTERN', 'BUKRS_PATTERN', 'MIN_RAG', 'ON_ABORT', 'CHANNEL', 'DESTINATION', 'DIGEST',
                        'MAX_ITEMS', 'THROTTLE_MIN', 'QUIET_FROM', 'QUIET_TO', 'ESCALATE_AFTER', 'ESCALATION_DEST',
                        'ESC_OVERRIDE', 'ACTIVE', 'TEMPLATE_ID', 'SHOW_AMOUNTS'],
    'purge_targets.csv': ['TARGET', 'CLASS_NAME', 'PARAM_AREA', 'PARAM_NAME', 'ACTIVE'],
    'param_areas.csv': ['AREA', 'DESCRIPTION', 'OWNER_TEAM', 'PROD_EDITABLE', 'ACTIVE'],
}
KEYS = {
    'process_register.csv': ['AREA', 'PROCESS_ID'],
    'check_registry.csv': ['AREA', 'CHECK_ID'],
    'check_aggregates.csv': ['AREA', 'CHECK_ID', 'AGG_ID'],
    'approved_tables.csv': ['AREA', 'TABLE_NAME'],
    'control_register.csv': ['AREA', 'CONTROL_ID'],
    'control_guidance.csv': ['LANGU', 'AREA', 'CONTROL_ID'],
    'control_checks.csv': ['AREA', 'CONTROL_ID', 'CHECK_AREA', 'MATCH_FIELD', 'MATCH_VALUE'],
    'alert_rules.csv': ['RULE_ID'],
    'purge_targets.csv': ['TARGET'],
    'param_areas.csv': ['AREA'],
}
LIMITS = {'AREA': 16, 'PROCESS_ID': 20, 'CHECK_ID': 20, 'AGG_ID': 10, 'CONTROL_ID': 20, 'RULE_ID': 10,
          'SCHED_GROUP': 10, 'AUTH_ROLE': 30, 'CLASS_NAME': 30, 'PURGE_TARGET': 12, 'TARGET': 12,
          'DESCRIPTION': 60, 'TABNAME': 30, 'TABLE_NAME': 30, 'CHECK_CODE': 30}
NAME = re.compile(r'^[A-Z][A-Z0-9_]*$')
PLACEHOLDER = re.compile('‹[^›]*›')
YES = 'X'


class SpecError(ValueError):
    """The specification cannot be scaffolded (name, length, missing value)."""


def flag(value):
    return YES if value else ''


def check_value(column, value):
    """A key or name of the tables: upper case, SAP length; placeholders are allowed (inactive rows)."""
    if PLACEHOLDER.search(value):
        return
    limit = LIMITS.get(column)
    if limit and len(value) > limit:
        raise SpecError(f'{column} {value!r}: longer than {limit} characters')
    if column in ('AREA', 'PROCESS_ID', 'CHECK_ID', 'AGG_ID', 'CONTROL_ID', 'RULE_ID', 'SCHED_GROUP',
                  'CLASS_NAME', 'TARGET', 'TABLE_NAME', 'TABNAME') and value and not NAME.match(value):
        raise SpecError(f'{column} {value!r}: upper-case letters, digits and _ only')


def rows_of(spec):
    """{file: [row dict]} of every configuration row of the specification."""
    for key in ('area', 'process', 'name', 'auth_role'):
        if not spec.get(key):
            raise SpecError(f'specification: {key} is missing')
    area, process = spec['area'], spec['process']
    on = flag(spec.get('active', True))
    group = spec.get('schedule_group', 'DAILY')
    out = {name: [] for name in COLUMNS}
    if spec.get('own_data') and not spec.get('purge_target'):
        raise SpecError('own_data needs purge_target (and purge_class / purge_param for a new target)')
    out['process_register.csv'].append({
        'AREA': area, 'PROCESS_ID': process, 'DESCRIPTION': spec['name'], 'OWNER': '', 'BACKUP': '',
        'RUNBOOK_URL': spec.get('runbook_url', ''), 'AUTH_ROLE': spec['auth_role'],
        'OWN_DATA': flag(spec.get('own_data')), 'PURGE_TARGET': spec.get('purge_target', ''), 'ACTIVE': on,
        'SEQ': str(spec.get('seq', 10))})
    if not spec.get('checks'):
        raise SpecError('specification: at least one check')
    control = spec.get('control') or {}
    control_area = control.get('area', area)
    control_id = control.get('id', process)
    for seq, check in enumerate(spec['checks'], start=1):
        aggs = check.get('aggregates', [])
        if bool(aggs) == bool(check.get('class')):
            raise SpecError(f'check {check.get("id")}: either aggregates or a class')
        out['check_registry.csv'].append({
            'AREA': area, 'CHECK_ID': check['id'], 'PROCESS_ID': process,
            'DESCRIPTION': check.get('description', ''), 'CLASS_NAME': AGG_CLASS if aggs else check['class'],
            'SCHED_GROUP': check.get('schedule_group', group), 'BUKRS_AWARE': flag(check.get('bukrs_aware')),
            'ACTIVE': on, 'SEQ': str(seq * 10)})
        out['control_checks.csv'].append({'AREA': control_area, 'CONTROL_ID': control_id, 'CHECK_AREA': area,
                                          'MATCH_FIELD': 'GROUP2', 'MATCH_VALUE': check['id']})
        for agg in aggs:
            func = agg.get('func', 'COUNT').upper()
            if func not in ('COUNT', 'AGE'):
                raise SpecError(f'aggregate {agg.get("id")}: func COUNT or AGE')
            if func == 'AGE' and not agg.get('date_field'):
                raise SpecError(f'aggregate {agg.get("id")}: AGE needs date_field')
            if check.get('bukrs_aware') and not agg.get('bukrs_field'):
                raise SpecError(f'aggregate {agg.get("id")}: a company-code aware check needs bukrs_field')
            out['check_aggregates.csv'].append({
                'AREA': area, 'CHECK_ID': check['id'], 'AGG_ID': agg['id'],
                'DESCRIPTION': agg.get('description', ''), 'TABNAME': agg['table'], 'AGG_FUNC': func,
                'DATE_FIELD': agg.get('date_field', ''), 'MIN_AGE_DAYS': str(agg.get('min_age_days', 0)),
                'BUKRS_FIELD': agg.get('bukrs_field', ''), 'STATUS_FIELD': agg.get('status_field', ''),
                'STATUS_OP': agg.get('status_op', 'EQ' if agg.get('status_field') else ''),
                'STATUS_VALUE': agg.get('status_value', ''), 'COND_FIELD': agg.get('cond_field', ''),
                'COND_OP': agg.get('cond_op', ''), 'COND_VALUE': agg.get('cond_value', ''),
                'AMBER': str(agg.get('amber', 0)), 'RED': str(agg.get('red', 0)),
                'CHECK_CODE': agg.get('check_code', ''), 'ACTIVE': on})
            if not any(t['TABLE_NAME'] == agg['table'] for t in out['approved_tables.csv']):
                out['approved_tables.csv'].append({'AREA': area, 'TABLE_NAME': agg['table'], 'ACTIVE': on,
                                                   'APPROVED_BY': '',
                                                   'DESCRIPTION': agg.get('table_description', spec['name'])[:60]})
    if control.get('create', not control):
        out['control_register.csv'].append({
            'AREA': control_area, 'CONTROL_ID': control_id,
            'DESCRIPTION': control.get('description', spec['name']), 'CATEGORY': control.get('category', ''),
            'OWNER': '', 'BACKUP': '', 'TEAM': '', 'CUTOFF_TIME': control.get('cutoff_time', ''), 'RUNBOOK_URL': '',
            'ACTIVE': on, 'SEQ': str(control.get('seq', 100))})
        out['control_guidance.csv'].append({
            'LANGU': 'E', 'AREA': control_area, 'CONTROL_ID': control_id,
            'GUIDANCE': control.get('guidance', f'Review the open exceptions of {spec["name"]} and record the '
                                                f'next action.')})
    rule = spec.get('alert_rule') or {}
    out['alert_rules.csv'].append({
        'RULE_ID': rule.get('id', process[:10]), 'AREA': area, 'MIN_SEVERITY': rule.get('min_severity', 'E'),
        'RULE_PATTERN': '', 'CHECK_PATTERN': '', 'GROUP1_PATTERN': process, 'GROUP2_PATTERN': '',
        'BUKRS_PATTERN': rule.get('bukrs_pattern', ''), 'MIN_RAG': '', 'ON_ABORT': YES, 'CHANNEL': 'EMAIL',
        'DESTINATION': rule.get('destination', '‹SO23 list›'), 'DIGEST': YES, 'MAX_ITEMS': '50',
        'THROTTLE_MIN': '60', 'QUIET_FROM': '', 'QUIET_TO': '', 'ESCALATE_AFTER': '', 'ESCALATION_DEST': '',
        'ESC_OVERRIDE': '', 'ACTIVE': on, 'TEMPLATE_ID': rule.get('template_id', ''), 'SHOW_AMOUNTS': ''})
    if spec.get('own_data') and spec.get('purge_class'):
        out['purge_targets.csv'].append({
            'TARGET': spec['purge_target'], 'CLASS_NAME': spec['purge_class'], 'PARAM_AREA': 'CA_OPS',
            'PARAM_NAME': spec.get('purge_param', f'RETENTION_DAYS_{spec["purge_target"]}'), 'ACTIVE': on})
    # A new area is delivered with an active process only: a delivered inactive area would be reported
    # every day by the consumer's parameter check; the document names it for the activation
    if spec.get('new_area') and spec.get('active', True):
        out['param_areas.csv'].append({'AREA': area, 'DESCRIPTION': spec['new_area'].get('description', spec['name']),
                                       'OWNER_TEAM': spec['new_area'].get('owner_team', spec.get('owner_team', '')),
                                       'PROD_EDITABLE': YES, 'ACTIVE': on})
    for name, lines in out.items():
        for row in lines:
            for column, value in row.items():
                check_value(column, value)
    return out


def merge(path, columns, keys, new_rows):
    """The file's text with the new rows appended (rows whose key exists are kept as they are)."""
    existing = []
    header = columns
    if os.path.isfile(path):
        with open(path, encoding='utf-8', newline='') as handle:
            reader = csv.DictReader(handle)
            header = reader.fieldnames or columns
            existing = list(reader)
    seen = {tuple(r.get(k, '') for k in keys) for r in existing}
    added = [r for r in new_rows if tuple(r.get(k, '') for k in keys) not in seen]
    if not added:
        return None, 0
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=header, lineterminator='\n', extrasaction='ignore')
    writer.writeheader()
    for row in existing + added:
        writer.writerow({h: row.get(h, '') for h in header})
    return buffer.getvalue(), len(added)


def class_prefix(name):
    """zcl_pe_c_refund -> (zcl_pe_c_refund, ZCL_PE_C_REFUND)."""
    return name.lower(), name.upper()


def skeleton(spec, check):
    """Source and test include of a check class (compiles against ZIF_CA_OPS_CHECK; reads nothing yet)."""
    low, up = class_prefix(check['class'])
    date = spec.get('date', '2026-11-10')
    src = f"""*&---------------------------------------------------------------------*
*& Artifact: {low}.clas.abap
*& Purpose:
*& Check {check['id']} of process {spec['process']} (area {spec['area']}):
*& {check.get('description', '')[:66]}
*& Registered in ZCA_OPS_CHECK; run by ZCL_CA_OPS_CHECK_RUNNER, which stamps
*& GROUP1 = process and GROUP2 = check. Reads only through its own data
*& access class (one set-based read, no SELECT in a loop). Read only.
*& Modification log:
*& {date} | Initial version (scaffold tools/abaptools/new_process.py).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Check {check['id'][:40]}</p>
CLASS {low} DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

  PRIVATE SECTION.
    "! The objects of the check that break its rule (one set-based read of the data access class;
    "! add the context - today, company codes - the read needs)
    METHODS evaluate
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.

ENDCLASS.



CLASS {low} IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    rs_result-findings = evaluate( ).
    rs_result-item_count = lines( rs_result-findings ).
  ENDMETHOD.


  METHOD evaluate.
    " Read the objects through the data access class of the process; one finding per object:
    " object key, check code, severity, company code, message of the consumer's message class.
    CLEAR rt_findings.
  ENDMETHOD.

ENDCLASS.
"""
    test = f"""*&---------------------------------------------------------------------*
*& Artifact: {low}.clas.testclasses.abap
*& Purpose:
*& Tests of check {check['id']} through ZIF_CA_OPS_CHECK~RUN with a data access
*& double; does not prove live SAP runtime behavior.
*& Modification log:
*& {date} | Initial version (scaffold tools/abaptools/new_process.py).
*&---------------------------------------------------------------------*
CLASS ltc_check DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS nothing_found_no_finding FOR TESTING.
ENDCLASS.


CLASS ltc_check IMPLEMENTATION.

  " Rule: without objects that break the rule the check raises nothing (the runner resolves)
  METHOD nothing_found_no_finding.
    TRY.
        DATA(ls_result) = NEW {low}( )->zif_ca_ops_check~run( is_check   = VALUE #( )
                                                                   is_context = VALUE #( ) ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'No finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
"""
    return {f'{low}.clas.abap': src, f'{low}.clas.testclasses.abap': test}


def document(spec, out):
    """docs/processes/<AREA>_<PROCESS>.md of the process."""
    area, process = spec['area'], spec['process']
    status = 'active' if spec.get('active', True) else 'inactive - every row delivered inactive'
    control = spec.get('control') or {}
    lines = [f'# Process {process} - {spec["name"]}', '',
             '> Generated by `tools/abaptools/new_process.py` (process onboarding of the operations framework '
             'ZCA_OPS); complete it, never delete the owner line.', '',
             f'Area: `{area}` · Status: {status}', '',
             f'Owner team: {spec.get("owner_team", "")}', '',
             f'Role (PFCG, ZCA_OPS for the area): `{spec["auth_role"]}`', '',
             '## Checks', '',
             '| Check | Kind | Schedule group | Company-code aware | Covered by control |',
             '|---|---|---|---|---|']
    for row in out['check_registry.csv']:
        kind = 'aggregate (no code)' if row['CLASS_NAME'] == AGG_CLASS else f'class `{row["CLASS_NAME"]}`'
        lines.append(f'| `{row["CHECK_ID"]}` | {kind} | {row["SCHED_GROUP"]} | {row["BUKRS_AWARE"] or "-"} | '
                     f'`{control.get("area", area)}` / `{control.get("id", process)}` |')
    if out['check_aggregates.csv']:
        lines += ['', '| Aggregate | Table | Function | Status | Limits amber / red |', '|---|---|---|---|---|']
        for row in out['check_aggregates.csv']:
            lines.append(f'| `{row["CHECK_ID"]}` / `{row["AGG_ID"]}` | {row["TABNAME"]} | {row["AGG_FUNC"]} | '
                         f'{row["STATUS_FIELD"]} {row["STATUS_OP"]} {row["STATUS_VALUE"]} | '
                         f'{row["AMBER"]} / {row["RED"]} |')
    rule = out['alert_rules.csv'][0]
    lines += ['', '## End to end', '',
              '| Piece | Where |', '|---|---|',
              f'| Configuration | app `ZUI_CA_OPS_CFG`: business processes, registered checks, aggregate checks, '
              f'approved tables, controls (rows of the seed files under `config/`, DV1, customizing request) |',
              f'| Run | job `ZCA_OPS_CHECK_RUN` with `P_AREA` = `{area}`, `P_GROUP` = '
              f'`{spec.get("schedule_group", "DAILY")}`, test mode off (job user: ZCA_OPS 16 for `{area}`) |',
              f'| Findings and exceptions | app `ZUI_CA_OPS_EXC`, area `{area}`, GROUP1 = `{process}`, GROUP2 = check |',
              f'| Alerts | rule `{rule["RULE_ID"]}` (area `{area}`, GROUP1 `{process}`, severity {rule["MIN_SEVERITY"]}'
              f' or worse) to `{rule["DESTINATION"]}` |',
              f'| Daily review | control `{control.get("id", process)}` (`ZUI_CA_OPS_REV`) |',
              f'| Dashboard and freshness | app `ZUI_CA_OPS_DASH`, area `{area}`; stale after `CHECK_STALE_MIN_{area}`'
              ' (else `CHECK_STALE_MIN_DEFAULT`) minutes |',
              '| Purge | ' + (f'target `{spec["purge_target"]}` (`ZCA_OPS_PURGE`)' if spec.get('own_data')
                               else 'findings only: purged with their runs (built-in target RUN)') + ' |',
              f'| Morning completeness | `ZCL_CA_OPS_CHK_ONBOARD` reports a missing piece of this process |',
              '', '## Parameters to deliver (area CA_OPS, definitions of the consumer)', '']
    if spec.get('new_area') and not spec.get('active', True):
        lines += [f'- Area `{area}` itself (`config/param_areas.csv`: {spec["new_area"].get("description", "")}) - '
                  'added on activation, never delivered inactive (the parameter check would report it daily)']
    lines += [
              f'- `SLA_DAYS_{area}_E`, `SLA_DAYS_{area}_W` - due date of the exceptions (else `SLA_DAYS_DEFAULT`)',
              f'- `CHECK_STALE_MIN_{area}` - freshness of the dashboard (else `CHECK_STALE_MIN_DEFAULT`)']
    if spec.get('own_data'):
        lines.append(f'- `RETENTION_DAYS_{spec["purge_target"]}` - retention of the own tables')
    verify = spec.get('verify', [])
    if verify:
        lines += ['', '## VERIFY before activation', ''] + [f'- {v}' for v in verify]
    return '\n'.join(lines) + '\n'


def scaffold(root, spec, dry_run=False):
    """Write (or with dry_run only list) every file of the process; returns [(path, rows added or 'new')]."""
    out = rows_of(spec)
    changes = []
    for name, new_rows in out.items():
        if not new_rows:
            continue
        path = os.path.join(root, 'config', name)
        text, added = merge(path, COLUMNS[name], KEYS[name], new_rows)
        if text is None:
            continue
        changes.append((os.path.relpath(path, root), added))
        if not dry_run:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w', encoding='utf-8', newline='') as handle:
                handle.write(text)
    doc = os.path.join(root, 'docs', 'processes', f'{spec["area"]}_{spec["process"]}.md')
    if not os.path.isfile(doc):
        changes.append((os.path.relpath(doc, root), 'new'))
        if not dry_run:
            os.makedirs(os.path.dirname(doc), exist_ok=True)
            with open(doc, 'w', encoding='utf-8', newline='\n') as handle:
                handle.write(document(spec, out))
    for check in spec['checks']:
        if not (check.get('class') and check.get('skeleton')):
            continue
        folder = os.path.join(root, check.get('skeleton_dir', 'src'))
        for name, text in skeleton(spec, check).items():
            path = os.path.join(folder, name)
            if os.path.isfile(path):
                continue
            changes.append((os.path.relpath(path, root), 'new'))
            if not dry_run:
                os.makedirs(folder, exist_ok=True)
                with open(path, 'w', encoding='utf-8', newline='\n') as handle:
                    handle.write(text)
    return changes


def spec_from_args(args):
    spec = {'area': args.area, 'process': args.process, 'name': args.name, 'auth_role': args.role,
            'owner_team': args.owner_team or '', 'schedule_group': args.group, 'active': not args.inactive,
            'checks': []}
    for item in args.agg or []:
        parts = item.split(':')
        if len(parts) < 3:
            raise SpecError(f'--agg {item!r}: ID:FUNC:TABLE[:STATUS_FIELD:OP:VALUE]')
        agg = {'id': parts[0], 'func': parts[1], 'table': parts[2]}
        if len(parts) >= 6:
            agg.update(status_field=parts[3], status_op=parts[4], status_value=parts[5])
        spec['checks'].append({'id': parts[0], 'aggregates': [dict(agg, id=parts[0][:10])]})
    for item in args.cls or []:
        check_id, _, name = item.partition(':')
        spec['checks'].append({'id': check_id, 'class': name, 'skeleton': True})
    return spec


def main(argv=None):
    parser = argparse.ArgumentParser(description='Scaffold a new business process (process onboarding, ZCA_OPS).')
    parser.add_argument('--root', required=True, help='component folder (e.g. ops-framework or a consumer)')
    parser.add_argument('--spec', help='process specification (JSON)')
    parser.add_argument('--area')
    parser.add_argument('--process')
    parser.add_argument('--name')
    parser.add_argument('--role')
    parser.add_argument('--owner-team')
    parser.add_argument('--group', default='DAILY')
    parser.add_argument('--agg', action='append', help='ID:FUNC:TABLE[:STATUS_FIELD:OP:VALUE]')
    parser.add_argument('--class', dest='cls', action='append', help='CHECK_ID:CLASS_NAME (skeleton in src/)')
    parser.add_argument('--inactive', action='store_true')
    parser.add_argument('--dry-run', action='store_true', help='list what would be written, write nothing')
    args = parser.parse_args(argv)
    try:
        if args.spec:
            with open(args.spec, encoding='utf-8') as handle:
                spec = json.load(handle)
        else:
            spec = spec_from_args(args)
        changes = scaffold(args.root, spec, dry_run=args.dry_run)
    except (SpecError, KeyError, OSError, json.JSONDecodeError) as error:
        print(f'new_process: {error}', file=sys.stderr)
        return 2
    verb = 'would write' if args.dry_run else 'written'
    for path, what in changes:
        print(f'{path}: {verb} ({what if what == "new" else str(what) + " row(s)"})')
    if not changes:
        print('nothing to do: every row and file of the process exists')
    print('next: python3 tools/checks.py (or the consumer\'s check runner) - check process_onboarding')
    return 0


if __name__ == '__main__':
    sys.exit(main())
