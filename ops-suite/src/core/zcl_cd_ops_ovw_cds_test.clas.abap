*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_ovw_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the production-support overview page
*& (cl_cds_test_environment over ZR_CD_OPSFRESHNESS and ZR_CD_OPSCRITEXC). No
*& production logic and no methods: the overview is CDS only; the tests live
*& in the test include.
*& Modification log:
*& 2026-11-06 | Initial version (production-support overview page).
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
