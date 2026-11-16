*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_alert_confirm.clas.testclasses.abap
*& Purpose:
*& Tests of the delivery confirmation step with doubles (alert repository,
*& channels by class name, clock, in-memory parameters, store): a channel
*& that confirms (delivered, with its time), one that does not yet
*& (pending), one that cannot confirm (no CONFIRM implemented: the optional
*& method's initial answer is "cannot confirm", never "delivered"), a
*& channel no longer configured, a channel whose CONFIRM fails (still
*& pending, asked again), test mode (nothing written) and a failed
*& submission (nothing to confirm). Does not prove live SAP runtime
*& behavior (SOST status read: VERIFY V271 / V272).
*& Modification log:
*& 2026-11-16 | Initial version (build O: alert delivery confirmed separately from submission).
*&---------------------------------------------------------------------*
CLASS ltd_channel DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert_channel.
    DATA ms_answer TYPE zif_ca_ops_eval_types=>ty_delivery.
    DATA mv_fail TYPE abap_bool.
    DATA mv_asked TYPE i.
ENDCLASS.

CLASS ltd_channel IMPLEMENTATION.
  METHOD zif_ca_ops_alert_channel~deliver.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_channel~confirm.
    mv_asked += 1.
    IF mv_fail = abap_true.
      RAISE EXCEPTION NEW cx_sy_zerodivide( ).
    ENDIF.
    rs_delivery = ms_answer.
  ENDMETHOD.
ENDCLASS.


"! A custom channel that implements only DELIVER (CONFIRM and DELIVERY_REF stay DEFAULT IGNORE)
CLASS ltd_mute_channel DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert_channel.
ENDCLASS.

CLASS ltd_mute_channel IMPLEMENTATION.
  METHOD zif_ca_ops_alert_channel~deliver.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_alert_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert_dao PARTIALLY IMPLEMENTED.
    DATA mt_log TYPE zif_ca_ops_types=>tt_alert_log.
    DATA mt_channels TYPE zif_ca_ops_types=>tt_alert_channel.
    DATA mt_saved TYPE zif_ca_ops_types=>tt_alert_log.
    DATA mv_open_only TYPE abap_bool.
ENDCLASS.

CLASS ltd_alert_dao IMPLEMENTATION.
  METHOD zif_ca_ops_alert_dao~get_submitted.
    mv_open_only = iv_open_only.
    rt_log = mt_log.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~get_channels.
    rt_channels = mt_channels.
  ENDMETHOD.
  METHOD zif_ca_ops_alert_dao~set_delivery.
    mt_saved = it_log.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_store PARTIALLY IMPLEMENTED.
    DATA mv_commits TYPE i.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_ca_ops_store~commit.
    mv_commits += 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261116090000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261116'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '090000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_confirm DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        class_mail TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_ZT_CHN_MAIL',
        class_mute TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_ZT_CHN_MUTE',
        sent_at    TYPE timestampl VALUE '20261116080000.0000000',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_alert_dao.
    DATA mo_store TYPE REF TO ltd_store.
    DATA mo_mail TYPE REF TO ltd_channel.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS alert
      IMPORTING
        iv_channel    TYPE zif_ca_ops_types=>ty_channel
        iv_status     TYPE char1 DEFAULT 'S'
      RETURNING
        VALUE(rs_log) TYPE zif_ca_ops_types=>ty_alert_log.

    METHODS confirmed_delivered      FOR TESTING RAISING zcx_ca_ops_error.
    METHODS not_confirmed_pending    FOR TESTING RAISING zcx_ca_ops_error.
    METHODS channel_cannot_confirm   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS channel_not_configured   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS failing_confirm_pending  FOR TESTING RAISING zcx_ca_ops_error.
    METHODS test_mode_writes_nothing FOR TESTING RAISING zcx_ca_ops_error.
    METHODS failed_submission_left   FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_confirm IMPLEMENTATION.

  METHOD setup.
    mo_dao   = NEW #( ).
    mo_store = NEW #( ).
    mo_mail  = NEW #( ).
    mo_seed  = NEW #( ).
    mo_dao->mt_channels = VALUE #( ( channel = 'EMAIL' class_name = gc-class_mail active = abap_true )
                                   ( channel = 'ZT_MUTE' class_name = gc-class_mute active = abap_true ) ).
    zcl_ca_ops_injector=>inject_alert_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_store( mo_store ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc-class_mail io_instance = mo_mail ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc-class_mute io_instance = NEW ltd_mute_channel( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD alert.
    rs_log = VALUE #( alert_id = '0123456789ABCDEF0123456789ABCDEF' rule_id = 'ZT_RULE' channel = iv_channel
                      area = 'ZT_OPS_A' sent_at = gc-sent_at status = iv_status ).
  ENDMETHOD.


  " Rule: the channel confirms - delivered with its time, written once, committed
  METHOD confirmed_delivered.
    mo_mail->ms_answer = VALUE #( state = zif_ca_ops_eval_types=>gc_dlv-delivered delivered_at = '20261116081000.0000000' ).
    mo_dao->mt_log = VALUE #( ( alert( 'EMAIL' ) ) ).
    DATA(ls_summary) = NEW zcl_ca_ops_alert_confirm( )->confirm( abap_false ).
    cl_abap_unit_assert=>assert_true( act = mo_dao->mv_open_only msg = 'Only undecided alerts asked' ).
    cl_abap_unit_assert=>assert_equals( act = ls_summary-delivered exp = 1 msg = 'Delivered' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-dlv_state exp = zif_ca_ops_eval_types=>gc_dlv-delivered
                                        msg = 'Stored as delivered' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-dlv_at exp = '20261116081000.0000000'
                                        msg = 'The channel''s delivery time' ).
    cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 1 msg = 'One commit' ).
  ENDMETHOD.


  " Rule: not confirmed yet - pending, no delivery time
  METHOD not_confirmed_pending.
    mo_mail->ms_answer = VALUE #( state = zif_ca_ops_eval_types=>gc_dlv-pending ).
    mo_dao->mt_log = VALUE #( ( alert( 'EMAIL' ) ) ).
    DATA(ls_summary) = NEW zcl_ca_ops_alert_confirm( )->confirm( abap_false ).
    cl_abap_unit_assert=>assert_equals( act = ls_summary-pending exp = 1 msg = 'Pending' ).
    cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_saved[ 1 ]-dlv_at msg = 'No delivery time' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-dlv_checked_at exp = '20261116090000.0000000'
                                        msg = 'Attempt recorded' ).
  ENDMETHOD.


  " Rule: a channel without CONFIRM cannot confirm - never delivered
  METHOD channel_cannot_confirm.
    mo_dao->mt_log = VALUE #( ( alert( 'ZT_MUTE' ) ) ).
    DATA(ls_summary) = NEW zcl_ca_ops_alert_confirm( )->confirm( abap_false ).
    cl_abap_unit_assert=>assert_equals( act = ls_summary-cannot_confirm exp = 1 msg = 'Cannot confirm' ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-dlv_state
                                        exp = zif_ca_ops_eval_types=>gc_dlv-cannot_confirm msg = 'Stored N' ).
  ENDMETHOD.


  " Rule: a channel no longer configured cannot confirm (with the reason)
  METHOD channel_not_configured.
    mo_dao->mt_log = VALUE #( ( alert( 'ZT_GONE' ) ) ).
    NEW zcl_ca_ops_alert_confirm( )->confirm( abap_false ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-dlv_state
                                        exp = zif_ca_ops_eval_types=>gc_dlv-cannot_confirm msg = 'Stored N' ).
    cl_abap_unit_assert=>assert_not_initial( act = mo_dao->mt_saved[ 1 ]-dlv_info msg = 'Reason' ).
  ENDMETHOD.


  " Rule: a failing CONFIRM leaves the alert undecided (asked again), never delivered
  METHOD failing_confirm_pending.
    mo_mail->mv_fail = abap_true.
    mo_dao->mt_log = VALUE #( ( alert( 'EMAIL' ) ) ).
    NEW zcl_ca_ops_alert_confirm( )->confirm( abap_false ).
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_saved[ 1 ]-dlv_state exp = zif_ca_ops_eval_types=>gc_dlv-pending
                                        msg = 'Still pending' ).
  ENDMETHOD.


  " Rule: test mode asks but writes and commits nothing
  METHOD test_mode_writes_nothing.
    mo_mail->ms_answer = VALUE #( state = zif_ca_ops_eval_types=>gc_dlv-delivered ).
    mo_dao->mt_log = VALUE #( ( alert( 'EMAIL' ) ) ).
    DATA(ls_summary) = NEW zcl_ca_ops_alert_confirm( )->confirm( abap_true ).
    cl_abap_unit_assert=>assert_equals( act = ls_summary-delivered exp = 1 msg = 'Asked' ).
    cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_saved msg = 'Nothing written' ).
    cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 0 msg = 'No commit' ).
  ENDMETHOD.


  " Rule: a failed submission has no delivery to confirm
  METHOD failed_submission_left.
    mo_dao->mt_log = VALUE #( ( alert( iv_channel = 'EMAIL' iv_status = 'F' ) ) ).
    DATA(ls_summary) = NEW zcl_ca_ops_alert_confirm( )->confirm( abap_false ).
    cl_abap_unit_assert=>assert_equals( act = ls_summary-checked exp = 0 msg = 'Not asked' ).
    cl_abap_unit_assert=>assert_equals( act = mo_mail->mv_asked exp = 0 msg = 'Channel not asked' ).
  ENDMETHOD.

ENDCLASS.
