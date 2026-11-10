*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_request.clas.testclasses.abap
*& Purpose:
*& Unit tests of the payment request rule (due date and stage) with LTD
*& doubles of the trace repository (configured request log), the worklist
*& repository (items of a FIN with their payment run), the health check
*& repository (A_INFLIGHT calendar, C_PRQ_CANCEL rule, holidays), the clock
*& and the in-memory parameters: the SUCCESS row rule (any attempt), the
*& cut-off per source (19:00 default), the next business day, a future
*& request not overdue, every stage (no item, payment block, not in a
*& payment run, cleared without run, paid on time, paid late), a request
*& cancelled after SUCCESS (C_PRQ_CANCEL rule) and the watermark read of
*& new requests. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-08 | Initial version (requests not paid on their requested payment date).
*&---------------------------------------------------------------------*
CLASS ltd_trace_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_trace_dao PARTIALLY IMPLEMENTED.
    DATA mt_rows TYPE zif_cd_ops_trace_types=>tt_cfg_row.
ENDCLASS.

CLASS ltd_trace_dao IMPLEMENTATION.
  METHOD zif_cd_ops_trace_dao~read_configured_set.
    LOOP AT mt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF line_exists( it_keys[ table_line = <ls_row>-key1 ] ).
        INSERT <ls_row> INTO TABLE rt_rows.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_trace_dao~read_configured_after.
    rt_rows = mt_rows.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_outcome_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_outcome_dao PARTIALLY IMPLEMENTED.
    DATA mt_items TYPE zif_cd_ops_payout_types=>tt_req_item.
ENDCLASS.

CLASS ltd_outcome_dao IMPLEMENTATION.
  METHOD zif_cd_ops_pay_outcome_dao~get_request_items.
    LOOP AT mt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      IF line_exists( it_fin[ table_line = <ls_item>-fin ] ).
        INSERT <ls_item> INTO TABLE rt_items.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_hck_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_defs TYPE zif_cd_hck_types=>tt_check_def.
    DATA mt_holidays TYPE STANDARD TABLE OF d WITH EMPTY KEY.
ENDCLASS.

