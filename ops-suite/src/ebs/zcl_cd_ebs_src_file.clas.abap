*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ebs_src_file.clas.abap
*& Purpose:
*& Source for one bank file before import: parses it with the parser of its
*& format (BAI2, CAMT.053/054) and hands statements, lines and the parser's
*& structural findings (S00/S06/S11/S12) to the engine as one package.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-07 | get_file removed (no caller).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - source bank file</p>
CLASS zcl_cd_ebs_src_file DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_cd_ebs_source.

    METHODS constructor
      IMPORTING
        iv_content   TYPE string
        iv_format    TYPE zif_cd_ebs_types=>ty_format
        iv_file_name TYPE string OPTIONAL.


  PRIVATE SECTION.
    DATA mv_content   TYPE string.
    DATA mv_format    TYPE zif_cd_ebs_types=>ty_format.
    DATA mv_file_name TYPE string.
    DATA mv_done      TYPE abap_bool.
    DATA ms_file      TYPE zif_cd_ebs_types=>ty_file.

ENDCLASS.



CLASS zcl_cd_ebs_src_file IMPLEMENTATION.

  METHOD constructor.
    mv_content   = iv_content.
    mv_format    = iv_format.
    mv_file_name = iv_file_name.
  ENDMETHOD.


  METHOD zif_cd_ebs_source~next_package.
    IF mv_done = abap_true.
      RETURN.
    ENDIF.
    mv_done = abap_true.
    ms_file = zcl_cd_ebs_factory=>get_parser( mv_format )->parse( iv_content   = mv_content
                                                                  iv_file_name = mv_file_name ).
    rs_package-statements = ms_file-statements.
    rs_package-lines      = ms_file-lines.
    rs_package-findings   = ms_file-findings.
  ENDMETHOD.

ENDCLASS.
