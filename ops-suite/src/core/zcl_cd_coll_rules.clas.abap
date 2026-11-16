*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_coll_rules.clas.abap
*& Purpose:
*& Shared rules of the collections request checks (process CD_COLL /
*& BASE_REQ_LIFE, build R): the request status source (COLL_SRC_REQUEST)
*& and the refund log (COLL_SRC_REFUND) as source specifications read
*& through the DDIC-validated, approved configured-source reader of the
*& payment trace (no SQL here); the latest status of each request (last row
*& by DATE, TIME - the source may keep one row per request or per change);
*& hours since the status change (local time FMON_TIME_ZONE); limits in
*& hours (D-PO3); item findings with request key, company code, amount,
*& currency, age, deadline and the control; a capped read is partial. A
*& source, value or limit still blank or a placeholder raises: no verdict.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Collections request checks - shared rules</p>
CLASS zcl_cd_coll_rules DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! @raising zcx_ca_ops_error | the request status source is not configured
    METHODS constructor
      IMPORTING
        is_check   TYPE zif_ca_ops_chk_types=>ty_check
        is_context TYPE zif_ca_ops_chk_types=>ty_context
      RAISING
        zcx_ca_ops_error.

    "! Requests whose latest status is iv_status (window COLL_LOOKBACK_DAYS up to today)
    METHODS requests_in
      IMPORTING
        iv_status          TYPE clike
      RETURNING
        VALUE(rt_requests) TYPE zif_cd_coll_types=>tt_request
      RAISING
        zcx_ca_ops_error.

    "! The read reached COLL_MAX_ROWS: the check is partial
    METHODS capped
      RETURNING
        VALUE(rv_capped) TYPE abap_bool.

    "! Finding of the capped read (information), for the result of a partial check
    METHODS capped_finding
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! A parameter value; blank or a placeholder raises (not configured)
    "! @raising zcx_ca_ops_error | message 904
    METHODS required
      IMPORTING
        iv_name         TYPE zif_ca_ops_types=>ty_param_name
      RETURNING
        VALUE(rv_value) TYPE string
      RAISING
        zcx_ca_ops_error.

    "! Amber / red limits in hours; 0 or red below amber raises (not configured)
    "! @raising zcx_ca_ops_error | message 904
    METHODS limits
      IMPORTING
        iv_amber         TYPE zif_ca_ops_types=>ty_param_name
        iv_red           TYPE zif_ca_ops_types=>ty_param_name
      RETURNING
        VALUE(rs_limits) TYPE zif_cd_coll_types=>ty_limits
      RAISING
        zcx_ca_ops_error.

    "! A source specification of a parameter; TABLE, KEY, STATUS and DATE must be set
    "! @raising zcx_ca_ops_error | message 904
    METHODS source
      IMPORTING
        iv_name          TYPE zif_ca_ops_types=>ty_param_name
      RETURNING
        VALUE(rs_source) TYPE zif_cd_ops_trace_types=>ty_source_cfg
      RAISING
        zcx_ca_ops_error.

    "! Finding of one request (company code, amount, currency, age in hours, deadline, control)
    METHODS item_finding
      IMPORTING
        is_request        TYPE zif_cd_coll_types=>ty_request
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
        iv_severity       TYPE zif_ca_ops_types=>ty_severity
        iv_message        TYPE string
        iv_limit_h        TYPE i
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! Item of the exposure per currency of one request
    METHODS item_of
      IMPORTING
        is_request     TYPE zif_cd_coll_types=>ty_request
        iv_limit_h     TYPE i
      RETURNING
        VALUE(rs_item) TYPE zif_cd_hck_cheque_types=>ty_item.

    "! Severity of an age in hours: E from red, W from amber, blank below
    CLASS-METHODS severity_of
      IMPORTING
        iv_hours           TYPE i
        is_limits          TYPE zif_cd_coll_types=>ty_limits
      RETURNING
        VALUE(rv_severity) TYPE zif_ca_ops_types=>ty_severity.

  PRIVATE SECTION.
    DATA ms_check TYPE zif_ca_ops_chk_types=>ty_check.
    DATA ms_context TYPE zif_ca_ops_chk_types=>ty_context.
    DATA mo_params TYPE REF TO zif_ca_ops_params.
    DATA ms_source TYPE zif_cd_ops_trace_types=>ty_source_cfg.
    DATA mv_time_zone TYPE tznzone.
    DATA mv_currency TYPE zif_ca_ops_types=>ty_currency.
    DATA mv_days TYPE i.
    DATA mv_max TYPE i.
    DATA mv_capped TYPE abap_bool.
    DATA mv_from TYPE d.

    "! Positive integer parameter, else the default
    METHODS int
      IMPORTING
        iv_name         TYPE zif_ca_ops_types=>ty_param_name
        iv_default      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

