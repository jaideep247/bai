*&---------------------------------------------------------------------*
*& Artifact: zcd_ops_payment_trace.prog.abap
*& Purpose:
*& 360 degree payment trace for L1 / L2 support (read-only): enter a FIN
*& ID + source, a clearing / payment document or a cheque number; shows
*& the evidence timeline (request, open item, clearing-reset history,
*& payment, file, PRISM handoff, bank ACK, settlement or return, payment
*& engine clearing, G/L) per payment attempt as ALV with status light,
*& source record, key and timestamp; the first missing milestone is
*& flagged. Authorisation ZCD_OPS display (03), area CORE, and per company
*& code in the engine. Writes nothing, posts nothing, starts no job.
*& Modification log:
*& 2026-11-06 | Initial version (360 degree payment trace).
*&---------------------------------------------------------------------*
REPORT zcd_ops_payment_trace.

TYPES ty_fin TYPE zif_cd_ops_trace_types=>ty_fin.
TYPES ty_source TYPE zif_cd_ops_trace_types=>ty_source.
TYPES ty_docno TYPE zif_cd_ops_trace_types=>ty_docno.
TYPES ty_ref TYPE zif_cd_ops_trace_types=>ty_ref.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  PARAMETERS p_fin TYPE ty_fin.
  PARAMETERS p_src TYPE ty_source.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-b02.
  PARAMETERS p_augbl TYPE ty_docno.
  PARAMETERS p_chect TYPE ty_ref.
SELECTION-SCREEN END OF BLOCK b02.


CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS main.

  PRIVATE SECTION.
    "! Columns of ZIF_CD_OPS_TRACE_TYPES=>TY_TRACE_ROW: exception column (status light),
    "! hidden technical column and the labelled columns
    CONSTANTS:
      BEGIN OF gc_column,
        light         TYPE lvc_fname VALUE 'LIGHT',
        seq           TYPE lvc_fname VALUE 'SEQ',
        attempt       TYPE lvc_fname VALUE 'ATTEMPT',
        attempt_kind  TYPE lvc_fname VALUE 'ATTEMPT_KIND',
        clearing_ref  TYPE lvc_fname VALUE 'CLEARING_REF',
        stage         TYPE lvc_fname VALUE 'STAGE',
        status        TYPE lvc_fname VALUE 'STATUS',
        first_gap     TYPE lvc_fname VALUE 'FIRST_GAP',
        reason        TYPE lvc_fname VALUE 'REASON',
        source_table  TYPE lvc_fname VALUE 'SOURCE_TABLE',
        record_key    TYPE lvc_fname VALUE 'RECORD_KEY',
        evidence_date TYPE lvc_fname VALUE 'EVIDENCE_DATE',
        evidence_time TYPE lvc_fname VALUE 'EVIDENCE_TIME',
        time_zone     TYPE lvc_fname VALUE 'TIME_ZONE',
        detail        TYPE lvc_fname VALUE 'DETAIL',
      END OF gc_column.

    DATA mt_rows TYPE zif_cd_ops_trace_types=>tt_trace_row.

    METHODS display.
    METHODS set_texts
      IMPORTING
        io_columns TYPE REF TO cl_salv_columns_table.
    METHODS set_text
      IMPORTING
        io_columns TYPE REF TO cl_salv_columns_table
        iv_name    TYPE lvc_fname
        iv_text    TYPE clike.
ENDCLASS.


CLASS lcl_app IMPLEMENTATION.

  METHOD main.
    IF p_fin IS INITIAL AND p_augbl IS INITIAL AND p_chect IS INITIAL.
      MESSAGE s731(zcd_ops) DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.
    TRY.
        zcl_cd_ops_factory=>get_auth( )->check( iv_activity = zif_cd_ops_auth=>gc_activity-display
                                                iv_pe_area  = zif_cd_ops_types=>gc_pe_area-core ).
      CATCH zcx_cd_ops_error INTO DATA(lx_ops).
        MESSAGE lx_ops TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    DATA(ls_result) = NEW zcl_cd_ops_trace_engine( )->trace(
      VALUE #( fin          = to_upper( p_fin )
               source       = to_upper( p_src )
               clearing_doc = |{ p_augbl ALPHA = IN }|
               check_no     = p_chect ) ).
    mt_rows = ls_result-rows.
    MESSAGE s700(zcd_ops) WITH ls_result-verdict ls_result-first_gap_stage ls_result-first_gap_attempt
                               ls_result-attempts.
    IF sy-batch = abap_false.
      display( ).
    ENDIF.
  ENDMETHOD.


  METHOD display.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = mt_rows ).
        lo_alv->get_functions( )->set_all( abap_true ).
        DATA(lo_columns) = lo_alv->get_columns( ).
        lo_columns->set_optimize( abap_true ).
        lo_columns->set_exception_column( gc_column-light ).
        lo_columns->get_column( gc_column-seq )->set_technical( abap_true ).
        set_texts( lo_columns ).
        lo_alv->display( ).
      CATCH cx_salv_msg cx_salv_not_found cx_salv_data_error INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD set_texts.
    set_text( io_columns = io_columns iv_name = gc_column-attempt iv_text = TEXT-c01 ).
    set_text( io_columns = io_columns iv_name = gc_column-attempt_kind iv_text = TEXT-c02 ).
    set_text( io_columns = io_columns iv_name = gc_column-clearing_ref iv_text = TEXT-c03 ).
    set_text( io_columns = io_columns iv_name = gc_column-stage iv_text = TEXT-c04 ).
    set_text( io_columns = io_columns iv_name = gc_column-status iv_text = TEXT-c05 ).
    set_text( io_columns = io_columns iv_name = gc_column-first_gap iv_text = TEXT-c06 ).
    set_text( io_columns = io_columns iv_name = gc_column-reason iv_text = TEXT-c07 ).
    set_text( io_columns = io_columns iv_name = gc_column-source_table iv_text = TEXT-c08 ).
    set_text( io_columns = io_columns iv_name = gc_column-record_key iv_text = TEXT-c09 ).
    set_text( io_columns = io_columns iv_name = gc_column-evidence_date iv_text = TEXT-c10 ).
    set_text( io_columns = io_columns iv_name = gc_column-evidence_time iv_text = TEXT-c11 ).
    set_text( io_columns = io_columns iv_name = gc_column-time_zone iv_text = TEXT-c12 ).
    set_text( io_columns = io_columns iv_name = gc_column-detail iv_text = TEXT-c13 ).
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
