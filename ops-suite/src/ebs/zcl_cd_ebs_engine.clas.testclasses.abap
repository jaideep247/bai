*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_engine.clas.testclasses.abap
*& Purpose:
*& Application tests of the EBS engine with LTD_* doubles for the source,
*& customizing, store, alert router and a failing rule plug-in. Proves requirements
*& baseline acceptance tests 3 (new code by customizing) and 7 (unmapped code
*& always blocked). Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Run lock: held lock skips the run; lock released after the run.
*& 2026-11-06 | Exception carry-forward: package scope reconciled; skipped after a rule failure.
*& 2026-11-06 | Audit A03: empty and unusable rule groups.
*& 2026-11-06 | Audit A66/A67/A68: unevaluated lines, technical breaker, alert after cap, exact line cap, NO_DATA run.
*& 2026-11-06 | Audit A98: contradictory blank / * map rows are recorded as MAP_CONFLICT.
*& 2026-11-06 | Audit A95: missing 99 recorded as MISSING_TRAILER (parsed BAI2 file).
*& 2026-11-06 | Audit A97: end-to-end parser-to-engine tests (configuration-only code, informational code); dispatch test commented.
*& 2026-11-06 | Operating model: LTC_POSTING_STATE - posted / unposted / NOT_POSTED entries, file source,
*&            | POSTING_INCOMPLETE once per statement, never green, no reconciliation of skipped entries.
*& 2026-11-06 | Return / NOC reason correction: R05 (NEEDS_POSTING) skips an entry that is not posted yet.
*& 2026-11-06 | Performance: LTC_REGISTER_MEMO - the same statements validated twice read DFKKCR twice.
*& 2026-11-06 | Payment engine account scope: LTD_CFG returns accounts; LTC_POSTING_STATE lines carry
*&            | a payment engine XBLNR; LTC_PE_SCOPE - mixed statement skipped and counted, no findings,
*&            | no reconciliation; all-PE statement validated.
*& 2026-11-06 | findings_of: prefix test with find( ) instead of a CP wildcard (no CP / NP in the suite).
*& 2026-11-07 | Store double: get_param / get_range delegate to the shared fake ZCL_CD_OPS_PARAMS_MEM
*&            | (semantics of ZCL_CD_OPS_STORE: condensed, blank = default).
*& 2026-11-07 | Read-only scope: pre-posting decision, kill switch, blocked-line release and
*&            | blocks-posting flag removed with their tests; configuration gap, map conflict,
*&            | missing trailer and end-to-end tests assert the findings of VALIDATE_PACKAGE.
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
    "! ZCD_EBS_ACCT rows (payment engine account scope)
    DATA mt_accounts TYPE zif_cd_ebs_types=>tt_account_cfg.
ENDCLASS.

