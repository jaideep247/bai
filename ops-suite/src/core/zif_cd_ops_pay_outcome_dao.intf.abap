*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_pay_outcome_dao.intf.abap
*& Purpose:
*& SQL of the incremental payment outcome snapshot: watermarks per evidence
*& source (ZCD_PAY_OUTWM), the payment documents with new evidence after a
*& watermark (one set-based read per source and package, ordered, capped),
*& cheques of statement references, the FIN numbers of payment documents
*& (DFKKOP), the current versions of FIN numbers and the version writes
*& (ZCD_PAY_OUTCOME: close by UPDATE FROM TABLE, insert FROM TABLE). The
*& caller commits (through the store). Writes only the suite's own tables.
*& Modification log:
*& 2026-11-07 | Initial version (incremental 5-minute payment outcome snapshot).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment outcome - snapshot repository</p>
"! Implementation ZCL_CD_OPS_PAY_OUTCOME_DAO, factory ZCL_CD_OPS_FACTORY=>GET_PAY_OUTCOME_DAO.
"! Never one SELECT per payment: every read takes a key set or a watermark and a package size.
INTERFACE zif_cd_ops_pay_outcome_dao
  PUBLIC.

  "! Watermarks of every source read so far (a missing source = first run)
  METHODS get_watermarks
    RETURNING
      VALUE(rt_watermarks) TYPE zif_cd_ops_payout_types=>tt_watermark.

  "! Write the watermark of a source (no commit)
  METHODS save_watermark
    IMPORTING
      is_watermark TYPE zif_cd_ops_payout_types=>ty_watermark
    RAISING
      zcx_cd_ops_error.

  "! Payment documents (and, for STATEMENT, statement references) with new evidence of the
  "! source after the watermark, in watermark order, at most iv_max keys; the watermark of
  "! the last key read and whether more keys wait. A watermark without key starts at its date
  "! @parameter iv_source | ZIF_CD_OPS_PAYOUT_TYPES=>GC_SOURCE
  METHODS get_changes
    IMPORTING
      iv_source         TYPE zif_cd_ops_payout_types=>ty_source_id
      is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
      iv_max            TYPE i
    RETURNING
      VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes.

  "! Payment documents of cheques whose number is one of the statement references
  "! (DFKKCR-ZTNUM = FEBEP-CHECT, DFKKCR-DOC1R = AUGBL)
  METHODS get_cheque_documents
    IMPORTING
      it_refs         TYPE zif_cd_ops_trace_types=>tt_ref
    RETURNING
      VALUE(rt_docno) TYPE zif_cd_ops_trace_types=>tt_docno.

  "! Items with a FIN number cleared by the payment documents (DFKKOP-AUGBL, ZZ_FIN_TRANS_NUM)
  METHODS get_fin_items
    IMPORTING
      it_docno        TYPE zif_cd_ops_trace_types=>tt_docno
    RETURNING
      VALUE(rt_items) TYPE zif_cd_ops_payout_types=>tt_fin_item.

  "! Current versions (VALID_TO open) of the FIN numbers (index FIN)
  METHODS get_open_versions
    IMPORTING
      it_fin             TYPE zif_cd_ops_payout_types=>tt_fin
    RETURNING
      VALUE(rt_versions) TYPE zif_cd_ops_payout_types=>tt_version.

  "! Close versions (their VALID_TO set) and insert new ones, set-based, no commit
  "! @raising zcx_cd_ops_error | a version could not be written
  METHODS save_versions
    IMPORTING
      it_close  TYPE zif_cd_ops_payout_types=>tt_version
      it_insert TYPE zif_cd_ops_payout_types=>tt_version
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
