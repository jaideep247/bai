#!/usr/bin/env python3
"""Upgrade notes between two git revisions of the product (objects added / changed / removed per pack, dictionary
changes with the conversions flagged, changed configuration, component versions, rollback guidance).

Wrapper of the shared engine ../../tools/abaptools/release_diff.py (rules described there and in
docs/RELEASE_AND_INSTALL.md). Reads git only; writes nothing unless --out is given.

Usage: python3 tools/release_diff.py <old revision> <new revision> [--out FILE]

Modification log:
2026-11-15 | Initial version (build M: upgrade replay and rollback).
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('release_diff', 'ops_framework')

MANIFEST = 'ops-framework/release/manifest.json'

if __name__ == '__main__':
    sys.exit(_engine.main(os.path.dirname(ROOT), MANIFEST, sys.argv[1:]))
