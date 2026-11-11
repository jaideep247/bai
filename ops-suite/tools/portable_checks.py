#!/usr/bin/env python3
"""Portable consistency checks for the ops suite (no SAP system needed).

Evidence of house-rule compliance only - NOT SAP activation, ATC or ABAP Unit
results (usage checks: tools/usage_checks.py). Writes docs/portable_checks.json, docs/Coverage_Run_Register.csv (one row per class:
own test include / covered by / exempt, from tools/test_path_register.csv) and
docs/Changed_Artifacts.csv.  Usage:  python3 tools/portable_checks.py [abaplint-binary]

The checks the suite shares with both frameworks (artefact header, SELECT *, FINAL, test class
risk / duration, name lengths, method names, PCRE only, no CP / NP) are the shared ones
(../../tools/abaptools/checks.py and name_checks.py); the list and the suite's own checks are here.

Modification log:
2026-11-10 | Common checks from the shared tools (tools/abaptools); the suite's list unchanged.
2026-11-10 | process_onboarding (process onboarding of the operations framework: registered processes complete).
2026-11-11 | link_registry (customer overlay of the link registry valid with the product layers, outputs up to date).
2026-11-11 | process_catalogue (customer layer of the process catalogue valid with the product packages, outputs current).
"""
import csv, json, os, re, subprocess, sys, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
from abaptools import checks as shared  # noqa: E402
# COMMIT WORK is the operations framework's (store, e-mail channel): none in the suite (2026-11-10)
COMMIT_ALLOWED = set()

def abap_files():
    for d, _, files in os.walk(SRC):
        for f in sorted(files):
            if f.endswith('.abap'):
                yield os.path.join(d, f)

def obj_name(f):
    return os.path.basename(f).split('.')[0]

def strip_comments(text):
    out = []
    for line in text.splitlines():
        if line.lstrip().startswith('*') or line.lstrip().startswith('"'):
            continue
        out.append(re.sub(r'"[^\n]*$', '', line) if '"' in line and "'" not in line and '`' not in line else line)
    return '\n'.join(out)

checks, register = [], {}
def check(name, failures, detail):
    checks.append({'name': name, 'passed': not failures, 'detail': detail,
                   'failures': failures[:50]})

files = list(abap_files())
names, short, fae, bukrs, tnames, commits, writes = ([] for _ in range(7))
for f in files:
    rel = os.path.relpath(f, ROOT)
    text = open(f, encoding='utf-8').read()
    code = strip_comments(text)
    base = os.path.basename(f)
    if len(obj_name(f)) > 30:
        names.append(rel)
    for m in re.finditer(r'shorttext synchronized">([^<]*)<', text):
        if len(m.group(1)) > 60:
            short.append(f'{rel}: {m.group(1)}')
    for m in re.finditer(r'METHOD\s+([\w~]+)\.(.*?)ENDMETHOD\.', code, re.S | re.I):
        body = m.group(2)
        if re.search(r'FOR\s+ALL\s+ENTRIES', body, re.I) and not re.search(r'IS\s+(NOT\s+)?INITIAL|CHECK\s+\w', body, re.I):
            fae.append(f'{rel}: {m.group(1)}')
    # the generated parameter seed holds parameter values (e.g. PURGE_PACKAGE_SIZE 1000), not company codes
    if re.search(r"'1000'", code) and 'testclasses' not in base and base != 'zcl_cd_ops_param_seed.clas.abap':
        bukrs.append(rel)
    tests = re.findall(r'METHODS\s+(\w+)\s+FOR\s+TESTING', code, re.I)
    for t in tests:
        if len(t) > 30:
            tnames.append(f'{rel}: {t}')
    if tests:
        owner = obj_name(f).upper()
        register[owner] = register.get(owner, 0) + len(tests)
    if re.search(r'\bCOMMIT\s+WORK\b', code, re.I) and base not in COMMIT_ALLOWED:
        commits.append(rel)
    if base.endswith('.prog.abap') and re.search(r'^\s*WRITE\b', code, re.I | re.M):
        writes.append(rel)

