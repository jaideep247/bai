*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_prism_http.clas.abap
*& Purpose:
*& ICF handler of the PRISM status API (SICF node /sap/zcd_ops/prism_status,
*& inactive until CAB approval). Thin: copies method, content type and body
*& to ZCL_CD_FMON_PRISM_API and writes its status and JSON answer back.
*& Deliberately not unit tested (it only moves data across the ICF boundary);
*& every decision is tested in ZCL_CD_FMON_PRISM_API / _EVENT / _DAO.
*& Modification log:
*& 2026-11-06 | Initial version (PRISM status API, user decision 2026-11-06).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FMON PRISM status API - ICF handler (REST JSON)</p>
"! Plain REST JSON over HTTPS, no OData, no CSRF token (machine-to-machine call of a
"! technical user; SICF logon and S_ICF restrict the caller - docs/PRISM_Status_API.md).
CLASS zcl_cd_fmon_prism_http DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES if_http_extension.

ENDCLASS.



CLASS zcl_cd_fmon_prism_http IMPLEMENTATION.

  METHOD if_http_extension~handle_request.
    DATA(ls_response) = NEW zcl_cd_fmon_prism_api( )->handle(
                          VALUE #( method       = server->request->get_method( )
                                   content_type = server->request->get_content_type( )
                                   body         = server->request->get_data( ) ) ).

    server->response->set_status( code   = ls_response-status_code
                                  reason = CONV #( ls_response-status ) ).
    server->response->set_content_type( zif_cd_fmon_prism_types=>gc_content_type_json ).
    IF ls_response-status_code = zif_cd_fmon_prism_types=>gc_http-method_not_allowed.
      server->response->set_header_field( name  = zif_cd_fmon_prism_types=>gc_header_allow
                                          value = zif_cd_fmon_prism_types=>gc_method_post ).
    ENDIF.
    server->response->set_cdata( ls_response-body ).
  ENDMETHOD.

ENDCLASS.
