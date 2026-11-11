*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_job_state.clas.testclasses.abap
*& Purpose:
*& Test of the registered check long-running / waiting jobs through
*& ZIF_CA_OPS_CHECK~RUN with a data access double: nothing active or
*& waiting = no finding and a complete result (earlier exceptions are
*& resolved by the runner). The rules are tested in ZCL_CA_OPS_JOB_MONITOR.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_dao PARTIALLY IMPLEMENTED.
    DATA mv_saves TYPE i.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_ca_ops_job_dao~active_jobs.
    CLEAR rt_jobs.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~waiting_jobs.
    CLEAR rt_jobs.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~save.
    mv_saves += 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_job_state DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS nothing_waiting_complete FOR TESTING.
ENDCLASS.


CLASS ltc_chk_job_state IMPLEMENTATION.

  METHOD setup.
    zcl_ca_ops_injector=>inject_params( NEW zcl_ca_ops_param_seed( )->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  " Rule: a complete snapshot without long-running or waiting jobs raises nothing and is not partial
  METHOD nothing_waiting_complete.
    TRY.
        DATA(lo_dao) = NEW ltd_dao( ).
        DATA(ls_result) = CAST zif_ca_ops_check( NEW zcl_ca_ops_chk_job_state( io_dao = lo_dao )
                          )->run( is_check   = VALUE #( area = 'ZT_OPS_A' check_id = 'ZT_JOB_STATE' )
                                  is_context = VALUE #( area = 'ZT_OPS_A' today = '20261111' test_mode = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = lo_dao->mv_saves exp = 0 msg = 'Test mode saves nothing' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'Nothing to report' ).
        cl_abap_unit_assert=>assert_false( act = ls_result-partial msg = 'Complete: the runner may resolve' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
