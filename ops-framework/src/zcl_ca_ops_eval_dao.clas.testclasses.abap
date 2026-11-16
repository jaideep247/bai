*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_eval_dao.clas.testclasses.abap
*& Purpose:
*& Tests of the evaluation records on doubled ZCA_OPS_EVAL / ZCA_OPS_EVALSRC
*& (ABAP SQL test environment): a complete record is its own last valid
*& result; a partial record names the latest complete record of its
*& check; sources are stored with their verdict; LATEST returns the newest
*& record of every check. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-16 | Initial version (build O: evaluation state of every control).
*&---------------------------------------------------------------------*
CLASS ltc_eval_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_eval_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS last_valid_result FOR TESTING RAISING zcx_ca_ops_error.
    METHODS latest_per_check  FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_eval_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCA_OPS_EVAL' ) ( 'ZCA_OPS_EVALSRC' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_eval_dao( ).
  ENDMETHOD.


  METHOD last_valid_result.
    mo_cut->save( VALUE #( ( run_id = '00000000000000000000000000000001' check_id = 'ZT_CHECK' area = 'ZT_OPS_A'
                             evaluated_at = '20261116070000.0000000' completeness = 'C' result_class = 'OK'
                             eval_state = 'OK' ) ) ).
    mo_cut->save( VALUE #( ( run_id = '00000000000000000000000000000002' check_id = 'ZT_CHECK' area = 'ZT_OPS_A'
                             evaluated_at = '20261116080000.0000000' completeness = 'P' result_class = 'OK'
                             eval_state = 'PARTIAL'
                             sources = VALUE #( ( source_id = 'ZT_SRC' newest_at = '20261116060000.0000000'
                                                  stale_min = 60 is_stale = abap_true ) ) ) ) ).
    DATA(lt_latest) = mo_cut->latest( 'ZT_OPS_A' ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_latest ) exp = 1 msg = 'One check' ).
    cl_abap_unit_assert=>assert_equals( act = lt_latest[ 1 ]-eval_state exp = 'PARTIAL' msg = 'Latest record' ).
    cl_abap_unit_assert=>assert_equals( act = lt_latest[ 1 ]-last_valid_run
                                        exp = CONV zif_ca_ops_types=>ty_run_id( '00000000000000000000000000000001' )
                                        msg = 'Last valid = the latest complete run' ).
    cl_abap_unit_assert=>assert_equals( act = lt_latest[ 1 ]-last_valid_cls exp = 'OK' msg = 'Its result' ).
    SELECT COUNT(*) FROM zca_ops_evalsrc WHERE check_id = 'ZT_CHECK' AND is_stale = 'X' INTO @DATA(lv_sources).
    cl_abap_unit_assert=>assert_equals( act = lv_sources exp = 1 msg = 'Source stored with its verdict' ).
  ENDMETHOD.


  METHOD latest_per_check.
    mo_cut->save( VALUE #( ( run_id = '00000000000000000000000000000003' check_id = 'ZT_ONE' area = 'ZT_OPS_A'
                             evaluated_at = '20261116070000.0000000' completeness = 'C' result_class = 'OK' )
                           ( run_id = '00000000000000000000000000000003' check_id = 'ZT_TWO' area = 'ZT_OPS_A'
                             evaluated_at = '20261116070000.0000000' completeness = 'N' result_class = 'NOT_EVAL' ) ) ).
    DATA(lt_latest) = mo_cut->latest( ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_latest ) exp = 2 msg = 'Every check' ).
    cl_abap_unit_assert=>assert_equals( act = lt_latest[ check_id = 'ZT_ONE' ]-last_valid_run
                                        exp = CONV zif_ca_ops_types=>ty_run_id( '00000000000000000000000000000003' )
                                        msg = 'Complete: itself' ).
    cl_abap_unit_assert=>assert_initial( act = lt_latest[ check_id = 'ZT_TWO' ]-last_valid_run
                                         msg = 'Never complete: no last valid result' ).
  ENDMETHOD.

ENDCLASS.
