*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s10_complete.clas.abap
*& Purpose:
*& S10 (imported statements only): every entry must be posted (FI document)
*& or blocked with an open exception. Entries that are neither are reported -
*& nothing may silently stay in limbo. Pure.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A26 / A35: NOT_POSTED entries complete; statement key.
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
      " A26: an entry the business never posts (NOT_POSTED, e.g. sweeps) is complete unposted
      LOOP AT it_lines INTO DATA(ls_line) USING KEY stmt
           WHERE stmt_key = ls_statement-stmt_key AND belnr IS INITIAL AND blocked = abap_false
             AND not_posted = abap_false.
        lv_open += 1.
        lv_amount += ls_line-amount.
      ENDLOOP.
      IF lv_open > 0.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = zif_cd_ebs_types=>gc_check_code-entries_not_accounted
                 iv_amount = lv_amount
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-entries_not_accounted
                                                     iv_v1    = lv_open
                                                     iv_v2    = lv_amount ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
