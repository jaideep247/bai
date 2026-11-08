*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_prq_not_paid.clas.testclasses.abap
*& Purpose:
*& Unit tests of the morning report check A_PRQ_NOT_PAID with LTD doubles of
*& the worklist repository (due request rows with item sums, the NIGHTLYREQ
*& watermark) and the request rule (request amounts), core injector: one
*& finding per source + stage + due date with count, amount per currency and
*& examples, a request counted once although its items are in two
*& currencies, the request amount when the FIN has no item, zero measured
*& when nothing is due, the nightly re-evaluation not run today = warning
*& and evidence PARTIAL, a capped read = completion PARTIAL. Does not prove
*& live SAP runtime behavior.
*& Modification log:
*& 2026-11-08 | Initial version (requests not paid on their requested payment date).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_outcome_dao PARTIALLY IMPLEMENTED.
    DATA mt_rows TYPE zif_cd_ops_payout_types=>tt_due_request.
    DATA mt_watermarks TYPE zif_cd_ops_payout_types=>tt_watermark.
    DATA mv_before TYPE d.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_ops_pay_outcome_dao~get_due_requests.
    mv_before = iv_before.
    LOOP AT mt_rows ASSIGNING FIELD-SYMBOL(<ls_row>) TO iv_max.
      INSERT <ls_row> INTO TABLE rt_rows.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~get_watermarks.
    rt_watermarks = mt_watermarks.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_request DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_request PARTIALLY IMPLEMENTED.
    DATA mt_requests TYPE zif_cd_ops_payout_types=>tt_request.
ENDCLASS.

