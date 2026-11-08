*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_postarea_injector.clas.abap
*& Purpose:
*& Test injector of ZCL_CD_OPS_POSTAREA_FACTORY: a repository double (the
*& in-memory posting areas ZCL_CD_OPS_POSTAREA_MEM), so the real reader runs
*& (cache, FQC0 precedence, parameters); reset( ) clears the double and the
*& reader of the run (its cache).
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas ZRSN, ZPMC, ZBTM, ZBTR).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - customer posting areas: test injector</p>
CLASS zcl_cd_ops_postarea_injector DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! A repository double; the reader of the run is dropped so the next one reads the double
    CLASS-METHODS inject_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_ops_postarea_dao.

    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_cd_ops_postarea_injector IMPLEMENTATION.

  METHOD inject_dao.
    zcl_cd_ops_postarea_factory=>go_dao_double = io_dao.
    CLEAR zcl_cd_ops_postarea_factory=>go_reader.
  ENDMETHOD.


  METHOD reset.
    CLEAR: zcl_cd_ops_postarea_factory=>go_dao_double,
           zcl_cd_ops_postarea_factory=>go_reader.
  ENDMETHOD.

ENDCLASS.
