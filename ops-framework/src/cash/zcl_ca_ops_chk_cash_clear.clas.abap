*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_cash_clear.clas.abap
*& Purpose:
*& FI-CA cash check "clearing reset and reversal after payout" (catalogue
*& process FICA_CLEARING). What should have happened: once a payment run
*& paid an item, its clearing stays and its payment document stays
*& unreversed - money that left the bank is not re-opened silently.
*& Detected on the database for the last CASH_CLR_DAYS: clearings reset
*& (DFKKRAPT, clearing reason in CASH_CLR_AUGRD, blank = any) whose clearing
*& document is the payment document of a payment run (DPAYH-DOC1R, not a
*& proposal), and payment documents of payment runs reversed (DFKKKO
*& STBEL, entry date of the reversal) - per document, company code and
*& currency. An event in the window never goes away by itself: the check
*& is always partial (an operator confirms and resolves the exception, as
*& the outage check). A failed read is "not evaluated". Read-only.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*& 2026-11-16 | Exception contract (build K merge): returns the evidence rows of its findings.
*& 2026-11-16 | Evaluation state (build O): the run's evaluation (ZCL_CA_OPS_CASH_CTX=>EVAL) in TY_RESULT-EVAL.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash check - clearing reset / reversal after payout</p>
"! VERIFY V228: DFKKRAPT STDAT / AUGBL / AUGRD, DFKKKO-STBEL of the reversed document and CPUDT of the reversal.
CLASS zcl_ca_ops_chk_cash_clear DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

  PRIVATE SECTION.
    DATA mo_ctx TYPE REF TO zcl_ca_ops_cash_ctx.

    METHODS resets
      IMPORTING
        iv_from   TYPE d
      CHANGING
        cs_result TYPE zif_ca_ops_chk_types=>ty_result.

    METHODS reversals
      IMPORTING
        iv_from   TYPE d
      CHANGING
        cs_result TYPE zif_ca_ops_chk_types=>ty_result.

ENDCLASS.



