*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_ingest.clas.testclasses.abap
*& Purpose:
*& Tests of the payment file ingestion through its public seam RUN with
*& an in-memory register and adapter doubles: the flagship scenario of
*& config/payfile/fixtures.json read through two integration setups - a
*& middleware with its own statuses and a direct transfer with other
*& statuses and another source of each role, wired only by adapter rows
*& and status mappings - gives identical business results (state, stage
*& reached, next milestone, minutes overdue, required milestones); an
*& observation read twice is stored once (event key); an unmapped status
*& is information; a failing source is "not evaluated" (its milestones
*& unknown, its watermark kept), never "no answer"; a class that is not
*& an adapter of its role is refused; test mode writes nothing; the
*& licence is gated first. No database. Does not prove live SAP runtime
*& behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
CLASS ltd_pf_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_dao.
    DATA mt_types TYPE zif_ca_ops_pf_types=>tt_type_cfg.
    DATA mt_stages TYPE zif_ca_ops_pf_types=>tt_stage.
    DATA mt_maps TYPE zif_ca_ops_pf_types=>tt_map.
    DATA mt_adapters TYPE zif_ca_ops_pf_types=>tt_adapter.
    DATA mt_sources TYPE zif_ca_ops_pf_types=>tt_source.
    DATA mt_files TYPE zif_ca_ops_pf_types=>tt_file.
    DATA mt_payments TYPE zif_ca_ops_pf_types=>tt_payment.
    DATA mt_events TYPE zif_ca_ops_pf_types=>tt_event.
    DATA mt_ms TYPE zif_ca_ops_pf_types=>tt_ms.
    DATA mt_days TYPE zif_ca_ops_pf_types=>tt_day.
    DATA mv_commits TYPE i.
ENDCLASS.

CLASS ltd_pf_dao IMPLEMENTATION.
  METHOD zif_ca_ops_pf_dao~get_file_types.
    rt_types = mt_types.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_stages.
    rt_stages = mt_stages.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_maps.
    rt_maps = mt_maps.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_adapters.
    rt_adapters = mt_adapters.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_source.
    rs_source = VALUE #( mt_sources[ source_id = iv_source_id ] OPTIONAL ).
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_sources.
    rt_sources = mt_sources.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~save_source.
    DELETE mt_sources WHERE source_id = is_source-source_id.
    INSERT is_source INTO TABLE mt_sources.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~files_by_key.
    LOOP AT mt_files ASSIGNING FIELD-SYMBOL(<ls_file>) WHERE file_type = iv_file_type.
      IF line_exists( it_native_keys[ table_line = <ls_file>-native_key ] ).
        INSERT <ls_file> INTO TABLE rt_files.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~files_since.
    rt_files = VALUE #( FOR ls_f IN mt_files WHERE ( bus_date >= iv_from ) ( ls_f ) ).
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~save_files.
    LOOP AT it_files ASSIGNING FIELD-SYMBOL(<ls_file>).
      DELETE mt_files WHERE file_id = <ls_file>-file_id.
      INSERT <ls_file> INTO TABLE mt_files.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~save_payments.
    LOOP AT it_file_ids ASSIGNING FIELD-SYMBOL(<lv_id>).
      DELETE mt_payments WHERE file_id = <lv_id>.
    ENDLOOP.
    INSERT LINES OF it_payments INTO TABLE mt_payments.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_payments.
    LOOP AT mt_payments ASSIGNING FIELD-SYMBOL(<ls_pay>).
      IF line_exists( it_file_ids[ table_line = <ls_pay>-file_id ] ).
        INSERT <ls_pay> INTO TABLE rt_payments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~payments_elsewhere.
    LOOP AT mt_payments ASSIGNING FIELD-SYMBOL(<ls_pay>).
      IF line_exists( it_payments[ pay_key = <ls_pay>-pay_key ] )
         AND NOT line_exists( it_payments[ pay_key = <ls_pay>-pay_key file_id = <ls_pay>-file_id ] ).
        INSERT <ls_pay> INTO TABLE rt_payments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~insert_events.
    " accepting duplicate keys, as the database
    LOOP AT it_events ASSIGNING FIELD-SYMBOL(<ls_event>).
      IF NOT line_exists( mt_events[ event_key = <ls_event>-event_key ] ).
        INSERT <ls_event> INTO TABLE mt_events.
        rv_inserted += 1.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_events.
    LOOP AT mt_events ASSIGNING FIELD-SYMBOL(<ls_event>).
      IF line_exists( it_file_ids[ table_line = <ls_event>-file_id ] ).
        INSERT <ls_event> INTO TABLE rt_events.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~events_by_source_id.
    rt_events = VALUE #( FOR ls_e IN mt_events WHERE ( source_id = iv_source_id ) ( ls_e ) ).
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~save_milestones.
    LOOP AT it_file_ids ASSIGNING FIELD-SYMBOL(<lv_id>).
      DELETE mt_ms WHERE file_id = <lv_id>.
    ENDLOOP.
    INSERT LINES OF it_milestones INTO TABLE mt_ms.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_milestones.
    rt_milestones = mt_ms.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_totals.
    CLEAR rt_totals.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~save_days.
    LOOP AT it_days ASSIGNING FIELD-SYMBOL(<ls_day>).
      DELETE mt_days WHERE file_type = <ls_day>-file_type AND bus_date = <ls_day>-bus_date.
      INSERT <ls_day> INTO TABLE mt_days.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~get_days.
    rt_days = mt_days.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~delete_before.
    rv_count = 0.
  ENDMETHOD.
  METHOD zif_ca_ops_pf_dao~commit.
    mv_commits += 1.
  ENDMETHOD.
