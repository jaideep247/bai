*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_alert_confirm.clas.abap
*& Purpose:
*& Delivery confirmation step of the alerts (docs/EVALUATION_AND_
*& COVERAGE.md section 4; report ZCA_OPS_ALERT_CONFIRM): every alert
*& submitted in the last EVAL_DLV_LOOKBACK_H hours whose delivery is not
*& decided yet (DLV_STATE blank or P) is asked again through its channel
*& (ZIF_CA_OPS_ALERT_CHANNEL=>CONFIRM: application log delivered on write,
*& e-mail through the send status reader of EVAL_EMAIL_READER, a custom
*& channel through its own CONFIRM). A channel that does not answer, is no
*& longer configured or fails keeps the alert undecided or "cannot
*& confirm" - never "delivered". Writes only the delivery columns of
*& ZCA_OPS_ALLOG and commits once; test mode writes nothing. Read-only
*& towards the channels: nothing is sent again. The registered check
*& ZCL_CA_OPS_CHK_ALERT_DLV turns what stays unconfirmed into findings.
*& Modification log:
*& 2026-11-16 | Initial version (build O: alert delivery confirmed separately from submission).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - alert delivery confirmation</p>
CLASS zcl_ca_ops_alert_confirm DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Ask the channels about every undecided submitted alert of the look-back and store their answers
    "! @raising zcx_ca_ops_error | 081 an alert row is gone, store errors
    METHODS confirm
      IMPORTING
        iv_test_mode      TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rs_summary) TYPE zif_ca_ops_eval_types=>ty_confirm_summary
      RAISING
        zcx_ca_ops_error.

    "! One alert: the channel's answer applied to its row (pure apart from the channel; tests)
    CLASS-METHODS apply
      IMPORTING
        is_delivery   TYPE zif_ca_ops_eval_types=>ty_delivery
        iv_now        TYPE timestampl
      CHANGING
        cs_log        TYPE zif_ca_ops_types=>ty_alert_log.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_channel_ref,
        channel  TYPE zif_ca_ops_types=>ty_channel,
        instance TYPE REF TO zif_ca_ops_alert_channel,
        info     TYPE zif_ca_ops_types=>ty_message,
      END OF ty_channel_ref.
    TYPES tt_channel_ref TYPE HASHED TABLE OF ty_channel_ref WITH UNIQUE KEY channel.

    DATA mt_channels TYPE tt_channel_ref.

    "! The channel instance of an alert's channel (initial with the reason when it cannot be created)
    METHODS channel_of
      IMPORTING
        iv_channel     TYPE zif_ca_ops_types=>ty_channel
        it_config      TYPE zif_ca_ops_types=>tt_alert_channel
      RETURNING
        VALUE(rs_ref) TYPE ty_channel_ref.

ENDCLASS.



