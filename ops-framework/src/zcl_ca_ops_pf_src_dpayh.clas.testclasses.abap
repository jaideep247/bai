*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_src_dpayh.clas.testclasses.abap
*& Purpose:
*& Tests of the FI-CA payment run file source: payments of a run are
*& grouped into files by the configured fields (default paying company
*& code, method, house bank, account), the run key comes from DPAYH (run
*& date / run ID), payment keys from its key fields, a currency-less row
*& has no known amount; a grouping field outside BBUKR / RZAWE / HBKID /
*& HKTID is refused (386); the read keeps payment-order payments without
*& payment document only for the methods of the setting ORDERS (DPAYH
*& read replaced in test seam PF_DPAYH_READ). Does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-15 | Initial version (build K: payment file lifecycle).
*&---------------------------------------------------------------------*
CLASS ltc_pf_src_dpayh DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PUBLIC SECTION.
    "! The DPAYH rows of the test (read by the injection of seam PF_DPAYH_READ)
    CLASS-DATA gt_rows TYPE zcl_ca_ops_pf_src_dpayh=>tt_row.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_ca_ops_pf_src_dpayh.

    METHODS setup.
    METHODS configure
      IMPORTING
        iv_setting TYPE zif_ca_ops_pf_types=>ty_setting
      RAISING
        zcx_ca_ops_error.

    METHODS default_grouping      FOR TESTING RAISING zcx_ca_ops_error.
    METHODS own_grouping          FOR TESTING RAISING zcx_ca_ops_error.
    METHODS unknown_field_refused FOR TESTING.
    METHODS payment_orders_kept   FOR TESTING RAISING zcx_ca_ops_error.
ENDCLASS.


CLASS ltc_pf_src_dpayh IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
    gt_rows = VALUE #(
      ( laufd = '20261116' laufi = 'ZT1' orign = 'P' payno = 1 bbukr = '1000' rzawe = 'T' hbkid = 'BANK1' hktid = 'ACC1'
        waers = 'USD' rwbtr = '100.00' doc1r = 'D1' gpa1r = 'BP1' )
      ( laufd = '20261116' laufi = 'ZT1' orign = 'P' payno = 2 bbukr = '1000' rzawe = 'T' hbkid = 'BANK1' hktid = 'ACC1'
        waers = 'USD' rwbtr = '200.00' doc1r = 'D2' gpa1r = 'BP2' )
      ( laufd = '20261116' laufi = 'ZT1' orign = 'P' payno = 3 bbukr = '1000' rzawe = 'C' hbkid = 'BANK1' hktid = 'ACC1'
        waers = '' rwbtr = '0' doc1r = 'D3' gpa1r = 'BP3' )
      ( laufd = '20261116' laufi = 'ZT1' orign = 'P' payno = 4 bbukr = '1000' rzawe = 'O' hbkid = 'BANK1' hktid = 'ACC1'
        waers = 'USD' rwbtr = '50.00' doc1r = '' gpa1r = 'BP4' ) ).
  ENDMETHOD.


  METHOD configure.
    mo_cut->zif_ca_ops_pf_adapter~configure( VALUE #( role = zif_ca_ops_pf_types=>gc_role-file file_type = 'ZT'
                                                      class_name = 'ZCL_CA_OPS_PF_SRC_DPAYH' setting = iv_setting ) ).
  ENDMETHOD.


  METHOD default_grouping.
    configure( '' ).
    DATA(lt_files) = mo_cut->group( gt_rows ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_files ) exp = 3 msg = 'One file per method' ).
    DATA(ls_file) = lt_files[ native_key = '20261116/ZT1/1000/T/BANK1/ACC1' ].
    cl_abap_unit_assert=>assert_equals( act = ls_file-pay_count exp = 2 msg = 'Two payments' ).
    cl_abap_unit_assert=>assert_equals( act = ls_file-run_id exp = 'ZT1' msg = 'Run key from DPAYH' ).
    cl_abap_unit_assert=>assert_equals( act = ls_file-payments[ 1 ]-pay_key exp = '20261116/ZT1/P/1/' msg = 'Payment key' ).
    DATA(ls_cheque) = lt_files[ native_key = '20261116/ZT1/1000/C/BANK1/ACC1' ].
    cl_abap_unit_assert=>assert_false( act = ls_cheque-payments[ 1 ]-amount_known msg = 'No currency: amount unknown' ).
  ENDMETHOD.


  METHOD own_grouping.
    configure( 'GROUP=BBUKR,HBKID' ).
    DATA(lt_files) = mo_cut->group( gt_rows ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_files ) exp = 1 msg = 'One file per company code and bank' ).
  ENDMETHOD.


  METHOD unknown_field_refused.
    TRY.
        configure( 'GROUP=GPA1R' ).
        cl_abap_unit_assert=>fail( msg = 'Refused expected' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '386' msg = '386' ).
    ENDTRY.
  ENDMETHOD.


  METHOD payment_orders_kept.
    configure( 'ORDERS=O' ).
    TEST-INJECTION pf_dpayh_read.
      lt_rows = ltc_pf_src_dpayh=>gt_rows.
    END-TEST-INJECTION.
    DATA(ls_batch) = mo_cut->zif_ca_ops_pf_file_src~read_files( VALUE #( from_ts = '20261116000000.0000000'
                                                                         to_ts   = '20261117000000.0000000' ) ).
    cl_abap_unit_assert=>assert_equals( act = REDUCE i( INIT n = 0 FOR ls_f IN ls_batch-files NEXT n = n + ls_f-pay_count )
                                        exp = 4 msg = 'The payment order without document is a payment' ).
    configure( '' ).
    ls_batch = mo_cut->zif_ca_ops_pf_file_src~read_files( VALUE #( from_ts = '20261116000000.0000000'
                                                                   to_ts   = '20261117000000.0000000' ) ).
    cl_abap_unit_assert=>assert_equals( act = REDUCE i( INIT n = 0 FOR ls_f IN ls_batch-files NEXT n = n + ls_f-pay_count )
                                        exp = 3 msg = 'Without the setting: not paid' ).
  ENDMETHOD.

ENDCLASS.
