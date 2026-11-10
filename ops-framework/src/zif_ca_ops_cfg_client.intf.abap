*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_cfg_client.intf.abap
*& Purpose:
*& System reads the configuration apps depend on: client settings (T000)
*& and the state of a transport request (E070). Injectable so the gate is
*& testable without a system.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*& 2026-11-10 | Moved from ZIF_CD_OPS_CFG_CLIENT to the reusable framework ZCA_OPS.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops framework - config apps: client and request reads</p>
INTERFACE zif_ca_ops_cfg_client
  PUBLIC.

  "! Change option (SCC4) and role of the logon client
  METHODS read_client
    RETURNING
      VALUE(rs_client) TYPE zif_ca_ops_cfg_types=>ty_client.

  "! Existence, status and function of a transport request or task
  METHODS read_request
    IMPORTING
      iv_request     TYPE zif_ca_ops_cfg_types=>ty_request
    RETURNING
      VALUE(rs_info) TYPE zif_ca_ops_cfg_types=>ty_request_info.

ENDINTERFACE.
