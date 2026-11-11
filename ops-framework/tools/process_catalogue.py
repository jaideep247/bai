#!/usr/bin/env python3
"""Process catalogue of the operations framework ZCA_OPS: the product packages (baseline S4CORE, industry packages
FICA and FSCD) - seed rows of the catalogue tables, the monitoring rows of the standard processes (all inactive) and
the catalogue document.

Wrapper of the shared engine ../../tools/abaptools/process_catalogue.py (spec format, validation and outputs
described there and in docs/PROCESS_CATALOGUE.md); this file is the framework's profile. The worked example of a
customer layer (config/catalogue/examples/xx_layer.json, prefix XX) is validated with the product packages, never
seeded. Never edit a generated file - change the package spec and regenerate.

Usage: python3 tools/process_catalogue.py [--check]

Modification log:
2026-11-11 | Initial version (process catalogue with activation).
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('process_catalogue', 'ops_framework')
_links = abaptools.fresh('link_registry', 'ops_framework_catalogue')

PROFILE = {
    'own': ['config/catalogue/s4core.json', 'config/catalogue/packages/fica.json',
            'config/catalogue/packages/fscd.json'],
    'examples': ['config/catalogue/examples/xx_layer.json'],
    'links': {'base': _links.PRODUCT_LAYERS},
    'register': 'config/process_register.csv',
    'seed_folder': 'config/catalogue/seed',
    'monitoring_folder': 'config/catalogue/monitoring',
    'docs_folder': 'docs/catalogue',
    'title': 'Process catalogue of the product (S4CORE, FICA, FSCD)',
    'day': '20261111',
}

if __name__ == '__main__':
    sys.exit(_engine.main(ROOT, PROFILE, sys.argv[1:]))
