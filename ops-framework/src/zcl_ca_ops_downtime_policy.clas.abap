*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_downtime_policy.clas.abap
*& Purpose:
*& Rules of planned downtime windows (ZCA_OPS_DTWIN, 2026-11-11): which
*& finding a window covers (area and every filled scope pattern - PCRE on
*& check code, object key, interface or bank in GROUP1 / GROUP2, complete
*& value, case ignored), which window is in effect at a time (approved,
*& start <= time < end), the derived status (awaiting approval, scheduled,
*& active, ended - never stored), the checks of a window on save (start and
*& end, longest window DOWNTIME_MAX_HOURS, start in the past within
*& DOWNTIME_PAST_TOL_MIN, reason, valid patterns, no overlapping window of
*& the same scope) and the four-eyes approval. Pure logic: no database, no
*& clock - the caller passes the time and the limits.
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: planned downtime).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - planned downtime rules</p>
CLASS zcl_ca_ops_downtime_policy DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! The window covers the finding: same area and every filled scope pattern matches (check code, object
    "! key, GROUP1 or GROUP2 for the interface / bank); a window without pattern covers the whole area
    CLASS-METHODS covers
      IMPORTING
        is_window       TYPE zif_ca_ops_resp_types=>ty_window
        iv_area         TYPE zif_ca_ops_types=>ty_area
        is_finding      TYPE zif_ca_ops_types=>ty_finding
      RETURNING
        VALUE(rv_covers) TYPE abap_bool.

    "! The window is in effect at some time of [iv_from, iv_to] (UTC; blank iv_to = the point iv_from):
    "! approved, start <= iv_to and end > iv_from
    CLASS-METHODS in_effect
      IMPORTING
        is_window        TYPE zif_ca_ops_resp_types=>ty_window
        iv_from          TYPE timestampl
        iv_to            TYPE timestampl OPTIONAL
      RETURNING
        VALUE(rv_effect) TYPE abap_bool.

    "! The first window of the list in effect in [iv_from, iv_to] that covers the finding (blank = none)
    CLASS-METHODS covering
      IMPORTING
        it_windows          TYPE zif_ca_ops_resp_types=>tt_window
        iv_area             TYPE zif_ca_ops_types=>ty_area
        is_finding          TYPE zif_ca_ops_types=>ty_finding
        iv_from             TYPE timestampl
        iv_to               TYPE timestampl OPTIONAL
      RETURNING
        VALUE(rv_window_id) TYPE zif_ca_ops_resp_types=>ty_uuid.

    "! The first area-wide window (no scope pattern) of the area in effect at iv_at (blank = none): it also
    "! holds back the run-level alerts (RAG, abort) of the area
    CLASS-METHODS area_wide
      IMPORTING
        it_windows          TYPE zif_ca_ops_resp_types=>tt_window
        iv_area             TYPE zif_ca_ops_types=>ty_area
        iv_at               TYPE timestampl
      RETURNING
        VALUE(rv_window_id) TYPE zif_ca_ops_resp_types=>ty_uuid.

    "! P awaiting approval, S scheduled, A active, E ended (by its end or End now)
    CLASS-METHODS status
      IMPORTING
        is_window        TYPE zif_ca_ops_resp_types=>ty_window
        iv_now           TYPE timestampl
      RETURNING
        VALUE(rv_status) TYPE zif_ca_ops_resp_types=>ty_window_status.

    "! UTC time stamp of a local date and time in a time zone (blank zone = UTC)
    CLASS-METHODS to_utc
      IMPORTING
        iv_date             TYPE d
        iv_time             TYPE t
        iv_zone             TYPE tznzone
      RETURNING
        VALUE(rv_timestamp) TYPE timestampl.

    "! Checks of a window on save; the UTC start and end must be set (TO_UTC). A window ended by a user
    "! (iv_ended_early) keeps its start and end as left by End now, an approved one is not checked against
    "! the past again. it_others = the other windows of the area (approved or not) around the window
    CLASS-METHODS validate
      IMPORTING
        is_window          TYPE zif_ca_ops_resp_types=>ty_window
        it_others          TYPE zif_ca_ops_resp_types=>tt_window
        is_limits          TYPE zif_ca_ops_resp_types=>ty_window_limits
        iv_ended_early     TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(rt_problems) TYPE zif_ca_ops_resp_types=>tt_problem.

    "! Four-eyes approval: a window awaiting approval, approved by a user other than the planner
    CLASS-METHODS may_approve
      IMPORTING
        is_window          TYPE zif_ca_ops_resp_types=>ty_window
        iv_user            TYPE syuname
        iv_now             TYPE timestampl
      RETURNING
        VALUE(rt_problems) TYPE zif_ca_ops_resp_types=>tt_problem.

    "! A window may be changed or deleted while it awaits approval (an approved window is only ended)
    CLASS-METHODS may_change
      IMPORTING
        is_window          TYPE zif_ca_ops_resp_types=>ty_window
        iv_now             TYPE timestampl
      RETURNING
        VALUE(rt_problems) TYPE zif_ca_ops_resp_types=>tt_problem.

    "! A window may be ended now while it is scheduled or active
    CLASS-METHODS may_end
      IMPORTING
        is_window          TYPE zif_ca_ops_resp_types=>ty_window
        iv_now             TYPE timestampl
      RETURNING
        VALUE(rt_problems) TYPE zif_ca_ops_resp_types=>tt_problem.

  PRIVATE SECTION.
    "! Seconds from iv_from to iv_to (negative when iv_to is earlier)
    CLASS-METHODS seconds_between
      IMPORTING
        iv_from           TYPE timestampl
        iv_to             TYPE timestampl
      RETURNING
        VALUE(rv_seconds) TYPE decfloat34.

    "! Same area and the same scope patterns (case ignored)
    CLASS-METHODS same_scope
      IMPORTING
        is_left        TYPE zif_ca_ops_resp_types=>ty_window
        is_right       TYPE zif_ca_ops_resp_types=>ty_window
      RETURNING
        VALUE(rv_same) TYPE abap_bool.

    "! Local start of a window as text (ISO date and time) for a message
    CLASS-METHODS local_text
      IMPORTING
        iv_date        TYPE d
        iv_time        TYPE t
      RETURNING
        VALUE(rv_text) TYPE zif_ca_ops_types=>ty_msgv.

    CLASS-METHODS problem
      IMPORTING
        iv_msgno          TYPE zif_ca_ops_types=>ty_msgno
        iv_v1             TYPE simple OPTIONAL
        iv_v2             TYPE simple OPTIONAL
        iv_element        TYPE string OPTIONAL
      RETURNING
        VALUE(rs_problem) TYPE zif_ca_ops_resp_types=>ty_problem.

ENDCLASS.



CLASS zcl_ca_ops_downtime_policy IMPLEMENTATION.

  METHOD covers.
    IF is_window-area <> iv_area.
      RETURN.
    ENDIF.
    rv_covers = xsdbool(
          ( is_window-check_pattern IS INITIAL
            OR zcl_ca_ops_util=>pcre_match( iv_value = is_finding-check_code iv_pattern = is_window-check_pattern ) = abap_true )
      AND ( is_window-object_pattern IS INITIAL
            OR zcl_ca_ops_util=>pcre_match( iv_value = is_finding-object_key iv_pattern = is_window-object_pattern ) = abap_true )
      AND ( is_window-group_pattern IS INITIAL
            OR zcl_ca_ops_util=>pcre_match( iv_value = is_finding-group1 iv_pattern = is_window-group_pattern ) = abap_true
            OR zcl_ca_ops_util=>pcre_match( iv_value = is_finding-group2 iv_pattern = is_window-group_pattern ) = abap_true ) ).
  ENDMETHOD.


  METHOD in_effect.
    DATA(lv_to) = COND timestampl( WHEN iv_to IS INITIAL THEN iv_from ELSE iv_to ).
    rv_effect = xsdbool( is_window-approved_by IS NOT INITIAL
                         AND is_window-from_utc <= lv_to
                         AND is_window-to_utc > iv_from ).
  ENDMETHOD.


  METHOD covering.
    LOOP AT it_windows ASSIGNING FIELD-SYMBOL(<ls_window>).
      IF in_effect( is_window = <ls_window> iv_from = iv_from iv_to = iv_to ) = abap_true
         AND covers( is_window = <ls_window> iv_area = iv_area is_finding = is_finding ) = abap_true.
        rv_window_id = <ls_window>-window_id.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD area_wide.
    LOOP AT it_windows ASSIGNING FIELD-SYMBOL(<ls_window>)
         WHERE area           = iv_area
           AND check_pattern  IS INITIAL
           AND object_pattern IS INITIAL
           AND group_pattern  IS INITIAL.
      IF in_effect( is_window = <ls_window> iv_from = iv_at ) = abap_true.
        rv_window_id = <ls_window>-window_id.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD status.
    rv_status = COND #( WHEN is_window-to_utc <= iv_now THEN zif_ca_ops_resp_types=>gc_window_status-ended
                        WHEN is_window-approved_by IS INITIAL THEN zif_ca_ops_resp_types=>gc_window_status-pending
                        WHEN is_window-from_utc <= iv_now THEN zif_ca_ops_resp_types=>gc_window_status-active
                        ELSE zif_ca_ops_resp_types=>gc_window_status-scheduled ).
  ENDMETHOD.


  METHOD to_utc.
    DATA(lv_zone) = COND tznzone( WHEN iv_zone IS INITIAL THEN zif_ca_ops_types=>gc_time_zone_utc ELSE iv_zone ).
    CONVERT DATE iv_date TIME iv_time INTO TIME STAMP rv_timestamp TIME ZONE lv_zone.
  ENDMETHOD.


  METHOD validate.
    IF is_window-from_date IS INITIAL OR is_window-to_date IS INITIAL.
      INSERT problem( iv_msgno   = zif_ca_ops_resp_types=>gc_msg-window_incomplete
                      iv_element = zif_ca_ops_resp_types=>gc_element-from_date ) INTO TABLE rt_problems.
      RETURN.
    ENDIF.
    IF is_window-reason IS INITIAL.
      INSERT problem( iv_msgno   = zif_ca_ops_resp_types=>gc_msg-window_reason
                      iv_element = zif_ca_ops_resp_types=>gc_element-reason ) INTO TABLE rt_problems.
    ENDIF.
    " scope patterns: PCRE that compiles (an invalid pattern is never 'no match')
    DATA(lt_patterns) = VALUE string_table( ( CONV #( is_window-check_pattern ) )
                                            ( CONV #( is_window-object_pattern ) )
                                            ( CONV #( is_window-group_pattern ) ) ).
    DATA(lt_elements) = VALUE string_table( ( zif_ca_ops_resp_types=>gc_element-check_pattern )
                                            ( zif_ca_ops_resp_types=>gc_element-object_pattern )
                                            ( zif_ca_ops_resp_types=>gc_element-group_pattern ) ).
    LOOP AT lt_patterns ASSIGNING FIELD-SYMBOL(<lv_pattern>).
      IF zcl_ca_ops_util=>pcre_valid( <lv_pattern> ) = abap_false.
        INSERT problem( iv_msgno   = zif_ca_ops_resp_types=>gc_msg-window_pattern
                        iv_v1      = <lv_pattern>
                        iv_element = lt_elements[ sy-tabix ] ) INTO TABLE rt_problems.
      ENDIF.
    ENDLOOP.
    IF iv_ended_early = abap_true.
      " End now set the end itself: start and end are what the window really was
      RETURN.
    ENDIF.
    DATA(lv_seconds) = seconds_between( iv_from = is_window-from_utc iv_to = is_window-to_utc ).
    IF lv_seconds <= 0.
      INSERT problem( iv_msgno   = zif_ca_ops_resp_types=>gc_msg-window_order
                      iv_v1      = local_text( iv_date = is_window-to_date iv_time = is_window-to_time )
                      iv_v2      = local_text( iv_date = is_window-from_date iv_time = is_window-from_time )
                      iv_element = zif_ca_ops_resp_types=>gc_element-to_date ) INTO TABLE rt_problems.
      RETURN.
    ENDIF.
    DATA(lv_max_seconds) = is_limits-max_hours * zif_ca_ops_resp_types=>gc_minutes_per_hour
                           * zif_ca_ops_resp_types=>gc_seconds_per_minute.
    IF is_limits-max_hours > 0 AND lv_seconds > lv_max_seconds.
      INSERT problem( iv_msgno   = zif_ca_ops_resp_types=>gc_msg-window_too_long
                      iv_v1      = CONV i( ceil( lv_seconds / ( zif_ca_ops_resp_types=>gc_minutes_per_hour
                                                                * zif_ca_ops_resp_types=>gc_seconds_per_minute ) ) )
                      iv_v2      = is_limits-max_hours
                      iv_element = zif_ca_ops_resp_types=>gc_element-to_date ) INTO TABLE rt_problems.
    ENDIF.
    " a window is planned ahead: it may start a little in the past (the tolerance), never be back-dated
    IF is_window-approved_by IS INITIAL.
      DATA(lv_past_seconds) = seconds_between( iv_from = is_window-from_utc iv_to = is_limits-now ).
      IF lv_past_seconds > is_limits-tolerance_min * zif_ca_ops_resp_types=>gc_seconds_per_minute.
        INSERT problem( iv_msgno   = zif_ca_ops_resp_types=>gc_msg-window_in_past
                        iv_v1      = CONV i( ceil( lv_past_seconds / zif_ca_ops_resp_types=>gc_seconds_per_minute ) )
                        iv_v2      = is_limits-tolerance_min
                        iv_element = zif_ca_ops_resp_types=>gc_element-from_date ) INTO TABLE rt_problems.
      ENDIF.
    ENDIF.
    " no duplicate: another window of the same scope whose time overlaps (ended ones are history)
    LOOP AT it_others ASSIGNING FIELD-SYMBOL(<ls_other>) WHERE window_id <> is_window-window_id.
      IF same_scope( is_left = is_window is_right = <ls_other> ) = abap_true
         AND <ls_other>-to_utc > is_limits-now
         AND <ls_other>-from_utc < is_window-to_utc
         AND is_window-from_utc < <ls_other>-to_utc.
        INSERT problem( iv_msgno   = zif_ca_ops_resp_types=>gc_msg-window_overlap
                        iv_v1      = local_text( iv_date = <ls_other>-from_date iv_time = <ls_other>-from_time )
                        iv_element = zif_ca_ops_resp_types=>gc_element-from_date ) INTO TABLE rt_problems.
        EXIT.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD may_approve.
    CASE status( is_window = is_window iv_now = iv_now ).
      WHEN zif_ca_ops_resp_types=>gc_window_status-ended.
        INSERT problem( zif_ca_ops_resp_types=>gc_msg-window_ended ) INTO TABLE rt_problems.
      WHEN zif_ca_ops_resp_types=>gc_window_status-pending.
        " four-eyes: the planner never approves the own window
        IF is_window-created_by = iv_user.
          INSERT problem( iv_msgno = zif_ca_ops_resp_types=>gc_msg-window_four_eyes
                          iv_v1    = is_window-created_by ) INTO TABLE rt_problems.
        ENDIF.
      WHEN OTHERS.
        INSERT problem( zif_ca_ops_resp_types=>gc_msg-window_approved ) INTO TABLE rt_problems.
    ENDCASE.
  ENDMETHOD.


  METHOD may_change.
    CASE status( is_window = is_window iv_now = iv_now ).
      WHEN zif_ca_ops_resp_types=>gc_window_status-pending.
        RETURN.
      WHEN zif_ca_ops_resp_types=>gc_window_status-ended.
        INSERT problem( zif_ca_ops_resp_types=>gc_msg-window_ended ) INTO TABLE rt_problems.
      WHEN OTHERS.
        INSERT problem( zif_ca_ops_resp_types=>gc_msg-window_approved ) INTO TABLE rt_problems.
    ENDCASE.
  ENDMETHOD.


  METHOD may_end.
    CASE status( is_window = is_window iv_now = iv_now ).
      WHEN zif_ca_ops_resp_types=>gc_window_status-scheduled OR zif_ca_ops_resp_types=>gc_window_status-active.
        RETURN.
      WHEN zif_ca_ops_resp_types=>gc_window_status-ended.
        INSERT problem( zif_ca_ops_resp_types=>gc_msg-window_ended ) INTO TABLE rt_problems.
      WHEN OTHERS.
        " awaiting approval: change or delete it instead
        INSERT problem( zif_ca_ops_resp_types=>gc_msg-window_pending ) INTO TABLE rt_problems.
    ENDCASE.
  ENDMETHOD.


  METHOD seconds_between.
    TRY.
        rv_seconds = cl_abap_tstmp=>subtract( tstmp1 = iv_to tstmp2 = iv_from ).
      CATCH cx_parameter_invalid_range cx_parameter_invalid_type.
        " an initial or out-of-range time stamp: no duration (the order check refuses the window)
        CLEAR rv_seconds.
    ENDTRY.
  ENDMETHOD.


  METHOD same_scope.
    rv_same = xsdbool( is_left-area = is_right-area
                       AND to_upper( is_left-check_pattern ) = to_upper( is_right-check_pattern )
                       AND to_upper( is_left-object_pattern ) = to_upper( is_right-object_pattern )
                       AND to_upper( is_left-group_pattern ) = to_upper( is_right-group_pattern ) ).
  ENDMETHOD.


  METHOD local_text.
    rv_text = |{ iv_date DATE = ISO } { iv_time TIME = ISO }|.
  ENDMETHOD.


  METHOD problem.
    rs_problem-msgno   = iv_msgno.
    rs_problem-v1      = COND #( WHEN iv_v1 IS SUPPLIED THEN |{ iv_v1 }| ).
    rs_problem-v2      = COND #( WHEN iv_v2 IS SUPPLIED THEN |{ iv_v2 }| ).
    rs_problem-element = iv_element.
  ENDMETHOD.

ENDCLASS.
