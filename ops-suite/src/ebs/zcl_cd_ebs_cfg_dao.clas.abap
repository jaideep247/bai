*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_cfg_dao.clas.abap
*& Purpose:
*& SQL for EBS customizing: ZCD_BTC_MAP, ZCD_BTC_RULE joined with the rule
*& registry ZCD_EBS_RULE_DEF (assignment severity/action override the registry
*& defaults), ZCD_EBS_ACCT, ZCD_EBS_FLOW_PAT and ZCD_EBS_RSN_MAP.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*& 2026-11-06 | Generic lookup rule R21 (ZCD_EBS_LOOKUP) - new validations by configuration.
*& 2026-11-06 | Audit A03 / A27: unusable assignments returned (LEFT OUTER JOIN), blocks-posting flag resolved.
*& 2026-11-06 | Operating model: NEEDS_POSTING of the rule registry carried on the assignment.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
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
           posting_rule, ret_reason, action, active, description, disposition
      FROM zcd_btc_map
      ORDER BY scheme, btc_code, bank_key, flow_type
      INTO CORRESPONDING FIELDS OF TABLE @rt_map.
  ENDMETHOD.


  METHOD zif_cd_ebs_cfg_dao~get_rules.
    " A03: LEFT OUTER JOIN - an active assignment whose definition is missing or inactive
    " is returned as UNUSABLE instead of disappearing (the engine blocks on it)
    SELECT r~rule_group, r~rule_id, r~seq, d~rule_level AS level, d~class_name,
           r~severity, r~action, r~param1, r~param2, r~param3, r~tolerance, r~window_days,
           r~active, d~description,
           d~default_severity, d~default_action,
           d~active AS def_active, d~blocks_posting AS default_blocks, r~blocks_posting AS blocks_override,
           d~needs_posting
      FROM zcd_btc_rule AS r
      LEFT OUTER JOIN zcd_ebs_rule_def AS d ON d~rule_id = r~rule_id
      WHERE r~active = @abap_true
      ORDER BY r~rule_group, r~seq, r~rule_id
      INTO TABLE @DATA(lt_rows).

    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(ls_rule) = CORRESPONDING zif_cd_ebs_types=>ty_rule_cfg( <ls_row> ).
      ls_rule-unusable = xsdbool( <ls_row>-rule_id <> zif_cd_ebs_types=>gc_rule_none
                                  AND ( <ls_row>-class_name IS INITIAL OR <ls_row>-def_active = abap_false ) ).
      ls_rule-blocks_posting = SWITCH #( <ls_row>-blocks_override
                                         WHEN zif_cd_ebs_types=>gc_blocks_override-yes THEN abap_true
                                         WHEN zif_cd_ebs_types=>gc_blocks_override-no  THEN abap_false
                                         ELSE <ls_row>-default_blocks ).
      IF ls_rule-severity IS INITIAL.
        ls_rule-severity = <ls_row>-default_severity.
      ENDIF.
      IF ls_rule-action IS INITIAL.
        ls_rule-action = <ls_row>-default_action.
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


  METHOD zif_cd_ebs_cfg_dao~get_lookups.
    SELECT lookup_id, table_name, key_field, key_kind, key_length, status_field, allowed_values,
           not_found_code, status_code, active
      FROM zcd_ebs_lookup
      WHERE active = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @rt_lookups.
  ENDMETHOD.

ENDCLASS.
