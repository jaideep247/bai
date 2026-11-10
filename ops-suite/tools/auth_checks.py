#!/usr/bin/env python3
"""Portable check auth_fields_defined: every check on authorisation object ZCD_OPS names
only the fields that config/auth_zcd_ops.md defines for it (section 1 field table and the
field list of the object in section 2).

Scanned: AUTHORITY-CHECK OBJECT 'ZCD_OPS' / zif_ca_ops_auth=>gc_object in ABAP sources and
aspect pfcg_auth( ZCD_OPS, ... ) in DCL sources (src/ and the ADT-only cds/ folder).
A field name that SU21 does not know makes every kernel check fail (sy-subrc 12) and every
DCL deny; abaplint cannot see it because the object is not in the SAP stubs.
"""
import os
import re

OBJECT = 'ZCD_OPS'
_AUTH_DOC = os.path.join('config', 'auth_zcd_ops.md')
_ABAP_CHECK = re.compile(
    r"AUTHORITY-CHECK\s+OBJECT\s+('\w+'|zif_ca_ops_auth=>gc_object)(.*?)\.(?:\s|$)", re.I | re.S)
_ABAP_ID = re.compile(r"\bID\s+'([^']+)'", re.I)
_DCL_AUTH = re.compile(r'pfcg_auth\s*\(\s*ZCD_OPS\s*,(.*?)\)', re.I | re.S)


def defined_fields(root):
    """Fields of ZCD_OPS: the section 1 field table plus the object's field list in section 2."""
    with open(os.path.join(root, _AUTH_DOC), encoding='utf-8') as fh:
        text = fh.read()
    fields = set()
    sec1 = re.search(r'^## 1\..*?(?=^## )', text, re.M | re.S)
    if sec1:
        fields |= set(re.findall(r'^\| `(\w+)` \|', sec1.group(0), re.M))
    sec2 = re.search(r'^## 2\..*?(?=^## )', text, re.M | re.S)
    if sec2:
        row = re.search(r'^\| `' + OBJECT + r'` \|[^|]*\|([^|]*)\|', sec2.group(0), re.M)
        if row:
            fields |= set(re.findall(r'`(\w+)`', row.group(1)))
    return {f.upper() for f in fields}


def _strip_abap_comments(text):
    out = []
    for line in text.splitlines():
        if line.lstrip().startswith('*'):
            out.append('')
            continue
        cut, lit = [], None
        for ch in line:
            if lit:
                if ch == lit:
                    lit = None
            elif ch in "'`|":
                lit = ch
            elif ch == '"':
                break
            cut.append(ch)
        out.append(''.join(cut))
    return '\n'.join(out)


def _strip_dcl_comments(text):
    return '\n'.join(re.sub(r'//.*$', '', line) for line in text.splitlines())


def _files(root):
    for top in ('src', 'cds'):
        for d, _, files in os.walk(os.path.join(root, top)):
            for f in sorted(files):
                if f.endswith(('.abap', '.asdcls')):
                    yield os.path.join(d, f)


def _dcl_fields(args):
    """Field names of a pfcg_auth argument list: positional names and NAME = 'value' pairs."""
    names = []
    for part in args.split(','):
        m = re.match(r'\s*(\w+)', part)
        if m:
            names.append(m.group(1).upper())
    return names


def failures(root):
    allowed = defined_fields(root)
    if not allowed:
        return [f'{_AUTH_DOC}: no field definition of {OBJECT} found (sections 1 and 2)']
    out = []
    for path in _files(root):
        rel = os.path.relpath(path, root)
        with open(path, encoding='utf-8') as fh:
            raw = fh.read()
        if path.endswith('.abap'):
            code = _strip_abap_comments(raw)
            for m in _ABAP_CHECK.finditer(code):
                if m.group(1).startswith("'") and m.group(1).strip("'").upper() != OBJECT:
                    continue
                line = code[:m.start()].count('\n') + 1
                for field in _ABAP_ID.findall(m.group(2)):
                    if field.upper() not in allowed:
                        out.append(f'{rel}:{line}: field {field} is not a field of {OBJECT}')
        else:
            code = _strip_dcl_comments(raw)
            for m in _DCL_AUTH.finditer(code):
                line = code[:m.start()].count('\n') + 1
                for field in _dcl_fields(m.group(1)):
                    if field not in allowed:
                        out.append(f'{rel}:{line}: field {field} is not a field of {OBJECT}')
    return out
