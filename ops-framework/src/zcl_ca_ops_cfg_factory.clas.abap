*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cfg_factory.clas.abap
*& Purpose:
*& Resolves the gate of the configuration apps and its seams (T000 / E070
*& reader, transport recorder, authorisation). Test doubles come from
*& ZCL_CA_OPS_CFG_INJECTOR. Getters never read the database.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - config apps: factory</p>
CLASS zcl_ca_ops_cfg_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_ca_ops_cfg_injector.

  PUBLIC SECTION.
    "! New gate per call; it reads the client settings once, on first use
    CLASS-METHODS get_gate
      RETURNING
        VALUE(ro_gate) TYPE REF TO zcl_ca_ops_cfg_gate.

    CLASS-METHODS get_client
      RETURNING
        VALUE(ro_client) TYPE REF TO zif_ca_ops_cfg_client.

    CLASS-METHODS get_transport
      RETURNING
        VALUE(ro_transport) TYPE REF TO zif_ca_ops_cfg_transport.

    CLASS-METHODS get_auth
      RETURNING
        VALUE(ro_auth) TYPE REF TO zif_ca_ops_cfg_auth.

  PRIVATE SECTION.
    CLASS-DATA go_client_double    TYPE REF TO zif_ca_ops_cfg_client.
    CLASS-DATA go_transport_double TYPE REF TO zif_ca_ops_cfg_transport.
    CLASS-DATA go_auth_double      TYPE REF TO zif_ca_ops_cfg_auth.

ENDCLASS.



CLASS zcl_ca_ops_cfg_factory IMPLEMENTATION.

  METHOD get_gate.
    ro_gate = NEW #( ).
  ENDMETHOD.


  METHOD get_client.
    ro_client = COND #( WHEN go_client_double IS BOUND THEN go_client_double
                        ELSE NEW zcl_ca_ops_cfg_client( ) ).
  ENDMETHOD.


  METHOD get_transport.
    ro_transport = COND #( WHEN go_transport_double IS BOUND THEN go_transport_double
                           ELSE NEW zcl_ca_ops_cfg_transport( ) ).
  ENDMETHOD.


  METHOD get_auth.
    ro_auth = COND #( WHEN go_auth_double IS BOUND THEN go_auth_double
                      ELSE NEW zcl_ca_ops_cfg_auth( ) ).
  ENDMETHOD.

ENDCLASS.
