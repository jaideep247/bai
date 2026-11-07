*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param_validator.clas.testclasses.abap
*& Purpose:
*& Unit tests of the validation rules (pure logic; DDIC / class checks use
*& RTTI on SAP objects that exist in every system: T000, CL_ABAP_TYPEDESCR,
*& CX_SY_ZERODIVIDE, IF_MESSAGE). The validator never raises, so the test
*& methods need no TRY wrapper. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
CLASS ltc_validator DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_area TYPE zif_ca_param_types=>ty_area VALUE 'ZTEST'.
    CONSTANTS gc_name TYPE zif_ca_param_types=>ty_name VALUE 'P1'.

    DATA mo_cut TYPE REF TO zcl_ca_param_validator.

    METHODS setup.

    METHODS definition
      IMPORTING
        iv_value_type        TYPE zif_ca_param_types=>ty_value_type
        iv_kind              TYPE zif_ca_param_types=>ty_kind DEFAULT zif_ca_param_types=>gc_kind-single
      RETURNING
        VALUE(rs_definition) TYPE zif_ca_param_types=>ty_definition.

    "! Message number of check_value for one value
    METHODS value_msgno
      IMPORTING
        is_definition   TYPE zif_ca_param_types=>ty_definition
        iv_value        TYPE zif_ca_param_types=>ty_value
      RETURNING
        VALUE(rv_msgno) TYPE symsgno.

    "! Message numbers of check_definition
    METHODS definition_msgnos
      IMPORTING
        is_definition    TYPE zif_ca_param_types=>ty_definition
      RETURNING
        VALUE(rt_msgnos) TYPE string_table.

    METHODS blank_is_always_valid FOR TESTING.
    METHODS int_valid FOR TESTING.
    METHODS int_not_a_number FOR TESTING.
    METHODS int_overflow FOR TESTING.
    METHODS int_below_min FOR TESTING.
    METHODS int_above_max FOR TESTING.
    METHODS dec_valid_and_invalid FOR TESTING.
    METHODS bool_only_upper_x FOR TESTING.
    METHODS date_valid FOR TESTING.
    METHODS date_impossible_day FOR TESTING.
    METHODS date_limits FOR TESTING.
    METHODS time_valid_and_invalid FOR TESTING.
    METHODS pcre_value_compiles FOR TESTING.
    METHODS allowed_pcre_whole_value FOR TESTING.
    METHODS allowed_pcre_ignores_case FOR TESTING.
    METHODS allowed_pcre_per_list_item FOR TESTING.
    METHODS ddic_existing_table FOR TESTING.
    METHODS ddic_unknown_type FOR TESTING.
    METHODS ddic_class_is_not_ddic FOR TESTING.
    METHODS ddic_name_injection FOR TESTING.
    METHODS class_existing FOR TESTING.
    METHODS class_unknown FOR TESTING.
    METHODS class_with_interface FOR TESTING.
    METHODS class_without_interface FOR TESTING.
    METHODS row_single_with_high FOR TESTING.
    METHODS row_select_bt_needs_high FOR TESTING.
    METHODS row_select_eq_no_high FOR TESTING.
    METHODS row_select_bad_sign FOR TESTING.
    METHODS row_select_valid_interval FOR TESTING.
    METHODS row_checks_low_value FOR TESTING.
    METHODS def_valid_has_no_message FOR TESTING.
    METHODS def_name_kind_type_invalid FOR TESTING.
    METHODS def_list_needs_single FOR TESTING.
    METHODS def_limits_only_for_numbers FOR TESTING.
    METHODS def_min_above_max FOR TESTING.
    METHODS def_interface_rules FOR TESTING.
    METHODS def_pattern_rules FOR TESTING.
    METHODS def_default_is_validated FOR TESTING.
    METHODS area_name_invalid FOR TESTING.
    METHODS split_list_drops_blanks FOR TESTING.
ENDCLASS.


