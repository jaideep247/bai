*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_engine.clas.testclasses.abap
*& Purpose:
*& Application tests of the EBS engine with LTD_* doubles for the source,
*& customizing, store, alert router and a failing rule plug-in. Proves master
*& prompt acceptance tests 3 (new code by customizing) and 7 (unmapped code
*& always blocked). Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Run lock: held lock skips the run; lock released after the run.
*& 2026-11-06 | Exception carry-forward: package scope reconciled; skipped after a rule failure.
*& 2026-11-06 | Release tests approved_release_unblocks, other_block_still_blocks, rule_failure_not_releasable.
*&---------------------------------------------------------------------*
CLASS ltd_source DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_source.
    DATA mt_packages TYPE STANDARD TABLE OF zif_cd_ebs_types=>ty_package WITH EMPTY KEY.
    DATA mv_next TYPE i VALUE 1.
ENDCLASS.

CLASS ltd_source IMPLEMENTATION.
  METHOD zif_cd_ebs_source~next_package.
    rs_package = VALUE #( mt_packages[ mv_next ] OPTIONAL ).
    mv_next += 1.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_cfg DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_cfg_dao.
    DATA mt_map   TYPE zif_cd_ebs_types=>tt_btc_map.
    DATA mt_rules TYPE zif_cd_ebs_types=>tt_rule_cfg.
    DATA mv_broken TYPE abap_bool.
ENDCLASS.

CLASS ltd_cfg IMPLEMENTATION.
  METHOD zif_cd_ebs_cfg_dao~get_btc_map.
    IF mv_broken = abap_true.
      RAISE EXCEPTION NEW cx_sy_itab_line_not_found( ).
    ENDIF.
    rt_map = mt_map.
  ENDMETHOD.
  METHOD zif_cd_ebs_cfg_dao~get_rules.
    rt_rules = mt_rules.
  ENDMETHOD.
  METHOD zif_cd_ebs_cfg_dao~get_accounts.
    CLEAR rt_accounts.
  ENDMETHOD.
  METHOD zif_cd_ebs_cfg_dao~get_flow_patterns.
    CLEAR rt_patterns.
  ENDMETHOD.
  METHOD zif_cd_ebs_cfg_dao~get_reason_map.
    CLEAR rt_reasons.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store.
    DATA mt_params   TYPE zif_cd_ops_types=>tt_kv.
    DATA mt_saved    TYPE zif_cd_ops_types=>tt_finding.
    DATA ms_finished TYPE zif_cd_ops_types=>ty_run.
    DATA mv_commits  TYPE i.
    DATA mv_starts   TYPE i.
    DATA mv_reconciles TYPE i.
    DATA mt_reconciled TYPE zif_cd_ops_types=>tt_object_key.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_cd_ops_store~start_run.
    mv_starts += 1.
    rs_run-module    = iv_module.
    rs_run-variant   = iv_variant.
    rs_run-test_mode = iv_test_mode.
    rs_run-status    = zif_cd_ops_types=>gc_run_status-running.
  ENDMETHOD.
  METHOD zif_cd_ops_store~save_findings.
    IF cs_run-test_mode = abap_false.
      INSERT LINES OF it_findings INTO TABLE mt_saved.
    ENDIF.
    cs_run-finding_count = cs_run-finding_count + lines( it_findings ).
  ENDMETHOD.
  METHOD zif_cd_ops_store~finish_run.
    ms_finished = is_run.
  ENDMETHOD.
  METHOD zif_cd_ops_store~reconcile.
    mv_reconciles += 1.
    INSERT LINES OF it_object_keys INTO TABLE mt_reconciled.
  ENDMETHOD.
  METHOD zif_cd_ops_store~commit.
    mv_commits += 1.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_param.
    rv_value = VALUE #( mt_params[ name = iv_name ]-value DEFAULT iv_default ).
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_last_run.
    CLEAR rs_run.
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
    DATA mv_dispatched TYPE i.
