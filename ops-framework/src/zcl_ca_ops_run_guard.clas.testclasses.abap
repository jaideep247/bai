*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_run_guard.clas.testclasses.abap
*& Purpose:
*& Tests of the refused run: a second run while the lock is held becomes an
*& aborted, red run with one RUN_LOCKED finding that is alerted once and is
*& recognisable by the reports. Written before the class. Does not prove live
*& SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (run lock).
*& 2026-11-06 | Modern-syntax sweep: no trailing RETURN.
*& 2026-11-10 | Refusal saved in its own LUW and ALERT_FAILED on a failing dispatch; abort( ): rollback,
*&            | aborted run with RUN_ABORTED (trace, error class), durable before the ON_ABORT dispatch.
*& 2026-11-10 | Moved from ZCL_CD_OPS_RUN_GUARD to the reusable framework ZCA_OPS (test include).
*&---------------------------------------------------------------------*
CLASS ltd_alert DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert.
    DATA mv_dispatch_calls TYPE i.
    DATA mt_dispatched TYPE zif_ca_ops_types=>tt_finding.
    DATA ms_run TYPE zif_ca_ops_types=>ty_run.
    DATA mv_fail TYPE abap_bool.
    "! Store commits counted when the dispatch starts (durable before notified)
    DATA mv_commits_at_dispatch TYPE i.
ENDCLASS.


CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_store PARTIALLY IMPLEMENTED.
    CLASS-DATA gv_commits TYPE i.
    DATA mv_rollbacks TYPE i.
    DATA mt_saved TYPE zif_ca_ops_types=>tt_finding.
    DATA ms_finished TYPE zif_ca_ops_types=>ty_run.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_ca_ops_store~save_findings.
    INSERT LINES OF it_findings INTO TABLE mt_saved.
    cs_run-finding_count += lines( it_findings ).
  ENDMETHOD.
  METHOD zif_ca_ops_store~finish_run.
    ms_finished = is_run.
  ENDMETHOD.
  METHOD zif_ca_ops_store~commit.
    gv_commits += 1.
  ENDMETHOD.
  METHOD zif_ca_ops_store~rollback.
    mv_rollbacks += 1.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_alert IMPLEMENTATION.
  METHOD zif_ca_ops_alert~send.
  ENDMETHOD.
  METHOD zif_ca_ops_alert~dispatch.
    mv_dispatch_calls += 1.
    mt_dispatched = it_findings.
    ms_run = is_run.
    mv_commits_at_dispatch = ltd_store=>gv_commits.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e020(zca_ops) WITH 'TEST'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261106070000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261106'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '070000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_run_guard DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_holder TYPE syuname VALUE 'BATCH_OTHER'.
    CONSTANTS gc_variant TYPE zif_ca_ops_types=>ty_variant VALUE 'DAILY'.
    CONSTANTS gc_started TYPE timestampl VALUE '20261106065900.0000000'.
    DATA mo_alert TYPE REF TO ltd_alert.
    DATA mo_store TYPE REF TO ltd_store.
    DATA ms_run TYPE zif_ca_ops_types=>ty_run.

    METHODS setup.
    METHODS teardown.
    METHODS refuse
      RETURNING
        VALUE(rs_refusal) TYPE zcl_ca_ops_run_guard=>ty_refusal.

    METHODS refusal_is_aborted_red_run FOR TESTING.
    METHODS refusal_is_alerted_once    FOR TESTING.
    METHODS refusal_is_recognised      FOR TESTING.
    METHODS normal_run_not_refused     FOR TESTING.
    METHODS refusal_is_saved           FOR TESTING.
    METHODS refusal_alert_failure_kept FOR TESTING.
    METHODS abort_closes_run_aborted   FOR TESTING.
    METHODS abort_keeps_trace_and_class FOR TESTING.
    METHODS abort_durable_before_alert FOR TESTING.
    METHODS abort_alert_failure_kept   FOR TESTING.

    METHODS abort_run
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.
ENDCLASS.


