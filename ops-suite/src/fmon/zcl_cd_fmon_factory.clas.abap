*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_fmon_factory.clas.abap
*& Purpose:
*& FMON factory: single resolution point for the DAO, DDIC describer,
*& calendar, lot reader, adapters, plug-in checks and the engine. Test
*& doubles are written into its private slots by ZCL_CD_FMON_INJECTOR.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Adapter and check plug-ins created with the core interface check (audit A62).
*& 2026-11-06 | get_prism_dao( ), get_prism_queue( ) for the PRISM status API.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">File monitoring - factory</p>
"! Getters have no side effects and never read the database.
CLASS zcl_cd_fmon_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_cd_fmon_injector.

  PUBLIC SECTION.

    CLASS-METHODS get_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_fmon_dao.

    CLASS-METHODS get_ddic
      RETURNING
        VALUE(ro_ddic) TYPE REF TO zif_cd_fmon_ddic.

    CLASS-METHODS get_calendar
      RETURNING
        VALUE(ro_calendar) TYPE REF TO zif_cd_fmon_calendar.

    CLASS-METHODS get_lot_reader
      RETURNING
        VALUE(ro_reader) TYPE REF TO zif_cd_fmon_lot_reader.

    "! Blank class name = generic adapter; otherwise a configured plug-in
    "! @raising zcx_cd_ops_error | class missing or not a ZIF_CD_FMON_ADAPTER
    CLASS-METHODS get_adapter
      IMPORTING
        iv_class_name     TYPE zif_cd_ops_types=>ty_class_name OPTIONAL
      RETURNING
        VALUE(ro_adapter) TYPE REF TO zif_cd_fmon_adapter
      RAISING
        zcx_cd_ops_error.

    "! @raising zcx_cd_ops_error | class missing or not a ZIF_CD_FMON_CHECK
    CLASS-METHODS get_check
      IMPORTING
        iv_class_name   TYPE zif_cd_ops_types=>ty_class_name
      RETURNING
        VALUE(ro_check) TYPE REF TO zif_cd_fmon_check
      RAISING
        zcx_cd_ops_error.

    CLASS-METHODS get_engine
      RETURNING
        VALUE(ro_engine) TYPE REF TO zcl_cd_fmon_engine.

    "! Repository of the PRISM status API (ZCD_FMON_PRISM)
    CLASS-METHODS get_prism_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_fmon_prism_dao.

    "! Queue of the instant processing of a PRISM event (bgPF)
    CLASS-METHODS get_prism_queue
      RETURNING
        VALUE(ro_queue) TYPE REF TO zif_cd_fmon_prism_queue.

  PRIVATE SECTION.
    CLASS-DATA go_prism_queue_double TYPE REF TO zif_cd_fmon_prism_queue.
    CLASS-DATA go_prism_dao_double TYPE REF TO zif_cd_fmon_prism_dao.
    CLASS-DATA go_dao_double TYPE REF TO zif_cd_fmon_dao.
    CLASS-DATA go_ddic_double TYPE REF TO zif_cd_fmon_ddic.
    CLASS-DATA go_calendar_double TYPE REF TO zif_cd_fmon_calendar.
    CLASS-DATA go_lot_reader_double TYPE REF TO zif_cd_fmon_lot_reader.
    CLASS-DATA go_adapter_double TYPE REF TO zif_cd_fmon_adapter.

ENDCLASS.



CLASS zcl_cd_fmon_factory IMPLEMENTATION.

  METHOD get_dao.
    ro_dao = COND #( WHEN go_dao_double IS BOUND THEN go_dao_double
                     ELSE NEW zcl_cd_fmon_dao( ) ).
  ENDMETHOD.


  METHOD get_ddic.
    ro_ddic = COND #( WHEN go_ddic_double IS BOUND THEN go_ddic_double
                      ELSE NEW zcl_cd_fmon_ddic( ) ).
  ENDMETHOD.


  METHOD get_calendar.
    ro_calendar = COND #( WHEN go_calendar_double IS BOUND THEN go_calendar_double
                          ELSE NEW zcl_cd_fmon_calendar( ) ).
  ENDMETHOD.


  METHOD get_lot_reader.
    ro_reader = COND #( WHEN go_lot_reader_double IS BOUND THEN go_lot_reader_double
                        ELSE NEW zcl_cd_fmon_lot_reader( ) ).
  ENDMETHOD.


  METHOD get_adapter.
    IF iv_class_name IS INITIAL.
      ro_adapter = COND #( WHEN go_adapter_double IS BOUND THEN go_adapter_double
                           ELSE NEW zcl_cd_fmon_adapter_generic( ) ).
      RETURN.
    ENDIF.
    " A62: the core factory checks the interface by RTTI before CREATE OBJECT
    DATA(lo_object) = zcl_cd_ops_factory=>get_plugin(
                        iv_class_name = iv_class_name
                        iv_interface  = zif_cd_fmon_types=>gc_plugin_interface-adapter ).
    TRY.
        ro_adapter ?= lo_object.
      CATCH cx_sy_move_cast_error.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e032(zcd_ops) WITH iv_class_name zif_cd_fmon_types=>gc_plugin_interface-adapter.
    ENDTRY.
  ENDMETHOD.


  METHOD get_check.
    DATA(lo_object) = zcl_cd_ops_factory=>get_plugin(
                        iv_class_name = iv_class_name
                        iv_interface  = zif_cd_fmon_types=>gc_plugin_interface-check ).
    TRY.
        ro_check ?= lo_object.
      CATCH cx_sy_move_cast_error.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e032(zcd_ops) WITH iv_class_name zif_cd_fmon_types=>gc_plugin_interface-check.
    ENDTRY.
  ENDMETHOD.


  METHOD get_engine.
    ro_engine = NEW zcl_cd_fmon_engine( ).
  ENDMETHOD.


  METHOD get_prism_dao.
    ro_dao = COND #( WHEN go_prism_dao_double IS BOUND THEN go_prism_dao_double
                     ELSE NEW zcl_cd_fmon_prism_dao( ) ).
  ENDMETHOD.


  METHOD get_prism_queue.
    ro_queue = COND #( WHEN go_prism_queue_double IS BOUND THEN go_prism_queue_double
                       ELSE NEW zcl_cd_fmon_prism_queue( ) ).
  ENDMETHOD.

ENDCLASS.
