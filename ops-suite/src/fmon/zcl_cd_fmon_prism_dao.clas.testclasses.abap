*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_dao.clas.testclasses.abap
*& Purpose:
*& SQL tests of the PRISM event repository on a cl_osql_test_environment
*& double of ZCD_FMON_PRISM: insert, idempotent duplicate, conflicting
*& duplicate, unprocessed read window, processed marker; does not prove live
*& SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API, instant bgPF processing).
*& 2026-11-07 | Regenerated files: read_failures reads FAILED milestones with a listed error code only.
*&---------------------------------------------------------------------*
CLASS ltc_prism_dao DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        event_id   TYPE zif_cd_fmon_prism_types=>ty_event_id VALUE 'PRISM-0001',
        other_id   TYPE zif_cd_fmon_prism_types=>ty_event_id VALUE 'PRISM-0002',
        file_ref   TYPE zif_cd_fmon_types=>ty_file_name VALUE 'ACH_PNC_20261106_01',
        occurred   TYPE timestampl VALUE '20261106143000',
        received   TYPE timestampl VALUE '20261106143100',
        later      TYPE timestampl VALUE '20261106150000',
        window_end TYPE timestampl VALUE '20261107000000',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_fmon_prism_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS new_row
      IMPORTING
        iv_event_id   TYPE zif_cd_fmon_prism_types=>ty_event_id
      RETURNING
        VALUE(rs_row) TYPE zif_cd_fmon_prism_types=>ty_row.

    METHODS insert_new_event FOR TESTING.
    METHODS same_payload_is_duplicate FOR TESTING.
    METHODS other_payload_is_conflict FOR TESTING.
    METHODS unprocessed_read_skips_done FOR TESTING.
    METHODS mark_keeps_first_time FOR TESTING.
    METHODS failures_by_listed_code FOR TESTING.

ENDCLASS.


CLASS ltc_prism_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'ZCD_FMON_PRISM' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_fmon_prism_dao( ).
  ENDMETHOD.


  METHOD new_row.
    rs_row-event_id      = iv_event_id.
    rs_row-file_ref      = gc_test-file_ref.
    rs_row-direction     = zif_cd_fmon_types=>gc_direction-outbound.
    rs_row-milestone     = zif_cd_fmon_prism_types=>gc_milestone-received.
    rs_row-occurred_at   = gc_test-occurred.
    rs_row-counterparty  = 'PNC'.
    rs_row-business_date = '20261106'.
    rs_row-received_at   = gc_test-received.
    rs_row-received_by   = 'PRISM_TECH'.
  ENDMETHOD.


  " Rule: a new event ID is inserted and can be read back unprocessed.
  METHOD insert_new_event.
    TRY.
        DATA(ls_row) = new_row( gc_test-event_id ).
        DATA(lv_result) = mo_cut->insert_event( ls_row ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_prism_types=>gc_store_result-inserted
                                            msg = 'A new event must be inserted' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->read_event( gc_test-event_id ) exp = ls_row
                                            msg = 'The stored row must equal the event' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (idempotency): the same event re-sent (other receipt time) is a duplicate, stored once.
  METHOD same_payload_is_duplicate.
    TRY.
        DATA(ls_row) = new_row( gc_test-event_id ).
        mo_cut->insert_event( ls_row ).
        DATA(ls_resent) = ls_row.
        ls_resent-received_at = gc_test-later.
        DATA(lv_result) = mo_cut->insert_event( ls_resent ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_prism_types=>gc_store_result-duplicate
                                            msg = 'A re-sent event must be a duplicate' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->read_event( gc_test-event_id )-received_at
                                            exp = gc_test-received
                                            msg = 'The first receipt must be kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the same event ID with another content is a conflict and changes nothing.
  METHOD other_payload_is_conflict.
    TRY.
        DATA(ls_row) = new_row( gc_test-event_id ).
        mo_cut->insert_event( ls_row ).
        DATA(ls_other) = ls_row.
        ls_other-milestone = zif_cd_fmon_prism_types=>gc_milestone-failed.
        DATA(lv_result) = mo_cut->insert_event( ls_other ).
        cl_abap_unit_assert=>assert_equals( act = lv_result exp = zif_cd_fmon_prism_types=>gc_store_result-conflict
                                            msg = 'Another payload under the same ID must be a conflict' ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->read_event( gc_test-event_id )-milestone
                                            exp = zif_cd_fmon_prism_types=>gc_milestone-received
                                            msg = 'The stored event must not change' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (safety net): the 5-minute run reads only events no unit has processed.
  METHOD unprocessed_read_skips_done.
    TRY.
        mo_cut->insert_event( new_row( gc_test-event_id ) ).
        mo_cut->insert_event( new_row( gc_test-other_id ) ).
        mo_cut->mark_processed( it_event_ids = VALUE #( ( gc_test-other_id ) ) iv_at = gc_test-later ).
        DATA(lt_rows) = mo_cut->read_unprocessed( iv_from     = gc_test-occurred
                                                  iv_to       = gc_test-window_end
                                                  iv_max_rows = 10 ).
        cl_abap_unit_assert=>assert_equals( act = VALUE zif_cd_fmon_prism_types=>tt_event_id(
                                                    FOR ls_row IN lt_rows ( ls_row-event_id ) )
                                            exp = VALUE zif_cd_fmon_prism_types=>tt_event_id( ( gc_test-event_id ) )
                                            msg = 'Only the unprocessed event must be read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (regenerated files): only FAILED milestones with a listed error code (duplicate name) of the
  " window are read - other codes, other milestones and an empty list read nothing.
  METHOD failures_by_listed_code.
    CONSTANTS lc_dup TYPE zif_cd_fmon_prism_types=>ty_error_code VALUE 'NAME_EXISTS'.
    TRY.
        DATA(ls_dup) = new_row( gc_test-event_id ).
        ls_dup-milestone  = zif_cd_fmon_prism_types=>gc_milestone-failed.
        ls_dup-error_code = lc_dup.
        mo_cut->insert_event( ls_dup ).
        DATA(ls_other) = new_row( gc_test-other_id ).
        ls_other-milestone  = zif_cd_fmon_prism_types=>gc_milestone-failed.
        ls_other-error_code = 'BANK_DOWN'.
        mo_cut->insert_event( ls_other ).
        DATA(lt_rows) = mo_cut->read_failures( it_codes = VALUE #( ( lc_dup ) ) iv_since = '20261101' ).
        cl_abap_unit_assert=>assert_equals( act = VALUE zif_cd_fmon_prism_types=>tt_event_id(
                                                    FOR ls_row IN lt_rows ( ls_row-event_id ) )
                                            exp = VALUE zif_cd_fmon_prism_types=>tt_event_id( ( gc_test-event_id ) )
                                            msg = 'Only the failure with the listed code' ).
        cl_abap_unit_assert=>assert_initial( act = mo_cut->read_failures( it_codes = VALUE #( ) iv_since = '20261101' )
                                             msg = 'An empty code list reads nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (concurrency): a second unit does not overwrite the first processing time.
  METHOD mark_keeps_first_time.
    TRY.
        mo_cut->insert_event( new_row( gc_test-event_id ) ).
        mo_cut->mark_processed( it_event_ids = VALUE #( ( gc_test-event_id ) ) iv_at = gc_test-received ).
        mo_cut->mark_processed( it_event_ids = VALUE #( ( gc_test-event_id ) ) iv_at = gc_test-later ).
        cl_abap_unit_assert=>assert_equals( act = mo_cut->read_event( gc_test-event_id )-processed_at
                                            exp = gc_test-received
                                            msg = 'The first processing time must be kept' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
