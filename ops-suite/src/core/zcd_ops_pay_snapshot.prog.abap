*&---------------------------------------------------------------------*
*& Artifact: zcd_ops_pay_snapshot.prog.abap
*& Purpose:
*& Job step of the 5-minute SM36 job ZCD_FMON_MONITOR_ALL (step 2, after
*& ZCD_FMON_MONITOR): incremental snapshot of the canonical payment outcome
*& (ZCL_CD_OPS_PAY_SNAPSHOT) - only payments with new evidence since the
*& watermark of each source, a version only when the outcome changes.
*& Authorisation ZCD_OPS activity 16 payment engine area CORE. Test mode
*& evaluates and counts, writes nothing. One job-log message per source;
*& ALV result in dialog. No WRITE lists. Changes nothing in file monitoring.
*& Modification log:
*& 2026-11-07 | Initial version (incremental 5-minute payment outcome snapshot).
*&---------------------------------------------------------------------*
REPORT zcd_ops_pay_snapshot.

PARAMETERS p_test AS CHECKBOX DEFAULT space.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    DATA mt_sources TYPE zif_cd_ops_payout_types=>tt_source_result.

    METHODS display.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        zcl_cd_ops_factory=>get_auth( )->check( iv_activity = zif_cd_ops_auth=>gc_activity-execute
                                                iv_pe_area  = zif_cd_ops_types=>gc_pe_area-core ).
        DATA(ls_result) = NEW zcl_cd_ops_pay_snapshot( )->run( xsdbool( p_test = abap_true ) ).
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
         WHERE check_code = zif_cd_ops_payout_types=>gc_code-snapshot_failed.
      MESSAGE <ls_finding>-message TYPE 'S' DISPLAY LIKE 'E'.
    ENDLOOP.

    IF sy-batch = abap_false.
      display( ).
    ENDIF.
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
