*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_cash_ebs.clas.testclasses.abap
*& Purpose:
*& Fixtures of the bank statement check (config/cash/fixtures.json, EBS-*)
*& through ZIF_CA_OPS_CHECK=>RUN: one known account without the statement
*& of a working day = statement missing (account key, owner, age); no
*& statement of any account for a day = one "source stale", not one per
*& account; the weekend = not expected; lines not posted and lines without
*& payment lot per statement and currency; the house banks to FI-CA pending
*& = "not evaluated"; no statement at all in the account window = expected
*& accounts unknown, "not evaluated". Doubles: cash data access; parameters
*& in memory. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
CLASS ltd_ebs_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cash_dao PARTIALLY IMPLEMENTED.
    DATA mt_days TYPE zif_ca_ops_cash_types=>tt_statement_day.
    DATA mt_unposted TYPE zif_ca_ops_cash_types=>tt_sum.
    DATA mt_no_lot TYPE zif_ca_ops_cash_types=>tt_sum.
ENDCLASS.

CLASS ltd_ebs_dao IMPLEMENTATION.
  METHOD zif_ca_ops_cash_dao~statement_days.
    rt_days = mt_days.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~unposted_lines.
    rt_sums = mt_unposted.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~lines_not_in_fica.
    rt_sums = mt_no_lot.
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~working_day.
    rv_working = xsdbool( iv_date <> '20261114' AND iv_date <> '20261115' ).
  ENDMETHOD.
  METHOD zif_ca_ops_cash_dao~owner.
    rs_owner = VALUE #( control_id = 'FICA_EBS_LOTS' owner = 'ZT_OWNER' team = 'ZT_TEAM' ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_cash_ebs DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area  TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        bukrs TYPE bukrs VALUE 'ZT01',
        today TYPE d VALUE '20261116',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_ebs_dao.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.
    METHODS of_code
      IMPORTING
        is_result          TYPE zif_ca_ops_chk_types=>ty_result
        iv_code            TYPE zif_ca_ops_types=>ty_check_code
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.

    METHODS account_missing_one_day    FOR TESTING RAISING zcx_ca_ops_error.
    METHODS no_account_delivered_stale FOR TESTING RAISING zcx_ca_ops_error.
    METHODS lines_unposted_and_no_lot  FOR TESTING RAISING zcx_ca_ops_error.
    METHODS fica_banks_pending         FOR TESTING RAISING zcx_ca_ops_error.
    METHODS no_statement_unknown       FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_chk_cash_ebs IMPLEMENTATION.

  METHOD setup.
    mo_dao  = NEW #( ).
    mo_seed = NEW #( ).
    zcl_ca_ops_cash_injector=>inject_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-calendar iv_value = 'ZT' ).
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-lookback_days iv_value = '4' ).
    mo_seed->set( iv_name = zif_ca_ops_cash_types=>gc_param-ebs_fica_banks iv_value = 'HB1' ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_cash_injector=>reset( ).
  ENDMETHOD.


  METHOD run.
    rs_result = NEW zcl_ca_ops_chk_cash_ebs( )->zif_ca_ops_check~run(
                  is_check   = VALUE #( area = gc-area check_id = 'FICA_CASH_EBS' process_id = 'FICA_EBS_LOTS'
                                        bukrs_aware = abap_true )
                  is_context = VALUE #( area = gc-area today = gc-today ) ).
  ENDMETHOD.


  METHOD of_code.
    rt_findings = VALUE #( FOR ls IN is_result-findings WHERE ( check_code = iv_code ) ( ls ) ).
  ENDMETHOD.


  " Fixture EBS-01: two accounts deliver on the 12th, only HB1/AC1 on the 13th - HB2/AC2 missing for the 13th
  METHOD account_missing_one_day.
    mo_dao->mt_days = VALUE #( ( company_code = gc-bukrs house_bank = 'HB1' account_id = 'AC1'
                                 statement_date = '20261112' statement_count = 1 )
                               ( company_code = gc-bukrs house_bank = 'HB2' account_id = 'AC2'
                                 statement_date = '20261112' statement_count = 1 )
                               ( company_code = gc-bukrs house_bank = 'HB1' account_id = 'AC1'
                                 statement_date = '20261113' statement_count = 1 ) ).

    DATA(ls_result) = run( ).

    DATA(lt_missing) = of_code( is_result = ls_result iv_code = zif_ca_ops_cash_types=>gc_code-ebs_missing ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_missing ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_missing[ 1 ]-object_key exp = '20261113/HB2/AC2/ZT01/' ).
    cl_abap_unit_assert=>assert_equals( act = lt_missing[ 1 ]-account exp = 'HB2/AC2' ).
    cl_abap_unit_assert=>assert_equals( act = lt_missing[ 1 ]-business_date exp = '20261113' ).
    cl_abap_unit_assert=>assert_true( xsdbool( lt_missing[ 1 ]-details CS 'ZT_OWNER' ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lines( of_code( is_result = ls_result iv_code = zif_ca_ops_cash_types=>gc_code-not_expected ) )
      exp = 2 ).
    cl_abap_unit_assert=>assert_initial( of_code( is_result = ls_result iv_code = zif_ca_ops_cash_types=>gc_code-ebs_stale ) ).
  ENDMETHOD.


  " Fixture EBS-02 (scorecard 4): nothing arrived on the 13th for any of two known accounts - one "source stale"
  METHOD no_account_delivered_stale.
    mo_dao->mt_days = VALUE #( ( company_code = gc-bukrs house_bank = 'HB1' account_id = 'AC1'
                                 statement_date = '20261112' statement_count = 1 )
                               ( company_code = gc-bukrs house_bank = 'HB2' account_id = 'AC2'
                                 statement_date = '20261112' statement_count = 1 ) ).

    DATA(ls_result) = run( ).

    DATA(lt_stale) = of_code( is_result = ls_result iv_code = zif_ca_ops_cash_types=>gc_code-ebs_stale ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_stale ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_stale[ 1 ]-item_count exp = 2 ).
    cl_abap_unit_assert=>assert_true( xsdbool( lt_stale[ 1 ]-details CS zif_ca_ops_cash_types=>gc_evaluation-stale ) ).
    cl_abap_unit_assert=>assert_initial( of_code( is_result = ls_result
                                                  iv_code   = zif_ca_ops_cash_types=>gc_code-ebs_missing ) ).
  ENDMETHOD.


  " Fixture EBS-03 (scorecard 3): statement 00000001 has 2 lines not posted (100.00 EUR), statement 00000003 of HB1
  " has no payment lot (3 lines, 45.00 EUR)
  METHOD lines_unposted_and_no_lot.
    mo_dao->mt_days = VALUE #( ( company_code = gc-bukrs house_bank = 'HB1' account_id = 'AC1'
                                 statement_date = '20261112' statement_count = 1 )
                               ( company_code = gc-bukrs house_bank = 'HB1' account_id = 'AC1'
                                 statement_date = '20261113' statement_count = 1 ) ).
    mo_dao->mt_unposted = VALUE #( ( object_id = '00000001' company_code = gc-bukrs currency = 'EUR' house_bank = 'HB1'
                                     account_id = 'AC1' item_count = 2 amount = '100.00' oldest = '20261112' ) ).
    mo_dao->mt_no_lot = VALUE #( ( object_id = '00000003' company_code = gc-bukrs currency = 'EUR' house_bank = 'HB1'
                                   account_id = 'AC1' item_count = 3 amount = '45.00' oldest = '20261113' ) ).

    DATA(ls_result) = run( ).

    DATA(lt_unposted) = of_code( is_result = ls_result iv_code = zif_ca_ops_cash_types=>gc_code-ebs_unposted ).
    DATA(ls_unposted) = lt_unposted[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_unposted-object_key exp = '00000001/ZT01/EUR' ).
    cl_abap_unit_assert=>assert_equals( act = ls_unposted-amount exp = '100.00' ).
    cl_abap_unit_assert=>assert_true( xsdbool( ls_unposted-details CS 'KUKEY' ) ).
    DATA(lt_no_lot) = of_code( is_result = ls_result iv_code = zif_ca_ops_cash_types=>gc_code-ebs_not_fica ).
    DATA(ls_no_lot) = lt_no_lot[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_no_lot-item_count exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = ls_no_lot-rule_id exp = zif_ca_ops_cash_types=>gc_stage-transfer ).
    cl_abap_unit_assert=>assert_false( ls_result-partial ).
  ENDMETHOD.


  " Fixture EBS-04: the house banks to FI-CA are not maintained - the transfer rule is not evaluated
  METHOD fica_banks_pending.
    mo_seed->remove( zif_ca_ops_cash_types=>gc_param-ebs_fica_banks ).
    mo_dao->mt_days = VALUE #( ( company_code = gc-bukrs house_bank = 'HB1' account_id = 'AC1'
                                 statement_date = '20261112' statement_count = 1 )
                               ( company_code = gc-bukrs house_bank = 'HB1' account_id = 'AC1'
                                 statement_date = '20261113' statement_count = 1 ) ).

    DATA(ls_result) = run( ).

    DATA(lt_pending) = of_code( is_result = ls_result iv_code = zif_ca_ops_cash_types=>gc_code-not_evaluated ).
    DATA(ls_pending) = lt_pending[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_pending-cfg_rule exp = zif_ca_ops_cash_types=>gc_param-ebs_fica_banks ).
    cl_abap_unit_assert=>assert_true( ls_result-partial ).
  ENDMETHOD.


  " Fixture EBS-05: no statement at all in the account window - the expected accounts are unknown, not green
  METHOD no_statement_unknown.
    DATA(ls_result) = run( ).

    DATA(lt_unknown) = of_code( is_result = ls_result iv_code = zif_ca_ops_cash_types=>gc_code-not_evaluated ).
    cl_abap_unit_assert=>assert_equals( act = lt_unknown[ 1 ]-rule_id exp = zif_ca_ops_cash_types=>gc_stage-arrival ).
    cl_abap_unit_assert=>assert_true( ls_result-partial ).
  ENDMETHOD.

ENDCLASS.
