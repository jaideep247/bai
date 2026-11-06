*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_dao.clas.testclasses.abap
*& Purpose:
*& SQL tests of the FMON repository on cl_osql_test_environment doubles of
*& ZCD_FMON_FILE / ZCD_FMON_EVENT: event idempotency, numbering, registry
*& lookups; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Audit A04/A05/A49/A50/A51: version check, per-instance events, window bounds, approved tables.
*& 2026-11-06 | Performance fix 8: grouped count of a configured table (COUNT(*) per value combination).
*&---------------------------------------------------------------------*
CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
    CONSTANTS gc_now TYPE timestampl VALUE '20261102080000'.
ENDCLASS.


CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = gc_now.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~today.
    rv_date = '20261102'.
  ENDMETHOD.
  METHOD zif_cd_ops_clock~time.
    rv_time = '080000'.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_ddic DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_fmon_ddic PARTIALLY IMPLEMENTED.
    DATA mv_may_read TYPE abap_bool VALUE abap_true.
ENDCLASS.


CLASS ltd_ddic IMPLEMENTATION.
  METHOD zif_cd_fmon_ddic~may_read.
    rv_allowed = mv_may_read.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_dao DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_iface TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_PNC_OUT'.
    CONSTANTS gc_src TYPE zif_cd_fmon_types=>ty_src_id VALUE 'ACHACK'.
    CONSTANTS gc_date TYPE d VALUE '20261102'.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_fmon_dao.
    DATA mo_ddic TYPE REF TO ltd_ddic.

    "! The row as a read returns it: exists in the DB, version = CHANGED_AT as read
    METHODS as_loaded
      IMPORTING
        is_file        TYPE zif_cd_fmon_types=>ty_file
      RETURNING
        VALUE(rs_file) TYPE zif_cd_fmon_types=>ty_file.

    METHODS legacy_query
      RETURNING
        VALUE(rs_query) TYPE zif_cd_fmon_types=>ty_query.

    METHODS msgno_of_read
      RETURNING
        VALUE(rv_msgno) TYPE symsgno.

    METHODS approve_file_table.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.
    METHODS teardown.

    METHODS new_file
      IMPORTING
        iv_id          TYPE i
        iv_date        TYPE d
        iv_outcome     TYPE zif_cd_fmon_types=>ty_stage OPTIONAL
      RETURNING
        VALUE(rs_file) TYPE zif_cd_fmon_types=>ty_file.

    METHODS new_event
      IMPORTING
        iv_stage        TYPE zif_cd_fmon_types=>ty_stage
      RETURNING
        VALUE(rs_event) TYPE zif_cd_fmon_types=>ty_event.

    METHODS same_event_is_stored_once FOR TESTING.
    METHODS repeat_insert_reports_false FOR TESTING.
    METHODS events_numbered_per_file FOR TESTING.
    METHODS saved_file_found_by_ref FOR TESTING.
    METHODS open_old_file_is_evaluated FOR TESTING.
    METHODS history_found_by_checksum FOR TESTING.
    METHODS later_open_file_not_evaluated FOR TESTING.
    METHODS newer_registry_not_overwritten FOR TESTING.
    METHODS unchanged_registry_is_saved FOR TESTING.
    METHODS event_belongs_to_its_instance FOR TESTING.
    METHODS cross_interface_ref_own_event FOR TESTING.
    METHODS older_instances_not_prefetched FOR TESTING.
    METHODS unapproved_table_is_refused FOR TESTING.
    METHODS read_without_auth_is_refused FOR TESTING.
    METHODS approved_table_is_read FOR TESTING.
    METHODS grouped_count_per_status FOR TESTING.
    METHODS grouped_count_needs_approval FOR TESTING.

ENDCLASS.


