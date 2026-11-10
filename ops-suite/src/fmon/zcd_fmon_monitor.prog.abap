*&---------------------------------------------------------------------*
*& Artifact: zcd_fmon_monitor.prog.abap
*& Purpose:
*& File monitoring run and file status board: runs ZCL_CD_FMON_ENGINE for
*& a business date (optionally one interface, test mode) and shows the
*& board or the findings as ALV (CL_SALV_TABLE). No WRITE lists.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Authorisation ZCD_OPS activity 16 payment engine area FMON at start.
*& 2026-11-06 | Refused run (run lock held) reported; job ends in error in background.
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-10 | In background an error ends the job with a type E message (was S: the job ended green).
*&---------------------------------------------------------------------*
REPORT zcd_fmon_monitor.

PARAMETERS p_date TYPE d DEFAULT sy-datum OBLIGATORY.
PARAMETERS p_iface TYPE c LENGTH 20.
PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_find AS CHECKBOX DEFAULT ' '.


"! SALV exception column of the file board (traffic light of the SLA)
CONSTANTS gc_light_column TYPE lvc_fname VALUE 'SLA_LIGHT'.

CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    DATA mt_board TYPE zif_cd_fmon_types=>tt_board.
    DATA mt_findings TYPE zif_ca_ops_types=>tt_finding.

    METHODS show_board.
    METHODS show_findings.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-execute
                                                iv_pe_area   = zif_cd_ops_types=>gc_pe_area-file_monitor ).
        DATA(ls_result) = zcl_cd_fmon_factory=>get_engine( )->run(
          iv_business_date = p_date
          iv_iface_id      = CONV #( to_upper( p_iface ) )
          iv_test_mode     = xsdbool( p_test = abap_true ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_ops).
        " B9: in background the job ends cancelled (Control-M red), never green
        IF sy-batch = abap_true.
          MESSAGE lx_ops TYPE 'E'.
        ENDIF.
        MESSAGE lx_ops TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    IF zcl_ca_ops_run_guard=>was_refused( ls_result-findings ) = abap_true.
      " Run lock held: background job ends in error so Control-M shows it
      IF sy-batch = abap_true.
        MESSAGE ls_result-run-message TYPE 'E'.
      ENDIF.
      MESSAGE ls_result-run-message TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    mt_board    = ls_result-board.
    mt_findings = ls_result-findings.
    DATA(lv_findings) = lines( mt_findings ).
    MESSAGE s220(zcd_ops) WITH p_date ls_result-run-total_items lv_findings ls_result-run-rag.

    IF p_find = abap_true.
      show_findings( ).
    ELSE.
      show_board( ).
    ENDIF.
  ENDMETHOD.


  METHOD show_board.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = mt_board ).
        lo_alv->get_functions( )->set_all( abap_true ).
        DATA(lo_columns) = lo_alv->get_columns( ).
        lo_columns->set_optimize( abap_true ).
        lo_columns->set_exception_column( gc_light_column ).
        lo_alv->display( ).
      CATCH cx_salv_msg cx_salv_data_error INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD show_findings.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = mt_findings ).
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
