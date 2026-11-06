*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_ops_pattern_check.clas.testclasses.abap
*& Purpose:
*& Domain tests of the pattern check and the CP-to-PCRE conversion rule:
*& matched values, values no pattern captures, patterns that capture nothing,
*& invalid patterns, whole-value match; wildcards, metacharacters, CP escapes,
*& blank, PCRE syntax left alone; migration plan (convert, unchanged, invalid,
*& too long, lists). No doubles. Does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (PCRE patterns: pattern check and migration).
*&---------------------------------------------------------------------*
CLASS ltc_pattern_check DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      BEGIN OF gc_test,
        wire_job  TYPE string VALUE `ZCD_PAYM_WIRE_01`,
        ach_job   TYPE string VALUE `ZCD_PAYM_ACH_01`,
        other_job TYPE string VALUE `SAP_REORG_JOBS`,
        wire      TYPE string VALUE `ZCD_PAYM_WIRE_.*`,
        unused    TYPE string VALUE `ZCD_POST_.*`,
        invalid   TYPE string VALUE `ZCD_(PAYM`,
        step      TYPE string VALUE `PAYRUN 010`,
      END OF gc_test.

    METHODS values
      RETURNING
        VALUE(rt_values) TYPE zif_cd_ops_pattern_types=>tt_value.
    METHODS rows_of
      IMPORTING
        is_result     TYPE zif_cd_ops_pattern_types=>ty_check_result
        iv_status     TYPE zif_cd_ops_pattern_types=>ty_status
      RETURNING
        VALUE(rt_rows) TYPE zif_cd_ops_pattern_types=>tt_check_row.
    METHODS migration_row
      IMPORTING
        iv_old        TYPE string
        iv_is_list    TYPE abap_bool DEFAULT abap_false
        iv_max_length TYPE i DEFAULT 30
      RETURNING
        VALUE(rs_row) TYPE zif_cd_ops_pattern_types=>ty_migration.

    METHODS matched_value_names_pattern  FOR TESTING.
    METHODS uncaptured_value_is_listed   FOR TESTING.
    METHODS unused_pattern_is_listed     FOR TESTING.
    METHODS invalid_pattern_is_listed    FOR TESTING.
    METHODS part_of_value_not_captured   FOR TESTING.
    METHODS overlap_counts_patterns      FOR TESTING.
    METHODS star_and_plus_become_pcre    FOR TESTING.
    METHODS metacharacters_are_escaped   FOR TESTING.
    METHODS cp_escape_gives_literal      FOR TESTING.
    METHODS blank_wildcard_stays_blank   FOR TESTING.
    METHODS converted_matches_same_value FOR TESTING.
    METHODS pcre_syntax_is_recognised    FOR TESTING.
    METHODS plan_converts_wildcards      FOR TESTING.
    METHODS plan_keeps_pcre_and_plain    FOR TESTING.
    METHODS plan_refuses_too_long        FOR TESTING.
    METHODS plan_refuses_invalid         FOR TESTING.
    METHODS plan_converts_list_items     FOR TESTING.
    METHODS area_owner_for_authority     FOR TESTING.
    METHODS table_owner_and_entity       FOR TESTING.
ENDCLASS.


