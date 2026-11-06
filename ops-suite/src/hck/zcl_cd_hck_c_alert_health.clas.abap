*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_alert_health.clas.abap
*& Purpose:
*& Technical health: alert delivery of the suite - failed and throttled
*& deliveries per channel in ZCD_OPS_ALLOG within a time window.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCD_OPS_ALCHN / ALLOG / ALRULE.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - alert delivery health (ZCD_OPS_ALLOG)</p>
"! PARAM1 = window in hours back from now (default 24).
"! Metrics per channel (DIM1): ALERT_FAILED (status F), ALERT_THROTTLED
"! (status T); ALERT_FAILED '*' = 0 when nothing failed.
CLASS zcl_cd_hck_c_alert_health DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS:
      BEGIN OF gc_metric,
        failed    TYPE zif_cd_hck_types=>ty_metric_name VALUE 'ALERT_FAILED',
        throttled TYPE zif_cd_hck_types=>ty_metric_name VALUE 'ALERT_THROTTLED',
      END OF gc_metric.

ENDCLASS.



CLASS zcl_cd_hck_c_alert_health IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lv_now TYPE timestamp.
    DATA lv_to TYPE timestampl.
    DATA lv_from TYPE timestampl.
    DATA lv_failed_total TYPE zif_cd_hck_types=>ty_value.

    DATA(lv_hours) = nmax( val1 = 1
                           val2 = zcl_cd_hck_param=>int( iv_value = is_def-param1 iv_default = 24 ) ).
    CONVERT DATE is_context-now_date TIME is_context-now_time INTO TIME STAMP lv_now TIME ZONE sy-zonlo.
    lv_to = lv_now.
    lv_from = cl_abap_tstmp=>subtractsecs( tstmp = lv_now
                                           secs  = lv_hours * 3600 ).

    DATA(lt_stats) = zcl_cd_hck_factory=>get_dao( )->get_alert_stats( iv_from = lv_from
                                                                       iv_to   = lv_to ).
    LOOP AT lt_stats ASSIGNING FIELD-SYMBOL(<ls_stat>).
      CASE <ls_stat>-status.
        WHEN zif_cd_hck_types=>gc_alert_status-failed.
          lv_failed_total = lv_failed_total + <ls_stat>-item_count.
          INSERT VALUE #( metric = gc_metric-failed dim1 = <ls_stat>-channel value = <ls_stat>-item_count )
            INTO TABLE rs_result-metrics.
        WHEN zif_cd_hck_types=>gc_alert_status-throttled.
          INSERT VALUE #( metric = gc_metric-throttled dim1 = <ls_stat>-channel value = <ls_stat>-item_count )
            INTO TABLE rs_result-metrics.
      ENDCASE.
    ENDLOOP.
    IF lv_failed_total = 0.
      INSERT VALUE #( metric = gc_metric-failed dim1 = zif_cd_hck_types=>gc_default_key value = 0 )
        INTO TABLE rs_result-metrics.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
