*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_engine.clas.testclasses.abap
*& Purpose:
*& Application tests of the FMON engine with LTD_* doubles (DAO, adapter,
*& lot reader, calendar, store, alert, clock) through both injectors;
*& includes acceptance test 8; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_dao PARTIALLY IMPLEMENTED.
    DATA mt_ifaces TYPE zif_cd_fmon_types=>tt_iface.
    DATA mt_slas TYPE zif_cd_fmon_types=>tt_sla.
    DATA mt_srcs TYPE zif_cd_fmon_types=>tt_src.
    DATA mt_lotcfgs TYPE zif_cd_fmon_types=>tt_lotcfg.
    DATA mt_checks TYPE zif_cd_fmon_types=>tt_chk.
    DATA mt_saved TYPE zif_cd_fmon_types=>tt_file.
    DATA mt_events TYPE zif_cd_fmon_types=>tt_event.
    DATA mv_save_calls TYPE i.
    DATA mv_fail_save TYPE abap_bool.
ENDCLASS.


CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_fmon_dao~get_ifaces.
    rt_ifaces = mt_ifaces.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_slas.
    rt_slas = mt_slas.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_calendars.
    CLEAR rt_cals.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_sources.
    rt_sources = mt_srcs.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_source_maps.
    CLEAR rt_maps.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_lot_configs.
    rt_cfgs = mt_lotcfgs.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_checks.
    rt_checks = mt_checks.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~find_files_by_ref.
    CLEAR rt_files.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_eval_files.
    CLEAR rt_files.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_history.
    CLEAR rt_files.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_events.
    CLEAR rt_events.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~save_files.
    mv_save_calls += 1.
    IF mv_fail_save = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e010(zcd_ops) WITH 'ZCD_FMON_FILE'.
    ENDIF.
    mt_saved = it_files.
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~insert_event.
    INSERT is_event INTO TABLE mt_events.
    rv_inserted = abap_true.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_adapter DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_adapter.
    CONSTANTS gc_broken TYPE zif_cd_fmon_types=>ty_src_id VALUE 'BROKEN'.
    DATA mt_records TYPE zif_cd_fmon_types=>tt_src_record.
ENDCLASS.


CLASS ltd_adapter IMPLEMENTATION.
  METHOD zif_cd_fmon_adapter~read.
    IF is_request-src-src_id = gc_broken.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e200(zcd_ops) WITH 'ZCD_NOT_THERE'.
    ENDIF.
    rt_records = VALUE #( FOR ls_rec IN mt_records WHERE ( src_id = is_request-src-src_id ) ( ls_rec ) ).
  ENDMETHOD.
ENDCLASS.


CLASS ltd_lot_reader DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_lot_reader.
    TYPES:
      BEGIN OF ty_lot,
        file_name TYPE zif_cd_fmon_types=>ty_file_name,
        total     TYPE i,
        open      TYPE i,
        keys      TYPE string,
      END OF ty_lot.
    DATA mt_lots TYPE STANDARD TABLE OF ty_lot WITH EMPTY KEY.
ENDCLASS.


CLASS ltd_lot_reader IMPLEMENTATION.
  METHOD zif_cd_fmon_lot_reader~read.
    DATA ls_status TYPE zif_cd_fmon_types=>ty_lot_status.
    LOOP AT it_files INTO DATA(ls_file).
      CLEAR ls_status.
      ls_status-file_id  = ls_file-file_id.
      ls_status-lot_type = is_cfg-lot_type.
      ls_status-sla_days = is_cfg-noc_sla_days.
      READ TABLE mt_lots INTO DATA(ls_lot) WITH KEY file_name = ls_file-file_name.
      IF sy-subrc = 0.
        ls_status-found       = abap_true.
        ls_status-total_items = ls_lot-total.
        ls_status-open_items  = ls_lot-open.
        ls_status-done_items  = ls_lot-total - ls_lot-open.
        ls_status-open_keys   = ls_lot-keys.
      ENDIF.
      INSERT ls_status INTO TABLE rt_status.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_calendar DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_calendar.
    DATA mv_age TYPE i VALUE 1.
ENDCLASS.


