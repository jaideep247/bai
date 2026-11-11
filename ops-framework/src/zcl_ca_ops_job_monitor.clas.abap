*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_monitor.clas.abap
*& Purpose:
*& Engine of the SAP job monitor (docs/JOB_MONITORING.md), run by the two
*& registered checks ZCL_CA_OPS_CHK_JOB_FAIL (FAILURES, incremental) and
*& ZCL_CA_OPS_CHK_JOB_STATE (STATES, snapshot). FAILURES reads every job
*& of the client that was cancelled, or that finished with error lines in
*& its job log (watched programs), after the watermark minus the overlap
*& (first run: the look-back), capped per run; drops excluded names and
*& jobs already reported; links parents and children through the ordered
*& resolvers (recursive to JOB_MAX_DEPTH); classifies each failure -
*& JOB_CHILD_FAILED when its root did not abort (what the scheduler sees
*& is fine), else JOB_ABORTED / JOB_LOG_ERROR; a job another monitor
*& claims is information only; keeps the evidence chain (job, steps, job
*& log errors, application logs, ancestors and children, scheduler job,
*& business objects of the enrichers) and the new watermark. STATES reports
*& long-running jobs and released jobs that did not start. Read only
*& towards SAP; the evidence is written without commit in the runner's
*& LUW and never in test mode.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - SAP job monitor engine</p>
"! FAILURES is incremental: a run sees only the jobs of its window, so its result is always partial
"! (an exception is resolved by its owner, never because a later window does not show the job again).
"! STATES is a snapshot of the active and waiting jobs: complete unless a read was capped.
CLASS zcl_ca_ops_job_monitor DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! @parameter io_dao | Data access (default ZCL_CA_OPS_JOB_DAO; a double in tests)
    "! @parameter io_log | Job log reader (default ZCL_CA_OPS_JOB_LOG over BP_JOBLOG_READ; a double in tests)
    METHODS constructor
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_job_dao OPTIONAL
        io_log TYPE REF TO zif_ca_ops_job_log OPTIONAL.

    "! Cancelled jobs, failed children, job log errors of the window after the watermark
    METHODS failures
      IMPORTING
        is_check         TYPE zif_ca_ops_chk_types=>ty_check
        is_context       TYPE zif_ca_ops_chk_types=>ty_context
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.

    "! Long-running jobs and released jobs not started
    METHODS states
      IMPORTING
        is_check         TYPE zif_ca_ops_chk_types=>ty_check
        is_context       TYPE zif_ca_ops_chk_types=>ty_context
      RETURNING
        VALUE(rs_result) TYPE zif_ca_ops_chk_types=>ty_result
      RAISING
        zcx_ca_ops_error.

    "! The read window: from the watermark minus the overlap (first run: now minus the look-back) to now
    CLASS-METHODS window
      IMPORTING
        is_watermark     TYPE zif_ca_ops_job_types=>ty_watermark
        is_now           TYPE zif_ca_ops_job_types=>ty_point
        iv_lookback_min  TYPE i
        iv_overlap_min   TYPE i
      RETURNING
        VALUE(rs_window) TYPE zif_ca_ops_job_types=>ty_window.

    "! Object key of a job's finding: job name / job count
    CLASS-METHODS object_key
      IMPORTING
        iv_jobname    TYPE btcjob
        iv_jobcount   TYPE btcjobcnt
      RETURNING
        VALUE(rv_key) TYPE zif_ca_ops_types=>ty_object_key.

  PRIVATE SECTION.
    TYPES tt_job_hash TYPE HASHED TABLE OF zif_ca_ops_job_types=>ty_job WITH UNIQUE KEY jobname jobcount.
    TYPES tt_link_hash TYPE HASHED TABLE OF zif_ca_ops_job_types=>ty_link WITH UNIQUE KEY child_name child_count.
    TYPES tt_claim_hash TYPE HASHED TABLE OF zif_ca_ops_job_types=>ty_claim WITH UNIQUE KEY jobname jobcount.
    TYPES tt_step_sorted TYPE SORTED TABLE OF zif_ca_ops_job_types=>ty_step
                         WITH NON-UNIQUE KEY jobname jobcount stepcount.
    TYPES:
      BEGIN OF ty_root,
        root  TYPE zif_ca_ops_job_types=>ty_job_key,
        depth TYPE i,
      END OF ty_root.
    TYPES:
      BEGIN OF ty_failure,
        job        TYPE zif_ca_ops_job_types=>ty_job,
        log_errors TYPE i,
      END OF ty_failure.
    TYPES tt_failure TYPE STANDARD TABLE OF ty_failure WITH EMPTY KEY.
    TYPES tt_object TYPE STANDARD TABLE OF REF TO object WITH EMPTY KEY.

    DATA mo_dao TYPE REF TO zif_ca_ops_job_dao.
    DATA mo_reader TYPE REF TO zif_ca_ops_job_log.
    DATA mo_cache TYPE REF TO zcl_ca_ops_job_log_cache.
    DATA ms_config TYPE zif_ca_ops_job_types=>ty_config.
    DATA ms_context TYPE zif_ca_ops_chk_types=>ty_context.
    DATA ms_now TYPE zif_ca_ops_job_types=>ty_point.
    "! Findings of the monitor itself (configuration, plug-ins, caps) of the current run
    DATA mt_own TYPE zif_ca_ops_types=>tt_finding.
    "! Every TBTCO row known in the run (failed jobs, ancestors, context children)
    DATA mt_jobs TYPE tt_job_hash.
    "! Parent of a job (first resolver that linked it)
    DATA mt_parent TYPE tt_link_hash.
    "! Parent of a context child (children of a failing job's parent)
    DATA mt_child_link TYPE tt_link_hash.
    DATA mt_claims TYPE tt_claim_hash.
    DATA mt_steps TYPE tt_step_sorted.
    DATA mt_sched TYPE zif_ca_ops_job_types=>tt_sched.
    DATA ms_evidence TYPE zif_ca_ops_job_types=>ty_evidence_set.
    "! Resolvers of the run (JOB_RESOLVERS, created once)
    DATA mt_resolvers TYPE tt_object.

    "! Parameters of the run, caps cut to the ceilings; an unusable pattern is a finding and dropped
    METHODS read_config.

    METHODS int_param
      IMPORTING
        iv_name         TYPE zif_ca_ops_types=>ty_param_name
        iv_default      TYPE i
        iv_ceiling      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

    METHODS list_param
      IMPORTING
        iv_name          TYPE zif_ca_ops_types=>ty_param_name
        iv_default       TYPE string OPTIONAL
      RETURNING
        VALUE(rt_values) TYPE string_table.

    CLASS-METHODS to_range
      IMPORTING
        it_values       TYPE string_table
      RETURNING
        VALUE(rt_range) TYPE zif_ca_ops_types=>tt_param_range.

    "! Start of a run: settings, clock, caches, the job log reader with its budget
    METHODS begin
      IMPORTING
        is_context TYPE zif_ca_ops_chk_types=>ty_context.

    "! Drop the jobs whose name matches JOB_EXCLUDE_PCRE
    METHODS drop_excluded
      CHANGING
        ct_jobs TYPE zif_ca_ops_job_types=>tt_job.

    "! Drop the jobs already reported as a failure (the overlap of the window)
    METHODS drop_reported
      CHANGING
        ct_jobs TYPE zif_ca_ops_job_types=>tt_job.

    "! A read reached its cap: finding, and the next watermark is not after the last row read
    METHODS capped
      IMPORTING
        it_jobs  TYPE zif_ca_ops_job_types=>tt_job
        iv_kind  TYPE zif_ca_ops_types=>ty_check_code
      CHANGING
        cs_next  TYPE zif_ca_ops_job_types=>ty_point.

    "! Finished jobs of watched programs whose log holds error lines (log budget; the rest waits)
    METHODS finished_failures
      IMPORTING
        it_finished         TYPE zif_ca_ops_job_types=>tt_job
      CHANGING
        cs_next             TYPE zif_ca_ops_job_types=>ty_point
        ct_failed           TYPE tt_failure
      RETURNING
        VALUE(rv_evaluated) TYPE i.

    "! Error lines of a job log (types of JOB_LOG_ERROR_TYPES)
    METHODS error_lines
      IMPORTING
        is_job          TYPE zif_ca_ops_job_types=>ty_job
      RETURNING
        VALUE(rt_lines) TYPE zif_ca_ops_job_types=>tt_log_line.

    "! Parents up to JOB_MAX_DEPTH through the resolvers in order; the first link of a job wins
    METHODS link_parents
      IMPORTING
        it_failed TYPE tt_failure.

    "! Children of the failing jobs' parents through the resolvers (context, JOB_MAX_CHILDREN each)
    METHODS link_children
      IMPORTING
        it_failed TYPE tt_failure.

    "! Plug-ins of a parameter (resolvers, enrichers, claims); a class that cannot be created is a finding
    METHODS plugins
      IMPORTING
        it_classes        TYPE string_table
        iv_interface      TYPE zif_ca_ops_types=>ty_class_name
      RETURNING
        VALUE(rt_objects) TYPE tt_object.

    METHODS plugin_failed
      IMPORTING
        iv_plugin TYPE clike
        ix_error  TYPE REF TO cx_root.

    "! Read the TBTCO rows of keys not known yet
    METHODS learn
      IMPORTING
        it_keys        TYPE zif_ca_ops_job_types=>tt_job_key
      RETURNING
        VALUE(rt_jobs) TYPE zif_ca_ops_job_types=>tt_job.

    "! Root (topmost ancestor) and depth of a job
    METHODS root_of
      IMPORTING
        is_job         TYPE zif_ca_ops_job_types=>ty_job
      RETURNING
        VALUE(rs_root) TYPE ty_root.

    METHODS claims
      IMPORTING
        it_jobs TYPE zif_ca_ops_job_types=>tt_job.

    "! scheduler job of a SAP job name (first active row in sequence whose pattern matches)
    METHODS scheduler_of
      IMPORTING
        iv_jobname    TYPE btcjob
      RETURNING
        VALUE(rs_sched) TYPE zif_ca_ops_job_types=>ty_sched.

    METHODS load_scheduler.

    "! Steps of the jobs of the run (one read)
    METHODS load_steps
      IMPORTING
        it_keys TYPE zif_ca_ops_job_types=>tt_job_key.

    "! Error lines of the failed jobs, application logs, business objects
    METHODS collect_evidence
      IMPORTING
        it_failed TYPE tt_failure.

    METHODS keep_lines
      IMPORTING
        it_failed TYPE tt_failure.

    METHODS keep_applogs
      IMPORTING
        it_failed TYPE tt_failure.

    METHODS enrich.

    "! Finding and evidence row of one failed job
    METHODS failure_finding
      IMPORTING
        is_failure        TYPE ty_failure
        iv_failed_in_run  TYPE i
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! Finding and evidence row of a long-running or waiting job
    METHODS state_finding
      IMPORTING
        is_job            TYPE zif_ca_ops_job_types=>ty_job
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! Labelled lines of a finding: parent, root, scheduler job, first step, application logs, objects
    METHODS context_lines
      IMPORTING
        is_job         TYPE zif_ca_ops_job_types=>ty_job
        is_root        TYPE ty_root
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Evidence row of a job (role, code, links, scheduler job, company code)
    METHODS evidence_row
      IMPORTING
        is_job        TYPE zif_ca_ops_job_types=>ty_job
        iv_role       TYPE zif_ca_ops_job_types=>ty_role
        is_finding    TYPE zif_ca_ops_types=>ty_finding OPTIONAL
      RETURNING
        VALUE(rs_row) TYPE zif_ca_ops_job_types=>ty_evidence.

    "! Context rows (ancestors, children) not already kept as a failure
    METHODS context_rows
      IMPORTING
        it_failed TYPE tt_failure.

    "! Company code of a job from its business objects (exactly one distinct, else blank)
    METHODS bukrs_of
      IMPORTING
        is_job          TYPE zif_ca_ops_job_types=>ty_job
      RETURNING
        VALUE(rv_bukrs) TYPE bukrs.

    "! Write evidence and watermark (never in test mode)
    METHODS save
      IMPORTING
        is_check     TYPE zif_ca_ops_chk_types=>ty_check
        is_watermark TYPE zif_ca_ops_job_types=>ty_point OPTIONAL
      RAISING
        zcx_ca_ops_error.

    METHODS own_finding
      IMPORTING
        iv_code   TYPE zif_ca_ops_types=>ty_check_code
        iv_key    TYPE clike
        iv_text   TYPE string
        iv_action TYPE zif_ca_ops_types=>ty_action DEFAULT zif_ca_ops_types=>gc_action-exception.

    CLASS-METHODS keys
      IMPORTING
        it_jobs        TYPE zif_ca_ops_job_types=>tt_job
      RETURNING
        VALUE(rt_keys) TYPE zif_ca_ops_job_types=>tt_job_key.

