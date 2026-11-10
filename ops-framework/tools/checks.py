#!/usr/bin/env python3
"""House checks of the operations framework ZCA_OPS that abaplint does not cover.

Copied from param-framework/tools/checks.py (2026-11-10) and extended for the framework: abapGit
metadata, messages used and defined, a test path for every class, the seed class of the parameters,
layering (no reference to a consumer) and customer wording.

Offline evidence of house-rule compliance only - not SAP activation, ATC or ABAP Unit.
Usage:  python3 tools/checks.py          (exit 1 when a check fails)

Checks
  name_lengths        object names <= 30, transparent tables <= 16, message class <= 20,
                      authorization fields / objects <= 10, test methods <= 30, short texts <= 60
  artifact_header     every ABAP source starts with '*& Artifact: <file name>' and has
                      Purpose and Modification log lines
  pcre_only           no POSIX regular expressions (regex =, FIND/REPLACE ... REGEX, CREATE_POSIX)
  no_cp_patterns      no CP / NP comparisons and no option 'CP' / 'NP'
  no_inline_texts     no user text as a literal in production code: MESSAGE with a text literal, or a
                      sentence-like literal outside declarations (test data of test includes allowed)
  no_select_star      explicit field lists in every SELECT
  final_classes       every public concrete class is FINAL
  test_classes        every test class has RISK LEVEL HARMLESS and DURATION SHORT
  messages            every ZCA_OPS message number the code raises or names (MESSAGE eNNN(zca_ops), gc_msg
                      constants of the types interfaces) has a row in config/zca_ops_messages.md, every
                      row is used by production code (000, the free-text message, excepted); texts <= 73
  abapgit_up_to_date  tools/abapgit_serialize.py --check (generated XML equals the sources)
  test_path           every class has a test include or a row in tools/test_path_register.csv
                      (covered by a test include that names it, or exempt with a reason)
  param_definitions   tools/param_definitions.py: definitions of area CA_OPS complete, seed class generated
  layering            no reference to a consumer object (ZCD_*, ZCL_CD_*, ZIF_CD_*, ZCX_CD_*) in src/ -
                      only the modification log line "Moved from ..." may name the former object
  customer_terms      none of the words of config/customer_terms.txt in src/, the message texts or the
                      text elements (whole words, case ignored)
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP_DIRS = {'.git', 'deps', 'node_modules', '__pycache__'}


def files(root, suffixes):
    for d, dirs, names in os.walk(root):
        dirs[:] = [x for x in dirs if x not in SKIP_DIRS]
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
    return failures


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


POSIX = re.compile(r'\bregex\s*=|\b(FIND|REPLACE)\b[^.]*\bREGEX\b|create_posix', re.I)


def check_pcre_only(root):
    failures = []
    for path in files(os.path.join(root, 'src'), ('.abap',)):
        for stmt in strip_comments(read(path)).split('.'):
            if POSIX.search(stmt) and not re.search(r'\bPCRE\b', stmt, re.I):
                failures.append(f'{os.path.basename(path)}: {stmt.strip()[:80]}')
    return failures


def check_no_cp(root):
    failures = []
    for path in files(os.path.join(root, 'src'), ('.abap',)):
        code = strip_literals(strip_comments(read(path)))
        if re.search(r'\s(CP|NP)\s', code) or re.search(r"option\s*=\s*'(CP|NP)'", read(path), re.I):
            failures.append(os.path.basename(path))
    return failures


def strip_literals(code):
    return re.sub(r"'[^'\n]*'|`[^`\n]*`|\|[^|\n]*\|", "''", code)


DECLARATION = re.compile(r'^\s*(CONSTANTS|TYPES|DATA|CLASS-DATA|STATICS)\b', re.I)
SENTENCE = re.compile(r"'([^'\n]*[A-Za-z]{2,}\s+[A-Za-z]{2,}[^'\n]*)'|`([^`\n]*[A-Za-z]{2,}\s+[A-Za-z]{2,}[^`\n]*)`")


def statements(code):
    return [s for s in re.split(r'\.\s*\n', code) if s.strip()]


LITERAL = re.compile(r"'(?:[^'\n]|'')*'|`(?:[^`\n]|``)*`")
WORDS = re.compile(r'[A-Za-z]{2,} +[A-Za-z]{2,}')


def check_no_inline_texts(root):
    """Production code only: test data of a test include is no user text (as in the suite's literal scan)."""
    failures = []
    for path in files(os.path.join(root, 'src'), ('.abap',)):
        base = os.path.basename(path)
        if '.testclasses.' in base:
            continue
        for stmt in statements(strip_comments(read(path))):
            if re.search(r"\bMESSAGE\s+['`]", stmt, re.I):
                failures.append(f'{base}: MESSAGE with a text literal')
                continue
            if DECLARATION.match(stmt):
                continue
            for m in LITERAL.finditer(stmt):
                if WORDS.search(m.group(0)[1:-1]):
                    failures.append(f'{base}: {m.group(0)[:60]}')
    return failures


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
            tail = (m.group(2) + m.group(3)).upper()
            if not re.search(r'METHODS\s+\w+\s+FOR\s+TESTING', code[m.end():].split('ENDCLASS')[0], re.I):
                continue
            if 'RISK LEVEL HARMLESS' not in re.sub(r'\s+', ' ', tail) or 'DURATION SHORT' not in re.sub(r'\s+', ' ', tail):
                failures.append(f'{os.path.basename(path)}: {m.group(1)}')
    return failures


MSG_ROW = re.compile(r'^\| (\d{3}) \| (.*?) \|$', re.M)
RAISED = re.compile(r'\b[EWISAX](\d{3})\(zca_ops\)', re.I)
CONST = re.compile(r"(\w+)\s+TYPE\s+\S+\s+VALUE\s+'(\d{3})'", re.I)


def message_rows(root):
    cfg = json.loads(read(os.path.join(root, 'config', 'repository.json')))
    return MSG_ROW.findall(read(os.path.join(root, cfg['message_class']['source'])))


def message_constants(root):
    """(file, name, number) of every gc_msg constant of the framework's types interfaces."""
    out = []
    for path in files(os.path.join(root, 'src'), ('types.intf.abap',)):
        block = re.search(r'BEGIN OF gc_msg,(.*?)END OF gc_msg', strip_comments(read(path)), re.S | re.I)
        if block:
            out += [(os.path.basename(path), n, nr) for n, nr in CONST.findall(block.group(1))]
    return out


def check_messages(root):
    rows = message_rows(root)
    defined = {nr for nr, _ in rows}
    failures = [f'message {nr}: text longer than 73' for nr, text in rows if len(text) > 73]
    used = set()
    production = ''
    for path in files(os.path.join(root, 'src'), ('.abap',)):
        code = strip_comments(read(path))
        for nr in RAISED.findall(code):
            if nr not in defined:
                failures.append(f'{os.path.basename(path)}: message {nr} of ZCA_OPS is not defined')
        if '.testclasses.' not in path and not path.endswith('types.intf.abap'):
            production += code + '\n'
            used |= set(RAISED.findall(code))
    for base, name, nr in message_constants(root):
        if nr not in defined:
            failures.append(f'{base}: gc_msg-{name} = {nr} is not a message of ZCA_OPS')
        if re.search(r'gc_msg-' + name + r'\b', production, re.I):
            used.add(nr)
    for nr in sorted(defined - used - {'000'}):
        failures.append(f'message {nr}: raised by no production code')
    return failures


def check_abapgit(root):
    sys.path.insert(0, os.path.join(root, 'tools'))
    import abapgit_serialize  # noqa: E402
    stage, _ = abapgit_serialize.build(root)
    return list(stage.problems) + [f'{f}: out of date (run tools/abapgit_serialize.py)' for f in stage.changed()]


def check_test_path(root):
    register = {}
    path = os.path.join(root, 'tools', 'test_path_register.csv')
    if os.path.exists(path):
        import csv
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


def check_param_definitions(root):
    sys.path.insert(0, os.path.join(root, 'tools'))
    import param_definitions  # noqa: E402
    return param_definitions.failures(root)


CONSUMER = re.compile(r'\b(zcd_\w+|zcl_cd_\w+|zif_cd_\w+|zcx_cd_\w+)', re.I)
MOVED_LINE = re.compile(r'^\*& \d{4}-\d{2}-\d{2} \| Moved from Z(CL|IF|CX)?_?CD_\w+ to the reusable framework ZCA_OPS')


def check_layering(root):
    failures = []
    for path in files(os.path.join(root, 'src'), ('.abap', '.asddls', '.asdcls', '.asddlxs', '.asbdef',
                                                  '.srvdsrv', '.xml')):
        for no, line in enumerate(read(path).splitlines(), start=1):
            if MOVED_LINE.match(line):
                continue
            m = CONSUMER.search(line)
            if m:
                failures.append(f'{os.path.relpath(path, root)}:{no}: {m.group(1)}')
    return failures


def customer_terms(root):
    path = os.path.join(root, 'config', 'customer_terms.txt')
    terms = []
    for line in read(path).splitlines():
        line = line.split('#')[0].strip()
        if line:
            terms.append(line)
    return terms


def check_customer_terms(root):
    pattern = re.compile(r'(?<![A-Za-z0-9])(' + '|'.join(re.escape(t) for t in customer_terms(root)) +
                         r')(?![A-Za-z0-9])', re.I)
    cfg = json.loads(read(os.path.join(root, 'config', 'repository.json')))
    targets = list(files(os.path.join(root, 'src'), ('.abap', '.asddls', '.asdcls', '.asddlxs', '.asbdef',
                                                     '.srvdsrv', '.xml')))
    targets += list(files(os.path.join(root, 'docs', 'text_elements'), ('.md',)))
    targets.append(os.path.join(root, cfg['message_class']['source']))
    failures = []
    for path in targets:
        for no, line in enumerate(read(path).splitlines(), start=1):
            if MOVED_LINE.match(line):
                continue
            m = pattern.search(line)
            if m:
                failures.append(f'{os.path.relpath(path, root)}:{no}: {m.group(1)}')
    return failures


CHECKS = [
    ('name_lengths', check_name_lengths),
    ('artifact_header', check_artifact_header),
    ('pcre_only', check_pcre_only),
    ('no_cp_patterns', check_no_cp),
    ('no_inline_texts', check_no_inline_texts),
    ('no_select_star', check_no_select_star),
    ('final_classes', check_final),
    ('test_classes', check_test_classes),
    ('messages', check_messages),
    ('abapgit_up_to_date', check_abapgit),
    ('test_path', check_test_path),
    ('param_definitions', check_param_definitions),
    ('layering', check_layering),
    ('customer_terms', check_customer_terms),
]


def run(root=ROOT):
    return {name: fn(root) for name, fn in CHECKS}


def main():
    results = run()
    failed = 0
    for name, failures in results.items():
        print(f'{"PASS" if not failures else "FAIL"}  {name}')
        for f in failures[:50]:
            print(f'      {f}')
        failed += bool(failures)
    print(f'{len(results) - failed}/{len(results)} checks passed')
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
