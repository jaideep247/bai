*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_brk_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the clearing-account break analysis and
*& of the pilot pack: snapshots shown (last run per key date, latest key
*& date flagged), breaks by bucket of the latest snapshots, and the pilot
*& metrics (exceptions per day, false positives, time to detect against the
*& baseline, share of breaks explained). No production logic and no
*& methods: the views are CDS; the tests live in the test include.
*& Modification log:
*& 2026-11-11 | Initial version (build F: break analysis and pilot pack).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Break analysis and pilot pack - CDS unit test holder</p>
"! The snapshots shown, the card per bucket and the pilot metrics are derived in CDS (docs/BREAK_ANALYSIS.md,
"! docs/PILOT_PACK.md); this class only carries their ABAP Unit tests (test include). It is never instantiated.
CLASS zcl_ca_ops_brk_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_ca_ops_brk_cds_test IMPLEMENTATION.

ENDCLASS.
