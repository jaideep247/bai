*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_store.clas.abap
*& Purpose:
*& Repository for the shared result/exception store. The only class that
*& writes ZCD_OPS_RUN and ZCD_OPS_FINDING. Findings of severity B/E/W are
*& created as owned exceptions (status OPEN) with an SLA due date taken from
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - DB store (ZCD_OPS_RUN/FINDING/PARAM)</p>
"! Repository for the shared result/exception store. The only class that
"! writes ZCD_OPS_RUN and ZCD_OPS_FINDING. Findings of severity B/E/W are
"! created as owned exceptions (status OPEN) with an SLA due date taken from
"! ZCD_OPS_PARAM SLA_DAYS_<module>_<severity> (fallback SLA_DAYS_DEFAULT, 1).
CLASS zcl_cd_ops_store DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store.

    CONSTANTS:
      BEGIN OF gc_disposition,
        open        TYPE c LENGTH 1 VALUE 'O',
        information TYPE c LENGTH 1 VALUE 'I',
      END OF gc_disposition.

  PRIVATE SECTION.
    TYPES ty_param_cache TYPE SORTED TABLE OF zif_cd_ops_types=>ty_kv WITH UNIQUE KEY name.

    DATA mt_param_cache TYPE ty_param_cache.
    DATA mv_params_loaded TYPE abap_bool.

    METHODS load_params.

    METHODS sla_days
      IMPORTING
        iv_module      TYPE zif_cd_ops_types=>ty_module
        iv_severity    TYPE zif_cd_ops_types=>ty_severity
      RETURNING
        VALUE(rv_days) TYPE i.

    METHODS map_run_to_db
      IMPORTING
        is_run       TYPE zif_cd_ops_types=>ty_run
      RETURNING
        VALUE(rs_db) TYPE zcd_ops_run.

    METHODS map_run_from_db
      IMPORTING
        is_db         TYPE zcd_ops_run
      RETURNING
        VALUE(rs_run) TYPE zif_cd_ops_types=>ty_run.

ENDCLASS.



