*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_util.clas.testclasses.abap
*& Purpose:
*& Domain tests of the payment engine helpers: ZCD_OPS texts, bank reference
*& key normalisation, account masking. No doubles. Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Test text_fills_message_vars (texts as ZCD_OPS messages).
*& 2026-11-10 | account_label tests.
*& 2026-11-10 | Tests of the generic helpers moved with them to the framework ZCA_OPS (ZCL_CA_OPS_UTIL).
*&---------------------------------------------------------------------*
CLASS ltc_util DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS key_padded_after_zero_strip  FOR TESTING.
    METHODS key_length_zero_keeps_value  FOR TESTING.
    METHODS text_fills_message_vars      FOR TESTING.
    METHODS text_tail_is_not_truncated   FOR TESTING.
    METHODS account_shows_house_bank     FOR TESTING.
    METHODS account_number_is_masked     FOR TESTING.
    METHODS short_account_fully_masked   FOR TESTING.

    CONSTANTS:
      BEGIN OF gc_test,
        account     TYPE string VALUE `0012345678`,
        masked      TYPE string VALUE `****5678`,
        short       TYPE string VALUE `678`,
        hbkid       TYPE string VALUE `JPMC1`,
        hktid       TYPE string VALUE `OPS01`,
        house_label TYPE string VALUE `JPMC1/OPS01`,
      END OF gc_test.
ENDCLASS.


CLASS ltc_util IMPLEMENTATION.

  " Bank references are normalised to the document key length
  METHOD key_padded_after_zero_strip.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>normalize_key( iv_reference = ' 0000012345 '
                                                                             iv_length    = 12 )
                                        exp = `000000012345`
                                        msg = 'Reference must be normalised to 12 digits' ).
  ENDMETHOD.


  " Length 0 keeps the reference as delivered (check numbers)
  METHOD key_length_zero_keeps_value.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>normalize_key( iv_reference = '00777' iv_length = 0 )
                                        exp = `00777`
                                        msg = 'Length 0 must keep leading zeros' ).
  ENDMETHOD.


  " Texts are T100 text elements: message 000 (&1 &2 &3 &4) of ZCD_OPS with the variables filled
  " in order; numbers keep their template formatting
  METHOD text_fills_message_vars.
    TRY.
        DATA(lv_text) = zcl_cd_ops_util=>text( iv_msgno = '000'
                                               iv_v1    = `A`
                                               iv_v2    = 42
                                               iv_v3    = `C` ).
        cl_abap_unit_assert=>assert_equals( act = condense( lv_text ) exp = `A 42 C`
                                            msg = 'Variables must replace &1 to &3 in order' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A long value (exception text, finding message) is appended untruncated as the tail -
  " message variables are only 50 characters long
  METHOD text_tail_is_not_truncated.
    TRY.
        DATA(lv_long) = repeat( val = `x` occ = 80 ).
        DATA(lv_text) = zcl_cd_ops_util=>text( iv_msgno = '000' iv_v1 = `A` iv_tail = lv_long ).
        cl_abap_unit_assert=>assert_equals( act = condense( lv_text ) exp = |A { lv_long }|
                                            msg = 'The tail must follow the message text in full' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " B15: house bank and account ID replace the account number when both are known
  METHOD account_shows_house_bank.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>account_label( iv_account = gc_test-account
                                                                             iv_hbkid   = gc_test-hbkid
                                                                             iv_hktid   = gc_test-hktid )
                                        exp = gc_test-house_label
                                        msg = 'House bank / account ID, never the number' ).
  ENDMETHOD.


  " B15: without house bank only the last four characters are shown
  METHOD account_number_is_masked.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_util=>account_label( gc_test-account )
                                        exp = gc_test-masked
                                        msg = 'Masked to the last four characters' ).
  ENDMETHOD.


  " B15: a number of four characters or fewer is masked completely
  METHOD short_account_fully_masked.
    cl_abap_unit_assert=>assert_false( act = xsdbool( zcl_cd_ops_util=>account_label( gc_test-short ) CS gc_test-short )
                                       msg = 'A short number never appears in full' ).
  ENDMETHOD.

ENDCLASS.
