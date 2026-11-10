*&---------------------------------------------------------------------*
*& Artifact: zca_ops_retention.prog.abap
*& Purpose:
*& Retention purge of the operations framework (ZCL_CA_OPS_PURGE): runs with
*& findings and exception history, alert log and every target a consumer
*& registered in ZCA_OPS_PURGE. Test mode (default) only counts.
*& Authorisation ZCA_OPS activity 16 for area CA_OPS. Scheduled monthly by
*& the job scheduler with test mode off. One job-log message per target;
*& ALV result in dialog. No WRITE lists.
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-10 | In background an error ends the job with a type E message (was S: the job ended green).
*& 2026-11-10 | Moved from ZCD_OPS_PURGE to the reusable framework ZCA_OPS (authorisation ZCA_OPS for area
*&            | CA_OPS, registered consumer targets, mode texts as text symbols).
*&---------------------------------------------------------------------*
REPORT zca_ops_retention.

PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    DATA mt_results TYPE zcl_ca_ops_purge=>tt_result.

    METHODS display.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-execute
                                                iv_area     = zif_ca_ops_types=>gc_param_area ).
        mt_results = NEW zcl_ca_ops_purge( )->run( xsdbool( p_test = abap_true ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_ops).
        " in background the job ends cancelled (scheduler red), never green
        IF sy-batch = abap_true.
          MESSAGE lx_ops TYPE 'E'.
        ENDIF.
        MESSAGE lx_ops TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    DATA(lv_mode) = COND string( WHEN p_test = abap_true THEN TEXT-m01 ELSE TEXT-m02 ).
    LOOP AT mt_results ASSIGNING FIELD-SYMBOL(<ls_result>).
      MESSAGE s060(zca_ops) WITH <ls_result>-target <ls_result>-rows <ls_result>-cutoff lv_mode.
    ENDLOOP.

    IF sy-batch = abap_false.
      display( ).
    ENDIF.
  ENDMETHOD.


  METHOD display.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = mt_results ).
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
