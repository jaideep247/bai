*&---------------------------------------------------------------------*
*& Artifact: zif_cd_coll_types.intf.abap
*& Purpose:
*& Types and constants of the collections request checks of process
*& CD_COLL / BASE_REQ_LIFE (control BASE_REJECTS, proposal P2, build R):
*& R2 SCHEDULED without an answer of the source (COLL_R2_SCHEDULED) and R3
*& source reject without a successful Stripe premium refund
*& (COLL_R3_REFUND). Parameters (area CD_OPS, prefix COLL_): the request
*& status source and the refund log as source specifications, the reject
*& value, the refund success / failure values, the limits in hours (D-PO3),
*& the currency, window and row cap. Messages 904, 905, 910-912. No logic.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Collections request checks - types</p>
INTERFACE zif_cd_coll_types
  PUBLIC.

  "! Latest status of one collections request (request status source COLL_SRC_REQUEST)
  TYPES:
    BEGIN OF ty_request,
      key        TYPE zif_cd_ops_trace_types=>ty_key_value,
      bukrs      TYPE bukrs,
      status     TYPE string,
      changed_on TYPE d,
      changed_at TYPE timestampl,
      amount     TYPE zif_ca_ops_types=>ty_amount,
      "! Hours since the status change (now of the run)
      hours      TYPE i,
    END OF ty_request.
  TYPES tt_request TYPE HASHED TABLE OF ty_request WITH UNIQUE KEY key.

  "! Limits of a check in hours (amber / red, D-PO3)
  TYPES:
    BEGIN OF ty_limits,
      amber TYPE i,
      red   TYPE i,
    END OF ty_limits.

  "! Parameters of ZCA_PARAM (area CD_OPS, delivered blank / 0 = not configured: the check raises)
  CONSTANTS:
    BEGIN OF gc_param,
      "! TABLE=..;KEY=<request key>;KEY2=<company code field>;STATUS=..;DATE=..;TIME=..;AMOUNT=..
      src_request   TYPE zif_ca_ops_types=>ty_param_name VALUE 'COLL_SRC_REQUEST',
      "! TABLE=..;KEY=<request key>;STATUS=..;DATE=..;TIME=.. of SAP's Stripe refund call log
      src_refund    TYPE zif_ca_ops_types=>ty_param_name VALUE 'COLL_SRC_REFUND',
      reject_value  TYPE zif_ca_ops_types=>ty_param_name VALUE 'COLL_REJECT_VALUE',
      refund_ok     TYPE zif_ca_ops_types=>ty_param_name VALUE 'COLL_REFUND_OK',
      refund_failed TYPE zif_ca_ops_types=>ty_param_name VALUE 'COLL_REFUND_FAILED',
      r2_amber      TYPE zif_ca_ops_types=>ty_param_name VALUE 'COLL_R2_AMBER_H',
      r2_red        TYPE zif_ca_ops_types=>ty_param_name VALUE 'COLL_R2_RED_H',
      r3_amber      TYPE zif_ca_ops_types=>ty_param_name VALUE 'COLL_R3_AMBER_H',
      r3_red        TYPE zif_ca_ops_types=>ty_param_name VALUE 'COLL_R3_RED_H',
      currency      TYPE zif_ca_ops_types=>ty_param_name VALUE 'COLL_CURRENCY',
      lookback      TYPE zif_ca_ops_types=>ty_param_name VALUE 'COLL_LOOKBACK_DAYS',
      max_rows      TYPE zif_ca_ops_types=>ty_param_name VALUE 'COLL_MAX_ROWS',
    END OF gc_param.
  CONSTANTS:
    BEGIN OF gc_default,
      lookback TYPE i VALUE 7,
      max_rows TYPE i VALUE 50000,
      "! Item findings listed per check (the exposure findings count all)
      max_list TYPE i VALUE 200,
    END OF gc_default.

  "! Confirmed request status (user 2026-11-10): sent to the source (BASE) via PRISM
  CONSTANTS gc_status_scheduled TYPE string VALUE `SCHEDULED`.
  "! Control of the daily review that owns the findings
  CONSTANTS gc_control TYPE string VALUE `BASE_REJECTS`.
  CONSTANTS gc_seconds_per_hour TYPE i VALUE 3600.

  CONSTANTS:
    BEGIN OF gc_code,
      no_answer      TYPE zif_ca_ops_types=>ty_check_code VALUE 'REQ_NO_SOURCE_ANSWER',
      refund_missing TYPE zif_ca_ops_types=>ty_check_code VALUE 'PREMIUM_REFUND_MISSING',
      refund_failed  TYPE zif_ca_ops_types=>ty_check_code VALUE 'PREMIUM_REFUND_FAILED',
      read_capped    TYPE zif_ca_ops_types=>ty_check_code VALUE 'READ_CAPPED',
    END OF gc_code.

  CONSTANTS:
    BEGIN OF gc_msg,
      not_configured TYPE zif_ca_ops_types=>ty_msgno VALUE '904',
      read_capped    TYPE zif_ca_ops_types=>ty_msgno VALUE '905',
      no_answer      TYPE zif_ca_ops_types=>ty_msgno VALUE '910',
      refund_missing TYPE zif_ca_ops_types=>ty_msgno VALUE '911',
      refund_failed  TYPE zif_ca_ops_types=>ty_msgno VALUE '912',
    END OF gc_msg.

ENDINTERFACE.
