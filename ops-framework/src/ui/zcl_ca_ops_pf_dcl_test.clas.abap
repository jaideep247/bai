*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_dcl_test.clas.abap
*& Purpose:
*& Holder of the access-control unit tests of the payment file worklist
*& (pack FICA_CASH): ZC_CA_OPSPAYFILE, ZC_CA_OPSPFPAYMENT,
*& ZC_CA_OPSPFMILESTONE and ZC_CA_OPSPFEVIDENCE with the access-control
*& double of the CDS test double framework (two-user company-code
*& isolation, build Q). No production logic and no methods; the tests live
*& in the test include. In the pack of the views it tests (a core object
*& never names a FICA_CASH object).
*& Modification log:
*& 2026-11-16 | Initial version (build Q: two-user isolation of the payment file worklist).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment file worklist - DCL unit test holder</p>
"! The read rule of the payment file worklist (area authorised and, for a company code, area and company
"! code authorised) is tested in the test include. Never instantiated.
CLASS zcl_ca_ops_pf_dcl_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_ca_ops_pf_dcl_test IMPLEMENTATION.

ENDCLASS.
