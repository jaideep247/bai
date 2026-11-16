*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_xrun.clas.testclasses.abap
*& Purpose:
*& Fixtures of the expected-run check (config/expected_runs/fixtures.json,
*& XRUN-*) through ZIF_CA_OPS_CHECK=>RUN: the scheduler planned a run and
*& SAP has no job - never started, with its deadline, owner, stage and the
*& evidence of the scheduler record and of the missing SAP job; a run held
*& back by an unfinished predecessor; a scheduler source older than its
*& limit makes the evaluation STALE (notice); a holiday of the calendar is
*& HOLIDAY, not OK and not missing; a source that cannot be read is not
*& evaluated (the check partial); the scheduler ran it but SAP never had a
*& job (failed before SAP); a source class that does not exist is a
*& configuration notice. Doubles: expected-run source (plug-in), job
*& monitor data access, owner, clock, parameters in memory.
*& Modification log:
*& 2026-11-16 | Initial version (build P: expected runs from the scheduler).
*&---------------------------------------------------------------------*
CLASS ltd_xrun_source DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_expected_run_src.
    DATA ms_plan TYPE zif_ca_ops_xrun_types=>ty_plan.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.

CLASS ltd_xrun_source IMPLEMENTATION.
  METHOD zif_ca_ops_expected_run_src~id.
    rv_id = 'ZT_EXPORT'.
  ENDMETHOD.
  METHOD zif_ca_ops_expected_run_src~read.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e607(zca_ops) WITH 'ZT_EXPORT' 'file missing'.
    ENDIF.
    rs_plan = ms_plan.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_xrun_jobs DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_dao PARTIALLY IMPLEMENTED.
    DATA mt_running TYPE zif_ca_ops_job_types=>tt_job.
ENDCLASS.

CLASS ltd_xrun_jobs IMPLEMENTATION.
  METHOD zif_ca_ops_job_dao~jobs_running.
    rt_jobs = mt_running.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~waiting_jobs.
    CLEAR rt_jobs.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~scheduler_jobs.
    CLEAR rt_sched.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_xrun_owner DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_owner.
ENDCLASS.

CLASS ltd_xrun_owner IMPLEMENTATION.
  METHOD zif_ca_ops_owner~resolve.
    rs_owner = VALUE #( user = 'ZT_OWNER' team = 'ZT_TEAM' source = zif_ca_ops_exc_contract=>gc_resp_source-control
                        ref = 'ZT_CTL' ).
  ENDMETHOD.
ENDCLASS.


