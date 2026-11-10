*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_purge_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the purge SQL: old runs without blocking exceptions are
*& deleted with their findings; open exceptions and valid waivers keep the run;
*& recent rows are kept; the alert log purges by its timestamp; the registry
*& returns the active consumer targets.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCA_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-07 | test of the check verdict target.
*& 2026-11-07 | old_outcome_version_deleted (purge target PAY_OUTCOME: closed versions and runs before
*&            | the cutoff; the current version of a recent payment stays).
*& 2026-11-08 | Retention 90 days of PAY_OUTCOME: an open cheque 120 days old keeps its current version,
*&            | a cleared payment 91 days old and a version closed 91 days ago are purged.
*& 2026-11-10 | run_purge_takes_history (exception history purged with its findings), old_file_purged_
*&            | open_kept (registry by business date, file of an open exception kept).
*& 2026-11-10 | Moved from ZCL_CD_OPS_PURGE_DAO to the reusable framework ZCA_OPS: tests of RUN and
*&            | ALERT_LOG (the suite's targets are tested with a consumer's class); registry test.
*& 2026-11-10 | old_review_is_deleted (target REVIEW, daily control review).
*&---------------------------------------------------------------------*
CLASS ltc_purge_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        today     TYPE d VALUE '20261106',
        cutoff    TYPE timestampl VALUE '20251002000000.0000000',
        old       TYPE timestampl VALUE '20250101060000.0000000',
        recent    TYPE timestampl VALUE '20261101060000.0000000',
        run_old   TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000A1',
        run_new   TYPE zif_ca_ops_types=>ty_run_id VALUE '000000000000000000000000000000A2',
        valid_end TYPE d VALUE '20261231',
        past_end  TYPE d VALUE '20260101',
        old_run   TYPE d VALUE '20250101',
        new_run   TYPE d VALUE '20261101',
        area      TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS',
        target    TYPE zif_ca_ops_purge_target=>ty_target VALUE 'ZT_TARGET',
        class     TYPE seoclsname VALUE 'ZCL_ZT_TARGET',
        param     TYPE zif_ca_ops_types=>ty_param_name VALUE 'RETENTION_DAYS_ZT_TARGET',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_purge_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS given_run
      IMPORTING
        iv_run_id      TYPE zif_ca_ops_types=>ty_run_id
        iv_started     TYPE timestampl
        iv_disposition TYPE zif_ca_ops_types=>ty_disposition
        iv_waiver_end  TYPE d OPTIONAL.
    METHODS delete_runs
      EXPORTING
        ev_findings    TYPE i
      RETURNING
        VALUE(rv_runs) TYPE i.
    METHODS run_count
      RETURNING
        VALUE(rv_count) TYPE i.

    METHODS old_closed_run_is_deleted  FOR TESTING.
    METHODS run_purge_takes_history    FOR TESTING.
    METHODS open_exception_keeps_run   FOR TESTING.
    METHODS valid_waiver_keeps_run     FOR TESTING.
    METHODS expired_waiver_is_purged   FOR TESTING.
    METHODS recent_run_is_kept         FOR TESTING.
    METHODS old_alert_log_is_deleted   FOR TESTING.
    METHODS active_targets_registered  FOR TESTING.
    METHODS old_review_is_deleted      FOR TESTING.


ENDCLASS.


