*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_request.clas.abap
*& Purpose:
*& Due date and stage of payment requests (ZIF_CD_OPS_PAY_REQUEST, user
*& decision 2026-11-08). Request log rows come from the configured source
*& TRACE_SRC_REQUEST (TABLE / KEY = FIN / KEY2 = source / STATUS / DATE +
*& TIME = received / DUE = requested payment date / AMOUNT; names VERIFY-SE11,
*& read through the DDIC-validated, approved file monitoring reader): the
*& SUCCESS row rule (any attempt, never the highest COUNTER, value
*& TRACE_PRQ_SUCCESS), the cancellation rule of the morning report check
*& C_PRQ_CANCEL (PARAM2: cancelled status value and sources - a request
*& cancelled after SUCCESS is not expected to be paid). Due date = the
*& requested payment date (the received date when blank or earlier); a
*& request received after the cut-off of its source (PAYOUT_REQ_CUTOFF,
*& SOURCE=HHMMSS, default 19:00, time zone FMON_TIME_ZONE) on that day is
*& due the next day; a day that is no business day of the payment engine's
*& factory calendar (A_INFLIGHT PARAM1, ZCL_CD_HCK_PAY_AGEING) moves to the
*& next business day. Stage from the payment engine items of the FIN
*& (DFKKOP-ZZ_FIN_TRANS_NUM): none = PRQ_NO_ITEM; an open item with a
*& payment block (DFKKOP-SPZAH, VERIFY-SE11) = PRQ_PAYMENT_BLOCK; an open
*& item = PRQ_NOT_IN_RUN; every item cleared by a payment run (AUGBL with a
*& DPAYH run) = PRQ_PAID on or before the due date, else PRQ_PAID_LATE;
*& cleared otherwise = PRQ_CLEARED_NO_RUN. Overdue = not paid and the local
*& date is after the due date. One read of the request log and one of the
*& items per call; read-only.
*& Modification log:
*& 2026-11-08 | Initial version (requests not paid on their requested payment date).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment request - due date and stage</p>
"! Parameters (ZCA_PARAM): TRACE_SRC_REQUEST, TRACE_PRQ_SUCCESS, PAYOUT_REQ_CUTOFF (CD_OPS),
"! FMON_TIME_ZONE (CD_FMON). Check definitions read: A_INFLIGHT (PARAM1 calendar), C_PRQ_CANCEL
"! (PARAM2 cancellation).
CLASS zcl_cd_ops_pay_request DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_request.

    "! Due date of a request: the requested payment date (the received date when blank or earlier),
    "! the next day when received after the cut-off on that day, then the next business day
    METHODS due_date
      IMPORTING
        iv_requested     TYPE d
        iv_received_date TYPE d
        iv_received_time TYPE t
        iv_cutoff        TYPE t
      RETURNING
        VALUE(rv_due)    TYPE d.

    "! Cut-off of a source from PAYOUT_REQ_CUTOFF (SOURCE=HHMMSS list; * = every other source); a value
    "! that is no valid time falls back to the delivered 19:00
    METHODS cutoff_of
      IMPORTING
        iv_source        TYPE zif_cd_ops_trace_types=>ty_source
      RETURNING
        VALUE(rv_cutoff) TYPE t.

  PRIVATE SECTION.
    "! Days a due date may move forward to reach a business day (a calendar without any working day
    "! never loops for ever)
    CONSTANTS gc_max_roll_days TYPE i VALUE 31.
    "! Delivered cut-off (the last hourly disbursement run)
    CONSTANTS gc_default_cutoff TYPE t VALUE '190000'.
    "! No upper received date of a change read (FAST)
    CONSTANTS gc_open_date TYPE d VALUE '99991231'.

    DATA mv_rules_loaded TYPE abap_bool.
    DATA mv_loaded TYPE abap_bool.
    DATA ms_source TYPE zif_cd_ops_trace_types=>ty_source_cfg.
    DATA mv_success TYPE string.
    DATA mv_time_zone TYPE tznzone.
    DATA mv_calendar TYPE zif_cd_hck_types=>ty_calendar.
    DATA mt_cutoffs TYPE string_table.
    DATA ms_cancel TYPE zcl_cd_hck_c_prq_cancel=>ty_cancel_rule.
    DATA mo_calendar TYPE REF TO zcl_cd_hck_pay_ageing.

    "! Rules once per instance: cut-offs, time zone, calendar, cancellation rule (never raises)
    METHODS load_rules.

    "! The request source and its SUCCESS value once per instance
    "! @raising zcx_cd_ops_error | TRACE_SRC_REQUEST without TABLE, KEY, KEY2, STATUS or DATE
    METHODS load
      RAISING
        zcx_cd_ops_error.

    "! Stage, paid date, amount of one request from the items of its FIN
    METHODS judge
      IMPORTING
        it_items    TYPE zif_cd_ops_payout_types=>tt_req_item
      CHANGING
        cs_request  TYPE zif_cd_ops_payout_types=>ty_request.

    CLASS-METHODS same
      IMPORTING
        iv_left        TYPE clike
        iv_right       TYPE clike
      RETURNING
        VALUE(rv_same) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_ops_pay_request IMPLEMENTATION.

  METHOD load.
    load_rules( ).
    IF mv_loaded = abap_true.
      RETURN.
    ENDIF.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    ms_source = zcl_cd_ops_trace_engine=>parse_source(
                  iv_param = zif_cd_ops_trace_types=>gc_param-src_request
                  iv_spec  = lo_params->get_param( zif_cd_ops_trace_types=>gc_param-src_request ) ).
    IF ms_source-table_name IS INITIAL OR ms_source-key_field IS INITIAL OR ms_source-key2_field IS INITIAL
       OR ms_source-status_field IS INITIAL OR ms_source-date_field IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e703(zcd_ops) WITH zif_cd_ops_trace_types=>gc_param-src_request.
    ENDIF.
    mv_success = to_upper( condense( CONV string( lo_params->get_param(
                                                    iv_name    = zif_cd_ops_trace_types=>gc_param-success_value
                                                    iv_default = zif_cd_ops_trace_types=>gc_default-success_value ) ) ) ).
    mv_loaded = abap_true.
  ENDMETHOD.


  METHOD load_rules.
    IF mv_rules_loaded = abap_true.
      RETURN.
    ENDIF.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    mt_cutoffs = zcl_cd_hck_ev_support=>tokens(
                   lo_params->get_param( iv_name    = zif_cd_ops_payout_types=>gc_param-req_cutoff
                                         iv_default = zif_cd_ops_payout_types=>gc_param_default-req_cutoff ) ).
    " The payment engine's local time (the FMON BAI deadlines use the same) and factory calendar
    mv_time_zone = lo_params->get_param( iv_name    = zif_cd_fmon_types=>gc_param-time_zone
                                         iv_default = CONV #( zif_cd_ops_types=>gc_time_zone_utc ) ).
    DATA(lo_hck) = zcl_cd_hck_factory=>get_dao( ).
    DATA(lt_defs) = lo_hck->get_check_defs(
                      it_check_ids = VALUE #( sign   = zif_cd_ops_types=>gc_range-sign_include
                                              option = zif_cd_ops_types=>gc_range-option_equal
                                              ( low = zif_cd_ops_payout_types=>gc_check-inflight )
                                              ( low = zif_cd_ops_payout_types=>gc_check-prq_cancel ) ) ).
    mv_calendar = to_upper( condense( VALUE #( lt_defs[ check_id = zif_cd_ops_payout_types=>gc_check-inflight ]-param1
                                               OPTIONAL ) ) ).
    ms_cancel = zcl_cd_hck_c_prq_cancel=>cancel_rule(
                  VALUE #( lt_defs[ check_id = zif_cd_ops_payout_types=>gc_check-prq_cancel ]-param2 OPTIONAL ) ).
    mo_calendar = NEW #( it_classes    = VALUE #( )
                         it_banks      = VALUE #( )
                         it_watched    = VALUE #( )
                         iv_calendar   = mv_calendar
                         it_thresholds = VALUE #( )
                         iv_today      = zcl_cd_ops_factory=>get_clock( )->today( ) ).
    mv_rules_loaded = abap_true.
  ENDMETHOD.


  METHOD zif_cd_ops_pay_request~changes.
    load( ).
    rs_changes-watermark = is_watermark.
    IF iv_max <= 0.
      RETURN.
    ENDIF.
    " Keyset on received date, time, FIN (the read is ordered so); every attempt is read, the SUCCESS
    " ones become requests (a request whose SUCCESS attempt comes later is picked up then)
    DATA(lt_rows) = zcl_cd_ops_factory=>get_trace_dao( )->read_configured_after(
                      is_source   = ms_source
                      is_after    = VALUE #( date = is_watermark-wm_date
                                             time = is_watermark-wm_time
                                             key  = is_watermark-wm_key )
                      iv_date_to  = COND #( WHEN iv_to IS INITIAL THEN gc_open_date ELSE iv_to )
                      iv_max_rows = iv_max ).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF same( iv_left = <ls_row>-status iv_right = mv_success ) = abap_true.
        INSERT VALUE #( fin    = condense( <ls_row>-key1 )
                        source = to_upper( condense( <ls_row>-key2 ) ) ) INTO TABLE rs_changes-requests.
      ENDIF.
      rs_changes-watermark-wm_date = zcl_cd_ops_trace_engine=>to_date( <ls_row>-ev_date ).
      rs_changes-watermark-wm_time = zcl_cd_ops_trace_engine=>to_time( <ls_row>-ev_time ).
      rs_changes-watermark-wm_key  = <ls_row>-key1.
    ENDLOOP.
    rs_changes-more = xsdbool( lines( lt_rows ) >= iv_max ).
  ENDMETHOD.


  METHOD zif_cd_ops_pay_request~evaluate.
    DATA lt_keys TYPE zif_cd_ops_trace_types=>tt_key_value.
    DATA lt_fin TYPE zif_cd_ops_payout_types=>tt_fin.
    DATA lv_today TYPE d.
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.
    load( ).
    LOOP AT it_keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      INSERT CONV #( <ls_key>-fin ) INTO TABLE lt_keys.
      INSERT <ls_key>-fin INTO TABLE lt_fin.
    ENDLOOP.
    " Every attempt of the FIN numbers in one read; a capped read could hide a SUCCESS or a
    " cancellation: fail closed (the caller writes nothing)
    DATA(lv_cap) = lines( lt_keys ) * zif_cd_ops_payout_types=>gc_max_attempts.
    DATA(lt_rows) = zcl_cd_ops_factory=>get_trace_dao( )->read_configured_set( is_source   = ms_source
                                                                              it_keys     = lt_keys
                                                                              iv_max_rows = lv_cap ).
    IF lines( lt_rows ) >= lv_cap.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e379(zcd_ops) WITH ms_source-table_name lv_cap zif_cd_ops_payout_types=>gc_context.
    ENDIF.
    DATA(lt_items) = zcl_cd_ops_factory=>get_pay_outcome_dao( )->get_request_items( lt_fin ).
    " The local date of the payment engine (the request is overdue once its due date has passed)
    CONVERT TIME STAMP iv_now TIME ZONE mv_time_zone INTO DATE lv_today.

    LOOP AT it_keys ASSIGNING <ls_key>.
      DATA(ls_request) = VALUE zif_cd_ops_payout_types=>ty_request( fin = <ls_key>-fin source = <ls_key>-source ).
      DATA(lv_tracked) = abap_false.
      DATA(lv_cancelled) = abap_false.
      LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
        IF same( iv_left = <ls_row>-key1 iv_right = <ls_key>-fin ) = abap_false
           OR same( iv_left = <ls_row>-key2 iv_right = <ls_key>-source ) = abap_false.
          CONTINUE.
        ENDIF.
        IF same( iv_left = <ls_row>-status iv_right = ms_cancel-value ) = abap_true
           AND line_exists( ms_cancel-sources[ table_line = to_upper( condense( CONV string( <ls_key>-source ) ) ) ] ).
          lv_cancelled = abap_true.
        ENDIF.
        IF same( iv_left = <ls_row>-status iv_right = mv_success ) = abap_false.
          CONTINUE.
        ENDIF.
        " Rule: any SUCCESS attempt makes the request processed by PRISM - the earliest one is the receipt
        DATA(lv_date) = zcl_cd_ops_trace_engine=>to_date( <ls_row>-ev_date ).
        DATA(lv_at) = zcl_cd_ops_trace_engine=>to_time( <ls_row>-ev_time ).
        IF lv_tracked = abap_false OR lv_date < ls_request-received_date
           OR ( lv_date = ls_request-received_date AND lv_at < ls_request-received_time ).
          ls_request-received_date = lv_date.
          ls_request-received_time = lv_at.
          ls_request-requested     = zcl_cd_ops_trace_engine=>to_date( <ls_row>-due ).
          ls_request-amount        = zcl_cd_ops_util=>to_decimal( <ls_row>-amount ).
        ENDIF.
        lv_tracked = abap_true.
      ENDLOOP.
      IF lv_tracked = abap_false.
        " No SUCCESS attempt: not a tracked request (a failure is C_PRQ_NO_SPE's), no worklist row
        ls_request-finished = abap_true.
        INSERT ls_request INTO TABLE rt_requests.
        CONTINUE.
      ENDIF.
      ls_request-cutoff   = cutoff_of( <ls_key>-source ).
      ls_request-due_date = due_date( iv_requested     = ls_request-requested
                                      iv_received_date = ls_request-received_date
                                      iv_received_time = ls_request-received_time
                                      iv_cutoff        = ls_request-cutoff ).
      IF lv_cancelled = abap_true.
        " Cancelled after SUCCESS (C_PRQ_CANCEL rule): money will not leave - not expected to be paid
        ls_request-stage    = zif_cd_ops_payout_types=>gc_req_stage-cancelled.
        ls_request-finished = abap_true.
        ls_request-text     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-req_cancelled
                                                     iv_v1    = ms_cancel-value ).
        INSERT ls_request INTO TABLE rt_requests.
        CONTINUE.
      ENDIF.
      judge( EXPORTING it_items   = VALUE #( FOR ls_item IN lt_items WHERE ( fin = <ls_key>-fin ) ( ls_item ) )
             CHANGING  cs_request = ls_request ).
      ls_request-finished = xsdbool( ls_request-stage = zif_cd_ops_payout_types=>gc_req_stage-paid ).
      ls_request-overdue  = xsdbool( ls_request-stage <> zif_cd_ops_payout_types=>gc_req_stage-paid
                                     AND ls_request-stage <> zif_cd_ops_payout_types=>gc_req_stage-paid_late
                                     AND lv_today > ls_request-due_date ).
      ls_request-text = |{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-req_evidence
                                                  iv_v1    = |{ ls_request-requested DATE = ISO }|
                                                  iv_v2    = |{ ls_request-received_date DATE = ISO }|
                                                  iv_v3    = |{ ls_request-received_time TIME = ISO }|
                                                  iv_v4    = |{ ls_request-due_date DATE = ISO }| ) } { ls_request-text }|.
      INSERT ls_request INTO TABLE rt_requests.
    ENDLOOP.
  ENDMETHOD.


  METHOD judge.
    DATA ls_open TYPE zif_cd_ops_payout_types=>ty_req_item.
    DATA ls_offset TYPE zif_cd_ops_payout_types=>ty_req_item.
    IF it_items IS INITIAL.
      cs_request-stage = zif_cd_ops_payout_types=>gc_req_stage-no_item.
      cs_request-text  = zcl_cd_ops_util=>text( zif_cd_ops_payout_types=>gc_msg-req_no_item ).
      RETURN.
    ENDIF.
    " The item amount replaces the request amount (one currency: the first item's)
    cs_request-amount   = 0.
    cs_request-currency = it_items[ 1 ]-currency.
    cs_request-bukrs    = it_items[ 1 ]-bukrs.
    LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      IF <ls_item>-currency = cs_request-currency.
        cs_request-amount = cs_request-amount + abs( <ls_item>-amount ).
      ENDIF.
      IF <ls_item>-augbl IS INITIAL.
        " Open: a blocked item is the stage reached (the block, not the run, holds it)
        IF ls_open IS INITIAL OR ( ls_open-spzah IS INITIAL AND <ls_item>-spzah IS NOT INITIAL ).
          ls_open = <ls_item>.
        ENDIF.
      ELSEIF <ls_item>-laufd IS INITIAL.
        ls_offset = <ls_item>.
      ELSEIF <ls_item>-laufd > cs_request-paid_date.
        " Paid when the last item is paid: the latest payment run of the items
        cs_request-paid_date = <ls_item>-laufd.
        cs_request-augbl     = <ls_item>-augbl.
      ENDIF.
    ENDLOOP.
    IF ls_open IS NOT INITIAL AND ls_open-spzah IS NOT INITIAL.
      cs_request-stage = zif_cd_ops_payout_types=>gc_req_stage-payment_block.
      cs_request-text  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-req_block
                                                iv_v1    = ls_open-opbel
                                                iv_v2    = ls_open-spzah ).
    ELSEIF ls_open IS NOT INITIAL.
      cs_request-stage = zif_cd_ops_payout_types=>gc_req_stage-not_in_run.
      cs_request-text  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-req_not_in_run
                                                iv_v1    = ls_open-opbel ).
    ELSEIF ls_offset IS NOT INITIAL.
      cs_request-stage = zif_cd_ops_payout_types=>gc_req_stage-cleared_no_run.
      cs_request-text  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-req_cleared
                                                iv_v1    = ls_offset-opbel
                                                iv_v2    = ls_offset-augbl ).
    ELSE.
      " Every item cleared by a payment run: paid - on time by the end of the due date, else late
      cs_request-stage = COND #( WHEN cs_request-paid_date <= cs_request-due_date
                                 THEN zif_cd_ops_payout_types=>gc_req_stage-paid
                                 ELSE zif_cd_ops_payout_types=>gc_req_stage-paid_late ).
      cs_request-text  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-req_paid
                                                iv_v1    = cs_request-augbl
                                                iv_v2    = |{ cs_request-paid_date DATE = ISO }| ).
    ENDIF.
  ENDMETHOD.


  METHOD due_date.
    rv_due = COND #( WHEN iv_requested IS INITIAL OR iv_requested < iv_received_date
                     THEN iv_received_date ELSE iv_requested ).
    " Received on the due day after the cut-off of its source: the last disbursement run has gone
    IF iv_received_date = rv_due AND iv_received_time > iv_cutoff.
      rv_due = rv_due + 1.
    ENDIF.
    load_rules( ).
    " Due on a day without disbursement run (weekend, holiday): the next business day
    DO gc_max_roll_days TIMES.
      IF mo_calendar->is_business_day( iv_calendar = mv_calendar iv_date = rv_due ) = abap_true.
        RETURN.
      ENDIF.
      rv_due = rv_due + 1.
    ENDDO.
  ENDMETHOD.


  METHOD cutoff_of.
    DATA lv_any TYPE t.
    load_rules( ).
    lv_any = gc_default_cutoff.
    LOOP AT mt_cutoffs ASSIGNING FIELD-SYMBOL(<lv_entry>).
      SPLIT <lv_entry> AT zif_cd_ops_payout_types=>gc_cutoff_sep INTO DATA(lv_source) DATA(lv_time).
      " HHMMSS digits only (the definition's pattern); anything else keeps the delivered cut-off
      DATA(lv_value) = zcl_cd_ops_trace_engine=>to_time( lv_time ).
      IF lv_value IS INITIAL AND condense( lv_time ) <> zif_cd_ops_types=>gc_time-day_start.
        CONTINUE.
      ENDIF.
      IF condense( lv_source ) = zif_cd_ops_payout_types=>gc_cutoff_any.
        lv_any = lv_value.
      ELSEIF same( iv_left = lv_source iv_right = iv_source ) = abap_true.
        rv_cutoff = lv_value.
        RETURN.
      ENDIF.
    ENDLOOP.
    rv_cutoff = lv_any.
  ENDMETHOD.


  METHOD same.
    rv_same = xsdbool( to_upper( condense( CONV string( iv_left ) ) ) = to_upper( condense( CONV string( iv_right ) ) ) ).
  ENDMETHOD.

ENDCLASS.
