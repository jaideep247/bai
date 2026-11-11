*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_dao.clas.abap
*& Purpose:
*& All SQL of the SAP job monitor. SAP job tables TBTCO / TBTCP and the
*& application log headers BALHDR are read only, for the logon client
*& (TBTCO is cross-client: AUTHCKMAN), by status and a date / time window,
*& ordered and capped (UP TO / cut after FOR ALL ENTRIES) - never a full
*& scan of the job history, never a pattern in SQL (job names are matched
*& with PCRE in ABAP). The monitor's own tables: evidence ZCA_OPS_JOB,
*& _JOBSTEP, _JOBMSG, _JOBALOG, _JOBBO (insert or replace by key),
*& watermark ZCA_OPS_JOBWM, external scheduler mapping ZCA_OPS_JOBSCH. No commit.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor). Dynamic field names: PCRE and
*&            | CL_ABAP_DYN_PRG=>CHECK_COLUMN_NAME before any dynamic SQL.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - SAP job monitor data access</p>
"! VERIFY-SE11 V58 / V59: fields of TBTCO, TBTCP, BALHDR on 7.58 and the indexes the windows use
"! (docs/JOB_MONITORING.md section 7). Writes nothing in a SAP table.
CLASS zcl_ca_ops_job_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_dao.

  PRIVATE SECTION.
    TYPES tt_progname TYPE RANGE OF zif_ca_ops_job_types=>ty_progname.
    TYPES tt_user TYPE RANGE OF syuname.
    TYPES tt_status TYPE RANGE OF zif_ca_ops_job_types=>ty_status.

    "! Field name for a dynamic select list or condition: letters, digits, underscore only
    CONSTANTS gc_field_pcre TYPE string VALUE `[A-Z][A-Z0-9_]{0,29}`.
    "! Initial date of a job that has not started / has no planned start
    CONSTANTS gc_no_date TYPE d VALUE '00000000'.

    "! Cut a table read with FOR ALL ENTRIES to iv_max rows, in key order
    CLASS-METHODS cap
      IMPORTING
        iv_max  TYPE i
      CHANGING
        ct_jobs TYPE zif_ca_ops_job_types=>tt_job.

    "! A configured field name is a plain DDIC name (the caller checked it against the runtime DDIC)
    CLASS-METHODS check_field
      IMPORTING
        iv_field TYPE zif_ca_ops_job_types=>ty_fieldname
      RAISING
        zcx_ca_ops_error.

ENDCLASS.



