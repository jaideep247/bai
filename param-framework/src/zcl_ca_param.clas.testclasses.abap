*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_param.clas.testclasses.abap
*& Purpose:
*& Unit tests of the read semantics of ZCL_CA_PARAM over the in-memory DAO
*& (ZCL_CA_PARAM_BUILDER / ZCL_CA_PARAM_DAO_MEM): default, mandatory, BOOL
*& on / explicit off / default, single value with two rows, select-option
*& list and range in NUMB order, typed conversion with min / max, allowed
*& PCRE, DDIC and class checks, unknown / inactive area, unknown name,
*& buffer and refresh. Tests of an exception catch ZCX_CA_PARAM and assert
*& the message number. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-07 | Initial version.
*&---------------------------------------------------------------------*
CLASS ltc_param DEFINITION FINAL FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_area TYPE zif_ca_param_types=>ty_area VALUE 'ZTEST'.
    CONSTANTS gc_name TYPE zif_ca_param_types=>ty_name VALUE 'P1'.

    "! Message number raised by one read (initial when the read succeeds)
    METHODS error_of
      IMPORTING
        io_param        TYPE REF TO zif_ca_param
        iv_read_as      TYPE zif_ca_param_types=>ty_value_type
        iv_area         TYPE zif_ca_param_types=>ty_area DEFAULT gc_area
        iv_name         TYPE zif_ca_param_types=>ty_name DEFAULT gc_name
      RETURNING
        VALUE(rv_msgno) TYPE symsgno.

    "! A builder with area ZTEST started
    METHODS given
      RETURNING
        VALUE(ro_builder) TYPE REF TO zcl_ca_param_builder.

    METHODS missing_value_gives_default FOR TESTING.
    METHODS missing_mandatory_raises FOR TESTING.
    METHODS mandatory_with_default_ok FOR TESTING.
    METHODS blank_mandatory_value_raises FOR TESTING.
    METHODS bool_x_is_true FOR TESTING.
    METHODS bool_blank_row_is_off FOR TESTING.
    METHODS bool_missing_gives_default FOR TESTING.
    METHODS single_with_two_rows_raises FOR TESTING.
    METHODS select_list_in_numb_order FOR TESTING.
    METHODS select_range_in_numb_order FOR TESTING.
    METHODS select_default_is_one_row FOR TESTING.
    METHODS select_empty_range FOR TESTING.
    METHODS range_on_single_raises FOR TESTING.
    METHODS value_on_select_raises FOR TESTING.
    METHODS list_value_is_split FOR TESTING.
    METHODS list_needs_eq_rows FOR TESTING.
    METHODS int_is_converted FOR TESTING.
    METHODS int_invalid_raises FOR TESTING.
    METHODS int_above_max_raises FOR TESTING.
    METHODS int_blank_raises FOR TESTING.
    METHODS dec_is_converted FOR TESTING.
    METHODS date_and_time_converted FOR TESTING.
    METHODS type_mismatch_raises FOR TESTING.
    METHODS default_invalid_raises FOR TESTING.
    METHODS invalid_select_row_raises FOR TESTING.
    METHODS allowed_pcre_mismatch FOR TESTING.
    METHODS ddic_value_validated FOR TESTING.
    METHODS class_interface_validated FOR TESTING.
    METHODS unknown_area_raises FOR TESTING.
    METHODS inactive_area_raises FOR TESTING.
    METHODS unknown_name_raises FOR TESTING.
    METHODS name_is_case_insensitive FOR TESTING.
    METHODS is_set_ignores_default FOR TESTING.
    METHODS definition_is_returned FOR TESTING.
    METHODS one_read_per_area FOR TESTING.
    METHODS refresh_reads_again FOR TESTING.
ENDCLASS.


