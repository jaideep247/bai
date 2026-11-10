*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_adapter_prism.clas.testclasses.abap
*& Purpose:
*& Unit tests of the PRISM source adapter with an LTD_* PRISM DAO: configured
*& field names, stage map, business date and digest rules of the generic
*& adapter, interfaceId preference, unprocessed-only read (5-minute safety net),
*& configuration errors; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API, instant bgPF processing).
*& 2026-11-07 | Design review: business dates in US Central (CST) around midnight and both
*&              daylight-saving changes (repeated / missing hour).
*&---------------------------------------------------------------------*
CLASS ltd_prism_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_prism_dao PARTIALLY IMPLEMENTED.
    DATA mt_rows TYPE zif_cd_fmon_prism_types=>tt_row.
    DATA mv_from TYPE timestampl.
    DATA mv_to TYPE timestampl.
ENDCLASS.


CLASS ltd_prism_dao IMPLEMENTATION.
  METHOD zif_cd_fmon_prism_dao~read_unprocessed.
    mv_from = iv_from.
    mv_to   = iv_to.
    rt_rows = VALUE #( FOR ls_row IN mt_rows WHERE ( processed_at IS INITIAL ) ( ls_row ) ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_adapter_prism DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        src_id    TYPE zif_cd_fmon_types=>ty_src_id VALUE 'PRISM',
        file_name TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ach_pnc_20261106_01',
        occurred  TYPE timestampl VALUE '20261106143000',
        iface     TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'WIRE_JPMC_OUT',
        "! FMON_TIME_ZONE of the landscape: US Central with daylight saving
        central   TYPE zif_cd_fmon_types=>ty_time_zone VALUE 'CST',
      END OF gc_test.
    "! occurredAt (UTC) and the business date in US Central
    CONSTANTS:
      BEGIN OF gc_utc,
        "! 23:58 CST on 1 Nov and 00:03 CST on 2 Nov
        before_midnight TYPE timestampl VALUE '20261102055800',
        after_midnight  TYPE timestampl VALUE '20261102060300',
        "! 01:30 CDT and 01:30 CST on 1 Nov (the repeated hour)
        repeated_cdt    TYPE timestampl VALUE '20261101063000',
        repeated_cst    TYPE timestampl VALUE '20261101073000',
        "! 01:59 CST and 03:01 CDT on 8 Mar (02:00-03:00 does not exist)
        before_jump     TYPE timestampl VALUE '20260308075900',
        after_jump      TYPE timestampl VALUE '20260308080100',
      END OF gc_utc.

    DATA mo_dao TYPE REF TO ltd_prism_dao.
    DATA ms_request TYPE zif_cd_fmon_types=>ty_read_request.

    METHODS setup.
    METHODS teardown.

    METHODS add_row
      IMPORTING
        iv_event_id  TYPE zif_cd_fmon_prism_types=>ty_event_id
        iv_milestone TYPE zif_cd_fmon_prism_types=>ty_milestone
        iv_iface     TYPE zif_cd_fmon_types=>ty_iface_id OPTIONAL
        iv_processed TYPE abap_bool DEFAULT abap_false
        iv_occurred  TYPE timestampl DEFAULT gc_test-occurred.

    METHODS rows_become_prism_stages FOR TESTING.
    METHODS interface_id_wins FOR TESTING.
    METHODS batch_reads_unprocessed FOR TESTING.
    METHODS unknown_field_is_refused FOR TESTING.
    METHODS central_dates_midnight_dst FOR TESTING.

ENDCLASS.


