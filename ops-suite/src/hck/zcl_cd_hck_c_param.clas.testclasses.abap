*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_param.clas.testclasses.abap
*& Purpose:
*& Unit tests of the configuration check PARAM_INVALID with the REAL framework
*& logic: the in-memory data of ZCL_CD_OPS_PARAM_SEED (every delivered area and
*& definition) injected into ZCL_CA_PARAM_INJECTOR (reads) and the HCK factory
*& (definition list). Valid set, invalid value, invalid extra definition,
*& delivered definition missing, area missing. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (parameters moved to ZCA_PARAM).
*&---------------------------------------------------------------------*
CLASS ltc_param_check DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        check_id   TYPE zif_cd_hck_types=>ty_check_id VALUE 'D_PARAM',
        name       TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_TOP_N',
        bad_value  TYPE string VALUE `many`,
        extra      TYPE zif_ca_param_types=>ty_name VALUE 'HCK_LOCAL_EXTRA',
        bad_dflt   TYPE zif_ca_param_types=>ty_value VALUE 'x',
        msgno_name TYPE symsgno VALUE '003',
      END OF gc_test.

    TYPES:
      BEGIN OF ty_flags,
        bad_value     TYPE abap_bool,
        bad_extra     TYPE abap_bool,
        missing_def   TYPE abap_bool,
        missing_area  TYPE abap_bool,
      END OF ty_flags.

    DATA mo_seed TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS delivered_set_is_valid FOR TESTING.
    METHODS invalid_value_reported FOR TESTING.
    METHODS invalid_extra_def_reported FOR TESTING.
    METHODS missing_definition_reported FOR TESTING.
    METHODS missing_area_reported_once FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_param_check IMPLEMENTATION.

  METHOD setup.
    mo_seed = NEW #( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_param_injector=>reset( ).
    zcl_cd_hck_injector=>reset( ).
    CLEAR mo_seed.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA lo_dao TYPE REF TO zcl_ca_param_dao_mem.
    DATA ls_definition TYPE zif_ca_param_types=>ty_definition.

    lo_dao = mo_seed->dao( ).
    IF is_flags-bad_value = abap_true.
      mo_seed->set( iv_name = gc_test-name iv_value = gc_test-bad_value ).
    ENDIF.
    IF is_flags-bad_extra = abap_true.
      ls_definition-area          = zif_cd_ops_types=>gc_param_area-hck.
      ls_definition-name          = gc_test-extra.
      ls_definition-kind          = zif_ca_param_types=>gc_kind-single.
      ls_definition-value_type    = zif_ca_param_types=>gc_value_type-int.
      ls_definition-default_value = gc_test-bad_dflt.
      lo_dao->add_definition( ls_definition ).
    ENDIF.
    IF is_flags-missing_def = abap_true OR is_flags-missing_area = abap_true.
      " a database without the delivered definition (or without the whole area)
      lo_dao = NEW #( ).
      LOOP AT zcl_cd_ops_param_seed=>areas( ) ASSIGNING FIELD-SYMBOL(<ls_area>).
        IF is_flags-missing_area = abap_false OR <ls_area>-area <> zif_cd_ops_types=>gc_param_area-hck.
          lo_dao->add_area( <ls_area> ).
        ENDIF.
      ENDLOOP.
      LOOP AT zcl_cd_ops_param_seed=>definitions( ) ASSIGNING FIELD-SYMBOL(<ls_definition>)
           WHERE name <> gc_test-name.
        lo_dao->add_definition( <ls_definition> ).
      ENDLOOP.
    ENDIF.
    zcl_ca_param_injector=>inject_dao( lo_dao ).
    zcl_cd_hck_injector=>inject_param_dao( lo_dao ).
  ENDMETHOD.


  METHOD act.
    DATA ls_def TYPE zif_cd_hck_types=>ty_check_def.
    ls_def-check_id = gc_test-check_id.
    rs_result = NEW zcl_cd_hck_c_param( )->zif_cd_hck_check~execute( is_def        = ls_def
                                                                     it_thresholds = VALUE #( )
                                                                     is_context    = VALUE #( ) ).
  ENDMETHOD.


  " Rule: the delivered areas and definitions are all readable - no finding, metric 0
  METHOD delivered_set_is_valid.
    TRY.
        configure_scenario( VALUE #( ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'No invalid parameter' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 0 msg = 'Metric 0' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a value that is invalid for its definition is one E finding area/name
  METHOD invalid_value_reported.
    TRY.
        configure_scenario( VALUE #( bad_value = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One finding' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_result-findings[ 1 ]-object_key
          exp = CONV zif_ca_ops_types=>ty_object_key( |{ zif_cd_ops_types=>gc_param_area-hck }/{ gc_test-name }| )
          msg = 'Object key area/name' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_cd_hck_types=>gc_code-param_invalid msg = 'PARAM_INVALID' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-severity
                                            exp = zif_ca_ops_types=>gc_severity-error msg = 'Severity E' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 1 msg = 'Metric 1' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a definition maintained only in the database is checked too (here: invalid default)
  METHOD invalid_extra_def_reported.
    TRY.
        configure_scenario( VALUE #( bad_extra = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One finding' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_result-findings[ 1 ]-object_key
          exp = CONV zif_ca_ops_types=>ty_object_key( |{ zif_cd_ops_types=>gc_param_area-hck }/{ gc_test-extra }| )
          msg = 'The extra definition is reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a delivered definition that the database lacks is reported (name not defined, 003)
  METHOD missing_definition_reported.
    TRY.
        configure_scenario( VALUE #( missing_def = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One finding' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_result-findings[ 1 ]-message
          exp = CONV zif_ca_ops_types=>ty_message( zcx_ca_param=>create( VALUE #(
                  msgid = zif_ca_param_types=>gc_msgid
                  msgno = gc_test-msgno_name
                  v1    = zif_cd_ops_types=>gc_param_area-hck
                  v2    = gc_test-name ) )->get_text( ) )
          msg = 'The framework message: not defined in the area' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an area that does not exist is one finding, its parameters are not read one by one
  METHOD missing_area_reported_once.
    TRY.
        configure_scenario( VALUE #( missing_area = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-object_key
                                            exp = CONV zif_ca_ops_types=>ty_object_key(
                                                    zif_cd_ops_types=>gc_param_area-hck )
                                            msg = 'The area is the object' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
