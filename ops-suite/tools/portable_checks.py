#!/usr/bin/env python3
"""Portable consistency checks for the ops suite (no SAP system needed).

Evidence of house-rule compliance only - NOT SAP activation, ATC or ABAP Unit
results. Writes docs/portable_checks.json, docs/Coverage_Run_Register.csv and
docs/Changed_Artifacts.csv.  Usage:  python3 tools/portable_checks.py [abaplint-binary]
"""
import csv, json, os, re, subprocess, sys, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
COMMIT_ALLOWED = {'zcl_cd_ops_store.clas.abap', 'zcl_cd_ops_chn_email.clas.abap'}

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
hdr, names, short, select_star, fae, bukrs, final, risk, tnames, commits, writes = ([] for _ in range(11))
for f in files:
    rel = os.path.relpath(f, ROOT)
    text = open(f, encoding='utf-8').read()
    code = strip_comments(text)
    base = os.path.basename(f)
    if not re.search(r'^\*& Artifact: ' + re.escape(base) + r'\s*$', text, re.M):
        hdr.append(rel)
    if len(obj_name(f)) > 30:
        names.append(rel)
    for m in re.finditer(r'shorttext synchronized">([^<]*)<', text):
        if len(m.group(1)) > 60:
            short.append(f'{rel}: {m.group(1)}')
    if re.search(r'\bSELECT\s+(SINGLE\s+)?\*', code, re.I):
        select_star.append(rel)
    for m in re.finditer(r'METHOD\s+([\w~]+)\.(.*?)ENDMETHOD\.', code, re.S | re.I):
        body = m.group(2)
        if re.search(r'FOR\s+ALL\s+ENTRIES', body, re.I) and not re.search(r'IS\s+(NOT\s+)?INITIAL|CHECK\s+\w', body, re.I):
            fae.append(f'{rel}: {m.group(1)}')
    if re.search(r"'1000'", code) and 'testclasses' not in base:
        bukrs.append(rel)
    if base.endswith('.clas.abap'):
        m = re.search(r'CLASS\s+\w+\s+DEFINITION(.*?)\.', code, re.S | re.I)
        if m and 'PUBLIC' in m.group(1).upper() and 'ABSTRACT' not in m.group(1).upper() \
                and 'FINAL' not in m.group(1).upper() and not obj_name(f).startswith('zcx_'):
            final.append(rel)
    for m in re.finditer(r'CLASS\s+(\w+)\s+DEFINITION([^.]*?)FOR\s+TESTING([^.]*)\.', code, re.S | re.I):
        tail = (m.group(2) + m.group(3)).upper()
        if 'ABSTRACT' in tail and 'RISK' not in tail:
            continue
        if ('RISK LEVEL' in tail or 'DURATION' in tail) and ('HARMLESS' not in tail or 'SHORT' not in tail):
            risk.append(f'{rel}: {m.group(1)}')
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

check('artifact_header_present', hdr, 'Every ABAP source starts with the Artifact/Purpose/Modification log header.')
check('object_names_max_30', names, 'Every object name is 30 characters or fewer.')
check('short_text_max_60', short, 'Every SE24 short text (ABAP Doc shorttext) is 60 characters or fewer.')
check('no_select_star', select_star, 'No SELECT * (explicit field lists only).')
check('fae_guarded', fae, 'Every method with FOR ALL ENTRIES checks the driver table for INITIAL first.')
check('no_hardcoded_company_code', bukrs, "No hard-coded company code '1000' in production code.")
check('concrete_classes_final', final, 'Every concrete public class is FINAL.')
check('tests_harmless_short', risk, 'Every test class is RISK LEVEL HARMLESS DURATION SHORT.')
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

check('pcre_only', name_checks.posix_regex_failures(ROOT),
      'Regular expressions use PCRE only (pcre = / PCRE); POSIX (regex =, FIND / REPLACE ... REGEX, '
      'CL_ABAP_REGEX POSIX) is obsolete since ABAP 7.55.')

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

with open(os.path.join(docs, 'Coverage_Run_Register.csv'), 'w', newline='') as fh:
    w = csv.writer(fh)
    w.writerow(['Object', 'ABAP Unit methods supplied', 'Required statement coverage percent',
                'Measured statement coverage percent', 'Status'])
    for owner in sorted(register):
        w.writerow([owner, register[owner], 90, '', 'Not run in target SAP'])

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
