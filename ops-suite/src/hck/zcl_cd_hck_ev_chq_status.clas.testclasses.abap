*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_chq_status.clas.testclasses.abap
*& Purpose:
*& Unit tests of the evidence "cheque status" (DFKKCR-STATE): B holds for
*& PARAM1 B, V for PARAM1 V, blank (open) never holds, no cheque = no row,
*& one read for all payments, PARAM1 required. Payment trace repository
*& is a double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (user rule 2: B cashed, V voided, blank open).
*& 2026-11-07 | Token BLANK.
*& 2026-11-07 | Code review: a voided cheque and its reissue - the live cheque decides; one shared read
*&            | per collection (start_collection before each collect).
*& 2026-11-08 | PARAM2 payment status STOPPED holds alone (user decision: a stopped cheque is voided).
*&---------------------------------------------------------------------*
CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_checks TYPE zif_cd_ops_trace_types=>tt_check.
    DATA mt_runs TYPE zif_cd_ops_trace_types=>tt_payment_run.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~get_checks_by_doc.
    mv_calls = mv_calls + 1.
    rt_checks = mt_checks.
  ENDMETHOD.
  METHOD zif_cd_ops_trace_dao~get_payment_runs.
    rt_runs = mt_runs.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ev_chq_status DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_cashed TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      gc_voided TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300002',
      gc_open   TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300003',
      gc_none   TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300004',
      "! DPAYH-ZZ_PAYMENT_STATUS values (confirmed 2026-11-08)
      gc_stopped TYPE c LENGTH 20 VALUE 'STOPPED',
      gc_issued  TYPE c LENGTH 20 VALUE 'ISSUED'.
    DATA mo_trace TYPE REF TO ltd_trace_dao.

    METHODS setup.
    METHODS teardown.
    METHODS collect
      IMPORTING
        iv_param1        TYPE clike
        iv_param2        TYPE clike OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_runtime_types=>ty_evidence_result
      RAISING
        zcx_cd_ops_error.
    METHODS cashed_holds_for_b     FOR TESTING.
    METHODS voided_holds_for_v     FOR TESTING.
    METHODS blank_never_holds      FOR TESTING.
    METHODS blank_param1_raises    FOR TESTING.
    METHODS reissue_voided_not_decisive FOR TESTING.
    METHODS stopped_status_holds_alone FOR TESTING.
    METHODS status_list_blank_no_read  FOR TESTING.
ENDCLASS.


CLASS ltc_ev_chq_status IMPLEMENTATION.

  METHOD setup.
    DATA ls_check TYPE zif_cd_ops_trace_types=>ty_check.
    mo_trace = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    ls_check-doc1r = gc_cashed.
    ls_check-state = 'B'.
    INSERT ls_check INTO TABLE mo_trace->mt_checks.
    ls_check-doc1r = gc_voided.
    ls_check-state = 'V'.
    INSERT ls_check INTO TABLE mo_trace->mt_checks.
    ls_check-doc1r = gc_open.
    CLEAR ls_check-state.
    INSERT ls_check INTO TABLE mo_trace->mt_checks.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_trace.
  ENDMETHOD.


  METHOD collect.
    DATA lt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    zcl_cd_hck_ev_support=>start_collection( ).
    INSERT VALUE #( doc1r = gc_cashed ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_voided ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_open ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_none ) INTO TABLE lt_payments.
    rs_result = NEW zcl_cd_hck_ev_chq_status( )->zif_cd_hck_evidence~collect(
                  it_payments = lt_payments
                  is_rule     = VALUE #( evidence_class = 'ZCL_CD_HCK_EV_CHQ_STATUS' param1 = iv_param1 param2 = iv_param2 )
                  iv_max_rows = 100 ).
  ENDMETHOD.


  " Rule: state B (cashed) holds for PARAM1 B; one read for all payments
  METHOD cashed_holds_for_b.
    TRY.
        DATA(ls_result) = collect( 'B' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_cashed ]-found msg = 'B holds' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_voided ]-found msg = 'V does not' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-evidence[ doc1r = gc_none ] ) )
                                           msg = 'No cheque: no row' ).
        cl_abap_unit_assert=>assert_equals( act = mo_trace->mv_calls exp = 1 msg = 'One read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: state V (voided) holds for PARAM1 V
  METHOD voided_holds_for_v.
    TRY.
        DATA(ls_result) = collect( 'v' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_voided ]-found msg = 'V holds' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_cashed ]-found msg = 'B does not' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: blank state (open) holds only for the token BLANK
  METHOD blank_never_holds.
    TRY.
        DATA(ls_result) = collect( 'B,V' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_open ]-found msg = 'Open does not hold' ).
        ls_result = collect( |V,{ zif_cd_hck_runtime_types=>gc_state_blank }| ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_open ]-found msg = 'Token BLANK holds for blank' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Code review 2: the voided cheque of a payment that was reissued (newer cheque, state B) does not
  " make the payment voided - the live cheque decides
  METHOD reissue_voided_not_decisive.
    DATA ls_check TYPE zif_cd_ops_trace_types=>ty_check.
    TRY.
        ls_check-doc1r = gc_voided.
        ls_check-ztnum = '0000000002'.
        ls_check-state = 'B'.
        INSERT ls_check INTO TABLE mo_trace->mt_checks.
        DATA(ls_result) = collect( 'V' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_voided ]-found
                                           msg = 'Voided cheque not decisive' ).
        ls_result = collect( 'B' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_voided ]-found
                                          msg = 'The reissue decides' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " User decision 2026-11-08: a cheque whose payment status is STOPPED (PARAM2) is voided whatever its
  " register state - state V or status STOPPED, either one is enough; no register row needed
  METHOD stopped_status_holds_alone.
    TRY.
        INSERT VALUE #( doc1r = gc_open status = gc_stopped ) INTO TABLE mo_trace->mt_runs.
        INSERT VALUE #( doc1r = gc_none status = gc_stopped ) INTO TABLE mo_trace->mt_runs.
        INSERT VALUE #( doc1r = gc_voided status = gc_issued ) INTO TABLE mo_trace->mt_runs.
        INSERT VALUE #( doc1r = gc_cashed status = gc_issued ) INTO TABLE mo_trace->mt_runs.
        DATA(ls_result) = collect( iv_param1 = 'V' iv_param2 = gc_stopped ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_open ]-found
                                          msg = 'STOPPED with a blank register state holds' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_none ]-found
                                          msg = 'STOPPED holds without a register row' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_voided ]-found
                                          msg = 'V without STOPPED still holds' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_cashed ]-found
                                           msg = 'Cashed and ISSUED does not hold' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( find( val = ls_result-evidence[ doc1r = gc_open ]-detail
                                                               sub = condense( gc_stopped ) ) >= 0 )
                                          msg = 'The status is shown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Without PARAM2 the payment status plays no part (a STOPPED payment with state blank does not hold V)
  METHOD status_list_blank_no_read.
    TRY.
        INSERT VALUE #( doc1r = gc_open status = gc_stopped ) INTO TABLE mo_trace->mt_runs.
        DATA(ls_result) = collect( 'V' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_open ]-found
                                           msg = 'No PARAM2: the status is not evidence' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PARAM1 (status values) is required
  METHOD blank_param1_raises.
    TRY.
        collect( space ).
        cl_abap_unit_assert=>fail( msg = 'Blank PARAM1 must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Raised' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
