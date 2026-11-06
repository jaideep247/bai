*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_injector.clas.abap
*& Purpose:
*& Test injector for ZCL_CD_FMON_FACTORY (unit tests only; not FOR TESTING
*& so the factory can name it as GLOBAL FRIEND). Always reset( ) in
*& teardown. Plug-in check doubles go through ZCL_CD_OPS_INJECTOR.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - test injector for the factory</p>
CLASS zcl_cd_fmon_injector DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS inject_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_fmon_dao.

    CLASS-METHODS inject_ddic
      IMPORTING
        io_ddic TYPE REF TO zif_cd_fmon_ddic.

    CLASS-METHODS inject_calendar
      IMPORTING
        io_calendar TYPE REF TO zif_cd_fmon_calendar.

    CLASS-METHODS inject_lot_reader
      IMPORTING
        io_reader TYPE REF TO zif_cd_fmon_lot_reader.

    "! Replaces the generic adapter (sources with a blank adapter class)
    CLASS-METHODS inject_adapter
      IMPORTING
        io_adapter TYPE REF TO zif_cd_fmon_adapter.

    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_cd_fmon_injector IMPLEMENTATION.

  METHOD inject_dao.
    zcl_cd_fmon_factory=>go_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_ddic.
    zcl_cd_fmon_factory=>go_ddic_double = io_ddic.
  ENDMETHOD.


  METHOD inject_calendar.
    zcl_cd_fmon_factory=>go_calendar_double = io_calendar.
  ENDMETHOD.


  METHOD inject_lot_reader.
    zcl_cd_fmon_factory=>go_lot_reader_double = io_reader.
  ENDMETHOD.


  METHOD inject_adapter.
    zcl_cd_fmon_factory=>go_adapter_double = io_adapter.
  ENDMETHOD.


  METHOD reset.
    CLEAR: zcl_cd_fmon_factory=>go_dao_double,
           zcl_cd_fmon_factory=>go_ddic_double,
           zcl_cd_fmon_factory=>go_calendar_double,
           zcl_cd_fmon_factory=>go_lot_reader_double,
           zcl_cd_fmon_factory=>go_adapter_double.
  ENDMETHOD.

ENDCLASS.
