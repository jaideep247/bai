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
*& 2026-11-15 | FUN08 no longer read (TFK033D has FUN01..FUN06, reference system S/4HANA 2025).
*& 2026-11-15 | FUN07 no longer read (VERIFY V161 closed): a layout with a 7th result or fields longer
*&            | than CHAR 12 is not read from a posting area - typed table (source T, ZCL_CD_OPS_PAMAP_DAO).
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
    " TFK033D on the reference system S/4HANA 2025 (ddic/a4h): key APPLK, BUBER, KTOPL, KEY01..KEY08 (KEYNN_KK,
    " CHAR 12), results FUN01..FUN06 (FUNNN_KK, CHAR 12) - nothing else exists. A purpose whose layout needs more
    " (ZBTM, ZBTR) is read from its typed table; the reader never asks a posting area for it (source T).
    " CHAR values into strings - trailing blanks dropped, nothing truncated
    SELECT key01, key02, key03, key04, key05, key06, key07, key08,
           fun01, fun02, fun03, fun04, fun05, fun06
      FROM tfk033d
      WHERE applk = @iv_applk
        AND buber = @iv_area
        AND ktopl = @iv_ktopl
      ORDER BY key01, key02, key03, key04, key05, key06, key07, key08
      INTO CORRESPONDING FIELDS OF TABLE @rt_entries.
  ENDMETHOD.

ENDCLASS.
