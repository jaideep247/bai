*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_pf_factory.clas.abap
*& Purpose:
*& Resolves the data access of the payment file lifecycle (pack
*& FICA_CASH, licence module CASH_OPS): the injected double, else
*& ZCL_CA_OPS_PF_DAO. Test doubles come from ZCL_CA_OPS_PF_INJECTOR. The
*& framework services (parameters, clock, licence, owner, evidence, plug-in
*& creation) stay with ZCL_CA_OPS_FACTORY, so no object of the core pack
*& names an object of this pack. The getter never reads the database.
*& Modification log:
*& 2026-11-16 | Initial version (merge of build K with the release packs: the payment file data access left the
*&            | core factory).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Payment file lifecycle - factory</p>
CLASS zcl_ca_ops_pf_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_ca_ops_pf_injector.

  PUBLIC SECTION.
    "! Data access of the payment file lifecycle (a new instance per call unless a double is injected)
    CLASS-METHODS get_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_ca_ops_pf_dao.

  PRIVATE SECTION.
    CLASS-DATA go_dao_double TYPE REF TO zif_ca_ops_pf_dao.

ENDCLASS.



CLASS zcl_ca_ops_pf_factory IMPLEMENTATION.

  METHOD get_dao.
    ro_dao = COND #( WHEN go_dao_double IS BOUND THEN go_dao_double
                     ELSE NEW zcl_ca_ops_pf_dao( ) ).
  ENDMETHOD.

ENDCLASS.
