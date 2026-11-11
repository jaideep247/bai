*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_res_heur.clas.testclasses.abap
*& Purpose:
*& Tests of the resolver HEURISTIC with a data access double: the only job
*& that ran when the child was created and has a step of the child's
*& scheduling user is its parent (quality P); two such jobs = no link
*& (ambiguous); a job without a step of that user is no candidate; the
*& children of a parent are the jobs its step users created during its run.
*& Clock double. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
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
    rt_jobs = mt_running.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~jobs_created.
    LOOP AT mt_created ASSIGNING FIELD-SYMBOL(<ls_job>) WHERE sdluname IN it_users.
      INSERT <ls_job> INTO TABLE rt_jobs.
    ENDLOOP.
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


CLASS ltc_heuristic DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        child   TYPE btcjob VALUE 'ZT_WORKER',
        parent  TYPE btcjob VALUE 'ZT_SCHEDULER',
        other   TYPE btcjob VALUE 'ZT_SCHEDULER_2',
        count   TYPE btcjobcnt VALUE '10000001',
        user    TYPE syuname VALUE 'ZT_BATCH',
        today   TYPE d VALUE '20261111',
      END OF gc.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_cut TYPE REF TO zif_ca_ops_job_resolver.
    METHODS setup.
    METHODS teardown.
    METHODS running
      IMPORTING
        iv_name TYPE btcjob
        iv_user TYPE syuname DEFAULT gc-user.
    METHODS child
      RETURNING
        VALUE(rs_job) TYPE zif_ca_ops_job_types=>ty_job.
    METHODS only_candidate_is_parent FOR TESTING.
    METHODS two_candidates_no_link   FOR TESTING.
    METHODS other_user_no_candidate  FOR TESTING.
    METHODS children_created_in_run  FOR TESTING.
ENDCLASS.


CLASS ltc_heuristic IMPLEMENTATION.

  METHOD setup.
    zcl_ca_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    mo_dao = NEW #( ).
    mo_cut = NEW zcl_ca_ops_job_res_heur( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD running.
    INSERT VALUE #( jobname = iv_name jobcount = gc-count status = zif_ca_ops_job_types=>gc_status-finished
                    strtdate = gc-today strttime = '090000' enddate = gc-today endtime = '093000' )
      INTO TABLE mo_dao->mt_running.
    INSERT VALUE #( jobname = iv_name jobcount = gc-count stepcount = 1 progname = 'ZT_SCHEDULER_PROGRAM'
                    authcknam = iv_user ) INTO TABLE mo_dao->mt_steps.
  ENDMETHOD.


  METHOD child.
    rs_job = VALUE #( jobname = gc-child jobcount = gc-count status = zif_ca_ops_job_types=>gc_status-aborted
                      sdldate = gc-today sdltime = '091000' sdluname = gc-user ).
  ENDMETHOD.


  " Rule: the only job running at the child's creation with a step of its scheduling user = parent (P)
  METHOD only_candidate_is_parent.
    running( gc-parent ).
    TRY.
        DATA(lt_links) = mo_cut->parents( it_jobs = VALUE #( ( child( ) ) ) is_config = VALUE #( max_jobs = 100 )
                                          io_dao = mo_dao io_log = VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_links ) exp = 1 msg = 'One parent' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-parent_name exp = gc-parent msg = 'The scheduler job' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-quality exp = zif_ca_ops_job_types=>gc_quality-probable
                                            msg = 'Probable only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: two candidates = ambiguous, no link (never a guess)
  METHOD two_candidates_no_link.
    running( gc-parent ).
    running( gc-other ).
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->parents( it_jobs = VALUE #( ( child( ) ) ) is_config = VALUE #( max_jobs = 100 )
                                 io_dao = mo_dao io_log = VALUE #( ) )
          msg = 'Ambiguous' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a job without a step of the scheduling user is no candidate
  METHOD other_user_no_candidate.
    running( iv_name = gc-parent iv_user = 'ZT_OTHER' ).
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->parents( it_jobs = VALUE #( ( child( ) ) ) is_config = VALUE #( max_jobs = 100 )
                                 io_dao = mo_dao io_log = VALUE #( ) )
          msg = 'Other user' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the children of a parent are the jobs its step users created during its run
  METHOD children_created_in_run.
    running( gc-parent ).
    INSERT child( ) INTO TABLE mo_dao->mt_created.
    TRY.
        DATA(lt_links) = mo_cut->children( it_jobs = mo_dao->mt_running is_config = VALUE #( max_children = 10 )
                                           io_dao = mo_dao io_log = VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_links ) exp = 1 msg = 'One child' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-child_name exp = gc-child msg = 'The worker' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
