*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r02_bounds.clas.abap
*& Purpose:
*& R02: amount must lie between PARAM1 (minimum) and PARAM2 (maximum) of
*& the rule assignment. Blank bound = not checked. Also serves R11 (fee
*& tolerance) when configured with the fee schedule bounds. Pure.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R02 - amount bounds</p>
CLASS zcl_cd_ebs_r_r02_bounds DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r02_bounds IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA(lv_min) = amount_param( is_rule-param1 ).
    DATA(lv_max) = amount_param( is_rule-param2 ).
    LOOP AT it_lines INTO DATA(ls_line).
      IF is_rule-param1 IS NOT INITIAL AND ls_line-amount < lv_min.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = zif_cd_ebs_types=>gc_check_code-amount_below_min
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-amount_below_min
                                                     iv_v1    = ls_line-amount
                                                     iv_v2    = lv_min ) ) INTO TABLE rt_findings.
      ELSEIF is_rule-param2 IS NOT INITIAL AND ls_line-amount > lv_max.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = zif_cd_ebs_types=>gc_check_code-amount_above_max
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-amount_above_max
                                                     iv_v1    = ls_line-amount
                                                     iv_v2    = lv_max ) ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
