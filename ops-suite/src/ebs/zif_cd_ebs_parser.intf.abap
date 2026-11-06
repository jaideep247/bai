*&---------------------------------------------------------------------*
*& Artifact: zif_cd_ebs_parser.intf.abap
*& Purpose:
*& Implementations: ZCL_CD_EBS_PARSER_BAI2, ZCL_CD_EBS_PARSER_CAMT.
*& A parser never posts and never reads the database. Structural problems that
*& still allow reading return findings (S00/S06/S11/S12); an unreadable file raises.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">EBS validation - bank file parser</p>
"! Implementations: ZCL_CD_EBS_PARSER_BAI2, ZCL_CD_EBS_PARSER_CAMT.
"! A parser never posts and never reads the database. Structural problems that
"! still allow reading return findings (S00/S06/S11/S12); an unreadable file raises.
INTERFACE zif_cd_ebs_parser
  PUBLIC.

  METHODS parse
    IMPORTING
      iv_content     TYPE string
      iv_file_name   TYPE string OPTIONAL
    RETURNING
      VALUE(rs_file) TYPE zif_cd_ebs_types=>ty_file
    RAISING
      zcx_cd_ops_error.

ENDINTERFACE.
