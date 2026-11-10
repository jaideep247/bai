*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_param_seed.clas.testclasses.abap
*& Purpose:
*& Unit tests of the delivered parameter definitions with the REAL framework
*& logic (ZCL_CA_PARAM over the in-memory DAO): every delivered definition is
*& readable without a value row (default valid for value type, limits,
*& pattern, class and interface), every name maps to its delivered area, and
*& the in-memory store maintains, removes and logs. Does not prove live SAP
*& runtime behavior (the definitions in DV1 are checked by PARAM_INVALID).
*& Modification log:
*& 2026-11-07 | Initial version (parameters moved to ZCA_PARAM).
*& 2026-11-07 | errors_are_listed: the adapter lists errors, no log channel (SLG1 minimum).
*&---------------------------------------------------------------------*
CLASS ltc_param_seed DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        name    TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_TOP_N',
        value   TYPE string VALUE `7`,
        unknown TYPE zif_ca_ops_types=>ty_param_name VALUE 'HCK_NOT_DELIVERED',
      END OF gc_test.

    DATA mo_cut TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS every_default_is_readable FOR TESTING.
    METHODS area_by_prefix_of_name FOR TESTING.
    METHODS set_and_remove_value FOR TESTING.
    METHODS errors_are_listed FOR TESTING.
ENDCLASS.


CLASS ltc_param_seed IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
  ENDMETHOD.


  " Rule: every delivered definition can be read with no value row - its default is valid
  " for the definition (value type, min / max, allowed pattern, class and interface)
  METHOD every_default_is_readable.
    DATA lo_param TYPE REF TO zif_ca_param.
    lo_param = NEW zcl_ca_param( io_dao = mo_cut->dao( ) ).
    LOOP AT zcl_cd_ops_param_seed=>definitions( ) ASSIGNING FIELD-SYMBOL(<ls_definition>).
      TRY.
          lo_param->get_value( iv_area = <ls_definition>-area
                               iv_name = <ls_definition>-name ).
        CATCH zcx_ca_param INTO DATA(lx_error).
          cl_abap_unit_assert=>fail( msg = |{ <ls_definition>-name }: { lx_error->get_text( ) }| ).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  " Rule: the adapter finds every delivered definition in its area (prefix table)
  METHOD area_by_prefix_of_name.
    LOOP AT zcl_cd_ops_param_seed=>definitions( ) ASSIGNING FIELD-SYMBOL(<ls_definition>).
      cl_abap_unit_assert=>assert_equals( act = NEW zcl_cd_ops_param_seed( )->params( )->area_of( <ls_definition>-name )
                                          exp = <ls_definition>-area
                                          msg = |{ <ls_definition>-name } is read from its area| ).
    ENDLOOP.
  ENDMETHOD.


  " Rule: set( ) maintains one value row, visible at once; remove( ) brings the default back
  METHOD set_and_remove_value.
    DATA(lo_params) = mo_cut->params( ).
    DATA(lv_default) = lo_params->get_param( gc_test-name ).
    mo_cut->set( iv_name = gc_test-name iv_value = gc_test-value ).
    cl_abap_unit_assert=>assert_equals( act = lo_params->get_param( gc_test-name ) exp = gc_test-value
                                        msg = 'The maintained value is read at once' ).
    mo_cut->remove( gc_test-name ).
    cl_abap_unit_assert=>assert_equals( act = lo_params->get_param( gc_test-name ) exp = lv_default
                                        msg = 'Without the row the definition default applies' ).
  ENDMETHOD.


  " Rule: an undefined name is listed once by the adapter (no application log)
  METHOD errors_are_listed.
    DATA(lo_params) = mo_cut->params( ).
    lo_params->get_param( gc_test-unknown ).
    lo_params->get_param( gc_test-unknown ).
    cl_abap_unit_assert=>assert_equals( act = lines( lo_params->get_errors( ) ) exp = 1
                                        msg = 'An undefined name is listed once' ).
  ENDMETHOD.

ENDCLASS.
