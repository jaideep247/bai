*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_check_runner.clas.testclasses.abap
*& Purpose:
*& Tests of the generic check runner through its public seam RUN( ): the
*& identity stamped on every finding (GROUP1 process, GROUP2 check), a check
*& that raises (CHECK_FAILED, run continues, not auto-resolved), auto-resolve
*& of complete checks only, no registered check, the run lock (refused,
*& nothing started), the authorisation (041), durable before notified and a
*& failed alert dispatch (ALERT_FAILED). Every dependency is a local double
*& injected through ZCL_CA_OPS_INJECTOR (store, alert router, authorisation,
*& lock, clock, check registry, the check plug-ins); no test reads or writes
*& the database. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework).
*&---------------------------------------------------------------------*
CLASS ltd_check DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.
    DATA mt_findings TYPE zif_ca_ops_types=>tt_finding.
    DATA mv_fail TYPE abap_bool.
    DATA mv_partial TYPE abap_bool.
    DATA mv_calls TYPE i.
    DATA ms_context TYPE zif_ca_ops_chk_types=>ty_context.
ENDCLASS.

CLASS ltd_check IMPLEMENTATION.
  METHOD zif_ca_ops_check~run.
    mv_calls += 1.
    ms_context = is_context.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e092(zca_ops) WITH is_check-check_id is_check-area.
    ENDIF.
    rs_result-findings   = mt_findings.
    rs_result-item_count = 1.
    rs_result-partial    = mv_partial.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check_dao PARTIALLY IMPLEMENTED.
    DATA mt_checks TYPE zif_ca_ops_chk_types=>tt_check.
    DATA mv_group TYPE zif_ca_ops_chk_types=>ty_sched_group.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_ca_ops_check_dao~get_checks.
    mv_group = iv_sched_group.
    rt_checks = mt_checks.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_store PARTIALLY IMPLEMENTED.
    CLASS-DATA gv_commits TYPE i.
    DATA mv_started TYPE i.
    DATA mv_variant TYPE zif_ca_ops_types=>ty_variant.
    DATA mt_saved TYPE zif_ca_ops_types=>tt_finding.
    DATA mt_groups TYPE zif_ca_ops_types=>tt_group.
    DATA mv_reconciled TYPE abap_bool.
    DATA ms_finished TYPE zif_ca_ops_types=>ty_run.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_ca_ops_store~start_run.
    mv_started += 1.
    mv_variant = iv_variant.
    rs_run-area       = iv_area.
    rs_run-variant    = iv_variant.
    rs_run-test_mode  = iv_test_mode.
    rs_run-status     = zif_ca_ops_types=>gc_run_status-running.
    rs_run-started_at = '20261110065900.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_store~save_findings.
    INSERT LINES OF it_findings INTO TABLE mt_saved.
    cs_run-finding_count += lines( it_findings ).
  ENDMETHOD.
  METHOD zif_ca_ops_store~reconcile.
    mv_reconciled = abap_true.
    mt_groups = it_groups.
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
    DATA mv_fail TYPE abap_bool.
    DATA mv_dispatch_calls TYPE i.
    DATA mv_commits_at_dispatch TYPE i.
ENDCLASS.

CLASS ltd_alert IMPLEMENTATION.
  METHOD zif_ca_ops_alert~send.
  ENDMETHOD.
  METHOD zif_ca_ops_alert~dispatch.
    mv_dispatch_calls += 1.
    mv_commits_at_dispatch = ltd_store=>gv_commits.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e007(zca_ops) WITH 'EMAIL'.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth PARTIALLY IMPLEMENTED.
    DATA mv_allowed TYPE abap_bool VALUE abap_true.
    DATA mv_activity TYPE zif_ca_ops_auth=>ty_activity.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~is_allowed.
    rv_allowed = mv_allowed.
  ENDMETHOD.
  METHOD zif_ca_ops_auth~check.
    mv_activity = iv_activity.
    IF mv_allowed = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e041(zca_ops) WITH zif_ca_ops_auth=>gc_object iv_activity.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_lock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_lock.
    DATA mv_held_by TYPE syuname.
    DATA mv_released TYPE i.
ENDCLASS.

