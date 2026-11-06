*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_auth.clas.abap
*& Purpose:
*& Authorisation check of the configuration apps on object ZCD_OPS (design
*& 1): ACTVT and ZCD_MODULE, company code not restricted (module-wide
*& customizing). Temporary seam - replaced by ZCL_CD_OPS_AUTH of the core
*& build at merge. The object is created in SU21 by security (design 1).
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - config apps: ZCD_OPS check</p>
CLASS zcl_cd_ops_cfg_auth DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ops_cfg_auth.

ENDCLASS.



CLASS zcl_cd_ops_cfg_auth IMPLEMENTATION.

  METHOD zif_cd_ops_cfg_auth~is_authorized.
    AUTHORITY-CHECK OBJECT 'ZCD_OPS'
      ID 'ACTVT'      FIELD iv_actvt
      ID 'ZCD_MODULE' FIELD iv_module
      ID 'BUKRS'      DUMMY.
    rv_allowed = xsdbool( sy-subrc = 0 ).
  ENDMETHOD.

ENDCLASS.
