*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s01_continuity.clas.abap
*& Purpose:
*& S01: the opening balance must equal the closing balance of the previous
*& statement of the same account: an earlier statement in the same package, else
*& the latest imported one (FEBKO). Deviation above the tolerance fails.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS check S01 - opening = prior closing</p>
CLASS zcl_cd_ebs_r_s01_continuity DEFINITION
  PUBLIC
  INHERITING FROM zcl_cd_ebs_rule_base
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS zif_cd_ebs_rule~execute REDEFINITION.

ENDCLASS.



CLASS zcl_cd_ebs_r_s01_continuity IMPLEMENTATION.

  METHOD zif_cd_ebs_rule~execute.
    LOOP AT it_statements INTO DATA(ls_statement) WHERE has_opening = abap_true.
      DATA(lv_prior) = CONV zif_cd_ops_types=>ty_amount( 0 ).
      DATA(lv_found) = abap_false.
      LOOP AT it_statements INTO DATA(ls_other)
           WHERE account_no = ls_statement-account_no AND has_closing = abap_true
             AND ( stmt_date < ls_statement-stmt_date
                OR ( stmt_date = ls_statement-stmt_date AND stmt_no < ls_statement-stmt_no ) ).
        lv_prior = ls_other-closing_bal.
        lv_found = abap_true.
      ENDLOOP.
      IF lv_found = abap_false AND ls_statement-hbkid IS NOT INITIAL.
        DATA(ls_header) = feb_dao( )->get_prior_header( iv_bukrs  = ls_statement-bukrs
                                                         iv_hbkid  = ls_statement-hbkid
                                                         iv_hktid  = ls_statement-hktid
                                                         iv_before = ls_statement-stmt_date
                                                         iv_aznum  = CONV #( ls_statement-stmt_no ) ).
        IF ls_header IS NOT INITIAL.
          lv_found = abap_true.
          lv_prior = COND #( WHEN ls_header-esvoz = param( iv_name = 'EBS_FEB_DEBIT_IND' iv_default = `S` )
                             THEN - ls_header-esbtr ELSE ls_header-esbtr ).
        ENDIF.
      ENDIF.
      IF lv_found = abap_true AND abs( ls_statement-opening_bal - lv_prior ) > tolerance( is_rule ).
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = 'OPENING_NE_PRIOR_CLOSING'
                 iv_amount = ls_statement-opening_bal - lv_prior
                 iv_message = |Opening { ls_statement-opening_bal } <> prior closing { lv_prior }| )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