ENDCLASS.



CLASS zcl_ca_ops_job_monitor IMPLEMENTATION.

  METHOD constructor.
    mo_dao = COND #( WHEN io_dao IS BOUND THEN io_dao ELSE NEW zcl_ca_ops_job_dao( ) ).
    mo_reader = COND #( WHEN io_log IS BOUND THEN io_log ELSE NEW zcl_ca_ops_job_log( ) ).
  ENDMETHOD.


  METHOD window.
    rs_window-to = is_now.
    IF is_watermark-point-date IS INITIAL.
      rs_window-first = abap_true.
      rs_window-from  = zcl_ca_ops_job_time=>add_minutes( is_point = is_now iv_minutes = 0 - iv_lookback_min ).
      RETURN.
    ENDIF.
    rs_window-from = zcl_ca_ops_job_time=>add_minutes( is_point = is_watermark-point iv_minutes = 0 - iv_overlap_min ).
    " a watermark after now (clock moved back) never skips jobs: read up to now from the earlier point
    rs_window-from = zcl_ca_ops_job_time=>earlier( is_first = rs_window-from is_second = is_now ).
  ENDMETHOD.


  METHOD object_key.
    rv_key = |{ iv_jobname }{ zif_ca_ops_job_types=>gc_key_separator }{ iv_jobcount }|.
  ENDMETHOD.


  METHOD failures.
    DATA lt_failed TYPE tt_failure.

    begin( is_context ).
    DATA(ls_watermark) = mo_dao->watermark( iv_area     = is_check-area
                                            iv_check_id = is_check-check_id ).
    DATA(ls_window) = window( is_watermark    = ls_watermark
                              is_now          = ms_now
                              iv_lookback_min = ms_config-lookback_min
                              iv_overlap_min  = ms_config-overlap_min ).
    DATA(ls_next) = ls_window-to.

    DATA(lt_aborted) = mo_dao->aborted_jobs( is_window = ls_window
                                             iv_max    = ms_config-max_jobs ).
    capped( EXPORTING it_jobs = lt_aborted
                      iv_kind = zif_ca_ops_job_types=>gc_code-aborted
            CHANGING  cs_next = ls_next ).
    DATA(lt_finished) = mo_dao->finished_jobs( is_window   = ls_window
                                               it_programs = ms_config-log_programs
                                               iv_max      = ms_config-max_jobs ).
    capped( EXPORTING it_jobs = lt_finished
                      iv_kind = zif_ca_ops_job_types=>gc_code-log_error
            CHANGING  cs_next = ls_next ).
    drop_excluded( CHANGING ct_jobs = lt_aborted ).
    drop_excluded( CHANGING ct_jobs = lt_finished ).
    drop_reported( CHANGING ct_jobs = lt_aborted ).
    drop_reported( CHANGING ct_jobs = lt_finished ).

    DATA(lv_evaluated) = finished_failures( EXPORTING it_finished = lt_finished
                                            CHANGING  cs_next     = ls_next
                                                      ct_failed   = lt_failed ).
    LOOP AT lt_aborted ASSIGNING FIELD-SYMBOL(<ls_aborted>).
      INSERT VALUE #( job = <ls_aborted> ) INTO TABLE lt_failed.
    ENDLOOP.
    LOOP AT lt_failed ASSIGNING FIELD-SYMBOL(<ls_failed>).
      INSERT <ls_failed>-job INTO TABLE mt_jobs.
    ENDLOOP.

    IF lt_failed IS NOT INITIAL.
      link_parents( lt_failed ).
      link_children( lt_failed ).
      claims( VALUE #( FOR <ls_f> IN lt_failed ( <ls_f>-job ) ) ).
      load_scheduler( ).
      load_steps( keys( VALUE #( FOR <ls_k> IN mt_jobs ( <ls_k> ) ) ) ).
      collect_evidence( lt_failed ).
      LOOP AT lt_failed ASSIGNING <ls_failed>.
        INSERT failure_finding( is_failure       = <ls_failed>
                                iv_failed_in_run = lines( lt_failed ) ) INTO TABLE rs_result-findings.
      ENDLOOP.
      context_rows( lt_failed ).
    ENDIF.

    save( is_check     = is_check
          is_watermark = ls_next ).
    INSERT LINES OF mt_own INTO TABLE rs_result-findings.
    rs_result-item_count = lines( lt_aborted ) + lv_evaluated.
    " incremental: a later window never re-reads a job, so nothing may be auto-resolved
    rs_result-partial = abap_true.
  ENDMETHOD.


  METHOD states.
    begin( is_context ).
    " a snapshot has no watermark: the point of a capped read is only reported
    DATA(ls_ignored) = ms_now.
    DATA(lt_active) = mo_dao->active_jobs(
                        is_started_before = zcl_ca_ops_job_time=>add_minutes( is_point   = ms_now
                                                                                iv_minutes = 0 - ms_config-long_running_min )
                        iv_max            = ms_config-max_jobs ).
    capped( EXPORTING it_jobs = lt_active
                      iv_kind = zif_ca_ops_job_types=>gc_code-long_running
            CHANGING  cs_next = ls_ignored ).
    DATA(lt_waiting) = mo_dao->waiting_jobs(
                         it_statuses       = ms_config-waiting_statuses
                         is_planned_before = zcl_ca_ops_job_time=>add_minutes( is_point   = ms_now
                                                                                 iv_minutes = 0 - ms_config-not_started_min )
                         iv_max            = ms_config-max_jobs ).
    capped( EXPORTING it_jobs = lt_waiting
                      iv_kind = zif_ca_ops_job_types=>gc_code-not_started
            CHANGING  cs_next = ls_ignored ).
    rs_result-partial = xsdbool( lines( lt_active ) >= ms_config-max_jobs OR lines( lt_waiting ) >= ms_config-max_jobs ).
    drop_excluded( CHANGING ct_jobs = lt_active ).
    drop_excluded( CHANGING ct_jobs = lt_waiting ).

    DATA(lt_all) = lt_active.
    INSERT LINES OF lt_waiting INTO TABLE lt_all.
    LOOP AT lt_all ASSIGNING FIELD-SYMBOL(<ls_job>).
      INSERT <ls_job> INTO TABLE mt_jobs.
    ENDLOOP.
    IF lt_all IS NOT INITIAL.
      claims( lt_all ).
      load_scheduler( ).
      load_steps( keys( lt_all ) ).
      LOOP AT lt_active ASSIGNING <ls_job>.
        INSERT state_finding( is_job  = <ls_job>
                              iv_code = zif_ca_ops_job_types=>gc_code-long_running ) INTO TABLE rs_result-findings.
      ENDLOOP.
      LOOP AT lt_waiting ASSIGNING <ls_job>.
        INSERT state_finding( is_job  = <ls_job>
                              iv_code = zif_ca_ops_job_types=>gc_code-not_started ) INTO TABLE rs_result-findings.
      ENDLOOP.
    ENDIF.
    save( is_check ).
    INSERT LINES OF mt_own INTO TABLE rs_result-findings.
    rs_result-item_count = lines( lt_all ).
    IF mt_own IS NOT INITIAL.
      rs_result-partial = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD begin.
    CLEAR: mt_own, mt_jobs, mt_parent, mt_child_link, mt_claims, mt_steps, mt_sched, ms_evidence.
    ms_context = is_context.
    ms_now = zcl_ca_ops_job_time=>now( ).
    read_config( ).
    mo_cache = NEW zcl_ca_ops_job_log_cache( io_reader = mo_reader
                                             iv_budget = ms_config-max_log_reads ).
  ENDMETHOD.


  METHOD read_config.
    CLEAR ms_config.
    ms_config-lookback_min     = int_param( iv_name    = zif_ca_ops_job_types=>gc_param-lookback_min
                                            iv_default = zif_ca_ops_job_types=>gc_param_default-lookback_min
                                            iv_ceiling = zif_ca_ops_job_types=>gc_ceiling-jobs ).
    ms_config-overlap_min      = int_param( iv_name    = zif_ca_ops_job_types=>gc_param-overlap_min
                                            iv_default = zif_ca_ops_job_types=>gc_param_default-overlap_min
                                            iv_ceiling = zif_ca_ops_job_types=>gc_ceiling-jobs ).
    ms_config-max_jobs         = int_param( iv_name    = zif_ca_ops_job_types=>gc_param-max_jobs
                                            iv_default = zif_ca_ops_job_types=>gc_param_default-max_jobs
                                            iv_ceiling = zif_ca_ops_job_types=>gc_ceiling-jobs ).
    ms_config-max_log_reads    = int_param( iv_name    = zif_ca_ops_job_types=>gc_param-max_log_reads
                                            iv_default = zif_ca_ops_job_types=>gc_param_default-max_log_reads
                                            iv_ceiling = zif_ca_ops_job_types=>gc_ceiling-log_reads ).
    ms_config-max_messages     = int_param( iv_name    = zif_ca_ops_job_types=>gc_param-max_messages
                                            iv_default = zif_ca_ops_job_types=>gc_param_default-max_messages
                                            iv_ceiling = zif_ca_ops_job_types=>gc_ceiling-messages ).
    ms_config-max_depth        = int_param( iv_name    = zif_ca_ops_job_types=>gc_param-max_depth
                                            iv_default = zif_ca_ops_job_types=>gc_param_default-max_depth
                                            iv_ceiling = zif_ca_ops_job_types=>gc_ceiling-depth ).
    ms_config-max_children     = int_param( iv_name    = zif_ca_ops_job_types=>gc_param-max_children
                                            iv_default = zif_ca_ops_job_types=>gc_param_default-max_children
                                            iv_ceiling = zif_ca_ops_job_types=>gc_ceiling-children ).
    ms_config-max_applogs      = int_param( iv_name    = zif_ca_ops_job_types=>gc_param-max_applogs
                                            iv_default = zif_ca_ops_job_types=>gc_param_default-max_applogs
                                            iv_ceiling = zif_ca_ops_job_types=>gc_ceiling-applogs ).
    ms_config-long_running_min = int_param( iv_name    = zif_ca_ops_job_types=>gc_param-long_running_min
                                            iv_default = zif_ca_ops_job_types=>gc_param_default-long_running_min
                                            iv_ceiling = zif_ca_ops_job_types=>gc_ceiling-jobs ).
    ms_config-not_started_min  = int_param( iv_name    = zif_ca_ops_job_types=>gc_param-not_started_min
                                            iv_default = zif_ca_ops_job_types=>gc_param_default-not_started_min
                                            iv_ceiling = zif_ca_ops_job_types=>gc_ceiling-jobs ).
    ms_config-log_programs     = to_range( list_param( zif_ca_ops_job_types=>gc_param-log_programs ) ).
    ms_config-parent_programs  = to_range( list_param( zif_ca_ops_job_types=>gc_param-parent_programs ) ).
    ms_config-log_error_types  = to_range( list_param( iv_name    = zif_ca_ops_job_types=>gc_param-log_error_types
                                                       iv_default = zif_ca_ops_job_types=>gc_param_default-log_error_types ) ).
    ms_config-waiting_statuses = to_range( list_param(
                                   iv_name    = zif_ca_ops_job_types=>gc_param-waiting_statuses
                                   iv_default = zif_ca_ops_job_types=>gc_param_default-waiting_statuses ) ).
    ms_config-resolvers        = list_param( iv_name    = zif_ca_ops_job_types=>gc_param-resolvers
                                             iv_default = zif_ca_ops_job_types=>gc_param_default-resolvers ).
    ms_config-enrichers        = list_param( zif_ca_ops_job_types=>gc_param-enrichers ).
    ms_config-claims           = list_param( zif_ca_ops_job_types=>gc_param-claims ).
    " a pattern that does not compile is reported and left out - never "no exclusion" in silence
    LOOP AT zcl_ca_ops_util=>split_list( zcl_ca_ops_factory=>get_params( )->get_param(
                                           iv_name = zif_ca_ops_job_types=>gc_param-exclude
                                           iv_area = zif_ca_ops_types=>gc_param_area ) ) ASSIGNING FIELD-SYMBOL(<lv_pattern>).
      IF zcl_ca_ops_util=>pcre_valid( <lv_pattern> ) = abap_true.
        INSERT <lv_pattern> INTO TABLE ms_config-exclude.
      ELSE.
        own_finding( iv_code = zif_ca_ops_job_types=>gc_code-config
                     iv_key  = zif_ca_ops_job_types=>gc_param-exclude
                     iv_text = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-config
                                                      iv_v1    = zif_ca_ops_job_types=>gc_param-exclude
                                                      iv_v2    = <lv_pattern> ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD int_param.
    rv_value = zcl_ca_ops_util=>param_int( io_params  = zcl_ca_ops_factory=>get_params( )
                                           iv_name    = iv_name
                                           iv_default = iv_default
                                           iv_area    = zif_ca_ops_types=>gc_param_area ).
    IF rv_value < 0.
      rv_value = iv_default.
    ENDIF.
    IF rv_value > iv_ceiling.
      rv_value = iv_ceiling.
    ENDIF.
  ENDMETHOD.


  METHOD list_param.
    LOOP AT zcl_ca_ops_util=>split_list( zcl_ca_ops_factory=>get_params( )->get_param(
                                           iv_name    = iv_name
                                           iv_default = iv_default
                                           iv_area    = zif_ca_ops_types=>gc_param_area ) ) ASSIGNING FIELD-SYMBOL(<lv_value>).
      INSERT to_upper( <lv_value> ) INTO TABLE rt_values.
    ENDLOOP.
  ENDMETHOD.


  METHOD to_range.
    LOOP AT it_values ASSIGNING FIELD-SYMBOL(<lv_value>).
      INSERT VALUE #( sign   = zif_ca_ops_types=>gc_range-sign_include
                      option = zif_ca_ops_types=>gc_range-option_equal
                      low    = <lv_value> ) INTO TABLE rt_range.
    ENDLOOP.
  ENDMETHOD.


  METHOD drop_excluded.
    IF ms_config-exclude IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT ct_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      IF zcl_ca_ops_util=>pcre_match_any( iv_value = <ls_job>-jobname it_patterns = ms_config-exclude ) = abap_true.
        DELETE ct_jobs.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD drop_reported.
    IF ct_jobs IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_reported) = mo_dao->reported( it_keys = keys( ct_jobs ) ).
    LOOP AT ct_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      IF line_exists( lt_reported[ jobname = <ls_job>-jobname jobcount = <ls_job>-jobcount ] ).
        DELETE ct_jobs.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD capped.
    IF it_jobs IS INITIAL OR lines( it_jobs ) < ms_config-max_jobs.
      RETURN.
    ENDIF.
    DATA(ls_last) = it_jobs[ lines( it_jobs ) ].
    cs_next = zcl_ca_ops_job_time=>earlier( is_first  = cs_next
                                            is_second = zcl_ca_ops_job_time=>ended( ls_last ) ).
    own_finding( iv_code   = zif_ca_ops_job_types=>gc_code-read_capped
                 iv_key    = iv_kind
                 iv_action = zif_ca_ops_types=>gc_action-notify
                 iv_text   = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-read_capped
                                                    iv_v1    = iv_kind
                                                    iv_v2    = lines( it_jobs )
                                                    iv_v3    = ms_config-max_jobs
                                                    iv_v4    = |{ cs_next-date DATE = ISO } { cs_next-time TIME = ISO }| ) ).
  ENDMETHOD.


  METHOD finished_failures.
    LOOP AT it_finished ASSIGNING FIELD-SYMBOL(<ls_job>).
      IF mo_cache->can_read( iv_jobname = <ls_job>-jobname iv_jobcount = <ls_job>-jobcount ) = abap_false.
        " budget used up: this job and the later ones are evaluated by the next run
        cs_next = zcl_ca_ops_job_time=>earlier( is_first  = cs_next
                                                is_second = zcl_ca_ops_job_time=>ended( <ls_job> ) ).
        own_finding( iv_code   = zif_ca_ops_job_types=>gc_code-read_capped
                     iv_key    = zif_ca_ops_job_types=>gc_param-max_log_reads
                     iv_action = zif_ca_ops_types=>gc_action-notify
                     iv_text   = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-read_capped
                                                        iv_v1    = zif_ca_ops_job_types=>gc_param-max_log_reads
                                                        iv_v2    = mo_cache->reads( )
                                                        iv_v3    = ms_config-max_log_reads
                                                        iv_v4    = |{ cs_next-date DATE = ISO } { cs_next-time TIME = ISO }| ) ).
        RETURN.
      ENDIF.
      rv_evaluated += 1.
      DATA(lv_errors) = lines( error_lines( <ls_job> ) ).
      IF lv_errors > 0.
        INSERT VALUE #( job = <ls_job> log_errors = lv_errors ) INTO TABLE ct_failed.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD error_lines.
    IF ms_config-log_error_types IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        DATA(lt_lines) = mo_cache->zif_ca_ops_job_log~read( iv_jobname  = is_job-jobname
                                                            iv_jobcount = is_job-jobcount ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        plugin_failed( iv_plugin = object_key( iv_jobname = is_job-jobname iv_jobcount = is_job-jobcount )
                       ix_error  = lx_error ).
        RETURN.
    ENDTRY.
    LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>) WHERE msgtype IN ms_config-log_error_types.
      INSERT <ls_line> INTO TABLE rt_lines.
    ENDLOOP.
  ENDMETHOD.


  METHOD link_parents.
    DATA lt_level TYPE zif_ca_ops_job_types=>tt_job.
    DATA lt_new TYPE zif_ca_ops_job_types=>tt_job_key.
    DATA lt_links TYPE zif_ca_ops_job_types=>tt_link.

    mt_resolvers = plugins( it_classes   = ms_config-resolvers
                            iv_interface = zif_ca_ops_job_types=>gc_plugin_intf-resolver ).
    lt_level = VALUE #( FOR <ls_f> IN it_failed ( <ls_f>-job ) ).
    DO ms_config-max_depth TIMES.
      DATA(lt_open) = lt_level.
      LOOP AT mt_resolvers INTO DATA(lo_object).
        IF lt_open IS INITIAL.
          EXIT.
        ENDIF.
        TRY.
            lt_links = CAST zif_ca_ops_job_resolver( lo_object )->parents( it_jobs   = lt_open
                                                                         is_config = ms_config
                                                                         io_dao    = mo_dao
                                                                         io_log    = mo_cache ).
          CATCH cx_root INTO DATA(lx_error).
            plugin_failed( iv_plugin = cl_abap_classdescr=>get_class_name( lo_object )
                           ix_error  = lx_error ).
            CONTINUE.
        ENDTRY.
        LOOP AT lt_links ASSIGNING FIELD-SYMBOL(<ls_link>).
          IF ( <ls_link>-parent_name = <ls_link>-child_name AND <ls_link>-parent_count = <ls_link>-child_count )
             OR NOT line_exists( lt_open[ jobname = <ls_link>-child_name jobcount = <ls_link>-child_count ] ).
            CONTINUE.
          ENDIF.
          INSERT <ls_link> INTO TABLE mt_parent.
          IF sy-subrc = 0.
            DELETE lt_open WHERE jobname = <ls_link>-child_name AND jobcount = <ls_link>-child_count.
            INSERT VALUE #( jobname = <ls_link>-parent_name jobcount = <ls_link>-parent_count ) INTO TABLE lt_new.
          ENDIF.
        ENDLOOP.
      ENDLOOP.
      " the next level: parents not known yet (a known job is never followed twice - no cycle)
      lt_level = learn( lt_new ).
      CLEAR lt_new.
      IF lt_level IS INITIAL.
        EXIT.
      ENDIF.
    ENDDO.
  ENDMETHOD.


  METHOD link_children.
    DATA lt_parents TYPE zif_ca_ops_job_types=>tt_job.
    DATA lt_new TYPE zif_ca_ops_job_types=>tt_job_key.
    DATA lt_links TYPE zif_ca_ops_job_types=>tt_link.

    LOOP AT it_failed ASSIGNING FIELD-SYMBOL(<ls_failed>).
      READ TABLE mt_parent ASSIGNING FIELD-SYMBOL(<ls_up>)
           WITH TABLE KEY child_name = <ls_failed>-job-jobname child_count = <ls_failed>-job-jobcount.
      IF sy-subrc = 0.
        READ TABLE mt_jobs ASSIGNING FIELD-SYMBOL(<ls_parent>)
             WITH TABLE KEY jobname = <ls_up>-parent_name jobcount = <ls_up>-parent_count.
        IF sy-subrc = 0 AND NOT line_exists( lt_parents[ jobname = <ls_parent>-jobname jobcount = <ls_parent>-jobcount ] ).
          INSERT <ls_parent> INTO TABLE lt_parents.
        ENDIF.
      ENDIF.
    ENDLOOP.
    IF lt_parents IS INITIAL OR ms_config-max_children = 0.
      RETURN.
    ENDIF.
    LOOP AT mt_resolvers INTO DATA(lo_object).
      TRY.
          lt_links = CAST zif_ca_ops_job_resolver( lo_object )->children( it_jobs   = lt_parents
                                                                        is_config = ms_config
                                                                        io_dao    = mo_dao
                                                                        io_log    = mo_cache ).
        CATCH cx_root INTO DATA(lx_error).
          plugin_failed( iv_plugin = cl_abap_classdescr=>get_class_name( lo_object )
                         ix_error  = lx_error ).
          CONTINUE.
      ENDTRY.
      LOOP AT lt_links ASSIGNING FIELD-SYMBOL(<ls_link>).
        DATA(lv_siblings) = REDUCE i( INIT lv_count = 0
                                      FOR <ls_known> IN mt_child_link
                                      WHERE ( parent_name = <ls_link>-parent_name AND parent_count = <ls_link>-parent_count )
                                      NEXT lv_count = lv_count + 1 ).
        IF lv_siblings >= ms_config-max_children
           OR line_exists( mt_parent[ child_name = <ls_link>-child_name child_count = <ls_link>-child_count ] ).
          CONTINUE.
        ENDIF.
        INSERT <ls_link> INTO TABLE mt_child_link.
        IF sy-subrc = 0.
          INSERT VALUE #( jobname = <ls_link>-child_name jobcount = <ls_link>-child_count ) INTO TABLE lt_new.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    learn( lt_new ).
  ENDMETHOD.


  METHOD plugins.
    LOOP AT it_classes ASSIGNING FIELD-SYMBOL(<lv_class>).
      TRY.
          " the factory checks the interface by RTTI before the class is created
          INSERT zcl_ca_ops_factory=>get_plugin( iv_class_name = CONV #( <lv_class> )
                                                 iv_interface  = iv_interface ) INTO TABLE rt_objects.
        CATCH cx_root INTO DATA(lx_error).
          plugin_failed( iv_plugin = <lv_class>
                         ix_error  = lx_error ).
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD plugin_failed.
    own_finding( iv_code = zif_ca_ops_job_types=>gc_code-plugin_failed
                 iv_key  = iv_plugin
                 iv_text = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-plugin_failed
                                                  iv_v1    = iv_plugin
                                                  iv_tail  = ix_error->get_text( ) ) ).
    ASSIGN mt_own[ lines( mt_own ) ] TO FIELD-SYMBOL(<ls_own>).
    <ls_own>-details     = zcl_ca_ops_util=>exception_trace( ix_error ).
    <ls_own>-error_class = zcl_ca_ops_util=>error_class( ix_error ).
  ENDMETHOD.


  METHOD learn.
    DATA lt_unknown TYPE zif_ca_ops_job_types=>tt_job_key.
    LOOP AT it_keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      IF NOT line_exists( mt_jobs[ jobname = <ls_key>-jobname jobcount = <ls_key>-jobcount ] ).
        INSERT <ls_key> INTO TABLE lt_unknown.
      ENDIF.
    ENDLOOP.
    IF lt_unknown IS INITIAL.
      RETURN.
    ENDIF.
    rt_jobs = mo_dao->jobs( lt_unknown ).
    LOOP AT rt_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      INSERT <ls_job> INTO TABLE mt_jobs.
    ENDLOOP.
  ENDMETHOD.


  METHOD root_of.
    rs_root-root = VALUE #( jobname = is_job-jobname jobcount = is_job-jobcount ).
    DO ms_config-max_depth TIMES.
      READ TABLE mt_parent ASSIGNING FIELD-SYMBOL(<ls_link>)
           WITH TABLE KEY child_name = rs_root-root-jobname child_count = rs_root-root-jobcount.
      IF sy-subrc <> 0 OR NOT line_exists( mt_jobs[ jobname = <ls_link>-parent_name jobcount = <ls_link>-parent_count ] ).
        EXIT.
      ENDIF.
      rs_root-root = VALUE #( jobname = <ls_link>-parent_name jobcount = <ls_link>-parent_count ).
      rs_root-depth += 1.
    ENDDO.
  ENDMETHOD.


  METHOD claims.
    DATA lt_claims TYPE zif_ca_ops_job_types=>tt_claim.
    LOOP AT plugins( it_classes   = ms_config-claims
                     iv_interface = zif_ca_ops_job_types=>gc_plugin_intf-claim ) INTO DATA(lo_object).
      TRY.
          lt_claims = CAST zif_ca_ops_job_claim( lo_object )->claimed( it_jobs ).
        CATCH cx_root INTO DATA(lx_error).
          plugin_failed( iv_plugin = cl_abap_classdescr=>get_class_name( lo_object )
                         ix_error  = lx_error ).
          CONTINUE.
      ENDTRY.
      LOOP AT lt_claims ASSIGNING FIELD-SYMBOL(<ls_claim>).
        INSERT <ls_claim> INTO TABLE mt_claims.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD load_scheduler.
    mt_sched = mo_dao->scheduler_jobs( ).
    LOOP AT mt_sched ASSIGNING FIELD-SYMBOL(<ls_sched>).
      IF zcl_ca_ops_util=>pcre_valid( <ls_sched>-sap_pattern ) = abap_false.
        own_finding( iv_code = zif_ca_ops_job_types=>gc_code-config
                     iv_key  = |{ <ls_sched>-sched_folder }/{ <ls_sched>-sched_job }|
                     iv_text = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-config
                                                      iv_v1    = <ls_sched>-sched_job
                                                      iv_v2    = <ls_sched>-sap_pattern ) ).
        DELETE mt_sched.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD scheduler_of.
    LOOP AT mt_sched ASSIGNING FIELD-SYMBOL(<ls_sched>) WHERE sap_pattern IS NOT INITIAL.
      IF zcl_ca_ops_util=>pcre_match( iv_value = iv_jobname iv_pattern = <ls_sched>-sap_pattern ) = abap_true.
        rs_sched = <ls_sched>.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD load_steps.
    mt_steps = mo_dao->steps( it_keys ).
  ENDMETHOD.


  METHOD collect_evidence.
    keep_lines( it_failed ).
    keep_applogs( it_failed ).
    enrich( ).
    LOOP AT mt_steps ASSIGNING FIELD-SYMBOL(<ls_step>).
      INSERT <ls_step> INTO TABLE ms_evidence-steps.
    ENDLOOP.
  ENDMETHOD.


  METHOD keep_lines.
    LOOP AT it_failed ASSIGNING FIELD-SYMBOL(<ls_failed>).
      DATA(lt_lines) = error_lines( <ls_failed>-job ).
      DELETE lt_lines FROM ms_config-max_messages + 1.
      DATA(lv_no) = 0.
      LOOP AT lt_lines ASSIGNING FIELD-SYMBOL(<ls_line>).
        lv_no += 1.
        INSERT VALUE #( jobname  = <ls_failed>-job-jobname
                        jobcount = <ls_failed>-job-jobcount
                        line_no  = lv_no
                        line     = <ls_line> ) INTO TABLE ms_evidence-lines.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD keep_applogs.
    DATA lt_users TYPE string_table.
    DATA lt_programs TYPE string_table.
    DATA lt_points TYPE STANDARD TABLE OF zif_ca_ops_job_types=>ty_point WITH EMPTY KEY.
    DATA ls_window TYPE zif_ca_ops_job_types=>ty_window.

    IF ms_config-max_applogs = 0.
      RETURN.
    ENDIF.
    LOOP AT it_failed ASSIGNING FIELD-SYMBOL(<ls_failed>) WHERE job-strtdate IS NOT INITIAL.
      INSERT zcl_ca_ops_job_time=>started( <ls_failed>-job ) INTO TABLE lt_points.
      INSERT COND #( WHEN <ls_failed>-job-enddate IS INITIAL THEN ms_now
                     ELSE zcl_ca_ops_job_time=>ended( <ls_failed>-job ) ) INTO TABLE lt_points.
      LOOP AT mt_steps ASSIGNING FIELD-SYMBOL(<ls_step>)
           WHERE jobname = <ls_failed>-job-jobname AND jobcount = <ls_failed>-job-jobcount.
        INSERT CONV string( <ls_step>-authcknam ) INTO TABLE lt_users.
        INSERT CONV string( <ls_step>-progname ) INTO TABLE lt_programs.
      ENDLOOP.
    ENDLOOP.
    SORT lt_points BY date time.
    IF lt_points IS INITIAL.
      RETURN.
    ENDIF.
    ls_window-from = lt_points[ 1 ].
    ls_window-to   = lt_points[ lines( lt_points ) ].
    SORT lt_users.
    DELETE ADJACENT DUPLICATES FROM lt_users.
    SORT lt_programs.
    DELETE ADJACENT DUPLICATES FROM lt_programs.
    DATA(lt_applogs) = mo_dao->applogs( is_window   = ls_window
                                        it_users    = to_range( lt_users )
                                        it_programs = to_range( lt_programs )
                                        iv_max      = ms_config-max_applogs * lines( it_failed ) ).
    " linked to a job by step user, program and run time - no BALHDR field names the job: probable
    LOOP AT it_failed ASSIGNING <ls_failed>.
      DATA(lv_kept) = 0.
      LOOP AT lt_applogs ASSIGNING FIELD-SYMBOL(<ls_applog>).
        IF lv_kept >= ms_config-max_applogs.
          EXIT.
        ENDIF.
        IF zcl_ca_ops_job_time=>ran_at( is_job   = <ls_failed>-job
                                        is_point = VALUE #( date = <ls_applog>-aldate time = <ls_applog>-altime )
                                        is_now   = ms_now ) = abap_false
           OR NOT line_exists( mt_steps[ jobname   = <ls_failed>-job-jobname
                                         jobcount  = <ls_failed>-job-jobcount
                                         progname  = <ls_applog>-alprog
                                         authcknam = <ls_applog>-aluser ] ).
          CONTINUE.
        ENDIF.
        lv_kept += 1.
        INSERT VALUE #( jobname  = <ls_failed>-job-jobname
                        jobcount = <ls_failed>-job-jobcount
                        applog   = <ls_applog>
                        quality  = zif_ca_ops_job_types=>gc_quality-probable ) INTO TABLE ms_evidence-applogs.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD enrich.
    DATA lt_jobs TYPE zif_ca_ops_job_types=>tt_job.
    DATA lt_objects TYPE zif_ca_ops_job_types=>tt_bus_object.

    DATA(lt_enrichers) = plugins( it_classes   = ms_config-enrichers
                                  iv_interface = zif_ca_ops_job_types=>gc_plugin_intf-enricher ).
    IF lt_enrichers IS INITIAL.
      RETURN.
    ENDIF.
    " the failed jobs and their ancestors (context children carry no business context)
    LOOP AT mt_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      IF NOT line_exists( mt_child_link[ child_name = <ls_job>-jobname child_count = <ls_job>-jobcount ] ).
        INSERT <ls_job> INTO TABLE lt_jobs.
      ENDIF.
    ENDLOOP.
    DATA(lt_steps) = VALUE zif_ca_ops_job_types=>tt_step( FOR <ls_s> IN mt_steps ( <ls_s> ) ).
    LOOP AT lt_enrichers INTO DATA(lo_object).
      TRY.
          CAST zif_ca_ops_job_enricher( lo_object )->enrich( EXPORTING it_jobs    = lt_jobs
                                                                       it_steps   = lt_steps
                                                             CHANGING  ct_objects = lt_objects ).
        CATCH cx_root INTO DATA(lx_error).
          plugin_failed( iv_plugin = cl_abap_classdescr=>get_class_name( lo_object )
                         ix_error  = lx_error ).
      ENDTRY.
    ENDLOOP.
    ms_evidence-objects = lt_objects.
  ENDMETHOD.


  METHOD failure_finding.
    DATA(ls_root) = root_of( is_failure-job ).
    READ TABLE mt_jobs ASSIGNING FIELD-SYMBOL(<ls_root>)
         WITH TABLE KEY jobname = ls_root-root-jobname jobcount = ls_root-root-jobcount.
    DATA(lv_root_status) = COND zif_ca_ops_job_types=>ty_status( WHEN sy-subrc = 0 THEN <ls_root>-status ).
    DATA(lv_child) = xsdbool( ls_root-depth > 0 AND lv_root_status <> zif_ca_ops_job_types=>gc_status-aborted ).

    rs_finding-object_type   = zif_ca_ops_job_types=>gc_object_type.
    rs_finding-object_key    = object_key( iv_jobname = is_failure-job-jobname iv_jobcount = is_failure-job-jobcount ).
    rs_finding-rule_id       = zif_ca_ops_job_types=>gc_rule_id.
    rs_finding-reference     = ls_root-root-jobname.
    rs_finding-business_date = COND #( WHEN is_failure-job-enddate IS NOT INITIAL THEN is_failure-job-enddate
                                       ELSE ms_context-today ).
    rs_finding-company_code  = bukrs_of( is_failure-job ).
    rs_finding-item_count    = 1.
    rs_finding-action        = zif_ca_ops_types=>gc_action-exception.
    IF lv_child = abap_true.
      rs_finding-check_code = zif_ca_ops_job_types=>gc_code-child_failed.
      rs_finding-severity   = zif_ca_ops_types=>gc_severity-error.
      rs_finding-message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-child_failed
                                                     iv_v1    = is_failure-job-jobname
                                                     iv_v2    = is_failure-job-jobcount
                                                     iv_v3    = ls_root-root-jobname
                                                     iv_v4    = ls_root-root-jobcount ).
    ELSEIF is_failure-job-status = zif_ca_ops_job_types=>gc_status-aborted.
      rs_finding-check_code = zif_ca_ops_job_types=>gc_code-aborted.
      rs_finding-severity   = zif_ca_ops_types=>gc_severity-error.
      rs_finding-message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-aborted
                                                     iv_v1    = is_failure-job-jobname
                                                     iv_v2    = is_failure-job-jobcount
                                                     iv_v3    = |{ is_failure-job-enddate DATE = ISO }|
                                                     iv_v4    = |{ is_failure-job-endtime TIME = ISO }| ).
    ELSE.
      rs_finding-check_code = zif_ca_ops_job_types=>gc_code-log_error.
      rs_finding-severity   = zif_ca_ops_types=>gc_severity-warning.
      rs_finding-message    = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-log_error
                                                     iv_v1    = is_failure-job-jobname
                                                     iv_v2    = is_failure-job-jobcount
                                                     iv_v3    = is_failure-log_errors ).
    ENDIF.
    rs_finding-context = context_lines( is_job = is_failure-job is_root = ls_root ).
    IF lv_child = abap_true.
      rs_finding-context = rs_finding-context && cl_abap_char_utilities=>newline
                        && zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-ctx_failed
                                                  iv_v1    = iv_failed_in_run ).
      IF lv_root_status = zif_ca_ops_job_types=>gc_status-running
         OR lv_root_status = zif_ca_ops_job_types=>gc_status-put_active.
        rs_finding-context = rs_finding-context && cl_abap_char_utilities=>newline
                          && zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-root_active
                                                    iv_v1    = ls_root-root-jobname
                                                    iv_v2    = ls_root-root-jobcount ).
      ENDIF.
    ENDIF.
    LOOP AT ms_evidence-lines ASSIGNING FIELD-SYMBOL(<ls_line>)
         WHERE jobname = is_failure-job-jobname AND jobcount = is_failure-job-jobcount.
      rs_finding-details = |{ rs_finding-details }{ <ls_line>-line-msgid }/{ <ls_line>-line-msgno } |
                        && |{ <ls_line>-line-msgtype }: { <ls_line>-line-text }{ cl_abap_char_utilities=>newline }|.
    ENDLOOP.
    " another monitor reports this job: evidence and information only, never a second alert
    READ TABLE mt_claims ASSIGNING FIELD-SYMBOL(<ls_claim>)
         WITH TABLE KEY jobname = is_failure-job-jobname jobcount = is_failure-job-jobcount.
    IF sy-subrc = 0.
      rs_finding-severity = zif_ca_ops_types=>gc_severity-info.
      rs_finding-action   = zif_ca_ops_types=>gc_action-notify.
      rs_finding-message  = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-claimed
                                                   iv_v1    = is_failure-job-jobname
                                                   iv_v2    = is_failure-job-jobcount
                                                   iv_v3    = <ls_claim>-claimer ).
    ENDIF.
    DATA(ls_row) = evidence_row( is_job     = is_failure-job
                                 iv_role    = zif_ca_ops_job_types=>gc_role-failed
                                 is_finding = rs_finding ).
    ls_row-log_errors = is_failure-log_errors.
    INSERT ls_row INTO TABLE ms_evidence-jobs.
  ENDMETHOD.


  METHOD state_finding.
    rs_finding-object_type   = zif_ca_ops_job_types=>gc_object_type.
    rs_finding-object_key    = object_key( iv_jobname = is_job-jobname iv_jobcount = is_job-jobcount ).
    rs_finding-rule_id       = zif_ca_ops_job_types=>gc_rule_id.
    rs_finding-check_code    = iv_code.
    rs_finding-severity      = zif_ca_ops_types=>gc_severity-warning.
    rs_finding-action        = zif_ca_ops_types=>gc_action-exception.
    rs_finding-reference     = is_job-jobname.
    rs_finding-business_date = ms_context-today.
    rs_finding-item_count    = 1.
    IF iv_code = zif_ca_ops_job_types=>gc_code-long_running.
      rs_finding-message = zcl_ca_ops_util=>text(
        iv_msgno = zif_ca_ops_job_types=>gc_msg-long_running
        iv_v1    = is_job-jobname
        iv_v2    = is_job-jobcount
        iv_v3    = zcl_ca_ops_job_time=>minutes_between( is_from = zcl_ca_ops_job_time=>started( is_job ) is_to = ms_now )
        iv_v4    = ms_config-long_running_min ).
    ELSE.
      rs_finding-message = zcl_ca_ops_util=>text(
        iv_msgno = zif_ca_ops_job_types=>gc_msg-not_started
        iv_v1    = is_job-jobname
        iv_v2    = is_job-jobcount
        iv_v3    = zcl_ca_ops_job_time=>minutes_between( is_from = VALUE #( date = is_job-sdlstrtdt time = is_job-sdlstrttm )
                                                         is_to   = ms_now )
        iv_v4    = ms_config-not_started_min ).
    ENDIF.
    rs_finding-context = context_lines( is_job  = is_job
                                        is_root = VALUE #( root = VALUE #( jobname = is_job-jobname jobcount = is_job-jobcount ) ) ).
    READ TABLE mt_claims ASSIGNING FIELD-SYMBOL(<ls_claim>)
         WITH TABLE KEY jobname = is_job-jobname jobcount = is_job-jobcount.
    IF sy-subrc = 0.
      rs_finding-severity = zif_ca_ops_types=>gc_severity-info.
      rs_finding-action   = zif_ca_ops_types=>gc_action-notify.
      rs_finding-message  = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-claimed
                                                   iv_v1    = is_job-jobname
                                                   iv_v2    = is_job-jobcount
                                                   iv_v3    = <ls_claim>-claimer ).
    ENDIF.
    INSERT evidence_row( is_job     = is_job
                         iv_role    = zif_ca_ops_job_types=>gc_role-failed
                         is_finding = rs_finding ) INTO TABLE ms_evidence-jobs.
  ENDMETHOD.


  METHOD context_lines.
    DATA lt_lines TYPE string_table.
    DATA ls_first TYPE zif_ca_ops_job_types=>ty_applog.

    READ TABLE mt_parent ASSIGNING FIELD-SYMBOL(<ls_link>)
         WITH TABLE KEY child_name = is_job-jobname child_count = is_job-jobcount.
    IF sy-subrc = 0.
      READ TABLE mt_jobs ASSIGNING FIELD-SYMBOL(<ls_parent>)
           WITH TABLE KEY jobname = <ls_link>-parent_name jobcount = <ls_link>-parent_count.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-ctx_parent
                                    iv_v1    = <ls_link>-parent_name
                                    iv_v2    = <ls_link>-parent_count
                                    iv_v3    = COND zif_ca_ops_job_types=>ty_status( WHEN sy-subrc = 0
                                                                                      THEN <ls_parent>-status )
                                    iv_v4    = |{ <ls_link>-resolver } ({ <ls_link>-quality })| ) INTO TABLE lt_lines.
    ENDIF.
    IF is_root-depth > 0.
      READ TABLE mt_jobs ASSIGNING FIELD-SYMBOL(<ls_root>)
           WITH TABLE KEY jobname = is_root-root-jobname jobcount = is_root-root-jobcount.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-ctx_root
                                    iv_v1    = is_root-root-jobname
                                    iv_v2    = is_root-root-jobcount
                                    iv_v3    = COND zif_ca_ops_job_types=>ty_status( WHEN sy-subrc = 0 THEN <ls_root>-status )
                                    iv_v4    = is_root-depth ) INTO TABLE lt_lines.
    ENDIF.
    DATA(ls_sched) = scheduler_of( is_root-root-jobname ).
    IF ls_sched-sched_job IS NOT INITIAL.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-ctx_sched
                                    iv_v1    = ls_sched-sched_folder
                                    iv_v2    = ls_sched-sched_job
                                    iv_v3    = ls_sched-criticality ) INTO TABLE lt_lines.
    ENDIF.
    LOOP AT mt_steps ASSIGNING FIELD-SYMBOL(<ls_step>) WHERE jobname = is_job-jobname AND jobcount = is_job-jobcount.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-ctx_step
                                    iv_v1    = <ls_step>-stepcount
                                    iv_v2    = <ls_step>-progname
                                    iv_v3    = <ls_step>-variant
                                    iv_v4    = <ls_step>-authcknam ) INTO TABLE lt_lines.
      EXIT.
    ENDLOOP.
    DATA(lv_applogs) = 0.
    DATA(lv_with_errors) = 0.
    LOOP AT ms_evidence-applogs ASSIGNING FIELD-SYMBOL(<ls_applog>)
         WHERE jobname = is_job-jobname AND jobcount = is_job-jobcount.
      lv_applogs += 1.
      IF <ls_applog>-applog-msg_cnt_e > 0 OR <ls_applog>-applog-msg_cnt_a > 0.
        lv_with_errors += 1.
      ENDIF.
      IF lv_applogs = 1.
        ls_first = <ls_applog>-applog.
      ENDIF.
    ENDLOOP.
    IF lv_applogs > 0.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-ctx_applog
                                    iv_v1    = lv_applogs
                                    iv_v2    = lv_with_errors
                                    iv_v3    = ls_first-object
                                    iv_v4    = ls_first-lognumber ) INTO TABLE lt_lines.
    ENDIF.
    LOOP AT ms_evidence-objects ASSIGNING FIELD-SYMBOL(<ls_object>)
         WHERE jobname = is_job-jobname AND jobcount = is_job-jobcount.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_job_types=>gc_msg-ctx_object
                                    iv_v1    = <ls_object>-object_type
                                    iv_v2    = <ls_object>-object_key
                                    iv_v3    = <ls_object>-label
                                    iv_v4    = <ls_object>-quality ) INTO TABLE lt_lines.
    ENDLOOP.
    rv_text = concat_lines_of( table = lt_lines sep = cl_abap_char_utilities=>newline ).
  ENDMETHOD.


  METHOD evidence_row.
    DATA(ls_root) = root_of( is_job ).
    rs_row = VALUE #( jobname         = is_job-jobname
                      jobcount        = is_job-jobcount
                      area            = ms_context-area
                      bukrs           = bukrs_of( is_job )
                      role            = iv_role
                      check_code      = is_finding-check_code
                      severity        = is_finding-severity
                      object_key      = is_finding-object_key
                      status          = is_job-status
                      planned_date    = is_job-sdlstrtdt
                      planned_time    = is_job-sdlstrttm
                      created_date    = is_job-sdldate
                      created_time    = is_job-sdltime
                      start_date      = is_job-strtdate
                      start_time      = is_job-strttime
                      end_date        = is_job-enddate
                      end_time        = is_job-endtime
                      sched_user      = is_job-sdluname
                      server          = is_job-reaxserver
                      event_id        = is_job-eventid
                      event_parm      = is_job-eventparm
                      root_jobname    = ls_root-root-jobname
                      root_jobcount   = ls_root-root-jobcount
                      depth           = ls_root-depth
                      detected_at     = ms_context-now
                      detected_on     = ms_context-today
                      run_id          = ms_context-run_id ).
    READ TABLE mt_jobs ASSIGNING FIELD-SYMBOL(<ls_root>)
         WITH TABLE KEY jobname = ls_root-root-jobname jobcount = ls_root-root-jobcount.
    IF sy-subrc = 0.
      rs_row-root_status = <ls_root>-status.
    ENDIF.
    READ TABLE mt_parent ASSIGNING FIELD-SYMBOL(<ls_link>)
         WITH TABLE KEY child_name = is_job-jobname child_count = is_job-jobcount.
    IF sy-subrc <> 0.
      READ TABLE mt_child_link ASSIGNING <ls_link>
           WITH TABLE KEY child_name = is_job-jobname child_count = is_job-jobcount.
    ENDIF.
    IF sy-subrc = 0.
      rs_row-parent_jobname  = <ls_link>-parent_name.
      rs_row-parent_jobcount = <ls_link>-parent_count.
      rs_row-link_resolver   = <ls_link>-resolver.
      rs_row-link_quality    = <ls_link>-quality.
    ENDIF.
    DATA(ls_sched) = scheduler_of( ls_root-root-jobname ).
    rs_row-sched_folder  = ls_sched-sched_folder.
    rs_row-sched_job     = ls_sched-sched_job.
    rs_row-criticality = ls_sched-criticality.
    READ TABLE mt_claims ASSIGNING FIELD-SYMBOL(<ls_claim>)
         WITH TABLE KEY jobname = is_job-jobname jobcount = is_job-jobcount.
    IF sy-subrc = 0.
      rs_row-claimed_by = <ls_claim>-claimer.
    ENDIF.
  ENDMETHOD.


  METHOD context_rows.
    DATA lt_keys TYPE zif_ca_ops_job_types=>tt_job_key.
    LOOP AT mt_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      IF NOT line_exists( it_failed[ job-jobname = <ls_job>-jobname job-jobcount = <ls_job>-jobcount ] ).
        INSERT VALUE #( jobname = <ls_job>-jobname jobcount = <ls_job>-jobcount ) INTO TABLE lt_keys.
      ENDIF.
    ENDLOOP.
    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.
    " a job kept as a failure (also long-running / not started) is never overwritten by a context row
    DATA(lt_kept) = mo_dao->reported( it_keys          = lt_keys
                                      iv_failures_only = abap_false ).
    LOOP AT lt_keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      IF line_exists( lt_kept[ jobname = <ls_key>-jobname jobcount = <ls_key>-jobcount ] ).
        CONTINUE.
      ENDIF.
      DATA(ls_job) = mt_jobs[ jobname = <ls_key>-jobname jobcount = <ls_key>-jobcount ].
      DATA(lv_role) = COND zif_ca_ops_job_types=>ty_role(
                        WHEN line_exists( mt_child_link[ child_name = <ls_key>-jobname child_count = <ls_key>-jobcount ] )
                        THEN zif_ca_ops_job_types=>gc_role-child
                        ELSE zif_ca_ops_job_types=>gc_role-ancestor ).
      DATA(ls_row) = evidence_row( is_job  = ls_job
                                   iv_role = lv_role ).
      IF lv_role = zif_ca_ops_job_types=>gc_role-ancestor.
        ls_row-failed_children = REDUCE i( INIT lv_count = 0
                                           FOR <ls_f> IN ms_evidence-jobs
                                           WHERE ( root_jobname = <ls_key>-jobname AND root_jobcount = <ls_key>-jobcount )
                                           NEXT lv_count = lv_count + 1 ).
      ENDIF.
      INSERT ls_row INTO TABLE ms_evidence-jobs.
    ENDLOOP.
  ENDMETHOD.


  METHOD bukrs_of.
    LOOP AT ms_evidence-objects ASSIGNING FIELD-SYMBOL(<ls_object>)
         WHERE jobname = is_job-jobname AND jobcount = is_job-jobcount AND bukrs IS NOT INITIAL.
      IF rv_bukrs IS INITIAL.
        rv_bukrs = <ls_object>-bukrs.
      ELSEIF rv_bukrs <> <ls_object>-bukrs.
        " objects of two company codes: the job is area-level
        CLEAR rv_bukrs.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD save.
    IF ms_context-test_mode = abap_true.
      RETURN.
    ENDIF.
    mo_dao->save( is_evidence  = ms_evidence
                  is_watermark = COND #( WHEN is_watermark IS NOT INITIAL
                                         THEN VALUE #( area     = is_check-area
                                                       check_id = is_check-check_id
                                                       point    = is_watermark
                                                       run_id   = ms_context-run_id ) ) ).
  ENDMETHOD.


  METHOD own_finding.
    INSERT VALUE #( object_type = zif_ca_ops_job_types=>gc_object_type
                    object_key  = iv_key
                    rule_id     = zif_ca_ops_job_types=>gc_rule_id
                    check_code  = iv_code
                    severity    = zif_ca_ops_types=>gc_severity-warning
                    action      = iv_action
                    message     = iv_text ) INTO TABLE mt_own.
  ENDMETHOD.


  METHOD keys.
    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      INSERT VALUE #( jobname = <ls_job>-jobname jobcount = <ls_job>-jobcount ) INTO TABLE rt_keys.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
