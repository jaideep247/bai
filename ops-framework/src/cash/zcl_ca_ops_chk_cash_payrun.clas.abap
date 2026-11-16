*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_cash_payrun.clas.abap
*& Purpose:
*& FI-CA cash check "payment run" (catalogue process FICA_PAYRUN). What
*& should have happened: on every working day of the business calendar a
*& payment run paid the company codes of CASH_PAYRUN_BUKRS (blank = any),
*& every payment got its payment document and a proposal was paid in full.
*& Detected from the payments of the runs (DPAYH, aggregated per run,
*& company code and currency on the database) and the run's job (TBTCO,
*& job name CASH_PAYRUN_JOBNAME): no payment and no finished job on an
*& expected day = run missing (a cancelled job = job failed); a finished
*& job without payments = valid zero volume (information); a non-working
*& day = not expected (information); payments without payment document (a
*& payment-order method of CASH_PAYRUN_ORDER_METHODS excluded) and
*& the gap to the proposal (CASH_PAYRUN_GAP_ACTIVE) are exceptions per run,
*& company code and currency - with stage JOB_OK when the job of the run
*& date finished successfully (successful job, incomplete business output).
*& A source that cannot be read, or a calendar that is missing, is "not
*& evaluated" (the check partial), never green. Read-only.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*& 2026-11-16 | Exception contract (build K merge): returns the evidence rows of its findings.
*& 2026-11-16 | Evaluation state (build O): the run's evaluation (ZCL_CA_OPS_CASH_CTX=>EVAL) in TY_RESULT-EVAL.
*& 2026-11-16 | Build P: the sum per run is the public SUM_BY_RUN (pure), called by the mass activity check
*&            | ZCL_CA_OPS_CHK_MA_INTERVAL for the document output of a payment run (one rule, not a copy).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash check - payment run expected / completed</p>
"! VERIFY V221: DPAYH-XVORL set = proposal row; a payment run that follows a proposal carries the proposal's run date
"! and ID (the gap rule stays off until confirmed); DOC1R initial = no payment document. An expected run is matched on
"! its run date (LAUFD = the day of the scheduler job) and company code, never on a fixed LAUFI: the mass activity
"! scheduler derives LAUFI from the template's ID (its first 3 characters plus a counter when that key already ran).
CLASS zcl_ca_ops_chk_cash_payrun DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

    "! The run rows per run, proposal flag, company code and currency (payment methods summed); with
    "! iv_skip_orders the payments without document of a payment-order method (it_order_methods) are left out -
    "! such a method posts its document only after the bank confirmed the order. Pure; also called by the mass
    "! activity check for the document output of a payment run (one rule, not a copy)
    CLASS-METHODS sum_by_run
      IMPORTING
        it_rows          TYPE zif_ca_ops_cash_types=>tt_run_sum
        it_order_methods TYPE zif_ca_ops_types=>tt_param_range
        iv_skip_orders   TYPE abap_bool
      RETURNING
        VALUE(rt_runs)   TYPE zif_ca_ops_cash_types=>tt_run_sum.

  PRIVATE SECTION.
    DATA mo_ctx TYPE REF TO zcl_ca_ops_cash_ctx.
    DATA mt_runs TYPE zif_ca_ops_cash_types=>tt_run_sum.
    DATA mt_jobs TYPE zif_ca_ops_job_types=>tt_job.

    "! Expected runs of the calendar window: missing, job failed, zero volume, not expected
    METHODS expected_runs
      CHANGING
        cs_result TYPE zif_ca_ops_chk_types=>ty_result.

    "! The finding of an expected day without payments of the company code (blank = any)
    METHODS no_run
      IMPORTING
        iv_date           TYPE d
        iv_company        TYPE bukrs
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! Payments of past runs without payment document
    METHODS without_document
      CHANGING
        cs_result TYPE zif_ca_ops_chk_types=>ty_result.

    "! The run rows per run, proposal flag, company code and currency (payment methods summed); with
    "! iv_skip_orders the payments without document of a payment-order method (CASH_PAYRUN_ORDER_METHODS) are
    "! left out - such a method posts its document only after the bank confirmed the order
    METHODS by_run
      IMPORTING
        iv_skip_orders TYPE abap_bool
      RETURNING
        VALUE(rt_runs) TYPE zif_ca_ops_cash_types=>tt_run_sum.

    "! Proposed items of past runs the payment run did not pay
    METHODS proposal_gaps
      CHANGING
        cs_result TYPE zif_ca_ops_chk_types=>ty_result.

    "! The job of the day: a finished one first, else a cancelled one, else the latest (blank = none)
    METHODS job_of
      IMPORTING
        iv_date       TYPE d
      RETURNING
        VALUE(rs_job) TYPE zif_ca_ops_job_types=>ty_job.

    "! The job line of the details (name, count, status, end); blank without a job
    METHODS job_line
      IMPORTING
        is_job         TYPE zif_ca_ops_job_types=>ty_job
      RETURNING
        VALUE(rv_line) TYPE string.

    "! Evidence keys of a run and of the day's job
    METHODS run_evidence
      IMPORTING
        is_run             TYPE zif_ca_ops_cash_types=>ty_run_sum
        is_job             TYPE zif_ca_ops_job_types=>ty_job
      RETURNING
        VALUE(rt_evidence) TYPE zif_ca_ops_cash_types=>tt_evidence.

