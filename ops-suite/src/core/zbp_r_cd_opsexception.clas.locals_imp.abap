*&---------------------------------------------------------------------*
*& Artifact: zbp_r_cd_opsexception.clas.locals_imp.abap
*& Purpose:
*& Handler of the exceptions app: instance authorisation (ZCD_OPS 02 per
*& area, 85 to approve a waiver), action availability per disposition and
*& the four actions. Each action asks ZCL_CD_OPS_EXC_POLICY, updates the
*& exception and writes one history row. Thin: no rule is decided here.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! Content IDs of the history rows created by each action (one per action)
INTERFACE lif_c.
  CONSTANTS:
    BEGIN OF gc_cid,
      assign    TYPE abp_behv_cid VALUE 'ASSIGN',
      resolve   TYPE abp_behv_cid VALUE 'RESOLVE',
      waive_req TYPE abp_behv_cid VALUE 'WAIVE_REQ',
      waive_ok  TYPE abp_behv_cid VALUE 'WAIVE_OK',
    END OF gc_cid.
ENDINTERFACE.


CLASS lhc_exception DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Exception RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Exception RESULT result.

    METHODS assignowner FOR MODIFY
      IMPORTING keys FOR ACTION Exception~assignOwner RESULT result.

    METHODS resolveexception FOR MODIFY
      IMPORTING keys FOR ACTION Exception~resolveException RESULT result.

    METHODS requestwaiver FOR MODIFY
      IMPORTING keys FOR ACTION Exception~requestWaiver RESULT result.

    METHODS approvewaiver FOR MODIFY
      IMPORTING keys FOR ACTION Exception~approveWaiver RESULT result.

    "! Allowed (enabled) or not (disabled) as a feature-control value
    METHODS fc
      IMPORTING
        iv_on        TYPE abap_bool
      RETURNING
        VALUE(rv_fc) TYPE if_abap_behv=>t_xflag.
ENDCLASS.


