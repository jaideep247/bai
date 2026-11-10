*&---------------------------------------------------------------------*
*& Artifact: zca_ops_check_run.prog.abap
*& Purpose:
*& Generic runner of the check registry (process onboarding framework): one
*& run of the active checks of an area and schedule group (ZCA_OPS_CHECK) -
*& ZCL_CA_OPS_CHECK_RUNNER. Schedule one job per area and schedule group.
*& Authorisation ZCA_OPS 16 for the area. Test mode (default) writes nothing
*& and sends nothing. Result as a message and, in dialog, the findings in an
*& ALV list; in background an error ends the job cancelled.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework).
*&---------------------------------------------------------------------*
REPORT zca_ops_check_run.

PARAMETERS p_area TYPE zif_ca_ops_types=>ty_area OBLIGATORY.
PARAMETERS p_group TYPE zif_ca_ops_chk_types=>ty_sched_group.
PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_column,
        group2     TYPE lvc_fname VALUE 'GROUP2',
        check_code TYPE lvc_fname VALUE 'CHECK_CODE',
        severity   TYPE lvc_fname VALUE 'SEVERITY',
        message    TYPE lvc_fname VALUE 'MESSAGE',
        object_key TYPE lvc_fname VALUE 'OBJECT_KEY',
      END OF gc_column.

    DATA mt_findings TYPE zif_ca_ops_types=>tt_finding.

    METHODS display.
    METHODS set_text
      IMPORTING
        io_columns TYPE REF TO cl_salv_columns_table
        iv_name    TYPE lvc_fname
        iv_text    TYPE clike.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    TRY.
        DATA(ls_result) = NEW zcl_ca_ops_check_runner( )->run( iv_area        = p_area
                                                               iv_sched_group = p_group
                                                               iv_test_mode   = xsdbool( p_test = abap_true ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_ops).
        " in background the job ends cancelled (scheduler red), never green
        IF sy-batch = abap_true.
          MESSAGE lx_ops TYPE 'E'.
        ENDIF.
        MESSAGE lx_ops TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    mt_findings = ls_result-findings.
    MESSAGE s102(zca_ops) WITH p_area p_group ls_result-check_count lines( mt_findings ).

    IF sy-batch = abap_false.
      display( ).
    ENDIF.
  ENDMETHOD.


  METHOD display.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = mt_findings ).
        lo_alv->get_functions( )->set_all( abap_true ).
        DATA(lo_columns) = lo_alv->get_columns( ).
        lo_columns->set_optimize( abap_true ).
        set_text( io_columns = lo_columns iv_name = gc_column-group2 iv_text = TEXT-c05 ).
        set_text( io_columns = lo_columns iv_name = gc_column-check_code iv_text = TEXT-c01 ).
        set_text( io_columns = lo_columns iv_name = gc_column-severity iv_text = TEXT-c02 ).
        set_text( io_columns = lo_columns iv_name = gc_column-message iv_text = TEXT-c03 ).
        set_text( io_columns = lo_columns iv_name = gc_column-object_key iv_text = TEXT-c04 ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD set_text.
    TRY.
        DATA(lo_column) = io_columns->get_column( iv_name ).
        lo_column->set_short_text( CONV #( iv_text ) ).
        lo_column->set_medium_text( CONV #( iv_text ) ).
        lo_column->set_long_text( CONV #( iv_text ) ).
      CATCH cx_salv_not_found ##NO_HANDLER.
        " Column of the row type only - nothing to label
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


START-OF-SELECTION.
  NEW lcl_app( )->main( ).
