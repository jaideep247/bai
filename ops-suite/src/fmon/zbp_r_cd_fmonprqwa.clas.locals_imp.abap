*&---------------------------------------------------------------------*
*& Artifact: zbp_r_cd_fmonprqwa.clas.locals_imp.abap
*& Purpose:
*& Handler and saver of the PRISM handled-manually app: ZCD_OPS 02 (FMON) to
*& record; record stamped with user, time and status H; completeness from
*& ZCL_CD_FMON_OPS_POLICY; on save the open FMON exception whose object key
*& is the request reference (upper case, as FMON keys request "files") is
*& resolved with action MANUAL and the handling reference.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
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
    METHODS save_modified REDEFINITION.
ENDCLASS.


CLASS lsc_handled IMPLEMENTATION.

  METHOD save_modified.
    " VERIFY-ADT: READ ENTITIES of the own BO in save_modified (buffer read only).
    CHECK create-handled IS NOT INITIAL.
    READ ENTITIES OF zr_cd_fmonprqwa IN LOCAL MODE
      ENTITY Handled ALL FIELDS WITH CORRESPONDING #( create-handled )
      RESULT DATA(lt_rows).
    DATA(lo_exc_dao) = zcl_cd_ops_factory=>get_exc_dao( ).
    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      TRY.
          lo_exc_dao->resolve( it_keys      = lo_exc_dao->find_open(
                                                iv_pe_area     = zif_cd_ops_types=>gc_pe_area-file_monitor
                                                iv_object_key = to_upper( <ls_row>-RequestRef ) )
                               iv_action    = zif_cd_ops_exc_types=>gc_action-manual
                               iv_reason    = <ls_row>-Reason
                               iv_reference = <ls_row>-Reference
                               iv_user      = sy-uname
                               iv_at        = lv_now ).
        CATCH zcx_cd_ops_error INTO DATA(lx_error).
          " the record itself is saved; the exception stays open and visible in the exceptions app
          INSERT VALUE #( %tky = <ls_row>-%tky
                          %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = zif_cd_ops_types=>gc_msgno_free
                                              severity = if_abap_behv_message=>severity-warning
                                              v1 = lx_error->get_text( ) ) ) INTO TABLE reported-handled.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
