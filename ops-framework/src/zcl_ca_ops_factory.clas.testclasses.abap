*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_factory.clas.testclasses.abap
*& Purpose:
*& Tests of plug-in creation by class name (the mechanism behind every
*& configured rule, check, adapter and channel): unknown and abstract classes are
*& refused with ZCX_CA_OPS_ERROR, an injected double wins, a real class is created.
*& Written after the class (characterisation tests). Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (TDD gap closure).
*& 2026-11-06 | Authorisation seam: injected double is returned.
*& 2026-11-06 | Interface check before instantiation (audit A62).
*& 2026-11-06 | Modern-syntax sweep: no trailing RETURN.
*& 2026-11-10 | Moved from ZCL_CD_OPS_FACTORY to the reusable framework ZCA_OPS (test include).
*& 2026-11-10 | injected_check_dao_returned, real_check_dao_created (check registry, process onboarding).
*&---------------------------------------------------------------------*
CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    CLEAR rv_timestamp.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    CLEAR rv_date.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    CLEAR rv_time.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_auth.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_ca_ops_auth~is_allowed.
    rv_allowed = abap_true.
  ENDMETHOD.
  METHOD zif_ca_ops_auth~check.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_check_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check_dao PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_check_dao IMPLEMENTATION.
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
    METHODS injected_check_dao_returned  FOR TESTING.
    METHODS real_check_dao_created       FOR TESTING.
    METHODS unrelated_class_not_created  FOR TESTING.
    METHODS matching_interface_creates   FOR TESTING.
    METHODS unknown_interface_refused    FOR TESTING.
    METHODS double_must_match_interface  FOR TESTING.
    METHODS old_param_release_refused    FOR TESTING.
    METHODS current_param_release_passes FOR TESTING.
ENDCLASS.


