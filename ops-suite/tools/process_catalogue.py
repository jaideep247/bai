#!/usr/bin/env python3
"""
Artifact: tools/process_catalogue.py
Purpose:  The suite's customer layer of the process catalogue of ZCA_OPS (package CD on top of the product packages
          S4CORE, FICA and FSCD of ../ops-framework/config/catalogue): validates the layer with the product packages,
          the link registry of the suite and config/process_register.csv (CAT_PROCESS), writes the seed rows of the
          layer (config/catalogue/seed: the customer process and the activation proposal, maintained in the
          framework's configuration app ZUI_CA_OPS_CFG), the catalogue of every package with this landscape's state
          and monitoring (docs/catalogue/catalogue.md) and the activation proposal with the decision list
          (docs/catalogue/activation.md). Shared engine ../../tools/abaptools/process_catalogue.py. Never edit a
          generated file - change config/catalogue/overlay.json and regenerate.
Usage:    python3 tools/process_catalogue.py           -> regenerate
          python3 tools/process_catalogue.py --check   -> report an invalid catalogue or out-of-date files, exit 1
Modification log:
2026-11-11 | Initial version (process catalogue: customer layer of the suite, activation proposal).
"""
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, '..', '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('process_catalogue', 'ops_suite')
_links = abaptools.fresh('link_registry', 'ops_suite_catalogue')

ROOT = os.path.dirname(_HERE)
PROFILE = {
    'base': _engine.PRODUCT_PACKAGES,
    'own': ['config/catalogue/overlay.json'],
    'links': {'base': _links.PRODUCT_LAYERS, 'own': [os.path.join(ROOT, 'config', 'links', 'overlay.json')]},
    'register': 'config/process_register.csv',
    'seed_folder': 'config/catalogue/seed',
    'docs_folder': 'docs/catalogue',
    'show_all': True,
    'title': 'Process catalogue of the ops suite (S4CORE, FICA, FSCD, CD)',
    'day': '20261111',
}

if __name__ == '__main__':
    sys.exit(_engine.main(ROOT, PROFILE, sys.argv[1:]))