CLASS zcl_ca_ops_alert_confirm IMPLEMENTATION.

  METHOD confirm.
    DATA ls_delivery TYPE zif_ca_ops_eval_types=>ty_delivery.
    DATA(lo_dao) = zcl_ca_ops_factory=>get_alert_dao( ).
    DATA(lv_now) = zcl_ca_ops_factory=>get_clock( )->now( ).
    DATA(lv_hours) = zcl_ca_ops_util=>param_int( io_params  = zcl_ca_ops_factory=>get_params( )
                                                 iv_name    = zif_ca_ops_eval_types=>gc_param-lookback_h
                                                 iv_default = zif_ca_ops_eval_types=>gc_param_default-lookback_h ).
    DATA(lv_since) = lv_now.
    TRY.
        lv_since = cl_abap_tstmp=>add( tstmp = lv_now secs = - lv_hours * 3600 ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        CLEAR lv_since.
    ENDTRY.
    DATA(lt_config) = lo_dao->get_channels( ).
    rs_summary-rows = lo_dao->get_submitted( iv_since = lv_since iv_open_only = abap_true ).
    LOOP AT rs_summary-rows ASSIGNING FIELD-SYMBOL(<ls_log>)
         WHERE status = zif_ca_ops_types=>gc_alert_status-sent
            OR status = zif_ca_ops_types=>gc_alert_status-partial.
      rs_summary-checked += 1.
      DATA(ls_ref) = channel_of( iv_channel = <ls_log>-channel it_config = lt_config ).
      IF ls_ref-instance IS NOT BOUND.
        ls_delivery = VALUE #( state = zif_ca_ops_eval_types=>gc_dlv-cannot_confirm info = ls_ref-info ).
      ELSE.
        TRY.
            ls_delivery = ls_ref-instance->confirm( <ls_log> ).
          CATCH cx_root INTO DATA(lx_confirm).
            " the channel could not answer now: still undecided, asked again by the next step
            ls_delivery = VALUE #( state = zif_ca_ops_eval_types=>gc_dlv-pending
                                   info  = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-confirm_failed
                                                                  iv_v1    = <ls_log>-channel
                                                                  iv_tail  = lx_confirm->get_text( ) ) ).
        ENDTRY.
      ENDIF.
      apply( EXPORTING is_delivery = ls_delivery
                       iv_now      = lv_now
             CHANGING  cs_log      = <ls_log> ).
      CASE <ls_log>-dlv_state.
        WHEN zif_ca_ops_eval_types=>gc_dlv-delivered.
          rs_summary-delivered += 1.
        WHEN zif_ca_ops_eval_types=>gc_dlv-failed.
          rs_summary-failed += 1.
        WHEN zif_ca_ops_eval_types=>gc_dlv-cannot_confirm.
          rs_summary-cannot_confirm += 1.
        WHEN OTHERS.
          rs_summary-pending += 1.
      ENDCASE.
    ENDLOOP.
    " a failed submission has no delivery to confirm
    DELETE rs_summary-rows WHERE status = zif_ca_ops_types=>gc_alert_status-failed.
    IF iv_test_mode = abap_true OR rs_summary-rows IS INITIAL.
      RETURN.
    ENDIF.
    lo_dao->set_delivery( rs_summary-rows ).
    zcl_ca_ops_factory=>get_store( )->commit( ).
  ENDMETHOD.


  METHOD apply.
    cs_log-dlv_checked_at = iv_now.
    cs_log-dlv_state = COND #( WHEN is_delivery-state IS INITIAL THEN zif_ca_ops_eval_types=>gc_dlv-cannot_confirm
                               ELSE is_delivery-state ).
    cs_log-dlv_info = is_delivery-info.
    IF cs_log-dlv_state = zif_ca_ops_eval_types=>gc_dlv-delivered.
      cs_log-dlv_at = COND #( WHEN is_delivery-delivered_at IS INITIAL THEN iv_now ELSE is_delivery-delivered_at ).
    ELSE.
      CLEAR cs_log-dlv_at.
    ENDIF.
  ENDMETHOD.


  METHOD channel_of.
    ASSIGN mt_channels[ channel = iv_channel ] TO FIELD-SYMBOL(<ls_known>).
    IF sy-subrc = 0.
      rs_ref = <ls_known>.
      RETURN.
    ENDIF.
    rs_ref-channel = iv_channel.
    DATA(ls_config) = VALUE zif_ca_ops_types=>ty_alert_channel( it_config[ channel = iv_channel ] OPTIONAL ).
    IF ls_config-class_name IS INITIAL.
      rs_ref-info = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-no_channel iv_v1 = iv_channel ).
    ELSE.
      TRY.
          rs_ref-instance = CAST zif_ca_ops_alert_channel( zcl_ca_ops_factory=>get_plugin(
                              iv_class_name = ls_config-class_name
                              iv_interface  = zif_ca_ops_types=>gc_plugin_intf-alert_channel ) ).
        CATCH zcx_ca_ops_error cx_sy_move_cast_error INTO DATA(lx_wiring).
          rs_ref-info = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_eval_types=>gc_msg-confirm_failed
                                               iv_v1    = iv_channel
                                               iv_tail  = lx_wiring->get_text( ) ).
      ENDTRY.
    ENDIF.
    INSERT rs_ref INTO TABLE mt_channels.
  ENDMETHOD.

ENDCLASS.
