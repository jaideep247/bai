*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_snapshot.clas.testclasses.abap
*& Purpose:
*& Unit tests of the payment worklist snapshot (FAST / NIGHTLY / SWEEP) with
*& LTD doubles of the worklist repository, the evaluator, the request rule,
*& the store, the run lock, the clock (core injector) and the health check
*& repository (A_INFLIGHT limits and calendar, HCK injector), payments and
*& outcomes of the shared fixtures (ZCL_CD_OPS_PAY_FIXTURE): a clean final
*& outcome deletes the open row (no history), an exception keeps versions
*& and closes with a closing version, an open row changes in place, an
*& unchanged row is never rewritten, a payment late beyond AMBER / RED is an
*& exception, a deleted clean payment re-enters through RETURNS, payment
*& requests (open, overdue, paid on time, paid late), NIGHTLY cursors and
*& SWEEP without watermark, the watermark picks up only new evidence, a
*& newer DPAYH run replaces the row of the older run, a FIN in two sources
*& is AMBIGUOUS for both with a finding, test mode writes nothing, a capped
*& evidence read fails closed, parallel packages with the ordered watermark
*& rule, the snapshot lag of the FAST sources. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version (incremental 5-minute payment outcome snapshot).
*& 2026-11-08 | Fixtures wire returned / return with the status pending: version only on an outcome change.
*& 2026-11-08 | Scale: PAYOUT_PARALLEL 1 behaves as before (no unit dispatched, a watermark per package);
*&            | parallel packages through a queue double that runs the bgPF operation - a failed middle
*&            | package holds the watermark at the end of the package before it (the later package's
*&            | versions are written, its watermark is not), an unfinished package is abandoned;
*&            | ordered watermark rule and snapshot lag as pure functions; the status-pending verdict
*&            | writes an IN_FLIGHT version with the marker PAY_STATUS_PENDING (basis of PAY_STATUS_LAG,
*&            | was: no version); a payment without FIN gets a version with FIN and source blank; the
*&            | FIN in two sources gives one aggregated finding with its examples (was one per source).
*& 2026-11-08 | Exceptions-only worklist: clean outcome deleted (no history), exception versions and the
*&            | closing version, open row changed in place, late payment, re-entry through RETURNS,
*&            | payment requests, NIGHTLY and SWEEP modes, duplicate current rows of a race, lag of the
*&            | FAST sources only.
*& 2026-11-10 | Concurrency review: the package write gets the rows the judgement was based on; a stale
*&            | judgement (a concurrent mode changed the rows) and a database error fail the package closed
*&            | (rollback, nothing written, watermark kept, finding); the units re-read their package by key
*&            | (the queue double runs the operation with the key only); packages deleted per mode; the count of
*&            | consecutive failed runs: a warning first, an error from PAYOUT_FAIL_ESCALATE on, reset by a run
*&            | without failure; a configuration error is PAY_OUTCOME_CONFIG.
*&---------------------------------------------------------------------*
"! Worklist repository double: evidence events per source, rows in memory
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_outcome_dao PARTIALLY IMPLEMENTED.
    TYPES:
      BEGIN OF ty_event,
        source TYPE zif_cd_ops_payout_types=>ty_source_id,
        wm_date TYPE d,
        wm_time TYPE t,
        doc    TYPE zif_cd_ops_trace_types=>ty_docno,
      END OF ty_event.
    DATA mt_events TYPE STANDARD TABLE OF ty_event WITH EMPTY KEY.
    DATA mt_watermarks TYPE zif_cd_ops_payout_types=>tt_watermark.
    DATA mt_items TYPE zif_cd_ops_payout_types=>tt_fin_item.
    DATA mt_versions TYPE zif_cd_ops_payout_types=>tt_version.
    DATA mt_closed TYPE zif_cd_ops_payout_types=>tt_version.
    DATA mt_inserted TYPE zif_cd_ops_payout_types=>tt_version.
    DATA mt_deleted TYPE zif_cd_ops_payout_types=>tt_version.
    DATA mt_updated TYPE zif_cd_ops_payout_types=>tt_version.
    DATA mv_wm_saves TYPE i.
    "! Package rows (ZCD_PAY_OUTPKG) and every watermark saved, in order
    DATA mt_packages TYPE zif_cd_ops_payout_types=>tt_package.
    DATA mt_wm_history TYPE STANDARD TABLE OF zif_cd_ops_payout_types=>ty_watermark WITH EMPTY KEY.
    "! Members of the planned packages (documents and requests, as ZCD_PAY_OUTPKGM)
    DATA mt_members TYPE zif_cd_ops_payout_types=>tt_package.
    "! The rows the last package write was based on
    DATA mt_basis TYPE zif_cd_ops_payout_types=>tt_version.
    "! A concurrent run changed the rows of the next package write (780), or the database fails (SQL error)
    DATA mv_stale TYPE abap_bool.
    DATA mv_db_error TYPE abap_bool.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_ops_pay_outcome_dao~get_watermarks.
    rt_watermarks = mt_watermarks.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~save_watermark.
    " As the repository: the position only, the count of failed runs stays
    DATA(ls_watermark) = is_watermark.
    ls_watermark-fail_count = VALUE #( mt_watermarks[ source = is_watermark-source ]-fail_count OPTIONAL ).
    mv_wm_saves = mv_wm_saves + 1.
    DELETE mt_watermarks WHERE source = is_watermark-source.
    INSERT ls_watermark INTO TABLE mt_watermarks.
    INSERT ls_watermark INTO TABLE mt_wm_history.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~get_changes.
    DATA lt_new LIKE mt_events.
    rs_changes-watermark = is_watermark.
    " NIGHTLY: the current payment rows after the cursor; NIGHTLYREQ: the current request rows
    IF iv_source = zif_cd_ops_payout_types=>gc_source-nightly.
      LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ls_row>)
           WHERE valid_to = zif_cd_ops_payout_types=>gc_valid_to_open AND augbl IS NOT INITIAL.
        INSERT <ls_row>-augbl INTO TABLE rs_changes-docno.
      ENDLOOP.
      RETURN.
    ENDIF.
    IF iv_source = zif_cd_ops_payout_types=>gc_source-nightly_req.
      LOOP AT mt_versions ASSIGNING <ls_row>
           WHERE valid_to = zif_cd_ops_payout_types=>gc_valid_to_open AND augbl IS INITIAL.
        INSERT VALUE #( fin = <ls_row>-fin_id source = <ls_row>-source ) INTO TABLE rs_changes-requests.
      ENDLOOP.
      RETURN.
    ENDIF.
    LOOP AT mt_events ASSIGNING FIELD-SYMBOL(<ls_event>) WHERE source = iv_source.
      IF iv_to IS NOT INITIAL AND <ls_event>-wm_date > iv_to.
        CONTINUE.
      ENDIF.
      IF <ls_event>-wm_date > is_watermark-wm_date
         OR ( <ls_event>-wm_date = is_watermark-wm_date AND <ls_event>-wm_time > is_watermark-wm_time )
         OR ( <ls_event>-wm_date = is_watermark-wm_date AND <ls_event>-wm_time = is_watermark-wm_time
              AND <ls_event>-doc > is_watermark-wm_key ).
        INSERT <ls_event> INTO TABLE lt_new.
      ENDIF.
    ENDLOOP.
    SORT lt_new BY wm_date wm_time doc.
    LOOP AT lt_new ASSIGNING <ls_event> TO iv_max.
      INSERT <ls_event>-doc INTO TABLE rs_changes-docno.
      rs_changes-watermark-wm_date = <ls_event>-wm_date.
      rs_changes-watermark-wm_time = <ls_event>-wm_time.
      rs_changes-watermark-wm_key  = <ls_event>-doc.
    ENDLOOP.
    rs_changes-more = xsdbool( lines( lt_new ) > iv_max ).
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~get_cheque_documents.
    CLEAR rt_docno.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~get_fin_items.
    LOOP AT mt_items ASSIGNING FIELD-SYMBOL(<ls_item>).
      IF line_exists( it_docno[ table_line = <ls_item>-augbl ] ).
        INSERT <ls_item> INTO TABLE rt_items.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~get_versions.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ls_version>) WHERE augbl IS NOT INITIAL.
      IF line_exists( it_docno[ table_line = <ls_version>-augbl ] ).
        INSERT <ls_version> INTO TABLE rt_versions.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~get_request_versions.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ls_version>) WHERE augbl IS INITIAL.
      IF line_exists( it_keys[ fin = <ls_version>-fin_id source = <ls_version>-source ] ).
        INSERT <ls_version> INTO TABLE rt_versions.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~get_request_keys.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ls_version>)
         WHERE augbl IS INITIAL AND valid_to = zif_cd_ops_payout_types=>gc_valid_to_open.
      IF line_exists( it_fin[ table_line = <ls_version>-fin_id ] ).
        INSERT VALUE #( fin = <ls_version>-fin_id source = <ls_version>-source ) INTO TABLE rt_keys.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~save_packages.
    LOOP AT it_packages ASSIGNING FIELD-SYMBOL(<ls_package>).
      INSERT <ls_package> INTO TABLE mt_members.
      DATA(ls_row) = <ls_package>.
      ls_row-status = zif_cd_ops_payout_types=>gc_pkg_status-planned.
      ls_row-documents = lines( ls_row-docno ).
      CLEAR: ls_row-docno, ls_row-requests.
      INSERT ls_row INTO TABLE mt_packages.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~get_package.
    READ TABLE mt_members INTO DATA(ls_member)
         WITH KEY run_id = is_key-run_id source = is_key-source pkg_no = is_key-pkg_no.
    IF sy-subrc = 0.
      rs_package = ls_member.
    ENDIF.
    rs_package-run_at = is_key-run_at.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~save_failures.
    READ TABLE mt_watermarks ASSIGNING FIELD-SYMBOL(<ls_watermark>) WITH TABLE KEY source = iv_source.
    IF sy-subrc = 0.
      <ls_watermark>-fail_count = iv_count.
      RETURN.
    ENDIF.
    INSERT VALUE #( source = iv_source fail_count = iv_count ) INTO TABLE mt_watermarks.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~claim_package.
    rv_claimed = xsdbool( VALUE #( mt_packages[ run_id = is_package-run_id
                                                source = is_package-source
                                                pkg_no = is_package-pkg_no ]-status OPTIONAL )
                          = zif_cd_ops_payout_types=>gc_pkg_status-planned ).
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~finish_package.
    READ TABLE mt_packages ASSIGNING FIELD-SYMBOL(<ls_row>)
         WITH KEY run_id = is_package-run_id source = is_package-source pkg_no = is_package-pkg_no.
    IF sy-subrc = 0.
      <ls_row>-status    = is_package-status.
      <ls_row>-evaluated = is_package-evaluated.
      <ls_row>-inserted  = is_package-inserted.
      <ls_row>-closed    = is_package-closed.
      <ls_row>-message   = is_package-message.
    ENDIF.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~get_packages.
    LOOP AT mt_packages ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE run_id = iv_run_id.
      INSERT <ls_row> INTO TABLE rt_packages.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~abandon_packages.
    LOOP AT mt_packages ASSIGNING FIELD-SYMBOL(<ls_row>)
         WHERE run_id = iv_run_id AND status = zif_cd_ops_payout_types=>gc_pkg_status-planned.
      <ls_row>-status = zif_cd_ops_payout_types=>gc_pkg_status-abandoned.
      rv_count = rv_count + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~delete_packages.
    DATA(lv_before) = lines( mt_packages ).
    DELETE mt_packages WHERE run_id <> iv_keep_run_id AND mode = iv_mode.
    DELETE mt_members WHERE run_id <> iv_keep_run_id AND mode = iv_mode.
    rv_count = lv_before - lines( mt_packages ).
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~get_new_versions.
    LOOP AT mt_inserted ASSIGNING FIELD-SYMBOL(<ls_version>)
         WHERE valid_from = iv_valid_from AND finding = iv_finding.
      INSERT VALUE #( version = <ls_version> pymet = zcl_cd_ops_pay_fixture=>gc_wire ) INTO TABLE rt_versions.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~save_versions.
    mt_basis = it_basis.
    IF mv_stale = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e780(zcd_ops) WITH 1 space.
    ENDIF.
    IF mv_db_error = abap_true.
      RAISE EXCEPTION NEW cx_sy_open_sql_db( ).
    ENDIF.
    LOOP AT it_delete ASSIGNING FIELD-SYMBOL(<ls_delete>).
      DELETE mt_versions WHERE fin_id = <ls_delete>-fin_id AND source = <ls_delete>-source
                           AND bukrs = <ls_delete>-bukrs AND augbl = <ls_delete>-augbl
                           AND laufd = <ls_delete>-laufd AND laufi = <ls_delete>-laufi
                           AND valid_from = <ls_delete>-valid_from.
    ENDLOOP.
    LOOP AT it_update ASSIGNING FIELD-SYMBOL(<ls_update>).
      LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ls_version>)
           WHERE fin_id = <ls_update>-fin_id AND source = <ls_update>-source AND bukrs = <ls_update>-bukrs
             AND augbl = <ls_update>-augbl AND laufd = <ls_update>-laufd AND laufi = <ls_update>-laufi
             AND valid_from = <ls_update>-valid_from.
        <ls_version> = <ls_update>.
      ENDLOOP.
    ENDLOOP.
    LOOP AT it_close ASSIGNING FIELD-SYMBOL(<ls_close>).
      LOOP AT mt_versions ASSIGNING <ls_version>
           WHERE fin_id = <ls_close>-fin_id AND source = <ls_close>-source AND bukrs = <ls_close>-bukrs
             AND augbl = <ls_close>-augbl AND laufd = <ls_close>-laufd AND laufi = <ls_close>-laufi
             AND valid_from = <ls_close>-valid_from.
        <ls_version>-valid_to = <ls_close>-valid_to.
      ENDLOOP.
    ENDLOOP.
    INSERT LINES OF it_delete INTO TABLE mt_deleted.
    INSERT LINES OF it_update INTO TABLE mt_updated.
    INSERT LINES OF it_close INTO TABLE mt_closed.
    INSERT LINES OF it_insert INTO TABLE mt_inserted.
    INSERT LINES OF it_insert INTO TABLE mt_versions.
  ENDMETHOD.
