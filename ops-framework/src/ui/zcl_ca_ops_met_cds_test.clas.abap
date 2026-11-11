*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_met_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the response-time metrics (MTTA / MTTR):
*& first assignment of an episode (ZI_CA_OpsExcAssign1), re-opened exceptions
*& (ZI_CA_OpsExcReopen), times and flags (ZI_CA_OpsExcTimes), counters, buckets
*& and averages (ZR_CA_OpsExcMetric). No production logic and no methods: the
*& metrics are CDS only; the tests live in the test include.
*& Modification log:
*& 2026-11-11 | Initial version (operations response features: response-time metrics).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Response-time metrics - CDS unit test holder</p>
"! The metrics are derived in CDS (docs/OPERATIONS_FEATURES.md); this class only carries their ABAP Unit
"! tests (test include). It is never instantiated.
CLASS zcl_ca_ops_met_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_ca_ops_met_cds_test IMPLEMENTATION.

ENDCLASS.
