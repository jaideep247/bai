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
    CONSTANTS gc_max_agg_rows TYPE i VALUE 5000.
    CONSTANTS gc_max_job_rows TYPE i VALUE 5000.
    CONSTANTS gc_hash_package TYPE i VALUE 1000.

    METHODS sha256
      IMPORTING
        iv_data        TYPE string
      RETURNING
        VALUE(rv_hash) TYPE zif_cd_hck_types=>ty_hash
      RAISING
        zcx_cd_ops_error.

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
    SELECT check_id, metric, bukrs, amber, red, higher_is_worse, baseline_mode, z_limit, lookback_runs
      FROM zcd_hck_thresh
      WHERE check_id = @iv_check_id
      ORDER BY check_id, metric, bukrs
      INTO CORRESPONDING FIELDS OF TABLE @rt_thresholds.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_agg_defs.
    SELECT check_id, agg_id, description, tabname, agg_func, sum_field, date_field, date_mode,
           age_days_min, group_field, cond1_field, cond1_op, cond1_value, cond2_field, cond2_op,
           cond2_value, cond3_field, cond3_op, cond3_value
      FROM zcd_hck_agg
      WHERE check_id = @iv_check_id
      ORDER BY agg_id
      INTO CORRESPONDING FIELDS OF TABLE @rt_defs.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~is_table_whitelisted.
    DATA(lv_tabname) = to_upper( iv_tabname ).
    SELECT SINGLE active
      FROM zcd_hck_tabwl
      WHERE tabname = @lv_tabname
      INTO @DATA(lv_active).
    rv_allowed = xsdbool( sy-subrc = 0 AND lv_active = abap_true ).
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_table_fields.
    DATA lo_descr TYPE REF TO cl_abap_typedescr.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    DATA lt_ddic TYPE ddfields.

    DATA(lv_name) = to_upper( condense( CONV string( iv_tabname ) ) ).
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
      CATCH cx_sy_move_cast_error.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e303(zcd_ops) WITH lv_name.
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
    LOOP AT lt_ddic INTO DATA(ls_ddic).
      INSERT VALUE #( fieldname = ls_ddic-fieldname
                      type_kind = ls_ddic-inttype
                      keyflag   = ls_ddic-keyflag ) INTO TABLE rt_fields.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~aggregate.
    " names in is_query were checked against the DDIC by ZCL_CD_HCK_AGG_QUERY=>BUILD
    DATA(lv_select) = COND string( WHEN is_query-group_field IS NOT INITIAL
                                   THEN |{ is_query-group_field } AS group_value, | ).
    lv_select = lv_select && `COUNT(*) AS row_count`.
    IF is_query-agg_func = zif_cd_hck_types=>gc_agg_func-sum.
      lv_select = |{ lv_select }, SUM( { is_query-sum_field } ) AS total|.
    ENDIF.
    DATA(lv_from)  = CONV string( is_query-tabname ).
    DATA(lv_where) = is_query-where_clause.
    DATA(lv_group) = CONV string( is_query-group_field ).

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
            UP TO @gc_max_agg_rows ROWS.
        ENDIF.
      CATCH cx_sy_dynamic_osql_error INTO DATA(lx_sql).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e308(zcd_ops) WITH is_query-tabname is_query-agg_id
          EXPORTING
            previous = lx_sql.
    ENDTRY.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_metric_history.
    " index ZCD_HCK_METRIC~HST: CHECK_ID, METRIC, DIM1, MEASURED_AT
    SELECT value
      FROM zcd_hck_metric
      WHERE check_id = @iv_check_id
        AND metric   = @iv_metric
        AND dim1     = @iv_dim1
      ORDER BY measured_at DESCENDING
      INTO TABLE @rt_values
      UP TO @iv_max_rows ROWS.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~save_metrics.
    DATA lt_db TYPE STANDARD TABLE OF zcd_hck_metric WITH EMPTY KEY.
    DATA ls_db TYPE zcd_hck_metric.

    IF it_metrics IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT it_metrics INTO DATA(ls_metric).
      CLEAR ls_db.
      ls_db-run_id      = ls_metric-run_id.
      ls_db-check_id    = ls_metric-check_id.
      ls_db-metric      = ls_metric-metric.
      ls_db-dim1        = ls_metric-dim1.
      ls_db-dim2        = ls_metric-dim2.
      ls_db-value       = ls_metric-value.
      ls_db-measured_at = ls_metric-measured_at.
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
    SELECT tabname, description
      FROM zcd_hck_drift
      WHERE active = @abap_true
      ORDER BY tabname
      INTO CORRESPONDING FIELDS OF TABLE @rt_tables.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_baselines.
    SELECT tabname, hash, row_count, taken_at, taken_by
      FROM zcd_hck_baseline
      ORDER BY tabname
      INTO CORRESPONDING FIELDS OF TABLE @rt_baselines.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~compute_table_hash.
    DATA lr_table TYPE REF TO data.
    DATA lt_names TYPE string_table.
    DATA lv_package TYPE string.
    DATA lv_cursor TYPE cursor.
    " used in the dynamic OPEN CURSOR select list (not seen by static checks)
    DATA lv_select TYPE string ##NEEDED.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lv_field> TYPE any.

    DATA(lt_fields) = zif_cd_hck_dao~get_table_fields( iv_tabname ).
    LOOP AT lt_fields INTO DATA(ls_field).
      INSERT CONV string( ls_field-fieldname ) INTO TABLE lt_names.
    ENDLOOP.
    lv_select = concat_lines_of( table = lt_names sep = `, ` ).
    DATA(lv_from) = to_upper( condense( CONV string( iv_tabname ) ) ).

    rs_hash-tabname = lv_from.
    TRY.
        CREATE DATA lr_table TYPE STANDARD TABLE OF (lv_from).
        ASSIGN lr_table->* TO <lt_rows>.
        OPEN CURSOR @lv_cursor FOR
          SELECT (lv_select)
            FROM (lv_from)
            ORDER BY PRIMARY KEY.
        DO.
          FETCH NEXT CURSOR @lv_cursor INTO CORRESPONDING FIELDS OF TABLE @<lt_rows> PACKAGE SIZE @gc_hash_package.
          IF sy-subrc <> 0.
            EXIT.
          ENDIF.
          " chained hash: H(n) = SHA256( H(n-1) || rows of package n ), deterministic by primary key
          lv_package = rs_hash-hash.
          LOOP AT <lt_rows> ASSIGNING FIELD-SYMBOL(<ls_row>).
            DO.
              ASSIGN COMPONENT sy-index OF STRUCTURE <ls_row> TO <lv_field>.
              IF sy-subrc <> 0.
                EXIT.
              ENDIF.
              lv_package = |{ lv_package }{ <lv_field> }\||.
            ENDDO.
            lv_package = lv_package && cl_abap_char_utilities=>newline.
          ENDLOOP.
          rs_hash-row_count = rs_hash-row_count + lines( <lt_rows> ).
          rs_hash-hash = sha256( lv_package ).
        ENDDO.
        CLOSE CURSOR @lv_cursor.
      CATCH cx_sy_dynamic_osql_error cx_sy_create_data_error INTO DATA(lx_sql).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e311(zcd_ops) WITH lv_from
          EXPORTING
            previous = lx_sql.
    ENDTRY.
    IF rs_hash-hash IS INITIAL.
      " empty table: hash of the empty string, so 'emptied' is detected as drift
      rs_hash-hash = sha256( `` ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~save_baselines.
    DATA lt_db TYPE STANDARD TABLE OF zcd_hck_baseline WITH EMPTY KEY.
    DATA ls_db TYPE zcd_hck_baseline.
    LOOP AT it_baselines INTO DATA(ls_baseline).
      CLEAR ls_db.
      ls_db-tabname   = ls_baseline-tabname.
      ls_db-hash      = ls_baseline-hash.
      ls_db-row_count = ls_baseline-row_count.
      ls_db-taken_at  = ls_baseline-taken_at.
      ls_db-taken_by  = ls_baseline-taken_by.
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
        AND c~cycle_id IN @it_cycle_ids
      ORDER BY c~cycle_id, s~step_no
      INTO CORRESPONDING FIELDS OF TABLE @rt_steps.
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
    IF it_jobnames IS INITIAL.
      RETURN.
    ENDIF.
    "VERIFY-DDIC: TBTCO-JOBNAME, JOBCOUNT, STATUS, SDLSTRTDT, SDLSTRTTM, STRTDATE, STRTTIME, ENDDATE, ENDTIME
    SELECT jobname, jobcount, status, sdlstrtdt, sdlstrttm, strtdate, strttime, enddate, endtime
      FROM tbtco
      WHERE jobname IN @it_jobnames
        AND ( sdlstrtdt BETWEEN @iv_from AND @iv_to
           OR strtdate  BETWEEN @iv_from AND @iv_to )
      ORDER BY jobname, jobcount
      INTO CORRESPONDING FIELDS OF TABLE @rt_runs
      UP TO @gc_max_job_rows ROWS.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_applog_stats.
    IF it_objects IS INITIAL.
      " no object list = no full scan of BALHDR
      RETURN.
    ENDIF.
    "VERIFY-DDIC: BALHDR-OBJECT, SUBOBJECT, ALDATE, MSG_CNT_AL (all), MSG_CNT_E (error), MSG_CNT_A (abort)
    SELECT object, subobject, COUNT(*) AS log_count,
           SUM( msg_cnt_al ) AS msg_total, SUM( msg_cnt_e ) AS msg_error, SUM( msg_cnt_a ) AS msg_abort
      FROM balhdr
      WHERE aldate    = @iv_date
        AND object    IN @it_objects
        AND subobject IN @it_subobjects
      GROUP BY object, subobject
      ORDER BY object, subobject
      INTO CORRESPONDING FIELDS OF TABLE @rt_stat.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_overdue_exceptions.
    CONSTANTS lc_no_date TYPE d VALUE '00000000'.
    " index ZCD_OPS_FINDING~OPN: CLIENT, PE_AREA, DISPOSITION, DUE_DATE
    SELECT pe_area, COUNT(*) AS item_count, MIN( due_date ) AS oldest_due
      FROM zcd_ops_finding
      WHERE disposition IN ( @zif_cd_hck_types=>gc_disposition-open, @zif_cd_hck_types=>gc_disposition-assigned )
        AND due_date    < @iv_today
        AND due_date    > @lc_no_date
      GROUP BY pe_area
      ORDER BY pe_area
      INTO CORRESPONDING FIELDS OF TABLE @rt_overdue.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_open_exceptions.
    SELECT pe_area, group1, group2, object_key, check_code, severity, message, disposition,
           owner, due_date, created_at
      FROM zcd_ops_finding
      WHERE disposition IN ( @zif_cd_hck_types=>gc_disposition-open, @zif_cd_hck_types=>gc_disposition-assigned )
      ORDER BY due_date ASCENDING, created_at ASCENDING
      INTO CORRESPONDING FIELDS OF TABLE @rt_exceptions
      UP TO @iv_max_rows ROWS.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_fikeys_without_gl.
    " confirmed path DFKKSUMC-FIKEY = DFKKKO-FIKEY = BSEG-AWKEY; the header BKPF-AWKEY
    " carries the same reference key and is indexed (AWTYP/AWKEY), BSEG-AWKEY is not.
    "VERIFY-DDIC: DFKKKO-BUDAT (posting date of the payment engine document header)
    "VERIFY-DDIC: BKPF-AWKEY holds the reconciliation key (FIKEY) for the payment engine transfer
    SELECT DISTINCT s~fikey
      FROM dfkksumc AS s
      WHERE EXISTS ( SELECT fikey FROM dfkkko
                       WHERE fikey = s~fikey
                         AND budat BETWEEN @iv_from AND @iv_to )
        AND NOT EXISTS ( SELECT awkey FROM bkpf
                           WHERE awkey = s~fikey )
      ORDER BY s~fikey
      INTO CORRESPONDING FIELDS OF TABLE @rt_gaps
      UP TO @iv_max_rows ROWS.
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
    LOOP AT lt_enq INTO DATA(ls_enq).
      DATA(lv_age) = zcl_cd_hck_cycle_eval=>minutes_between( iv_from_date = ls_enq-gtdate
                                                             iv_from_time = ls_enq-gttime
                                                             iv_to_date   = iv_now_date
                                                             iv_to_time   = iv_now_time ).
      rs_stat-lock_max_age_min = nmax( val1 = rs_stat-lock_max_age_min
                                       val2 = lv_age ).
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_hck_dao~get_alert_stats.
    " ZCD_OPS_ALERT_LOG is delivered by the core alert router
    SELECT channel, status, COUNT(*) AS item_count
      FROM zcd_ops_alert_log
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
            if_algorithm  = 'SHA256'
            if_data       = iv_data
          IMPORTING
            ef_hashstring = lv_hash ).
      CATCH cx_abap_message_digest INTO DATA(lx_digest).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e311(zcd_ops) WITH 'SHA256'
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
    " names in is_query were checked against the DDIC and the whitelist by ZCL_CD_HCK_VALUE_QUERY
    DATA(lv_fields) = is_query-field_list.
    DATA(lv_from)   = CONV string( is_query-tabname ).
    DATA(lv_where)  = is_query-where_clause.
    DATA(lv_order)  = is_query-order_by.
    TRY.
        SELECT (lv_fields)
          FROM (lv_from)
          WHERE (lv_where)
          ORDER BY (lv_order)
          INTO CORRESPONDING FIELDS OF TABLE @rt_rows
          UP TO @iv_max_rows ROWS.
      CATCH cx_sy_dynamic_osql_error INTO DATA(lx_sql).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e308(zcd_ops) WITH is_query-tabname 'VALUES'
          EXPORTING
            previous = lx_sql.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
