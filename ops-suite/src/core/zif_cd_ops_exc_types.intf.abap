*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_exc_types.intf.abap
*& Purpose:
*& Types and constants of the exception lifecycle (exceptions app, design
*& 6.1): actions, history rows, decisions of ZCL_CD_OPS_EXC_POLICY.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - exception lifecycle types</p>
INTERFACE zif_cd_ops_exc_types
  PUBLIC.

  TYPES ty_action TYPE c LENGTH 10.
  TYPES ty_reason TYPE c LENGTH 255.
  TYPES ty_reference TYPE c LENGTH 70.

  "! ZCD_OPS_EXC_HIST-ACTION
  CONSTANTS:
    BEGIN OF gc_action,
      assign      TYPE ty_action VALUE 'ASSIGN',
      resolve     TYPE ty_action VALUE 'RESOLVE',
      waive_req   TYPE ty_action VALUE 'WAIVE_REQ',
      waive_ok    TYPE ty_action VALUE 'WAIVE_OK',
      "! EBS blocked-line release approved (design 6.2)
      release     TYPE ty_action VALUE 'RELEASE',
      "! Handled manually outside SAP (FMON manual status, PRISM request, design 6.4/6.5)
      manual      TYPE ty_action VALUE 'MANUAL',
    END OF gc_action.

  "! Key of an exception (ZCD_OPS_FINDING)
  TYPES:
    BEGIN OF ty_exc_key,
      run_id     TYPE zif_cd_ops_types=>ty_run_id,
      finding_no TYPE i,
    END OF ty_exc_key.
  TYPES tt_exc_key TYPE STANDARD TABLE OF ty_exc_key WITH EMPTY KEY.

  "! The lifecycle state the policy decides on
  TYPES:
    BEGIN OF ty_state,
      disposition   TYPE zif_cd_ops_types=>ty_disposition,
      waiver_req_by TYPE syuname,
    END OF ty_state.

  "! Policy decision: allowed, or the ZCD_OPS message number that explains why not
  TYPES:
    BEGIN OF ty_decision,
      allowed TYPE abap_bool,
      msgno   TYPE symsgno,
      v1      TYPE symsgv,
    END OF ty_decision.

  "! ZCD_OPS messages of the exception lifecycle
  CONSTANTS:
    BEGIN OF gc_msg,
      not_open        TYPE symsgno VALUE '061',
      reason_missing  TYPE symsgno VALUE '062',
      same_user       TYPE symsgno VALUE '063',
      no_request      TYPE symsgno VALUE '064',
      date_in_past    TYPE symsgno VALUE '065',
      owner_missing   TYPE symsgno VALUE '066',
      request_pending TYPE symsgno VALUE '067',
    END OF gc_msg.

ENDINTERFACE.
