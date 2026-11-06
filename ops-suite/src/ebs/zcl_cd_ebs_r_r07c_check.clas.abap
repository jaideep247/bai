*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r07c_check.clas.abap
*& Purpose:
*& R07C: the check number must exist in the check register (DFKKCR-ZTNUM =
*& FEBEP-CHECT) and its status must not be in PARAM1 (default 99 = cancelled).
*& Legacy parity: v4 255D.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check register scoped to house bank account; DPAYH proposal runs excluded (review 3.2).
*& 2026-11-06 | Any forbidden register row fails; HOUSE_BANK_AMBIGUOUS reported (audit 2026-11-06).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Check-register query with every form of the check number (leading zeros).
*& 2026-11-06 | Performance fix 1: register from check_register( ) (package memo, sorted index), one match per line.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R07C - check in register, not cancelled</p>
CLASS zcl_cd_ebs_r_r07c_check DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r07c_check IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    " Every form the check number can take in the register (leading zeros), read once per package
    DATA(ls_register) = check_register( it_lines = it_lines it_statements = it_statements ).
    DATA(lt_forbidden) = value_list( iv_values = is_rule-param1 iv_default = `99` ).
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
      " Fail closed: any forbidden register row fails, not only the first one
      LOOP AT ls_match-checks ASSIGNING FIELD-SYMBOL(<ls_check>).
        IF in_list( iv_value = <ls_check>-crstatus it_list = lt_forbidden ) = abap_true.
          INSERT zcl_cd_ebs_finding=>for_rule_line(
                   is_rule = is_rule is_line = <ls_line> iv_check_code = zif_cd_ebs_types=>gc_check_code-check_status
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-check_status
                                                       iv_v1    = ls_match-ztnum
                                                       iv_v2    = <ls_check>-crstatus ) )
            INTO TABLE rt_findings.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
