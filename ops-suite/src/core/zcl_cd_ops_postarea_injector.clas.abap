*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_postarea_injector.clas.abap
*& Purpose:
*& Test injector of ZCL_CD_OPS_POSTAREA_FACTORY: repository doubles (the
*& in-memory mappings ZCL_CD_OPS_POSTAREA_MEM serve both sources), so the
*& real reader runs (cache, source, version, FQC0 precedence, parameters);
*& reset( ) clears the doubles and the reader of the run (its cache).
*& Modification log:
*& 2026-11-08 | Initial version (customer posting areas ZRSN, ZPMC, ZBTM, ZBTR).
*& 2026-11-15 | Typed table repository: INJECT_DAO also injects a double that serves both sources;
*&            | INJECT_TYPED_DAO; RENEW_READER (a new run: the reader reads again).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - customer posting areas: test injector</p>
CLASS zcl_cd_ops_postarea_injector DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! A repository double; the reader of the run is dropped so the next one reads the double. A
    "! double that is also a typed table repository (ZCL_CD_OPS_POSTAREA_MEM) serves source T too.
    CLASS-METHODS inject_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_ops_postarea_dao.

    "! A typed table repository double (source T); the reader of the run is dropped
    CLASS-METHODS inject_typed_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_ops_pamap_dao.

    "! The reader of the run is dropped (as at the start of the next run; doubles kept)
    CLASS-METHODS renew_reader.

    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_cd_ops_postarea_injector IMPLEMENTATION.

  METHOD inject_dao.
    zcl_cd_ops_postarea_factory=>go_dao_double = io_dao.
    IF io_dao IS INSTANCE OF zif_cd_ops_pamap_dao.
      zcl_cd_ops_postarea_factory=>go_typed_double = CAST #( io_dao ).
    ENDIF.
    CLEAR zcl_cd_ops_postarea_factory=>go_reader.
  ENDMETHOD.


  METHOD inject_typed_dao.
    zcl_cd_ops_postarea_factory=>go_typed_double = io_dao.
    CLEAR zcl_cd_ops_postarea_factory=>go_reader.
  ENDMETHOD.


  METHOD renew_reader.
    CLEAR zcl_cd_ops_postarea_factory=>go_reader.
  ENDMETHOD.


  METHOD reset.
    CLEAR: zcl_cd_ops_postarea_factory=>go_dao_double,
           zcl_cd_ops_postarea_factory=>go_typed_double,
           zcl_cd_ops_postarea_factory=>go_reader.
  ENDMETHOD.

ENDCLASS.
