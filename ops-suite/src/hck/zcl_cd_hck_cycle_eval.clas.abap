*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_cycle_eval.clas.abap
*& Purpose:
*& Pure job-cycle rules: derive the state of a cycle step from TBTCO job
*& instances, start window, max runtime and predecessor; build its findings.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Program/variant match, retries supersede aborts, late start (audit A42).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - job cycle step state rules (pure)</p>
"! Step date = cycle date + DAY_OFFSET. Candidates: jobs matching the JOBNAME
"! pattern (CP) and - when maintained - PROGRAM and VARIANT of the first step,
"! started on the step date at or after WINDOW_FROM. Deciding attempt (A42): the
"! earliest finished one; else the latest running; else the latest aborted. A
"! success after an abort is a retry (information); a deciding attempt that
"! started after WINDOW_TO is late (warning).
"! A = FAILED, F = COMPLETED (overrun flag beyond MAX_RUNTIME_MIN),
"! R = RUNNING or STUCK (beyond MAX_RUNTIME_MIN); no started instance =
"! NOT_STARTED, or MISSED once WINDOW_TO has passed. A predecessor in
"! FAILED/MISSED/STUCK marks a not-started step as blocked.
"! Monitoring only - restart / retrigger is a later phase.
CLASS zcl_cd_hck_cycle_eval DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS derive_state
      IMPORTING
        is_step          TYPE zif_cd_hck_types=>ty_cycle_step
        it_runs          TYPE zif_cd_hck_types=>tt_job_run
        iv_cycle_date    TYPE d
        iv_now_date      TYPE d
        iv_now_time      TYPE t
        iv_pred_state    TYPE zif_cd_hck_types=>ty_step_state OPTIONAL
      RETURNING
        VALUE(rs_status) TYPE zif_cd_hck_types=>ty_step_status.

    "! MISSED: E if critical, I if skippable, else W; FAILED: E/W by critical;
    "! STUCK: E; overrun: W; blocked: W
    CLASS-METHODS findings_for
      IMPORTING
        is_step            TYPE zif_cd_hck_types=>ty_cycle_step
        is_status          TYPE zif_cd_hck_types=>ty_step_status
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding.

    "! Whole minutes between two date/time points (negative when reversed)
    CLASS-METHODS minutes_between
      IMPORTING
        iv_from_date      TYPE d
        iv_from_time      TYPE t
        iv_to_date        TYPE d
        iv_to_time        TYPE t
      RETURNING
        VALUE(rv_minutes) TYPE i.

ENDCLASS.



