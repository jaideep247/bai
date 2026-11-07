*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_recon_dao.intf.abap
*& Purpose:
*& Reads of the three-way reconciliation check A_RECON_3WAY: the active
*& configuration (ZCD_HCK_RCSET, ZCD_HCK_RCBTC) and the legs, every one
*& aggregated on the database (GROUP BY, SUM, COUNT): bank lines of the
*& payment engine accounts (ZI_CD_HckRcBankLine over FEBEP / FEBKO), G/L
*& lines of the clearing accounts (ACDOCA), payment engine G/L transfer
*& totals (DFKKSUMC), payment documents (DPAYH), Stripe deposit documents
*& and descriptor groups, unmatched ACH assignment groups. No line-level
*& copy, no SELECT per document. Read-only: the interface has no write
*& method.
*& Modification log:
*& 2026-11-07 | Initial version (three-way reconciliation check A_RECON_3WAY).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - three-way reconciliation reads</p>
"! Implementation ZCL_CD_HCK_RECON_DAO, factory ZCL_CD_HCK_FACTORY=>GET_RECON_DAO.
"! Empty key / account lists read nothing (never "all").
INTERFACE zif_cd_hck_recon_dao
  PUBLIC.

  "! Active reconciliation sets (ZCD_HCK_RCSET), ordered by set id
  METHODS get_sets
    RETURNING
      VALUE(rt_sets) TYPE zif_cd_hck_recon_types=>tt_set.

  "! Active bank code roles of the sets (ZCD_HCK_RCBTC)
  METHODS get_btc_roles
    RETURNING
      VALUE(rt_roles) TYPE zif_cd_hck_recon_types=>tt_btc_role.

  "! Bank lines of the accounts with a booking day in iv_from .. iv_to, grouped per account,
  "! currency, day, code and debit / credit (SUM of the amount, COUNT of the lines)
  METHODS get_bank_days
    IMPORTING
      it_accounts    TYPE zif_cd_hck_recon_types=>tt_account
      iv_from        TYPE d
      iv_to          TYPE d
    RETURNING
      VALUE(rt_days) TYPE zif_cd_hck_recon_types=>tt_bank_day.

  "! Last booking day of the accounts' statement lines in iv_from .. iv_to (statement loaded up
  "! to; no line in the range = no row)
  METHODS get_bank_last_days
    IMPORTING
      it_accounts    TYPE zif_cd_hck_recon_types=>tt_account
      iv_from        TYPE d
      iv_to          TYPE d
    RETURNING
      VALUE(rt_last) TYPE zif_cd_hck_recon_types=>tt_bank_last.

  "! Bank lines of the codes without a returns lot (no DFKKRP row with SELW1 = FEBEP-CHECT),
  "! grouped as get_bank_days (empty code list = nothing read)
  METHODS get_bank_days_no_lot
    IMPORTING
      it_accounts    TYPE zif_cd_hck_recon_types=>tt_account
      it_btcs        TYPE zif_cd_hck_recon_types=>tt_btc
      iv_from        TYPE d
      iv_to          TYPE d
    RETURNING
      VALUE(rt_days) TYPE zif_cd_hck_recon_types=>tt_bank_day.

  "! G/L lines of the clearing accounts (ledger, company code, account, transaction currency)
  "! with a posting day in iv_from .. iv_to, grouped per day and reference procedure (signed SUM)
  METHODS get_gl_days
    IMPORTING
      it_keys        TYPE zif_cd_hck_recon_types=>tt_gl_key
      iv_ledger      TYPE zif_cd_hck_recon_types=>ty_ledger
      iv_from        TYPE d
      iv_to          TYPE d
    RETURNING
      VALUE(rt_days) TYPE zif_cd_hck_recon_types=>tt_gl_day.

  "! Payment engine G/L transfer totals (DFKKSUMC) of the clearing accounts per posting day
  METHODS get_fica_days
    IMPORTING
      it_keys        TYPE zif_cd_hck_recon_types=>tt_gl_key
      iv_from        TYPE d
      iv_to          TYPE d
    RETURNING
      VALUE(rt_days) TYPE zif_cd_hck_recon_types=>tt_fica_day.

  "! Payment documents of payment runs (DPAYH: DOC1R filled, no proposal run) of the house bank
  "! accounts per currency and run date
  METHODS get_payment_days
    IMPORTING
      it_banks       TYPE zif_cd_hck_recon_types=>tt_bank_key
      iv_from        TYPE d
      iv_to          TYPE d
    RETURNING
      VALUE(rt_days) TYPE zif_cd_hck_recon_types=>tt_pay_day.

  "! Bank lines of the deposit codes grouped per posting document (FEBEP-BELNR / GJAHR, blank =
  "! not posted), currency, day and debit / credit
  METHODS get_deposits
    IMPORTING
      it_accounts        TYPE zif_cd_hck_recon_types=>tt_account
      it_btcs            TYPE zif_cd_hck_recon_types=>tt_btc
      iv_from            TYPE d
      iv_to              TYPE d
    RETURNING
      VALUE(rt_deposits) TYPE zif_cd_hck_recon_types=>tt_deposit.

  "! Clearing-account lines of the documents per assignment and debit / credit (signed SUM)
  METHODS get_doc_assignments
    IMPORTING
      it_docs           TYPE zif_cd_hck_recon_types=>tt_doc_key
      iv_hkont          TYPE zif_cd_hck_recon_types=>ty_hkont
      iv_ledger         TYPE zif_cd_hck_recon_types=>ty_ledger
    RETURNING
      VALUE(rt_assigns) TYPE zif_cd_hck_recon_types=>tt_doc_assign.

  "! Clearing-account lines of the assignment groups (posting day iv_from .. iv_to) per
  "! assignment and debit / credit (signed SUM)
  METHODS get_assignment_sums
    IMPORTING
      is_key         TYPE zif_cd_hck_recon_types=>ty_gl_key
      it_zuonr       TYPE zif_cd_hck_recon_types=>tt_zuonr
      iv_ledger      TYPE zif_cd_hck_recon_types=>ty_ledger
      iv_from        TYPE d
      iv_to          TYPE d
    RETURNING
      VALUE(rt_sums) TYPE zif_cd_hck_recon_types=>tt_assign_sum.

  "! Assignment groups of the clearing account (posting day iv_from .. iv_to) whose lines do not
  "! net to zero, oldest first; at most iv_max_rows (reaching it = capped)
  METHODS get_open_assignments
    IMPORTING
      is_key         TYPE zif_cd_hck_recon_types=>ty_gl_key
      iv_ledger      TYPE zif_cd_hck_recon_types=>ty_ledger
      iv_from        TYPE d
      iv_to          TYPE d
      iv_max_rows    TYPE i
    RETURNING
      VALUE(rt_open) TYPE zif_cd_hck_recon_types=>tt_open_assign.

ENDINTERFACE.