ENDCLASS.



CLASS zcl_cd_coll_rules IMPLEMENTATION.

  METHOD constructor.
    ms_check   = is_check.
    ms_context = is_context.
    mo_params  = zcl_cd_ops_factory=>get_params( ).
    ms_source  = source( zif_cd_coll_types=>gc_param-src_request ).
    mv_time_zone = mo_params->get_param( iv_name    = zif_cd_fmon_types=>gc_param-time_zone
                                         iv_default = CONV #( zif_ca_ops_types=>gc_time_zone_utc ) ).
    mv_currency = to_upper( mo_params->get_param( zif_cd_coll_types=>gc_param-currency ) ).
    IF zcl_cd_hck_exposure=>is_unset( mv_currency ) = abap_true.
      CLEAR mv_currency.
    ENDIF.
    mv_days = int( iv_name = zif_cd_coll_types=>gc_param-lookback iv_default = zif_cd_coll_types=>gc_default-lookback ).
    mv_max  = int( iv_name = zif_cd_coll_types=>gc_param-max_rows iv_default = zif_cd_coll_types=>gc_default-max_rows ).
  ENDMETHOD.


  METHOD requests_in.
    DATA lv_at TYPE timestampl.
    DATA(lv_today) = ms_context-today.
    mv_from = lv_today - mv_days.
    " Ordered by DATE, TIME, KEY: the last row of a request is its latest status
    DATA(lt_rows) = zcl_cd_ops_factory=>get_trace_dao( )->read_configured_after( is_source   = ms_source
                                                                                 is_after    = VALUE #( date = mv_from )
                                                                                 iv_date_to  = lv_today
                                                                                 iv_max_rows = mv_max ).
    mv_capped = xsdbool( lines( lt_rows ) >= mv_max ).
    DATA(lv_status) = to_upper( condense( CONV string( iv_status ) ) ).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_on) = zcl_cd_ops_trace_engine=>to_date( <ls_row>-ev_date ).
      DATA(lv_time) = zcl_cd_ops_trace_engine=>to_time( <ls_row>-ev_time ).
      CONVERT DATE lv_on TIME lv_time INTO TIME STAMP lv_at TIME ZONE mv_time_zone.
      DATA(ls_new) = VALUE zif_cd_coll_types=>ty_request(
                       key        = condense( <ls_row>-key1 )
                       bukrs      = condense( <ls_row>-key2 )
                       status     = to_upper( condense( CONV string( <ls_row>-status ) ) )
                       changed_on = lv_on
                       changed_at = lv_at
                       amount     = zcl_ca_ops_util=>to_decimal( <ls_row>-amount ) ).
      ls_new-hours = nmax( val1 = 0
                           val2 = cl_abap_tstmp=>subtract( tstmp1 = ms_context-now tstmp2 = lv_at )
                                  DIV zif_cd_coll_types=>gc_seconds_per_hour ).
      MODIFY TABLE rt_requests FROM ls_new.
      IF sy-subrc <> 0.
        INSERT ls_new INTO TABLE rt_requests.
      ENDIF.
    ENDLOOP.
    DELETE rt_requests WHERE status <> lv_status.
  ENDMETHOD.


  METHOD capped.
    rv_capped = mv_capped.
  ENDMETHOD.


  METHOD capped_finding.
    rs_finding = VALUE #( object_key = ms_check-check_id
                          check_code = zif_cd_coll_types=>gc_code-read_capped
                          severity   = zif_ca_ops_types=>gc_severity-warning
                          action     = zif_ca_ops_types=>gc_action-notify
                          message    = zcl_cd_ops_util=>text( iv_msgno = zif_cd_coll_types=>gc_msg-read_capped
                                                              iv_v1    = ms_check-check_id
                                                              iv_v2    = mv_max
                                                              iv_v3    = mv_from
                                                              iv_v4    = ms_context-today ) ).
  ENDMETHOD.


  METHOD required.
    rv_value = condense( mo_params->get_param( iv_name ) ).
    IF zcl_cd_hck_exposure=>is_unset( rv_value ) = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e904(zcd_ops) WITH ms_check-check_id iv_name.
    ENDIF.
  ENDMETHOD.


  METHOD limits.
    rs_limits-amber = int( iv_name = iv_amber iv_default = 0 ).
    rs_limits-red   = int( iv_name = iv_red iv_default = 0 ).
    IF rs_limits-amber <= 0 OR rs_limits-red < rs_limits-amber.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e904(zcd_ops) WITH ms_check-check_id iv_amber.
    ENDIF.
  ENDMETHOD.


  METHOD source.
    DATA(lv_spec) = mo_params->get_param( iv_name ).
    rs_source = zcl_cd_ops_trace_engine=>parse_source( iv_param = iv_name iv_spec = lv_spec ).
    IF zcl_cd_hck_exposure=>is_unset( lv_spec ) = abap_true
       OR rs_source-table_name IS INITIAL OR rs_source-key_field IS INITIAL
       OR rs_source-status_field IS INITIAL OR rs_source-date_field IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e904(zcd_ops) WITH ms_check-check_id iv_name.
    ENDIF.
  ENDMETHOD.


  METHOD item_of.
    rs_item = VALUE #( object_key = is_request-key
                       bukrs      = is_request-bukrs
                       amount     = is_request-amount
                       currency   = mv_currency
                       age        = is_request-hours
                       event_date = is_request-changed_on
                       deadline   = COND #( WHEN iv_limit_h > 0
                                            THEN is_request-changed_on + ( iv_limit_h + 23 ) DIV 24 ) ).
  ENDMETHOD.


  METHOD item_finding.
    DATA(ls_item) = item_of( is_request = is_request iv_limit_h = iv_limit_h ).
    rs_finding = VALUE #( object_key    = is_request-key
                          check_code    = iv_code
                          severity      = iv_severity
                          action        = zif_ca_ops_types=>gc_action-exception
                          reference     = is_request-key
                          amount        = is_request-amount
                          currency      = mv_currency
                          company_code  = is_request-bukrs
                          business_date = is_request-changed_on
                          event_at      = is_request-changed_at
                          item_count    = 1
                          message       = iv_message
                          context       = zcl_cd_hck_exposure=>context( is_item     = ls_item
                                                                        iv_control  = zif_cd_coll_types=>gc_control
                                                                        iv_evidence = is_request-key
                                                                        iv_in_hours = abap_true ) ).
  ENDMETHOD.


  METHOD severity_of.
    rv_severity = COND #( WHEN iv_hours >= is_limits-red THEN zif_ca_ops_types=>gc_severity-error
                          WHEN iv_hours >= is_limits-amber THEN zif_ca_ops_types=>gc_severity-warning ).
  ENDMETHOD.


  METHOD int.
    rv_value = zcl_cd_hck_param=>int( iv_value = mo_params->get_param( iv_name ) iv_default = iv_default ).
  ENDMETHOD.

ENDCLASS.
