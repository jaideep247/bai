*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_purge.clas.abap
*& Purpose:
*& Retention purge of the suite's own history: runs with their findings, alert
*& log, FMON events, HCK metrics. Retention days per target in ZCD_OPS_PARAM
*& (RETENTION_DAYS_<target>), never below 30 days. Test mode counts only;
*& otherwise deletes package by package with a commit per package. Runs that
*& still hold an open, assigned or validly waived exception are never purged
*& (rule in the DAO). Does not purge customizing or legacy tables.
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - retention purge</p>
CLASS zcl_cd_ops_purge DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Retention never below this many days (protects against a mistyped parameter)
    CONSTANTS gc_min_days TYPE i VALUE 30.
    CONSTANTS gc_default_package TYPE i VALUE 1000.

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

    METHODS int_param
      IMPORTING
        iv_name         TYPE zif_cd_ops_types=>ty_param_name
        iv_default      TYPE i
      RETURNING
        VALUE(rv_value) TYPE i.

ENDCLASS.



CLASS zcl_cd_ops_purge IMPLEMENTATION.

  METHOD cutoff_date.
    rv_date = iv_today - nmax( val1 = iv_days val2 = gc_min_days ).
  ENDMETHOD.


  METHOD run.
    DATA lv_cutoff_ts TYPE timestampl.

    DATA(lo_dao)   = zcl_cd_ops_factory=>get_purge_dao( ).
    DATA(lo_store) = zcl_cd_ops_factory=>get_store( ).
    DATA(lv_today) = zcl_cd_ops_factory=>get_clock( )->today( ).
    DATA(lv_package) = nmax( val1 = int_param( iv_name = 'PURGE_PACKAGE_SIZE' iv_default = gc_default_package )
                             val2 = 1 ).

    LOOP AT targets( ) INTO DATA(ls_target).
      DATA(ls_result) = VALUE ty_result(
        target = ls_target-target
        days   = nmax( val1 = int_param( iv_name    = CONV #( |RETENTION_DAYS_{ ls_target-target }| )
                                         iv_default = ls_target-default_days )
                       val2 = gc_min_days ) ).
      ls_result-cutoff = cutoff_date( iv_today = lv_today iv_days = ls_result-days ).
      CONVERT DATE ls_result-cutoff TIME zif_cd_ops_types=>gc_time-day_start
        INTO TIME STAMP lv_cutoff_ts TIME ZONE zif_cd_ops_types=>gc_time_zone_utc.

      IF iv_test_mode = abap_true.
        ls_result-rows = lo_dao->count_purgeable( iv_target = ls_target-target
                                                  iv_cutoff = lv_cutoff_ts
                                                  iv_today  = lv_today ).
      ELSE.
        DO.
          DATA(lv_deleted) = lo_dao->delete_package( EXPORTING iv_target   = ls_target-target
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
                          ( target = zif_cd_ops_purge_dao=>gc_target-hck_metric default_days = 400 ) ).
  ENDMETHOD.


  METHOD int_param.
    DATA(lv_text) = zcl_cd_ops_factory=>get_store( )->get_param( iv_name    = iv_name
                                                                 iv_default = |{ iv_default }| ).
    rv_value = zcl_cd_ops_util=>to_decimal( iv_value = lv_text iv_default = iv_default ).
  ENDMETHOD.

ENDCLASS.
