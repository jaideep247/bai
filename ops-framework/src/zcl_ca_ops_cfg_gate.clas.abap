*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cfg_gate.clas.abap
*& Purpose:
*& The single entry point of the four configuration behaviour pools:
*& feature control (create / delete per client policy), transport request
*& check, transport recording (only where the client records changes) and
*& authorisation (ZCD_OPS). Client settings are read once per instance.
*& Handlers stay thin: they only translate answers into RAP results.
*& Modification log:
*& 2026-11-06 | Initial version (RAP configuration apps, design 5).
*& 2026-11-07 | Per-table create withdrawn: new rows only by transport from DV1 (user decision, D-3).
*& 2026-11-08 | MAY_EDIT: editing the singleton needs ZCD_OPS 01, 02 or 06 of the area (activities per child).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Ops suite - config apps: gate for behaviour pools</p>
CLASS zcl_ca_ops_cfg_gate DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE
  GLOBAL FRIENDS zcl_ca_ops_cfg_factory.

  PUBLIC SECTION.
    METHODS decision
      RETURNING
        VALUE(rs_decision) TYPE zif_ca_ops_cfg_types=>ty_decision.

    METHODS create_allowed
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    METHODS delete_allowed
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    "! Message 402-405 when the request cannot take the changes; initial otherwise
    METHODS check_request
      IMPORTING
        iv_request        TYPE zif_ca_ops_cfg_types=>ty_request
      RETURNING
        VALUE(rs_message) TYPE zif_ca_ops_cfg_types=>ty_message.

    METHODS is_authorized
      IMPORTING
        iv_area         TYPE zif_ca_ops_types=>ty_area
        iv_actvt          TYPE zif_ca_ops_cfg_types=>ty_actvt
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    "! Editing the singleton of an app: at least one of ZCD_OPS 01 (create), 02 (change) or
    "! 06 (delete) for the payment engine area; each child operation checks its own activity
    METHODS may_edit
      IMPORTING
        iv_area        TYPE zif_ca_ops_types=>ty_area
      RETURNING
        VALUE(rv_allowed) TYPE abap_bool.

    "! Records the save on the request where the client records changes; no-op elsewhere
    METHODS record
      IMPORTING
        iv_request   TYPE zif_ca_ops_cfg_types=>ty_request
        it_relations TYPE zif_ca_ops_cfg_types=>tt_relation
        ir_create    TYPE REF TO data OPTIONAL
        ir_update    TYPE REF TO data OPTIONAL
        ir_delete    TYPE REF TO data OPTIONAL
      RAISING
        zcx_ca_ops_error.

  PRIVATE SECTION.
    DATA mo_client    TYPE REF TO zif_ca_ops_cfg_client.
    DATA mo_transport TYPE REF TO zif_ca_ops_cfg_transport.
    DATA mo_auth      TYPE REF TO zif_ca_ops_cfg_auth.
    DATA ms_decision  TYPE zif_ca_ops_cfg_types=>ty_decision.
    DATA mv_decided   TYPE abap_bool.

    METHODS constructor.

ENDCLASS.



CLASS zcl_ca_ops_cfg_gate IMPLEMENTATION.

  METHOD constructor.
    mo_client    = zcl_ca_ops_cfg_factory=>get_client( ).
    mo_transport = zcl_ca_ops_cfg_factory=>get_transport( ).
    mo_auth      = zcl_ca_ops_cfg_factory=>get_auth( ).
  ENDMETHOD.


  METHOD decision.
    IF mv_decided = abap_false.
      ms_decision = zcl_ca_ops_cfg_policy=>decide( mo_client->read_client( ) ).
      mv_decided  = abap_true.
    ENDIF.
    rs_decision = ms_decision.
  ENDMETHOD.


  METHOD create_allowed.
    rv_allowed = decision( )-create_allowed.
  ENDMETHOD.


  METHOD delete_allowed.
    rv_allowed = decision( )-delete_allowed.
  ENDMETHOD.


  METHOD check_request.
    DATA ls_info TYPE zif_ca_ops_cfg_types=>ty_request_info.

    DATA(ls_decision) = decision( ).
    IF ls_decision-transport_required = abap_true AND iv_request IS NOT INITIAL.
      ls_info = mo_client->read_request( iv_request ).
    ENDIF.
    rs_message = zcl_ca_ops_cfg_policy=>request_error( is_decision = ls_decision
                                                      iv_request  = iv_request
                                                      is_info     = ls_info ).
  ENDMETHOD.


  METHOD is_authorized.
    rv_allowed = mo_auth->is_authorized( iv_area = iv_area
                                         iv_actvt  = iv_actvt ).
  ENDMETHOD.


  METHOD may_edit.
    rv_allowed = xsdbool( is_authorized( iv_area = iv_area
                                         iv_actvt   = zif_ca_ops_cfg_types=>gc_actvt-change ) = abap_true
                          OR is_authorized( iv_area = iv_area
                                            iv_actvt   = zif_ca_ops_cfg_types=>gc_actvt-create ) = abap_true
                          OR is_authorized( iv_area = iv_area
                                            iv_actvt   = zif_ca_ops_cfg_types=>gc_actvt-delete ) = abap_true ).
  ENDMETHOD.


  METHOD record.
    IF decision( )-transport_required = abap_false OR iv_request IS INITIAL.
      RETURN.
    ENDIF.
    mo_transport->record( iv_request   = iv_request
                          it_relations = it_relations
                          ir_create    = ir_create
                          ir_update    = ir_update
                          ir_delete    = ir_delete ).
  ENDMETHOD.

ENDCLASS.
