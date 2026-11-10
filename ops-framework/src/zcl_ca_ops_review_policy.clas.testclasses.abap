*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_review_policy.clas.testclasses.abap
*& Purpose:
*& Pure tests of the daily control review rules: severity -> status, ranks,
*& what a sign-off needs (action required: observation and next action; a
*& result that differs from the derived status: observation), awaiting
*& review (no sign-off, worse status, newer finding) and overdue (date over,
*& past the cut-off). No doubles; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-10 | Initial version (control register and daily control review).
*&---------------------------------------------------------------------*
CLASS ltc_review_policy DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        today       TYPE d VALUE '20261110',
        yesterday   TYPE d VALUE '20261109',
        cutoff      TYPE t VALUE '083000',
        before_cut  TYPE t VALUE '080000',
        after_cut   TYPE t VALUE '091500',
        reviewed_at TYPE timestampl VALUE '20261110140000.0000000',
        later       TYPE timestampl VALUE '20261110150000.0000000',
        earlier     TYPE timestampl VALUE '20261110120000.0000000',
        observation TYPE zif_ca_ops_ctl_types=>ty_text VALUE 'Two items rejected by the bank, retry is safe',
        next_action TYPE zif_ca_ops_ctl_types=>ty_text VALUE 'Retry after the bank confirms',
      END OF gc_test.

    METHODS severity_maps_to_status     FOR TESTING.
    METHODS action_needs_both_texts     FOR TESTING.
    METHODS healthy_confirmed_freely    FOR TESTING.
    METHODS other_result_needs_reason   FOR TESTING.
    METHODS unknown_result_refused      FOR TESTING.
    METHODS unreviewed_is_awaiting      FOR TESTING.
    METHODS worse_status_reopens        FOR TESTING.
    METHODS newer_finding_reopens       FOR TESTING.
    METHODS inactive_never_awaits       FOR TESTING.
    METHODS overdue_after_cutoff        FOR TESTING.
    METHODS past_date_overdue           FOR TESTING.
ENDCLASS.