CLASS ltd_xrun_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_xrun_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261116090000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261116'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '090000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_xrun DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area   TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        source TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZT_XRUN_SRC',
        today  TYPE d VALUE '20261116',
        now    TYPE timestampl VALUE '20261116090000.0000000',
        folder TYPE zif_ca_ops_job_types=>ty_sched_folder VALUE 'ZT_FOLDER',
        prep   TYPE zif_ca_ops_job_types=>ty_sched_job VALUE 'ZT_PAY_PREP',
        payrun TYPE zif_ca_ops_job_types=>ty_sched_job VALUE 'ZT_PAY_RUN',
      END OF gc.

    DATA mo_source TYPE REF TO ltd_xrun_source.
    DATA mo_jobs TYPE REF TO ltd_xrun_jobs.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.
    METHODS planned
      IMPORTING
        iv_job        TYPE zif_ca_ops_job_types=>ty_sched_job DEFAULT gc-prep
        iv_time       TYPE t DEFAULT '060000'
        iv_pattern    TYPE zif_ca_ops_types=>ty_object_key DEFAULT 'ZT_PAYPREP.*'
        iv_state      TYPE zif_ca_ops_xrun_types=>ty_sched_state OPTIONAL
      RETURNING
        VALUE(rs_run) TYPE zif_ca_ops_xrun_types=>ty_expected.
    METHODS of_code
      IMPORTING
        is_result         TYPE zif_ca_ops_chk_types=>ty_result
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    METHODS never_started_no_sap_job     FOR TESTING RAISING zcx_ca_ops_error.
    METHODS predecessor_not_finished     FOR TESTING RAISING zcx_ca_ops_error.
    METHODS stale_source_is_stale        FOR TESTING RAISING zcx_ca_ops_error.
    METHODS holiday_not_expected         FOR TESTING RAISING zcx_ca_ops_error.
    METHODS unreadable_source_not_eval   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS failed_before_sap            FOR TESTING RAISING zcx_ca_ops_error.
    METHODS unknown_source_class         FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_chk_xrun IMPLEMENTATION.

  METHOD setup.
    mo_source = NEW #( ).
    mo_jobs   = NEW #( ).
    mo_seed   = NEW #( ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_xrun_clock( ) ).
    zcl_ca_ops_injector=>inject_owner( NEW ltd_xrun_owner( ) ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc-source io_instance = mo_source ).
    mo_seed->set( iv_name = zif_ca_ops_xrun_types=>gc_param-sources iv_value = gc-source ).
    mo_seed->set( iv_name = zif_ca_ops_xrun_types=>gc_param-lookback iv_value = '0' ).
    mo_source->ms_plan-newest_at = gc-now.
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD run.
    rs_result = NEW zcl_ca_ops_chk_xrun( mo_jobs )->zif_ca_ops_check~run(
                  is_check   = VALUE #( area = gc-area check_id = 'EXPECTED_RUNS' )
                  is_context = VALUE #( area = gc-area today = gc-today now = gc-now ) ).
  ENDMETHOD.


  METHOD planned.
    rs_run = VALUE #( run_id       = |R-{ iv_job }|
                      sched_folder = gc-folder
                      sched_job    = iv_job
                      sap_pattern  = iv_pattern
                      plan_date    = gc-today
                      plan_time    = iv_time
                      sched_state  = iv_state ).
  ENDMETHOD.


  METHOD of_code.
    READ TABLE is_result-findings INTO rs_finding WITH KEY check_code = iv_code.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = |{ iv_code } expected| ).
  ENDMETHOD.


  " Fixture XRUN-01: the scheduler planned ZT_PAY_PREP for 06:00 (late after 30 minutes); at 09:00 SAP has no job
  " of its names - one exception with deadline 06:30, owner, stage SCHEDULER and the scheduler / SAP evidence
  METHOD never_started_no_sap_job.
    mo_source->ms_plan-runs = VALUE #( ( planned( ) ) ).

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 ).
    DATA(ls_finding) = of_code( is_result = ls_result iv_code = zif_ca_ops_xrun_types=>gc_code-never_started ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-error ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-stage exp = zif_ca_ops_xrun_types=>gc_stage-scheduler ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = 'ZT_PAY_PREP/202611160600' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-deadline_at exp = '20261116063000.0000000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-item_count exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-unknown_count exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-resp_user exp = 'ZT_OWNER' ).
    cl_abap_unit_assert=>assert_initial( zcl_ca_ops_exc_contract=>missing( ls_finding ) ).
    DATA(lt_evidence) = VALUE zif_ca_ops_exc_contract=>tt_evidence( FOR ls IN ls_result-evidence
                                                                    WHERE ( evid_key = ls_finding-evid_key ) ( ls ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_evidence ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_evidence[ 1 ]-kind exp = zif_ca_ops_exc_contract=>gc_kind-scheduler ).
    cl_abap_unit_assert=>assert_equals( act = lt_evidence[ 2 ]-quality
                                        exp = zif_ca_ops_exc_contract=>gc_quality-unmatched ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-expected exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-observed exp = 0 ).
  ENDMETHOD.


  " Fixture XRUN-02: ZT_PAY_PREP started 06:01 and was cancelled; ZT_PAY_RUN (07:00, after ZT_PAY_PREP) never
  " started - it waits for its predecessor; the evidence links both SAP jobs
  METHOD predecessor_not_finished.
    DATA(ls_payrun) = planned( iv_job = gc-payrun iv_time = '070000' iv_pattern = 'ZT_PAYRUN.*' ).
    ls_payrun-pred_folder = gc-folder.
    ls_payrun-pred_job    = gc-prep.
    mo_source->ms_plan-runs = VALUE #( ( planned( ) ) ( ls_payrun ) ).
    mo_jobs->mt_running = VALUE #( ( jobname = 'ZT_PAYPREP_DAILY' jobcount = '06010001' status = 'A'
                                     strtdate = gc-today strttime = '060100' enddate = gc-today endtime = '060400' ) ).

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 ).
    DATA(ls_finding) = of_code( is_result = ls_result iv_code = zif_ca_ops_xrun_types=>gc_code-pred_open ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-stage exp = zif_ca_ops_xrun_types=>gc_stage-predecessor ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = 'ZT_PAY_RUN/202611160700' ).
    cl_abap_unit_assert=>assert_initial( zcl_ca_ops_exc_contract=>missing( ls_finding ) ).
    DATA(lt_jobs) = VALUE zif_ca_ops_exc_contract=>tt_evidence( FOR ls IN ls_result-evidence
                                                                WHERE ( evid_key    = ls_finding-evid_key
                                                                    AND link_object = 'S4_BACKGROUND_JOB' ) ( ls ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_jobs ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_jobs[ 1 ]-link_value exp = 'JOBNAME=ZT_PAYPREP_DAILY;JOBCOUNT=06010001' ).
  ENDMETHOD.


  " Fixture XRUN-03: the scheduler export is from 07:00, its limit 60 minutes, now 09:00: a stale source - a notice
  " and the evaluation STALE; its run of 10:00 is not due yet
  METHOD stale_source_is_stale.
    mo_source->ms_plan = VALUE #( runs      = VALUE #( ( planned( iv_time = '100000' ) ) )
                                  newest_at = '20261116070000.0000000'
                                  stale_min = 60 ).

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 ).
    DATA(ls_finding) = of_code( is_result = ls_result iv_code = zif_ca_ops_xrun_types=>gc_code-source_stale ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-action exp = zif_ca_ops_types=>gc_action-notify ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-result_class exp = zif_ca_ops_eval_types=>gc_state-stale ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-sources[ 1 ]-source_id exp = 'ZT_EXPORT' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-sources[ 1 ]-stale_min exp = 60 ).
  ENDMETHOD.


  " Fixture XRUN-04: today is a holiday of the row's calendar - no run expected: no finding, evaluation HOLIDAY
  METHOD holiday_not_expected.
    mo_source->ms_plan-not_expected = VALUE #( ( sched_folder = gc-folder sched_job = gc-prep plan_date = gc-today
                                                 calendar_id = 'ZT' ) ).

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_initial( ls_result-findings ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-result_class exp = zif_ca_ops_eval_types=>gc_state-holiday ).
    cl_abap_unit_assert=>assert_false( ls_result-partial ).
  ENDMETHOD.


  " Fixture XRUN-05: the scheduler export cannot be read - not evaluated (never "nothing expected"), partial
  METHOD unreadable_source_not_eval.
    mo_source->mv_fail = abap_true.

    DATA(ls_result) = run( ).

    DATA(ls_finding) = of_code( is_result = ls_result iv_code = zif_ca_ops_xrun_types=>gc_code-source_failed ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-warning ).
    cl_abap_unit_assert=>assert_true( ls_result-partial ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-unevaluated exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-evaluated exp = 0 ).
  ENDMETHOD.


  " Fixture XRUN-06: the scheduler ended the run not OK at 06:05 and SAP never had a job - stage HANDOVER
  METHOD failed_before_sap.
    DATA(ls_run) = planned( iv_state = zif_ca_ops_xrun_types=>gc_state-ended_not_ok ).
    ls_run-state_at = '20261116060500.0000000'.
    mo_source->ms_plan-runs = VALUE #( ( ls_run ) ).

    DATA(ls_result) = run( ).

    DATA(ls_finding) = of_code( is_result = ls_result iv_code = zif_ca_ops_xrun_types=>gc_code-never_started ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-stage exp = zif_ca_ops_xrun_types=>gc_stage-handover ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-evidence[ 1 ]-occurred_at exp = ls_run-state_at ).
  ENDMETHOD.


  " Rule: a source class that does not exist is a configuration notice, the evaluation not complete
  METHOD unknown_source_class.
    mo_seed->set( iv_name = zif_ca_ops_xrun_types=>gc_param-sources iv_value = 'ZCL_ZT_NOT_THERE' ).

    DATA(ls_result) = run( ).

    DATA(ls_finding) = of_code( is_result = ls_result iv_code = zif_ca_ops_xrun_types=>gc_code-config_invalid ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = 'ZCL_ZT_NOT_THERE' ).
    cl_abap_unit_assert=>assert_true( ls_result-partial ).
  ENDMETHOD.

ENDCLASS.
