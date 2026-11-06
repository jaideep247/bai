*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_threshold.clas.testclasses.abap
*& Purpose:
*& Unit tests of threshold resolution ('*' fallback, company-code override)
*& and of static / baseline evaluation; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
CLASS ltc_threshold DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check  TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_RET_AGED',
      gc_metric TYPE zif_cd_hck_types=>ty_metric_name VALUE 'RET_AGED',
      gc_bukrs  TYPE zif_cd_hck_types=>ty_thresh_key VALUE 'US01',
      gc_other  TYPE zif_cd_hck_types=>ty_thresh_key VALUE 'US02'.

    METHODS bukrs_row_beats_star_row FOR TESTING.
    METHODS star_row_without_bukrs_row FOR TESTING.
    METHODS unknown_metric_no_threshold FOR TESTING.
    METHODS red_when_value_reaches_red FOR TESTING.
    METHODS amber_between_amber_and_red FOR TESTING.
    METHODS green_below_amber FOR TESTING.
    METHODS lower_worse_red_at_zero FOR TESTING.
    METHODS zero_red_disabled_when_higher FOR TESTING.
    METHODS zscore_outlier_turns_amber FOR TESTING.
    METHODS short_history_no_baseline FOR TESTING.
    METHODS iqr_outlier_turns_amber FOR TESTING.

    METHODS threshold_row
      IMPORTING
        iv_bukrs      TYPE zif_cd_hck_types=>ty_thresh_key
        iv_amber      TYPE zif_cd_hck_types=>ty_value
        iv_red        TYPE zif_cd_hck_types=>ty_value
      RETURNING
        VALUE(rs_row) TYPE zif_cd_hck_types=>ty_threshold.

    METHODS history_246
      RETURNING
        VALUE(rt_values) TYPE zif_cd_hck_types=>tt_value.

ENDCLASS.



