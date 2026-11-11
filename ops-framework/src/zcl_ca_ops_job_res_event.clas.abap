*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_res_event.clas.abap
*& Purpose:
*& Parent / child resolver EVENT of the SAP job monitor: a job started by
*& an event whose parameter names the job that raised it - "start after
*& job" (event SAP_END_OF_JOB, EVENTPARM = predecessor job name, 32, and
*& count, 8) and any event of JOB_EVENT_IDS with the same layout. Parents:
*& from the child's EVENTID / EVENTPARM, kept when the parent job exists
*& in TBTCO. Children: the jobs whose EVENTID / EVENTPARM name the parent
*& (one set-based read). Quality C (confirmed by the event parameter).
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - job resolver EVENT</p>
"! VERIFY-SE11 V61: the start-after-job event and its EVENTPARM layout (name 32 + count 8) on 7.58; an
"! event raised by a program (BP_EVENT_RAISE) names no job - such a link is left to the heuristic.
CLASS zcl_ca_ops_job_res_event DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_resolver.

  PRIVATE SECTION.
    "! Events whose parameter names the predecessor (JOB_EVENT_IDS)
    METHODS events
      RETURNING
        VALUE(rt_events) TYPE string_table.

    "! Predecessor job name (first 32 characters) and count (next 8) of an event parameter
    CLASS-METHODS parent_name
      IMPORTING
        iv_parm        TYPE zif_ca_ops_job_types=>ty_eventparm
      RETURNING
        VALUE(rv_name) TYPE btcjob.
    CLASS-METHODS parent_count
      IMPORTING
        iv_parm         TYPE zif_ca_ops_job_types=>ty_eventparm
      RETURNING
        VALUE(rv_count) TYPE btcjobcnt.

    "! Event parameter naming a job: name padded to 32 characters, then the count
    CLASS-METHODS event_parm
      IMPORTING
        is_job         TYPE zif_ca_ops_job_types=>ty_job
      RETURNING
        VALUE(rv_parm) TYPE zif_ca_ops_job_types=>ty_eventparm.

ENDCLASS.



CLASS zcl_ca_ops_job_res_event IMPLEMENTATION.

  METHOD zif_ca_ops_job_resolver~id.
    rv_id = zif_ca_ops_job_types=>gc_resolver-event.
  ENDMETHOD.


  METHOD zif_ca_ops_job_resolver~parents.
    DATA lt_parents TYPE zif_ca_ops_job_types=>tt_job_key.
    DATA lt_candidates TYPE zif_ca_ops_job_types=>tt_link.

    DATA(lt_events) = events( ).
    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>) WHERE eventparm IS NOT INITIAL.
      IF NOT line_exists( lt_events[ table_line = condense( CONV string( <ls_job>-eventid ) ) ] ).
        CONTINUE.
      ENDIF.
      DATA(ls_link) = VALUE zif_ca_ops_job_types=>ty_link(
        parent_name  = parent_name( <ls_job>-eventparm )
        parent_count = parent_count( <ls_job>-eventparm )
        child_name   = <ls_job>-jobname
        child_count  = <ls_job>-jobcount
        resolver     = zif_ca_ops_job_types=>gc_resolver-event
        quality      = zif_ca_ops_job_types=>gc_quality-confirmed ).
      IF ls_link-parent_name IS INITIAL OR ls_link-parent_count IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT ls_link INTO TABLE lt_candidates.
      INSERT VALUE #( jobname = ls_link-parent_name jobcount = ls_link-parent_count ) INTO TABLE lt_parents.
    ENDLOOP.
    IF lt_parents IS INITIAL.
      RETURN.
    ENDIF.
    " a link counts only when the parent job is a job of this client
    DATA(lt_existing) = io_dao->jobs( lt_parents ).
    LOOP AT lt_candidates ASSIGNING FIELD-SYMBOL(<ls_candidate>).
      IF line_exists( lt_existing[ jobname = <ls_candidate>-parent_name jobcount = <ls_candidate>-parent_count ] ).
        INSERT <ls_candidate> INTO TABLE rt_links.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_job_resolver~children.
    DATA lt_events TYPE zif_ca_ops_job_types=>tt_job.
    DATA lv_parm TYPE zif_ca_ops_job_types=>ty_eventparm.

    LOOP AT events( ) ASSIGNING FIELD-SYMBOL(<lv_event>).
      LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
        lv_parm = event_parm( is_job = <ls_job> ).
        INSERT VALUE #( eventid = <lv_event> eventparm = lv_parm ) INTO TABLE lt_events.
      ENDLOOP.
    ENDLOOP.
    DATA(lt_children) = io_dao->jobs_by_event( it_events = lt_events
                                               iv_max    = is_config-max_children * lines( it_jobs ) ).
    LOOP AT lt_children ASSIGNING FIELD-SYMBOL(<ls_child>).
      INSERT VALUE #(
        parent_name  = parent_name( <ls_child>-eventparm )
        parent_count = parent_count( <ls_child>-eventparm )
        child_name   = <ls_child>-jobname
        child_count  = <ls_child>-jobcount
        resolver     = zif_ca_ops_job_types=>gc_resolver-event
        quality      = zif_ca_ops_job_types=>gc_quality-confirmed ) INTO TABLE rt_links.
    ENDLOOP.
  ENDMETHOD.


  METHOD parent_name.
    rv_name = substring( val = iv_parm len = zif_ca_ops_job_types=>gc_eventparm-name_length ).
  ENDMETHOD.


  METHOD parent_count.
    rv_count = substring( val = iv_parm
                          off = zif_ca_ops_job_types=>gc_eventparm-name_length
                          len = zif_ca_ops_job_types=>gc_eventparm-count_length ).
  ENDMETHOD.


  METHOD event_parm.
    " the name padded with blanks to its column width, the count right after it
    rv_parm = |{ is_job-jobname WIDTH = zif_ca_ops_job_types=>gc_eventparm-name_length }{ is_job-jobcount }|.
  ENDMETHOD.


  METHOD events.
    LOOP AT zcl_ca_ops_util=>split_list( zcl_ca_ops_factory=>get_params( )->get_param(
                                           iv_name    = zif_ca_ops_job_types=>gc_param-event_ids
                                           iv_default = zif_ca_ops_job_types=>gc_param_default-event_ids
                                           iv_area    = zif_ca_ops_types=>gc_param_area ) )
         ASSIGNING FIELD-SYMBOL(<lv_event>).
      INSERT to_upper( <lv_event> ) INTO TABLE rt_events.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
