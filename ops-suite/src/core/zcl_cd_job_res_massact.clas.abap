*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_job_res_massact.clas.abap
*& Purpose:
*& Parent / child resolver of the framework's SAP job monitor
*& (ZIF_CA_OPS_JOB_RESOLVER) for the payment engine's mass activities: the
*& parallel worker jobs of one RFKK_MA_SCHEDULER run. A worker is a job
*& whose name matches JOB_MA_WORKER_PCRE (group 1 = the run token); its
*& parent is the job of a scheduler program (JOB_MA_PROGRAMS) that ran
*& when the worker was created, with a step of the worker's scheduling user
*& and - when JOB_MA_SCHED_PCRE is maintained - the same run token in its
*& name; exactly one such job = link, quality P (name pattern and time
*& window; C once the run is linked through the mass activity tables,
*& VERIFY-SE11 V67). Children: the workers created during a scheduler job's
*& run (the framework's heuristic, restricted to worker names and tokens).
*& Blank JOB_MA_WORKER_PCRE = off. Reads through the monitor's data access.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor adoption, area CD_JOBS).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - job resolver: mass activity workers</p>
"! Delivered outside JOB_RESOLVERS until the worker naming is confirmed (put it before the heuristic).
CLASS zcl_cd_job_res_massact DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_resolver.

  PRIVATE SECTION.
    DATA mv_worker_pcre TYPE string.
    DATA mv_sched_pcre TYPE string.

    "! Read the patterns; abap_false = resolver off
    "! @raising zcx_ca_ops_error | 121 a pattern does not compile
    METHODS configured
      RETURNING
        VALUE(rv_on) TYPE abap_bool
      RAISING
        zcx_ca_ops_error.

    "! Run token of a name (group 1 of the pattern; blank = no match)
    CLASS-METHODS token
      IMPORTING
        iv_name         TYPE btcjob
        iv_pcre         TYPE string
      RETURNING
        VALUE(rv_token) TYPE string.

    "! The pair fits: the worker's token equals the scheduler's (when the scheduler pattern is maintained)
    METHODS same_run
      IMPORTING
        is_link          TYPE zif_ca_ops_job_types=>ty_link
      RETURNING
        VALUE(rv_result) TYPE abap_bool.

    "! Settings of the run with the parent programs = the mass activity scheduler programs
    METHODS scheduler_config
      IMPORTING
        is_config        TYPE zif_ca_ops_job_types=>ty_config
      RETURNING
        VALUE(rs_config) TYPE zif_ca_ops_job_types=>ty_config.

ENDCLASS.



CLASS zcl_cd_job_res_massact IMPLEMENTATION.

  METHOD zif_ca_ops_job_resolver~id.
    rv_id = zif_cd_job_types=>gc_resolver_mass.
  ENDMETHOD.


  METHOD zif_ca_ops_job_resolver~parents.
    DATA lt_workers TYPE zif_ca_ops_job_types=>tt_job.
    DATA lt_pairs TYPE zif_ca_ops_job_types=>tt_link.

    IF it_jobs IS INITIAL OR configured( ) = abap_false.
      RETURN.
    ENDIF.
    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      IF token( iv_name = <ls_job>-jobname iv_pcre = mv_worker_pcre ) IS NOT INITIAL.
        INSERT <ls_job> INTO TABLE lt_workers.
      ENDIF.
    ENDLOOP.
    IF lt_workers IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT zcl_ca_ops_job_res_heur=>parent_candidates( it_jobs   = lt_workers
                                                         is_config = scheduler_config( is_config )
                                                         io_dao    = io_dao ) ASSIGNING FIELD-SYMBOL(<ls_pair>).
      IF same_run( <ls_pair> ) = abap_true.
        INSERT <ls_pair> INTO TABLE lt_pairs.
      ENDIF.
    ENDLOOP.
    " exactly one scheduler run per worker - two are ambiguous, never a guess
    LOOP AT lt_pairs ASSIGNING <ls_pair>.
      IF REDUCE i( INIT lv_count = 0
                   FOR <ls_other> IN lt_pairs
                   WHERE ( child_name = <ls_pair>-child_name AND child_count = <ls_pair>-child_count )
                   NEXT lv_count = lv_count + 1 ) = 1.
        DATA(ls_link) = <ls_pair>.
        ls_link-resolver = zif_cd_job_types=>gc_resolver_mass.
        ls_link-quality  = zif_ca_ops_job_types=>gc_quality-probable.
        INSERT ls_link INTO TABLE rt_links.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD zif_ca_ops_job_resolver~children.
    IF it_jobs IS INITIAL OR configured( ) = abap_false.
      RETURN.
    ENDIF.
    DATA(lt_links) = NEW zcl_ca_ops_job_res_heur( )->zif_ca_ops_job_resolver~children(
                       it_jobs   = it_jobs
                       is_config = scheduler_config( is_config )
                       io_dao    = io_dao
                       io_log    = io_log ).
    LOOP AT lt_links ASSIGNING FIELD-SYMBOL(<ls_link>).
      IF token( iv_name = <ls_link>-child_name iv_pcre = mv_worker_pcre ) IS NOT INITIAL
         AND same_run( <ls_link> ) = abap_true.
        <ls_link>-resolver = zif_cd_job_types=>gc_resolver_mass.
        INSERT <ls_link> INTO TABLE rt_links.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD configured.
    DATA(lo_params) = zcl_cd_ops_factory=>get_params( ).
    mv_worker_pcre = lo_params->get_param( iv_name = zif_cd_job_types=>gc_param-ma_worker_pcre
                                           iv_area = zif_ca_ops_types=>gc_param_area ).
    mv_sched_pcre = lo_params->get_param( iv_name = zif_cd_job_types=>gc_param-ma_sched_pcre
                                          iv_area = zif_ca_ops_types=>gc_param_area ).
    IF mv_worker_pcre IS INITIAL.
      RETURN.
    ENDIF.
    IF zcl_ca_ops_util=>pcre_valid( mv_worker_pcre ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e121(zca_ops) WITH zif_cd_job_types=>gc_param-ma_worker_pcre mv_worker_pcre.
    ENDIF.
    IF zcl_ca_ops_util=>pcre_valid( mv_sched_pcre ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e121(zca_ops) WITH zif_cd_job_types=>gc_param-ma_sched_pcre mv_sched_pcre.
    ENDIF.
    rv_on = abap_true.
  ENDMETHOD.


  METHOD token.
    FIND FIRST OCCURRENCE OF PCRE iv_pcre IN iv_name IGNORING CASE SUBMATCHES rv_token.
    IF sy-subrc <> 0.
      CLEAR rv_token.
    ENDIF.
  ENDMETHOD.


  METHOD same_run.
    IF mv_sched_pcre IS INITIAL.
      rv_result = abap_true.
      RETURN.
    ENDIF.
    DATA(lv_parent_token) = token( iv_name = is_link-parent_name iv_pcre = mv_sched_pcre ).
    rv_result = xsdbool( lv_parent_token IS NOT INITIAL
                         AND to_upper( lv_parent_token )
                           = to_upper( token( iv_name = is_link-child_name iv_pcre = mv_worker_pcre ) ) ).
  ENDMETHOD.


  METHOD scheduler_config.
    rs_config = is_config.
    CLEAR rs_config-parent_programs.
    LOOP AT zcl_ca_ops_util=>split_list( zcl_cd_ops_factory=>get_params( )->get_param(
                                           iv_name    = zif_cd_job_types=>gc_param-ma_programs
                                           iv_default = zif_cd_job_types=>gc_param_default-ma_programs
                                           iv_area    = zif_ca_ops_types=>gc_param_area ) ) ASSIGNING FIELD-SYMBOL(<lv_program>).
      INSERT VALUE #( sign   = zif_ca_ops_types=>gc_range-sign_include
                      option = zif_ca_ops_types=>gc_range-option_equal
                      low    = to_upper( <lv_program> ) ) INTO TABLE rs_config-parent_programs.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
