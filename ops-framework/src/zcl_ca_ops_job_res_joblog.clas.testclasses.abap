*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_res_joblog.clas.testclasses.abap
*& Purpose:
*& Tests of the resolver JOBLOG with doubles of the data access and the job
*& log reader: blank parameters = off (no log read); the children of a job
*& are the jobs its log announces with name and count (configured message,
*& PCRE groups; quality C); a line of another message is ignored; the
*& parent of a child is the candidate whose log names it; an invalid
*& pattern raises 121. Does not prove live SAP runtime behavior
*& (VERIFY-SE91 V62: the announcing message and its text).
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_dao PARTIALLY IMPLEMENTED.
    DATA mt_running TYPE zif_ca_ops_job_types=>tt_job.
    DATA mt_steps TYPE zif_ca_ops_job_types=>tt_step.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_ca_ops_job_dao~jobs_running.
    rt_jobs = mt_running.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~steps.
    rt_steps = mt_steps.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_log DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_log.
    DATA mt_lines TYPE zif_ca_ops_job_types=>tt_log_line.
    DATA mv_reads TYPE i.
ENDCLASS.

CLASS ltd_log IMPLEMENTATION.
  METHOD zif_ca_ops_job_log~read.
    mv_reads += 1.
    IF iv_jobname = 'ZT_SCHEDULER' AND iv_jobcount IS NOT INITIAL.
      rt_lines = mt_lines.
    ENDIF.
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


CLASS ltc_joblog DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        parent TYPE btcjob VALUE 'ZT_SCHEDULER',
        child  TYPE btcjob VALUE 'ZT_WORKER_07',
        count  TYPE btcjobcnt VALUE '10000001',
        child_count TYPE btcjobcnt VALUE '12345678',
        user   TYPE syuname VALUE 'ZT_BATCH',
        today  TYPE d VALUE '20261111',
      END OF gc.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_log TYPE REF TO ltd_log.
    DATA mo_seed TYPE REF TO zcl_ca_ops_param_seed.
    DATA mo_cut TYPE REF TO zif_ca_ops_job_resolver.
    METHODS setup.
    METHODS teardown.
    METHODS configure.
    METHODS blank_parameters_off    FOR TESTING.
    METHODS children_named_in_log   FOR TESTING.
    METHODS parent_whose_log_names  FOR TESTING.
    METHODS invalid_pattern_refused FOR TESTING.
ENDCLASS.


CLASS ltc_joblog IMPLEMENTATION.

  METHOD setup.
    mo_seed = NEW #( ).
    zcl_ca_ops_injector=>inject_params( mo_seed->params( ) ).
    zcl_ca_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    mo_dao = NEW #( ).
    mo_log = NEW #( ).
    mo_cut = NEW zcl_ca_ops_job_res_joblog( ).
    mo_log->mt_lines = VALUE #( ( msgid = 'ZT' msgno = '010' msgtype = 'S'
                                  text = |Job { gc-child } ({ gc-child_count }) released| )
                                ( msgid = 'ZT' msgno = '011' msgtype = 'S'
                                  text = |Job ZT_NOT_A_CHILD ({ gc-child_count }) mentioned| ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD configure.
    mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-child_msg_ids iv_value = 'ZT/010' ).
    mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-child_msg_pcre iv_value = 'Job (\S+) \((\d{8})\)' ).
  ENDMETHOD.


  " Rule: without the message and the pattern the resolver reads no log
  METHOD blank_parameters_off.
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->children( it_jobs = VALUE #( ( jobname = gc-parent jobcount = gc-count ) )
                                  is_config = VALUE #( max_children = 10 ) io_dao = mo_dao io_log = mo_log )
          msg = 'Off' ).
        cl_abap_unit_assert=>assert_equals( act = mo_log->mv_reads exp = 0 msg = 'No log read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the configured line names the child with name and count - confirmed; other messages are ignored
  METHOD children_named_in_log.
    configure( ).
    TRY.
        DATA(lt_links) = mo_cut->children( it_jobs = VALUE #( ( jobname = gc-parent jobcount = gc-count ) )
                                           is_config = VALUE #( max_children = 10 ) io_dao = mo_dao io_log = mo_log ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_links ) exp = 1 msg = 'One child named' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-child_name exp = gc-child msg = 'Its name' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-child_count exp = gc-child_count msg = 'Its count' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-quality exp = zif_ca_ops_job_types=>gc_quality-confirmed
                                            msg = 'Confirmed by the log' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the parent of a child is the candidate whose log names the child
  METHOD parent_whose_log_names.
    configure( ).
    INSERT VALUE #( jobname = gc-parent jobcount = gc-count status = zif_ca_ops_job_types=>gc_status-finished
                    strtdate = gc-today strttime = '090000' enddate = gc-today endtime = '093000' )
      INTO TABLE mo_dao->mt_running.
    INSERT VALUE #( jobname = gc-parent jobcount = gc-count stepcount = 1 authcknam = gc-user ) INTO TABLE mo_dao->mt_steps.
    TRY.
        DATA(lt_links) = mo_cut->parents(
                           it_jobs = VALUE #( ( jobname = gc-child jobcount = gc-child_count sdluname = gc-user
                                                sdldate = gc-today sdltime = '091000' ) )
                           is_config = VALUE #( max_jobs = 100 ) io_dao = mo_dao io_log = mo_log ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_links ) exp = 1 msg = 'One parent' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-parent_name exp = gc-parent msg = 'The scheduler' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a pattern that does not compile is a configuration error (121), never "no child"
  METHOD invalid_pattern_refused.
    mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-child_msg_ids iv_value = 'ZT/010' ).
    mo_seed->set( iv_name = zif_ca_ops_job_types=>gc_param-child_msg_pcre iv_value = 'Job (' ).
    TRY.
        mo_cut->children( it_jobs = VALUE #( ( jobname = gc-parent jobcount = gc-count ) )
                          is_config = VALUE #( max_children = 10 ) io_dao = mo_dao io_log = mo_log ).
        cl_abap_unit_assert=>fail( msg = 'Expected 121' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '121'
                                            msg = 'Pattern not usable' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
