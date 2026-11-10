#!/usr/bin/env python3
"""House checks shared by the component check runners (offline, no SAP system).

Each component keeps its own runner with its list of checks (param-framework/tools/checks.py,
ops-framework/tools/checks.py, ops-suite/tools/portable_checks.py); the checks below are the
common ones. Every check takes the component folder and returns its failures (empty = pass).
Offline evidence of house-rule compliance only - not SAP activation, ATC or ABAP Unit.

  name_lengths        object names <= 30, transparent tables <= 16, message class <= 20,
                      authorization fields / objects <= 10, test methods <= 30, short texts <= 60
                      (abapGit file names) plus the declaration limits of name_checks
  method_names        methods snake_case, no data prefix, <= 30 (name_checks)
  artifact_header     every ABAP source starts with '*& Artifact: <file name>' and has
                      Purpose and Modification log lines
  pcre_only           no POSIX regular expressions (name_checks)
  no_cp_patterns      no CP / NP comparisons and no option 'CP' / 'NP' (name_checks)
  no_select_star      explicit field lists in every SELECT
  final_classes       every public concrete class is FINAL (exception classes excepted: consumers
                      inherit them)
  test_classes        every test class has RISK LEVEL HARMLESS and DURATION SHORT
  test_path           every class has a test include or a row in tools/test_path_register.csv
                      (covered by a test include that names it, or exempt with a reason)
  customer_terms      none of the words of config/customer_terms.txt in src/, the message texts or the
                      text elements (whole words, case ignored)
  packaging           the component is self-contained: no file of it names a component folder it
                      must not depend on (Python imports, abaplint dependency paths, document links)

Modification log:
2026-11-10 | Operations framework: test paths, layering, customer wording.
2026-11-10 | Moved to the shared tools (tools/abaptools): one implementation per check, per-folder lists;
           | PCRE / CP / name checks of name_checks for every component; packaging check.
"""
import csv
import json
import os
import re

from . import name_checks

SKIP_DIRS = {'.git', 'deps', 'node_modules', '__pycache__'}


# ---------------------------------------------------------------------------------- reading
def files(root, suffixes):
    for d, dirs, names in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x not in SKIP_DIRS)
        for f in sorted(names):
            if f.endswith(suffixes):
                yield os.path.join(d, f)


def read(path):
    with open(path, encoding='utf-8') as handle:
        return handle.read()


def strip_comments(text):
    """ABAP source without full-line comments and without end-of-line comments."""
    out = []
    for line in text.splitlines():
        stripped = line.lstrip()
        if stripped.startswith('*') or stripped.startswith('"'):
            continue
        out.append(strip_eol_comment(line))
    return '\n'.join(out)


def strip_eol_comment(line):
    quote = None
    for i, ch in enumerate(line):
        if quote:
            if ch == quote:
                quote = None
        elif ch in ("'", '`', '|'):
            quote = ch
        elif ch == '"':
            return line[:i]
    return line


def strip_literals(code):
    return re.sub(r"'[^'\n]*'|`[^`\n]*`|\|[^|\n]*\|", "''", code)


def statements(code):
    return [s for s in re.split(r'\.\s*\n', code) if s.strip()]


def message_source(root):
    """Path of the message class source named in config/repository.json."""
    cfg = json.loads(read(os.path.join(root, 'config', 'repository.json')))
    return os.path.join(root, cfg['message_class']['source'])


# ---------------------------------------------------------------------------------- checks
def check_name_lengths(root):
    failures = []
    for path in files(os.path.join(root, 'src'), ('.xml',)):
        base = os.path.basename(path)
        parts = base.split('.')
        if len(parts) < 3 or parts[0] == 'package':
            continue
        name, kind = parts[0], parts[1]
        limit = {'tabl': 16, 'msag': 20, 'auth': 10, 'suso': 10, 'susc': 4}.get(kind, 30)
        if len(name) > limit:
            failures.append(f'{base}: {name} longer than {limit}')
    for path in files(os.path.join(root, 'src'), ('.abap',)):
        text = read(path)
        for m in re.finditer(r'METHODS\s+(\w+)\s+FOR\s+TESTING', text, re.I):
            if len(m.group(1)) > 30:
                failures.append(f'{os.path.basename(path)}: test method {m.group(1)} longer than 30')
        for m in re.finditer(r'shorttext synchronized">([^<]*)<', text):
            if len(m.group(1)) > 60:
                failures.append(f'{os.path.basename(path)}: short text longer than 60')
    return failures + name_checks.name_length_failures(root)