CLASS zcl_ca_ops_job_dao IMPLEMENTATION.

  METHOD zif_ca_ops_job_dao~aborted_jobs.
    "VERIFY-SE11 V58: TBTCO index on STATUS / ENDDATE (AUTHCKMAN filter of the client)
    SELECT jobname, jobcount, status, sdlstrtdt, sdlstrttm, sdldate, sdltime, sdluname, strtdate, strttime,
           enddate, endtime, reaxserver, eventid, eventparm
      FROM tbtco
      WHERE authckman = @sy-mandt
        AND status    = @zif_ca_ops_job_types=>gc_status-aborted
        AND ( enddate > @is_window-from-date
           OR ( enddate = @is_window-from-date AND endtime >= @is_window-from-time ) )
        AND ( enddate < @is_window-to-date
           OR ( enddate = @is_window-to-date AND endtime <= @is_window-to-time ) )
      ORDER BY enddate, endtime, jobname, jobcount
      INTO CORRESPONDING FIELDS OF TABLE @rt_jobs
      UP TO @iv_max ROWS.
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~finished_jobs.
    DATA lt_programs TYPE tt_progname.
    IF it_programs IS INITIAL.
      RETURN.
    ENDIF.
    lt_programs = CORRESPONDING #( it_programs ).
    SELECT DISTINCT j~jobname, j~jobcount, j~status, j~sdlstrtdt, j~sdlstrttm, j~sdldate, j~sdltime, j~sdluname,
           j~strtdate, j~strttime, j~enddate, j~endtime, j~reaxserver, j~eventid, j~eventparm
      FROM tbtco AS j
        INNER JOIN tbtcp AS p ON  p~jobname  = j~jobname
                              AND p~jobcount = j~jobcount
      WHERE j~authckman = @sy-mandt
        AND j~status    = @zif_ca_ops_job_types=>gc_status-finished
        AND ( j~enddate > @is_window-from-date
           OR ( j~enddate = @is_window-from-date AND j~endtime >= @is_window-from-time ) )
        AND ( j~enddate < @is_window-to-date
           OR ( j~enddate = @is_window-to-date AND j~endtime <= @is_window-to-time ) )
        AND p~progname IN @lt_programs
      ORDER BY j~enddate, j~endtime, j~jobname, j~jobcount
      INTO CORRESPONDING FIELDS OF TABLE @rt_jobs
      UP TO @iv_max ROWS.
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~active_jobs.
    SELECT jobname, jobcount, status, sdlstrtdt, sdlstrttm, sdldate, sdltime, sdluname, strtdate, strttime,
           enddate, endtime, reaxserver, eventid, eventparm
      FROM tbtco
      WHERE authckman = @sy-mandt
        AND status IN ( @zif_ca_ops_job_types=>gc_status-running, @zif_ca_ops_job_types=>gc_status-put_active )
        AND strtdate <> @gc_no_date
        AND ( strtdate < @is_started_before-date
           OR ( strtdate = @is_started_before-date AND strttime <= @is_started_before-time ) )
      ORDER BY strtdate, strttime, jobname, jobcount
      INTO CORRESPONDING FIELDS OF TABLE @rt_jobs
      UP TO @iv_max ROWS.
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~waiting_jobs.
    DATA lt_statuses TYPE tt_status.
    IF it_statuses IS INITIAL.
      RETURN.
    ENDIF.
    lt_statuses = CORRESPONDING #( it_statuses ).
    " a job waiting for an event has no planned start: never "not started"
    SELECT jobname, jobcount, status, sdlstrtdt, sdlstrttm, sdldate, sdltime, sdluname, strtdate, strttime,
           enddate, endtime, reaxserver, eventid, eventparm
      FROM tbtco
      WHERE authckman = @sy-mandt
        AND status IN @lt_statuses
        AND eventid   = @space
        AND sdlstrtdt <> @gc_no_date
        AND ( sdlstrtdt < @is_planned_before-date
           OR ( sdlstrtdt = @is_planned_before-date AND sdlstrttm <= @is_planned_before-time ) )
      ORDER BY sdlstrtdt, sdlstrttm, jobname, jobcount
      INTO CORRESPONDING FIELDS OF TABLE @rt_jobs
      UP TO @iv_max ROWS.
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~jobs.
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.
    SELECT jobname, jobcount, status, sdlstrtdt, sdlstrttm, sdldate, sdltime, sdluname, strtdate, strttime,
           enddate, endtime, reaxserver, eventid, eventparm
      FROM tbtco
      FOR ALL ENTRIES IN @it_keys
      WHERE jobname   = @it_keys-jobname
        AND jobcount  = @it_keys-jobcount
        AND authckman = @sy-mandt
      INTO CORRESPONDING FIELDS OF TABLE @rt_jobs.
    SORT rt_jobs BY jobname jobcount.
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~jobs_created.
    DATA lt_users TYPE tt_user.
    IF it_users IS INITIAL.
      RETURN.
    ENDIF.
    lt_users = CORRESPONDING #( it_users ).
    SELECT jobname, jobcount, status, sdlstrtdt, sdlstrttm, sdldate, sdltime, sdluname, strtdate, strttime,
           enddate, endtime, reaxserver, eventid, eventparm
      FROM tbtco
      WHERE authckman = @sy-mandt
        AND sdluname IN @lt_users
        AND ( sdldate > @is_window-from-date
           OR ( sdldate = @is_window-from-date AND sdltime >= @is_window-from-time ) )
        AND ( sdldate < @is_window-to-date
           OR ( sdldate = @is_window-to-date AND sdltime <= @is_window-to-time ) )
      ORDER BY sdldate, sdltime, jobname, jobcount
      INTO CORRESPONDING FIELDS OF TABLE @rt_jobs
      UP TO @iv_max ROWS.
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~jobs_running.
    DATA lt_programs TYPE tt_progname.
    IF it_programs IS INITIAL.
      SELECT jobname, jobcount, status, sdlstrtdt, sdlstrttm, sdldate, sdltime, sdluname, strtdate, strttime,
             enddate, endtime, reaxserver, eventid, eventparm
        FROM tbtco
        WHERE authckman = @sy-mandt
          AND strtdate <> @gc_no_date
          AND ( strtdate < @is_window-to-date
             OR ( strtdate = @is_window-to-date AND strttime <= @is_window-to-time ) )
          AND ( status IN ( @zif_ca_ops_job_types=>gc_status-running, @zif_ca_ops_job_types=>gc_status-put_active )
             OR enddate > @is_window-from-date
             OR ( enddate = @is_window-from-date AND endtime >= @is_window-from-time ) )
        ORDER BY strtdate, strttime, jobname, jobcount
        INTO CORRESPONDING FIELDS OF TABLE @rt_jobs
        UP TO @iv_max ROWS.
      RETURN.
    ENDIF.
    lt_programs = CORRESPONDING #( it_programs ).
    SELECT DISTINCT j~jobname, j~jobcount, j~status, j~sdlstrtdt, j~sdlstrttm, j~sdldate, j~sdltime, j~sdluname,
           j~strtdate, j~strttime, j~enddate, j~endtime, j~reaxserver, j~eventid, j~eventparm
      FROM tbtco AS j
        INNER JOIN tbtcp AS p ON  p~jobname  = j~jobname
                              AND p~jobcount = j~jobcount
      WHERE j~authckman = @sy-mandt
        AND p~progname IN @lt_programs
        AND j~strtdate <> @gc_no_date
        AND ( j~strtdate < @is_window-to-date
           OR ( j~strtdate = @is_window-to-date AND j~strttime <= @is_window-to-time ) )
        AND ( j~status IN ( @zif_ca_ops_job_types=>gc_status-running, @zif_ca_ops_job_types=>gc_status-put_active )
           OR j~enddate > @is_window-from-date
           OR ( j~enddate = @is_window-from-date AND j~endtime >= @is_window-from-time ) )
      ORDER BY j~strtdate, j~strttime, j~jobname, j~jobcount
      INTO CORRESPONDING FIELDS OF TABLE @rt_jobs
      UP TO @iv_max ROWS.
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~jobs_by_event.
    IF it_events IS INITIAL.
      RETURN.
    ENDIF.
    "VERIFY-SE11 V61: TBTCO index on EVENTID / EVENTPARM
    SELECT jobname, jobcount, status, sdlstrtdt, sdlstrttm, sdldate, sdltime, sdluname, strtdate, strttime,
           enddate, endtime, reaxserver, eventid, eventparm
      FROM tbtco
      FOR ALL ENTRIES IN @it_events
      WHERE eventid   = @it_events-eventid
        AND eventparm = @it_events-eventparm
        AND authckman = @sy-mandt
      INTO CORRESPONDING FIELDS OF TABLE @rt_jobs.
    cap( EXPORTING iv_max  = iv_max
         CHANGING  ct_jobs = rt_jobs ).
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~steps.
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.
    "VERIFY-SE11 V58: TBTCP-AUTHCKNAM (step user), LISTIDENT (spool list of the step)
    SELECT jobname, jobcount, stepcount, progname, variant, authcknam, listident
      FROM tbtcp
      FOR ALL ENTRIES IN @it_keys
      WHERE jobname  = @it_keys-jobname
        AND jobcount = @it_keys-jobcount
      INTO CORRESPONDING FIELDS OF TABLE @rt_steps.
    SORT rt_steps BY jobname jobcount stepcount.
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~applogs.
    DATA lt_users TYPE tt_user.
    DATA lt_programs TYPE tt_progname.
    IF it_users IS INITIAL OR it_programs IS INITIAL.
      RETURN.
    ENDIF.
    lt_users = CORRESPONDING #( it_users ).
    lt_programs = CORRESPONDING #( it_programs ).
    "VERIFY-SE11 V59: BALHDR-ALUSER, ALPROG, MSG_CNT_E, MSG_CNT_A; index on ALDATE
    SELECT lognumber, object, subobject, extnumber, aldate, altime, aluser, alprog, msg_cnt_e, msg_cnt_a
      FROM balhdr
      WHERE ( aldate > @is_window-from-date
           OR ( aldate = @is_window-from-date AND altime >= @is_window-from-time ) )
        AND ( aldate < @is_window-to-date
           OR ( aldate = @is_window-to-date AND altime <= @is_window-to-time ) )
        AND aluser IN @lt_users
        AND alprog IN @lt_programs
      ORDER BY aldate, altime, lognumber
      INTO CORRESPONDING FIELDS OF TABLE @rt_applogs
      UP TO @iv_max ROWS.
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~parents_by_fields.
    TYPES:
      BEGIN OF ty_row,
        child_name   TYPE btcjob,
        child_count  TYPE btcjobcnt,
        parent_name  TYPE btcjob,
        parent_count TYPE btcjobcnt,
      END OF ty_row.
    DATA lt_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.
    check_field( iv_name_field ).
    check_field( iv_count_field ).
    DATA(lv_fields) = |JOBNAME AS CHILD_NAME, JOBCOUNT AS CHILD_COUNT, { iv_name_field } AS PARENT_NAME, |
                   && |{ iv_count_field } AS PARENT_COUNT|.
    SELECT (lv_fields)
      FROM tbtco
      FOR ALL ENTRIES IN @it_keys
      WHERE jobname   = @it_keys-jobname
        AND jobcount  = @it_keys-jobcount
        AND authckman = @sy-mandt
      INTO CORRESPONDING FIELDS OF TABLE @lt_rows.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE parent_name IS NOT INITIAL.
      INSERT CORRESPONDING #( <ls_row> ) INTO TABLE rt_links.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~children_by_fields.
    TYPES:
      BEGIN OF ty_row,
        child_name   TYPE btcjob,
        child_count  TYPE btcjobcnt,
        parent_name  TYPE btcjob,
        parent_count TYPE btcjobcnt,
      END OF ty_row.
    DATA lt_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.
    check_field( iv_name_field ).
    check_field( iv_count_field ).
    DATA(lv_fields) = |JOBNAME AS CHILD_NAME, JOBCOUNT AS CHILD_COUNT, { iv_name_field } AS PARENT_NAME, |
                   && |{ iv_count_field } AS PARENT_COUNT|.
    " VERIFY-ADT V63: FOR ALL ENTRIES with a dynamic condition naming the entries (7.58 strict mode)
    DATA(lv_where) = |{ iv_name_field } = @IT_KEYS-JOBNAME AND { iv_count_field } = @IT_KEYS-JOBCOUNT |
                  && |AND AUTHCKMAN = @SY-MANDT|.
    SELECT (lv_fields)
      FROM tbtco
      FOR ALL ENTRIES IN @it_keys
      WHERE (lv_where)
      INTO CORRESPONDING FIELDS OF TABLE @lt_rows.
    SORT lt_rows BY parent_name parent_count child_name child_count.
    DELETE lt_rows FROM iv_max + 1.
    rt_links = CORRESPONDING #( lt_rows ).
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~reported.
    TYPES:
      BEGIN OF ty_row,
        jobname    TYPE btcjob,
        jobcount   TYPE btcjobcnt,
        check_code TYPE zif_ca_ops_types=>ty_check_code,
      END OF ty_row.
    DATA lt_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.
    IF it_keys IS INITIAL.
      RETURN.
    ENDIF.
    SELECT jobname, jobcount, check_code
      FROM zca_ops_job
      FOR ALL ENTRIES IN @it_keys
      WHERE jobname  = @it_keys-jobname
        AND jobcount = @it_keys-jobcount
        AND job_role = @zif_ca_ops_job_types=>gc_role-failed
      INTO CORRESPONDING FIELDS OF TABLE @lt_rows.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      IF iv_failures_only = abap_true
         AND <ls_row>-check_code <> zif_ca_ops_job_types=>gc_code-aborted
         AND <ls_row>-check_code <> zif_ca_ops_job_types=>gc_code-child_failed
         AND <ls_row>-check_code <> zif_ca_ops_job_types=>gc_code-log_error.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( jobname = <ls_row>-jobname jobcount = <ls_row>-jobcount ) INTO TABLE rt_keys.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~scheduler_jobs.
    SELECT sched_folder, sched_job, sap_pattern, criticality, seq
      FROM zca_ops_jobsch
      WHERE active = @abap_true
      ORDER BY seq, sched_folder, sched_job
      INTO CORRESPONDING FIELDS OF TABLE @rt_sched.
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~watermark.
    rs_watermark-area     = iv_area.
    rs_watermark-check_id = iv_check_id.
    SELECT SINGLE wm_date, wm_time, run_id
      FROM zca_ops_jobwm
      WHERE area     = @iv_area
        AND check_id = @iv_check_id
      INTO (@rs_watermark-point-date, @rs_watermark-point-time, @rs_watermark-run_id).
  ENDMETHOD.


  METHOD zif_ca_ops_job_dao~save.
    DATA lt_jobs TYPE STANDARD TABLE OF zca_ops_job WITH EMPTY KEY.
    DATA lt_steps TYPE STANDARD TABLE OF zca_ops_jobstep WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF zca_ops_jobmsg WITH EMPTY KEY.
    DATA lt_applogs TYPE STANDARD TABLE OF zca_ops_jobalog WITH EMPTY KEY.
    DATA lt_objects TYPE STANDARD TABLE OF zca_ops_jobbo WITH EMPTY KEY.
    DATA lv_failed TYPE i.

    lt_jobs = CORRESPONDING #( is_evidence-jobs MAPPING job_role = role ).
    lt_steps = CORRESPONDING #( is_evidence-steps MAPPING step_user = authcknam spool_id = listident ).
    LOOP AT is_evidence-lines ASSIGNING FIELD-SYMBOL(<ls_line>).
      INSERT VALUE #( jobname      = <ls_line>-jobname
                      jobcount     = <ls_line>-jobcount
                      line_no      = <ls_line>-line_no
                      entered_date = <ls_line>-line-enterdate
                      entered_time = <ls_line>-line-entertime
                      msgid        = <ls_line>-line-msgid
                      msgno        = <ls_line>-line-msgno
                      msgtype      = <ls_line>-line-msgtype
                      text         = <ls_line>-line-text ) INTO TABLE lt_lines.
    ENDLOOP.
    LOOP AT is_evidence-applogs ASSIGNING FIELD-SYMBOL(<ls_applog>).
      INSERT VALUE #( jobname   = <ls_applog>-jobname
                      jobcount  = <ls_applog>-jobcount
                      lognumber = <ls_applog>-applog-lognumber
                      object    = <ls_applog>-applog-object
                      subobject = <ls_applog>-applog-subobject
                      extnumber = <ls_applog>-applog-extnumber
                      log_date  = <ls_applog>-applog-aldate
                      log_time  = <ls_applog>-applog-altime
                      log_user  = <ls_applog>-applog-aluser
                      log_prog  = <ls_applog>-applog-alprog
                      msg_cnt_e = <ls_applog>-applog-msg_cnt_e
                      msg_cnt_a = <ls_applog>-applog-msg_cnt_a
                      quality   = <ls_applog>-quality ) INTO TABLE lt_applogs.
    ENDLOOP.
    " objects numbered per job in the order the enrichers delivered them
    LOOP AT is_evidence-objects ASSIGNING FIELD-SYMBOL(<ls_object>).
      DATA(lv_no) = 1 + REDUCE i( INIT lv_count = 0
                                  FOR <ls_done> IN lt_objects
                                  WHERE ( jobname = <ls_object>-jobname AND jobcount = <ls_object>-jobcount )
                                  NEXT lv_count = lv_count + 1 ).
      DATA(ls_object) = CORRESPONDING zca_ops_jobbo( <ls_object> ).
      ls_object-object_no = lv_no.
      INSERT ls_object INTO TABLE lt_objects.
    ENDLOOP.

    IF lt_jobs IS NOT INITIAL.
      MODIFY zca_ops_job FROM TABLE @lt_jobs.
      lv_failed += sy-subrc.
    ENDIF.
    IF lt_steps IS NOT INITIAL.
      MODIFY zca_ops_jobstep FROM TABLE @lt_steps.
      lv_failed += sy-subrc.
    ENDIF.
    IF lt_lines IS NOT INITIAL.
      MODIFY zca_ops_jobmsg FROM TABLE @lt_lines.
      lv_failed += sy-subrc.
    ENDIF.
    IF lt_applogs IS NOT INITIAL.
      MODIFY zca_ops_jobalog FROM TABLE @lt_applogs.
      lv_failed += sy-subrc.
    ENDIF.
    IF lt_objects IS NOT INITIAL.
      MODIFY zca_ops_jobbo FROM TABLE @lt_objects.
      lv_failed += sy-subrc.
    ENDIF.
    IF is_watermark-area IS NOT INITIAL.
      DATA(ls_watermark) = VALUE zca_ops_jobwm( area     = is_watermark-area
                                                check_id = is_watermark-check_id
                                                wm_date  = is_watermark-point-date
                                                wm_time  = is_watermark-point-time
                                                run_id   = is_watermark-run_id ).
      MODIFY zca_ops_jobwm FROM @ls_watermark.
      lv_failed += sy-subrc.
    ENDIF.
    IF lv_failed <> 0.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e129(zca_ops) WITH is_watermark-area is_watermark-check_id.
    ENDIF.
  ENDMETHOD.


  METHOD cap.
    SORT ct_jobs BY jobname jobcount.
    DELETE ct_jobs FROM iv_max + 1.
  ENDMETHOD.


  METHOD check_field.
    DATA(lv_field) = condense( CONV string( iv_field ) ).
    IF NOT matches( val = lv_field pcre = gc_field_pcre ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e127(zca_ops) WITH iv_field.
    ENDIF.
    " second gate before dynamic SQL: a valid column name for the database interface
    TRY.
        cl_abap_dyn_prg=>check_column_name( val = lv_field strict = abap_true ).
      CATCH cx_abap_invalid_name INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e127(zca_ops) WITH iv_field
          EXPORTING
            previous = lx_error.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