check('artifact_header_present', shared.check_artifact_header(ROOT), 'Every ABAP source starts with the Artifact/Purpose/Modification log header.')
check('object_names_max_30', names, 'Every object name is 30 characters or fewer.')
check('short_text_max_60', short, 'Every SE24 short text (ABAP Doc shorttext) is 60 characters or fewer.')
check('no_select_star', shared.check_no_select_star(ROOT), 'No SELECT * (explicit field lists only).')
check('fae_guarded', fae, 'Every method with FOR ALL ENTRIES checks the driver table for INITIAL first.')
check('no_hardcoded_company_code', bukrs, "No hard-coded company code '1000' in production code.")
check('concrete_classes_final', shared.check_final(ROOT), 'Every concrete public class is FINAL.')
check('tests_harmless_short', shared.check_test_classes(ROOT), 'Every test class is RISK LEVEL HARMLESS DURATION SHORT.')
check('test_method_names_max_30', tnames, 'Every test method name is 30 characters or fewer.')
check('commit_only_in_sanctioned_objects', commits, 'COMMIT WORK only in the store (LUW owner) and the e-mail channel (BCS).')
check('no_write_lists', writes, 'Programs use ALV / HTML output, never WRITE lists.')

# Phase 5: no hardcoding - user-facing texts are ZCD_OPS messages / text symbols, values are
# named constants, parameters or customizing (tools/literal_scan.py, allow-list with reasons)
sys.path.insert(0, os.path.join(ROOT, 'tools'))
import literal_scan  # noqa: E402
_lits = literal_scan.scan()
inline = [f'{r[0]}:{r[1]} {r[5][:40]}' for r in _lits if r[2] in (1, 2)]
check('no_inline_texts', inline,
      f'No user-facing text or technical value as a literal outside declarations ({len(_lits)} literals scanned; '
      f'allow-list tools/literal_allowlist.txt).')

# Every message number held in a gc_msg constant exists in class ZCD_OPS and is used once
_md = open(os.path.join(ROOT, 'config', 'zcd_ops_messages.md'), encoding='utf-8').read()
_numbers = set(re.findall(r'^\| (\d{3}) \|', _md, re.M))
_msg_fail, _seen = [], {}
for _p in files:
    if not re.search(r'zif_cd_\w*types\.intf\.abap$', _p):
        continue
    _m = re.search(r'BEGIN OF gc_msg,(.*?)END OF gc_msg\.', open(_p, encoding='utf-8').read(), re.S)
    for _name, _no in re.findall(r"(\w+)\s+TYPE\s+\S+\s+VALUE\s+'(\d{3})'", _m.group(1) if _m else ''):
        if _no not in _numbers:
            _msg_fail.append(f'{os.path.relpath(_p, ROOT)}: {_name} -> {_no} not in ZCD_OPS')
        _seen[f'{_p}:{_name}'] = _no
check('message_constants_exist', _msg_fail,
      f'{len(_seen)} message-number constants point to existing ZCD_OPS messages (a shared message may be named by several apps).')

# SAP length limits and the house method naming rule (tools/name_checks.py)
import name_checks  # noqa: E402
check('name_lengths', name_checks.name_length_failures(ROOT),
      'Objects, CDS entities, DDLS / SRVD / DCLS names, methods, attributes, types, local classes and '
      'local data 30 characters at most; transparent tables 16; message class 20; table fields 30.')
check('method_names', name_checks.method_name_failures(ROOT),
      'Methods are snake_case, never start with a data prefix (lv_, it_, mo_, gc_, ...) and have '
      '30 characters at most (test methods included).')

