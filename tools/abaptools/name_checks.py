#!/usr/bin/env python3
"""Name and pattern checks of an ABAP component folder (portable, no SAP system): SAP length
limits, the house method naming rule, PCRE only and no CP / NP patterns. Shared engine
(tools/abaptools), used by every component's check runner (ops-suite/tools/portable_checks.py,
ops-framework/tools/checks.py, param-framework/tools/checks.py: checks name_lengths, method_names,
pcre_only, no_cp_patterns, no_inline_in_call).

Limits (SAP): object names, CDS entities, DDLS / SRVD / DCLS names, methods, attributes,
types, local classes and local data 30; transparent tables 16; message classes 20; table
field names 30. Methods: snake_case, never a data prefix (lv_, it_, mo_, gc_, ...), 30 at most
(test methods included).

Inline declarations (inline_in_call_failures, check no_inline_in_call of every runner): no DATA( ... ) /
FINAL( ... ) after IMPORTING of a method call in a functional position (right side of an assignment, a
condition, an operand of another call) - abaplint accepts it, the compiler of the reference system
(S/4HANA 2025) refuses it. A standalone call (meth( IMPORTING e = DATA(x) ).) and CALL METHOD stay allowed.

Modification log:
2026-11-10 | Moved to the shared tools (tools/abaptools); pcre_only also finds a FIND / REPLACE ... REGEX
           | statement that spans lines (the frameworks' statement check).
2026-11-16 | inline_in_call_failures (house rule no_inline_in_call: the reference system's compiler refuses an
           | inline declaration in IMPORTING of a functional call).
"""
import os
import re

LIMIT = 30
TABLE_LIMIT = 16
MSAG_LIMIT = 20
SNAKE = re.compile(r'^[a-z][a-z0-9_]*$')
#: data prefixes a method name must not start with (house naming convention)
#: (is_ starts a predicate method - is_valid( ), Clean ABAP - and is allowed)
DATA_PREFIX = re.compile(r'^(?!is_)(?:[lgm][vstorxc]|[iecr][vstor]|lc|mc|gc|ty|tt|p|s|so)_', re.I)
DECLARATION = re.compile(r'^\s*(?:CLASS-)?(METHODS|DATA|CONSTANTS|TYPES|EVENTS|CLASS-EVENTS)\b\s*:?\s*(.*)$', re.I)
CLASS_DEF = re.compile(r'^\s*CLASS\s+([\w/]+)\s+DEFINITION\b', re.I)
INTERFACE_DEF = re.compile(r'^\s*INTERFACE\s+([\w/]+)\b(?!\s+LOAD)', re.I)
INLINE = re.compile(r'\b(?:DATA|FIELD-SYMBOL|FINAL)\(\s*(<?[\w/]+>?)\s*\)', re.I)
BEGIN_OF = re.compile(r'\bBEGIN\s+OF\s+([\w/]+)', re.I)
CDS_ENTITY = re.compile(r'\bdefine\s+(?:root\s+)?(?:view\s+entity|view|table\s+function|abstract\s+entity|'
                        r'custom\s+entity|transient\s+view\s+entity|role|service)\s+([\w/]+)', re.I)
DDL_TABLE = re.compile(r'\bdefine\s+table\s+(\w+)', re.I)
DDL_FIELD = re.compile(r'^\s*(?:key\s+)?([a-z_][\w]*)\s*:', re.I | re.M)


def _walk(root, *exts):
    for folder, dirs, files in os.walk(root):
        dirs[:] = sorted(d for d in dirs if d not in ('.git', 'node_modules', '__pycache__'))
        for name in sorted(files):
            if name.endswith(exts):
                yield os.path.join(folder, name)


def _read(path):
    with open(path, encoding='utf-8') as fh:
        return fh.read()