CLASS ltc_run_guard IMPLEMENTATION.

  METHOD setup.
    mo_alert = NEW #( ).
    mo_store = NEW #( ).
    CLEAR ltd_store=>gv_commits.
    zcl_ca_ops_injector=>inject_alert( mo_alert ).
    zcl_ca_ops_injector=>inject_store( mo_store ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    CLEAR ms_run.
    ms_run-area    = zcl_ca_ops_param_seed=>gc_test_area-second.
    ms_run-variant    = gc_variant.
    ms_run-status     = zif_ca_ops_types=>gc_run_status-running.
    ms_run-started_at = gc_started.
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
    CLEAR: mo_alert, mo_store.
  ENDMETHOD.


  METHOD refuse.
    rs_refusal = zcl_ca_ops_run_guard=>refuse( iv_area  = zcl_ca_ops_param_seed=>gc_test_area-first
                                               iv_variant = gc_variant
                                               iv_holder  = gc_holder ).
  ENDMETHOD.


  METHOD abort_run.
    TRY.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e010(zca_ops) WITH 'ZT_TABLE'
          EXPORTING
            previous = NEW cx_sy_open_sql_db( ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        rt_findings = zcl_ca_ops_run_guard=>abort( EXPORTING ix_error = lx_error
                                                   CHANGING  cs_run   = ms_run ).
    ENDTRY.
  ENDMETHOD.


  " B11: the refusal's alert decision log is durable - the refusal owns its small LUW
  METHOD refusal_is_saved.
    TRY.
        refuse( ).
        cl_abap_unit_assert=>assert_equals( act = ltd_store=>gv_commits exp = 1
                                            msg = 'The refusal is made durable once, after the dispatch' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_commits_at_dispatch exp = 0
                                            msg = 'The dispatch runs before that' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " B11: a dispatch that fails is a finding of the refusal, never swallowed
  METHOD refusal_alert_failure_kept.
    TRY.
        mo_alert->mv_fail = abap_true.
        DATA(ls_refusal) = refuse( ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_refusal-findings[ check_code = zcl_ca_ops_run_guard=>gc_check_alert_failed ] ) )
          msg = 'ALERT_FAILED is part of the refusal' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " B9: an aborted run is rolled back and closed red with status A - never left running
  METHOD abort_closes_run_aborted.
    TRY.
        abort_run( ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_rollbacks exp = 1
                                            msg = 'The open LUW is rolled back first' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->ms_finished-status
                                            exp = zif_ca_ops_types=>gc_run_status-aborted
                                            msg = 'The run is closed as aborted' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->ms_finished-rag exp = zif_ca_ops_types=>gc_rag-red
                                            msg = 'An aborted run is red' ).
        cl_abap_unit_assert=>assert_not_initial( act = mo_store->ms_finished-message
                                                 msg = 'The run message names the error' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " B10 / B12: the RUN_ABORTED finding keeps the chain and its error class
  METHOD abort_keeps_trace_and_class.
    TRY.
        abort_run( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_store->mt_saved ) exp = 1
                                            msg = 'One RUN_ABORTED finding is saved' ).
        DATA(ls_saved) = mo_store->mt_saved[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_saved-check_code exp = zcl_ca_ops_run_guard=>gc_check_aborted
                                            msg = 'Check code RUN_ABORTED' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( ls_saved-details CS `CX_SY_OPEN_SQL_DB` )
                                          msg = 'The previous exception is in the trace' ).
        cl_abap_unit_assert=>assert_equals( act = ls_saved-error_class
                                            exp = zif_ca_ops_types=>gc_error_class-transient
                                            msg = 'A database error is TRANSIENT' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " B9: durable before notified - the ON_ABORT rules see the saved aborted run
  METHOD abort_durable_before_alert.
    TRY.
        abort_run( ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_commits_at_dispatch exp = 1
                                            msg = 'Saved before the dispatch' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->ms_run-status
                                            exp = zif_ca_ops_types=>gc_run_status-aborted
                                            msg = 'The router sees an aborted run (ON_ABORT)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " B11: a failing dispatch after an abort is saved as ALERT_FAILED
  METHOD abort_alert_failure_kept.
    TRY.
        mo_alert->mv_fail = abap_true.
        DATA(lt_findings) = abort_run( ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( mo_store->mt_saved[ check_code = zcl_ca_ops_run_guard=>gc_check_alert_failed ] ) )
          msg = 'ALERT_FAILED is saved' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_findings ) exp = 2
                                            msg = 'RUN_ABORTED and ALERT_FAILED are returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a refused run is visible as an aborted, red run - never as a green no-op
  METHOD refusal_is_aborted_red_run.
    TRY.
        DATA(ls_refusal) = refuse( ).
        cl_abap_unit_assert=>assert_equals( act = ls_refusal-run-status exp = zif_ca_ops_types=>gc_run_status-aborted
                                            msg = 'A refused run must be aborted' ).
        cl_abap_unit_assert=>assert_equals( act = ls_refusal-run-rag exp = zif_ca_ops_types=>gc_rag-red
                                            msg = 'A refused run must be red' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_refusal-findings ) exp = 1
                                            msg = 'Exactly one RUN_LOCKED finding is expected' ).
        cl_abap_unit_assert=>assert_equals( act = ls_refusal-findings[ 1 ]-check_code
                                            exp = zcl_ca_ops_run_guard=>gc_check_code
                                            msg = 'The finding must be RUN_LOCKED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: whoever runs the job is told once, through the alert router
  METHOD refusal_is_alerted_once.
    TRY.
        refuse( ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatch_calls exp = 1
                                            msg = 'The refusal must be dispatched once' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mt_dispatched[ 1 ]-check_code
                                            exp = zcl_ca_ops_run_guard=>gc_check_code
                                            msg = 'RUN_LOCKED must reach the alert router' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: reports recognise a refusal from the result's findings
  METHOD refusal_is_recognised.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_run_guard=>was_refused( refuse( )-findings )
                                          msg = 'The refusal must be recognised' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an ordinary result is not mistaken for a refusal
  METHOD normal_run_not_refused.
    DATA lt_findings TYPE zif_ca_ops_types=>tt_finding.
    DATA ls_finding TYPE zif_ca_ops_types=>ty_finding.
    ls_finding-check_code = 'PLUGIN_ERROR'.
    INSERT ls_finding INTO TABLE lt_findings.
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_run_guard=>was_refused( lt_findings )
                                       msg = 'Other findings are not a refusal' ).
  ENDMETHOD.

ENDCLASS.
