*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_alert_dlv.clas.abap
*& Purpose:
*& Registered check of the alert delivery (module CORE; registry row
*& CA_OPS / ALERT_DELIVERY, group ALERTDLV, run by ZCA_OPS_ALERT_CONFIRM
*& after its confirmation step; docs/EVALUATION_AND_COVERAGE.md section
*& 4): every alert submitted in the last EVAL_DLV_LOOKBACK_H hours whose
*& delivery is not confirmed - failed after its submission (573, E), not
*& confirmed EVAL_DLV_CONFIRM_MIN minutes after it (572, W) - and one notice
*& per channel that cannot confirm (574, severity EVAL_DLV_UNCONFIRMABLE,
*& I by default). Its source is the confirmation step itself: the newest
*& confirmation attempt (DLV_CHECKED_AT) is its freshness, so a step that
*& stopped running makes the evaluation STALE, never OK. Reads only.
*& Modification log:
*& 2026-11-16 | Initial version (build O: alert delivery confirmed separately from submission).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert delivery check</p>
CLASS zcl_ca_ops_chk_alert_dlv DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

    "! Source name of the confirmation step in the evaluation record
    CONSTANTS gc_source TYPE zif_ca_ops_eval_types=>ty_source_id VALUE 'ZCA_OPS_ALLOG'.

  PRIVATE SECTION.
    CONSTANTS gc_seconds_per_minute TYPE i VALUE 60.
    CONSTANTS gc_minutes_per_hour TYPE i VALUE 60.

    "! Finding of one alert whose delivery is not confirmed (initial when it is, or still within its grace)
    METHODS alert_finding
      IMPORTING
        is_log            TYPE zif_ca_ops_types=>ty_alert_log
        iv_now            TYPE timestampl
        iv_confirm_min    TYPE i
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

ENDCLASS.



