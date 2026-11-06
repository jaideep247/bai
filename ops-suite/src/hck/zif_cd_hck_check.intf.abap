*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_check.intf.abap
*& Purpose:
*& Contract of a health check plug-in. One class per check type; the
*& check row in ZCD_HCK_DEF names the class and carries its parameters.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - check plug-in contract</p>
"! A check measures (metrics) and reports itemised problems (findings).
"! It never evaluates thresholds of its metrics, never persists and never
"! alerts: the engine does that centrally from ZCD_HCK_THRESH.
INTERFACE zif_cd_hck_check
  PUBLIC.

  "! @parameter is_def        | Check definition (ZCD_HCK_DEF row)
  "! @parameter it_thresholds | Thresholds of this check (all company-code rows)
  "! @parameter is_context    | Report date, current time, run id, test mode
  "! @parameter rs_result     | Metrics, findings, optional RAG and step states
  "! @raising zcx_cd_ops_error | Configuration or read error; engine records PLUGIN_ERROR
  METHODS execute
    IMPORTING
      is_def           TYPE zif_cd_hck_types=>ty_check_def
      it_thresholds    TYPE zif_cd_hck_types=>tt_threshold
      is_context       TYPE zif_cd_hck_types=>ty_context
    RETURNING
      VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
