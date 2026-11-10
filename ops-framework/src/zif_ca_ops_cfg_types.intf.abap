*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_cfg_types.intf.abap
*& Purpose:
*& Named types and constants of the RAP configuration apps (the framework's
*& own app and every consumer app generated the same way): client
*& settings, change decision, transport request state, field check
*& results, authorisation activities, messages of class ZCA_OPS. No logic.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*& 2026-11-06 | Message 418: a pattern field is not valid PCRE.
*& 2026-11-07 | GC_PROD_MAINTAINABLE withdrawn: new rows only by transport from DV1 (user decision, D-3).
*& 2026-11-10 | Moved from ZIF_CD_OPS_CFG_TYPES to the reusable framework ZCA_OPS: types, client and request
*&            | constants, activities and the messages of the gate and of the framework app (class
*&            | ZCA_OPS; 434 parameter, 435 area); the area is ZIF_CA_OPS_TYPES=>TY_AREA (was TY_PE_AREA
*&            | CHAR 4); a consumer's field check messages stay in its own types interface.
*& 2026-11-10 | Message 436: e-mail template ID of an alert rule / channel not valid (alert e-mail templates).
*& 2026-11-10 | Messages 437-439: control register (owner / backup user, team, runbook link).
*& 2026-11-10 | TABLE_INVALID / FIELD_INVALID (082 / 083): table and field checks of the aggregate rows
*&            | and approved tables of the check registry (process onboarding).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - configuration apps: types</p>
INTERFACE zif_ca_ops_cfg_types
  PUBLIC.

  TYPES ty_actvt         TYPE c LENGTH 2.
  TYPES ty_request       TYPE c LENGTH 20.
  TYPES ty_change_option TYPE c LENGTH 1.
  TYPES ty_client_role   TYPE c LENGTH 1.
  TYPES ty_req_status    TYPE c LENGTH 1.
  TYPES ty_req_function  TYPE c LENGTH 1.
  TYPES ty_name          TYPE c LENGTH 30.
  TYPES ty_value         TYPE c LENGTH 255.
  TYPES ty_value_list    TYPE string.
  TYPES ty_msg_number    TYPE n LENGTH 3.
  TYPES ty_msg_var       TYPE c LENGTH 50.
  TYPES ty_names         TYPE STANDARD TABLE OF ty_name WITH EMPTY KEY.

  "! Client settings (T000 / SCC4) that decide what may be changed
  TYPES:
    BEGIN OF ty_client,
      change_option TYPE ty_change_option,
      role          TYPE ty_client_role,
    END OF ty_client.

  "! What the configuration apps allow in this client
  TYPES:
    BEGIN OF ty_decision,
      create_allowed     TYPE abap_bool,
      update_allowed     TYPE abap_bool,
      delete_allowed     TYPE abap_bool,
      transport_required TYPE abap_bool,
    END OF ty_decision.

  "! State of a transport request (E070)
  TYPES:
    BEGIN OF ty_request_info,
      exists   TYPE abap_bool,
      status   TYPE ty_req_status,
      function TYPE ty_req_function,
    END OF ty_request_info.

  "! Message of class ZCA_OPS for a RAP %msg (number initial = no message)
  TYPES:
    BEGIN OF ty_message,
      number TYPE ty_msg_number,
      v1     TYPE ty_msg_var,
      v2     TYPE ty_msg_var,
      v3     TYPE ty_msg_var,
    END OF ty_message.

  "! Field check result of a behaviour pool: message (class of the app) + element to highlight
  TYPES:
    BEGIN OF ty_field_message,
      number  TYPE ty_msg_number,
      v1      TYPE ty_msg_var,
      v2      TYPE ty_msg_var,
      v3      TYPE ty_msg_var,
      element TYPE ty_name,
    END OF ty_field_message.
  TYPES tt_field_message TYPE STANDARD TABLE OF ty_field_message WITH EMPTY KEY.

  "! RAP entity (alias) <-> customizing table, for transport recording
  TYPES:
    BEGIN OF ty_relation,
      entity TYPE ty_name,
      table  TYPE ty_name,
    END OF ty_relation.
  TYPES tt_relation TYPE STANDARD TABLE OF ty_relation WITH EMPTY KEY.

  "! T000-CCCORACTIV. VERIFY-SE11: confirm the fixed values of domain
  "! CCCORACTIV in DV1 (SCC4 wording in brackets) before activation.
  CONSTANTS:
    BEGIN OF gc_change_option,
      "! Changes without automatic recording
      no_recording  TYPE ty_change_option VALUE ' ',
      "! Automatic recording of changes (customizing client, DV1)
      auto_record   TYPE ty_change_option VALUE '1',
      "! No changes allowed
      no_changes    TYPE ty_change_option VALUE '2',
      "! Changes without automatic recording, no transports allowed
      no_transports TYPE ty_change_option VALUE '3',
    END OF gc_change_option.

  "! T000-CCCATEGORY
  CONSTANTS gc_role_production TYPE ty_client_role VALUE 'P'.

  "! Authorisation object ZCA_OPS, field ACTVT
  CONSTANTS:
    BEGIN OF gc_actvt,
      create  TYPE ty_actvt VALUE '01',
      change  TYPE ty_actvt VALUE '02',
      display TYPE ty_actvt VALUE '03',
      delete  TYPE ty_actvt VALUE '06',
    END OF gc_actvt.

  "! E070: TRSTATUS modifiable (D) / modifiable, protected (L);
  "! TRFUNCTION customizing request (W) / customizing task (Q)
  CONSTANTS:
    BEGIN OF gc_request,
      modifiable           TYPE ty_req_status VALUE 'D',
      modifiable_protected TYPE ty_req_status VALUE 'L',
      customizing_request  TYPE ty_req_function VALUE 'W',
      customizing_task     TYPE ty_req_function VALUE 'Q',
    END OF gc_request.

  "! Message class ZCA_OPS, range 400-449 (configuration apps): the gate's request messages and the
  "! field checks of the framework's own app
  CONSTANTS:
    BEGIN OF gc_msg,
      request_missing   TYPE ty_msg_number VALUE '402',
      request_unknown   TYPE ty_msg_number VALUE '403',
      request_not_cust  TYPE ty_msg_number VALUE '404',
      request_released  TYPE ty_msg_number VALUE '405',
      class_invalid     TYPE ty_msg_number VALUE '410',
      value_invalid     TYPE ty_msg_number VALUE '413',
      window_incomplete TYPE ty_msg_number VALUE '414',
      pattern_invalid   TYPE ty_msg_number VALUE '418',
      dest_invalid      TYPE ty_msg_number VALUE '419',
      "! Purge registry: the retention parameter is not defined in its area
      param_invalid     TYPE ty_msg_number VALUE '434',
      "! Alert rule: the area is neither * nor a parameter area of ZCA_PARAM_AREA
      area_invalid      TYPE ty_msg_number VALUE '435',
      "! Alert rule / channel: the e-mail template ID is not valid or the template does not exist
      template_invalid  TYPE ty_msg_number VALUE '436',
      "! Control: owner or backup is not a user of this client
      user_invalid      TYPE ty_msg_number VALUE '437',
      "! Control: the team is not a value of parameter CONTROL_TEAMS
      team_invalid      TYPE ty_msg_number VALUE '438',
      "! Control: the runbook link is not an http / https link
      url_invalid       TYPE ty_msg_number VALUE '439',
      "! Aggregate check / approved table: the table is not a DDIC table (process onboarding, 2026-11-10)
      table_invalid     TYPE ty_msg_number VALUE '082',
      "! Aggregate check: the field is not a field of the row's table
      field_invalid     TYPE ty_msg_number VALUE '083',
    END OF gc_msg.

ENDINTERFACE.
