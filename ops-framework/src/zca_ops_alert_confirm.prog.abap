*&---------------------------------------------------------------------*
*& Artifact: zca_ops_alert_confirm.prog.abap
*& Purpose:
*& Alert delivery confirmation (docs/EVALUATION_AND_COVERAGE.md section
*& 4): asks the channel of every submitted alert of the look-back whose
*& delivery is not decided yet (ZCL_CA_OPS_ALERT_CONFIRM) and stores the
*& answer (delivered, pending, failed, cannot confirm), then - when a
*& schedule group is given - runs the registered checks of area CA_OPS in
*& that group (the delivery check ZCL_CA_OPS_CHK_ALERT_DLV, group
*& ALERTDLV), so what stays unconfirmed becomes a finding in the same job.
*& Authorisation ZCA_OPS 16 for area CA_OPS. Test mode (default) writes
*& nothing. One job log line (575); in background an error ends the job
*& cancelled. Schedule it every 15 minutes. Never sends again.
*& Modification log:
*& 2026-11-16 | Initial version (build O: alert delivery confirmed separately from submission).
*&---------------------------------------------------------------------*
REPORT zca_ops_alert_confirm.

PARAMETERS p_group TYPE zif_ca_ops_chk_types=>ty_sched_group DEFAULT 'ALERTDLV'.
PARAMETERS p_test TYPE abap_bool AS CHECKBOX DEFAULT abap_true.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-execute
                                                iv_area     = zif_ca_ops_types=>gc_param_area ).
        DATA(ls_summary) = NEW zcl_ca_ops_alert_confirm( )->confirm( p_test ).
        MESSAGE s575(zca_ops) WITH ls_summary-checked ls_summary-delivered ls_summary-pending
                                   ls_summary-cannot_confirm.
        IF p_group IS NOT INITIAL.
          NEW zcl_ca_ops_check_runner( )->run( iv_area        = zif_ca_ops_types=>gc_param_area
                                               iv_sched_group = p_group
                                               iv_test_mode   = p_test ).
        ENDIF.
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        " in background the job ends cancelled (scheduler red), never green
        IF sy-batch = abap_true.
          MESSAGE lx_error TYPE 'E'.
        ENDIF.
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->main( ).