CLASS ltd_cfg IMPLEMENTATION.
  METHOD zif_cd_ebs_cfg_dao~get_btc_map.
    rt_map = mt_map.
  ENDMETHOD.
  METHOD zif_cd_ebs_cfg_dao~get_rules.
    rt_rules = mt_rules.
  ENDMETHOD.
  METHOD zif_cd_ebs_cfg_dao~get_accounts.
    rt_accounts = mt_accounts.
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
  METHOD zif_cd_ops_params~refresh_params.
  ENDMETHOD.
  METHOD zif_cd_ops_params~get_param.
    " Shared parameter fake: exactly the read semantics of ZCL_CD_OPS_STORE
    rv_value = NEW zcl_cd_ops_params_mem( mt_params )->zif_cd_ops_params~get_param( iv_name    = iv_name
                                                                                     iv_default = iv_default ).
  ENDMETHOD.
  METHOD zif_cd_ops_params~get_range.
    rt_range = NEW zcl_cd_ops_params_mem( mt_params )->zif_cd_ops_params~get_range( iv_name ).
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
  ENDMETHOD.
  METHOD zif_cd_ops_alert~dispatch.
    mv_dispatched += 1.
    mt_findings = it_findings.
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
    METHODS held_lock_skips_run          FOR TESTING.
    METHODS lock_released_after_run      FOR TESTING.
    METHODS validated_lines_reconciled   FOR TESTING.
    METHODS failed_rule_skips_reconcile  FOR TESTING.
    METHODS map_conflict_is_recorded     FOR TESTING.
    METHODS missing_99_is_recorded       FOR TESTING.
    METHODS e2e_config_only_code_routed  FOR TESTING.
    METHODS e2e_info_code_no_line        FOR TESTING.
    "! A97: map row and rule assignment for BAI2 165 / 890 in group CFGONLY - configuration only
    METHODS configure_code
      IMPORTING
        iv_code TYPE zif_cd_ebs_types=>ty_btc_code.
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
    METHODS plugin_error_unevaluated     FOR TESTING.
    METHODS plugin_error_trips_breaker   FOR TESTING.
    METHODS blocker_after_cap_alerts     FOR TESTING.
    METHODS kept_lines_capped_exactly    FOR TESTING.
    METHODS empty_source_is_no_data      FOR TESTING.
    METHODS empty_feed_opt_in_green      FOR TESTING.
    METHODS empty_rule_group_is_gap      FOR TESTING.
    METHODS none_row_makes_group_optional FOR TESTING.
    METHODS unusable_rule_is_gap         FOR TESTING.
    "! Findings of VALIDATE_PACKAGE for a package (default: the first package of the source)
    METHODS validate
      IMPORTING
        is_package         TYPE zif_cd_ebs_types=>ty_package OPTIONAL
      EXPORTING
        es_package         TYPE zif_cd_ebs_types=>ty_package
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding.
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


  " Acceptance test 3 - ENGINE DISPATCH ONLY: a normalised line (synthetic code 987, no parser)
  " is routed by configuration to its rule group. The parser-to-engine proof with a real
  " BAI2 file is e2e_config_only_code_posts (A97)
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


  METHOD validate.
    es_package = COND #( WHEN is_package IS SUPPLIED THEN is_package ELSE mo_source->mt_packages[ 1 ] ).
    TRY.
        rt_findings = NEW zcl_cd_ebs_engine( )->validate_package( CHANGING cs_package = es_package ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Validation raised: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " A03: a mapped rule group without any usable rule is a configuration gap - never a silent pass
  METHOD empty_rule_group_is_gap.
    TRY.
        configure_scenario( default_flags( ) ).
        DATA(lt_findings) = validate( ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( lt_findings[ check_code = zif_cd_ebs_types=>gc_check_code-rule_group_empty ] ) )
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
        DATA(lt_findings) = validate( ).
        cl_abap_unit_assert=>assert_initial( act = lt_findings
                                             msg = 'An explicitly optional group raises no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A03: an assignment whose rule definition is missing or inactive never silently disappears
  METHOD unusable_rule_is_gap.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-assign_sign_rule = abap_true.
        ls_flags-wrong_sign       = abap_true.
        configure_scenario( ls_flags ).
        mo_cfg->mt_rules[ 1 ]-unusable = abap_true.
        DATA(lt_findings) = validate( ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( lt_findings[ check_code = zif_cd_ebs_types=>gc_check_code-rule_unusable ] ) )
          msg = 'The gap must be recorded as RULE_UNUSABLE' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( lt_findings[ check_code = zif_cd_ebs_types=>gc_check_code-sign_mismatch ] ) )
          msg = 'An unusable rule must not be executed' ).
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


  " A98: blank-flow and '*' rows with contradictory actions are recorded as MAP_CONFLICT (action BLOCK)
  METHOD map_conflict_is_recorded.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-assign_sign_rule = abap_true.
        configure_scenario( ls_flags ).
        DATA(ls_blank) = mo_cfg->mt_map[ 1 ].
        ls_blank-flow_type = space.
        ls_blank-action    = zif_cd_ops_types=>gc_action-on_account.
        INSERT ls_blank INTO TABLE mo_cfg->mt_map.
        DATA(lt_findings) = validate( ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( lt_findings[ check_code = zif_cd_ebs_types=>gc_check_code-map_conflict ]-action OPTIONAL )
          exp = zif_cd_ops_types=>gc_action-block
          msg = 'MAP_CONFLICT must be recorded with action BLOCK' ).
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


  " A95: a BAI2 file without 99 is recorded as MISSING_TRAILER - a missing trailer never self-satisfies
  METHOD missing_99_is_recorded.
    TRY.
        " The code is mapped and valid - only the missing trailer can raise a finding
        configure_code( '165' ).
        DATA(lt_findings) = validate( file_package( small_bai2( iv_no_99 = abap_true ) ) ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( lt_findings[ check_code = 'MISSING_TRAILER' ] ) )
          msg = 'The missing 99 trailer must be recorded' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD configure_code.
    INSERT VALUE #( scheme = zif_cd_ebs_types=>gc_scheme-bai2 btc_code = iv_code flow_type = zif_cd_ebs_types=>gc_flow-any
                    category = 'C01' rule_group = 'CFGONLY' exp_cdi = zif_cd_ebs_types=>gc_cdi-credit
                    active = abap_true ) INTO TABLE mo_cfg->mt_map.
    IF NOT line_exists( mo_cfg->mt_rules[ rule_group = 'CFGONLY' ] ).
      add_rule( iv_group = 'CFGONLY' iv_id = 'R01' iv_class = gc_test-sign_class
                iv_level = zif_cd_ebs_types=>gc_level-line ).
    ENDIF.
  ENDMETHOD.


  " A97 end to end: BAI2 file text -> ZCL_CD_EBS_PARSER_BAI2 -> file source -> engine. A monetary
  " code mapped only by configuration (map row + rule row) is routed and validated without a blocker
  METHOD e2e_config_only_code_routed.
    TRY.
        configure_code( '165' ).
        DATA(lt_findings) = validate( EXPORTING is_package = file_package( small_bai2( ) )
                                      IMPORTING es_package = DATA(ls_package) ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE string_table( FOR l IN ls_package-lines ( |{ l-btc_code }/{ l-rule_group }| ) )
          exp = VALUE string_table( ( `165/CFGONLY` ) )
          msg = 'The parsed line must be routed by configuration only' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( lt_findings[ severity = zif_cd_ops_types=>gc_severity-block ] )
                      OR line_exists( lt_findings[ action = zif_cd_ops_types=>gc_action-block ] ) )
          msg = 'A configured, valid entry must raise no blocker' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A97 negative: an informational BAI2 code (7xx-9xx, here 890) never becomes a line even when
  " a map row exists - the parser does not emit it, so configuration alone cannot validate it
  METHOD e2e_info_code_no_line.
    TRY.
        configure_code( '165' ).
        configure_code( '890' ).
        validate( EXPORTING is_package = file_package( small_bai2( iv_extra = `16,890,,,BR0002,,INFO ONLY/` ) )
                  IMPORTING es_package = DATA(ls_package) ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_package-lines[ btc_code = '890' ] ) )
                                           msg = 'An informational code must never become a line' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_package-lines ) exp = 1
                                            msg = 'Only the monetary entry is a line' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! Operating model 2026-11-06: rule double that records the lines and statements it is given
CLASS ltd_probe_rule DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_rule.
    DATA mt_lines      TYPE zif_cd_ebs_types=>tt_line.
    DATA mt_statements TYPE zif_cd_ebs_types=>tt_statement.
ENDCLASS.

CLASS ltd_probe_rule IMPLEMENTATION.
  METHOD zif_cd_ebs_rule~execute.
    INSERT LINES OF it_lines INTO TABLE mt_lines.
    INSERT LINES OF it_statements INTO TABLE mt_statements.
  ENDMETHOD.
ENDCLASS.


