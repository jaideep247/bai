*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s05_date.clas.abap
*& Purpose:
*& S05: a statement needs a date, not in the future and not older than
*& WINDOW_DAYS (default 10) against the system date.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'STMT_DATE_MISSING'
                 iv_message = 'Statement has no date' ) INTO TABLE rt_findings.
      ELSEIF ls_statement-stmt_date > lv_today.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'STMT_DATE_FUTURE'
                 iv_message = |Statement dated { ls_statement-stmt_date DATE = ISO } is in the future| )
          INTO TABLE rt_findings.
      ELSEIF lv_today - ls_statement-stmt_date > lv_window.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'STMT_DATE_STALE'
                 iv_message = |Statement dated { ls_statement-stmt_date DATE = ISO } is older than { lv_window } days| )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
