#!/usr/bin/env python3
"""Extension points of the operations framework ZCA_OPS: the inventory config/extension_points.json against the
product (files, documents, the extensibility annotations and anchor elements of every extensible view, no other
extensible view), the generated matrix of docs/EXTENDING_WITH_CUSTOMER_DATA.md and the worked example of a customer
pack (config/extensions/examples/xx, rendered into docs/extensions/example_xx.md - never into a package of the
framework).

Wrapper of the shared engine ../../tools/abaptools/extensions.py (rules described there and in the document); this
file is the framework's profile. Never edit a generated file or block - change the inventory or the pack and
regenerate.

Usage: python3 tools/extensions.py [--check]

Modification log:
2026-11-15 | Initial version (build H: one customer extension contract, extensible product views, generator).
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('extensions', 'ops_framework')

PROFILE = {
    'inventory': 'config/extension_points.json',
    'doc': 'docs/EXTENDING_WITH_CUSTOMER_DATA.md',
    'examples': [{'pack': 'config/extensions/examples/xx', 'doc': 'docs/extensions/example_xx.md',
                  'title': 'Worked example - extensions of the fictitious customer XX'}],
}

if __name__ == '__main__':
    sys.exit(_engine.main(ROOT, PROFILE, sys.argv[1:]))
