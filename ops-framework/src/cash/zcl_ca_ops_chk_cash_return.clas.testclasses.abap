*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_cash_return.clas.testclasses.abap
*& Purpose:
*& Fixtures of the returns lot check (config/cash/fixtures.json, RETURN-*)
*& through ZIF_CA_OPS_CHECK=>RUN: a returns lot not closed is an exception
*& with lot key, amount, currency, owner and age; returns in clarification
*& and returns without returns document (reversal pending) are exceptions of
*& their own stage; the done status pending = "not evaluated" while the
*& other rules run; one unreadable rule leaves the others evaluated and the
*& check partial. Doubles: cash data access; parameters in memory. Does not
*& prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
CLASS ltd_return_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cash_dao PARTIALLY IMPLEMENTED.
    DATA mt_open TYPE zif_ca_ops_cash_types=>tt_sum.
    DATA mt_clarif TYPE zif_ca_ops_cash_types=>tt_sum.
    DATA mt_nodoc TYPE zif_ca_ops_cash_types=>tt_sum.
    DATA mv_fail_clarif TYPE abap_bool.
ENDCLASS.

CLASS ltd_return_dao IMPLEMENTATION.
  METHOD zif_ca_ops_cash_dao~open_returns_lots.
    rt_sums = mt_open.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~return_clarifications.
    IF mv_fail_clarif = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e521(zca_ops) WITH 'DFKKRP'.
    ENDIF.
    rt_sums = mt_clarif.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~returns_without_document.
    rt_sums = mt_nodoc.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~owner.
    rs_owner = VALUE #( control_id = 'FICA_RETURNS' owner = 'ZT_OWNER' team = 'ZT_TEAM' ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_cash_return DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area  TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        bukrs TYPE bukrs VALUE 'ZT01',
        today TYPE d VALUE '20261116',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_return_dao.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.
    METHODS lot
      IMPORTING
        iv_id         TYPE clike
        iv_amount     TYPE zif_ca_ops_cash_types=>ty_amount
      RETURNING
        VALUE(rt_sum) TYPE zif_ca_ops_cash_types=>tt_sum.

    METHODS lot_not_closed_exception   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS clarification_and_reversal FOR TESTING RAISING zcx_ca_ops_error.
    METHODS done_status_pending        FOR TESTING RAISING zcx_ca_ops_error.
    METHODS one_rule_unreadable        FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_chk_cash_return IMPLEMENTATION.

  METHOD setup.
    mo_dao  = NEW #( ).
    mo_seed = NEW #( ).
    zcl_ca_ops_cash_injector=>inject_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-ret_done_status iv_value = '9' ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_cash_injector=>reset( ).
  ENDMETHOD.


  METHOD run.
    rs_result = NEW zcl_ca_ops_chk_cash_return( )->zif_ca_ops_check~run(
                  is_check   = VALUE #( area = gc-area check_id = 'FICA_CASH_RETURNS' process_id = 'FICA_RETURNS'
                                        bukrs_aware = abap_true )
                  is_context = VALUE #( area = gc-area today = gc-today ) ).
  ENDMETHOD.


  METHOD lot.
    rt_sum = VALUE #( ( object_id = iv_id company_code = gc-bukrs currency = 'EUR' item_count = 1 amount = iv_amount
                        oldest = '20261111' ) ).
  ENDMETHOD.


  " Fixture RETURN-01: returns lot RET1 of 11 November not closed (40.00 EUR) - exception with key, owner, age 5
  METHOD lot_not_closed_exception.
    mo_dao->mt_open = lot( iv_id = 'RET1' iv_amount = '40.00' ).

    DATA(ls_result) = run( ).
    DATA(ls_finding) = ls_result-findings[ 1 ].

    cl_abap_unit_assert=>assert_equals( act = ls_finding-check_code exp = zif_ca_ops_cash_types=>gc_code-retlot_open ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = 'RET1/ZT01/EUR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = '40.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-business_date exp = '20261111' ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS 'KEYR1' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS 'ZT_OWNER' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-message CS 'RET1' ) ).
  ENDMETHOD.


  " Fixture RETURN-02: a return in clarification and a return without returns document - one stage each
  METHOD clarification_and_reversal.
    mo_dao->mt_clarif = lot( iv_id = 'RET2' iv_amount = '60.00' ).
    mo_dao->mt_nodoc  = lot( iv_id = 'RET3' iv_amount = '15.00' ).

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-return_clarif
                                                                ]-rule_id
                                        exp = zif_ca_ops_cash_types=>gc_stage-clarify ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-return_no_doc
                                                                ]-amount
                                        exp = '15.00' ).
    cl_abap_unit_assert=>assert_false( ls_result-partial ).
  ENDMETHOD.


  " Fixture RETURN-03: the done status is pending - that rule not evaluated, the others evaluated, partial
  METHOD done_status_pending.
    mo_seed->remove( zif_ca_ops_cash_types=>gc_param-ret_done_status ).
    mo_dao->mt_open  = lot( iv_id = 'RET1' iv_amount = '40.00' ).
    mo_dao->mt_nodoc = lot( iv_id = 'RET3' iv_amount = '15.00' ).

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_false( xsdbool( line_exists(
      ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-retlot_open ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists(
      ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-not_evaluated ] ) ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists(
      ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-return_no_doc ] ) ) ).
    cl_abap_unit_assert=>assert_true( ls_result-partial ).
  ENDMETHOD.


  " Fixture RETURN-04: the clarification read fails - not evaluated for that stage only, partial
  METHOD one_rule_unreadable.
    mo_dao->mv_fail_clarif = abap_true.
    mo_dao->mt_open = lot( iv_id = 'RET1' iv_amount = '40.00' ).

    DATA(ls_result) = run( ).

    DATA(ls_failed) = ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-not_evaluated ].
    cl_abap_unit_assert=>assert_equals( act = ls_failed-rule_id exp = zif_ca_ops_cash_types=>gc_stage-clarify ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists(
      ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-retlot_open ] ) ) ).
    cl_abap_unit_assert=>assert_true( ls_result-partial ).
  ENDMETHOD.

ENDCLASS.
