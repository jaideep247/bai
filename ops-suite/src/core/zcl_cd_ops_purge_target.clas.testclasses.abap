*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_purge_target.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the suite's purge targets: FMON events, PRISM events and HCK
*& verdicts purge by their timestamps; old registry files without an open
*& exception are purged; payment outcome versions keep their rules (current
*& version of a payment that is not final never deleted).
*& Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (retention purge, gap G1).
*& 2026-11-06 | Modern-syntax sweep: alert tables ZCA_OPS_ALCHN / ALLOG / ALRULE.
*& 2026-11-07 | old_hck_result_is_deleted (purge target HCK_RESULT).
*& 2026-11-07 | old_outcome_version_deleted (purge target PAY_OUTCOME: closed versions and runs before
*&            | the cutoff; the current version of a recent payment stays).
*& 2026-11-08 | Retention 90 days of PAY_OUTCOME: an open cheque 120 days old keeps its current version,
*&            | a cleared payment 91 days old and a version closed 91 days ago are purged.
*& 2026-11-10 | run_purge_takes_history (exception history purged with its findings), old_file_purged_
*&            | open_kept (registry by business date, file of an open FMON exception kept).
*& 2026-11-10 | Split from the tests of ZCL_CD_OPS_PURGE_DAO: the suite's targets (ZCL_CD_OPS_PURGE_TARGET,
*&            | plug-in of the framework purge); RUN / ALERT_LOG tests moved with the framework DAO.
*&---------------------------------------------------------------------*
CLASS ltc_purge_target DEFINITION FINAL FOR TESTING
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
      END OF gc.
    "! Retention 90 days of the payment outcome (user decision 2026-11-08): today 2026-11-08,
    "! cutoff 2026-08-10
    CONSTANTS:
      BEGIN OF gc_ret,
        today      TYPE d VALUE '20261108',
        cutoff     TYPE timestampl VALUE '20260810000000.0000000',
        days_120   TYPE d VALUE '20260711',
        days_91    TYPE d VALUE '20260809',
        closed_91  TYPE timestamp VALUE '20260809120000',
        opened     TYPE timestamp VALUE '20260711180000',
        cheque_doc TYPE c LENGTH 12 VALUE '000000910001',
        wire_doc   TYPE c LENGTH 12 VALUE '000000910002',
        ach_doc    TYPE c LENGTH 12 VALUE '000000910003',
        package    TYPE i VALUE 100,
      END OF gc_ret.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_ca_ops_purge_target.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.


    METHODS old_file_purged_open_kept  FOR TESTING.
    METHODS old_fmon_event_is_deleted  FOR TESTING.
    METHODS old_prism_event_is_deleted FOR TESTING.
    METHODS old_hck_result_is_deleted  FOR TESTING.
    METHODS old_outcome_version_deleted FOR TESTING.
    METHODS open_cheque_keeps_current  FOR TESTING.
    METHODS cleared_old_payment_purged FOR TESTING.
    METHODS closed_old_version_purged  FOR TESTING.

    "! One payment outcome version (keys of the test payments, FIN and source fixed)
    METHODS given_version
      IMPORTING
        iv_augbl      TYPE clike
        iv_laufd      TYPE d
        iv_valid_from TYPE timestamp
        iv_valid_to   TYPE timestamp
        iv_outcome    TYPE zif_cd_ops_payout_types=>ty_outcome.

    "! Purge one package of PAY_OUTCOME with the 90-day cutoff; the versions left
    METHODS purge_90_days
      RETURNING
        VALUE(rt_left) TYPE zif_cd_ops_payout_types=>tt_version.
ENDCLASS.


