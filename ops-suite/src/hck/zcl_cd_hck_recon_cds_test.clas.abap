*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_recon_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the three-way reconciliation views
*& (cl_cds_test_environment over ZI_CD_HCKRCBANKLINE - bank leg with the
*& payment engine account from XBLNR - and ZI_CD_HCKRECON - stored results
*& split by group). No production logic and no methods; the tests live in
*& the test include.
*& Modification log:
*& 2026-11-07 | Initial version (three-way reconciliation check A_RECON_3WAY).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check reconciliation - CDS unit test holder</p>
"! The reconciliation CDS views are read-only; this class only carries their ABAP Unit tests
"! (test include). It is never instantiated.
CLASS zcl_cd_hck_recon_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_cd_hck_recon_cds_test IMPLEMENTATION.

ENDCLASS.
