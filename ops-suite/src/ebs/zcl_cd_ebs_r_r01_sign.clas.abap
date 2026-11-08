*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r01_sign.clas.abap
*& Purpose:
*& R01: the credit/debit indicator must match the direction the BTC map
*& expects for the code (ZBTM result EXP_CDI). A reversal may carry the
*& opposite sign. Pure; no repository.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-08 | Customer posting area: EXP_CDI is a result of ZBTM (was ZCD_BTC_MAP) - comment only.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS rule R01 - amount sign vs expected direction</p>
CLASS zcl_cd_ebs_r_r01_sign DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r01_sign IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    LOOP AT it_lines ASSIGNING FIELD-SYMBOL(<ls_line>)
         WHERE exp_cdi = zif_cd_ebs_types=>gc_cdi-credit OR exp_cdi = zif_cd_ebs_types=>gc_cdi-debit.
      IF <ls_line>-cdi = <ls_line>-exp_cdi OR <ls_line>-reversal = abap_true.
        CONTINUE.
      ENDIF.
      INSERT zcl_cd_ebs_finding=>for_rule_line(
               is_rule = is_rule is_line = <ls_line> iv_check_code = zif_cd_ebs_types=>gc_check_code-sign_mismatch
               iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-sign_mismatch
                                                   iv_v1    = <ls_line>-btc_code
                                                   iv_v2    = <ls_line>-exp_cdi
                                                   iv_v3    = <ls_line>-cdi ) )
        INTO TABLE rt_findings.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
