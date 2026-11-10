*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_pay_status.clas.testclasses.abap
*& Purpose:
*& Unit tests of the evidence "payment status": listed status found,
*& other status shown but not found, newest run row decides, no row,
*& PARAM1 required, one read for all payments. Payment trace repository
*& is a double; does not prove live SAP runtime behavior.
*& Pending statuses (PARAM2): not found, not missing; one status read per
*& collection shared by every status row.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 1).
*& 2026-11-08 | Confirmed status values (SENT replaced by CONFIRMED); PARAM2 pending, shared status read.
*&---------------------------------------------------------------------*
CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_runs TYPE zif_cd_ops_trace_types=>tt_payment_run.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~get_payment_runs.
    mv_calls = mv_calls + 1.
    rt_runs = mt_runs.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ev_pay_status DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_doc1 TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      gc_doc2 TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300002',
      gc_doc3 TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300003'.
    DATA mo_trace TYPE REF TO ltd_trace_dao.

    METHODS setup.
    METHODS teardown.
    METHODS collect
      IMPORTING
        iv_param1        TYPE clike DEFAULT 'CLEARED'
        iv_param2        TYPE clike OPTIONAL
        iv_new_run       TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_runtime_types=>ty_evidence_result
      RAISING
        zcx_ca_ops_error.
    METHODS listed_status_found   FOR TESTING.
    METHODS other_status_shown    FOR TESTING.
    METHODS newest_run_decides    FOR TESTING.
    METHODS blank_param1_raises   FOR TESTING.
    METHODS pending_not_missing   FOR TESTING.
    METHODS status_read_once      FOR TESTING.
ENDCLASS.


CLASS ltc_ev_pay_status IMPLEMENTATION.

  METHOD setup.
    mo_trace = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    " Shared EBS read order: per document newest run first
    INSERT VALUE #( doc1r = gc_doc1 laufd = '20261106' status = 'cleared' ) INTO TABLE mo_trace->mt_runs.
    INSERT VALUE #( doc1r = gc_doc2 laufd = '20261106' status = 'CONFIRMED' ) INTO TABLE mo_trace->mt_runs.
    INSERT VALUE #( doc1r = gc_doc2 laufd = '20261001' status = 'CLEARED' ) INTO TABLE mo_trace->mt_runs.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_trace.
  ENDMETHOD.


  METHOD collect.
    DATA lt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    " One collection per check run: the status read is shared within it
    IF iv_new_run = abap_true.
      zcl_cd_hck_ev_support=>start_collection( ).
    ENDIF.
    INSERT VALUE #( doc1r = gc_doc1 ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_doc2 ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_doc3 ) INTO TABLE lt_payments.
    rs_result = NEW zcl_cd_hck_ev_pay_status( )->zif_cd_hck_evidence~collect(
                  it_payments = lt_payments
                  is_rule     = VALUE #( evidence_class = 'ZCL_CD_HCK_EV_PAY_STATUS' param1 = iv_param1 param2 = iv_param2 )
                  iv_max_rows = 100 ).
  ENDMETHOD.


  " Rule: DPAYH-ZZ_PAYMENT_STATUS in PARAM1 (case ignored) holds; one read for all
  METHOD listed_status_found.
    TRY.
        DATA(ls_result) = collect( ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_doc1 ]-found msg = 'CLEARED holds' ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_calls exp = 1 msg = 'One read' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-evidence[ doc1r = gc_doc3 ] ) )
                                           msg = 'No run row: no evidence' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: another status is shown in the detail but does not hold
  METHOD other_status_shown.
    TRY.
        DATA(ls_result) = collect( ).
        DATA(ls_evidence) = ls_result-evidence[ doc1r = gc_doc2 ].
        cl_abap_unit_assert=>assert_false( act = ls_evidence-found msg = 'CONFIRMED does not hold' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = ls_evidence-detail sub = `CONFIRMED` ) >= 0 )
                                          msg = 'Status shown' ).
        cl_abap_unit_assert=>assert_false( act = ls_evidence-pending msg = 'Without PARAM2 nothing is pending' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only the newest run row of a document decides (an older CLEARED row does not)
  METHOD newest_run_decides.
    TRY.
        DATA(ls_result) = collect( ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_doc2 ]-found msg = 'Newest row decides' ).
        ls_result = collect( iv_param1 = 'CONFIRMED,CLEARED' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_doc2 ]-found msg = 'List of values' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Confirmed status values 2026-11-08: a status the hourly status job has not updated yet (PARAM2,
  " e.g. ISSUED / CONFIRMED) is not found but pending - expected to follow, never missing
  METHOD pending_not_missing.
    TRY.
        DATA(ls_result) = collect( iv_param1 = 'RETURNED' iv_param2 = 'ISSUED,CONFIRMED' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_doc2 ]-found msg = 'CONFIRMED is not RETURNED' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_doc2 ]-pending
                                          msg = 'CONFIRMED waits for the status job' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_doc1 ]-pending
                                           msg = 'CLEARED is final, not pending' ).
        ls_result = collect( iv_param1 = 'CONFIRMED' iv_param2 = 'ISSUED,CONFIRMED' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_doc2 ]-found msg = 'A listed status holds' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_doc2 ]-pending
                                           msg = 'Found is never pending' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Two status rows of one run (CLEARED and RETURNED rows) read DPAYH once (status_of memo)
  METHOD status_read_once.
    TRY.
        collect( ).
        DATA(ls_result) = collect( iv_param1 = 'RETURNED' iv_new_run = abap_false ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_calls exp = 1 msg = 'One DPAYH read per collection' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_doc1 ]-found msg = 'CLEARED is not RETURNED' ).
        collect( ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_calls exp = 2 msg = 'A new run reads again' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PARAM1 (status values) is required
  METHOD blank_param1_raises.
    TRY.
        collect( iv_param1 = space ).
        cl_abap_unit_assert=>fail( msg = 'Blank PARAM1 must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Raised' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
