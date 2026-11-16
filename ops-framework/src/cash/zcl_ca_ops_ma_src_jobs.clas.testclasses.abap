*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_ma_src_jobs.clas.testclasses.abap
*& Purpose:
*& Runs of a mass activity from SAP's job tables: the parent job is a job
*& of the activity's names that ran since the date (another name is not);
*& its intervals are the jobs the resolvers link to it, numbered in the
*& order they were created, with their state from the job status (F OK,
*& A FAILED, R RUNNING, S WAITING) and their minutes; the run date is the
*& parent's start date, the run ID unknown, the quality probable; a parent
*& pattern that does not compile raises (the check reports it). Doubles:
*& job monitor data access, a resolver plug-in, the job log reader.
*& Modification log:
*& 2026-11-16 | Initial version (build P: FI-CA mass-activity intervals and their output).
*&---------------------------------------------------------------------*
CLASS ltd_src_jobs_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_dao PARTIALLY IMPLEMENTED.
    DATA mt_running TYPE zif_ca_ops_job_types=>tt_job.
    DATA mt_children TYPE zif_ca_ops_job_types=>tt_job.
ENDCLASS.

CLASS ltd_src_jobs_dao IMPLEMENTATION.
  METHOD zif_ca_ops_job_dao~jobs_running.
    rt_jobs = mt_running.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~jobs.
    rt_jobs = mt_children.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_src_jobs_resolver DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_resolver.
    DATA mt_links TYPE zif_ca_ops_job_types=>tt_link.
ENDCLASS.

CLASS ltd_src_jobs_resolver IMPLEMENTATION.
  METHOD zif_ca_ops_job_resolver~id.
    rv_id = 'ZT_RES'.
  ENDMETHOD.
  METHOD zif_ca_ops_job_resolver~parents.
    CLEAR rt_links.
  ENDMETHOD.
  METHOD zif_ca_ops_job_resolver~children.
    rt_links = mt_links.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_src_jobs_log DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_log PARTIALLY IMPLEMENTED.
ENDCLASS.

CLASS ltd_src_jobs_log IMPLEMENTATION.
ENDCLASS.


CLASS ltd_src_jobs_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_src_jobs_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261112090000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261112'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '090000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_ma_src_jobs DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        resolver TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZT_MA_RESOLVER',
        rundate  TYPE d VALUE '20261112',
      END OF gc.

    DATA mo_dao TYPE REF TO ltd_src_jobs_dao.
    DATA mo_resolver TYPE REF TO ltd_src_jobs_resolver.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.
    DATA mo_cut TYPE REF TO zif_ca_ops_ma_src.

    METHODS setup.
    METHODS teardown.
    METHODS activity
      IMPORTING
        iv_pattern         TYPE zif_ca_ops_types=>ty_object_key DEFAULT 'ZT_FPY1_.*'
      RETURNING
        VALUE(rs_activity) TYPE zif_ca_ops_ma_types=>ty_activity.
    METHODS child
      IMPORTING
        iv_count      TYPE btcjobcnt
        iv_status     TYPE zif_ca_ops_job_types=>ty_status
        iv_created    TYPE t
      RETURNING
        VALUE(rs_job) TYPE zif_ca_ops_job_types=>ty_job.

    METHODS parent_and_intervals      FOR TESTING RAISING zcx_ca_ops_error.
    METHODS other_names_not_a_run     FOR TESTING RAISING zcx_ca_ops_error.
    METHODS invalid_pattern_raises    FOR TESTING.
    METHODS states_from_job_status    FOR TESTING.
ENDCLASS.


