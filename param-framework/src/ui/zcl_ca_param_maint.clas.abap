*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_maint.clas.abap
*& Purpose:
*& Single entry point of the behaviour pool ZBP_R_CA_PARAMAREA: maintenance
*& mode of the client (read once per instance), change policy
*& (ZCL_CA_PARAM_MAINT_POLICY), validation rules (ZCL_CA_PARAM_VALIDATOR,
*& the same as at runtime), authorization and transport request check and
*& recording through ZIF_CA_PARAM_SYSTEM. The handlers stay thin: they
*& translate answers into RAP results. get( ) returns the instance of the
*& session; tests create their own over a system double.
*& Modification log:
*& 2026-11-07 | Initial version.
*& 2026-11-10 | check_config_change: message 048 with the reason when the client check failed.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - maintenance gate</p>
CLASS zcl_ca_param_maint DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! The gate of this session (over ZCL_CA_PARAM_SYSTEM)
    CLASS-METHODS get
      RETURNING
        VALUE(ro_maint) TYPE REF TO zcl_ca_param_maint.

    "! @parameter io_system | System boundary (default: ZCL_CA_PARAM_SYSTEM)
    METHODS constructor
      IMPORTING
        io_system TYPE REF TO zif_ca_param_system OPTIONAL.

    METHODS mode
      RETURNING
        VALUE(rv_mode) TYPE zif_ca_param_types=>ty_mode.

    METHODS can_maintain_config
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    METHODS can_edit_area
      IMPORTING
        iv_prod_editable  TYPE abap_bool
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    METHODS can_change_value
      IMPORTING
        iv_prod_editable   TYPE abap_bool
        iv_developer_owned TYPE abap_bool
      RETURNING
        VALUE(rv_allowed)  TYPE abap_bool.

    METHODS is_authorized
      IMPORTING
        iv_area           TYPE zif_ca_param_types=>ty_area
        iv_actvt          TYPE zif_ca_param_types=>ty_actvt
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    "! Message 040-043 when the request cannot take the changes of the area
    METHODS check_request
      IMPORTING
        iv_area           TYPE zif_ca_param_types=>ty_area
        iv_request        TYPE zif_ca_param_types=>ty_request
      RETURNING
        VALUE(rs_message) TYPE zif_ca_param_types=>ty_message.

    "! Message 044 when areas / definitions cannot be maintained in this client; 048 with the
    "! reason when the client check itself failed (customizing treated as not editable)
    METHODS check_config_change
      IMPORTING
        iv_area           TYPE zif_ca_param_types=>ty_area
      RETURNING
        VALUE(rs_message) TYPE zif_ca_param_types=>ty_message.

    "! Message 045 when the value rows of the parameter cannot be changed in this client
    METHODS check_value_change
      IMPORTING
        iv_area            TYPE zif_ca_param_types=>ty_area
        iv_name            TYPE zif_ca_param_types=>ty_name
        iv_prod_editable   TYPE abap_bool
        iv_developer_owned TYPE abap_bool
      RETURNING
        VALUE(rs_message)  TYPE zif_ca_param_types=>ty_message.

    "! Record the save on the request in TRANSPORT mode; no-op in LOCAL mode
    METHODS record
      IMPORTING
        iv_request   TYPE zif_ca_param_types=>ty_request
        ir_create    TYPE REF TO data
        ir_update    TYPE REF TO data
        ir_delete    TYPE REF TO data
      RAISING
        zcx_ca_param.

    METHODS validator
      RETURNING
        VALUE(ro_validator) TYPE REF TO zcl_ca_param_validator.

  PRIVATE SECTION.
    CLASS-DATA go_instance TYPE REF TO zcl_ca_param_maint.

    DATA mo_system    TYPE REF TO zif_ca_param_system.
    DATA mo_validator TYPE REF TO zcl_ca_param_validator.
    DATA mv_mode      TYPE zif_ca_param_types=>ty_mode.
    DATA ms_client    TYPE zif_ca_param_types=>ty_client.

ENDCLASS.



