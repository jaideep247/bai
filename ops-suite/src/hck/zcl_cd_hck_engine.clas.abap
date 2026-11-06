*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_engine.clas.abap
*& Purpose:
*& Health check engine: runs the configured checks, guards each one,
*& evaluates thresholds/baselines, persists via the core store and alerts.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*& 2026-11-06 | Run header committed at start; results committed before alerts and report mail.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - engine (run checks, score, persist)</p>
"! Per check: plug-in by class name (ZCD_HCK_DEF), runtime measured against
"! TIMEOUT_SEC (overrun = finding; a synchronous call cannot be killed),
"! any exception -> PLUGIN_ERROR finding and the run continues, metrics
"! evaluated against ZCD_HCK_THRESH ('*' fallback, z-score / IQR baseline),
"! findings and metrics persisted per check (module HCK, object type CHECK,
"! GROUP1 = category, GROUP2 = check id). Health of the health check: the
"! modules in HCK_WATCH_MODULES must have run within HCK_MAX_AGE_HOURS.
"! Test mode: nothing saved, nothing committed, no alert, no e-mail.
CLASS zcl_cd_hck_engine DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    CONSTANTS:
      BEGIN OF gc_param,
        watch_modules TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_WATCH_MODULES',
        max_age_hours TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_MAX_AGE_HOURS',
        timeout_sec   TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_TIMEOUT_SEC',
        lookback      TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_LOOKBACK_RUNS',
        top_n         TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_TOP_N',
        mail_route    TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_MAIL_ROUTE',
        green_min     TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_SCORE_GREEN_MIN',
        amber_min     TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_SCORE_AMBER_MIN',
        weight_high   TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_WEIGHT_H',
        weight_medium TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_WEIGHT_M',
        weight_low    TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_WEIGHT_L',
      END OF gc_param.

    CONSTANTS gc_default_route TYPE zif_cd_ops_types=>ty_param_name VALUE 'MORNING'.

    "! Run the selected checks and build the morning report
    "! @raising zcx_cd_ops_error | store errors (start/save/finish run)
    METHODS run
      IMPORTING
        is_selection     TYPE zif_cd_hck_types=>ty_selection
      RETURNING
        VALUE(rs_report) TYPE zif_cd_hck_types=>ty_report
      RAISING
        zcx_cd_ops_error.

    "! Take a new golden baseline (hash) of every table in ZCD_HCK_DRIFT.
    "! Requires S_TABU_NAM ACTVT 02 for table ZCD_HCK_BASELINE.
    "! @raising zcx_cd_ops_error | 041 no authorization, 303/311 hash errors
    METHODS take_baseline
      IMPORTING
        iv_test_mode    TYPE abap_bool
      RETURNING
        VALUE(rv_count) TYPE i
      RAISING
        zcx_cd_ops_error.

  PRIVATE SECTION.

    DATA mo_store TYPE REF TO zif_cd_ops_store.
    DATA mo_dao TYPE REF TO zif_cd_hck_dao.
    DATA mo_clock TYPE REF TO zif_cd_ops_clock.

    METHODS execute_check
      IMPORTING
        is_def           TYPE zif_cd_hck_types=>ty_check_def
        is_context       TYPE zif_cd_hck_types=>ty_context
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result.

    METHODS call_plugin
      IMPORTING
        is_def           TYPE zif_cd_hck_types=>ty_check_def
        it_thresholds    TYPE zif_cd_hck_types=>tt_threshold
        is_context       TYPE zif_cd_hck_types=>ty_context
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.

    METHODS evaluate_metrics
      IMPORTING
        it_thresholds TYPE zif_cd_hck_types=>tt_threshold
      CHANGING
        cs_result     TYPE zif_cd_hck_types=>ty_check_result.

    METHODS finalize_result
      CHANGING
        cs_result TYPE zif_cd_hck_types=>ty_check_result.

    METHODS persist_result
      IMPORTING
        is_result TYPE zif_cd_hck_types=>ty_check_result
      CHANGING
        cs_run    TYPE zif_cd_ops_types=>ty_run
      RAISING
        zcx_cd_ops_error.

    METHODS module_status
      RETURNING
        VALUE(rt_modules) TYPE zif_cd_hck_types=>tt_module_status.

    METHODS self_check
      IMPORTING
        it_modules       TYPE zif_cd_hck_types=>tt_module_status
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result.

    METHODS open_exceptions
      IMPORTING
        iv_today             TYPE d
      RETURNING
        VALUE(rt_exceptions) TYPE zif_cd_hck_types=>tt_open_exception.

    METHODS score_rules
      RETURNING
        VALUE(rs_rules) TYPE zif_cd_hck_types=>ty_score_rules.

    METHODS notify
      IMPORTING
        is_selection TYPE zif_cd_hck_types=>ty_selection
      CHANGING
        cs_report    TYPE zif_cd_hck_types=>ty_report
      RAISING
        zcx_cd_ops_error.

    METHODS close_run
      CHANGING
        cs_report TYPE zif_cd_hck_types=>ty_report.

    METHODS param_int
      IMPORTING
        iv_name         TYPE zif_cd_ops_types=>ty_param_name
        iv_default      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

    METHODS hours_between
      IMPORTING
        iv_from         TYPE timestampl
        iv_to           TYPE timestampl
      RETURNING
        VALUE(rv_hours) TYPE i.

    "! DIM1 as threshold key when it fits 4 characters (company code, source), else '*'
    METHODS threshold_key
      IMPORTING
        iv_dim1       TYPE zif_cd_hck_types=>ty_dim
      RETURNING
        VALUE(rv_key) TYPE zif_cd_hck_types=>ty_thresh_key.

    METHODS value_text
      IMPORTING
        iv_value       TYPE zif_cd_hck_types=>ty_value
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_cd_hck_engine IMPLEMENTATION.

  METHOD run.
    mo_store = zcl_cd_ops_factory=>get_store( ).
    mo_clock = zcl_cd_ops_factory=>get_clock( ).
    mo_dao   = zcl_cd_hck_factory=>get_dao( ).

    DATA(lv_today) = mo_clock->today( ).
    rs_report-report_date = COND #( WHEN is_selection-report_date IS INITIAL THEN lv_today
                                    ELSE is_selection-report_date ).
    rs_report-run = mo_store->start_run( iv_module    = zif_cd_ops_types=>gc_module-health_check
                                         iv_variant   = is_selection-variant
                                         iv_test_mode = is_selection-test_mode ).
    IF rs_report-run-started_at IS INITIAL.
      rs_report-run-started_at = mo_clock->now( ).
    ENDIF.
    IF is_selection-test_mode = abap_false.
      " Run header durable first: a run that dumps stays visible as status R
      mo_store->commit( ).
    ENDIF.

    DATA(ls_context) = VALUE zif_cd_hck_types=>ty_context( report_date = rs_report-report_date
                                                           now_date    = lv_today
                                                           now_time    = mo_clock->time( )
                                                           run_id      = rs_report-run-run_id
                                                           test_mode   = is_selection-test_mode ).

    DATA(lt_defs) = mo_dao->get_check_defs( it_categories = is_selection-categories
                                            it_priorities = is_selection-priorities
                                            it_check_ids  = is_selection-check_ids ).
    LOOP AT lt_defs INTO DATA(ls_def).
      DATA(ls_result) = execute_check( is_def     = ls_def
                                       is_context = ls_context ).
      IF is_selection-test_mode = abap_false.
        persist_result( EXPORTING is_result = ls_result
                        CHANGING  cs_run    = rs_report-run ).
      ENDIF.
      INSERT ls_result INTO TABLE rs_report-results.
    ENDLOOP.

    IF is_selection-include_modules = abap_true.
      rs_report-modules = module_status( ).
      ls_result = self_check( rs_report-modules ).
      IF is_selection-test_mode = abap_false.
        persist_result( EXPORTING is_result = ls_result
                        CHANGING  cs_run    = rs_report-run ).
      ENDIF.
      INSERT ls_result INTO TABLE rs_report-results.
    ENDIF.

    DATA(ls_summary) = zcl_cd_hck_score=>summarize( it_results = rs_report-results
                                                    is_rules   = score_rules( ) ).
    rs_report-score          = ls_summary-score.
    rs_report-overall_rag    = ls_summary-overall_rag.
    rs_report-critical_count = ls_summary-critical_count.
    rs_report-high_count     = ls_summary-high_count.
    rs_report-categories     = ls_summary-categories.
    rs_report-exceptions     = open_exceptions( lv_today ).

    close_run( CHANGING cs_report = rs_report ).

    IF is_selection-test_mode = abap_true.
      RETURN.
    ENDIF.
    " Results are durable before anyone is told (a channel may COMMIT WORK itself)
    mo_store->finish_run( rs_report-run ).
    mo_store->commit( ).
    notify( EXPORTING is_selection = is_selection
            CHANGING  cs_report    = rs_report ).
  ENDMETHOD.


  METHOD take_baseline.
    DATA lt_baselines TYPE zif_cd_hck_types=>tt_baseline.

    AUTHORITY-CHECK OBJECT 'S_TABU_NAM'
      ID 'ACTVT' FIELD '02'
      ID 'TABLE' FIELD 'ZCD_HCK_BASELINE'.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e041(zcd_ops) WITH 'ZCD_HCK_BASELINE' '02'.
    ENDIF.

    mo_store = zcl_cd_ops_factory=>get_store( ).
    mo_clock = zcl_cd_ops_factory=>get_clock( ).
    mo_dao   = zcl_cd_hck_factory=>get_dao( ).

    DATA(lv_now) = mo_clock->now( ).
    LOOP AT mo_dao->get_drift_tables( ) INTO DATA(ls_table).
      DATA(ls_baseline) = mo_dao->compute_table_hash( ls_table-tabname ).
      ls_baseline-taken_at = lv_now.
      ls_baseline-taken_by = sy-uname.
      INSERT ls_baseline INTO TABLE lt_baselines.
    ENDLOOP.
    rv_count = lines( lt_baselines ).

    IF iv_test_mode = abap_true OR lt_baselines IS INITIAL.
      RETURN.
    ENDIF.
    mo_dao->save_baselines( lt_baselines ).
    mo_store->commit( ).
  ENDMETHOD.


  METHOD execute_check.
    DATA(lv_started) = mo_clock->now( ).
    DATA(lt_thresholds) = mo_dao->get_thresholds( is_def-check_id ).

    TRY.
        rs_result = call_plugin( is_def        = is_def
                                 it_thresholds = lt_thresholds
                                 is_context    = is_context ).
      CATCH zcx_cd_ops_error INTO DATA(lx_ops).
        CLEAR rs_result.
        rs_result-plugin_error = abap_true.
        INSERT VALUE #( check_code = zif_cd_hck_types=>gc_code-plugin_error
                        severity   = zif_cd_ops_types=>gc_severity-error
                        action     = zif_cd_ops_types=>gc_action-notify
                        reference  = is_def-class_name
                        message    = lx_ops->get_text( ) ) INTO TABLE rs_result-findings.
      CATCH cx_root INTO DATA(lx_root).
        CLEAR rs_result.
        rs_result-plugin_error = abap_true.
        INSERT VALUE #( check_code = zif_cd_hck_types=>gc_code-plugin_error
                        severity   = zif_cd_ops_types=>gc_severity-error
                        action     = zif_cd_ops_types=>gc_action-notify
                        reference  = is_def-class_name
                        message    = lx_root->get_text( ) ) INTO TABLE rs_result-findings.
    ENDTRY.

    rs_result-check_id    = is_def-check_id.
    rs_result-description = is_def-description.
    rs_result-category    = is_def-category.
    rs_result-priority    = is_def-priority.
    rs_result-runtime_ms  = zcl_cd_ops_util=>elapsed_ms( iv_from = lv_started
                                                         iv_to   = mo_clock->now( ) ).

    DATA(lv_timeout_sec) = COND i( WHEN is_def-timeout_sec > 0 THEN is_def-timeout_sec
                                   ELSE param_int( iv_name = gc_param-timeout_sec iv_default = 300 ) ).
    IF rs_result-runtime_ms > lv_timeout_sec * 1000.
      rs_result-timed_out = abap_true.
      INSERT VALUE #( check_code = zif_cd_hck_types=>gc_code-timeout
                      severity   = zif_cd_ops_types=>gc_severity-warning
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = |Check { is_def-check_id } ran { rs_result-runtime_ms } ms, timeout { lv_timeout_sec } s| )
        INTO TABLE rs_result-findings.
    ENDIF.

    IF rs_result-plugin_error = abap_false.
      evaluate_metrics( EXPORTING it_thresholds = lt_thresholds
                        CHANGING  cs_result     = rs_result ).
    ENDIF.
    finalize_result( CHANGING cs_result = rs_result ).
  ENDMETHOD.


  METHOD call_plugin.
    DATA lo_check TYPE REF TO zif_cd_hck_check.
    DATA(lo_object) = zcl_cd_ops_factory=>get_plugin( is_def-class_name ).
    TRY.
        lo_check ?= lo_object.
      CATCH cx_sy_move_cast_error.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e300(zcd_ops) WITH is_def-check_id is_def-class_name.
    ENDTRY.
    rs_result = lo_check->execute( is_def        = is_def
                                   it_thresholds = it_thresholds
                                   is_context    = is_context ).
  ENDMETHOD.


  METHOD evaluate_metrics.
    DATA lt_history TYPE zif_cd_hck_types=>tt_value.
    DATA(lv_default_lookback) = param_int( iv_name = gc_param-lookback iv_default = 8 ).

    LOOP AT cs_result-metrics INTO DATA(ls_metric).
      DATA(ls_threshold) = zcl_cd_hck_threshold=>resolve( it_thresholds = it_thresholds
                                                          iv_metric     = ls_metric-metric
                                                          iv_key        = threshold_key( ls_metric-dim1 ) ).
      IF ls_threshold IS INITIAL.
        CONTINUE.
      ENDIF.
      CLEAR lt_history.
      IF ls_threshold-baseline_mode IS NOT INITIAL AND ls_threshold-baseline_mode <> zif_cd_hck_types=>gc_baseline-none.
        lt_history = mo_dao->get_metric_history(
          iv_check_id = cs_result-check_id
          iv_metric   = ls_metric-metric
          iv_dim1     = ls_metric-dim1
          iv_max_rows = COND #( WHEN ls_threshold-lookback_runs > 0 THEN ls_threshold-lookback_runs
                                ELSE lv_default_lookback ) ).
      ENDIF.
      DATA(ls_evaluation) = zcl_cd_hck_threshold=>evaluate( iv_value     = ls_metric-value
                                                            is_threshold = ls_threshold
                                                            it_history   = lt_history ).
      IF ls_evaluation-check_code IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lv_message) = COND string(
        WHEN ls_evaluation-check_code = zif_cd_hck_types=>gc_code-baseline_outlier
        THEN |{ ls_metric-metric } { ls_metric-dim1 }: { value_text( ls_metric-value ) } is a baseline outlier |
          && |(mean { value_text( ls_evaluation-mean ) }, z { value_text( ls_evaluation-z_score ) }, |
          && |{ ls_evaluation-points } points)|
        ELSE |{ ls_metric-metric } { ls_metric-dim1 }: { value_text( ls_metric-value ) } |
          && |(amber { value_text( ls_threshold-amber ) }, red { value_text( ls_threshold-red ) })| ).
      INSERT VALUE #( object_key = |{ cs_result-check_id }/{ ls_metric-metric }/{ ls_metric-dim1 }|
                      check_code = ls_evaluation-check_code
                      severity   = COND #( WHEN ls_evaluation-rag = zif_cd_ops_types=>gc_rag-red
                                           THEN zif_cd_ops_types=>gc_severity-error
                                           ELSE zif_cd_ops_types=>gc_severity-warning )
                      action     = zif_cd_ops_types=>gc_action-exception
                      reference  = ls_metric-dim2
                      message    = lv_message ) INTO TABLE cs_result-findings.
    ENDLOOP.
  ENDMETHOD.


  METHOD finalize_result.
    LOOP AT cs_result-findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      <ls_finding>-object_type = zif_cd_hck_types=>gc_object_type.
      <ls_finding>-group1      = cs_result-category.
      <ls_finding>-group2      = cs_result-check_id.
      IF <ls_finding>-object_key IS INITIAL.
        <ls_finding>-object_key = cs_result-check_id.
      ENDIF.
    ENDLOOP.

    cs_result-rag = zcl_cd_ops_util=>worse_rag( iv_rag1 = cs_result-rag
                                                iv_rag2 = zcl_cd_ops_util=>rag_from_findings( cs_result-findings ) ).
    IF cs_result-plugin_error = abap_true.
      cs_result-rag = zif_cd_ops_types=>gc_rag-red.
    ENDIF.

    DATA(lv_worst) = zcl_cd_ops_util=>worst_severity( cs_result-findings ).
    IF lv_worst IS INITIAL OR lv_worst = zif_cd_ops_types=>gc_severity-info.
      IF cs_result-summary IS INITIAL.
        cs_result-summary = |OK - { lines( cs_result-metrics ) } metric(s) within limits|.
      ENDIF.
      RETURN.
    ENDIF.
    DATA(ls_worst) = VALUE #( cs_result-findings[ severity = lv_worst ] OPTIONAL ).
    cs_result-summary = COND #( WHEN lines( cs_result-findings ) > 1
                                THEN |{ ls_worst-message } (+{ lines( cs_result-findings ) - 1 } more)|
                                ELSE ls_worst-message ).
  ENDMETHOD.


  METHOD persist_result.
    DATA lt_history TYPE zif_cd_hck_types=>tt_metric_hist.
    DATA ls_history TYPE zif_cd_hck_types=>ty_metric_hist.

    IF is_result-findings IS NOT INITIAL.
      mo_store->save_findings( EXPORTING it_findings = is_result-findings
                               CHANGING  cs_run      = cs_run ).
    ENDIF.

    DATA(lv_now) = mo_clock->now( ).
    LOOP AT is_result-metrics INTO DATA(ls_metric).
      ls_history-run_id      = cs_run-run_id.
      ls_history-check_id    = is_result-check_id.
      ls_history-metric      = ls_metric-metric.
      ls_history-dim1        = ls_metric-dim1.
      ls_history-dim2        = ls_metric-dim2.
      ls_history-value       = ls_metric-value.
      ls_history-measured_at = lv_now.
      INSERT ls_history INTO TABLE lt_history.
    ENDLOOP.
    IF lt_history IS NOT INITIAL.
      mo_dao->save_metrics( lt_history ).
    ENDIF.
    " one commit per check: results survive a later abort of the run
    mo_store->commit( ).
  ENDMETHOD.


  METHOD module_status.
    DATA ls_status TYPE zif_cd_hck_types=>ty_module_status.

    DATA(lv_now) = mo_clock->now( ).
    DATA(lv_default_age) = param_int( iv_name = gc_param-max_age_hours iv_default = 26 ).
    DATA(lt_modules) = zcl_cd_ops_util=>split_list(
      mo_store->get_param( iv_name = gc_param-watch_modules iv_default = `EBS,FMON,HCK` ) ).

    LOOP AT lt_modules INTO DATA(lv_module).
      CLEAR ls_status.
      ls_status-module        = to_upper( lv_module ).
      ls_status-max_age_hours = param_int( iv_name    = CONV #( |HCK_MAX_AGE_H_{ ls_status-module }| )
                                           iv_default = lv_default_age ).
      DATA(ls_last) = mo_store->get_last_run( ls_status-module ).
      IF ls_last-run_id IS INITIAL.
        ls_status-stale = abap_true.
        ls_status-rag   = zif_cd_ops_types=>gc_rag-red.
        INSERT ls_status INTO TABLE rt_modules.
        CONTINUE.
      ENDIF.
      ls_status-last_run_at   = ls_last-started_at.
      ls_status-status        = ls_last-status.
      ls_status-rag           = ls_last-rag.
      ls_status-finding_count = ls_last-finding_count.
      ls_status-age_hours     = hours_between( iv_from = ls_last-started_at
                                               iv_to   = lv_now ).
      ls_status-stale         = xsdbool( ls_status-age_hours > ls_status-max_age_hours ).
      LOOP AT mo_store->get_findings( ls_last-run_id ) INTO DATA(ls_finding).
        CASE zcl_cd_ops_util=>severity_rank( ls_finding-severity ).
          WHEN 3 OR 4.
            ls_status-error_count = ls_status-error_count + 1.
          WHEN 2.
            ls_status-warning_count = ls_status-warning_count + 1.
        ENDCASE.
      ENDLOOP.
      INSERT ls_status INTO TABLE rt_modules.
    ENDLOOP.
  ENDMETHOD.


  METHOD self_check.
    rs_result-check_id    = zif_cd_hck_types=>gc_self_check.
    rs_result-description = 'Health of the health check (EBS, FMON, HCK ran)'.
    rs_result-category    = zif_cd_hck_types=>gc_category-technical.
    rs_result-priority    = zif_cd_hck_types=>gc_priority-high.
    LOOP AT it_modules INTO DATA(ls_module) WHERE stale = abap_true.
      INSERT VALUE #( object_key = ls_module-module
                      check_code = zif_cd_hck_types=>gc_code-module_stale
                      severity   = zif_cd_ops_types=>gc_severity-error
                      action     = zif_cd_ops_types=>gc_action-notify
                      message    = COND #( WHEN ls_module-last_run_at IS INITIAL
                                           THEN |Module { ls_module-module } has never run|
                                           ELSE |Module { ls_module-module } last ran { ls_module-age_hours } h ago |
                                             && |(max { ls_module-max_age_hours } h)| ) )
        INTO TABLE rs_result-findings.
    ENDLOOP.
    finalize_result( CHANGING cs_result = rs_result ).
  ENDMETHOD.


  METHOD open_exceptions.
    DATA lv_created TYPE d.
    DATA lv_time TYPE t.
    rt_exceptions = mo_dao->get_open_exceptions( param_int( iv_name = gc_param-top_n iv_default = 20 ) ).
    LOOP AT rt_exceptions ASSIGNING FIELD-SYMBOL(<ls_exception>).
      IF <ls_exception>-created_at IS NOT INITIAL.
        CONVERT TIME STAMP <ls_exception>-created_at TIME ZONE sy-zonlo INTO DATE lv_created TIME lv_time.
        <ls_exception>-age_days = iv_today - lv_created.
      ENDIF.
      IF <ls_exception>-due_date IS NOT INITIAL AND <ls_exception>-due_date < iv_today.
        <ls_exception>-overdue_days = iv_today - <ls_exception>-due_date.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD score_rules.
    rs_rules = zcl_cd_hck_score=>default_rules( ).
    rs_rules-green_min     = param_int( iv_name = gc_param-green_min     iv_default = rs_rules-green_min ).
    rs_rules-amber_min     = param_int( iv_name = gc_param-amber_min     iv_default = rs_rules-amber_min ).
    rs_rules-weight_high   = param_int( iv_name = gc_param-weight_high   iv_default = rs_rules-weight_high ).
    rs_rules-weight_medium = param_int( iv_name = gc_param-weight_medium iv_default = rs_rules-weight_medium ).
    rs_rules-weight_low    = param_int( iv_name = gc_param-weight_low    iv_default = rs_rules-weight_low ).
  ENDMETHOD.


  METHOD notify.
    DATA lt_findings TYPE zif_cd_ops_types=>tt_finding.
    DATA lt_failures TYPE zif_cd_ops_types=>tt_finding.

    LOOP AT cs_report-results INTO DATA(ls_result).
      INSERT LINES OF ls_result-findings INTO TABLE lt_findings.
    ENDLOOP.

    DATA(lo_alert) = zcl_cd_ops_factory=>get_alert( ).
    " alert routing (channels, recipients, throttling) is customizing of ZCD_OPS_ALERT_RULE
    TRY.
        lo_alert->dispatch( is_run      = cs_report-run
                            it_findings = lt_findings ).
      CATCH zcx_cd_ops_error INTO DATA(lx_dispatch).
        INSERT VALUE #( object_type = zif_cd_hck_types=>gc_object_type
                        object_key  = zif_cd_hck_types=>gc_self_check
                        group1      = zif_cd_hck_types=>gc_category-technical
                        group2      = zif_cd_hck_types=>gc_self_check
                        check_code  = zif_cd_hck_types=>gc_code-alert_failed
                        severity    = zif_cd_ops_types=>gc_severity-warning
                        action      = zif_cd_ops_types=>gc_action-notify
                        message     = lx_dispatch->get_text( ) ) INTO TABLE lt_failures.
    ENDTRY.

    " the morning report e-mail is a report, not an alert: deliberate send to one route
    IF is_selection-send_mail = abap_true.
      TRY.
          lo_alert->send( iv_route   = CONV #( mo_store->get_param( iv_name    = gc_param-mail_route
                                                                    iv_default = CONV #( gc_default_route ) ) )
                          iv_subject = zcl_cd_hck_report_html=>subject( cs_report )
                          iv_html    = zcl_cd_hck_report_html=>render( cs_report ) ).
        CATCH zcx_cd_ops_error INTO DATA(lx_send).
          INSERT VALUE #( object_type = zif_cd_hck_types=>gc_object_type
                          object_key  = gc_default_route
                          group1      = zif_cd_hck_types=>gc_category-technical
                          group2      = zif_cd_hck_types=>gc_self_check
                          check_code  = zif_cd_hck_types=>gc_code-alert_failed
                          severity    = zif_cd_ops_types=>gc_severity-warning
                          action      = zif_cd_ops_types=>gc_action-notify
                          message     = lx_send->get_text( ) ) INTO TABLE lt_failures.
      ENDTRY.
    ENDIF.

    IF lt_failures IS NOT INITIAL.
      mo_store->save_findings( EXPORTING it_findings = lt_failures
                               CHANGING  cs_run      = cs_report-run ).
      mo_store->finish_run( cs_report-run ).
      mo_store->commit( ).
    ENDIF.
  ENDMETHOD.


  METHOD close_run.
    LOOP AT cs_report-results INTO DATA(ls_result).
      CASE ls_result-rag.
        WHEN zif_cd_ops_types=>gc_rag-green.
          cs_report-run-passed_items = cs_report-run-passed_items + 1.
        WHEN zif_cd_ops_types=>gc_rag-amber.
          cs_report-run-warning_items = cs_report-run-warning_items + 1.
        WHEN OTHERS.
          cs_report-run-failed_items = cs_report-run-failed_items + 1.
      ENDCASE.
    ENDLOOP.
    cs_report-run-total_items = lines( cs_report-results ).
    cs_report-run-rag         = cs_report-overall_rag.
    cs_report-run-status      = SWITCH #( cs_report-overall_rag
                                          WHEN zif_cd_ops_types=>gc_rag-red   THEN zif_cd_ops_types=>gc_run_status-error
                                          WHEN zif_cd_ops_types=>gc_rag-amber THEN zif_cd_ops_types=>gc_run_status-warning
                                          ELSE zif_cd_ops_types=>gc_run_status-success ).
    cs_report-run-ended_at    = mo_clock->now( ).
    cs_report-run-runtime_ms  = zcl_cd_ops_util=>elapsed_ms( iv_from = cs_report-run-started_at
                                                             iv_to   = cs_report-run-ended_at ).
    cs_report-run-message     = |Health score { cs_report-score }/100, { cs_report-critical_count } red, |
                             && |{ cs_report-high_count } amber|.
  ENDMETHOD.


  METHOD param_int.
    rv_value = zcl_cd_ops_util=>to_decimal( iv_value   = mo_store->get_param( iv_name = iv_name )
                                            iv_default = iv_default ).
  ENDMETHOD.


  METHOD hours_between.
    TRY.
        DATA(lv_seconds) = cl_abap_tstmp=>subtract( tstmp1 = iv_to
                                                    tstmp2 = iv_from ).
        rv_hours = lv_seconds DIV 3600.
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        rv_hours = 0.
    ENDTRY.
  ENDMETHOD.


  METHOD threshold_key.
    rv_key = COND #( WHEN strlen( condense( iv_dim1 ) ) <= 4 AND iv_dim1 IS NOT INITIAL THEN iv_dim1
                     ELSE zif_cd_hck_types=>gc_default_key ).
  ENDMETHOD.


  METHOD value_text.
    rv_text = |{ iv_value STYLE = SIMPLE }|.
  ENDMETHOD.

ENDCLASS.
