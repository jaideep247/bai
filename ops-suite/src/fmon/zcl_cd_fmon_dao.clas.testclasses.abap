*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_dao.clas.testclasses.abap
*& Purpose:
*& SQL tests of the FMON repository on cl_osql_test_environment doubles of
*& ZCD_FMON_FILE / ZCD_FMON_EVENT: event idempotency, numbering, registry
*& lookups; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
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


CLASS ltc_dao DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_iface TYPE zif_cd_fmon_types=>ty_iface_id VALUE 'ACH_PNC_OUT'.
    CONSTANTS gc_src TYPE zif_cd_fmon_types=>ty_src_id VALUE 'ACHACK'.
    CONSTANTS gc_date TYPE d VALUE '20261102'.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_fmon_dao.

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

ENDCLASS.


CLASS ltc_dao IMPLEMENTATION.

  METHOD class_setup.
    DATA lt_deps TYPE if_osql_test_environment=>ty_t_sobjnames.
    INSERT CONV #( 'ZCD_FMON_FILE' ) INTO TABLE lt_deps.
    INSERT CONV #( 'ZCD_FMON_EVENT' ) INTO TABLE lt_deps.
    go_env = cl_osql_test_environment=>create( i_dependency_list = lt_deps ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
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
                                            exp = VALUE zif_cd_fmon_types=>tt_file( ( ls_file ) )
                                            msg = 'Saved file must be found by reference' ).
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
                                            exp = VALUE zif_cd_fmon_types=>tt_file( ( ls_today ) ( ls_old_open ) )
                                            msg = 'Window file and old open file expected' ).
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
          exp = VALUE zif_cd_fmon_types=>tt_file( ( ls_earlier ) )
          msg = 'Earlier file with the same checksum expected' ).
      CATCH cx_root INTO DATA(lx).
        cl_abap_unit_assert=>fail( msg = |Unexpected exception: { lx->get_text( ) }| ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
