*&---------------------------------------------------------------------*
*& Report Z_BAI_MASS_VALIDATION
*&---------------------------------------------------------------------*
*& BAI Validation Framework - Main Execution Program
*& Executes all configured BAI validators for a date range
*&---------------------------------------------------------------------*
REPORT z_bai_mass_validation.

*&---------------------------------------------------------------------*
*& Selection Screen
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.

  " Date Range Selection
  PARAMETERS: p_datefr TYPE datum OBLIGATORY DEFAULT sy-datum,
              p_dateto TYPE datum OBLIGATORY DEFAULT sy-datum.

SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.

  " Execution Options
  PARAMETERS: p_chunk TYPE i DEFAULT 10000,        " Chunk size
              p_test  AS CHECKBOX.                 " Test mode (no commit)

SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.

  " BAI Code Selection (Optional - leave blank for all)
  SELECT-OPTIONS: s_bai FOR gs_bai_dummy-bai_code.

SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE TEXT-004.

  " Display Options
  PARAMETERS: p_detail AS CHECKBOX DEFAULT abap_true,  " Show details
              p_alv    AS CHECKBOX DEFAULT abap_true.  " Display results in ALV

SELECTION-SCREEN END OF BLOCK b4.

*&---------------------------------------------------------------------*
*& Data Declarations
*&---------------------------------------------------------------------*
DATA: lo_mass_validator TYPE REF TO zcl_bai_mass_validator,
      lv_batch_id       TYPE sysuuid_x16,
      lv_total_records  TYPE i,
      lv_total_passed   TYPE i,
      lv_total_failed   TYPE i,
      lv_start_time     TYPE timestampl,
      lv_end_time       TYPE timestampl,
      lv_duration       TYPE p DECIMALS 2.

" Dummy structure for SELECT-OPTIONS
TYPES: BEGIN OF ty_bai_dummy,
         bai_code TYPE char10,
       END OF ty_bai_dummy.
DATA: gs_bai_dummy TYPE ty_bai_dummy.

*&---------------------------------------------------------------------*
*& Initialization
*&---------------------------------------------------------------------*
INITIALIZATION.
  " Set default date range (last 7 days)
  p_dateto = sy-datum.
  p_datefr = sy-datum - 7.

*&---------------------------------------------------------------------*
*& At Selection Screen
*&---------------------------------------------------------------------*
AT SELECTION-SCREEN.
  " Validate date range
  IF p_datefr > p_dateto.
    MESSAGE 'From date cannot be after To date' TYPE 'E'.
  ENDIF.

  " Validate chunk size
  IF p_chunk < 100 OR p_chunk > 50000.
    MESSAGE 'Chunk size must be between 100 and 50,000' TYPE 'E'.
  ENDIF.

*&---------------------------------------------------------------------*
*& Start of Selection
*&---------------------------------------------------------------------*
START-OF-SELECTION.

  PERFORM execute_validation.

*&---------------------------------------------------------------------*
*& End of Selection
*&---------------------------------------------------------------------*
END-OF-SELECTION.

  PERFORM display_results.

*&---------------------------------------------------------------------*
*& Form EXECUTE_VALIDATION
*&---------------------------------------------------------------------*
FORM execute_validation.

  DATA: lx_error TYPE REF TO cx_root,
        lv_msg   TYPE string.

  " Display execution parameters
  WRITE: / 'BAI Validation Framework - Mass Execution'.
  WRITE: / sy-uline(70).
  WRITE: / 'Date Range:', p_datefr, '-', p_dateto.
  WRITE: / 'Chunk Size:', p_chunk.
  WRITE: / 'Test Mode:', COND #( WHEN p_test = abap_true THEN 'YES' ELSE 'NO' ).
  WRITE: / sy-uline(70).
  SKIP.

  " Start timing
  GET TIME STAMP FIELD lv_start_time.

  TRY.
      " Create mass validator
      WRITE: / 'Creating mass validator...'.
      CREATE OBJECT lo_mass_validator
        EXPORTING
          iv_chunk_size = p_chunk.

      " Load active validators
      WRITE: / 'Loading active validators...'.
      lo_mass_validator->load_all_active_validators( ).

      " TODO: Apply BAI code filter if specified
      " (Would need to add method to mass validator)

      " Execute validation
      WRITE: / 'Starting validation...'.
      SKIP.

      lo_mass_validator->run_validation(
        EXPORTING
          iv_febep_date_from = p_datefr
          iv_febep_date_to   = p_dateto
        IMPORTING
          ev_batch_id        = lv_batch_id
          ev_total_records   = lv_total_records
          ev_total_passed    = lv_total_passed
          ev_total_failed    = lv_total_failed
      ).

      " Test mode - rollback instead of commit
      IF p_test = abap_true.
        WRITE: / 'TEST MODE - Rolling back...'.
        ROLLBACK WORK.
      ENDIF.

    CATCH zcx_bai_validation_error INTO lx_error.
      lv_msg = lx_error->get_text( ).
      WRITE: / 'Validation Error:', lv_msg.
      MESSAGE lv_msg TYPE 'E'.

    CATCH zcx_bai_db_error INTO lx_error.
      lv_msg = lx_error->get_text( ).
      WRITE: / 'Database Error:', lv_msg.
      MESSAGE lv_msg TYPE 'E'.

    CATCH cx_root INTO lx_error.
      lv_msg = lx_error->get_text( ).
      WRITE: / 'Unexpected Error:', lv_msg.
      MESSAGE lv_msg TYPE 'E'.

  ENDTRY.

  " End timing
  GET TIME STAMP FIELD lv_end_time.
  lv_duration = ( lv_end_time - lv_start_time ) / 1000000.

