#!/usr/bin/env python3
"""Regenerate the object table in docs/Class_Purpose_and_Modification_Log.md
from the artefact headers (*& Artifact / Purpose / Modification log) of every
class, interface and program under src/. The rest of the page is kept.

Usage (from ops-suite/): python3 tools/class_purpose.py
"""
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOC = os.path.join(ROOT, 'docs', 'Class_Purpose_and_Modification_Log.md')
AREA = {'core': 'CORE', 'ebs': 'EBS', 'fmon': 'FMON', 'hck': 'HCK'}
HEADER = ('| Payment engine area | Object | Short text (SE24) | Purpose | Own test include | Log entries |\n'
          '|---|---|---|---|---|---|\n')


def row(path):
    text = open(path, encoding='utf-8').read()
    name = os.path.basename(path).split('.')[0].upper()
    area = AREA.get(os.path.basename(os.path.dirname(path)), '')
    short = re.search(r'shorttext synchronized">([^<]*)<', text)
    purpose = re.search(r'\*& Purpose:\n((?:\*&.*\n)+?)\*& Modification log', text)
    purpose_text = ' '.join(l[2:].strip() for l in purpose.group(1).splitlines()).strip() if purpose else ''
    logs = len(re.findall(r'^\*& 20\d\d-\d\d-\d\d', text, flags=re.M))
    base = path[:-len('.abap')]
    has_test = os.path.exists(base.replace('.clas', '.clas.testclasses') + '.abap') or \
        os.path.exists(path.replace('.clas.abap', '.clas.testclasses.abap'))
    cell = lambda s: s.replace('|', '\\|')
    return (area, name, f"| {area} | {name} | {cell(short.group(1) if short else '')} | {cell(purpose_text)} | "
                        f"{'yes' if has_test else '—'} | {logs} |")


def main():
    files = [f for f in glob.glob(os.path.join(ROOT, 'src', '*', '*.abap'))
             if re.search(r'\.(clas|intf|prog)\.abap$', f)]
    rows = sorted(row(f) for f in files)
    doc = open(DOC, encoding='utf-8').read()
    start = doc.index(HEADER)
    end = start + len(HEADER)
    while end < len(doc) and doc[end] == '|':
        end = doc.index('\n', end) + 1
    new = doc[:start] + HEADER + '\n'.join(r[2] for r in rows) + '\n' + doc[end:]
    if new != doc:
        open(DOC, 'w', encoding='utf-8').write(new)
    print(f'{len(rows)} objects listed')


if __name__ == '__main__':
    main()
