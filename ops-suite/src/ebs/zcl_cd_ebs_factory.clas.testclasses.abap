*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_factory.clas.testclasses.abap
*& Purpose:
*& Unit tests of the EBS factory: injected doubles win (ZCL_CD_EBS_INJECTOR),
*& reset( ) restores the delivered repositories (created only - no method
*& of a real repository is called, so no database is read), the parser
*& comes from parameter EBS_PARSER_<format> of the injected store double
*& with the delivered default, a class that is no parser is refused. Does
*& not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltd_cfg_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_cfg_dao PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_cfg_dao IMPLEMENTATION.
ENDCLASS.


CLASS ltd_feb_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_feb_dao PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_feb_dao IMPLEMENTATION.
ENDCLASS.


CLASS ltd_sap_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_sap_dao PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_sap_dao IMPLEMENTATION.
ENDCLASS.


CLASS ltd_release_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_release_dao PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_release_dao IMPLEMENTATION.
ENDCLASS.


CLASS ltd_parser DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_parser PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_parser IMPLEMENTATION.
ENDCLASS.


CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store PARTIALLY IMPLEMENTED.
    DATA mt_params TYPE zif_cd_ops_types=>tt_kv.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_cd_ops_store~get_param.
    READ TABLE mt_params INTO DATA(ls_param) WITH TABLE KEY name = iv_name.
    rv_value = COND #( WHEN sy-subrc = 0 THEN ls_param-value ELSE iv_default ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ebs_factory DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_param_bai2  TYPE zif_cd_ops_types=>ty_param_name VALUE 'EBS_PARSER_BAI2',
      gc_not_parser  TYPE string VALUE `ZCL_CD_OPS_CLOCK`,
      gc_msgno_kind  TYPE symsgno VALUE '032'.

    TYPES:
      BEGIN OF ty_flags,
        doubles      TYPE abap_bool,
        wrong_parser TYPE abap_bool,
      END OF ty_flags.

    DATA mo_store TYPE REF TO ltd_store.
    DATA mo_cfg TYPE REF TO ltd_cfg_dao.
    DATA mo_feb TYPE REF TO ltd_feb_dao.
    DATA mo_sap TYPE REF TO ltd_sap_dao.
    DATA mo_release TYPE REF TO ltd_release_dao.
    DATA mo_parser TYPE REF TO ltd_parser.

    METHODS setup.
    METHODS teardown.
    METHODS injected_doubles_win FOR TESTING.
    METHODS delivered_repositories FOR TESTING.
    METHODS default_parser_per_format FOR TESTING.
    METHODS wrong_parser_class_refused FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
ENDCLASS.


CLASS ltc_ebs_factory IMPLEMENTATION.

  METHOD setup.
    mo_store   = NEW #( ).
    mo_cfg     = NEW #( ).
    mo_feb     = NEW #( ).
    mo_sap     = NEW #( ).
    mo_release = NEW #( ).
    mo_parser  = NEW #( ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ebs_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD configure_scenario.
    IF is_flags-doubles = abap_true.
      zcl_cd_ebs_injector=>inject_cfg_dao( mo_cfg ).
      zcl_cd_ebs_injector=>inject_feb_dao( mo_feb ).
      zcl_cd_ebs_injector=>inject_sap_dao( mo_sap ).
      zcl_cd_ebs_injector=>inject_release_dao( mo_release ).
      zcl_cd_ebs_injector=>inject_parser( mo_parser ).
    ENDIF.
    IF is_flags-wrong_parser = abap_true.
      INSERT VALUE #( name = gc_param_bai2 value = gc_not_parser ) INTO TABLE mo_store->mt_params.
    ENDIF.
  ENDMETHOD.


  " Rule: an injected double is returned for every repository and the parser
  METHOD injected_doubles_win.
    TRY.
        configure_scenario( VALUE #( doubles = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_factory=>get_cfg_dao( ) exp = mo_cfg
                                            msg = 'Configuration DAO double' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_factory=>get_feb_dao( ) exp = mo_feb
                                            msg = 'FEB DAO double' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_factory=>get_sap_dao( ) exp = mo_sap
                                            msg = 'SAP DAO double' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ebs_factory=>get_release_dao( ) exp = mo_release
                                            msg = 'Release DAO double' ).
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_ebs_factory=>get_parser( zif_cd_ebs_types=>gc_format-bai2 )
          exp = mo_parser
          msg = 'Parser double' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without doubles the delivered repositories are created (no method called: no SQL)
  METHOD delivered_repositories.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( zcl_cd_ebs_factory=>get_cfg_dao( ) IS INSTANCE OF zcl_cd_ebs_cfg_dao )
          msg = 'Delivered configuration DAO' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( zcl_cd_ebs_factory=>get_feb_dao( ) IS INSTANCE OF zcl_cd_ebs_feb_dao )
          msg = 'Delivered FEB DAO' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( zcl_cd_ebs_factory=>get_sap_dao( ) IS INSTANCE OF zcl_cd_ebs_sap_dao )
          msg = 'Delivered SAP DAO' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( zcl_cd_ebs_factory=>get_release_dao( ) IS INSTANCE OF zcl_cd_ebs_release_dao )
          msg = 'Delivered release DAO' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without parameter the delivered parser of the format is created
  METHOD default_parser_per_format.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( zcl_cd_ebs_factory=>get_parser( zif_cd_ebs_types=>gc_format-bai2 )
                         IS INSTANCE OF zcl_cd_ebs_parser_bai2 )
          msg = 'BAI2 parser by default' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( zcl_cd_ebs_factory=>get_parser( zif_cd_ebs_types=>gc_format-camt053 )
                         IS INSTANCE OF zcl_cd_ebs_parser_camt )
          msg = 'camt parser by default' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A62): a configured class that is not a parser is refused (032), never created
  METHOD wrong_parser_class_refused.
    configure_scenario( VALUE #( wrong_parser = abap_true ) ).
    TRY.
        zcl_cd_ebs_factory=>get_parser( zif_cd_ebs_types=>gc_format-bai2 ).
        cl_abap_unit_assert=>fail( msg = 'A class that is no parser must be refused' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = gc_msgno_kind
                                            msg = 'Refused with message 032' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
