*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_factory.clas.abap
*& Purpose:
*& Resolves shared services (store, alert router, alert DAO, clock) and creates
*& configured plug-ins by class name. Test doubles come from ZCL_CD_OPS_INJECTOR.
*& Getters never read the database.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-05 | Alert router and alert DAO added.
*& 2026-11-06 | Authorisation seam (ZCD_OPS) added.
*& 2026-11-06 | Run lock seam added.
*& 2026-11-06 | Retention purge DAO seam added.
*& 2026-11-06 | Exception repository seam added (operations apps).
*& 2026-11-06 | Required plug-in interface checked by RTTI before CREATE OBJECT (audit A62).
*& 2026-11-06 | Payment trace read repository seam added (360 degree payment trace).
*& 2026-11-06 | Pattern check / migration repository seam added (PCRE patterns).
*& 2026-11-07 | get_params: runtime parameters (ZIF_CD_OPS_PARAMS), default the store.
*& 2026-11-07 | Exception and pattern DAO without test-double slot (injector seams removed, unused).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations suite - core factory</p>
"! Single resolution point for shared services and for configuration-driven
"! plug-ins (EBS rules, health checks, file adapters). Test doubles are written
"! by ZCL_CD_OPS_INJECTOR into the private slots.
"! Construction has no side effects: getters never read the database.
CLASS zcl_cd_ops_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_cd_ops_injector.

  PUBLIC SECTION.

    CLASS-METHODS get_store
      RETURNING
        VALUE(ro_store) TYPE REF TO zif_cd_ops_store.

    "! Runtime parameters: the injected double, else the store (ZCD_OPS_PARAM)
    CLASS-METHODS get_params
      RETURNING
        VALUE(ro_params) TYPE REF TO zif_cd_ops_params.

    CLASS-METHODS get_alert
      RETURNING
        VALUE(ro_alert) TYPE REF TO zif_cd_ops_alert.

    CLASS-METHODS get_clock
      RETURNING
        VALUE(ro_clock) TYPE REF TO zif_cd_ops_clock.

    CLASS-METHODS get_alert_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ops_alert_dao.

    CLASS-METHODS get_auth
      RETURNING
        VALUE(ro_auth) TYPE REF TO zif_cd_ops_auth.

    CLASS-METHODS get_lock
      RETURNING
        VALUE(ro_lock) TYPE REF TO zif_cd_ops_lock.

    CLASS-METHODS get_purge_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ops_purge_dao.

    "! Exception repository (closing exceptions from other apps' saves)
    CLASS-METHODS get_exc_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ops_exc_dao.

    "! Read repository of the payment trace (read-only)
    CLASS-METHODS get_trace_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ops_trace_dao.

    "! Repository of the pattern check and the pattern migration
    CLASS-METHODS get_pattern_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_cd_ops_pattern_dao.

    "! Instantiate a configured plug-in class by name.
    "! An injected double for the same class name wins.
    "! With iv_interface the class (or the double) must implement that interface; this is
    "! checked by RTTI BEFORE the instance is created, so the constructor of a wrongly
    "! configured class never runs (audit A62).
    "! @parameter iv_interface | required plug-in interface, e.g. ZIF_CD_HCK_CHECK
    "! @raising zcx_cd_ops_error | class does not exist, is not instantiable or does not
    "! implement the interface; interface does not exist
    CLASS-METHODS get_plugin
      IMPORTING
        iv_class_name    TYPE zif_cd_ops_types=>ty_class_name
        iv_interface     TYPE zif_cd_ops_types=>ty_class_name OPTIONAL
      RETURNING
        VALUE(ro_object) TYPE REF TO object
      RAISING
        zcx_cd_ops_error.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_plugin_double,
        class_name TYPE zif_cd_ops_types=>ty_class_name,
        instance   TYPE REF TO object,
      END OF ty_plugin_double.
    TYPES tt_plugin_double TYPE HASHED TABLE OF ty_plugin_double WITH UNIQUE KEY class_name.

    CLASS-DATA go_store_double TYPE REF TO zif_cd_ops_store.
    CLASS-DATA go_params_double TYPE REF TO zif_cd_ops_params.
    CLASS-DATA go_alert_double TYPE REF TO zif_cd_ops_alert.
    CLASS-DATA go_clock_double TYPE REF TO zif_cd_ops_clock.
    CLASS-DATA go_alert_dao_double TYPE REF TO zif_cd_ops_alert_dao.
    CLASS-DATA go_auth_double TYPE REF TO zif_cd_ops_auth.
    CLASS-DATA go_lock_double TYPE REF TO zif_cd_ops_lock.
    CLASS-DATA go_purge_dao_double TYPE REF TO zif_cd_ops_purge_dao.
    CLASS-DATA go_trace_dao_double TYPE REF TO zif_cd_ops_trace_dao.
    CLASS-DATA gt_plugin_double TYPE tt_plugin_double.

    CLASS-METHODS describe_interface
      IMPORTING
        iv_interface   TYPE string
      RETURNING
        VALUE(ro_intf) TYPE REF TO cl_abap_intfdescr
      RAISING
        zcx_cd_ops_error.

    "! Per-session store instance; its parameter snapshot is renewed by each start_run (A64)
    CLASS-DATA go_store TYPE REF TO zif_cd_ops_store.

