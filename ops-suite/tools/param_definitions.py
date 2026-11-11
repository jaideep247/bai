#!/usr/bin/env python3
"""
Artifact: tools/param_definitions.py
Purpose:  The suite's runtime parameters in the framework ZCA_PARAM (areas CD_OPS, CD_EBS,
          CD_FMON, CD_HCK, and the suite's own names in the operations framework's area CA_OPS:
          ALERT_<route>, SLA_DAYS_<area>_<severity>, RETENTION_DAYS_<suite purge target>).
          The generator is the shared engine (../../tools/abaptools/param_definitions.py, also used
          by the operations framework's profile); this file is the suite's profile: seed class ZCL_CD_OPS_PARAM_SEED, the prefix table of
          ZCL_CD_OPS_FACTORY=>PARAM_PREFIXES plus the framework's, the run-time names and the code
          defaults of the suite. Same checks (portable check param_definitions_complete).
Usage:    python3 tools/param_definitions.py           -> regenerate the seed class
          python3 tools/param_definitions.py --check   -> report drift / incompleteness, exit 1
Modification log:
2026-11-07 | Initial version (parameters moved to ZCA_PARAM).
2026-11-07 | Default and value rows checked against ALLOWED_PCRE (design review: queue scope C).
2026-11-08 | Table consolidation: generated DEFINITIONS( ) in parts; DEFAULTS may scale a constant.
2026-11-10 | The generator moved to the operations framework (ops-framework/tools/param_definitions.py,
           | configure( )); this file holds the suite's profile. Framework names (ALERT_, SLA_,
           | PURGE_, RETENTION_) read area CA_OPS; the suite's names there are its rows in area CA_OPS.
2026-11-10 | The generator moved to the shared tools (tools/abaptools); own instance of the engine.
2026-11-11 | SHIFT_TIMES_<team> of the framework's shift handover for the teams of CONTROL_TEAMS (suite rows in
           | area CA_OPS, definition = the source of the default).
"""
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(_HERE, '..', '..', 'tools'))
import abaptools  # noqa: E402

_gen = abaptools.fresh('param_definitions', 'ops_suite')

FW = os.path.join('..', 'ops-framework')
FW_TYPES = os.path.join(FW, 'src', 'zif_ca_ops_types.intf.abap')
SEED = os.path.join('src', 'core', 'zcl_cd_ops_param_seed.clas.abap')
ADAPTER = os.path.join('src', 'core', 'zcl_cd_ops_factory.clas.abap')
OPS_TYPES = os.path.join('src', 'core', 'zif_cd_ops_types.intf.abap')
_HCK_TYPES = os.path.join('src', 'hck', 'zif_cd_hck_types.intf.abap')
# Operations response features of the framework (2026-11-11): shift start times per team of the control register
_FW_RESP_TYPES = os.path.join(FW, 'src', 'zif_ca_ops_resp_types.intf.abap')
_FW_CTL_TYPES = os.path.join(FW, 'src', 'zif_ca_ops_ctl_types.intf.abap')
_EBS_TYPES = os.path.join('src', 'ebs', 'zif_cd_ebs_types.intf.abap')
AREA_SOURCES = [
    (ADAPTER, OPS_TYPES, r'prefix\s*=\s*zif_cd_ops_types=>(gc_param_area_prefix-\w+)\s+'
                         r'area\s*=\s*zif_cd_ops_types=>(gc_param_area-\w+)'),
    (os.path.join(FW, 'src', 'zcl_ca_ops_params.clas.abap'), FW_TYPES,
     r'prefix\s*=\s*zif_ca_ops_types=>(gc_param_area_prefix-\w+)\s+area\s*=\s*zif_ca_ops_types=>(gc_param_area)\b'),
]
EXTRA_AREAS_CSV = [os.path.join(FW, 'config', 'param_areas.csv')]
EXTRA_DEFS_CSV = [os.path.join(FW, 'config', 'param_definitions.csv')]

