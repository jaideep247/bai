*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_cfg_injector.clas.abap
*& Purpose:
*& Unit tests only: writes the double slots of ZCL_CD_OPS_CFG_FACTORY. Always
*& call reset( ) in teardown. Not FOR TESTING so the factory can name it
*& GLOBAL FRIEND.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - config apps: test injector</p>
CLASS zcl_cd_ops_cfg_injector DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS inject_client
      IMPORTING
        io_client TYPE REF TO zif_cd_ops_cfg_client.

    CLASS-METHODS inject_transport
      IMPORTING
        io_transport TYPE REF TO zif_cd_ops_cfg_transport.

    CLASS-METHODS inject_auth
      IMPORTING
        io_auth TYPE REF TO zif_cd_ops_cfg_auth.

    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_cd_ops_cfg_injector IMPLEMENTATION.

  METHOD inject_client.
    zcl_cd_ops_cfg_factory=>go_client_double = io_client.
  ENDMETHOD.


  METHOD inject_transport.
    zcl_cd_ops_cfg_factory=>go_transport_double = io_transport.
  ENDMETHOD.


  METHOD inject_auth.
    zcl_cd_ops_cfg_factory=>go_auth_double = io_auth.
  ENDMETHOD.


  METHOD reset.
    CLEAR: zcl_cd_ops_cfg_factory=>go_client_double,
           zcl_cd_ops_cfg_factory=>go_transport_double,
           zcl_cd_ops_cfg_factory=>go_auth_double.
  ENDMETHOD.

ENDCLASS.
