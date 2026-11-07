*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_purge.clas.testclasses.abap
*& Purpose:
*& Tests of the retention purge rules and orchestration with a DAO double:
*& retention has a floor, parameters drive the cutoff, test mode only counts,
*& deletion runs in packages with a commit per package. Written before the
*& class. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
*& 2026-11-07 | Store double: get_param / get_range delegate to the shared fake ZCL_CD_OPS_PARAMS_MEM
*&            | (semantics of ZCL_CD_OPS_STORE: condensed, blank = default).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_purge_dao.
    "! Rows returned by successive delete_package calls (then 0)
    DATA mt_package_sizes TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    DATA mv_count TYPE i.
    DATA mv_delete_calls TYPE i.
    DATA mv_count_calls TYPE i.
    DATA mv_last_cutoff TYPE timestampl.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_ops_purge_dao~count_purgeable.
    mv_count_calls += 1.
    mv_last_cutoff = iv_cutoff.
    rv_count = mv_count.
  ENDMETHOD.
  METHOD zif_cd_ops_purge_dao~delete_package.
    mv_delete_calls += 1.
    IF iv_target = zif_cd_ops_purge_dao=>gc_target-run.
      mv_last_cutoff = iv_cutoff.
      rv_count = VALUE #( mt_package_sizes[ mv_delete_calls ] OPTIONAL ).
      ev_findings = rv_count * 2.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_store PARTIALLY IMPLEMENTED.
    DATA mt_params TYPE zif_cd_ops_types=>tt_kv.
    DATA mv_commits TYPE i.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD zif_cd_ops_params~get_param.
    " Shared parameter fake: exactly the read semantics of ZCL_CD_OPS_STORE
    rv_value = NEW zcl_cd_ops_params_mem( mt_params )->zif_cd_ops_params~get_param( iv_name    = iv_name
                                                                                     iv_default = iv_default ).
  ENDMETHOD.
  METHOD zif_cd_ops_params~get_range.
    rt_range = NEW zcl_cd_ops_params_mem( mt_params )->zif_cd_ops_params~get_range( iv_name ).
  ENDMETHOD.
  METHOD zif_cd_ops_store~commit.
    mv_commits += 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = '20261106020000.0000000'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~today.
    rv_date = '20261106'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~time.
    rv_time = '020000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_purge DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_today TYPE d VALUE '20261106'.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_store TYPE REF TO ltd_store.

    METHODS setup.
    METHODS teardown.
    METHODS run_result
      IMPORTING
        it_results       TYPE zcl_cd_ops_purge=>tt_result
      RETURNING
        VALUE(rs_result) TYPE zcl_cd_ops_purge=>ty_result.

    METHODS retention_has_a_floor      FOR TESTING.
    METHODS retention_days_set_cutoff  FOR TESTING.
    METHODS test_mode_only_counts      FOR TESTING.
    METHODS deletes_in_packages        FOR TESTING.
    METHODS retention_param_is_used    FOR TESTING.
ENDCLASS.


CLASS ltc_purge IMPLEMENTATION.

  METHOD setup.
    mo_dao   = NEW #( ).
    mo_store = NEW #( ).
    zcl_cd_ops_injector=>inject_purge_dao( mo_dao ).
    zcl_cd_ops_injector=>inject_store( mo_store ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_store.
  ENDMETHOD.


  METHOD run_result.
    rs_result = VALUE #( it_results[ target = zif_cd_ops_purge_dao=>gc_target-run ] OPTIONAL ).
  ENDMETHOD.


  " Rule: a mistyped retention (0, 5 days) never purges recent evidence - 30 days minimum
  METHOD retention_has_a_floor.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_purge=>cutoff_date( iv_today = gc_today iv_days = 0 )
                                        exp = '20261007'
                                        msg = 'Retention below 30 days must be raised to 30' ).
  ENDMETHOD.


  " Rule: rows older than today minus the retention days are purgeable
  METHOD retention_days_set_cutoff.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_purge=>cutoff_date( iv_today = gc_today iv_days = 400 )
                                        exp = '20251002'
                                        msg = 'Cutoff must be today minus the retention days' ).
  ENDMETHOD.


  " Rule: test mode reports what would be deleted and changes nothing
  METHOD test_mode_only_counts.
    TRY.
        mo_dao->mv_count = 7.
        DATA(lt_results) = NEW zcl_cd_ops_purge( )->run( abap_true ).
        cl_abap_unit_assert=>assert_equals( act = run_result( lt_results )-rows exp = 7
                                            msg = 'Test mode must report the purgeable rows' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_delete_calls exp = 0 msg = 'Test mode must not delete' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 0 msg = 'Test mode must not commit' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: deletion runs in packages with a commit per package until a short package
  METHOD deletes_in_packages.
    TRY.
        INSERT VALUE #( name = 'PURGE_PACKAGE_SIZE' value = '2' ) INTO TABLE mo_store->mt_params.
        mo_dao->mt_package_sizes = VALUE #( ( 2 ) ( 2 ) ( 1 ) ).
        DATA(ls_run) = run_result( NEW zcl_cd_ops_purge( )->run( abap_false ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-rows exp = 5 msg = 'All packages must be counted' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-findings exp = 10 msg = 'Deleted findings must be counted' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 7
                                            msg = 'One commit per package of every target (3 + 4 empty targets)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: RETENTION_DAYS_RUN in ZCD_OPS_PARAM decides the cutoff, not code
  METHOD retention_param_is_used.
    TRY.
        INSERT VALUE #( name = 'RETENTION_DAYS_RUN' value = '100' ) INTO TABLE mo_store->mt_params.
        DATA(ls_run) = run_result( NEW zcl_cd_ops_purge( )->run( abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-cutoff exp = '20260729'
                                            msg = 'The parameter must set the cutoff date' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-days exp = 100 msg = 'The parameter must be reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
