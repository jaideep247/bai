*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_evidence.clas.testclasses.abap
*& Purpose:
*& Tests of the evidence store on a doubled ZCA_OPS_FNDEVI / ZCA_OPS_FINDING
*& (ABAP SQL test environment): SAVE replaces the rows of an evidence key
*& (a finding raised again shows its latest evidence only) and numbers
*& rows without a sequence; READ returns them in order; WALKER_REQUEST
*& turns a row into a start of the link walker and refuses a row without
*& link object or key values (377). Does not prove live SAP runtime
*& behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build K: exception contract).
*&---------------------------------------------------------------------*
CLASS ltc_evidence DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_evidence.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS save_replaces_key   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS walker_start        FOR TESTING RAISING zcx_ca_ops_error.
    METHODS walker_needs_object FOR TESTING.
ENDCLASS.


CLASS ltc_evidence IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCA_OPS_FNDEVI' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_evidence( ).
  ENDMETHOD.


  METHOD save_replaces_key.
    mo_cut->save( iv_area = 'ZT' iv_run_id = VALUE #( )
                  it_evidence = VALUE #( ( evid_key = 'K1' label = 'old 1' ) ( evid_key = 'K1' label = 'old 2' ) ) ).
    mo_cut->save( iv_area = 'ZT' iv_run_id = VALUE #( )
                  it_evidence = VALUE #( ( evid_key = 'K1' label = 'new' ) ) ).
    DATA(lt_rows) = mo_cut->read( iv_area = 'ZT' iv_evid_key = 'K1' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'Replaced, never mixed' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-label exp = 'new' msg = 'Latest evidence' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-seq exp = 1 msg = 'Numbered' ).
  ENDMETHOD.


  METHOD walker_start.
    DATA(ls_request) = mo_cut->walker_request( iv_area     = 'ZT'
                                               is_evidence = VALUE #( link_object = 'FICA_PAYMENT_RUN'
                                                                      link_value  = 'LAUFD=20261116;LAUFI=ZT1' ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_request-object_id exp = 'FICA_PAYMENT_RUN' msg = 'Start object' ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_request-keys ) exp = 2 msg = 'Its key values' ).
  ENDMETHOD.


  METHOD walker_needs_object.
    TRY.
        mo_cut->walker_request( iv_area = 'ZT' is_evidence = VALUE #( evid_key = 'K1' seq = 1 ) ).
        cl_abap_unit_assert=>fail( msg = 'Refused expected' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '377' msg = '377' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
