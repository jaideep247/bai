#!/usr/bin/env python3
"""Release manifest of the product (release/manifest.json): validation against the repository (components, versions,
packs, objects, import order, licence modules, catalogue, source contracts, checks, seed rows, open items, fixtures,
blank-slate rules), the generated document release/MANIFEST.md, the object report and the namespace report.

Wrapper of the shared engine ../../tools/abaptools/release_manifest.py (rules described there and in
docs/RELEASE_AND_INSTALL.md); this file is the framework's profile. Never edit release/MANIFEST.md - change the
manifest and regenerate.

Usage: python3 tools/release_manifest.py [--check | --report DIR | --namespace /NS/]

Modification log:
2026-11-15 | Initial version (build M: clean install and release baseline).
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('release_manifest', 'ops_framework')

PROFILE = {
    'manifest': 'release/manifest.json',
    'doc': 'release/MANIFEST.md',
}

if __name__ == '__main__':
    sys.exit(_engine.main(ROOT, PROFILE, sys.argv[1:]))
