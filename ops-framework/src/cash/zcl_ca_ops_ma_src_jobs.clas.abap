*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_ma_src_jobs.clas.abap
*& Purpose:
*& Delivered run source of the FI-CA mass activity check (ZIF_CA_OPS_MA_
*& SRC; docs/EXPECTED_RUNS_AND_MASS_ACTIVITIES.md section 3.2), from SAP's
*& job tables only (through the job monitor's data access): the parent job
*& of a run is a job that ran since the date with a step of the activity's
*& program (blank = any) and a name of its PCRE; its intervals are the
*& jobs the job monitor's parent / child resolvers link to it (MA_RESOLVERS,
*& blank = JOB_RESOLVERS; the first link of a child wins), numbered in the
*& order they were created. An interval's state is its job's status: F
*& finished = OK, A cancelled = FAILED, R / Z active = RUNNING, else
*& WAITING. The run date is the parent's start date (LAUFD: the mass
*& activity scheduler names a run by the day it runs); the run ID is not
*& known to this source (blank) and the run's quality is P - derived from
*& job names and times, not from the run's own records (VERIFY V300). Read
*& only; nothing is released, cancelled or restarted.
*& Modification log:
*& 2026-11-16 | Initial version (build P: FI-CA mass-activity intervals and their output).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA mass activities - runs from SAP jobs</p>
CLASS zcl_ca_ops_ma_src_jobs DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_ma_src.

    "! @parameter io_dao | Data access of the job monitor (tests: a double)
    "! @parameter io_log | Job log reader of the resolvers (tests: a double)
    METHODS constructor
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_job_dao OPTIONAL
        io_log TYPE REF TO zif_ca_ops_job_log OPTIONAL.

    "! State of an interval from its job's status
    CLASS-METHODS state_of
      IMPORTING
        is_job          TYPE zif_ca_ops_job_types=>ty_job
      RETURNING
        VALUE(rv_state) TYPE zif_ca_ops_ma_types=>ty_state.

  PRIVATE SECTION.
    DATA mo_dao TYPE REF TO zif_ca_ops_job_dao.
    DATA mo_log TYPE REF TO zif_ca_ops_job_log.

    "! Links of the parents' children by the resolvers in order (the first link of a child wins)
    METHODS children
      IMPORTING
        it_parents      TYPE zif_ca_ops_job_types=>tt_job
        iv_max          TYPE i
        it_programs     TYPE zif_ca_ops_types=>tt_param_range
      RETURNING
        VALUE(rt_links) TYPE zif_ca_ops_job_types=>tt_link
      RAISING
        zcx_ca_ops_error.

    "! The intervals of one parent, numbered in creation order
    CLASS-METHODS intervals
      IMPORTING
        is_parent           TYPE zif_ca_ops_job_types=>ty_job
        it_links            TYPE zif_ca_ops_job_types=>tt_link
        it_children         TYPE zif_ca_ops_job_types=>tt_job
        is_now              TYPE zif_ca_ops_job_types=>ty_point
      RETURNING
        VALUE(rt_intervals) TYPE zif_ca_ops_ma_types=>tt_interval.

ENDCLASS.