def _code_lines(text):
    """ABAP lines without full-line comments, end-of-line comments and literal contents."""
    for no, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith('*'):
            continue
        out, in_lit = [], None
        for ch in line:
            if in_lit:
                if ch == in_lit:
                    in_lit = None
                continue
            if ch in "'`|":
                in_lit = ch
                continue
            if ch == '"':
                break
            out.append(ch)
        yield no, ''.join(out)


def _declared_names(text):
    """(line, kind, name) of declarations: methods, data, constants, types, events, local
    classes / interfaces, structure names and inline declarations. Chains (:) are followed
    to the terminating period; components of a chained declaration are taken after commas."""
    chain = None
    for no, code in _code_lines(text):
        for m in INLINE.finditer(code):
            yield no, 'local', m.group(1).strip('<>')
        for m in BEGIN_OF.finditer(code):
            yield no, 'type', m.group(1)
        m = CLASS_DEF.match(code) or INTERFACE_DEF.match(code)
        if m:
            yield no, 'class', m.group(1)
        if chain:
            for part in code.split(','):
                name = re.match(r'^\s*(?:BEGIN\s+OF\s+|END\s+OF\s+)?([\w/]+)', part)
                if name and name.group(1).upper() not in ('END', 'BEGIN'):
                    yield no, chain, name.group(1)
            if code.rstrip().endswith('.'):
                chain = None
            continue
        m = DECLARATION.match(code)
        if not m:
            continue
        kind = m.group(1).upper()
        rest = m.group(2)
        first = re.match(r'^(?:BEGIN\s+OF\s+|END\s+OF\s+)?([\w/~]+)', rest)
        if first and not re.match(r'^(BEGIN|END)$', first.group(1), re.I):
            yield no, kind.lower(), first.group(1)
        if re.match(rf'^\s*(?:CLASS-)?{kind}\s*:', code, re.I) and not code.rstrip().endswith('.'):
            chain = kind.lower()
        elif re.match(rf'^\s*(?:CLASS-)?{kind}\s*:', code, re.I):
            for part in rest.split(',')[1:]:
                name = re.match(r'^\s*([\w/]+)', part)
                if name:
                    yield no, kind.lower(), name.group(1)


def name_length_failures(root):
    failures = []
    src = os.path.join(root, 'src')
    for path in _walk(src, '.abap', '.xml', '.asddls', '.asddlxs', '.asdcls', '.asbdef', '.srvdsrv'):
        rel = os.path.relpath(path, root)
        base = os.path.basename(path)
        obj = base.split('.')[0]
        limit = MSAG_LIMIT if base.endswith('.msag.xml') else LIMIT
        if len(obj) > limit:
            failures.append(f'{rel}: object name {obj} ({len(obj)} > {limit})')
        if base.endswith(('.asddls', '.asdcls', '.srvdsrv')):
            for m in CDS_ENTITY.finditer(_read(path)):
                if len(m.group(1)) > LIMIT:
                    failures.append(f'{rel}: CDS name {m.group(1)} ({len(m.group(1))} > {LIMIT})')
        if base.endswith('.abap'):
            for no, kind, name in _declared_names(_read(path)):
                name = name.split('~')[-1]
                if len(name) > LIMIT:
                    failures.append(f'{rel}:{no} {kind} {name} ({len(name)} > {LIMIT})')
    for folder in ('ddic', 'cds'):
        for path in _walk(os.path.join(root, folder), '.ddl', '.asddls'):
            rel = os.path.relpath(path, root)
            text = _read(path)
            for m in CDS_ENTITY.finditer(text):
                if len(m.group(1)) > LIMIT:
                    failures.append(f'{rel}: CDS name {m.group(1)} ({len(m.group(1))} > {LIMIT})')
            table = DDL_TABLE.search(text)
            if not table:
                continue
            if '#TRANSPARENT' in text and len(table.group(1)) > TABLE_LIMIT:
                failures.append(f'{rel}: transparent table {table.group(1)} ({len(table.group(1))} > {TABLE_LIMIT})')
            body = text[table.end():]
            for m in DDL_FIELD.finditer(body):
                if len(m.group(1)) > LIMIT:
                    failures.append(f'{rel}: field {m.group(1)} ({len(m.group(1))} > {LIMIT})')
    return failures


