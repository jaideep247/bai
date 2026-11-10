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
*& 2026-11-06 | Audit A28: get_febep_reasons (configured FEBEP field, DEFAULT IGNORE).
*& 2026-11-06 | Audit A65: TY_DOCNO width is the document key width (VERIFY-DDIC OPBEL_KK / AUGBL_KK / DOC1R CHAR 12).
*& 2026-11-06 | Operating model: get_febep_posting (FEBEP posting-area flags, DEFAULT IGNORE).
*& 2026-11-06 | Performance fix 3: get_febep_reasons / get_febep_posting moved into ZIF_CD_EBS_FEB_DAO get_items.
*& 2026-11-06 | Performance fix 4: non-unique sorted secondary keys on the result tables (rules loop USING KEY).
*& 2026-11-06 | Performance fix 6: get_gl_balances - one ACDOCA aggregate for all closing statements (was one per statement).
*& 2026-11-06 | Sorted/hashed sweep: keyed lookups by sorted secondary keys / hashed tables (Performance_Review.md).
*& 2026-11-06 | Return / NOC reason correction: TY_RETURN_ITEM-RLGRD (DFKKRP return reason, same read);
*&            | get_noc_items - NOC lot items (DFKKNRP) by INFOF with their NOC reason FLGRD.
*& 2026-11-07 | TY_RETURN_ITEM-AMOUNT (DFKKRP-BETRW) for the in-flight check (shared read, A_INFLIGHT).
*& 2026-11-08 | Customer posting area: FICA_REASON is a result of ZRSN (was ZCD_EBS_RSN_MAP) - comment only.
*& 2026-11-10 | is_lookup_field_approved: ZCD_OPS_TABWL row EBS / LOOKUP for the table and field (R21,
*&            | DEFAULT IGNORE); get_lookup_rows reads only approved fields with S_TABU_NAM 03.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - payment engine reads for line rules</p>
"! All reads used by the business rules (R07*, R08, R12, R18, R19). Keys are
"! already normalised by the caller. Every method returns an empty table for an
"! empty key list (FOR ALL ENTRIES guard lives here).
INTERFACE zif_cd_ebs_sap_dao
  PUBLIC.

  "! A65: key width of OPBEL / AUGBL / DOC1R - rules read it from this type, never truncate to
  "! it (VERIFY-DDIC: OPBEL_KK, AUGBL_KK and DPAYH-DOC1R are CHAR 12)
  TYPES ty_docno TYPE c LENGTH 12.
  TYPES tt_docno TYPE SORTED TABLE OF ty_docno WITH UNIQUE KEY table_line.
  TYPES ty_ztnum TYPE c LENGTH 35.
  TYPES tt_ztnum TYPE SORTED TABLE OF ty_ztnum WITH UNIQUE KEY table_line.
  TYPES ty_status TYPE c LENGTH 20.
  "! Payment engine return / NOC reason of a lot item (DFKKRP-RLGRD, DFKKNRP-FLGRD; VERIFY-SE11
  "! length 3 as the ZRSN result FICA_REASON)
  TYPES ty_lot_reason TYPE c LENGTH 3.
  "! DFKKNRP-INFOF (CHAR 50): the payment document (AUGBL) or the payment reference
  TYPES ty_infof TYPE c LENGTH 50.
  TYPES tt_infof TYPE SORTED TABLE OF ty_infof WITH UNIQUE KEY table_line.

  "! Returns lot item (DFKKRP) found by the payment document in SELW1
  TYPES:
    BEGIN OF ty_return_item,
      selw1     TYPE ty_docno,
      opbel     TYPE ty_docno,
      "! Returns lot status (DFKKRK-STARS via DFKKRP-OPBEL, as in legacy v4)
      lot_stars TYPE ty_status,
      "! Return reason of the item (DFKKRP-RLGRD, VERIFY-SE11) - FEBEP carries no return reason
      rlgrd     TYPE ty_lot_reason,
      "! Returned amount of the item (DFKKRP-BETRW, VERIFY-DDIC) - the morning report compares it
      "! with the return line of the bank statement (A_INFLIGHT)
      amount    TYPE zif_ca_ops_types=>ty_amount,
    END OF ty_return_item.
  "! Fix 4: secondary key BY_SELW1 - rules read the items of one payment document by key
  TYPES tt_return_item TYPE STANDARD TABLE OF ty_return_item WITH EMPTY KEY
                       WITH NON-UNIQUE SORTED KEY by_selw1 COMPONENTS selw1.

  "! NOC lot item (DFKKNRP: KEYN1 lot, POSNA item) found by its INFOF - confirmed 2026-11-06:
  "! INFOF holds the payment document (AUGBL) or the payment reference (exact content VERIFY-SE11)
  TYPES:
    BEGIN OF ty_noc_item,
      keyn1 TYPE c LENGTH 12,
      posna TYPE n LENGTH 6,
      infof TYPE ty_infof,
      "! NOC reason of the item (DFKKNRP-FLGRD, VERIFY-SE11)
      flgrd TYPE ty_lot_reason,
    END OF ty_noc_item.
  TYPES tt_noc_item TYPE STANDARD TABLE OF ty_noc_item WITH EMPTY KEY.

  "! Payment header (DPAYH) by payment document DOC1R
  TYPES:
    BEGIN OF ty_payment,
      doc1r  TYPE ty_docno,
      laufd  TYPE d,
      laufi  TYPE c LENGTH 6,
      status TYPE ty_status,
    END OF ty_payment.
  "! Fix 4: primary order stays newest run first; secondary key BY_DOC1R for the rule lookup
  TYPES tt_payment TYPE STANDARD TABLE OF ty_payment WITH EMPTY KEY
                   WITH NON-UNIQUE SORTED KEY by_doc1r COMPONENTS doc1r.

  "! ACH retrieval log (ZCD_ACH_RTRV_LOG) by clearing document
  TYPES:
    BEGIN OF ty_retrieval,
      augbl  TYPE ty_docno,
      status TYPE ty_status,
    END OF ty_retrieval.
  "! Fix 4: secondary key BY_AUGBL - attempts of one clearing document in read order
  TYPES tt_retrieval TYPE STANDARD TABLE OF ty_retrieval WITH EMPTY KEY
                     WITH NON-UNIQUE SORTED KEY by_augbl COMPONENTS augbl.

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
      amount   TYPE zif_ca_ops_types=>ty_amount,
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
  "! Fix 4: secondary key BY_DOCUMENT - lines of one FI document
  TYPES tt_fi_line TYPE STANDARD TABLE OF ty_fi_line WITH EMPTY KEY
                   WITH NON-UNIQUE SORTED KEY by_document COMPONENTS bukrs belnr gjahr.

  METHODS get_return_items
    IMPORTING
      it_docno        TYPE tt_docno
    RETURNING
      VALUE(rt_items) TYPE tt_return_item.

  "! NOC lot items whose INFOF is one of the given values (exact forms - the caller passes
  "! every form a payment document / reference can take); empty list = nothing read
  METHODS get_noc_items DEFAULT IGNORE
    IMPORTING
      it_infof        TYPE tt_infof
    RETURNING
      VALUE(rt_items) TYPE tt_noc_item.

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
  "! Sweep: secondary key BY_KEY - R21 reads the rows of one key per bank line
  TYPES tt_lookup_row TYPE STANDARD TABLE OF ty_lookup_row WITH EMPTY KEY
                      WITH NON-UNIQUE SORTED KEY by_key COMPONENTS lookup_key.

  "! Rows of the configured table for the keys (key field, status field). Table and field
  "! names are validated against the DDIC; an unknown name raises (rule fails closed).
  "! The field of the table is approved for the EBS lookup rule R21 (active ZCD_OPS_TABWL row of
  "! area EBS, purpose LOOKUP, table and field - field-level, a blank field approves nothing)
  METHODS is_lookup_field_approved DEFAULT IGNORE
    IMPORTING
      iv_table           TYPE clike
      iv_field           TYPE clike
    RETURNING
      VALUE(rv_approved) TYPE abap_bool.

  "! Rows of the configured lookup table: key and status field must be approved
  "! (is_lookup_field_approved, 812) and the table displayable (S_TABU_NAM 03, 813)
  METHODS get_lookup_rows
    IMPORTING
      is_lookup      TYPE zif_cd_ebs_types=>ty_lookup_cfg
      it_keys        TYPE tt_lookup_key
    RETURNING
      VALUE(rt_rows) TYPE tt_lookup_row
    RAISING
      zcx_ca_ops_error.

  METHODS get_retrievals
    IMPORTING
      it_docno             TYPE tt_docno
    RETURNING
      VALUE(rt_retrievals) TYPE tt_retrieval
    RAISING
      zcx_ca_ops_error.

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

  "! Fix 6: one bank G/L balance request per closing statement (R18)
  TYPES:
    BEGIN OF ty_gl_request,
      request_no TYPE i,
      bukrs      TYPE ty_fi_key-bukrs,
      gl_account TYPE ty_fi_line-hkont,
      currency   TYPE zif_ca_ops_types=>ty_currency,
      stmt_date  TYPE d,
    END OF ty_gl_request.
  TYPES tt_gl_request TYPE SORTED TABLE OF ty_gl_request WITH UNIQUE KEY request_no.
  TYPES:
    BEGIN OF ty_gl_balance,
      request_no TYPE i,
      balance    TYPE zif_ca_ops_types=>ty_amount,
    END OF ty_gl_balance.
  TYPES tt_gl_balance TYPE HASHED TABLE OF ty_gl_balance WITH UNIQUE KEY request_no.

  "! Bank G/L balances in transaction currency up to and including each request's date,
  "! one aggregate statement for all requests. A request without postings has no row
  "! (balance 0, as SUM over no rows gave before)
  METHODS get_gl_balances
    IMPORTING
      it_requests        TYPE tt_gl_request
    RETURNING
      VALUE(rt_balances) TYPE tt_gl_balance.

ENDINTERFACE.
