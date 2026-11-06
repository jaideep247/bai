*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r01_sign.clas.abap
*& Purpose:
*& R01: the credit/debit indicator must match the direction the BTC map
*& expects for the code (ZCD_BTC_MAP-EXP_CDI). A reversal may carry the
*& opposite sign. Pure; no repository.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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
    LOOP AT it_lines INTO DATA(ls_line)
         WHERE exp_cdi = zif_cd_ebs_types=>gc_cdi-credit OR exp_cdi = zif_cd_ebs_types=>gc_cdi-debit.
      IF ls_line-cdi = ls_line-exp_cdi OR ls_line-reversal = abap_true.
        CONTINUE.
      ENDIF.
      INSERT zcl_cd_ebs_finding=>for_rule_line(
               is_rule = is_rule is_line = ls_line iv_check_code = 'SIGN_MISMATCH'
               iv_message = |{ ls_line-btc_code } expects { ls_line-exp_cdi }, bank sent { ls_line-cdi }| )
        INTO TABLE rt_findings.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