def method_name_failures(root):
    failures = []
    for path in _walk(os.path.join(root, 'src'), '.abap'):
        rel = os.path.relpath(path, root)
        for no, kind, name in _declared_names(_read(path)):
            if kind != 'methods' or '~' in name:
                continue
            if not SNAKE.match(name):
                failures.append(f'{rel}:{no} method {name}: not snake_case')
            elif DATA_PREFIX.match(name):
                failures.append(f'{rel}:{no} method {name}: starts with a data prefix')
            if len(name) > LIMIT:
                failures.append(f'{rel}:{no} method {name} ({len(name)} > {LIMIT})')
    return failures


# POSIX regular expressions are obsolete since ABAP 7.55: only PCRE is allowed.
_POSIX_PATTERNS = [
    re.compile(r'\bregex\s*=', re.I),                      # matches( ... regex = ... ), find( ... regex = ... )
    re.compile(r'\b(FIND|REPLACE)\b[^.]*\bREGEX\b', re.I), # FIND / REPLACE ... REGEX
    re.compile(r'\bcl_abap_regex\s*=>\s*create_posix\b', re.I),
    re.compile(r'\bNEW\s+cl_abap_regex\s*\(', re.I),      # constructor = POSIX unless pcre
]


# A FIND / REPLACE statement over several lines: REGEX without PCRE in the statement
_POSIX_STATEMENT = re.compile(r'\b(FIND|REPLACE)\b[^.]*\bREGEX\b', re.I)


def posix_regex_failures(root):
    """Files that use POSIX regular expressions in code (comments and literal contents ignored)."""
    failures = []
    for path in _walk(os.path.join(root, 'src'), '.abap'):
        lines = list(_code_lines(_read(path)))
        hits = [f'{os.path.relpath(path, root)}:{no}: {line.strip()[:80]}'
                for no, line in lines if any(p.search(line) for p in _POSIX_PATTERNS)]
        if not hits:
            for stmt in '\n'.join(line for _, line in lines).split('.'):
                if _POSIX_STATEMENT.search(stmt) and not re.search(r'\bPCRE\b', stmt, re.I):
                    hits.append(f'{os.path.relpath(path, root)}: {" ".join(stmt.split())[:80]}')
        failures += hits
    return failures


# Patterns are PCRE matched to the complete value (user decision 2026-11-06): no CP / NP
# wildcard comparison and no CP / NP range row in code (comments and literal contents ignored)
_CP_COMPARE = re.compile(r'(?<![-~>\w])(CP|NP)(?![\w-])', re.I)
_CP_OPTION = re.compile(r"\boption\s*=.*'(CP|NP)'", re.I)


def _lines_without_comments(text):
    """ABAP lines without full-line and end-of-line comments; literals kept."""
    for no, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith('*'):
            continue
        out, in_lit = [], None
        for ch in line:
            if in_lit:
                if ch == in_lit:
                    in_lit = None
            elif ch in "'`|":
                in_lit = ch
            elif ch == '"':
                break
            out.append(ch)
        yield no, ''.join(out)


def cp_pattern_failures(root):
    """Files that compare with CP / NP or build a CP / NP range row (comments and literals ignored)."""
    failures = []
    for path in _walk(os.path.join(root, 'src'), '.abap'):
        text = _read(path)
        rel = os.path.relpath(path, root)
        for no, line in _code_lines(text):
            if _CP_COMPARE.search(line):
                failures.append(f'{rel}:{no}: {line.strip()[:80]}')
        for no, line in _lines_without_comments(text):
            if _CP_OPTION.search(line):
                failures.append(f'{rel}:{no}: {line.strip()[:80]}')
    return failures