CLASS ltc_factory IMPLEMENTATION.

  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  " A class name in customizing that does not exist is refused, never dumps
  METHOD unknown_class_is_refused.
    TRY.
        zcl_ca_ops_factory=>get_plugin( 'ZCL_CA_DOES_NOT_EXIST' ).
        cl_abap_unit_assert=>fail( msg = 'Unknown class must raise ZCX_CA_OPS_ERROR' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '030'
                                            msg = 'Unknown class must raise message 030' ).
    ENDTRY.
  ENDMETHOD.


  " An abstract class (e.g. the rule base) cannot be configured as a plug-in
  METHOD abstract_class_is_refused.
    TRY.
        zcl_ca_ops_factory=>get_plugin( 'CL_ABAP_TYPEDESCR' ).
        cl_abap_unit_assert=>fail( msg = 'Abstract class must raise ZCX_CA_OPS_ERROR' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '031'
                                            msg = 'Abstract class must raise message 031' ).
    ENDTRY.
  ENDMETHOD.


  " An injected double for a class name is returned instead of a new instance
  METHOD injected_double_wins.
    TRY.
        DATA(lo_double) = NEW ltd_clock( ).
        zcl_ca_ops_injector=>inject_plugin( iv_class_name = 'ZCL_CA_OPS_CLOCK' io_instance = lo_double ).
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_factory=>get_plugin( 'ZCL_CA_OPS_CLOCK' )
                                            exp = lo_double
                                            msg = 'Injected double must be returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A real, instantiable class is created and castable to its interface
  METHOD real_class_is_created.
    TRY.
        DATA(lo_object) = zcl_ca_ops_factory=>get_plugin( 'ZCL_CA_OPS_CLOCK' ).
        DATA(lo_clock) = CAST zif_ca_ops_clock( lo_object ).
        cl_abap_unit_assert=>assert_bound( act = lo_clock msg = 'Real plug-in must be created' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Customizing may hold the class name in lower case or with blanks
  METHOD class_name_case_insensitive.
    TRY.
        cl_abap_unit_assert=>assert_bound( act = zcl_ca_ops_factory=>get_plugin( ' zcl_ca_ops_clock' )
                                           msg = 'Lower-case class name must resolve' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Service getters return the injected double (seam used by every application test)
  METHOD injected_clock_is_returned.
    DATA(lo_double) = NEW ltd_clock( ).
    zcl_ca_ops_injector=>inject_clock( lo_double ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_factory=>get_clock( ) exp = lo_double
                                        msg = 'Injected clock must be returned' ).
  ENDMETHOD.


  " Every authorisation question goes through one seam, so consumers are testable
  METHOD injected_auth_is_returned.
    DATA(lo_double) = NEW ltd_auth( ).
    zcl_ca_ops_injector=>inject_auth( lo_double ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_factory=>get_auth( ) exp = lo_double
                                        msg = 'Injected authorisation double must be returned' ).
  ENDMETHOD.


  " The check registry is read through one seam: runner, aggregate and onboarding checks are testable
  METHOD injected_check_dao_returned.
    DATA(lo_double) = NEW ltd_check_dao( ).
    zcl_ca_ops_injector=>inject_check_dao( lo_double ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_factory=>get_check_dao( ) exp = lo_double
                                        msg = 'Injected check registry double must be returned' ).
  ENDMETHOD.


  " Without a double the real data access is returned (and the reset removes the double)
  METHOD real_check_dao_created.
    zcl_ca_ops_injector=>inject_check_dao( NEW ltd_check_dao( ) ).
    zcl_ca_ops_injector=>reset( ).
    cl_abap_unit_assert=>assert_true( act = xsdbool( zcl_ca_ops_factory=>get_check_dao( ) IS INSTANCE OF zcl_ca_ops_check_dao )
                                      msg = 'The real check registry data access after the reset' ).
  ENDMETHOD.


  " Audit A62: a configured class that does not implement the required interface is
  " refused BEFORE CREATE OBJECT - its constructor (side effects) must not run
  METHOD unrelated_class_not_created.
    zcl_ca_ops_plugin_probe=>reset( ).
    TRY.
        zcl_ca_ops_factory=>get_plugin( iv_class_name = 'ZCL_CA_OPS_PLUGIN_PROBE'
                                        iv_interface  = zif_ca_ops_types=>gc_plugin_intf-alert_channel ).
        cl_abap_unit_assert=>fail( msg = 'An unrelated class must raise ZCX_CA_OPS_ERROR' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '032'
                                            msg = 'Missing interface must raise message 032' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_plugin_probe=>gv_instances exp = 0
                                        msg = 'The constructor of the unrelated class must not run' ).
  ENDMETHOD.


  " Audit A62: a class implementing the required interface is created as before
  METHOD matching_interface_creates.
    TRY.
        DATA(lo_object) = zcl_ca_ops_factory=>get_plugin( iv_class_name = 'ZCL_CA_OPS_CLOCK'
                                                          iv_interface  = 'ZIF_CA_OPS_CLOCK' ).
        cl_abap_unit_assert=>assert_bound( act = CAST zif_ca_ops_clock( lo_object )
                                           msg = 'A matching plug-in must be created' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A62: a mistyped interface name is a configuration error, not a pass
  METHOD unknown_interface_refused.
    zcl_ca_ops_plugin_probe=>reset( ).
    TRY.
        zcl_ca_ops_factory=>get_plugin( iv_class_name = 'ZCL_CA_OPS_PLUGIN_PROBE'
                                        iv_interface  = 'ZIF_CA_DOES_NOT_EXIST' ).
        cl_abap_unit_assert=>fail( msg = 'An unknown interface must raise ZCX_CA_OPS_ERROR' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '033'
                                            msg = 'Unknown interface must raise message 033' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_plugin_probe=>gv_instances exp = 0
                                        msg = 'Nothing is created for an unknown interface' ).
  ENDMETHOD.


  " Audit A62: an injected double is held to the same interface
  METHOD double_must_match_interface.
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = 'ZCL_CA_OPS_CLOCK' io_instance = NEW ltd_auth( ) ).
    TRY.
        zcl_ca_ops_factory=>get_plugin( iv_class_name = 'ZCL_CA_OPS_CLOCK'
                                        iv_interface  = 'ZIF_CA_OPS_CLOCK' ).
        cl_abap_unit_assert=>fail( msg = 'A double without the interface must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '032'
                                            msg = 'A double without the interface must raise 032' ).
    ENDTRY.
  ENDMETHOD.


  " Version check: a parameter framework older than the release ZCA_OPS needs refuses every run
  METHOD old_param_release_refused.
    zcl_ca_ops_injector=>inject_param_version( `1.0.0` ).
    TRY.
        zcl_ca_ops_factory=>check_version( ).
        cl_abap_unit_assert=>fail( msg = 'An older ZCA_PARAM must be refused' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '044'
                                            msg = 'Message 044 names both releases' ).
    ENDTRY.
  ENDMETHOD.


  " Version check: the installed release (or a later one) passes
  METHOD current_param_release_passes.
    TRY.
        zcl_ca_ops_injector=>inject_param_version( zif_ca_ops_types=>gc_param_min_version ).
        zcl_ca_ops_factory=>check_version( ).
        zcl_ca_ops_injector=>inject_param_version( `9.0.0` ).
        zcl_ca_ops_factory=>check_version( ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
