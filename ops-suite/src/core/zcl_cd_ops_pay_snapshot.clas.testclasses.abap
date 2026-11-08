*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pay_snapshot.clas.testclasses.abap
*& Purpose:
*& Unit tests of the incremental 5-minute payment outcome snapshot with LTD
*& doubles of the snapshot repository, the evaluator, the store, the run
*& lock and the clock (core injector), payments and outcomes of the shared
*& fixtures (ZCL_CD_OPS_PAY_FIXTURE): an outcome change creates a version
*& (the current one closed), no change writes nothing, the watermark picks
*& up only new evidence and advances, a newer DPAYH run closes the version
*& of the older run, a FIN in two sources is AMBIGUOUS for both with a
*& finding, test mode writes nothing, a capped evidence read fails closed
*& (nothing written, watermark kept). Confirmed status values (2026-11-08):
*& a return with status RETURNED creates the RETURNED version; the same
*& return while the status job has not updated the status stays IN_FLIGHT -
*& no new version because of the status lag. Does not prove live SAP
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
*&---------------------------------------------------------------------*
"! Snapshot repository double: evidence events per source, versions in memory
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
    DATA mv_wm_saves TYPE i.
    "! Package rows (ZCD_PAY_OUTPKG) and every watermark saved, in order
    DATA mt_packages TYPE zif_cd_ops_payout_types=>tt_package.
    DATA mt_wm_history TYPE STANDARD TABLE OF zif_cd_ops_payout_types=>ty_watermark WITH EMPTY KEY.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_ops_pay_outcome_dao~get_watermarks.
    rt_watermarks = mt_watermarks.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~save_watermark.
    mv_wm_saves = mv_wm_saves + 1.
    DELETE mt_watermarks WHERE source = is_watermark-source.
    INSERT is_watermark INTO TABLE mt_watermarks.
    INSERT is_watermark INTO TABLE mt_wm_history.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~get_changes.
    DATA lt_new LIKE mt_events.
    rs_changes-watermark = is_watermark.
    LOOP AT mt_events ASSIGNING FIELD-SYMBOL(<ls_event>) WHERE source = iv_source.
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

  METHOD zif_cd_ops_pay_outcome_dao~get_open_versions.
    LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ls_version>)
         WHERE valid_to = zif_cd_ops_payout_types=>gc_valid_to_open.
      IF line_exists( it_docno[ table_line = <ls_version>-augbl ] ).
        INSERT <ls_version> INTO TABLE rt_versions.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~save_packages.
    LOOP AT it_packages ASSIGNING FIELD-SYMBOL(<ls_package>).
      DATA(ls_row) = <ls_package>.
      ls_row-status = zif_cd_ops_payout_types=>gc_pkg_status-planned.
      ls_row-documents = lines( ls_row-docno ).
      CLEAR ls_row-docno.
      INSERT ls_row INTO TABLE mt_packages.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~claim_package.
    rv_claimed = xsdbool( VALUE #( mt_packages[ source = is_package-source pkg_no = is_package-pkg_no ]-status OPTIONAL )
                          = zif_cd_ops_payout_types=>gc_pkg_status-planned ).
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~finish_package.
    READ TABLE mt_packages ASSIGNING FIELD-SYMBOL(<ls_row>)
         WITH KEY source = is_package-source pkg_no = is_package-pkg_no.
    IF sy-subrc = 0.
      <ls_row>-status    = is_package-status.
      <ls_row>-evaluated = is_package-evaluated.
      <ls_row>-inserted  = is_package-inserted.
      <ls_row>-closed    = is_package-closed.
      <ls_row>-message   = is_package-message.
    ENDIF.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~get_packages.
    rt_packages = mt_packages.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~abandon_packages.
    LOOP AT mt_packages ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE status = zif_cd_ops_payout_types=>gc_pkg_status-planned.
      <ls_row>-status = zif_cd_ops_payout_types=>gc_pkg_status-abandoned.
      rv_count = rv_count + 1.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~delete_packages.
    DATA(lv_before) = lines( mt_packages ).
    DELETE mt_packages WHERE run_id <> iv_keep_run_id.
    rv_count = lv_before - lines( mt_packages ).
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~get_new_versions.
    LOOP AT mt_inserted ASSIGNING FIELD-SYMBOL(<ls_version>)
         WHERE valid_from = iv_valid_from AND finding = iv_finding.
      INSERT VALUE #( version = <ls_version> pymet = zcl_cd_ops_pay_fixture=>gc_wire ) INTO TABLE rt_versions.
    ENDLOOP.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~save_versions.
    LOOP AT it_close ASSIGNING FIELD-SYMBOL(<ls_close>).
      LOOP AT mt_versions ASSIGNING FIELD-SYMBOL(<ls_version>)
           WHERE fin_id = <ls_close>-fin_id AND source = <ls_close>-source AND bukrs = <ls_close>-bukrs
             AND augbl = <ls_close>-augbl AND laufd = <ls_close>-laufd AND laufi = <ls_close>-laufi
             AND valid_from = <ls_close>-valid_from.
        <ls_version>-valid_to = <ls_close>-valid_to.
      ENDLOOP.
    ENDLOOP.
    INSERT LINES OF it_close INTO TABLE mt_closed.
    INSERT LINES OF it_insert INTO TABLE mt_inserted.
    INSERT LINES OF it_insert INTO TABLE mt_versions.
  ENDMETHOD.
