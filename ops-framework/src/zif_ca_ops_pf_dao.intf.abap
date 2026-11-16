*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_pf_dao.intf.abap
*& Purpose:
*& Data access of the payment file lifecycle: the configuration
*& (ZCA_OPS_PFTYP / PFSTG / PFMAP / PFADP) and the register (ZCA_OPS_PFFILE
*& / PFPAY / PFEVT / PFMST / PFSRC / PFDAY). The register is written only
*& through this interface (ingestion); evidence rows are inserted
*& accepting duplicate keys, so an observation read twice is stored once.
*& Amount totals per file and currency are aggregated in the database.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - payment file data access</p>
INTERFACE zif_ca_ops_pf_dao
  PUBLIC.

  "! Active file types of the area (blank file type = all)
  METHODS get_file_types
    IMPORTING
      iv_area         TYPE zif_ca_ops_types=>ty_area
      iv_file_type    TYPE zif_ca_ops_pf_types=>ty_file_type OPTIONAL
    RETURNING
      VALUE(rt_types) TYPE zif_ca_ops_pf_types=>tt_type_cfg.

  "! Active milestones of a file type
  METHODS get_stages
    IMPORTING
      iv_area          TYPE zif_ca_ops_types=>ty_area
      iv_file_type     TYPE zif_ca_ops_pf_types=>ty_file_type
    RETURNING
      VALUE(rt_stages) TYPE zif_ca_ops_pf_types=>tt_stage.

  "! Active status mapping rows of the area
  METHODS get_maps
    IMPORTING
      iv_area        TYPE zif_ca_ops_types=>ty_area
    RETURNING
      VALUE(rt_maps) TYPE zif_ca_ops_pf_types=>tt_map.

  "! Active adapters of a file type
  METHODS get_adapters
    IMPORTING
      iv_area            TYPE zif_ca_ops_types=>ty_area
      iv_file_type       TYPE zif_ca_ops_pf_types=>ty_file_type
    RETURNING
      VALUE(rt_adapters) TYPE zif_ca_ops_pf_types=>tt_adapter.

  "! State of a source (initial = never read)
  METHODS get_source
    IMPORTING
      iv_area          TYPE zif_ca_ops_types=>ty_area
      iv_source_id     TYPE zif_ca_ops_pf_types=>ty_source_id
    RETURNING
      VALUE(rs_source) TYPE zif_ca_ops_pf_types=>ty_source.

  "! States of the sources of the area
  METHODS get_sources
    IMPORTING
      iv_area           TYPE zif_ca_ops_types=>ty_area
    RETURNING
      VALUE(rt_sources) TYPE zif_ca_ops_pf_types=>tt_source.

  METHODS save_source
    IMPORTING
      is_source TYPE zif_ca_ops_pf_types=>ty_source
    RAISING
      zcx_ca_ops_error.

  "! Files of a file type by native key
  METHODS files_by_key
    IMPORTING
      iv_area         TYPE zif_ca_ops_types=>ty_area
      iv_file_type    TYPE zif_ca_ops_pf_types=>ty_file_type
      it_native_keys  TYPE zif_ca_ops_pf_types=>tt_native_key
    RETURNING
      VALUE(rt_files) TYPE zif_ca_ops_pf_types=>tt_file.

  "! Files of a file type (blank = all) with a business date from iv_from on, at most iv_max
  METHODS files_since
    IMPORTING
      iv_area         TYPE zif_ca_ops_types=>ty_area
      iv_file_type    TYPE zif_ca_ops_pf_types=>ty_file_type OPTIONAL
      iv_from         TYPE d
      iv_max          TYPE i
    RETURNING
      VALUE(rt_files) TYPE zif_ca_ops_pf_types=>tt_file.

  "! Insert or update files (key area and file ID)
  METHODS save_files
    IMPORTING
      it_files TYPE zif_ca_ops_pf_types=>tt_file
    RAISING
      zcx_ca_ops_error.

  "! Replace the payments of the files named
  METHODS save_payments
    IMPORTING
      iv_area     TYPE zif_ca_ops_types=>ty_area
      it_file_ids TYPE zif_ca_ops_pf_types=>tt_file_id
      it_payments TYPE zif_ca_ops_pf_types=>tt_payment
    RAISING
      zcx_ca_ops_error.

  "! Payments of the files
  METHODS get_payments
    IMPORTING
      iv_area            TYPE zif_ca_ops_types=>ty_area
      it_file_ids        TYPE zif_ca_ops_pf_types=>tt_file_id
    RETURNING
      VALUE(rt_payments) TYPE zif_ca_ops_pf_types=>tt_payment.

  "! Payments of the area with one of the keys in other files than the ones named (reissue, duplicate exposure)
  METHODS payments_elsewhere
    IMPORTING
      iv_area            TYPE zif_ca_ops_types=>ty_area
      it_payments        TYPE zif_ca_ops_pf_types=>tt_payment
    RETURNING
      VALUE(rt_payments) TYPE zif_ca_ops_pf_types=>tt_payment.

  "! Insert evidence rows accepting duplicate keys
  "! @parameter rv_inserted | Rows that were new
  METHODS insert_events
    IMPORTING
      it_events          TYPE zif_ca_ops_pf_types=>tt_event
    RETURNING
      VALUE(rv_inserted) TYPE i.

  "! Evidence rows of the files
  METHODS get_events
    IMPORTING
      iv_area          TYPE zif_ca_ops_types=>ty_area
      it_file_ids      TYPE zif_ca_ops_pf_types=>tt_file_id
    RETURNING
      VALUE(rt_events) TYPE zif_ca_ops_pf_types=>tt_event.

  "! Earlier evidence rows of a source with the same source event IDs (repeated references)
  METHODS events_by_source_id
    IMPORTING
      iv_area          TYPE zif_ca_ops_types=>ty_area
      iv_source_id     TYPE zif_ca_ops_pf_types=>ty_source_id
      it_ids           TYPE zif_ca_ops_pf_types=>tt_native_key
    RETURNING
      VALUE(rt_events) TYPE zif_ca_ops_pf_types=>tt_event.

  "! Replace the milestone rows of the files named
  METHODS save_milestones
    IMPORTING
      iv_area       TYPE zif_ca_ops_types=>ty_area
      it_file_ids   TYPE zif_ca_ops_pf_types=>tt_file_id
      it_milestones TYPE zif_ca_ops_pf_types=>tt_ms
    RAISING
      zcx_ca_ops_error.

  METHODS get_milestones
    IMPORTING
      iv_area              TYPE zif_ca_ops_types=>ty_area
      it_file_ids          TYPE zif_ca_ops_pf_types=>tt_file_id
    RETURNING
      VALUE(rt_milestones) TYPE zif_ca_ops_pf_types=>tt_ms.

  "! Amounts per file and currency (aggregated in the database; duplicate exposure = payments carried by another
  "! file of the area)
  METHODS get_totals
    IMPORTING
      iv_area          TYPE zif_ca_ops_types=>ty_area
      it_file_ids      TYPE zif_ca_ops_pf_types=>tt_file_id
    RETURNING
      VALUE(rt_totals) TYPE zif_ca_ops_pf_types=>tt_total.

  METHODS save_days
    IMPORTING
      it_days TYPE zif_ca_ops_pf_types=>tt_day
    RAISING
      zcx_ca_ops_error.

  "! Day rows of the area (blank file type = all) from iv_from on
  METHODS get_days
    IMPORTING
      iv_area        TYPE zif_ca_ops_types=>ty_area
      iv_file_type   TYPE zif_ca_ops_pf_types=>ty_file_type OPTIONAL
      iv_from        TYPE d
    RETURNING
      VALUE(rt_days) TYPE zif_ca_ops_pf_types=>tt_day.

  "! Remove the files of a file type with a business date before iv_before (with payments, evidence, milestones)
  "! and their day rows
  METHODS delete_before
    IMPORTING
      iv_area         TYPE zif_ca_ops_types=>ty_area
      iv_file_type    TYPE zif_ca_ops_pf_types=>ty_file_type
      iv_before       TYPE d
    RETURNING
      VALUE(rv_count) TYPE i.

  "! One unit of work per file type (ingestion)
  METHODS commit.

ENDINTERFACE.
