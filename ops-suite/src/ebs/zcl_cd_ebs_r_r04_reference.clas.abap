*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r04_reference.clas.abap
*& Purpose:
*& R04: the reference used for matching must be present. PARAM1 selects it:
*& REFERENCE (default), E2E, CHECK, INSTR. PARAM2 = ALNUM also enforces
*& letters/digits only (legacy CHECT_FORMAT). NOTPROVIDED counts as missing.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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
                 is_rule = is_rule is_line = ls_line iv_check_code = 'REF_MISSING'
                 iv_message = |Required reference { is_rule-param1 } missing for { ls_line-btc_code }| )
          INTO TABLE rt_findings.
      ELSEIF to_upper( condense( CONV string( is_rule-param2 ) ) ) = `ALNUM`
             AND to_upper( lv_reference ) CN gc_alnum.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'REF_FORMAT'
                 iv_message = |Reference { lv_reference } is not alphanumeric| ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
