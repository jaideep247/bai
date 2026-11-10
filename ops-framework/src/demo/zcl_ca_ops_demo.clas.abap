*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_demo.clas.abap
*& Purpose:
*& Demo consumer of the operations framework (optional sub-package
*& ZCA_OPS_DEMO, not needed in production): one run of area CA_DEMO through
*& the framework - authorisation ZCA_OPS execute (16) for the area, start
*& the run (durable before anything else), count background jobs of the
*& last 24 hours (TBTCO, read only), write the findings (information: jobs
*& ended; error = open exception: jobs cancelled; warning: released jobs
*& late), reconcile, finish, commit, dispatch the alert rules of the area.
*& A technical error closes the run as aborted (ZCL_CA_OPS_RUN_GUARD).
*& Test mode (default): nothing is written and no alert is sent. Sample
*& mode writes the error and the warning even when their count is 0.
*& Modification log:
*& 2026-11-10 | Initial version (demo consumer of the operations framework).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework demo - job check of area CA_DEMO</p>
CLASS zcl_ca_ops_demo DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! io_dao = a double in the unit tests (default: the TBTCO reader)
    METHODS constructor
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_demo_dao OPTIONAL.

    "! One run of area CA_DEMO; returns the run header, the counts and the findings written
    METHODS run
      IMPORTING
        iv_test_mode     TYPE abap_bool DEFAULT abap_true
        iv_sample        TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_demo_types=>ty_result
      RAISING
        zcx_ca_ops_error.

  PRIVATE SECTION.
    DATA mo_dao TYPE REF TO zif_ca_ops_demo_dao.

    "! Job counts of the window that ends now
    METHODS counts
      RETURNING
        VALUE(rs_counts) TYPE zif_ca_ops_demo_types=>ty_counts.

    METHODS findings
      IMPORTING
        is_counts          TYPE zif_ca_ops_demo_types=>ty_counts
        iv_sample          TYPE abap_bool
      RETURNING
        VALUE(rt_findings) TYPE zif_ca_ops_types=>tt_finding.

    METHODS finding
      IMPORTING
        iv_check_code     TYPE zif_ca_ops_types=>ty_check_code
        iv_severity       TYPE zif_ca_ops_types=>ty_severity
        iv_message        TYPE string
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! Counts, status, RAG and runtime of the finished run
    METHODS close
      IMPORTING
        it_findings TYPE zif_ca_ops_types=>tt_finding
        is_counts   TYPE zif_ca_ops_demo_types=>ty_counts
      CHANGING
        cs_run      TYPE zif_ca_ops_types=>ty_run.

ENDCLASS.



