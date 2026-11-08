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
*&---------------------------------------------------------------------*
"! Snapshot repository double: evidence events per source, versions in memory
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_pay_outcome_dao.
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
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_ops_pay_outcome_dao~get_watermarks.
    rt_watermarks = mt_watermarks.
  ENDMETHOD.

  METHOD zif_cd_ops_pay_outcome_dao~save_watermark.
    mv_wm_saves = mv_wm_saves + 1.
    DELETE mt_watermarks WHERE source = is_watermark-source.
    INSERT is_watermark INTO TABLE mt_watermarks.
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
      IF line_exists( it_fin[ table_line = <ls_version>-fin_id ] ).
        INSERT <ls_version> INTO TABLE rt_versions.
      ENDIF.
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

    DATA mo_fixture TYPE REF TO zcl_cd_ops_pay_fixture.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_outcome TYPE REF TO ltd_outcome.
    DATA mo_store TYPE REF TO ltd_store.
    DATA mo_clock TYPE REF TO ltd_clock.

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
    METHODS status_lag_no_new_version  FOR TESTING.

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
    zcl_cd_ops_injector=>inject_pay_outcome_dao( mo_dao ).
    zcl_cd_ops_injector=>inject_pay_outcome( mo_outcome ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
    zcl_cd_ops_injector=>inject_lock( NEW ltd_lock( ) ).
    zcl_cd_ops_injector=>inject_clock( mo_clock ).
    zcl_cd_ops_injector=>inject_params( NEW zcl_cd_ops_param_seed( )->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_hck_injector=>reset( ).
    CLEAR: mo_fixture, mo_dao, mo_outcome, mo_store, mo_clock.
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


  " The return is on the statement but the status job has not updated DPAYH yet: the verdict stays
  " IN_FLIGHT (status pending) - the snapshot writes no version because of the lag (the morning
  " report's PAY_STATUS_LAG reports it after the grace period)
  METHOD status_lag_no_new_version.
    TRY.
        DATA(ls_scenario) = given( zcl_cd_ops_pay_fixture=>gc_scenario-return_lag ).
        cl_abap_unit_assert=>assert_true( act = mo_outcome->mt_verdicts[ 1 ]-status_pending msg = 'Fixture: status pending' ).
        current_version( is_scenario = ls_scenario iv_outcome = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        act( ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_closed msg = 'Nothing closed' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->mt_inserted msg = 'No version because of the lag' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
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


  " A FIN in two sources: a version per source, both AMBIGUOUS, and a finding for each
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
        LOOP AT ls_result-findings TRANSPORTING NO FIELDS
             WHERE check_code = zif_cd_ops_payout_types=>gc_code-source_ambiguous.
          lv_findings = lv_findings + 1.
        ENDLOOP.
        cl_abap_unit_assert=>assert_equals( act = lv_findings exp = 2 msg = 'A finding per source' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_store->mt_findings ) exp = 2 msg = 'Findings stored' ).
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
