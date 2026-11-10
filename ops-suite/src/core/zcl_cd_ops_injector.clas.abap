*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_injector.clas.abap
*& Purpose:
*& Unit tests only (not FOR TESTING so the factory may name it as GLOBAL FRIEND).
*& Writes the private double slots of ZCL_CD_OPS_FACTORY; inject_params and
*& reset( ) also serve the framework factory ZCL_CA_OPS_FACTORY (parameters
*& are the framework adapter). Always call reset( ) in teardown.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | inject_trace_dao added (360 degree payment trace).
*& 2026-11-07 | inject_params added (runtime parameters).
*& 2026-11-07 | inject_pay_outcome / inject_pay_outcome_dao added (canonical payment outcome).
*& 2026-11-08 | inject_pay_snap_queue added (parallel packages of the outcome snapshot).
*& 2026-11-08 | inject_pay_request (payment request rule double).
*& 2026-11-10 | Framework slots moved to the reusable framework ZCA_OPS (ZCL_CA_OPS_INJECTOR); inject_params
*&            | writes the framework slot; reset( ) also resets the framework injector.
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
    "! Parameters of suite and framework (ZCL_CA_OPS_INJECTOR=>INJECT_PARAMS)
    CLASS-METHODS inject_params
      IMPORTING
        io_params TYPE REF TO zif_ca_ops_params.

    CLASS-METHODS inject_trace_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_ops_trace_dao.

    CLASS-METHODS inject_pay_outcome
      IMPORTING
        io_outcome TYPE REF TO zif_cd_ops_pay_outcome.

    CLASS-METHODS inject_pay_request
      IMPORTING
        io_request TYPE REF TO zif_cd_ops_pay_request.

    CLASS-METHODS inject_pay_outcome_dao
      IMPORTING
        io_dao TYPE REF TO zif_cd_ops_pay_outcome_dao.

    CLASS-METHODS inject_pay_snap_queue
      IMPORTING
        io_queue TYPE REF TO zif_cd_ops_pay_snap_queue.

    "! Clears the suite's slots and the framework's (ZCL_CA_OPS_INJECTOR=>RESET)
    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_cd_ops_injector IMPLEMENTATION.

  METHOD inject_params.
    zcl_ca_ops_injector=>inject_params( io_params ).
  ENDMETHOD.


  METHOD inject_trace_dao.
    zcl_cd_ops_factory=>go_trace_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_pay_outcome.
    zcl_cd_ops_factory=>go_pay_outcome_double = io_outcome.
  ENDMETHOD.


  METHOD inject_pay_request.
    zcl_cd_ops_factory=>go_pay_request_double = io_request.
  ENDMETHOD.


  METHOD inject_pay_outcome_dao.
    zcl_cd_ops_factory=>go_pay_outcome_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_pay_snap_queue.
    zcl_cd_ops_factory=>go_pay_snap_queue_double = io_queue.
  ENDMETHOD.


  METHOD reset.
    CLEAR: zcl_cd_ops_factory=>go_trace_dao_double,
           zcl_cd_ops_factory=>go_pay_outcome_double,
           zcl_cd_ops_factory=>go_pay_request_double,
           zcl_cd_ops_factory=>go_pay_outcome_dao_double,
           zcl_cd_ops_factory=>go_pay_snap_queue_double.
    zcl_ca_ops_injector=>reset( ).
  ENDMETHOD.

ENDCLASS.
