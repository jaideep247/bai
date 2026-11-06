*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r05_reason.clas.abap
*& Purpose:
*& R05: a NACHA return reason (R01-R85) or NOC code (C01-C07) must be mapped
*& to an payment engine return reason in ZCD_EBS_RSN_MAP. PARAM1 = REQUIRED also
*& fails entries without a reason. Without any mapping only the format is checked.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A28: placeholder mapping incomplete, NOC vs return (PARAM2), required without mapping.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
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
    DATA(lv_required) = xsdbool( to_upper( condense( CONV string( is_rule-param1 ) ) )
                                 = zif_cd_ebs_types=>gc_rule_keyword-required ).
    DATA(lv_kind) = to_upper( condense( CONV string( is_rule-param2 ) ) ).
    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      IF <ls_line>-return_reason IS INITIAL.
        IF lv_required = abap_true.
          INSERT zcl_cd_ebs_finding=>for_rule_line(
                   is_rule = is_rule is_line = <ls_line> iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_missing
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-reason_missing
                                                       iv_v1    = <ls_line>-btc_code ) ) INTO TABLE rt_findings.
        ENDIF.
        CONTINUE.
      ENDIF.
      IF lt_reasons IS NOT INITIAL.
        READ TABLE lt_reasons INTO DATA(ls_map) WITH TABLE KEY reason = <ls_line>-return_reason.
        IF sy-subrc <> 0.
          INSERT zcl_cd_ebs_finding=>for_rule_line(
                   is_rule = is_rule is_line = <ls_line> iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_unmapped
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-reason_unmapped
                                                       iv_v1    = <ls_line>-return_reason ) )
            INTO TABLE rt_findings.
        ELSEIF ls_map-fica_reason IS INITIAL OR ls_map-fica_reason(1) = zif_cd_ebs_types=>gc_placeholder_prefix.
          " A28: a seeded placeholder is no mapping
          INSERT zcl_cd_ebs_finding=>for_rule_line(
                   is_rule = is_rule is_line = <ls_line> iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_map_incomplete
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-reason_map_incomplete
                                                       iv_v1    = <ls_line>-return_reason
                                                       iv_v2    = ls_map-fica_reason ) ) INTO TABLE rt_findings.
        ELSEIF ( lv_kind = zif_cd_ebs_types=>gc_rule_keyword-return AND ls_map-is_noc = abap_true )
            OR ( lv_kind = zif_cd_ebs_types=>gc_rule_keyword-noc    AND ls_map-is_noc = abap_false ).
          " A28: a NOC is never a return and a return never a NOC
          INSERT zcl_cd_ebs_finding=>for_rule_line(
                   is_rule = is_rule is_line = <ls_line> iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_kind
                   iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-reason_kind
                                                       iv_v1    = <ls_line>-return_reason
                                                       iv_v2    = lv_kind ) ) INTO TABLE rt_findings.
        ENDIF.
      ELSEIF lv_required = abap_true.
        " A28: a required reason cannot be validated without mapping - incomplete configuration
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = <ls_line> iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_map_incomplete
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-reason_map_incomplete
                                                     iv_v1    = <ls_line>-return_reason
                                                     iv_v2    = zif_cd_ebs_types=>gc_rule_keyword-required ) )
          INTO TABLE rt_findings.
      ELSEIF NOT matches( val = <ls_line>-return_reason pcre = gc_reason_pattern ).
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = <ls_line> iv_check_code = zif_cd_ebs_types=>gc_check_code-reason_invalid
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-reason_invalid
                                                     iv_v1    = <ls_line>-return_reason ) ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