ENDFORM.

*&---------------------------------------------------------------------*
*& Form DISPLAY_RESULTS
*&---------------------------------------------------------------------*
FORM display_results.

  DATA: lv_pass_rate TYPE p DECIMALS 2.

  SKIP 2.
  WRITE: / '══════════════════════════════════════════════════════════════'.
  WRITE: / '                    VALIDATION RESULTS'.
  WRITE: / '══════════════════════════════════════════════════════════════'.

  " Display batch ID
  IF lv_batch_id IS NOT INITIAL.
    WRITE: / 'Batch ID:', lv_batch_id.
  ENDIF.

  " Display statistics
  WRITE: / sy-uline(70).
  WRITE: / 'Total Records Validated:', lv_total_records.
  WRITE: / 'Passed:', lv_total_passed COLOR COL_POSITIVE.
  WRITE: / 'Failed:', lv_total_failed COLOR COL_NEGATIVE.

  IF lv_total_records > 0.
    lv_pass_rate = ( lv_total_passed / lv_total_records ) * 100.
    WRITE: / 'Pass Rate:', lv_pass_rate, '%'.
  ENDIF.

  WRITE: / 'Execution Time:', lv_duration, 'seconds'.
  WRITE: / sy-uline(70).

  " Status indicator
  IF lv_total_failed = 0.
    WRITE: / 'Status: SUCCESS ✓' COLOR COL_POSITIVE.
  ELSEIF lv_pass_rate >= 90.
    WRITE: / 'Status: WARNING (>10% failures)' COLOR COL_TOTAL.
  ELSE.
    WRITE: / 'Status: ERROR (>10% failures)' COLOR COL_NEGATIVE.
  ENDIF.

  " Display ALV if requested and batch ID exists
  IF p_alv = abap_true AND lv_batch_id IS NOT INITIAL.
    SKIP 2.
    PERFORM show_alv_results.
  ELSE.
    SKIP 2.
    WRITE: / 'To view detailed results in ALV grid:'.
    WRITE: / 'Execute transaction: Z_BAI_VALIDATION_DASHBOARD'.
    WRITE: / 'Or run SE16 on table: ZBAI_VALIDATION_RESULTS'.
    WRITE: / 'Batch ID:', lv_batch_id.
  ENDIF.

  " Show next steps
  SKIP 2.
  WRITE: / 'Next Steps:'.
  WRITE: / '1. Review failed records in ZBAI_VALIDATION_RESULTS'.
  WRITE: / '2. Check batch summary in ZBAI_VALIDATION_SUMMARY'.
  WRITE: / '3. View audit log in ZBAI_BATCH_AUDIT_LOG'.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form SHOW_ALV_RESULTS
*&---------------------------------------------------------------------*
FORM show_alv_results.

  TYPES: BEGIN OF ty_alv_result,
           bai_code        TYPE char10,
           kukey           TYPE char12,
           esnum           TYPE char9,
           status          TYPE char1,
           status_icon     TYPE icon_d,
           failed_checks   TYPE string,
           primary_failure TYPE char10,
           message         TYPE string,
           validated_on    TYPE datum,
           validated_at    TYPE uzeit,
         END OF ty_alv_result.

  DATA: lt_results TYPE TABLE OF ty_alv_result,
        lo_alv     TYPE REF TO cl_salv_table,
        lx_error   TYPE REF TO cx_salv_error.

  " Load failed records for this batch
  SELECT bai_code, kukey, esnum, status, status_icon,
         failed_checks, primary_failure, message,
         validated_on, validated_at
    FROM zbai_validation_results
    INTO TABLE @lt_results
    WHERE batch_id = @lv_batch_id
      AND status = 'R'
    ORDER BY bai_code, kukey.

  IF lt_results IS INITIAL.
    WRITE: / 'No failed records to display in ALV'.
    RETURN.
  ENDIF.

  TRY.
      " Create ALV object
      cl_salv_table=>factory(
        IMPORTING
          r_salv_table = lo_alv
        CHANGING
          t_table      = lt_results
      ).

      " Configure columns
      DATA(lo_columns) = lo_alv->get_columns( ).
      lo_columns->set_optimize( abap_true ).

      " Set icon column
      DATA(lo_column) = lo_columns->get_column( 'STATUS_ICON' ).
      lo_column->set_icon( abap_true ).
      lo_column->set_short_text( 'St' ).

      " Set other column texts
      lo_column = lo_columns->get_column( 'BAI_CODE' ).
      lo_column->set_short_text( 'BAI' ).
      lo_column->set_medium_text( 'BAI Code' ).

      lo_column = lo_columns->get_column( 'FAILED_CHECKS' ).
      lo_column->set_short_text( 'Failures' ).
      lo_column->set_medium_text( 'Failed Checks' ).

      lo_column = lo_columns->get_column( 'MESSAGE' ).
      lo_column->set_short_text( 'Message' ).
      lo_column->set_medium_text( 'Validation Message' ).

      " Enable all functions
      DATA(lo_functions) = lo_alv->get_functions( ).
      lo_functions->set_all( abap_true ).

      " Display settings
      DATA(lo_display) = lo_alv->get_display_settings( ).
      lo_display->set_striped_pattern( abap_true ).
      lo_display->set_list_header( |BAI Validation Results - Batch { lv_batch_id }| ).

      " Display ALV
      lo_alv->display( ).

    CATCH cx_salv_error INTO lx_error.
      WRITE: / 'Error displaying ALV:', lx_error->get_text( ).
  ENDTRY.

ENDFORM.