CLASS zcl_ca_ops_demo IMPLEMENTATION.

  METHOD constructor.
    mo_dao = COND #( WHEN io_dao IS BOUND THEN io_dao ELSE NEW zcl_ca_ops_demo_dao( ) ).
  ENDMETHOD.


  METHOD run.
    zcl_ca_ops_factory=>get_auth( )->check( iv_activity = zif_ca_ops_auth=>gc_activity-execute
                                            iv_area     = zif_ca_ops_demo_types=>gc_area ).
    DATA(lo_store) = zcl_ca_ops_factory=>get_store( ).
    rs_result-run = lo_store->start_run( iv_area      = zif_ca_ops_demo_types=>gc_area
                                         iv_variant   = zif_ca_ops_demo_types=>gc_variant
                                         iv_test_mode = iv_test_mode ).
    " the run header is durable before anything can fail or notify
    lo_store->commit( ).
    TRY.
        rs_result-counts = counts( ).
        rs_result-findings = findings( is_counts = rs_result-counts
                                       iv_sample = iv_sample ).
        lo_store->save_findings( EXPORTING it_findings = rs_result-findings
                                 CHANGING  cs_run      = rs_result-run ).
        " an exception of an earlier run that this run no longer raises is resolved
        lo_store->reconcile( is_run         = rs_result-run
                             it_object_keys = VALUE #( ( zif_ca_ops_demo_types=>gc_object_key ) ) ).
        close( EXPORTING it_findings = rs_result-findings
                         is_counts   = rs_result-counts
               CHANGING  cs_run      = rs_result-run ).
        lo_store->finish_run( rs_result-run ).
        lo_store->commit( ).
        " the alert rules of area CA_DEMO (and of *) decide who hears about it; none in test mode
        zcl_ca_ops_factory=>get_alert( )->dispatch( is_run      = rs_result-run
                                                    it_findings = rs_result-findings ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        zcl_ca_ops_run_guard=>abort( EXPORTING ix_error = lx_error
                                     CHANGING  cs_run   = rs_result-run ).
        RAISE EXCEPTION lx_error.
    ENDTRY.
  ENDMETHOD.


  METHOD counts.
    DATA(lo_clock) = zcl_ca_ops_factory=>get_clock( ).
    DATA ls_now TYPE zif_ca_ops_demo_types=>ty_moment.
    DATA ls_from TYPE zif_ca_ops_demo_types=>ty_moment.
    DATA ls_late TYPE zif_ca_ops_demo_types=>ty_moment.

    ls_now-date = lo_clock->today( ).
    ls_now-time = lo_clock->time( ).
    " the window is whole days of hours back from now (24 h: same time yesterday)
    ls_from-date = ls_now-date - zif_ca_ops_demo_types=>gc_window_hours DIV zif_ca_ops_demo_types=>gc_hours_per_day.
    ls_from-time = ls_now-time.
    " a released job is late once its planned start lies this long in the past (time wraps at midnight)
    DATA(lv_late_seconds) = zif_ca_ops_demo_types=>gc_late_minutes * zif_ca_ops_demo_types=>gc_seconds_per_minute.
    ls_late-time = ls_now-time - lv_late_seconds.
    ls_late-date = COND #( WHEN ls_now-time < lv_late_seconds THEN ls_now-date - 1 ELSE ls_now-date ).

    rs_counts-ended = mo_dao->count_ended( iv_status = zif_ca_ops_demo_types=>gc_job_status-finished
                                           is_from   = ls_from
                                           is_to     = ls_now ).
    rs_counts-aborted = mo_dao->count_ended( iv_status = zif_ca_ops_demo_types=>gc_job_status-aborted
                                             is_from   = ls_from
                                             is_to     = ls_now ).
    rs_counts-late = mo_dao->count_planned( iv_status = zif_ca_ops_demo_types=>gc_job_status-released
                                            is_from   = ls_from
                                            is_to     = ls_late ).
  ENDMETHOD.


  METHOD findings.
    INSERT finding( iv_check_code = zif_ca_ops_demo_types=>gc_check-ended
                    iv_severity   = zif_ca_ops_types=>gc_severity-info
                    iv_message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_demo_types=>gc_msg-ended
                                                           iv_v1    = zif_ca_ops_demo_types=>gc_window_hours
                                                           iv_v2    = is_counts-ended
                                                           iv_v3    = is_counts-aborted
                                                           iv_v4    = is_counts-late ) )
           INTO TABLE rt_findings.
    IF is_counts-aborted > 0 OR iv_sample = abap_true.
      INSERT finding( iv_check_code = zif_ca_ops_demo_types=>gc_check-aborted
                      iv_severity   = zif_ca_ops_types=>gc_severity-error
                      iv_message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_demo_types=>gc_msg-aborted
                                                             iv_v1    = is_counts-aborted
                                                             iv_v2    = zif_ca_ops_demo_types=>gc_window_hours ) )
             INTO TABLE rt_findings.
    ENDIF.
    IF is_counts-late > 0 OR iv_sample = abap_true.
      INSERT finding( iv_check_code = zif_ca_ops_demo_types=>gc_check-late
                      iv_severity   = zif_ca_ops_types=>gc_severity-warning
                      iv_message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_demo_types=>gc_msg-late
                                                             iv_v1    = is_counts-late
                                                             iv_v2    = zif_ca_ops_demo_types=>gc_late_minutes ) )
             INTO TABLE rt_findings.
    ENDIF.
  ENDMETHOD.


  METHOD finding.
    rs_finding-object_type = zif_ca_ops_demo_types=>gc_object_type.
    rs_finding-object_key  = zif_ca_ops_demo_types=>gc_object_key.
    rs_finding-rule_id     = zif_ca_ops_demo_types=>gc_rule_id.
    rs_finding-check_code  = iv_check_code.
    rs_finding-severity    = iv_severity.
    rs_finding-action      = COND #( WHEN iv_severity = zif_ca_ops_types=>gc_severity-info
                                     THEN zif_ca_ops_types=>gc_action-notify
                                     ELSE zif_ca_ops_types=>gc_action-exception ).
    rs_finding-message     = iv_message.
  ENDMETHOD.


  METHOD close.
    DATA(lv_rank) = zcl_ca_ops_util=>severity_rank( zcl_ca_ops_util=>worst_severity( it_findings ) ).
    cs_run-total_items   = is_counts-ended + is_counts-aborted + is_counts-late.
    cs_run-failed_items  = is_counts-aborted.
    cs_run-warning_items = is_counts-late.
    cs_run-passed_items  = is_counts-ended.
    cs_run-rag           = zcl_ca_ops_util=>rag_from_findings( it_findings ).
    cs_run-status        = COND #( WHEN lv_rank >= 3 THEN zif_ca_ops_types=>gc_run_status-error
                                   WHEN lv_rank = 2  THEN zif_ca_ops_types=>gc_run_status-warning
                                   ELSE zif_ca_ops_types=>gc_run_status-success ).
    cs_run-ended_at      = zcl_ca_ops_factory=>get_clock( )->now( ).
    cs_run-runtime_ms    = zcl_ca_ops_util=>elapsed_ms( iv_from = cs_run-started_at
                                                        iv_to   = cs_run-ended_at ).
  ENDMETHOD.

ENDCLASS.
