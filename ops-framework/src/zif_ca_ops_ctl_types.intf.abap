*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_ctl_types.intf.abap
*& Purpose:
*& Types and constants of the control register and the daily control
*& review (sign-off per business date): status codes and their ranks, the
*& severity -> status mapping, the finding fields a control may select,
*& the review row, the input of a sign-off, parameters of area CA_OPS
*& (time zone of the business date, teams) and the messages of the review.
*& The status of a control is derived from findings (CDS ZI_CA_OpsCtlFindDay
*& and ZCL_CA_OPS_REVIEW_POLICY, same rule), never stored. No logic.
*& Modification log:
*& 2026-11-10 | Initial version (control register and daily control review).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - control review types</p>
INTERFACE zif_ca_ops_ctl_types
  PUBLIC.

  TYPES ty_control_id TYPE c LENGTH 20.
  "! H healthy, W watch, A action required (domain ZCA_OPS_CTL_STATUS: translatable texts)
  TYPES ty_status TYPE c LENGTH 1.
  TYPES ty_text TYPE c LENGTH 255.
  TYPES ty_match_field TYPE c LENGTH 10.

  "! Status of a control on a business date (labels: fixed values of domain ZCA_OPS_CTL_STATUS)
  CONSTANTS:
    BEGIN OF gc_status,
      healthy TYPE ty_status VALUE 'H',
      watch   TYPE ty_status VALUE 'W',
      action  TYPE ty_status VALUE 'A',
    END OF gc_status.

  "! Rank of a status (higher = worse); the CDS views use the same ranks
  CONSTANTS:
    BEGIN OF gc_rank,
      healthy TYPE i VALUE 0,
      watch   TYPE i VALUE 1,
      action  TYPE i VALUE 2,
    END OF gc_rank.

  "! Field of a finding a covered-check row (ZCA_OPS_CTLCHK-MATCH_FIELD) compares, exact value
  CONSTANTS:
    BEGIN OF gc_match_field,
      rule_id    TYPE ty_match_field VALUE 'RULE_ID',
      check_code TYPE ty_match_field VALUE 'CHECK_CODE',
      group2     TYPE ty_match_field VALUE 'GROUP2',
    END OF gc_match_field.

  "! A sign-off of one control on one business date (ZCA_OPS_REVIEW)
  TYPES:
    BEGIN OF ty_review,
      area             TYPE zif_ca_ops_types=>ty_area,
      control_id       TYPE ty_control_id,
      business_date    TYPE d,
      status_at_review TYPE ty_status,
      review_result    TYPE ty_status,
      evidence_run     TYPE zif_ca_ops_types=>ty_run_id,
      reviewed_by      TYPE syuname,
      reviewed_at      TYPE timestampl,
      observation      TYPE ty_text,
      next_action      TYPE ty_text,
      last_changed_at  TYPE timestampl,
    END OF ty_review.
  TYPES tt_review TYPE STANDARD TABLE OF ty_review WITH EMPTY KEY.

  "! What the review policy decides a sign-off on: the derived status and what the reviewer entered
  TYPES:
    BEGIN OF ty_review_input,
      derived_status TYPE ty_status,
      "! Blank = the reviewer confirms the derived status
      review_result  TYPE ty_status,
      observation    TYPE ty_text,
      next_action    TYPE ty_text,
    END OF ty_review_input.

  "! The state "awaiting review" is decided on (the CDS views apply the same rule)
  TYPES:
    BEGIN OF ty_await_state,
      active           TYPE abap_bool,
      derived_status   TYPE ty_status,
      "! Latest finding of the control's checks on the business date (UTC)
      last_finding_at  TYPE timestampl,
      "! Blank when the control was not signed off for the date
      status_at_review TYPE ty_status,
      reviewed_at      TYPE timestampl,
    END OF ty_await_state.

  "! Parameters of the control review (area CA_OPS)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Time zone of the business date, the review cut-off and the times shown (TTZZ) [UTC]
      time_zone TYPE zif_ca_ops_types=>ty_param_name VALUE 'CONTROL_TIME_ZONE',
      "! Teams a control may name (comma list) [ONSITE,OFFSHORE]
      teams     TYPE zif_ca_ops_types=>ty_param_name VALUE 'CONTROL_TEAMS',
    END OF gc_param.

  CONSTANTS:
    BEGIN OF gc_param_default,
      time_zone TYPE zif_ca_ops_types=>ty_param_value VALUE 'UTC',
      teams     TYPE zif_ca_ops_types=>ty_param_value VALUE 'ONSITE,OFFSHORE',
    END OF gc_param_default.

  "! A runbook link: http or https, no blanks (PCRE, whole value, case ignored)
  CONSTANTS gc_url_pattern TYPE string VALUE `https?://\S+`.

  "! ZCA_OPS messages of the daily control review
  CONSTANTS:
    BEGIN OF gc_msg,
      "! Action required: observation and next action are mandatory
      action_text_missing TYPE symsgno VALUE '076',
      "! The reviewer's result differs from the derived status: an observation is mandatory
      result_differs      TYPE symsgno VALUE '077',
      "! The result is not a control status
      result_invalid      TYPE symsgno VALUE '078',
      "! The review of the control and date is locked by another user
      review_locked       TYPE symsgno VALUE '079',
      "! The lock service failed for the review of the control and date
      lock_failed         TYPE symsgno VALUE '080',
    END OF gc_msg.

ENDINTERFACE.
