*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_downtime_policy.clas.testclasses.abap
*& Purpose:
*& Domain tests of the planned downtime rules (pure logic, structures built
*& field by field): which finding a window covers, which window is in effect,
*& the derived status, the checks of a window on save (order, longest window,
*& start in the past, reason, patterns, overlapping duplicate) and the
*& four-eyes approval. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: planned downtime).
*&---------------------------------------------------------------------*
CLASS ltc_downtime_policy DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        area       TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_A',
        other_area TYPE zif_ca_ops_types=>ty_area VALUE 'ZT_OPS_B',
        window     TYPE zif_ca_ops_resp_types=>ty_uuid VALUE '000000000000000000000000000000C1',
        other      TYPE zif_ca_ops_resp_types=>ty_uuid VALUE '000000000000000000000000000000C2',
        planner    TYPE syuname VALUE 'ZT_PLANNER',
        approver   TYPE syuname VALUE 'ZT_APPROVER',
        day        TYPE d VALUE '20261111',
        from_time  TYPE t VALUE '220000',
        to_time    TYPE t VALUE '235900',
        from_utc   TYPE timestampl VALUE '20261111220000.0000000',
        to_utc     TYPE timestampl VALUE '20261111235900.0000000',
        inside     TYPE timestampl VALUE '20261111230000.0000000',
        before     TYPE timestampl VALUE '20261111215500.0000000',
        long_ago   TYPE timestampl VALUE '20261111200000.0000000',
        after      TYPE timestampl VALUE '20261112000000.0000000',
        check_bank TYPE zif_ca_ops_types=>ty_check_code VALUE 'NO_BANK_ACK',
        bank_pat   TYPE zif_ca_ops_types=>ty_pattern VALUE 'BANK_A.*',
        max_hours  TYPE i VALUE 24,
        tolerance  TYPE i VALUE 15,
      END OF gc.

    METHODS window
      RETURNING
        VALUE(rs_window) TYPE zif_ca_ops_resp_types=>ty_window.
    METHODS limits
      IMPORTING
        iv_now           TYPE timestampl
      RETURNING
        VALUE(rs_limits) TYPE zif_ca_ops_resp_types=>ty_window_limits.
    METHODS has
      IMPORTING
        it_problems   TYPE zif_ca_ops_resp_types=>tt_problem
        iv_msgno      TYPE zif_ca_ops_types=>ty_msgno
      RETURNING
        VALUE(rv_has) TYPE abap_bool.

    METHODS scope_pattern_on_group      FOR TESTING.
    METHODS area_wide_covers_all        FOR TESTING.
    METHODS other_area_never_covered    FOR TESTING.
    METHODS only_approved_in_effect     FOR TESTING.
    METHODS ends_by_itself              FOR TESTING.
    METHODS end_before_start_refused    FOR TESTING.
    METHODS longer_than_max_refused     FOR TESTING.
    METHODS start_in_past_tolerated     FOR TESTING.
    METHODS start_long_ago_refused      FOR TESTING.
    METHODS same_scope_overlap_refused  FOR TESTING.
    METHODS other_scope_may_overlap     FOR TESTING.
    METHODS reason_and_pattern_checked  FOR TESTING.
    METHODS planner_cannot_approve      FOR TESTING.
    METHODS approved_only_ended         FOR TESTING.
ENDCLASS.


