*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_link_query.clas.abap
*& Purpose:
*& Pure logic of one read of the link registry walker: builds the SQL of a
*& link for a set of source rows (target approved for the area, every
*& field of the target checked against its runtime DDIC, the source rows'
*& values transformed and quoted - one IN list for a single EQ condition,
*& OR groups for several, constants, not-initial conditions), attributes
*& the rows read to their source rows, keeps the preferred rows (PREFER),
*& applies the transforms and masks sensitive values. No SQL, no database:
*& ZCL_CA_OPS_LINK_DAO runs what this class built.
*& Modification log:
*& 2026-11-11 | Initial version (link registry and walker).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - link read builder (pure)</p>
"! Security: the target must be approved for the area (ZCA_OPS_TABWL); every field name must exist in
"! the runtime DDIC of the target; character literals go through CL_ABAP_DYN_PRG=>QUOTE, numeric
"! literals must be numbers. A source row with a blank join value never joins (a blank key would
"! match every blank row). Nothing of the configuration is concatenated into SQL unchecked.
CLASS zcl_ca_ops_link_query DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.
    "! A TABLE-FIELD reference split
    TYPES:
      BEGIN OF ty_ref,
        source TYPE zif_ca_ops_link_types=>ty_source,
        field  TYPE zif_ca_ops_link_types=>ty_fieldname,
      END OF ty_ref.

    "! Validated read of a link for the source rows; WHERE_CLAUSE is initial when no source row has a
    "! complete, non-blank join value (nothing to read)
    "! @raising zcx_ca_ops_error | 212 not approved, 213 unknown field, 234 reference of another source,
    "! 214 incomplete condition, 215 transform, 227 a value is not a number of a numeric field
    CLASS-METHODS build
      IMPORTING
        iv_area         TYPE zif_ca_ops_types=>ty_area
        is_target       TYPE zif_ca_ops_link_types=>ty_object
        it_conds        TYPE zif_ca_ops_link_types=>tt_cond
        it_sources      TYPE zif_ca_ops_link_types=>tt_row
        it_select       TYPE zif_ca_ops_link_types=>tt_fieldname
        it_fields       TYPE zif_ca_ops_chk_types=>tt_field
        iv_approved     TYPE abap_bool
      RETURNING
        VALUE(rs_query) TYPE zif_ca_ops_link_types=>ty_query
      RAISING
        zcx_ca_ops_error.

    "! The row read belongs to the source row: every EQ condition's to field equals the source's
    "! transformed from value
    "! @raising zcx_ca_ops_error | 215 transform
    CLASS-METHODS belongs_to
      IMPORTING
        is_row          TYPE zif_ca_ops_link_types=>ty_row
        is_source       TYPE zif_ca_ops_link_types=>ty_row
        it_conds        TYPE zif_ca_ops_link_types=>tt_cond
      RETURNING
        VALUE(rv_match) TYPE abap_bool
      RAISING
        zcx_ca_ops_error.

    "! Of the rows of one source row keep those that meet every PREFER condition - when at least one
    "! does (never "the highest counter"); without PREFER conditions or a preferred row: all rows
    CLASS-METHODS prefer
      IMPORTING
        it_rows        TYPE zif_ca_ops_link_types=>tt_row
        it_conds       TYPE zif_ca_ops_link_types=>tt_cond
      RETURNING
        VALUE(rt_rows) TYPE zif_ca_ops_link_types=>tt_row.

    "! Value of an EQ condition's transform applied to a from value
    "! @raising zcx_ca_ops_error | 215 unknown transform or invalid argument
    CLASS-METHODS transform
      IMPORTING
        iv_value        TYPE clike
        iv_transform    TYPE zif_ca_ops_link_types=>ty_transform
        iv_arg          TYPE zif_ca_ops_link_types=>ty_arg
        iv_link_id      TYPE zif_ca_ops_link_types=>ty_link_id
      RETURNING
        VALUE(rv_value) TYPE string
      RAISING
        zcx_ca_ops_error.

    "! TABLE-FIELD in upper case (source empty when there is no separator)
    CLASS-METHODS split_ref
      IMPORTING
        iv_ref        TYPE zif_ca_ops_link_types=>ty_field_ref
      RETURNING
        VALUE(rs_ref) TYPE ty_ref.

    "! Value of a field of a row (initial when the row has no such field)
    CLASS-METHODS value_of
      IMPORTING
        it_pairs        TYPE zif_ca_ops_link_types=>tt_pair
        iv_field        TYPE clike
      RETURNING
        VALUE(rv_value) TYPE zif_ca_ops_link_types=>ty_key_value.

    "! Masked value: M keeps the last GC_MASK_VISIBLE characters, H masks everything, blank unchanged
    CLASS-METHODS mask
      IMPORTING
        iv_value        TYPE clike
        iv_sensitivity  TYPE zif_ca_ops_link_types=>ty_flag1
      RETURNING
        VALUE(rv_value) TYPE zif_ca_ops_link_types=>ty_key_value.

  PRIVATE SECTION.
    "! A decimal number literal accepted for a numeric field
    CONSTANTS gc_number_pattern TYPE string VALUE `[-+]?[0-9]+(\.[0-9]+)?`.
    "! A transform argument that is a length
    CONSTANTS gc_length_pattern TYPE string VALUE `[1-9][0-9]?`.
    "! A value of digits only (ALPHA adds leading zeros to it)
    CONSTANTS gc_digits_pattern TYPE string VALUE `[0-9]+`.

    CLASS-METHODS field_kind
      IMPORTING
        iv_field       TYPE clike
        is_target      TYPE zif_ca_ops_link_types=>ty_object
        it_fields      TYPE zif_ca_ops_chk_types=>tt_field
      RETURNING
        VALUE(rv_kind) TYPE zif_ca_ops_chk_types=>ty_type_kind
      RAISING
        zcx_ca_ops_error.

    "! Field of a to reference of the target (the reference names the target's source)
    CLASS-METHODS to_field
      IMPORTING
        is_cond         TYPE zif_ca_ops_link_types=>ty_cond
        is_target       TYPE zif_ca_ops_link_types=>ty_object
      RETURNING
        VALUE(rv_field) TYPE zif_ca_ops_link_types=>ty_fieldname
      RAISING
        zcx_ca_ops_error.

    CLASS-METHODS literal
      IMPORTING
        iv_value          TYPE clike
        iv_kind           TYPE zif_ca_ops_chk_types=>ty_type_kind
        is_cond           TYPE zif_ca_ops_link_types=>ty_cond
      RETURNING
        VALUE(rv_literal) TYPE string
      RAISING
        zcx_ca_ops_error.

    CLASS-METHODS initial_literal
      IMPORTING
        iv_kind           TYPE zif_ca_ops_chk_types=>ty_type_kind
      RETURNING
        VALUE(rv_literal) TYPE string.

    CLASS-METHODS is_numeric_kind
      IMPORTING
        iv_kind           TYPE zif_ca_ops_chk_types=>ty_type_kind
      RETURNING
        VALUE(rv_numeric) TYPE abap_bool.

    "! OR groups (or the IN list) of the EQ conditions over the distinct join values of the sources
    CLASS-METHODS join_clause
      IMPORTING
        is_target     TYPE zif_ca_ops_link_types=>ty_object
        it_eq         TYPE zif_ca_ops_link_types=>tt_cond
        it_sources    TYPE zif_ca_ops_link_types=>tt_row
        it_fields     TYPE zif_ca_ops_chk_types=>tt_field
      RETURNING
        VALUE(rv_sql) TYPE string
      RAISING
        zcx_ca_ops_error.

    "! Transformed from values of the EQ conditions of one source row; empty when one is blank
    CLASS-METHODS join_values
      IMPORTING
        is_source        TYPE zif_ca_ops_link_types=>ty_row
        it_eq            TYPE zif_ca_ops_link_types=>tt_cond
      RETURNING
        VALUE(rt_values) TYPE string_table
      RAISING
        zcx_ca_ops_error.

