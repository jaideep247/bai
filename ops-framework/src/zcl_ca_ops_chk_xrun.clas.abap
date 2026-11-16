*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_xrun.clas.abap
*& Purpose:
*& Registered check of the expected runs (module JOBS; registry row
*& CA_OPS / EXPECTED_RUNS, delivered inactive; docs/EXPECTED_RUNS_AND_
*& MASS_ACTIVITIES.md section 2): reads the plan of every expected-run
*& source of XRUN_SOURCES (ZIF_CA_OPS_EXPECTED_RUN_SRC, in order - a run
*& of an earlier source wins) for today and XRUN_LOOKBACK_DAYS back,
*& compares it with SAP's background jobs (ZCL_CA_OPS_XRUN_MONITOR, TBTCO
*& through the job monitor's data access) and raises: never started (the
*& scheduler never started it, or it failed before SAP, or the SAP job
*& waits), predecessor not finished, held, started late. Every finding
*& carries the exception contract: one run (amount unknown), the deadline
*& that passed (planned start + late minutes), the stage, the owner from
*& the configuration and evidence rows of the scheduler record (kind
*& SCHD) and of the SAP job (link object S4_BACKGROUND_JOB; quality P -
*& matched by name and time window) or "no SAP job" (quality U). The
*& evaluation record: a source older than its limit makes the result
*& STALE (and a notice), a source that cannot be read makes it not
*& evaluated (the check partial), a day the business calendar does not
*& expect is HOLIDAY, a day it cannot answer is not evaluated. Reads only:
*& nothing is started, held, released or restarted.
*& Modification log:
*& 2026-11-16 | Initial version (build P: expected runs from the scheduler).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - check: expected runs</p>
"! Registry row: ZCA_OPS_CHECK with CLASS_NAME = ZCL_CA_OPS_CHK_XRUN, the area of the consumer and a fast schedule
"! group (e.g. every 15 minutes); its owner is the control covering the check (else the business process owner).
CLASS zcl_ca_ops_chk_xrun DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

    "! Source name of SAP's jobs in the evidence rows
    CONSTANTS gc_sap_source TYPE zif_ca_ops_exc_contract=>ty_source_id VALUE 'TBTCO'.
    "! Link registry object of an SAP background job
    CONSTANTS gc_link_job TYPE zif_ca_ops_exc_contract=>ty_link_object VALUE 'S4_BACKGROUND_JOB'.

    "! @parameter io_dao | Data access of the job monitor (tests: a double)
    METHODS constructor
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_job_dao OPTIONAL.

    "! Object key of a run: scheduler job / planned date and time (the folder is in the evidence)
    CLASS-METHODS object_key
      IMPORTING
        is_run        TYPE zif_ca_ops_xrun_types=>ty_expected
      RETURNING
        VALUE(rv_key) TYPE zif_ca_ops_types=>ty_object_key.

  PRIVATE SECTION.
    "! Field names of the key values of an evidence row
    CONSTANTS:
      BEGIN OF gc_field,
        source   TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'SOURCE',
        run      TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'RUN',
        job      TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'JOB',
        plan     TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'PLAN',
        state    TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'STATE',
        jobname  TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'JOBNAME',
        jobcount TYPE zif_ca_ops_link_types=>ty_fieldname VALUE 'JOBCOUNT',
      END OF gc_field.
    CONSTANTS gc_seconds_per_minute TYPE i VALUE 60.

    TYPES:
      BEGIN OF ty_owner_cache,
        check_code TYPE zif_ca_ops_types=>ty_check_code,
        stage      TYPE zif_ca_ops_types=>ty_rule_id,
        owner      TYPE zif_ca_ops_owner=>ty_owner,
      END OF ty_owner_cache.
    TYPES tt_owner_cache TYPE HASHED TABLE OF ty_owner_cache WITH UNIQUE KEY check_code stage.

    DATA mo_dao TYPE REF TO zif_ca_ops_job_dao.
    DATA mo_params TYPE REF TO zif_ca_ops_params.
    DATA ms_check TYPE zif_ca_ops_chk_types=>ty_check.
    DATA ms_context TYPE zif_ca_ops_chk_types=>ty_context.
    DATA ms_now TYPE zif_ca_ops_job_types=>ty_point.
    DATA mt_owners TYPE tt_owner_cache.

    "! Parameters of the comparison
    METHODS config
      RETURNING
        VALUE(rs_config) TYPE zif_ca_ops_xrun_types=>ty_config.

    METHODS int_param
      IMPORTING
        iv_name         TYPE zif_ca_ops_types=>ty_param_name
        iv_default      TYPE i
        iv_ceiling      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

    "! The plans of every source, merged (an earlier source's run wins); notices for stale, failed and unusable
    "! sources, holidays and unknown days folded into the evaluation
    METHODS plans
      IMPORTING
        is_request     TYPE zif_ca_ops_xrun_types=>ty_request
      CHANGING
        cs_result      TYPE zif_ca_ops_chk_types=>ty_result
      RETURNING
        VALUE(rt_runs) TYPE zif_ca_ops_xrun_types=>tt_expected.

    "! The days of one source's plan that are holidays, unknown or invalid
    METHODS plan_days
      IMPORTING
        iv_source_id TYPE zif_ca_ops_xrun_types=>ty_source_id
        is_plan      TYPE zif_ca_ops_xrun_types=>ty_plan
      CHANGING
        cs_result    TYPE zif_ca_ops_chk_types=>ty_result.

    "! A notice about a source or the configuration (warning, action NOTIFY - no deadline, no owned run)
    METHODS notice
      IMPORTING
        iv_code           TYPE zif_ca_ops_types=>ty_check_code
        iv_key            TYPE clike
        iv_msgno          TYPE zif_ca_ops_types=>ty_msgno
        iv_v1             TYPE simple OPTIONAL
        iv_v2             TYPE simple OPTIONAL
        iv_v3             TYPE simple OPTIONAL
        iv_v4             TYPE simple OPTIONAL
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! The finding of a verdict with its contract and evidence (initial for OK and PENDING)
    METHODS finding
      IMPORTING
        is_result         TYPE zif_ca_ops_xrun_types=>ty_result
      CHANGING
        ct_evidence       TYPE zif_ca_ops_exc_contract=>tt_evidence
      RETURNING
        VALUE(rs_finding) TYPE zif_ca_ops_types=>ty_finding.

    "! Message of a verdict
    METHODS message
      IMPORTING
        is_result      TYPE zif_ca_ops_xrun_types=>ty_result
      RETURNING
        VALUE(rv_text) TYPE zif_ca_ops_types=>ty_message.

    "! Context lines: the scheduler record, the SAP job, the predecessor
    METHODS context
      IMPORTING
        is_result      TYPE zif_ca_ops_xrun_types=>ty_result
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Evidence rows of a verdict: the scheduler record, the SAP job (or none), the predecessor and its job
    METHODS evidence
      IMPORTING
        is_result          TYPE zif_ca_ops_xrun_types=>ty_result
        iv_evid_key        TYPE zif_ca_ops_exc_contract=>ty_evid_key
      RETURNING
        VALUE(rt_evidence) TYPE zif_ca_ops_exc_contract=>tt_evidence.

    METHODS sched_row
      IMPORTING
        is_run             TYPE zif_ca_ops_xrun_types=>ty_expected
        iv_evid_key        TYPE zif_ca_ops_exc_contract=>ty_evid_key
        iv_seq             TYPE i
      RETURNING
        VALUE(rs_evidence) TYPE zif_ca_ops_exc_contract=>ty_evidence.

    METHODS job_row
      IMPORTING
        is_job             TYPE zif_ca_ops_job_types=>ty_job
        is_run             TYPE zif_ca_ops_xrun_types=>ty_expected
        iv_evid_key        TYPE zif_ca_ops_exc_contract=>ty_evid_key
        iv_seq             TYPE i
      RETURNING
        VALUE(rs_evidence) TYPE zif_ca_ops_exc_contract=>ty_evidence.

    "! Owner of a check code and stage from the configuration (cached for the run)
    METHODS owner
      IMPORTING
        iv_code         TYPE zif_ca_ops_types=>ty_check_code
        iv_stage        TYPE zif_ca_ops_types=>ty_rule_id
      RETURNING
        VALUE(rs_owner) TYPE zif_ca_ops_owner=>ty_owner.

    "! UTC time stamp of a point of the server clock (by its distance to now; initial when now is unknown)
    METHODS utc_of
      IMPORTING
        is_point     TYPE zif_ca_ops_job_types=>ty_point
      RETURNING
        VALUE(rv_ts) TYPE timestampl.

    CLASS-METHODS point_text
      IMPORTING
        iv_date        TYPE d
        iv_time        TYPE t
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_ca_ops_chk_xrun IMPLEMENTATION.

  METHOD constructor.
    mo_dao = COND #( WHEN io_dao IS BOUND THEN io_dao ELSE NEW zcl_ca_ops_job_dao( ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_check~run.
    DATA lt_invalid TYPE zif_ca_ops_xrun_types=>tt_expected.
    DATA lt_evidence TYPE zif_ca_ops_exc_contract=>tt_evidence.

    ms_check   = is_check.
    ms_context = is_context.
    mo_params  = zcl_ca_ops_factory=>get_params( ).
    ms_now     = zcl_ca_ops_job_time=>now( ).
    CLEAR mt_owners.
    DATA(ls_config) = config( ).
    DATA(lv_lookback) = int_param( iv_name    = zif_ca_ops_xrun_types=>gc_param-lookback
                                   iv_default = zif_ca_ops_xrun_types=>gc_param_default-lookback
                                   iv_ceiling = zif_ca_ops_xrun_types=>gc_ceiling-lookback ).
    DATA(lt_runs) = plans( EXPORTING is_request = VALUE #( from_date = ms_now-date - lv_lookback
                                                           to_date   = ms_now-date
                                                           max       = ls_config-max_jobs
                                                           now       = is_context-now )
                           CHANGING  cs_result  = rs_result ).
    DATA(lo_monitor) = NEW zcl_ca_ops_xrun_monitor( mo_dao ).
    lo_monitor->resolve_patterns( CHANGING ct_runs    = lt_runs
                                           ct_invalid = lt_invalid ).
    LOOP AT lt_invalid ASSIGNING FIELD-SYMBOL(<ls_invalid>).
      INSERT notice( iv_code  = zif_ca_ops_xrun_types=>gc_code-config_invalid
                     iv_key   = object_key( <ls_invalid> )
                     iv_msgno = zif_ca_ops_xrun_types=>gc_msg-config
                     iv_v1    = |{ <ls_invalid>-sched_folder }/{ <ls_invalid>-sched_job }|
                     iv_v2    = <ls_invalid>-sap_pattern ) INTO TABLE rs_result-findings.
      zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = zif_ca_ops_eval_types=>gc_state-not_evaluated
                                   CHANGING  cs_eval = rs_result-eval ).
      rs_result-partial = abap_true.
    ENDLOOP.
    lo_monitor->sap_jobs( EXPORTING it_runs   = lt_runs
                                    is_config = ls_config
                                    is_now    = ms_now
                          IMPORTING et_jobs   = DATA(lt_jobs)
                                    ev_capped = DATA(lv_capped) ).
    IF lv_capped = abap_true.
      INSERT notice( iv_code  = zif_ca_ops_xrun_types=>gc_code-capped
                     iv_key   = gc_sap_source
                     iv_msgno = zif_ca_ops_xrun_types=>gc_msg-capped
                     iv_v1    = ls_config-max_jobs ) INTO TABLE rs_result-findings.
      rs_result-partial = abap_true.
    ENDIF.
    LOOP AT zcl_ca_ops_xrun_monitor=>judge( it_runs   = lt_runs
                                            it_jobs   = lt_jobs
                                            is_config = ls_config
                                            is_now    = ms_now ) ASSIGNING FIELD-SYMBOL(<ls_result>).
      rs_result-item_count += 1.
      CASE <ls_result>-verdict.
        WHEN zif_ca_ops_xrun_types=>gc_verdict-pending.
          CONTINUE.
        WHEN zif_ca_ops_xrun_types=>gc_verdict-ok.
          rs_result-eval-expected += 1.
          rs_result-eval-observed += 1.
          zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = zif_ca_ops_eval_types=>gc_state-ok
                                       CHANGING  cs_eval = rs_result-eval ).
        WHEN OTHERS.
          rs_result-eval-expected += 1.
          IF <ls_result>-verdict = zif_ca_ops_xrun_types=>gc_verdict-started_late.
            rs_result-eval-observed += 1.
          ENDIF.
          DATA(ls_finding) = finding( EXPORTING is_result   = <ls_result>
                                      CHANGING  ct_evidence = lt_evidence ).
          INSERT ls_finding INTO TABLE rs_result-findings.
          zcl_ca_ops_eval=>merge_term( EXPORTING iv_term      = zif_ca_ops_eval_types=>gc_term-observed
                                                 iv_exception = abap_true
                                       CHANGING  cs_eval      = rs_result-eval ).
      ENDCASE.
    ENDLOOP.
    rs_result-evidence = lt_evidence.
    rs_result-eval-bus_date = ms_now-date.
  ENDMETHOD.


  METHOD config.
    rs_config-late_min  = int_param( iv_name    = zif_ca_ops_xrun_types=>gc_param-late_min
                                     iv_default = zif_ca_ops_xrun_types=>gc_param_default-late_min
                                     iv_ceiling = zif_ca_ops_xrun_types=>gc_ceiling-minutes ).
    rs_config-early_min = int_param( iv_name    = zif_ca_ops_xrun_types=>gc_param-early_min
                                     iv_default = zif_ca_ops_xrun_types=>gc_param_default-early_min
                                     iv_ceiling = zif_ca_ops_xrun_types=>gc_ceiling-minutes ).
    rs_config-match_min = int_param( iv_name    = zif_ca_ops_xrun_types=>gc_param-match_min
                                     iv_default = zif_ca_ops_xrun_types=>gc_param_default-match_min
                                     iv_ceiling = zif_ca_ops_xrun_types=>gc_ceiling-minutes ).
    rs_config-max_jobs  = nmax( val1 = 1
                                val2 = int_param( iv_name    = zif_ca_ops_xrun_types=>gc_param-max_jobs
                                                  iv_default = zif_ca_ops_xrun_types=>gc_param_default-max_jobs
                                                  iv_ceiling = zif_ca_ops_xrun_types=>gc_ceiling-max_jobs ) ).
    LOOP AT zcl_ca_ops_util=>split_list( mo_params->get_param(
                                           iv_name    = zif_ca_ops_xrun_types=>gc_param-waiting
                                           iv_default = zif_ca_ops_xrun_types=>gc_param_default-waiting ) )
         ASSIGNING FIELD-SYMBOL(<lv_status>).
      INSERT VALUE #( sign   = zif_ca_ops_types=>gc_range-sign_include
                      option = zif_ca_ops_types=>gc_range-option_equal
                      low    = to_upper( <lv_status> ) ) INTO TABLE rs_config-waiting.
    ENDLOOP.
  ENDMETHOD.


  METHOD int_param.
    rv_value = nmin( val1 = iv_ceiling
                     val2 = nmax( val1 = 0
                                  val2 = zcl_ca_ops_util=>param_int( io_params  = mo_params
                                                                     iv_name    = iv_name
                                                                     iv_default = iv_default ) ) ).
  ENDMETHOD.


  METHOD plans.
    DATA lo_source TYPE REF TO zif_ca_ops_expected_run_src.

    LOOP AT zcl_ca_ops_util=>split_list( mo_params->get_param(
                                           iv_name    = zif_ca_ops_xrun_types=>gc_param-sources
                                           iv_default = zif_ca_ops_xrun_types=>gc_param_default-sources ) )
         ASSIGNING FIELD-SYMBOL(<lv_class>).
      DATA(lv_class) = CONV zif_ca_ops_types=>ty_class_name( to_upper( <lv_class> ) ).
      TRY.
          lo_source = CAST #( zcl_ca_ops_factory=>get_plugin(
                                iv_class_name = lv_class
                                iv_interface  = zif_ca_ops_xrun_types=>gc_plugin_intf-source ) ).
        CATCH zcx_ca_ops_error INTO DATA(lx_plugin).
          " a source that cannot be created is a gap of the plan, never "nothing expected"
          INSERT notice( iv_code  = zif_ca_ops_xrun_types=>gc_code-config_invalid
                         iv_key   = lv_class
                         iv_msgno = zif_ca_ops_xrun_types=>gc_msg-config
                         iv_v1    = lv_class
                         iv_v2    = lx_plugin->get_text( ) ) INTO TABLE cs_result-findings.
          zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = zif_ca_ops_eval_types=>gc_state-not_evaluated
                                       CHANGING  cs_eval = cs_result-eval ).
          cs_result-partial = abap_true.
          CONTINUE.
      ENDTRY.
      DATA(lv_source) = lo_source->id( ).
      TRY.
          DATA(ls_plan) = lo_source->read( is_request ).
        CATCH zcx_ca_ops_error INTO DATA(lx_read).
          INSERT notice( iv_code  = zif_ca_ops_xrun_types=>gc_code-source_failed
                         iv_key   = lv_source
                         iv_msgno = zif_ca_ops_xrun_types=>gc_msg-source_failed
                         iv_v1    = lv_source
                         iv_v2    = lx_read->get_text( ) ) INTO TABLE cs_result-findings.
          zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = zif_ca_ops_eval_types=>gc_state-not_evaluated
                                       CHANGING  cs_eval = cs_result-eval ).
          cs_result-partial = abap_true.
          CONTINUE.
      ENDTRY.
      " freshness of the source: the evaluation record judges it against its limit (stale = STALE, never OK)
      DATA(lv_stale_min) = COND i( WHEN ls_plan-stale_min > 0 THEN ls_plan-stale_min
                                   ELSE int_param( iv_name    = zif_ca_ops_xrun_types=>gc_param-stale_min
                                                   iv_default = zif_ca_ops_xrun_types=>gc_param_default-stale_min
                                                   iv_ceiling = zif_ca_ops_xrun_types=>gc_ceiling-minutes ) ).
      zcl_ca_ops_eval=>add_source( EXPORTING iv_source_id = lv_source
                                             iv_newest_at = ls_plan-newest_at
                                             iv_stale_min = lv_stale_min
                                   CHANGING  cs_eval      = cs_result-eval ).
      IF zcl_ca_ops_eval=>is_stale( iv_newest_at = ls_plan-newest_at
                                    iv_now       = is_request-now
                                    iv_stale_min = lv_stale_min ) = abap_true.
        INSERT notice( iv_code  = zif_ca_ops_xrun_types=>gc_code-source_stale
                       iv_key   = lv_source
                       iv_msgno = zif_ca_ops_xrun_types=>gc_msg-source_stale
                       iv_v1    = lv_source
                       iv_v2    = |{ ls_plan-newest_at TIMESTAMP = ISO }|
                       iv_v3    = lv_stale_min ) INTO TABLE cs_result-findings.
        zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = zif_ca_ops_eval_types=>gc_state-stale
                                     CHANGING  cs_eval = cs_result-eval ).
      ENDIF.
      IF ls_plan-partial = abap_true.
        cs_result-partial = abap_true.
      ENDIF.
      plan_days( EXPORTING iv_source_id = lv_source
                           is_plan      = ls_plan
                 CHANGING  cs_result    = cs_result ).
      LOOP AT ls_plan-runs INTO DATA(ls_run).
        IF line_exists( rt_runs[ sched_folder = ls_run-sched_folder
                                 sched_job    = ls_run-sched_job
                                 plan_date    = ls_run-plan_date
                                 plan_time    = ls_run-plan_time ] ).
          CONTINUE.
        ENDIF.
        IF ls_run-source_id IS INITIAL.
          ls_run-source_id = lv_source.
        ENDIF.
        INSERT ls_run INTO TABLE rt_runs.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD plan_days.
    " a day the business calendar does not expect: HOLIDAY, not OK and not missing
    DO lines( is_plan-not_expected ) TIMES.
      zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = zif_ca_ops_eval_types=>gc_state-holiday
                                   CHANGING  cs_eval = cs_result-eval ).
    ENDDO.
    LOOP AT is_plan-unknown ASSIGNING FIELD-SYMBOL(<ls_day>).
      INSERT notice( iv_code  = zif_ca_ops_xrun_types=>gc_code-config_invalid
                     iv_key   = |{ <ls_day>-sched_job }/{ <ls_day>-plan_date }|
                     iv_msgno = zif_ca_ops_xrun_types=>gc_msg-config
                     iv_v1    = |{ iv_source_id } { <ls_day>-sched_folder }/{ <ls_day>-sched_job } { <ls_day>-plan_date DATE = ISO }|
                     iv_v2    = <ls_day>-reason ) INTO TABLE cs_result-findings.
      zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = zif_ca_ops_eval_types=>gc_state-not_evaluated
                                   CHANGING  cs_eval = cs_result-eval ).
      cs_result-partial = abap_true.
    ENDLOOP.
    LOOP AT is_plan-invalid ASSIGNING <ls_day>.
      INSERT notice( iv_code  = zif_ca_ops_xrun_types=>gc_code-config_invalid
                     iv_key   = |{ <ls_day>-sched_folder }/{ <ls_day>-sched_job }|
                     iv_msgno = zif_ca_ops_xrun_types=>gc_msg-config
                     iv_v1    = |{ iv_source_id } { <ls_day>-sched_folder }/{ <ls_day>-sched_job }|
                     iv_v2    = <ls_day>-reason ) INTO TABLE cs_result-findings.
      zcl_ca_ops_eval=>merge_term( EXPORTING iv_term = zif_ca_ops_eval_types=>gc_state-not_evaluated
                                   CHANGING  cs_eval = cs_result-eval ).
      cs_result-partial = abap_true.
    ENDLOOP.
  ENDMETHOD.


  METHOD notice.
    rs_finding = VALUE #( object_type = zif_ca_ops_xrun_types=>gc_object_type
                          object_key  = iv_key
                          rule_id     = zif_ca_ops_xrun_types=>gc_stage-source
                          stage       = zif_ca_ops_xrun_types=>gc_stage-source
                          check_code  = iv_code
                          severity    = zif_ca_ops_types=>gc_severity-warning
                          action      = zif_ca_ops_types=>gc_action-notify
                          message     = zcl_ca_ops_util=>text( iv_msgno = iv_msgno
                                                               iv_v1    = iv_v1
                                                               iv_v2    = iv_v2
                                                               iv_v3    = iv_v3
                                                               iv_v4    = iv_v4 )
                          item_count    = 0
                          unknown_count = 1 ).
    DATA(ls_owner) = owner( iv_code = iv_code iv_stage = zif_ca_ops_xrun_types=>gc_stage-source ).
    rs_finding-resp_user   = ls_owner-user.
    rs_finding-resp_team   = ls_owner-team.
    rs_finding-resp_source = ls_owner-source.
    rs_finding-evid_key    = zcl_ca_ops_exc_contract=>evidence_key( iv_area       = ms_check-area
                                                                    iv_check_id   = ms_check-check_id
                                                                    iv_object_key = rs_finding-object_key ).
  ENDMETHOD.


  METHOD finding.
    DATA lv_code TYPE zif_ca_ops_types=>ty_check_code.
    DATA lv_severity TYPE zif_ca_ops_types=>ty_severity.

    CASE is_result-verdict.
      WHEN zif_ca_ops_xrun_types=>gc_verdict-never_started.
        lv_code = zif_ca_ops_xrun_types=>gc_code-never_started.
        lv_severity = zif_ca_ops_types=>gc_severity-error.
      WHEN zif_ca_ops_xrun_types=>gc_verdict-pred_open.
        lv_code = zif_ca_ops_xrun_types=>gc_code-pred_open.
        lv_severity = zif_ca_ops_types=>gc_severity-error.
      WHEN zif_ca_ops_xrun_types=>gc_verdict-held.
        lv_code = zif_ca_ops_xrun_types=>gc_code-held.
        lv_severity = zif_ca_ops_types=>gc_severity-warning.
      WHEN zif_ca_ops_xrun_types=>gc_verdict-started_late.
        lv_code = zif_ca_ops_xrun_types=>gc_code-started_late.
        lv_severity = zif_ca_ops_types=>gc_severity-warning.
      WHEN OTHERS.
        RETURN.
    ENDCASE.
    rs_finding = VALUE #( object_type   = zif_ca_ops_xrun_types=>gc_object_type
                          object_key    = object_key( is_result-run )
                          rule_id       = is_result-stage
                          stage         = is_result-stage
                          check_code    = lv_code
                          severity      = lv_severity
                          action        = zif_ca_ops_types=>gc_action-exception
                          reference     = |{ is_result-run-sched_folder }/{ is_result-run-sched_job }|
                          message       = message( is_result )
                          context       = context( is_result )
                          business_date = is_result-run-plan_date
                          item_count    = 1
                          unknown_count = 1
                          event_at      = utc_of( zcl_ca_ops_xrun_monitor=>planned( is_result-run ) )
                          deadline_at   = utc_of( VALUE #( date = is_result-due_date time = is_result-due_time ) ) ).
    DATA(ls_owner) = owner( iv_code = lv_code iv_stage = is_result-stage ).
    rs_finding-resp_user   = ls_owner-user.
    rs_finding-resp_team   = ls_owner-team.
    rs_finding-resp_source = ls_owner-source.
    rs_finding-evid_key    = zcl_ca_ops_exc_contract=>evidence_key( iv_area       = ms_check-area
                                                                    iv_check_id   = ms_check-check_id
                                                                    iv_object_key = rs_finding-object_key ).
    DELETE ct_evidence WHERE evid_key = rs_finding-evid_key.
    INSERT LINES OF evidence( is_result = is_result iv_evid_key = rs_finding-evid_key ) INTO TABLE ct_evidence.
  ENDMETHOD.


  METHOD message.
    DATA(lv_run) = |{ is_result-run-sched_folder }/{ is_result-run-sched_job }|.
    DATA(lv_plan) = point_text( iv_date = is_result-run-plan_date iv_time = is_result-run-plan_time ).
    CASE is_result-verdict.
      WHEN zif_ca_ops_xrun_types=>gc_verdict-pred_open.
        rv_text = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_xrun_types=>gc_msg-pred_open
                                         iv_v1    = lv_run
                                         iv_v2    = lv_plan
                                         iv_v3    = |{ is_result-pred-sched_folder }/{ is_result-pred-sched_job }|
                                         iv_v4    = COND string( WHEN is_result-pred_job IS INITIAL
                                                                 THEN is_result-pred-sched_state
                                                                 ELSE |{ is_result-pred_job-jobname } { is_result-pred_job-status }| ) ).
      WHEN zif_ca_ops_xrun_types=>gc_verdict-held.
        rv_text = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_xrun_types=>gc_msg-held
                                         iv_v1    = lv_run
                                         iv_v2    = lv_plan
                                         iv_v3    = |{ is_result-run-state_at TIMESTAMP = ISO }| ).
      WHEN zif_ca_ops_xrun_types=>gc_verdict-started_late.
        rv_text = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_xrun_types=>gc_msg-started_late
                                         iv_v1    = lv_run
                                         iv_v2    = lv_plan
                                         iv_v3    = is_result-late_minutes
                                         iv_v4    = |{ is_result-job-jobname }/{ is_result-job-jobcount }| ).
      WHEN OTHERS.
        CASE is_result-stage.
          WHEN zif_ca_ops_xrun_types=>gc_stage-sap_queue.
            rv_text = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_xrun_types=>gc_msg-sap_queue
                                             iv_v1    = lv_run
                                             iv_v2    = lv_plan
                                             iv_v3    = |{ is_result-job-jobname }/{ is_result-job-jobcount }|
                                             iv_v4    = is_result-job-status ).
          WHEN zif_ca_ops_xrun_types=>gc_stage-handover.
            rv_text = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_xrun_types=>gc_msg-handover
                                             iv_v1    = lv_run
                                             iv_v2    = lv_plan
                                             iv_v3    = is_result-run-sched_state
                                             iv_v4    = is_result-run-sap_pattern ).
          WHEN OTHERS.
            rv_text = zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_xrun_types=>gc_msg-never_started
                                             iv_v1    = lv_run
                                             iv_v2    = lv_plan
                                             iv_v3    = is_result-run-sap_pattern
                                             iv_v4    = COND string( WHEN is_result-run-sched_state IS INITIAL
                                                                     THEN `-`
                                                                     ELSE is_result-run-sched_state ) ).
        ENDCASE.
    ENDCASE.
  ENDMETHOD.


  METHOD context.
    DATA lt_lines TYPE string_table.

    INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_xrun_types=>gc_msg-ctx_sched
                                  iv_v1    = is_result-run-source_id
                                  iv_v2    = |{ is_result-run-sched_folder }/{ is_result-run-sched_job }|
                                  iv_v3    = is_result-run-run_id
                                  iv_v4    = is_result-run-sched_state ) INTO TABLE lt_lines.
    IF is_result-job IS NOT INITIAL.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_xrun_types=>gc_msg-ctx_job
                                    iv_v1    = is_result-job-jobname
                                    iv_v2    = is_result-job-jobcount
                                    iv_v3    = is_result-job-status
                                    iv_v4    = point_text( iv_date = is_result-job-strtdate
                                                           iv_time = is_result-job-strttime ) ) INTO TABLE lt_lines.
    ENDIF.
    IF is_result-pred IS NOT INITIAL.
      INSERT zcl_ca_ops_util=>text( iv_msgno = zif_ca_ops_xrun_types=>gc_msg-ctx_pred
                                    iv_v1    = |{ is_result-pred-sched_folder }/{ is_result-pred-sched_job }|
                                    iv_v2    = |{ is_result-pred_job-jobname }/{ is_result-pred_job-jobcount }|
                                    iv_v3    = is_result-pred_job-status ) INTO TABLE lt_lines.
    ENDIF.
    rv_text = concat_lines_of( table = lt_lines sep = cl_abap_char_utilities=>newline ).
  ENDMETHOD.


  METHOD evidence.
    INSERT sched_row( is_run = is_result-run iv_evid_key = iv_evid_key iv_seq = 1 ) INTO TABLE rt_evidence.
    INSERT job_row( is_job      = is_result-job
                    is_run      = is_result-run
                    iv_evid_key = iv_evid_key
                    iv_seq      = 2 ) INTO TABLE rt_evidence.
    IF is_result-pred IS NOT INITIAL.
      INSERT sched_row( is_run = is_result-pred iv_evid_key = iv_evid_key iv_seq = 3 ) INTO TABLE rt_evidence.
      INSERT job_row( is_job      = is_result-pred_job
                      is_run      = is_result-pred
                      iv_evid_key = iv_evid_key
                      iv_seq      = 4 ) INTO TABLE rt_evidence.
    ENDIF.
  ENDMETHOD.


  METHOD sched_row.
    rs_evidence = VALUE #(
      evid_key    = iv_evid_key
      seq         = iv_seq
      kind        = zif_ca_ops_exc_contract=>gc_kind-scheduler
      ev_type     = zif_ca_ops_exc_contract=>gc_type-run
      label       = |{ is_run-sched_folder }/{ is_run-sched_job }|
      native_key  = zcl_ca_ops_exc_contract=>link_value( VALUE #(
                      ( fieldname = gc_field-source value = is_run-source_id )
                      ( fieldname = gc_field-run    value = is_run-run_id )
                      ( fieldname = gc_field-job    value = is_run-sched_job )
                      ( fieldname = gc_field-plan   value = point_text( iv_date = is_run-plan_date iv_time = is_run-plan_time ) )
                      ( fieldname = gc_field-state  value = is_run-sched_state ) ) )
      occurred_at = is_run-state_at
      observed_at = ms_context-now
      quality     = zif_ca_ops_exc_contract=>gc_quality-confirmed
      source_id   = is_run-source_id ).
  ENDMETHOD.


  METHOD job_row.
    IF is_job IS INITIAL.
      " SAP has no job of the run's names in its window: the absence is evidence too
      rs_evidence = VALUE #( evid_key    = iv_evid_key
                             seq         = iv_seq
                             kind        = zif_ca_ops_exc_contract=>gc_kind-sap
                             ev_type     = zif_ca_ops_exc_contract=>gc_type-job
                             label       = is_run-sap_pattern
                             native_key  = |{ gc_field-jobname }~{ is_run-sap_pattern }|
                             observed_at = ms_context-now
                             quality     = zif_ca_ops_exc_contract=>gc_quality-unmatched
                             source_id   = gc_sap_source ).
      RETURN.
    ENDIF.
    DATA(lv_value) = zcl_ca_ops_exc_contract=>link_value( VALUE #( ( fieldname = gc_field-jobname  value = is_job-jobname )
                                                                   ( fieldname = gc_field-jobcount value = is_job-jobcount ) ) ).
    rs_evidence = VALUE #( evid_key    = iv_evid_key
                           seq         = iv_seq
                           kind        = zif_ca_ops_exc_contract=>gc_kind-sap
                           ev_type     = zif_ca_ops_exc_contract=>gc_type-job
                           label       = |{ is_job-jobname }/{ is_job-jobcount } { is_job-status }|
                           native_key  = lv_value
                           link_object = gc_link_job
                           link_value  = lv_value
                           occurred_at = COND #( WHEN is_job-strtdate IS NOT INITIAL
                                                 THEN utc_of( zcl_ca_ops_job_time=>started( is_job ) ) )
                           observed_at = ms_context-now
                           quality     = zif_ca_ops_exc_contract=>gc_quality-probable
                           source_id   = gc_sap_source ).
  ENDMETHOD.


  METHOD owner.
    ASSIGN mt_owners[ check_code = iv_code stage = iv_stage ] TO FIELD-SYMBOL(<ls_cache>).
    IF sy-subrc <> 0.
      INSERT VALUE #( check_code = iv_code
                      stage      = iv_stage
                      owner      = zcl_ca_ops_factory=>get_owner( )->resolve( iv_area       = ms_check-area
                                                                              iv_check_id   = ms_check-check_id
                                                                              iv_check_code = iv_code
                                                                              iv_rule_id    = iv_stage
                                                                              iv_process_id = ms_check-process_id ) )
             INTO TABLE mt_owners ASSIGNING <ls_cache>.
    ENDIF.
    rs_owner = <ls_cache>-owner.
    IF rs_owner-source IS INITIAL.
      rs_owner-source = zif_ca_ops_exc_contract=>gc_resp_source-none.
    ENDIF.
  ENDMETHOD.


  METHOD utc_of.
    IF ms_context-now IS INITIAL OR is_point-date IS INITIAL.
      RETURN.
    ENDIF.
    TRY.
        rv_ts = cl_abap_tstmp=>add( tstmp = ms_context-now
                                    secs  = zcl_ca_ops_job_time=>minutes_between( is_from = ms_now
                                                                                  is_to   = is_point ) * gc_seconds_per_minute ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        CLEAR rv_ts.
    ENDTRY.
  ENDMETHOD.


  METHOD object_key.
    rv_key = |{ is_run-sched_job }{ zif_ca_ops_xrun_types=>gc_separator }{ is_run-plan_date }{ is_run-plan_time(4) }|.
  ENDMETHOD.


  METHOD point_text.
    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.
    rv_text = |{ iv_date DATE = ISO } { iv_time TIME = ISO }|.
  ENDMETHOD.

ENDCLASS.
