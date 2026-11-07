*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_factory.clas.testclasses.abap
*& Purpose:
*& Unit tests of ZCL_CA_PARAM_FACTORY and ZCL_CA_PARAM_INJECTOR: one
*& instance per session, injected double, injected DAO with the real
*& logic, reset. teardown resets the injector. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
CLASS ltc_factory DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_area TYPE zif_ca_param_types=>ty_area VALUE 'ZTEST'.
    CONSTANTS gc_name TYPE zif_ca_param_types=>ty_name VALUE 'P1'.

    METHODS teardown.

    METHODS get_returns_one_instance FOR TESTING.
    METHODS inject_returns_double FOR TESTING.
    METHODS inject_dao_keeps_logic FOR TESTING.
    METHODS reset_restores_production FOR TESTING.
ENDCLASS.


CLASS ltc_factory IMPLEMENTATION.

  METHOD teardown.
    zcl_ca_param_injector=>reset( ).
  ENDMETHOD.


  METHOD get_returns_one_instance.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_param_factory=>get( )
                                            exp = zcl_ca_param_factory=>get( )
                                            msg = `One reader (and one buffer) per session` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD inject_returns_double.
    TRY.
        DATA(lo_double) = NEW zcl_ca_param_builder( )->area( gc_area )->build( ).
        zcl_ca_param_injector=>inject( lo_double ).
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_param_factory=>get( )
                                            exp = lo_double
                                            msg = `The injected reader is returned` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD inject_dao_keeps_logic.
    TRY.
        DATA(lo_dao) = NEW zcl_ca_param_builder( )->area( gc_area
                                                 )->param( iv_name       = gc_name
                                                           iv_value_type = zif_ca_param_types=>gc_value_type-bool
                                                           iv_default    = zif_ca_param_types=>gc_true
                                                 )->row( space )->dao( ).
        zcl_ca_param_injector=>inject_dao( lo_dao ).
        cl_abap_unit_assert=>assert_false( act = zcl_ca_param_factory=>get( )->get_bool( iv_area = gc_area
                                                                                         iv_name = gc_name )
                                           msg = `The real logic runs over the injected DAO (blank row = off)` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD reset_restores_production.
    TRY.
        DATA(lo_double) = NEW zcl_ca_param_builder( )->area( gc_area )->build( ).
        zcl_ca_param_injector=>inject( lo_double ).
        zcl_ca_param_injector=>reset( ).
        DATA(lo_param) = zcl_ca_param_factory=>get( ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( lo_param <> lo_double AND lo_param IS INSTANCE OF zcl_ca_param )
                                          msg = `After reset the production reader is returned` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
