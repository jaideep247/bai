*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cash_injector.clas.abap
*& Purpose:
*& Unit tests only (not FOR TESTING so the factory may name it as GLOBAL
*& FRIEND): writes the double slot of ZCL_CA_OPS_CASH_FACTORY. RESET also
*& resets the framework's injector (ZCL_CA_OPS_INJECTOR), so one call in a
*& teardown clears every slot a cash test filled.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*& 2026-11-16 | INJECT_MA_DAO: the mass activity check's data access (build P).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash operations - test injector</p>
CLASS zcl_ca_ops_cash_injector DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS inject_dao
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_cash_dao.

    "! Data access of the mass activity check (build P)
    CLASS-METHODS inject_ma_dao
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_ma_dao.

    "! Clears the cash slot and every slot of the framework's injector
    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_ca_ops_cash_injector IMPLEMENTATION.

  METHOD inject_dao.
    zcl_ca_ops_cash_factory=>go_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_ma_dao.
    zcl_ca_ops_cash_factory=>go_ma_dao_double = io_dao.
  ENDMETHOD.


  METHOD reset.
    CLEAR: zcl_ca_ops_cash_factory=>go_dao_double, zcl_ca_ops_cash_factory=>go_ma_dao_double.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.

ENDCLASS.
