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
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A25: G/L account found through the canonical account identity.
*& 2026-11-06 | Performance fix 6: one G/L balance read for all closing statements of the package.
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
    DATA lt_requests TYPE zif_cd_ebs_sap_dao=>tt_gl_request.
    DATA ls_request TYPE zif_cd_ebs_sap_dao=>ty_gl_request.
    DATA(lt_accounts) = zcl_cd_ebs_factory=>get_cfg_dao( )->get_accounts( ).
    " Fix 6: one balance request per mapped closing statement, read in one statement
    LOOP AT it_statements ASSIGNING FIELD-SYMBOL(<ls_request_stmt>)
         WHERE has_closing = abap_true AND bukrs IS NOT INITIAL.
      " The statement's row number identifies the request (statement keys need not be unique)
      ls_request-request_no = sy-tabix.
      " A25 / A16: house bank identity first, then account number
      ls_request-gl_account = account_of( it_accounts = lt_accounts is_statement = <ls_request_stmt> )-gl_account.
      IF ls_request-gl_account IS INITIAL.
        CONTINUE.
      ENDIF.
      ls_request-bukrs      = <ls_request_stmt>-bukrs.
      ls_request-currency   = <ls_request_stmt>-currency.
      ls_request-stmt_date  = <ls_request_stmt>-stmt_date.
      INSERT ls_request INTO TABLE lt_requests.
    ENDLOOP.
    DATA(lt_balances) = sap_dao( )->get_gl_balances( lt_requests ).

    " Findings in statement order, as before
    LOOP AT it_statements ASSIGNING FIELD-SYMBOL(<ls_statement>) WHERE has_closing = abap_true AND bukrs IS NOT INITIAL.
      DATA(lv_request_no) = sy-tabix.
      DATA(lv_gl_account) = VALUE #( lt_requests[ request_no = lv_request_no ]-gl_account OPTIONAL ).
      IF lv_gl_account IS INITIAL.
        " No silent pass: a statement that cannot be reconciled is reported
        " (an account missing from ZCD_EBS_ACCT altogether is S04's finding)
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = <ls_statement> iv_check_code = zif_cd_ebs_types=>gc_check_code-gl_account_not_mapped
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-gl_account_not_mapped
                                                     iv_v1    = <ls_statement>-account_no ) )
          INTO TABLE rt_findings.
        CONTINUE.
      ENDIF.
      " No posting up to the date: balance 0 (SUM over no rows)
      DATA(lv_balance) = VALUE #( lt_balances[ request_no = lv_request_no ]-balance OPTIONAL ).
      IF abs( lv_balance - <ls_statement>-closing_bal ) > tolerance( is_rule ).
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = <ls_statement> iv_check_code = zif_cd_ebs_types=>gc_check_code-gl_ne_closing
                 iv_amount = lv_balance - <ls_statement>-closing_bal
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-gl_ne_closing
                                                     iv_v1    = lv_gl_account
                                                     iv_v2    = lv_balance
                                                     iv_v3    = <ls_statement>-closing_bal ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
