*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_dcl_test.clas.abap
*& Purpose:
*& Holder of the access-control unit tests of the framework's read roles
*& (company-code isolation): ZC_CA_OPSEXCEPTION and ZC_CA_OPSCTLREVIEW with
*& the access-control double of the CDS test double framework. No
*& production logic and no methods; the tests live in the test include. Kept
*& apart from the other CDS tests so that a correction of the double's API
*& (VERIFY-ADT) touches only this class.
*& Modification log:
*& 2026-11-10 | Initial version (company-code isolation of findings, history and control review).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Company-code isolation - DCL unit test holder</p>
"! The read rule of the exceptions app and the daily control review (area authorised and, for a
"! company code, area and company code authorised) is tested in the test include. Never instantiated.
CLASS zcl_ca_ops_dcl_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_ca_ops_dcl_test IMPLEMENTATION.

ENDCLASS.
