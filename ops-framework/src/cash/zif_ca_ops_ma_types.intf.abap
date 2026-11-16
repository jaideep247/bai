*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_ma_types.intf.abap
*& Purpose:
*& Types and constants of the FI-CA mass activity check (package
*& ZCA_OPS_CASH, docs/EXPECTED_RUNS_AND_MASS_ACTIVITIES.md section 3): a
*& mass activity the area watches (ZCA_OPS_MAACT), one run of it with its
*& parent job and its intervals as the run source sees them (ZIF_CA_OPS_
*& MA_SRC: the delivered source sees the parallel jobs of a run through
*& SAP's job tables), the state of an interval, the document output of a
*& run (payment documents of the payment run, dunning notices) against its
*& expectation, check codes, stages, evidence keys, parameters MA_* and
*& messages 615-629. Status VALUES of SAP tables are never constants here
*& (the job status values are the job monitor's, VERIFY V58). No logic.
*& Modification log:
*& 2026-11-16 | Initial version (build P: FI-CA mass-activity intervals and their output).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA mass activities - types and constants</p>
INTERFACE zif_ca_ops_ma_types
  PUBLIC.

  TYPES ty_act_id      TYPE c LENGTH 10.
  TYPES ty_aktyp       TYPE c LENGTH 10.
  TYPES ty_output_kind TYPE c LENGTH 10.
  TYPES ty_state       TYPE c LENGTH 8.
  TYPES ty_run_id      TYPE c LENGTH 6.

  "! Document output rule of a mass activity (ZCA_OPS_MAACT-OUTPUT_KIND)
  CONSTANTS:
    BEGIN OF gc_output,
      "! Payment documents of the payment run (DPAYH, the payment run check's rule)
      pay_doc TYPE ty_output_kind VALUE 'PAYDOC',
      "! Dunning notices of the run (FKKMAKO: count and dunning balance per currency)
      dunning TYPE ty_output_kind VALUE 'DUNNING',
      none    TYPE ty_output_kind VALUE 'NONE',
    END OF gc_output.

  "! State of an interval (from the status of its job; values of the job monitor, VERIFY V58)
  CONSTANTS:
    BEGIN OF gc_state,
      ok      TYPE ty_state VALUE 'OK',
      failed  TYPE ty_state VALUE 'FAILED',
      running TYPE ty_state VALUE 'RUNNING',
      waiting TYPE ty_state VALUE 'WAITING',
    END OF gc_state.

  "! Stages of the findings (the cash stage JOB_OK when the parent job ended successfully)
  CONSTANTS:
    BEGIN OF gc_stage,
      interval TYPE zif_ca_ops_cash_types=>ty_stage VALUE 'INTERVAL',
      output   TYPE zif_ca_ops_cash_types=>ty_stage VALUE 'OUTPUT',
    END OF gc_stage.

  "! Object type of the findings (object key = activity / run date / run ID / company code / currency)
  CONSTANTS gc_object_type TYPE zif_ca_ops_types=>ty_object_type VALUE 'MARUN'.

  "! Check codes
  CONSTANTS:
    BEGIN OF gc_code,
      "! One or more intervals of a run failed or did not finish (stage JOB_OK when the parent ended successfully)
      interval_failed TYPE zif_ca_ops_types=>ty_check_code VALUE 'MA_INTERVAL_FAILED',
      "! An interval runs longer than its limit
      interval_long   TYPE zif_ca_ops_types=>ty_check_code VALUE 'MA_INTERVAL_OVERRUN',
      "! The run ended, its document output is short of the expectation (per currency)
      output_short    TYPE zif_ca_ops_types=>ty_check_code VALUE 'MA_OUTPUT_SHORT',
    END OF gc_code.

  "! Evidence keys (names of ZIF_CA_OPS_CASH_TYPES=>TY_EVIDENCE; LAUFD/LAUFI and JOBNAME/JOBCOUNT are the cash keys
  "! with their link objects)
  CONSTANTS:
    BEGIN OF gc_key,
      "! The mass activity run: activity type, run date, run ID (blank when the source does not know it)
      run      TYPE zif_ca_ops_cash_types=>ty_key_name VALUE 'AKTYP/LAUFD/LAUFI',
      "! Number of an interval of the run (its parallel job follows as JOBNAME/JOBCOUNT)
      interval TYPE zif_ca_ops_cash_types=>ty_key_name VALUE 'INTERVAL',
    END OF gc_key.

  "! Source names (REFERENCE of a finding, reason of a failed read)
  CONSTANTS:
    BEGIN OF gc_source,
      activities TYPE zif_ca_ops_types=>ty_reference VALUE 'ZCA_OPS_MAACT',
      runs       TYPE zif_ca_ops_types=>ty_reference VALUE 'TBTCO/TBTCP',
      dunning    TYPE zif_ca_ops_types=>ty_reference VALUE 'FKKMAKO',
    END OF gc_source.

  "! Plug-in interface of the run source (checked by RTTI before creation)
  CONSTANTS gc_source_intf TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZIF_CA_OPS_MA_SRC'.

  "! Parameters (area CA_OPS, prefix MA_; config/param_definitions.csv, docs/PARAMETERS.md)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Days of runs read back (runs whose parent job started from today minus these days)
      lookback_days TYPE zif_ca_ops_types=>ty_param_name VALUE 'MA_LOOKBACK_DAYS',
      "! Minutes an interval may run (a row's RUN_LIMIT_MIN wins)
      run_limit_min TYPE zif_ca_ops_types=>ty_param_name VALUE 'MA_RUN_LIMIT_MIN',
      "! Run source class (ZIF_CA_OPS_MA_SRC)
      source        TYPE zif_ca_ops_types=>ty_param_name VALUE 'MA_SOURCE',
      "! Parent / child resolvers of the delivered source (blank = JOB_RESOLVERS of the job monitor)
      resolvers     TYPE zif_ca_ops_types=>ty_param_name VALUE 'MA_RESOLVERS',
      "! Parent jobs read per activity and intervals kept per run
      max_runs      TYPE zif_ca_ops_types=>ty_param_name VALUE 'MA_MAX_RUNS',
      max_intervals TYPE zif_ca_ops_types=>ty_param_name VALUE 'MA_MAX_INTERVALS',
    END OF gc_param.

  "! Code defaults (equal to the definition defaults)
  CONSTANTS:
    BEGIN OF gc_param_default,
      lookback_days TYPE i VALUE 2,
      run_limit_min TYPE i VALUE 120,
      source        TYPE string VALUE `ZCL_CA_OPS_MA_SRC_JOBS`,
      max_runs      TYPE i VALUE 200,
      max_intervals TYPE i VALUE 500,
    END OF gc_param_default.

  "! Messages of the mass activity check (message class ZCA_OPS, 615-629)
  CONSTANTS:
    BEGIN OF gc_msg,
      interval_failed TYPE zif_ca_ops_types=>ty_msgno VALUE '615',
      interval_job_ok TYPE zif_ca_ops_types=>ty_msgno VALUE '616',
      interval_long   TYPE zif_ca_ops_types=>ty_msgno VALUE '617',
      output_short    TYPE zif_ca_ops_types=>ty_msgno VALUE '618',
      output_job_ok   TYPE zif_ca_ops_types=>ty_msgno VALUE '619',
      config          TYPE zif_ca_ops_types=>ty_msgno VALUE '620',
      det_run         TYPE zif_ca_ops_types=>ty_msgno VALUE '621',
      det_interval    TYPE zif_ca_ops_types=>ty_msgno VALUE '622',
      det_output      TYPE zif_ca_ops_types=>ty_msgno VALUE '623',
    END OF gc_msg.

  "! A mass activity the area watches (ZCA_OPS_MAACT)
  TYPES:
    BEGIN OF ty_activity,
      area           TYPE zif_ca_ops_types=>ty_area,
      act_id         TYPE ty_act_id,
      description    TYPE c LENGTH 60,
      aktyp          TYPE ty_aktyp,
      parent_program TYPE zif_ca_ops_job_types=>ty_progname,
      job_pattern    TYPE zif_ca_ops_types=>ty_object_key,
      output_kind    TYPE ty_output_kind,
      min_output     TYPE i,
      run_limit_min  TYPE i,
    END OF ty_activity.
  TYPES tt_activity TYPE STANDARD TABLE OF ty_activity WITH EMPTY KEY.

  "! An interval of a run (the delivered source: a parallel job of the run, numbered in creation order)
  TYPES:
    BEGIN OF ty_interval,
      number  TYPE i,
      job     TYPE zif_ca_ops_job_types=>ty_job,
      state   TYPE ty_state,
      "! Minutes it has run (running) or ran (ended)
      minutes TYPE i,
    END OF ty_interval.
  TYPES tt_interval TYPE STANDARD TABLE OF ty_interval WITH EMPTY KEY.

  "! One run of a mass activity
  TYPES:
    BEGIN OF ty_run,
      act_id    TYPE ty_act_id,
      aktyp     TYPE ty_aktyp,
      "! Run date (LAUFD: the day the scheduler ran it) and run ID (LAUFI; blank = not known to the source)
      run_date  TYPE d,
      run_id    TYPE ty_run_id,
      parent    TYPE zif_ca_ops_job_types=>ty_job,
      intervals TYPE tt_interval,
      "! C = the source read the run's own records, P = derived from job names and times
      quality   TYPE zif_ca_ops_exc_contract=>ty_quality,
    END OF ty_run.
  TYPES tt_run TYPE STANDARD TABLE OF ty_run WITH EMPTY KEY.

  "! What a run source returns
  TYPES:
    BEGIN OF ty_runs,
      runs    TYPE tt_run,
      "! X = a cap was reached: more runs or intervals exist
      partial TYPE abap_bool,
    END OF ty_runs.

  "! Dunning notices of a run per currency (FKKMAKO)
  TYPES:
    BEGIN OF ty_notice_sum,
      run_date   TYPE d,
      run_id     TYPE ty_run_id,
      currency   TYPE zif_ca_ops_types=>ty_currency,
      item_count TYPE i,
      amount     TYPE zif_ca_ops_cash_types=>ty_amount,
    END OF ty_notice_sum.
  TYPES tt_notice_sum TYPE STANDARD TABLE OF ty_notice_sum WITH EMPTY KEY.

  "! The document output of a run against its expectation, per company code and currency
  TYPES:
    BEGIN OF ty_output,
      run_date        TYPE d,
      run_id          TYPE ty_run_id,
      company_code    TYPE bukrs,
      currency        TYPE zif_ca_ops_types=>ty_currency,
      expected_count  TYPE i,
      expected_amount TYPE zif_ca_ops_cash_types=>ty_amount,
      observed_count  TYPE i,
      observed_amount TYPE zif_ca_ops_cash_types=>ty_amount,
      "! X = amounts are known (payment documents); blank = count only (a minimum count)
      with_amount     TYPE abap_bool,
    END OF ty_output.
  TYPES tt_output TYPE STANDARD TABLE OF ty_output WITH EMPTY KEY.

ENDINTERFACE.
