*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_types.intf.abap
*& Purpose:
*& Shared types and constants of the operations framework ZCA_OPS: runs,
*& findings, severities, RAG, run statuses, actions, exception
*& dispositions, error classes, job link, logical file paths, alerting
*& (rules, channels, messages, log) and the framework parameters of area
*& CA_OPS. Every consumer writes its findings to one store (ZCA_OPS_RUN /
*& ZCA_OPS_FINDING); the area of a run is a parameter area of ZCA_PARAM
*& (ZCA_PARAM_AREA). B = block, E = error, W = warning, I = information.
*& No logic.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Area CORE and exception dispositions; object-key and group sets; message class constant
*&            | and message number / variable types (texts as messages).
*& 2026-11-06 | Alert claim / repeat / partial statuses, intent key, SLG1 external ID, escalation override
*&            | (A17, A45, A46); plug-in interface names for the factory interface check (A62); run status
*&            | NO_DATA (A68).
*& 2026-11-07 | Parameter names / prefixes / defaults (GC_PARAM, GC_PARAM_PREFIX, GC_PARAM_DEFAULT);
*&            | TT_PARAM_RANGE and GC_RANGE; TT_PARAM_ERROR.
*& 2026-11-10 | Error class (GC_ERROR_CLASS), job link of a run (TY_RUN-JOBNAME / JOBCOUNT / SYSID), logical
*&            | file name / path types, S_DATASET activities.
*& 2026-11-10 | Moved from zif_ca_ops_types to the reusable framework ZCA_OPS (generic part of the split):
*&            | area = parameter area of ZCA_PARAM (TY_AREA, field AREA, was AREA CHAR 4); parameters in
*&            | area CA_OPS (GC_PARAM_AREA); message class ZCA_OPS; version constants (GC_VERSION,
*&            | GC_PARAM_MIN_VERSION); alert section plug-in interface; purge target types.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - shared types and constants</p>
"! Runs, findings, severities, RAG, dispositions, alerting and parameters of the
"! operations framework ZCA_OPS. The area of a run is a parameter area of ZCA_PARAM.
INTERFACE zif_ca_ops_types
  PUBLIC.

  "! Release of the operations framework (CHANGELOG.md)
  CONSTANTS gc_version TYPE string VALUE `1.0.0`.
  "! Lowest release of the parameter framework ZCA_PARAM this release needs
  "! (ZIF_CA_PARAM_TYPES=>GC_VERSION; checked once per session, ZCL_CA_OPS_FACTORY=>CHECK_VERSION)
  CONSTANTS gc_param_min_version TYPE string VALUE `1.1.0`.

  "! Area of a run, finding, alert rule or lock: a parameter area of ZCA_PARAM (ZCA_PARAM_AREA)
  TYPES ty_area        TYPE zif_ca_param_types=>ty_area.
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
  TYPES ty_intent_key  TYPE c LENGTH 40.
  TYPES ty_extnumber   TYPE c LENGTH 100.
  "! Number of a message (every user-facing text is a message of a message class)
  TYPES ty_msgno       TYPE n LENGTH 3.
  "! Message variable (&1 .. &4)
  TYPES ty_msgv        TYPE c LENGTH 50.
  "! Message class holding every text of the framework (translatable, SE91)
  CONSTANTS gc_message_class TYPE symsgid VALUE 'ZCA_OPS'.
  "! Message type used when a text is only built, never shown
  CONSTANTS gc_msgty_info TYPE c LENGTH 1 VALUE 'I'.
  CONSTANTS gc_msgty_error TYPE c LENGTH 1 VALUE 'E'.
  "! Time of day limits and the time zone used for UTC timestamps
  CONSTANTS:
    BEGIN OF gc_time,
      day_start TYPE t VALUE '000000',
      day_end   TYPE t VALUE '235959',
    END OF gc_time.
  CONSTANTS gc_time_zone_utc TYPE tznzone VALUE 'UTC'.

  TYPES ty_action      TYPE c LENGTH 10.
  TYPES ty_param_name  TYPE c LENGTH 30.
  "! Value of a parameter (ZCA_PARAM_VAL-LOW, CHAR 255) and its select-option style view
  TYPES ty_param_value TYPE c LENGTH 255.
  TYPES tt_param_range TYPE RANGE OF ty_param_value.

  "! The framework's own parameter area in ZCA_PARAM (config/param_areas.csv)
  CONSTANTS gc_param_area TYPE ty_area VALUE 'CA_OPS'.

  "! Framework parameters (area CA_OPS): alerting, purge, exception SLA
  CONSTANTS:
    BEGIN OF gc_param,
      "! Recipients when ALERT_<route> is blank
      alert_default    TYPE ty_param_name VALUE 'ALERT_DEFAULT',
      "! Escalation look-back window of an alert rule in hours [24]
      alert_window_h   TYPE ty_param_name VALUE 'ALERT_ESCALATION_WINDOW_H',
      "! Plug-in class of a consumer's own section of the alert message (ZIF_CA_OPS_ALERT_SECTION;
      "! blank = none)
      alert_section    TYPE ty_param_name VALUE 'ALERT_SECTION_CLASS',
      "! Rows deleted per purge package [1000]
      purge_package    TYPE ty_param_name VALUE 'PURGE_PACKAGE_SIZE',
      "! SLA days of an exception when SLA_DAYS_<area>_<severity> is blank [1]
      sla_days_default TYPE ty_param_name VALUE 'SLA_DAYS_DEFAULT',
    END OF gc_param.

  "! Parameter-name prefixes completed at run time (ALERT_<route>, RETENTION_DAYS_<target>,
  "! SLA_DAYS_<area>_<severity>)
  CONSTANTS:
    BEGIN OF gc_param_prefix,
      alert          TYPE ty_param_name VALUE 'ALERT_',
      retention_days TYPE ty_param_name VALUE 'RETENTION_DAYS_',
      sla_days       TYPE ty_param_name VALUE 'SLA_DAYS_',
    END OF gc_param_prefix.

  "! Name prefixes of the framework parameters: a name with one of them is read in area CA_OPS
  "! unless the caller names the area (ZCL_CA_OPS_PARAMS=>AREA_OF; consumers add their own)
  CONSTANTS:
    BEGIN OF gc_param_area_prefix,
      alert     TYPE ty_param_name VALUE 'ALERT_',
      sla       TYPE ty_param_name VALUE 'SLA_',
      retention TYPE ty_param_name VALUE 'RETENTION_',
      purge     TYPE ty_param_name VALUE 'PURGE_',
    END OF gc_param_area_prefix.

  "! Delivered defaults of the framework parameters
  CONSTANTS:
    BEGIN OF gc_param_default,
      alert_window_h TYPE i VALUE 24,
      purge_package  TYPE i VALUE 1000,
      sla_days       TYPE i VALUE 1,
      "! Retention of a purge target whose parameter cannot be read (the definition default applies first)
      retention_days TYPE i VALUE 400,
    END OF gc_param_default.

  "! A name prefix and the area its parameters are read in (ZIF_CA_OPS_PARAMS=>ADD_PREFIXES)
  TYPES:
    BEGIN OF ty_param_prefix,
      prefix TYPE ty_param_name,
      area   TYPE ty_area,
    END OF ty_param_prefix.
  TYPES tt_param_prefix TYPE STANDARD TABLE OF ty_param_prefix WITH EMPTY KEY.

  "! SALV exception column values (traffic light)
  CONSTANTS:
    BEGIN OF gc_light,
      red    TYPE c LENGTH 1 VALUE '1',
      yellow TYPE c LENGTH 1 VALUE '2',
      green  TYPE c LENGTH 1 VALUE '3',
    END OF gc_light.
  "! Sign / option of a select-option style range row (ZIF_CA_OPS_PARAMS=>GET_RANGE)
  CONSTANTS:
    BEGIN OF gc_range,
      sign_include TYPE c LENGTH 1 VALUE 'I',
      sign_exclude TYPE c LENGTH 1 VALUE 'E',
      option_equal TYPE c LENGTH 2 VALUE 'EQ',
    END OF gc_range.
  TYPES ty_variant     TYPE c LENGTH 30.
  TYPES ty_amount      TYPE p LENGTH 12 DECIMALS 2.
  TYPES ty_currency    TYPE c LENGTH 5.
  TYPES ty_class_name  TYPE c LENGTH 30.

  "! Plug-in interfaces of the framework (passed to ZCL_CA_OPS_FACTORY=>GET_PLUGIN, A62)
  CONSTANTS:
    BEGIN OF gc_plugin_intf,
      alert_channel TYPE ty_class_name VALUE 'ZIF_CA_OPS_ALERT_CHANNEL',
      alert_section TYPE ty_class_name VALUE 'ZIF_CA_OPS_ALERT_SECTION',
      purge_target  TYPE ty_class_name VALUE 'ZIF_CA_OPS_PURGE_TARGET',
    END OF gc_plugin_intf.
  TYPES ty_run_id      TYPE x LENGTH 16.

  "! Error class of a failure (ZCA_OPS_FINDING-ERROR_CLASS): only TRANSIENT may be retried
  "! (lock, timeout, database); DATA, CONFIG and CODE go to their owner (ZCL_CA_OPS_UTIL=>ERROR_CLASS)
  TYPES ty_error_class TYPE c LENGTH 10.
  CONSTANTS:
    BEGIN OF gc_error_class,
      transient TYPE ty_error_class VALUE 'TRANSIENT',
      data      TYPE ty_error_class VALUE 'DATA',
      config    TYPE ty_error_class VALUE 'CONFIG',
      code      TYPE ty_error_class VALUE 'CODE',
    END OF gc_error_class.

  "! Classification of ZCL_CA_OPS_UTIL=>ERROR_CLASS: ZCA_OPS message numbers of lock / timeout and of
  "! configuration / authorisation failures (comma lists - extend them with every new message of the
  "! kind; a consumer classifies its own messages in a redefinition of ZCX_CA_OPS_ERROR=>CLASSIFY),
  "! exception classes of the database layer (TRANSIENT) and the prefix of runtime errors (CODE)
  CONSTANTS:
    BEGIN OF gc_error_rule,
      transient_msgno TYPE string VALUE `040,042`,
      config_msgno    TYPE string VALUE `007,021,027,030,031,032,033,041,043,044,807,808,809`,
      transient_class TYPE string VALUE `CX_SY_OPEN_SQL_DB,CX_SQL_EXCEPTION`,
      code_prefix     TYPE string VALUE `CX_SY_`,
    END OF gc_error_rule.

  "! Batch job of a run (SM37 link) and the system it ran in (ZCL_CA_OPS_UTIL=>JOB_LINK)
  TYPES:
    BEGIN OF ty_job_link,
      jobname  TYPE btcjob,
      jobcount TYPE btcjobcnt,
      sysid    TYPE sysysid,
    END OF ty_job_link.

  "! Application server files only through a logical path of transaction FILE (no directory from a
  "! user): logical path for FILE_GET_NAME_USING_PATH and the logical file name it is validated
  "! against (FILE_VALIDATE_NAME); the consumer names both (ZCL_CA_OPS_FILE_PATH=>PHYSICAL)
  TYPES:
    BEGIN OF ty_logical_file,
      path TYPE pathintern,
      file TYPE fileintern,
    END OF ty_logical_file.
  "! S_DATASET activity of AUTHORITY_CHECK_DATASET
  TYPES ty_dataset_activity TYPE c LENGTH 8.
  CONSTANTS:
    BEGIN OF gc_dataset_activity,
      read  TYPE ty_dataset_activity VALUE 'READ',
      write TYPE ty_dataset_activity VALUE 'WRITE',
    END OF gc_dataset_activity.

  "! ZCA_OPS_FINDING-DISPOSITION - exception lifecycle
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

  "! B = block, E = error, W = warning, I = information
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
      "! Completed, but the source delivered nothing to evaluate (audit A68) - RAG grey, never green
      no_data TYPE ty_run_status VALUE 'N',
    END OF gc_run_status.

  "! Action taken for a finding
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
      "! TRANSIENT / DATA / CONFIG / CODE for a finding raised at a catch boundary (else blank)
      error_class TYPE ty_error_class,
    END OF ty_finding.
  TYPES tt_finding TYPE STANDARD TABLE OF ty_finding WITH EMPTY KEY.

  "! Scope of a run for exception reconciliation: object keys or groups (GROUP2) evaluated
  TYPES tt_object_key TYPE SORTED TABLE OF ty_object_key WITH UNIQUE KEY table_line.
  TYPES tt_group      TYPE SORTED TABLE OF ty_group WITH UNIQUE KEY table_line.

  TYPES:
    BEGIN OF ty_run,
      run_id        TYPE ty_run_id,
      area          TYPE ty_area,
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
      "! Batch job of the run (SM37 link; blank in dialog) and the system it ran in
      jobname       TYPE btcjob,
      jobcount      TYPE btcjobcnt,
      sysid         TYPE sysysid,
    END OF ty_run.
  TYPES tt_run TYPE STANDARD TABLE OF ty_run WITH EMPTY KEY.

  "! A parameter that could not be read (ZCX_CA_PARAM): ZIF_CA_OPS_PARAMS=>GET_ERRORS
  TYPES:
    BEGIN OF ty_param_error,
      area  TYPE ty_area,
      name  TYPE ty_param_name,
      msgno TYPE symsgno,
      text  TYPE string,
    END OF ty_param_error.
  TYPES tt_param_error TYPE SORTED TABLE OF ty_param_error WITH UNIQUE KEY area name.

  "! ---- Alert router (ZCA_OPS_ALRULE / _ALCHN / _ALLOG) ----
  TYPES ty_channel     TYPE c LENGTH 10.
  "! Alert rule pattern: PCRE, matched to the complete value, case ignored; blank = any
  TYPES ty_pattern     TYPE c LENGTH 35.
  "! List of PCRE patterns (each matched to the complete value, case ignored)
  TYPES tt_pcre        TYPE STANDARD TABLE OF string WITH EMPTY KEY.
  TYPES ty_alert_dest  TYPE c LENGTH 255.

  CONSTANTS:
    BEGIN OF gc_channel,
      email  TYPE ty_channel VALUE 'EMAIL',
      applog TYPE ty_channel VALUE 'APPLOG',
    END OF gc_channel.

  "! Area of an alert rule that applies to every area
  CONSTANTS gc_area_any TYPE ty_area VALUE '*'.

  "! Delivery status in ZCA_OPS_ALLOG
  CONSTANTS:
    BEGIN OF gc_alert_status,
      sent      TYPE c LENGTH 1 VALUE 'S',
      failed    TYPE c LENGTH 1 VALUE 'F',
      throttled TYPE c LENGTH 1 VALUE 'T',
      quiet     TYPE c LENGTH 1 VALUE 'Q',
      "! Durable claim written and committed before the external send (audit A17)
      claimed   TYPE c LENGTH 1 VALUE 'C',
      "! Only carried-forward exceptions - not alerted again (audit A17)
      repeat    TYPE c LENGTH 1 VALUE 'R',
      "! Delivered in part (e.g. application log stopped adding lines, audit A45)
      partial   TYPE c LENGTH 1 VALUE 'P',
    END OF gc_alert_status.

  "! One alert rule: which findings of which area go to which channel
  TYPES:
    BEGIN OF ty_alert_rule,
      rule_id         TYPE ty_rule_id,
      area            TYPE ty_area,
      "! Lowest severity that triggers (B, E, W, I)
      min_severity    TYPE ty_severity,
      "! PCRE patterns on the finding (complete value, case ignored); blank = any
      rule_pattern    TYPE ty_pattern,
      check_pattern   TYPE ty_pattern,
      group1_pattern  TYPE ty_pattern,
      group2_pattern  TYPE ty_pattern,
      "! Also alert when the run ends with this RAG or worse (blank = no run-level alert)
      min_rag         TYPE ty_rag,
      on_abort        TYPE abap_bool,
      channel         TYPE ty_channel,
      "! E-mail list or log object - meaning depends on the channel
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
      "! X = a due escalation is delivered even inside the throttle window (audit A46)
      esc_override    TYPE abap_bool,
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
      area        TYPE ty_area,
      run_id      TYPE ty_run_id,
      severity    TYPE ty_severity,
      subject     TYPE ty_message,
      html        TYPE string,
      text        TYPE string,
      item_count  TYPE i,
      "! External ID of the application log (SLG1): area / run / rule
      extnumber   TYPE ty_extnumber,
    END OF ty_alert_message.
  TYPES tt_alert_message TYPE STANDARD TABLE OF ty_alert_message WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_alert_log,
      alert_id    TYPE ty_run_id,
      rule_id     TYPE ty_rule_id,
      channel     TYPE ty_channel,
      run_id      TYPE ty_run_id,
      area        TYPE ty_area,
      sent_at     TYPE timestampl,
      status      TYPE c LENGTH 1,
      destination TYPE ty_alert_dest,
      subject     TYPE ty_message,
      error       TYPE ty_message,
      "! Alert intent (rule, run, channel, destination, subject) and attempt: one
      "! dispatcher per intent and attempt (unique index INT, audit A17)
      intent_key  TYPE ty_intent_key,
      attempt     TYPE i,
    END OF ty_alert_log.
  TYPES tt_alert_log TYPE STANDARD TABLE OF ty_alert_log WITH EMPTY KEY.

  "! A finding raised again only because an open exception was carried forward
  TYPES:
    BEGIN OF ty_repeat_key,
      object_type TYPE ty_object_type,
      object_key  TYPE ty_object_key,
      check_code  TYPE ty_check_code,
    END OF ty_repeat_key.
  TYPES tt_repeat_key TYPE HASHED TABLE OF ty_repeat_key WITH UNIQUE KEY object_type object_key check_code.

  "! Message numbers (class ZCA_OPS) of the framework's user-facing texts
  CONSTANTS:
    BEGIN OF gc_msg,
      alert_subject_run     TYPE ty_msgno VALUE '002',
      alert_subject_count   TYPE ty_msgno VALUE '003',
      alert_run_line_1      TYPE ty_msgno VALUE '004',
      alert_run_line_2      TYPE ty_msgno VALUE '005',
      alert_more_findings   TYPE ty_msgno VALUE '006',
      channel_inactive      TYPE ty_msgno VALUE '007',
      passed_on_rerun       TYPE ty_msgno VALUE '008',
      no_recipient          TYPE ty_msgno VALUE '021',
      applog_partial        TYPE ty_msgno VALUE '025',
      alert_pattern_invalid TYPE ty_msgno VALUE '742',
      alert_id_failed       TYPE ty_msgno VALUE '802',
      alert_run_reference   TYPE ty_msgno VALUE '803',
      run_aborted           TYPE ty_msgno VALUE '804',
      alert_dispatch_failed TYPE ty_msgno VALUE '805',
    END OF gc_msg.

ENDINTERFACE.
