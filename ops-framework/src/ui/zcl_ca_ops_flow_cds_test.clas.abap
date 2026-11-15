*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_flow_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the account flow reconciliation: the
*& journal signatures of the flow accounts (window, ledger, account and
*& currency range), the positions and Unexplained (evaluated, not
*& evaluated, no control point, the sign of an unsigned amount) and the
*& control tags of the stages. No production logic and no methods: the
*& dashboard is CDS; the tests live in the test include.
*& Modification log:
*& 2026-11-15 | Initial version (build G: account flow reconciliation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Account flow - CDS unit test holder</p>
"! The movement, positions, expected postings and control tags are derived in CDS (docs/ACCOUNT_FLOW.md); this class
"! only carries their ABAP Unit tests (test include). It is never instantiated.
CLASS zcl_ca_ops_flow_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_ca_ops_flow_cds_test IMPLEMENTATION.

ENDCLASS.