ENDCLASS.


"! File source double: one payment file with three payments
CLASS ltd_pf_files DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_file_src.
ENDCLASS.

CLASS ltd_pf_files IMPLEMENTATION.
  METHOD zif_ca_ops_pf_adapter~configure.
    " no setting
  ENDMETHOD.
  METHOD zif_ca_ops_pf_file_src~read_files.
    rs_batch-as_of = is_request-to_ts.
    rs_batch-files = VALUE #( ( native_key = 'F1' bukrs = 'ZT01' run_date = '20261116' run_id = 'ZT1'
                                bus_date = '20261116' gen_at = '20261116160000.0000000'
                                payments = VALUE #( ( pay_key = 'P1' currency = 'USD' amount = '1000.00' amount_known = abap_true
                                                      partner = '4711000123' pay_doc = 'D1' )
                                                    ( pay_key = 'P2' currency = 'USD' amount = '2500.50' amount_known = abap_true )
                                                    ( pay_key = 'P3' currency = 'EUR' amount = '200.00' amount_known = abap_true ) ) ) ).
  ENDMETHOD.
ENDCLASS.


"! Event source double of any role: the records it is given, or a failure
CLASS ltd_pf_events DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_transfer_src.
    INTERFACES zif_ca_ops_pf_ack_src.
    INTERFACES zif_ca_ops_pf_sched_src.
    DATA mt_events TYPE zif_ca_ops_pf_types=>tt_src_event.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.

CLASS ltd_pf_events IMPLEMENTATION.
  METHOD zif_ca_ops_pf_adapter~configure.
    " no setting
  ENDMETHOD.
  METHOD zif_ca_ops_pf_event_src~read_events.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e010(zca_ops) WITH 'SOURCE'.
    ENDIF.
    rs_batch-as_of = is_request-to_ts.
    rs_batch-events = mt_events.
  ENDMETHOD.
ENDCLASS.


"! Not an adapter of any role
CLASS ltd_pf_no_adapter DEFINITION FINAL FOR TESTING.
ENDCLASS.

CLASS ltd_pf_no_adapter IMPLEMENTATION.
ENDCLASS.


