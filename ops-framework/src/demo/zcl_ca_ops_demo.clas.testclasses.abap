*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_demo.clas.testclasses.abap
*& Purpose:
*& Tests of the demo consumer through its public seam RUN( ): findings per
*& job count (information, error = exception, warning), sample mode, the
*& window passed to the job reader (incl. midnight), the run made durable
*& before the alert dispatch, test mode, the authorisation and the abort of
*& a run whose store fails. Every dependency is a local double (data access,
*& store, alert router, authorisation, clock - injected through
*& ZCL_CA_OPS_INJECTOR); no test reads or writes the database.
*& Modification log:
*& 2026-11-10 | Initial version (demo consumer of the operations framework).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_demo_dao.
    DATA ms_counts TYPE zif_ca_ops_demo_types=>ty_counts.
    "! Windows the check asked for (ended: status F and A; planned: status S)
    DATA ms_ended_from TYPE zif_ca_ops_demo_types=>ty_moment.
    DATA ms_ended_to TYPE zif_ca_ops_demo_types=>ty_moment.
    DATA ms_planned_to TYPE zif_ca_ops_demo_types=>ty_moment.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_ca_ops_demo_dao~count_ended.
    ms_ended_from = is_from.
    ms_ended_to   = is_to.
    rv_count = COND #( WHEN iv_status = zif_ca_ops_demo_types=>gc_job_status-aborted THEN ms_counts-aborted
                       ELSE ms_counts-ended ).
  ENDMETHOD.
  METHOD zif_ca_ops_demo_dao~count_planned.
    ms_planned_to = is_to.
    rv_count = ms_counts-late.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_store PARTIALLY IMPLEMENTED.
    CLASS-DATA gv_commits TYPE i.
    DATA mv_started TYPE i.
    DATA mv_test_mode TYPE abap_bool.
    DATA mv_fail_save TYPE abap_bool.
    DATA mt_saved TYPE zif_ca_ops_types=>tt_finding.
    DATA ms_finished TYPE zif_ca_ops_types=>ty_run.
    DATA mt_reconciled TYPE zif_ca_ops_types=>tt_object_key.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_ca_ops_store~start_run.
    mv_started += 1.
    mv_test_mode = iv_test_mode.
    rs_run-area       = iv_area.
    rs_run-variant    = iv_variant.
    rs_run-test_mode  = iv_test_mode.
    rs_run-status     = zif_ca_ops_types=>gc_run_status-running.
    rs_run-started_at = '20261110065900.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_store~save_findings.
    IF mv_fail_save = abap_true.
      " fails once: the abort that follows saves its own finding
      mv_fail_save = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e010(zca_ops) WITH 'ZCA_OPS_FINDING'.
    ENDIF.
    INSERT LINES OF it_findings INTO TABLE mt_saved.
    cs_run-finding_count += lines( it_findings ).
  ENDMETHOD.
  METHOD zif_ca_ops_store~reconcile.
    mt_reconciled = it_object_keys.
  ENDMETHOD.
  METHOD zif_ca_ops_store~finish_run.
    ms_finished = is_run.
  ENDMETHOD.
  METHOD zif_ca_ops_store~commit.
    gv_commits += 1.
  ENDMETHOD.
  METHOD zif_ca_ops_store~rollback.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_alert DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert.
    DATA mv_dispatch_calls TYPE i.
    DATA mv_commits_at_dispatch TYPE i.
    DATA mt_dispatched TYPE zif_ca_ops_types=>tt_finding.
ENDCLASS.

