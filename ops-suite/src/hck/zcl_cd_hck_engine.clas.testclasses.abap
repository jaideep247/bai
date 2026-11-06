*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_engine.clas.testclasses.abap
*& Purpose:
*& Unit tests of the health check engine through run( ) with LTD doubles for
*& store, alert, clock, DAO and check plug-ins; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Run lock: held lock skips the run; lock released after the run.
*& 2026-11-06 | Exception carry-forward: executed checks reconciled; failed check excluded.
*& 2026-11-06 | suppressed_red_is_not_red (design 6.3).
*&---------------------------------------------------------------------*
CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store.
    DATA mt_params TYPE zif_cd_ops_types=>tt_kv.
    DATA mt_last_runs TYPE zif_cd_ops_types=>tt_run.
    DATA mt_saved TYPE zif_cd_ops_types=>tt_finding.
    DATA mv_save_calls TYPE i.
    DATA mv_finish_calls TYPE i.
    DATA mv_commit_calls TYPE i.
    DATA mv_start_calls TYPE i.
    DATA mt_reconciled TYPE zif_cd_ops_types=>tt_group.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_cd_ops_store~start_run.
    mv_start_calls = mv_start_calls + 1.
    rs_run-run_id    = '0123456789ABCDEF0123456789ABCDEF'.
    rs_run-module    = iv_module.
    rs_run-variant   = iv_variant.
    rs_run-test_mode = iv_test_mode.
    rs_run-status    = zif_cd_ops_types=>gc_run_status-running.
  ENDMETHOD.

  METHOD zif_cd_ops_store~save_findings.
    mv_save_calls = mv_save_calls + 1.
    INSERT LINES OF it_findings INTO TABLE mt_saved.
    cs_run-finding_count = cs_run-finding_count + lines( it_findings ).
  ENDMETHOD.

  METHOD zif_cd_ops_store~finish_run.
    mv_finish_calls = mv_finish_calls + 1.
  ENDMETHOD.

  METHOD zif_cd_ops_store~commit.
    mv_commit_calls = mv_commit_calls + 1.
  ENDMETHOD.

  METHOD zif_cd_ops_store~reconcile.
    INSERT LINES OF it_groups INTO TABLE mt_reconciled.
  ENDMETHOD.

  METHOD zif_cd_ops_store~get_param.
    READ TABLE mt_params INTO DATA(ls_param) WITH TABLE KEY name = iv_name.
    rv_value = COND #( WHEN sy-subrc = 0 THEN ls_param-value ELSE iv_default ).
  ENDMETHOD.

  METHOD zif_cd_ops_store~get_last_run.
    READ TABLE mt_last_runs INTO rs_run WITH KEY module = iv_module.
    IF sy-subrc <> 0.
      CLEAR rs_run.
    ENDIF.
  ENDMETHOD.

  METHOD zif_cd_ops_store~get_runs_since.
    CLEAR rt_runs.
  ENDMETHOD.

  METHOD zif_cd_ops_store~get_findings.
    CLEAR rt_findings.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_alert DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert.
    DATA mv_send_calls TYPE i.
    DATA mv_dispatch_calls TYPE i.
    DATA mv_last_route TYPE zif_cd_ops_types=>ty_param_name.
    "! When bound, dispatch( ) records how far the run was persisted at that moment
    DATA mo_store TYPE REF TO ltd_store.
    DATA mv_commits_seen TYPE i.
    DATA mv_finishes_seen TYPE i.
ENDCLASS.

CLASS ltd_alert IMPLEMENTATION.
  METHOD zif_cd_ops_alert~send.
    mv_send_calls = mv_send_calls + 1.
    mv_last_route = iv_route.
  ENDMETHOD.

  METHOD zif_cd_ops_alert~dispatch.
    mv_dispatch_calls = mv_dispatch_calls + 1.
    IF mo_store IS BOUND.
      mv_commits_seen  = mo_store->mv_commit_calls.
      mv_finishes_seen = mo_store->mv_finish_calls.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_lock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_lock.
    DATA mv_held     TYPE abap_bool.
    DATA mv_acquires TYPE i.
    DATA mv_releases TYPE i.
