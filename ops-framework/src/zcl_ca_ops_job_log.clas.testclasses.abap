*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_log.clas.testclasses.abap
*& Purpose:
*& Tests of the job log reader through the TEST-SEAM JOBLOG_READ (the
*& function module is never called): the lines of a read log are mapped,
*& a missing or empty log is an empty result, any other return code
*& raises 123. Does not prove live SAP runtime behavior (VERIFY-SE37 V60).
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
CLASS ltc_job_log DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        jobname  TYPE btcjob VALUE 'ZT_JOB',
        jobcount TYPE btcjobcnt VALUE '10000001',
      END OF gc.
    METHODS lines_are_mapped      FOR TESTING.
    METHODS missing_log_is_empty  FOR TESTING.
    METHODS other_error_raises    FOR TESTING.
ENDCLASS.


CLASS ltc_job_log IMPLEMENTATION.

  " Rule: message class, number, type and text of every line
  METHOD lines_are_mapped.
    TEST-INJECTION joblog_read.
      lt_log = VALUE #( ( enterdate = '20261111' entertime = '093000' msgid = 'ZT' msgno = '001' msgtype = 'A'
                          text = 'Job cancelled' ) ).
      lv_rc = 0.
    END-TEST-INJECTION.
    TRY.
        DATA(lt_lines) = NEW zcl_ca_ops_job_log( )->zif_ca_ops_job_log~read( iv_jobname  = gc-jobname
                                                                             iv_jobcount = gc-jobcount ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 1 msg = 'One line' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-msgtype exp = 'A' msg = 'Type kept' ).
        cl_abap_unit_assert=>assert_equals( act = lt_lines[ 1 ]-msgno exp = '001' msg = 'Number kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a log that does not exist is an empty result, never an error
  METHOD missing_log_is_empty.
    TEST-INJECTION joblog_read.
      lv_rc = 3.
    END-TEST-INJECTION.
    TRY.
        cl_abap_unit_assert=>assert_initial(
          act = NEW zcl_ca_ops_job_log( )->zif_ca_ops_job_log~read( iv_jobname = gc-jobname iv_jobcount = gc-jobcount )
          msg = 'Empty' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: any other return code raises 123
  METHOD other_error_raises.
    TEST-INJECTION joblog_read.
      lv_rc = 1.
    END-TEST-INJECTION.
    TRY.
        NEW zcl_ca_ops_job_log( )->zif_ca_ops_job_log~read( iv_jobname = gc-jobname iv_jobcount = gc-jobcount ).
        cl_abap_unit_assert=>fail( msg = 'Expected 123' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '123'
                                            msg = 'Not readable' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
