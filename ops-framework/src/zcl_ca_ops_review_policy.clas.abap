*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_review_policy.clas.abap
*& Purpose:
*& Rules of the daily control review, without database: the status of a
*& finding severity (B / E action required, W watch, else healthy), status
*& ranks, whether a sign-off may be saved (action required needs an
*& observation and a next action; a result that differs from the derived
*& status needs an observation), whether a control awaits review (no
*& sign-off, the status got worse, or a covered finding changed since the
*& sign-off - new, severity, amount, configuration version) and whether that
*& review is overdue (business date over, or past the control's cut-off on
*& the date). The CDS views of the review app and of the consumers' cards
*& apply the same rules (docs/CONTROL_REVIEW.md); tests prove them here.
*& Modification log:
*& 2026-11-10 | Initial version (control register and daily control review).
*& 2026-11-11 | Explainable, versioned results: a sign-off is reopened by a covered finding that is new since
*&            | the sign-off or changed in severity, amount or configuration version (REOPEN_REASON per finding,
*&            | the reason of the slice = the first that applies; a worse status reopens with WORSE); a finding
*&            | raised again unchanged no longer reopens it (IS_AWAITING, REOPEN_REASON_OF_SLICE).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - daily control review rules</p>
CLASS zcl_ca_ops_review_policy DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! B / E -> action required, W -> watch, anything else -> healthy
    CLASS-METHODS status_of_severity
      IMPORTING
        iv_severity      TYPE zif_ca_ops_types=>ty_severity
      RETURNING
        VALUE(rv_status) TYPE zif_ca_ops_ctl_types=>ty_status.

    "! 0 healthy (also blank), 1 watch, 2 action required
    CLASS-METHODS status_rank
      IMPORTING
        iv_status      TYPE zif_ca_ops_ctl_types=>ty_status
      RETURNING
        VALUE(rv_rank) TYPE i.

    "! May the sign-off be saved? Result blank = the derived status confirmed
    CLASS-METHODS can_review
      IMPORTING
        is_input           TYPE zif_ca_ops_ctl_types=>ty_review_input
      RETURNING
        VALUE(rs_decision) TYPE zif_ca_ops_exc_types=>ty_decision.

    "! Result stored with the sign-off: the reviewer's result, else the derived status
    CLASS-METHODS effective_result
      IMPORTING
        is_input         TYPE zif_ca_ops_ctl_types=>ty_review_input
      RETURNING
        VALUE(rv_result) TYPE zif_ca_ops_ctl_types=>ty_status.

    "! Why a covered finding recorded after the sign-off reopens it: NEW (first seen after the sign-off),
    "! STATUS (severity differs from the replaced row), AMOUNT (amount or currency differs), CONFIG (another
    "! configuration version, both known); blank = raised again unchanged (does not reopen)
    CLASS-METHODS reopen_reason
      IMPORTING
        is_finding       TYPE zif_ca_ops_ctl_types=>ty_reopen_finding
        iv_reviewed_at   TYPE timestampl
      RETURNING
        VALUE(rv_reason) TYPE zif_ca_ops_ctl_types=>ty_reopen.

    "! Reason of a signed-off slice: the first of NEW, STATUS, AMOUNT, CONFIG among its findings' reasons,
    "! else WORSE when the status is worse than at the sign-off; blank = the sign-off stands
    CLASS-METHODS reopen_reason_of_slice
      IMPORTING
        it_reasons          TYPE string_table
        iv_derived_status   TYPE zif_ca_ops_ctl_types=>ty_status
        iv_status_at_review TYPE zif_ca_ops_ctl_types=>ty_status
      RETURNING
        VALUE(rv_reason)    TYPE zif_ca_ops_ctl_types=>ty_reopen.

    "! Active and (not signed off, worse than at the sign-off, or reopened by a changed covered finding)
    CLASS-METHODS is_awaiting
      IMPORTING
        is_state           TYPE zif_ca_ops_ctl_types=>ty_await_state
      RETURNING
        VALUE(rv_awaiting) TYPE abap_bool.

    "! Awaiting and the business date is over, or today past the cut-off (initial cut-off = end of day)
    CLASS-METHODS is_overdue
      IMPORTING
        iv_awaiting       TYPE abap_bool
        iv_business_date  TYPE d
        iv_today          TYPE d
        iv_now_time       TYPE t
        iv_cutoff         TYPE t
      RETURNING
        VALUE(rv_overdue) TYPE abap_bool.

  PRIVATE SECTION.
    CLASS-METHODS refuse
      IMPORTING
        iv_msgno           TYPE symsgno
        iv_v1              TYPE clike OPTIONAL
      RETURNING
        VALUE(rs_decision) TYPE zif_ca_ops_exc_types=>ty_decision.

ENDCLASS.



