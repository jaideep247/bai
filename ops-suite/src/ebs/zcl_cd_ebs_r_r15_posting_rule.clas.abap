*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r15_posting_rule.clas.abap
*& Purpose:
*& R15: the BTC map must prescribe a posting rule, and an imported entry must
*& have been interpreted with exactly that posting rule (FEBEP-VGINT). Pure.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R15 - posting rule resolves</p>
CLASS zcl_cd_ebs_r_r15_posting_rule DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r15_posting_rule IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    LOOP AT it_lines INTO DATA(ls_line).
      IF ls_line-map_posting IS INITIAL.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'POSTING_RULE_MISSING'
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-posting_rule_missing
                                                     iv_v1    = ls_line-btc_code ) ) INTO TABLE rt_findings.
      ELSEIF ls_line-posting_rule IS NOT INITIAL AND ls_line-posting_rule <> ls_line-map_posting.
        INSERT zcl_cd_ebs_finding=>for_rule_line(
                 is_rule = is_rule is_line = ls_line iv_check_code = 'POSTING_RULE_MISMATCH'
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-posting_rule_mismatch
                                                     iv_v1    = ls_line-posting_rule
                                                     iv_v2    = ls_line-map_posting ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