ENDCLASS.

CLASS ltd_alert IMPLEMENTATION.
  METHOD zif_cd_ops_alert~send.
    RETURN.
  ENDMETHOD.
  METHOD zif_cd_ops_alert~dispatch.
    mv_dispatched += 1.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_release_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_release_dao.
    "! Check code released (approved) for every line the engine asks for; blank = none
    DATA mv_check_code TYPE zif_cd_ops_types=>ty_check_code.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_release_dao IMPLEMENTATION.
  METHOD zif_cd_ebs_release_dao~get_approved.
    mv_calls += 1.
    CHECK mv_check_code IS NOT INITIAL.
    LOOP AT it_object_keys INTO DATA(lv_key).
      INSERT VALUE #( release_uuid = '000000000000000000000000000000A1'
                      object_key   = lv_key
                      check_code   = mv_check_code
                      status       = zif_cd_ebs_release_types=>gc_status-approved
                      requested_by = 'REQUESTER'
                      approved_by  = 'APPROVER' ) INTO TABLE rt_releases.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS ltd_failing_rule DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_rule.
ENDCLASS.

CLASS ltd_failing_rule IMPLEMENTATION.
  METHOD zif_cd_ebs_rule~execute.
    RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e012(zcd_ops) WITH 'TEST'.
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
    mv_acquires += 1.
    rv_acquired = xsdbool( mv_held = abap_false ).
    IF mv_held = abap_true.
      ev_holder = 'OTHER_JOB'.
    ENDIF.
  ENDMETHOD.
  METHOD zif_cd_ops_lock~release.
    mv_releases += 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = '20261105080000.0000000'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~today.
    rv_date = '20261105'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~time.
    rv_time = '080000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_engine DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        group_new   TYPE zif_cd_ebs_types=>ty_rule_group VALUE 'NEWBANK',
        code_new    TYPE zif_cd_ebs_types=>ty_btc_code VALUE '987',
        code_unmap  TYPE zif_cd_ebs_types=>ty_btc_code VALUE '999',
        sign_class  TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_EBS_R_R01_SIGN',
        cover_class TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_EBS_R_S09_COVERAGE',
        fail_class  TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_TEST_FAILING_RULE',
      END OF gc_test.

    TYPES:
      BEGIN OF ty_flags,
        map_new_code      TYPE abap_bool,
        assign_sign_rule  TYPE abap_bool,
        assign_star_rule  TYPE abap_bool,
        assign_stmt_rule  TYPE abap_bool,
        assign_fail_rule  TYPE abap_bool,
        line_code         TYPE zif_cd_ebs_types=>ty_btc_code,
        wrong_sign        TYPE abap_bool,
        packages          TYPE i,
        lines_per_package TYPE i,
        test_mode         TYPE abap_bool,
      END OF ty_flags.

    DATA mo_source TYPE REF TO ltd_source.
    DATA mo_cfg    TYPE REF TO ltd_cfg.
    DATA mo_store  TYPE REF TO ltd_store.
    DATA mo_alert  TYPE REF TO ltd_alert.
    DATA mo_lock   TYPE REF TO ltd_lock.
    DATA mo_release TYPE REF TO ltd_release_dao.
    DATA ms_result TYPE zcl_cd_ebs_engine=>ty_result.

    METHODS setup.
    METHODS teardown.
    METHODS default_flags
      RETURNING
        VALUE(rs_flags) TYPE ty_flags.
    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS add_rule
      IMPORTING
        iv_group TYPE zif_cd_ebs_types=>ty_rule_group
        iv_id    TYPE zif_cd_ops_types=>ty_rule_id
        iv_class TYPE zif_cd_ops_types=>ty_class_name
        iv_level TYPE char1.
    METHODS run_engine
      IMPORTING
        iv_test_mode TYPE abap_bool DEFAULT abap_false.
    METHODS count_rule
      IMPORTING
        iv_rule_id      TYPE zif_cd_ops_types=>ty_rule_id
      RETURNING
        VALUE(rv_count) TYPE i.

    METHODS unmapped_code_always_blocked FOR TESTING.
    METHODS new_code_needs_config_only   FOR TESTING.
    METHODS group_rule_skips_other_codes FOR TESTING.
    METHODS star_rule_runs_for_all_lines FOR TESTING.
    METHODS failing_rule_does_not_abort  FOR TESTING.
    METHODS test_mode_saves_nothing      FOR TESTING.
    METHODS run_dispatches_alert_once    FOR TESTING.
    METHODS circuit_breaker_aborts_run   FOR TESTING.
    METHODS kept_findings_are_capped     FOR TESTING.
    METHODS enforce_mode_blocks_posting  FOR TESTING.
    METHODS monitor_mode_never_blocks    FOR TESTING.
    METHODS off_mode_validates_nothing   FOR TESTING.
    METHODS failed_rule_blocks_posting   FOR TESTING.
    METHODS broken_config_blocks_posting FOR TESTING.
    METHODS approved_release_unblocks    FOR TESTING.
    METHODS other_block_still_blocks     FOR TESTING.
    METHODS rule_failure_not_releasable  FOR TESTING.
    METHODS held_lock_skips_run          FOR TESTING.
    METHODS lock_released_after_run      FOR TESTING.
    METHODS validated_lines_reconciled   FOR TESTING.
    METHODS failed_rule_skips_reconcile  FOR TESTING.
