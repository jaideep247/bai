*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_trx_dash_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the transactions dashboard
*& (cl_cds_test_environment over ZR_CD_TRXFLOW, ZR_CD_TRXKPI,
*& ZR_CD_TRXPROBLEM and ZR_CD_TRXRETNOC). No production logic and no
*& methods: the dashboard is CDS only; the tests live in the test include.
*& Modification log:
*& 2026-11-06 | Initial version (transactions dashboard).
*& 2026-11-08 | Tests on the exceptions-only payment worklist (test include).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Transactions dashboard - CDS unit test holder</p>
"! The transactions dashboard (docs/Dashboard_Transactions.md) is read-only CDS; this class
"! only carries its ABAP Unit tests (test include). It is never instantiated.
CLASS zcl_cd_trx_dash_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_cd_trx_dash_cds_test IMPLEMENTATION.

ENDCLASS.
