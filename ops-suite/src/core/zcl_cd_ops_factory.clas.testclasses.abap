*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_factory.clas.testclasses.abap
*& Purpose:
*& Tests of the suite factory over the framework ZCA_OPS: the parameters are
*& the framework adapter with the suite's name prefixes (every prefix reads
*& its area, the framework's prefixes read CA_OPS), an injected double of a
*& suite service is returned and reset, and ZCX_CD_OPS_ERROR classifies
*& ZCD_OPS messages by the suite's rules and hands every other message class
*& to the framework exception ZCX_CA_OPS_ERROR. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (framework ZCA_OPS: the plug-in tests moved with GET_PLUGIN to
*&            | ZCL_CA_OPS_FACTORY; suite services, parameter prefixes, exception classification).
*&---------------------------------------------------------------------*
CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
ENDCLASS.


CLASS ltc_factory DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        "! A ZCD_OPS message of the suite's lock / timeout rule and one of its configuration rule
        msg_transient TYPE symsgno VALUE '313',
        msg_config    TYPE symsgno VALUE '050',
        "! A ZCA_OPS message of the framework's lock rule
        msg_lock      TYPE symsgno VALUE '040',
      END OF gc_test.

    METHODS teardown.
    METHODS prefixes_read_suite_areas    FOR TESTING.
    METHODS injected_trace_dao_returned  FOR TESTING.
    METHODS suite_message_is_classified  FOR TESTING.
    METHODS framework_message_delegated  FOR TESTING.

    "! The suite exception with a message of the class
    METHODS raised
      IMPORTING
        iv_msgid        TYPE symsgid
        iv_msgno        TYPE symsgno
      RETURNING
        VALUE(rx_error) TYPE REF TO zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_factory IMPLEMENTATION.

  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD raised.
    TRY.
        RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE ID iv_msgid TYPE zif_ca_ops_types=>gc_msgty_error NUMBER iv_msgno.
      CATCH zcx_ca_ops_error INTO rx_error.
        RETURN.
    ENDTRY.
  ENDMETHOD.


  " Rule: every suite prefix reads its area; the framework's prefixes keep CA_OPS
  METHOD prefixes_read_suite_areas.
    zcl_cd_ops_injector=>inject_params( NEW zcl_ca_ops_param_seed( )->params( ) ).
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    cl_abap_unit_assert=>assert_equals( act = lo_params->area_of( zif_cd_ebs_types=>gc_param-gl_ledger )
                                        exp = zif_cd_ops_types=>gc_param_area-ebs msg = 'EBS_ is CD_EBS' ).
    cl_abap_unit_assert=>assert_equals( act = lo_params->area_of( zif_cd_fmon_types=>gc_param-max_rows )
                                        exp = zif_cd_ops_types=>gc_param_area-fmon msg = 'FMON_ is CD_FMON' ).
    cl_abap_unit_assert=>assert_equals( act = lo_params->area_of( zif_cd_hck_types=>gc_param-top_n )
                                        exp = zif_cd_ops_types=>gc_param_area-hck msg = 'HCK_ is CD_HCK' ).
    cl_abap_unit_assert=>assert_equals( act = lo_params->area_of( zif_cd_ops_trace_types=>gc_param-max_rows )
                                        exp = zif_cd_ops_types=>gc_param_area-ops msg = 'TRACE_ is CD_OPS' ).
    cl_abap_unit_assert=>assert_equals( act = lo_params->area_of( zif_ca_ops_types=>gc_param-alert_default )
                                        exp = zif_ca_ops_types=>gc_param_area msg = 'ALERT_ stays CA_OPS' ).
  ENDMETHOD.


  " Rule: an injected double of a suite service is returned until reset
  METHOD injected_trace_dao_returned.
    DATA(lo_double) = NEW ltd_trace_dao( ).
    zcl_cd_ops_injector=>inject_trace_dao( lo_double ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_factory=>get_trace_dao( ) exp = lo_double
                                        msg = 'The injected double is returned' ).
    zcl_cd_ops_injector=>reset( ).
    cl_abap_unit_assert=>assert_false( act = xsdbool( zcl_cd_ops_factory=>get_trace_dao( ) = lo_double )
                                       msg = 'After reset the real repository is returned' ).
  ENDMETHOD.


  " Rule: ZCX_CD_OPS_ERROR classifies ZCD_OPS messages by the suite's rules
  METHOD suite_message_is_classified.
    cl_abap_unit_assert=>assert_equals(
      act = raised( iv_msgid = zif_cd_ops_types=>gc_message_class iv_msgno = gc_test-msg_transient )->classify( )
      exp = zif_ca_ops_types=>gc_error_class-transient
      msg = 'A suite lock / timeout message is TRANSIENT' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_ops_util=>error_class( raised( iv_msgid = zif_cd_ops_types=>gc_message_class
                                                  iv_msgno = gc_test-msg_config ) )
      exp = zif_ca_ops_types=>gc_error_class-config
      msg = 'A suite configuration message is CONFIG (through the framework utility)' ).
  ENDMETHOD.


  " Rule: a message of another class is the framework's to classify
  METHOD framework_message_delegated.
    cl_abap_unit_assert=>assert_equals(
      act = raised( iv_msgid = zif_ca_ops_types=>gc_message_class iv_msgno = gc_test-msg_lock )->classify( )
      exp = zif_ca_ops_types=>gc_error_class-transient
      msg = 'ZCA_OPS 040 is TRANSIENT by the framework rules' ).
  ENDMETHOD.

ENDCLASS.
