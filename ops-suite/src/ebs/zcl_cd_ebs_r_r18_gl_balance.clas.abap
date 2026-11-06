*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_r18_gl_balance.clas.abap
*& Purpose:
*& R18 (statement level, after posting): the bank G/L account balance
*& (ZCD_EBS_ACCT-GL_ACCOUNT) up to the statement date must equal the statement
*& closing balance within the tolerance.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Missing G/L account reported as GL_ACCOUNT_NOT_MAPPED instead of skipped (audit 2026-11-06).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS check R18 - bank G/L balance = closing</p>
CLASS zcl_cd_ebs_r_r18_gl_balance DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_r18_gl_balance IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA(lt_accounts) = zcl_cd_ebs_factory=>get_cfg_dao( )->get_accounts( ).
    LOOP AT it_statements INTO DATA(ls_statement) WHERE has_closing = abap_true AND bukrs IS NOT INITIAL.
      DATA(lv_gl_account) = VALUE #( lt_accounts[ account_no = ls_statement-account_no active = abap_true ]-gl_account
                                     OPTIONAL ).
      IF lv_gl_account IS INITIAL.
        " No silent pass: a statement that cannot be reconciled is reported
        " (an account missing from ZCD_EBS_ACCT altogether is S04's finding)
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'GL_ACCOUNT_NOT_MAPPED'
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-gl_account_not_mapped
                                                     iv_v1    = ls_statement-account_no ) )
          INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      DATA(lv_balance) = sap_dao( )->get_gl_balance( iv_bukrs      = ls_statement-bukrs
                                                     iv_gl_account = lv_gl_account
                                                     iv_currency   = ls_statement-currency
                                                     iv_date       = ls_statement-stmt_date ).
      IF abs( lv_balance - ls_statement-closing_bal ) > tolerance( is_rule ).
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'GL_NE_CLOSING'
                 iv_amount = lv_balance - ls_statement-closing_bal
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-gl_ne_closing
                                                     iv_v1    = lv_gl_account
                                                     iv_v2    = lv_balance
                                                     iv_v3    = ls_statement-closing_bal ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
