*&---------------------------------------------------------------------*
*& Artifact: zca_ops_flow_run.prog.abap
*& Purpose:
*& Account flow reconciliation (docs/ACCOUNT_FLOW.md): evaluates the
*& active account flows of an area (or one flow) at a key date - for every
*& account of the flow what existing checks account for in its closing
*& position (break analysis, open FI-CA items, open exceptions of the
*& stage checks; the plug-in of the account) - and saves one evaluation
*& per flow (committed per flow), which the dashboard compares with the
*& closing position of the same date. Key date blank = today minus
*& FLOW_KEY_DATE_LAG days. Test mode (default) writes nothing.
*& Authorisation ZCA_OPS 16 for the area. Read-only towards business data.
*& One line per flow in the job log (message 320 or 323), one per
*& configuration problem (324-329) and per account not evaluated (321);
*& in background an error ends the job cancelled. Schedule after the
*& break analysis and the checks of the day.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
REPORT zca_ops_flow_run.

PARAMETERS p_area TYPE zif_ca_ops_types=>ty_area OBLIGATORY.
PARAMETERS p_flow TYPE zif_ca_ops_flow_types=>ty_flow_id.
PARAMETERS p_kdate TYPE d.
PARAMETERS p_test TYPE abap_bool AS CHECKBOX DEFAULT abap_true.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    "! The key date: entered, else today minus FLOW_KEY_DATE_LAG
    METHODS key_date
      RETURNING
        VALUE(rv_date) TYPE d.

    "! Job log lines of one flow: the problems, the accounts not evaluated, the summary
    METHODS log_result
      IMPORTING
        is_result TYPE zif_ca_ops_flow_types=>ty_result.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    DATA(lv_key_date) = key_date( ).
    TRY.
        DATA(lt_results) = NEW zcl_ca_ops_flow_eval( )->evaluate( iv_area      = p_area
                                                                  iv_flow_id   = p_flow
                                                                  iv_key_date  = lv_key_date
                                                                  iv_test_mode = p_test ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        " in background the job ends cancelled (scheduler red), never green
        IF sy-batch = abap_true.
          MESSAGE lx_error TYPE 'E'.
        ENDIF.
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.
    IF lt_results IS INITIAL.
      MESSAGE s336(zca_ops) WITH p_area p_flow.
      RETURN.
    ENDIF.
    LOOP AT lt_results ASSIGNING FIELD-SYMBOL(<ls_result>).
      log_result( <ls_result> ).
    ENDLOOP.
  ENDMETHOD.


  METHOD log_result.
    LOOP AT is_result-problems ASSIGNING FIELD-SYMBOL(<ls_problem>).
      MESSAGE zcl_ca_ops_util=>text( iv_msgno = <ls_problem>-msgno
                                     iv_v1    = <ls_problem>-v1
                                     iv_v2    = <ls_problem>-v2
                                     iv_v3    = <ls_problem>-v3
                                     iv_v4    = <ls_problem>-v4 ) TYPE 'S'.
    ENDLOOP.
    IF is_result-skipped = abap_true.
      RETURN.
    ENDIF.
    LOOP AT is_result-items ASSIGNING FIELD-SYMBOL(<ls_item>)
         WHERE status = zif_ca_ops_flow_types=>gc_item_status-not_evaluated.
      MESSAGE s321(zca_ops) WITH <ls_item>-flow_acct is_result-eval-flow_id <ls_item>-reason(50).
    ENDLOOP.
    IF is_result-purged > 0.
      MESSAGE s335(zca_ops) WITH is_result-eval-flow_id is_result-eval-key_date is_result-purged.
    ENDIF.
    MESSAGE is_result-eval-message TYPE 'S'.
  ENDMETHOD.


  METHOD key_date.
    rv_date = p_kdate.
    IF rv_date IS INITIAL.
      rv_date = zcl_ca_ops_factory=>get_clock( )->today( )
              - zcl_ca_ops_util=>param_int( io_params  = zcl_ca_ops_factory=>get_params( )
                                            iv_name    = zif_ca_ops_flow_types=>gc_param-key_lag
                                            iv_default = zif_ca_ops_flow_types=>gc_default-key_lag ).
    ENDIF.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->main( ).
