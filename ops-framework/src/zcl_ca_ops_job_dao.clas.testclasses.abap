*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the SAP job monitor's SQL on cl_osql_test_environment
*& doubles of TBTCO, TBTCP, BALHDR and the monitor's tables: cancelled jobs
*& of the client in the window, oldest end first, capped; finished jobs of
*& watched programs only; active jobs started before a point; released jobs
*& with a planned start (event jobs left out); jobs by key; jobs created
*& by a user; jobs by event parameter; steps; application logs of user,
*& program and window; failures already kept (failure codes or any);
*& active scheduler rows in sequence; watermark; save of evidence and
*& watermark (insert or replace); a configured field name that is not a
*& plain name is refused (127). Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
CLASS ltc_job_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        today   TYPE d VALUE '20261111',
        count   TYPE btcjobcnt VALUE '10000001',
        count2  TYPE btcjobcnt VALUE '10000002',
        other_client TYPE mandt VALUE '999',
        program TYPE zif_ca_ops_job_types=>ty_progname VALUE 'ZT_MASS_PROGRAM',
        user    TYPE syuname VALUE 'ZT_BATCH',
        area    TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        check   TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_JOB_FAIL',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_job_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS given_job
      IMPORTING
        iv_name   TYPE btcjob
        iv_count  TYPE btcjobcnt DEFAULT gc-count
        iv_status TYPE zif_ca_ops_job_types=>ty_status
        iv_end    TYPE t DEFAULT '093000'
        iv_client TYPE mandt DEFAULT sy-mandt
        iv_event  TYPE zif_ca_ops_job_types=>ty_eventid OPTIONAL
        iv_parm   TYPE zif_ca_ops_job_types=>ty_eventparm OPTIONAL.
    METHODS given_step
      IMPORTING
        iv_name    TYPE btcjob
        iv_program TYPE zif_ca_ops_job_types=>ty_progname.
    METHODS window
      RETURNING
        VALUE(rs_window) TYPE zif_ca_ops_job_types=>ty_window.

    METHODS aborted_in_window_capped  FOR TESTING.
    METHODS finished_of_programs      FOR TESTING.
    METHODS active_and_waiting        FOR TESTING.
    METHODS keys_creator_and_event    FOR TESTING.
    METHODS steps_and_applogs         FOR TESTING.
    METHODS reported_failure_codes    FOR TESTING.
    METHODS scheduler_rows_active     FOR TESTING.
    METHODS save_and_read_watermark   FOR TESTING.
    METHODS field_name_refused        FOR TESTING.
ENDCLASS.


