*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_cash_paylot.clas.abap
*& Purpose:
*& FI-CA cash check "incoming payment lot" (catalogue process
*& FICA_PAY_LOTS). What should have happened: a payment lot is posted and
*& closed within CASH_LOT_DAYS of its creation and no lot item waits in
*& clarification longer than CASH_LOT_CLARIF_DAYS. Detected per lot,
*& company code and currency on the database (DFKKZK / DFKKZP): lots whose
*& status is none of CASH_LOT_DONE_STATUS (a pending value - "not
*& evaluated" until maintained, VERIFY V222) and lot items in
*& clarification (DFKKZP-XKLAE set, V223). No open lot is an observed,
*& valid result (nothing is pending); a failed read is "not evaluated"
*& (the check partial), never green. Read-only.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*& 2026-11-16 | Exception contract (build K merge): returns the evidence rows of its findings.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash check - payment lot posting and clarification</p>
CLASS zcl_ca_ops_chk_cash_paylot DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

  PRIVATE SECTION.
    DATA mo_ctx TYPE REF TO zcl_ca_ops_cash_ctx.

    "! Lots not posted / closed after CASH_LOT_DAYS
    METHODS not_posted
      CHANGING
        cs_result TYPE zif_ca_ops_chk_types=>ty_result.

    "! Lot items in clarification after CASH_LOT_CLARIF_DAYS
    METHODS clarifications
      CHANGING
        cs_result TYPE zif_ca_ops_chk_types=>ty_result.

    "! The exception of a lot (per company code and currency)
    METHODS lot_exception
      IMPORTING
        is_sum        TYPE zif_ca_ops_cash_types=>ty_sum
      RETURNING
        VALUE(rs_exc) TYPE zif_ca_ops_cash_types=>ty_exception.

ENDCLASS.



CLASS zcl_ca_ops_chk_cash_paylot IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    mo_ctx = NEW #( is_check = is_check is_context = is_context ).
    not_posted( CHANGING cs_result = rs_result ).
    clarifications( CHANGING cs_result = rs_result ).
    rs_result-partial = mo_ctx->partial( ).
    " exception contract: the typed evidence rows of the findings (stored by the runner)
    rs_result-evidence = mo_ctx->evidence( ).
  ENDMETHOD.


  METHOD not_posted.
    DATA(lt_done) = mo_ctx->param_range( zif_ca_ops_cash_types=>gc_param-lot_done_status ).
    IF lt_done IS INITIAL.
      INSERT mo_ctx->pending( iv_stage  = zif_ca_ops_cash_types=>gc_stage-posting
                              iv_source = zif_ca_ops_cash_types=>gc_source-lots
                              iv_param  = zif_ca_ops_cash_types=>gc_param-lot_done_status ) INTO TABLE cs_result-findings.
      RETURN.
    ENDIF.
    DATA(lv_days) = mo_ctx->param_int( iv_name    = zif_ca_ops_cash_types=>gc_param-lot_days
                                 iv_default = zif_ca_ops_cash_types=>gc_param_default-lot_days ).
    TRY.
        DATA(lt_sums) = mo_ctx->dao( )->open_lots( it_done       = lt_done
                                                   iv_created_to = CONV #( mo_ctx->today( ) - lv_days )
                                                   iv_max        = mo_ctx->max_rows( ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        INSERT mo_ctx->read_failed( iv_stage  = zif_ca_ops_cash_types=>gc_stage-posting
                                    iv_source = zif_ca_ops_cash_types=>gc_source-lots
                                    iv_param  = zif_ca_ops_cash_types=>gc_param-lot_done_status
                                    ix_error  = lx_error ) INTO TABLE cs_result-findings.
        RETURN.
    ENDTRY.
    mo_ctx->cap( EXPORTING iv_stage    = zif_ca_ops_cash_types=>gc_stage-posting
                           iv_source   = zif_ca_ops_cash_types=>gc_source-lots
                           iv_rows     = lines( lt_sums )
                 CHANGING  ct_findings = cs_result-findings ).
    cs_result-item_count = cs_result-item_count + lines( lt_sums ).
    LOOP AT lt_sums ASSIGNING FIELD-SYMBOL(<ls_sum>).
      DATA(ls_exc) = lot_exception( <ls_sum> ).
      ls_exc = VALUE #( BASE ls_exc
                        check_code = zif_ca_ops_cash_types=>gc_code-lot_not_posted
                        stage      = zif_ca_ops_cash_types=>gc_stage-posting
                        rule_param = zif_ca_ops_cash_types=>gc_param-lot_done_status
                        msgno      = zif_ca_ops_cash_types=>gc_msg-lot_not_posted
                        msgv1      = condense( CONV string( <ls_sum>-object_id ) )
                        msgv2      = |{ zcl_ca_ops_cash_exc=>age_days( iv_oldest = <ls_sum>-oldest
                                                                       iv_today  = mo_ctx->today( ) ) }|
                        msgv3      = |{ <ls_sum>-item_count }|
                        msgv4      = zcl_ca_ops_cash_exc=>amount_text( iv_amount   = <ls_sum>-amount
                                                                       iv_currency = <ls_sum>-currency ) ).
      INSERT mo_ctx->finding( ls_exc ) INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD clarifications.
    DATA(lv_days) = mo_ctx->param_int( iv_name    = zif_ca_ops_cash_types=>gc_param-lot_clarif_days
                                 iv_default = zif_ca_ops_cash_types=>gc_param_default-lot_clarif_days ).
    TRY.
        DATA(lt_sums) = mo_ctx->dao( )->lot_clarifications( iv_posted_to = CONV #( mo_ctx->today( ) - lv_days )
                                                            iv_max       = mo_ctx->max_rows( ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        INSERT mo_ctx->read_failed( iv_stage  = zif_ca_ops_cash_types=>gc_stage-clarify
                                    iv_source = zif_ca_ops_cash_types=>gc_source-lots
                                    iv_param  = zif_ca_ops_cash_types=>gc_param-lot_clarif_days
                                    ix_error  = lx_error ) INTO TABLE cs_result-findings.
        RETURN.
    ENDTRY.
    mo_ctx->cap( EXPORTING iv_stage    = zif_ca_ops_cash_types=>gc_stage-clarify
                           iv_source   = zif_ca_ops_cash_types=>gc_source-lots
                           iv_rows     = lines( lt_sums )
                 CHANGING  ct_findings = cs_result-findings ).
    cs_result-item_count = cs_result-item_count + lines( lt_sums ).
    LOOP AT lt_sums ASSIGNING FIELD-SYMBOL(<ls_sum>).
      DATA(ls_exc) = lot_exception( <ls_sum> ).
      ls_exc = VALUE #( BASE ls_exc
                        check_code = zif_ca_ops_cash_types=>gc_code-lot_clarif
                        stage      = zif_ca_ops_cash_types=>gc_stage-clarify
                        rule_param = zif_ca_ops_cash_types=>gc_param-lot_clarif_days
                        msgno      = zif_ca_ops_cash_types=>gc_msg-lot_clarif
                        msgv1      = condense( CONV string( <ls_sum>-object_id ) )
                        msgv2      = |{ <ls_sum>-item_count }|
                        msgv3      = zcl_ca_ops_cash_exc=>amount_text( iv_amount   = <ls_sum>-amount
                                                                       iv_currency = <ls_sum>-currency )
                        msgv4      = |{ <ls_sum>-oldest DATE = ISO }| ).
      INSERT mo_ctx->finding( ls_exc ) INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD lot_exception.
    rs_exc = VALUE #(
      severity     = zif_ca_ops_types=>gc_severity-error
      object_type  = zif_ca_ops_cash_types=>gc_object_type-lot
      object_key   = zcl_ca_ops_cash_exc=>object_key( iv_id       = is_sum-object_id
                                                      iv_company  = is_sum-company_code
                                                      iv_currency = is_sum-currency )
      source       = zif_ca_ops_cash_types=>gc_source-lots
      company_code = is_sum-company_code
      currency     = is_sum-currency
      item_count   = is_sum-item_count
      amount       = is_sum-amount
      oldest       = is_sum-oldest
      evidence     = VALUE #( ( name = zif_ca_ops_cash_types=>gc_key-lot value = is_sum-object_id ) ) ).
  ENDMETHOD.

ENDCLASS.
