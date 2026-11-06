*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_applog.clas.testclasses.abap
*& Purpose:
*& Unit tests of the application log error-rate check: rate and error count
*& per object / subobject, weight of the rate, empty log, missing objects
*& parameter. The DAO is a test double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_stats TYPE zif_cd_hck_types=>tt_applog_stat.
    DATA mv_date TYPE d.
    DATA mt_objects TYPE zif_cd_hck_types=>tt_object_range.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_applog_stats.
    mv_date    = iv_date.
    mt_objects = it_objects.
    rt_stat    = mt_stats.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_applog DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check     TYPE zif_cd_hck_types=>ty_check_id VALUE 'E_APPLOG',
      gc_objects   TYPE zif_cd_hck_types=>ty_param VALUE 'ZCD_OPS,FKK*',
      gc_object    TYPE zif_cd_hck_types=>ty_bal_object VALUE 'ZCD_OPS',
      gc_subobject TYPE zif_cd_hck_types=>ty_bal_subobject VALUE 'EBS',
      gc_today     TYPE d VALUE '20261106',
      gc_yesterday TYPE d VALUE '20261105',
      gc_total     TYPE i VALUE 200,
      gc_errors    TYPE i VALUE 6,
      gc_aborts    TYPE i VALUE 4,
      gc_rate      TYPE i VALUE 5.

    TYPES:
      BEGIN OF ty_flags,
        no_objects TYPE abap_bool,
        with_log   TYPE abap_bool,
        empty_log  TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA ms_def TYPE zif_cd_hck_types=>ty_check_def.

    METHODS setup.
    METHODS teardown.
    METHODS rate_and_errors_per_object FOR TESTING.
    METHODS empty_log_rate_is_zero FOR TESTING.
    METHODS missing_objects_raises FOR TESTING.
    METHODS default_day_is_yesterday FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_applog IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    CLEAR ms_def.
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_stat TYPE zif_cd_hck_types=>ty_applog_stat.
    ms_def-check_id = gc_check.
    IF is_flags-no_objects = abap_false.
      ms_def-param1 = gc_objects.
    ENDIF.
    ls_stat-object    = gc_object.
    ls_stat-subobject = gc_subobject.
    ls_stat-log_count = 1.
    IF is_flags-with_log = abap_true.
      ls_stat-msg_total = gc_total.
      ls_stat-msg_error = gc_errors.
      ls_stat-msg_abort = gc_aborts.
      INSERT ls_stat INTO TABLE mo_dao->mt_stats.
    ENDIF.
    IF is_flags-empty_log = abap_true.
      INSERT ls_stat INTO TABLE mo_dao->mt_stats.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_applog( )->zif_cd_hck_check~execute(
      is_def        = ms_def
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc_today ) ).
  ENDMETHOD.


  " Rule: rate = (errors + aborts) / messages * 100, weighted by the messages read (A88)
  METHOD rate_and_errors_per_object.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        configure_scenario( VALUE #( with_log = abap_true ) ).
        DATA(lv_dim) = CONV zif_cd_hck_types=>ty_dim( |{ gc_object }/{ gc_subobject }| ).
        INSERT VALUE #( metric = zcl_cd_hck_c_applog=>gc_metric-error_rate dim1 = lv_dim dim2 = gc_yesterday
                        value  = gc_rate
                        kind   = zif_cd_hck_types=>gc_metric_kind-rate
                        weight = gc_total ) INTO TABLE lt_exp.
        INSERT VALUE #( metric = zcl_cd_hck_c_applog=>gc_metric-error_messages dim1 = lv_dim dim2 = gc_yesterday
                        value  = gc_errors + gc_aborts ) INTO TABLE lt_exp.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics exp = lt_exp
                                            msg = 'Error rate and error count per object/subobject' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_objects ) exp = 2
                                            msg = 'Both configured objects are read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a log without messages has rate 0 - no division by zero
  METHOD empty_log_rate_is_zero.
    TRY.
        configure_scenario( VALUE #( empty_log = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-value exp = 0
                                            msg = 'Rate of an empty log is 0' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-weight exp = 0
                                            msg = 'Weight of an empty log is 0' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without log objects (PARAM1) the check is misconfigured and raises (engine: PLUGIN_ERROR)
  METHOD missing_objects_raises.
    configure_scenario( VALUE #( no_objects = abap_true ) ).
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'Missing PARAM1 must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Configuration error raised' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PARAM3 blank = day offset 1 (yesterday's logs)
  METHOD default_day_is_yesterday.
    TRY.
        configure_scenario( VALUE #( with_log = abap_true ) ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_date exp = gc_yesterday
                                            msg = 'Default day is report date - 1' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
