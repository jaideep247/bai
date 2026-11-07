*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_gate.clas.testclasses.abap
*& Purpose:
*& Application tests of the configuration gate used by every RAP
*& configuration handler: client policy, request check, transport
*& recording and authorisation, with LTD_ doubles injected through
*& ZCL_CD_OPS_CFG_INJECTOR; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (written before the class, RAP config apps).
*& 2026-11-07 | Per-table create test withdrawn: new rows only by transport from DV1 (D-3).
*&---------------------------------------------------------------------*
CLASS ltd_client DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_cfg_client.
    DATA ms_client     TYPE zif_cd_ops_cfg_types=>ty_client.
    DATA ms_info       TYPE zif_cd_ops_cfg_types=>ty_request_info.
    DATA mv_read_calls TYPE i.
ENDCLASS.

CLASS ltd_client IMPLEMENTATION.
  METHOD zif_cd_ops_cfg_client~read_client.
    mv_read_calls += 1.
    rs_client = ms_client.
  ENDMETHOD.
  METHOD zif_cd_ops_cfg_client~read_request.
    rs_info = ms_info.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_transport DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_cfg_transport.
    DATA mv_calls   TYPE i.
    DATA mv_request TYPE zif_cd_ops_cfg_types=>ty_request.
ENDCLASS.

CLASS ltd_transport IMPLEMENTATION.
  METHOD zif_cd_ops_cfg_transport~record.
    mv_calls += 1.
    mv_request = iv_request.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_cfg_auth.
    DATA mv_allowed TYPE abap_bool.
    DATA mv_pe_area  TYPE zif_cd_ops_cfg_types=>ty_pe_area.
    DATA mv_actvt   TYPE zif_cd_ops_cfg_types=>ty_actvt.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_cd_ops_cfg_auth~is_authorized.
    mv_pe_area = iv_pe_area.
    mv_actvt  = iv_actvt.
    rv_allowed = mv_allowed.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_gate DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_request TYPE zif_cd_ops_cfg_types=>ty_request VALUE 'DV1K900123'.

    TYPES:
      BEGIN OF ty_flags,
        production   TYPE abap_bool,
        dv1          TYPE abap_bool,
        req_released TYPE abap_bool,
        authorized   TYPE abap_bool,
      END OF ty_flags.

    DATA mo_client    TYPE REF TO ltd_client.
    DATA mo_transport TYPE REF TO ltd_transport.
    DATA mo_auth      TYPE REF TO ltd_auth.

    METHODS setup.
    METHODS teardown.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.

    METHODS cut
      RETURNING
        VALUE(ro_gate) TYPE REF TO zcl_cd_ops_cfg_gate.

    METHODS production_disables_create   FOR TESTING.
    METHODS dv1_enables_create_delete    FOR TESTING.
    METHODS dv1_rejects_released_request FOR TESTING.
    METHODS no_recording_in_production   FOR TESTING.
    METHODS dv1_records_on_request       FOR TESTING.
    METHODS auth_asks_area_and_actvt   FOR TESTING.
    METHODS client_is_read_once          FOR TESTING.
ENDCLASS.


