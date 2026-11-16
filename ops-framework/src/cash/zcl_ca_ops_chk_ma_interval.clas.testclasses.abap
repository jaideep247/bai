*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_ma_interval.clas.testclasses.abap
*& Purpose:
*& Fixtures of the mass activity check (config/expected_runs/fixtures.json,
*& MA-*) through ZIF_CA_OPS_CHECK=>RUN. Scorecard scenario 1: the parent
*& job of the payment run finished successfully, one of its three
*& intervals was cancelled, and the run produced 2 of 3 payment documents
*& - one exception at stage JOB_OK with count 1, 250.00 EUR, owner,
*& deadline and the evidence of the run, the parent job and the failed
*& interval. Also: an interval failed without an output rule; an interval
*& running past its limit; dunning notices below the minimum (count only);
*& two parent jobs of one run date judged once; the proposal as the
*& expectation only with CASH_PAYRUN_GAP_ACTIVE; a run source that cannot
*& read is "not evaluated" (partial), never green. Doubles: run source
*& (plug-in), cash data access, mass activity data access, parameters.
*& Modification log:
*& 2026-11-16 | Initial version (build P: FI-CA mass-activity intervals and their output).
*&---------------------------------------------------------------------*
CLASS ltd_ma_source DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_ma_src.
    DATA mt_runs TYPE zif_ca_ops_ma_types=>tt_run.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.

CLASS ltd_ma_source IMPLEMENTATION.
  METHOD zif_ca_ops_ma_src~runs.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e521(zca_ops) WITH 'TBTCO/TBTCP'.
    ENDIF.
    rs_runs-runs = VALUE #( FOR ls IN mt_runs WHERE ( act_id = is_activity-act_id ) ( ls ) ).
  ENDMETHOD.
ENDCLASS.


CLASS ltd_ma_cash_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cash_dao PARTIALLY IMPLEMENTED.
    DATA mt_runs TYPE zif_ca_ops_cash_types=>tt_run_sum.
ENDCLASS.

CLASS ltd_ma_cash_dao IMPLEMENTATION.
  METHOD zif_ca_ops_cash_dao~payment_runs.
    rt_runs = mt_runs.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~working_day.
    rv_working = xsdbool( iv_date <> '20261114' AND iv_date <> '20261115' ).
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~owner.
    rs_owner = VALUE #( control_id = 'FICA_PAYRUN' owner = 'ZT_OWNER' backup = 'ZT_BACKUP' team = 'ZT_TEAM'
                        cutoff_time = '100000' ).
  ENDMETHOD.
ENDCLASS.


CLASS ltd_ma_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_ma_dao.
    DATA mt_activities TYPE zif_ca_ops_ma_types=>tt_activity.
    DATA mt_notices TYPE zif_ca_ops_ma_types=>tt_notice_sum.
ENDCLASS.

