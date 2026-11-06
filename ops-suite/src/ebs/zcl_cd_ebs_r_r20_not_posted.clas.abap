*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r20_not_posted.clas.abap
*& Purpose:
*& R20: entries of this group must not carry an FI document (e.g. ZBA sweeps
*& 275/575 are not posted by EBS). Legacy parity: v4 275D/575D BELNR_NOT_EMPTY.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R20 - entry must not be posted</p>
CLASS zcl_cd_ebs_r_r20_not_posted DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r20_not_posted IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    LOOP AT it_lines INTO DATA(ls_line) WHERE belnr IS NOT INITIAL.
      INSERT zcl_cd_ebs_finding=>for_rule_line(
               is_rule = is_rule is_line = ls_line iv_check_code = 'POSTED_UNEXPECTEDLY'
               iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-posted_unexpectedly
                                                   iv_v1    = ls_line-btc_code
                                                   iv_v2    = ls_line-belnr ) )
        INTO TABLE rt_findings.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
