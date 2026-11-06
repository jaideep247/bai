*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_op.clas.testclasses.abap
*& Purpose:
*& Unit test of the bgPF operation: execute( ) hands the event ID it was
*& created with to ZCL_CD_FMON_PRISM_PROC, which reads it through the
*& injected PRISM DAO double (ZCL_CD_FMON_INJECTOR); an unknown event ends
*& there. Does not prove live SAP runtime behavior (bgPF itself: PRISM-12).
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltd_prism_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_prism_dao PARTIALLY IMPLEMENTED.
    DATA mt_read TYPE STANDARD TABLE OF zif_cd_fmon_prism_types=>ty_event_id WITH EMPTY KEY.
ENDCLASS.

CLASS ltd_prism_dao IMPLEMENTATION.
  METHOD zif_cd_fmon_prism_dao~read_event.
    " unknown event: initial row, the unit ends without further reads
    INSERT iv_event_id INTO TABLE mt_read.
    CLEAR rs_row.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_prism_op DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_event_id TYPE zif_cd_fmon_prism_types=>ty_event_id VALUE 'EVT-0001'.

    DATA mo_dao TYPE REF TO ltd_prism_dao.

    METHODS setup.
    METHODS teardown.
    METHODS executes_its_event FOR TESTING.
ENDCLASS.


CLASS ltc_prism_op IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_cd_fmon_injector=>inject_prism_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_fmon_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  " Rule: the operation processes exactly the event it was created for (only the ID is serialized)
  METHOD executes_its_event.
    DATA lt_exp LIKE mo_dao->mt_read.
    TRY.
        INSERT gc_event_id INTO TABLE lt_exp.
        NEW zcl_cd_fmon_prism_op( gc_event_id )->if_bgmc_op_single_tx_uncontr~execute( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_read exp = lt_exp
                                            msg = 'The carried event ID is processed once' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
