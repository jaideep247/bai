*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_factory.clas.abap
*& Purpose:
*& Single resolution point of the HCK data access object and engine;
*& test doubles are placed by ZCL_CD_HCK_INJECTOR.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - factory (DAO, engine)</p>
"! Getters never read the database.
CLASS zcl_cd_hck_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_cd_hck_injector.

  PUBLIC SECTION.

    CLASS-METHODS get_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_hck_dao.

    CLASS-METHODS get_engine
      RETURNING
        VALUE(ro_engine) TYPE REF TO zcl_cd_hck_engine.

  PRIVATE SECTION.

    CLASS-DATA go_dao_double TYPE REF TO zif_cd_hck_dao.

ENDCLASS.



CLASS zcl_cd_hck_factory IMPLEMENTATION.

  METHOD get_dao.
    ro_dao = COND #( WHEN go_dao_double IS BOUND THEN go_dao_double
                     ELSE NEW zcl_cd_hck_dao( ) ).
  ENDMETHOD.


  METHOD get_engine.
    ro_engine = NEW zcl_cd_hck_engine( ).
  ENDMETHOD.

ENDCLASS.
