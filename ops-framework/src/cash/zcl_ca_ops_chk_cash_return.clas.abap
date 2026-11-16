*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_cash_return.clas.abap
*& Purpose:
*& FI-CA cash check "returns lot" (catalogue process FICA_RETURNS). What
*& should have happened: a returns lot is posted and closed within
*& CASH_RET_DAYS, no return waits in clarification longer than
*& CASH_RET_CLARIF_DAYS, and every return got its returns document (the
*& reversal of the returned payment) within CASH_RET_DAYS. Detected per
*& returns lot, company code and currency on the database (DFKKRK /
*& DFKKRP): lots whose status is none of CASH_RET_DONE_STATUS (a pending
*& value - "not evaluated" until maintained, VERIFY V224), returns in
*& clarification (DFKKRP-XKLAE set) and returns without returns document
*& (DFKKRP-RLBEL initial, V225). A failed read is "not evaluated" (the
*& check partial), never green. Read-only.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash check - returns lot and reversal pending</p>
CLASS zcl_ca_ops_chk_cash_return DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_rule,
        stage TYPE zif_ca_ops_cash_types=>ty_stage,
        code  TYPE zif_ca_ops_types=>ty_check_code,
        param TYPE zif_ca_ops_types=>ty_param_name,
        msgno TYPE zif_ca_ops_types=>ty_msgno,
      END OF ty_rule.

    DATA mo_ctx TYPE REF TO zcl_ca_ops_cash_ctx.

    "! The findings of the returns read by one rule
    METHODS report
      IMPORTING
        is_rule     TYPE ty_rule
        it_sums     TYPE zif_ca_ops_cash_types=>tt_sum
      CHANGING
        cs_result   TYPE zif_ca_ops_chk_types=>ty_result.

    METHODS failed
      IMPORTING
        is_rule     TYPE ty_rule
        ix_error    TYPE REF TO zcx_ca_ops_error
      CHANGING
        cs_result   TYPE zif_ca_ops_chk_types=>ty_result.

ENDCLASS.