CLASS ltd_alert IMPLEMENTATION.
  METHOD zif_ca_ops_alert~send.
  ENDMETHOD.
  METHOD zif_ca_ops_alert~dispatch.
    mv_dispatch_calls += 1.
    mv_commits_at_dispatch = ltd_store=>gv_commits.
    mt_dispatched = it_findings.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth PARTIALLY IMPLEMENTED.
    DATA mv_allowed TYPE abap_bool VALUE abap_true.
    DATA mv_area TYPE zif_ca_ops_types=>ty_area.
    DATA mv_activity TYPE zif_ca_ops_auth=>ty_activity.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~is_allowed.
    rv_allowed = mv_allowed.
  ENDMETHOD.
  METHOD zif_ca_ops_auth~check.
    mv_area     = iv_area.
    mv_activity = iv_activity.
    IF mv_allowed = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e041(zca_ops) WITH zif_ca_ops_auth=>gc_object iv_activity.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
    DATA mv_today TYPE d VALUE '20261110'.
    DATA mv_time TYPE t VALUE '070000'.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261110070000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = mv_today.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = mv_time.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_demo DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    "! Scenario intent of one test
    TYPES:
      BEGIN OF ty_flags,
        ended      TYPE i,
        aborted    TYPE i,
        late       TYPE i,
        sample     TYPE abap_bool,
        test_mode  TYPE abap_bool,
        denied     TYPE abap_bool,
        fail_save  TYPE abap_bool,
        after_midn TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_store TYPE REF TO ltd_store.
    DATA mo_alert TYPE REF TO ltd_alert.
    DATA mo_auth TYPE REF TO ltd_auth.
    DATA mo_clock TYPE REF TO ltd_clock.

    METHODS setup.
    METHODS teardown.
    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS run_process
      IMPORTING
        is_flags         TYPE ty_flags
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_demo_types=>ty_result
      RAISING
        zcx_ca_ops_error.
    METHODS severity_of
      IMPORTING
        it_findings        TYPE zif_ca_ops_types=>tt_finding
        iv_check_code      TYPE zif_ca_ops_types=>ty_check_code
      RETURNING
        VALUE(rv_severity) TYPE zif_ca_ops_types=>ty_severity.

    METHODS error_finding_is_exception FOR TESTING.
    METHODS only_info_when_all_is_well FOR TESTING.
    METHODS warning_for_late_jobs      FOR TESTING.
    METHODS sample_writes_three        FOR TESTING.
    METHODS window_is_last_24_hours    FOR TESTING.
    METHODS late_cut_wraps_at_midnight FOR TESTING.
    METHODS durable_before_alert       FOR TESTING.
    METHODS test_mode_reaches_store    FOR TESTING.
    METHODS no_authorisation_no_run    FOR TESTING.
    METHODS store_failure_aborts_run   FOR TESTING.
ENDCLASS.


