*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_agg_query.clas.testclasses.abap
*& Purpose:
*& Unit tests of generic aggregate validation (whitelist, DDIC fields,
*& operators, literals) and WHERE building; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Expected group set: a missing group measures zero (audit A103).
*& 2026-11-08 | Table consolidation: the HCK whitelist is ZCD_OPS_TABWL (HCK / READ), comments only.
*& 2026-11-08 | Table consolidation: ltc_group_list - expected group list parsed once (trimmed, distinct) and
*&            | validated on save (blank element, repeat, overlong value).
*&---------------------------------------------------------------------*
CLASS ltc_agg_query DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check    TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_RET_AGED',
      gc_agg      TYPE zif_cd_hck_types=>ty_agg_id VALUE 'RET_AGED',
      gc_table    TYPE zif_cd_hck_types=>ty_tabname VALUE 'DFKKOP',
      gc_ref_date TYPE d VALUE '20261105'.

    DATA ms_def TYPE zif_cd_hck_types=>ty_agg_def.
    DATA mt_fields TYPE zif_cd_hck_types=>tt_field.
    DATA mv_whitelisted TYPE abap_bool.

    METHODS setup.
    METHODS builds_aging_where FOR TESTING.
    METHODS rejects_unlisted_table FOR TESTING.
    METHODS rejects_unknown_field FOR TESTING.
    METHODS rejects_unknown_operator FOR TESTING.
    METHODS rejects_text_numeric_field FOR TESTING.
    METHODS rejects_non_date_age_field FOR TESTING.
    METHODS rejects_sum_on_text_field FOR TESTING.
    METHODS escapes_quote_in_literal FOR TESTING.
    METHODS in_list_quotes_each_value FOR TESTING.
    METHODS day_mode_compares_one_date FOR TESTING.
    METHODS no_rows_give_star_zero FOR TESTING.
    METHODS group_rows_become_dims FOR TESTING.
    METHODS missing_expected_group_zero FOR TESTING.
    METHODS no_rows_zero_per_expected FOR TESTING.

    METHODS add_field
      IMPORTING
        iv_name TYPE zif_cd_hck_types=>ty_fieldname
        iv_kind TYPE zif_cd_hck_types=>ty_type_kind.

    METHODS act
      RETURNING
        VALUE(rs_query) TYPE zif_cd_hck_types=>ty_agg_query
      RAISING
        zcx_ca_ops_error.

    METHODS assert_msgno
      IMPORTING
        iv_msgno TYPE symsgno
        iv_msg   TYPE string.

ENDCLASS.



