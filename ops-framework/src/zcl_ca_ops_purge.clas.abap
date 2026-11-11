*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_purge.clas.abap
*& Purpose:
*& Retention purge of the framework's history and of the targets consumers
*& register: runs with their findings and exception history (RUN), alert
*& log (ALERT_LOG), sign-offs of the daily control review (REVIEW), then
*& every active row of ZCA_OPS_PURGE (a class of ZIF_CA_OPS_PURGE_TARGET and
*& its retention parameter). Retention days per target in ZCA_PARAM
*& (RETENTION_DAYS_RUN / _ALERT_LOG / _REVIEW in area CA_OPS, a
*& registered target's own parameter), never below 30 days. Every target is
*& created before anything is deleted (a wrong registry row stops the run
*& first). Test mode counts only; otherwise deletes package by package with
*& a commit per package. Runs that still hold an open, assigned or validly
*& waived exception are never purged (rule in the DAO). Keep rules of a
*& consumer target are the consumer's.
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
*& 2026-11-07 | PURGE_PACKAGE_SIZE / RETENTION_DAYS_ names and default from the types interface; one shared
*&            | helper PARAM_INT over GET_PARAMS (private int_param removed); retention days in ZCA_PARAM.
*& 2026-11-10 | RUN also purges the exception history of its findings (HISTORY).
*& 2026-11-10 | Moved from ZCL_CD_OPS_PURGE to the reusable framework ZCA_OPS: built-in targets RUN and
*&            | ALERT_LOG, consumer targets from the registry ZCA_OPS_PURGE (plug-ins of
*&            | ZIF_CA_OPS_PURGE_TARGET, retention parameter per row); result column DEPENDENT (was FINDINGS).
*& 2026-11-10 | Built-in target REVIEW (sign-offs of the daily control review, RETENTION_DAYS_REVIEW 400).
*& 2026-11-11 | Built-in target DOWNTIME (ended planned downtime windows, DOWNTIME_RETENTION_DAYS 400).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - retention purge</p>
CLASS zcl_ca_ops_purge DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Retention never below this many days (protects against a mistyped parameter)
    CONSTANTS gc_min_days TYPE i VALUE 30.

    TYPES:
      BEGIN OF ty_result,
        target    TYPE zif_ca_ops_purge_target=>ty_target,
        days      TYPE i,
        cutoff    TYPE d,
        "! Rows deleted (test mode: rows that would be deleted)
        rows      TYPE i,
        "! Rows of dependent tables deleted with them (RUN: findings)
        dependent TYPE i,
        "! History rows deleted with them (RUN: exception history)
        history   TYPE i,
      END OF ty_result.
    TYPES tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    CLASS-METHODS cutoff_date
      IMPORTING
        iv_today       TYPE d
        iv_days        TYPE i
      RETURNING
        VALUE(rv_date) TYPE d.

    "! @raising zcx_ca_ops_error | a registered target class cannot be created as a purge target
    METHODS run
      IMPORTING
        iv_test_mode      TYPE abap_bool
      RETURNING
        VALUE(rt_results) TYPE tt_result
      RAISING
        zcx_ca_ops_error.

  PRIVATE SECTION.
    "! Built-in defaults of the framework's targets (the parameter definitions deliver the same)
    CONSTANTS gc_run_days TYPE i VALUE 400.
    CONSTANTS gc_alert_log_days TYPE i VALUE 180.
    CONSTANTS gc_review_days TYPE i VALUE 400.

    TYPES:
      BEGIN OF ty_target_cfg,
        target       TYPE zif_ca_ops_purge_target=>ty_target,
        param_area   TYPE zif_ca_ops_types=>ty_area,
        param_name   TYPE zif_ca_ops_types=>ty_param_name,
        default_days TYPE i,
        handler      TYPE REF TO zif_ca_ops_purge_target,
      END OF ty_target_cfg.
    TYPES tt_target_cfg TYPE STANDARD TABLE OF ty_target_cfg WITH EMPTY KEY.

    "! RUN first (its findings are the largest table), ALERT_LOG, REVIEW, then the registered targets
    METHODS targets
      IMPORTING
        io_dao            TYPE REF TO zif_ca_ops_purge_dao
      RETURNING
        VALUE(rt_targets) TYPE tt_target_cfg
      RAISING
        zcx_ca_ops_error.

ENDCLASS.



CLASS zcl_ca_ops_purge IMPLEMENTATION.

  METHOD cutoff_date.
    rv_date = iv_today - nmax( val1 = iv_days val2 = gc_min_days ).
  ENDMETHOD.


  METHOD run.
    DATA lv_cutoff_ts TYPE timestampl.

    DATA(lo_dao)   = zcl_ca_ops_factory=>get_purge_dao( ).
    DATA(lo_store) = zcl_ca_ops_factory=>get_store( ).
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    DATA(lv_today) = zcl_ca_ops_factory=>get_clock( )->today( ).
    DATA(lv_package) = nmax( val1 = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                                iv_name    = zif_ca_ops_types=>gc_param-purge_package
                                                                iv_default = zif_ca_ops_types=>gc_param_default-purge_package )
                             val2 = 1 ).
    " every target is known before anything is deleted
    DATA(lt_targets) = targets( lo_dao ).

    LOOP AT lt_targets ASSIGNING FIELD-SYMBOL(<ls_target>).
      DATA(ls_result) = VALUE ty_result(
        target = <ls_target>-target
        days   = nmax( val1 = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                          iv_name    = <ls_target>-param_name
                                                          iv_area    = <ls_target>-param_area
                                                          iv_default = <ls_target>-default_days )
                       val2 = gc_min_days ) ).
      ls_result-cutoff = cutoff_date( iv_today = lv_today iv_days = ls_result-days ).
      CONVERT DATE ls_result-cutoff TIME zif_ca_ops_types=>gc_time-day_start
        INTO TIME STAMP lv_cutoff_ts TIME ZONE zif_ca_ops_types=>gc_time_zone_utc.

      IF iv_test_mode = abap_true.
        ls_result-rows = <ls_target>-handler->count_purgeable( iv_target = <ls_target>-target
                                                               iv_cutoff = lv_cutoff_ts
                                                               iv_today  = lv_today ).
      ELSE.
        DO.
          DATA(lv_deleted) = <ls_target>-handler->delete_package( EXPORTING iv_target    = <ls_target>-target
                                                                            iv_cutoff    = lv_cutoff_ts
                                                                            iv_today     = lv_today
                                                                            iv_max       = lv_package
                                                                  IMPORTING ev_dependent = DATA(lv_dependent)
                                                                            ev_history   = DATA(lv_history) ).
          lo_store->commit( ).
          ls_result-rows      += lv_deleted.
          ls_result-dependent += lv_dependent.
          ls_result-history   += lv_history.
          IF lv_deleted < lv_package.
            EXIT.
          ENDIF.
        ENDDO.
      ENDIF.
      INSERT ls_result INTO TABLE rt_results.
    ENDLOOP.
  ENDMETHOD.


  METHOD targets.
    rt_targets = VALUE #(
      ( target       = zif_ca_ops_purge_dao=>gc_target-run
        param_area   = zif_ca_ops_types=>gc_param_area
        param_name   = |{ zif_ca_ops_types=>gc_param_prefix-retention_days }{ zif_ca_ops_purge_dao=>gc_target-run }|
        default_days = gc_run_days
        handler      = io_dao )
      ( target       = zif_ca_ops_purge_dao=>gc_target-alert_log
        param_area   = zif_ca_ops_types=>gc_param_area
        param_name   = |{ zif_ca_ops_types=>gc_param_prefix-retention_days }{ zif_ca_ops_purge_dao=>gc_target-alert_log }|
        default_days = gc_alert_log_days
        handler      = io_dao )
      ( target       = zif_ca_ops_purge_dao=>gc_target-review
        param_area   = zif_ca_ops_types=>gc_param_area
        param_name   = |{ zif_ca_ops_types=>gc_param_prefix-retention_days }{ zif_ca_ops_purge_dao=>gc_target-review }|
        default_days = gc_review_days
        handler      = io_dao )
      " planned downtime windows (2026-11-11): the parameter of the feature (prefix DOWNTIME_)
      ( target       = zif_ca_ops_purge_dao=>gc_target-downtime
        param_area   = zif_ca_ops_types=>gc_param_area
        param_name   = zif_ca_ops_resp_types=>gc_param-downtime_retention
        default_days = zif_ca_ops_resp_types=>gc_param_default-downtime_retention
        handler      = io_dao ) ).
    LOOP AT io_dao->get_targets( ) ASSIGNING FIELD-SYMBOL(<ls_row>).
      TRY.
          DATA(lo_handler) = CAST zif_ca_ops_purge_target( zcl_ca_ops_factory=>get_plugin(
                               iv_class_name = <ls_row>-class_name
                               iv_interface  = zif_ca_ops_types=>gc_plugin_intf-purge_target ) ).
        CATCH cx_sy_move_cast_error INTO DATA(lx_cast).
          RAISE EXCEPTION TYPE zcx_ca_ops_error
            MESSAGE e032(zca_ops) WITH <ls_row>-class_name zif_ca_ops_types=>gc_plugin_intf-purge_target
            EXPORTING
              previous = lx_cast.
      ENDTRY.
      INSERT VALUE #( target       = <ls_row>-target
                      param_area   = <ls_row>-param_area
                      param_name   = <ls_row>-param_name
                      default_days = zif_ca_ops_types=>gc_param_default-retention_days
                      handler      = lo_handler ) INTO TABLE rt_targets.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
