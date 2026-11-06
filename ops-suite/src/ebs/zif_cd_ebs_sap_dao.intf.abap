*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ebs_sap_dao.intf.abap
*& Purpose:
*& All reads used by the business rules (R07*, R08, R12, R18, R19). Keys are
*& already normalised by the caller. Every method returns an empty table for an
*& empty key list (FOR ALL ENTRIES guard lives here).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | TY_CHECK carries HBKID/HKTID (review 3.2).
*& 2026-11-06 | Generic lookup rule R21 (ZCD_EBS_LOOKUP) - new validations by configuration.
*& 2026-11-06 | Audit A07: company code of the register row (optional, configured field).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - payment engine reads for line rules</p>
"! All reads used by the business rules (R07*, R08, R12, R18, R19). Keys are
"! already normalised by the caller. Every method returns an empty table for an
"! empty key list (FOR ALL ENTRIES guard lives here).
INTERFACE zif_cd_ebs_sap_dao
  PUBLIC.

  TYPES ty_docno TYPE c LENGTH 12.
  TYPES tt_docno TYPE SORTED TABLE OF ty_docno WITH UNIQUE KEY table_line.
  TYPES ty_ztnum TYPE c LENGTH 35.
  TYPES tt_ztnum TYPE SORTED TABLE OF ty_ztnum WITH UNIQUE KEY table_line.
  TYPES ty_status TYPE c LENGTH 20.

  "! Returns lot item (DFKKRP) found by the payment document in SELW1
  TYPES:
    BEGIN OF ty_return_item,
      selw1     TYPE ty_docno,
      opbel     TYPE ty_docno,
      "! Returns lot status (DFKKRK-STARS via DFKKRP-OPBEL, as in legacy v4)
      lot_stars TYPE ty_status,
    END OF ty_return_item.
  TYPES tt_return_item TYPE STANDARD TABLE OF ty_return_item WITH EMPTY KEY.

  "! Payment header (DPAYH) by payment document DOC1R
  TYPES:
    BEGIN OF ty_payment,
      doc1r  TYPE ty_docno,
      laufd  TYPE d,
      laufi  TYPE c LENGTH 6,
      status TYPE ty_status,
    END OF ty_payment.
  TYPES tt_payment TYPE STANDARD TABLE OF ty_payment WITH EMPTY KEY.

  "! ACH retrieval log (ZCD_ACH_RTRV_LOG) by clearing document
  TYPES:
    BEGIN OF ty_retrieval,
      augbl  TYPE ty_docno,
      status TYPE ty_status,
    END OF ty_retrieval.
  TYPES tt_retrieval TYPE STANDARD TABLE OF ty_retrieval WITH EMPTY KEY.

  "! Check register (DFKKCR) by check number
  TYPES:
    BEGIN OF ty_check,
      ztnum    TYPE ty_ztnum,
      "! Company code of the register row (A07) - only when EBS_DFKKCR_BUKRS_FIELD names a
      "! DFKKCR field (VERIFY-DDIC); blank otherwise
      bukrs    TYPE c LENGTH 4,
      "! House bank / account: ZTNUM is unique only within them (review 3.2)
      hbkid    TYPE c LENGTH 5,
      hktid    TYPE c LENGTH 5,
      doc1r    TYPE ty_docno,
      amount   TYPE zif_cd_ops_types=>ty_amount,
      crstatus TYPE ty_status,
    END OF ty_check.
  TYPES tt_check TYPE STANDARD TABLE OF ty_check WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_fi_key,
      bukrs TYPE c LENGTH 4,
      belnr TYPE c LENGTH 10,
      gjahr TYPE n LENGTH 4,
    END OF ty_fi_key.
  TYPES tt_fi_key TYPE SORTED TABLE OF ty_fi_key WITH UNIQUE KEY bukrs belnr gjahr.

  "! FI document line (BSEG) with clearing information
  TYPES:
    BEGIN OF ty_fi_line,
      bukrs TYPE c LENGTH 4,
      belnr TYPE c LENGTH 10,
      gjahr TYPE n LENGTH 4,
      buzei TYPE n LENGTH 3,
      hkont TYPE c LENGTH 10,
      augbl TYPE c LENGTH 10,
    END OF ty_fi_line.
  TYPES tt_fi_line TYPE STANDARD TABLE OF ty_fi_line WITH EMPTY KEY.

  METHODS get_return_items
    IMPORTING
      it_docno        TYPE tt_docno
    RETURNING
      VALUE(rt_items) TYPE tt_return_item.

  METHODS get_payments
    IMPORTING
      it_docno           TYPE tt_docno
    RETURNING
      VALUE(rt_payments) TYPE tt_payment.

  "! Generic lookup (rule R21): key of a configured table, as text
  TYPES ty_lookup_key TYPE c LENGTH 70.
  TYPES tt_lookup_key TYPE SORTED TABLE OF ty_lookup_key WITH UNIQUE KEY table_line.
  TYPES:
    BEGIN OF ty_lookup_row,
      lookup_key TYPE ty_lookup_key,
      status     TYPE c LENGTH 40,
    END OF ty_lookup_row.
  TYPES tt_lookup_row TYPE STANDARD TABLE OF ty_lookup_row WITH EMPTY KEY.

  "! Rows of the configured table for the keys (key field, status field). Table and field
  "! names are validated against the DDIC; an unknown name raises (rule fails closed).
  METHODS get_lookup_rows
    IMPORTING
      is_lookup      TYPE zif_cd_ebs_types=>ty_lookup_cfg
      it_keys        TYPE tt_lookup_key
    RETURNING
      VALUE(rt_rows) TYPE tt_lookup_row
    RAISING
      zcx_cd_ops_error.

  METHODS get_retrievals
    IMPORTING
      it_docno             TYPE tt_docno
    RETURNING
      VALUE(rt_retrievals) TYPE tt_retrieval
    RAISING
      zcx_cd_ops_error.

  METHODS get_checks
    IMPORTING
      it_ztnum         TYPE tt_ztnum
    RETURNING
      VALUE(rt_checks) TYPE tt_check.

  METHODS get_fi_lines
    IMPORTING
      it_keys         TYPE tt_fi_key
    RETURNING
      VALUE(rt_lines) TYPE tt_fi_line.

  "! Bank G/L balance in transaction currency up to and including iv_date
  METHODS get_gl_balance
    IMPORTING
      iv_bukrs          TYPE zif_cd_ebs_sap_dao=>ty_fi_key-bukrs
      iv_gl_account     TYPE zif_cd_ebs_sap_dao=>ty_fi_line-hkont
      iv_currency       TYPE zif_cd_ops_types=>ty_currency
      iv_date           TYPE d
    RETURNING
      VALUE(rv_balance) TYPE zif_cd_ops_types=>ty_amount.

ENDINTERFACE.
