*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_dataset.clas.testclasses.abap
*& Purpose:
*& Unit tests of the application server file wrapper on its error paths
*& only (nothing is written): a file that cannot be opened and a transfer to
*& a file that is not open raise ZCX_CD_OPS_ERROR, close and delete of a
*& missing file are silent. The success path writes to the application
*& server and is a QA1 case; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltc_dataset DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    "! A directory that does not exist on any application server of the landscape
    CONSTANTS gc_missing_file TYPE string VALUE `/zcd_ops_no_such_directory/zcd_ops_unit_test.txt`.
    CONSTANTS gc_line TYPE string VALUE `unit test line`.

    DATA mo_cut TYPE REF TO zif_cd_hck_file.

    METHODS setup.
    METHODS teardown.
    METHODS unopenable_file_raises FOR TESTING.
    METHODS transfer_unopened_raises FOR TESTING.
    METHODS close_missing_is_silent FOR TESTING.
    METHODS delete_missing_is_silent FOR TESTING.
ENDCLASS.


CLASS ltc_dataset IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW zcl_cd_hck_dataset( ).
  ENDMETHOD.


  METHOD teardown.
    CLEAR mo_cut.
  ENDMETHOD.


  " Rule (A61): a report file that cannot be opened is an error, never a silent empty export
  METHOD unopenable_file_raises.
    TRY.
        mo_cut->open_output( gc_missing_file ).
        cl_abap_unit_assert=>fail( msg = 'Open in a missing directory must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Open error raised' ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A61): a line that cannot be written raises - no truncated export
  METHOD transfer_unopened_raises.
    TRY.
        mo_cut->transfer( iv_file = gc_missing_file
                          iv_line = gc_line ).
        cl_abap_unit_assert=>fail( msg = 'Transfer to a file that is not open must raise' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Transfer error raised' ).
    ENDTRY.
  ENDMETHOD.


  " Rule: closing a file that is not open is not an error (cleanup after a failure)
  METHOD close_missing_is_silent.
    TRY.
        mo_cut->close( gc_missing_file ).
        cl_abap_unit_assert=>assert_bound( act = mo_cut msg = 'Close returned without error' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: deleting a file that does not exist is not an error (cleanup after a failure)
  METHOD delete_missing_is_silent.
    TRY.
        mo_cut->delete( gc_missing_file ).
        cl_abap_unit_assert=>assert_bound( act = mo_cut msg = 'Delete returned without error' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
