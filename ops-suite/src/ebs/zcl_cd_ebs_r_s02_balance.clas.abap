*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s02_balance.clas.abap
*& Purpose:
*& S02: opening + credit entries - debit entries must equal the closing
*& balance; when the bank declares totals (BAI2 100/400, CAMT TxsSummry) the
*& declared totals must balance too. Pure.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A34 / A35: unknown sign reported, gross totals compared, statement key.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS check S02 - opening + credits - debits = closing</p>
CLASS zcl_cd_ebs_r_s02_balance DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_s02_balance IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    LOOP AT it_statements ASSIGNING FIELD-SYMBOL(<ls_statement>)
         WHERE has_opening = abap_true AND has_closing = abap_true.
      DATA(lv_credits) = CONV zif_cd_ops_types=>ty_amount( 0 ).
      DATA(lv_debits)  = CONV zif_cd_ops_types=>ty_amount( 0 ).
      DATA(lv_unknown) = 0.
      LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>) USING KEY stmt WHERE stmt_key = <ls_statement>-stmt_key.
        CASE <ls_line>-cdi.
          WHEN zif_cd_ebs_types=>gc_cdi-debit.
            lv_debits += <ls_line>-amount.
          WHEN zif_cd_ebs_types=>gc_cdi-credit.
            lv_credits += <ls_line>-amount.
          WHEN OTHERS.
            lv_unknown += 1.
        ENDCASE.
      ENDLOOP.
      " A34: an entry of unknown direction makes the arithmetic meaningless - reported instead
      IF lv_unknown > 0.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = <ls_statement> iv_check_code = zif_cd_ebs_types=>gc_check_code-cdi_unknown
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-cdi_unknown
                                                     iv_v1    = <ls_statement>-stmt_key
                                                     iv_v2    = lv_unknown ) ) INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      DATA lv_difference TYPE zif_cd_ops_types=>ty_amount.
      lv_difference = <ls_statement>-opening_bal + lv_credits - lv_debits - <ls_statement>-closing_bal.
      IF abs( lv_difference ) > tolerance( is_rule ).
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = <ls_statement> iv_check_code = zif_cd_ebs_types=>gc_check_code-balance_arithmetic
                 iv_amount = lv_difference
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-balance_arithmetic
                                                     iv_v1    = <ls_statement>-opening_bal
                                                     iv_v2    = lv_credits
                                                     iv_v3    = lv_debits
                                                     iv_v4    = <ls_statement>-closing_bal ) ) INTO TABLE rt_findings.
      ENDIF.
      IF <ls_statement>-has_totals = abap_true.
        DATA lv_declared TYPE zif_cd_ops_types=>ty_amount.
        lv_declared = <ls_statement>-opening_bal + <ls_statement>-total_credits
                          - <ls_statement>-total_debits - <ls_statement>-closing_bal.
        IF abs( lv_declared ) > tolerance( is_rule ).
          INSERT zcl_cd_ebs_finding=>for_rule_statement(
                   is_rule = is_rule is_statement = <ls_statement> iv_check_code = zif_cd_ebs_types=>gc_check_code-declared_totals
                   iv_amount = lv_declared
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-declared_totals
                                                       iv_v1    = lv_declared ) ) INTO TABLE rt_findings.
        ENDIF.
        " A34: gross credits and debits separately - equal overstatements cancel only in the net
        IF abs( <ls_statement>-total_credits - lv_credits ) > tolerance( is_rule ).
          INSERT zcl_cd_ebs_finding=>for_rule_statement(
                   is_rule = is_rule is_statement = <ls_statement> iv_check_code = zif_cd_ebs_types=>gc_check_code-gross_totals
                   iv_amount = <ls_statement>-total_credits - lv_credits
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-gross_credits
                                                       iv_v1    = <ls_statement>-total_credits
                                                       iv_v2    = lv_credits ) ) INTO TABLE rt_findings.
        ENDIF.
        IF abs( <ls_statement>-total_debits - lv_debits ) > tolerance( is_rule ).
          INSERT zcl_cd_ebs_finding=>for_rule_statement(
                   is_rule = is_rule is_statement = <ls_statement> iv_check_code = zif_cd_ebs_types=>gc_check_code-gross_totals
                   iv_amount = <ls_statement>-total_debits - lv_debits
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-gross_debits
                                                       iv_v1    = <ls_statement>-total_debits
                                                       iv_v2    = lv_debits ) ) INTO TABLE rt_findings.
        ENDIF.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
