*&---------------------------------------------------------------------*
*& Artifact: zcd_morning_report.prog.abap
*& Purpose:
*& Payment engine morning report: runs the configured health checks, shows
*& the scorecard and results in ALV, mails the HTML report, exports CSV.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Authorisation ZCD_OPS activity 16 payment engine area HCK at start.
*& 2026-11-06 | Refused run (run lock held) reported; job ends in error in background.
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Export through ZCL_CD_HCK_EXPORT: complete file or none (audit A61).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Modern-syntax sweep: string templates.
*& 2026-11-10 | In background an error ends the job with a type E message (was S: the job ended green).
*& 2026-11-10 | Export: P_FILE is a file name only, resolved in logical path ZCD_OPS_HCK_OUT (FILE), validated
*&            | and checked with S_DATASET WRITE (ZCL_CA_OPS_FILE_PATH); temporary file and the delete on
*&            | error work only on that validated path.
*&---------------------------------------------------------------------*
*& Presentation layer only: no SQL here. Engine ZCL_CD_HCK_ENGINE, renderer
*& ZCL_CD_HCK_REPORT_HTML. Schedule daily (Control-M) with a variant that
*& has P_MAIL = X and P_TEST = space; in background the ALV goes to spool.
*& Text symbols B01-B04 and selection texts: see docs/HCK_MORNING_REPORT.md.
*&---------------------------------------------------------------------*
REPORT zcd_morning_report.

DATA gv_category TYPE zif_cd_hck_types=>ty_category.
DATA gv_priority TYPE zif_cd_hck_types=>ty_priority.
DATA gv_check_id TYPE zif_cd_hck_types=>ty_check_id.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
  PARAMETERS p_today RADIOBUTTON GROUP win DEFAULT 'X'.
  PARAMETERS p_yday RADIOBUTTON GROUP win.
  PARAMETERS p_cust RADIOBUTTON GROUP win.
  PARAMETERS p_date TYPE d DEFAULT sy-datum.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-b02.
  SELECT-OPTIONS s_cat FOR gv_category NO INTERVALS.
  SELECT-OPTIONS s_prio FOR gv_priority NO INTERVALS.
  SELECT-OPTIONS s_check FOR gv_check_id.
  PARAMETERS p_mods AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b02.

SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE TEXT-b03.
  PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.
  PARAMETERS p_mail AS CHECKBOX.
  PARAMETERS p_exc AS CHECKBOX DEFAULT 'X'.
  PARAMETERS p_exp AS CHECKBOX.
  PARAMETERS p_file TYPE string LOWER CASE.
SELECTION-SCREEN END OF BLOCK b03.

SELECTION-SCREEN BEGIN OF BLOCK b04 WITH FRAME TITLE TEXT-b04.
  PARAMETERS p_base AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b04.


"! Technical values of the report: SALV exception column and its values, dataset activity
CONSTANTS gc_light_column TYPE lvc_fname VALUE 'LIGHT'.
CONSTANTS:
  BEGIN OF gc_light,
    red    TYPE c LENGTH 1 VALUE '1',
    yellow TYPE c LENGTH 1 VALUE '2',
    green  TYPE c LENGTH 1 VALUE '3',
    none   TYPE c LENGTH 1 VALUE ' ',
  END OF gc_light.

CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.

    TYPES:
      BEGIN OF ty_alv_result,
        light        TYPE c LENGTH 1,
        check_id     TYPE zif_cd_hck_types=>ty_check_id,
        category     TYPE zif_cd_hck_types=>ty_category,
        cat_text     TYPE zif_cd_hck_types=>ty_text,
        priority     TYPE zif_cd_hck_types=>ty_priority,
        rag          TYPE zif_ca_ops_types=>ty_rag,
        description  TYPE zif_cd_hck_types=>ty_text,
        summary      TYPE zif_ca_ops_types=>ty_message,
        findings     TYPE i,
        metrics      TYPE i,
        runtime_ms   TYPE i,
        timed_out    TYPE abap_bool,
        plugin_error TYPE abap_bool,
      END OF ty_alv_result.
    TYPES tt_alv_result TYPE STANDARD TABLE OF ty_alv_result WITH EMPTY KEY.

    TYPES:
      BEGIN OF ty_alv_finding,
        severity   TYPE zif_ca_ops_types=>ty_severity,
        check_code TYPE zif_ca_ops_types=>ty_check_code,
        object_key TYPE zif_ca_ops_types=>ty_object_key,
        reference  TYPE zif_ca_ops_types=>ty_reference,
        message    TYPE zif_ca_ops_types=>ty_message,
      END OF ty_alv_finding.
    TYPES tt_alv_finding TYPE STANDARD TABLE OF ty_alv_finding WITH EMPTY KEY.

    METHODS run.

    METHODS validate.

  PRIVATE SECTION.

    DATA ms_report TYPE zif_cd_hck_types=>ty_report.
    DATA mt_alv TYPE tt_alv_result.

    METHODS selection
      RETURNING
        VALUE(rs_selection) TYPE zif_cd_hck_types=>ty_selection.

    METHODS take_baseline.

    METHODS build_alv_rows.

    METHODS display_results.

    METHODS display_exceptions.

    METHODS header
      RETURNING
        VALUE(ro_grid) TYPE REF TO cl_salv_form_layout_grid.

    METHODS export_csv.

    METHODS on_double_click
      FOR EVENT double_click OF cl_salv_events_table
      IMPORTING
        row.

    METHODS show_popup
      CHANGING
        ct_table TYPE STANDARD TABLE.

    METHODS light
      IMPORTING
        iv_rag          TYPE zif_ca_ops_types=>ty_rag
      RETURNING
        VALUE(rv_light) TYPE char1.

ENDCLASS.



