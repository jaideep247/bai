*&---------------------------------------------------------------------*
*& Artifact: zif_cd_fmon_adapter.intf.abap
*& Purpose:
*& Legacy source adapter: reads one configured custom table (ZCD_FMON_SRC)
*& and translates its rows into file status records via ZCD_FMON_SRCMAP.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - legacy source adapter</p>
"! Default implementation ZCL_CD_FMON_ADAPTER_GENERIC (adapter class blank).
"! A specific adapter is configured by class name in ZCD_FMON_SRC-ADAPTER_CLASS.
INTERFACE zif_cd_fmon_adapter
  PUBLIC.

  METHODS read
    IMPORTING
      is_request        TYPE zif_cd_fmon_types=>ty_read_request
    RETURNING
      VALUE(rt_records) TYPE zif_cd_fmon_types=>tt_src_record
    RAISING
      zcx_ca_ops_error.

ENDINTERFACE.
