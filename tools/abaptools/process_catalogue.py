#!/usr/bin/env python3
"""Process catalogue of the operations framework ZCA_OPS: the SAP standard business processes a customer may run,
in layered packages, with their activation per customer (offline engine; the runtime twin is ZCL_CA_OPS_CATALOG and
the activation views ZI_CA_OpsCatProcEff / ZI_CA_OpsProcEff).

First principle: the product knows which standard processes exist, how they run (transactions, programs, mass
activities), which standard tables they write and how to watch them; a customer only says which of them it runs
(activation, effective from a date, with reason and approver) and adds its own processes on top.

Packages (one JSON spec per package, ranked; a higher rank may depend on and switch a lower one, never the reverse):
  S  product baseline   processes of the S/4HANA core every system has (background jobs, bank statements)
  I  industry package   processes of an industry solution (SAP FI-CA / FS-CD)
  C  customer layer     the customer's own processes and its activation rows

Spec (JSON) of a package:
  package     {id, kind S|I|C, rank, prefix, mon_area, description, owner, active, auth_role}
  processes   [{id, name, component, card, owner_role, schedule, default_active, verify, seq,
               steps [{kind T|P|M|J|E, name, description, verify}],
               tables [{name, role H|I|L|S|C, link_object, description, verify}],
               depends_on [{id, kind H|S, description}],
               monitors [{check, description, bukrs_aware, schedule_group, class, aggregates [new_process rows +
                          verify]}],
               onboarded [{area, process}]          business processes of the component that monitor it (CAT_PROCESS)
               external [text]                      monitoring outside the framework's runner (documented only)
              }]
  monitoring  [{process, onboarded {area, process}}]   a customer layer: its business process monitors a process of
               a lower package (CAT_PROCESS of process_register.csv)
  external    [{process, text}]                     a customer layer: its own monitoring of a lower package's
               process outside the framework's runner (documented in the catalogue and the activation proposal)
  activation  [{process, valid_from YYYYMMDD, active, reason, approved_by}]   rows of a customer layer; approved_by
               blank in a repository (a person's user is entered in DV1; the onboarding check reports it until then)
  decisions   [{process, question, proposal}]       open questions of the activation (documented)
A name with evidence V carries "verify": "<VERIFY item>"; a field or name in angle quotes (U+2039 / U+203A) is a
placeholder. A process is evidence V when any of its names is. Monitoring rows are delivered in the package's
monitoring area (mon_area) with the scaffold of tools/abaptools/new_process.py and are always INACTIVE in a product
package (a customer switches them on after its VERIFY items and the activation); a row with a VERIFY item or a
placeholder is never active.

Validation: ids and prefixes, package ranks, step / table / dependency kinds, dependencies on known processes of the
same or a lower package without cycles, link objects of the link registry on the same table, aggregate tables listed
in the process's tables, activation rows of known processes with a reason and a YYYYMMDD date, onboarded business
processes in the component's process_register.csv with CAT_PROCESS = the process (and no CAT_PROCESS of the
register that names an unknown process).

Outputs (generate / check): seed rows of ZCA_OPS_CATPKG / _CATPRC / _CATSTP / _CATTAB / _CATDEP / _CATACT of the
component's own packages (config/catalogue/seed), the monitoring rows of its packages (config/catalogue/monitoring,
the tables of the process onboarding), the catalogue document (docs/catalogue/catalogue.md) and, for a customer
layer, the activation proposal (docs/catalogue/activation.md). --check fails on an invalid catalogue or an
out-of-date output.

Modification log:
2026-11-11 | Initial version (process catalogue with activation).
"""
import csv
import importlib.util
import io
import json
import os
import re

HERE = os.path.dirname(os.path.abspath(__file__))


