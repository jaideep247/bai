*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_ev_gl_zuonr.clas.testclasses.abap
*& Purpose:
*& Unit tests of the evidence "assignment state of the G/L line": EQUAL
*& (ACH: ZUONR still AUGBL holds, changed = anomaly "assignment changed"),
*& CHANGED (Stripe: descriptor set holds, still AUGBL does not), invalid
*& expectation raises, one read. Runtime DAO is a double; does not prove
*& live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (user facts on collections clearing).
*&---------------------------------------------------------------------*
CLASS ltd_runtime_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_runtime_dao PARTIALLY IMPLEMENTED.
    DATA mt_lines TYPE zif_cd_hck_runtime_types=>tt_gl_xref2_line.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_runtime_dao IMPLEMENTATION.
  METHOD zif_cd_hck_runtime_dao~get_gl_lines_by_xref2.
    mv_calls = mv_calls + 1.
    rt_lines = mt_lines.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ev_gl_zuonr DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_bukrs     TYPE c LENGTH 4 VALUE 'US01',
      "! ZUONR still = AUGBL
      gc_same      TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      "! ZUONR = Stripe statement descriptor
      gc_changed   TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300002'.
    DATA mo_dao TYPE REF TO ltd_runtime_dao.

    METHODS setup.
    METHODS teardown.
    METHODS collect
      IMPORTING
        iv_expect        TYPE clike
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_runtime_types=>ty_evidence_result
      RAISING
        zcx_ca_ops_error.
    METHODS equal_holds_changed_anomaly FOR TESTING.
    METHODS changed_holds_for_stripe   FOR TESTING.
    METHODS invalid_expectation_raises FOR TESTING.
ENDCLASS.


CLASS ltc_ev_gl_zuonr IMPLEMENTATION.

  METHOD setup.
    DATA ls_line TYPE zif_cd_hck_runtime_types=>ty_gl_xref2_line.
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_runtime_dao( mo_dao ).
    ls_line-bukrs = gc_bukrs.
    ls_line-xref2 = gc_same.
    ls_line-zuonr = '300001'.
    INSERT ls_line INTO TABLE mo_dao->mt_lines.
    ls_line-xref2 = gc_changed.
    ls_line-zuonr = 'STRIPE PAYOUT 1107'.
    INSERT ls_line INTO TABLE mo_dao->mt_lines.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD collect.
    DATA lt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    INSERT VALUE #( doc1r = gc_same bukrs = gc_bukrs laufd = '20261106' ) INTO TABLE lt_payments.
    INSERT VALUE #( doc1r = gc_changed bukrs = gc_bukrs laufd = '20261106' ) INTO TABLE lt_payments.
    rs_result = NEW zcl_cd_hck_ev_gl_zuonr( )->zif_cd_hck_evidence~collect(
                  it_payments = lt_payments
                  is_rule     = VALUE #( evidence_class = 'ZCL_CD_HCK_EV_GL_ZUONR' param1 = iv_expect )
                  iv_max_rows = 100 ).
  ENDMETHOD.


  " Rule: ACH collections - ZUONR = AUGBL holds; a changed assignment is an anomaly; one read
  METHOD equal_holds_changed_anomaly.
    TRY.
        DATA(ls_result) = collect( zif_cd_hck_runtime_types=>gc_zuonr_expect-equal ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_same ]-found msg = 'Still AUGBL' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-evidence[ doc1r = gc_changed ]-anomaly
                                            exp = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist
                                            msg = 'Assignment changed' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_calls exp = 1 msg = 'One read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: Stripe - the descriptor set by payout processing holds; still AUGBL does not, no anomaly
  METHOD changed_holds_for_stripe.
    TRY.
        DATA(ls_result) = collect( zif_cd_hck_runtime_types=>gc_zuonr_expect-changed ).
        cl_abap_unit_assert=>assert_true( act = ls_result-evidence[ doc1r = gc_changed ]-found msg = 'Descriptor set' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-evidence[ doc1r = gc_same ]-found msg = 'Still AUGBL' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-evidence[ doc1r = gc_same ]-anomaly msg = 'No anomaly' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an expectation other than EQUAL / CHANGED is a configuration error
  METHOD invalid_expectation_raises.
    TRY.
        collect( 'SOMETIMES' ).
        cl_abap_unit_assert=>fail( msg = 'Invalid expectation must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Raised' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
