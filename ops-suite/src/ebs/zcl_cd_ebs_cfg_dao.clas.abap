*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_cfg_dao.clas.abap
*& Purpose:
*& SQL for EBS customizing: ZCD_BTC_MAP, ZCD_BTC_RULE joined with the rule
*& registry ZCD_EBS_RULE_DEF (assignment severity/action override the registry
*& defaults), ZCD_EBS_ACCT, ZCD_EBS_FLOW_PAT and ZCD_EBS_RSN_MAP.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - customizing repository</p>
CLASS zcl_cd_ebs_cfg_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_cfg_dao.

ENDCLASS.



CLASS zcl_cd_ebs_cfg_dao IMPLEMENTATION.

  METHOD zif_cd_ebs_cfg_dao~get_btc_map.
    SELECT scheme, btc_code, bank_key, flow_type, category, rule_group, exp_cdi, pay_method,
           posting_rule, ret_reason, action, active, description
      FROM zcd_btc_map
      ORDER BY scheme, btc_code, bank_key, flow_type
      INTO CORRESPONDING FIELDS OF TABLE @rt_map.
  ENDMETHOD.


  METHOD zif_cd_ebs_cfg_dao~get_rules.
    SELECT r~rule_group, r~rule_id, r~seq, d~rule_level AS level, d~class_name,
           r~severity, r~action, r~param1, r~param2, r~param3, r~tolerance, r~window_days,
           r~active, d~description,
           d~default_severity, d~default_action
      FROM zcd_btc_rule AS r
      INNER JOIN zcd_ebs_rule_def AS d ON d~rule_id = r~rule_id
      WHERE r~active = @abap_true
        AND d~active = @abap_true
      ORDER BY r~rule_group, r~seq, r~rule_id
      INTO TABLE @DATA(lt_rows).

    LOOP AT lt_rows INTO DATA(ls_row).
      DATA(ls_rule) = CORRESPONDING zif_cd_ebs_types=>ty_rule_cfg( ls_row ).
      IF ls_rule-severity IS INITIAL.
        ls_rule-severity = ls_row-default_severity.
      ENDIF.
      IF ls_rule-action IS INITIAL.
        ls_rule-action = ls_row-default_action.
      ENDIF.
      INSERT ls_rule INTO TABLE rt_rules.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ebs_cfg_dao~get_accounts.
    SELECT bukrs, hbkid, hktid, account_no, bank_key, format, flow_default, currency, gl_account, active
      FROM zcd_ebs_acct
      ORDER BY bukrs, hbkid, hktid
      INTO CORRESPONDING FIELDS OF TABLE @rt_accounts.
  ENDMETHOD.


  METHOD zif_cd_ebs_cfg_dao~get_flow_patterns.
    SELECT priority, pattern, flow_type
      FROM zcd_ebs_flow_pat
      WHERE active = @abap_true
      ORDER BY priority, pattern
      INTO CORRESPONDING FIELDS OF TABLE @rt_patterns.
  ENDMETHOD.


  METHOD zif_cd_ebs_cfg_dao~get_reason_map.
    SELECT reason, fica_reason, is_noc
      FROM zcd_ebs_rsn_map
      INTO CORRESPONDING FIELDS OF TABLE @rt_reasons.
  ENDMETHOD.

ENDCLASS.
