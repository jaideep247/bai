#!/usr/bin/env python3
"""Regenerate the object table of a class purpose document from the artefact headers
(*& Artifact / Purpose / Modification log) of every class, interface and program under
src/<sub-folder>/ of a component. The rest of the page is kept.

Shared engine (tools/abaptools); a component's wrapper tools/class_purpose.py calls
main(root, doc, areas, header): doc = the document, areas = sub-folder -> area column,
header = the table header the object rows follow.

Usage (from the component folder): python3 tools/class_purpose.py [--check]
--check writes nothing and exits 1 when the table is out of date.

Modification log:
2026-11-05 | Initial version (ops suite).
2026-11-10 | Moved to the shared tools (tools/abaptools): document, area map and header are the
           | wrapper's; option --check.
"""
import glob
import os
import re
import sys


def row(path, areas):
    with open(path, encoding='utf-8') as fh:
        text = fh.read()
    name = os.path.basename(path).split('.')[0].upper()
    area = areas.get(os.path.basename(os.path.dirname(path)), '')
    short = re.search(r'shorttext synchronized">([^<]*)<', text)
    purpose = re.search(r'\*& Purpose:\n((?:\*&.*\n)+?)\*& Modification log', text)
    purpose_text = ' '.join(l[2:].strip() for l in purpose.group(1).splitlines()).strip() if purpose else ''
    logs = len(re.findall(r'^\*& 20\d\d-\d\d-\d\d', text, flags=re.M))
    base = path[:-len('.abap')]
    has_test = os.path.exists(base.replace('.clas', '.clas.testclasses') + '.abap') or \
        os.path.exists(path.replace('.clas.abap', '.clas.testclasses.abap'))

    def cell(value):
        return value.replace('|', '\\|')
    return (area, name, f"| {area} | {name} | {cell(short.group(1) if short else '')} | {cell(purpose_text)} | "
                        f"{'yes' if has_test else '—'} | {logs} |")


def render(root, doc_text, areas, header):
    """The document with a regenerated object table; (text, number of objects)."""
    files = [f for f in glob.glob(os.path.join(root, 'src', '*', '*.abap'))
             if re.search(r'\.(clas|intf|prog)\.abap$', f)]
    rows = sorted(row(f, areas) for f in files)
    start = doc_text.index(header)
    end = start + len(header)
    while end < len(doc_text) and doc_text[end] == '|':
        end = doc_text.index('\n', end) + 1
    return doc_text[:start] + header + '\n'.join(r[2] for r in rows) + '\n' + doc_text[end:], len(rows)


def main(root, doc, areas, header, argv=None):
    argv = sys.argv[1:] if argv is None else argv
    with open(doc, encoding='utf-8') as fh:
        old = fh.read()
    new, count = render(root, old, areas, header)
    if '--check' in argv:
        print(f'{count} objects listed; {"out of date (run tools/class_purpose.py)" if new != old else "up to date"}')
        return 1 if new != old else 0
    if new != old:
        with open(doc, 'w', encoding='utf-8') as fh:
            fh.write(new)
    print(f'{count} objects listed')
    return 0
