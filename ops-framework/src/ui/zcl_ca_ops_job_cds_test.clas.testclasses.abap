*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_cds_test.clas.testclasses.abap
*& Purpose:
*& CDS tests of the SAP job failures board (ZR_CA_OpsJobFailure) on
*& cl_cds_test_environment doubles of its direct dependencies (ZCA_OPS_JOB,
*& TBTCO, ZI_CA_OpsJobExc): the counters of the "Job failures today" cards
*& count the failures kept today per check code (ancestors and children are
*& context, failures of another day are not today's); the open exception of
*& a failure is joined by area, object key, check code and company code;
*& the live status is blank when TBTCO no longer has the job. Does not prove
*& live SAP runtime behavior. VERIFY-ADT V66: doubles of CDS dependencies
*& and of the cross-client TBTCO (7.58).
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
"! ZR_CA_OPSJOBFAILURE: counters and joins of the board
CLASS ltc_board DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area   TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        count  TYPE btcjobcnt VALUE '10000001',
        old    TYPE d VALUE '20200101',
        run_id TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000F1',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_cds_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS counters_of_today      FOR TESTING.
    METHODS open_exception_joined  FOR TESTING.
    METHODS live_status_until_reorg FOR TESTING.
ENDCLASS.


CLASS ltc_board IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_cds_test_environment=>create( i_for_entity = 'ZR_CA_OPSJOBFAILURE' ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_jobs TYPE STANDARD TABLE OF zca_ops_job WITH EMPTY KEY.
    DATA lt_live TYPE STANDARD TABLE OF tbtco WITH EMPTY KEY.
    DATA lt_exc TYPE STANDARD TABLE OF zi_ca_opsjobexc WITH EMPTY KEY.

    go_env->clear_doubles( ).
    lt_jobs = VALUE #( area = gc-area jobcount = gc-count detected_on = sy-datum
                       ( jobname = 'ZT_ABORTED' job_role = 'F' check_code = 'JOB_ABORTED' severity = 'E'
                         object_key = |ZT_ABORTED/{ gc-count }| )
                       ( jobname = 'ZT_CHILD' job_role = 'F' check_code = 'JOB_CHILD_FAILED' severity = 'E'
                         object_key = |ZT_CHILD/{ gc-count }| parent_jobname = 'ZT_PARENT' parent_jobcount = gc-count )
                       ( jobname = 'ZT_WAITING' job_role = 'F' check_code = 'JOB_NOT_STARTED' severity = 'W'
                         object_key = |ZT_WAITING/{ gc-count }| )
                       ( jobname = 'ZT_LONG' job_role = 'F' check_code = 'JOB_LONG_RUNNING' severity = 'W'
                         object_key = |ZT_LONG/{ gc-count }| )
                       ( jobname = 'ZT_PARENT' job_role = 'A' ) ).
    INSERT VALUE #( area = gc-area jobname = 'ZT_YESTERDAY' jobcount = gc-count job_role = 'F'
                    check_code = 'JOB_ABORTED' severity = 'E' object_key = |ZT_YESTERDAY/{ gc-count }|
                    detected_on = gc-old ) INTO TABLE lt_jobs.
    lt_live = VALUE #( ( jobname = 'ZT_CHILD' jobcount = gc-count status = 'A' ) ).
    lt_exc = VALUE #( ( runid = gc-run_id findingno = 1 area = gc-area objectkey = |ZT_CHILD/{ gc-count }|
                        checkcode = 'JOB_CHILD_FAILED' disposition = 'O' owner = 'ZT_OWNER' ) ).
    go_env->insert_test_data( lt_jobs ).
    go_env->insert_test_data( lt_live ).
    go_env->insert_test_data( lt_exc ).
  ENDMETHOD.


  " Rule: today's failures per check code; ancestors and other days are not counted
  METHOD counters_of_today.
    SELECT SUM( failurestoday ) AS failures, SUM( abortedtoday ) AS aborted, SUM( childfailedtoday ) AS child,
           SUM( notstartedtoday ) AS waiting, SUM( longrunningtoday ) AS long
      FROM zr_ca_opsjobfailure
      INTO @DATA(ls_sum).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-failures exp = 4 msg = 'Four failures today' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-aborted exp = 1 msg = 'Yesterday''s cancellation not counted' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-child exp = 1 msg = 'Child failed while the parent finished' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-waiting exp = 1 msg = 'Not started' ).
    cl_abap_unit_assert=>assert_equals( act = ls_sum-long exp = 1 msg = 'Long-running' ).
  ENDMETHOD.


  " Rule: the open exception of the failure is joined by its identity; a failure without one has none
  METHOD open_exception_joined.
    SELECT jobname, exceptionstatus, exceptionowner, hasopenexception
      FROM zr_ca_opsjobfailure
      WHERE hasopenexception = @abap_true
      INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One open exception' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-jobname exp = 'ZT_CHILD' msg = 'Of the failed child' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-exceptionowner exp = 'ZT_OWNER' msg = 'Its owner' ).
  ENDMETHOD.


  " Rule: the live status comes from TBTCO while it holds the job; blank after the reorganisation
  METHOD live_status_until_reorg.
    SELECT jobname, livestatus FROM zr_ca_opsjobfailure
      WHERE jobname = 'ZT_CHILD' OR jobname = 'ZT_ABORTED'
      ORDER BY jobname
      INTO TABLE @DATA(lt_rows).
    cl_abap_unit_assert=>assert_initial( act = lt_rows[ 1 ]-livestatus msg = 'Reorganised: blank' ).
    cl_abap_unit_assert=>assert_equals( act = lt_rows[ 2 ]-livestatus exp = 'A' msg = 'Live status' ).
  ENDMETHOD.

ENDCLASS.
