*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_monitor.clas.testclasses.abap
*& Purpose:
*& Tests of the SAP job monitor engine through FAILURES / STATES / WINDOW
*& with doubles of its data access (TBTCO / TBTCP / BALHDR reads and the
*& evidence tables), of the job log reader (no BP_JOBLOG_READ), of a
*& resolver, a claim and an enricher (plug-ins injected by class name) and
*& of the clock; parameters from the in-memory seed. Rules: a cancelled job
*& is JOB_ABORTED; a failed child under a root that finished is
*& JOB_CHILD_FAILED (recursive to the root), under a cancelled root it is
*& JOB_ABORTED; a finished job of a watched program with error lines is
*& JOB_LOG_ERROR, without none; the log budget holds the watermark; the
*& overlap is not reported twice; excluded names are dropped, an invalid
*& pattern is a finding; a claimed job is information only; test mode
*& saves nothing; the first run uses the look-back, later runs the
*& watermark minus the overlap; a capped read moves the watermark back; a
*& failing resolver is a finding and the failure is still reported; the
*& company code of an enricher's object and the scheduler job of the root
*& reach finding and evidence; long-running and not started jobs.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_dao.
    DATA mt_aborted TYPE zif_ca_ops_job_types=>tt_job.
    DATA mt_finished TYPE zif_ca_ops_job_types=>tt_job.
    DATA mt_active TYPE zif_ca_ops_job_types=>tt_job.
    DATA mt_waiting TYPE zif_ca_ops_job_types=>tt_job.
    DATA mt_known TYPE zif_ca_ops_job_types=>tt_job.
    DATA mt_steps TYPE zif_ca_ops_job_types=>tt_step.
    DATA mt_applogs TYPE zif_ca_ops_job_types=>tt_applog.
    DATA mt_reported TYPE zif_ca_ops_job_types=>tt_job_key.
    DATA mt_sched TYPE zif_ca_ops_job_types=>tt_sched.
    DATA ms_watermark TYPE zif_ca_ops_job_types=>ty_watermark.
    DATA ms_window TYPE zif_ca_ops_job_types=>ty_window.
    DATA ms_saved TYPE zif_ca_ops_job_types=>ty_evidence_set.
    DATA ms_saved_watermark TYPE zif_ca_ops_job_types=>ty_watermark.
    DATA mv_saves TYPE i.
  PRIVATE SECTION.
    METHODS cut
      IMPORTING
        it_jobs        TYPE zif_ca_ops_job_types=>tt_job
        iv_max         TYPE i
      RETURNING
        VALUE(rt_jobs) TYPE zif_ca_ops_job_types=>tt_job.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD cut.
    rt_jobs = it_jobs.
    DELETE rt_jobs FROM iv_max + 1.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~aborted_jobs.
    ms_window = is_window.
    rt_jobs = cut( it_jobs = mt_aborted iv_max = iv_max ).
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~finished_jobs.
    IF it_programs IS NOT INITIAL.
      rt_jobs = cut( it_jobs = mt_finished iv_max = iv_max ).
    ENDIF.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~active_jobs.
    rt_jobs = cut( it_jobs = mt_active iv_max = iv_max ).
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~waiting_jobs.
    rt_jobs = cut( it_jobs = mt_waiting iv_max = iv_max ).
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~jobs.
    LOOP AT mt_known ASSIGNING FIELD-SYMBOL(<ls_job>).
      IF line_exists( it_keys[ jobname = <ls_job>-jobname jobcount = <ls_job>-jobcount ] ).
        INSERT <ls_job> INTO TABLE rt_jobs.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~jobs_created.
    CLEAR rt_jobs.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~jobs_running.
    CLEAR rt_jobs.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~jobs_by_event.
    CLEAR rt_jobs.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~steps.
    LOOP AT mt_steps ASSIGNING FIELD-SYMBOL(<ls_step>).
      IF line_exists( it_keys[ jobname = <ls_step>-jobname jobcount = <ls_step>-jobcount ] ).
        INSERT <ls_step> INTO TABLE rt_steps.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~applogs.
    rt_applogs = mt_applogs.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~parents_by_fields.
    CLEAR rt_links.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~children_by_fields.
    CLEAR rt_links.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~reported.
    LOOP AT mt_reported ASSIGNING FIELD-SYMBOL(<ls_key>).
      IF line_exists( it_keys[ jobname = <ls_key>-jobname jobcount = <ls_key>-jobcount ] ).
        INSERT <ls_key> INTO TABLE rt_keys.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~scheduler_jobs.
    rt_sched = mt_sched.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~watermark.
    rs_watermark = ms_watermark.
    rs_watermark-area     = iv_area.
    rs_watermark-check_id = iv_check_id.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~save.
    mv_saves += 1.
    ms_saved = is_evidence.
    ms_saved_watermark = is_watermark.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_log DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_log.
    TYPES:
      BEGIN OF ty_log,
        jobname  TYPE btcjob,
        jobcount TYPE btcjobcnt,
        line     TYPE zif_ca_ops_job_types=>ty_log_line,
      END OF ty_log.
    DATA mt_logs TYPE STANDARD TABLE OF ty_log WITH EMPTY KEY.
    DATA mv_reads TYPE i.
