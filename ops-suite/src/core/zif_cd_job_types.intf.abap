*&---------------------------------------------------------------------*
*& Artifact: zif_cd_job_types.intf.abap
*& Purpose:
*& Types and constants of the suite's adoption of the framework's SAP job
*& monitor (area CD_JOBS, decision D-PO1: own area per process): the
*& payment engine plug-ins - mass activity resolver and enricher, payment
*& run enricher, the health check's claim of its named job cycles - their
*& parameters (prefix JOB_, area CA_OPS, delivered by the suite), business
*& object types, the job-cycle check class of the health check and the
*& messages 841-843 of ZCD_OPS. No logic.
*& Modification log:
*& 2026-11-11 | Initial version (SAP job monitor adoption, area CD_JOBS).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - SAP job monitor plug-in types</p>
INTERFACE zif_cd_job_types
  PUBLIC.

  "! Area of the SAP job monitor's runs and findings in the suite (parameter area of ZCA_PARAM)
  CONSTANTS gc_area TYPE zif_ca_ops_types=>ty_area VALUE 'CD_JOBS'.

  "! Business object types of the suite's enrichers (ZCA_OPS_JOBBO-OBJECT_TYPE)
  CONSTANTS:
    BEGIN OF gc_object_type,
      "! A mass activity run: activity type / run date / run ID
      mass_run     TYPE zif_ca_ops_job_types=>ty_bo_type VALUE 'MASS_ACTIVITY_RUN',
      "! A payment run (DPAYH LAUFD / LAUFI)
      payment_run  TYPE zif_ca_ops_job_types=>ty_bo_type VALUE 'PAYMENT_RUN',
      "! Open exceptions of the payment run in the payment worklist (ZCD_PAY_OUTCOME)
      worklist     TYPE zif_ca_ops_job_types=>ty_bo_type VALUE 'PAYMENT_WORKLIST',
    END OF gc_object_type.

  "! Separator of the parts of a business object key
  CONSTANTS gc_key_separator TYPE string VALUE `/`.
  "! Resolver ID of the mass activity resolver
  CONSTANTS gc_resolver_mass TYPE zif_ca_ops_job_types=>ty_resolver_id VALUE 'MASSACT'.
  "! Class of the health check's job-cycle checks (B_CYCLE_*, B_CLEAR_*): their cycles are claimed
  CONSTANTS gc_cycle_check_class TYPE zif_ca_ops_types=>ty_class_name VALUE 'ZCL_CD_HCK_C_JOB_CYCLE'.
  "! Prefix of the claimer shown on the board (the health check reports the step)
  CONSTANTS gc_claimer_prefix TYPE string VALUE `HCK`.

  "! Parameters of the suite's plug-ins (area CA_OPS, definitions of the suite)
  CONSTANTS:
    BEGIN OF gc_param,
      "! Mass activity: PCRE of a worker job name, group 1 = the run token shared with its scheduler job
      "! (VERIFY-SE11 V67; blank = the mass activity resolver is off)
      ma_worker_pcre    TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_MA_WORKER_PCRE',
      "! Mass activity: PCRE of the scheduler job name, group 1 = the same run token (blank = time and user)
      ma_sched_pcre     TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_MA_SCHED_PCRE',
      "! Mass activity: programs of the scheduler step [RFKK_MA_SCHEDULER]
      ma_programs       TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_MA_PROGRAMS',
      "! Mass activity: PCRE of a job name, group 1 = activity type, 2 = run date (YYYYMMDD), 3 = run ID
      "! (VERIFY-SE11 V67; blank = the mass activity enricher adds nothing)
      ma_run_pcre       TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_MA_RUN_PCRE',
      "! Payment run: mass activity types of the payment run FPY1 (VERIFY-SE11 V68; blank = off)
      payrun_activities TYPE zif_ca_ops_types=>ty_param_name VALUE 'JOB_PAYRUN_ACTIVITIES',
    END OF gc_param.

  CONSTANTS:
    BEGIN OF gc_param_default,
      ma_programs TYPE string VALUE `RFKK_MA_SCHEDULER`,
    END OF gc_param_default.

  "! Messages of the plug-ins (message class ZCD_OPS, 841-859)
  CONSTANTS:
    BEGIN OF gc_msg,
      mass_run    TYPE zif_ca_ops_types=>ty_msgno VALUE '841',
      payment_run TYPE zif_ca_ops_types=>ty_msgno VALUE '842',
      worklist    TYPE zif_ca_ops_types=>ty_msgno VALUE '843',
    END OF gc_msg.

  "! A mass activity run read from a job name
  TYPES:
    BEGIN OF ty_mass_run,
      activity TYPE c LENGTH 4,
      run_date TYPE d,
      run_id   TYPE c LENGTH 6,
    END OF ty_mass_run.

  "! Payments of a payment run per company code (DPAYH)
  TYPES:
    BEGIN OF ty_run_payments,
      laufd    TYPE d,
      laufi    TYPE c LENGTH 6,
      bukrs    TYPE bukrs,
      payments TYPE i,
    END OF ty_run_payments.
  TYPES tt_run_payments TYPE STANDARD TABLE OF ty_run_payments WITH EMPTY KEY.

  "! Open exceptions of a payment run in the payment worklist
  TYPES:
    BEGIN OF ty_run_exceptions,
      laufd      TYPE d,
      laufi      TYPE c LENGTH 6,
      exceptions TYPE i,
    END OF ty_run_exceptions.
  TYPES tt_run_exceptions TYPE STANDARD TABLE OF ty_run_exceptions WITH EMPTY KEY.

  "! A payment run key (run date, run ID)
  TYPES:
    BEGIN OF ty_run_key,
      laufd TYPE d,
      laufi TYPE c LENGTH 6,
    END OF ty_run_key.
  TYPES tt_run_key TYPE SORTED TABLE OF ty_run_key WITH UNIQUE KEY laufd laufi.

ENDINTERFACE.
