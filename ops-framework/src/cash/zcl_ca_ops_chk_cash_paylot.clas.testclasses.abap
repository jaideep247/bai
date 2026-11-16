*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_cash_paylot.clas.testclasses.abap
*& Purpose:
*& Fixtures of the payment lot check (config/cash/fixtures.json, PAYLOT-*)
*& through ZIF_CA_OPS_CHECK=>RUN: a lot not posted after CASH_LOT_DAYS is
*& an exception with lot key, amount, currency, owner and age; lot items in
*& clarification after CASH_LOT_CLARIF_DAYS too; the done status pending =
*& "not evaluated" (the check partial) while the clarification rule still
*& runs; nothing open = no finding, not partial (a valid observed result);
*& an unreadable lot table is "not evaluated". Doubles: cash data access;
*& parameters in memory. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
CLASS ltd_paylot_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cash_dao PARTIALLY IMPLEMENTED.
    DATA mt_open TYPE zif_ca_ops_cash_types=>tt_sum.
    DATA mt_clarif TYPE zif_ca_ops_cash_types=>tt_sum.
    DATA mv_created_to TYPE d.
    DATA mv_posted_to TYPE d.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.

CLASS ltd_paylot_dao IMPLEMENTATION.
  METHOD zif_ca_ops_cash_dao~open_lots.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e521(zca_ops) WITH 'DFKKZK'.
    ENDIF.
    mv_created_to = iv_created_to.
    rt_sums = mt_open.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~lot_clarifications.
    mv_posted_to = iv_posted_to.
    rt_sums = mt_clarif.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~owner.
    rs_owner = VALUE #( control_id = 'FICA_PAY_LOTS' owner = 'ZT_OWNER' team = 'ZT_TEAM' ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_cash_paylot DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area  TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        bukrs TYPE bukrs VALUE 'ZT01',
        today TYPE d VALUE '20261116',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_paylot_dao.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.

    METHODS lot_not_posted_exception   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS clarification_aged         FOR TESTING RAISING zcx_ca_ops_error.
    METHODS done_status_pending        FOR TESTING RAISING zcx_ca_ops_error.
    METHODS nothing_open_is_observed   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS unreadable_not_evaluated   FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_chk_cash_paylot IMPLEMENTATION.

  METHOD setup.
    mo_dao  = NEW #( ).
    mo_seed = NEW #( ).
    zcl_ca_ops_cash_injector=>inject_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-lot_done_status iv_value = '9' ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_cash_injector=>reset( ).
  ENDMETHOD.


  METHOD run.
    rs_result = NEW zcl_ca_ops_chk_cash_paylot( )->zif_ca_ops_check~run(
                  is_check   = VALUE #( area = gc-area check_id = 'FICA_CASH_PAYLOT' process_id = 'FICA_PAY_LOTS'
                                        bukrs_aware = abap_true )
                  is_context = VALUE #( area = gc-area today = gc-today ) ).
  ENDMETHOD.


  " Fixture PAYLOT-01: lot LOT1 of 10 November not posted (2 items, 25.00 EUR) - exception with key, owner, age 6
  METHOD lot_not_posted_exception.
    mo_dao->mt_open = VALUE #( ( object_id = 'LOT1' company_code = gc-bukrs currency = 'EUR' item_count = 2
                                 amount = '25.00' oldest = '20261110' ) ).

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 ).
    DATA(ls_finding) = ls_result-findings[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_finding-check_code exp = zif_ca_ops_cash_types=>gc_code-lot_not_posted ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = 'LOT1/ZT01/EUR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = '25.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-item_count exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-business_date exp = '20261110' ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-message CS 'LOT1' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS 'KEYZ1' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS 'ZT_OWNER' ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_created_to exp = '20261115' ).
    cl_abap_unit_assert=>assert_false( ls_result-partial ).
  ENDMETHOD.


  " Fixture PAYLOT-02: 3 items of LOT2 in clarification since 11 November (CASH_LOT_CLARIF_DAYS 3)
  METHOD clarification_aged.
    mo_dao->mt_clarif = VALUE #( ( object_id = 'LOT2' company_code = gc-bukrs currency = 'EUR' item_count = 3
                                   amount = '75.00' oldest = '20261111' ) ).

    DATA(ls_result) = run( ).
    DATA(ls_finding) = ls_result-findings[ 1 ].

    cl_abap_unit_assert=>assert_equals( act = ls_finding-check_code exp = zif_ca_ops_cash_types=>gc_code-lot_clarif ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-rule_id exp = zif_ca_ops_cash_types=>gc_stage-clarify ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = '75.00' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_posted_to exp = '20261113' ).
  ENDMETHOD.


  " Fixture PAYLOT-03: the done status is pending - not evaluated (partial); the clarification rule still runs
  METHOD done_status_pending.
    mo_seed->remove( zif_ca_ops_cash_types=>gc_param-lot_done_status ).
    mo_dao->mt_clarif = VALUE #( ( object_id = 'LOT2' company_code = gc-bukrs currency = 'EUR' item_count = 1
                                   amount = '5.00' oldest = '20261111' ) ).

    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 2 ).
    DATA(ls_pending) = ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-not_evaluated ].
    cl_abap_unit_assert=>assert_equals( act = ls_pending-cfg_rule exp = zif_ca_ops_cash_types=>gc_param-lot_done_status ).
    cl_abap_unit_assert=>assert_true( ls_result-partial ).
    cl_abap_unit_assert=>assert_initial( mo_dao->mv_created_to ).
  ENDMETHOD.


  " Fixture PAYLOT-04: nothing open and nothing in clarification - no finding and complete (auto-resolve allowed)
  METHOD nothing_open_is_observed.
    DATA(ls_result) = run( ).

    cl_abap_unit_assert=>assert_initial( ls_result-findings ).
    cl_abap_unit_assert=>assert_false( ls_result-partial ).
  ENDMETHOD.


  " Fixture PAYLOT-05: the lot table cannot be read - not evaluated with the source, never green
  METHOD unreadable_not_evaluated.
    mo_dao->mv_fail = abap_true.

    DATA(ls_result) = run( ).

    DATA(ls_finding) = ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-not_evaluated ].
    cl_abap_unit_assert=>assert_equals( act = ls_finding-reference exp = zif_ca_ops_cash_types=>gc_source-lots ).
    cl_abap_unit_assert=>assert_not_initial( ls_finding-error_class ).
    cl_abap_unit_assert=>assert_true( ls_result-partial ).
  ENDMETHOD.

ENDCLASS.
