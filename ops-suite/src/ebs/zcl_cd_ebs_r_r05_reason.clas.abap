*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r05_reason.clas.abap
*& Purpose:
*& R05: a NACHA return reason (R01-R85) or NOC code (C01-C07) must be mapped
*& to an payment engine return reason in ZCD_EBS_RSN_MAP. PARAM1 = REQUIRED also
*& fails entries without a reason. Without any mapping only the format is checked.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R05 - valid return / NOC reason</p>
CLASS zcl_cd_ebs_r_r05_reason DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS gc_reason_pattern TYPE string VALUE `^(R(0[1-9]|[1-7][0-9]|8[0-5])|C0[1-7])\s*$`.
ENDCLASS.



CLASS zcl_cd_ebs_r_r05_reason IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA(lt_reasons) = zcl_cd_ebs_factory=>get_cfg_dao( )->get_reason_map( ).
    LOOP AT it_lines INTO DATA(ls_line).
      IF ls_line-return_reason IS INITIAL.
        IF to_upper( condense( CONV string( is_rule-param1 ) ) ) = `REQUIRED`.
          INSERT zcl_cd_ebs_finding=>for_rule_line(
                   is_rule = is_rule is_line = ls_line iv_check_code = 'REASON_MISSING'
                   iv_message = |Return/NOC reason missing for { ls_line-btc_code }| ) INTO TABLE rt_findings.
        ENDIF.
        CONTINUE.
      ENDIF.
      IF lt_reasons IS NOT INITIAL.
        IF NOT line_exists( lt_reasons[ reason = ls_line-return_reason ] ).
          INSERT zcl_cd_ebs_finding=>for_rule_line(
                   is_rule = is_rule is_line = ls_line iv_check_code = 'REASON_UNMAPPED'
                   iv_message = |Reason { ls_line-return_reason } not mapped to an payment engine return reason| )
            INTO TABLE rt_findings.
        ENDIF.
      ELSEIF NOT matches( val = ls_line-return_reason pcre = gc_reason_pattern ).
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'REASON_INVALID'
                 iv_message = |Reason { ls_line-return_reason } is not R01-R85 or C01-C07| ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
