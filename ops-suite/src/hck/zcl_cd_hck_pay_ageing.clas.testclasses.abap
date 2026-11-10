*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_pay_ageing.clas.testclasses.abap
*& Purpose:
*& Unit tests of the shared ageing rule of a payment in flight with an LTD
*& double of the health check repository (holidays per calendar, HCK
*& injector): business days after the value date in the house-bank /
*& class / default calendar, the run date when the value date is missing,
*& calendar days of ISSUE_DATE classes, the RAG against AGE_OLDEST, never
*& late without limits, the business-day test of a single date (read once).
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-08 | Initial version (ageing extracted from A_INFLIGHT for the payment worklist).
*&---------------------------------------------------------------------*
CLASS ltd_hck_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    TYPES:
      BEGIN OF ty_holiday,
        calendar TYPE zif_cd_hck_types=>ty_calendar,
        date     TYPE d,
      END OF ty_holiday.
    DATA mt_holidays TYPE STANDARD TABLE OF ty_holiday WITH EMPTY KEY.
    DATA mv_reads TYPE i.
ENDCLASS.

CLASS ltd_hck_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~is_working_day.
    mv_reads = mv_reads + 1.
    rv_working = xsdbool( NOT line_exists( mt_holidays[ calendar = iv_calendar date = iv_date ] ) ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ageing DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        today    TYPE d VALUE '20261111',
        monday   TYPE d VALUE '20261109',
        friday   TYPE d VALUE '20261106',
        holiday  TYPE d VALUE '20261110',
        us       TYPE zif_cd_hck_types=>ty_calendar VALUE 'US',
        uk       TYPE zif_cd_hck_types=>ty_calendar VALUE 'GB',
        bank     TYPE zif_cd_hck_runtime_types=>ty_hbkid VALUE 'BARC1',
        wire     TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'DWIR',
        cheque   TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'DCHQ',
        metric   TYPE zif_cd_hck_types=>ty_metric_name VALUE 'AGE_OLDEST',
        amber    TYPE i VALUE 1,
        red      TYPE i VALUE 2,
        two_days TYPE i VALUE 2,
        five     TYPE i VALUE 5,
      END OF gc.

    DATA mo_hck TYPE REF TO ltd_hck_dao.
    DATA mo_cut TYPE REF TO zcl_cd_hck_pay_ageing.

    METHODS setup.
    METHODS teardown.

    METHODS value_date_business_days FOR TESTING.
    METHODS missing_value_run_date   FOR TESTING.
    METHODS issue_date_calendar_days FOR TESTING.
    METHODS bank_calendar_overrides  FOR TESTING.
    METHODS rag_from_age_oldest      FOR TESTING.
    METHODS no_limits_never_late     FOR TESTING.
    METHODS single_day_read_once     FOR TESTING.
ENDCLASS.


CLASS ltc_ageing IMPLEMENTATION.

  METHOD setup.
    DATA lt_classes TYPE zif_cd_hck_runtime_types=>tt_pm_class.
    DATA lt_banks TYPE zif_cd_hck_runtime_types=>tt_pm_class.
    DATA lt_thresholds TYPE zif_cd_hck_types=>tt_threshold.
    DATA ls_class TYPE zif_cd_hck_runtime_types=>ty_pm_class.
    DATA ls_threshold TYPE zif_cd_hck_types=>ty_threshold.
    mo_hck = NEW #( ).
    INSERT VALUE #( calendar = gc-us date = gc-holiday ) INTO TABLE mo_hck->mt_holidays.
    INSERT VALUE #( calendar = gc-uk date = gc-monday ) INTO TABLE mo_hck->mt_holidays.
    zcl_cd_hck_injector=>inject_dao( mo_hck ).
    ls_class-flow         = gc-wire(1).
    ls_class-method_class = gc-wire+1(3).
    ls_class-age_basis    = zif_cd_hck_runtime_types=>gc_age_basis-value_date.
    INSERT ls_class INTO TABLE lt_classes.
    ls_class-method_class = gc-cheque+1(3).
    ls_class-age_basis    = zif_cd_hck_runtime_types=>gc_age_basis-issue_date.
    INSERT ls_class INTO TABLE lt_classes.
    CLEAR ls_class.
    ls_class-flow         = gc-wire(1).
    ls_class-method_class = gc-wire+1(3).
    ls_class-hbkid        = gc-bank.
    ls_class-calendar     = gc-uk.
    INSERT ls_class INTO TABLE lt_banks.
    ls_threshold-metric          = gc-metric.
    ls_threshold-bukrs           = gc-wire.
    ls_threshold-amber           = gc-amber.
    ls_threshold-red             = gc-red.
    ls_threshold-higher_is_worse = abap_true.
    INSERT ls_threshold INTO TABLE lt_thresholds.
    mo_cut = NEW #( it_classes    = lt_classes
                    it_banks      = lt_banks
                    it_watched    = VALUE #( ( gc-wire ) ( gc-cheque ) )
                    iv_calendar   = gc-us
                    it_thresholds = lt_thresholds
                    iv_today      = gc-today ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR: mo_hck, mo_cut.
  ENDMETHOD.


  " Rule: a VALUE_DATE class is aged in business days after the value date (holiday not counted)
  METHOD value_date_business_days.
    TRY.
        DATA(ls_age) = mo_cut->age_of( iv_key = gc-wire iv_laufd = gc-friday iv_valut = gc-monday iv_hbkid = space ).
        cl_abap_unit_assert=>assert_equals( act = ls_age-age exp = 1 msg = 'Tuesday is a holiday: one business day' ).
        cl_abap_unit_assert=>assert_equals( act = ls_age-ref_date exp = gc-monday msg = 'From the value date' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without value date the run date is the reference (said by A_INFLIGHT as VALUE_DATE_MISSING)
  METHOD missing_value_run_date.
    TRY.
        DATA(ls_age) = mo_cut->age_of( iv_key = gc-wire iv_laufd = gc-monday iv_valut = VALUE #( ) iv_hbkid = space ).
        cl_abap_unit_assert=>assert_true( act = ls_age-no_valut msg = 'Value date missing' ).
        cl_abap_unit_assert=>assert_equals( act = ls_age-ref_date exp = gc-monday msg = 'Run date used' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an ISSUE_DATE class (cheques) is aged in calendar days since the run date
  METHOD issue_date_calendar_days.
    TRY.
        DATA(ls_age) = mo_cut->age_of( iv_key = gc-cheque iv_laufd = gc-friday iv_valut = gc-monday iv_hbkid = space ).
        cl_abap_unit_assert=>assert_equals( act = ls_age-age exp = gc-five msg = 'Calendar days since the run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the house-bank calendar overrides the class / default calendar
  METHOD bank_calendar_overrides.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->calendar_of( iv_key = gc-wire iv_hbkid = gc-bank ) exp = gc-uk
                                            msg = 'Bank calendar' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->calendar_of( iv_key = gc-wire iv_hbkid = space ) exp = gc-us
                                            msg = 'Default calendar' ).
        DATA(ls_age) = mo_cut->age_of( iv_key = gc-wire iv_laufd = gc-friday iv_valut = gc-monday iv_hbkid = gc-bank ).
        cl_abap_unit_assert=>assert_equals( act = ls_age-age exp = gc-two_days
                                            msg = 'UK: Tuesday is no holiday there - two business days' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: AMBER from the age that is late, RED from the critical age (AGE_OLDEST of the flow + class)
  METHOD rag_from_age_oldest.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->rag_of( iv_key = gc-wire iv_age = gc-amber )
                                            exp = zif_ca_ops_types=>gc_rag-amber msg = 'Late' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->rag_of( iv_key = gc-wire iv_age = gc-red )
                                            exp = zif_ca_ops_types=>gc_rag-red msg = 'Critical' ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->limits_set( gc-wire ) msg = 'Limits maintained' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a flow + class without AGE_OLDEST limits is never late (no stale-cheque policy)
  METHOD no_limits_never_late.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->rag_of( iv_key = gc-cheque iv_age = gc-five )
                                             msg = 'No limits: no RAG' ).
        cl_abap_unit_assert=>assert_false( act = mo_cut->limits_set( gc-cheque ) msg = 'Not maintained' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a single date is tested once per calendar and run (due dates of payment requests)
  METHOD single_day_read_once.
    TRY.
        cl_abap_unit_assert=>assert_false( act = mo_cut->is_business_day( iv_calendar = gc-us iv_date = gc-holiday )
                                           msg = 'Holiday' ).
        cl_abap_unit_assert=>assert_false( act = mo_cut->is_business_day( iv_calendar = gc-us iv_date = gc-holiday )
                                           msg = 'Holiday again' ).
        cl_abap_unit_assert=>assert_equals( act = mo_hck->mv_reads exp = 1 msg = 'Read once' ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->is_business_day( iv_calendar = space iv_date = gc-holiday )
                                          msg = 'No calendar: every day' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
