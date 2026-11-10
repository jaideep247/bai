*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_clock.intf.abap
*& Purpose:
*& Operations framework - clock (injectable for tests)
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-10 | Moved from ZIF_CD_OPS_CLOCK to the reusable framework ZCA_OPS.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - clock (injectable for tests)</p>
INTERFACE zif_ca_ops_clock
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
