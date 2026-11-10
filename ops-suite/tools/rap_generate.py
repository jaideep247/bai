#!/usr/bin/env python3
"""Generate the suite's RAP configuration apps (design 5, docs/RAP_Apps_Design.md) from the
customizing-table DDLs: EBS, FMON, HCK and approved tables (prefix CD).

Wrapper of the shared engine ../../tools/abaptools/rap_generate.py (shape, outputs and check kinds
described there); this file is the suite's profile: the apps (SPEC), element renames, label tokens
and labels. The operations framework's own app ZUI_CA_OPS_CFG is generated from ops-framework
(its tools/rap_generate.py).

Usage: python3 tools/rap_generate.py [--check]

Modification log:
2026-11-06 | Initial version (RAP configuration apps, design 5).
2026-11-10 | Generator parameterised for the framework ZCA_OPS (app framework written into the framework).
2026-11-10 | The engine moved to the shared tools (tools/abaptools); this file is the suite's profile; the
           | framework's app moved to the framework's own wrapper.
2026-11-10 | Payment lifecycle stages (ZCD_OPS_PAYSTAGE) in the core app (overview page, control center).
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, '..', 'tools'))
import abaptools  # noqa: E402

_engine = abaptools.fresh('rap_generate', 'ops_suite')
BLANK, FILLED = _engine.BLANK, _engine.FILLED

SEV = 'B,E,W,I'
# Stages a clock-time deadline may name (ZCD_FMON_SLA kind DEADLINE): inbound receipt / import / processing,
# outbound generation / bank acknowledgement (one constant line of the pool: at most 84 characters)
DEADLINE_STAGES = 'FILE_RECEIVED,FILE_LOADED,FULLY_PROCESSED,GENERATED_IN_SAP,ACK_RECEIVED'
ACTIONS = 'AUTO_POST,EXCEPTION,BLOCK,NOTIFY,ON_ACCOUNT'
# Customer posting areas (user decision 2026-11-08): ZCD_BTC_MAP, ZCD_EBS_RSN_MAP, ZCD_HCK_PMCLASS and
# ZCD_HCK_BTCROLE are FI-CA customer posting areas ZBTM, ZRSN, ZPMC, ZBTR maintained in FQC0 - no app
# entity; their checks are the configuration check ZCL_CD_OPS_CFG_CHECKS=>CHECK_POSTING_AREAS
# (morning report D_POSTAREA_INVALID). Rule groups of ZBTM are checked there against ZCD_BTC_RULE.
SPEC = {
    'ebs': dict(
        folder='ebs', pe_area='CD_EBS', root='EbsCfgAll', draft='zcd_d_ebscfg', service='ZUI_CD_EBS_CFG',
        title='EBS rules and mapping', tables=[
            ('zcd_btc_rule', 'BtcRule', 'zcd_d_btcrule', 'Rule assignment', 'Rule assignments', [],
             [('enum', 'severity', ',' + SEV), ('enum', 'action', ',' + ACTIONS)]),
            ('zcd_ebs_rule_def', 'RuleDef', 'zcd_d_ruledef', 'Rule', 'Rule registry', [],
             [('class', 'class_name', 'ZIF_CD_EBS_RULE'), ('enum', 'rule_level', 'L,S'),
              ('enum', 'default_severity', SEV), ('enum', 'default_action', ACTIONS),
              ('enum', 'finding_class', ',DUPLICATE,POSTING')]),
            ('zcd_ebs_acct', 'HouseBankAcct', 'zcd_d_ebsacct', 'House bank account', 'House bank accounts', [],
             [('enum', 'flow_default', ',D,C')]),
            ('zcd_ebs_flow_pat', 'FlowPattern', 'zcd_d_flowpat', 'Flow pattern', 'Flow patterns (XBLNR)',
             ['priority'], [('enum', 'flow_type', 'D,C'), ('pcre', 'pattern')]),
            ('zcd_ebs_lookup', 'EbsLookup', 'zcd_d_ebslkp', 'Lookup (rule R21)', 'Lookups (rule R21)', [],
             [('enum', 'key_kind', 'DOCNO,ZTNUM,REFERENCE'), ('table', 'table_name'),
              ('field', 'key_field', 'table_name'), ('field', 'status_field', 'table_name'),
              ('approved', 'key_field', 'table_name'), ('approved', 'status_field', 'table_name')]),
        ]),
    'fmon': dict(
        folder='fmon', pe_area='CD_FMON', root='FmonCfgAll', draft='zcd_d_fmoncfg', service='ZUI_CD_FMON_CFG',
        title='File monitoring setup', tables=[
            ('zcd_fmon_iface', 'FmonIface', 'zcd_d_fmiface', 'Interface', 'Interfaces', [],
             [('enum', 'direction', 'I,O'), ('pcre', 'name_pattern')]),
            # Table consolidation 2026-11-08: a stage by a duration or by a clock time of a business day
            # (user requirement 2026-11-07, was ZCD_FMON_DEADL) - one table, KIND says which
            ('zcd_fmon_sla', 'FmonSla', 'zcd_d_fmsla', 'Stage SLA', 'Stage SLAs (duration or deadline)', [],
             [('enum', 'kind', 'DURATION,DEADLINE'), ('enum', 'severity', ',' + SEV),
              ('when', 'kind', 'DURATION', [('positive', 'max_minutes'), ('enum', 'basis', ',P,G'),
                                            ('enum', 'day_type', '*'), ('blank', 'due_time')]),
              ('when', 'kind', 'DEADLINE', [('required', 'due_time'), ('enum', 'stage', DEADLINE_STAGES),
                                            ('enum', 'day_type', 'NORMAL,MONTH_END,RETURNS_DAY,*'),
                                            ('blank', 'max_minutes'), ('blank', 'basis')])]),
            ('zcd_fmon_src', 'FmonSource', 'zcd_d_fmsrc', 'Source adapter', 'Source adapters', [],
             [('table', 'table_name')] + [('field', f, 'table_name') for f in (
                 'file_key_field', 'file_name_field', 'date_field', 'time_field', 'ts_field', 'status_field',
                 'count_field', 'amount_field', 'size_field', 'checksum_field', 'source_field', 'lob_field',
                 'item_key_field')]
             + [('class', 'adapter_class', 'ZIF_CD_FMON_ADAPTER')]),
            ('zcd_fmon_srcmap', 'FmonSourceMap', 'zcd_d_fmsrcmap', 'Status mapping', 'Status mappings',
             ['status_value'], []),
            ('zcd_fmon_chk', 'FmonCheck', 'zcd_d_fmchk', 'Check', 'Checks', [],
             [('class', 'class_name', 'ZIF_CD_FMON_CHECK'), ('enum', 'severity', ',' + SEV)]),
            ('zcd_fmon_lotcfg', 'FmonLotCfg', 'zcd_d_fmlotcfg', 'Lot configuration', 'Returns / NOC lots', [],
             [('table', 'hdr_table'), ('table', 'item_table'),
              ('field', 'hdr_lot_field', 'hdr_table'), ('field', 'hdr_link_field', 'hdr_table'),
              ('field', 'item_lot_field', 'item_table'), ('field', 'item_key_field', 'item_table'),
              ('field', 'item_status_field', 'item_table'), ('field', 'item_link_field', 'item_table'),
              ('enum', 'link_by', ',N,R')]),
            ('zcd_fmon_cal', 'FmonCalendar', 'zcd_d_fmcal', 'Expected files', 'Expected files per day type', [],
             [('window', 'window_from', 'window_to')]),
        ]),
    'hck': dict(
        folder='hck', pe_area='CD_HCK', root='HckCfgAll', draft='zcd_d_hckcfg', service='ZUI_CD_HCK_CFG',
        title='Health check setup', tables=[
            ('zcd_hck_def', 'HckCheckDef', 'zcd_d_hckdef', 'Check', 'Checks', [],
             [('class', 'class_name', 'ZIF_CD_HCK_CHECK'), ('enum', 'category', 'A,B,C,D,E'),
              ('enum', 'priority', 'H,M,L')]),
            ('zcd_hck_thresh', 'HckThreshold', 'zcd_d_hckthr', 'Threshold', 'Thresholds', [],
             [('thresholds',), ('enum', 'baseline_mode', ',NONE,ZSCORE')]),
            ('zcd_hck_agg', 'HckAggregate', 'zcd_d_hckagg', 'Aggregate', 'Generic aggregates', [],
             [('table', 'tabname'), ('field', 'sum_field', 'tabname'), ('field', 'date_field', 'tabname'),
              ('field', 'group_field', 'tabname'), ('field', 'cond1_field', 'tabname'),
              ('field', 'cond2_field', 'tabname'), ('field', 'cond3_field', 'tabname'),
              ('enum', 'agg_func', 'COUNT,SUM'), ('enum', 'date_mode', ',AGE,DAY'),
              ('enum', 'cond1_op', ',EQ,NE,GT,LT,GE,LE,IN'), ('enum', 'cond2_op', ',EQ,NE,GT,LT,GE,LE,IN'),
              ('enum', 'cond3_op', ',EQ,NE,GT,LT,GE,LE,IN'),
              # Audit A103: expected groups of a grouped aggregate (silent group = measured 0) - one
              # comma list on the row since the table consolidation of 2026-11-08 (was ZCD_HCK_AGGGRP)
              ('valid', 'expected_groups', 'zcl_cd_hck_agg_query=>group_list_valid', 'group_list_invalid'),
              ('when', 'group_field', BLANK, [('blank', 'expected_groups')])]),
            ('zcd_job_cycle', 'JobCycle', 'zcd_d_jobcyc', 'Job cycle', 'Job cycles', [], []),
            ('zcd_job_step', 'JobStep', 'zcd_d_jobstep', 'Job step', 'Job cycle steps', [],
             [('window', 'window_from', 'window_to'), ('pcre', 'jobname')]),
            # User rules 2026-11-07 (in-flight check A_INFLIGHT): evidence rules and role-sequence
            # outcomes keyed by flow + method class (an open list: a new class is rows in these tables
            # and entries of the posting areas ZPMC / ZBTR, never a code or domain change)
            ('zcd_hck_clrrule', 'HckClrRule', 'zcd_d_hckclr', 'Evidence rule', 'Clearing / return evidence rules',
             [], [('enum', 'flow', 'D,C'), ('enum', 'purpose', 'CLEARED,RETURNED,RETRIEVED,VOIDED,PENDING,IN_FLIGHT'),
                  ('enum', 'required', ',X,C,N'), ('class', 'evidence_class', 'ZIF_CD_HCK_EVIDENCE')]),
            ('zcd_hck_seqout', 'HckSeqOutcome', 'zcd_d_hckseqo', 'Sequence outcome', 'Role sequence outcomes', [],
             [('enum', 'flow', 'D,C'), ('pcre', 'seq_pattern'), ('enum', 'expected_dfkkrp', ',0,1,2,3,4,5,6,7,8,9'),
              ('enum', 'severity', ',' + SEV),
              # Code review 2026-11-07: register state tokens and the outcome finding catalogue
              ('valid', 'reg_state', 'zcl_cd_hck_ev_support=>reg_state_valid', 'reg_state_invalid'),
              ('valid', 'finding', 'zcl_cd_hck_ev_support=>outcome_finding_valid', 'finding_invalid')]),
            # Three-way reconciliation A_RECON_3WAY (2026-11-07): clearing account sets and the role of
            # each bank code per set (leg, deposit, buckets); open lists of configuration
            ('zcd_hck_rcset', 'HckReconSet', 'zcd_d_hckrcset', 'Reconciliation set',
             'Reconciliation clearing account sets', [],
             [('enum', 'kind', 'THREEWAY,ACH_ZUONR,STRIPE'), ('enum', 'side', 'C,D')]),
        ]),
    'core': dict(
        folder='core', pe_area='CD_OPS', root='OpsCfgAll', draft='zcd_d_opscfg', service='ZUI_CD_OPS_CFG',
        title='Approved tables and payment stages', tables=[
            # Runtime parameters are maintained in the framework app ZUI_CA_PARAM (ZCA_PARAM), not here -
            # also the stale threshold per monitor (MON_STALE_AFTER_MIN_<area>, was ZCD_OPS_MONCFG, 2026-11-08).
            # Alert rules and channels are the framework's app (ZUI_CA_OPS_CFG, 2026-11-10).
            # Table consolidation 2026-11-08: one approved-table list for every dynamic reader (was
            # ZCD_FMON_TABWL, ZCD_HCK_TABWL, ZCD_HCK_DRIFT) - a cross-area security boundary, so it
            # lives in the core app; area + purpose say which reader may use a row
            ('zcd_ops_tabwl', 'ApprovedTable', 'zcd_d_opstabwl', 'Approved table', 'Approved tables per reader',
             ['field_name'],
             [('enum', 'pe_area', 'CD_FMON,CD_HCK,CD_EBS'),
              ('when', 'pe_area', 'CD_FMON', [('enum', 'purpose', 'SOURCE')]),
              ('when', 'pe_area', 'CD_HCK', [('enum', 'purpose', 'READ,DRIFT'), ('blank', 'field_name')]),
              # EBS lookup rule R21 (2026-11-10): approved per field (key and status field of ZCD_EBS_LOOKUP)
              ('when', 'pe_area', 'CD_EBS', [('enum', 'purpose', 'LOOKUP'), ('required', 'field_name')]),
              ('table', 'table_name'), ('field', 'field_name', 'table_name')]),
            # Payment lifecycle card of the overview page (2026-11-10): stage order and labels are
            # configuration; the counts are read live from DPAYH and the worklist
            ('zcd_ops_paystage', 'PayStage', 'zcd_d_paystage', 'Payment stage', 'Payment lifecycle stages', [],
             [('enum', 'source', 'PAYRUN,REQUEST'),
              ('when', 'active', 'X', [('required', 'match_value'), ('required', 'label')])]),
        ]),
}

# Element names that would collide with RAP / BDEF keywords
RENAME = {'action': 'ActionCode',
          'pe_area': 'PaymentEngineArea'}  # pe_area: design D-6
TOKENS = {'btc': 'BTC', 'bai2': 'BAI2', 'cdi': 'credit/debit', 'id': 'ID', 'sla': 'SLA', 'noc': 'NOC',
          'fica': 'payment engine', 'ts': 'timestamp', 'lob': 'line of business', 'hbkid': 'house bank',
          'hktid': 'account ID', 'bukrs': 'company code', 'iface': 'interface', 'src': 'source',
          'hdr': 'header', 'agg': 'aggregate', 'func': 'function', 'cond1': 'condition 1',
          'cond2': 'condition 2', 'cond3': 'condition 3', 'op': 'operator', 'tabname': 'table',
          'fcal': 'factory calendar', 'pred': 'predecessor', 'no': 'number', 'seq': 'sequence',
          'param1': 'parameter 1', 'param2': 'parameter 2', 'param3': 'parameter 3', 'param4': 'parameter 4',
          'params': 'parameters', 'min': 'minimum', 'max': 'maximum', 'dest': 'destination',
          'rag': 'RAG', 'xblnr': 'XBLNR', 'gl': 'G/L', 'z': 'Z', 'exp': 'expected', 'chn': 'channel',
          'msg': 'message', 'pay': 'payment', 'ret': 'return', 'rsn': 'reason', 'lot': 'lot'}
LABELS = {'pe_area': 'Payment engine area',  # design D-6
          # Framework app (2026-11-10): the area is a parameter area of ZCA_PARAM
          'area': 'Area (* = every area)', 'param_area': 'Area of the retention parameter',
          'param_name': 'Retention parameter (ZCA_PARAM)', 'target': 'Purge target',
          'last_changed_by': 'Last changed by', 'last_changed_at': 'Last changed at',
          'local_last_changed_at': 'Changed at (instance)', 'changed_by': 'Changed by (SM30)',
          'changed_at': 'Changed at (SM30)', 'flow_type': 'Flow (D/C/*)', 'exp_cdi': 'Expected direction',
          'bank_key': 'Bank key (blank = all banks)', 'action': 'Action', 'z_limit': 'Z-score limit',
          'higher_is_worse': 'Higher is worse', 'is_noc': 'NOC reason', 'ack_level': 'ACK level',
          # User decision 2026-11-06: ZCD_EBS_ACCT-ACCOUNT_NO is the payment engine bank account as
          # derived from FEBEP-XBLNR (bank text removed, first 10 characters) - EBS scope
          'account_no': 'Payment engine account (XBLNR, 10 characters)',
          # In-flight check configuration (user rules 2026-11-07)
          'pay_methods': 'Payment methods (comma list)', 'age_basis': 'Ageing basis',
          'required': 'Required (X must hold, C condition, N must not hold)', 'evidence_class': 'Evidence class',
          'compare_amount': 'Compare amount (X returns lot, R payment, C correction)', 'reg_state': 'Register state (cheque, blank = any)',
          'finding': 'Finding code of the outcome (blank = none)',
          'seq_pattern': 'Role sequence (PCRE, whole value)',
          'expected_dfkkrp': 'Returns lot items expected (blank = not checked)',
          'max_age_days': 'Maximum age of a pending outcome (days)',
          # Regenerated files (user 2026-11-07): payment run of a file, e.g. LAUFD,LAUFI,HBKID
          'group_fields': 'Generation group fields (comma list)',
          # Three-way reconciliation (A_RECON_3WAY, 2026-11-07)
          'invert_bank': 'Invert bank sign (leg mapping)', 'leg_bank': 'Compare bank with G/L',
          'leg_fica': 'Compare G/L with payment engine control total',
          # Table consolidation 2026-11-08
          'usage': 'Usage (LIFECYCLE / RECON)',
          'scope': 'Scope (lifecycle: flow + method class; recon: set ID)',
          'purpose': 'Purpose (FMON: SOURCE; HCK: READ / DRIFT)',
          'field_name': 'Field (blank = whole table)',
          # Payment lifecycle stages (2026-11-10)
          'stage': 'Stage', 'label': 'Label of the stage',
          'source': 'Counted from (PAYRUN / REQUEST)',
          'match_value': 'Payment status (PAYRUN) / worklist outcome or stage (REQUEST)'}

_engine.configure(ROOT=ROOT, SPEC=SPEC, RENAME=RENAME, TOKENS=TOKENS, LABELS=LABELS)


def __getattr__(name):
    """The engine's functions and state (templates, CONST, localize, ...), configured for the suite."""
    return getattr(_engine, name)


if __name__ == '__main__':
    _engine.main()
