*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_job_enr_massact.clas.testclasses.abap
*& Purpose:
*& Unit tests of the mass activity enricher: blank JOB_MA_RUN_PCRE adds
*& nothing (delivered off); a job name matching the pattern gives the mass
*& activity run (activity, run date, run ID) with quality P; an impossible
*& date is no run; an invalid pattern raises 121. Parameters from the
*& in-memory seed. Does not prove live SAP runtime behavior (VERIFY-SE11 V67:
*& the real job naming).
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor adoption, area CD_JOBS).
*&---------------------------------------------------------------------*
CLASS ltc_enr_massact DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_pattern TYPE string VALUE `ZT_MA_([A-Z0-9]{4})_(\d{8})_([A-Z0-9]{1,6})(_\d+)?`,
      gc_job     TYPE btcjob VALUE 'ZT_MA_0030_20261111_PAY01_3',
      gc_count   TYPE btcjobcnt VALUE '10000001'.

    DATA mo_seed TYPE REF TO zcl_cd_ops_param_seed.

    METHODS setup.
    METHODS teardown.
    METHODS act
      IMPORTING
        iv_jobname        TYPE btcjob
      RETURNING
        VALUE(rt_objects) TYPE zif_ca_ops_job_types=>tt_bus_object
      RAISING
        zcx_ca_ops_error.

    METHODS blank_pattern_adds_nothing FOR TESTING.
    METHODS run_from_job_name          FOR TESTING.
    METHODS impossible_date_no_run     FOR TESTING.
    METHODS invalid_pattern_raises     FOR TESTING.
ENDCLASS.


CLASS ltc_enr_massact IMPLEMENTATION.

  METHOD setup.
    mo_seed = NEW #( ).
    zcl_cd_ops_injector=>inject_params( mo_seed->params( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD act.
    NEW zcl_cd_job_enr_massact( )->zif_ca_ops_job_enricher~enrich(
      EXPORTING it_jobs    = VALUE #( ( jobname = iv_jobname jobcount = gc_count ) )
                it_steps   = VALUE #( )
      CHANGING  ct_objects = rt_objects ).
  ENDMETHOD.


  " Rule: delivered off - no pattern, no object
  METHOD blank_pattern_adds_nothing.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = act( gc_job ) msg = 'Nothing without the pattern' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: activity, run date and run ID from the job name - probable
  METHOD run_from_job_name.
    TRY.
        mo_seed->set( iv_name = zif_cd_job_types=>gc_param-ma_run_pcre iv_value = gc_pattern ).
        DATA(lt_objects) = act( gc_job ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_objects ) exp = 1 msg = 'One mass activity run' ).
        cl_abap_unit_assert=>assert_equals( act = lt_objects[ 1 ]-object_key exp = '0030/20261111/PAY01'
                                            msg = 'Activity / run date / run ID' ).
        cl_abap_unit_assert=>assert_equals( act = lt_objects[ 1 ]-object_type
                                            exp = zif_cd_job_types=>gc_object_type-mass_run msg = 'Type' ).
        cl_abap_unit_assert=>assert_equals( act = lt_objects[ 1 ]-quality
                                            exp = zif_ca_ops_job_types=>gc_quality-probable msg = 'From the name only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a date that does not exist is no run date
  METHOD impossible_date_no_run.
    TRY.
        mo_seed->set( iv_name = zif_cd_job_types=>gc_param-ma_run_pcre iv_value = gc_pattern ).
        cl_abap_unit_assert=>assert_initial( act = act( 'ZT_MA_0030_20261340_PAY01' ) msg = 'Month 13' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a pattern that does not compile is a configuration error (121), never "no run"
  METHOD invalid_pattern_raises.
    mo_seed->set( iv_name = zif_cd_job_types=>gc_param-ma_run_pcre iv_value = 'ZT_(' ).
    TRY.
        act( gc_job ).
        cl_abap_unit_assert=>fail( msg = 'Expected 121' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '121'
                                            msg = 'Pattern not usable' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
