#!/usr/bin/env python3
"""CDS <-> ABAP parity: facts that CDS has to hold as literals (CDS cannot read ABAP constants or
ZCA_PARAM) are compared with the named ABAP constant that is their single documented source.

Data-driven: one row of PAIRS per fact. A row names
  name       - what is compared (reported on drift)
  cds        - CDS source file(s) relative to ops-suite/ (a list compares every file)
  pattern    - Python regex with ONE group; every match in each file is compared
  abap       - ABAP source file holding the constant(s)
  constants  - constant path(s): 'gc_struct-component' or 'gc_constant'; several = a set
  mode       - 'equal' (every match equals the constant, times SCALE when given) or
               'set' (the set of all matches in a file equals the set of the constants)
  scale      - optional factor (e.g. 60: CDS seconds against an ABAP value in minutes)
A pattern that matches nothing is drift too: the CDS was changed and the row must follow.

Usage: python3 tools/cds_abap_parity.py  (prints the drift, exit 1 on drift);
portable check 'cds_abap_parity' in tools/portable_checks.py.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

_WINDOW = r"dats_add_days\(\s*\$session\.system_date\s*,\s*-(\d+)\s*,"
_RUN_STATUS = r"status\s*=\s*'(\w)'"
_STALE_FALLBACK = r"coalesce\(\s*Cfg\.stale_after_min\s*,\s*(\d+)\s*\)"

# (name, cds file(s), pattern, abap file, constant(s), mode, scale)
PAIRS = [
    # EBS: payment engine account from FEBEP-XBLNR (user decision 2026-11-06, EBS_VALIDATION.md A0a)
    ('xblnr_bank_text_pcre', 'src/ebs/zi_cd_ebslineacct.ddls.asddls', r"pcre\s*=>\s*'([^']*)'",
     'src/ebs/zif_cd_ebs_types.intf.abap', 'gc_pe_account-bank_text_pcre', 'equal', None),
    ('xblnr_account_length', 'src/ebs/zi_cd_ebslineacct.ddls.asddls',
     r"result_length\s*=>\s*\d+\s*\)\s*,\s*' '\s*\)\s*,\s*(\d+)\s*\)",
     'src/ebs/zif_cd_ebs_types.intf.abap', 'gc_pe_account-length', 'equal', None),
    # Dashboard date windows
    ('ebs_dashboard_window_days',
     ['src/ebs/zi_cd_ebsstmtbase.ddls.asddls', 'src/ebs/zi_cd_ebslineacct.ddls.asddls',
      'src/ebs/zi_cd_ebsrunbase.ddls.asddls', 'src/ebs/zi_cd_ebsfinding.ddls.asddls'], _WINDOW,
     'src/ebs/zif_cd_ebs_types.intf.abap', 'gc_dashboard-window_days', 'equal', None),
    ('hck_dashboard_window_days',
     ['src/hck/zr_cd_hckrun.ddls.asddls', 'src/hck/zi_cd_hckfinding.ddls.asddls',
      'src/hck/zi_cd_hckmetricbase.ddls.asddls'], _WINDOW,
     'src/hck/zif_cd_hck_types.intf.abap', 'gc_dashboard-window_days', 'equal', None),
    ('trx_dashboard_item_window_days',
     ['src/core/zi_cd_trxitem.ddls.asddls', 'cds/zi_cd_trxreqlog.ddls.asddls'], _WINDOW,
     'src/core/zif_cd_ops_types.intf.abap', 'gc_trx_dashboard-item_window_days', 'equal', None),
    ('trx_dashboard_evidence_window_days',
     ['src/core/zr_cd_trxpayrun.ddls.asddls', 'src/core/zi_cd_trxitembank.ddls.asddls',
      'src/core/zi_cd_trxitemenc.ddls.asddls', 'cds/zi_cd_trxacku.ddls.asddls'], _WINDOW,
     'src/core/zif_cd_ops_types.intf.abap', 'gc_trx_dashboard-evidence_window_days', 'equal', None),
    # Credit indicator: no CDS view interprets FEBEP-EPVOZ today; the EBS dashboard CDS test data
    # uses it, so its fixture follows the delivered EBS_FEB_CREDIT_IND default
    ('feb_credit_indicator', 'src/ebs/zcl_cd_ebs_dash_cds_test.clas.testclasses.abap',
     r"lc_credit\s+TYPE\s+c\s+LENGTH\s+1\s+VALUE\s+'(\w)'",
     'src/ebs/zif_cd_ebs_types.intf.abap', 'gc_param_default-feb_credit_ind', 'equal', None),
    # Reversal: clearing reason 05 is the only reversal reason (user decision 2026-11-07)
    ('reversal_clearing_reason', 'src/core/zr_cd_trxflow.ddls.asddls', r"ClearingReason\s*=\s*'(\w+)'",
     'src/core/zif_cd_ops_trace_types.intf.abap', 'gc_reversal_augrd', 'equal', None),
    # Dashboard classification of a rule's findings (ZCD_EBS_RULE_DEF-FINDING_CLASS) and its seed
    ('ebs_finding_class', 'src/ebs/zi_cd_ebsfinding.ddls.asddls', r"_RuleDef\.finding_class\s*=\s*'(\w+)'",
     'src/ebs/zif_cd_ebs_types.intf.abap', ['gc_finding_class-duplicate', 'gc_finding_class-posting'], 'set', None),
    ('ebs_finding_class_seed', 'config/zcd_ebs_rule_def.csv', r",(DUPLICATE|POSTING)$",
     'src/ebs/zif_cd_ebs_types.intf.abap', ['gc_finding_class-duplicate', 'gc_finding_class-posting'], 'set', None),
    # Completed run statuses of the "as of" / KPI views
    ('ebs_completed_run_status',
     ['src/ebs/zi_cd_ebsrunbase.ddls.asddls', 'src/ebs/zi_cd_ebsrunlast.ddls.asddls'], _RUN_STATUS,
     'src/core/zif_cd_ops_types.intf.abap',
     ['gc_run_status-success', 'gc_run_status-warning', 'gc_run_status-error', 'gc_run_status-no_data'],
     'set', None),
    ('fmon_hck_completed_run_status',
     ['src/fmon/zi_cd_fmonrunlast.ddls.asddls', 'src/hck/zi_cd_hckrunlast.ddls.asddls'], _RUN_STATUS,
     'src/core/zif_cd_ops_types.intf.abap',
     ['gc_run_status-success', 'gc_run_status-warning', 'gc_run_status-error'], 'set', None),
    # Stale thresholds: ZCD_OPS_MONCFG row, else the CDS fallback literal = the ABAP default;
    # the delivered seed rows equal them (config/alert_seed.md)
    ('fmon_stale_fallback_minutes', 'src/fmon/zr_cd_fmonasof.ddls.asddls', _STALE_FALLBACK,
     'src/fmon/zif_cd_fmon_types.intf.abap', 'gc_dashboard-stale_after_min', 'equal', None),
    ('ebs_hck_stale_fallback_minutes', ['src/ebs/zr_cd_ebsasof.ddls.asddls', 'src/hck/zr_cd_hckasof.ddls.asddls'],
     _STALE_FALLBACK, 'src/hck/zif_cd_hck_types.intf.abap', 'gc_param_default-max_age_hours', 'equal', 60),
    ('fmon_stale_seed_minutes', 'config/alert_seed.md', r"^\| FMON \| (\d+) \|",
     'src/fmon/zif_cd_fmon_types.intf.abap', 'gc_dashboard-stale_after_min', 'equal', None),
    ('ebs_hck_stale_seed_minutes', 'config/alert_seed.md', r"^\| (?:EBS|HCK) \| (\d+) \|",
     'src/hck/zif_cd_hck_types.intf.abap', 'gc_param_default-max_age_hours', 'equal', 60),
]


def _strip_abap_comment(line):
    return '' if line.lstrip().startswith('*') else line


def abap_constant(text, path):
    """Value of constant 'gc_x' or structured component 'gc_s-comp' in ABAP source text (str),
    None when not found. Quotes ('..' / `..`) are removed."""
    lines = [_strip_abap_comment(l) for l in text.splitlines()]
    if '-' in path:
        struct, comp = path.split('-', 1)
        body, inside = [], False
        for line in lines:
            if re.search(r'\bBEGIN\s+OF\s+' + re.escape(struct) + r'\s*,', line, re.I):
                inside = True
                continue
            if inside and re.search(r'\bEND\s+OF\s+' + re.escape(struct) + r'\b', line, re.I):
                break
            if inside:
                body.append(line)
        regex = r'^\s*' + re.escape(comp) + r'\s+TYPE\s+.*?\bVALUE\s+(.+?)\s*[,.]\s*(?:".*)?$'
    else:
        body = lines
        regex = r'\bCONSTANTS\s+' + re.escape(path) + r'\s+TYPE\s+.*?\bVALUE\s+(.+?)\s*\.\s*(?:".*)?$'
    for line in body:
        m = re.search(regex, line, re.I)
        if m:
            value = m.group(1).strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "'`":
                value = value[1:-1]
            return value
    return None


def _norm(value):
    # numbers compare as numbers; a code with a leading zero ('05') stays text, so '5' <> '05'
    return int(value) if re.fullmatch(r'-?(?:0|[1-9]\d*)', str(value)) else str(value)


def pair_failures(root, pairs):
    """Drift of every pair as a list of text lines (empty = all facts agree)."""
    failures = []
    for name, cds, pattern, abap, constants, mode, scale in pairs:
        cds_files = cds if isinstance(cds, list) else [cds]
        const_list = constants if isinstance(constants, list) else [constants]
        abap_path = os.path.join(root, abap)
        if not os.path.exists(abap_path):
            failures.append(f'{name}: ABAP file {abap} missing')
            continue
        abap_text = open(abap_path, encoding='utf-8').read()
        values = []
        for const in const_list:
            value = abap_constant(abap_text, const)
            if value is None:
                failures.append(f'{name}: constant {const} not found in {abap}')
            else:
                values.append(_norm(value))
        if len(values) != len(const_list):
            continue
        if scale:
            values = [v * scale for v in values]
        for cds_file in cds_files:
            cds_path = os.path.join(root, cds_file)
            if not os.path.exists(cds_path):
                failures.append(f'{name}: CDS file {cds_file} missing')
                continue
            found = [_norm(v) for v in re.findall(pattern, open(cds_path, encoding='utf-8').read(), re.S | re.M)]
            if not found:
                failures.append(f'{name}: pattern not found in {cds_file} (CDS changed - update the pair)')
            elif mode == 'set':
                if set(found) != set(values):
                    failures.append(f'{name}: {cds_file} has {sorted(set(map(str, found)))}, '
                                    f'{abap} {const_list} = {sorted(map(str, values))}')
            else:
                for value in found:
                    if value != values[0]:
                        failures.append(f'{name}: {cds_file} has {value}, {abap} {const_list[0]}'
                                        f'{" x " + str(scale) if scale else ""} = {values[0]}')
    return failures


def failures(root=ROOT):
    return pair_failures(root, PAIRS)


if __name__ == '__main__':
    drift = failures()
    for line in drift:
        print('DRIFT', line)
    print(f'{len(PAIRS)} pairs, {len(drift)} drift(s)')
    sys.exit(1 if drift else 0)
