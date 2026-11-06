#!/usr/bin/env python3
"""
Artifact: tools/literal_scan.py
Purpose:  Inventory of every literal in the suite's ABAP production code (test includes
          excluded) and its classification:
            1 TEXT   user-facing text (finding / run / alert messages, labels, output)
            2 VALUE  technical value (check codes, statuses, names, defaults, thresholds)
            3 OK     legitimate (CONSTANTS / types interfaces, separators, syntax-required
                     names such as CALL FUNCTION / AUTHORITY-CHECK, allow-listed lines)
          Used by tools/portable_checks.py (check no_inline_texts) and to write
          docs/Hardcoding_Inventory.md.
Usage:    python3 tools/literal_scan.py            -> summary per category
          python3 tools/literal_scan.py --list     -> every category 1/2 literal
          python3 tools/literal_scan.py --md FILE  -> write the inventory document
Modification log:
2026-11-06 | Initial version (phase 5: remove hardcoding).
2026-11-06 | Inventory keeps the phase-5 baseline and breaks legitimate literals down by reason and area.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, 'src')
ALLOW = os.path.join(ROOT, 'tools', 'literal_allowlist.txt')

# Statement starts whose literals are declarations (the place where values belong)
DECL = re.compile(r'^\s*(CONSTANTS|TYPES|DATA|CLASS-DATA|STATICS|PARAMETERS|SELECT-OPTIONS|'
                  r'SELECTION-SCREEN)\b', re.I)
# Syntax that requires a literal or a name: kept, but listed as legitimate
SYNTAX = [
    re.compile(r"CALL\s+FUNCTION\s*$", re.I),
    re.compile(r"AUTHORITY-CHECK\s+OBJECT\s*$", re.I),
    re.compile(r"\bID\s*$", re.I),
    re.compile(r"\bCALL\s+TRANSFORMATION\s*$", re.I),
    re.compile(r"\bSET\s+PF-STATUS\s*$", re.I),
    re.compile(r"\bSET\s+TITLEBAR\s*$", re.I),
    re.compile(r"\bTYPE\s*$", re.I),            # MESSAGE ... TYPE 'E'
    re.compile(r"\bDISPLAY\s+LIKE\s*$", re.I),
    re.compile(r"\bFORMAT\s*$", re.I),
    re.compile(r"DELETING\s+(LEADING|TRAILING)\s*$", re.I),
]
SEPARATOR = re.compile(r"^[\s,;:/\-–()\[\]\.=<>|#%+*&\x01]*$")
WORDS = re.compile(r"[A-Za-z]{2,}[a-z][A-Za-z]*\s+\S|[a-z]{3,}")


def load_allow():
    entries = []
    if os.path.exists(ALLOW):
        for line in open(ALLOW, encoding='utf-8'):
            if not line.strip() or line.lstrip().startswith('#'):
                continue
            body = line.rstrip('\n')
            if '   #' in body:
                body = body[:body.index('   #')]
            path, _, pattern = body.partition(' ')
            pattern = pattern.rstrip() if pattern.strip() else ''
            # a pattern written with a leading blank keeps one leading blank
            if pattern.startswith('  '):
                pattern = pattern[1:]
            if pattern:
                entries.append((path.strip(), pattern))
    return entries


def statements(text):
    """Yield (line_no, statement_text, [(literal, kind, line_no, prefix)]) per ABAP statement."""
    stmt, lits, start = '', [], None
    for no, raw in enumerate(text.split('\n'), 1):
        if raw.lstrip().startswith('*'):
            continue
        i, n = 0, len(raw)
        if start is None:
            start = no
        while i < n:
            c = raw[i]
            if c == '"':
                break
            if c in "'`":
                j = i + 1
                while j < n:
                    if raw[j] == c and j + 1 < n and raw[j + 1] == c:
                        j += 2
                        continue
                    if raw[j] == c:
                        break
                    j += 1
                lits.append((raw[i + 1:j], c, no, stmt))
                stmt += c + c
                i = j + 1
                continue
            if c == '|':
                j, depth, buf = i + 1, 0, ''
                while j < n:
                    d = raw[j]
                    if depth == 0 and d == '\\' and j + 1 < n:
                        # \n \r \t are control characters, not letters
                        buf += '\x01' if raw[j + 1] in 'nrt' else raw[j + 1]
                        j += 2
                        continue
                    if d == '{':
                        if depth == 0 and buf:
                            lits.append((buf, '|', no, stmt))
                            buf = ''
                        depth += 1
                    elif d == '}':
                        depth -= 1
                    elif d == '|' and depth == 0:
                        break
                    elif depth == 0:
                        buf += d
                    j += 1
                if buf:
                    lits.append((buf, '|', no, stmt))
                stmt += '||'
                i = j + 1
                continue
            stmt += c
            if c == '.':
                yield start, stmt, lits
                stmt, lits, start = '', [], None
            i += 1
        stmt += ' '
    if stmt.strip():
        yield start, stmt, lits


def classify(path, stmt, lit, kind, prefix, allow):
    rel = os.path.relpath(path, ROOT)
    name = os.path.basename(path)
    if re.match(r'zif_cd_\w*types\.intf\.abap$', name):
        return 3, 'types interface'
    head = stmt.lstrip()
    if DECL.match(head) or re.match(r'^\s*(BEGIN|END)\s+OF\b', head, re.I):
        return 3, 'declaration'
    for path_pat, pattern in allow:
        if (path_pat == '*' or rel.endswith(path_pat)) and pattern and pattern in lit:
            return 3, 'allow-list'
    if any(rx.search(prefix.rstrip()) for rx in SYNTAX):
        return 3, 'syntax'
    if lit == '' or SEPARATOR.match(lit):
        return 3, 'separator'
    # range tables: SIGN / OPTION values are ABAP semantics (I/E, EQ/CP/BT ...)
    if re.search(r'\b(sign|option)\s*=\s*(COND #\(.*)?$', prefix, re.I) and re.fullmatch(r'[IE]|EQ|NE|CP|NP|BT|NB|GT|GE|LT|LE', lit):
        return 3, 'range semantics'
    # names of the suite's own repository objects (tables, interfaces, classes)
    if re.fullmatch(r'(ZCD_|ZIF_CD_|ZCL_CD_|ZCX_CD_)[A-Z0-9_]*', lit):
        return 3, 'repository object name'
    if kind == '|' or WORDS.search(lit):
        return (1, 'text') if re.search(r'[A-Za-z]', lit) else (3, 'format')
    return 2, 'value'


def scan():
    allow = load_allow()
    rows = []
    for d, _, files in os.walk(SRC):
        for f in sorted(files):
            if not f.endswith('.abap') or 'testclasses' in f:
                continue
            p = os.path.join(d, f)
            text = open(p, encoding='utf-8').read()
            for _, stmt, lits in statements(text):
                for lit, kind, no, prefix in lits:
                    cat, why = classify(p, stmt, lit, kind, prefix, allow)
                    rows.append((os.path.relpath(p, ROOT), no, cat, why, kind, lit))
    return rows


# Baseline of the phase-5 clean-up (commit f10b8f0), same scanner and allow-list
BASELINE = {'commit': 'f10b8f0', 'total': 1909, 1: 516, 2: 274, 3: 1119}
REASONS = {'types interface': 'Named constants in the area types interfaces',
           'declaration': 'CONSTANTS / TYPES / DATA / PARAMETERS declarations',
           'allow-list': 'Allow-listed lines (wire formats, SQL fragments - `tools/literal_allowlist.txt`)',
           'syntax': 'Names SAP syntax requires (CALL FUNCTION, AUTHORITY-CHECK, MESSAGE TYPE)',
           'separator': 'Separators',
           'range semantics': 'Range sign / option values',
           'repository object name': 'Repository object names',
           'format': 'Format characters (no letters)'}


def main():
    rows = scan()
    if '--list' in sys.argv:
        for r in rows:
            if r[2] in (1, 2):
                print(f'{r[0]}:{r[1]} [{r[2]} {r[3]}] {r[4]}{r[5]}{r[4]}')
    cats = {1: 0, 2: 0, 3: 0}
    for r in rows:
        cats[r[2]] += 1
    print(f'literals: {len(rows)}  text(1)={cats[1]}  value(2)={cats[2]}  legitimate(3)={cats[3]}')
    if '--md' in sys.argv:
        target = sys.argv[sys.argv.index('--md') + 1]
        per = {}
        for r in rows:
            per.setdefault(r[0], {1: 0, 2: 0, 3: 0})[r[2]] += 1
        before = sys.argv[sys.argv.index('--before') + 1] if '--before' in sys.argv else ''
        with open(target, 'w', encoding='utf-8') as fh:
            fh.write('# Hardcoding inventory (generated by tools/literal_scan.py)\n\n')
            fh.write('> **First principle:** a value the business may change is configuration; a text a user reads is a '
                     'text element; a value fixed by a standard or by SAP syntax is a named constant.\n\n')
            b = BASELINE
            fh.write('## Before / after\n\n'
                     f'| | Before ({b["commit"]}) | Now |\n|---|---|---|\n'
                     f'| Literals in production ABAP | {b["total"]} | {len(rows)} |\n'
                     f'| User-facing text (1) | {b[1]} | {cats[1]} |\n'
                     f'| Technical value (2) | {b[2]} | {cats[2]} |\n'
                     f'| Legitimate (3) | {b[3]} | {cats[3]} |\n\n'
                     'Same scanner and allow-list for both columns. Texts live in message class ZCD_OPS (built only '
                     'through `ZCL_CD_OPS_UTIL=>TEXT( )`) or in text symbols; values in named constants of the area '
                     'types interfaces, class constants, the generated `lif_c` interfaces of the configuration apps, '
                     'or SAP constants. The portable check `no_inline_texts` keeps categories 1 and 2 at zero; the '
                     'total grows with new code, not with hardcoding.\n\n')
            fh.write(f'## Now\n\nLiterals in production ABAP: **{len(rows)}** — user-facing text (1): **{cats[1]}**, '
                     f'technical value (2): **{cats[2]}**, legitimate (3): **{cats[3]}**.\n\n')
            fh.write('Category 3 = declarations (CONSTANTS / TYPES / DATA / PARAMETERS / types interfaces), '
                     'separators and format characters, names SAP syntax requires as literals (CALL FUNCTION, '
                     'AUTHORITY-CHECK OBJECT / ID, MESSAGE TYPE), and allow-listed lines (`tools/literal_allowlist.txt`, '
                     'each with its reason).\n\n')
            by_reason = {}
            by_area = {}
            for r in rows:
                if r[2] == 3:
                    by_reason[r[3]] = by_reason.get(r[3], 0) + 1
                    area = r[0].split(os.sep)[1].upper() if r[0].count(os.sep) >= 2 else '-'
                    by_area[area] = by_area.get(area, 0) + 1
            fh.write('### Legitimate literals by reason\n\n| Reason | Literals |\n|---|---|\n')
            for why in sorted(by_reason, key=lambda k: -by_reason[k]):
                fh.write(f'| {REASONS.get(why, why)} | {by_reason[why]} |\n')
            fh.write('\n### Legitimate literals by payment engine area\n\n| Area (`src/`) | Literals |\n|---|---|\n')
            for area in sorted(by_area):
                fh.write(f'| {area} | {by_area[area]} |\n')
            flagged = [f for f in sorted(per) if per[f][1] or per[f][2]]
            fh.write('\n### Files with category 1 or 2 literals\n\n')
            if flagged:
                fh.write('| File | Text (1) | Value (2) | Legitimate (3) |\n|---|---|---|---|\n')
                for f in flagged:
                    c = per[f]
                    fh.write(f'| `{f}` | {c[1]} | {c[2]} | {c[3]} |\n')
            else:
                fh.write('None - every file is clean.\n')
            left = [r for r in rows if r[2] in (1, 2)]
            if left:
                fh.write('\n## Remaining category 1 / 2 literals\n\n| File:line | Category | Literal |\n|---|---|---|\n')
                for r in left:
                    fh.write(f'| `{r[0]}:{r[1]}` | {r[2]} | `{r[5][:60]}` |\n')
    return cats


if __name__ == '__main__':
    main()
