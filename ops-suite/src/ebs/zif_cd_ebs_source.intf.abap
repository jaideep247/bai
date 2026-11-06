*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ebs_source.intf.abap
*& Purpose:
*& ZCL_CD_EBS_SRC_FEB: imported statements (FEBKO/FEBEP), packaged by statement.
*& ZCL_CD_EBS_SRC_FILE: one parsed bank file (pre-import), one package.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - statement source</p>
"! ZCL_CD_EBS_SRC_FEB: imported statements (FEBKO/FEBEP), packaged by statement.
"! ZCL_CD_EBS_SRC_FILE: one parsed bank file (pre-import), one package.
INTERFACE zif_cd_ebs_source
  PUBLIC.

  "! Next unit of work; an initial package (no statements) ends the run
  METHODS next_package
    RETURNING
      VALUE(rs_package) TYPE zif_cd_ebs_types=>ty_package
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
