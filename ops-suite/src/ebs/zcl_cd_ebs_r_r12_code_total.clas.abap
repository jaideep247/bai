*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r12_code_total.clas.abap
*& Purpose:
*& R12: per statement, the total and count of the entries of this rule group
*& must equal the total and count of the matching check register rows
*& (DFKKCR). Legacy parity: v4 581D TOTAL_SUM_MISMATCH / TOTAL_COUNT_MISMATCH.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check register scoped to house bank account; DPAYH proposal runs excluded (review 3.2).
*& 2026-11-06 | Totals skipped with HOUSE_BANK_AMBIGUOUS when accounts cannot be separated; count definition documented (audit 2026-11-06).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R12 - code total vs register total</p>
CLASS zcl_cd_ebs_r_r12_code_total DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r12_code_total IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA lt_ztnum TYPE zif_cd_ebs_sap_dao=>tt_ztnum.
    DATA lt_statements TYPE tt_stmt_hash.
    lt_statements = it_statements.
    LOOP AT it_lines INTO DATA(ls_key_line).
      DATA(lv_ref) = ztnum_key( line_reference( ls_key_line ) ).
      IF lv_ref IS NOT INITIAL.
        INSERT lv_ref INTO TABLE lt_ztnum.
      ENDIF.
    ENDLOOP.
    DATA(lt_checks) = sap_dao( )->get_checks( lt_ztnum ).

    LOOP AT it_lines INTO DATA(ls_group) GROUP BY ls_group-stmt_key INTO DATA(lv_stmt_key).
      DATA(lv_bank_total) = CONV zif_cd_ops_types=>ty_amount( 0 ).
      DATA(lv_bank_count) = 0.
      DATA(lv_reg_total)  = CONV zif_cd_ops_types=>ty_amount( 0 ).
      DATA(lv_reg_count)  = 0.
      DATA(lv_ambiguous)  = abap_false.
      " Count = bank entries with at least one register row; total = every register row
      " of those entries (R08 sums all rows per check - parity D7)
      LOOP AT GROUP lv_stmt_key INTO DATA(ls_line).
        IF house_bank_ambiguous( it_checks = lt_checks is_line = ls_line it_statements = it_statements ) = abap_true.
          lv_ambiguous = abap_true.
        ENDIF.
        lv_bank_total += ls_line-amount.
        lv_bank_count += 1.
        DATA(lt_line_checks) = checks_for_line( it_checks = lt_checks is_line = ls_line it_statements = it_statements ).
        LOOP AT lt_line_checks INTO DATA(ls_check).
          lv_reg_total += abs( ls_check-amount ).
        ENDLOOP.
        IF lt_line_checks IS NOT INITIAL.
          lv_reg_count += 1.
        ENDIF.
      ENDLOOP.
      DATA(ls_statement) = VALUE #( lt_statements[ stmt_key = lv_stmt_key ] OPTIONAL ).
      ls_statement-stmt_key = lv_stmt_key.
      IF lv_ambiguous = abap_true.
        " Totals would mix accounts: report instead of comparing
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = zif_cd_ebs_types=>gc_check_code-house_bank_ambiguous
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-house_bank_ambiguous_2
                                                     iv_v1    = is_rule-rule_group ) )
          INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      IF abs( lv_bank_total - lv_reg_total ) > tolerance( is_rule ).
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = zif_cd_ebs_types=>gc_check_code-code_total_mismatch
                 iv_amount = lv_bank_total - lv_reg_total
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-code_total_mismatch
                                                     iv_v1    = is_rule-rule_group
                                                     iv_v2    = lv_bank_total
                                                     iv_v3    = lv_reg_total ) )
          INTO TABLE rt_findings.
      ENDIF.
      IF lv_bank_count <> lv_reg_count.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = zif_cd_ebs_types=>gc_check_code-code_count_mismatch
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-code_count_mismatch
                                                     iv_v1    = is_rule-rule_group
                                                     iv_v2    = lv_bank_count
                                                     iv_v3    = lv_reg_count ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
