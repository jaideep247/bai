*&---------------------------------------------------------------------*
*& Artifact: zif_cd_fmon_prism_types.intf.abap
*& Purpose:
*& Types and constants of the PRISM status API (POST /sap/zcd_ops/prism_status):
*& wire format (JSON keys, milestones, directions, error codes, HTTP status),
*& the stored row of ZCD_FMON_PRISM, request / response of the service. No logic.
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API, user decision 2026-11-06).
*& 2026-11-06 | Instant processing (bgPF unit per event): PROCESSED_AT, adapter, parameters.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FMON PRISM status API - types and wire format</p>
"! Contract: docs/PRISM_Status_API.md. JSON keys, milestone, direction and error code values
"! are the interface agreed with PRISM (wire format), not texts.
INTERFACE zif_cd_fmon_prism_types
  PUBLIC.

  TYPES ty_event_id     TYPE c LENGTH 64.
  TYPES ty_milestone    TYPE c LENGTH 10.
  TYPES ty_counterparty TYPE c LENGTH 20.
  TYPES ty_prism_ref    TYPE c LENGTH 64.
  TYPES ty_error_code   TYPE c LENGTH 20.
  TYPES ty_error_text   TYPE c LENGTH 255.
  "! Outcome of storing one event: I inserted, D duplicate (same payload), C conflict
  TYPES ty_store_result TYPE c LENGTH 1.
  "! Wire values of the response field "status" and of error codes
  TYPES ty_wire_value   TYPE c LENGTH 30.

  "! Milestones PRISM reports (wire values; mapped to FMON stages in ZCD_FMON_SRCMAP)
  CONSTANTS:
    BEGIN OF gc_milestone,
      received  TYPE ty_milestone VALUE 'RECEIVED',
      delivered TYPE ty_milestone VALUE 'DELIVERED',
      failed    TYPE ty_milestone VALUE 'FAILED',
    END OF gc_milestone.

  "! Direction on the wire; stored as the FMON direction code (O / I)
  CONSTANTS:
    BEGIN OF gc_wire_direction,
      outbound TYPE string VALUE `OUTBOUND`,
      inbound  TYPE string VALUE `INBOUND`,
    END OF gc_wire_direction.

  "! JSON member names of request and response (wire format, docs/PRISM_Status_API.md)
  CONSTANTS:
    BEGIN OF gc_key,
      event_id      TYPE string VALUE `eventId`,
      file_ref      TYPE string VALUE `fileReference`,
      iface_id      TYPE string VALUE `interfaceId`,
      direction     TYPE string VALUE `direction`,
      milestone     TYPE string VALUE `milestone`,
      occurred_at   TYPE string VALUE `occurredAt`,
      counterparty  TYPE string VALUE `counterparty`,
      prism_ref     TYPE string VALUE `prismReference`,
      record_count  TYPE string VALUE `recordCount`,
      control_total TYPE string VALUE `controlTotal`,
      currency      TYPE string VALUE `currency`,
      error_code    TYPE string VALUE `errorCode`,
      error_text    TYPE string VALUE `errorText`,
      status        TYPE string VALUE `status`,
      errors        TYPE string VALUE `errors`,
      code          TYPE string VALUE `code`,
      field         TYPE string VALUE `field`,
      message       TYPE string VALUE `message`,
    END OF gc_key.

  "! Element names of the sXML JSON-XML representation (object, array, str, num, bool, null)
  CONSTANTS:
    BEGIN OF gc_jsonxml,
      object    TYPE string VALUE `object`,
      array     TYPE string VALUE `array`,
      str       TYPE string VALUE `str`,
      num       TYPE string VALUE `num`,
      bool      TYPE string VALUE `bool`,
      null      TYPE string VALUE `null`,
      attr_name TYPE string VALUE `name`,
    END OF gc_jsonxml.

  "! HTTP status codes of the API
  CONSTANTS:
    BEGIN OF gc_http,
      ok                 TYPE i VALUE 200,
      accepted           TYPE i VALUE 202,
      bad_request        TYPE i VALUE 400,
      forbidden          TYPE i VALUE 403,
      method_not_allowed TYPE i VALUE 405,
      conflict           TYPE i VALUE 409,
      payload_too_large  TYPE i VALUE 413,
      unsupported_media  TYPE i VALUE 415,
      internal_error     TYPE i VALUE 500,
    END OF gc_http.

  "! Response field "status" (wire values)
  CONSTANTS:
    BEGIN OF gc_api_status,
      accepted  TYPE ty_wire_value VALUE 'ACCEPTED',
      duplicate TYPE ty_wire_value VALUE 'DUPLICATE',
      rejected  TYPE ty_wire_value VALUE 'REJECTED',
      conflict  TYPE ty_wire_value VALUE 'CONFLICT',
      error     TYPE ty_wire_value VALUE 'ERROR',
    END OF gc_api_status.

  "! Error codes of the response list (wire values)
  CONSTANTS:
    BEGIN OF gc_error,
      missing           TYPE ty_wire_value VALUE 'MISSING_FIELD',
      invalid           TYPE ty_wire_value VALUE 'INVALID_VALUE',
      too_long          TYPE ty_wire_value VALUE 'VALUE_TOO_LONG',
      duplicate_key     TYPE ty_wire_value VALUE 'DUPLICATE_FIELD',
      not_scalar        TYPE ty_wire_value VALUE 'NOT_A_SCALAR',
      malformed_json    TYPE ty_wire_value VALUE 'MALFORMED_JSON',
      not_an_object     TYPE ty_wire_value VALUE 'NOT_A_JSON_OBJECT',
      method            TYPE ty_wire_value VALUE 'METHOD_NOT_ALLOWED',
      media_type        TYPE ty_wire_value VALUE 'UNSUPPORTED_MEDIA_TYPE',
      too_large         TYPE ty_wire_value VALUE 'PAYLOAD_TOO_LARGE',
      not_authorized    TYPE ty_wire_value VALUE 'NOT_AUTHORIZED',
      event_id_conflict TYPE ty_wire_value VALUE 'EVENT_ID_CONFLICT',
      store_failed      TYPE ty_wire_value VALUE 'STORE_FAILED',
    END OF gc_error.

  CONSTANTS:
    BEGIN OF gc_store_result,
      inserted  TYPE ty_store_result VALUE 'I',
      duplicate TYPE ty_store_result VALUE 'D',
      conflict  TYPE ty_store_result VALUE 'C',
    END OF gc_store_result.

  "! HTTP method and media type accepted (wire format)
  CONSTANTS gc_method_post TYPE string VALUE `POST`.
  CONSTANTS gc_media_json TYPE string VALUE `application/json`.
  CONSTANTS gc_content_type_json TYPE string VALUE `application/json; charset=utf-8`.
  "! Charset parameter accepted in the request content type (sXML reads UTF-8)
  CONSTANTS gc_charset_utf8 TYPE string VALUE `charset=utf-8`.
  CONSTANTS gc_charset_param TYPE string VALUE `charset`.
  "! JSON literal of an absent value
  CONSTANTS gc_json_null TYPE string VALUE `null`.
  "! Response header naming the allowed method on 405 (wire format)
  CONSTANTS gc_header_allow TYPE string VALUE `Allow`.
  "! UTC designators accepted in occurredAt (ISO 8601)
  CONSTANTS:
    BEGIN OF gc_utc,
      zulu   TYPE string VALUE `Z`,
      offset TYPE string VALUE `+00:00`,
    END OF gc_utc.

  "! Request body limit in ZCD_OPS_PARAM [16384 bytes]
  CONSTANTS gc_param_max_bytes TYPE zif_cd_ops_types=>ty_param_name VALUE 'FMON_PRISM_MAX_BYTES'.
  CONSTANTS gc_default_max_bytes TYPE i VALUE 16384.
  "! Instant processing: the unit saves findings and hands them to the alert router (X, default),
  "! or only updates the registry and leaves findings and alerts to the 5-minute run (blank)
  CONSTANTS gc_param_instant TYPE zif_cd_ops_types=>ty_param_name VALUE 'FMON_PRISM_INSTANT'.
  CONSTANTS gc_default_instant TYPE string VALUE `X`.
  "! Adapter of the configured ZCD_FMON_SRC row that reads ZCD_FMON_PRISM (batch and unit)
  CONSTANTS gc_adapter_class TYPE zif_cd_ops_types=>ty_class_name VALUE 'ZCL_CD_FMON_ADAPTER_PRISM'.
  "! Attempts of one unit when another process changed the file meanwhile (audit A04)
  CONSTANTS gc_unit_attempts TYPE i VALUE 2.
  "! Name of the background process (bgPF, SBGRFCMON)
  CONSTANTS gc_process_name TYPE string VALUE `ZCD_FMON_PRISM`.
  "! occurredAt may lie at most this many minutes after the SAP clock (clock skew)
  CONSTANTS gc_max_future_minutes TYPE i VALUE 15.

  "! Patterns (PCRE) of the validation and of the masking of account-like numbers
  CONSTANTS:
    BEGIN OF gc_pcre,
      "! YYYY-MM-DDThh:mm:ss[.f{1,7}](Z|+00:00)
      timestamp TYPE string VALUE `^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(\.\d{1,7})?(Z|\+00:00)$`,
      "! Identifiers: letters, digits and . _ : - (no blanks)
      ident     TYPE string VALUE `^[A-Za-z0-9._:\-]+$`,
      "! Interface ID of ZCD_FMON_IFACE
      iface     TYPE string VALUE `^[A-Z0-9_]+$`,
      "! ISO 4217 currency code
      currency  TYPE string VALUE `^[A-Z]{3}$`,
      "! Non-negative integer
      integer   TYPE string VALUE `^\d{1,10}$`,
      "! Amount: up to 21 integer digits and 2 decimals, optional sign
      amount    TYPE string VALUE `^-?\d{1,21}(\.\d{1,2})?$`,
      "! Leading part of a run of 8 or more digits (keeps the last 4 digits visible)
      account   TYPE string VALUE `(?<!\d)\d{4,}(?=\d{4}(?!\d))`,
      "! Control characters (CR, LF, TAB, ...) - not allowed in a file reference
      control   TYPE string VALUE `[\x00-\x1F]`,
    END OF gc_pcre.
  "! Replacement of the masked leading digits of an account-like number
  CONSTANTS gc_mask TYPE string VALUE `****`.
  "! Highest recordCount accepted (INT4)
  CONSTANTS gc_max_count TYPE i VALUE 2147483647.

  "! Message numbers (class ZCD_OPS) of the API texts
  CONSTANTS:
    BEGIN OF gc_msg,
      field_missing       TYPE zif_cd_ops_types=>ty_msgno VALUE '250',
      field_invalid       TYPE zif_cd_ops_types=>ty_msgno VALUE '251',
      field_too_long      TYPE zif_cd_ops_types=>ty_msgno VALUE '252',
      field_duplicate     TYPE zif_cd_ops_types=>ty_msgno VALUE '253',
      field_not_scalar    TYPE zif_cd_ops_types=>ty_msgno VALUE '254',
      malformed_json      TYPE zif_cd_ops_types=>ty_msgno VALUE '255',
      not_an_object       TYPE zif_cd_ops_types=>ty_msgno VALUE '256',
      method_not_allowed  TYPE zif_cd_ops_types=>ty_msgno VALUE '257',
      unsupported_media   TYPE zif_cd_ops_types=>ty_msgno VALUE '258',
      payload_too_large   TYPE zif_cd_ops_types=>ty_msgno VALUE '259',
      not_authorized      TYPE zif_cd_ops_types=>ty_msgno VALUE '260',
      event_id_conflict   TYPE zif_cd_ops_types=>ty_msgno VALUE '261',
      store_failed        TYPE zif_cd_ops_types=>ty_msgno VALUE '262',
      occurred_in_future  TYPE zif_cd_ops_types=>ty_msgno VALUE '263',
      total_needs_ccy     TYPE zif_cd_ops_types=>ty_msgno VALUE '264',
      not_queued          TYPE zif_cd_ops_types=>ty_msgno VALUE '268',
    END OF gc_msg.

  " ---------------------------------------------------------------- stored event
  "! One PRISM call as stored in ZCD_FMON_PRISM (without client)
  TYPES:
    BEGIN OF ty_row,
      event_id      TYPE ty_event_id,
      file_ref      TYPE zif_cd_fmon_types=>ty_file_name,
      iface_id      TYPE zif_cd_fmon_types=>ty_iface_id,
      direction     TYPE zif_cd_fmon_types=>ty_direction,
      milestone     TYPE ty_milestone,
      occurred_at   TYPE timestampl,
      counterparty  TYPE ty_counterparty,
      prism_ref     TYPE ty_prism_ref,
      record_count  TYPE i,
      "! recordCount was sent (X) - blank = not reported, not zero
      count_sent    TYPE abap_bool,
      control_total TYPE zif_cd_ops_types=>ty_amount,
      currency      TYPE waers,
      error_code    TYPE ty_error_code,
      error_text    TYPE ty_error_text,
      "! occurredAt in FMON_TIME_ZONE (same rule as the generic adapter for TS_FIELD)
      business_date TYPE d,
      received_at   TYPE timestampl,
      received_by   TYPE syuname,
      "! FMON applied the event (bgPF unit); initial = the 5-minute run still reads it
      processed_at  TYPE timestampl,
    END OF ty_row.
  TYPES tt_row TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
  TYPES tt_event_id TYPE STANDARD TABLE OF ty_event_id WITH EMPTY KEY.

  " ---------------------------------------------------------------- parsing
  "! One top-level JSON member: name, JSON-XML kind (str, num, bool, null) and text value
  TYPES:
    BEGIN OF ty_member,
      name  TYPE string,
      kind  TYPE string,
      value TYPE string,
    END OF ty_member.
  TYPES tt_member TYPE HASHED TABLE OF ty_member WITH UNIQUE KEY name.

  TYPES:
    BEGIN OF ty_error,
      code    TYPE ty_wire_value,
      field   TYPE string,
      message TYPE string,
    END OF ty_error.
  TYPES tt_error TYPE STANDARD TABLE OF ty_error WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_parsed,
      members TYPE tt_member,
      errors  TYPE tt_error,
    END OF ty_parsed.

  "! Result of mapping a parsed body to a row
  TYPES:
    BEGIN OF ty_mapped,
      row    TYPE ty_row,
      errors TYPE tt_error,
    END OF ty_mapped.

  "! What the mapping needs besides the body (no clock or user inside the mapper)
  TYPES:
    BEGIN OF ty_map_context,
      now       TYPE timestampl,
      user      TYPE syuname,
      time_zone TYPE zif_cd_fmon_types=>ty_time_zone,
    END OF ty_map_context.

  " ---------------------------------------------------------------- HTTP boundary
  TYPES:
    BEGIN OF ty_request,
      method       TYPE string,
      content_type TYPE string,
      body         TYPE xstring,
    END OF ty_request.

  TYPES:
    BEGIN OF ty_response,
      status_code TYPE i,
      status      TYPE ty_wire_value,
      event_id    TYPE ty_event_id,
      errors      TYPE tt_error,
      "! JSON body: {"eventId":...,"status":...,"errors":[...]}
      body        TYPE string,
    END OF ty_response.

ENDINTERFACE.