CLASS ltc_validator IMPLEMENTATION.

  METHOD setup.
    mo_cut = NEW #( ).
  ENDMETHOD.


  METHOD definition.
    rs_definition-area       = gc_area.
    rs_definition-name       = gc_name.
    rs_definition-kind       = iv_kind.
    rs_definition-value_type = iv_value_type.
  ENDMETHOD.


  METHOD value_msgno.
    rv_msgno = mo_cut->check_value( is_definition = is_definition
                                    iv_value      = iv_value )-msgno.
  ENDMETHOD.


  METHOD definition_msgnos.
    LOOP AT mo_cut->check_definition( is_definition ) ASSIGNING FIELD-SYMBOL(<ls_message>).
      INSERT CONV string( <ls_message>-msgno ) INTO TABLE rt_msgnos.
    ENDLOOP.
  ENDMETHOD.


  METHOD blank_is_always_valid.
    cl_abap_unit_assert=>assert_initial(
      act = value_msgno( is_definition = definition( zif_ca_param_types=>gc_value_type-int ) iv_value = space )
      msg = `A blank value is "no value", never a type error` ).
  ENDMETHOD.


  METHOD int_valid.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-int ).
    cl_abap_unit_assert=>assert_initial( act = value_msgno( is_definition = ls_definition iv_value = ' -42' )
                                         msg = `Signed integer with leading blank is valid` ).
  ENDMETHOD.


  METHOD int_not_a_number.
    cl_abap_unit_assert=>assert_equals(
      act = value_msgno( is_definition = definition( zif_ca_param_types=>gc_value_type-int ) iv_value = 'abc' )
      exp = zif_ca_param_types=>gc_msg-type_invalid
      msg = `Text is not an integer: message 006 instead of a conversion dump` ).
  ENDMETHOD.


  METHOD int_overflow.
    cl_abap_unit_assert=>assert_equals(
      act = value_msgno( is_definition = definition( zif_ca_param_types=>gc_value_type-int ) iv_value = '2147483648' )
      exp = zif_ca_param_types=>gc_msg-type_invalid
      msg = `A number outside type i is not a valid INT` ).
  ENDMETHOD.


  METHOD int_below_min.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-int ).
    ls_definition-min_value = '10'.
    cl_abap_unit_assert=>assert_equals( act = value_msgno( is_definition = ls_definition iv_value = '9' )
                                        exp = zif_ca_param_types=>gc_msg-below_min
                                        msg = `9 is below the minimum 10` ).
    cl_abap_unit_assert=>assert_initial( act = value_msgno( is_definition = ls_definition iv_value = '10' )
                                         msg = `The minimum itself is allowed` ).
  ENDMETHOD.


  METHOD int_above_max.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-int ).
    ls_definition-max_value = '100'.
    cl_abap_unit_assert=>assert_equals( act = value_msgno( is_definition = ls_definition iv_value = '101' )
                                        exp = zif_ca_param_types=>gc_msg-above_max
                                        msg = `101 is above the maximum 100 (numeric, not text compare)` ).
    cl_abap_unit_assert=>assert_initial( act = value_msgno( is_definition = ls_definition iv_value = '99' )
                                         msg = `99 is below the maximum 100 (numeric compare)` ).
  ENDMETHOD.


  METHOD dec_valid_and_invalid.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-dec ).
    ls_definition-max_value = '1.5'.
    cl_abap_unit_assert=>assert_initial( act = value_msgno( is_definition = ls_definition iv_value = '1.25' )
                                         msg = `1.25 is a valid decimal below 1.5` ).
    cl_abap_unit_assert=>assert_equals( act = value_msgno( is_definition = ls_definition iv_value = '1,25' )
                                        exp = zif_ca_param_types=>gc_msg-type_invalid
                                        msg = `Decimal comma is not valid (decimal point only)` ).
    cl_abap_unit_assert=>assert_equals( act = value_msgno( is_definition = ls_definition iv_value = '1.75' )
                                        exp = zif_ca_param_types=>gc_msg-above_max
                                        msg = `1.75 is above 1.5` ).
  ENDMETHOD.


  METHOD bool_only_upper_x.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-bool ).
    cl_abap_unit_assert=>assert_initial( act = value_msgno( is_definition = ls_definition iv_value = 'X' )
                                         msg = `X is on` ).
    cl_abap_unit_assert=>assert_equals( act = value_msgno( is_definition = ls_definition iv_value = 'Y' )
                                        exp = zif_ca_param_types=>gc_msg-type_invalid
                                        msg = `Only X or blank are BOOL values` ).
  ENDMETHOD.


  METHOD date_valid.
    cl_abap_unit_assert=>assert_initial(
      act = value_msgno( is_definition = definition( zif_ca_param_types=>gc_value_type-date ) iv_value = '20240229' )
      msg = `29 February of a leap year is valid` ).
  ENDMETHOD.


  METHOD date_impossible_day.
    cl_abap_unit_assert=>assert_equals(
      act = value_msgno( is_definition = definition( zif_ca_param_types=>gc_value_type-date ) iv_value = '20260230' )
      exp = zif_ca_param_types=>gc_msg-type_invalid
      msg = `30 February is not a date` ).
  ENDMETHOD.


  METHOD date_limits.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-date ).
    ls_definition-min_value = '20260101'.
    cl_abap_unit_assert=>assert_equals( act = value_msgno( is_definition = ls_definition iv_value = '20251231' )
                                        exp = zif_ca_param_types=>gc_msg-below_min
                                        msg = `A date before the minimum date` ).
  ENDMETHOD.


  METHOD time_valid_and_invalid.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-time ).
    cl_abap_unit_assert=>assert_initial( act = value_msgno( is_definition = ls_definition iv_value = '235959' )
                                         msg = `23:59:59 is a time` ).
    cl_abap_unit_assert=>assert_equals( act = value_msgno( is_definition = ls_definition iv_value = '240000' )
                                        exp = zif_ca_param_types=>gc_msg-type_invalid
                                        msg = `24:00:00 is not a time` ).
  ENDMETHOD.


  METHOD pcre_value_compiles.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-pcre ).
    cl_abap_unit_assert=>assert_initial( act = value_msgno( is_definition = ls_definition iv_value = '^FILE_[0-9]+$' )
                                         msg = `A valid PCRE` ).
    cl_abap_unit_assert=>assert_equals( act = value_msgno( is_definition = ls_definition iv_value = '([A-Z]' )
                                        exp = zif_ca_param_types=>gc_msg-type_invalid
                                        msg = `An unbalanced bracket is not a PCRE` ).
  ENDMETHOD.


  METHOD allowed_pcre_whole_value.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-char ).
    ls_definition-allowed_pcre = '[A-Z]+'.
    cl_abap_unit_assert=>assert_equals( act = value_msgno( is_definition = ls_definition iv_value = 'ABC1' )
                                        exp = zif_ca_param_types=>gc_msg-pattern_mismatch
                                        msg = `The pattern must match the whole value, not a part` ).
  ENDMETHOD.


  METHOD allowed_pcre_ignores_case.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-char ).
    ls_definition-allowed_pcre = '[A-Z]+'.
    cl_abap_unit_assert=>assert_initial( act = value_msgno( is_definition = ls_definition iv_value = 'abc' )
                                         msg = `The allowed pattern ignores case` ).
  ENDMETHOD.


  METHOD allowed_pcre_per_list_item.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-list ).
    ls_definition-allowed_pcre = '[0-9]{4}'.
    cl_abap_unit_assert=>assert_initial( act = value_msgno( is_definition = ls_definition iv_value = '1000, 2000;3000' )
                                         msg = `Every list element matches` ).
    cl_abap_unit_assert=>assert_equals( act = value_msgno( is_definition = ls_definition iv_value = '1000,20' )
                                        exp = zif_ca_param_types=>gc_msg-pattern_mismatch
                                        msg = `One element does not match` ).
  ENDMETHOD.


  METHOD ddic_existing_table.
    cl_abap_unit_assert=>assert_initial(
      act = value_msgno( is_definition = definition( zif_ca_param_types=>gc_value_type-ddic ) iv_value = 'T000' )
      msg = `T000 exists in every system` ).
  ENDMETHOD.


  METHOD ddic_unknown_type.
    cl_abap_unit_assert=>assert_equals(
      act = value_msgno( is_definition = definition( zif_ca_param_types=>gc_value_type-ddic ) iv_value = 'ZCA_NO_SUCH_TABLE_9' )
      exp = zif_ca_param_types=>gc_msg-ddic_unknown
      msg = `An unknown DDIC name is rejected` ).
  ENDMETHOD.


  METHOD ddic_class_is_not_ddic.
    cl_abap_unit_assert=>assert_equals(
      act = value_msgno( is_definition = definition( zif_ca_param_types=>gc_value_type-ddic ) iv_value = 'CL_ABAP_TYPEDESCR' )
      exp = zif_ca_param_types=>gc_msg-ddic_unknown
      msg = `A class is not a DDIC type` ).
  ENDMETHOD.


  METHOD ddic_name_injection.
    cl_abap_unit_assert=>assert_equals(
      act = value_msgno( is_definition = definition( zif_ca_param_types=>gc_value_type-ddic ) iv_value = 'T000 WHERE 1 = 1' )
      exp = zif_ca_param_types=>gc_msg-type_invalid
      msg = `Only a repository name is accepted, never an SQL fragment` ).
  ENDMETHOD.


  METHOD class_existing.
    cl_abap_unit_assert=>assert_initial(
      act = value_msgno( is_definition = definition( zif_ca_param_types=>gc_value_type-class ) iv_value = 'CL_ABAP_TYPEDESCR' )
      msg = `CL_ABAP_TYPEDESCR exists` ).
  ENDMETHOD.


  METHOD class_unknown.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-class ).
    cl_abap_unit_assert=>assert_equals( act = value_msgno( is_definition = ls_definition iv_value = 'ZCL_CA_NO_SUCH_CLASS_9' )
                                        exp = zif_ca_param_types=>gc_msg-class_unknown
                                        msg = `An unknown class is rejected` ).
    cl_abap_unit_assert=>assert_equals( act = value_msgno( is_definition = ls_definition iv_value = 'T000' )
                                        exp = zif_ca_param_types=>gc_msg-class_unknown
                                        msg = `A table is not a class` ).
  ENDMETHOD.


  METHOD class_with_interface.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-class ).
    ls_definition-interface_name = 'IF_MESSAGE'.
    cl_abap_unit_assert=>assert_initial( act = value_msgno( is_definition = ls_definition iv_value = 'CX_SY_ZERODIVIDE' )
                                         msg = `CX_SY_ZERODIVIDE implements IF_MESSAGE (inherited from CX_ROOT)` ).
  ENDMETHOD.


  METHOD class_without_interface.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-class ).
    ls_definition-interface_name = 'IF_MESSAGE'.
    cl_abap_unit_assert=>assert_equals( act = value_msgno( is_definition = ls_definition iv_value = 'CL_ABAP_TYPEDESCR' )
                                        exp = zif_ca_param_types=>gc_msg-class_no_intf
                                        msg = `CL_ABAP_TYPEDESCR does not implement IF_MESSAGE` ).
  ENDMETHOD.


  METHOD row_single_with_high.
    DATA ls_row TYPE zif_ca_param_types=>ty_value_row.

    ls_row-numb = '0001'.
    ls_row-low  = 'A'.
    ls_row-high = 'B'.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->check_row( is_definition = definition( zif_ca_param_types=>gc_value_type-char ) is_row = ls_row )-msgno
      exp = zif_ca_param_types=>gc_msg-row_invalid
      msg = `A single value has no HIGH` ).
  ENDMETHOD.


  METHOD row_select_bt_needs_high.
    DATA ls_row TYPE zif_ca_param_types=>ty_value_row.

    ls_row-numb = '0001'.
    ls_row-sign = zif_ca_param_types=>gc_sign-include.
    ls_row-opti = zif_ca_param_types=>gc_option-bt.
    ls_row-low  = 'A'.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->check_row( is_definition = definition( iv_value_type = zif_ca_param_types=>gc_value_type-char
                                                           iv_kind       = zif_ca_param_types=>gc_kind-select )
                               is_row        = ls_row )-msgno
      exp = zif_ca_param_types=>gc_msg-row_invalid
      msg = `BT needs HIGH` ).
  ENDMETHOD.


  METHOD row_select_eq_no_high.
    DATA ls_row TYPE zif_ca_param_types=>ty_value_row.

    ls_row-numb = '0001'.
    ls_row-sign = zif_ca_param_types=>gc_sign-include.
    ls_row-opti = zif_ca_param_types=>gc_option-eq.
    ls_row-low  = 'A'.
    ls_row-high = 'B'.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->check_row( is_definition = definition( iv_value_type = zif_ca_param_types=>gc_value_type-char
                                                           iv_kind       = zif_ca_param_types=>gc_kind-select )
                               is_row        = ls_row )-msgno
      exp = zif_ca_param_types=>gc_msg-row_invalid
      msg = `EQ takes no HIGH` ).
  ENDMETHOD.


  METHOD row_select_bad_sign.
    DATA ls_row TYPE zif_ca_param_types=>ty_value_row.

    ls_row-numb = '0001'.
    ls_row-sign = 'X'.
    ls_row-opti = zif_ca_param_types=>gc_option-eq.
    ls_row-low  = 'A'.
    cl_abap_unit_assert=>assert_equals(
      act = mo_cut->check_row( is_definition = definition( iv_value_type = zif_ca_param_types=>gc_value_type-char
                                                           iv_kind       = zif_ca_param_types=>gc_kind-select )
                               is_row        = ls_row )-msgno
      exp = zif_ca_param_types=>gc_msg-row_invalid
      msg = `Sign must be I or E` ).
  ENDMETHOD.


  METHOD row_select_valid_interval.
    DATA ls_row TYPE zif_ca_param_types=>ty_value_row.

    ls_row-numb = '0001'.
    ls_row-sign = zif_ca_param_types=>gc_sign-exclude.
    ls_row-opti = zif_ca_param_types=>gc_option-bt.
    ls_row-low  = '10'.
    ls_row-high = '20'.
    cl_abap_unit_assert=>assert_initial(
      act = mo_cut->check_row( is_definition = definition( iv_value_type = zif_ca_param_types=>gc_value_type-int
                                                           iv_kind       = zif_ca_param_types=>gc_kind-select )
                               is_row        = ls_row )
      msg = `E BT 10 20 is a valid row` ).
  ENDMETHOD.


  METHOD row_checks_low_value.
    DATA ls_row TYPE zif_ca_param_types=>ty_value_row.

    ls_row-numb = '0001'.
    ls_row-sign = zif_ca_param_types=>gc_sign-include.
    ls_row-opti = zif_ca_param_types=>gc_option-eq.
    ls_row-low  = 'abc'.
    DATA(ls_message) = mo_cut->check_row(
                         is_definition = definition( iv_value_type = zif_ca_param_types=>gc_value_type-int
                                                     iv_kind       = zif_ca_param_types=>gc_kind-select )
                         is_row        = ls_row ).
    cl_abap_unit_assert=>assert_equals( act = ls_message-msgno
                                        exp = zif_ca_param_types=>gc_msg-type_invalid
                                        msg = `LOW is validated against the value type` ).
    cl_abap_unit_assert=>assert_equals( act = ls_message-field
                                        exp = zif_ca_param_types=>gc_field-low
                                        msg = `The message points to LOW` ).
  ENDMETHOD.


  METHOD def_valid_has_no_message.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-int ).
    ls_definition-min_value     = '1'.
    ls_definition-max_value     = '50'.
    ls_definition-default_value = '10'.
    cl_abap_unit_assert=>assert_initial( act = mo_cut->check_definition( ls_definition )
                                         msg = `A consistent definition has no message` ).
  ENDMETHOD.


  METHOD def_name_kind_type_invalid.
    DATA(ls_definition) = definition( 'NUM' ).
    ls_definition-name = '1BAD-NAME'.
    ls_definition-kind = 'X'.
    cl_abap_unit_assert=>assert_equals(
      act = definition_msgnos( ls_definition )
      exp = VALUE string_table( ( CONV string( zif_ca_param_types=>gc_msg-name_invalid ) )
                                ( CONV string( zif_ca_param_types=>gc_msg-kind_invalid ) )
                                ( CONV string( zif_ca_param_types=>gc_msg-vtype_invalid ) ) )
      msg = `Name, kind and value type are reported together` ).
  ENDMETHOD.


  METHOD def_list_needs_single.
    cl_abap_unit_assert=>assert_equals(
      act = definition_msgnos( definition( iv_value_type = zif_ca_param_types=>gc_value_type-list
                                           iv_kind       = zif_ca_param_types=>gc_kind-select ) )
      exp = VALUE string_table( ( CONV string( zif_ca_param_types=>gc_msg-list_needs_single ) ) )
      msg = `LIST is a single value; a select-option is a list by itself` ).
  ENDMETHOD.


  METHOD def_limits_only_for_numbers.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-char ).
    ls_definition-min_value = 'A'.
    cl_abap_unit_assert=>assert_equals(
      act = definition_msgnos( ls_definition )
      exp = VALUE string_table( ( CONV string( zif_ca_param_types=>gc_msg-field_not_allowed ) ) )
      msg = `CHAR has no minimum` ).
  ENDMETHOD.


  METHOD def_min_above_max.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-int ).
    ls_definition-min_value = '20'.
    ls_definition-max_value = '3'.
    cl_abap_unit_assert=>assert_equals(
      act = definition_msgnos( ls_definition )
      exp = VALUE string_table( ( CONV string( zif_ca_param_types=>gc_msg-min_above_max ) ) )
      msg = `Minimum 20 above maximum 3 (numeric compare)` ).
  ENDMETHOD.


  METHOD def_interface_rules.
    DATA(ls_int) = definition( zif_ca_param_types=>gc_value_type-int ).
    ls_int-interface_name = 'IF_MESSAGE'.
    cl_abap_unit_assert=>assert_equals(
      act = definition_msgnos( ls_int )
      exp = VALUE string_table( ( CONV string( zif_ca_param_types=>gc_msg-field_not_allowed ) ) )
      msg = `An interface only for value type CLASS` ).
    DATA(ls_class) = definition( zif_ca_param_types=>gc_value_type-class ).
    ls_class-interface_name = 'ZIF_CA_NO_SUCH_INTF_9'.
    cl_abap_unit_assert=>assert_equals(
      act = definition_msgnos( ls_class )
      exp = VALUE string_table( ( CONV string( zif_ca_param_types=>gc_msg-intf_unknown ) ) )
      msg = `The interface must exist` ).
  ENDMETHOD.


  METHOD def_pattern_rules.
    DATA(ls_char) = definition( zif_ca_param_types=>gc_value_type-char ).
    ls_char-allowed_pcre = '([A-Z]'.
    cl_abap_unit_assert=>assert_equals(
      act = definition_msgnos( ls_char )
      exp = VALUE string_table( ( CONV string( zif_ca_param_types=>gc_msg-pattern_invalid ) ) )
      msg = `The allowed pattern must compile` ).
    DATA(ls_bool) = definition( zif_ca_param_types=>gc_value_type-bool ).
    ls_bool-allowed_pcre = 'X'.
    cl_abap_unit_assert=>assert_equals(
      act = definition_msgnos( ls_bool )
      exp = VALUE string_table( ( CONV string( zif_ca_param_types=>gc_msg-field_not_allowed ) ) )
      msg = `No pattern for BOOL` ).
  ENDMETHOD.


  METHOD def_default_is_validated.
    DATA(ls_definition) = definition( zif_ca_param_types=>gc_value_type-int ).
    ls_definition-default_value = 'ten'.
    DATA(lt_messages) = mo_cut->check_definition( ls_definition ).
    cl_abap_unit_assert=>assert_equals( act = lines( lt_messages )
                                        exp = 1
                                        msg = `One message for the invalid default` ).
    cl_abap_unit_assert=>assert_equals( act = lt_messages[ 1 ]-field
                                        exp = zif_ca_param_types=>gc_field-default_value
                                        msg = `The message points to the default value` ).
  ENDMETHOD.


  METHOD area_name_invalid.
    DATA ls_area TYPE zif_ca_param_types=>ty_area_row.

    ls_area-area = 'Z-AREA'.
    cl_abap_unit_assert=>assert_equals( act = lines( mo_cut->check_area( ls_area ) )
                                        exp = 1
                                        msg = `A hyphen is not allowed in an area name` ).
  ENDMETHOD.


  METHOD split_list_drops_blanks.
    cl_abap_unit_assert=>assert_equals( act = mo_cut->split_list( ` A, B;; C ,` )
                                        exp = VALUE string_table( ( `A` ) ( `B` ) ( `C` ) )
                                        msg = `Comma and semicolon split, elements condensed, blanks dropped` ).
  ENDMETHOD.

ENDCLASS.
