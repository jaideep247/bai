*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_res_joblog.clas.abap
*& Purpose:
*& Parent / child resolver JOBLOG of the SAP job monitor: a job log line
*& that announces a released job names the child. The announcing messages
*& are configuration (JOB_CHILD_MSG_IDS, MSGID/MSGNO list) and the text is
*& read with JOB_CHILD_MSG_PCRE (group 1 = job name, group 2 = job count);
*& either blank = resolver off. Children: from the parents' logs. Parents:
*& the candidates of the heuristic (ran when the child was created, step
*& of its scheduling user) whose log names the child. Quality C (the log
*& names job name and count). Job logs through the monitor's reader (its
*& read budget JOB_MAX_LOG_READS applies).
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - job resolver JOBLOG</p>
"! VERIFY-SE91 V62: message class / number of the job log line that names a released child (e.g. of
"! the mass activity scheduler) and its text layout; delivered off (blank parameters).
CLASS zcl_ca_ops_job_res_joblog DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_resolver.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_msg_id,
        msgid TYPE symsgid,
        msgno TYPE symsgno,
      END OF ty_msg_id.
    TYPES tt_msg_id TYPE SORTED TABLE OF ty_msg_id WITH UNIQUE KEY msgid msgno.

    CONSTANTS gc_id_separator TYPE string VALUE `/`.

    DATA mt_msg_ids TYPE tt_msg_id.
    DATA mv_pcre TYPE string.

    "! Read the parameters; abap_false = resolver off
    "! @raising zcx_ca_ops_error | 121 the pattern is not valid PCRE
    METHODS configured
      RETURNING
        VALUE(rv_on) TYPE abap_bool
      RAISING
        zcx_ca_ops_error.

    "! Children named by the log of one job
    METHODS named_children
      IMPORTING
        is_parent       TYPE zif_ca_ops_job_types=>ty_job
        io_log          TYPE REF TO zif_ca_ops_job_log
      RETURNING
        VALUE(rt_links) TYPE zif_ca_ops_job_types=>tt_link
      RAISING
        zcx_ca_ops_error.

ENDCLASS.



CLASS zcl_ca_ops_job_res_joblog IMPLEMENTATION.

  METHOD zif_ca_ops_job_resolver~id.
    rv_id = zif_ca_ops_job_types=>gc_resolver-job_log.
  ENDMETHOD.


  METHOD zif_ca_ops_job_resolver~parents.
    DATA lt_named TYPE zif_ca_ops_job_types=>tt_link.
    DATA lt_read TYPE zif_ca_ops_job_types=>tt_job_key.

    IF it_jobs IS INITIAL OR configured( ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lt_pairs) = zcl_ca_ops_job_res_heur=>parent_candidates( it_jobs   = it_jobs
                                                                  is_config = is_config
                                                                  io_dao    = io_dao ).
    LOOP AT lt_pairs ASSIGNING FIELD-SYMBOL(<ls_pair>).
      " one log read per candidate parent
      INSERT VALUE #( jobname = <ls_pair>-parent_name jobcount = <ls_pair>-parent_count ) INTO TABLE lt_read.
      IF sy-subrc = 0.
        INSERT LINES OF named_children( is_parent = VALUE #( jobname  = <ls_pair>-parent_name
                                                             jobcount = <ls_pair>-parent_count )
                                        io_log    = io_log ) INTO TABLE lt_named.
      ENDIF.
    ENDLOOP.
    LOOP AT lt_named ASSIGNING FIELD-SYMBOL(<ls_named>).
      IF line_exists( it_jobs[ jobname = <ls_named>-child_name jobcount = <ls_named>-child_count ] )
         AND NOT line_exists( rt_links[ child_name = <ls_named>-child_name child_count = <ls_named>-child_count ] ).
        INSERT <ls_named> INTO TABLE rt_links.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_job_resolver~children.
    IF it_jobs IS INITIAL OR configured( ) = abap_false.
      RETURN.
    ENDIF.
    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_parent>).
      DATA(lt_named) = named_children( is_parent = <ls_parent>
                                       io_log    = io_log ).
      DELETE lt_named FROM is_config-max_children + 1.
      INSERT LINES OF lt_named INTO TABLE rt_links.
    ENDLOOP.
  ENDMETHOD.


  METHOD configured.
    CLEAR: mt_msg_ids, mv_pcre.
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    mv_pcre = lo_params->get_param( iv_name = zif_ca_ops_job_types=>gc_param-child_msg_pcre
                                    iv_area = zif_ca_ops_types=>gc_param_area ).
    LOOP AT zcl_ca_ops_util=>split_list( lo_params->get_param( iv_name = zif_ca_ops_job_types=>gc_param-child_msg_ids
                                                               iv_area = zif_ca_ops_types=>gc_param_area ) )
         ASSIGNING FIELD-SYMBOL(<lv_id>).
      SPLIT <lv_id> AT gc_id_separator INTO DATA(lv_msgid) DATA(lv_msgno).
      INSERT VALUE #( msgid = to_upper( lv_msgid ) msgno = lv_msgno ) INTO TABLE mt_msg_ids.
    ENDLOOP.
    IF mv_pcre IS INITIAL OR mt_msg_ids IS INITIAL.
      RETURN.
    ENDIF.
    IF zcl_ca_ops_util=>pcre_valid( mv_pcre ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e121(zca_ops) WITH zif_ca_ops_job_types=>gc_param-child_msg_pcre.
    ENDIF.
    rv_on = abap_true.
  ENDMETHOD.


  METHOD named_children.
    DATA lv_name TYPE string.
    DATA lv_count TYPE string.
    LOOP AT io_log->read( iv_jobname  = is_parent-jobname
                          iv_jobcount = is_parent-jobcount ) ASSIGNING FIELD-SYMBOL(<ls_line>).
      IF NOT line_exists( mt_msg_ids[ msgid = <ls_line>-msgid msgno = <ls_line>-msgno ] ).
        CONTINUE.
      ENDIF.
      CLEAR: lv_name, lv_count.
      FIND FIRST OCCURRENCE OF PCRE mv_pcre IN <ls_line>-text SUBMATCHES lv_name lv_count IGNORING CASE.
      IF sy-subrc <> 0 OR lv_name IS INITIAL OR lv_count IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( parent_name  = is_parent-jobname
                      parent_count = is_parent-jobcount
                      child_name   = to_upper( lv_name )
                      child_count  = lv_count
                      resolver     = zif_ca_ops_job_types=>gc_resolver-job_log
                      quality      = zif_ca_ops_job_types=>gc_quality-confirmed ) INTO TABLE rt_links.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
