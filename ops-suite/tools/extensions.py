#!/usr/bin/env python3
"""Customer extensions of the ops suite: its data on top of the product views of the operations framework ZCA_OPS.

Wrapper of the shared engine ../../tools/abaptools/extensions.py (rules there and in
ops-framework/docs/EXTENDING_WITH_CUSTOMER_DATA.md): the declarations config/extensions/*.json are checked against
the framework's inventory of extension points (ops-framework/config/extension_points.json) and the link registry
(product layers + config/links/overlay.json); the extend view entity sources are generated into src/ext (active) or
config/extensions/pending (waiting for a VERIFY item, never imported), the report into docs/extensions/extensions.md.
Never edit a generated file - change the declaration and regenerate; then run tools/abapgit_serialize.py.

Usage: python3 tools/extensions.py [--check]

Modification log:
2026-11-15 | Initial version (build H: customer plug-in pack of the ops suite).
"""
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, '..', '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('extensions', 'ops_suite')

ROOT = os.path.dirname(_HERE)
PROFILE = {
    'pack': 'config/extensions',
    'title': 'Extensions of the ops suite on the framework views',
}

if __name__ == '__main__':
    sys.exit(_engine.main(ROOT, PROFILE, sys.argv[1:]))
