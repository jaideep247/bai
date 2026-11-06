*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_export.clas.testclasses.abap
*& Purpose:
*& Unit tests of the complete-or-nothing export with an LTD file double;
*& does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (audit A61: no truncated report export).
*& 2026-11-06 | Modern-syntax sweep: no trailing RETURN.
*&---------------------------------------------------------------------*
CLASS ltd_file DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_file.
    "! File whose writes fail (simulated disk / permission error)
    DATA mv_fail_on TYPE string.
    DATA mt_opened TYPE string_table.
    DATA mt_deleted TYPE string_table.
    DATA mt_written TYPE string_table.
ENDCLASS.

CLASS ltd_file IMPLEMENTATION.
  METHOD zif_cd_hck_file~open_output.
    INSERT iv_file INTO TABLE mt_opened.
  ENDMETHOD.
  METHOD zif_cd_hck_file~transfer.
    IF iv_file = mv_fail_on.
      RAISE EXCEPTION TYPE zcx_cd_ops_error MESSAGE e368(zcd_ops) WITH iv_file.
    ENDIF.
    INSERT |{ iv_file }={ iv_line }| INTO TABLE mt_written.
  ENDMETHOD.
  METHOD zif_cd_hck_file~close.
  ENDMETHOD.
  METHOD zif_cd_hck_file~delete.
    INSERT iv_file INTO TABLE mt_deleted.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_export DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_file TYPE string VALUE `/usr/sap/trans/morning.csv`.
    DATA mo_file TYPE REF TO ltd_file.
    DATA mt_lines TYPE string_table.

    METHODS setup.
    METHODS complete_write_publishes FOR TESTING.
    METHODS temp_failure_keeps_target FOR TESTING RAISING cx_static_check.
    METHODS target_failure_removes_it FOR TESTING RAISING cx_static_check.

ENDCLASS.



CLASS ltc_export IMPLEMENTATION.

  METHOD setup.
    mo_file = NEW #( ).
    CLEAR mt_lines.
    INSERT `A;B` INTO TABLE mt_lines.
    INSERT `1;2` INTO TABLE mt_lines.
  ENDMETHOD.


  " Rule: a complete write reaches the target and the temporary file is removed
  METHOD complete_write_publishes.
    TRY.
        zcl_cd_hck_export=>write( iv_file = gc_file it_lines = mt_lines io_file = mo_file ).
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_file->mt_written[ table_line = |{ gc_file }=1;2| ] ) )
                                          msg = 'The target must receive every line' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( mo_file->mt_deleted[ table_line = gc_file && zcl_cd_hck_export=>gc_temp_suffix ] ) )
          msg = 'The temporary file must be removed' ).
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( mo_file->mt_deleted[ table_line = gc_file ] ) )
                                           msg = 'A complete target must not be deleted' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Audit A61: a failure while writing the temporary file never touches the target
  METHOD temp_failure_keeps_target.
    mo_file->mv_fail_on = gc_file && zcl_cd_hck_export=>gc_temp_suffix.
    TRY.
        zcl_cd_hck_export=>write( iv_file = gc_file it_lines = mt_lines io_file = mo_file ).
        cl_abap_unit_assert=>fail( msg = 'The write error must be raised' ).
      CATCH zcx_cd_ops_error.
        cl_abap_unit_assert=>assert_false( act = xsdbool( line_exists( mo_file->mt_opened[ table_line = gc_file ] ) )
                                           msg = 'The target must not be opened after a failed temporary write' ).
        cl_abap_unit_assert=>assert_true(
          act = xsdbool( line_exists( mo_file->mt_deleted[ table_line = gc_file && zcl_cd_hck_export=>gc_temp_suffix ] ) )
          msg = 'The partial temporary file must be removed' ).
    ENDTRY.
  ENDMETHOD.


  " Audit A61: a failure while replacing the target removes it - never a truncated report
  METHOD target_failure_removes_it.
    mo_file->mv_fail_on = gc_file.
    TRY.
        zcl_cd_hck_export=>write( iv_file = gc_file it_lines = mt_lines io_file = mo_file ).
        cl_abap_unit_assert=>fail( msg = 'The write error must be raised' ).
      CATCH zcx_cd_ops_error.
        cl_abap_unit_assert=>assert_true( act = xsdbool( line_exists( mo_file->mt_deleted[ table_line = gc_file ] ) )
                                          msg = 'A partly written target must be deleted' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