CLASS ltc_demo IMPLEMENTATION.

  METHOD setup.
    mo_dao   = NEW #( ).
    mo_store = NEW #( ).
    mo_alert = NEW #( ).
    mo_auth  = NEW #( ).
    mo_clock = NEW #( ).
    CLEAR ltd_store=>gv_commits.
    zcl_ca_ops_injector=>inject_store( mo_store ).
    zcl_ca_ops_injector=>inject_alert( mo_alert ).
    zcl_ca_ops_injector=>inject_auth( mo_auth ).
    zcl_ca_ops_injector=>inject_clock( mo_clock ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_store, mo_alert, mo_auth, mo_clock.
  ENDMETHOD.


  METHOD configure_scenario.
    mo_dao->ms_counts-ended   = is_flags-ended.
    mo_dao->ms_counts-aborted = is_flags-aborted.
    mo_dao->ms_counts-late    = is_flags-late.
    mo_auth->mv_allowed       = xsdbool( is_flags-denied = abap_false ).
    mo_store->mv_fail_save    = is_flags-fail_save.
    IF is_flags-after_midn = abap_true.
      mo_clock->mv_time = '003000'.
    ENDIF.
  ENDMETHOD.


  METHOD run_process.
    configure_scenario( is_flags ).
    rs_result = NEW zcl_ca_ops_demo( mo_dao )->run( iv_test_mode = is_flags-test_mode
                                                    iv_sample    = is_flags-sample ).
  ENDMETHOD.


  METHOD severity_of.
    READ TABLE it_findings WITH KEY check_code = iv_check_code ASSIGNING FIELD-SYMBOL(<ls_finding>).
    IF sy-subrc = 0.
      rv_severity = <ls_finding>-severity.
    ENDIF.
  ENDMETHOD.


  METHOD error_finding_is_exception.
    DATA ls_flags TYPE ty_flags.
    TRY.
        ls_flags-ended   = 40.
        ls_flags-aborted = 2.
        DATA(ls_result) = run_process( ls_flags ).
        cl_abap_unit_assert=>assert_equals(
          act = severity_of( it_findings = ls_result-findings iv_check_code = zif_ca_ops_demo_types=>gc_check-aborted )
          exp = zif_ca_ops_types=>gc_severity-error
          msg = 'Cancelled jobs are an error finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ check_code = zif_ca_ops_demo_types=>gc_check-aborted ]-action
                                            exp = zif_ca_ops_types=>gc_action-exception
                                            msg = 'The error is an exception for its owner' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->ms_finished-rag exp = zif_ca_ops_types=>gc_rag-red
                                            msg = 'An error makes the run red' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->ms_finished-status
                                            exp = zif_ca_ops_types=>gc_run_status-error
                                            msg = 'Run status error' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_store->mt_saved ) exp = 2
                                            msg = 'Information and error are saved' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD only_info_when_all_is_well.
    DATA ls_flags TYPE ty_flags.
    TRY.
        ls_flags-ended = 12.
        DATA(ls_result) = run_process( ls_flags ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1
                                            msg = 'Only the information finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-severity
                                            exp = zif_ca_ops_types=>gc_severity-info
                                            msg = 'Information severity' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->ms_finished-rag exp = zif_ca_ops_types=>gc_rag-green
                                            msg = 'Green run' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->ms_finished-passed_items exp = 12
                                            msg = 'Jobs ended are the passed items' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mt_reconciled
                                            exp = VALUE zif_ca_ops_types=>tt_object_key( ( zif_ca_ops_demo_types=>gc_object_key ) )
                                            msg = 'Earlier exceptions of the jobs object are reconciled' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD warning_for_late_jobs.
    DATA ls_flags TYPE ty_flags.
    TRY.
        ls_flags-late = 1.
        DATA(ls_result) = run_process( ls_flags ).
        cl_abap_unit_assert=>assert_equals(
          act = severity_of( it_findings = ls_result-findings iv_check_code = zif_ca_ops_demo_types=>gc_check-late )
          exp = zif_ca_ops_types=>gc_severity-warning
          msg = 'Late released jobs are a warning' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->ms_finished-rag exp = zif_ca_ops_types=>gc_rag-amber
                                            msg = 'A warning makes the run amber' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD sample_writes_three.
    DATA ls_flags TYPE ty_flags.
    TRY.
        ls_flags-sample = abap_true.
        DATA(ls_result) = run_process( ls_flags ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 3
                                            msg = 'Sample mode writes information, error and warning' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-counts-aborted exp = 0
                                            msg = 'The counts stay the real ones' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD window_is_last_24_hours.
    DATA ls_flags TYPE ty_flags.
    TRY.
        run_process( ls_flags ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_ended_from-date exp = '20261109'
                                            msg = 'The window starts yesterday' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_ended_from-time exp = '070000'
                                            msg = 'at the same time' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_ended_to-date exp = '20261110'
                                            msg = 'and ends today' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_planned_to-time exp = '060000'
                                            msg = 'A released job is late 60 minutes after its planned start' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD late_cut_wraps_at_midnight.
    DATA ls_flags TYPE ty_flags.
    TRY.
        ls_flags-after_midn = abap_true.
        run_process( ls_flags ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_planned_to-date exp = '20261109'
                                            msg = 'Half past midnight: the cut is yesterday' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_planned_to-time exp = '233000'
                                            msg = 'at 23:30' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD durable_before_alert.
    DATA ls_flags TYPE ty_flags.
    TRY.
        ls_flags-aborted = 1.
        run_process( ls_flags ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatch_calls exp = 1
                                            msg = 'The alert rules are applied once' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_commits_at_dispatch exp = 2
                                            msg = 'Run header and findings are committed before the dispatch' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_alert->mt_dispatched ) exp = 2
                                            msg = 'The dispatch gets the findings of the run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD test_mode_reaches_store.
    DATA ls_flags TYPE ty_flags.
    TRY.
        ls_flags-test_mode = abap_true.
        DATA(ls_result) = run_process( ls_flags ).
        cl_abap_unit_assert=>assert_true( act = mo_store->mv_test_mode
                                          msg = 'The store is told test mode (it persists nothing)' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-run-test_mode
                                          msg = 'The run is a test run (the router sends nothing)' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-run-area exp = zif_ca_ops_demo_types=>gc_area
                                            msg = 'Area CA_DEMO' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD no_authorisation_no_run.
    DATA ls_flags TYPE ty_flags.
    ls_flags-denied = abap_true.
    TRY.
        run_process( ls_flags ).
        cl_abap_unit_assert=>fail( msg = 'Without authorisation the run must be refused' ).
      CATCH zcx_ca_ops_error ##NO_HANDLER.
        " expected
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_store->mv_started exp = 0
                                        msg = 'No run is started' ).
    cl_abap_unit_assert=>assert_equals( act = mo_auth->mv_activity exp = zif_ca_ops_auth=>gc_activity-execute
                                        msg = 'Activity execute (16) is checked' ).
    cl_abap_unit_assert=>assert_equals( act = mo_auth->mv_area exp = zif_ca_ops_demo_types=>gc_area
                                        msg = 'for area CA_DEMO' ).
  ENDMETHOD.


  METHOD store_failure_aborts_run.
    DATA ls_flags TYPE ty_flags.
    ls_flags-aborted   = 1.
    ls_flags-fail_save = abap_true.
    TRY.
        run_process( ls_flags ).
        cl_abap_unit_assert=>fail( msg = 'The error is raised again to the caller' ).
      CATCH zcx_ca_ops_error ##NO_HANDLER.
        " expected
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_store->ms_finished-status
                                        exp = zif_ca_ops_types=>gc_run_status-aborted
                                        msg = 'The run is closed as aborted, never left running' ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( mo_store->mt_saved[ check_code = zcl_ca_ops_run_guard=>gc_check_aborted ] ) )
      msg = 'RUN_ABORTED is saved' ).
  ENDMETHOD.

ENDCLASS.