CLASS zcl_cd_hck_cycle_eval IMPLEMENTATION.

  METHOD derive_state.
    DATA ls_match TYPE zif_cd_hck_types=>ty_job_run.
    DATA ls_finished TYPE zif_cd_hck_types=>ty_job_run.
    DATA ls_running TYPE zif_cd_hck_types=>ty_job_run.
    DATA ls_aborted TYPE zif_cd_hck_types=>ty_job_run.
    DATA lv_found TYPE abap_bool.
    DATA lv_attempts TYPE i.

    DATA(lv_step_date) = CONV d( iv_cycle_date + is_step-day_offset ).
    rs_status-cycle_id   = is_step-cycle_id.
    rs_status-step_no    = is_step-step_no.
    rs_status-jobname    = is_step-jobname.
    rs_status-cycle_date = iv_cycle_date.

    LOOP AT it_runs ASSIGNING FIELD-SYMBOL(<ls_run>) WHERE jobname CP is_step-jobname.
      IF <ls_run>-status <> zif_cd_hck_types=>gc_job_status-running
         AND <ls_run>-status <> zif_cd_hck_types=>gc_job_status-finished
         AND <ls_run>-status <> zif_cd_hck_types=>gc_job_status-aborted.
        CONTINUE.
      ENDIF.
      IF <ls_run>-strtdate <> lv_step_date OR <ls_run>-strttime < is_step-window_from.
        CONTINUE.
      ENDIF.
      " the job name alone is not the step: program and variant must match when maintained
      IF ( is_step-program IS NOT INITIAL AND <ls_run>-progname <> is_step-program )
         OR ( is_step-variant IS NOT INITIAL AND <ls_run>-variant <> is_step-variant ).
        CONTINUE.
      ENDIF.
      lv_attempts = lv_attempts + 1.
      CASE <ls_run>-status.
        WHEN zif_cd_hck_types=>gc_job_status-finished.
          IF ls_finished IS INITIAL OR <ls_run>-strttime < ls_finished-strttime.
            ls_finished = <ls_run>.
          ENDIF.
        WHEN zif_cd_hck_types=>gc_job_status-running.
          IF ls_running IS INITIAL OR <ls_run>-strttime > ls_running-strttime.
            ls_running = <ls_run>.
          ENDIF.
        WHEN OTHERS.
          IF ls_aborted IS INITIAL OR <ls_run>-strttime > ls_aborted-strttime.
            ls_aborted = <ls_run>.
          ENDIF.
      ENDCASE.
    ENDLOOP.
    ls_match = COND #( WHEN ls_finished IS NOT INITIAL THEN ls_finished
                       WHEN ls_running IS NOT INITIAL THEN ls_running
                       ELSE ls_aborted ).
    lv_found = xsdbool( ls_match IS NOT INITIAL ).
    rs_status-attempts = lv_attempts.
    IF lv_found = abap_true.
      rs_status-retried    = xsdbool( ls_finished IS NOT INITIAL AND ls_aborted IS NOT INITIAL ).
      rs_status-late_start = xsdbool( is_step-window_to IS NOT INITIAL AND ls_match-strttime > is_step-window_to ).
    ENDIF.
    IF lv_found = abap_false.
      DATA(lv_window_closed) = xsdbool( is_step-window_to IS NOT INITIAL
                                        AND ( iv_now_date > lv_step_date
                                           OR ( iv_now_date = lv_step_date AND iv_now_time > is_step-window_to ) ) ).
      rs_status-state = COND #( WHEN lv_window_closed = abap_true THEN zif_cd_hck_types=>gc_step_state-missed
                                ELSE zif_cd_hck_types=>gc_step_state-not_started ).
      rs_status-blocked = xsdbool( iv_pred_state = zif_cd_hck_types=>gc_step_state-failed
                                OR iv_pred_state = zif_cd_hck_types=>gc_step_state-missed
                                OR iv_pred_state = zif_cd_hck_types=>gc_step_state-stuck ).
      RETURN.
    ENDIF.

    rs_status-jobname    = ls_match-jobname.
    rs_status-jobcount   = ls_match-jobcount.
    rs_status-started_on = ls_match-strtdate.
    rs_status-started_at = ls_match-strttime.

    IF ls_match-status = zif_cd_hck_types=>gc_job_status-running.
      rs_status-runtime_min = minutes_between( iv_from_date = ls_match-strtdate
                                               iv_from_time = ls_match-strttime
                                               iv_to_date   = iv_now_date
                                               iv_to_time   = iv_now_time ).
    ELSE.
      rs_status-runtime_min = minutes_between( iv_from_date = ls_match-strtdate
                                               iv_from_time = ls_match-strttime
                                               iv_to_date   = ls_match-enddate
                                               iv_to_time   = ls_match-endtime ).
    ENDIF.
    rs_status-overrun = xsdbool( is_step-max_runtime_min > 0 AND rs_status-runtime_min > is_step-max_runtime_min ).

    rs_status-state = SWITCH #( ls_match-status
                                WHEN zif_cd_hck_types=>gc_job_status-aborted  THEN zif_cd_hck_types=>gc_step_state-failed
                                WHEN zif_cd_hck_types=>gc_job_status-finished THEN zif_cd_hck_types=>gc_step_state-completed
                                ELSE COND #( WHEN rs_status-overrun = abap_true THEN zif_cd_hck_types=>gc_step_state-stuck
                                             ELSE zif_cd_hck_types=>gc_step_state-running ) ).
  ENDMETHOD.


  METHOD findings_for.
    DATA ls_finding TYPE zif_cd_ops_types=>ty_finding.

    ls_finding-object_type = zif_cd_hck_types=>gc_object_type.
    ls_finding-object_key  = |{ is_status-cycle_id }/{ is_status-step_no }|.
    ls_finding-reference   = is_status-jobname.
    ls_finding-action      = zif_cd_ops_types=>gc_action-notify.
    ls_finding-message     = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-cycle_step
                                                    iv_v1    = is_status-cycle_id
                                                    iv_v2    = is_status-step_no
                                                    iv_v3    = is_status-jobname
                                                    iv_v4    = is_status-state ).

    CASE is_status-state.
      WHEN zif_cd_hck_types=>gc_step_state-missed.
        ls_finding-check_code = zif_cd_hck_types=>gc_code-step_missed.
        ls_finding-severity   = COND #( WHEN is_step-critical = abap_true  THEN zif_cd_ops_types=>gc_severity-error
                                        WHEN is_step-skippable = abap_true THEN zif_cd_ops_types=>gc_severity-info
                                        ELSE zif_cd_ops_types=>gc_severity-warning ).
      WHEN zif_cd_hck_types=>gc_step_state-failed.
        ls_finding-check_code = zif_cd_hck_types=>gc_code-step_failed.
        ls_finding-severity   = COND #( WHEN is_step-critical = abap_true THEN zif_cd_ops_types=>gc_severity-error
                                        ELSE zif_cd_ops_types=>gc_severity-warning ).
      WHEN zif_cd_hck_types=>gc_step_state-stuck.
        ls_finding-check_code = zif_cd_hck_types=>gc_code-step_stuck.
        ls_finding-severity   = zif_cd_ops_types=>gc_severity-error.
        ls_finding-message    = ls_finding-message && ` `
                             && zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-after_min_max
                                                       iv_v1    = is_status-runtime_min
                                                       iv_v2    = is_step-max_runtime_min ).
      WHEN zif_cd_hck_types=>gc_step_state-completed.
        " A42: a completed step can still be late or retried - one finding each
        DATA(ls_base) = ls_finding.
        IF is_status-late_start = abap_true.
          ls_finding-check_code = zif_cd_hck_types=>gc_code-step_late.
          ls_finding-severity   = zif_cd_ops_types=>gc_severity-warning.
          ls_finding-message    = ls_base-message && ` `
                               && zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-step_started_late
                                                         iv_v1    = |{ is_status-started_at TIME = ISO }|
                                                         iv_v2    = |{ is_step-window_to TIME = ISO }| ).
          INSERT ls_finding INTO TABLE rt_findings.
        ENDIF.
        IF is_status-retried = abap_true.
          ls_finding-check_code = zif_cd_hck_types=>gc_code-step_retried.
          ls_finding-severity   = zif_cd_ops_types=>gc_severity-info.
          ls_finding-message    = ls_base-message && ` `
                               && zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-step_retried
                                                         iv_v1    = is_status-attempts
                                                         iv_v2    = |{ is_status-started_at TIME = ISO }| ).
          INSERT ls_finding INTO TABLE rt_findings.
        ENDIF.
        IF is_status-overrun = abap_false.
          RETURN.
        ENDIF.
        ls_finding-check_code = zif_cd_hck_types=>gc_code-step_overrun.
        ls_finding-severity   = zif_cd_ops_types=>gc_severity-warning.
        ls_finding-message    = ls_base-message && ` `
                             && zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-in_min_max
                                                       iv_v1    = is_status-runtime_min
                                                       iv_v2    = is_step-max_runtime_min ).
      WHEN OTHERS.
        IF is_status-blocked = abap_false.
          RETURN.
        ENDIF.
        ls_finding-check_code = zif_cd_hck_types=>gc_code-step_blocked.
        ls_finding-severity   = zif_cd_ops_types=>gc_severity-warning.
        ls_finding-message    = ls_finding-message && `, `
                             && zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-blocked_by_predecessor
                                                       iv_v1    = is_step-pred_step ).
    ENDCASE.
    INSERT ls_finding INTO TABLE rt_findings.
  ENDMETHOD.


  METHOD minutes_between.
    DATA(lv_seconds) = ( iv_to_date - iv_from_date ) * 86400 + ( iv_to_time - iv_from_time ).
    rv_minutes = lv_seconds DIV 60.
  ENDMETHOD.

ENDCLASS.