"! Operating model 2026-11-06 (post-posting detective control): an imported entry that is
"! expected to post but is not posted is not evaluated by the posting-dependent rules
"! (NEEDS_POSTING), is counted as unevaluated, gets one POSTING_INCOMPLETE per statement
"! (rule S13) and keeps the run from being green. Does not prove live SAP runtime behavior.
CLASS ltc_posting_state DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        group       TYPE zif_cd_ebs_types=>ty_rule_group VALUE 'NEWBANK',
        code        TYPE zif_cd_ebs_types=>ty_btc_code VALUE '987',
        dep_class   TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_TEST_POSTED_PROBE',
        indep_class TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_TEST_INDEP_PROBE',
        stmt_class  TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_TEST_STMT_PROBE',
        s13_class   TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_EBS_R_S13_POSTED',
        s13_id      TYPE zif_cd_ops_types=>ty_rule_id VALUE 'S13',
        stmt_key    TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'FEB00001001',
        "! Payment engine account scope: every line carries an active configured account
        pe_account  TYPE zif_cd_ebs_types=>ty_text35 VALUE '8XX1174412',
        xblnr       TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'JPMC8XX1174412334',
      END OF gc_test.

    TYPES:
      BEGIN OF ty_flags,
        "! FEB (imported statement) or FILE (bank file before import)
        source        TYPE zif_cd_ebs_types=>ty_source,
        "! Posting state of every line: P posted, O open, blank unknown
        posting_state TYPE c LENGTH 1,
        lines         TYPE i,
        "! Map row disposition NOT_POSTED (e.g. 275 / 575 sweeps)
        not_posted    TYPE abap_bool,
        "! Severity of the S13 assignment (blank = W, the seed default)
        s13_severity  TYPE zif_cd_ops_types=>ty_severity,
      END OF ty_flags.

    DATA mo_source    TYPE REF TO ltd_source.
    DATA mo_cfg       TYPE REF TO ltd_cfg.
    DATA mo_store     TYPE REF TO ltd_store.
    DATA mo_dep_rule  TYPE REF TO ltd_probe_rule.
    DATA mo_ind_rule  TYPE REF TO ltd_probe_rule.
    DATA mo_stmt_rule TYPE REF TO ltd_probe_rule.
    DATA ms_result    TYPE zcl_cd_ebs_engine=>ty_result.

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
        iv_group         TYPE zif_cd_ebs_types=>ty_rule_group
        iv_id            TYPE zif_cd_ops_types=>ty_rule_id
        iv_class         TYPE zif_cd_ops_types=>ty_class_name
        iv_level         TYPE char1
        iv_needs_posting TYPE abap_bool
        iv_severity      TYPE zif_cd_ops_types=>ty_severity DEFAULT zif_cd_ops_types=>gc_severity-error.
    METHODS run_engine.
    METHODS count_code
      IMPORTING
        iv_check_code   TYPE zif_cd_ops_types=>ty_check_code
      RETURNING
        VALUE(rv_count) TYPE i.

    METHODS posted_entry_runs_all_rules  FOR TESTING.
    METHODS open_entry_skips_dep_rules   FOR TESTING.
    METHODS open_entry_is_unevaluated    FOR TESTING.
    METHODS open_entries_one_finding     FOR TESTING.
    METHODS open_entry_run_never_green   FOR TESTING.
    METHODS open_entry_indep_rules_run   FOR TESTING.
    METHODS not_posted_map_no_finding    FOR TESTING.
    METHODS file_source_rules_unchanged  FOR TESTING.
    METHODS open_entry_not_reconciled    FOR TESTING.
    METHODS r05_skips_unposted_entry     FOR TESTING.
ENDCLASS.


