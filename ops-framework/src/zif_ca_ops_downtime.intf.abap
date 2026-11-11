*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_downtime.intf.abap
*& Purpose:
*& Planned downtime API of the framework (2026-11-11): the windows of an
*& area (ZCA_OPS_DTWIN) and the question "is this planned?" - asked by the
*& store when it records a finding (planned downtime mark), by the alert
*& router (run-level alerts, escalations) and by a consumer's missing-volume
*& or SLA-style check before it raises a finding for a period. Only approved
*& windows take effect. Obtained from ZCL_CA_OPS_FACTORY=>GET_DOWNTIME.
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: planned downtime).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - planned downtime API</p>
INTERFACE zif_ca_ops_downtime
  PUBLIC.

  "! Windows of an area (blank = every area) whose time overlaps [iv_from, iv_to] (UTC), by start
  "! @parameter iv_approved_only | X = approved windows only (the ones that take effect); blank = also the
  "!                              windows awaiting approval (overlap check of the downtime app)
  METHODS windows
    IMPORTING
      iv_area            TYPE zif_ca_ops_types=>ty_area
      iv_from            TYPE timestampl
      iv_to              TYPE timestampl
      iv_approved_only   TYPE abap_bool DEFAULT abap_true
    RETURNING
      VALUE(rt_windows)  TYPE zif_ca_ops_resp_types=>tt_window.

  "! Is this planned? The approved window of the area in effect at some time of [iv_from, iv_to] (UTC; blank
  "! iv_to = the point iv_from) that covers a finding with this check code, object key and interface / bank
  "! (GROUP1 / GROUP2 of is_finding; blank fields match only a window without that pattern). Blank = not
  "! planned - e.g. a missing-volume check raises its finding, else it records it as information
  METHODS planned
    IMPORTING
      iv_area             TYPE zif_ca_ops_types=>ty_area
      is_finding          TYPE zif_ca_ops_types=>ty_finding
      iv_from             TYPE timestampl
      iv_to               TYPE timestampl OPTIONAL
    RETURNING
      VALUE(rv_window_id) TYPE zif_ca_ops_resp_types=>ty_uuid.

  "! The area-wide window (no scope pattern) of the area in effect at iv_at (blank = none)
  METHODS area_planned
    IMPORTING
      iv_area             TYPE zif_ca_ops_types=>ty_area
      iv_at               TYPE timestampl
    RETURNING
      VALUE(rv_window_id) TYPE zif_ca_ops_resp_types=>ty_uuid.

ENDINTERFACE.