CLASS zcl_ca_param_maint IMPLEMENTATION.

  METHOD get.
    IF go_instance IS NOT BOUND.
      go_instance = NEW #( ).
    ENDIF.
    ro_maint = go_instance.
  ENDMETHOD.


  METHOD constructor.
    mo_system    = COND #( WHEN io_system IS BOUND THEN io_system ELSE NEW zcl_ca_param_system( ) ).
    mo_validator = NEW #( ).
  ENDMETHOD.


  METHOD mode.
    IF mv_mode IS INITIAL.
      ms_client = mo_system->read_client( ).
      mv_mode   = zcl_ca_param_maint_policy=>mode( ms_client ).
    ENDIF.
    rv_mode = mv_mode.
  ENDMETHOD.


  METHOD can_maintain_config.
    rv_allowed = zcl_ca_param_maint_policy=>can_maintain_config( mode( ) ).
  ENDMETHOD.


  METHOD can_edit_area.
    rv_allowed = zcl_ca_param_maint_policy=>can_edit_area( iv_mode          = mode( )
                                                            iv_prod_editable = iv_prod_editable ).
  ENDMETHOD.


  METHOD can_change_value.
    rv_allowed = zcl_ca_param_maint_policy=>can_change_value( iv_mode            = mode( )
                                                               iv_prod_editable   = iv_prod_editable
                                                               iv_developer_owned = iv_developer_owned ).
  ENDMETHOD.


  METHOD is_authorized.
    rv_allowed = mo_system->is_authorized( iv_area  = iv_area
                                           iv_actvt = iv_actvt ).
  ENDMETHOD.


  METHOD check_request.
    DATA ls_info TYPE zif_ca_param_types=>ty_request_info.

    IF mode( ) = zif_ca_param_types=>gc_mode-transport AND iv_request IS NOT INITIAL.
      ls_info = mo_system->read_request( iv_request ).
    ENDIF.
    rs_message = zcl_ca_param_maint_policy=>request_message( iv_mode    = mode( )
                                                             iv_area    = iv_area
                                                             iv_request = iv_request
                                                             is_info    = ls_info ).
  ENDMETHOD.


  METHOD check_config_change.
    IF can_maintain_config( ) = abap_true.
      RETURN.
    ENDIF.
    IF ms_client-cust_reason IS NOT INITIAL.
      rs_message = VALUE #( msgid = zif_ca_param_types=>gc_msgid
                            msgno = zif_ca_param_types=>gc_msg-client_unchecked
                            v1    = iv_area
                            v2    = ms_client-cust_reason ).
      RETURN.
    ENDIF.
    rs_message = VALUE #( msgid = zif_ca_param_types=>gc_msgid
                          msgno = zif_ca_param_types=>gc_msg-config_not_allowed
                          v1    = iv_area ).
  ENDMETHOD.


  METHOD check_value_change.
    IF can_change_value( iv_prod_editable   = iv_prod_editable
                         iv_developer_owned = iv_developer_owned ) = abap_false.
      rs_message = VALUE #( msgid = zif_ca_param_types=>gc_msgid
                            msgno = zif_ca_param_types=>gc_msg-value_not_editable
                            v1    = iv_area
                            v2    = iv_name ).
    ENDIF.
  ENDMETHOD.


  METHOD record.
    IF mode( ) <> zif_ca_param_types=>gc_mode-transport OR iv_request IS INITIAL.
      RETURN.
    ENDIF.
    mo_system->record_changes(
      iv_request   = iv_request
      it_relations = VALUE #( ( entity = zif_ca_param_types=>gc_entity-area
                                table  = zif_ca_param_types=>gc_table-area )
                              ( entity = zif_ca_param_types=>gc_entity-definition
                                table  = zif_ca_param_types=>gc_table-definition )
                              ( entity = zif_ca_param_types=>gc_entity-value
                                table  = zif_ca_param_types=>gc_table-value ) )
      ir_create    = ir_create
      ir_update    = ir_update
      ir_delete    = ir_delete ).
  ENDMETHOD.


  METHOD validator.
    ro_validator = mo_validator.
  ENDMETHOD.

ENDCLASS.
