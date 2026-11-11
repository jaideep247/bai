*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_svc_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the service health score (ZI_CD_SVCOBJ,
*& ZR_CD_SVCHEALTH) and the process flow (ZR_CD_PAYFLOW) of the overview
*& page. No production logic and no methods: the cards are CDS only; the
*& tests live in the test include.
*& Modification log:
*& 2026-11-11 | Initial version (service health and process flow cards).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Service health and process flow - CDS test holder</p>
"! The service health and process flow cards (docs/Dashboard_Production_Support.md) are read-only CDS;
"! this class only carries their ABAP Unit tests (test include). It is never instantiated.
CLASS zcl_cd_ops_svc_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_cd_ops_svc_cds_test IMPLEMENTATION.

ENDCLASS.
