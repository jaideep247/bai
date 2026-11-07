*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_dash_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the health check dashboard on cl_cds_test_environment
*& doubles of the base tables (ZCD_HCK_DEF, ZCD_HCK_RESULT, ZCD_HCK_METRIC,
*& ZCD_OPS_FINDING, ZCD_OPS_RUN): status of every check in the last
*& completed run as the engine persisted it (RED, AMBER, WARMUP, GREEN,
*& FAILED, SKIPPED; NO_RESULT without a row), green without metric, scope
*& of a filtered run, warm-up next to a fixed limit = report, findings of older runs do not change the status
*& but count as open, category status = worst check, KPI counts, as-of / stale
*& and the 31-day metric history with its DIM2 series; does not prove live
*& SAP runtime behavior.
*& VERIFY-ADT: create( i_select_base_dependencies = abap_true ) doubles the
*& tables behind the view stack (incl. CROSS JOIN with outer joins on the
*& cross-joined row) on 7.58; $session.system_date is not doubled.
*& Modification log:
*& 2026-11-06 | Initial version (health check dashboard).
*& 2026-11-06 | Modern-syntax sweep: test helper LTD_ROWS.
*& 2026-11-07 | moncfg_threshold_applies: ZCD_OPS_MONCFG threshold of HCK (base dependency doubled).
*& 2026-11-07 | Verdict from ZCD_HCK_RESULT (design review): ltc_verdict with the four acceptance cases.
*&---------------------------------------------------------------------*
"! Test data builders: one row per call, filled field by field (house rule)
CLASS ltd_rows DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    CONSTANTS gc_pe_area TYPE zif_cd_ops_types=>ty_pe_area VALUE 'HCK'.
    CONSTANTS gc_metric TYPE c LENGTH 30 VALUE 'COUNT'.

    CLASS-METHODS now
      RETURNING
        VALUE(rv_now) TYPE timestampl.

    CLASS-METHODS seconds_ago
      IMPORTING
        iv_seconds   TYPE i
      RETURNING
        VALUE(rv_ts) TYPE timestampl.

    CLASS-METHODS check
      IMPORTING
        iv_check_id   TYPE zif_cd_hck_types=>ty_check_id
        iv_category   TYPE zif_cd_hck_types=>ty_category
        iv_active     TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(rs_def) TYPE zcd_hck_def.

    CLASS-METHODS finding
      IMPORTING
        iv_run_id         TYPE zif_cd_ops_types=>ty_run_id
        iv_finding_no     TYPE i
        iv_check_id       TYPE zif_cd_hck_types=>ty_check_id
        iv_category       TYPE zif_cd_hck_types=>ty_category
        iv_code           TYPE zif_cd_ops_types=>ty_check_code
        iv_severity       TYPE zif_cd_ops_types=>ty_severity
        iv_disposition    TYPE zif_cd_ops_types=>ty_disposition DEFAULT zif_cd_ops_types=>gc_disposition-open
      RETURNING
        VALUE(rs_finding) TYPE zcd_ops_finding.

    CLASS-METHODS metric
      IMPORTING
        iv_run_id        TYPE zif_cd_ops_types=>ty_run_id
        iv_check_id      TYPE zif_cd_hck_types=>ty_check_id
        iv_dim1          TYPE clike
        iv_dim2          TYPE clike OPTIONAL
        iv_measured_at   TYPE timestampl
      RETURNING
        VALUE(rs_metric) TYPE zcd_hck_metric.

    CLASS-METHODS run
      IMPORTING
        iv_run_id     TYPE zif_cd_ops_types=>ty_run_id
        iv_status     TYPE zif_cd_ops_types=>ty_run_status
        iv_ended_at   TYPE timestampl
        iv_test_mode  TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rs_run) TYPE zcd_ops_run.

    "! Persisted verdict of a check in a run (ZCD_HCK_RESULT)
    CLASS-METHODS result
      IMPORTING
        iv_run_id        TYPE zif_cd_ops_types=>ty_run_id
        iv_check_id      TYPE zif_cd_hck_types=>ty_check_id
        iv_status        TYPE zif_cd_hck_types=>ty_check_status
        iv_completion    TYPE zif_cd_hck_types=>ty_completion DEFAULT zif_cd_hck_types=>gc_completion-complete
        iv_metric_count  TYPE i DEFAULT 0
      RETURNING
        VALUE(rs_result) TYPE zcd_hck_result.
