*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_builder.clas.abap
*& Purpose:
*& Fluent builder of test data for consumers' unit tests: area, then its
*& parameters (definition), then value rows of the current parameter
*& (NUMB 1, 2, ...). build( ) returns the REAL read logic ZCL_CA_PARAM over
*& the in-memory DAO, so a consumer test sees exactly the production
*& semantics (defaults, BOOL off, validation, exceptions). It only stores
*& data; it decides nothing.
*&   DATA(lo_param) = NEW zcl_ca_param_builder( )->area( 'ZPE_OPS'
*&     )->param( iv_name = 'MAX_ITEMS' iv_value_type = 'INT' iv_default = '10'
*&     )->row( '25' )->build( ).
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - test data builder</p>
CLASS zcl_ca_param_builder DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    METHODS constructor.

    "! Start an area (active; values not editable in production unless iv_prod_editable)
    METHODS area
      IMPORTING
        iv_area          TYPE zif_ca_param_types=>ty_area
        iv_prod_editable TYPE abap_bool DEFAULT abap_false
        iv_active        TYPE abap_bool DEFAULT abap_true
      RETURNING
        VALUE(ro_self)   TYPE REF TO zcl_ca_param_builder.

    "! Define a parameter of the current area
    METHODS param
      IMPORTING
        iv_name         TYPE zif_ca_param_types=>ty_name
        iv_value_type   TYPE zif_ca_param_types=>ty_value_type DEFAULT zif_ca_param_types=>gc_value_type-char
        iv_kind         TYPE zif_ca_param_types=>ty_kind DEFAULT zif_ca_param_types=>gc_kind-single
        iv_default      TYPE zif_ca_param_types=>ty_value OPTIONAL
        iv_min          TYPE zif_ca_param_types=>ty_value OPTIONAL
        iv_max          TYPE zif_ca_param_types=>ty_value OPTIONAL
        iv_allowed_pcre TYPE zif_ca_param_types=>ty_value OPTIONAL
        iv_interface    TYPE zif_ca_param_types=>ty_interface OPTIONAL
        iv_mandatory    TYPE abap_bool DEFAULT abap_false
      RETURNING
        VALUE(ro_self)  TYPE REF TO zcl_ca_param_builder.

    "! Add a value row to the current parameter (next NUMB)
    METHODS row
      IMPORTING
        iv_low         TYPE zif_ca_param_types=>ty_value
        iv_high        TYPE zif_ca_param_types=>ty_value OPTIONAL
        iv_sign        TYPE zif_ca_param_types=>ty_sign DEFAULT zif_ca_param_types=>gc_sign-include
        iv_option      TYPE zif_ca_param_types=>ty_option DEFAULT zif_ca_param_types=>gc_option-eq
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_ca_param_builder.

    "! The in-memory DAO with the data built so far
    METHODS dao
      RETURNING
        VALUE(ro_dao) TYPE REF TO zcl_ca_param_dao_mem.

    "! Real read logic over the in-memory DAO
    METHODS build
      RETURNING
        VALUE(ro_param) TYPE REF TO zif_ca_param.

  PRIVATE SECTION.
    DATA mo_dao  TYPE REF TO zcl_ca_param_dao_mem.
    DATA mv_area TYPE zif_ca_param_types=>ty_area.
    DATA mv_name TYPE zif_ca_param_types=>ty_name.

ENDCLASS.



CLASS zcl_ca_param_builder IMPLEMENTATION.

  METHOD constructor.
    mo_dao = NEW #( ).
  ENDMETHOD.


  METHOD area.
    DATA ls_area TYPE zif_ca_param_types=>ty_area_row.

    ls_area-area          = iv_area.
    ls_area-description   = iv_area.
    ls_area-prod_editable = iv_prod_editable.
    ls_area-active        = iv_active.
    mo_dao->add_area( ls_area ).
    mv_area = iv_area.
    CLEAR mv_name.
    ro_self = me.
  ENDMETHOD.


  METHOD param.
    DATA ls_definition TYPE zif_ca_param_types=>ty_definition.

    ls_definition-area           = mv_area.
    ls_definition-name           = iv_name.
    ls_definition-kind           = iv_kind.
    ls_definition-value_type     = iv_value_type.
    ls_definition-default_value  = iv_default.
    ls_definition-min_value      = iv_min.
    ls_definition-max_value      = iv_max.
    ls_definition-allowed_pcre   = iv_allowed_pcre.
    ls_definition-interface_name = iv_interface.
    ls_definition-mandatory      = iv_mandatory.
    mo_dao->add_definition( ls_definition ).
    mv_name = iv_name.
    ro_self = me.
  ENDMETHOD.


  METHOD row.
    DATA ls_value TYPE zif_ca_param_types=>ty_value_row.

    ls_value-area = mv_area.
    ls_value-name = mv_name.
    ls_value-numb = mo_dao->count_values( iv_area = mv_area
                                          iv_name = mv_name ) + 1.
    ls_value-sign = iv_sign.
    ls_value-opti = iv_option.
    ls_value-low  = iv_low.
    ls_value-high = iv_high.
    mo_dao->add_value( ls_value ).
    ro_self = me.
  ENDMETHOD.


  METHOD dao.
    ro_dao = mo_dao.
  ENDMETHOD.


  METHOD build.
    ro_param = NEW zcl_ca_param( io_dao = mo_dao ).
  ENDMETHOD.

ENDCLASS.