CLASS ltc_gate IMPLEMENTATION.

  METHOD setup.
    mo_client    = NEW #( ).
    mo_transport = NEW #( ).
    mo_auth      = NEW #( ).
    zcl_cd_ops_cfg_injector=>inject_client( mo_client ).
    zcl_cd_ops_cfg_injector=>inject_transport( mo_transport ).
    zcl_cd_ops_cfg_injector=>inject_auth( mo_auth ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_cfg_injector=>reset( ).
    CLEAR: mo_client, mo_transport, mo_auth.
  ENDMETHOD.


  METHOD configure_scenario.
    IF is_flags-production = abap_true.
      mo_client->ms_client-change_option = zif_cd_ops_cfg_types=>gc_change_option-no_changes.
      mo_client->ms_client-role          = zif_cd_ops_cfg_types=>gc_role_production.
    ENDIF.
    IF is_flags-dv1 = abap_true.
      mo_client->ms_client-change_option = zif_cd_ops_cfg_types=>gc_change_option-auto_record.
      mo_client->ms_client-role          = 'C'.
    ENDIF.
    mo_client->ms_info-exists   = abap_true.
    mo_client->ms_info-function = zif_cd_ops_cfg_types=>gc_request-customizing_request.
    mo_client->ms_info-status   = COND #( WHEN is_flags-req_released = abap_true THEN 'R'
                                          ELSE zif_cd_ops_cfg_types=>gc_request-modifiable ).
    mo_auth->mv_allowed = is_flags-authorized.
  ENDMETHOD.


  METHOD cut.
    ro_gate = zcl_cd_ops_cfg_factory=>get_gate( ).
  ENDMETHOD.


  " Rule: production never offers 'create' or 'delete' (D-3: new entries via transport)
  METHOD production_disables_create.
    TRY.
        configure_scenario( VALUE #( production = abap_true ) ).
        DATA(lo_gate) = cut( ).
        cl_abap_unit_assert=>assert_false( act = lo_gate->create_allowed( ) msg = 'No create in production' ).
        cl_abap_unit_assert=>assert_false( act = lo_gate->delete_allowed( ) msg = 'No delete in production' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD dv1_enables_create_delete.
    TRY.
        configure_scenario( VALUE #( dv1 = abap_true ) ).
        DATA(lo_gate) = cut( ).
        cl_abap_unit_assert=>assert_true( act = lo_gate->create_allowed( ) msg = 'Create allowed in DV1' ).
        cl_abap_unit_assert=>assert_true( act = lo_gate->delete_allowed( ) msg = 'Delete allowed in DV1' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: in DV1 the request is read from E070 and a released one is refused
  METHOD dv1_rejects_released_request.
    TRY.
        configure_scenario( VALUE #( dv1 = abap_true req_released = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = cut( )->check_request( gc_request )-number
                                            exp = zif_cd_ops_cfg_types=>gc_msg-request_released
                                            msg = 'A released request must give message 405' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: production changes are change-logged, never put on a transport
  METHOD no_recording_in_production.
    TRY.
        configure_scenario( VALUE #( production = abap_true ) ).
        cut( )->record( iv_request   = gc_request
                        it_relations = VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = mo_transport->mv_calls exp = 0
                                            msg = 'Nothing is recorded in production' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD dv1_records_on_request.
    TRY.
        configure_scenario( VALUE #( dv1 = abap_true ) ).
        cut( )->record( iv_request   = gc_request
                        it_relations = VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = mo_transport->mv_calls exp = 1
                                            msg = 'DV1 changes are recorded once' ).
        cl_abap_unit_assert=>assert_equals( act = mo_transport->mv_request exp = gc_request
                                            msg = 'Recorded on the selected request' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: authorisation object ZCD_OPS is asked for the app's payment engine area and the activity
  METHOD auth_asks_area_and_actvt.
    TRY.
        configure_scenario( VALUE #( dv1 = abap_true authorized = abap_true ) ).
        cl_abap_unit_assert=>assert_true(
          act = cut( )->is_authorized( iv_pe_area = zif_cd_ops_cfg_types=>gc_pe_area-fmon
                                       iv_actvt  = zif_cd_ops_cfg_types=>gc_actvt-change )
          msg = 'The answer of the authorisation check is returned' ).
        cl_abap_unit_assert=>assert_equals( act = mo_auth->mv_pe_area exp = zif_cd_ops_cfg_types=>gc_pe_area-fmon
                                            msg = 'Payment engine area passed to the check' ).
        cl_abap_unit_assert=>assert_equals( act = mo_auth->mv_actvt exp = zif_cd_ops_cfg_types=>gc_actvt-change
                                            msg = 'Activity passed to the check' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: T000 is read once per gate instance (feature control asks per entity)
  METHOD client_is_read_once.
    TRY.
        configure_scenario( VALUE #( dv1 = abap_true ) ).
        DATA(lo_gate) = cut( ).
        lo_gate->create_allowed( ).
        lo_gate->delete_allowed( ).
        lo_gate->check_request( gc_request ).
        cl_abap_unit_assert=>assert_equals( act = mo_client->mv_read_calls exp = 1
                                            msg = 'Client settings must be read once' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
