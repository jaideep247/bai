*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ebs_feb_dao.intf.abap
*& Purpose:
*& Raw reads only; conversion to the format-neutral model happens in
*& ZCL_CD_EBS_SRC_FEB so the mapping is unit-testable without a database.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - imported bank statements (FEBKO/FEBEP)</p>
"! Raw reads only; conversion to the format-neutral model happens in
"! ZCL_CD_EBS_SRC_FEB so the mapping is unit-testable without a database.
INTERFACE zif_cd_ebs_feb_dao
  PUBLIC.

  TYPES ty_kukey TYPE zif_cd_ebs_types=>ty_kukey.
  TYPES tt_kukey TYPE STANDARD TABLE OF ty_kukey WITH EMPTY KEY.
  TYPES tt_r_bukrs TYPE RANGE OF zif_cd_ebs_types=>ty_statement-bukrs.
  TYPES tt_r_hbkid TYPE RANGE OF zif_cd_ebs_types=>ty_statement-hbkid.
  TYPES tt_r_kukey TYPE RANGE OF ty_kukey.

  TYPES:
    BEGIN OF ty_selection,
      bukrs     TYPE tt_r_bukrs,
      hbkid     TYPE tt_r_hbkid,
      kukey     TYPE tt_r_kukey,
      date_from TYPE d,
      date_to   TYPE d,
    END OF ty_selection.

  "! FEBKO header (fields used by the suite)
  TYPES:
    BEGIN OF ty_header,
      kukey TYPE ty_kukey,
      bukrs TYPE c LENGTH 4,
      hbkid TYPE c LENGTH 5,
      hktid TYPE c LENGTH 5,
      aznum TYPE c LENGTH 5,
      azdat TYPE d,
      waers TYPE c LENGTH 5,
      ssbtr TYPE zif_cd_ops_types=>ty_amount,
      ssvoz TYPE c LENGTH 1,
      esbtr TYPE zif_cd_ops_types=>ty_amount,
      esvoz TYPE c LENGTH 1,
      anzes TYPE i,
      efart TYPE c LENGTH 1,
    END OF ty_header.
  TYPES tt_header TYPE STANDARD TABLE OF ty_header WITH EMPTY KEY.

  "! FEBEP item (fields used by the suite)
  TYPES:
    BEGIN OF ty_item,
      kukey TYPE ty_kukey,
      esnum TYPE zif_cd_ebs_types=>ty_esnum,
      vorgc TYPE c LENGTH 3,
      vgext TYPE c LENGTH 27,
      vgint TYPE c LENGTH 4,
      epvoz TYPE c LENGTH 1,
      kwbtr TYPE zif_cd_ops_types=>ty_amount,
      kwaer TYPE c LENGTH 5,
      budat TYPE d,
      valut TYPE d,
      chect TYPE c LENGTH 13,
      xblnr TYPE c LENGTH 16,
      belnr TYPE c LENGTH 10,
      gjahr TYPE n LENGTH 4,
    END OF ty_item.
  TYPES tt_item TYPE STANDARD TABLE OF ty_item WITH EMPTY KEY.

  "! Statement keys in scope, ordered by account and statement date/number
  METHODS get_headers
    IMPORTING
      is_selection      TYPE ty_selection
    RETURNING
      VALUE(rt_headers) TYPE tt_header.

  METHODS get_items
    IMPORTING
      it_kukey        TYPE tt_kukey
    RETURNING
      VALUE(rt_items) TYPE tt_item.

  "! Latest statement of the same house bank account dated before iv_before
  "! (or same date with a lower statement number)
  METHODS get_prior_header
    IMPORTING
      iv_bukrs         TYPE ty_header-bukrs
      iv_hbkid         TYPE ty_header-hbkid
      iv_hktid         TYPE ty_header-hktid
      iv_before        TYPE d
      iv_aznum         TYPE ty_header-aznum OPTIONAL
    RETURNING
      VALUE(rs_header) TYPE ty_header.

  "! Already imported statement with the same account, number and date
  METHODS statement_exists
    IMPORTING
      iv_bukrs         TYPE ty_header-bukrs
      iv_hbkid         TYPE ty_header-hbkid
      iv_hktid         TYPE ty_header-hktid
      iv_aznum         TYPE ty_header-aznum
      iv_azdat         TYPE d
    RETURNING
      VALUE(rv_exists) TYPE abap_bool.

ENDINTERFACE.
