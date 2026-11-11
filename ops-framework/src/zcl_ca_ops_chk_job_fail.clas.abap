*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_job_fail.clas.abap
*& Purpose:
*& Registered check (ZIF_CA_OPS_CHECK) of the SAP job monitor: failures of
*& every job of the client since the last window - cancelled jobs, jobs of
*& watched programs whose job log holds errors, and failed children whose
*& root (the job the scheduler started) did not abort (JOB_CHILD_FAILED).
*& Run by the generic runner in a fast schedule group (e.g. every 5
*& minutes); the engine is ZCL_CA_OPS_JOB_MONITOR=>FAILURES. Incremental:
*& its result is always partial (no auto-resolve).
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - check: SAP job failures</p>
"! Registry row: ZCA_OPS_CHECK with CLASS_NAME = ZCL_CA_OPS_CHK_JOB_FAIL, the area of the consumer and a
"! schedule group of its own (the watermark is kept per area and check ID).
CLASS zcl_ca_ops_chk_job_fail DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

    "! @parameter io_dao | Data access of the monitor (tests: a double)
    "! @parameter io_log | Job log reader (tests: a double)
    METHODS constructor
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_job_dao OPTIONAL
        io_log TYPE REF TO zif_ca_ops_job_log OPTIONAL.

  PRIVATE SECTION.
    DATA mo_monitor TYPE REF TO zcl_ca_ops_job_monitor.

ENDCLASS.



CLASS zcl_ca_ops_chk_job_fail IMPLEMENTATION.

  METHOD constructor.
    mo_monitor = NEW #( io_dao = io_dao
                        io_log = io_log ).
  ENDMETHOD.


  METHOD zif_ca_ops_check~run.
    rs_result = mo_monitor->failures( is_check   = is_check
                                      is_context = is_context ).
  ENDMETHOD.

ENDCLASS.