CLASS ltc_param IMPLEMENTATION.

  METHOD given.
    ro_builder = NEW zcl_ca_param_builder( )->area( gc_area ).
  ENDMETHOD.


  METHOD error_of.
    TRY.
        CASE iv_read_as.
          WHEN zif_ca_param_types=>gc_value_type-int.
            io_param->get_int( iv_area = iv_area iv_name = iv_name ).
          WHEN zif_ca_param_types=>gc_value_type-dec.
            io_param->get_dec( iv_area = iv_area iv_name = iv_name ).
          WHEN zif_ca_param_types=>gc_value_type-bool.
            io_param->get_bool( iv_area = iv_area iv_name = iv_name ).
          WHEN zif_ca_param_types=>gc_value_type-date.
            io_param->get_date( iv_area = iv_area iv_name = iv_name ).
          WHEN zif_ca_param_types=>gc_value_type-list.
            io_param->get_list( iv_area = iv_area iv_name = iv_name ).
          WHEN zif_ca_param_types=>gc_read_as-range.
            io_param->get_range( iv_area = iv_area iv_name = iv_name ).
          WHEN OTHERS.
            io_param->get_value( iv_area = iv_area iv_name = iv_name ).
        ENDCASE.
      CATCH zcx_ca_param INTO DATA(lx_error).
        rv_msgno = lx_error->if_t100_message~t100key-msgno.
    ENDTRY.
  ENDMETHOD.


  METHOD missing_value_gives_default.
    TRY.
        DATA(lo_param) = given( )->param( iv_name = gc_name iv_default = 'ABC' )->build( ).
        cl_abap_unit_assert=>assert_equals( act = lo_param->get_value( iv_area = gc_area iv_name = gc_name )
                                            exp = `ABC`
                                            msg = `No value row: the default` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD missing_mandatory_raises.
    DATA(lo_param) = given( )->param( iv_name = gc_name iv_mandatory = abap_true )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-value )
                                        exp = zif_ca_param_types=>gc_msg-mandatory_missing
                                        msg = `Mandatory without value and default: exception, no silent blank` ).
  ENDMETHOD.


  METHOD mandatory_with_default_ok.
    DATA(lo_param) = given( )->param( iv_name = gc_name iv_mandatory = abap_true iv_default = 'D' )->build( ).
    cl_abap_unit_assert=>assert_initial( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-value )
                                         msg = `A default satisfies a mandatory parameter` ).
  ENDMETHOD.


  METHOD blank_mandatory_value_raises.
    DATA(lo_param) = given( )->param( iv_name = gc_name iv_mandatory = abap_true iv_default = 'D' )->row( space )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-value )
                                        exp = zif_ca_param_types=>gc_msg-mandatory_missing
                                        msg = `A blank value row of a mandatory (non-BOOL) parameter is an error` ).
  ENDMETHOD.


  METHOD bool_x_is_true.
    TRY.
        DATA(lo_param) = given( )->param( iv_name = gc_name iv_value_type = zif_ca_param_types=>gc_value_type-bool
                                )->row( zif_ca_param_types=>gc_true )->build( ).
        cl_abap_unit_assert=>assert_true( act = lo_param->get_bool( iv_area = gc_area iv_name = gc_name )
                                          msg = `Row X: on` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD bool_blank_row_is_off.
    TRY.
        DATA(lo_param) = given( )->param( iv_name       = gc_name
                                          iv_value_type = zif_ca_param_types=>gc_value_type-bool
                                          iv_default    = zif_ca_param_types=>gc_true
                                          iv_mandatory  = abap_true )->row( space )->build( ).
        cl_abap_unit_assert=>assert_false( act = lo_param->get_bool( iv_area = gc_area iv_name = gc_name )
                                           msg = `Row with blank LOW switches a flag off, even with default X` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD bool_missing_gives_default.
    TRY.
        DATA(lo_param) = given( )->param( iv_name       = gc_name
                                          iv_value_type = zif_ca_param_types=>gc_value_type-bool
                                          iv_default    = zif_ca_param_types=>gc_true )->build( ).
        cl_abap_unit_assert=>assert_true( act = lo_param->get_bool( iv_area = gc_area iv_name = gc_name )
                                          msg = `No row: the default X` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD single_with_two_rows_raises.
    DATA(lo_param) = given( )->param( gc_name )->row( 'A' )->row( 'B' )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-value )
                                        exp = zif_ca_param_types=>gc_msg-single_multiple
                                        msg = `Two rows of a single value: configuration error, not row 1 by chance` ).
  ENDMETHOD.


  METHOD select_list_in_numb_order.
    DATA ls_row TYPE zif_ca_param_types=>ty_value_row.
    DATA lt_exp TYPE zif_ca_param_types=>tt_list.

    TRY.
        DATA(lo_builder) = given( )->param( iv_name = gc_name iv_kind = zif_ca_param_types=>gc_kind-select ).
        ls_row-area = gc_area.
        ls_row-name = gc_name.
        ls_row-sign = zif_ca_param_types=>gc_sign-include.
        ls_row-opti = zif_ca_param_types=>gc_option-eq.
        ls_row-numb = '0003'.
        ls_row-low  = 'C'.
        lo_builder->dao( )->add_value( ls_row ).
        ls_row-numb = '0001'.
        ls_row-low  = 'A'.
        lo_builder->dao( )->add_value( ls_row ).
        ls_row-numb = '0002'.
        ls_row-low  = 'B'.
        lo_builder->dao( )->add_value( ls_row ).
        lt_exp = VALUE #( ( `A` ) ( `B` ) ( `C` ) ).
        cl_abap_unit_assert=>assert_equals( act = lo_builder->build( )->get_list( iv_area = gc_area iv_name = gc_name )
                                            exp = lt_exp
                                            msg = `List in NUMB order, whatever the insert order` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD select_range_in_numb_order.
    DATA lt_exp TYPE zif_ca_param_types=>tt_range.

    TRY.
        DATA(lo_param) = given( )->param( iv_name       = gc_name
                                          iv_kind       = zif_ca_param_types=>gc_kind-select
                                          iv_value_type = zif_ca_param_types=>gc_value_type-int
                                )->row( iv_low = '10' iv_high = '20' iv_option = zif_ca_param_types=>gc_option-bt
                                )->row( iv_low = '15' iv_sign = zif_ca_param_types=>gc_sign-exclude )->build( ).
        lt_exp = VALUE #( ( sign   = zif_ca_param_types=>gc_sign-include
                            option = zif_ca_param_types=>gc_option-bt
                            low    = '10'
                            high   = '20' )
                          ( sign   = zif_ca_param_types=>gc_sign-exclude
                            option = zif_ca_param_types=>gc_option-eq
                            low    = '15' ) ).
        cl_abap_unit_assert=>assert_equals( act = lo_param->get_range( iv_area = gc_area iv_name = gc_name )
                                            exp = lt_exp
                                            msg = `Range rows with sign, option, low, high in NUMB order` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD select_default_is_one_row.
    DATA lt_exp TYPE zif_ca_param_types=>tt_range.

    TRY.
        DATA(lo_param) = given( )->param( iv_name    = gc_name
                                          iv_kind    = zif_ca_param_types=>gc_kind-select
                                          iv_default = '1000' )->build( ).
        lt_exp = VALUE #( ( sign   = zif_ca_param_types=>gc_sign-include
                            option = zif_ca_param_types=>gc_option-eq
                            low    = '1000' ) ).
        cl_abap_unit_assert=>assert_equals( act = lo_param->get_range( iv_area = gc_area iv_name = gc_name )
                                            exp = lt_exp
                                            msg = `No rows: the default as one I EQ row` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD select_empty_range.
    TRY.
        DATA(lo_param) = given( )->param( iv_name = gc_name iv_kind = zif_ca_param_types=>gc_kind-select )->build( ).
        cl_abap_unit_assert=>assert_initial( act = lo_param->get_range( iv_area = gc_area iv_name = gc_name )
                                             msg = `No rows, no default, not mandatory: empty range` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD range_on_single_raises.
    DATA(lo_param) = given( )->param( gc_name )->row( 'A' )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-range )
                                        exp = zif_ca_param_types=>gc_msg-kind_mismatch
                                        msg = `A single value is not a range` ).
  ENDMETHOD.


  METHOD value_on_select_raises.
    DATA(lo_param) = given( )->param( iv_name = gc_name iv_kind = zif_ca_param_types=>gc_kind-select )->row( 'A' )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-value )
                                        exp = zif_ca_param_types=>gc_msg-kind_mismatch
                                        msg = `A select-option is not a single value` ).
  ENDMETHOD.


  METHOD list_value_is_split.
    DATA lt_exp TYPE zif_ca_param_types=>tt_list.

    TRY.
        DATA(lo_param) = given( )->param( iv_name = gc_name iv_value_type = zif_ca_param_types=>gc_value_type-list
                                )->row( 'A; B ,C' )->build( ).
        lt_exp = VALUE #( ( `A` ) ( `B` ) ( `C` ) ).
        cl_abap_unit_assert=>assert_equals( act = lo_param->get_list( iv_area = gc_area iv_name = gc_name )
                                            exp = lt_exp
                                            msg = `LIST value split at comma and semicolon` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD list_needs_eq_rows.
    DATA(lo_param) = given( )->param( iv_name = gc_name iv_kind = zif_ca_param_types=>gc_kind-select
                            )->row( iv_low = 'A' iv_option = zif_ca_param_types=>gc_option-ne )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_value_type-list )
                                        exp = zif_ca_param_types=>gc_msg-row_not_list
                                        msg = `An NE row cannot be read as a list element` ).
  ENDMETHOD.


  METHOD int_is_converted.
    TRY.
        DATA(lo_param) = given( )->param( iv_name = gc_name iv_value_type = zif_ca_param_types=>gc_value_type-int
                                          iv_min  = '1' iv_max = '100' )->row( '25' )->build( ).
        cl_abap_unit_assert=>assert_equals( act = lo_param->get_int( iv_area = gc_area iv_name = gc_name )
                                            exp = 25
                                            msg = `INT value as type i` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD int_invalid_raises.
    DATA(lo_param) = given( )->param( iv_name = gc_name iv_value_type = zif_ca_param_types=>gc_value_type-int
                            )->row( 'abc' )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_value_type-int )
                                        exp = zif_ca_param_types=>gc_msg-type_invalid
                                        msg = `Text in an INT parameter: exception 006, no conversion dump` ).
  ENDMETHOD.


  METHOD int_above_max_raises.
    DATA(lo_param) = given( )->param( iv_name = gc_name iv_value_type = zif_ca_param_types=>gc_value_type-int
                                      iv_max  = '100' )->row( '101' )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_value_type-int )
                                        exp = zif_ca_param_types=>gc_msg-above_max
                                        msg = `Value above the maximum` ).
  ENDMETHOD.


  METHOD int_blank_raises.
    DATA(lo_param) = given( )->param( iv_name = gc_name iv_value_type = zif_ca_param_types=>gc_value_type-int )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_value_type-int )
                                        exp = zif_ca_param_types=>gc_msg-no_value
                                        msg = `No value and no default: no silent zero` ).
  ENDMETHOD.


  METHOD dec_is_converted.
    TRY.
        DATA(lo_param) = given( )->param( iv_name = gc_name iv_value_type = zif_ca_param_types=>gc_value_type-dec
                                )->row( '1.5' )->build( ).
        cl_abap_unit_assert=>assert_equals( act = lo_param->get_dec( iv_area = gc_area iv_name = gc_name )
                                            exp = CONV zif_ca_param_types=>ty_decimal( '1.5' )
                                            msg = `DEC value as decfloat34` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD date_and_time_converted.
    TRY.
        DATA(lo_param) = given( )->param( iv_name = 'D1' iv_value_type = zif_ca_param_types=>gc_value_type-date
                                )->row( '20261107'
                                )->param( iv_name = 'T1' iv_value_type = zif_ca_param_types=>gc_value_type-time
                                )->row( '133000' )->build( ).
        cl_abap_unit_assert=>assert_equals( act = lo_param->get_date( iv_area = gc_area iv_name = 'D1' )
                                            exp = CONV d( '20261107' )
                                            msg = `DATE value as type d` ).
        cl_abap_unit_assert=>assert_equals( act = lo_param->get_time( iv_area = gc_area iv_name = 'T1' )
                                            exp = CONV t( '133000' )
                                            msg = `TIME value as type t` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD type_mismatch_raises.
    DATA(lo_param) = given( )->param( gc_name )->row( '5' )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_value_type-int )
                                        exp = zif_ca_param_types=>gc_msg-type_mismatch
                                        msg = `A CHAR parameter is not read as INT` ).
  ENDMETHOD.


  METHOD default_invalid_raises.
    DATA(lo_param) = given( )->param( iv_name = gc_name iv_value_type = zif_ca_param_types=>gc_value_type-int
                                      iv_default = 'ten' )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_value_type-int )
                                        exp = zif_ca_param_types=>gc_msg-type_invalid
                                        msg = `The default is validated like a value` ).
  ENDMETHOD.


  METHOD invalid_select_row_raises.
    DATA(lo_param) = given( )->param( iv_name = gc_name iv_kind = zif_ca_param_types=>gc_kind-select
                            )->row( iv_low = 'A' iv_option = zif_ca_param_types=>gc_option-bt )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-range )
                                        exp = zif_ca_param_types=>gc_msg-row_invalid
                                        msg = `BT without HIGH is never returned` ).
  ENDMETHOD.


  METHOD allowed_pcre_mismatch.
    DATA(lo_param) = given( )->param( iv_name = gc_name iv_allowed_pcre = '[A-Z]{3}' )->row( 'ABCD' )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-value )
                                        exp = zif_ca_param_types=>gc_msg-pattern_mismatch
                                        msg = `The allowed pattern matches the whole value only` ).
  ENDMETHOD.


  METHOD ddic_value_validated.
    DATA(lo_param) = given( )->param( iv_name = 'OK' iv_value_type = zif_ca_param_types=>gc_value_type-ddic
                            )->row( 'T000'
                            )->param( iv_name = 'BAD' iv_value_type = zif_ca_param_types=>gc_value_type-ddic
                            )->row( 'ZCA_NO_SUCH_TABLE_9' )->build( ).
    cl_abap_unit_assert=>assert_initial(
      act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-value iv_name = 'OK' )
      msg = `T000 is a DDIC type` ).
    cl_abap_unit_assert=>assert_equals(
      act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-value iv_name = 'BAD' )
      exp = zif_ca_param_types=>gc_msg-ddic_unknown
      msg = `An unknown DDIC name is never handed to dynamic SQL` ).
  ENDMETHOD.


  METHOD class_interface_validated.
    DATA(lo_param) = given( )->param( iv_name       = gc_name
                                      iv_value_type = zif_ca_param_types=>gc_value_type-class
                                      iv_interface  = 'IF_MESSAGE' )->row( 'CL_ABAP_TYPEDESCR' )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-value )
                                        exp = zif_ca_param_types=>gc_msg-class_no_intf
                                        msg = `A class without the required interface is rejected` ).
  ENDMETHOD.


  METHOD unknown_area_raises.
    DATA(lo_param) = given( )->param( gc_name )->build( ).
    cl_abap_unit_assert=>assert_equals(
      act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-value iv_area = 'ZNONE' )
      exp = zif_ca_param_types=>gc_msg-area_unknown
      msg = `Unknown area: exception, never a default` ).
  ENDMETHOD.


  METHOD inactive_area_raises.
    DATA(lo_param) = NEW zcl_ca_param_builder( )->area( iv_area = gc_area iv_active = abap_false
                                                )->param( gc_name )->build( ).
    cl_abap_unit_assert=>assert_equals( act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-value )
                                        exp = zif_ca_param_types=>gc_msg-area_inactive
                                        msg = `Inactive area: exception` ).
  ENDMETHOD.


  METHOD unknown_name_raises.
    DATA(lo_param) = given( )->param( gc_name )->build( ).
    cl_abap_unit_assert=>assert_equals(
      act = error_of( io_param = lo_param iv_read_as = zif_ca_param_types=>gc_read_as-value iv_name = 'P2' )
      exp = zif_ca_param_types=>gc_msg-name_unknown
      msg = `Unknown name: exception, never a default` ).
  ENDMETHOD.


  METHOD name_is_case_insensitive.
    TRY.
        DATA(lo_param) = given( )->param( gc_name )->row( 'V' )->build( ).
        cl_abap_unit_assert=>assert_equals( act = lo_param->get_value( iv_area = 'ztest' iv_name = 'p1' )
                                            exp = `V`
                                            msg = `Area and name are keys in upper case` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD is_set_ignores_default.
    TRY.
        DATA(lo_param) = given( )->param( iv_name = 'SET' )->row( 'V'
                                )->param( iv_name = 'DEFAULT_ONLY' iv_default = 'D' )->build( ).
        cl_abap_unit_assert=>assert_true( act = lo_param->is_set( iv_area = gc_area iv_name = 'SET' )
                                          msg = `A value row is maintained` ).
        cl_abap_unit_assert=>assert_false( act = lo_param->is_set( iv_area = gc_area iv_name = 'DEFAULT_ONLY' )
                                           msg = `A default alone is not maintained` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD definition_is_returned.
    TRY.
        DATA(lo_param) = given( )->param( iv_name = gc_name iv_value_type = zif_ca_param_types=>gc_value_type-int
                                          iv_max  = '9' )->build( ).
        DATA(ls_definition) = lo_param->get_definition( iv_area = gc_area iv_name = gc_name ).
        cl_abap_unit_assert=>assert_equals( act = ls_definition-max_value
                                            exp = '9'
                                            msg = `The definition is returned as maintained` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD one_read_per_area.
    TRY.
        DATA(lo_builder) = given( )->param( 'A' )->row( '1' )->param( 'B' )->row( '2' ).
        DATA(lo_param) = lo_builder->build( ).
        lo_param->get_value( iv_area = gc_area iv_name = 'A' ).
        lo_param->get_value( iv_area = gc_area iv_name = 'B' ).
        cl_abap_unit_assert=>assert_equals( act = lo_builder->dao( )->read_count( )
                                            exp = 1
                                            msg = `One DAO read per area while buffered` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  METHOD refresh_reads_again.
    TRY.
        DATA(lo_builder) = given( )->param( gc_name )->row( 'OLD' ).
        DATA(lo_param) = lo_builder->build( ).
        lo_param->get_value( iv_area = gc_area iv_name = gc_name ).
        lo_builder->dao( )->remove_values( iv_area = gc_area iv_name = gc_name ).
        lo_builder->row( 'NEW' ).
        cl_abap_unit_assert=>assert_equals( act = lo_param->get_value( iv_area = gc_area iv_name = gc_name )
                                            exp = `OLD`
                                            msg = `Buffered until refresh` ).
        lo_param->refresh( gc_area ).
        cl_abap_unit_assert=>assert_equals( act = lo_param->get_value( iv_area = gc_area iv_name = gc_name )
                                            exp = `NEW`
                                            msg = `After refresh the current value` ).
        cl_abap_unit_assert=>assert_equals( act = lo_builder->dao( )->read_count( )
                                            exp = 2
                                            msg = `Refresh causes exactly one new read` ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
