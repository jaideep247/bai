CLASS zcl_bai_mass_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS: gc_default_chunk_size TYPE i VALUE 10000.

    TYPES: BEGIN OF ty_batch_stats,
             batch_id          TYPE sysuuid_x16,
             total_validators  TYPE i,
             total_records     TYPE i,
             total_passed      TYPE i,
             total_failed      TYPE i,
             overall_pass_rate TYPE p DECIMALS 2,
             duration_seconds  TYPE p DECIMALS 2,
             execution_date    TYPE datum,
             execution_time    TYPE tims,
             status            TYPE char1,
           END OF ty_batch_stats.

    METHODS constructor
      IMPORTING
        iv_chunk_size TYPE i DEFAULT gc_default_chunk_size.

    METHODS add_validator
      IMPORTING
        iv_bai_code  TYPE char10
        iv_flow_type TYPE char1
      RAISING
        zcx_bai_validation_error.

    METHODS load_all_active_validators
      RAISING
        zcx_bai_db_error.

    METHODS run_validation
      IMPORTING
        it_febep           TYPE zif_bai_validator=>tt_febep_data OPTIONAL
        iv_febep_date_from TYPE datum OPTIONAL
        iv_febep_date_to   TYPE datum OPTIONAL
      EXPORTING
        ev_total_records   TYPE i
        ev_total_passed    TYPE i
        ev_total_failed    TYPE i
        ev_batch_id        TYPE sysuuid_x16
      RAISING
        zcx_bai_validation_error
        zcx_bai_db_error.

    METHODS get_batch_statistics
      RETURNING
        VALUE(rs_stats) TYPE ty_batch_stats.

  PROTECTED SECTION.

    TYPES: BEGIN OF ty_validator_config,
             bai_code  TYPE char10,
             flow_type TYPE char1,
             priority  TYPE int1,
           END OF ty_validator_config.

    DATA: mt_validators                TYPE STANDARD TABLE OF ty_validator_config
                                       WITH EMPTY KEY,
          mo_db_layer                  TYPE REF TO zcl_bai_db_layer,
          mo_logger                    TYPE REF TO zcl_bai_logger,
          mv_chunk_size                TYPE i,
          mv_batch_id                  TYPE sysuuid_x16,
          mv_consecutive_high_failures TYPE i VALUE 0,
          ms_batch_stats               TYPE ty_batch_stats,
          mv_start_timestamp           TYPE timestampl.

    METHODS process_chunk
      IMPORTING
        it_chunk        TYPE zif_bai_validator=>tt_febep_data
        iv_chunk_number TYPE i
      RAISING
        zcx_bai_validation_error
        zcx_bai_db_error.

    METHODS send_alert_email
      IMPORTING
        iv_subject TYPE string
        iv_body    TYPE string.

  PRIVATE SECTION.

ENDCLASS.



