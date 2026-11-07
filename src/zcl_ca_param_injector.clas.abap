*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_injector.clas.abap
*& Purpose:
*& Test seam of ZCL_CA_PARAM_FACTORY (global friend, FOR TESTING: usable
*& from test classes only). inject replaces the reader returned by get( );
*& inject_dao keeps the real logic and replaces only the data access (e.g.
*& ZCL_CA_PARAM_DAO_MEM); reset restores production behaviour - call it in
*& teardown. VERIFY-ADT: a FOR TESTING class as GLOBAL FRIENDS of a
*& productive class activates in DV1 (fallback: drop FOR TESTING).
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - injector for tests</p>
CLASS zcl_ca_param_injector DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  FOR TESTING.

  PUBLIC SECTION.
    "! get( ) returns io_param until reset
    CLASS-METHODS inject
      IMPORTING
        io_param TYPE REF TO zif_ca_param.

    "! get( ) returns a new real reader over io_dao until reset
    CLASS-METHODS inject_dao
      IMPORTING
        io_dao TYPE REF TO zif_ca_param_dao.

    "! Production behaviour again (also drops the session buffer)
    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_ca_param_injector IMPLEMENTATION.

  METHOD inject.
    zcl_ca_param_factory=>go_double = io_param.
  ENDMETHOD.


  METHOD inject_dao.
    zcl_ca_param_factory=>go_dao_double = io_dao.
    CLEAR zcl_ca_param_factory=>go_instance.
  ENDMETHOD.


  METHOD reset.
    CLEAR: zcl_ca_param_factory=>go_double,
           zcl_ca_param_factory=>go_dao_double,
           zcl_ca_param_factory=>go_instance.
  ENDMETHOD.

ENDCLASS.
