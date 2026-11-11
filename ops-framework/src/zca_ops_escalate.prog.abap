*&---------------------------------------------------------------------*
*& Artifact: zca_ops_escalate.prog.abap
*& Purpose:
*& Escalation until acknowledged (operations response features): escalates
*& the open, unassigned exceptions of an area whose next escalation step is
*& due under the alert rules with ESC_AFTER_MIN (ZCA_OPS_ALRULE) -
*& ZIF_CA_OPS_ALERT=>ESCALATE. Schedule one job per area every 5 to 15
*& minutes (the cadence bounds how late a step goes out). Authorisation
*& ZCA_OPS 16 for the area. Every attempt is logged in ZCA_OPS_ALLOG
*& (ESC_STEP); a step is never sent twice. In background an error ends the
*& job cancelled.
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: escalation until acknowledged).
*&---------------------------------------------------------------------*
REPORT zca_ops_escalate.

PARAMETERS p_area TYPE zif_ca_ops_types=>ty_area OBLIGATORY.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        DATA(ls_result) = zcl_ca_ops_factory=>get_alert( )->escalate( p_area ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        " in background the job ends cancelled (scheduler red), never green
        IF sy-batch = abap_true.
          MESSAGE lx_error TYPE 'E'.
        ENDIF.
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.
    " the deliveries were committed one by one (claim, then final status) by the router
    MESSAGE s156(zca_ops) WITH p_area ls_result-escalated ls_result-skipped ls_result-failed.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->main( ).
