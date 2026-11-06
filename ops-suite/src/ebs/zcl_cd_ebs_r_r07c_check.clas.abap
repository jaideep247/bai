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
    DATA lt_ztnum TYPE zif_cd_ebs_sap_dao=>tt_ztnum.
    LOOP AT it_lines INTO DATA(ls_key_line).
      DATA(lv_ref) = ztnum_key( line_reference( ls_key_line ) ).
      IF lv_ref IS NOT INITIAL.
        INSERT lv_ref INTO TABLE lt_ztnum.
      ENDIF.
    ENDLOOP.
    DATA(lt_checks) = sap_dao( )->get_checks( lt_ztnum ).
    DATA(lt_forbidden) = value_list( iv_values = is_rule-param1 iv_default = `99` ).
    LOOP AT it_lines INTO DATA(ls_line).
      DATA(lv_ztnum) = ztnum_key( line_reference( ls_line ) ).
      IF lv_ztnum IS INITIAL.
        CONTINUE.
      ENDIF.
      IF house_bank_ambiguous( it_checks = lt_checks is_line = ls_line it_statements = it_statements ) = abap_true.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'HOUSE_BANK_AMBIGUOUS'
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-house_bank_ambiguous
                                                     iv_v1    = lv_ztnum ) )
          INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      DATA(lt_line_checks) = checks_for_line( it_checks = lt_checks is_line = ls_line it_statements = it_statements ).
      IF lt_line_checks IS INITIAL.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'CHECK_NOT_FOUND'
                 iv_message =
                   zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-check_not_found
                                          iv_v1 = lv_ztnum ) ) INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      " Fail closed: any forbidden register row fails, not only the first one
      LOOP AT lt_line_checks INTO DATA(ls_check).
        IF in_list( iv_value = ls_check-crstatus it_list = lt_forbidden ) = abap_true.
          INSERT zcl_cd_ebs_finding=>for_rule_line(
                   is_rule = is_rule is_line = ls_line iv_check_code = 'CHECK_STATUS'
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-check_status
                                                       iv_v1    = lv_ztnum
                                                       iv_v2    = ls_check-crstatus ) )
            INTO TABLE rt_findings.
          EXIT.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