RUNTIME = {
    (FW_TYPES, 'gc_param_prefix-alert'): ('const', _HCK_TYPES, 'gc_param_default-mail_route'),
    (FW_TYPES, 'gc_param_prefix-retention_days'):
        ('struct', os.path.join('src', 'core', 'zcl_cd_ops_purge_target.clas.abap'), 'gc_target', None),
    (FW_TYPES, 'gc_param_prefix-sla_days'):
        ('product', ('struct', OPS_TYPES, 'gc_pe_area', ['ebs', 'file_monitor', 'health_check']),
                    ('struct', FW_TYPES, 'gc_severity', ['block', 'error', 'warning'])),
    # Monitor freshness per area (table consolidation 2026-11-08, was ZCD_OPS_MONCFG)
    (OPS_TYPES, 'gc_param_prefix-stale_after_min'):
        ('struct', OPS_TYPES, 'gc_pe_area', ['ebs', 'file_monitor', 'health_check', 'core']),
    (_HCK_TYPES, 'gc_param_prefix-max_age'): ('list', _HCK_TYPES, 'gc_param_default-watch_pe_areas'),
    (_HCK_TYPES, 'gc_param_prefix-max_run'): ('list', _HCK_TYPES, 'gc_param_default-watch_pe_areas'),
    (_EBS_TYPES, 'gc_param_prefix-parser'): ('struct', _EBS_TYPES, 'gc_format', None),
    (os.path.join('src', 'hck', 'zif_cd_hck_runtime_types.intf.abap'), 'gc_param_prefix-btc_info'):
        ('struct', _EBS_TYPES, 'gc_scheme', None),
    # Shift handover of the framework (2026-11-11): SHIFT_TIMES_<team> for the teams of CONTROL_TEAMS (read in CDS)
    (_FW_RESP_TYPES, 'gc_param_prefix-shift_times'): ('list', _FW_CTL_TYPES, 'gc_param_default-teams'),
}

_RULE_BASE = os.path.join('src', 'ebs', 'zcl_cd_ebs_rule_base.clas.abap')
_SCORE = os.path.join('src', 'hck', 'zcl_cd_hck_score.clas.abap')
DEFAULTS = {
    'EBS_DUP_LOOKBACK_DAYS': ('const', os.path.join('src', 'ebs', 'zcl_cd_ebs_r_r22_dup_history.clas.abap'),
                              'gc_default_days'),
    'EBS_KEYLEN_DOCNO': ('const', _RULE_BASE, 'gc_default_docno_length'),
    'EBS_KEYLEN_ZTNUM': ('const', _RULE_BASE, 'gc_default_ztnum_length'),
    'EBS_INFLIGHT_HOURS': ('const', _RULE_BASE, 'gc_default_inflight_hours'),
    'EBS_PARSER_BAI2': ('const', _EBS_TYPES, 'gc_param_default-parser_bai2'),
    'EBS_PARSER_CAMT053': ('const', _EBS_TYPES, 'gc_param_default-parser_camt'),
    'EBS_PARSER_CAMT054': ('const', _EBS_TYPES, 'gc_param_default-parser_camt'),
    'FMON_TIME_ZONE': ('const', FW_TYPES, 'gc_time_zone_utc'),
    'FMON_AGE_BASIS': ('const', os.path.join('src', 'fmon', 'zif_cd_fmon_types.intf.abap'), 'gc_age_basis-after_receipt'),
    'FMON_PRISM_MAX_BYTES': ('const', os.path.join('src', 'fmon', 'zif_cd_fmon_prism_types.intf.abap'),
                             'gc_default_max_bytes'),
    'FMON_PRISM_INSTANT': ('const', os.path.join('src', 'fmon', 'zif_cd_fmon_prism_types.intf.abap'),
                           'gc_default_instant'),
    'HCK_SUPPRESS_MAX_DAYS': ('const', os.path.join('src', 'hck', 'zif_cd_hck_suppress_types.intf.abap'),
                              'gc_default_max_days'),
    'HCK_FLAT_TOL_PCT': ('const', os.path.join('src', 'hck', 'zcl_cd_hck_threshold.clas.abap'),
                         'gc_default_flat_tol_pct'),
    'HCK_SCORE_GREEN_MIN': ('regex', _SCORE, r'rs_rules-green_min\s*=\s*(\d+)\.'),
    'HCK_SCORE_AMBER_MIN': ('regex', _SCORE, r'rs_rules-amber_min\s*=\s*(\d+)\.'),
    'HCK_WEIGHT_H': ('regex', _SCORE, r'rs_rules-weight_high\s*=\s*(\d+)\.'),
    'HCK_WEIGHT_M': ('regex', _SCORE, r'rs_rules-weight_medium\s*=\s*(\d+)\.'),
    'HCK_WEIGHT_L': ('regex', _SCORE, r'rs_rules-weight_low\s*=\s*(\d+)\.'),
    # Retention of the suite's purge targets (ZCL_CD_OPS_PURGE_TARGET, registry ZCA_OPS_PURGE): the
    # definition is the single source (the framework purge reads the parameter the registry row names)
    'RETENTION_DAYS_FMON_EVENT': ('definition',),
    'RETENTION_DAYS_HCK_METRIC': ('definition',),
    'RETENTION_DAYS_FMON_PRISM': ('definition',),
    'RETENTION_DAYS_HCK_RESULT': ('definition',),
    'RETENTION_DAYS_PAY_OUTCOME': ('definition',),
    'RETENTION_DAYS_FMON_FILE': ('definition',),
    # Shift start times of the suite's teams (framework shift handover, 2026-11-11): the definition is the source
    'SHIFT_TIMES_ONSITE': ('definition',),
    'SHIFT_TIMES_OFFSHORE': ('definition',),
    # Stale thresholds (minutes): the values the dashboards' CDS literals hold (cds_abap_parity) -
    # FMON 3 x its 5-minute cadence, EBS / HCK = HCK_MAX_AGE_HOURS (26 h) in minutes
    'MON_STALE_AFTER_MIN_CD_FMON': ('const', os.path.join('src', 'fmon', 'zif_cd_fmon_types.intf.abap'),
                                    'gc_dashboard-stale_after_min'),
    'MON_STALE_AFTER_MIN_CD_EBS': ('const', _HCK_TYPES, 'gc_param_default-max_age_hours', 60),
    'MON_STALE_AFTER_MIN_CD_HCK': ('const', _HCK_TYPES, 'gc_param_default-max_age_hours', 60),
    # CD_OPS = the payment outcome snapshot lag (2026-11-08): 6 x its 5-minute cadence
    'MON_STALE_AFTER_MIN_CD_OPS': ('const', os.path.join('src', 'core', 'zif_cd_ops_payout_types.intf.abap'),
                                   'gc_param_default-stale_after_min'),
}

