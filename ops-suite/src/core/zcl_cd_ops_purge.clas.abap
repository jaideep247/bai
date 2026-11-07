*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_purge.clas.abap
*& Purpose:
*& Retention purge of the suite's own history: runs with their findings, alert
*& log, FMON events, HCK metrics. Retention days per target in ZCA_PARAM
*& (RETENTION_DAYS_<target>), never below 30 days. Test mode counts only;
*& otherwise deletes package by package with a commit per package. Runs that
*& still hold an open, assigned or validly waived exception are never purged
*& (rule in the DAO). Does not purge customizing or legacy tables.
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Purge target FMON_PRISM: PRISM status events by receipt time (RETENTION_DAYS_FMON_PRISM).
*& 2026-11-07 | PURGE_PACKAGE_SIZE / RETENTION_DAYS_ names and default from ZIF_CD_OPS_TYPES; one shared
*&            | helper ZCL_CD_OPS_UTIL=>PARAM_INT over GET_PARAMS (private int_param removed).
*& 2026-11-07 | Purpose: retention days in ZCA_PARAM (ZCD_OPS_PARAM retired).
*& 2026-11-07 | Purge target HCK_RESULT (check verdicts per run, 400 days, RETENTION_DAYS_HCK_RESULT).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - retention purge</p>
CLASS zcl_cd_ops_purge DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Retention never below this many days (protects against a mistyped parameter)
    CONSTANTS gc_min_days TYPE i VALUE 30.

    TYPES:
      BEGIN OF ty_result,
        target   TYPE zif_cd_ops_purge_dao=>ty_target,
        days     TYPE i,
        cutoff   TYPE d,
        "! Rows deleted (test mode: rows that would be deleted)
        rows     TYPE i,
        "! RUN only: findings deleted with the runs
        findings TYPE i,
      END OF ty_result.
    TYPES tt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.

    CLASS-METHODS cutoff_date
      IMPORTING
        iv_today       TYPE d
        iv_days        TYPE i
      RETURNING
        VALUE(rv_date) TYPE d.

    METHODS run
      IMPORTING
        iv_test_mode      TYPE abap_bool
      RETURNING
        VALUE(rt_results) TYPE tt_result
      RAISING
        zcx_cd_ops_error.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_target_cfg,
        target       TYPE zif_cd_ops_purge_dao=>ty_target,
        default_days TYPE i,
      END OF ty_target_cfg.
    TYPES tt_target_cfg TYPE STANDARD TABLE OF ty_target_cfg WITH EMPTY KEY.

    METHODS targets
      RETURNING
        VALUE(rt_targets) TYPE tt_target_cfg.


ENDCLASS.



CLASS zcl_cd_ops_purge IMPLEMENTATION.

  METHOD cutoff_date.
    rv_date = iv_today - nmax( val1 = iv_days val2 = gc_min_days ).
  ENDMETHOD.


  METHOD run.
    DATA lv_cutoff_ts TYPE timestampl.

    DATA(lo_dao)   = zcl_cd_ops_factory=>get_purge_dao( ).
    DATA(lo_store) = zcl_cd_ops_factory=>get_store( ).
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    DATA(lv_today) = zcl_cd_ops_factory=>get_clock( )->today( ).
    DATA(lv_package) = nmax( val1 = zcl_cd_ops_util=>param_int( io_params  = lo_params
                                                                iv_name    = zif_cd_ops_types=>gc_param-purge_package
                                                                iv_default = zif_cd_ops_types=>gc_param_default-purge_package )
                             val2 = 1 ).

    LOOP AT targets( ) ASSIGNING FIELD-SYMBOL(<ls_target>).
      DATA(ls_result) = VALUE ty_result(
        target = <ls_target>-target
        days   = nmax( val1 = zcl_cd_ops_util=>param_int(
                                io_params  = lo_params
                                iv_name    = CONV #( |{ zif_cd_ops_types=>gc_param_prefix-retention_days }{ <ls_target>-target }| )
                                iv_default = <ls_target>-default_days )
                       val2 = gc_min_days ) ).
      ls_result-cutoff = cutoff_date( iv_today = lv_today iv_days = ls_result-days ).
      CONVERT DATE ls_result-cutoff TIME zif_cd_ops_types=>gc_time-day_start
        INTO TIME STAMP lv_cutoff_ts TIME ZONE zif_cd_ops_types=>gc_time_zone_utc.

      IF iv_test_mode = abap_true.
        ls_result-rows = lo_dao->count_purgeable( iv_target = <ls_target>-target
                                                  iv_cutoff = lv_cutoff_ts
                                                  iv_today  = lv_today ).
      ELSE.
        DO.
          DATA(lv_deleted) = lo_dao->delete_package( EXPORTING iv_target   = <ls_target>-target
                                                               iv_cutoff   = lv_cutoff_ts
                                                               iv_today    = lv_today
                                                               iv_max      = lv_package
                                                     IMPORTING ev_findings = DATA(lv_findings) ).
          lo_store->commit( ).
          ls_result-rows     += lv_deleted.
          ls_result-findings += lv_findings.
          IF lv_deleted < lv_package.
            EXIT.
          ENDIF.
        ENDDO.
      ENDIF.
      INSERT ls_result INTO TABLE rt_results.
    ENDLOOP.
  ENDMETHOD.


  METHOD targets.
    " RUN first: its findings are the largest table
    rt_targets = VALUE #( ( target = zif_cd_ops_purge_dao=>gc_target-run        default_days = 400 )
                          ( target = zif_cd_ops_purge_dao=>gc_target-alert_log  default_days = 180 )
                          ( target = zif_cd_ops_purge_dao=>gc_target-fmon_event default_days = 400 )
                          ( target = zif_cd_ops_purge_dao=>gc_target-hck_metric default_days = 400 )
                          ( target = zif_cd_ops_purge_dao=>gc_target-fmon_prism default_days = 400 )
                          ( target = zif_cd_ops_purge_dao=>gc_target-hck_result default_days = 400 ) ).
  ENDMETHOD.


ENDCLASS.