def check_method_names(root):
    return name_checks.method_name_failures(root)


def check_artifact_header(root):
    failures = []
    for path in files(os.path.join(root, 'src'), ('.abap',)):
        text = read(path)
        base = os.path.basename(path)
        if not re.match(r'\*&-+\*\n\*& Artifact: ' + re.escape(base) + r'\s*\n', text):
            failures.append(f'{base}: header must start with "*& Artifact: {base}"')
        elif '*& Purpose:' not in text or '*& Modification log:' not in text:
            failures.append(f'{base}: Purpose or Modification log missing')
    return failures


def check_pcre_only(root):
    return name_checks.posix_regex_failures(root)


def check_no_cp(root):
    return name_checks.cp_pattern_failures(root)


def check_no_select_star(root):
    return [os.path.basename(p) for p in files(os.path.join(root, 'src'), ('.abap',))
            if re.search(r'\bSELECT\s+(SINGLE\s+)?\*', strip_comments(read(p)), re.I)]


def check_final(root):
    failures = []
    for path in files(os.path.join(root, 'src'), ('.clas.abap',)):
        if os.path.basename(path).startswith('zcx_'):
            continue  # exception classes are inherited by consumers
        m = re.search(r'^CLASS\s+(\w+)\s+DEFINITION(.*?)\.', strip_comments(read(path)), re.S | re.I | re.M)
        if m and 'PUBLIC' in m.group(2).upper() and 'ABSTRACT' not in m.group(2).upper() \
                and 'FINAL' not in m.group(2).upper():
            failures.append(os.path.basename(path))
    return failures


def check_test_classes(root):
    failures = []
    for path in files(os.path.join(root, 'src'), ('.abap',)):
        code = strip_comments(read(path))
        for m in re.finditer(r'CLASS\s+(\w+)\s+DEFINITION([^.]*?)\bFOR\s+TESTING([^.]*)\.', code, re.S | re.I):
            tail = re.sub(r'\s+', ' ', (m.group(2) + m.group(3)).upper())
            if not re.search(r'METHODS\s+\w+\s+FOR\s+TESTING', code[m.end():].split('ENDCLASS')[0], re.I):
                continue
            if 'RISK LEVEL HARMLESS' not in tail or 'DURATION SHORT' not in tail:
                failures.append(f'{os.path.basename(path)}: {m.group(1)}')
    return failures


def check_test_path(root):
    register = {}
    path = os.path.join(root, 'tools', 'test_path_register.csv')
    if os.path.exists(path):
        with open(path, encoding='utf-8', newline='') as fh:
            register = {r['object'].upper(): r for r in csv.DictReader(fh)}
    failures = []
    classes = {os.path.basename(p).split('.')[0].upper(): p for p in files(os.path.join(root, 'src'), ('.clas.abap',))}
    for name, p in sorted(classes.items()):
        if os.path.exists(p.replace('.clas.abap', '.clas.testclasses.abap')):
            continue
        row = register.get(name)
        if row is None:
            failures.append(f'{name}: no test include and no register row')
        elif row['path'] == 'covered':
            cover = classes.get(row['covered_by'].upper())
            include = cover.replace('.clas.abap', '.clas.testclasses.abap') if cover else ''
            if not include or not os.path.exists(include) or name.lower() not in read(include).lower():
                failures.append(f'{name}: covering test include {row["covered_by"]} missing or does not name it')
        elif row['path'] != 'exempt' or not row['reason']:
            failures.append(f'{name}: register row must be covered (with a test include) or exempt with a reason')
    for name in register:
        if name not in classes:
            failures.append(f'{name}: register row for a class that does not exist')
    return failures


