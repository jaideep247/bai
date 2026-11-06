*&---------------------------------------------------------------------*
*& Artifact: zif_cd_fmon_check.intf.abap
*& Purpose:
*& Plug-in check contract. Implementations are configured in ZCD_FMON_CHK
*& by class name; they are pure (context in, findings out, no SQL).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - plug-in check</p>
INTERFACE zif_cd_fmon_check
  PUBLIC.

  "! @parameter is_ctx   | Files, events, configuration and lots of this run
  "! @parameter is_check | Configured check row (ID, severity, parameters)
  METHODS execute
    IMPORTING
      is_ctx             TYPE zif_cd_fmon_types=>ty_check_ctx
      is_check           TYPE zif_cd_fmon_types=>ty_chk
    RETURNING
      VALUE(rt_findings) TYPE zif_cd_ops_types=>tt_finding
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
