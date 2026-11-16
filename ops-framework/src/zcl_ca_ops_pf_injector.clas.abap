*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_injector.clas.abap
*& Purpose:
*& Test injector of the payment file lifecycle: writes the double slot of
*& ZCL_CA_OPS_PF_FACTORY; RESET clears it and every slot of the
*& framework's injector. Unit tests only (not FOR TESTING so the factory
*& may name it as GLOBAL FRIEND). Always call reset( ) in teardown.
*& Modification log:
*& 2026-11-16 | Initial version (merge of build K with the release packs).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment file lifecycle - test injector</p>
CLASS zcl_ca_ops_pf_injector DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS inject_dao
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_pf_dao.

    "! Clears the payment file slot and every slot of the framework's injector
    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_ca_ops_pf_injector IMPLEMENTATION.

  METHOD inject_dao.
    zcl_ca_ops_pf_factory=>go_dao_double = io_dao.
  ENDMETHOD.


  METHOD reset.
    CLEAR zcl_ca_ops_pf_factory=>go_dao_double.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.

ENDCLASS.
