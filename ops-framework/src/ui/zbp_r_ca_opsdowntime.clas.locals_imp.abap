*&---------------------------------------------------------------------*
*& Artifact: zbp_r_ca_opsdowntime.clas.locals_imp.abap
*& Purpose:
*& Handler of the downtime app: authorisation (plan 01 checked on save with
*& the area, change 02, delete 06, approve 85, End now 02 - ZCA_OPS of the
*& window's area), availability of change / delete / Approve / End now by the
*& derived status, the time zone of a new window (DOWNTIME_TIME_ZONE), the UTC
*& start and end, the checks on save and the two actions. Thin: every rule is
*& ZCL_CA_OPS_DOWNTIME_POLICY; the other windows of the area come from the
*& downtime API (ZCL_CA_OPS_FACTORY=>GET_DOWNTIME).
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: planned downtime).
*&---------------------------------------------------------------------*
CLASS lhc_downtime DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES tt_entities TYPE TABLE FOR READ RESULT zr_ca_opsdowntime\\Downtime.

    "! State areas of the checks on save: the messages of a check are cleared before it runs again
    CONSTANTS:
      BEGIN OF gc_state,
        area   TYPE string VALUE 'VALIDATE_AREA',
        window TYPE string VALUE 'VALIDATE_WINDOW',
      END OF gc_state.

    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Downtime RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Downtime RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Downtime RESULT result.

    METHODS approvewindow FOR MODIFY
      IMPORTING keys FOR ACTION Downtime~approveWindow RESULT result.

    METHODS endwindow FOR MODIFY
      IMPORTING keys FOR ACTION Downtime~endWindow RESULT result.

    METHODS settimezone FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Downtime~setTimeZone.

    METHODS setutc FOR DETERMINE ON SAVE
      IMPORTING keys FOR Downtime~setUtc.

    METHODS validatearea FOR VALIDATE ON SAVE
      IMPORTING keys FOR Downtime~validateArea.

    METHODS validatewindow FOR VALIDATE ON SAVE
      IMPORTING keys FOR Downtime~validateWindow.

    "! The window of an entity as the policy sees it (UTC from the local entry and the row's time zone)
    METHODS window_of
      IMPORTING
        is_entity        TYPE LINE OF tt_entities
      RETURNING
        VALUE(rs_window) TYPE zif_ca_ops_resp_types=>ty_window.

    "! Allowed (enabled) or not (disabled) as a feature-control value
    METHODS fc
      IMPORTING
        iv_on        TYPE abap_bool
      RETURNING
        VALUE(rv_fc) TYPE if_abap_behv=>t_xflag.

    "! Allowed or unauthorized: ZCA_OPS with the activity for the area of the window
    METHODS auth
      IMPORTING
        iv_activity    TYPE zif_ca_ops_auth=>ty_activity
        iv_area        TYPE zif_ca_ops_types=>ty_area
      RETURNING
        VALUE(rv_auth) TYPE if_abap_behv=>t_xflag.
ENDCLASS.


