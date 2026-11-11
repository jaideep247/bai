*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_res_heur.clas.abap
*& Purpose:
*& Parent / child resolver HEURISTIC of the SAP job monitor: a job released
*& by a program is scheduled by the user of that program's step and is
*& created while the program runs. Parent of a child = the only job that
*& ran when the child was created, has a step of that user (and, when
*& JOB_PARENT_PROGRAMS is maintained, of one of those programs) and is not
*& the child itself; two or more candidates = no link (ambiguous). Children
*& of a parent = the jobs created during its run by its step users that
*& have no other candidate in the read. Quality P (probable). Set-based:
*& one read of candidates and their steps per call. PARENT_CANDIDATES is
*& shared with the resolver JOBLOG, which confirms candidates by the log.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - job resolver HEURISTIC</p>
CLASS zcl_ca_ops_job_res_heur DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_resolver.

    "! Every (candidate parent, child) pair: the candidate ran when the child was created, has a step of
    "! the child's scheduling user (and of a parent program when configured) and is not the child
    CLASS-METHODS parent_candidates
      IMPORTING
        it_jobs         TYPE zif_ca_ops_job_types=>tt_job
        is_config       TYPE zif_ca_ops_job_types=>ty_config
        io_dao          TYPE REF TO zif_ca_ops_job_dao
      RETURNING
        VALUE(rt_pairs) TYPE zif_ca_ops_job_types=>tt_link.

  PRIVATE SECTION.
    TYPES tt_step_user TYPE SORTED TABLE OF zif_ca_ops_job_types=>ty_step
                       WITH NON-UNIQUE KEY jobname jobcount authcknam.

    "! The window from the earliest to the latest point of the list (blank when the list is empty)
    CLASS-METHODS span
      IMPORTING
        it_points        TYPE STANDARD TABLE
      RETURNING
        VALUE(rs_window) TYPE zif_ca_ops_job_types=>ty_window.

    CLASS-METHODS keys
      IMPORTING
        it_jobs        TYPE zif_ca_ops_job_types=>tt_job
      RETURNING
        VALUE(rt_keys) TYPE zif_ca_ops_job_types=>tt_job_key.

    "! Keep the pairs whose child has exactly one parent
    CLASS-METHODS unique
      IMPORTING
        it_pairs        TYPE zif_ca_ops_job_types=>tt_link
      RETURNING
        VALUE(rt_links) TYPE zif_ca_ops_job_types=>tt_link.

ENDCLASS.



