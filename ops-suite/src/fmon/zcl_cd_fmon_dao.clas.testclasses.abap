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
*& 2026-11-06 | Modern-syntax sweep: caught exception lx_error.
*& 2026-11-06 | ltc_cfg_reads: interfaces, SLAs, calendars, sources, maps, lot configs, checks (coverage gap closure).
*& 2026-11-07 | ltc_cfg_reads: SLA and calendar rows active only, stage deadlines (ZCD_FMON_DEADL).
*& 2026-11-07 | Regenerated files: generations found by interface + generation group within the window
*&            | (get_group_files, index GRP).
*& 2026-11-08 | get_group_acks: the files of a group with their ACK events in one read - a file without
*&            | ACK once with ACK_AT initial, other stages, other groups and older files not read.
*& 2026-11-08 | Table consolidation: approvals in ZCD_OPS_TABWL (FMON / SOURCE, blank field = whole table);
*&            | rows of another area or purpose do not approve (other_purpose_not_approved).
*& 2026-11-08 | Table consolidation: SLA rows with KIND / DAY_TYPE; deadlines_only_active reads DURATION and
*&            | DEADLINE rows of ZCD_FMON_SLA in one read (ZCD_FMON_DEADL merged).
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

    "! A row of the approved-table list for ZCD_FMON_FILE (default: FMON / SOURCE, whole table)
    METHODS approve_file_table
      IMPORTING
        iv_pe_area TYPE zif_cd_ops_types=>ty_pe_area DEFAULT zif_cd_ops_types=>gc_pe_area-file_monitor
        iv_purpose TYPE zif_cd_ops_types=>ty_tabwl_purpose DEFAULT zif_cd_ops_types=>gc_tabwl_purpose-source.

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
    METHODS other_purpose_not_approved FOR TESTING.
    METHODS grouped_count_per_status FOR TESTING.
    METHODS grouped_count_needs_approval FOR TESTING.
    METHODS generations_found_by_group FOR TESTING.
    METHODS group_acks_with_events FOR TESTING.

ENDCLASS.