CLASS zcl_ca_ops_chk_cash_return IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    mo_ctx = NEW #( is_check = is_check is_context = is_context ).
    DATA(lo_dao) = mo_ctx->dao( ).
    DATA(lv_max) = mo_ctx->max_rows( ).
    DATA(lv_days_to) = CONV d( mo_ctx->today( ) - mo_ctx->param_int(
                                 iv_name    = zif_ca_ops_cash_types=>gc_param-ret_days
                                 iv_default = zif_ca_ops_cash_types=>gc_param_default-ret_days ) ).

    " 1. returns lot not closed (status value pending until maintained)
    DATA(ls_open) = VALUE ty_rule( stage = zif_ca_ops_cash_types=>gc_stage-posting
                                   code  = zif_ca_ops_cash_types=>gc_code-retlot_open
                                   param = zif_ca_ops_cash_types=>gc_param-ret_done_status
                                   msgno = zif_ca_ops_cash_types=>gc_msg-retlot_open ).
    DATA(lt_done) = mo_ctx->param_range( zif_ca_ops_cash_types=>gc_param-ret_done_status ).
    IF lt_done IS INITIAL.
      INSERT mo_ctx->pending( iv_stage  = ls_open-stage
                              iv_source = zif_ca_ops_cash_types=>gc_source-returns
                              iv_param  = ls_open-param ) INTO TABLE rs_result-findings.
    ELSE.
      TRY.
          report( EXPORTING is_rule   = ls_open
                            it_sums   = lo_dao->open_returns_lots( it_done       = lt_done
                                                                   iv_created_to = lv_days_to
                                                                   iv_max        = lv_max )
                  CHANGING  cs_result = rs_result ).
        CATCH zcx_ca_ops_error INTO DATA(lx_open).
          failed( EXPORTING is_rule = ls_open ix_error = lx_open CHANGING cs_result = rs_result ).
      ENDTRY.
    ENDIF.

    " 2. returns in clarification
    DATA(ls_clarif) = VALUE ty_rule( stage = zif_ca_ops_cash_types=>gc_stage-clarify
                                     code  = zif_ca_ops_cash_types=>gc_code-return_clarif
                                     param = zif_ca_ops_cash_types=>gc_param-ret_clarif_days
                                     msgno = zif_ca_ops_cash_types=>gc_msg-return_clarif ).
    TRY.
        report( EXPORTING is_rule   = ls_clarif
                          it_sums   = lo_dao->return_clarifications(
                                        iv_posted_to = CONV #( mo_ctx->today( ) - mo_ctx->param_int(
                                                                 iv_name    = ls_clarif-param
                                                                 iv_default = zif_ca_ops_cash_types=>gc_param_default-ret_clarif_days ) )
                                        iv_max       = lv_max )
                CHANGING  cs_result = rs_result ).
      CATCH zcx_ca_ops_error INTO DATA(lx_clarif).
        failed( EXPORTING is_rule = ls_clarif ix_error = lx_clarif CHANGING cs_result = rs_result ).
    ENDTRY.

    " 3. returns without returns document: the reversal of the returned payment is pending
    DATA(ls_reversal) = VALUE ty_rule( stage = zif_ca_ops_cash_types=>gc_stage-reversal
                                       code  = zif_ca_ops_cash_types=>gc_code-return_no_doc
                                       param = zif_ca_ops_cash_types=>gc_param-ret_days
                                       msgno = zif_ca_ops_cash_types=>gc_msg-return_no_doc ).
    TRY.
        report( EXPORTING is_rule   = ls_reversal
                          it_sums   = lo_dao->returns_without_document( iv_posted_to = lv_days_to iv_max = lv_max )
                CHANGING  cs_result = rs_result ).
      CATCH zcx_ca_ops_error INTO DATA(lx_reversal).
        failed( EXPORTING is_rule = ls_reversal ix_error = lx_reversal CHANGING cs_result = rs_result ).
    ENDTRY.
    rs_result-partial = mo_ctx->partial( ).
  ENDMETHOD.


  METHOD report.
    mo_ctx->cap( EXPORTING iv_stage    = is_rule-stage
                           iv_source   = zif_ca_ops_cash_types=>gc_source-returns
                           iv_rows     = lines( it_sums )
                 CHANGING  ct_findings = cs_result-findings ).
    cs_result-item_count = cs_result-item_count + lines( it_sums ).
    LOOP AT it_sums ASSIGNING FIELD-SYMBOL(<ls_sum>).
      DATA(lv_lot) = condense( CONV string( <ls_sum>-object_id ) ).
      DATA(lv_amount) = zcl_ca_ops_cash_exc=>amount_text( iv_amount = <ls_sum>-amount iv_currency = <ls_sum>-currency ).
      DATA(lv_age) = zcl_ca_ops_cash_exc=>age_days( iv_oldest = <ls_sum>-oldest iv_today = mo_ctx->today( ) ).
      INSERT mo_ctx->finding( VALUE #(
        check_code   = is_rule-code
        severity     = zif_ca_ops_types=>gc_severity-error
        stage        = is_rule-stage
        object_type  = zif_ca_ops_cash_types=>gc_object_type-returns_lot
        object_key   = zcl_ca_ops_cash_exc=>object_key( iv_id       = <ls_sum>-object_id
                                                        iv_company  = <ls_sum>-company_code
                                                        iv_currency = <ls_sum>-currency )
        source       = zif_ca_ops_cash_types=>gc_source-returns
        company_code = <ls_sum>-company_code
        currency     = <ls_sum>-currency
        item_count   = <ls_sum>-item_count
        amount       = <ls_sum>-amount
        oldest       = <ls_sum>-oldest
        age_days     = lv_age
        rule_param   = is_rule-param
        evidence     = VALUE #( ( name = zif_ca_ops_cash_types=>gc_key-returns value = <ls_sum>-object_id ) )
        msgno        = is_rule-msgno
        msgv1        = lv_lot
        " 507: lot, age, count, amount; 508: lot, count, amount, oldest; 509: lot, count, amount
        msgv2        = COND #( WHEN is_rule-msgno = zif_ca_ops_cash_types=>gc_msg-retlot_open THEN |{ lv_age }|
                               ELSE |{ <ls_sum>-item_count }| )
        msgv3        = COND #( WHEN is_rule-msgno = zif_ca_ops_cash_types=>gc_msg-retlot_open
                               THEN |{ <ls_sum>-item_count }| ELSE lv_amount )
        msgv4        = COND #( WHEN is_rule-msgno = zif_ca_ops_cash_types=>gc_msg-retlot_open THEN lv_amount
                               WHEN is_rule-msgno = zif_ca_ops_cash_types=>gc_msg-return_clarif
                               THEN |{ <ls_sum>-oldest DATE = ISO }| ) ) ) INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD failed.
    INSERT mo_ctx->read_failed( iv_stage  = is_rule-stage
                                iv_source = zif_ca_ops_cash_types=>gc_source-returns
                                iv_param  = is_rule-param
                                ix_error  = ix_error ) INTO TABLE cs_result-findings.
  ENDMETHOD.

ENDCLASS.
