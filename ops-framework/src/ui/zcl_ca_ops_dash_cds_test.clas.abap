*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_dash_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the area dashboard of the check registry
*& (ZR_CA_OpsCheckStatus): status, freshness and the overview card counters
*& (registered checks, flagged, stale, needs attention). No production logic
*& and no methods: the dashboard is CDS only; the tests live in the test
*& include.
*& Modification log:
*& 2026-11-10 | Initial version (overview card of the area dashboard).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Area dashboard - CDS unit test holder</p>
"! The status per registered check is derived in CDS (docs/ADDING_A_BUSINESS_PROCESS.md); this class only
"! carries its ABAP Unit tests (test include). It is never instantiated.
CLASS zcl_ca_ops_dash_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_ca_ops_dash_cds_test IMPLEMENTATION.

ENDCLASS.
