*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_cheque_types.intf.abap
*& Purpose:
*& Types and constants of the pilot acceptance checks of the first
*& customer's daily controls (build R): ECT pending cheques (C_ECT_PENDING,
*& control ECT_PENDING, proposal P3), cheque payments without a cheque
*& number (C_CHQ_NO_ID, control MISSING_CHECK_IDS, proposal P6), the cheque
*& register rows (DFKKCR) and cheque payments (DPAYH) they read, and the
*& exposure of a finding set per currency (count, amount, oldest age,
*& deadline). Messages 900-909 and 913-917 of class ZCD_OPS. No logic.
*& Modification log:
*& 2026-11-16 | Initial version (build R: pilot acceptance items of the first customer's daily controls).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - cheque pilot checks (types)</p>
INTERFACE zif_cd_hck_cheque_types
  PUBLIC.

  TYPES ty_cheque_no TYPE c LENGTH 13.
  TYPES ty_docno     TYPE c LENGTH 24.
  TYPES ty_laufi     TYPE c LENGTH 6.
  TYPES ty_pymet     TYPE c LENGTH 1.
  TYPES ty_hbkid     TYPE c LENGTH 5.
  TYPES ty_state     TYPE c LENGTH 1.
  TYPES tt_cheque_no TYPE SORTED TABLE OF ty_cheque_no WITH UNIQUE KEY table_line.
  TYPES tt_pymet     TYPE SORTED TABLE OF ty_pymet WITH UNIQUE KEY table_line.

  "! Cheque register row (DFKKCR; fields seen on the reference system S/4HANA 2025, ddic/a4h): cheque
  "! number ZTNUM, payment document DOC1R (= DFKKOP-AUGBL, confirmed), paying company code BBUKR,
  "! house bank, amount RBETR / WAERS, run date LAUFD, cheque state STATE (B cashed, V voided, blank open)
  "! and the encashment date BNKDT the bank statement import writes (test tool fact 2026-11-16)
  TYPES:
    BEGIN OF ty_register,
      ztnum    TYPE ty_cheque_no,
      doc1r    TYPE ty_docno,
      bukrs    TYPE bukrs,
      hbkid    TYPE ty_hbkid,
      amount   TYPE zif_ca_ops_types=>ty_amount,
      currency TYPE zif_ca_ops_types=>ty_currency,
      laufd    TYPE d,
      state    TYPE ty_state,
      bnkdt    TYPE d,
    END OF ty_register.
  TYPES tt_register TYPE STANDARD TABLE OF ty_register WITH EMPTY KEY.

  "! Cheque payment of a payment run (DPAYH, no proposal run) - paying company code BBUKR, method RZAWE
  TYPES:
    BEGIN OF ty_payment,
      doc1r    TYPE ty_docno,
      laufd    TYPE d,
      laufi    TYPE ty_laufi,
      bukrs    TYPE bukrs,
      pymet    TYPE ty_pymet,
      hbkid    TYPE ty_hbkid,
      amount   TYPE zif_ca_ops_types=>ty_amount,
      currency TYPE zif_ca_ops_types=>ty_currency,
    END OF ty_payment.
  TYPES tt_payment TYPE STANDARD TABLE OF ty_payment WITH EMPTY KEY.

  "! One item of a finding set (a pending cheque, a payment without cheque number, a request)
  TYPES:
    BEGIN OF ty_item,
      object_key TYPE zif_ca_ops_types=>ty_object_key,
      reference  TYPE zif_ca_ops_types=>ty_reference,
      bukrs      TYPE bukrs,
      amount     TYPE zif_ca_ops_types=>ty_amount,
      currency   TYPE zif_ca_ops_types=>ty_currency,
      "! Age in the unit of the check (days; hours for the collections checks)
      age        TYPE i,
      event_date TYPE d,
      deadline   TYPE d,
    END OF ty_item.
  TYPES tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

  "! Exposure of a finding set per currency (blank currency = amount not known)
  TYPES:
    BEGIN OF ty_total,
      currency   TYPE zif_ca_ops_types=>ty_currency,
      item_count TYPE i,
      amount     TYPE zif_ca_ops_types=>ty_amount,
      oldest     TYPE i,
      oldest_key TYPE zif_ca_ops_types=>ty_object_key,
      deadline   TYPE d,
    END OF ty_total.
  TYPES tt_total TYPE SORTED TABLE OF ty_total WITH UNIQUE KEY currency.

  "! Check codes of the findings
  CONSTANTS:
    BEGIN OF gc_code,
      ect_pending     TYPE zif_ca_ops_types=>ty_check_code VALUE 'ECT_CHEQUE_PENDING',
      ect_no_register TYPE zif_ca_ops_types=>ty_check_code VALUE 'ECT_PENDING_NO_REGISTER',
      cheque_no_id    TYPE zif_ca_ops_types=>ty_check_code VALUE 'CHEQUE_NUMBER_MISSING',
      "! One summary finding per currency of a check (information: count, amount, oldest, deadline)
      exposure        TYPE zif_ca_ops_types=>ty_check_code VALUE 'EXPOSURE_PER_CURRENCY',
      read_capped     TYPE zif_ca_ops_types=>ty_check_code VALUE 'READ_CAPPED',
    END OF gc_code.

  "! Metrics (thresholds ZCD_HCK_THRESH)
  CONSTANTS:
    BEGIN OF gc_metric,
      ect_count    TYPE zif_cd_hck_types=>ty_metric_name VALUE 'ECT_PENDING',
      ect_age      TYPE zif_cd_hck_types=>ty_metric_name VALUE 'ECT_PENDING_AGE',
      no_id_count  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'CHEQUE_NO_ID',
    END OF gc_metric.

  "! Names of the check parameters (PARAM1-2 of ZCD_HCK_DEF, NAME=VALUE pairs)
  CONSTANTS:
    BEGIN OF gc_spec,
      pending TYPE string VALUE `PENDING`,
      days    TYPE string VALUE `DAYS`,
      max     TYPE string VALUE `MAX`,
      rows    TYPE string VALUE `ROWS`,
      methods TYPE string VALUE `METHODS`,
      offset  TYPE string VALUE `OFFSET`,
      control TYPE string VALUE `CONTROL`,
    END OF gc_spec.
  CONSTANTS:
    BEGIN OF gc_default,
      "! Days of cheque history read back (a pending cheque older than this is not seen - pilot item)
      days      TYPE i VALUE 180,
      max       TYPE i VALUE 200,
      rows      TYPE i VALUE 50000,
      "! Run dates checked: the payment runs of the day before the report date
      offset    TYPE i VALUE 1,
      run_days  TYPE i VALUE 1,
      ect_ctl   TYPE string VALUE `ECT_PENDING`,
      no_id_ctl TYPE string VALUE `MISSING_CHECK_IDS`,
    END OF gc_default.

  "! Text of a placeholder (angle quotes): a parameter value that still holds one is not configured
  CONSTANTS gc_placeholder_open TYPE string VALUE `‹`.
  "! Cheque register states: blank = open; B cashed, V voided (DFKKCR-STATE, user 2026-11-15)
  CONSTANTS gc_state_open TYPE ty_state VALUE ' '.

  "! Messages of class ZCD_OPS
  CONSTANTS:
    BEGIN OF gc_msg,
      ect_pending      TYPE zif_ca_ops_types=>ty_msgno VALUE '900',
      ect_no_register  TYPE zif_ca_ops_types=>ty_msgno VALUE '901',
      exposure         TYPE zif_ca_ops_types=>ty_msgno VALUE '902',
      cheque_no_id     TYPE zif_ca_ops_types=>ty_msgno VALUE '903',
      not_configured   TYPE zif_ca_ops_types=>ty_msgno VALUE '904',
      read_capped      TYPE zif_ca_ops_types=>ty_msgno VALUE '905',
      ctx_deadline     TYPE zif_ca_ops_types=>ty_msgno VALUE '913',
      ctx_age_days     TYPE zif_ca_ops_types=>ty_msgno VALUE '914',
      ctx_control      TYPE zif_ca_ops_types=>ty_msgno VALUE '915',
      ctx_age_hours    TYPE zif_ca_ops_types=>ty_msgno VALUE '916',
      ctx_evidence     TYPE zif_ca_ops_types=>ty_msgno VALUE '917',
    END OF gc_msg.

ENDINTERFACE.
