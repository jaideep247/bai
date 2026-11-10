*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_chk_types.intf.abap
*& Purpose:
*& Types and constants of the process onboarding framework: business
*& process register (ZCA_OPS_PROC), check registry (ZCA_OPS_CHECK), the
*& no-code aggregate check (ZCA_OPS_AGG over tables approved per area in
*& ZCA_OPS_TABWL), the context and result of a check run by the generic
*& runner ZCL_CA_OPS_CHECK_RUNNER, the onboarding (completeness) check,
*& the freshness parameter of the area dashboard and the messages. A check
*& is identified in every finding by GROUP2 = check ID and GROUP1 =
*& process ID (the runner stamps them). No logic.
*& Modification log:
*& 2026-11-10 | Initial version (process onboarding framework).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - check registry types</p>
INTERFACE zif_ca_ops_chk_types
  PUBLIC.

  TYPES ty_check_id    TYPE c LENGTH 20.
  TYPES ty_process_id  TYPE c LENGTH 20.
  TYPES ty_sched_group TYPE c LENGTH 10.
  TYPES ty_agg_id      TYPE c LENGTH 10.
  TYPES ty_agg_func    TYPE c LENGTH 5.
  TYPES ty_fieldname   TYPE c LENGTH 30.
  TYPES ty_tabname     TYPE c LENGTH 30.
  TYPES ty_operator    TYPE c LENGTH 2.
  TYPES ty_cond_value  TYPE c LENGTH 70.
  TYPES ty_type_kind   TYPE c LENGTH 1.
  TYPES ty_text        TYPE c LENGTH 60.
  TYPES ty_role        TYPE c LENGTH 30.
  TYPES ty_url         TYPE c LENGTH 255.
  TYPES ty_purge_target TYPE c LENGTH 12.

  "! Plug-in interface of a registered check (ZCA_OPS_CHECK-CLASS_NAME, checked by RTTI before creation)
  CONSTANTS gc_check_intf TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_CHECK'.

  "! Function of an aggregate row: COUNT = matching rows, AGE = days since the oldest date of them
  CONSTANTS:
    BEGIN OF gc_agg_func,
      count TYPE ty_agg_func VALUE 'COUNT',
      age   TYPE ty_agg_func VALUE 'AGE',
    END OF gc_agg_func.

  "! Operators of a condition (IN: comma list); the status condition takes EQ, NE and IN only
  CONSTANTS:
    BEGIN OF gc_operator,
      eq     TYPE ty_operator VALUE 'EQ',
      ne     TYPE ty_operator VALUE 'NE',
      gt     TYPE ty_operator VALUE 'GT',
      lt     TYPE ty_operator VALUE 'LT',
      ge     TYPE ty_operator VALUE 'GE',
      le     TYPE ty_operator VALUE 'LE',
      in_set TYPE ty_operator VALUE 'IN',
    END OF gc_operator.

  "! Object types of the findings of the runner and of the framework's checks
  CONSTANTS:
    BEGIN OF gc_object_type,
      check     TYPE zif_ca_ops_types=>ty_object_type VALUE 'CHECK',
      aggregate TYPE zif_ca_ops_types=>ty_object_type VALUE 'AGGREGATE',
      process   TYPE zif_ca_ops_types=>ty_object_type VALUE 'PROCESS',
    END OF gc_object_type.

  "! Rule ID of the runner's own findings and of the onboarding check
  CONSTANTS:
    BEGIN OF gc_rule_id,
      runner  TYPE zif_ca_ops_types=>ty_rule_id VALUE 'RUNNER',
      onboard TYPE zif_ca_ops_types=>ty_rule_id VALUE 'ONBOARD',
    END OF gc_rule_id.

  "! Check codes of the runner, the aggregate check and the onboarding check
  CONSTANTS:
    BEGIN OF gc_code,
      "! The check raised: no verdict about the business (its exceptions are not auto-resolved)
      check_failed    TYPE zif_ca_ops_types=>ty_check_code VALUE 'CHECK_FAILED',
      "! The area and schedule group of the run have no active check
      no_checks       TYPE zif_ca_ops_types=>ty_check_code VALUE 'CHECKS_NOT_REGISTERED',
      "! An aggregate row cannot be measured (table not approved, field unknown, operator, value)
      agg_invalid     TYPE zif_ca_ops_types=>ty_check_code VALUE 'AGG_CONFIG_INVALID',
      agg_count       TYPE zif_ca_ops_types=>ty_check_code VALUE 'AGG_COUNT',
      agg_age         TYPE zif_ca_ops_types=>ty_check_code VALUE 'AGG_AGE',
      "! Onboarding gaps of a registered business process
      proc_no_check   TYPE zif_ca_ops_types=>ty_check_code VALUE 'PROC_NO_CHECK',
      proc_no_control TYPE zif_ca_ops_types=>ty_check_code VALUE 'PROC_NO_CONTROL',
      proc_no_alert   TYPE zif_ca_ops_types=>ty_check_code VALUE 'PROC_NO_ALERT_RULE',
      proc_no_owner   TYPE zif_ca_ops_types=>ty_check_code VALUE 'PROC_NO_OWNER',
      proc_no_purge   TYPE zif_ca_ops_types=>ty_check_code VALUE 'PROC_NO_PURGE',
      proc_no_auth    TYPE zif_ca_ops_types=>ty_check_code VALUE 'PROC_NO_AUTH',
    END OF gc_code.

  "! Most groups (company codes) one aggregate row returns (company codes are few; a cut result is never
  "! taken as complete: the check is then partial)
  CONSTANTS gc_max_groups TYPE i VALUE 10000.
  "! Lowest date of a DATS field that counts as filled (initial dates are left out of AGE and COUNT)
  CONSTANTS gc_initial_date TYPE d VALUE '00000000'.

  "! Freshness of the area dashboard (ZR_CA_OpsCheckStatus, read in CDS): a run of the area and schedule
  "! group older than CHECK_STALE_MIN_<area> (else CHECK_STALE_MIN_DEFAULT) minutes is stale
  CONSTANTS:
    BEGIN OF gc_param,
      stale_default TYPE zif_ca_ops_types=>ty_param_name VALUE 'CHECK_STALE_MIN_DEFAULT',
    END OF gc_param.
  CONSTANTS:
    BEGIN OF gc_param_prefix,
      "! Completed with the area (a consumer delivers the definition of its area)
      stale_min TYPE zif_ca_ops_types=>ty_param_name VALUE 'CHECK_STALE_MIN_',
    END OF gc_param_prefix.
  CONSTANTS:
    BEGIN OF gc_param_default,
      "! 25 hours: a daily schedule group is stale once a run is missed
      stale_default TYPE i VALUE 1500,
    END OF gc_param_default.

  "! Messages of the check registry, the aggregate check and the onboarding check (message class ZCA_OPS)
  CONSTANTS:
    BEGIN OF gc_msg,
      field_unknown   TYPE zif_ca_ops_types=>ty_msgno VALUE '083',
      check_failed    TYPE zif_ca_ops_types=>ty_msgno VALUE '084',
      no_checks       TYPE zif_ca_ops_types=>ty_msgno VALUE '085',
      agg_count       TYPE zif_ca_ops_types=>ty_msgno VALUE '094',
      agg_age         TYPE zif_ca_ops_types=>ty_msgno VALUE '095',
      proc_no_check   TYPE zif_ca_ops_types=>ty_msgno VALUE '096',
      proc_no_control TYPE zif_ca_ops_types=>ty_msgno VALUE '097',
      proc_no_alert   TYPE zif_ca_ops_types=>ty_msgno VALUE '098',
      proc_no_owner   TYPE zif_ca_ops_types=>ty_msgno VALUE '099',
      proc_no_purge   TYPE zif_ca_ops_types=>ty_msgno VALUE '100',
      proc_no_auth    TYPE zif_ca_ops_types=>ty_msgno VALUE '101',
    END OF gc_msg.

  "! A registered check (ZCA_OPS_CHECK)
  TYPES:
    BEGIN OF ty_check,
      area        TYPE zif_ca_ops_types=>ty_area,
      check_id    TYPE ty_check_id,
      process_id  TYPE ty_process_id,
      description TYPE ty_text,
      class_name  TYPE zif_ca_ops_types=>ty_class_name,
      sched_group TYPE ty_sched_group,
      bukrs_aware TYPE abap_bool,
      active      TYPE abap_bool,
      seq         TYPE i,
    END OF ty_check.
  TYPES tt_check TYPE STANDARD TABLE OF ty_check WITH EMPTY KEY.

  "! A registered business process (ZCA_OPS_PROC)
  TYPES:
    BEGIN OF ty_process,
      area         TYPE zif_ca_ops_types=>ty_area,
      process_id   TYPE ty_process_id,
      description  TYPE ty_text,
      owner        TYPE syuname,
      backup       TYPE syuname,
      runbook_url  TYPE ty_url,
      auth_role    TYPE ty_role,
      own_data     TYPE abap_bool,
      purge_target TYPE ty_purge_target,
      active       TYPE abap_bool,
      seq          TYPE i,
    END OF ty_process.
  TYPES tt_process TYPE STANDARD TABLE OF ty_process WITH EMPTY KEY.

  "! A check a control covers (ZCA_OPS_CTLCHK with finding field GROUP2 of an active control)
  TYPES:
    BEGIN OF ty_covered,
      area     TYPE zif_ca_ops_types=>ty_area,
      check_id TYPE ty_check_id,
    END OF ty_covered.
  TYPES tt_covered TYPE SORTED TABLE OF ty_covered WITH UNIQUE KEY area check_id.
  TYPES tt_area TYPE SORTED TABLE OF zif_ca_ops_types=>ty_area WITH UNIQUE KEY table_line.

  "! A no-code aggregate row (ZCA_OPS_AGG)
  TYPES:
    BEGIN OF ty_agg,
      area         TYPE zif_ca_ops_types=>ty_area,
      check_id     TYPE ty_check_id,
      agg_id       TYPE ty_agg_id,
      description  TYPE ty_text,
      tabname      TYPE ty_tabname,
      agg_func     TYPE ty_agg_func,
      date_field   TYPE ty_fieldname,
      min_age_days TYPE i,
      bukrs_field  TYPE ty_fieldname,
      status_field TYPE ty_fieldname,
      status_op    TYPE ty_operator,
      status_value TYPE ty_cond_value,
      cond_field   TYPE ty_fieldname,
      cond_op      TYPE ty_operator,
      cond_value   TYPE ty_cond_value,
      amber        TYPE i,
      red          TYPE i,
      check_code   TYPE zif_ca_ops_types=>ty_check_code,
      active       TYPE abap_bool,
    END OF ty_agg.
  TYPES tt_agg TYPE STANDARD TABLE OF ty_agg WITH EMPTY KEY.

  "! A field of the runtime DDIC of an approved table
  TYPES:
    BEGIN OF ty_field,
      fieldname TYPE ty_fieldname,
      type_kind TYPE ty_type_kind,
    END OF ty_field.
  TYPES tt_field TYPE SORTED TABLE OF ty_field WITH UNIQUE KEY fieldname.

  "! The SQL of an aggregate row, built only from checked names and quoted literals
  TYPES:
    BEGIN OF ty_agg_query,
      tabname      TYPE ty_tabname,
      select_list  TYPE string,
      where_clause TYPE string,
      "! Company-code field (GROUP BY); blank = one area-level row
      group_field  TYPE ty_fieldname,
    END OF ty_agg_query.

  "! One result row of an aggregate (per company code when grouped)
  TYPES:
    BEGIN OF ty_agg_row,
      company_code TYPE bukrs,
      row_count    TYPE i,
      "! AGE: the oldest date of the matching rows
      oldest       TYPE d,
    END OF ty_agg_row.
  TYPES tt_agg_row TYPE STANDARD TABLE OF ty_agg_row WITH EMPTY KEY.

  "! What the runner hands every check
  TYPES:
    BEGIN OF ty_context,
      area        TYPE zif_ca_ops_types=>ty_area,
      sched_group TYPE ty_sched_group,
      run_id      TYPE zif_ca_ops_types=>ty_run_id,
      test_mode   TYPE abap_bool,
      today       TYPE d,
      now         TYPE timestampl,
    END OF ty_context.

  "! What a check returns. GROUP1 / GROUP2 of the findings are set by the runner (process / check ID)
  TYPES:
    BEGIN OF ty_result,
      findings   TYPE zif_ca_ops_types=>tt_finding,
      "! Objects (rows, groups, processes) the check evaluated - run counter TOTAL_ITEMS
      item_count TYPE i,
      "! X = the check evaluated less than all (a row could not be read): its earlier exceptions stay
      "! open (no auto-resolve); the runner sets it for a check that raised
      partial    TYPE abap_bool,
    END OF ty_result.

  "! Result of one run of the runner (report, tests)
  TYPES:
    BEGIN OF ty_run_result,
      run         TYPE zif_ca_ops_types=>ty_run,
      findings    TYPE zif_ca_ops_types=>tt_finding,
      check_count TYPE i,
      "! The run lock was held: nothing ran (RUN_LOCKED finding of ZCL_CA_OPS_RUN_GUARD)
      refused     TYPE abap_bool,
    END OF ty_run_result.

ENDINTERFACE.
