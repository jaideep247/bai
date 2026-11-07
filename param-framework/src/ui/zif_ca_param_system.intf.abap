*&---------------------------------------------------------------------*
*& Artifact: zif_ca_param_system.intf.abap
*& Purpose:
*& System boundary of the maintenance app: client settings and customizing
*& changeability, transport request state, authorization check and
*& transport recording. Implemented by ZCL_CA_PARAM_SYSTEM (SAP APIs);
*& unit tests of ZCL_CA_PARAM_MAINT use a local double. No decisions here.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - system boundary (app)</p>
INTERFACE zif_ca_param_system
  PUBLIC.

  "! Role and change option of the logon client; customizing changeable with recording
  METHODS read_client
    RETURNING
      VALUE(rs_client) TYPE zif_ca_param_types=>ty_client.

  "! Existence, status and type of a transport request or task
  METHODS read_request
    IMPORTING
      iv_request     TYPE zif_ca_param_types=>ty_request
    RETURNING
      VALUE(rs_info) TYPE zif_ca_param_types=>ty_request_info.

  "! Authorization object ZCA_PARAM for an area (blank area = any area) and activity
  METHODS is_authorized
    IMPORTING
      iv_area           TYPE zif_ca_param_types=>ty_area
      iv_actvt          TYPE zif_ca_param_types=>ty_actvt
    RETURNING
      VALUE(rv_allowed) TYPE abap_bool.

  "! Record the rows of one RAP save on a customizing request
  METHODS record_changes
    IMPORTING
      iv_request   TYPE zif_ca_param_types=>ty_request
      it_relations TYPE zif_ca_param_types=>tt_relation
      ir_create    TYPE REF TO data
      ir_update    TYPE REF TO data
      ir_delete    TYPE REF TO data
    RAISING
      zcx_ca_param.

ENDINTERFACE.
