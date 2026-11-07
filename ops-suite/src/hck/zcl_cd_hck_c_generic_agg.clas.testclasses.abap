*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_c_generic_agg.clas.testclasses.abap
*& Purpose:
*& Unit tests of the generic aggregate check: one metric per group value,
*& expected groups measured zero, an invalid row reported while the others
*& are measured, no definition raises, exhausted budget stops. DAO and clock
*& are test doubles; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-06 | Initial version (coverage gap closure: own test include).
*& 2026-11-07 | Parameters from the shared fake ZCL_CD_OPS_PARAMS_MEM (row caps at their delivered defaults).
*&---------------------------------------------------------------------*
CLASS ltd_dao DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_hck_dao PARTIALLY IMPLEMENTED.
    DATA mt_defs TYPE zif_cd_hck_types=>tt_agg_def.
    DATA mt_groups TYPE zif_cd_hck_types=>tt_agg_group.
    DATA mt_rows TYPE zif_cd_hck_types=>tt_agg_row.
    DATA mv_queries TYPE i.
ENDCLASS.

CLASS ltd_dao IMPLEMENTATION.
  METHOD zif_cd_hck_dao~get_agg_defs.
    rt_defs = mt_defs.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_agg_groups.
    rt_groups = mt_groups.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~is_table_whitelisted.
    rv_allowed = abap_true.
  ENDMETHOD.

  METHOD zif_cd_hck_dao~get_table_fields.
    rt_fields = VALUE #( ( fieldname = 'BUKRS' type_kind = cl_abap_typedescr=>typekind_char )
                         ( fieldname = 'FAEDN' type_kind = cl_abap_typedescr=>typekind_date ) ).
  ENDMETHOD.

  METHOD zif_cd_hck_dao~aggregate.
    mv_queries = mv_queries + 1.
    rt_rows = mt_rows.
  ENDMETHOD.
ENDCLASS.


CLASS ltd_clock DEFINITION FINAL FOR TESTING.
  PUBLIC SECTION.
    INTERFACES zif_cd_ops_clock.
    CONSTANTS gc_now TYPE timestampl VALUE '20261106070000.0000000'.
    CONSTANTS gc_today TYPE d VALUE '20261106'.
ENDCLASS.

CLASS ltd_clock IMPLEMENTATION.
  METHOD zif_cd_ops_clock~now.
    rv_timestamp = gc_now.
  ENDMETHOD.

  METHOD zif_cd_ops_clock~today.
    rv_date = gc_today.
  ENDMETHOD.

  METHOD zif_cd_ops_clock~time.
    CLEAR rv_time.
  ENDMETHOD.
ENDCLASS.


CLASS ltc_generic_agg DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check    TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_RDI_AGING',
      gc_agg      TYPE zif_cd_hck_types=>ty_agg_id VALUE 'RDI_10D',
      gc_bad_agg  TYPE zif_cd_hck_types=>ty_agg_id VALUE 'BAD_FUNC',
      gc_bad_func TYPE zif_cd_hck_types=>ty_agg_func VALUE 'AVG',
      gc_table    TYPE zif_cd_hck_types=>ty_tabname VALUE 'DFKKOP',
      gc_us01     TYPE zif_cd_hck_types=>ty_group_value VALUE 'US01',
      gc_us02     TYPE zif_cd_hck_types=>ty_group_value VALUE 'US02',
      gc_count    TYPE i VALUE 12,
      gc_age_days TYPE i VALUE 10,
      gc_today    TYPE d VALUE '20261106',
      gc_deadline TYPE timestampl VALUE '20261106060000.0000000'.

    TYPES:
      BEGIN OF ty_flags,
        no_defs   TYPE abap_bool,
        invalid   TYPE abap_bool,
        expected  TYPE abap_bool,
        exhausted TYPE abap_bool,
      END OF ty_flags.

    DATA mo_dao TYPE REF TO ltd_dao.
    DATA ms_context TYPE zif_cd_hck_types=>ty_context.

    METHODS setup.
    METHODS teardown.
    METHODS metric_per_group_value FOR TESTING.
    METHODS expected_group_measures_zero FOR TESTING.
    METHODS invalid_row_others_measured FOR TESTING.
    METHODS no_definition_raises FOR TESTING.
    METHODS exhausted_budget_stops FOR TESTING.

    METHODS configure_scenario
      IMPORTING
        is_flags TYPE ty_flags.
    METHODS act
      RETURNING
        VALUE(rs_result) TYPE zif_cd_hck_types=>ty_check_result
      RAISING
        zcx_cd_ops_error.
ENDCLASS.


