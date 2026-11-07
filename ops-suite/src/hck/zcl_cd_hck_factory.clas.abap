*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_factory.clas.abap
*& Purpose:
*& Single resolution point of the HCK data access object and engine;
*& test doubles are placed by ZCL_CD_HCK_INJECTOR.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-07 | get_param_dao: data access of ZCA_PARAM for the configuration check PARAM_INVALID.
*& 2026-11-07 | get_runtime_dao: reads of the checks E_NUMRANGE, E_QUEUES, A_INFLIGHT.
*& 2026-11-07 | get_recon_dao: reads of the three-way reconciliation check A_RECON_3WAY.
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

    "! Data access of the parameter framework (configuration check PARAM_INVALID)
    CLASS-METHODS get_param_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_ca_param_dao.

    "! Reads of the runtime checks (number ranges, queues, payments in flight)
    CLASS-METHODS get_runtime_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_hck_runtime_dao.

    "! Reads of the three-way reconciliation check (bank, G/L, payment engine legs)
    CLASS-METHODS get_recon_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_hck_recon_dao.

  PRIVATE SECTION.

    CLASS-DATA go_dao_double TYPE REF TO zif_cd_hck_dao.
    CLASS-DATA go_param_dao_double TYPE REF TO zif_ca_param_dao.
    CLASS-DATA go_runtime_dao_double TYPE REF TO zif_cd_hck_runtime_dao.
    CLASS-DATA go_recon_dao_double TYPE REF TO zif_cd_hck_recon_dao.

ENDCLASS.



CLASS zcl_cd_hck_factory IMPLEMENTATION.

  METHOD get_dao.
    ro_dao = COND #( WHEN go_dao_double IS BOUND THEN go_dao_double
                     ELSE NEW zcl_cd_hck_dao( ) ).
  ENDMETHOD.


  METHOD get_engine.
    ro_engine = NEW zcl_cd_hck_engine( ).
  ENDMETHOD.


  METHOD get_param_dao.
    ro_dao = COND #( WHEN go_param_dao_double IS BOUND THEN go_param_dao_double
                     ELSE NEW zcl_ca_param_dao( ) ).
  ENDMETHOD.


  METHOD get_runtime_dao.
    ro_dao = COND #( WHEN go_runtime_dao_double IS BOUND THEN go_runtime_dao_double
                     ELSE NEW zcl_cd_hck_runtime_dao( ) ).
  ENDMETHOD.


  METHOD get_recon_dao.
    ro_dao = COND #( WHEN go_recon_dao_double IS BOUND THEN go_recon_dao_double
                     ELSE NEW zcl_cd_hck_recon_dao( ) ).
  ENDMETHOD.

ENDCLASS.
