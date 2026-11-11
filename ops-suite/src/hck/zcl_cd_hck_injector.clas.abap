*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_injector.clas.abap
*& Purpose:
*& Test seam of the HCK factory: injects a DAO double; reset( ) clears it.
*& Used by ABAP Unit only (global friend of ZCL_CD_HCK_FACTORY).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-07 | inject_param_dao (ZCA_PARAM data access, e.g. ZCL_CA_PARAM_DAO_MEM).
*& 2026-11-07 | inject_runtime_dao (reads of E_NUMRANGE, E_QUEUES, A_INFLIGHT).
*& 2026-11-07 | inject_recon_dao (reads of the three-way reconciliation A_RECON_3WAY).
*& 2026-11-11 | inject_docchg_dao (reads of the document-change risk check A_DOC_CHANGE, build C).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - test injector for the HCK factory</p>
"! Always call reset( ) in teardown.
CLASS zcl_cd_hck_injector DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS inject_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_hck_dao.

    "! Data access of the parameter framework (e.g. ZCL_CA_PARAM_DAO_MEM)
    CLASS-METHODS inject_param_dao
      IMPORTING
        io_dao TYPE REF TO zif_ca_param_dao.

    "! Reads of the runtime checks (number ranges, queues, payments in flight)
    CLASS-METHODS inject_runtime_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_hck_runtime_dao.

    "! Reads of the three-way reconciliation check
    CLASS-METHODS inject_recon_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_hck_recon_dao.

    "! Reads of the document-change risk check
    CLASS-METHODS inject_docchg_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_hck_docchg_dao.

    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_cd_hck_injector IMPLEMENTATION.

  METHOD inject_dao.
    zcl_cd_hck_factory=>go_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_param_dao.
    zcl_cd_hck_factory=>go_param_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_runtime_dao.
    zcl_cd_hck_factory=>go_runtime_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_recon_dao.
    zcl_cd_hck_factory=>go_recon_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_docchg_dao.
    zcl_cd_hck_factory=>go_docchg_dao_double = io_dao.
  ENDMETHOD.


  METHOD reset.
    CLEAR: zcl_cd_hck_factory=>go_dao_double,
           zcl_cd_hck_factory=>go_param_dao_double,
           zcl_cd_hck_factory=>go_runtime_dao_double,
           zcl_cd_hck_factory=>go_recon_dao_double,
           zcl_cd_hck_factory=>go_docchg_dao_double.
  ENDMETHOD.

ENDCLASS.