ENDCLASS.


"! Evaluator double: verdicts per document and sources per FIN; FOR_SOURCE is the real rule
CLASS ltd_outcome DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_outcome PARTIALLY IMPLEMENTED.
    DATA mt_verdicts TYPE zif_cd_ops_payout_types=>tt_verdict.
    DATA mt_sources TYPE zif_cd_ops_payout_types=>tt_fin_source.
    DATA mt_findings TYPE zif_cd_ops_types=>tt_finding.
    "! Documents asked for, per call
    DATA mt_asked TYPE zif_cd_ops_trace_types=>tt_docno.
    DATA mv_calls TYPE i.
ENDCLASS.

CLASS ltd_outcome IMPLEMENTATION.
  METHOD zif_cd_ops_pay_outcome~load.
    CLEAR rs_config.
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
    NEW zcl_cd_ops_pay_snap_op( is_package )->if_bgmc_op_single_tx_uncontr~execute( ).
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
ENDCLASS.

CLASS ltd_lock IMPLEMENTATION.
  METHOD zif_cd_ops_lock~acquire.
    CLEAR ev_holder.
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
        one       TYPE string VALUE `1`,
        wait_sec  TYPE string VALUE `30`,
        second    TYPE i VALUE 2,
        third     TYPE i VALUE 3,
      END OF gc_par.
    "! Snapshot lag: two sources processed to 11:50 and 11:30, recheck far behind, now 12:00
    CONSTANTS:
      BEGIN OF gc_lag,
        now       TYPE timestampl VALUE '20261111120000',
        to_1150   TYPE timestampl VALUE '20261111115000',
        to_1130   TYPE timestampl VALUE '20261111113015',
        to_0800   TYPE timestampl VALUE '20261111080000',
        minutes   TYPE i VALUE 29,
      END OF gc_lag.

    DATA mo_fixture TYPE REF TO zcl_cd_ops_pay_fixture.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_outcome TYPE REF TO ltd_outcome.
    DATA mo_store TYPE REF TO ltd_store.
    DATA mo_clock TYPE REF TO ltd_clock.
    DATA mo_queue TYPE REF TO ltd_queue.

    METHODS setup.
    METHODS teardown.

    METHODS change_creates_version     FOR TESTING.
    METHODS no_change_writes_nothing   FOR TESTING.
    METHODS watermark_picks_up_new     FOR TESTING.
    METHODS newer_run_closes_older     FOR TESTING.
    METHODS two_sources_ambiguous_both FOR TESTING.
    METHODS test_mode_writes_nothing   FOR TESTING.
    METHODS capped_read_fails_closed   FOR TESTING.
    METHODS return_creates_version     FOR TESTING.
    METHODS status_pending_marked      FOR TESTING.
    METHODS payment_without_fin        FOR TESTING.
    METHODS serial_never_dispatches    FOR TESTING.
    METHODS failed_middle_holds_wm     FOR TESTING.
    METHODS unfinished_package_holds   FOR TESTING.
    METHODS contiguous_done_rule       FOR TESTING.
    METHODS lag_oldest_source          FOR TESTING.
    METHODS lag_unknown_without_run    FOR TESTING.

    "! Parameters of the run: parallel packages, package size, wait (seed values, else delivered)
    METHODS parameters
      IMPORTING
        iv_parallel TYPE string
        iv_package  TYPE string OPTIONAL.

    "! Three payments A, B, C as DOCUMENTS evidence, each with a FIN item and a CLEARED verdict
    METHODS given_three_payments.

    "! Scenario of the shared fixture: its payment as evidence of DOCUMENTS, its item, its sources
    "! and the evaluator's verdict
    METHODS given
      IMPORTING
        iv_id              TYPE zcl_cd_ops_pay_fixture=>ty_scenario_id
      RETURNING
        VALUE(rs_scenario) TYPE zcl_cd_ops_pay_fixture=>ty_scenario.

    "! A current version of the scenario's payment (written by an earlier run)
    METHODS current_version
      IMPORTING
        is_scenario TYPE zcl_cd_ops_pay_fixture=>ty_scenario
        iv_outcome  TYPE zif_cd_ops_payout_types=>ty_outcome
        iv_laufi    TYPE clike OPTIONAL.

    METHODS act
      IMPORTING
        iv_test_mode     TYPE abap_bool DEFAULT abap_false
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
    mo_store = NEW #( ).
    mo_clock = NEW #( ).
    mo_queue = NEW #( ).
    mo_queue->mo_dao = mo_dao.
    zcl_cd_ops_injector=>inject_pay_snap_queue( mo_queue ).
    zcl_cd_ops_injector=>inject_pay_outcome_dao( mo_dao ).
    zcl_cd_ops_injector=>inject_pay_outcome( mo_outcome ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
    zcl_cd_ops_injector=>inject_lock( NEW ltd_lock( ) ).
    zcl_cd_ops_injector=>inject_clock( mo_clock ).
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
                      outcome = zif_cd_ops_payout_types=>gc_outcome-cleared ) INTO TABLE mo_outcome->mt_verdicts.
    ENDLOOP.
    INSERT VALUE #( fin = gc_par-fin source = zcl_cd_ops_pay_fixture=>gc_source-pclm sources = 1 )
      INTO TABLE mo_outcome->mt_sources.
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_hck_injector=>reset( ).
    CLEAR: mo_fixture, mo_dao, mo_outcome, mo_store, mo_clock, mo_queue.
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
                    outcome = rs_scenario-evaluated
                    status_pending = rs_scenario-status_pending ) INTO TABLE mo_outcome->mt_verdicts.
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
                    outcome    = iv_outcome ) INTO TABLE mo_dao->mt_versions.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_ops_pay_snapshot( )->run( iv_test_mode ).
  ENDMETHOD.


  " An outcome change (IN_FLIGHT -> CLEARED) closes the current version and creates a new one
  METHOD change_creates_version.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        current_version( is_scenario = ls_scenario iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_closed ) exp = 1 msg = 'Current version closed' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_closed[ 1 ]-valid_to exp = gc_now msg = 'Closed now' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 1 msg = 'One new version' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-outcome exp = ls_scenario-expected
                                            msg = 'New version CLEARED' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-valid_from exp = gc_now msg = 'Valid from now' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-valid_to
                                            exp = zif_cd_ops_payout_types=>gc_valid_to_open msg = 'Open end' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Confirmed status values 2026-11-08: the wire return with status RETURNED replaces IN_FLIGHT by a
  " RETURNED version
  METHOD return_creates_version.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-returned ).
        current_version( is_scenario = ls_scenario iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_closed ) exp = 1 msg = 'IN_FLIGHT closed' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 1 msg = 'One new version' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-outcome exp = zif_cd_ops_payout_types=>gc_outcome-returned
                                            msg = 'RETURNED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The return is on the statement but the status job has not updated DPAYH yet: the outcome stays
  " IN_FLIGHT; the version is marked PAY_STATUS_PENDING (2026-11-08, was: no version) - A_INFLIGHT
  " reports PAY_STATUS_LAG once HCK_PAY_STATUS_LAG_MIN has passed since its VALID_FROM
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
        " The same verdict again writes nothing
        CLEAR: mo_dao->mt_inserted, mo_dao->mt_closed, mo_dao->mt_watermarks.
        mo_clock->mv_now = gc_later.
        act( ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'No second version' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (2026-11-08): a payment without an item with a FIN (e.g. a collection) gets one version with
  " FIN and source blank - A_INFLIGHT counts every payment from the table
  METHOD payment_without_fin.
    TRY.
        INSERT VALUE #( source  = zif_cd_ops_payout_types=>gc_source-documents
                        wm_date = ltd_clock=>gc_today
                        wm_time = gc_event_time
                        doc     = gc_new_doc ) INTO TABLE mo_dao->mt_events.
        INSERT VALUE #( doc1r   = gc_new_doc
                        laufd   = ltd_clock=>gc_today
                        laufi   = gc_older_run
                        bukrs   = zcl_cd_ops_pay_fixture=>gc_bukrs
                        outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ) INTO TABLE mo_outcome->mt_verdicts.
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 1 msg = 'One version' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted[ 1 ]-fin_id msg = 'FIN blank' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-bukrs exp = zcl_cd_ops_pay_fixture=>gc_bukrs
                                            msg = 'Company code of the payment run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: PAYOUT_PARALLEL 1 behaves as before - no unit dispatched, every package commits its
  " versions and its watermark itself, one after the other
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
  " never passes package 2, although package 3 wrote its versions; the next run judges 2 and 3 again
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
                                          msg = 'Package 3 wrote its versions' ).
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
        cl_abap_unit_assert=>assert_equals( act = ls_result-run-status exp = zif_cd_ops_types=>gc_run_status-error
                                            msg = 'Run in error' ).
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


  " Rule: the lag is the age of the oldest processed-to instant of the evidence sources (whole
  " minutes); the recheck has no time and does not count
  METHOD lag_oldest_source.
    DATA(lt_watermarks) = VALUE zif_cd_ops_payout_types=>tt_watermark(
      ( source = zif_cd_ops_payout_types=>gc_source-documents current_to = gc_lag-to_1150 )
      ( source = zif_cd_ops_payout_types=>gc_source-recheck   current_to = gc_lag-to_0800 )
      ( source = zif_cd_ops_payout_types=>gc_source-statement current_to = gc_lag-to_1130 ) ).
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


  " The same outcome again writes nothing (no version, not even an evaluation time)
  METHOD no_change_writes_nothing.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        current_version( is_scenario = ls_scenario iv_outcome = ls_scenario-expected ).
        act( ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_closed msg = 'Nothing closed' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'Nothing inserted' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_versions ) exp = 1 msg = 'Still one version' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
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


  " Two DPAYH runs: the version of the older run is closed, the latest run gets the version
  METHOD newer_run_closes_older.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-two_runs ).
        current_version( is_scenario = ls_scenario
                         iv_outcome  = zif_cd_ops_payout_types=>gc_outcome-in_flight
                         iv_laufi    = gc_older_run ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_closed ) exp = 1 msg = 'Older run closed' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_closed[ 1 ]-laufi exp = gc_older_run msg = 'The older run' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mt_inserted[ 1 ]-laufi exp = ls_scenario-expected_laufi
                                            msg = 'Version of the latest run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A FIN in two sources: a version per source, both AMBIGUOUS, and one aggregated finding per flow +
  " method class + run date (count of payments, one example line per FIN / source)
  METHOD two_sources_ambiguous_both.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-two_sources ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->mt_inserted ) exp = 2 msg = 'One version per source' ).
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


  " Test mode judges and counts but writes no version and no watermark
  METHOD test_mode_writes_nothing.
    TRY.
        given( zcl_cd_ops_pay_fixture=>gc_scenario-success_old ).
        DATA(ls_result) = act( abap_true ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'No version' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_wm_saves exp = 0 msg = 'No watermark' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 0 msg = 'No commit' ).
        cl_abap_unit_assert=>assert_equals(
          act = ls_result-sources[ source = zif_cd_ops_payout_types=>gc_source-documents ]-inserted
          exp = 1 msg = 'The version that would be written is counted' ).
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
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'No version' ).
        cl_abap_unit_assert=>assert_false(
          act = xsdbool( line_exists( mo_dao->mt_watermarks[ source = zif_cd_ops_payout_types=>gc_source-documents ] ) )
          msg = 'Watermark not advanced' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( ls_result-findings[ check_code = zif_cd_ops_payout_types=>gc_code-snapshot_failed ] ) )
          msg = 'PAY_OUTCOME_FAILED reported' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-run-status exp = zif_cd_ops_types=>gc_run_status-error
                                            msg = 'Run in error' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
