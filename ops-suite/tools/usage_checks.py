#!/usr/bin/env python3
"""Usage checks of the ops suite (portable, no SAP system): nothing is declared that nothing uses.
Used by tools/portable_checks.py (checks messages_used, params_used, constants_used).

- messages_used: every message of class ZCD_OPS (config/zcd_ops_messages.md) is raised by
  production code - through a message-number constant (gc_msg-..., TYPE symsgno / msgnr / ty_msgno)
  that production code reads, a MESSAGE eNNN(zcd_ops) statement or a NUMBER = 'NNN' literal.
- params_used: every parameter-name constant (BEGIN OF gc_param / gc_param_prefix in a types
  interface) is read by production code.
- constants_used: every constant of a types interface (zif_cd_*types*.intf.abap) is referenced by
  ABAP code, a test or CDS - by name, by its literal value in a CDS source (four characters or
  more) or as a pair of tools/cds_abap_parity.py; a reference in documentation only does not count.
  Message numbers, check codes, parameter names and parameter defaults are checked one by one; any
  other structure is a value domain and counts as used when one of its values is referenced.

Production code is every ABAP source in src/ and cds/ except test includes (*.testclasses.abap).
Usage:  python3 tools/usage_checks.py   (prints the findings of the three checks)
"""
import os
import re

MSG_FILE = os.path.join('config', 'zcd_ops_messages.md')
TYPES_FILE = re.compile(r'zif_cd_\w*types\.intf\.abap$')
MSGNO_CONST = re.compile(r"^\s*(\w+)\s+TYPE\s+(?:\S*=>)?(?:ty_msgno|ty_msg_number|symsgno|msgnr|sy-msgno)\s+VALUE\s+'(\d{3})'",
                         re.I | re.M)
MESSAGE_STMT = re.compile(r"\bMESSAGE\s+[aeiswx](\d{3})\(\s*zcd_ops\s*\)", re.I)
NUMBER_LIT = re.compile(r"\bnumber\s*=\s*'(\d{3})'", re.I)
BEGIN = re.compile(r'^\s*BEGIN\s+OF\s+(\w+)\s*,', re.I)
END = re.compile(r'^\s*END\s+OF\s+(\w+)\s*[.,]', re.I)
COMPONENT = re.compile(r"^\s*(\w+)\s+TYPE\s+[^.,]*?\bVALUE\s+('[^']*'|`[^`]*`|[-\w=>]+)", re.I)
STANDALONE = re.compile(r'^gc_(msg|check_code|param|param_prefix|param_default)$')
TOP_CONST = re.compile(r"^\s*CONSTANTS\s*:?\s+(\w+)\s+TYPE\s+[^.,]*?\bVALUE\s+('[^']*'|`[^`]*`|[-\w=>]+)", re.I)


def _walk(root, folders, *exts):
    for top in folders:
        for folder, dirs, files in os.walk(os.path.join(root, top)):
            dirs[:] = sorted(d for d in dirs if d not in ('.git', 'node_modules', '__pycache__'))
            for name in sorted(files):
                if name.endswith(exts):
                    yield os.path.join(folder, name)


def _read(path):
    with open(path, encoding='utf-8') as fh:
        return fh.read()


def _strip(line):
    """Code part of an ABAP line: no full-line or end-of-line comment (literals kept)."""
    if line.lstrip().startswith('*'):
        return ''
    out, in_lit = [], None
    for ch in line:
        if in_lit:
            out.append(ch)
            if ch == in_lit:
                in_lit = None
            continue
        if ch in "'`|":
            in_lit = ch
        elif ch == '"':
            break
        out.append(ch)
    return ''.join(out)


class _Sources:
    def __init__(self, root):
        self.root = root
        self.abap = {}
        for path in _walk(root, ('src', 'cds'), '.abap'):
            self.abap[path] = [_strip(l) for l in _read(path).splitlines()]
        self.cds = {p: _read(p) for p in _walk(root, ('src', 'cds'), '.asddls', '.asdcls', '.asbdef', '.asddlxs')}
        parity = os.path.join(root, 'tools', 'cds_abap_parity.py')
        self.parity = _read(parity) if os.path.exists(parity) else ''

    def rel(self, path):
        return os.path.relpath(path, self.root)

    def production(self):
        return {p: l for p, l in self.abap.items() if not p.endswith('.testclasses.abap')}

    def refs(self, pattern, sources, skip=None):
        """Files with a code line matching pattern, ignoring the line skip = (path, line index)."""
        hits = []
        for path, lines in sources.items():
            for no, line in enumerate(lines):
                if skip and (path, no) == skip:
                    continue
                if pattern.search(line):
                    hits.append(path)
                    break
        return hits


