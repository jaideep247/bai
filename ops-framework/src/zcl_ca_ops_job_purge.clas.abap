*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_purge.clas.abap
*& Purpose:
*& Purge target JOB_EVIDENCE of the SAP job monitor (registry row of
*& ZCA_OPS_PURGE, retention RETENTION_DAYS_JOB_EVIDENCE): the kept jobs of
*& ZCA_OPS_JOB detected before the cutoff, with their steps, job log lines,
*& application log links and business objects (ZCA_OPS_JOBSTEP, _JOBMSG,
*& _JOBALOG, _JOBBO), one package at a time - set-based (child keys read
*& for the package, deleted from the table of keys). The watermark is never
*& purged. No commit: the purge commits per package.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - purge target SAP job evidence</p>
CLASS zcl_ca_ops_job_purge DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_purge_target.

ENDCLASS.



CLASS zcl_ca_ops_job_purge IMPLEMENTATION.

  METHOD zif_ca_ops_purge_target~count_purgeable.
    SELECT COUNT(*)
      FROM zca_ops_job
      WHERE detected_at < @iv_cutoff
      INTO @rv_count.
  ENDMETHOD.


  METHOD zif_ca_ops_purge_target~delete_package.
    DATA lt_jobs TYPE STANDARD TABLE OF zca_ops_job WITH EMPTY KEY.
    DATA lt_steps TYPE STANDARD TABLE OF zca_ops_jobstep WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF zca_ops_jobmsg WITH EMPTY KEY.
    DATA lt_applogs TYPE STANDARD TABLE OF zca_ops_jobalog WITH EMPTY KEY.
    DATA lt_objects TYPE STANDARD TABLE OF zca_ops_jobbo WITH EMPTY KEY.

    CLEAR: ev_dependent, ev_history.
    SELECT jobname, jobcount
      FROM zca_ops_job
      WHERE detected_at < @iv_cutoff
      ORDER BY detected_at, jobname, jobcount
      INTO CORRESPONDING FIELDS OF TABLE @lt_jobs
      UP TO @iv_max ROWS.
    IF lt_jobs IS INITIAL.
      RETURN.
    ENDIF.
    SELECT jobname, jobcount, stepcount
      FROM zca_ops_jobstep
      FOR ALL ENTRIES IN @lt_jobs
      WHERE jobname  = @lt_jobs-jobname
        AND jobcount = @lt_jobs-jobcount
      INTO CORRESPONDING FIELDS OF TABLE @lt_steps.
    SELECT jobname, jobcount, line_no
      FROM zca_ops_jobmsg
      FOR ALL ENTRIES IN @lt_jobs
      WHERE jobname  = @lt_jobs-jobname
        AND jobcount = @lt_jobs-jobcount
      INTO CORRESPONDING FIELDS OF TABLE @lt_lines.
    SELECT jobname, jobcount, lognumber
      FROM zca_ops_jobalog
      FOR ALL ENTRIES IN @lt_jobs
      WHERE jobname  = @lt_jobs-jobname
        AND jobcount = @lt_jobs-jobcount
      INTO CORRESPONDING FIELDS OF TABLE @lt_applogs.
    SELECT jobname, jobcount, object_no
      FROM zca_ops_jobbo
      FOR ALL ENTRIES IN @lt_jobs
      WHERE jobname  = @lt_jobs-jobname
        AND jobcount = @lt_jobs-jobcount
      INTO CORRESPONDING FIELDS OF TABLE @lt_objects.
    IF lt_steps IS NOT INITIAL.
      DELETE zca_ops_jobstep FROM TABLE @lt_steps.
      ev_dependent += sy-dbcnt.
    ENDIF.
    IF lt_lines IS NOT INITIAL.
      DELETE zca_ops_jobmsg FROM TABLE @lt_lines.
      ev_dependent += sy-dbcnt.
    ENDIF.
    IF lt_applogs IS NOT INITIAL.
      DELETE zca_ops_jobalog FROM TABLE @lt_applogs.
      ev_dependent += sy-dbcnt.
    ENDIF.
    IF lt_objects IS NOT INITIAL.
      DELETE zca_ops_jobbo FROM TABLE @lt_objects.
      ev_dependent += sy-dbcnt.
    ENDIF.
    DELETE zca_ops_job FROM TABLE @lt_jobs.
    rv_count = sy-dbcnt.
  ENDMETHOD.

ENDCLASS.
