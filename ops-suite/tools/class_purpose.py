#!/usr/bin/env python3
"""Regenerate the object table in docs/Class_Purpose_and_Modification_Log.md
from the artefact headers (*& Artifact / Purpose / Modification log) of every
class, interface and program under src/. The rest of the page is kept.

Wrapper of the shared engine ../../tools/abaptools/class_purpose.py with the suite's
document, its payment engine areas and the table header.

Usage (from ops-suite/): python3 tools/class_purpose.py [--check]

Modification log:
2026-11-05 | Initial version.
2026-11-10 | The engine moved to the shared tools (tools/abaptools); option --check.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
from abaptools import class_purpose as _engine  # noqa: E402

DOC = os.path.join(ROOT, 'docs', 'Class_Purpose_and_Modification_Log.md')
AREA = {'core': 'CORE', 'ebs': 'EBS', 'fmon': 'FMON', 'hck': 'HCK'}
HEADER = ('| Payment engine area | Object | Short text (SE24) | Purpose | Own test include | Log entries |\n'
          '|---|---|---|---|---|---|\n')


def main(argv=None):
    return _engine.main(ROOT, DOC, AREA, HEADER, argv)


if __name__ == '__main__':
    sys.exit(main())