CLASS ltc_review_policy IMPLEMENTATION.

  " Rule: B / E action required, W watch, I and blank healthy; ranks 2 / 1 / 0
  METHOD severity_maps_to_status.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_review_policy=>status_of_severity( zif_ca_ops_types=>gc_severity-block )
                                        exp = zif_ca_ops_ctl_types=>gc_status-action msg = 'B is action required' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_review_policy=>status_of_severity( zif_ca_ops_types=>gc_severity-error )
                                        exp = zif_ca_ops_ctl_types=>gc_status-action msg = 'E is action required' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_review_policy=>status_of_severity( zif_ca_ops_types=>gc_severity-warning )
                                        exp = zif_ca_ops_ctl_types=>gc_status-watch msg = 'W is watch' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_review_policy=>status_of_severity( zif_ca_ops_types=>gc_severity-info )
                                        exp = zif_ca_ops_ctl_types=>gc_status-healthy msg = 'I is healthy' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_review_policy=>status_rank( space )
                                        exp = zif_ca_ops_ctl_types=>gc_rank-healthy msg = 'Blank ranks as healthy' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_review_policy=>status_rank( zif_ca_ops_ctl_types=>gc_status-action )
                                        exp = zif_ca_ops_ctl_types=>gc_rank-action msg = 'Action required ranks highest' ).
  ENDMETHOD.


  " Rule: a control that needs action is signed off only with observation and next action
  METHOD action_needs_both_texts.
    DATA(ls_decision) = zcl_ca_ops_review_policy=>can_review(
                          VALUE #( derived_status = zif_ca_ops_ctl_types=>gc_status-action
                                   observation    = gc_test-observation ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_decision-msgno exp = zif_ca_ops_ctl_types=>gc_msg-action_text_missing
                                        msg = 'Next action missing: refused with 076' ).
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_review_policy=>can_review(
                                              VALUE #( derived_status = zif_ca_ops_ctl_types=>gc_status-action
                                                       observation    = gc_test-observation
                                                       next_action    = gc_test-next_action ) )-allowed
                                      msg = 'Both texts given: signed off' ).
  ENDMETHOD.


  " Rule: a healthy or watch control is confirmed without text; the stored result is the derived one
  METHOD healthy_confirmed_freely.
    DATA(ls_input) = VALUE zif_ca_ops_ctl_types=>ty_review_input( derived_status = zif_ca_ops_ctl_types=>gc_status-watch ).
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_review_policy=>can_review( ls_input )-allowed
                                      msg = 'Watch confirmed without text' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_review_policy=>effective_result( ls_input )
                                        exp = zif_ca_ops_ctl_types=>gc_status-watch
                                        msg = 'Blank result = the derived status' ).
  ENDMETHOD.


  " Rule: a result other than the derived status needs an observation (and action required both texts)
  METHOD other_result_needs_reason.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_ops_review_policy=>can_review( VALUE #( derived_status = zif_ca_ops_ctl_types=>gc_status-watch
                                                            review_result  = zif_ca_ops_ctl_types=>gc_status-healthy ) )-msgno
      exp = zif_ca_ops_ctl_types=>gc_msg-result_differs msg = 'Watch confirmed as healthy needs an observation (077)' ).
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_ops_review_policy=>can_review( VALUE #( derived_status = zif_ca_ops_ctl_types=>gc_status-watch
                                                            review_result  = zif_ca_ops_ctl_types=>gc_status-healthy
                                                            observation    = gc_test-observation ) )-allowed
      msg = 'With an observation the reviewer may differ' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_ops_review_policy=>can_review( VALUE #( derived_status = zif_ca_ops_ctl_types=>gc_status-healthy
                                                            review_result  = zif_ca_ops_ctl_types=>gc_status-action
                                                            observation    = gc_test-observation ) )-msgno
      exp = zif_ca_ops_ctl_types=>gc_msg-action_text_missing msg = 'Raised to action required: next action needed' ).
  ENDMETHOD.


  METHOD unknown_result_refused.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_ca_ops_review_policy=>can_review( VALUE #( derived_status = zif_ca_ops_ctl_types=>gc_status-healthy
                                                            review_result  = 'X' ) )-msgno
      exp = zif_ca_ops_ctl_types=>gc_msg-result_invalid msg = 'X is no status (078)' ).
  ENDMETHOD.


  " Rule: an active control without sign-off awaits review
  METHOD unreviewed_is_awaiting.
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_ops_review_policy=>is_awaiting( VALUE #( active         = abap_true
                                                            derived_status = zif_ca_ops_ctl_types=>gc_status-healthy ) )
      msg = 'Healthy but not signed off: awaiting' ).
    cl_abap_unit_assert=>assert_false(
      act = zcl_ca_ops_review_policy=>is_awaiting( VALUE #( active           = abap_true
                                                            derived_status   = zif_ca_ops_ctl_types=>gc_status-watch
                                                            status_at_review = zif_ca_ops_ctl_types=>gc_status-watch
                                                            last_finding_at  = gc_test-earlier
                                                            reviewed_at      = gc_test-reviewed_at ) )
      msg = 'Signed off at the same status, no newer finding: done' ).
  ENDMETHOD.


  " Rule: worse than at the sign-off -> awaiting again; better -> stays reviewed
  METHOD worse_status_reopens.
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_ops_review_policy=>is_awaiting( VALUE #( active           = abap_true
                                                            derived_status   = zif_ca_ops_ctl_types=>gc_status-action
                                                            status_at_review = zif_ca_ops_ctl_types=>gc_status-watch
                                                            reviewed_at      = gc_test-reviewed_at ) )
      msg = 'Watch at sign-off, action required now: awaiting' ).
    cl_abap_unit_assert=>assert_false(
      act = zcl_ca_ops_review_policy=>is_awaiting( VALUE #( active           = abap_true
                                                            derived_status   = zif_ca_ops_ctl_types=>gc_status-healthy
                                                            status_at_review = zif_ca_ops_ctl_types=>gc_status-action
                                                            reviewed_at      = gc_test-reviewed_at ) )
      msg = 'Better than at sign-off: still reviewed' ).
  ENDMETHOD.


  METHOD newer_finding_reopens.
    cl_abap_unit_assert=>assert_true(
      act = zcl_ca_ops_review_policy=>is_awaiting( VALUE #( active           = abap_true
                                                            derived_status   = zif_ca_ops_ctl_types=>gc_status-watch
                                                            status_at_review = zif_ca_ops_ctl_types=>gc_status-watch
                                                            last_finding_at  = gc_test-later
                                                            reviewed_at      = gc_test-reviewed_at ) )
      msg = 'A finding after the sign-off: awaiting again' ).
  ENDMETHOD.


  METHOD inactive_never_awaits.
    cl_abap_unit_assert=>assert_false(
      act = zcl_ca_ops_review_policy=>is_awaiting( VALUE #( derived_status = zif_ca_ops_ctl_types=>gc_status-action ) )
      msg = 'An inactive control is not reviewed' ).
  ENDMETHOD.


  " Rule: today, awaiting and past the cut-off = overdue; before the cut-off not yet
  METHOD overdue_after_cutoff.
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_review_policy=>is_overdue( iv_awaiting      = abap_true
                                                                                  iv_business_date = gc_test-today
                                                                                  iv_today         = gc_test-today
                                                                                  iv_now_time      = gc_test-after_cut
                                                                                  iv_cutoff        = gc_test-cutoff )
                                      msg = '09:15 after a 08:30 cut-off: overdue' ).
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_review_policy=>is_overdue( iv_awaiting      = abap_true
                                                                                   iv_business_date = gc_test-today
                                                                                   iv_today         = gc_test-today
                                                                                   iv_now_time      = gc_test-before_cut
                                                                                   iv_cutoff        = gc_test-cutoff )
                                       msg = '08:00 before the cut-off: not yet' ).
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_review_policy=>is_overdue( iv_awaiting      = abap_true
                                                                                   iv_business_date = gc_test-today
                                                                                   iv_today         = gc_test-today
                                                                                   iv_now_time      = gc_test-after_cut
                                                                                   iv_cutoff        = '000000' )
                                       msg = 'No cut-off: overdue only when the day is over' ).
  ENDMETHOD.


  METHOD past_date_overdue.
    cl_abap_unit_assert=>assert_true( act = zcl_ca_ops_review_policy=>is_overdue( iv_awaiting      = abap_true
                                                                                  iv_business_date = gc_test-yesterday
                                                                                  iv_today         = gc_test-today
                                                                                  iv_now_time      = gc_test-before_cut
                                                                                  iv_cutoff        = gc_test-cutoff )
                                      msg = 'Yesterday not signed off: overdue' ).
    cl_abap_unit_assert=>assert_false( act = zcl_ca_ops_review_policy=>is_overdue( iv_awaiting      = abap_false
                                                                                   iv_business_date = gc_test-yesterday
                                                                                   iv_today         = gc_test-today
                                                                                   iv_now_time      = gc_test-after_cut
                                                                                   iv_cutoff        = gc_test-cutoff )
                                       msg = 'Signed off: never overdue' ).
  ENDMETHOD.

ENDCLASS.
