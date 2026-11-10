*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_coll_c_refund.clas.testclasses.abap
*& Purpose:
*& Tests of check COLL_R3_REFUND through ZIF_CA_OPS_CHECK~RUN with a data access
*& double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (scaffold tools/abaptools/new_process.py).
*&---------------------------------------------------------------------*
CLASS ltc_check DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS nothing_found_no_finding FOR TESTING.
ENDCLASS.


CLASS ltc_check IMPLEMENTATION.

  " Rule: without objects that break the rule the check raises nothing (the runner resolves)
  METHOD nothing_found_no_finding.
    TRY.
        DATA(ls_result) = NEW zcl_cd_coll_c_refund( )->zif_ca_ops_check~run( is_check   = VALUE #( )
                                                                   is_context = VALUE #( ) ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'No finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
