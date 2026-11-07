*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_maint.clas.testclasses.abap
*& Purpose:
*& Unit tests of the maintenance gate over a local double of
*& ZIF_CA_PARAM_SYSTEM (LTD_SYSTEM): client read once, request read only in
*& transport mode, recording only in transport mode, recording failure
*& propagated, 044 / 045 messages, authorization delegated. Does not prove
*& live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
CLASS ltd_system DEFINITION FINAL FOR TESTING.

  PUBLIC SECTION.
    INTERFACES zif_ca_param_system.

    DATA ms_client         TYPE zif_ca_param_types=>ty_client.
    DATA ms_request_info   TYPE zif_ca_param_types=>ty_request_info.
    DATA mv_authorized     TYPE abap_bool.
    DATA mv_record_fails   TYPE abap_bool.
    DATA mv_client_reads   TYPE i.
    DATA mv_request_reads  TYPE i.
    DATA mv_records        TYPE i.
    DATA mv_recorded_req   TYPE zif_ca_param_types=>ty_request.
    DATA mv_checked_actvt  TYPE zif_ca_param_types=>ty_actvt.

ENDCLASS.


CLASS ltd_system IMPLEMENTATION.

  METHOD zif_ca_param_system~read_client.
    mv_client_reads = mv_client_reads + 1.
    rs_client = ms_client.
  ENDMETHOD.


  METHOD zif_ca_param_system~read_request.
    mv_request_reads = mv_request_reads + 1.
    rs_info = ms_request_info.
  ENDMETHOD.


  METHOD zif_ca_param_system~is_authorized.
    mv_checked_actvt = iv_actvt.
    rv_allowed = mv_authorized.
  ENDMETHOD.


  METHOD zif_ca_param_system~record_changes.
    IF mv_record_fails = abap_true.
      RAISE EXCEPTION zcx_ca_param=>create( VALUE #( msgid = zif_ca_param_types=>gc_msgid
                                                     msgno = zif_ca_param_types=>gc_msg-record_failed
                                                     v1    = iv_request ) ).
    ENDIF.
    mv_records      = mv_records + 1.
    mv_recorded_req = iv_request.
  ENDMETHOD.

ENDCLASS.


CLASS ltc_maint DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_request TYPE zif_ca_param_types=>ty_request VALUE 'DV1K900001'.
    CONSTANTS gc_area    TYPE zif_ca_param_types=>ty_area VALUE 'ZTEST'.
    CONSTANTS gc_name    TYPE zif_ca_param_types=>ty_name VALUE 'P1'.
    CONSTANTS gc_test    TYPE zif_ca_param_types=>ty_role VALUE 'T'.

    TYPES:
      BEGIN OF ty_flags,
        transport  TYPE abap_bool,
        authorized TYPE abap_bool,
        fails      TYPE abap_bool,
      END OF ty_flags.

    DATA mo_system TYPE REF TO ltd_system.
    DATA mo_cut    TYPE REF TO zcl_ca_param_maint.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    METHODS client_read_once FOR TESTING.
    METHODS request_read_in_transport FOR TESTING.
    METHODS no_request_read_locally FOR TESTING.
    METHODS record_in_transport_mode FOR TESTING.
    METHODS no_record_in_local_mode FOR TESTING.
    METHODS record_failure_propagates FOR TESTING RAISING cx_static_check.
    METHODS config_change_message FOR TESTING.
    METHODS value_change_message FOR TESTING.
    METHODS authorization_delegated FOR TESTING.
ENDCLASS.


