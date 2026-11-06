*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s09_coverage.clas.abap
*& Purpose:
*& S09: every entry of a statement must be mapped in ZCD_BTC_MAP. One finding
*& per statement summarising unmapped (X01) entries; each entry already has its
*& own R14 block. Pure.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS check S09 - 100 % BTC mapping coverage</p>
CLASS zcl_cd_ebs_r_s09_coverage DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_s09_coverage IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    LOOP AT it_statements INTO DATA(ls_statement).
      DATA(lv_total) = 0.
      DATA(lv_unmapped) = 0.
      LOOP AT it_lines INTO DATA(ls_line) WHERE stmt_key = ls_statement-stmt_key.
        lv_total += 1.
        IF ls_line-category = zif_cd_ebs_types=>gc_category_unmapped.
          lv_unmapped += 1.
        ENDIF.
      ENDLOOP.
      IF lv_unmapped > 0.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'BTC_COVERAGE'
                 iv_message = |{ lv_unmapped } of { lv_total } entries have an unmapped transaction code| )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
