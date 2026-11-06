*&---------------------------------------------------------------------*
*& Artifact: zcd_ebs_validate.prog.abap
*& Purpose:
*& Runs EBS validation for imported statements (FEBKO/FEBEP, post-import) or
*& for one bank file before import (BAI2 / CAMT.053 / CAMT.054, application
*& server or PC upload). Shows run summary and findings in ALV. Test mode
*& saves nothing and sends no alert. Schedulable in background (Control-M).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation; replaces
*&            | Z_BAI_MASS_VALIDATION / ZFIR_BANK_POST_VALIDATION_V2).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*& 2026-11-06 | Authorisation ZCD_OPS activity 16 payment engine area EBS replaces S_PROGRAM.
*& 2026-11-06 | Refused run (run lock held) reported; job ends in error in background.
*& 2026-11-06 | Variant parameter typed with ZIF_CD_OPS_TYPES=>TY_VARIANT (audit A01).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A68: FEB date range validated (selection screen and source).
*& 2026-11-06 | Audit A69: server file read rejects encoding and read errors, distinguishes end of file, always closes.
*&---------------------------------------------------------------------*
REPORT zcd_ebs_validate.

TABLES sscrfields.

DATA gv_bukrs TYPE c LENGTH 4.
DATA gv_hbkid TYPE c LENGTH 5.
DATA gv_kukey TYPE n LENGTH 8.

SELECTION-SCREEN BEGIN OF BLOCK b_src WITH FRAME TITLE TEXT-b01.
  PARAMETERS p_feb  RADIOBUTTON GROUP src DEFAULT 'X' USER-COMMAND src.
  PARAMETERS p_file RADIOBUTTON GROUP src.
SELECTION-SCREEN END OF BLOCK b_src.

SELECTION-SCREEN BEGIN OF BLOCK b_feb WITH FRAME TITLE TEXT-b02.
  SELECT-OPTIONS s_bukrs FOR gv_bukrs.
  SELECT-OPTIONS s_hbkid FOR gv_hbkid.
  SELECT-OPTIONS s_kukey FOR gv_kukey.
  PARAMETERS p_from TYPE d DEFAULT sy-datum.
  PARAMETERS p_to   TYPE d DEFAULT sy-datum.
  PARAMETERS p_pack TYPE i DEFAULT 50.
SELECTION-SCREEN END OF BLOCK b_feb.

SELECTION-SCREEN BEGIN OF BLOCK b_fil WITH FRAME TITLE TEXT-b03.
  PARAMETERS p_path TYPE string LOWER CASE.
  PARAMETERS p_pc   AS CHECKBOX.
  PARAMETERS p_bai2 RADIOBUTTON GROUP fmt DEFAULT 'X' ##NEEDED.
  PARAMETERS p_c053 RADIOBUTTON GROUP fmt.
  PARAMETERS p_c054 RADIOBUTTON GROUP fmt.
SELECTION-SCREEN END OF BLOCK b_fil.

SELECTION-SCREEN BEGIN OF BLOCK b_run WITH FRAME TITLE TEXT-b04.
  PARAMETERS p_var  TYPE zif_cd_ops_types=>ty_variant DEFAULT 'DAILY'.
  PARAMETERS p_test AS CHECKBOX DEFAULT 'X'.
  PARAMETERS p_all  AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b_run.


"! Report controller: builds the source, runs the engine, shows the result
"! Technical values of the report (selection-screen function, PC upload format)
CONSTANTS gc_ucomm_execute TYPE sy-ucomm VALUE 'ONLI'.
CONSTANTS gc_upload_filetype TYPE char10 VALUE 'ASC'.
"! SAP code page 4110 = UTF-8
CONSTANTS gc_codepage_utf8 TYPE abap_encod VALUE '4110'.
"! READ DATASET return code at end of file (VERIFY: an unterminated last line may come
"! with this code - it is kept, never dropped)
CONSTANTS gc_subrc_eof TYPE sysubrc VALUE 4.

