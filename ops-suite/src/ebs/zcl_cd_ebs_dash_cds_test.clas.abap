*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_dash_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the EBS validation dashboard
*& (cl_cds_test_environment over ZR_CD_EBSSTMT, ZR_CD_EBSFIND, ZR_CD_EBSRUN,
*& ZR_CD_EBSKPI, ZR_CD_EBSASOF and ZR_CD_EBSRETNOC). No production logic and
*& no methods: the dashboard is CDS only; the tests live in the test include.
*& Modification log:
*& 2026-11-06 | Initial version (EBS validation dashboard).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation dashboard - CDS unit test holder</p>
"! The EBS validation dashboard (docs/Dashboard_EBS_Validation.md) is read-only CDS; this
"! class only carries its ABAP Unit tests (test include). It is never instantiated.
CLASS zcl_cd_ebs_dash_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_cd_ebs_dash_cds_test IMPLEMENTATION.

ENDCLASS.
