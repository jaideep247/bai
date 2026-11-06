*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_suppression.clas.abap
*& Purpose:
*& Health-check suppression rules (design 6.3), pure: an active suppression
*& (status A, today within valid from / to) of a check turns the matching
*& findings into information - still listed, not alerted, not scored.
*& Matching: check ID, object-key pattern (blank = all), company code
*& (blank = all) found in the object key. Long suppressions need a second
*& user; the creator cannot approve.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - suppression of known findings</p>
CLASS zcl_cd_hck_suppression DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Findings of one check result with active suppressions applied (group2 = check ID)
    CLASS-METHODS apply
      IMPORTING
        it_findings        TYPE zif_cd_ops_types=>tt_finding
        it_suppressions    TYPE zif_cd_hck_suppress_types=>tt_suppression
        iv_today           TYPE d
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding.

    "! More days than allowed without a second user?
    CLASS-METHODS needs_approval
      IMPORTING
        iv_from            TYPE d
        iv_to              TYPE d
        iv_max_days        TYPE i
      RETURNING
        VALUE(rv_approval) TYPE abap_bool.

    CLASS-METHODS can_approve
      IMPORTING
        iv_status          TYPE zif_cd_hck_suppress_types=>ty_status
        iv_created_by      TYPE syuname
        iv_approver        TYPE syuname
      RETURNING
        VALUE(rs_decision) TYPE zif_cd_ops_exc_types=>ty_decision.

    "! A request names the check, a reason and a period that does not end before it starts
    CLASS-METHODS check_request
      IMPORTING
        iv_check_id        TYPE zif_cd_hck_types=>ty_check_id
        iv_reason          TYPE zif_cd_ops_exc_types=>ty_reason
        iv_from            TYPE d
        iv_to              TYPE d
      RETURNING
        VALUE(rs_decision) TYPE zif_cd_ops_exc_types=>ty_decision.

  PRIVATE SECTION.
    CLASS-METHODS matches
      IMPORTING
        is_finding      TYPE zif_cd_ops_types=>ty_finding
        is_suppression  TYPE zif_cd_hck_suppress_types=>ty_suppression
        iv_today        TYPE d
      RETURNING
        VALUE(rv_match) TYPE abap_bool.
ENDCLASS.



CLASS zcl_cd_hck_suppression IMPLEMENTATION.

  METHOD apply.
    rt_findings = it_findings.
    CHECK it_suppressions IS NOT INITIAL.
    LOOP AT rt_findings ASSIGNING FIELD-SYMBOL(<ls_finding>)
         WHERE severity <> zif_cd_ops_types=>gc_severity-info.
      LOOP AT it_suppressions ASSIGNING FIELD-SYMBOL(<ls_suppression>).
        IF matches( is_finding = <ls_finding> is_suppression = <ls_suppression> iv_today = iv_today ) = abap_false.
          CONTINUE.
        ENDIF.
        <ls_finding>-severity = zif_cd_ops_types=>gc_severity-info.
        <ls_finding>-action   = zif_cd_ops_types=>gc_action-notify.
        <ls_finding>-message  = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-suppressed_until_by
                                                       iv_v1    = |{ <ls_suppression>-valid_to DATE = ISO }|
                                                       iv_v2    = <ls_suppression>-created_by
                                                       iv_tail  = CONV #( <ls_finding>-message ) ).
        EXIT.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD needs_approval.
    rv_approval = xsdbool( iv_to - iv_from > iv_max_days ).
  ENDMETHOD.


  METHOD can_approve.
    IF iv_status <> zif_cd_hck_suppress_types=>gc_status-requested.
      rs_decision-msgno = zif_cd_hck_suppress_types=>gc_msg-not_requested.
      rs_decision-v1    = iv_status.
    ELSEIF iv_created_by = iv_approver.
      rs_decision-msgno = zif_cd_hck_suppress_types=>gc_msg-same_user.
      rs_decision-v1    = iv_created_by.
    ELSE.
      rs_decision-allowed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD check_request.
    IF iv_check_id IS INITIAL.
      rs_decision-msgno = zif_cd_hck_suppress_types=>gc_msg-check_missing.
    ELSEIF iv_reason IS INITIAL.
      rs_decision-msgno = zif_cd_hck_suppress_types=>gc_msg-no_reason.
    ELSEIF iv_from IS INITIAL OR iv_to IS INITIAL OR iv_to < iv_from.
      rs_decision-msgno = zif_cd_hck_suppress_types=>gc_msg-period_invalid.
    ELSE.
      rs_decision-allowed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD matches.
    rv_match = xsdbool(
         is_suppression-status = zif_cd_hck_suppress_types=>gc_status-active
     AND is_suppression-check_id = is_finding-group2
     AND iv_today >= is_suppression-valid_from
     AND iv_today <= is_suppression-valid_to
     AND ( is_suppression-key_pattern IS INITIAL OR is_finding-object_key CP is_suppression-key_pattern )
     AND ( is_suppression-bukrs IS INITIAL OR is_finding-object_key CS is_suppression-bukrs ) ).
  ENDMETHOD.

ENDCLASS.
