#!/usr/bin/env python3
"""Link registry of the operations framework ZCA_OPS: the product layers (baseline S4CORE, industry package
CONTRACT) - seed rows of the registry tables, lineage, CDS snippets and field impact.

Wrapper of the shared engine ../../tools/abaptools/link_registry.py (spec format, validation and outputs described
there and in docs/LINK_REGISTRY.md); this file is the framework's profile. The worked example of a customer overlay
(config/links/examples/xx_overlay.json, prefix XX) is validated with the product layers, never seeded.
Never edit a generated file - change the layer spec and regenerate.

Usage: python3 tools/link_registry.py [--check]

Modification log:
2026-11-11 | Initial version (link registry: product baseline and contract accounting package).
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('link_registry', 'ops_framework')

PROFILE = {
    'own': ['config/links/s4core.json', 'config/links/packages/contract_accounting.json'],
    'examples': ['config/links/examples/xx_overlay.json'],
    'seed_folder': 'config/links/seed',
    'docs_folder': 'docs/links',
    'ddic': ['ddic', 'src'],
    'aggregates': ['config/check_aggregates.csv'],
    'title': 'Link registry of the product (S4CORE, CONTRACT)',
}

if __name__ == '__main__':
    sys.exit(_engine.main(ROOT, PROFILE, sys.argv[1:]))
