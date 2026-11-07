*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_factory.clas.abap
*& Purpose:
*& Entry point of the parameter framework: get( ) returns the session-wide
*& instance of ZIF_CA_PARAM (ZCL_CA_PARAM over ZCL_CA_PARAM_DAO, one buffer
*& per internal session). Tests replace the instance or the DAO through
*& ZCL_CA_PARAM_INJECTOR (global friend). No logic.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - factory</p>
CLASS zcl_ca_param_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_ca_param_injector.

  PUBLIC SECTION.
    "! The parameter reader of this session (a test double when one is injected)
    CLASS-METHODS get
      RETURNING
        VALUE(ro_param) TYPE REF TO zif_ca_param.

  PRIVATE SECTION.
    CLASS-DATA go_instance   TYPE REF TO zif_ca_param.
    CLASS-DATA go_double     TYPE REF TO zif_ca_param.
    CLASS-DATA go_dao_double TYPE REF TO zif_ca_param_dao.

ENDCLASS.



CLASS zcl_ca_param_factory IMPLEMENTATION.

  METHOD get.
    IF go_double IS BOUND.
      ro_param = go_double.
      RETURN.
    ENDIF.
    IF go_instance IS NOT BOUND.
      go_instance = NEW zcl_ca_param( io_dao = COND #( WHEN go_dao_double IS BOUND
                                                       THEN go_dao_double
                                                       ELSE NEW zcl_ca_param_dao( ) ) ).
    ENDIF.
    ro_param = go_instance.
  ENDMETHOD.

ENDCLASS.