CLASS ltd_hck_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_check_defs.
    rt_defs = mt_defs.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~is_working_day.
    rv_working = xsdbool( NOT line_exists( mt_holidays[ table_line = iv_date ] ) ).
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock PARTIALLY IMPLEMENTED.
    CONSTANTS gc_today TYPE d VALUE '20261111'.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~today.
    rv_date = gc_today.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_request DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        now        TYPE zif_cd_ops_payout_types=>ty_timestamp VALUE '20261111120000',
        yesterday  TYPE d VALUE '20261110',
        today      TYPE d VALUE '20261111',
        tomorrow   TYPE d VALUE '20261112',
        saturday   TYPE d VALUE '20261114',
        sunday     TYPE d VALUE '20261115',
        monday     TYPE d VALUE '20261116',
        morning    TYPE t VALUE '090000',
        evening    TYPE t VALUE '193000',
        late_cut   TYPE string VALUE `ORCI=200000,*=190000`,
        cut_2000   TYPE t VALUE '200000',
        cut_1900   TYPE t VALUE '190000',
        fin        TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0000009300',
        fin2       TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0000009301',
        pclm       TYPE zif_cd_ops_trace_types=>ty_source VALUE 'PCLM',
        orci       TYPE zif_cd_ops_trace_types=>ty_source VALUE 'ORCI',
        success    TYPE c LENGTH 40 VALUE 'SUCCESS',
        failed     TYPE c LENGTH 40 VALUE 'FAILED',
        cancelled  TYPE c LENGTH 40 VALUE 'CANCELLED',
        spec       TYPE string VALUE `TABLE=ZCD_PAYM_REQ_LOG;KEY=ZZ_FIN;KEY2=SOURCE;STATUS=ZZ_STATUS;` &
                                     `DATE=ERDAT;TIME=ERZET;DUE=ZZ_PAYDT`,
        item       TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000930001',
        payment    TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000930002',
        block      TYPE c LENGTH 1 VALUE 'A',
        calendar   TYPE zif_cd_hck_types=>ty_param VALUE 'US',
        amount     TYPE zif_ca_ops_types=>ty_amount VALUE '-250.00',
        currency   TYPE zif_ca_ops_types=>ty_currency VALUE 'USD',
      END OF gc.

    DATA mo_trace TYPE REF TO ltd_trace_dao.
    DATA mo_out TYPE REF TO ltd_outcome_dao.
    DATA mo_hck TYPE REF TO ltd_hck_dao.
    DATA mo_params TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.

    METHODS success_any_attempt_tracked FOR TESTING.
    METHODS cutoff_moves_to_next_day    FOR TESTING.
    METHODS weekend_next_business_day   FOR TESTING.
    METHODS cutoff_per_source           FOR TESTING.
    METHODS future_request_not_overdue  FOR TESTING.
    METHODS stage_no_item_overdue       FOR TESTING.
    METHODS stage_payment_block         FOR TESTING.
    METHODS stage_not_in_payment_run    FOR TESTING.
    METHODS stage_cleared_without_run   FOR TESTING.
    METHODS paid_on_time_finished       FOR TESTING.
    METHODS paid_late_not_finished      FOR TESTING.
    METHODS cancelled_after_success     FOR TESTING.
    METHODS new_requests_after_mark     FOR TESTING.

    "! A request log attempt
    METHODS attempt
      IMPORTING
        iv_fin    TYPE zif_cd_ops_trace_types=>ty_fin DEFAULT gc-fin
        iv_source TYPE zif_cd_ops_trace_types=>ty_source DEFAULT gc-pclm
        iv_status TYPE clike DEFAULT gc-success
        iv_date   TYPE d DEFAULT gc-yesterday
        iv_time   TYPE t DEFAULT gc-morning
        iv_due    TYPE d DEFAULT gc-yesterday.

    "! An item of the FIN: open (no clearing document), cleared by a payment run of iv_laufd, or cleared
    "! without payment run (iv_laufd initial)
    METHODS item
      IMPORTING
        iv_augbl TYPE clike OPTIONAL
        iv_laufd TYPE d OPTIONAL
        iv_block TYPE clike OPTIONAL.

    METHODS act
      IMPORTING
        iv_source         TYPE zif_cd_ops_trace_types=>ty_source DEFAULT gc-pclm
      RETURNING
        VALUE(rs_request) TYPE zif_cd_ops_payout_types=>ty_request
      RAISING
        zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_request IMPLEMENTATION.

  METHOD setup.
    mo_trace = NEW #( ).
    mo_out = NEW #( ).
    mo_hck = NEW #( ).
    INSERT VALUE #( check_id = zif_cd_ops_payout_types=>gc_check-inflight param1 = gc-calendar ) INTO TABLE mo_hck->mt_defs.
    INSERT gc-saturday INTO TABLE mo_hck->mt_holidays.
    INSERT gc-sunday INTO TABLE mo_hck->mt_holidays.
    zcl_cd_ops_injector=>inject_trace_dao( mo_trace ).
    zcl_cd_ops_injector=>inject_pay_outcome_dao( mo_out ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    zcl_cd_hck_injector=>inject_dao( mo_hck ).
    mo_params = NEW zcl_cd_ops_param_seed( ).
    mo_params->set( iv_name = zif_cd_ops_trace_types=>gc_param-src_request iv_value = gc-spec ).
    zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_hck_injector=>reset( ).
    CLEAR: mo_trace, mo_out, mo_hck, mo_params.
  ENDMETHOD.


  METHOD attempt.
    INSERT VALUE #( key1    = iv_fin
                    key2    = iv_source
                    status  = iv_status
                    ev_date = iv_date
                    ev_time = iv_time
                    due     = iv_due ) INTO TABLE mo_trace->mt_rows.
  ENDMETHOD.


  METHOD item.
    INSERT VALUE #( fin      = gc-fin
                    opbel    = gc-item
                    augbl    = iv_augbl
                    spzah    = iv_block
                    amount   = gc-amount
                    currency = gc-currency
                    laufd    = iv_laufd ) INTO TABLE mo_out->mt_items.
  ENDMETHOD.


  METHOD act.
    DATA(lt_requests) = NEW zcl_cd_ops_pay_request( )->zif_cd_ops_pay_request~evaluate(
                          it_keys = VALUE #( ( fin = gc-fin source = iv_source ) )
                          iv_now  = gc-now ).
    rs_request = VALUE #( lt_requests[ 1 ] OPTIONAL ).
  ENDMETHOD.


  " Rule: a request is tracked when ANY attempt is SUCCESS (never the highest COUNTER); without a SUCCESS
  " attempt it is not a worklist request (failures: C_PRQ_NO_SPE)
  METHOD success_any_attempt_tracked.
    TRY.
        attempt( ).
        attempt( iv_status = gc-failed iv_time = gc-evening ).
        attempt( iv_fin = gc-fin2 iv_status = gc-failed ).
        DATA(lt_requests) = NEW zcl_cd_ops_pay_request( )->zif_cd_ops_pay_request~evaluate(
                              it_keys = VALUE #( ( fin = gc-fin source = gc-pclm ) ( fin = gc-fin2 source = gc-pclm ) )
                              iv_now  = gc-now ).
        cl_abap_unit_assert=>assert_false( act = lt_requests[ KEY by_key fin = gc-fin source = gc-pclm ]-finished
                                           msg = 'SUCCESS before a failed retry: tracked' ).
        cl_abap_unit_assert=>assert_true( act = lt_requests[ KEY by_key fin = gc-fin2 source = gc-pclm ]-finished
                                          msg = 'No SUCCESS: not tracked' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: received after the cut-off (19:00) on its requested date: due the next business day
  METHOD cutoff_moves_to_next_day.
    TRY.
        DATA(lo_cut) = NEW zcl_cd_ops_pay_request( ).
        cl_abap_unit_assert=>assert_equals( act = lo_cut->due_date( iv_requested     = gc-today
                                                                    iv_received_date = gc-today
                                                                    iv_received_time = gc-evening
                                                                    iv_cutoff        = gc-cut_1900 )
                                            exp = gc-tomorrow msg = 'After the cut-off: next day' ).
        cl_abap_unit_assert=>assert_equals( act = lo_cut->due_date( iv_requested     = gc-today
                                                                    iv_received_date = gc-today
                                                                    iv_received_time = gc-morning
                                                                    iv_cutoff        = gc-cut_1900 )
                                            exp = gc-today msg = 'Before the cut-off: the same day' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: due on a day that is no business day of the payment engine's calendar: the next business day
  METHOD weekend_next_business_day.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = NEW zcl_cd_ops_pay_request( )->due_date( iv_requested     = gc-saturday
                                                                                           iv_received_date = gc-today
                                                                                           iv_received_time = gc-morning
                                                                                           iv_cutoff        = gc-cut_1900 )
                                            exp = gc-monday msg = 'Saturday: Monday' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the cut-off is configurable per source (PAYOUT_REQ_CUTOFF SOURCE=HHMMSS, * = every other)
  METHOD cutoff_per_source.
    TRY.
        mo_params->set( iv_name = zif_cd_ops_payout_types=>gc_param-req_cutoff iv_value = gc-late_cut ).
        zcl_cd_ops_injector=>inject_params( mo_params->params( ) ).
        DATA(lo_cut) = NEW zcl_cd_ops_pay_request( ).
        cl_abap_unit_assert=>assert_equals( act = lo_cut->cutoff_of( gc-orci ) exp = gc-cut_2000 msg = 'ORCI 20:00' ).
        cl_abap_unit_assert=>assert_equals( act = lo_cut->cutoff_of( gc-pclm ) exp = gc-cut_1900 msg = 'Others 19:00' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a request for a future date is not overdue before its due date has passed
  METHOD future_request_not_overdue.
    TRY.
        attempt( iv_due = gc-tomorrow ).
        DATA(ls_request) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_request-due_date exp = gc-tomorrow msg = 'Due tomorrow' ).
        cl_abap_unit_assert=>assert_false( act = ls_request-overdue msg = 'Not overdue yet' ).
        cl_abap_unit_assert=>assert_false( act = ls_request-finished msg = 'Not paid yet' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no payment engine item for the FIN after the due date: stage PRQ_NO_ITEM, overdue
  METHOD stage_no_item_overdue.
    TRY.
        attempt( ).
        DATA(ls_request) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_request-stage exp = zif_cd_ops_payout_types=>gc_req_stage-no_item
                                            msg = 'No item' ).
        cl_abap_unit_assert=>assert_true( act = ls_request-overdue msg = 'Due yesterday: overdue' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an open item with a payment block: stage PRQ_PAYMENT_BLOCK
  METHOD stage_payment_block.
    TRY.
        attempt( ).
        item( iv_block = gc-block ).
        cl_abap_unit_assert=>assert_equals( act = act( )-stage exp = zif_cd_ops_payout_types=>gc_req_stage-payment_block
                                            msg = 'Blocked' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an open item without block: stage PRQ_NOT_IN_RUN; the item amount is the request's amount
  METHOD stage_not_in_payment_run.
    TRY.
        attempt( ).
        item( ).
        DATA(ls_request) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_request-stage exp = zif_cd_ops_payout_types=>gc_req_stage-not_in_run
                                            msg = 'Not in a payment run' ).
        cl_abap_unit_assert=>assert_equals( act = ls_request-amount exp = abs( gc-amount ) msg = 'Item amount' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an item cleared without a payment run (offset, reversal): stage PRQ_CLEARED_NO_RUN, overdue
  METHOD stage_cleared_without_run.
    TRY.
        attempt( ).
        item( iv_augbl = gc-payment ).
        DATA(ls_request) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_request-stage exp = zif_cd_ops_payout_types=>gc_req_stage-cleared_no_run
                                            msg = 'Cleared without payment run' ).
        cl_abap_unit_assert=>assert_true( act = ls_request-overdue msg = 'Not paid: overdue' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: cleared by a payment run on or before the due date: paid on time, finished (no worklist row)
  METHOD paid_on_time_finished.
    TRY.
        attempt( ).
        item( iv_augbl = gc-payment iv_laufd = gc-yesterday ).
        DATA(ls_request) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_request-stage exp = zif_cd_ops_payout_types=>gc_req_stage-paid
                                            msg = 'Paid' ).
        cl_abap_unit_assert=>assert_true( act = ls_request-finished msg = 'Finished' ).
        cl_abap_unit_assert=>assert_false( act = ls_request-overdue msg = 'Never overdue' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: paid in a payment run after the due date: PRQ_PAID_LATE (closes the exception, history kept)
  METHOD paid_late_not_finished.
    TRY.
        attempt( ).
        item( iv_augbl = gc-payment iv_laufd = gc-today ).
        DATA(ls_request) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_request-stage exp = zif_cd_ops_payout_types=>gc_req_stage-paid_late
                                            msg = 'Paid late' ).
        cl_abap_unit_assert=>assert_equals( act = ls_request-paid_date exp = gc-today msg = 'Run date of the payment' ).
        cl_abap_unit_assert=>assert_false( act = ls_request-overdue msg = 'Paid: not overdue any more' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (C_PRQ_CANCEL): a PCLM request cancelled after SUCCESS is not expected to be paid - finished
  METHOD cancelled_after_success.
    TRY.
        attempt( ).
        attempt( iv_status = gc-cancelled iv_time = gc-evening ).
        DATA(ls_request) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_request-stage exp = zif_cd_ops_payout_types=>gc_req_stage-cancelled
                                            msg = 'Cancelled' ).
        cl_abap_unit_assert=>assert_true( act = ls_request-finished msg = 'Not expected to be paid' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the REQUESTS source takes the SUCCESS attempts after the watermark; the watermark moves to the
  " last attempt read
  METHOD new_requests_after_mark.
    TRY.
        attempt( iv_time = gc-morning ).
        attempt( iv_fin = gc-fin2 iv_status = gc-failed iv_time = gc-evening ).
        DATA(ls_changes) = NEW zcl_cd_ops_pay_request( )->zif_cd_ops_pay_request~changes(
                             is_watermark = VALUE #( source = zif_cd_ops_payout_types=>gc_source-requests )
                             iv_max       = 100 ).
        cl_abap_unit_assert=>assert_equals( act = ls_changes-requests
                                            exp = VALUE zif_cd_ops_payout_types=>tt_req_key( ( fin = gc-fin source = gc-pclm ) )
                                            msg = 'The SUCCESS request only' ).
        cl_abap_unit_assert=>assert_equals( act = ls_changes-watermark-wm_time exp = gc-evening msg = 'Watermark at the last row' ).
        cl_abap_unit_assert=>assert_false( act = ls_changes-more msg = 'Nothing more' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
