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
2026-11-10 | Process onboarding: business processes, registered checks, aggregate rows (table 082 / field 083
           | checks) and approved tables.
2026-11-11 | SAP job monitor: scheduler jobs and the SAP job names they start (pattern checked on save).
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
        title='Processes, checks, alerting, purge targets and controls', tables=[
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
            # Process onboarding (2026-11-10): business processes, the check registry of the generic runner,
            # the no-code aggregate rows and the tables they may read (approved per area)
            ('zca_ops_proc', 'Process', 'zca_d_proc', 'Process', 'Business processes', [],
             [('area', 'area', False), ('valid', 'owner', 'zcl_ca_ops_cfg_checks=>user_valid', 'user_invalid'),
              ('valid', 'backup', 'zcl_ca_ops_cfg_checks=>user_valid', 'user_invalid'),
              ('valid', 'runbook_url', 'zcl_ca_ops_cfg_checks=>url_valid', 'url_invalid')]),
            ('zca_ops_check', 'RegisteredCheck', 'zca_d_check', 'Check', 'Registered checks', [],
             [('area', 'area', False), ('class', 'class_name', 'ZIF_CA_OPS_CHECK')]),
            ('zca_ops_agg', 'AggregateCheck', 'zca_d_agg', 'Aggregate', 'Aggregate checks (no code)', [],
             [('area', 'area', False), ('enum', 'agg_func', 'COUNT,AGE'), ('enum', 'status_op', ',EQ,NE,IN'),
              ('enum', 'cond_op', ',EQ,NE,GT,LT,GE,LE,IN'), ('table', 'tabname'),
              ('field', 'date_field', 'tabname'), ('field', 'bukrs_field', 'tabname'),
              ('field', 'status_field', 'tabname'), ('field', 'cond_field', 'tabname')]),
            ('zca_ops_tabwl', 'ApprovedTable', 'zca_d_tabwl', 'Approved table', 'Tables approved for aggregate checks', [],
             [('area', 'area', False), ('table', 'table_name'),
              ('valid', 'approved_by', 'zcl_ca_ops_cfg_checks=>user_valid', 'user_invalid')]),
            # SAP job monitor (2026-11-11): jobs of the external workload scheduler and the SAP job names they
            # start (PCRE, complete name) - the board shows scheduler job -> SAP parent job -> failed child
            ('zca_ops_jobsch', 'SchedulerJob', 'zca_d_jobsch', 'Scheduler job', 'Scheduler jobs and SAP job names', [],
             [('pcre', 'sap_pattern'), ('enum', 'criticality', 'H,M,L')]),
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
          'guidance': 'Guidance for the reviewer',
          # Process onboarding (2026-11-10)
          'process_id': 'Business process', 'auth_role': 'Role (PFCG) granting ZCA_OPS for the area',
          'own_data': 'Writes own tables (purge target required)', 'purge_target': 'Purge target of own tables',
          'sched_group': 'Schedule group (run variant)',
          'bukrs_aware': 'Reports per company code', 'agg_id': 'Aggregate ID (rule ID of the findings)',
          'tabname': 'Table (approved for the area)', 'agg_func': 'Function (COUNT or AGE)',
          'date_field': 'Date field (AGE counts from it)', 'min_age_days': 'Minimum age (days)',
          'bukrs_field': 'Company-code field (one result each)', 'status_field': 'Status field',
          'status_op': 'Status operator (EQ, NE, IN)', 'status_value': 'Status value(s)',
          'cond_field': 'Condition field', 'cond_op': 'Condition operator', 'cond_value': 'Condition value(s)',
          'amber': 'Amber limit (rows or days, 0 = none)', 'red': 'Red limit (rows or days, 0 = none)',
          'check_code': 'Check code of the findings', 'table_name': 'Table',
          'approved_by': 'Approved by (reviewer)',
          # SAP job monitor (2026-11-11)
          'sched_folder': 'Scheduler folder', 'sched_job': 'Scheduler job',
          'sap_pattern': 'SAP job names (PCRE, complete name)', 'criticality': 'Criticality (H / M / L)'}

_engine.configure(ROOT=ROOT, SPEC=SPEC, RENAME={}, TOKENS=TOKENS, LABELS=LABELS)


def __getattr__(name):
    """The engine's functions and state (templates, CONST, localize, ...), configured for the framework."""
    return getattr(_engine, name)


if __name__ == '__main__':
    _engine.main()
