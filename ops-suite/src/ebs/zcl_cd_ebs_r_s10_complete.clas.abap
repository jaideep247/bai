*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s10_complete.clas.abap
*& Purpose:
*& S10 (imported statements only): every entry must be posted (FI document)
*& or blocked with an open exception. Entries that are neither are reported -
*& nothing may silently stay in limbo. Pure.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS check S10 - every entry accounted for</p>
CLASS zcl_cd_ebs_r_s10_complete DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_s10_complete IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    LOOP AT it_statements INTO DATA(ls_statement) WHERE source = zif_cd_ebs_types=>gc_source-feb.
      DATA(lv_open) = 0.
      DATA(lv_amount) = CONV zif_cd_ops_types=>ty_amount( 0 ).
      LOOP AT it_lines INTO DATA(ls_line)
           WHERE stmt_key = ls_statement-stmt_key AND belnr IS INITIAL AND blocked = abap_false.
        lv_open += 1.
        lv_amount += ls_line-amount.
      ENDLOOP.
      IF lv_open > 0.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'ENTRIES_NOT_ACCOUNTED'
                 iv_amount = lv_amount
                 iv_message = |{ lv_open } entries neither posted nor blocked (total { lv_amount })| )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
