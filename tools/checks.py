#!/usr/bin/env python3
"""House checks of the parameter framework that abaplint does not cover.

Offline evidence of house-rule compliance only - not SAP activation, ATC or ABAP Unit.
Usage:  python3 tools/checks.py          (exit 1 when a check fails)

Checks
  name_lengths        object names <= 30, transparent tables <= 16, message class <= 20,
                      authorization fields / objects <= 10, test methods <= 30, short texts <= 60
  artifact_header     every ABAP source starts with '*& Artifact: <file name>' and has
                      Purpose and Modification log lines
  pcre_only           no POSIX regular expressions (regex =, FIND/REPLACE ... REGEX, CREATE_POSIX)
  no_cp_patterns      no CP / NP comparisons and no option 'CP' / 'NP'
  no_inline_texts     no user text as a literal: MESSAGE with a text literal, or a sentence-like
                      literal outside declarations (test classes may use literals in msg = )
  no_select_star      explicit field lists in every SELECT
  final_classes       every public concrete class is FINAL
  test_classes        every test class has RISK LEVEL HARMLESS and DURATION SHORT
  messages            every ZIF_CA_PARAM_TYPES=>GC_MSG constant has a message row with the same
                      number and name; texts <= 73
  neutral_wording     no file names an assistant tool or vendor
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


def check_no_inline_texts(root):
    failures = []
    for path in files(os.path.join(root, 'src'), ('.abap',)):
        base = os.path.basename(path)
        test = '.testclasses.' in base
        for stmt in statements(strip_comments(read(path))):
            if re.search(r"\bMESSAGE\s+['`]", stmt, re.I):
                failures.append(f'{base}: MESSAGE with a text literal')
                continue
            if DECLARATION.match(stmt):
                continue
            for m in SENTENCE.finditer(stmt):
                prefix = stmt[:m.start()]
                if test and re.search(r'\b(msg|quit)\s*=\s*$', prefix, re.I):
                    continue
                failures.append(f'{base}: {m.group(0)[:60]}')
    return failures


def check_no_select_star(root):
    return [os.path.basename(p) for p in files(os.path.join(root, 'src'), ('.abap',))
            if re.search(r'\bSELECT\s+(SINGLE\s+)?\*', strip_comments(read(p)), re.I)]


def check_final(root):
    failures = []
    for path in files(os.path.join(root, 'src'), ('.clas.abap',)):
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


def check_messages(root):
    cfg = json.loads(read(os.path.join(root, 'config', 'repository.json')))
    rows = re.findall(r'^\| (\d{3}) \| (\w+) \| (.*?) \|$', read(os.path.join(root, cfg['message_class']['source'])), re.M)
    by_name = {name: nr for nr, name, _ in rows}
    failures = [f'message {nr}: text longer than 73' for nr, _, text in rows if len(text) > 73]
    types = os.path.join(root, 'src', 'zif_ca_param_types.intf.abap')
    if not os.path.exists(types):
        return failures
    block = re.search(r'BEGIN OF gc_msg,(.*?)END OF gc_msg', read(types), re.S | re.I)
    if not block:
        return failures + ['ZIF_CA_PARAM_TYPES: constant structure gc_msg missing']
    for name, nr in re.findall(r'(\w+)\s+TYPE\s+symsgno\s+VALUE\s+\'(\d{3})\'', block.group(1), re.I):
        if by_name.get(name.lower()) != nr:
            failures.append(f'gc_msg-{name} = {nr}: no message row "| {nr} | {name.lower()} |"')
    return failures


def _words():
    # stored reversed so that this file does not contain the words it looks for
    return [w[::-1] for w in ('edualc', 'ciporhtna', 'tpgtahc', 'ianepo', 'tolipoc', 'inimeg', 'mll')]


def check_neutral_wording(root):
    pattern = re.compile(r'\b(' + '|'.join(_words()) + r')\b|\bai[- ](generated|assistant)\b|\bgenerated by ai\b', re.I)
    failures = []
    for path in files(root, ('.abap', '.xml', '.md', '.py', '.json', '.yml', '.ddl', '.asddls', '.asddlxs',
                             '.asbdef', '.srvdsrv', '.asdcls', '.txt', '.gitignore')):
        for no, line in enumerate(read(path).splitlines(), start=1):
            if pattern.search(line):
                failures.append(f'{os.path.relpath(path, root)}:{no}')
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
    ('neutral_wording', check_neutral_wording),
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
