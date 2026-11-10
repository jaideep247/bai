*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_pattern_types.intf.abap
*& Purpose:
*& Types and constants of the pattern check and the pattern migration
*& (user decision 2026-11-06: configured patterns are PCRE matched to the
*& complete value, case ignored): pattern areas, configured patterns, real
*& values, check result rows, migration rows and their statuses. No logic.
*& Modification log:
*& 2026-11-06 | Initial version (PCRE patterns: pattern check and migration).
*& 2026-11-10 | TT_PE_AREA: payment engine areas the migration report may read (ZCD_OPS 03).
*& 2026-11-10 | Alert rule fields and entity left the migration scope (framework table ZCA_OPS_ALRULE);
*&            | GC_TABLE-ALERT_RULE stays the source label of the pattern check.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - pattern check and migration types</p>
INTERFACE zif_cd_ops_pattern_types
  PUBLIC.

  TYPES ty_area   TYPE c LENGTH 10.
  TYPES ty_status TYPE c LENGTH 12.
  TYPES ty_name   TYPE c LENGTH 30.
  "! Payment engine areas a caller is authorised for (ZCD_OPS 03)
  TYPES tt_pe_area TYPE SORTED TABLE OF zif_ca_ops_types=>ty_area WITH UNIQUE KEY table_line.

  "! Pattern areas of the pattern check: configured field -> source of real values
  CONSTANTS:
    BEGIN OF gc_area,
      "! ZCD_EBS_FLOW_PAT-PATTERN -> FEBEP-XBLNR of the configured accounts (ZCD_EBS_ACCT)
      ebs_flow    TYPE ty_area VALUE 'EBS_FLOW',
      "! ZCD_FMON_IFACE-NAME_PATTERN -> ZCD_FMON_FILE-FILE_NAME
      fmon_file   TYPE ty_area VALUE 'FMON_FILE',
      "! ZCD_JOB_STEP-JOBNAME and the job-name lists of ZCD_HCK_DEF -> TBTCO-JOBNAME
      hck_job     TYPE ty_area VALUE 'HCK_JOB',
      "! ZCD_HCK_SUPPRESS-KEY_PATTERN -> object keys of HCK findings (ZCA_OPS_FINDING)
      hck_suppr   TYPE ty_area VALUE 'HCK_SUPPR',
      "! ZCA_OPS_ALRULE-RULE_PATTERN -> rule IDs of findings
      alert_rule  TYPE ty_area VALUE 'ALERT_RULE',
      "! ZCA_OPS_ALRULE-CHECK_PATTERN -> check codes of findings
      alert_check TYPE ty_area VALUE 'ALERT_CHK',
      "! ZCA_OPS_ALRULE-GROUP1_PATTERN -> group 1 of findings
      alert_grp1  TYPE ty_area VALUE 'ALERT_GRP1',
      "! ZCA_OPS_ALRULE-GROUP2_PATTERN -> group 2 of findings
      alert_grp2  TYPE ty_area VALUE 'ALERT_GRP2',
    END OF gc_area.

  "! A configured pattern and where it is maintained (table / key)
  TYPES:
    BEGIN OF ty_pattern,
      source  TYPE string,
      pattern TYPE string,
    END OF ty_pattern.
  TYPES tt_pattern TYPE STANDARD TABLE OF ty_pattern WITH EMPTY KEY.

  "! Distinct real values of the area's source (e.g. XBLNR, file name, job name)
  TYPES tt_value TYPE STANDARD TABLE OF string WITH EMPTY KEY.

  "! Statuses of a pattern check row
  CONSTANTS:
    BEGIN OF gc_check,
      "! The value is matched by the pattern of the row (one row per value and pattern)
      matched   TYPE ty_status VALUE 'MATCHED',
      "! The value is matched by no pattern: these records would not be captured
      no_match  TYPE ty_status VALUE 'NO_MATCH',
      "! The pattern matches none of the values read
      unused    TYPE ty_status VALUE 'UNUSED',
      "! The pattern does not compile as PCRE (configuration error)
      invalid   TYPE ty_status VALUE 'INVALID',
    END OF gc_check.

  "! One row of the pattern check list
  TYPES:
    BEGIN OF ty_check_row,
      status  TYPE ty_status,
      value   TYPE string,
      pattern TYPE string,
      source  TYPE string,
      "! Values matched by the pattern (pattern rows) / patterns matching the value (value rows)
      hits    TYPE i,
    END OF ty_check_row.
  TYPES tt_check_row TYPE STANDARD TABLE OF ty_check_row WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_check_result,
      rows      TYPE tt_check_row,
      values    TYPE i,
      unmatched TYPE i,
      unused    TYPE i,
      invalid   TYPE i,
    END OF ty_check_result.

  "! Configuration rows holding patterns, for the one-off migration from CP wildcards
  TYPES:
    BEGIN OF ty_migration,
      "! Table and field (ZCD_EBS_FLOW_PAT / PATTERN ...)
      table      TYPE ty_name,
      field      TYPE ty_name,
      "! Key of the row as shown to the user, and the technical key parts
      row_key    TYPE string,
      key1       TYPE string,
      key2       TYPE string,
      "! The field holds a comma / semicolon list of patterns (ZCD_HCK_DEF parameters)
      is_list    TYPE abap_bool,
      max_length TYPE i,
      old        TYPE string,
      new        TYPE string,
      status     TYPE ty_status,
      message    TYPE string,
    END OF ty_migration.
  TYPES tt_migration TYPE STANDARD TABLE OF ty_migration WITH EMPTY KEY.

  "! Rows written to one configuration table (transport recording where the client records changes)
  TYPES:
    BEGIN OF ty_written,
      table   TYPE ty_name,
      created TYPE REF TO data,
      updated TYPE REF TO data,
      deleted TYPE REF TO data,
    END OF ty_written.
  TYPES tt_written TYPE STANDARD TABLE OF ty_written WITH EMPTY KEY.

  "! Statuses of a migration row
  CONSTANTS:
    BEGIN OF gc_migration,
      "! The CP wildcard pattern becomes the PCRE pattern in NEW (written in update mode)
      convert      TYPE ty_status VALUE 'CONVERT',
      "! Same text in both notations (no wildcard, no PCRE metacharacter)
      unchanged    TYPE ty_status VALUE 'UNCHANGED',
      "! Already PCRE syntax (escape, class, group, quantifier, anchor, .* ...): left as it is
      already_pcre TYPE ty_status VALUE 'ALREADY_PCRE',
      "! The converted pattern does not compile: not written
      invalid      TYPE ty_status VALUE 'INVALID',
      "! The converted pattern does not fit the field: not written
      too_long     TYPE ty_status VALUE 'TOO_LONG',
      "! Written (update mode)
      written      TYPE ty_status VALUE 'WRITTEN',
    END OF gc_migration.

  "! Configuration tables and fields that hold patterns (migration scope)
  CONSTANTS:
    BEGIN OF gc_table,
      flow_pattern TYPE ty_name VALUE 'ZCD_EBS_FLOW_PAT',
      fmon_iface   TYPE ty_name VALUE 'ZCD_FMON_IFACE',
      job_step     TYPE ty_name VALUE 'ZCD_JOB_STEP',
      alert_rule   TYPE ty_name VALUE 'ZCA_OPS_ALRULE',
      hck_def      TYPE ty_name VALUE 'ZCD_HCK_DEF',
      suppression  TYPE ty_name VALUE 'ZCD_HCK_SUPPRESS',
    END OF gc_table.

  CONSTANTS:
    BEGIN OF gc_field,
      pattern        TYPE ty_name VALUE 'PATTERN',
      name_pattern   TYPE ty_name VALUE 'NAME_PATTERN',
      jobname        TYPE ty_name VALUE 'JOBNAME',
      param1         TYPE ty_name VALUE 'PARAM1',
      param2         TYPE ty_name VALUE 'PARAM2',
      key_pattern    TYPE ty_name VALUE 'KEY_PATTERN',
    END OF gc_field.

  "! RAP entity (behaviour definition alias) of each configuration table, for transport recording
  CONSTANTS:
    BEGIN OF gc_entity,
      flow_pattern TYPE ty_name VALUE 'FlowPattern',
      fmon_iface   TYPE ty_name VALUE 'FmonIface',
      job_step     TYPE ty_name VALUE 'JobStep',
      hck_def      TYPE ty_name VALUE 'HckCheckDef',
    END OF gc_entity.

  "! Check classes whose ZCD_HCK_DEF parameters are PCRE lists (tech jobs / job runtime PARAM1,
  "! application log PARAM1 + PARAM2, job cycle PARAM2)
  CONSTANTS:
    BEGIN OF gc_list_class,
      tech_jobs   TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CD_HCK_C_TECH_JOBS',
      job_runtime TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CD_HCK_C_JOB_RUNTIME',
      applog      TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CD_HCK_C_APPLOG',
      job_cycle   TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CD_HCK_C_JOB_CYCLE',
    END OF gc_list_class.

  "! Default and largest row cap of the value read of the pattern check
  CONSTANTS gc_default_max_rows TYPE i VALUE 5000.
  CONSTANTS gc_max_rows_limit TYPE i VALUE 100000.

ENDINTERFACE.
