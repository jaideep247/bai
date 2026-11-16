*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_ma_interval.clas.abap
*& Purpose:
*& FI-CA cash check "mass activity intervals and their output" (module
*& CASH_OPS, catalogue process FICA_PAYRUN, check FICA_MA_INTERVALS;
*& docs/EXPECTED_RUNS_AND_MASS_ACTIVITIES.md section 3). For every active
*& mass activity of the area (ZCA_OPS_MAACT) the runs of the last
*& MA_LOOKBACK_DAYS from the run source (MA_SOURCE; delivered: parent job
*& and its parallel jobs from SAP's job tables): a parent job that ended
*& while one or more intervals failed or did not finish (stage JOB_OK when
*& the parent ended successfully - the scheduler sees green), an interval
*& running past its limit, and a run that ended with less document output
*& than expected - payment documents of the payment run (DPAYH through the
*& cash checks' data access and the payment run check's own sum, payment-
*& order methods left out; the proposal is the expectation only with
*& CASH_PAYRUN_GAP_ACTIVE, as in the payment run check) or dunning notices
*& (FKKMAKO) below the row's minimum. Findings per currency with count
*& and amount, built by the cash context (owner, cutoff, contract,
*& evidence: run key, activity type, parent job, interval numbers and
*& their jobs). A read that fails or a row that is not usable is "not
*& evaluated" (the check partial). Read-only.
*& Modification log:
*& 2026-11-16 | Initial version (build P: FI-CA mass-activity intervals and their output).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash check - mass activity intervals and output</p>
"! The run is matched to its output on the run date (LAUFD = the parent job's start date) and, where the source
"! knows it, the run ID; without a run ID every run of the date counts (evidence quality P). VERIFY V300 - V303.
CLASS zcl_ca_ops_chk_ma_interval DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

    "! The document output of the payment runs of a run date (run ID blank = every run of the date) against the
    "! expectation: the payments of the run, or the proposal when it is larger and iv_with_proposal = X; payments
    "! of a payment-order method count as documented. Pure (rows of the cash data access)
    CLASS-METHODS payment_output
      IMPORTING
        it_rows          TYPE zif_ca_ops_cash_types=>tt_run_sum
        iv_run_date      TYPE d
        iv_run_id        TYPE zif_ca_ops_ma_types=>ty_run_id
        it_order_methods TYPE zif_ca_ops_types=>tt_param_range
        iv_with_proposal TYPE abap_bool
      RETURNING
        VALUE(rt_output) TYPE zif_ca_ops_ma_types=>tt_output.

  PRIVATE SECTION.
    DATA mo_ctx TYPE REF TO zcl_ca_ops_cash_ctx.
    DATA mv_payments_read TYPE abap_bool.
    DATA mt_payments TYPE zif_ca_ops_cash_types=>tt_run_sum.
    DATA mv_notices_read TYPE abap_bool.
    DATA mt_notices TYPE zif_ca_ops_ma_types=>tt_notice_sum.
    "! Outputs already judged (activity / run date / run ID): several parent jobs of one date are judged once
    DATA mt_judged TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    "! The runs of one activity and their findings
    METHODS activity
      IMPORTING
        is_activity TYPE zif_ca_ops_ma_types=>ty_activity
        io_source   TYPE REF TO zif_ca_ops_ma_src
      CHANGING
        cs_result   TYPE zif_ca_ops_chk_types=>ty_result.

    "! The findings of one run; X = the run raised one
    METHODS run
      IMPORTING
        is_activity       TYPE zif_ca_ops_ma_types=>ty_activity
        is_run            TYPE zif_ca_ops_ma_types=>ty_run
      CHANGING
        cs_result         TYPE zif_ca_ops_chk_types=>ty_result
      RETURNING
        VALUE(rv_finding) TYPE abap_bool.

    "! The output of an ended run against its expectation (empty when the rule has none or it cannot be read)
    METHODS output
      IMPORTING
        is_activity      TYPE zif_ca_ops_ma_types=>ty_activity
        is_run           TYPE zif_ca_ops_ma_types=>ty_run
      CHANGING
        cs_result        TYPE zif_ca_ops_chk_types=>ty_result
      RETURNING
        VALUE(rt_output) TYPE zif_ca_ops_ma_types=>tt_output.

    "! The dunning notices of a run date against the activity's minimum (count only)
    METHODS dunning_output
      IMPORTING
        is_activity      TYPE zif_ca_ops_ma_types=>ty_activity
        is_run           TYPE zif_ca_ops_ma_types=>ty_run
      RETURNING
        VALUE(rt_output) TYPE zif_ca_ops_ma_types=>tt_output.

    "! The exception of a run, its keys and labelled lines filled
    METHODS exception
      IMPORTING
        is_activity   TYPE zif_ca_ops_ma_types=>ty_activity
        is_run        TYPE zif_ca_ops_ma_types=>ty_run
        it_intervals  TYPE zif_ca_ops_ma_types=>tt_interval
        "! Run ID of the output (the payment run's LAUFI) when the run source does not know it
        iv_run_id     TYPE zif_ca_ops_ma_types=>ty_run_id OPTIONAL
        iv_company    TYPE bukrs OPTIONAL
        iv_currency   TYPE zif_ca_ops_types=>ty_currency OPTIONAL
      RETURNING
        VALUE(rs_exc) TYPE zif_ca_ops_cash_types=>ty_exception.

    "! X = the parent job ended (finished or cancelled)
    CLASS-METHODS parent_ended
      IMPORTING
        is_run          TYPE zif_ca_ops_ma_types=>ty_run
      RETURNING
        VALUE(rv_ended) TYPE abap_bool.

    CLASS-METHODS run_text
      IMPORTING
        is_run         TYPE zif_ca_ops_ma_types=>ty_run
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_ca_ops_chk_ma_interval IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    DATA lo_source TYPE REF TO zif_ca_ops_ma_src.

    mo_ctx = NEW #( is_check = is_check is_context = is_context ).
    CLEAR: mv_payments_read, mt_payments, mv_notices_read, mt_notices, mt_judged.
    TRY.
        DATA(lt_activities) = zcl_ca_ops_cash_factory=>get_ma_dao( )->activities( is_check-area ).
        DATA(lv_class) = CONV zif_ca_ops_types=>ty_class_name( to_upper( mo_ctx->param_text(
                           iv_name    = zif_ca_ops_ma_types=>gc_param-source
                           iv_default = zif_ca_ops_ma_types=>gc_param_default-source ) ) ).
        IF lt_activities IS NOT INITIAL.
          lo_source = CAST #( zcl_ca_ops_factory=>get_plugin( iv_class_name = lv_class
                                                              iv_interface  = zif_ca_ops_ma_types=>gc_source_intf ) ).
        ENDIF.
      CATCH zcx_ca_ops_error INTO DATA(lx_setup).
        " without the activities or the run source nothing can be told: one "not evaluated", never green
        INSERT mo_ctx->read_failed( iv_stage  = zif_ca_ops_ma_types=>gc_stage-interval
                                    iv_source = zif_ca_ops_ma_types=>gc_source-activities
                                    iv_param  = zif_ca_ops_ma_types=>gc_param-source
                                    ix_error  = lx_setup ) INTO TABLE rs_result-findings.
        rs_result-partial = abap_true.
        rs_result-evidence = mo_ctx->evidence( ).
        rs_result-eval = mo_ctx->eval( ).
        RETURN.
    ENDTRY.
    LOOP AT lt_activities ASSIGNING FIELD-SYMBOL(<ls_activity>).
      activity( EXPORTING is_activity = <ls_activity>
                          io_source   = lo_source
                CHANGING  cs_result   = rs_result ).
    ENDLOOP.
    DATA(lv_ok_runs) = rs_result-eval-observed.
    rs_result-partial  = xsdbool( rs_result-partial = abap_true OR mo_ctx->partial( ) = abap_true ).
    rs_result-evidence = mo_ctx->evidence( ).
    DATA(lv_expected) = rs_result-eval-expected.
    " the evaluation of the exceptions (cash context) and of the runs without one (OK)
    rs_result-eval = mo_ctx->eval( ).
    rs_result-eval-expected = lv_expected.
    rs_result-eval-observed = lv_ok_runs.
    DO lv_ok_runs TIMES.
      zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = zif_ca_ops_eval_types=>gc_state-ok
                                   CHANGING  cs_eval = rs_result-eval ).
    ENDDO.
  ENDMETHOD.


  METHOD activity.
    IF is_activity-output_kind IS NOT INITIAL
       AND is_activity-output_kind <> zif_ca_ops_ma_types=>gc_output-pay_doc
       AND is_activity-output_kind <> zif_ca_ops_ma_types=>gc_output-dunning
       AND is_activity-output_kind <> zif_ca_ops_ma_types=>gc_output-none.
      INSERT mo_ctx->not_evaluated( iv_stage  = zif_ca_ops_ma_types=>gc_stage-output
                                    iv_source = zif_ca_ops_ma_types=>gc_source-activities
                                    iv_reason = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_ma_types=>gc_msg-config
                                                                       iv_v1    = is_activity-act_id
                                                                       iv_v2    = is_activity-output_kind ) )
             INTO TABLE cs_result-findings.
      RETURN.
    ENDIF.
    DATA(lv_from) = CONV d( mo_ctx->today( ) - mo_ctx->param_int(
                              iv_name    = zif_ca_ops_ma_types=>gc_param-lookback_days
                              iv_default = zif_ca_ops_ma_types=>gc_param_default-lookback_days ) ).
    DATA(lv_max) = nmax( val1 = 1
                         val2 = mo_ctx->param_int( iv_name    = zif_ca_ops_ma_types=>gc_param-max_runs
                                                   iv_default = zif_ca_ops_ma_types=>gc_param_default-max_runs ) ).
    TRY.
        DATA(ls_runs) = io_source->runs( is_activity = is_activity iv_from = lv_from iv_max = lv_max ).
      CATCH zcx_ca_ops_error INTO DATA(lx_runs).
        INSERT mo_ctx->read_failed( iv_stage  = zif_ca_ops_ma_types=>gc_stage-interval
                                    iv_source = zif_ca_ops_ma_types=>gc_source-runs
                                    iv_param  = zif_ca_ops_ma_types=>gc_param-source
                                    ix_error  = lx_runs ) INTO TABLE cs_result-findings.
        RETURN.
    ENDTRY.
    IF ls_runs-partial = abap_true.
      mo_ctx->set_partial( ).
    ENDIF.
    LOOP AT ls_runs-runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      cs_result-item_count += 1.
      IF run( EXPORTING is_activity = is_activity
                        is_run      = <ls_run>
              CHANGING  cs_result   = cs_result ) = abap_false AND parent_ended( <ls_run> ) = abap_true.
        cs_result-eval-observed += 1.
      ENDIF.
      IF parent_ended( <ls_run> ) = abap_true.
        cs_result-eval-expected += 1.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD run.
    DATA lt_bad TYPE zif_ca_ops_ma_types=>tt_interval.
    DATA lt_long TYPE zif_ca_ops_ma_types=>tt_interval.

    DATA(lv_ended) = parent_ended( is_run ).
    DATA(lv_parent_ok) = xsdbool( is_run-parent-status = zif_ca_ops_job_types=>gc_status-finished ).
    DATA(lv_limit) = COND i( WHEN is_activity-run_limit_min > 0 THEN is_activity-run_limit_min
                             ELSE mo_ctx->param_int( iv_name    = zif_ca_ops_ma_types=>gc_param-run_limit_min
                                                     iv_default = zif_ca_ops_ma_types=>gc_param_default-run_limit_min ) ).
    LOOP AT is_run-intervals ASSIGNING FIELD-SYMBOL(<ls_interval>).
      CASE <ls_interval>-state.
        WHEN zif_ca_ops_ma_types=>gc_state-failed.
          INSERT <ls_interval> INTO TABLE lt_bad.
        WHEN zif_ca_ops_ma_types=>gc_state-running OR zif_ca_ops_ma_types=>gc_state-waiting.
          " an interval that has not finished when its parent ended did not finish
          IF lv_ended = abap_true.
            INSERT <ls_interval> INTO TABLE lt_bad.
          ELSEIF <ls_interval>-state = zif_ca_ops_ma_types=>gc_state-running AND <ls_interval>-minutes > lv_limit.
            INSERT <ls_interval> INTO TABLE lt_long.
          ENDIF.
      ENDCASE.
    ENDLOOP.
    DATA(lv_run) = run_text( is_run ).
    " 1. the run ended with less output than expected: one finding per company code and currency
    IF lv_ended = abap_true.
      LOOP AT output( EXPORTING is_activity = is_activity
                                is_run      = is_run
                      CHANGING  cs_result   = cs_result ) ASSIGNING FIELD-SYMBOL(<ls_output>).
        IF <ls_output>-observed_count >= <ls_output>-expected_count.
          CONTINUE.
        ENDIF.
        DATA(ls_exc) = exception( is_activity  = is_activity
                                  is_run       = is_run
                                  it_intervals = lt_bad
                                  iv_run_id    = <ls_output>-run_id
                                  iv_company   = <ls_output>-company_code
                                  iv_currency  = <ls_output>-currency ).
        ls_exc-check_code = zif_ca_ops_ma_types=>gc_code-output_short.
        ls_exc-severity   = zif_ca_ops_types=>gc_severity-error.
        ls_exc-stage      = COND #( WHEN lv_parent_ok = abap_true THEN zif_ca_ops_cash_types=>gc_stage-job_ok
                                    ELSE zif_ca_ops_ma_types=>gc_stage-output ).
        ls_exc-item_count = <ls_output>-expected_count - <ls_output>-observed_count.
        IF <ls_output>-with_amount = abap_true.
          ls_exc-amount = <ls_output>-expected_amount - <ls_output>-observed_amount.
        ELSE.
          CLEAR ls_exc-currency.
        ENDIF.
        ls_exc-source = COND #( WHEN is_activity-output_kind = zif_ca_ops_ma_types=>gc_output-pay_doc
                                THEN zif_ca_ops_cash_types=>gc_source-payments
                                ELSE zif_ca_ops_ma_types=>gc_source-dunning ).
        DATA(lv_out_run) = |{ is_run-run_date DATE = ISO }/{ COND #( WHEN is_run-run_id IS NOT INITIAL
                                                                       THEN is_run-run_id
                                                                       ELSE <ls_output>-run_id ) }|.
        IF lv_parent_ok = abap_true.
          " failure injection of scorecard 1: the job reports success, the business output is incomplete
          ls_exc-msgno = zif_ca_ops_ma_types=>gc_msg-output_job_ok.
          ls_exc-msgv1 = is_run-parent-jobname.
          ls_exc-msgv2 = lv_out_run.
        ELSE.
          ls_exc-msgno = zif_ca_ops_ma_types=>gc_msg-output_short.
          ls_exc-msgv1 = lv_out_run.
          ls_exc-msgv2 = is_activity-act_id.
        ENDIF.
        ls_exc-msgv3 = |{ <ls_output>-observed_count }|.
        ls_exc-msgv4 = |{ <ls_output>-expected_count }|.
        ls_exc-note  = |{ ls_exc-note }{ cl_abap_char_utilities=>newline }{
                         zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_ma_types=>gc_msg-det_output
                                                iv_v1    = is_activity-output_kind
                                                iv_v2    = |{ <ls_output>-expected_count }|
                                                iv_v3    = |{ <ls_output>-observed_count }|
                                                iv_v4    = lines( lt_bad ) ) }|.
        INSERT mo_ctx->finding( ls_exc ) INTO TABLE cs_result-findings.
        rv_finding = abap_true.
      ENDLOOP.
    ENDIF.
    " 2. intervals failed or did not finish - unless the short output already names them
    IF rv_finding = abap_false AND lt_bad IS NOT INITIAL.
      ls_exc = exception( is_activity = is_activity is_run = is_run it_intervals = lt_bad ).
      ls_exc-check_code = zif_ca_ops_ma_types=>gc_code-interval_failed.
      ls_exc-severity   = zif_ca_ops_types=>gc_severity-error.
      ls_exc-item_count = lines( lt_bad ).
      ls_exc-source     = zif_ca_ops_ma_types=>gc_source-runs.
      IF lv_ended = abap_true AND lv_parent_ok = abap_true.
        ls_exc-stage = zif_ca_ops_cash_types=>gc_stage-job_ok.
        ls_exc-msgno = zif_ca_ops_ma_types=>gc_msg-interval_job_ok.
        ls_exc-msgv1 = is_run-parent-jobname.
        ls_exc-msgv2 = lv_run.
        ls_exc-msgv3 = is_activity-act_id.
        ls_exc-msgv4 = |{ lines( lt_bad ) }|.
      ELSE.
        ls_exc-stage = zif_ca_ops_ma_types=>gc_stage-interval.
        ls_exc-msgno = zif_ca_ops_ma_types=>gc_msg-interval_failed.
        ls_exc-msgv1 = lv_run.
        ls_exc-msgv2 = is_activity-act_id.
        ls_exc-msgv3 = |{ lines( lt_bad ) }|.
        ls_exc-msgv4 = |{ lines( is_run-intervals ) }|.
      ENDIF.
      INSERT mo_ctx->finding( ls_exc ) INTO TABLE cs_result-findings.
      rv_finding = abap_true.
    ENDIF.
    " 3. intervals still running past their limit (the run has not ended)
    IF lt_long IS NOT INITIAL.
      ls_exc = exception( is_activity = is_activity is_run = is_run it_intervals = lt_long ).
      ls_exc-check_code = zif_ca_ops_ma_types=>gc_code-interval_long.
      ls_exc-severity   = zif_ca_ops_types=>gc_severity-warning.
      ls_exc-stage      = zif_ca_ops_ma_types=>gc_stage-interval.
      ls_exc-item_count = lines( lt_long ).
      ls_exc-source     = zif_ca_ops_ma_types=>gc_source-runs.
      ls_exc-rule_param = zif_ca_ops_ma_types=>gc_param-run_limit_min.
      ls_exc-msgno = zif_ca_ops_ma_types=>gc_msg-interval_long.
      ls_exc-msgv1 = lv_run.
      ls_exc-msgv2 = is_activity-act_id.
      ls_exc-msgv3 = |{ lt_long[ 1 ]-number }|.
      ls_exc-msgv4 = |{ lt_long[ 1 ]-minutes }|.
      INSERT mo_ctx->finding( ls_exc ) INTO TABLE cs_result-findings.
      rv_finding = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD output.
    DATA(lv_key) = |{ is_activity-act_id }/{ is_run-run_date }/{ is_run-run_id }|.
    INSERT lv_key INTO TABLE mt_judged.
    IF sy-subrc <> 0.
      " another parent job of the same run date was judged already: its output is not counted twice
      RETURN.
    ENDIF.
    CASE is_activity-output_kind.
      WHEN zif_ca_ops_ma_types=>gc_output-pay_doc.
        IF mv_payments_read = abap_false.
          mv_payments_read = abap_true.
          TRY.
              mt_payments = mo_ctx->dao( )->payment_runs(
                              iv_from = CONV d( mo_ctx->today( ) - mo_ctx->param_int(
                                                  iv_name    = zif_ca_ops_ma_types=>gc_param-lookback_days
                                                  iv_default = zif_ca_ops_ma_types=>gc_param_default-lookback_days ) )
                              iv_to   = mo_ctx->today( )
                              iv_max  = mo_ctx->max_rows( ) ).
              mo_ctx->cap( EXPORTING iv_stage    = zif_ca_ops_ma_types=>gc_stage-output
                                     iv_source   = zif_ca_ops_cash_types=>gc_source-payments
                                     iv_rows     = lines( mt_payments )
                           CHANGING  ct_findings = cs_result-findings ).
            CATCH zcx_ca_ops_error INTO DATA(lx_payments).
              INSERT mo_ctx->read_failed( iv_stage  = zif_ca_ops_ma_types=>gc_stage-output
                                          iv_source = zif_ca_ops_cash_types=>gc_source-payments
                                          ix_error  = lx_payments ) INTO TABLE cs_result-findings.
          ENDTRY.
        ENDIF.
        " the proposal is the expectation only where the payment run check compares it too (VERIFY V221)
        DATA(lv_gap_active) = mo_ctx->param_text( zif_ca_ops_cash_types=>gc_param-payrun_gap_active ).
        DATA(lt_orders) = mo_ctx->param_range( zif_ca_ops_cash_types=>gc_param-payrun_order_meth ).
        rt_output = payment_output( it_rows          = mt_payments
                                    iv_run_date      = is_run-run_date
                                    iv_run_id        = is_run-run_id
                                    it_order_methods = lt_orders
                                    iv_with_proposal = xsdbool( lv_gap_active = abap_true ) ).
      WHEN zif_ca_ops_ma_types=>gc_output-dunning.
        IF mv_notices_read = abap_false.
          mv_notices_read = abap_true.
          TRY.
              mt_notices = zcl_ca_ops_cash_factory=>get_ma_dao( )->dunning_notices(
                             iv_from = CONV d( mo_ctx->today( ) - mo_ctx->param_int(
                                                 iv_name    = zif_ca_ops_ma_types=>gc_param-lookback_days
                                                 iv_default = zif_ca_ops_ma_types=>gc_param_default-lookback_days ) )
                             iv_to   = mo_ctx->today( )
                             iv_max  = mo_ctx->max_rows( ) ).
              mo_ctx->cap( EXPORTING iv_stage    = zif_ca_ops_ma_types=>gc_stage-output
                                     iv_source   = zif_ca_ops_ma_types=>gc_source-dunning
                                     iv_rows     = lines( mt_notices )
                           CHANGING  ct_findings = cs_result-findings ).
            CATCH zcx_ca_ops_error INTO DATA(lx_notices).
              INSERT mo_ctx->read_failed( iv_stage  = zif_ca_ops_ma_types=>gc_stage-output
                                          iv_source = zif_ca_ops_ma_types=>gc_source-dunning
                                          ix_error  = lx_notices ) INTO TABLE cs_result-findings.
          ENDTRY.
        ENDIF.
        rt_output = dunning_output( is_activity = is_activity is_run = is_run ).
      WHEN OTHERS.
        RETURN.
    ENDCASE.
    " a payment run whose parent ended without any payment of the date: short of the row's minimum (count only)
    IF is_activity-min_output > 0 AND is_activity-output_kind = zif_ca_ops_ma_types=>gc_output-pay_doc
       AND rt_output IS INITIAL.
      INSERT VALUE #( run_date       = is_run-run_date
                      run_id         = is_run-run_id
                      expected_count = is_activity-min_output ) INTO TABLE rt_output.
    ENDIF.
  ENDMETHOD.


  METHOD dunning_output.
    DATA lv_count TYPE i.

    IF is_activity-min_output <= 0.
      RETURN.
    ENDIF.
    LOOP AT mt_notices ASSIGNING FIELD-SYMBOL(<ls_notice>) WHERE run_date = is_run-run_date.
      " without a run ID every dunning run of the date counts (evidence quality P)
      IF is_run-run_id IS NOT INITIAL AND <ls_notice>-run_id <> is_run-run_id.
        CONTINUE.
      ENDIF.
      lv_count += <ls_notice>-item_count.
    ENDLOOP.
    INSERT VALUE #( run_date       = is_run-run_date
                    run_id         = is_run-run_id
                    expected_count = is_activity-min_output
                    observed_count = lv_count ) INTO TABLE rt_output.
  ENDMETHOD.


  METHOD payment_output.
    DATA ls_out TYPE zif_ca_ops_ma_types=>ty_output.

    DATA(lt_runs) = zcl_ca_ops_chk_cash_payrun=>sum_by_run( it_rows          = it_rows
                                                           it_order_methods = it_order_methods
                                                           iv_skip_orders   = abap_true ).
    LOOP AT lt_runs ASSIGNING FIELD-SYMBOL(<ls_pay>)
         WHERE run_date = iv_run_date AND proposal = abap_false.
      IF iv_run_id IS NOT INITIAL AND <ls_pay>-run_id <> iv_run_id.
        CONTINUE.
      ENDIF.
      ls_out = VALUE #( run_date        = <ls_pay>-run_date
                        run_id          = <ls_pay>-run_id
                        company_code    = <ls_pay>-company_code
                        currency        = <ls_pay>-currency
                        expected_count  = <ls_pay>-item_count
                        expected_amount = <ls_pay>-amount
                        observed_count  = <ls_pay>-item_count - <ls_pay>-nodoc_count
                        observed_amount = <ls_pay>-amount - <ls_pay>-nodoc_amount
                        with_amount     = abap_true ).
      IF iv_with_proposal = abap_true.
        " the proposal of the same run date and ID is the expectation when it holds more (VERIFY V221)
        READ TABLE lt_runs ASSIGNING FIELD-SYMBOL(<ls_prop>) WITH KEY run_date     = <ls_pay>-run_date
                                                                      run_id       = <ls_pay>-run_id
                                                                      proposal     = abap_true
                                                                      company_code = <ls_pay>-company_code
                                                                      currency     = <ls_pay>-currency.
        IF sy-subrc = 0 AND <ls_prop>-item_count > ls_out-expected_count.
          ls_out-expected_count  = <ls_prop>-item_count.
          ls_out-expected_amount = <ls_prop>-amount.
        ENDIF.
      ENDIF.
      INSERT ls_out INTO TABLE rt_output.
    ENDLOOP.
  ENDMETHOD.


  METHOD exception.
    DATA(lv_run_id) = COND zif_ca_ops_ma_types=>ty_run_id( WHEN is_run-run_id IS NOT INITIAL THEN is_run-run_id
                                                           ELSE iv_run_id ).
    rs_exc = VALUE #(
      object_type  = zif_ca_ops_ma_types=>gc_object_type
      object_key   = zcl_ca_ops_cash_exc=>object_key( iv_id       = |{ is_run-act_id }/{ is_run-run_date }|
                                                      iv_sub      = lv_run_id
                                                      iv_company  = iv_company
                                                      iv_currency = iv_currency )
      company_code = iv_company
      currency     = iv_currency
      oldest       = is_run-run_date
      rule_param   = zif_ca_ops_ma_types=>gc_param-source
      evidence     = VALUE #( ( name  = zif_ca_ops_ma_types=>gc_key-run
                                value = |{ is_run-aktyp }/{ is_run-run_date }/{ lv_run_id }| )
                              ( name  = zif_ca_ops_cash_types=>gc_key-job
                                value = |{ is_run-parent-jobname }/{ is_run-parent-jobcount }| ) ) ).
    IF is_activity-output_kind = zif_ca_ops_ma_types=>gc_output-pay_doc.
      " the payment run's own key: linked to its payments (FICA_PAYMENT_RUN)
      INSERT VALUE #( name  = zif_ca_ops_cash_types=>gc_key-run
                      value = |{ is_run-run_date }/{ lv_run_id }| ) INTO TABLE rs_exc-evidence.
    ENDIF.
    LOOP AT it_intervals ASSIGNING FIELD-SYMBOL(<ls_interval>).
      INSERT VALUE #( name = zif_ca_ops_ma_types=>gc_key-interval value = |{ <ls_interval>-number }| )
             INTO TABLE rs_exc-evidence.
      INSERT VALUE #( name  = zif_ca_ops_cash_types=>gc_key-job
                      value = |{ <ls_interval>-job-jobname }/{ <ls_interval>-job-jobcount }| ) INTO TABLE rs_exc-evidence.
    ENDLOOP.
    DATA(lt_lines) = VALUE string_table( ( zcl_ca_ops_util=>text(
                                             iv_msgno = zif_ca_ops_ma_types=>gc_msg-det_run
                                             iv_v1    = |{ is_run-run_date DATE = ISO }/{ lv_run_id }|
                                             iv_v2    = is_run-aktyp
                                             iv_v3    = |{ is_run-parent-jobname }/{ is_run-parent-jobcount }|
                                             iv_v4    = is_run-parent-status ) ) ).
    LOOP AT it_intervals ASSIGNING <ls_interval>.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_ma_types=>gc_msg-det_interval
                                    iv_v1    = <ls_interval>-number
                                    iv_v2    = |{ <ls_interval>-job-jobname }/{ <ls_interval>-job-jobcount }|
                                    iv_v3    = <ls_interval>-state
                                    iv_v4    = <ls_interval>-minutes ) INTO TABLE lt_lines.
    ENDLOOP.
    rs_exc-note = concat_lines_of( table = lt_lines sep = cl_abap_char_utilities=>newline ).
  ENDMETHOD.


  METHOD parent_ended.
    rv_ended = xsdbool( is_run-parent-status = zif_ca_ops_job_types=>gc_status-finished
                        OR is_run-parent-status = zif_ca_ops_job_types=>gc_status-aborted ).
  ENDMETHOD.


  METHOD run_text.
    rv_text = |{ is_run-run_date DATE = ISO }/{ is_run-run_id }|.
  ENDMETHOD.

ENDCLASS.
