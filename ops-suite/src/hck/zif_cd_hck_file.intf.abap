*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_file.intf.abap
*& Purpose:
*& Application-server file access used by the morning-report export, behind an
*& interface so the write / publish logic is unit tested without files.
*& Modification log:
*& 2026-11-06 | Initial version (audit A61: no truncated report export).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - application server file access</p>
INTERFACE zif_cd_hck_file
  PUBLIC.

  "! Open for output (UTF-8 text); an existing file is replaced
  "! @raising zcx_ca_ops_error | 316 file could not be opened
  METHODS open_output
    IMPORTING
      iv_file TYPE string
    RAISING
      zcx_ca_ops_error.

  "! @raising zcx_ca_ops_error | 368 line could not be written
  METHODS transfer
    IMPORTING
      iv_file TYPE string
      iv_line TYPE string
    RAISING
      zcx_ca_ops_error.

  "! Close; harmless when the file is not open
  METHODS close
    IMPORTING
      iv_file TYPE string.

  "! Delete; harmless when the file does not exist
  METHODS delete
    IMPORTING
      iv_file TYPE string.

ENDINTERFACE.
