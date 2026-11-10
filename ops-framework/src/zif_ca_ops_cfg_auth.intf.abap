*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_cfg_auth.intf.abap
*& Purpose:
*& Authorisation seam of the configuration apps (object ZCD_OPS, design 1);
*& the delivered implementation delegates to ZCL_CA_OPS_AUTH.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*& 2026-11-07 | Purpose describes the delegating adapter (merge note removed).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - config apps: authorisation seam</p>
INTERFACE zif_ca_ops_cfg_auth
  PUBLIC.

  "! ZCD_OPS with ACTVT and ZCA_PARAR; BUKRS not restricted (payment engine area-wide)
  METHODS is_authorized
    IMPORTING
      iv_area         TYPE zif_ca_ops_types=>ty_area
      iv_actvt          TYPE zif_ca_ops_cfg_types=>ty_actvt
    RETURNING
      VALUE(rv_allowed) TYPE abap_bool.

ENDINTERFACE.
