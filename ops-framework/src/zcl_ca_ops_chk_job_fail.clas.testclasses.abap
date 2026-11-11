*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_job_fail.clas.testclasses.abap
*& Purpose:
*& Test of the registered check SAP job failures through
*& ZIF_CA_OPS_CHECK~RUN with doubles of the job monitor's data access and
*& job log reader: a cancelled job is one JOB_ABORTED finding and the
*& result is partial (incremental check, no auto-resolve). The rules are
*& tested in ZCL_CA_OPS_JOB_MONITOR. Does not prove live SAP runtime
*& behavior.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_dao PARTIALLY IMPLEMENTED.
    DATA mv_saves TYPE i.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_ca_ops_job_dao~watermark.
    rs_watermark-area     = iv_area.
    rs_watermark-check_id = iv_check_id.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~aborted_jobs.
    IF iv_max > 0 AND is_window-to IS NOT INITIAL.
      rt_jobs = VALUE #( ( jobname = 'ZT_JOB' jobcount = '10000001' status = zif_ca_ops_job_types=>gc_status-aborted
                           enddate = '20261111' endtime = '093000' ) ).
    ENDIF.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~finished_jobs.
    CLEAR rt_jobs.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~reported.
    CLEAR rt_keys.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~jobs.
    CLEAR rt_jobs.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~steps.
    CLEAR rt_steps.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~scheduler_jobs.
    CLEAR rt_sched.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~applogs.
    CLEAR rt_applogs.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~save.
    mv_saves += 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_log DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_log.
ENDCLASS.

CLASS ltd_log IMPLEMENTATION.
  METHOD zif_ca_ops_job_log~read.
    CLEAR rt_lines.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_chk_job_fail DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS setup.
    METHODS teardown.
    METHODS cancelled_job_is_partial FOR TESTING.
ENDCLASS.


CLASS ltc_chk_job_fail IMPLEMENTATION.

  METHOD setup.
    DATA(lo_seed) = NEW zcl_ca_ops_param_seed( ).
    lo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-resolvers iv_value = space ).
    zcl_ca_ops_injector=>inject_params( lo_seed->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  " Rule: the check delivers the monitor's findings and is partial (incremental)
  METHOD cancelled_job_is_partial.
    TRY.
        DATA(lo_dao) = NEW ltd_dao( ).
        DATA(ls_result) = CAST zif_ca_ops_check( NEW zcl_ca_ops_chk_job_fail( io_dao = lo_dao io_log = NEW ltd_log( ) )
                          )->run( is_check   = VALUE #( area = 'ZT_OPS_A' check_id = 'ZT_JOB_FAIL' )
                                  is_context = VALUE #( area = 'ZT_OPS_A' today = '20261111' test_mode = abap_true ) ).
        cl_abap_unit_assert=>assert_equals( act = lo_dao->mv_saves exp = 0 msg = 'Test mode saves nothing' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_ca_ops_job_types=>gc_code-aborted msg = 'Cancelled job' ).
        cl_abap_unit_assert=>assert_true( act = ls_result-partial msg = 'Incremental check' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
