*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_cash_glkey.clas.testclasses.abap
*& Purpose:
*& Fixtures of the reconciliation key check (config/cash/fixtures.json,
*& GLKEY-*) through ZIF_CA_OPS_CHECK=>RUN: a key open past its cutoff, a
*& key with transfer error and a closed key without G/L document are
*& exceptions per key, company code and currency with amount, owner and
*& age; the G/L rule names the journal entry that should exist; the
*& reference type pending = that rule "not evaluated" while the others run;
*& one unreadable rule leaves the others evaluated, the check partial.
*& Doubles: cash data access; parameters in memory. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
CLASS ltd_glkey_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cash_dao PARTIALLY IMPLEMENTED.
    DATA mt_open TYPE zif_ca_ops_cash_types=>tt_sum.
    DATA mt_error TYPE zif_ca_ops_cash_types=>tt_sum.
    DATA mt_gap TYPE zif_ca_ops_cash_types=>tt_sum.
    DATA mv_awtyp TYPE string.
    DATA mv_fail_error TYPE abap_bool.
ENDCLASS.

CLASS ltd_glkey_dao IMPLEMENTATION.
  METHOD zif_ca_ops_cash_dao~open_keys.
    rt_sums = mt_open.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~error_keys.
    IF mv_fail_error = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e521(zca_ops) WITH 'DFKKSUMC'.
    ENDIF.
    rt_sums = mt_error.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~keys_not_in_gl.
    mv_awtyp = iv_awtyp.
    rt_sums = mt_gap.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~owner.
    rs_owner = VALUE #( control_id = 'FICA_GL_TRANSFER' owner = 'ZT_OWNER' team = 'ZT_TEAM' ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_cash_glkey DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area  TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        bukrs TYPE bukrs VALUE 'ZT01',
        today TYPE d VALUE '20261116',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_glkey_dao.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.
    METHODS key
      IMPORTING
        iv_key        TYPE clike
        iv_amount     TYPE zif_ca_ops_cash_types=>ty_amount
      RETURNING
        VALUE(rt_sum) TYPE zif_ca_ops_cash_types=>tt_sum.

    METHODS open_past_cutoff         FOR TESTING RAISING zcx_ca_ops_error.
    METHODS closed_not_in_gl         FOR TESTING RAISING zcx_ca_ops_error.
    METHODS reference_type_pending   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS one_rule_unreadable      FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_chk_cash_glkey IMPLEMENTATION.

  METHOD setup.
    mo_dao  = NEW #( ).
    mo_seed = NEW #( ).
    zcl_ca_ops_cash_injector=>inject_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-gl_awtyp iv_value = 'ZTREF' ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_cash_injector=>reset( ).
  ENDMETHOD.


  METHOD run.
    rs_result = NEW zcl_ca_ops_chk_cash_glkey( )->zif_ca_ops_check~run(
                  is_check   = VALUE #( area = gc-area check_id = 'FICA_CASH_GLKEY' process_id = 'FICA_GL_TRANSFER'
                                        bukrs_aware = abap_true )
                  is_context = VALUE #( area = gc-area today = gc-today ) ).
  ENDMETHOD.


  METHOD key.
    rt_sum = VALUE #( ( object_id = iv_key company_code = gc-bukrs currency = 'EUR' item_count = 4 amount = iv_amount
                        oldest = '20261112' ) ).
  ENDMETHOD.


  " Fixture GLKEY-01: key KEY_OPEN created on the 12th still open (4 total lines, 1,000.00 EUR debit side)
  METHOD open_past_cutoff.
    mo_dao->mt_open = key( iv_key = 'KEY_OPEN' iv_amount = '1000.00' ).

    DATA(ls_result) = run( ).

    DATA(ls_finding) = ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-glkey_open ].
    cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = 'KEY_OPEN/ZT01/EUR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = '1000.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-business_date exp = '20261112' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-rule_id exp = zif_ca_ops_cash_types=>gc_stage-close ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS 'FIKEY' ) ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS 'ZT_OWNER' ) ).
    cl_abap_unit_assert=>assert_false( ls_result-partial ).
  ENDMETHOD.


  " Fixture GLKEY-02 (scorecard 3): key KEY_GAP closed on the 12th, no G/L document of reference type ZTREF
  METHOD closed_not_in_gl.
    mo_dao->mt_gap = key( iv_key = 'KEY_GAP' iv_amount = '300.00' ).

    DATA(ls_result) = run( ).

    DATA(ls_finding) = ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-glkey_not_gl ].
    cl_abap_unit_assert=>assert_equals( act = ls_finding-amount exp = '300.00' ).
    cl_abap_unit_assert=>assert_equals( act = ls_finding-rule_id exp = zif_ca_ops_cash_types=>gc_stage-gl ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_finding-details CS 'ZTREF/KEY_GAP' ) ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_awtyp exp = 'ZTREF' ).
  ENDMETHOD.


  " Fixture GLKEY-03: the reference type is pending - the G/L rule is not evaluated, the others run, partial
  METHOD reference_type_pending.
    mo_seed->remove( zif_ca_ops_cash_types=>gc_param-gl_awtyp ).
    mo_dao->mt_error = key( iv_key = 'KEY_ERR' iv_amount = '20.00' ).

    DATA(ls_result) = run( ).

    DATA(ls_pending) = ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-not_evaluated ].
    cl_abap_unit_assert=>assert_equals( act = ls_pending-cfg_rule exp = zif_ca_ops_cash_types=>gc_param-gl_awtyp ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists(
      ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-glkey_error ] ) ) ).
    cl_abap_unit_assert=>assert_initial( mo_dao->mv_awtyp ).
    cl_abap_unit_assert=>assert_true( ls_result-partial ).
  ENDMETHOD.


  " Fixture GLKEY-04: the error read fails - not evaluated for the transfer stage, the open keys still reported
  METHOD one_rule_unreadable.
    mo_dao->mv_fail_error = abap_true.
    mo_dao->mt_open = key( iv_key = 'KEY_OPEN' iv_amount = '1000.00' ).

    DATA(ls_result) = run( ).

    DATA(ls_failed) = ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-not_evaluated ].
    cl_abap_unit_assert=>assert_equals( act = ls_failed-rule_id exp = zif_ca_ops_cash_types=>gc_stage-transfer ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists(
      ls_result-findings[ check_code = zif_ca_ops_cash_types=>gc_code-glkey_open ] ) ) ).
    cl_abap_unit_assert=>assert_true( ls_result-partial ).
  ENDMETHOD.

ENDCLASS.
