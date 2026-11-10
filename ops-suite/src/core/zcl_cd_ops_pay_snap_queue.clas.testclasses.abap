*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_snap_queue.clas.testclasses.abap
*& Purpose:
*& Unit test of the bgPF queue of the snapshot packages through the test
*& seams BGPF and PAUSE: a process saved for execution returns without
*& exception, a pause returns. The bgPF error branch (CX_BGMC -> message
*& 764) is not injected because CX_BGMC is VERIFY-ADT on SAP_BASIS 7.58 SP01
*& (QA case POC-14); does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-08 | Initial version (parallel snapshot packages).
*&---------------------------------------------------------------------*
CLASS ltc_snap_queue DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_doc TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000900001'.
    CONSTANTS gc_seconds TYPE i VALUE 5.

    DATA mo_cut TYPE REF TO zif_cd_ops_pay_snap_queue.

    METHODS setup.
    METHODS teardown.
    METHODS saved_process_returns FOR TESTING.
    METHODS pause_returns         FOR TESTING.
ENDCLASS.


CLASS ltc_snap_queue IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_cd_ops_pay_snap_queue( ).
  ENDMETHOD.


  METHOD teardown.
    CLEAR mo_cut.
  ENDMETHOD.


  " Rule: a package the framework saved for execution is no error for the run
  METHOD saved_process_returns.
    DATA ls_package TYPE zif_cd_ops_payout_types=>ty_package.
    TRY.
        ls_package-source = zif_cd_ops_payout_types=>gc_source-documents.
        ls_package-pkg_no = 1.
        INSERT gc_doc INTO TABLE ls_package-docno.
        TEST-INJECTION bgpf.
        END-TEST-INJECTION.
        mo_cut->dispatch( ls_package ).
        cl_abap_unit_assert=>assert_bound( act = mo_cut msg = 'Dispatched without exception' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a pause between two looks at the packages returns to the run
  METHOD pause_returns.
    TRY.
        TEST-INJECTION pause.
        END-TEST-INJECTION.
        mo_cut->pause( gc_seconds ).
        cl_abap_unit_assert=>assert_bound( act = mo_cut msg = 'Paused without exception' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
