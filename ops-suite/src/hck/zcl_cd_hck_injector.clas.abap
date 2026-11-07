*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_injector.clas.abap
*& Purpose:
*& Test seam of the HCK factory: injects a DAO double; reset( ) clears it.
*& Used by ABAP Unit only (global friend of ZCL_CD_HCK_FACTORY).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-07 | inject_param_dao (ZCA_PARAM data access, e.g. ZCL_CA_PARAM_DAO_MEM).
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

    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_cd_hck_injector IMPLEMENTATION.

  METHOD inject_dao.
    zcl_cd_hck_factory=>go_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_param_dao.
    zcl_cd_hck_factory=>go_param_dao_double = io_dao.
  ENDMETHOD.


  METHOD reset.
    CLEAR: zcl_cd_hck_factory=>go_dao_double,
           zcl_cd_hck_factory=>go_param_dao_double.
  ENDMETHOD.

ENDCLASS.
