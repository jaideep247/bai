*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s03_sequence.clas.abap
*& Purpose:
*& S03: numeric statement numbers of an account must follow the previous one
*& without gap or repeat (previous = latest imported FEBKO statement).
*& Non-numeric numbers (some CAMT banks) are not checked.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS check S03 - statement number continuity</p>
CLASS zcl_cd_ebs_r_s03_sequence DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS gc_digits TYPE string VALUE `0123456789`.
ENDCLASS.



CLASS zcl_cd_ebs_r_s03_sequence IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    LOOP AT it_statements INTO DATA(ls_statement) WHERE hbkid IS NOT INITIAL.
      DATA(lv_number) = condense( CONV string( ls_statement-stmt_no ) ).
      IF lv_number IS INITIAL OR lv_number CN gc_digits.
        CONTINUE.
      ENDIF.
      DATA(ls_header) = feb_dao( )->get_prior_header( iv_bukrs  = ls_statement-bukrs
                                                       iv_hbkid  = ls_statement-hbkid
                                                       iv_hktid  = ls_statement-hktid
                                                       iv_before = ls_statement-stmt_date
                                                       iv_aznum  = CONV #( ls_statement-stmt_no ) ).
      DATA(lv_prior) = condense( CONV string( ls_header-aznum ) ).
      IF lv_prior IS INITIAL OR lv_prior CN gc_digits.
        CONTINUE.
      ENDIF.
      DATA(lv_expected) = CONV i( lv_prior ) + 1.
      DATA(lv_actual) = CONV i( lv_number ).
      IF lv_actual > lv_expected.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'STMT_NO_GAP'
                 iv_message = |Statement { lv_actual } follows { lv_prior }: { lv_actual - lv_expected } missing| )
          INTO TABLE rt_findings.
      ELSEIF lv_actual < lv_expected.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'STMT_NO_REPEAT'
                 iv_message = |Statement { lv_actual } not after last imported { lv_prior }| )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