CLASS zcl_ca_ops_chk_cash_clear IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    mo_ctx = NEW #( is_check = is_check is_context = is_context ).
    DATA(lv_from) = CONV d( mo_ctx->today( ) - mo_ctx->param_int(
                              iv_name    = zif_ca_ops_cash_types=>gc_param-clr_days
                              iv_default = zif_ca_ops_cash_types=>gc_param_default-clr_days ) ).
    resets( EXPORTING iv_from = lv_from CHANGING cs_result = rs_result ).
    reversals( EXPORTING iv_from = lv_from CHANGING cs_result = rs_result ).
    " an exception of the window is closed by an operator, never auto-resolved when the window moved on
    rs_result-partial = abap_true.
    " exception contract: the typed evidence rows of the findings (stored by the runner)
    rs_result-evidence = mo_ctx->evidence( ).
    rs_result-eval = mo_ctx->eval( ).
  ENDMETHOD.


  METHOD resets.
    TRY.
        DATA(lt_sums) = mo_ctx->dao( )->paid_clearing_resets(
                          iv_reset_from = iv_from
                          it_augrd      = mo_ctx->param_range( zif_ca_ops_cash_types=>gc_param-clr_augrd )
                          iv_max        = mo_ctx->max_rows( ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        INSERT mo_ctx->read_failed( iv_stage  = zif_ca_ops_cash_types=>gc_stage-reset
                                    iv_source = zif_ca_ops_cash_types=>gc_source-resets
                                    iv_param  = zif_ca_ops_cash_types=>gc_param-clr_augrd
                                    ix_error  = lx_error ) INTO TABLE cs_result-findings.
        RETURN.
    ENDTRY.
    mo_ctx->cap( EXPORTING iv_stage    = zif_ca_ops_cash_types=>gc_stage-reset
                           iv_source   = zif_ca_ops_cash_types=>gc_source-resets
                           iv_rows     = lines( lt_sums )
                 CHANGING  ct_findings = cs_result-findings ).
    cs_result-item_count = cs_result-item_count + lines( lt_sums ).
    LOOP AT lt_sums ASSIGNING FIELD-SYMBOL(<ls_sum>).
      INSERT mo_ctx->finding( VALUE #(
        check_code   = zif_ca_ops_cash_types=>gc_code-clr_reset
        severity     = zif_ca_ops_types=>gc_severity-error
        stage        = zif_ca_ops_cash_types=>gc_stage-reset
        object_type  = zif_ca_ops_cash_types=>gc_object_type-document
        object_key   = zcl_ca_ops_cash_exc=>object_key( iv_id       = <ls_sum>-object_id
                                                        iv_company  = <ls_sum>-company_code
                                                        iv_currency = <ls_sum>-currency )
        source       = zif_ca_ops_cash_types=>gc_source-resets
        company_code = <ls_sum>-company_code
        currency     = <ls_sum>-currency
        item_count   = <ls_sum>-item_count
        amount       = <ls_sum>-amount
        oldest       = <ls_sum>-oldest
        rule_param   = zif_ca_ops_cash_types=>gc_param-clr_augrd
        evidence     = VALUE #( ( name = zif_ca_ops_cash_types=>gc_key-clearing value = <ls_sum>-object_id )
                                ( name = zif_ca_ops_cash_types=>gc_key-payment value = <ls_sum>-object_id ) )
        msgno        = zif_ca_ops_cash_types=>gc_msg-clr_reset
        msgv1        = condense( CONV string( <ls_sum>-object_id ) )
        msgv2        = |{ <ls_sum>-item_count }|
        msgv3        = zcl_ca_ops_cash_exc=>amount_text( iv_amount   = <ls_sum>-amount
                                                         iv_currency = <ls_sum>-currency ) ) ) INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD reversals.
    TRY.
        DATA(lt_sums) = mo_ctx->dao( )->reversed_payments( iv_reversed_from = iv_from iv_max = mo_ctx->max_rows( ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        INSERT mo_ctx->read_failed( iv_stage  = zif_ca_ops_cash_types=>gc_stage-reversal
                                    iv_source = zif_ca_ops_cash_types=>gc_source-reversals
                                    iv_param  = zif_ca_ops_cash_types=>gc_param-clr_days
                                    ix_error  = lx_error ) INTO TABLE cs_result-findings.
        RETURN.
    ENDTRY.
    mo_ctx->cap( EXPORTING iv_stage    = zif_ca_ops_cash_types=>gc_stage-reversal
                           iv_source   = zif_ca_ops_cash_types=>gc_source-reversals
                           iv_rows     = lines( lt_sums )
                 CHANGING  ct_findings = cs_result-findings ).
    cs_result-item_count = cs_result-item_count + lines( lt_sums ).
    LOOP AT lt_sums ASSIGNING FIELD-SYMBOL(<ls_sum>).
      " OBJECT_SUB = run date and run ID of the payment (LAUFD + LAUFI)
      DATA(lv_run) = |{ <ls_sum>-object_sub(8) }/{ condense( CONV string( <ls_sum>-object_sub+8 ) ) }|.
      INSERT mo_ctx->finding( VALUE #(
        check_code   = zif_ca_ops_cash_types=>gc_code-pay_reversed
        severity     = zif_ca_ops_types=>gc_severity-error
        stage        = zif_ca_ops_cash_types=>gc_stage-reversal
        object_type  = zif_ca_ops_cash_types=>gc_object_type-document
        object_key   = zcl_ca_ops_cash_exc=>object_key( iv_id       = <ls_sum>-object_id
                                                        iv_sub      = lv_run
                                                        iv_company  = <ls_sum>-company_code
                                                        iv_currency = <ls_sum>-currency )
        source       = zif_ca_ops_cash_types=>gc_source-reversals
        company_code = <ls_sum>-company_code
        currency     = <ls_sum>-currency
        item_count   = <ls_sum>-item_count
        amount       = <ls_sum>-amount
        oldest       = <ls_sum>-oldest
        rule_param   = zif_ca_ops_cash_types=>gc_param-clr_days
        evidence     = VALUE #( ( name = zif_ca_ops_cash_types=>gc_key-document value = <ls_sum>-object_id )
                                ( name = zif_ca_ops_cash_types=>gc_key-run value = lv_run ) )
        msgno        = zif_ca_ops_cash_types=>gc_msg-pay_reversed
        msgv1        = condense( CONV string( <ls_sum>-object_id ) )
        msgv2        = lv_run
        msgv3        = zcl_ca_ops_cash_exc=>amount_text( iv_amount   = <ls_sum>-amount
                                                         iv_currency = <ls_sum>-currency ) ) ) INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
