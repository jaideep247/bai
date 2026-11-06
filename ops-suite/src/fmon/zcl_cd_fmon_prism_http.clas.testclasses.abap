*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_http.clas.testclasses.abap
*& Purpose:
*& Unit tests of the ICF handler of the PRISM status API with local doubles
*& of the ICF server, request and response: method, content type and body
*& reach the API, its status, JSON body, content type and the Allow header
*& reach the response. Only answers decided before any read are used (405,
*& 403 with the injected authorisation double); does not prove live SAP
*& runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*&---------------------------------------------------------------------*
CLASS ltd_request DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES if_http_request PARTIALLY IMPLEMENTED.
    DATA mv_method TYPE string.
    DATA mv_content_type TYPE string.
    DATA mv_body TYPE xstring.
ENDCLASS.

CLASS ltd_request IMPLEMENTATION.
  METHOD if_http_request~get_method.
    method = mv_method.
  ENDMETHOD.

  METHOD if_http_entity~get_content_type.
    content_type = mv_content_type.
  ENDMETHOD.

  METHOD if_http_entity~get_data.
    data = mv_body.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_response DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES if_http_response PARTIALLY IMPLEMENTED.
    DATA mv_code TYPE i.
    DATA mv_content_type TYPE string.
    DATA mv_allow TYPE string.
    DATA mv_body TYPE string.
ENDCLASS.

CLASS ltd_response IMPLEMENTATION.
  METHOD if_http_response~set_status.
    mv_code = code.
  ENDMETHOD.

  METHOD if_http_entity~set_content_type.
    mv_content_type = content_type.
  ENDMETHOD.

  METHOD if_http_entity~set_header_field.
    mv_allow = value.
  ENDMETHOD.

  METHOD if_http_entity~set_cdata.
    mv_body = data.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_server DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES if_http_server PARTIALLY IMPLEMENTED.
    METHODS constructor
      IMPORTING
        io_request  TYPE REF TO ltd_request
        io_response TYPE REF TO ltd_response.
ENDCLASS.

CLASS ltd_server IMPLEMENTATION.
  METHOD constructor.
    if_http_server~request  = io_request.
    if_http_server~response = io_response.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_auth DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_auth PARTIALLY IMPLEMENTED.
    DATA mv_allowed TYPE abap_bool.
ENDCLASS.

CLASS ltd_auth IMPLEMENTATION.
  METHOD zif_cd_ops_auth~is_allowed.
    rv_allowed = mv_allowed.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_prism_http DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_get TYPE string VALUE `GET`.

    TYPES:
      BEGIN OF ty_flags,
        get_method TYPE abap_bool,
      END OF ty_flags.

    DATA mo_request TYPE REF TO ltd_request.
    DATA mo_response TYPE REF TO ltd_response.

    METHODS setup.
    METHODS teardown.
    METHODS get_answers_405_with_allow FOR TESTING.
    METHODS refused_post_answers_403 FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act.
ENDCLASS.


CLASS ltc_prism_http IMPLEMENTATION.

  METHOD setup.
    mo_request  = NEW #( ).
    mo_response = NEW #( ).
    " the API is never authorised here: only answers decided before any read are reached
    zcl_cd_ops_injector=>inject_auth( NEW ltd_auth( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
    CLEAR: mo_request, mo_response.
  ENDMETHOD.


  METHOD configure_scenario.
    mo_request->mv_content_type = zif_cd_fmon_prism_types=>gc_content_type_json.
    mo_request->mv_method = COND #( WHEN is_flags-get_method = abap_true THEN gc_get
                                    ELSE zif_cd_fmon_prism_types=>gc_method_post ).
  ENDMETHOD.


  METHOD act.
    NEW zcl_cd_fmon_prism_http( )->if_http_extension~handle_request(
      NEW ltd_server( io_request = mo_request io_response = mo_response ) ).
  ENDMETHOD.


  " Rule: a method other than POST is 405 with header Allow: POST and a JSON body
  METHOD get_answers_405_with_allow.
    TRY.
        configure_scenario( VALUE #( get_method = abap_true ) ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_response->mv_code
                                            exp = zif_cd_fmon_prism_types=>gc_http-method_not_allowed
                                            msg = 'Status 405' ).
        cl_abap_unit_assert=>assert_equals( act = mo_response->mv_allow
                                            exp = zif_cd_fmon_prism_types=>gc_method_post
                                            msg = 'Allow header names POST' ).
        cl_abap_unit_assert=>assert_equals( act = mo_response->mv_content_type
                                            exp = zif_cd_fmon_prism_types=>gc_content_type_json
                                            msg = 'JSON answer' ).
        cl_abap_unit_assert=>assert_not_initial( act = mo_response->mv_body msg = 'Body written' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a refused caller gets 403 and no Allow header
  METHOD refused_post_answers_403.
    TRY.
        configure_scenario( VALUE #( ) ).
        act( ).
        cl_abap_unit_assert=>assert_equals( act = mo_response->mv_code
                                            exp = zif_cd_fmon_prism_types=>gc_http-forbidden
                                            msg = 'Status 403' ).
        cl_abap_unit_assert=>assert_initial( act = mo_response->mv_allow msg = 'No Allow header' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
