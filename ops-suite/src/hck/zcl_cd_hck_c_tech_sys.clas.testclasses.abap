*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_tech_sys.clas.testclasses.abap
*& Purpose:
*& Unit tests of the technical system check: short dumps, update errors and
*& lock statistics as '*' metrics, lock read error passed to the engine. The
*& DAO is a test double; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    CONSTANTS gc_reason TYPE i VALUE 8.
    DATA mv_dumps TYPE i.
    DATA mv_update_errors TYPE i.
    DATA ms_locks TYPE zif_cd_hck_types=>ty_tech_stat.
    DATA mv_lock_fails TYPE abap_bool.
    DATA mv_dump_date TYPE d.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~count_short_dumps.
    mv_dump_date = iv_date.
    rv_count = mv_dumps.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~count_update_errors.
    rv_count = mv_update_errors.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~read_lock_stats.
    IF mv_lock_fails = abap_true.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e313(zcd_ops) WITH gc_reason.
    ENDIF.
    rs_stat = ms_locks.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_tech_sys DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check   TYPE zif_cd_hck_types=>ty_check_id VALUE 'E_TECH_SYS',
      gc_dumps   TYPE i VALUE 3,
      gc_updates TYPE i VALUE 1,
      gc_locks   TYPE i VALUE 25,
      gc_age     TYPE i VALUE 90,
      gc_today   TYPE d VALUE '20261106'.

    TYPES:
      BEGIN OF ty_flags,
        load       TYPE abap_bool,
        lock_fails TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.

    METHODS setup.
    METHODS teardown.
    METHODS four_metrics_measured FOR TESTING.
    METHODS lock_read_error_raises FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_tech_sys IMPLEMENTATION.

  METHOD setup.
    mo_dao = NEW #( ).
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD configure_scenario.
    IF is_flags-load = abap_true.
      mo_dao->mv_dumps                  = gc_dumps.
      mo_dao->mv_update_errors          = gc_updates.
      mo_dao->ms_locks-lock_entries     = gc_locks.
      mo_dao->ms_locks-lock_max_age_min = gc_age.
    ENDIF.
    mo_dao->mv_lock_fails = is_flags-lock_fails.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_tech_sys( )->zif_cd_hck_check~execute(
      is_def        = VALUE #( check_id = gc_check )
      it_thresholds = VALUE #( )
      is_context    = VALUE #( report_date = gc_today now_date = gc_today ) ).
  ENDMETHOD.


  " Rule: dumps of the report date, update errors and lock statistics are '*' metrics;
  " the lock age is a level (aggregated by MAX, A88)
  METHOD four_metrics_measured.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        configure_scenario( VALUE #( load = abap_true ) ).
        INSERT VALUE #( metric = zcl_cd_hck_c_tech_sys=>gc_metric-short_dumps
                        dim1 = zif_cd_hck_types=>gc_default_key value = gc_dumps ) INTO TABLE lt_exp.
        INSERT VALUE #( metric = zcl_cd_hck_c_tech_sys=>gc_metric-update_errors
                        dim1 = zif_cd_hck_types=>gc_default_key value = gc_updates ) INTO TABLE lt_exp.
        INSERT VALUE #( metric = zcl_cd_hck_c_tech_sys=>gc_metric-lock_entries
                        dim1 = zif_cd_hck_types=>gc_default_key value = gc_locks ) INTO TABLE lt_exp.
        INSERT VALUE #( metric = zcl_cd_hck_c_tech_sys=>gc_metric-lock_max_age
                        dim1 = zif_cd_hck_types=>gc_default_key value = gc_age
                        kind = zif_cd_hck_types=>gc_metric_kind-level ) INTO TABLE lt_exp.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics exp = lt_exp msg = 'Four technical metrics' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_dump_date exp = gc_today
                                            msg = 'Dumps counted for the report date' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an unreadable lock table is raised to the engine (PLUGIN_ERROR), never measured as 0
  METHOD lock_read_error_raises.
    configure_scenario( VALUE #( lock_fails = abap_true ) ).
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'Lock read error must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Read error raised' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