ENDCLASS.

CLASS ltd_lock IMPLEMENTATION.
  METHOD zif_cd_ops_lock~acquire.
    mv_acquires = mv_acquires + 1.
    rv_acquired = xsdbool( mv_held = abap_false ).
    IF mv_held = abap_true.
      ev_holder = 'OTHER_JOB'.
    ENDIF.
  ENDMETHOD.
  METHOD zif_cd_ops_lock~release.
    mv_releases = mv_releases + 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
    CONSTANTS gc_base TYPE timestampl VALUE '20261105070000.0000000'.
    CONSTANTS gc_today TYPE d VALUE '20261105'.
    "! seconds added per call of now( )
    DATA mv_step TYPE i.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    mv_calls = mv_calls + 1.
    rv_timestamp = cl_abap_tstmp=>add( tstmp = gc_base
                                       secs  = mv_calls * mv_step ).
  ENDMETHOD.

  METHOD zif_cd_ops_clock~today.
    rv_date = gc_today.
  ENDMETHOD.

  METHOD zif_cd_ops_clock~time.
    rv_time = '070000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_defs TYPE zif_cd_hck_types=>tt_check_def.
    DATA mt_thresholds TYPE zif_cd_hck_types=>tt_threshold.
    DATA mv_metric_saves TYPE i.
    DATA mt_suppressions TYPE zif_cd_hck_suppress_types=>tt_suppression.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_check_defs.
    rt_defs = mt_defs.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_thresholds.
    rt_thresholds = VALUE #( FOR ls_row IN mt_thresholds WHERE ( check_id = iv_check_id ) ( ls_row ) ).
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_metric_history.
    CLEAR rt_values.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~save_metrics.
    mv_metric_saves = mv_metric_saves + 1.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_open_exceptions.
    CLEAR rt_exceptions.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_suppressions.
    rt_suppressions = mt_suppressions.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_check DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.
    DATA ms_result TYPE zif_cd_hck_types=>ty_check_result.
    DATA mv_raise TYPE abap_bool.
ENDCLASS.

CLASS ltd_check IMPLEMENTATION.
  METHOD zif_cd_hck_check~execute.
    IF mv_raise = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e301(zcd_ops) WITH is_def-check_id 'simulated failure'.
    ENDIF.
    rs_result = ms_result.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_engine DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_red_check  TYPE zif_cd_hck_types=>ty_check_id VALUE 'C_RED',
      gc_fail_check TYPE zif_cd_hck_types=>ty_check_id VALUE 'B_FAIL',
      gc_metric     TYPE zif_cd_hck_types=>ty_metric_name VALUE 'OVERDUE',
      gc_dim        TYPE zif_cd_hck_types=>ty_dim VALUE 'EBS',
      gc_green      TYPE zif_cd_ops_types=>ty_rag VALUE 'G',
      gc_amber      TYPE zif_cd_ops_types=>ty_rag VALUE 'A',
      gc_red        TYPE zif_cd_ops_types=>ty_rag VALUE 'R',
      gc_grey       TYPE zif_cd_ops_types=>ty_rag VALUE ' '.

    TYPES:
      BEGIN OF ty_flags,
        green_checks    TYPE i,
        red_metric      TYPE abap_bool,
        failing_plugin  TYPE abap_bool,
        slow_clock      TYPE abap_bool,
        test_mode       TYPE abap_bool,
        send_mail       TYPE abap_bool,
        include_modules TYPE abap_bool,
        ebs_never_ran   TYPE abap_bool,
      END OF ty_flags.

    DATA mo_store TYPE REF TO ltd_store.
    DATA mo_alert TYPE REF TO ltd_alert.
    DATA mo_clock TYPE REF TO ltd_clock.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_lock TYPE REF TO ltd_lock.
    DATA ms_flags TYPE ty_flags.

    METHODS setup.
    METHODS teardown.

    METHODS all_green_scores_hundred FOR TESTING.
    METHODS red_metric_turns_check_red FOR TESTING.
    METHODS suppressed_red_is_not_red FOR TESTING.
    METHODS failed_plugin_does_not_abort FOR TESTING.
    METHODS timeout_overrun_is_flagged FOR TESTING.
    METHODS test_mode_saves_nothing FOR TESTING.
    METHODS real_run_persists_dispatches FOR TESTING.
    METHODS mail_goes_to_morning_route FOR TESTING.
    METHODS stale_module_fails_self FOR TESTING.
    METHODS category_rag_and_score FOR TESTING.
    METHODS alerts_sent_after_commit FOR TESTING.
    METHODS held_lock_skips_run FOR TESTING.
    METHODS lock_released_after_run FOR TESTING.
    METHODS executed_checks_reconciled FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    METHODS add_check
      IMPORTING
        iv_check_id TYPE zif_cd_hck_types=>ty_check_id
        iv_category TYPE zif_cd_hck_types=>ty_category
        iv_priority TYPE zif_cd_hck_types=>ty_priority
      RETURNING
        VALUE(ro_check) TYPE REF TO ltd_check.

    METHODS act
      RETURNING
        VALUE(rs_report) TYPE zif_cd_hck_types=>ty_report
      RAISING
        zcx_cd_ops_error.