CLASS lcl_report DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS run.

  PRIVATE SECTION.
    METHODS build_source
      RETURNING
        VALUE(ro_source) TYPE REF TO zif_cd_ebs_source
      RAISING
        zcx_cd_ops_error.

    METHODS read_file
      RETURNING
        VALUE(rv_content) TYPE string
      RAISING
        zcx_cd_ops_error.

    METHODS file_format
      RETURNING
        VALUE(rv_format) TYPE zif_cd_ebs_types=>ty_format.

    METHODS is_result_text
      IMPORTING
        is_run         TYPE zif_cd_ops_types=>ty_run
      RETURNING
        VALUE(rv_text) TYPE symsgv.

    METHODS display
      IMPORTING
        is_result TYPE zcl_cd_ebs_engine=>ty_result.
ENDCLASS.


CLASS lcl_report IMPLEMENTATION.

  METHOD run.
    TRY.
        zcl_cd_ops_factory=>get_auth( )->check( iv_activity = zif_cd_ops_auth=>gc_activity-execute
                                                iv_pe_area   = zif_cd_ops_types=>gc_pe_area-ebs ).
        DATA(ls_result) = NEW zcl_cd_ebs_engine( )->run( io_source    = build_source( )
                                                         iv_variant   = p_var
                                                         iv_test_mode = p_test ).
        IF zcl_cd_ops_run_guard=>was_refused( ls_result-findings ) = abap_true.
          " Run lock held: background job ends in error so Control-M shows it
          IF sy-batch = abap_true.
            MESSAGE ls_result-run-message TYPE 'E'.
          ENDIF.
          MESSAGE ls_result-run-message TYPE 'S' DISPLAY LIKE 'E'.
          RETURN.
        ENDIF.
        IF sy-batch = abap_true.
          MESSAGE s000(zcd_ops) WITH is_result_text( ls_result-run ) space space space.
        ELSE.
          display( ls_result ).
        ENDIF.
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        MESSAGE lx_error TYPE 'E'.
    ENDTRY.
  ENDMETHOD.


  METHOD build_source.
    DATA ls_selection TYPE zif_cd_ebs_feb_dao=>ty_selection.
    IF p_feb = abap_true.
      ls_selection-bukrs     = s_bukrs[].
      ls_selection-hbkid     = s_hbkid[].
      ls_selection-kukey     = s_kukey[].
      ls_selection-date_from = p_from.
      ls_selection-date_to   = p_to.
      zcl_cd_ebs_src_feb=>check_selection( ls_selection ).
      ro_source = NEW zcl_cd_ebs_src_feb( is_selection = ls_selection iv_package_size = p_pack ).
    ELSE.
      ro_source = NEW zcl_cd_ebs_src_file( iv_content   = read_file( )
                                           iv_format    = file_format( )
                                           iv_file_name = p_path ).
    ENDIF.
  ENDMETHOD.


  METHOD file_format.
    rv_format = COND #( WHEN p_c053 = abap_true THEN zif_cd_ebs_types=>gc_format-camt053
                        WHEN p_c054 = abap_true THEN zif_cd_ebs_types=>gc_format-camt054
                        ELSE zif_cd_ebs_types=>gc_format-bai2 ).
  ENDMETHOD.


  METHOD read_file.
    DATA lt_lines TYPE string_table.
    DATA lv_line  TYPE string.

    IF p_pc = abap_true AND sy-batch = abap_false.
      cl_gui_frontend_services=>gui_upload( EXPORTING  filename = p_path
                                                       filetype = gc_upload_filetype
                                                       codepage = gc_codepage_utf8
                                            CHANGING   data_tab = lt_lines
                                            EXCEPTIONS OTHERS   = 1 ).
      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e012(zcd_ops) WITH p_path.
      ENDIF.
    ELSE.
      " A69: no IGNORING CONVERSION ERRORS - a file that is not UTF-8 is rejected, not
      " validated with replaced characters; only end of file ends the read; the dataset is
      " closed on every path
      TRY.
          OPEN DATASET p_path FOR INPUT IN TEXT MODE ENCODING UTF-8.
          IF sy-subrc <> 0.
            RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e012(zcd_ops) WITH p_path.
          ENDIF.
          DO.
            CLEAR lv_line.
            READ DATASET p_path INTO lv_line.
            DATA(lv_subrc) = sy-subrc.
            IF lv_subrc = 0.
              INSERT lv_line INTO TABLE lt_lines.
            ELSEIF lv_subrc = gc_subrc_eof.
              IF lv_line IS NOT INITIAL.
                INSERT lv_line INTO TABLE lt_lines.
              ENDIF.
              EXIT.
            ELSE.
              DATA(lv_read) = lines( lt_lines ).
              RAISE EXCEPTION TYPE zcx_cd_ops_error
                MESSAGE e531(zcd_ops) WITH p_path lv_subrc lv_read.
            ENDIF.
          ENDDO.
        CATCH cx_sy_conversion_codepage INTO DATA(lx_codepage).
          CLOSE DATASET p_path.
          DATA(lv_read_ok) = lines( lt_lines ).
          RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e530(zcd_ops) WITH p_path lv_read_ok
            EXPORTING
              previous = lx_codepage.
        CATCH cx_sy_file_access_error INTO DATA(lx_file).
          CLOSE DATASET p_path.
          RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e012(zcd_ops) WITH p_path
            EXPORTING
              previous = lx_file.
        CLEANUP.
          CLOSE DATASET p_path.
      ENDTRY.
      CLOSE DATASET p_path.
    ENDIF.
    rv_content = concat_lines_of( table = lt_lines sep = cl_abap_char_utilities=>newline ).
  ENDMETHOD.


  METHOD is_result_text.
    rv_text = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-report_result
                                     iv_v1    = is_run-status
                                     iv_v2    = is_run-rag
                                     iv_v3    = is_run-failed_items
                                     iv_v4    = is_run-blocked_items ).
  ENDMETHOD.


  METHOD display.
    DATA lt_findings TYPE zif_cd_ops_types=>tt_finding.
    lt_findings = is_result-findings.
    IF p_all = abap_false.
      DELETE lt_findings WHERE severity = zif_cd_ops_types=>gc_severity-info.
    ENDIF.
    TRY.
        cl_salv_table=>factory( IMPORTING r_salv_table = DATA(lo_alv)
                                CHANGING  t_table      = lt_findings ).
        lo_alv->get_functions( )->set_all( abap_true ).
        lo_alv->get_columns( )->set_optimize( abap_true ).
        DATA(lo_header) = NEW cl_salv_form_layout_grid( ).
        lo_header->create_text( row = 1 column = 1 text = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-report_header
                                                                                 iv_v1    = is_result-run-variant
                                                                                 iv_v2    = is_result-run-status
                                                                                 iv_v3    = is_result-run-rag ) ).
        lo_header->create_text( row = 2 column = 1 text = is_result-run-message ).
        lo_header->create_text( row = 3 column = 1
                                text = COND string( WHEN p_test = abap_true THEN TEXT-t01
                                                    ELSE zcl_cd_ops_util=>text( iv_msgno = zif_cd_ebs_types=>gc_msg-report_saved
                                                                                iv_v1    = is_result-run-finding_count ) ) ).
        lo_alv->set_top_of_list( lo_header ).
        lo_alv->display( ).
      CATCH cx_salv_msg INTO DATA(lx_salv).
        MESSAGE lx_salv TYPE 'I'.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


AT SELECTION-SCREEN.
  IF sscrfields-ucomm = gc_ucomm_execute AND p_file = abap_true AND p_path IS INITIAL.
    MESSAGE e510(zcd_ops).
  ENDIF.
  " A68: an inverted date range is rejected on the selection screen
  IF sscrfields-ucomm = gc_ucomm_execute AND p_feb = abap_true AND p_from > p_to.
    MESSAGE e527(zcd_ops) WITH p_from p_to.
  ENDIF.

START-OF-SELECTION.
  NEW lcl_report( )->run( ).
