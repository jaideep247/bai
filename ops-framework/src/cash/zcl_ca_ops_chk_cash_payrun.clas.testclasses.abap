*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_cash_payrun.clas.testclasses.abap
*& Purpose:
*& Fixtures of the payment run check (config/cash/fixtures.json, PAYRUN-*)
*& through ZIF_CA_OPS_CHECK=>RUN: an expected business day without payment
*& and without job = run missing (stale); a finished job without payments
*& = valid zero volume (information); a cancelled job = job failed; the
*& weekend = not expected (information); the failure injection - job
*& finished successfully, payments without payment document - is an
*& exception of stage JOB_OK with the run key, amount, currency, owner and
*& age; two currencies are two findings, never summed; the proposal gap
*& when the rule is on; a payment-order method is left out of the payments
*& without document; unreadable payments and a missing calendar are "not
*& evaluated" (the check partial), never green. Doubles: cash data access;
*& parameters in memory. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
CLASS ltd_payrun_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cash_dao PARTIALLY IMPLEMENTED.
    DATA mt_runs TYPE zif_ca_ops_cash_types=>tt_run_sum.
    DATA mt_jobs TYPE zif_ca_ops_job_types=>tt_job.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.

CLASS ltd_payrun_dao IMPLEMENTATION.
  METHOD zif_ca_ops_cash_dao~payment_runs.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e521(zca_ops) WITH 'DPAYH'.
    ENDIF.
    rt_runs = mt_runs.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~jobs.
    rt_jobs = mt_jobs.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~working_day.
    " the weekend 14 / 15 November 2026
    rv_working = xsdbool( iv_date <> '20261114' AND iv_date <> '20261115' ).
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~owner.
    rs_owner = VALUE #( control_id = 'FICA_PAYRUN' owner = 'ZT_OWNER' backup = 'ZT_BACKUP' team = 'ZT_TEAM'
                        cutoff_time = '100000' ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_cash_payrun DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area  TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        bukrs TYPE bukrs VALUE 'ZT01',
        today TYPE d VALUE '20261116',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_payrun_dao.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.
    METHODS of_code
      IMPORTING
        is_result          TYPE zif_ca_ops_chk_types=>ty_result
        iv_code            TYPE zif_ca_ops_types=>ty_check_code
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.
    METHODS given_run_of_12th.
    METHODS given_job
      IMPORTING
        iv_date   TYPE d
        iv_status TYPE zif_ca_ops_job_types=>ty_status.

    METHODS missing_run_on_business_day FOR TESTING RAISING zcx_ca_ops_error.
    METHODS zero_volume_is_information  FOR TESTING RAISING zcx_ca_ops_error.
    METHODS cancelled_job_is_job_failed FOR TESTING RAISING zcx_ca_ops_error.
    METHODS job_ok_output_incomplete    FOR TESTING RAISING zcx_ca_ops_error.
    METHODS currencies_never_summed     FOR TESTING RAISING zcx_ca_ops_error.
    METHODS proposal_gap_when_active    FOR TESTING RAISING zcx_ca_ops_error.
    METHODS unreadable_not_evaluated    FOR TESTING RAISING zcx_ca_ops_error.
    METHODS no_calendar_not_evaluated   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS order_method_excluded       FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_chk_cash_payrun IMPLEMENTATION.

  METHOD setup.
    mo_dao  = NEW #( ).
    mo_seed = NEW #( ).
    zcl_ca_ops_cash_injector=>inject_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-calendar iv_value = 'ZT' ).
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-lookback_days iv_value = '4' ).
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-payrun_jobname iv_value = 'ZT_PAYRUN*' ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_cash_injector=>reset( ).
  ENDMETHOD.


  METHOD run.
    rs_result = NEW zcl_ca_ops_chk_cash_payrun( )->zif_ca_ops_check~run(
                  is_check   = VALUE #( area = gc-area check_id = 'FICA_CASH_PAYRUN' process_id = 'FICA_PAYRUN'
                                        bukrs_aware = abap_true )
                  is_context = VALUE #( area = gc-area today = gc-today now = '20261116080000.0000000' ) ).
  ENDMETHOD.


  METHOD of_code.
    rt_findings = VALUE #( FOR ls IN is_result-findings WHERE ( check_code = iv_code ) ( ls ) ).
  ENDMETHOD.


  " A run of Thursday 12 November with payments, all with payment document
  METHOD given_run_of_12th.
    mo_dao->mt_runs = VALUE #( ( run_date = '20261112' run_id = 'PAY01' company_code = gc-bukrs currency = 'EUR'
                                 item_count = 3 amount = '900.00' ) ).
  ENDMETHOD.


  METHOD given_job.
    INSERT VALUE #( jobname = 'ZT_PAYRUN_DAILY' jobcount = |{ iv_date+6(2) }000001| status = iv_status
                    strtdate = iv_date enddate = iv_date endtime = '063000' ) INTO TABLE mo_dao->mt_jobs.
  ENDMETHOD.


  " Fixture PAYRUN-01 (scorecard 4): Friday 13th silent - no payment, no job: run missing, source stale;
  " the weekend is not expected; Thursday observed
  METHOD missing_run_on_business_day.
    given_run_of_12th( ).

    DATA(ls_result) = run( ).

    DATA(lt_missing) = of_code( is_result = ls_result iv_code = zif_ca_ops_cash_types=>gc_code-payrun_missing ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_missing ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_missing[ 1 ]-object_key exp = '20261113' ).
    cl_abap_unit_assert=>assert_equals( act = lt_missing[ 1 ]-severity exp = zif_ca_ops_types=>gc_severity-error ).
    cl_abap_unit_assert=>assert_equals( act = lt_missing[ 1 ]-rule_id exp = zif_ca_ops_cash_types=>gc_stage-schedule ).
    cl_abap_unit_assert=>assert_true( xsdbool( lt_missing[ 1 ]-details CS zif_ca_ops_cash_types=>gc_evaluation-stale ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( lt_missing[ 1 ]-details CS 'ZT_OWNER' ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( of_code( is_result = ls_result iv_code = zif_ca_ops_cash_types=>gc_code-not_expected ) )
      exp = 2 ).
    cl_abap_unit_assert=>assert_false( ls_result-partial ).
  ENDMETHOD.


  " Fixture PAYRUN-02 (scorecard 4): the job ran on the 13th and paid nothing - valid zero volume, not missing
  METHOD zero_volume_is_information.
    given_run_of_12th( ).
    given_job( iv_date = '20261113' iv_status = zif_ca_ops_job_types=>gc_status-finished ).

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_initial( of_code( is_result = ls_result
                                                  iv_code   = zif_ca_ops_cash_types=>gc_code-payrun_missing ) ).
    DATA(lt_zero) = of_code( is_result = ls_result iv_code = zif_ca_ops_cash_types=>gc_code-zero_volume ).
    cl_abap_unit_assert=>assert_equals( act = lt_zero[ 1 ]-severity exp = zif_ca_ops_types=>gc_severity-info ).
    cl_abap_unit_assert=>assert_true( xsdbool( lt_zero[ 1 ]-details CS zif_ca_ops_cash_types=>gc_evaluation-zero_volume ) ).
  ENDMETHOD.


  " Fixture PAYRUN-03: the job of the 13th was cancelled - job failed, stage JOB
  METHOD cancelled_job_is_job_failed.
    given_run_of_12th( ).
    given_job( iv_date = '20261113' iv_status = zif_ca_ops_job_types=>gc_status-aborted ).

    DATA(lt_failed) = of_code( is_result = run( ) iv_code = zif_ca_ops_cash_types=>gc_code-payrun_job_failed ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_failed ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_failed[ 1 ]-rule_id exp = zif_ca_ops_cash_types=>gc_stage-job ).
    cl_abap_unit_assert=>assert_true( xsdbool( lt_failed[ 1 ]-details CS 'ZT_PAYRUN_DAILY' ) ).
  ENDMETHOD.


  " Fixture PAYRUN-04 (failure injection, scorecard 1): the job of the 12th finished successfully, one of three
  " payments has no payment document - exception JOB_OK with run key, amount, currency, owner and age
  METHOD job_ok_output_incomplete.
    mo_dao->mt_runs = VALUE #( ( run_date = '20261112' run_id = 'PAY01' company_code = gc-bukrs currency = 'EUR'
                                 item_count = 3 amount = '900.00' nodoc_count = 1 nodoc_amount = '250.00' ) ).
    given_job( iv_date = '20261112' iv_status = zif_ca_ops_job_types=>gc_status-finished ).

    DATA(lt_nodoc) = of_code( is_result = run( ) iv_code = zif_ca_ops_cash_types=>gc_code-payrun_no_doc ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_nodoc ) exp = 1 ).
    DATA(ls_finding) = lt_nodoc[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_finding-rule_id exp = zif_ca_ops_cash_types=>gc_stage-job_ok ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = '20261112/PAY01/ZT01/EUR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = '250.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-currency exp = 'EUR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-company_code exp = gc-bukrs ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-item_count exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-business_date exp = '20261112' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-reference exp = zif_ca_ops_cash_types=>gc_source-payments ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-message CS 'ZT_PAYRUN_DAILY' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS 'ZT_OWNER' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS 'LAUFD/LAUFI' ) ).
    " age 4 days (12th to 16th); the next cutoff today 10:00 (before the cutoff time)
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS '2026-11-12' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS '2026-11-16' ) ).
  ENDMETHOD.


  " Fixture PAYRUN-05: a run paying in two currencies - one finding per currency, amounts never summed
  METHOD currencies_never_summed.
    mo_dao->mt_runs = VALUE #( ( run_date = '20261112' run_id = 'PAY01' company_code = gc-bukrs currency = 'EUR'
                                 item_count = 2 amount = '200.00' nodoc_count = 1 nodoc_amount = '100.00' )
                               ( run_date = '20261112' run_id = 'PAY01' company_code = gc-bukrs currency = 'USD'
                                 item_count = 2 amount = '300.00' nodoc_count = 2 nodoc_amount = '300.00' ) ).

    DATA(lt_nodoc) = of_code( is_result = run( ) iv_code = zif_ca_ops_cash_types=>gc_code-payrun_no_doc ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_nodoc ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_nodoc[ currency = 'USD' ]-amount exp = '300.00' ).
    cl_abap_unit_assert=>assert_equals( act = lt_nodoc[ currency = 'EUR' ]-amount exp = '100.00' ).
    cl_abap_unit_assert=>assert_equals( act = lt_nodoc[ currency = 'EUR' ]-rule_id exp = zif_ca_ops_cash_types=>gc_stage-payment ).
  ENDMETHOD.


  " Fixture PAYRUN-06: proposal of 5 items not followed in full (3 paid) - gap 2 items, 200.00 (rule switched on)
  METHOD proposal_gap_when_active.
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-payrun_gap_active iv_value = abap_true ).
    mo_dao->mt_runs = VALUE #( ( run_date = '20261112' run_id = 'PAY01' proposal = abap_true company_code = gc-bukrs
                                 currency = 'EUR' item_count = 5 amount = '500.00' )
                               ( run_date = '20261112' run_id = 'PAY01' company_code = gc-bukrs currency = 'EUR'
                                 item_count = 3 amount = '300.00' ) ).

    DATA(lt_gap) = of_code( is_result = run( ) iv_code = zif_ca_ops_cash_types=>gc_code-payrun_gap ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_gap ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_gap[ 1 ]-item_count exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_gap[ 1 ]-amount exp = '200.00' ).
    cl_abap_unit_assert=>assert_equals( act = lt_gap[ 1 ]-rule_id exp = zif_ca_ops_cash_types=>gc_stage-proposal ).
  ENDMETHOD.


  " Fixture PAYRUN-07 (scorecard 4, failed query): payments unreadable - not evaluated, partial, nothing green
  METHOD unreadable_not_evaluated.
    mo_dao->mv_fail = abap_true.

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                        exp = zif_ca_ops_cash_types=>gc_code-not_evaluated ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-reference
                                        exp = zif_ca_ops_cash_types=>gc_source-payments ).
    cl_abap_unit_assert=>assert_true( ls_result-partial ).
  ENDMETHOD.


  " Fixture PAYRUN-08: no business calendar - the expected runs are not evaluated (never "every day" or "none")
  METHOD no_calendar_not_evaluated.
    mo_seed->remove( zif_ca_ops_cash_types=>gc_param-calendar ).
    given_run_of_12th( ).

    DATA(ls_result) = run( ).

    DATA(lt_not_evaluated) = of_code( is_result = ls_result iv_code = zif_ca_ops_cash_types=>gc_code-not_evaluated ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_not_evaluated ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_not_evaluated[ 1 ]-rule_id exp = zif_ca_ops_cash_types=>gc_stage-schedule ).
    cl_abap_unit_assert=>assert_initial( of_code( is_result = ls_result
                                                  iv_code   = zif_ca_ops_cash_types=>gc_code-payrun_missing ) ).
    cl_abap_unit_assert=>assert_true( ls_result-partial ).
  ENDMETHOD.

  " Fixture PAYRUN-09: a payment-order method posts no payment document by design - only the other method's
  " payment without document is an exception, the methods of one run, company code and currency summed
  METHOD order_method_excluded.
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-payrun_order_meth iv_value = 'O' ).
    mo_dao->mt_runs = VALUE #( ( run_date = '20261112' run_id = 'PAY01' company_code = gc-bukrs currency = 'EUR'
                                 pay_method = 'O' item_count = 2 amount = '200.00' nodoc_count = 2 nodoc_amount = '200.00' )
                               ( run_date = '20261112' run_id = 'PAY01' company_code = gc-bukrs currency = 'EUR'
                                 pay_method = 'C' item_count = 3 amount = '150.00' nodoc_count = 1 nodoc_amount = '50.00' ) ).

    DATA(lt_nodoc) = of_code( is_result = run( ) iv_code = zif_ca_ops_cash_types=>gc_code-payrun_no_doc ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_nodoc ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_nodoc[ 1 ]-object_key exp = '20261112/PAY01/ZT01/EUR' ).
    cl_abap_unit_assert=>assert_equals( act = lt_nodoc[ 1 ]-item_count exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_nodoc[ 1 ]-amount exp = '50.00' ).
  ENDMETHOD.

ENDCLASS.
