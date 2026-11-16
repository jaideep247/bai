*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_alert_dlv.clas.testclasses.abap
*& Purpose:
*& Tests of the alert delivery check with doubles (alert repository,
*& in-memory parameters): a delivered alert raises nothing, a failure after
*& the submission is an error, an alert not confirmed past the grace
*& minutes a warning (within them nothing), alerts of a channel that cannot
*& confirm one notice per channel (severity of EVAL_DLV_UNCONFIRMABLE), and
*& the confirmation step is the check's source (its newest attempt is the
*& freshness of the verdict). Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build O: alert delivery confirmed separately from submission).
*&---------------------------------------------------------------------*
CLASS ltd_alert_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_alert_dao PARTIALLY IMPLEMENTED.
    DATA mt_log TYPE zif_ca_ops_types=>tt_alert_log.
ENDCLASS.

CLASS ltd_alert_dao IMPLEMENTATION.
  METHOD zif_ca_ops_alert_dao~get_submitted.
    rt_log = mt_log.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_alert_dlv DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        now     TYPE timestampl VALUE '20261116090000.0000000',
        old     TYPE timestampl VALUE '20261116080000.0000000',
        recent  TYPE timestampl VALUE '20261116085000.0000000',
        checked TYPE timestampl VALUE '20261116085500.0000000',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_alert_dao.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS run
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.
    METHODS alert
      IMPORTING
        iv_id         TYPE clike
        iv_channel    TYPE zif_ca_ops_types=>ty_channel DEFAULT 'EMAIL'
        iv_sent_at    TYPE timestampl DEFAULT gc-old
        iv_dlv        TYPE char1
      RETURNING
        VALUE(rs_log) TYPE zif_ca_ops_types=>ty_alert_log.

    METHODS delivered_no_finding      FOR TESTING RAISING zcx_ca_ops_error.
    METHODS failed_is_error           FOR TESTING RAISING zcx_ca_ops_error.
    METHODS unconfirmed_after_grace   FOR TESTING RAISING zcx_ca_ops_error.
    METHODS within_grace_nothing      FOR TESTING RAISING zcx_ca_ops_error.
    METHODS unconfirmable_one_notice  FOR TESTING RAISING zcx_ca_ops_error.
    METHODS confirmation_is_source    FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_alert_dlv IMPLEMENTATION.

  METHOD setup.
    mo_dao  = NEW #( ).
    mo_seed = NEW #( ).
    zcl_ca_ops_injector=>inject_alert_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD run.
    rs_result = NEW zcl_ca_ops_chk_alert_dlv( )->zif_ca_ops_check~run(
                  is_check   = VALUE #( area = 'CA_OPS' check_id = 'ALERT_DELIVERY' )
                  is_context = VALUE #( area = 'CA_OPS' today = '20261116' now = gc-now ) ).
  ENDMETHOD.


  METHOD alert.
    rs_log = VALUE #( alert_id = iv_id rule_id = 'ZT_RULE' channel = iv_channel area = 'ZT_OPS_A' sent_at = iv_sent_at
                      status = 'S' dlv_state = iv_dlv dlv_checked_at = gc-checked ).
  ENDMETHOD.


  METHOD delivered_no_finding.
    mo_dao->mt_log = VALUE #( ( alert( iv_id = '00000000000000000000000000000001' iv_dlv = 'D' ) ) ).
    DATA(ls_result) = run( ).
    cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'Delivered: nothing to report' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-item_count exp = 1 msg = 'Evaluated' ).
  ENDMETHOD.


  METHOD failed_is_error.
    mo_dao->mt_log = VALUE #( ( alert( iv_id = '00000000000000000000000000000002' iv_dlv = 'F' ) ) ).
    DATA(ls_result) = run( ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                        exp = zif_ca_ops_eval_types=>gc_code-dlv_failed msg = 'Failed' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-severity exp = zif_ca_ops_types=>gc_severity-error
                                        msg = 'Error' ).
  ENDMETHOD.


  METHOD unconfirmed_after_grace.
    mo_dao->mt_log = VALUE #( ( alert( iv_id = '00000000000000000000000000000003' iv_dlv = 'P' ) ) ).
    DATA(ls_result) = run( ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                        exp = zif_ca_ops_eval_types=>gc_code-not_confirmed msg = 'Not confirmed' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-severity exp = zif_ca_ops_types=>gc_severity-warning
                                        msg = 'Warning' ).
  ENDMETHOD.


  METHOD within_grace_nothing.
    mo_dao->mt_log = VALUE #( ( alert( iv_id = '00000000000000000000000000000004' iv_dlv = 'P' iv_sent_at = gc-recent ) ) ).
    DATA(ls_result) = run( ).
    cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'Within EVAL_DLV_CONFIRM_MIN' ).
  ENDMETHOD.


  METHOD unconfirmable_one_notice.
    mo_dao->mt_log = VALUE #( ( alert( iv_id = '00000000000000000000000000000005' iv_dlv = 'N' ) )
                              ( alert( iv_id = '00000000000000000000000000000006' iv_dlv = 'N' ) ) ).
    DATA(ls_result) = run( ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One notice per channel' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                        exp = zif_ca_ops_eval_types=>gc_code-unconfirmable msg = 'Cannot confirm' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-severity exp = zif_ca_ops_types=>gc_severity-info
                                        msg = 'Information by default' ).
    mo_seed->set( iv_name = zif_ca_ops_eval_types=>gc_param-unconfirmable iv_value = 'W' ).
    DATA(ls_again) = run( ).
    cl_abap_unit_assert=>assert_equals( act = ls_again-findings[ 1 ]-severity exp = zif_ca_ops_types=>gc_severity-warning
                                        msg = 'Warning when the site asks for it' ).
  ENDMETHOD.


  METHOD confirmation_is_source.
    mo_dao->mt_log = VALUE #( ( alert( iv_id = '00000000000000000000000000000007' iv_dlv = 'D' ) ) ).
    DATA(ls_result) = run( ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-sources[ 1 ]-source_id exp = zcl_ca_ops_chk_alert_dlv=>gc_source
                                        msg = 'The confirmation step is the source' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-eval-sources[ 1 ]-newest_at exp = gc-checked
                                        msg = 'Its newest attempt' ).
  ENDMETHOD.

ENDCLASS.