ENDCLASS.


CLASS ltc_engine IMPLEMENTATION.

  METHOD setup.
    mo_source = NEW #( ).
    mo_cfg    = NEW #( ).
    mo_store  = NEW #( ).
    mo_alert  = NEW #( ).
    mo_lock   = NEW #( ).
    zcl_cd_ops_injector=>inject_lock( mo_lock ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
    zcl_cd_ops_injector=>inject_alert( mo_alert ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    zcl_cd_ops_injector=>inject_plugin( iv_class_name = gc_test-fail_class io_instance = NEW ltd_failing_rule( ) ).
    zcl_cd_ebs_injector=>inject_cfg_dao( mo_cfg ).
    mo_release = NEW #( ).
    zcl_cd_ebs_injector=>inject_release_dao( mo_release ).
    CLEAR ms_result.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_ebs_injector=>reset( ).
    CLEAR: mo_source, mo_cfg, mo_store, mo_alert, mo_lock.
  ENDMETHOD.


  METHOD default_flags.
    rs_flags-map_new_code      = abap_true.
    rs_flags-line_code         = gc_test-code_new.
    rs_flags-packages          = 1.
    rs_flags-lines_per_package = 1.
  ENDMETHOD.


  METHOD add_rule.
    DATA ls_rule TYPE zif_cd_ebs_types=>ty_rule_cfg.
    ls_rule-rule_group = iv_group.
    ls_rule-rule_id    = iv_id.
    ls_rule-class_name = iv_class.
    ls_rule-level      = iv_level.
    ls_rule-severity   = zif_cd_ops_types=>gc_severity-error.
    ls_rule-action     = zif_cd_ops_types=>gc_action-exception.
    ls_rule-active     = abap_true.
    INSERT ls_rule INTO TABLE mo_cfg->mt_rules.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_map     TYPE zif_cd_ebs_types=>ty_btc_map.
    DATA ls_package TYPE zif_cd_ebs_types=>ty_package.
    DATA ls_stmt    TYPE zif_cd_ebs_types=>ty_statement.
    DATA ls_line    TYPE zif_cd_ebs_types=>ty_line.

    IF is_flags-map_new_code = abap_true.
      ls_map-scheme     = zif_cd_ebs_types=>gc_scheme-bai2.
      ls_map-btc_code   = gc_test-code_new.
      ls_map-flow_type  = zif_cd_ebs_types=>gc_flow-any.
      ls_map-category   = 'D01'.
      ls_map-rule_group = gc_test-group_new.
      ls_map-exp_cdi    = zif_cd_ebs_types=>gc_cdi-credit.
      ls_map-active     = abap_true.
      INSERT ls_map INTO TABLE mo_cfg->mt_map.
    ENDIF.
    IF is_flags-assign_sign_rule = abap_true.
      add_rule( iv_group = gc_test-group_new iv_id = 'R01' iv_class = gc_test-sign_class
                iv_level = zif_cd_ebs_types=>gc_level-line ).
    ENDIF.
    IF is_flags-assign_star_rule = abap_true.
      add_rule( iv_group = zif_cd_ebs_types=>gc_rule_group_all iv_id = 'R01' iv_class = gc_test-sign_class
                iv_level = zif_cd_ebs_types=>gc_level-line ).
    ENDIF.
    IF is_flags-assign_stmt_rule = abap_true.
      add_rule( iv_group = zif_cd_ebs_types=>gc_rule_group_all iv_id = 'S09' iv_class = gc_test-cover_class
                iv_level = zif_cd_ebs_types=>gc_level-statement ).
    ENDIF.
    IF is_flags-assign_fail_rule = abap_true.
      add_rule( iv_group = gc_test-group_new iv_id = 'R99' iv_class = gc_test-fail_class
                iv_level = zif_cd_ebs_types=>gc_level-line ).
    ENDIF.

    DO is_flags-packages TIMES.
      DATA(lv_package) = sy-index.
      CLEAR ls_package.
      ls_stmt-stmt_key    = |S{ lv_package WIDTH = 4 ALIGN = RIGHT PAD = '0' }|.
      ls_stmt-source      = zif_cd_ebs_types=>gc_source-file.
      ls_stmt-currency    = 'USD'.
      ls_stmt-stmt_date   = '20261105'.
      INSERT ls_stmt INTO TABLE ls_package-statements.
      DO is_flags-lines_per_package TIMES.
        CLEAR ls_line.
        ls_line-stmt_key  = ls_stmt-stmt_key.
        ls_line-line_no   = sy-index.
        ls_line-scheme    = zif_cd_ebs_types=>gc_scheme-bai2.
        ls_line-btc_code  = is_flags-line_code.
        ls_line-cdi       = COND #( WHEN is_flags-wrong_sign = abap_true THEN zif_cd_ebs_types=>gc_cdi-debit
                                    ELSE zif_cd_ebs_types=>gc_cdi-credit ).
        ls_line-amount    = '10.00'.
        ls_line-currency  = 'USD'.
        ls_line-reference = |REF{ sy-index }|.
        INSERT ls_line INTO TABLE ls_package-lines.
      ENDDO.
      INSERT ls_package INTO TABLE mo_source->mt_packages.
    ENDDO.
  ENDMETHOD.


  METHOD run_engine.
    TRY.
        ms_result = NEW zcl_cd_ebs_engine( )->run( io_source    = mo_source
                                                   iv_variant   = 'UNIT'
                                                   iv_test_mode = iv_test_mode ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Engine run raised: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD count_rule.
    rv_count = REDUCE i( INIT lv_n = 0 FOR ls_f IN ms_result-findings WHERE ( rule_id = iv_rule_id )
                         NEXT lv_n = lv_n + 1 ).
  ENDMETHOD.


  " Acceptance test 7: an unmapped code is blocked, counted and never validated as postable
  METHOD unmapped_code_always_blocked.
    DATA(ls_flags) = default_flags( ).
    ls_flags-line_code        = gc_test-code_unmap.
    ls_flags-assign_star_rule = abap_true.
    configure_scenario( ls_flags ).

    run_engine( ).

    cl_abap_unit_assert=>assert_equals( act = ms_result-run-blocked_items exp = 1
                                        msg = 'The unmapped line must be counted as blocked' ).
    cl_abap_unit_assert=>assert_equals( act = count_rule( 'R14' ) exp = 1
                                        msg = 'The unmapped line must carry one R14 finding' ).
    cl_abap_unit_assert=>assert_equals( act = count_rule( 'R01' ) exp = 0
                                        msg = 'Line rules must not run on a blocked line' ).
  ENDMETHOD.


  " Acceptance test 3: a new bank code plus a rule assignment is validated with no code change
  METHOD new_code_needs_config_only.
    DATA(ls_flags) = default_flags( ).
    ls_flags-assign_sign_rule = abap_true.
    ls_flags-wrong_sign       = abap_true.
    configure_scenario( ls_flags ).

    run_engine( ).

    cl_abap_unit_assert=>assert_equals( act = count_rule( 'R01' ) exp = 1
                                        msg = 'Configured rule R01 must validate the new code' ).
    cl_abap_unit_assert=>assert_equals( act = ms_result-run-failed_items exp = 1
                                        msg = 'The wrong-sign line must count as failed' ).
  ENDMETHOD.


  " A group rule runs only for lines of its rule group
  METHOD group_rule_skips_other_codes.
    DATA(ls_flags) = default_flags( ).
    ls_flags-assign_sign_rule = abap_true.
    ls_flags-wrong_sign       = abap_true.
    configure_scenario( ls_flags ).
    mo_cfg->mt_rules[ 1 ]-rule_group = 'OTHERGRP'.

    run_engine( ).

    cl_abap_unit_assert=>assert_equals( act = count_rule( 'R01' ) exp = 0
                                        msg = 'A rule of another group must not run' ).
  ENDMETHOD.


  " A '*' line rule runs for every mapped line
  METHOD star_rule_runs_for_all_lines.
    DATA(ls_flags) = default_flags( ).
    ls_flags-assign_star_rule  = abap_true.
    ls_flags-wrong_sign        = abap_true.
    ls_flags-lines_per_package = 3.
    configure_scenario( ls_flags ).

    run_engine( ).

    cl_abap_unit_assert=>assert_equals( act = count_rule( 'R01' ) exp = 3
                                        msg = 'A * rule must validate every mapped line' ).
  ENDMETHOD.


  " A rule that raises is recorded as PLUGIN_ERROR; the run and the other rules continue
  METHOD failing_rule_does_not_abort.
    DATA(ls_flags) = default_flags( ).
    ls_flags-assign_fail_rule = abap_true.
    ls_flags-assign_sign_rule = abap_true.
    ls_flags-wrong_sign       = abap_true.
    configure_scenario( ls_flags ).

    run_engine( ).

    cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( ms_result-findings[ check_code = 'PLUGIN_ERROR' ] ) )
                                      msg = 'A failing rule must leave a PLUGIN_ERROR finding' ).
    cl_abap_unit_assert=>assert_equals( act = count_rule( 'R01' ) exp = 1
                                        msg = 'Other rules must still run' ).
    cl_abap_unit_assert=>assert_differs( act = ms_result-run-status exp = zif_cd_ops_types=>gc_run_status-aborted
                                         msg = 'A failing rule must not abort the run' ).
  ENDMETHOD.


  " Test mode: findings are returned but nothing is saved, committed or alerted
  METHOD test_mode_saves_nothing.
    DATA(ls_flags) = default_flags( ).
    ls_flags-line_code = gc_test-code_unmap.
    configure_scenario( ls_flags ).

    run_engine( iv_test_mode = abap_true ).

    cl_abap_unit_assert=>assert_not_initial( act = ms_result-findings msg = 'Test mode must still return findings' ).
    cl_abap_unit_assert=>assert_initial( act = mo_store->mt_saved msg = 'Test mode must save nothing' ).
    cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 0 msg = 'Test mode must not commit' ).
    cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatched exp = 0 msg = 'Test mode must not alert' ).
    cl_abap_unit_assert=>assert_equals( act = mo_lock->mv_acquires exp = 0 msg = 'Test mode must not take the run lock' ).
  ENDMETHOD.


  " A productive run hands its findings to the alert router exactly once
  METHOD run_dispatches_alert_once.
    DATA(ls_flags) = default_flags( ).
    ls_flags-line_code = gc_test-code_unmap.
    configure_scenario( ls_flags ).

    run_engine( ).

    cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatched exp = 1
                                        msg = 'The alert router must be called once per run' ).
    cl_abap_unit_assert=>assert_not_initial( act = mo_store->mt_saved msg = 'Findings must be saved' ).
  ENDMETHOD.


  " Circuit breaker: three consecutive packages above the failure rate abort the run
  METHOD circuit_breaker_aborts_run.
    DATA(ls_flags) = default_flags( ).
    ls_flags-line_code         = gc_test-code_unmap.
    ls_flags-packages          = 5.
    ls_flags-lines_per_package = 2.
    configure_scenario( ls_flags ).
    INSERT VALUE #( name = 'EBS_CB_MIN_LINES' value = '1' ) INTO TABLE mo_store->mt_params.

    run_engine( ).

    cl_abap_unit_assert=>assert_equals( act = ms_result-run-status exp = zif_cd_ops_types=>gc_run_status-aborted
                                        msg = 'Three failing packages must abort the run' ).
    cl_abap_unit_assert=>assert_equals( act = ms_result-run-total_items exp = 6
                                        msg = 'Only the first three packages may be processed' ).
  ENDMETHOD.


  " Review 3.5: findings kept in memory are capped (EBS_RESULT_MAX); counts and RAG still cover every line
  METHOD kept_findings_are_capped.
    DATA(ls_flags) = default_flags( ).
    ls_flags-line_code         = gc_test-code_unmap.
    ls_flags-lines_per_package = 3.
    configure_scenario( ls_flags ).
    INSERT VALUE #( name = 'EBS_RESULT_MAX' value = '1' ) INTO TABLE mo_store->mt_params.

    run_engine( ).

    cl_abap_unit_assert=>assert_equals( act = lines( ms_result-findings ) exp = 1
                                        msg = 'Only EBS_RESULT_MAX findings may be kept in memory' ).
    cl_abap_unit_assert=>assert_equals( act = ms_result-run-blocked_items exp = 3
                                        msg = 'Counts must still cover every line' ).
    cl_abap_unit_assert=>assert_equals( act = ms_result-run-rag exp = zif_cd_ops_types=>gc_rag-red
                                        msg = 'RAG must reflect findings that were not kept' ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_store->mt_saved ) exp = 3
                                        msg = 'Every finding must still be saved' ).
  ENDMETHOD.


  " Kill switch ENFORCE: a B finding blocks posting
  METHOD enforce_mode_blocks_posting.
    DATA ls_finding TYPE zif_cd_ops_types=>ty_finding.
    ls_finding-severity = zif_cd_ops_types=>gc_severity-block.
    cl_abap_unit_assert=>assert_true(
      act = zcl_cd_ebs_engine=>must_block( iv_mode = zcl_cd_ebs_engine=>gc_mode-enforce
                                           it_findings = VALUE #( ( ls_finding ) ) )
      msg = 'Enforce mode must block on a B finding' ).
  ENDMETHOD.


  " Kill switch MONITOR: findings are recorded but posting is never blocked
  METHOD monitor_mode_never_blocks.
    DATA ls_finding TYPE zif_cd_ops_types=>ty_finding.
    ls_finding-severity = zif_cd_ops_types=>gc_severity-block.
    cl_abap_unit_assert=>assert_false(
      act = zcl_cd_ebs_engine=>must_block( iv_mode = zcl_cd_ebs_engine=>gc_mode-monitor
                                           it_findings = VALUE #( ( ls_finding ) ) )
      msg = 'Monitor mode must never block' ).
  ENDMETHOD.


  " Kill switch OFF: the pre-posting hook validates nothing
  METHOD off_mode_validates_nothing.
    DATA ls_package TYPE zif_cd_ebs_types=>ty_package.
    DATA ls_line    TYPE zif_cd_ebs_types=>ty_line.
    ls_line-btc_code = gc_test-code_unmap.
    INSERT ls_line INTO TABLE ls_package-lines.
    TRY.
        DATA(ls_decision) = NEW zcl_cd_ebs_engine( )->validate_for_posting(
          iv_mode    = zcl_cd_ebs_engine=>gc_mode-off
          is_package = ls_package ).
        cl_abap_unit_assert=>assert_initial( act = ls_decision-findings msg = 'Off mode must not validate' ).
        cl_abap_unit_assert=>assert_false( act = ls_decision-block msg = 'Off mode must not block' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Fail closed: in ENFORCE mode a rule that raises blocks posting - a broken
  " check is never permission to post an unvalidated line (review 2026-11-06)
  METHOD failed_rule_blocks_posting.
    DATA(ls_flags) = default_flags( ).
    ls_flags-assign_fail_rule = abap_true.
    configure_scenario( ls_flags ).
    DATA(ls_package) = mo_source->mt_packages[ 1 ].
    TRY.
        DATA(ls_decision) = NEW zcl_cd_ebs_engine( )->validate_for_posting(
          iv_mode    = zcl_cd_ebs_engine=>gc_mode-enforce
          is_package = ls_package ).
        cl_abap_unit_assert=>assert_true( act = ls_decision-block
                                          msg = 'A failing rule must block posting in enforce mode' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( ls_decision-findings[ check_code = 'PLUGIN_ERROR' ]-action OPTIONAL )
          exp = zif_cd_ops_types=>gc_action-block
          msg = 'PLUGIN_ERROR must carry action BLOCK' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Fail closed: validation that cannot run at all (configuration unreadable)
  " blocks posting in enforce mode instead of raising to the BAdI
  METHOD broken_config_blocks_posting.
    DATA(ls_flags) = default_flags( ).
    configure_scenario( ls_flags ).
    mo_cfg->mv_broken = abap_true.
    DATA(ls_package) = mo_source->mt_packages[ 1 ].
    TRY.
        DATA(ls_decision) = NEW zcl_cd_ebs_engine( )->validate_for_posting(
          iv_mode    = zcl_cd_ebs_engine=>gc_mode-enforce
          is_package = ls_package ).
        cl_abap_unit_assert=>assert_true( act = ls_decision-block
                                          msg = 'Validation that could not run must block in enforce mode' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_decision-findings[ check_code = 'VALIDATION_ERROR' ] ) )
          msg = 'The reason must be recorded as VALIDATION_ERROR' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Must not raise: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: while another run of the same variant holds the lock, nothing is
  " validated or saved; the refusal is alerted once
  METHOD held_lock_skips_run.
    DATA(ls_flags) = default_flags( ).
    configure_scenario( ls_flags ).
    mo_lock->mv_held = abap_true.

    run_engine( ).

    cl_abap_unit_assert=>assert_equals( act = mo_store->mv_starts exp = 0
                                        msg = 'No run may be started while the lock is held' ).
    cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_run_guard=>was_refused( ms_result-findings )
                                      msg = 'The result must carry RUN_LOCKED' ).
    cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatched exp = 1
                                        msg = 'The refusal must be alerted once' ).
  ENDMETHOD.


  " Rule: a productive run takes the lock once and releases it at the end
  METHOD lock_released_after_run.
    DATA(ls_flags) = default_flags( ).
    configure_scenario( ls_flags ).

    run_engine( ).

    cl_abap_unit_assert=>assert_equals( act = mo_lock->mv_acquires exp = 1 msg = 'The lock must be taken once' ).
    cl_abap_unit_assert=>assert_equals( act = mo_lock->mv_releases exp = 1 msg = 'The lock must be released once' ).
  ENDMETHOD.


  " Rule: every line and statement a package validated is reconciled, so open
  " exceptions of earlier runs that passed this time are resolved
  METHOD validated_lines_reconciled.
    DATA(ls_flags) = default_flags( ).
    ls_flags-assign_sign_rule = abap_true.
    configure_scenario( ls_flags ).
    DATA(ls_package) = mo_source->mt_packages[ 1 ].

    run_engine( ).

    cl_abap_unit_assert=>assert_equals( act = mo_store->mv_reconciles exp = 1
                                        msg = 'Each package must be reconciled once' ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( mo_store->mt_reconciled[
                       table_line = zcl_cd_ebs_finding=>line_key( ls_package-lines[ 1 ] ) ] ) )
      msg = 'The validated line must be in the reconciliation scope' ).
    cl_abap_unit_assert=>assert_true(
      act = xsdbool( line_exists( mo_store->mt_reconciled[ table_line = ls_package-statements[ 1 ]-stmt_key ] ) )
      msg = 'The validated statement must be in the reconciliation scope' ).
  ENDMETHOD.


  " Rule: a package where a rule could not run proves nothing - its exceptions stay open
  METHOD failed_rule_skips_reconcile.
    DATA(ls_flags) = default_flags( ).
    ls_flags-assign_fail_rule = abap_true.
    configure_scenario( ls_flags ).

    run_engine( ).

    cl_abap_unit_assert=>assert_equals( act = mo_store->mv_reconciles exp = 0
                                        msg = 'No reconciliation after a rule failure' ).
  ENDMETHOD.


  " Release (design 6.2): an approved release of the line's block opens the gate; the
  " finding stays recorded as information
  METHOD approved_release_unblocks.
    DATA(ls_flags) = default_flags( ).
    ls_flags-line_code = gc_test-code_unmap.
    configure_scenario( ls_flags ).
    mo_release->mv_check_code = 'UNMAPPED_BTC'.
    TRY.
        DATA(ls_decision) = NEW zcl_cd_ebs_engine( )->validate_for_posting(
          iv_mode    = zcl_cd_ebs_engine=>gc_mode-enforce
          is_package = mo_source->mt_packages[ 1 ] ).
        cl_abap_unit_assert=>assert_false( act = ls_decision-block msg = 'A released line must not block posting' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( ls_decision-findings[ check_code = 'UNMAPPED_BTC' ]-severity OPTIONAL )
          exp = zif_cd_ops_types=>gc_severity-info
          msg = 'The released block must stay recorded as information' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Release is per check code: a release for another check does not open the gate
  METHOD other_block_still_blocks.
    DATA(ls_flags) = default_flags( ).
    ls_flags-line_code = gc_test-code_unmap.
    configure_scenario( ls_flags ).
    mo_release->mv_check_code = 'CHECK_STATUS'.
    TRY.
        DATA(ls_decision) = NEW zcl_cd_ebs_engine( )->validate_for_posting(
          iv_mode    = zcl_cd_ebs_engine=>gc_mode-enforce
          is_package = mo_source->mt_packages[ 1 ] ).
        cl_abap_unit_assert=>assert_true( act = ls_decision-block
                                          msg = 'A release of another check code must not unblock' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Fail closed stays closed: a rule that could not run is never released
  METHOD rule_failure_not_releasable.
    DATA(ls_flags) = default_flags( ).
    ls_flags-assign_fail_rule = abap_true.
    configure_scenario( ls_flags ).
    mo_release->mv_check_code = 'PLUGIN_ERROR'.
    TRY.
        DATA(ls_decision) = NEW zcl_cd_ebs_engine( )->validate_for_posting(
          iv_mode    = zcl_cd_ebs_engine=>gc_mode-enforce
          is_package = mo_source->mt_packages[ 1 ] ).
        cl_abap_unit_assert=>assert_true( act = ls_decision-block
                                          msg = 'A PLUGIN_ERROR must still block although a release exists' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
