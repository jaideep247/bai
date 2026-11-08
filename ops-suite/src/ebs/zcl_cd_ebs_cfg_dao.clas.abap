*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_cfg_dao.clas.abap
*& Purpose:
*& SQL for EBS customizing: ZCD_BTC_RULE joined with the rule registry
*& ZCD_EBS_RULE_DEF (assignment severity/action override the registry
*& defaults), ZCD_EBS_ACCT, ZCD_EBS_FLOW_PAT. The bank transaction codes and
*& the return / NOC reasons are entries of the customer posting areas ZBTM /
*& ZRSN (FQC0), read through ZCL_CD_OPS_POSTAREA (one read per run):
*& ZBTM keys SCHEME / CODE (ISO: domain) / FAMILY / SUB-FAMILY / BANK / FLOW,
*& results CATEGORY / RULE_GROUP / EXP_CDI / PAY_METHOD / POSTING_RULE /
*& ACTION / DISPOSITION; ZRSN key REASON, results FICA_REASON / IS_NOC.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*& 2026-11-06 | Generic lookup rule R21 (ZCD_EBS_LOOKUP) - new validations by configuration.
*& 2026-11-06 | Audit A03: unusable assignments returned (LEFT OUTER JOIN).
*& 2026-11-06 | Operating model: NEEDS_POSTING of the rule registry carried on the assignment.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-07 | Read-only scope: blocks-posting flag (A27) removed.
*& 2026-11-08 | Customer posting areas: BTC map from ZBTM and reasons from ZRSN (ZCL_CD_OPS_POSTAREA, were ZCD_BTC_MAP
*&            | / ZCD_EBS_RSN_MAP); get_reason (exact reason beats *).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - customizing repository</p>
CLASS zcl_cd_ebs_cfg_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_cfg_dao.

  PRIVATE SECTION.
    "! A ZRSN entry as reason map row
    CLASS-METHODS reason_of
      IMPORTING
        is_entry         TYPE zif_cd_ops_postarea_types=>ty_entry
      RETURNING
        VALUE(rs_reason) TYPE zif_cd_ebs_types=>ty_reason_map.

ENDCLASS.



CLASS zcl_cd_ebs_cfg_dao IMPLEMENTATION.

  METHOD zif_cd_ebs_cfg_dao~get_btc_map.
    " ZBTM (FQC0): an entry that exists applies (no ACTIVE flag); bank '*' = the default row of every
    " bank (blank bank key); an ISO family row has sub-family '*'
    LOOP AT zcl_cd_ops_postarea_factory=>get_reader( )->entries( zif_cd_ops_postarea_types=>gc_purpose-btc_map )
         ASSIGNING FIELD-SYMBOL(<ls_entry>).
      DATA(ls_map) = VALUE zif_cd_ebs_types=>ty_btc_map(
        scheme       = <ls_entry>-key01
        btc_code     = COND #( WHEN <ls_entry>-key01 <> zif_cd_ebs_types=>gc_scheme-iso THEN <ls_entry>-key02
                               WHEN <ls_entry>-key04 = zif_cd_ops_postarea_types=>gc_generic
                               THEN |{ <ls_entry>-key02 }{ zif_cd_ebs_types=>gc_iso_separator }{ <ls_entry>-key03 }|
                               ELSE |{ <ls_entry>-key02 }{ zif_cd_ebs_types=>gc_iso_separator }{ <ls_entry>-key03 }| &&
                                    |{ zif_cd_ebs_types=>gc_iso_separator }{ <ls_entry>-key04 }| )
        bank_key     = COND #( WHEN <ls_entry>-key05 <> zif_cd_ops_postarea_types=>gc_generic THEN <ls_entry>-key05 )
        flow_type    = <ls_entry>-key06
        category     = <ls_entry>-fun01
        rule_group   = <ls_entry>-fun02
        exp_cdi      = <ls_entry>-fun03
        pay_method   = <ls_entry>-fun04
        posting_rule = <ls_entry>-fun05
        action       = <ls_entry>-fun06
        disposition  = <ls_entry>-fun07
        active       = abap_true ).
      INSERT ls_map INTO TABLE rt_map.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ebs_cfg_dao~get_rules.
    " A03: LEFT OUTER JOIN - an active assignment whose definition is missing or inactive
    " is returned as UNUSABLE instead of disappearing (the engine blocks on it)
    SELECT r~rule_group, r~rule_id, r~seq, d~rule_level AS level, d~class_name,
           r~severity, r~action, r~param1, r~param2, r~param3, r~tolerance, r~window_days,
           r~active, d~description,
           d~default_severity, d~default_action,
           d~active AS def_active,
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
    LOOP AT zcl_cd_ops_postarea_factory=>get_reader( )->entries( zif_cd_ops_postarea_types=>gc_purpose-reason )
         ASSIGNING FIELD-SYMBOL(<ls_entry>).
      INSERT reason_of( <ls_entry> ) INTO TABLE rt_reasons.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ebs_cfg_dao~get_reason.
    DATA(ls_entry) = zcl_cd_ops_postarea_factory=>get_reader( )->find(
                       iv_purpose = zif_cd_ops_postarea_types=>gc_purpose-reason
                       is_keys    = VALUE #( key01 = condense( iv_reason ) ) ).
    IF ls_entry IS NOT INITIAL.
      rs_reason = reason_of( ls_entry ).
    ENDIF.
  ENDMETHOD.


  METHOD reason_of.
    rs_reason-reason      = is_entry-key01.
    rs_reason-fica_reason = is_entry-fun01.
    rs_reason-is_noc      = xsdbool( is_entry-fun02 = abap_true ).
  ENDMETHOD.


  METHOD zif_cd_ebs_cfg_dao~get_lookups.
    SELECT lookup_id, table_name, key_field, key_kind, key_length, status_field, allowed_values,
           not_found_code, status_code, active
      FROM zcd_ebs_lookup
      WHERE active = @abap_true
      INTO CORRESPONDING FIELDS OF TABLE @rt_lookups.
  ENDMETHOD.

ENDCLASS.
