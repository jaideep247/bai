*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_xrun_monitor.clas.testclasses.abap
*& Purpose:
*& Rules of the comparison of expected runs with SAP jobs: started in time
*& = OK; started after the late limit = LATE with its minutes; before the
*& planned start or within the late minutes = PENDING; due without a job =
*& NEVER at stage SCHEDULER (the scheduler did not start it), HANDOVER (it
*& says it ran: failed before SAP) or SAP_QUEUE (the SAP job waits); due
*& with an unfinished predecessor of the same day = PRED_OPEN; held at the
*& scheduler = HELD; a job serves one run only and only inside its window;
*& patterns completed from the scheduler row, unusable ones set apart; the
*& job reads with their cap. Doubles: job monitor data access.
*& Modification log:
*& 2026-11-16 | Initial version (build P: expected runs from the scheduler).
*&---------------------------------------------------------------------*
CLASS ltd_xrun_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_dao PARTIALLY IMPLEMENTED.
    DATA mt_running TYPE zif_ca_ops_job_types=>tt_job.
    DATA mt_waiting TYPE zif_ca_ops_job_types=>tt_job.
    DATA mt_sched TYPE zif_ca_ops_job_types=>tt_sched.
ENDCLASS.

CLASS ltd_xrun_dao IMPLEMENTATION.
  METHOD zif_ca_ops_job_dao~jobs_running.
    rt_jobs = mt_running.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~waiting_jobs.
    rt_jobs = mt_waiting.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~scheduler_jobs.
    rt_sched = mt_sched.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_xrun_monitor DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        today   TYPE d VALUE '20261116',
        folder  TYPE zif_ca_ops_job_types=>ty_sched_folder VALUE 'ZT_FOLDER',
        prep    TYPE zif_ca_ops_job_types=>ty_sched_job VALUE 'ZT_PAY_PREP',
        payrun  TYPE zif_ca_ops_job_types=>ty_sched_job VALUE 'ZT_PAY_RUN',
        pattern TYPE zif_ca_ops_types=>ty_object_key VALUE 'ZT_PAYPREP.*',
      END OF gc.

    METHODS config
      RETURNING
        VALUE(rs_config) TYPE zif_ca_ops_xrun_types=>ty_config.
    METHODS run
      IMPORTING
        iv_job        TYPE zif_ca_ops_job_types=>ty_sched_job DEFAULT gc-prep
        iv_time       TYPE t DEFAULT '060000'
        iv_state      TYPE zif_ca_ops_xrun_types=>ty_sched_state OPTIONAL
        iv_pattern    TYPE zif_ca_ops_types=>ty_object_key DEFAULT gc-pattern
      RETURNING
        VALUE(rs_run) TYPE zif_ca_ops_xrun_types=>ty_expected.
    METHODS job
      IMPORTING
        iv_name       TYPE btcjob DEFAULT 'ZT_PAYPREP_DAILY'
        iv_count      TYPE btcjobcnt DEFAULT '06000001'
        iv_status     TYPE zif_ca_ops_job_types=>ty_status
        iv_start      TYPE t OPTIONAL
        iv_planned    TYPE t OPTIONAL
      RETURNING
        VALUE(rs_job) TYPE zif_ca_ops_job_types=>ty_job.
    METHODS judge_one
      IMPORTING
        is_run           TYPE zif_ca_ops_xrun_types=>ty_expected
        it_jobs          TYPE zif_ca_ops_job_types=>tt_job OPTIONAL
        iv_now           TYPE t DEFAULT '090000'
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_xrun_types=>ty_result.

    METHODS started_in_time_is_ok        FOR TESTING.
    METHODS started_after_limit_is_late  FOR TESTING.
    METHODS before_due_is_pending        FOR TESTING.
    METHODS no_job_scheduler_stage       FOR TESTING.
    METHODS scheduler_ran_no_sap_job     FOR TESTING.
    METHODS waiting_sap_job_queue_stage  FOR TESTING.
    METHODS predecessor_open             FOR TESTING.
    METHODS predecessor_done_by_state    FOR TESTING.
    METHODS held_after_planned_start     FOR TESTING.
    METHODS job_outside_window_ignored   FOR TESTING.
    METHODS one_job_serves_one_run       FOR TESTING.
    METHODS patterns_from_scheduler_row  FOR TESTING.
    METHODS reads_capped                 FOR TESTING.
ENDCLASS.


