*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_hovr_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the shift handover: the current shift start
*& (ZI_CA_OpsShiftCur), the previous one (ZI_CA_OpsShiftPrev) and the handover
*& counts per team, area and company code (ZI_CA_OpsHovrEvt). No production
*& logic and no methods: the handover is CDS only; the tests live in the test
*& include.
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: shift handover).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Shift handover - CDS unit test holder</p>
"! The shift handover is derived in CDS (docs/OPERATIONS_FEATURES.md); this class only carries its ABAP Unit
"! tests (test include). It is never instantiated.
CLASS zcl_ca_ops_hovr_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_ca_ops_hovr_cds_test IMPLEMENTATION.

ENDCLASS.