CLASS zcl_ca_ops_chk_alert_dlv IMPLEMENTATION.

  METHOD zif_ca_ops_check~run.
    TYPES:
      BEGIN OF ty_count,
        channel TYPE zif_ca_ops_types=>ty_channel,
        count   TYPE i,
      END OF ty_count.
    DATA lt_unconfirmable TYPE SORTED TABLE OF ty_count WITH UNIQUE KEY channel.
    DATA lv_checked TYPE timestampl.

    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    DATA(lv_hours) = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                 iv_name    = zif_ca_ops_eval_types=>gc_param-lookback_h
                                                 iv_default = zif_ca_ops_eval_types=>gc_param_default-lookback_h ).
    DATA(lv_confirm_min) = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                       iv_name    = zif_ca_ops_eval_types=>gc_param-confirm_min
                                                       iv_default = zif_ca_ops_eval_types=>gc_param_default-confirm_min ).
    DATA(lv_severity) = CONV zif_ca_ops_types=>ty_severity( to_upper( lo_params->get_param(
                          iv_name    = zif_ca_ops_eval_types=>gc_param-unconfirmable
                          iv_default = CONV #( zif_ca_ops_eval_types=>gc_param_default-unconfirmable ) ) ) ).
    IF lv_severity <> zif_ca_ops_types=>gc_severity-warning.
      lv_severity = zif_ca_ops_types=>gc_severity-info.
    ENDIF.
    DATA(lv_since) = is_context-now.
    TRY.
        lv_since = cl_abap_tstmp=>add( tstmp = is_context-now
                                       secs  = - lv_hours * gc_minutes_per_hour * gc_seconds_per_minute ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        CLEAR lv_since.
    ENDTRY.

    LOOP AT zcl_ca_ops_factory=>get_alert_dao( )->get_submitted( lv_since ) ASSIGNING FIELD-SYMBOL(<ls_log>)
         WHERE status = zif_ca_ops_types=>gc_alert_status-sent
            OR status = zif_ca_ops_types=>gc_alert_status-partial.
      rs_result-item_count += 1.
      IF <ls_log>-dlv_checked_at > lv_checked.
        lv_checked = <ls_log>-dlv_checked_at.
      ENDIF.
      IF <ls_log>-dlv_state = zif_ca_ops_eval_types=>gc_dlv-cannot_confirm.
        ASSIGN lt_unconfirmable[ channel = <ls_log>-channel ] TO FIELD-SYMBOL(<ls_count>).
        IF sy-subrc <> 0.
          INSERT VALUE #( channel = <ls_log>-channel ) INTO TABLE lt_unconfirmable ASSIGNING <ls_count>.
        ENDIF.
        <ls_count>-count += 1.
        CONTINUE.
      ENDIF.
      DATA(ls_finding) = alert_finding( is_log = <ls_log> iv_now = is_context-now iv_confirm_min = lv_confirm_min ).
      IF ls_finding IS NOT INITIAL.
        INSERT ls_finding INTO TABLE rs_result-findings.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_unconfirmable ASSIGNING <ls_count>.
      INSERT VALUE #( object_type = zif_ca_ops_eval_types=>gc_object_type-alert
                      object_key  = <ls_count>-channel
                      rule_id     = zif_ca_ops_eval_types=>gc_rule_id-delivery
                      check_code  = zif_ca_ops_eval_types=>gc_code-unconfirmable
                      severity    = lv_severity
                      action      = zif_ca_ops_types=>gc_action-notify
                      message     = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-unconfirmable
                                                           iv_v1    = <ls_count>-count
                                                           iv_v2    = <ls_count>-channel ) ) INTO TABLE rs_result-findings.
    ENDLOOP.
    " the source of this check is the confirmation step: its newest attempt is the freshness of the verdict
    IF rs_result-item_count > 0.
      zcl_ca_ops_eval=>add_source( EXPORTING iv_source_id = gc_source
                                             iv_newest_at = lv_checked
                                             iv_stale_min = lv_confirm_min * 2
                                   CHANGING  cs_eval      = rs_result-eval ).
    ENDIF.
    rs_result-eval-expected = rs_result-item_count.
    rs_result-eval-observed = rs_result-item_count - lines( rs_result-findings ).
  ENDMETHOD.


  METHOD alert_finding.
    DATA(lv_key) = CONV zif_ca_ops_types=>ty_object_key( |{ is_log-alert_id }| ).
    CASE is_log-dlv_state.
      WHEN zif_ca_ops_eval_types=>gc_dlv-delivered.
        RETURN.
      WHEN zif_ca_ops_eval_types=>gc_dlv-failed.
        rs_finding = VALUE #( check_code = zif_ca_ops_eval_types=>gc_code-dlv_failed
                              severity   = zif_ca_ops_types=>gc_severity-error
                              message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-dlv_failed
                                                                  iv_v1    = lv_key
                                                                  iv_v2    = is_log-rule_id
                                                                  iv_v3    = is_log-channel
                                                                  iv_v4    = is_log-dlv_info ) ).
      WHEN OTHERS.
        " pending or not asked: a finding only once the grace minutes after the submission have passed
        IF zcl_ca_ops_eval=>is_stale( iv_newest_at = is_log-sent_at
                                      iv_now       = iv_now
                                      iv_stale_min = iv_confirm_min ) = abap_false.
          RETURN.
        ENDIF.
        rs_finding = VALUE #( check_code = zif_ca_ops_eval_types=>gc_code-not_confirmed
                              severity   = zif_ca_ops_types=>gc_severity-warning
                              message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-not_confirmed
                                                                  iv_v1    = lv_key
                                                                  iv_v2    = is_log-rule_id
                                                                  iv_v3    = is_log-channel
                                                                  iv_v4    = |{ is_log-sent_at TIMESTAMP = ISO }| ) ).
    ENDCASE.
    rs_finding-object_type = zif_ca_ops_eval_types=>gc_object_type-alert.
    rs_finding-object_key  = lv_key.
    rs_finding-rule_id     = zif_ca_ops_eval_types=>gc_rule_id-delivery.
    " the run that raised the alert (its area is in the alert log row)
    rs_finding-reference   = is_log-run_id.
  ENDMETHOD.

ENDCLASS.
