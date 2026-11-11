*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_job_log.intf.abap
*& Purpose:
*& Seam of the SAP job monitor for reading a job log (implementation
*& ZCL_CA_OPS_JOB_LOG over BP_JOBLOG_READ): the unit tests of the monitor
*& and of the resolvers hand in a double and never call the function
*& module. Read only.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - job log reader</p>
INTERFACE zif_ca_ops_job_log
  PUBLIC.

  "! Lines of the job log of one job (empty when the job has no log)
  "! @raising zcx_ca_ops_error | 123 the log could not be read (deleted, no authorisation)
  METHODS read
    IMPORTING
      iv_jobname      TYPE btcjob
      iv_jobcount     TYPE btcjobcnt
    RETURNING
      VALUE(rt_lines) TYPE zif_ca_ops_job_types=>tt_log_line
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