ENDCLASS.

CLASS ltd_log IMPLEMENTATION.
  METHOD zif_ca_ops_job_log~read.
    mv_reads += 1.
    LOOP AT mt_logs ASSIGNING FIELD-SYMBOL(<ls_log>) WHERE jobname = iv_jobname AND jobcount = iv_jobcount.
      INSERT <ls_log>-line INTO TABLE rt_lines.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_resolver DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_resolver.
    DATA mt_links TYPE zif_ca_ops_job_types=>tt_link.
    DATA mv_fail TYPE abap_bool.
ENDCLASS.

CLASS ltd_resolver IMPLEMENTATION.
  METHOD zif_ca_ops_job_resolver~id.
    rv_id = 'ZT_RES'.
  ENDMETHOD.
  METHOD zif_ca_ops_job_resolver~parents.
    IF mv_fail = abap_true.
      RAISE EXCEPTION TYPE zcx_ca_ops_error MESSAGE e127(zca_ops) WITH 'ZT_FIELD'.
    ENDIF.
    LOOP AT mt_links ASSIGNING FIELD-SYMBOL(<ls_link>).
      IF line_exists( it_jobs[ jobname = <ls_link>-child_name jobcount = <ls_link>-child_count ] ).
        INSERT <ls_link> INTO TABLE rt_links.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_job_resolver~children.
    LOOP AT mt_links ASSIGNING FIELD-SYMBOL(<ls_link>).
      IF line_exists( it_jobs[ jobname = <ls_link>-parent_name jobcount = <ls_link>-parent_count ] ).
        INSERT <ls_link> INTO TABLE rt_links.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_claim DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_claim.
    DATA mv_jobname TYPE btcjob.
ENDCLASS.

CLASS ltd_claim IMPLEMENTATION.
  METHOD zif_ca_ops_job_claim~claimed.
    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>) WHERE jobname = mv_jobname.
      INSERT VALUE #( jobname = <ls_job>-jobname jobcount = <ls_job>-jobcount claimer = 'ZT_CYCLE/010' )
        INTO TABLE rt_claims.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_enricher DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_enricher.
    DATA mv_bukrs TYPE bukrs.
ENDCLASS.

