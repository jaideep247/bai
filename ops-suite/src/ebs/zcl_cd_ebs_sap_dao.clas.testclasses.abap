*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_sap_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the payment engine read repository: returns lot items are found
*& by SELW1 with the lot status of their OPBEL; payments by DOC1R; an empty key
*& list reads nothing. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Operating model: posting-area flag names are DDIC-validated (unknown name raises).
*&---------------------------------------------------------------------*
CLASS ltc_sap_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        payment TYPE zif_cd_ebs_sap_dao=>ty_docno VALUE '000000012345',
        lot_doc TYPE zif_cd_ebs_sap_dao=>ty_docno VALUE '000000099999',
      END OF gc_test.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.
    DATA mo_cut TYPE REF TO zif_cd_ebs_sap_dao.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS return_item_found_by_selw1   FOR TESTING.
    METHODS empty_keys_read_nothing      FOR TESTING.
    METHODS payment_found_by_doc1r       FOR TESTING.
    METHODS posting_unknown_field_raises FOR TESTING.
    METHODS posting_empty_keys_nothing   FOR TESTING.
ENDCLASS.


CLASS ltc_sap_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create(
      i_dependency_list = VALUE #( ( 'DFKKRP' ) ( 'DFKKRK' ) ( 'DPAYH' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD setup.
    DATA lt_rp TYPE STANDARD TABLE OF dfkkrp WITH EMPTY KEY.
    DATA ls_rp TYPE dfkkrp.
    DATA lt_rk TYPE STANDARD TABLE OF dfkkrk WITH EMPTY KEY.
    DATA ls_rk TYPE dfkkrk.
    DATA lt_payh TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    DATA ls_payh TYPE dpayh.

    go_env->clear_doubles( ).
    ls_rp-opbel = gc_test-lot_doc.
    ls_rp-selw1 = gc_test-payment.
    INSERT ls_rp INTO TABLE lt_rp.
    go_env->insert_test_data( lt_rp ).
    ls_rk-opbel = gc_test-lot_doc.
    ls_rk-stars = '5'.
    INSERT ls_rk INTO TABLE lt_rk.
    go_env->insert_test_data( lt_rk ).
    ls_payh-doc1r = gc_test-payment.
    ls_payh-laufd = '20261104'.
    ls_payh-laufi = 'PCLM01'.
    INSERT ls_payh INTO TABLE lt_payh.
    go_env->insert_test_data( lt_payh ).
    mo_cut = NEW zcl_cd_ebs_sap_dao( ).
  ENDMETHOD.


  " Confirmed path DFKKRP-SELW1 = payment document; lot status via DFKKRP-OPBEL
  METHOD return_item_found_by_selw1.
    TRY.
        DATA(lt_items) = mo_cut->get_return_items( VALUE #( ( gc_test-payment ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_items ) exp = 1 msg = 'One returns item expected' ).
        cl_abap_unit_assert=>assert_equals( act = lt_items[ 1 ]-lot_stars exp = '5'
                                            msg = 'Lot status must come from DFKKRK of the item OPBEL' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " FOR ALL ENTRIES guard: an empty key list must not read the whole table
  METHOD empty_keys_read_nothing.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_return_items( VALUE #( ) )
                                             msg = 'Empty key list must return nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Payment run entry is found by DOC1R
  METHOD payment_found_by_doc1r.
    TRY.
        DATA(lt_payments) = mo_cut->get_payments( VALUE #( ( gc_test-payment ) ) ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_payments ) exp = 1 msg = 'One payment expected' ).
        cl_abap_unit_assert=>assert_equals( act = lt_payments[ 1 ]-laufi exp = 'PCLM01'
                                            msg = 'Payment run id must be returned' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

  " Operating model 2026-11-06: a posting-area flag name that is not a FEBEP field is a
  " configuration error (message 051) - never a silent 'every entry not posted'
  METHOD posting_unknown_field_raises.
    DATA lt_kukey TYPE zif_cd_ebs_sap_dao=>tt_febep_kukey.
    DATA lt_fields TYPE string_table.
    INSERT CONV #( '00001001' ) INTO TABLE lt_kukey.
    INSERT `ZZ_NOT_A_FEBEP_FIELD` INTO TABLE lt_fields.
    TRY.
        mo_cut->get_febep_posting( it_kukey = lt_kukey it_fields = lt_fields ).
        cl_abap_unit_assert=>fail( msg = 'An unknown FEBEP field must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '051'
                                            msg = 'Message 051 (invalid configuration value) expected' ).
    ENDTRY.
  ENDMETHOD.


  " FOR ALL ENTRIES guard: no statement key, no read
  METHOD posting_empty_keys_nothing.
    DATA lt_fields TYPE string_table.
    INSERT `VB1OK` INTO TABLE lt_fields.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = mo_cut->get_febep_posting( it_kukey  = VALUE #( )
                                                                               it_fields = lt_fields )
                                             msg = 'Empty key list must return nothing' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
