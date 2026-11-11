*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_cfg_version.clas.abap
*& Purpose:
*& Configuration version of a check (explainable, versioned results): the
*& SHA-1 (hex, 40 characters) of the effective configuration rows that
*& produced a result - the registry row of the check (area, check ID,
*& process, class, schedule group, company-code flag, active) and the
*& check's own rows (ZIF_CA_OPS_CHECK_CONFIG: aggregate rows, bucket rules,
*& parameter values). Lines are sorted before hashing, so the order in
*& which a check lists its rows never changes the version; the same rows
*& always give the same version. Pure: no database, no state.
*& Modification log:
*& 2026-11-11 | Initial version (explainable, versioned results).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - configuration version of a check</p>
"! A finding records the version of its run (ZCA_OPS_FINDING-CFG_VERSION); the control review reopens a
"! sign-off when a covered finding was produced by another version (docs/EXPLAINABLE_RESULTS.md).
CLASS zcl_ca_ops_cfg_version DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! Kind of the registry row's line
    CONSTANTS gc_kind_check TYPE string VALUE `CHECK`.
    "! Separator of the values of a line and of the lines of the hashed text
    CONSTANTS gc_separator TYPE string VALUE `|`.
    "! Hash algorithm (CL_ABAP_MESSAGE_DIGEST)
    CONSTANTS gc_algorithm TYPE string VALUE `SHA1`.

    "! Version of a check: the registry row's line and the check's own lines, sorted, hashed
    "! @parameter is_check   | Registry row (description and sequence left out: they change no result)
    "! @parameter it_lines   | The check's own configuration lines (ZIF_CA_OPS_CHECK_CONFIG)
    "! @parameter rv_version | SHA-1 in hex; blank when no hash could be built
    CLASS-METHODS of_check
      IMPORTING
        is_check          TYPE zif_ca_ops_chk_types=>ty_check
        it_lines          TYPE string_table OPTIONAL
      RETURNING
        VALUE(rv_version) TYPE zif_ca_ops_types=>ty_cfg_version.

    "! Version of any set of configuration lines (sorted before hashing)
    CLASS-METHODS of_lines
      IMPORTING
        it_lines          TYPE string_table
      RETURNING
        VALUE(rv_version) TYPE zif_ca_ops_types=>ty_cfg_version.

    "! One configuration line: the kind, then the value of every elementary component of the row in order
    "! (a structure; any other data object is one value)
    CLASS-METHODS line
      IMPORTING
        iv_kind        TYPE clike
        is_row         TYPE any
      RETURNING
        VALUE(rv_line) TYPE string.

ENDCLASS.



CLASS zcl_ca_ops_cfg_version IMPLEMENTATION.

  METHOD of_check.
    DATA lt_lines TYPE string_table.
    DATA(ls_row) = is_check.
    CLEAR: ls_row-description, ls_row-seq.
    lt_lines = it_lines.
    INSERT line( iv_kind = gc_kind_check is_row = ls_row ) INTO TABLE lt_lines.
    rv_version = of_lines( lt_lines ).
  ENDMETHOD.


  METHOD of_lines.
    DATA lv_hash TYPE string.
    DATA(lt_sorted) = it_lines.
    SORT lt_sorted BY table_line.
    TRY.
        cl_abap_message_digest=>calculate_hash_for_char(
          EXPORTING
            if_algorithm  = gc_algorithm
            if_data       = concat_lines_of( table = lt_sorted sep = cl_abap_char_utilities=>newline )
          IMPORTING
            ef_hashstring = lv_hash ).
      CATCH cx_abap_message_digest.
        " without a hash the version is not known (blank) - the result itself is unaffected
        CLEAR lv_hash.
    ENDTRY.
    rv_version = to_upper( lv_hash ).
  ENDMETHOD.


  METHOD line.
    DATA lt_values TYPE string_table.
    INSERT CONV string( iv_kind ) INTO TABLE lt_values.
    DATA(lo_type) = cl_abap_typedescr=>describe_by_data( is_row ).
    IF lo_type->kind <> cl_abap_typedescr=>kind_struct.
      INSERT condense( CONV string( is_row ) ) INTO TABLE lt_values.
    ELSE.
      DATA(lv_index) = 0.
      DO.
        lv_index += 1.
        ASSIGN COMPONENT lv_index OF STRUCTURE is_row TO FIELD-SYMBOL(<lv_value>).
        IF sy-subrc <> 0.
          EXIT.
        ENDIF.
        DATA(lo_component) = cl_abap_typedescr=>describe_by_data( <lv_value> ).
        IF lo_component->kind <> cl_abap_typedescr=>kind_elem.
          " tables and references are not configuration values
          CONTINUE.
        ENDIF.
        INSERT condense( |{ <lv_value> }| ) INTO TABLE lt_values.
      ENDDO.
    ENDIF.
    rv_line = concat_lines_of( table = lt_values sep = gc_separator ).
  ENDMETHOD.

ENDCLASS.