CLASS ltd_enricher IMPLEMENTATION.
  METHOD zif_ca_ops_job_enricher~enrich.
    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      INSERT VALUE #( jobname     = <ls_job>-jobname
                      jobcount    = <ls_job>-jobcount
                      enricher    = 'ZT_ENRICHER'
                      object_type = 'ZT_RUN'
                      object_key  = <ls_job>-jobname
                      bukrs       = mv_bukrs
                      quality     = zif_ca_ops_job_types=>gc_quality-probable ) INTO TABLE ct_objects.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261111100000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261111'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '100000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_monitor DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        check_id  TYPE zif_ca_ops_chk_types=>ty_check_id VALUE 'ZT_JOB_FAIL',
        resolver  TYPE string VALUE `ZT_RESOLVER`,
        claim     TYPE string VALUE `ZT_CLAIM`,
        enricher  TYPE string VALUE `ZT_ENRICHER`,
        child     TYPE btcjob VALUE 'ZT_WORKER_01',
        parent    TYPE btcjob VALUE 'ZT_SCHEDULER',
        root      TYPE btcjob VALUE 'ZT_ROOT',
        other     TYPE btcjob VALUE 'ZT_OTHER',
        count     TYPE btcjobcnt VALUE '10000001',
        count2    TYPE btcjobcnt VALUE '10000002',
        today     TYPE d VALUE '20261111',
        program   TYPE string VALUE `ZT_MASS_PROGRAM`,
        bukrs     TYPE bukrs VALUE 'ZT01',
        run_id    TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000E1',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_log TYPE REF TO ltd_log.
    DATA mo_resolver TYPE REF TO ltd_resolver.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.
    DATA mv_test_mode TYPE abap_bool.

    METHODS setup.
    METHODS teardown.

    "! A TBTCO row of today
    METHODS job
      IMPORTING
        iv_name       TYPE btcjob
        iv_count      TYPE btcjobcnt DEFAULT gc-count
        iv_status     TYPE zif_ca_ops_job_types=>ty_status DEFAULT zif_ca_ops_job_types=>gc_status-aborted
        iv_end        TYPE t DEFAULT '093000'
      RETURNING
        VALUE(rs_job) TYPE zif_ca_ops_job_types=>ty_job.

    METHODS link
      IMPORTING
        iv_parent TYPE btcjob
        iv_child  TYPE btcjob.

    METHODS failures
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result.

    METHODS states
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result.

    METHODS only_finding
      IMPORTING
        is_result         TYPE zif_ca_ops_chk_types=>ty_result
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    METHODS aborted_job_is_reported   FOR TESTING.
    METHODS child_under_finished_root FOR TESTING.
    METHODS child_under_aborted_root  FOR TESTING.
    METHODS root_two_levels_up        FOR TESTING.
    METHODS finished_with_log_errors  FOR TESTING.
    METHODS log_budget_holds_mark     FOR TESTING.
    METHODS overlap_not_reported      FOR TESTING.
    METHODS excluded_and_invalid      FOR TESTING.
    METHODS claimed_is_information    FOR TESTING.
    METHODS test_mode_saves_nothing   FOR TESTING.
    METHODS window_lookback_overlap   FOR TESTING.
    METHODS capped_read_moves_mark    FOR TESTING.
    METHODS failing_resolver          FOR TESTING.
    METHODS company_code_and_sched    FOR TESTING.
    METHODS long_running_not_started  FOR TESTING.
ENDCLASS.


