*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_job_purge.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the purge target JOB_EVIDENCE: jobs kept before the
*& cutoff are counted and deleted with their steps, job log lines,
*& application log links and business objects; a newer job and the
*& watermark stay. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor).
*&---------------------------------------------------------------------*
CLASS ltc_job_purge DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        target TYPE zif_ca_ops_purge_target=>ty_target VALUE 'JOB_EVIDENCE',
        old    TYPE timestampl VALUE '20260101000000.0000000',
        cutoff TYPE timestampl VALUE '20260601000000.0000000',
        new    TYPE timestampl VALUE '20261111000000.0000000',
        count  TYPE btcjobcnt VALUE '10000001',
      END OF gc.
    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS old_jobs_with_children FOR TESTING.
ENDCLASS.


CLASS ltc_job_purge IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCA_OPS_JOB' ) ( 'ZCA_OPS_JOBSTEP' ) ( 'ZCA_OPS_JOBMSG' ) ( 'ZCA_OPS_JOBALOG' )
                                   ( 'ZCA_OPS_JOBBO' ) ( 'ZCA_OPS_JOBWM' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_jobs TYPE STANDARD TABLE OF zca_ops_job WITH EMPTY KEY.
    DATA lt_steps TYPE STANDARD TABLE OF zca_ops_jobstep WITH EMPTY KEY.
    DATA lt_lines TYPE STANDARD TABLE OF zca_ops_jobmsg WITH EMPTY KEY.
    DATA lt_applogs TYPE STANDARD TABLE OF zca_ops_jobalog WITH EMPTY KEY.
    DATA lt_objects TYPE STANDARD TABLE OF zca_ops_jobbo WITH EMPTY KEY.
    DATA lt_marks TYPE STANDARD TABLE OF zca_ops_jobwm WITH EMPTY KEY.
    go_env->clear_doubles( ).
    lt_jobs = VALUE #( jobcount = gc-count ( jobname = 'ZT_OLD' detected_at = gc-old )
                                           ( jobname = 'ZT_NEW' detected_at = gc-new ) ).
    lt_steps = VALUE #( jobcount = gc-count stepcount = 1 ( jobname = 'ZT_OLD' ) ( jobname = 'ZT_NEW' ) ).
    lt_lines = VALUE #( jobcount = gc-count line_no = 1 ( jobname = 'ZT_OLD' ) ).
    lt_applogs = VALUE #( jobcount = gc-count lognumber = 'ZT00000001' ( jobname = 'ZT_OLD' ) ).
    lt_objects = VALUE #( jobcount = gc-count object_no = 1 ( jobname = 'ZT_OLD' ) ).
    lt_marks = VALUE #( ( area = 'ZT_OPS_A' check_id = 'ZT_JOB_FAIL' wm_date = '20260101' ) ).
    go_env->insert_test_data( lt_jobs ).
    go_env->insert_test_data( lt_steps ).
    go_env->insert_test_data( lt_lines ).
    go_env->insert_test_data( lt_applogs ).
    go_env->insert_test_data( lt_objects ).
    go_env->insert_test_data( lt_marks ).
  ENDMETHOD.


  " Rule: the jobs before the cutoff go with every evidence row; newer jobs and the watermark stay
  METHOD old_jobs_with_children.
    DATA(lo_cut) = CAST zif_ca_ops_purge_target( NEW zcl_ca_ops_job_purge( ) ).
    cl_abap_unit_assert=>assert_equals(
      act = lo_cut->count_purgeable( iv_target = gc-target iv_cutoff = gc-cutoff iv_today = '20261111' )
      exp = 1 msg = 'One old job' ).
    DATA(lv_deleted) = lo_cut->delete_package( EXPORTING iv_target    = gc-target
                                                         iv_cutoff    = gc-cutoff
                                                         iv_today     = '20261111'
                                                         iv_max       = 100
                                               IMPORTING ev_dependent = DATA(lv_dependent) ).
    cl_abap_unit_assert=>assert_equals( act = lv_deleted exp = 1 msg = 'One job deleted' ).
    cl_abap_unit_assert=>assert_equals( act = lv_dependent exp = 4 msg = 'Step, line, log link, object' ).
    SELECT COUNT(*) FROM zca_ops_jobstep INTO @DATA(lv_steps).
    cl_abap_unit_assert=>assert_equals( act = lv_steps exp = 1 msg = 'The newer job keeps its step' ).
    SELECT COUNT(*) FROM zca_ops_jobwm INTO @DATA(lv_marks).
    cl_abap_unit_assert=>assert_equals( act = lv_marks exp = 1 msg = 'The watermark is never purged' ).
  ENDMETHOD.

ENDCLASS.