ENDCLASS.


CLASS ltd_rows IMPLEMENTATION.

  METHOD now.
    GET TIME STAMP FIELD rv_now.
  ENDMETHOD.


  METHOD seconds_ago.
    rv_ts = cl_abap_tstmp=>subtract_secs( tstmp = CONV timestamp( now( ) ) secs = iv_seconds ).
  ENDMETHOD.


  METHOD check.
    rs_def-check_id = iv_check_id.
    rs_def-category = iv_category.
    rs_def-active   = iv_active.
    rs_def-priority = zif_cd_hck_types=>gc_priority-high.
  ENDMETHOD.


  METHOD finding.
    rs_finding-run_id      = iv_run_id.
    rs_finding-finding_no  = iv_finding_no.
    rs_finding-pe_area     = gc_pe_area.
    rs_finding-object_type = zif_cd_hck_types=>gc_object_type.
    rs_finding-object_key  = iv_check_id.
    rs_finding-group1      = iv_category.
    rs_finding-group2      = iv_check_id.
    rs_finding-check_code  = iv_code.
    rs_finding-severity    = iv_severity.
    rs_finding-disposition = iv_disposition.
    rs_finding-created_at  = now( ).
  ENDMETHOD.


  METHOD metric.
    rs_metric-run_id      = iv_run_id.
    rs_metric-check_id    = iv_check_id.
    rs_metric-metric      = gc_metric.
    rs_metric-dim1        = iv_dim1.
    rs_metric-dim2        = iv_dim2.
    rs_metric-measured_at = iv_measured_at.
    rs_metric-kind        = zif_cd_hck_types=>gc_metric_kind-volume.
  ENDMETHOD.


  METHOD run.
    rs_run-run_id     = iv_run_id.
    rs_run-pe_area    = gc_pe_area.
    rs_run-test_mode  = iv_test_mode.
    rs_run-status     = iv_status.
    rs_run-ended_at   = iv_ended_at.
    rs_run-started_at = iv_ended_at.
  ENDMETHOD.


  METHOD result.
    rs_result-run_id       = iv_run_id.
    rs_result-check_id     = iv_check_id.
    rs_result-check_status = iv_status.
    rs_result-completion   = iv_completion.
    rs_result-metric_count = iv_metric_count.
    rs_result-executed_at  = now( ).
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_HCKCHECK / ZR_CD_HCKCATEGORY / ZR_CD_HCKKPI: status per check and category, KPI counts
CLASS ltc_check DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_run,
        old  TYPE zif_cd_ops_types=>ty_run_id VALUE 'D0000000000000000000000000000001',
        last TYPE zif_cd_ops_types=>ty_run_id VALUE 'D0000000000000000000000000000002',
        test TYPE zif_cd_ops_types=>ty_run_id VALUE 'D0000000000000000000000000000003',
      END OF gc_run.
    CONSTANTS:
      BEGIN OF gc_check,
        red      TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_RECON_GAP',
        amber    TYPE zif_cd_hck_types=>ty_check_id VALUE 'B_JOB_RUNTIME',
        green    TYPE zif_cd_hck_types=>ty_check_id VALUE 'C_OVERDUE_EXC',
        warmup   TYPE zif_cd_hck_types=>ty_check_id VALUE 'D_DRIFT',
        none     TYPE zif_cd_hck_types=>ty_check_id VALUE 'E_TECH_SYS',
        inactive TYPE zif_cd_hck_types=>ty_check_id VALUE 'E_INACTIVE',
      END OF gc_check.
    CONSTANTS:
      BEGIN OF gc_status,
        red       TYPE c LENGTH 10 VALUE 'RED',
        amber     TYPE c LENGTH 10 VALUE 'AMBER',
        green     TYPE c LENGTH 10 VALUE 'GREEN',
        warmup    TYPE c LENGTH 10 VALUE 'WARMUP',
        no_result TYPE c LENGTH 10 VALUE 'NO_RESULT',
        grey      TYPE c LENGTH 10 VALUE 'GREY',
      END OF gc_status.
    CONSTANTS gc_dim1 TYPE c LENGTH 4 VALUE 'US01'.
    CONSTANTS gc_active_checks TYPE i VALUE 5.
    CONSTANTS gc_categories TYPE i VALUE 5.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS status_of_every_check FOR TESTING.
    METHODS old_run_finding_stays_open FOR TESTING.
    METHODS category_takes_worst_check FOR TESTING.
    METHODS kpi_counts_open_exceptions FOR TESTING.

    METHODS status_of
      IMPORTING
        iv_check_id      TYPE zif_cd_hck_types=>ty_check_id
      RETURNING
        VALUE(rv_status) TYPE string.