# Test paths (tools/test_checks.py): every class reached by a test or exempt with a reason,
# OSQL doubles complete, no real DAO in the tests of a class without SQL
import test_checks  # noqa: E402
check('test_path_every_class', test_checks.test_path_failures(ROOT),
      'Every class has its own test include, or a row in tools/test_path_register.csv naming the covering '
      'test include (which mentions the class) or an exemption with its reason.')
check('osql_doubles_complete', test_checks.osql_double_failures(ROOT),
      'A test include of a class with Open SQL uses cl_osql_test_environment / cl_cds_test_environment and '
      'doubles every table the tested methods (and their helpers) read or write; injected test seams and '
      'osql-not-reached markers excluded (static, best effort - dynamic table names are not resolved).')
check('no_real_dao_in_tests', test_checks.real_dao_failures(ROOT),
      'A test include of a class without SQL injects doubles when the class gets a DAO / the store from a '
      'factory, and never creates a real DAO / store.')

check('pcre_only', name_checks.posix_regex_failures(ROOT),
      'Regular expressions use PCRE only (pcre = / PCRE); POSIX (regex =, FIND / REPLACE ... REGEX, '
      'CL_ABAP_REGEX POSIX) is obsolete since ABAP 7.55.')
check('no_cp_patterns', name_checks.cp_pattern_failures(ROOT),
      'Patterns are PCRE matched to the complete value (ZCL_CD_OPS_UTIL=>PCRE_MATCH): no CP / NP '
      "comparison and no option = 'CP' / 'NP' range row in code (comments and literal contents ignored).")

# Authorisation object ZCA_OPS (framework, replaced ZCD_OPS 2026-11-10): only the fields SU20 / SU21 define
import auth_checks  # noqa: E402
check('auth_fields_defined', auth_checks.failures(ROOT),
      'Every AUTHORITY-CHECK on ZCA_OPS (zif_ca_ops_auth=>gc_object) and every pfcg_auth( ZCA_OPS, ... ) '
      'in a DCL (src/, cds/ and ../ops-framework/src) names only the fields ops-framework/docs/auth_zca_ops.md '
      'defines (section 1 fields, section 2 object field list); the retired ZCD_OPS / ZCD_PE_AREA appear nowhere.')

# Nothing declared that nothing uses (tools/usage_checks.py)
import usage_checks  # noqa: E402
check('messages_used', usage_checks.message_failures(ROOT),
      'Every ZCD_OPS message (config/zcd_ops_messages.md) is raised by production code: a message-number '
      'constant that production code reads, MESSAGE eNNN(zcd_ops) or NUMBER = literal.')
check('params_used', usage_checks.param_failures(ROOT),
      'Every parameter-name constant (gc_param, gc_param_prefix of a types interface) is read by production code.')
check('constants_used', usage_checks.constant_failures(ROOT),
      'Every types-interface constant is referenced by code, a test or CDS (documentation does not count); '
      'message numbers, check codes, parameter names and defaults one by one, other structures as value domains.')

# Parameters in ZCA_PARAM: seed files, generated seed class and code agree (tools/param_definitions.py)
import param_definitions  # noqa: E402
_counts = param_definitions.counts(ROOT)
check('param_definitions_complete', param_definitions.failures(ROOT),
      f'{sum(sum(c.values()) for c in _counts.values())} delivered definitions in {len(_counts)} areas '
      '(config/param_definitions.csv): every parameter name the code reads (gc_param constants, standalone '
      'gc_param_* constants, every enumerated run-time name) is defined and every definition is read, the area '
      'is the one ZCL_CA_OPS_PARAMS derives from the prefix, the default equals the default the code '
      'delivers, flags are BOOL, no read is compared with an off token, ZCL_CD_OPS_PARAM_SEED is generated '
      'from the seed files.')

# Facts CDS holds as literals agree with their single ABAP source (tools/cds_abap_parity.py)
import cds_abap_parity  # noqa: E402
check('cds_abap_parity', cds_abap_parity.failures(ROOT),
      f'{len(cds_abap_parity.PAIRS)} CDS literal(s) / ABAP constant pairs agree (XBLNR rule, dashboard date '
      'windows, credit indicator, reversal reason, completed run statuses, stale thresholds).')

