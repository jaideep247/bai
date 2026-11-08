*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_snapshot.clas.abap
*& Purpose:
*& The payment worklist ZCD_PAY_OUTCOME: open payments, open payment
*& requests and exceptions only (user decision 2026-11-08). Three modes of
*& program ZCD_OPS_PAY_SNAPSHOT: FAST (every 5 minutes, step 2 of SM36 job
*& ZCD_FMON_MONITOR_ALL) reads per evidence source (payment / clearing
*& documents, reversals, statement lines, returns lots, G/L clearing of
*& XREF2, new payment requests, recheck of rows that are not final) only
*& what is new after the source's watermark; NIGHTLY re-evaluates every
*& current row (a payment becomes late, a request passes its due date with
*& no new evidence) from a cursor; SWEEP re-reads chosen evidence sources
*& for a date range without moving a watermark. Payments are judged by the
*& shared evaluator ZIF_CD_OPS_PAY_OUTCOME, their age by the shared rule
*& ZCL_CD_HCK_PAY_AGEING (late beyond AMBER / RED of A_INFLIGHT = finding
*& PAYMENT_NOT_CLEARED), requests by ZIF_CD_OPS_PAY_REQUEST (due date,
*& stage; not paid by the end of the due date = PRQ_NOT_PAID). Worklist rule
*& (PLAN_WORKLIST): a final, clean outcome (CLEARED / RETURNED / RETRIEVED /
*& VOIDED / REVERSED, no finding; a request paid on time or cancelled) has
*& no row - its open row is deleted; an open row is one current row changed
*& in place; an exception (any finding) keeps versions, and when it closes
*& its last version is closed and a closing version (valid from = valid to)
*& records how it ended - the purge removes it 90 days later. Unchanged rows
*& are never rewritten. A FIN in two sources is AMBIGUOUS for both (one
*& finding per flow + method class + run date). PAYOUT_PARALLEL > 1: the
*& packages are planned first, judged in waves of bgPF units
*& (ZCL_CD_OPS_PAY_SNAP_OP, rows ZCD_PAY_OUTPKG) and a watermark advances
*& only to the end of the last contiguous completed package. A package that
*& cannot be judged completely writes nothing (PAY_OUTCOME_FAILED). Run lock
*& per mode; test mode writes nothing. Read-only towards business tables.
*& Modification log:
*& 2026-11-07 | Initial version (incremental 5-minute payment outcome snapshot).
*& 2026-11-08 | Scale (2 million payments a peak day, user 2026-11-08): parallel packages as bgPF units
*&            | (PAYOUT_PARALLEL, PAYOUT_PARALLEL_WAIT_SEC; queue seam ZIF_CD_OPS_PAY_SNAP_QUEUE) with
*&            | ordered watermark advancement (CONTIGUOUS_DONE); PAYOUT_PARALLEL 1 unchanged. CURRENT_TO
*&            | per watermark and the snapshot lag (LAG). Versions also for payments without FIN; current
*&            | versions read by payment document; a new version when the finding changes too; marker
*&            | PAY_STATUS_PENDING for a verdict whose payment status waits for the status job (basis of
*&            | A_INFLIGHT PAY_STATUS_LAG); SEVERITY of the version. PAY_SOURCE_AMBIGUOUS aggregated per
*&            | flow + method class + run date with count and the first PAYOUT_EXAMPLES examples.
*& 2026-11-08 | Exceptions-only worklist (user decision 2026-11-08, was: a version for every payment): clean
*&            | final outcomes deleted, open rows changed in place, exception versions and a closing
*&            | version (PLAN_WORKLIST replaces PLAN_VERSIONS); late payments marked by the shared ageing
*&            | rule; modes FAST / NIGHTLY / SWEEP (own run lock variants, NIGHTLY cursors, SWEEP date
*&            | range without watermarks, PAYOUT_BATCH_MAX_PACKAGES); payment requests (source REQUESTS,
*&            | due date and stage by ZIF_CD_OPS_PAY_REQUEST, re-judged with their payment); FLOW_CLASS
*&            | and DUE_DATE of a row; the lag counts the FAST evidence sources only.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment worklist - FAST / NIGHTLY / SWEEP snapshot</p>
"! Parameters (ZCA_PARAM, CD_OPS): PAYOUT_PACKAGE_SIZE, PAYOUT_MAX_PACKAGES, PAYOUT_INITIAL_DAYS,
"! PAYOUT_PARALLEL, PAYOUT_PARALLEL_WAIT_SEC, PAYOUT_EXAMPLES, PAYOUT_BATCH_MAX_PACKAGES; evidence
"! row cap HCK_INFLIGHT_MAX_ROWS (as A_INFLIGHT); AGE_OLDEST limits and PARAM1 of A_INFLIGHT.
CLASS zcl_cd_ops_pay_snapshot DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_result,
        run      TYPE zif_cd_ops_types=>ty_run,
        "! Mode of the run (FAST, NIGHTLY, SWEEP)
        mode     TYPE zif_cd_ops_payout_types=>ty_mode,
        sources  TYPE zif_cd_ops_payout_types=>tt_source_result,
        findings TYPE zif_cd_ops_types=>tt_finding,
        "! Snapshot lag after the run (from the saved watermarks)
        lag      TYPE zif_cd_ops_payout_types=>ty_lag,
      END OF ty_result.

    "! Package status in package order (ordered watermark advancement)
    TYPES tt_pkg_status TYPE STANDARD TABLE OF zif_cd_ops_payout_types=>ty_pkg_status WITH EMPTY KEY.

    "! One run of the mode chosen (blank = FAST) over its evidence sources
    "! @raising zcx_cd_ops_error | run header or run end could not be written
    METHODS run
      IMPORTING
        iv_test_mode     TYPE abap_bool
        is_selection     TYPE zif_cd_ops_payout_types=>ty_selection OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE ty_result
      RAISING
        zcx_cd_ops_error.

    "! One parallel package as its bgPF unit runs it: judge the documents and requests, claim the
    "! package row (still planned), write the worklist rows and status D in one commit; on any error
    "! nothing of the package is written and its status is F. Never raises
    METHODS run_package
      IMPORTING
        is_package TYPE zif_cd_ops_payout_types=>ty_package.

    "! The worklist writes that make the rows of the evaluated payments and requests what the
    "! evaluation wants (entity = payment document, or FIN + source of a request):
    "!  - a clean entity (it_clean): without exception history its rows are deleted; with exception
    "!    history (a row with a finding, a closed row, or a clean entry that carries a finding - a
    "!    request paid late) the current rows are closed and a closing version per current key records
    "!    the outcome (valid from = valid to = now);
    "!  - a wanted row (it_desired): same outcome, finding, severity, evidence kind, flow class and due
    "!    date as the current row = nothing; both open (no finding) = updated in place (valid from
    "!    kept); else the current row is retired (exception closed, open row deleted) and the row
    "!    inserted; no current row = inserted;
    "!  - a current row of an evaluated entity that is not wanted any more, and every older duplicate of
    "!    a key (a concurrent run), is retired
    CLASS-METHODS plan_worklist
      IMPORTING
        it_desired TYPE zif_cd_ops_payout_types=>tt_version
        it_clean   TYPE zif_cd_ops_payout_types=>tt_version
        it_rows    TYPE zif_cd_ops_payout_types=>tt_version
        iv_now     TYPE zif_cd_ops_payout_types=>ty_timestamp
      EXPORTING
        et_close   TYPE zif_cd_ops_payout_types=>tt_version
        et_insert  TYPE zif_cd_ops_payout_types=>tt_version
        et_delete  TYPE zif_cd_ops_payout_types=>tt_version
        et_update  TYPE zif_cd_ops_payout_types=>tt_version.

    "! Ordered watermark rule: the number of leading packages (package order) that are done - the
    "! watermark of the source may advance to the end of the last of them and never further
    CLASS-METHODS contiguous_done
      IMPORTING
        it_status       TYPE tt_pkg_status
      RETURNING
        VALUE(rv_count) TYPE i.

    "! Snapshot lag at iv_now: whole minutes since the oldest CURRENT_TO of the FAST evidence sources
    "! (RECHECK and the NIGHTLY cursors have no evidence time and are left out); KNOWN blank when no
    "! source has a CURRENT_TO yet
    CLASS-METHODS lag
      IMPORTING
        it_watermarks TYPE zif_cd_ops_payout_types=>tt_watermark
        iv_now        TYPE timestampl
      RETURNING
        VALUE(rs_lag) TYPE zif_cd_ops_payout_types=>ty_lag.

    "! Evidence sources of a mode in processing order (FAST: the recheck last - it sees this run's rows)
    CLASS-METHODS sources
      IMPORTING
        is_selection      TYPE zif_cd_ops_payout_types=>ty_selection
      RETURNING
        VALUE(rt_sources) TYPE string_table.

  PRIVATE SECTION.
    "! A planned package of the parallel mode with the watermark after it
    TYPES:
      BEGIN OF ty_plan,
        package   TYPE zif_cd_ops_payout_types=>ty_package,
        watermark TYPE zif_cd_ops_payout_types=>ty_watermark,
        more      TYPE abap_bool,
        "! The watermark of its source already stands at the end of this package
        applied   TYPE abap_bool,
      END OF ty_plan.
    TYPES tt_plan TYPE STANDARD TABLE OF ty_plan WITH EMPTY KEY.

    "! A version with a finding written by this run and the flow + method class of its payment
    TYPES:
      BEGIN OF ty_flagged,
        version TYPE zif_cd_ops_payout_types=>ty_version,
        key     TYPE zif_cd_hck_runtime_types=>ty_flow_class,
      END OF ty_flagged.
    TYPES tt_flagged TYPE STANDARD TABLE OF ty_flagged WITH EMPTY KEY.

    "! What one package of documents and requests comes to
    TYPES:
      BEGIN OF ty_judgement,
        documents TYPE i,
        evaluated TYPE i,
        close     TYPE zif_cd_ops_payout_types=>tt_version,
        insert    TYPE zif_cd_ops_payout_types=>tt_version,
        delete    TYPE zif_cd_ops_payout_types=>tt_version,
        update    TYPE zif_cd_ops_payout_types=>tt_version,
        flagged   TYPE tt_flagged,
      END OF ty_judgement.

    "! A worklist row with its entity (payment document, or FIN + source of a request)
    TYPES:
      BEGIN OF ty_keyed,
        entity TYPE string,
        row    TYPE zif_cd_ops_payout_types=>ty_version,
      END OF ty_keyed.
    TYPES tt_keyed TYPE SORTED TABLE OF ty_keyed WITH NON-UNIQUE KEY entity.

    "! The wanted rows and clean entities of an evaluation
    TYPES:
      BEGIN OF ty_wanted,
        desired TYPE zif_cd_ops_payout_types=>tt_version,
        clean   TYPE zif_cd_ops_payout_types=>tt_version,
      END OF ty_wanted.

    DATA mo_dao TYPE REF TO zif_cd_ops_pay_outcome_dao.
    DATA mo_outcome TYPE REF TO zif_cd_ops_pay_outcome.
    DATA mo_request TYPE REF TO zif_cd_ops_pay_request.
    DATA mo_store TYPE REF TO zif_cd_ops_store.
    DATA mo_ageing TYPE REF TO zcl_cd_hck_pay_ageing.
    DATA ms_config TYPE zif_cd_ops_payout_types=>ty_config.
    DATA ms_selection TYPE zif_cd_ops_payout_types=>ty_selection.
    DATA mv_test_mode TYPE abap_bool.
    DATA mv_run_id TYPE zif_cd_ops_types=>ty_run_id.
    DATA mv_now TYPE zif_cd_ops_payout_types=>ty_timestamp.
    DATA mv_package TYPE i.
    DATA mv_max_packages TYPE i.
    DATA mv_initial_days TYPE i.
    DATA mv_parallel TYPE i.
    DATA mv_wait_sec TYPE i.
    DATA mv_examples TYPE i.
    "! Row cap of every evidence read (HCK_INFLIGHT_MAX_ROWS)
    DATA mv_cap TYPE i.
    "! Payment documents / requests already judged (or planned) in this run (in several sources: once)
    DATA mt_done TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA mt_req_done TYPE zif_cd_ops_payout_types=>tt_req_key.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.
    "! Versions with a finding written by the packages judged in this process (one by one, test mode)
    DATA mt_flagged TYPE tt_flagged.

    METHODS execute
      IMPORTING
        iv_test_mode     TYPE abap_bool
      RETURNING
        VALUE(rs_result) TYPE ty_result
      RAISING
        zcx_cd_ops_error.

    METHODS read_parameters.

    "! Run lock variant of the mode
    METHODS variant
      RETURNING
        VALUE(rv_variant) TYPE zif_cd_ops_types=>ty_variant.

    "! SWEEP without date range or evidence source, or with a source that cannot be swept: said, nothing run
    METHODS selection_valid
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! The changes of a source after its watermark: REQUESTS from the request service (configured
    "! request log), every other source from the repository; SWEEP stops at the end of its range
    METHODS changes
      IMPORTING
        iv_source         TYPE zif_cd_ops_payout_types=>ty_source_id
        is_watermark      TYPE zif_cd_ops_payout_types=>ty_watermark
      RETURNING
        VALUE(rs_changes) TYPE zif_cd_ops_payout_types=>ty_changes
      RAISING
        zcx_cd_ops_error.

    "! PAYOUT_PARALLEL = 1 (and test mode): one package after the other, rows and watermark of a
    "! package in one commit
    METHODS process_source
      IMPORTING
        iv_source        TYPE zif_cd_ops_payout_types=>ty_source_id
        is_watermark     TYPE zif_cd_ops_payout_types=>ty_watermark
      RETURNING
        VALUE(rs_result) TYPE zif_cd_ops_payout_types=>ty_source_result.

    "! Judge one package and write its rows and watermark (one commit; SWEEP keeps every watermark)
    METHODS process_package
      IMPORTING
        is_changes TYPE zif_cd_ops_payout_types=>ty_changes
      CHANGING
        cs_result  TYPE zif_cd_ops_payout_types=>ty_source_result
      RAISING
        zcx_cd_ops_error.

    "! PAYOUT_PARALLEL > 1: plan every source, judge the packages in waves of bgPF units, advance each
    "! watermark to the end of its last contiguous completed package after every wave
    METHODS process_parallel
      IMPORTING
        it_watermarks     TYPE zif_cd_ops_payout_types=>tt_watermark
      RETURNING
        VALUE(rt_results) TYPE zif_cd_ops_payout_types=>tt_source_result
      RAISING
        zcx_cd_ops_error.

    "! The packages of one source after its watermark (key reads only), documents of the run judged once
    METHODS plan_source
      IMPORTING
        iv_source       TYPE zif_cd_ops_payout_types=>ty_source_id
        is_watermark    TYPE zif_cd_ops_payout_types=>ty_watermark
      RETURNING
        VALUE(rt_plans) TYPE tt_plan.

    "! Dispatch one wave, wait for it (at most PAYOUT_PARALLEL_WAIT_SEC), take over the package status
    METHODS run_wave
      CHANGING
        ct_plans TYPE tt_plan
      RAISING
        zcx_cd_ops_error.

    "! Advance every source's watermark to the end of its last contiguous done package
    METHODS advance_watermarks
      CHANGING
        ct_plans TYPE tt_plan
      RAISING
        zcx_cd_ops_error.

    "! Payment documents of a change set: the documents, the statement references that are payment
    "! documents and the payment documents of the cheques referenced - without those already judged
    METHODS documents_of
      IMPORTING
        is_changes      TYPE zif_cd_ops_payout_types=>ty_changes
      RETURNING
        VALUE(rt_docno) TYPE zif_cd_ops_trace_types=>tt_docno.

    "! Payment requests of a change set without those already judged
    METHODS requests_of
      IMPORTING
        is_changes     TYPE zif_cd_ops_payout_types=>ty_changes
      RETURNING
        VALUE(rt_keys) TYPE zif_cd_ops_payout_types=>tt_req_key.

    "! Verdicts of the documents, judgements of the requests (also the requests of the judged payments'
    "! FIN numbers), every row of them: what to delete, close, update and insert
    METHODS judge
      IMPORTING
        it_docno            TYPE zif_cd_ops_trace_types=>tt_docno
        it_requests         TYPE zif_cd_ops_payout_types=>tt_req_key
      RETURNING
        VALUE(rs_judgement) TYPE ty_judgement
      RAISING
        zcx_cd_ops_error.

    "! Rows wanted for the verdicts: one per item FIN, source, company code; one with FIN and source
    "! blank for a payment without an item with a FIN; a clean verdict is a clean entity
    METHODS desired_versions
      IMPORTING
        is_evaluation    TYPE zif_cd_ops_payout_types=>ty_evaluation
        it_items         TYPE zif_cd_ops_payout_types=>tt_fin_item
        it_sources       TYPE zif_cd_ops_payout_types=>tt_fin_source
      RETURNING
        VALUE(rs_wanted) TYPE ty_wanted.

    "! Rows wanted for the requests: open (not yet due), not paid (exception), clean (paid on time,
    "! cancelled, no SUCCESS attempt) or closing (paid late)
    METHODS request_versions
      IMPORTING
        it_requests      TYPE zif_cd_ops_payout_types=>tt_request
      RETURNING
        VALUE(rs_wanted) TYPE ty_wanted.

    "! The row of a verdict on the template (keys): outcome, evidence, finding, the status marker, a late
    "! payment, the exception code of an inconsistent / undetermined / ambiguous outcome
    METHODS row_of
      IMPORTING
        is_template   TYPE zif_cd_ops_payout_types=>ty_version
        is_verdict    TYPE zif_cd_ops_payout_types=>ty_verdict
      RETURNING
        VALUE(rs_row) TYPE zif_cd_ops_payout_types=>ty_version.

    "! A payment in flight late beyond AMBER / RED of A_INFLIGHT (shared ageing rule): finding
    "! PAYMENT_NOT_CLEARED with W / E, unless the verdict already has a finding or the marker
    METHODS mark_late
      IMPORTING
        is_verdict TYPE zif_cd_ops_payout_types=>ty_verdict
      CHANGING
        cs_version TYPE zif_cd_ops_payout_types=>ty_version.

    "! An undetermined, inconsistent or ambiguous outcome is an exception: without a finding of the
    "! evaluator it gets the code A_INFLIGHT reports it under (the worklist's exception = a finding)
    CLASS-METHODS ensure_finding
      CHANGING
        cs_version TYPE zif_cd_ops_payout_types=>ty_version.

    "! The shared ageing rule with A_INFLIGHT's limits and calendar (once per run / unit)
    METHODS ageing
      RETURNING
        VALUE(ro_ageing) TYPE REF TO zcl_cd_hck_pay_ageing.

    "! First run of a source: PAYOUT_INITIAL_DAYS before today (statement: first line from then); SWEEP:
    "! the start of its date range; recheck and NIGHTLY cursors: from the first row
    METHODS initial_watermark
      IMPORTING
        iv_source           TYPE zif_cd_ops_payout_types=>ty_source_id
      RETURNING
        VALUE(rs_watermark) TYPE zif_cd_ops_payout_types=>ty_watermark.

    "! The watermark after a package with the instant up to which its source is processed: the run
    "! time when the source caught up, else the entry time of the watermark (system time zone), else
    "! (statement, recheck: no time) the instant kept from before
    METHODS processed_to
      IMPORTING
        is_watermark        TYPE zif_cd_ops_payout_types=>ty_watermark
        iv_more             TYPE abap_bool
        iv_before           TYPE timestampl
      RETURNING
        VALUE(rs_watermark) TYPE zif_cd_ops_payout_types=>ty_watermark.

    "! NIGHTLY / SWEEP stopped at PAYOUT_BATCH_MAX_PACKAGES with more to read: said once per source
    METHODS batch_stopped
      IMPORTING
        iv_source   TYPE zif_cd_ops_payout_types=>ty_source_id
        iv_packages TYPE i.

    "! One finding per flow + method class + finding code + run date of the versions with a finding
    "! written by this run (PAY_SOURCE_AMBIGUOUS): count of payments, first PAYOUT_EXAMPLES lines
    METHODS report_flagged
      IMPORTING
        it_flagged TYPE tt_flagged.

    "! Flow + method class of a method (DPAYH-PYMET) and flow indicator (TFK042Z-XEINZ)
    METHODS class_key
      IMPORTING
        iv_pymet      TYPE zif_cd_hck_runtime_types=>ty_pymet
        iv_xeinz      TYPE abap_bool
      RETURNING
        VALUE(rv_key) TYPE zif_cd_hck_runtime_types=>ty_flow_class.

    METHODS failure
      IMPORTING
        iv_source TYPE zif_cd_ops_payout_types=>ty_source_id
        iv_text   TYPE string.

    METHODS finish
      CHANGING
        cs_result TYPE ty_result
      RAISING
        zcx_cd_ops_error.

    METHODS release_lock.

    "! Entity of a row: the payment document, else FIN + source of the request
    CLASS-METHODS entity_of
      IMPORTING
        is_version       TYPE zif_cd_ops_payout_types=>ty_version
      RETURNING
        VALUE(rv_entity) TYPE string.

    "! Retire a current row: an exception version is closed, an open row deleted
    CLASS-METHODS retire
      IMPORTING
        is_row    TYPE zif_cd_ops_payout_types=>ty_version
        iv_now    TYPE zif_cd_ops_payout_types=>ty_timestamp
      CHANGING
        ct_close  TYPE zif_cd_ops_payout_types=>tt_version
        ct_delete TYPE zif_cd_ops_payout_types=>tt_version.

ENDCLASS.



CLASS zcl_cd_ops_pay_snapshot IMPLEMENTATION.

  METHOD run.
    DATA lv_holder TYPE syuname.
    ms_selection = is_selection.
    IF ms_selection-mode IS INITIAL.
      ms_selection-mode = zif_cd_ops_payout_types=>gc_mode-fast.
    ENDIF.
    IF iv_test_mode = abap_false.
      " An overlapping start of the same mode is refused (RUN_LOCKED), never run twice; the modes have
      " their own locks, so a nightly or sweep run never blocks the 5-minute FAST run
      IF zcl_cd_ops_factory=>get_lock( )->acquire( EXPORTING iv_pe_area = zif_cd_ops_types=>gc_pe_area-core
                                                             iv_variant = variant( )
                                                   IMPORTING ev_holder  = lv_holder ) = abap_false.
        DATA(ls_refusal) = zcl_cd_ops_run_guard=>refuse( iv_pe_area = zif_cd_ops_types=>gc_pe_area-core
                                                         iv_variant = variant( )
                                                         iv_holder  = lv_holder ).
        rs_result-run      = ls_refusal-run.
        rs_result-mode     = ms_selection-mode.
        rs_result-findings = ls_refusal-findings.
        RETURN.
      ENDIF.
    ENDIF.
    TRY.
        rs_result = execute( iv_test_mode ).
      CLEANUP.
        IF iv_test_mode = abap_false.
          release_lock( ).
        ENDIF.
    ENDTRY.
    IF iv_test_mode = abap_false.
      release_lock( ).
    ENDIF.
  ENDMETHOD.


  METHOD execute.
    CLEAR: mt_done, mt_req_done, mt_findings, mt_flagged, ms_config, mo_ageing.
    mv_test_mode = iv_test_mode.
    rs_result-mode = ms_selection-mode.
    mo_store   = zcl_cd_ops_factory=>get_store( ).
    mo_dao     = zcl_cd_ops_factory=>get_pay_outcome_dao( ).
    mo_outcome = zcl_cd_ops_factory=>get_pay_outcome( ).
    mo_request = zcl_cd_ops_factory=>get_pay_request( ).
    rs_result-run = mo_store->start_run( iv_pe_area   = zif_cd_ops_types=>gc_pe_area-core
                                         iv_variant   = variant( )
                                         iv_test_mode = iv_test_mode ).
    IF iv_test_mode = abap_false.
      mo_store->commit( ).
    ENDIF.
    mv_run_id = rs_result-run-run_id.
    mv_now = trunc( zcl_cd_ops_factory=>get_clock( )->now( ) ).
    read_parameters( ).
    IF selection_valid( ) = abap_false.
      finish( CHANGING cs_result = rs_result ).
      RETURN.
    ENDIF.
    TRY.
        mv_cap = zcl_cd_ops_pay_outcome=>evidence_cap( ).
        ms_config = mo_outcome->load( iv_context  = zif_cd_ops_payout_types=>gc_context
                                      iv_max_rows = mv_cap ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        " No configuration: nothing can be judged, nothing is written
        failure( iv_source = space iv_text = lx_error->get_text( ) ).
        finish( CHANGING cs_result = rs_result ).
        RETURN.
    ENDTRY.

    DATA(lt_watermarks) = mo_dao->get_watermarks( ).
    IF mv_parallel > 1 AND iv_test_mode = abap_false.
      rs_result-sources = process_parallel( lt_watermarks ).
    ELSE.
      LOOP AT sources( ms_selection ) ASSIGNING FIELD-SYMBOL(<lv_source>).
        DATA(lv_source) = CONV zif_cd_ops_payout_types=>ty_source_id( <lv_source> ).
        " SWEEP never starts from (or moves) a watermark: its range is its own
        DATA(ls_watermark) = COND #( WHEN ms_selection-mode <> zif_cd_ops_payout_types=>gc_mode-sweep
                                     THEN VALUE #( lt_watermarks[ source = lv_source ] OPTIONAL ) ).
        IF ls_watermark IS INITIAL.
          ls_watermark = initial_watermark( lv_source ).
        ENDIF.
        INSERT process_source( iv_source = lv_source is_watermark = ls_watermark ) INTO TABLE rs_result-sources.
      ENDLOOP.
      report_flagged( mt_flagged ).
    ENDIF.
    finish( CHANGING cs_result = rs_result ).
  ENDMETHOD.


  METHOD read_parameters.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    mv_package = nmax( val1 = 1
                       val2 = nmin( val1 = zcl_cd_ops_util=>param_int(
                                             io_params  = lo_params
                                             iv_name    = zif_cd_ops_payout_types=>gc_param-package_size
                                             iv_default = zif_cd_ops_payout_types=>gc_param_default-package_size )
                                    val2 = zif_cd_ops_payout_types=>gc_max_package ) ).
    " FAST is bounded per 5-minute run; NIGHTLY and SWEEP by their own, larger budget
    mv_max_packages = nmax( val1 = 1
                            val2 = COND #( WHEN ms_selection-mode = zif_cd_ops_payout_types=>gc_mode-fast
                                           THEN zcl_cd_ops_util=>param_int(
                                                  io_params  = lo_params
                                                  iv_name    = zif_cd_ops_payout_types=>gc_param-max_packages
                                                  iv_default = zif_cd_ops_payout_types=>gc_param_default-max_packages )
                                           ELSE zcl_cd_ops_util=>param_int(
                                                  io_params  = lo_params
                                                  iv_name    = zif_cd_ops_payout_types=>gc_param-batch_max_packages
                                                  iv_default = zif_cd_ops_payout_types=>gc_param_default-batch_max_packages ) ) ).
    mv_initial_days = nmax( val1 = 0
                            val2 = zcl_cd_ops_util=>param_int(
                                     io_params  = lo_params
                                     iv_name    = zif_cd_ops_payout_types=>gc_param-initial_days
                                     iv_default = zif_cd_ops_payout_types=>gc_param_default-initial_days ) ).
    mv_parallel = nmax( val1 = 1
                        val2 = nmin( val1 = zcl_cd_ops_util=>param_int(
                                              io_params  = lo_params
                                              iv_name    = zif_cd_ops_payout_types=>gc_param-parallel
                                              iv_default = zif_cd_ops_payout_types=>gc_param_default-parallel )
                                     val2 = zif_cd_ops_payout_types=>gc_max_parallel ) ).
    mv_wait_sec = nmax( val1 = zif_cd_ops_payout_types=>gc_poll_seconds
                        val2 = zcl_cd_ops_util=>param_int(
                                 io_params  = lo_params
                                 iv_name    = zif_cd_ops_payout_types=>gc_param-wait_sec
                                 iv_default = zif_cd_ops_payout_types=>gc_param_default-wait_sec ) ).
    mv_examples = nmax( val1 = 1
                        val2 = zcl_cd_ops_util=>param_int(
                                 io_params  = lo_params
                                 iv_name    = zif_cd_ops_payout_types=>gc_param-examples
                                 iv_default = zif_cd_ops_payout_types=>gc_param_default-examples ) ).
  ENDMETHOD.


  METHOD variant.
    rv_variant = SWITCH #( ms_selection-mode
                           WHEN zif_cd_ops_payout_types=>gc_mode-nightly THEN zif_cd_ops_payout_types=>gc_variant_nightly
                           WHEN zif_cd_ops_payout_types=>gc_mode-sweep   THEN zif_cd_ops_payout_types=>gc_variant_sweep
                           ELSE zif_cd_ops_payout_types=>gc_variant ).
  ENDMETHOD.


  METHOD selection_valid.
    rv_valid = abap_true.
    IF ms_selection-mode <> zif_cd_ops_payout_types=>gc_mode-sweep.
      RETURN.
    ENDIF.
    " Only the watermark sources with dated evidence can be swept (never the recheck or the cursors)
    DATA(lt_allowed) = sources( VALUE #( mode = zif_cd_ops_payout_types=>gc_mode-fast ) ).
    DELETE lt_allowed WHERE table_line = zif_cd_ops_payout_types=>gc_source-recheck.
    DATA(lv_bad) = xsdbool( ms_selection-date_from IS INITIAL OR ms_selection-date_to IS INITIAL
                            OR ms_selection-date_to < ms_selection-date_from OR ms_selection-sources IS INITIAL ).
    LOOP AT ms_selection-sources ASSIGNING FIELD-SYMBOL(<lv_source>).
      IF NOT line_exists( lt_allowed[ table_line = CONV string( <lv_source> ) ] ).
        lv_bad = abap_true.
      ENDIF.
    ENDLOOP.
    IF lv_bad = abap_false.
      RETURN.
    ENDIF.
    rv_valid = abap_false.
    failure( iv_source = space
             iv_text   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-sweep_selection
                                                iv_v1    = concat_lines_of( table = lt_allowed sep = `, ` ) ) ).
  ENDMETHOD.


  METHOD changes.
    DATA(lv_to) = COND d( WHEN ms_selection-mode = zif_cd_ops_payout_types=>gc_mode-sweep THEN ms_selection-date_to ).
    IF iv_source = zif_cd_ops_payout_types=>gc_source-requests.
      rs_changes = mo_request->changes( is_watermark = is_watermark
                                        iv_max       = mv_package
                                        iv_to        = lv_to ).
    ELSE.
      rs_changes = mo_dao->get_changes( iv_source    = iv_source
                                        is_watermark = is_watermark
                                        iv_max       = mv_package
                                        iv_to        = lv_to ).
    ENDIF.
    rs_changes-watermark-source     = iv_source.
    rs_changes-watermark-updated_at = mv_now.
    rs_changes-watermark-last_rows  = lines( rs_changes-docno ) + lines( rs_changes-refs ) + lines( rs_changes-requests ).
    rs_changes-watermark = processed_to( is_watermark = rs_changes-watermark
                                         iv_more      = rs_changes-more
                                         iv_before    = is_watermark-current_to ).
  ENDMETHOD.


  METHOD process_source.
    rs_result-source = iv_source.
    DATA(ls_watermark) = is_watermark.
    DO mv_max_packages TIMES.
      TRY.
          DATA(ls_changes) = changes( iv_source = iv_source is_watermark = ls_watermark ).
          process_package( EXPORTING is_changes = ls_changes
                           CHANGING  cs_result  = rs_result ).
        CATCH zcx_cd_ops_error INTO DATA(lx_error).
          " Fail closed: nothing of the package is written, the watermark stays; the next run retries
          mo_store->rollback( ).
          failure( iv_source = iv_source iv_text = lx_error->get_text( ) ).
          RETURN.
      ENDTRY.
      rs_result-packages = rs_result-packages + 1.
      ls_watermark = ls_changes-watermark.
      rs_result-more = ls_changes-more.
      IF ls_changes-more = abap_false.
        RETURN.
      ENDIF.
    ENDDO.
    batch_stopped( iv_source = iv_source iv_packages = rs_result-packages ).
  ENDMETHOD.


  METHOD process_package.
    DATA(lt_judged) = documents_of( is_changes ).
    DATA(lt_requests) = requests_of( is_changes ).
    cs_result-documents = cs_result-documents + lines( lt_judged ) + lines( lt_requests ).
    IF lt_judged IS NOT INITIAL OR lt_requests IS NOT INITIAL.
      DATA(ls_judgement) = judge( it_docno = lt_judged it_requests = lt_requests ).
      cs_result-evaluated = cs_result-evaluated + ls_judgement-evaluated.
      cs_result-closed    = cs_result-closed + lines( ls_judgement-close ) + lines( ls_judgement-delete ).
      cs_result-inserted  = cs_result-inserted + lines( ls_judgement-insert ) + lines( ls_judgement-update ).
      INSERT LINES OF ls_judgement-flagged INTO TABLE mt_flagged.
      INSERT LINES OF lt_judged INTO TABLE mt_done.
      INSERT LINES OF lt_requests INTO TABLE mt_req_done.
    ENDIF.

    IF mv_test_mode = abap_true.
      RETURN.
    ENDIF.
    " Rows and watermark of the package are durable together (SWEEP moves no watermark)
    IF lt_judged IS NOT INITIAL OR lt_requests IS NOT INITIAL.
      mo_dao->save_versions( it_close  = ls_judgement-close
                             it_insert = ls_judgement-insert
                             it_delete = ls_judgement-delete
                             it_update = ls_judgement-update ).
    ENDIF.
    IF ms_selection-mode <> zif_cd_ops_payout_types=>gc_mode-sweep.
      mo_dao->save_watermark( is_changes-watermark ).
    ENDIF.
    mo_store->commit( ).
  ENDMETHOD.


  METHOD documents_of.
    DATA lt_docno TYPE zif_cd_ops_trace_types=>tt_docno.
    " Statement references are payment documents (methods E G H I J K L) or cheque numbers
    lt_docno = is_changes-docno.
    LOOP AT is_changes-refs ASSIGNING FIELD-SYMBOL(<lv_ref>).
      IF strlen( condense( CONV string( <lv_ref> ) ) ) <= zif_cd_ops_payout_types=>gc_docno_length.
        INSERT CONV #( <lv_ref> ) INTO TABLE lt_docno.
      ENDIF.
    ENDLOOP.
    INSERT LINES OF mo_dao->get_cheque_documents( is_changes-refs ) INTO TABLE lt_docno.
    LOOP AT lt_docno ASSIGNING FIELD-SYMBOL(<lv_docno>).
      IF NOT line_exists( mt_done[ table_line = <lv_docno> ] ).
        INSERT <lv_docno> INTO TABLE rt_docno.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD requests_of.
    LOOP AT is_changes-requests ASSIGNING FIELD-SYMBOL(<ls_key>).
      IF NOT line_exists( mt_req_done[ fin = <ls_key>-fin source = <ls_key>-source ] ).
        INSERT <ls_key> INTO TABLE rt_keys.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD judge.
    DATA lt_fin TYPE zif_cd_ops_payout_types=>tt_fin.
    DATA lt_desired_docs TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA ls_wanted TYPE ty_wanted.
    DATA lt_rows TYPE zif_cd_ops_payout_types=>tt_version.
    rs_judgement-documents = lines( it_docno ) + lines( it_requests ).
    DATA(lt_requests) = it_requests.

    IF it_docno IS NOT INITIAL.
      DATA(ls_evaluation) = mo_outcome->evaluate_documents( it_docno ).
      " A capped evidence read could hide evidence: the package is not judged (fail closed)
      READ TABLE ls_evaluation-findings ASSIGNING FIELD-SYMBOL(<ls_capped>)
           WITH KEY check_code = zif_cd_hck_runtime_types=>gc_code-read_capped.
      IF sy-subrc = 0.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e379(zcd_ops) WITH <ls_capped>-object_key mv_cap zif_cd_ops_payout_types=>gc_context.
      ENDIF.
      rs_judgement-evaluated = lines( ls_evaluation-verdicts ).
      LOOP AT ls_evaluation-verdicts ASSIGNING FIELD-SYMBOL(<ls_verdict>).
        INSERT <ls_verdict>-doc1r INTO TABLE lt_desired_docs.
      ENDLOOP.
    ENDIF.
    IF lt_desired_docs IS NOT INITIAL.
      DATA(lt_items) = mo_dao->get_fin_items( lt_desired_docs ).
      LOOP AT lt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
        INSERT <ls_item>-fin INTO TABLE lt_fin.
      ENDLOOP.
      ls_wanted = desired_versions( is_evaluation = ls_evaluation
                                    it_items      = lt_items
                                    it_sources    = mo_outcome->sources_of( lt_fin ) ).
      " Every row of the judged payment documents, every FIN and source (index DOC)
      lt_rows = mo_dao->get_versions( lt_desired_docs ).
      " A request of a FIN just paid leaves the worklist in the same run (paid on time: clean)
      LOOP AT mo_dao->get_request_keys( lt_fin ) ASSIGNING FIELD-SYMBOL(<ls_paid_key>).
        IF NOT line_exists( mt_req_done[ fin = <ls_paid_key>-fin source = <ls_paid_key>-source ] ).
          INSERT <ls_paid_key> INTO TABLE lt_requests.
        ENDIF.
      ENDLOOP.
    ENDIF.

    IF lt_requests IS NOT INITIAL.
      DATA(ls_req_wanted) = request_versions( mo_request->evaluate( it_keys = lt_requests iv_now = mv_now ) ).
      rs_judgement-evaluated = rs_judgement-evaluated + lines( lt_requests ).
      INSERT LINES OF ls_req_wanted-desired INTO TABLE ls_wanted-desired.
      INSERT LINES OF ls_req_wanted-clean INTO TABLE ls_wanted-clean.
      INSERT LINES OF mo_dao->get_request_versions( lt_requests ) INTO TABLE lt_rows.
    ENDIF.
    IF ls_wanted IS INITIAL.
      RETURN.
    ENDIF.

    plan_worklist( EXPORTING it_desired = ls_wanted-desired
                             it_clean   = ls_wanted-clean
                             it_rows    = lt_rows
                             iv_now     = mv_now
                   IMPORTING et_close   = rs_judgement-close
                             et_insert  = rs_judgement-insert
                             et_delete  = rs_judgement-delete
                             et_update  = rs_judgement-update ).
    LOOP AT rs_judgement-insert ASSIGNING FIELD-SYMBOL(<ls_new>)
         WHERE finding = zif_cd_ops_payout_types=>gc_code-source_ambiguous.
      READ TABLE ls_evaluation-verdicts ASSIGNING <ls_verdict> WITH KEY by_doc COMPONENTS doc1r = <ls_new>-augbl.
      IF sy-subrc = 0.
        INSERT VALUE #( version = <ls_new>
                        key     = |{ <ls_verdict>-flow }{ <ls_verdict>-class }| ) INTO TABLE rs_judgement-flagged.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD desired_versions.
    DATA lt_rows TYPE zif_cd_ops_payout_types=>tt_version.
    DATA(lt_final) = zcl_cd_ops_pay_outcome=>final_outcomes( ).
    LOOP AT is_evaluation-verdicts ASSIGNING FIELD-SYMBOL(<ls_verdict>).
      CLEAR lt_rows.
      DATA(ls_template) = VALUE zif_cd_ops_payout_types=>ty_version(
                            augbl         = <ls_verdict>-doc1r
                            laufd         = <ls_verdict>-laufd
                            laufi         = <ls_verdict>-laufi
                            valid_from    = mv_now
                            valid_to      = zif_cd_ops_payout_types=>gc_valid_to_open
                            evaluated_at  = mv_now
                            flow_class    = |{ <ls_verdict>-flow }{ <ls_verdict>-class }| ).
      DATA(lv_items) = 0.
      LOOP AT it_items ASSIGNING FIELD-SYMBOL(<ls_item>) WHERE augbl = <ls_verdict>-doc1r.
        lv_items = lv_items + 1.
        LOOP AT it_sources ASSIGNING FIELD-SYMBOL(<ls_source>) WHERE fin = <ls_item>-fin.
          " The source attribution: a FIN in two sources is AMBIGUOUS for each (never clean)
          DATA(ls_verdict) = mo_outcome->for_source( is_verdict = <ls_verdict> is_source = <ls_source> ).
          DATA(ls_version) = ls_template.
          ls_version-fin_id = <ls_item>-fin.
          ls_version-source = <ls_source>-source.
          ls_version-bukrs  = <ls_item>-bukrs.
          INSERT row_of( is_template = ls_version is_verdict = ls_verdict ) INTO TABLE lt_rows.
        ENDLOOP.
      ENDLOOP.
      IF lv_items = 0.
        " A payment without an item with a FIN (e.g. a collection): one row, FIN and source blank
        ls_version = ls_template.
        ls_version-bukrs = <ls_verdict>-bukrs.
        INSERT row_of( is_template = ls_version is_verdict = <ls_verdict> ) INTO TABLE lt_rows.
      ENDIF.
      " A final, clean outcome of every row (the money movement is decided, the evidence agrees, no
      " finding): no row - the payment's open row is deleted, an exception closes (user decision 2026-11-08)
      DATA(lv_clean) = abap_true.
      LOOP AT lt_rows TRANSPORTING NO FIELDS WHERE finding IS NOT INITIAL OR outcome NOT IN lt_final.
        lv_clean = abap_false.
        EXIT.
      ENDLOOP.
      IF lv_clean = abap_true.
        DATA(ls_clean) = ls_template.
        ls_clean-bukrs         = <ls_verdict>-bukrs.
        ls_clean-outcome       = <ls_verdict>-outcome.
        ls_clean-evidence_kind = <ls_verdict>-evidence_kind.
        ls_clean-evidence_ref  = <ls_verdict>-evidence_ref.
        INSERT ls_clean INTO TABLE rs_wanted-clean.
        CONTINUE.
      ENDIF.
      INSERT LINES OF lt_rows INTO TABLE rs_wanted-desired.
    ENDLOOP.
  ENDMETHOD.


  METHOD row_of.
    rs_row = is_template.
    rs_row-laufd         = is_verdict-laufd.
    rs_row-laufi         = is_verdict-laufi.
    rs_row-outcome       = is_verdict-outcome.
    rs_row-evidence_kind = is_verdict-evidence_kind.
    rs_row-evidence_ref  = is_verdict-evidence_ref.
    rs_row-finding       = is_verdict-finding.
    rs_row-severity      = is_verdict-severity.
    " The bank evidence decides, the status job has not followed: in flight with the marker (the
    " morning report's PAY_STATUS_LAG counts the grace from VALID_FROM of this version)
    IF is_verdict-status_pending = abap_true AND is_verdict-finding IS INITIAL.
      rs_row-finding = zif_cd_ops_payout_types=>gc_code-status_pending.
    ENDIF.
    mark_late( EXPORTING is_verdict = is_verdict
               CHANGING  cs_version = rs_row ).
    ensure_finding( CHANGING cs_version = rs_row ).
  ENDMETHOD.


  METHOD mark_late.
    " Only a payment in flight without a finding of its own is aged here (undetermined, inconsistent,
    " ambiguous and the status marker are exceptions already)
    IF is_verdict-status <> zif_cd_ops_payout_types=>gc_status-open OR cs_version-finding IS NOT INITIAL
       OR is_verdict-outcome <> zif_cd_ops_payout_types=>gc_outcome-in_flight.
      RETURN.
    ENDIF.
    DATA(ls_age) = ageing( )->age_of( iv_key   = |{ is_verdict-flow }{ is_verdict-class }|
                                      iv_laufd = is_verdict-laufd
                                      iv_valut = is_verdict-valut
                                      iv_hbkid = is_verdict-hbkid ).
    CASE ls_age-rag.
      WHEN zif_cd_ops_types=>gc_rag-red.
        cs_version-finding  = zif_cd_hck_runtime_types=>gc_code-payment_not_clear.
        cs_version-severity = zif_cd_ops_types=>gc_severity-error.
      WHEN zif_cd_ops_types=>gc_rag-amber.
        cs_version-finding  = zif_cd_hck_runtime_types=>gc_code-payment_not_clear.
        cs_version-severity = zif_cd_ops_types=>gc_severity-warning.
    ENDCASE.
  ENDMETHOD.


  METHOD ensure_finding.
    IF cs_version-finding IS NOT INITIAL.
      RETURN.
    ENDIF.
    CASE cs_version-outcome.
      WHEN zif_cd_ops_payout_types=>gc_outcome-inconsistent.
        cs_version-finding  = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist.
        cs_version-severity = zif_cd_ops_types=>gc_severity-error.
      WHEN zif_cd_ops_payout_types=>gc_outcome-undetermined.
        cs_version-finding  = zif_cd_hck_runtime_types=>gc_code-undetermined.
        cs_version-severity = zif_cd_ops_types=>gc_severity-warning.
      WHEN zif_cd_ops_payout_types=>gc_outcome-ambiguous.
        cs_version-finding  = zif_cd_ops_payout_types=>gc_code-source_ambiguous.
        cs_version-severity = zif_cd_ops_types=>gc_severity-warning.
    ENDCASE.
  ENDMETHOD.


  METHOD ageing.
    IF mo_ageing IS NOT BOUND.
      " A_INFLIGHT's AGE_OLDEST limits and default calendar (PARAM1): one definition of "late"
      DATA(lo_hck) = zcl_cd_hck_factory=>get_dao( ).
      DATA(lt_defs) = lo_hck->get_check_defs(
                        it_check_ids = VALUE #( ( sign   = zif_cd_ops_types=>gc_range-sign_include
                                                  option = zif_cd_ops_types=>gc_range-option_equal
                                                  low    = zif_cd_ops_payout_types=>gc_check-inflight ) ) ).
      mo_ageing = NEW #( it_classes    = ms_config-classes
                         it_banks      = ms_config-banks
                         it_watched    = ms_config-watched
                         iv_calendar   = VALUE #( lt_defs[ 1 ]-param1 OPTIONAL )
                         it_thresholds = lo_hck->get_thresholds( zif_cd_ops_payout_types=>gc_check-inflight )
                         iv_today      = zcl_cd_ops_factory=>get_clock( )->today( ) ).
    ENDIF.
    ro_ageing = mo_ageing.
  ENDMETHOD.


  METHOD request_versions.
    LOOP AT it_requests ASSIGNING FIELD-SYMBOL(<ls_request>).
      DATA(ls_row) = VALUE zif_cd_ops_payout_types=>ty_version(
                       fin_id        = <ls_request>-fin
                       source        = <ls_request>-source
                       valid_from    = mv_now
                       valid_to      = zif_cd_ops_payout_types=>gc_valid_to_open
                       evidence_kind = <ls_request>-stage
                       evidence_ref  = <ls_request>-text
                       evaluated_at  = mv_now
                       due_date      = <ls_request>-due_date ).
      IF <ls_request>-stage = zif_cd_ops_payout_types=>gc_req_stage-paid_late.
        " Paid after the due date: finished, but the exception is history for 90 days (a closing version
        " even when no nightly marked it before the payment came)
        ls_row-outcome  = zif_cd_ops_payout_types=>gc_outcome-req_paid_late.
        ls_row-finding  = zif_cd_ops_payout_types=>gc_code-request_not_paid.
        ls_row-severity = zif_cd_ops_types=>gc_severity-error.
        INSERT ls_row INTO TABLE rs_wanted-clean.
        CONTINUE.
      ENDIF.
      IF <ls_request>-finished = abap_true.
        " Paid on time, cancelled after SUCCESS, no SUCCESS attempt: no row
        ls_row-outcome = zif_cd_ops_payout_types=>gc_outcome-req_open.
        INSERT ls_row INTO TABLE rs_wanted-clean.
        CONTINUE.
      ENDIF.
      IF <ls_request>-overdue = abap_true.
        " Not paid in a payment run by the end of the due date: RED from the morning after
        ls_row-outcome  = zif_cd_ops_payout_types=>gc_outcome-req_not_paid.
        ls_row-finding  = zif_cd_ops_payout_types=>gc_code-request_not_paid.
        ls_row-severity = zif_cd_ops_types=>gc_severity-error.
      ELSE.
        ls_row-outcome = zif_cd_ops_payout_types=>gc_outcome-req_open.
      ENDIF.
      INSERT ls_row INTO TABLE rs_wanted-desired.
    ENDLOOP.
  ENDMETHOD.


  METHOD plan_worklist.
    DATA lt_rows TYPE tt_keyed.
    DATA lt_desired TYPE tt_keyed.
    DATA lt_clean TYPE tt_keyed.
    DATA lt_entities TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.
    CLEAR: et_close, et_insert, et_delete, et_update.
    " Every row keyed by its entity once (payment document, or FIN + source of a request)
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      INSERT VALUE #( entity = entity_of( <ls_row> ) row = <ls_row> ) INTO TABLE lt_rows.
    ENDLOOP.
    LOOP AT it_desired ASSIGNING FIELD-SYMBOL(<ls_wanted>).
      INSERT VALUE #( entity = entity_of( <ls_wanted> ) row = <ls_wanted> ) INTO TABLE lt_desired.
      INSERT entity_of( <ls_wanted> ) INTO TABLE lt_entities.
    ENDLOOP.
    LOOP AT it_clean ASSIGNING FIELD-SYMBOL(<ls_clean_row>).
      INSERT VALUE #( entity = entity_of( <ls_clean_row> ) row = <ls_clean_row> ) INTO TABLE lt_clean.
      INSERT entity_of( <ls_clean_row> ) INTO TABLE lt_entities.
    ENDLOOP.

    LOOP AT lt_entities ASSIGNING FIELD-SYMBOL(<lv_entity>).
      " Current rows of the entity, newest first: an older duplicate of a key (a concurrent run) is retired
      DATA(lt_current) = VALUE zif_cd_ops_payout_types=>tt_version( ).
      DATA(lv_history) = abap_false.
      LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_keyed>) WHERE entity = <lv_entity>.
        IF <ls_keyed>-row-finding IS NOT INITIAL OR <ls_keyed>-row-valid_to <> zif_cd_ops_payout_types=>gc_valid_to_open.
          lv_history = abap_true.
        ENDIF.
        IF <ls_keyed>-row-valid_to = zif_cd_ops_payout_types=>gc_valid_to_open.
          INSERT <ls_keyed>-row INTO TABLE lt_current.
        ENDIF.
      ENDLOOP.
      SORT lt_current BY fin_id source bukrs augbl laufd laufi valid_from DESCENDING.

      READ TABLE lt_clean ASSIGNING FIELD-SYMBOL(<ls_clean>) WITH TABLE KEY entity = <lv_entity>.
      IF sy-subrc = 0.
        " A clean entity that is itself an exception that closes (a request paid late) has history too
        IF <ls_clean>-row-finding IS NOT INITIAL.
          lv_history = abap_true.
        ENDIF.
        IF lv_history = abap_false.
          " No history for a clean payment: its open rows go (user decision 2026-11-08)
          INSERT LINES OF lt_current INTO TABLE et_delete.
          CONTINUE.
        ENDIF.
        " The exception closes: the current rows end now, a closing version per key records the outcome
        DATA(lt_keys) = lt_current.
        IF lt_keys IS INITIAL.
          INSERT <ls_clean>-row INTO TABLE lt_keys.
        ENDIF.
        LOOP AT lt_current ASSIGNING FIELD-SYMBOL(<ls_current>).
          DATA(ls_close) = <ls_current>.
          ls_close-valid_to = iv_now.
          INSERT ls_close INTO TABLE et_close.
        ENDLOOP.
        SORT lt_keys BY fin_id source bukrs augbl laufd laufi.
        DELETE ADJACENT DUPLICATES FROM lt_keys COMPARING fin_id source bukrs augbl laufd laufi.
        LOOP AT lt_keys ASSIGNING FIELD-SYMBOL(<ls_key>).
          DATA(ls_closing) = <ls_clean>-row.
          ls_closing-fin_id     = <ls_key>-fin_id.
          ls_closing-source     = <ls_key>-source.
          ls_closing-bukrs      = <ls_key>-bukrs.
          ls_closing-augbl      = <ls_key>-augbl.
          ls_closing-laufd      = <ls_key>-laufd.
          ls_closing-laufi      = <ls_key>-laufi.
          ls_closing-valid_from = iv_now.
          ls_closing-valid_to   = iv_now.
          INSERT ls_closing INTO TABLE et_insert.
        ENDLOOP.
        CONTINUE.
      ENDIF.

      LOOP AT lt_desired ASSIGNING FIELD-SYMBOL(<ls_desired>) WHERE entity = <lv_entity>.
        DATA(lv_first) = abap_true.
        DATA(ls_found) = VALUE zif_cd_ops_payout_types=>ty_version( ).
        LOOP AT lt_current ASSIGNING <ls_current>
             WHERE fin_id = <ls_desired>-row-fin_id AND source = <ls_desired>-row-source
               AND bukrs = <ls_desired>-row-bukrs AND augbl = <ls_desired>-row-augbl
               AND laufd = <ls_desired>-row-laufd AND laufi = <ls_desired>-row-laufi.
          IF lv_first = abap_true.
            ls_found = <ls_current>.
            lv_first = abap_false.
          ELSE.
            retire( EXPORTING is_row = <ls_current> iv_now = iv_now
                    CHANGING  ct_close = et_close ct_delete = et_delete ).
          ENDIF.
        ENDLOOP.
        IF lv_first = abap_true.
          INSERT <ls_desired>-row INTO TABLE et_insert.
          CONTINUE.
        ENDIF.
        " No change of what the worklist shows: nothing is written (not even the evaluation time)
        IF ls_found-outcome = <ls_desired>-row-outcome AND ls_found-finding = <ls_desired>-row-finding
           AND ls_found-severity = <ls_desired>-row-severity
           AND ls_found-evidence_kind = <ls_desired>-row-evidence_kind
           AND ls_found-flow_class = <ls_desired>-row-flow_class AND ls_found-due_date = <ls_desired>-row-due_date.
          CONTINUE.
        ENDIF.
        IF ls_found-finding IS INITIAL AND <ls_desired>-row-finding IS INITIAL.
          " Open stays open: one row, changed in place (it keeps the instant it was first seen)
          DATA(ls_update) = <ls_desired>-row.
          ls_update-valid_from = ls_found-valid_from.
          INSERT ls_update INTO TABLE et_update.
          CONTINUE.
        ENDIF.
        retire( EXPORTING is_row = ls_found iv_now = iv_now
                CHANGING  ct_close = et_close ct_delete = et_delete ).
        INSERT <ls_desired>-row INTO TABLE et_insert.
      ENDLOOP.

      " A current row of the entity that is no longer wanted (newer payment run, other source attribution)
      LOOP AT lt_current ASSIGNING <ls_current>.
        DATA(lv_wanted) = abap_false.
        LOOP AT lt_desired ASSIGNING <ls_desired> WHERE entity = <lv_entity>.
          IF <ls_desired>-row-fin_id = <ls_current>-fin_id AND <ls_desired>-row-source = <ls_current>-source
             AND <ls_desired>-row-bukrs = <ls_current>-bukrs AND <ls_desired>-row-augbl = <ls_current>-augbl
             AND <ls_desired>-row-laufd = <ls_current>-laufd AND <ls_desired>-row-laufi = <ls_current>-laufi.
            lv_wanted = abap_true.
            EXIT.
          ENDIF.
        ENDLOOP.
        IF lv_wanted = abap_false.
          retire( EXPORTING is_row = <ls_current> iv_now = iv_now
                  CHANGING  ct_close = et_close ct_delete = et_delete ).
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD retire.
    IF is_row-finding IS INITIAL.
      INSERT is_row INTO TABLE ct_delete.
      RETURN.
    ENDIF.
    DATA(ls_close) = is_row.
    ls_close-valid_to = iv_now.
    INSERT ls_close INTO TABLE ct_close.
  ENDMETHOD.


  METHOD entity_of.
    rv_entity = COND #( WHEN is_version-augbl IS NOT INITIAL THEN |{ is_version-augbl }|
                        ELSE |{ zif_cd_ops_trace_types=>gc_key_sep }{ is_version-fin_id }| &&
                             |{ zif_cd_ops_trace_types=>gc_key_sep }{ is_version-source }| ).
  ENDMETHOD.


  METHOD process_parallel.
    DATA lt_plans TYPE tt_plan.
    DATA lt_mode_sources TYPE zif_cd_ops_payout_types=>tt_source_id.
    LOOP AT sources( ms_selection ) ASSIGNING FIELD-SYMBOL(<lv_mode_source>).
      INSERT CONV #( <lv_mode_source> ) INTO TABLE lt_mode_sources.
    ENDLOOP.
    " Packages of earlier runs of this mode are history (its run lock is held): only this run's rows stay
    IF mo_dao->delete_packages( iv_keep_run_id = mv_run_id it_sources = lt_mode_sources ) > 0.
      mo_store->commit( ).
    ENDIF.
    LOOP AT sources( ms_selection ) ASSIGNING FIELD-SYMBOL(<lv_source>).
      DATA(lv_source) = CONV zif_cd_ops_payout_types=>ty_source_id( <lv_source> ).
      DATA(ls_watermark) = COND #( WHEN ms_selection-mode <> zif_cd_ops_payout_types=>gc_mode-sweep
                                   THEN VALUE #( it_watermarks[ source = lv_source ] OPTIONAL ) ).
      IF ls_watermark IS INITIAL.
        ls_watermark = initial_watermark( lv_source ).
      ENDIF.
      INSERT VALUE #( source = lv_source ) INTO TABLE rt_results.
      INSERT LINES OF plan_source( iv_source = lv_source is_watermark = ls_watermark ) INTO TABLE lt_plans.
    ENDLOOP.

    " Waves of PAYOUT_PARALLEL units until every package ran (or its source failed before it)
    WHILE line_exists( lt_plans[ package-status = zif_cd_ops_payout_types=>gc_pkg_status-planned ] ).
      run_wave( CHANGING ct_plans = lt_plans ).
      advance_watermarks( CHANGING ct_plans = lt_plans ).
    ENDWHILE.

    LOOP AT rt_results ASSIGNING FIELD-SYMBOL(<ls_result>).
      LOOP AT lt_plans ASSIGNING FIELD-SYMBOL(<ls_plan>) WHERE package-source = <ls_result>-source.
        <ls_result>-documents = <ls_result>-documents + lines( <ls_plan>-package-docno )
                                                      + lines( <ls_plan>-package-requests ).
        <ls_result>-evaluated = <ls_result>-evaluated + <ls_plan>-package-evaluated.
        <ls_result>-inserted  = <ls_result>-inserted + <ls_plan>-package-inserted.
        <ls_result>-closed    = <ls_result>-closed + <ls_plan>-package-closed.
        IF <ls_plan>-applied = abap_true
           OR ( ms_selection-mode = zif_cd_ops_payout_types=>gc_mode-sweep
                AND <ls_plan>-package-status = zif_cd_ops_payout_types=>gc_pkg_status-done ).
          <ls_result>-packages = <ls_result>-packages + 1.
          <ls_result>-more     = <ls_plan>-more.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    " Findings of the versions the units wrote: from the database (the units ran in other sessions)
    DATA(lt_flagged) = VALUE tt_flagged( ).
    LOOP AT mo_dao->get_new_versions( iv_valid_from = mv_now
                                      iv_finding    = zif_cd_ops_payout_types=>gc_code-source_ambiguous )
         ASSIGNING FIELD-SYMBOL(<ls_new>).
      INSERT VALUE #( version = <ls_new>-version
                      key     = class_key( iv_pymet = <ls_new>-pymet iv_xeinz = <ls_new>-xeinz ) ) INTO TABLE lt_flagged.
    ENDLOOP.
    report_flagged( lt_flagged ).
  ENDMETHOD.


  METHOD plan_source.
    DATA(ls_watermark) = is_watermark.
    DO mv_max_packages TIMES.
      TRY.
          DATA(ls_changes) = changes( iv_source = iv_source is_watermark = ls_watermark ).
        CATCH zcx_cd_ops_error INTO DATA(lx_error).
          " The source cannot be read: its later packages are not planned, the watermark stays
          failure( iv_source = iv_source iv_text = lx_error->get_text( ) ).
          RETURN.
      ENDTRY.
      DATA(ls_plan) = VALUE ty_plan( package-run_id   = mv_run_id
                                     package-source   = iv_source
                                     package-pkg_no   = sy-index
                                     package-status   = zif_cd_ops_payout_types=>gc_pkg_status-planned
                                     package-docno    = documents_of( ls_changes )
                                     package-requests = requests_of( ls_changes )
                                     watermark        = ls_changes-watermark
                                     more             = ls_changes-more ).
      INSERT LINES OF ls_plan-package-docno INTO TABLE mt_done.
      INSERT LINES OF ls_plan-package-requests INTO TABLE mt_req_done.
      INSERT ls_plan INTO TABLE rt_plans.
      ls_watermark = ls_changes-watermark.
      IF ls_changes-more = abap_false.
        RETURN.
      ENDIF.
    ENDDO.
    batch_stopped( iv_source = iv_source iv_packages = mv_max_packages ).
  ENDMETHOD.


  METHOD run_wave.
    DATA lt_wave TYPE zif_cd_ops_payout_types=>tt_package.
    DATA lt_failed TYPE SORTED TABLE OF zif_cd_ops_payout_types=>ty_source_id WITH UNIQUE KEY table_line.
    " A source with a failed package is not continued in this run (its watermark cannot pass it)
    LOOP AT ct_plans ASSIGNING FIELD-SYMBOL(<ls_plan>)
         WHERE package-status = zif_cd_ops_payout_types=>gc_pkg_status-failed
            OR package-status = zif_cd_ops_payout_types=>gc_pkg_status-abandoned.
      INSERT <ls_plan>-package-source INTO TABLE lt_failed.
    ENDLOOP.
    LOOP AT ct_plans ASSIGNING <ls_plan> WHERE package-status = zif_cd_ops_payout_types=>gc_pkg_status-planned.
      IF line_exists( lt_failed[ table_line = <ls_plan>-package-source ] ).
        <ls_plan>-package-status = zif_cd_ops_payout_types=>gc_pkg_status-abandoned.
        CONTINUE.
      ENDIF.
      " A package without documents and requests moves only its watermark: done without a unit
      IF <ls_plan>-package-docno IS INITIAL AND <ls_plan>-package-requests IS INITIAL.
        <ls_plan>-package-status = zif_cd_ops_payout_types=>gc_pkg_status-done.
        CONTINUE.
      ENDIF.
      <ls_plan>-package-run_at = mv_now.
      INSERT <ls_plan>-package INTO TABLE lt_wave.
      IF lines( lt_wave ) >= mv_parallel.
        EXIT.
      ENDIF.
    ENDLOOP.
    IF lt_wave IS INITIAL.
      RETURN.
    ENDIF.

    mo_dao->save_packages( lt_wave ).
    DATA(lo_queue) = zcl_cd_ops_factory=>get_pay_snap_queue( ).
    LOOP AT lt_wave ASSIGNING FIELD-SYMBOL(<ls_package>).
      TRY.
          lo_queue->dispatch( <ls_package> ).
        CATCH zcx_cd_ops_error INTO DATA(lx_error).
          " bgPF not available: the package is judged here, one by one (said once per run)
          IF NOT line_exists( mt_findings[ check_code = zif_cd_ops_payout_types=>gc_code-parallel_off ] ).
            INSERT VALUE #( object_type = zif_cd_ops_payout_types=>gc_object_type
                            object_key  = |{ zif_cd_ops_payout_types=>gc_context }/| &&
                                          |{ zif_cd_ops_payout_types=>gc_code-parallel_off }|
                            check_code  = zif_cd_ops_payout_types=>gc_code-parallel_off
                            severity    = zif_cd_ops_types=>gc_severity-warning
                            action      = zif_cd_ops_types=>gc_action-notify
                            message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-parallel_off
                                                                 iv_tail  = lx_error->get_text( ) ) ) INTO TABLE mt_findings.
          ENDIF.
          mo_store->commit( ).
          run_package( <ls_package> ).
      ENDTRY.
    ENDLOOP.
    " The units start with this commit
    mo_store->commit( ).

    " Wait for the wave; packages still planned after PAYOUT_PARALLEL_WAIT_SEC are abandoned (a unit
    " that has claimed its row finishes first: the claim locks the row)
    DATA(lv_waited) = 0.
    DO.
      DATA(lt_rows) = mo_dao->get_packages( mv_run_id ).
      DATA(lv_open) = abap_false.
      LOOP AT lt_wave ASSIGNING <ls_package>.
        IF VALUE #( lt_rows[ source = <ls_package>-source pkg_no = <ls_package>-pkg_no ]-status OPTIONAL )
           = zif_cd_ops_payout_types=>gc_pkg_status-planned.
          lv_open = abap_true.
        ENDIF.
      ENDLOOP.
      IF lv_open = abap_false.
        EXIT.
      ENDIF.
      IF lv_waited >= mv_wait_sec.
        IF mo_dao->abandon_packages( mv_run_id ) > 0.
          mo_store->commit( ).
        ENDIF.
        lt_rows = mo_dao->get_packages( mv_run_id ).
        EXIT.
      ENDIF.
      lo_queue->pause( zif_cd_ops_payout_types=>gc_poll_seconds ).
      lv_waited = lv_waited + zif_cd_ops_payout_types=>gc_poll_seconds.
    ENDDO.

    LOOP AT lt_wave ASSIGNING <ls_package>.
      DATA(ls_row) = VALUE #( lt_rows[ source = <ls_package>-source pkg_no = <ls_package>-pkg_no ] OPTIONAL ).
      READ TABLE ct_plans ASSIGNING <ls_plan>
           WITH KEY package-source = <ls_package>-source package-pkg_no = <ls_package>-pkg_no.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      <ls_plan>-package-status    = COND #( WHEN ls_row-status IS INITIAL
                                              OR ls_row-status = zif_cd_ops_payout_types=>gc_pkg_status-planned
                                            THEN zif_cd_ops_payout_types=>gc_pkg_status-abandoned
                                            ELSE ls_row-status ).
      <ls_plan>-package-evaluated = ls_row-evaluated.
      <ls_plan>-package-inserted  = ls_row-inserted.
      <ls_plan>-package-closed    = ls_row-closed.
      CASE <ls_plan>-package-status.
        WHEN zif_cd_ops_payout_types=>gc_pkg_status-failed.
          failure( iv_source = <ls_package>-source iv_text = CONV #( ls_row-message ) ).
        WHEN zif_cd_ops_payout_types=>gc_pkg_status-abandoned.
          failure( iv_source = <ls_package>-source
                   iv_text   = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-pkg_abandoned
                                                      iv_v1    = <ls_package>-source
                                                      iv_v2    = <ls_package>-pkg_no
                                                      iv_v3    = mv_wait_sec ) ).
      ENDCASE.
    ENDLOOP.
  ENDMETHOD.


  METHOD advance_watermarks.
    DATA lt_status TYPE tt_pkg_status.
    " SWEEP moves no watermark: its packages only write rows
    IF ms_selection-mode = zif_cd_ops_payout_types=>gc_mode-sweep.
      RETURN.
    ENDIF.
    LOOP AT sources( ms_selection ) ASSIGNING FIELD-SYMBOL(<lv_source>).
      DATA(lv_source) = CONV zif_cd_ops_payout_types=>ty_source_id( <lv_source> ).
      CLEAR lt_status.
      DATA(lv_applied) = 0.
      LOOP AT ct_plans ASSIGNING FIELD-SYMBOL(<ls_plan>) WHERE package-source = lv_source.
        INSERT <ls_plan>-package-status INTO TABLE lt_status.
        IF <ls_plan>-applied = abap_true.
          lv_applied = lv_applied + 1.
        ENDIF.
      ENDLOOP.
      " Ordered: only to the end of the last contiguous done package, never past a failed one
      DATA(lv_done) = contiguous_done( lt_status ).
      IF lv_done <= lv_applied.
        CONTINUE.
      ENDIF.
      DATA(lv_position) = 0.
      DATA(ls_watermark) = VALUE zif_cd_ops_payout_types=>ty_watermark( ).
      LOOP AT ct_plans ASSIGNING <ls_plan> WHERE package-source = lv_source.
        lv_position = lv_position + 1.
        IF lv_position > lv_done.
          EXIT.
        ENDIF.
        <ls_plan>-applied = abap_true.
        ls_watermark = <ls_plan>-watermark.
      ENDLOOP.
      mo_dao->save_watermark( ls_watermark ).
      mo_store->commit( ).
    ENDLOOP.
  ENDMETHOD.


  METHOD contiguous_done.
    LOOP AT it_status ASSIGNING FIELD-SYMBOL(<lv_status>).
      IF <lv_status> <> zif_cd_ops_payout_types=>gc_pkg_status-done.
        RETURN.
      ENDIF.
      rv_count = rv_count + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD run_package.
    DATA(ls_package) = is_package.
    mo_store   = zcl_cd_ops_factory=>get_store( ).
    mo_dao     = zcl_cd_ops_factory=>get_pay_outcome_dao( ).
    mo_outcome = zcl_cd_ops_factory=>get_pay_outcome( ).
    mo_request = zcl_cd_ops_factory=>get_pay_request( ).
    mv_now     = is_package-run_at.
    TRY.
        mv_cap = zcl_cd_ops_pay_outcome=>evidence_cap( ).
        ms_config = mo_outcome->load( iv_context  = zif_cd_ops_payout_types=>gc_context
                                      iv_max_rows = mv_cap ).
        DATA(ls_judgement) = judge( it_docno = is_package-docno it_requests = is_package-requests ).
        " An abandoned package (the run stopped waiting) writes nothing
        IF mo_dao->claim_package( ls_package ) = abap_false.
          mo_store->rollback( ).
          RETURN.
        ENDIF.
        mo_dao->save_versions( it_close  = ls_judgement-close
                               it_insert = ls_judgement-insert
                               it_delete = ls_judgement-delete
                               it_update = ls_judgement-update ).
        ls_package-status    = zif_cd_ops_payout_types=>gc_pkg_status-done.
        ls_package-evaluated = ls_judgement-evaluated.
        ls_package-inserted  = lines( ls_judgement-insert ) + lines( ls_judgement-update ).
        ls_package-closed    = lines( ls_judgement-close ) + lines( ls_judgement-delete ).
        mo_dao->finish_package( ls_package ).
        mo_store->commit( ).
      CATCH cx_root INTO DATA(lx_error).
        " Fail closed: nothing of the package is written; the run keeps the watermark before it
        mo_store->rollback( ).
        ls_package-status  = zif_cd_ops_payout_types=>gc_pkg_status-failed.
        ls_package-message = lx_error->get_text( ).
        TRY.
            IF mo_dao->claim_package( ls_package ) = abap_true.
              mo_dao->finish_package( ls_package ).
            ENDIF.
            mo_store->commit( ).
          CATCH zcx_cd_ops_error.
            " The run sees the package still planned and abandons it after its wait
            mo_store->rollback( ).
        ENDTRY.
    ENDTRY.
  ENDMETHOD.


  METHOD processed_to.
    rs_watermark = is_watermark.
    IF iv_more = abap_false.
      " Caught up: every evidence of the source up to this run is processed
      rs_watermark-current_to = mv_now.
      RETURN.
    ENDIF.
    rs_watermark-current_to = iv_before.
    IF is_watermark-wm_date IS NOT INITIAL AND is_watermark-source <> zif_cd_ops_payout_types=>gc_source-statement
       AND is_watermark-source <> zif_cd_ops_payout_types=>gc_source-recheck.
      " Behind: processed up to the entry time of the last evidence read (system time zone)
      CONVERT DATE is_watermark-wm_date TIME is_watermark-wm_time
        INTO TIME STAMP rs_watermark-current_to TIME ZONE sy-zonlo.
      IF sy-subrc <> 0.
        rs_watermark-current_to = iv_before.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD lag.
    " The FAST evidence sources only: the recheck and the NIGHTLY cursors carry no evidence time
    LOOP AT it_watermarks ASSIGNING FIELD-SYMBOL(<ls_watermark>)
         WHERE source <> zif_cd_ops_payout_types=>gc_source-recheck
           AND source <> zif_cd_ops_payout_types=>gc_source-nightly
           AND source <> zif_cd_ops_payout_types=>gc_source-nightly_req
           AND current_to IS NOT INITIAL.
      IF rs_lag-known = abap_false OR <ls_watermark>-current_to < rs_lag-current_to.
        rs_lag-known      = abap_true.
        rs_lag-source     = <ls_watermark>-source.
        rs_lag-current_to = <ls_watermark>-current_to.
      ENDIF.
    ENDLOOP.
    IF rs_lag-known = abap_false.
      RETURN.
    ENDIF.
    DATA(lv_seconds) = cl_abap_tstmp=>subtract( tstmp1 = iv_now tstmp2 = rs_lag-current_to ).
    rs_lag-minutes = nmax( val1 = 0 val2 = floor( lv_seconds / 60 ) ).
  ENDMETHOD.


  METHOD batch_stopped.
    IF ms_selection-mode = zif_cd_ops_payout_types=>gc_mode-fast.
      RETURN.
    ENDIF.
    INSERT VALUE #( object_type = zif_cd_ops_payout_types=>gc_object_type
                    object_key  = |{ zif_cd_ops_payout_types=>gc_context }/{ ms_selection-mode }/{ iv_source }|
                    check_code  = zif_cd_ops_payout_types=>gc_code-batch_incomplete
                    severity    = zif_cd_ops_types=>gc_severity-warning
                    action      = zif_cd_ops_types=>gc_action-notify
                    message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-batch_stopped
                                                         iv_v1    = |{ ms_selection-mode } { iv_source }|
                                                         iv_v2    = iv_packages ) ) INTO TABLE mt_findings.
  ENDMETHOD.


  METHOD report_flagged.
    DATA lt_details TYPE string_table.
    DATA lt_payments TYPE SORTED TABLE OF zif_cd_ops_trace_types=>ty_docno WITH UNIQUE KEY table_line.
    DATA(lt_sorted) = it_flagged.
    SORT lt_sorted BY key version-finding version-laufd version-augbl version-fin_id version-source.
    LOOP AT lt_sorted ASSIGNING FIELD-SYMBOL(<ls_first>)
         GROUP BY ( key     = <ls_first>-key
                    finding = <ls_first>-version-finding
                    laufd   = <ls_first>-version-laufd ) ASSIGNING FIELD-SYMBOL(<ls_group>).
      CLEAR: lt_details, lt_payments.
      DATA(lv_rows) = 0.
      LOOP AT GROUP <ls_group> ASSIGNING FIELD-SYMBOL(<ls_member>).
        lv_rows = lv_rows + 1.
      ENDLOOP.
      INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-examples_head
                                    iv_v1    = nmin( val1 = mv_examples val2 = lv_rows )
                                    iv_v2    = lv_rows ) INTO TABLE lt_details.
      LOOP AT GROUP <ls_group> ASSIGNING <ls_member>.
        INSERT <ls_member>-version-augbl INTO TABLE lt_payments.
        IF lines( lt_details ) <= mv_examples.
          INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-ambiguous_line
                                        iv_v1    = <ls_member>-version-fin_id
                                        iv_v2    = <ls_member>-version-source
                                        iv_v3    = <ls_member>-version-augbl
                                        iv_tail  = CONV string( <ls_member>-version-evidence_ref ) ) INTO TABLE lt_details.
        ENDIF.
      ENDLOOP.
      INSERT zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-drill_down
                                    iv_v1    = <ls_group>-finding
                                    iv_v2    = |{ <ls_group>-laufd DATE = ISO }| ) INTO TABLE lt_details.
      INSERT VALUE #( object_type = zif_cd_ops_payout_types=>gc_object_type
                      object_key  = |{ zif_cd_ops_payout_types=>gc_context }/{ <ls_group>-key }/| &&
                                    |{ <ls_group>-finding }/{ <ls_group>-laufd }|
                      group1      = <ls_group>-key
                      group2      = |{ <ls_group>-laufd }|
                      check_code  = <ls_group>-finding
                      severity    = zif_cd_ops_types=>gc_severity-warning
                      action      = zif_cd_ops_types=>gc_action-notify
                      reference   = <ls_group>-key
                      message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-aggregated
                                                           iv_v1    = <ls_group>-key
                                                           iv_v2    = |{ <ls_group>-laufd DATE = ISO }|
                                                           iv_v3    = lines( lt_payments )
                                                           iv_v4    = <ls_group>-finding )
                      details     = concat_lines_of( table = lt_details sep = cl_abap_char_utilities=>newline ) )
             INTO TABLE mt_findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD class_key.
    DATA(lv_flow) = COND zif_cd_hck_runtime_types=>ty_flow( WHEN iv_xeinz = abap_true
                                                              THEN zif_cd_hck_runtime_types=>gc_flow-collection
                                                            ELSE zif_cd_hck_runtime_types=>gc_flow-disbursement ).
    rv_key = |{ lv_flow }{ VALUE #( ms_config-methods[ flow = lv_flow pymet = iv_pymet ]-class OPTIONAL ) }|.
  ENDMETHOD.


  METHOD initial_watermark.
    rs_watermark-source = iv_source.
    IF iv_source = zif_cd_ops_payout_types=>gc_source-recheck
       OR iv_source = zif_cd_ops_payout_types=>gc_source-nightly
       OR iv_source = zif_cd_ops_payout_types=>gc_source-nightly_req.
      RETURN.
    ENDIF.
    IF ms_selection-mode = zif_cd_ops_payout_types=>gc_mode-sweep.
      " The whole first day of the range: the statement reads from its first line posted that day, the
      " dated sources after the last second of the day before
      rs_watermark-wm_date = COND #( WHEN iv_source = zif_cd_ops_payout_types=>gc_source-statement
                                     THEN ms_selection-date_from ELSE ms_selection-date_from - 1 ).
      rs_watermark-wm_time = COND #( WHEN iv_source <> zif_cd_ops_payout_types=>gc_source-statement
                                     THEN zif_cd_ops_types=>gc_time-day_end ).
      RETURN.
    ENDIF.
    " History starts at go-live: the first run reads the last PAYOUT_INITIAL_DAYS days once
    rs_watermark-wm_date = zcl_cd_ops_factory=>get_clock( )->today( ) - mv_initial_days.
  ENDMETHOD.


  METHOD failure.
    INSERT VALUE #( object_type = zif_cd_ops_payout_types=>gc_object_type
                    object_key  = |{ zif_cd_ops_payout_types=>gc_context }/{ iv_source }|
                    check_code  = zif_cd_ops_payout_types=>gc_code-snapshot_failed
                    severity    = zif_cd_ops_types=>gc_severity-error
                    action      = zif_cd_ops_types=>gc_action-notify
                    message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-snapshot_failed
                                                         iv_v1    = iv_source
                                                         iv_tail  = iv_text ) ) INTO TABLE mt_findings.
  ENDMETHOD.


  METHOD finish.
    cs_result-findings = mt_findings.
    LOOP AT cs_result-sources ASSIGNING FIELD-SYMBOL(<ls_source>).
      cs_result-run-total_items  = cs_result-run-total_items + <ls_source>-documents.
      cs_result-run-passed_items = cs_result-run-passed_items + <ls_source>-evaluated.
    ENDLOOP.
    cs_result-run-status = COND #( WHEN line_exists( mt_findings[ severity = zif_cd_ops_types=>gc_severity-error ] )
                                     THEN zif_cd_ops_types=>gc_run_status-error
                                   WHEN mt_findings IS NOT INITIAL
                                     THEN zif_cd_ops_types=>gc_run_status-warning
                                   ELSE zif_cd_ops_types=>gc_run_status-success ).
    cs_result-run-rag = SWITCH #( cs_result-run-status
                                  WHEN zif_cd_ops_types=>gc_run_status-error   THEN zif_cd_ops_types=>gc_rag-red
                                  WHEN zif_cd_ops_types=>gc_run_status-warning THEN zif_cd_ops_types=>gc_rag-amber
                                  ELSE zif_cd_ops_types=>gc_rag-green ).
    cs_result-run-ended_at = zcl_cd_ops_factory=>get_clock( )->now( ).
    IF mo_dao IS BOUND.
      cs_result-lag = lag( it_watermarks = mo_dao->get_watermarks( )
                           iv_now        = cs_result-run-ended_at ).
    ENDIF.
    IF mt_findings IS NOT INITIAL.
      mo_store->save_findings( EXPORTING it_findings = mt_findings
                               CHANGING  cs_run      = cs_result-run ).
    ENDIF.
    mo_store->finish_run( cs_result-run ).
    IF mv_test_mode = abap_false.
      mo_store->commit( ).
    ENDIF.
  ENDMETHOD.


  METHOD sources.
    CASE is_selection-mode.
      WHEN zif_cd_ops_payout_types=>gc_mode-nightly.
        rt_sources = VALUE #( ( CONV #( zif_cd_ops_payout_types=>gc_source-nightly ) )
                              ( CONV #( zif_cd_ops_payout_types=>gc_source-nightly_req ) ) ).
      WHEN zif_cd_ops_payout_types=>gc_mode-sweep.
        LOOP AT is_selection-sources ASSIGNING FIELD-SYMBOL(<lv_source>).
          INSERT CONV #( <lv_source> ) INTO TABLE rt_sources.
        ENDLOOP.
      WHEN OTHERS.
        rt_sources = VALUE #( ( CONV #( zif_cd_ops_payout_types=>gc_source-documents ) )
                              ( CONV #( zif_cd_ops_payout_types=>gc_source-reversals ) )
                              ( CONV #( zif_cd_ops_payout_types=>gc_source-statement ) )
                              ( CONV #( zif_cd_ops_payout_types=>gc_source-returns ) )
                              ( CONV #( zif_cd_ops_payout_types=>gc_source-gl ) )
                              ( CONV #( zif_cd_ops_payout_types=>gc_source-requests ) )
                              ( CONV #( zif_cd_ops_payout_types=>gc_source-recheck ) ) ).
    ENDCASE.
  ENDMETHOD.


  METHOD release_lock.
    zcl_cd_ops_factory=>get_lock( )->release( iv_pe_area = zif_cd_ops_types=>gc_pe_area-core
                                              iv_variant = variant( ) ).
  ENDMETHOD.

ENDCLASS.
