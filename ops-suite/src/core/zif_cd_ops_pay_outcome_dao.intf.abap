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
*& 2026-11-08 | Scale: current versions by payment document (index DOC, also payments without FIN);
*&            | parallel packages (ZCD_PAY_OUTPKG: save, claim FOR UPDATE, finish, abandon, read,
*&            | delete); versions written by a run (aggregated findings); A_INFLIGHT aggregate reads
*&            | (grouped current versions with DPAYH by key, examples per partition, ACK candidates,
*&            | payment documents not yet snapshotted).
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

  "! Current versions (VALID_TO open) of the payment documents, every FIN and source (index DOC)
  METHODS get_open_versions
    IMPORTING
      it_docno           TYPE zif_cd_ops_trace_types=>tt_docno
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

  " ------------------------------------------------------------ parallel packages (ZCD_PAY_OUTPKG)
  "! Plan the packages of a run (status P), no commit
  "! @raising zcx_cd_ops_error | a package row could not be written
  METHODS save_packages
    IMPORTING
      it_packages TYPE zif_cd_ops_payout_types=>tt_package
    RAISING
      zcx_cd_ops_error.

  "! Lock the package row for this LUW (SELECT FOR UPDATE) and tell whether it is still planned:
  "! an abandoned package writes nothing
  METHODS claim_package
    IMPORTING
      is_package        TYPE zif_cd_ops_payout_types=>ty_package
    RETURNING
      VALUE(rv_claimed) TYPE abap_bool.

  "! Status, counts and message of a package (D or F), no commit
  "! @raising zcx_cd_ops_error | the package row could not be written
  METHODS finish_package
    IMPORTING
      is_package TYPE zif_cd_ops_payout_types=>ty_package
    RAISING
      zcx_cd_ops_error.

  "! Packages of a run with status and counts (no document lists)
  METHODS get_packages
    IMPORTING
      iv_run_id          TYPE zif_cd_ops_types=>ty_run_id
    RETURNING
      VALUE(rt_packages) TYPE zif_cd_ops_payout_types=>tt_package.

  "! Packages of the run still planned become abandoned (their unit writes nothing any more), no
  "! commit; the number of packages abandoned
  METHODS abandon_packages
    IMPORTING
      iv_run_id       TYPE zif_cd_ops_types=>ty_run_id
    RETURNING
      VALUE(rv_count) TYPE i.

  "! Delete the package rows of every run but this one (run lock held), no commit; rows deleted
  METHODS delete_packages
    IMPORTING
      iv_keep_run_id  TYPE zif_cd_ops_types=>ty_run_id
    RETURNING
      VALUE(rv_count) TYPE i.

  "! Versions written by a run (VALID_FROM = the run time) with a finding, with the method and flow
  "! indicator of the payment (DPAYH by key, TFK042Z) - aggregated findings of parallel packages
  METHODS get_new_versions
    IMPORTING
      iv_valid_from      TYPE zif_cd_ops_payout_types=>ty_timestamp
      iv_finding         TYPE zif_cd_ops_types=>ty_check_code
    RETURNING
      VALUE(rt_versions) TYPE zif_cd_ops_payout_types=>tt_new_version.

  " ------------------------------------------------------------ A_INFLIGHT (set-based on HANA)
  "! Current versions grouped on HANA, one row per payment counted once (FIN and source rows of a
  "! payment collapse), joined to DPAYH by key (LAUFD, LAUFI, DOC1R = AUGBL) and TFK042Z: payments of
  "! the methods whose outcome is not final - every one, however old - and final outcomes of runs on
  "! or after iv_final_from; AMBIGUOUS rows are not counted (their payments: GET_AMBIGUOUS_ONLY)
  METHODS get_outcome_groups
    IMPORTING
      is_query          TYPE zif_cd_ops_payout_types=>ty_group_query
    RETURNING
      VALUE(rt_groups) TYPE zif_cd_ops_payout_types=>tt_outcome_group.

  "! The first iv_rows payments (value date, then payment document) of every partition flow
  "! indicator + method + house bank + run + outcome + finding + payment status of the current
  "! versions matching the query - the examples of the aggregated findings
  METHODS get_outcome_examples
    IMPORTING
      is_query           TYPE zif_cd_ops_payout_types=>ty_group_query
      iv_rows            TYPE i
    RETURNING
      VALUE(rt_examples) TYPE zif_cd_ops_payout_types=>tt_outcome_example.

  "! Payments of the current versions matching the query, oldest run first (run date, payment
  "! document), at most iv_max - the candidates of the bank ACK case of PAY_STATUS_LAG
  METHODS get_outcome_rows
    IMPORTING
      is_query       TYPE zif_cd_ops_payout_types=>ty_group_query
      iv_max         TYPE i
    RETURNING
      VALUE(rt_rows) TYPE zif_cd_ops_payout_types=>tt_outcome_example.

  "! Payments whose current versions all say AMBIGUOUS (the evaluated outcome is not stored): their
  "! documents, oldest run first, at most iv_max
  METHODS get_ambiguous_only
    IMPORTING
      is_query        TYPE zif_cd_ops_payout_types=>ty_group_query
      iv_max          TYPE i
    RETURNING
      VALUE(rt_docno) TYPE zif_cd_ops_trace_types=>tt_docno.

  "! Payment documents of payment runs (DPAYH, no proposal run) of the methods with run date from
  "! iv_from that have no current version yet (not reached by the snapshot), oldest first, at most
  "! iv_max
  METHODS get_unsnapshotted
    IMPORTING
      it_methods      TYPE zif_cd_hck_runtime_types=>tt_pymet
      iv_from         TYPE d
      iv_max          TYPE i
    RETURNING
      VALUE(rt_docno) TYPE zif_cd_ops_trace_types=>tt_docno.

ENDINTERFACE.
