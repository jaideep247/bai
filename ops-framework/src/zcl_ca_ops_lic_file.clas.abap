*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_lic_file.clas.abap
*& Purpose:
*& Reading a licence file, pure (no database, no SSF): the PEM text the
*& vendor's tool writes (-----BEGIN CMS----- / PKCS7 ... -----END ...-----,
*& or Base64 without the armour lines) to the DER bytes of the signed data,
*& and the signed content (UTF-8 JSON, asJSON of ZIF_CA_OPS_LIC_TYPES=>
*& TY_PAYLOAD under the name LICENSE) to the payload structure, read by the
*& identity transformation through an sXML reader (VERIFY V164). A file
*& that is no Base64 or no payload of the vendor's format raises 361.
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - licence file reader (pure)</p>
CLASS zcl_ca_ops_lic_file DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! DER of the signed data of a PEM / Base64 text
    "! @raising zcx_ca_ops_error | 361 no Base64 content
    CLASS-METHODS der_of
      IMPORTING
        iv_content    TYPE string
      RETURNING
        VALUE(rv_der) TYPE xstring
      RAISING
        zcx_ca_ops_error.

    "! The payload of the signed content
    "! @raising zcx_ca_ops_error | 361 not UTF-8 JSON of the payload
    CLASS-METHODS payload_of
      IMPORTING
        iv_content        TYPE xstring
      RETURNING
        VALUE(rs_payload) TYPE zif_ca_ops_lic_types=>ty_payload
      RAISING
        zcx_ca_ops_error.

  PRIVATE SECTION.
    "! An armour line of PEM (-----BEGIN ...----- / -----END ...-----)
    CONSTANTS gc_armour_pcre TYPE string VALUE `-----[A-Z0-9 ]+-----`.
    CONSTANTS gc_base64_pcre TYPE string VALUE `^[A-Za-z0-9+/]+={0,2}$`.
    CONSTANTS gc_space_pcre TYPE string VALUE `\s+`.

ENDCLASS.



CLASS zcl_ca_ops_lic_file IMPLEMENTATION.

  METHOD der_of.
    DATA(lv_base64) = replace( val = iv_content pcre = gc_armour_pcre with = `` occ = 0 ).
    lv_base64 = replace( val = lv_base64 pcre = gc_space_pcre with = `` occ = 0 ).
    IF lv_base64 IS INITIAL OR NOT matches( val = lv_base64 pcre = gc_base64_pcre ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e361(zca_ops) WITH 'BASE64'.
    ENDIF.
    rv_der = cl_http_utility=>decode_x_base64( lv_base64 ).
    IF rv_der IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e361(zca_ops) WITH 'BASE64'.
    ENDIF.
  ENDMETHOD.


  METHOD payload_of.
    IF iv_content IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e361(zca_ops) WITH 'JSON'.
    ENDIF.
    TRY.
        " VERIFY-ADT (V164): an sXML string reader recognises UTF-8 JSON and the identity transformation reads
        " the asJSON representation of the structure (members = component names, upper case)
        DATA(lo_reader) = cl_sxml_string_reader=>create( iv_content ).
        CALL TRANSFORMATION id SOURCE XML lo_reader RESULT license = rs_payload.
      CATCH cx_transformation_error cx_sxml_error INTO DATA(lx_json).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e361(zca_ops) WITH 'JSON'
          EXPORTING
            previous = lx_json.
    ENDTRY.
    IF rs_payload-format IS INITIAL OR rs_payload-license_id IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e361(zca_ops) WITH 'LICENSE'.
    ENDIF.
  ENDMETHOD.

ENDCLASS.
