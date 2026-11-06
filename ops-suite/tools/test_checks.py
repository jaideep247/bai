#!/usr/bin/env python3
"""
Artifact: tools/test_checks.py
Purpose:  Portable test-path checks of the ops suite (no SAP system needed). Used by
          tools/portable_checks.py; evidence of test structure only - NOT ABAP Unit results
          or coverage (measured in DV1, docs/Coverage_Run_Register.csv).
            test_path_every_class   every class in src/ has its own test include, or a row in
                                    tools/test_path_register.csv that names a covering test
                                    include (which must mention the class) or an exemption
                                    with its reason
            osql_doubles_complete   a test include of a class with Open SQL uses
                                    cl_osql_test_environment / cl_cds_test_environment, and
                                    every table read or written by the class methods its tests
                                    call (and the private helpers they call) is in a double list
            no_real_dao_in_tests    a test include of a class without SQL that gets a DAO or the
                                    store from a factory injects doubles (an injector call), and no
                                    test include of a class without SQL creates a real DAO / store
          Limits (best effort, static): dynamic table names (FROM (lv_table)) are not resolved;
          methods reached only through another class are not followed; the double lists are
          the quoted names inside the create( ... ) calls of the include. A table a test never
          reaches (the method raises before the statement) is declared in the include with the
          comment marker  osql-not-reached: <TABLE>.
Usage:    python3 tools/test_checks.py            -> failures of every check
Modification log:
2026-11-06 | Initial version (coverage gap closure: test path, OSQL doubles, injected DAOs).
"""
import csv
import os
import re
import sys

REGISTER = os.path.join('tools', 'test_path_register.csv')
KINDS = ('own', 'covered', 'exempt')
SQL_SOURCE = re.compile(r'\b(?:FROM|JOIN)\s+([a-z/][\w/]*)', re.I)
NOT_TABLES = {'TABLE', 'DATA', 'CORRESPONDING', 'FIELDS', 'INITIAL', 'LINE', 'SCREEN', 'ADJACENT', 'VALUE',
              'TEXT', 'MEMORY', 'DATABASE', 'SHARED'}
FACTORY_DAO = re.compile(r'zcl_cd_\w+_factory=>get_(?:\w*dao|store)\s*\(', re.I)
INJECTOR_CALL = re.compile(r'zcl_cd_\w+_injector=>inject_\w+\s*\(', re.I)
REAL_DAO = re.compile(r'\bNEW\s+zcl_cd_\w*(?:dao|store)\s*\(|CREATE\s+OBJECT\s+\w+\s+TYPE\s+zcl_cd_\w*(?:dao|store)\b', re.I)
NOT_REACHED = re.compile(r'osql-not-reached:\s*([\w/ ,]+)', re.I)


def _walk_classes(root):
    for folder, dirs, files in os.walk(os.path.join(root, 'src')):
        dirs.sort()
        for name in sorted(files):
            if name.endswith('.clas.abap'):
                yield os.path.join(folder, name)


def _read(path):
    with open(path, encoding='utf-8') as fh:
        return fh.read()


def _code(text):
    """ABAP without comment lines, end-of-line comments and literal contents."""
    out = []
    for line in text.splitlines():
        if line.lstrip().startswith('*'):
            continue
        buf, lit = [], None
        for ch in line:
            if lit:
                if ch == lit:
                    lit = None
                    buf.append(ch)
                continue
            if ch in "'`|":
                lit = ch
                buf.append(ch)
                continue
            if ch == '"':
                break
            buf.append(ch)
        out.append(''.join(buf))
    return '\n'.join(out)


def _test_include(path):
    return path.replace('.clas.abap', '.clas.testclasses.abap')


def _name(path):
    return os.path.basename(path).split('.')[0].upper()


