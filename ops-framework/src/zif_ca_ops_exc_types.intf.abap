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
*& 2026-11-10 | Moved from ZIF_CD_OPS_EXC_TYPES to the reusable framework ZCA_OPS.
*& 2026-11-10 | Classification of an open exception: action CLASSIFY, reason codes (parameter
*&            | EXC_REASON_CODES, delivered TIMING and INVESTIGATING), message 068.
*& 2026-11-11 | Reason code NOT_AN_ISSUE (false positive; pilot pack metric), delivered in EXC_REASON_CODES.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - exception lifecycle types</p>
INTERFACE zif_ca_ops_exc_types
  PUBLIC.

  TYPES ty_action TYPE c LENGTH 10.
  TYPES ty_reason TYPE c LENGTH 255.
  TYPES ty_reference TYPE c LENGTH 70.
  "! Classification of an open exception (ZCA_OPS_FINDING-REASON_CODE)
  TYPES ty_reason_code TYPE c LENGTH 12.

  "! ZCA_OPS_EXC_HIST-ACTION
  CONSTANTS:
    BEGIN OF gc_action,
      assign      TYPE ty_action VALUE 'ASSIGN',
      resolve     TYPE ty_action VALUE 'RESOLVE',
      waive_req   TYPE ty_action VALUE 'WAIVE_REQ',
      waive_ok    TYPE ty_action VALUE 'WAIVE_OK',
      "! Handled manually outside SAP (a manual status or request of a consumer)
      manual      TYPE ty_action VALUE 'MANUAL',
      "! Reason code given to an open exception (it stays open)
      classify    TYPE ty_action VALUE 'CLASSIFY',
    END OF gc_action.

  "! Delivered reason codes (values of parameter EXC_REASON_CODES; a landscape may add more)
  CONSTANTS:
    BEGIN OF gc_reason_code,
      "! A difference that a later day's posting or statement clears (e.g. a reconciliation variance)
      timing        TYPE ty_reason_code VALUE 'TIMING',
      "! Operations are investigating the exception
      investigating TYPE ty_reason_code VALUE 'INVESTIGATING',
      "! Not an issue: the exception was a false positive (pilot metric false-positive rate, docs/PILOT_PACK.md;
      "! 2026-11-11) - classify, then resolve
      not_an_issue  TYPE ty_reason_code VALUE 'NOT_AN_ISSUE',
    END OF gc_reason_code.

  "! Parameters of the exception lifecycle (area CA_OPS)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Reason codes an open exception may be classified with (comma list) [TIMING,INVESTIGATING,NOT_AN_ISSUE]
      reason_codes TYPE zif_ca_ops_types=>ty_param_name VALUE 'EXC_REASON_CODES',
    END OF gc_param.

  CONSTANTS:
    BEGIN OF gc_param_default,
      reason_codes TYPE zif_ca_ops_types=>ty_param_value VALUE 'TIMING,INVESTIGATING,NOT_AN_ISSUE',
    END OF gc_param_default.

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

  "! Policy decision: allowed, or the ZCA_OPS message number that explains why not
  TYPES:
    BEGIN OF ty_decision,
      allowed TYPE abap_bool,
      msgno   TYPE symsgno,
      v1      TYPE symsgv,
    END OF ty_decision.

  "! ZCA_OPS messages of the exception lifecycle
  CONSTANTS:
    BEGIN OF gc_msg,
      not_open        TYPE symsgno VALUE '061',
      reason_missing  TYPE symsgno VALUE '062',
      same_user       TYPE symsgno VALUE '063',
      no_request      TYPE symsgno VALUE '064',
      date_in_past    TYPE symsgno VALUE '065',
      owner_missing   TYPE symsgno VALUE '066',
      request_pending TYPE symsgno VALUE '067',
      "! The reason code is not one of the values of parameter EXC_REASON_CODES
      reason_code_invalid TYPE symsgno VALUE '068',
      "! Exception &1 (&2) changed by a user during the run - left for next run
      changed_deferred TYPE symsgno VALUE '786',
      "! Exception &1 / &2 changed meanwhile - not resolved, nothing saved
      changed_meanwhile TYPE symsgno VALUE '787',
    END OF gc_msg.

ENDINTERFACE.