CLASS ltc_monitor IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    mo_log = NEW #( ).
    mo_resolver = NEW #( ).
    mv_test_mode = abap_false.
    mo_seed = NEW #( ).
    mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-resolvers iv_value = gc-resolver ).
    mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-log_programs iv_value = gc-program ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = CONV #( gc-resolver ) io_instance = mo_resolver ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD job.
    rs_job = VALUE #( jobname = iv_name jobcount = iv_count status = iv_status
                      sdldate = gc-today sdltime = '090000' sdluname = 'ZT_BATCH'
                      strtdate = gc-today strttime = '090500' ).
    IF iv_status <> zif_ca_ops_job_types=>gc_status-running.
      rs_job-enddate = gc-today.
      rs_job-endtime = iv_end.
    ENDIF.
  ENDMETHOD.


  METHOD link.
    INSERT VALUE #( parent_name = iv_parent parent_count = gc-count child_name = iv_child child_count = gc-count
                    resolver = 'ZT_RES' quality = zif_ca_ops_job_types=>gc_quality-probable ) INTO TABLE mo_resolver->mt_links.
  ENDMETHOD.


  METHOD failures.
    DATA(lo_cut) = NEW zcl_ca_ops_job_monitor( io_dao = mo_dao io_log = mo_log ).
    rs_result = lo_cut->failures( is_check   = VALUE #( area = gc-area check_id = gc-check_id )
                                  is_context = VALUE #( area = gc-area run_id = gc-run_id today = gc-today
                                                        test_mode = mv_test_mode ) ).
  ENDMETHOD.


  METHOD states.
    DATA(lo_cut) = NEW zcl_ca_ops_job_monitor( io_dao = mo_dao io_log = mo_log ).
    rs_result = lo_cut->states( is_check   = VALUE #( area = gc-area check_id = gc-check_id )
                                is_context = VALUE #( area = gc-area run_id = gc-run_id today = gc-today ) ).
  ENDMETHOD.


  METHOD only_finding.
    LOOP AT is_result-findings INTO rs_finding WHERE check_code = iv_code.
      RETURN.
    ENDLOOP.
    cl_abap_unit_assert=>fail( msg = |No finding { iv_code }| ).
  ENDMETHOD.


  " Rule: a cancelled job without a linked ancestor is JOB_ABORTED (error), kept with the new watermark
  METHOD aborted_job_is_reported.
    TRY.
        INSERT job( gc-other ) INTO TABLE mo_dao->mt_aborted.
        DATA(ls_result) = failures( ).
        DATA(ls_finding) = only_finding( is_result = ls_result iv_code = zif_ca_ops_job_types=>gc_code-aborted ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-error
                                            msg = 'A cancelled job is an error' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = |{ gc-other }/{ gc-count }|
                                            msg = 'Object key = job name / job count' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One finding' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-partial msg = 'Incremental: never auto-resolved' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_saved-jobs[ 1 ]-role exp = zif_ca_ops_job_types=>gc_role-failed
                                            msg = 'Kept as a failure' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_saved_watermark-point
                                            exp = VALUE zif_ca_ops_job_types=>ty_point( date = gc-today time = '100000' )
                                            msg = 'Watermark = end of the window (now)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the scheduler job finished (what the scheduler sees), its child failed: JOB_CHILD_FAILED with the root
  METHOD child_under_finished_root.
    TRY.
        INSERT job( gc-child ) INTO TABLE mo_dao->mt_aborted.
        INSERT job( iv_name = gc-parent iv_status = zif_ca_ops_job_types=>gc_status-finished ) INTO TABLE mo_dao->mt_known.
        link( iv_parent = gc-parent iv_child = gc-child ).
        DATA(ls_result) = failures( ).
        DATA(ls_finding) = only_finding( is_result = ls_result iv_code = zif_ca_ops_job_types=>gc_code-child_failed ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-error
                                            msg = 'A failed child under a fine parent is an error' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-reference exp = gc-parent msg = 'Carries the root job' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-findings[
                                                     check_code = zif_ca_ops_job_types=>gc_code-aborted ] ) )
                                           msg = 'One finding per failed job' ).
        DATA(ls_parent) = mo_dao->ms_saved-jobs[ jobname = gc-parent ].
        cl_abap_unit_assert=>assert_equals( act = ls_parent-role exp = zif_ca_ops_job_types=>gc_role-ancestor
                                            msg = 'The parent is kept as ancestor' ).
        cl_abap_unit_assert=>assert_equals( act = ls_parent-failed_children exp = 1 msg = 'With its failed child' ).
        DATA(ls_child) = mo_dao->ms_saved-jobs[ jobname = gc-child ].
        cl_abap_unit_assert=>assert_equals( act = ls_child-parent_jobname exp = gc-parent msg = 'Child linked to parent' ).
        cl_abap_unit_assert=>assert_equals( act = ls_child-link_quality exp = zif_ca_ops_job_types=>gc_quality-probable
                                            msg = 'With the resolver quality' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: under a cancelled root the scheduler already saw the failure: the child is JOB_ABORTED
  METHOD child_under_aborted_root.
    TRY.
        INSERT job( gc-child ) INTO TABLE mo_dao->mt_aborted.
        INSERT job( gc-parent ) INTO TABLE mo_dao->mt_known.
        link( iv_parent = gc-parent iv_child = gc-child ).
        DATA(ls_result) = failures( ).
        cl_abap_unit_assert=>assert_equals( act = only_finding( is_result = ls_result
                                                                iv_code   = zif_ca_ops_job_types=>gc_code-aborted )-object_key
                                            exp = |{ gc-child }/{ gc-count }|
                                            msg = 'Cancelled child of a cancelled root' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-findings[
                                                     check_code = zif_ca_ops_job_types=>gc_code-child_failed ] ) )
                                           msg = 'No child-failed finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the parents are followed recursively; the root is the topmost ancestor
  METHOD root_two_levels_up.
    TRY.
        INSERT job( gc-child ) INTO TABLE mo_dao->mt_aborted.
        INSERT job( iv_name = gc-parent iv_status = zif_ca_ops_job_types=>gc_status-finished ) INTO TABLE mo_dao->mt_known.
        INSERT job( iv_name = gc-root iv_status = zif_ca_ops_job_types=>gc_status-running ) INTO TABLE mo_dao->mt_known.
        link( iv_parent = gc-parent iv_child = gc-child ).
        link( iv_parent = gc-root iv_child = gc-parent ).
        DATA(ls_result) = failures( ).
        DATA(ls_finding) = only_finding( is_result = ls_result iv_code = zif_ca_ops_job_types=>gc_code-child_failed ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-reference exp = gc-root msg = 'The topmost ancestor' ).
        DATA(ls_child) = mo_dao->ms_saved-jobs[ jobname = gc-child ].
        cl_abap_unit_assert=>assert_equals( act = ls_child-depth exp = 2 msg = 'Two levels below the root' ).
        cl_abap_unit_assert=>assert_equals( act = ls_child-root_status exp = zif_ca_ops_job_types=>gc_status-running
                                            msg = 'Root still active' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a finished job of a watched program with error lines is JOB_LOG_ERROR; without error lines nothing
  METHOD finished_with_log_errors.
    TRY.
        INSERT job( iv_name = gc-other iv_status = zif_ca_ops_job_types=>gc_status-finished ) INTO TABLE mo_dao->mt_finished.
        INSERT job( iv_name = gc-parent iv_status = zif_ca_ops_job_types=>gc_status-finished ) INTO TABLE mo_dao->mt_finished.
        INSERT VALUE #( jobname = gc-other jobcount = gc-count
                        line    = VALUE #( msgid = 'ZT' msgno = '001' msgtype = 'E' text = 'Interval 3 failed' ) )
          INTO TABLE mo_log->mt_logs.
        INSERT VALUE #( jobname = gc-parent jobcount = gc-count
                        line    = VALUE #( msgid = 'ZT' msgno = '002' msgtype = 'S' text = 'Job finished' ) )
          INTO TABLE mo_log->mt_logs.
        DATA(ls_result) = failures( ).
        DATA(ls_finding) = only_finding( is_result = ls_result iv_code = zif_ca_ops_job_types=>gc_code-log_error ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-object_key exp = |{ gc-other }/{ gc-count }|
                                            msg = 'The job with an error line' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'The clean job raises nothing' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->ms_saved-lines ) exp = 1 msg = 'The error line is kept' ).
        cl_abap_unit_assert=>assert_equals( act = mo_log->mv_reads exp = 2 msg = 'Each log read once' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: over the log budget a finished job is not evaluated and the watermark stays before it
  METHOD log_budget_holds_mark.
    TRY.
        mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-max_log_reads iv_value = '1' ).
        INSERT job( iv_name = gc-other iv_status = zif_ca_ops_job_types=>gc_status-finished iv_end = '091000' )
          INTO TABLE mo_dao->mt_finished.
        INSERT job( iv_name = gc-parent iv_status = zif_ca_ops_job_types=>gc_status-finished iv_end = '092000' )
          INTO TABLE mo_dao->mt_finished.
        DATA(ls_result) = failures( ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_saved_watermark-point-time exp = '092000'
                                            msg = 'The next run starts at the job not evaluated' ).
        only_finding( is_result = ls_result iv_code = zif_ca_ops_job_types=>gc_code-read_capped ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-item_count exp = 1 msg = 'One job evaluated' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a job of the overlap already kept as a failure is not reported again
  METHOD overlap_not_reported.
    TRY.
        INSERT job( gc-other ) INTO TABLE mo_dao->mt_aborted.
        INSERT VALUE #( jobname = gc-other jobcount = gc-count ) INTO TABLE mo_dao->mt_reported.
        DATA(ls_result) = failures( ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'Reported once only' ).
        cl_abap_unit_assert=>assert_initial( act = mo_dao->ms_saved-jobs msg = 'Nothing kept again' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an excluded name is dropped; a pattern that does not compile is a configuration finding
  METHOD excluded_and_invalid.
    TRY.
        mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-exclude iv_value = 'ZT_OTH.*,ZT_(' ).
        INSERT job( gc-other ) INTO TABLE mo_dao->mt_aborted.
        DATA(ls_result) = failures( ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( ls_result-findings[
                                                     check_code = zif_ca_ops_job_types=>gc_code-aborted ] ) )
                                           msg = 'Excluded job not reported' ).
        only_finding( is_result = ls_result iv_code = zif_ca_ops_job_types=>gc_code-config ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a job another monitor reports is information only (no exception, no second alert), evidence kept
  METHOD claimed_is_information.
    TRY.
        DATA(lo_claim) = NEW ltd_claim( ).
        lo_claim->mv_jobname = gc-other.
        zcl_ca_ops_injector=>inject_plugin( iv_class_name = CONV #( gc-claim ) io_instance = lo_claim ).
        mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-claims iv_value = gc-claim ).
        INSERT job( gc-other ) INTO TABLE mo_dao->mt_aborted.
        DATA(ls_finding) = only_finding( is_result = failures( ) iv_code = zif_ca_ops_job_types=>gc_code-aborted ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-severity exp = zif_ca_ops_types=>gc_severity-info
                                            msg = 'Information only' ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-action exp = zif_ca_ops_types=>gc_action-notify
                                            msg = 'No owned exception' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_saved-jobs[ 1 ]-claimed_by exp = 'ZT_CYCLE/010'
                                            msg = 'Who reports it' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: test mode reports but writes no evidence and no watermark
  METHOD test_mode_saves_nothing.
    TRY.
        mv_test_mode = abap_true.
        INSERT job( gc-other ) INTO TABLE mo_dao->mt_aborted.
        DATA(ls_result) = failures( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'Still reported' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_saves exp = 0 msg = 'Nothing saved' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: first run = now minus the look-back; then the watermark minus the overlap; never after now
  METHOD window_lookback_overlap.
    DATA(ls_now) = VALUE zif_ca_ops_job_types=>ty_point( date = gc-today time = '000500' ).
    DATA(ls_first) = zcl_ca_ops_job_monitor=>window( is_watermark = VALUE #( ) is_now = ls_now
                                                     iv_lookback_min = 60 iv_overlap_min = 10 ).
    cl_abap_unit_assert=>assert_equals( act = ls_first-from
                                        exp = VALUE zif_ca_ops_job_types=>ty_point( date = '20261110' time = '230500' )
                                        msg = 'Look-back across midnight' ).
    cl_abap_unit_assert=>assert_true( act = ls_first-first msg = 'First run' ).
    DATA(ls_next) = zcl_ca_ops_job_monitor=>window(
                      is_watermark = VALUE #( point = VALUE #( date = gc-today time = '000000' ) )
                      is_now = ls_now iv_lookback_min = 60 iv_overlap_min = 10 ).
    cl_abap_unit_assert=>assert_equals( act = ls_next-from
                                        exp = VALUE zif_ca_ops_job_types=>ty_point( date = '20261110' time = '235000' )
                                        msg = 'Watermark minus the overlap' ).
    cl_abap_unit_assert=>assert_equals( act = ls_next-to exp = ls_now msg = 'Up to now' ).
    DATA(ls_future) = zcl_ca_ops_job_monitor=>window(
                        is_watermark = VALUE #( point = VALUE #( date = '20261112' time = '000000' ) )
                        is_now = ls_now iv_lookback_min = 60 iv_overlap_min = 10 ).
    cl_abap_unit_assert=>assert_equals( act = ls_future-from exp = ls_now msg = 'A watermark after now never skips' ).
  ENDMETHOD.


  " Rule: a read that reaches its cap is reported and the watermark moves back to its last row
  METHOD capped_read_moves_mark.
    TRY.
        mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-max_jobs iv_value = '1' ).
        INSERT job( iv_name = gc-other iv_end = '091500' ) INTO TABLE mo_dao->mt_aborted.
        INSERT job( iv_name = gc-child iv_end = '091600' ) INTO TABLE mo_dao->mt_aborted.
        DATA(ls_result) = failures( ).
        only_finding( is_result = ls_result iv_code = zif_ca_ops_job_types=>gc_code-read_capped ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->ms_saved_watermark-point-time exp = '091500'
                                            msg = 'Continues at the last row read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a resolver that raises is a plug-in finding; the failure is still reported (without parent)
  METHOD failing_resolver.
    TRY.
        mo_resolver->mv_fail = abap_true.
        INSERT job( gc-child ) INTO TABLE mo_dao->mt_aborted.
        DATA(ls_result) = failures( ).
        only_finding( is_result = ls_result iv_code = zif_ca_ops_job_types=>gc_code-plugin_failed ).
        only_finding( is_result = ls_result iv_code = zif_ca_ops_job_types=>gc_code-aborted ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the company code of the enricher's object and the scheduler job of the root reach finding and evidence
  METHOD company_code_and_sched.
    TRY.
        DATA(lo_enricher) = NEW ltd_enricher( ).
        lo_enricher->mv_bukrs = gc-bukrs.
        zcl_ca_ops_injector=>inject_plugin( iv_class_name = CONV #( gc-enricher ) io_instance = lo_enricher ).
        mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-enrichers iv_value = gc-enricher ).
        INSERT VALUE #( sched_folder = 'ZT_FOLDER' sched_job = 'ZT_CTRL_JOB' sap_pattern = 'ZT_OTH.*'
                        criticality = 'H' ) INTO TABLE mo_dao->mt_sched.
        INSERT job( gc-other ) INTO TABLE mo_dao->mt_aborted.
        DATA(ls_finding) = only_finding( is_result = failures( ) iv_code = zif_ca_ops_job_types=>gc_code-aborted ).
        cl_abap_unit_assert=>assert_equals( act = ls_finding-company_code exp = gc-bukrs msg = 'Company code of the object' ).
        DATA(ls_row) = mo_dao->ms_saved-jobs[ 1 ].
        cl_abap_unit_assert=>assert_equals( act = ls_row-sched_job exp = 'ZT_CTRL_JOB' msg = 'Scheduler job of the root' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-bukrs exp = gc-bukrs msg = 'Company code kept' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->ms_saved-objects ) exp = 1 msg = 'Business object kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: active beyond the limit = JOB_LONG_RUNNING, waiting beyond the limit = JOB_NOT_STARTED; complete
  METHOD long_running_not_started.
    TRY.
        INSERT job( iv_name = gc-root iv_status = zif_ca_ops_job_types=>gc_status-running ) INTO TABLE mo_dao->mt_active.
        DATA(ls_waiting) = job( iv_name = gc-other iv_status = zif_ca_ops_job_types=>gc_status-released ).
        ls_waiting-sdlstrtdt = gc-today.
        ls_waiting-sdlstrttm = '080000'.
        INSERT ls_waiting INTO TABLE mo_dao->mt_waiting.
        DATA(ls_result) = states( ).
        cl_abap_unit_assert=>assert_equals(
          act = only_finding( is_result = ls_result iv_code = zif_ca_ops_job_types=>gc_code-long_running )-severity
          exp = zif_ca_ops_types=>gc_severity-warning msg = 'Long-running is a warning' ).
        only_finding( is_result = ls_result iv_code = zif_ca_ops_job_types=>gc_code-not_started ).
        cl_abap_unit_assert=>assert_false( act = ls_result-partial msg = 'A complete snapshot resolves what ended' ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_dao->ms_saved-jobs ) exp = 2 msg = 'Both kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
