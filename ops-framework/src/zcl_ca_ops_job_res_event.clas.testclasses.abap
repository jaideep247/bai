*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_res_event.clas.testclasses.abap
*& Purpose:
*& Tests of the resolver EVENT with a data access double: the parent of a
*& job started after another job is read from its event parameter (name 32
*& + count 8) and kept only when that job exists (quality C); an event not
*& in JOB_EVENT_IDS links nothing; the children of a job are read by the
*& event parameter that names it. Does not prove live SAP runtime behavior
*& (VERIFY-SE11 V61: the event and its parameter layout).
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_dao PARTIALLY IMPLEMENTED.
    DATA mt_known TYPE zif_ca_ops_job_types=>tt_job.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_ca_ops_job_dao~jobs.
    LOOP AT mt_known ASSIGNING FIELD-SYMBOL(<ls_job>).
      IF line_exists( it_keys[ jobname = <ls_job>-jobname jobcount = <ls_job>-jobcount ] ).
        INSERT <ls_job> INTO TABLE rt_jobs.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
  METHOD zif_ca_ops_job_dao~jobs_by_event.
    LOOP AT mt_known ASSIGNING FIELD-SYMBOL(<ls_job>).
      IF line_exists( it_events[ eventid = <ls_job>-eventid eventparm = <ls_job>-eventparm ] ).
        INSERT <ls_job> INTO TABLE rt_jobs.
      ENDIF.
    ENDLOOP.
    DELETE rt_jobs FROM iv_max + 1.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_event DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        parent TYPE btcjob VALUE 'ZT_PREDECESSOR',
        child  TYPE btcjob VALUE 'ZT_SUCCESSOR',
        count  TYPE btcjobcnt VALUE '10000001',
        event  TYPE zif_ca_ops_job_types=>ty_eventid VALUE 'SAP_END_OF_JOB',
        other  TYPE zif_ca_ops_job_types=>ty_eventid VALUE 'ZT_OTHER_EVENT',
      END OF gc.
    DATA mo_dao TYPE REF TO ltd_dao.
    DATA mo_cut TYPE REF TO zif_ca_ops_job_resolver.
    METHODS setup.
    METHODS teardown.
    METHODS successor
      IMPORTING
        iv_event      TYPE zif_ca_ops_job_types=>ty_eventid
      RETURNING
        VALUE(rs_job) TYPE zif_ca_ops_job_types=>ty_job.
    METHODS parent_from_event_parm FOR TESTING.
    METHODS unknown_parent_no_link FOR TESTING.
    METHODS other_event_no_link    FOR TESTING.
    METHODS children_by_event_parm FOR TESTING.
ENDCLASS.


CLASS ltc_event IMPLEMENTATION.

  METHOD setup.
    zcl_ca_ops_injector=>inject_params( NEW zcl_ca_ops_param_seed( )->params( ) ).
    mo_dao = NEW #( ).
    mo_cut = NEW zcl_ca_ops_job_res_event( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD successor.
    rs_job = VALUE #( jobname = gc-child jobcount = gc-count eventid = iv_event
                      eventparm = |{ gc-parent WIDTH = 32 }{ gc-count }| ).
  ENDMETHOD.


  " Rule: start after job - the event parameter names the predecessor (confirmed)
  METHOD parent_from_event_parm.
    TRY.
        INSERT VALUE #( jobname = gc-parent jobcount = gc-count ) INTO TABLE mo_dao->mt_known.
        DATA(lt_links) = mo_cut->parents( it_jobs = VALUE #( ( successor( gc-event ) ) ) is_config = VALUE #( )
                                          io_dao = mo_dao io_log = VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_links ) exp = 1 msg = 'One parent' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-parent_name exp = gc-parent msg = 'The predecessor' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-parent_count exp = gc-count msg = 'Its job count' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-quality exp = zif_ca_ops_job_types=>gc_quality-confirmed
                                            msg = 'Confirmed by the event parameter' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a parent that is not a job of the client is no link
  METHOD unknown_parent_no_link.
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->parents( it_jobs = VALUE #( ( successor( gc-event ) ) ) is_config = VALUE #( )
                                 io_dao = mo_dao io_log = VALUE #( ) )
          msg = 'No link without the parent job' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an event that is not in JOB_EVENT_IDS links nothing
  METHOD other_event_no_link.
    TRY.
        INSERT VALUE #( jobname = gc-parent jobcount = gc-count ) INTO TABLE mo_dao->mt_known.
        cl_abap_unit_assert=>assert_initial(
          act = mo_cut->parents( it_jobs = VALUE #( ( successor( gc-other ) ) ) is_config = VALUE #( )
                                 io_dao = mo_dao io_log = VALUE #( ) )
          msg = 'Other events name no job' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the children of a job are the jobs waiting for its end
  METHOD children_by_event_parm.
    TRY.
        INSERT successor( gc-event ) INTO TABLE mo_dao->mt_known.
        DATA(lt_links) = mo_cut->children( it_jobs = VALUE #( ( jobname = gc-parent jobcount = gc-count ) )
                                           is_config = VALUE #( max_children = 10 ) io_dao = mo_dao io_log = VALUE #( ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_links ) exp = 1 msg = 'One child' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-child_name exp = gc-child msg = 'The successor' ).
        cl_abap_unit_assert=>assert_equals( act = lt_links[ 1 ]-parent_name exp = gc-parent msg = 'Of the parent' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