CLASS ltc_posting_state IMPLEMENTATION.

  METHOD setup.
    mo_source    = NEW #( ).
    mo_cfg       = NEW #( ).
    mo_store     = NEW #( ).
    mo_dep_rule  = NEW #( ).
    mo_ind_rule  = NEW #( ).
    mo_stmt_rule = NEW #( ).
    zcl_cd_ops_injector=>inject_lock( NEW ltd_lock( ) ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
    zcl_cd_ops_injector=>inject_alert( NEW ltd_alert( ) ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    zcl_cd_ops_injector=>inject_plugin( iv_class_name = gc_test-dep_class io_instance = mo_dep_rule ).
    zcl_cd_ops_injector=>inject_plugin( iv_class_name = gc_test-indep_class io_instance = mo_ind_rule ).
    zcl_cd_ops_injector=>inject_plugin( iv_class_name = gc_test-stmt_class io_instance = mo_stmt_rule ).
    zcl_cd_ebs_injector=>inject_cfg_dao( mo_cfg ).
    CLEAR ms_result.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_ebs_injector=>reset( ).
    CLEAR: mo_source, mo_cfg, mo_store, mo_dep_rule, mo_ind_rule, mo_stmt_rule.
  ENDMETHOD.


  METHOD default_flags.
    rs_flags-source        = zif_cd_ebs_types=>gc_source-feb.
    rs_flags-posting_state = zif_cd_ebs_types=>gc_posting_state-posted.
    rs_flags-lines         = 1.
  ENDMETHOD.


  METHOD add_rule.
    DATA ls_rule TYPE zif_cd_ebs_types=>ty_rule_cfg.
    ls_rule-rule_group    = iv_group.
    ls_rule-rule_id       = iv_id.
    ls_rule-class_name    = iv_class.
    ls_rule-level         = iv_level.
    ls_rule-severity      = iv_severity.
    ls_rule-action        = zif_cd_ops_types=>gc_action-notify.
    ls_rule-active        = abap_true.
    ls_rule-needs_posting = iv_needs_posting.
    INSERT ls_rule INTO TABLE mo_cfg->mt_rules.
  ENDMETHOD.


  " Map row for the code, the S13 rule, a posting-dependent statement rule (as R18 / S10), a
  " posting-dependent line rule (as R19 / R07R) and an independent line rule (as R01) - and
  " one statement whose lines all carry the posting state of the scenario
  METHOD configure_scenario.
    DATA ls_map     TYPE zif_cd_ebs_types=>ty_btc_map.
    DATA ls_package TYPE zif_cd_ebs_types=>ty_package.
    DATA ls_stmt    TYPE zif_cd_ebs_types=>ty_statement.
    DATA ls_line    TYPE zif_cd_ebs_types=>ty_line.
    DATA ls_account TYPE zif_cd_ebs_types=>ty_account_cfg.

    ls_account-account_no = gc_test-pe_account.
    ls_account-active     = abap_true.
    INSERT ls_account INTO TABLE mo_cfg->mt_accounts.

    ls_map-scheme      = zif_cd_ebs_types=>gc_scheme-bai2.
    ls_map-btc_code    = gc_test-code.
    ls_map-flow_type   = zif_cd_ebs_types=>gc_flow-any.
    ls_map-category    = 'D01'.
    ls_map-rule_group  = gc_test-group.
    ls_map-exp_cdi     = zif_cd_ebs_types=>gc_cdi-credit.
    ls_map-active      = abap_true.
    ls_map-disposition = COND #( WHEN is_flags-not_posted = abap_true THEN zif_cd_ebs_types=>gc_disposition-not_posted ).
    INSERT ls_map INTO TABLE mo_cfg->mt_map.

    add_rule( iv_group         = zif_cd_ebs_types=>gc_rule_group_all
              iv_id            = gc_test-s13_id
              iv_class         = gc_test-s13_class
              iv_level         = zif_cd_ebs_types=>gc_level-statement
              iv_needs_posting = abap_false
              iv_severity      = COND #( WHEN is_flags-s13_severity IS INITIAL
                                         THEN zif_cd_ops_types=>gc_severity-warning
                                         ELSE is_flags-s13_severity ) ).
    add_rule( iv_group = zif_cd_ebs_types=>gc_rule_group_all iv_id = 'R18' iv_class = gc_test-stmt_class
              iv_level = zif_cd_ebs_types=>gc_level-statement iv_needs_posting = abap_true ).
    add_rule( iv_group = gc_test-group iv_id = 'R19' iv_class = gc_test-dep_class
              iv_level = zif_cd_ebs_types=>gc_level-line iv_needs_posting = abap_true ).
    add_rule( iv_group = gc_test-group iv_id = 'R01' iv_class = gc_test-indep_class
              iv_level = zif_cd_ebs_types=>gc_level-line iv_needs_posting = abap_false ).

    ls_stmt-stmt_key  = COND #( WHEN is_flags-source = zif_cd_ebs_types=>gc_source-feb THEN gc_test-stmt_key
                                ELSE 'S0001' ).
    ls_stmt-source    = is_flags-source.
    ls_stmt-currency  = 'USD'.
    ls_stmt-stmt_date = '20261105'.
    INSERT ls_stmt INTO TABLE ls_package-statements.
    DO is_flags-lines TIMES.
      CLEAR ls_line.
      ls_line-stmt_key      = ls_stmt-stmt_key.
      ls_line-line_no       = sy-index.
      ls_line-scheme        = zif_cd_ebs_types=>gc_scheme-bai2.
      ls_line-btc_code      = gc_test-code.
      ls_line-cdi           = zif_cd_ebs_types=>gc_cdi-credit.
      ls_line-amount        = '10.00'.
      ls_line-currency      = 'USD'.
      ls_line-reference     = |REF{ sy-index }|.
      ls_line-xblnr         = gc_test-xblnr.
      ls_line-posting_state = is_flags-posting_state.
      INSERT ls_line INTO TABLE ls_package-lines.
    ENDDO.
    INSERT ls_package INTO TABLE mo_source->mt_packages.
  ENDMETHOD.


  METHOD run_engine.
    TRY.
        ms_result = NEW zcl_cd_ebs_engine( )->run( io_source = mo_source iv_variant = 'UNIT' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Engine run raised: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD count_code.
    rv_count = REDUCE i( INIT lv_n = 0 FOR ls_f IN ms_result-findings WHERE ( check_code = iv_check_code )
                         NEXT lv_n = lv_n + 1 ).
  ENDMETHOD.


  " A posted entry: every rule runs, nothing is unevaluated, no POSTING_INCOMPLETE, green
  METHOD posted_entry_runs_all_rules.
    TRY.
        configure_scenario( default_flags( ) ).
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dep_rule->mt_lines ) exp = 1
                                            msg = 'A posting-dependent line rule must validate a posted entry' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_stmt_rule->mt_statements ) exp = 1
                                            msg = 'A posting-dependent statement rule must validate a posted statement' ).
        cl_abap_unit_assert=>assert_equals( act = count_code( zif_cd_ebs_types=>gc_check_code-posting_incomplete ) exp = 0
                                            msg = 'A posted entry must not raise POSTING_INCOMPLETE' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-posting_open exp = 0
                                            msg = 'A posted entry is fully evaluated' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-passed_items exp = 1
                                            msg = 'A posted entry without findings passes' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-rag exp = zif_cd_ops_types=>gc_rag-green
                                            msg = 'A fully posted, clean statement closes green' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " An entry expected to post but not posted: posting-dependent rules (line and statement)
  " never see it - no false 'FI document not found' before FEBP has finished
  METHOD open_entry_skips_dep_rules.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-posting_state = zif_cd_ebs_types=>gc_posting_state-open.
        configure_scenario( ls_flags ).
        run_engine( ).
        cl_abap_unit_assert=>assert_initial( act = mo_dep_rule->mt_lines
                                             msg = 'A posting-dependent line rule must not see an unposted entry' ).
        cl_abap_unit_assert=>assert_initial( act = mo_stmt_rule->mt_statements
                                             msg = 'A posting-dependent statement rule must skip the incomplete statement' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The skipped entry is counted and reported as unevaluated - never passed, never failed
  METHOD open_entry_is_unevaluated.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-posting_state = zif_cd_ebs_types=>gc_posting_state-open.
        ls_flags-lines         = 2.
        configure_scenario( ls_flags ).
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-posting_open exp = 2
                                            msg = 'Both unposted entries must be counted as posting-open' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-unevaluated exp = 2
                                            msg = 'Posting-open entries are unevaluated' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-passed_items exp = 0
                                            msg = 'An unevaluated entry must never count as passed' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-failed_items exp = 0
                                            msg = 'An entry whose posting checks did not run must not count as failed' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-total_items exp = 2
                                            msg = 'Unevaluated entries still count in the total' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " One statement-level POSTING_INCOMPLETE (rule S13) for the statement, however many of its
  " entries are open, with the configured severity
  METHOD open_entries_one_finding.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-posting_state = zif_cd_ebs_types=>gc_posting_state-open.
        ls_flags-lines         = 3.
        configure_scenario( ls_flags ).
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = count_code( zif_cd_ebs_types=>gc_check_code-posting_incomplete ) exp = 1
                                            msg = 'One POSTING_INCOMPLETE per statement expected' ).
        DATA(ls_finding) = ms_result-findings[ check_code = zif_cd_ebs_types=>gc_check_code-posting_incomplete ].
        cl_abap_unit_assert=>assert_equals( act = ls_finding-object_type exp = zcl_cd_ebs_finding=>gc_object_type-statement
                                            msg = 'POSTING_INCOMPLETE is a statement finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = CONV zif_cd_ops_types=>ty_object_key( gc_test-stmt_key )
                                            msg = 'POSTING_INCOMPLETE must name the statement' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'Severity comes from the S13 rule configuration' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-rule_id exp = gc_test-s13_id
                                            msg = 'POSTING_INCOMPLETE is raised by rule S13' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A run with entries not evaluated for posting is never green - even if S13 were configured
  " with severity I (information)
  METHOD open_entry_run_never_green.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-posting_state = zif_cd_ebs_types=>gc_posting_state-open.
        ls_flags-s13_severity  = zif_cd_ops_types=>gc_severity-info.
        configure_scenario( ls_flags ).
        run_engine( ).
        cl_abap_unit_assert=>assert_differs( act = ms_result-run-rag exp = zif_cd_ops_types=>gc_rag-green
                                             msg = 'A run with POSTING_INCOMPLETE must never be green' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-rag exp = zif_cd_ops_types=>gc_rag-amber
                                            msg = 'Incomplete posting without other findings is amber' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rules that do not depend on the posting (structure, balance, sign, value date, mapping)
  " still validate the unposted entry
  METHOD open_entry_indep_rules_run.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-posting_state = zif_cd_ebs_types=>gc_posting_state-open.
        configure_scenario( ls_flags ).
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_ind_rule->mt_lines ) exp = 1
                                            msg = 'An independent rule must still validate the unposted entry' ).
        cl_abap_unit_assert=>assert_true( act = mo_ind_rule->mt_lines[ 1 ]-posting_open
                                          msg = 'The engine marks the entry as expected to post but not posted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Return / NOC reason correction: on the FEB source R05 reads the returns / NOC lot, which
  " exists only after return processing - seeded NEEDS_POSTING (config/zcd_ebs_rule_def.csv),
  " so an entry expected to post but not posted never reaches R05 (no false REASON_*)
  METHOD r05_skips_unposted_entry.
    DATA(lo_r05) = NEW ltd_probe_rule( ).
    TRY.
        zcl_cd_ops_injector=>inject_plugin( iv_class_name = 'ZCL_CD_EBS_R_R05_REASON' io_instance = lo_r05 ).
        DATA(ls_flags) = default_flags( ).
        ls_flags-posting_state = zif_cd_ebs_types=>gc_posting_state-open.
        configure_scenario( ls_flags ).
        add_rule( iv_group = gc_test-group iv_id = 'R05' iv_class = 'ZCL_CD_EBS_R_R05_REASON'
                  iv_level = zif_cd_ebs_types=>gc_level-line iv_needs_posting = abap_true ).
        run_engine( ).
        cl_abap_unit_assert=>assert_initial( act = lo_r05->mt_lines
                                             msg = 'R05 must not see an entry whose posting is not complete' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-posting_open exp = 1
                                            msg = 'The entry is counted as not evaluated' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A26: an entry mapped NOT_POSTED (sweeps 275 / 575) is not expected to post - unposted is
  " complete: no POSTING_INCOMPLETE, nothing unevaluated
  METHOD not_posted_map_no_finding.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-posting_state = zif_cd_ebs_types=>gc_posting_state-open.
        ls_flags-not_posted    = abap_true.
        configure_scenario( ls_flags ).
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = count_code( zif_cd_ebs_types=>gc_check_code-posting_incomplete ) exp = 0
                                            msg = 'A NOT_POSTED entry left unposted must not raise POSTING_INCOMPLETE' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-posting_open exp = 0
                                            msg = 'A NOT_POSTED entry is not posting-open' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dep_rule->mt_lines ) exp = 1
                                            msg = 'Rules of a NOT_POSTED entry run as before' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Bank file before import: the posting state is unknown by definition - the posting-dependent
  " rules behave as before (they run), no POSTING_INCOMPLETE, nothing unevaluated
  METHOD file_source_rules_unchanged.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-source        = zif_cd_ebs_types=>gc_source-file.
        ls_flags-posting_state = zif_cd_ebs_types=>gc_posting_state-unknown.
        configure_scenario( ls_flags ).
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dep_rule->mt_lines ) exp = 1
                                            msg = 'A file entry must reach the posting-dependent rule as before' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_stmt_rule->mt_statements ) exp = 1
                                            msg = 'A file statement must reach the posting-dependent statement rule' ).
        cl_abap_unit_assert=>assert_equals( act = count_code( zif_cd_ebs_types=>gc_check_code-posting_incomplete ) exp = 0
                                            msg = 'A bank file must never raise POSTING_INCOMPLETE' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-unevaluated exp = 0
                                            msg = 'Nothing of a bank file is unevaluated for posting' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Exceptions of earlier runs for an unposted entry and its statement stay open: a skipped
  " check is never a 'passed on re-run'
  METHOD open_entry_not_reconciled.
    TRY.
        DATA(ls_flags) = default_flags( ).
        ls_flags-posting_state = zif_cd_ebs_types=>gc_posting_state-open.
        configure_scenario( ls_flags ).
        DATA(ls_line) = mo_source->mt_packages[ 1 ]-lines[ 1 ].
        run_engine( ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( mo_store->mt_reconciled[ table_line = zcl_cd_ebs_finding=>line_key( ls_line ) ] ) )
          msg = 'An unposted entry must not be reconciled' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( mo_store->mt_reconciled[ table_line = CONV zif_cd_ops_types=>ty_object_key(
                                                                                gc_test-stmt_key ) ] ) )
          msg = 'A statement with an unposted entry must not be reconciled' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! Check-register reads of the cheque rules counted (DFKKCR double)
