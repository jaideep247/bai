*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r22_dup_history.clas.abap
*& Purpose:
*& R22: an entry must not already be in another imported statement of the same
*& house bank account within the look-back window (WINDOW_DAYS of the rule row,
*& else EBS_DUP_LOOKBACK_DAYS): same reference, amount, debit/credit and bank
*& transaction code. The statement's own entries (same KUKEY) are excluded.
*& Needs the SAP house bank identity; R09 stays the within-statement check.
*& Modification log:
*& 2026-11-06 | Initial version (audit A14, business decision: look back N days).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R22 - duplicate of an earlier statement</p>
CLASS zcl_cd_ebs_r_r22_dup_history DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

    "! Look-back days when neither the rule row nor ZCD_OPS_PARAM set them
    CONSTANTS gc_default_days TYPE i VALUE 5.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_key,
        reference TYPE string,
        amount    TYPE zif_cd_ops_types=>ty_amount,
        cdi       TYPE zif_cd_ebs_types=>ty_cdi,
        btc_code  TYPE zif_cd_ebs_types=>ty_btc_code,
      END OF ty_key.
    TYPES:
      BEGIN OF ty_seen,
        key   TYPE ty_key,
        kukey TYPE zif_cd_ebs_types=>ty_kukey,
      END OF ty_seen.
    TYPES tt_seen TYPE HASHED TABLE OF ty_seen WITH UNIQUE KEY key.

    METHODS look_back_days
      IMPORTING
        is_rule        TYPE zif_cd_ebs_types=>ty_rule_cfg
      RETURNING
        VALUE(rv_days) TYPE i.

ENDCLASS.



CLASS zcl_cd_ebs_r_r22_dup_history IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA lt_seen TYPE tt_seen.
    DATA ls_key TYPE ty_key.
    DATA lv_from TYPE d.
    DATA(lv_days) = look_back_days( is_rule ).
    DATA(lv_credit_ind) = param( iv_name    = zif_cd_ebs_types=>gc_param-feb_credit_ind
                                 iv_default = zif_cd_ebs_types=>gc_param_default-feb_credit_ind ).
    DATA(lv_debit_ind) = param( iv_name    = zif_cd_ebs_types=>gc_param-feb_debit_ind
                                iv_default = zif_cd_ebs_types=>gc_param_default-feb_debit_ind ).

    LOOP AT it_statements INTO DATA(ls_statement) WHERE hbkid IS NOT INITIAL AND stmt_date IS NOT INITIAL.
      CLEAR lt_seen.
      lv_from = ls_statement-stmt_date - lv_days.
      DATA(lt_items) = feb_dao( )->get_recent_items( iv_bukrs = ls_statement-bukrs
                                                     iv_hbkid = ls_statement-hbkid
                                                     iv_hktid = ls_statement-hktid
                                                     iv_from  = lv_from
                                                     iv_to    = ls_statement-stmt_date ).
      LOOP AT lt_items INTO DATA(ls_item) WHERE kukey <> ls_statement-kukey AND chect IS NOT INITIAL.
        CLEAR ls_key.
        ls_key-reference = condense( CONV string( ls_item-chect ) ).
        ls_key-amount    = abs( ls_item-kwbtr ).
        ls_key-cdi       = COND #( WHEN ls_item-epvoz = lv_credit_ind THEN zif_cd_ebs_types=>gc_cdi-credit
                                   WHEN ls_item-epvoz = lv_debit_ind  THEN zif_cd_ebs_types=>gc_cdi-debit ).
        ls_key-btc_code  = COND #( WHEN ls_item-vorgc IS NOT INITIAL THEN ls_item-vorgc ELSE ls_item-vgext ).
        INSERT VALUE #( key = ls_key kukey = ls_item-kukey ) INTO TABLE lt_seen.
      ENDLOOP.
      IF lt_seen IS INITIAL.
        CONTINUE.
      ENDIF.
      LOOP AT it_lines INTO DATA(ls_line) WHERE stmt_key = ls_statement-stmt_key AND reference IS NOT INITIAL.
        CLEAR ls_key.
        ls_key-reference = condense( CONV string( ls_line-reference ) ).
        ls_key-amount    = ls_line-amount.
        ls_key-cdi       = ls_line-cdi.
        ls_key-btc_code  = ls_line-btc_code.
        READ TABLE lt_seen INTO DATA(ls_seen) WITH TABLE KEY key = ls_key.
        IF sy-subrc = 0.
          INSERT zcl_cd_ebs_finding=>for_rule_line(
                   is_rule = is_rule is_line = ls_line iv_check_code = zif_cd_ebs_types=>gc_check_code-duplicate_history
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-duplicate_history
                                                       iv_v1    = zcl_cd_ebs_finding=>line_key( ls_line )
                                                       iv_v2    = ls_seen-kukey
                                                       iv_v3    = ls_line-reference ) )
            INTO TABLE rt_findings.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD look_back_days.
    rv_days = COND #( WHEN is_rule-window_days > 0 THEN is_rule-window_days
                      ELSE CONV i( zcl_cd_ops_util=>to_decimal(
                                     iv_value   = param( iv_name    = zif_cd_ebs_types=>gc_param-dup_lookback_days
                                                         iv_default = |{ gc_default_days }| )
                                     iv_default = gc_default_days ) ) ).
  ENDMETHOD.

ENDCLASS.
