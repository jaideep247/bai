*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_docchg_types.intf.abap
*& Purpose:
*& Types and constants of the document-change risk check A_DOC_CHANGE
*& (ZCL_CD_HCK_C_DOCCHG, build C): check codes, metrics, ZCD_OPS messages
*& 860-889, evidence codes, defaults of the check row parameters PARAM1-4.
*& Modification log:
*& 2026-11-11 | Initial version (reversal and reset-clearing tracking, build C).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - document-change risk types</p>
INTERFACE zif_cd_hck_docchg_types
  PUBLIC.

  "! Payment engine document number (DFKKKO-OPBEL, DPAYH-DOC1R)
  TYPES ty_docno TYPE c LENGTH 12.
  "! Payment status DPAYH-ZZ_PAYMENT_STATUS (confirmed values ISSUED, CONFIRMED, CLEARED, RETURNED,
  "! RETRIEVED, STOPPED)
  TYPES ty_pay_status TYPE c LENGTH 20.
  TYPES tt_pay_status TYPE SORTED TABLE OF ty_pay_status WITH UNIQUE KEY table_line.
  "! Evidence that a payment left SAP
  TYPES ty_evidence TYPE c LENGTH 20.

  "! A reversed payment document with the reversal and one payment run of the document (several
  "! runs of one document are several rows; the check keeps the latest - LAUFD, then LAUFI)
  TYPES:
    BEGIN OF ty_reversal,
      payment_doc  TYPE ty_docno,
      reversal_doc TYPE ty_docno,
      "! Reconciliation key of the reversal document (its G/L transfer)
      fikey        TYPE zif_cd_hck_types=>ty_fikey,
      "! Entry date of the reversal document (DFKKKO-CPUDT)
      reversed_on  TYPE d,
      laufd        TYPE d,
      laufi        TYPE c LENGTH 6,
      bukrs        TYPE c LENGTH 4,
      status       TYPE ty_pay_status,
      amount       TYPE zif_ca_ops_types=>ty_amount,
      currency     TYPE zif_ca_ops_types=>ty_currency,
    END OF ty_reversal.
  TYPES tt_reversal TYPE STANDARD TABLE OF ty_reversal WITH EMPTY KEY.

  "! Check codes of A_DOC_CHANGE (severity E: an owned exception each)
  CONSTANTS:
    BEGIN OF gc_code,
      "! A payment reversed after it left SAP (file sent, bank ACK, bank line, cheque cashed):
      "! possible double payment or an orphaned bank item
      left_sap   TYPE zif_ca_ops_types=>ty_check_code VALUE 'REV_AFTER_LEFT_SAP',
      "! A payment engine reversal whose reconciliation key has no G/L transfer: the G/L still
      "! shows the payment
      gl_not_rev TYPE zif_ca_ops_types=>ty_check_code VALUE 'REV_GL_NOT_REVERSED',
      "! A bank statement line that references a reversed payment document (variance bucket
      "! reset / reversal of the ledger reconciliation)
      bank_line  TYPE zif_ca_ops_types=>ty_check_code VALUE 'REV_BANK_LINE',
      "! A read reached its row cap (warning; evidence PARTIAL)
      capped     TYPE zif_ca_ops_types=>ty_check_code VALUE 'REV_READ_CAPPED',
    END OF gc_code.

  "! Metrics (DIM1 *): reversed payments read and the three risks
  CONSTANTS:
    BEGIN OF gc_metric,
      reversals  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'RV_REVERSALS',
      left_sap   TYPE zif_cd_hck_types=>ty_metric_name VALUE 'RV_LEFT_SAP',
      gl_not_rev TYPE zif_cd_hck_types=>ty_metric_name VALUE 'RV_GL_NOT_REV',
      bank_line  TYPE zif_cd_hck_types=>ty_metric_name VALUE 'RV_BANK_LINE',
    END OF gc_metric.

  "! ZCD_OPS messages of the check (range 860-889, build C)
  CONSTANTS:
    BEGIN OF gc_msg,
      left_sap   TYPE zif_ca_ops_types=>ty_msgno VALUE '860',
      gl_not_rev TYPE zif_ca_ops_types=>ty_msgno VALUE '861',
      bank_line  TYPE zif_ca_ops_types=>ty_msgno VALUE '862',
      capped     TYPE zif_ca_ops_types=>ty_msgno VALUE '863',
    END OF gc_msg.

  "! Evidence that the payment had left SAP (fourth variable of message 860)
  CONSTANTS:
    BEGIN OF gc_evidence,
      bank_line     TYPE ty_evidence VALUE 'BANK_LINE',
      cheque_cashed TYPE ty_evidence VALUE 'CHEQUE_CASHED',
    END OF gc_evidence.

  "! Object key prefixes of the findings (<prefix>/<document>[/<line>])
  CONSTANTS:
    BEGIN OF gc_key,
      left_sap   TYPE string VALUE `LEFT`,
      gl_not_rev TYPE string VALUE `GLREV`,
      bank_line  TYPE string VALUE `BANK`,
      separator  TYPE string VALUE `/`,
    END OF gc_key.

  "! Cheque status DFKKCR-STATE cashed (confirmed 2026-11-07: B cashed, V voided, blank open)
  CONSTANTS gc_cheque_cashed TYPE c LENGTH 1 VALUE 'B'.

  "! Defaults of the check row (ZCD_HCK_DEF): PARAM1 window days, PARAM2 G/L lag days, PARAM3 row
  "! cap, PARAM4 payment statuses that mean the payment left SAP (comma list)
  CONSTANTS:
    BEGIN OF gc_default,
      window_days   TYPE i VALUE 7,
      lag_days      TYPE i VALUE 1,
      max_rows      TYPE i VALUE 500,
      left_statuses TYPE string VALUE `ISSUED,CONFIRMED,CLEARED,RETURNED,RETRIEVED`,
    END OF gc_default.

ENDINTERFACE.
