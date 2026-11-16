*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_src_tbtco.clas.testclasses.abap
*& Purpose:
*& Tests of the SAP job scheduler source with a double of the job
*& monitor's data access: a finished and a cancelled job become one event
*& each with the job status as native status, job name and count, the
*& link object of a background job and its key values; the programs of
*& the setting are what the data access is asked for; without a program
*& the adapter is refused (386). Does not prove live SAP runtime
*& behavior (system time conversion V177).
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
CLASS ltd_job_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_dao PARTIALLY IMPLEMENTED.
    DATA mt_programs TYPE zif_ca_ops_types=>tt_param_range.
ENDCLASS.

CLASS ltd_job_dao IMPLEMENTATION.
  METHOD zif_ca_ops_job_dao~jobs_running.
    mt_programs = it_programs.
    rt_jobs = VALUE #( ( jobname = 'ZT_MEDIUM' jobcount = '00000001' status = 'F' enddate = '20261116' endtime = '162000' )
                       ( jobname = 'ZT_MEDIUM' jobcount = '00000002' status = 'A' strtdate = '20261116' strttime = '170000' ) ).
  ENDMETHOD.
ENDCLASS.


CLASS ltc_pf_src_tbtco DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS jobs_become_events     FOR TESTING RAISING zcx_ca_ops_error.
    METHODS programs_required      FOR TESTING.
ENDCLASS.


CLASS ltc_pf_src_tbtco IMPLEMENTATION.

  METHOD jobs_become_events.
    DATA(lo_dao) = NEW ltd_job_dao( ).
    DATA(lo_cut) = NEW zcl_ca_ops_pf_src_tbtco( lo_dao ).
    lo_cut->zif_ca_ops_pf_adapter~configure( VALUE #( role = zif_ca_ops_pf_types=>gc_role-sched setting = 'PROGRAMS=ZT_MEDIUM_PROGRAM' ) ).
    DATA(ls_batch) = lo_cut->zif_ca_ops_pf_event_src~read_events( VALUE #( from_ts = '20261116000000.0000000'
                                                                           to_ts   = '20261117000000.0000000' ) ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_batch-events ) exp = 2 msg = 'One event per job' ).
    cl_abap_unit_assert=>assert_equals( act = lo_dao->mt_programs[ 1 ]-low exp = 'ZT_MEDIUM_PROGRAM' msg = 'Programs asked' ).
    DATA(ls_event) = ls_batch-events[ 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_event-native_status exp = 'F' msg = 'Job status' ).
    cl_abap_unit_assert=>assert_equals( act = ls_event-source_event_id exp = 'ZT_MEDIUM/00000001' msg = 'Job name and count' ).
    cl_abap_unit_assert=>assert_equals( act = ls_event-link_object exp = zcl_ca_ops_pf_src_tbtco=>gc_link_object msg = 'Link object' ).
    cl_abap_unit_assert=>assert_equals( act = ls_event-link_value exp = 'JOBNAME=ZT_MEDIUM;JOBCOUNT=00000001' msg = 'Key values' ).
    cl_abap_unit_assert=>assert_equals( act = ls_batch-events[ 2 ]-bus_date exp = '20261116' msg = 'Start date of an unended job' ).
  ENDMETHOD.


  METHOD programs_required.
    TRY.
        NEW zcl_ca_ops_pf_src_tbtco( NEW ltd_job_dao( ) )->zif_ca_ops_pf_adapter~configure(
          VALUE #( role = zif_ca_ops_pf_types=>gc_role-sched ) ).
        cl_abap_unit_assert=>fail( msg = 'Refused expected' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '386' msg = '386' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