CLASS ltc_maint IMPLEMENTATION.

  METHOD configure_scenario.
    mo_system = NEW #( ).
    mo_system->ms_client-role          = gc_test.
    mo_system->ms_client-cust_editable = abap_true.
    mo_system->ms_client-change_option = COND #( WHEN is_flags-transport = abap_true
                                                 THEN zif_ca_param_types=>gc_change_option-auto_record
                                                 ELSE zif_ca_param_types=>gc_change_option-no_changes ).
    mo_system->ms_request_info-exists   = abap_true.
    mo_system->ms_request_info-function = zif_ca_param_types=>gc_request-customizing_request.
    mo_system->ms_request_info-status   = zif_ca_param_types=>gc_request-modifiable.
    mo_system->mv_authorized   = is_flags-authorized.
    mo_system->mv_record_fails = is_flags-fails.
    mo_cut = NEW #( io_system = mo_system ).
  ENDMETHOD.


  METHOD client_read_once.
    TRY.
        configure_scenario( VALUE #( transport = abap_true ) ).
        mo_cut->mode( ).
        mo_cut->can_maintain_config( ).
        cl_abap_unit_assert=>assert_equals( act = mo_system->mv_client_reads
                                            exp = 1
                                            msg = `Client settings are read once per gate` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD request_read_in_transport.
    TRY.
        configure_scenario( VALUE #( transport = abap_true ) ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->check_request( iv_area    = gc_area
                                                                          iv_request = gc_request )
                                             msg = `Open customizing request accepted` ).
        cl_abap_unit_assert=>assert_equals( act = mo_system->mv_request_reads
                                            exp = 1
                                            msg = `The request is read in transport mode` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD no_request_read_locally.
    TRY.
        configure_scenario( VALUE #( transport = abap_false ) ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->check_request( iv_area    = gc_area
                                                                          iv_request = gc_request )
                                             msg = `No request check in a local client` ).
        cl_abap_unit_assert=>assert_equals( act = mo_system->mv_request_reads
                                            exp = 0
                                            msg = `No E070 read in a local client` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD record_in_transport_mode.
    DATA lt_rows TYPE string_table.

    TRY.
        configure_scenario( VALUE #( transport = abap_true ) ).
        mo_cut->record( iv_request = gc_request
                        ir_create  = REF #( lt_rows )
                        ir_update  = REF #( lt_rows )
                        ir_delete  = REF #( lt_rows ) ).
        cl_abap_unit_assert=>assert_equals( act = mo_system->mv_recorded_req
                                            exp = gc_request
                                            msg = `The save is recorded on the request` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD no_record_in_local_mode.
    DATA lt_rows TYPE string_table.

    TRY.
        configure_scenario( VALUE #( transport = abap_false ) ).
        mo_cut->record( iv_request = gc_request
                        ir_create  = REF #( lt_rows )
                        ir_update  = REF #( lt_rows )
                        ir_delete  = REF #( lt_rows ) ).
        cl_abap_unit_assert=>assert_equals( act = mo_system->mv_records
                                            exp = 0
                                            msg = `Local changes are not recorded (table logging only)` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD record_failure_propagates.
    DATA lt_rows TYPE string_table.

    configure_scenario( VALUE #( transport = abap_true fails = abap_true ) ).
    TRY.
        mo_cut->record( iv_request = gc_request
                        ir_create  = REF #( lt_rows )
                        ir_update  = REF #( lt_rows )
                        ir_delete  = REF #( lt_rows ) ).
        cl_abap_unit_assert=>fail( msg = `A recording failure must not be swallowed` ).
      CATCH zcx_ca_param INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = zif_ca_param_types=>gc_msg-record_failed
                                            msg = `Message 047` ).
    ENDTRY.
  ENDMETHOD.


  METHOD config_change_message.
    TRY.
        configure_scenario( VALUE #( transport = abap_false ) ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->check_config_change( gc_area )-msgno
                                            exp = zif_ca_param_types=>gc_msg-config_not_allowed
                                            msg = `Definitions are not maintained in a local client` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD value_change_message.
    TRY.
        configure_scenario( VALUE #( transport = abap_false ) ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->check_value_change( iv_area            = gc_area
                                                                              iv_name            = gc_name
                                                                              iv_prod_editable   = abap_true
                                                                              iv_developer_owned = abap_true )-msgno
                                            exp = zif_ca_param_types=>gc_msg-value_not_editable
                                            msg = `Developer-owned value not changeable in a local client` ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->check_value_change( iv_area            = gc_area
                                                                               iv_name            = gc_name
                                                                               iv_prod_editable   = abap_true
                                                                               iv_developer_owned = abap_false )
                                             msg = `Business-owned value of a production-editable area` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD authorization_delegated.
    TRY.
        configure_scenario( VALUE #( authorized = abap_true ) ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->is_authorized( iv_area  = gc_area
                                                                       iv_actvt = zif_ca_param_types=>gc_actvt-delete )
                                          msg = `The answer of the authorization check` ).
        cl_abap_unit_assert=>assert_equals( act = mo_system->mv_checked_actvt
                                            exp = zif_ca_param_types=>gc_actvt-delete
                                            msg = `The activity is passed on` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
