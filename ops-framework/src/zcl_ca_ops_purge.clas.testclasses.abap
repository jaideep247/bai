*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_purge.clas.testclasses.abap
*& Purpose:
*& Tests of the retention purge rules and orchestration with a DAO double:
*& retention has a floor, parameters drive the cutoff, test mode only counts,
*& deletion runs in packages with a commit per package. Written before the
*& class. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
*& 2026-11-07 | Store double: get_param / get_range delegate to the shared fake ZCL_CD_OPS_PARAMS_MEM
*&            | (semantics of ZCL_CA_OPS_STORE: condensed, blank = default).
*& 2026-11-07 | Parameters over ZCA_PARAM (zcl_ca_ops_param_seed injected with INJECT_PARAMS); the store double
*&            | serves no parameters.
*& 2026-11-07 | Comment: RETENTION_DAYS_RUN in ZCA_PARAM.
*& 2026-11-07 | Six purge targets (HCK_RESULT added): one more empty-target commit.
*& 2026-11-07 | Seven purge targets (PAY_OUTCOME added): one more empty-target commit.
*& 2026-11-10 | deletes_in_packages: exception history counted, target FMON_FILE (one more empty target).
*& 2026-11-10 | Moved from ZCL_CD_OPS_PURGE to the reusable framework ZCA_OPS: built-in targets RUN and
*&            | ALERT_LOG; registered_target_purged (registry row: plug-in double and its own retention
*&            | parameter); wrong_target_class_stops (nothing deleted when a registry class is no target).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_purge_dao.
    "! Registered consumer targets returned by get_targets
    DATA mt_targets TYPE zif_ca_ops_purge_dao=>tt_registry.
    "! Rows returned by successive delete_package calls (then 0)
    DATA mt_package_sizes TYPE STANDARD TABLE OF i WITH EMPTY KEY.
    DATA mv_count TYPE i.
    DATA mv_delete_calls TYPE i.
    DATA mv_count_calls TYPE i.
    DATA mv_last_cutoff TYPE timestampl.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_ca_ops_purge_dao~get_targets.
    rt_targets = mt_targets.
  ENDMETHOD.
  METHOD zif_ca_ops_purge_target~count_purgeable.
    mv_count_calls += 1.
    mv_last_cutoff = iv_cutoff.
    rv_count = mv_count.
  ENDMETHOD.
  METHOD zif_ca_ops_purge_target~delete_package.
    mv_delete_calls += 1.
    IF iv_target = zif_ca_ops_purge_dao=>gc_target-run.
      mv_last_cutoff = iv_cutoff.
      rv_count = VALUE #( mt_package_sizes[ mv_delete_calls ] OPTIONAL ).
      ev_dependent = rv_count * 2.
      ev_history  = rv_count.
    ENDIF.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_target DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_purge_target.
    DATA mv_count TYPE i.
    DATA mv_last_cutoff TYPE timestampl.
    DATA mv_target TYPE zif_ca_ops_purge_target=>ty_target.
ENDCLASS.

CLASS ltd_target IMPLEMENTATION.
  METHOD zif_ca_ops_purge_target~count_purgeable.
    mv_target      = iv_target.
    mv_last_cutoff = iv_cutoff.
    rv_count       = mv_count.
  ENDMETHOD.
  METHOD zif_ca_ops_purge_target~delete_package.
    CLEAR: ev_dependent, ev_history.
    mv_target = iv_target.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_store DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_store PARTIALLY IMPLEMENTED.
    "! Parameters over ZCA_PARAM (delivered definitions, in memory)
    DATA mo_params TYPE REF TO zcl_ca_ops_param_seed.
    DATA mv_commits TYPE i.
    METHODS constructor.
ENDCLASS.

CLASS ltd_store IMPLEMENTATION.
  METHOD constructor.
    mo_params = NEW #( ).
  ENDMETHOD.
  METHOD zif_ca_ops_store~commit.
    mv_commits += 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261106020000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261106'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '020000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_purge DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_today TYPE d VALUE '20261106'.
    CONSTANTS:
      BEGIN OF gc_reg,
        target TYPE zif_ca_ops_purge_target=>ty_target VALUE 'ZT_TARGET',
        class  TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_ZT_TARGET',
        "! An existing framework class that is no purge target
        wrong  TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CA_OPS_CLOCK',
        param  TYPE zif_ca_ops_types=>ty_param_name VALUE 'RETENTION_DAYS_ALERT_LOG',
        days   TYPE zif_ca_param_types=>ty_value VALUE '60',
        cutoff TYPE d VALUE '20260907',
      END OF gc_reg.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_store TYPE REF TO ltd_store.

    METHODS setup.
    METHODS teardown.
    METHODS run_result
      IMPORTING
        it_results       TYPE zcl_ca_ops_purge=>tt_result
      RETURNING
        VALUE(rs_result) TYPE zcl_ca_ops_purge=>ty_result.

    METHODS retention_has_a_floor      FOR TESTING.
    METHODS retention_days_set_cutoff  FOR TESTING.
    METHODS test_mode_only_counts      FOR TESTING.
    METHODS deletes_in_packages        FOR TESTING.
    METHODS retention_param_is_used    FOR TESTING.
    METHODS registered_target_purged   FOR TESTING.
    METHODS wrong_target_class_stops   FOR TESTING.
