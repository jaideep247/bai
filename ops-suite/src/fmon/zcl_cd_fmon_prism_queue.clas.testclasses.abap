*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_queue.clas.testclasses.abap
*& Purpose:
*& Unit test of the bgPF queue through test seam BGPF: a process saved for
*& execution returns without exception. The bgPF error branch (CX_BGMC ->
*& message 268) is not injected here because CX_BGMC is VERIFY-ADT on
*& SAP_BASIS 7.58 SP01 (QA case PRISM-12); does not prove live SAP runtime
*& behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltc_prism_queue DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_event_id TYPE zif_cd_fmon_prism_types=>ty_event_id VALUE 'EVT-0001'.

    DATA mo_cut TYPE REF TO zif_cd_fmon_prism_queue.

    METHODS setup.
    METHODS teardown.
    METHODS saved_process_returns FOR TESTING.
ENDCLASS.


CLASS ltc_prism_queue IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_cd_fmon_prism_queue( ).
  ENDMETHOD.


  METHOD teardown.
    CLEAR mo_cut.
  ENDMETHOD.


  " Rule: a process the framework saved for execution is no error for the API caller
  METHOD saved_process_returns.
    TRY.
        TEST-INJECTION bgpf.
        END-TEST-INJECTION.
        mo_cut->enqueue( gc_event_id ).
        cl_abap_unit_assert=>assert_bound( act = mo_cut msg = 'Enqueued without exception' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
