*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r08_check_amount.clas.abap
*& Purpose:
*& R08: the amount the bank paid for a check must equal the check register
*& amount (sum of DFKKCR rows per ZTNUM) within the rule tolerance.
*& Legacy parity: v4 581D per-check AMOUNT_MISMATCH.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check register scoped to house bank account; DPAYH proposal runs excluded (review 3.2).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R08 - check amount vs register</p>
CLASS zcl_cd_ebs_r_r08_check_amount DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r08_check_amount IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA lt_ztnum TYPE zif_cd_ebs_sap_dao=>tt_ztnum.
    LOOP AT it_lines INTO DATA(ls_key_line).
      DATA(lv_ref) = ztnum_key( line_reference( ls_key_line ) ).
      IF lv_ref IS NOT INITIAL.
        INSERT lv_ref INTO TABLE lt_ztnum.
      ENDIF.
    ENDLOOP.
    DATA(lt_checks) = sap_dao( )->get_checks( lt_ztnum ).
    LOOP AT it_lines INTO DATA(ls_line).
      DATA(lv_ztnum) = ztnum_key( line_reference( ls_line ) ).
      IF lv_ztnum IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lt_line_checks) = checks_for_line( it_checks = lt_checks is_line = ls_line it_statements = it_statements ).
      IF lt_line_checks IS INITIAL.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'CHECK_NOT_FOUND'
                 iv_message = |Check { lv_ztnum } not in the check register| ) INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      DATA(lv_register) = REDUCE zif_cd_ops_types=>ty_amount(
        INIT lv_sum = CONV zif_cd_ops_types=>ty_amount( 0 )
        FOR ls_check IN lt_line_checks
        NEXT lv_sum = lv_sum + abs( ls_check-amount ) ).
      IF abs( lv_register - ls_line-amount ) > tolerance( is_rule ).
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'CHECK_AMOUNT_MISMATCH'
                 iv_message = |Check { lv_ztnum }: bank { ls_line-amount }, register { lv_register }| )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
