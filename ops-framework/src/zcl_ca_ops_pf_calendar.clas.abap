*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_calendar.clas.abap
*& Purpose:
*& Delivered business calendar of the payment file lifecycle
*& (ZIF_CA_OPS_PF_CALENDAR, role CALENDAR): the SAP factory calendar of
*& the file type (ZCA_OPS_PFTYP-CALENDAR_ID, transaction SCAL) through
*& the function modules DATE_CONVERT_TO_FACTORYDATE and
*& FACTORYDATE_CONVERT_TO_DATE (parameter names VERIFY-SE37 V176, as the
*& first consumer's file monitoring). A blank calendar ID makes every day
*& a business day (a site without a calendar). Answers are cached per
*& instance. Read only.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file factory calendar</p>
CLASS zcl_ca_ops_pf_calendar DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_calendar.

  PRIVATE SECTION.
    TYPES ty_factory_date TYPE p LENGTH 3 DECIMALS 0.
    TYPES:
      BEGIN OF ty_cache,
        calendar_id TYPE zif_ca_ops_exc_contract=>ty_calendar_id,
        date        TYPE d,
        business    TYPE abap_bool,
      END OF ty_cache.
    DATA mt_cache TYPE HASHED TABLE OF ty_cache WITH UNIQUE KEY calendar_id date.

    "! Factory date of a date (moved forward to the next working day) and whether the date is one
    METHODS to_factory_date
      IMPORTING
        iv_calendar_id  TYPE zif_ca_ops_exc_contract=>ty_calendar_id
        iv_date         TYPE d
      EXPORTING
        ev_factory_date TYPE ty_factory_date
        ev_working      TYPE abap_bool
      RAISING
        zcx_ca_ops_error.

    METHODS to_date
      IMPORTING
        iv_calendar_id  TYPE zif_ca_ops_exc_contract=>ty_calendar_id
        iv_factory_date TYPE ty_factory_date
      RETURNING
        VALUE(rv_date)  TYPE d
      RAISING
        zcx_ca_ops_error.

ENDCLASS.



CLASS zcl_ca_ops_pf_calendar IMPLEMENTATION.

  METHOD zif_ca_ops_pf_adapter~configure.
    " no setting: the calendar ID is the file type's
  ENDMETHOD.


  METHOD zif_ca_ops_pf_calendar~is_business_day.
    IF iv_calendar_id IS INITIAL.
      rv_business = abap_true.
      RETURN.
    ENDIF.
    READ TABLE mt_cache WITH TABLE KEY calendar_id = iv_calendar_id date = iv_date ASSIGNING FIELD-SYMBOL(<ls_cache>).
    IF sy-subrc = 0.
      rv_business = <ls_cache>-business.
      RETURN.
    ENDIF.
    to_factory_date( EXPORTING iv_calendar_id = iv_calendar_id
                               iv_date        = iv_date
                     IMPORTING ev_working     = rv_business ).
    INSERT VALUE #( calendar_id = iv_calendar_id date = iv_date business = rv_business ) INTO TABLE mt_cache.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_calendar~add_business_days.
    DATA lv_factory TYPE ty_factory_date.
    IF iv_calendar_id IS INITIAL.
      rv_date = iv_date + nmax( val1 = 0 val2 = iv_days ).
      RETURN.
    ENDIF.
    " a non-working date moves to the next working day first (correct option +), then n working days on
    to_factory_date( EXPORTING iv_calendar_id  = iv_calendar_id
                               iv_date         = iv_date
                     IMPORTING ev_factory_date = lv_factory ).
    rv_date = to_date( iv_calendar_id  = iv_calendar_id
                       iv_factory_date = lv_factory + nmax( val1 = 0 val2 = iv_days ) ).
  ENDMETHOD.


  METHOD to_factory_date.
    DATA lv_indicator TYPE c LENGTH 1.
    DATA lv_subrc TYPE sysubrc.

    CLEAR: ev_factory_date, ev_working.
    " VERIFY-SE37 (V176): parameter names of DATE_CONVERT_TO_FACTORYDATE on the target release
    TEST-SEAM pf_to_factory_date.
      CALL FUNCTION 'DATE_CONVERT_TO_FACTORYDATE'
        EXPORTING
          correct_option       = '+'
          date                 = iv_date
          factory_calendar_id  = iv_calendar_id
        IMPORTING
          factorydate          = ev_factory_date
          workingday_indicator = lv_indicator
        EXCEPTIONS
          error_message        = 98
          OTHERS               = 99.
      lv_subrc = sy-subrc.
    END-TEST-SEAM.
    IF lv_subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e393(zca_ops) WITH iv_calendar_id iv_date.
    ENDIF.
    " the indicator is blank on a working day, + / - when the date was moved
    ev_working = xsdbool( lv_indicator IS INITIAL ).
  ENDMETHOD.


  METHOD to_date.
    DATA lv_subrc TYPE sysubrc.
    " VERIFY-SE37 (V176): parameter names of FACTORYDATE_CONVERT_TO_DATE on the target release
    TEST-SEAM pf_to_date.
      CALL FUNCTION 'FACTORYDATE_CONVERT_TO_DATE'
        EXPORTING
          factorydate         = iv_factory_date
          factory_calendar_id = iv_calendar_id
        IMPORTING
          date                = rv_date
        EXCEPTIONS
          error_message       = 98
          OTHERS              = 99.
      lv_subrc = sy-subrc.
    END-TEST-SEAM.
    IF lv_subrc <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e393(zca_ops) WITH iv_calendar_id iv_factory_date.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
