*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_factory.clas.abap
*& Purpose:
*& Resolves the shared services of the payment engine suite (payment trace,
*& payment outcome, payment requests, outcome snapshot repository and queue,
*& pattern repository) and the runtime parameters with the suite's area
*& prefixes. Framework services (store, alert router, clock, authorisation,
*& lock, purge, plug-ins) come from ZCL_CA_OPS_FACTORY. Test doubles come
*& from ZCL_CD_OPS_INJECTOR. Getters never read the database.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Payment trace read repository seam added (360 degree payment trace).
*& 2026-11-06 | Pattern check / migration repository seam added (PCRE patterns).
*& 2026-11-07 | get_params: the session adapter over ZCA_PARAM (store serves no parameters).
*& 2026-11-07 | get_pay_outcome (canonical payment outcome evaluator), get_pay_outcome_dao (snapshot SQL).
*& 2026-11-08 | get_pay_snap_queue (bgPF units of the parallel outcome snapshot packages).
*& 2026-11-08 | get_pay_request (due date and stage of payment requests: worklist and payment trace).
*& 2026-11-10 | Framework services moved to the reusable framework ZCA_OPS (ZCL_CA_OPS_FACTORY); get_params
*&            | returns the framework adapter with the suite's name prefixes (areas CD_OPS, CD_EBS,
*&            | CD_FMON, CD_HCK) added.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - core factory</p>
"! Single resolution point for the suite's shared services. Framework services come
"! from ZCL_CA_OPS_FACTORY. Test doubles are written by ZCL_CD_OPS_INJECTOR.
"! Construction has no side effects: getters never read the database.
CLASS zcl_cd_ops_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_cd_ops_injector.

  PUBLIC SECTION.

    "! Runtime parameters of the suite: the framework's session adapter (or its injected double)
    "! with the name prefixes of the suite's areas (ZIF_CD_OPS_TYPES=>GC_PARAM_AREA_PREFIX)
    CLASS-METHODS get_params
      RETURNING
        VALUE(ro_params) TYPE REF TO zif_ca_ops_params.

    "! Name prefix -> parameter area of the suite (added to the framework adapter)
    CLASS-METHODS param_prefixes
      RETURNING
        VALUE(rt_prefixes) TYPE zif_ca_ops_types=>tt_param_prefix.

    "! Read repository of the payment trace (read-only)
    CLASS-METHODS get_trace_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ops_trace_dao.

    "! Canonical payment outcome evaluator (a new instance per call: one per run)
    CLASS-METHODS get_pay_outcome
      RETURNING
        VALUE(ro_outcome) TYPE REF TO zif_cd_ops_pay_outcome.

    "! Due date and stage of payment requests (one rule: worklist and payment trace)
    CLASS-METHODS get_pay_request
      RETURNING
        VALUE(ro_request) TYPE REF TO zif_cd_ops_pay_request.

    "! Repository of the payment outcome snapshot (versions, watermarks, changed documents)
    CLASS-METHODS get_pay_outcome_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ops_pay_outcome_dao.

    "! bgPF queue of the parallel packages of the payment outcome snapshot
    CLASS-METHODS get_pay_snap_queue
      RETURNING
        VALUE(ro_queue) TYPE REF TO zif_cd_ops_pay_snap_queue.

    "! Repository of the pattern check and the pattern migration
    CLASS-METHODS get_pattern_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ops_pattern_dao.

  PRIVATE SECTION.
    CLASS-DATA go_trace_dao_double TYPE REF TO zif_cd_ops_trace_dao.
    CLASS-DATA go_pay_outcome_double TYPE REF TO zif_cd_ops_pay_outcome.
    CLASS-DATA go_pay_request_double TYPE REF TO zif_cd_ops_pay_request.
    CLASS-DATA go_pay_outcome_dao_double TYPE REF TO zif_cd_ops_pay_outcome_dao.
    CLASS-DATA go_pay_snap_queue_double TYPE REF TO zif_cd_ops_pay_snap_queue.

ENDCLASS.



CLASS zcl_cd_ops_factory IMPLEMENTATION.

  METHOD get_params.
    ro_params = zcl_ca_ops_factory=>get_params( ).
    ro_params->add_prefixes( param_prefixes( ) ).
  ENDMETHOD.


  METHOD param_prefixes.
    rt_prefixes = VALUE #(
      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-trace    area = zif_cd_ops_types=>gc_param_area-ops )
      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-payout   area = zif_cd_ops_types=>gc_param_area-ops )
      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-monitor  area = zif_cd_ops_types=>gc_param_area-ops )
      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-postarea area = zif_cd_ops_types=>gc_param_area-ops )
      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-ebs      area = zif_cd_ops_types=>gc_param_area-ebs )
      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-fmon     area = zif_cd_ops_types=>gc_param_area-fmon )
      ( prefix = zif_cd_ops_types=>gc_param_area_prefix-hck      area = zif_cd_ops_types=>gc_param_area-hck ) ).
  ENDMETHOD.


  METHOD get_trace_dao.
    ro_dao = COND #( WHEN go_trace_dao_double IS BOUND THEN go_trace_dao_double
                     ELSE NEW zcl_cd_ops_trace_dao( ) ).
  ENDMETHOD.


  METHOD get_pay_outcome.
    ro_outcome = COND #( WHEN go_pay_outcome_double IS BOUND THEN go_pay_outcome_double
                         ELSE NEW zcl_cd_ops_pay_outcome( ) ).
  ENDMETHOD.


  METHOD get_pay_request.
    ro_request = COND #( WHEN go_pay_request_double IS BOUND THEN go_pay_request_double
                         ELSE NEW zcl_cd_ops_pay_request( ) ).
  ENDMETHOD.


  METHOD get_pay_outcome_dao.
    ro_dao = COND #( WHEN go_pay_outcome_dao_double IS BOUND THEN go_pay_outcome_dao_double
                     ELSE NEW zcl_cd_ops_pay_outcome_dao( ) ).
  ENDMETHOD.


  METHOD get_pay_snap_queue.
    ro_queue = COND #( WHEN go_pay_snap_queue_double IS BOUND THEN go_pay_snap_queue_double
                       ELSE NEW zcl_cd_ops_pay_snap_queue( ) ).
  ENDMETHOD.


  METHOD get_pattern_dao.
    ro_dao = NEW zcl_cd_ops_pattern_dao( ).
  ENDMETHOD.

ENDCLASS.