ENDCLASS.


"! Evaluator double: verdicts per document, sources per FIN, the configuration; FOR_SOURCE is the real rule
CLASS ltd_outcome DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_outcome PARTIALLY IMPLEMENTED.
    DATA ms_config TYPE zif_cd_ops_payout_types=>ty_config.
    DATA mt_verdicts TYPE zif_cd_ops_payout_types=>tt_verdict.
    DATA mt_sources TYPE zif_cd_ops_payout_types=>tt_fin_source.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.
    "! Documents asked for, per call
    DATA mt_asked TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA mv_calls TYPE i.
    "! The request source is not configured (configuration error 703)
    DATA mv_no_source TYPE abap_bool.
ENDCLASS.

CLASS ltd_outcome IMPLEMENTATION.
  METHOD zif_cd_ops_pay_outcome~load.
    rs_config = ms_config.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome~evaluate_documents.
    mv_calls = mv_calls + 1.
    INSERT LINES OF it_docno INTO TABLE mt_asked.
    LOOP AT mt_verdicts ASSIGNING FIELD-SYMBOL(<ls_verdict>).
      IF line_exists( it_docno[ table_line = <ls_verdict>-doc1r ] ).
        INSERT <ls_verdict> INTO TABLE rs_evaluation-verdicts.
      ENDIF.
    ENDLOOP.
    rs_evaluation-findings = mt_findings.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome~sources_of.
    IF mv_no_source = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e703(zcd_ops) WITH zif_cd_ops_trace_types=>gc_param-src_request.
    ENDIF.
    LOOP AT mt_sources ASSIGNING FIELD-SYMBOL(<ls_source>).
      IF line_exists( it_fin[ table_line = <ls_source>-fin ] ).
        INSERT <ls_source> INTO TABLE rt_sources.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome~for_source.
    rs_verdict = NEW zcl_cd_ops_pay_outcome( )->zif_cd_ops_pay_outcome~for_source( is_verdict = is_verdict
                                                                                    is_source  = is_source ).
  ENDMETHOD.
ENDCLASS.


"! Request rule double: new requests as REQUESTS events, the verdict of each request
CLASS ltd_request DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_request.
    DATA mt_new TYPE zif_cd_ops_payout_types=>tt_req_key.
    DATA mt_requests TYPE zif_cd_ops_payout_types=>tt_request.
    DATA mt_asked TYPE zif_cd_ops_payout_types=>tt_req_key.
ENDCLASS.

CLASS ltd_request IMPLEMENTATION.
  METHOD zif_cd_ops_pay_request~changes.
    rs_changes-watermark = is_watermark.
    rs_changes-requests  = mt_new.
    CLEAR mt_new.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_request~evaluate.
    LOOP AT it_keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      INSERT <ls_key> INTO TABLE mt_asked.
      READ TABLE mt_requests INTO DATA(ls_request) WITH KEY by_key COMPONENTS fin = <ls_key>-fin source = <ls_key>-source.
      IF sy-subrc <> 0.
        ls_request = VALUE #( fin = <ls_key>-fin source = <ls_key>-source finished = abap_true ).
      ENDIF.
      INSERT ls_request INTO TABLE rt_requests.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


"! Health check repository double: A_INFLIGHT with its AGE_OLDEST limits, every day a business day
CLASS ltd_hck_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_thresholds TYPE zif_cd_hck_types=>tt_threshold.
ENDCLASS.

CLASS ltd_hck_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_check_defs.
    CLEAR rt_defs.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_thresholds.
    rt_thresholds = mt_thresholds.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~is_working_day.
    rv_working = abap_true.
  ENDMETHOD.
ENDCLASS.


"! Queue double of the parallel packages: runs the bgPF operation of a package in this session, or
"! fails it (status F, as a unit after an error), or leaves it unfinished (the run abandons it)
CLASS ltd_queue DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_snap_queue.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mt_fail TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    DATA mt_hang TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    DATA mv_dispatched TYPE i.
    DATA mv_pauses TYPE i.
ENDCLASS.

