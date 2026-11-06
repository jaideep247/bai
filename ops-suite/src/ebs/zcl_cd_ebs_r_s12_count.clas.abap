*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s12_count.clas.abap
*& Purpose:
*& S12 (imported statements): the number of entries read must equal the
*& number the header declares. Files are checked by the parser. Pure.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS check S12 - entry count = declared count</p>
CLASS zcl_cd_ebs_r_s12_count DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_s12_count IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    LOOP AT it_statements INTO DATA(ls_statement)
         WHERE source = zif_cd_ebs_types=>gc_source-feb AND declared_count >= 0.
      DATA(lv_read) = REDUCE i( INIT lv_count = 0
                                FOR ls_line IN it_lines WHERE ( stmt_key = ls_statement-stmt_key )
                                NEXT lv_count = lv_count + 1 ).
      IF lv_read <> ls_statement-declared_count.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'ENTRY_COUNT'
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-entry_count
                                                     iv_v1    = ls_statement-declared_count
                                                     iv_v2    = lv_read ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
