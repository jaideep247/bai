*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_log_cache.clas.testclasses.abap
*& Purpose:
*& Tests of the job log reader with budget: a log is read once (cache),
*& over the budget a read returns nothing and EXHAUSTED says so, a cached
*& log can still be read over the budget. Reader double instead of
*& BP_JOBLOG_READ. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
CLASS ltd_reader DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_ca_ops_job_log.
    DATA mv_reads TYPE i.
ENDCLASS.

CLASS ltd_reader IMPLEMENTATION.
  METHOD zif_ca_ops_job_log~read.
    mv_reads += 1.
    INSERT VALUE #( msgid = 'ZT' msgno = '001' msgtype = 'E' text = |{ iv_jobname }/{ iv_jobcount }| ) INTO TABLE rt_lines.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_cache DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        first  TYPE btcjob VALUE 'ZT_FIRST',
        second TYPE btcjob VALUE 'ZT_SECOND',
        count  TYPE btcjobcnt VALUE '10000001',
      END OF gc.
    DATA mo_reader TYPE REF TO ltd_reader.
    DATA mo_cut TYPE REF TO zcl_ca_ops_job_log_cache.
    METHODS setup.
    METHODS read_once_from_cache   FOR TESTING.
    METHODS over_budget_is_empty   FOR TESTING.
ENDCLASS.


CLASS ltc_cache IMPLEMENTATION.

  METHOD setup.
    mo_reader = NEW #( ).
    mo_cut = NEW #( io_reader = mo_reader iv_budget = 1 ).
  ENDMETHOD.


  " Rule: the same log is read from the reader once per run
  METHOD read_once_from_cache.
    TRY.
        mo_cut->zif_ca_ops_job_log~read( iv_jobname = gc-first iv_jobcount = gc-count ).
        DATA(lt_lines) = mo_cut->zif_ca_ops_job_log~read( iv_jobname = gc-first iv_jobcount = gc-count ).
        cl_abap_unit_assert=>assert_equals( act = mo_reader->mv_reads exp = 1 msg = 'One read' ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_lines ) exp = 1 msg = 'Lines from the cache' ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->can_read( iv_jobname = gc-first iv_jobcount = gc-count )
                                          msg = 'A cached log can be read over the budget' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: over the budget a read returns nothing and the cache says it was exhausted
  METHOD over_budget_is_empty.
    TRY.
        mo_cut->zif_ca_ops_job_log~read( iv_jobname = gc-first iv_jobcount = gc-count ).
        cl_abap_unit_assert=>assert_false( act = mo_cut->can_read( iv_jobname = gc-second iv_jobcount = gc-count )
                                           msg = 'Budget used up' ).
        DATA(lt_lines) = mo_cut->zif_ca_ops_job_log~read( iv_jobname = gc-second iv_jobcount = gc-count ).
        cl_abap_unit_assert=>assert_initial( act = lt_lines msg = 'Nothing read' ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->exhausted( ) msg = 'Exhausted' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->reads( ) exp = 1 msg = 'One read counted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