ENDCLASS.



CLASS zcl_ca_ops_chk_cash_payrun IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    mo_ctx = NEW #( is_check = is_check is_context = is_context ).
    DATA(lv_today) = mo_ctx->today( ).
    DATA(lv_from) = CONV d( lv_today - mo_ctx->param_int( iv_name    = zif_ca_ops_cash_types=>gc_param-lookback_days
                                                    iv_default = zif_ca_ops_cash_types=>gc_param_default-lookback_days ) ).
    TRY.
        mt_runs = mo_ctx->dao( )->payment_runs( iv_from = lv_from iv_to = lv_today iv_max = mo_ctx->max_rows( ) ).
        mo_ctx->cap( EXPORTING iv_stage    = zif_ca_ops_cash_types=>gc_stage-payment
                               iv_source   = zif_ca_ops_cash_types=>gc_source-payments
                               iv_rows     = lines( mt_runs )
                     CHANGING  ct_findings = rs_result-findings ).
      CATCH zcx_ca_ops_error INTO DATA(lx_runs).
        " without the payments nothing of the run can be told: one "not evaluated", never green
        INSERT mo_ctx->read_failed( iv_stage  = zif_ca_ops_cash_types=>gc_stage-payment
                                    iv_source = zif_ca_ops_cash_types=>gc_source-payments
                                    ix_error  = lx_runs ) INTO TABLE rs_result-findings.
        rs_result-partial = abap_true.
        rs_result-evidence = mo_ctx->evidence( ).
        rs_result-eval = mo_ctx->eval( ).
        RETURN.
    ENDTRY.
    DATA(lv_pattern) = mo_ctx->param_text( zif_ca_ops_cash_types=>gc_param-payrun_jobname ).
    IF lv_pattern IS NOT INITIAL.
      TRY.
          mt_jobs = mo_ctx->dao( )->jobs( iv_pattern = lv_pattern
                                          iv_from    = lv_from
                                          iv_to      = lv_today
                                          iv_max     = mo_ctx->max_rows( ) ).
        CATCH zcx_ca_ops_error INTO DATA(lx_jobs).
          " without job evidence a day without payments is reported missing (zero volume cannot be told)
          INSERT mo_ctx->read_failed( iv_stage  = zif_ca_ops_cash_types=>gc_stage-job
                                      iv_source = zif_ca_ops_cash_types=>gc_source-jobs
                                      iv_param  = zif_ca_ops_cash_types=>gc_param-payrun_jobname
                                      ix_error  = lx_jobs ) INTO TABLE rs_result-findings.
      ENDTRY.
    ENDIF.
    expected_runs( CHANGING cs_result = rs_result ).
    without_document( CHANGING cs_result = rs_result ).
    proposal_gaps( CHANGING cs_result = rs_result ).
    rs_result-item_count = rs_result-item_count + lines( mt_runs ).
    rs_result-partial = mo_ctx->partial( ).
    " exception contract: the typed evidence rows of the findings (stored by the runner)
    rs_result-evidence = mo_ctx->evidence( ).
    rs_result-eval = mo_ctx->eval( ).
  ENDMETHOD.


  METHOD expected_runs.
    DATA lt_companies TYPE STANDARD TABLE OF bukrs WITH EMPTY KEY.
    DATA lv_seen TYPE abap_bool.

    TRY.
        DATA(lt_days) = mo_ctx->window_days( mo_ctx->param_int(
                          iv_name    = zif_ca_ops_cash_types=>gc_param-payrun_lag_days
                          iv_default = zif_ca_ops_cash_types=>gc_param_default-payrun_lag_days ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_calendar).
        INSERT mo_ctx->read_failed( iv_stage  = zif_ca_ops_cash_types=>gc_stage-schedule
                                    iv_source = zif_ca_ops_cash_types=>gc_source-calendar
                                    iv_param  = zif_ca_ops_cash_types=>gc_param-calendar
                                    ix_error  = lx_calendar ) INTO TABLE cs_result-findings.
        RETURN.
    ENDTRY.
    lt_companies = VALUE #( FOR ls_range IN mo_ctx->param_range( zif_ca_ops_cash_types=>gc_param-payrun_bukrs )
                            ( CONV bukrs( ls_range-low ) ) ).
    IF lt_companies IS INITIAL.
      " no company code list: one expectation for the area (any paying company code)
      INSERT VALUE #( ) INTO TABLE lt_companies.
    ENDIF.
    LOOP AT lt_days ASSIGNING FIELD-SYMBOL(<ls_day>).
      cs_result-item_count = cs_result-item_count + 1.
      IF <ls_day>-working = abap_false.
        INSERT mo_ctx->finding( VALUE #(
          check_code  = zif_ca_ops_cash_types=>gc_code-not_expected
          severity    = zif_ca_ops_types=>gc_severity-info
          stage       = zif_ca_ops_cash_types=>gc_stage-schedule
          evaluation  = zif_ca_ops_cash_types=>gc_evaluation-not_expected
          object_type = zif_ca_ops_cash_types=>gc_object_type-day
          object_key  = zcl_ca_ops_cash_exc=>object_key( <ls_day>-date )
          source      = zif_ca_ops_cash_types=>gc_source-calendar
          rule_param  = zif_ca_ops_cash_types=>gc_param-calendar
          evidence    = VALUE #( ( name = zif_ca_ops_cash_types=>gc_key-day value = <ls_day>-date ) )
          msgno       = zif_ca_ops_cash_types=>gc_msg-not_expected
          msgv1       = zif_ca_ops_cash_types=>gc_stage-schedule
          msgv2       = |{ <ls_day>-date DATE = ISO }|
          msgv3       = mo_ctx->param_text( zif_ca_ops_cash_types=>gc_param-calendar ) ) ) INTO TABLE cs_result-findings.
        CONTINUE.
      ENDIF.
      LOOP AT lt_companies INTO DATA(lv_company).
        lv_seen = abap_false.
        LOOP AT mt_runs ASSIGNING FIELD-SYMBOL(<ls_run>) WHERE run_date = <ls_day>-date AND proposal = abap_false.
          IF lv_company IS INITIAL OR <ls_run>-company_code = lv_company.
            lv_seen = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_seen = abap_false.
          INSERT no_run( iv_date = <ls_day>-date iv_company = lv_company ) INTO TABLE cs_result-findings.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD no_run.
    DATA(ls_job) = job_of( iv_date ).
    DATA(ls_exc) = VALUE zif_ca_ops_cash_types=>ty_exception(
      object_type  = zif_ca_ops_cash_types=>gc_object_type-run
      object_key   = zcl_ca_ops_cash_exc=>object_key( iv_id = iv_date iv_company = iv_company )
      source       = zif_ca_ops_cash_types=>gc_source-jobs
      company_code = iv_company
      oldest       = iv_date
      rule_param   = zif_ca_ops_cash_types=>gc_param-payrun_jobname
      evidence     = VALUE #( ( name = zif_ca_ops_cash_types=>gc_key-day value = iv_date ) ) ).
    IF ls_job IS NOT INITIAL.
      INSERT VALUE #( name = zif_ca_ops_cash_types=>gc_key-job value = |{ ls_job-jobname }/{ ls_job-jobcount }| )
             INTO TABLE ls_exc-evidence.
      ls_exc-note = job_line( ls_job ).
    ENDIF.
    CASE ls_job-status.
      WHEN zif_ca_ops_job_types=>gc_status-finished.
        " the run ran and found nothing to pay: a valid zero-volume day
        ls_exc = VALUE #( BASE ls_exc
          check_code = zif_ca_ops_cash_types=>gc_code-zero_volume
          severity   = zif_ca_ops_types=>gc_severity-info
          stage      = zif_ca_ops_cash_types=>gc_stage-payment
          evaluation = zif_ca_ops_cash_types=>gc_evaluation-zero_volume
          msgno      = zif_ca_ops_cash_types=>gc_msg-zero_volume
          msgv1      = zif_ca_ops_cash_types=>gc_stage-payment
          msgv2      = |{ iv_date DATE = ISO }|
          msgv3      = ls_job-jobname ).
      WHEN zif_ca_ops_job_types=>gc_status-aborted.
        ls_exc = VALUE #( BASE ls_exc
          check_code = zif_ca_ops_cash_types=>gc_code-payrun_job_failed
          severity   = zif_ca_ops_types=>gc_severity-error
          stage      = zif_ca_ops_cash_types=>gc_stage-job
          evaluation = zif_ca_ops_cash_types=>gc_evaluation-observed
          msgno      = zif_ca_ops_cash_types=>gc_msg-payrun_job_failed
          msgv1      = ls_job-jobname
          msgv2      = |{ iv_date DATE = ISO }|
          msgv3      = ls_job-status
          msgv4      = ls_job-jobcount ).
      WHEN OTHERS.
        " no payment and no finished job (or no job evidence configured): the run that was due did not happen
        ls_exc = VALUE #( BASE ls_exc
          check_code = zif_ca_ops_cash_types=>gc_code-payrun_missing
          severity   = zif_ca_ops_types=>gc_severity-error
          stage      = zif_ca_ops_cash_types=>gc_stage-schedule
          evaluation = COND #( WHEN ls_job IS INITIAL THEN zif_ca_ops_cash_types=>gc_evaluation-stale
                               ELSE zif_ca_ops_cash_types=>gc_evaluation-observed )
          msgno      = zif_ca_ops_cash_types=>gc_msg-payrun_missing
          msgv1      = |{ iv_date DATE = ISO }|
          msgv2      = iv_company ).
    ENDCASE.
    rs_finding = mo_ctx->finding( ls_exc ).
  ENDMETHOD.


  METHOD without_document.
    DATA(lv_to) = CONV d( mo_ctx->today( ) - mo_ctx->param_int(
                            iv_name    = zif_ca_ops_cash_types=>gc_param-payrun_min_age
                            iv_default = zif_ca_ops_cash_types=>gc_param_default-payrun_min_age ) ).
    DATA(lt_runs) = by_run( abap_true ).
    LOOP AT lt_runs ASSIGNING FIELD-SYMBOL(<ls_run>)
         WHERE proposal = abap_false AND nodoc_count > 0 AND run_date <= lv_to.
      DATA(ls_job) = job_of( <ls_run>-run_date ).
      DATA(lv_run) = |{ <ls_run>-run_date DATE = ISO }/{ <ls_run>-run_id }|.
      DATA(lv_amount) = zcl_ca_ops_cash_exc=>amount_text( iv_amount   = <ls_run>-nodoc_amount
                                                          iv_currency = <ls_run>-currency ).
      DATA(ls_exc) = VALUE zif_ca_ops_cash_types=>ty_exception(
        check_code   = zif_ca_ops_cash_types=>gc_code-payrun_no_doc
        severity     = zif_ca_ops_types=>gc_severity-error
        stage        = zif_ca_ops_cash_types=>gc_stage-payment
        object_type  = zif_ca_ops_cash_types=>gc_object_type-run
        object_key   = zcl_ca_ops_cash_exc=>object_key( iv_id       = <ls_run>-run_date
                                                        iv_sub      = <ls_run>-run_id
                                                        iv_company  = <ls_run>-company_code
                                                        iv_currency = <ls_run>-currency )
        source       = zif_ca_ops_cash_types=>gc_source-payments
        company_code = <ls_run>-company_code
        currency     = <ls_run>-currency
        item_count   = <ls_run>-nodoc_count
        amount       = <ls_run>-nodoc_amount
        oldest       = <ls_run>-run_date
        rule_param   = zif_ca_ops_cash_types=>gc_param-payrun_min_age
        evidence     = run_evidence( is_run = <ls_run> is_job = ls_job )
        msgno        = zif_ca_ops_cash_types=>gc_msg-payrun_no_doc
        msgv1        = lv_run
        msgv2        = |{ <ls_run>-nodoc_count }|
        msgv3        = lv_amount
        note         = job_line( ls_job ) ).
      IF ls_job-status = zif_ca_ops_job_types=>gc_status-finished.
        " failure injection: the job reports success, the business output is incomplete
        ls_exc-stage = zif_ca_ops_cash_types=>gc_stage-job_ok.
        ls_exc-msgno = zif_ca_ops_cash_types=>gc_msg-payrun_job_ok.
        ls_exc-msgv1 = ls_job-jobname.
        ls_exc-msgv2 = lv_run.
        ls_exc-msgv3 = |{ <ls_run>-nodoc_count }|.
        ls_exc-msgv4 = lv_amount.
      ENDIF.
      INSERT mo_ctx->finding( ls_exc ) INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD proposal_gaps.
    DATA ls_paid TYPE zif_ca_ops_cash_types=>ty_run_sum.

    " the rule needs V221 (same run date and ID of proposal and payment run): off until confirmed
    IF mo_ctx->param_text( zif_ca_ops_cash_types=>gc_param-payrun_gap_active ) <> abap_true.
      RETURN.
    ENDIF.
    DATA(lv_to) = CONV d( mo_ctx->today( ) - mo_ctx->param_int(
                            iv_name    = zif_ca_ops_cash_types=>gc_param-payrun_min_age
                            iv_default = zif_ca_ops_cash_types=>gc_param_default-payrun_min_age ) ).
    DATA(lt_runs) = by_run( abap_false ).
    LOOP AT lt_runs ASSIGNING FIELD-SYMBOL(<ls_prop>) WHERE proposal = abap_true AND run_date <= lv_to.
      CLEAR ls_paid.
      READ TABLE lt_runs INTO ls_paid WITH KEY run_date     = <ls_prop>-run_date
                                               run_id       = <ls_prop>-run_id
                                               proposal     = abap_false
                                               company_code = <ls_prop>-company_code
                                               currency     = <ls_prop>-currency.
      DATA(lv_gap_count) = <ls_prop>-item_count - ls_paid-item_count.
      IF lv_gap_count <= 0.
        CONTINUE.
      ENDIF.
      DATA(lv_gap_amount) = CONV zif_ca_ops_cash_types=>ty_amount( <ls_prop>-amount - ls_paid-amount ).
      DATA(ls_job) = job_of( <ls_prop>-run_date ).
      INSERT mo_ctx->finding( VALUE #(
        check_code   = zif_ca_ops_cash_types=>gc_code-payrun_gap
        severity     = zif_ca_ops_types=>gc_severity-error
        stage        = COND #( WHEN ls_job-status = zif_ca_ops_job_types=>gc_status-finished
                               THEN zif_ca_ops_cash_types=>gc_stage-job_ok
                               ELSE zif_ca_ops_cash_types=>gc_stage-proposal )
        object_type  = zif_ca_ops_cash_types=>gc_object_type-run
        object_key   = zcl_ca_ops_cash_exc=>object_key( iv_id       = <ls_prop>-run_date
                                                        iv_sub      = <ls_prop>-run_id
                                                        iv_company  = <ls_prop>-company_code
                                                        iv_currency = <ls_prop>-currency )
        source       = zif_ca_ops_cash_types=>gc_source-payments
        company_code = <ls_prop>-company_code
        currency     = <ls_prop>-currency
        item_count   = lv_gap_count
        amount       = lv_gap_amount
        oldest       = <ls_prop>-run_date
        rule_param   = zif_ca_ops_cash_types=>gc_param-payrun_gap_active
        evidence     = run_evidence( is_run = <ls_prop> is_job = ls_job )
        msgno        = zif_ca_ops_cash_types=>gc_msg-payrun_gap
        msgv1        = |{ <ls_prop>-run_date DATE = ISO }/{ <ls_prop>-run_id }|
        msgv2        = |{ lv_gap_count }|
        msgv3        = zcl_ca_ops_cash_exc=>amount_text( iv_amount   = lv_gap_amount
                                                         iv_currency = <ls_prop>-currency ) ) ) INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD by_run.
    rt_runs = sum_by_run( it_rows          = mt_runs
                          it_order_methods = mo_ctx->param_range( zif_ca_ops_cash_types=>gc_param-payrun_order_meth )
                          iv_skip_orders   = iv_skip_orders ).
  ENDMETHOD.


  METHOD sum_by_run.
    DATA lt_sum TYPE SORTED TABLE OF zif_ca_ops_cash_types=>ty_run_sum
                WITH UNIQUE KEY run_date run_id proposal company_code currency.

    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(ls_row) = <ls_row>.
      CLEAR ls_row-pay_method.
      IF iv_skip_orders = abap_true AND it_order_methods IS NOT INITIAL AND <ls_row>-pay_method IN it_order_methods.
        CLEAR: ls_row-nodoc_count, ls_row-nodoc_amount.
      ENDIF.
      READ TABLE lt_sum ASSIGNING FIELD-SYMBOL(<ls_sum>) WITH TABLE KEY run_date     = ls_row-run_date
                                                                      run_id       = ls_row-run_id
                                                                      proposal     = ls_row-proposal
                                                                      company_code = ls_row-company_code
                                                                      currency     = ls_row-currency.
      IF sy-subrc = 0.
        <ls_sum>-item_count   = <ls_sum>-item_count + ls_row-item_count.
        <ls_sum>-amount       = <ls_sum>-amount + ls_row-amount.
        <ls_sum>-nodoc_count  = <ls_sum>-nodoc_count + ls_row-nodoc_count.
        <ls_sum>-nodoc_amount = <ls_sum>-nodoc_amount + ls_row-nodoc_amount.
      ELSE.
        INSERT ls_row INTO TABLE lt_sum.
      ENDIF.
    ENDLOOP.
    rt_runs = lt_sum.
  ENDMETHOD.


  METHOD job_of.
    DATA ls_aborted TYPE zif_ca_ops_job_types=>ty_job.

    LOOP AT mt_jobs ASSIGNING FIELD-SYMBOL(<ls_job>)
         WHERE strtdate = iv_date OR ( strtdate IS INITIAL AND sdlstrtdt = iv_date ).
      CASE <ls_job>-status.
        WHEN zif_ca_ops_job_types=>gc_status-finished.
          rs_job = <ls_job>.
          RETURN.
        WHEN zif_ca_ops_job_types=>gc_status-aborted.
          ls_aborted = <ls_job>.
        WHEN OTHERS.
          rs_job = <ls_job>.
      ENDCASE.
    ENDLOOP.
    IF ls_aborted IS NOT INITIAL.
      rs_job = ls_aborted.
    ENDIF.
  ENDMETHOD.


  METHOD job_line.
    IF is_job IS INITIAL.
      RETURN.
    ENDIF.
    rv_line = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_cash_types=>gc_msg-det_job
                                     iv_v1    = is_job-jobname
                                     iv_v2    = is_job-jobcount
                                     iv_v3    = is_job-status
                                     iv_v4    = |{ is_job-enddate DATE = ISO } { is_job-endtime TIME = ISO }| ).
  ENDMETHOD.


  METHOD run_evidence.
    rt_evidence = VALUE #( ( name  = zif_ca_ops_cash_types=>gc_key-run
                             value = |{ is_run-run_date }/{ is_run-run_id }| ) ).
    IF is_job IS NOT INITIAL.
      INSERT VALUE #( name  = zif_ca_ops_cash_types=>gc_key-job
                      value = |{ is_job-jobname }/{ is_job-jobcount }| ) INTO TABLE rt_evidence.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