CLASS ltd_register_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_sap_dao PARTIALLY IMPLEMENTED.
    DATA mv_check_reads TYPE i.
ENDCLASS.

CLASS ltd_register_dao IMPLEMENTATION.
  METHOD zif_cd_ebs_sap_dao~get_checks.
    mv_check_reads += 1.
    CLEAR rt_checks.
  ENDMETHOD.
ENDCLASS.


"! Performance fix 1 note: the DFKKCR memo of R07C / R08 / R12 is bound to the statement keys
"! of a package. validate_package( ) clears it first, so validating the same statement set a
"! second time in one session reads the register again (no stale rows). Does not prove live
"! SAP runtime behavior.
CLASS ltc_register_memo DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        group    TYPE zif_cd_ebs_types=>ty_rule_group VALUE 'CHEQUES',
        code     TYPE zif_cd_ebs_types=>ty_btc_code VALUE '475',
        r07c     TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_EBS_R_R07C_CHECK',
        stmt_key TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'S0001',
      END OF gc_test.

    DATA mo_cfg TYPE REF TO ltd_cfg.
    DATA mo_dao TYPE REF TO ltd_register_dao.

    METHODS setup.
    METHODS teardown.
    METHODS package
      RETURNING
        VALUE(rs_package) TYPE zif_cd_ebs_types=>ty_package.

    METHODS same_statements_reread      FOR TESTING.
