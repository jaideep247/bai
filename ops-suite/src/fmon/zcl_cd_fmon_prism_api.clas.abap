*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_api.clas.abap
*& Purpose:
*& PRISM status API service: every decision of one call - method, authority
*& (ZCD_OPS 01 / FMON), media type, size limit, parse / validate, idempotent
*& store with commit, HTTP status and JSON body. Writes only ZCD_FMON_PRISM;
*& never business data, payment files, jobs or routing.
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API, user decision 2026-11-06).
*& 2026-11-06 | Instant processing: bgPF unit queued in the LUW of the stored event.
*& 2026-11-07 | Parameters through ZCL_CD_OPS_FACTORY=>GET_PARAMS (ZIF_CA_OPS_PARAMS).
*& 2026-11-07 | Comment: FMON_PRISM_MAX_BYTES in ZCA_PARAM (ZCD_OPS_PARAM retired).
*& 2026-11-10 | 500 answer carries the error code and event ID only (no internal exception text); the
*&            | detail is kept server-side: run PRISM_API with a PRISM_STORE_FAILED finding (trace, class).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FMON PRISM status API - request service</p>
"! Order: 405 method -> 403 authority -> 415 media type -> 413 size -> 400 validation
"! -> store: 202 stored and the instant unit queued (both committed before the answer),
"! 200 duplicate (same payload),
"! 409 event ID reused with another payload, 500 store failure (rolled back; PRISM retries).
"! 401 (no or wrong logon) is answered by the ICF logon before this service runs.
CLASS zcl_cd_fmon_prism_api DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    METHODS handle
      IMPORTING
        is_request         TYPE zif_cd_fmon_prism_types=>ty_request
      RETURNING
        VALUE(rs_response) TYPE zif_cd_fmon_prism_types=>ty_response.

    "! Media type is application/json, charset (if given) UTF-8 - case-insensitive
    CLASS-METHODS is_json
      IMPORTING
        iv_content_type TYPE string
      RETURNING
        VALUE(rv_json)  TYPE abap_bool.

  PRIVATE SECTION.

    "! Request size limit: ZCA_PARAM FMON_PRISM_MAX_BYTES, else the delivered default
    METHODS max_bytes
      RETURNING
        VALUE(rv_bytes) TYPE i.

    METHODS store
      IMPORTING
        is_row             TYPE zif_cd_fmon_prism_types=>ty_row
      RETURNING
        VALUE(rs_response) TYPE zif_cd_fmon_prism_types=>ty_response.

    "! The store failure as a run of variant PRISM_API with one finding (trace in DETAILS), in its
    "! own small LUW after the rollback; if even that fails, PRISM's retry is the record
    METHODS record_failure
      IMPORTING
        is_row   TYPE zif_cd_fmon_prism_types=>ty_row
        ix_error TYPE REF TO cx_root.

    CLASS-METHODS respond
      IMPORTING
        iv_status_code     TYPE i
        iv_status          TYPE zif_cd_fmon_prism_types=>ty_wire_value
        iv_event_id        TYPE zif_cd_fmon_prism_types=>ty_event_id OPTIONAL
        it_errors          TYPE zif_cd_fmon_prism_types=>tt_error OPTIONAL
      RETURNING
        VALUE(rs_response) TYPE zif_cd_fmon_prism_types=>ty_response.

ENDCLASS.



