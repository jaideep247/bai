*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_clock.intf.abap
*& Purpose:
*& Operations suite - clock (injectable for tests)
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - clock (injectable for tests)</p>
INTERFACE zif_cd_ops_clock
  PUBLIC.

  METHODS now
    RETURNING
      VALUE(rv_timestamp) TYPE timestampl.

  METHODS today
    RETURNING
      VALUE(rv_date) TYPE d.

  METHODS time
    RETURNING
      VALUE(rv_time) TYPE t.

ENDINTERFACE.
