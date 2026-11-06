*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_tech_jobs.clas.testclasses.abap
*& Purpose:
*& Unit tests of the technical job check: cancelled, long-running and late
*& jobs, an old unfinished job outside the window, duplicates of window and
*& unresolved reads counted once, capped read, missing patterns. The DAO is
*& a test double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*& 2026-11-06 | PARAM1 job names as PCRE; an invalid pattern raises message 373 (bad_pattern_raises).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_runs TYPE zif_cd_hck_types=>tt_job_run.
    DATA mt_unresolved TYPE zif_cd_hck_types=>tt_job_run.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_job_runs.
    rt_runs = mt_runs.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_unresolved_jobs.
    rt_runs = mt_unresolved.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_tech_jobs DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check     TYPE zif_cd_hck_types=>ty_check_id VALUE 'E_TECH_JOBS',
      gc_patterns  TYPE zif_cd_hck_types=>ty_param VALUE 'ZCD_.*',
      gc_bad       TYPE zif_cd_hck_types=>ty_param VALUE 'ZCD_.*, ZCD_(FPY1',
      gc_job       TYPE zif_cd_hck_types=>ty_jobname VALUE 'ZCD_FPY1_PAYRUN',
      gc_count_1   TYPE zif_cd_hck_types=>ty_jobcount VALUE '00000001',
      gc_count_2   TYPE zif_cd_hck_types=>ty_jobcount VALUE '00000002',
      gc_count_3   TYPE zif_cd_hck_types=>ty_jobcount VALUE '00000003',
      gc_count_4   TYPE zif_cd_hck_types=>ty_jobcount VALUE '00000004',
      gc_today     TYPE d VALUE '20261106',
      gc_last_week TYPE d VALUE '20261030',
      gc_now       TYPE t VALUE '070000',
      gc_early     TYPE t VALUE '010000',
      gc_recent    TYPE t VALUE '065000'.

    TYPES:
      BEGIN OF ty_flags,
        no_patterns TYPE abap_bool,
        bad_pattern TYPE abap_bool,
        cancelled   TYPE abap_bool,
        long_run    TYPE abap_bool,
        short_run   TYPE abap_bool,
        late        TYPE abap_bool,
        old_stuck   TYPE abap_bool,
        duplicate   TYPE abap_bool,
        capped      TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA ms_def TYPE zif_cd_hck_types=>ty_check_def.

    METHODS setup.
    METHODS teardown.
    METHODS cancelled_job_is_error FOR TESTING.
    METHODS long_running_is_warning FOR TESTING.
    METHODS short_running_is_ignored FOR TESTING.
    METHODS late_start_is_warning FOR TESTING.
    METHODS old_stuck_job_is_seen FOR TESTING.
    METHODS duplicate_counted_once FOR TESTING.
    METHODS capped_read_is_reported FOR TESTING.
    METHODS missing_patterns_raises FOR TESTING.
    METHODS bad_pattern_raises FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS run
      IMPORTING
        iv_count  TYPE zif_cd_hck_types=>ty_jobcount
        iv_status TYPE zif_cd_hck_types=>ty_job_status
        iv_date   TYPE d
        iv_time   TYPE t
      RETURNING
        VALUE(rs_run) TYPE zif_cd_hck_types=>ty_job_run.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
    METHODS metric_value
      IMPORTING
        is_result       TYPE zif_cd_hck_types=>ty_check_result
        iv_metric       TYPE zif_cd_hck_types=>ty_metric_name
      RETURNING
        VALUE(rv_value) TYPE zif_cd_hck_types=>ty_value.
ENDCLASS.


