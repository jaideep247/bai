*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_runtime_types.intf.abap
*& Purpose:
*& Types and constants of the read-only runtime checks of the morning
*& report: number ranges nearly exhausted (NRIV), qRFC / bgRFC queues in
*& error or stuck, payments issued but not cleared on the bank statement.
*& Check codes, parameter names and defaults, message numbers and the
*& delivered (VERIFY-DDIC) table and field names of the queue reads.
*& Modification log:
*& 2026-11-07 | Initial version (checks E_NUMRANGE, E_QUEUES, A_INFLIGHT).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - number range, queue, in-flight types</p>
"! Shared by ZCL_CD_HCK_C_NUMRANGE, ZCL_CD_HCK_C_QUEUES, ZCL_CD_HCK_C_INFLIGHT and
"! their data access ZIF_CD_HCK_RUNTIME_DAO. Read-only: nothing here writes SAP data.
INTERFACE zif_cd_hck_runtime_types
  PUBLIC.

  " ------------------------------------------------------------ number ranges
  "! NRIV-OBJECT (number range object, SNRO)
  TYPES ty_nr_object TYPE c LENGTH 10.
  TYPES tt_nr_object TYPE SORTED TABLE OF ty_nr_object WITH UNIQUE KEY table_line.
  "! NRIV-FROMNUMBER / TONUMBER / NRLEVEL: character fields (VERIFY-DDIC CHAR 20)
  TYPES ty_nr_number TYPE c LENGTH 20.
  TYPES ty_year TYPE n LENGTH 4.

  "! One internal interval of NRIV (EXTERNIND blank) - VERIFY-DDIC field names
  TYPES:
    BEGIN OF ty_nr_interval,
      object     TYPE ty_nr_object,
      subobject  TYPE c LENGTH 6,
      nrrangenr  TYPE c LENGTH 2,
      toyear     TYPE ty_year,
      fromnumber TYPE ty_nr_number,
      tonumber   TYPE ty_nr_number,
      nrlevel    TYPE ty_nr_number,
    END OF ty_nr_interval.
  TYPES tt_nr_interval TYPE STANDARD TABLE OF ty_nr_interval WITH EMPTY KEY.

  "! Year of a number range interval that is not year-dependent (NRIV-TOYEAR)
  CONSTANTS gc_nr_no_year TYPE ty_year VALUE '0000'.
  "! A number range limit or level is converted only when it consists of digits
  CONSTANTS gc_pcre_digits TYPE string VALUE `\d+`.

  " ------------------------------------------------------------ queues
  "! Queue source kind - also the threshold key (DIM1, 4 characters)
  TYPES ty_queue_kind TYPE c LENGTH 4.
  "! Problem class of a queue state: ERROR, HOLD or STUCK
  TYPES ty_queue_class TYPE c LENGTH 5.
  TYPES ty_queue_name TYPE c LENGTH 70.
  TYPES ty_queue_state TYPE c LENGTH 20.
  TYPES ty_tcode TYPE c LENGTH 20.

  CONSTANTS:
    BEGIN OF gc_queue_kind,
      outbound TYPE ty_queue_kind VALUE 'QOUT',
      inbound  TYPE ty_queue_kind VALUE 'QIN',
      bgrfc    TYPE ty_queue_kind VALUE 'BGRF',
    END OF gc_queue_kind.

  CONSTANTS:
    BEGIN OF gc_queue_class,
      error TYPE ty_queue_class VALUE 'ERROR',
      hold  TYPE ty_queue_class VALUE 'HOLD',
      stuck TYPE ty_queue_class VALUE 'STUCK',
    END OF gc_queue_class.

  "! Monitor transaction support uses per source (named in the finding; nothing is called)
  CONSTANTS:
    BEGIN OF gc_queue_tcode,
      outbound TYPE ty_tcode VALUE 'SMQ1',
      inbound  TYPE ty_tcode VALUE 'SMQ2',
      bgrfc    TYPE ty_tcode VALUE 'SBGRFCMON',
    END OF gc_queue_tcode.

  "! Where the entries of one queue source are read: table and the fields by role. The
  "! names are validated against the runtime DDIC before the read (unknown name = the source
  "! is reported QUEUE_CONFIG_INVALID, never read as empty)
  TYPES:
    BEGIN OF ty_queue_source,
      kind        TYPE ty_queue_kind,
      tabname     TYPE zif_cd_hck_types=>ty_tabname,
      name_field  TYPE zif_cd_hck_types=>ty_fieldname,
      dest_field  TYPE zif_cd_hck_types=>ty_fieldname,
      state_field TYPE zif_cd_hck_types=>ty_fieldname,
      date_field  TYPE zif_cd_hck_types=>ty_fieldname,
      time_field  TYPE zif_cd_hck_types=>ty_fieldname,
      "! The table name is configuration (bgRFC): it must be on ZCD_HCK_TABWL
      configured  TYPE abap_bool,
    END OF ty_queue_source.

  "! Entries of one queue, destination, state and day (oldest time of the day)
  TYPES:
    BEGIN OF ty_queue_group,
      name    TYPE ty_queue_name,
      dest    TYPE ty_queue_name,
      state   TYPE ty_queue_state,
      qdate   TYPE d,
      qtime   TYPE t,
      entries TYPE int8,
    END OF ty_queue_group.
  TYPES tt_queue_group TYPE STANDARD TABLE OF ty_queue_group WITH EMPTY KEY.

  "! Outbound qRFC queue entries (SMQ1). VERIFY-DDIC: every field name below
  CONSTANTS:
    BEGIN OF gc_trfcqout,
      tabname     TYPE zif_cd_hck_types=>ty_tabname VALUE 'TRFCQOUT',
      name_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QNAME',
      dest_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'DEST',
      state_field TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QSTATE',
      date_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QRFCDATUM',
      time_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QRFCUZEIT',
    END OF gc_trfcqout.

  "! Inbound qRFC queue entries (SMQ2). VERIFY-DDIC: every field name below (no destination)
  CONSTANTS:
    BEGIN OF gc_trfcqin,
      tabname     TYPE zif_cd_hck_types=>ty_tabname VALUE 'TRFCQIN',
      name_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QNAME',
      state_field TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QSTATE',
      date_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QRFCDATUM',
      time_field  TYPE zif_cd_hck_types=>ty_fieldname VALUE 'QRFCUZEIT',
    END OF gc_trfcqin.

  "! Names of the bgRFC source specification (PARAM4 of the queue check, NAME=VALUE;...)
  CONSTANTS:
    BEGIN OF gc_spec,
      table TYPE string VALUE `TABLE`,
      name  TYPE string VALUE `NAME`,
      dest  TYPE string VALUE `DEST`,
      state TYPE string VALUE `STATE`,
      date  TYPE string VALUE `DATE`,
      time  TYPE string VALUE `TIME`,
    END OF gc_spec.

  " ------------------------------------------------------------ payments in flight
  "! D disbursement (TFK042Z-XEINZ blank), C collection (XEINZ = X)
  TYPES ty_flow TYPE c LENGTH 1.
  "! Method class: WIR wire, ACH, CHQ cheque (mapping of payment methods in ZCA_PARAM)
  TYPES ty_method_class TYPE c LENGTH 3.
  "! Flow + method class, e.g. DWIR: the metric dimension and the threshold key
  TYPES ty_flow_class TYPE c LENGTH 4.
  TYPES ty_pymet TYPE c LENGTH 1.
  TYPES tt_pymet TYPE SORTED TABLE OF ty_pymet WITH UNIQUE KEY table_line.
  "! DFKKOP-AUGBL / DPAYH-DOC1R width (as ZIF_CD_OPS_TRACE_TYPES=>TY_DOCNO)
  TYPES ty_docno TYPE c LENGTH 12.
  "! BSEG-ZUONR (assignment; carries AUGBL for ACH and card)
  TYPES ty_zuonr TYPE c LENGTH 18.

  CONSTANTS:
    BEGIN OF gc_flow,
      disbursement TYPE ty_flow VALUE 'D',
      collection   TYPE ty_flow VALUE 'C',
    END OF gc_flow.

  CONSTANTS:
    BEGIN OF gc_method_class,
      wire   TYPE ty_method_class VALUE 'WIR',
      ach    TYPE ty_method_class VALUE 'ACH',
      cheque TYPE ty_method_class VALUE 'CHQ',
    END OF gc_method_class.

  "! Payment of a payment run (DPAYH, proposal runs excluded, DOC1R filled) with its flow.
  "! VERIFY-DDIC: DPAYH-BUKRS, PYMET, VALUT, RWBTR, WAERS; TFK042Z-XEINZ via T001-LAND1
  TYPES:
    BEGIN OF ty_issued_payment,
      doc1r    TYPE ty_docno,
      laufd    TYPE d,
      laufi    TYPE c LENGTH 6,
      bukrs    TYPE c LENGTH 4,
      pymet    TYPE ty_pymet,
      valut    TYPE d,
      amount   TYPE zif_cd_ops_types=>ty_amount,
      currency TYPE zif_cd_ops_types=>ty_currency,
      "! TFK042Z-XEINZ: X = collection, blank = disbursement
      xeinz    TYPE abap_bool,
    END OF ty_issued_payment.
  TYPES tt_issued_payment TYPE STANDARD TABLE OF ty_issued_payment WITH EMPTY KEY.

  "! Company code + assignment of a clearing-account line (collections: ZUONR = AUGBL)
  TYPES:
    BEGIN OF ty_assignment,
      bukrs TYPE c LENGTH 4,
      zuonr TYPE ty_zuonr,
    END OF ty_assignment.
  TYPES tt_assignment TYPE SORTED TABLE OF ty_assignment WITH UNIQUE KEY bukrs zuonr.

  " ------------------------------------------------------------ check codes
  CONSTANTS:
    BEGIN OF gc_code,
      "! Number range interval at or above the amber usage
      nr_usage_high      TYPE zif_cd_ops_types=>ty_check_code VALUE 'NR_USAGE_HIGH',
      "! A configured number range object has no internal interval of this or next year
      nr_no_interval     TYPE zif_cd_ops_types=>ty_check_code VALUE 'NR_NO_INTERVAL',
      "! Limits or level of an interval are not numeric / not a valid interval
      nr_not_numeric     TYPE zif_cd_ops_types=>ty_check_code VALUE 'NR_NOT_NUMERIC',
      queue_error        TYPE zif_cd_ops_types=>ty_check_code VALUE 'QUEUE_ERROR',
      queue_hold         TYPE zif_cd_ops_types=>ty_check_code VALUE 'QUEUE_HOLD',
      queue_stuck        TYPE zif_cd_ops_types=>ty_check_code VALUE 'QUEUE_STUCK',
      "! A queue source could not be read (DDIC, whitelist): nothing measured for it
      queue_config       TYPE zif_cd_ops_types=>ty_check_code VALUE 'QUEUE_CONFIG_INVALID',
      "! bgRFC source not configured (PARAM4 blank) - listed, not measured
      queue_not_watched  TYPE zif_cd_ops_types=>ty_check_code VALUE 'QUEUE_NOT_MONITORED',
      "! Payments of a flow / method class not cleared on the bank statement past the limit
      payment_not_clear  TYPE zif_cd_ops_types=>ty_check_code VALUE 'PAYMENT_NOT_CLEARED',
      "! Payments aged from the run date because the value date is missing
      value_date_missing TYPE zif_cd_ops_types=>ty_check_code VALUE 'VALUE_DATE_MISSING',
      "! Configuration of the in-flight check incomplete (calendar, method class)
      inflight_config    TYPE zif_cd_ops_types=>ty_check_code VALUE 'INFLIGHT_CONFIG',
      "! No ZCD_HCK_THRESH limits for a metric the check classifies by - not evaluated
      limits_missing     TYPE zif_cd_ops_types=>ty_check_code VALUE 'LIMITS_NOT_CONFIGURED',
      "! A read reached its row cap: the result may be incomplete
      read_capped        TYPE zif_cd_ops_types=>ty_check_code VALUE 'TECH_READ_CAPPED',
    END OF gc_code.

  " ------------------------------------------------------------ parameters (ZCA_PARAM)
  "! Hard ceilings of the row caps HCK_MAX_TECH_ROWS / HCK_INFLIGHT_MAX_ROWS
  CONSTANTS gc_max_tech_rows TYPE i VALUE 50000.
  CONSTANTS gc_max_inflight_rows TYPE i VALUE 50000.

  CONSTANTS:
    BEGIN OF gc_param,
      "! qRFC / bgRFC states that are an error (comma list)
      queue_err_states  TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_QUEUE_ERR_STATES',
      "! States that hold a queue (stopped)
      queue_hold_states TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_QUEUE_HOLD_STATES',
      "! States that are normal unless older than the check's age limit (stuck)
      queue_wait_states TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_QUEUE_WAIT_STATES',
      "! Rows of one technical read (NRIV intervals, queue groups)
      max_tech_rows     TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_MAX_TECH_ROWS',
      "! Payment methods per method class (comma lists of SAP payment methods)
      inflight_wire     TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_INFLIGHT_WIRE_METHODS',
      inflight_ach      TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_INFLIGHT_ACH_METHODS',
      inflight_cheque   TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_INFLIGHT_CHQ_METHODS',
      "! Payments read per window (DPAYH)
      inflight_max_rows TYPE zif_cd_ops_types=>ty_param_name VALUE 'HCK_INFLIGHT_MAX_ROWS',
    END OF gc_param.

  CONSTANTS:
    BEGIN OF gc_param_default,
      queue_err_states  TYPE string VALUE `SYSFAIL,CPICERR`,
      queue_hold_states TYPE string VALUE `STOP,WAITSTOP`,
      queue_wait_states TYPE string VALUE `READY,RUNNING`,
      max_tech_rows     TYPE i VALUE 5000,
      inflight_cheque   TYPE string VALUE `C`,
      inflight_max_rows TYPE i VALUE 5000,
    END OF gc_param_default.

  "! Defaults of the check parameters (PARAM1-4 of ZCD_HCK_DEF) when blank
  CONSTANTS:
    BEGIN OF gc_check_default,
      "! E_QUEUES PARAM3: READY / RUNNING older than this is stuck (minutes)
      queue_stuck_min TYPE i VALUE 30,
      "! A_INFLIGHT PARAM2 / PARAM3: look-back of wire / ACH and of cheques (days)
      inflight_days   TYPE i VALUE 10,
      cheque_days     TYPE i VALUE 120,
      "! A_INFLIGHT PARAM4: payments listed per finding (oldest first)
      top_n           TYPE i VALUE 10,
      "! Longest day range counted in business days (calendar reads per run)
      max_calendar    TYPE i VALUE 400,
    END OF gc_check_default.

  " ------------------------------------------------------------ messages (class ZCD_OPS)
  CONSTANTS:
    BEGIN OF gc_msg,
      nr_usage            TYPE zif_cd_ops_types=>ty_msgno VALUE '376',
      nr_no_interval      TYPE zif_cd_ops_types=>ty_msgno VALUE '377',
      nr_not_numeric      TYPE zif_cd_ops_types=>ty_msgno VALUE '378',
      read_capped         TYPE zif_cd_ops_types=>ty_msgno VALUE '379',
      queue_group         TYPE zif_cd_ops_types=>ty_msgno VALUE '380',
      queue_detail        TYPE zif_cd_ops_types=>ty_msgno VALUE '381',
      queue_source_failed TYPE zif_cd_ops_types=>ty_msgno VALUE '382',
      bgrfc_not_watched   TYPE zif_cd_ops_types=>ty_msgno VALUE '383',
      limits_missing      TYPE zif_cd_ops_types=>ty_msgno VALUE '386',
      no_calendar         TYPE zif_cd_ops_types=>ty_msgno VALUE '387',
      not_cleared         TYPE zif_cd_ops_types=>ty_msgno VALUE '388',
      payment_line        TYPE zif_cd_ops_types=>ty_msgno VALUE '389',
      payment_age         TYPE zif_cd_ops_types=>ty_msgno VALUE '390',
      run_date_used       TYPE zif_cd_ops_types=>ty_msgno VALUE '391',
      value_date_missing  TYPE zif_cd_ops_types=>ty_msgno VALUE '392',
      class_not_watched   TYPE zif_cd_ops_types=>ty_msgno VALUE '393',
    END OF gc_msg.

ENDINTERFACE.