TYPES_FILE = re.compile(r'zif_cd_\w*types\.intf\.abap$')

GEN_HEADER = """*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_param_seed.clas.abap
*& Purpose:
*& Delivered parameter areas and definitions of the suite in the framework
*& ZCA_PARAM - GENERATED by tools/param_definitions.py from
*& config/param_areas.csv and config/param_definitions.csv; do not edit,
*& regenerate. areas( ) / definitions( ) feed the configuration check
*& PARAM_INVALID (every delivered name must be defined and readable). An
*& instance is the in-memory parameter store of the unit tests: a
*& ZCL_CA_PARAM_DAO_MEM with the delivered areas and definitions of the
*& suite and of the operations framework (ZCL_CA_OPS_PARAM_SEED), set( )
*& maintains a value row, params( ) returns the framework adapter
*& ZCL_CA_OPS_PARAMS with the suite's prefixes over the real read logic
*& ZCL_CA_PARAM. Production-safe: no database.
*& Modification log:
*& 2026-11-07 | Initial version (generated; parameters moved to ZCA_PARAM).
*& 2026-11-08 | DEFINITIONS( ) collects parts of at most 100 rows (method length; the table
*&            | consolidation moved settings of retired customizing tables into definitions).
*& 2026-11-10 | Framework ZCA_OPS: the in-memory store also holds the framework's area and definitions;
*&            | params( ) is ZCL_CA_OPS_PARAMS with ZCL_CD_OPS_FACTORY=>PARAM_PREFIXES.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - delivered parameter definitions</p>
"! Delivered areas and definitions (generated from config/param_*.csv) and the
"! in-memory parameter store of the unit tests over the real framework logic.
CLASS zcl_cd_ops_param_seed DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Delivered areas (config/param_areas.csv)
    CLASS-METHODS areas
      RETURNING
        VALUE(rt_areas) TYPE zif_ca_param_types=>tt_area_row.

    "! Delivered definitions (config/param_definitions.csv)
    CLASS-METHODS definitions
      RETURNING
        VALUE(rt_definitions) TYPE zif_ca_param_types=>tt_definition.

    "! In-memory store with the delivered areas and definitions and no value row
    METHODS constructor.

    "! Maintain the value row of a parameter (replaces the rows it had); visible at once
    METHODS set
      IMPORTING
        iv_name        TYPE zif_ca_ops_types=>ty_param_name
        iv_value       TYPE clike
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_cd_ops_param_seed.

    "! Remove the value rows of a parameter: the definition default applies again
    METHODS remove
      IMPORTING
        iv_name TYPE zif_ca_ops_types=>ty_param_name.

    "! The in-memory data access (e.g. for ZCL_CA_PARAM_INJECTOR=>INJECT_DAO)
    METHODS dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zcl_ca_param_dao_mem.

    "! The suite's parameter adapter over the real read logic
    METHODS params
      RETURNING
        VALUE(ro_params) TYPE REF TO zif_ca_ops_params.


  PRIVATE SECTION.
"""