CLASS zcl_ca_ops_review_policy IMPLEMENTATION.

  METHOD status_of_severity.
    rv_status = SWITCH #( iv_severity
                          WHEN zif_ca_ops_types=>gc_severity-block OR zif_ca_ops_types=>gc_severity-error
                            THEN zif_ca_ops_ctl_types=>gc_status-action
                          WHEN zif_ca_ops_types=>gc_severity-warning
                            THEN zif_ca_ops_ctl_types=>gc_status-watch
                          ELSE zif_ca_ops_ctl_types=>gc_status-healthy ).
  ENDMETHOD.


  METHOD status_rank.
    rv_rank = SWITCH #( iv_status
                        WHEN zif_ca_ops_ctl_types=>gc_status-action THEN zif_ca_ops_ctl_types=>gc_rank-action
                        WHEN zif_ca_ops_ctl_types=>gc_status-watch  THEN zif_ca_ops_ctl_types=>gc_rank-watch
                        ELSE zif_ca_ops_ctl_types=>gc_rank-healthy ).
  ENDMETHOD.


  METHOD effective_result.
    rv_result = COND #( WHEN is_input-review_result IS INITIAL THEN is_input-derived_status
                        ELSE is_input-review_result ).
    IF rv_result IS INITIAL.
      rv_result = zif_ca_ops_ctl_types=>gc_status-healthy.
    ENDIF.
  ENDMETHOD.


  METHOD can_review.
    DATA(lv_derived) = COND zif_ca_ops_ctl_types=>ty_status( WHEN is_input-derived_status IS INITIAL
                                                             THEN zif_ca_ops_ctl_types=>gc_status-healthy
                                                             ELSE is_input-derived_status ).
    IF is_input-review_result IS NOT INITIAL
       AND is_input-review_result <> zif_ca_ops_ctl_types=>gc_status-healthy
       AND is_input-review_result <> zif_ca_ops_ctl_types=>gc_status-watch
       AND is_input-review_result <> zif_ca_ops_ctl_types=>gc_status-action.
      rs_decision = refuse( iv_msgno = zif_ca_ops_ctl_types=>gc_msg-result_invalid iv_v1 = is_input-review_result ).
      RETURN.
    ENDIF.
    DATA(lv_result) = effective_result( is_input ).
    IF ( lv_result = zif_ca_ops_ctl_types=>gc_status-action OR lv_derived = zif_ca_ops_ctl_types=>gc_status-action )
       AND ( is_input-observation IS INITIAL OR is_input-next_action IS INITIAL ).
      rs_decision = refuse( zif_ca_ops_ctl_types=>gc_msg-action_text_missing ).
    ELSEIF lv_result <> lv_derived AND is_input-observation IS INITIAL.
      rs_decision = refuse( iv_msgno = zif_ca_ops_ctl_types=>gc_msg-result_differs iv_v1 = lv_result ).
    ELSE.
      rs_decision-allowed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD is_awaiting.
    IF is_state-active = abap_false.
      RETURN.
    ENDIF.
    rv_awaiting = xsdbool( is_state-status_at_review IS INITIAL
                           OR status_rank( is_state-derived_status ) > status_rank( is_state-status_at_review )
                           OR is_state-reopen_reason IS NOT INITIAL ).
  ENDMETHOD.


  METHOD reopen_reason.
    IF is_finding-first_seen_at > iv_reviewed_at.
      rv_reason = zif_ca_ops_ctl_types=>gc_reopen-new.
    ELSEIF is_finding-has_prev = abap_false.
      " no replaced row known: no evidence of a change
      RETURN.
    ELSEIF is_finding-prev_severity <> is_finding-severity.
      rv_reason = zif_ca_ops_ctl_types=>gc_reopen-status.
    ELSEIF is_finding-prev_amount <> is_finding-amount OR is_finding-prev_currency <> is_finding-currency.
      rv_reason = zif_ca_ops_ctl_types=>gc_reopen-amount.
    ELSEIF is_finding-prev_version IS NOT INITIAL AND is_finding-cfg_version IS NOT INITIAL
       AND is_finding-prev_version <> is_finding-cfg_version.
      rv_reason = zif_ca_ops_ctl_types=>gc_reopen-config.
    ENDIF.
  ENDMETHOD.


  METHOD reopen_reason_of_slice.
    DATA(lt_order) = VALUE string_table( ( CONV #( zif_ca_ops_ctl_types=>gc_reopen-new ) )
                                         ( CONV #( zif_ca_ops_ctl_types=>gc_reopen-status ) )
                                         ( CONV #( zif_ca_ops_ctl_types=>gc_reopen-amount ) )
                                         ( CONV #( zif_ca_ops_ctl_types=>gc_reopen-config ) ) ).
    LOOP AT lt_order INTO DATA(lv_reason).
      IF line_exists( it_reasons[ table_line = lv_reason ] ).
        rv_reason = lv_reason.
        RETURN.
      ENDIF.
    ENDLOOP.
    IF iv_status_at_review IS NOT INITIAL
       AND status_rank( iv_derived_status ) > status_rank( iv_status_at_review ).
      rv_reason = zif_ca_ops_ctl_types=>gc_reopen-worse.
    ENDIF.
  ENDMETHOD.


  METHOD is_overdue.
    IF iv_awaiting = abap_false OR iv_business_date > iv_today.
      RETURN.
    ENDIF.
    rv_overdue = xsdbool( iv_business_date < iv_today
                          OR ( iv_cutoff IS NOT INITIAL AND iv_now_time > iv_cutoff ) ).
  ENDMETHOD.


  METHOD refuse.
    rs_decision = VALUE #( allowed = abap_false msgno = iv_msgno v1 = iv_v1 ).
  ENDMETHOD.

ENDCLASS.