def load_register(root):
    """{OBJECT: (kind, covered_by, reason)} from tools/test_path_register.csv."""
    rows = {}
    path = os.path.join(root, REGISTER)
    if not os.path.exists(path):
        return rows
    with open(path, encoding='utf-8', newline='') as fh:
        for row in csv.DictReader(fh):
            rows[row['object'].strip().upper()] = (row['path'].strip().lower(), row['covered_by'].strip().upper(),
                                                  row['reason'].strip())
    return rows


def _includes_by_owner(root):
    return {_name(p): _test_include(p) for p in _walk_classes(root) if os.path.exists(_test_include(p))}


def test_path_failures(root):
    failures = []
    register = load_register(root)
    includes = _includes_by_owner(root)
    classes = {_name(p) for p in _walk_classes(root)}
    for name in sorted(classes):
        kind, covered_by, reason = register.get(name, ('', '', ''))
        if name in includes:
            if kind and kind != 'own':
                failures.append(f'{name}: has its own test include but the register says {kind}')
            continue
        if kind == 'covered':
            if covered_by not in includes:
                failures.append(f'{name}: covering test include {covered_by or "(none)"} does not exist')
            elif not re.search(r'\b' + re.escape(name) + r'\b', _read(includes[covered_by]), re.I):
                failures.append(f'{name}: covering test include {covered_by} never mentions the class')
        elif kind == 'exempt':
            if not reason:
                failures.append(f'{name}: exemption without reason')
        else:
            failures.append(f'{name}: no test include and no register row (covered by / exempt)')
    for name, (kind, _, reason) in sorted(register.items()):
        if name not in classes:
            failures.append(f'{name}: register row for a class that does not exist')
        if kind not in KINDS:
            failures.append(f'{name}: unknown test path kind {kind!r}')
        if kind == 'own' and not reason:
            failures.append(f'{name}: own-include row without the partial exemption it records')
    return failures


def _methods(code):
    """{short method name: body} of the IMPLEMENTATION part of a class."""
    impl = code[code.upper().find('IMPLEMENTATION'):]
    return {m.group(1).split('~')[-1].lower(): m.group(2)
            for m in re.finditer(r'^\s*METHOD\s+([\w~]+)\s*\.(.*?)^\s*ENDMETHOD\s*\.', impl, re.S | re.M | re.I)}


def _tables(body):
    """Database tables / CDS entities of the Open SQL statements of a method body (static names
    only; internal-table INSERT / MODIFY / DELETE and dynamic names are not tables)."""
    found = set()
    for statement in re.split(r'\.\s*$', body, flags=re.M):
        st = ' '.join(statement.split())
        head = st.split(' ', 1)[0].upper() if st else ''
        names = []
        if head in ('SELECT', 'WITH', 'OPEN'):
            names = SQL_SOURCE.findall(st)
        elif head == 'UPDATE':
            names = re.findall(r'^UPDATE\s+([a-z/][\w/]*)\s+(?:SET|FROM)\b', st, re.I) + SQL_SOURCE.findall(st)
        elif head == 'INSERT':
            names = re.findall(r'^INSERT\s+INTO\s+(?!TABLE\b)([a-z/][\w/]*)', st, re.I) + \
                re.findall(r'^INSERT\s+([a-z/][\w/]*)\s+FROM\s+(?:TABLE\s+)?@', st, re.I)
        elif head == 'MODIFY':
            names = re.findall(r'^MODIFY\s+([a-z/][\w/]*)\s+FROM\s+(?:TABLE\s+)?@', st, re.I)
        elif head == 'DELETE':
            names = re.findall(r'^DELETE\s+FROM\s+([a-z/][\w/]*)', st, re.I) + \
                re.findall(r'^DELETE\s+([a-z/][\w/]*)\s+FROM\s+(?:TABLE\s+)?@', st, re.I)
        found.update(n.upper() for n in names if n.upper() not in NOT_TABLES)
    return found


def has_sql(code):
    """Open SQL outside test seams (SQL inside a seam is replaced by its injection in tests)."""
    return any(_tables(_without_seams(body)) for body in _methods(code).values())


