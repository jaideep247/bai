*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_maint_policy.clas.abap
*& Purpose:
*& Change policy of the maintenance app, pure (no SQL, no system read):
*&  - mode: TRANSPORT where the client is not a production client, records
*&    customizing changes automatically and the business configuration
*&    API reports customizing as editable; LOCAL everywhere else (QA,
*&    production, clients without recording);
*&  - areas, definitions, new values and deletions: TRANSPORT only;
*&  - existing values: TRANSPORT, or LOCAL when the area is PROD_EDITABLE
*&    and the definition is not DEVELOPER_OWNED;
*&  - customizing request: required in TRANSPORT (exists, customizing
*&    request or task, modifiable); not used in LOCAL.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - maintenance change policy</p>
CLASS zcl_ca_param_maint_policy DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! TRANSPORT or LOCAL for these client settings
    CLASS-METHODS mode
      IMPORTING
        is_client      TYPE zif_ca_param_types=>ty_client
      RETURNING
        VALUE(rv_mode) TYPE zif_ca_param_types=>ty_mode.

    "! Areas, definitions, new values and deletions may be maintained
    CLASS-METHODS can_maintain_config
      IMPORTING
        iv_mode           TYPE zif_ca_param_types=>ty_mode
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    "! An existing value row may be changed
    CLASS-METHODS can_change_value
      IMPORTING
        iv_mode            TYPE zif_ca_param_types=>ty_mode
        iv_prod_editable   TYPE abap_bool
        iv_developer_owned TYPE abap_bool
      RETURNING
        VALUE(rv_allowed)  TYPE abap_bool.

    "! The area may be opened for editing (draft): to maintain anything or to change values
    CLASS-METHODS can_edit_area
      IMPORTING
        iv_mode           TYPE zif_ca_param_types=>ty_mode
        iv_prod_editable  TYPE abap_bool
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    "! Message 040-043 when the request cannot take the changes; initial when it can or in LOCAL
    CLASS-METHODS request_message
      IMPORTING
        iv_mode           TYPE zif_ca_param_types=>ty_mode
        iv_area           TYPE zif_ca_param_types=>ty_area
        iv_request        TYPE zif_ca_param_types=>ty_request
        is_info           TYPE zif_ca_param_types=>ty_request_info
      RETURNING
        VALUE(rs_message) TYPE zif_ca_param_types=>ty_message.

ENDCLASS.



CLASS zcl_ca_param_maint_policy IMPLEMENTATION.

  METHOD mode.
    rv_mode = COND #( WHEN is_client-role <> zif_ca_param_types=>gc_role_production
                       AND is_client-change_option = zif_ca_param_types=>gc_change_option-auto_record
                       AND is_client-cust_editable = abap_true
                      THEN zif_ca_param_types=>gc_mode-transport
                      ELSE zif_ca_param_types=>gc_mode-local ).
  ENDMETHOD.


  METHOD can_maintain_config.
    rv_allowed = xsdbool( iv_mode = zif_ca_param_types=>gc_mode-transport ).
  ENDMETHOD.


  METHOD can_change_value.
    rv_allowed = xsdbool( iv_mode = zif_ca_param_types=>gc_mode-transport
                          OR ( iv_prod_editable = abap_true AND iv_developer_owned = abap_false ) ).
  ENDMETHOD.


  METHOD can_edit_area.
    rv_allowed = xsdbool( iv_mode = zif_ca_param_types=>gc_mode-transport OR iv_prod_editable = abap_true ).
  ENDMETHOD.


  METHOD request_message.
    IF iv_mode <> zif_ca_param_types=>gc_mode-transport.
      RETURN.
    ENDIF.
    rs_message-msgid = zif_ca_param_types=>gc_msgid.
    IF iv_request IS INITIAL.
      rs_message-msgno = zif_ca_param_types=>gc_msg-request_missing.
      rs_message-v1    = iv_area.
    ELSEIF is_info-exists = abap_false.
      rs_message-msgno = zif_ca_param_types=>gc_msg-request_unknown.
      rs_message-v1    = iv_request.
    ELSEIF is_info-function <> zif_ca_param_types=>gc_request-customizing_request
       AND is_info-function <> zif_ca_param_types=>gc_request-customizing_task.
      rs_message-msgno = zif_ca_param_types=>gc_msg-request_not_cust.
      rs_message-v1    = iv_request.
    ELSEIF is_info-status <> zif_ca_param_types=>gc_request-modifiable
       AND is_info-status <> zif_ca_param_types=>gc_request-protected.
      rs_message-msgno = zif_ca_param_types=>gc_msg-request_released.
      rs_message-v1    = iv_request.
    ELSE.
      CLEAR rs_message.
    ENDIF.
    IF rs_message IS NOT INITIAL.
      rs_message-field = zif_ca_param_types=>gc_field-request.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
