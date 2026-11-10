*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s04_account.clas.abap
*& Purpose:
*& S04: the account must be configured and active in ZCD_EBS_ACCT and the
*& statement currency must equal the configured account currency.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A33: house bank identity preferred; missing currency reported.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-10 | Texts name the account as house bank / account ID, else masked to its last four characters.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS check S04 - account and currency valid</p>
CLASS zcl_cd_ebs_r_s04_account DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_s04_account IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    DATA(lt_accounts) = zcl_cd_ebs_factory=>get_cfg_dao( )->get_accounts( ).
    LOOP AT it_statements ASSIGNING FIELD-SYMBOL(<ls_statement>).
      " A33: complete SAP house bank identity first, then the bank account number
      DATA(ls_account) = account_of( it_accounts = lt_accounts is_statement = <ls_statement> ).
      IF ls_account IS INITIAL.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = <ls_statement> iv_check_code = zif_cd_ebs_types=>gc_check_code-account_not_configured
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-account_not_configured
                                                     iv_v1    = zcl_cd_ops_util=>account_label(
                                                                  iv_account = <ls_statement>-account_no
                                                                  iv_hbkid   = <ls_statement>-hbkid
                                                                  iv_hktid   = <ls_statement>-hktid ) ) )
          INTO TABLE rt_findings.
      ELSEIF ls_account-currency IS INITIAL OR <ls_statement>-currency IS INITIAL.
        " A33: a currency that is not known cannot be validated - reported, never skipped
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = <ls_statement>
                 iv_check_code = zif_cd_ebs_types=>gc_check_code-account_currency_missing
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-account_currency_missing
                                                     iv_v1    = account_key( <ls_statement> ) ) ) INTO TABLE rt_findings.
      ELSEIF ls_account-currency <> <ls_statement>-currency.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = <ls_statement> iv_check_code = zif_cd_ebs_types=>gc_check_code-account_currency
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-account_currency
                                                     iv_v1    = <ls_statement>-currency
                                                     iv_v2    = ls_account-currency ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
