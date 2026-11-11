*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_chk_job_state.clas.abap
*& Purpose:
*& Registered check (ZIF_CA_OPS_CHECK) of the SAP job monitor: the jobs of
*& the client that are active far beyond JOB_LONG_RUNNING_MIN (long-
*& running or orphaned) and the released jobs that did not start
*& JOB_NOT_STARTED_MIN after their planned start (stuck in the queue). A
*& snapshot (engine ZCL_CA_OPS_JOB_MONITOR=>STATES): complete unless a read
*& was capped, so an exception of a job that has since ended or started is
*& resolved by the next run.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - check: long-running / waiting jobs</p>
CLASS zcl_ca_ops_chk_job_state DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_check.

    "! @parameter io_dao | Data access of the monitor (tests: a double)
    METHODS constructor
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_job_dao OPTIONAL.

  PRIVATE SECTION.
    DATA mo_monitor TYPE REF TO zcl_ca_ops_job_monitor.

ENDCLASS.



CLASS zcl_ca_ops_chk_job_state IMPLEMENTATION.

  METHOD constructor.
    mo_monitor = NEW #( io_dao = io_dao ).
  ENDMETHOD.


  METHOD zif_ca_ops_check~run.
    rs_result = mo_monitor->states( is_check   = is_check
                                    is_context = is_context ).
  ENDMETHOD.

ENDCLASS.