ENDCLASS.



CLASS zcl_cd_ops_factory IMPLEMENTATION.

  METHOD get_store.
    IF go_store_double IS BOUND.
      ro_store = go_store_double.
      RETURN.
    ENDIF.
    IF go_store IS NOT BOUND.
      go_store = NEW zcl_cd_ops_store( ).
    ENDIF.
    ro_store = go_store.
  ENDMETHOD.


  METHOD get_params.
    ro_params = COND #( WHEN go_params_double IS BOUND THEN go_params_double ELSE get_store( ) ).
  ENDMETHOD.


  METHOD get_alert.
    ro_alert = COND #( WHEN go_alert_double IS BOUND THEN go_alert_double
                       ELSE NEW zcl_cd_ops_alert_router( ) ).
  ENDMETHOD.


  METHOD get_clock.
    ro_clock = COND #( WHEN go_clock_double IS BOUND THEN go_clock_double
                       ELSE NEW zcl_cd_ops_clock( ) ).
  ENDMETHOD.


  METHOD get_alert_dao.
    ro_dao = COND #( WHEN go_alert_dao_double IS BOUND THEN go_alert_dao_double
                     ELSE NEW zcl_cd_ops_alert_dao( ) ).
  ENDMETHOD.


  METHOD get_auth.
    ro_auth = COND #( WHEN go_auth_double IS BOUND THEN go_auth_double
                      ELSE NEW zcl_cd_ops_auth( ) ).
  ENDMETHOD.


  METHOD get_lock.
    ro_lock = COND #( WHEN go_lock_double IS BOUND THEN go_lock_double
                      ELSE NEW zcl_cd_ops_lock( ) ).
  ENDMETHOD.


  METHOD get_purge_dao.
    ro_dao = COND #( WHEN go_purge_dao_double IS BOUND THEN go_purge_dao_double
                     ELSE NEW zcl_cd_ops_purge_dao( ) ).
  ENDMETHOD.


  METHOD get_exc_dao.
    ro_dao = NEW zcl_cd_ops_exc_dao( ).
  ENDMETHOD.


  METHOD get_trace_dao.
    ro_dao = COND #( WHEN go_trace_dao_double IS BOUND THEN go_trace_dao_double
                     ELSE NEW zcl_cd_ops_trace_dao( ) ).
  ENDMETHOD.


  METHOD get_pattern_dao.
    ro_dao = NEW zcl_cd_ops_pattern_dao( ).
  ENDMETHOD.


  METHOD get_plugin.
    DATA lo_descr TYPE REF TO cl_abap_typedescr.
    DATA lo_class TYPE REF TO cl_abap_classdescr.

    DATA lo_intf  TYPE REF TO cl_abap_intfdescr.

    DATA(lv_name) = to_upper( condense( CONV string( iv_class_name ) ) ).
    DATA(lv_intf) = to_upper( condense( CONV string( iv_interface ) ) ).
    IF lv_intf IS NOT INITIAL.
      lo_intf = describe_interface( lv_intf ).
    ENDIF.

    READ TABLE gt_plugin_double INTO DATA(ls_double)
      WITH TABLE KEY class_name = CONV zif_cd_ops_types=>ty_class_name( lv_name ).
    IF sy-subrc = 0.
      IF lo_intf IS BOUND AND lo_intf->applies_to( ls_double-instance ) = abap_false.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e032(zcd_ops) WITH lv_name lv_intf.
      ENDIF.
      ro_object = ls_double-instance.
      RETURN.
    ENDIF.

    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = lv_name
      RECEIVING
        p_descr_ref    = lo_descr
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e030(zcd_ops) WITH lv_name.
    ENDIF.

    TRY.
        lo_class ?= lo_descr.
      CATCH cx_sy_move_cast_error.
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e031(zcd_ops) WITH lv_name.
    ENDTRY.

    IF lo_class->is_instantiatable( ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e031(zcd_ops) WITH lv_name.
    ENDIF.

    " A62: interface first - a class that is not a plug-in of this kind is never created
    IF lo_intf IS BOUND AND lo_intf->applies_to_class( lv_name ) = abap_false.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e032(zcd_ops) WITH lv_name lv_intf.
    ENDIF.

    TRY.
        CREATE OBJECT ro_object TYPE (lv_name).
      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        RAISE EXCEPTION TYPE zcx_cd_ops_error
          MESSAGE e031(zcd_ops) WITH lv_name
          EXPORTING
            previous = lx_create.
    ENDTRY.
  ENDMETHOD.


  METHOD describe_interface.
    DATA lo_descr TYPE REF TO cl_abap_typedescr.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = iv_interface
      RECEIVING
        p_descr_ref    = lo_descr
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e033(zcd_ops) WITH iv_interface.
    ENDIF.
    IF lo_descr->kind <> cl_abap_typedescr=>kind_intf.
      RAISE EXCEPTION TYPE zcx_cd_ops_error
        MESSAGE e033(zcd_ops) WITH iv_interface.
    ENDIF.
    ro_intf = CAST #( lo_descr ).
  ENDMETHOD.

ENDCLASS.