CLASS zcl_cd_fmon_prism_api IMPLEMENTATION.

  METHOD handle.
    IF to_upper( is_request-method ) <> zif_cd_fmon_prism_types=>gc_method_post.
      rs_response = respond( iv_status_code = zif_cd_fmon_prism_types=>gc_http-method_not_allowed
                             iv_status      = zif_cd_fmon_prism_types=>gc_api_status-rejected
                             it_errors      = VALUE #( ( zcl_cd_fmon_prism_event=>new_error(
                                                           iv_code  = zif_cd_fmon_prism_types=>gc_error-method
                                                           iv_msgno = zif_cd_fmon_prism_types=>gc_msg-method_not_allowed
                                                           iv_v1    = is_request-method ) ) ) ).
      RETURN.
    ENDIF.

    IF zcl_ca_ops_factory=>get_auth( )->is_allowed( iv_activity = zif_ca_ops_auth=>gc_activity-create
                                                    iv_pe_area  = zif_cd_ops_types=>gc_pe_area-file_monitor )
       = abap_false.
      rs_response = respond( iv_status_code = zif_cd_fmon_prism_types=>gc_http-forbidden
                             iv_status      = zif_cd_fmon_prism_types=>gc_api_status-rejected
                             it_errors      = VALUE #( ( zcl_cd_fmon_prism_event=>new_error(
                                                           iv_code  = zif_cd_fmon_prism_types=>gc_error-not_authorized
                                                           iv_msgno = zif_cd_fmon_prism_types=>gc_msg-not_authorized
                                                           iv_v1    = zif_ca_ops_auth=>gc_activity-create
                                                           iv_v2    = zif_cd_ops_types=>gc_pe_area-file_monitor ) ) ) ).
      RETURN.
    ENDIF.

    IF is_json( is_request-content_type ) = abap_false.
      rs_response = respond( iv_status_code = zif_cd_fmon_prism_types=>gc_http-unsupported_media
                             iv_status      = zif_cd_fmon_prism_types=>gc_api_status-rejected
                             it_errors      = VALUE #( ( zcl_cd_fmon_prism_event=>new_error(
                                                           iv_code  = zif_cd_fmon_prism_types=>gc_error-media_type
                                                           iv_msgno = zif_cd_fmon_prism_types=>gc_msg-unsupported_media
                                                           iv_v1    = is_request-content_type ) ) ) ).
      RETURN.
    ENDIF.

    DATA(lv_max) = max_bytes( ).
    DATA(lv_size) = xstrlen( is_request-body ).
    IF lv_size > lv_max.
      rs_response = respond( iv_status_code = zif_cd_fmon_prism_types=>gc_http-payload_too_large
                             iv_status      = zif_cd_fmon_prism_types=>gc_api_status-rejected
                             it_errors      = VALUE #( ( zcl_cd_fmon_prism_event=>new_error(
                                                           iv_code  = zif_cd_fmon_prism_types=>gc_error-too_large
                                                           iv_msgno = zif_cd_fmon_prism_types=>gc_msg-payload_too_large
                                                           iv_v1    = lv_size
                                                           iv_v2    = lv_max ) ) ) ).
      RETURN.
    ENDIF.

    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    DATA(ls_mapped) = zcl_cd_fmon_prism_event=>map(
                        is_parsed  = zcl_cd_fmon_prism_event=>parse( is_request-body )
                        is_context = VALUE #( now       = zcl_ca_ops_factory=>get_clock( )->now( )
                                              user      = sy-uname
                                              time_zone = CONV #( lo_params->get_param(
                                                                    iv_name    = zif_cd_fmon_types=>gc_param-time_zone
                                                                    iv_default = CONV #( zif_ca_ops_types=>gc_time_zone_utc ) ) ) ) ).
    IF ls_mapped-errors IS NOT INITIAL.
      rs_response = respond( iv_status_code = zif_cd_fmon_prism_types=>gc_http-bad_request
                             iv_status      = zif_cd_fmon_prism_types=>gc_api_status-rejected
                             iv_event_id    = ls_mapped-row-event_id
                             it_errors      = ls_mapped-errors ).
      RETURN.
    ENDIF.

    rs_response = store( ls_mapped-row ).
  ENDMETHOD.


  METHOD store.
    DATA(lo_store) = zcl_ca_ops_factory=>get_store( ).
    TRY.
        DATA(lv_result) = zcl_cd_fmon_factory=>get_prism_dao( )->insert_event( is_row ).
      CATCH zcx_ca_ops_error cx_sy_open_sql_db INTO DATA(lx_error).
        " Nothing half-written stays; PRISM retries the same event ID
        lo_store->rollback( ).
        " The caller gets the error code and the event ID only - the internal text stays here
        record_failure( is_row = is_row ix_error = lx_error ).
        rs_response = respond( iv_status_code = zif_cd_fmon_prism_types=>gc_http-internal_error
                               iv_status      = zif_cd_fmon_prism_types=>gc_api_status-error
                               iv_event_id    = is_row-event_id
                               it_errors      = VALUE #( ( zcl_cd_fmon_prism_event=>new_error(
                                                             iv_code  = zif_cd_fmon_prism_types=>gc_error-store_failed
                                                             iv_msgno = zif_cd_fmon_prism_types=>gc_msg-store_failed
                                                             iv_v1    = is_row-event_id ) ) ) ).
        RETURN.
    ENDTRY.

    CASE lv_result.
      WHEN zif_cd_fmon_prism_types=>gc_store_result-inserted.
        " Instant processing: the bgPF unit is registered in this LUW and starts with the commit;
        " if it cannot be registered the event is still stored - the 5-minute run applies it
        TRY.
            zcl_cd_fmon_factory=>get_prism_queue( )->enqueue( is_row-event_id ).
          CATCH zcx_ca_ops_error ##NO_HANDLER.
        ENDTRY.
        " Durable before PRISM is told: 202 only after the commit
        lo_store->commit( ).
        rs_response = respond( iv_status_code = zif_cd_fmon_prism_types=>gc_http-accepted
                               iv_status      = zif_cd_fmon_prism_types=>gc_api_status-accepted
                               iv_event_id    = is_row-event_id ).
      WHEN zif_cd_fmon_prism_types=>gc_store_result-duplicate.
        rs_response = respond( iv_status_code = zif_cd_fmon_prism_types=>gc_http-ok
                               iv_status      = zif_cd_fmon_prism_types=>gc_api_status-duplicate
                               iv_event_id    = is_row-event_id ).
      WHEN OTHERS.
        rs_response = respond( iv_status_code = zif_cd_fmon_prism_types=>gc_http-conflict
                               iv_status      = zif_cd_fmon_prism_types=>gc_api_status-conflict
                               iv_event_id    = is_row-event_id
                               it_errors      = VALUE #( ( zcl_cd_fmon_prism_event=>new_error(
                                                             iv_code  = zif_cd_fmon_prism_types=>gc_error-event_id_conflict
                                                             iv_field = zif_cd_fmon_prism_types=>gc_key-event_id
                                                             iv_msgno = zif_cd_fmon_prism_types=>gc_msg-event_id_conflict
                                                             iv_v1    = is_row-event_id ) ) ) ).
    ENDCASE.
  ENDMETHOD.


  METHOD record_failure.
    DATA(lo_store) = zcl_ca_ops_factory=>get_store( ).
    TRY.
        DATA(ls_run) = lo_store->start_run( iv_pe_area = zif_cd_ops_types=>gc_pe_area-file_monitor
                                            iv_variant = zif_cd_fmon_prism_types=>gc_api_variant ).
        DATA(lt_findings) = VALUE zif_ca_ops_types=>tt_finding(
          ( object_type = zif_cd_fmon_prism_types=>gc_object_type_event
            object_key  = is_row-event_id
            reference   = is_row-event_id
            check_code  = zif_cd_fmon_prism_types=>gc_check_store_failed
            severity    = zif_ca_ops_types=>gc_severity-error
            action      = zif_ca_ops_types=>gc_action-notify
            message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_fmon_prism_types=>gc_msg-store_failed
                                                 iv_v1    = is_row-event_id
                                                 iv_tail  = ix_error->get_text( ) )
            details     = zcl_ca_ops_util=>exception_trace( ix_error )
            error_class = zcl_ca_ops_util=>error_class( ix_error ) ) ).
        lo_store->save_findings( EXPORTING it_findings = lt_findings CHANGING cs_run = ls_run ).
        ls_run-status   = zif_ca_ops_types=>gc_run_status-error.
        ls_run-rag      = zif_ca_ops_types=>gc_rag-red.
        ls_run-ended_at = zcl_ca_ops_factory=>get_clock( )->now( ).
        ls_run-message  = lt_findings[ 1 ]-message.
        lo_store->finish_run( ls_run ).
        lo_store->commit( ).
      CATCH zcx_ca_ops_error cx_sy_open_sql_db.
        " the database refuses this record too: PRISM retries the event ID, the 500 is answered
        lo_store->rollback( ).
    ENDTRY.
  ENDMETHOD.


  METHOD is_json.
    SPLIT to_lower( iv_content_type ) AT `;` INTO TABLE DATA(lt_parts).
    DATA(lv_ok) = abap_false.
    LOOP AT lt_parts ASSIGNING FIELD-SYMBOL(<lv_part>).
      DATA(lv_index) = sy-tabix.
      DATA(lv_part) = condense( <lv_part> ).
      IF lv_index = 1.
        lv_ok = xsdbool( lv_part = zif_cd_fmon_prism_types=>gc_media_json ).
      ELSEIF substring_before( val = lv_part sub = `=` ) = zif_cd_fmon_prism_types=>gc_charset_param
             AND lv_part <> zif_cd_fmon_prism_types=>gc_charset_utf8.
        lv_ok = abap_false.
      ENDIF.
    ENDLOOP.
    rv_json = lv_ok.
  ENDMETHOD.


  METHOD max_bytes.
    rv_bytes = zcl_ca_ops_util=>to_decimal(
                 iv_value   = zcl_cd_ops_factory=>get_params( )->get_param(
                                iv_name    = zif_cd_fmon_prism_types=>gc_param_max_bytes
                                iv_default = |{ zif_cd_fmon_prism_types=>gc_default_max_bytes }| )
                 iv_default = zif_cd_fmon_prism_types=>gc_default_max_bytes ).
    IF rv_bytes <= 0.
      rv_bytes = zif_cd_fmon_prism_types=>gc_default_max_bytes.
    ENDIF.
  ENDMETHOD.


  METHOD respond.
    rs_response-status_code = iv_status_code.
    rs_response-status      = iv_status.
    rs_response-event_id    = iv_event_id.
    rs_response-errors      = it_errors.
    rs_response-body        = zcl_cd_fmon_prism_event=>to_json( rs_response ).
  ENDMETHOD.

ENDCLASS.
