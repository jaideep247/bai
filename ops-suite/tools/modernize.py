#!/usr/bin/env python3
"""Mechanical modernization of the ops suite - idempotent, safe to re-run after every merge.

Phases (each one changes nothing when its target state is already reached):
  tables      Transparent tables longer than 16 characters (SAP limit) are renamed in every
              text file of the suite (DDL file names and content, abapGit TABL XML, ABAP SQL,
              CDS, tools/rap_generate.py spec, configuration seeds, docs). Token-boundary
              matching, case kept (ZCD_OPS_ALERT_CHN / zcd_ops_alert_chn).
  exceptions  Caught exceptions are named lx_error: CATCH ... INTO DATA(lx) and every use of
              lx inside that CATCH block (token boundary, never inside literals or comments).
  naming      Local helper classes FOR TESTING named LCL_* in test includes become LTD_*
              (house rule: local classes LCL_ / LHC_ / LSC_ / LTD_, test classes LTC_ / LTD_).
  quickfix    abaplint quick fixes of the rules whose fix is a statement-local, behaviour-
              neutral rewrite (QUICKFIX_RULES); only with --abaplint <binary>.

Everything else the modern-syntax rules of abaplint.json report (they are enabled there) is a
manual change; after a merge run this script, then abaplint, and fix what is left by hand.

Usage (from ops-suite/):
  python3 tools/modernize.py [--abaplint <abaplint binary>] [--root <suite folder>] [--check]
                             [--phases tables,exceptions,naming,quickfix]
--check: report what would change, change nothing, exit 1 when something would change.
--phases: run only these phases (default: all; quickfix only with --abaplint).
"""
import argparse
import difflib
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

#: (d) transparent tables above 16 characters -> new name (16 at most)
TABLE_RENAMES = {
    'zcd_ops_alert_chn': 'zca_ops_alchn',
    'zcd_ops_alert_log': 'zca_ops_allog',
    'zcd_ops_alert_rule': 'zca_ops_alrule',
}
#: (e) name of a caught exception
OLD_EXCEPTION, NEW_EXCEPTION = 'lx', 'lx_error'
#: (a) rules whose abaplint quick fix is applied automatically
QUICKFIX_RULES = ['prefer_insert_into_table', 'prefer_raise_exception_new', 'unnecessary_return',
                  'prefer_is_not', 'unnecessary_chaining']

TEXT_EXT = ('.abap', '.xml', '.ddl', '.asddls', '.asddlxs', '.asdcls', '.asbdef', '.srvdsrv',
            '.md', '.csv', '.json', '.py', '.txt', '.yml')
#: never rewritten: this script and its fixture test name the old values on purpose
SELF = {os.path.join('tools', 'modernize.py'), os.path.join('tools', 'tests', 'test_modernize.py')}
SKIP_DIRS = {'.git', 'node_modules', '__pycache__', 'deps'}
WORD = r'[A-Za-z0-9_]'


def text_files(root):
    for folder, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in SKIP_DIRS)
        for name in sorted(files):
            path = os.path.join(folder, name)
            if name.endswith(TEXT_EXT) and os.path.relpath(path, root) not in SELF:
                yield path


def read(path):
    with open(path, encoding='utf-8') as fh:
        return fh.read()


