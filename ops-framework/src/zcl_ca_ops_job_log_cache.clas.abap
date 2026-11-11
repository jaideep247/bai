*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_log_cache.clas.abap
*& Purpose:
*& Job log reader of one run of the SAP job monitor: each log is read at
*& most once (cache by job) and at most JOB_MAX_LOG_READS logs per run (a
*& budget shared by detection, resolvers and evidence). Over budget a read
*& returns nothing and EXHAUSTED says so - the caller decides what is not
*& evaluated. Wraps the reader seam ZIF_CA_OPS_JOB_LOG (BP_JOBLOG_READ in
*& production, a double in tests). Read only.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - job log reader with budget</p>
CLASS zcl_ca_ops_job_log_cache DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_log.

    "! @parameter io_reader | The reader of the logs (BP_JOBLOG_READ or a double)
    "! @parameter iv_budget | Logs that may be read in this run
    METHODS constructor
      IMPORTING
        io_reader TYPE REF TO zif_ca_ops_job_log
        iv_budget TYPE i.

    "! The log of the job is cached or the budget allows one more read
    METHODS can_read
      IMPORTING
        iv_jobname       TYPE btcjob
        iv_jobcount      TYPE btcjobcnt
      RETURNING
        VALUE(rv_result) TYPE abap_bool.

    "! A read was refused because the budget was used up
    METHODS exhausted
      RETURNING
        VALUE(rv_result) TYPE abap_bool.

    "! Logs read from the reader in this run
    METHODS reads
      RETURNING
        VALUE(rv_count) TYPE i.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_entry,
        jobname  TYPE btcjob,
        jobcount TYPE btcjobcnt,
        lines    TYPE zif_ca_ops_job_types=>tt_log_line,
      END OF ty_entry.
    TYPES tt_entry TYPE HASHED TABLE OF ty_entry WITH UNIQUE KEY jobname jobcount.

    DATA mo_reader TYPE REF TO zif_ca_ops_job_log.
    DATA mv_budget TYPE i.
    DATA mv_reads TYPE i.
    DATA mv_exhausted TYPE abap_bool.
    DATA mt_cache TYPE tt_entry.

ENDCLASS.



CLASS zcl_ca_ops_job_log_cache IMPLEMENTATION.

  METHOD constructor.
    mo_reader = io_reader.
    mv_budget = iv_budget.
  ENDMETHOD.


  METHOD zif_ca_ops_job_log~read.
    READ TABLE mt_cache ASSIGNING FIELD-SYMBOL(<ls_entry>)
         WITH TABLE KEY jobname = iv_jobname jobcount = iv_jobcount.
    IF sy-subrc = 0.
      rt_lines = <ls_entry>-lines.
      RETURN.
    ENDIF.
    IF mv_reads >= mv_budget.
      mv_exhausted = abap_true.
      RETURN.
    ENDIF.
    mv_reads += 1.
    " a failed read is cached empty: the same log is never asked twice in a run
    INSERT VALUE #( jobname = iv_jobname jobcount = iv_jobcount ) INTO TABLE mt_cache ASSIGNING <ls_entry>.
    <ls_entry>-lines = mo_reader->read( iv_jobname  = iv_jobname
                                        iv_jobcount = iv_jobcount ).
    rt_lines = <ls_entry>-lines.
  ENDMETHOD.


  METHOD can_read.
    rv_result = xsdbool( mv_reads < mv_budget
                         OR line_exists( mt_cache[ jobname = iv_jobname jobcount = iv_jobcount ] ) ).
  ENDMETHOD.


  METHOD exhausted.
    rv_result = mv_exhausted.
  ENDMETHOD.


  METHOD reads.
    rv_count = mv_reads.
  ENDMETHOD.

ENDCLASS.