CLASS zcl_bai_mass_validator IMPLEMENTATION.


  METHOD constructor.

    " Validate chunk size
    IF iv_chunk_size <= 0 OR iv_chunk_size > 50000.
      mv_chunk_size = gc_default_chunk_size.
    ELSE.
      mv_chunk_size = iv_chunk_size.
    ENDIF.

    " Initialize dependencies
    CREATE OBJECT mo_db_layer.
    CREATE OBJECT mo_logger.

  ENDMETHOD.


  METHOD add_validator.

    " Validate inputs
    IF iv_bai_code IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bai_validation_error
        EXPORTING
          textid   = zcx_bai_validation_error=>invalid_configuration
          mv_text1 = 'BAI code is empty'.
    ENDIF.

    IF iv_flow_type IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bai_validation_error
        EXPORTING
          textid   = zcx_bai_validation_error=>invalid_configuration
          mv_text1 = 'Flow type is empty'.
    ENDIF.

    IF iv_flow_type <> 'D' AND iv_flow_type <> 'C'.
      RAISE EXCEPTION TYPE zcx_bai_validation_error
        EXPORTING
          textid   = zcx_bai_validation_error=>invalid_configuration
          mv_text1 = |Invalid flow type: { iv_flow_type }|.
    ENDIF.

    " Add to list
    APPEND VALUE #(
      bai_code  = iv_bai_code
      flow_type = iv_flow_type
      priority  = 50
    ) TO mt_validators.

  ENDMETHOD.


  METHOD load_all_active_validators.

    DATA: lt_configs TYPE TABLE OF zbai_validator_config.

    " Load from config table
    TRY.
        SELECT *
          FROM zbai_validator_config
          WHERE active = @abap_true
          ORDER BY priority ASCENDING
          INTO TABLE @lt_configs.

      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        RAISE EXCEPTION TYPE zcx_bai_db_error
          EXPORTING
            textid   = zcx_bai_db_error=>select_failed
            mv_table = 'ZBAI_VALIDATOR_CONFIG'.
    ENDTRY.

    IF lt_configs IS INITIAL.
      RAISE EXCEPTION TYPE zcx_bai_validation_error
        EXPORTING
          textid = zcx_bai_validation_error=>no_validators_configured.
    ENDIF.

    " Clear existing and load new
    CLEAR mt_validators.

    LOOP AT lt_configs INTO DATA(ls_config).
      APPEND VALUE #(
        bai_code  = ls_config-bai_code
        flow_type = ls_config-flow_type
        priority  = ls_config-priority
      ) TO mt_validators.
    ENDLOOP.

  ENDMETHOD.


  METHOD run_validation.

    DATA: lv_lock_key      TYPE char50,
          lv_end_timestamp TYPE timestampl,
          lt_febep_chunk   TYPE zif_bai_validator=>tt_febep_data,
          lv_chunk_num     TYPE i VALUE 0.

    " Check authorization
    AUTHORITY-CHECK OBJECT 'Z_BAI_VAL'
      ID 'ACTVT' FIELD '01'.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bai_validation_error
        EXPORTING
          textid = zcx_bai_validation_error=>not_authorized.
    ENDIF.

    " Acquire lock
    lv_lock_key = |{ iv_febep_date_from }{ iv_febep_date_to }|.

    CALL FUNCTION 'ENQUEUE_EZBAI_BATCH'
      EXPORTING
        mode_zbai_lock = 'E'
        mandt          = sy-mandt
        lock_key       = lv_lock_key
        _scope         = '2'
        _wait          = abap_false
      EXCEPTIONS
        foreign_lock   = 1
        system_failure = 2
        OTHERS         = 3.

    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_bai_validation_error
        EXPORTING
          textid   = zcx_bai_validation_error=>batch_already_running
          mv_text1 = |Date range { lv_lock_key }|.
    ENDIF.

    TRY.

        " Generate batch ID
        TRY.
            mv_batch_id = cl_system_uuid=>create_uuid_x16_static( ).
            ev_batch_id = mv_batch_id.
          CATCH cx_uuid_error.
            RAISE EXCEPTION TYPE zcx_bai_validation_error
              EXPORTING
                textid = zcx_bai_validation_error=>batch_id_generation_failed.
        ENDTRY.

        " Check validators
        IF mt_validators IS INITIAL.
          RAISE EXCEPTION TYPE zcx_bai_validation_error
            EXPORTING
              textid = zcx_bai_validation_error=>no_validators_configured.
        ENDIF.

        " Initialize batch statistics
        CLEAR ms_batch_stats.
        ms_batch_stats-batch_id        = mv_batch_id.
        ms_batch_stats-execution_date  = sy-datum.
        ms_batch_stats-execution_time  = sy-uzeit.

        " Start timing
        GET TIME STAMP FIELD mv_start_timestamp.

        " Log start
        mo_logger->info(
          iv_msgid = 'ZBAI'
          iv_msgno = '001'
          iv_msgv1 = |Batch { mv_batch_id }|
          iv_msgv2 = |{ iv_febep_date_from } - { iv_febep_date_to }|
        ).

        " ===== DB STREAMING - ONLY NEEDED FIELDS =====

        SELECT kukey, esnum, vorgc, belnr, gjahr,
               chect, betra, kwbtr, bewae, budat, bldat,
               augbl, valut
          FROM febep
          WHERE budat BETWEEN @iv_febep_date_from AND @iv_febep_date_to
          INTO TABLE @lt_febep_chunk
          PACKAGE SIZE @mv_chunk_size.

          " Increment chunk counter
          ADD 1 TO lv_chunk_num.

          " Log progress
          mo_logger->info(
            iv_msgid = 'ZBAI'
            iv_msgno = '002'
            iv_msgv1 = |{ lv_chunk_num }|
            iv_msgv2 = |{ lines( lt_febep_chunk ) }|
          ).

          " Process chunk
          process_chunk(
            it_chunk        = lt_febep_chunk
            iv_chunk_number = lv_chunk_num
          ).

          " Free memory
          CLEAR lt_febep_chunk.

          " Commit after each chunk
          mo_db_layer->commit_transaction( ).

        ENDSELECT.

        " End timing
        GET TIME STAMP FIELD lv_end_timestamp.

        " Calculate duration in seconds
        ms_batch_stats-duration_seconds = ( lv_end_timestamp - mv_start_timestamp ) / 1000000.

        ms_batch_stats-total_validators = lines( mt_validators ).

        " Calculate pass rate
        IF ms_batch_stats-total_records > 0.
          ms_batch_stats-overall_pass_rate =
            ( ms_batch_stats-total_passed / ms_batch_stats-total_records ) * 100.
        ENDIF.

        " Determine status
        IF ms_batch_stats-total_failed = 0.
          ms_batch_stats-status = 'S'.
        ELSEIF ms_batch_stats-overall_pass_rate >= 90.
          ms_batch_stats-status = 'W'.
        ELSE.
          ms_batch_stats-status = 'E'.
        ENDIF.

        " Save batch audit
        mo_db_layer->save_batch_audit(
          iv_batch_id         = mv_batch_id
          iv_execution_date   = ms_batch_stats-execution_date
          iv_execution_time   = ms_batch_stats-execution_time
          iv_total_records    = ms_batch_stats-total_records
          iv_total_passed     = ms_batch_stats-total_passed
          iv_total_failed     = ms_batch_stats-total_failed
          iv_bai_codes        = 'Multiple'
          iv_date_from        = iv_febep_date_from
          iv_date_to          = iv_febep_date_to
          iv_duration_seconds = ms_batch_stats-duration_seconds
          iv_status           = ms_batch_stats-status
        ).

        mo_db_layer->commit_transaction( ).

        " Set output
        ev_total_records = ms_batch_stats-total_records.
        ev_total_passed  = ms_batch_stats-total_passed.
        ev_total_failed  = ms_batch_stats-total_failed.

        " Log completion
        mo_logger->info(
          iv_msgid = 'ZBAI'
          iv_msgno = '003'
          iv_msgv1 = mv_batch_id
          iv_msgv2 = |{ ev_total_passed }|
          iv_msgv3 = |{ ev_total_failed }|
        ).

        mo_logger->save( ).

      CLEANUP.

        " Always release lock
        CALL FUNCTION 'DEQUEUE_EZBAI_BATCH'
          EXPORTING
            mode_zbai_lock = 'E'
            mandt          = sy-mandt
            lock_key       = lv_lock_key
            _scope         = '3'.

    ENDTRY.

  ENDMETHOD.


  METHOD process_chunk.

    DATA: lo_validator       TYPE REF TO zif_bai_validator,
          lt_chunk_results   TYPE zif_bai_validator=>tt_validation_result,
          ls_validator_stats TYPE zif_bai_validator=>ty_validation_stats,
          lv_chunk_failed    TYPE i,
          lv_chunk_total     TYPE i,
          lv_chunk_fail_rate TYPE p DECIMALS 2.

    lv_chunk_total = lines( it_chunk ).

    " Process each validator
    LOOP AT mt_validators INTO DATA(ls_validator).

      TRY.
          " Get validator instance from factory
          lo_validator = zcl_bai_validator_factory=>get_validator(
            iv_bai_code  = ls_validator-bai_code
            iv_flow_type = ls_validator-flow_type
          ).

          " ===== CRITICAL: FILTER CHUNK BY BAI CODE =====
          " Only pass records that match this validator's BAI code
          DATA(lt_filtered_chunk) = VALUE zif_bai_validator=>tt_febep_data(
            FOR <fs_rec> IN it_chunk WHERE ( vorgc = ls_validator-bai_code )
            ( <fs_rec> )
          ).

          " Skip if no matching records
          IF lt_filtered_chunk IS INITIAL.
            mo_logger->info(
              iv_msgid = 'ZBAI'
              iv_msgno = '010'
              iv_msgv1 = ls_validator-bai_code
              iv_msgv2 = |Chunk { iv_chunk_number }: No records for this BAI code|
            ).
            CONTINUE.
          ENDIF.

          " Validate filtered chunk
          lt_chunk_results = lo_validator->validate(
            it_febep    = lt_filtered_chunk
            iv_batch_id = mv_batch_id
          ).

          " Get statistics
          ls_validator_stats = lo_validator->get_statistics( ).

          " Aggregate to batch level
          ms_batch_stats-total_records += ls_validator_stats-total_count.
          ms_batch_stats-total_passed  += ls_validator_stats-passed_count.
          ms_batch_stats-total_failed  += ls_validator_stats-failed_count.

          " Save results
          IF lt_chunk_results IS NOT INITIAL.
            mo_db_layer->save_results(
              it_results  = lt_chunk_results
              iv_batch_id = mv_batch_id
            ).
          ENDIF.

          " Save summary
          mo_db_layer->save_batch_summary(
            iv_batch_id      = mv_batch_id
            iv_bai_code      = ls_validator_stats-bai_code
            iv_flow_type     = ls_validator_stats-flow_type
            iv_total_records = ls_validator_stats-total_count
            iv_passed_count  = ls_validator_stats-passed_count
            iv_failed_count  = ls_validator_stats-failed_count
            iv_warning_count = ls_validator_stats-warning_count
            iv_duration_ms   = ls_validator_stats-duration_ms
          ).

          " Log progress
          mo_logger->info(
            iv_msgid = 'ZBAI'
            iv_msgno = '010'
            iv_msgv1 = ls_validator-bai_code
            iv_msgv2 = |Chunk { iv_chunk_number }: { lines( lt_filtered_chunk ) } records|
            iv_msgv3 = |Passed: { ls_validator_stats-passed_count }, Failed: { ls_validator_stats-failed_count }|
          ).

          " Track chunk failures
          lv_chunk_failed += ls_validator_stats-failed_count.

        CATCH zcx_bai_config_error INTO DATA(lx_cfg).
          mo_logger->error(
            iv_msgid = 'ZBAI'
            iv_msgno = '101'
            iv_msgv1 = ls_validator-bai_code
            iv_msgv2 = lx_cfg->get_text( )
          ).

        CATCH zcx_bai_validation_error INTO DATA(lx_val).
          mo_logger->error(
            iv_msgid = 'ZBAI'
            iv_msgno = '102'
            iv_msgv1 = ls_validator-bai_code
            iv_msgv2 = lx_val->get_text( )
          ).

        CATCH zcx_bai_db_error INTO DATA(lx_db).
          mo_logger->error(
            iv_msgid = 'ZBAI'
            iv_msgno = '103'
            iv_msgv1 = ls_validator-bai_code
            iv_msgv2 = lx_db->get_text( )
          ).

      ENDTRY.

      CLEAR: lt_chunk_results, ls_validator_stats.

    ENDLOOP.

    " Check failure rate monitoring
    IF lv_chunk_total > 0.
      lv_chunk_fail_rate = ( lv_chunk_failed / lv_chunk_total ) * 100.

      IF lv_chunk_fail_rate > 50.

        mo_logger->warning(
          iv_msgid = 'ZBAI'
          iv_msgno = '150'
          iv_msgv1 = 'Multiple validators'
          iv_msgv2 = |{ lv_chunk_fail_rate }%|
          iv_msgv3 = |Chunk { iv_chunk_number }|
        ).

        ADD 1 TO mv_consecutive_high_failures.

        IF mv_consecutive_high_failures >= 3.

          mo_logger->error(
            iv_msgid = 'ZBAI'
            iv_msgno = '151'
            iv_msgv1 = |{ mv_consecutive_high_failures } consecutive chunks|
            iv_msgv2 = '50%'
          ).

          " Send alert
          send_alert_email(
            iv_subject = |BAI Validation Critical: High Failure Rate|
            iv_body    = |Batch { mv_batch_id } exceeded failure threshold|
          ).

          " Stop processing
          RAISE EXCEPTION TYPE zcx_bai_validation_error
            EXPORTING
              textid   = zcx_bai_validation_error=>failure_threshold_exceeded
              mv_text1 = |Failure rate { lv_chunk_fail_rate }% exceeds 50%|.

        ENDIF.

      ELSE.
        " Reset counter on good chunk
        CLEAR mv_consecutive_high_failures.
      ENDIF.

    ENDIF.

  ENDMETHOD.


  METHOD send_alert_email.

    DATA: lo_send_request TYPE REF TO cl_bcs,
          lo_document     TYPE REF TO cl_document_bcs,
          lo_recipient    TYPE REF TO if_recipient_bcs,
          lv_email        TYPE ad_smtpadr.

    TRY.
        " Get email from config
        SELECT SINGLE param_value
          FROM zbai_config
          WHERE param_name = 'ALERT_EMAIL'
          INTO @lv_email.

        IF lv_email IS INITIAL.
          lv_email = 'bai-alerts@company.com'.
        ENDIF.

        " Create and send email
        lo_send_request = cl_bcs=>create_persistent( ).

        lo_document = cl_document_bcs=>create_document(
          i_type    = 'RAW'
          i_text    = VALUE bcsy_text( ( line = iv_body ) )
          i_subject = iv_subject
        ).

        lo_send_request->set_document( lo_document ).

        lo_recipient = cl_cam_address_bcs=>create_internet_address( lv_email ).
        lo_send_request->add_recipient( lo_recipient ).
        lo_send_request->set_send_immediately( abap_true ).

        lo_send_request->send( ).
        COMMIT WORK.

      CATCH cx_bcs INTO DATA(lx_bcs).
        mo_logger->warning(
          iv_msgid = 'ZBAI'
          iv_msgno = '999'
          iv_msgv1 = |Email send failed: { lx_bcs->get_text( ) }|
        ).
    ENDTRY.

  ENDMETHOD.


  METHOD get_batch_statistics.
    rs_stats = ms_batch_stats.
  ENDMETHOD.


ENDCLASS.
