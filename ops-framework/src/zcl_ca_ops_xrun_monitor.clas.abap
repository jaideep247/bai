*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_xrun_monitor.clas.abap
*& Purpose:
*& Engine of the expected runs (docs/EXPECTED_RUNS_AND_MASS_ACTIVITIES.md
*& section 2.3): compares the plan of the external scheduler with SAP's
*& background jobs (TBTCO through the job monitor's data access). The
*& SAP job names of a run come from the run itself or from the scheduler
*& row of its folder and job (ZCA_OPS_JOBSCH); a job of those names whose
*& start - else planned start, else creation - lies from XRUN_EARLY_MIN
*& before to XRUN_MATCH_MIN after the planned start is the run's job (each
*& job serves one run, earliest plan first; quality probable - a name and
*& a time window, no key). Verdicts: started in time (OK), started after
*& the late limit (LATE), not due yet (PENDING), held at the scheduler
*& after its planned start (HELD), due and its predecessor of the same day
*& has not ended successfully (PRED_OPEN), due and no job started (NEVER:
*& stage SCHEDULER when the scheduler did not start it, HANDOVER when the
*& scheduler started or ended it but SAP has no job - it failed before
*& SAP, SAP_QUEUE when the SAP job waits). Reads only; no job is
*& released, started or changed.
*& Modification log:
*& 2026-11-16 | Initial version (build P: expected runs from the scheduler).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - expected runs versus SAP jobs</p>
CLASS zcl_ca_ops_xrun_monitor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! @parameter io_dao | Data access of the job monitor (tests: a double)
    METHODS constructor
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_job_dao OPTIONAL.

    "! Complete the SAP job names of every run from its scheduler row; runs without a usable pattern are moved to
    "! et_invalid (reported by the check, never judged)
    METHODS resolve_patterns
      CHANGING
        ct_runs    TYPE zif_ca_ops_xrun_types=>tt_expected
        ct_invalid TYPE zif_ca_ops_xrun_types=>tt_expected.

    "! The SAP jobs that may be runs of the plan: jobs that ran from the earliest planned start (less the early
    "! minutes) until now, and jobs that wait to start
    "! @parameter ev_capped | X = a read reached XRUN_MAX_JOBS (the check is partial)
    METHODS sap_jobs
      IMPORTING
        it_runs   TYPE zif_ca_ops_xrun_types=>tt_expected
        is_config TYPE zif_ca_ops_xrun_types=>ty_config
        is_now    TYPE zif_ca_ops_job_types=>ty_point
      EXPORTING
        et_jobs   TYPE zif_ca_ops_job_types=>tt_job
        ev_capped TYPE abap_bool.

    "! The verdict of every run (pure: no read)
    CLASS-METHODS judge
      IMPORTING
        it_runs           TYPE zif_ca_ops_xrun_types=>tt_expected
        it_jobs           TYPE zif_ca_ops_job_types=>tt_job
        is_config         TYPE zif_ca_ops_xrun_types=>ty_config
        is_now            TYPE zif_ca_ops_job_types=>ty_point
      RETURNING
        VALUE(rt_results) TYPE zif_ca_ops_xrun_types=>tt_result.

    "! Planned start of a run
    CLASS-METHODS planned
      IMPORTING
        is_run          TYPE zif_ca_ops_xrun_types=>ty_expected
      RETURNING
        VALUE(rs_point) TYPE zif_ca_ops_job_types=>ty_point.

  PRIVATE SECTION.
    TYPES tt_key TYPE zif_ca_ops_job_types=>tt_job_key.

    DATA mo_dao TYPE REF TO zif_ca_ops_job_dao.

    "! The job of a run among the jobs not used yet: the earliest started one in its window, else a waiting one
    CLASS-METHODS match
      IMPORTING
        is_run        TYPE zif_ca_ops_xrun_types=>ty_expected
        it_jobs       TYPE zif_ca_ops_job_types=>tt_job
        it_used       TYPE tt_key
        is_config     TYPE zif_ca_ops_xrun_types=>ty_config
      RETURNING
        VALUE(rs_job) TYPE zif_ca_ops_job_types=>ty_job.

    "! The point that places a job in time: start, else planned start, else creation
    CLASS-METHODS job_point
      IMPORTING
        is_job          TYPE zif_ca_ops_job_types=>ty_job
      RETURNING
        VALUE(rs_point) TYPE zif_ca_ops_job_types=>ty_point.

    "! The verdict of one run whose job (or none) is known
    CLASS-METHODS verdict
      IMPORTING
        is_now    TYPE zif_ca_ops_job_types=>ty_point
        it_all    TYPE zif_ca_ops_xrun_types=>tt_result
      CHANGING
        cs_result TYPE zif_ca_ops_xrun_types=>ty_result.

    "! X = the predecessor's run of the day ended successfully (SAP job finished, or the scheduler says so)
    CLASS-METHODS pred_done
      IMPORTING
        is_pred         TYPE zif_ca_ops_xrun_types=>ty_result
      RETURNING
        VALUE(rv_done) TYPE abap_bool.

