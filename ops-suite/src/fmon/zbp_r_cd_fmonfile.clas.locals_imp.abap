*&---------------------------------------------------------------------*
*& Artifact: zbp_r_cd_fmonfile.clas.locals_imp.abap
*& Purpose:
*& Handler and saver of the FMON manual-status app: ZCD_OPS 02 (FMON); the
*& action asks ZCL_CD_FMON_OPS_POLICY, moves the file with the state
*& machine and keeps reason / evidence in a transaction buffer; the saver
*& writes one event per change with source MANUAL. The next FMON run
*& reconciles the exceptions of the file (store reconcile, phase 1).
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Audit A05: technical database error of the event insert ends the save.
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Modern-syntax sweep: INSERT INTO TABLE.
*&---------------------------------------------------------------------*
CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF ty_manual,
        file_id  TYPE zif_cd_fmon_types=>ty_file_id,
        stage    TYPE zif_cd_fmon_types=>ty_stage,
        reason   TYPE zif_cd_fmon_types=>ty_info,
        evidence TYPE zif_cd_fmon_types=>ty_file_ref,
      END OF ty_manual.
    TYPES tt_manual TYPE STANDARD TABLE OF ty_manual WITH EMPTY KEY.
    CLASS-DATA gt_manual TYPE tt_manual.
ENDCLASS.


CLASS lhc_fmonfile DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR FmonFile RESULT result.

    METHODS setmanualstatus FOR MODIFY
      IMPORTING keys FOR ACTION FmonFile~setManualStatus RESULT result.
ENDCLASS.


CLASS lhc_fmonfile IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%action-setManualStatus = if_abap_behv=>mk-on.
      result-%action-setManualStatus = COND #( WHEN zcl_ca_ops_factory=>get_auth( )->is_allowed(
                                                      iv_activity = zif_ca_ops_auth=>gc_activity-change
                                                      iv_pe_area   = zif_cd_ops_types=>gc_pe_area-file_monitor ) = abap_true
                                               THEN if_abap_behv=>auth-allowed
                                               ELSE if_abap_behv=>auth-unauthorized ).
    ENDIF.
  ENDMETHOD.


  METHOD setmanualstatus.
    DATA ls_file TYPE zif_cd_fmon_types=>ty_file.
    READ ENTITIES OF zr_cd_fmonfile IN LOCAL MODE
      ENTITY FmonFile ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_files).
    DATA(lv_now) = zcl_ca_ops_factory=>get_clock( )->now( ).
    LOOP AT lt_files INTO DATA(ls_row).
      DATA(ls_key) = keys[ KEY id %tky = ls_row-%tky ].
      CLEAR ls_file.
      ls_file-file_id           = ls_row-FileId.
      ls_file-direction         = ls_row-Direction.
      ls_file-stage             = ls_row-Stage.
      ls_file-outcome           = ls_row-Outcome.
      ls_file-unprocessed_count = ls_row-UnprocessedCount.
      DATA(ls_decision) = zcl_cd_fmon_ops_policy=>check_manual( iv_stage  = ls_key-%param-Stage
                                                                iv_reason = ls_key-%param-Reason
                                                                is_file   = ls_file ).
      IF ls_decision-allowed = abap_false.
        INSERT VALUE #( %tky = ls_row-%tky ) INTO TABLE failed-fmonfile.
        INSERT VALUE #( %tky = ls_row-%tky
                        %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = ls_decision-msgno
                                            severity = if_abap_behv_message=>severity-error
                                            v1 = ls_decision-v1 v2 = ls_row-FileName v3 = ls_row-Stage ) )
          INTO TABLE reported-fmonfile.
        CONTINUE.
      ENDIF.
      zcl_cd_fmon_status=>apply( EXPORTING iv_stage       = ls_key-%param-Stage
                                           iv_unprocessed = ls_row-UnprocessedCount
                                 CHANGING  cs_file        = ls_file ).
      MODIFY ENTITIES OF zr_cd_fmonfile IN LOCAL MODE
        ENTITY FmonFile
          UPDATE FIELDS ( Stage Outcome UnprocessedCount LastEventAt ChangedAt ChangedBy )
          WITH VALUE #( ( %tky             = ls_row-%tky
                          Stage            = ls_file-stage
                          Outcome          = ls_file-outcome
                          UnprocessedCount = ls_file-unprocessed_count
                          LastEventAt      = lv_now
                          ChangedAt        = lv_now
                          ChangedBy        = sy-uname ) ).
      INSERT VALUE #( file_id  = ls_row-FileId
                      stage    = ls_key-%param-Stage
                      reason   = ls_key-%param-Reason
                      evidence = ls_key-%param-Evidence ) INTO TABLE lcl_buffer=>gt_manual.
    ENDLOOP.
    READ ENTITIES OF zr_cd_fmonfile IN LOCAL MODE
      ENTITY FmonFile ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = ls_res ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lsc_fmonfile DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.


CLASS lsc_fmonfile IMPLEMENTATION.

  METHOD save_modified.
    " One event per manual change - the audit trail of the file (source MANUAL)
    DATA ls_event TYPE zif_cd_fmon_types=>ty_event.
    DATA(lo_dao) = zcl_cd_fmon_factory=>get_dao( ).
    DATA(lv_now) = zcl_ca_ops_factory=>get_clock( )->now( ).
    LOOP AT lcl_buffer=>gt_manual ASSIGNING FIELD-SYMBOL(<ls_manual>).
      CLEAR ls_event.
      ls_event-file_id    = <ls_manual>-file_id.
      ls_event-stage      = <ls_manual>-stage.
      ls_event-event_at   = lv_now.
      ls_event-src_id     = zif_cd_fmon_types=>gc_manual_src_id.
      ls_event-src_key    = <ls_manual>-evidence.
      ls_event-info       = <ls_manual>-reason.
      ls_event-created_by = sy-uname.
      ls_event-created_at = lv_now.
      TRY.
          lo_dao->insert_event( ls_event ).
        CATCH zcx_ca_ops_error INTO DATA(lx_error).
          " the file must never change without its audit event
          RAISE SHORTDUMP lx_error.
        CATCH cx_sy_open_sql_db INTO DATA(lx_sql).
          " Audit A05: a technical database error ends the save the same way
          RAISE SHORTDUMP lx_sql.
      ENDTRY.
    ENDLOOP.
    CLEAR lcl_buffer=>gt_manual.
  ENDMETHOD.


  METHOD cleanup_finalize.
    CLEAR lcl_buffer=>gt_manual.
  ENDMETHOD.

ENDCLASS.
