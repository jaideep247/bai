*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r10_value_date.clas.abap
*& Purpose:
*& R10: value date and booking date may differ by at most WINDOW_DAYS
*& (default 5). Also serves R13 (reversal window) when assigned to reversal
*& categories with their own window. Pure.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R10 - value date window</p>
CLASS zcl_cd_ebs_r_r10_value_date DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

  PRIVATE SECTION.
    CONSTANTS gc_default_window TYPE i VALUE 5.
ENDCLASS.



CLASS zcl_cd_ebs_r_r10_value_date IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA(lv_window) = COND i( WHEN is_rule-window_days > 0 THEN is_rule-window_days ELSE gc_default_window ).
    LOOP AT it_lines INTO DATA(ls_line) WHERE value_date IS NOT INITIAL AND booking_date IS NOT INITIAL.
      IF abs( ls_line-value_date - ls_line-booking_date ) > lv_window.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = zif_cd_ebs_types=>gc_check_code-value_date_window
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-value_date_window
                                                     iv_v1    = |{ ls_line-value_date DATE = ISO }|
                                                     iv_v2    = lv_window
                                                     iv_v3    = |{ ls_line-booking_date DATE = ISO }| ) ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
