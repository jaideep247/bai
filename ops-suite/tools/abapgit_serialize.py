#!/usr/bin/env python3
"""abapGit metadata of the ops suite (folder logic PREFIX, starting folder /ops-suite/src/).

Wrapper of the shared serializer (../../tools/abaptools/abapgit_serialize.py, inputs and outputs
described there); the settings are config/repository.json of this folder: .abapgit.xml at the
repository root, packages ZCD_OPS and ZCD_OPS_<MOD>, message class ZCD_OPS from
config/zcd_ops_messages.md (texts cut at 73), secondary indexes from the DDL comment lines
'// @index <ID> [UNIQUE]: F1, F2' (DD12V / DD17V).

Re-run after adding objects, tables or messages:  python3 tools/abapgit_serialize.py [--check]
Audit A89: every output is staged in memory and validated first; files are replaced only
when all tables serialized cleanly (exit 1 and nothing written otherwise). Unchanged
files are never rewritten. --check writes nothing and exits 1 when a file is out of date.

Modification log:
2026-11-05 | Initial version.
2026-11-10 | The engine moved to the shared tools (tools/abaptools, one serializer for the suite and
           | both frameworks); settings in config/repository.json; option --check.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
from abaptools import abapgit_serialize as _engine  # noqa: E402


def build(root=ROOT):
    return _engine.build(root)


def main(argv):
    return _engine.main(argv, ROOT)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
