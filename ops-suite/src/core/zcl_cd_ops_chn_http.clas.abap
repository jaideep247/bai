*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_chn_http.clas.abap
*& Purpose:
*& Alert channel HTTP: POSTs the alert as JSON to an SM59 destination (e.g. a
*& Teams/ServiceNow/PagerDuty webhook proxied by PRISM). The destination name is
*& configuration; credentials live in SM59, never in code. Non-2xx = failure.
*& Thin wrapper over CL_HTTP_CLIENT - covered by the QA1 integration test.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - alert channel HTTP webhook</p>
CLASS zcl_cd_ops_chn_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_alert_channel.

    "! JSON body; pure, so it is unit-testable without a destination
    CLASS-METHODS to_json
      IMPORTING
        is_message     TYPE zif_cd_ops_types=>ty_alert_message
      RETURNING
        VALUE(rv_json) TYPE string.

  PRIVATE SECTION.
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
    lo_client->request->set_content_type( 'application/json; charset=utf-8' ).
    lo_client->request->set_cdata( to_json( is_message ) ).

    lo_client->send( EXCEPTIONS OTHERS = 1 ).
    IF sy-subrc = 0.
      lo_client->receive( EXCEPTIONS OTHERS = 1 ).
    ENDIF.
    IF sy-subrc <> 0.
      lo_client->close( EXCEPTIONS OTHERS = 0 ).
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e023(zcd_ops) WITH is_message-destination 'SEND'.
    ENDIF.

    lo_client->response->get_status( IMPORTING code = lv_status reason = lv_reason ).
    lo_client->close( EXCEPTIONS OTHERS = 0 ).
    IF lv_status < 200 OR lv_status >= 300.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e024(zcd_ops) WITH is_message-destination lv_status lv_reason.
    ENDIF.
  ENDMETHOD.


  METHOD to_json.
    rv_json = |\{"ruleId":{ json_string( is_message-rule_id ) },|
           && |"module":{ json_string( is_message-module ) },|
           && |"severity":{ json_string( is_message-severity ) },|
           && |"subject":{ json_string( is_message-subject ) },|
           && |"items":{ is_message-item_count },|
           && |"text":{ json_string( is_message-text ) }\}|.
  ENDMETHOD.


  METHOD json_string.
    rv_json = |"{ escape( val = condense( CONV string( iv_value ) ) format = cl_abap_format=>e_json_string ) }"|.
  ENDMETHOD.

ENDCLASS.
