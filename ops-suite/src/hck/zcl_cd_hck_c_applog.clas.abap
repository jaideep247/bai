*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_applog.clas.abap
*& Purpose:
*& Mass-run health: application-log (SLG1) error rate per object/subobject
*& from the BALHDR message counters, for a configured object list.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Error rate is a weighted rate metric (weight = messages read, audit A88).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | PARAM1 objects / PARAM2 subobjects are PCRE (complete value, case ignored); invalid raises E373.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - application log error rate (SLG1)</p>
"! PARAM1 = log objects (patterns allowed), PARAM2 = subobjects (blank = all),
"! PARAM3 = day offset (default 1). Metrics per OBJECT/SUBOBJECT (DIM1):
"! ERR_RATE_PCT = (errors + aborts) / all messages * 100, ERR_MESSAGES.
"! Header counters only - no message texts are loaded (no BAL_DB_LOAD).
CLASS zcl_cd_hck_c_applog DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS:
      BEGIN OF gc_metric,
        error_rate     TYPE zif_cd_hck_types=>ty_metric_name VALUE 'ERR_RATE_PCT',
        error_messages TYPE zif_cd_hck_types=>ty_metric_name VALUE 'ERR_MESSAGES',
      END OF gc_metric.

ENDCLASS.



CLASS zcl_cd_hck_c_applog IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA lv_rate TYPE zif_cd_hck_types=>ty_value.

    DATA(lt_objects) = zcl_cd_hck_param=>patterns( is_def-param1 ).
    IF lt_objects IS INITIAL.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e344(zcd_ops) WITH is_def-check_id.
    ENDIF.
    DATA(lt_subobjects) = zcl_cd_hck_param=>patterns( is_def-param2 ).
    zcl_cd_hck_param=>check_patterns( it_patterns = lt_objects iv_check_id = is_def-check_id ).
    zcl_cd_hck_param=>check_patterns( it_patterns = lt_subobjects iv_check_id = is_def-check_id ).
    DATA(lv_day) = CONV d( is_context-report_date - zcl_cd_hck_param=>int( iv_value = is_def-param3 iv_default = 1 ) ).

    DATA(lt_stats) = zcl_cd_hck_factory=>get_dao( )->get_applog_stats( it_objects    = lt_objects
                                                                        it_subobjects = lt_subobjects
                                                                        iv_date       = lv_day ).
    LOOP AT lt_stats ASSIGNING FIELD-SYMBOL(<ls_stat>).
      DATA(lv_dim) = CONV zif_cd_hck_types=>ty_dim( |{ <ls_stat>-object }/{ <ls_stat>-subobject }| ).
      DATA(lv_errors) = <ls_stat>-msg_error + <ls_stat>-msg_abort.
      lv_rate = COND #( WHEN <ls_stat>-msg_total > 0 THEN lv_errors * 100 / <ls_stat>-msg_total ELSE 0 ).
      " A88: a rate is averaged over days / objects weighted by the messages it was read from
      INSERT VALUE #( metric = gc_metric-error_rate dim1 = lv_dim dim2 = lv_day value = lv_rate
                      kind   = zif_cd_hck_types=>gc_metric_kind-rate
                      weight = <ls_stat>-msg_total )
        INTO TABLE rs_result-metrics.
      INSERT VALUE #( metric = gc_metric-error_messages dim1 = lv_dim dim2 = lv_day value = lv_errors )
        INTO TABLE rs_result-metrics.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