# Process onboarding (2026-11-10): every registered business process of config/ is integrated end to end
from abaptools import onboarding  # noqa: E402
check('process_onboarding',
      onboarding.failures(ROOT, auth_docs=('config/auth_zcd_ops.md',),
                          source_roots=('src', os.path.join('..', 'ops-framework', 'src')),
                          extra_roots=(os.path.join(ROOT, '..', 'ops-framework'),)),
      'Every registered business process (config/process_register.csv) has checks, a control covering each '
      'check (GROUP2), an alert rule of its area, an owner (or an owner team in its document), purge coverage '
      'and a role of config/auth_zcd_ops.md; no active row carries a placeholder or VERIFY marker; aggregate '
      'rows read approved tables (tools/abaptools/onboarding.py).')

# Link registry (2026-11-11): the overlay with the product layers valid, seed rows / lineage / snippets / impact current
import link_registry  # noqa: E402
check('link_registry', link_registry._engine.check(ROOT, link_registry.PROFILE),
      'The customer overlay config/links/overlay.json is valid on top of the product layers of the framework '
      '(ids and prefixes, declared fields, repository DDIC / CDS metadata, conditions, active links on confirmed '
      'fields only, cardinality, fallback chains, replacements, sensitivity) and its generated seed rows, lineage, '
      'CDS snippets and impact report are up to date (tools/link_registry.py).')

# Process catalogue (2026-11-11): the customer layer with the product packages valid, seed rows / documents current
import process_catalogue  # noqa: E402
check('process_catalogue', process_catalogue._engine.check(ROOT, process_catalogue.PROFILE),
      'The customer layer config/catalogue/overlay.json is valid on top of the product packages of the framework '
      '(ids and prefixes, package ranks, steps, tables and their link registry objects, dependencies without '
      'cycles, activation rows with a reason and no person, CAT_PROCESS of config/process_register.csv) and its '
      'seed rows, catalogue and activation proposal are up to date (tools/process_catalogue.py).')

lint_bin = sys.argv[1] if len(sys.argv) > 1 else None
lint_detail, lint_failures = 'abaplint not run (no binary given)', ['not run']
if lint_bin:
    out = subprocess.run([lint_bin], cwd=ROOT, capture_output=True, text=True).stdout
    m = re.search(r'abaplint: (\d+) issue', out)
    issues = int(m.group(1)) if m else -1
    lint_failures = [] if issues == 0 else [l for l in out.splitlines() if '[E]' in l][:50] or [out[-500:]]
    lint_detail = f'abaplint (v758 syntax, SAP stubs from abaplint/deps): {issues} issue(s) over {len(files)} files.'
check('abaplint_clean', lint_failures, lint_detail)

# ATC-equivalent rule set (abaplint.atc.json); documented exemptions only, see docs/ATC_Validation.md
ATC_KNOWN = {('src/hck/zcl_cd_hck_dao.clas.abap', 'select_add_order_by'),
             ('src/fmon/zcl_cd_fmon_dao.clas.abap', 'db_operation_in_loop')}
atc_detail, atc_failures = 'ATC-equivalent set not run (no binary given)', ['not run']
if lint_bin:
    proc = subprocess.run([lint_bin, 'abaplint.atc.json'], cwd=ROOT, capture_output=True, text=True)
    out = proc.stdout
    found = re.findall(r'^(\S+)\[\d+, \d+\].*\((\w+)\) \[', out, re.M)
    summary = re.search(r'^abaplint: (\d+) issue\(s\) found, (\d+) file\(s\) analyzed', out, re.M)
    # Audit A24: a run that did not complete (exit code other than 0 / 1, no summary line,
    # no files, or a finding count that differs from the parsed lines) never passes
    if proc.returncode not in (0, 1) or not summary or int(summary.group(2)) == 0 \
            or int(summary.group(1)) != len(found):
        atc_failures = [f'abaplint ATC run incomplete (exit {proc.returncode}, '
                        f'summary {"found" if summary else "missing"})']
        atc_detail = 'ATC-equivalent abaplint rule set did not complete: ' + (proc.stderr or out)[-300:]
    else:
        atc_failures = [f'{f} {r}' for f, r in found if (f, r) not in ATC_KNOWN]
        atc_detail = (f'ATC-equivalent abaplint rule set: {len(found)} finding(s) over '
                      f'{summary.group(2)} file(s), {len(found) - len(atc_failures)} documented exemption(s).')
