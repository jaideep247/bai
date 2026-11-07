*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_alert_health.clas.testclasses.abap
*& Purpose:
*& Unit tests of the alert delivery health check: failed and throttled
*& deliveries per channel, zero failures as one '*' metric. The DAO is a
*& test double from the HCK injector; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*& 2026-11-07 | Throttled channel of the test is APPLOG (webhook channel removed).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_stats TYPE zif_cd_hck_types=>tt_alert_stat.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_alert_stats.
    mv_calls = mv_calls + 1.
    rt_stat = mt_stats.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_alert_health DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check   TYPE zif_cd_hck_types=>ty_check_id VALUE 'E_ALERTS',
      gc_mail    TYPE zif_cd_hck_types=>ty_channel VALUE 'EMAIL',
      gc_applog  TYPE zif_cd_hck_types=>ty_channel VALUE 'APPLOG',
      gc_failed  TYPE i VALUE 3,
      gc_thrott  TYPE i VALUE 2,
      gc_today   TYPE d VALUE '20261106',
      gc_now     TYPE t VALUE '070000'.

    TYPES:
      BEGIN OF ty_flags,
        failed    TYPE abap_bool,
        throttled TYPE abap_bool,
        sent_only TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.

    METHODS setup.
    METHODS teardown.
    METHODS failed_measured_per_channel FOR TESTING.
    METHODS no_failure_measures_zero FOR TESTING.
    METHODS sent_is_not_measured FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_alert_health IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_stat TYPE zif_cd_hck_types=>ty_alert_stat.
    IF is_flags-failed = abap_true.
      ls_stat-channel    = gc_mail.
      ls_stat-status     = zif_cd_hck_types=>gc_alert_status-failed.
      ls_stat-item_count = gc_failed.
      INSERT ls_stat INTO TABLE mo_dao->mt_stats.
    ENDIF.
    IF is_flags-throttled = abap_true.
      ls_stat-channel    = gc_applog.
      ls_stat-status     = zif_cd_hck_types=>gc_alert_status-throttled.
      ls_stat-item_count = gc_thrott.
      INSERT ls_stat INTO TABLE mo_dao->mt_stats.
    ENDIF.
    IF is_flags-sent_only = abap_true.
      ls_stat-channel    = gc_mail.
      ls_stat-status     = zif_cd_hck_types=>gc_alert_status-sent.
      ls_stat-item_count = gc_failed.
      INSERT ls_stat INTO TABLE mo_dao->mt_stats.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    DATA ls_def TYPE zif_cd_hck_types=>ty_check_def.
    DATA ls_context TYPE zif_cd_hck_types=>ty_context.
    ls_def-check_id      = gc_check.
    ls_context-report_date = gc_today.
    ls_context-now_date    = gc_today.
    ls_context-now_time    = gc_now.
    rs_result = NEW zcl_cd_hck_c_alert_health( )->zif_cd_hck_check~execute( is_def        = ls_def
                                                                            it_thresholds = VALUE #( )
                                                                            is_context    = ls_context ).
  ENDMETHOD.


  " Rule: a failed delivery is measured per channel; throttled deliveries are a metric of their own
  METHOD failed_measured_per_channel.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        configure_scenario( VALUE #( failed = abap_true throttled = abap_true ) ).
        INSERT VALUE #( metric = zcl_cd_hck_c_alert_health=>gc_metric-failed dim1 = gc_mail value = gc_failed )
          INTO TABLE lt_exp.
        INSERT VALUE #( metric = zcl_cd_hck_c_alert_health=>gc_metric-throttled dim1 = gc_applog value = gc_thrott )
          INTO TABLE lt_exp.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics exp = lt_exp
                                            msg = 'Failed and throttled deliveries are measured per channel' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_calls exp = 1 msg = 'One statistics read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no failed delivery is one ALERT_FAILED '*' = 0, so a threshold can turn the check green
  METHOD no_failure_measures_zero.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        INSERT VALUE #( metric = zcl_cd_hck_c_alert_health=>gc_metric-failed
                        dim1   = zif_cd_hck_types=>gc_default_key ) INTO TABLE lt_exp.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics exp = lt_exp
                                            msg = 'Nothing failed: ALERT_FAILED * = 0' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'The check itself reports no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: sent deliveries are not a health problem and produce no channel metric
  METHOD sent_is_not_measured.
    TRY.
        configure_scenario( VALUE #( sent_only = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-metrics ) exp = 1
                                            msg = 'Only the zero failure metric' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics[ 1 ]-dim1
                                            exp = zif_cd_hck_types=>gc_default_key
                                            msg = 'Zero metric is the * row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