CLASS ltd_calendar IMPLEMENTATION.
  METHOD zif_cd_fmon_calendar~is_working_day.
    rv_working = abap_true.
  ENDMETHOD.
  METHOD zif_cd_fmon_calendar~is_month_end.
    rv_month_end = abap_false.
  ENDMETHOD.
  METHOD zif_cd_fmon_calendar~working_days_between.
    rv_days = mv_age.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store PARTIALLY IMPLEMENTED.
    DATA mv_finish_calls TYPE i.
    DATA mv_commit_calls TYPE i.
    DATA mv_rollback_calls TYPE i.
ENDCLASS.


CLASS ltd_store IMPLEMENTATION.
  METHOD zif_cd_ops_store~start_run.
    rs_run-module    = iv_module.
    rs_run-variant   = iv_variant.
    rs_run-test_mode = iv_test_mode.
    rs_run-status    = zif_cd_ops_types=>gc_run_status-running.
  ENDMETHOD.
  METHOD zif_cd_ops_store~save_findings.
    cs_run-finding_count += lines( it_findings ).
  ENDMETHOD.
  METHOD zif_cd_ops_store~finish_run.
    mv_finish_calls += 1.
  ENDMETHOD.
  METHOD zif_cd_ops_store~commit.
    mv_commit_calls += 1.
  ENDMETHOD.
  METHOD zif_cd_ops_store~rollback.
    mv_rollback_calls += 1.
  ENDMETHOD.
  METHOD zif_cd_ops_store~get_param.
    rv_value = iv_default.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_alert DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert.
    DATA mv_dispatch_calls TYPE i.
    DATA mv_send_calls TYPE i.
    DATA mt_dispatched TYPE zif_cd_ops_types=>tt_finding.
    "! When bound, dispatch( ) records how far the run was persisted at that moment
    DATA mo_store TYPE REF TO ltd_store.
    DATA mv_commits_seen TYPE i.
    DATA mv_finishes_seen TYPE i.
ENDCLASS.


CLASS ltd_alert IMPLEMENTATION.
  METHOD zif_cd_ops_alert~send.
    mv_send_calls += 1.
  ENDMETHOD.
  METHOD zif_cd_ops_alert~dispatch.
    mv_dispatch_calls += 1.
    mt_dispatched = it_findings.
    IF mo_store IS BOUND.
      mv_commits_seen  = mo_store->mv_commit_calls.
      mv_finishes_seen = mo_store->mv_finish_calls.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
ENDCLASS.


CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = '20261102080000'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~today.
    rv_date = '20261102'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~time.
    rv_time = '080000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_failing_check DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_check.
ENDCLASS.


