*&---------------------------------------------------------------------*
*& Artifact: zif_ca_ops_cfg_auth.intf.abap
*& Purpose:
*& Authorisation seam of the configuration apps (object ZCA_OPS, design 1);
*& the delivered implementation delegates to ZCL_CA_OPS_AUTH.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*& 2026-11-07 | Purpose describes the delegating adapter (merge note removed).
*& 2026-11-10 | Moved from ZIF_CD_OPS_CFG_AUTH to the reusable framework ZCA_OPS.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops framework - config apps: authorisation seam</p>
INTERFACE zif_ca_ops_cfg_auth
  PUBLIC.

  "! ZCA_OPS with ACTVT and ZCA_PARAR; BUKRS not restricted (area-wide)
  METHODS is_authorized
    IMPORTING
      iv_area         TYPE zif_ca_ops_types=>ty_area
      iv_actvt          TYPE zif_ca_ops_cfg_types=>ty_actvt
    RETURNING
      VALUE(rv_allowed) TYPE abap_bool.

ENDINTERFACE.
