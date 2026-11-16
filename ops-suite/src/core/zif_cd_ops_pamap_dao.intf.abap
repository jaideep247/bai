*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_pamap_dao.intf.abap
*& Purpose:
*& SQL seam of the typed product mapping tables (ZCD_OPS_MAPRSN, _MAPPMC,
*& _MAPBTM, _MAPBTR - one per purpose, typed key and result columns, a
*& mapping version per row): the entries of one version in the shape of a
*& posting area entry (KEY01.., FUN01..), so the reader and every consumer
*& stay unchanged; and the insert of the migration from a posting area.
*& Implementation ZCL_CD_OPS_PAMAP_DAO; in-memory double
*& ZCL_CD_OPS_POSTAREA_MEM.
*& Modification log:
*& 2026-11-15 | Initial version (typed product mapping tables, product review 2026-11-15).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - typed mapping tables: repository</p>
INTERFACE zif_cd_ops_pamap_dao
  PUBLIC.

  "! Every entry of the mapping version of the purpose, ordered by the key columns (the columns
  "! in layout order as KEY01.. / FUN01..; values condensed). Empty for an unknown purpose.
  METHODS read_entries
    IMPORTING
      iv_purpose        TYPE zif_cd_ops_postarea_types=>ty_purpose
      iv_version        TYPE zif_cd_ops_postarea_types=>ty_version
    RETURNING
      VALUE(rt_entries) TYPE zif_cd_ops_postarea_types=>tt_entry.

  "! Inserts the entries as rows of the version (change stamps set; no commit - the caller's
  "! store commits). Returns the rows written (typed table rows, for the customizing request).
  METHODS insert_entries
    IMPORTING
      iv_purpose     TYPE zif_cd_ops_postarea_types=>ty_purpose
      iv_version     TYPE zif_cd_ops_postarea_types=>ty_version
      it_entries     TYPE zif_cd_ops_postarea_types=>tt_entry
    RETURNING
      VALUE(rr_rows) TYPE REF TO data
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
