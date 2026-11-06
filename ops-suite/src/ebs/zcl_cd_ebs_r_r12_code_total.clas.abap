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
*& 2026-11-06 | Check-register query with every form of the check number (leading zeros).
*& 2026-11-06 | Audit A08: bank entries against distinct register rows (no row reused).
*& 2026-11-06 | Performance fix 1: register from check_register( ) (package memo, sorted index), one match per line.
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
    DATA lt_register TYPE HASHED TABLE OF zif_cd_ebs_sap_dao=>ty_check WITH UNIQUE KEY table_line.
    " Every form the check number can take in the register (leading zeros), read once per package
    DATA(ls_register) = check_register( it_lines = it_lines it_statements = it_statements ).

    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_group>) GROUP BY <ls_group>-stmt_key INTO DATA(lv_stmt_key).
      DATA(lv_bank_total) = CONV zif_cd_ops_types=>ty_amount( 0 ).
      DATA(lv_bank_count) = 0.
      DATA(lv_ambiguous)  = abap_false.
      " A08: two independent populations - bank entries (count, total) against the distinct
      " register rows they match (count, total); a register row counts once even when
      " several bank entries carry its check number
      CLEAR lt_register.
      LOOP AT GROUP lv_stmt_key ASSIGNING FIELD-SYMBOL(<ls_line>).
        " One register match per line (ambiguity and rows evaluated once, not twice)
        DATA(ls_match) = register_match( is_register = ls_register is_line = <ls_line> ).
        IF ls_match-ambiguous = abap_true.
          lv_ambiguous = abap_true.
        ENDIF.
        lv_bank_total += <ls_line>-amount.
        lv_bank_count += 1.
        " Single INSERT (not INSERT LINES OF): a row already counted is skipped, never a duplicate-key dump
        LOOP AT ls_match-checks ASSIGNING FIELD-SYMBOL(<ls_check>).
          INSERT <ls_check> INTO TABLE lt_register.
        ENDLOOP.
      ENDLOOP.
      DATA(lv_reg_count) = lines( lt_register ).
      DATA(lv_reg_total) = REDUCE zif_cd_ops_types=>ty_amount(
        INIT lv_sum = CONV zif_cd_ops_types=>ty_amount( 0 )
        FOR ls_row IN lt_register
        NEXT lv_sum = lv_sum + abs( ls_row-amount ) ).
      DATA(ls_statement) = VALUE #( ls_register-statements[ stmt_key = lv_stmt_key ] OPTIONAL ).
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
