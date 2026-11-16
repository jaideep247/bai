*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_pf_fmon_events.clas.testclasses.abap
*& Purpose:
*& Tests of the overlay's event source: every FMON event of a file in the
*& window becomes one record with the FMON stage as native status, the
*& file's FMON reference, record ID file ID / event number; events outside
*& the window or of a stage not in the setting are left out; read through
*& a double of the FMON data access (ZCL_CD_FMON_INJECTOR); refused
*& without interfaces. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle overlay).
*&---------------------------------------------------------------------*
CLASS ltd_pf_fmon_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_dao PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_pf_fmon_dao IMPLEMENTATION.
  METHOD zif_cd_fmon_dao~get_eval_files.
    rt_files = VALUE #( ( file_id = '01' iface_id = 'ZT_ACH' file_ref = 'ACH_1' direction = 'O' business_date = '20261116' )
                        ( file_id = '02' iface_id = 'ZT_BAI' file_ref = 'BAI_1' direction = 'I' business_date = '20261116' ) ).
  ENDMETHOD.
  METHOD zif_cd_fmon_dao~get_events.
    rt_events = VALUE #( ( file_id = '01' event_no = 1 stage = 'GENERATED_IN_SAP' event_at = '20261116162000.0000000' )
                         ( file_id = '01' event_no = 2 stage = 'PRISM_DELIVERED' event_at = '20261116164500.0000000' )
                         ( file_id = '01' event_no = 3 stage = 'ACK_RECEIVED' event_at = '20261118090000.0000000' )
                         ( file_id = '02' event_no = 1 stage = 'FILE_RECEIVED' event_at = '20261116100000.0000000' ) ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_pf_fmon_events DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS teardown.
    METHODS window_and_stages FOR TESTING RAISING zcx_ca_ops_error.
    METHODS ifaces_required   FOR TESTING.
ENDCLASS.


CLASS ltc_pf_fmon_events IMPLEMENTATION.

  METHOD teardown.
    zcl_cd_fmon_injector=>reset( ).
  ENDMETHOD.


  METHOD window_and_stages.
    zcl_cd_fmon_injector=>inject_dao( NEW ltd_pf_fmon_dao( ) ).
    DATA(lo_cut) = NEW zcl_cd_pf_fmon_events( ).
    lo_cut->zif_ca_ops_pf_adapter~configure( VALUE #( role = 'TRANSFER'
                                                      setting = 'IFACES=ZT_ACH,ZT_BAI;STAGES=GENERATED_IN_SAP,PRISM_DELIVERED' ) ).
    DATA(ls_batch) = lo_cut->zif_ca_ops_pf_event_src~read_events( VALUE #( from_ts = '20261116000000.0000000'
                                                                           to_ts   = '20261117000000.0000000' ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_batch-events ) exp = 2 msg = 'Outbound, in the window, its stages' ).
    cl_abap_unit_assert=>assert_equals( act = ls_batch-events[ 2 ]-native_status exp = 'PRISM_DELIVERED' msg = 'FMON stage' ).
    cl_abap_unit_assert=>assert_equals( act = ls_batch-events[ 2 ]-native_key exp = 'ACH_1' msg = 'FMON reference' ).
    cl_abap_unit_assert=>assert_initial( act = ls_batch-events[ 2 ]-amount msg = 'No amount without currency' ).
  ENDMETHOD.


  METHOD ifaces_required.
    TRY.
        NEW zcl_cd_pf_fmon_events( )->zif_ca_ops_pf_adapter~configure( VALUE #( role = 'ACK' setting = 'STAGES=ACK_RECEIVED' ) ).
        cl_abap_unit_assert=>fail( msg = 'Refused expected' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '386' msg = '386' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