ENDCLASS.


CLASS ltc_purge IMPLEMENTATION.

  METHOD setup.
    mo_dao   = NEW #( ).
    mo_store = NEW #( ).
    zcl_ca_ops_injector=>inject_purge_dao( mo_dao ).
    zcl_ca_ops_injector=>inject_store( mo_store ).
    zcl_ca_ops_injector=>inject_params( mo_store->mo_params->params( ) ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_clock( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
    CLEAR: mo_dao, mo_store.
  ENDMETHOD.


  METHOD run_result.
    rs_result = VALUE #( it_results[ target = zif_ca_ops_purge_dao=>gc_target-run ] OPTIONAL ).
  ENDMETHOD.


  " Rule: a mistyped retention (0, 5 days) never purges recent evidence - 30 days minimum
  METHOD retention_has_a_floor.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_purge=>cutoff_date( iv_today = gc_today iv_days = 0 )
                                        exp = '20261007'
                                        msg = 'Retention below 30 days must be raised to 30' ).
  ENDMETHOD.


  " Rule: rows older than today minus the retention days are purgeable
  METHOD retention_days_set_cutoff.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_purge=>cutoff_date( iv_today = gc_today iv_days = 400 )
                                        exp = '20251002'
                                        msg = 'Cutoff must be today minus the retention days' ).
  ENDMETHOD.


  " Rule: test mode reports what would be deleted and changes nothing
  METHOD test_mode_only_counts.
    TRY.
        mo_dao->mv_count = 7.
        DATA(lt_results) = NEW zcl_ca_ops_purge( )->run( abap_true ).
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
        mo_store->mo_params->set( iv_name = 'PURGE_PACKAGE_SIZE' iv_value = '2' ).
        mo_dao->mt_package_sizes = VALUE #( ( 2 ) ( 2 ) ( 1 ) ).
        DATA(ls_run) = run_result( NEW zcl_ca_ops_purge( )->run( abap_false ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-rows exp = 5 msg = 'All packages must be counted' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-history exp = 5
                                            msg = 'Exception history purged with the findings is counted' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-dependent exp = 10 msg = 'Deleted findings must be counted' ).
        cl_abap_unit_assert=>assert_equals( act = mo_store->mv_commits exp = 4
                                            msg = 'One commit per package of every target (3 + ALERT_LOG empty)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: RETENTION_DAYS_RUN in ZCA_PARAM decides the cutoff, not code
  METHOD retention_param_is_used.
    TRY.
        mo_store->mo_params->set( iv_name = 'RETENTION_DAYS_RUN' iv_value = '100' ).
        DATA(ls_run) = run_result( NEW zcl_ca_ops_purge( )->run( abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-cutoff exp = '20260729'
                                            msg = 'The parameter must set the cutoff date' ).
        cl_abap_unit_assert=>assert_equals( act = ls_run-days exp = 100 msg = 'The parameter must be reported' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Registry: a consumer target is purged by its plug-in with its own retention parameter
  METHOD registered_target_purged.
    TRY.
        DATA(lo_target) = NEW ltd_target( ).
        lo_target->mv_count = 3.
        zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc_reg-class io_instance = lo_target ).
        mo_dao->mt_targets = VALUE #( ( target     = gc_reg-target
                                        class_name = gc_reg-class
                                        param_area = zif_ca_ops_types=>gc_param_area
                                        param_name = gc_reg-param ) ).
        mo_store->mo_params->set( iv_name = gc_reg-param iv_value = gc_reg-days ).
        DATA(lt_results) = NEW zcl_ca_ops_purge( )->run( abap_true ).
        DATA(ls_result) = VALUE #( lt_results[ target = gc_reg-target ] OPTIONAL ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-rows exp = 3 msg = 'The plug-in counts its rows' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-cutoff exp = gc_reg-cutoff
                                            msg = 'The registered parameter sets the cutoff' ).
        cl_abap_unit_assert=>assert_equals( act = lo_target->mv_target exp = gc_reg-target
                                            msg = 'The plug-in is asked for its target' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Registry: a class that is no purge target stops the run before anything is deleted
  METHOD wrong_target_class_stops.
    mo_dao->mt_targets = VALUE #( ( target = gc_reg-target class_name = gc_reg-wrong
                                    param_area = zif_ca_ops_types=>gc_param_area param_name = gc_reg-param ) ).
    TRY.
        NEW zcl_ca_ops_purge( )->run( abap_false ).
        cl_abap_unit_assert=>fail( msg = 'A wrong target class must stop the purge' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '032'
                                            msg = 'Class does not implement the target interface (032)' ).
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_delete_calls exp = 0 msg = 'Nothing is deleted' ).
  ENDMETHOD.

ENDCLASS.
