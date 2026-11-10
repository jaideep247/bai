*&---------------------------------------------------------------------*
*& Artifact: zbp_r_cd_hcksuppress.clas.locals_imp.abap
*& Purpose:
*& Handler of the suppression app: ZCD_OPS 02 (HCK) to create and end, 85 to
*& approve; status A at once or R for periods longer than
*& HCK_SUPPRESS_MAX_DAYS; request and four-eyes checks from
*& ZCL_CD_HCK_SUPPRESSION.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*& 2026-11-06 | Modern-syntax sweep: INSERT INTO TABLE.
*& 2026-11-06 | validateRequest: the key pattern must be valid PCRE (message 418, field KeyPattern).
*& 2026-11-10 | Company-code isolation: create (validation), end and approve of a suppression of a company code need
*&            | ZCA_OPS with that BUKRS (ZCL_CD_HCK_SUPPRESSION=>CHECK_COMPANY_CODE, message 840).
*&---------------------------------------------------------------------*
CLASS lhc_suppression DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Suppression RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Suppression RESULT result.

    METHODS setstatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Suppression~setStatus.

    METHODS validaterequest FOR VALIDATE ON SAVE
      IMPORTING keys FOR Suppression~validateRequest.

    METHODS approvesuppression FOR MODIFY
      IMPORTING keys FOR ACTION Suppression~approveSuppression RESULT result.

    METHODS endsuppression FOR MODIFY
      IMPORTING keys FOR ACTION Suppression~endSuppression RESULT result.

    METHODS auth
      IMPORTING
        iv_activity    TYPE zif_ca_ops_auth=>ty_activity
      RETURNING
        VALUE(rv_auth) TYPE if_abap_behv=>t_xflag.
ENDCLASS.