CLASS ltc_purge_target IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCA_OPS_FINDING' ) ( 'ZCD_FMON_EVENT' ) ( 'ZCD_HCK_METRIC' )
                                   ( 'ZCD_FMON_PRISM' ) ( 'ZCD_HCK_RESULT' ) ( 'ZCD_PAY_OUTCOME' )
                                   ( 'ZCD_FMON_FILE' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_ops_purge_target( ).
  ENDMETHOD.


  " B16: old registry files are purged by business date; the file of an open FMON exception stays
  METHOD old_file_purged_open_kept.
    DATA lt_files TYPE STANDARD TABLE OF zcd_fmon_file WITH EMPTY KEY.
    DATA ls_file TYPE zcd_fmon_file.
    DATA lt_findings TYPE STANDARD TABLE OF zca_ops_finding WITH EMPTY KEY.
    DATA ls_finding TYPE zca_ops_finding.
    TRY.
        ls_file-file_id       = gc-run_old.
        ls_file-business_date = gc-old_run.
        INSERT ls_file INTO TABLE lt_files.
        ls_file-file_id       = gc-run_new.
        INSERT ls_file INTO TABLE lt_files.
        go_env->insert_test_data( lt_files ).
        ls_finding-run_id      = gc-run_new.
        ls_finding-finding_no  = 1.
        ls_finding-area     = zif_cd_ops_types=>gc_pe_area-file_monitor.
        ls_finding-reference   = |{ gc-run_new }|.
        ls_finding-disposition = zif_ca_ops_types=>gc_disposition-open.
        INSERT ls_finding INTO TABLE lt_findings.
        go_env->insert_test_data( lt_findings ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->delete_package( iv_target = zcl_cd_ops_purge_target=>gc_target-fmon_file
                                        iv_cutoff = gc-cutoff
                                        iv_today  = gc-today
                                        iv_max    = 100 )
          exp = 1
          msg = 'Only the file without an open exception is purged' ).
        SELECT file_id FROM zcd_fmon_file ORDER BY file_id INTO TABLE @DATA(lt_left).
        cl_abap_unit_assert=>assert_equals( act = lt_left exp = VALUE #( ( file_id = gc-run_new ) )
                                            msg = 'The file of the open exception stays' ).
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
          act = mo_cut->count_purgeable( iv_target = zcl_cd_ops_purge_target=>gc_target-fmon_event
                                         iv_cutoff = gc-cutoff
                                         iv_today  = gc-today )
          exp = 1
          msg = 'One event is older than the cutoff' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->delete_package( iv_target = zcl_cd_ops_purge_target=>gc_target-fmon_event
                                        iv_cutoff = gc-cutoff
                                        iv_today  = gc-today
                                        iv_max    = 100 )
          exp = 1
          msg = 'Only the old event must be deleted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  " Rule: PRISM status events are purged by their receipt time, recent ones are kept
  METHOD old_hck_result_is_deleted.
    DATA lt_results TYPE STANDARD TABLE OF zcd_hck_result WITH EMPTY KEY.
    DATA ls_result TYPE zcd_hck_result.
    TRY.
        ls_result-run_id      = gc-run_old.
        ls_result-check_id    = 'A_INFLIGHT'.
        ls_result-executed_at = gc-old.
        INSERT ls_result INTO TABLE lt_results.
        ls_result-run_id      = gc-run_new.
        ls_result-executed_at = gc-recent.
        INSERT ls_result INTO TABLE lt_results.
        go_env->insert_test_data( lt_results ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->delete_package( iv_target = zcl_cd_ops_purge_target=>gc_target-hck_result
                                        iv_cutoff = gc-cutoff
                                        iv_today  = gc-today
                                        iv_max    = 100 )
          exp = 1
          msg = 'Only the old verdict must be deleted' ).
        SELECT COUNT(*) FROM zcd_hck_result INTO @DATA(lv_left).
        cl_abap_unit_assert=>assert_equals( act = lv_left exp = 1 msg = 'The recent verdict stays' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD old_prism_event_is_deleted.
    DATA lt_prism TYPE STANDARD TABLE OF zcd_fmon_prism WITH EMPTY KEY.
    TRY.
        lt_prism = VALUE #( ( event_id = 'PRISM-OLD' received_at = gc-old )
                            ( event_id = 'PRISM-NEW' received_at = gc-recent ) ).
        go_env->insert_test_data( lt_prism ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->count_purgeable( iv_target = zcl_cd_ops_purge_target=>gc_target-fmon_prism
                                         iv_cutoff = gc-cutoff
                                         iv_today  = gc-today )
          exp = 1
          msg = 'One PRISM event is older than the cutoff' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->delete_package( iv_target = zcl_cd_ops_purge_target=>gc_target-fmon_prism
                                        iv_cutoff = gc-cutoff
                                        iv_today  = gc-today
                                        iv_max    = 100 )
          exp = 1
          msg = 'Only the old PRISM event must be deleted' ).
        SELECT COUNT(*) FROM zcd_fmon_prism INTO @DATA(lv_left).
        cl_abap_unit_assert=>assert_equals( act = lv_left exp = 1 msg = 'The recent PRISM event stays' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: payment outcome versions closed before the cutoff and versions of payment runs before the
  " cutoff date are purged; the current version of a recent payment and its recent history stay
  METHOD old_outcome_version_deleted.
    DATA lt_versions TYPE STANDARD TABLE OF zcd_pay_outcome WITH EMPTY KEY.
    DATA ls_version TYPE zcd_pay_outcome.
    TRY.
        ls_version-fin_id   = 'FIN0000009001'.
        ls_version-source   = 'PCLM'.
        ls_version-bukrs    = 'US01'.
        ls_version-augbl    = '000000900001'.
        " Old payment run: every version goes (also the current one)
        ls_version-laufd      = gc-old_run.
        ls_version-valid_from = '20250101070000'.
        ls_version-valid_to   = zif_cd_ops_payout_types=>gc_valid_to_open.
        ls_version-outcome    = zif_cd_ops_payout_types=>gc_outcome-cleared.
        INSERT ls_version INTO TABLE lt_versions.
        " Recent payment run: a version closed before the cutoff goes, the current one stays
        ls_version-augbl      = '000000900002'.
        ls_version-laufd      = gc-new_run.
        ls_version-valid_from = '20250101070000'.
        ls_version-valid_to   = '20250201070000'.
        ls_version-outcome    = zif_cd_ops_payout_types=>gc_outcome-in_flight.
        INSERT ls_version INTO TABLE lt_versions.
        ls_version-valid_from = '20250201070000'.
        ls_version-valid_to   = zif_cd_ops_payout_types=>gc_valid_to_open.
        ls_version-outcome    = zif_cd_ops_payout_types=>gc_outcome-cleared.
        INSERT ls_version INTO TABLE lt_versions.
        go_env->insert_test_data( lt_versions ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->count_purgeable( iv_target = zcl_cd_ops_purge_target=>gc_target-pay_outcome
                                         iv_cutoff = gc-cutoff
                                         iv_today  = gc-today )
          exp = 2
          msg = 'Old run and closed old version are purgeable' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->delete_package( iv_target = zcl_cd_ops_purge_target=>gc_target-pay_outcome
                                        iv_cutoff = gc-cutoff
                                        iv_today  = gc-today
                                        iv_max    = 100 )
          exp = 2
          msg = 'Two versions deleted' ).
        SELECT outcome, valid_to FROM zcd_pay_outcome ORDER BY PRIMARY KEY INTO TABLE @DATA(lt_left).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_left ) exp = 1 msg = 'One version stays' ).
        cl_abap_unit_assert=>assert_equals( act = lt_left[ 1 ]-valid_to exp = zif_cd_ops_payout_types=>gc_valid_to_open
                                            msg = 'The current version of the recent payment' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD given_version.
    DATA lt_versions TYPE STANDARD TABLE OF zcd_pay_outcome WITH EMPTY KEY.
    DATA ls_version TYPE zcd_pay_outcome.
    ls_version-fin_id     = 'FIN0000009101'.
    ls_version-source     = 'PCLM'.
    ls_version-bukrs      = 'US01'.
    ls_version-augbl      = iv_augbl.
    ls_version-laufd      = iv_laufd.
    ls_version-laufi      = 'RUN001'.
    ls_version-valid_from = iv_valid_from.
    ls_version-valid_to   = iv_valid_to.
    ls_version-outcome    = iv_outcome.
    INSERT ls_version INTO TABLE lt_versions.
    go_env->insert_test_data( lt_versions ).
  ENDMETHOD.


  METHOD purge_90_days.
    mo_cut->delete_package( iv_target = zcl_cd_ops_purge_target=>gc_target-pay_outcome
                            iv_cutoff = gc_ret-cutoff
                            iv_today  = gc_ret-today
                            iv_max    = gc_ret-package ).
    SELECT augbl, laufd, valid_from, valid_to, outcome
      FROM zcd_pay_outcome
      ORDER BY augbl, valid_from
      INTO CORRESPONDING FIELDS OF TABLE @rt_left.
  ENDMETHOD.


  " Rule (2026-11-08): the current version of a payment that is not final is never purged - an open
  " cheque issued 120 days ago keeps its current version (A_INFLIGHT still counts it); its history
  " closed before the cutoff goes
  METHOD open_cheque_keeps_current.
    TRY.
        given_version( iv_augbl      = gc_ret-cheque_doc
                       iv_laufd      = gc_ret-days_120
                       iv_valid_from = gc_ret-opened
                       iv_valid_to   = zif_cd_ops_payout_types=>gc_valid_to_open
                       iv_outcome    = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        DATA(lt_left) = purge_90_days( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_left ) exp = 1 msg = 'The current version stays' ).
        cl_abap_unit_assert=>assert_equals( act = lt_left[ 1 ]-outcome exp = zif_cd_ops_payout_types=>gc_outcome-in_flight
                                            msg = 'Open cheque still in flight' ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->count_purgeable( iv_target = zcl_cd_ops_purge_target=>gc_target-pay_outcome
                                         iv_cutoff = gc_ret-cutoff
                                         iv_today  = gc_ret-today )
          exp = 0
          msg = 'Nothing purgeable' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (2026-11-08): the current version of a final outcome is purged once its payment run is
  " before the cutoff - a wire cleared, paid 91 days ago, goes; the same outcome 120 days old in
  " flight (other payment) is not touched
  METHOD cleared_old_payment_purged.
    TRY.
        given_version( iv_augbl      = gc_ret-wire_doc
                       iv_laufd      = gc_ret-days_91
                       iv_valid_from = gc_ret-closed_91
                       iv_valid_to   = zif_cd_ops_payout_types=>gc_valid_to_open
                       iv_outcome    = zif_cd_ops_payout_types=>gc_outcome-cleared ).
        given_version( iv_augbl      = gc_ret-cheque_doc
                       iv_laufd      = gc_ret-days_120
                       iv_valid_from = gc_ret-opened
                       iv_valid_to   = zif_cd_ops_payout_types=>gc_valid_to_open
                       iv_outcome    = zif_cd_ops_payout_types=>gc_outcome-pending ).
        DATA(lt_left) = purge_90_days( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_left ) exp = 1 msg = 'Only the pending payment stays' ).
        cl_abap_unit_assert=>assert_equals( act = lt_left[ 1 ]-augbl exp = gc_ret-cheque_doc msg = 'Cleared payment purged' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a version closed before the cutoff (91 days ago) is purged; the current version of the
  " payment (not final) stays
  METHOD closed_old_version_purged.
    TRY.
        given_version( iv_augbl      = gc_ret-ach_doc
                       iv_laufd      = gc_ret-days_120
                       iv_valid_from = gc_ret-opened
                       iv_valid_to   = gc_ret-closed_91
                       iv_outcome    = zif_cd_ops_payout_types=>gc_outcome-in_flight ).
        given_version( iv_augbl      = gc_ret-ach_doc
                       iv_laufd      = gc_ret-days_120
                       iv_valid_from = gc_ret-closed_91
                       iv_valid_to   = zif_cd_ops_payout_types=>gc_valid_to_open
                       iv_outcome    = zif_cd_ops_payout_types=>gc_outcome-inconsistent ).
        DATA(lt_left) = purge_90_days( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_left ) exp = 1 msg = 'Closed version purged' ).
        cl_abap_unit_assert=>assert_equals( act = lt_left[ 1 ]-valid_to exp = zif_cd_ops_payout_types=>gc_valid_to_open
                                            msg = 'Current version stays' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
