*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_src_tbtco.clas.abap
*& Purpose:
*& Delivered scheduler source of the payment file lifecycle (role SCHED)
*& on SAP background jobs, through the SAP job monitor's data access
*& (ZIF_CA_OPS_JOB_DAO=>JOBS_RUNNING on TBTCO / TBTCP - no SQL of its own):
*& the jobs of the programs of the setting that ran in the window, each
*& one event with the job status as native status (F finished, A
*& cancelled, R / Z / S / P / Y otherwise - the status mapping says which
*& is GENERATED OK / FAILED; template rows for source SAPJOB), its end
*& (else start) in UTC and the job name and count (link object
*& S4_BACKGROUND_JOB). A job names no file: the engine matches it to the
*& open files of the file type of its business date (quality probable).
*& Setting: PROGRAMS=<report names> (comma list, required - the payment
*& medium program of the site, V175). System time of TBTCO converted with
*& CL_ABAP_TSTMP (V177). Read only.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - scheduler source: SAP jobs</p>
CLASS zcl_ca_ops_pf_src_tbtco DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_pf_sched_src.

    "! Link registry object of a background job (config/links/s4core.json)
    CONSTANTS gc_link_object TYPE zif_ca_ops_exc_contract=>ty_link_object VALUE 'S4_BACKGROUND_JOB'.

    "! @parameter io_dao | Data access of the job monitor (tests: a double)
    METHODS constructor
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_job_dao OPTIONAL.

    "! Events of jobs (public for the tests)
    METHODS events_of
      IMPORTING
        it_jobs          TYPE zif_ca_ops_job_types=>tt_job
      RETURNING
        VALUE(rt_events) TYPE zif_ca_ops_pf_types=>tt_src_event.

  PRIVATE SECTION.
    DATA mo_dao TYPE REF TO zif_ca_ops_job_dao.
    DATA mt_programs TYPE zif_ca_ops_types=>tt_param_range.

    CLASS-METHODS to_utc
      IMPORTING
        iv_date      TYPE d
        iv_time      TYPE t
      RETURNING
        VALUE(rv_ts) TYPE timestampl.

    CLASS-METHODS to_system
      IMPORTING
        iv_ts           TYPE timestampl
      RETURNING
        VALUE(rs_point) TYPE zif_ca_ops_job_types=>ty_point.

ENDCLASS.



CLASS zcl_ca_ops_pf_src_tbtco IMPLEMENTATION.

  METHOD constructor.
    mo_dao = COND #( WHEN io_dao IS BOUND THEN io_dao ELSE NEW zcl_ca_ops_job_dao( ) ).
  ENDMETHOD.


  METHOD zif_ca_ops_pf_adapter~configure.
    CLEAR mt_programs.
    SPLIT is_adapter-setting AT ';' INTO TABLE DATA(lt_parts).
    LOOP AT lt_parts ASSIGNING FIELD-SYMBOL(<lv_part>).
      SPLIT <lv_part> AT '=' INTO DATA(lv_name) DATA(lv_value).
      IF to_upper( condense( lv_name ) ) = 'PROGRAMS'.
        LOOP AT zcl_ca_ops_util=>split_list( to_upper( lv_value ) ) ASSIGNING FIELD-SYMBOL(<lv_program>).
          INSERT VALUE #( sign = 'I' option = 'EQ' low = <lv_program> ) INTO TABLE mt_programs.
        ENDLOOP.
      ENDIF.
    ENDLOOP.
    " without a program every job of the client would be a candidate: refused
    IF mt_programs IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e386(zca_ops) WITH is_adapter-role is_adapter-file_type is_adapter-class_name 'PROGRAMS'.
    ENDIF.
  ENDMETHOD.


  METHOD zif_ca_ops_pf_event_src~read_events.
    DATA(ls_window) = VALUE zif_ca_ops_job_types=>ty_window( from  = to_system( is_request-from_ts )
                                                             to    = to_system( is_request-to_ts )
                                                             first = is_request-first ).
    DATA(lv_max) = COND i( WHEN is_request-max > 0 THEN is_request-max ELSE 1000 ).
    DATA(lt_jobs) = mo_dao->jobs_running( is_window   = ls_window
                                          it_programs = mt_programs
                                          iv_max      = lv_max ).
    rs_batch-partial = xsdbool( lines( lt_jobs ) >= lv_max ).
    rs_batch-as_of = is_request-to_ts.
    rs_batch-events = events_of( lt_jobs ).
  ENDMETHOD.


  METHOD events_of.
    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      DATA(lv_date) = COND d( WHEN <ls_job>-enddate IS NOT INITIAL THEN <ls_job>-enddate ELSE <ls_job>-strtdate ).
      DATA(lv_time) = COND t( WHEN <ls_job>-enddate IS NOT INITIAL THEN <ls_job>-endtime ELSE <ls_job>-strttime ).
      INSERT VALUE #( source_event_id = |{ <ls_job>-jobname }/{ <ls_job>-jobcount }|
                      event_version   = 1
                      native_status   = <ls_job>-status
                      occurred_at     = to_utc( iv_date = lv_date iv_time = lv_time )
                      bus_date        = lv_date
                      job_name        = <ls_job>-jobname
                      job_count       = <ls_job>-jobcount
                      link_object     = gc_link_object
                      link_value      = zcl_ca_ops_exc_contract=>link_value(
                                          VALUE #( ( fieldname = 'JOBNAME'  value = <ls_job>-jobname )
                                                   ( fieldname = 'JOBCOUNT' value = <ls_job>-jobcount ) ) ) )
             INTO TABLE rt_events.
    ENDLOOP.
  ENDMETHOD.


  METHOD to_utc.
    IF iv_date IS INITIAL.
      RETURN.
    ENDIF.
    " VERIFY-ADT (V177): TBTCO holds system time; CL_ABAP_TSTMP converts it with the system time zone
    TRY.
        rv_ts = cl_abap_tstmp=>systemtstmp_syst2utc( syst_date = iv_date syst_time = iv_time ).
      CATCH cx_parameter_invalid_range.
        CLEAR rv_ts.
    ENDTRY.
  ENDMETHOD.


  METHOD to_system.
    DATA lv_ts TYPE timestamp.
    lv_ts = iv_ts.
    TRY.
        cl_abap_tstmp=>systemtstmp_utc2syst( EXPORTING utc_tstmp = lv_ts
                                             IMPORTING syst_date = rs_point-date
                                                       syst_time = rs_point-time ).
      CATCH cx_parameter_invalid_range.
        CLEAR rs_point.
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
