*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ebs_cfg_dao.intf.abap
*& Purpose:
*& ZCD_BTC_MAP, ZCD_BTC_RULE + ZCD_EBS_RULE_DEF, ZCD_EBS_ACCT,
*& ZCD_EBS_FLOW_PAT, ZCD_EBS_RSN_MAP. Read once per run (engine caches).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Generic lookup rule R21 (ZCD_EBS_LOOKUP) - new validations by configuration.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - customizing repository</p>
"! ZCD_BTC_MAP, ZCD_BTC_RULE + ZCD_EBS_RULE_DEF, ZCD_EBS_ACCT,
"! ZCD_EBS_FLOW_PAT, ZCD_EBS_RSN_MAP. Read once per run (engine caches).
INTERFACE zif_cd_ebs_cfg_dao
  PUBLIC.

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

  METHODS get_reason_map
    RETURNING
      VALUE(rt_reasons) TYPE zif_cd_ebs_types=>tt_reason_map.

  "! Active lookups of rule R21 (ZCD_EBS_LOOKUP)
  METHODS get_lookups DEFAULT IGNORE
    RETURNING
      VALUE(rt_lookups) TYPE zif_cd_ebs_types=>tt_lookup_cfg.

ENDINTERFACE.
