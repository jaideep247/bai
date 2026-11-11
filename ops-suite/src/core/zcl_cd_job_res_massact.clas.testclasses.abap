*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_job_res_massact.clas.testclasses.abap
*& Purpose:
*& Unit tests of the mass activity resolver with a double of the job
*& monitor's data access and a clock double: blank JOB_MA_WORKER_PCRE is
*& off; a worker's parent is the scheduler job that ran when it was created
*& with the worker's scheduling user and the same run token (quality P);
*& a scheduler of another run token is no parent; the children of a
*& scheduler job are its workers. Does not prove live SAP runtime behavior
*& (VERIFY-SE11 V67: the real job naming).
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor adoption, area CD_JOBS).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_dao PARTIALLY IMPLEMENTED.
    DATA mt_running TYPE zif_ca_ops_job_types=>tt_job.
    DATA mt_created TYPE zif_ca_ops_job_types=>tt_job.
    DATA mt_steps TYPE zif_ca_ops_job_types=>tt_step.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_ca_ops_job_dao~jobs_running.
    IF it_programs IS NOT INITIAL.
      rt_jobs = mt_running.
    ENDIF.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~jobs_created.
    rt_jobs = mt_created.
    DELETE rt_jobs FROM iv_max + 1.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~steps.
    LOOP AT mt_steps ASSIGNING FIELD-SYMBOL(<ls_step>).
      IF line_exists( it_keys[ jobname = <ls_step>-jobname jobcount = <ls_step>-jobcount ] ).
        INSERT <ls_step> INTO TABLE rt_steps.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_clock.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_ca_ops_clock~now.
    rv_timestamp = '20261111100000.0000000'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~today.
    rv_date = '20261111'.
  ENDMETHOD.
  METHOD zif_ca_ops_clock~time.
    rv_time = '100000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_res_massact DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_worker_pcre TYPE string VALUE `ZT_MA_(\w+)_W\d+`,
      gc_sched_pcre  TYPE string VALUE `ZT_MA_(\w+)`,
      gc_worker      TYPE btcjob VALUE 'ZT_MA_RUN1_W01',
      gc_scheduler   TYPE btcjob VALUE 'ZT_MA_RUN1',
      gc_other       TYPE btcjob VALUE 'ZT_MA_RUN2',
      gc_count       TYPE btcjobcnt VALUE '10000001',
      gc_user        TYPE syuname VALUE 'ZT_BATCH',
      gc_today       TYPE d VALUE '20261111'.

    DATA mo_seed TYPE REF TO zcl_cd_ops_param_seed.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_cut TYPE REF TO zif_ca_ops_job_resolver.

    METHODS setup.
    METHODS teardown.
    METHODS scheduler
      IMPORTING
        iv_name TYPE btcjob.
    METHODS worker
      RETURNING
        VALUE(rs_job) TYPE zif_ca_ops_job_types=>ty_job.

    METHODS blank_pattern_is_off    FOR TESTING.
    METHODS parent_of_the_same_run  FOR TESTING.
    METHODS other_run_is_no_parent  FOR TESTING.
    METHODS workers_are_children    FOR TESTING.
ENDCLASS.


CLASS ltc_res_massact IMPLEMENTATION.

  METHOD setup.
    mo_seed = NEW #( ).
    zcl_cd_ops_injector=>inject_params( mo_seed->params( ) ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    mo_dao = NEW #( ).
    mo_cut = NEW zcl_cd_job_res_massact( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD scheduler.
    INSERT VALUE #( jobname = iv_name jobcount = gc_count status = zif_ca_ops_job_types=>gc_status-finished
                    strtdate = gc_today strttime = '090000' enddate = gc_today endtime = '093000' )
      INTO TABLE mo_dao->mt_running.
    INSERT VALUE #( jobname = iv_name jobcount = gc_count stepcount = 1 progname = 'RFKK_MA_SCHEDULER'
                    authcknam = gc_user ) INTO TABLE mo_dao->mt_steps.
  ENDMETHOD.


  METHOD worker.
    rs_job = VALUE #( jobname = gc_worker jobcount = gc_count status = zif_ca_ops_job_types=>gc_status-aborted
                      sdldate = gc_today sdltime = '091000' sdluname = gc_user ).
  ENDMETHOD.


  " Rule: delivered off - no worker pattern, no link
  METHOD blank_pattern_is_off.
    scheduler( gc_scheduler ).
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->parents( it_jobs = VALUE #( ( worker( ) ) ) is_config = VALUE #( max_jobs = 100 )
                                 io_dao = mo_dao io_log = VALUE #( ) )
          msg = 'Off' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the scheduler job of the same run token, running at the worker's creation, is the parent (P)
  METHOD parent_of_the_same_run.
    mo_seed->set( iv_name = zif_cd_job_types=>gc_param-ma_worker_pcre iv_value = gc_worker_pcre ).
    mo_seed->set( iv_name = zif_cd_job_types=>gc_param-ma_sched_pcre iv_value = gc_sched_pcre ).
    scheduler( gc_scheduler ).
    scheduler( gc_other ).
    TRY.
        DATA(lt_links) = mo_cut->parents( it_jobs = VALUE #( ( worker( ) ) ) is_config = VALUE #( max_jobs = 100 )
                                          io_dao = mo_dao io_log = VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_links ) exp = 1 msg = 'One parent despite two schedulers' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-parent_name exp = gc_scheduler msg = 'Same run token' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-resolver exp = zif_cd_job_types=>gc_resolver_mass
                                            msg = 'Mass activity resolver' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-quality exp = zif_ca_ops_job_types=>gc_quality-probable
                                            msg = 'Probable' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a scheduler of another run is no parent
  METHOD other_run_is_no_parent.
    mo_seed->set( iv_name = zif_cd_job_types=>gc_param-ma_worker_pcre iv_value = gc_worker_pcre ).
    mo_seed->set( iv_name = zif_cd_job_types=>gc_param-ma_sched_pcre iv_value = gc_sched_pcre ).
    scheduler( gc_other ).
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->parents( it_jobs = VALUE #( ( worker( ) ) ) is_config = VALUE #( max_jobs = 100 )
                                 io_dao = mo_dao io_log = VALUE #( ) )
          msg = 'Other run token' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the workers created during a scheduler job's run are its children
  METHOD workers_are_children.
    mo_seed->set( iv_name = zif_cd_job_types=>gc_param-ma_worker_pcre iv_value = gc_worker_pcre ).
    scheduler( gc_scheduler ).
    INSERT worker( ) INTO TABLE mo_dao->mt_created.
    INSERT VALUE #( jobname = 'ZT_NOT_A_WORKER' jobcount = gc_count sdldate = gc_today sdltime = '091500'
                    sdluname = gc_user ) INTO TABLE mo_dao->mt_created.
    TRY.
        DATA(lt_links) = mo_cut->children( it_jobs = mo_dao->mt_running is_config = VALUE #( max_children = 10 )
                                           io_dao = mo_dao io_log = VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_links ) exp = 1 msg = 'Only the worker' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-child_name exp = gc_worker msg = 'The worker job' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
