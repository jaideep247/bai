*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r08_check_amount.clas.abap
*& Purpose:
*& R08: the amount the bank paid for a check must equal the check register
*& amount (sum of DFKKCR rows per ZTNUM) within the rule tolerance.
*& Legacy parity: v4 581D per-check AMOUNT_MISMATCH.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check register scoped to house bank account; DPAYH proposal runs excluded (review 3.2).
*& 2026-11-06 | HOUSE_BANK_AMBIGUOUS reported when the account cannot be determined (audit 2026-11-06).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Check-register query with every form of the check number (leading zeros).
*& 2026-11-06 | Performance fix 1: register from check_register( ) (package memo, sorted index), one match per line.
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
    " Every form the check number can take in the register (leading zeros), read once per package
    DATA(ls_register) = check_register( it_lines = it_lines it_statements = it_statements ).
    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      DATA(ls_match) = register_match( is_register = ls_register is_line = <ls_line> ).
      IF ls_match-ztnum IS INITIAL.
        CONTINUE.
      ENDIF.
      IF ls_match-ambiguous = abap_true.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = <ls_line> iv_check_code = zif_cd_ebs_types=>gc_check_code-house_bank_ambiguous
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-house_bank_ambiguous
                                                     iv_v1    = ls_match-ztnum ) )
          INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      IF ls_match-checks IS INITIAL.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = <ls_line> iv_check_code = zif_cd_ebs_types=>gc_check_code-check_not_found
                 iv_message =
                   zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-check_not_found
                                          iv_v1 = ls_match-ztnum ) ) INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      DATA(lv_register) = REDUCE zif_cd_ops_types=>ty_amount(
        INIT lv_sum = CONV zif_cd_ops_types=>ty_amount( 0 )
        FOR ls_check IN ls_match-checks
        NEXT lv_sum = lv_sum + abs( ls_check-amount ) ).
      IF abs( lv_register - <ls_line>-amount ) > tolerance( is_rule ).
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = <ls_line> iv_check_code = zif_cd_ebs_types=>gc_check_code-check_amount_mismatch
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-check_amount_mismatch
                                                     iv_v1    = ls_match-ztnum
                                                     iv_v2    = <ls_line>-amount
                                                     iv_v3    = lv_register ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
