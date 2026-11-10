*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_lock.intf.abap
*& Purpose:
*& One run per payment engine area + variant at a time. The lock survives COMMIT WORK
*& (engines commit per package) and is released by the engine at the end.
*& Modification log:
*& 2026-11-06 | Initial version (run lock).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - run lock per area and variant</p>
INTERFACE zif_ca_ops_lock
  PUBLIC.

  "! Take the run lock. Not acquired: ev_holder names the user holding it.
  "! @raising zcx_ca_ops_error | lock service not available
  METHODS acquire
    IMPORTING
      iv_area          TYPE zif_ca_ops_types=>ty_area
      iv_variant         TYPE zif_ca_ops_types=>ty_variant
    EXPORTING
      ev_holder          TYPE syuname
    RETURNING
      VALUE(rv_acquired) TYPE abap_bool
    RAISING
      zcx_ca_ops_error.

  METHODS release
    IMPORTING
      iv_area  TYPE zif_ca_ops_types=>ty_area
      iv_variant TYPE zif_ca_ops_types=>ty_variant.

ENDINTERFACE.