CLASS lhc_exception IMPLEMENTATION.

  METHOD get_instance_authorizations.
    DATA(lo_auth) = zcl_cd_ops_factory=>get_auth( ).
    READ ENTITIES OF zr_cd_opsexception IN LOCAL MODE
      ENTITY Exception
        FIELDS ( PaymentEngineArea ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exceptions).
    LOOP AT lt_exceptions ASSIGNING FIELD-SYMBOL(<ls_exception>).
      DATA(lv_change) = COND #( WHEN lo_auth->is_allowed( iv_activity = zif_cd_ops_auth=>gc_activity-change
                                                         iv_pe_area   = <ls_exception>-PaymentEngineArea ) = abap_true
                                THEN if_abap_behv=>auth-allowed
                                ELSE if_abap_behv=>auth-unauthorized ).
      DATA(lv_approve) = COND #( WHEN lo_auth->is_allowed( iv_activity = zif_cd_ops_auth=>gc_activity-approve
                                                          iv_pe_area   = <ls_exception>-PaymentEngineArea ) = abap_true
                                 THEN if_abap_behv=>auth-allowed
                                 ELSE if_abap_behv=>auth-unauthorized ).
      " answer only what the framework asked for
      INSERT VALUE #( %tky                     = <ls_exception>-%tky
                      %action-assignOwner      = COND #( WHEN requested_authorizations-%action-assignOwner = if_abap_behv=>mk-on
                                                         THEN lv_change )
                      %action-resolveException = COND #( WHEN requested_authorizations-%action-resolveException = if_abap_behv=>mk-on
                                                         THEN lv_change )
                      %action-requestWaiver    = COND #( WHEN requested_authorizations-%action-requestWaiver = if_abap_behv=>mk-on
                                                         THEN lv_change )
                      %action-approveWaiver    = COND #( WHEN requested_authorizations-%action-approveWaiver = if_abap_behv=>mk-on
                                                         THEN lv_approve ) ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_instance_features.
    READ ENTITIES OF zr_cd_opsexception IN LOCAL MODE
      ENTITY Exception
        FIELDS ( Disposition WaiverReqBy ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exceptions).
    LOOP AT lt_exceptions INTO DATA(ls_exception).
      DATA(lv_open) = zcl_cd_ops_exc_policy=>is_open( ls_exception-Disposition ).
      INSERT VALUE #( %tky = ls_exception-%tky ) INTO TABLE result ASSIGNING FIELD-SYMBOL(<ls_result>).
      IF requested_features-%action-assignOwner = if_abap_behv=>mk-on.
        <ls_result>-%action-assignOwner = fc( lv_open ).
      ENDIF.
      IF requested_features-%action-resolveException = if_abap_behv=>mk-on.
        <ls_result>-%action-resolveException = fc( lv_open ).
      ENDIF.
      IF requested_features-%action-requestWaiver = if_abap_behv=>mk-on.
        <ls_result>-%action-requestWaiver = fc( xsdbool( lv_open = abap_true AND ls_exception-WaiverReqBy IS INITIAL ) ).
      ENDIF.
      " four-eyes: the requester never sees an enabled Approve button
      IF requested_features-%action-approveWaiver = if_abap_behv=>mk-on.
        <ls_result>-%action-approveWaiver = fc( xsdbool( lv_open = abap_true
                                                         AND ls_exception-WaiverReqBy IS NOT INITIAL
                                                         AND ls_exception-WaiverReqBy <> sy-uname ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD assignowner.
    READ ENTITIES OF zr_cd_opsexception IN LOCAL MODE
      ENTITY Exception ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exceptions).
    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).
    LOOP AT lt_exceptions INTO DATA(ls_exception).
      DATA(ls_key) = keys[ KEY id %tky = ls_exception-%tky ].
      DATA(ls_decision) = zcl_cd_ops_exc_policy=>can_assign(
                            is_state = VALUE #( disposition   = ls_exception-Disposition
                                                waiver_req_by = ls_exception-WaiverReqBy )
                            iv_owner = ls_key-%param-Owner ).
      IF ls_decision-allowed = abap_false.
        INSERT VALUE #( %tky = ls_exception-%tky ) INTO TABLE failed-exception.
        INSERT VALUE #( %tky = ls_exception-%tky
                        %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = ls_decision-msgno
                                            severity = if_abap_behv_message=>severity-error v1 = ls_decision-v1 ) )
          INTO TABLE reported-exception.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_cd_opsexception IN LOCAL MODE
        ENTITY Exception
          UPDATE FIELDS ( Owner Disposition )
          WITH VALUE #( ( %tky        = ls_exception-%tky
                          Owner       = ls_key-%param-Owner
                          Disposition = zif_cd_ops_types=>gc_disposition-assigned ) )
        ENTITY Exception
          CREATE BY \_History
          FIELDS ( HistAction FromDisp ToDisp Owner CreatedBy CreatedAt )
          WITH VALUE #( ( %tky    = ls_exception-%tky
                          %target = VALUE #( ( %cid       = lif_c=>gc_cid-assign
                                               HistAction = zif_cd_ops_exc_types=>gc_action-assign
                                               FromDisp   = ls_exception-Disposition
                                               ToDisp     = zif_cd_ops_types=>gc_disposition-assigned
                                               Owner      = ls_key-%param-Owner
                                               CreatedBy  = sy-uname
                                               CreatedAt  = lv_now ) ) ) ).
    ENDLOOP.
    READ ENTITIES OF zr_cd_opsexception IN LOCAL MODE
      ENTITY Exception ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_row IN lt_result ( %tky = ls_row-%tky %param = ls_row ) ).
  ENDMETHOD.


  METHOD resolveexception.
    READ ENTITIES OF zr_cd_opsexception IN LOCAL MODE
      ENTITY Exception ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exceptions).
    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).
    LOOP AT lt_exceptions INTO DATA(ls_exception).
      DATA(ls_key) = keys[ KEY id %tky = ls_exception-%tky ].
      DATA(ls_decision) = zcl_cd_ops_exc_policy=>can_resolve(
                            is_state  = VALUE #( disposition   = ls_exception-Disposition
                                                 waiver_req_by = ls_exception-WaiverReqBy )
                            iv_reason = ls_key-%param-Reason ).
      IF ls_decision-allowed = abap_false.
        INSERT VALUE #( %tky = ls_exception-%tky ) INTO TABLE failed-exception.
        INSERT VALUE #( %tky = ls_exception-%tky
                        %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = ls_decision-msgno
                                            severity = if_abap_behv_message=>severity-error v1 = ls_decision-v1 ) )
          INTO TABLE reported-exception.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_cd_opsexception IN LOCAL MODE
        ENTITY Exception
          UPDATE FIELDS ( Disposition ResolvedBy ResolvedAt Resolution )
          WITH VALUE #( ( %tky        = ls_exception-%tky
                          Disposition = zif_cd_ops_types=>gc_disposition-resolved
                          ResolvedBy  = sy-uname
                          ResolvedAt  = lv_now
                          Resolution  = ls_key-%param-Reason ) )
        ENTITY Exception
          CREATE BY \_History
          FIELDS ( HistAction FromDisp ToDisp Owner Reason CreatedBy CreatedAt )
          WITH VALUE #( ( %tky    = ls_exception-%tky
                          %target = VALUE #( ( %cid       = lif_c=>gc_cid-resolve
                                               HistAction = zif_cd_ops_exc_types=>gc_action-resolve
                                               FromDisp   = ls_exception-Disposition
                                               ToDisp     = zif_cd_ops_types=>gc_disposition-resolved
                                               Owner      = ls_exception-Owner
                                               Reason     = ls_key-%param-Reason
                                               CreatedBy  = sy-uname
                                               CreatedAt  = lv_now ) ) ) ).
    ENDLOOP.
    READ ENTITIES OF zr_cd_opsexception IN LOCAL MODE
      ENTITY Exception ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_row IN lt_result ( %tky = ls_row-%tky %param = ls_row ) ).
  ENDMETHOD.


  METHOD requestwaiver.
    READ ENTITIES OF zr_cd_opsexception IN LOCAL MODE
      ENTITY Exception ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exceptions).
    DATA(lo_clock) = zcl_cd_ops_factory=>get_clock( ).
    DATA(lv_now) = lo_clock->now( ).
    LOOP AT lt_exceptions INTO DATA(ls_exception).
      DATA(ls_key) = keys[ KEY id %tky = ls_exception-%tky ].
      DATA(ls_decision) = zcl_cd_ops_exc_policy=>can_request_waiver(
                            is_state    = VALUE #( disposition   = ls_exception-Disposition
                                                   waiver_req_by = ls_exception-WaiverReqBy )
                            iv_reason   = ls_key-%param-Reason
                            iv_valid_to = ls_key-%param-ValidTo
                            iv_today    = lo_clock->today( ) ).
      IF ls_decision-allowed = abap_false.
        INSERT VALUE #( %tky = ls_exception-%tky ) INTO TABLE failed-exception.
        INSERT VALUE #( %tky = ls_exception-%tky
                        %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = ls_decision-msgno
                                            severity = if_abap_behv_message=>severity-error v1 = ls_decision-v1 ) )
          INTO TABLE reported-exception.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_cd_opsexception IN LOCAL MODE
        ENTITY Exception
          UPDATE FIELDS ( WaiverReqBy WaiverReqAt WaiverReason WaiverUntil )
          WITH VALUE #( ( %tky         = ls_exception-%tky
                          WaiverReqBy  = sy-uname
                          WaiverReqAt  = lv_now
                          WaiverReason = ls_key-%param-Reason
                          WaiverUntil  = ls_key-%param-ValidTo ) )
        ENTITY Exception
          CREATE BY \_History
          FIELDS ( HistAction FromDisp ToDisp Owner Reason CreatedBy CreatedAt )
          WITH VALUE #( ( %tky    = ls_exception-%tky
                          %target = VALUE #( ( %cid       = lif_c=>gc_cid-waive_req
                                               HistAction = zif_cd_ops_exc_types=>gc_action-waive_req
                                               FromDisp   = ls_exception-Disposition
                                               ToDisp     = ls_exception-Disposition
                                               Owner      = ls_exception-Owner
                                               Reason     = ls_key-%param-Reason
                                               CreatedBy  = sy-uname
                                               CreatedAt  = lv_now ) ) ) ).
    ENDLOOP.
    READ ENTITIES OF zr_cd_opsexception IN LOCAL MODE
      ENTITY Exception ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_row IN lt_result ( %tky = ls_row-%tky %param = ls_row ) ).
  ENDMETHOD.


  METHOD approvewaiver.
    READ ENTITIES OF zr_cd_opsexception IN LOCAL MODE
      ENTITY Exception ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_exceptions).
    DATA(lv_now) = zcl_cd_ops_factory=>get_clock( )->now( ).
    LOOP AT lt_exceptions INTO DATA(ls_exception).
      DATA(ls_decision) = zcl_cd_ops_exc_policy=>can_approve_waiver(
                            is_state    = VALUE #( disposition   = ls_exception-Disposition
                                                   waiver_req_by = ls_exception-WaiverReqBy )
                            iv_approver = sy-uname ).
      IF ls_decision-allowed = abap_false.
        INSERT VALUE #( %tky = ls_exception-%tky ) INTO TABLE failed-exception.
        INSERT VALUE #( %tky = ls_exception-%tky
                        %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = ls_decision-msgno
                                            severity = if_abap_behv_message=>severity-error v1 = ls_decision-v1 ) )
          INTO TABLE reported-exception.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_cd_opsexception IN LOCAL MODE
        ENTITY Exception
          UPDATE FIELDS ( Disposition ResolvedBy ResolvedAt Resolution )
          WITH VALUE #( ( %tky        = ls_exception-%tky
                          Disposition = zif_cd_ops_types=>gc_disposition-waived
                          ResolvedBy  = sy-uname
                          ResolvedAt  = lv_now
                          Resolution  = ls_exception-WaiverReason ) )
        ENTITY Exception
          CREATE BY \_History
          FIELDS ( HistAction FromDisp ToDisp Owner Reason CreatedBy CreatedAt )
          WITH VALUE #( ( %tky    = ls_exception-%tky
                          %target = VALUE #( ( %cid       = lif_c=>gc_cid-waive_ok
                                               HistAction = zif_cd_ops_exc_types=>gc_action-waive_ok
                                               FromDisp   = ls_exception-Disposition
                                               ToDisp     = zif_cd_ops_types=>gc_disposition-waived
                                               Owner      = ls_exception-Owner
                                               Reason     = ls_exception-WaiverReason
                                               CreatedBy  = sy-uname
                                               CreatedAt  = lv_now ) ) ) ).
    ENDLOOP.
    READ ENTITIES OF zr_cd_opsexception IN LOCAL MODE
      ENTITY Exception ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_row IN lt_result ( %tky = ls_row-%tky %param = ls_row ) ).
  ENDMETHOD.


  METHOD fc.
    rv_fc = COND #( WHEN iv_on = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.

ENDCLASS.
