#!/usr/bin/env python3
"""Licensing of the operations framework ZCA_OPS: the licensable modules (config/licensing/modules.json) against the
product, the generated module map of the runtime (src/zcl_ca_ops_lic_map.clas.abap) and the module document
(docs/licensing/modules.md).

Wrapper of the shared engine ../../tools/abaptools/licensing.py (rules described there and in docs/LICENSING.md); this
file is the framework's profile. Never edit a generated file - change modules.json or the license_module of a
catalogue package and regenerate. The vendor's issuing and verification tools are ../../tools/licensing.

Usage: python3 tools/licensing.py [--check]

Modification log:
2026-11-15 | Initial version (licensing: module catalogue, module map, module document).
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('licensing', 'ops_framework')

PROFILE = {
    'modules': 'config/licensing/modules.json',
    # product catalogue packages (repository-relative): each names its license_module
    'packages': ['ops-framework/config/catalogue/s4core.json', 'ops-framework/config/catalogue/packages/fica.json',
                 'ops-framework/config/catalogue/packages/fscd.json'],
    'behaviour_pool': 'src/ui/zbp_r_ca_opscfgall.clas.locals_imp.abap',
    'class_prefix': 'zcl_ca_ops_',
    'map_class': 'ZCL_CA_OPS_LIC_MAP',
    'types_interface': 'zif_ca_ops_lic_types',
    'doc': 'docs/licensing/modules.md',
    'doc_title': 'Licensable modules of ZCA_OPS',
}

if __name__ == '__main__':
    sys.exit(_engine.main(ROOT, PROFILE, sys.argv[1:]))
