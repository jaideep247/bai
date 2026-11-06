*&---------------------------------------------------------------------*
*& Artifact: zbp_r_cd_ebsrelease.clas.locals_imp.abap
*& Purpose:
*& Handler and saver of the blocked-line release app: ZCD_OPS 43 to request,
*& 85 to approve / reject (EBS); request stamped with user and time; request
*& and four-eyes checks from ZCL_CD_EBS_RELEASE_POLICY; on approval the open
*& exception of the line and check code is resolved (additional save).
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
CLASS lhc_release DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Release RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Release RESULT result.

    METHODS setrequested FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Release~setRequested.

    METHODS validaterequest FOR VALIDATE ON SAVE
      IMPORTING keys FOR Release~validateRequest.

    METHODS approverelease FOR MODIFY
      IMPORTING keys FOR ACTION Release~approveRelease RESULT result.

    METHODS rejectrelease FOR MODIFY
      IMPORTING keys FOR ACTION Release~rejectRelease RESULT result.

    "! ZCD_OPS for EBS with an activity, as RAP authorisation value
    METHODS auth
      IMPORTING
        iv_activity    TYPE zif_cd_ops_auth=>ty_activity
      RETURNING
        VALUE(rv_auth) TYPE if_abap_behv=>t_xflag.
ENDCLASS.


CLASS lhc_release IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = auth( zif_cd_ops_auth=>gc_activity-release ).
    ENDIF.
    IF requested_authorizations-%action-approveRelease = if_abap_behv=>mk-on.
      result-%action-approveRelease = auth( zif_cd_ops_auth=>gc_activity-approve ).
    ENDIF.
    IF requested_authorizations-%action-rejectRelease = if_abap_behv=>mk-on.
      result-%action-rejectRelease = auth( zif_cd_ops_auth=>gc_activity-approve ).
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_features.
    READ ENTITIES OF zr_cd_ebsrelease IN LOCAL MODE
      ENTITY Release FIELDS ( Status RequestedBy ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_releases).
    LOOP AT lt_releases INTO DATA(ls_release).
      DATA(lv_open) = xsdbool( ls_release-Status = zif_cd_ebs_release_types=>gc_status-requested ).
      APPEND VALUE #( %tky = ls_release-%tky ) TO result ASSIGNING FIELD-SYMBOL(<ls_result>).
      " four-eyes: the requester never sees an enabled Approve button
      IF requested_features-%action-approveRelease = if_abap_behv=>mk-on.
        <ls_result>-%action-approveRelease = COND #( WHEN lv_open = abap_true AND ls_release-RequestedBy <> sy-uname
                                                     THEN if_abap_behv=>fc-o-enabled
                                                     ELSE if_abap_behv=>fc-o-disabled ).
      ENDIF.
      IF requested_features-%action-rejectRelease = if_abap_behv=>mk-on.
        <ls_result>-%action-rejectRelease = COND #( WHEN lv_open = abap_true
                                                    THEN if_abap_behv=>fc-o-enabled
                                                    ELSE if_abap_behv=>fc-o-disabled ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD setrequested.
    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).
    MODIFY ENTITIES OF zr_cd_ebsrelease IN LOCAL MODE
      ENTITY Release
        UPDATE FIELDS ( Status RequestedBy RequestedAt )
        WITH VALUE #( FOR ls_key IN keys ( %tky        = ls_key-%tky
                                           Status      = zif_cd_ebs_release_types=>gc_status-requested
                                           RequestedBy = sy-uname
                                           RequestedAt = lv_now ) ).
  ENDMETHOD.


  METHOD validaterequest.
    READ ENTITIES OF zr_cd_ebsrelease IN LOCAL MODE
      ENTITY Release FIELDS ( ObjectKey CheckCode Reason ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_releases).
    LOOP AT lt_releases ASSIGNING FIELD-SYMBOL(<ls_release>).
      DATA(ls_decision) = zcl_cd_ebs_release_policy=>check_request( iv_object_key = <ls_release>-ObjectKey
                                                                    iv_check_code = <ls_release>-CheckCode
                                                                    iv_reason     = <ls_release>-Reason ).
      IF ls_decision-allowed = abap_false.
        APPEND VALUE #( %tky = <ls_release>-%tky ) TO failed-release.
        APPEND VALUE #( %tky = <ls_release>-%tky
                        %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = ls_decision-msgno
                                            severity = if_abap_behv_message=>severity-error v1 = ls_decision-v1 ) )
          TO reported-release.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD approverelease.
    READ ENTITIES OF zr_cd_ebsrelease IN LOCAL MODE
      ENTITY Release ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_releases).
    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).
    LOOP AT lt_releases INTO DATA(ls_release).
      DATA(ls_decision) = zcl_cd_ebs_release_policy=>can_approve( iv_status       = ls_release-Status
                                                                  iv_requested_by = ls_release-RequestedBy
                                                                  iv_approver     = sy-uname ).
      IF ls_decision-allowed = abap_false.
        APPEND VALUE #( %tky = ls_release-%tky ) TO failed-release.
        APPEND VALUE #( %tky = ls_release-%tky
                        %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = ls_decision-msgno
                                            severity = if_abap_behv_message=>severity-error v1 = ls_decision-v1 ) )
          TO reported-release.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_cd_ebsrelease IN LOCAL MODE
        ENTITY Release
          UPDATE FIELDS ( Status ApprovedBy ApprovedAt )
          WITH VALUE #( ( %tky       = ls_release-%tky
                          Status     = zif_cd_ebs_release_types=>gc_status-approved
                          ApprovedBy = sy-uname
                          ApprovedAt = lv_now ) ).
    ENDLOOP.
    READ ENTITIES OF zr_cd_ebsrelease IN LOCAL MODE
      ENTITY Release ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_row IN lt_result ( %tky = ls_row-%tky %param = ls_row ) ).
  ENDMETHOD.


  METHOD rejectrelease.
    READ ENTITIES OF zr_cd_ebsrelease IN LOCAL MODE
      ENTITY Release FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_releases).
    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).
    LOOP AT lt_releases INTO DATA(ls_release).
      IF ls_release-Status <> zif_cd_ebs_release_types=>gc_status-requested.
        APPEND VALUE #( %tky = ls_release-%tky ) TO failed-release.
        APPEND VALUE #( %tky = ls_release-%tky
                        %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = zif_cd_ebs_release_types=>gc_msg-not_requested
                                            severity = if_abap_behv_message=>severity-error v1 = ls_release-Status ) )
          TO reported-release.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_cd_ebsrelease IN LOCAL MODE
        ENTITY Release
          UPDATE FIELDS ( Status ApprovedBy ApprovedAt )
          WITH VALUE #( ( %tky       = ls_release-%tky
                          Status     = zif_cd_ebs_release_types=>gc_status-rejected
                          ApprovedBy = sy-uname
                          ApprovedAt = lv_now ) ).
    ENDLOOP.
    READ ENTITIES OF zr_cd_ebsrelease IN LOCAL MODE
      ENTITY Release ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_row IN lt_result ( %tky = ls_row-%tky %param = ls_row ) ).
  ENDMETHOD.


  METHOD auth.
    rv_auth = COND #( WHEN zcl_cd_ops_factory=>get_auth( )->is_allowed(
                             iv_activity = iv_activity
                             iv_pe_area   = zif_cd_ops_types=>gc_pe_area-ebs ) = abap_true
                      THEN if_abap_behv=>auth-allowed
                      ELSE if_abap_behv=>auth-unauthorized ).
  ENDMETHOD.