CLASS ltc_xrun_monitor IMPLEMENTATION.

  METHOD config.
    rs_config = VALUE #( late_min = 30 early_min = 60 match_min = 720 max_jobs = 100 ).
  ENDMETHOD.


  METHOD run.
    rs_run = VALUE #( source_id    = 'JOBSCH'
                      sched_folder = gc-folder
                      sched_job    = iv_job
                      sap_pattern  = iv_pattern
                      plan_date    = gc-today
                      plan_time    = iv_time
                      sched_state  = iv_state ).
  ENDMETHOD.


  METHOD job.
    rs_job = VALUE #( jobname = iv_name jobcount = iv_count status = iv_status ).
    IF iv_start IS NOT INITIAL.
      rs_job-strtdate = gc-today.
      rs_job-strttime = iv_start.
    ENDIF.
    IF iv_planned IS NOT INITIAL.
      rs_job-sdlstrtdt = gc-today.
      rs_job-sdlstrttm = iv_planned.
    ENDIF.
  ENDMETHOD.


  METHOD judge_one.
    DATA(lt_results) = zcl_ca_ops_xrun_monitor=>judge( it_runs   = VALUE #( ( is_run ) )
                                                       it_jobs   = it_jobs
                                                       is_config = config( )
                                                       is_now    = VALUE #( date = gc-today time = iv_now ) ).
    rs_result = lt_results[ 1 ].
  ENDMETHOD.


  " Rule: a job of the run's names started before the late limit (06:00 + 30 minutes)
  METHOD started_in_time_is_ok.
    DATA(ls_result) = judge_one( is_run  = run( )
                                 it_jobs = VALUE #( ( job( iv_status = 'F' iv_start = '061000' ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_ca_ops_xrun_types=>gc_verdict-ok ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-job-jobcount exp = '06000001' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-late_minutes exp = 10 ).
  ENDMETHOD.


  " Rule: started 07:15 for 06:00 + 30 = late by 75 minutes after the planned start
  METHOD started_after_limit_is_late.
    DATA(ls_result) = judge_one( is_run  = run( )
                                 it_jobs = VALUE #( ( job( iv_status = 'R' iv_start = '071500' ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_ca_ops_xrun_types=>gc_verdict-started_late ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-stage exp = zif_ca_ops_xrun_types=>gc_stage-late_start ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-late_minutes exp = 75 ).
  ENDMETHOD.


  " Rule: no verdict before the planned start, nor within the late minutes
  METHOD before_due_is_pending.
    cl_abap_unit_assert=>assert_equals( act = judge_one( is_run = run( ) iv_now = '055900' )-verdict
                                        exp = zif_ca_ops_xrun_types=>gc_verdict-pending ).
    cl_abap_unit_assert=>assert_equals( act = judge_one( is_run = run( ) iv_now = '062000' )-verdict
                                        exp = zif_ca_ops_xrun_types=>gc_verdict-pending ).
  ENDMETHOD.


  " Fixture XRUN-01: planned 06:00, due 06:30, now 09:00, SAP has no job, the scheduler says nothing
  METHOD no_job_scheduler_stage.
    DATA(ls_result) = judge_one( run( ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_ca_ops_xrun_types=>gc_verdict-never_started ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-stage exp = zif_ca_ops_xrun_types=>gc_stage-scheduler ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-due_time exp = '063000' ).
    cl_abap_unit_assert=>assert_initial( ls_result-job ).
  ENDMETHOD.


  " Fixture XRUN-06: the scheduler ended the run not OK, SAP never had a job - it failed before SAP
  METHOD scheduler_ran_no_sap_job.
    DATA(ls_result) = judge_one( run( iv_state = zif_ca_ops_xrun_types=>gc_state-ended_not_ok ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_ca_ops_xrun_types=>gc_verdict-never_started ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-stage exp = zif_ca_ops_xrun_types=>gc_stage-handover ).
  ENDMETHOD.


  " Rule: the SAP job is released for 06:00 and never started
  METHOD waiting_sap_job_queue_stage.
    DATA(ls_result) = judge_one( is_run  = run( )
                                 it_jobs = VALUE #( ( job( iv_status = 'S' iv_planned = '060000' ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_ca_ops_xrun_types=>gc_verdict-never_started ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-stage exp = zif_ca_ops_xrun_types=>gc_stage-sap_queue ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-job-status exp = 'S' ).
  ENDMETHOD.


  " Fixture XRUN-02: the predecessor's SAP job was cancelled; the run planned 07:00 never started
  METHOD predecessor_open.
    DATA(ls_payrun) = run( iv_job = gc-payrun iv_time = '070000' iv_pattern = 'ZT_PAYRUN.*' ).
    ls_payrun-pred_folder = gc-folder.
    ls_payrun-pred_job    = gc-prep.
    DATA(lt_results) = zcl_ca_ops_xrun_monitor=>judge(
      it_runs   = VALUE #( ( run( ) ) ( ls_payrun ) )
      it_jobs   = VALUE #( ( job( iv_status = 'A' iv_start = '060100' ) ) )
      is_config = config( )
      is_now    = VALUE #( date = gc-today time = '090000' ) ).
    DATA(ls_result) = lt_results[ run-sched_job = gc-payrun ].
    cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_ca_ops_xrun_types=>gc_verdict-pred_open ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-stage exp = zif_ca_ops_xrun_types=>gc_stage-predecessor ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-pred_job-status exp = 'A' ).
    " the predecessor itself started in time: its failure is the job monitor's
    cl_abap_unit_assert=>assert_equals( act = lt_results[ run-sched_job = gc-prep ]-verdict
                                        exp = zif_ca_ops_xrun_types=>gc_verdict-ok ).
  ENDMETHOD.


  " Rule: a predecessor the scheduler reports ended OK (no SAP job of its own) does not hold the run
  METHOD predecessor_done_by_state.
    DATA(ls_payrun) = run( iv_job = gc-payrun iv_time = '070000' iv_pattern = 'ZT_PAYRUN.*' ).
    ls_payrun-pred_folder = gc-folder.
    ls_payrun-pred_job    = gc-prep.
    DATA(lt_results) = zcl_ca_ops_xrun_monitor=>judge(
      it_runs   = VALUE #( ( run( iv_state = zif_ca_ops_xrun_types=>gc_state-ended_ok iv_pattern = 'ZT_OTHER' ) )
                           ( ls_payrun ) )
      it_jobs   = VALUE #( )
      is_config = config( )
      is_now    = VALUE #( date = gc-today time = '090000' ) ).
    DATA(ls_result) = lt_results[ run-sched_job = gc-payrun ].
    cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_ca_ops_xrun_types=>gc_verdict-never_started ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-stage exp = zif_ca_ops_xrun_types=>gc_stage-scheduler ).
  ENDMETHOD.


  " Rule: held at the scheduler once the planned start has passed (even within the late minutes)
  METHOD held_after_planned_start.
    DATA(ls_result) = judge_one( is_run = run( iv_state = zif_ca_ops_xrun_types=>gc_state-held ) iv_now = '061000' ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_ca_ops_xrun_types=>gc_verdict-held ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-stage exp = zif_ca_ops_xrun_types=>gc_stage-scheduler ).
  ENDMETHOD.


  " Rule: yesterday's job of the same names (outside 60 minutes before / 720 after the plan) is not this run
  METHOD job_outside_window_ignored.
    DATA(ls_old) = job( iv_status = 'F' iv_start = '060500' ).
    ls_old-strtdate = '20261115'.
    DATA(ls_result) = judge_one( is_run = run( ) it_jobs = VALUE #( ( ls_old ) ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_result-verdict exp = zif_ca_ops_xrun_types=>gc_verdict-never_started ).
  ENDMETHOD.


  " Rule: two runs of one job a day (06:00, 08:00) and one SAP job at 06:05: the second run has none
  METHOD one_job_serves_one_run.
    DATA(lt_results) = zcl_ca_ops_xrun_monitor=>judge(
      it_runs   = VALUE #( ( run( iv_time = '080000' ) ) ( run( ) ) )
      it_jobs   = VALUE #( ( job( iv_status = 'F' iv_start = '060500' ) ) )
      is_config = config( )
      is_now    = VALUE #( date = gc-today time = '090000' ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_results[ run-plan_time = '060000' ]-verdict
                                        exp = zif_ca_ops_xrun_types=>gc_verdict-ok ).
    cl_abap_unit_assert=>assert_equals( act = lt_results[ run-plan_time = '080000' ]-verdict
                                        exp = zif_ca_ops_xrun_types=>gc_verdict-never_started ).
  ENDMETHOD.


  " Rule: a run without names takes them from its scheduler row; no row or an invalid pattern = set apart
  METHOD patterns_from_scheduler_row.
    DATA lt_invalid TYPE zif_ca_ops_xrun_types=>tt_expected.
    DATA(lo_dao) = NEW ltd_xrun_dao( ).
    lo_dao->mt_sched = VALUE #( ( sched_folder = gc-folder sched_job = gc-prep sap_pattern = gc-pattern ) ).
    DATA(lt_runs) = VALUE zif_ca_ops_xrun_types=>tt_expected( ( run( iv_pattern = space ) )
                                                              ( run( iv_job = gc-payrun iv_pattern = space ) )
                                                              ( run( iv_job = 'ZT_BAD' iv_pattern = '(' ) ) ).
    NEW zcl_ca_ops_xrun_monitor( lo_dao )->resolve_patterns( CHANGING ct_runs    = lt_runs
                                                                      ct_invalid = lt_invalid ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_runs ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_runs[ 1 ]-sap_pattern exp = gc-pattern ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_invalid ) exp = 2 ).
  ENDMETHOD.


  " Rule: running and waiting jobs are read once each; a read at its cap makes the comparison partial
  METHOD reads_capped.
    DATA(lo_dao) = NEW ltd_xrun_dao( ).
    lo_dao->mt_running = VALUE #( ( job( iv_status = 'F' iv_start = '060500' ) ) ).
    lo_dao->mt_waiting = VALUE #( ( job( iv_name = 'ZT_PAYPREP_LATE' iv_status = 'S' iv_planned = '080000' ) )
                                  ( job( iv_status = 'F' iv_start = '060500' ) ) ).
    NEW zcl_ca_ops_xrun_monitor( lo_dao )->sap_jobs( EXPORTING it_runs   = VALUE #( ( run( ) ) )
                                                               is_config = VALUE #( BASE config( ) max_jobs = 2 )
                                                               is_now    = VALUE #( date = gc-today time = '090000' )
                                                     IMPORTING et_jobs   = DATA(lt_jobs)
                                                               ev_capped = DATA(lv_capped) ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_jobs ) exp = 2 ).
    cl_abap_unit_assert=>assert_true( lv_capped ).
  ENDMETHOD.

ENDCLASS.