CLASS ltc_pattern_check IMPLEMENTATION.

  METHOD values.
    INSERT gc_test-wire_job INTO TABLE rt_values.
    INSERT gc_test-ach_job INTO TABLE rt_values.
    INSERT gc_test-other_job INTO TABLE rt_values.
  ENDMETHOD.


  METHOD rows_of.
    LOOP AT is_result-rows ASSIGNING FIELD-SYMBOL(<ls_row>) WHERE status = iv_status.
      INSERT <ls_row> INTO TABLE rt_rows.
    ENDLOOP.
  ENDMETHOD.


  METHOD migration_row.
    rs_row-table      = zif_cd_ops_pattern_types=>gc_table-job_step.
    rs_row-field      = zif_cd_ops_pattern_types=>gc_field-jobname.
    rs_row-is_list    = iv_is_list.
    rs_row-max_length = iv_max_length.
    rs_row-old        = iv_old.
  ENDMETHOD.


  " The check names, for every value a pattern captures, the pattern and where it is maintained
  METHOD matched_value_names_pattern.
    TRY.
        DATA(ls_result) = zcl_cd_ops_pattern_check=>analyse(
          it_patterns = VALUE #( ( source = gc_test-step pattern = gc_test-wire ) )
          it_values   = values( ) ).
        DATA(lt_matched) = rows_of( is_result = ls_result iv_status = zif_cd_ops_pattern_types=>gc_check-matched ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_matched ) exp = 1 msg = 'One value captured' ).
        cl_abap_unit_assert=>assert_equals( act = lt_matched[ 1 ]-value exp = gc_test-wire_job
                                            msg = 'The wire job is captured' ).
        cl_abap_unit_assert=>assert_equals( act = lt_matched[ 1 ]-source exp = gc_test-step
                                            msg = 'The row names where the pattern is maintained' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-values exp = 3 msg = 'Three values read' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Values no pattern captures are listed: these records would not come
  METHOD uncaptured_value_is_listed.
    TRY.
        DATA(ls_result) = zcl_cd_ops_pattern_check=>analyse(
          it_patterns = VALUE #( ( source = gc_test-step pattern = gc_test-wire ) )
          it_values   = values( ) ).
        DATA(lt_rows) = rows_of( is_result = ls_result iv_status = zif_cd_ops_pattern_types=>gc_check-no_match ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 2 msg = 'Two values not captured' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-unmatched exp = 2 msg = 'Counted in the summary' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-value exp = gc_test-ach_job
                                            msg = 'The ACH job is not captured by the wire pattern' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A pattern that captures none of the values read is listed as unused
  METHOD unused_pattern_is_listed.
    TRY.
        DATA(ls_result) = zcl_cd_ops_pattern_check=>analyse(
          it_patterns = VALUE #( ( source = gc_test-step pattern = gc_test-wire )
                                 ( source = gc_test-step pattern = gc_test-unused ) )
          it_values   = values( ) ).
        DATA(lt_rows) = rows_of( is_result = ls_result iv_status = zif_cd_ops_pattern_types=>gc_check-unused ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_rows ) exp = 1 msg = 'One unused pattern' ).
        cl_abap_unit_assert=>assert_equals( act = lt_rows[ 1 ]-pattern exp = gc_test-unused
                                            msg = 'The posting pattern captures nothing' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-unused exp = 1 msg = 'Counted in the summary' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " An invalid pattern is listed first and never counted as 'no match'
  METHOD invalid_pattern_is_listed.
    TRY.
        DATA(ls_result) = zcl_cd_ops_pattern_check=>analyse(
          it_patterns = VALUE #( ( source = gc_test-step pattern = gc_test-invalid ) )
          it_values   = values( ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-rows[ 1 ]-status
                                            exp = zif_cd_ops_pattern_types=>gc_check-invalid
                                            msg = 'The invalid pattern comes first' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-invalid exp = 1 msg = 'Counted in the summary' ).
        cl_abap_unit_assert=>assert_initial(
          act = rows_of( is_result = ls_result iv_status = zif_cd_ops_pattern_types=>gc_check-unused )
          msg = 'An invalid pattern is not reported as unused' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " The complete value must match: a pattern for the start of the name captures nothing
  METHOD part_of_value_not_captured.
    TRY.
        DATA(ls_result) = zcl_cd_ops_pattern_check=>analyse(
          it_patterns = VALUE #( ( source = gc_test-step pattern = `ZCD_PAYM` ) )
          it_values   = values( ) ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-unmatched exp = 3 msg = 'No value captured' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-unused exp = 1 msg = 'The pattern is unused' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " A value captured by two patterns shows both, each row with the count 2 (overlap)
  METHOD overlap_counts_patterns.
    TRY.
        DATA(ls_result) = zcl_cd_ops_pattern_check=>analyse(
          it_patterns = VALUE #( ( source = gc_test-step pattern = gc_test-wire )
                                 ( source = gc_test-step pattern = `zcd_paym_.*` ) )
          it_values   = values( ) ).
        DATA(lt_matched) = rows_of( is_result = ls_result iv_status = zif_cd_ops_pattern_types=>gc_check-matched ).
        cl_abap_unit_assert=>assert_equals( act = lines( lt_matched ) exp = 3
                                            msg = 'Wire job twice (two patterns), ACH job once' ).
        cl_abap_unit_assert=>assert_equals( act = lt_matched[ 1 ]-hits exp = 2
                                            msg = 'The wire job is captured by two patterns' ).
        cl_abap_unit_assert=>assert_equals( act = lt_matched[ 3 ]-hits exp = 1
                                            msg = 'The ACH job by one (case ignored)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Conversion rule: * -> .*, + -> .
  METHOD star_and_plus_become_pcre.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_pattern_check=>from_wildcard( 'ZCD_PAYM_*' )
                                        exp = `ZCD_PAYM_.*`
                                        msg = '* becomes .*' ).
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_pattern_check=>from_wildcard( 'HCK_C04/*/US0+' )
                                        exp = `HCK_C04/.*/US0.`
                                        msg = '+ becomes .' ).
  ENDMETHOD.


  " Conversion rule: PCRE metacharacters of a CP pattern are literals and are escaped
  METHOD metacharacters_are_escaped.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_pattern_check=>from_wildcard( 'ACH.PNC(1)$*' )
                                        exp = `ACH\.PNC\(1\)\$.*`
                                        msg = '. ( ) $ are escaped' ).
  ENDMETHOD.


  " Conversion rule: the CP escape #x is the literal x (#* a star, ## a hash, trailing # a hash)
  METHOD cp_escape_gives_literal.
    cl_abap_unit_assert=>assert_equals( act = zcl_cd_ops_pattern_check=>from_wildcard( 'A#*B##C#' )
                                        exp = `A\*B#C#`
                                        msg = '#* is a literal star, ## and a trailing # a literal hash' ).
  ENDMETHOD.


  " Conversion rule: blank stays blank (each call site keeps its blank meaning)
  METHOD blank_wildcard_stays_blank.
    cl_abap_unit_assert=>assert_initial( act = zcl_cd_ops_pattern_check=>from_wildcard( space )
                                         msg = 'Blank stays blank' ).
  ENDMETHOD.


  " The converted pattern captures the same values the CP wildcard did (case ignored)
  METHOD converted_matches_same_value.
    DATA(lv_pcre) = zcl_cd_ops_pattern_check=>from_wildcard( 'ach_pnc_*.txt' ).
    cl_abap_unit_assert=>assert_true(
      act = zcl_cd_ops_util=>pcre_match( iv_value = 'ACH_PNC_20261106_01.TXT' iv_pattern = lv_pcre )
      msg = 'The converted pattern captures the file' ).
    cl_abap_unit_assert=>assert_false(
      act = zcl_cd_ops_util=>pcre_match( iv_value = 'ACH_PNC_20261106_01XTXT' iv_pattern = lv_pcre )
      msg = 'The literal dot is not any character' ).
  ENDMETHOD.


  " PCRE syntax is recognised, so a pattern is never converted twice
  METHOD pcre_syntax_is_recognised.
    cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_pattern_check=>is_pcre_syntax( 'ZCD_PAYM_.*' )
                                      msg = '.* is PCRE' ).
    cl_abap_unit_assert=>assert_true( act = zcl_cd_ops_pattern_check=>is_pcre_syntax( 'ACH_[0-9]{8}' )
                                      msg = 'Class and quantifier are PCRE' ).
    cl_abap_unit_assert=>assert_false( act = zcl_cd_ops_pattern_check=>is_pcre_syntax( 'ZCD_PAYM_*' )
                                       msg = 'A CP wildcard is not PCRE syntax' ).
  ENDMETHOD.


  " Plan: a CP wildcard row is converted
  METHOD plan_converts_wildcards.
    DATA(lt_plan) = zcl_cd_ops_pattern_check=>plan_migration( VALUE #( ( migration_row( `ZCD_PAYM_*` ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_plan[ 1 ]-status exp = zif_cd_ops_pattern_types=>gc_migration-convert
                                        msg = 'The wildcard row is converted' ).
    cl_abap_unit_assert=>assert_equals( act = lt_plan[ 1 ]-new exp = `ZCD_PAYM_.*`
                                        msg = 'New pattern' ).
  ENDMETHOD.


  " Plan: PCRE rows (migration already run) and plain names are left as they are
  METHOD plan_keeps_pcre_and_plain.
    DATA(lt_plan) = zcl_cd_ops_pattern_check=>plan_migration( VALUE #( ( migration_row( `ZCD_PAYM_.*` ) )
                                                                       ( migration_row( `ZCD_POST_GL` ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_plan[ 1 ]-status
                                        exp = zif_cd_ops_pattern_types=>gc_migration-already_pcre
                                        msg = 'A PCRE row is not converted again' ).
    cl_abap_unit_assert=>assert_equals( act = lt_plan[ 2 ]-status
                                        exp = zif_cd_ops_pattern_types=>gc_migration-unchanged
                                        msg = 'A plain name is the same in both notations' ).
  ENDMETHOD.


  " Plan: a converted pattern longer than the field is refused, never cut
  METHOD plan_refuses_too_long.
    DATA(lt_plan) = zcl_cd_ops_pattern_check=>plan_migration(
      VALUE #( ( migration_row( iv_old = `A*B*C*D*` iv_max_length = 10 ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_plan[ 1 ]-status exp = zif_cd_ops_pattern_types=>gc_migration-too_long
                                        msg = 'A.*B.*C.*D.* (12) does not fit 10 characters' ).
    cl_abap_unit_assert=>assert_not_initial( act = lt_plan[ 1 ]-message msg = 'The reason is given' ).
  ENDMETHOD.


  " Plan: a pattern that does not compile is refused
  METHOD plan_refuses_invalid.
    DATA(lt_plan) = zcl_cd_ops_pattern_check=>plan_migration( VALUE #( ( migration_row( `ZCD_(PAYM` ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_plan[ 1 ]-status exp = zif_cd_ops_pattern_types=>gc_migration-invalid
                                        msg = 'An invalid pattern is never written' ).
  ENDMETHOD.


  " Plan: a parameter list is converted item by item
  METHOD plan_converts_list_items.
    DATA(lt_plan) = zcl_cd_ops_pattern_check=>plan_migration(
      VALUE #( ( migration_row( iv_old = `ZCD_PAYM_*; ZCD_POST_GL` iv_is_list = abap_true iv_max_length = 100 ) ) ) ).
    cl_abap_unit_assert=>assert_equals( act = lt_plan[ 1 ]-status exp = zif_cd_ops_pattern_types=>gc_migration-convert
                                        msg = 'The list converts' ).
    cl_abap_unit_assert=>assert_equals( act = lt_plan[ 1 ]-new exp = `ZCD_PAYM_.*, ZCD_POST_GL`
                                        msg = 'Each item converted, comma separated' ).
  ENDMETHOD.


  " Migration: owner area (authorisation) and RAP entity (transport) of each table; the
  " suppressions are application data, never recorded on a transport
  METHOD table_owner_and_entity.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cd_ops_pattern_check=>pe_area_of_table( zif_cd_ops_pattern_types=>gc_table-fmon_iface )
      exp = zif_cd_ops_types=>gc_pe_area-file_monitor
      msg = 'Interfaces belong to FMON' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cd_ops_pattern_check=>entity_of_table( zif_cd_ops_pattern_types=>gc_table-job_step )
      exp = zif_cd_ops_pattern_types=>gc_entity-job_step
      msg = 'Job steps are recorded as entity JobStep' ).
    cl_abap_unit_assert=>assert_initial(
      act = zcl_cd_ops_pattern_check=>entity_of_table( zif_cd_ops_pattern_types=>gc_table-suppression )
      msg = 'Suppressions are not transported' ).
  ENDMETHOD.


  " Authorisation: each pattern area belongs to one payment engine area
  METHOD area_owner_for_authority.
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cd_ops_pattern_check=>pe_area_of( zif_cd_ops_pattern_types=>gc_area-ebs_flow )
      exp = zif_cd_ops_types=>gc_pe_area-ebs
      msg = 'EBS flow patterns belong to EBS' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cd_ops_pattern_check=>pe_area_of( zif_cd_ops_pattern_types=>gc_area-hck_suppr )
      exp = zif_cd_ops_types=>gc_pe_area-health_check
      msg = 'Suppression keys belong to HCK' ).
    cl_abap_unit_assert=>assert_equals(
      act = zcl_cd_ops_pattern_check=>pe_area_of( zif_cd_ops_pattern_types=>gc_area-alert_grp2 )
      exp = zif_cd_ops_types=>gc_pe_area-core
      msg = 'Alert rule patterns belong to CORE' ).
  ENDMETHOD.

ENDCLASS.