ENDCLASS.


CLASS ltc_register_memo IMPLEMENTATION.

  METHOD setup.
    DATA ls_map TYPE zif_cd_ebs_types=>ty_btc_map.
    DATA ls_rule TYPE zif_cd_ebs_types=>ty_rule_cfg.
    mo_cfg = NEW #( ).
    mo_dao = NEW #( ).
    zcl_cd_ops_injector=>inject_store( NEW ltd_store( ) ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    zcl_cd_ebs_injector=>inject_cfg_dao( mo_cfg ).
    zcl_cd_ebs_injector=>inject_sap_dao( mo_dao ).
    ls_map-scheme     = zif_cd_ebs_types=>gc_scheme-bai2.
    ls_map-btc_code   = gc_test-code.
    ls_map-flow_type  = zif_cd_ebs_types=>gc_flow-any.
    ls_map-category   = 'D03'.
    ls_map-rule_group = gc_test-group.
    ls_map-exp_cdi    = zif_cd_ebs_types=>gc_cdi-debit.
    ls_map-active     = abap_true.
    INSERT ls_map INTO TABLE mo_cfg->mt_map.
    ls_rule-rule_group = gc_test-group.
    ls_rule-rule_id    = 'R07C'.
    ls_rule-class_name = gc_test-r07c.
    ls_rule-level      = zif_cd_ebs_types=>gc_level-line.
    ls_rule-severity   = zif_cd_ops_types=>gc_severity-error.
    ls_rule-action     = zif_cd_ops_types=>gc_action-exception.
    ls_rule-active     = abap_true.
    INSERT ls_rule INTO TABLE mo_cfg->mt_rules.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_ebs_injector=>reset( ).
    CLEAR: mo_cfg, mo_dao.
  ENDMETHOD.


  METHOD package.
    DATA ls_stmt TYPE zif_cd_ebs_types=>ty_statement.
    DATA ls_line TYPE zif_cd_ebs_types=>ty_line.
    ls_stmt-stmt_key  = gc_test-stmt_key.
    ls_stmt-source    = zif_cd_ebs_types=>gc_source-file.
    ls_stmt-currency  = 'USD'.
    ls_stmt-stmt_date = '20261105'.
    INSERT ls_stmt INTO TABLE rs_package-statements.
    ls_line-stmt_key  = gc_test-stmt_key.
    ls_line-line_no   = 1.
    ls_line-scheme    = zif_cd_ebs_types=>gc_scheme-bai2.
    ls_line-btc_code  = gc_test-code.
    ls_line-cdi       = zif_cd_ebs_types=>gc_cdi-debit.
    ls_line-amount    = '10.00'.
    ls_line-currency  = 'USD'.
    ls_line-reference = '10045'.
    INSERT ls_line INTO TABLE rs_package-lines.
  ENDMETHOD.


  " The same statement set validated twice in one session: the register is read each time
  METHOD same_statements_reread.
    TRY.
        DATA(lo_cut) = NEW zcl_cd_ebs_engine( ).
        DATA(ls_first) = package( ).
        lo_cut->validate_package( CHANGING cs_package = ls_first ).
        DATA(ls_second) = package( ).
        lo_cut->validate_package( CHANGING cs_package = ls_second ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_check_reads exp = 2
                                            msg = 'A second validation of the same statements must read DFKKCR again' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! Payment engine account scope (user decision 2026-11-06): an imported statement is validated
"! only when every line's XBLNR carries an active configured payment engine account. A mixed
"! statement is skipped entirely - no statement or line rule, no finding (not even S04 or
"! R14), no reconciliation of its earlier exceptions - and counted as out of scope in the
"! result and the run message. Does not prove live SAP runtime behavior.
CLASS ltc_pe_scope DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        group      TYPE zif_cd_ebs_types=>ty_rule_group VALUE 'PESCOPE',
        code       TYPE zif_cd_ebs_types=>ty_btc_code VALUE '987',
        unmapped   TYPE zif_cd_ebs_types=>ty_btc_code VALUE '999',
        line_class TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_TEST_SCOPE_LINE',
        stmt_class TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_TEST_SCOPE_STMT',
        s04_class  TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_EBS_R_S04_ACCOUNT',
        s04_id     TYPE zif_cd_ops_types=>ty_rule_id VALUE 'S04',
        stmt_id    TYPE zif_cd_ops_types=>ty_rule_id VALUE 'S99',
        line_id    TYPE zif_cd_ops_types=>ty_rule_id VALUE 'R99',
        stmt_in    TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'FEB00002001',
        stmt_mixed TYPE zif_cd_ebs_types=>ty_stmt_key VALUE 'FEB00002002',
        pe_account TYPE zif_cd_ebs_types=>ty_text35 VALUE '8XX1174412',
        xblnr_pe   TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'JPMC8XX1174412334',
        xblnr_pe_2 TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'JPMC8XX1174412335',
        xblnr_othr TYPE zif_cd_ebs_types=>ty_xblnr VALUE 'BOA9999999999001',
        bukrs      TYPE c LENGTH 4 VALUE 'US01',
        hbkid      TYPE c LENGTH 5 VALUE 'JPMC1',
        hktid      TYPE c LENGTH 5 VALUE 'DISB1',
        other_hkt  TYPE c LENGTH 5 VALUE 'OTHR1',
        currency   TYPE zif_cd_ops_types=>ty_currency VALUE 'USD',
      END OF gc_test.

    DATA mo_source    TYPE REF TO ltd_source.
    DATA mo_cfg       TYPE REF TO ltd_cfg.
    DATA mo_store     TYPE REF TO ltd_store.
    DATA mo_line_rule TYPE REF TO ltd_probe_rule.
    DATA mo_stmt_rule TYPE REF TO ltd_probe_rule.
    DATA ms_result    TYPE zcl_cd_ebs_engine=>ty_result.

    METHODS setup.
    METHODS teardown.
    "! One in-scope statement (every line a payment engine account) and, with iv_mixed, one
    "! statement of another house bank account whose second line is not a payment engine account
    "! and carries an unmapped code (would raise S04 and R14 if it were validated)
    METHODS configure_scenario
      IMPORTING
        iv_mixed    TYPE abap_bool
        iv_in_scope TYPE abap_bool DEFAULT abap_true.
    METHODS add_statement
      IMPORTING
        iv_stmt_key TYPE zif_cd_ebs_types=>ty_stmt_key
        iv_hktid    TYPE clike
      CHANGING
        cs_package  TYPE zif_cd_ebs_types=>ty_package.
    METHODS add_line
      IMPORTING
        iv_stmt_key TYPE zif_cd_ebs_types=>ty_stmt_key
        iv_xblnr    TYPE zif_cd_ebs_types=>ty_xblnr
        iv_code     TYPE zif_cd_ebs_types=>ty_btc_code DEFAULT gc_test-code
      CHANGING
        cs_package  TYPE zif_cd_ebs_types=>ty_package.
    METHODS run_engine.
    METHODS findings_of
      IMPORTING
        iv_stmt_key     TYPE zif_cd_ebs_types=>ty_stmt_key
      RETURNING
        VALUE(rv_count) TYPE i.

    METHODS all_pe_statement_validated   FOR TESTING.
    METHODS mixed_statement_skipped      FOR TESTING.
    METHODS mixed_statement_no_findings  FOR TESTING.
    METHODS mixed_statement_counted      FOR TESTING.
    METHODS mixed_statement_not_reconcil FOR TESTING.
    METHODS only_mixed_run_is_no_data    FOR TESTING.
ENDCLASS.


CLASS ltc_pe_scope IMPLEMENTATION.

  METHOD setup.
    mo_source    = NEW #( ).
    mo_cfg       = NEW #( ).
    mo_store     = NEW #( ).
    mo_line_rule = NEW #( ).
    mo_stmt_rule = NEW #( ).
    zcl_cd_ops_injector=>inject_lock( NEW ltd_lock( ) ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
    zcl_cd_ops_injector=>inject_alert( NEW ltd_alert( ) ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    zcl_cd_ops_injector=>inject_plugin( iv_class_name = gc_test-line_class io_instance = mo_line_rule ).
    zcl_cd_ops_injector=>inject_plugin( iv_class_name = gc_test-stmt_class io_instance = mo_stmt_rule ).
    zcl_cd_ebs_injector=>inject_cfg_dao( mo_cfg ).
    CLEAR ms_result.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_ebs_injector=>reset( ).
    CLEAR: mo_source, mo_cfg, mo_store, mo_line_rule, mo_stmt_rule.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_map     TYPE zif_cd_ebs_types=>ty_btc_map.
    DATA ls_rule    TYPE zif_cd_ebs_types=>ty_rule_cfg.
    DATA ls_account TYPE zif_cd_ebs_types=>ty_account_cfg.
    DATA ls_package TYPE zif_cd_ebs_types=>ty_package.

    " Configured payment engine account: house bank account JPMC1 / DISB1, account 8XX1174412
    ls_account-bukrs      = gc_test-bukrs.
    ls_account-hbkid      = gc_test-hbkid.
    ls_account-hktid      = gc_test-hktid.
    ls_account-account_no = gc_test-pe_account.
    ls_account-currency   = gc_test-currency.
    ls_account-active     = abap_true.
    INSERT ls_account INTO TABLE mo_cfg->mt_accounts.

    ls_map-scheme     = zif_cd_ebs_types=>gc_scheme-bai2.
    ls_map-btc_code   = gc_test-code.
    ls_map-flow_type  = zif_cd_ebs_types=>gc_flow-any.
    ls_map-category   = 'D01'.
    ls_map-rule_group = gc_test-group.
    ls_map-exp_cdi    = zif_cd_ebs_types=>gc_cdi-credit.
    ls_map-active     = abap_true.
    INSERT ls_map INTO TABLE mo_cfg->mt_map.

    " S04 (real rule: house bank account configured) and probes for statement and line rules
    ls_rule-rule_group = zif_cd_ebs_types=>gc_rule_group_all.
    ls_rule-rule_id    = gc_test-s04_id.
    ls_rule-class_name = gc_test-s04_class.
    ls_rule-level      = zif_cd_ebs_types=>gc_level-statement.
    ls_rule-severity   = zif_cd_ops_types=>gc_severity-error.
    ls_rule-active     = abap_true.
    INSERT ls_rule INTO TABLE mo_cfg->mt_rules.
    ls_rule-rule_id    = gc_test-stmt_id.
    ls_rule-class_name = gc_test-stmt_class.
    INSERT ls_rule INTO TABLE mo_cfg->mt_rules.
    ls_rule-rule_group = gc_test-group.
    ls_rule-rule_id    = gc_test-line_id.
    ls_rule-class_name = gc_test-line_class.
    ls_rule-level      = zif_cd_ebs_types=>gc_level-line.
    INSERT ls_rule INTO TABLE mo_cfg->mt_rules.

    IF iv_in_scope = abap_true.
      add_statement( EXPORTING iv_stmt_key = gc_test-stmt_in iv_hktid = gc_test-hktid CHANGING cs_package = ls_package ).
      add_line( EXPORTING iv_stmt_key = gc_test-stmt_in iv_xblnr = gc_test-xblnr_pe CHANGING cs_package = ls_package ).
      add_line( EXPORTING iv_stmt_key = gc_test-stmt_in iv_xblnr = gc_test-xblnr_pe_2 CHANGING cs_package = ls_package ).
    ENDIF.
    IF iv_mixed = abap_true.
      add_statement( EXPORTING iv_stmt_key = gc_test-stmt_mixed iv_hktid = gc_test-other_hkt
                     CHANGING  cs_package  = ls_package ).
      add_line( EXPORTING iv_stmt_key = gc_test-stmt_mixed iv_xblnr = gc_test-xblnr_pe
                CHANGING  cs_package  = ls_package ).
      add_line( EXPORTING iv_stmt_key = gc_test-stmt_mixed iv_xblnr = gc_test-xblnr_othr iv_code = gc_test-unmapped
                CHANGING  cs_package  = ls_package ).
    ENDIF.
    INSERT ls_package INTO TABLE mo_source->mt_packages.
  ENDMETHOD.


  METHOD add_statement.
    DATA ls_stmt TYPE zif_cd_ebs_types=>ty_statement.
    ls_stmt-stmt_key  = iv_stmt_key.
    ls_stmt-source    = zif_cd_ebs_types=>gc_source-feb.
    ls_stmt-bukrs     = gc_test-bukrs.
    ls_stmt-hbkid     = gc_test-hbkid.
    ls_stmt-hktid     = iv_hktid.
    ls_stmt-currency  = gc_test-currency.
    ls_stmt-stmt_date = '20261105'.
    INSERT ls_stmt INTO TABLE cs_package-statements.
  ENDMETHOD.


  METHOD add_line.
    DATA ls_line TYPE zif_cd_ebs_types=>ty_line.
    ls_line-stmt_key  = iv_stmt_key.
    ls_line-line_no   = lines( cs_package-lines ) + 1.
    ls_line-scheme    = zif_cd_ebs_types=>gc_scheme-bai2.
    ls_line-btc_code  = iv_code.
    ls_line-cdi       = zif_cd_ebs_types=>gc_cdi-credit.
    ls_line-amount    = '10.00'.
    ls_line-currency  = gc_test-currency.
    ls_line-reference = |REF{ ls_line-line_no }|.
    ls_line-xblnr     = iv_xblnr.
    INSERT ls_line INTO TABLE cs_package-lines.
  ENDMETHOD.


  METHOD run_engine.
    TRY.
        ms_result = NEW zcl_cd_ebs_engine( )->run( io_source = mo_source iv_variant = 'UNIT' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Engine run raised: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD findings_of.
    LOOP AT mo_store->mt_saved ASSIGNING FIELD-SYMBOL(<ls_finding>).
      " statement key itself, or a line key below it (prefix test, no wildcard pattern)
      IF <ls_finding>-object_key = iv_stmt_key OR find( val = <ls_finding>-object_key sub = |{ iv_stmt_key }/| ) = 0.
        rv_count += 1.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  " Every line a payment engine account: statement and line rules run as before, green
  METHOD all_pe_statement_validated.
    TRY.
        configure_scenario( abap_false ).
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_stmt_rule->mt_statements ) exp = 1
                                            msg = 'The statement rule must validate the in-scope statement' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_line_rule->mt_lines ) exp = 2
                                            msg = 'The line rule must validate both lines' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-out_of_scope exp = 0
                                            msg = 'Nothing is out of scope' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-passed_items exp = 2
                                            msg = 'Both lines pass' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-rag exp = zif_cd_ops_types=>gc_rag-green
                                            msg = 'A clean in-scope statement closes green' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A mixed statement reaches no statement rule and no line rule
  METHOD mixed_statement_skipped.
    TRY.
        configure_scenario( abap_true ).
        run_engine( ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( mo_stmt_rule->mt_statements[ stmt_key = gc_test-stmt_mixed ] ) )
          msg = 'A statement rule must not see the out-of-scope statement' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( mo_line_rule->mt_lines[ stmt_key = gc_test-stmt_mixed ] ) )
          msg = 'A line rule must not see a line of the out-of-scope statement' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_line_rule->mt_lines ) exp = 2
                                            msg = 'The in-scope statement is still validated' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-total_items exp = 2
                                            msg = 'Lines of the out-of-scope statement are not counted as entries' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Its house bank account is not configured (S04) and one line has an unmapped code (R14):
  " neither raises a finding - an out-of-scope statement is never an exception
  METHOD mixed_statement_no_findings.
    TRY.
        configure_scenario( abap_true ).
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = findings_of( gc_test-stmt_mixed ) exp = 0
                                            msg = 'No finding for an out-of-scope statement or its lines' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( ms_result-findings[ check_code = zif_cd_ebs_types=>gc_check_code-account_not_configured ] ) )
          msg = 'S04 must not report the skipped statement' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( ms_result-findings[ check_code = zif_cd_ebs_types=>gc_check_code-unmapped_btc ] ) )
          msg = 'R14 must not report a line of the skipped statement' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD mixed_statement_counted.
    TRY.
        configure_scenario( abap_true ).
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-out_of_scope exp = 1
                                            msg = 'The mixed statement is counted as out of scope' ).
        DATA(lv_text) = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-out_of_scope iv_v1 = 1 ).
        cl_abap_unit_assert=>assert_char_cp( act = ms_result-run-message exp = |*{ lv_text }*|
                                             msg = 'The run message reports the out-of-scope statements' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->ms_finished-message exp = ms_result-run-message
                                            msg = 'The saved run carries the same message' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Earlier exceptions of a skipped statement and its lines stay open: a statement that was
  " not evaluated never resolves anything (as posting-open entries)
  METHOD mixed_statement_not_reconcil.
    TRY.
        configure_scenario( abap_true ).
        run_engine( ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( mo_store->mt_reconciled[ table_line = CONV zif_cd_ops_types=>ty_object_key(
                                                                                gc_test-stmt_mixed ) ] ) )
          msg = 'The out-of-scope statement must not be reconciled' ).
        LOOP AT mo_store->mt_reconciled ASSIGNING FIELD-SYMBOL(<lv_key>).
          cl_abap_unit_assert=>assert_char_np( act = <lv_key> exp = |{ gc_test-stmt_mixed }/*|
                                               msg = 'No line of the out-of-scope statement may be reconciled' ).
        ENDLOOP.
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( mo_store->mt_reconciled[ table_line = CONV zif_cd_ops_types=>ty_object_key(
                                                                               gc_test-stmt_in ) ] ) )
          msg = 'The in-scope statement is reconciled as before' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A selection whose statements are all out of scope did select statements: not NO_DATA
  METHOD only_mixed_run_is_no_data.
    TRY.
        configure_scenario( iv_mixed = abap_true iv_in_scope = abap_false ).
        run_engine( ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-out_of_scope exp = 1
                                            msg = 'The statement is counted as out of scope' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-status exp = zcl_cd_ebs_engine=>gc_status_no_data
                                            msg = 'Nothing was in scope - NO_DATA (grey), never green' ).
        cl_abap_unit_assert=>assert_equals( act = ms_result-run-rag exp = zif_cd_ops_types=>gc_rag-grey
                                            msg = 'An empty account configuration must not look like a clean day' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( mo_store->mt_saved[ rule_id = 'S04' ] ) )
                                           msg = 'No rule finding for the skipped statement' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