CLASS ltc_agg_query IMPLEMENTATION.

  METHOD setup.
    CLEAR: ms_def, mt_fields.
    mv_whitelisted = abap_true.
    add_field( iv_name = 'BUKRS' iv_kind = 'C' ).
    add_field( iv_name = 'AUGST' iv_kind = 'C' ).
    add_field( iv_name = 'HVORG' iv_kind = 'C' ).
    add_field( iv_name = 'FAEDN' iv_kind = 'D' ).
    add_field( iv_name = 'BETRH' iv_kind = 'P' ).
    " acceptance test 1: return debits aging > 10 days by company code
    ms_def-check_id     = gc_check.
    ms_def-agg_id       = gc_agg.
    ms_def-tabname      = gc_table.
    ms_def-agg_func     = zif_cd_hck_types=>gc_agg_func-count.
    ms_def-date_field   = 'FAEDN'.
    ms_def-date_mode    = zif_cd_hck_types=>gc_date_mode-age.
    ms_def-age_days_min = 10.
    ms_def-group_field  = 'BUKRS'.
    ms_def-cond1_field  = 'AUGST'.
    ms_def-cond1_op     = zif_cd_hck_types=>gc_operator-eq.
    ms_def-cond1_value  = ''.
  ENDMETHOD.


  METHOD add_field.
    DATA ls_field TYPE zif_cd_hck_types=>ty_field.
    ls_field-fieldname = iv_name.
    ls_field-type_kind = iv_kind.
    INSERT ls_field INTO TABLE mt_fields.
  ENDMETHOD.


  METHOD act.
    rs_query = zcl_cd_hck_agg_query=>build( is_def         = ms_def
                                            it_fields      = mt_fields
                                            iv_whitelisted = mv_whitelisted
                                            iv_ref_date    = gc_ref_date ).
  ENDMETHOD.


  METHOD assert_msgno.
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = |{ iv_msg }: no exception raised| ).
      CATCH zcx_ca_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_equals( act = lx_error->if_t100_message~t100key-msgno
                                            exp = iv_msgno
                                            msg = iv_msg ).
    ENDTRY.
  ENDMETHOD.


  " Rule: aging check = date older than ref date - N days, not initial, plus bound conditions
  METHOD builds_aging_where.
    DATA ls_exp TYPE zif_cd_hck_types=>ty_agg_query.
    TRY.
        ls_exp-agg_id       = gc_agg.
        ls_exp-tabname      = gc_table.
        ls_exp-agg_func     = zif_cd_hck_types=>gc_agg_func-count.
        ls_exp-group_field  = 'BUKRS'.
        ls_exp-where_clause = `FAEDN <= '20261026' AND FAEDN > '00000000' AND AUGST = ''`.
        cl_abap_unit_assert=>assert_equals( act = act( )
                                            exp = ls_exp
                                            msg = 'Aging query for acceptance test 1 must be built from config only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a table not approved in ZCD_OPS_TABWL (HCK / READ) is refused (message 302)
  METHOD rejects_unlisted_table.
    mv_whitelisted = abap_false.
    assert_msgno( iv_msgno = '302' iv_msg = 'Non-whitelisted table must be refused' ).
  ENDMETHOD.


  " Rule: a field not in the DDIC of the table is refused (message 304)
  METHOD rejects_unknown_field.
    ms_def-cond2_field = 'XYZ_NOFIELD'.
    ms_def-cond2_op    = zif_cd_hck_types=>gc_operator-eq.
    ms_def-cond2_value = 'X'.
    assert_msgno( iv_msgno = '304' iv_msg = 'Unknown condition field must be refused' ).
  ENDMETHOD.


  " Rule: only EQ NE GT LT GE LE IN are accepted (message 305)
  METHOD rejects_unknown_operator.
    ms_def-cond1_op = 'CP'.
    assert_msgno( iv_msgno = '305' iv_msg = 'Operator CP must be refused' ).
  ENDMETHOD.


  " Rule: a numeric field only takes numeric values (message 306)
  METHOD rejects_text_numeric_field.
    ms_def-cond2_field = 'BETRH'.
    ms_def-cond2_op    = zif_cd_hck_types=>gc_operator-gt.
    ms_def-cond2_value = '1 OR 1=1'.
    assert_msgno( iv_msgno = '306' iv_msg = 'Text in a numeric condition must be refused' ).
  ENDMETHOD.


  " Rule: the aging date field must be a DATS field (message 309)
  METHOD rejects_non_date_age_field.
    ms_def-date_field = 'BUKRS'.
    assert_msgno( iv_msgno = '309' iv_msg = 'Non-date aging field must be refused' ).
  ENDMETHOD.


  " Rule: SUM needs a numeric field (message 318)
  METHOD rejects_sum_on_text_field.
    ms_def-agg_func  = zif_cd_hck_types=>gc_agg_func-sum.
    ms_def-sum_field = 'HVORG'.
    assert_msgno( iv_msgno = '318' iv_msg = 'SUM on a text field must be refused' ).
  ENDMETHOD.


  " Rule: literals are quoted and inner quotes doubled - no SQL injection
  METHOD escapes_quote_in_literal.
    TRY.
        ms_def-cond1_value = `0060' OR '1'='1`.
        DATA(lv_where) = act( )-where_clause.
        cl_abap_unit_assert=>assert_equals(
          act = lv_where
          exp = `FAEDN <= '20261026' AND FAEDN > '00000000' AND AUGST = '0060'' OR ''1''=''1'`
          msg = 'Injected quote must stay inside one escaped literal' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: IN takes a comma list, each value quoted
  METHOD in_list_quotes_each_value.
    TRY.
        ms_def-cond1_field = 'HVORG'.
        ms_def-cond1_op    = zif_cd_hck_types=>gc_operator-in_set.
        ms_def-cond1_value = '0060, 0070'.
        cl_abap_unit_assert=>assert_equals(
          act = act( )-where_clause
          exp = `FAEDN <= '20261026' AND FAEDN > '00000000' AND HVORG IN ( '0060', '0070' )`
          msg = 'IN list must become a quoted value set' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: DAY mode counts exactly one day (ref date - N), used for volumes
  METHOD day_mode_compares_one_date.
    TRY.
        ms_def-date_mode    = zif_cd_hck_types=>gc_date_mode-day.
        ms_def-age_days_min = 1.
        CLEAR: ms_def-cond1_field, ms_def-cond1_op, ms_def-cond1_value.
        cl_abap_unit_assert=>assert_equals( act = act( )-where_clause
                                            exp = `FAEDN = '20261104'`
                                            msg = 'DAY mode with offset 1 must select yesterday only' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: no rows still measure 0 under dimension '*' (a silent feed is visible)
  METHOD no_rows_give_star_zero.
    DATA lt_rows TYPE zif_cd_hck_types=>tt_agg_row.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        INSERT VALUE #( metric = gc_agg dim1 = '*' value = 0 ) INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_agg_query=>to_metrics( is_def      = ms_def
                                                  it_rows     = lt_rows
                                                  iv_ref_date = gc_ref_date )
          exp = lt_exp
          msg = 'Empty result must give one zero metric for *' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: each group value becomes DIM1; COUNT gives the row count
  METHOD group_rows_become_dims.
    DATA lt_rows TYPE zif_cd_hck_types=>tt_agg_row.
    DATA ls_row TYPE zif_cd_hck_types=>ty_agg_row.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        ls_row-group_value = 'US01'.
        ls_row-row_count   = 12.
        ls_row-total       = 999.
        INSERT ls_row INTO TABLE lt_rows.
        ls_row-group_value = 'US02'.
        ls_row-row_count   = 3.
        INSERT ls_row INTO TABLE lt_rows.
        INSERT VALUE #( metric = gc_agg dim1 = 'US01' value = 12 ) INTO TABLE lt_exp.
        INSERT VALUE #( metric = gc_agg dim1 = 'US02' value = 3 ) INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_agg_query=>to_metrics( is_def      = ms_def
                                                  it_rows     = lt_rows
                                                  iv_ref_date = gc_ref_date )
          exp = lt_exp
          msg = 'Group values must map to DIM1 with the count' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A103): an expected group without rows measures 0 - one company silent while another
  " is active must not vanish from the metrics
  METHOD missing_expected_group_zero.
    DATA lt_rows TYPE zif_cd_hck_types=>tt_agg_row.
    DATA lt_expected TYPE zif_cd_hck_types=>tt_group_value.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        INSERT VALUE #( group_value = 'US01' row_count = 12 ) INTO TABLE lt_rows.
        INSERT CONV #( 'US01' ) INTO TABLE lt_expected.
        INSERT CONV #( 'US02' ) INTO TABLE lt_expected.
        INSERT VALUE #( metric = gc_agg dim1 = 'US01' value = 12 ) INTO TABLE lt_exp.
        INSERT VALUE #( metric = gc_agg dim1 = 'US02' value = 0 ) INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_agg_query=>to_metrics( is_def      = ms_def
                                                  it_rows     = lt_rows
                                                  iv_ref_date = gc_ref_date
                                                  it_expected = lt_expected )
          exp = lt_exp
          msg = 'Missing company US02 must measure 0 next to active US01' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A103): with an expected set, an empty result is a zero per expected group, not '*'
  METHOD no_rows_zero_per_expected.
    DATA lt_rows TYPE zif_cd_hck_types=>tt_agg_row.
    DATA lt_expected TYPE zif_cd_hck_types=>tt_group_value.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        INSERT CONV #( 'US01' ) INTO TABLE lt_expected.
        INSERT CONV #( 'US02' ) INTO TABLE lt_expected.
        INSERT VALUE #( metric = gc_agg dim1 = 'US01' value = 0 ) INTO TABLE lt_exp.
        INSERT VALUE #( metric = gc_agg dim1 = 'US02' value = 0 ) INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_agg_query=>to_metrics( is_def      = ms_def
                                                  it_rows     = lt_rows
                                                  iv_ref_date = gc_ref_date
                                                  it_expected = lt_expected )
          exp = lt_exp
          msg = 'Every expected company must measure 0' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.


