*&---------------------------------------------------------------------*
*& Report Z_BAI_VALIDATION_DASHBOARD
*&---------------------------------------------------------------------*
*& BAI Validation Framework - Results Dashboard
*& Display validation results with drill-down capabilities
*&---------------------------------------------------------------------*
REPORT z_bai_validation_dashboard.

TABLES: zbai_validation_results, zbai_validation_summary.

*&---------------------------------------------------------------------*
*& Selection Screen
*&---------------------------------------------------------------------*
SELECTION-SCREEN BEGIN OF BLOCK b1 WITH FRAME TITLE TEXT-001.
  PARAMETERS: p_batch TYPE sysuuid_x16.
SELECTION-SCREEN END OF BLOCK b1.

SELECTION-SCREEN BEGIN OF BLOCK b2 WITH FRAME TITLE TEXT-002.
  SELECT-OPTIONS: s_date FOR zbai_validation_results-validated_on.
SELECTION-SCREEN END OF BLOCK b2.

SELECTION-SCREEN BEGIN OF BLOCK b3 WITH FRAME TITLE TEXT-003.
  SELECT-OPTIONS: s_bai FOR zbai_validation_results-bai_code.
  PARAMETERS: p_failed AS CHECKBOX DEFAULT 'X',
              p_passed AS CHECKBOX.
SELECTION-SCREEN END OF BLOCK b3.

SELECTION-SCREEN BEGIN OF BLOCK b4 WITH FRAME TITLE TEXT-004.
  PARAMETERS: p_summ AS CHECKBOX DEFAULT 'X',
              p_detail AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b4.

*&---------------------------------------------------------------------*
*& Type Definitions
*&---------------------------------------------------------------------*
TYPES: BEGIN OF ty_result_alv,
         kukey           TYPE char12,
         esnum           TYPE char9,
         bai_code        TYPE char10,
         status          TYPE char1,
         status_icon     TYPE icon_d,
         failed_checks   TYPE string,
         message         TYPE string,
         batch_id        TYPE sysuuid_x16,
         validated_on    TYPE datum,
       END OF ty_result_alv.

TYPES: BEGIN OF ty_summary_alv,
         batch_id        TYPE sysuuid_x16,
         bai_code        TYPE char10,
         total_records   TYPE i,
         passed_count    TYPE i,
         failed_count    TYPE i,
         pass_rate       TYPE p DECIMALS 2,
         execution_date  TYPE datum,
       END OF ty_summary_alv.

DATA: lt_results TYPE TABLE OF ty_result_alv,
      lt_summary TYPE TABLE OF ty_summary_alv,
      lo_alv     TYPE REF TO cl_salv_table.

START-OF-SELECTION.
  IF p_summ = abap_true.
    PERFORM load_summary.
    PERFORM display_summary_alv.
  ENDIF.

  IF p_detail = abap_true.
    PERFORM load_details.
    PERFORM display_detail_alv.
  ENDIF.

FORM load_summary.
  SELECT batch_id, bai_code, flow_type,
         total_records, passed_count, failed_count,
         execution_date
    FROM zbai_validation_summary
    INTO TABLE @DATA(lt_sum)
    WHERE execution_date IN @s_date
      AND bai_code IN @s_bai
      AND ( batch_id = @p_batch OR @p_batch IS INITIAL ).

  LOOP AT lt_sum INTO DATA(ls_sum).
    APPEND VALUE #(
      batch_id = ls_sum-batch_id
      bai_code = ls_sum-bai_code
      total_records = ls_sum-total_records
      passed_count = ls_sum-passed_count
      failed_count = ls_sum-failed_count
      pass_rate = COND #( WHEN ls_sum-total_records > 0
                          THEN ( ls_sum-passed_count / ls_sum-total_records ) * 100
                          ELSE 0 )
      execution_date = ls_sum-execution_date
    ) TO lt_summary.
  ENDLOOP.
ENDFORM.

FORM load_details.
  SELECT kukey, esnum, bai_code, status, status_icon,
         failed_checks, message, batch_id, validated_on
    FROM zbai_validation_results
    INTO TABLE @lt_results
    WHERE validated_on IN @s_date
      AND bai_code IN @s_bai
      AND ( batch_id = @p_batch OR @p_batch IS INITIAL )
      AND ( ( status = 'R' AND @p_failed = abap_true )
         OR ( status = 'G' AND @p_passed = abap_true ) ).
ENDFORM.

FORM display_summary_alv.
  CHECK lt_summary IS NOT INITIAL.
  
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING t_table = lt_summary ).

      lo_alv->get_columns( )->set_optimize( abap_true ).
      lo_alv->get_functions( )->set_all( abap_true ).
      lo_alv->get_display_settings( )->set_list_header( 'BAI Validation Summary' ).
      lo_alv->display( ).
    CATCH cx_salv_error.
  ENDTRY.
ENDFORM.

FORM display_detail_alv.
  CHECK lt_results IS NOT INITIAL.
  
  TRY.
      cl_salv_table=>factory(
        IMPORTING r_salv_table = lo_alv
        CHANGING t_table = lt_results ).

      lo_alv->get_columns( )->set_optimize( abap_true ).
      lo_alv->get_functions( )->set_all( abap_true ).
      
      DATA(lo_column) = lo_alv->get_columns( )->get_column( 'STATUS_ICON' ).
      lo_column->set_icon( abap_true ).
      
      lo_alv->get_display_settings( )->set_list_header( 'BAI Validation Details' ).
      lo_alv->display( ).
    CATCH cx_salv_error.
  ENDTRY.
ENDFORM.
