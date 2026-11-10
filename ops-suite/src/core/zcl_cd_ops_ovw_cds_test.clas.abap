*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_ovw_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the production-support overview page
*& (cl_cds_test_environment over ZR_CD_OPSFRESHNESS, ZR_CD_OPSCRITEXC and the
*& control center views ZR_CD_OPSCTLDAY, ZI_CD_PAYLIFERUN, ZR_CD_PAYLIFECYCLE,
*& ZI_CD_OPSVARBANK, ZR_CD_OPSVARIANCE). No
*& production logic and no methods: the overview is CDS only; the tests live
*& in the test include.
*& Modification log:
*& 2026-11-06 | Initial version (production-support overview page).
*& 2026-11-10 | Also the tests of the control center cards (daily controls, payment lifecycle, variances).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Production support overview - CDS unit test holder</p>
"! The overview page (docs/Dashboard_Production_Support.md) is read-only CDS; this class only
"! carries its ABAP Unit tests (test include). It is never instantiated.
CLASS zcl_cd_ops_ovw_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_cd_ops_ovw_cds_test IMPLEMENTATION.

ENDCLASS.
