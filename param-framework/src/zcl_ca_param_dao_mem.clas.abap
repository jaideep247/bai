*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_dao_mem.clas.abap
*& Purpose:
*& In-memory data access (ZIF_CA_PARAM_DAO) for unit tests of consumers and
*& of the framework: holds area rows, definitions and value rows in SORTED
*& / HASHED tables and returns them per area exactly as ZCL_CA_PARAM_DAO
*& does (key order). It holds data only - no defaults, no validation, no
*& semantics - so a test over it runs the real logic of ZCL_CA_PARAM.
*& Counts read_area calls (buffer tests). Production-safe (no database).
*& Fill it directly (add_*) or with ZCL_CA_PARAM_BUILDER.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - in-memory data access</p>
CLASS zcl_ca_param_dao_mem DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_param_dao.

    "! Add or replace an area row
    METHODS add_area
      IMPORTING
        is_area        TYPE zif_ca_param_types=>ty_area_row
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_ca_param_dao_mem.

    "! Add or replace a definition
    METHODS add_definition
      IMPORTING
        is_definition  TYPE zif_ca_param_types=>ty_definition
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_ca_param_dao_mem.

    "! Add or replace a value row (key area, name, numb)
    METHODS add_value
      IMPORTING
        is_value       TYPE zif_ca_param_types=>ty_value_row
      RETURNING
        VALUE(ro_self) TYPE REF TO zcl_ca_param_dao_mem.

    "! Remove every value row of a parameter (as if deleted in the maintenance app)
    METHODS remove_values
      IMPORTING
        iv_area TYPE zif_ca_param_types=>ty_area
        iv_name TYPE zif_ca_param_types=>ty_name.

    "! Number of value rows of a parameter (next NUMB = count + 1)
    METHODS count_values
      IMPORTING
        iv_area         TYPE zif_ca_param_types=>ty_area
        iv_name         TYPE zif_ca_param_types=>ty_name
      RETURNING
        VALUE(rv_count) TYPE i.

    "! Calls of read_area since creation
    METHODS read_count
      RETURNING
        VALUE(rv_count) TYPE i.

  PRIVATE SECTION.
    DATA mt_areas       TYPE zif_ca_param_types=>tt_area_row.
    DATA mt_definitions TYPE zif_ca_param_types=>tt_definition.
    DATA mt_values      TYPE zif_ca_param_types=>tt_value_row.
    DATA mv_read_count  TYPE i.

ENDCLASS.



CLASS zcl_ca_param_dao_mem IMPLEMENTATION.

  METHOD zif_ca_param_dao~read_area.
    mv_read_count = mv_read_count + 1.
    READ TABLE mt_areas INTO rs_data-area WITH TABLE KEY area = iv_area.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.
    rs_data-found = abap_true.
    LOOP AT mt_definitions ASSIGNING FIELD-SYMBOL(<ls_definition>) WHERE area = iv_area.
      INSERT <ls_definition> INTO TABLE rs_data-definitions.
    ENDLOOP.
    LOOP AT mt_values ASSIGNING FIELD-SYMBOL(<ls_value>) WHERE area = iv_area.
      INSERT <ls_value> INTO TABLE rs_data-values.
    ENDLOOP.
  ENDMETHOD.


  METHOD add_area.
    DELETE TABLE mt_areas WITH TABLE KEY area = is_area-area.
    INSERT is_area INTO TABLE mt_areas.
    ro_self = me.
  ENDMETHOD.


  METHOD add_definition.
    DELETE TABLE mt_definitions WITH TABLE KEY area = is_definition-area
                                               name = is_definition-name.
    INSERT is_definition INTO TABLE mt_definitions.
    ro_self = me.
  ENDMETHOD.


  METHOD add_value.
    DELETE TABLE mt_values WITH TABLE KEY area = is_value-area
                                          name = is_value-name
                                          numb = is_value-numb.
    INSERT is_value INTO TABLE mt_values.
    ro_self = me.
  ENDMETHOD.


  METHOD remove_values.
    DELETE mt_values WHERE area = iv_area AND name = iv_name.
  ENDMETHOD.


  METHOD count_values.
    LOOP AT mt_values TRANSPORTING NO FIELDS WHERE area = iv_area AND name = iv_name.
      rv_count = rv_count + 1.
    ENDLOOP.
  ENDMETHOD.


  METHOD read_count.
    rv_count = mv_read_count.
  ENDMETHOD.

ENDCLASS.