# Inline declaration in IMPORTING of a functional method call (reference system S/4HANA 2025, 2026-11-16):
# x = meth( IMPORTING e = DATA(y) ) is refused by the compiler ("The inline declaration DATA(...) is not
# possible in this position"), abaplint accepts it. Declare the variable first.
_IMPORTING = re.compile(r'\bIMPORTING\b', re.I)
_INLINE_DECL = re.compile(r'\b(?:DATA|FINAL)\(', re.I)
_NEXT_PART = re.compile(r'\b(?:EXPORTING|CHANGING|RECEIVING|EXCEPTIONS)\b', re.I)
#: statements whose operands are functional positions (a call in them is never standalone); the keyword is
#: followed by an operand - a method named like a keyword (read( ... ).) is a standalone call
_OPERAND_STATEMENTS = re.compile(
    r'^(?:IF|ELSEIF|WHILE|CHECK|CASE|WHEN|ASSERT|RETURN|APPEND|INSERT|MODIFY|COLLECT|LOOP|READ|DELETE|'
    r'RAISE|MESSAGE|CONCATENATE|SPLIT|WRITE|SORT|CONDENSE|TRANSLATE|SHIFT|FIND|REPLACE)\s+\S', re.I)


def _statements_with_lines(text):
    """(first line number, statement) of the code lines (comments and literal contents removed), split at '.'."""
    out, buf, start = [], [], None
    for no, line in _code_lines(text):
        for part in re.split(r'(\.)', line):
            if part == '.':
                if buf and ''.join(buf).strip():
                    out.append((start, ' '.join(buf)))
                buf, start = [], None
                continue
            if part.strip() and start is None:
                start = no
            buf.append(part)
    if buf and ''.join(buf).strip():
        out.append((start, ' '.join(buf)))
    return out


def _depth_zero(text):
    """text without its parenthesised groups."""
    out, depth = [], 0
    for ch in text:
        if ch == '(':
            depth += 1
        elif ch == ')':
            depth = max(0, depth - 1)
        elif depth == 0:
            out.append(ch)
    return ''.join(out)


def inline_call_statement(stmt):
    """True when the statement declares inline (DATA( / FINAL() after IMPORTING of a call in a functional
    position: the call's result is assigned or compared, or the call is an operand of another call."""
    opens = []
    parents = {}
    for i, ch in enumerate(stmt):
        if ch == '(':
            opens.append(i)
        elif ch == ')':
            if opens:
                parents[opens.pop()] = i
    for m in _IMPORTING.finditer(stmt):
        stack = []
        for i, ch in enumerate(stmt[:m.start()]):
            if ch == '(':
                stack.append(i)
            elif ch == ')' and stack:
                stack.pop()
        if not stack:
            continue  # CALL METHOD ... IMPORTING without parentheses
        close = parents.get(stack[-1], len(stmt))
        segment = stmt[m.end():close]
        nxt = _NEXT_PART.search(segment)
        if nxt:
            segment = segment[:nxt.start()]
        if not _INLINE_DECL.search(segment):
            continue
        if len(stack) > 1:
            return True  # the call is an operand of another call or expression
        prefix = _depth_zero(stmt[:stack[0]]).strip()
        if '=' in prefix.replace('=>', '') or _OPERAND_STATEMENTS.match(prefix):
            return True
    return False


def inline_in_call_failures(root):
    """Statements with an inline declaration in IMPORTING of a functional method call (src/, comments and
    literal contents ignored)."""
    failures = []
    for path in _walk(os.path.join(root, 'src'), '.abap'):
        rel = os.path.relpath(path, root)
        for no, stmt in _statements_with_lines(_read(path)):
            if inline_call_statement(stmt):
                failures.append(f'{rel}:{no}: {" ".join(stmt.split())[:100]}')
    return failures
