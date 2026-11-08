*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_postarea_dao.clas.abap
*& Purpose:
*& SQL of the posting area reader: one set-based read of the stored FQC0
*& entries of a posting area (TFK033D, by application area, posting area
*& and chart of accounts). Read-only - FQC0 is the only maintenance; the
*& entries arrive by customizing transport. Chosen over the account
*& determination API (FKK_ACCOUNT_DETERMINE): the suite needs every entry
*& of an area (sets of codes, roles and payment methods, the configuration
*& check), not one determination per key, and the API's message handling
*& per missing key is not wanted in a batch read (Implementation_Order.md).
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas ZRSN, ZPMC, ZBTM, ZBTR).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - customer posting areas: SQL (TFK033D)</p>
CLASS zcl_cd_ops_postarea_dao DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_postarea_dao.

ENDCLASS.



CLASS zcl_cd_ops_postarea_dao IMPLEMENTATION.

  METHOD zif_cd_ops_postarea_dao~read_entries.
    " VERIFY-DDIC: TFK033D fields APPLK, BUBER, KTOPL, KEY01..KEY08, FUN01..FUN08 (SE11 in DV1);
    " CHAR values into strings - trailing blanks dropped, nothing truncated
    SELECT key01, key02, key03, key04, key05, key06, key07, key08,
           fun01, fun02, fun03, fun04, fun05, fun06, fun07, fun08
      FROM tfk033d
      WHERE applk = @iv_applk
        AND buber = @iv_area
        AND ktopl = @iv_ktopl
      ORDER BY key01, key02, key03, key04, key05, key06, key07, key08
      INTO CORRESPONDING FIELDS OF TABLE @rt_entries.
  ENDMETHOD.

ENDCLASS.
