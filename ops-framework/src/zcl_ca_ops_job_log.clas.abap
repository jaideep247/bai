*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_log.clas.abap
*& Purpose:
*& Job log reader of the SAP job monitor: BP_JOBLOG_READ for one job of
*& the logon client (read only). An empty or missing log is an empty
*& result; any other failure raises 123. The call is wrapped in the
*& TEST-SEAM JOBLOG_READ (return code and lines in local variables).
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor; TEST-SEAM JOBLOG_READ).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - job log reader (BP_JOBLOG_READ)</p>
"! VERIFY-SE37 V60: interface of BP_JOBLOG_READ on 7.58 (CLIENT, JOBCOUNT, JOBNAME, table JOBLOGTBL of
"! structure TBTC5 with ENTERDATE, ENTERTIME, TEXT, MSGID, MSGNO, MSGTYPE; exceptions as below).
CLASS zcl_ca_ops_job_log DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_log.

  PRIVATE SECTION.
    "! Return codes of BP_JOBLOG_READ that mean "no log" (does not exist, empty): an empty result
    CONSTANTS:
      BEGIN OF gc_rc,
        ok         TYPE i VALUE 0,
        not_exists TYPE i VALUE 3,
        empty      TYPE i VALUE 4,
      END OF gc_rc.

ENDCLASS.



CLASS zcl_ca_ops_job_log IMPLEMENTATION.

  METHOD zif_ca_ops_job_log~read.
    DATA lt_log TYPE STANDARD TABLE OF tbtc5 WITH EMPTY KEY.
    DATA lv_rc TYPE i.

    TEST-SEAM joblog_read.
      CALL FUNCTION 'BP_JOBLOG_READ'
        EXPORTING
          client                = sy-mandt
          jobcount              = iv_jobcount
          jobname               = iv_jobname
        TABLES
          joblogtbl             = lt_log
        EXCEPTIONS
          cant_read_joblog      = 1
          jobcount_missing      = 2
          joblog_does_not_exist = 3
          joblog_is_empty       = 4
          joblog_name_missing   = 5
          jobname_missing       = 6
          job_does_not_exist    = 7
          OTHERS                = 8.
      lv_rc = sy-subrc.
    END-TEST-SEAM.

    CASE lv_rc.
      WHEN gc_rc-ok.
        rt_lines = CORRESPONDING #( lt_log ).
      WHEN gc_rc-not_exists OR gc_rc-empty.
        RETURN.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e123(zca_ops) WITH iv_jobname iv_jobcount lv_rc.
    ENDCASE.
  ENDMETHOD.

ENDCLASS.