CLASS zcl_ca_ops_ma_src_jobs IMPLEMENTATION.

  METHOD constructor.
    mo_dao = COND #( WHEN io_dao IS BOUND THEN io_dao ELSE NEW zcl_ca_ops_job_dao( ) ).
    mo_log = COND #( WHEN io_log IS BOUND THEN io_log
                     ELSE NEW zcl_ca_ops_job_log_cache( io_reader = NEW zcl_ca_ops_job_log( )
                                                        iv_budget = zif_ca_ops_job_types=>gc_param_default-max_log_reads ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_ma_src~runs.
    DATA lt_programs TYPE zif_ca_ops_types=>tt_param_range.
    DATA lt_parents TYPE zif_ca_ops_job_types=>tt_job.
    DATA lt_keys TYPE zif_ca_ops_job_types=>tt_job_key.

    IF zcl_ca_ops_util=>pcre_valid( is_activity-job_pattern ) = abap_false OR is_activity-job_pattern IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e620(zca_ops) WITH is_activity-act_id is_activity-job_pattern.
    ENDIF.
    IF is_activity-parent_program IS NOT INITIAL.
      lt_programs = VALUE #( ( sign   = zif_ca_ops_types=>gc_range-sign_include
                               option = zif_ca_ops_types=>gc_range-option_equal
                               low    = is_activity-parent_program ) ).
    ENDIF.
    DATA(ls_now) = zcl_ca_ops_job_time=>now( ).
    DATA(lt_ran) = mo_dao->jobs_running( is_window   = VALUE #( from = VALUE #( date = iv_from ) to = ls_now )
                                         it_programs = lt_programs
                                         iv_max      = iv_max ).
    rs_runs-partial = xsdbool( lines( lt_ran ) >= iv_max ).
    LOOP AT lt_ran ASSIGNING FIELD-SYMBOL(<ls_job>).
      IF zcl_ca_ops_util=>pcre_match( iv_value = <ls_job>-jobname iv_pattern = is_activity-job_pattern ) = abap_true.
        INSERT <ls_job> INTO TABLE lt_parents.
      ENDIF.
    ENDLOOP.
    IF lt_parents IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_max_intervals) = nmax( val1 = 1
                                   val2 = zcl_ca_ops_util=>param_int(
                                            io_params  = zcl_ca_ops_factory=>get_params( )
                                            iv_name    = zif_ca_ops_ma_types=>gc_param-max_intervals
                                            iv_default = zif_ca_ops_ma_types=>gc_param_default-max_intervals ) ).
    DATA(lt_links) = children( it_parents  = lt_parents
                               iv_max      = lv_max_intervals
                               it_programs = lt_programs ).
    LOOP AT lt_links ASSIGNING FIELD-SYMBOL(<ls_link>).
      INSERT VALUE #( jobname = <ls_link>-child_name jobcount = <ls_link>-child_count ) INTO TABLE lt_keys.
    ENDLOOP.
    DATA(lt_children) = mo_dao->jobs( lt_keys ).
    LOOP AT lt_parents ASSIGNING FIELD-SYMBOL(<ls_parent>).
      DATA(lt_intervals) = intervals( is_parent   = <ls_parent>
                                      it_links    = lt_links
                                      it_children = lt_children
                                      is_now      = ls_now ).
      IF lines( lt_intervals ) >= lv_max_intervals.
        rs_runs-partial = abap_true.
      ENDIF.
      INSERT VALUE #( act_id    = is_activity-act_id
                      aktyp     = is_activity-aktyp
                      run_date  = <ls_parent>-strtdate
                      parent    = <ls_parent>
                      intervals = lt_intervals
                      quality   = zif_ca_ops_exc_contract=>gc_quality-probable ) INTO TABLE rs_runs-runs.
    ENDLOOP.
  ENDMETHOD.


  METHOD children.
    DATA lt_classes TYPE string_table.

    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    lt_classes = zcl_ca_ops_util=>split_list( lo_params->get_param( zif_ca_ops_ma_types=>gc_param-resolvers ) ).
    IF lt_classes IS INITIAL.
      lt_classes = zcl_ca_ops_util=>split_list( lo_params->get_param(
                     iv_name    = zif_ca_ops_job_types=>gc_param-resolvers
                     iv_default = zif_ca_ops_job_types=>gc_param_default-resolvers ) ).
    ENDIF.
    DATA(ls_config) = VALUE zif_ca_ops_job_types=>ty_config(
                        max_jobs        = zif_ca_ops_job_types=>gc_param_default-max_jobs
                        max_log_reads   = zif_ca_ops_job_types=>gc_param_default-max_log_reads
                        max_children    = iv_max
                        parent_programs = it_programs ).
    LOOP AT lt_classes ASSIGNING FIELD-SYMBOL(<lv_class>).
      DATA(lo_resolver) = CAST zif_ca_ops_job_resolver( zcl_ca_ops_factory=>get_plugin(
                            iv_class_name = CONV #( to_upper( <lv_class> ) )
                            iv_interface  = zif_ca_ops_job_types=>gc_plugin_intf-resolver ) ).
      LOOP AT lo_resolver->children( it_jobs   = it_parents
                                     is_config = ls_config
                                     io_dao    = mo_dao
                                     io_log    = mo_log ) ASSIGNING FIELD-SYMBOL(<ls_link>).
        IF NOT line_exists( rt_links[ child_name = <ls_link>-child_name child_count = <ls_link>-child_count ] ).
          INSERT <ls_link> INTO TABLE rt_links.
        ENDIF.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD intervals.
    DATA lt_jobs TYPE zif_ca_ops_job_types=>tt_job.

    LOOP AT it_links ASSIGNING FIELD-SYMBOL(<ls_link>)
         WHERE parent_name = is_parent-jobname AND parent_count = is_parent-jobcount.
      READ TABLE it_children INTO DATA(ls_child) WITH KEY jobname  = <ls_link>-child_name
                                                          jobcount = <ls_link>-child_count.
      IF sy-subrc = 0.
        INSERT ls_child INTO TABLE lt_jobs.
      ENDIF.
    ENDLOOP.
    SORT lt_jobs BY sdldate sdltime jobname jobcount.
    LOOP AT lt_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      DATA(ls_interval) = VALUE zif_ca_ops_ma_types=>ty_interval( number = sy-tabix
                                                                  job    = <ls_job>
                                                                  state  = state_of( <ls_job> ) ).
      IF <ls_job>-strtdate IS NOT INITIAL.
        ls_interval-minutes = zcl_ca_ops_job_time=>minutes_between(
                                is_from = zcl_ca_ops_job_time=>started( <ls_job> )
                                is_to   = COND #( WHEN ls_interval-state = zif_ca_ops_ma_types=>gc_state-running
                                                    OR <ls_job>-enddate IS INITIAL
                                                  THEN is_now
                                                  ELSE zcl_ca_ops_job_time=>ended( <ls_job> ) ) ).
      ENDIF.
      INSERT ls_interval INTO TABLE rt_intervals.
    ENDLOOP.
  ENDMETHOD.


  METHOD state_of.
    rv_state = SWITCH #( is_job-status
                         WHEN zif_ca_ops_job_types=>gc_status-finished   THEN zif_ca_ops_ma_types=>gc_state-ok
                         WHEN zif_ca_ops_job_types=>gc_status-aborted    THEN zif_ca_ops_ma_types=>gc_state-failed
                         WHEN zif_ca_ops_job_types=>gc_status-running
                           OR zif_ca_ops_job_types=>gc_status-put_active THEN zif_ca_ops_ma_types=>gc_state-running
                         ELSE zif_ca_ops_ma_types=>gc_state-waiting ).
  ENDMETHOD.

ENDCLASS.