CLASS ltd_request IMPLEMENTATION.
  METHOD zif_cd_ops_pay_request~evaluate.
    LOOP AT mt_requests ASSIGNING FIELD-SYMBOL(<ls_request>).
      IF line_exists( it_keys[ fin = <ls_request>-fin source = <ls_request>-source ] ).
        INSERT <ls_request> INTO TABLE rt_requests.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_prq_not_paid DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        check     TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_PRQ_NOT_PAID',
        today     TYPE d VALUE '20261111',
        morning   TYPE t VALUE '070000',
        due       TYPE d VALUE '20261110',
        night     TYPE timestampl VALUE '20261111120000',
        day_old   TYPE timestampl VALUE '20261110020000',
        fin1      TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0000009401',
        fin2      TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0000009402',
        fin3      TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0000009403',
        pclm      TYPE zif_cd_ops_trace_types=>ty_source VALUE 'PCLM',
        orci      TYPE zif_cd_ops_trace_types=>ty_source VALUE 'ORCI',
        usd       TYPE zif_cd_ops_types=>ty_currency VALUE 'USD',
        eur       TYPE zif_cd_ops_types=>ty_currency VALUE 'EUR',
        amount    TYPE zif_cd_ops_types=>ty_amount VALUE '100.00',
        requested TYPE zif_cd_ops_types=>ty_amount VALUE '75.00',
        cap       TYPE string VALUE `2`,
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_request TYPE REF TO ltd_request.

    METHODS setup.
    METHODS teardown.

    METHODS one_finding_per_cell      FOR TESTING.
    METHODS request_counted_once      FOR TESTING.
    METHODS no_item_request_amount    FOR TESTING.
    METHODS nothing_due_measures_zero FOR TESTING.
    METHODS nightly_missing_partial   FOR TESTING.
    METHODS capped_read_partial       FOR TESTING.

    METHODS row
      IMPORTING
        iv_fin      TYPE zif_cd_ops_trace_types=>ty_fin
        iv_source   TYPE zif_cd_ops_trace_types=>ty_source DEFAULT gc-pclm
        iv_stage    TYPE zif_cd_ops_payout_types=>ty_req_stage DEFAULT zif_cd_ops_payout_types=>gc_req_stage-not_in_run
        iv_currency TYPE zif_cd_ops_types=>ty_currency DEFAULT gc-usd
        iv_amount   TYPE zif_cd_ops_types=>ty_amount DEFAULT gc-amount.

    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_prq_not_paid IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    mo_request = NEW #( ).
    " The nightly re-evaluation of the request rows ran tonight
    INSERT VALUE #( source = zif_cd_ops_payout_types=>gc_source-nightly_req current_to = gc-night )
      INTO TABLE mo_dao->mt_watermarks.
    zcl_cd_ops_injector=>inject_pay_outcome_dao( mo_dao ).
    zcl_cd_ops_injector=>inject_pay_request( mo_request ).
    zcl_cd_ops_injector=>inject_params( NEW zcl_cd_ops_param_seed( )->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_request.
  ENDMETHOD.


  METHOD row.
    INSERT VALUE #( fin_id   = iv_fin
                    source   = iv_source
                    outcome  = zif_cd_ops_payout_types=>gc_outcome-req_not_paid
                    stage    = iv_stage
                    due_date = gc-due
                    currency = iv_currency
                    amount   = iv_amount ) INTO TABLE mo_dao->mt_rows.
  ENDMETHOD.


  METHOD act.
    DATA ls_def TYPE zif_cd_hck_types=>ty_check_def.
    DATA ls_context TYPE zif_cd_hck_types=>ty_context.
    ls_def-check_id        = gc-check.
    ls_context-report_date = gc-today.
    ls_context-now_date    = gc-today.
    ls_context-now_time    = gc-morning.
    rs_result = NEW zcl_cd_hck_c_prq_not_paid( )->zif_cd_hck_check~execute( is_def        = ls_def
                                                                            it_thresholds = VALUE #( )
                                                                            is_context    = ls_context ).
  ENDMETHOD.


  " Rule: one finding per source + stage + due date (E, RED from the morning after the due date), with
  " the count and the amount per currency; requests due before today only
  METHOD one_finding_per_cell.
    TRY.
        row( gc-fin1 ).
        row( gc-fin2 ).
        row( iv_fin = gc-fin3 iv_source = gc-orci iv_stage = zif_cd_ops_payout_types=>gc_req_stage-payment_block ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_before exp = gc-today msg = 'Due before today' ).
        DATA(lt_findings) = VALUE zif_cd_ops_types=>tt_finding( FOR ls IN ls_result-findings
                                                                WHERE ( check_code = zif_cd_ops_payout_types=>gc_code-request_not_paid )
                                                                ( ls ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_findings ) exp = 2 msg = 'PCLM not in run, ORCI blocked' ).
        DATA(ls_pclm) = lt_findings[ group1 = gc-pclm ].
        cl_abap_unit_assert=>assert_equals( act = ls_pclm-severity exp = zif_cd_ops_types=>gc_severity-error msg = 'RED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_pclm-amount exp = gc-amount + gc-amount msg = 'Sum in one currency' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_pclm-object_key
          exp = |{ gc-check }/{ gc-pclm }/{ zif_cd_ops_payout_types=>gc_req_stage-not_in_run }/{ gc-due }|
          msg = 'Stable key: source / stage / due date' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( ls_result-metrics[ metric = zcl_cd_hck_c_prq_not_paid=>gc_metric
                                            dim1   = zif_cd_hck_types=>gc_default_key ]-value OPTIONAL )
          exp = 3 msg = 'Three requests in all' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a request whose FIN has items in two currencies counts once; both amounts are shown
  METHOD request_counted_once.
    TRY.
        row( gc-fin1 ).
        row( iv_fin = gc-fin1 iv_currency = gc-eur ).
        DATA(ls_result) = act( ).
        DATA(ls_finding) = ls_result-findings[ check_code = zif_cd_ops_payout_types=>gc_code-request_not_paid ].
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( ls_result-metrics[ metric = zcl_cd_hck_c_prq_not_paid=>gc_metric
                                            dim1   = zif_cd_hck_types=>gc_default_key ]-value OPTIONAL )
          exp = 1 msg = 'Counted once' ).
        cl_abap_unit_assert=>assert_initial( act = ls_finding-currency msg = 'Two currencies: never summed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without a payment engine item the request amount of the request log is reported
  METHOD no_item_request_amount.
    TRY.
        row( iv_fin = gc-fin1 iv_stage = zif_cd_ops_payout_types=>gc_req_stage-no_item
             iv_currency = space iv_amount = 0 ).
        INSERT VALUE #( fin = gc-fin1 source = gc-pclm amount = gc-requested ) INTO TABLE mo_request->mt_requests.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_result-findings[ check_code = zif_cd_ops_payout_types=>gc_code-request_not_paid ]-amount
          exp = gc-requested msg = 'Request amount' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: nothing due and unpaid measures zero - evidence of health, never an empty result
  METHOD nothing_due_measures_zero.
    TRY.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( VALUE zif_cd_hck_types=>tt_metric( FOR ls IN ls_result-metrics
                                                          WHERE ( metric = zcl_cd_hck_c_prq_not_paid=>gc_metric
                                                                  AND value = 0 ) ( ls ) ) )
          exp = 1 msg = 'Zero measured' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'No finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without tonight's re-evaluation a request due yesterday may be unjudged: warning, evidence PARTIAL
  METHOD nightly_missing_partial.
    TRY.
        mo_dao->mt_watermarks[ 1 ]-current_to = gc-day_old.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_ops_payout_types=>gc_code-nightly_missing ] ) )
          msg = 'Said' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-evidence exp = zif_cd_hck_types=>gc_evidence-partial
                                            msg = 'Evidence PARTIAL' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a read capped at HCK_INFLIGHT_MAX_ROWS is said (TECH_READ_CAPPED) and the completion PARTIAL
  METHOD capped_read_partial.
    TRY.
        DATA(lo_seed) = NEW zcl_cd_ops_param_seed( ).
        lo_seed->set( iv_name = zif_cd_hck_runtime_types=>gc_param-inflight_max_rows iv_value = gc-cap ).
        zcl_cd_ops_injector=>inject_params( lo_seed->params( ) ).
        row( gc-fin1 ).
        row( gc-fin2 ).
        row( gc-fin3 ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-completion exp = zif_cd_hck_types=>gc_completion-partial
                                            msg = 'Completion PARTIAL' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_hck_runtime_types=>gc_code-read_capped ] ) )
          msg = 'TECH_READ_CAPPED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