def write(path, text):
    with open(path, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write(text)


# ------------------------------------------------------------------ (d) table renames
def rename_tables(root, check):
    changes = []
    patterns = []
    for old, new in TABLE_RENAMES.items():
        for o, n in ((old, new), (old.upper(), new.upper())):
            patterns.append((re.compile(rf'(?<!{WORD}){re.escape(o)}(?!{WORD})'), n))
    for path in list(text_files(root)):
        text = read(path)
        new_text = text
        for pattern, replacement in patterns:
            new_text = pattern.sub(replacement, new_text)
        base = os.path.basename(path)
        new_base = base
        for old, new in TABLE_RENAMES.items():
            if base.startswith(old + '.'):
                new_base = new + base[len(old):]
        if new_text != text or new_base != base:
            changes.append(os.path.relpath(path, root) + (f' -> {new_base}' if new_base != base else ''))
            if not check:
                target = os.path.join(os.path.dirname(path), new_base)
                write(target, new_text)
                if target != path:
                    os.remove(path)
    return changes


# ------------------------------------------------------------------ helpers for ABAP code
def split_code(line):
    """(code, rest): rest is the comment part; literals stay in code but are masked by mask()."""
    if line.lstrip().startswith('*'):
        return '', line
    in_lit = None
    for i, ch in enumerate(line):
        if in_lit:
            if ch == in_lit:
                in_lit = None
        elif ch in "'`|":
            in_lit = ch
        elif ch == '"':
            return line[:i], line[i:]
    return line, ''


def mask(code):
    """Same length as code, literal contents replaced by spaces (string-template embeddings kept)."""
    out, in_lit, depth = [], None, 0
    for ch in code:
        if in_lit == '|' and ch == '{':
            depth += 1
            out.append(ch)
            continue
        if in_lit == '|' and ch == '}' and depth:
            depth -= 1
            out.append(ch)
            continue
        if in_lit and not (in_lit == '|' and depth):
            if ch == in_lit:
                in_lit = None
                out.append(ch)
            else:
                out.append(' ')
            continue
        if ch in "'`|":
            in_lit = ch
        out.append(ch)
    return ''.join(out)


def replace_tokens(line, old, new):
    """Replace the variable old by new in the code part of one line (not after -, ~, >)."""
    code, comment = split_code(line)
    masked = mask(code)
    pattern = re.compile(rf'(?<![A-Za-z0-9_\-~>]){re.escape(old)}(?![A-Za-z0-9_])', re.I)
    parts, last = [], 0
    for m in pattern.finditer(masked):
        parts.append(code[last:m.start()] + new)
        last = m.end()
    return ''.join(parts) + code[last:] + comment


def statement_keyword(line):
    code = mask(split_code(line)[0]).strip().upper()
    return code.split(' ', 1)[0].rstrip('.') if code else ''


# ------------------------------------------------------------------ (e) caught exceptions
CATCH_INTO = re.compile(rf'\bINTO\s+DATA\(\s*{OLD_EXCEPTION}\s*\)', re.I)


def rename_caught_exceptions(root, check):
    changes, problems = [], []
    for path in text_files(root):
        if not path.endswith('.abap'):
            continue
        lines = read(path).splitlines(keepends=True)
        new_lines = list(lines)
        i = 0
        while i < len(lines):
            if statement_keyword(lines[i]) == 'CATCH' and CATCH_INTO.search(mask(split_code(lines[i])[0])):
                # CATCH block: to the next CATCH / CLEANUP / ENDTRY of the same TRY
                depth, j = 0, i
                while j < len(lines):
                    kw = statement_keyword(lines[j])
                    if j > i and depth == 0 and kw in ('CATCH', 'CLEANUP', 'ENDTRY'):
                        break
                    if kw == 'TRY':
                        depth += 1
                    elif kw == 'ENDTRY':
                        depth -= 1
                    new_lines[j] = replace_tokens(new_lines[j], OLD_EXCEPTION, NEW_EXCEPTION)
                    j += 1
                i = j
                continue
            i += 1
        if new_lines != lines:
            text = ''.join(new_lines)
            # a use outside its CATCH block (inline declarations are method-wide) is left for review
            if re.search(rf'(?<![A-Za-z0-9_\-~>]){OLD_EXCEPTION}->', ''.join(mask(split_code(l)[0]) for l in new_lines)):
                problems.append(f'{os.path.relpath(path, root)}: {OLD_EXCEPTION} used outside its CATCH block')
            changes.append(os.path.relpath(path, root))
            if not check:
                write(path, text)
    return changes, problems


# ------------------------------------------------------------------ (f) local test helper classes
LOCAL_TEST_HELPER = re.compile(r'^\s*CLASS\s+(lcl_\w+)\s+DEFINITION\b[^.]*\bFOR\s+TESTING\b', re.I | re.M)


def rename_test_helpers(root, check):
    changes = []
    for path in text_files(root):
        if not path.endswith('.testclasses.abap'):
            continue
        text = read(path)
        names = {m.group(1).lower() for m in LOCAL_TEST_HELPER.finditer(text)}
        if not names:
            continue
        lines = text.splitlines(keepends=True)
        for name in sorted(names):
            new_name = 'ltd_' + name[len('lcl_'):]
            if re.search(rf'(?<![A-Za-z0-9_]){new_name}(?![A-Za-z0-9_])', text, re.I):
                raise SystemExit(f'{path}: {new_name} already exists - rename {name} by hand')
            lines = [replace_tokens(l, name, new_name) for l in lines]
        new_text = ''.join(lines)
        if new_text != text:
            changes.append(os.path.relpath(path, root))
            if not check:
                write(path, new_text)
    return changes


# ------------------------------------------------------------------ (a) abaplint quick fixes
def apply_quickfixes(root, abaplint, check):
    with open(os.path.join(root, 'abaplint.json'), encoding='utf-8') as fh:
        config = json.load(fh)
    config['rules'] = {rule: config['rules'].get(rule, True) for rule in QUICKFIX_RULES}
    config['rules'].update({'parser_error': True, 'check_syntax': True})
    handle, cfg = tempfile.mkstemp(suffix='.json', dir=root, prefix='.modernize_')
    os.close(handle)
    try:
        with open(cfg, 'w', encoding='utf-8') as fh:
            json.dump(config, fh, indent=2)
        before = {p: read(p) for p in text_files(os.path.join(root, 'src'))}
        args = [abaplint, os.path.basename(cfg)] + ([] if check else ['--fix'])
        out = subprocess.run(args, cwd=root, capture_output=True, text=True).stdout
    finally:
        os.remove(cfg)
    if check:
        return [l.split('[')[0] for l in out.splitlines() if l.rstrip().endswith('[E]')]
    changes = []
    for path, old in before.items():
        new = read(path) if os.path.exists(path) else old
        if new != old:
            cleaned = drop_emptied_lines(old, new)
            if cleaned != new:
                write(path, cleaned)
            changes.append(os.path.relpath(path, root))
    return changes


def drop_emptied_lines(old, new):
    """A quick fix that removes a statement (RETURN.) leaves an empty line: drop it."""
    old_lines, new_lines = old.splitlines(keepends=True), new.splitlines(keepends=True)
    out = []
    matcher = difflib.SequenceMatcher(a=old_lines, b=new_lines, autojunk=False)
    for op, a1, a2, b1, b2 in matcher.get_opcodes():
        segment = new_lines[b1:b2]
        if op == 'replace' and all(not l.strip() for l in segment) and all(l.strip() for l in old_lines[a1:a2]):
            continue
        out.extend(segment)
    return ''.join(out)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument('--abaplint', help='abaplint binary (enables the quick-fix phase)')
    parser.add_argument('--root', default=ROOT, help='suite folder (default: this ops-suite)')
    parser.add_argument('--check', action='store_true', help='report only, change nothing')
    parser.add_argument('--phases', default='tables,exceptions,naming,quickfix', help='comma list of phases')
    args = parser.parse_args(argv)
    root = os.path.abspath(args.root)
    phases = {p.strip() for p in args.phases.split(',') if p.strip()}
    unknown = phases - {'tables', 'exceptions', 'naming', 'quickfix'}
    if unknown:
        parser.error(f'unknown phase(s): {", ".join(sorted(unknown))}')

    report, problems = {}, []
    if 'tables' in phases:
        report['tables'] = rename_tables(root, args.check)
    if 'exceptions' in phases:
        report['exceptions'], problems = rename_caught_exceptions(root, args.check)
    if 'naming' in phases:
        report['naming'] = rename_test_helpers(root, args.check)
    if 'quickfix' in phases and args.abaplint:
        report['quickfix'] = apply_quickfixes(root, args.abaplint, args.check)
    for phase, changed in report.items():
        print(f'{phase}: {len(changed)} file(s){" would change" if args.check else " changed"}')
        for item in changed:
            print(f'  {item}')
    for problem in problems:
        print(f'REVIEW {problem}')
    if problems:
        return 2
    return 1 if args.check and any(report.values()) else 0


if __name__ == '__main__':
    sys.exit(main())
