*&---------------------------------------------------------------------*
*& Artifact: zif_cd_fmon_lot_reader.intf.abap
*& Purpose:
*& Returns / NOC lot completeness reader: counts processed and open items
*& of the lots that belong to registered inbound files (ZCD_FMON_LOTCFG).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - returns/NOC lot completeness reader</p>
INTERFACE zif_cd_fmon_lot_reader
  PUBLIC.

  "! One status per file; found = abap_false when no lot item is linked to it
  METHODS read
    IMPORTING
      is_cfg           TYPE zif_cd_fmon_types=>ty_lotcfg
      it_files         TYPE zif_cd_fmon_types=>tt_file
      iv_max_rows      TYPE i DEFAULT 0
    RETURNING
      VALUE(rt_status) TYPE zif_cd_fmon_types=>tt_lot_status
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