CLASS ltd_pf_calendar DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_calendar.
ENDCLASS.

CLASS ltd_pf_calendar IMPLEMENTATION.
  METHOD zif_ca_ops_pf_adapter~configure.
    " no setting
  ENDMETHOD.
  METHOD zif_ca_ops_pf_calendar~is_business_day.
    rv_business = xsdbool( ( iv_date - CONV d( '19000101' ) ) MOD 7 < 5 ).
  ENDMETHOD.
  METHOD zif_ca_ops_pf_calendar~add_business_days.
    rv_date = iv_date.
    WHILE zif_ca_ops_pf_calendar~is_business_day( iv_calendar_id = iv_calendar_id iv_date = rv_date ) = abap_false.
      rv_date += 1.
    ENDWHILE.
    DO iv_days TIMES.
      rv_date += 1.
      WHILE zif_ca_ops_pf_calendar~is_business_day( iv_calendar_id = iv_calendar_id iv_date = rv_date ) = abap_false.
        rv_date += 1.
      ENDWHILE.
    ENDDO.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_pf_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_pf_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261117110000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261117'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '110000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_pf_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_pf_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~check.
    " every activity allowed
  ENDMETHOD.
ENDCLASS.


CLASS ltd_pf_license DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_license PARTIALLY IMPLEMENTED.
    DATA mv_module TYPE zif_ca_ops_lic_types=>ty_module.
ENDCLASS.

CLASS ltd_pf_license IMPLEMENTATION.
  METHOD zif_ca_ops_license~gate.
    mv_module = iv_module.
    rs_decision = VALUE #( module = iv_module allowed = abap_true ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_pf_ingest DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_area TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_PF'.
    "! A setup: the source IDs of its roles and the native statuses of its sources
    TYPES:
      BEGIN OF ty_setup,
        sched     TYPE zif_ca_ops_pf_types=>ty_source_id,
        transfer  TYPE zif_ca_ops_pf_types=>ty_source_id,
        ack       TYPE zif_ca_ops_pf_types=>ty_source_id,
        generated TYPE zif_ca_ops_pf_types=>ty_status,
        delivered TYPE zif_ca_ops_pf_types=>ty_status,
        receipt   TYPE zif_ca_ops_pf_types=>ty_status,
      END OF ty_setup.

    DATA mo_dao TYPE REF TO ltd_pf_dao.
    DATA mo_sched TYPE REF TO ltd_pf_events.
    DATA mo_transfer TYPE REF TO ltd_pf_events.
    DATA mo_ack TYPE REF TO ltd_pf_events.
    DATA mo_license TYPE REF TO ltd_pf_license.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    "! New doubles, injected
    METHODS fresh.
    "! Configure the area for a setup and give its sources the flagship's records in its native statuses
    METHODS given
      IMPORTING
        is_setup TYPE ty_setup.
    METHODS run
      IMPORTING
        iv_test_mode TYPE abap_bool DEFAULT abap_false.
    METHODS file
      RETURNING
        VALUE(rs_file) TYPE zif_ca_ops_pf_types=>ty_file.
    METHODS middleware
      RETURNING
        VALUE(rs_setup) TYPE ty_setup.
    METHODS direct
      RETURNING
        VALUE(rs_setup) TYPE ty_setup.

    METHODS two_setups_same_result     FOR TESTING.
    METHODS read_twice_stored_once     FOR TESTING.
    METHODS unmapped_is_information    FOR TESTING.
    METHODS failing_source_unknown     FOR TESTING.
    METHODS wrong_class_refused        FOR TESTING.
    METHODS partner_masked             FOR TESTING.
    METHODS test_mode_writes_nothing   FOR TESTING.
ENDCLASS.