check('atc_equivalent_clean', atc_failures, atc_detail)

docs = os.path.join(ROOT, 'docs')
result = {
    '_artifact': {'name': 'portable_checks.json',
                  'purpose': 'Portable consistency evidence; not SAP activation, ATC, runtime or coverage',
                  'generated': datetime.date.today().isoformat()},
    'passed': sum(c['passed'] for c in checks), 'total': len(checks),
    'abap_files': len(files), 'declared_unit_methods': sum(register.values()),
    'measured_coverage': None, 'checks': checks}
json.dump(result, open(os.path.join(docs, 'portable_checks.json'), 'w'), indent=2)

# One row per class (tools/test_checks.py): own test include, covered by another one, or exempt
_paths = test_checks.load_register(ROOT)
_classes = sorted({obj_name(f).upper() for f in files if f.endswith('.clas.abap')} | set(register))
with open(os.path.join(docs, 'Coverage_Run_Register.csv'), 'w', newline='') as fh:
    w = csv.writer(fh)
    w.writerow(['Object', 'Test path', 'Covered by', 'ABAP Unit methods supplied',
                'Required statement coverage percent', 'Measured statement coverage percent', 'Status'])
    for owner in _classes:
        kind, covered_by, reason = _paths.get(owner, ('own', '', ''))
        if owner in register:
            status = 'Not run in target SAP' + (f'; partial exemption: {reason}' if reason else '')
            w.writerow([owner, 'own test include', '', register[owner], 90, '', status])
        elif kind == 'covered':
            w.writerow([owner, 'covered', covered_by, 0, 90, '',
                        f'Not run in target SAP; measured in {covered_by} ({reason})'])
        else:
            w.writerow([owner, 'exempt', '', 0, '', '', f'Exempt: {reason}'])

with open(os.path.join(docs, 'Changed_Artifacts.csv'), 'w', newline='') as fh:
    w = csv.writer(fh)
    w.writerow(['Artifact', 'Type', 'Purpose'])
    for d, _, fs in sorted(os.walk(ROOT)):
        if '/.git' in d or '/node_modules' in d:
            continue
        for f in sorted(fs):
            p = os.path.relpath(os.path.join(d, f), ROOT)
            kind = ('ABAP' if f.endswith('.abap') else 'abapGit' if f.endswith('.xml') else
                    'DDIC' if f.endswith('.ddl') else
                    'CDS' if f.endswith(('.asddls', '.asddlxs')) else
                    'RAP' if f.endswith(('.asbdef', '.srvdsrv')) else 'Config' if p.startswith('config') else
                    'Doc' if f.endswith(('.md', '.csv', '.json')) else 'Other')
            purpose = ''
            if f.endswith('.abap'):
                m = re.search(r'\*& Purpose:\n\*& (.*)', open(os.path.join(d, f), encoding='utf-8').read())
                purpose = m.group(1).strip() if m else ''
            w.writerow([p, kind, purpose])

print(f"{result['passed']}/{result['total']} checks passed; {len(files)} ABAP files; "
      f"{result['declared_unit_methods']} unit test methods")
for c in checks:
    if not c['passed']:
        print('FAIL', c['name'], c['failures'][:5])

sys.exit(0 if result['passed'] == result['total'] else 1)