def _types_constants(src):
    """(path, line index, name, value) of every constant of the types interfaces; structure
    components as gc_struct-component."""
    out = []
    for path, lines in src.abap.items():
        if not TYPES_FILE.search(path):
            continue
        struct = None
        in_const = False
        for no, line in enumerate(lines):
            if re.match(r'^\s*CONSTANTS\b', line, re.I):
                in_const = True
            m = BEGIN.match(line) or re.match(r'^\s*CONSTANTS\s*:?\s*BEGIN\s+OF\s+(\w+)\s*,', line, re.I)
            if in_const and m:
                struct = m.group(1).lower()
                continue
            if struct and END.match(line):
                struct = None
                in_const = False
                continue
            if struct:
                c = COMPONENT.match(line)
                if c:
                    out.append((path, no, f'{struct}-{c.group(1).lower()}', c.group(2)))
                continue
            c = TOP_CONST.match(line)
            if c:
                out.append((path, no, c.group(1).lower(), c.group(2)))
            if line.rstrip().endswith('.'):
                in_const = False
    return out


def _name_pattern(name):
    if '-' in name:
        struct, comp = name.split('-', 1)
        return re.compile(r'\b' + re.escape(struct) + r'-' + re.escape(comp) + r'\b', re.I)
    return re.compile(r'\b' + re.escape(name) + r'\b(?!-)', re.I)


def _whole_struct_used(src, struct):
    """The structure itself (not a component) is named outside its BEGIN OF / END OF lines."""
    pat = re.compile(r'\b' + re.escape(struct) + r'\b(?!-)', re.I)
    for lines in src.abap.values():
        for line in lines:
            if pat.search(line) and not re.search(r'(BEGIN|END)\s+OF\s+' + re.escape(struct) + r'\b', line, re.I):
                return True
    return False


def message_failures(root):
    """Messages of ZCD_OPS that no production code raises."""
    src = _Sources(root)
    path = os.path.join(root, MSG_FILE)
    numbers = re.findall(r'^\| (\d{3}) \|', _read(path), re.M)
    prod = src.production()
    used = set()
    for lines in prod.values():
        text = '\n'.join(lines)
        used.update(MESSAGE_STMT.findall(text))
        used.update(NUMBER_LIT.findall(text))
    for p, lines in src.abap.items():
        for no, line in enumerate(lines):
            m = MSGNO_CONST.match(line)
            if not m:
                continue
            name = m.group(1).lower()
            in_struct = _enclosing_struct(lines, no)
            pattern = _name_pattern(f'{in_struct}-{name}' if in_struct else name)
            if src.refs(pattern, prod, skip=(p, no)):
                used.add(m.group(2))
    return [f'{MSG_FILE}: message {n} is raised by no production code' for n in numbers if n not in used]


def _enclosing_struct(lines, no):
    for i in range(no - 1, -1, -1):
        if END.match(lines[i]):
            return None
        m = re.search(r'BEGIN\s+OF\s+(\w+)\s*,', lines[i], re.I)
        if m:
            return m.group(1).lower()
    return None


def param_failures(root):
    """Parameter-name constants (gc_param-..., gc_param_prefix-...) that no production code reads."""
    src = _Sources(root)
    prod = src.production()
    fails = []
    for path, no, name, _ in _types_constants(src):
        if not re.match(r'gc_param(_prefix)?-', name):
            continue
        if not src.refs(_name_pattern(name), prod, skip=(path, no)):
            fails.append(f'{src.rel(path)}: {name} is read by no production code')
    return fails


def constant_failures(root):
    """Types-interface constants referenced by no ABAP code, test, CDS source or CDS parity pair.
    Components of STANDALONE structures (message numbers, check codes, parameter names and
    defaults) are checked one by one; any other structure is a value domain (statuses, codes,
    activities): it is used when one of its components or the structure itself is referenced -
    its other values document the domain a configured or delivered value can take."""
    src = _Sources(root)
    used, domains = {}, {}
    for path, no, name, value in _types_constants(src):
        ok = bool(src.refs(_name_pattern(name), src.abap, skip=(path, no)))
        literal = value.strip("'`")
        if not ok and value[:1] in "'`" and len(literal) >= 4:
            ok = any(re.search(r"'" + re.escape(literal) + r"'", text, re.I) for text in src.cds.values())
        if not ok:
            ok = "'" + name + "'" in src.parity.lower()
        used[(path, name)] = ok
        if '-' in name:
            domains.setdefault((path, name.split('-', 1)[0]), []).append(ok)
    fails = []
    for (path, name), ok in used.items():
        if ok:
            continue
        rel = src.rel(path)
        if '-' not in name:
            fails.append(f'{rel}: {name} is referenced by no code, test or CDS')
            continue
        struct = name.split('-', 1)[0]
        if STANDALONE.match(struct):
            fails.append(f'{rel}: {name} is referenced by no code, test or CDS')
        elif not any(domains[(path, struct)]) and not _whole_struct_used(src, struct):
            msg = f'{rel}: {struct} (no value referenced by code, test or CDS)'
            if msg not in fails:
                fails.append(msg)
    return fails


if __name__ == '__main__':
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for title, fn in (('messages_used', message_failures), ('params_used', param_failures),
                      ('constants_used', constant_failures)):
        found = fn(here)
        print(f'{title}: {len(found)}')
        for f in found:
            print('  ' + f)
