*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r04_reference.clas.abap
*& Purpose:
*& R04: the reference used for matching must be present. PARAM1 selects it:
*& REFERENCE (default), E2E, CHECK, INSTR. PARAM2 = ALNUM also enforces
*& letters/digits only (legacy CHECT_FORMAT). NOTPROVIDED counts as missing.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R04 - required reference present</p>
CLASS zcl_cd_ebs_r_r04_reference DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS gc_not_provided TYPE string VALUE `NOTPROVIDED`.
    CONSTANTS gc_alnum TYPE string VALUE `0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ`.
ENDCLASS.



CLASS zcl_cd_ebs_r_r04_reference IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    LOOP AT it_lines INTO DATA(ls_line).
      DATA(lv_reference) = condense( SWITCH string( to_upper( condense( CONV string( is_rule-param1 ) ) )
                                                    WHEN `E2E`   THEN ls_line-end_to_end_id
                                                    WHEN `CHECK` THEN ls_line-check_no
                                                    WHEN `INSTR` THEN ls_line-instr_id
                                                    ELSE ls_line-reference ) ).
      IF lv_reference IS INITIAL OR lv_reference = gc_not_provided.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = zif_cd_ebs_types=>gc_check_code-ref_missing
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-ref_missing
                                                     iv_v1    = is_rule-param1
                                                     iv_v2    = ls_line-btc_code ) )
          INTO TABLE rt_findings.
      ELSEIF to_upper( condense( CONV string( is_rule-param2 ) ) ) = `ALNUM`
             AND to_upper( lv_reference ) CN gc_alnum.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = zif_cd_ebs_types=>gc_check_code-ref_format
                 iv_message =
                   zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-ref_format
                                          iv_v1 = lv_reference ) ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