def _sibling(name):
    """A private instance of a sibling engine (the engines are loaded by file, not as a package)."""
    spec = importlib.util.spec_from_file_location(f'abaptools_{name}_catalogue', os.path.join(HERE, name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


_links = _sibling('link_registry')
_scaffold = _sibling('new_process')
REPO = os.path.dirname(os.path.dirname(HERE))
# The product packages delivered with the framework (every consumer's catalogue starts with them)
PRODUCT_PACKAGES = [os.path.join(REPO, 'ops-framework', 'config', 'catalogue', 's4core.json'),
                    os.path.join(REPO, 'ops-framework', 'config', 'catalogue', 'packages', 'fica.json'),
                    os.path.join(REPO, 'ops-framework', 'config', 'catalogue', 'packages', 'fscd.json')]

PKG_KINDS = {'S': 'product baseline', 'I': 'industry package', 'C': 'customer layer'}
STEP_KINDS = {'T': 'transaction', 'P': 'program', 'M': 'mass activity type', 'J': 'background job', 'E': 'event / BAdI'}
TAB_ROLES = {'H': 'header', 'I': 'item', 'L': 'log / history', 'S': 'status', 'C': 'configuration'}
DEP_KINDS = {'H': 'hard', 'S': 'soft'}
ID = re.compile(r'^[A-Z][A-Z0-9_]{1,19}$')
PKG_ID = re.compile(r'^[A-Z][A-Z0-9_]{1,9}$')
NAME = re.compile(r'^[A-Z/][A-Z0-9_/]{0,39}$')
DATE = re.compile(r'^20[0-9]{2}(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])$')
PLACEHOLDER = re.compile('‹[^›]*›')
VERIFY = re.compile(r'^V[0-9]{2,4}( V[0-9]{2,4})*$')
TEXT_MAX = 60

# Catalogue tables: (table, CSV columns) - the DDIC fields without MANDT and the administrative fields
TABLES = [
    ('zca_ops_catpkg', ['PKG_ID', 'PKG_KIND', 'PKG_RANK', 'ID_PREFIX', 'MON_AREA', 'DESCRIPTION', 'OWNER', 'ACTIVE']),
    ('zca_ops_catprc', ['PROCESS_ID', 'PKG_ID', 'DESCRIPTION', 'COMPONENT', 'DASH_CARD', 'OWNER_ROLE', 'SCHEDULE',
                        'DFLT_ACTIVE', 'EVIDENCE', 'VERIFY_REF', 'SEQ']),
    ('zca_ops_catstp', ['PROCESS_ID', 'STEP_NO', 'STEP_KIND', 'OBJ_NAME', 'DESCRIPTION', 'EVIDENCE', 'VERIFY_REF']),
    ('zca_ops_cattab', ['PROCESS_ID', 'TABNAME', 'TAB_ROLE', 'LINK_OBJECT', 'DESCRIPTION', 'EVIDENCE', 'VERIFY_REF']),
    ('zca_ops_catdep', ['PROCESS_ID', 'PRED_ID', 'DEP_KIND', 'DESCRIPTION']),
    ('zca_ops_catact', ['PROCESS_ID', 'VALID_FROM', 'ACTIVE', 'PKG_ID', 'REASON', 'APPROVED_BY', 'APPROVED_ON']),
]
# Monitoring rows: the scaffold's files -> the table they seed
MONITORING = {'process_register.csv': 'zca_ops_proc', 'check_registry.csv': 'zca_ops_check',
              'check_aggregates.csv': 'zca_ops_agg', 'approved_tables.csv': 'zca_ops_tabwl',
              'control_register.csv': 'zca_ops_control', 'control_guidance.csv': 'zca_ops_ctlt',
              'control_checks.csv': 'zca_ops_ctlchk', 'alert_rules.csv': 'zca_ops_alrule'}


class CatalogueError(ValueError):
    """The catalogue is invalid (message lists every problem)."""


def _yes(value):
    return 'X' if value else ''


def _verify_of(item):
    return str(item.get('verify') or '')


def _evidence(item):
    return 'V' if _verify_of(item) or any(PLACEHOLDER.search(str(v)) for v in item.values() if isinstance(v, str)) \
        else 'C'


# ------------------------------------------------------------------------------------------------ load
class Catalogue:
    """Packages, processes and activation rows of one or more package specs."""

    def __init__(self):
        self.packages = {}     # id -> package dict (+ 'file')
        self.processes = {}    # id -> process dict (+ 'package')
        self.activation = []   # row dicts (+ 'package')
        self.decisions = []    # dicts (+ 'package')
        self.problems = []

    def add(self, spec, path=''):
        pkg = dict(spec.get('package') or {})
        pid = pkg.get('id', '')
        if not pid:
            self.problems.append(f'{path}: package without id')
            return
        if pid in self.packages:
            self.problems.append(f'{path}: package {pid} defined twice')
            return
        pkg['file'] = path
        self.packages[pid] = pkg
        for proc in spec.get('processes', []):
            proc = dict(proc)
            proc['package'] = pid
            if proc.get('id') in self.processes:
                self.problems.append(f'process {proc.get("id")}: defined twice')
                continue
            self.processes[proc.get('id', '')] = proc
        # a customer layer maps its business processes and its own monitoring to processes of lower packages
        for row in spec.get('monitoring', []):
            proc = self.processes.get(row.get('process'))
            if proc is None:
                self.problems.append(f'{path}: monitoring of {row.get("process")}, which is not in the catalogue')
            else:
                proc.setdefault('onboarded', []).append(dict(row['onboarded']))
        for row in spec.get('external', []):
            proc = self.processes.get(row.get('process'))
            if proc is None:
                self.problems.append(f'{path}: external monitoring of {row.get("process")}, which is not in the '
                                     f'catalogue')
            else:
                proc.setdefault('external', []).append(row['text'])
        for row in spec.get('activation', []):
            self.activation.append(dict(row, package=pid))
        for row in spec.get('decisions', []):
            self.decisions.append(dict(row, package=pid))

    def rank(self, pid):
        return (self.packages.get(pid) or {}).get('rank', 0)

    def state(self, process_id, day):
        """(active, source, row) on a day YYYYMMDD - the rule of ZCL_CA_OPS_CATALOG=>STATE."""
        proc = self.processes.get(process_id)
        if proc is None:
            return False, 'U', None
        pkg = self.packages.get(proc['package']) or {}
        if not pkg.get('active', True):
            return False, 'P', None
        rows = sorted((r for r in self.activation if r.get('process') == process_id
                       and str(r.get('valid_from', '')) <= day), key=lambda r: str(r.get('valid_from', '')))
        if rows:
            return bool(rows[-1].get('active')), 'A', rows[-1]
        return bool(proc.get('default_active')), 'D', None

    def evidence(self, proc):
        names = [proc] + proc.get('steps', []) + proc.get('tables', [])
        for mon in proc.get('monitors', []):
            names += mon.get('aggregates', [])
        return 'V' if any(_evidence(x) == 'V' for x in names) else 'C'

    def verify_refs(self, proc):
        refs = []
        names = [proc] + proc.get('steps', []) + proc.get('tables', [])
        for mon in proc.get('monitors', []):
            names += mon.get('aggregates', [])
        for item in names:
            for ref in _verify_of(item).split():
                if ref not in refs:
                    refs.append(ref)
        return refs


def load(paths):
    cat = Catalogue()
    for path in paths:
        with open(path, encoding='utf-8') as handle:
            cat.add(json.load(handle), os.path.relpath(path, REPO))
    return cat


# ------------------------------------------------------------------------------------------------ validate
def _text(value):
    return value is None or len(str(value)) <= TEXT_MAX


def validate(cat, registry=None, register=None):
    """Problems of the catalogue (empty = valid). registry: the link registry of the component (objects by id);
    register: rows of the component's process_register.csv (AREA, PROCESS_ID, CAT_PROCESS)."""
    p = list(cat.problems)
    ranks = {}
    for pid, pkg in cat.packages.items():
        if not PKG_ID.match(pid):
            p.append(f'package {pid}: id must be 2-10 upper-case letters, digits or _')
        if pkg.get('kind') not in PKG_KINDS:
            p.append(f'package {pid}: kind {pkg.get("kind")!r} is not one of {sorted(PKG_KINDS)}')
        if not isinstance(pkg.get('rank'), int) or pkg['rank'] <= 0:
            p.append(f'package {pid}: rank must be a positive number')
        elif pkg['rank'] in ranks:
            p.append(f'package {pid}: rank {pkg["rank"]} also of package {ranks[pkg["rank"]]}')
        else:
            ranks[pkg['rank']] = pid
        if not str(pkg.get('prefix', '')).endswith('_') or len(pkg.get('prefix', '')) > 10:
            p.append(f'package {pid}: prefix must end with _ and have at most 10 characters')
        if pkg.get('kind') != 'C' and not pkg.get('mon_area'):
            p.append(f'package {pid}: a product package names its monitoring area (mon_area)')
        if not _text(pkg.get('description')):
            p.append(f'package {pid}: description longer than {TEXT_MAX}')
    check_ids = {}
    for proc_id, proc in cat.processes.items():
        pkg = cat.packages[proc['package']]
        label = f'process {proc_id}'
        if not ID.match(proc_id or ''):
            p.append(f'{label}: id must be 2-20 upper-case letters, digits or _')
        if not str(proc_id).startswith(pkg.get('prefix', '?')):
            p.append(f'{label}: id must start with the prefix {pkg.get("prefix")} of package {pkg["id"]}')
        for key in ('name', 'owner_role', 'schedule'):
            if not proc.get(key):
                p.append(f'{label}: {key} is missing')
        if not _text(proc.get('name')) or not _text(proc.get('schedule')) or len(proc.get('owner_role', '')) > 40:
            p.append(f'{label}: name / schedule longer than {TEXT_MAX} or owner role longer than 40')
        if len(proc.get('card', '')) > 20 or len(proc.get('component', '')) > 10:
            p.append(f'{label}: card longer than 20 or component longer than 10')
        for ref in (_verify_of(proc).split() if _verify_of(proc) else []):
            if not VERIFY.match(ref):
                p.append(f'{label}: verify {ref!r} is not a VERIFY item (V<number>)')
        if pkg.get('kind') != 'C' and proc.get('default_active') and cat.evidence(proc) == 'V':
            p.append(f'{label}: a product process with a VERIFY item is never active by default')
        if not proc.get('steps'):
            p.append(f'{label}: no step')
        for no, step in enumerate(proc.get('steps', []), start=1):
            if step.get('kind') not in STEP_KINDS:
                p.append(f'{label} step {no}: kind {step.get("kind")!r} is not one of {sorted(STEP_KINDS)}')
            name = step.get('name', '')
            if not PLACEHOLDER.search(name) and not NAME.match(name):
                p.append(f'{label} step {no}: name {name!r} is not an SAP object name')
            if PLACEHOLDER.search(name) and not _verify_of(step):
                p.append(f'{label} step {no}: a placeholder needs its VERIFY item')
            if not _text(step.get('description')):
                p.append(f'{label} step {no}: description longer than {TEXT_MAX}')
        tables = {}
        for tab in proc.get('tables', []):
            name = tab.get('name', '')
            tables[name] = tab
            if tab.get('role') not in TAB_ROLES:
                p.append(f'{label} table {name}: role {tab.get("role")!r} is not one of {sorted(TAB_ROLES)}')
            if not PLACEHOLDER.search(name) and not NAME.match(name):
                p.append(f'{label} table {name!r}: not a table name')
            if PLACEHOLDER.search(name) and not _verify_of(tab):
                p.append(f'{label} table {name}: a placeholder needs its VERIFY item')
            obj = tab.get('link_object')
            if obj and registry is not None:
                target = registry.objects.get(obj)
                if target is None:
                    p.append(f'{label} table {name}: link object {obj} is not in the link registry')
                elif target['source'].upper() != name.upper():
                    p.append(f'{label} table {name}: link object {obj} reads {target["source"]}')
            if not _text(tab.get('description')):
                p.append(f'{label} table {name}: description longer than {TEXT_MAX}')
        for dep in proc.get('depends_on', []):
            pred = cat.processes.get(dep.get('id'))
            if pred is None:
                p.append(f'{label}: depends on {dep.get("id")}, which is not in the catalogue')
            elif cat.rank(pred['package']) > cat.rank(proc['package']):
                p.append(f'{label}: depends on {dep["id"]} of the higher package {pred["package"]}')
            if dep.get('kind') not in DEP_KINDS:
                p.append(f'{label}: dependency {dep.get("id")} kind {dep.get("kind")!r} is not H or S')
        if pkg.get('kind') != 'C' and not proc.get('monitors'):
            p.append(f'{label}: a product process delivers at least one monitoring check')
        for mon in proc.get('monitors', []):
            cid = mon.get('check', '')
            if cid in check_ids:
                p.append(f'{label}: check {cid} also of process {check_ids[cid]}')
            check_ids[cid] = proc_id
            if not ID.match(cid):
                p.append(f'{label}: check id {cid!r} must be 2-20 upper-case letters, digits or _')
            for agg in mon.get('aggregates', []):
                tab = agg.get('table', '')
                if tab not in tables:
                    p.append(f'{label} check {cid} aggregate {agg.get("id")}: table {tab} is not a table of the process')
                if (PLACEHOLDER.search(json.dumps(agg, ensure_ascii=False)) and not _verify_of(agg)
                        and not _verify_of(tables.get(tab, {}))):
                    p.append(f'{label} check {cid} aggregate {agg.get("id")}: a placeholder needs its VERIFY item')
        for onb in proc.get('onboarded', []):
            if register is None:
                continue
            row = next((r for r in register if r.get('AREA') == onb.get('area')
                        and r.get('PROCESS_ID') == onb.get('process')), None)
            if row is None:
                p.append(f'{label}: onboarded {onb.get("area")}/{onb.get("process")} is not in process_register.csv')
            elif row.get('CAT_PROCESS') != proc_id:
                p.append(f'{label}: onboarded {onb.get("area")}/{onb.get("process")} names catalogue process '
                         f'{row.get("CAT_PROCESS")!r} (CAT_PROCESS)')
    p += _cycles(cat)
    for row in cat.activation:
        pkg = cat.packages[row['package']]
        label = f'activation {row.get("process")} {row.get("valid_from")}'
        if pkg.get('kind') != 'C':
            p.append(f'{label}: activation rows belong to a customer layer')
        if row.get('process') not in cat.processes:
            p.append(f'{label}: process is not in the catalogue')
        if not DATE.match(str(row.get('valid_from', ''))):
            p.append(f'{label}: valid_from must be a date YYYYMMDD')
        if not row.get('reason') or len(row.get('reason', '')) > 80:
            p.append(f'{label}: reason required (at most 80 characters)')
        if row.get('approved_by'):
            p.append(f'{label}: approved_by names a person - leave it blank, the approver is entered in DV1')
    if register is not None:
        for row in register:
            ref = row.get('CAT_PROCESS', '')
            if ref and ref not in cat.processes:
                p.append(f'process_register.csv {row.get("AREA")}/{row.get("PROCESS_ID")}: CAT_PROCESS {ref} '
                         f'is not in the catalogue')
    return p


def _cycles(cat):
    out = []
    for start in sorted(cat.processes):
        seen, todo = set(), [start]
        while todo:
            cur = todo.pop()
            for dep in cat.processes.get(cur, {}).get('depends_on', []):
                if dep.get('id') == start:
                    out.append(f'process {start}: dependency cycle')
                    todo = []
                    break
                if dep.get('id') not in seen:
                    seen.add(dep.get('id'))
                    todo.append(dep.get('id'))
    return out


# ------------------------------------------------------------------------------------------------ outputs
def _csv(columns, rows):
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=columns, lineterminator='\n')
    writer.writeheader()
    for row in rows:
        writer.writerow({c: row.get(c, '') for c in columns})
    return buffer.getvalue()


def seed_rows(cat, own):
    """{table: [rows]} of the catalogue tables for the packages in own."""
    out = {t: [] for t, _ in TABLES}
    for pid in own:
        pkg = cat.packages[pid]
        out['zca_ops_catpkg'].append({'PKG_ID': pid, 'PKG_KIND': pkg['kind'], 'PKG_RANK': str(pkg['rank']),
                                      'ID_PREFIX': pkg['prefix'], 'MON_AREA': pkg.get('mon_area', ''),
                                      'DESCRIPTION': pkg.get('description', ''), 'OWNER': pkg.get('owner', ''),
                                      'ACTIVE': _yes(pkg.get('active', True))})
    for proc_id in sorted(cat.processes):
        proc = cat.processes[proc_id]
        if proc['package'] not in own:
            continue
        refs = cat.verify_refs(proc)
        out['zca_ops_catprc'].append({
            'PROCESS_ID': proc_id, 'PKG_ID': proc['package'], 'DESCRIPTION': proc['name'],
            'COMPONENT': proc.get('component', ''), 'DASH_CARD': proc.get('card', ''),
            'OWNER_ROLE': proc['owner_role'], 'SCHEDULE': proc['schedule'],
            'DFLT_ACTIVE': _yes(proc.get('default_active')), 'EVIDENCE': cat.evidence(proc),
            'VERIFY_REF': ' '.join(refs)[:20], 'SEQ': str(proc.get('seq', 0))})
        for no, step in enumerate(proc.get('steps', []), start=1):
            out['zca_ops_catstp'].append({
                'PROCESS_ID': proc_id, 'STEP_NO': f'{no * 10:03d}', 'STEP_KIND': step['kind'],
                'OBJ_NAME': step['name'], 'DESCRIPTION': step.get('description', ''), 'EVIDENCE': _evidence(step),
                'VERIFY_REF': _verify_of(step)})
        for tab in proc.get('tables', []):
            out['zca_ops_cattab'].append({
                'PROCESS_ID': proc_id, 'TABNAME': tab['name'], 'TAB_ROLE': tab['role'],
                'LINK_OBJECT': tab.get('link_object', ''), 'DESCRIPTION': tab.get('description', ''),
                'EVIDENCE': _evidence(tab), 'VERIFY_REF': _verify_of(tab)})
        for dep in proc.get('depends_on', []):
            out['zca_ops_catdep'].append({'PROCESS_ID': proc_id, 'PRED_ID': dep['id'], 'DEP_KIND': dep['kind'],
                                          'DESCRIPTION': dep.get('description', '')})
    for row in cat.activation:
        if row['package'] in own:
            out['zca_ops_catact'].append({'PROCESS_ID': row['process'], 'VALID_FROM': str(row['valid_from']),
                                          'ACTIVE': _yes(row.get('active')), 'PKG_ID': row['package'],
                                          'REASON': row['reason'], 'APPROVED_BY': '', 'APPROVED_ON': ''})
    for table, rows in out.items():
        keys = {'zca_ops_catpkg': ['PKG_ID'], 'zca_ops_catprc': ['PROCESS_ID'],
                'zca_ops_catstp': ['PROCESS_ID', 'STEP_NO'], 'zca_ops_cattab': ['PROCESS_ID', 'TABNAME'],
                'zca_ops_catdep': ['PROCESS_ID', 'PRED_ID'], 'zca_ops_catact': ['PROCESS_ID', 'VALID_FROM']}[table]
        rows.sort(key=lambda r: [r[k] for k in keys])
    return out


def monitoring_rows(cat, own):
    """{monitoring table: [rows]} - the scaffold rows of every monitored process of a product package in own,
    all inactive (a customer switches them on after its VERIFY items and the activation)."""
    out = {t: [] for t in MONITORING.values()}
    for proc_id in sorted(cat.processes):
        proc = cat.processes[proc_id]
        pkg = cat.packages[proc['package']]
        if proc['package'] not in own or pkg.get('kind') == 'C' or not proc.get('monitors'):
            continue
        spec = {'area': pkg['mon_area'], 'process': proc_id, 'name': proc['name'][:60],
                'auth_role': pkg.get('auth_role', ''), 'active': False, 'cat_process': proc_id,
                'seq': proc.get('seq', 10),
                'control': {'id': proc_id, 'create': True, 'category': proc.get('card', ''),
                            'description': proc['name'][:60],
                            'guidance': f'Review the open exceptions of {proc["name"]} and record the next action.'},
                'alert_rule': {'id': proc.get('alert_rule', proc_id.replace('_', '')[:10]),
                               'destination': '‹SO23 list›'},
                'checks': []}
        for mon in proc['monitors']:
            check = {'id': mon['check'], 'description': mon.get('description', '')[:60],
                     'bukrs_aware': mon.get('bukrs_aware', False),
                     'schedule_group': mon.get('schedule_group', 'DAILY')}
            if mon.get('class'):
                check['class'] = mon['class']
            if mon.get('aggregates'):
                check['aggregates'] = [{k: v for k, v in agg.items() if k != 'verify'} for agg in mon['aggregates']]
            spec['checks'].append(check)
        for name, rows in _scaffold.rows_of(spec).items():
            if name in MONITORING:
                out[MONITORING[name]].extend(rows)
    return out


def _md_cell(value):
    return str(value or '').replace('|', '/').replace('\n', ' ')


def _ordered(cat, pid):
    """Process IDs of a package in the order of their SEQ."""
    return sorted((x for x in cat.processes if cat.processes[x]['package'] == pid),
                  key=lambda x: (cat.processes[x].get('seq', 0), x))


def document(cat, title, shown, day):
    """Markdown: the processes of the packages in shown - state on the day, steps, tables, dependencies,
    monitoring checks and VERIFY items."""
    lines = [f'# {title}', '', '> Generated by `tools/process_catalogue.py` from the package specs - never edit, '
             'regenerate.', '',
             f'State as of {day[:4]}-{day[4:6]}-{day[6:]} (the activation rule of `ZCL_CA_OPS_CATALOG`: package off '
             '-> inactive; else the activation row with the latest effective-from date on or before the day; else '
             'the delivered default). Evidence C = every name confirmed, V = a name is still a VERIFY item (its '
             'monitoring rows stay inactive).', '']
    lines += ['| Package | Kind | Rank | Prefix | Monitoring area | Processes | Active | VERIFY (evidence V) |',
              '|---|---|---|---|---|---|---|---|']
    for pid in sorted(shown, key=cat.rank):
        pkg = cat.packages[pid]
        procs = [x for x in cat.processes.values() if x['package'] == pid]
        active = sum(1 for x in procs if cat.state(x['id'], day)[0])
        verify = sum(1 for x in procs if cat.evidence(x) == 'V')
        lines.append(f'| {pid} | {PKG_KINDS[pkg["kind"]]} | {pkg["rank"]} | `{pkg["prefix"]}` | '
                     f'{pkg.get("mon_area") or "-"} | {len(procs)} | {active} | {verify} |')
    lines += ['', '## Processes', '',
              '| Process | Name | Component | Card | Active | Decided by | Evidence | Monitoring checks |',
              '|---|---|---|---|---|---|---|---|']
    source_text = {'A': 'activation row', 'D': 'default', 'P': 'package off', 'U': 'unknown'}
    for pid in sorted(shown, key=cat.rank):
        for proc_id in _ordered(cat, pid):
            proc = cat.processes[proc_id]
            on, source, _ = cat.state(proc_id, day)
            checks = ', '.join(m['check'] for m in proc.get('monitors', [])) or '-'
            lines.append(f'| {proc_id} | {_md_cell(proc["name"])} | {proc.get("component", "")} | '
                         f'{proc.get("card", "")} | {"yes" if on else "no"} | {source_text[source]} | '
                         f'{cat.evidence(proc)} {" ".join(cat.verify_refs(proc))} | {checks} |')
    for pid in sorted(shown, key=cat.rank):
        for proc_id in _ordered(cat, pid):
            proc = cat.processes[proc_id]
            lines += ['', f'### {proc_id} - {proc["name"]}', '',
                      f'Package {pid} · component {proc.get("component", "-")} · dashboard card '
                      f'{proc.get("card", "-")} · business owner role: {proc["owner_role"]} · typical schedule: '
                      f'{proc["schedule"]}', '']
            if proc.get('description'):
                lines += [proc['description'], '']
            lines += ['| Step | Kind | SAP object | What it does | Evidence |', '|---|---|---|---|---|']
            for no, step in enumerate(proc.get('steps', []), start=1):
                lines.append(f'| {no * 10:03d} | {STEP_KINDS[step["kind"]]} | `{step["name"]}` | '
                             f'{_md_cell(step.get("description"))} | {_evidence(step)} {_verify_of(step)} |')
            if proc.get('tables'):
                lines += ['', '| Table | Role | Link registry object | Meaning | Evidence |', '|---|---|---|---|---|']
                for tab in proc['tables']:
                    lines.append(f'| `{tab["name"]}` | {TAB_ROLES[tab["role"]]} | {tab.get("link_object") or "-"} | '
                                 f'{_md_cell(tab.get("description"))} | {_evidence(tab)} {_verify_of(tab)} |')
            if proc.get('depends_on'):
                lines += ['', 'Depends on: ' + '; '.join(
                    f'{d["id"]} ({DEP_KINDS[d["kind"]]}: {d.get("description", "")})' for d in proc['depends_on'])]
            if proc.get('monitors'):
                lines += ['', '| Monitoring check | What it watches | Class / aggregate rows | Evidence |',
                          '|---|---|---|---|']
                for mon in proc['monitors']:
                    rows = '; '.join(_agg_text(a) for a in mon.get('aggregates', []))
                    how = (f'`{mon["class"]}`' + (f' with {rows}' if rows else '')) if mon.get('class') else rows
                    ev = 'V ' + ' '.join(sorted({_verify_of(a) for a in mon.get('aggregates', []) if _verify_of(a)})) \
                        if any(_evidence(a) == 'V' for a in mon.get('aggregates', [])) else 'C'
                    lines.append(f'| {mon["check"]} | {_md_cell(mon.get("description"))} | {_md_cell(how)} | {ev} |')
            for onb in proc.get('onboarded', []):
                lines += ['', f'Monitored by the business process {onb["area"]}/{onb["process"]} (CAT_PROCESS).']
            for ext in proc.get('external', []):
                lines += ['', f'Monitored outside the runner: {ext}']
    return '\n'.join(lines) + '\n'


def _agg_text(agg):
    parts = [f'{agg["id"]}: {agg.get("func", "COUNT")} `{agg["table"]}`']
    if agg.get('date_field'):
        window = []
        if agg.get('min_age_days'):
            window.append(f'>= {agg["min_age_days"]} d')
        if agg.get('max_age_days'):
            window.append(f'<= {agg["max_age_days"]} d')
        parts.append(f'date {agg["date_field"]}' + (f' {agg["time_field"]}' if agg.get('time_field') else '')
                     + (f' ({", ".join(window)})' if window else ''))
    if agg.get('status_field'):
        parts.append(f'{agg["status_field"]} {agg.get("status_op", "EQ")} {agg.get("status_value", "")}')
    if agg.get('cond_field'):
        parts.append(f'{agg["cond_field"]} {agg.get("cond_op", "")} {agg.get("cond_value", "")}')
    if agg.get('bukrs_field'):
        parts.append(f'per {agg["bukrs_field"]}')
    parts.append(f'amber {agg.get("amber", 0)} / red {agg.get("red", 0)}')
    return ', '.join(parts)


def activation_document(cat, title, own, day):
    """Markdown of a customer layer: the activation proposal (every process of the catalogue, active or not, why)
    and the decision list."""
    lines = [f'# {title}', '', '> Generated by `tools/process_catalogue.py` from the customer layer - never edit, '
             'regenerate.', '',
             f'State as of {day[:4]}-{day[4:6]}-{day[6:]}. An activation row is a proposal until a business '
             'approver is entered in DV1 (APPROVED_BY, four-eyes); until then the onboarding check reports it '
             '(message 253).', '',
             '| Process | Package | Name | Proposal | From | Reason | Monitored by |', '|---|---|---|---|---|---|---|']
    for proc_id in sorted(cat.processes, key=lambda x: (cat.rank(cat.processes[x]['package']),
                                                        cat.processes[x].get('seq', 0), x)):
        proc = cat.processes[proc_id]
        on, source, row = cat.state(proc_id, day)
        own_rows = [r for r in cat.activation if r['process'] == proc_id and r['package'] in own]
        last = own_rows[-1] if own_rows else None
        if last:
            reason = last['reason']
        elif source == 'P':
            reason = 'package switched off'
        elif on:
            reason = 'active by default of its package (no activation row)'
        else:
            reason = 'to confirm with business (no activation row: inactive by default)'
        monitors = [f'{o["area"]}/{o["process"]}' for o in proc.get('onboarded', [])] + proc.get('external', [])
        lines.append(f'| {proc_id} | {proc["package"]} | {_md_cell(proc["name"])} | '
                     f'{"**ACTIVE**" if on else "inactive"} | {last["valid_from"] if last else "-"} | '
                     f'{_md_cell(reason)} | {_md_cell("; ".join(monitors)) or "-"} |')
    decisions = [d for d in cat.decisions if d['package'] in own]
    if decisions:
        lines += ['', '## Decisions for the business', '', '| # | Process | Question | Proposal |', '|---|---|---|---|']
        for no, dec in enumerate(decisions, start=1):
            lines.append(f'| {no} | {dec["process"]} | {_md_cell(dec["question"])} | {_md_cell(dec["proposal"])} |')
    return '\n'.join(lines) + '\n'


# ------------------------------------------------------------------------------------------------ profile runner
def _register(root, profile):
    path = os.path.join(root, profile['register']) if profile.get('register') else None
    if not path or not os.path.isfile(path):
        return None if not path else []
    with open(path, encoding='utf-8', newline='') as handle:
        return [{k.strip().upper(): (v or '').strip() for k, v in row.items() if k} for row in csv.DictReader(handle)]


def outputs(root, profile):
    """(catalogue, problems, {relative path: text}) of a component profile: base [package specs loaded first, not
    seeded], own [package specs, seeded], examples [validated with base + own, neither seeded nor documented],
    links (link registry profile: base / own layer specs), register (process_register.csv), seed_folder,
    monitoring_folder, docs_folder, title, day (YYYYMMDD of the documented state)."""
    base = [p if os.path.isabs(p) else os.path.join(root, p) for p in profile.get('base', [])]
    own = [os.path.join(root, p) for p in profile['own']]
    cat = load(base + own)
    links = profile.get('links') or {}
    registry = _links.load([p if os.path.isabs(p) else os.path.join(root, p)
                            for p in links.get('base', []) + links.get('own', [])]) if links else None
    register = _register(root, profile)
    problems = validate(cat, registry, register)
    for example in profile.get('examples', []):
        sample = load(base + own + [os.path.join(root, example)])
        problems += [f'{example}: {x}' for x in validate(sample, registry) if x not in problems]
    own_ids = [pid for pid, pkg in cat.packages.items()
               if os.path.normpath(os.path.join(REPO, pkg['file'])) in [os.path.normpath(p) for p in own]]
    files = {}
    if problems:
        return cat, problems, files
    for table, columns in TABLES:
        rows = seed_rows(cat, own_ids)[table]
        files[os.path.join(profile['seed_folder'], f'{table}.csv')] = _csv(columns, rows)
    if profile.get('monitoring_folder'):
        mon = monitoring_rows(cat, own_ids)
        for name, table in MONITORING.items():
            files[os.path.join(profile['monitoring_folder'], f'{table}.csv')] = _csv(_scaffold.COLUMNS[name],
                                                                                    mon[table])
    day = profile['day']
    shown = list(cat.packages) if profile.get('show_all') else own_ids
    files[os.path.join(profile['docs_folder'], 'catalogue.md')] = document(cat, f'{profile["title"]} - catalogue',
                                                                           shown, day)
    if any(cat.packages[p]['kind'] == 'C' for p in own_ids):
        files[os.path.join(profile['docs_folder'], 'activation.md')] = activation_document(
            cat, f'{profile["title"]} - activation proposal', own_ids, day)
    return cat, problems, files


def _read(path):
    if not os.path.exists(path):
        return None
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def check(root, profile):
    """Problems of the catalogue plus out-of-date outputs (empty = valid and up to date)."""
    _, problems, files = outputs(root, profile)
    stale = [f'{rel}: out of date (run tools/process_catalogue.py)' for rel, text in sorted(files.items())
             if _read(os.path.join(root, rel)) != text]
    return problems + stale


def generate(root, profile):
    _, problems, files = outputs(root, profile)
    if problems:
        raise CatalogueError('\n'.join(problems))
    written = []
    for rel, text in sorted(files.items()):
        path = os.path.join(root, rel)
        if _read(path) != text:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, 'w', encoding='utf-8') as handle:
                handle.write(text)
            written.append(rel)
    return written


def main(root, profile, argv):
    if '--check' in argv:
        failures = check(root, profile)
        if failures:
            print('Process catalogue invalid or out of date:')
            for line in failures:
                print('  ' + line)
            return 1
        print('process catalogue valid and up to date')
        return 0
    try:
        written = generate(root, profile)
    except CatalogueError as error:
        print(error)
        return 1
    print(f'{len(written)} file(s) written')
    return 0