CLASS ltc_dao IMPLEMENTATION.

  METHOD class_setup.
    DATA lt_deps TYPE if_osql_test_environment=>ty_t_sobjnames.
    INSERT CONV #( 'ZCD_FMON_FILE' ) INTO TABLE lt_deps.
    INSERT CONV #( 'ZCD_FMON_EVENT' ) INTO TABLE lt_deps.
    INSERT CONV #( 'ZCD_OPS_TABWL' ) INTO TABLE lt_deps.
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (regenerated files): the generations of a payment run are found by interface + group key
  " since the window start - another group and an older generation are not read.
  METHOD generations_found_by_group.
    CONSTANTS lc_group TYPE zif_cd_fmon_types=>ty_file_ref VALUE '20261102/RUN01/PNC1'.
    CONSTANTS lc_other TYPE zif_cd_fmon_types=>ty_file_ref VALUE '20261102/RUN02/PNC1'.
    TRY.
        DATA(ls_first) = new_file( iv_id = 1 iv_date = gc_date ).
        ls_first-gen_group = lc_group.
        DATA(ls_second) = new_file( iv_id = 2 iv_date = '20261020' ).
        ls_second-gen_group = lc_group.
        DATA(ls_other) = new_file( iv_id = 3 iv_date = gc_date ).
        ls_other-gen_group = lc_other.
        DATA(ls_too_old) = new_file( iv_id = 4 iv_date = '20261001' ).
        ls_too_old-gen_group = lc_group.
        mo_cut->save_files( VALUE #( ( ls_first ) ( ls_second ) ( ls_other ) ( ls_too_old ) ) ).
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->get_group_files( it_keys  = VALUE #( ( iface_id = gc_iface gen_group = lc_group ) )
                                         iv_since = '20261003' )
          exp = VALUE zif_cd_fmon_types=>tt_file( ( as_loaded( ls_first ) ) ( as_loaded( ls_second ) ) )
          msg = 'Both generations of the run inside the window, nothing else' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Rule (status lag of A_INFLIGHT, file-level ACK): the files of a generation group come back with
  " their ACK_RECEIVED events in one read - a file without ACK once with ACK_AT initial; other stages,
  " another group and a file older than the window are not read.
  METHOD group_acks_with_events.
    CONSTANTS lc_group TYPE zif_cd_fmon_types=>ty_file_ref VALUE '20261102/COLL01/PNC1'.
    CONSTANTS lc_other TYPE zif_cd_fmon_types=>ty_file_ref VALUE '20261102/COLL02/PNC1'.
    DATA lt_exp TYPE zif_cd_fmon_types=>tt_group_ack.
    DATA ls_exp TYPE zif_cd_fmon_types=>ty_group_ack.
    TRY.
        DATA(ls_acked) = new_file( iv_id = 1 iv_date = gc_date ).
        ls_acked-gen_group      = lc_group.
        ls_acked-first_event_at = '20261102060000'.
        DATA(ls_open) = new_file( iv_id = 2 iv_date = gc_date ).
        ls_open-gen_group      = lc_group.
        ls_open-first_event_at = '20261102070000'.
        DATA(ls_other) = new_file( iv_id = 3 iv_date = gc_date ).
        ls_other-gen_group = lc_other.
        DATA(ls_too_old) = new_file( iv_id = 4 iv_date = '20261001' ).
        ls_too_old-gen_group = lc_group.
        mo_cut->save_files( VALUE #( ( ls_acked ) ( ls_open ) ( ls_other ) ( ls_too_old ) ) ).
        " File 1: generated, then acknowledged (event of file 1 of NEW_EVENT)
        mo_cut->insert_event( new_event( zif_cd_fmon_types=>gc_stage-generated ) ).
        mo_cut->insert_event( new_event( zif_cd_fmon_types=>gc_stage-ack ) ).
        ls_exp-file_id        = ls_acked-file_id.
        ls_exp-iface_id       = gc_iface.
        ls_exp-gen_group      = lc_group.
        ls_exp-file_ref       = ls_acked-file_ref.
        ls_exp-file_name      = ls_acked-file_name.
        ls_exp-first_event_at = ls_acked-first_event_at.
        ls_exp-ack_at         = ltd_clock=>gc_now.
        INSERT ls_exp INTO TABLE lt_exp.
        ls_exp-file_id        = ls_open-file_id.
        ls_exp-file_ref       = ls_open-file_ref.
        ls_exp-file_name      = ls_open-file_name.
        ls_exp-first_event_at = ls_open-first_event_at.
        CLEAR ls_exp-ack_at.
        INSERT ls_exp INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals(
          act = mo_cut->get_group_acks( it_keys  = VALUE #( ( iface_id = gc_iface gen_group = lc_group ) )
                                        iv_since = '20261003' )
          exp = lt_exp
          msg = 'Both files of the group, the ACK of file 1, nothing else' ).
      CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
        cl_abap_unit_assert=>fail( msg = |Database error: { lx_sql->get_text( ) }| ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        rv_msgno = lx_error->if_t100_message~t100key-msgno.
    ENDTRY.
  ENDMETHOD.


  METHOD approve_file_table.
    DATA lt_allow TYPE STANDARD TABLE OF zcd_ops_tabwl WITH EMPTY KEY.
    DATA ls_allow TYPE zcd_ops_tabwl.
    ls_allow-pe_area    = iv_pe_area.
    ls_allow-purpose    = iv_purpose.
    ls_allow-table_name = 'ZCD_FMON_FILE'.
    " blank field = the whole table
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Audit A51: a valid table name that nobody approved in ZCD_OPS_TABWL (FMON / SOURCE) is never read (244)
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
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx_error->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.


  " Fix 8: the grouped read passes the same approval gate as the plain read (A51)
  METHOD grouped_count_needs_approval.
    DATA lv_msgno TYPE symsgno.
    TRY.
        mo_cut->count_legacy( legacy_query( ) ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        lv_msgno = lx_error->if_t100_message~t100key-msgno.
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


  " Table consolidation 2026-11-08: the reader filters the approved-table list by its own area and
  " purpose - an HCK READ row (or an FMON row of another purpose) never approves the FMON reader
  METHOD other_purpose_not_approved.
    approve_file_table( iv_pe_area = zif_cd_ops_types=>gc_pe_area-health_check
                        iv_purpose = zif_cd_ops_types=>gc_tabwl_purpose-read ).
    approve_file_table( iv_purpose = zif_cd_ops_types=>gc_tabwl_purpose-drift ).
    cl_abap_unit_assert=>assert_equals( act = msgno_of_read( ) exp = '244'
                                        msg = 'Rows of another area or purpose must not approve the FMON read' ).
  ENDMETHOD.

ENDCLASS.



"! OSQL tests of the FMON customizing reads (every table they read is doubled): active
"! filter where the read has one, all rows where it has none
CLASS ltc_cfg_reads DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        iface_on  TYPE c LENGTH 20 VALUE 'ACH_OUT_JPMC',
        iface_off TYPE c LENGTH 20 VALUE 'OLD_IFACE',
        stage_ack TYPE c LENGTH 20 VALUE 'ACK',
        stage_snt TYPE c LENGTH 20 VALUE 'SENT',
        day_work  TYPE c LENGTH 12 VALUE 'WORKDAY',
        day_off   TYPE c LENGTH 12 VALUE 'HOLIDAY',
        stage_off TYPE c LENGTH 20 VALUE 'FORWARDED',
        due_time  TYPE t VALUE '100000',
        minutes   TYPE i VALUE 30,
        src_on    TYPE c LENGTH 10 VALUE 'PRISM',
        src_off   TYPE c LENGTH 10 VALUE 'LEGACY',
        status_ok TYPE c LENGTH 40 VALUE 'DELIVERED',
        status_ko TYPE c LENGTH 40 VALUE 'REJECTED',
        lot_type  TYPE c LENGTH 10 VALUE 'RETURNS',
        lot_off   TYPE c LENGTH 10 VALUE 'NOC',
        check_on  TYPE c LENGTH 10 VALUE 'LATE',
        check_off TYPE c LENGTH 10 VALUE 'SIZE',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_fmon_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS ifaces_only_active FOR TESTING.
    METHODS slas_only_active FOR TESTING.
    METHODS calendars_only_active FOR TESTING.
    METHODS deadlines_only_active FOR TESTING.
    METHODS sources_only_active FOR TESTING.
    METHODS source_maps_all_rows FOR TESTING.
    METHODS lot_configs_only_active FOR TESTING.
    METHODS checks_only_active FOR TESTING.
ENDCLASS.


CLASS ltc_cfg_reads IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'ZCD_FMON_IFACE' ) ( 'ZCD_FMON_SLA' ) ( 'ZCD_FMON_CAL' )
                                   ( 'ZCD_FMON_SRC' ) ( 'ZCD_FMON_SRCMAP' ) ( 'ZCD_FMON_LOTCFG' )
                                   ( 'ZCD_FMON_CHK' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    mo_cut = NEW zcl_cd_fmon_dao( ).
  ENDMETHOD.


  " Rule: only active interfaces are monitored
  METHOD ifaces_only_active.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_fmon_iface WITH EMPTY KEY.
    DATA ls_row TYPE zcd_fmon_iface.
    TRY.
        ls_row-iface_id = gc_test-iface_on.
        ls_row-active   = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-iface_id = gc_test-iface_off.
        ls_row-active   = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_ifaces) = mo_cut->get_ifaces( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_ifaces ) exp = 1 msg = 'Only the active interface' ).
        cl_abap_unit_assert=>assert_equals( act = lt_ifaces[ 1 ]-iface_id exp = gc_test-iface_on
                                            msg = 'Active interface returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only active SLA rows are read (production switches a row off, never deletes it)
  METHOD slas_only_active.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_fmon_sla WITH EMPTY KEY.
    DATA ls_row TYPE zcd_fmon_sla.
    TRY.
        ls_row-iface_id = gc_test-iface_on.
        ls_row-stage    = gc_test-stage_snt.
        ls_row-kind     = zif_cd_fmon_types=>gc_sla_kind-duration.
        ls_row-day_type = zif_cd_fmon_types=>gc_wildcard.
        ls_row-active   = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-stage    = gc_test-stage_ack.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-stage    = gc_test-stage_off.
        ls_row-active   = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_slas( ) ) exp = 2
                                            msg = 'Both active SLA stages, not the switched-off one' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only active calendar rows are read; boundary: none configured - empty
  METHOD calendars_only_active.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_fmon_cal WITH EMPTY KEY.
    DATA ls_row TYPE zcd_fmon_cal.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_calendars( ) msg = 'No calendar configured' ).
        ls_row-iface_id = gc_test-iface_on.
        ls_row-day_type = gc_test-day_work.
        ls_row-active   = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-day_type = gc_test-day_off.
        ls_row-active   = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_cals) = mo_cut->get_calendars( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_cals ) exp = 1 msg = 'One calendar row' ).
        cl_abap_unit_assert=>assert_equals( act = lt_cals[ 1 ]-day_type exp = gc_test-day_work
                                            msg = 'Day type returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (table consolidation 2026-11-08): a DURATION and a DEADLINE row of the same interface and stage
  " are both read in one read with their kind's fields; a switched-off deadline is not read
  METHOD deadlines_only_active.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_fmon_sla WITH EMPTY KEY.
    DATA ls_row TYPE zcd_fmon_sla.
    TRY.
        ls_row-iface_id    = gc_test-iface_on.
        ls_row-stage       = gc_test-stage_snt.
        ls_row-kind        = zif_cd_fmon_types=>gc_sla_kind-duration.
        ls_row-day_type    = zif_cd_fmon_types=>gc_wildcard.
        ls_row-max_minutes = gc_test-minutes.
        ls_row-active      = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        CLEAR ls_row-max_minutes.
        ls_row-kind     = zif_cd_fmon_types=>gc_sla_kind-deadline.
        ls_row-day_type = gc_test-day_work.
        ls_row-due_time = gc_test-due_time.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-stage    = gc_test-stage_ack.
        ls_row-active   = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_slas) = mo_cut->get_slas( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_slas ) exp = 2
                                            msg = 'Duration and active deadline, not the switched-off one' ).
        cl_abap_unit_assert=>assert_equals(
          act = lt_slas[ stage = gc_test-stage_snt kind = zif_cd_fmon_types=>gc_sla_kind-deadline ]-due_time
          exp = gc_test-due_time
          msg = 'Due time of the DEADLINE row' ).
        cl_abap_unit_assert=>assert_equals(
          act = lt_slas[ stage = gc_test-stage_snt kind = zif_cd_fmon_types=>gc_sla_kind-duration ]-max_minutes
          exp = gc_test-minutes
          msg = 'Minutes of the DURATION row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only active sources are read
  METHOD sources_only_active.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_fmon_src WITH EMPTY KEY.
    DATA ls_row TYPE zcd_fmon_src.
    TRY.
        ls_row-src_id = gc_test-src_on.
        ls_row-active = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-src_id = gc_test-src_off.
        ls_row-active = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_sources) = mo_cut->get_sources( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_sources ) exp = 1 msg = 'Only the active source' ).
        cl_abap_unit_assert=>assert_equals( act = lt_sources[ 1 ]-src_id exp = gc_test-src_on
                                            msg = 'Active source returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: every status map row of every source is read
  METHOD source_maps_all_rows.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_fmon_srcmap WITH EMPTY KEY.
    DATA ls_row TYPE zcd_fmon_srcmap.
    TRY.
        ls_row-src_id       = gc_test-src_on.
        ls_row-status_value = gc_test-status_ok.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-status_value = gc_test-status_ko.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->get_source_maps( ) ) exp = 2
                                            msg = 'Both status values' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only active lot configurations are read
  METHOD lot_configs_only_active.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_fmon_lotcfg WITH EMPTY KEY.
    DATA ls_row TYPE zcd_fmon_lotcfg.
    TRY.
        ls_row-iface_id = gc_test-iface_on.
        ls_row-lot_type = gc_test-lot_type.
        ls_row-active   = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-lot_type = gc_test-lot_off.
        ls_row-active   = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_cfgs) = mo_cut->get_lot_configs( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_cfgs ) exp = 1 msg = 'Only the active lot type' ).
        cl_abap_unit_assert=>assert_equals( act = lt_cfgs[ 1 ]-lot_type exp = gc_test-lot_type
                                            msg = 'Active lot type returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only active checks are run
  METHOD checks_only_active.
    DATA lt_rows TYPE STANDARD TABLE OF zcd_fmon_chk WITH EMPTY KEY.
    DATA ls_row TYPE zcd_fmon_chk.
    TRY.
        ls_row-check_id = gc_test-check_on.
        ls_row-active   = abap_true.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-check_id = gc_test-check_off.
        ls_row-active   = abap_false.
        INSERT ls_row INTO TABLE lt_rows.
        go_env->insert_test_data( lt_rows ).
        DATA(lt_checks) = mo_cut->get_checks( ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_checks ) exp = 1 msg = 'Only the active check' ).
        cl_abap_unit_assert=>assert_equals( act = lt_checks[ 1 ]-check_id exp = gc_test-check_on
                                            msg = 'Active check returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
