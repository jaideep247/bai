#!/usr/bin/env python3
"""abapGit metadata of the parameter framework ZCA_PARAM (folder logic PREFIX).

Wrapper of the shared serializer (../../tools/abaptools/abapgit_serialize.py, inputs and outputs
described there); the settings are config/repository.json of this folder.

Usage:  python3 tools/abapgit_serialize.py [--check]
--check writes nothing and exits 1 when a generated file is missing or out of date.

Modification log:
2026-11-07 | Initial version.
2026-11-10 | The engine moved to the shared tools (tools/abaptools); this file is the wrapper.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
from abaptools import abapgit_serialize as _engine  # noqa: E402

# The engine's interface (tests and tools/checks.py)
Stage = _engine.Stage
parse_table = _engine.parse_table
table_xml = _engine.table_xml


def build(root=ROOT):
    return _engine.build(root)


def main(argv):
    return _engine.main(argv, ROOT)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
