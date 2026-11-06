*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_tech_sys.clas.abap
*& Purpose:
*& Technical health: short dumps of the day, update requests in error and
*& lock entries (count and age of the oldest lock).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - short dumps, update errors, locks</p>
"! Metrics (DIM1 '*'): SHORT_DUMPS (report date), UPDATE_ERRORS,
"! LOCK_ENTRIES, LOCK_MAX_AGE_MIN. Limits in ZCD_HCK_THRESH.
CLASS zcl_cd_hck_c_tech_sys DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_hck_check.

    CONSTANTS:
      BEGIN OF gc_metric,
        short_dumps   TYPE zif_cd_hck_types=>ty_metric_name VALUE 'SHORT_DUMPS',
        update_errors TYPE zif_cd_hck_types=>ty_metric_name VALUE 'UPDATE_ERRORS',
        lock_entries  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'LOCK_ENTRIES',
        lock_max_age  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'LOCK_MAX_AGE_MIN',
      END OF gc_metric.

ENDCLASS.



CLASS zcl_cd_hck_c_tech_sys IMPLEMENTATION.

  METHOD zif_cd_hck_check~execute.
    DATA(lo_dao) = zcl_cd_hck_factory=>get_dao( ).
    DATA(ls_locks) = lo_dao->read_lock_stats( iv_now_date = is_context-now_date
                                              iv_now_time = is_context-now_time ).
    rs_result-metrics = VALUE #(
      dim1 = zif_cd_hck_types=>gc_default_key
      ( metric = gc_metric-short_dumps   value = lo_dao->count_short_dumps( is_context-report_date ) )
      ( metric = gc_metric-update_errors value = lo_dao->count_update_errors( ) )
      ( metric = gc_metric-lock_entries  value = ls_locks-lock_entries )
      ( metric = gc_metric-lock_max_age  value = ls_locks-lock_max_age_min ) ).
  ENDMETHOD.

ENDCLASS.
