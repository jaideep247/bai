*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r03_currency.clas.abap
*& Purpose:
*& R03: every entry must be in the currency of its statement (account).
*& Pure; no repository.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R03 - line currency = statement currency</p>
CLASS zcl_cd_ebs_r_r03_currency DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r03_currency IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA lt_statements TYPE tt_stmt_hash.
    lt_statements = it_statements.
    LOOP AT it_lines INTO DATA(ls_line) WHERE currency IS NOT INITIAL.
      DATA(lv_stmt_currency) = VALUE #( lt_statements[ stmt_key = ls_line-stmt_key ]-currency OPTIONAL ).
      IF lv_stmt_currency IS NOT INITIAL AND lv_stmt_currency <> ls_line-currency.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = zif_cd_ebs_types=>gc_check_code-currency_mismatch
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-currency_mismatch
                                                     iv_v1    = ls_line-currency
                                                     iv_v2    = lv_stmt_currency ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
