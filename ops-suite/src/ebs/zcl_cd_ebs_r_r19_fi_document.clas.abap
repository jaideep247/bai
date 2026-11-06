*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r19_fi_document.clas.abap
*& Purpose:
*& R19: the FI document of an imported entry (FEBEP-BELNR/GJAHR, company code
*& of the statement) must exist; PARAM1 = CLEARED also requires a cleared line
*& (PARAM2 = G/L account restricts the check). PARAM3 = OPTIONAL skips unposted.
*& Legacy parity: v4 466D (exists) and 166C (cleared).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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
        IF to_upper( condense( CONV string( is_rule-param3 ) ) ) <> `OPTIONAL`.
          INSERT zcl_cd_ebs_finding=>for_rule_line(
                   is_rule = is_rule is_line = ls_line iv_check_code = 'NOT_POSTED'
                   iv_message = |Entry { ls_line-btc_code } { ls_line-reference } has no FI document| )
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
                 is_rule = is_rule is_line = ls_line iv_check_code = 'FI_DOC_NOT_FOUND'
                 iv_message = |FI document { lv_bukrs } { ls_line-belnr } { ls_line-gjahr } not found| )
          INTO TABLE rt_findings.
      ELSEIF lv_need_cleared = abap_true AND lv_cleared = abap_false.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'FI_DOC_NOT_CLEARED'
                 iv_message = |FI document { ls_line-belnr } { ls_line-gjahr } is not cleared| ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