CLASS ltd_failing_check IMPLEMENTATION.
  METHOD zif_cd_fmon_check~execute.
    RAISE EXCEPTION TYPE zcx_cd_ops_error
      MESSAGE e205(zcd_ops) WITH 'LTD_FAILING_CHECK' 'simulated failure'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_engine DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_flags,
        returns_open      TYPE i,
        source_says_fully TYPE abap_bool,
        outbound          TYPE abap_bool,
        dup_rows          TYPE abap_bool,
        failing_check     TYPE abap_bool,
        broken_source     TYPE abap_bool,
        unmapped_status   TYPE abap_bool,
        noc_age           TYPE i,
        test_mode         TYPE abap_bool,
      END OF ty_flags.

    CONSTANTS gc_date TYPE d VALUE '20261102'.
    CONSTANTS gc_out TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_PNC_OUT'.
    CONSTANTS gc_ret TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_RET_IN'.
    CONSTANTS gc_noc TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'NOC_IN'.
    CONSTANTS gc_out_file TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_PNC_20261102_01'.
    CONSTANTS gc_ret_file TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_RET_20261102'.
    CONSTANTS gc_noc_file TYPE zif_cd_fmon_types=>ty_file_name VALUE 'NOC_20261102'.
    CONSTANTS gc_src_out TYPE zif_cd_fmon_types=>ty_src_id VALUE 'REGUT'.
    CONSTANTS gc_src_ack TYPE zif_cd_fmon_types=>ty_src_id VALUE 'ACHACK'.
    CONSTANTS gc_src_in TYPE zif_cd_fmon_types=>ty_src_id VALUE 'RTRV'.
    CONSTANTS gc_fail_class TYPE zif_cd_ops_types=>ty_class_name VALUE 'LTD_FAILING_CHECK'.
    CONSTANTS gc_lot_check TYPE zif_cd_fmon_types=>ty_check_id VALUE 'C_LOT'.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_adapter TYPE REF TO ltd_adapter.
    DATA mo_lots TYPE REF TO ltd_lot_reader.
    DATA mo_calendar TYPE REF TO ltd_calendar.
    DATA mo_store TYPE REF TO ltd_store.
    DATA mo_alert TYPE REF TO ltd_alert.
    DATA mv_test_mode TYPE abap_bool.

    METHODS setup.
    METHODS teardown.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_fmon_types=>ty_result
      RAISING
        zcx_cd_ops_error.

    METHODS add_iface
      IMPORTING
        iv_iface_id  TYPE zif_cd_fmon_types=>ty_iface_id
        iv_direction TYPE zif_cd_fmon_types=>ty_direction
        iv_file_type TYPE zif_cd_fmon_types=>ty_file_type
        iv_pattern   TYPE zif_cd_fmon_types=>ty_pattern.

    METHODS add_record
      IMPORTING
        iv_src_id TYPE zif_cd_fmon_types=>ty_src_id
        iv_name   TYPE zif_cd_fmon_types=>ty_file_name
        iv_stage  TYPE zif_cd_fmon_types=>ty_stage
        iv_at     TYPE timestampl
        iv_count  TYPE i DEFAULT 0
        iv_amount TYPE zif_cd_ops_types=>ty_amount DEFAULT 0.

    METHODS add_check
      IMPORTING
        iv_check_id TYPE zif_cd_fmon_types=>ty_check_id
        iv_class    TYPE zif_cd_ops_types=>ty_class_name.

    METHODS board_row
      IMPORTING
        is_result     TYPE zif_cd_fmon_types=>ty_result
        iv_name       TYPE zif_cd_fmon_types=>ty_file_name
      RETURNING
        VALUE(rs_row) TYPE zif_cd_fmon_types=>ty_board.

    METHODS codes
      IMPORTING
        it_findings     TYPE zif_cd_ops_types=>tt_finding
      RETURNING
        VALUE(rt_codes) TYPE string_table.

    METHODS expected_lot_finding
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding.

    METHODS partial_returns_stay_partial FOR TESTING.
    METHODS open_item_gives_one_finding FOR TESTING.
    METHODS partial_returns_are_alerted FOR TESTING.
    METHODS source_cannot_close_open_lot FOR TESTING.
    METHODS acked_file_ends_ack_received FOR TESTING.
    METHODS duplicate_rows_one_event FOR TESTING.
    METHODS failing_check_does_not_abort FOR TESTING.
    METHODS failing_source_does_not_abort FOR TESTING.
    METHODS test_mode_writes_nothing FOR TESTING.
    METHODS unmapped_status_is_reported FOR TESTING.
    METHODS noc_age_is_in_banking_days FOR TESTING.
    METHODS alerts_sent_after_commit FOR TESTING.
    METHODS persist_error_rolls_back FOR TESTING.

ENDCLASS.


