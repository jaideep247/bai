*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cfg_policy.clas.abap
*& Purpose:
*& Change policy of the configuration apps (design D-3): new entries only
*& where the client records changes (DV1, on a customizing request);
*& existing entries editable in every client (production: direct,
*& change-logged); delete only where new entries are allowed. Also decides
*& whether a transport request is acceptable. Pure: no SQL, no system read.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*& 2026-11-07 | Per-table create withdrawn: new rows only by transport from DV1 (user decision, D-3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - config apps: change policy</p>
CLASS zcl_ca_ops_cfg_policy DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! What may be changed in a client with these settings
    CLASS-METHODS decide
      IMPORTING
        is_client          TYPE zif_ca_ops_cfg_types=>ty_client
      RETURNING
        VALUE(rs_decision) TYPE zif_ca_ops_cfg_types=>ty_decision.

    "! Message when the request cannot take the changes; initial when it can
    "! or when this client does not record changes
    CLASS-METHODS request_error
      IMPORTING
        is_decision       TYPE zif_ca_ops_cfg_types=>ty_decision
        iv_request        TYPE zif_ca_ops_cfg_types=>ty_request
        is_info           TYPE zif_ca_ops_cfg_types=>ty_request_info
      RETURNING
        VALUE(rs_message) TYPE zif_ca_ops_cfg_types=>ty_message.

ENDCLASS.



CLASS zcl_ca_ops_cfg_policy IMPLEMENTATION.

  METHOD decide.
    " Existing entries can always be corrected (production: direct, change-logged)
    rs_decision-update_allowed = abap_true.

    IF is_client-role = zif_ca_ops_cfg_types=>gc_role_production
       OR is_client-change_option = zif_ca_ops_cfg_types=>gc_change_option-no_changes
       OR is_client-change_option = zif_ca_ops_cfg_types=>gc_change_option-no_transports.
      RETURN.
    ENDIF.

    rs_decision-create_allowed     = abap_true.
    rs_decision-delete_allowed     = abap_true.
    rs_decision-transport_required = xsdbool( is_client-change_option =
                                              zif_ca_ops_cfg_types=>gc_change_option-auto_record ).
  ENDMETHOD.


  METHOD request_error.
    IF is_decision-transport_required = abap_false.
      RETURN.
    ENDIF.

    rs_message-v1 = iv_request.
    IF iv_request IS INITIAL.
      rs_message-number = zif_ca_ops_cfg_types=>gc_msg-request_missing.
    ELSEIF is_info-exists = abap_false.
      rs_message-number = zif_ca_ops_cfg_types=>gc_msg-request_unknown.
    ELSEIF is_info-function <> zif_ca_ops_cfg_types=>gc_request-customizing_request
       AND is_info-function <> zif_ca_ops_cfg_types=>gc_request-customizing_task.
      rs_message-number = zif_ca_ops_cfg_types=>gc_msg-request_not_cust.
    ELSEIF is_info-status <> zif_ca_ops_cfg_types=>gc_request-modifiable
       AND is_info-status <> zif_ca_ops_cfg_types=>gc_request-modifiable_protected.
      rs_message-number = zif_ca_ops_cfg_types=>gc_msg-request_released.
    ELSE.
      CLEAR rs_message.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