ENDCLASS.


CLASS lsc_release DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.


CLASS lsc_release IMPLEMENTATION.

  METHOD save_modified.
    " Approved releases close the open exception of their line and check code.
    " VERIFY-ADT: READ ENTITIES of the own BO in save_modified (buffer read only).
    CHECK update-release IS NOT INITIAL.
    READ ENTITIES OF zr_cd_ebsrelease IN LOCAL MODE
      ENTITY Release ALL FIELDS WITH CORRESPONDING #( update-release )
      RESULT DATA(lt_releases).
    DATA(lo_exc_dao) = zcl_cd_ops_factory=>get_exc_dao( ).
    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).
    LOOP AT lt_releases ASSIGNING FIELD-SYMBOL(<ls_release>) WHERE Status = zif_cd_ebs_release_types=>gc_status-approved.
      TRY.
          lo_exc_dao->resolve( it_keys      = lo_exc_dao->find_open( iv_pe_area     = zif_cd_ops_types=>gc_pe_area-ebs
                                                                     iv_object_key = <ls_release>-ObjectKey
                                                                     iv_check_code = <ls_release>-CheckCode )
                               iv_action    = zif_cd_ops_exc_types=>gc_action-release
                               iv_reason    = <ls_release>-Reason
                               iv_reference = |{ <ls_release>-ReleaseUuid }|
                               iv_user      = <ls_release>-ApprovedBy
                               iv_at        = lv_now ).
        CATCH zcx_cd_ops_error INTO DATA(lx_error).
          " the release itself is saved; the exception stays open and is visible in the app
          APPEND VALUE #( %tky = <ls_release>-%tky
                          %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = zif_cd_ops_types=>gc_msgno_free
                                              severity = if_abap_behv_message=>severity-warning
                                              v1 = lx_error->get_text( ) ) ) TO reported-release.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
