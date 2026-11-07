*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_validator.clas.abap
*& Purpose:
*& Validation rules of the parameter framework, used by the runtime
*& (ZCL_CA_PARAM, on every read) and by the maintenance app (on save), so
*& both apply exactly the same rules. Checks names, definitions (kind,
*& value type, min / max, default, allowed PCRE, interface), value rows
*& (sign / option / high per kind) and values (type, min / max, allowed
*& PCRE matched to the whole value ignoring case, DDIC type existence and
*& class existence + interface via RTTI). Returns messages of class
*& ZCA_PARAM (initial = valid); it never raises and never reads tables.
*& A blank value is valid here (no value / BOOL off); whether blank is
*& acceptable is decided by the caller (mandatory, typed getters).
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Parameter framework - validation rules</p>
CLASS zcl_ca_param_validator DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    "! Area master row: the area name is an identifier
    METHODS check_area
      IMPORTING
        is_area            TYPE zif_ca_param_types=>ty_area_row
      RETURNING
        VALUE(rt_messages) TYPE zif_ca_param_types=>tt_message.

    "! Definition: name, kind, value type, limits, interface, pattern, default
    METHODS check_definition
      IMPORTING
        is_definition      TYPE zif_ca_param_types=>ty_definition
      RETURNING
        VALUE(rt_messages) TYPE zif_ca_param_types=>tt_message.

    "! One value row: sign / option / high for the kind, then LOW and HIGH as values
    METHODS check_row
      IMPORTING
        is_definition     TYPE zif_ca_param_types=>ty_definition
        is_row            TYPE zif_ca_param_types=>ty_value_row
      RETURNING
        VALUE(rs_message) TYPE zif_ca_param_types=>ty_message.

    "! One value: type, min / max, allowed pattern, DDIC / class existence (blank = valid)
    METHODS check_value
      IMPORTING
        is_definition     TYPE zif_ca_param_types=>ty_definition
        iv_value          TYPE zif_ca_param_types=>ty_value
      RETURNING
        VALUE(rs_message) TYPE zif_ca_param_types=>ty_message.

    "! Upper-case identifier (area, parameter name): A-Z, 0-9, _, starting with a letter
    METHODS is_identifier
      IMPORTING
        iv_name         TYPE csequence
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! Elements of a LIST value: split at comma / semicolon, condensed, blanks dropped
    METHODS split_list
      IMPORTING
        iv_value       TYPE csequence
      RETURNING
        VALUE(rt_list) TYPE zif_ca_param_types=>tt_list.

  PRIVATE SECTION.
    METHODS message
      IMPORTING
        is_definition     TYPE zif_ca_param_types=>ty_definition
        iv_msgno          TYPE symsgno
        iv_v3             TYPE csequence OPTIONAL
        iv_v4             TYPE csequence OPTIONAL
        iv_field          TYPE zif_ca_param_types=>ty_field OPTIONAL
      RETURNING
        VALUE(rs_message) TYPE zif_ca_param_types=>ty_message.

    METHODS check_type
      IMPORTING
        is_definition     TYPE zif_ca_param_types=>ty_definition
        iv_value          TYPE zif_ca_param_types=>ty_value
      RETURNING
        VALUE(rs_message) TYPE zif_ca_param_types=>ty_message.

    METHODS check_limits
      IMPORTING
        is_definition     TYPE zif_ca_param_types=>ty_definition
        iv_value          TYPE zif_ca_param_types=>ty_value
      RETURNING
        VALUE(rs_message) TYPE zif_ca_param_types=>ty_message.

    METHODS check_pattern
      IMPORTING
        is_definition     TYPE zif_ca_param_types=>ty_definition
        iv_value          TYPE zif_ca_param_types=>ty_value
      RETURNING
        VALUE(rs_message) TYPE zif_ca_param_types=>ty_message.

    METHODS check_repository
      IMPORTING
        is_definition     TYPE zif_ca_param_types=>ty_definition
        iv_value          TYPE zif_ca_param_types=>ty_value
      RETURNING
        VALUE(rs_message) TYPE zif_ca_param_types=>ty_message.

    "! Definition check of MIN_VALUE / MAX_VALUE
    METHODS check_limit_fields
      IMPORTING
        is_definition      TYPE zif_ca_param_types=>ty_definition
      RETURNING
        VALUE(rt_messages) TYPE zif_ca_param_types=>tt_message.

    "! -1 / 0 / 1 for left < = > right (numbers for INT / DEC, text for DATE / TIME)
    METHODS compare
      IMPORTING
        iv_value_type    TYPE zif_ca_param_types=>ty_value_type
        iv_left          TYPE zif_ca_param_types=>ty_value
        iv_right         TYPE zif_ca_param_types=>ty_value
      RETURNING
        VALUE(rv_result) TYPE i
      RAISING
        cx_sy_conversion_error
        cx_sy_arithmetic_error.

    METHODS to_decimal
      IMPORTING
        iv_value        TYPE zif_ca_param_types=>ty_value
      RETURNING
        VALUE(rv_value) TYPE zif_ca_param_types=>ty_decimal
      RAISING
        cx_sy_conversion_error
        cx_sy_arithmetic_error.

    METHODS is_int
      IMPORTING
        iv_value        TYPE zif_ca_param_types=>ty_value
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    "! Converts to decfloat34 without error (no overflow)
    METHODS is_decimal
      IMPORTING
        iv_value        TYPE zif_ca_param_types=>ty_value
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS is_date
      IMPORTING
        iv_value        TYPE zif_ca_param_types=>ty_value
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS is_pcre
      IMPORTING
        iv_pattern      TYPE csequence
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS is_value_type
      IMPORTING
        iv_value_type   TYPE zif_ca_param_types=>ty_value_type
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

    METHODS is_interface
      IMPORTING
        iv_name         TYPE csequence
      RETURNING
        VALUE(rv_valid) TYPE abap_bool.

