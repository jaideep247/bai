*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_factory.clas.testclasses.abap
*& Purpose:
*& Tests of plug-in creation by class name (the mechanism behind every
*& configured rule, check, adapter and channel): unknown and abstract classes are
*& refused with ZCX_CD_OPS_ERROR, an injected double wins, a real class is created.
*& Written after the class (characterisation tests). Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (TDD gap closure).
*& 2026-11-06 | Authorisation seam: injected double is returned.
*&---------------------------------------------------------------------*
CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    CLEAR rv_timestamp.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~today.
    CLEAR rv_date.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~time.
    CLEAR rv_time.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_auth.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_cd_ops_auth~is_allowed.
    rv_allowed = abap_true.
  ENDMETHOD.
  METHOD zif_cd_ops_auth~check.
    RETURN.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_factory DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS teardown.

    METHODS unknown_class_is_refused     FOR TESTING.
    METHODS abstract_class_is_refused    FOR TESTING.
    METHODS injected_double_wins         FOR TESTING.
    METHODS real_class_is_created        FOR TESTING.
    METHODS class_name_case_insensitive  FOR TESTING.
    METHODS injected_clock_is_returned   FOR TESTING.
    METHODS injected_auth_is_returned    FOR TESTING.
ENDCLASS.


CLASS ltc_factory IMPLEMENTATION.

  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  " A class name in customizing that does not exist is refused, never dumps
  METHOD unknown_class_is_refused.
    TRY.
        zcl_cd_ops_factory=>get_plugin( 'ZCL_CD_DOES_NOT_EXIST' ).
        cl_abap_unit_assert=>fail( msg = 'Unknown class must raise ZCX_CD_OPS_ERROR' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '030'
                                            msg = 'Unknown class must raise message 030' ).
    ENDTRY.
  ENDMETHOD.


  " An abstract class (e.g. the rule base) cannot be configured as a plug-in
  METHOD abstract_class_is_refused.
    TRY.
        zcl_cd_ops_factory=>get_plugin( 'ZCL_CD_EBS_RULE_BASE' ).
        cl_abap_unit_assert=>fail( msg = 'Abstract class must raise ZCX_CD_OPS_ERROR' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '031'
                                            msg = 'Abstract class must raise message 031' ).
    ENDTRY.
  ENDMETHOD.


  " An injected double for a class name is returned instead of a new instance
  METHOD injected_double_wins.
    TRY.
        DATA(lo_double) = NEW ltd_clock( ).
        zcl_cd_ops_injector=>inject_plugin( iv_class_name = 'ZCL_CD_OPS_CLOCK' io_instance = lo_double ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_factory=>get_plugin( 'ZCL_CD_OPS_CLOCK' )
                                            exp = lo_double
                                            msg = 'Injected double must be returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A real, instantiable class is created and castable to its interface
  METHOD real_class_is_created.
    TRY.
        DATA(lo_object) = zcl_cd_ops_factory=>get_plugin( 'ZCL_CD_OPS_CLOCK' ).
        DATA(lo_clock) = CAST zif_cd_ops_clock( lo_object ).
        cl_abap_unit_assert=>assert_bound( act = lo_clock msg = 'Real plug-in must be created' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Customizing may hold the class name in lower case or with blanks
  METHOD class_name_case_insensitive.
    TRY.
        cl_abap_unit_assert=>assert_bound( act = zcl_cd_ops_factory=>get_plugin( ' zcl_cd_ops_clock' )
                                           msg = 'Lower-case class name must resolve' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Service getters return the injected double (seam used by every application test)
  METHOD injected_clock_is_returned.
    DATA(lo_double) = NEW ltd_clock( ).
    zcl_cd_ops_injector=>inject_clock( lo_double ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_factory=>get_clock( ) exp = lo_double
                                        msg = 'Injected clock must be returned' ).
  ENDMETHOD.


  " Every authorisation question goes through one seam, so consumers are testable
  METHOD injected_auth_is_returned.
    DATA(lo_double) = NEW ltd_auth( ).
    zcl_cd_ops_injector=>inject_auth( lo_double ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_factory=>get_auth( ) exp = lo_double
                                        msg = 'Injected authorisation double must be returned' ).
  ENDMETHOD.

ENDCLASS.