CLASS ltc_generic_agg IMPLEMENTATION.

  METHOD setup.
    zcl_cd_ops_injector=>inject_params( NEW zcl_cd_ops_params_mem( ) ).
    mo_dao = NEW #( ).
    CLEAR ms_context.
    ms_context-report_date = gc_today.
    zcl_cd_hck_injector=>inject_dao( mo_dao ).
    zcl_cd_ops_injector=>inject_clock( NEW ltd_clock( ) ).
  ENDMETHOD.


  METHOD teardown.
    zcl_cd_hck_injector=>reset( ).
    zcl_cd_ops_injector=>reset( ).
    CLEAR mo_dao.
  ENDMETHOD.


  METHOD configure_scenario.
    DATA ls_def TYPE zif_cd_hck_types=>ty_agg_def.
    DATA ls_row TYPE zif_cd_hck_types=>ty_agg_row.
    IF is_flags-no_defs = abap_true.
      RETURN.
    ENDIF.
    IF is_flags-invalid = abap_true.
      ls_def-check_id = gc_check.
      ls_def-agg_id   = gc_bad_agg.
      ls_def-tabname  = gc_table.
      ls_def-agg_func = gc_bad_func.
      INSERT ls_def INTO TABLE mo_dao->mt_defs.
      CLEAR ls_def.
    ENDIF.
    ls_def-check_id     = gc_check.
    ls_def-agg_id       = gc_agg.
    ls_def-tabname      = gc_table.
    ls_def-agg_func     = zif_cd_hck_types=>gc_agg_func-count.
    ls_def-date_field   = 'FAEDN'.
    ls_def-date_mode    = zif_cd_hck_types=>gc_date_mode-age.
    ls_def-age_days_min = gc_age_days.
    ls_def-group_field  = 'BUKRS'.
    INSERT ls_def INTO TABLE mo_dao->mt_defs.
    ls_row-group_value = gc_us01.
    ls_row-row_count   = gc_count.
    INSERT ls_row INTO TABLE mo_dao->mt_rows.
    IF is_flags-expected = abap_true.
      INSERT VALUE #( check_id = gc_check agg_id = gc_agg group_value = gc_us02 ) INTO TABLE mo_dao->mt_groups.
    ENDIF.
    IF is_flags-exhausted = abap_true.
      ms_context-deadline = gc_deadline.
    ENDIF.
  ENDMETHOD.


  METHOD act.
    rs_result = NEW zcl_cd_hck_c_generic_agg( )->zif_cd_hck_check~execute(
      is_def        = VALUE #( check_id = gc_check )
      it_thresholds = VALUE #( )
      is_context    = ms_context ).
  ENDMETHOD.


  " Rule (acceptance test 1): one metric per aggregate and group value (company code)
  METHOD metric_per_group_value.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        configure_scenario( VALUE #( ) ).
        INSERT VALUE #( metric = gc_agg dim1 = gc_us01 value = gc_count ) INTO TABLE lt_exp.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics exp = lt_exp
                                            msg = 'Metric AGG_ID per company code' ).
        cl_abap_unit_assert=>assert_initial( act = ls_result-findings msg = 'Valid row has no finding' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A103): an expected company code without rows measures 0
  METHOD expected_group_measures_zero.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_metric.
    TRY.
        configure_scenario( VALUE #( expected = abap_true ) ).
        INSERT VALUE #( metric = gc_agg dim1 = gc_us01 value = gc_count ) INTO TABLE lt_exp.
        INSERT VALUE #( metric = gc_agg dim1 = gc_us02 value = 0 ) INTO TABLE lt_exp.
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-metrics exp = lt_exp
                                            msg = 'Silent expected group measures 0' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an invalid row is AGG_CONFIG_INVALID; the valid rows are still measured
  METHOD invalid_row_others_measured.
    TRY.
        configure_scenario( VALUE #( invalid = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-findings ) exp = 1 msg = 'One invalid row' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_cd_hck_types=>gc_code-agg_invalid
                                            msg = 'Invalid row is AGG_CONFIG_INVALID' ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-object_key
                                            exp = |{ gc_check }/{ gc_bad_agg }|
                                            msg = 'Finding names check and aggregate' ).
        cl_abap_unit_assert=>assert_equals( act = lines( ls_result-metrics ) exp = 1
                                            msg = 'Valid row still measured' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a check without ZCD_HCK_AGG rows is misconfigured and raises
  METHOD no_definition_raises.
    configure_scenario( VALUE #( no_defs = abap_true ) ).
    TRY.
        act( ).
        cl_abap_unit_assert=>fail( msg = 'No aggregate definition must raise' ).
      CATCH zcx_cd_ops_error INTO DATA(lx_error).
        cl_abap_unit_assert=>assert_bound( act = lx_error msg = 'Configuration error raised' ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A18): a passed deadline stops before the next aggregate is queried
  METHOD exhausted_budget_stops.
    TRY.
        configure_scenario( VALUE #( exhausted = abap_true ) ).
        DATA(ls_result) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_result-findings[ 1 ]-check_code
                                            exp = zif_cd_hck_types=>gc_code-budget_exhausted
                                            msg = 'Budget stop is reported' ).
        cl_abap_unit_assert=>assert_equals( act = mo_dao->mv_queries exp = 0 msg = 'No query issued' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
