*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_export.clas.abap
*& Purpose:
*& Writes a complete report file or none (audit A61): the content goes to a
*& temporary file first; the target is opened only after that succeeded; any
*& failure closes both, deletes the temporary file and a partly written target.
*& Modification log:
*& 2026-11-06 | Initial version (audit A61: no truncated report export).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - complete-or-nothing file export</p>
"! ABAP cannot rename a dataset atomically. Instead the full content is proven
"! writable on <file>.tmp before the target is replaced; a failure while the target
"! is being written removes it, so no truncated report is ever left behind.
CLASS zcl_cd_hck_export DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CONSTANTS gc_temp_suffix TYPE string VALUE `.tmp`.

    "! @raising zcx_cd_ops_error | 316 open / 368 write failed - nothing partial is left
    CLASS-METHODS write
      IMPORTING
        iv_file  TYPE string
        it_lines TYPE string_table
        io_file  TYPE REF TO zif_cd_hck_file
      RAISING
        zcx_cd_ops_error.

  PRIVATE SECTION.
    CLASS-METHODS write_all
      IMPORTING
        iv_file  TYPE string
        it_lines TYPE string_table
        io_file  TYPE REF TO zif_cd_hck_file
      RAISING
        zcx_cd_ops_error.

ENDCLASS.



CLASS zcl_cd_hck_export IMPLEMENTATION.

  METHOD write.
    DATA lv_target_opened TYPE abap_bool.
    DATA(lv_temp) = iv_file && gc_temp_suffix.
    TRY.
        write_all( iv_file = lv_temp it_lines = it_lines io_file = io_file ).
        lv_target_opened = abap_true.
        write_all( iv_file = iv_file it_lines = it_lines io_file = io_file ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        io_file->close( lv_temp ).
        io_file->delete( lv_temp ).
        io_file->close( iv_file ).
        IF lv_target_opened = abap_true.
          " the target was already being replaced: never leave it truncated
          io_file->delete( iv_file ).
        ENDIF.
        RAISE EXCEPTION lx_error.
    ENDTRY.
    io_file->delete( lv_temp ).
  ENDMETHOD.


  METHOD write_all.
    io_file->open_output( iv_file ).
    LOOP AT it_lines INTO DATA(lv_line).
      io_file->transfer( iv_file = iv_file iv_line = lv_line ).
    ENDLOOP.
    io_file->close( iv_file ).
  ENDMETHOD.

ENDCLASS.
