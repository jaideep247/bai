*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_postarea_factory.clas.abap
*& Purpose:
*& Factory of the customer posting area reader: one reader per internal
*& session (= one run of a batch program), so each posting area is read
*& once per run and every consumer shares the cache; the repositories
*& (TFK033D posting areas, ZCD_OPS_MAP* typed tables). Test doubles through
*& ZCL_CD_OPS_POSTAREA_INJECTOR.
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas ZRSN, ZPMC, ZBTM, ZBTR).
*& 2026-11-15 | GET_TYPED_DAO: repository of the typed product mapping tables (source T).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - customer posting areas: factory</p>
CLASS zcl_cd_ops_postarea_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_cd_ops_postarea_injector.

  PUBLIC SECTION.
    "! The reader of this run (created once; reads through the repository double when injected)
    CLASS-METHODS get_reader
      RETURNING
        VALUE(ro_reader) TYPE REF TO zif_cd_ops_postarea.

    CLASS-METHODS get_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ops_postarea_dao.

    "! Repository of the typed product mapping tables (source T)
    CLASS-METHODS get_typed_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ops_pamap_dao.

  PRIVATE SECTION.
    CLASS-DATA go_dao_double    TYPE REF TO zif_cd_ops_postarea_dao.
    CLASS-DATA go_typed_double  TYPE REF TO zif_cd_ops_pamap_dao.
    "! The reader of the run (its cache holds the entries read)
    CLASS-DATA go_reader        TYPE REF TO zif_cd_ops_postarea.

ENDCLASS.



CLASS zcl_cd_ops_postarea_factory IMPLEMENTATION.

  METHOD get_reader.
    IF go_reader IS NOT BOUND.
      go_reader = NEW zcl_cd_ops_postarea( ).
    ENDIF.
    ro_reader = go_reader.
  ENDMETHOD.


  METHOD get_dao.
    ro_dao = COND #( WHEN go_dao_double IS BOUND THEN go_dao_double
                     ELSE NEW zcl_cd_ops_postarea_dao( ) ).
  ENDMETHOD.


  METHOD get_typed_dao.
    ro_dao = COND #( WHEN go_typed_double IS BOUND THEN go_typed_double
                     ELSE NEW zcl_cd_ops_pamap_dao( ) ).
  ENDMETHOD.

ENDCLASS.
