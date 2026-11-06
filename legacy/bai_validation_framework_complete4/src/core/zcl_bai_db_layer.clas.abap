CLASS zcl_bai_db_layer DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS save_results
      IMPORTING
        it_results  TYPE zif_bai_validator=>tt_validation_result
        iv_batch_id TYPE sysuuid_x16
      RAISING
        zcx_bai_db_error.

    METHODS save_batch_summary
      IMPORTING
        iv_batch_id      TYPE sysuuid_x16
        iv_bai_code      TYPE char10
        iv_flow_type     TYPE char1
        iv_total_records TYPE i
        iv_passed_count  TYPE i
        iv_failed_count  TYPE i
        iv_warning_count TYPE i DEFAULT 0
        iv_duration_ms   TYPE int8
      RAISING
        zcx_bai_db_error.

    METHODS save_batch_audit
      IMPORTING
        iv_batch_id         TYPE sysuuid_x16
        iv_execution_date   TYPE datum
        iv_execution_time   TYPE tims
        iv_total_records    TYPE i
        iv_total_passed     TYPE i
        iv_total_failed     TYPE i
        iv_bai_codes        TYPE string
        iv_date_from        TYPE datum
        iv_date_to          TYPE datum
        iv_duration_seconds TYPE dec
        iv_status           TYPE char1
      RAISING
        zcx_bai_db_error.

    METHODS commit_transaction
      RAISING
        zcx_bai_db_error.

    METHODS rollback_transaction
      RAISING
        zcx_bai_db_error.

    METHODS get_failed_records
      IMPORTING
        iv_batch_id       TYPE sysuuid_x16
        iv_bai_code       TYPE char10 OPTIONAL
      RETURNING
        VALUE(rt_results) TYPE zif_bai_validator=>tt_validation_result
      RAISING
        zcx_bai_db_error.

  PROTECTED SECTION.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_bai_db_layer IMPLEMENTATION.


  METHOD save_results.

    DATA: lt_results_db TYPE TABLE OF zbai_validation_results,
          ls_result_db  TYPE zbai_validation_results.

    " Convert to database structure
    LOOP AT it_results INTO DATA(ls_result).

      ls_result_db = VALUE #(
        kukey           = ls_result-kukey
        esnum           = ls_result-esnum
        bai_code        = ls_result-bai_code
        batch_id        = iv_batch_id
        vorgc           = ls_result-vorgc
        belnr           = ls_result-belnr
        gjahr           = ls_result-gjahr
        chect           = ls_result-chect
        flow_type       = ls_result-flow_type
        status          = ls_result-status
        status_icon     = ls_result-status_icon
        failed_checks   = ls_result-failed_checks
        primary_failure = ls_result-primary_failure
        details_json    = ls_result-details_json
        message         = ls_result-message
        validation_date = sy-datum
        validation_time = sy-uzeit
        validated_by    = sy-uname
        created_by      = sy-uname
        created_at      = cl_abap_context_info=>get_system_time( )
      ).

      APPEND ls_result_db TO lt_results_db.

    ENDLOOP.

    " Bulk insert
    IF lt_results_db IS NOT INITIAL.

      INSERT zbai_validation_results FROM TABLE lt_results_db.

      IF sy-subrc <> 0.
        RAISE EXCEPTION TYPE zcx_bai_db_error
          EXPORTING
            textid   = zcx_bai_db_error=>insert_failed
            mv_table = 'ZBAI_VALIDATION_RESULTS'.
      ENDIF.

    ENDIF.

  ENDMETHOD.


  METHOD save_batch_summary.

    DATA: ls_summary TYPE zbai_validation_summary,
          lv_pass_rate TYPE p DECIMALS 2,
          lv_avg_ms    TYPE p DECIMALS 2.

    " Calculate metrics
    IF iv_total_records > 0.
      lv_pass_rate = ( iv_passed_count / iv_total_records ) * 100.
      lv_avg_ms = iv_duration_ms / iv_total_records.
    ENDIF.

    " Build summary record
    ls_summary = VALUE #(
      batch_id        = iv_batch_id
      bai_code        = iv_bai_code
      flow_type       = iv_flow_type
      validation_date = sy-datum
      validation_time = sy-uzeit
      total_records   = iv_total_records
      passed_count    = iv_passed_count
      failed_count    = iv_failed_count
      warning_count   = iv_warning_count
      pass_rate       = lv_pass_rate
      pass_rate_unit  = '%'
      duration_ms     = iv_duration_ms
      avg_ms_per_record = lv_avg_ms
      created_by      = sy-uname
      created_at      = cl_abap_context_info=>get_system_time( )
    ).

    " Insert
    INSERT zbai_validation_summary FROM ls_summary.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bai_db_error
        EXPORTING
          textid   = zcx_bai_db_error=>summary_insert_failed
          mv_table = 'ZBAI_VALIDATION_SUMMARY'.
    ENDIF.

  ENDMETHOD.


  METHOD save_batch_audit.

    DATA: ls_audit TYPE zbai_batch_audit_log.

    " Build audit record
    ls_audit = VALUE #(
      batch_id            = iv_batch_id
      execution_date      = iv_execution_date
      execution_time      = iv_execution_time
      total_records       = iv_total_records
      total_passed        = iv_total_passed
      total_failed        = iv_total_failed
      bai_codes_validated = iv_bai_codes
      febep_date_from     = iv_date_from
      febep_date_to       = iv_date_to
      duration_seconds    = iv_duration_seconds
      status              = iv_status
      created_by          = sy-uname
      created_at          = cl_abap_context_info=>get_system_time( )
    ).

    " Insert
    INSERT zbai_batch_audit_log FROM ls_audit.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bai_db_error
        EXPORTING
          textid   = zcx_bai_db_error=>batch_audit_failed
          mv_table = 'ZBAI_BATCH_AUDIT_LOG'.
    ENDIF.

  ENDMETHOD.


  METHOD commit_transaction.

    COMMIT WORK AND WAIT.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bai_db_error
        EXPORTING
          textid   = zcx_bai_db_error=>commit_failed
          mv_table = 'ALL'.
    ENDIF.

  ENDMETHOD.


  METHOD rollback_transaction.

    ROLLBACK WORK.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bai_db_error
        EXPORTING
          textid   = zcx_bai_db_error=>rollback_failed
          mv_table = 'ALL'.
    ENDIF.

  ENDMETHOD.


  METHOD get_failed_records.

    DATA: lt_results_db TYPE TABLE OF zbai_validation_results.

    " Query failed records
    IF iv_bai_code IS INITIAL.

      SELECT *
        FROM zbai_validation_results
        WHERE batch_id = @iv_batch_id
        INTO TABLE @lt_results_db.

    ELSE.

      SELECT *
        FROM zbai_validation_results
        WHERE batch_id = @iv_batch_id
          AND bai_code = @iv_bai_code
        INTO TABLE @lt_results_db.

    ENDIF.

    IF sy-subrc <> 0.
      " No results is OK - return empty table
      RETURN.
    ENDIF.

    " Convert to interface structure
    rt_results = VALUE #(
      FOR <db> IN lt_results_db
      ( kukey           = <db>-kukey
        esnum           = <db>-esnum
        bai_code        = <db>-bai_code
        vorgc           = <db>-vorgc
        belnr           = <db>-belnr
        gjahr           = <db>-gjahr
        chect           = <db>-chect
        flow_type       = <db>-flow_type
        status          = <db>-status
        status_icon     = <db>-status_icon
        failed_checks   = <db>-failed_checks
        primary_failure = <db>-primary_failure
        details_json    = <db>-details_json
        message         = <db>-message )
    ).

  ENDMETHOD.


ENDCLASS.
