*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_lic_file.clas.testclasses.abap
*& Purpose:
*& Tests of the licence file reader: PEM armour and line breaks removed and
*& the Base64 decoded, a text without Base64 refused (361), the payload of
*& the vendor's tool read from its JSON (modules, systems, installations,
*& grace days), a text that is no JSON and a JSON without licence ID
*& refused. No database, no SSF.
*& Modification log:
*& 2026-11-15 | Initial version (licensing).
*&---------------------------------------------------------------------*
CLASS ltc_lic_file DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc,
        "! Base64 of the three bytes 4D 61 6E
        base64  TYPE string VALUE `TWFu`,
        der     TYPE xstring VALUE '4D616E',
        "! The payload exactly as tools/licensing/issue_license.py writes it
        json    TYPE string VALUE `{"LICENSE":{"FORMAT":1,"LICENSE_ID":"ZT-LIC-0001","PRODUCT":"ZCA_OPS",`
                                & `"CUSTOMER":"ZT customer","INSTALLATIONS":["0020123456"],`
                                & `"SYSTEMS":[{"SID":"PS4","CLIENT":"100"},{"SID":"QA1","CLIENT":""}],`
                                & `"VERSION_FROM":"1.0","VERSION_TO":"1",`
                                & `"MODULES":[{"CODE":"JOBS","VALID_FROM":"20261115","VALID_TO":"20271114"}],`
                                & `"GRACE_DAYS":30,"ISSUED_AT":"20261115120000"}}`,
        no_id   TYPE string VALUE `{"LICENSE":{"FORMAT":1,"LICENSE_ID":""}}`,
        no_json TYPE string VALUE `licence`,
      END OF gc.

    METHODS pem_decoded                FOR TESTING RAISING zcx_ca_ops_error.
    METHODS no_base64_refused          FOR TESTING.
    METHODS payload_read               FOR TESTING RAISING zcx_ca_ops_error.
    METHODS no_json_refused            FOR TESTING.
    METHODS payload_without_id_refused FOR TESTING.

    METHODS utf8
      IMPORTING
        iv_text         TYPE string
      RETURNING
        VALUE(rv_bytes) TYPE xstring.
ENDCLASS.


CLASS ltc_lic_file IMPLEMENTATION.

  METHOD utf8.
    rv_bytes = cl_abap_codepage=>convert_to( iv_text ).
  ENDMETHOD.


  METHOD pem_decoded.
    DATA(lv_pem) = |-----BEGIN CMS-----\r\n{ gc-base64 }\n-----END CMS-----\n|.
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_lic_file=>der_of( lv_pem ) exp = gc-der ).
    " Base64 without the armour lines is accepted as well
    cl_abap_unit_assert=>assert_equals( act = zcl_ca_ops_lic_file=>der_of( gc-base64 ) exp = gc-der ).
  ENDMETHOD.


  METHOD no_base64_refused.
    TRY.
        zcl_ca_ops_lic_file=>der_of( `not base64 *` ).
        cl_abap_unit_assert=>fail( 'no Base64 accepted' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '361' ).
    ENDTRY.
  ENDMETHOD.


  METHOD payload_read.
    DATA(ls_payload) = zcl_ca_ops_lic_file=>payload_of( utf8( gc-json ) ).
    cl_abap_unit_assert=>assert_equals( act = ls_payload-format exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = ls_payload-license_id exp = `ZT-LIC-0001` ).
    cl_abap_unit_assert=>assert_equals( act = ls_payload-product exp = `ZCA_OPS` ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_payload-installations ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lines( ls_payload-systems ) exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = ls_payload-systems[ 1 ]-client exp = '100' ).
    cl_abap_unit_assert=>assert_equals( act = ls_payload-modules[ 1 ]-code exp = 'JOBS' ).
    cl_abap_unit_assert=>assert_equals( act = ls_payload-modules[ 1 ]-valid_to exp = '20271114' ).
    cl_abap_unit_assert=>assert_equals( act = ls_payload-grace_days exp = 30 ).
  ENDMETHOD.


  METHOD no_json_refused.
    TRY.
        zcl_ca_ops_lic_file=>payload_of( utf8( gc-no_json ) ).
        cl_abap_unit_assert=>fail( 'no JSON accepted' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '361' ).
    ENDTRY.
  ENDMETHOD.


  METHOD payload_without_id_refused.
    TRY.
        zcl_ca_ops_lic_file=>payload_of( utf8( gc-no_id ) ).
        cl_abap_unit_assert=>fail( 'payload without licence ID accepted' ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '361' ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
