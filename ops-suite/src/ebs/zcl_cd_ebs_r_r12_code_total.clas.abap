*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r12_code_total.clas.abap
*& Purpose:
*& R12: per statement, the total and count of the entries of this rule group
*& must equal the total and count of the matching check register rows
*& (DFKKCR). Legacy parity: v4 581D TOTAL_SUM_MISMATCH / TOTAL_COUNT_MISMATCH.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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
      LOOP AT GROUP lv_stmt_key INTO DATA(ls_line).
        lv_bank_total += ls_line-amount.
        lv_bank_count += 1.
        DATA(lv_ztnum) = ztnum_key( line_reference( ls_line ) ).
        LOOP AT lt_checks INTO DATA(ls_check) WHERE ztnum = lv_ztnum.
          lv_reg_total += abs( ls_check-amount ).
        ENDLOOP.
        IF line_exists( lt_checks[ ztnum = lv_ztnum ] ).
          lv_reg_count += 1.
        ENDIF.
      ENDLOOP.
      DATA(ls_statement) = VALUE #( lt_statements[ stmt_key = lv_stmt_key ] OPTIONAL ).
      ls_statement-stmt_key = lv_stmt_key.
      IF abs( lv_bank_total - lv_reg_total ) > tolerance( is_rule ).
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'CODE_TOTAL_MISMATCH'
                 iv_amount = lv_bank_total - lv_reg_total
                 iv_message = |Group { is_rule-rule_group }: bank total { lv_bank_total }, register { lv_reg_total }| )
          INTO TABLE rt_findings.
      ENDIF.
      IF lv_bank_count <> lv_reg_count.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'CODE_COUNT_MISMATCH'
                 iv_message = |Group { is_rule-rule_group }: { lv_bank_count } bank entries, { lv_reg_count } in register| )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
