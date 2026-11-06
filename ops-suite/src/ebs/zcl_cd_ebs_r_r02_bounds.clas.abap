*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r02_bounds.clas.abap
*& Purpose:
*& R02: amount must lie between PARAM1 (minimum) and PARAM2 (maximum) of
*& the rule assignment. Blank bound = not checked. Also serves R11 (fee
*& tolerance) when configured with the fee schedule bounds. Pure.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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
                 is_rule = is_rule is_line = ls_line iv_check_code = 'AMOUNT_BELOW_MIN'
                 iv_message = |Amount { ls_line-amount } below minimum { lv_min }| ) INTO TABLE rt_findings.
      ELSEIF is_rule-param2 IS NOT INITIAL AND ls_line-amount > lv_max.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'AMOUNT_ABOVE_MAX'
                 iv_message = |Amount { ls_line-amount } above maximum { lv_max }| ) INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