GEN_FOOTER = """{decls}    DATA mo_dao TYPE REF TO zcl_ca_param_dao_mem.
    DATA mo_param TYPE REF TO zif_ca_param.
    DATA mo_params TYPE REF TO zif_ca_ops_params.

ENDCLASS.



CLASS zcl_cd_ops_param_seed IMPLEMENTATION.

  METHOD areas.
{areas}  ENDMETHOD.


  METHOD definitions.
{defs}  ENDMETHOD.

{parts}

  METHOD constructor.
    mo_dao = NEW #( ).
    DATA(lt_areas) = zcl_ca_ops_param_seed=>areas( ).
    INSERT LINES OF areas( ) INTO TABLE lt_areas.
    LOOP AT lt_areas ASSIGNING FIELD-SYMBOL(<ls_area>).
      mo_dao->add_area( <ls_area> ).
    ENDLOOP.
    DATA(lt_definitions) = zcl_ca_ops_param_seed=>definitions( ).
    INSERT LINES OF definitions( ) INTO TABLE lt_definitions.
    LOOP AT lt_definitions ASSIGNING FIELD-SYMBOL(<ls_definition>).
      mo_dao->add_definition( <ls_definition> ).
    ENDLOOP.
    mo_param = NEW zcl_ca_param( io_dao = mo_dao ).
  ENDMETHOD.


  METHOD set.
    DATA ls_value TYPE zif_ca_param_types=>ty_value_row.

    remove( iv_name ).
    ls_value-area = params( )->area_of( iv_name ).
    ls_value-name = iv_name.
    ls_value-numb = 1.
    ls_value-sign = zif_ca_param_types=>gc_sign-include.
    ls_value-opti = zif_ca_param_types=>gc_option-eq.
    ls_value-low  = iv_value.
    mo_dao->add_value( ls_value ).
    ro_self = me.
  ENDMETHOD.


  METHOD remove.
    mo_dao->remove_values( iv_area = params( )->area_of( iv_name )
                           iv_name = iv_name ).
    " the read logic buffers per area: the next read sees the change
    mo_param->refresh( ).
  ENDMETHOD.


  METHOD dao.
    ro_dao = mo_dao.
  ENDMETHOD.


  METHOD params.
    IF mo_params IS NOT BOUND.
      mo_params = NEW zcl_ca_ops_params( io_param = mo_param ).
      mo_params->add_prefixes( zcl_cd_ops_factory=>param_prefixes( ) ).
    ENDIF.
    ro_params = mo_params.
  ENDMETHOD.

ENDCLASS.
"""

_gen.configure(SEED=SEED, ADAPTER=ADAPTER, OPS_TYPES=OPS_TYPES, AREA_SOURCES=AREA_SOURCES,
               EXTRA_AREAS_CSV=EXTRA_AREAS_CSV, EXTRA_DEFS_CSV=EXTRA_DEFS_CSV, RUNTIME=RUNTIME, DEFAULTS=DEFAULTS, TYPES_FILE=TYPES_FILE,
               GEN_HEADER=GEN_HEADER, GEN_FOOTER=GEN_FOOTER)

# The generator's interface, configured for the suite
AREAS_CSV = _gen.AREAS_CSV
DEFS_CSV = _gen.DEFS_CSV
VALUES_CSV = _gen.VALUES_CSV
AREA_COLS = _gen.AREA_COLS
DEF_COLS = _gen.DEF_COLS
VALUE_COLS = _gen.VALUE_COLS
PART_ROWS = _gen.PART_ROWS
constants = _gen.constants
load = _gen.load
render = _gen.render
failures = _gen.failures
counts = _gen.counts
expected_names = _gen.expected_names
code_default = _gen.code_default
pattern_mismatch = _gen.pattern_mismatch
area_map = _gen.area_map

if __name__ == '__main__':
    sys.argv = sys.argv[:1] + [a for a in sys.argv[1:]]
    _gen.main(os.path.dirname(_HERE))
