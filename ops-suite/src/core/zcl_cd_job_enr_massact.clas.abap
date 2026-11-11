*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_job_enr_massact.clas.abap
*& Purpose:
*& Enricher of the framework's SAP job monitor (ZIF_CA_OPS_JOB_ENRICHER)
*& for the payment engine's mass activities (RFKK_MA_SCHEDULER and its
*& parallel worker jobs): the mass activity run of a failed job or of its
*& ancestor - activity type, run date and run ID - read from the job name
*& with JOB_MA_RUN_PCRE (group 1 activity, 2 run date YYYYMMDD, 3 run ID).
*& Quality P (from the name, not from a mass activity table). Blank pattern
*& = adds nothing; the class is delivered outside JOB_ENRICHERS until the
*& job naming and the mass activity tables are confirmed (VERIFY-SE11 V67).
*& The failed intervals of a run are not read (the interval table and its
*& status are not confirmed - not built). No SQL.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor adoption, area CD_JOBS).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - job enricher: mass activity run</p>
CLASS zcl_cd_job_enr_massact DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_enricher.

    "! The mass activity run of a job name (blank when the pattern does not match or the date is invalid)
    CLASS-METHODS run_of
      IMPORTING
        iv_jobname    TYPE btcjob
        iv_pcre       TYPE string
      RETURNING
        VALUE(rs_run) TYPE zif_cd_job_types=>ty_mass_run.

  PRIVATE SECTION.
    "! A run date of the job name: eight digits (YYYYMMDD)
    CONSTANTS gc_date_pcre TYPE string VALUE `\d{8}`.

ENDCLASS.



CLASS zcl_cd_job_enr_massact IMPLEMENTATION.

  METHOD zif_ca_ops_job_enricher~enrich.
    DATA(lv_pcre) = zcl_cd_ops_factory=>get_params( )->get_param( iv_name = zif_cd_job_types=>gc_param-ma_run_pcre
                                                                  iv_area = zif_ca_ops_types=>gc_param_area ).
    IF lv_pcre IS INITIAL OR it_jobs IS INITIAL.
      RETURN.
    ENDIF.
    IF zcl_ca_ops_util=>pcre_valid( lv_pcre ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e121(zca_ops) WITH zif_cd_job_types=>gc_param-ma_run_pcre lv_pcre.
    ENDIF.
    LOOP AT it_jobs ASSIGNING FIELD-SYMBOL(<ls_job>).
      DATA(ls_run) = run_of( iv_jobname = <ls_job>-jobname iv_pcre = lv_pcre ).
      IF ls_run IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( jobname     = <ls_job>-jobname
                      jobcount    = <ls_job>-jobcount
                      enricher    = cl_abap_classdescr=>get_class_name( me )
                      object_type = zif_cd_job_types=>gc_object_type-mass_run
                      object_key  = |{ ls_run-activity }{ zif_cd_job_types=>gc_key_separator }{ ls_run-run_date }|
                                 && |{ zif_cd_job_types=>gc_key_separator }{ ls_run-run_id }|
                      label       = zcl_cd_ops_util=>text( iv_msgno = zif_cd_job_types=>gc_msg-mass_run
                                                           iv_v1    = ls_run-activity
                                                           iv_v2    = |{ ls_run-run_date DATE = ISO }|
                                                           iv_v3    = ls_run-run_id )
                      quality     = zif_ca_ops_job_types=>gc_quality-probable ) INTO TABLE ct_objects.
    ENDLOOP.
  ENDMETHOD.


  METHOD run_of.
    DATA lv_activity TYPE string.
    DATA lv_date TYPE string.
    DATA lv_id TYPE string.
    DATA lv_run_date TYPE d.
    FIND FIRST OCCURRENCE OF PCRE iv_pcre IN iv_jobname IGNORING CASE SUBMATCHES lv_activity lv_date lv_id.
    IF sy-subrc <> 0 OR lv_activity IS INITIAL OR lv_id IS INITIAL OR NOT matches( val = lv_date pcre = gc_date_pcre ).
      RETURN.
    ENDIF.
    lv_run_date = lv_date.
    " a date that does not exist (e.g. 20261340) converts to 0: not a run date
    IF CONV i( lv_run_date ) = 0.
      RETURN.
    ENDIF.
    rs_run = VALUE #( activity = to_upper( lv_activity ) run_date = lv_run_date run_id = to_upper( lv_id ) ).
  ENDMETHOD.

ENDCLASS.