CLASS ltc_job_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'TBTCO' ) ( 'TBTCP' ) ( 'BALHDR' ) ( 'ZCA_OPS_JOB' ) ( 'ZCA_OPS_JOBSTEP' )
                                   ( 'ZCA_OPS_JOBMSG' ) ( 'ZCA_OPS_JOBALOG' ) ( 'ZCA_OPS_JOBBO' ) ( 'ZCA_OPS_JOBWM' )
                                   ( 'ZCA_OPS_JOBSCH' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_job_dao( ).
  ENDMETHOD.


  METHOD given_job.
    DATA lt_rows TYPE STANDARD TABLE OF tbtco WITH EMPTY KEY.
    DATA ls_row TYPE tbtco.
    ls_row-jobname   = iv_name.
    ls_row-jobcount  = iv_count.
    ls_row-status    = iv_status.
    ls_row-authckman = iv_client.
    ls_row-sdldate   = gc-today.
    ls_row-sdltime   = '090000'.
    ls_row-sdluname  = gc-user.
    ls_row-sdlstrtdt = gc-today.
    ls_row-sdlstrttm = '080000'.
    ls_row-eventid   = iv_event.
    ls_row-eventparm = iv_parm.
    IF iv_status <> zif_ca_ops_job_types=>gc_status-released.
      ls_row-strtdate = gc-today.
      ls_row-strttime = '090500'.
    ENDIF.
    IF iv_status = zif_ca_ops_job_types=>gc_status-aborted OR iv_status = zif_ca_ops_job_types=>gc_status-finished.
      ls_row-enddate = gc-today.
      ls_row-endtime = iv_end.
    ENDIF.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  METHOD given_step.
    DATA lt_rows TYPE STANDARD TABLE OF tbtcp WITH EMPTY KEY.
    DATA ls_row TYPE tbtcp.
    ls_row-jobname   = iv_name.
    ls_row-jobcount  = gc-count.
    ls_row-stepcount = 1.
    ls_row-progname  = iv_program.
    ls_row-authcknam = gc-user.
    INSERT ls_row INTO TABLE lt_rows.
    go_env->insert_test_data( lt_rows ).
  ENDMETHOD.


  METHOD window.
    rs_window-from = VALUE #( date = gc-today time = '090000' ).
    rs_window-to   = VALUE #( date = gc-today time = '100000' ).
  ENDMETHOD.


  " Rule: cancelled jobs of this client that ended in the window, oldest end first, at most the cap
  METHOD aborted_in_window_capped.
    TRY.
        given_job( iv_name = 'ZT_LATE' iv_status = zif_ca_ops_job_types=>gc_status-aborted iv_end = '094000' ).
        given_job( iv_name = 'ZT_EARLY' iv_status = zif_ca_ops_job_types=>gc_status-aborted iv_end = '091000' ).
        given_job( iv_name = 'ZT_BEFORE' iv_status = zif_ca_ops_job_types=>gc_status-aborted iv_end = '085900' ).
        given_job( iv_name = 'ZT_CLIENT' iv_status = zif_ca_ops_job_types=>gc_status-aborted iv_client = gc-other_client ).
        given_job( iv_name = 'ZT_FINE' iv_status = zif_ca_ops_job_types=>gc_status-finished ).
        DATA(lt_jobs) = mo_cut->aborted_jobs( is_window = window( ) iv_max = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_jobs ) exp = 2 msg = 'Two cancelled jobs of the window' ).
        cl_abap_unit_assert=>assert_equals( act = lt_jobs[ 1 ]-jobname exp = 'ZT_EARLY' msg = 'Oldest end first' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->aborted_jobs( is_window = window( ) iv_max = 1 ) ) exp = 1
                                            msg = 'Capped' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: finished jobs only with a step of a watched program; no program = nothing
  METHOD finished_of_programs.
    TRY.
        given_job( iv_name = 'ZT_WATCHED' iv_status = zif_ca_ops_job_types=>gc_status-finished ).
        given_step( iv_name = 'ZT_WATCHED' iv_program = gc-program ).
        given_job( iv_name = 'ZT_OTHER' iv_status = zif_ca_ops_job_types=>gc_status-finished ).
        given_step( iv_name = 'ZT_OTHER' iv_program = 'ZT_OTHER_PROGRAM' ).
        DATA(lt_programs) = VALUE zif_ca_ops_types=>tt_param_range( ( sign = 'I' option = 'EQ' low = gc-program ) ).
        DATA(lt_jobs) = mo_cut->finished_jobs( is_window = window( ) it_programs = lt_programs iv_max = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_jobs ) exp = 1 msg = 'One watched job' ).
        cl_abap_unit_assert=>assert_equals( act = lt_jobs[ 1 ]-jobname exp = 'ZT_WATCHED' msg = 'Of the program' ).
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->finished_jobs( is_window = window( ) it_programs = VALUE #( ) iv_max = 10 )
          msg = 'No program, nothing read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: active jobs started before the point; released jobs planned before the point, event jobs left out
  METHOD active_and_waiting.
    TRY.
        given_job( iv_name = 'ZT_RUNNING' iv_status = zif_ca_ops_job_types=>gc_status-running ).
        given_job( iv_name = 'ZT_RELEASED' iv_status = zif_ca_ops_job_types=>gc_status-released ).
        given_job( iv_name = 'ZT_EVENT' iv_status = zif_ca_ops_job_types=>gc_status-released iv_event = 'ZT_EVENT' ).
        DATA(lt_active) = mo_cut->active_jobs( is_started_before = VALUE #( date = gc-today time = '093000' ) iv_max = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_active ) exp = 1 msg = 'One active job' ).
        DATA(lt_waiting) = mo_cut->waiting_jobs(
                             it_statuses = VALUE #( ( sign = 'I' option = 'EQ' low = zif_ca_ops_job_types=>gc_status-released ) )
                             is_planned_before = VALUE #( date = gc-today time = '093000' ) iv_max = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_waiting ) exp = 1 msg = 'One waiting job' ).
        cl_abap_unit_assert=>assert_equals( act = lt_waiting[ 1 ]-jobname exp = 'ZT_RELEASED' msg = 'Not the event job' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: jobs by key, created by a user in a window, waiting for an event parameter
  METHOD keys_creator_and_event.
    TRY.
        given_job( iv_name = 'ZT_PARENT' iv_status = zif_ca_ops_job_types=>gc_status-finished ).
        given_job( iv_name = 'ZT_CHILD' iv_count = gc-count2 iv_status = zif_ca_ops_job_types=>gc_status-aborted
                   iv_event = 'SAP_END_OF_JOB' iv_parm = 'ZT_PARENT' ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( mo_cut->jobs( VALUE #( ( jobname = 'ZT_PARENT' jobcount = gc-count ) ) ) ) exp = 1
          msg = 'By key' ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( mo_cut->jobs_created( is_window = window( )
                                             it_users  = VALUE #( ( sign = 'I' option = 'EQ' low = gc-user ) )
                                             iv_max    = 10 ) ) exp = 2
          msg = 'Created by the user in the window' ).
        DATA(lt_children) = mo_cut->jobs_by_event( it_events = VALUE #( ( eventid = 'SAP_END_OF_JOB' eventparm = 'ZT_PARENT' ) )
                                                   iv_max    = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_children ) exp = 1 msg = 'By event parameter' ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( mo_cut->jobs_running( is_window = window( ) it_programs = VALUE #( ) iv_max = 10 ) ) exp = 2
          msg = 'Both ran in the window' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: steps by job; application logs of the user and program in the window
  METHOD steps_and_applogs.
    DATA lt_logs TYPE STANDARD TABLE OF balhdr WITH EMPTY KEY.
    DATA ls_log TYPE balhdr.
    TRY.
        given_step( iv_name = 'ZT_JOB' iv_program = gc-program ).
        ls_log-lognumber = 'ZT00000001'.
        ls_log-aldate    = gc-today.
        ls_log-altime    = '091500'.
        ls_log-aluser    = gc-user.
        ls_log-alprog    = gc-program.
        INSERT ls_log INTO TABLE lt_logs.
        ls_log-lognumber = 'ZT00000002'.
        ls_log-aluser    = 'ZT_OTHER'.
        INSERT ls_log INTO TABLE lt_logs.
        go_env->insert_test_data( lt_logs ).
        DATA(lt_steps) = mo_cut->steps( VALUE #( ( jobname = 'ZT_JOB' jobcount = gc-count ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lt_steps[ 1 ]-progname exp = gc-program msg = 'Program of the step' ).
        DATA(lt_applogs) = mo_cut->applogs( is_window   = window( )
                                            it_users    = VALUE #( ( sign = 'I' option = 'EQ' low = gc-user ) )
                                            it_programs = VALUE #( ( sign = 'I' option = 'EQ' low = gc-program ) )
                                            iv_max      = 10 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_applogs ) exp = 1 msg = 'The user''s log only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a job kept with a failure code is reported; a long-running row counts only for "any finding"
  METHOD reported_failure_codes.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_job WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_job.
    TRY.
        ls_row-job_role   = zif_ca_ops_job_types=>gc_role-failed.
        ls_row-jobname    = 'ZT_ABORTED'.
        ls_row-jobcount   = gc-count.
        ls_row-check_code = zif_ca_ops_job_types=>gc_code-aborted.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-jobname    = 'ZT_LONG'.
        ls_row-check_code = zif_ca_ops_job_types=>gc_code-long_running.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_keys) = VALUE zif_ca_ops_job_types=>tt_job_key( ( jobname = 'ZT_ABORTED' jobcount = gc-count )
                                                                ( jobname = 'ZT_LONG' jobcount = gc-count ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->reported( lt_keys ) ) exp = 1 msg = 'Failure codes only' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->reported( it_keys = lt_keys iv_failures_only = abap_false ) )
                                            exp = 2 msg = 'Any finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: active scheduler rows in sequence
  METHOD scheduler_rows_active.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_jobsch WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_jobsch.
    TRY.
        ls_row-sched_folder = 'ZT_F'.
        ls_row-sched_job    = 'ZT_B'.
        ls_row-sap_pattern  = 'ZT_B.*'.
        ls_row-active       = abap_true.
        ls_row-seq          = 20.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-sched_job    = 'ZT_A'.
        ls_row-sap_pattern  = 'ZT_A.*'.
        ls_row-seq          = 10.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-sched_job    = 'ZT_C'.
        ls_row-sap_pattern  = 'ZT_C.*'.
        ls_row-active       = abap_false.
        ls_row-seq          = 5.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_sched) = mo_cut->scheduler_jobs( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_sched ) exp = 2 msg = 'Active rows' ).
        cl_abap_unit_assert=>assert_equals( act = lt_sched[ 1 ]-sched_job exp = 'ZT_A' msg = 'In sequence' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: evidence and watermark are written (insert or replace) and the watermark is read back
  METHOD save_and_read_watermark.
    TRY.
        DATA(ls_evidence) = VALUE zif_ca_ops_job_types=>ty_evidence_set(
          jobs    = VALUE #( ( jobname = 'ZT_JOB' jobcount = gc-count role = zif_ca_ops_job_types=>gc_role-failed
                               check_code = zif_ca_ops_job_types=>gc_code-aborted ) )
          steps   = VALUE #( ( jobname = 'ZT_JOB' jobcount = gc-count stepcount = 1 progname = gc-program ) )
          lines   = VALUE #( ( jobname = 'ZT_JOB' jobcount = gc-count line_no = 1
                               line = VALUE #( msgid = 'ZT' msgno = '001' msgtype = 'A' ) ) )
          objects = VALUE #( ( jobname = 'ZT_JOB' jobcount = gc-count object_type = 'ZT_RUN' )
                             ( jobname = 'ZT_JOB' jobcount = gc-count object_type = 'ZT_PAY' ) ) ).
        DATA(ls_mark) = VALUE zif_ca_ops_job_types=>ty_watermark( area = gc-area check_id = gc-check
                                                                  point = VALUE #( date = gc-today time = '100000' ) ).
        mo_cut->save( is_evidence = ls_evidence is_watermark = ls_mark ).
        mo_cut->save( is_evidence = ls_evidence is_watermark = ls_mark ).
        SELECT COUNT(*) FROM zca_ops_jobbo INTO @DATA(lv_objects).
        cl_abap_unit_assert=>assert_equals( act = lv_objects exp = 2 msg = 'Objects numbered per job, replaced' ).
        SELECT COUNT(*) FROM zca_ops_job INTO @DATA(lv_jobs).
        cl_abap_unit_assert=>assert_equals( act = lv_jobs exp = 1 msg = 'One job row' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->watermark( iv_area = gc-area iv_check_id = gc-check )-point
                                            exp = ls_mark-point msg = 'Watermark read back' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a field name with other characters never reaches dynamic SQL (127)
  METHOD field_name_refused.
    TRY.
        mo_cut->parents_by_fields( it_keys        = VALUE #( ( jobname = 'ZT_JOB' jobcount = gc-count ) )
                                   iv_name_field  = 'JOBNAME, X'
                                   iv_count_field = 'JOBCOUNT' ).
        cl_abap_unit_assert=>fail( msg = 'Expected 127' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '127'
                                            msg = 'Refused' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
