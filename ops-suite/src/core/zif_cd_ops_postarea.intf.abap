*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_postarea.intf.abap
*& Purpose:
*& Reader of the FI-CA customer posting areas of the suite (FQC0 entries):
*& all entries of a posting area, read once per run and cached, and the
*& entry that applies to a key with the FQC0 rule (an exact value beats the
*& generic value '*'; key fields compared from KEY01 on). Implementation
*& ZCL_CD_OPS_POSTAREA, factory ZCL_CD_OPS_POSTAREA_FACTORY=>GET_READER.
*& Read-only.
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas ZRSN, ZPMC, ZBTM, ZBTR).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - customer posting area reader</p>
"! A posting area is named by its purpose (ZIF_CD_OPS_POSTAREA_TYPES=>GC_PURPOSE); the
"! posting area itself, the application area and the chart of accounts are parameters.
INTERFACE zif_cd_ops_postarea
  PUBLIC.

  "! Every entry of the posting area of the purpose, ordered by the key values; the first
  "! call of a purpose reads the database, later calls of the run return the cache
  METHODS entries
    IMPORTING
      iv_purpose        TYPE zif_cd_ops_postarea_types=>ty_purpose
    RETURNING
      VALUE(rt_entries) TYPE zif_cd_ops_postarea_types=>tt_entry.

  "! The entry that applies to the key values (FQC0): every key must be equal or '*'; among
  "! the candidates the one with an exact value in the first key where they differ wins
  "! (KEY01 first - an exact key beats '*', the most specific entry from the left wins).
  "! Initial when no entry applies.
  METHODS find
    IMPORTING
      iv_purpose      TYPE zif_cd_ops_postarea_types=>ty_purpose
      is_keys         TYPE zif_cd_ops_postarea_types=>ty_keys
    RETURNING
      VALUE(rs_entry) TYPE zif_cd_ops_postarea_types=>ty_entry.

  "! The posting area of the purpose as configured (parameter; for messages and findings)
  METHODS area
    IMPORTING
      iv_purpose     TYPE zif_cd_ops_postarea_types=>ty_purpose
    RETURNING
      VALUE(rv_area) TYPE zif_cd_ops_postarea_types=>ty_area.

ENDINTERFACE.
