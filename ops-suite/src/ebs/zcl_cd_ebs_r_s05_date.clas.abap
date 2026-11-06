*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s05_date.clas.abap
*& Purpose:
*& S05: a statement needs a date, not in the future and not older than
*& WINDOW_DAYS (default 10) against the system date.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS check S05 - statement date sanity</p>
CLASS zcl_cd_ebs_r_s05_date DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS gc_default_window TYPE i VALUE 10.
ENDCLASS.



CLASS zcl_cd_ebs_r_s05_date IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA(lv_today) = zcl_cd_ops_factory=>get_clock( )->today( ).
    DATA(lv_window) = COND i( WHEN is_rule-window_days > 0 THEN is_rule-window_days ELSE gc_default_window ).
    LOOP AT it_statements INTO DATA(ls_statement).
      IF ls_statement-stmt_date IS INITIAL.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = zif_cd_ebs_types=>gc_check_code-stmt_date_missing
                 iv_message = zcl_cd_ops_util=>text( zif_cd_ebs_types=>gc_msg-stmt_date_missing ) ) INTO TABLE rt_findings.
      ELSEIF ls_statement-stmt_date > lv_today.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = zif_cd_ebs_types=>gc_check_code-stmt_date_future
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-stmt_date_future
                                                     iv_v1    = |{ ls_statement-stmt_date DATE = ISO }| ) )
          INTO TABLE rt_findings.
      ELSEIF lv_today - ls_statement-stmt_date > lv_window.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = zif_cd_ebs_types=>gc_check_code-stmt_date_stale
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-stmt_date_stale
                                                     iv_v1    = |{ ls_statement-stmt_date DATE = ISO }|
                                                     iv_v2    = lv_window ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