CLASS ltc_pf_ingest IMPLEMENTATION.

  METHOD setup.
    fresh( ).
  ENDMETHOD.


  METHOD fresh.
    mo_dao = NEW #( ).
    mo_sched = NEW #( ).
    mo_transfer = NEW #( ).
    mo_ack = NEW #( ).
    mo_license = NEW #( ).
    mo_seed = NEW #( ).
    zcl_ca_ops_injector=>inject_pf_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_license( mo_license ).
    zcl_ca_ops_injector=>inject_auth( NEW ltd_pf_auth( ) ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_pf_clock( ) ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = 'ZT_PF_FILES' io_instance = NEW ltd_pf_files( ) ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = 'ZT_PF_SCHED' io_instance = mo_sched ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = 'ZT_PF_TRANSFER' io_instance = mo_transfer ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = 'ZT_PF_ACK' io_instance = mo_ack ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = 'ZT_PF_CALENDAR' io_instance = NEW ltd_pf_calendar( ) ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = 'ZT_PF_NONE' io_instance = NEW ltd_pf_no_adapter( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD middleware.
    rs_setup = VALUE #( sched = 'ZTJOB' transfer = 'ZTMW' ack = 'ZTBANK'
                        generated = 'F' delivered = 'SENT' receipt = 'TA_OK' ).
  ENDMETHOD.


  METHOD direct.
    rs_setup = VALUE #( sched = 'ZTRUNLOG' transfer = 'ZTFOLDER' ack = 'ZTACKTAB'
                        generated = 'DONE' delivered = 'UPLOADED' receipt = 'RCVD' ).
  ENDMETHOD.


  METHOD given.
    mo_dao->mt_types = VALUE #( ( area = gc_area file_type = 'PAYMENTS' ack_level = zif_ca_ops_pf_types=>gc_ack_level-file
                                  calendar_id = 'ZT' time_zone = 'UTC' expected_files = 1 zero_ok = abap_true
                                  stale_min = 1440 open_days = 5 active = abap_true ) ).
    mo_dao->mt_stages = VALUE #(
      ( milestone = zif_ca_ops_pf_types=>gc_milestone-payrun required = abap_true active = abap_true )
      ( milestone = zif_ca_ops_pf_types=>gc_milestone-generated required = abap_true active = abap_true
        due_kind = zif_ca_ops_pf_types=>gc_due_kind-offset basis = zif_ca_ops_pf_types=>gc_milestone-payrun offset_min = 60 )
      ( milestone = zif_ca_ops_pf_types=>gc_milestone-delivered required = abap_true active = abap_true
        due_kind = zif_ca_ops_pf_types=>gc_due_kind-offset basis = zif_ca_ops_pf_types=>gc_milestone-generated offset_min = 60 )
      ( milestone = zif_ca_ops_pf_types=>gc_milestone-receipt required = abap_true active = abap_true
        due_kind = zif_ca_ops_pf_types=>gc_due_kind-offset basis = zif_ca_ops_pf_types=>gc_milestone-delivered offset_min = 30 )
      ( milestone = zif_ca_ops_pf_types=>gc_milestone-accepted required = abap_true active = abap_true
        due_kind = zif_ca_ops_pf_types=>gc_due_kind-clock due_time = '100000' day_offset = 1 ) ).
    mo_dao->mt_adapters = VALUE #(
      ( role = zif_ca_ops_pf_types=>gc_role-file     source_id = 'ZTPAYRUN'        class_name = 'ZT_PF_FILES' active = abap_true )
      ( role = zif_ca_ops_pf_types=>gc_role-sched    source_id = is_setup-sched    class_name = 'ZT_PF_SCHED' active = abap_true )
      ( role = zif_ca_ops_pf_types=>gc_role-transfer source_id = is_setup-transfer class_name = 'ZT_PF_TRANSFER'
        source_type = zif_ca_ops_pf_types=>gc_source_type-mw active = abap_true )
      ( role = zif_ca_ops_pf_types=>gc_role-ack      source_id = is_setup-ack      class_name = 'ZT_PF_ACK'
        source_type = zif_ca_ops_pf_types=>gc_source_type-bank active = abap_true )
      ( role = zif_ca_ops_pf_types=>gc_role-calendar source_id = 'ZTCAL'           class_name = 'ZT_PF_CALENDAR' active = abap_true ) ).
    mo_dao->mt_maps = VALUE #(
      ( source_id = is_setup-sched    status = is_setup-generated milestone = zif_ca_ops_pf_types=>gc_milestone-generated
        outcome = zif_ca_ops_pf_types=>gc_outcome-ok active = abap_true )
      ( source_id = is_setup-transfer status = is_setup-delivered milestone = zif_ca_ops_pf_types=>gc_milestone-delivered
        outcome = zif_ca_ops_pf_types=>gc_outcome-ok active = abap_true )
      ( source_id = is_setup-ack      status = is_setup-receipt   milestone = zif_ca_ops_pf_types=>gc_milestone-receipt
        outcome = zif_ca_ops_pf_types=>gc_outcome-ok active = abap_true ) ).
    " the flagship's records in the setup's own statuses: the job by its run, the transfer and the bank by file
    mo_sched->mt_events = VALUE #( ( source_event_id = 'JOB1' event_version = 1 native_status = is_setup-generated
                                     run_date = '20261116' run_id = 'ZT1' bukrs = 'ZT01' job_name = 'ZT_MEDIUM'
                                     job_count = '00000001' occurred_at = '20261116162000.0000000' ) ).
    mo_transfer->mt_events = VALUE #( ( source_event_id = 'MSG1' event_version = 1 native_status = is_setup-delivered
                                        native_key = 'F1' occurred_at = '20261116164500.0000000' ) ).
    mo_ack->mt_events = VALUE #( ( source_event_id = 'ACK1' event_version = 1 native_status = is_setup-receipt
                                   native_key = 'F1' occurred_at = '20261116170000.0000000' ) ).
  ENDMETHOD.


  METHOD run.
    TRY.
        NEW zcl_ca_ops_pf_ingest( )->run( iv_area = gc_area iv_test_mode = iv_test_mode ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD file.
    rs_file = VALUE #( mo_dao->mt_files[ native_key = 'F1' ] OPTIONAL ).
  ENDMETHOD.


  " The same business facts through two integration setups give the same business result
  METHOD two_setups_same_result.
    given( middleware( ) ).
    run( ).
    DATA(ls_first) = file( ).
    DATA(lt_first) = VALUE zif_ca_ops_pf_types=>tt_ms( FOR ls_m IN mo_dao->mt_ms ( milestone = ls_m-milestone status = ls_m-status ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_license->mv_module exp = zif_ca_ops_lic_types=>gc_module-cashops
                                        msg = 'Module CASHOPS gated' ).
    cl_abap_unit_assert=>assert_equals( act = ls_first-next_ms exp = zif_ca_ops_pf_types=>gc_milestone-accepted
                                        msg = 'Flagship: acceptance missing' ).
    cl_abap_unit_assert=>assert_equals( act = ls_first-overdue_min exp = 60 msg = 'Overdue an hour' ).
    cl_abap_unit_assert=>assert_equals( act = ls_first-gen_job exp = 'ZT_MEDIUM' msg = 'Job of the run' ).

    zcl_ca_ops_injector=>reset( ).
    fresh( ).
    given( direct( ) ).
    run( ).
    DATA(ls_second) = file( ).
    DATA(lt_second) = VALUE zif_ca_ops_pf_types=>tt_ms( FOR ls_m IN mo_dao->mt_ms ( milestone = ls_m-milestone status = ls_m-status ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_second-state exp = ls_first-state msg = 'Same state' ).
    cl_abap_unit_assert=>assert_equals( act = ls_second-stage exp = ls_first-stage msg = 'Same stage' ).
    cl_abap_unit_assert=>assert_equals( act = ls_second-next_ms exp = ls_first-next_ms msg = 'Same next milestone' ).
    cl_abap_unit_assert=>assert_equals( act = ls_second-overdue_min exp = ls_first-overdue_min msg = 'Same overdue' ).
    cl_abap_unit_assert=>assert_equals( act = lt_second exp = lt_first msg = 'Same milestones' ).
  ENDMETHOD.


  METHOD read_twice_stored_once.
    given( middleware( ) ).
    run( ).
    DATA(lv_events) = lines( mo_dao->mt_events ).
    run( ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_events ) exp = lv_events msg = 'Idempotent' ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_files ) exp = 1 msg = 'One file' ).
  ENDMETHOD.


  METHOD unmapped_is_information.
    given( middleware( ) ).
    INSERT VALUE #( source_event_id = 'ACK2' event_version = 1 native_status = 'WHATEVER' native_key = 'F1'
                    occurred_at = '20261117080000.0000000' ) INTO TABLE mo_ack->mt_events.
    run( ).
    DATA(ls_event) = VALUE #( mo_dao->mt_events[ source_event_id = 'ACK2' ] OPTIONAL ).
    cl_abap_unit_assert=>assert_equals( act = ls_event-outcome exp = zif_ca_ops_pf_types=>gc_outcome-info msg = 'Information' ).
    cl_abap_unit_assert=>assert_equals( act = file( )-next_ms exp = zif_ca_ops_pf_types=>gc_milestone-accepted msg = 'Moves nothing' ).
  ENDMETHOD.


  METHOD failing_source_unknown.
    given( middleware( ) ).
    mo_ack->mv_fail = abap_true.
    CLEAR mo_ack->mt_events.
    run( ).
    DATA(ls_source) = VALUE #( mo_dao->mt_sources[ source_id = 'ZTBANK' ] OPTIONAL ).
    cl_abap_unit_assert=>assert_equals( act = ls_source-status exp = zif_ca_ops_pf_types=>gc_src_status-failed msg = 'Failed' ).
    cl_abap_unit_assert=>assert_initial( act = ls_source-watermark msg = 'Watermark kept' ).
    cl_abap_unit_assert=>assert_equals( act = file( )-eval_state exp = zif_ca_ops_pf_types=>gc_eval-not_evaluated
                                        msg = 'Not evaluated' ).
    cl_abap_unit_assert=>assert_equals( act = file( )-overdue_min exp = 0 msg = 'Never overdue without its source' ).
  ENDMETHOD.


  METHOD wrong_class_refused.
    given( middleware( ) ).
    mo_dao->mt_adapters[ role = zif_ca_ops_pf_types=>gc_role-ack ]-class_name = 'ZT_PF_NONE'.
    run( ).
    DATA(ls_source) = VALUE #( mo_dao->mt_sources[ source_id = 'ZTBANK' ] OPTIONAL ).
    cl_abap_unit_assert=>assert_equals( act = ls_source-status exp = zif_ca_ops_pf_types=>gc_src_status-failed
                                        msg = 'Not an adapter: not evaluated' ).
  ENDMETHOD.


  METHOD partner_masked.
    given( middleware( ) ).
    run( ).
    DATA(ls_pay) = VALUE #( mo_dao->mt_payments[ pay_key = 'P1' ] OPTIONAL ).
    cl_abap_unit_assert=>assert_differs( act = ls_pay-partner_masked exp = '4711000123' msg = 'Never in full' ).
    cl_abap_unit_assert=>assert_not_initial( act = ls_pay-partner_masked msg = 'Masked, not dropped' ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_payments ) exp = 3 msg = 'Three payments' ).
  ENDMETHOD.


  METHOD test_mode_writes_nothing.
    given( middleware( ) ).
    run( abap_true ).
    cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_files msg = 'No file' ).
    cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_events msg = 'No evidence' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_commits exp = 0 msg = 'No commit' ).
  ENDMETHOD.

ENDCLASS.
