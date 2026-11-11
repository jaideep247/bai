*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_time.clas.abap
*& Purpose:
*& Points in server time of the SAP job monitor (TBTCO keeps date and time
*& of the application server): order, minutes between, a point moved by
*& minutes, the created / start / end point of a job, whether a job ran at
*& a point, the server clock now (ZIF_CA_OPS_CLOCK). Pure logic, no SQL.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - SAP job monitor time points</p>
CLASS zcl_ca_ops_job_time DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! The server clock now (date and time of the application server, as TBTCO)
    CLASS-METHODS now
      RETURNING
        VALUE(rs_point) TYPE zif_ca_ops_job_types=>ty_point.

    "! Seconds since 0001-01-01 00:00:00 (a total order of points)
    CLASS-METHODS seconds
      IMPORTING
        is_point          TYPE zif_ca_ops_job_types=>ty_point
      RETURNING
        VALUE(rv_seconds) TYPE int8.

    "! The point moved by iv_minutes (negative = earlier)
    CLASS-METHODS add_minutes
      IMPORTING
        is_point        TYPE zif_ca_ops_job_types=>ty_point
        iv_minutes      TYPE i
      RETURNING
        VALUE(rs_point) TYPE zif_ca_ops_job_types=>ty_point.

    "! Whole minutes from the first point to the second (negative when the second is earlier)
    CLASS-METHODS minutes_between
      IMPORTING
        is_from           TYPE zif_ca_ops_job_types=>ty_point
        is_to             TYPE zif_ca_ops_job_types=>ty_point
      RETURNING
        VALUE(rv_minutes) TYPE i.

    "! The first point is not later than the second
    CLASS-METHODS not_after
      IMPORTING
        is_first        TYPE zif_ca_ops_job_types=>ty_point
        is_second       TYPE zif_ca_ops_job_types=>ty_point
      RETURNING
        VALUE(rv_result) TYPE abap_bool.

    "! The earlier of two points
    CLASS-METHODS earlier
      IMPORTING
        is_first        TYPE zif_ca_ops_job_types=>ty_point
        is_second       TYPE zif_ca_ops_job_types=>ty_point
      RETURNING
        VALUE(rs_point) TYPE zif_ca_ops_job_types=>ty_point.

    "! The point a job was created (scheduled), started and ended
    CLASS-METHODS created
      IMPORTING
        is_job          TYPE zif_ca_ops_job_types=>ty_job
      RETURNING
        VALUE(rs_point) TYPE zif_ca_ops_job_types=>ty_point.
    CLASS-METHODS started
      IMPORTING
        is_job          TYPE zif_ca_ops_job_types=>ty_job
      RETURNING
        VALUE(rs_point) TYPE zif_ca_ops_job_types=>ty_point.
    CLASS-METHODS ended
      IMPORTING
        is_job          TYPE zif_ca_ops_job_types=>ty_job
      RETURNING
        VALUE(rs_point) TYPE zif_ca_ops_job_types=>ty_point.

    "! The job had started at the point and had not ended before it (an active job runs until iv_now)
    CLASS-METHODS ran_at
      IMPORTING
        is_job           TYPE zif_ca_ops_job_types=>ty_job
        is_point         TYPE zif_ca_ops_job_types=>ty_point
        is_now           TYPE zif_ca_ops_job_types=>ty_point
      RETURNING
        VALUE(rv_result) TYPE abap_bool.

    "! The job is active (running or put active)
    CLASS-METHODS is_active
      IMPORTING
        is_job           TYPE zif_ca_ops_job_types=>ty_job
      RETURNING
        VALUE(rv_result) TYPE abap_bool.

  PRIVATE SECTION.
    CONSTANTS gc_epoch TYPE d VALUE '00010101'.
    CONSTANTS gc_seconds_per_day TYPE i VALUE 86400.
    CONSTANTS gc_seconds_per_minute TYPE i VALUE 60.

ENDCLASS.



CLASS zcl_ca_ops_job_time IMPLEMENTATION.

  METHOD now.
    DATA(lo_clock) = zcl_ca_ops_factory=>get_clock( ).
    rs_point-date = lo_clock->today( ).
    rs_point-time = lo_clock->time( ).
  ENDMETHOD.


  METHOD seconds.
    DATA lv_days TYPE int8.
    DATA lv_time TYPE int8.
    IF is_point-date IS INITIAL.
      RETURN.
    ENDIF.
    lv_days = is_point-date - gc_epoch.
    lv_time = is_point-time.
    rv_seconds = lv_days * gc_seconds_per_day + lv_time.
  ENDMETHOD.


  METHOD add_minutes.
    DATA lv_total TYPE int8.
    DATA lv_days TYPE i.
    DATA lv_rest TYPE i.
    lv_total = seconds( is_point ) + iv_minutes * gc_seconds_per_minute.
    IF lv_total < 0.
      lv_total = 0.
    ENDIF.
    lv_days = lv_total DIV gc_seconds_per_day.
    lv_rest = lv_total MOD gc_seconds_per_day.
    rs_point-date = gc_epoch + lv_days.
    rs_point-time = lv_rest.
  ENDMETHOD.


  METHOD minutes_between.
    rv_minutes = ( seconds( is_to ) - seconds( is_from ) ) DIV gc_seconds_per_minute.
  ENDMETHOD.


  METHOD not_after.
    rv_result = xsdbool( seconds( is_first ) <= seconds( is_second ) ).
  ENDMETHOD.


  METHOD earlier.
    rs_point = COND #( WHEN not_after( is_first = is_first is_second = is_second ) THEN is_first ELSE is_second ).
  ENDMETHOD.


  METHOD created.
    rs_point = VALUE #( date = is_job-sdldate time = is_job-sdltime ).
  ENDMETHOD.


  METHOD started.
    rs_point = VALUE #( date = is_job-strtdate time = is_job-strttime ).
  ENDMETHOD.


  METHOD ended.
    rs_point = VALUE #( date = is_job-enddate time = is_job-endtime ).
  ENDMETHOD.


  METHOD ran_at.
    IF is_job-strtdate IS INITIAL
       OR not_after( is_first = started( is_job ) is_second = is_point ) = abap_false.
      RETURN.
    ENDIF.
    DATA(ls_end) = COND zif_ca_ops_job_types=>ty_point( WHEN is_active( is_job ) = abap_true OR is_job-enddate IS INITIAL
                                                         THEN is_now
                                                         ELSE ended( is_job ) ).
    rv_result = not_after( is_first = is_point is_second = ls_end ).
  ENDMETHOD.


  METHOD is_active.
    rv_result = xsdbool( is_job-status = zif_ca_ops_job_types=>gc_status-running
                         OR is_job-status = zif_ca_ops_job_types=>gc_status-put_active ).
  ENDMETHOD.

ENDCLASS.