def _without_seams(body, seams=None):
    """Method body without the TEST-SEAM blocks (all of them, or only the named ones)."""
    def keep(m):
        return m.group(0) if seams is not None and m.group(1).lower() not in seams else ''
    return re.sub(r'^\s*TEST-SEAM\s+(\w+)\s*\..*?^\s*END-TEST-SEAM\s*\.', keep, body, flags=re.S | re.M | re.I)


def _reached(methods, called):
    todo, seen = list(called), set()
    while todo:
        name = todo.pop()
        if name in seen or name not in methods:
            continue
        seen.add(name)
        for other in methods:
            if other not in seen and re.search(r'(?<![\w>~-])' + re.escape(other) + r'\s*\(', methods[name], re.I):
                todo.append(other)
    return seen


def _doubles(test):
    """Names in the double lists: quoted names inside the create( ) calls and inside class_setup
    (a list built there), plus the osql-not-reached markers."""
    names = set()
    for m in re.finditer(r'cl_(?:osql|cds)_test_environment=>create\s*\((.*?)\)\s*\.', test, re.S | re.I):
        names.update(n.upper() for n in re.findall(r"'([\w/]+)'", m.group(1)))
    for m in re.finditer(r'^\s*METHOD\s+class_setup\s*\.(.*?)^\s*ENDMETHOD\s*\.', test, re.S | re.M | re.I):
        names.update(n.upper() for n in re.findall(r"'([\w/]+)'", m.group(1)))
    for m in NOT_REACHED.finditer(test):
        names.update(n.strip().upper() for n in m.group(1).replace(',', ' ').split())
    return names


def osql_double_failures(root):
    failures = []
    for path in _walk_classes(root):
        test_path = _test_include(path)
        if not os.path.exists(test_path):
            continue
        raw_test = _read(test_path)
        test = _code(raw_test)
        injected = {m.lower() for m in re.findall(r'TEST-INJECTION\s+(\w+)', test, re.I)}
        methods = {name: _without_seams(body, injected) for name, body in _methods(_code(_read(path))).items()}
        if not any(_tables(body) for body in methods.values()):
            continue
        rel = os.path.relpath(test_path, root)
        if not re.search(r'cl_(osql|cds)_test_environment=>create', test, re.I):
            failures.append(f'{rel}: class has Open SQL, test include has no cl_osql_test_environment')
            continue
        called = {m.lower() for m in re.findall(r'(?:->|~)(\w+)\s*\(', test)}
        doubles = _doubles(test) | _doubles(raw_test)
        missing = set()
        for name in _reached(methods, called):
            missing |= _tables(methods[name]) - doubles
        if missing:
            failures.append(f'{rel}: tables read by tested methods are not doubled: {", ".join(sorted(missing))}')
    return failures


def real_dao_failures(root):
    failures = []
    for path in _walk_classes(root):
        test_path = _test_include(path)
        if not os.path.exists(test_path):
            continue
        code = _code(_read(path))
        if has_sql(code):
            continue
        test = _code(_read(test_path))
        rel = os.path.relpath(test_path, root)
        if REAL_DAO.search(test):
            failures.append(f'{rel}: test include of a class without SQL creates a real DAO / store')
        if FACTORY_DAO.search(code) and not INJECTOR_CALL.search(test):
            failures.append(f'{rel}: class gets a DAO from a factory, test include injects no double')
    return failures


if __name__ == '__main__':
    ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    total = 0
    for check, func in (('test_path_every_class', test_path_failures),
                        ('osql_doubles_complete', osql_double_failures),
                        ('no_real_dao_in_tests', real_dao_failures)):
        fails = func(ROOT)
        total += len(fails)
        print(f'{check}: {len(fails)} failure(s)')
        for f in fails:
            print('  ' + f)
    sys.exit(1 if total else 0)