CLASS ltd_lock IMPLEMENTATION.
  METHOD zif_ca_ops_lock~acquire.
    ev_holder = mv_held_by.
    rv_acquired = xsdbool( mv_held_by IS INITIAL ).
  ENDMETHOD.
  METHOD zif_ca_ops_lock~release.
    mv_released += 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261110070000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261110'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '070000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_runner DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        group     TYPE zif_ca_ops_chk_types=>ty_sched_group VALUE 'DAILY',
        process   TYPE zif_ca_ops_chk_types=>ty_process_id VALUE 'ZT_PROCESS',
        check_ok  TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_CHECK_OK',
        check_bad TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_CHECK_BAD',
        class_ok  TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_ZT_CHECK_OK',
        class_bad TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_ZT_CHECK_BAD',
        object    TYPE zif_ca_ops_types=>ty_object_key VALUE 'REQ-1',
        holder    TYPE syuname VALUE 'OTHER_USER',
      END OF gc.

    TYPES:
      BEGIN OF ty_flags,
        bad_check    TYPE abap_bool,
        no_checks    TYPE abap_bool,
        lock_held    TYPE abap_bool,
        not_allowed  TYPE abap_bool,
        alert_fails  TYPE abap_bool,
        partial      TYPE abap_bool,
      END OF ty_flags.

    DATA mo_ok TYPE REF TO ltd_check.
    DATA mo_bad TYPE REF TO ltd_check.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_store TYPE REF TO ltd_store.
    DATA mo_alert TYPE REF TO ltd_alert.
    DATA mo_auth TYPE REF TO ltd_auth.
    DATA mo_lock TYPE REF TO ltd_lock.

    METHODS setup.
    METHODS teardown.
    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_run_result
      RAISING
        zcx_ca_ops_error.

    METHODS identity_stamped_on_findings FOR TESTING.
    METHODS failed_check_is_recorded     FOR TESTING.
    METHODS only_complete_checks_resolve FOR TESTING.
    METHODS partial_check_not_resolved   FOR TESTING.
    METHODS no_registered_check_is_error FOR TESTING.
    METHODS held_lock_refuses_run        FOR TESTING.
    METHODS missing_authority_raises     FOR TESTING.
    METHODS durable_before_notified      FOR TESTING.
    METHODS failed_alert_is_recorded     FOR TESTING.
ENDCLASS.


