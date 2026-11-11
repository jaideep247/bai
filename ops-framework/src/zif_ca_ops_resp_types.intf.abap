*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_resp_types.intf.abap
*& Purpose:
*& Types and constants of the operations response features of the
*& framework (2026-11-11, docs/OPERATIONS_FEATURES.md): runbook link per
*& check, planned downtime windows, escalation until acknowledged, alert
*& correlation (parent / child exceptions), response-time metrics and the
*& shift handover - parameters of area CA_OPS (name prefixes RUNBOOK_,
*& DOWNTIME_, ESC_, CORR_, METRIC_, SHIFT_), messages 140-159 of ZCA_OPS (153 / 154: ZIF_CA_OPS_CFG_TYPES),
*& rows read by the alert router, the store and the downtime API. No logic.
*& Modification log:
*& 2026-11-11 | Initial version (operations response features).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - response feature types</p>
INTERFACE zif_ca_ops_resp_types
  PUBLIC.

  "! ID of a downtime window (ZCA_OPS_DTWIN-WINDOW_ID) and of a correlation group (ZCA_OPS_FINDING-CORR_ID)
  TYPES ty_uuid TYPE x LENGTH 16.
  "! A scope pattern on the object key (PCRE, complete value, case ignored; blank = any)
  TYPES ty_long_pattern TYPE c LENGTH 70.
  TYPES ty_corr_rule TYPE c LENGTH 10.
  TYPES ty_corr_role TYPE c LENGTH 1.
  "! SHA-1 of area, correlation rule, company code and key value (hex)
  TYPES ty_corr_key TYPE c LENGTH 40.
  TYPES ty_key_fields TYPE c LENGTH 60.
  "! Status of a window (domain ZCA_OPS_DTW_STATUS: translatable texts in the downtime app)
  TYPES ty_window_status TYPE zca_ops_dtw_status.
  TYPES ty_reason TYPE c LENGTH 255.
  TYPES ty_runbook_url TYPE c LENGTH 255.
  TYPES ty_first_action TYPE c LENGTH 120.

  "! ---- Runbook link per check (ZCA_OPS_RUNBOOK) ----
  "! Precedence when several rows match a finding: CHECK_CODE, then GROUP2, then RULE_ID (the same rule in
  "! ZI_CA_OpsFindRunbook); the field names are those of a control's covered checks (ZIF_CA_OPS_CTL_TYPES)
  TYPES:
    BEGIN OF ty_runbook,
      area         TYPE zif_ca_ops_types=>ty_area,
      match_field  TYPE zif_ca_ops_ctl_types=>ty_match_field,
      match_value  TYPE zif_ca_ops_types=>ty_group,
      runbook_url  TYPE ty_runbook_url,
      first_action TYPE ty_first_action,
    END OF ty_runbook.
  TYPES tt_runbook TYPE STANDARD TABLE OF ty_runbook WITH EMPTY KEY.

  "! ---- Planned downtime windows (ZCA_OPS_DTWIN) ----
  "! Status of a window, derived from the approval and the time (never stored): P awaiting approval,
  "! S scheduled (approved, not started), A active, E ended (by its end or by End now)
  CONSTANTS:
    BEGIN OF gc_window_status,
      pending   TYPE ty_window_status VALUE 'P',
      scheduled TYPE ty_window_status VALUE 'S',
      active    TYPE ty_window_status VALUE 'A',
      ended     TYPE ty_window_status VALUE 'E',
    END OF gc_window_status.

  TYPES:
    BEGIN OF ty_window,
      window_id      TYPE ty_uuid,
      area           TYPE zif_ca_ops_types=>ty_area,
      check_pattern  TYPE zif_ca_ops_types=>ty_pattern,
      object_pattern TYPE ty_long_pattern,
      group_pattern  TYPE zif_ca_ops_types=>ty_pattern,
      from_date      TYPE d,
      from_time      TYPE t,
      to_date        TYPE d,
      to_time        TYPE t,
      time_zone      TYPE tznzone,
      from_utc       TYPE timestampl,
      to_utc         TYPE timestampl,
      reason         TYPE ty_reason,
      created_by     TYPE syuname,
      approved_by    TYPE syuname,
    END OF ty_window.
  TYPES tt_window TYPE STANDARD TABLE OF ty_window WITH EMPTY KEY.

  "! The limits a window is validated against (parameters, clock) and the user who acts
  TYPES:
    BEGIN OF ty_window_limits,
      now           TYPE timestampl,
      max_hours     TYPE i,
      tolerance_min TYPE i,
    END OF ty_window_limits.

  "! A refusal of the downtime app or the policy: message of ZCA_OPS and the element it belongs to
  TYPES:
    BEGIN OF ty_problem,
      msgno   TYPE zif_ca_ops_types=>ty_msgno,
      v1      TYPE zif_ca_ops_types=>ty_msgv,
      v2      TYPE zif_ca_ops_types=>ty_msgv,
      element TYPE string,
    END OF ty_problem.
  TYPES tt_problem TYPE STANDARD TABLE OF ty_problem WITH EMPTY KEY.

  "! Element names of the downtime app (CDS element names, upper case) a refusal points to
  CONSTANTS:
    BEGIN OF gc_element,
      to_date       TYPE string VALUE 'TODATE',
      from_date     TYPE string VALUE 'FROMDATE',
      reason        TYPE string VALUE 'REASON',
      check_pattern TYPE string VALUE 'CHECKPATTERN',
      object_pattern TYPE string VALUE 'OBJECTPATTERN',
      group_pattern TYPE string VALUE 'GROUPPATTERN',
      area          TYPE string VALUE 'AREA',
    END OF gc_element.

  "! ---- Alert correlation (ZCA_OPS_CORR, ZCA_OPS_FINDING-CORR_*) ----
  CONSTANTS:
    BEGIN OF gc_corr_role,
      "! The first exception of a correlation key in the window: alerted, with the number of its children
      parent TYPE ty_corr_role VALUE 'P',
      "! A later exception of the key inside the parent's window: recorded, not alerted on its own
      child  TYPE ty_corr_role VALUE 'C',
    END OF gc_corr_role.

  "! Finding fields a correlation key may be built from (ZCA_OPS_CORR-KEY_FIELDS, comma list)
  CONSTANTS:
    BEGIN OF gc_key_field,
      object_key  TYPE string VALUE 'OBJECT_KEY',
      object_type TYPE string VALUE 'OBJECT_TYPE',
      group1      TYPE string VALUE 'GROUP1',
      group2      TYPE string VALUE 'GROUP2',
      rule_id     TYPE string VALUE 'RULE_ID',
      check_code  TYPE string VALUE 'CHECK_CODE',
    END OF gc_key_field.
  "! Between the parts of a correlation key and of the hashed key input (not text)
  CONSTANTS gc_key_separator TYPE string VALUE `|`.
  "! Hash of correlation keys and escalation intents (CL_ABAP_MESSAGE_DIGEST)
  CONSTANTS gc_hash_algorithm TYPE string VALUE `SHA1`.

  TYPES:
    BEGIN OF ty_corr_rule_row,
      area          TYPE zif_ca_ops_types=>ty_area,
      corr_rule     TYPE ty_corr_rule,
      check_pattern TYPE zif_ca_ops_types=>ty_pattern,
      key_fields    TYPE ty_key_fields,
      key_pattern   TYPE ty_long_pattern,
      window_min    TYPE i,
    END OF ty_corr_rule_row.
  TYPES tt_corr_rule TYPE STANDARD TABLE OF ty_corr_rule_row WITH EMPTY KEY.

  "! A new open exception the correlator selected: its position in the store's batch, key and window
  TYPES:
    BEGIN OF ty_corr_item,
      index      TYPE i,
      corr_key   TYPE ty_corr_key,
      window_min TYPE i,
    END OF ty_corr_item.
  TYPES tt_corr_item TYPE STANDARD TABLE OF ty_corr_item WITH EMPTY KEY.

  "! An open parent of a correlation key (stored earlier)
  TYPES:
    BEGIN OF ty_corr_parent,
      corr_key      TYPE ty_corr_key,
      corr_id       TYPE ty_uuid,
      first_seen_at TYPE timestampl,
    END OF ty_corr_parent.
  TYPES tt_corr_parent TYPE STANDARD TABLE OF ty_corr_parent WITH EMPTY KEY.

  "! Marks of a stored finding the alert router reads by the run: planned downtime and correlation
  TYPES:
    BEGIN OF ty_finding_mark,
      object_type  TYPE zif_ca_ops_types=>ty_object_type,
      object_key   TYPE zif_ca_ops_types=>ty_object_key,
      check_code   TYPE zif_ca_ops_types=>ty_check_code,
      company_code TYPE bukrs,
      downtime_id  TYPE ty_uuid,
      corr_id      TYPE ty_uuid,
      corr_role    TYPE ty_corr_role,
    END OF ty_finding_mark.
  TYPES tt_finding_mark TYPE HASHED TABLE OF ty_finding_mark
                        WITH UNIQUE KEY object_type object_key check_code company_code.

  "! Open children of a correlation group (alert of the parent: "n correlated exceptions")
  TYPES:
    BEGIN OF ty_corr_count,
      corr_id  TYPE ty_uuid,
      children TYPE i,
    END OF ty_corr_count.
  TYPES tt_corr_count TYPE HASHED TABLE OF ty_corr_count WITH UNIQUE KEY corr_id.
  TYPES tt_uuid TYPE SORTED TABLE OF ty_uuid WITH UNIQUE KEY table_line.

  "! ---- Escalation until acknowledged (ZCA_OPS_ALRULE-ESC_*, job ZCA_OPS_ESCALATE) ----
  "! An open exception (disposition O, not assigned) that may be escalated: its stored row and finding
  TYPES:
    BEGIN OF ty_esc_candidate,
      run_id        TYPE zif_ca_ops_types=>ty_run_id,
      finding_no    TYPE i,
      first_seen_at TYPE timestampl,
      corr_role     TYPE ty_corr_role,
      finding       TYPE zif_ca_ops_types=>ty_finding,
    END OF ty_esc_candidate.
  TYPES tt_esc_candidate TYPE STANDARD TABLE OF ty_esc_candidate WITH EMPTY KEY.
  TYPES tt_intent_key TYPE SORTED TABLE OF zif_ca_ops_types=>ty_intent_key WITH UNIQUE KEY table_line.

  "! Result of one escalation job (message 156)
  TYPES:
    BEGIN OF ty_escalation_result,
      escalated TYPE i,
      skipped   TYPE i,
      failed    TYPE i,
    END OF ty_escalation_result.

  "! Most escalations of one exception, whatever a rule or the parameter says (bounds the intents read)
  CONSTANTS gc_esc_max_hard TYPE i VALUE 20.
  "! Prefix of the hashed intent of an escalation (an ordinary alert intent never starts with it)
  CONSTANTS gc_esc_intent_prefix TYPE string VALUE `ESC`.
  "! Seconds of a minute / an hour (time arithmetic of windows and escalations)
  CONSTANTS gc_seconds_per_minute TYPE i VALUE 60.
  CONSTANTS gc_minutes_per_hour TYPE i VALUE 60.

  "! Bounds of the time buckets of the response-time metrics in seconds (CDS ZR_CA_OpsExcMetric holds the same
  "! values as literals - CDS cannot read ABAP constants): 15 minutes, 1 hour, 4 hours, 1 day, 3 days, 7 days
  CONSTANTS:
    BEGIN OF gc_metric_seconds,
      quarter_hour TYPE i VALUE 900,
      hour         TYPE i VALUE 3600,
      four_hours   TYPE i VALUE 14400,
      day          TYPE i VALUE 86400,
      three_days   TYPE i VALUE 259200,
      week         TYPE i VALUE 604800,
    END OF gc_metric_seconds.

  "! Parameters of the response features (area CA_OPS)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Time zone in which a downtime window is entered (TTZZ; stored with the window) [UTC]
      downtime_time_zone TYPE zif_ca_ops_types=>ty_param_name VALUE 'DOWNTIME_TIME_ZONE',
      "! Longest downtime window (hours) [24]
      downtime_max_hours TYPE zif_ca_ops_types=>ty_param_name VALUE 'DOWNTIME_MAX_HOURS',
      "! Minutes a window may start in the past when it is saved [15]
      downtime_past_tol  TYPE zif_ca_ops_types=>ty_param_name VALUE 'DOWNTIME_PAST_TOL_MIN',
      "! Retention of ended downtime windows (days, at least 30) [400]
      downtime_retention TYPE zif_ca_ops_types=>ty_param_name VALUE 'DOWNTIME_RETENTION_DAYS',
      "! Escalations of one exception when the rule's ESC_MAX_COUNT is 0 [3]
      esc_max_default    TYPE zif_ca_ops_types=>ty_param_name VALUE 'ESC_MAX_DEFAULT',
      "! Time zone of the month / week of the response-time metrics (CDS ZI_CA_OpsMetricTz) [UTC]
      metric_time_zone   TYPE zif_ca_ops_types=>ty_param_name VALUE 'METRIC_TIME_ZONE',
      "! Time zone of the shift start times (CDS ZI_CA_OpsShiftDef) [UTC]
      shift_time_zone    TYPE zif_ca_ops_types=>ty_param_name VALUE 'SHIFT_TIME_ZONE',
      "! Shift start times (HHMMSS rows) of a team without SHIFT_TIMES_<team> and of exceptions of no team [000000]
      shift_times_default TYPE zif_ca_ops_types=>ty_param_name VALUE 'SHIFT_TIMES_DEFAULT',
    END OF gc_param.

  "! Names completed by a consumer (definitions in its seed files): SHIFT_TIMES_<team> (kind S, TIME rows)
  CONSTANTS:
    BEGIN OF gc_param_prefix,
      shift_times TYPE zif_ca_ops_types=>ty_param_name VALUE 'SHIFT_TIMES_',
    END OF gc_param_prefix.

  CONSTANTS:
    BEGIN OF gc_param_default,
      downtime_time_zone  TYPE zif_ca_ops_types=>ty_param_value VALUE 'UTC',
      downtime_max_hours  TYPE i VALUE 24,
      downtime_past_tol   TYPE i VALUE 15,
      downtime_retention  TYPE i VALUE 400,
      esc_max_default     TYPE i VALUE 3,
      metric_time_zone    TYPE zif_ca_ops_types=>ty_param_value VALUE 'UTC',
      shift_time_zone     TYPE zif_ca_ops_types=>ty_param_value VALUE 'UTC',
      shift_times_default TYPE zif_ca_ops_types=>ty_param_value VALUE '000000',
    END OF gc_param_default.

  "! ZCA_OPS messages of the response features
  CONSTANTS:
    BEGIN OF gc_msg,
      "! Alert log D: findings of a rule in a planned downtime window, recorded and not alerted
      downtime_suppressed TYPE zif_ca_ops_types=>ty_msgno VALUE '140',
      "! Alert log K: correlated children alerted with their parent only
      corr_suppressed     TYPE zif_ca_ops_types=>ty_msgno VALUE '141',
      "! Subject prefix of an escalation (step, maximum, minutes open)
      esc_subject         TYPE zif_ca_ops_types=>ty_msgno VALUE '142',
      window_order        TYPE zif_ca_ops_types=>ty_msgno VALUE '143',
      window_too_long     TYPE zif_ca_ops_types=>ty_msgno VALUE '144',
      window_in_past      TYPE zif_ca_ops_types=>ty_msgno VALUE '145',
      window_overlap      TYPE zif_ca_ops_types=>ty_msgno VALUE '146',
      window_four_eyes    TYPE zif_ca_ops_types=>ty_msgno VALUE '147',
      window_approved     TYPE zif_ca_ops_types=>ty_msgno VALUE '148',
      window_ended        TYPE zif_ca_ops_types=>ty_msgno VALUE '149',
      window_pattern      TYPE zif_ca_ops_types=>ty_msgno VALUE '150',
      window_reason       TYPE zif_ca_ops_types=>ty_msgno VALUE '151',
      not_authorised      TYPE zif_ca_ops_types=>ty_msgno VALUE '152',
      corr_id_failed      TYPE zif_ca_ops_types=>ty_msgno VALUE '155',
      "! Result of the escalation job
      esc_result          TYPE zif_ca_ops_types=>ty_msgno VALUE '156',
      "! Alert log D of a run-level trigger (RAG, abort) inside an area-wide window
      downtime_run_level  TYPE zif_ca_ops_types=>ty_msgno VALUE '157',
      window_incomplete   TYPE zif_ca_ops_types=>ty_msgno VALUE '158',
      "! End now of a window that awaits approval (change or delete it instead)
      window_pending      TYPE zif_ca_ops_types=>ty_msgno VALUE '159',
    END OF gc_msg.

ENDINTERFACE.
