*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r19_fi_document.clas.abap
*& Purpose:
*& R19: the FI document of an imported entry (FEBEP-BELNR/GJAHR, company code
*& of the statement) must exist; PARAM1 = CLEARED also requires a cleared line
*& (PARAM2 = G/L account restricts the check). PARAM3 = OPTIONAL skips unposted.
*& Legacy parity: v4 466D (exists) and 166C (cleared).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R19 - FI posting exists / cleared</p>
CLASS zcl_cd_ebs_r_r19_fi_document DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r19_fi_document IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA lt_keys TYPE zif_cd_ebs_sap_dao=>tt_fi_key.
    DATA ls_key TYPE zif_cd_ebs_sap_dao=>ty_fi_key.
    DATA lt_statements TYPE tt_stmt_hash.
    lt_statements = it_statements.
    LOOP AT it_lines INTO DATA(ls_key_line) WHERE belnr IS NOT INITIAL.
      ls_key-bukrs = VALUE #( lt_statements[ stmt_key = ls_key_line-stmt_key ]-bukrs OPTIONAL ).
      ls_key-belnr = ls_key_line-belnr.
      ls_key-gjahr = ls_key_line-gjahr.
      INSERT ls_key INTO TABLE lt_keys.
    ENDLOOP.
    DATA(lt_fi_lines) = sap_dao( )->get_fi_lines( lt_keys ).
    DATA(lv_need_cleared) = xsdbool( to_upper( condense( CONV string( is_rule-param1 ) ) ) = `CLEARED` ).
    DATA(lv_gl_account) = condense( CONV string( is_rule-param2 ) ).

    LOOP AT it_lines INTO DATA(ls_line).
      IF ls_line-belnr IS INITIAL.
        IF to_upper( condense( CONV string( is_rule-param3 ) ) ) <> zif_cd_ebs_types=>gc_rule_keyword-optional.
          INSERT zcl_cd_ebs_finding=>for_rule_line(
                   is_rule = is_rule is_line = ls_line iv_check_code = zif_cd_ebs_types=>gc_check_code-not_posted
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-not_posted
                                                       iv_v1    = ls_line-btc_code
                                                       iv_v2    = ls_line-reference ) )
            INTO TABLE rt_findings.
        ENDIF.
        CONTINUE.
      ENDIF.
      DATA(lv_bukrs) = VALUE #( lt_statements[ stmt_key = ls_line-stmt_key ]-bukrs OPTIONAL ).
      DATA(lv_found) = abap_false.
      DATA(lv_cleared) = abap_false.
      LOOP AT lt_fi_lines INTO DATA(ls_fi) WHERE bukrs = lv_bukrs AND belnr = ls_line-belnr AND gjahr = ls_line-gjahr.
        lv_found = abap_true.
        IF ls_fi-augbl IS NOT INITIAL AND ( lv_gl_account IS INITIAL OR ls_fi-hkont = lv_gl_account ).
          lv_cleared = abap_true.
        ENDIF.
      ENDLOOP.
      IF lv_found = abap_false.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = zif_cd_ebs_types=>gc_check_code-fi_doc_not_found
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-fi_doc_not_found
                                                     iv_v1    = lv_bukrs
                                                     iv_v2    = ls_line-belnr
                                                     iv_v3    = ls_line-gjahr ) )
          INTO TABLE rt_findings.
      ELSEIF lv_need_cleared = abap_true AND lv_cleared = abap_false.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = zif_cd_ebs_types=>gc_check_code-fi_doc_not_cleared
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-fi_doc_not_cleared
                                                     iv_v1    = ls_line-belnr
                                                     iv_v2    = ls_line-gjahr ) ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
