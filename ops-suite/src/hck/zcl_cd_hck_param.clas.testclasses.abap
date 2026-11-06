*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_param.clas.testclasses.abap
*& Purpose:
*& Unit tests of check parameter parsing (pattern lists to ranges, safe
*& integers); does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
CLASS ltc_param DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS star_pattern_becomes_cp FOR TESTING.
    METHODS blank_list_gives_no_range FOR TESTING.
    METHODS text_int_uses_default FOR TESTING.

ENDCLASS.



CLASS ltc_param IMPLEMENTATION.

  " Rule: '*' or '+' in a token means pattern (CP), otherwise equality (EQ); upper case
  METHOD star_pattern_becomes_cp.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_pattern_range.
    TRY.
        INSERT VALUE #( sign = 'I' option = 'CP' low = 'ZCD_PAYM_*' ) INTO TABLE lt_exp.
        INSERT VALUE #( sign = 'I' option = 'EQ' low = 'ZCD_POST_GL' ) INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_param=>pattern_range( 'zcd_paym_*; ZCD_POST_GL' )
                                            exp = lt_exp
                                            msg = 'List must become CP and EQ rows in upper case' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an empty parameter selects nothing (callers then skip the read)
  METHOD blank_list_gives_no_range.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_pattern_range.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_param=>pattern_range( ' ' )
                                            exp = lt_exp
                                            msg = 'Blank list must give an empty range' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a non-numeric parameter falls back to the default instead of dumping
  METHOD text_int_uses_default.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_param=>int( iv_value = 'ten' iv_default = 10 )
                                            exp = 10
                                            msg = 'Text must fall back to the default' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
