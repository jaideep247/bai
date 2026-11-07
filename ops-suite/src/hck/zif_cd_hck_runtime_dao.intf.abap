*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_runtime_dao.intf.abap
*& Purpose:
*& Reads of the runtime checks of the morning report: number range
*& intervals (NRIV), queue entries grouped per queue / destination / state
*& / day (qRFC tables, configured bgRFC table), payments of payment runs in
*& a window with their flow (DPAYH, TFK042Z), G/L lines by XREF2 with their
*& clearing (collections) and the configuration of the in-flight check
*& (method classes, clearing rules, BAI roles, sequence outcomes).
*& Keyed or window-bounded, capped.
*& Read-only: the interface has no write method.
*& Modification log:
*& 2026-11-07 | Initial version (checks E_NUMRANGE, E_QUEUES, A_INFLIGHT).
*& 2026-11-07 | get_cleared_assignments (BSAS) replaced by get_gl_lines_by_xref2 (BSEG); reads of
*&            | ZCD_HCK_PMCLASS, _PMBANK, _EVSET, ZCD_HCK_CLRRULE, ZCD_HCK_BTCROLE, ZCD_HCK_SEQOUT (user rules
*&            | 1-5); configured table by reference (Stripe payout log).
*& 2026-11-07 | get_issued_payments_by_doc: payment runs of payment documents (canonical payment outcome).
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

  "! Payment runs (DPAYH: proposal runs excluded) of the payment documents with the collection
  "! indicator of the method - the same join as GET_ISSUED_PAYMENTS, by DOC1R instead of the
  "! run-date window (every run of a document; empty list = nothing read); at most iv_max_rows
  METHODS get_issued_payments_by_doc
    IMPORTING
      it_docno           TYPE zif_cd_ops_trace_types=>tt_docno
      iv_max_rows        TYPE i
    RETURNING
      VALUE(rt_payments) TYPE zif_cd_hck_runtime_types=>tt_issued_payment.

  "! G/L lines (BSEG) whose XREF2 is one of the keys' values in the company code, fiscal year
  "! iv_gjahr_from .. iv_gjahr_to and - when it_hkont is not empty - one of the G/L accounts;
  "! with their clearing document AUGBL; at most iv_max_rows rows (reaching it = capped)
  METHODS get_gl_lines_by_xref2
    IMPORTING
      it_keys         TYPE zif_cd_hck_runtime_types=>tt_xref2_key
      iv_gjahr_from   TYPE zif_cd_hck_runtime_types=>ty_year
      iv_gjahr_to     TYPE zif_cd_hck_runtime_types=>ty_year
      it_hkont        TYPE zif_cd_hck_runtime_types=>tt_hkont
      iv_max_rows     TYPE i
    RETURNING
      VALUE(rt_lines) TYPE zif_cd_hck_runtime_types=>tt_gl_xref2_line.

  "! Active method classes (ZCD_HCK_PMCLASS) with their payment methods and ageing basis
  METHODS get_pm_classes
    RETURNING
      VALUE(rt_classes) TYPE zif_cd_hck_runtime_types=>tt_pm_class.

  "! Active house-bank calendars per flow + method class (ZCD_HCK_PMBANK)
  METHODS get_pm_banks
    RETURNING
      VALUE(rt_banks) TYPE zif_cd_hck_runtime_types=>tt_pm_bank.

  "! Active settings of an evidence kind (ZCD_HCK_EVSET by set id)
  METHODS get_evidence_settings
    IMPORTING
      iv_set_id          TYPE zif_cd_hck_runtime_types=>ty_set_id
    RETURNING
      VALUE(rt_settings) TYPE zif_cd_hck_runtime_types=>tt_setting.

  "! Rows of a configured table whose reference field is one of the values (e.g. the Stripe
  "! payout log ZCD_STRP_POUT_LOG). Table on ZCD_HCK_TABWL, fields in the DDIC - checked before
  "! the read; at most iv_max_rows rows (reaching it = capped)
  "! @raising zcx_cd_ops_error | table not whitelisted, unknown field, SQL error
  METHODS get_reference_rows
    IMPORTING
      is_source      TYPE zif_cd_hck_runtime_types=>ty_ref_source
      it_refs        TYPE zif_cd_hck_runtime_types=>tt_ref_value
      iv_max_rows    TYPE i
    RETURNING
      VALUE(rt_rows) TYPE zif_cd_hck_runtime_types=>tt_ref_row
    RAISING
      zcx_cd_ops_error.

  "! Active clearing / return evidence rules (ZCD_HCK_CLRRULE)
  METHODS get_clearing_rules
    RETURNING
      VALUE(rt_rules) TYPE zif_cd_hck_runtime_types=>tt_clr_rule.

  "! Active BAI code roles per flow + method class (ZCD_HCK_BTCROLE)
  METHODS get_btc_roles
    RETURNING
      VALUE(rt_roles) TYPE zif_cd_hck_runtime_types=>tt_btc_role.

  "! Active outcomes of role sequences per flow + method class (ZCD_HCK_SEQOUT)
  METHODS get_seq_outcomes
    RETURNING
      VALUE(rt_outcomes) TYPE zif_cd_hck_runtime_types=>tt_seq_outcome.

ENDINTERFACE.