CLASS ltc_ma_src_jobs IMPLEMENTATION.

  METHOD setup.
    mo_dao      = NEW #( ).
    mo_resolver = NEW #( ).
    mo_seed     = NEW #( ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_src_jobs_clock( ) ).
    zcl_ca_ops_injector=>inject_plugin( iv_class_name = gc-resolver io_instance = mo_resolver ).
    mo_seed->set( iv_name = zif_ca_ops_ma_types=>gc_param-resolvers iv_value = gc-resolver ).
    mo_cut = NEW zcl_ca_ops_ma_src_jobs( io_dao = mo_dao io_log = NEW ltd_src_jobs_log( ) ).
    mo_dao->mt_running = VALUE #( ( jobname = 'ZT_FPY1_PAY01' jobcount = '06000001' status = 'F'
                                    strtdate = gc-rundate strttime = '060000' enddate = gc-rundate endtime = '063000' ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD activity.
    rs_activity = VALUE #( act_id = 'PAYRUN' aktyp = 'ZPAY' job_pattern = iv_pattern output_kind = 'PAYDOC' ).
  ENDMETHOD.


  METHOD child.
    rs_job = VALUE #( jobname = 'ZT_FPY1_PAY01_W' jobcount = iv_count status = iv_status
                      sdldate = gc-rundate sdltime = iv_created strtdate = gc-rundate strttime = iv_created
                      enddate = COND #( WHEN iv_status = 'F' OR iv_status = 'A' THEN gc-rundate )
                      endtime = COND #( WHEN iv_status = 'F' OR iv_status = 'A' THEN '062000' ) ).
  ENDMETHOD.


  " Rule: the parent and its three intervals in creation order; interval 2 cancelled; run date = start date
  METHOD parent_and_intervals.
    mo_dao->mt_children = VALUE #( ( child( iv_count = '06010003' iv_status = 'F' iv_created = '060300' ) )
                                   ( child( iv_count = '06010001' iv_status = 'F' iv_created = '060100' ) )
                                   ( child( iv_count = '06010002' iv_status = 'A' iv_created = '060200' ) ) ).
    mo_resolver->mt_links = VALUE #( FOR ls IN mo_dao->mt_children
                                     ( parent_name = 'ZT_FPY1_PAY01' parent_count = '06000001'
                                       child_name  = ls-jobname      child_count  = ls-jobcount
                                       resolver    = 'ZT_RES'        quality      = 'P' ) ).

    DATA(ls_runs) = mo_cut->runs( is_activity = activity( ) iv_from = '20261110' iv_max = 100 ).

    cl_abap_unit_assert=>assert_equals( act = lines( ls_runs-runs ) exp = 1 ).
    DATA(ls_run) = ls_runs-runs[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_run-run_date exp = gc-rundate ).
    cl_abap_unit_assert=>assert_initial( ls_run-run_id ).
    cl_abap_unit_assert=>assert_equals( act = ls_run-quality exp = zif_ca_ops_exc_contract=>gc_quality-probable ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_run-intervals ) exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = ls_run-intervals[ 2 ]-job-jobcount exp = '06010002' ).
    cl_abap_unit_assert=>assert_equals( act = ls_run-intervals[ 2 ]-state exp = zif_ca_ops_ma_types=>gc_state-failed ).
    cl_abap_unit_assert=>assert_equals( act = ls_run-intervals[ 1 ]-minutes exp = 19 ).
  ENDMETHOD.


  " Rule: a job of other names is no run of the activity
  METHOD other_names_not_a_run.
    DATA(ls_runs) = mo_cut->runs( is_activity = activity( 'ZT_DUNNING_.*' ) iv_from = '20261110' iv_max = 100 ).
    cl_abap_unit_assert=>assert_initial( ls_runs-runs ).
  ENDMETHOD.


  " Rule: a parent pattern that does not compile is never "no run"
  METHOD invalid_pattern_raises.
    TRY.
        mo_cut->runs( is_activity = activity( '(' ) iv_from = '20261110' iv_max = 100 ).
        cl_abap_unit_assert=>fail( 'invalid pattern accepted' ).
      CATCH zcx_ca_ops_error.
        RETURN.
    ENDTRY.
  ENDMETHOD.


  " Rule: F = OK, A = FAILED, R / Z = RUNNING, S / Y / P = WAITING (job monitor's status values, VERIFY V58)
  METHOD states_from_job_status.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_ma_src_jobs=>state_of( VALUE #( status = 'F' ) )
                                        exp = zif_ca_ops_ma_types=>gc_state-ok ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_ma_src_jobs=>state_of( VALUE #( status = 'A' ) )
                                        exp = zif_ca_ops_ma_types=>gc_state-failed ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_ma_src_jobs=>state_of( VALUE #( status = 'Z' ) )
                                        exp = zif_ca_ops_ma_types=>gc_state-running ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_ma_src_jobs=>state_of( VALUE #( status = 'S' ) )
                                        exp = zif_ca_ops_ma_types=>gc_state-waiting ).
  ENDMETHOD.

ENDCLASS.
