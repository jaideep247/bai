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
2026-11-10 | E-mail template of alert rules and channels (TEMPLATE_ID, check template_invalid 436) and the
           | rule flag SHOW_AMOUNTS (alert e-mail templates).
2026-11-10 | Control register of the daily review: controls (owner / backup user 437, team 438, runbook URL
           | 439), guidance per language and the checks a control covers (exact values).
2026-11-10 | Alert rules: company-code pattern BUKRS_PATTERN (PCRE, checked on save as the other patterns).
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
        title='Alerting, purge targets and controls', tables=[
            ('zca_ops_alrule', 'AlertRule', 'zca_d_alrule', 'Alert rule', 'Alert rules', [],
             [('area', 'area', True), ('enum', 'min_severity', ',' + SEV),
              ('enum', 'min_rag', ',R,A,G'), ('window', 'quiet_from', 'quiet_to'),
              ('pcre', 'rule_pattern'), ('pcre', 'check_pattern'), ('pcre', 'group1_pattern'),
              ('pcre', 'group2_pattern'), ('pcre', 'bukrs_pattern'),
              ('dest', ('channel', 'channel'), 'destination', 'escalation_dest')]),
            ('zca_ops_alchn', 'AlertChannel', 'zca_d_alchn', 'Channel', 'Alert channels', [],
             [('class', 'class_name', 'ZIF_CA_OPS_ALERT_CHANNEL'), ('dest', ('class', 'class_name'), 'destination'),
              ('valid', 'template_id', 'zcl_ca_ops_cfg_checks=>template_valid', 'template_invalid')]),
            # Purge targets of consumers (registry, 2026-11-10): plug-in class and retention parameter
            ('zca_ops_purge', 'PurgeTarget', 'zca_d_purge', 'Purge target', 'Purge targets of consumers', [],
             [('class', 'class_name', 'ZIF_CA_OPS_PURGE_TARGET'), ('area', 'param_area', False),
              ('param', 'param_area', 'param_name')]),
            # Control register of the daily review (2026-11-10): controls, guidance per language and the
            # checks each control covers (exact values of a finding field - joined in CDS, so no pattern)
            ('zca_ops_control', 'Control', 'zca_d_ctl', 'Control', 'Controls (daily review)', [],
             [('area', 'area', False), ('valid', 'owner', 'zcl_ca_ops_cfg_checks=>user_valid', 'user_invalid'),
              ('valid', 'backup', 'zcl_ca_ops_cfg_checks=>user_valid', 'user_invalid'),
              ('valid', 'team', 'zcl_ca_ops_cfg_checks=>team_valid', 'team_invalid'),
              ('valid', 'runbook_url', 'zcl_ca_ops_cfg_checks=>url_valid', 'url_invalid')]),
            ('zca_ops_ctlt', 'ControlText', 'zca_d_ctlt', 'Guidance', 'Control guidance per language', [],
             [('area', 'area', False)]),
            ('zca_ops_ctlchk', 'ControlCheck', 'zca_d_ctlchk', 'Covered check', 'Checks covered by a control', [],
             [('area', 'area', False), ('area', 'check_area', False),
              ('enum', 'match_field', 'RULE_ID,CHECK_CODE,GROUP2')]),
        ]),
}

# Words of a field name -> label words, and labels of single fields (override the words)
TOKENS = {'id': 'ID', 'min': 'minimum', 'max': 'maximum', 'dest': 'destination', 'rag': 'RAG', 'url': 'URL'}
LABELS = {'area': 'Area (alert rules: * = every area)', 'param_area': 'Area of the retention parameter',
          'param_name': 'Retention parameter (ZCA_PARAM)', 'target': 'Purge target',
          'last_changed_by': 'Last changed by', 'last_changed_at': 'Last changed at',
          'local_last_changed_at': 'Changed at (instance)', 'changed_by': 'Changed by (SM30)',
          'changed_at': 'Changed at (SM30)', 'template_id': 'E-mail template (SMTG template ID)',
          'show_amounts': 'Show amounts in the e-mail',
          'bukrs_pattern': 'Company code pattern (PCRE, blank = any)',
          # Control register (2026-11-10)
          'langu': 'Language', 'cutoff_time': 'Review cut-off (local time, CONTROL_TIME_ZONE)',
          'team': 'Team (parameter CONTROL_TEAMS)', 'check_area': 'Area of the findings',
          'match_field': 'Finding field (RULE_ID / CHECK_CODE / GROUP2)', 'match_value': 'Value (exact)',
          'guidance': 'Guidance for the reviewer'}

_engine.configure(ROOT=ROOT, SPEC=SPEC, RENAME={}, TOKENS=TOKENS, LABELS=LABELS)


def __getattr__(name):
    """The engine's functions and state (templates, CONST, localize, ...), configured for the framework."""
    return getattr(_engine, name)


if __name__ == '__main__':
    _engine.main()