CLASS lhc_downtime IMPLEMENTATION.

  METHOD get_global_authorizations.
    " the area of a new window is known on save: validateArea checks ZCA_OPS 01 for it
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.


  METHOD get_instance_authorizations.
    READ ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
      ENTITY Downtime
        FIELDS ( Area ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_windows).
    LOOP AT lt_windows ASSIGNING FIELD-SYMBOL(<ls_window>).
      INSERT VALUE #( %tky = <ls_window>-%tky
                      %update = COND #( WHEN requested_authorizations-%update = if_abap_behv=>mk-on
                                        THEN auth( iv_activity = zif_ca_ops_auth=>gc_activity-change
                                                   iv_area     = <ls_window>-Area ) )
                      %delete = COND #( WHEN requested_authorizations-%delete = if_abap_behv=>mk-on
                                        THEN auth( iv_activity = zif_ca_ops_auth=>gc_activity-delete
                                                   iv_area     = <ls_window>-Area ) )
                      %action-approveWindow = COND #( WHEN requested_authorizations-%action-approveWindow = if_abap_behv=>mk-on
                                                      THEN auth( iv_activity = zif_ca_ops_auth=>gc_activity-approve
                                                                 iv_area     = <ls_window>-Area ) )
                      %action-endWindow = COND #( WHEN requested_authorizations-%action-endWindow = if_abap_behv=>mk-on
                                                  THEN auth( iv_activity = zif_ca_ops_auth=>gc_activity-change
                                                             iv_area     = <ls_window>-Area ) ) ) INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD get_instance_features.
    READ ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
      ENTITY Downtime ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_windows).
    DATA(lv_now) = zcl_ca_ops_factory=>get_clock( )->now( ).
    LOOP AT lt_windows ASSIGNING FIELD-SYMBOL(<ls_entity>).
      DATA(ls_window) = window_of( <ls_entity> ).
      DATA(lv_change) = fc( xsdbool( zcl_ca_ops_downtime_policy=>may_change( is_window = ls_window
                                                                              iv_now    = lv_now ) IS INITIAL ) ).
      " answer only what the framework asked for; four-eyes: the planner never sees an enabled Approve button
      INSERT VALUE #( %tky                  = <ls_entity>-%tky
                      %update               = COND #( WHEN requested_features-%update = if_abap_behv=>mk-on
                                                      THEN lv_change )
                      %delete               = COND #( WHEN requested_features-%delete = if_abap_behv=>mk-on
                                                      THEN lv_change )
                      %action-approveWindow = COND #( WHEN requested_features-%action-approveWindow = if_abap_behv=>mk-on
                                                      THEN fc( xsdbool( zcl_ca_ops_downtime_policy=>may_approve(
                                                                          is_window = ls_window
                                                                          iv_user   = sy-uname
                                                                          iv_now    = lv_now ) IS INITIAL ) ) )
                      %action-endWindow     = COND #( WHEN requested_features-%action-endWindow = if_abap_behv=>mk-on
                                                      THEN fc( xsdbool( zcl_ca_ops_downtime_policy=>may_end(
                                                                          is_window = ls_window
                                                                          iv_now    = lv_now ) IS INITIAL ) ) ) )
        INTO TABLE result.
    ENDLOOP.
  ENDMETHOD.


  METHOD approvewindow.
    READ ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
      ENTITY Downtime ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_windows).
    DATA(lv_now) = zcl_ca_ops_factory=>get_clock( )->now( ).
    LOOP AT lt_windows ASSIGNING FIELD-SYMBOL(<ls_entity>).
      DATA(lt_problems) = zcl_ca_ops_downtime_policy=>may_approve( is_window = window_of( <ls_entity> )
                                                                   iv_user   = sy-uname
                                                                   iv_now    = lv_now ).
      IF lt_problems IS NOT INITIAL.
        INSERT VALUE #( %tky = <ls_entity>-%tky ) INTO TABLE failed-downtime.
        LOOP AT lt_problems ASSIGNING FIELD-SYMBOL(<ls_problem>).
          INSERT VALUE #( %tky = <ls_entity>-%tky
                          %msg = new_message( id       = zif_ca_ops_types=>gc_message_class
                                              number   = <ls_problem>-msgno
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = <ls_problem>-v1
                                              v2       = <ls_problem>-v2 ) ) INTO TABLE reported-downtime.
        ENDLOOP.
        CONTINUE.
      ENDIF.
      MODIFY ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
        ENTITY Downtime
          UPDATE FIELDS ( ApprovedBy ApprovedAt )
          WITH VALUE #( ( %tky = <ls_entity>-%tky ApprovedBy = sy-uname ApprovedAt = lv_now ) ).
    ENDLOOP.
    READ ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
      ENTITY Downtime ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_row IN lt_result ( %tky = ls_row-%tky %param = ls_row ) ).
  ENDMETHOD.


  METHOD endwindow.
    READ ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
      ENTITY Downtime ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_windows).
    DATA(lv_now) = zcl_ca_ops_factory=>get_clock( )->now( ).
    DATA(lv_now_ts) = CONV timestamp( lv_now ).
    LOOP AT lt_windows ASSIGNING FIELD-SYMBOL(<ls_entity>).
      DATA(ls_window) = window_of( <ls_entity> ).
      DATA(lt_problems) = zcl_ca_ops_downtime_policy=>may_end( is_window = ls_window iv_now = lv_now ).
      IF lt_problems IS NOT INITIAL.
        INSERT VALUE #( %tky = <ls_entity>-%tky ) INTO TABLE failed-downtime.
        LOOP AT lt_problems ASSIGNING FIELD-SYMBOL(<ls_problem>).
          INSERT VALUE #( %tky = <ls_entity>-%tky
                          %msg = new_message( id       = zif_ca_ops_types=>gc_message_class
                                              number   = <ls_problem>-msgno
                                              severity = if_abap_behv_message=>severity-error
                                              v1       = <ls_problem>-v1
                                              v2       = <ls_problem>-v2 ) ) INTO TABLE reported-downtime.
        ENDLOOP.
        CONTINUE.
      ENDIF.
      " the end is now (local time of the window's zone); a window that had not started ends before it starts
      CONVERT TIME STAMP lv_now_ts TIME ZONE ls_window-time_zone INTO DATE DATA(lv_date) TIME DATA(lv_time).
      DATA(ls_update) = VALUE zif_ca_ops_resp_types=>ty_window( from_date = ls_window-from_date
                                                                from_time = ls_window-from_time
                                                                from_utc  = ls_window-from_utc ).
      IF ls_window-from_utc > lv_now.
        ls_update-from_date = lv_date.
        ls_update-from_time = lv_time.
        ls_update-from_utc  = lv_now.
      ENDIF.
      MODIFY ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
        ENTITY Downtime
          UPDATE FIELDS ( FromDate FromTime FromUtc ToDate ToTime ToUtc EndedBy )
          WITH VALUE #( ( %tky     = <ls_entity>-%tky
                          FromDate = ls_update-from_date
                          FromTime = ls_update-from_time
                          FromUtc  = ls_update-from_utc
                          ToDate   = lv_date
                          ToTime   = lv_time
                          ToUtc    = lv_now
                          EndedBy  = sy-uname ) ).
    ENDLOOP.
    READ ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
      ENTITY Downtime ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).
    result = VALUE #( FOR ls_row IN lt_result ( %tky = ls_row-%tky %param = ls_row ) ).
  ENDMETHOD.


  METHOD settimezone.
    READ ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
      ENTITY Downtime FIELDS ( TimeZone ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_windows).
    DELETE lt_windows WHERE TimeZone IS NOT INITIAL.
    IF lt_windows IS INITIAL.
      RETURN.
    ENDIF.
    " the zone the planner enters in; stored with the window, so the entry keeps its meaning
    DATA(lv_zone) = CONV tznzone( to_upper( zcl_ca_ops_factory=>get_params( )->get_param(
                                              iv_name    = zif_ca_ops_resp_types=>gc_param-downtime_time_zone
                                              iv_default = CONV #( zif_ca_ops_resp_types=>gc_param_default-downtime_time_zone ) ) ) ).
    MODIFY ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
      ENTITY Downtime
        UPDATE FIELDS ( TimeZone )
        WITH VALUE #( FOR ls_window IN lt_windows ( %tky = ls_window-%tky TimeZone = lv_zone ) ).
  ENDMETHOD.


  METHOD setutc.
    READ ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
      ENTITY Downtime ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_windows).
    MODIFY ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
      ENTITY Downtime
        UPDATE FIELDS ( FromUtc ToUtc )
        WITH VALUE #( FOR ls_entity IN lt_windows ( %tky    = ls_entity-%tky
                                                    FromUtc = window_of( ls_entity )-from_utc
                                                    ToUtc   = window_of( ls_entity )-to_utc ) ).
  ENDMETHOD.


  METHOD validatearea.
    READ ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
      ENTITY Downtime FIELDS ( Area ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_windows).
    LOOP AT lt_windows ASSIGNING FIELD-SYMBOL(<ls_entity>).
      INSERT VALUE #( %tky = <ls_entity>-%tky %state_area = gc_state-area ) INTO TABLE reported-downtime.
      IF zcl_ca_ops_cfg_checks=>area_valid( iv_area = <ls_entity>-Area iv_any_allowed = abap_false ) = abap_false.
        INSERT VALUE #( %tky = <ls_entity>-%tky ) INTO TABLE failed-downtime.
        INSERT VALUE #( %tky          = <ls_entity>-%tky
                        %state_area   = gc_state-area
                        %element-Area = if_abap_behv=>mk-on
                        %msg          = new_message( id       = zif_ca_ops_types=>gc_message_class
                                                     number   = zif_ca_ops_cfg_types=>gc_msg-area_invalid
                                                     severity = if_abap_behv_message=>severity-error
                                                     v1       = <ls_entity>-Area ) ) INTO TABLE reported-downtime.
      ELSEIF auth( iv_activity = zif_ca_ops_auth=>gc_activity-create
                   iv_area     = <ls_entity>-Area ) <> if_abap_behv=>auth-allowed.
        INSERT VALUE #( %tky = <ls_entity>-%tky ) INTO TABLE failed-downtime.
        INSERT VALUE #( %tky          = <ls_entity>-%tky
                        %state_area   = gc_state-area
                        %element-Area = if_abap_behv=>mk-on
                        %msg          = new_message( id       = zif_ca_ops_types=>gc_message_class
                                                     number   = zif_ca_ops_resp_types=>gc_msg-not_authorised
                                                     severity = if_abap_behv_message=>severity-error
                                                     v1       = <ls_entity>-Area
                                                     v2       = zif_ca_ops_auth=>gc_activity-create ) )
          INTO TABLE reported-downtime.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD validatewindow.
    READ ENTITIES OF zr_ca_opsdowntime IN LOCAL MODE
      ENTITY Downtime ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_windows).
    DATA(lo_params) = zcl_ca_ops_factory=>get_params( ).
    DATA(ls_limits) = VALUE zif_ca_ops_resp_types=>ty_window_limits(
      now           = zcl_ca_ops_factory=>get_clock( )->now( )
      max_hours     = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                  iv_name    = zif_ca_ops_resp_types=>gc_param-downtime_max_hours
                                                  iv_default = zif_ca_ops_resp_types=>gc_param_default-downtime_max_hours )
      tolerance_min = zcl_ca_ops_util=>param_int( io_params  = lo_params
                                                  iv_name    = zif_ca_ops_resp_types=>gc_param-downtime_past_tol
                                                  iv_default = zif_ca_ops_resp_types=>gc_param_default-downtime_past_tol ) ).
    DATA(lo_downtime) = zcl_ca_ops_factory=>get_downtime( ).
    LOOP AT lt_windows ASSIGNING FIELD-SYMBOL(<ls_entity>).
      INSERT VALUE #( %tky = <ls_entity>-%tky %state_area = gc_state-window ) INTO TABLE reported-downtime.
      DATA(ls_window) = window_of( <ls_entity> ).
      " the other windows of the area around this one, approved or not (duplicates)
      DATA(lt_others) = COND zif_ca_ops_resp_types=>tt_window(
        WHEN ls_window-from_utc IS NOT INITIAL AND ls_window-to_utc IS NOT INITIAL
        THEN lo_downtime->windows( iv_area          = ls_window-area
                                   iv_from          = ls_window-from_utc
                                   iv_to            = ls_window-to_utc
                                   iv_approved_only = abap_false ) ).
      DATA(lt_problems) = zcl_ca_ops_downtime_policy=>validate( is_window      = ls_window
                                                                it_others      = lt_others
                                                                is_limits      = ls_limits
                                                                iv_ended_early = xsdbool( <ls_entity>-EndedBy IS NOT INITIAL ) ).
      IF lt_problems IS INITIAL.
        CONTINUE.
      ENDIF.
      INSERT VALUE #( %tky = <ls_entity>-%tky ) INTO TABLE failed-downtime.
      LOOP AT lt_problems ASSIGNING FIELD-SYMBOL(<ls_problem>).
        INSERT VALUE #( %tky                   = <ls_entity>-%tky
                        %state_area            = gc_state-window
                        %element-FromDate      = COND #( WHEN <ls_problem>-element = zif_ca_ops_resp_types=>gc_element-from_date
                                                         THEN if_abap_behv=>mk-on )
                        %element-ToDate        = COND #( WHEN <ls_problem>-element = zif_ca_ops_resp_types=>gc_element-to_date
                                                         THEN if_abap_behv=>mk-on )
                        %element-Reason        = COND #( WHEN <ls_problem>-element = zif_ca_ops_resp_types=>gc_element-reason
                                                         THEN if_abap_behv=>mk-on )
                        %element-CheckPattern  = COND #( WHEN <ls_problem>-element = zif_ca_ops_resp_types=>gc_element-check_pattern
                                                         THEN if_abap_behv=>mk-on )
                        %element-ObjectPattern = COND #( WHEN <ls_problem>-element = zif_ca_ops_resp_types=>gc_element-object_pattern
                                                         THEN if_abap_behv=>mk-on )
                        %element-GroupPattern  = COND #( WHEN <ls_problem>-element = zif_ca_ops_resp_types=>gc_element-group_pattern
                                                         THEN if_abap_behv=>mk-on )
                        %msg                   = new_message( id       = zif_ca_ops_types=>gc_message_class
                                                              number   = <ls_problem>-msgno
                                                              severity = if_abap_behv_message=>severity-error
                                                              v1       = <ls_problem>-v1
                                                              v2       = <ls_problem>-v2 ) ) INTO TABLE reported-downtime.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD window_of.
    rs_window-window_id      = is_entity-WindowId.
    rs_window-area           = is_entity-Area.
    rs_window-check_pattern  = is_entity-CheckPattern.
    rs_window-object_pattern = is_entity-ObjectPattern.
    rs_window-group_pattern  = is_entity-GroupPattern.
    rs_window-from_date      = is_entity-FromDate.
    rs_window-from_time      = is_entity-FromTime.
    rs_window-to_date        = is_entity-ToDate.
    rs_window-to_time        = is_entity-ToTime.
    rs_window-time_zone      = is_entity-TimeZone.
    rs_window-reason         = is_entity-Reason.
    rs_window-created_by     = is_entity-CreatedBy.
    rs_window-approved_by    = is_entity-ApprovedBy.
    " the stored UTC pair, else (a new or changed entry) from the local entry and the window's zone
    rs_window-from_utc = COND #( WHEN is_entity-FromUtc IS NOT INITIAL AND is_entity-EndedBy IS NOT INITIAL
                                 THEN is_entity-FromUtc
                                 WHEN is_entity-FromDate IS NOT INITIAL
                                 THEN zcl_ca_ops_downtime_policy=>to_utc( iv_date = is_entity-FromDate
                                                                          iv_time = is_entity-FromTime
                                                                          iv_zone = is_entity-TimeZone ) ).
    rs_window-to_utc   = COND #( WHEN is_entity-ToUtc IS NOT INITIAL AND is_entity-EndedBy IS NOT INITIAL
                                 THEN is_entity-ToUtc
                                 WHEN is_entity-ToDate IS NOT INITIAL
                                 THEN zcl_ca_ops_downtime_policy=>to_utc( iv_date = is_entity-ToDate
                                                                          iv_time = is_entity-ToTime
                                                                          iv_zone = is_entity-TimeZone ) ).
  ENDMETHOD.


  METHOD fc.
    rv_fc = COND #( WHEN iv_on = abap_true THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).
  ENDMETHOD.


  METHOD auth.
    rv_auth = COND #( WHEN zcl_ca_ops_exc_policy=>may_act( io_auth     = zcl_ca_ops_factory=>get_auth( )
                                                           iv_activity = iv_activity
                                                           iv_area     = iv_area
                                                           iv_bukrs    = space ) = abap_true
                      THEN if_abap_behv=>auth-allowed
                      ELSE if_abap_behv=>auth-unauthorized ).
  ENDMETHOD.

ENDCLASS.
