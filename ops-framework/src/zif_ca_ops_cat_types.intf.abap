*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_cat_types.intf.abap
*& Purpose:
*& Types and constants of the process catalogue: packages (ZCA_OPS_CATPKG),
*& SAP standard processes with their steps, tables and dependencies
*& (ZCA_OPS_CATPRC / _CATSTP / _CATTAB / _CATDEP), the activation per
*& customer (ZCA_OPS_CATACT, effective from a date), the effective state of
*& a catalogue process and of a business process of ZCA_OPS_PROC that
*& monitors it, the check codes of the runner, the onboarding check and the
*& outage check, parameters (prefix CAT_) and messages 240-279. No logic.
*& Modification log:
*& 2026-11-11 | Initial version (process catalogue with activation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - process catalogue types</p>
INTERFACE zif_ca_ops_cat_types
  PUBLIC.

  TYPES ty_pkg_id     TYPE c LENGTH 10.
  TYPES ty_process_id TYPE c LENGTH 20.
  TYPES ty_kind       TYPE c LENGTH 1.
  TYPES ty_text       TYPE c LENGTH 60.
  TYPES ty_reason     TYPE c LENGTH 80.
  TYPES ty_obj_name   TYPE c LENGTH 40.
  TYPES ty_role_text  TYPE c LENGTH 40.
  TYPES ty_card       TYPE c LENGTH 20.
  TYPES ty_component  TYPE c LENGTH 10.
  TYPES ty_verify_ref TYPE c LENGTH 20.
  TYPES ty_step_no    TYPE n LENGTH 3.

  "! Kind of a package: product baseline, industry package, customer layer
  CONSTANTS:
    BEGIN OF gc_pkg_kind,
      baseline TYPE ty_kind VALUE 'S',
      industry TYPE ty_kind VALUE 'I',
      customer TYPE ty_kind VALUE 'C',
    END OF gc_pkg_kind.

  "! Kind of a step: transaction, program, mass activity type, background job, event / BAdI
  CONSTANTS:
    BEGIN OF gc_step_kind,
      transaction   TYPE ty_kind VALUE 'T',
      program       TYPE ty_kind VALUE 'P',
      mass_activity TYPE ty_kind VALUE 'M',
      job           TYPE ty_kind VALUE 'J',
      event         TYPE ty_kind VALUE 'E',
    END OF gc_step_kind.

  "! Dependency: hard (the predecessor must be active and run first) or soft (uses its data)
  CONSTANTS:
    BEGIN OF gc_dep_kind,
      hard TYPE ty_kind VALUE 'H',
      soft TYPE ty_kind VALUE 'S',
    END OF gc_dep_kind.

  "! Evidence of a name of the catalogue: confirmed or a VERIFY item
  CONSTANTS:
    BEGIN OF gc_evidence,
      confirmed TYPE ty_kind VALUE 'C',
      verify    TYPE ty_kind VALUE 'V',
    END OF gc_evidence.

  "! What decided the effective state of a catalogue process
  CONSTANTS:
    BEGIN OF gc_source,
      "! An activation row of ZCA_OPS_CATACT (the latest effective on the day)
      activation TYPE ty_kind VALUE 'A',
      "! No activation row on or before the day: the delivered default DFLT_ACTIVE
      default    TYPE ty_kind VALUE 'D',
      "! The package is switched off (or unknown): inactive whatever the rows say
      package    TYPE ty_kind VALUE 'P',
      "! The process is not in the catalogue
      unknown    TYPE ty_kind VALUE 'U',
    END OF gc_source.

  "! Check codes: the runner's note for a skipped check, the onboarding check's catalogue gaps, the outage check
  CONSTANTS:
    BEGIN OF gc_code,
      "! Info: the check was not run because its business process is not active (runner)
      process_inactive TYPE zif_ca_ops_types=>ty_check_code VALUE 'PROCESS_INACTIVE',
      "! An active catalogue process that no check in effect monitors
      cat_no_check     TYPE zif_ca_ops_types=>ty_check_code VALUE 'CAT_NO_CHECK',
      "! An active check whose business process is not active (it does not run)
      check_proc_off   TYPE zif_ca_ops_types=>ty_check_code VALUE 'CHECK_PROC_INACTIVE',
      "! A business process names a catalogue process that is not defined
      cat_ref_unknown  TYPE zif_ca_ops_types=>ty_check_code VALUE 'CAT_REF_UNKNOWN',
      "! An active catalogue process depends (hard) on an inactive one
      cat_dep_inactive TYPE zif_ca_ops_types=>ty_check_code VALUE 'CAT_DEP_INACTIVE',
      "! The catalogue rows break a rule (prefix, package, dependency, activation)
      cat_invalid      TYPE zif_ca_ops_types=>ty_check_code VALUE 'CAT_INVALID',
      "! Outage check: rows of an aggregate rule inside / around a planned downtime window
      outage_rows      TYPE zif_ca_ops_types=>ty_check_code VALUE 'OUTAGE_ROWS',
    END OF gc_code.

  "! Object type of the catalogue findings of the onboarding check and of the outage check
  CONSTANTS:
    BEGIN OF gc_object_type,
      catalogue TYPE zif_ca_ops_types=>ty_object_type VALUE 'CATALOGUE',
      window    TYPE zif_ca_ops_types=>ty_object_type VALUE 'DOWNTIME',
    END OF gc_object_type.

  "! Rule ID of the outage check's own findings when no aggregate row is configured
  CONSTANTS gc_rule_outage TYPE zif_ca_ops_types=>ty_rule_id VALUE 'OUTAGE'.

  "! Parameters (area CA_OPS, prefix CAT_)
  CONSTANTS:
    BEGIN OF gc_param,
      outage_days   TYPE zif_ca_ops_types=>ty_param_name VALUE 'CAT_OUTAGE_DAYS',
      outage_margin TYPE zif_ca_ops_types=>ty_param_name VALUE 'CAT_OUTAGE_MARGIN_DAYS',
    END OF gc_param.
  CONSTANTS:
    BEGIN OF gc_param_default,
      outage_days   TYPE i VALUE 3,
      outage_margin TYPE i VALUE 1,
    END OF gc_param_default.

  "! Messages of the process catalogue (message class ZCA_OPS, 240-279; 240 is the configuration app's)
  CONSTANTS:
    BEGIN OF gc_msg,
      skipped         TYPE zif_ca_ops_types=>ty_msgno VALUE '241',
      cat_no_check    TYPE zif_ca_ops_types=>ty_msgno VALUE '242',
      check_proc_off  TYPE zif_ca_ops_types=>ty_msgno VALUE '243',
      cat_ref_unknown TYPE zif_ca_ops_types=>ty_msgno VALUE '244',
      cat_dep_off     TYPE zif_ca_ops_types=>ty_msgno VALUE '245',
      prefix          TYPE zif_ca_ops_types=>ty_msgno VALUE '247',
      package_unknown TYPE zif_ca_ops_types=>ty_msgno VALUE '248',
      dep_invalid     TYPE zif_ca_ops_types=>ty_msgno VALUE '249',
      dep_cycle       TYPE zif_ca_ops_types=>ty_msgno VALUE '250',
      act_unknown     TYPE zif_ca_ops_types=>ty_msgno VALUE '252',
      act_incomplete  TYPE zif_ca_ops_types=>ty_msgno VALUE '253',
      outage_rows     TYPE zif_ca_ops_types=>ty_msgno VALUE '254',
      window_invalid  TYPE zif_ca_ops_types=>ty_msgno VALUE '255',
    END OF gc_msg.

  "! A package (ZCA_OPS_CATPKG)
  TYPES:
    BEGIN OF ty_package,
      pkg_id      TYPE ty_pkg_id,
      pkg_kind    TYPE ty_kind,
      pkg_rank    TYPE i,
      id_prefix   TYPE ty_pkg_id,
      mon_area    TYPE zif_ca_ops_types=>ty_area,
      description TYPE ty_text,
      owner       TYPE ty_text,
      active      TYPE abap_bool,
    END OF ty_package.
  TYPES tt_package TYPE SORTED TABLE OF ty_package WITH UNIQUE KEY pkg_id.

  "! A catalogue process (ZCA_OPS_CATPRC)
  TYPES:
    BEGIN OF ty_process,
      process_id  TYPE ty_process_id,
      pkg_id      TYPE ty_pkg_id,
      description TYPE ty_text,
      component   TYPE ty_component,
      dash_card   TYPE ty_card,
      owner_role  TYPE ty_role_text,
      schedule    TYPE ty_text,
      dflt_active TYPE abap_bool,
      evidence    TYPE ty_kind,
      verify_ref  TYPE ty_verify_ref,
      seq         TYPE i,
    END OF ty_process.
  TYPES tt_process TYPE SORTED TABLE OF ty_process WITH UNIQUE KEY process_id.

  "! A step of a process (ZCA_OPS_CATSTP)
  TYPES:
    BEGIN OF ty_step,
      process_id  TYPE ty_process_id,
      step_no     TYPE ty_step_no,
      step_kind   TYPE ty_kind,
      obj_name    TYPE ty_obj_name,
      description TYPE ty_text,
      evidence    TYPE ty_kind,
      verify_ref  TYPE ty_verify_ref,
    END OF ty_step.
  TYPES tt_step TYPE SORTED TABLE OF ty_step WITH UNIQUE KEY process_id step_no.

  "! A standard table of a process (ZCA_OPS_CATTAB)
  TYPES:
    BEGIN OF ty_table,
      process_id  TYPE ty_process_id,
      tabname     TYPE zif_ca_ops_chk_types=>ty_tabname,
      tab_role    TYPE ty_kind,
      link_object TYPE zif_ca_ops_link_types=>ty_object_id,
      description TYPE ty_text,
      evidence    TYPE ty_kind,
      verify_ref  TYPE ty_verify_ref,
    END OF ty_table.
  TYPES tt_table TYPE SORTED TABLE OF ty_table WITH UNIQUE KEY process_id tabname.

  "! A dependency between processes (ZCA_OPS_CATDEP)
  TYPES:
    BEGIN OF ty_dependency,
      process_id  TYPE ty_process_id,
      pred_id     TYPE ty_process_id,
      dep_kind    TYPE ty_kind,
      description TYPE ty_text,
    END OF ty_dependency.
  TYPES tt_dependency TYPE SORTED TABLE OF ty_dependency WITH UNIQUE KEY process_id pred_id.

  "! An activation row (ZCA_OPS_CATACT)
  TYPES:
    BEGIN OF ty_activation,
      process_id  TYPE ty_process_id,
      valid_from  TYPE d,
      active      TYPE abap_bool,
      pkg_id      TYPE ty_pkg_id,
      reason      TYPE ty_reason,
      approved_by TYPE syuname,
      approved_on TYPE d,
    END OF ty_activation.
  TYPES tt_activation TYPE SORTED TABLE OF ty_activation WITH UNIQUE KEY process_id valid_from.

  "! A business process of ZCA_OPS_PROC with its catalogue process (active or not)
  TYPES:
    BEGIN OF ty_onboarded,
      area        TYPE zif_ca_ops_types=>ty_area,
      process_id  TYPE zif_ca_ops_chk_types=>ty_process_id,
      cat_process TYPE ty_process_id,
      active      TYPE abap_bool,
    END OF ty_onboarded.
  TYPES tt_onboarded TYPE SORTED TABLE OF ty_onboarded WITH UNIQUE KEY area process_id.

  "! Effective state of a catalogue process on a day
  TYPES:
    BEGIN OF ty_state,
      process_id  TYPE ty_process_id,
      active      TYPE abap_bool,
      "! GC_SOURCE: activation row, default, package off, unknown
      source      TYPE ty_kind,
      "! The deciding activation row (source A)
      valid_from  TYPE d,
      reason      TYPE ty_reason,
      approved_by TYPE syuname,
    END OF ty_state.
  TYPES tt_state TYPE SORTED TABLE OF ty_state WITH UNIQUE KEY process_id.

  "! A process with everything the catalogue knows about it (API for consumers and a test tool)
  TYPES:
    BEGIN OF ty_definition,
      process      TYPE ty_process,
      package      TYPE ty_package,
      state        TYPE ty_state,
      steps        TYPE tt_step,
      tables       TYPE tt_table,
      dependencies TYPE tt_dependency,
      "! Business processes of ZCA_OPS_PROC that monitor it (area, process; active or not)
      monitors     TYPE tt_onboarded,
    END OF ty_definition.

  "! Business processes switched off for the runner (area, process ID)
  TYPES tt_process_ids TYPE SORTED TABLE OF zif_ca_ops_chk_types=>ty_process_id WITH UNIQUE KEY table_line.

  "! A rule the catalogue rows break (message number and variables, the row it is about)
  TYPES:
    BEGIN OF ty_problem,
      object_key TYPE zif_ca_ops_types=>ty_object_key,
      msgno      TYPE zif_ca_ops_types=>ty_msgno,
      v1         TYPE string,
      v2         TYPE string,
      v3         TYPE string,
    END OF ty_problem.
  TYPES tt_problem TYPE STANDARD TABLE OF ty_problem WITH EMPTY KEY.

ENDINTERFACE.
