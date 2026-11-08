*&---------------------------------------------------------------------*
*& Artifact: zcd_ops_pay_snapshot.prog.abap
*& Purpose:
*& The payment worklist (ZCL_CD_OPS_PAY_SNAPSHOT, open payments, open
*& payment requests and exceptions only) in one of three modes:
*& FAST - step 2 of the 5-minute SM36 job ZCD_FMON_MONITOR_ALL (after
*& ZCD_FMON_MONITOR): only new payments, requests and evidence since the
*& watermark of each source; NIGHTLY - once a night (own job step, variant
*& ZCD_PAY_NIGHTLY): every open and exception row re-evaluated (late
*& payments, requests past their due date); SWEEP - on demand in the
*& background: the evidence sources chosen re-read for a date range,
*& without moving a watermark, packaged and bounded. Authorisation ZCD_OPS
*& activity 16 payment engine area CORE. Test mode evaluates and counts,
*& writes nothing. One job-log message per source; ALV result in dialog.
*& No WRITE lists. Changes nothing in file monitoring.
*& Modification log:
*& 2026-11-07 | Initial version (incremental 5-minute payment outcome snapshot).
*& 2026-11-08 | Job log: the snapshot lag after the run (message 761, limit MON_STALE_AFTER_MIN_CORE) or
*&            | "not run yet" (762); parallel packages are the class's (PAYOUT_PARALLEL).
*& 2026-11-08 | Exceptions-only worklist: modes FAST (default, unchanged job step), NIGHTLY and SWEEP (date
*&            | range and evidence sources); the lag is said after a FAST run only.
*&---------------------------------------------------------------------*
REPORT zcd_ops_pay_snapshot.

DATA gv_source TYPE zif_cd_ops_payout_types=>ty_source_id.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  PARAMETERS p_fast  RADIOBUTTON GROUP mode.
  PARAMETERS p_night RADIOBUTTON GROUP mode.
  PARAMETERS p_sweep RADIOBUTTON GROUP mode.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-b02.
  PARAMETERS p_from TYPE d.
  PARAMETERS p_to TYPE d.
  SELECT-OPTIONS s_src FOR gv_source NO INTERVALS.
SELECTION-SCREEN END OF BLOCK b02.

PARAMETERS p_test AS CHECKBOX DEFAULT space.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    DATA mt_sources TYPE zif_cd_ops_payout_types=>tt_source_result.

    "! Mode, SWEEP range and sources from the selection screen
    METHODS selection
      RETURNING
        VALUE(rs_selection) TYPE zif_cd_ops_payout_types=>ty_selection.

    METHODS display.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        zcl_cd_ops_factory=>get_auth( )->check( iv_activity = zif_cd_ops_auth=>gc_activity-execute
                                                iv_pe_area  = zif_cd_ops_types=>gc_pe_area-core ).
        DATA(ls_result) = NEW zcl_cd_ops_pay_snapshot( )->run( iv_test_mode = xsdbool( p_test = abap_true )
                                                               is_selection = selection( ) ).
      CATCH zcx_cd_ops_error INTO DATA(lx_ops).
        MESSAGE lx_ops TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    mt_sources = ls_result-sources.
    LOOP AT mt_sources ASSIGNING FIELD-SYMBOL(<ls_source>).
      MESSAGE ID zif_cd_ops_types=>gc_message_class TYPE 'S' NUMBER zif_cd_ops_payout_types=>gc_msg-source_result
        WITH <ls_source>-source <ls_source>-documents <ls_source>-evaluated <ls_source>-inserted.
    ENDLOOP.
    LOOP AT ls_result-findings ASSIGNING FIELD-SYMBOL(<ls_finding>)
         WHERE check_code = zif_cd_ops_payout_types=>gc_code-snapshot_failed
            OR check_code = zif_cd_ops_payout_types=>gc_code-batch_incomplete.
      MESSAGE <ls_finding>-message TYPE 'S' DISPLAY LIKE 'E'.
    ENDLOOP.
    " The snapshot lag after a FAST run (the production-support freshness row shows the same)
    IF ls_result-mode = zif_cd_ops_payout_types=>gc_mode-fast AND ls_result-lag-known = abap_true.
      DATA(lv_limit) = zcl_cd_ops_util=>param_int(
                         io_params  = zcl_cd_ops_factory=>get_params( )
                         iv_name    = CONV #( |{ zif_cd_ops_types=>gc_param_prefix-stale_after_min }| &&
                                              |{ zif_cd_ops_types=>gc_pe_area-core }| )
                         iv_default = zif_cd_ops_payout_types=>gc_param_default-stale_after_min ).
      MESSAGE ID zif_cd_ops_types=>gc_message_class TYPE 'S' NUMBER zif_cd_ops_payout_types=>gc_msg-snapshot_lag
        WITH ls_result-lag-minutes lv_limit ls_result-lag-source |{ ls_result-lag-current_to TIMESTAMP = ISO }|.
    ELSEIF ls_result-mode = zif_cd_ops_payout_types=>gc_mode-fast.
      MESSAGE ID zif_cd_ops_types=>gc_message_class TYPE 'S' NUMBER zif_cd_ops_payout_types=>gc_msg-snapshot_never
        WITH zif_cd_ops_types=>gc_pe_area-core.
    ENDIF.

    IF sy-batch = abap_false.
      display( ).
    ENDIF.
  ENDMETHOD.


  METHOD selection.
    rs_selection-mode = COND #( WHEN p_night = abap_true THEN zif_cd_ops_payout_types=>gc_mode-nightly
                                WHEN p_sweep = abap_true THEN zif_cd_ops_payout_types=>gc_mode-sweep
                                WHEN p_fast = abap_true  THEN zif_cd_ops_payout_types=>gc_mode-fast ).
    IF rs_selection-mode <> zif_cd_ops_payout_types=>gc_mode-sweep.
      RETURN.
    ENDIF.
    rs_selection-date_from = p_from.
    rs_selection-date_to   = p_to.
    LOOP AT s_src ASSIGNING FIELD-SYMBOL(<ls_source>).
      INSERT to_upper( <ls_source>-low ) INTO TABLE rs_selection-sources.
    ENDLOOP.
  ENDMETHOD.


  METHOD display.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = mt_sources ).
        lo_alv->get_functions( )->set_all( abap_true ).
        lo_alv->get_columns( )->set_optimize( abap_true ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->main( ).
