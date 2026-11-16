*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_chq_no_id.clas.testclasses.abap
*& Purpose:
*& Unit tests of the check for cheque payments without a cheque number: every
*& payment the DAO returns is an error finding with run, amount, currency and
*& company code, plus one exposure finding per currency; the window is the
*& run date of the day before the report date by default; MAX caps the list
*& while the metric counts all; unset cheque methods raise (no verdict). The
*& cheque DAO is a double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
CLASS ltd_cheque DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_cheque_dao PARTIALLY IMPLEMENTED.
    DATA mt_payments TYPE zif_cd_hck_cheque_types=>tt_payment.
    DATA mv_from TYPE d.
    DATA mv_to TYPE d.
    DATA mt_methods TYPE zif_cd_hck_cheque_types=>tt_pymet.
ENDCLASS.

CLASS ltd_cheque IMPLEMENTATION.
  METHOD zif_cd_hck_cheque_dao~get_payments_without_cheque.
    mv_from = iv_from.
    mv_to = iv_to.
    mt_methods = it_methods.
    rt_payments = mt_payments.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chq_no_id DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        check    TYPE zif_cd_hck_types=>ty_check_id VALUE 'C_CHQ_NO_ID',
        options  TYPE zif_cd_hck_types=>ty_param VALUE 'METHODS=c',
        cap_one  TYPE zif_cd_hck_types=>ty_param VALUE 'METHODS=C;MAX=1',
        unset    TYPE zif_cd_hck_types=>ty_param VALUE 'METHODS=‹cheque payment methods›',
        today    TYPE d VALUE '20261116',
        run_day  TYPE d VALUE '20261115',
        doc_a    TYPE c LENGTH 24 VALUE '000000920001',
        doc_b    TYPE c LENGTH 24 VALUE '000000920002',
        method   TYPE c LENGTH 1 VALUE 'C',
        bukrs    TYPE c LENGTH 4 VALUE 'ZT01',
        usd      TYPE zif_ca_ops_types=>ty_currency VALUE 'USD',
        amount   TYPE zif_ca_ops_types=>ty_amount VALUE '75.00',
      END OF gc.

    DATA mo_cheque TYPE REF TO ltd_cheque.
    DATA ms_def TYPE zif_cd_hck_types=>ty_check_def.

    METHODS setup.
    METHODS teardown.
    METHODS payment_without_number FOR TESTING.
    METHODS findings_capped_metric_all FOR TESTING.
    METHODS unset_methods_raise FOR TESTING.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_chq_no_id IMPLEMENTATION.

  METHOD setup.
    mo_cheque = NEW #( ).
    ms_def = VALUE #( check_id = gc-check param1 = gc-options ).
    mo_cheque->mt_payments = VALUE #( ( doc1r = gc-doc_a laufd = gc-run_day bukrs = gc-bukrs pymet = gc-method
                                        amount = gc-amount currency = gc-usd )
                                      ( doc1r = gc-doc_b laufd = gc-run_day bukrs = gc-bukrs pymet = gc-method
                                        amount = gc-amount currency = gc-usd ) ).
    zcl_cd_hck_injector=>inject_cheque_dao( mo_cheque ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_chq_no_id( )->zif_cd_hck_check~execute(
      is_def        = ms_def
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc-today ) ).
  ENDMETHOD.


  " Rule: each cheque payment of yesterday's runs without cheque number is an error with its evidence
  METHOD payment_without_number.
    TRY.
        DATA(ls_result) = act( ).
        DATA(lt_found) = VALUE zif_ca_ops_types=>tt_finding(
                           FOR ls_finding IN ls_result-findings
                           WHERE ( check_code = zif_cd_hck_cheque_types=>gc_code-cheque_no_id ) ( ls_finding ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_found ) exp = 2 msg = 'Two payments' ).
        cl_abap_unit_assert=>assert_equals( act = lt_found[ 1 ]-severity exp = zif_ca_ops_types=>gc_severity-error
                                            msg = 'Error' ).
        cl_abap_unit_assert=>assert_equals( act = lt_found[ 1 ]-amount exp = gc-amount msg = 'Amount' ).
        cl_abap_unit_assert=>assert_equals( act = lt_found[ 1 ]-currency exp = gc-usd msg = 'Currency' ).
        cl_abap_unit_assert=>assert_equals( act = lt_found[ 1 ]-company_code exp = gc-bukrs msg = 'Company code' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cheque->mv_from exp = gc-run_day msg = 'Runs of yesterday' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cheque->mv_to exp = gc-run_day msg = 'One run day' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_cheque->mt_methods[ table_line = gc-method ] ) )
                                          msg = 'Method in upper case' ).
        DATA(lt_total) = VALUE zif_ca_ops_types=>tt_finding(
                           FOR ls_finding IN ls_result-findings
                           WHERE ( check_code = zif_cd_hck_cheque_types=>gc_code-exposure ) ( ls_finding ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_total ) exp = 1 msg = 'One currency' ).
        cl_abap_unit_assert=>assert_equals( act = lt_total[ 1 ]-item_count exp = 2 msg = 'Count per currency' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: MAX caps the listed findings, the metric still counts every payment
  METHOD findings_capped_metric_all.
    ms_def-param1 = gc-cap_one.
    TRY.
        DATA(ls_result) = act( ).
        DATA(lv_listed) = REDUCE i( INIT n = 0 FOR ls_finding IN ls_result-findings
                                    WHERE ( check_code = zif_cd_hck_cheque_types=>gc_code-cheque_no_id ) NEXT n = n + 1 ).
        cl_abap_unit_assert=>assert_equals( act = lv_listed exp = 1 msg = 'List capped' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 2 msg = 'Metric counts all' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: cheque methods still a placeholder - not evaluated, nothing read
  METHOD unset_methods_raise.
    ms_def-param1 = gc-unset.
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'Unset methods must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Not evaluated' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cheque->mv_to msg = 'Nothing read' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