CLASS lhc_suppression IMPLEMENTATION.

  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = auth( zif_ca_ops_auth=>gc_activity-change ).
    ENDIF.
    IF requested_authorizations-%action-endSuppression = if_abap_behv=>mk-on.
      result-%action-endSuppression = auth( zif_ca_ops_auth=>gc_activity-change ).
    ENDIF.
    IF requested_authorizations-%action-approveSuppression = if_abap_behv=>mk-on.
      result-%action-approveSuppression = auth( zif_ca_ops_auth=>gc_activity-approve ).
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_features.
    READ ENTITIES OF zr_cd_hcksuppress IN LOCAL MODE
      ENTITY Suppression FIELDS ( Status CreatedBy ValidTo ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rows).
    DATA(lv_today) = zcl_ca_ops_factory=>get_clock( )->today( ).
    LOOP AT lt_rows INTO DATA(ls_row).
      INSERT VALUE #( %tky = ls_row-%tky ) INTO TABLE result ASSIGNING FIELD-SYMBOL(<ls_result>).
      " four-eyes: the creator never sees an enabled Approve button
      IF requested_features-%action-approveSuppression = if_abap_behv=>mk-on.
        <ls_result>-%action-approveSuppression =
          COND #( WHEN ls_row-Status = zif_cd_hck_suppress_types=>gc_status-requested AND ls_row-CreatedBy <> sy-uname
                  THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).
      ENDIF.
      IF requested_features-%action-endSuppression = if_abap_behv=>mk-on.
        <ls_result>-%action-endSuppression = COND #( WHEN ls_row-ValidTo >= lv_today
                                                     THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD setstatus.
    READ ENTITIES OF zr_cd_hcksuppress IN LOCAL MODE
      ENTITY Suppression FIELDS ( ValidFrom ValidTo ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rows).
    DATA(lv_max_days) = zcl_cd_hck_param=>int(
                          iv_value   = zcl_cd_ops_factory=>get_params( )->get_param(
                                         iv_name    = zif_cd_hck_suppress_types=>gc_param_max_days
                                         iv_default = |{ zif_cd_hck_suppress_types=>gc_default_max_days }| )
                          iv_default = zif_cd_hck_suppress_types=>gc_default_max_days ).
    DATA(lv_now) = zcl_ca_ops_factory=>get_clock( )->now( ).
    MODIFY ENTITIES OF zr_cd_hcksuppress IN LOCAL MODE
      ENTITY Suppression
        UPDATE FIELDS ( Status CreatedBy CreatedAt )
        WITH VALUE #( FOR ls_row IN lt_rows
                      ( %tky      = ls_row-%tky
                        Status    = COND #( WHEN zcl_cd_hck_suppression=>needs_approval(
                                                   iv_from     = ls_row-ValidFrom
                                                   iv_to       = ls_row-ValidTo
                                                   iv_max_days = lv_max_days ) = abap_true
                                            THEN zif_cd_hck_suppress_types=>gc_status-requested
                                            ELSE zif_cd_hck_suppress_types=>gc_status-active )
                        CreatedBy = sy-uname
                        CreatedAt = lv_now ) ).
  ENDMETHOD.


  METHOD validaterequest.
    READ ENTITIES OF zr_cd_hcksuppress IN LOCAL MODE
      ENTITY Suppression FIELDS ( CheckId Reason ValidFrom ValidTo KeyPattern CompanyCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rows).
    DATA(lo_auth) = zcl_ca_ops_factory=>get_auth( ).
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(ls_decision) = zcl_cd_hck_suppression=>check_request( iv_check_id = <ls_row>-CheckId
                                                                 iv_reason   = <ls_row>-Reason
                                                                 iv_from     = <ls_row>-ValidFrom
                                                                 iv_to       = <ls_row>-ValidTo
                                                                 iv_key_pattern = <ls_row>-KeyPattern ).
      " company-code isolation: a suppression of a company code needs ZCA_OPS 02 with that BUKRS
      IF ls_decision-allowed = abap_true.
        ls_decision = zcl_cd_hck_suppression=>check_company_code( io_auth     = lo_auth
                                                                  iv_activity = zif_ca_ops_auth=>gc_activity-change
                                                                  iv_bukrs    = <ls_row>-CompanyCode ).
      ENDIF.
      IF ls_decision-allowed = abap_false.
        INSERT VALUE #( %tky = <ls_row>-%tky ) INTO TABLE failed-suppression.
        INSERT VALUE #( %tky = <ls_row>-%tky
                        %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = ls_decision-msgno
                                            severity = if_abap_behv_message=>severity-error
                                            v1 = COND #( WHEN ls_decision-v1 IS NOT INITIAL THEN ls_decision-v1
                                                         ELSE |{ <ls_row>-ValidFrom DATE = ISO }| )
                                            v2 = |{ <ls_row>-ValidTo DATE = ISO }| ) )
          INTO TABLE reported-suppression.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD approvesuppression.
    READ ENTITIES OF zr_cd_hcksuppress IN LOCAL MODE
      ENTITY Suppression ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rows).
    DATA(lv_now) = zcl_ca_ops_factory=>get_clock( )->now( ).
    DATA(lo_auth) = zcl_ca_ops_factory=>get_auth( ).
    LOOP AT lt_rows INTO DATA(ls_row).
      DATA(ls_decision) = zcl_cd_hck_suppression=>can_approve( iv_status     = ls_row-Status
                                                               iv_created_by = ls_row-CreatedBy
                                                               iv_approver   = sy-uname ).
      " company-code isolation: the approver needs ZCA_OPS 85 with the suppression's BUKRS
      IF ls_decision-allowed = abap_true.
        ls_decision = zcl_cd_hck_suppression=>check_company_code( io_auth     = lo_auth
                                                                  iv_activity = zif_ca_ops_auth=>gc_activity-approve
                                                                  iv_bukrs    = ls_row-CompanyCode ).
      ENDIF.
      IF ls_decision-allowed = abap_false.
        INSERT VALUE #( %tky = ls_row-%tky ) INTO TABLE failed-suppression.
        INSERT VALUE #( %tky = ls_row-%tky
                        %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = ls_decision-msgno
                                            severity = if_abap_behv_message=>severity-error v1 = ls_decision-v1 ) )
          INTO TABLE reported-suppression.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_cd_hcksuppress IN LOCAL MODE
        ENTITY Suppression
          UPDATE FIELDS ( Status ApprovedBy ApprovedAt )
          WITH VALUE #( ( %tky       = ls_row-%tky
                          Status     = zif_cd_hck_suppress_types=>gc_status-active
                          ApprovedBy = sy-uname
                          ApprovedAt = lv_now ) ).
    ENDLOOP.
    READ ENTITIES OF zr_cd_hcksuppress IN LOCAL MODE
      ENTITY Suppression ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = ls_res ) ).
  ENDMETHOD.


  METHOD endsuppression.
    " The suppression ends yesterday: from the next morning report on the findings count again
    READ ENTITIES OF zr_cd_hcksuppress IN LOCAL MODE
      ENTITY Suppression FIELDS ( ValidFrom CompanyCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_rows).
    DATA(lv_yesterday) = CONV d( zcl_ca_ops_factory=>get_clock( )->today( ) - 1 ).
    DATA(lo_auth) = zcl_ca_ops_factory=>get_auth( ).
    " company-code isolation: ending a suppression of a company code needs ZCA_OPS 02 with that BUKRS
    DATA(lt_ending) = lt_rows.
    CLEAR lt_ending.
    LOOP AT lt_rows ASSIGNING FIELD-SYMBOL(<ls_end>).
      DATA(ls_decision) = zcl_cd_hck_suppression=>check_company_code( io_auth     = lo_auth
                                                                      iv_activity = zif_ca_ops_auth=>gc_activity-change
                                                                      iv_bukrs    = <ls_end>-CompanyCode ).
      IF ls_decision-allowed = abap_true.
        INSERT <ls_end> INTO TABLE lt_ending.
      ELSE.
        INSERT VALUE #( %tky = <ls_end>-%tky ) INTO TABLE failed-suppression.
        INSERT VALUE #( %tky = <ls_end>-%tky
                        %msg = new_message( id = zif_cd_ops_types=>gc_message_class number = ls_decision-msgno
                                            severity = if_abap_behv_message=>severity-error v1 = ls_decision-v1 ) )
          INTO TABLE reported-suppression.
      ENDIF.
    ENDLOOP.
    MODIFY ENTITIES OF zr_cd_hcksuppress IN LOCAL MODE
      ENTITY Suppression
        UPDATE FIELDS ( ValidFrom ValidTo )
        WITH VALUE #( FOR ls_row IN lt_ending
                      ( %tky      = ls_row-%tky
                        ValidFrom = COND #( WHEN ls_row-ValidFrom > lv_yesterday THEN lv_yesterday ELSE ls_row-ValidFrom )
                        ValidTo   = lv_yesterday ) ).
    READ ENTITIES OF zr_cd_hcksuppress IN LOCAL MODE
      ENTITY Suppression ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_res IN lt_result ( %tky = ls_res-%tky %param = ls_res ) ).
  ENDMETHOD.


  METHOD auth.
    rv_auth = COND #( WHEN zcl_ca_ops_factory=>get_auth( )->is_allowed(
                             iv_activity = iv_activity
                             iv_area   = zif_cd_ops_types=>gc_pe_area-health_check ) = abap_true
                      THEN if_abap_behv=>auth-allowed
                      ELSE if_abap_behv=>auth-unauthorized ).
  ENDMETHOD.

ENDCLASS.
