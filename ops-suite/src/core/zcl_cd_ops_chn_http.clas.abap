*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_chn_http.clas.abap
*& Purpose:
*& Alert channel HTTP: POSTs the alert as JSON to an SM59 destination (e.g. a
*& Teams/ServiceNow/PagerDuty webhook proxied by PRISM). The destination name is
*& configuration; credentials live in SM59, never in code. Non-2xx = failure.
*& The body carries runId, dedupKey (alert intent), eventAction, source, system,
*& occurredAt (UTC) and a correlation object so ServiceNow Event Management /
*& PagerDuty Events v2 de-duplicate retries (schema: docs/ALERTING.md).
*& Thin wrapper over CL_HTTP_CLIENT - covered by the QA1 integration test.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Webhook key peArea (rename regression fixed); column names in comments.
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Correlation and de-duplication fields (runId, dedupKey, eventAction, source, system,
*&              occurredAt, correlation); existing keys kept.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - alert channel HTTP webhook</p>
CLASS zcl_cd_ops_chn_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert_channel.

    "! Event action of the payload (wire format, PagerDuty Events v2 / ServiceNow event).
    "! The suite raises events only; resolution is done in the receiver.
    CONSTANTS:
      BEGIN OF gc_event_action,
        trigger TYPE string VALUE `trigger`,
      END OF gc_event_action.
    "! Event source of the payload (wire format; receivers route on it)
    CONSTANTS gc_source TYPE string VALUE `ZCD_OPS`.

    "! JSON body; pure apart from the system ID, so it is unit-testable without a destination
    CLASS-METHODS to_json
      IMPORTING
        is_message     TYPE zif_cd_ops_types=>ty_alert_message
      RETURNING
        VALUE(rv_json) TYPE string.

    "! De-duplication key: the alert intent (A17) - equal for every attempt of the same
    "! alert; without one, payment engine area / run / rule (still deterministic)
    CLASS-METHODS dedup_key
      IMPORTING
        is_message    TYPE zif_cd_ops_types=>ty_alert_message
      RETURNING
        VALUE(rv_key) TYPE string.

  PRIVATE SECTION.
    "! HTTP step named in message 023 when the request could not be sent
    CONSTANTS gc_http_step_send TYPE string VALUE `SEND`.
    "! Webhook payload format (wire format of the receiver, not text)
    CONSTANTS gc_content_type TYPE string VALUE `application/json; charset=utf-8`.
    "! JSON literal for an unknown value (wire format)
    CONSTANTS gc_json_null TYPE string VALUE `null`.
    "! ISO 8601 designator of UTC
    CONSTANTS gc_utc_designator TYPE string VALUE `Z`.

    "! UTC time as ISO 8601 with Z (seconds), or JSON null when unknown
    CLASS-METHODS json_time
      IMPORTING
        iv_timestamp   TYPE timestampl
      RETURNING
        VALUE(rv_json) TYPE string.

    CLASS-METHODS json_string
      IMPORTING
        iv_value       TYPE clike
      RETURNING
        VALUE(rv_json) TYPE string.

ENDCLASS.



CLASS zcl_cd_ops_chn_http IMPLEMENTATION.

  METHOD zif_cd_ops_alert_channel~deliver.
    DATA lo_client TYPE REF TO if_http_client.
    DATA lv_status TYPE i.
    DATA lv_reason TYPE string.

    cl_http_client=>create_by_destination(
      EXPORTING
        destination              = CONV rfcdest( is_message-destination )
      IMPORTING
        client                   = lo_client
      EXCEPTIONS
        argument_not_found       = 1
        destination_not_found    = 2
        destination_no_authority = 3
        plugin_not_active        = 4
        internal_error           = 5
        OTHERS                   = 6 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e023(zcd_ops) WITH is_message-destination sy-subrc.
    ENDIF.

    lo_client->request->set_method( if_http_request=>co_request_method_post ).
    lo_client->request->set_content_type( gc_content_type ).
    lo_client->request->set_cdata( to_json( is_message ) ).

    lo_client->send( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc = 0.
      lo_client->receive( EXCEPTIONS OTHERS = 1 ).
    ENDIF.
    IF sy-subrc <> 0.
      lo_client->close( EXCEPTIONS OTHERS = 0 ).
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e023(zcd_ops) WITH is_message-destination gc_http_step_send.
    ENDIF.

    lo_client->response->get_status( IMPORTING code = lv_status reason = lv_reason ).
    lo_client->close( EXCEPTIONS OTHERS = 0 ).
    IF lv_status < 200 OR lv_status >= 300.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e024(zcd_ops) WITH is_message-destination lv_status lv_reason.
    ENDIF.
  ENDMETHOD.


  METHOD to_json.
    rv_json = |\{"ruleId":{ json_string( is_message-rule_id ) },|
           && |"peArea":{ json_string( is_message-pe_area ) },|
           && |"severity":{ json_string( is_message-severity ) },|
           && |"subject":{ json_string( is_message-subject ) },|
           && |"items":{ is_message-item_count },|
           && |"text":{ json_string( is_message-text ) },|
           && |"runId":{ json_string( |{ is_message-run_id }| ) },|
           && |"dedupKey":{ json_string( dedup_key( is_message ) ) },|
           && |"eventAction":{ json_string( gc_event_action-trigger ) },|
           && |"source":{ json_string( gc_source ) },|
           && |"system":{ json_string( |{ sy-sysid }/{ sy-mandt }| ) },|
           && |"occurredAt":{ json_time( is_message-occurred_at ) },|
           && |"correlation":\{"runId":{ json_string( |{ is_message-run_id }| ) },|
           && |"logId":{ json_string( is_message-extnumber ) }\}\}|.
  ENDMETHOD.


  METHOD dedup_key.
    rv_key = COND #( WHEN is_message-intent_key IS NOT INITIAL
                     THEN is_message-intent_key
                     ELSE |{ is_message-pe_area }/{ is_message-run_id }/{ is_message-rule_id }| ).
  ENDMETHOD.


  METHOD json_time.
    DATA lv_seconds TYPE timestamp.
    IF iv_timestamp IS INITIAL.
      rv_json = gc_json_null.
      RETURN.
    ENDIF.
    lv_seconds = trunc( iv_timestamp ).
    rv_json = |"{ lv_seconds TIMESTAMP = ISO }{ gc_utc_designator }"|.
  ENDMETHOD.


  METHOD json_string.
    rv_json = |"{ escape( val = condense( CONV string( iv_value ) ) format = cl_abap_format=>e_json_string ) }"|.
  ENDMETHOD.

ENDCLASS.
