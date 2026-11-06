*&---------------------------------------------------------------------*
*& Artifact: zcd_ops_purge.prog.abap
*& Purpose:
*& Retention purge of the operations suite's history (ZCL_CD_OPS_PURGE):
*& runs with findings, alert log, FMON events, HCK metrics. Test mode (default)
*& only counts. Authorisation ZCD_OPS activity 16 module CORE. Scheduled monthly
*& by Control-M with test mode off. One job-log message per target; ALV result
*& in dialog. No WRITE lists.
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
*&---------------------------------------------------------------------*
REPORT zcd_ops_purge.

PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    DATA mt_results TYPE zcl_cd_ops_purge=>tt_result.

    METHODS display.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        zcl_cd_ops_factory=>get_auth( )->check( iv_activity = zif_cd_ops_auth=>gc_activity-execute
                                                iv_module   = zif_cd_ops_types=>gc_module-core ).
        mt_results = NEW zcl_cd_ops_purge( )->run( xsdbool( p_test = abap_true ) ).
      CATCH zcx_cd_ops_error INTO DATA(lx_ops).
        MESSAGE lx_ops TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    DATA(lv_mode) = COND string( WHEN p_test = abap_true THEN `test mode, nothing deleted` ELSE `deleted` ).
    LOOP AT mt_results INTO DATA(ls_result).
      MESSAGE s060(zcd_ops) WITH ls_result-target ls_result-rows ls_result-cutoff lv_mode.
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
