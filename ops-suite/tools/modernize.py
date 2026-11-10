#!/usr/bin/env python3
"""Mechanical modernization of the ops suite - idempotent, safe to re-run after every merge.

Wrapper of the shared engine ../../tools/abaptools/modernize.py (phases tables, exceptions,
naming, quickfix - described there) with the suite's profile: the table renames of the
16-character limit (ZCD_OPS_ALERT_* -> the framework tables ZCA_OPS_AL*) and the files that name
the old values on purpose.

Usage (from ops-suite/):
  python3 tools/modernize.py [--abaplint <abaplint binary>] [--root <suite folder>] [--check]
                             [--phases tables,exceptions,naming,quickfix]

Modification log:
2026-11-10 | The engine moved to the shared tools (tools/abaptools); this file is the suite's profile.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('modernize', 'ops_suite')
_engine.configure(
    ROOT=ROOT,
    #: (d) transparent tables above 16 characters -> new name (16 at most)
    TABLE_RENAMES={
        'zcd_ops_alert_chn': 'zca_ops_alchn',
        'zcd_ops_alert_log': 'zca_ops_allog',
        'zcd_ops_alert_rule': 'zca_ops_alrule',
    },
    #: never rewritten: this profile and its fixture test name the old values on purpose
    SELF={os.path.join('tools', 'modernize.py'), os.path.join('tools', 'tests', 'test_modernize.py')})

main = _engine.main

if __name__ == '__main__':
    sys.exit(main())
