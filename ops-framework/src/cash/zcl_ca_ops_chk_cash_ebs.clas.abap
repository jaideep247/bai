*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_cash_ebs.clas.abap
*& Purpose:
*& FI-CA cash check "bank statement" (catalogue process FICA_EBS_LOTS).
*& What should have happened: every house bank account that delivers
*& statements (a statement in the last CASH_EBS_ACCOUNT_DAYS) has one for
*& every working day of the business calendar; every line of an imported
*& statement is posted within CASH_EBS_POST_DAYS; the statements of the
*& house banks CASH_EBS_FICA_BANKS reach FI-CA as payment lots. Detected
*& on the database (FEBKO / FEBEP, DFKKZK-KUKEY): per account and day the
*& statement missing; no statement of any known account for a day = the
*& source is stale (one finding, not one per account); a non-working day
*& is not expected (information); lines not posted and lines without a
*& payment lot per statement, company code, account and currency. No
*& statement at all in the account window = expected accounts unknown:
*& "not evaluated", never green. Read-only.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*& 2026-11-16 | Exception contract (build K merge): returns the evidence rows of its findings.
*& 2026-11-16 | Evaluation state (build O): the run's evaluation (ZCL_CA_OPS_CASH_CTX=>EVAL) in TY_RESULT-EVAL.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash check - bank statement arrival and posting</p>
"! VERIFY V226 / V227: FEBKO-AZDAT the statement date of the business day, EDATE the import date, FEBEP-VB1OK set =
"! posted (posting area 1), a statement transferred to FI-CA is named by DFKKZK-KUKEY.
CLASS zcl_ca_ops_chk_cash_ebs DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_account,
        company_code TYPE bukrs,
        house_bank   TYPE zif_ca_ops_cash_types=>ty_bank_id,
        account_id   TYPE zif_ca_ops_cash_types=>ty_bank_id,
      END OF ty_account.
    TYPES tt_account TYPE SORTED TABLE OF ty_account WITH UNIQUE KEY company_code house_bank account_id.

    DATA mo_ctx TYPE REF TO zcl_ca_ops_cash_ctx.

    "! Statements expected per account and working day: missing, source stale, not expected
    METHODS arrival
      CHANGING
        cs_result TYPE zif_ca_ops_chk_types=>ty_result.

    "! The finding of an account without the day's statement
    METHODS missing
      IMPORTING
        iv_date           TYPE d
        is_account        TYPE ty_account
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! Lines not posted / not transferred to FI-CA
    METHODS statement_lines
      IMPORTING
        iv_stage  TYPE zif_ca_ops_cash_types=>ty_stage
      CHANGING
        cs_result TYPE zif_ca_ops_chk_types=>ty_result.

ENDCLASS.



