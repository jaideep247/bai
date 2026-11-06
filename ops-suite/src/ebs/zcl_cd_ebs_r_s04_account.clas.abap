*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s04_account.clas.abap
*& Purpose:
*& S04: the account must be configured and active in ZCD_EBS_ACCT and the
*& statement currency must equal the configured account currency.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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
    LOOP AT it_statements INTO DATA(ls_statement).
      DATA(ls_account) = VALUE #( lt_accounts[ account_no = ls_statement-account_no active = abap_true ] OPTIONAL ).
      IF ls_account IS INITIAL AND ls_statement-hbkid IS NOT INITIAL.
        ls_account = VALUE #( lt_accounts[ bukrs = ls_statement-bukrs hbkid = ls_statement-hbkid
                                           hktid = ls_statement-hktid active = abap_true ] OPTIONAL ).
      ENDIF.
      IF ls_account IS INITIAL.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'ACCOUNT_NOT_CONFIGURED'
                 iv_message = |Account { ls_statement-account_no } not active in ZCD_EBS_ACCT| ) INTO TABLE rt_findings.
      ELSEIF ls_account-currency IS NOT INITIAL AND ls_statement-currency IS NOT INITIAL
             AND ls_account-currency <> ls_statement-currency.
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'ACCOUNT_CURRENCY'
                 iv_message = |Statement in { ls_statement-currency }, account in { ls_account-currency }| )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
