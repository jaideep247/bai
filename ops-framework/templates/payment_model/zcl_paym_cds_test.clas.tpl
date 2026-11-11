*&---------------------------------------------------------------------*
*& Artifact: zcl_{{p}}_paym_cds_test.clas.abap
*& Purpose:
*& Holder of the CDS unit tests of the generated payment model (cube per
*& currency and flow, trend against the same weekday last week, payment to
*& request links, masked feeder reference). Generated from the product
*& template by tools/abaptools/payment_model.py - never edit, regenerate.
*& No production logic: the tests live in the test include.
*& Modification log:
*& {{SINCE}} | Generated from the product template (payment model).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment model - CDS unit test holder</p>
"! The payment model is read-only CDS generated from a mapping spec; this class only carries its ABAP
"! Unit tests (test include). It is never instantiated.
CLASS zcl_{{p}}_paym_cds_test DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

ENDCLASS.



CLASS zcl_{{p}}_paym_cds_test IMPLEMENTATION.

ENDCLASS.