ENDCLASS.



CLASS zcl_ca_ops_link_query IMPLEMENTATION.

  METHOD build.
    DATA lt_eq TYPE zif_ca_ops_link_types=>tt_cond.
    DATA lt_where TYPE string_table.
    DATA lt_literals TYPE string_table.

    IF iv_approved = abap_false.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e212(zca_ops) WITH is_target-object_id is_target-source_name iv_area.
    ENDIF.
    rs_query-source = to_upper( condense( is_target-source_name ) ).

    " Selected fields: the caller's and the to fields of the conditions (rows are matched back by them)
    LOOP AT it_select ASSIGNING FIELD-SYMBOL(<lv_select>).
      INSERT CONV zif_ca_ops_link_types=>ty_fieldname( to_upper( condense( <lv_select> ) ) ) INTO TABLE rs_query-fields.
    ENDLOOP.
    LOOP AT it_conds ASSIGNING FIELD-SYMBOL(<ls_cond>).
      DATA(lv_to) = to_field( is_cond = <ls_cond> is_target = is_target ).
      DATA(lv_kind) = field_kind( iv_field = lv_to is_target = is_target it_fields = it_fields ).
      CASE <ls_cond>-cond_kind.
        WHEN zif_ca_ops_link_types=>gc_cond_kind-eq.
          IF <ls_cond>-from_ref IS INITIAL.
            RAISE EXCEPTION TYPE zcx_ca_ops_error
              MESSAGE e214(zca_ops) WITH <ls_cond>-link_id <ls_cond>-cond_no <ls_cond>-cond_kind.
          ENDIF.
          INSERT <ls_cond> INTO TABLE lt_eq.
          INSERT lv_to INTO TABLE rs_query-fields.
        WHEN zif_ca_ops_link_types=>gc_cond_kind-const.
          CLEAR lt_literals.
          LOOP AT zcl_ca_ops_util=>split_list( <ls_cond>-cond_value ) ASSIGNING FIELD-SYMBOL(<lv_token>).
            INSERT literal( iv_value = <lv_token> iv_kind = lv_kind is_cond = <ls_cond> ) INTO TABLE lt_literals.
          ENDLOOP.
          IF lt_literals IS INITIAL.
            RAISE EXCEPTION TYPE zcx_ca_ops_error
              MESSAGE e214(zca_ops) WITH <ls_cond>-link_id <ls_cond>-cond_no <ls_cond>-cond_kind.
          ENDIF.
          INSERT COND string( WHEN lines( lt_literals ) = 1 THEN |{ lv_to } = { lt_literals[ 1 ] }|
                              ELSE |{ lv_to } IN ( { concat_lines_of( table = lt_literals sep = `, ` ) } )| )
                 INTO TABLE lt_where.
        WHEN zif_ca_ops_link_types=>gc_cond_kind-not_initial.
          INSERT |{ lv_to } <> { initial_literal( lv_kind ) }| INTO TABLE lt_where.
        WHEN zif_ca_ops_link_types=>gc_cond_kind-prefer.
          IF <ls_cond>-cond_value IS INITIAL.
            RAISE EXCEPTION TYPE zcx_ca_ops_error
              MESSAGE e214(zca_ops) WITH <ls_cond>-link_id <ls_cond>-cond_no <ls_cond>-cond_kind.
          ENDIF.
          INSERT lv_to INTO TABLE rs_query-fields.
        WHEN OTHERS.
          RAISE EXCEPTION TYPE zcx_ca_ops_error
            MESSAGE e214(zca_ops) WITH <ls_cond>-link_id <ls_cond>-cond_no <ls_cond>-cond_kind.
      ENDCASE.
    ENDLOOP.
    IF lt_eq IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e214(zca_ops) WITH is_target-object_id space zif_ca_ops_link_types=>gc_cond_kind-eq.
    ENDIF.

    SORT rs_query-fields.
    DELETE ADJACENT DUPLICATES FROM rs_query-fields.
    DELETE rs_query-fields WHERE table_line IS INITIAL.
    LOOP AT rs_query-fields ASSIGNING FIELD-SYMBOL(<lv_field>).
      field_kind( iv_field = <lv_field> is_target = is_target it_fields = it_fields ).
    ENDLOOP.
    rs_query-select_list = concat_lines_of( table = rs_query-fields sep = `, ` ).

    DATA(lv_join) = join_clause( is_target  = is_target
                                 it_eq      = lt_eq
                                 it_sources = it_sources
                                 it_fields  = it_fields ).
    IF lv_join IS INITIAL.
      RETURN.
    ENDIF.
    INSERT lv_join INTO lt_where INDEX 1.
    rs_query-where_clause = concat_lines_of( table = lt_where sep = ` AND ` ).
  ENDMETHOD.


  METHOD join_clause.
    DATA lv_index TYPE i.
    DATA lt_groups TYPE string_table.
    DATA lt_tuples TYPE SORTED TABLE OF string WITH UNIQUE KEY table_line.

    LOOP AT it_sources ASSIGNING FIELD-SYMBOL(<ls_source>).
      DATA(lt_values) = join_values( is_source = <ls_source> it_eq = it_eq ).
      IF lt_values IS INITIAL.
        CONTINUE.
      ENDIF.
      DATA(lt_parts) = VALUE string_table( ).
      lv_index = 0.
      LOOP AT it_eq ASSIGNING FIELD-SYMBOL(<ls_eq>).
        lv_index = lv_index + 1.
        DATA(lv_to) = to_field( is_cond = <ls_eq> is_target = is_target ).
        DATA(lv_value) = lt_values[ lv_index ].
        INSERT |{ lv_to } = { literal( iv_value = lv_value
                                       iv_kind  = field_kind( iv_field = lv_to is_target = is_target it_fields = it_fields )
                                       is_cond  = <ls_eq> ) }| INTO TABLE lt_parts.
      ENDLOOP.
      INSERT concat_lines_of( table = lt_parts sep = ` AND ` ) INTO TABLE lt_tuples.
    ENDLOOP.
    IF lt_tuples IS INITIAL.
      RETURN.
    ENDIF.

    IF lines( it_eq ) = 1.
      " One field: an IN list of the distinct literals
      DATA(lv_field) = to_field( is_cond = it_eq[ 1 ] is_target = is_target ).
      DATA(lv_prefix) = |{ lv_field } = |.
      LOOP AT lt_tuples ASSIGNING FIELD-SYMBOL(<lv_tuple>).
        INSERT substring( val = <lv_tuple> off = strlen( lv_prefix ) ) INTO TABLE lt_groups.
      ENDLOOP.
      rv_sql = |{ lv_field } IN ( { concat_lines_of( table = lt_groups sep = `, ` ) } )|.
      RETURN.
    ENDIF.
    LOOP AT lt_tuples ASSIGNING <lv_tuple>.
      INSERT |( { <lv_tuple> } )| INTO TABLE lt_groups.
    ENDLOOP.
    rv_sql = |( { concat_lines_of( table = lt_groups sep = ` OR ` ) } )|.
  ENDMETHOD.


  METHOD join_values.
    LOOP AT it_eq ASSIGNING FIELD-SYMBOL(<ls_eq>).
      DATA(lv_from) = value_of( it_pairs = is_source-pairs iv_field = split_ref( <ls_eq>-from_ref )-field ).
      DATA(lv_value) = transform( iv_value     = lv_from
                                  iv_transform = <ls_eq>-transform
                                  iv_arg       = <ls_eq>-transform_arg
                                  iv_link_id   = <ls_eq>-link_id ).
      IF lv_from IS INITIAL OR lv_value IS INITIAL.
        CLEAR rt_values.
        RETURN.
      ENDIF.
      INSERT lv_value INTO TABLE rt_values.
    ENDLOOP.
  ENDMETHOD.


  METHOD belongs_to.
    DATA lt_eq TYPE zif_ca_ops_link_types=>tt_cond.
    DATA lv_index TYPE i.

    LOOP AT it_conds ASSIGNING FIELD-SYMBOL(<ls_cond>) WHERE cond_kind = zif_ca_ops_link_types=>gc_cond_kind-eq.
      INSERT <ls_cond> INTO TABLE lt_eq.
    ENDLOOP.
    DATA(lt_values) = join_values( is_source = is_source it_eq = lt_eq ).
    IF lt_values IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT lt_eq ASSIGNING FIELD-SYMBOL(<ls_eq>).
      lv_index = lv_index + 1.
      DATA(lv_row) = CONV string( value_of( it_pairs = is_row-pairs iv_field = split_ref( <ls_eq>-to_ref )-field ) ).
      IF lv_row <> lt_values[ lv_index ].
        RETURN.
      ENDIF.
    ENDLOOP.
    rv_match = abap_true.
  ENDMETHOD.


  METHOD prefer.
    LOOP AT it_rows ASSIGNING FIELD-SYMBOL(<ls_row>).
      DATA(lv_preferred) = abap_true.
      LOOP AT it_conds ASSIGNING FIELD-SYMBOL(<ls_cond>) WHERE cond_kind = zif_ca_ops_link_types=>gc_cond_kind-prefer.
        IF value_of( it_pairs = <ls_row>-pairs iv_field = split_ref( <ls_cond>-to_ref )-field ) <> <ls_cond>-cond_value.
          lv_preferred = abap_false.
        ENDIF.
      ENDLOOP.
      IF lv_preferred = abap_true.
        INSERT <ls_row> INTO TABLE rt_rows.
      ENDIF.
    ENDLOOP.
    IF rt_rows IS INITIAL.
      rt_rows = it_rows.
    ENDIF.
  ENDMETHOD.


  METHOD transform.
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    DATA(lv_arg) = condense( CONV string( iv_arg ) ).
    DATA(lv_length) = 0.
    IF iv_transform = zif_ca_ops_link_types=>gc_transform-alpha
        OR iv_transform = zif_ca_ops_link_types=>gc_transform-left
        OR iv_transform = zif_ca_ops_link_types=>gc_transform-right.
      IF NOT matches( val = lv_arg pcre = gc_length_pattern ).
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e215(zca_ops) WITH iv_link_id iv_transform iv_arg.
      ENDIF.
      lv_length = CONV i( lv_arg ).
    ENDIF.
    CASE iv_transform.
      WHEN zif_ca_ops_link_types=>gc_transform-none.
        rv_value = lv_value.
      WHEN zif_ca_ops_link_types=>gc_transform-alpha.
        " Leading zeros to the length (numeric values only; a value with letters stays as it is)
        rv_value = COND #( WHEN matches( val = lv_value pcre = gc_digits_pattern ) AND strlen( lv_value ) < lv_length
                           THEN repeat( val = `0` occ = lv_length - strlen( lv_value ) ) && lv_value
                           ELSE lv_value ).
      WHEN zif_ca_ops_link_types=>gc_transform-no_zeros.
        rv_value = shift_left( val = lv_value sub = `0` ).
      WHEN zif_ca_ops_link_types=>gc_transform-upper.
        rv_value = to_upper( lv_value ).
      WHEN zif_ca_ops_link_types=>gc_transform-left.
        rv_value = COND #( WHEN strlen( lv_value ) > lv_length THEN substring( val = lv_value len = lv_length )
                           ELSE lv_value ).
      WHEN zif_ca_ops_link_types=>gc_transform-right.
        rv_value = COND #( WHEN strlen( lv_value ) > lv_length
                           THEN substring( val = lv_value off = strlen( lv_value ) - lv_length )
                           ELSE lv_value ).
      WHEN zif_ca_ops_link_types=>gc_transform-prefix.
        rv_value = lv_arg && lv_value.
      WHEN zif_ca_ops_link_types=>gc_transform-suffix.
        rv_value = lv_value && lv_arg.
      WHEN OTHERS.
        RAISE EXCEPTION TYPE zcx_ca_ops_error
          MESSAGE e215(zca_ops) WITH iv_link_id iv_transform iv_arg.
    ENDCASE.
    IF lv_value IS INITIAL.
      CLEAR rv_value.
    ENDIF.
  ENDMETHOD.


  METHOD split_ref.
    DATA(lv_ref) = to_upper( condense( CONV string( iv_ref ) ) ).
    SPLIT lv_ref AT zif_ca_ops_link_types=>gc_ref_separator INTO DATA(lv_source) DATA(lv_field).
    IF lv_field IS INITIAL.
      rs_ref-field = lv_source.
      RETURN.
    ENDIF.
    rs_ref-source = lv_source.
    rs_ref-field  = lv_field.
  ENDMETHOD.


  METHOD value_of.
    DATA(lv_field) = to_upper( condense( CONV string( iv_field ) ) ).
    READ TABLE it_pairs ASSIGNING FIELD-SYMBOL(<ls_pair>) WITH KEY fieldname = lv_field.
    IF sy-subrc = 0.
      rv_value = <ls_pair>-value.
    ENDIF.
  ENDMETHOD.


  METHOD mask.
    DATA(lv_value) = condense( CONV string( iv_value ) ).
    DATA(lv_length) = strlen( lv_value ).
    CASE iv_sensitivity.
      WHEN zif_ca_ops_link_types=>gc_sensitivity-masked.
        rv_value = COND #( WHEN lv_length > zif_ca_ops_link_types=>gc_mask_visible
                           THEN repeat( val = zif_ca_ops_link_types=>gc_mask_char
                                        occ = lv_length - zif_ca_ops_link_types=>gc_mask_visible )
                                && substring( val = lv_value off = lv_length - zif_ca_ops_link_types=>gc_mask_visible )
                           ELSE repeat( val = zif_ca_ops_link_types=>gc_mask_char occ = lv_length ) ).
      WHEN zif_ca_ops_link_types=>gc_sensitivity-hidden.
        rv_value = repeat( val = zif_ca_ops_link_types=>gc_mask_char occ = lv_length ).
      WHEN OTHERS.
        rv_value = lv_value.
    ENDCASE.
  ENDMETHOD.


  METHOD field_kind.
    DATA(lv_field) = CONV zif_ca_ops_chk_types=>ty_fieldname( to_upper( condense( iv_field ) ) ).
    READ TABLE it_fields INTO DATA(ls_field) WITH TABLE KEY fieldname = lv_field.
    IF sy-subrc <> 0 OR lv_field IS INITIAL.
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e213(zca_ops) WITH is_target-object_id lv_field is_target-source_name.
    ENDIF.
    rv_kind = ls_field-type_kind.
  ENDMETHOD.


  METHOD to_field.
    DATA(ls_ref) = split_ref( is_cond-to_ref ).
    IF ls_ref-source <> to_upper( condense( is_target-source_name ) ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e234(zca_ops) WITH is_cond-link_id is_cond-to_ref is_target-object_id is_target-source_name.
    ENDIF.
    rv_field = ls_ref-field.
  ENDMETHOD.


  METHOD literal.
    " trim only - internal blanks of a literal are significant
    DATA(lv_value) = shift_right( val = shift_left( val = CONV string( iv_value ) sub = ` ` ) sub = ` ` ).
    IF is_numeric_kind( iv_kind ) = abap_false.
      rv_literal = cl_abap_dyn_prg=>quote( lv_value ).
      RETURN.
    ENDIF.
    IF NOT matches( val = lv_value pcre = gc_number_pattern ).
      RAISE EXCEPTION TYPE zcx_ca_ops_error
        MESSAGE e227(zca_ops) WITH is_cond-link_id is_cond-cond_no lv_value is_cond-to_ref.
    ENDIF.
    rv_literal = lv_value.
  ENDMETHOD.


  METHOD initial_literal.
    rv_literal = COND #( WHEN is_numeric_kind( iv_kind ) = abap_true THEN `0`
                         WHEN iv_kind = cl_abap_typedescr=>typekind_date THEN cl_abap_dyn_prg=>quote( `00000000` )
                         WHEN iv_kind = cl_abap_typedescr=>typekind_time THEN cl_abap_dyn_prg=>quote( `000000` )
                         ELSE cl_abap_dyn_prg=>quote( ` ` ) ).
  ENDMETHOD.


  METHOD is_numeric_kind.
    rv_numeric = xsdbool( iv_kind = cl_abap_typedescr=>typekind_int OR iv_kind = cl_abap_typedescr=>typekind_int1
                       OR iv_kind = cl_abap_typedescr=>typekind_int2 OR iv_kind = cl_abap_typedescr=>typekind_int8
                       OR iv_kind = cl_abap_typedescr=>typekind_packed OR iv_kind = cl_abap_typedescr=>typekind_float
                       OR iv_kind = cl_abap_typedescr=>typekind_decfloat16
                       OR iv_kind = cl_abap_typedescr=>typekind_decfloat34 ).
  ENDMETHOD.

ENDCLASS.
