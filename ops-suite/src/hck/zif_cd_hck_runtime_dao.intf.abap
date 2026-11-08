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
*& 2026-11-08 | Table consolidation: approved tables (HCK / READ) and drift tables (HCK / DRIFT) read from
*&            | ZCD_OPS_TABWL (was ZCD_HCK_TABWL, ZCD_HCK_DRIFT).
*& 2026-11-08 | Table consolidation: get_btc_roles reads usage LIFECYCLE of ZCD_HCK_BTCROLE (flow + method
*&            | class split from SCOPE).
*& 2026-11-08 | Table consolidation: get_evidence_settings (ZCD_HCK_EVSET) removed - the Stripe settings are
*&            | ZCA_PARAM parameters HCK_STRIPE_*.
*& 2026-11-08 | Table consolidation: get_pm_classes returns the class rows and the house-bank calendar rows
*&            | (key HBKID); get_pm_banks (ZCD_HCK_PMBANK) removed.
*& 2026-11-08 | Customer posting areas: get_pm_classes reads ZPMC, get_btc_roles ZBTR usage LIFECYCLE (were
*&            | ZCD_HCK_PMCLASS / ZCD_HCK_BTCROLE).
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
  "! DDIC (and ZCD_OPS_TABWL HCK / READ for a configured table) before the read.
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

  "! Method classes of the customer posting area ZPMC (FQC0 keys FLOW / PAYMENT METHOD / HOUSE
  "! BANK, results METHOD_CLASS / AGE_BASIS / CALENDAR): one class row (HBKID blank) per flow +
  "! class with the payment methods of its '*' entries, ageing basis and calendar, and one
  "! house-bank calendar row per flow + class + house bank (entries with a house bank).
  "! Entries with flow or payment method '*' or without class are not used (configuration check)
  METHODS get_pm_classes
    RETURNING
      VALUE(rt_classes) TYPE zif_cd_hck_runtime_types=>tt_pm_class.

  "! Rows of a configured table whose reference field is one of the values (e.g. the Stripe
  "! payout log ZCD_STRP_POUT_LOG). Table on ZCD_OPS_TABWL (HCK / READ), fields in the DDIC - checked before
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

  "! Bank code roles of the payment lifecycle per flow + method class: entries of the customer
  "! posting area ZBTR with usage LIFECYCLE (flow and method class split from SCOPE, ISO code from
  "! its three parts; RECON entries and entries with '*' are never returned)
  METHODS get_btc_roles
    RETURNING
      VALUE(rt_roles) TYPE zif_cd_hck_runtime_types=>tt_btc_role.

  "! Active outcomes of role sequences per flow + method class (ZCD_HCK_SEQOUT)
  METHODS get_seq_outcomes
    RETURNING
      VALUE(rt_outcomes) TYPE zif_cd_hck_runtime_types=>tt_seq_outcome.

ENDINTERFACE.
