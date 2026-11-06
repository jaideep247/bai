*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_canonical.clas.abap
*& Purpose:
*& Pure canonical serialization of a table row for the configuration-drift
*& hash: every field as <type kind>:<length>:<value>; so no two different
*& rows serialize to the same text (no separator ambiguity). No SQL.
*& Modification log:
*& 2026-11-06 | Initial version (audit A57: length-prefixed typed fields).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - canonical row serialization (drift hash)</p>
"! Hash version 2 (GC_HASH_VERSION). Version 1 joined unescaped values with '|',
"! so A|B,C and A,B|C produced the same hash; baselines of version 1 must be retaken.
CLASS zcl_cd_hck_canonical DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Version of the serialization written into ZCD_HCK_BASELINE-HASH_VERSION
    CONSTANTS gc_hash_version TYPE zif_cd_hck_types=>ty_hash_version VALUE '2'.

    "! One field: type kind, length of the value text, value text
    CLASS-METHODS field
      IMPORTING
        iv_value       TYPE any
      RETURNING
        VALUE(rv_text) TYPE string.

    "! All components of a structured row, in component order
    CLASS-METHODS row
      IMPORTING
        is_row         TYPE any
      RETURNING
        VALUE(rv_text) TYPE string.

  PRIVATE SECTION.
    CONSTANTS gc_part_sep TYPE c LENGTH 1 VALUE ':'.
    CONSTANTS gc_field_end TYPE c LENGTH 1 VALUE ';'.

ENDCLASS.



CLASS zcl_cd_hck_canonical IMPLEMENTATION.

  METHOD field.
    DATA(lv_value) = |{ iv_value }|.
    DATA(lv_kind) = cl_abap_typedescr=>describe_by_data( iv_value )->type_kind.
    rv_text = |{ lv_kind }{ gc_part_sep }{ strlen( lv_value ) }{ gc_part_sep }{ lv_value }{ gc_field_end }|.
  ENDMETHOD.


  METHOD row.
    FIELD-SYMBOLS <lv_field> TYPE any.
    DO.
      ASSIGN COMPONENT sy-index OF STRUCTURE is_row TO <lv_field>.
      IF sy-subrc <> 0.
        EXIT.
      ENDIF.
      rv_text = rv_text && field( <lv_field> ).
    ENDDO.
  ENDMETHOD.

ENDCLASS.