CLASS ltc_threshold IMPLEMENTATION.

  METHOD threshold_row.
    rs_row-check_id        = gc_check.
    rs_row-metric          = gc_metric.
    rs_row-bukrs           = iv_bukrs.
    rs_row-amber           = iv_amber.
    rs_row-red             = iv_red.
    rs_row-higher_is_worse = abap_true.
    rs_row-baseline_mode   = zif_cd_hck_types=>gc_baseline-none.
  ENDMETHOD.


  METHOD history_246.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    lv_value = 2.
    INSERT lv_value INTO TABLE rt_values.
    lv_value = 4.
    INSERT lv_value INTO TABLE rt_values.
    lv_value = 6.
    INSERT lv_value INTO TABLE rt_values.
  ENDMETHOD.


  " Rule: a company-code row overrides the '*' default row
  METHOD bukrs_row_beats_star_row.
    DATA lt_rows TYPE zif_cd_hck_types=>tt_threshold.
    TRY.
        INSERT threshold_row( iv_bukrs = zif_cd_hck_types=>gc_default_key iv_amber = 1 iv_red = 10 ) INTO TABLE lt_rows.
        INSERT threshold_row( iv_bukrs = gc_bukrs iv_amber = 5 iv_red = 50 ) INTO TABLE lt_rows.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_threshold=>resolve( it_thresholds = lt_rows
                                               iv_metric     = gc_metric
                                               iv_key        = gc_bukrs )
          exp = threshold_row( iv_bukrs = gc_bukrs iv_amber = 5 iv_red = 50 )
          msg = 'The US01 row must win over the * row' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: without a row for the company code the '*' row applies
  METHOD star_row_without_bukrs_row.
    DATA lt_rows TYPE zif_cd_hck_types=>tt_threshold.
    TRY.
        INSERT threshold_row( iv_bukrs = zif_cd_hck_types=>gc_default_key iv_amber = 1 iv_red = 10 ) INTO TABLE lt_rows.
        INSERT threshold_row( iv_bukrs = gc_bukrs iv_amber = 5 iv_red = 50 ) INTO TABLE lt_rows.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_threshold=>resolve( it_thresholds = lt_rows
                                               iv_metric     = gc_metric
                                               iv_key        = gc_other )
          exp = threshold_row( iv_bukrs = zif_cd_hck_types=>gc_default_key iv_amber = 1 iv_red = 10 )
          msg = 'US02 has no row: the * row must apply' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a metric without any row is not evaluated
  METHOD unknown_metric_no_threshold.
    DATA lt_rows TYPE zif_cd_hck_types=>tt_threshold.
    DATA ls_initial TYPE zif_cd_hck_types=>ty_threshold.
    TRY.
        INSERT threshold_row( iv_bukrs = zif_cd_hck_types=>gc_default_key iv_amber = 1 iv_red = 10 ) INTO TABLE lt_rows.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_threshold=>resolve( it_thresholds = lt_rows
                                               iv_metric     = 'OTHER_METRIC'
                                               iv_key        = gc_bukrs )
          exp = ls_initial
          msg = 'An unconfigured metric must resolve to no threshold' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: higher is worse - value >= red is RED / THRESHOLD_RED
  METHOD red_when_value_reaches_red.
    DATA lt_history TYPE zif_cd_hck_types=>tt_value.
    DATA ls_exp TYPE zif_cd_hck_types=>ty_evaluation.
    TRY.
        ls_exp-rag        = zif_cd_ops_types=>gc_rag-red.
        ls_exp-check_code = zif_cd_hck_types=>gc_code-threshold_red.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_threshold=>evaluate( iv_value     = 10
                                                is_threshold = threshold_row( iv_bukrs = gc_bukrs iv_amber = 1 iv_red = 10 )
                                                it_history   = lt_history )
          exp = ls_exp
          msg = 'Value 10 with red 10 must be RED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: amber <= value < red is AMBER / THRESHOLD_AMBER
  METHOD amber_between_amber_and_red.
    DATA lt_history TYPE zif_cd_hck_types=>tt_value.
    DATA ls_exp TYPE zif_cd_hck_types=>ty_evaluation.
    TRY.
        ls_exp-rag        = zif_cd_ops_types=>gc_rag-amber.
        ls_exp-check_code = zif_cd_hck_types=>gc_code-threshold_amber.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_threshold=>evaluate( iv_value     = 3
                                                is_threshold = threshold_row( iv_bukrs = gc_bukrs iv_amber = 1 iv_red = 10 )
                                                it_history   = lt_history )
          exp = ls_exp
          msg = 'Value 3 between amber 1 and red 10 must be AMBER' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: value below amber is GREEN without a check code
  METHOD green_below_amber.
    DATA lt_history TYPE zif_cd_hck_types=>tt_value.
    DATA ls_exp TYPE zif_cd_hck_types=>ty_evaluation.
    TRY.
        ls_exp-rag = zif_cd_ops_types=>gc_rag-green.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_threshold=>evaluate( iv_value     = 0
                                                is_threshold = threshold_row( iv_bukrs = gc_bukrs iv_amber = 1 iv_red = 10 )
                                                it_history   = lt_history )
          exp = ls_exp
          msg = 'Value 0 below amber 1 must be GREEN' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: lower is worse - red 0 is a real limit (zero volume is RED)
  METHOD lower_worse_red_at_zero.
    DATA lt_history TYPE zif_cd_hck_types=>tt_value.
    DATA ls_exp TYPE zif_cd_hck_types=>ty_evaluation.
    TRY.
        DATA(ls_row) = threshold_row( iv_bukrs = gc_bukrs iv_amber = 100 iv_red = 0 ).
        ls_row-higher_is_worse = abap_false.
        ls_exp-rag        = zif_cd_ops_types=>gc_rag-red.
        ls_exp-check_code = zif_cd_hck_types=>gc_code-threshold_red.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_threshold=>evaluate( iv_value     = 0
                                                is_threshold = ls_row
                                                it_history   = lt_history )
          exp = ls_exp
          msg = 'Zero volume with lower-is-worse red 0 must be RED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: higher is worse - red 0 means 'no red limit', not 'always red'
  METHOD zero_red_disabled_when_higher.
    DATA lt_history TYPE zif_cd_hck_types=>tt_value.
    DATA ls_exp TYPE zif_cd_hck_types=>ty_evaluation.
    TRY.
        ls_exp-rag        = zif_cd_ops_types=>gc_rag-amber.
        ls_exp-check_code = zif_cd_hck_types=>gc_code-threshold_amber.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_threshold=>evaluate( iv_value     = 500
                                                is_threshold = threshold_row( iv_bukrs = gc_bukrs iv_amber = 1 iv_red = 0 )
                                                it_history   = lt_history )
          exp = ls_exp
          msg = 'Without a red limit a high value must stay AMBER' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: z-score beyond the limit is a baseline outlier (AMBER)
  METHOD zscore_outlier_turns_amber.
    DATA ls_exp TYPE zif_cd_hck_types=>ty_evaluation.
    TRY.
        DATA(ls_row) = threshold_row( iv_bukrs = gc_bukrs iv_amber = 0 iv_red = 0 ).
        ls_row-baseline_mode = zif_cd_hck_types=>gc_baseline-zscore.
        ls_row-z_limit       = 3.
        ls_exp-rag        = zif_cd_ops_types=>gc_rag-amber.
        ls_exp-check_code = zif_cd_hck_types=>gc_code-baseline_outlier.
        ls_exp-z_score    = 3.
        ls_exp-mean       = 4.
        ls_exp-points     = 3.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_threshold=>evaluate( iv_value     = 10
                                                is_threshold = ls_row
                                                it_history   = history_246( ) )
          exp = ls_exp
          msg = 'z = 3 against 2,4,6 must be a baseline outlier' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: fewer than the minimum history points means no baseline verdict
  METHOD short_history_no_baseline.
    DATA lt_history TYPE zif_cd_hck_types=>tt_value.
    DATA ls_exp TYPE zif_cd_hck_types=>ty_evaluation.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    TRY.
        lv_value = 2.
        INSERT lv_value INTO TABLE lt_history.
        lv_value = 4.
        INSERT lv_value INTO TABLE lt_history.
        DATA(ls_row) = threshold_row( iv_bukrs = gc_bukrs iv_amber = 0 iv_red = 0 ).
        ls_row-baseline_mode = zif_cd_hck_types=>gc_baseline-zscore.
        ls_row-z_limit       = 1.
        ls_exp-rag    = zif_cd_ops_types=>gc_rag-green.
        ls_exp-points = 2.
        ls_exp-mean   = 3.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_threshold=>evaluate( iv_value     = 100
                                                is_threshold = ls_row
                                                it_history   = lt_history )
          exp = ls_exp
          msg = 'Two history points are not a baseline' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: IQR mode flags values beyond Q3 + k * IQR (k = Z_LIMIT)
  METHOD iqr_outlier_turns_amber.
    DATA ls_exp TYPE zif_cd_hck_types=>ty_evaluation.
    TRY.
        DATA(ls_row) = threshold_row( iv_bukrs = gc_bukrs iv_amber = 0 iv_red = 0 ).
        ls_row-baseline_mode = zif_cd_hck_types=>gc_baseline-iqr.
        ls_row-z_limit       = '1.5'.
        ls_exp-rag        = zif_cd_ops_types=>gc_rag-amber.
        ls_exp-check_code = zif_cd_hck_types=>gc_code-baseline_outlier.
        ls_exp-mean       = 4.
        ls_exp-points     = 3.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_threshold=>evaluate( iv_value     = 20
                                                is_threshold = ls_row
                                                it_history   = history_246( ) )
          exp = ls_exp
          msg = '20 is above Q3 5 + 1.5 * IQR 2 = 8' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