CLASS zcl_cd_ops_store IMPLEMENTATION.

  METHOD zif_cd_ops_store~start_run.
    DATA(lo_clock) = zcl_cd_ops_factory=>get_clock( ).
    TRY.
        rs_run-run_id = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error INTO DATA(lx_uuid).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e001(zcd_ops)
          EXPORTING
            previous = lx_uuid.
    ENDTRY.
    rs_run-module     = iv_module.
    rs_run-variant    = iv_variant.
    rs_run-test_mode  = iv_test_mode.
    rs_run-started_at = lo_clock->now( ).
    rs_run-status     = zif_cd_ops_types=>gc_run_status-running.
    rs_run-rag        = zif_cd_ops_types=>gc_rag-grey.
    rs_run-created_by = sy-uname.

    IF iv_test_mode = abap_true.
      RETURN.
    ENDIF.

    DATA(ls_db) = map_run_to_db( rs_run ).
    INSERT zcd_ops_run FROM @ls_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH 'ZCD_OPS_RUN'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_store~save_findings.
    DATA lt_db TYPE STANDARD TABLE OF zcd_ops_finding WITH EMPTY KEY.
    DATA ls_db TYPE zcd_ops_finding.

    IF it_findings IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lo_clock) = zcl_cd_ops_factory=>get_clock( ).
    DATA(lv_today) = lo_clock->today( ).
    DATA(lv_now)   = lo_clock->now( ).
    DATA(lv_seq)   = cs_run-finding_count.

    LOOP AT it_findings INTO DATA(ls_finding).
      lv_seq += 1.
      CLEAR ls_db.
      ls_db-run_id      = cs_run-run_id.
      ls_db-finding_no  = lv_seq.
      ls_db-module      = cs_run-module.
      ls_db-object_type = ls_finding-object_type.
      ls_db-object_key  = ls_finding-object_key.
      ls_db-group1      = ls_finding-group1.
      ls_db-group2      = ls_finding-group2.
      ls_db-rule_id     = ls_finding-rule_id.
      ls_db-check_code  = ls_finding-check_code.
      ls_db-severity    = ls_finding-severity.
      ls_db-action      = ls_finding-action.
      ls_db-amount      = ls_finding-amount.
      ls_db-currency    = ls_finding-currency.
      ls_db-reference   = ls_finding-reference.
      ls_db-message     = ls_finding-message.
      ls_db-details     = ls_finding-details.
      ls_db-created_at  = lv_now.
      ls_db-created_by  = sy-uname.
      IF zcl_cd_ops_util=>severity_rank( ls_finding-severity ) >= 2.
        ls_db-disposition = gc_disposition-open.
        ls_db-due_date    = lv_today + sla_days( iv_module   = cs_run-module
                                                 iv_severity = ls_finding-severity ).
      ELSE.
        ls_db-disposition = gc_disposition-information.
      ENDIF.
      INSERT ls_db INTO TABLE lt_db.
    ENDLOOP.

    cs_run-finding_count = lv_seq.

    IF cs_run-test_mode = abap_true.
      RETURN.
    ENDIF.

    INSERT zcd_ops_finding FROM TABLE @lt_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e010(zcd_ops) WITH 'ZCD_OPS_FINDING'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_store~finish_run.
    IF is_run-test_mode = abap_true.
      RETURN.
    ENDIF.
    DATA(ls_db) = map_run_to_db( is_run ).
    UPDATE zcd_ops_run FROM @ls_db.
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e011(zcd_ops) WITH 'ZCD_OPS_RUN'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_store~commit.
    COMMIT WORK.
  ENDMETHOD.


  METHOD zif_cd_ops_store~get_param.
    load_params( ).
    READ TABLE mt_param_cache INTO DATA(ls_param) WITH TABLE KEY name = iv_name.
    IF sy-subrc = 0 AND ls_param-value IS NOT INITIAL.
      rv_value = condense( CONV string( ls_param-value ) ).
    ELSE.
      rv_value = iv_default.
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_store~get_last_run.
    DATA lt_db TYPE STANDARD TABLE OF zcd_ops_run WITH EMPTY KEY.
    IF iv_variant IS INITIAL.
      SELECT run_id, module, variant, test_mode, started_at, ended_at, status, rag,
             total_items, passed_items, failed_items, blocked_items, warning_items,
             finding_count, runtime_ms, message, created_by
        FROM zcd_ops_run
        WHERE module    = @iv_module
          AND test_mode = @abap_false
          AND status   <> @zif_cd_ops_types=>gc_run_status-running
        ORDER BY started_at DESCENDING
        INTO CORRESPONDING FIELDS OF TABLE @lt_db
        UP TO 1 ROWS.
    ELSE.
      SELECT run_id, module, variant, test_mode, started_at, ended_at, status, rag,
             total_items, passed_items, failed_items, blocked_items, warning_items,
             finding_count, runtime_ms, message, created_by
        FROM zcd_ops_run
        WHERE module    = @iv_module
          AND variant   = @iv_variant
          AND test_mode = @abap_false
          AND status   <> @zif_cd_ops_types=>gc_run_status-running
        ORDER BY started_at DESCENDING
        INTO CORRESPONDING FIELDS OF TABLE @lt_db
        UP TO 1 ROWS.
    ENDIF.
    READ TABLE lt_db INTO DATA(ls_db) INDEX 1.
    IF sy-subrc = 0.
      rs_run = map_run_from_db( ls_db ).
    ENDIF.
  ENDMETHOD.


  METHOD zif_cd_ops_store~get_runs_since.
    SELECT run_id, module, variant, test_mode, started_at, ended_at, status, rag,
           total_items, passed_items, failed_items, blocked_items, warning_items,
           finding_count, runtime_ms, message, created_by
      FROM zcd_ops_run
      WHERE module      = @iv_module
        AND test_mode   = @abap_false
        AND started_at >= @iv_since
      ORDER BY started_at
      INTO TABLE @DATA(lt_db).
    LOOP AT lt_db INTO DATA(ls_db).
      DATA(ls_full) = CORRESPONDING zcd_ops_run( ls_db ).
      INSERT map_run_from_db( ls_full ) INTO TABLE rt_runs.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_cd_ops_store~get_findings.
    SELECT object_type, object_key, group1, group2, rule_id, check_code, severity,
           action, amount, currency, reference, message, details
      FROM zcd_ops_finding
      WHERE run_id = @iv_run_id
      ORDER BY finding_no
      INTO CORRESPONDING FIELDS OF TABLE @rt_findings.
  ENDMETHOD.


  METHOD load_params.
    IF mv_params_loaded = abap_true.
      RETURN.
    ENDIF.
    SELECT param_name AS name, param_value AS value
      FROM zcd_ops_param
      INTO CORRESPONDING FIELDS OF TABLE @mt_param_cache.
    mv_params_loaded = abap_true.
  ENDMETHOD.


  METHOD sla_days.
    DATA(lv_value) = zif_cd_ops_store~get_param(
      iv_name    = CONV #( |SLA_DAYS_{ iv_module }_{ iv_severity }| )
      iv_default = zif_cd_ops_store~get_param( iv_name    = 'SLA_DAYS_DEFAULT'
                                               iv_default = `1` ) ).
    rv_days = zcl_cd_ops_util=>to_decimal( iv_value = lv_value iv_default = 1 ).
  ENDMETHOD.


  METHOD map_run_to_db.
    rs_db-run_id        = is_run-run_id.
    rs_db-module        = is_run-module.
    rs_db-variant       = is_run-variant.
    rs_db-test_mode     = is_run-test_mode.
    rs_db-started_at    = is_run-started_at.
    rs_db-ended_at      = is_run-ended_at.
    rs_db-status        = is_run-status.
    rs_db-rag           = is_run-rag.
    rs_db-total_items   = is_run-total_items.
    rs_db-passed_items  = is_run-passed_items.
    rs_db-failed_items  = is_run-failed_items.
    rs_db-blocked_items = is_run-blocked_items.
    rs_db-warning_items = is_run-warning_items.
    rs_db-finding_count = is_run-finding_count.
    rs_db-runtime_ms    = is_run-runtime_ms.
    rs_db-message       = is_run-message.
    rs_db-created_by    = is_run-created_by.
  ENDMETHOD.


  METHOD map_run_from_db.
    rs_run-run_id        = is_db-run_id.
    rs_run-module        = is_db-module.
    rs_run-variant       = is_db-variant.
    rs_run-test_mode     = is_db-test_mode.
    rs_run-started_at    = is_db-started_at.
    rs_run-ended_at      = is_db-ended_at.
    rs_run-status        = is_db-status.
    rs_run-rag           = is_db-rag.
    rs_run-total_items   = is_db-total_items.
    rs_run-passed_items  = is_db-passed_items.
    rs_run-failed_items  = is_db-failed_items.
    rs_run-blocked_items = is_db-blocked_items.
    rs_run-warning_items = is_db-warning_items.
    rs_run-finding_count = is_db-finding_count.
    rs_run-runtime_ms    = is_db-runtime_ms.
    rs_run-message       = is_db-message.
    rs_run-created_by    = is_db-created_by.
  ENDMETHOD.

ENDCLASS.
