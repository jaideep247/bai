*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_injector.clas.abap
*& Purpose:
*& Unit tests only (not FOR TESTING so the factory may name it as GLOBAL FRIEND).
*& Writes the private double slots of ZCL_CA_OPS_FACTORY.
*& Always call reset( ) in teardown (a consumer's injector reset calls it too).
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | inject_auth, inject_lock, inject_purge_dao added.
*& 2026-11-07 | inject_params added (runtime parameters); reset also drops the session parameter adapter.
*& 2026-11-10 | Moved from ZCL_CD_OPS_INJECTOR to the reusable framework ZCA_OPS (framework slots only);
*&            | inject_param_version (double of the installed ZCA_PARAM release, version check).
*& 2026-11-10 | INJECT_MAIL_TEMPLATE (alert e-mail templates).
*& 2026-11-10 | INJECT_REVIEW_DAO (daily control review).
*& 2026-11-10 | INJECT_CHECK_DAO (check registry, process onboarding).
*& 2026-11-11 | INJECT_DOWNTIME (planned downtime API, operations response features).
*& 2026-11-11 | INJECT_CATALOG, INJECT_CAT_DAO (process catalogue).
*& 2026-11-11 | INJECT_BRK_DAO (clearing-account break analysis).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - test injector for the factory</p>
"! Unit tests only (not FOR TESTING so the factory may name it as GLOBAL FRIEND).
"! Writes the private double slots of ZCL_CA_OPS_FACTORY.
"! Always call reset( ) in teardown.
CLASS zcl_ca_ops_injector DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    CLASS-METHODS inject_store
      IMPORTING
        io_store TYPE REF TO zif_ca_ops_store.

    CLASS-METHODS inject_params
      IMPORTING
        io_params TYPE REF TO zif_ca_ops_params.

    CLASS-METHODS inject_alert
      IMPORTING
        io_alert TYPE REF TO zif_ca_ops_alert.

    CLASS-METHODS inject_clock
      IMPORTING
        io_clock TYPE REF TO zif_ca_ops_clock.

    CLASS-METHODS inject_alert_dao
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_alert_dao.

    CLASS-METHODS inject_auth
      IMPORTING
        io_auth TYPE REF TO zif_ca_ops_auth.

    CLASS-METHODS inject_lock
      IMPORTING
        io_lock TYPE REF TO zif_ca_ops_lock.

    CLASS-METHODS inject_purge_dao
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_purge_dao.

    CLASS-METHODS inject_mail_template
      IMPORTING
        io_template TYPE REF TO zif_ca_ops_mail_template.

    CLASS-METHODS inject_review_dao
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_review_dao.
    CLASS-METHODS inject_check_dao
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_check_dao.
    CLASS-METHODS inject_downtime
      IMPORTING
        io_downtime TYPE REF TO zif_ca_ops_downtime.
    CLASS-METHODS inject_catalog
      IMPORTING
        io_catalog TYPE REF TO zif_ca_ops_catalog.
    CLASS-METHODS inject_cat_dao
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_cat_dao.

    "! Break analysis data access (2026-11-11)
    CLASS-METHODS inject_brk_dao
      IMPORTING
        io_dao TYPE REF TO zif_ca_ops_brk_dao.

    CLASS-METHODS inject_plugin
      IMPORTING
        iv_class_name TYPE zif_ca_ops_types=>ty_class_name
        io_instance   TYPE REF TO object.

    "! Release of ZCA_PARAM as CHECK_VERSION sees it (and the check runs again)
    CLASS-METHODS inject_param_version
      IMPORTING
        iv_version TYPE string.

    CLASS-METHODS reset.

ENDCLASS.



CLASS zcl_ca_ops_injector IMPLEMENTATION.

  METHOD inject_store.
    zcl_ca_ops_factory=>go_store_double = io_store.
  ENDMETHOD.


  METHOD inject_params.
    zcl_ca_ops_factory=>go_params_double = io_params.
  ENDMETHOD.


  METHOD inject_alert.
    zcl_ca_ops_factory=>go_alert_double = io_alert.
  ENDMETHOD.


  METHOD inject_clock.
    zcl_ca_ops_factory=>go_clock_double = io_clock.
  ENDMETHOD.


  METHOD inject_alert_dao.
    zcl_ca_ops_factory=>go_alert_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_auth.
    zcl_ca_ops_factory=>go_auth_double = io_auth.
  ENDMETHOD.


  METHOD inject_lock.
    zcl_ca_ops_factory=>go_lock_double = io_lock.
  ENDMETHOD.


  METHOD inject_purge_dao.
    zcl_ca_ops_factory=>go_purge_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_mail_template.
    zcl_ca_ops_factory=>go_mail_template_double = io_template.
  ENDMETHOD.


  METHOD inject_review_dao.
    zcl_ca_ops_factory=>go_review_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_check_dao.
    zcl_ca_ops_factory=>go_check_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_downtime.
    zcl_ca_ops_factory=>go_downtime_double = io_downtime.
  ENDMETHOD.


  METHOD inject_catalog.
    zcl_ca_ops_factory=>go_catalog_double = io_catalog.
  ENDMETHOD.


  METHOD inject_cat_dao.
    zcl_ca_ops_factory=>go_cat_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_brk_dao.
    zcl_ca_ops_factory=>go_brk_dao_double = io_dao.
  ENDMETHOD.


  METHOD inject_plugin.
    DATA(lv_name) = CONV zif_ca_ops_types=>ty_class_name( to_upper( condense( CONV string( iv_class_name ) ) ) ).
    DELETE zcl_ca_ops_factory=>gt_plugin_double
      WHERE class_name = lv_name.
    INSERT VALUE #( class_name = lv_name
                    instance   = io_instance ) INTO TABLE zcl_ca_ops_factory=>gt_plugin_double.
  ENDMETHOD.


  METHOD inject_param_version.
    zcl_ca_ops_factory=>gv_param_version_double = iv_version.
    CLEAR zcl_ca_ops_factory=>gv_version_ok.
  ENDMETHOD.


  METHOD reset.
    CLEAR: zcl_ca_ops_factory=>go_store_double,
           zcl_ca_ops_factory=>go_params_double,
           zcl_ca_ops_factory=>go_alert_double,
           zcl_ca_ops_factory=>go_mail_template_double,
           zcl_ca_ops_factory=>go_clock_double,
           zcl_ca_ops_factory=>go_alert_dao_double,
           zcl_ca_ops_factory=>go_auth_double,
           zcl_ca_ops_factory=>go_lock_double,
           zcl_ca_ops_factory=>go_purge_dao_double,
           zcl_ca_ops_factory=>go_review_dao_double,
           zcl_ca_ops_factory=>go_check_dao_double,
           zcl_ca_ops_factory=>go_downtime_double,
           zcl_ca_ops_factory=>go_catalog_double,
           zcl_ca_ops_factory=>go_cat_dao_double,
           zcl_ca_ops_factory=>go_brk_dao_double,
           zcl_ca_ops_factory=>gt_plugin_double,
           zcl_ca_ops_factory=>gv_param_version_double,
           zcl_ca_ops_factory=>gv_version_ok,
           zcl_ca_ops_factory=>go_store,
           zcl_ca_ops_factory=>go_params.
  ENDMETHOD.

ENDCLASS.
