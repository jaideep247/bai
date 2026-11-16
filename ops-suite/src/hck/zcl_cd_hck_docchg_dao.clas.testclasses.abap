*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_docchg_dao.clas.testclasses.abap
*& Purpose:
*& OSQL tests of the document-change reads: a payment document whose header
*& carries a reversal entered in the window is returned once per payment
*& run, latest run first; proposal runs, reversals outside the window and
*& documents without reversal are not; the row cap holds; a reversal found
*& only by the reversal document's STBEL (original without STORB) counts.
*& Tables DFKKKO and DPAYH are doubled; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-11 | Initial version (reversal and reset-clearing tracking, build C).
*& 2026-11-15 | DPAYH paying company code BBUKR and method RZAWE (DPAYH has no BUKRS / PYMET; reference system S/4HANA
*&            | 2025).
*& 2026-11-16 | Reversal direction (reference system A4H): the reversal carries STBEL = the reversed payment
*&            | document, the original STORB = its reversal; test of a reversal found by STBEL only.
*&---------------------------------------------------------------------*
CLASS ltc_docchg_dao DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        from       TYPE d VALUE '20261105',
        to         TYPE d VALUE '20261110',
        in_window  TYPE d VALUE '20261109',
        too_early  TYPE d VALUE '20261101',
        run_old    TYPE d VALUE '20261102',
        run_new    TYPE d VALUE '20261103',
        pay_doc    TYPE c LENGTH 12 VALUE '000012345678',
        rev_doc    TYPE c LENGTH 12 VALUE '000099990001',
        old_pay    TYPE c LENGTH 12 VALUE '000012340000',
        old_rev    TYPE c LENGTH 12 VALUE '000099990000',
        lone_pay   TYPE c LENGTH 12 VALUE '000077770000',
        lone_rev   TYPE c LENGTH 12 VALUE '000099990002',
        plain_pay  TYPE c LENGTH 12 VALUE '000055550000',
        bukrs      TYPE c LENGTH 4 VALUE 'ZT01',
        proposal   TYPE c LENGTH 1 VALUE 'X',
      END OF gc.

    CLASS-DATA go_env TYPE REF TO if_osql_test_environment.

    CLASS-METHODS class_setup.
    CLASS-METHODS class_teardown.
    METHODS setup.

    METHODS reversed_payment_per_run FOR TESTING.
    METHODS row_cap_holds FOR TESTING.
    METHODS found_by_reversal_stbel FOR TESTING.

    METHODS header
      IMPORTING
        iv_opbel TYPE clike
        iv_stbel TYPE clike OPTIONAL
        iv_storb TYPE clike OPTIONAL
        iv_cpudt TYPE d OPTIONAL.
    METHODS run
      IMPORTING
        iv_doc   TYPE clike
        iv_laufd TYPE d
        iv_xvorl TYPE abap_bool DEFAULT abap_false.
ENDCLASS.


CLASS ltc_docchg_dao IMPLEMENTATION.

  METHOD class_setup.
    go_env = cl_osql_test_environment=>create( i_dependency_list = VALUE #( ( 'DFKKKO' ) ( 'DPAYH' ) ) ).
  ENDMETHOD.


  METHOD class_teardown.
    go_env->destroy( ).
  ENDMETHOD.


  METHOD header.
    DATA lt_headers TYPE STANDARD TABLE OF dfkkko WITH EMPTY KEY.
    DATA ls_header TYPE dfkkko.
    ls_header-opbel = iv_opbel.
    ls_header-stbel = iv_stbel.
    ls_header-storb = iv_storb.
    ls_header-cpudt = iv_cpudt.
    ls_header-fikey = iv_opbel.
    INSERT ls_header INTO TABLE lt_headers.
    go_env->insert_test_data( lt_headers ).
  ENDMETHOD.


  METHOD run.
    DATA lt_runs TYPE STANDARD TABLE OF dpayh WITH EMPTY KEY.
    DATA ls_run TYPE dpayh.
    ls_run-laufd = iv_laufd.
    ls_run-laufi = iv_doc+6(6).
    ls_run-doc1r = iv_doc.
    ls_run-xvorl = iv_xvorl.
    ls_run-bbukr = gc-bukrs.
    INSERT ls_run INTO TABLE lt_runs.
    go_env->insert_test_data( lt_runs ).
  ENDMETHOD.


  METHOD setup.
    go_env->clear_doubles( ).
    " reversed in the window (the original names its reversal in STORB, the reversal the original in
    " STBEL), paid in two runs and one proposal run
    header( iv_opbel = gc-pay_doc iv_storb = gc-rev_doc ).
    header( iv_opbel = gc-rev_doc iv_stbel = gc-pay_doc iv_cpudt = gc-in_window ).
    run( iv_doc = gc-pay_doc iv_laufd = gc-run_old ).
    run( iv_doc = gc-pay_doc iv_laufd = gc-run_new ).
    run( iv_doc = gc-pay_doc iv_laufd = gc-in_window iv_xvorl = gc-proposal ).
    " reversed before the window; a payment without reversal
    header( iv_opbel = gc-old_pay iv_storb = gc-old_rev ).
    header( iv_opbel = gc-old_rev iv_stbel = gc-old_pay iv_cpudt = gc-too_early ).
    run( iv_doc = gc-old_pay iv_laufd = gc-run_old ).
    header( iv_opbel = gc-plain_pay ).
    run( iv_doc = gc-plain_pay iv_laufd = gc-run_new ).
  ENDMETHOD.


  METHOD reversed_payment_per_run.
    TRY.
        DATA(lt_rows) = NEW zcl_cd_hck_docchg_dao( )->zif_cd_hck_docchg_dao~get_reversed_payments(
                          iv_from = gc-from iv_to = gc-to iv_max_rows = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2
                                            msg = 'One row per payment run, proposal run left out' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-laufd exp = gc-run_new msg = 'Latest run first' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-reversal_doc exp = gc-rev_doc msg = 'Reversal document' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-reversed_on exp = gc-in_window
                                            msg = 'Entry date of the reversal' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-bukrs exp = gc-bukrs msg = 'Company code of the run' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD row_cap_holds.
    TRY.
        DATA(lt_rows) = NEW zcl_cd_hck_docchg_dao( )->zif_cd_hck_docchg_dao~get_reversed_payments(
                          iv_from = gc-from iv_to = gc-to iv_max_rows = 1 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'At most the cap' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the reversal is found by the reversal document's STBEL alone - an original without STORB
  " (the field the reference system A4H did not prove) is still reported
  METHOD found_by_reversal_stbel.
    TRY.
        go_env->clear_doubles( ).
        header( iv_opbel = gc-lone_pay ).
        header( iv_opbel = gc-lone_rev iv_stbel = gc-lone_pay iv_cpudt = gc-in_window ).
        run( iv_doc = gc-lone_pay iv_laufd = gc-run_new ).
        DATA(lt_rows) = NEW zcl_cd_hck_docchg_dao( )->zif_cd_hck_docchg_dao~get_reversed_payments(
                          iv_from = gc-from iv_to = gc-to iv_max_rows = 100 ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'Reversal by STBEL found' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-payment_doc exp = gc-lone_pay msg = 'Reversed payment' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-reversal_doc exp = gc-lone_rev msg = 'Reversal document' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
