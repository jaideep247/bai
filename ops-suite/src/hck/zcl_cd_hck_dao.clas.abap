*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_dao.clas.abap
*& Purpose:
*& All SQL of the health check payment engine area: customizing, metric history, drift
*& baselines and the technical reads (TBTCO, BALHDR, SNAP, VBHDR, locks).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | ATC-equivalent fixes: ORDER BY, CHECK before FOR ALL ENTRIES, sy-subrc, keyless SORT.
*& 2026-11-06 | get_suppressions: active suppressions of the day (design 6.3).
*& 2026-11-06 | select_values: validated value queries (known-table checks).
*& 2026-11-06 | Webhook key peArea (rename regression fixed); column names in comments.
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Metric history by distinct completed runs, as-of bound (audit A58).
*& 2026-11-06 | Job runs with first-step program/variant; unresolved jobs regardless of date (audit A42, A44).
*& 2026-11-06 | G/L transfer gaps by AWTYP, company code, unreversed document; uncapped count (audit A43).
*& 2026-11-06 | Aggregate and value queries rebuilt and re-validated at the SQL boundary (audit A56).
*& 2026-11-06 | Drift hash over canonical typed fields, version 2; cursor closed on all paths (audit A57).
*& 2026-11-06 | Metric kind (blank = volume) and weight persisted (audit A88).
*& 2026-11-06 | Baseline history filtered by DIM2 as well (audit A101).
*& 2026-11-06 | Expected groups read from ZCD_HCK_AGGGRP; row cap on the interface (audit A103).
*& 2026-11-06 | Performance fix 7: metric history - latest point per run by ROW_NUMBER( ) in a CTE, newest runs
*&            | first, UP TO iv_max_rows (was up to 5000 points per series filtered in ABAP).
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Modern-syntax sweep: string templates, alert tables ZCA_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-06 | PCRE patterns: ABAP SQL LIKE_REGEXPR is not used (not parsed by the offline lint; HANA regex
*&              cannot use an index). Job names: distinct names of the window / open statuses, PCRE filter
*&              in ABAP, then the runs of the matched names (FOR ALL ENTRIES). BALHDR counters grouped per day, filtered
*&              in ABAP. Cycle ids filtered in ABAP (customizing rows). Performance_Review.md.
*& 2026-11-07 | Row caps from parameters HCK_MAX_JOB_ROWS / _JOB_NAMES / _AGG_ROWS (ZCL_CD_HCK_PARAM, cut to the
*&            | hard ceilings); cap reached fails as before.
*& 2026-11-07 | get_monitor_cfg: ZCD_OPS_MONCFG (stale threshold per area, shared with the dashboards).
*& 2026-11-07 | save_results: verdict of each check per run (ZCD_HCK_RESULT, design review).
*& 2026-11-08 | Table consolidation: approved tables (HCK / READ) and drift tables (HCK / DRIFT) read from
*&            | ZCD_OPS_TABWL (was ZCD_HCK_TABWL, ZCD_HCK_DRIFT).
*& 2026-11-08 | Table consolidation: get_monitor_cfg (ZCD_OPS_MONCFG) removed - the stale threshold per area
*&            | is the core parameter MON_STALE_AFTER_MIN_<area>.
*& 2026-11-08 | Table consolidation: expected groups are the field EXPECTED_GROUPS of ZCD_HCK_AGG (read with
*&            | the definitions); get_agg_groups (ZCD_HCK_AGGGRP) removed.
*& 2026-11-10 | A caught cast error is kept as PREVIOUS of the raised error (exception chain).
*& 2026-11-10 | get_table_fields checks S_TABU_NAM 03 (ZIF_CA_OPS_AUTH=>MAY_READ_TABLE) first: every dynamic read
*&            | (aggregate, values, queues, reference rows, drift hash) describes its table there - 813.
*& 2026-11-10 | save_metrics: company code of the metric (ZCD_HCK_METRIC-BUKRS, company-code isolation).
*& 2026-11-10 | get_overdue_exceptions per area and company code (company-code isolation); AREA read AS PE_AREA (the
*&            | target component - CORRESPONDING left the area blank before).
*& 2026-11-11 | get_metric_history with a day list: the latest point of each listed day (seasonal baseline).
*&            | get_thresholds reads SEASON.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - DAO (all SQL and system reads)</p>
"! Every standard-table field not confirmed in DEVELOPMENT_STANDARDS is
"! isolated in exactly one method and marked "VERIFY-DDIC:. Dynamic SQL is
"! only executed for queries built by ZCL_CD_HCK_AGG_QUERY (whitelisted
"! table, DDIC-checked names, quoted literals) or for DDIC field lists.
CLASS zcl_cd_hck_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao.

  PRIVATE SECTION.
    "! Hash of a table's content for configuration drift
    CONSTANTS gc_hash_algorithm TYPE string VALUE `SHA256`.
    "! Query kind named in message 308 for a value (not aggregate) query
    CONSTANTS gc_query_kind_values TYPE string VALUE `VALUES`.
    CONSTANTS gc_first_step TYPE i VALUE 1.
    CONSTANTS gc_hash_package TYPE i VALUE 1000.
    "! Metric points scanned to find the last N distinct runs (A58)
    CONSTANTS gc_max_timestamp TYPE timestampl VALUE '99991231235959.9999999'.

    "! Table read by the PCRE job-name filter (message 747)
    CONSTANTS gc_table_tbtco TYPE string VALUE `TBTCO`.
    TYPES tt_jobname TYPE STANDARD TABLE OF zif_cd_hck_types=>ty_jobname WITH EMPTY KEY.


    "! Names that match one of the PCRE patterns; raises message 747 when the name read
    "! reached GC_MAX_JOB_NAMES (the selection could be incomplete)
    METHODS matched_jobnames
      IMPORTING
        it_names        TYPE tt_jobname
        it_patterns     TYPE zif_ca_ops_types=>tt_pcre
      RETURNING
        VALUE(rt_names) TYPE tt_jobname
      RAISING
        zcx_ca_ops_error.

    "! Program and variant of the first job step (TBTCP) into the job runs (A42)
    METHODS add_step_program
      CHANGING
        ct_runs TYPE zif_cd_hck_types=>tt_job_run.

    METHODS sha256
      IMPORTING
        iv_data        TYPE string
      RETURNING
        VALUE(rv_hash) TYPE zif_cd_hck_types=>ty_hash
      RAISING
        zcx_ca_ops_error.