CLASS ltc_adapter_prism IMPLEMENTATION.

  METHOD setup.
    DATA ls_map TYPE zif_cd_fmon_types=>ty_srcmap.
    mo_dao = NEW #( ).
    zcl_cd_fmon_injector=>inject_prism_dao( mo_dao ).
    CLEAR ms_request.
    ms_request-src-src_id          = gc_test-src_id.
    ms_request-src-table_name      = 'ZCD_FMON_PRISM'.
    ms_request-src-file_name_field = 'FILE_REF'.
    ms_request-src-ts_field        = 'OCCURRED_AT'.
    ms_request-src-status_field    = 'MILESTONE'.
    ms_request-src-adapter_class   = zif_cd_fmon_prism_types=>gc_adapter_class.
    ms_request-time_zone           = zif_ca_ops_types=>gc_time_zone_utc.
    ms_request-date_from           = '20261105'.
    ms_request-date_to             = '20261106'.
    ms_request-max_rows            = 100.
    ls_map-src_id       = gc_test-src_id.
    ls_map-status_value = zif_cd_fmon_prism_types=>gc_milestone-received.
    ls_map-stage        = zif_cd_fmon_types=>gc_stage-prism_received.
    INSERT ls_map INTO TABLE ms_request-maps.
    ls_map-status_value = zif_cd_fmon_prism_types=>gc_milestone-delivered.
    ls_map-stage        = zif_cd_fmon_types=>gc_stage-prism_delivered.
    INSERT ls_map INTO TABLE ms_request-maps.
    ls_map-status_value = zif_cd_fmon_prism_types=>gc_milestone-failed.
    ls_map-stage        = zif_cd_fmon_types=>gc_stage-prism_failed.
    INSERT ls_map INTO TABLE ms_request-maps.
  ENDMETHOD.


  METHOD teardown.
    CLEAR mo_dao.
    zcl_cd_fmon_injector=>reset( ).
  ENDMETHOD.


  METHOD add_row.
    DATA ls_row TYPE zif_cd_fmon_prism_types=>ty_row.
    ls_row-event_id     = iv_event_id.
    ls_row-file_ref     = gc_test-file_name.
    ls_row-iface_id     = iv_iface.
    ls_row-direction    = zif_cd_fmon_types=>gc_direction-outbound.
    ls_row-milestone    = iv_milestone.
    ls_row-occurred_at  = iv_occurred.
    ls_row-processed_at = COND #( WHEN iv_processed = abap_true THEN gc_test-occurred ).
    INSERT ls_row INTO TABLE mo_dao->mt_rows.
  ENDMETHOD.


  " Rule: rows become records with the generic key rules (upper-case reference, business date
  " from occurredAt) and the stage of ZCD_FMON_SRCMAP.
  METHOD rows_become_prism_stages.
    DATA ls_exp TYPE zif_cd_fmon_types=>ty_src_record.
    TRY.
        add_row( iv_event_id = 'E1' iv_milestone = zif_cd_fmon_prism_types=>gc_milestone-delivered ).
        DATA(lt_records) = zcl_cd_fmon_adapter_prism=>to_records( is_request = ms_request
                                                                  it_rows    = mo_dao->mt_rows ).
        ls_exp-src_id        = gc_test-src_id.
        ls_exp-file_name     = gc_test-file_name.
        ls_exp-file_ref      = to_upper( gc_test-file_name ).
        ls_exp-raw_status    = zif_cd_fmon_prism_types=>gc_milestone-delivered.
        ls_exp-stage         = zif_cd_fmon_types=>gc_stage-prism_delivered.
        ls_exp-event_at      = gc_test-occurred.
        ls_exp-business_date = '20261106'.
        cl_abap_unit_assert=>assert_equals( act = lt_records exp = VALUE zif_cd_fmon_types=>tt_src_record( ( ls_exp ) )
                                            msg = 'One PRISM_DELIVERED record with the generic key rules' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an interfaceId sent by PRISM selects the interface (no name pattern needed).
  METHOD interface_id_wins.
    TRY.
        add_row( iv_event_id = 'E1' iv_milestone = zif_cd_fmon_prism_types=>gc_milestone-received
                 iv_iface = gc_test-iface ).
        DATA(lt_records) = zcl_cd_fmon_adapter_prism=>to_records( is_request = ms_request
                                                                  it_rows    = mo_dao->mt_rows ).
        cl_abap_unit_assert=>assert_equals( act = lt_records[ 1 ]-iface_id exp = gc_test-iface
                                            msg = 'The record must carry the interface PRISM named' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (safety net): the 5-minute run reads only events no unit processed, in the window
  " [date_from 00:00, date_to + 1 00:00) of RECEIVED_AT.
  METHOD batch_reads_unprocessed.
    DATA lv_from TYPE timestampl VALUE '20261105000000'.
    DATA lv_to TYPE timestampl VALUE '20261107000000'.
    TRY.
        add_row( iv_event_id = 'E1' iv_milestone = zif_cd_fmon_prism_types=>gc_milestone-received
                 iv_processed = abap_true ).
        add_row( iv_event_id = 'E2' iv_milestone = zif_cd_fmon_prism_types=>gc_milestone-failed ).
        DATA(lt_records) = NEW zcl_cd_fmon_adapter_prism( )->zif_cd_fmon_adapter~read( ms_request ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_records ) exp = 1 msg = 'Only the unprocessed event' ).
        cl_abap_unit_assert=>assert_equals( act = lt_records[ 1 ]-stage exp = zif_cd_fmon_types=>gc_stage-prism_failed
                                            msg = 'The failed event (its unit did not run) is applied' ).
        cl_abap_unit_assert=>assert_equals( act = |{ mo_dao->mv_from }/{ mo_dao->mv_to }| exp = |{ lv_from }/{ lv_to }|
                                            msg = 'Half-open window of the run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a configured field that is not a column of ZCD_FMON_PRISM is a configuration error.
  METHOD unknown_field_is_refused.
    TRY.
        add_row( iv_event_id = 'E1' iv_milestone = zif_cd_fmon_prism_types=>gc_milestone-received ).
        ms_request-src-file_name_field = 'FILE_NAME'.
        zcl_cd_fmon_adapter_prism=>to_records( is_request = ms_request
                                               it_rows    = mo_dao->mt_rows ).
        cl_abap_unit_assert=>fail( msg = 'An unknown field must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '201'
                                            msg = 'Message 201: field does not exist' ).
    ENDTRY.
  ENDMETHOD.


  " Acceptance (design review): the business date is occurredAt in FMON_TIME_ZONE (US Central,
  " daylight saving) - 23:58 CST stays on 1 Nov and 00:03 CST is 2 Nov; both 01:30 of the
  " repeated hour (CDT, then CST) are 1 Nov; both sides of the missing hour are 8 Mar. The event
  " time itself stays UTC, so SLA minutes are UTC differences.
  METHOD central_dates_midnight_dst.
    DATA lv_dates TYPE string.
    TRY.
        ms_request-time_zone = gc_test-central.
        add_row( iv_event_id = 'E1' iv_milestone = zif_cd_fmon_prism_types=>gc_milestone-delivered
                 iv_occurred = gc_utc-before_midnight ).
        add_row( iv_event_id = 'E2' iv_milestone = zif_cd_fmon_prism_types=>gc_milestone-delivered
                 iv_occurred = gc_utc-after_midnight ).
        add_row( iv_event_id = 'E3' iv_milestone = zif_cd_fmon_prism_types=>gc_milestone-received
                 iv_occurred = gc_utc-repeated_cdt ).
        add_row( iv_event_id = 'E4' iv_milestone = zif_cd_fmon_prism_types=>gc_milestone-delivered
                 iv_occurred = gc_utc-repeated_cst ).
        add_row( iv_event_id = 'E5' iv_milestone = zif_cd_fmon_prism_types=>gc_milestone-received
                 iv_occurred = gc_utc-before_jump ).
        add_row( iv_event_id = 'E6' iv_milestone = zif_cd_fmon_prism_types=>gc_milestone-delivered
                 iv_occurred = gc_utc-after_jump ).
        DATA(lt_records) = zcl_cd_fmon_adapter_prism=>to_records( is_request = ms_request
                                                                  it_rows    = mo_dao->mt_rows ).
        LOOP AT lt_records ASSIGNING FIELD-SYMBOL(<ls_record>).
          lv_dates = |{ lv_dates }{ <ls_record>-business_date }/|.
        ENDLOOP.
        cl_abap_unit_assert=>assert_equals(
          act = lv_dates
          exp = |20261101/20261102/20261101/20261101/20260308/20260308/|
          msg = 'Business dates must be the US Central dates around midnight and both DST changes' ).
        cl_abap_unit_assert=>assert_equals( act = lt_records[ 4 ]-event_at exp = gc_utc-repeated_cst
                                            msg = 'The event time stays UTC' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