CLASS ltc_engine IMPLEMENTATION.

  METHOD setup.
    mo_dao      = NEW #( ).
    mo_adapter  = NEW #( ).
    mo_lots     = NEW #( ).
    mo_calendar = NEW #( ).
    mo_store    = NEW #( ).
    mo_alert    = NEW #( ).
    zcl_cd_fmon_injector=>inject_dao( mo_dao ).
    zcl_cd_fmon_injector=>inject_adapter( mo_adapter ).
    zcl_cd_fmon_injector=>inject_lot_reader( mo_lots ).
    zcl_cd_fmon_injector=>inject_calendar( mo_calendar ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
    zcl_cd_ops_injector=>inject_alert( mo_alert ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_fmon_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD add_iface.
    DATA ls_iface TYPE zif_cd_fmon_types=>ty_iface.
    ls_iface-iface_id     = iv_iface_id.
    ls_iface-direction    = iv_direction.
    ls_iface-file_type    = iv_file_type.
    ls_iface-source_sys   = zif_cd_fmon_types=>gc_wildcard.
    ls_iface-lob          = zif_cd_fmon_types=>gc_wildcard.
    ls_iface-pay_method   = 'ACH'.
    ls_iface-name_pattern = iv_pattern.
    ls_iface-min_bytes    = 1.
    ls_iface-ack_expected = xsdbool( iv_direction = zif_cd_fmon_types=>gc_direction-outbound ).
    ls_iface-ack_level    = zif_cd_fmon_types=>gc_ack_level-file.
    ls_iface-active       = abap_true.
    INSERT ls_iface INTO TABLE mo_dao->mt_ifaces.
  ENDMETHOD.


  METHOD add_record.
    DATA ls_rec TYPE zif_cd_fmon_types=>ty_src_record.
    ls_rec-src_id        = iv_src_id.
    ls_rec-file_name     = iv_name.
    ls_rec-file_ref      = zcl_cd_fmon_util=>normalize_ref( iv_name ).
    ls_rec-raw_status    = iv_stage.
    ls_rec-stage         = iv_stage.
    ls_rec-event_at      = iv_at.
    ls_rec-business_date = gc_date.
    IF iv_count > 0.
      ls_rec-rec_count   = iv_count.
      ls_rec-count_known = abap_true.
    ENDIF.
    ls_rec-amount        = iv_amount.
    INSERT ls_rec INTO TABLE mo_adapter->mt_records.
  ENDMETHOD.


  METHOD add_check.
    DATA ls_check TYPE zif_cd_fmon_types=>ty_chk.
    ls_check-check_id   = iv_check_id.
    ls_check-class_name = iv_class.
    ls_check-severity   = zif_cd_ops_types=>gc_severity-error.
    ls_check-active     = abap_true.
    INSERT ls_check INTO TABLE mo_dao->mt_checks.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_sla TYPE zif_cd_fmon_types=>ty_sla.
    DATA ls_src TYPE zif_cd_fmon_types=>ty_src.
    DATA ls_cfg TYPE zif_cd_fmon_types=>ty_lotcfg.

    mv_test_mode = is_flags-test_mode.
    mo_calendar->mv_age = COND #( WHEN is_flags-noc_age > 0 THEN is_flags-noc_age ELSE 1 ).

    add_iface( iv_iface_id = gc_out iv_direction = zif_cd_fmon_types=>gc_direction-outbound
               iv_file_type = zif_cd_fmon_types=>gc_file_type-payment iv_pattern = 'ACH_PNC_*' ).
    add_iface( iv_iface_id = gc_ret iv_direction = zif_cd_fmon_types=>gc_direction-inbound
               iv_file_type = zif_cd_fmon_types=>gc_file_type-returns iv_pattern = 'ACH_RET_*' ).
    add_iface( iv_iface_id = gc_noc iv_direction = zif_cd_fmon_types=>gc_direction-inbound
               iv_file_type = zif_cd_fmon_types=>gc_file_type-noc iv_pattern = 'NOC_*' ).

    ls_sla-iface_id    = gc_out.
    ls_sla-stage       = zif_cd_fmon_types=>gc_stage-sent.
    ls_sla-max_minutes = 30.
    ls_sla-basis       = zif_cd_fmon_types=>gc_sla_basis-previous.
    ls_sla-severity    = zif_cd_ops_types=>gc_severity-error.
    INSERT ls_sla INTO TABLE mo_dao->mt_slas.
    ls_sla-stage       = zif_cd_fmon_types=>gc_stage-ack.
    ls_sla-max_minutes = 120.
    ls_sla-basis       = zif_cd_fmon_types=>gc_sla_basis-generation.
    INSERT ls_sla INTO TABLE mo_dao->mt_slas.

    ls_src-active = abap_true.
    ls_src-src_id = gc_src_out.
    INSERT ls_src INTO TABLE mo_dao->mt_srcs.
    ls_src-src_id = gc_src_ack.
    INSERT ls_src INTO TABLE mo_dao->mt_srcs.
    ls_src-src_id = gc_src_in.
    INSERT ls_src INTO TABLE mo_dao->mt_srcs.
    IF is_flags-broken_source = abap_true.
      ls_src-src_id = ltd_adapter=>gc_broken.
      INSERT ls_src INTO TABLE mo_dao->mt_srcs.
    ENDIF.

    ls_cfg-iface_id   = zif_cd_fmon_types=>gc_wildcard.
    ls_cfg-lot_type   = zif_cd_fmon_types=>gc_lot_type-returns.
    ls_cfg-item_table = 'DFKKRP'.
    ls_cfg-active     = abap_true.
    INSERT ls_cfg INTO TABLE mo_dao->mt_lotcfgs.
    ls_cfg-lot_type     = zif_cd_fmon_types=>gc_lot_type-noc.
    ls_cfg-item_table   = 'DFKKNRP'.
    ls_cfg-noc_sla_days = 6.
    INSERT ls_cfg INTO TABLE mo_dao->mt_lotcfgs.

    add_check( iv_check_id = 'C_ACK'  iv_class = 'ZCL_CD_FMON_CHK_ACK_MATCH' ).
    add_check( iv_check_id = 'C_DUP'  iv_class = 'ZCL_CD_FMON_CHK_DUPLICATE' ).
    add_check( iv_check_id = 'C_LATE' iv_class = 'ZCL_CD_FMON_CHK_LATE' ).
    add_check( iv_check_id = gc_lot_check iv_class = 'ZCL_CD_FMON_CHK_LOT' ).
    add_check( iv_check_id = 'C_MISS' iv_class = 'ZCL_CD_FMON_CHK_MISSING' ).
    add_check( iv_check_id = 'C_NOC'  iv_class = 'ZCL_CD_FMON_CHK_NOC_AGING' ).
    add_check( iv_check_id = 'C_REJ'  iv_class = 'ZCL_CD_FMON_CHK_REJECT' ).
    add_check( iv_check_id = 'C_SIZE' iv_class = 'ZCL_CD_FMON_CHK_SIZE' ).
    add_check( iv_check_id = 'C_SLA'  iv_class = 'ZCL_CD_FMON_CHK_SLA' ).
    IF is_flags-failing_check = abap_true.
      add_check( iv_check_id = 'C_FAIL' iv_class = gc_fail_class ).
      zcl_cd_ops_injector=>inject_plugin( iv_class_name = gc_fail_class
                                          io_instance   = NEW ltd_failing_check( ) ).
    ENDIF.

    " Inbound returns file: received, loaded, lot with 3 items
    add_record( iv_src_id = gc_src_in iv_name = gc_ret_file
                iv_stage = zif_cd_fmon_types=>gc_stage-received iv_at = '20261102050000' ).
    add_record( iv_src_id = gc_src_in iv_name = gc_ret_file
                iv_stage = zif_cd_fmon_types=>gc_stage-loaded iv_at = '20261102051000' ).
    IF is_flags-source_says_fully = abap_true.
      add_record( iv_src_id = gc_src_in iv_name = gc_ret_file
                  iv_stage = zif_cd_fmon_types=>gc_stage-fully iv_at = '20261102052000' ).
    ENDIF.
    IF is_flags-unmapped_status = abap_true.
      add_record( iv_src_id = gc_src_in iv_name = gc_ret_file iv_stage = '' iv_at = '20261102052000' ).
    ENDIF.
    INSERT VALUE #( file_name = gc_ret_file
                    total     = 3
                    open      = is_flags-returns_open
                    keys      = COND #( WHEN is_flags-returns_open > 0 THEN `L1/3` ) ) INTO TABLE mo_lots->mt_lots.

    IF is_flags-outbound = abap_true.
      add_record( iv_src_id = gc_src_out iv_name = gc_out_file iv_stage = zif_cd_fmon_types=>gc_stage-generated
                  iv_at = '20261102043000' iv_count = 10 iv_amount = '1000.00' ).
      IF is_flags-dup_rows = abap_true.
        add_record( iv_src_id = gc_src_out iv_name = gc_out_file iv_stage = zif_cd_fmon_types=>gc_stage-generated
                    iv_at = '20261102043500' iv_count = 10 iv_amount = '1000.00' ).
      ENDIF.
      add_record( iv_src_id = gc_src_out iv_name = gc_out_file iv_stage = zif_cd_fmon_types=>gc_stage-sent
                  iv_at = '20261102044000' ).
      add_record( iv_src_id = gc_src_ack iv_name = gc_out_file iv_stage = zif_cd_fmon_types=>gc_stage-ack
                  iv_at = '20261102050000' iv_count = COND #( WHEN is_flags-dup_rows = abap_true THEN 20 ELSE 10 )
                  iv_amount = COND #( WHEN is_flags-dup_rows = abap_true THEN '2000.00' ELSE '1000.00' ) ).
    ENDIF.

    IF is_flags-noc_age > 0.
      add_record( iv_src_id = gc_src_in iv_name = gc_noc_file
                  iv_stage = zif_cd_fmon_types=>gc_stage-received iv_at = '20261102050000' ).
      add_record( iv_src_id = gc_src_in iv_name = gc_noc_file
                  iv_stage = zif_cd_fmon_types=>gc_stage-loaded iv_at = '20261102050500' ).
      INSERT VALUE #( file_name = gc_noc_file total = 2 open = 1 keys = `N1/2` ) INTO TABLE mo_lots->mt_lots.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rs_result = zcl_cd_fmon_factory=>get_engine( )->run( iv_business_date = gc_date
                                                         iv_test_mode     = mv_test_mode ).
  ENDMETHOD.


  METHOD board_row.
    rs_row = VALUE #( is_result-board[ file_name = iv_name ] OPTIONAL ).
  ENDMETHOD.


  METHOD codes.
    LOOP AT it_findings INTO DATA(ls_finding).
      INSERT CONV string( ls_finding-check_code ) INTO TABLE rt_codes.
    ENDLOOP.
    SORT rt_codes.
  ENDMETHOD.


  METHOD expected_lot_finding.
    DATA ls_finding TYPE zif_cd_ops_types=>ty_finding.
    DATA(ls_file) = VALUE #( mo_dao->mt_saved[ file_name = gc_ret_file ] OPTIONAL ).
    ls_finding-object_type = zif_cd_fmon_types=>gc_object_type.
    ls_finding-object_key  = gc_ret_file.
    ls_finding-group1      = gc_ret.
    ls_finding-group2      = 'ACH'.
    ls_finding-rule_id     = gc_lot_check.
    ls_finding-check_code  = zif_cd_fmon_types=>gc_check_code-lot_unprocessed.
    ls_finding-severity    = zif_cd_ops_types=>gc_severity-error.
    ls_finding-action      = zif_cd_ops_types=>gc_action-exception.
    ls_finding-reference   = zcl_cd_fmon_util=>file_hex( ls_file-file_id ).
    ls_finding-message     = |{ gc_ret_file }: 1 of 3 RETURNS transaction(s) unprocessed (L1/3)|.
    INSERT ls_finding INTO TABLE rt_findings.
  ENDMETHOD.


  " Rule (acceptance test 8): a returns file with one unprocessed transaction
  " stays PARTIALLY_PROCESSED with unprocessed count 1.
  METHOD partial_returns_stay_partial.
    TRY.
        configure_scenario( VALUE #( returns_open = 1 ) ).
        DATA(ls_row) = board_row( is_result = act( ) iv_name = gc_ret_file ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-outcome exp = zif_cd_fmon_types=>gc_stage-partially
                                            msg = 'Outcome must be PARTIALLY_PROCESSED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-unprocessed_count exp = 1
                                            msg = 'Unprocessed count must be 1' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (acceptance test 8): the open transaction is exactly one owned LOT_UNPROCESSED
  " finding of severity E - whole findings table asserted.
  METHOD open_item_gives_one_finding.
    TRY.
        configure_scenario( VALUE #( returns_open = 1 ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings exp = expected_lot_finding( )
                                            msg = 'Exactly the LOT_UNPROCESSED finding is expected' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (acceptance test 8): the run's findings are dispatched once to the core alert router.
  METHOD partial_returns_are_alerted.
    TRY.
        configure_scenario( VALUE #( returns_open = 1 ) ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatch_calls exp = 1
                                            msg = 'dispatch( ) must be called once' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mt_dispatched exp = expected_lot_finding( )
                                            msg = 'The PARTIALLY_PROCESSED finding must be dispatched' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: for a lot-controlled interface a source claiming FULLY_PROCESSED cannot
  " close the file while the lot still has an open transaction.
  METHOD source_cannot_close_open_lot.
    TRY.
        configure_scenario( VALUE #( returns_open = 1 source_says_fully = abap_true ) ).
        DATA(ls_row) = board_row( is_result = act( ) iv_name = gc_ret_file ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-outcome exp = zif_cd_fmon_types=>gc_stage-partially
                                            msg = 'Lot evidence must win over the source status' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: generation, PRISM handoff and bank ack from two sources chain into one
  " file that ends ACK_RECEIVED with no finding.
  METHOD acked_file_ends_ack_received.
    TRY.
        configure_scenario( VALUE #( outbound = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = board_row( is_result = ls_result iv_name = gc_out_file )-outcome
                                            exp = zif_cd_fmon_types=>gc_stage-ack
                                            msg = 'Outbound file must end ACK_RECEIVED' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings
                                             msg = 'A file on time and fully acknowledged has no finding' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: several source rows of one stage give one audit event (idempotent trail).
  METHOD duplicate_rows_one_event.
    TRY.
        configure_scenario( VALUE #( outbound = abap_true dup_rows = abap_true ) ).
        act( ).
        DATA(lv_generated) = REDUCE i( INIT n = 0
                                       FOR ls_event IN mo_dao->mt_events
                                       WHERE ( stage = zif_cd_fmon_types=>gc_stage-generated )
                                       NEXT n = n + 1 ).
        cl_abap_unit_assert=>assert_equals( act = lv_generated exp = 1
                                            msg = 'Two generation rows must give one event' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a failing plug-in check becomes PLUGIN_ERROR; the other checks still report.
  METHOD failing_check_does_not_abort.
    TRY.
        configure_scenario( VALUE #( returns_open = 1 failing_check = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals(
          act = codes( ls_result-findings )
          exp = VALUE string_table( ( `LOT_UNPROCESSED` ) ( `PLUGIN_ERROR` ) )
          msg = 'PLUGIN_ERROR plus the lot finding must be reported' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a failing source adapter becomes PLUGIN_ERROR; other sources are still synced.
  METHOD failing_source_does_not_abort.
    TRY.
        configure_scenario( VALUE #( broken_source = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = codes( ls_result-findings )
                                            exp = VALUE string_table( ( `PLUGIN_ERROR` ) )
                                            msg = 'Only the broken source may be reported' ).
        cl_abap_unit_assert=>assert_equals( act = board_row( is_result = ls_result iv_name = gc_ret_file )-outcome
                                            exp = zif_cd_fmon_types=>gc_stage-fully
                                            msg = 'The healthy source must still be processed' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: test mode saves no registry row or event, does not commit and does not alert.
  METHOD test_mode_writes_nothing.
    TRY.
        configure_scenario( VALUE #( returns_open = 1 test_mode = abap_true ) ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_save_calls exp = 0
                                            msg = 'No registry save in test mode' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_events
                                             msg = 'No event insert in test mode' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commit_calls exp = 0
                                            msg = 'No commit in test mode' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_dispatch_calls exp = 0
                                            msg = 'No alert dispatch in test mode' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (no silent suspense): a status value without stage mapping is reported, never dropped.
  METHOD unmapped_status_is_reported.
    TRY.
        configure_scenario( VALUE #( unmapped_status = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = codes( ls_result-findings )
                                            exp = VALUE string_table( ( `UNMAPPED_STATUS` ) )
                                            msg = 'Unmapped status must be reported' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: NOC age is measured in banking days of the calendar seam (7 > 6 -> NOC_AGING).
  METHOD noc_age_is_in_banking_days.
    TRY.
        configure_scenario( VALUE #( noc_age = 7 ) ).
        DATA(ls_result) = act( ).
        READ TABLE ls_result-findings INTO DATA(ls_aging)
          WITH KEY check_code = zif_cd_fmon_types=>gc_check_code-noc_aging.
        cl_abap_unit_assert=>assert_subrc( act = sy-subrc exp = 0
                                           msg = 'NOC_AGING finding expected' ).
        cl_abap_unit_assert=>assert_equals( act = ls_aging-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'NOC aging is a compliance error (E)' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: results are durable before anyone is told - run header committed at start,
  " findings and run end committed before the alert router is called (review 2026-11-06)
  METHOD alerts_sent_after_commit.
    TRY.
        configure_scenario( VALUE #( returns_open = 1 ) ).
        mo_alert->mo_store = mo_store.
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_finishes_seen exp = 1
                                            msg = 'The run must be finished before alerts are dispatched' ).
        cl_abap_unit_assert=>assert_equals( act = mo_alert->mv_commits_seen exp = 2
                                            msg = 'Run start and results must be committed before alerts' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a registry that cannot be saved completely is rolled back, never committed
  " half-written; the failure is a PERSIST_ERROR finding
  METHOD persist_error_rolls_back.
    TRY.
        configure_scenario( VALUE #( returns_open = 1 ) ).
        mo_dao->mv_fail_save = abap_true.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_rollback_calls exp = 1
                                            msg = 'A failed registry save must be rolled back' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_fmon_types=>gc_check_code-persist_error ] ) )
          msg = 'The failure must be recorded as PERSIST_ERROR' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
