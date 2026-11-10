*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_ctl_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the daily control review (findings of a
*& control, derived state, awaiting and overdue review, counters). No
*& production logic and no methods: the status is CDS only; the tests live
*& in the test include.
*& Modification log:
*& 2026-11-10 | Initial version (control register and daily control review).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Daily control review - CDS unit test holder</p>
"! The status of a control per business date is derived in CDS (docs/CONTROL_REVIEW.md); this class
"! only carries its ABAP Unit tests (test include). It is never instantiated.
CLASS zcl_ca_ops_ctl_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_ca_ops_ctl_cds_test IMPLEMENTATION.

ENDCLASS.
