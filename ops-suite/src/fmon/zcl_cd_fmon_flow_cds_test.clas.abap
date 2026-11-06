*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_flow_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the file monitoring dashboard
*& (cl_cds_test_environment over ZR_CD_FMONFLOW, ZR_CD_FMONASOF,
*& ZR_CD_FMONFLOWKPI and ZR_CD_FMONFLOWFAIL). No production logic and
*& no methods: the dashboard is CDS only; the tests live in the test include.
*& Modification log:
*& 2026-11-06 | Initial version (FMON file monitoring dashboard).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring dashboard - CDS unit test holder</p>
"! The file monitoring dashboard (docs/Dashboard_File_Monitoring.md) is read-only CDS; this
"! class only carries its ABAP Unit tests (test include). It is never instantiated.
CLASS zcl_cd_fmon_flow_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_cd_fmon_flow_cds_test IMPLEMENTATION.

ENDCLASS.
