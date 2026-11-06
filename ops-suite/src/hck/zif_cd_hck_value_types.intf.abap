*&---------------------------------------------------------------------*
*& Artifact: zif_cd_hck_value_types.intf.abap
*& Purpose:
*& Types of the value queries behind the USAA known-table checks (payment
*& request without SPE row, cheque status regression, paid request left
*& CANCELLED): parameter specs, validated queries, rows and status events.
*& Modification log:
*& 2026-11-06 | Initial version (RAP operations apps, phase 3).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - value query types (known tables)</p>
INTERFACE zif_cd_hck_value_types
  PUBLIC.

  "! One NAME=VALUE pair of a check parameter (PARAM1-4 of ZCD_HCK_DEF)
  TYPES:
    BEGIN OF ty_spec,
      name  TYPE string,
      value TYPE string,
    END OF ty_spec.
  TYPES tt_spec TYPE STANDARD TABLE OF ty_spec WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_condition,
      field    TYPE zif_cd_hck_types=>ty_fieldname,
      operator TYPE zif_cd_hck_types=>ty_operator,
      value    TYPE zif_cd_hck_types=>ty_cond_value,
    END OF ty_condition.
  TYPES tt_condition TYPE STANDARD TABLE OF ty_condition WITH EMPTY KEY.

  "! A validated query: names checked against the DDIC and the whitelist, literals quoted
  TYPES:
    BEGIN OF ty_value_query,
      tabname      TYPE zif_cd_hck_types=>ty_tabname,
      field_list   TYPE string,
      where_clause TYPE string,
      order_by     TYPE string,
    END OF ty_value_query.

  "! Up to three character-like values of one row (aliases V1, V2, V3)
  TYPES:
    BEGIN OF ty_value_row,
      v1 TYPE string,
      v2 TYPE string,
      v3 TYPE string,
    END OF ty_value_row.
  TYPES tt_value_row TYPE STANDARD TABLE OF ty_value_row WITH EMPTY KEY.

  TYPES tt_key TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

  "! One status change of a cheque (ZCD_CHECK_HIST): key, order, status
  TYPES:
    BEGIN OF ty_status_event,
      key    TYPE string,
      seq    TYPE string,
      status TYPE string,
    END OF ty_status_event.
  TYPES tt_status_event TYPE STANDARD TABLE OF ty_status_event WITH EMPTY KEY.

  TYPES:
    BEGIN OF ty_regression,
      key         TYPE string,
      from_status TYPE string,
      to_status   TYPE string,
    END OF ty_regression.
  TYPES tt_regression TYPE STANDARD TABLE OF ty_regression WITH EMPTY KEY.

ENDINTERFACE.
