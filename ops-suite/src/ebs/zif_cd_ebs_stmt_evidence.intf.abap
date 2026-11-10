*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ebs_stmt_evidence.intf.abap
*& Purpose:
*& Statement evidence of the imported bank statements of a bank (read-only):
*& per bank key and statement date the payment engine accounts expected
*& (ZCD_EBS_ACCT), the accounts with an imported statement (FEBKO), the
*& in-scope entries (FEBEP, payment engine account scope of EBS) and the
*& entries expected to post that are not posted. Shared read of the EBS
*& pipeline for other payment engine areas (file monitoring: FEB adapter).
*& Dependency direction: FMON -> EBS (this interface); EBS never uses FMON.
*& Modification log:
*& 2026-11-07 | Initial version (BAI processing deadline, statement evidence for FMON).
*& 2026-11-07 | BANK_KEY = bank identifier as in the statement (user decision 2026-11-07).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS - statement evidence per bank and statement date</p>
"! Implementation ZCL_CD_EBS_STMT_EVIDENCE (factory ZCL_CD_EBS_FACTORY=>GET_STMT_EVIDENCE).
INTERFACE zif_cd_ebs_stmt_evidence
  PUBLIC.

  TYPES tt_bank_key TYPE SORTED TABLE OF zif_cd_ebs_types=>ty_bank_key WITH UNIQUE KEY table_line.
  TYPES tt_date TYPE SORTED TABLE OF d WITH UNIQUE KEY table_line.

  TYPES:
    BEGIN OF ty_request,
      "! Bank keys of ZCD_EBS_ACCT (bank identifier as in the statement), condensed, upper case
      bank_keys  TYPE tt_bank_key,
      "! Statement dates (FEBKO-AZDAT) to report
      stmt_dates TYPE tt_date,
      "! Statements read at most; a read that reaches the cap is TRUNCATED (nothing proven)
      max_rows   TYPE i,
    END OF ty_request.

  "! Evidence of one bank and statement date (one row per requested bank key and date)
  TYPES:
    BEGIN OF ty_evidence,
      bank_key          TYPE zif_cd_ebs_types=>ty_bank_key,
      stmt_date         TYPE d,
      "! Active payment engine accounts of the bank (ZCD_EBS_ACCT house bank accounts)
      accounts_expected TYPE i,
      "! Accounts with at least one imported statement (FEBKO) of the date
      accounts_imported TYPE i,
      "! Imported statements of the date / of them outside the payment engine account scope
      statements        TYPE i,
      out_of_scope      TYPE i,
      "! Entries (FEBEP) of the in-scope statements / expected to post but not posted
      lines_total       TYPE i,
      lines_open        TYPE i,
      "! The posting state was read (EBS_FEB_POSTED_FIELDS not OFF)
      posting_known     TYPE abap_bool,
      "! The statement read reached MAX_ROWS: counts are not complete
      truncated         TYPE abap_bool,
    END OF ty_evidence.
  TYPES tt_evidence TYPE SORTED TABLE OF ty_evidence WITH UNIQUE KEY bank_key stmt_date.

  "! One FEBKO read and one FEBEP read for all requested banks and dates
  METHODS read
    IMPORTING
      is_request         TYPE ty_request
    RETURNING
      VALUE(rt_evidence) TYPE tt_evidence
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
