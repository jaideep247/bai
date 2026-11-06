*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_param.clas.testclasses.abap
*& Purpose:
*& Unit tests of check parameter parsing (PCRE pattern lists, validation,
*& safe integers); does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | PCRE lists: items kept as PCRE patterns, blank list empty, invalid pattern raises E373.
*&---------------------------------------------------------------------*
CLASS ltc_param DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS list_items_are_pcre FOR TESTING.
    METHODS blank_list_gives_no_pattern FOR TESTING.
    METHODS invalid_pattern_is_refused FOR TESTING.
    METHODS text_int_uses_default FOR TESTING.

ENDCLASS.



CLASS ltc_param IMPLEMENTATION.

  " Rule: every list item is a PCRE pattern (matched to the complete value, case ignored)
  METHOD list_items_are_pcre.
    DATA lt_exp TYPE zif_cd_ops_types=>tt_pcre.
    TRY.
        INSERT `zcd_paym_.*` INTO TABLE lt_exp.
        INSERT `ZCD_POST_GL` INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_param=>patterns( 'zcd_paym_.*; ZCD_POST_GL' )
                                            exp = lt_exp
                                            msg = 'List must become two PCRE patterns as written' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an empty parameter selects nothing (callers then skip the read)
  METHOD blank_list_gives_no_pattern.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = zcl_cd_hck_param=>patterns( ' ' )
                                             msg = 'Blank list must give no pattern' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a pattern that is not valid PCRE is a configuration error (E373), not an empty selection
  METHOD invalid_pattern_is_refused.
    TRY.
        zcl_cd_hck_param=>check_patterns( it_patterns = zcl_cd_hck_param=>patterns( 'ZCD_.*, ZCD_(PAYM' )
                                          iv_check_id = 'B_TECH_JOBS' ).
        cl_abap_unit_assert=>fail( msg = 'An invalid pattern must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno exp = '373'
                                            msg = 'Message 373 names the invalid pattern' ).
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
