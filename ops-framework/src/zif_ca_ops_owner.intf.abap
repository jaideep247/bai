*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_owner.intf.abap
*& Purpose:
*& Responsible user and team of a finding from the existing configuration
*& (exception contract, docs/EXCEPTION_CONTRACT.md section 4): the
*& active control that covers the finding's check code, check ID or rule
*& (ZCA_OPS_CTLCHK -> ZCA_OPS_CONTROL owner and team; the precedence of
*& the runbook link), else the owner of the check's business process
*& (ZCA_OPS_PROC), else none - said so on the finding (source N), never
*& guessed. Read only.
*& Modification log:
*& 2026-11-15 | Initial version (build K: exception contract).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - responsible owner of a finding</p>
INTERFACE zif_ca_ops_owner
  PUBLIC.

  TYPES:
    BEGIN OF ty_owner,
      user   TYPE syuname,
      team   TYPE zif_ca_ops_exc_contract=>ty_team,
      source TYPE zif_ca_ops_exc_contract=>ty_resp_source,
      "! The control or business process that named them
      ref    TYPE zif_ca_ops_chk_types=>ty_process_id,
    END OF ty_owner.

  "! Responsible owner of a finding of a check
  "! @parameter iv_area       | Area of the findings
  "! @parameter iv_check_id   | Check ID (finding GROUP2)
  "! @parameter iv_check_code | Check code of the finding
  "! @parameter iv_rule_id    | Rule of the finding
  "! @parameter iv_process_id | Business process of the check (ZCA_OPS_PROC; blank = none)
  METHODS resolve
    IMPORTING
      iv_area         TYPE zif_ca_ops_types=>ty_area
      iv_check_id     TYPE zif_ca_ops_chk_types=>ty_check_id
      iv_check_code   TYPE zif_ca_ops_types=>ty_check_code
      iv_rule_id      TYPE zif_ca_ops_types=>ty_rule_id OPTIONAL
      iv_process_id   TYPE zif_ca_ops_chk_types=>ty_process_id OPTIONAL
    RETURNING
      VALUE(rs_owner) TYPE ty_owner.

ENDINTERFACE.