CLASS lcl_app IMPLEMENTATION.

  METHOD validate.
    IF p_cust = abap_true AND p_date IS INITIAL.
      MESSAGE e353(zcd_ops).
    ENDIF.
    IF p_exp = abap_true AND p_file IS INITIAL.
      MESSAGE e354(zcd_ops).
    ENDIF.
    IF p_mail = abap_true AND p_test = abap_true.
      " test mode never mails - say so instead of silently ignoring the flag
      MESSAGE w355(zcd_ops).
    ENDIF.
  ENDMETHOD.


  METHOD run.
    TRY.
        zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-execute
                                                iv_pe_area   = zif_cd_ops_types=>gc_pe_area-health_check ).
      CATCH zcx_ca_ops_error INTO DATA(lx_auth).
        " B9: in background the job ends cancelled (Control-M red), never green
        IF sy-batch = abap_true.
          MESSAGE lx_auth TYPE 'E'.
        ENDIF.
        MESSAGE lx_auth TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.
    IF p_base = abap_true.
      take_baseline( ).
      RETURN.
    ENDIF.

    TRY.
        ms_report = zcl_cd_hck_factory=>get_engine( )->run( selection( ) ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        " B9: in background the job ends cancelled (Control-M red), never green
        IF sy-batch = abap_true.
          MESSAGE lx_error TYPE 'E'.
        ENDIF.
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.
    IF zcl_ca_ops_run_guard=>was_refused( VALUE #( ms_report-results[ 1 ]-findings OPTIONAL ) ) = abap_true.
      " Run lock held: background job ends in error so Control-M shows it
      IF sy-batch = abap_true.
        MESSAGE ms_report-run-message TYPE 'E'.
      ENDIF.
      MESSAGE ms_report-run-message TYPE 'S' DISPLAY LIKE 'E'.
      RETURN.
    ENDIF.

    build_alv_rows( ).
    IF p_exp = abap_true.
      export_csv( ).
    ENDIF.
    display_results( ).
    IF p_exc = abap_true.
      display_exceptions( ).
    ENDIF.
  ENDMETHOD.


  METHOD selection.
    " quick date window: today / yesterday / custom date
    rs_selection-report_date     = COND #( WHEN p_today = abap_true THEN sy-datum
                                           WHEN p_yday = abap_true  THEN sy-datum - 1
                                           ELSE p_date ).
    rs_selection-categories      = CORRESPONDING #( s_cat[] ).
    rs_selection-priorities      = CORRESPONDING #( s_prio[] ).
    rs_selection-check_ids       = CORRESPONDING #( s_check[] ).
    rs_selection-include_pe_areas = p_mods.
    rs_selection-send_mail       = xsdbool( p_mail = abap_true AND p_test = abap_false ).
    rs_selection-test_mode       = p_test.
    rs_selection-variant         = sy-slset.
  ENDMETHOD.


  METHOD take_baseline.
    TRY.
        DATA(lv_count) = zcl_cd_hck_factory=>get_engine( )->take_baseline( p_test ).
        MESSAGE s314(zcd_ops) WITH lv_count COND string( WHEN p_test = abap_true THEN TEXT-t01 ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        " B9: in background the job ends cancelled (Control-M red), never green
        IF sy-batch = abap_true.
          MESSAGE lx_error TYPE 'E'.
        ENDIF.
        MESSAGE lx_error TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD build_alv_rows.
    DATA ls_row TYPE ty_alv_result.
    CLEAR mt_alv.
    LOOP AT ms_report-results ASSIGNING FIELD-SYMBOL(<ls_result>).
      CLEAR ls_row.
      ls_row-light        = light( <ls_result>-rag ).
      ls_row-check_id     = <ls_result>-check_id.
      ls_row-category     = <ls_result>-category.
      ls_row-cat_text     = zcl_cd_hck_report_html=>category_text( <ls_result>-category ).
      ls_row-priority     = <ls_result>-priority.
      ls_row-rag          = <ls_result>-rag.
      ls_row-description  = <ls_result>-description.
      ls_row-summary      = <ls_result>-summary.
      ls_row-findings     = lines( <ls_result>-findings ).
      ls_row-metrics      = lines( <ls_result>-metrics ).
      ls_row-runtime_ms   = <ls_result>-runtime_ms.
      ls_row-timed_out    = <ls_result>-timed_out.
      ls_row-plugin_error = <ls_result>-plugin_error.
      INSERT ls_row INTO TABLE mt_alv.
    ENDLOOP.
  ENDMETHOD.


  METHOD display_results.
    DATA lo_alv TYPE REF TO cl_salv_table.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = lo_alv
                                CHANGING  t_table      = mt_alv ).
        lo_alv->get_functions( )->set_default( abap_true ).
        DATA(lo_columns) = lo_alv->get_columns( ).
        lo_columns->set_optimize( abap_true ).
        lo_columns->set_exception_column( gc_light_column ).
        lo_alv->get_display_settings( )->set_list_header(
          CONV #( zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-report_list_header
                                         iv_v1    = |{ ms_report-report_date DATE = ISO }| ) ) ).
        lo_alv->get_display_settings( )->set_striped_pattern( abap_true ).
        DATA(lo_header) = header( ).
        lo_alv->set_top_of_list( lo_header ).
        lo_alv->set_top_of_list_print( lo_header ).
        SET HANDLER on_double_click FOR lo_alv->get_event( ).
        lo_alv->display( ).
      CATCH cx_salv_msg cx_salv_not_found cx_salv_data_error INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD display_exceptions.
    DATA lo_alv TYPE REF TO cl_salv_table.
    IF ms_report-exceptions IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = lo_alv
                                CHANGING  t_table      = ms_report-exceptions ).
        lo_alv->get_functions( )->set_default( abap_true ).
        lo_alv->get_columns( )->set_optimize( abap_true ).
        lo_alv->get_display_settings( )->set_list_header( CONV #( TEXT-t02 ) ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD header.
    DATA lv_row TYPE i.
    ro_grid = NEW #( ).
    lv_row = 1.
    ro_grid->create_label( row = lv_row column = 1 text = CONV #( TEXT-t03 ) ).
    ro_grid->create_text( row    = lv_row
                          column = 2
                          text   = |{ ms_report-score }/100 { zcl_cd_hck_report_html=>rag_text( ms_report-overall_rag ) }| ).
    lv_row = lv_row + 1.
    ro_grid->create_label( row = lv_row column = 1 text = CONV #( TEXT-t04 ) ).
    ro_grid->create_text( row = lv_row column = 2 text = |{ ms_report-critical_count } / { ms_report-high_count }| ).
    lv_row = lv_row + 1.
    ro_grid->create_label( row = lv_row column = 1 text = CONV #( TEXT-t05 ) ).
    ro_grid->create_text( row    = lv_row
                          column = 2
                          text   = COND string( WHEN ms_report-run-test_mode = abap_true THEN TEXT-t06
                                                ELSE TEXT-t07 ) ).
    LOOP AT ms_report-categories ASSIGNING FIELD-SYMBOL(<ls_category>).
      lv_row = lv_row + 1.
      ro_grid->create_label( row    = lv_row
                             column = 1
                             text   = |{ <ls_category>-category } { zcl_cd_hck_report_html=>category_text( <ls_category>-category ) }| ).
      ro_grid->create_text( row    = lv_row
                            column = 2
                            text   = |{ zcl_cd_hck_report_html=>rag_text( <ls_category>-rag ) } {
                                         zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-report_category
                                                                iv_v1    = <ls_category>-red_count
                                                                iv_v2    = <ls_category>-amber_count
                                                                iv_v3    = <ls_category>-check_count ) }| ).
    ENDLOOP.
    LOOP AT ms_report-pe_areas ASSIGNING FIELD-SYMBOL(<ls_pe_area>).
      lv_row = lv_row + 1.
      ro_grid->create_label( row = lv_row column = 1 text = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-report_area
                                                                         iv_v1    = <ls_pe_area>-pe_area ) ).
      ro_grid->create_text( row    = lv_row
                            column = 2
                            text   = COND string( WHEN <ls_pe_area>-last_run_at IS INITIAL THEN TEXT-t08
                                                  ELSE zcl_cd_ops_util=>text(
                                                         iv_msgno = zif_cd_hck_types=>gc_msg-report_last_run
                                                         iv_v1    = |{ <ls_pe_area>-last_run_at TIMESTAMP = ISO }|
                                                         iv_v2    = <ls_pe_area>-age_hours
                                                         iv_v3    = <ls_pe_area>-error_count ) &&
                                                       COND string( WHEN <ls_pe_area>-stale = abap_true THEN TEXT-t09 ) ) ).
    ENDLOOP.
  ENDMETHOD.


  METHOD on_double_click.
    DATA lt_findings TYPE tt_alv_finding.
    READ TABLE mt_alv INTO DATA(ls_row) INDEX row.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    READ TABLE ms_report-results INTO DATA(ls_result) WITH KEY check_id = ls_row-check_id.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    IF ls_result-step_status IS NOT INITIAL.
      " job cycle board: one row per step with its derived state
      show_popup( CHANGING ct_table = ls_result-step_status ).
      RETURN.
    ENDIF.
    lt_findings = CORRESPONDING #( ls_result-findings ).
    IF lt_findings IS INITIAL.
      show_popup( CHANGING ct_table = ls_result-metrics ).
      RETURN.
    ENDIF.
    show_popup( CHANGING ct_table = lt_findings ).
  ENDMETHOD.


  METHOD show_popup.
    DATA lo_alv TYPE REF TO cl_salv_table.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = lo_alv
                                CHANGING  t_table      = ct_table ).
        lo_alv->get_columns( )->set_optimize( abap_true ).
        lo_alv->set_screen_popup( start_column = 5
                                  end_column   = 160
                                  start_line   = 3
                                  end_line     = 25 ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD export_csv.
    " Directory traversal: only a file name, resolved in the logical path of the export,
    " validated and authorised for WRITE - the temporary file and a delete on error stay in it
    TRY.
        DATA(lv_file) = zcl_ca_ops_file_path=>physical( is_logical   = zif_cd_ops_types=>gc_logical_file-hck_export
                                                        iv_file_name = p_file
                                                        iv_activity  = zif_ca_ops_types=>gc_dataset_activity-write ).
      CATCH zcx_ca_ops_error INTO DATA(lx_path).
        IF sy-batch = abap_true.
          MESSAGE lx_path TYPE 'E'.
        ENDIF.
        MESSAGE lx_path TYPE 'S' DISPLAY LIKE 'E'.
        RETURN.
    ENDTRY.

    " A61: complete file or none - temporary file first, target replaced only afterwards
    TRY.
        zcl_cd_hck_export=>write( iv_file  = lv_file
                                  it_lines = zcl_cd_hck_report_html=>render_csv( ms_report )
                                  io_file  = NEW zcl_cd_hck_dataset( ) ).
        MESSAGE s315(zcd_ops) WITH lv_file.
      CATCH zcx_ca_ops_error INTO DATA(lx_file).
        " B9: in background the job ends cancelled (Control-M red), never green
        IF sy-batch = abap_true.
          MESSAGE lx_file TYPE 'E'.
        ENDIF.
        MESSAGE lx_file TYPE 'S' DISPLAY LIKE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD light.
    " SALV exception column: 1 red, 2 yellow, 3 green, space = none
    rv_light = SWITCH #( iv_rag
                         WHEN zif_ca_ops_types=>gc_rag-red   THEN gc_light-red
                         WHEN zif_ca_ops_types=>gc_rag-amber THEN gc_light-yellow
                         WHEN zif_ca_ops_types=>gc_rag-green THEN gc_light-green
                         ELSE gc_light-none ).
  ENDMETHOD.

ENDCLASS.


AT SELECTION-SCREEN.
  NEW lcl_app( )->validate( ).

START-OF-SELECTION.
  NEW lcl_app( )->run( ).
