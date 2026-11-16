*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cash_factory.clas.abap
*& Purpose:
*& Resolves the data access of the FI-CA cash operations checks (package
*& ZCA_OPS_CASH): the injected double, else ZCL_CA_OPS_CASH_DAO. Test
*& doubles come from ZCL_CA_OPS_CASH_INJECTOR. The framework services
*& (parameters, catalogue, clock) stay with ZCL_CA_OPS_FACTORY. The getter
*& never reads the database.
*& Modification log:
*& 2026-11-15 | Initial version (build N: FI-CA cash coverage).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">FI-CA cash operations - factory</p>
CLASS zcl_ca_ops_cash_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_ca_ops_cash_injector.

  PUBLIC SECTION.
    "! Data access of the cash checks (a new instance per call unless a double is injected)
    CLASS-METHODS get_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_ca_ops_cash_dao.

  PRIVATE SECTION.
    CLASS-DATA go_dao_double TYPE REF TO zif_ca_ops_cash_dao.

ENDCLASS.



CLASS zcl_ca_ops_cash_factory IMPLEMENTATION.

  METHOD get_dao.
    ro_dao = COND #( WHEN go_dao_double IS BOUND THEN go_dao_double
                     ELSE NEW zcl_ca_ops_cash_dao( ) ).
  ENDMETHOD.

ENDCLASS.
