*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_param.clas.testclasses.abap
*& Purpose:
*& Unit tests of check parameter parsing (PCRE pattern lists, validation,
*& safe integers); does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | PCRE lists: items kept as PCRE patterns, blank list empty, invalid pattern raises E373.
*& 2026-11-07 | Row caps: default, maintained value, ceiling, not positive (shared fake ZCL_CD_OPS_PARAMS_MEM).
*& 2026-11-07 | Row caps over ZCA_PARAM (ZCL_CD_OPS_PARAM_SEED): the definition default applies when unset.
*&---------------------------------------------------------------------*
CLASS ltc_param DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    METHODS list_items_are_pcre FOR TESTING.
    METHODS blank_list_gives_no_pattern FOR TESTING.
    METHODS invalid_pattern_is_refused FOR TESTING.
    METHODS text_int_uses_default FOR TESTING.
    METHODS cap_default_when_unset FOR TESTING.
    METHODS cap_from_parameter FOR TESTING.
    METHODS cap_cut_at_ceiling FOR TESTING.
    METHODS cap_not_positive_is_default FOR TESTING.
    METHODS teardown.
    "! Inject parameters with HCK_MAX_JOB_ROWS = iv_value (blank = not maintained)
    METHODS given_job_rows
      IMPORTING
        iv_value TYPE string.

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

  METHOD teardown.
    zcl_cd_ops_injector=>reset( ).
  ENDMETHOD.


  METHOD given_job_rows.
    DATA(lo_params) = NEW zcl_cd_ops_param_seed( ).
    IF iv_value IS NOT INITIAL.
      lo_params->set( iv_name = zif_cd_hck_types=>gc_param-max_job_rows iv_value = iv_value ).
    ENDIF.
    zcl_cd_ops_injector=>inject_params( lo_params->params( ) ).
  ENDMETHOD.


  " Rule: without a parameter the delivered default applies
  METHOD cap_default_when_unset.
    given_job_rows( `` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_param=>job_rows_cap( )
                                        exp = zif_cd_hck_types=>gc_param_default-max_job_rows
                                        msg = 'Unset cap must be the default' ).
  ENDMETHOD.


  " Rule: a maintained cap below the ceiling is used as is
  METHOD cap_from_parameter.
    given_job_rows( `12000` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_param=>job_rows_cap( )
                                        exp = 12000
                                        msg = 'The maintained cap must be used' ).
  ENDMETHOD.


  " Rule: the constant stays the hard ceiling - a larger parameter is cut
  METHOD cap_cut_at_ceiling.
    given_job_rows( `999999` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_param=>job_rows_cap( )
                                        exp = zif_cd_hck_types=>gc_max_job_rows
                                        msg = 'A cap above the ceiling must be cut' ).
  ENDMETHOD.


  " Rule: zero or a negative value never switches the cap off
  METHOD cap_not_positive_is_default.
    given_job_rows( `0` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_param=>job_rows_cap( )
                                        exp = zif_cd_hck_types=>gc_param_default-max_job_rows
                                        msg = 'A cap of 0 must give the default' ).
  ENDMETHOD.

ENDCLASS.