ENDCLASS.



CLASS zcl_ca_param_validator IMPLEMENTATION.

  METHOD check_area.
    IF is_identifier( is_area-area ) = abap_false.
      INSERT VALUE #( msgid = zif_ca_param_types=>gc_msgid
                      msgno = zif_ca_param_types=>gc_msg-name_invalid
                      v1    = is_area-area
                      v3    = is_area-area
                      field = zif_ca_param_types=>gc_field-area ) INTO TABLE rt_messages.
    ENDIF.
  ENDMETHOD.


  METHOD check_definition.
    IF is_identifier( is_definition-name ) = abap_false.
      INSERT message( is_definition = is_definition
                      iv_msgno      = zif_ca_param_types=>gc_msg-name_invalid
                      iv_v3         = is_definition-name
                      iv_field      = zif_ca_param_types=>gc_field-name ) INTO TABLE rt_messages.
    ENDIF.
    IF is_definition-kind <> zif_ca_param_types=>gc_kind-single
       AND is_definition-kind <> zif_ca_param_types=>gc_kind-select.
      INSERT message( is_definition = is_definition
                      iv_msgno      = zif_ca_param_types=>gc_msg-kind_invalid
                      iv_v3         = is_definition-kind
                      iv_field      = zif_ca_param_types=>gc_field-kind ) INTO TABLE rt_messages.
    ENDIF.
    IF is_value_type( is_definition-value_type ) = abap_false.
      " every further rule depends on the value type
      INSERT message( is_definition = is_definition
                      iv_msgno      = zif_ca_param_types=>gc_msg-vtype_invalid
                      iv_v3         = is_definition-value_type
                      iv_field      = zif_ca_param_types=>gc_field-value_type ) INTO TABLE rt_messages.
      RETURN.
    ENDIF.
    IF is_definition-value_type = zif_ca_param_types=>gc_value_type-list
       AND is_definition-kind = zif_ca_param_types=>gc_kind-select.
      INSERT message( is_definition = is_definition
                      iv_msgno      = zif_ca_param_types=>gc_msg-list_needs_single
                      iv_field      = zif_ca_param_types=>gc_field-kind ) INTO TABLE rt_messages.
    ENDIF.

    INSERT LINES OF check_limit_fields( is_definition ) INTO TABLE rt_messages.

    IF is_definition-interface_name IS NOT INITIAL.
      IF is_definition-value_type <> zif_ca_param_types=>gc_value_type-class.
        INSERT message( is_definition = is_definition
                        iv_msgno      = zif_ca_param_types=>gc_msg-field_not_allowed
                        iv_v3         = zif_ca_param_types=>gc_field-interface_name
                        iv_v4         = is_definition-value_type
                        iv_field      = zif_ca_param_types=>gc_field-interface_name ) INTO TABLE rt_messages.
      ELSEIF is_interface( is_definition-interface_name ) = abap_false.
        INSERT message( is_definition = is_definition
                        iv_msgno      = zif_ca_param_types=>gc_msg-intf_unknown
                        iv_v3         = is_definition-interface_name
                        iv_field      = zif_ca_param_types=>gc_field-interface_name ) INTO TABLE rt_messages.
      ENDIF.
    ENDIF.

    IF is_definition-allowed_pcre IS NOT INITIAL.
      IF is_definition-value_type = zif_ca_param_types=>gc_value_type-bool.
        INSERT message( is_definition = is_definition
                        iv_msgno      = zif_ca_param_types=>gc_msg-field_not_allowed
                        iv_v3         = zif_ca_param_types=>gc_field-allowed_pcre
                        iv_v4         = is_definition-value_type
                        iv_field      = zif_ca_param_types=>gc_field-allowed_pcre ) INTO TABLE rt_messages.
      ELSEIF is_pcre( is_definition-allowed_pcre ) = abap_false.
        INSERT message( is_definition = is_definition
                        iv_msgno      = zif_ca_param_types=>gc_msg-pattern_invalid
                        iv_v3         = is_definition-allowed_pcre
                        iv_field      = zif_ca_param_types=>gc_field-allowed_pcre ) INTO TABLE rt_messages.
      ENDIF.
    ENDIF.

    " the default must be a valid value itself (only when the rules above hold)
    IF rt_messages IS INITIAL AND is_definition-default_value IS NOT INITIAL.
      DATA(ls_message) = check_value( is_definition = is_definition
                                      iv_value      = is_definition-default_value ).
      IF ls_message IS NOT INITIAL.
        ls_message-field = zif_ca_param_types=>gc_field-default_value.
        INSERT ls_message INTO TABLE rt_messages.
      ENDIF.
    ENDIF.
  ENDMETHOD.


  METHOD check_limit_fields.
    IF is_definition-min_value IS INITIAL AND is_definition-max_value IS INITIAL.
      RETURN.
    ENDIF.
    CASE is_definition-value_type.
      WHEN zif_ca_param_types=>gc_value_type-int
        OR zif_ca_param_types=>gc_value_type-dec
        OR zif_ca_param_types=>gc_value_type-date
        OR zif_ca_param_types=>gc_value_type-time.
        DATA(ls_min) = check_type( is_definition = is_definition
                                   iv_value      = is_definition-min_value ).
        IF ls_min IS NOT INITIAL.
          ls_min-field = zif_ca_param_types=>gc_field-min_value.
          INSERT ls_min INTO TABLE rt_messages.
        ENDIF.
        DATA(ls_max) = check_type( is_definition = is_definition
                                   iv_value      = is_definition-max_value ).
        IF ls_max IS NOT INITIAL.
          ls_max-field = zif_ca_param_types=>gc_field-max_value.
          INSERT ls_max INTO TABLE rt_messages.
        ENDIF.
        IF rt_messages IS NOT INITIAL OR is_definition-min_value IS INITIAL OR is_definition-max_value IS INITIAL.
          RETURN.
        ENDIF.
        TRY.
            IF compare( iv_value_type = is_definition-value_type
                        iv_left       = is_definition-min_value
                        iv_right      = is_definition-max_value ) > 0.
              INSERT message( is_definition = is_definition
                              iv_msgno      = zif_ca_param_types=>gc_msg-min_above_max
                              iv_v3         = is_definition-min_value
                              iv_v4         = is_definition-max_value
                              iv_field      = zif_ca_param_types=>gc_field-max_value ) INTO TABLE rt_messages.
            ENDIF.
          CATCH cx_sy_conversion_error cx_sy_arithmetic_error.
            INSERT message( is_definition = is_definition
                            iv_msgno      = zif_ca_param_types=>gc_msg-type_invalid
                            iv_v3         = is_definition-max_value
                            iv_v4         = is_definition-value_type
                            iv_field      = zif_ca_param_types=>gc_field-max_value ) INTO TABLE rt_messages.
        ENDTRY.
      WHEN OTHERS.
        INSERT message( is_definition = is_definition
                        iv_msgno      = zif_ca_param_types=>gc_msg-field_not_allowed
                        iv_v3         = COND #( WHEN is_definition-min_value IS NOT INITIAL
                                                THEN zif_ca_param_types=>gc_field-min_value
                                                ELSE zif_ca_param_types=>gc_field-max_value )
                        iv_v4         = is_definition-value_type
                        iv_field      = COND #( WHEN is_definition-min_value IS NOT INITIAL
                                                THEN zif_ca_param_types=>gc_field-min_value
                                                ELSE zif_ca_param_types=>gc_field-max_value ) ) INTO TABLE rt_messages.
    ENDCASE.
  ENDMETHOD.


  METHOD check_row.
    DATA(lv_row_text) = |{ is_row-sign } { is_row-opti } { is_row-high }|.
    CASE is_definition-kind.
      WHEN zif_ca_param_types=>gc_kind-single.
        " a single value is LOW; sign / option may be blank or I / EQ, HIGH stays blank
        IF ( is_row-sign IS NOT INITIAL AND is_row-sign <> zif_ca_param_types=>gc_sign-include )
           OR ( is_row-opti IS NOT INITIAL AND is_row-opti <> zif_ca_param_types=>gc_option-eq )
           OR is_row-high IS NOT INITIAL.
          rs_message = message( is_definition = is_definition
                                iv_msgno      = zif_ca_param_types=>gc_msg-row_invalid
                                iv_v3         = is_row-numb
                                iv_v4         = lv_row_text
                                iv_field      = zif_ca_param_types=>gc_field-high ).
          RETURN.
        ENDIF.
      WHEN zif_ca_param_types=>gc_kind-select.
        DATA(lv_interval) = xsdbool( is_row-opti = zif_ca_param_types=>gc_option-bt
                                     OR is_row-opti = zif_ca_param_types=>gc_option-nb ).
        IF ( is_row-sign <> zif_ca_param_types=>gc_sign-include AND is_row-sign <> zif_ca_param_types=>gc_sign-exclude )
           OR ( lv_interval = abap_false
                AND is_row-opti <> zif_ca_param_types=>gc_option-eq AND is_row-opti <> zif_ca_param_types=>gc_option-ne
                AND is_row-opti <> zif_ca_param_types=>gc_option-gt AND is_row-opti <> zif_ca_param_types=>gc_option-ge
                AND is_row-opti <> zif_ca_param_types=>gc_option-lt AND is_row-opti <> zif_ca_param_types=>gc_option-le )
           OR ( lv_interval = abap_true AND is_row-high IS INITIAL )
           OR ( lv_interval = abap_false AND is_row-high IS NOT INITIAL ).
          rs_message = message( is_definition = is_definition
                                iv_msgno      = zif_ca_param_types=>gc_msg-row_invalid
                                iv_v3         = is_row-numb
                                iv_v4         = lv_row_text
                                iv_field      = zif_ca_param_types=>gc_field-opti ).
          RETURN.
        ENDIF.
      WHEN OTHERS.
        rs_message = message( is_definition = is_definition
                              iv_msgno      = zif_ca_param_types=>gc_msg-kind_invalid
                              iv_v3         = is_definition-kind
                              iv_field      = zif_ca_param_types=>gc_field-kind ).
        RETURN.
    ENDCASE.

    rs_message = check_value( is_definition = is_definition
                              iv_value      = is_row-low ).
    IF rs_message IS NOT INITIAL.
      rs_message-field = zif_ca_param_types=>gc_field-low.
      RETURN.
    ENDIF.
    rs_message = check_value( is_definition = is_definition
                              iv_value      = is_row-high ).
    IF rs_message IS NOT INITIAL.
      rs_message-field = zif_ca_param_types=>gc_field-high.
    ENDIF.
  ENDMETHOD.


  METHOD check_value.
    IF iv_value IS INITIAL.
      RETURN.
    ENDIF.
    rs_message = check_type( is_definition = is_definition
                             iv_value      = iv_value ).
    IF rs_message IS INITIAL.
      rs_message = check_limits( is_definition = is_definition
                                 iv_value      = iv_value ).
    ENDIF.
    IF rs_message IS INITIAL.
      rs_message = check_pattern( is_definition = is_definition
                                  iv_value      = iv_value ).
    ENDIF.
    IF rs_message IS INITIAL.
      " RTTI last: the most expensive check
      rs_message = check_repository( is_definition = is_definition
                                     iv_value      = iv_value ).
    ENDIF.
  ENDMETHOD.


  METHOD check_type.
    DATA lv_valid TYPE abap_bool.

    IF iv_value IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_text) = condense( CONV string( iv_value ) ).
    CASE is_definition-value_type.
      WHEN zif_ca_param_types=>gc_value_type-int.
        lv_valid = is_int( iv_value ).
      WHEN zif_ca_param_types=>gc_value_type-dec.
        lv_valid = xsdbool( matches( val = lv_text pcre = zif_ca_param_types=>gc_pcre-dec )
                            AND is_decimal( iv_value ) = abap_true ).
      WHEN zif_ca_param_types=>gc_value_type-bool.
        lv_valid = xsdbool( iv_value = zif_ca_param_types=>gc_true ).
      WHEN zif_ca_param_types=>gc_value_type-date.
        lv_valid = is_date( iv_value ).
      WHEN zif_ca_param_types=>gc_value_type-time.
        lv_valid = xsdbool( matches( val = lv_text pcre = zif_ca_param_types=>gc_pcre-time ) ).
      WHEN zif_ca_param_types=>gc_value_type-char
        OR zif_ca_param_types=>gc_value_type-list.
        lv_valid = abap_true.
      WHEN zif_ca_param_types=>gc_value_type-pcre.
        lv_valid = is_pcre( iv_value ).
      WHEN zif_ca_param_types=>gc_value_type-ddic
        OR zif_ca_param_types=>gc_value_type-class.
        " a repository name only - never a fragment of dynamic code; existence: check_repository
        lv_valid = xsdbool( matches( val = lv_text pcre = zif_ca_param_types=>gc_pcre-repository ) ).
      WHEN OTHERS.
        rs_message = message( is_definition = is_definition
                              iv_msgno      = zif_ca_param_types=>gc_msg-vtype_invalid
                              iv_v3         = is_definition-value_type
                              iv_field      = zif_ca_param_types=>gc_field-value_type ).
        RETURN.
    ENDCASE.
    IF lv_valid = abap_false.
      rs_message = message( is_definition = is_definition
                            iv_msgno      = zif_ca_param_types=>gc_msg-type_invalid
                            iv_v3         = iv_value
                            iv_v4         = is_definition-value_type ).
    ENDIF.
  ENDMETHOD.


  METHOD check_limits.
    CASE is_definition-value_type.
      WHEN zif_ca_param_types=>gc_value_type-int
        OR zif_ca_param_types=>gc_value_type-dec
        OR zif_ca_param_types=>gc_value_type-date
        OR zif_ca_param_types=>gc_value_type-time.
      WHEN OTHERS.
        RETURN.
    ENDCASE.
    TRY.
        IF is_definition-min_value IS NOT INITIAL.
          rs_message = check_type( is_definition = is_definition
                                   iv_value      = is_definition-min_value ).
          IF rs_message IS INITIAL
             AND compare( iv_value_type = is_definition-value_type
                          iv_left       = iv_value
                          iv_right      = is_definition-min_value ) < 0.
            rs_message = message( is_definition = is_definition
                                  iv_msgno      = zif_ca_param_types=>gc_msg-below_min
                                  iv_v3         = iv_value
                                  iv_v4         = is_definition-min_value ).
          ENDIF.
          IF rs_message IS NOT INITIAL.
            RETURN.
          ENDIF.
        ENDIF.
        IF is_definition-max_value IS NOT INITIAL.
          rs_message = check_type( is_definition = is_definition
                                   iv_value      = is_definition-max_value ).
          IF rs_message IS INITIAL
             AND compare( iv_value_type = is_definition-value_type
                          iv_left       = iv_value
                          iv_right      = is_definition-max_value ) > 0.
            rs_message = message( is_definition = is_definition
                                  iv_msgno      = zif_ca_param_types=>gc_msg-above_max
                                  iv_v3         = iv_value
                                  iv_v4         = is_definition-max_value ).
          ENDIF.
        ENDIF.
      CATCH cx_sy_conversion_error cx_sy_arithmetic_error.
        rs_message = message( is_definition = is_definition
                              iv_msgno      = zif_ca_param_types=>gc_msg-type_invalid
                              iv_v3         = iv_value
                              iv_v4         = is_definition-value_type ).
    ENDTRY.
  ENDMETHOD.


  METHOD check_pattern.
    IF is_definition-allowed_pcre IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_elements) = COND zif_ca_param_types=>tt_list(
                          WHEN is_definition-value_type = zif_ca_param_types=>gc_value_type-list
                          THEN split_list( iv_value )
                          ELSE VALUE #( ( CONV string( iv_value ) ) ) ).
    DATA(lv_pattern) = CONV string( is_definition-allowed_pcre ).
    LOOP AT lt_elements ASSIGNING FIELD-SYMBOL(<lv_element>).
      TRY.
          IF NOT matches( val = <lv_element> pcre = lv_pattern case = abap_false ).
            rs_message = message( is_definition = is_definition
                                  iv_msgno      = zif_ca_param_types=>gc_msg-pattern_mismatch
                                  iv_v3         = <lv_element> ).
            RETURN.
          ENDIF.
        CATCH cx_sy_regex.
          rs_message = message( is_definition = is_definition
                                iv_msgno      = zif_ca_param_types=>gc_msg-pattern_invalid
                                iv_v3         = is_definition-allowed_pcre
                                iv_field      = zif_ca_param_types=>gc_field-allowed_pcre ).
          RETURN.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.


  METHOD check_repository.
    DATA lo_type TYPE REF TO cl_abap_typedescr.

    CASE is_definition-value_type.
      WHEN zif_ca_param_types=>gc_value_type-ddic
        OR zif_ca_param_types=>gc_value_type-class.
      WHEN OTHERS.
        RETURN.
    ENDCASE.
    DATA(lv_name) = condense( CONV string( iv_value ) ).
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = lv_name
      RECEIVING
        p_descr_ref    = lo_type
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    DATA(lv_found) = xsdbool( sy-subrc = 0 AND lo_type IS BOUND ).

    IF is_definition-value_type = zif_ca_param_types=>gc_value_type-ddic.
      IF lv_found = abap_false OR lo_type->is_ddic_type( ) = abap_false.
        rs_message = message( is_definition = is_definition
                              iv_msgno      = zif_ca_param_types=>gc_msg-ddic_unknown
                              iv_v3         = lv_name ).
      ENDIF.
      RETURN.
    ENDIF.

    IF lv_found = abap_false OR lo_type->kind <> cl_abap_typedescr=>kind_class.
      rs_message = message( is_definition = is_definition
                            iv_msgno      = zif_ca_param_types=>gc_msg-class_unknown
                            iv_v3         = lv_name ).
      RETURN.
    ENDIF.
    IF is_definition-interface_name IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_interface) = condense( CONV string( is_definition-interface_name ) ).
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = lv_interface
      RECEIVING
        p_descr_ref    = lo_type
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0 OR lo_type IS NOT BOUND OR lo_type->kind <> cl_abap_typedescr=>kind_intf.
      rs_message = message( is_definition = is_definition
                            iv_msgno      = zif_ca_param_types=>gc_msg-intf_unknown
                            iv_v3         = lv_interface ).
      RETURN.
    ENDIF.
    TRY.
        " VERIFY-ADT: CL_ABAP_INTFDESCR=>APPLIES_TO_CLASS( p_classname ) (also inherited interfaces)
        IF CAST cl_abap_intfdescr( lo_type )->applies_to_class( CONV #( lv_name ) ) = abap_false.
          rs_message = message( is_definition = is_definition
                                iv_msgno      = zif_ca_param_types=>gc_msg-class_no_intf
                                iv_v3         = lv_name
                                iv_v4         = lv_interface ).
        ENDIF.
      CATCH cx_sy_move_cast_error.
        rs_message = message( is_definition = is_definition
                              iv_msgno      = zif_ca_param_types=>gc_msg-intf_unknown
                              iv_v3         = lv_interface ).
    ENDTRY.
  ENDMETHOD.


  METHOD compare.
    CASE iv_value_type.
      WHEN zif_ca_param_types=>gc_value_type-int
        OR zif_ca_param_types=>gc_value_type-dec.
        DATA(lv_left) = to_decimal( iv_left ).
        DATA(lv_right) = to_decimal( iv_right ).
        rv_result = COND #( WHEN lv_left < lv_right THEN -1
                            WHEN lv_left > lv_right THEN 1
                            ELSE 0 ).
      WHEN OTHERS.
        " DATE / TIME: fixed-width digits compare as text
        DATA(lv_left_text) = condense( CONV string( iv_left ) ).
        DATA(lv_right_text) = condense( CONV string( iv_right ) ).
        rv_result = COND #( WHEN lv_left_text < lv_right_text THEN -1
                            WHEN lv_left_text > lv_right_text THEN 1
                            ELSE 0 ).
    ENDCASE.
  ENDMETHOD.


  METHOD to_decimal.
    rv_value = condense( CONV string( iv_value ) ).
  ENDMETHOD.


  METHOD is_int.
    DATA(lv_text) = condense( CONV string( iv_value ) ).
    IF NOT matches( val = lv_text pcre = zif_ca_param_types=>gc_pcre-int ).
      RETURN.
    ENDIF.
    TRY.
        DATA(lv_number) = to_decimal( iv_value ).
        rv_valid = xsdbool( lv_number >= zif_ca_param_types=>gc_int_min
                            AND lv_number <= zif_ca_param_types=>gc_int_max ).
      CATCH cx_sy_conversion_error cx_sy_arithmetic_error.
        rv_valid = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD is_decimal.
    TRY.
        to_decimal( iv_value ).
        rv_valid = abap_true.
      CATCH cx_sy_conversion_error cx_sy_arithmetic_error.
        rv_valid = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD is_date.
    DATA lv_date TYPE d.
    DATA lv_days TYPE i.

    DATA(lv_text) = condense( CONV string( iv_value ) ).
    IF NOT matches( val = lv_text pcre = zif_ca_param_types=>gc_pcre-date ).
      RETURN.
    ENDIF.
    lv_date = lv_text.
    " an invalid date (e.g. 20260230) converts to 0 days
    lv_days = lv_date.
    rv_valid = xsdbool( lv_days > 0 ).
  ENDMETHOD.


  METHOD is_pcre.
    TRY.
        cl_abap_regex=>create_pcre( pattern     = CONV string( iv_pattern )
                                    ignore_case = abap_true ).
        rv_valid = abap_true.
      CATCH cx_sy_regex.
        rv_valid = abap_false.
    ENDTRY.
  ENDMETHOD.


  METHOD is_value_type.
    CASE iv_value_type.
      WHEN zif_ca_param_types=>gc_value_type-int
        OR zif_ca_param_types=>gc_value_type-dec
        OR zif_ca_param_types=>gc_value_type-char
        OR zif_ca_param_types=>gc_value_type-bool
        OR zif_ca_param_types=>gc_value_type-date
        OR zif_ca_param_types=>gc_value_type-time
        OR zif_ca_param_types=>gc_value_type-list
        OR zif_ca_param_types=>gc_value_type-pcre
        OR zif_ca_param_types=>gc_value_type-ddic
        OR zif_ca_param_types=>gc_value_type-class.
        rv_valid = abap_true.
      WHEN OTHERS.
        rv_valid = abap_false.
    ENDCASE.
  ENDMETHOD.


  METHOD is_interface.
    DATA lo_type TYPE REF TO cl_abap_typedescr.

    DATA(lv_name) = condense( CONV string( iv_name ) ).
    IF NOT matches( val = lv_name pcre = zif_ca_param_types=>gc_pcre-repository ).
      RETURN.
    ENDIF.
    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = lv_name
      RECEIVING
        p_descr_ref    = lo_type
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    rv_valid = xsdbool( sy-subrc = 0 AND lo_type IS BOUND AND lo_type->kind = cl_abap_typedescr=>kind_intf ).
  ENDMETHOD.


  METHOD is_identifier.
    rv_valid = xsdbool( matches( val = iv_name pcre = zif_ca_param_types=>gc_pcre-identifier ) ).
  ENDMETHOD.


  METHOD split_list.
    DATA lt_parts TYPE string_table.

    DATA(lv_text) = replace( val  = CONV string( iv_value )
                             pcre = zif_ca_param_types=>gc_pcre-separator
                             with = zif_ca_param_types=>gc_list_separator
                             occ  = 0 ).
    SPLIT lv_text AT zif_ca_param_types=>gc_list_separator INTO TABLE lt_parts.
    LOOP AT lt_parts ASSIGNING FIELD-SYMBOL(<lv_part>).
      DATA(lv_element) = condense( <lv_part> ).
      IF lv_element IS NOT INITIAL.
        INSERT lv_element INTO TABLE rt_list.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD message.
    rs_message = VALUE #( msgid = zif_ca_param_types=>gc_msgid
                          msgno = iv_msgno
                          v1    = is_definition-area
                          v2    = is_definition-name
                          v3    = iv_v3
                          v4    = iv_v4
                          field = iv_field ).
  ENDMETHOD.

ENDCLASS.