SOURCE_SUFFIXES = ('.abap', '.asddls', '.asdcls', '.asddlxs', '.asbdef', '.srvdsrv', '.xml')


def customer_terms(root):
    path = os.path.join(root, 'config', 'customer_terms.txt')
    terms = []
    for line in read(path).splitlines():
        line = line.split('#')[0].strip()
        if line:
            terms.append(line)
    return terms


def check_customer_terms(root, allowed_line=None):
    """No word of config/customer_terms.txt in src/, the text elements and the message texts;
    allowed_line = a compiled pattern of lines that may name one (e.g. a 'Moved from' log line)."""
    pattern = re.compile(r'(?<![A-Za-z0-9])(' + '|'.join(re.escape(t) for t in customer_terms(root)) +
                         r')(?![A-Za-z0-9])', re.I)
    targets = list(files(os.path.join(root, 'src'), SOURCE_SUFFIXES))
    targets += list(files(os.path.join(root, 'docs', 'text_elements'), ('.md',)))
    targets.append(message_source(root))
    failures = []
    for path in targets:
        for no, line in enumerate(read(path).splitlines(), start=1):
            if allowed_line and allowed_line.match(line):
                continue
            m = pattern.search(line)
            if m:
                failures.append(f'{os.path.relpath(path, root)}:{no}: {m.group(1)}')
    return failures


def check_references(root, pattern, allowed_line=None):
    """Lines of src/ that name an object of pattern (layering: e.g. a consumer's objects)."""
    failures = []
    for path in files(os.path.join(root, 'src'), SOURCE_SUFFIXES):
        for no, line in enumerate(read(path).splitlines(), start=1):
            if allowed_line and allowed_line.match(line):
                continue
            m = pattern.search(line)
            if m:
                failures.append(f'{os.path.relpath(path, root)}:{no}: {m.group(1)}')
    return failures


# Packaging: text files of a component that may name another component folder
PACKAGING_SUFFIXES = ('.py', '.json', '.md', '.yml', '.yaml', '.csv', '.txt', '.abap', '.asddls', '.asdcls',
                      '.asddlxs', '.asbdef', '.srvdsrv', '.xml', '.ddl')


PACKAGING_LIST = 'packaging: forbidden folders'


def check_packaging(root, forbidden, exempt=('CHANGELOG.md',)):
    """The component is self-contained: no file under root names a forbidden component folder
    (e.g. a consumer's folder) - no Python import or path, abaplint dependency folder or document
    link. The shared tools (<repository>/tools) are allowed for every component. exempt = file
    names whose history may name the component they came from (the change log); a line that
    carries the comment PACKAGING_LIST is the runner's own list of forbidden folders."""
    words = re.compile(r'(?<![\w-])(' + '|'.join(re.escape(f) for f in forbidden) + r')(?![\w-])', re.I)
    failures = []
    for path in files(root, PACKAGING_SUFFIXES):
        if os.path.basename(path) in exempt:
            continue
        for no, line in enumerate(read(path).splitlines(), start=1):
            if PACKAGING_LIST in line:
                continue
            m = words.search(line)
            if m:
                failures.append(f'{os.path.relpath(path, root)}:{no}: names {m.group(1)}')
    return failures


# ---------------------------------------------------------------------------------- runner
def run(checks, root):
    """{name: failures} of a component's list of (name, function) checks."""
    return {name: fn(root) for name, fn in checks}


def report(results):
    """Print the results; returns the exit code (1 when a check failed)."""
    failed = 0
    for name, failures in results.items():
        print(f'{"PASS" if not failures else "FAIL"}  {name}')
        for f in failures[:50]:
            print(f'      {f}')
        failed += bool(failures)
    print(f'{len(results) - failed}/{len(results)} checks passed')
    return 1 if failed else 0