CLASS ltd_ma_dao IMPLEMENTATION.
  METHOD zif_ca_ops_ma_dao~activities.
    rt_activities = mt_activities.
  ENDMETHOD.
  METHOD zif_ca_ops_ma_dao~dunning_notices.
    rt_sums = mt_notices.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_ma_interval DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area   TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        source TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZT_MA_SRC',
        bukrs  TYPE bukrs VALUE 'ZT01',
        today  TYPE d VALUE '20261116',
        rundate TYPE d VALUE '20261112',
      END OF gc.

    DATA mo_source TYPE REF TO ltd_ma_source.
    DATA mo_cash TYPE REF TO ltd_ma_cash_dao.
    DATA mo_ma TYPE REF TO ltd_ma_dao.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.
    METHODS activity
      IMPORTING
        iv_act_id          TYPE zif_ca_ops_ma_types=>ty_act_id DEFAULT 'PAYRUN'
        iv_output          TYPE zif_ca_ops_ma_types=>ty_output_kind DEFAULT 'PAYDOC'
        iv_min             TYPE i OPTIONAL
      RETURNING
        VALUE(rs_activity) TYPE zif_ca_ops_ma_types=>ty_activity.
    "! A run of 12 November: parent job with its status, three intervals of which one has the given status
    METHODS given_run
      IMPORTING
        iv_act_id      TYPE zif_ca_ops_ma_types=>ty_act_id DEFAULT 'PAYRUN'
        iv_parent      TYPE zif_ca_ops_job_types=>ty_status DEFAULT 'F'
        iv_interval2   TYPE zif_ca_ops_ma_types=>ty_state DEFAULT 'FAILED'
        iv_minutes2    TYPE i DEFAULT 12
      RETURNING
        VALUE(rs_run)  TYPE zif_ca_ops_ma_types=>ty_run.
    "! DPAYH of run 20261112 / PAY01: three payments, the 250.00 EUR one without payment document
    METHODS given_payments.
    METHODS of_code
      IMPORTING
        is_result         TYPE zif_ca_ops_chk_types=>ty_result
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    METHODS job_ok_interval_failed_short  FOR TESTING RAISING zcx_ca_ops_error.
    METHODS interval_failed_no_output     FOR TESTING RAISING zcx_ca_ops_error.
    METHODS interval_overrun              FOR TESTING RAISING zcx_ca_ops_error.
    METHODS dunning_below_minimum         FOR TESTING RAISING zcx_ca_ops_error.
    METHODS complete_run_is_ok            FOR TESTING RAISING zcx_ca_ops_error.
    METHODS two_parents_judged_once       FOR TESTING RAISING zcx_ca_ops_error.
    METHODS proposal_when_gap_active      FOR TESTING.
    METHODS unreadable_runs_not_evaluated FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_chk_ma_interval IMPLEMENTATION.

  METHOD setup.
    mo_source = NEW #( ).
    mo_cash   = NEW #( ).
    mo_ma     = NEW #( ).
    mo_seed   = NEW #( ).
    zcl_ca_ops_cash_injector=>inject_dao( mo_cash ).
    zcl_ca_ops_cash_injector=>inject_ma_dao( mo_ma ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc-source io_instance = mo_source ).
    mo_seed->set( iv_name = zif_ca_ops_ma_types=>gc_param-source iv_value = gc-source ).
    mo_seed->set( iv_name = zif_ca_ops_ma_types=>gc_param-lookback_days iv_value = '4' ).
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-calendar iv_value = 'ZT' ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_cash_injector=>reset( ).
  ENDMETHOD.


  METHOD run.
    rs_result = NEW zcl_ca_ops_chk_ma_interval( )->zif_ca_ops_check~run(
                  is_check   = VALUE #( area = gc-area check_id = 'FICA_MA_INTERVALS' process_id = 'FICA_PAYRUN'
                                        bukrs_aware = abap_true )
                  is_context = VALUE #( area = gc-area today = gc-today now = '20261116080000.0000000' ) ).
  ENDMETHOD.


  METHOD activity.
    rs_activity = VALUE #( area           = gc-area
                           act_id         = iv_act_id
                           aktyp          = 'ZPAY'
                           parent_program = 'RFKK_MA_SCHEDULER'
                           job_pattern    = 'ZT_FPY1_.*'
                           output_kind    = iv_output
                           min_output     = iv_min ).
  ENDMETHOD.


  METHOD given_run.
    rs_run = VALUE #( act_id   = iv_act_id
                      aktyp    = 'ZPAY'
                      run_date = gc-rundate
                      parent   = VALUE #( jobname = 'ZT_FPY1_PAY01' jobcount = '06000001' status = iv_parent
                                          strtdate = gc-rundate strttime = '060000'
                                          enddate = COND #( WHEN iv_parent = 'F' OR iv_parent = 'A' THEN gc-rundate )
                                          endtime = COND #( WHEN iv_parent = 'F' OR iv_parent = 'A' THEN '063000' ) )
                      quality  = zif_ca_ops_exc_contract=>gc_quality-probable
                      intervals = VALUE #(
                        ( number = 1 state = 'OK' minutes = 10
                          job = VALUE #( jobname = 'ZT_FPY1_PAY01_W' jobcount = '06010001' status = 'F' ) )
                        ( number = 2 state = iv_interval2 minutes = iv_minutes2
                          job = VALUE #( jobname = 'ZT_FPY1_PAY01_W' jobcount = '06010002'
                                         status = SWITCH #( iv_interval2 WHEN 'FAILED' THEN 'A'
                                                                         WHEN 'RUNNING' THEN 'R' ELSE 'F' ) ) )
                        ( number = 3 state = 'OK' minutes = 11
                          job = VALUE #( jobname = 'ZT_FPY1_PAY01_W' jobcount = '06010003' status = 'F' ) ) ) ).
  ENDMETHOD.


  METHOD given_payments.
    mo_cash->mt_runs = VALUE #( ( run_date = gc-rundate run_id = 'PAY01' company_code = gc-bukrs currency = 'EUR'
                                  pay_method = 'T' item_count = 3 amount = '900.00'
                                  nodoc_count = 1 nodoc_amount = '250.00' ) ).
  ENDMETHOD.


  METHOD of_code.
    READ TABLE is_result-findings INTO rs_finding WITH KEY check_code = iv_code.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = |{ iv_code } expected| ).
  ENDMETHOD.


  " Fixture MA-01 (scorecard 1): parent job ZT_FPY1_PAY01 finished OK, interval 2 cancelled, the payment run
  " 20261112 / PAY01 produced 2 of 3 payment documents: one exception, stage JOB_OK, 1 document, 250.00 EUR, owner,
  " deadline (next working day 10:00), evidence: run, activity type, parent job, the failed interval and its job
  METHOD job_ok_interval_failed_short.
    mo_ma->mt_activities = VALUE #( ( activity( ) ) ).
    mo_source->mt_runs = VALUE #( ( given_run( ) ) ).
    given_payments( ).

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 ).
    DATA(ls_finding) = of_code( is_result = ls_result iv_code = zif_ca_ops_ma_types=>gc_code-output_short ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-error ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-stage exp = zif_ca_ops_cash_types=>gc_stage-job_ok ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = 'PAYRUN/20261112/PAY01/ZT01/EUR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-item_count exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = '250.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-currency exp = 'EUR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-company_code exp = gc-bukrs ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-resp_user exp = 'ZT_OWNER' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-resp_source exp = zif_ca_ops_exc_contract=>gc_resp_source-control ).
    cl_abap_unit_assert=>assert_not_initial( ls_finding-deadline_at ).
    cl_abap_unit_assert=>assert_initial( zcl_ca_ops_exc_contract=>missing( ls_finding ) ).
    DATA(lt_evidence) = VALUE zif_ca_ops_exc_contract=>tt_evidence( FOR ls IN ls_result-evidence
                                                                    WHERE ( evid_key = ls_finding-evid_key ) ( ls ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_evidence ) exp = 5 ).
    cl_abap_unit_assert=>assert_equals( act = lt_evidence[ 1 ]-native_key exp = 'AKTYP/LAUFD/LAUFI=ZPAY/20261112/PAY01' ).
    cl_abap_unit_assert=>assert_equals( act = lt_evidence[ 2 ]-link_object exp = 'S4_BACKGROUND_JOB' ).
    cl_abap_unit_assert=>assert_equals( act = lt_evidence[ 3 ]-link_object exp = 'FICA_PAYMENT_RUN' ).
    cl_abap_unit_assert=>assert_equals( act = lt_evidence[ 4 ]-native_key exp = 'INTERVAL=2' ).
    cl_abap_unit_assert=>assert_equals( act = lt_evidence[ 5 ]-link_value exp = 'JOBNAME=ZT_FPY1_PAY01_W;JOBCOUNT=06010002' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-result_class exp = zif_ca_ops_eval_types=>gc_state-findings ).
  ENDMETHOD.


  " Fixture MA-02: no output rule - the parent ended OK while interval 2 was cancelled: interval failed, stage JOB_OK
  METHOD interval_failed_no_output.
    mo_ma->mt_activities = VALUE #( ( activity( iv_output = 'NONE' ) ) ).
    mo_source->mt_runs = VALUE #( ( given_run( ) ) ).

    DATA(ls_result) = run( ).

    DATA(ls_finding) = of_code( is_result = ls_result iv_code = zif_ca_ops_ma_types=>gc_code-interval_failed ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-stage exp = zif_ca_ops_cash_types=>gc_stage-job_ok ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-item_count exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-unknown_count exp = 1 ).
    cl_abap_unit_assert=>assert_initial( zcl_ca_ops_exc_contract=>missing( ls_finding ) ).
  ENDMETHOD.


  " Fixture MA-03: the parent still runs, interval 2 runs for 150 minutes (limit 120): overrun warning
  METHOD interval_overrun.
    mo_ma->mt_activities = VALUE #( ( activity( ) ) ).
    mo_source->mt_runs = VALUE #( ( given_run( iv_parent = 'R' iv_interval2 = 'RUNNING' iv_minutes2 = 150 ) ) ).

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 ).
    DATA(ls_finding) = of_code( is_result = ls_result iv_code = zif_ca_ops_ma_types=>gc_code-interval_long ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-warning ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-stage exp = zif_ca_ops_ma_types=>gc_stage-interval ).
  ENDMETHOD.


  " Fixture MA-04: dunning run with 4 notices, minimum 10: short by 6 (count only, no currency)
  METHOD dunning_below_minimum.
    mo_ma->mt_activities = VALUE #( ( activity( iv_act_id = 'DUNNING' iv_output = 'DUNNING' iv_min = 10 ) ) ).
    mo_source->mt_runs = VALUE #( ( given_run( iv_act_id = 'DUNNING' iv_interval2 = 'OK' ) ) ).
    mo_ma->mt_notices = VALUE #( ( run_date = gc-rundate run_id = 'DUN01' currency = 'EUR' item_count = 4
                                   amount = '1200.00' ) ).

    DATA(ls_result) = run( ).

    DATA(ls_finding) = of_code( is_result = ls_result iv_code = zif_ca_ops_ma_types=>gc_code-output_short ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-item_count exp = 6 ).
    cl_abap_unit_assert=>assert_initial( ls_finding-currency ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-unknown_count exp = 6 ).
    cl_abap_unit_assert=>assert_initial( zcl_ca_ops_exc_contract=>missing( ls_finding ) ).
  ENDMETHOD.


  " Rule: intervals finished and every payment documented - nothing raised, the run counts as observed OK
  METHOD complete_run_is_ok.
    mo_ma->mt_activities = VALUE #( ( activity( ) ) ).
    mo_source->mt_runs = VALUE #( ( given_run( iv_interval2 = 'OK' ) ) ).
    mo_cash->mt_runs = VALUE #( ( run_date = gc-rundate run_id = 'PAY01' company_code = gc-bukrs currency = 'EUR'
                                  item_count = 3 amount = '900.00' ) ).

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_initial( ls_result-findings ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-result_class exp = zif_ca_ops_eval_types=>gc_state-ok ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-observed exp = 1 ).
  ENDMETHOD.


  " Rule: two parent jobs of the same run date (no run ID known) - the date's output is judged once
  METHOD two_parents_judged_once.
    mo_ma->mt_activities = VALUE #( ( activity( ) ) ).
    DATA(ls_second) = given_run( iv_interval2 = 'OK' ).
    ls_second-parent-jobcount = '07000001'.
    mo_source->mt_runs = VALUE #( ( given_run( iv_interval2 = 'OK' ) ) ( ls_second ) ).
    given_payments( ).

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 ).
  ENDMETHOD.


  " Rule: the proposal is the expectation only when the gap rule of the payment run check is on (VERIFY V221)
  METHOD proposal_when_gap_active.
    DATA(lt_rows) = VALUE zif_ca_ops_cash_types=>tt_run_sum(
      ( run_date = gc-rundate run_id = 'PAY01' company_code = gc-bukrs currency = 'EUR' item_count = 2 amount = '650.00' )
      ( run_date = gc-rundate run_id = 'PAY01' proposal = abap_true company_code = gc-bukrs currency = 'EUR'
        item_count = 3 amount = '900.00' ) ).

    DATA(lt_off) = zcl_ca_ops_chk_ma_interval=>payment_output( it_rows          = lt_rows
                                                               iv_run_date      = gc-rundate
                                                               iv_run_id        = space
                                                               it_order_methods = VALUE #( )
                                                               iv_with_proposal = abap_false ).
    DATA(lt_on) = zcl_ca_ops_chk_ma_interval=>payment_output( it_rows          = lt_rows
                                                              iv_run_date      = gc-rundate
                                                              iv_run_id        = space
                                                              it_order_methods = VALUE #( )
                                                              iv_with_proposal = abap_true ).

    cl_abap_unit_assert=>assert_equals( act = lt_off[ 1 ]-expected_count exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_on[ 1 ]-expected_count exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_on[ 1 ]-expected_amount exp = '900.00' ).
    cl_abap_unit_assert=>assert_equals( act = lt_on[ 1 ]-observed_amount exp = '650.00' ).
  ENDMETHOD.


  " Fixture MA-05: the runs cannot be read - not evaluated, the check partial, never green
  METHOD unreadable_runs_not_evaluated.
    mo_ma->mt_activities = VALUE #( ( activity( ) ) ).
    mo_source->mv_fail = abap_true.

    DATA(ls_result) = run( ).

    DATA(ls_finding) = of_code( is_result = ls_result iv_code = zif_ca_ops_cash_types=>gc_code-not_evaluated ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-warning ).
    cl_abap_unit_assert=>assert_true( ls_result-partial ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-unevaluated exp = 1 ).
  ENDMETHOD.

ENDCLASS.
