*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ops_cfg_auth.intf.abap
*& Purpose:
*& Authorisation seam of the configuration apps (object ZCD_OPS, design 1).
*& Temporary: replaced by ZIF_CD_OPS_AUTH / ZCL_CD_OPS_AUTH of the core
*& build at merge.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - config apps: authorisation seam</p>
INTERFACE zif_cd_ops_cfg_auth
  PUBLIC.

  "! ZCD_OPS with ACTVT and ZCD_MODULE; BUKRS not restricted (module-wide)
  METHODS is_authorized
    IMPORTING
      iv_module         TYPE zif_cd_ops_cfg_types=>ty_module
      iv_actvt          TYPE zif_cd_ops_cfg_types=>ty_actvt
    RETURNING
      VALUE(rv_allowed) TYPE abap_bool.

ENDINTERFACE.
