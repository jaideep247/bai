#!/usr/bin/env python3
"""
Artifact: tools/literal_scan.py
Purpose:  The suite's profile of the literal inventory (shared engine
          ../../tools/abaptools/literal_scan.py: categories 1 TEXT, 2 VALUE, 3 OK described there):
          allow-list tools/literal_allowlist.txt, types interfaces zif_cd_*types, own object names
          ZCD_ / ZIF_CD_ / ZCL_CD_ / ZCX_CD_, the phase-5 baseline. Used by tools/portable_checks.py
          (check no_inline_texts) and to write docs/Hardcoding_Inventory.md.
Usage:    python3 tools/literal_scan.py            -> summary per category
          python3 tools/literal_scan.py --list     -> every category 1/2 literal
          python3 tools/literal_scan.py --check    -> exit 1 when a category 1/2 literal is left
          python3 tools/literal_scan.py --md FILE  -> write the inventory document
Modification log:
2026-11-06 | Initial version (phase 5: remove hardcoding).
2026-11-10 | The engine moved to the shared tools (tools/abaptools); this file is the suite's profile.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('literal_scan', 'ops_suite')
_engine.configure(
    ROOT=ROOT,
    ALLOW=os.path.join(ROOT, 'tools', 'literal_allowlist.txt'),
    TYPES_FILE=re.compile(r'zif_cd_\w*types\.intf\.abap$'),
    OWN_OBJECTS=re.compile(r'(ZCD_|ZIF_CD_|ZCL_CD_|ZCX_CD_)[A-Z0-9_]*'),
    # Baseline of the phase-5 clean-up (commit f10b8f0), same scanner and allow-list
    BASELINE={'commit': 'f10b8f0', 'total': 1909, 1: 516, 2: 274, 3: 1119},
    MD_SOURCES=('Texts live in message class ZCD_OPS (built only through `ZCL_CD_OPS_UTIL=>TEXT( )`) or in '
                'text symbols; values in named constants of the area types interfaces, class constants, the '
                'generated `lif_c` interfaces of the configuration apps, or SAP constants.'),
    AREA_HEADING='payment engine area')

scan = _engine.scan
statements = _engine.statements
classify = _engine.classify
load_allow = _engine.load_allow
main = _engine.main

if __name__ == '__main__':
    main()