CLASS ltc_purge_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCA_OPS_RUN' ) ( 'ZCA_OPS_FINDING' ) ( 'ZCA_OPS_ALLOG' )
                                   ( 'ZCA_OPS_EXC_HIST' ) ( 'ZCA_OPS_PURGE' )
                                   ( 'ZCA_OPS_REVIEW' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_ca_ops_purge_dao( ).
  ENDMETHOD.


  METHOD given_run.
    DATA lt_runs TYPE STANDARD TABLE OF zca_ops_run WITH EMPTY KEY.
    DATA ls_run TYPE zca_ops_run.
    DATA lt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.
    DATA ls_finding TYPE zca_ops_finding.
    ls_run-run_id     = iv_run_id.
    ls_run-area     = gc-area.
    ls_run-started_at = iv_started.
    ls_run-status     = zif_ca_ops_types=>gc_run_status-success.
    INSERT ls_run INTO TABLE lt_runs.
    go_env->insert_test_data( lt_runs ).
    ls_finding-run_id       = iv_run_id.
    ls_finding-finding_no   = 1.
    ls_finding-area       = gc-area.
    ls_finding-check_code   = 'UNMAPPED_BTC'.
    ls_finding-severity     = zif_ca_ops_types=>gc_severity-error.
    ls_finding-disposition  = iv_disposition.
    ls_finding-waiver_until = iv_waiver_end.
    INSERT ls_finding INTO TABLE lt_findings.
    go_env->insert_test_data( lt_findings ).
  ENDMETHOD.


  METHOD delete_runs.
    rv_runs = mo_cut->delete_package( EXPORTING iv_target   = zif_ca_ops_purge_dao=>gc_target-run
                                                iv_cutoff   = gc-cutoff
                                                iv_today    = gc-today
                                                iv_max      = 100
                                      IMPORTING ev_dependent = ev_findings ).
  ENDMETHOD.


  METHOD run_count.
    SELECT COUNT(*) FROM zca_ops_run INTO @rv_count.
  ENDMETHOD.


  " Rule: an old run whose exceptions are all closed is deleted with its findings
  METHOD old_closed_run_is_deleted.
    TRY.
        given_run( iv_run_id = gc-run_old iv_started = gc-old iv_disposition = zif_ca_ops_types=>gc_disposition-resolved ).
        DATA(lv_runs) = delete_runs( IMPORTING ev_findings = DATA(lv_findings) ).
        cl_abap_unit_assert=>assert_equals( act = lv_runs exp = 1 msg = 'The old closed run must be deleted' ).
        cl_abap_unit_assert=>assert_equals( act = lv_findings exp = 1 msg = 'Its findings must be deleted with it' ).
        cl_abap_unit_assert=>assert_equals( act = run_count( ) exp = 0 msg = 'No run may remain' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " B16: the action history of the purged findings goes with them - never orphaned
  METHOD run_purge_takes_history.
    DATA lt_hist TYPE STANDARD TABLE OF zca_ops_exc_hist WITH EMPTY KEY.
    DATA ls_hist TYPE zca_ops_exc_hist.
    TRY.
        given_run( iv_run_id = gc-run_old iv_started = gc-old iv_disposition = zif_ca_ops_types=>gc_disposition-resolved ).
        ls_hist-hist_uuid  = gc-run_new.
        ls_hist-run_id     = gc-run_old.
        ls_hist-finding_no = 1.
        INSERT ls_hist INTO TABLE lt_hist.
        go_env->insert_test_data( lt_hist ).
        mo_cut->delete_package( EXPORTING iv_target   = zif_ca_ops_purge_dao=>gc_target-run
                                          iv_cutoff   = gc-cutoff
                                          iv_today    = gc-today
                                          iv_max      = 100
                                IMPORTING ev_history  = DATA(lv_history) ).
        cl_abap_unit_assert=>assert_equals( act = lv_history exp = 1 msg = 'The history row goes with its finding' ).
        SELECT COUNT(*) FROM zca_ops_exc_hist INTO @DATA(lv_left).
        cl_abap_unit_assert=>assert_equals( act = lv_left exp = 0 msg = 'No orphaned history' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a run holding an open exception is evidence still in use - never purged
  METHOD open_exception_keeps_run.
    TRY.
        given_run( iv_run_id = gc-run_old iv_started = gc-old iv_disposition = zif_ca_ops_types=>gc_disposition-open ).
        cl_abap_unit_assert=>assert_equals( act = delete_runs( ) exp = 0 msg = 'An open exception must keep its run' ).
        cl_abap_unit_assert=>assert_equals( act = run_count( ) exp = 1 msg = 'The run must remain' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a waiver that is still valid keeps its run
  METHOD valid_waiver_keeps_run.
    TRY.
        given_run( iv_run_id      = gc-run_old
                   iv_started     = gc-old
                   iv_disposition = zif_ca_ops_types=>gc_disposition-waived
                   iv_waiver_end  = gc-valid_end ).
        cl_abap_unit_assert=>assert_equals( act = delete_runs( ) exp = 0 msg = 'A valid waiver must keep its run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an expired waiver no longer protects the run
  METHOD expired_waiver_is_purged.
    TRY.
        given_run( iv_run_id      = gc-run_old
                   iv_started     = gc-old
                   iv_disposition = zif_ca_ops_types=>gc_disposition-waived
                   iv_waiver_end  = gc-past_end ).
        cl_abap_unit_assert=>assert_equals( act = delete_runs( ) exp = 1 msg = 'An expired waiver must not keep the run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: runs inside the retention period are kept
  METHOD recent_run_is_kept.
    TRY.
        given_run( iv_run_id = gc-run_new iv_started = gc-recent iv_disposition = zif_ca_ops_types=>gc_disposition-resolved ).
        cl_abap_unit_assert=>assert_equals( act = delete_runs( ) exp = 0 msg = 'A recent run must be kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: alert log rows are purged by their send time
  METHOD old_alert_log_is_deleted.
    DATA lt_log TYPE STANDARD TABLE OF zca_ops_allog WITH EMPTY KEY.
    DATA ls_log TYPE zca_ops_allog.
    TRY.
        ls_log-alert_id = gc-run_old.
        ls_log-sent_at  = gc-old.
        INSERT ls_log INTO TABLE lt_log.
        ls_log-alert_id = gc-run_new.
        ls_log-sent_at  = gc-recent.
        INSERT ls_log INTO TABLE lt_log.
        go_env->insert_test_data( lt_log ).
        DATA(lv_deleted) = mo_cut->delete_package( iv_target = zif_ca_ops_purge_dao=>gc_target-alert_log
                                                   iv_cutoff = gc-cutoff
                                                   iv_today  = gc-today
                                                   iv_max    = 100 ).
        SELECT COUNT(*) FROM zca_ops_allog INTO @DATA(lv_left).
        cl_abap_unit_assert=>assert_equals( act = lv_deleted exp = 1 msg = 'Only the old alert must be deleted' ).
        cl_abap_unit_assert=>assert_equals( act = lv_left exp = 1 msg = 'The recent alert must remain' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.



  " Registry: only active consumer targets are purged, with their class and retention parameter
  METHOD active_targets_registered.
    DATA lt_rows TYPE STANDARD TABLE OF zca_ops_purge WITH EMPTY KEY.
    DATA ls_row TYPE zca_ops_purge.
    TRY.
        ls_row-target     = gc-target.
        ls_row-class_name = gc-class.
        ls_row-param_area = zif_ca_ops_types=>gc_param_area.
        ls_row-param_name = gc-param.
        ls_row-active     = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-target = gc-area.
        ls_row-active = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->get_targets( )
          exp = VALUE zif_ca_ops_purge_dao=>tt_registry( ( target     = gc-target
                                                           class_name = gc-class
                                                           param_area = zif_ca_ops_types=>gc_param_area
                                                           param_name = gc-param ) )
          msg = 'Active rows only, with class and parameter' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a sign-off older than the cutoff is deleted, a recent one is kept (count and delete agree)
  METHOD old_review_is_deleted.
    DATA lt_reviews TYPE STANDARD TABLE OF zca_ops_review WITH EMPTY KEY.
    lt_reviews = VALUE #( ( area = gc-area control_id = 'ZT_CTL' business_date = gc-old_run reviewed_at = gc-old )
                          ( area = gc-area control_id = 'ZT_CTL' business_date = gc-new_run reviewed_at = gc-recent ) ).
    go_env->insert_test_data( lt_reviews ).

    DATA(lv_count) = mo_cut->count_purgeable( iv_target = zif_ca_ops_purge_dao=>gc_target-review
                                              iv_cutoff = gc-cutoff
                                              iv_today  = gc-today ).
    DATA(lv_deleted) = mo_cut->delete_package( iv_target = zif_ca_ops_purge_dao=>gc_target-review
                                               iv_cutoff = gc-cutoff
                                               iv_today  = gc-today
                                               iv_max    = 100 ).
    SELECT business_date FROM zca_ops_review INTO TABLE @DATA(lt_left).

    cl_abap_unit_assert=>assert_equals( act = lv_count exp = 1 msg = 'One sign-off before the cutoff' ).
    cl_abap_unit_assert=>assert_equals( act = lv_deleted exp = 1 msg = 'Only the old sign-off deleted' ).
    cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_left[ 1 ]-business_date OPTIONAL ) exp = gc-new_run
                                        msg = 'The recent sign-off is kept' ).
  ENDMETHOD.

ENDCLASS.
