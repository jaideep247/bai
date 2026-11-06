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
*& 2026-11-06 | Audit A27 / A03: blocking flag, empty and unusable rule groups.
*& 2026-11-06 | Audit A27/A86: parser (package) findings honour the blocks-posting flag.
*& 2026-11-06 | Audit A66/A67/A68: unevaluated lines, technical breaker, alert after cap, exact line cap, NO_DATA run.
*& 2026-11-06 | Audit A85: posting disposition per line, precedence and monitor mode.
*& 2026-11-06 | Audit A64: posting check refreshes the parameter snapshot.
*& 2026-11-06 | Audit A91: kill switch missing, invalid, off and SQL failure (TEST-INJECTION tvarvc_read).
*& 2026-11-06 | Audit A98: contradictory blank / * map rows block through the posting decision.
*& 2026-11-06 | Audit A95: missing 99 blocks through the posting decision (parsed BAI2 file).
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
    "! A64: parameter snapshot refreshes
    DATA mv_refreshes TYPE i.
    DATA mt_reconciled TYPE zif_cd_ops_types=>tt_object_key.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_cd_ops_store~start_run.
    mv_starts += 1.
    rs_run-pe_area    = iv_pe_area.
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
  METHOD zif_cd_ops_store~refresh_params.
    mv_refreshes += 1.
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
    "! A67: findings handed to the alert router
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.
ENDCLASS.

