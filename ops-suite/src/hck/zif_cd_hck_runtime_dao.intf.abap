*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_runtime_dao.intf.abap
*& Purpose:
*& Reads of the runtime checks of the morning report: number range
*& intervals (NRIV), queue entries grouped per queue / destination / state
*& / day (qRFC tables, configured bgRFC table), payments of payment runs in
*& a window with their flow (DPAYH, TFK042Z) and cleared clearing-account
*& lines by assignment (collections). Keyed or window-bounded, capped.
*& Read-only: the interface has no write method.
*& Modification log:
*& 2026-11-07 | Initial version (checks E_NUMRANGE, E_QUEUES, A_INFLIGHT).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - runtime reads (NRIV, queues, payments)</p>
"! Implementation ZCL_CD_HCK_RUNTIME_DAO, factory ZCL_CD_HCK_FACTORY=>GET_RUNTIME_DAO.
"! Bank lines, cheques, document headers and returns are read through the payment trace
"! repository ZIF_CD_OPS_TRACE_DAO (core factory), never copied here.
INTERFACE zif_cd_hck_runtime_dao
  PUBLIC.

  "! Internal intervals (EXTERNIND blank) of the objects that are not year-dependent or
  "! valid in iv_year_from .. iv_year_to, ordered by object / subobject / interval / year;
  "! at most iv_max_rows (empty object list = nothing read)
  METHODS get_number_ranges
    IMPORTING
      it_objects          TYPE zif_cd_hck_runtime_types=>tt_nr_object
      iv_year_from        TYPE zif_cd_hck_runtime_types=>ty_year
      iv_year_to          TYPE zif_cd_hck_runtime_types=>ty_year
      iv_max_rows         TYPE i
    RETURNING
      VALUE(rt_intervals) TYPE zif_cd_hck_runtime_types=>tt_nr_interval.

  "! Entries of a queue source grouped per queue, destination, state and day, with the
  "! oldest time of the day; at most iv_max_rows groups. Names are validated against the
  "! DDIC (and ZCD_HCK_TABWL for a configured table) before the read.
  "! @raising zcx_cd_ops_error | unknown table / field, wrong field type, not whitelisted
  METHODS get_queue_groups
    IMPORTING
      is_source       TYPE zif_cd_hck_runtime_types=>ty_queue_source
      iv_max_rows     TYPE i
    RETURNING
      VALUE(rt_groups) TYPE zif_cd_hck_runtime_types=>tt_queue_group
    RAISING
      zcx_cd_ops_error.

  "! Payments of payment runs (DPAYH: DOC1R filled, proposal runs excluded) with run date
  "! in iv_from .. iv_to and one of the payment methods, with the collection indicator of
  "! the method (TFK042Z-XEINZ, country of the company code); at most iv_max_rows, oldest
  "! run first (empty method list = nothing read)
  METHODS get_issued_payments
    IMPORTING
      it_methods         TYPE zif_cd_hck_runtime_types=>tt_pymet
      iv_from            TYPE d
      iv_to              TYPE d
      iv_max_rows        TYPE i
    RETURNING
      VALUE(rt_payments) TYPE zif_cd_hck_runtime_types=>tt_issued_payment.

  "! The assignments (company code + ZUONR) that have a cleared G/L line (collections:
  "! clearing-account line with ZUONR = AUGBL cleared by the bank statement posting)
  METHODS get_cleared_assignments
    IMPORTING
      it_keys           TYPE zif_cd_hck_runtime_types=>tt_assignment
    RETURNING
      VALUE(rt_cleared) TYPE zif_cd_hck_runtime_types=>tt_assignment.

ENDINTERFACE.
