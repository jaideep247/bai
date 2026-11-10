*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_factory.clas.abap
*& Purpose:
*& Resolves the framework services (store, parameters, alert router, alert
*& DAO, clock, authorisation, run lock, purge DAO, exception repository) and
*& creates configured plug-ins by class name. Test doubles come from
*& ZCL_CA_OPS_INJECTOR. Getters never read the database. CHECK_VERSION
*& refuses to run on a parameter framework ZCA_PARAM older than the release
*& this framework needs (once per session; the store calls it at start_run).
*& Consumer services (a consumer's own repositories and engines) live in the
*& consumer's factory, never here.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-05 | Alert router and alert DAO added.
*& 2026-11-06 | Authorisation seam, run lock seam, retention purge DAO seam, exception repository seam.
*& 2026-11-06 | Required plug-in interface checked by RTTI before CREATE OBJECT (audit A62).
*& 2026-11-07 | get_params: runtime parameters, the session adapter over ZCA_PARAM (store serves no parameters).
*& 2026-11-10 | A caught cast error is kept as PREVIOUS of the raised error (exception chain).
*& 2026-11-10 | Moved from ZCL_CD_OPS_FACTORY to the reusable framework ZCA_OPS: framework services only
*&            | (consumer services stay in the consumer's factory); CHECK_VERSION (ZCA_PARAM release).
*& 2026-11-10 | GET_MAIL_TEMPLATE: renderer of alert e-mails from SAP e-mail templates (injectable).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - factory</p>
"! Single resolution point for the framework services and for configuration-driven
"! plug-ins. Test doubles are written by ZCL_CA_OPS_INJECTOR into the private slots.
"! Construction has no side effects: getters never read the database.
CLASS zcl_ca_ops_factory DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_ca_ops_injector.

  PUBLIC SECTION.

    CLASS-METHODS get_store
      RETURNING
        VALUE(ro_store) TYPE REF TO zif_ca_ops_store.

    "! Runtime parameters: the injected double, else the session's adapter over ZCA_PARAM
    "! (ZCL_CA_OPS_PARAMS; one error list per session, cleared by refresh_params). Consumers add
    "! the name prefixes of their areas with ZIF_CA_OPS_PARAMS=>ADD_PREFIXES.
    CLASS-METHODS get_params
      RETURNING
        VALUE(ro_params) TYPE REF TO zif_ca_ops_params.

    CLASS-METHODS get_alert
      RETURNING
        VALUE(ro_alert) TYPE REF TO zif_ca_ops_alert.

    CLASS-METHODS get_clock
      RETURNING
        VALUE(ro_clock) TYPE REF TO zif_ca_ops_clock.

    CLASS-METHODS get_alert_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_ca_ops_alert_dao.

    CLASS-METHODS get_auth
      RETURNING
        VALUE(ro_auth) TYPE REF TO zif_ca_ops_auth.

    CLASS-METHODS get_lock
      RETURNING
        VALUE(ro_lock) TYPE REF TO zif_ca_ops_lock.

    CLASS-METHODS get_purge_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_ca_ops_purge_dao.

    "! Renderer of alert e-mails from SAP e-mail templates (the injected double, else the SMTG
    "! adapter ZCL_CA_OPS_MAIL_TPL_SMTG; the built-in layout is not a slot - it is pure logic)
    CLASS-METHODS get_mail_template
      RETURNING
        VALUE(ro_template) TYPE REF TO zif_ca_ops_mail_template.

    "! Exception repository (closing exceptions from other apps' saves)
    CLASS-METHODS get_exc_dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zif_ca_ops_exc_dao.

    "! Instantiate a configured plug-in class by name.
    "! An injected double for the same class name wins.
    "! With iv_interface the class (or the double) must implement that interface; this is
    "! checked by RTTI BEFORE the instance is created, so the constructor of a wrongly
    "! configured class never runs (audit A62).
    "! @parameter iv_interface | required plug-in interface, e.g. ZIF_CA_OPS_ALERT_CHANNEL
    "! @raising zcx_ca_ops_error | class does not exist, is not instantiable or does not
    "! implement the interface; interface does not exist
    CLASS-METHODS get_plugin
      IMPORTING
        iv_class_name    TYPE zif_ca_ops_types=>ty_class_name
        iv_interface     TYPE zif_ca_ops_types=>ty_class_name OPTIONAL
      RETURNING
        VALUE(ro_object) TYPE REF TO object
      RAISING
        zcx_ca_ops_error.

    "! The installed parameter framework ZCA_PARAM is at least the release this framework needs
    "! (ZIF_CA_OPS_TYPES=>GC_PARAM_MIN_VERSION); checked once per session, message 044 otherwise
    "! @raising zcx_ca_ops_error | ZCA_PARAM too old - nothing may run on it
    CLASS-METHODS check_version
      RAISING
        zcx_ca_ops_error.

  PRIVATE SECTION.
    TYPES:
      BEGIN OF ty_plugin_double,
        class_name TYPE zif_ca_ops_types=>ty_class_name,
        instance   TYPE REF TO object,
      END OF ty_plugin_double.
    TYPES tt_plugin_double TYPE HASHED TABLE OF ty_plugin_double WITH UNIQUE KEY class_name.

    CLASS-DATA go_store_double TYPE REF TO zif_ca_ops_store.
    CLASS-DATA go_params_double TYPE REF TO zif_ca_ops_params.
    CLASS-DATA go_alert_double TYPE REF TO zif_ca_ops_alert.
    CLASS-DATA go_clock_double TYPE REF TO zif_ca_ops_clock.
    CLASS-DATA go_alert_dao_double TYPE REF TO zif_ca_ops_alert_dao.
    CLASS-DATA go_auth_double TYPE REF TO zif_ca_ops_auth.
    CLASS-DATA go_lock_double TYPE REF TO zif_ca_ops_lock.
    CLASS-DATA go_purge_dao_double TYPE REF TO zif_ca_ops_purge_dao.
    CLASS-DATA go_mail_template_double TYPE REF TO zif_ca_ops_mail_template.
    CLASS-DATA gt_plugin_double TYPE tt_plugin_double.
    "! Installed ZCA_PARAM release as seen by CHECK_VERSION (test seam: a double release)
    CLASS-DATA gv_param_version_double TYPE string.

    CLASS-METHODS describe_interface
      IMPORTING
        iv_interface   TYPE string
      RETURNING
        VALUE(ro_intf) TYPE REF TO cl_abap_intfdescr
      RAISING
        zcx_ca_ops_error.

    "! Per-session store instance
    CLASS-DATA go_store TYPE REF TO zif_ca_ops_store.
    "! Per-session parameter adapter; its snapshot is renewed by each start_run (A64)
    CLASS-DATA go_params TYPE REF TO zif_ca_ops_params.
    "! The version check passed in this session
    CLASS-DATA gv_version_ok TYPE abap_bool.

ENDCLASS.



CLASS zcl_ca_ops_factory IMPLEMENTATION.

  METHOD get_store.
    IF go_store_double IS BOUND.
      ro_store = go_store_double.
      RETURN.
    ENDIF.
    IF go_store IS NOT BOUND.
      go_store = NEW zcl_ca_ops_store( ).
    ENDIF.
    ro_store = go_store.
  ENDMETHOD.


  METHOD get_params.
    IF go_params_double IS BOUND.
      ro_params = go_params_double.
      RETURN.
    ENDIF.
    IF go_params IS NOT BOUND.
      go_params = NEW zcl_ca_ops_params( ).
    ENDIF.
    ro_params = go_params.
  ENDMETHOD.


  METHOD get_alert.
    ro_alert = COND #( WHEN go_alert_double IS BOUND THEN go_alert_double
                       ELSE NEW zcl_ca_ops_alert_router( ) ).
  ENDMETHOD.


  METHOD get_clock.
    ro_clock = COND #( WHEN go_clock_double IS BOUND THEN go_clock_double
                       ELSE NEW zcl_ca_ops_clock( ) ).
  ENDMETHOD.


  METHOD get_alert_dao.
    ro_dao = COND #( WHEN go_alert_dao_double IS BOUND THEN go_alert_dao_double
                     ELSE NEW zcl_ca_ops_alert_dao( ) ).
  ENDMETHOD.


  METHOD get_auth.
    ro_auth = COND #( WHEN go_auth_double IS BOUND THEN go_auth_double
                      ELSE NEW zcl_ca_ops_auth( ) ).
  ENDMETHOD.


  METHOD get_lock.
    ro_lock = COND #( WHEN go_lock_double IS BOUND THEN go_lock_double
                      ELSE NEW zcl_ca_ops_lock( ) ).
  ENDMETHOD.


  METHOD get_purge_dao.
    ro_dao = COND #( WHEN go_purge_dao_double IS BOUND THEN go_purge_dao_double
                     ELSE NEW zcl_ca_ops_purge_dao( ) ).
  ENDMETHOD.


  METHOD get_mail_template.
    ro_template = COND #( WHEN go_mail_template_double IS BOUND THEN go_mail_template_double
                          ELSE NEW zcl_ca_ops_mail_tpl_smtg( ) ).
  ENDMETHOD.


  METHOD get_exc_dao.
    ro_dao = NEW zcl_ca_ops_exc_dao( ).
  ENDMETHOD.


  METHOD check_version.
    IF gv_version_ok = abap_true.
      RETURN.
    ENDIF.
    DATA(lv_installed) = COND string( WHEN gv_param_version_double IS NOT INITIAL THEN gv_param_version_double
                                      ELSE zif_ca_param_types=>gc_version ).
    IF zcl_ca_ops_util=>version_at_least( iv_installed = lv_installed
                                          iv_required  = zif_ca_ops_types=>gc_param_min_version ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e044(zca_ops) WITH zif_ca_ops_types=>gc_version zif_ca_ops_types=>gc_param_min_version lv_installed.
    ENDIF.
    gv_version_ok = abap_true.
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
      WITH TABLE KEY class_name = CONV zif_ca_ops_types=>ty_class_name( lv_name ).
    IF sy-subrc = 0.
      IF lo_intf IS BOUND AND lo_intf->applies_to( ls_double-instance ) = abap_false.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e032(zca_ops) WITH lv_name lv_intf.
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
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e030(zca_ops) WITH lv_name.
    ENDIF.

    TRY.
        lo_class ?= lo_descr.
      CATCH cx_sy_move_cast_error INTO DATA(lx_error).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e031(zca_ops) WITH lv_name
          EXPORTING
            previous = lx_error.
    ENDTRY.

    IF lo_class->is_instantiatable( ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e031(zca_ops) WITH lv_name.
    ENDIF.

    " A62: interface first - a class that is not a plug-in of this kind is never created
    IF lo_intf IS BOUND AND lo_intf->applies_to_class( lv_name ) = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e032(zca_ops) WITH lv_name lv_intf.
    ENDIF.

    TRY.
        CREATE OBJECT ro_object TYPE (lv_name).
      CATCH cx_sy_create_object_error INTO DATA(lx_create).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e031(zca_ops) WITH lv_name
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
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e033(zca_ops) WITH iv_interface.
    ENDIF.
    IF lo_descr->kind <> cl_abap_typedescr=>kind_intf.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e033(zca_ops) WITH iv_interface.
    ENDIF.
    ro_intf = CAST #( lo_descr ).
  ENDMETHOD.

ENDCLASS.
