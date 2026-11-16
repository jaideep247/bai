*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_cash_dao.intf.abap
*& Purpose:
*& Data access of the FI-CA cash operations checks: set-based reads of SAP
*& standard tables (DPAYH, TBTCO, DFKKZK / DFKKZP, DFKKRK / DFKKRP, FEBKO /
*& FEBEP, DFKKRAPT, DFKKKO, DFKKSUMC / DFKKSUM), the G/L side through the
*& released view I_JournalEntry (ZI_CA_OpsCashJrnl), the owner of a check
*& from the framework configuration (ZCA_OPS_CTLCHK / _CONTROL / _PROC) and
*& the working days of the factory calendar. Every count and sum is
*& computed on the database, grouped by source object, company code and
*& currency, oldest first, at most iv_max rows. A failed read raises
*& ZCX_CA_OPS_ERROR (message 521 with the source): the caller reports the
*& rule "not evaluated", never green. Never writes a table.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash operations - data access</p>
"! Ranges of status values come from parameters (blank = the caller does not call: value pending).
INTERFACE zif_ca_ops_cash_dao
  PUBLIC.

  "! Payments of the runs of the window per run, proposal flag, paying company code, currency and payment method,
  "! with the payments without payment document (DPAYH: LAUFD, LAUFI, XVORL, BBUKR, WAERS, RZAWE, RWBTR, DOC1R)
  METHODS payment_runs
    IMPORTING
      iv_from        TYPE d
      iv_to          TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rt_runs) TYPE zif_ca_ops_cash_types=>tt_run_sum
    RAISING
      zcx_ca_ops_error.

  "! Jobs whose name matches the pattern (* = any characters) and that started or were planned in the window
  "! (TBTCO), any status
  METHODS jobs
    IMPORTING
      iv_pattern     TYPE csequence
      iv_from        TYPE d
      iv_to          TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rt_jobs) TYPE zif_ca_ops_job_types=>tt_job
    RAISING
      zcx_ca_ops_error.

  "! Payment lots created on or before the day whose status is none of the done values, per lot, company code
  "! and currency of the items (DFKKZK STAZS / ERDAT, DFKKZP BETRZ / WAERS / BUKRS)
  METHODS open_lots
    IMPORTING
      it_done        TYPE zif_ca_ops_types=>tt_param_range
      iv_created_to  TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_cash_types=>tt_sum
    RAISING
      zcx_ca_ops_error.

  "! Payment lot items in clarification (DFKKZP-XKLAE set) posted on or before the day, per lot, company code
  "! and currency
  METHODS lot_clarifications
    IMPORTING
      iv_posted_to   TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_cash_types=>tt_sum
    RAISING
      zcx_ca_ops_error.

  "! Returns lots created on or before the day whose status is none of the done values, per lot, company code
  "! and currency of the returns (DFKKRK STARS / ERDAT, DFKKRP BETRR / WAERS / BUKRS)
  METHODS open_returns_lots
    IMPORTING
      it_done        TYPE zif_ca_ops_types=>tt_param_range
      iv_created_to  TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_cash_types=>tt_sum
    RAISING
      zcx_ca_ops_error.

  "! Returns in clarification (DFKKRP-XKLAE set) posted on or before the day, per lot, company code, currency
  METHODS return_clarifications
    IMPORTING
      iv_posted_to   TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_cash_types=>tt_sum
    RAISING
      zcx_ca_ops_error.

  "! Returns without returns document (DFKKRP-RLBEL initial) posted on or before the day, per lot, company
  "! code and currency
  METHODS returns_without_document
    IMPORTING
      iv_posted_to   TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_cash_types=>tt_sum
    RAISING
      zcx_ca_ops_error.

  "! Bank statements per account and statement date in the window (FEBKO BUKRS, HBKID, HKTID, AZDAT)
  METHODS statement_days
    IMPORTING
      iv_from        TYPE d
      iv_to          TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rt_days) TYPE zif_ca_ops_cash_types=>tt_statement_day
    RAISING
      zcx_ca_ops_error.

  "! Statement lines not posted (FEBEP-VB1OK not set) of statements imported on or before the day, per
  "! statement, company code, account and currency (FEBEP KWBTR / KWAER)
  METHODS unposted_lines
    IMPORTING
      iv_imported_to TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_cash_types=>tt_sum
    RAISING
      zcx_ca_ops_error.

  "! Lines of statements of the house banks imported on or before the day for which no payment lot names the
  "! statement (no DFKKZK with the statement's KUKEY), per statement, company code, account and currency
  METHODS lines_not_in_fica
    IMPORTING
      it_banks       TYPE zif_ca_ops_types=>tt_param_range
      iv_imported_to TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_cash_types=>tt_sum
    RAISING
      zcx_ca_ops_error.

  "! Clearings reset on or after the day (DFKKRAPT STDAT) whose clearing document is the payment document of a
  "! payment run (DPAYH-DOC1R, not a proposal), clearing reason in the range (empty = any), per clearing
  "! document, company code and currency
  METHODS paid_clearing_resets
    IMPORTING
      iv_reset_from  TYPE d
      it_augrd       TYPE zif_ca_ops_types=>tt_param_range
      iv_max         TYPE i
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_cash_types=>tt_sum
    RAISING
      zcx_ca_ops_error.

  "! Payment documents of payment runs (DPAYH-DOC1R) that were reversed (DFKKKO-STORB of the original names the
  "! reversal) by a reversal entered on or after the day (CPUDT of the reversal document), per payment document,
  "! run, company code and currency
  METHODS reversed_payments
    IMPORTING
      iv_reversed_from TYPE d
      iv_max           TYPE i
    RETURNING
      VALUE(rt_sums)   TYPE zif_ca_ops_cash_types=>tt_sum
    RAISING
      zcx_ca_ops_error.

  "! Reconciliation keys not closed (DFKKSUMC-XCLOS not set) created on or before the day, per key, company
  "! code and currency of their totals (DFKKSUM, debit side)
  METHODS open_keys
    IMPORTING
      iv_created_to  TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_cash_types=>tt_sum
    RAISING
      zcx_ca_ops_error.

  "! Reconciliation keys with the error indicator set (DFKKSUMC-XERRO), per key, company code and currency
  METHODS error_keys
    IMPORTING
      iv_max         TYPE i
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_cash_types=>tt_sum
    RAISING
      zcx_ca_ops_error.

  "! Reconciliation keys closed on or before the day whose totals of a company code have no unreversed G/L
  "! document with the reference type and the key as reference (ZI_CA_OpsCashJrnl), per key, company code and
  "! currency
  METHODS keys_not_in_gl
    IMPORTING
      iv_closed_to   TYPE d
      iv_awtyp       TYPE csequence
      iv_max         TYPE i
    RETURNING
      VALUE(rt_sums) TYPE zif_ca_ops_cash_types=>tt_sum
    RAISING
      zcx_ca_ops_error.

  "! Owner of a check: the active control covering the check (first by control ID), else the process owner
  METHODS owner
    IMPORTING
      iv_area         TYPE zif_ca_ops_types=>ty_area
      iv_check_id     TYPE zif_ca_ops_chk_types=>ty_check_id
      iv_process_id   TYPE zif_ca_ops_chk_types=>ty_process_id
    RETURNING
      VALUE(rs_owner) TYPE zif_ca_ops_cash_types=>ty_owner.

  "! The day is a working day of the factory calendar
  METHODS working_day
    IMPORTING
      iv_date           TYPE d
      iv_calendar       TYPE csequence
    RETURNING
      VALUE(rv_working) TYPE abap_bool
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
