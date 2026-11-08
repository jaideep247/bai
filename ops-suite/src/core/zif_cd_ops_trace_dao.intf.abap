*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_trace_dao.intf.abap
*& Purpose:
*& Every read of the 360 degree payment trace. Key reads only (no LIKE,
*& no range scans without a key), each bounded by a row cap; table-driven
*& methods return an empty table for an empty key list. Read-only: the
*& interface has no write method.
*& Modification log:
*& 2026-11-06 | Initial version (360 degree payment trace).
*& 2026-11-06 | Configured and EBS reads reuse the existing validated readers; files by date.
*& 2026-11-06 | Return / NOC reasons: get_returns carries DFKKRP-RLGRD; get_noc_items (DFKKNRP by INFOF, capped).
*& 2026-11-07 | Comment: source specifications from ZCA_PARAM (ZCD_OPS_PARAM retired).
*& 2026-11-07 | read_configured_set: one read for many keys (source attribution of the payment outcome).
*& 2026-11-08 | Table consolidation: approved tables read from ZCD_OPS_TABWL (area FMON, purpose SOURCE; was
*&            | ZCD_FMON_TABWL).
*& 2026-11-08 | READ_CONFIGURED_AFTER: watermark read of a configured source (keyset date, time, key) - request log
*&            | of the payment worklist.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment trace - read repository</p>
INTERFACE zif_cd_ops_trace_dao
  PUBLIC.

  "! Rows of a configured source (request log, clearing-reset history, generated-file
  "! register, payment-level ACK, cheque history) for one key. Table and field names come
  "! from ZCA_PARAM; the read goes through the file monitoring reader, which checks
  "! them against the DDIC, the approved tables (ZCD_OPS_TABWL, FMON / SOURCE) and S_TABU_NAM first.
  "! @parameter iv_match_key2 | abap_false: KEY2 is read but not used as a condition
  "! @raising zcx_cd_ops_error | unknown table / field, table not approved or not authorised
  METHODS read_configured
    IMPORTING
      is_source      TYPE zif_cd_ops_trace_types=>ty_source_cfg
      is_key         TYPE zif_cd_ops_trace_types=>ty_cfg_key
      iv_match_key2  TYPE abap_bool DEFAULT abap_true
      iv_max_rows    TYPE i
    RETURNING
      VALUE(rt_rows) TYPE zif_cd_ops_trace_types=>tt_cfg_row
    RAISING
      zcx_cd_ops_error.

  "! Rows of a configured source for many keys in one read (KEY1 IN the values; KEY2 read,
  "! not compared) - the source attribution of FIN numbers by the payment outcome evaluator
  "! @raising zcx_cd_ops_error | unknown table / field, table not approved or not authorised
  METHODS read_configured_set
    IMPORTING
      is_source      TYPE zif_cd_ops_trace_types=>ty_source_cfg
      it_keys        TYPE zif_cd_ops_trace_types=>tt_key_value
      iv_max_rows    TYPE i
    RETURNING
      VALUE(rt_rows) TYPE zif_cd_ops_trace_types=>tt_cfg_row
    RAISING
      zcx_cd_ops_error.

  "! Watermark read of a configured source (2026-11-08, request log of the payment worklist): the rows
  "! after the keyset position (DATE, TIME, KEY = the source's DATE / TIME / KEY fields) with DATE up to
  "! iv_date_to, ordered by DATE, TIME, KEY, at most iv_max_rows. DATE (and KEY) must be configured
  "! @raising zcx_cd_ops_error | unknown table / field, table not approved or not authorised
  METHODS read_configured_after
    IMPORTING
      is_source      TYPE zif_cd_ops_trace_types=>ty_source_cfg
      is_after       TYPE zif_cd_ops_trace_types=>ty_cfg_seek
      iv_date_to     TYPE d
      iv_max_rows    TYPE i
    RETURNING
      VALUE(rt_rows) TYPE zif_cd_ops_trace_types=>tt_cfg_row
    RAISING
      zcx_cd_ops_error.

  "! Business partners by external number (BUT000-BPEXT = request ZZ_MEMBER_NO), with the
  "! configured source field when iv_source_field is given (VERIFY-SE11; read through the
  "! approved reader, so BUT000 needs a ZCD_OPS_TABWL row FMON / SOURCE)
  "! @raising zcx_cd_ops_error | source field unknown, BUT000 not approved or not authorised
  METHODS get_partners
    IMPORTING
      iv_bpext           TYPE zif_cd_ops_trace_types=>ty_key_value
      iv_source_field    TYPE zif_cd_ops_trace_types=>ty_fieldname OPTIONAL
      iv_source          TYPE zif_cd_ops_trace_types=>ty_source OPTIONAL
      iv_max_rows        TYPE i
    RETURNING
      VALUE(rt_partners) TYPE zif_cd_ops_trace_types=>tt_partner
    RAISING
      zcx_cd_ops_error.

  "! Open items by FIN number (DFKKOP-ZZ_FIN_TRANS_NUM, confirmed)
  METHODS get_items_by_fin
    IMPORTING
      iv_fin          TYPE zif_cd_ops_trace_types=>ty_fin
      iv_max_rows     TYPE i
    RETURNING
      VALUE(rt_items) TYPE zif_cd_ops_trace_types=>tt_item.

  "! Open items by clearing document (DFKKOP-AUGBL)
  METHODS get_items_by_clearing
    IMPORTING
      iv_augbl        TYPE zif_cd_ops_trace_types=>ty_docno
      iv_max_rows     TYPE i
    RETURNING
      VALUE(rt_items) TYPE zif_cd_ops_trace_types=>tt_item.

  "! Document headers (DFKKKO): FIKEY, reversal document, entry date / time
  METHODS get_doc_headers
    IMPORTING
      it_docno          TYPE zif_cd_ops_trace_types=>tt_docno
    RETURNING
      VALUE(rt_headers) TYPE zif_cd_ops_trace_types=>tt_doc_header.

  "! Payment run rows (DPAYH) by payment document DOC1R, proposal runs excluded
  METHODS get_payment_runs
    IMPORTING
      it_docno       TYPE zif_cd_ops_trace_types=>tt_docno
    RETURNING
      VALUE(rt_runs) TYPE zif_cd_ops_trace_types=>tt_payment_run.

  "! Cheque register (DFKKCR) by payment document: DFKKCR-DOC1R = DFKKOP-AUGBL
  METHODS get_checks_by_doc
    IMPORTING
      it_docno         TYPE zif_cd_ops_trace_types=>tt_docno
    RETURNING
      VALUE(rt_checks) TYPE zif_cd_ops_trace_types=>tt_check.

  "! Cheque register (DFKKCR) by cheque number ZTNUM
  METHODS get_checks_by_number
    IMPORTING
      iv_ztnum         TYPE zif_cd_ops_trace_types=>ty_ref
      iv_max_rows      TYPE i
    RETURNING
      VALUE(rt_checks) TYPE zif_cd_ops_trace_types=>tt_check.

  "! Bank statement lines (FEBEP) by CHECT = clearing reference (methods E G H I J K L) or
  "! cheque number (method C), posted on or after iv_from
  METHODS get_bank_lines
    IMPORTING
      it_ref          TYPE zif_cd_ops_trace_types=>tt_ref
      iv_from         TYPE d
      iv_max_rows     TYPE i
    RETURNING
      VALUE(rt_lines) TYPE zif_cd_ops_trace_types=>tt_bank_line.

  "! Returns lot items (DFKKRP-SELW1 = clearing reference) with the lot status and the
  "! return reason RLGRD
  METHODS get_returns
    IMPORTING
      it_docno          TYPE zif_cd_ops_trace_types=>tt_docno
    RETURNING
      VALUE(rt_returns) TYPE zif_cd_ops_trace_types=>tt_return.

  "! NOC lot items (DFKKNRP) whose INFOF is one of the given exact values (clearing document
  "! or payment reference in every stored form); at most iv_max_rows + 1 rows (INFOF is no key)
  METHODS get_noc_items
    IMPORTING
      it_infof        TYPE zif_cd_ops_trace_types=>tt_infof
      iv_max_rows     TYPE i
    RETURNING
      VALUE(rt_items) TYPE zif_cd_ops_trace_types=>tt_noc.

  "! ACH retrieval log (ZCD_ACH_RTRV_LOG-AUGBL); status field from EBS_RTRV_STATUS_FIELD
  "! (the EBS read, shared)
  "! @raising zcx_cd_ops_error | configured status field unknown
  METHODS get_retrievals
    IMPORTING
      it_docno             TYPE zif_cd_ops_trace_types=>tt_docno
    RETURNING
      VALUE(rt_retrievals) TYPE zif_cd_ops_trace_types=>tt_retrieval
    RAISING
      zcx_cd_ops_error.

  "! Monitored files (ZCD_FMON_FILE) by file reference with a business date in
  "! iv_from .. iv_to (index BDT; the reference alone has no index)
  METHODS get_fmon_files
    IMPORTING
      it_file_ref     TYPE zif_cd_ops_trace_types=>tt_file_ref
      iv_from         TYPE d
      iv_to           TYPE d
    RETURNING
      VALUE(rt_files) TYPE zif_cd_ops_trace_types=>tt_fmon_file.

  "! File events (ZCD_FMON_EVENT) of the files
  METHODS get_fmon_events
    IMPORTING
      it_file_id       TYPE zif_cd_ops_trace_types=>tt_file_id
    RETURNING
      VALUE(rt_events) TYPE zif_cd_ops_trace_types=>tt_fmon_event.

  "! Summary records (DFKKSUMC) of the FIKEYs
  METHODS get_summary_keys
    IMPORTING
      it_fikey        TYPE zif_cd_ops_trace_types=>tt_fikey
    RETURNING
      VALUE(rt_fikey) TYPE zif_cd_ops_trace_types=>tt_fikey.

  "! G/L documents of the transfer: BKPF-AWTYP = iv_awtyp, AWKEY = FIKEY, same company code
  METHODS get_gl_documents
    IMPORTING
      it_fikey       TYPE zif_cd_ops_trace_types=>tt_fikey
      iv_awtyp       TYPE zif_cd_ops_trace_types=>ty_key_value
    RETURNING
      VALUE(rt_docs) TYPE zif_cd_ops_trace_types=>tt_gl_doc.

  "! Lines of the G/L documents whose XREF2 carries the clearing reference (BSEG by key)
  METHODS get_gl_clearing_lines
    IMPORTING
      it_keys         TYPE zif_cd_ops_trace_types=>tt_gl_key
      iv_xref2        TYPE zif_cd_ops_trace_types=>ty_docno
    RETURNING
      VALUE(rt_lines) TYPE zif_cd_ops_trace_types=>tt_gl_line.

  "! Collection or disbursement payment method (TFK042Z-XEINZ via T001-LAND1)
  METHODS get_method_kind
    IMPORTING
      iv_bukrs       TYPE zif_cd_ops_trace_types=>ty_bukrs
      iv_pymet       TYPE zif_cd_ops_trace_types=>ty_pymet
    RETURNING
      VALUE(rv_kind) TYPE zif_cd_ops_trace_types=>ty_kind.

ENDINTERFACE.
