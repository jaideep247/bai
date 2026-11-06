*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_calendar.clas.abap
*& Purpose:
*& Thin wrapper over the standard factory calendar function modules
*& DATE_CONVERT_TO_FACTORYDATE / FACTORYDATE_CONVERT_TO_DATE. The only
*& FMON class that calls them; deliberately not unit tested (see doc).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - factory calendar (FM wrapper)</p>
CLASS zcl_cd_fmon_calendar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_calendar.

  PRIVATE SECTION.
    "! VERIFY-DDIC: SCAL-FACDATE is the factory-date type of the FM parameters
    TYPES ty_factory_date TYPE scal-facdate.

    "! iv_correct '+' = next working day, '-' = previous working day
    METHODS to_factory_date
      IMPORTING
        iv_date            TYPE d
        iv_calendar_id     TYPE zif_cd_fmon_types=>ty_fcal_id
        iv_correct         TYPE c
      EXPORTING
        ev_factory_date    TYPE ty_factory_date
        ev_working_day     TYPE abap_bool
      RAISING
        zcx_cd_ops_error.

    METHODS to_date
      IMPORTING
        iv_factory_date TYPE ty_factory_date
        iv_calendar_id  TYPE zif_cd_fmon_types=>ty_fcal_id
      RETURNING
        VALUE(rv_date)  TYPE d
      RAISING
        zcx_cd_ops_error.

ENDCLASS.



CLASS zcl_cd_fmon_calendar IMPLEMENTATION.

  METHOD zif_cd_fmon_calendar~is_working_day.
    to_factory_date( EXPORTING iv_date        = iv_date
                               iv_calendar_id = iv_calendar_id
                               iv_correct     = '+'
                     IMPORTING ev_working_day = rv_working ).
  ENDMETHOD.


  METHOD zif_cd_fmon_calendar~is_month_end.
    DATA lv_factory_date TYPE ty_factory_date.
    DATA lv_working TYPE abap_bool.

    to_factory_date( EXPORTING iv_date         = iv_date
                               iv_calendar_id  = iv_calendar_id
                               iv_correct      = '+'
                     IMPORTING ev_factory_date = lv_factory_date
                               ev_working_day  = lv_working ).
    IF lv_working = abap_false.
      RETURN.
    ENDIF.
    DATA(lv_next) = to_date( iv_factory_date = lv_factory_date + 1
                             iv_calendar_id  = iv_calendar_id ).
    rv_month_end = xsdbool( lv_next+4(2) <> iv_date+4(2) ).
  ENDMETHOD.


  METHOD zif_cd_fmon_calendar~working_days_between.
    DATA lv_from TYPE ty_factory_date.
    DATA lv_to TYPE ty_factory_date.

    IF iv_to <= iv_from.
      RETURN.
    ENDIF.
    to_factory_date( EXPORTING iv_date         = iv_from
                               iv_calendar_id  = iv_calendar_id
                               iv_correct      = '+'
                     IMPORTING ev_factory_date = lv_from ).
    to_factory_date( EXPORTING iv_date         = iv_to
                               iv_calendar_id  = iv_calendar_id
                               iv_correct      = '-'
                     IMPORTING ev_factory_date = lv_to ).
    rv_days = nmax( val1 = 0 val2 = lv_to - lv_from ).
  ENDMETHOD.


  METHOD to_factory_date.
    DATA lv_indicator TYPE c LENGTH 1.

    CLEAR: ev_factory_date, ev_working_day.
    "VERIFY-DDIC: parameter names of DATE_CONVERT_TO_FACTORYDATE (SE37 before transport)
    CALL FUNCTION 'DATE_CONVERT_TO_FACTORYDATE'
      EXPORTING
        correct_option       = iv_correct
        date                 = iv_date
        factory_calendar_id  = iv_calendar_id
      IMPORTING
        factorydate          = ev_factory_date
        workingday_indicator = lv_indicator
      EXCEPTIONS
        error_message        = 98
        OTHERS               = 99.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e206(zcd_ops) WITH iv_calendar_id iv_date.
    ENDIF.
    " Indicator is blank on a working day, '+' / '-' when the date was moved
    ev_working_day = xsdbool( lv_indicator IS INITIAL ).
  ENDMETHOD.


  METHOD to_date.
    "VERIFY-DDIC: parameter names of FACTORYDATE_CONVERT_TO_DATE (SE37 before transport)
    CALL FUNCTION 'FACTORYDATE_CONVERT_TO_DATE'
      EXPORTING
        factorydate         = iv_factory_date
        factory_calendar_id = iv_calendar_id
      IMPORTING
        date                = rv_date
      EXCEPTIONS
        error_message       = 98
        OTHERS              = 99.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e206(zcd_ops) WITH iv_calendar_id iv_factory_date.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
