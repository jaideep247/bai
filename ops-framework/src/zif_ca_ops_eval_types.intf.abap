*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_eval_types.intf.abap
*& Purpose:
*& Types and constants of evaluation and coverage (docs/EVALUATION_AND_
*& COVERAGE.md, build O): the one evaluation vocabulary of every check run
*& - completeness (C complete, P partial, N not evaluated: the flags of the
*& payment file day register) and result class (OK, ZERO_OK, HOLIDAY,
*& PER_CLOSED, STALE, NOT_EVAL, FINDINGS: the day results of the payment
*& file lifecycle, extended), the display state support sees, the terms of
*& the earlier vocabularies that map onto it (day results of build K,
*& evaluations of the FI-CA cash checks of build N), the optional part a
*& check may add to its result (ZIF_CA_OPS_CHK_TYPES=>TY_RESULT-EVAL), the
*& evaluation record (ZCA_OPS_EVAL / ZCA_OPS_EVALSRC), the delivery state of
*& an alert (ZCA_OPS_ALLOG-DLV_*), the monitor coverage state of a check,
*& parameters EVAL_*, check codes and messages 560-599. No logic
*& (ZCL_CA_OPS_EVAL, ZCL_CA_OPS_COVERAGE).
*& Modification log:
*& 2026-11-16 | Initial version (build O: evaluation state, delivery confirmation, coverage, catalogue
*&            | milestones).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - evaluation and coverage types</p>
"! Built-in types, the data elements of its domains and ZIF_CA_OPS_TYPES only: ZIF_CA_OPS_CHK_TYPES includes
"! TY_CHECK_EVAL in its result.
INTERFACE zif_ca_ops_eval_types
  PUBLIC.

  "! Evaluation state / result class (domain ZCA_OPS_EVAL_STATE: translatable texts; DD07L values <= 10)
  TYPES ty_state       TYPE zca_ops_eval_state.
  "! Completeness (domain ZCA_OPS_EVAL_CMPL)
  TYPES ty_cmpl        TYPE zca_ops_eval_cmpl.
  TYPES ty_reason_code TYPE c LENGTH 20.
  TYPES ty_reason      TYPE c LENGTH 255.
  TYPES ty_source_id   TYPE c LENGTH 30.
  "! Accounting period YYYYMM
  TYPES ty_period      TYPE n LENGTH 6.
  "! Company codes in scope, comma list (blank = the area)
  TYPES ty_bukrs_list  TYPE c LENGTH 120.
  "! A term of an earlier vocabulary (day result of build K, evaluation of build N, a state of this one)
  TYPES ty_term        TYPE c LENGTH 15.
  "! Licence state of a check in a run: blank covered, W warned, R refused
  TYPES ty_lic_state   TYPE c LENGTH 1.
  "! Delivery state of an alert (domain ZCA_OPS_DLV_STATE); blank = not asked yet
  TYPES ty_dlv_state   TYPE zca_ops_dlv_state.
  TYPES ty_dlv_ref     TYPE c LENGTH 70.
  "! Monitor coverage state of a registered check (domain ZCA_OPS_COV_STATE)
  TYPES ty_cov_state   TYPE zca_ops_cov_state.

  "! Completeness: the payment file day register's flags (ZIF_CA_OPS_PF_TYPES=>GC_EVAL C / P / N)
  CONSTANTS:
    BEGIN OF gc_cmpl,
      complete      TYPE ty_cmpl VALUE 'C',
      partial       TYPE ty_cmpl VALUE 'P',
      not_evaluated TYPE ty_cmpl VALUE 'N',
    END OF gc_cmpl.

  "! Result class and display state. The stored codes are those of the payment file day results (NOT_EVAL, not a
  "! third spelling); PER_CLOSED = period closed; PARTIAL is a display state only (completeness first)
  CONSTANTS:
    BEGIN OF gc_state,
      "! Complete and nothing to report
      ok            TYPE ty_state VALUE 'OK',
      "! A valid day without volume (the job ran, the source answered, nothing expected was missing)
      zero_ok       TYPE ty_state VALUE 'ZERO_OK',
      "! Not expected by the calendar (holiday, weekend)
      holiday       TYPE ty_state VALUE 'HOLIDAY',
      "! The accounting period of the scope is closed: no activity expected, a zero is not health
      period_closed TYPE ty_state VALUE 'PER_CLOSED',
      "! The source has not delivered within its limit: its silence proves nothing
      stale         TYPE ty_state VALUE 'STALE',
      "! Nothing could be evaluated (read failed, value pending, check raised, not run)
      not_evaluated TYPE ty_state VALUE 'NOT_EVAL',
      "! Owned exceptions raised
      findings      TYPE ty_state VALUE 'FINDINGS',
      "! Display state only: part of the scope could not be evaluated
      partial       TYPE ty_state VALUE 'PARTIAL',
    END OF gc_state.

  "! Terms of the earlier vocabularies mapped by ZCL_CA_OPS_EVAL=>OF_TERM (values, not objects: build K's day
  "! results ZIF_CA_OPS_PF_TYPES=>GC_DAY and build N's evaluations of the cash checks)
  CONSTANTS:
    BEGIN OF gc_term,
      "! Build K: a day with fewer files than expected after its deadline / part of them (business findings)
      day_missing     TYPE ty_term VALUE 'MISSING',
      day_partial     TYPE ty_term VALUE 'PARTIAL',
      "! Build K: the day's deadline has not passed - no verdict yet, no contribution
      day_pending     TYPE ty_term VALUE 'PENDING',
      "! Build N: the source was read (with or without an exception)
      observed        TYPE ty_term VALUE 'OBSERVED',
      "! Build N: valid zero-volume day (CASH_ZERO_VOLUME)
      zero_volume     TYPE ty_term VALUE 'ZERO_VOLUME',
      "! Build N: not a working day (CASH_NOT_EXPECTED)
      not_expected    TYPE ty_term VALUE 'NOT_EXPECTED',
      "! Build N: a rule not evaluated (CASH_NOT_EVALUATED)
      not_evaluated_n TYPE ty_term VALUE 'NOT_EVALUATED',
    END OF gc_term.

  "! Reason codes of the evaluation record (the reason text is a message)
  CONSTANTS:
    BEGIN OF gc_reason,
      check_raised     TYPE ty_reason_code VALUE 'CHECK_FAILED',
      partial          TYPE ty_reason_code VALUE 'PARTIAL',
      not_evaluated    TYPE ty_reason_code VALUE 'NOT_EVALUATED',
      source_stale     TYPE ty_reason_code VALUE 'SOURCE_STALE',
      period_closed    TYPE ty_reason_code VALUE 'PERIOD_CLOSED',
      license_refused  TYPE ty_reason_code VALUE 'LICENSE_REFUSED',
      process_inactive TYPE ty_reason_code VALUE 'PROCESS_INACTIVE',
      "! Build Q: a table, view or field the configuration names is not in this system's dictionary
      ddic_missing     TYPE ty_reason_code VALUE 'DDIC_MISSING',
    END OF gc_reason.

  "! Licence state of a check in a run (ZCA_OPS_EVAL-LIC_STATE, read through ZIF_CA_OPS_LICENSE by the runner)
  CONSTANTS:
    BEGIN OF gc_lic_state,
      covered TYPE ty_lic_state VALUE ' ',
      warned  TYPE ty_lic_state VALUE 'W',
      refused TYPE ty_lic_state VALUE 'R',
    END OF gc_lic_state.

  "! Delivery state of an alert (ZCA_OPS_ALLOG-DLV_STATE). Never D without the channel's confirmation
  CONSTANTS:
    BEGIN OF gc_dlv,
      not_asked      TYPE ty_dlv_state VALUE ' ',
      pending        TYPE ty_dlv_state VALUE 'P',
      delivered      TYPE ty_dlv_state VALUE 'D',
      failed         TYPE ty_dlv_state VALUE 'F',
      cannot_confirm TYPE ty_dlv_state VALUE 'N',
    END OF gc_dlv.

  "! Monitor coverage state of a registered check (ZCL_CA_OPS_COVERAGE; the CDS ZR_CA_OpsCoverage, same rule),
  "! worst first: DISABLED, REFUSED, NOT_RUN, IMPAIRED, WARNED, RAN
  CONSTANTS:
    BEGIN OF gc_cov,
      disabled TYPE ty_cov_state VALUE 'DISABLED',
      refused  TYPE ty_cov_state VALUE 'REFUSED',
      not_run  TYPE ty_cov_state VALUE 'NOT_RUN',
      impaired TYPE ty_cov_state VALUE 'IMPAIRED',
      warned   TYPE ty_cov_state VALUE 'WARNED',
      ran      TYPE ty_cov_state VALUE 'RAN',
    END OF gc_cov.

  "! Parameters of area CA_OPS (prefix EVAL_, docs/PARAMETERS.md)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Minutes after which a source a check names is stale when it gives no limit of its own [1500]
      source_stale_min TYPE zif_ca_ops_types=>ty_param_name VALUE 'EVAL_SOURCE_STALE_MIN',
      "! Closed accounting periods: AREA:YYYYMM or AREA:BUKRS:YYYYMM (comma list; * = every area) [blank]
      period_closed    TYPE zif_ca_ops_types=>ty_param_name VALUE 'EVAL_PERIOD_CLOSED',
      "! Class of a site's period-close calendar (ZIF_CA_OPS_EVAL_PERIOD); blank = EVAL_PERIOD_CLOSED [blank]
      period_source    TYPE zif_ca_ops_types=>ty_param_name VALUE 'EVAL_PERIOD_SOURCE',
      "! Minutes after the submission an alert must be confirmed delivered [30]
      confirm_min      TYPE zif_ca_ops_types=>ty_param_name VALUE 'EVAL_DLV_CONFIRM_MIN',
      "! Hours of submitted alerts the confirmation step and the delivery check look back [48]
      lookback_h       TYPE zif_ca_ops_types=>ty_param_name VALUE 'EVAL_DLV_LOOKBACK_H',
      "! Class of the e-mail send status reader (ZIF_CA_OPS_DLV_READER); blank = e-mail cannot confirm [blank]
      email_reader     TYPE zif_ca_ops_types=>ty_param_name VALUE 'EVAL_EMAIL_READER',
      "! Severity of the notice "channel cannot confirm" (I or W) [I]
      unconfirmable    TYPE zif_ca_ops_types=>ty_param_name VALUE 'EVAL_DLV_UNCONFIRMABLE',
    END OF gc_param.

  CONSTANTS:
    BEGIN OF gc_param_default,
      source_stale_min TYPE i VALUE 1500,
      confirm_min      TYPE i VALUE 30,
      lookback_h       TYPE i VALUE 48,
      unconfirmable    TYPE zif_ca_ops_types=>ty_severity VALUE 'I',
    END OF gc_param_default.

  "! Plug-in interfaces of this part (checked by RTTI before creation)
  CONSTANTS:
    BEGIN OF gc_plugin_intf,
      period_source TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_EVAL_PERIOD',
      dlv_reader    TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_DLV_READER',
    END OF gc_plugin_intf.

  "! Separators of EVAL_PERIOD_CLOSED entries and of a company-code list
  CONSTANTS gc_entry_separator TYPE c LENGTH 1 VALUE ':'.
  CONSTANTS gc_any_area TYPE zif_ca_ops_types=>ty_area VALUE '*'.

  "! Rule IDs and object types of the framework's own checks of this part
  CONSTANTS:
    BEGIN OF gc_rule_id,
      coverage TYPE zif_ca_ops_types=>ty_rule_id VALUE 'COVERAGE',
      delivery TYPE zif_ca_ops_types=>ty_rule_id VALUE 'ALERT_DLV',
    END OF gc_rule_id.

  CONSTANTS:
    BEGIN OF gc_object_type,
      check TYPE zif_ca_ops_types=>ty_object_type VALUE 'CHECK',
      alert TYPE zif_ca_ops_types=>ty_object_type VALUE 'ALERT',
    END OF gc_object_type.

  "! Check codes of the coverage check (ZCL_CA_OPS_CHK_COVERAGE) and the delivery check (ZCL_CA_OPS_CHK_ALERT_DLV)
  CONSTANTS:
    BEGIN OF gc_code,
      "! An expected check has no evaluation within its window: a monitor gap (E)
      not_run        TYPE zif_ca_ops_types=>ty_check_code VALUE 'MONITOR_NOT_RUN',
      "! The latest evaluation is not evaluated, stale or partial (W)
      impaired       TYPE zif_ca_ops_types=>ty_check_code VALUE 'MONITOR_IMPAIRED',
      "! Refused by the licence under LIC_ENFORCE = X (E)
      refused        TYPE zif_ca_ops_types=>ty_check_code VALUE 'MONITOR_REFUSED',
      "! Runs under a licence warning (LIC_ENFORCE = W, module not covered) (W)
      warned         TYPE zif_ca_ops_types=>ty_check_code VALUE 'MONITOR_LIC_WARNED',
      "! Submitted, not confirmed delivered after EVAL_DLV_CONFIRM_MIN minutes (W)
      not_confirmed  TYPE zif_ca_ops_types=>ty_check_code VALUE 'ALERT_NOT_CONFIRMED',
      "! Failed after its submission (the channel says so) (E)
      dlv_failed     TYPE zif_ca_ops_types=>ty_check_code VALUE 'ALERT_DLV_FAILED',
      "! The channel cannot confirm (I by default, EVAL_DLV_UNCONFIRMABLE)
      unconfirmable  TYPE zif_ca_ops_types=>ty_check_code VALUE 'ALERT_DLV_UNCONFIRMABLE',
    END OF gc_code.

  "! Messages (message class ZCA_OPS, range 560-599)
  CONSTANTS:
    BEGIN OF gc_msg,
      check_raised     TYPE zif_ca_ops_types=>ty_msgno VALUE '560',
      partial          TYPE zif_ca_ops_types=>ty_msgno VALUE '561',
      source_stale     TYPE zif_ca_ops_types=>ty_msgno VALUE '562',
      period_closed    TYPE zif_ca_ops_types=>ty_msgno VALUE '563',
      license_refused  TYPE zif_ca_ops_types=>ty_msgno VALUE '564',
      process_inactive TYPE zif_ca_ops_types=>ty_msgno VALUE '565',
      not_evaluated    TYPE zif_ca_ops_types=>ty_msgno VALUE '566',
      signoff_unknown  TYPE zif_ca_ops_types=>ty_msgno VALUE '567',
      cov_not_run      TYPE zif_ca_ops_types=>ty_msgno VALUE '568',
      cov_impaired     TYPE zif_ca_ops_types=>ty_msgno VALUE '569',
      cov_refused      TYPE zif_ca_ops_types=>ty_msgno VALUE '570',
      cov_warned       TYPE zif_ca_ops_types=>ty_msgno VALUE '571',
      not_confirmed    TYPE zif_ca_ops_types=>ty_msgno VALUE '572',
      dlv_failed       TYPE zif_ca_ops_types=>ty_msgno VALUE '573',
      unconfirmable    TYPE zif_ca_ops_types=>ty_msgno VALUE '574',
      confirm_summary  TYPE zif_ca_ops_types=>ty_msgno VALUE '575',
      confirm_failed   TYPE zif_ca_ops_types=>ty_msgno VALUE '576',
      no_reader        TYPE zif_ca_ops_types=>ty_msgno VALUE '577',
      applog_written   TYPE zif_ca_ops_types=>ty_msgno VALUE '579',
      validated        TYPE zif_ca_ops_types=>ty_msgno VALUE '580',
      validate_unknown TYPE zif_ca_ops_types=>ty_msgno VALUE '581',
      validate_release TYPE zif_ca_ops_types=>ty_msgno VALUE '582',
      validate_test    TYPE zif_ca_ops_types=>ty_msgno VALUE '583',
      no_channel       TYPE zif_ca_ops_types=>ty_msgno VALUE '584',
    END OF gc_msg.

  "! A source a check names: its newest observation and its own stale limit (0 = EVAL_SOURCE_STALE_MIN)
  TYPES:
    BEGIN OF ty_source,
      source_id TYPE ty_source_id,
      newest_at TYPE timestampl,
      stale_min TYPE i,
      "! Set by the runner: X = older than its limit (or nothing observed)
      is_stale  TYPE abap_bool,
    END OF ty_source.
  TYPES tt_source TYPE STANDARD TABLE OF ty_source WITH EMPTY KEY.

  "! Optional part of a check's result (ZIF_CA_OPS_CHK_TYPES=>TY_RESULT-EVAL). A check that fills nothing gets the
  "! runner's defaults from TY_RESULT: raised = not evaluated, PARTIAL = partial, no exception = OK, else FINDINGS.
  "! ZCL_CA_OPS_EVAL=>MERGE_TERM / ADD_SOURCE fill it from a check's own vocabulary
  TYPES:
    BEGIN OF ty_check_eval,
      "! Blank = derived by the runner
      result_class   TYPE ty_state,
      "! Blank = from TY_RESULT-PARTIAL
      completeness   TYPE ty_cmpl,
      reason_code    TYPE ty_reason_code,
      reason         TYPE ty_reason,
      "! Expected scope: blank = the run's date, its month and the area
      bus_date       TYPE d,
      period         TYPE ty_period,
      bukrs_list     TYPE ty_bukrs_list,
      expected       TYPE i,
      observed       TYPE i,
      watermark      TYPE timestampl,
      sources        TYPE tt_source,
      "! Terms merged (MERGE_TERM): evaluated and not evaluated ones - both = partial, only the latter = not evaluated
      evaluated      TYPE i,
      unevaluated    TYPE i,
    END OF ty_check_eval.

  "! The evaluation record of one check and run (ZCA_OPS_EVAL, sources ZCA_OPS_EVALSRC)
  TYPES:
    BEGIN OF ty_eval,
      run_id         TYPE zif_ca_ops_types=>ty_run_id,
      check_id       TYPE c LENGTH 20,
      area           TYPE zif_ca_ops_types=>ty_area,
      process_id     TYPE c LENGTH 20,
      sched_group    TYPE c LENGTH 10,
      evaluated_at   TYPE timestampl,
      bus_date       TYPE d,
      period         TYPE ty_period,
      bukrs_list     TYPE ty_bukrs_list,
      expected_cnt   TYPE i,
      observed_cnt   TYPE i,
      item_count     TYPE i,
      finding_cnt    TYPE i,
      completeness   TYPE ty_cmpl,
      result_class   TYPE ty_state,
      eval_state     TYPE ty_state,
      reason_code    TYPE ty_reason_code,
      reason         TYPE ty_reason,
      fresh_at       TYPE timestampl,
      fresh_source   TYPE ty_source_id,
      watermark      TYPE timestampl,
      lic_state      TYPE ty_lic_state,
      lic_module     TYPE c LENGTH 20,
      last_valid_run TYPE zif_ca_ops_types=>ty_run_id,
      last_valid_at  TYPE timestampl,
      last_valid_cls TYPE ty_state,
      sources        TYPE tt_source,
    END OF ty_eval.
  TYPES tt_eval TYPE STANDARD TABLE OF ty_eval WITH EMPTY KEY.

  "! What the runner knows of one check run besides its result (input of ZCL_CA_OPS_EVAL=>DERIVE)
  TYPES:
    BEGIN OF ty_derive_input,
      run_id           TYPE zif_ca_ops_types=>ty_run_id,
      area             TYPE zif_ca_ops_types=>ty_area,
      check_id         TYPE c LENGTH 20,
      process_id       TYPE c LENGTH 20,
      sched_group      TYPE c LENGTH 10,
      today            TYPE d,
      now              TYPE timestampl,
      "! X = the check raised (CHECK_FAILED): not evaluated whatever it returned
      raised           TYPE abap_bool,
      "! Text of the error a raised check gave (the reason of the record)
      error_text       TYPE zif_ca_ops_types=>ty_message,
      "! X = the period of the scope is closed (ZIF_CA_OPS_EVAL_PERIOD)
      period_closed    TYPE abap_bool,
      "! Stale limit of a source without its own (EVAL_SOURCE_STALE_MIN)
      source_stale_min TYPE i,
      lic_state        TYPE ty_lic_state,
      lic_module       TYPE c LENGTH 20,
    END OF ty_derive_input.

  "! What a channel answers about one submitted alert (ZIF_CA_OPS_ALERT_CHANNEL=>CONFIRM, ZIF_CA_OPS_DLV_READER)
  TYPES:
    BEGIN OF ty_delivery,
      "! Initial = the channel cannot confirm (an optional method a channel does not implement)
      state        TYPE ty_dlv_state,
      delivered_at TYPE timestampl,
      info         TYPE zif_ca_ops_types=>ty_message,
    END OF ty_delivery.

  "! What the coverage rule decides on (ZCL_CA_OPS_COVERAGE=>STATE; ZR_CA_OpsCoverage, same rule)
  TYPES:
    BEGIN OF ty_cov_input,
      "! Registered check active and its business process in effect (ZI_CA_OpsChkEff)
      active          TYPE abap_bool,
      "! Licence today through ZIF_CA_OPS_LICENSE: allowed (abap_false only under X) and warned (W, not covered)
      lic_allowed     TYPE abap_bool,
      lic_warned      TYPE abap_bool,
      "! Latest evaluation of the check (initial = never evaluated)
      has_eval        TYPE abap_bool,
      evaluated_at    TYPE timestampl,
      eval_state      TYPE ty_state,
      reason_code     TYPE ty_reason_code,
      now             TYPE timestampl,
      "! Schedule window in minutes (CHECK_STALE_MIN_<area>, else CHECK_STALE_MIN_DEFAULT)
      window_min      TYPE i,
    END OF ty_cov_input.

  "! One row of the coverage of an area (the coverage check's view of a registered check)
  TYPES:
    BEGIN OF ty_cov_row,
      area         TYPE zif_ca_ops_types=>ty_area,
      check_id     TYPE c LENGTH 20,
      process_id   TYPE c LENGTH 20,
      module       TYPE c LENGTH 20,
      state        TYPE ty_cov_state,
      eval_state   TYPE ty_state,
      evaluated_at TYPE timestampl,
    END OF ty_cov_row.
  TYPES tt_cov_row TYPE STANDARD TABLE OF ty_cov_row WITH EMPTY KEY.

  "! Who recorded a platform validation of a catalogue process (ZCA_OPS_CATVAL-SOURCE)
  CONSTANTS:
    BEGIN OF gc_val_source,
      harness  TYPE c LENGTH 1 VALUE 'H',
      operator TYPE c LENGTH 1 VALUE 'O',
    END OF gc_val_source.

  "! Platform validation of a catalogue process on one system (ZCA_OPS_CATVAL; report ZCA_OPS_CAT_VALIDATE)
  TYPES:
    BEGIN OF ty_validation,
      process_id   TYPE c LENGTH 20,
      sys_id       TYPE c LENGTH 8,
      release_txt  TYPE c LENGTH 40,
      validated_on TYPE d,
      validated_by TYPE syuname,
      source       TYPE c LENGTH 1,
      evidence     TYPE zif_ca_ops_types=>ty_message,
    END OF ty_validation.

  "! Result of one confirmation step (ZCL_CA_OPS_ALERT_CONFIRM): alerts asked and their states now
  TYPES:
    BEGIN OF ty_confirm_summary,
      checked        TYPE i,
      delivered      TYPE i,
      pending        TYPE i,
      failed         TYPE i,
      cannot_confirm TYPE i,
      rows           TYPE zif_ca_ops_types=>tt_alert_log,
    END OF ty_confirm_summary.

ENDINTERFACE.
