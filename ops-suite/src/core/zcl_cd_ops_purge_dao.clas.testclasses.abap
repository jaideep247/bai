*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_purge_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the purge SQL: old runs without blocking exceptions are
*& deleted with their findings; open exceptions and valid waivers keep the run;
*& recent rows are kept; alert log and FMON events purge by their timestamps.
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
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
        run_old   TYPE zif_cd_ops_types=>ty_run_id VALUE '000000000000000000000000000000A1',
        run_new   TYPE zif_cd_ops_types=>ty_run_id VALUE '000000000000000000000000000000A2',
        valid_end TYPE d VALUE '20261231',
        past_end  TYPE d VALUE '20260101',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ops_purge_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS given_run
      IMPORTING
        iv_run_id      TYPE zif_cd_ops_types=>ty_run_id
        iv_started     TYPE timestampl
        iv_disposition TYPE zif_cd_ops_types=>ty_disposition
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
    METHODS open_exception_keeps_run   FOR TESTING.
    METHODS valid_waiver_keeps_run     FOR TESTING.
    METHODS expired_waiver_is_purged   FOR TESTING.
    METHODS recent_run_is_kept         FOR TESTING.
    METHODS old_alert_log_is_deleted   FOR TESTING.
    METHODS old_fmon_event_is_deleted  FOR TESTING.
ENDCLASS.


CLASS ltc_purge_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCD_OPS_RUN' ) ( 'ZCD_OPS_FINDING' ) ( 'ZCD_OPS_ALLOG' )
                                   ( 'ZCD_FMON_EVENT' ) ( 'ZCD_HCK_METRIC' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_ops_purge_dao( ).
  ENDMETHOD.


  METHOD given_run.
    DATA lt_runs TYPE STANDARD TABLE OF zcd_ops_run WITH EMPTY KEY.
    DATA ls_run TYPE zcd_ops_run.
    DATA lt_findings TYPE STANDARD TABLE OF zcd_ops_finding WITH EMPTY KEY.
    DATA ls_finding TYPE zcd_ops_finding.
    ls_run-run_id     = iv_run_id.
    ls_run-pe_area     = zif_cd_ops_types=>gc_pe_area-ebs.
    ls_run-started_at = iv_started.
    ls_run-status     = zif_cd_ops_types=>gc_run_status-success.
    INSERT ls_run INTO TABLE lt_runs.
    go_env->insert_test_data( lt_runs ).
    ls_finding-run_id       = iv_run_id.
    ls_finding-finding_no   = 1.
    ls_finding-pe_area       = zif_cd_ops_types=>gc_pe_area-ebs.
    ls_finding-check_code   = 'UNMAPPED_BTC'.
    ls_finding-severity     = zif_cd_ops_types=>gc_severity-error.
    ls_finding-disposition  = iv_disposition.
    ls_finding-waiver_until = iv_waiver_end.
    INSERT ls_finding INTO TABLE lt_findings.
    go_env->insert_test_data( lt_findings ).
  ENDMETHOD.


  METHOD delete_runs.
    rv_runs = mo_cut->delete_package( EXPORTING iv_target   = zif_cd_ops_purge_dao=>gc_target-run
                                                iv_cutoff   = gc-cutoff
                                                iv_today    = gc-today
                                                iv_max      = 100
                                      IMPORTING ev_findings = ev_findings ).
  ENDMETHOD.


  METHOD run_count.
    SELECT COUNT(*) FROM zcd_ops_run INTO @rv_count.
  ENDMETHOD.


  " Rule: an old run whose exceptions are all closed is deleted with its findings
  METHOD old_closed_run_is_deleted.
    TRY.
        given_run( iv_run_id = gc-run_old iv_started = gc-old iv_disposition = zif_cd_ops_types=>gc_disposition-resolved ).
        DATA(lv_runs) = delete_runs( IMPORTING ev_findings = DATA(lv_findings) ).
        cl_abap_unit_assert=>assert_equals( act = lv_runs exp = 1 msg = 'The old closed run must be deleted' ).
        cl_abap_unit_assert=>assert_equals( act = lv_findings exp = 1 msg = 'Its findings must be deleted with it' ).
        cl_abap_unit_assert=>assert_equals( act = run_count( ) exp = 0 msg = 'No run may remain' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a run holding an open exception is evidence still in use - never purged
  METHOD open_exception_keeps_run.
    TRY.
        given_run( iv_run_id = gc-run_old iv_started = gc-old iv_disposition = zif_cd_ops_types=>gc_disposition-open ).
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
                   iv_disposition = zif_cd_ops_types=>gc_disposition-waived
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
                   iv_disposition = zif_cd_ops_types=>gc_disposition-waived
                   iv_waiver_end  = gc-past_end ).
        cl_abap_unit_assert=>assert_equals( act = delete_runs( ) exp = 1 msg = 'An expired waiver must not keep the run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: runs inside the retention period are kept
  METHOD recent_run_is_kept.
    TRY.
        given_run( iv_run_id = gc-run_new iv_started = gc-recent iv_disposition = zif_cd_ops_types=>gc_disposition-resolved ).
        cl_abap_unit_assert=>assert_equals( act = delete_runs( ) exp = 0 msg = 'A recent run must be kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: alert log rows are purged by their send time
  METHOD old_alert_log_is_deleted.
    DATA lt_log TYPE STANDARD TABLE OF zcd_ops_allog WITH EMPTY KEY.
    DATA ls_log TYPE zcd_ops_allog.
    TRY.
        ls_log-alert_id = gc-run_old.
        ls_log-sent_at  = gc-old.
        INSERT ls_log INTO TABLE lt_log.
        ls_log-alert_id = gc-run_new.
        ls_log-sent_at  = gc-recent.
        INSERT ls_log INTO TABLE lt_log.
        go_env->insert_test_data( lt_log ).
        DATA(lv_deleted) = mo_cut->delete_package( iv_target = zif_cd_ops_purge_dao=>gc_target-alert_log
                                                   iv_cutoff = gc-cutoff
                                                   iv_today  = gc-today
                                                   iv_max    = 100 ).
        SELECT COUNT(*) FROM zcd_ops_allog INTO @DATA(lv_left).
        cl_abap_unit_assert=>assert_equals( act = lv_deleted exp = 1 msg = 'Only the old alert must be deleted' ).
        cl_abap_unit_assert=>assert_equals( act = lv_left exp = 1 msg = 'The recent alert must remain' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: FMON events are purged by their creation time, test mode counts them
  METHOD old_fmon_event_is_deleted.
    DATA lt_events TYPE STANDARD TABLE OF zcd_fmon_event WITH EMPTY KEY.
    DATA ls_event TYPE zcd_fmon_event.
    TRY.
        ls_event-file_id    = gc-run_old.
        ls_event-event_no   = 1.
        ls_event-created_at = gc-old.
        INSERT ls_event INTO TABLE lt_events.
        ls_event-event_no   = 2.
        ls_event-created_at = gc-recent.
        INSERT ls_event INTO TABLE lt_events.
        go_env->insert_test_data( lt_events ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->count_purgeable( iv_target = zif_cd_ops_purge_dao=>gc_target-fmon_event
                                         iv_cutoff = gc-cutoff
                                         iv_today  = gc-today )
          exp = 1
          msg = 'One event is older than the cutoff' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->delete_package( iv_target = zif_cd_ops_purge_dao=>gc_target-fmon_event
                                        iv_cutoff = gc-cutoff
                                        iv_today  = gc-today
                                        iv_max    = 100 )
          exp = 1
          msg = 'Only the old event must be deleted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
