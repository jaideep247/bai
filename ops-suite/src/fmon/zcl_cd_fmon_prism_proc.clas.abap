*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_proc.clas.abap
*& Purpose:
*& Instant processing of one stored PRISM event (body of the bgPF unit): read
*& the event, convert it with the configured PRISM source (same key rules as
*& the 5-minute run), apply it through ZCL_CD_FMON_ENGINE=>RUN_EVENT and mark
*& it processed. Suite-internal only: no business data, no job start.
*& Modification log:
*& 2026-11-06 | Initial version (instant PRISM processing, user decision 2026-11-06).
*& 2026-11-07 | Time zone parameter through ZCL_CD_OPS_FACTORY=>GET_PARAMS (ZIF_CD_OPS_PARAMS).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FMON PRISM status API - instant processing of one event</p>
"! The event stays unprocessed (the 5-minute run applies it - safety net) when: it needs a file
"! FMON does not know yet (deferred), another process changed the file in every attempt
"! (PERSIST_CONFLICT, audit A04), the registry could not be saved, the PRISM source is not
"! configured, or the engine raised. An event already processed is not applied again.
CLASS zcl_cd_fmon_prism_proc DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_outcome,
        "! The event was applied and marked processed
        processed TYPE abap_bool,
        "! Left to the 5-minute run (see class documentation)
        deferred  TYPE abap_bool,
        attempts  TYPE i,
        result    TYPE zif_cd_fmon_types=>ty_result,
      END OF ty_outcome.

    METHODS process
      IMPORTING
        iv_event_id       TYPE zif_cd_fmon_prism_types=>ty_event_id
      RETURNING
        VALUE(rs_outcome) TYPE ty_outcome.

  PRIVATE SECTION.
    "! Engine findings that leave the event to the 5-minute run
    METHODS needs_retry
      IMPORTING
        is_result        TYPE zif_cd_fmon_types=>ty_result
      RETURNING
        VALUE(rv_retry)  TYPE abap_bool.

    METHODS failed
      IMPORTING
        is_result         TYPE zif_cd_fmon_types=>ty_result
      RETURNING
        VALUE(rv_failed)  TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_fmon_prism_proc IMPLEMENTATION.

  METHOD process.
    DATA ls_request TYPE zif_cd_fmon_types=>ty_read_request.

    DATA(lo_prism_dao) = zcl_cd_fmon_factory=>get_prism_dao( ).
    DATA(ls_row) = lo_prism_dao->read_event( iv_event_id ).
    IF ls_row IS INITIAL OR ls_row-processed_at IS NOT INITIAL.
      RETURN.
    ENDIF.

    " The configured PRISM source (ZCD_FMON_SRC row with the PRISM adapter) and its stage map
    DATA(lo_dao) = zcl_cd_fmon_factory=>get_dao( ).
    DATA(lt_srcs) = lo_dao->get_sources( ).
    LOOP AT lt_srcs ASSIGNING FIELD-SYMBOL(<ls_src>)
         WHERE adapter_class = zif_cd_fmon_prism_types=>gc_adapter_class AND active = abap_true.
      ls_request-src = <ls_src>.
      EXIT.
    ENDLOOP.
    IF ls_request-src IS INITIAL.
      rs_outcome-deferred = abap_true.
      RETURN.
    ENDIF.
    DATA(lt_maps) = lo_dao->get_source_maps( ).
    ls_request-maps = VALUE #( FOR ls_map IN lt_maps WHERE ( src_id = ls_request-src-src_id ) ( ls_map ) ).
    DATA(lo_store) = zcl_cd_ops_factory=>get_store( ).
    ls_request-time_zone = zcl_cd_ops_factory=>get_params( )->get_param(
                             iv_name    = zif_cd_fmon_types=>gc_param-time_zone
                             iv_default = CONV #( zif_cd_ops_types=>gc_time_zone_utc ) ).

    TRY.
        DATA(lt_records) = zcl_cd_fmon_adapter_prism=>to_records( is_request = ls_request
                                                                  it_rows    = VALUE #( ( ls_row ) ) ).
        DO zif_cd_fmon_prism_types=>gc_unit_attempts TIMES.
          rs_outcome-attempts += 1.
          " A fresh engine re-reads the file with its current version on every attempt
          rs_outcome-result = zcl_cd_fmon_factory=>get_engine( )->run_event(
                                EXPORTING is_src      = ls_request-src
                                          it_records  = lt_records
                                IMPORTING ev_deferred = rs_outcome-deferred ).
          IF needs_retry( rs_outcome-result ) = abap_false.
            EXIT.
          ENDIF.
        ENDDO.
      CATCH zcx_cd_ops_error cx_sy_open_sql_db.
        " Left unprocessed: the 5-minute run applies the event
        lo_store->rollback( ).
        rs_outcome-deferred = abap_true.
        RETURN.
    ENDTRY.

    IF rs_outcome-deferred = abap_true OR failed( rs_outcome-result ) = abap_true.
      rs_outcome-deferred = abap_true.
      RETURN.
    ENDIF.
    TRY.
        lo_prism_dao->mark_processed( it_event_ids = VALUE #( ( iv_event_id ) )
                                      iv_at        = zcl_cd_ops_factory=>get_clock( )->now( ) ).
        lo_store->commit( ).
        rs_outcome-processed = abap_true.
      CATCH zcx_cd_ops_error.
        " Not marked: the 5-minute run re-applies it (idempotent)
        lo_store->rollback( ).
    ENDTRY.
  ENDMETHOD.


  METHOD needs_retry.
    rv_retry = xsdbool( line_exists( is_result-findings[ check_code = zif_cd_fmon_types=>gc_check_code-persist_conflict ] ) ).
  ENDMETHOD.


  METHOD failed.
    " Unmapped / malformed events stay unprocessed too: the 5-minute run keeps reporting them,
    " and applies them once the interface or stage map is configured
    LOOP AT is_result-findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      CASE <ls_finding>-check_code.
        WHEN zif_cd_fmon_types=>gc_check_code-persist_conflict
          OR zif_cd_fmon_types=>gc_check_code-persist_error
          OR zif_cd_fmon_types=>gc_check_code-ref_ambiguous
          OR zif_cd_fmon_types=>gc_check_code-unmapped_file
          OR zif_cd_fmon_types=>gc_check_code-unmapped_status
          OR zif_cd_fmon_types=>gc_check_code-malformed_row.
          rv_failed = abap_true.
          RETURN.
        WHEN OTHERS.
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