ENDCLASS.


CLASS ltc_check IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZR_CD_HCKCHECK' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_HCKCATEGORY' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_HCKKPI' i_select_base_dependencies = abap_true ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_defs TYPE STANDARD TABLE OF zcd_hck_def WITH EMPTY KEY.
    DATA lt_runs TYPE STANDARD TABLE OF zcd_ops_run WITH EMPTY KEY.
    DATA lt_findings TYPE STANDARD TABLE OF zcd_ops_finding WITH EMPTY KEY.
    DATA lt_metrics TYPE STANDARD TABLE OF zcd_hck_metric WITH EMPTY KEY.
    DATA lt_results TYPE STANDARD TABLE OF zcd_hck_result WITH EMPTY KEY.

    go_env->clear_doubles( ).
    INSERT ltd_rows=>check( iv_check_id = gc_check-red iv_category = zif_cd_hck_types=>gc_category-financial )
           INTO TABLE lt_defs.
    INSERT ltd_rows=>check( iv_check_id = gc_check-amber iv_category = zif_cd_hck_types=>gc_category-mass_run )
           INTO TABLE lt_defs.
    INSERT ltd_rows=>check( iv_check_id = gc_check-green iv_category = zif_cd_hck_types=>gc_category-exceptions )
           INTO TABLE lt_defs.
    INSERT ltd_rows=>check( iv_check_id = gc_check-warmup iv_category = zif_cd_hck_types=>gc_category-config )
           INTO TABLE lt_defs.
    INSERT ltd_rows=>check( iv_check_id = gc_check-none iv_category = zif_cd_hck_types=>gc_category-technical )
           INTO TABLE lt_defs.
    INSERT ltd_rows=>check( iv_check_id = gc_check-inactive iv_category = zif_cd_hck_types=>gc_category-technical
                            iv_active   = abap_false ) INTO TABLE lt_defs.

    DATA(ls_last) = ltd_rows=>run( iv_run_id   = gc_run-last
                                   iv_status   = zif_cd_ops_types=>gc_run_status-error
                                   iv_ended_at = ltd_rows=>seconds_ago( 60 ) ).
    ls_last-rag           = zif_cd_ops_types=>gc_rag-red.
    ls_last-total_items   = gc_active_checks.
    ls_last-passed_items  = 1.
    ls_last-warning_items = 1.
    ls_last-failed_items  = 1.
    INSERT ls_last INTO TABLE lt_runs.
    INSERT ltd_rows=>run( iv_run_id   = gc_run-old
                          iv_status   = zif_cd_ops_types=>gc_run_status-success
                          iv_ended_at = ltd_rows=>seconds_ago( 3600 ) ) INTO TABLE lt_runs.
    INSERT ltd_rows=>run( iv_run_id    = gc_run-test
                          iv_status    = zif_cd_ops_types=>gc_run_status-success
                          iv_ended_at  = ltd_rows=>now( )
                          iv_test_mode = abap_true ) INTO TABLE lt_runs.

    INSERT ltd_rows=>finding( iv_run_id   = gc_run-last iv_finding_no = 1
                              iv_check_id = gc_check-red iv_category = zif_cd_hck_types=>gc_category-financial
                              iv_code     = zif_cd_hck_types=>gc_code-threshold_red
                              iv_severity = zif_cd_ops_types=>gc_severity-error ) INTO TABLE lt_findings.
    INSERT ltd_rows=>finding( iv_run_id   = gc_run-last iv_finding_no = 2
                              iv_check_id = gc_check-amber iv_category = zif_cd_hck_types=>gc_category-mass_run
                              iv_code     = zif_cd_hck_types=>gc_code-baseline_outlier
                              iv_severity = zif_cd_ops_types=>gc_severity-warning ) INTO TABLE lt_findings.
    INSERT ltd_rows=>finding( iv_run_id      = gc_run-last iv_finding_no = 3
                              iv_check_id    = gc_check-warmup iv_category = zif_cd_hck_types=>gc_category-config
                              iv_code        = zif_cd_hck_types=>gc_code-baseline_warmup
                              iv_severity    = zif_cd_ops_types=>gc_severity-info
                              iv_disposition = zif_cd_ops_types=>gc_disposition-information ) INTO TABLE lt_findings.
    " An exception of the older run on the green check: still open, not the check's status today
    INSERT ltd_rows=>finding( iv_run_id   = gc_run-old iv_finding_no = 1
                              iv_check_id = gc_check-green iv_category = zif_cd_hck_types=>gc_category-exceptions
                              iv_code     = zif_cd_hck_types=>gc_code-threshold_red
                              iv_severity = zif_cd_ops_types=>gc_severity-error ) INTO TABLE lt_findings.
    INSERT ltd_rows=>metric( iv_run_id = gc_run-last iv_check_id = gc_check-green iv_dim1 = gc_dim1
                             iv_measured_at = ltd_rows=>seconds_ago( 60 ) ) INTO TABLE lt_metrics.

    " The verdicts the engine stored for the last run (no row for the check that did not run)
    INSERT ltd_rows=>result( iv_run_id = gc_run-last iv_check_id = gc_check-red
                             iv_status = zif_cd_hck_types=>gc_check_status-red ) INTO TABLE lt_results.
    INSERT ltd_rows=>result( iv_run_id = gc_run-last iv_check_id = gc_check-amber
                             iv_status = zif_cd_hck_types=>gc_check_status-amber ) INTO TABLE lt_results.
    INSERT ltd_rows=>result( iv_run_id = gc_run-last iv_check_id = gc_check-green iv_metric_count = 1
                             iv_status = zif_cd_hck_types=>gc_check_status-green ) INTO TABLE lt_results.
    INSERT ltd_rows=>result( iv_run_id = gc_run-last iv_check_id = gc_check-warmup
                             iv_status = zif_cd_hck_types=>gc_check_status-warmup ) INTO TABLE lt_results.

    go_env->insert_test_data( i_data = lt_defs ).
    go_env->insert_test_data( i_data = lt_runs ).
    go_env->insert_test_data( i_data = lt_findings ).
    go_env->insert_test_data( i_data = lt_metrics ).
    go_env->insert_test_data( i_data = lt_results ).
  ENDMETHOD.


  METHOD status_of.
    SELECT SINGLE checkstatus FROM zr_cd_hckcheck WHERE checkid = @iv_check_id INTO @DATA(lv_status).
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = |Check { iv_check_id } must be on the dashboard| ).
    rv_status = condense( lv_status ).
  ENDMETHOD.


  METHOD status_of_every_check.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = status_of( gc_check-red ) exp = gc_status-red
                                            msg = 'An E finding of the last run makes the check RED' ).
        cl_abap_unit_assert=>assert_equals( act = status_of( gc_check-amber ) exp = gc_status-amber
                                            msg = 'A W finding of the last run makes the check AMBER' ).
        cl_abap_unit_assert=>assert_equals( act = status_of( gc_check-green ) exp = gc_status-green
                                            msg = 'Stored verdict GREEN: GREEN' ).
        cl_abap_unit_assert=>assert_equals( act = status_of( gc_check-warmup ) exp = gc_status-warmup
                                            msg = 'Stored verdict WARMUP: WARMUP, never GREEN' ).
        cl_abap_unit_assert=>assert_equals( act = status_of( gc_check-none ) exp = gc_status-no_result
                                            msg = 'No verdict row in the run: NO_RESULT' ).
        SELECT COUNT(*) FROM zr_cd_hckcheck WHERE checkid = @gc_check-inactive INTO @DATA(lv_inactive).
        cl_abap_unit_assert=>assert_equals( act = lv_inactive exp = 0 msg = 'Inactive checks are not listed' ).
        SELECT SINGLE asofrunid FROM zr_cd_hckcheck WHERE checkid = @gc_check-red INTO @DATA(lv_run).
        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The check must be listed' ).
        cl_abap_unit_assert=>assert_equals( act = lv_run exp = gc_run-last
                                            msg = 'Status is from the last completed run, never the test run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD old_run_finding_stays_open.
    TRY.
        SELECT SINGLE checkstatus, openfindingcount, openredcount FROM zr_cd_hckcheck
          WHERE checkid = @gc_check-green INTO @DATA(ls_row).

        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The check must be listed' ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_row-checkstatus ) exp = gc_status-green
                                            msg = 'A finding of an older run does not set today''s status' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-openfindingcount exp = 1
                                            msg = 'The open exception of the older run is counted' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-openredcount exp = 1 msg = 'It is a red exception' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD category_takes_worst_check.
    TRY.
        SELECT category, categorystatus, checkcount FROM zr_cd_hckcategory ORDER BY category
          INTO TABLE @DATA(lt_cats).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_cats ) exp = gc_categories
                                            msg = 'One scorecard row per category with active checks' ).
        cl_abap_unit_assert=>assert_equals(
          act = condense( VALUE #( lt_cats[ category = zif_cd_hck_types=>gc_category-financial ]-categorystatus OPTIONAL ) )
          exp = gc_status-red msg = 'Category A has a red check' ).
        cl_abap_unit_assert=>assert_equals(
          act = condense( VALUE #( lt_cats[ category = zif_cd_hck_types=>gc_category-exceptions ]-categorystatus OPTIONAL ) )
          exp = gc_status-green msg = 'Category C has a green check only' ).
        cl_abap_unit_assert=>assert_equals(
          act = condense( VALUE #( lt_cats[ category = zif_cd_hck_types=>gc_category-config ]-categorystatus OPTIONAL ) )
          exp = gc_status-grey msg = 'A category with no verdict (warm-up only) is GREY' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( lt_cats[ category = zif_cd_hck_types=>gc_category-technical ]-checkcount OPTIONAL )
          exp = 1 msg = 'The inactive check of category E is not counted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD kpi_counts_open_exceptions.
    TRY.
        SELECT runid, runrag, redcheckcount, openfindingcount, openredcount, openambercount, isstale
          FROM zr_cd_hckkpi ORDER BY runid INTO TABLE @DATA(lt_kpi).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_kpi ) exp = 1 msg = 'The KPI entity has one row' ).
        DATA(ls_kpi) = VALUE #( lt_kpi[ 1 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-runid exp = gc_run-last msg = 'KPI of the last completed run' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-runrag exp = zif_cd_ops_types=>gc_rag-red
                                            msg = 'The stored overall RAG is shown' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-redcheckcount exp = 1 msg = 'Run counter of red checks' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-openfindingcount exp = 3
                                            msg = 'Open: two of the last run, one of the older run' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-openredcount exp = 2 msg = 'Two open red exceptions' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-openambercount exp = 1 msg = 'One open amber exception' ).
        cl_abap_unit_assert=>assert_equals( act = ls_kpi-isstale exp = abap_false msg = 'A fresh run is not stale' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_HCKCHECK: the persisted verdict decides (design review 4: dashboard = report)
CLASS ltc_verdict DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_run TYPE zif_cd_ops_types=>ty_run_id VALUE 'D0000000000000000000000000000021'.
    CONSTANTS:
      BEGIN OF gc_check,
        no_metric TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_NO_METRIC',
        warm_lim  TYPE zif_cd_hck_types=>ty_check_id VALUE 'B_WARM_FIXED',
        failed    TYPE zif_cd_hck_types=>ty_check_id VALUE 'C_FAILED',
        skipped   TYPE zif_cd_hck_types=>ty_check_id VALUE 'D_SKIPPED',
      END OF gc_check.
    CONSTANTS gc_scope TYPE zif_cd_ops_types=>ty_message VALUE 'Variant MORNING_A, categories I EQ A, priorities *, checks: *'.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS green_without_metric_green FOR TESTING.
    METHODS filtered_run_shows_scope   FOR TESTING.
    METHODS warmup_fixed_limit_report  FOR TESTING.
    METHODS failed_check_never_green   FOR TESTING.

    METHODS row_of
      IMPORTING
        iv_check_id   TYPE zif_cd_hck_types=>ty_check_id
      RETURNING
        VALUE(rs_row) TYPE zr_cd_hckcheck.
ENDCLASS.


CLASS ltc_verdict IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CD_HCKCHECK' i_select_base_dependencies = abap_true ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_defs TYPE STANDARD TABLE OF zcd_hck_def WITH EMPTY KEY.
    DATA lt_runs TYPE STANDARD TABLE OF zcd_ops_run WITH EMPTY KEY.
    DATA lt_results TYPE STANDARD TABLE OF zcd_hck_result WITH EMPTY KEY.
    DATA lt_findings TYPE STANDARD TABLE OF zcd_ops_finding WITH EMPTY KEY.
    go_env->clear_doubles( ).
    INSERT ltd_rows=>check( iv_check_id = gc_check-no_metric iv_category = zif_cd_hck_types=>gc_category-financial )
           INTO TABLE lt_defs.
    INSERT ltd_rows=>check( iv_check_id = gc_check-warm_lim iv_category = zif_cd_hck_types=>gc_category-mass_run )
           INTO TABLE lt_defs.
    INSERT ltd_rows=>check( iv_check_id = gc_check-failed iv_category = zif_cd_hck_types=>gc_category-exceptions )
           INTO TABLE lt_defs.
    INSERT ltd_rows=>check( iv_check_id = gc_check-skipped iv_category = zif_cd_hck_types=>gc_category-config )
           INTO TABLE lt_defs.
    INSERT ltd_rows=>run( iv_run_id   = gc_run
                          iv_status   = zif_cd_ops_types=>gc_run_status-error
                          iv_ended_at = ltd_rows=>seconds_ago( 60 ) ) INTO TABLE lt_runs.
    DATA(ls_result) = ltd_rows=>result( iv_run_id = gc_run iv_check_id = gc_check-no_metric
                                        iv_status = zif_cd_hck_types=>gc_check_status-green ).
    ls_result-run_scope = gc_scope.
    INSERT ls_result INTO TABLE lt_results.
    ls_result = ltd_rows=>result( iv_run_id = gc_run iv_check_id = gc_check-warm_lim iv_metric_count = 1
                                  iv_status = zif_cd_hck_types=>gc_check_status-green ).
    ls_result-baseline_mode = zif_cd_hck_types=>gc_baseline-zscore.
    ls_result-run_scope     = gc_scope.
    INSERT ls_result INTO TABLE lt_results.
    ls_result = ltd_rows=>result( iv_run_id     = gc_run iv_check_id = gc_check-failed
                                  iv_status     = zif_cd_hck_types=>gc_check_status-failed
                                  iv_completion = zif_cd_hck_types=>gc_completion-failed ).
    ls_result-run_scope = gc_scope.
    INSERT ls_result INTO TABLE lt_results.
    ls_result = ltd_rows=>result( iv_run_id     = gc_run iv_check_id = gc_check-skipped
                                  iv_status     = zif_cd_hck_types=>gc_check_status-skipped
                                  iv_completion = zif_cd_hck_types=>gc_completion-skipped ).
    ls_result-run_scope = gc_scope.
    INSERT ls_result INTO TABLE lt_results.
    " The warm-up information next to the fixed limit (the former inference made this WARMUP)
    INSERT ltd_rows=>finding( iv_run_id      = gc_run iv_finding_no = 1
                              iv_check_id    = gc_check-warm_lim iv_category = zif_cd_hck_types=>gc_category-mass_run
                              iv_code        = zif_cd_hck_types=>gc_code-baseline_warmup
                              iv_severity    = zif_cd_ops_types=>gc_severity-info
                              iv_disposition = zif_cd_ops_types=>gc_disposition-information ) INTO TABLE lt_findings.
    " The plug-in error of the failed check
    INSERT ltd_rows=>finding( iv_run_id   = gc_run iv_finding_no = 2
                              iv_check_id = gc_check-failed iv_category = zif_cd_hck_types=>gc_category-exceptions
                              iv_code     = zif_cd_hck_types=>gc_code-plugin_error
                              iv_severity = zif_cd_ops_types=>gc_severity-error ) INTO TABLE lt_findings.
    go_env->insert_test_data( i_data = lt_defs ).
    go_env->insert_test_data( i_data = lt_runs ).
    go_env->insert_test_data( i_data = lt_results ).
    go_env->insert_test_data( i_data = lt_findings ).
  ENDMETHOD.


  METHOD row_of.
    SELECT SINGLE checkid, checkstatus, statuscriticality, checkcompletion, runscope, baselinemode,
                  metriccount, greencheckcount, failedcheckcount
      FROM zr_cd_hckcheck
      WHERE checkid = @iv_check_id
      INTO CORRESPONDING FIELDS OF @rs_row.
    cl_abap_unit_assert=>assert_subrc( exp = 0 msg = |Check { iv_check_id } must be on the dashboard| ).
  ENDMETHOD.


  " Acceptance: a check that ran green without any metric row is GREEN, not grey / no result
  METHOD green_without_metric_green.
    TRY.
        DATA(ls_row) = row_of( gc_check-no_metric ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_row-checkstatus ) exp = zif_cd_hck_types=>gc_check_status-green
                                            msg = 'GREEN without metric' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-metriccount exp = 0 msg = 'No metric row' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-greencheckcount exp = 1 msg = 'Counted green' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Acceptance: a filtered run shows its scope; the check it left out is SKIPPED
  METHOD filtered_run_shows_scope.
    TRY.
        DATA(ls_row) = row_of( gc_check-skipped ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_row-checkstatus )
                                            exp = zif_cd_hck_types=>gc_check_status-skipped
                                            msg = 'Left out by the scope: SKIPPED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-runscope exp = gc_scope msg = 'Scope shown' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-greencheckcount exp = 0 msg = 'Not green' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Acceptance: a warm-up next to a fixed limit is GREEN on the dashboard as in the report
  METHOD warmup_fixed_limit_report.
    TRY.
        DATA(ls_row) = row_of( gc_check-warm_lim ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_row-checkstatus ) exp = zif_cd_hck_types=>gc_check_status-green
                                            msg = 'Dashboard = report: GREEN' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-baselinemode exp = zif_cd_hck_types=>gc_baseline-zscore
                                            msg = 'Baseline mode used is shown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Acceptance: a failed check is FAILED (red), never green
  METHOD failed_check_never_green.
    TRY.
        DATA(ls_row) = row_of( gc_check-failed ).
        cl_abap_unit_assert=>assert_equals( act = condense( ls_row-checkstatus ) exp = zif_cd_hck_types=>gc_check_status-failed
                                            msg = 'FAILED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-checkcompletion exp = zif_cd_hck_types=>gc_completion-failed
                                            msg = 'Completion FAILED' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-statuscriticality exp = 1 msg = 'Red criticality' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-greencheckcount exp = 0 msg = 'Never green' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-failedcheckcount exp = 1 msg = 'Counted failed' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! ZR_CD_HCKASOF / ZR_CD_HCKMETRIC: stale without a completed run, 31-day metric history
CLASS ltc_history DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_run TYPE zif_cd_ops_types=>ty_run_id VALUE 'D0000000000000000000000000000011'.
    CONSTANTS gc_run_old TYPE zif_cd_ops_types=>ty_run_id VALUE 'D0000000000000000000000000000012'.
    CONSTANTS gc_check TYPE zif_cd_hck_types=>ty_check_id VALUE 'B_VOLUME'.
    CONSTANTS gc_dim1 TYPE c LENGTH 4 VALUE 'PCLM'.
    CONSTANTS gc_series_1 TYPE c LENGTH 4 VALUE 'ACH'.
    CONSTANTS gc_series_2 TYPE c LENGTH 4 VALUE 'CHK'.
    "! 40 days: outside the 31-day window
    CONSTANTS gc_seconds_old TYPE i VALUE 3456000.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS stale_without_completed_run FOR TESTING.
    METHODS moncfg_threshold_applies FOR TESTING.
    METHODS history_keeps_dim2_series FOR TESTING.
ENDCLASS.


CLASS ltc_history IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create_for_multiple_cds(
               i_for_entities = VALUE #( ( i_for_entity = 'ZR_CD_HCKASOF' i_select_base_dependencies = abap_true )
                                         ( i_for_entity = 'ZR_CD_HCKMETRIC' i_select_base_dependencies = abap_true ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
  ENDMETHOD.


  " Rule: ZCD_OPS_MONCFG decides (60 minutes): a report two hours old is stale, although the
  " delivered 26 hours would keep it fresh
  METHOD moncfg_threshold_applies.
    CONSTANTS lc_minutes TYPE i VALUE 60.
    CONSTANTS lc_two_hours TYPE i VALUE 7200.
    DATA lt_cfg TYPE STANDARD TABLE OF zcd_ops_moncfg WITH EMPTY KEY.
    DATA ls_cfg TYPE zcd_ops_moncfg.
    TRY.
        DATA lt_runs TYPE STANDARD TABLE OF zcd_ops_run WITH EMPTY KEY.
        INSERT ltd_rows=>run( iv_run_id   = gc_run
                              iv_status   = zif_cd_ops_types=>gc_run_status-success
                              iv_ended_at = ltd_rows=>seconds_ago( lc_two_hours ) ) INTO TABLE lt_runs.
        go_env->insert_test_data( i_data = lt_runs ).
        ls_cfg-pe_area         = zif_cd_ops_types=>gc_pe_area-health_check.
        ls_cfg-stale_after_min = lc_minutes.
        INSERT ls_cfg INTO TABLE lt_cfg.
        go_env->insert_test_data( i_data = lt_cfg ).

        SELECT SINGLE isstale, staleafterminutes FROM zr_cd_hckasof INTO @DATA(ls_row).

        cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'The as-of row must exist' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-isstale exp = abap_true
                                            msg = 'Beyond the configured 60 minutes: stale' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-staleafterminutes exp = lc_minutes
                                            msg = 'The configured threshold is shown' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD stale_without_completed_run.
    TRY.
        DATA lt_runs TYPE STANDARD TABLE OF zcd_ops_run WITH EMPTY KEY.
        INSERT ltd_rows=>run( iv_run_id   = gc_run
                              iv_status   = zif_cd_ops_types=>gc_run_status-aborted
                              iv_ended_at = ltd_rows=>now( ) ) INTO TABLE lt_runs.
        INSERT ltd_rows=>run( iv_run_id    = gc_run_old
                              iv_status    = zif_cd_ops_types=>gc_run_status-success
                              iv_ended_at  = ltd_rows=>now( )
                              iv_test_mode = abap_true ) INTO TABLE lt_runs.
        go_env->insert_test_data( i_data = lt_runs ).

        SELECT asofat, isstale FROM zr_cd_hckasof ORDER BY asofat INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One row also without a run' ).
        DATA(ls_row) = VALUE #( lt_rows[ 1 ] OPTIONAL ).
        cl_abap_unit_assert=>assert_initial( act = ls_row-asofat
                                             msg = 'Aborted (lock refused) and test runs are not a completed report' ).
        cl_abap_unit_assert=>assert_equals( act = ls_row-isstale exp = abap_true
                                            msg = 'No completed morning report is stale, never green' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD history_keeps_dim2_series.
    TRY.
        DATA lt_metrics TYPE STANDARD TABLE OF zcd_hck_metric WITH EMPTY KEY.
        INSERT ltd_rows=>metric( iv_run_id = gc_run iv_check_id = gc_check iv_dim1 = gc_dim1 iv_dim2 = gc_series_1
                                 iv_measured_at = ltd_rows=>now( ) ) INTO TABLE lt_metrics.
        INSERT ltd_rows=>metric( iv_run_id = gc_run iv_check_id = gc_check iv_dim1 = gc_dim1 iv_dim2 = gc_series_2
                                 iv_measured_at = ltd_rows=>now( ) ) INTO TABLE lt_metrics.
        INSERT ltd_rows=>metric( iv_run_id = gc_run_old iv_check_id = gc_check iv_dim1 = gc_dim1
                                 iv_dim2 = gc_series_1
                                 iv_measured_at = ltd_rows=>seconds_ago( gc_seconds_old ) ) INTO TABLE lt_metrics.
        go_env->insert_test_data( i_data = lt_metrics ).

        SELECT runid, dimension2 FROM zr_cd_hckmetric ORDER BY dimension2 INTO TABLE @DATA(lt_rows).

        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2
                                            msg = 'Two series of the recent run; the 40-day-old row is outside' ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( lt_rows[ dimension2 = gc_series_2 ] ) )
                                          msg = 'Every DIM2 series is a row of its own' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( lt_rows[ runid = gc_run_old ] ) )
                                           msg = 'Metric rows older than 31 days are not read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
