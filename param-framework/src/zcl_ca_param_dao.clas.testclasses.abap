*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of ZCL_CA_PARAM_DAO: all three tables are doubled with
*& cl_osql_test_environment (created in class_setup, cleared in setup,
*& destroyed in class_teardown). Proves the area filter, the found flag
*& and the key order of definitions and values (rows inserted out of
*& order). Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
CLASS ltc_dao DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_area  TYPE zif_ca_param_types=>ty_area VALUE 'ZTEST'.
    CONSTANTS gc_other TYPE zif_ca_param_types=>ty_area VALUE 'ZOTHER'.

    CLASS-DATA go_environment TYPE REF TO if_osql_test_environment.

    DATA mo_cut TYPE REF TO zif_ca_param_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS insert_area
      IMPORTING
        iv_area TYPE zif_ca_param_types=>ty_area.
    METHODS insert_definition
      IMPORTING
        iv_area TYPE zif_ca_param_types=>ty_area
        iv_name TYPE zif_ca_param_types=>ty_name.
    METHODS insert_value
      IMPORTING
        iv_area TYPE zif_ca_param_types=>ty_area
        iv_name TYPE zif_ca_param_types=>ty_name
        iv_numb TYPE zif_ca_param_types=>ty_numb
        iv_low  TYPE zif_ca_param_types=>ty_value.

    METHODS unknown_area_not_found FOR TESTING.
    METHODS area_row_is_read FOR TESTING.
    METHODS definitions_ordered_by_name FOR TESTING.
    METHODS values_ordered_by_name_numb FOR TESTING.
    METHODS other_area_is_not_read FOR TESTING.
ENDCLASS.


CLASS ltc_dao IMPLEMENTATION.

  METHOD class_setup.
    go_environment = cl_osql_test_environment=>create(
                       i_dependency_list = VALUE #( ( 'ZCA_PARAM_AREA' ) ( 'ZCA_PARAM_DEF' ) ( 'ZCA_PARAM_VAL' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_environment->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_environment->clear_doubles( ).
    mo_cut = NEW zcl_ca_param_dao( ).
  ENDMETHOD.


  METHOD insert_area.
    DATA lt_rows TYPE STANDARD TABLE OF zca_param_area WITH EMPTY KEY.
    DATA ls_row  TYPE zca_param_area.

    ls_row-area          = iv_area.
    ls_row-description   = iv_area.
    ls_row-owner_team    = iv_area.
    ls_row-prod_editable = abap_true.
    ls_row-active        = abap_true.
    INSERT ls_row INTO TABLE lt_rows.
    go_environment->insert_test_data( lt_rows ).
  ENDMETHOD.


  METHOD insert_definition.
    DATA lt_rows TYPE STANDARD TABLE OF zca_param_def WITH EMPTY KEY.
    DATA ls_row  TYPE zca_param_def.

    ls_row-area       = iv_area.
    ls_row-name       = iv_name.
    ls_row-kind       = zif_ca_param_types=>gc_kind-select.
    ls_row-value_type = zif_ca_param_types=>gc_value_type-char.
    INSERT ls_row INTO TABLE lt_rows.
    go_environment->insert_test_data( lt_rows ).
  ENDMETHOD.


  METHOD insert_value.
    DATA lt_rows TYPE STANDARD TABLE OF zca_param_val WITH EMPTY KEY.
    DATA ls_row  TYPE zca_param_val.

    ls_row-area = iv_area.
    ls_row-name = iv_name.
    ls_row-numb = iv_numb.
    ls_row-sign = zif_ca_param_types=>gc_sign-include.
    ls_row-opti = zif_ca_param_types=>gc_option-eq.
    ls_row-low  = iv_low.
    INSERT ls_row INTO TABLE lt_rows.
    go_environment->insert_test_data( lt_rows ).
  ENDMETHOD.


  METHOD unknown_area_not_found.
    TRY.
        insert_area( gc_other ).
        DATA(ls_data) = mo_cut->read_area( gc_area ).
        cl_abap_unit_assert=>assert_false( act = ls_data-found
                                           msg = `An area without master row is not found` ).
        cl_abap_unit_assert=>assert_initial( act = ls_data-definitions
                                             msg = `No definitions for an unknown area` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD area_row_is_read.
    TRY.
        insert_area( gc_area ).
        DATA(ls_data) = mo_cut->read_area( gc_area ).
        cl_abap_unit_assert=>assert_true( act = ls_data-found
                                          msg = `The area is found` ).
        cl_abap_unit_assert=>assert_equals( act = ls_data-area-prod_editable
                                            exp = abap_true
                                            msg = `PROD_EDITABLE is read` ).
        cl_abap_unit_assert=>assert_equals( act = ls_data-area-active
                                            exp = abap_true
                                            msg = `ACTIVE is read` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD definitions_ordered_by_name.
    DATA lt_exp TYPE string_table.

    TRY.
        insert_area( gc_area ).
        insert_definition( iv_area = gc_area iv_name = 'ZETA' ).
        insert_definition( iv_area = gc_area iv_name = 'ALPHA' ).
        insert_definition( iv_area = gc_area iv_name = 'MID' ).
        DATA(ls_data) = mo_cut->read_area( gc_area ).
        lt_exp = VALUE #( ( `ALPHA` ) ( `MID` ) ( `ZETA` ) ).
        cl_abap_unit_assert=>assert_equals( act = VALUE string_table( FOR ls_def IN ls_data-definitions
                                                                       ( CONV string( ls_def-name ) ) )
                                            exp = lt_exp
                                            msg = `Definitions in key order, whatever the insert order` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD values_ordered_by_name_numb.
    DATA lt_exp TYPE string_table.

    TRY.
        insert_area( gc_area ).
        insert_definition( iv_area = gc_area iv_name = 'LIST' ).
        insert_value( iv_area = gc_area iv_name = 'LIST' iv_numb = '0003' iv_low = 'C' ).
        insert_value( iv_area = gc_area iv_name = 'LIST' iv_numb = '0001' iv_low = 'A' ).
        insert_value( iv_area = gc_area iv_name = 'LIST' iv_numb = '0002' iv_low = 'B' ).
        DATA(ls_data) = mo_cut->read_area( gc_area ).
        lt_exp = VALUE #( ( `A` ) ( `B` ) ( `C` ) ).
        cl_abap_unit_assert=>assert_equals( act = VALUE string_table( FOR ls_val IN ls_data-values
                                                                       ( CONV string( ls_val-low ) ) )
                                            exp = lt_exp
                                            msg = `Values in NUMB order, whatever the insert order` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD other_area_is_not_read.
    TRY.
        insert_area( gc_area ).
        insert_area( gc_other ).
        insert_definition( iv_area = gc_other iv_name = 'P1' ).
        insert_value( iv_area = gc_other iv_name = 'P1' iv_numb = '0001' iv_low = 'X' ).
        DATA(ls_data) = mo_cut->read_area( gc_area ).
        cl_abap_unit_assert=>assert_initial( act = ls_data-definitions
                                             msg = `Definitions of another area are not read` ).
        cl_abap_unit_assert=>assert_initial( act = ls_data-values
                                             msg = `Values of another area are not read` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