CLASS ltc_dao IMPLEMENTATION.

  METHOD class_setup.
    DATA lt_deps TYPE if_osql_test_environment=>ty_t_sobjnames.
    INSERT CONV #( 'ZCD_FMON_FILE' ) INTO TABLE lt_deps.
    INSERT CONV #( 'ZCD_FMON_EVENT' ) INTO TABLE lt_deps.
    INSERT CONV #( 'ZCD_FMON_TABWL' ) INTO TABLE lt_deps.
    go_env = cl_osql_test_environment=>create( i_dependency_list = lt_deps ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
    mo_ddic = NEW #( ).
    zcl_cd_fmon_injector=>inject_ddic( mo_ddic ).
    mo_cut = NEW zcl_cd_fmon_dao( ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    zcl_cd_fmon_injector=>reset( ).
  ENDMETHOD.


  METHOD new_file.
    rs_file-file_id       = CONV zif_cd_fmon_types=>ty_file_id( iv_id ).
    rs_file-iface_id      = gc_iface.
    rs_file-file_ref      = |ACH_PNC_{ iv_id }|.
    rs_file-direction     = zif_cd_fmon_types=>gc_direction-outbound.
    rs_file-file_type     = zif_cd_fmon_types=>gc_file_type-payment.
    rs_file-file_name     = |ACH_PNC_{ iv_id }|.
    rs_file-business_date = iv_date.
    rs_file-stage         = zif_cd_fmon_types=>gc_stage-generated.
    rs_file-outcome       = iv_outcome.
    rs_file-checksum      = |SUM{ iv_id }|.
  ENDMETHOD.


  METHOD new_event.
    rs_event-file_id  = CONV zif_cd_fmon_types=>ty_file_id( 1 ).
    rs_event-stage    = iv_stage.
    rs_event-event_at = ltd_clock=>gc_now.
    rs_event-src_id   = gc_src.
    rs_event-src_key  = 'ACH_PNC_1'.
  ENDMETHOD.


  " Rule: an event with the same SRC_ID + SRC_KEY + STAGE is stored only once.
  METHOD same_event_is_stored_once.
    TRY.
        mo_cut->insert_event( new_event( zif_cd_fmon_types=>gc_stage-ack ) ).
        mo_cut->insert_event( new_event( zif_cd_fmon_types=>gc_stage-ack ) ).
        DATA(lt_events) = mo_cut->get_events( VALUE #( ( CONV #( 1 ) ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_events ) exp = 1
                                            msg = 'Re-run must not duplicate the event' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the repeated insert reports abap_false (not inserted).
  METHOD repeat_insert_reports_false.
    TRY.
        mo_cut->insert_event( new_event( zif_cd_fmon_types=>gc_stage-ack ) ).
        DATA(lv_inserted) = mo_cut->insert_event( new_event( zif_cd_fmon_types=>gc_stage-ack ) ).
        cl_abap_unit_assert=>assert_false( act = lv_inserted
                                           msg = 'Second insert must report not inserted' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: EVENT_NO is assigned per file in insertion order (whole table asserted).
  METHOD events_numbered_per_file.
    DATA lt_exp TYPE zif_cd_fmon_types=>tt_event.
    TRY.
        DATA(ls_first) = new_event( zif_cd_fmon_types=>gc_stage-generated ).
        DATA(ls_second) = new_event( zif_cd_fmon_types=>gc_stage-sent ).
        mo_cut->insert_event( ls_first ).
        mo_cut->insert_event( ls_second ).
        ls_first-event_no    = 1.
        ls_first-created_by  = sy-uname.
        ls_first-created_at  = ltd_clock=>gc_now.
        ls_second-event_no   = 2.
        ls_second-created_by = sy-uname.
        ls_second-created_at = ltd_clock=>gc_now.
        INSERT ls_first INTO TABLE lt_exp.
        INSERT ls_second INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->get_events( VALUE #( ( ls_first-file_id ) ) )
                                            exp = lt_exp
                                            msg = 'Events must be numbered 1 and 2' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a saved registry entry is found again by interface + file reference.
  METHOD saved_file_found_by_ref.
    DATA lt_keys TYPE zif_cd_fmon_types=>tt_file_key.
    DATA ls_key TYPE zif_cd_fmon_types=>ty_file_key.
    TRY.
        DATA(ls_file) = new_file( iv_id = 1 iv_date = gc_date ).
        mo_cut->save_files( VALUE #( ( ls_file ) ) ).
        ls_key-iface_id = gc_iface.
        ls_key-file_ref = ls_file-file_ref.
        INSERT ls_key INTO TABLE lt_keys.
        cl_abap_unit_assert=>assert_equals( act = mo_cut->find_files_by_ref( lt_keys )
                                            exp = VALUE zif_cd_fmon_types=>tt_file( ( as_loaded( ls_file ) ) )
                                            msg = 'Saved file must be found by reference' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: files of the window plus older still-open files are evaluated; older
  " closed files are not.
  METHOD open_old_file_is_evaluated.
    TRY.
        DATA(ls_today) = new_file( iv_id = 1 iv_date = gc_date iv_outcome = zif_cd_fmon_types=>gc_stage-ack ).
        DATA(ls_old_open) = new_file( iv_id = 2 iv_date = '20261020' ).
        DATA(ls_old_done) = new_file( iv_id = 3 iv_date = '20261020' iv_outcome = zif_cd_fmon_types=>gc_stage-ack ).
        mo_cut->save_files( VALUE #( ( ls_today ) ( ls_old_open ) ( ls_old_done ) ) ).
        DATA(lt_files) = mo_cut->get_eval_files( iv_date_from  = '20261101'
                                                 iv_date_to    = gc_date
                                                 iv_open_since = '20261003' ).
        SORT lt_files BY file_id.
        cl_abap_unit_assert=>assert_equals( act = lt_files
                                            exp = VALUE zif_cd_fmon_types=>tt_file( ( as_loaded( ls_today ) )
                                                                                    ( as_loaded( ls_old_open ) ) )
                                            msg = 'Window file and old open file expected' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule: duplicate history finds an earlier file by checksum inside the window.
  METHOD history_found_by_checksum.
    TRY.
        DATA(ls_earlier) = new_file( iv_id = 7 iv_date = '20261030' ).
        mo_cut->save_files( VALUE #( ( ls_earlier ) ) ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->get_history( it_names     = VALUE #( )
                                     it_checksums = VALUE #( ( ls_earlier-checksum ) )
                                     iv_since     = '20261026' )
          exp = VALUE zif_cd_fmon_types=>tt_file( ( as_loaded( ls_earlier ) ) )
          msg = 'Earlier file with the same checksum expected' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  METHOD as_loaded.
    rs_file = is_file.
    rs_file-db_exists  = abap_true.
    rs_file-db_version = is_file-changed_at.
  ENDMETHOD.


  METHOD legacy_query.
    rs_query-table_name = 'ZCD_FMON_FILE'.
    zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-file_name
                                            iv_field = 'FILE_NAME'
                                  CHANGING  cs_query = rs_query ).
    rs_query-date_field = 'BUSINESS_DATE'.
    rs_query-date_kind  = zif_cd_fmon_types=>gc_date_kind-date.
    rs_query-date_from  = gc_date.
    rs_query-date_to    = gc_date.
    rs_query-max_rows   = 10.
  ENDMETHOD.


  METHOD msgno_of_read.
    TRY.
        mo_cut->read_legacy( legacy_query( ) ).
      CATCH zcx_cd_ops_error INTO DATA(lx).
        rv_msgno = lx->if_t100_message~t100key-msgno.
    ENDTRY.
  ENDMETHOD.


  METHOD approve_file_table.
    DATA lt_allow TYPE STANDARD TABLE OF zcd_fmon_tabwl WITH EMPTY KEY.
    DATA ls_allow TYPE zcd_fmon_tabwl.
    ls_allow-table_name = 'ZCD_FMON_FILE'.
    ls_allow-field_name = zif_cd_fmon_types=>gc_wildcard.
    ls_allow-active     = abap_true.
    INSERT ls_allow INTO TABLE lt_allow.
    go_env->insert_test_data( lt_allow ).
  ENDMETHOD.


  " Audit A50: a back-dated evaluation never pulls in open files of later business dates
  METHOD later_open_file_not_evaluated.
    TRY.
        DATA(ls_later) = new_file( iv_id = 4 iv_date = '20261103' ).
        mo_cut->save_files( VALUE #( ( ls_later ) ) ).
        DATA(lt_files) = mo_cut->get_eval_files( iv_date_from  = '20261101'
                                                 iv_date_to    = gc_date
                                                 iv_open_since = '20261003' ).
        cl_abap_unit_assert=>assert_initial( act = lt_files
                                             msg = 'An open file of a later date must not be evaluated' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A04: a row changed by another writer since it was read is not overwritten -
  " the save reports the conflict and the newer state stays
  METHOD newer_registry_not_overwritten.
    DATA lt_db TYPE STANDARD TABLE OF zcd_fmon_file WITH EMPTY KEY.
    TRY.
        DATA(ls_file) = new_file( iv_id = 5 iv_date = gc_date ).
        DATA(ls_db) = CORRESPONDING zcd_fmon_file( ls_file ).
        ls_db-stage      = zif_cd_fmon_types=>gc_stage-sent.
        ls_db-changed_at = '20261102075900'.
        INSERT ls_db INTO TABLE lt_db.
        go_env->insert_test_data( lt_db ).
        " this run read the row before the other writer changed it
        ls_file-db_exists  = abap_true.
        ls_file-db_version = '20261102070000'.
        ls_file-changed_at = ltd_clock=>gc_now.
        DATA(lt_conflicts) = mo_cut->save_files( VALUE #( ( ls_file ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lt_conflicts
                                            exp = VALUE zif_cd_fmon_types=>tt_file_id( ( ls_file-file_id ) )
                                            msg = 'The changed row must be reported as a conflict' ).
        DATA(lt_now) = mo_cut->find_files_by_ref( VALUE #( ( iface_id = gc_iface file_ref = ls_file-file_ref ) ) ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_now[ 1 ]-stage OPTIONAL )
                                            exp = zif_cd_fmon_types=>gc_stage-sent
                                            msg = 'The newer stage must not be overwritten' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A04: an unchanged row is saved normally
  METHOD unchanged_registry_is_saved.
    DATA lt_db TYPE STANDARD TABLE OF zcd_fmon_file WITH EMPTY KEY.
    TRY.
        DATA(ls_file) = new_file( iv_id = 6 iv_date = gc_date ).
        DATA(ls_db) = CORRESPONDING zcd_fmon_file( ls_file ).
        ls_db-changed_at = '20261102070000'.
        INSERT ls_db INTO TABLE lt_db.
        go_env->insert_test_data( lt_db ).
        ls_file-db_exists  = abap_true.
        ls_file-db_version = '20261102070000'.
        ls_file-stage      = zif_cd_fmon_types=>gc_stage-sent.
        ls_file-changed_at = ltd_clock=>gc_now.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->save_files( VALUE #( ( ls_file ) ) )
                                             msg = 'An unchanged row must save without conflict' ).
        DATA(lt_now) = mo_cut->find_files_by_ref( VALUE #( ( iface_id = gc_iface file_ref = ls_file-file_ref ) ) ).
        cl_abap_unit_assert=>assert_equals( act = VALUE #( lt_now[ 1 ]-stage OPTIONAL )
                                            exp = zif_cd_fmon_types=>gc_stage-sent
                                            msg = 'The new stage must be stored' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A05/A49: event idempotency is per file instance - the same reference, source and
  " stage of another business date's file is a new event, not a duplicate
  METHOD event_belongs_to_its_instance.
    TRY.
        DATA(ls_day1) = new_event( zif_cd_fmon_types=>gc_stage-ack ).
        DATA(ls_day2) = ls_day1.
        ls_day2-file_id = CONV zif_cd_fmon_types=>ty_file_id( 2 ).
        mo_cut->insert_event( ls_day1 ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->insert_event( ls_day2 )
                                          msg = 'The second instance must get its own event' ).
        cl_abap_unit_assert=>assert_equals(
          act = lines( mo_cut->get_events( VALUE #( ( ls_day1-file_id ) ( ls_day2-file_id ) ) ) )
          exp = 2
          msg = 'One event per file instance expected' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

  " Audit A90: two interfaces reuse the same file reference on the same source and stage.
  " Each interface has its own file instance (FILE_ID), so each file keeps its own event.
  METHOD cross_interface_ref_own_event.
    TRY.
        DATA(ls_iface_a) = new_event( zif_cd_fmon_types=>gc_stage-ack ).
        DATA(ls_iface_b) = ls_iface_a.
        ls_iface_b-file_id = CONV zif_cd_fmon_types=>ty_file_id( 3 ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->insert_event( ls_iface_a )
                                          msg = 'The first interface file must get its event' ).
        cl_abap_unit_assert=>assert_true( act = mo_cut->insert_event( ls_iface_b )
                                          msg = 'The second interface file must get its own event' ).
        cl_abap_unit_assert=>assert_false( act = mo_cut->insert_event( ls_iface_b )
                                           msg = 'A replay for the same file must stay idempotent' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.



  " Audit A49: instances of the same reference older than the watch window are not read
  METHOD older_instances_not_prefetched.
    TRY.
        DATA(ls_old) = new_file( iv_id = 8 iv_date = '20260901' ).
        DATA(ls_new) = new_file( iv_id = 9 iv_date = gc_date ).
        ls_new-file_ref = ls_old-file_ref.
        mo_cut->save_files( VALUE #( ( ls_old ) ( ls_new ) ) ).
        DATA(lt_found) = mo_cut->find_files_by_ref(
                           it_keys  = VALUE #( ( iface_id = gc_iface file_ref = ls_old-file_ref ) )
                           iv_since = '20261003' ).
        cl_abap_unit_assert=>assert_equals( act = lt_found
                                            exp = VALUE zif_cd_fmon_types=>tt_file( ( as_loaded( ls_new ) ) )
                                            msg = 'Only the instance inside the window expected' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A51: a valid table name that nobody approved in ZCD_FMON_TABWL is never read (244)
  METHOD unapproved_table_is_refused.
    cl_abap_unit_assert=>assert_equals( act = msgno_of_read( ) exp = '244'
                                        msg = 'An unapproved table must raise 244' ).
  ENDMETHOD.


  " Audit A51: an approved table without display authorisation is not read (245)
  METHOD read_without_auth_is_refused.
    approve_file_table( ).
    mo_ddic->mv_may_read = abap_false.
    cl_abap_unit_assert=>assert_equals( act = msgno_of_read( ) exp = '245'
                                        msg = 'Missing S_TABU_NAM display authority must raise 245' ).
  ENDMETHOD.


  " Fix 8: the grouped read counts the rows per value combination of the query fields (here
  " interface and stage of ZCD_FMON_FILE) - the same rows the plain read would return.
  " VERIFY-ADT: dynamic GROUP BY with a dynamic table inside cl_osql_test_environment
  METHOD grouped_count_per_status.
    DATA ls_query TYPE zif_cd_fmon_types=>ty_query.
    TRY.
        approve_file_table( ).
        DATA(ls_file1) = new_file( iv_id = 1 iv_date = gc_date ).
        DATA(ls_file2) = new_file( iv_id = 2 iv_date = gc_date ).
        DATA(ls_file3) = new_file( iv_id = 3 iv_date = gc_date ).
        ls_file3-stage = zif_cd_fmon_types=>gc_stage-sent.
        mo_cut->save_files( VALUE #( ( ls_file1 ) ( ls_file2 ) ( ls_file3 ) ) ).
        ls_query-table_name = 'ZCD_FMON_FILE'.
        zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-file_link
                                                iv_field = 'IFACE_ID'
                                      CHANGING  cs_query = ls_query ).
        zcl_cd_fmon_query=>add_field( EXPORTING iv_role  = zif_cd_fmon_types=>gc_role-item_status
                                                iv_field = 'STAGE'
                                      CHANGING  cs_query = ls_query ).
        ls_query-in_field  = 'IFACE_ID'.
        ls_query-in_values = VALUE #( ( CONV #( gc_iface ) ) ).
        DATA(lt_counts) = mo_cut->count_legacy( ls_query ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_counts ) exp = 2
                                            msg = 'Two stages, two groups' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( lt_counts[ row-item_status = CONV string( zif_cd_fmon_types=>gc_stage-generated ) ]-row_count
                         OPTIONAL )
          exp = 2
          msg = 'Two files in GENERATED' ).
        cl_abap_unit_assert=>assert_equals(
          act = VALUE #( lt_counts[ row-item_status = CONV string( zif_cd_fmon_types=>gc_stage-sent ) ]-row_count
                         OPTIONAL )
          exp = 1
          msg = 'One file in SENT' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Fix 8: the grouped read passes the same approval gate as the plain read (A51)
  METHOD grouped_count_needs_approval.
    DATA lv_msgno TYPE symsgno.
    TRY.
        mo_cut->count_legacy( legacy_query( ) ).
      CATCH zcx_cd_ops_error INTO DATA(lx).
        lv_msgno = lx->if_t100_message~t100key-msgno.
    ENDTRY.
    cl_abap_unit_assert=>assert_equals( act = lv_msgno exp = '244'
                                        msg = 'An unapproved table must raise 244 for the grouped read too' ).
  ENDMETHOD.


  " Audit A51: an approved, authorised table is read
  METHOD approved_table_is_read.
    approve_file_table( ).
    cl_abap_unit_assert=>assert_initial( act = msgno_of_read( )
                                         msg = 'An approved and authorised table must be read' ).
  ENDMETHOD.

ENDCLASS.

