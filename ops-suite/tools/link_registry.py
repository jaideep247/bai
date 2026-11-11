#!/usr/bin/env python3
"""
Artifact: tools/link_registry.py
Purpose:  The suite's customer overlay of the link registry of ZCA_OPS (layer CD on top of the product layers
          S4CORE and CONTRACT of ../ops-framework/config/links): validates the overlay with the product layers and
          the repository's DDIC / CDS metadata, writes the seed rows of the overlay (config/links/seed, maintained in
          the framework's configuration app ZUI_CA_OPS_CFG), the lineage of all three layers, the CDS snippets of the
          overlay's links and the field impact (links, payment model sections, aggregate checks). Shared engine
          ../../tools/abaptools/link_registry.py; the payment model generator renders its joins from the same
          registry. Never edit a generated file - change config/links/overlay.json and regenerate.
Usage:    python3 tools/link_registry.py           -> regenerate
          python3 tools/link_registry.py --check   -> report an invalid registry or out-of-date files, exit 1
Modification log:
2026-11-11 | Initial version (link registry: customer overlay of the suite).
"""
import os
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, '..', '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('link_registry', 'ops_suite')

ROOT = os.path.dirname(_HERE)
PROFILE = {
    'base': _engine.PRODUCT_LAYERS,
    'own': ['config/links/overlay.json'],
    'seed_folder': 'config/links/seed',
    'docs_folder': 'docs/links',
    'ddic': ['ddic', 'src', 'cds', os.path.join('..', 'ops-framework', 'ddic')],
    'aggregates': ['config/check_aggregates.csv'],
    'payment_model': os.path.join('config', 'payment_model', 'mapping.json'),
    'show_all': True,
    'title': 'Link registry of the ops suite (S4CORE, CONTRACT, CD)',
}

if __name__ == '__main__':
    sys.exit(_engine.main(ROOT, PROFILE, sys.argv[1:]))