CLASS ltc_tech_jobs IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    CLEAR ms_def.
    ms_def-check_id = gc_check.
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD run.
    rs_run-jobname  = gc_job.
    rs_run-jobcount = iv_count.
    rs_run-status   = iv_status.
    rs_run-strtdate = iv_date.
    rs_run-strttime = iv_time.
    rs_run-sdlstrtdt = iv_date.
    rs_run-sdlstrttm = iv_time.
  ENDMETHOD.


  METHOD configure_scenario.
    IF is_flags-no_patterns = abap_false.
      ms_def-param1 = gc_patterns.
    ENDIF.
    IF is_flags-bad_pattern = abap_true.
      ms_def-param1 = gc_bad.
    ENDIF.
    IF is_flags-cancelled = abap_true.
      INSERT run( iv_count = gc_count_1 iv_status = zif_cd_hck_types=>gc_job_status-aborted
                  iv_date = gc_today iv_time = gc_early ) INTO TABLE mo_dao->mt_runs.
    ENDIF.
    IF is_flags-long_run = abap_true.
      INSERT run( iv_count = gc_count_2 iv_status = zif_cd_hck_types=>gc_job_status-running
                  iv_date = gc_today iv_time = gc_early ) INTO TABLE mo_dao->mt_runs.
    ENDIF.
    IF is_flags-short_run = abap_true.
      INSERT run( iv_count = gc_count_2 iv_status = zif_cd_hck_types=>gc_job_status-running
                  iv_date = gc_today iv_time = gc_recent ) INTO TABLE mo_dao->mt_runs.
    ENDIF.
    IF is_flags-late = abap_true.
      INSERT run( iv_count = gc_count_3 iv_status = zif_cd_hck_types=>gc_job_status-released
                  iv_date = gc_today iv_time = gc_early ) INTO TABLE mo_dao->mt_runs.
    ENDIF.
    IF is_flags-old_stuck = abap_true.
      INSERT run( iv_count = gc_count_4 iv_status = zif_cd_hck_types=>gc_job_status-running
                  iv_date = gc_last_week iv_time = gc_early ) INTO TABLE mo_dao->mt_unresolved.
    ENDIF.
    IF is_flags-duplicate = abap_true.
      " the same running job delivered by the window read and by the unresolved read
      INSERT run( iv_count = gc_count_2 iv_status = zif_cd_hck_types=>gc_job_status-running
                  iv_date = gc_today iv_time = gc_early ) INTO TABLE mo_dao->mt_unresolved.
    ENDIF.
    IF is_flags-capped = abap_true.
      DO zif_cd_hck_types=>gc_max_job_rows TIMES.
        INSERT run( iv_count = CONV #( sy-index ) iv_status = zif_cd_hck_types=>gc_job_status-finished
                    iv_date = gc_today iv_time = gc_early ) INTO TABLE mo_dao->mt_runs.
      ENDDO.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_tech_jobs( )->zif_cd_hck_check~execute(
      is_def        = ms_def
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc_today now_date = gc_today now_time = gc_now ) ).
  ENDMETHOD.


  METHOD metric_value.
    rv_value = VALUE #( is_result-metrics[ metric = iv_metric ]-value OPTIONAL ).
  ENDMETHOD.


  " Rule: a cancelled job is an error finding and counted in CANCELLED
  METHOD cancelled_job_is_error.
    TRY.
        configure_scenario( VALUE #( cancelled = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_cd_hck_types=>gc_code-job_cancelled
                                            msg = 'JOB_CANCELLED reported' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-severity
                                            exp = zif_cd_ops_types=>gc_severity-error
                                            msg = 'Cancelled job is an error' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-object_key
                                            exp = |{ gc_job }/{ gc_count_1 }|
                                            msg = 'Finding key is job name / count' ).
        cl_abap_unit_assert=>assert_equals( act = metric_value( is_result = ls_result
                                                                iv_metric = zcl_cd_hck_c_tech_jobs=>gc_metric-cancelled )
                                            exp = 1
                                            msg = 'CANCELLED = 1' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a job active longer than PARAM2 (default 120 min) is a warning
  METHOD long_running_is_warning.
    TRY.
        configure_scenario( VALUE #( long_run = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_cd_hck_types=>gc_code-job_long_running
                                            msg = 'JOB_LONG_RUNNING reported' ).
        cl_abap_unit_assert=>assert_equals( act = metric_value( is_result = ls_result
                                                                iv_metric = zcl_cd_hck_c_tech_jobs=>gc_metric-long_running )
                                            exp = 1
                                            msg = 'LONG_RUNNING = 1' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a job running within the limit is no finding
  METHOD short_running_is_ignored.
    TRY.
        configure_scenario( VALUE #( short_run = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'No finding within the limit' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-metrics ) exp = 3 msg = 'Three metrics always' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a released job past its planned start + grace (default 30 min) is a late start
  METHOD late_start_is_warning.
    TRY.
        configure_scenario( VALUE #( late = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_cd_hck_types=>gc_code-job_late_start
                                            msg = 'JOB_LATE_START reported' ).
        cl_abap_unit_assert=>assert_equals( act = metric_value( is_result = ls_result
                                                                iv_metric = zcl_cd_hck_c_tech_jobs=>gc_metric-late_start )
                                            exp = 1
                                            msg = 'LATE_START = 1' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A44): a job stuck since last week stays visible although outside the window
  METHOD old_stuck_job_is_seen.
    TRY.
        configure_scenario( VALUE #( old_stuck = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'Old stuck job reported' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-object_key
                                            exp = |{ gc_job }/{ gc_count_4 }|
                                            msg = 'The unresolved job is the finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a job returned by both reads is counted once
  METHOD duplicate_counted_once.
    TRY.
        configure_scenario( VALUE #( long_run = abap_true duplicate = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One finding' ).
        cl_abap_unit_assert=>assert_equals( act = metric_value( is_result = ls_result
                                                                iv_metric = zcl_cd_hck_c_tech_jobs=>gc_metric-long_running )
                                            exp = 1
                                            msg = 'Counted once' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A44): a read at its cap is reported, the counts may be incomplete
  METHOD capped_read_is_reported.
    TRY.
        configure_scenario( VALUE #( capped = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'Only the cap finding' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_cd_hck_types=>gc_code-job_read_capped
                                            msg = 'JOB_READ_CAPPED reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without job name patterns (PARAM1) the check raises
  METHOD missing_patterns_raises.
    configure_scenario( VALUE #( no_patterns = abap_true ) ).
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'Missing PARAM1 must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Configuration error raised' ).
    ENDTRY.
  ENDMETHOD.


  " A job-name pattern that is not valid PCRE is a configuration error of the check (373),
  " never an empty job selection
  METHOD bad_pattern_raises.
    configure_scenario( VALUE #( bad_pattern = abap_true ) ).
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'An invalid PARAM1 pattern must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '373'
                                            msg = 'Message 373 names the invalid pattern' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
