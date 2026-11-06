*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_stats.clas.abap
*& Purpose:
*& Pure descriptive statistics for rolling baselines: mean, median, sample
*& standard deviation, percentile, z-score and IQR outlier test.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Field symbols: read-only loop work areas as ASSIGNING FIELD-SYMBOL (Performance_Review.md).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - statistics (pure, no DB)</p>
"! Empty input never dumps: every function returns 0 / abap_false.
CLASS zcl_cd_hck_stats DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS mean
      IMPORTING
        it_values       TYPE zif_cd_hck_types=>tt_value
      RETURNING
        VALUE(rv_value) TYPE zif_cd_hck_types=>ty_value.

    CLASS-METHODS median
      IMPORTING
        it_values       TYPE zif_cd_hck_types=>tt_value
      RETURNING
        VALUE(rv_value) TYPE zif_cd_hck_types=>ty_value.

    "! Sample standard deviation (n - 1); 0 for fewer than two values
    CLASS-METHODS std_dev
      IMPORTING
        it_values       TYPE zif_cd_hck_types=>tt_value
      RETURNING
        VALUE(rv_value) TYPE zif_cd_hck_types=>ty_value.

    "! Percentile 0..100 with linear interpolation between closest ranks
    CLASS-METHODS percentile
      IMPORTING
        it_values       TYPE zif_cd_hck_types=>tt_value
        iv_percent      TYPE zif_cd_hck_types=>ty_value
      RETURNING
        VALUE(rv_value) TYPE zif_cd_hck_types=>ty_value.

    "! (value - mean) / std dev of the history; 0 when the history has no spread
    CLASS-METHODS z_score
      IMPORTING
        iv_value        TYPE zif_cd_hck_types=>ty_value
        it_values       TYPE zif_cd_hck_types=>tt_value
      RETURNING
        VALUE(rv_value) TYPE zif_cd_hck_types=>ty_value.

    "! Tukey fence: higher is worse -> value > Q3 + k*IQR, else value < Q1 - k*IQR
    CLASS-METHODS is_iqr_outlier
      IMPORTING
        iv_value           TYPE zif_cd_hck_types=>ty_value
        it_values          TYPE zif_cd_hck_types=>tt_value
        iv_k               TYPE zif_cd_hck_types=>ty_value
        iv_higher_is_worse TYPE abap_bool
      RETURNING
        VALUE(rv_outlier)  TYPE abap_bool.

  PRIVATE SECTION.

    CLASS-METHODS sorted
      IMPORTING
        it_values        TYPE zif_cd_hck_types=>tt_value
      RETURNING
        VALUE(rt_values) TYPE zif_cd_hck_types=>tt_value.

ENDCLASS.



CLASS zcl_cd_hck_stats IMPLEMENTATION.

  METHOD mean.
    DATA lv_sum TYPE zif_cd_hck_types=>ty_value.
    IF it_values IS INITIAL.
      RETURN.
    ENDIF.
    LOOP AT it_values ASSIGNING FIELD-SYMBOL(<lv_value>).
      lv_sum = lv_sum + <lv_value>.
    ENDLOOP.
    rv_value = lv_sum / lines( it_values ).
  ENDMETHOD.


  METHOD median.
    rv_value = percentile( it_values  = it_values
                           iv_percent = 50 ).
  ENDMETHOD.


  METHOD std_dev.
    DATA lv_sum_sq TYPE zif_cd_hck_types=>ty_value.
    DATA(lv_count) = lines( it_values ).
    IF lv_count < 2.
      RETURN.
    ENDIF.
    DATA(lv_mean) = mean( it_values ).
    LOOP AT it_values ASSIGNING FIELD-SYMBOL(<lv_value>).
      lv_sum_sq = lv_sum_sq + ( <lv_value> - lv_mean ) ** 2.
    ENDLOOP.
    rv_value = sqrt( lv_sum_sq / ( lv_count - 1 ) ).
  ENDMETHOD.


  METHOD percentile.
    DATA lv_position TYPE zif_cd_hck_types=>ty_value.
    DATA lv_lower TYPE i.
    IF it_values IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lt_sorted) = sorted( it_values ).
    DATA(lv_count) = lines( lt_sorted ).
    DATA(lv_percent) = nmax( val1 = 0
                             val2 = nmin( val1 = iv_percent
                                          val2 = 100 ) ).
    " zero-based rank position
    lv_position = ( lv_count - 1 ) * lv_percent / 100.
    lv_lower = floor( lv_position ).
    DATA(lv_fraction) = lv_position - lv_lower.
    DATA(lv_low_value) = lt_sorted[ lv_lower + 1 ].
    IF lv_lower + 2 > lv_count OR lv_fraction = 0.
      rv_value = lv_low_value.
      RETURN.
    ENDIF.
    DATA(lv_high_value) = lt_sorted[ lv_lower + 2 ].
    rv_value = lv_low_value + ( lv_high_value - lv_low_value ) * lv_fraction.
  ENDMETHOD.


  METHOD z_score.
    DATA(lv_std_dev) = std_dev( it_values ).
    IF lv_std_dev = 0.
      RETURN.
    ENDIF.
    rv_value = ( iv_value - mean( it_values ) ) / lv_std_dev.
  ENDMETHOD.


  METHOD is_iqr_outlier.
    IF it_values IS INITIAL.
      RETURN.
    ENDIF.
    DATA(lv_q1) = percentile( it_values  = it_values
                              iv_percent = 25 ).
    DATA(lv_q3) = percentile( it_values  = it_values
                              iv_percent = 75 ).
    DATA(lv_fence) = iv_k * ( lv_q3 - lv_q1 ).
    IF iv_higher_is_worse = abap_true.
      rv_outlier = xsdbool( iv_value > lv_q3 + lv_fence ).
    ELSE.
      rv_outlier = xsdbool( iv_value < lv_q1 - lv_fence ).
    ENDIF.
  ENDMETHOD.


  METHOD sorted.
    rt_values = it_values.
    SORT rt_values BY table_line ASCENDING.
  ENDMETHOD.

ENDCLASS.
