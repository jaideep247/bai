*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_release_policy.clas.abap
*& Purpose:
*& Blocked-line release rules (design 6.2), pure: an approved release turns
*& the block finding of exactly its line and check code into information
*& (still recorded, no longer blocking); run- or statement-level findings
*& are never released; approval needs a second user; a request names line,
*& check code and reason.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - blocked-line release rules</p>
CLASS zcl_cd_ebs_release_policy DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Findings with released blocks downgraded to severity I / action NOTIFY
    CLASS-METHODS apply
      IMPORTING
        it_findings        TYPE zif_cd_ops_types=>tt_finding
        it_releases        TYPE zif_cd_ebs_release_types=>tt_release
      RETURNING
        VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding.

    "! Line keys of releasable block findings (to read their releases)
    CLASS-METHODS releasable_keys
      IMPORTING
        it_findings    TYPE zif_cd_ops_types=>tt_finding
      RETURNING
        VALUE(rt_keys) TYPE zif_cd_ops_types=>tt_object_key.

    CLASS-METHODS can_approve
      IMPORTING
        iv_status          TYPE zif_cd_ebs_release_types=>ty_status
        iv_requested_by    TYPE syuname
        iv_approver        TYPE syuname
      RETURNING
        VALUE(rs_decision) TYPE zif_cd_ops_exc_types=>ty_decision.

    CLASS-METHODS check_request
      IMPORTING
        iv_object_key      TYPE zif_cd_ops_types=>ty_object_key
        iv_check_code      TYPE zif_cd_ops_types=>ty_check_code
        iv_reason          TYPE zif_cd_ops_exc_types=>ty_reason
      RETURNING
        VALUE(rs_decision) TYPE zif_cd_ops_exc_types=>ty_decision.

  PRIVATE SECTION.
    CLASS-METHODS is_releasable
      IMPORTING
        is_finding        TYPE zif_cd_ops_types=>ty_finding
      RETURNING
        VALUE(rv_release) TYPE abap_bool.
ENDCLASS.



CLASS zcl_cd_ebs_release_policy IMPLEMENTATION.

  METHOD apply.
    rt_findings = it_findings.
    CHECK it_releases IS NOT INITIAL.
    LOOP AT rt_findings ASSIGNING FIELD-SYMBOL(<ls_finding>).
      IF is_releasable( <ls_finding> ) = abap_false.
        CONTINUE.
      ENDIF.
      READ TABLE it_releases INTO DATA(ls_release)
        WITH KEY object_key = <ls_finding>-object_key
                 check_code = <ls_finding>-check_code
                 status     = zif_cd_ebs_release_types=>gc_status-approved.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      <ls_finding>-severity  = zif_cd_ops_types=>gc_severity-info.
      <ls_finding>-action    = zif_cd_ops_types=>gc_action-notify.
      <ls_finding>-reference = |{ ls_release-release_uuid }|.
      <ls_finding>-message   = |Released by { ls_release-approved_by } (requested by { ls_release-requested_by }): |
                            && <ls_finding>-message.
    ENDLOOP.
  ENDMETHOD.


  METHOD releasable_keys.
    LOOP AT it_findings INTO DATA(ls_finding).
      IF is_releasable( ls_finding ) = abap_true.
        INSERT ls_finding-object_key INTO TABLE rt_keys.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD can_approve.
    IF iv_status <> zif_cd_ebs_release_types=>gc_status-requested.
      rs_decision-msgno = zif_cd_ebs_release_types=>gc_msg-not_requested.
      rs_decision-v1    = iv_status.
    ELSEIF iv_requested_by = iv_approver.
      rs_decision-msgno = zif_cd_ebs_release_types=>gc_msg-same_user.
      rs_decision-v1    = iv_requested_by.
    ELSE.
      rs_decision-allowed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD check_request.
    IF iv_object_key IS INITIAL OR iv_check_code IS INITIAL.
      rs_decision-msgno = zif_cd_ebs_release_types=>gc_msg-key_missing.
    ELSEIF iv_reason IS INITIAL.
      rs_decision-msgno = zif_cd_ebs_release_types=>gc_msg-no_reason.
    ELSE.
      rs_decision-allowed = abap_true.
    ENDIF.
  ENDMETHOD.


  METHOD is_releasable.
    rv_release = xsdbool( is_finding-object_type = zcl_cd_ebs_finding=>gc_object_type-line
                          AND ( is_finding-severity = zif_cd_ops_types=>gc_severity-block
                             OR is_finding-action   = zif_cd_ops_types=>gc_action-block ) ).
  ENDMETHOD.

ENDCLASS.
