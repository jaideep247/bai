*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ebs_cfg_dao.intf.abap
*& Purpose:
*& Customer posting area ZBTM (bank transaction codes), ZCD_BTC_RULE +
*& ZCD_EBS_RULE_DEF, ZCD_EBS_ACCT, ZCD_EBS_FLOW_PAT, customer posting area
*& ZRSN (return / NOC reasons). Read once per run (engine and posting area
*& reader cache).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Generic lookup rule R21 (ZCD_EBS_LOOKUP) - new validations by configuration.
*& 2026-11-08 | Customer posting areas: get_btc_map reads ZBTM, get_reason_map ZRSN (were ZCD_BTC_MAP /
*&            | ZCD_EBS_RSN_MAP); get_reason - the entry that applies to one reason (exact beats *).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - customizing repository</p>
"! Posting area ZBTM, ZCD_BTC_RULE + ZCD_EBS_RULE_DEF, ZCD_EBS_ACCT,
"! ZCD_EBS_FLOW_PAT, posting area ZRSN. Read once per run (engine caches).
INTERFACE zif_cd_ebs_cfg_dao
  PUBLIC.

  "! Every entry of the customer posting area ZBTM (ZCL_CD_OPS_POSTAREA), as map rows
  METHODS get_btc_map
    RETURNING
      VALUE(rt_map) TYPE zif_cd_ebs_types=>tt_btc_map.

  "! Active rule assignments joined with the rule registry, ordered by group/seq
  METHODS get_rules
    RETURNING
      VALUE(rt_rules) TYPE zif_cd_ebs_types=>tt_rule_cfg.

  METHODS get_accounts
    RETURNING
      VALUE(rt_accounts) TYPE zif_cd_ebs_types=>tt_account_cfg.

  METHODS get_flow_patterns
    RETURNING
      VALUE(rt_patterns) TYPE zif_cd_ebs_types=>tt_flow_pattern.

  "! Every entry of the customer posting area ZRSN (a '*' entry as reason '*')
  METHODS get_reason_map
    RETURNING
      VALUE(rt_reasons) TYPE zif_cd_ebs_types=>tt_reason_map.

  "! The entry of ZRSN that applies to a bank reason (FQC0: the exact reason beats '*');
  "! initial when none applies
  METHODS get_reason
    IMPORTING
      iv_reason        TYPE zif_cd_ebs_types=>ty_reason_map-reason
    RETURNING
      VALUE(rs_reason) TYPE zif_cd_ebs_types=>ty_reason_map.

  "! Active lookups of rule R21 (ZCD_EBS_LOOKUP)
  METHODS get_lookups DEFAULT IGNORE
    RETURNING
      VALUE(rt_lookups) TYPE zif_cd_ebs_types=>tt_lookup_cfg.

ENDINTERFACE.