CLASS ltc_downtime_policy IMPLEMENTATION.

  METHOD window.
    rs_window-window_id = gc-window.
    rs_window-area      = gc-area.
    rs_window-from_date = gc-day.
    rs_window-from_time = gc-from_time.
    rs_window-to_date   = gc-day.
    rs_window-to_time   = gc-to_time.
    rs_window-time_zone = zif_ca_ops_types=>gc_time_zone_utc.
    rs_window-from_utc  = gc-from_utc.
    rs_window-to_utc    = gc-to_utc.
    rs_window-reason    = 'ZT bank maintenance'.
    rs_window-created_by = gc-planner.
  ENDMETHOD.


  METHOD limits.
    rs_limits-now           = iv_now.
    rs_limits-max_hours     = gc-max_hours.
    rs_limits-tolerance_min = gc-tolerance.
  ENDMETHOD.


  METHOD has.
    rv_has = xsdbool( line_exists( it_problems[ msgno = iv_msgno ] ) ).
  ENDMETHOD.


  " Rule: a pattern on the interface / bank matches GROUP1 or GROUP2 of the finding, complete value
  METHOD scope_pattern_on_group.
    TRY.
        DATA ls_finding TYPE zif_ca_ops_types=>ty_finding.
        DATA(ls_window) = window( ).
        ls_window-group_pattern = gc-bank_pat.
        ls_finding-check_code = gc-check_bank.
        ls_finding-group2     = 'BANK_A_ACK'.
        cl_abap_unit_assert=>assert_true(
            act = zcl_ca_ops_downtime_policy=>covers( is_window = ls_window iv_area = gc-area is_finding = ls_finding )
            msg = 'GROUP2 of the finding matches the bank pattern' ).
        ls_finding-group2 = 'BANK_B_ACK'.
        cl_abap_unit_assert=>assert_false(
            act = zcl_ca_ops_downtime_policy=>covers( is_window = ls_window iv_area = gc-area is_finding = ls_finding )
            msg = 'Another bank is not covered' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a window without pattern covers every finding of its area
  METHOD area_wide_covers_all.
    TRY.
        DATA ls_finding TYPE zif_ca_ops_types=>ty_finding.
        ls_finding-check_code = gc-check_bank.
        cl_abap_unit_assert=>assert_true(
            act = zcl_ca_ops_downtime_policy=>covers( is_window = window( ) iv_area = gc-area is_finding = ls_finding )
            msg = 'An area-wide window covers the finding' ).
        cl_abap_unit_assert=>assert_equals(
            act = zcl_ca_ops_downtime_policy=>area_wide( it_windows = VALUE #( ( VALUE #( BASE window( )
                                                                                           approved_by = gc-approver ) ) )
                                                         iv_area    = gc-area
                                                         iv_at      = gc-inside )
            exp = gc-window
            msg = 'The approved area-wide window holds back run-level alerts' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a window never covers findings of another area
  METHOD other_area_never_covered.
    TRY.
        DATA ls_finding TYPE zif_ca_ops_types=>ty_finding.
        ls_finding-check_code = gc-check_bank.
        cl_abap_unit_assert=>assert_false(
            act = zcl_ca_ops_downtime_policy=>covers( is_window = window( ) iv_area = gc-other_area is_finding = ls_finding )
            msg = 'Another area is not covered' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: only an approved window takes effect, from its start to (excluding) its end
  METHOD only_approved_in_effect.
    TRY.
        DATA ls_finding TYPE zif_ca_ops_types=>ty_finding.
        DATA(ls_pending) = window( ).
        DATA(ls_approved) = window( ).
        ls_approved-window_id   = gc-other.
        ls_approved-approved_by = gc-approver.
        ls_finding-check_code = gc-check_bank.
        cl_abap_unit_assert=>assert_equals(
            act = zcl_ca_ops_downtime_policy=>covering( it_windows = VALUE #( ( ls_pending ) ( ls_approved ) )
                                                        iv_area    = gc-area
                                                        is_finding = ls_finding
                                                        iv_from    = gc-inside )
            exp = gc-other
            msg = 'The approved window covers, the pending one never' ).
        cl_abap_unit_assert=>assert_initial(
            act = zcl_ca_ops_downtime_policy=>covering( it_windows = VALUE #( ( ls_approved ) )
                                                        iv_area    = gc-area
                                                        is_finding = ls_finding
                                                        iv_from    = gc-to_utc )
            msg = 'At its end the window no longer covers' ).
        cl_abap_unit_assert=>assert_equals(
            act = zcl_ca_ops_downtime_policy=>covering( it_windows = VALUE #( ( ls_approved ) )
                                                        iv_area    = gc-area
                                                        is_finding = ls_finding
                                                        iv_from    = gc-long_ago
                                                        iv_to      = gc-inside )
            exp = gc-other
            msg = 'A period that overlaps the window is planned (missing-volume question)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the status is derived from approval and time - a window ends by itself
  METHOD ends_by_itself.
    TRY.
        DATA(ls_window) = window( ).
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_downtime_policy=>status( is_window = ls_window iv_now = gc-inside )
                                            exp = zif_ca_ops_resp_types=>gc_window_status-pending
                                            msg = 'Not approved: awaiting approval' ).
        ls_window-approved_by = gc-approver.
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_downtime_policy=>status( is_window = ls_window iv_now = gc-before )
                                            exp = zif_ca_ops_resp_types=>gc_window_status-scheduled
                                            msg = 'Approved, not started: scheduled' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_downtime_policy=>status( is_window = ls_window iv_now = gc-inside )
                                            exp = zif_ca_ops_resp_types=>gc_window_status-active
                                            msg = 'Approved and started: active' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_downtime_policy=>status( is_window = ls_window iv_now = gc-after )
                                            exp = zif_ca_ops_resp_types=>gc_window_status-ended
                                            msg = 'After its end: ended, without any action' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the end must be after the start (143)
  METHOD end_before_start_refused.
    TRY.
        DATA(ls_window) = window( ).
        ls_window-to_utc = ls_window-from_utc.
        cl_abap_unit_assert=>assert_true(
            act = has( it_problems = zcl_ca_ops_downtime_policy=>validate( is_window = ls_window
                                                                           it_others = VALUE #( )
                                                                           is_limits = limits( gc-before ) )
                       iv_msgno    = zif_ca_ops_resp_types=>gc_msg-window_order )
            msg = 'End = start is refused' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a window longer than DOWNTIME_MAX_HOURS is refused (144)
  METHOD longer_than_max_refused.
    TRY.
        DATA(ls_window) = window( ).
        ls_window-to_utc = '20261113000000.0000000'.
        DATA(lt_problems) = zcl_ca_ops_downtime_policy=>validate( is_window = ls_window
                                                                  it_others = VALUE #( )
                                                                  is_limits = limits( gc-before ) ).
        cl_abap_unit_assert=>assert_true( act = has( it_problems = lt_problems
                                                     iv_msgno    = zif_ca_ops_resp_types=>gc_msg-window_too_long )
                                          msg = '26 hours are longer than 24' ).
        cl_abap_unit_assert=>assert_false(
            act = has( it_problems = zcl_ca_ops_downtime_policy=>validate( is_window = window( )
                                                                           it_others = VALUE #( )
                                                                           is_limits = limits( gc-before ) )
                       iv_msgno    = zif_ca_ops_resp_types=>gc_msg-window_too_long )
            msg = 'Two hours are accepted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a window may start up to the tolerance in the past (DOWNTIME_PAST_TOL_MIN)
  METHOD start_in_past_tolerated.
    TRY.
        cl_abap_unit_assert=>assert_initial(
            act = zcl_ca_ops_downtime_policy=>validate( is_window = window( )
                                                        it_others = VALUE #( )
                                                        is_limits = limits( '20261111221000.0000000' ) )
            msg = 'Ten minutes in the past is within the tolerance of 15' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a window is never back-dated beyond the tolerance (145); an approved window is not checked again
  METHOD start_long_ago_refused.
    TRY.
        DATA(ls_window) = window( ).
        cl_abap_unit_assert=>assert_true(
            act = has( it_problems = zcl_ca_ops_downtime_policy=>validate( is_window = ls_window
                                                                           it_others = VALUE #( )
                                                                           is_limits = limits( gc-inside ) )
                       iv_msgno    = zif_ca_ops_resp_types=>gc_msg-window_in_past )
            msg = 'One hour in the past is refused' ).
        ls_window-approved_by = gc-approver.
        cl_abap_unit_assert=>assert_false(
            act = has( it_problems = zcl_ca_ops_downtime_policy=>validate( is_window = ls_window
                                                                           it_others = VALUE #( )
                                                                           is_limits = limits( gc-inside ) )
                       iv_msgno    = zif_ca_ops_resp_types=>gc_msg-window_in_past )
            msg = 'An approved window that runs is not refused for having started' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no two windows of the same scope overlap (146)
  METHOD same_scope_overlap_refused.
    TRY.
        DATA(ls_other) = window( ).
        ls_other-window_id = gc-other.
        ls_other-from_utc  = '20261111230000.0000000'.
        ls_other-to_utc    = '20261112010000.0000000'.
        cl_abap_unit_assert=>assert_true(
            act = has( it_problems = zcl_ca_ops_downtime_policy=>validate( is_window = window( )
                                                                           it_others = VALUE #( ( ls_other ) )
                                                                           is_limits = limits( gc-before ) )
                       iv_msgno    = zif_ca_ops_resp_types=>gc_msg-window_overlap )
            msg = 'An overlapping window of the same scope is a duplicate' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: windows of different scope may overlap; touching windows of the same scope do not overlap
  METHOD other_scope_may_overlap.
    TRY.
        DATA(ls_other) = window( ).
        ls_other-window_id     = gc-other.
        ls_other-group_pattern = gc-bank_pat.
        DATA(ls_next) = window( ).
        ls_next-window_id = gc-other.
        ls_next-from_utc  = gc-to_utc.
        ls_next-to_utc    = gc-after.
        cl_abap_unit_assert=>assert_initial(
            act = zcl_ca_ops_downtime_policy=>validate( is_window = window( )
                                                        it_others = VALUE #( ( ls_other ) ( ls_next ) )
                                                        is_limits = limits( gc-before ) )
            msg = 'Another scope and a window that starts at the end are no duplicates' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a reason is required (151) and a scope pattern must be valid PCRE (150)
  METHOD reason_and_pattern_checked.
    TRY.
        DATA(ls_window) = window( ).
        CLEAR ls_window-reason.
        ls_window-check_pattern = '(NO_'.
        DATA(lt_problems) = zcl_ca_ops_downtime_policy=>validate( is_window = ls_window
                                                                  it_others = VALUE #( )
                                                                  is_limits = limits( gc-before ) ).
        cl_abap_unit_assert=>assert_true( act = has( it_problems = lt_problems
                                                     iv_msgno    = zif_ca_ops_resp_types=>gc_msg-window_reason )
                                          msg = 'No reason is refused' ).
        cl_abap_unit_assert=>assert_true( act = has( it_problems = lt_problems
                                                     iv_msgno    = zif_ca_ops_resp_types=>gc_msg-window_pattern )
                                          msg = 'A pattern that does not compile is refused' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: four-eyes - the planner never approves the own window (147); another user may
  METHOD planner_cannot_approve.
    TRY.
        cl_abap_unit_assert=>assert_true(
            act = has( it_problems = zcl_ca_ops_downtime_policy=>may_approve( is_window = window( )
                                                                              iv_user   = gc-planner
                                                                              iv_now    = gc-before )
                       iv_msgno    = zif_ca_ops_resp_types=>gc_msg-window_four_eyes )
            msg = 'The planner is refused' ).
        cl_abap_unit_assert=>assert_initial(
            act = zcl_ca_ops_downtime_policy=>may_approve( is_window = window( ) iv_user = gc-approver iv_now = gc-before )
            msg = 'A second user may approve' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an approved window is not changed (148) - it is ended; a pending one cannot be ended (159)
  METHOD approved_only_ended.
    TRY.
        DATA(ls_window) = window( ).
        cl_abap_unit_assert=>assert_initial( act = zcl_ca_ops_downtime_policy=>may_change( is_window = ls_window
                                                                                           iv_now    = gc-before )
                                             msg = 'A pending window may be changed' ).
        cl_abap_unit_assert=>assert_true(
            act = has( it_problems = zcl_ca_ops_downtime_policy=>may_end( is_window = ls_window iv_now = gc-before )
                       iv_msgno    = zif_ca_ops_resp_types=>gc_msg-window_pending )
            msg = 'A pending window is changed or deleted, not ended' ).
        ls_window-approved_by = gc-approver.
        cl_abap_unit_assert=>assert_true(
            act = has( it_problems = zcl_ca_ops_downtime_policy=>may_change( is_window = ls_window iv_now = gc-inside )
                       iv_msgno    = zif_ca_ops_resp_types=>gc_msg-window_approved )
            msg = 'An approved window is not changed' ).
        cl_abap_unit_assert=>assert_initial( act = zcl_ca_ops_downtime_policy=>may_end( is_window = ls_window
                                                                                        iv_now    = gc-inside )
                                             msg = 'An active window may be ended now' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