ENDCLASS.



CLASS ltc_engine IMPLEMENTATION.

  METHOD setup.
    mo_store = NEW #( ).
    mo_alert = NEW #( ).
    mo_clock = NEW #( ).
    mo_dao   = NEW #( ).
    CLEAR ms_flags.
    mo_lock = NEW #( ).
    zcl_cd_ops_injector=>inject_lock( mo_lock ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
    zcl_cd_ops_injector=>inject_alert( mo_alert ).
    zcl_cd_ops_injector=>inject_clock( mo_clock ).
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD add_check.
    DATA ls_def TYPE zif_cd_hck_types=>ty_check_def.
    ls_def-check_id    = iv_check_id.
    ls_def-description = |Test check { iv_check_id }|.
    ls_def-category    = iv_category.
    ls_def-priority    = iv_priority.
    ls_def-active      = abap_true.
    ls_def-class_name  = |LTD_CHECK_{ iv_check_id }|.
    IF ms_flags-slow_clock = abap_true.
      ls_def-timeout_sec = 10.
    ENDIF.
    INSERT ls_def INTO TABLE mo_dao->mt_defs.
    ro_check = NEW #( ).
    zcl_cd_ops_injector=>inject_plugin( iv_class_name = ls_def-class_name
                                        io_instance   = ro_check ).
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_threshold TYPE zif_cd_hck_types=>ty_threshold.
    DATA ls_last_run TYPE zif_cd_ops_types=>ty_run.

    ms_flags = is_flags.
    IF is_flags-slow_clock = abap_true.
      mo_clock->mv_step = 100.
    ENDIF.

    IF is_flags-failing_plugin = abap_true.
      DATA(lo_failing) = add_check( iv_check_id = gc_fail_check iv_category = 'B' iv_priority = 'M' ).
      lo_failing->mv_raise = abap_true.
    ENDIF.

    DO is_flags-green_checks TIMES.
      DATA(lo_green) = add_check( iv_check_id = CONV #( |GREEN{ sy-index }| ) iv_category = 'A' iv_priority = 'M' ).
      lo_green->ms_result-rag = gc_green.
    ENDDO.

    IF is_flags-red_metric = abap_true.
      DATA(lo_red) = add_check( iv_check_id = gc_red_check iv_category = 'C' iv_priority = 'H' ).
      INSERT VALUE #( metric = gc_metric dim1 = gc_dim value = 15 ) INTO TABLE lo_red->ms_result-metrics.
      ls_threshold-check_id        = gc_red_check.
      ls_threshold-metric          = gc_metric.
      ls_threshold-bukrs           = zif_cd_hck_types=>gc_default_key.
      ls_threshold-amber           = 1.
      ls_threshold-red             = 10.
      ls_threshold-higher_is_worse = abap_true.
      ls_threshold-baseline_mode   = zif_cd_hck_types=>gc_baseline-none.
      INSERT ls_threshold INTO TABLE mo_dao->mt_thresholds.
    ENDIF.

    IF is_flags-include_modules = abap_true.
      INSERT VALUE #( name = 'HCK_WATCH_MODULES' value = 'EBS,FMON' ) INTO TABLE mo_store->mt_params.
      ls_last_run-run_id     = 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'.
      ls_last_run-module     = zif_cd_ops_types=>gc_module-file_monitor.
      ls_last_run-started_at = ltd_clock=>gc_base.
      ls_last_run-rag        = gc_green.
      INSERT ls_last_run INTO TABLE mo_store->mt_last_runs.
      IF is_flags-ebs_never_ran = abap_false.
        ls_last_run-module = zif_cd_ops_types=>gc_module-ebs.
        INSERT ls_last_run INTO TABLE mo_store->mt_last_runs.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rs_report = zcl_cd_hck_factory=>get_engine( )->run(
      VALUE #( report_date     = ltd_clock=>gc_today
               test_mode       = ms_flags-test_mode
               send_mail       = ms_flags-send_mail
               include_modules = ms_flags-include_modules ) ).
  ENDMETHOD.


  " Rule: only green checks give health score 100 and overall GREEN
  METHOD all_green_scores_hundred.
    TRY.
        configure_scenario( VALUE #( green_checks = 2 ) ).
        DATA(ls_report) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_report-results ) exp = 2 msg = 'Both checks must report' ).
        cl_abap_unit_assert=>assert_equals( act = ls_report-score exp = 100 msg = 'All green must score 100' ).
        cl_abap_unit_assert=>assert_equals( act = ls_report-overall_rag exp = gc_green msg = 'All green must be GREEN' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a metric at or above its red threshold turns the check RED with one owned finding
  METHOD red_metric_turns_check_red.
    DATA lt_exp TYPE zif_cd_ops_types=>tt_finding.
    TRY.
        configure_scenario( VALUE #( red_metric = abap_true ) ).
        DATA(ls_report) = act( ).
        DATA(ls_result) = ls_report-results[ check_id = gc_red_check ].
        INSERT VALUE #( object_type = zif_cd_hck_types=>gc_object_type
                        object_key  = |{ gc_red_check }/{ gc_metric }/{ gc_dim }|
                        group1      = 'C'
                        group2      = gc_red_check
                        check_code  = zif_cd_hck_types=>gc_code-threshold_red
                        severity    = zif_cd_ops_types=>gc_severity-error
                        action      = zif_cd_ops_types=>gc_action-exception
                        message     = |{ gc_metric } { gc_dim }: 15 (amber 1, red 10)| ) INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = ls_result-rag exp = gc_red msg = 'Check must be RED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings exp = lt_exp msg = 'Exactly one THRESHOLD_RED finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a failing plug-in becomes a PLUGIN_ERROR finding and the run continues
  METHOD failed_plugin_does_not_abort.
    TRY.
        configure_scenario( VALUE #( failing_plugin = abap_true green_checks = 1 ) ).
        DATA(ls_report) = act( ).
        DATA(ls_failed) = ls_report-results[ check_id = gc_fail_check ].
        cl_abap_unit_assert=>assert_equals( act = lines( ls_report-results ) exp = 2 msg = 'Second check must still run' ).
        cl_abap_unit_assert=>assert_equals( act = ls_failed-rag exp = gc_red msg = 'Failed plug-in must be RED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_failed-findings[ 1 ]-check_code
                                            exp = zif_cd_hck_types=>gc_code-plugin_error
                                            msg = 'Failure must be recorded as PLUGIN_ERROR' ).
        cl_abap_unit_assert=>assert_equals( act = ls_report-results[ check_id = 'GREEN1' ]-rag
                                            exp = gc_green
                                            msg = 'Healthy check after the failure must be GREEN' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: runtime above TIMEOUT_SEC is flagged (W finding, AMBER) - not silently accepted
  METHOD timeout_overrun_is_flagged.
    TRY.
        configure_scenario( VALUE #( green_checks = 1 slow_clock = abap_true ) ).
        DATA(ls_report) = act( ).
        DATA(ls_result) = ls_report-results[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_result-timed_out exp = abap_true msg = 'Overrun must be flagged' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_cd_hck_types=>gc_code-timeout
                                            msg = 'Overrun must give TIMEOUT_OVERRUN' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-rag exp = gc_amber msg = 'Overrun must make the check AMBER' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: test mode writes nothing, commits nothing, alerts nobody, mails nobody
  METHOD test_mode_saves_nothing.
    TRY.
        configure_scenario( VALUE #( red_metric = abap_true test_mode = abap_true send_mail = abap_true ) ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_save_calls exp = 0 msg = 'No findings saved' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_finish_calls exp = 0 msg = 'Run not finished in DB' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commit_calls exp = 0 msg = 'No commit' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_metric_saves exp = 0 msg = 'No metrics saved' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatch_calls exp = 0 msg = 'No alert dispatched' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_send_calls exp = 0 msg = 'No e-mail sent' ).
        cl_abap_unit_assert=>assert_equals( act = mo_lock->mv_acquires exp = 0 msg = 'Test mode takes no run lock' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a productive run saves findings and metrics per check, finishes the run and dispatches alerts once
  METHOD real_run_persists_dispatches.
    TRY.
        configure_scenario( VALUE #( red_metric = abap_true ) ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_save_calls exp = 1 msg = 'Findings saved once per check' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_store->mt_saved ) exp = 1 msg = 'One finding saved' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_metric_saves exp = 1 msg = 'Metrics saved once' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_finish_calls exp = 1 msg = 'Run finished once' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatch_calls exp = 1 msg = 'Alerts dispatched once' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_send_calls exp = 0 msg = 'No report mail unless requested' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the morning report mail is sent to route MORNING when requested
  METHOD mail_goes_to_morning_route.
    TRY.
        configure_scenario( VALUE #( green_checks = 1 send_mail = abap_true ) ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_send_calls exp = 1 msg = 'One report mail' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_last_route
                                            exp = zcl_cd_hck_engine=>gc_default_route
                                            msg = 'Report mail goes to route MORNING' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a watched module without a recent run makes the self check RED (health of the health check)
  METHOD stale_module_fails_self.
    TRY.
        configure_scenario( VALUE #( include_modules = abap_true ebs_never_ran = abap_true ) ).
        DATA(ls_report) = act( ).
        DATA(ls_self) = ls_report-results[ check_id = zif_cd_hck_types=>gc_self_check ].
        cl_abap_unit_assert=>assert_equals( act = ls_self-rag exp = gc_red msg = 'Self check must be RED' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_self-findings ) exp = 1 msg = 'Only EBS is stale' ).
        cl_abap_unit_assert=>assert_equals( act = ls_self-findings[ 1 ]-object_key
                                            exp = 'EBS'
                                            msg = 'The stale module is EBS' ).
        cl_abap_unit_assert=>assert_equals( act = ls_report-modules[ module = 'FMON' ]-stale
                                            exp = abap_false
                                            msg = 'FMON ran recently' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: report carries RAG per category and the weighted score of the run
  METHOD category_rag_and_score.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_category_status.
    TRY.
        configure_scenario( VALUE #( green_checks = 1 red_metric = abap_true ) ).
        DATA(ls_report) = act( ).
        INSERT VALUE #( category = 'A' rag = gc_green check_count = 1 green_count = 1 ) INTO TABLE lt_exp.
        INSERT VALUE #( category = 'B' rag = gc_grey ) INTO TABLE lt_exp.
        INSERT VALUE #( category = 'C' rag = gc_red check_count = 1 red_count = 1 ) INTO TABLE lt_exp.
        INSERT VALUE #( category = 'D' rag = gc_grey ) INTO TABLE lt_exp.
        INSERT VALUE #( category = 'E' rag = gc_grey ) INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = ls_report-categories exp = lt_exp msg = 'RAG per category A-E' ).
        cl_abap_unit_assert=>assert_equals( act = ls_report-score exp = 40 msg = '(2*100 + 3*0) / 5 = 40' ).
        cl_abap_unit_assert=>assert_equals( act = ls_report-overall_rag exp = gc_red msg = 'Red H check forces RED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: results are durable before anyone is told - run header committed at start,
  " findings and run end committed before alerts and the report mail (review 2026-11-06)
  METHOD alerts_sent_after_commit.
    TRY.
        configure_scenario( VALUE #( red_metric = abap_true ) ).
        mo_alert->mo_store = mo_store.
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_finishes_seen exp = 1
                                            msg = 'The run must be finished before alerts are dispatched' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_commits_seen exp = 2
                                            msg = 'Run start and results must be committed before alerts' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: while another morning report of the same variant holds the lock, no
  " check runs, nothing is saved, no report mail; the refusal is alerted once
  METHOD held_lock_skips_run.
    TRY.
        configure_scenario( VALUE #( red_metric = abap_true send_mail = abap_true ) ).
        mo_lock->mv_held = abap_true.
        DATA(ls_report) = act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_start_calls exp = 0
                                            msg = 'No run may be started while the lock is held' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_send_calls exp = 0
                                            msg = 'No report mail while the lock is held' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatch_calls exp = 1
                                            msg = 'The refusal must be alerted once' ).
        cl_abap_unit_assert=>assert_true(
          act = zcl_cd_ops_run_guard=>was_refused( VALUE #( ls_report-results[ 1 ]-findings OPTIONAL ) )
          msg = 'The report must carry RUN_LOCKED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a productive run takes the lock once and releases it at the end
  METHOD lock_released_after_run.
    TRY.
        configure_scenario( VALUE #( red_metric = abap_true ) ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_lock->mv_acquires exp = 1 msg = 'The lock must be taken once' ).
        cl_abap_unit_assert=>assert_equals( act = mo_lock->mv_releases exp = 1 msg = 'The lock must be released once' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: every check that ran is reconciled by its check ID (GROUP2), so exceptions
  " of earlier reports that passed today are resolved; a check that failed is not
  METHOD executed_checks_reconciled.
    TRY.
        configure_scenario( VALUE #( failing_plugin = abap_true green_checks = 1 ) ).
        act( ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_store->mt_reconciled[ table_line = 'GREEN1' ] ) )
                                          msg = 'A check that ran must be reconciled' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( mo_store->mt_reconciled[ table_line = CONV zif_cd_ops_types=>ty_group( gc_fail_check ) ] ) )
          msg = 'A check that failed must not resolve its exceptions' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (design 6.3): a suppressed finding stays listed as information and the check is not
  " red because of it (not scored, not alerted)
  METHOD suppressed_red_is_not_red.
    DATA ls_suppression TYPE zif_cd_hck_suppress_types=>ty_suppression.
    TRY.
        configure_scenario( VALUE #( red_metric = abap_true ) ).
        ls_suppression-check_id   = gc_red_check.
        ls_suppression-valid_from = '20261101'.
        ls_suppression-valid_to   = '20261130'.
        ls_suppression-status     = zif_cd_hck_suppress_types=>gc_status-active.
        ls_suppression-created_by = 'RTB_LEAD'.
        INSERT ls_suppression INTO TABLE mo_dao->mt_suppressions.
        DATA(ls_report) = act( ).
        DATA(ls_result) = ls_report-results[ check_id = gc_red_check ].
        cl_abap_unit_assert=>assert_equals( act = ls_result-rag exp = gc_green
                                            msg = 'A check whose only finding is suppressed must be green' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-info
                                            msg = 'The suppressed finding must stay listed as information' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