CLASS ltc_runner IMPLEMENTATION.

  METHOD setup.
    ltd_store=>gv_commits = 0.
    mo_ok    = NEW #( ).
    mo_bad   = NEW #( ).
    mo_dao   = NEW #( ).
    mo_store = NEW #( ).
    mo_alert = NEW #( ).
    mo_auth  = NEW #( ).
    mo_lock  = NEW #( ).
    zcl_ca_ops_injector=>inject_check_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_store( mo_store ).
    zcl_ca_ops_injector=>inject_alert( mo_alert ).
    zcl_ca_ops_injector=>inject_auth( mo_auth ).
    zcl_ca_ops_injector=>inject_lock( mo_lock ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc-class_ok io_instance = mo_ok ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc-class_bad io_instance = mo_bad ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_finding TYPE zif_ca_ops_types=>ty_finding.
    ls_finding-object_key = gc-object.
    ls_finding-check_code = zif_ca_ops_chk_types=>gc_code-agg_count.
    ls_finding-severity   = zif_ca_ops_types=>gc_severity-error.
    INSERT ls_finding INTO TABLE mo_ok->mt_findings.
    mo_ok->mv_partial = is_flags-partial.
    mo_bad->mv_fail = abap_true.
    IF is_flags-no_checks = abap_false.
      INSERT VALUE #( area = gc-area check_id = gc-check_ok process_id = gc-process class_name = gc-class_ok
                      sched_group = gc-group active = abap_true ) INTO TABLE mo_dao->mt_checks.
    ENDIF.
    IF is_flags-bad_check = abap_true.
      INSERT VALUE #( area = gc-area check_id = gc-check_bad process_id = gc-process class_name = gc-class_bad
                      sched_group = gc-group active = abap_true ) INTO TABLE mo_dao->mt_checks.
    ENDIF.
    mo_lock->mv_held_by = COND #( WHEN is_flags-lock_held = abap_true THEN gc-holder ).
    mo_auth->mv_allowed = xsdbool( is_flags-not_allowed = abap_false ).
    mo_alert->mv_fail = is_flags-alert_fails.
  ENDMETHOD.


  METHOD run.
    rs_result = NEW zcl_ca_ops_check_runner( )->run( iv_area        = gc-area
                                                     iv_sched_group = gc-group
                                                     iv_test_mode   = abap_false ).
  ENDMETHOD.


  " Rule: every finding of a check names its process (GROUP1) and check (GROUP2); the variant is the group
  METHOD identity_stamped_on_findings.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_store->mt_saved ) exp = 1 msg = 'One finding stored' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mt_saved[ 1 ]-group1 exp = gc-process msg = 'GROUP1 = process' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mt_saved[ 1 ]-group2 exp = gc-check_ok msg = 'GROUP2 = check' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mt_saved[ 1 ]-action exp = zif_ca_ops_types=>gc_action-exception
                                            msg = 'An error without action becomes an exception' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_variant exp = CONV zif_ca_ops_types=>ty_variant( gc-group )
                                            msg = 'Run variant = schedule group' ).
        cl_abap_unit_assert=>assert_equals( act = mo_ok->ms_context-today exp = '20261110' msg = 'Today from the clock' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-check_count exp = 1 msg = 'One check run' ).
        cl_abap_unit_assert=>assert_equals( act = mo_lock->mv_released exp = 1 msg = 'Lock released' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a check that raises is one CHECK_FAILED finding; the next check still runs
  METHOD failed_check_is_recorded.
    TRY.
        configure_scenario( VALUE #( bad_check = abap_true ) ).
        run( ).
        DATA(ls_failed) = mo_store->mt_saved[ check_code = zif_ca_ops_chk_types=>gc_code-check_failed ].
        cl_abap_unit_assert=>assert_equals( act = ls_failed-group2 exp = gc-check_bad msg = 'Failure names its check' ).
        cl_abap_unit_assert=>assert_equals( act = ls_failed-severity exp = zif_ca_ops_types=>gc_severity-error
                                            msg = 'Failure is an error' ).
        cl_abap_unit_assert=>assert_equals( act = mo_ok->mv_calls exp = 1 msg = 'The other check ran' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->ms_finished-status exp = zif_ca_ops_types=>gc_run_status-error
                                            msg = 'Run status error' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only checks that completed resolve what they no longer raise
  METHOD only_complete_checks_resolve.
    TRY.
        configure_scenario( VALUE #( bad_check = abap_true ) ).
        run( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_store->mt_groups ) exp = 1 msg = 'One group reconciled' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_store->mt_groups[ table_line = gc-check_ok ] ) )
                                          msg = 'The complete check is reconciled' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a partial check keeps its earlier exceptions open
  METHOD partial_check_not_resolved.
    TRY.
        configure_scenario( VALUE #( partial = abap_true ) ).
        run( ).
        cl_abap_unit_assert=>assert_false( act = mo_store->mv_reconciled msg = 'Nothing reconciled' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an area and group without an active check is an error finding, never a green run
  METHOD no_registered_check_is_error.
    TRY.
        configure_scenario( VALUE #( no_checks = abap_true ) ).
        run( ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mt_saved[ 1 ]-check_code exp = zif_ca_ops_chk_types=>gc_code-no_checks
                                            msg = 'CHECKS_NOT_REGISTERED' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->ms_finished-rag exp = zif_ca_ops_types=>gc_rag-red
                                            msg = 'Run red' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a second run of the area and group is refused; nothing starts
  METHOD held_lock_refuses_run.
    TRY.
        configure_scenario( VALUE #( lock_held = abap_true ) ).
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_true( act = ls_result-refused msg = 'Refused' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_started exp = 0 msg = 'No run started' ).
        cl_abap_unit_assert=>assert_equals( act = mo_ok->mv_calls exp = 0 msg = 'No check ran' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: ZCA_OPS execute (16) for the area is required (041)
  METHOD missing_authority_raises.
    configure_scenario( VALUE #( not_allowed = abap_true ) ).
    TRY.
        run( ).
        cl_abap_unit_assert=>fail( msg = 'Run without authority must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '041' msg = 'Message 041' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_started exp = 0 msg = 'No run started' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the run is committed before the alert rules are applied
  METHOD durable_before_notified.
    TRY.
        configure_scenario( VALUE #( ) ).
        run( ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatch_calls exp = 1 msg = 'One dispatch' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_commits_at_dispatch exp = 2
                                            msg = 'Header and results committed before the dispatch' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a failed dispatch is an ALERT_FAILED finding of the run, never silent
  METHOD failed_alert_is_recorded.
    TRY.
        configure_scenario( VALUE #( alert_fails = abap_true ) ).
        DATA(ls_result) = run( ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zcl_ca_ops_run_guard=>gc_check_alert_failed ] ) )
          msg = 'ALERT_FAILED returned' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( mo_store->mt_saved[ check_code = zcl_ca_ops_run_guard=>gc_check_alert_failed ] ) )
          msg = 'ALERT_FAILED stored' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
