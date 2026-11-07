*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_stats.clas.testclasses.abap
*& Purpose:
*& Unit tests of the pure statistics helper (mean, standard
*& deviation, percentile, z-score, IQR); does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-07 | Median tests call percentile( 50 ) (median removed).
*&---------------------------------------------------------------------*
CLASS ltc_stats DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS gc_iqr_k TYPE zif_cd_hck_types=>ty_value VALUE '1.5'.

    METHODS mean_of_empty_is_zero FOR TESTING.
    METHODS single_value_zero_stddev FOR TESTING.
    METHODS mean_of_known_series FOR TESTING.
    METHODS p50_even_count_averages FOR TESTING.
    METHODS p50_odd_count_is_middle FOR TESTING.
    METHODS sample_stddev_known_series FOR TESTING.
    METHODS percentile_interpolates FOR TESTING.
    METHODS zscore_measures_distance FOR TESTING.
    METHODS zscore_zero_without_spread FOR TESTING.
    METHODS iqr_flags_high_outlier FOR TESTING.
    METHODS iqr_keeps_inner_value FOR TESTING.
    METHODS iqr_low_side_when_lower_bad FOR TESTING.

    "! 2, 4, 6: mean 4, sample std dev 2
    METHODS series_246
      RETURNING
        VALUE(rt_values) TYPE zif_cd_hck_types=>tt_value.

    "! 1 .. 5: Q1 2, Q3 4, IQR 2
    METHODS series_1_to_5
      RETURNING
        VALUE(rt_values) TYPE zif_cd_hck_types=>tt_value.

ENDCLASS.



CLASS ltc_stats IMPLEMENTATION.

  METHOD series_246.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    lv_value = 2.
    INSERT lv_value INTO TABLE rt_values.
    lv_value = 4.
    INSERT lv_value INTO TABLE rt_values.
    lv_value = 6.
    INSERT lv_value INTO TABLE rt_values.
  ENDMETHOD.


  METHOD series_1_to_5.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    DO 5 TIMES.
      lv_value = sy-index.
      INSERT lv_value INTO TABLE rt_values.
    ENDDO.
  ENDMETHOD.


  " Rule: statistics of an empty series are 0, never a dump
  METHOD mean_of_empty_is_zero.
    DATA lt_empty TYPE zif_cd_hck_types=>tt_value.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_stats=>mean( lt_empty )
                                            exp = 0
                                            msg = 'Mean of an empty series must be 0' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one observation has no spread
  METHOD single_value_zero_stddev.
    DATA lt_values TYPE zif_cd_hck_types=>tt_value.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    TRY.
        lv_value = 7.
        INSERT lv_value INTO TABLE lt_values.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_stats=>std_dev( lt_values )
                                            exp = 0
                                            msg = 'Std dev of a single value must be 0' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: mean = sum / n
  METHOD mean_of_known_series.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_stats=>mean( series_246( ) )
                                            exp = 4
                                            msg = 'Mean of 2,4,6 must be 4' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the 50th percentile of an even count is the average of the two middle values
  METHOD p50_even_count_averages.
    DATA lt_values TYPE zif_cd_hck_types=>tt_value.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    TRY.
        lv_value = 4.
        INSERT lv_value INTO TABLE lt_values.
        lv_value = 1.
        INSERT lv_value INTO TABLE lt_values.
        lv_value = 3.
        INSERT lv_value INTO TABLE lt_values.
        lv_value = 2.
        INSERT lv_value INTO TABLE lt_values.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_stats=>percentile( it_values  = lt_values
                                                                                iv_percent = 50 )
                                            exp = '2.5'
                                            msg = 'Median of 1,2,3,4 (unsorted) must be 2.5' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: the 50th percentile of an odd count is the middle value
  METHOD p50_odd_count_is_middle.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_stats=>percentile( it_values  = series_1_to_5( )
                                                                                iv_percent = 50 )
                                            exp = 3
                                            msg = 'Median of 1..5 must be 3' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: sample standard deviation uses n - 1
  METHOD sample_stddev_known_series.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_stats=>std_dev( series_246( ) )
                                            exp = 2
                                            msg = 'Sample std dev of 2,4,6 must be 2' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: percentiles interpolate linearly between ranks
  METHOD percentile_interpolates.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_stats=>percentile( it_values  = series_1_to_5( )
                                                                                iv_percent = 25 )
                                            exp = 2
                                            msg = 'P25 of 1..5 must be 2' ).
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_stats=>percentile( it_values  = series_1_to_5( )
                                                                                iv_percent = 90 )
                                            exp = '4.6'
                                            msg = 'P90 of 1..5 must be 4.6' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: z = (value - mean) / std dev
  METHOD zscore_measures_distance.
    TRY.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_stats=>z_score( iv_value  = 10
                                                                             it_values = series_246( ) )
                                            exp = 3
                                            msg = 'z of 10 against 2,4,6 must be 3' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a flat history has no z-score (0) instead of a division by zero
  METHOD zscore_zero_without_spread.
    DATA lt_values TYPE zif_cd_hck_types=>tt_value.
    DATA lv_value TYPE zif_cd_hck_types=>ty_value.
    TRY.
        lv_value = 5.
        INSERT lv_value INTO TABLE lt_values.
        INSERT lv_value INTO TABLE lt_values.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_stats=>z_score( iv_value  = 50
                                                                             it_values = lt_values )
                                            exp = 0
                                            msg = 'z must be 0 when the history has no spread' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: value above Q3 + k * IQR is an outlier
  METHOD iqr_flags_high_outlier.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_stats=>is_iqr_outlier( iv_value           = 8
                                                  it_values          = series_1_to_5( )
                                                  iv_k               = gc_iqr_k
                                                  iv_higher_is_worse = abap_true )
          exp = abap_true
          msg = '8 is above Q3 4 + 1.5 * IQR 2 = 7' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: value inside the fence is not an outlier
  METHOD iqr_keeps_inner_value.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_stats=>is_iqr_outlier( iv_value           = 6
                                                  it_values          = series_1_to_5( )
                                                  iv_k               = gc_iqr_k
                                                  iv_higher_is_worse = abap_true )
          exp = abap_false
          msg = '6 is inside the upper fence 7' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: when lower is worse only the lower fence Q1 - k * IQR counts
  METHOD iqr_low_side_when_lower_bad.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_stats=>is_iqr_outlier( iv_value           = -2
                                                  it_values          = series_1_to_5( )
                                                  iv_k               = gc_iqr_k
                                                  iv_higher_is_worse = abap_false )
          exp = abap_true
          msg = '-2 is below Q1 2 - 1.5 * IQR 2 = -1' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
