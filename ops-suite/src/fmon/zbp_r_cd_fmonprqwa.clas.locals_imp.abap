*&---------------------------------------------------------------------*
*& Artifact: zbp_r_cd_fmonprqwa.clas.locals_imp.abap
*& Purpose:
*& Handler and saver of the PRISM handled-manually app: ZCD_OPS 02 (FMON) to
*& record; record stamped with user, time and status H; completeness from
*& ZCL_CD_FMON_OPS_POLICY; the open FMON exceptions whose object key is the
*& request reference (upper case, as FMON keys request "files") are read in
*& the early save (a read failure refuses the save) and resolved in the late
*& save with action MANUAL and the handling reference - all or nothing: a
*& write failure ends the save, never a half-written closure.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Modern-syntax sweep: INSERT INTO TABLE.
*& 2026-11-10 | Concurrency review: the open exceptions of a request are found in CHECK_BEFORE_SAVE (a read
*&            | failure refuses the save with message 788, before any write); SAVE_MODIFIED resolves exactly
*&            | the exceptions read there, all or nothing - a write failure or an exception changed meanwhile
*&            | ends the save (RAISE SHORTDUMP, as ZBP_R_CD_FMONFILE), never a record without its closure or a
*&            | closure without its history.
*&---------------------------------------------------------------------*
"! Transaction buffer: the records created in this transaction (determination) and the open exceptions
"! of each, read in the early save phase and resolved in SAVE_MODIFIED
CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_record,
        wa_uuid TYPE sysuuid_x16,
        open    TYPE zif_cd_ops_exc_types=>tt_exc_open,
      END OF ty_record.
    TYPES tt_record TYPE SORTED TABLE OF ty_record WITH UNIQUE KEY wa_uuid.
    CLASS-DATA gt_created TYPE tt_record.
ENDCLASS.


CLASS lhc_handled DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    CONSTANTS gc_status_handled TYPE c LENGTH 1 VALUE 'H'.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Handled RESULT result.

    METHODS sethandled FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Handled~setHandled.

    METHODS validatehandled FOR VALIDATE ON SAVE
      IMPORTING keys FOR Handled~validateHandled.
ENDCLASS.


CLASS lhc_handled IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = COND #( WHEN zcl_cd_ops_factory=>get_auth( )->is_allowed(
                                      iv_activity = zif_cd_ops_auth=>gc_activity-change
                                      iv_pe_area   = zif_cd_ops_types=>gc_pe_area-file_monitor ) = abap_true
                               THEN if_abap_behv=>auth-allowed
                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.


  METHOD sethandled.
    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).
    " Remembered for the save: its exceptions are read in CHECK_BEFORE_SAVE
    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      INSERT VALUE #( wa_uuid = <ls_key>-WaUuid ) INTO TABLE lcl_buffer=>gt_created.
    ENDLOOP.
    MODIFY ENTITIES OF zr_cd_fmonprqwa IN LOCAL MODE
      ENTITY Handled
        UPDATE FIELDS ( Status HandledBy HandledAt )
        WITH VALUE #( FOR ls_key IN keys ( %tky      = ls_key-%tky
                                           Status    = gc_status_handled
                                           HandledBy = sy-uname
                                           HandledAt = lv_now ) ).
  ENDMETHOD.


  METHOD validatehandled.
    READ ENTITIES OF zr_cd_fmonprqwa IN LOCAL MODE
      ENTITY Handled FIELDS ( RequestRef Reference Reason ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rows).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(ls_decision) = zcl_cd_fmon_ops_policy=>check_handled( iv_request_ref = <ls_row>-RequestRef
                                                                 iv_reference   = <ls_row>-Reference
                                                                 iv_reason      = <ls_row>-Reason ).
      IF ls_decision-allowed = abap_false.
        INSERT VALUE #( %tky = <ls_row>-%tky ) INTO TABLE failed-handled.
        INSERT VALUE #( %tky = <ls_row>-%tky
                        %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = ls_decision-msgno
                                            severity = if_abap_behv_message=>severity-error ) )
          INTO TABLE reported-handled.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.


CLASS lsc_handled DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS check_before_save REDEFINITION.
    METHODS save_modified REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.


CLASS lsc_handled IMPLEMENTATION.

  METHOD check_before_save.
    " Early save (no write yet): the open exceptions of each new record are read here - a failure refuses
    " the save with a message instead of a record whose exception silently stays open
    CHECK lcl_buffer=>gt_created IS NOT INITIAL.
    READ ENTITIES OF zr_cd_fmonprqwa IN LOCAL MODE
      ENTITY Handled FIELDS ( RequestRef ) WITH VALUE #( FOR ls_created IN lcl_buffer=>gt_created
                                                         ( WaUuid = ls_created-wa_uuid ) )
      RESULT DATA(lt_rows).
    DATA(lo_exc_dao) = zcl_cd_ops_factory=>get_exc_dao( ).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      READ TABLE lcl_buffer=>gt_created ASSIGNING FIELD-SYMBOL(<ls_created>)
           WITH TABLE KEY wa_uuid = <ls_row>-WaUuid.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      TRY.
          " As FMON keys request "files": the request reference in upper case (one keyed read per record)
          <ls_created>-open = lo_exc_dao->find_open( iv_pe_area    = zif_cd_ops_types=>gc_pe_area-file_monitor
                                                     iv_object_key = to_upper( <ls_row>-RequestRef ) ).
        CATCH cx_sy_open_sql_db.
          INSERT VALUE #( %tky = <ls_row>-%tky ) INTO TABLE failed-handled.
          INSERT VALUE #( %tky = <ls_row>-%tky
                          %msg = new_message( id       = zif_cd_ops_types=>gc_message_class
                                              number   = zif_cd_ops_exc_types=>gc_msg-open_read_failed
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = <ls_row>-RequestRef ) ) INTO TABLE reported-handled.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD save_modified.
    " VERIFY-ADT: READ ENTITIES of the own BO in save_modified (buffer read only).
    CHECK create-handled IS NOT INITIAL.
    READ ENTITIES OF zr_cd_fmonprqwa IN LOCAL MODE
      ENTITY Handled ALL FIELDS WITH CORRESPONDING #( create-handled )
      RESULT DATA(lt_rows).
    DATA(lo_exc_dao) = zcl_cd_ops_factory=>get_exc_dao( ).
    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      " Exactly the exceptions read in CHECK_BEFORE_SAVE, written only while they are as read
      DATA(lt_open) = VALUE #( lcl_buffer=>gt_created[ wa_uuid = <ls_row>-WaUuid ]-open OPTIONAL ).
      TRY.
          lo_exc_dao->resolve( it_open      = lt_open
                               iv_action    = zif_cd_ops_exc_types=>gc_action-manual
                               iv_reason    = <ls_row>-Reason
                               iv_reference = <ls_row>-Reference
                               iv_user      = sy-uname
                               iv_at        = lv_now ).
        CATCH zcx_cd_ops_error INTO DATA(lx_error).
          " Late save: past the point of no return - a record without its closure, or a closure without
          " its history, is never committed (the framework rolls the whole save back)
          RAISE SHORTDUMP lx_error.
        CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
          RAISE SHORTDUMP lx_sql.
      ENDTRY.
    ENDLOOP.
    CLEAR lcl_buffer=>gt_created.
  ENDMETHOD.


  METHOD cleanup_finalize.
    CLEAR lcl_buffer=>gt_created.
  ENDMETHOD.

ENDCLASS.
