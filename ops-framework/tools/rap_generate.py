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
2026-11-11 | Payment model: dimension texts (ZCA_OPS_PMDIM) and feeder systems with deep-link URL template
           | (ZCA_OPS_FEEDER, check url_invalid).
2026-11-11 | SAP job monitor: scheduler jobs and the SAP job names they start (pattern checked on save).
2026-11-11 | Operations response features: runbook links per check (link of an active row, 439), alert
           | correlation rules (patterns 418, key fields 153, window 154), escalation fields of alert rules
           | (severity floor).
2026-11-11 | Link registry: layers, objects, fields (table 082 / field 083 checks), links, conditions (field
           | references TABLE-FIELD 225, kind-dependent fields 235 / 236) and activation overrides.
2026-11-11 | Process catalogue: packages, processes, steps, tables (table 082 check), dependencies and the
           | activation per customer (reason, approver 240: a user of the client other than the user saving);
           | business processes name their catalogue process; aggregate rows: window MAX_AGE_DAYS, time field
           | (083 check), operator NI (none of a list).
2026-11-11 | Clearing-account break analysis: accounts, buckets, bucket rules (PCRE account pattern, bucket required)
           | and their conditions (kind, operator, LINK needs its link); pilot detection baselines per check.
2026-11-15 | Account flow reconciliation: flows, accounts by role (role, line source, plug-in class of what checks
           | account for), stages (expected roles, reserved rows 340), tiles fed by stage rows, stage controls and
           | ordered stage rules (criteria of the rule's line source only).
2026-11-15 | Licensing (docs/LICENSING.md): activation (ACTIVE = X) of a row of an unlicensed module refused on save
           | (message 350, only under LIC_ENFORCE = X): controls, aggregate rows, approved tables, scheduler jobs,
           | runbook links, correlation rules, customer link layers, break accounts, flows (check kind 'module'); a
           | business process / catalogue activation by its catalogue process, a registered check by its class, a
           | catalogue package by its module ('valid' with the *_LICENSED checks). Deactivation is always allowed.
2026-11-15 | Payment file lifecycle (docs/PAYMENT_FILE_LIFECYCLE.md): file types (ACK level, calendar, time zone,
           | cut-off, expectation; module CASH_OPS), milestones (product vocabulary, clock / offset deadlines), status
           | mappings (an outcome needs a milestone) and adapters (class of ZIF_CA_OPS_PF_ADAPTER, role, source).
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('rap_generate', 'ops_framework')
FILLED = _engine.FILLED

SEV = 'B,E,W,I'
# Account flow reconciliation (2026-11-15): roles of an account, stage IDs the dashboard reserves (a rule may name
# OTHER - a rule that sends lines to the row OTHER on purpose - but none of the position rows)
FLOW_ROLES = 'RECEIVABLE,PAYABLE,OUTSIDE,SETTLEMENT,CLEARING,CASH,CLARIFICATION'
FLOW_RESERVED = 'OTHER,MOVEMENT,OPENING,CLOSING,UNEXPLAINED'
FLOW_RESERVED_RULE = 'MOVEMENT,OPENING,CLOSING,UNEXPLAINED'
PF_MILESTONES = 'PAYRUN,GENERATED,PICKUP,DELIVERED,RECEIPT,ACCEPTED,SETTLED'

SPEC = {
    # The framework's own app (2026-11-10): sub-package ZCA_OPS_UI (folder ui), prefix CA, messages of
    # class ZCA_OPS, area CA_OPS
    'framework': dict(
        ddic='', draft_ddic='ui', prefix='ca',
        folder='ui', area='CA_OPS', root='OpsCfgAll', draft='zca_d_opscfg', service='ZUI_CA_OPS_CFG',
        title='Processes, checks, alerting, purge targets and controls', tables=[
            ('zca_ops_alrule', 'AlertRule', 'zca_d_alrule', 'Alert rule', 'Alert rules', [],
             [('area', 'area', True), ('enum', 'min_severity', ',' + SEV),
              ('enum', 'min_rag', ',R,A,G'), ('window', 'quiet_from', 'quiet_to'),
              ('pcre', 'rule_pattern'), ('pcre', 'check_pattern'), ('pcre', 'group1_pattern'),
              ('pcre', 'group2_pattern'), ('pcre', 'bukrs_pattern'),
              ('dest', ('channel', 'channel'), 'destination', 'escalation_dest'),
              ('enum', 'esc_severity', ',' + SEV)]),
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
              ('valid', 'runbook_url', 'zcl_ca_ops_cfg_checks=>url_valid', 'url_invalid'),
              ('when', 'active', 'X', [('module', 'CONTROL')])]),
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
              ('valid', 'runbook_url', 'zcl_ca_ops_cfg_checks=>url_valid', 'url_invalid'),
              ('when', 'active', 'X', [('valid', 'cat_process', 'zcl_ca_ops_cfg_checks=>cat_process_licensed',
                                        'license_refused')])]),
            ('zca_ops_check', 'RegisteredCheck', 'zca_d_check', 'Check', 'Registered checks', [],
             [('area', 'area', False), ('class', 'class_name', 'ZIF_CA_OPS_CHECK'),
              ('when', 'active', 'X', [('valid', 'class_name', 'zcl_ca_ops_cfg_checks=>class_licensed',
                                        'license_refused')])]),
            ('zca_ops_agg', 'AggregateCheck', 'zca_d_agg', 'Aggregate', 'Aggregate checks (no code)', [],
             [('area', 'area', False), ('enum', 'agg_func', 'COUNT,AGE'), ('enum', 'status_op', ',EQ,NE,IN,NI'),
              ('enum', 'cond_op', ',EQ,NE,GT,LT,GE,LE,IN,NI'), ('table', 'tabname'),
              ('field', 'date_field', 'tabname'), ('field', 'time_field', 'tabname'), ('field', 'bukrs_field', 'tabname'),
              ('field', 'status_field', 'tabname'), ('field', 'cond_field', 'tabname'),
              ('when', 'active', 'X', [('module', 'ONBOARD')])]),
            ('zca_ops_tabwl', 'ApprovedTable', 'zca_d_tabwl', 'Approved table', 'Tables approved for aggregate checks', [],
             [('area', 'area', False), ('table', 'table_name'),
              ('valid', 'approved_by', 'zcl_ca_ops_cfg_checks=>user_valid', 'user_invalid'),
              ('when', 'active', 'X', [('module', 'ONBOARD')])]),
            # Payment model (2026-11-11): texts / order of the dimension values and the feeder systems with their
            # deep-link URL template (read by the consumers' generated payment model CDS)
            ('zca_ops_pmdim', 'PaymDimText', 'zca_d_pmdim', 'Dimension text', 'Payment model dimension texts', [],
             [('enum', 'dimension', 'FLOW,SOURCE,TRANSACTION,REQ_STATUS,PAY_STATUS,METHOD_CLASS,DOC_EVENT')]),
            ('zca_ops_feeder', 'PaymFeeder', 'zca_d_feeder', 'Feeder system', 'Feeder systems of the payment model', [],
             [('valid', 'url_template', 'zcl_ca_ops_cfg_checks=>url_valid', 'url_invalid')]),
            # SAP job monitor (2026-11-11): jobs of the external workload scheduler and the SAP job names they
            # start (PCRE, complete name) - the board shows scheduler job -> SAP parent job -> failed child
            ('zca_ops_jobsch', 'SchedulerJob', 'zca_d_jobsch', 'Scheduler job', 'Scheduler jobs and SAP job names', [],
             [('pcre', 'sap_pattern'), ('enum', 'criticality', 'H,M,L'),
              ('when', 'active', 'X', [('module', 'JOBS')])]),
            # Operations response features (2026-11-11): runbook link per check (exact values, as covered checks;
            # an active row needs its link) and alert correlation rules (key fields, PCRE, window)
            ('zca_ops_runbook', 'RunbookLink', 'zca_d_runbook', 'Runbook link', 'Runbook links per check', [],
             [('area', 'area', False), ('enum', 'match_field', 'RULE_ID,CHECK_CODE,GROUP2'),
              ('when', 'active', 'X', [('valid', 'runbook_url', 'zcl_ca_ops_cfg_checks=>link_valid', 'url_invalid')]),
              ('when', 'active', 'X', [('module', 'RESPONSE')])]),
            ('zca_ops_corr', 'CorrelationRule', 'zca_d_corr', 'Correlation rule', 'Alert correlation rules', [],
             [('area', 'area', False), ('pcre', 'check_pattern'), ('pcre', 'key_pattern'),
              ('valid', 'key_fields', 'zcl_ca_ops_cfg_checks=>key_fields_valid', 'corr_fields_invalid'),
              ('valid', 'window_min', 'zcl_ca_ops_cfg_checks=>window_min_valid', 'corr_window_invalid'),
              ('when', 'active', 'X', [('module', 'RESPONSE')])]),
            # Link registry (2026-11-11): layers, business objects and their fields (checked against the runtime
            # DDIC), links with their conditions (TABLE-FIELD references) and activation overrides of a customer
            # layer; cross-row rules (prefixes, cycles, cardinality, evidence) are the registry check's
            # (ZCL_CA_OPS_CHK_LINKS) and the offline validator's (tools/link_registry.py)
            ('zca_ops_lnklyr', 'LinkLayer', 'zca_d_lnklyr', 'Link layer', 'Link registry layers', [],
             [('enum', 'layer_kind', 'S,I,C'),
              ('when', 'layer_kind', 'C', [('when', 'active', 'X', [('module', 'LINKS')])])]),
            ('zca_ops_lnkobj', 'LinkObject', 'zca_d_lnkobj', 'Object', 'Link registry business objects', [],
             [('table', 'source_name'), ('enum', 'source_kind', 'T,V')]),
            ('zca_ops_lnkfld', 'LinkField', 'zca_d_lnkfld', 'Field', 'Link registry object fields', [],
             [('table', 'source_name'), ('field', 'field_name', 'source_name'), ('enum', 'sensitivity', ',M,H'),
              ('enum', 'evidence', 'C,V'), ('when', 'evidence', 'V', [('required', 'verify_ref')])]),
            ('zca_ops_link', 'Link', 'zca_d_link', 'Link', 'Link registry links', [],
             [('enum', 'cardinality', '11,1N,N1,NM'), ('enum', 'quality', 'C,P')]),
            ('zca_ops_lnkcnd', 'LinkCondition', 'zca_d_lnkcnd', 'Condition', 'Link registry link conditions', [],
             [('enum', 'cond_kind', 'EQ,CONST,NOTINIT,PREFER'),
              ('enum', 'transform', ',ALPHA,NOZERO,UPPER,LEFT,RIGHT,PREFIX,SUFFIX'),
              ('valid', 'to_ref', 'zcl_ca_ops_cfg_checks=>field_ref_valid', 'link_ref_invalid'),
              ('valid', 'from_ref', 'zcl_ca_ops_cfg_checks=>field_ref_valid', 'link_ref_invalid'),
              ('when', 'cond_kind', 'EQ', [('required', 'from_ref'), ('required', 'to_ref')]),
              ('when', 'cond_kind', 'CONST,PREFER', [('required', 'cond_value'), ('blank', 'from_ref'),
                                                     ('blank', 'transform')]),
              ('when', 'cond_kind', 'NOTINIT', [('blank', 'cond_value'), ('blank', 'from_ref'),
                                                ('blank', 'transform')])]),
            ('zca_ops_lnkact', 'LinkActivation', 'zca_d_lnkact', 'Activation', 'Link registry activation overrides', [],
             [('enum', 'target_kind', 'L,K'), ('when', 'target_kind', 'L,K', [('required', 'reason')])]),
            # Process catalogue (2026-11-11): packages, SAP standard processes with their steps, tables and
            # dependencies, and the activation per customer (effective from a date, reason, approver - four-eyes);
            # cross-row rules (prefixes, ranks, dependency cycles, links of the registry) are the catalogue check's
            # (ZCL_CA_OPS_CHK_ONBOARD) and the offline validator's (tools/process_catalogue.py)
            ('zca_ops_catpkg', 'CatalogPackage', 'zca_d_catpkg', 'Package', 'Process catalogue packages', [],
             [('enum', 'pkg_kind', 'S,I,C'), ('area', 'mon_area', False),
              ('when', 'active', 'X', [('valid', 'pkg_id', 'zcl_ca_ops_cfg_checks=>package_licensed',
                                        'license_refused')])]),
            ('zca_ops_catprc', 'CatalogProcess', 'zca_d_catprc', 'Process', 'Process catalogue processes', [],
             [('enum', 'evidence', 'C,V'), ('when', 'evidence', 'V', [('required', 'verify_ref')])]),
            ('zca_ops_catstp', 'CatalogStep', 'zca_d_catstp', 'Step', 'Process catalogue steps', [],
             [('enum', 'step_kind', 'T,P,M,J,E'), ('enum', 'evidence', 'C,V'),
              ('when', 'evidence', 'V', [('required', 'verify_ref')])]),
            ('zca_ops_cattab', 'CatalogTable', 'zca_d_cattab', 'Table', 'Process catalogue tables', [],
             [('when', 'evidence', 'C', [('table', 'tabname')]), ('enum', 'tab_role', 'H,I,L,S,C'),
              ('enum', 'evidence', 'C,V'), ('when', 'evidence', 'V', [('required', 'verify_ref')])]),
            ('zca_ops_catdep', 'CatalogDependency', 'zca_d_catdep', 'Dependency', 'Process catalogue dependencies', [],
             [('enum', 'dep_kind', 'H,S')]),
            ('zca_ops_catact', 'CatalogActivation', 'zca_d_catact', 'Activation', 'Process catalogue activation', [],
             [('when', 'valid_from', FILLED, [('required', 'reason'), ('required', 'pkg_id'),
                                                ('required', 'approved_by')]),
              ('valid', 'approved_by', 'zcl_ca_ops_cfg_checks=>approver_valid', 'approver_invalid'),
              ('when', 'active', 'X', [('valid', 'process_id', 'zcl_ca_ops_cfg_checks=>cat_process_licensed',
                                        'license_refused')])]),
            # Clearing-account break analysis (2026-11-11): accounts, buckets, bucket rules (ordered, first match
            # wins) and their conditions; cross-row rules (bucket of a rule, link of a LINK condition, parameter of
            # an @ value) are the analysis's (ZCL_CA_OPS_BRK_RULES=>VALIDATE, configuration findings) and the offline
            # validator's (tools/checks.py break_rules)
            ('zca_ops_brkacc', 'BreakAccount', 'zca_d_brkacc', 'Account', 'Break analysis clearing accounts', [],
             [('area', 'area', False), ('when', 'active', 'X', [('module', 'BREAKS')])]),
            ('zca_ops_brkbkt', 'BreakBucket', 'zca_d_brkbkt', 'Bucket', 'Break analysis buckets', [], []),
            ('zca_ops_brkrul', 'BreakRule', 'zca_d_brkrul', 'Bucket rule', 'Break analysis bucket rules', [],
             [('area', 'area', True), ('pcre', 'acct_pattern'),
              ('when', 'active', 'X', [('required', 'bucket')])]),
            ('zca_ops_brkcnd', 'BreakCondition', 'zca_d_brkcnd', 'Condition', 'Break analysis rule conditions', [],
             [('area', 'area', True), ('enum', 'cond_kind', 'FIELD,GROUP,DAYS,LINK'),
              ('enum', 'operator', 'EQ,NE,IN,NI,GE,LE,GT,LT,RX,BL,NB,EX,NX'),
              ('when', 'cond_kind', 'LINK', [('required', 'link_id')]),
              ('when', 'cond_kind', 'FIELD,GROUP,DAYS', [('required', 'field'), ('blank', 'link_id')])]),
            # Pilot pack (2026-11-11): the previous detection time per check (baseline of the time to detect)
            ('zca_ops_pilotbl', 'PilotBaseline', 'zca_d_pilotbl', 'Baseline', 'Pilot detection baselines', [],
             [('area', 'area', False)]),
            # Account flow reconciliation (2026-11-15): flows, their accounts by role, stages, the checks that
            # control a stage and the ordered stage rules (first match wins); cross-row rules (stage of a rule, one
            # account per role, criteria of the rule's source) are the evaluation's (ZCL_CA_OPS_FLOW_CONFIG=>VALIDATE)
            # and the offline validator's (tools/checks.py flow_config)
            ('zca_ops_flow', 'AccountFlow', 'zca_d_flow', 'Flow', 'Account flows', [],
             [('area', 'area', False), ('enum', 'direction', ',D,C'),
              ('when', 'active', 'X', [('module', 'FLOW')])]),
            ('zca_ops_flwacc', 'FlowAccount', 'zca_d_flwacc', 'Flow account', 'Account flow accounts by role', [],
             [('area', 'area', False), ('enum', 'role', FLOW_ROLES), ('enum', 'line_source', 'G,F'),
              ('enum', 'eval_category', ',TRANSIT,CLARIFY,OPEN,BANK'),
              ('class', 'eval_class', 'ZIF_CA_OPS_FLOW_SOURCE'),
              ('when', 'active', 'X', [('required', 'bukrs'), ('required', 'hkont_from')])]),
            ('zca_ops_flwstg', 'FlowStage', 'zca_d_flwstg', 'Stage', 'Account flow stages', [],
             [('area', 'area', False),
              ('enum', 'expect_from', ',' + FLOW_ROLES), ('enum', 'expect_to', ',' + FLOW_ROLES),
              ('when', 'active', 'X', [('reserved', 'stage_id', FLOW_RESERVED)]),
              ('when', 'expect_from', FILLED, [('required', 'expect_to')])]),
            ('zca_ops_flwtil', 'FlowTileStage', 'zca_d_flwtil', 'Tile row', 'Account flow tiles from stages', [],
             [('area', 'area', False), ('enum', 'tile', 'REQUESTED,PAID,CLEARED'), ('enum', 'role', FLOW_ROLES),
              ('enum', 'side', 'D,C')]),
            ('zca_ops_flwctl', 'FlowStageControl', 'zca_d_flwctl', 'Stage control', 'Account flow stage controls', [],
             [('area', 'area', False), ('area', 'check_area', False)]),
            ('zca_ops_flwrul', 'FlowStageRule', 'zca_d_flwrul', 'Stage rule', 'Account flow stage rules', [],
             [('area', 'area', False), ('enum', 'line_source', 'G,F'), ('enum', 'debit_credit', ',S,H'),
              ('when', 'active', 'X', [('required', 'stage_id'), ('reserved', 'stage_id', FLOW_RESERVED_RULE)]),
              ('when', 'line_source', 'G', [('blank', 'origin'), ('blank', 'main_trans'), ('blank', 'sub_trans')]),
              ('when', 'line_source', 'F', [('blank', 'ref_type')])]),
            ('zca_ops_pftyp', 'PayFileType', 'zca_d_pftyp', 'File type', 'Payment file types', [],
             [('area', 'area', False), ('enum', 'direction', ',D,C'), ('enum', 'ack_level', 'F,B,P,N'),
              ('when', 'active', 'X', [('module', 'CASH_OPS')])]),
            ('zca_ops_pfstg', 'PayFileMilestone', 'zca_d_pfstg', 'Milestone', 'Payment file milestones', [],
             [('area', 'area', False), ('enum', 'milestone', PF_MILESTONES), ('enum', 'due_kind', ',T,O'),
              ('enum', 'basis', ',' + PF_MILESTONES),
              ('when', 'due_kind', 'O', [('required', 'basis')]),
              ('when', 'due_kind', 'T', [('blank', 'basis')])]),
            ('zca_ops_pfmap', 'PayFileStatusMap', 'zca_d_pfmap', 'Status mapping', 'Payment file status mapping', [],
             [('area', 'area', False), ('enum', 'milestone', ',' + PF_MILESTONES),
              ('enum', 'outcome', 'OK,REJECTED,PARTIAL,FAILED,INFO'),
              ('when', 'outcome', 'OK,REJECTED,PARTIAL,FAILED', [('required', 'milestone')])]),
            ('zca_ops_pfadp', 'PayFileAdapter', 'zca_d_pfadp', 'Adapter', 'Payment file adapters', [],
             [('area', 'area', False), ('enum', 'role', 'FILE,TRANSFER,ACK,SCHED,STMT,TICKET,CALENDAR'),
              ('class', 'class_name', 'ZIF_CA_OPS_PF_ADAPTER'), ('enum', 'source_type', ',SAP,MW,BANK'),
              ('when', 'active', 'X', [('required', 'class_name'), ('required', 'source_id')])]),
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
          # Payment model (2026-11-11)
          'dimension': 'Dimension of the payment model', 'dim_value': 'Value (as the adapter delivers it)',
          'text': 'Text on cards', 'seq': 'Display order', 'feeder': 'Feeder system (source value)',
          'url_template': 'Deep link (https URL, placeholder {REF})',
          'ref_visible': 'Feeder reference shown in full (not sensitive)',
          'approved_by': 'Approved by (reviewer)',
          # SAP job monitor (2026-11-11)
          'sched_folder': 'Scheduler folder', 'sched_job': 'Scheduler job',
          'sap_pattern': 'SAP job names (PCRE, complete name)', 'criticality': 'Criticality (H / M / L)',
          # Operations response features (2026-11-11)
          'first_action': 'First action (one line)', 'corr_rule': 'Correlation rule',
          'key_fields': 'Key fields (finding fields, comma list)', 'key_pattern': 'Key pattern (PCRE, group 1)',
          'window_min': 'Window (minutes from the parent)',
          'esc_after_min': 'Escalate after (minutes open, unassigned)',
          'esc_repeat_min': 'Repeat escalation every (minutes, 0 = once)',
          'esc_max_count': 'Escalations at most (0 = ESC_MAX_DEFAULT)',
          'esc_severity': 'Escalation severity floor (blank = minimum)',
          # Link registry (2026-11-11)
          'layer_id': 'Layer', 'layer_kind': 'Kind (S baseline, I industry, C customer)',
          'layer_rank': 'Rank (higher extends lower)', 'id_prefix': 'ID prefix of objects and links',
          'object_id': 'Business object', 'source_name': 'Table or CDS view',
          'source_kind': 'Source kind (T table, V view)',
          'field_name': 'Field', 'data_element': 'Data element',
          'sensitivity': 'Sensitivity (M masked, H hidden)', 'evidence': 'Evidence (C confirmed, V VERIFY)',
          'verify_ref': 'VERIFY item', 'link_id': 'Link', 'from_object': 'From object', 'to_object': 'To object',
          'cardinality': 'Cardinality (11, 1N, N1, NM)', 'quality': 'Evidence quality (C, P)',
          'fallback_of': 'Fallback of link', 'replaces': 'Replaces link', 'cond_no': 'Condition',
          'cond_kind': 'Kind (EQ, CONST, NOTINIT, PREFER)', 'from_ref': 'From TABLE-FIELD',
          'to_ref': 'To TABLE-FIELD', 'transform': 'Transform (EQ)',
          'transform_arg': 'Transform argument', 'target_kind': 'Target (L layer, K link)',
          'target_id': 'Layer or link switched', 'reason': 'Reason',
          # Process catalogue (2026-11-11)
          'pkg_id': 'Catalogue package', 'pkg_kind': 'Kind (S baseline, I industry, C customer)',
          'pkg_rank': 'Rank (higher extends lower)', 'mon_area': 'Area of the delivered monitoring',
          'component': 'SAP component', 'dash_card': 'Dashboard card', 'owner_role': 'Business owner role',
          'schedule': 'Typical schedule', 'dflt_active': 'Active by default (no activation row)',
          'step_no': 'Step', 'step_kind': 'Kind (T, P, M, J, E)', 'obj_name': 'SAP object',
          'tab_role': 'Role (H, I, L, S, C)', 'link_object': 'Link registry object',
          'pred_id': 'Depends on process', 'dep_kind': 'Dependency (H hard, S soft)',
          'valid_from': 'Effective from', 'approved_on': 'Approved on', 'cat_process': 'Catalogue process',
          'max_age_days': 'Window (days, 0 = none)', 'time_field': 'Time field (with the date field)',
          # Clearing-account break analysis (2026-11-11)
          'acct_id': 'Clearing account ID', 'bukrs': 'Company code', 'hkont': 'G/L clearing account',
          'ledger': 'Ledger (blank = BRK_LEDGER)', 'lookback_days': 'Days before the key date (0 = parameter)',
          'forward_days': 'Days after the key date (0 = parameter)', 'max_groups': 'Groups at most (0 = parameter)',
          'bucket': 'Variance bucket', 'explained': 'Explained (counts as explained)',
          'acct_pattern': 'Accounts (PCRE on the account ID, blank = all)',
          'operator': 'Operator', 'min_count': 'Linked rows needed (EX, 0 = 1)',
          # Pilot pack (2026-11-11)
          'baseline_min': 'Previous detection time (minutes after the event)', 'source': 'Source of the baseline',
          # Account flow reconciliation (2026-11-15)
          'flow_id': 'Account flow', 'direction': 'Direction (D disbursement, C collection)',
          'jrnl_ledger': 'Ledger (blank = FLOW_LEDGER)', 'flow_acct': 'Account (column of the dashboard)',
          'role': 'Role (RECEIVABLE, PAYABLE, OUTSIDE, CLEARING, ...)', 'currency': 'Currency (blank = every currency)',
          'hkont_from': 'G/L account (or first of a range)', 'hkont_to': 'Last G/L account of the range (blank = one)',
          'line_source': 'Lines from (G journal, F FI-CA documents)',
          'eval_class': 'Accounted for by class (blank = not evaluated)',
          'eval_category': 'Tile (TRANSIT, CLARIFY, OPEN, BANK)', 'stage_id': 'Stage',
          'tile': 'Tile (REQUESTED, PAID, CLEARED)', 'side': 'Side (D debit, C credit)',
          'expect_from': 'Expected: clears the open items of role',
          'expect_to': 'Expected: counter-posting on role',
          'rule_seq': 'Sequence (first match wins)', 'ref_type': 'Reference transaction (AWTYP)',
          'doc_type': 'Document type (journal or FI-CA)', 'origin': 'FI-CA origin key',
          'main_trans': 'FI-CA main transaction', 'sub_trans': 'FI-CA sub-transaction',
          'debit_credit': 'Debit / credit (S, H, blank = both)',
          'file_type': 'Payment file type', 'ack_level': 'Bank ACK level (F file, B batch, P payment, N none)',
          'ack_multi': 'One ACK may cover several files', 'calendar_id': 'Factory calendar (SCAL)',
          'time_zone': 'Time zone of the clock times', 'day_cutoff': 'Overnight cut-off (local time)',
          'expected_files': 'Files expected per business day', 'zero_ok': 'A business day without files is valid',
          'stale_min': 'Source stale after (minutes, 0 = PF_STALE_MIN)',
          'open_days': 'Watched for (days, 0 = PF_OPEN_DAYS)',
          'milestone': 'Milestone', 'required': 'Required',
          'due_kind': 'Deadline (T clock time, O offset)', 'due_time': 'Due at (local time)',
          'day_offset': 'Business days after the business date', 'basis': 'Offset from milestone',
          'offset_min': 'Offset (minutes)', 'grace_min': 'Warning for (minutes, 0 = PF_GRACE_MIN)',
          'source_id': 'Source', 'status': 'Native status (exact)', 'outcome': 'Outcome',
          'setting': 'Adapter setting', 'source_type': 'Source type (SAP, MW, BANK)'}

_engine.configure(ROOT=ROOT, SPEC=SPEC, RENAME={}, TOKENS=TOKENS, LABELS=LABELS)


def __getattr__(name):
    """The engine's functions and state (templates, CONST, localize, ...), configured for the framework."""
    return getattr(_engine, name)


if __name__ == '__main__':
    _engine.main()
