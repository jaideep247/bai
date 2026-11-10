*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_exc_types.intf.abap
*& Purpose:
*& Types and constants of the exception lifecycle (exceptions app, design
*& 6.1): actions, history rows, decisions of ZCL_CA_OPS_EXC_POLICY.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-07 | History action RELEASE removed with the blocked-line release (read-only scope).
*& 2026-11-10 | Concurrency review: TY_EXC_OPEN (key with the disposition and change stamp read - the
*&            | guard of a resolve; replaces TY_EXC_KEY), code EXC_CHANGED_DEFERRED, messages 786-788.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - exception lifecycle types</p>
INTERFACE zif_ca_ops_exc_types
  PUBLIC.

  TYPES ty_action TYPE c LENGTH 10.
  TYPES ty_reason TYPE c LENGTH 255.
  TYPES ty_reference TYPE c LENGTH 70.

  "! ZCA_OPS_EXC_HIST-ACTION
  CONSTANTS:
    BEGIN OF gc_action,
      assign      TYPE ty_action VALUE 'ASSIGN',
      resolve     TYPE ty_action VALUE 'RESOLVE',
      waive_req   TYPE ty_action VALUE 'WAIVE_REQ',
      waive_ok    TYPE ty_action VALUE 'WAIVE_OK',
      "! Handled manually outside SAP (FMON manual status, PRISM request, design 6.4/6.5)
      manual      TYPE ty_action VALUE 'MANUAL',
    END OF gc_action.

  "! An open exception as read: key, disposition, owner and change stamp (ZCA_OPS_FINDING-LAST_CHANGED_AT).
  "! A resolve writes the row only while disposition and stamp are still the ones read (2026-11-10)
  TYPES:
    BEGIN OF ty_exc_open,
      run_id          TYPE zif_ca_ops_types=>ty_run_id,
      finding_no      TYPE i,
      disposition     TYPE zif_ca_ops_types=>ty_disposition,
      owner           TYPE syuname,
      last_changed_at TYPE timestampl,
    END OF ty_exc_open.
  TYPES tt_exc_open TYPE STANDARD TABLE OF ty_exc_open WITH EMPTY KEY.

  "! Information finding of a store run: an exception a user changed while the run superseded or resolved
  "! it, twice in a row - the user's change is kept and the run's change is left for the next run
  CONSTANTS gc_code_deferred TYPE zif_ca_ops_types=>ty_check_code VALUE 'EXC_CHANGED_DEFERRED'.

  "! The lifecycle state the policy decides on
  TYPES:
    BEGIN OF ty_state,
      disposition   TYPE zif_ca_ops_types=>ty_disposition,
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
      "! Exception &1 (&2) changed by a user during the run - left for next run
      changed_deferred TYPE symsgno VALUE '786',
      "! Exception &1 / &2 changed meanwhile - not resolved, nothing saved
      changed_meanwhile TYPE symsgno VALUE '787',
      "! Open exceptions of request &1 could not be read - record not saved
      open_read_failed TYPE symsgno VALUE '788',
    END OF gc_msg.

ENDINTERFACE.
