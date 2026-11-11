*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cat_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the activation views of the process
*& catalogue: effective activation of a catalogue process
*& (ZI_CA_OpsCatProcEff), registered checks in effect (ZI_CA_OpsChkEff) and
*& controls not expected in the daily review (ZI_CA_OpsCtlProcOff). No
*& production logic and no methods: the rules are CDS; the tests live in the
*& test include.
*& Modification log:
*& 2026-11-11 | Initial version (process catalogue with activation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Process catalogue - CDS unit test holder</p>
"! The activation rules of the dashboard and the review are derived in CDS (docs/PROCESS_CATALOGUE.md); this
"! class only carries their ABAP Unit tests (test include). It is never instantiated.
CLASS zcl_ca_ops_cat_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_ca_ops_cat_cds_test IMPLEMENTATION.

ENDCLASS.
