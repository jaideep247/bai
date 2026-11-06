*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_types.intf.abap
*& Purpose:
*& Shared by Health Check (HCK), File Monitoring (FMON) and EBS Validation (EBS).
*& Every finding of every payment engine area is written to one store (ZCD_OPS_RUN / ZCD_OPS_FINDING).
*& B = block (never post), E = error, W = warning, I = information
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Payment engine area CORE and exception dispositions.
*& 2026-11-06 | Object-key and group sets (reconciliation scope).
*& 2026-11-06 | Message class constant and message number / variable types (texts as messages).
*& 2026-11-06 | Texts moved to message class ZCD_OPS (phase 5: no hardcoded texts).
*& 2026-11-06 | Check codes, message class and texts as constants / ZCD_OPS messages (phase 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - shared types and constants</p>
"! Shared by Health Check (HCK), File Monitoring (FMON) and EBS Validation (EBS).
"! Every finding of every payment engine area is written to one store (ZCD_OPS_RUN / ZCD_OPS_FINDING).
INTERFACE zif_cd_ops_types
  PUBLIC.

  TYPES ty_pe_area      TYPE c LENGTH 4.
  TYPES ty_severity    TYPE c LENGTH 1.
  TYPES ty_rag         TYPE c LENGTH 1.
  TYPES ty_run_status  TYPE c LENGTH 1.
  TYPES ty_rule_id     TYPE c LENGTH 10.
  TYPES ty_check_code  TYPE c LENGTH 30.
  TYPES ty_object_type TYPE c LENGTH 10.
  TYPES ty_object_key  TYPE c LENGTH 70.
  TYPES ty_group       TYPE c LENGTH 35.
  TYPES ty_reference   TYPE c LENGTH 35.
  TYPES ty_message     TYPE c LENGTH 255.
  "! Number of a message of class ZCD_OPS (every user-facing text of the suite is one)
  TYPES ty_msgno       TYPE n LENGTH 3.
  "! Message variable (&1 .. &4)
  TYPES ty_msgv        TYPE c LENGTH 50.
  "! Message class holding every text of the suite (translatable, SE91)
  CONSTANTS gc_message_class TYPE c LENGTH 20 VALUE 'ZCD_OPS'.
  "! Message type used when a text is only built, never shown
  CONSTANTS gc_msgty_info TYPE c LENGTH 1 VALUE 'I'.
  "! Message 000 (&1 &2 &3 &4): carries a text that is already a message
  CONSTANTS gc_msgno_free TYPE ty_msgno VALUE '000'.
  TYPES ty_action      TYPE c LENGTH 10.
  TYPES ty_param_name  TYPE c LENGTH 30.
  TYPES ty_param_value TYPE c LENGTH 255.
  TYPES ty_variant     TYPE c LENGTH 30.
  TYPES ty_amount      TYPE p LENGTH 12 DECIMALS 2.
  TYPES ty_currency    TYPE c LENGTH 5.
  TYPES ty_class_name  TYPE c LENGTH 30.
  TYPES ty_run_id      TYPE x LENGTH 16.

  CONSTANTS:
    BEGIN OF gc_pe_area,
      health_check TYPE ty_pe_area VALUE 'HCK',
      file_monitor TYPE ty_pe_area VALUE 'FMON',
      ebs          TYPE ty_pe_area VALUE 'EBS',
      "! Cross-payment engine area objects: alerting, parameters, purge (authorisation object ZCD_OPS)
      core         TYPE ty_pe_area VALUE 'CORE',
    END OF gc_pe_area.

  "! ZCD_OPS_FINDING-DISPOSITION - exception lifecycle
  TYPES ty_disposition TYPE c LENGTH 1.
  CONSTANTS:
    BEGIN OF gc_disposition,
      open        TYPE ty_disposition VALUE 'O',
      information TYPE ty_disposition VALUE 'I',
      assigned    TYPE ty_disposition VALUE 'A',
      resolved    TYPE ty_disposition VALUE 'R',
      waived      TYPE ty_disposition VALUE 'W',
      "! Replaced by the same exception in a later run (carry-forward)
      superseded  TYPE ty_disposition VALUE 'S',
    END OF gc_disposition.

  "! B = block (never post), E = error, W = warning, I = information
  CONSTANTS:
    BEGIN OF gc_severity,
      block   TYPE ty_severity VALUE 'B',
      error   TYPE ty_severity VALUE 'E',
      warning TYPE ty_severity VALUE 'W',
      info    TYPE ty_severity VALUE 'I',
    END OF gc_severity.

  CONSTANTS:
    BEGIN OF gc_rag,
      red   TYPE ty_rag VALUE 'R',
      amber TYPE ty_rag VALUE 'A',
      green TYPE ty_rag VALUE 'G',
      grey  TYPE ty_rag VALUE ' ',
    END OF gc_rag.

  CONSTANTS:
    BEGIN OF gc_run_status,
      running TYPE ty_run_status VALUE 'R',
      success TYPE ty_run_status VALUE 'S',
      warning TYPE ty_run_status VALUE 'W',
      error   TYPE ty_run_status VALUE 'E',
      aborted TYPE ty_run_status VALUE 'A',
    END OF gc_run_status.

  "! Action taken for a finding (master prompt: ZCD_BTC_RULE-ACTION)
  CONSTANTS:
    BEGIN OF gc_action,
      auto_post  TYPE ty_action VALUE 'AUTO_POST',
      exception  TYPE ty_action VALUE 'EXCEPTION',
      block      TYPE ty_action VALUE 'BLOCK',
      notify     TYPE ty_action VALUE 'NOTIFY',
      on_account TYPE ty_action VALUE 'ON_ACCOUNT',
    END OF gc_action.

  TYPES:
    BEGIN OF ty_finding,
      object_type TYPE ty_object_type,
      object_key  TYPE ty_object_key,
      group1      TYPE ty_group,
      group2      TYPE ty_group,
      rule_id     TYPE ty_rule_id,
      check_code  TYPE ty_check_code,
      severity    TYPE ty_severity,
      action      TYPE ty_action,
      amount      TYPE ty_amount,
      currency    TYPE ty_currency,
      reference   TYPE ty_reference,
      message     TYPE ty_message,
      details     TYPE string,
    END OF ty_finding.
  TYPES tt_finding TYPE STANDARD TABLE OF ty_finding WITH EMPTY KEY.

  "! Scope of a run for exception reconciliation: object keys or groups (GROUP2) evaluated
  TYPES tt_object_key TYPE SORTED TABLE OF ty_object_key WITH UNIQUE KEY table_line.
  TYPES tt_group      TYPE SORTED TABLE OF ty_group WITH UNIQUE KEY table_line.

  TYPES:
    BEGIN OF ty_run,
      run_id        TYPE ty_run_id,
      pe_area        TYPE ty_pe_area,
      variant       TYPE ty_variant,
      test_mode     TYPE abap_bool,
      started_at    TYPE timestampl,
      ended_at      TYPE timestampl,
      status        TYPE ty_run_status,
      rag           TYPE ty_rag,
      total_items   TYPE i,
      passed_items  TYPE i,
      failed_items  TYPE i,
      blocked_items TYPE i,
      warning_items TYPE i,
      finding_count TYPE i,
      runtime_ms    TYPE i,
      message       TYPE ty_message,
      created_by    TYPE syuname,
    END OF ty_run.
  TYPES tt_run TYPE STANDARD TABLE OF ty_run WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_kv,
      name  TYPE ty_param_name,
      value TYPE ty_param_value,
    END OF ty_kv.
  TYPES tt_kv TYPE SORTED TABLE OF ty_kv WITH UNIQUE KEY name.

  "! ---- Alert router (ZCD_OPS_ALERT_RULE / _CHN / _LOG) ----
  TYPES ty_channel     TYPE c LENGTH 10.
  TYPES ty_pattern     TYPE c LENGTH 35.
  TYPES ty_alert_dest  TYPE c LENGTH 255.

  CONSTANTS:
    BEGIN OF gc_channel,
      email  TYPE ty_channel VALUE 'EMAIL',
      applog TYPE ty_channel VALUE 'APPLOG',
      http   TYPE ty_channel VALUE 'HTTP',
    END OF gc_channel.

  "! Delivery status in ZCD_OPS_ALERT_LOG
  CONSTANTS:
    BEGIN OF gc_alert_status,
      sent      TYPE c LENGTH 1 VALUE 'S',
      failed    TYPE c LENGTH 1 VALUE 'F',
      throttled TYPE c LENGTH 1 VALUE 'T',
      quiet     TYPE c LENGTH 1 VALUE 'Q',
    END OF gc_alert_status.

  "! One alert rule: which findings of which payment engine area go to which channel
  TYPES:
    BEGIN OF ty_alert_rule,
      rule_id         TYPE ty_rule_id,
      pe_area          TYPE ty_pe_area,
      "! Lowest severity that triggers (B, E, W, I)
      min_severity    TYPE ty_severity,
      "! CP patterns on the finding; blank = any
      rule_pattern    TYPE ty_pattern,
      check_pattern   TYPE ty_pattern,
      group1_pattern  TYPE ty_pattern,
      group2_pattern  TYPE ty_pattern,
      "! Also alert when the run ends with this RAG or worse (blank = no run-level alert)
      min_rag         TYPE ty_rag,
      on_abort        TYPE abap_bool,
      channel         TYPE ty_channel,
      "! E-mail list, SM59 destination or log object - meaning depends on the channel
      destination     TYPE ty_alert_dest,
      "! X = one digest per rule and run; blank = one message per finding
      digest          TYPE abap_bool,
      max_items       TYPE i,
      throttle_min    TYPE i,
      quiet_from      TYPE t,
      quiet_to        TYPE t,
      "! After n consecutive alerting runs add the escalation destination
      escalate_after  TYPE i,
      escalation_dest TYPE ty_alert_dest,
      active          TYPE abap_bool,
    END OF ty_alert_rule.
  TYPES tt_alert_rule TYPE STANDARD TABLE OF ty_alert_rule WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_alert_channel,
      channel     TYPE ty_channel,
      class_name  TYPE ty_class_name,
      "! Default destination when the rule has none
      destination TYPE ty_alert_dest,
      active      TYPE abap_bool,
    END OF ty_alert_channel.
  TYPES tt_alert_channel TYPE STANDARD TABLE OF ty_alert_channel WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_alert_message,
      alert_id    TYPE ty_run_id,
      rule_id     TYPE ty_rule_id,
      channel     TYPE ty_channel,
      destination TYPE ty_alert_dest,
      pe_area      TYPE ty_pe_area,
      run_id      TYPE ty_run_id,
      severity    TYPE ty_severity,
      subject     TYPE ty_message,
      html        TYPE string,
      text        TYPE string,
      item_count  TYPE i,
    END OF ty_alert_message.
  TYPES tt_alert_message TYPE STANDARD TABLE OF ty_alert_message WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_alert_log,
      alert_id    TYPE ty_run_id,
      rule_id     TYPE ty_rule_id,
      channel     TYPE ty_channel,
      run_id      TYPE ty_run_id,
      pe_area      TYPE ty_pe_area,
      sent_at     TYPE timestampl,
      status      TYPE c LENGTH 1,
      destination TYPE ty_alert_dest,
      subject     TYPE ty_message,
      error       TYPE ty_message,
    END OF ty_alert_log.
  TYPES tt_alert_log TYPE STANDARD TABLE OF ty_alert_log WITH EMPTY KEY.

  "! Message numbers (class ZCD_OPS) of this area's user-facing texts
  CONSTANTS:
    BEGIN OF gc_msg,
      alert_subject_run           TYPE zif_cd_ops_types=>ty_msgno VALUE '002',
      alert_subject_count         TYPE zif_cd_ops_types=>ty_msgno VALUE '003',
      alert_run_line_1            TYPE zif_cd_ops_types=>ty_msgno VALUE '004',
      alert_run_line_2            TYPE zif_cd_ops_types=>ty_msgno VALUE '005',
      alert_more_findings         TYPE zif_cd_ops_types=>ty_msgno VALUE '006',
      channel_inactive            TYPE zif_cd_ops_types=>ty_msgno VALUE '007',
      passed_on_rerun             TYPE zif_cd_ops_types=>ty_msgno VALUE '008',
    END OF gc_msg.

ENDINTERFACE.