ENDCLASS.



CLASS zcl_ca_ops_xrun_monitor IMPLEMENTATION.

  METHOD constructor.
    mo_dao = COND #( WHEN io_dao IS BOUND THEN io_dao ELSE NEW zcl_ca_ops_job_dao( ) ).
  ENDMETHOD.


  METHOD resolve_patterns.
    DATA lt_keep TYPE zif_ca_ops_xrun_types=>tt_expected.
    DATA lt_rows TYPE zif_ca_ops_job_types=>tt_sched.

    IF line_exists( ct_runs[ sap_pattern = space ] ).
      lt_rows = mo_dao->scheduler_jobs( ).
    ENDIF.
    LOOP AT ct_runs INTO DATA(ls_run).
      IF ls_run-sap_pattern IS INITIAL.
        ls_run-sap_pattern = VALUE #( lt_rows[ sched_folder = ls_run-sched_folder
                                               sched_job    = ls_run-sched_job ]-sap_pattern OPTIONAL ).
      ENDIF.
      IF ls_run-sap_pattern IS INITIAL OR zcl_ca_ops_util=>pcre_valid( ls_run-sap_pattern ) = abap_false.
        INSERT ls_run INTO TABLE ct_invalid.
      ELSE.
        INSERT ls_run INTO TABLE lt_keep.
      ENDIF.
    ENDLOOP.
    ct_runs = lt_keep.
  ENDMETHOD.


  METHOD sap_jobs.
    DATA lt_keys TYPE tt_key.
    DATA ls_first TYPE zif_ca_ops_job_types=>ty_point.
    DATA ls_last TYPE zif_ca_ops_job_types=>ty_point.

    CLEAR: et_jobs, ev_capped.
    IF it_runs IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT it_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      DATA(ls_plan) = planned( <ls_run> ).
      IF ls_first IS INITIAL OR zcl_ca_ops_job_time=>not_after( is_first = ls_plan is_second = ls_first ) = abap_true.
        ls_first = ls_plan.
      ENDIF.
      IF ls_last IS INITIAL OR zcl_ca_ops_job_time=>not_after( is_first = ls_last is_second = ls_plan ) = abap_true.
        ls_last = ls_plan.
      ENDIF.
    ENDLOOP.
    DATA(ls_window) = VALUE zif_ca_ops_job_types=>ty_window(
      from = zcl_ca_ops_job_time=>add_minutes( is_point = ls_first iv_minutes = - is_config-early_min )
      to   = is_now ).
    DATA(lt_running) = mo_dao->jobs_running( is_window   = ls_window
                                             it_programs = VALUE #( )
                                             iv_max      = is_config-max_jobs ).
    DATA(lt_waiting) = mo_dao->waiting_jobs(
      it_statuses       = is_config-waiting
      is_planned_before = zcl_ca_ops_job_time=>add_minutes( is_point = ls_last iv_minutes = is_config-match_min )
      iv_max            = is_config-max_jobs ).
    ev_capped = xsdbool( lines( lt_running ) >= is_config-max_jobs OR lines( lt_waiting ) >= is_config-max_jobs ).
    LOOP AT lt_running ASSIGNING FIELD-SYMBOL(<ls_job>).
      INSERT VALUE #( jobname = <ls_job>-jobname jobcount = <ls_job>-jobcount ) INTO TABLE lt_keys.
      INSERT <ls_job> INTO TABLE et_jobs.
    ENDLOOP.
    LOOP AT lt_waiting ASSIGNING <ls_job>.
      INSERT VALUE #( jobname = <ls_job>-jobname jobcount = <ls_job>-jobcount ) INTO TABLE lt_keys.
      IF sy-subrc = 0.
        INSERT <ls_job> INTO TABLE et_jobs.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD judge.
    DATA lt_used TYPE tt_key.
    DATA lt_runs TYPE zif_ca_ops_xrun_types=>tt_expected.

    " earliest plan first: an SAP job serves the first run it fits
    lt_runs = it_runs.
    SORT lt_runs BY plan_date plan_time sched_folder sched_job.
    LOOP AT lt_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      DATA(ls_result) = VALUE zif_ca_ops_xrun_types=>ty_result(
        run = <ls_run>
        job = match( is_run = <ls_run> it_jobs = it_jobs it_used = lt_used is_config = is_config ) ).
      IF ls_result-job IS NOT INITIAL.
        INSERT VALUE #( jobname = ls_result-job-jobname jobcount = ls_result-job-jobcount ) INTO TABLE lt_used.
      ENDIF.
      DATA(ls_due) = zcl_ca_ops_job_time=>add_minutes(
                       is_point   = planned( <ls_run> )
                       iv_minutes = COND #( WHEN <ls_run>-late_min > 0 THEN <ls_run>-late_min ELSE is_config-late_min ) ).
      ls_result-due_date = ls_due-date.
      ls_result-due_time = ls_due-time.
      INSERT ls_result INTO TABLE rt_results.
    ENDLOOP.
    " the verdicts need the jobs of every run of the day first (the predecessor's)
    LOOP AT rt_results ASSIGNING FIELD-SYMBOL(<ls_result>).
      verdict( EXPORTING is_now    = is_now
                         it_all    = rt_results
               CHANGING  cs_result = <ls_result> ).
    ENDLOOP.
  ENDMETHOD.


  METHOD planned.
    rs_point = VALUE #( date = is_run-plan_date time = is_run-plan_time ).
  ENDMETHOD.


  METHOD match.
    DATA ls_waiting TYPE zif_ca_ops_job_types=>ty_job.

    DATA(ls_plan) = planned( is_run ).
    DATA(ls_from) = zcl_ca_ops_job_time=>add_minutes( is_point = ls_plan iv_minutes = - is_config-early_min ).
    DATA(ls_to) = zcl_ca_ops_job_time=>add_minutes( is_point = ls_plan iv_minutes = is_config-match_min ).
    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      IF line_exists( it_used[ jobname = <ls_job>-jobname jobcount = <ls_job>-jobcount ] )
         OR zcl_ca_ops_util=>pcre_match( iv_value = <ls_job>-jobname iv_pattern = is_run-sap_pattern ) = abap_false.
        CONTINUE.
      ENDIF.
      DATA(ls_point) = job_point( <ls_job> ).
      IF ls_point IS INITIAL
         OR zcl_ca_ops_job_time=>not_after( is_first = ls_from is_second = ls_point ) = abap_false
         OR zcl_ca_ops_job_time=>not_after( is_first = ls_point is_second = ls_to ) = abap_false.
        CONTINUE.
      ENDIF.
      IF <ls_job>-strtdate IS NOT INITIAL.
        IF rs_job IS INITIAL
           OR zcl_ca_ops_job_time=>not_after( is_first  = ls_point
                                              is_second = zcl_ca_ops_job_time=>started( rs_job ) ) = abap_true.
          rs_job = <ls_job>.
        ENDIF.
      ELSEIF ls_waiting IS INITIAL.
        ls_waiting = <ls_job>.
      ENDIF.
    ENDLOOP.
    IF rs_job IS INITIAL.
      rs_job = ls_waiting.
    ENDIF.
  ENDMETHOD.


  METHOD job_point.
    IF is_job-strtdate IS NOT INITIAL.
      rs_point = zcl_ca_ops_job_time=>started( is_job ).
    ELSEIF is_job-sdlstrtdt IS NOT INITIAL.
      rs_point = VALUE #( date = is_job-sdlstrtdt time = is_job-sdlstrttm ).
    ELSEIF is_job-sdldate IS NOT INITIAL.
      rs_point = zcl_ca_ops_job_time=>created( is_job ).
    ENDIF.
  ENDMETHOD.


  METHOD verdict.
    DATA(ls_plan) = planned( cs_result-run ).
    DATA(ls_due) = VALUE zif_ca_ops_job_types=>ty_point( date = cs_result-due_date time = cs_result-due_time ).
    IF cs_result-job-strtdate IS NOT INITIAL.
      DATA(ls_start) = zcl_ca_ops_job_time=>started( cs_result-job ).
      cs_result-late_minutes = nmax( val1 = 0
                                     val2 = zcl_ca_ops_job_time=>minutes_between( is_from = ls_plan is_to = ls_start ) ).
      IF zcl_ca_ops_job_time=>not_after( is_first = ls_start is_second = ls_due ) = abap_true.
        cs_result-verdict = zif_ca_ops_xrun_types=>gc_verdict-ok.
      ELSE.
        cs_result-verdict = zif_ca_ops_xrun_types=>gc_verdict-started_late.
        cs_result-stage   = zif_ca_ops_xrun_types=>gc_stage-late_start.
      ENDIF.
      RETURN.
    ENDIF.
    " not started: no verdict before the planned start
    IF zcl_ca_ops_job_time=>not_after( is_first = is_now is_second = ls_plan ) = abap_true
       AND is_now <> ls_plan.
      cs_result-verdict = zif_ca_ops_xrun_types=>gc_verdict-pending.
      RETURN.
    ENDIF.
    IF cs_result-run-sched_state = zif_ca_ops_xrun_types=>gc_state-held.
      cs_result-verdict = zif_ca_ops_xrun_types=>gc_verdict-held.
      cs_result-stage   = zif_ca_ops_xrun_types=>gc_stage-scheduler.
      RETURN.
    ENDIF.
    IF zcl_ca_ops_job_time=>not_after( is_first = is_now is_second = ls_due ) = abap_true.
      cs_result-verdict = zif_ca_ops_xrun_types=>gc_verdict-pending.
      RETURN.
    ENDIF.
    " due: is it waiting for a predecessor of the same day that has not ended successfully?
    IF cs_result-run-pred_job IS NOT INITIAL.
      LOOP AT it_all ASSIGNING FIELD-SYMBOL(<ls_pred>)
           WHERE run-sched_folder = cs_result-run-pred_folder
             AND run-sched_job    = cs_result-run-pred_job
             AND run-plan_date    = cs_result-run-plan_date.
        IF pred_done( <ls_pred> ) = abap_false.
          cs_result-verdict  = zif_ca_ops_xrun_types=>gc_verdict-pred_open.
          cs_result-stage    = zif_ca_ops_xrun_types=>gc_stage-predecessor.
          cs_result-pred     = <ls_pred>-run.
          cs_result-pred_job = <ls_pred>-job.
          RETURN.
        ENDIF.
      ENDLOOP.
    ENDIF.
    cs_result-verdict = zif_ca_ops_xrun_types=>gc_verdict-never_started.
    IF cs_result-job IS NOT INITIAL.
      " the SAP job exists and waits (released, ready, scheduled)
      cs_result-stage = zif_ca_ops_xrun_types=>gc_stage-sap_queue.
    ELSEIF cs_result-run-sched_state = zif_ca_ops_xrun_types=>gc_state-started
        OR cs_result-run-sched_state = zif_ca_ops_xrun_types=>gc_state-ended_ok
        OR cs_result-run-sched_state = zif_ca_ops_xrun_types=>gc_state-ended_not_ok.
      " the scheduler ran it, SAP never saw a job: it failed before SAP
      cs_result-stage = zif_ca_ops_xrun_types=>gc_stage-handover.
    ELSE.
      cs_result-stage = zif_ca_ops_xrun_types=>gc_stage-scheduler.
    ENDIF.
  ENDMETHOD.


  METHOD pred_done.
    rv_done = xsdbool( is_pred-job-status = zif_ca_ops_job_types=>gc_status-finished
                       OR ( is_pred-job IS INITIAL
                            AND is_pred-run-sched_state = zif_ca_ops_xrun_types=>gc_state-ended_ok ) ).
  ENDMETHOD.

ENDCLASS.