"! Table consolidation 2026-11-08: the expected groups of an aggregate are one comma list on the
"! ZCD_HCK_AGG row (was ZCD_HCK_AGGGRP) - parsed once by the readers, validated on save
CLASS ltc_group_list DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_us01 TYPE zif_cd_hck_types=>ty_group_value VALUE 'US01',
      gc_us02 TYPE zif_cd_hck_types=>ty_group_value VALUE 'US02',
      gc_pclm TYPE zif_cd_hck_types=>ty_group_value VALUE 'PCLM'.

    METHODS list_parsed_trimmed_distinct FOR TESTING.
    METHODS blank_list_no_group FOR TESTING.
    METHODS valid_list_accepted FOR TESTING.
    METHODS blank_element_refused FOR TESTING.
    METHODS repeat_refused FOR TESTING.
    METHODS overlong_value_refused FOR TESTING.
ENDCLASS.


CLASS ltc_group_list IMPLEMENTATION.

  " Rule: the readers get each value once, trimmed, in the order of the list; ';' separates too
  METHOD list_parsed_trimmed_distinct.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_group_value.
    TRY.
        INSERT gc_us01 INTO TABLE lt_exp.
        INSERT gc_us02 INTO TABLE lt_exp.
        INSERT gc_pclm INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_agg_query=>expected_groups( |{ gc_us01 } , { gc_us02 };{ gc_pclm },{ gc_us01 }| )
          exp = lt_exp
          msg = 'Three groups, trimmed, the repeat dropped' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a blank list expects no group (no zero rows are added)
  METHOD blank_list_no_group.
    TRY.
        cl_abap_unit_assert=>assert_initial( act = zcl_cd_hck_agg_query=>expected_groups( space )
                                             msg = 'Blank list: no expected group' ).
        cl_abap_unit_assert=>assert_true( act = zcl_cd_hck_agg_query=>group_list_valid( space )
                                          msg = 'Blank list is valid' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a comma list of distinct values is accepted on save
  METHOD valid_list_accepted.
    TRY.
        cl_abap_unit_assert=>assert_true( act = zcl_cd_hck_agg_query=>group_list_valid( |{ gc_us01 }, { gc_us02 }| )
                                          msg = 'Distinct values are valid' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an empty element (',,') is refused - it would silently expect nothing
  METHOD blank_element_refused.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_hck_agg_query=>group_list_valid( |{ gc_us01 },,{ gc_us02 }| )
                                           msg = 'An empty element is refused (426)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a repeated value is refused (no redundant data)
  METHOD repeat_refused.
    TRY.
        cl_abap_unit_assert=>assert_false( act = zcl_cd_hck_agg_query=>group_list_valid( |{ gc_us01 },{ gc_us01 }| )
                                           msg = 'A repeat is refused (426)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a value longer than a group value (70) would be cut and never match - refused
  METHOD overlong_value_refused.
    TRY.
        DATA(lv_long) = repeat( val = `X` occ = 71 ).
        cl_abap_unit_assert=>assert_false( act = zcl_cd_hck_agg_query=>group_list_valid( |{ gc_us01 },{ lv_long }| )
                                           msg = 'A value over 70 characters is refused (426)' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