CLASS ltd_queue IMPLEMENTATION.
  METHOD zif_cd_ops_pay_snap_queue~dispatch.
    mv_dispatched = mv_dispatched + 1.
    IF line_exists( mt_hang[ table_line = is_package-pkg_no ] ).
      RETURN.
    ENDIF.
    IF line_exists( mt_fail[ table_line = is_package-pkg_no ] ).
      DATA(ls_failed) = is_package.
      ls_failed-status = zif_cd_ops_payout_types=>gc_pkg_status-failed.
      mo_dao->zif_cd_ops_pay_outcome_dao~finish_package( ls_failed ).
      RETURN.
    ENDIF.
    " As bgPF: the operation carries the package key only, the unit re-reads its members
    NEW zcl_cd_ops_pay_snap_op( CORRESPONDING #( is_package ) )->if_bgmc_op_single_tx_uncontr~execute( ).
  ENDMETHOD.

  METHOD zif_cd_ops_pay_snap_queue~pause.
    mv_pauses = mv_pauses + 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store PARTIALLY IMPLEMENTED.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.
    DATA ms_finished TYPE zif_cd_ops_types=>ty_run.
    DATA mv_commits TYPE i.
    DATA mv_rollbacks TYPE i.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_cd_ops_store~start_run.
    rs_run-pe_area   = iv_pe_area.
    rs_run-variant   = iv_variant.
    rs_run-test_mode = iv_test_mode.
  ENDMETHOD.

  METHOD zif_cd_ops_store~save_findings.
    INSERT LINES OF it_findings INTO TABLE mt_findings.
    cs_run-finding_count = cs_run-finding_count + lines( it_findings ).
  ENDMETHOD.

  METHOD zif_cd_ops_store~finish_run.
    ms_finished = is_run.
  ENDMETHOD.

  METHOD zif_cd_ops_store~commit.
    mv_commits = mv_commits + 1.
  ENDMETHOD.

  METHOD zif_cd_ops_store~rollback.
    mv_rollbacks = mv_rollbacks + 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_lock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_lock.
    DATA mv_releases TYPE i.
    DATA mv_variant TYPE zif_cd_ops_types=>ty_variant.
ENDCLASS.

CLASS ltd_lock IMPLEMENTATION.
  METHOD zif_cd_ops_lock~acquire.
    CLEAR ev_holder.
    mv_variant = iv_variant.
    rv_acquired = abap_true.
  ENDMETHOD.

  METHOD zif_cd_ops_lock~release.
    mv_releases += 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock PARTIALLY IMPLEMENTED.
    CONSTANTS gc_today TYPE d VALUE '20261111'.
    DATA mv_now TYPE timestampl VALUE '20261111120000'.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~today.
    rv_date = gc_today.
  ENDMETHOD.

  METHOD zif_cd_ops_clock~now.
    rv_timestamp = mv_now.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_snapshot DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_earlier TYPE zif_cd_ops_payout_types=>ty_timestamp VALUE '20261110080000'.
    CONSTANTS gc_now TYPE zif_cd_ops_payout_types=>ty_timestamp VALUE '20261111120000'.
    CONSTANTS gc_later TYPE timestampl VALUE '20261111120500'.
    CONSTANTS gc_event_time TYPE t VALUE '100000'.
    CONSTANTS gc_later_time TYPE t VALUE '120100'.
    CONSTANTS gc_new_doc TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000900099'.
    CONSTANTS gc_new_fin TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0000009099'.
    CONSTANTS gc_older_run TYPE c LENGTH 6 VALUE 'WIR001'.
    "! Three payments of the parallel tests, entered one after the other
    CONSTANTS:
      BEGIN OF gc_par,
        doc_a     TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000910001',
        doc_b     TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000910002',
        doc_c     TYPE zif_cd_ops_trace_types=>ty_docno VALUE '000000910003',
        time_a    TYPE t VALUE '090000',
        time_b    TYPE t VALUE '091000',
        time_c    TYPE t VALUE '092000',
        fin       TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0000009100',
        parallel  TYPE string VALUE `4`,
        serial    TYPE string VALUE `1`,
        "! Runs of other modes with package rows before the run
        sweep_run TYPE zif_cd_ops_types=>ty_run_id VALUE '000000000000000000000000000000E1',
        fast_run  TYPE zif_cd_ops_types=>ty_run_id VALUE '000000000000000000000000000000E2',
        one       TYPE string VALUE `1`,
        wait_sec  TYPE string VALUE `30`,
        second    TYPE i VALUE 2,
        third     TYPE i VALUE 3,
      END OF gc_par.
    "! Snapshot lag: two sources processed to 11:50 and 11:30, recheck and nightly far behind, now 12:00
    CONSTANTS:
      BEGIN OF gc_lag,
        now       TYPE timestampl VALUE '20261111120000',
        to_1150   TYPE timestampl VALUE '20261111115000',
        to_1130   TYPE timestampl VALUE '20261111113015',
        to_0800   TYPE timestampl VALUE '20261111080000',
        to_night  TYPE timestampl VALUE '20261111020000',
        minutes   TYPE i VALUE 29,
      END OF gc_lag.
    "! A wire disbursement (flow D, class WIR) late: AMBER 1, RED 3 business days after the value date
    CONSTANTS:
      BEGIN OF gc_late,
        key      TYPE zif_cd_hck_runtime_types=>ty_flow_class VALUE 'DWIR',
        class    TYPE zif_cd_hck_runtime_types=>ty_method_class VALUE 'WIR',
        metric   TYPE zif_cd_hck_types=>ty_metric_name VALUE 'AGE_OLDEST',
        amber    TYPE i VALUE 1,
        red      TYPE i VALUE 3,
        two_ago  TYPE d VALUE '20261109',
        five_ago TYPE d VALUE '20261106',
      END OF gc_late.
    "! Payment requests (FIN + source)
    CONSTANTS:
      BEGIN OF gc_req,
        fin      TYPE zif_cd_ops_trace_types=>ty_fin VALUE 'FIN0000009200',
        source   TYPE zif_cd_ops_trace_types=>ty_source VALUE 'ORCI',
        due      TYPE d VALUE '20261110',
        tomorrow TYPE d VALUE '20261112',
      END OF gc_req.

    DATA mo_fixture TYPE REF TO zcl_cd_ops_pay_fixture.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_outcome TYPE REF TO ltd_outcome.
    DATA mo_request TYPE REF TO ltd_request.
    DATA mo_hck TYPE REF TO ltd_hck_dao.
    DATA mo_store TYPE REF TO ltd_store.
    DATA mo_clock TYPE REF TO ltd_clock.
    DATA mo_queue TYPE REF TO ltd_queue.
    DATA mo_lock TYPE REF TO ltd_lock.

    METHODS setup.
    METHODS teardown.

    METHODS clean_deletes_open_row     FOR TESTING.
    METHODS exception_closes_history   FOR TESTING.
    METHODS open_change_in_place       FOR TESTING.
    METHODS no_change_writes_nothing   FOR TESTING.
    METHODS late_payment_is_exception  FOR TESTING.
    METHODS returns_reenter_payment    FOR TESTING.
    METHODS reversal_reenters_clean    FOR TESTING.
    METHODS watermark_picks_up_new     FOR TESTING.
    METHODS newer_run_replaces_older   FOR TESTING.
    METHODS two_sources_ambiguous_both FOR TESTING.
    METHODS test_mode_writes_nothing   FOR TESTING.
    METHODS capped_read_fails_closed   FOR TESTING.
    METHODS return_is_finished         FOR TESTING.
    METHODS status_pending_marked      FOR TESTING.
    METHODS payment_without_fin        FOR TESTING.
    METHODS request_open_then_overdue  FOR TESTING.
    METHODS request_paid_on_time_gone  FOR TESTING.
    METHODS request_paid_late_history  FOR TESTING.
    METHODS request_rejudged_with_pay  FOR TESTING.
    METHODS nightly_rejudges_rows      FOR TESTING.
    METHODS sweep_moves_no_watermark   FOR TESTING.
    METHODS sweep_needs_range          FOR TESTING.
    METHODS plan_retires_duplicate     FOR TESTING.
    METHODS serial_never_dispatches    FOR TESTING.
    METHODS failed_middle_holds_wm     FOR TESTING.
    METHODS unfinished_package_holds   FOR TESTING.
    METHODS contiguous_done_rule       FOR TESTING.
    METHODS lag_oldest_source          FOR TESTING.
    METHODS lag_unknown_without_run    FOR TESTING.
    METHODS write_gets_judged_rows     FOR TESTING.
    METHODS stale_package_fails_closed FOR TESTING.
    METHODS db_error_rolls_back        FOR TESTING.
    METHODS failure_escalates          FOR TESTING.
    METHODS success_resets_failures    FOR TESTING.
    METHODS config_error_is_config     FOR TESTING.
    METHODS unit_reads_members_by_key  FOR TESTING.
    METHODS packages_deleted_per_mode  FOR TESTING.

    "! The finding of the source in the run's findings (failed or configuration)
    METHODS source_finding
      IMPORTING
        is_result         TYPE zcl_cd_ops_pay_snapshot=>ty_result
        iv_code           TYPE zif_cd_ops_types=>ty_check_code
      RETURNING
        VALUE(rs_finding) TYPE zif_cd_ops_types=>ty_finding.

    "! Parameters of the run: parallel packages, package size, wait (seed values, else delivered)
    METHODS parameters
      IMPORTING
        iv_parallel TYPE string
        iv_package  TYPE string OPTIONAL.

    "! Three payments A, B, C as DOCUMENTS evidence, each with a FIN item and an IN_FLIGHT verdict
    METHODS given_three_payments.

    "! Scenario of the shared fixture: its payment as evidence of DOCUMENTS, its item, its sources
    "! and the evaluator's verdict
    METHODS given
      IMPORTING
        iv_id              TYPE zcl_cd_ops_pay_fixture=>ty_scenario_id
      RETURNING
        VALUE(rs_scenario) TYPE zcl_cd_ops_pay_fixture=>ty_scenario.

    "! A payment of the source with a verdict (no FIN item: one row, FIN and source blank)
    METHODS given_payment
      IMPORTING
        iv_source  TYPE zif_cd_ops_payout_types=>ty_source_id DEFAULT zif_cd_ops_payout_types=>gc_source-documents
        iv_outcome TYPE zif_cd_ops_payout_types=>ty_outcome
        iv_finding TYPE zif_cd_ops_types=>ty_check_code OPTIONAL
        iv_valut   TYPE d DEFAULT ltd_clock=>gc_today.

    "! A current row of the scenario's payment (written by an earlier run)
    METHODS current_version
      IMPORTING
        is_scenario TYPE zcl_cd_ops_pay_fixture=>ty_scenario
        iv_outcome  TYPE zif_cd_ops_payout_types=>ty_outcome
        iv_finding  TYPE zif_cd_ops_types=>ty_check_code OPTIONAL
        iv_laufi    TYPE clike OPTIONAL.

    "! A current request row (written by an earlier run)
    METHODS current_request
      IMPORTING
        iv_outcome TYPE zif_cd_ops_payout_types=>ty_outcome
        iv_finding TYPE zif_cd_ops_types=>ty_check_code OPTIONAL.

    METHODS act
      IMPORTING
        iv_test_mode     TYPE abap_bool DEFAULT abap_false
        is_selection     TYPE zif_cd_ops_payout_types=>ty_selection OPTIONAL
      RETURNING
        VALUE(rs_result) TYPE zcl_cd_ops_pay_snapshot=>ty_result
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_snapshot IMPLEMENTATION.

  METHOD setup.
    mo_fixture = NEW #( ltd_clock=>gc_today ).
    mo_dao = NEW #( ).
    mo_outcome = NEW #( ).
    mo_request = NEW #( ).
    mo_hck = NEW #( ).
    mo_store = NEW #( ).
    mo_clock = NEW #( ).
    mo_queue = NEW #( ).
    mo_lock = NEW #( ).
    mo_queue->mo_dao = mo_dao.
    zcl_cd_ops_injector=>inject_pay_snap_queue( mo_queue ).
    zcl_cd_ops_injector=>inject_pay_outcome_dao( mo_dao ).
    zcl_cd_ops_injector=>inject_pay_outcome( mo_outcome ).
    zcl_cd_ops_injector=>inject_pay_request( mo_request ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
    zcl_cd_ops_injector=>inject_lock( mo_lock ).
    zcl_cd_ops_injector=>inject_clock( mo_clock ).
    zcl_cd_hck_injector=>inject_dao( mo_hck ).
    " PAYOUT_PARALLEL 1: the scenarios below run one package after the other, as before
    parameters( gc_par-serial ).
  ENDMETHOD.


  METHOD parameters.
    DATA(lo_seed) = NEW zcl_cd_ops_param_seed( ).
    lo_seed->set( iv_name = zif_cd_ops_payout_types=>gc_param-parallel iv_value = iv_parallel ).
    lo_seed->set( iv_name = zif_cd_ops_payout_types=>gc_param-wait_sec iv_value = gc_par-wait_sec ).
    IF iv_package IS SUPPLIED.
      lo_seed->set( iv_name = zif_cd_ops_payout_types=>gc_param-package_size iv_value = iv_package ).
    ENDIF.
    zcl_cd_ops_injector=>inject_params( lo_seed->params( ) ).
  ENDMETHOD.


  METHOD given_three_payments.
    DATA(lt_docs) = VALUE zif_cd_ops_trace_types=>tt_docno( ( gc_par-doc_a ) ( gc_par-doc_b ) ( gc_par-doc_c ) ).
    DATA(lv_time) = gc_par-time_a.
    LOOP AT lt_docs ASSIGNING FIELD-SYMBOL(<lv_doc>).
      lv_time = SWITCH #( <lv_doc> WHEN gc_par-doc_b THEN gc_par-time_b
                                   WHEN gc_par-doc_c THEN gc_par-time_c
                                   ELSE gc_par-time_a ).
      INSERT VALUE #( source  = zif_cd_ops_payout_types=>gc_source-documents
                      wm_date = ltd_clock=>gc_today
                      wm_time = lv_time
                      doc     = <lv_doc> ) INTO TABLE mo_dao->mt_events.
      INSERT VALUE #( augbl = <lv_doc> bukrs = zcl_cd_ops_pay_fixture=>gc_bukrs fin = gc_par-fin ) INTO TABLE mo_dao->mt_items.
      INSERT VALUE #( doc1r   = <lv_doc>
                      laufd   = ltd_clock=>gc_today
                      laufi   = gc_older_run
                      bukrs   = zcl_cd_ops_pay_fixture=>gc_bukrs
                      status  = zif_cd_ops_payout_types=>gc_status-open
                      outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ) INTO TABLE mo_outcome->mt_verdicts.
    ENDLOOP.
    INSERT VALUE #( fin = gc_par-fin source = zcl_cd_ops_pay_fixture=>gc_source-pclm sources = 1 )
      INTO TABLE mo_outcome->mt_sources.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_hck_injector=>reset( ).
    CLEAR: mo_fixture, mo_dao, mo_outcome, mo_request, mo_hck, mo_store, mo_clock, mo_queue, mo_lock.
  ENDMETHOD.


  METHOD given.
    rs_scenario = mo_fixture->scenario( iv_id ).
    INSERT VALUE #( source  = zif_cd_ops_payout_types=>gc_source-documents
                    wm_date = ltd_clock=>gc_today
                    wm_time = gc_event_time
                    doc     = rs_scenario-augbl ) INTO TABLE mo_dao->mt_events.
    INSERT VALUE #( augbl = rs_scenario-augbl bukrs = zcl_cd_ops_pay_fixture=>gc_bukrs fin = rs_scenario-fin )
      INTO TABLE mo_dao->mt_items.
    DATA(lt_sources) = VALUE zif_cd_ops_payout_types=>tt_fin_source( ).
    LOOP AT rs_scenario-requests ASSIGNING FIELD-SYMBOL(<ls_request>).
      INSERT VALUE #( fin = rs_scenario-fin source = <ls_request>-source ) INTO TABLE lt_sources.
    ENDLOOP.
    LOOP AT lt_sources ASSIGNING FIELD-SYMBOL(<ls_source>).
      <ls_source>-sources = lines( lt_sources ).
      INSERT <ls_source> INTO TABLE mo_outcome->mt_sources.
    ENDLOOP.
    INSERT VALUE #( doc1r   = rs_scenario-augbl
                    laufd   = rs_scenario-expected_laufd
                    laufi   = rs_scenario-expected_laufi
                    bukrs   = zcl_cd_ops_pay_fixture=>gc_bukrs
                    status  = zif_cd_ops_payout_types=>gc_status-open
                    outcome = rs_scenario-evaluated
                    status_pending = rs_scenario-status_pending ) INTO TABLE mo_outcome->mt_verdicts.
  ENDMETHOD.


  METHOD given_payment.
    INSERT VALUE #( source  = iv_source
                    wm_date = ltd_clock=>gc_today
                    wm_time = gc_event_time
                    doc     = gc_new_doc ) INTO TABLE mo_dao->mt_events.
    INSERT VALUE #( doc1r   = gc_new_doc
                    laufd   = iv_valut
                    laufi   = gc_older_run
                    bukrs   = zcl_cd_ops_pay_fixture=>gc_bukrs
                    flow    = zif_cd_hck_runtime_types=>gc_flow-disbursement
                    class   = gc_late-class
                    valut   = iv_valut
                    status  = COND #( WHEN iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight
                                      THEN zif_cd_ops_payout_types=>gc_status-open
                                      ELSE zif_cd_ops_payout_types=>gc_status-excluded )
                    outcome = iv_outcome
                    finding = iv_finding ) INTO TABLE mo_outcome->mt_verdicts.
  ENDMETHOD.


  METHOD current_version.
    INSERT VALUE #( fin_id     = is_scenario-fin
                    source     = zcl_cd_ops_pay_fixture=>gc_source-pclm
                    bukrs      = zcl_cd_ops_pay_fixture=>gc_bukrs
                    augbl      = is_scenario-augbl
                    laufd      = is_scenario-expected_laufd
                    laufi      = COND #( WHEN iv_laufi IS SUPPLIED THEN iv_laufi ELSE is_scenario-expected_laufi )
                    valid_from = gc_earlier
                    valid_to   = zif_cd_ops_payout_types=>gc_valid_to_open
                    outcome    = iv_outcome
                    finding    = iv_finding ) INTO TABLE mo_dao->mt_versions.
  ENDMETHOD.


  METHOD current_request.
    INSERT VALUE #( fin_id        = gc_req-fin
                    source        = gc_req-source
                    valid_from    = gc_earlier
                    valid_to      = zif_cd_ops_payout_types=>gc_valid_to_open
                    outcome       = iv_outcome
                    finding       = iv_finding
                    severity      = COND #( WHEN iv_finding IS NOT INITIAL THEN zif_cd_ops_types=>gc_severity-error )
                    evidence_kind = zif_cd_ops_payout_types=>gc_req_stage-not_in_run
                    due_date      = gc_req-due ) INTO TABLE mo_dao->mt_versions.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_ops_pay_snapshot( )->run( iv_test_mode = iv_test_mode is_selection = is_selection ).
  ENDMETHOD.


  METHOD source_finding.
    rs_finding = VALUE #( is_result-findings[ check_code = iv_code
                                              object_key = |{ zif_cd_ops_payout_types=>gc_context }/| &&
                                                           |{ zif_cd_ops_payout_types=>gc_source-documents }| ] OPTIONAL ).
  ENDMETHOD.


  " Rule (review 2026-11-10): the package write gets every row the judgement was based on - the
  " repository compares them with the current rows under the worklist guard
  METHOD write_gets_judged_rows.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        current_version( is_scenario = ls_scenario iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        DATA(lt_judged) = mo_dao->mt_versions.
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_basis exp = lt_judged msg = 'The rows judged are the basis' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (review 2026-11-10): a concurrent mode changed the rows after this run read them - the package
  " writes nothing (rolled back), the watermark stays, the next run judges again; a first failure is a
  " warning
  METHOD stale_package_fails_closed.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        current_version( is_scenario = ls_scenario iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        mo_dao->mv_stale = abap_true.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_deleted msg = 'Nothing deleted' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_versions ) exp = 1 msg = 'The open row stays' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_rollbacks exp = 1 msg = 'The package is rolled back' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_dao->mt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-documents ]-wm_date
          exp = VALUE d( ) msg = 'Watermark not advanced' ).
        DATA(ls_finding) = source_finding( is_result = ls_result iv_code = zif_cd_ops_payout_types=>gc_code-snapshot_failed ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'First failure: a warning, the next run retries' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_dao->mt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-documents ]-fail_count
          exp = 1 msg = 'One failed run counted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (review 2026-11-10): a database error of the package write (CX_SY_OPEN_SQL_DB) is caught at the
  " package boundary: rollback, finding with message 782, the run ends normally
  METHOD db_error_rolls_back.
    TRY.
        given( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        mo_dao->mv_db_error = abap_true.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'Nothing written' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_rollbacks exp = 1 msg = 'Rolled back' ).
        DATA(ls_finding) = source_finding( is_result = ls_result iv_code = zif_cd_ops_payout_types=>gc_code-snapshot_failed ).
        cl_abap_unit_assert=>assert_char_cp( act = ls_finding-message
                                             exp = |*{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-db_error
                                                                             iv_v1    = zif_cd_ops_payout_types=>gc_source-documents ) }*|
                                             msg = 'Message 782 with the source' ).
        cl_abap_unit_assert=>assert_not_initial( act = ls_result-run-ended_at msg = 'The run ends normally' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (review 2026-11-10): the source failed in PAYOUT_FAIL_ESCALATE - 1 runs before: this third
  " failure in a row is an error with the count (783)
  METHOD failure_escalates.
    TRY.
        given( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        INSERT VALUE #( source     = zif_cd_ops_payout_types=>gc_source-documents
                        fail_count = zif_cd_ops_payout_types=>gc_param_default-fail_escalate - 1 )
          INTO TABLE mo_dao->mt_watermarks.
        mo_dao->mv_stale = abap_true.
        DATA(ls_result) = act( ).
        DATA(ls_finding) = source_finding( is_result = ls_result iv_code = zif_cd_ops_payout_types=>gc_code-snapshot_failed ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Escalated to an error' ).
        cl_abap_unit_assert=>assert_char_cp(
          act = ls_finding-message
          exp = |*{ zcl_cd_ops_util=>text( iv_msgno = zif_cd_ops_payout_types=>gc_msg-failed_escalated
                                           iv_v1    = zif_cd_ops_payout_types=>gc_source-documents
                                           iv_v2    = zif_cd_ops_payout_types=>gc_param_default-fail_escalate
                                           iv_v3    = zif_cd_ops_payout_types=>gc_param_default-fail_escalate ) }*|
          msg = 'Message 783 with the count' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_dao->mt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-documents ]-fail_count
          exp = zif_cd_ops_payout_types=>gc_param_default-fail_escalate msg = 'Counted' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-run-status exp = zif_cd_ops_types=>gc_run_status-error
                                            msg = 'Run in error' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (review 2026-11-10): a run in which the source is judged without failure resets its count
  METHOD success_resets_failures.
    TRY.
        given( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        INSERT VALUE #( source     = zif_cd_ops_payout_types=>gc_source-documents
                        fail_count = zif_cd_ops_payout_types=>gc_param_default-fail_escalate )
          INTO TABLE mo_dao->mt_watermarks.
        act( ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_dao->mt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-documents ]-fail_count
          exp = 0 msg = 'Reset by a run without failure' ).
        cl_abap_unit_assert=>assert_not_initial(
          act = mo_dao->mt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-documents ]-wm_date
          msg = 'A row with only its count is a first run: the source was read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (review 2026-11-10): a configuration error (703: request source not configured) is reported as
  " configuration (PAY_OUTCOME_CONFIG, 784), never as a failure that a retry heals
  METHOD config_error_is_config.
    TRY.
        given( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        mo_outcome->mv_no_source = abap_true.
        DATA(ls_result) = act( ).
        DATA(ls_finding) = source_finding( is_result = ls_result iv_code = zif_cd_ops_payout_types=>gc_code-config_failed ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'A configuration finding, an error at once' ).
        cl_abap_unit_assert=>assert_initial(
          act = source_finding( is_result = ls_result iv_code = zif_cd_ops_payout_types=>gc_code-snapshot_failed )
          msg = 'Not reported as a failure to retry' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'Nothing written' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (review 2026-11-10): the bgPF unit carries the package key only - it judges exactly the documents
  " planned for its package, read back by the key
  METHOD unit_reads_members_by_key.
    TRY.
        parameters( iv_parallel = gc_par-parallel iv_package = gc_par-one ).
        given_three_payments( ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_queue->mv_dispatched exp = 3 msg = 'Three units' ).
        cl_abap_unit_assert=>assert_equals( act = mo_outcome->mt_asked
                                            exp = VALUE zif_cd_ops_trace_types=>tt_docno( ( gc_par-doc_a ) ( gc_par-doc_b )
                                                                                           ( gc_par-doc_c ) )
                                            msg = 'Each unit judged the documents of its package' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 3 msg = 'Every payment written once' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (review 2026-11-10): a run deletes the package rows of earlier runs of its own mode only - the
  " rows of a SWEEP run on the same evidence source survive a FAST run
  METHOD packages_deleted_per_mode.
    TRY.
        INSERT VALUE #( run_id = gc_par-sweep_run source = zif_cd_ops_payout_types=>gc_source-documents pkg_no = 1
                        mode   = zif_cd_ops_payout_types=>gc_mode-sweep
                        status = zif_cd_ops_payout_types=>gc_pkg_status-planned ) INTO TABLE mo_dao->mt_packages.
        INSERT VALUE #( run_id = gc_par-fast_run source = zif_cd_ops_payout_types=>gc_source-documents pkg_no = 1
                        mode   = zif_cd_ops_payout_types=>gc_mode-fast
                        status = zif_cd_ops_payout_types=>gc_pkg_status-done ) INTO TABLE mo_dao->mt_packages.
        parameters( iv_parallel = gc_par-parallel iv_package = gc_par-one ).
        given_three_payments( ).
        act( ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_dao->mt_packages[ run_id = gc_par-sweep_run ] ) )
                                          msg = 'The SWEEP rows of the source kept' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( mo_dao->mt_packages[ run_id = gc_par-fast_run ] ) )
                                           msg = 'The earlier FAST rows deleted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (user decision 2026-11-08): a final, clean outcome has no row - the open row of the payment is
  " deleted, no version is closed or written (no history for clean payments)
  METHOD clean_deletes_open_row.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        current_version( is_scenario = ls_scenario iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_deleted ) exp = 1 msg = 'Open row deleted' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_closed msg = 'Nothing closed' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'No CLEARED row' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_versions msg = 'The worklist forgets the payment' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an exception keeps its history - when it closes (clean outcome) the current version is closed
  " and a closing version (valid from = valid to = now) records how it ended; the purge removes it later
  METHOD exception_closes_history.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        current_version( is_scenario = ls_scenario
                         iv_outcome  = zif_cd_ops_payout_types=>gc_outcome-inconsistent
                         iv_finding  = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_closed ) exp = 1 msg = 'Exception closed' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_closed[ 1 ]-valid_to exp = gc_now msg = 'Closed now' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 1 msg = 'One closing version' ).
        DATA(ls_closing) = mo_dao->mt_inserted[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_closing-outcome exp = ls_scenario-expected msg = 'How it ended' ).
        cl_abap_unit_assert=>assert_equals( act = ls_closing-valid_to exp = gc_now msg = 'Closing version is history' ).
        cl_abap_unit_assert=>assert_equals( act = ls_closing-valid_from exp = gc_now msg = 'Valid from = valid to' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_deleted msg = 'History not deleted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an open payment keeps one current row - a change between open outcomes updates it in place
  " (no version, the instant it was first seen kept)
  METHOD open_change_in_place.
    TRY.
        given_payment( iv_outcome = zif_cd_ops_payout_types=>gc_outcome-pending ).
        INSERT VALUE #( bukrs      = zcl_cd_ops_pay_fixture=>gc_bukrs
                        augbl      = gc_new_doc
                        laufd      = ltd_clock=>gc_today
                        laufi      = gc_older_run
                        valid_from = gc_earlier
                        valid_to   = zif_cd_ops_payout_types=>gc_valid_to_open
                        outcome    = zif_cd_ops_payout_types=>gc_outcome-in_flight
                        flow_class = gc_late-key ) INTO TABLE mo_dao->mt_versions.
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_updated ) exp = 1 msg = 'Updated in place' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_updated[ 1 ]-valid_from exp = gc_earlier
                                            msg = 'Open since kept' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_updated[ 1 ]-outcome
                                            exp = zif_cd_ops_payout_types=>gc_outcome-pending msg = 'New outcome' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'No version' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_closed msg = 'No history' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The same open outcome again writes nothing (no row, not even an evaluation time)
  METHOD no_change_writes_nothing.
    TRY.
        given_payment( iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        INSERT VALUE #( bukrs      = zcl_cd_ops_pay_fixture=>gc_bukrs
                        augbl      = gc_new_doc
                        laufd      = ltd_clock=>gc_today
                        laufi      = gc_older_run
                        valid_from = gc_earlier
                        valid_to   = zif_cd_ops_payout_types=>gc_valid_to_open
                        outcome    = zif_cd_ops_payout_types=>gc_outcome-in_flight
                        flow_class = gc_late-key ) INTO TABLE mo_dao->mt_versions.
        act( ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_closed msg = 'Nothing closed' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'Nothing inserted' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_updated msg = 'Nothing updated' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_versions ) exp = 1 msg = 'Still one row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a payment in flight beyond AMBER (late, W) / RED (critical, E) of A_INFLIGHT's AGE_OLDEST is an
  " exception (PAYMENT_NOT_CLEARED) - the same ageing rule as the morning report; within the limit open
  METHOD late_payment_is_exception.
    TRY.
        INSERT VALUE #( check_id = zif_cd_ops_payout_types=>gc_check-inflight
                        metric   = gc_late-metric
                        bukrs    = gc_late-key
                        amber    = gc_late-amber
                        red      = gc_late-red
                        higher_is_worse = abap_true ) INTO TABLE mo_hck->mt_thresholds.
        INSERT VALUE #( flow = zif_cd_hck_runtime_types=>gc_flow-disbursement method_class = gc_late-class
                        age_basis = zif_cd_hck_runtime_types=>gc_age_basis-value_date ) INTO TABLE mo_outcome->ms_config-classes.
        INSERT gc_late-key INTO TABLE mo_outcome->ms_config-watched.
        given_payment( iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight iv_valut = gc_late-five_ago ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 1 msg = 'One row' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-finding
                                            exp = zif_cd_hck_runtime_types=>gc_code-payment_not_clear msg = 'Late: exception' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Beyond RED: critical' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-flow_class exp = gc_late-key
                                            msg = 'Flow + method class of the row' ).
        " The same payment two business days late: AMBER only - the next evaluation versions the change
        CLEAR: mo_outcome->mt_verdicts, mo_dao->mt_inserted, mo_dao->mt_events, mo_dao->mt_watermarks, mo_dao->mt_versions.
        given_payment( iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight iv_valut = gc_late-two_ago ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-warning
                                            msg = 'Beyond AMBER: late' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a payment deleted as clean that gets a returns lot later re-enters through RETURNS although it
  " has no row any more - judged again, an inconsistent return becomes an exception
  METHOD returns_reenter_payment.
    TRY.
        given_payment( iv_source  = zif_cd_ops_payout_types=>gc_source-returns
                       iv_outcome = zif_cd_ops_payout_types=>gc_outcome-inconsistent ).
        act( ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_outcome->mt_asked[ table_line = gc_new_doc ] ) )
                                          msg = 'Judged again through RETURNS' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 1 msg = 'The exception enters' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-finding
                                            exp = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist
                                            msg = 'Inconsistent without own finding: the A_INFLIGHT code' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a payment deleted as clean that is reversed later re-enters through REVERSALS; REVERSED is a
  " final clean outcome - judged, nothing written
  METHOD reversal_reenters_clean.
    TRY.
        given_payment( iv_source  = zif_cd_ops_payout_types=>gc_source-reversals
                       iv_outcome = zif_cd_ops_payout_types=>gc_outcome-reversed ).
        act( ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_outcome->mt_asked[ table_line = gc_new_doc ] ) )
                                          msg = 'Judged again through REVERSALS' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'Clean: no row' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_deleted msg = 'Nothing to delete' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Confirmed status values 2026-11-08: the wire return with status RETURNED is finished - not an
  " exception; its open row goes
  METHOD return_is_finished.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-returned ).
        current_version( is_scenario = ls_scenario iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_deleted ) exp = 1 msg = 'Open row deleted' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'No RETURNED row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The return is on the statement but the status job has not updated DPAYH yet: the outcome stays
  " IN_FLIGHT with the marker PAY_STATUS_PENDING (an exception: A_INFLIGHT reports PAY_STATUS_LAG once
  " HCK_PAY_STATUS_LAG_MIN has passed since its VALID_FROM); the open row is replaced by the version
  METHOD status_pending_marked.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-return_lag ).
        cl_abap_unit_assert=>assert_true( act = mo_outcome->mt_verdicts[ 1 ]-status_pending msg = 'Fixture: status pending' ).
        current_version( is_scenario = ls_scenario iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 1 msg = 'One marked version' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-outcome exp = zif_cd_ops_payout_types=>gc_outcome-in_flight
                                            msg = 'Still in flight' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-finding
                                            exp = zif_cd_ops_payout_types=>gc_code-status_pending msg = 'Marked pending' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_deleted ) exp = 1 msg = 'The open row replaced' ).
        " The same verdict again writes nothing
        CLEAR: mo_dao->mt_inserted, mo_dao->mt_closed, mo_dao->mt_watermarks.
        mo_clock->mv_now = gc_later.
        act( ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'No second version' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (2026-11-08): a payment without an item with a FIN (e.g. a collection) gets one row with FIN
  " and source blank - A_INFLIGHT counts every open payment from the worklist
  METHOD payment_without_fin.
    TRY.
        given_payment( iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 1 msg = 'One row' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted[ 1 ]-fin_id msg = 'FIN blank' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-bukrs exp = zcl_cd_ops_pay_fixture=>gc_bukrs
                                            msg = 'Company code of the payment run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (requests, 2026-11-08): a new request with a SUCCESS attempt enters as an open row (REQ_OPEN, its
  " due date); once its due date has passed unpaid it is an exception REQ_NOT_PAID (versioned)
  METHOD request_open_then_overdue.
    TRY.
        INSERT VALUE #( fin = gc_req-fin source = gc_req-source ) INTO TABLE mo_request->mt_new.
        INSERT VALUE #( fin = gc_req-fin source = gc_req-source due_date = gc_req-tomorrow
                        stage = zif_cd_ops_payout_types=>gc_req_stage-no_item ) INTO TABLE mo_request->mt_requests.
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 1 msg = 'The request enters' ).
        DATA(ls_open) = mo_dao->mt_inserted[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_open-outcome exp = zif_cd_ops_payout_types=>gc_outcome-req_open
                                            msg = 'Open, not due yet' ).
        cl_abap_unit_assert=>assert_initial( act = ls_open-augbl msg = 'A request row has no payment document' ).
        cl_abap_unit_assert=>assert_equals( act = ls_open-due_date exp = gc_req-tomorrow msg = 'Due date stored' ).
        cl_abap_unit_assert=>assert_equals( act = ls_open-evidence_kind exp = zif_cd_ops_payout_types=>gc_req_stage-no_item
                                            msg = 'Stage reached' ).
        " The nightly after the due date: not paid - the open row becomes the exception
        CLEAR: mo_dao->mt_inserted, mo_request->mt_requests.
        INSERT VALUE #( fin = gc_req-fin source = gc_req-source due_date = gc_req-due overdue = abap_true
                        stage = zif_cd_ops_payout_types=>gc_req_stage-not_in_run ) INTO TABLE mo_request->mt_requests.
        act( is_selection = VALUE #( mode = zif_cd_ops_payout_types=>gc_mode-nightly ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 1 msg = 'The exception' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-finding
                                            exp = zif_cd_ops_payout_types=>gc_code-request_not_paid msg = 'PRQ_NOT_PAID' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-severity exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'RED from the morning after the due date' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_deleted ) exp = 1 msg = 'The open row replaced' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a request paid on time is finished - its open row is deleted (clean, no history)
  METHOD request_paid_on_time_gone.
    TRY.
        current_request( zif_cd_ops_payout_types=>gc_outcome-req_open ).
        INSERT VALUE #( fin = gc_req-fin source = gc_req-source finished = abap_true
                        stage = zif_cd_ops_payout_types=>gc_req_stage-paid ) INTO TABLE mo_request->mt_requests.
        act( is_selection = VALUE #( mode = zif_cd_ops_payout_types=>gc_mode-nightly ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_deleted ) exp = 1 msg = 'Open request row deleted' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'No history' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a request paid after its due date closes the exception; the history (closing version
  " REQ_PAID_LATE) is kept 90 days
  METHOD request_paid_late_history.
    TRY.
        current_request( iv_outcome = zif_cd_ops_payout_types=>gc_outcome-req_not_paid
                         iv_finding = zif_cd_ops_payout_types=>gc_code-request_not_paid ).
        INSERT VALUE #( fin = gc_req-fin source = gc_req-source due_date = gc_req-due
                        stage = zif_cd_ops_payout_types=>gc_req_stage-paid_late ) INTO TABLE mo_request->mt_requests.
        act( is_selection = VALUE #( mode = zif_cd_ops_payout_types=>gc_mode-nightly ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_closed ) exp = 1 msg = 'Exception closed' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-outcome
                                            exp = zif_cd_ops_payout_types=>gc_outcome-req_paid_late msg = 'Paid late' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-valid_to exp = gc_now msg = 'History only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: when a payment of a FIN is judged, the open request rows of that FIN are judged with it - a
  " request paid on time leaves the worklist within the same FAST run
  METHOD request_rejudged_with_pay.
    TRY.
        given_three_payments( ).
        INSERT VALUE #( fin_id     = gc_par-fin
                        source     = gc_req-source
                        valid_from = gc_earlier
                        valid_to   = zif_cd_ops_payout_types=>gc_valid_to_open
                        outcome    = zif_cd_ops_payout_types=>gc_outcome-req_open
                        due_date   = gc_req-tomorrow ) INTO TABLE mo_dao->mt_versions.
        act( ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_request->mt_asked[ fin = gc_par-fin ] ) )
                                          msg = 'The request of the FIN judged' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_dao->mt_deleted[ fin_id = gc_par-fin augbl = space ] ) )
                                          msg = 'Paid: the request row goes' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: NIGHTLY re-judges every current row (payments and requests) from its cursors under its own run
  " lock and keeps its cursor in its own watermark - never the FAST evidence sources
  METHOD nightly_rejudges_rows.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-bank_line ).
        CLEAR mo_dao->mt_events.
        current_version( is_scenario = ls_scenario
                         iv_outcome  = zif_cd_ops_payout_types=>gc_outcome-inconsistent
                         iv_finding  = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist ).
        DATA(ls_result) = act( is_selection = VALUE #( mode = zif_cd_ops_payout_types=>gc_mode-nightly ) ).
        cl_abap_unit_assert=>assert_equals( act = mo_lock->mv_variant exp = zif_cd_ops_payout_types=>gc_variant_nightly
                                            msg = 'Own run lock' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_outcome->mt_asked[ table_line = ls_scenario-augbl ] ) )
                                          msg = 'The worklist row judged again' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( mo_dao->mt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-nightly ] ) )
          msg = 'Nightly cursor saved' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( mo_dao->mt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-documents ] ) )
          msg = 'No FAST watermark moved' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-mode exp = zif_cd_ops_payout_types=>gc_mode-nightly msg = 'Mode' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: SWEEP re-reads the chosen evidence sources for its date range, writes what changed and moves
  " no watermark
  METHOD sweep_moves_no_watermark.
    TRY.
        given_payment( iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        DATA(ls_result) = act( is_selection = VALUE #( mode      = zif_cd_ops_payout_types=>gc_mode-sweep
                                        date_from = ltd_clock=>gc_today
                                        date_to   = ltd_clock=>gc_today
                                        sources   = VALUE #( ( zif_cd_ops_payout_types=>gc_source-documents ) ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 1 msg = 'Missed payment written' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_wm_saves exp = 0 msg = 'No watermark moved' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-sources ) exp = 1 msg = 'Only the source chosen' ).
        cl_abap_unit_assert=>assert_equals( act = mo_lock->mv_variant exp = zif_cd_ops_payout_types=>gc_variant_sweep
                                            msg = 'Own run lock' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: SWEEP without a date range (or with a source that cannot be swept) runs nothing and says so
  METHOD sweep_needs_range.
    TRY.
        given_payment( iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        DATA(ls_result) = act( is_selection = VALUE #( mode    = zif_cd_ops_payout_types=>gc_mode-sweep
                                        sources = VALUE #( ( zif_cd_ops_payout_types=>gc_source-recheck ) ) ) ).
        cl_abap_unit_assert=>assert_equals( act = mo_outcome->mv_calls exp = 0 msg = 'Nothing judged' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_ops_payout_types=>gc_code-snapshot_failed ] ) )
          msg = 'Said' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: two current rows of one key (a concurrent FAST and NIGHTLY run) heal at the next evaluation -
  " the newest is kept, the older one retired
  METHOD plan_retires_duplicate.
    DATA lt_close TYPE zif_cd_ops_payout_types=>tt_version.
    DATA lt_insert TYPE zif_cd_ops_payout_types=>tt_version.
    DATA lt_delete TYPE zif_cd_ops_payout_types=>tt_version.
    DATA lt_update TYPE zif_cd_ops_payout_types=>tt_version.
    DATA(ls_newer) = VALUE zif_cd_ops_payout_types=>ty_version( augbl      = gc_new_doc
                                                                valid_from = gc_now
                                                                valid_to   = zif_cd_ops_payout_types=>gc_valid_to_open
                                                                outcome    = zif_cd_ops_payout_types=>gc_outcome-inconsistent
                                                                finding    = zif_cd_hck_runtime_types=>gc_code-clearing_inconsist ).
    DATA(ls_older) = ls_newer.
    ls_older-valid_from = gc_earlier.
    zcl_cd_ops_pay_snapshot=>plan_worklist( EXPORTING it_desired = VALUE #( ( ls_newer ) )
                                                      it_clean   = VALUE #( )
                                                      it_rows    = VALUE #( ( ls_older ) ( ls_newer ) )
                                                      iv_now     = gc_now
                                            IMPORTING et_close   = lt_close
                                                      et_insert  = lt_insert
                                                      et_delete  = lt_delete
                                                      et_update  = lt_update ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_close ) exp = 1 msg = 'The older duplicate closed' ).
    cl_abap_unit_assert=>assert_equals( act = lt_close[ 1 ]-valid_from exp = gc_earlier msg = 'The older one' ).
    cl_abap_unit_assert=>assert_initial( act = lt_insert msg = 'The newest unchanged' ).
    cl_abap_unit_assert=>assert_initial( act = lt_delete msg = 'Exception history never deleted' ).
    cl_abap_unit_assert=>assert_initial( act = lt_update msg = 'No update' ).
  ENDMETHOD.


  " Rule: PAYOUT_PARALLEL 1 behaves as before - no unit dispatched, every package commits its rows and
  " its watermark itself, one after the other
  METHOD serial_never_dispatches.
    TRY.
        parameters( iv_parallel = gc_par-serial iv_package = gc_par-one ).
        given_three_payments( ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_queue->mv_dispatched exp = 0 msg = 'No unit dispatched' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 3 msg = 'Every payment judged' ).
        DATA(lt_documents) = VALUE string_table( ).
        LOOP AT mo_dao->mt_wm_history ASSIGNING FIELD-SYMBOL(<ls_wm>)
             WHERE source = zif_cd_ops_payout_types=>gc_source-documents.
          INSERT CONV #( <ls_wm>-wm_key ) INTO TABLE lt_documents.
        ENDLOOP.
        cl_abap_unit_assert=>assert_equals( act = lt_documents
                                            exp = VALUE string_table( ( CONV #( gc_par-doc_a ) ) ( CONV #( gc_par-doc_b ) )
                                                                      ( CONV #( gc_par-doc_c ) ) )
                                            msg = 'A watermark after every package, in order' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_result-sources[ source = zif_cd_ops_payout_types=>gc_source-documents ]-packages
          exp = gc_par-third msg = 'Three packages' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_packages msg = 'No package rows' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: parallel packages - package 2 of 3 fails: the watermark stands at the end of package 1 and
  " never passes package 2, although package 3 wrote its rows; the next run judges 2 and 3 again
  METHOD failed_middle_holds_wm.
    TRY.
        parameters( iv_parallel = gc_par-parallel iv_package = gc_par-one ).
        given_three_payments( ).
        INSERT gc_par-second INTO TABLE mo_queue->mt_fail.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_queue->mv_dispatched exp = 3 msg = 'Three units dispatched' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_dao->mt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-documents ]-wm_key
          exp = CONV zif_cd_ops_payout_types=>ty_wm_key( gc_par-doc_a )
          msg = 'Watermark at the end of package 1' ).
        LOOP AT mo_dao->mt_wm_history ASSIGNING FIELD-SYMBOL(<ls_wm>)
             WHERE source = zif_cd_ops_payout_types=>gc_source-documents.
          cl_abap_unit_assert=>assert_differs( act = <ls_wm>-wm_key exp = CONV zif_cd_ops_payout_types=>ty_wm_key( gc_par-doc_c )
                                               msg = 'Never past the failed package' ).
        ENDLOOP.
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_dao->mt_inserted[ augbl = gc_par-doc_c ] ) )
                                          msg = 'Package 3 wrote its rows' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( mo_dao->mt_inserted[ augbl = gc_par-doc_b ] ) )
                                           msg = 'The failed package wrote nothing' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_ops_payout_types=>gc_code-snapshot_failed ] ) )
          msg = 'PAY_OUTCOME_FAILED' ).
        " The next run starts after package 1: B and C are judged again (C writes nothing new)
        CLEAR: mo_queue->mt_fail, mo_dao->mt_packages.
        mo_clock->mv_now = gc_later.
        act( ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_dao->mt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-documents ]-wm_key
          exp = CONV zif_cd_ops_payout_types=>ty_wm_key( gc_par-doc_c )
          msg = 'Second run: watermark at the end' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_dao->mt_inserted[ augbl = gc_par-doc_b ] ) )
                                          msg = 'Package 2 judged again' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a package not finished within PAYOUT_PARALLEL_WAIT_SEC is abandoned (its unit writes
  " nothing any more); the watermark stays before it
  METHOD unfinished_package_holds.
    TRY.
        parameters( iv_parallel = gc_par-parallel iv_package = gc_par-one ).
        given_three_payments( ).
        INSERT gc_par-second INTO TABLE mo_queue->mt_hang.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( mo_queue->mv_pauses > 0 ) msg = 'The run waited' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_dao->mt_packages[ pkg_no = gc_par-second ]-status
          exp = zif_cd_ops_payout_types=>gc_pkg_status-abandoned
          msg = 'Package 2 abandoned' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_dao->mt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-documents ]-wm_key
          exp = CONV zif_cd_ops_payout_types=>ty_wm_key( gc_par-doc_a )
          msg = 'Watermark before the abandoned package' ).
        " 2026-11-10: a first failed run of the source is a warning, error from PAYOUT_FAIL_ESCALATE on
        cl_abap_unit_assert=>assert_equals( act = ls_result-run-status exp = zif_cd_ops_types=>gc_run_status-warning
                                            msg = 'Run in warning' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the watermark advances over the leading done packages only
  METHOD contiguous_done_rule.
    DATA(lc_done) = zif_cd_ops_payout_types=>gc_pkg_status-done.
    DATA(lc_failed) = zif_cd_ops_payout_types=>gc_pkg_status-failed.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_pay_snapshot=>contiguous_done( VALUE #( ( lc_done ) ( lc_failed ) ( lc_done ) ) )
                                        exp = 1 msg = 'Failed middle: one' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_pay_snapshot=>contiguous_done( VALUE #( ( lc_done ) ( lc_done ) ) )
                                        exp = 2 msg = 'All done' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_pay_snapshot=>contiguous_done( VALUE #( ( lc_failed ) ( lc_done ) ) )
                                        exp = 0 msg = 'First failed: none' ).
  ENDMETHOD.


  " Rule: the lag is the age of the oldest processed-to instant of the FAST evidence sources (whole
  " minutes); the recheck and the NIGHTLY cursors have no evidence time and do not count
  METHOD lag_oldest_source.
    DATA(lt_watermarks) = VALUE zif_cd_ops_payout_types=>tt_watermark(
      ( source = zif_cd_ops_payout_types=>gc_source-documents   current_to = gc_lag-to_1150 )
      ( source = zif_cd_ops_payout_types=>gc_source-nightly     current_to = gc_lag-to_night )
      ( source = zif_cd_ops_payout_types=>gc_source-nightly_req current_to = gc_lag-to_night )
      ( source = zif_cd_ops_payout_types=>gc_source-recheck     current_to = gc_lag-to_0800 )
      ( source = zif_cd_ops_payout_types=>gc_source-statement   current_to = gc_lag-to_1130 ) ).
    DATA(ls_lag) = zcl_cd_ops_pay_snapshot=>lag( it_watermarks = lt_watermarks iv_now = gc_lag-now ).
    cl_abap_unit_assert=>assert_true( act = ls_lag-known msg = 'Lag known' ).
    cl_abap_unit_assert=>assert_equals( act = ls_lag-minutes exp = gc_lag-minutes msg = '29 whole minutes' ).
    cl_abap_unit_assert=>assert_equals( act = ls_lag-source exp = zif_cd_ops_payout_types=>gc_source-statement
                                        msg = 'The source furthest behind' ).
  ENDMETHOD.


  " Rule: without any processed-to instant the lag is unknown (the snapshot never ran: stale)
  METHOD lag_unknown_without_run.
    DATA(ls_lag) = zcl_cd_ops_pay_snapshot=>lag(
                     it_watermarks = VALUE #( ( source = zif_cd_ops_payout_types=>gc_source-recheck current_to = gc_lag-to_1150 ) )
                     iv_now        = gc_lag-now ).
    cl_abap_unit_assert=>assert_false( act = ls_lag-known msg = 'Unknown: treated as stale' ).
  ENDMETHOD.


  " Only evidence after the watermark is read: the second run judges only the new document and the
  " watermark of the source advances to it
  METHOD watermark_picks_up_new.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        act( ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_outcome->mt_asked[ table_line = ls_scenario-augbl ] ) )
                                          msg = 'First run judges the payment' ).
        " New evidence later the same day
        CLEAR mo_outcome->mt_asked.
        INSERT VALUE #( source  = zif_cd_ops_payout_types=>gc_source-documents
                        wm_date = ltd_clock=>gc_today
                        wm_time = gc_later_time
                        doc     = gc_new_doc ) INTO TABLE mo_dao->mt_events.
        INSERT VALUE #( augbl = gc_new_doc bukrs = zcl_cd_ops_pay_fixture=>gc_bukrs fin = gc_new_fin )
          INTO TABLE mo_dao->mt_items.
        mo_clock->mv_now = gc_later.
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_outcome->mt_asked ) exp = 1 msg = 'Only the new document' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_outcome->mt_asked[ table_line = gc_new_doc ] ) )
                                          msg = 'The new document is judged' ).
        DATA(ls_watermark) = mo_dao->mt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-documents ].
        cl_abap_unit_assert=>assert_equals( act = ls_watermark-wm_key exp = CONV zif_cd_ops_payout_types=>ty_wm_key( gc_new_doc )
                                            msg = 'Watermark at the new document' ).
        cl_abap_unit_assert=>assert_equals( act = ls_watermark-wm_time exp = gc_later_time msg = 'Watermark time' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Two DPAYH runs: the open row of the older run goes, the latest run gets the row
  METHOD newer_run_replaces_older.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-two_runs ).
        mo_outcome->mt_verdicts[ 1 ]-outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight.
        current_version( is_scenario = ls_scenario
                         iv_outcome  = zif_cd_ops_payout_types=>gc_outcome-in_flight
                         iv_laufi    = gc_older_run ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_deleted ) exp = 1 msg = 'Older run row retired' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_deleted[ 1 ]-laufi exp = gc_older_run msg = 'The older run' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-laufi exp = ls_scenario-expected_laufi
                                            msg = 'Row of the latest run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A FIN in two sources: a row per source, both AMBIGUOUS, and one aggregated finding per flow +
  " method class + run date (count of payments, one example line per FIN / source)
  METHOD two_sources_ambiguous_both.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-two_sources ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 2 msg = 'One row per source' ).
        LOOP AT mo_dao->mt_inserted ASSIGNING FIELD-SYMBOL(<ls_version>).
          cl_abap_unit_assert=>assert_equals( act = <ls_version>-outcome exp = ls_scenario-expected
                                              msg = |{ <ls_version>-source }: AMBIGUOUS| ).
        ENDLOOP.
        DATA(lv_findings) = 0.
        LOOP AT ls_result-findings ASSIGNING FIELD-SYMBOL(<ls_finding>)
             WHERE check_code = zif_cd_ops_payout_types=>gc_code-source_ambiguous.
          lv_findings = lv_findings + 1.
          DATA(lt_lines) = VALUE string_table( ).
          SPLIT <ls_finding>-details AT cl_abap_char_utilities=>newline INTO TABLE lt_lines.
          " Examples head, two example lines (FIN / source) and the drill-down line
          cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 4 msg = 'Examples and drill-down' ).
        ENDLOOP.
        cl_abap_unit_assert=>assert_equals( act = lv_findings exp = 1 msg = 'One aggregated finding' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_store->mt_findings ) exp = 1 msg = 'Finding stored' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Test mode judges and counts but writes no row and no watermark
  METHOD test_mode_writes_nothing.
    TRY.
        given_payment( iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        DATA(ls_result) = act( iv_test_mode = abap_true ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'No row' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_wm_saves exp = 0 msg = 'No watermark' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 0 msg = 'No commit' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_result-sources[ source = zif_cd_ops_payout_types=>gc_source-documents ]-inserted
          exp = 1 msg = 'The row that would be written is counted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A capped evidence read could hide evidence: the package writes nothing, the watermark stays
  METHOD capped_read_fails_closed.
    TRY.
        given( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        INSERT VALUE #( check_code = zif_cd_hck_runtime_types=>gc_code-read_capped ) INTO TABLE mo_outcome->mt_findings.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'No row' ).
        cl_abap_unit_assert=>assert_initial(
          act = VALUE #( mo_dao->mt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-documents ]-updated_at OPTIONAL )
          msg = 'Watermark not advanced (only the failed run is counted)' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_ops_payout_types=>gc_code-snapshot_failed ] ) )
          msg = 'PAY_OUTCOME_FAILED reported' ).
        " 2026-11-10: a first failed run is a warning (the next run retries); error from PAYOUT_FAIL_ESCALATE on
        cl_abap_unit_assert=>assert_equals( act = ls_result-run-status exp = zif_cd_ops_types=>gc_run_status-warning
                                            msg = 'Run in warning' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
