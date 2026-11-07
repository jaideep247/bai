*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_injector.clas.abap
*& Purpose:
*& Unit tests only (not FOR TESTING so the factory may name it as GLOBAL FRIEND).
*& Writes the private double slots of ZCL_CD_OPS_FACTORY.
*& Always call reset( ) in teardown.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | inject_auth added.
*& 2026-11-06 | inject_lock added.
*& 2026-11-06 | inject_purge_dao added.
*& 2026-11-06 | inject_exc_dao added (operations apps).
*& 2026-11-06 | inject_trace_dao added (360 degree payment trace).
*& 2026-11-06 | inject_pattern_dao added (PCRE patterns: pattern check and migration).
*& 2026-11-07 | inject_params added (runtime parameters, ZIF_CD_OPS_PARAMS).
*& 2026-11-07 | inject_exc_dao / inject_pattern_dao removed: no test used them (lean scope).
*& 2026-11-07 | reset also drops the session parameter adapter (ZCA_PARAM).
*& 2026-11-07 | inject_pay_outcome / inject_pay_outcome_dao added (canonical payment outcome).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - test injector for the core factory</p>
"! Unit tests only (not FOR TESTING so the factory may name it as GLOBAL FRIEND).
"! Writes the private double slots of ZCL_CD_OPS_FACTORY.
"! Always call reset( ) in teardown.
CLASS zcl_cd_ops_injector DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS inject_store
      IMPORTING
        io_store TYPE REF TO zif_cd_ops_store.

    "! Parameters (e.g. ZCL_CD_OPS_PARAM_SEED->PARAMS( ): the adapter over the real framework logic
    "! and in-memory definitions); without it get_params returns the adapter over ZCA_PARAM
    CLASS-METHODS inject_params
      IMPORTING
        io_params TYPE REF TO zif_cd_ops_params.

    CLASS-METHODS inject_alert
      IMPORTING
        io_alert TYPE REF TO zif_cd_ops_alert.

    CLASS-METHODS inject_clock
      IMPORTING
        io_clock TYPE REF TO zif_cd_ops_clock.

    CLASS-METHODS inject_alert_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_ops_alert_dao.

    CLASS-METHODS inject_auth
      IMPORTING
        io_auth TYPE REF TO zif_cd_ops_auth.

    CLASS-METHODS inject_lock
      IMPORTING
        io_lock TYPE REF TO zif_cd_ops_lock.

    CLASS-METHODS inject_purge_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_ops_purge_dao.

    CLASS-METHODS inject_trace_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_ops_trace_dao.

    CLASS-METHODS inject_pay_outcome
      IMPORTING
        io_outcome TYPE REF TO zif_cd_ops_pay_outcome.

    CLASS-METHODS inject_pay_outcome_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_ops_pay_outcome_dao.

    CLASS-METHODS inject_plugin
      IMPORTING
        iv_class_name TYPE zif_cd_ops_types=>ty_class_name
        io_instance   TYPE REF TO object.

    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_cd_ops_injector IMPLEMENTATION.

  METHOD inject_store.
    zcl_cd_ops_factory=>go_store_double = io_store.
  ENDMETHOD.


  METHOD inject_params.
    zcl_cd_ops_factory=>go_params_double = io_params.
  ENDMETHOD.


  METHOD inject_alert.
    zcl_cd_ops_factory=>go_alert_double = io_alert.
  ENDMETHOD.


  METHOD inject_clock.
    zcl_cd_ops_factory=>go_clock_double = io_clock.
  ENDMETHOD.


  METHOD inject_alert_dao.
    zcl_cd_ops_factory=>go_alert_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_auth.
    zcl_cd_ops_factory=>go_auth_double = io_auth.
  ENDMETHOD.


  METHOD inject_lock.
    zcl_cd_ops_factory=>go_lock_double = io_lock.
  ENDMETHOD.


  METHOD inject_purge_dao.
    zcl_cd_ops_factory=>go_purge_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_trace_dao.
    zcl_cd_ops_factory=>go_trace_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_pay_outcome.
    zcl_cd_ops_factory=>go_pay_outcome_double = io_outcome.
  ENDMETHOD.


  METHOD inject_pay_outcome_dao.
    zcl_cd_ops_factory=>go_pay_outcome_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_plugin.
    DATA(lv_name) = to_upper( condense( CONV string( iv_class_name ) ) ).
    DELETE zcl_cd_ops_factory=>gt_plugin_double
      WHERE class_name = CONV zif_cd_ops_types=>ty_class_name( lv_name ).
    INSERT VALUE #( class_name = lv_name
                    instance   = io_instance ) INTO TABLE zcl_cd_ops_factory=>gt_plugin_double.
  ENDMETHOD.


  METHOD reset.
    CLEAR: zcl_cd_ops_factory=>go_store_double,
           zcl_cd_ops_factory=>go_params_double,
           zcl_cd_ops_factory=>go_alert_double,
           zcl_cd_ops_factory=>go_clock_double,
           zcl_cd_ops_factory=>go_alert_dao_double,
           zcl_cd_ops_factory=>go_auth_double,
           zcl_cd_ops_factory=>go_lock_double,
           zcl_cd_ops_factory=>go_purge_dao_double,
           zcl_cd_ops_factory=>go_trace_dao_double,
           zcl_cd_ops_factory=>go_pay_outcome_double,
           zcl_cd_ops_factory=>go_pay_outcome_dao_double,
           zcl_cd_ops_factory=>gt_plugin_double,
           zcl_cd_ops_factory=>go_store,
           zcl_cd_ops_factory=>go_params.
  ENDMETHOD.

ENDCLASS.
