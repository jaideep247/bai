*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_r_s01_continuity.clas.abap
*& Purpose:
*& S01: the opening balance must equal the closing balance of the previous
*& statement of the same account: an earlier statement in the same package, else
*& the latest imported one (FEBKO). Deviation above the tolerance fails.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Nearest predecessor by date and number; stored statement wins when nearer (audit A15).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
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
    DATA lv_best_date TYPE d.
    DATA lv_best_no TYPE zif_cd_ebs_types=>ty_statement-stmt_no.
    LOOP AT it_statements INTO DATA(ls_statement) WHERE has_opening = abap_true.
      DATA(lv_prior) = CONV zif_cd_ops_types=>ty_amount( 0 ).
      DATA(lv_found) = abap_false.
      CLEAR: lv_best_date, lv_best_no.
      " Nearest earlier statement of the same account and currency in the package:
      " latest date, then highest statement number (table order is irrelevant)
      LOOP AT it_statements INTO DATA(ls_other)
           WHERE account_no = ls_statement-account_no AND currency = ls_statement-currency
             AND has_closing = abap_true
             AND ( stmt_date < ls_statement-stmt_date
                OR ( stmt_date = ls_statement-stmt_date AND stmt_no < ls_statement-stmt_no ) ).
        IF lv_found = abap_false OR ls_other-stmt_date > lv_best_date
           OR ( ls_other-stmt_date = lv_best_date AND ls_other-stmt_no > lv_best_no ).
          lv_prior     = ls_other-closing_bal.
          lv_best_date = ls_other-stmt_date.
          lv_best_no   = ls_other-stmt_no.
          lv_found     = abap_true.
        ENDIF.
      ENDLOOP.
      " The stored predecessor (FEBKO) is always consulted: it wins when it is nearer
      IF ls_statement-hbkid IS NOT INITIAL.
        DATA(ls_header) = feb_dao( )->get_prior_header( iv_bukrs  = ls_statement-bukrs
                                                         iv_hbkid  = ls_statement-hbkid
                                                         iv_hktid  = ls_statement-hktid
                                                         iv_before = ls_statement-stmt_date
                                                         iv_aznum  = CONV #( ls_statement-stmt_no ) ).
        IF ls_header IS NOT INITIAL
           AND ( lv_found = abap_false OR ls_header-azdat > lv_best_date
                 OR ( ls_header-azdat = lv_best_date AND CONV string( ls_header-aznum ) > CONV string( lv_best_no ) ) ).
          lv_found = abap_true.
          lv_prior = COND #( WHEN ls_header-esvoz = param( iv_name    = zif_cd_ebs_types=>gc_param-feb_debit_ind
                                                           iv_default = zif_cd_ebs_types=>gc_param_default-feb_debit_ind )
                             THEN - ls_header-esbtr ELSE ls_header-esbtr ).
        ENDIF.
      ENDIF.
      IF lv_found = abap_true AND abs( ls_statement-opening_bal - lv_prior ) > tolerance( is_rule ).
        INSERT zcl_cd_ebs_finding=>for_rule_statement(
                 is_rule = is_rule is_statement = ls_statement iv_check_code = zif_cd_ebs_types=>gc_check_code-opening_ne_prior_closing
                 iv_amount = ls_statement-opening_bal - lv_prior
                 iv_message = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-opening_ne_prior_closing
                                                     iv_v1    = ls_statement-opening_bal
                                                     iv_v2    = lv_prior ) )
          INTO TABLE rt_findings.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
