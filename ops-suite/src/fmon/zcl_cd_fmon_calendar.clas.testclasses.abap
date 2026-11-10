*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_calendar.clas.testclasses.abap
*& Purpose:
*& Unit tests of the factory calendar wrapper through test seams
*& TO_FACTORY_DATE / TO_DATE: working day, moved (non-working) day, month
*& end, working days between two dates, calendar errors raise 206. The
*& calendar function modules are replaced by TEST-INJECTION (factory date =
*& day of month); does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltc_calendar DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_calendar     TYPE zif_cd_fmon_types=>ty_fcal_id VALUE 'US',
      gc_monday       TYPE d VALUE '20261102',
      gc_friday       TYPE d VALUE '20261106',
      gc_last_working TYPE d VALUE '20261130',
      gc_msgno_cal    TYPE symsgno VALUE '206',
      gc_days_between TYPE i VALUE 4.

    TYPES:
      BEGIN OF ty_flags,
        moved          TYPE abap_bool,
        convert_fails  TYPE abap_bool,
        next_in_month  TYPE abap_bool,
        back_fails     TYPE abap_bool,
      END OF ty_flags.

    DATA mo_cut TYPE REF TO zif_cd_fmon_calendar.

    METHODS setup.
    METHODS teardown.
    METHODS working_day_is_working FOR TESTING.
    METHODS moved_day_is_not_working FOR TESTING.
    METHODS last_working_day_month_end FOR TESTING.
    METHODS mid_month_is_not_month_end FOR TESTING.
    METHODS holiday_is_not_month_end FOR TESTING.
    METHODS days_between_factory_dates FOR TESTING.
    METHODS reversed_range_is_zero FOR TESTING.
    METHODS calendar_error_raises_206 FOR TESTING.
    METHODS back_conversion_raises_206 FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS assert_raises_206
      IMPORTING
        iv_date TYPE d.
ENDCLASS.


CLASS ltc_calendar IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_cd_fmon_calendar( ).
  ENDMETHOD.


  METHOD teardown.
    CLEAR mo_cut.
  ENDMETHOD.


  " Both seams are injected in every scenario; the factory date is the day of the month
  METHOD configure_scenario.
    IF is_flags-convert_fails = abap_true.
      TEST-INJECTION to_factory_date.
        lv_subrc = 98.
      END-TEST-INJECTION.
    ELSEIF is_flags-moved = abap_true.
      TEST-INJECTION to_factory_date.
        ev_factory_date = iv_date+6(2).
        lv_indicator    = iv_correct.
        lv_subrc        = 0.
      END-TEST-INJECTION.
    ELSE.
      TEST-INJECTION to_factory_date.
        ev_factory_date = iv_date+6(2).
        lv_subrc        = 0.
      END-TEST-INJECTION.
    ENDIF.
    IF is_flags-back_fails = abap_true.
      TEST-INJECTION to_date.
        lv_subrc = 99.
      END-TEST-INJECTION.
    ELSEIF is_flags-next_in_month = abap_true.
      TEST-INJECTION to_date.
        rv_date  = '20261111'.
        lv_subrc = 0.
      END-TEST-INJECTION.
    ELSE.
      TEST-INJECTION to_date.
        rv_date  = '20261201'.
        lv_subrc = 0.
      END-TEST-INJECTION.
    ENDIF.
  ENDMETHOD.


  METHOD assert_raises_206.
    TRY.
        mo_cut->is_month_end( iv_date = iv_date iv_calendar_id = gc_calendar ).
        cl_abap_unit_assert=>fail( msg = 'Calendar error must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = gc_msgno_cal
                                            msg = 'Calendar error is message 206' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a date the calendar did not move is a working day
  METHOD working_day_is_working.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->is_working_day( iv_date        = gc_friday
                                                                        iv_calendar_id = gc_calendar )
                                          msg = 'Unmoved date is a working day' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a date the calendar moved (indicator + / -) is not a working day
  METHOD moved_day_is_not_working.
    TRY.
        configure_scenario( VALUE #( moved = abap_true ) ).
        cl_abap_unit_assert=>assert_false( act = mo_cut->is_working_day( iv_date        = gc_friday
                                                                         iv_calendar_id = gc_calendar )
                                           msg = 'Moved date is not a working day' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a working day whose next working day lies in the next month is the month end
  METHOD last_working_day_month_end.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->is_month_end( iv_date        = gc_last_working
                                                                      iv_calendar_id = gc_calendar )
                                          msg = 'Next working day in December: month end' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a working day followed by one in the same month is no month end
  METHOD mid_month_is_not_month_end.
    TRY.
        configure_scenario( VALUE #( next_in_month = abap_true ) ).
        cl_abap_unit_assert=>assert_false( act = mo_cut->is_month_end( iv_date        = gc_friday
                                                                       iv_calendar_id = gc_calendar )
                                           msg = 'Next working day in November: no month end' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a non-working day is never the month end (the last working day is)
  METHOD holiday_is_not_month_end.
    TRY.
        configure_scenario( VALUE #( moved = abap_true ) ).
        cl_abap_unit_assert=>assert_false( act = mo_cut->is_month_end( iv_date        = gc_last_working
                                                                       iv_calendar_id = gc_calendar )
                                           msg = 'Non-working day is no month end' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: banking days elapsed = difference of the factory dates
  METHOD days_between_factory_dates.
    TRY.
        configure_scenario( VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->working_days_between( iv_from        = gc_monday
                                                                                iv_to          = gc_friday
                                                                                iv_calendar_id = gc_calendar )
                                            exp = gc_days_between
                                            msg = 'Monday to Friday: 4 working days elapsed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an end before the start gives 0, never a negative age (no calendar read)
  METHOD reversed_range_is_zero.
    TRY.
        configure_scenario( VALUE #( convert_fails = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->working_days_between( iv_from        = gc_friday
                                                                                iv_to          = gc_monday
                                                                                iv_calendar_id = gc_calendar )
                                            exp = 0
                                            msg = 'Reversed range is 0 without calendar read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a calendar that cannot convert the date raises 206 - never a guessed age
  METHOD calendar_error_raises_206.
    configure_scenario( VALUE #( convert_fails = abap_true ) ).
    assert_raises_206( gc_friday ).
  ENDMETHOD.


  " Rule: a factory date that cannot be converted back raises 206
  METHOD back_conversion_raises_206.
    configure_scenario( VALUE #( back_fails = abap_true ) ).
    assert_raises_206( gc_last_working ).
  ENDMETHOD.

ENDCLASS.
