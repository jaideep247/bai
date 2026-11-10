*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cfg_auth.clas.abap
*& Purpose:
*& Authorisation check of the configuration apps on object ZCA_OPS (design
*& 1): ACTVT and ZCA_PARAR, company code not restricted (area-wide
*& customizing). Delegates to ZCL_CA_OPS_AUTH (core). The object is created
*& in SU21 by security (design 1).
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*& 2026-11-06 | Delegates to ZCL_CA_OPS_AUTH (core) - no own AUTHORITY-CHECK.
*& 2026-11-07 | Purpose: merge note removed.
*& 2026-11-10 | Purpose names the authorisation field ZCA_PARAR (SU20).
*& 2026-11-10 | Moved from ZCL_CD_OPS_CFG_AUTH to the reusable framework ZCA_OPS.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops framework - config apps: ZCA_OPS check</p>
CLASS zcl_ca_ops_cfg_auth DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_cfg_auth.

ENDCLASS.



CLASS zcl_ca_ops_cfg_auth IMPLEMENTATION.

  METHOD zif_ca_ops_cfg_auth~is_authorized.
    " One implementation of the ZCA_OPS check for the whole suite (merge of phases 1 and 2)
    rv_allowed = zcl_ca_ops_factory=>get_auth( )->is_allowed( iv_activity = CONV #( iv_actvt )
                                                              iv_area   = CONV #( iv_area ) ).
  ENDMETHOD.

ENDCLASS.