CLASS ltd_alert IMPLEMENTATION.
  METHOD zif_cd_ops_alert~send.
    RETURN.
  ENDMETHOD.
  METHOD zif_cd_ops_alert~dispatch.
    mv_dispatched += 1.
    mt_findings = it_findings.
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
        "! A85: action and disposition of the map row of the new code
        map_action        TYPE zif_cd_ops_types=>ty_action,
        map_disposition   TYPE zif_cd_ebs_types=>ty_btc_map-disposition,
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
    METHODS blocking_rule_blocks_posting FOR TESTING.
    METHODS parser_count_flag_blocks FOR TESTING.
    METHODS disposition_auto_post        FOR TESTING.
    METHODS disposition_block            FOR TESTING.
    METHODS disposition_not_posted       FOR TESTING.
    METHODS disposition_exception        FOR TESTING.
    METHODS disposition_on_account       FOR TESTING.
    METHODS disposition_block_wins       FOR TESTING.
    METHODS disposition_monitor_no_block FOR TESTING.
    METHODS disposition_awaiting_held    FOR TESTING.
    METHODS posting_check_refreshes_params FOR TESTING.
    METHODS map_conflict_blocks_posting  FOR TESTING.
    METHODS missing_99_blocks_posting    FOR TESTING.
    "! A95/A97: package of a BAI2 file parsed by ZCL_CD_EBS_PARSER_BAI2 (file source)
    METHODS file_package
      IMPORTING
        iv_content        TYPE string
      RETURNING
        VALUE(rs_package) TYPE zif_cd_ebs_types=>ty_package.
    "! A95/A97: a small consistent BAI2 file with one 165 credit; iv_extra is inserted before
    "! the 49 (its amount counted in the trailers), iv_no_99 drops the file trailer
    METHODS small_bai2
      IMPORTING
        iv_extra          TYPE string OPTIONAL
        iv_extra_amount   TYPE i DEFAULT 0
        iv_no_99          TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rv_content) TYPE string.
    METHODS kill_switch_missing_monitor  FOR TESTING.
    METHODS kill_switch_invalid_monitor  FOR TESTING.
    METHODS kill_switch_off_read         FOR TESTING.
    "! A91: a database error is injected into the TVARVC read (TEST-INJECTION tvarvc_read)
    METHODS kill_switch_sql_failure      FOR TESTING RAISING cx_sy_open_sql_db.
    "! A85: disposition of the first line of the first package (ENFORCE)
    METHODS first_disposition
      IMPORTING
        iv_mode               TYPE zcl_cd_ebs_engine=>ty_mode DEFAULT zcl_cd_ebs_engine=>gc_mode-enforce
      RETURNING
        VALUE(rv_disposition) TYPE zif_cd_ops_types=>ty_action.
    "! A85: scenario with the new code mapped and its group running R01
    METHODS sign_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS plugin_error_unevaluated     FOR TESTING.
    METHODS plugin_error_trips_breaker   FOR TESTING.
    METHODS blocker_after_cap_alerts     FOR TESTING.
    METHODS kept_lines_capped_exactly    FOR TESTING.
    METHODS empty_source_is_no_data      FOR TESTING.
    METHODS empty_feed_opt_in_green      FOR TESTING.
    METHODS parser_count_advisory FOR TESTING.
    METHODS advisory_rule_never_blocks   FOR TESTING.
    METHODS empty_rule_group_blocks      FOR TESTING.
    METHODS none_row_makes_group_optional FOR TESTING.
    METHODS unusable_rule_blocks         FOR TESTING.
    METHODS decide
      RETURNING
        VALUE(rs_decision) TYPE zcl_cd_ebs_engine=>ty_decision.
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
      ls_map-action      = is_flags-map_action.
      ls_map-disposition = is_flags-map_disposition.
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


  METHOD decide.
    TRY.
        rs_decision = NEW zcl_cd_ebs_engine( )->validate_for_posting(
          iv_mode    = zcl_cd_ebs_engine=>gc_mode-enforce
          is_package = mo_source->mt_packages[ 1 ] ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Posting check raised: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " A27: a failed check of a rule whose 'blocks posting' flag is on blocks posting in enforce mode
  METHOD blocking_rule_blocks_posting.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-assign_sign_rule = abap_true.
        ls_flags-wrong_sign       = abap_true.
        configure_scenario( ls_flags ).
        mo_cfg->mt_rules[ 1 ]-blocks_posting = abap_true.
        DATA(ls_decision) = decide( ).
        cl_abap_unit_assert=>assert_true( act = ls_decision-block
                                          msg = 'A blocking rule that failed must block posting' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( ls_decision-findings[ rule_id = 'R01' ]-action OPTIONAL )
          exp = zif_cd_ops_types=>gc_action-block
          msg = 'The finding of a blocking rule must carry action BLOCK' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A27: an advisory rule (flag off) records its finding but never blocks posting
  METHOD advisory_rule_never_blocks.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-assign_sign_rule = abap_true.
        ls_flags-wrong_sign       = abap_true.
        configure_scenario( ls_flags ).
        DATA(ls_decision) = decide( ).
        cl_abap_unit_assert=>assert_false( act = ls_decision-block
                                           msg = 'An advisory rule must not block posting' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( ls_decision-findings[ rule_id = 'R01' ] ) )
                                          msg = 'The advisory finding must still be recorded' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A03: a mapped rule group without any usable rule is a configuration gap - it blocks
  METHOD empty_rule_group_blocks.
    TRY.
        configure_scenario( default_flags( ) ).
        DATA(ls_decision) = decide( ).
        cl_abap_unit_assert=>assert_true( act = ls_decision-block
                                          msg = 'A mapped group without rules must block posting' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_decision-findings[ check_code = zif_cd_ebs_types=>gc_check_code-rule_group_empty ] ) )
          msg = 'The gap must be recorded as RULE_GROUP_EMPTY' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A03: a NONE row declares a group intentionally without code-specific rules
  METHOD none_row_makes_group_optional.
    TRY.
        configure_scenario( default_flags( ) ).
        add_rule( iv_group = gc_test-group_new iv_id = zif_cd_ebs_types=>gc_rule_none iv_class = space
                  iv_level = zif_cd_ebs_types=>gc_level-line ).
        DATA(ls_decision) = decide( ).
        cl_abap_unit_assert=>assert_false( act = ls_decision-block
                                           msg = 'An explicitly optional group must not block' ).
        cl_abap_unit_assert=>assert_initial( act = ls_decision-findings
                                             msg = 'An explicitly optional group raises no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A03: an assignment whose rule definition is missing or inactive never silently disappears
  METHOD unusable_rule_blocks.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-assign_sign_rule = abap_true.
        ls_flags-wrong_sign       = abap_true.
        configure_scenario( ls_flags ).
        mo_cfg->mt_rules[ 1 ]-unusable = abap_true.
        DATA(ls_decision) = decide( ).
        cl_abap_unit_assert=>assert_true( act = ls_decision-block
                                          msg = 'An unusable required rule must block posting' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_decision-findings[ check_code = zif_cd_ebs_types=>gc_check_code-rule_unusable ] ) )
          msg = 'The gap must be recorded as RULE_UNUSABLE' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( ls_decision-findings[ check_code = zif_cd_ebs_types=>gc_check_code-sign_mismatch ] ) )
          msg = 'An unusable rule must not be executed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A27/A86: a parser count discrepancy (S12) blocks posting when S12's flag is on (seed ON)
  METHOD parser_count_flag_blocks.
    TRY.
        configure_scenario( default_flags( ) ).
        add_rule( iv_group = zif_cd_ebs_types=>gc_rule_group_all iv_id = 'S12' iv_class = 'ZCL_CD_EBS_R_S12_COUNT'
                  iv_level = zif_cd_ebs_types=>gc_level-statement ).
        mo_cfg->mt_rules[ rule_id = 'S12' ]-blocks_posting = abap_true.
        add_rule( iv_group = gc_test-group_new iv_id = 'R01' iv_class = gc_test-sign_class
                  iv_level = zif_cd_ebs_types=>gc_level-line ).
        ASSIGN mo_source->mt_packages[ 1 ] TO FIELD-SYMBOL(<ls_package>).
        INSERT VALUE #( object_type = 'STMT' object_key = 'S0001' rule_id = 'S12' check_code = 'BAI2_RECORD_COUNT'
                        severity = zif_cd_ops_types=>gc_severity-error )
          INTO TABLE <ls_package>-findings.
        DATA(ls_decision) = decide( ).
        cl_abap_unit_assert=>assert_true( act = ls_decision-block
                                          msg = 'A parser count discrepancy of a blocking rule must block posting' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( ls_decision-findings[ rule_id = 'S12' ]-action OPTIONAL )
          exp = zif_cd_ops_types=>gc_action-block
          msg = 'The parser finding must carry action BLOCK from the rule flag' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A27/A86: with the flag off the parser count discrepancy is recorded but does not block
  METHOD parser_count_advisory.
    TRY.
        configure_scenario( default_flags( ) ).
        add_rule( iv_group = zif_cd_ebs_types=>gc_rule_group_all iv_id = 'S12' iv_class = 'ZCL_CD_EBS_R_S12_COUNT'
                  iv_level = zif_cd_ebs_types=>gc_level-statement ).
        add_rule( iv_group = gc_test-group_new iv_id = 'R01' iv_class = gc_test-sign_class
                  iv_level = zif_cd_ebs_types=>gc_level-line ).
        ASSIGN mo_source->mt_packages[ 1 ] TO FIELD-SYMBOL(<ls_package>).
        INSERT VALUE #( object_type = 'STMT' object_key = 'S0001' rule_id = 'S12' check_code = 'BAI2_RECORD_COUNT'
                        severity = zif_cd_ops_types=>gc_severity-error )
          INTO TABLE <ls_package>-findings.
        DATA(ls_decision) = decide( ).
        cl_abap_unit_assert=>assert_false( act = ls_decision-block
                                           msg = 'An advisory parser finding must not block posting' ).
        cl_abap_unit_assert=>assert_initial( act = VALUE #( ls_decision-findings[ rule_id = 'S12' ]-action OPTIONAL )
                                             msg = 'The advisory parser finding keeps a blank action' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A66: lines whose rule group had a PLUGIN_ERROR are unevaluated - counted as failed, never passed
  METHOD plugin_error_unevaluated.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-assign_fail_rule  = abap_true.
        ls_flags-lines_per_package = 2.
        configure_scenario( ls_flags ).
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-unevaluated exp = 2
                                            msg = 'Both lines of the failed group must be unevaluated' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-passed_items exp = 0
                                            msg = 'Unevaluated lines must never count as passed' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-failed_items exp = 2
                                            msg = 'Unevaluated lines count as failed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A66: a technical package failure feeds the breaker even below EBS_CB_MIN_LINES
  METHOD plugin_error_trips_breaker.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-assign_fail_rule = abap_true.
        ls_flags-packages         = 5.
        configure_scenario( ls_flags ).
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-status exp = zif_cd_ops_types=>gc_run_status-aborted
                                            msg = 'Three packages with a rule that could not run must abort the run' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-total_items exp = 3
                                            msg = 'Only the first three packages may be processed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A67: a blocker after the display cap (EBS_RESULT_MAX) still reaches the alert router
  METHOD blocker_after_cap_alerts.
    TRY.
        configure_scenario( default_flags( ) ).
        add_rule( iv_group = gc_test-group_new iv_id = 'R01' iv_class = gc_test-sign_class
                  iv_level = zif_cd_ebs_types=>gc_level-line ).
        ASSIGN mo_source->mt_packages[ 1 ] TO FIELD-SYMBOL(<ls_package>).
        INSERT VALUE #( object_type = 'STMT' object_key = 'S0001' rule_id = 'S05' check_code = 'TEST_WARNING'
                        severity = zif_cd_ops_types=>gc_severity-warning ) INTO TABLE <ls_package>-findings.
        INSERT VALUE #( object_type = 'STMT' object_key = 'S0001' rule_id = 'S02' check_code = 'TEST_BLOCKER'
                        severity = zif_cd_ops_types=>gc_severity-block ) INTO TABLE <ls_package>-findings.
        INSERT VALUE #( name = 'EBS_RESULT_MAX' value = '1' ) INTO TABLE mo_store->mt_params.
        run_engine( ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( ms_result-findings[ check_code = 'TEST_BLOCKER' ] ) )
          msg = 'The blocker must lie after the display cap in this scenario' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( mo_alert->mt_findings[ check_code = 'TEST_BLOCKER'
                                                              severity   = zif_cd_ops_types=>gc_severity-block ] ) )
          msg = 'A blocker after the cap must still be handed to the alert router' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A67: retained lines never exceed EBS_RESULT_MAX - not even by the rest of a package
  METHOD kept_lines_capped_exactly.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-lines_per_package = 3.
        configure_scenario( ls_flags ).
        INSERT VALUE #( name = 'EBS_RESULT_MAX' value = '2' ) INTO TABLE mo_store->mt_params.
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ms_result-lines ) exp = 2
                                            msg = 'Exactly EBS_RESULT_MAX lines may be retained' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-total_items exp = 3
                                            msg = 'Counts must still cover every line' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A68: a run that selected no statement is NO_DATA with RAG grey and a NO_DATA finding - not green
  METHOD empty_source_is_no_data.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-packages = 0.
        configure_scenario( ls_flags ).
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-status exp = zcl_cd_ebs_engine=>gc_status_no_data
                                            msg = 'An empty run must end NO_DATA' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-rag exp = zif_cd_ops_types=>gc_rag-grey
                                            msg = 'An empty run must be grey, not green' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( mo_store->mt_saved[ check_code = zif_cd_ebs_types=>gc_check_code-no_data ] ) )
          msg = 'The empty run must leave a saved NO_DATA finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A68: with EBS_EMPTY_FEED_OK = X an empty feed is intentional and closes green
  METHOD empty_feed_opt_in_green.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-packages = 0.
        configure_scenario( ls_flags ).
        INSERT VALUE #( name = zif_cd_ebs_types=>gc_param-empty_feed_ok value = abap_true ) INTO TABLE mo_store->mt_params.
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-status exp = zif_cd_ops_types=>gc_run_status-success
                                            msg = 'An intentionally empty feed closes successfully' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-rag exp = zif_cd_ops_types=>gc_rag-green
                                            msg = 'An intentionally empty feed is green' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( mo_store->mt_saved[ check_code = zif_cd_ebs_types=>gc_check_code-no_data ] ) )
          msg = 'No NO_DATA finding with the opt-in' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD first_disposition.
    TRY.
        DATA(ls_decision) = NEW zcl_cd_ebs_engine( )->validate_for_posting( iv_mode    = iv_mode
                                                                             is_package = mo_source->mt_packages[ 1 ] ).
        rv_disposition = VALUE #( ls_decision-dispositions[ 1 ]-disposition OPTIONAL ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Posting check raised: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD sign_scenario.
    DATA(ls_flags) = is_flags.
    ls_flags-assign_sign_rule = abap_true.
    configure_scenario( ls_flags ).
  ENDMETHOD.


  " A85: a mapped line that passed every rule is AUTO_POST
  METHOD disposition_auto_post.
    TRY.
        sign_scenario( default_flags( ) ).
        cl_abap_unit_assert=>assert_equals( act = first_disposition( ) exp = zif_cd_ops_types=>gc_action-auto_post
                                            msg = 'A clean mapped line must be AUTO_POST' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A85: an unmapped line (resolver BLOCK) is BLOCK in ENFORCE
  METHOD disposition_block.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-line_code = gc_test-code_unmap.
        configure_scenario( ls_flags ).
        cl_abap_unit_assert=>assert_equals( act = first_disposition( ) exp = zif_cd_ops_types=>gc_action-block
                                            msg = 'An unmapped line must be BLOCK' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A85: a map row with disposition NOT_POSTED (sweep) gives NOT_POSTED
  METHOD disposition_not_posted.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-map_disposition = zif_cd_ebs_types=>gc_disposition-not_posted.
        sign_scenario( ls_flags ).
        cl_abap_unit_assert=>assert_equals( act = first_disposition( ) exp = zif_cd_ebs_types=>gc_disposition-not_posted
                                            msg = 'A sweep line must be NOT_POSTED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A85: an advisory rule failure (action EXCEPTION, flag off) gives EXCEPTION - not BLOCK
  METHOD disposition_exception.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-wrong_sign = abap_true.
        sign_scenario( ls_flags ).
        cl_abap_unit_assert=>assert_equals( act = first_disposition( ) exp = zif_cd_ops_types=>gc_action-exception
                                            msg = 'An advisory failure must route the line to EXCEPTION' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A85: a map row with action ON_ACCOUNT gives ON_ACCOUNT when no finding is stronger
  METHOD disposition_on_account.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-map_action = zif_cd_ops_types=>gc_action-on_account.
        sign_scenario( ls_flags ).
        cl_abap_unit_assert=>assert_equals( act = first_disposition( ) exp = zif_cd_ops_types=>gc_action-on_account
                                            msg = 'An ON_ACCOUNT map row must give ON_ACCOUNT' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A85/A27: a failed blocking rule wins over NOT_POSTED (precedence BLOCK first)
  METHOD disposition_block_wins.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-map_disposition = zif_cd_ebs_types=>gc_disposition-not_posted.
        ls_flags-wrong_sign      = abap_true.
        sign_scenario( ls_flags ).
        mo_cfg->mt_rules[ rule_id = 'R01' ]-blocks_posting = abap_true.
        cl_abap_unit_assert=>assert_equals( act = first_disposition( ) exp = zif_cd_ops_types=>gc_action-block
                                            msg = 'BLOCK must take precedence over NOT_POSTED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A85: MONITOR never blocks - a would-be BLOCK line is handed over as EXCEPTION
  METHOD disposition_monitor_no_block.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-line_code = gc_test-code_unmap.
        configure_scenario( ls_flags ).
        cl_abap_unit_assert=>assert_equals( act = first_disposition( zcl_cd_ebs_engine=>gc_mode-monitor )
                                            exp = zif_cd_ops_types=>gc_action-exception
                                            msg = 'Monitor mode must never return BLOCK' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " In-flight grace: a line awaiting the lot transfer (W, NOTIFY) is held as EXCEPTION, never AUTO_POST
  METHOD disposition_awaiting_held.
    TRY.
        sign_scenario( default_flags( ) ).
        ASSIGN mo_source->mt_packages[ 1 ] TO FIELD-SYMBOL(<ls_package>).
        INSERT VALUE #( object_type = 'LINE'
                        object_key  = zcl_cd_ebs_finding=>line_key( <ls_package>-lines[ 1 ] )
                        rule_id     = 'R07R'
                        check_code  = zif_cd_ebs_types=>gc_check_code-awaiting_lot_transfer
                        severity    = zif_cd_ops_types=>gc_severity-warning
                        action      = zif_cd_ops_types=>gc_action-notify ) INTO TABLE <ls_package>-findings.
        cl_abap_unit_assert=>assert_equals( act = first_disposition( ) exp = zif_cd_ops_types=>gc_action-exception
                                            msg = 'A line awaiting the lot transfer must not be auto-posted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A64: validate_for_posting starts no run - it refreshes the parameter snapshot once per call
  METHOD posting_check_refreshes_params.
    TRY.
        sign_scenario( default_flags( ) ).
        first_disposition( ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_refreshes exp = 1
                                            msg = 'One parameter refresh per posting check' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A91: no TVARVC row - MONITOR with a KILL_SWITCH_FALLBACK diagnostic
  METHOD kill_switch_missing_monitor.
    DATA ls_diagnostic TYPE zif_cd_ops_types=>ty_finding.
    TEST-INJECTION tvarvc_read.
      lv_subrc = 4.
    END-TEST-INJECTION.
    DATA(lv_mode) = zcl_cd_ebs_engine=>read_mode( IMPORTING es_diagnostic = ls_diagnostic ).
    cl_abap_unit_assert=>assert_equals( act = lv_mode exp = zcl_cd_ebs_engine=>gc_mode-monitor
                                        msg = 'A missing switch must give MONITOR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_diagnostic-check_code
                                        exp = zif_cd_ebs_types=>gc_check_code-kill_switch_fallback
                                        msg = 'A missing switch must be diagnosed' ).
  ENDMETHOD.


  " A91: a value that is not E / M / O - MONITOR with a diagnostic
  METHOD kill_switch_invalid_monitor.
    DATA ls_diagnostic TYPE zif_cd_ops_types=>ty_finding.
    TEST-INJECTION tvarvc_read.
      lv_low = 'X'.
      lv_subrc = 0.
    END-TEST-INJECTION.
    DATA(lv_mode) = zcl_cd_ebs_engine=>read_mode( IMPORTING es_diagnostic = ls_diagnostic ).
    cl_abap_unit_assert=>assert_equals( act = lv_mode exp = zcl_cd_ebs_engine=>gc_mode-monitor
                                        msg = 'An invalid value must give MONITOR' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_diagnostic msg = 'An invalid value must be diagnosed' ).
  ENDMETHOD.


  " A91: OFF is read as OFF, without diagnostic
  METHOD kill_switch_off_read.
    DATA ls_diagnostic TYPE zif_cd_ops_types=>ty_finding.
    TEST-INJECTION tvarvc_read.
      lv_low = 'O'.
      lv_subrc = 0.
    END-TEST-INJECTION.
    DATA(lv_mode) = zcl_cd_ebs_engine=>read_mode( IMPORTING es_diagnostic = ls_diagnostic ).
    cl_abap_unit_assert=>assert_equals( act = lv_mode exp = zcl_cd_ebs_engine=>gc_mode-off
                                        msg = 'A maintained OFF must be honoured' ).
    cl_abap_unit_assert=>assert_initial( act = ls_diagnostic msg = 'A valid value needs no diagnostic' ).
  ENDMETHOD.


  " A91: a database error on the read - MONITOR with a diagnostic, never a dump
  METHOD kill_switch_sql_failure.
    DATA ls_diagnostic TYPE zif_cd_ops_types=>ty_finding.
    TEST-INJECTION tvarvc_read.
      IF lv_subrc = 0.
        RAISE EXCEPTION TYPE cx_sy_open_sql_db.
      ENDIF.
    END-TEST-INJECTION.
    TRY.
        DATA(lv_mode) = zcl_cd_ebs_engine=>read_mode( IMPORTING es_diagnostic = ls_diagnostic ).
        cl_abap_unit_assert=>assert_equals( act = lv_mode exp = zcl_cd_ebs_engine=>gc_mode-monitor
                                            msg = 'A failed read must give MONITOR' ).
        cl_abap_unit_assert=>assert_equals( act = ls_diagnostic-check_code
                                            exp = zif_cd_ebs_types=>gc_check_code-kill_switch_fallback
                                            msg = 'A failed read must be diagnosed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |read_mode must not raise: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " A98: blank-flow and '*' rows with contradictory actions reach the posting decision as BLOCK
  METHOD map_conflict_blocks_posting.
    TRY.
        sign_scenario( default_flags( ) ).
        DATA(ls_blank) = mo_cfg->mt_map[ 1 ].
        ls_blank-flow_type = space.
        ls_blank-action    = zif_cd_ops_types=>gc_action-on_account.
        INSERT ls_blank INTO TABLE mo_cfg->mt_map.
        DATA(ls_decision) = NEW zcl_cd_ebs_engine( )->validate_for_posting(
                              iv_mode    = zcl_cd_ebs_engine=>gc_mode-enforce
                              is_package = mo_source->mt_packages[ 1 ] ).
        cl_abap_unit_assert=>assert_true( act = ls_decision-block msg = 'Contradictory mapping must block posting' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_decision-findings[ check_code = zif_cd_ebs_types=>gc_check_code-map_conflict ] ) )
          msg = 'MAP_CONFLICT must be recorded' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( ls_decision-dispositions[ 1 ]-disposition OPTIONAL )
                                            exp = zif_cd_ops_types=>gc_action-block
                                            msg = 'The line disposition must be BLOCK' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD file_package.
    TRY.
        rs_package = NEW zcl_cd_ebs_src_file( iv_content   = iv_content
                                              iv_format    = zif_cd_ebs_types=>gc_format-bai2
                                              iv_file_name = `UNIT.BAI` )->zif_cd_ebs_source~next_package( ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Parsing raised: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD small_bai2.
    " 49 control total = 03 amounts + 16 amounts; record counts are physical records
    DATA(lv_extra_records) = COND i( WHEN iv_extra IS INITIAL THEN 0 ELSE 1 ).
    DATA(lv_total) = 300000 + iv_extra_amount.
    rv_content = |01,BANKSNDR,CUSTRCVR,261104,0630,1104U,80,,2/\n| &&
                 |02,CUSTRCVR,999000001,1,261103,2400,USD,2/\n| &&
                 |03,000123456789,USD,010,+100000,,,015,+150000,,/\n| &&
                 |16,165,50000,0,BR0001,INV0001,ACH CREDIT/\n| &&
                 COND string( WHEN iv_extra IS NOT INITIAL THEN |{ iv_extra }\n| ) &&
                 |49,+{ lv_total },{ 3 + lv_extra_records }/\n| &&
                 |98,+{ lv_total },1,{ 5 + lv_extra_records }/| &&
                 COND string( WHEN iv_no_99 = abap_false THEN |\n99,+{ lv_total },1,{ 7 + lv_extra_records }/| ).
  ENDMETHOD.


  " A95: a BAI2 file without 99 is blocked through the final ENFORCE decision
  METHOD missing_99_blocks_posting.
    TRY.
        sign_scenario( default_flags( ) ).
        DATA(ls_decision) = NEW zcl_cd_ebs_engine( )->validate_for_posting(
                              iv_mode    = zcl_cd_ebs_engine=>gc_mode-enforce
                              is_package = file_package( small_bai2( iv_no_99 = abap_true ) ) ).
        cl_abap_unit_assert=>assert_true( act = ls_decision-block
                                          msg = 'A file without its 99 trailer must not be posted' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( ls_decision-dispositions[ disposition = zif_cd_ops_types=>gc_action-auto_post ] ) )
          msg = 'No parsed line may be released for posting' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
