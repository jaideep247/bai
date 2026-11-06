*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_client.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the client / request repository of the configuration apps
*& with T000 and E070 doubled: change option and role of the logon client,
*& an unreadable client treated as production (fail closed), an existing
*& and an unknown request. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltc_cfg_client DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        role_test   TYPE zif_cd_ops_cfg_types=>ty_client_role VALUE 'T',
        request     TYPE zif_cd_ops_cfg_types=>ty_request VALUE 'DV1K900123',
        unknown     TYPE zif_cd_ops_cfg_types=>ty_request VALUE 'DV1K999999',
        modifiable  TYPE zif_cd_ops_cfg_types=>ty_req_status VALUE 'D',
        customizing TYPE zif_cd_ops_cfg_types=>ty_req_function VALUE 'W',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ops_cfg_client.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS add_client.
    METHODS add_request.

    METHODS client_settings_are_read FOR TESTING.
    METHODS missing_client_is_production FOR TESTING.
    METHODS existing_request_is_read FOR TESTING.
    METHODS unknown_request_not_exists FOR TESTING.
ENDCLASS.


CLASS ltc_cfg_client IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'T000' ) ( 'E070' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_ops_cfg_client( ).
  ENDMETHOD.


  METHOD add_client.
    DATA lt_rows TYPE STANDARD TABLE OF t000 WITH EMPTY KEY.
    DATA ls_row TYPE t000.
    ls_row-mandt      = sy-mandt.
    ls_row-cccoractiv = zif_cd_ops_cfg_types=>gc_change_option-auto_record.
    ls_row-cccategory = gc_test-role_test.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  METHOD add_request.
    DATA lt_rows TYPE STANDARD TABLE OF e070 WITH EMPTY KEY.
    DATA ls_row TYPE e070.
    ls_row-trkorr     = gc_test-request.
    ls_row-trstatus   = gc_test-modifiable.
    ls_row-trfunction = gc_test-customizing.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  " Rule: change option (SCC4) and role come from the logon client's T000 row
  METHOD client_settings_are_read.
    TRY.
        add_client( ).
        DATA(ls_client) = mo_cut->read_client( ).
        cl_abap_unit_assert=>assert_equals( act = ls_client-change_option
                                            exp = zif_cd_ops_cfg_types=>gc_change_option-auto_record
                                            msg = 'Change option from T000' ).
        cl_abap_unit_assert=>assert_equals( act = ls_client-role exp = gc_test-role_test msg = 'Role from T000' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an unreadable client is production without changes - fail closed
  METHOD missing_client_is_production.
    TRY.
        DATA(ls_client) = mo_cut->read_client( ).
        cl_abap_unit_assert=>assert_equals( act = ls_client-change_option
                                            exp = zif_cd_ops_cfg_types=>gc_change_option-no_changes
                                            msg = 'No changes allowed' ).
        cl_abap_unit_assert=>assert_equals( act = ls_client-role
                                            exp = zif_cd_ops_cfg_types=>gc_role_production
                                            msg = 'Treated as production' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an existing request returns its status and function (E070)
  METHOD existing_request_is_read.
    TRY.
        add_request( ).
        DATA(ls_info) = mo_cut->read_request( gc_test-request ).
        cl_abap_unit_assert=>assert_true( act = ls_info-exists msg = 'Request exists' ).
        cl_abap_unit_assert=>assert_equals( act = ls_info-status exp = gc_test-modifiable msg = 'Status from E070' ).
        cl_abap_unit_assert=>assert_equals( act = ls_info-function exp = gc_test-customizing
                                            msg = 'Function from E070' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an unknown request does not exist (initial result)
  METHOD unknown_request_not_exists.
    TRY.
        add_request( ).
        DATA(ls_info) = mo_cut->read_request( gc_test-unknown ).
        cl_abap_unit_assert=>assert_initial( act = ls_info msg = 'Unknown request is initial' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