ENDCLASS.



CLASS zcl_cd_hck_dao IMPLEMENTATION.

  METHOD zif_cd_hck_dao~get_check_defs.
    SELECT check_id, description, category, class_name, active, seq, priority,
           param1, param2, param3, param4, package_size, timeout_sec
      FROM zcd_hck_def
      WHERE active   = @abap_true
        AND category IN @it_categories
        AND priority IN @it_priorities
        AND check_id IN @it_check_ids
      ORDER BY seq, check_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_defs.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_thresholds.
    SELECT check_id, metric, bukrs, amber, red, higher_is_worse, baseline_mode, z_limit, lookback_runs, season
      FROM zcd_hck_thresh
      WHERE check_id = @iv_check_id
      ORDER BY check_id, metric, bukrs
      INTO CORRESPONDING FIELDS OF TABLE @rt_thresholds.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_agg_defs.
    SELECT check_id, agg_id, description, tabname, agg_func, sum_field, date_field, date_mode,
           age_days_min, group_field, expected_groups, cond1_field, cond1_op, cond1_value, cond2_field,
           cond2_op, cond2_value, cond3_field, cond3_op, cond3_value
      FROM zcd_hck_agg
      WHERE check_id = @iv_check_id
      ORDER BY agg_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_defs.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~is_table_whitelisted.
    DATA(lv_tabname) = to_upper( iv_tabname ).
    " Full key of the approved-table list: HCK reads a whole table (blank field) - 2026-11-08
    SELECT SINGLE active
      FROM zcd_ops_tabwl
      WHERE pe_area    = @zif_cd_ops_types=>gc_pe_area-health_check
        AND purpose    = @zif_cd_ops_types=>gc_tabwl_purpose-read
        AND table_name = @lv_tabname
        AND field_name = @space
      INTO @DATA(lv_active).
    rv_allowed = xsdbool( sy-subrc = 0 AND lv_active = abap_true ).
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_table_fields.
    DATA lo_descr TYPE REF TO cl_abap_typedescr.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    DATA lt_ddic TYPE ddfields.

    DATA(lv_name) = to_upper( condense( CONV string( iv_tabname ) ) ).
    " Every dynamic read of the health check describes its table here first: S_TABU_NAM display
    " of the running user, in addition to the approved-table list (the check reports 813)
    IF zcl_ca_ops_factory=>get_auth( )->may_read_table( lv_name ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e813(zcd_ops) WITH lv_name.
    ENDIF.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = lv_name
      RECEIVING
        p_descr_ref    = lo_descr
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e303(zcd_ops) WITH lv_name.
    ENDIF.
    TRY.
        lo_struct ?= lo_descr.
      CATCH cx_sy_move_cast_error INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e303(zcd_ops) WITH lv_name
          EXPORTING
            previous = lx_error.
    ENDTRY.

    lo_struct->get_ddic_field_list(
      RECEIVING
        p_field_list = lt_ddic
      EXCEPTIONS
        not_found    = 1
        no_ddic_type = 2
        OTHERS       = 3 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e303(zcd_ops) WITH lv_name.
    ENDIF.
    LOOP AT lt_ddic ASSIGNING FIELD-SYMBOL(<ls_ddic>).
      INSERT VALUE #( fieldname = <ls_ddic>-fieldname
                      type_kind = <ls_ddic>-inttype
                      keyflag   = <ls_ddic>-keyflag ) INTO TABLE rt_fields.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~aggregate.
    DATA lt_fields TYPE zif_cd_hck_types=>tt_field.
    " A56: the SQL boundary trusts no caller-built string. The query is rebuilt from its
    " definition - whitelist, DDIC field names, quoted literals - and only that runs.
    DATA(lv_whitelisted) = zif_cd_hck_dao~is_table_whitelisted( is_query-def-tabname ).
    IF lv_whitelisted = abap_true.
      lt_fields = zif_cd_hck_dao~get_table_fields( is_query-def-tabname ).
    ENDIF.
    DATA(ls_query) = zcl_cd_hck_agg_query=>build( is_def         = is_query-def
                                                  it_fields      = lt_fields
                                                  iv_whitelisted = lv_whitelisted
                                                  iv_ref_date    = is_query-ref_date ).
    DATA(lv_select) = COND string( WHEN ls_query-group_field IS NOT INITIAL
                                   THEN |{ ls_query-group_field } AS group_value, | ).
    lv_select = |{ lv_select }COUNT(*) AS row_count|.
    IF ls_query-agg_func = zif_cd_hck_types=>gc_agg_func-sum.
      lv_select = |{ lv_select }, SUM( { ls_query-sum_field } ) AS total|.
    ENDIF.
    DATA(lv_from)  = CONV string( ls_query-tabname ).
    DATA(lv_where) = ls_query-where_clause.
    DATA(lv_group) = CONV string( ls_query-group_field ).

    DATA(lv_max_rows) = zcl_cd_hck_param=>agg_rows_cap( ).
    TRY.
        IF lv_group IS INITIAL.
          " Aggregate without GROUP BY returns exactly one row: order is irrelevant
          SELECT (lv_select)
            FROM (lv_from)
            WHERE (lv_where)
            INTO CORRESPONDING FIELDS OF TABLE @rt_rows.             "#EC CI_NOORDER
        ELSE.
          SELECT (lv_select)
            FROM (lv_from)
            WHERE (lv_where)
            GROUP BY (lv_group)
            ORDER BY (lv_group)
            INTO CORRESPONDING FIELDS OF TABLE @rt_rows
            UP TO @lv_max_rows ROWS.
        ENDIF.
      CATCH cx_sy_dynamic_osql_error INTO DATA(lx_sql).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e308(zcd_ops) WITH ls_query-tabname ls_query-agg_id
          EXPORTING
            previous = lx_sql.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_metric_history.
    DATA lv_as_of TYPE timestampl.
    DATA lt_days TYPE RANGE OF zif_cd_hck_types=>ty_dim.
    CHECK iv_max_rows > 0.
    lv_as_of = COND #( WHEN iv_as_of IS INITIAL THEN gc_max_timestamp ELSE iv_as_of ).
    IF it_days IS NOT INITIAL.
      lt_days = VALUE #( FOR lv_day IN it_days ( sign   = zif_ca_ops_types=>gc_range-sign_include
                                                 option = zif_ca_ops_types=>gc_range-option_equal
                                                 low    = lv_day ) ).
      " index ZCD_HCK_METRIC~HST (CHECK_ID, METRIC, DIM1, DIM2, MEASURED_AT): one point per listed day - the
      " latest of the completed, non-test runs that measured it (a day backfilled by several runs counts once)
      WITH +points AS (
        SELECT m~dim2, m~value, m~measured_at,
               row_number( ) OVER( PARTITION BY m~dim2 ORDER BY m~measured_at DESCENDING ) AS rn
          FROM zcd_hck_metric AS m
            INNER JOIN zca_ops_run AS r ON r~run_id = m~run_id
          WHERE m~check_id    = @iv_check_id
            AND m~metric      = @iv_metric
            AND m~dim1        = @iv_dim1
            AND m~dim2        IN @lt_days
            AND m~measured_at <= @lv_as_of
            AND r~test_mode   = @abap_false
            AND r~status IN ( @zif_ca_ops_types=>gc_run_status-success,
                              @zif_ca_ops_types=>gc_run_status-warning,
                              @zif_ca_ops_types=>gc_run_status-error ) )
      SELECT dim2, value
        FROM +points
        WHERE rn = 1
        ORDER BY dim2 DESCENDING
        INTO TABLE @DATA(lt_day_points)
        UP TO @iv_max_rows ROWS.
      LOOP AT lt_day_points ASSIGNING FIELD-SYMBOL(<ls_day_point>).
        INSERT <ls_day_point>-value INTO TABLE rt_values.
      ENDLOOP.
      RETURN.
    ENDIF.
    " index ZCD_HCK_METRIC~HST: CHECK_ID, METRIC, DIM1, DIM2, MEASURED_AT. One series = the
    " persisted grain incl. DIM2 (A101); several points of one run (job instances, backfilled
    " days) count as one run: its latest point (A58).
    " Fix 7: the database keeps the latest point per run (ROW_NUMBER = 1) and returns only the
    " iv_max_rows newest runs - same values and order as the former ABAP de-duplication
    WITH +points AS (
      SELECT m~run_id, m~value, m~measured_at,
             row_number( ) OVER( PARTITION BY m~run_id ORDER BY m~measured_at DESCENDING ) AS rn
        FROM zcd_hck_metric AS m
          INNER JOIN zca_ops_run AS r ON r~run_id = m~run_id
        WHERE m~check_id    = @iv_check_id
          AND m~metric      = @iv_metric
          AND m~dim1        = @iv_dim1
          AND m~dim2        = @iv_dim2
          AND m~measured_at <= @lv_as_of
          AND r~test_mode   = @abap_false
          AND r~status IN ( @zif_ca_ops_types=>gc_run_status-success,
                            @zif_ca_ops_types=>gc_run_status-warning,
                            @zif_ca_ops_types=>gc_run_status-error ) )
    SELECT run_id, value, measured_at
      FROM +points
      WHERE rn = 1
      ORDER BY measured_at DESCENDING, run_id DESCENDING
      INTO TABLE @DATA(lt_points)
      UP TO @iv_max_rows ROWS.
    LOOP AT lt_points ASSIGNING FIELD-SYMBOL(<ls_point>).
      INSERT <ls_point>-value INTO TABLE rt_values.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~save_results.
    DATA lt_db TYPE STANDARD TABLE OF zcd_hck_result WITH EMPTY KEY.
    IF it_results IS INITIAL.
      RETURN.
    ENDIF.
    lt_db = CORRESPONDING #( it_results ).
    MODIFY zcd_hck_result FROM TABLE @lt_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH 'ZCD_HCK_RESULT'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~save_metrics.
    DATA lt_db TYPE STANDARD TABLE OF zcd_hck_metric WITH EMPTY KEY.
    DATA ls_db TYPE zcd_hck_metric.

    IF it_metrics IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT it_metrics ASSIGNING FIELD-SYMBOL(<ls_metric>).
      CLEAR ls_db.
      ls_db-run_id      = <ls_metric>-run_id.
      ls_db-check_id    = <ls_metric>-check_id.
      ls_db-metric      = <ls_metric>-metric.
      ls_db-dim1        = <ls_metric>-dim1.
      ls_db-dim2        = <ls_metric>-dim2.
      ls_db-value       = <ls_metric>-value.
      ls_db-measured_at = <ls_metric>-measured_at.
      " A88: the analytics aggregate by kind - an unclassified metric is a volume
      ls_db-kind        = COND #( WHEN <ls_metric>-kind IS INITIAL THEN zif_cd_hck_types=>gc_metric_kind-volume
                                  ELSE <ls_metric>-kind ).
      ls_db-weight      = <ls_metric>-weight.
      ls_db-bukrs       = <ls_metric>-bukrs.
      INSERT ls_db INTO TABLE lt_db.
    ENDLOOP.
    " a duplicate key inside one run is a repeated measurement: keep the first
    INSERT zcd_hck_metric FROM TABLE @lt_db ACCEPTING DUPLICATE KEYS.
    IF sy-subrc <> 0 AND sy-dbcnt = 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH 'ZCD_HCK_METRIC'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_drift_tables.
    SELECT table_name AS tabname, description
      FROM zcd_ops_tabwl
      WHERE pe_area    = @zif_cd_ops_types=>gc_pe_area-health_check
        AND purpose    = @zif_cd_ops_types=>gc_tabwl_purpose-drift
        AND field_name = @space
        AND active     = @abap_true
      ORDER BY table_name
      INTO CORRESPONDING FIELDS OF TABLE @rt_tables.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_baselines.
    SELECT tabname, hash, row_count, taken_at, taken_by, hash_version
      FROM zcd_hck_baseline
      ORDER BY tabname
      INTO CORRESPONDING FIELDS OF TABLE @rt_baselines.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~compute_table_hash.
    DATA lr_table TYPE REF TO data.
    DATA lt_names TYPE string_table.
    DATA lv_package TYPE string.
    DATA lv_cursor TYPE cursor.
    DATA lv_open TYPE abap_bool.
    " used in the dynamic OPEN CURSOR select list (not seen by static checks)
    DATA lv_select TYPE string ##NEEDED.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.

    DATA(lt_fields) = zif_cd_hck_dao~get_table_fields( iv_tabname ).
    LOOP AT lt_fields ASSIGNING FIELD-SYMBOL(<ls_field>).
      INSERT CONV string( <ls_field>-fieldname ) INTO TABLE lt_names.
    ENDLOOP.
    lv_select = concat_lines_of( table = lt_names sep = `, ` ).
    DATA(lv_from) = to_upper( condense( CONV string( iv_tabname ) ) ).

    rs_hash-tabname      = lv_from.
    rs_hash-hash_version = zcl_cd_hck_canonical=>gc_hash_version.
    TRY.
        CREATE DATA lr_table TYPE STANDARD TABLE OF (lv_from).
        ASSIGN lr_table->* TO <lt_rows>.
        OPEN CURSOR @lv_cursor FOR
          SELECT (lv_select)
            FROM (lv_from)
            ORDER BY PRIMARY KEY.
        lv_open = abap_true.
        DO.
          FETCH NEXT CURSOR @lv_cursor INTO CORRESPONDING FIELDS OF TABLE @<lt_rows> PACKAGE SIZE @gc_hash_package.
          IF sy-subrc <> 0.
            EXIT.
          ENDIF.
          " chained hash: H(n) = SHA256( H(n-1) || rows of package n ), deterministic by primary key
          lv_package = rs_hash-hash.
          " A57: canonical, length-prefixed typed fields - no separator ambiguity
          LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
            lv_package = lv_package && zcl_cd_hck_canonical=>row( <ls_row> ) && cl_abap_char_utilities=>newline.
          ENDLOOP.
          rs_hash-row_count = rs_hash-row_count + lines( <lt_rows> ).
          rs_hash-hash = sha256( lv_package ).
        ENDDO.
        CLOSE CURSOR @lv_cursor.
        lv_open = abap_false.
      CATCH cx_sy_dynamic_osql_error cx_sy_create_data_error INTO DATA(lx_sql).
        " A57: the cursor is closed on every path, also after an SQL error
        IF lv_open = abap_true.
          CLOSE CURSOR @lv_cursor.
        ENDIF.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e311(zcd_ops) WITH lv_from
          EXPORTING
            previous = lx_sql.
      CLEANUP.
        " any other exception leaving the method (e.g. a hash error) also closes the cursor
        IF lv_open = abap_true.
          CLOSE CURSOR @lv_cursor.
        ENDIF.
    ENDTRY.
    IF rs_hash-hash IS INITIAL.
      " empty table: hash of the empty string, so 'emptied' is detected as drift
      rs_hash-hash = sha256( `` ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~save_baselines.
    DATA lt_db TYPE STANDARD TABLE OF zcd_hck_baseline WITH EMPTY KEY.
    DATA ls_db TYPE zcd_hck_baseline.
    LOOP AT it_baselines ASSIGNING FIELD-SYMBOL(<ls_baseline>).
      CLEAR ls_db.
      ls_db-tabname   = <ls_baseline>-tabname.
      ls_db-hash      = <ls_baseline>-hash.
      ls_db-row_count = <ls_baseline>-row_count.
      ls_db-taken_at  = <ls_baseline>-taken_at.
      ls_db-taken_by  = <ls_baseline>-taken_by.
      ls_db-hash_version = <ls_baseline>-hash_version.
      INSERT ls_db INTO TABLE lt_db.
    ENDLOOP.
    MODIFY zcd_hck_baseline FROM TABLE @lt_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH 'ZCD_HCK_BASELINE'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_cycle_steps.
    SELECT c~cycle_id, c~description AS cycle_text, c~calendar,
           s~step_no, s~description AS step_text, s~jobname, s~program, s~variant, s~pred_step,
           s~day_offset, s~window_from, s~window_to, s~max_runtime_min, s~skippable, s~critical
      FROM zcd_job_cycle AS c
      INNER JOIN zcd_job_step AS s
        ON s~cycle_id = c~cycle_id
      WHERE c~active   = @abap_true
      ORDER BY c~cycle_id, s~step_no
      INTO CORRESPONDING FIELDS OF TABLE @rt_steps.
    " PCRE on the cycle id: applied to the (few) customizing rows in ABAP
    IF it_cycle_ids IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_all) = rt_steps.
    CLEAR rt_steps.
    LOOP AT lt_all ASSIGNING FIELD-SYMBOL(<ls_step>).
      IF zcl_ca_ops_util=>pcre_match_any( iv_value = <ls_step>-cycle_id it_patterns = it_cycle_ids ) = abap_true.
        INSERT <ls_step> INTO TABLE rt_steps.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~is_working_day.
    DATA lv_indicator TYPE c LENGTH 1.
    rv_working = abap_true.
    IF iv_calendar IS INITIAL.
      RETURN.
    ENDIF.
    " verify on target release: WORKINGDAY_INDICATOR = space for a working day
    CALL FUNCTION 'DATE_CONVERT_TO_FACTORYDATE'
      EXPORTING
        correct_option       = '+'
        date                 = iv_date
        factory_calendar_id  = iv_calendar
      IMPORTING
        workingday_indicator = lv_indicator
      EXCEPTIONS
        OTHERS               = 1.
    IF sy-subrc <> 0.
      " a broken calendar must never silence monitoring
      RETURN.
    ENDIF.
    rv_working = xsdbool( lv_indicator IS INITIAL ).
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_job_runs.
    DATA lt_names TYPE tt_jobname.
    IF it_jobnames IS INITIAL.
      RETURN.
    ENDIF.
    " PCRE on the job name: distinct names of the window first, matched in ABAP
    DATA(lv_max_names) = zcl_cd_hck_param=>job_names_cap( ).
    SELECT DISTINCT jobname
      FROM tbtco
      WHERE sdlstrtdt BETWEEN @iv_from AND @iv_to
         OR strtdate  BETWEEN @iv_from AND @iv_to
      ORDER BY jobname
      INTO TABLE @lt_names
      UP TO @lv_max_names ROWS.
    DATA(lt_matched) = matched_jobnames( it_names = lt_names it_patterns = it_jobnames ).
    IF lt_matched IS INITIAL.
      RETURN.
    ENDIF.
    " FOR ALL ENTRIES: the database interface packages a long name list (no oversized IN list);
    " order and row cap applied below, as before
    "VERIFY-DDIC: TBTCO-JOBNAME, JOBCOUNT, STATUS, SDLSTRTDT, SDLSTRTTM, STRTDATE, STRTTIME, ENDDATE, ENDTIME
    SELECT jobname, jobcount, status, sdlstrtdt, sdlstrttm, strtdate, strttime, enddate, endtime
      FROM tbtco
      FOR ALL ENTRIES IN @lt_matched
      WHERE jobname = @lt_matched-table_line
        AND ( sdlstrtdt BETWEEN @iv_from AND @iv_to
           OR strtdate  BETWEEN @iv_from AND @iv_to )
      INTO CORRESPONDING FIELDS OF TABLE @rt_runs.
    SORT rt_runs BY jobname jobcount.
    DELETE rt_runs FROM zcl_cd_hck_param=>job_rows_cap( ) + 1.
    add_step_program( CHANGING ct_runs = rt_runs ).
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_unresolved_jobs.
    DATA lt_names TYPE tt_jobname.
    IF it_jobnames IS INITIAL.
      RETURN.
    ENDIF.
    " PCRE on the job name: distinct names of the open statuses first, matched in ABAP
    DATA(lv_max_names) = zcl_cd_hck_param=>job_names_cap( ).
    SELECT DISTINCT jobname
      FROM tbtco
      WHERE status IN ( @zif_cd_hck_types=>gc_job_status-running,
                        @zif_cd_hck_types=>gc_job_status-ready,
                        @zif_cd_hck_types=>gc_job_status-put_activ,
                        @zif_cd_hck_types=>gc_job_status-released )
      ORDER BY jobname
      INTO TABLE @lt_names
      UP TO @lv_max_names ROWS.
    DATA(lt_matched) = matched_jobnames( it_names = lt_names it_patterns = it_jobnames ).
    IF lt_matched IS INITIAL.
      RETURN.
    ENDIF.
    "VERIFY-DDIC: TBTCO-STATUS values R running, Y ready, Z active, S released
    SELECT jobname, jobcount, status, sdlstrtdt, sdlstrttm, strtdate, strttime, enddate, endtime
      FROM tbtco
      FOR ALL ENTRIES IN @lt_matched
      WHERE jobname = @lt_matched-table_line
        AND status IN ( @zif_cd_hck_types=>gc_job_status-running,
                        @zif_cd_hck_types=>gc_job_status-ready,
                        @zif_cd_hck_types=>gc_job_status-put_activ,
                        @zif_cd_hck_types=>gc_job_status-released )
      INTO CORRESPONDING FIELDS OF TABLE @rt_runs.
    " oldest planned start first, capped (A44)
    SORT rt_runs BY sdlstrtdt sdlstrttm jobname jobcount.
    DELETE rt_runs FROM zcl_cd_hck_param=>job_rows_cap( ) + 1.
    add_step_program( CHANGING ct_runs = rt_runs ).
  ENDMETHOD.


  METHOD matched_jobnames.
    DATA(lv_max_names) = zcl_cd_hck_param=>job_names_cap( ).
    IF lines( it_names ) >= lv_max_names.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e747(zcd_ops) WITH lv_max_names gc_table_tbtco.
    ENDIF.
    LOOP AT it_names ASSIGNING FIELD-SYMBOL(<lv_name>).
      IF zcl_ca_ops_util=>pcre_match_any( iv_value = <lv_name> it_patterns = it_patterns ) = abap_true.
        INSERT <lv_name> INTO TABLE rt_names.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_step_program.
    TYPES:
      BEGIN OF ty_step,
        jobname  TYPE zif_cd_hck_types=>ty_job_run-jobname,
        jobcount TYPE zif_cd_hck_types=>ty_job_run-jobcount,
        progname TYPE zif_cd_hck_types=>ty_job_run-progname,
        variant  TYPE zif_cd_hck_types=>ty_job_run-variant,
      END OF ty_step.
    " Sweep: sorted key instead of SORT + BINARY SEARCH (one first step per job)
    DATA lt_steps TYPE SORTED TABLE OF ty_step WITH NON-UNIQUE KEY jobname jobcount.
    CHECK ct_runs IS NOT INITIAL.
    "VERIFY-DDIC: TBTCP-JOBNAME, JOBCOUNT, STEPCOUNT, PROGNAME, VARIANT
    SELECT jobname, jobcount, progname, variant
      FROM tbtcp
      FOR ALL ENTRIES IN @ct_runs
      WHERE jobname   = @ct_runs-jobname
        AND jobcount  = @ct_runs-jobcount
        AND stepcount = @gc_first_step
      INTO CORRESPONDING FIELDS OF TABLE @lt_steps.
    LOOP AT ct_runs ASSIGNING FIELD-SYMBOL(<ls_run>).
      READ TABLE lt_steps ASSIGNING FIELD-SYMBOL(<ls_step>)
           WITH TABLE KEY jobname = <ls_run>-jobname jobcount = <ls_run>-jobcount.
      IF sy-subrc = 0.
        <ls_run>-progname = <ls_step>-progname.
        <ls_run>-variant  = <ls_step>-variant.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_applog_stats.
    IF it_objects IS INITIAL.
      " no object list = no full scan of BALHDR
      RETURN.
    ENDIF.
    "VERIFY-DDIC: BALHDR-OBJECT, SUBOBJECT, ALDATE, MSG_CNT_AL (all), MSG_CNT_E (error), MSG_CNT_A (abort)
    " PCRE on object / subobject: counters of the day grouped in SQL (one row per pair),
    " matched in ABAP
    SELECT object, subobject, COUNT(*) AS log_count,
           SUM( msg_cnt_al ) AS msg_total, SUM( msg_cnt_e ) AS msg_error, SUM( msg_cnt_a ) AS msg_abort
      FROM balhdr
      WHERE aldate    = @iv_date
      GROUP BY object, subobject
      ORDER BY object, subobject
      INTO CORRESPONDING FIELDS OF TABLE @rt_stat.
    DATA(lt_all) = rt_stat.
    CLEAR rt_stat.
    LOOP AT lt_all ASSIGNING FIELD-SYMBOL(<ls_stat>).
      IF zcl_ca_ops_util=>pcre_match_any( iv_value = <ls_stat>-object it_patterns = it_objects ) = abap_true
         AND ( it_subobjects IS INITIAL
               OR zcl_ca_ops_util=>pcre_match_any( iv_value    = <ls_stat>-subobject
                                                   it_patterns = it_subobjects ) = abap_true ).
        INSERT <ls_stat> INTO TABLE rt_stat.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_overdue_exceptions.
    CONSTANTS lc_no_date TYPE d VALUE '00000000'.
    " index ZCA_OPS_FINDING~OPN: CLIENT, AREA, DISPOSITION, DUE_DATE. Per area and company code of the
    " exceptions (company-code isolation: a count never mixes two company codes); AREA named as the target
    " component PE_AREA (CORRESPONDING maps by name - without the alias the area stayed blank)
    SELECT area AS pe_area, bukrs, COUNT(*) AS item_count, MIN( due_date ) AS oldest_due
      FROM zca_ops_finding
      WHERE disposition IN ( @zif_cd_hck_types=>gc_disposition-open, @zif_cd_hck_types=>gc_disposition-assigned )
        AND due_date    < @iv_today
        AND due_date    > @lc_no_date
      GROUP BY area, bukrs
      ORDER BY area, bukrs
      INTO CORRESPONDING FIELDS OF TABLE @rt_overdue.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_open_exceptions.
    SELECT area, group1, group2, object_key, check_code, severity, message, disposition,
           owner, due_date, created_at
      FROM zca_ops_finding
      WHERE disposition IN ( @zif_cd_hck_types=>gc_disposition-open, @zif_cd_hck_types=>gc_disposition-assigned )
      ORDER BY due_date ASCENDING, created_at ASCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt_exceptions
      UP TO @iv_max_rows ROWS.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_fikeys_without_gl.
    " confirmed path DFKKSUMC-FIKEY = DFKKKO-FIKEY = BKPF-AWKEY. A43: the GL document must be
    " of the transfer reference type, for the same company code, and not reversed - an
    " unrelated document or the transfer of another company code no longer hides a gap.
    "VERIFY-DDIC: DFKKSUMC-BUKRS, DFKKKO-BUDAT, BKPF-AWTYP / AWKEY / BUKRS / STBLG
    "VERIFY-DDIC: AWTYP of the payment engine GL transfer (PARAM4, default FKKSU)
    SELECT DISTINCT s~fikey, s~bukrs
      FROM dfkksumc AS s
      WHERE EXISTS ( SELECT fikey FROM dfkkko
                       WHERE fikey = s~fikey
                         AND budat BETWEEN @iv_from AND @iv_to )
        AND NOT EXISTS ( SELECT awkey FROM bkpf
                           WHERE awtyp = @iv_awtyp
                             AND awkey = s~fikey
                             AND bukrs = s~bukrs
                             AND stblg = @space )
      ORDER BY s~fikey, s~bukrs
      INTO CORRESPONDING FIELDS OF TABLE @rt_gaps
      UP TO @iv_max_rows ROWS.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~count_fikeys_without_gl.
    " same population as get_fikeys_without_gl, without the display cap (keys only)
    SELECT DISTINCT s~fikey, s~bukrs
      FROM dfkksumc AS s
      WHERE EXISTS ( SELECT fikey FROM dfkkko
                       WHERE fikey = s~fikey
                         AND budat BETWEEN @iv_from AND @iv_to )
        AND NOT EXISTS ( SELECT awkey FROM bkpf
                           WHERE awtyp = @iv_awtyp
                             AND awkey = s~fikey
                             AND bukrs = s~bukrs
                             AND stblg = @space )
      ORDER BY s~fikey, s~bukrs
      INTO TABLE @DATA(lt_keys).
    rv_count = lines( lt_keys ).
  ENDMETHOD.


  METHOD zif_cd_hck_dao~count_short_dumps.
    "VERIFY-DDIC: SNAP_BEG-DATUM (short dump header, one row per dump); else SNAP with SEQNO = '000'
    SELECT COUNT(*)
      FROM snap_beg
      WHERE datum = @iv_date
      INTO @rv_count.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~count_update_errors.
    CONSTANTS lc_ok TYPE i VALUE 0.
    "VERIFY-DDIC: VBHDR-VBRC <> 0 marks an update request in error (SM13 status ERR)
    SELECT COUNT(*)
      FROM vbhdr
      WHERE vbrc <> @lc_ok
      INTO @rv_count.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~read_lock_stats.
    DATA lt_enq TYPE STANDARD TABLE OF seqg3 WITH EMPTY KEY.
    DATA lv_number TYPE i.

    CALL FUNCTION 'ENQUEUE_READ'
      EXPORTING
        gclient               = sy-mandt
        gname                 = space
        guname                = space
      IMPORTING
        number                = lv_number
      TABLES
        enq                   = lt_enq
      EXCEPTIONS
        communication_failure = 1
        system_failure        = 2
        OTHERS                = 3.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e313(zcd_ops) WITH sy-subrc.
    ENDIF.
    rs_stat-lock_entries = lv_number.
    "VERIFY-DDIC: SEQG3-GTDATE / GTTIME (date and time the lock was set)
    LOOP AT lt_enq ASSIGNING FIELD-SYMBOL(<ls_enq>).
      DATA(lv_age) = zcl_cd_hck_cycle_eval=>minutes_between( iv_from_date = <ls_enq>-gtdate
                                                             iv_from_time = <ls_enq>-gttime
                                                             iv_to_date   = iv_now_date
                                                             iv_to_time   = iv_now_time ).
      rs_stat-lock_max_age_min = nmax( val1 = rs_stat-lock_max_age_min
                                       val2 = lv_age ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_alert_stats.
    " ZCA_OPS_ALLOG is delivered by the core alert router
    SELECT channel, status, COUNT(*) AS item_count
      FROM zca_ops_allog
      WHERE sent_at BETWEEN @iv_from AND @iv_to
      GROUP BY channel, status
      ORDER BY channel, status
      INTO CORRESPONDING FIELDS OF TABLE @rt_stat.
  ENDMETHOD.


  METHOD sha256.
    DATA lv_hash TYPE string.
    TRY.
        cl_abap_message_digest=>calculate_hash_for_char(
          EXPORTING
            if_algorithm  = gc_hash_algorithm
            if_data       = iv_data
          IMPORTING
            ef_hashstring = lv_hash ).
      CATCH cx_abap_message_digest INTO DATA(lx_digest).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e311(zcd_ops) WITH gc_hash_algorithm
          EXPORTING
            previous = lx_digest.
    ENDTRY.
    rv_hash = lv_hash.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_suppressions.
    " index ZCD_HCK_SUPPRESS~ACT
    SELECT suppress_uuid, check_id, key_pattern, bukrs, valid_from, valid_to, status, created_by
      FROM zcd_hck_suppress
      WHERE status     = @zif_cd_hck_suppress_types=>gc_status-active
        AND valid_from <= @iv_today
        AND valid_to   >= @iv_today
      ORDER BY check_id, suppress_uuid
      INTO CORRESPONDING FIELDS OF TABLE @rt_suppressions.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~select_values.
    DATA lt_fields TYPE zif_cd_hck_types=>tt_field.
    " A56: rebuilt from its specification at the SQL boundary (whitelist, DDIC, quoting)
    DATA(lv_whitelisted) = zif_cd_hck_dao~is_table_whitelisted( is_query-tabname ).
    IF lv_whitelisted = abap_true.
      lt_fields = zif_cd_hck_dao~get_table_fields( is_query-tabname ).
    ENDIF.
    DATA(ls_query) = zcl_cd_hck_value_query=>build( iv_tabname     = is_query-tabname
                                                    it_return      = is_query-returns
                                                    it_conditions  = is_query-conditions
                                                    iv_date_field  = is_query-date_field
                                                    iv_date_from   = is_query-date_from
                                                    it_fields      = lt_fields
                                                    iv_whitelisted = lv_whitelisted ).
    DATA(lv_fields) = ls_query-field_list.
    DATA(lv_from)   = CONV string( ls_query-tabname ).
    DATA(lv_where)  = ls_query-where_clause.
    DATA(lv_order)  = ls_query-order_by.
    TRY.
        SELECT (lv_fields)
          FROM (lv_from)
          WHERE (lv_where)
          ORDER BY (lv_order)
          INTO CORRESPONDING FIELDS OF TABLE @rt_rows
          UP TO @iv_max_rows ROWS.
      CATCH cx_sy_dynamic_osql_error INTO DATA(lx_sql).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e308(zcd_ops) WITH ls_query-tabname gc_query_kind_values
          EXPORTING
            previous = lx_sql.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
