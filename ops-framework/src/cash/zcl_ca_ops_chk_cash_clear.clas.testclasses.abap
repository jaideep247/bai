*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_cash_clear.clas.testclasses.abap
*& Purpose:
*& Fixtures of the clearing reset / reversal check (config/cash/fixtures.json,
*& CLEAR-*) through ZIF_CA_OPS_CHECK=>RUN: a clearing by a paid payment
*& reset in the window is an exception with the clearing document, amount,
*& currency, owner and reset date; a reversed payment document names its
*& run; the window starts CASH_CLR_DAYS back and the clearing reasons of
*& CASH_CLR_AUGRD reach the read; the check is always partial (an operator
*& closes the exception); an unreadable source is "not evaluated". Doubles:
*& cash data access; parameters in memory. Does not prove live SAP runtime
*& behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
CLASS ltd_clear_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cash_dao PARTIALLY IMPLEMENTED.
    DATA mt_resets TYPE zif_ca_ops_cash_types=>tt_sum.
    DATA mt_reversals TYPE zif_ca_ops_cash_types=>tt_sum.
    DATA mv_from TYPE d.
    DATA mt_augrd TYPE zif_ca_ops_types=>tt_param_range.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.

CLASS ltd_clear_dao IMPLEMENTATION.
  METHOD zif_ca_ops_cash_dao~paid_clearing_resets.
    mv_from  = iv_reset_from.
    mt_augrd = it_augrd.
    rt_sums  = mt_resets.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~reversed_payments.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e521(zca_ops) WITH 'DFKKKO'.
    ENDIF.
    rt_sums = mt_reversals.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~owner.
    rs_owner = VALUE #( control_id = 'FICA_CLEARING' owner = 'ZT_OWNER' team = 'ZT_TEAM' ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_cash_clear DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area  TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        bukrs TYPE bukrs VALUE 'ZT01',
        today TYPE d VALUE '20261116',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_clear_dao.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.

    METHODS reset_after_payout       FOR TESTING RAISING zcx_ca_ops_error.
    METHODS reversal_names_run       FOR TESTING RAISING zcx_ca_ops_error.
    METHODS always_partial           FOR TESTING RAISING zcx_ca_ops_error.
    METHODS unreadable_not_evaluated FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_chk_cash_clear IMPLEMENTATION.

  METHOD setup.
    mo_dao  = NEW #( ).
    mo_seed = NEW #( ).
    zcl_ca_ops_cash_injector=>inject_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-clr_augrd iv_value = 'Z1,Z2' ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_cash_injector=>reset( ).
  ENDMETHOD.


  METHOD run.
    rs_result = NEW zcl_ca_ops_chk_cash_clear( )->zif_ca_ops_check~run(
                  is_check   = VALUE #( area = gc-area check_id = 'FICA_CASH_CLEARING' process_id = 'FICA_CLEARING'
                                        bukrs_aware = abap_true )
                  is_context = VALUE #( area = gc-area today = gc-today ) ).
  ENDMETHOD.


  " Fixture CLEAR-01 (scorecard 3): the clearing by payment document PAYDOC1 (2 items, 80.00 EUR) was reset on the
  " 15th after the payment run paid it
  METHOD reset_after_payout.
    mo_dao->mt_resets = VALUE #( ( object_id = 'PAYDOC1' company_code = gc-bukrs currency = 'EUR' item_count = 2
                                   amount = '80.00' oldest = '20261115' ) ).

    DATA(ls_result) = run( ).

    DATA(ls_finding) = ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-clr_reset ].
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = 'PAYDOC1/ZT01/EUR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = '80.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-business_date exp = '20261115' ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS 'AUGBL' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS 'ZT_OWNER' ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_from exp = '20261115' ).
    cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_augrd ) exp = 2 ).
  ENDMETHOD.


  " Fixture CLEAR-02: payment document PAYDOC2 of run 20261112/PAY01 reversed on the 15th (500.00 EUR)
  METHOD reversal_names_run.
    mo_dao->mt_reversals = VALUE #( ( object_id = 'PAYDOC2' object_sub = '20261112PAY01' company_code = gc-bukrs
                                      currency = 'EUR' item_count = 1 amount = '500.00' oldest = '20261115' ) ).

    DATA(ls_result) = run( ).

    DATA(ls_finding) = ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-pay_reversed ].
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = 'PAYDOC2/20261112/PAY01/ZT01/EUR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = '500.00' ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS 'LAUFD/LAUFI' ) ).
  ENDMETHOD.


  " Rule: an event in the window never disappears by itself - the check is partial even without findings
  METHOD always_partial.
    cl_abap_unit_assert=>assert_true( run( )-partial ).
  ENDMETHOD.


  " Fixture CLEAR-03: the reversal source cannot be read - not evaluated for the reversal stage
  METHOD unreadable_not_evaluated.
    mo_dao->mv_fail = abap_true.

    DATA(ls_result) = run( ).

    DATA(ls_finding) = ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-not_evaluated ].
    cl_abap_unit_assert=>assert_equals( act = ls_finding-rule_id exp = zif_ca_ops_cash_types=>gc_stage-reversal ).
  ENDMETHOD.

ENDCLASS.
