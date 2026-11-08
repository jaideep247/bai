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
*& 2026-11-08 | Exceptions-only worklist: every row of payments / requests (GET_VERSIONS, GET_REQUEST_VERSIONS),
*&            | request keys of FIN numbers, deletes and in-place updates of open rows (SAVE_VERSIONS), request
*&            | items with payment run and block, due requests of A_PRQ_NOT_PAID, NIGHTLY / NIGHTLYREQ cursors and
*&            | the SWEEP upper date (GET_CHANGES iv_to), package rows per mode's sources, not yet snapshotted =
*&            | after the DOCUMENTS watermark.
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

  "! Payment documents (and, for STATEMENT, statement references; for NIGHTLYREQ, payment requests)
  "! with new evidence of the source after the watermark, in watermark order, at most iv_max keys; the
  "! watermark of the last key read and whether more keys wait. A watermark without key starts at its
  "! date. NIGHTLY / NIGHTLYREQ: the current worklist rows after the cursor (payments / requests).
  "! REQUESTS is read by the request service (configured request log), not here
  "! @parameter iv_source | ZIF_CD_OPS_PAYOUT_TYPES=>GC_SOURCE
  "! @parameter iv_to | SWEEP: last entry / posting date read (initial: no upper bound)
  METHODS get_changes
    IMPORTING
      iv_source         TYPE zif_cd_ops_payout_types=>ty_source_id
      is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
      iv_max            TYPE i
      iv_to             TYPE d OPTIONAL
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

  "! Every worklist row (current and closed) of the payment documents, every FIN and source (index
  "! DOC): the current rows to compare and whether the payment has exception history
  METHODS get_versions
    IMPORTING
      it_docno           TYPE zif_cd_ops_trace_types=>tt_docno
    RETURNING
      VALUE(rt_versions) TYPE zif_cd_ops_payout_types=>tt_version.

  "! Every worklist row (current and closed) of the payment requests (FIN + source, payment document
  "! blank; index FIN)
  METHODS get_request_versions
    IMPORTING
      it_keys            TYPE zif_cd_ops_payout_types=>tt_req_key
    RETURNING
      VALUE(rt_versions) TYPE zif_cd_ops_payout_types=>tt_version.

  "! Payment requests with a current worklist row of the FIN numbers (index FIN): re-judged when a
  "! payment of the FIN is judged, so a request paid on time leaves the worklist within one run
  METHODS get_request_keys
    IMPORTING
      it_fin         TYPE zif_cd_ops_payout_types=>tt_fin
    RETURNING
      VALUE(rt_keys) TYPE zif_cd_ops_payout_types=>tt_req_key.

  "! Write the worklist, set-based, no commit: delete rows (open rows of a payment that left the
  "! worklist), close versions (VALID_TO set), update open rows in place, insert new rows
  "! @raising zcx_cd_ops_error | a row could not be written (a concurrent run changed it: retried)
  METHODS save_versions
    IMPORTING
      it_close  TYPE zif_cd_ops_payout_types=>tt_version
      it_insert TYPE zif_cd_ops_payout_types=>tt_version
      it_delete TYPE zif_cd_ops_payout_types=>tt_version OPTIONAL
      it_update TYPE zif_cd_ops_payout_types=>tt_version OPTIONAL
    RAISING
      zcx_cd_ops_error.

  "! Items of the FIN numbers of payment requests (DFKKOP-ZZ_FIN_TRANS_NUM) with the payment run of
  "! their clearing document (DPAYH-DOC1R = AUGBL, no proposal run) and the payment block
  "! (DFKKOP-SPZAH, VERIFY-SE11) - the stage of a request
  METHODS get_request_items
    IMPORTING
      it_fin          TYPE zif_cd_ops_payout_types=>tt_fin
    RETURNING
      VALUE(rt_items) TYPE zif_cd_ops_payout_types=>tt_req_item.

  "! Current request rows of the worklist due before iv_before (open or not paid), with the sum of
  "! their items per currency (DFKKOP by FIN; none = no item), oldest due date first, at most iv_max -
  "! the morning report check A_PRQ_NOT_PAID
  METHODS get_due_requests
    IMPORTING
      iv_before      TYPE d
      iv_max         TYPE i
    RETURNING
      VALUE(rt_rows) TYPE zif_cd_ops_payout_types=>tt_due_request.

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

  "! Delete the package rows of the sources of every run but this one (run lock of the mode held - the
  "! rows of another mode's sources stay), no commit; rows deleted
  METHODS delete_packages
    IMPORTING
      iv_keep_run_id  TYPE zif_cd_ops_types=>ty_run_id
      it_sources      TYPE zif_cd_ops_payout_types=>tt_source_id
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

  "! Payment documents of payment runs (DPAYH, no proposal run) of the methods not reached by the
  "! snapshot yet: entered (DFKKKO CPUDT / CPUTM / OPBEL) after the DOCUMENTS watermark is_after; without
  "! watermark (first run not done) the runs from iv_from. Oldest first, at most iv_max. A clean
  "! payment has no worklist row (2026-11-08), so "no row" never means "not reached"
  METHODS get_unsnapshotted
    IMPORTING
      it_methods      TYPE zif_cd_hck_runtime_types=>tt_pymet
      is_after        TYPE zif_cd_ops_payout_types=>ty_watermark
      iv_from         TYPE d
      iv_max          TYPE i
    RETURNING
      VALUE(rt_docno) TYPE zif_cd_ops_trace_types=>tt_docno.

ENDINTERFACE.
