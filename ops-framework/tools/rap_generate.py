#!/usr/bin/env python3
"""Generate the configuration app ZUI_CA_OPS_CFG of the operations framework ZCA_OPS (alert rules,
alert channels, purge targets of consumers) from the customizing-table DDLs in ddic/.

Wrapper of the shared engine ../../tools/abaptools/rap_generate.py (shape, outputs and check kinds
described there); this file is the framework's profile: the app (SPEC), label tokens and labels.
Writes ddic/ui/zca_d_*.tabl.ddl and src/ui/* - never edit the generated files, regenerate.
Then run tools/abapgit_serialize.py for the abapGit XML.

Usage: python3 tools/rap_generate.py [--check]

Modification log:
2026-11-10 | Initial version (the framework's app was generated from its first consumer's generator;
           | the engine is shared, tools/abaptools). Output unchanged.
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('rap_generate', 'ops_framework')

SEV = 'B,E,W,I'

SPEC = {
    # The framework's own app (2026-11-10): sub-package ZCA_OPS_UI (folder ui), prefix CA, messages of
    # class ZCA_OPS, area CA_OPS
    'framework': dict(
        ddic='', draft_ddic='ui', prefix='ca',
        folder='ui', pe_area='CA_OPS', root='OpsCfgAll', draft='zca_d_opscfg', service='ZUI_CA_OPS_CFG',
        title='Alerting and purge targets', tables=[
            ('zca_ops_alrule', 'AlertRule', 'zca_d_alrule', 'Alert rule', 'Alert rules', [],
             [('area', 'area', True), ('enum', 'min_severity', ',' + SEV),
              ('enum', 'min_rag', ',R,A,G'), ('window', 'quiet_from', 'quiet_to'),
              ('pcre', 'rule_pattern'), ('pcre', 'check_pattern'), ('pcre', 'group1_pattern'),
              ('pcre', 'group2_pattern'), ('dest', ('channel', 'channel'), 'destination', 'escalation_dest')]),
            ('zca_ops_alchn', 'AlertChannel', 'zca_d_alchn', 'Channel', 'Alert channels', [],
             [('class', 'class_name', 'ZIF_CA_OPS_ALERT_CHANNEL'), ('dest', ('class', 'class_name'), 'destination')]),
            # Purge targets of consumers (registry, 2026-11-10): plug-in class and retention parameter
            ('zca_ops_purge', 'PurgeTarget', 'zca_d_purge', 'Purge target', 'Purge targets of consumers', [],
             [('class', 'class_name', 'ZIF_CA_OPS_PURGE_TARGET'), ('area', 'param_area', False),
              ('param', 'param_area', 'param_name')]),
        ]),
}

# Words of a field name -> label words, and labels of single fields (override the words)
TOKENS = {'id': 'ID', 'min': 'minimum', 'max': 'maximum', 'dest': 'destination', 'rag': 'RAG'}
LABELS = {'area': 'Area (* = every area)', 'param_area': 'Area of the retention parameter',
          'param_name': 'Retention parameter (ZCA_PARAM)', 'target': 'Purge target',
          'last_changed_by': 'Last changed by', 'last_changed_at': 'Last changed at',
          'local_last_changed_at': 'Changed at (instance)', 'changed_by': 'Changed by (SM30)',
          'changed_at': 'Changed at (SM30)'}

_engine.configure(ROOT=ROOT, SPEC=SPEC, RENAME={}, TOKENS=TOKENS, LABELS=LABELS)


def __getattr__(name):
    """The engine's functions and state (templates, CONST, localize, ...), configured for the framework."""
    return getattr(_engine, name)


if __name__ == '__main__':
    _engine.main()
