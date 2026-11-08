*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s09_coverage.clas.abap
*& Purpose:
*& S09: every entry of a statement must be mapped in ZBTM. One finding
*& per statement summarising unmapped (X01) entries; each entry already has its
*& own R14 block. Pure.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A35: lines read by statement key.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-08 | Customer posting area: the map is ZBTM (FQC0; was ZCD_BTC_MAP) - comment only.
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
    LOOP AT it_statements ASSIGNING FIELD-SYMBOL(<ls_statement>).
      DATA(lv_total) = 0.
      DATA(lv_unmapped) = 0.
      LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>) USING KEY stmt WHERE stmt_key = <ls_statement>-stmt_key.
        lv_total += 1.
        IF <ls_line>-category = zif_cd_ebs_types=>gc_category_unmapped.
          lv_unmapped += 1.
        ENDIF.
      ENDLOOP.
      IF lv_unmapped > 0.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = <ls_statement> iv_check_code = zif_cd_ebs_types=>gc_check_code-btc_coverage
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-btc_coverage
                                                     iv_v1    = lv_unmapped
                                                     iv_v2    = lv_total ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