CLASS zcl_ca_ops_chk_cash_ebs IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    mo_ctx = NEW #( is_check = is_check is_context = is_context ).
    arrival( CHANGING cs_result = rs_result ).
    statement_lines( EXPORTING iv_stage = zif_ca_ops_cash_types=>gc_stage-posting CHANGING cs_result = rs_result ).
    statement_lines( EXPORTING iv_stage = zif_ca_ops_cash_types=>gc_stage-transfer CHANGING cs_result = rs_result ).
    rs_result-partial = mo_ctx->partial( ).
    " exception contract: the typed evidence rows of the findings (stored by the runner)
    rs_result-evidence = mo_ctx->evidence( ).
    rs_result-eval = mo_ctx->eval( ).
  ENDMETHOD.


  METHOD arrival.
    DATA lt_accounts TYPE tt_account.
    DATA lt_present TYPE tt_account.

    TRY.
        DATA(lt_days) = mo_ctx->window_days( mo_ctx->param_int(
                          iv_name    = zif_ca_ops_cash_types=>gc_param-ebs_lag_days
                          iv_default = zif_ca_ops_cash_types=>gc_param_default-ebs_lag_days ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_calendar).
        INSERT mo_ctx->read_failed( iv_stage  = zif_ca_ops_cash_types=>gc_stage-arrival
                                    iv_source = zif_ca_ops_cash_types=>gc_source-calendar
                                    iv_param  = zif_ca_ops_cash_types=>gc_param-calendar
                                    ix_error  = lx_calendar ) INTO TABLE cs_result-findings.
        RETURN.
    ENDTRY.
    DATA(lv_account_days) = mo_ctx->param_int( iv_name    = zif_ca_ops_cash_types=>gc_param-ebs_account_days
                                         iv_default = zif_ca_ops_cash_types=>gc_param_default-ebs_account_days ).
    DATA(lv_from) = CONV d( mo_ctx->today( ) - lv_account_days ).
    IF lt_days IS NOT INITIAL AND lt_days[ 1 ]-date < lv_from.
      lv_from = lt_days[ 1 ]-date.
    ENDIF.
    TRY.
        DATA(lt_statements) = mo_ctx->dao( )->statement_days( iv_from = lv_from
                                                              iv_to   = mo_ctx->today( )
                                                              iv_max  = mo_ctx->max_rows( ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        INSERT mo_ctx->read_failed( iv_stage  = zif_ca_ops_cash_types=>gc_stage-arrival
                                    iv_source = zif_ca_ops_cash_types=>gc_source-statement
                                    ix_error  = lx_error ) INTO TABLE cs_result-findings.
        RETURN.
    ENDTRY.
    mo_ctx->cap( EXPORTING iv_stage    = zif_ca_ops_cash_types=>gc_stage-arrival
                           iv_source   = zif_ca_ops_cash_types=>gc_source-statement
                           iv_rows     = lines( lt_statements )
                 CHANGING  ct_findings = cs_result-findings ).
    lt_accounts = CORRESPONDING #( lt_statements DISCARDING DUPLICATES ).
    IF lt_accounts IS INITIAL.
      INSERT mo_ctx->not_evaluated( iv_stage  = zif_ca_ops_cash_types=>gc_stage-arrival
                                    iv_source = zif_ca_ops_cash_types=>gc_source-statement
                                    iv_param  = zif_ca_ops_cash_types=>gc_param-ebs_account_days
                                    iv_reason = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-no_accounts
                                                                       iv_v1    = lv_account_days ) )
             INTO TABLE cs_result-findings.
      RETURN.
    ENDIF.
    LOOP AT lt_days ASSIGNING FIELD-SYMBOL(<ls_day>).
      cs_result-item_count = cs_result-item_count + 1.
      IF <ls_day>-working = abap_false.
        INSERT mo_ctx->finding( VALUE #(
          check_code  = zif_ca_ops_cash_types=>gc_code-not_expected
          severity    = zif_ca_ops_types=>gc_severity-info
          stage       = zif_ca_ops_cash_types=>gc_stage-arrival
          evaluation  = zif_ca_ops_cash_types=>gc_evaluation-not_expected
          object_type = zif_ca_ops_cash_types=>gc_object_type-day
          object_key  = zcl_ca_ops_cash_exc=>object_key( <ls_day>-date )
          source      = zif_ca_ops_cash_types=>gc_source-calendar
          rule_param  = zif_ca_ops_cash_types=>gc_param-calendar
          evidence    = VALUE #( ( name = zif_ca_ops_cash_types=>gc_key-day value = <ls_day>-date ) )
          msgno       = zif_ca_ops_cash_types=>gc_msg-not_expected
          msgv1       = zif_ca_ops_cash_types=>gc_stage-arrival
          msgv2       = |{ <ls_day>-date DATE = ISO }|
          msgv3       = mo_ctx->param_text( zif_ca_ops_cash_types=>gc_param-calendar ) ) ) INTO TABLE cs_result-findings.
        CONTINUE.
      ENDIF.
      lt_present = CORRESPONDING #( VALUE zif_ca_ops_cash_types=>tt_statement_day(
                                      FOR ls_stmt IN lt_statements WHERE ( statement_date = <ls_day>-date ) ( ls_stmt ) )
                                    DISCARDING DUPLICATES ).
      IF lt_present IS INITIAL.
        " nothing arrived for any known account: the import is stale - one finding, not one per account
        INSERT mo_ctx->finding( VALUE #(
          check_code  = zif_ca_ops_cash_types=>gc_code-ebs_stale
          severity    = zif_ca_ops_types=>gc_severity-error
          stage       = zif_ca_ops_cash_types=>gc_stage-arrival
          evaluation  = zif_ca_ops_cash_types=>gc_evaluation-stale
          object_type = zif_ca_ops_cash_types=>gc_object_type-day
          object_key  = zcl_ca_ops_cash_exc=>object_key( <ls_day>-date )
          source      = zif_ca_ops_cash_types=>gc_source-statement
          item_count  = lines( lt_accounts )
          oldest      = <ls_day>-date
          rule_param  = zif_ca_ops_cash_types=>gc_param-ebs_account_days
          evidence    = VALUE #( ( name = zif_ca_ops_cash_types=>gc_key-day value = <ls_day>-date ) )
          msgno       = zif_ca_ops_cash_types=>gc_msg-ebs_stale
          msgv1       = |{ <ls_day>-date DATE = ISO }|
          msgv2       = |{ lines( lt_accounts ) }| ) ) INTO TABLE cs_result-findings.
        CONTINUE.
      ENDIF.
      LOOP AT lt_accounts ASSIGNING FIELD-SYMBOL(<ls_account>).
        IF NOT line_exists( lt_present[ company_code = <ls_account>-company_code
                                        house_bank   = <ls_account>-house_bank
                                        account_id   = <ls_account>-account_id ] ).
          INSERT missing( iv_date = <ls_day>-date is_account = <ls_account> ) INTO TABLE cs_result-findings.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD missing.
    DATA(lv_account) = |{ is_account-house_bank }/{ is_account-account_id }|.
    rs_finding = mo_ctx->finding( VALUE #(
      check_code   = zif_ca_ops_cash_types=>gc_code-ebs_missing
      severity     = zif_ca_ops_types=>gc_severity-error
      stage        = zif_ca_ops_cash_types=>gc_stage-arrival
      object_type  = zif_ca_ops_cash_types=>gc_object_type-bank_account
      object_key   = zcl_ca_ops_cash_exc=>object_key( iv_id      = iv_date
                                                     iv_sub     = lv_account
                                                     iv_company = is_account-company_code )
      source       = zif_ca_ops_cash_types=>gc_source-statement
      company_code = is_account-company_code
      account      = lv_account
      oldest       = iv_date
      rule_param   = zif_ca_ops_cash_types=>gc_param-ebs_account_days
      evidence     = VALUE #( ( name = zif_ca_ops_cash_types=>gc_key-account value = lv_account )
                              ( name = zif_ca_ops_cash_types=>gc_key-day value = iv_date ) )
      msgno        = zif_ca_ops_cash_types=>gc_msg-ebs_missing
      msgv1        = |{ iv_date DATE = ISO }|
      msgv2        = is_account-house_bank
      msgv3        = is_account-account_id
      msgv4        = is_account-company_code ) ).
  ENDMETHOD.


  METHOD statement_lines.
    DATA lt_sums TYPE zif_ca_ops_cash_types=>tt_sum.

    DATA(lv_imported_to) = CONV d( mo_ctx->today( ) - mo_ctx->param_int(
                                     iv_name    = zif_ca_ops_cash_types=>gc_param-ebs_post_days
                                     iv_default = zif_ca_ops_cash_types=>gc_param_default-ebs_post_days ) ).
    DATA lv_source TYPE zif_ca_ops_types=>ty_reference.
    DATA lv_param TYPE zif_ca_ops_types=>ty_param_name.

    DATA(lv_transfer) = xsdbool( iv_stage = zif_ca_ops_cash_types=>gc_stage-transfer ).
    IF lv_transfer = abap_true.
      lv_source = zif_ca_ops_cash_types=>gc_source-to_fica.
      lv_param  = zif_ca_ops_cash_types=>gc_param-ebs_fica_banks.
    ELSE.
      lv_source = zif_ca_ops_cash_types=>gc_source-statement.
      lv_param  = zif_ca_ops_cash_types=>gc_param-ebs_post_days.
    ENDIF.
    TRY.
        IF lv_transfer = abap_true.
          DATA(lt_banks) = mo_ctx->param_range( lv_param ).
          IF lt_banks IS INITIAL.
            INSERT mo_ctx->pending( iv_stage  = iv_stage
                                    iv_source = lv_source
                                    iv_param  = lv_param ) INTO TABLE cs_result-findings.
            RETURN.
          ENDIF.
          lt_sums = mo_ctx->dao( )->lines_not_in_fica( it_banks       = lt_banks
                                                       iv_imported_to = lv_imported_to
                                                       iv_max         = mo_ctx->max_rows( ) ).
        ELSE.
          lt_sums = mo_ctx->dao( )->unposted_lines( iv_imported_to = lv_imported_to iv_max = mo_ctx->max_rows( ) ).
        ENDIF.
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        INSERT mo_ctx->read_failed( iv_stage  = iv_stage
                                    iv_source = lv_source
                                    iv_param  = lv_param
                                    ix_error  = lx_error ) INTO TABLE cs_result-findings.
        RETURN.
    ENDTRY.
    mo_ctx->cap( EXPORTING iv_stage    = iv_stage
                           iv_source   = lv_source
                           iv_rows     = lines( lt_sums )
                 CHANGING  ct_findings = cs_result-findings ).
    cs_result-item_count = cs_result-item_count + lines( lt_sums ).
    LOOP AT lt_sums ASSIGNING FIELD-SYMBOL(<ls_sum>).
      DATA(lv_account) = |{ <ls_sum>-house_bank }/{ <ls_sum>-account_id }|.
      INSERT mo_ctx->finding( VALUE #(
        check_code   = COND #( WHEN lv_transfer = abap_true THEN zif_ca_ops_cash_types=>gc_code-ebs_not_fica
                               ELSE zif_ca_ops_cash_types=>gc_code-ebs_unposted )
        severity     = zif_ca_ops_types=>gc_severity-error
        stage        = iv_stage
        object_type  = zif_ca_ops_cash_types=>gc_object_type-statement
        object_key   = zcl_ca_ops_cash_exc=>object_key( iv_id       = <ls_sum>-object_id
                                                        iv_company  = <ls_sum>-company_code
                                                        iv_currency = <ls_sum>-currency )
        source       = lv_source
        company_code = <ls_sum>-company_code
        currency     = <ls_sum>-currency
        account      = lv_account
        item_count   = <ls_sum>-item_count
        amount       = <ls_sum>-amount
        oldest       = <ls_sum>-oldest
        rule_param   = lv_param
        evidence     = VALUE #( ( name = zif_ca_ops_cash_types=>gc_key-statement value = <ls_sum>-object_id )
                                ( name = zif_ca_ops_cash_types=>gc_key-account value = lv_account ) )
        msgno        = COND #( WHEN lv_transfer = abap_true THEN zif_ca_ops_cash_types=>gc_msg-ebs_not_fica
                               ELSE zif_ca_ops_cash_types=>gc_msg-ebs_unposted )
        msgv1        = condense( CONV string( <ls_sum>-object_id ) )
        msgv2        = lv_account
        msgv3        = |{ <ls_sum>-item_count }|
        msgv4        = zcl_ca_ops_cash_exc=>amount_text( iv_amount   = <ls_sum>-amount
                                                         iv_currency = <ls_sum>-currency ) ) ) INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