CLASS zcl_ca_ops_job_res_heur IMPLEMENTATION.

  METHOD zif_ca_ops_job_resolver~id.
    rv_id = zif_ca_ops_job_types=>gc_resolver-heuristic.
  ENDMETHOD.


  METHOD zif_ca_ops_job_resolver~parents.
    rt_links = unique( parent_candidates( it_jobs   = it_jobs
                                          is_config = is_config
                                          io_dao    = io_dao ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_job_resolver~children.
    DATA lt_users TYPE zif_ca_ops_types=>tt_param_range.
    DATA lt_points TYPE STANDARD TABLE OF zif_ca_ops_job_types=>ty_point WITH EMPTY KEY.
    DATA lt_pairs TYPE zif_ca_ops_job_types=>tt_link.
    DATA lt_steps TYPE tt_step_user.

    IF it_jobs IS INITIAL.
      RETURN.
    ENDIF.
    DATA(ls_now) = zcl_ca_ops_job_time=>now( ).
    lt_steps = io_dao->steps( keys( it_jobs ) ).
    LOOP AT lt_steps ASSIGNING FIELD-SYMBOL(<ls_step>) WHERE authcknam IS NOT INITIAL.
      IF NOT line_exists( lt_users[ low = <ls_step>-authcknam ] ).
        INSERT VALUE #( sign   = zif_ca_ops_types=>gc_range-sign_include
                        option = zif_ca_ops_types=>gc_range-option_equal
                        low    = <ls_step>-authcknam ) INTO TABLE lt_users.
      ENDIF.
    ENDLOOP.
    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>) WHERE strtdate IS NOT INITIAL.
      INSERT zcl_ca_ops_job_time=>started( <ls_job> ) INTO TABLE lt_points.
      INSERT COND #( WHEN zcl_ca_ops_job_time=>is_active( <ls_job> ) = abap_true OR <ls_job>-enddate IS INITIAL
                     THEN ls_now
                     ELSE zcl_ca_ops_job_time=>ended( <ls_job> ) ) INTO TABLE lt_points.
    ENDLOOP.
    IF lt_users IS INITIAL OR lt_points IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_created) = io_dao->jobs_created( is_window = span( lt_points )
                                             it_users  = lt_users
                                             iv_max    = is_config-max_children * lines( it_jobs ) ).
    LOOP AT lt_created ASSIGNING FIELD-SYMBOL(<ls_child>).
      DATA(ls_created) = zcl_ca_ops_job_time=>created( <ls_child> ).
      LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_parent>)
           WHERE NOT ( jobname = <ls_child>-jobname AND jobcount = <ls_child>-jobcount ).
        IF zcl_ca_ops_job_time=>ran_at( is_job = <ls_parent> is_point = ls_created is_now = ls_now ) = abap_true
           AND line_exists( lt_steps[ jobname   = <ls_parent>-jobname
                                      jobcount  = <ls_parent>-jobcount
                                      authcknam = <ls_child>-sdluname ] ).
          INSERT VALUE #( parent_name  = <ls_parent>-jobname
                          parent_count = <ls_parent>-jobcount
                          child_name   = <ls_child>-jobname
                          child_count  = <ls_child>-jobcount
                          resolver     = zif_ca_ops_job_types=>gc_resolver-heuristic
                          quality      = zif_ca_ops_job_types=>gc_quality-probable ) INTO TABLE lt_pairs.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
    rt_links = unique( lt_pairs ).
  ENDMETHOD.


  METHOD parent_candidates.
    DATA lt_points TYPE STANDARD TABLE OF zif_ca_ops_job_types=>ty_point WITH EMPTY KEY.
    DATA lt_steps TYPE tt_step_user.

    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>) WHERE sdldate IS NOT INITIAL AND sdluname IS NOT INITIAL.
      INSERT zcl_ca_ops_job_time=>created( <ls_job> ) INTO TABLE lt_points.
    ENDLOOP.
    IF lt_points IS INITIAL.
      RETURN.
    ENDIF.
    DATA(ls_now) = zcl_ca_ops_job_time=>now( ).
    DATA(lt_candidates) = io_dao->jobs_running( is_window   = span( lt_points )
                                                it_programs = is_config-parent_programs
                                                iv_max      = is_config-max_jobs ).
    IF lt_candidates IS INITIAL.
      RETURN.
    ENDIF.
    lt_steps = io_dao->steps( keys( lt_candidates ) ).
    LOOP AT it_jobs ASSIGNING <ls_job> WHERE sdldate IS NOT INITIAL AND sdluname IS NOT INITIAL.
      DATA(ls_created) = zcl_ca_ops_job_time=>created( <ls_job> ).
      LOOP AT lt_candidates ASSIGNING FIELD-SYMBOL(<ls_candidate>)
           WHERE NOT ( jobname = <ls_job>-jobname AND jobcount = <ls_job>-jobcount ).
        IF zcl_ca_ops_job_time=>ran_at( is_job = <ls_candidate> is_point = ls_created is_now = ls_now ) = abap_true
           AND line_exists( lt_steps[ jobname   = <ls_candidate>-jobname
                                      jobcount  = <ls_candidate>-jobcount
                                      authcknam = <ls_job>-sdluname ] ).
          INSERT VALUE #( parent_name  = <ls_candidate>-jobname
                          parent_count = <ls_candidate>-jobcount
                          child_name   = <ls_job>-jobname
                          child_count  = <ls_job>-jobcount
                          resolver     = zif_ca_ops_job_types=>gc_resolver-heuristic
                          quality      = zif_ca_ops_job_types=>gc_quality-probable ) INTO TABLE rt_pairs.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD span.
    FIELD-SYMBOLS <ls_point> TYPE zif_ca_ops_job_types=>ty_point.
    LOOP AT it_points ASSIGNING <ls_point>.
      IF rs_window-from IS INITIAL
         OR zcl_ca_ops_job_time=>not_after( is_first = <ls_point> is_second = rs_window-from ) = abap_true.
        rs_window-from = <ls_point>.
      ENDIF.
      IF rs_window-to IS INITIAL
         OR zcl_ca_ops_job_time=>not_after( is_first = rs_window-to is_second = <ls_point> ) = abap_true.
        rs_window-to = <ls_point>.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD keys.
    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      INSERT VALUE #( jobname = <ls_job>-jobname jobcount = <ls_job>-jobcount ) INTO TABLE rt_keys.
    ENDLOOP.
  ENDMETHOD.


  METHOD unique.
    LOOP AT it_pairs ASSIGNING FIELD-SYMBOL(<ls_pair>).
      DATA(lv_parents) = REDUCE i( INIT lv_count = 0
                                   FOR <ls_other> IN it_pairs
                                   WHERE ( child_name = <ls_pair>-child_name AND child_count = <ls_pair>-child_count )
                                   NEXT lv_count = lv_count + 1 ).
      IF lv_parents = 1.
        INSERT <ls_pair> INTO TABLE rt_links.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
