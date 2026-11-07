*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_inflight.clas.testclasses.abap
*& Purpose:
*& Unit tests of the in-flight check: wire / ACH aged in business days after
*& the value date (boundary, holiday, no calendar, missing value date), both
*& flows reported separately, cleared / returned / reversed payments left
*& out (bank line, cleared assignment, encashed cheque), cheques in calendar
*& days, empty data, method mapping and limits configuration, row cap and
*& top N. Runtime DAO, payment trace repository and HCK DAO are test doubles
*& from the injectors, parameters the delivered in-memory definitions;
*& does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (payments in flight, both flows, value date).
*&---------------------------------------------------------------------*
CLASS ltd_runtime_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_runtime_dao PARTIALLY IMPLEMENTED.
    DATA mt_payments TYPE zif_cd_hck_runtime_types=>tt_issued_payment.
    DATA mt_cleared TYPE zif_cd_hck_runtime_types=>tt_assignment.
    DATA mt_asked TYPE zif_cd_hck_runtime_types=>tt_assignment.
ENDCLASS.

CLASS ltd_runtime_dao IMPLEMENTATION.
  METHOD zif_cd_hck_runtime_dao~get_issued_payments.
    LOOP AT mt_payments ASSIGNING FIELD-SYMBOL(<ls_payment>)
         WHERE laufd BETWEEN iv_from AND iv_to.
      IF line_exists( it_methods[ table_line = <ls_payment>-pymet ] ).
        INSERT <ls_payment> INTO TABLE rt_payments.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_hck_runtime_dao~get_cleared_assignments.
    mt_asked = it_keys.
    LOOP AT mt_cleared ASSIGNING FIELD-SYMBOL(<ls_cleared>).
      IF line_exists( it_keys[ bukrs = <ls_cleared>-bukrs zuonr = <ls_cleared>-zuonr ] ).
        INSERT <ls_cleared> INTO TABLE rt_cleared.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_headers TYPE zif_cd_ops_trace_types=>tt_doc_header.
    DATA mt_returns TYPE zif_cd_ops_trace_types=>tt_return.
    DATA mt_checks TYPE zif_cd_ops_trace_types=>tt_check.
    DATA mt_lines TYPE zif_cd_ops_trace_types=>tt_bank_line.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~get_doc_headers.
    rt_headers = mt_headers.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_returns.
    rt_returns = mt_returns.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_checks_by_doc.
    LOOP AT mt_checks ASSIGNING FIELD-SYMBOL(<ls_check>).
      IF line_exists( it_docno[ table_line = <ls_check>-doc1r ] ).
        INSERT <ls_check> INTO TABLE rt_checks.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~get_bank_lines.
    LOOP AT mt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      IF line_exists( it_ref[ table_line = <ls_line>-chect ] ).
        INSERT <ls_line> INTO TABLE rt_lines.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_hck_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    "! Non-working days of the test calendar (every other day works)
    DATA mt_holidays TYPE SORTED TABLE OF d WITH UNIQUE KEY table_line.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_hck_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~is_working_day.
    mv_calls = mv_calls + 1.
    rv_working = xsdbool( NOT line_exists( mt_holidays[ table_line = iv_date ] ) ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_inflight DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check    TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_INFLIGHT',
      gc_calendar TYPE zif_cd_hck_types=>ty_param VALUE 'US',
      gc_wire     TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'E',
      gc_ach      TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'G',
      gc_cheque   TYPE zif_cd_hck_runtime_types=>ty_pymet VALUE 'C',
      gc_bukrs    TYPE c LENGTH 4 VALUE 'US01',
      gc_usd      TYPE zif_cd_ops_types=>ty_currency VALUE 'USD',
      gc_amount   TYPE zif_cd_ops_types=>ty_amount VALUE '-250.00',
      "! Wednesday; Tuesday 2026-11-10 is a holiday of the test calendar
      gc_today    TYPE d VALUE '20261111',
      gc_holiday  TYPE d VALUE '20261110',
      gc_monday   TYPE d VALUE '20261109',
      gc_friday   TYPE d VALUE '20261106',
      gc_doc1     TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300001',
      gc_doc2     TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300002',
      gc_doc3     TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300003',
      gc_doc4     TYPE zif_cd_hck_runtime_types=>ty_docno VALUE '000000300004',
      gc_ztnum    TYPE zif_cd_ops_trace_types=>ty_ref VALUE '0000770001'.

    CONSTANTS:
      BEGIN OF gc_key,
        d_wire   TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'DWIR',
        d_ach    TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'DACH',
        d_cheque TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'DCHQ',
        c_wire   TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'CWIR',
        c_ach    TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'CACH',
      END OF gc_key.

    DATA mo_dao TYPE REF TO ltd_runtime_dao.
    DATA mo_trace TYPE REF TO ltd_trace_dao.
    DATA mo_hck_dao TYPE REF TO ltd_hck_dao.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.
    DATA mt_thresholds TYPE zif_cd_hck_types=>tt_threshold.

    METHODS setup.
    METHODS teardown.
    METHODS wire_value_date_boundary    FOR TESTING.
    METHODS holiday_is_not_a_business_day FOR TESTING.
    METHODS no_calendar_counts_all_days FOR TESTING.
    METHODS missing_value_date_run_date FOR TESTING.
    METHODS flows_reported_separately   FOR TESTING.
    METHODS cleared_and_returned_skip   FOR TESTING.
    METHODS cheque_calendar_days        FOR TESTING.
    METHODS empty_data_measures_zero    FOR TESTING.
    METHODS method_in_two_classes_raises FOR TESTING.
    METHODS limits_missing_warns        FOR TESTING.
    METHODS read_cap_and_top_n          FOR TESTING.

    METHODS limit
      IMPORTING
        iv_key   TYPE zif_cd_hck_runtime_types=>ty_flow_class
        iv_amber TYPE zif_cd_hck_types=>ty_value
        iv_red   TYPE zif_cd_hck_types=>ty_value.
    METHODS add_payment
      IMPORTING
        iv_doc        TYPE zif_cd_hck_runtime_types=>ty_docno
        iv_pymet      TYPE zif_cd_hck_runtime_types=>ty_pymet DEFAULT gc_wire
        iv_laufd      TYPE d DEFAULT gc_friday
        iv_valut      TYPE d OPTIONAL
        iv_collection TYPE abap_bool DEFAULT abap_false.
    METHODS act
      IMPORTING
        iv_calendar      TYPE zif_cd_hck_types=>ty_param DEFAULT gc_calendar
        iv_top_n         TYPE zif_cd_hck_types=>ty_param OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
    METHODS metric
      IMPORTING
        is_result       TYPE zif_cd_hck_types=>ty_check_result
        iv_metric       TYPE zif_cd_hck_types=>ty_metric_name
        iv_key          TYPE zif_cd_hck_runtime_types=>ty_flow_class DEFAULT gc_key-d_wire
      RETURNING
        VALUE(rv_value) TYPE zif_cd_hck_types=>ty_value.
    METHODS late
      IMPORTING
        is_result         TYPE zif_cd_hck_types=>ty_check_result
        iv_key            TYPE zif_cd_hck_runtime_types=>ty_flow_class DEFAULT gc_key-d_wire
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.
ENDCLASS.


CLASS ltc_inflight IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_runtime_dao( mo_dao ).
    mo_hck_dao = NEW #( ).
    INSERT gc_holiday INTO TABLE mo_hck_dao->mt_holidays.
    zcl_cd_hck_injector=>inject_dao( mo_hck_dao ).
    mo_trace = NEW #( ).
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    mo_params = NEW #( ).
    mo_params->set( iv_name = zif_cd_hck_runtime_types=>gc_param-inflight_wire iv_value = gc_wire ).
    mo_params->set( iv_name = zif_cd_hck_runtime_types=>gc_param-inflight_ach iv_value = gc_ach ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
    " Seed limits (confirm): wire late from 1 / critical from 2 business days after the value
    " date, ACH 2 / 3, cheques 61 / 90+ calendar days (> 60 / > 90)
    limit( iv_key = gc_key-d_wire iv_amber = 1 iv_red = 2 ).
    limit( iv_key = gc_key-c_wire iv_amber = 1 iv_red = 2 ).
    limit( iv_key = gc_key-d_ach iv_amber = 2 iv_red = 3 ).
    limit( iv_key = gc_key-c_ach iv_amber = 2 iv_red = 3 ).
    limit( iv_key = gc_key-d_cheque iv_amber = 61 iv_red = 91 ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_trace, mo_hck_dao, mo_params, mt_thresholds.
  ENDMETHOD.


  METHOD limit.
    DATA ls_threshold TYPE zif_cd_hck_types=>ty_threshold.
    ls_threshold-check_id        = gc_check.
    ls_threshold-metric          = zcl_cd_hck_c_inflight=>gc_metric-age_oldest.
    ls_threshold-bukrs           = iv_key.
    ls_threshold-amber           = iv_amber.
    ls_threshold-red             = iv_red.
    ls_threshold-higher_is_worse = abap_true.
    ls_threshold-baseline_mode   = zif_cd_hck_types=>gc_baseline-none.
    INSERT ls_threshold INTO TABLE mt_thresholds.
  ENDMETHOD.


  METHOD add_payment.
    DATA ls_payment TYPE zif_cd_hck_runtime_types=>ty_issued_payment.
    ls_payment-doc1r    = iv_doc.
    ls_payment-laufd    = iv_laufd.
    ls_payment-bukrs    = gc_bukrs.
    ls_payment-pymet    = iv_pymet.
    ls_payment-valut    = iv_valut.
    ls_payment-amount   = gc_amount.
    ls_payment-currency = gc_usd.
    ls_payment-xeinz    = iv_collection.
    INSERT ls_payment INTO TABLE mo_dao->mt_payments.
  ENDMETHOD.


  METHOD act.
    DATA ls_def TYPE zif_cd_hck_types=>ty_check_def.
    DATA ls_context TYPE zif_cd_hck_types=>ty_context.
    ls_def-check_id        = gc_check.
    ls_def-param1          = iv_calendar.
    ls_def-param4          = iv_top_n.
    ls_context-report_date = gc_today.
    ls_context-now_date    = gc_today.
    rs_result = NEW zcl_cd_hck_c_inflight( )->zif_cd_hck_check~execute( is_def        = ls_def
                                                                        it_thresholds = mt_thresholds
                                                                        is_context    = ls_context ).
  ENDMETHOD.


  METHOD metric.
    rv_value = VALUE #( is_result-metrics[ metric = iv_metric dim1 = iv_key ]-value OPTIONAL ).
  ENDMETHOD.


  METHOD late.
    rs_finding = VALUE #( is_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-payment_not_clear
                                              reference  = iv_key ] OPTIONAL ).
  ENDMETHOD.


  " Rule: a wire is late once its value date has passed by the grace (amber 1 = one business
  " day after); value date today is not late
  METHOD wire_value_date_boundary.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_today ).
        add_payment( iv_doc = gc_doc2 iv_valut = '20261108' ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open )
                                            exp = 2 msg = 'Two wires not cleared' ).
        " 2026-11-08 -> 09 (working), 10 (holiday), 11 (working) = 2 business days: critical
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-age_oldest )
                                            exp = 2 msg = 'Oldest: 2 business days' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-warn_count )
                                            exp = 1 msg = 'Value date today is not late' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-crit_count )
                                            exp = 1 msg = 'One critical' ).
        cl_abap_unit_assert=>assert_equals( act = late( ls_result )-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Critical payment: error' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( ls_result-metrics[ metric = zcl_cd_hck_c_inflight=>gc_metric-crit_amount
                                            dim1   = gc_key-d_wire dim2 = gc_usd ]-value OPTIONAL )
          exp = CONV zif_cd_hck_types=>ty_value( abs( gc_amount ) )
          msg = 'Critical amount per currency' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a holiday of the factory calendar between value date and today is not counted
  METHOD holiday_is_not_a_business_day.
    TRY.
        " Monday -> 10 (holiday), 11 = 1 business day: warning (amber 1), not critical (red 2)
        add_payment( iv_doc = gc_doc1 iv_valut = gc_monday ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-age_oldest )
                                            exp = 1 msg = 'Holiday not counted' ).
        cl_abap_unit_assert=>assert_equals( act = late( ls_result )-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'Late, not critical: warning' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-crit_count )
                                            exp = 0 msg = 'Nothing critical' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without a factory calendar every day counts (warning says so) - the same payment is critical
  METHOD no_calendar_counts_all_days.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_monday ).
        DATA(ls_result) = act( iv_calendar = space ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-age_oldest )
                                            exp = 2 msg = 'Calendar days' ).
        cl_abap_unit_assert=>assert_equals( act = mo_hck_dao->mv_calls exp = 0 msg = 'No calendar read' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                                             severity   = zif_cd_ops_types=>gc_severity-warning ]-severity OPTIONAL )
          exp = zif_cd_ops_types=>gc_severity-warning
          msg = 'Missing calendar: warning' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without value date the payment is aged from the run date and the finding says so
  METHOD missing_value_date_run_date.
    TRY.
        " Friday run date -> 07, 08, 09, 11 = 4 business days (10 is a holiday)
        add_payment( iv_doc = gc_doc1 ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-age_oldest )
                                            exp = 4 msg = 'Aged from the run date' ).
        DATA(lv_details) = late( ls_result )-details.
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( find( val = lv_details
                               sub = zcl_cd_ops_util=>text( zif_cd_hck_runtime_types=>gc_msg-run_date_used ) ) >= 0 )
          msg = 'Detail says the run date was used' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-value_date_missing ] ) )
          msg = 'Missing value dates listed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: collections (XEINZ = X) are measured and reported apart from disbursements (C / D)
  METHOD flows_reported_separately.
    TRY.
        " ACH collection, value date Friday: 4 business days -> critical (red 3)
        add_payment( iv_doc = gc_doc1 iv_pymet = gc_ach iv_valut = gc_friday iv_collection = abap_true ).
        " ACH disbursement, value date Monday: 1 business day -> not late (amber 2)
        add_payment( iv_doc = gc_doc2 iv_pymet = gc_ach iv_valut = gc_monday ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-crit_count
                                                          iv_key    = gc_key-c_ach )
                                            exp = 1 msg = 'Collection ACH critical' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-warn_count
                                                          iv_key    = gc_key-d_ach )
                                            exp = 0 msg = 'Disbursement ACH within grace' ).
        cl_abap_unit_assert=>assert_equals( act = late( is_result = ls_result iv_key = gc_key-c_ach )-severity
                                            exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Finding of flow C' ).
        cl_abap_unit_assert=>assert_initial( act = late( is_result = ls_result iv_key = gc_key-d_ach )
                                             msg = 'No finding of flow D' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( mo_dao->mt_asked[ bukrs = gc_bukrs zuonr = gc_doc1 ] ) )
          msg = 'Collection checked against the cleared assignment (ZUONR = AUGBL)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a payment matched to a bank line (CHECT = AUGBL, leading zeros ignored), a collection
  " with a cleared assignment, a returned and a reversed payment are not in flight
  METHOD cleared_and_returned_skip.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    DATA ls_return TYPE zif_cd_ops_trace_types=>ty_return.
    DATA ls_header TYPE zif_cd_ops_trace_types=>ty_doc_header.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        add_payment( iv_doc = gc_doc2 iv_valut = gc_friday ).
        add_payment( iv_doc = gc_doc3 iv_valut = gc_friday ).
        add_payment( iv_doc = gc_doc4 iv_pymet = gc_ach iv_valut = gc_friday iv_collection = abap_true ).
        ls_line-chect = '300001'.
        INSERT ls_line INTO TABLE mo_trace->mt_lines.
        ls_return-selw1 = gc_doc2.
        INSERT ls_return INTO TABLE mo_trace->mt_returns.
        ls_header-opbel = gc_doc3.
        ls_header-stbel = '000000900001'.
        INSERT ls_header INTO TABLE mo_trace->mt_headers.
        INSERT VALUE #( bukrs = gc_bukrs zuonr = gc_doc4 ) INTO TABLE mo_dao->mt_cleared.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open )
                                            exp = 0 msg = 'No wire in flight' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open
                                                          iv_key    = gc_key-c_ach )
                                            exp = 0 msg = 'Collection cleared on the clearing account' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-payment_not_clear ] ) )
          msg = 'Nothing late' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: cheques (disbursements) age in calendar days from issue: 60 days is not late, 61 is;
  " an encashed cheque or one on a bank line (CHECT = ZTNUM) is cleared; collection cheques are not watched
  METHOD cheque_calendar_days.
    DATA ls_check TYPE zif_cd_ops_trace_types=>ty_check.
    DATA ls_line TYPE zif_cd_ops_trace_types=>ty_bank_line.
    TRY.
        add_payment( iv_doc = gc_doc1 iv_pymet = gc_cheque iv_laufd = '20260912' ).
        add_payment( iv_doc = gc_doc2 iv_pymet = gc_cheque iv_laufd = '20260911' ).
        add_payment( iv_doc = gc_doc3 iv_pymet = gc_cheque iv_laufd = '20260801' ).
        add_payment( iv_doc = gc_doc4 iv_pymet = gc_cheque iv_laufd = '20260801' ).
        add_payment( iv_doc = '000000300005' iv_pymet = gc_cheque iv_laufd = '20260801' iv_collection = abap_true ).
        ls_check-doc1r = gc_doc3.
        ls_check-bancd = '20260815'.
        INSERT ls_check INTO TABLE mo_trace->mt_checks.
        CLEAR ls_check.
        ls_check-doc1r = gc_doc4.
        ls_check-ztnum = gc_ztnum.
        INSERT ls_check INTO TABLE mo_trace->mt_checks.
        ls_line-chect = '770001'.
        INSERT ls_line INTO TABLE mo_trace->mt_lines.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open
                                                          iv_key    = gc_key-d_cheque )
                                            exp = 2 msg = 'Two cheques uncashed' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-age_oldest
                                                          iv_key    = gc_key-d_cheque )
                                            exp = 61 msg = 'Calendar days from issue' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-warn_count
                                                          iv_key    = gc_key-d_cheque )
                                            exp = 1 msg = '60 days not late, 61 late' ).
        cl_abap_unit_assert=>assert_equals( act = late( is_result = ls_result iv_key = gc_key-d_cheque )-severity
                                            exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'Late cheque, not critical' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( ls_result-metrics[ dim1 = 'CCHQ' ] ) )
          msg = 'Collection cheques are not watched' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: nothing in flight measures zero for every watched flow / class (DWIR CWIR DACH CACH DCHQ)
  METHOD empty_data_measures_zero.
    TRY.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-metrics ) exp = 20 msg = 'Four metrics x five keys' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'Nothing to report' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a payment method in two classes is a configuration error (PLUGIN_ERROR), never a guess
  METHOD method_in_two_classes_raises.
    mo_params->set( iv_name = zif_cd_hck_runtime_types=>gc_param-inflight_ach iv_value = |{ gc_ach },{ gc_wire }| ).
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'Ambiguous mapping must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Configuration error raised' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a watched key without limits is not judged (warning); a class without methods is listed
  METHOD limits_missing_warns.
    TRY.
        DELETE mt_thresholds WHERE bukrs = gc_key-c_wire.
        mo_params->set( iv_name = zif_cd_hck_runtime_types=>gc_param-inflight_ach iv_value = space ).
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday iv_collection = abap_true ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-limits_missing ]-severity OPTIONAL )
          exp = zif_cd_ops_types=>gc_severity-warning
          msg = 'Limits missing: warning' ).
        cl_abap_unit_assert=>assert_initial( act = late( is_result = ls_result iv_key = gc_key-c_wire )
                                             msg = 'Not judged without limits' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result
                                                          iv_metric = zcl_cd_hck_c_inflight=>gc_metric-open
                                                          iv_key    = gc_key-c_wire )
                                            exp = 1 msg = 'Still counted' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-inflight_config
                                                          severity   = zif_cd_ops_types=>gc_severity-info ] ) )
          msg = 'ACH not monitored: listed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a read that reaches HCK_INFLIGHT_MAX_ROWS is reported; PARAM4 limits the listed payments
  METHOD read_cap_and_top_n.
    TRY.
        mo_params->set( iv_name = zif_cd_hck_runtime_types=>gc_param-inflight_max_rows iv_value = '2' ).
        add_payment( iv_doc = gc_doc1 iv_valut = gc_friday ).
        add_payment( iv_doc = gc_doc2 iv_valut = gc_friday ).
        DATA(ls_result) = act( iv_top_n = '1' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-read_capped ] ) )
          msg = 'Cap reached: reported' ).
        SPLIT late( ls_result )-details AT cl_abap_char_utilities=>newline INTO TABLE DATA(lt_lines).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 1 msg = 'Top 1 listed' ).
        cl_abap_unit_assert=>assert_equals( act = metric( is_result = ls_result iv_metric = zcl_cd_hck_c_inflight=>gc_metric-warn_count )
                                            exp = 2 msg = 'Counts are complete' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
