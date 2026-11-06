*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_dash_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the health check dashboard
*& (cl_cds_test_environment over ZR_CD_HCKCHECK, ZR_CD_HCKCATEGORY,
*& ZR_CD_HCKKPI, ZR_CD_HCKASOF and ZR_CD_HCKMETRIC). No production logic and
*& no methods: the dashboard is CDS only; the tests live in the test include.
*& Modification log:
*& 2026-11-06 | Initial version (health check dashboard).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check dashboard - CDS unit test holder</p>
"! The health check dashboard (docs/Dashboard_Health_Check.md) is read-only CDS; this class
"! only carries its ABAP Unit tests (test include). It is never instantiated.
CLASS zcl_cd_hck_dash_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_cd_hck_dash_cds_test IMPLEMENTATION.

ENDCLASS.
