*&---------------------------------------------------------------------*
*& Artifact: zif_cd_fmon_prism_dao.intf.abap
*& Purpose:
*& Repository of the PRISM status API: idempotent insert of one PRISM event
*& into ZCD_FMON_PRISM (the suite's own FMON store), the reads of the instant
*& unit and of the 5-minute safety net, and the processed marker. The caller
*& owns the LUW and commits through the core store.
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API, user decision 2026-11-06).
*& 2026-11-06 | read_event, read_unprocessed, mark_processed (instant bgPF processing).
*& 2026-11-07 | read_failures: FAILED milestones with a duplicate-name error code (DEFAULT IGNORE).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FMON PRISM status API - event repository</p>
INTERFACE zif_cd_fmon_prism_dao
  PUBLIC.

  "! Insert the event. An event ID already stored is not overwritten: the stored content
  "! is compared - same content = duplicate (idempotent retry), other content = conflict.
  "! @parameter rv_result | I inserted, D duplicate, C conflict (gc_store_result)
  "! @raising zcx_cd_ops_error | the event could neither be inserted nor read back
  METHODS insert_event
    IMPORTING
      is_row           TYPE zif_cd_fmon_prism_types=>ty_row
    RETURNING
      VALUE(rv_result) TYPE zif_cd_fmon_prism_types=>ty_store_result
    RAISING
      zcx_cd_ops_error.

  "! One stored event (initial when the ID is not stored)
  METHODS read_event
    IMPORTING
      iv_event_id   TYPE zif_cd_fmon_prism_types=>ty_event_id
    RETURNING
      VALUE(rs_row) TYPE zif_cd_fmon_prism_types=>ty_row.

  "! Events not yet applied by a unit, received in [iv_from, iv_to), oldest first, capped
  METHODS read_unprocessed
    IMPORTING
      iv_from        TYPE timestampl
      iv_to          TYPE timestampl
      iv_max_rows    TYPE i
    RETURNING
      VALUE(rt_rows) TYPE zif_cd_fmon_prism_types=>tt_row.

  "! FAILED milestones with one of the error codes, business date iv_since or later (index BDT);
  "! regenerated files: PRISM rejected a name it had already received. Empty list = no read
  METHODS read_failures DEFAULT IGNORE
    IMPORTING
      it_codes       TYPE zif_cd_fmon_prism_types=>tt_error_code
      iv_since       TYPE d
    RETURNING
      VALUE(rt_rows) TYPE zif_cd_fmon_prism_types=>tt_row.

  "! Set PROCESSED_AT of events still unprocessed (an event processed meanwhile keeps its time)
  "! @raising zcx_cd_ops_error | update failed
  METHODS mark_processed
    IMPORTING
      it_event_ids TYPE zif_cd_fmon_prism_types=>tt_event_id
      iv_at        TYPE timestampl
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
