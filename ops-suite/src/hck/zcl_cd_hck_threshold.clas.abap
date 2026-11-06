*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_threshold.clas.abap
*& Purpose:
*& Pure threshold logic: resolve the ZCD_HCK_THRESH row for a metric and
*& company code ('*' fallback) and evaluate a value statically and vs baseline.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Flat baseline: adverse deviation beyond a tolerance is an outlier (audit A59).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - threshold resolution and evaluation</p>
"! Static limits: higher is worse -> a zero limit is "not set";
"! lower is worse -> both limits apply as maintained (red 0 = zero is red),
"! unless both are zero. Baseline (ZSCORE / IQR) needs at least
"! GC_MIN_POINTS history values; an outlier is at least AMBER.
CLASS zcl_cd_hck_threshold DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CONSTANTS gc_min_points TYPE i VALUE 3.
    CONSTANTS gc_default_z TYPE zif_cd_hck_types=>ty_value VALUE 3.
    CONSTANTS gc_default_k TYPE zif_cd_hck_types=>ty_value VALUE '1.5'.
    "! Flat baseline (standard deviation 0): allowed adverse deviation in % of the mean
    CONSTANTS gc_default_flat_tol_pct TYPE zif_cd_hck_types=>ty_value VALUE 10.
    CONSTANTS gc_percent TYPE zif_cd_hck_types=>ty_value VALUE 100.

    "! Precedence: (metric, key) > (metric, '*') > ('*', '*'); initial when none
    CLASS-METHODS resolve
      IMPORTING
        it_thresholds       TYPE zif_cd_hck_types=>tt_threshold
        iv_metric           TYPE zif_cd_hck_types=>ty_metric_name
        iv_key              TYPE zif_cd_hck_types=>ty_thresh_key
      RETURNING
        VALUE(rs_threshold) TYPE zif_cd_hck_types=>ty_threshold.

    CLASS-METHODS evaluate
      IMPORTING
        iv_value             TYPE zif_cd_hck_types=>ty_value
        is_threshold         TYPE zif_cd_hck_types=>ty_threshold
        it_history           TYPE zif_cd_hck_types=>tt_value
        iv_flat_tol_pct      TYPE zif_cd_hck_types=>ty_value DEFAULT gc_default_flat_tol_pct
      RETURNING
        VALUE(rs_evaluation) TYPE zif_cd_hck_types=>ty_evaluation.

  PRIVATE SECTION.

    CLASS-METHODS static_rag
      IMPORTING
        iv_value      TYPE zif_cd_hck_types=>ty_value
        is_threshold  TYPE zif_cd_hck_types=>ty_threshold
      RETURNING
        VALUE(rv_rag) TYPE zif_cd_ops_types=>ty_rag.

    CLASS-METHODS is_outlier
      IMPORTING
        iv_value          TYPE zif_cd_hck_types=>ty_value
        is_threshold      TYPE zif_cd_hck_types=>ty_threshold
        it_history        TYPE zif_cd_hck_types=>tt_value
        iv_flat_tol_pct   TYPE zif_cd_hck_types=>ty_value
      EXPORTING
        ev_z_score        TYPE zif_cd_hck_types=>ty_value
      RETURNING
        VALUE(rv_outlier) TYPE abap_bool.

    "! Flat baseline: adverse deviation from the mean beyond the tolerance (A59)
    CLASS-METHODS is_flat_outlier
      IMPORTING
        iv_value          TYPE zif_cd_hck_types=>ty_value
        iv_mean           TYPE zif_cd_hck_types=>ty_value
        iv_higher_worse   TYPE abap_bool
        iv_flat_tol_pct   TYPE zif_cd_hck_types=>ty_value
      RETURNING
        VALUE(rv_outlier) TYPE abap_bool.

ENDCLASS.



CLASS zcl_cd_hck_threshold IMPLEMENTATION.

  METHOD resolve.
    READ TABLE it_thresholds INTO rs_threshold
      WITH KEY metric = iv_metric bukrs = iv_key.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.
    READ TABLE it_thresholds INTO rs_threshold
      WITH KEY metric = iv_metric bukrs = zif_cd_hck_types=>gc_default_key.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.
    READ TABLE it_thresholds INTO rs_threshold
      WITH KEY metric = zif_cd_hck_types=>gc_default_key bukrs = zif_cd_hck_types=>gc_default_key.
    IF sy-subrc <> 0.
      CLEAR rs_threshold.
    ENDIF.
  ENDMETHOD.


  METHOD evaluate.
    rs_evaluation-rag = static_rag( iv_value     = iv_value
                                    is_threshold = is_threshold ).
    rs_evaluation-check_code = SWITCH #( rs_evaluation-rag
                                         WHEN zif_cd_ops_types=>gc_rag-red   THEN zif_cd_hck_types=>gc_code-threshold_red
                                         WHEN zif_cd_ops_types=>gc_rag-amber THEN zif_cd_hck_types=>gc_code-threshold_amber ).

    IF is_threshold-baseline_mode IS INITIAL OR is_threshold-baseline_mode = zif_cd_hck_types=>gc_baseline-none.
      RETURN.
    ENDIF.
    rs_evaluation-points = lines( it_history ).
    rs_evaluation-mean   = zcl_cd_hck_stats=>mean( it_history ).
    IF rs_evaluation-points < gc_min_points.
      RETURN.
    ENDIF.

    IF is_outlier( EXPORTING iv_value        = iv_value
                             is_threshold    = is_threshold
                             it_history      = it_history
                             iv_flat_tol_pct = iv_flat_tol_pct
                   IMPORTING ev_z_score      = rs_evaluation-z_score ) = abap_false.
      RETURN.
    ENDIF.
    IF rs_evaluation-rag = zif_cd_ops_types=>gc_rag-green.
      rs_evaluation-rag        = zif_cd_ops_types=>gc_rag-amber.
      rs_evaluation-check_code = zif_cd_hck_types=>gc_code-baseline_outlier.
    ENDIF.
  ENDMETHOD.


  METHOD static_rag.
    DATA(lv_amber_set) = xsdbool( is_threshold-amber <> 0 ).
    DATA(lv_red_set)   = xsdbool( is_threshold-red <> 0 ).
    rv_rag = zif_cd_ops_types=>gc_rag-green.

    IF is_threshold-higher_is_worse = abap_true.
      IF lv_red_set = abap_true AND iv_value >= is_threshold-red.
        rv_rag = zif_cd_ops_types=>gc_rag-red.
      ELSEIF lv_amber_set = abap_true AND iv_value >= is_threshold-amber.
        rv_rag = zif_cd_ops_types=>gc_rag-amber.
      ENDIF.
      RETURN.
    ENDIF.

    IF lv_amber_set = abap_false AND lv_red_set = abap_false.
      RETURN.
    ENDIF.
    IF iv_value <= is_threshold-red.
      rv_rag = zif_cd_ops_types=>gc_rag-red.
    ELSEIF iv_value <= is_threshold-amber.
      rv_rag = zif_cd_ops_types=>gc_rag-amber.
    ENDIF.
  ENDMETHOD.


  METHOD is_outlier.
    CLEAR ev_z_score.
    " A flat history has no spread: z-score and IQR cannot judge it (z = 0, IQR = 0),
    " so the deviation from the mean decides, in the adverse direction only
    IF zcl_cd_hck_stats=>std_dev( it_history ) = 0.
      rv_outlier = is_flat_outlier( iv_value        = iv_value
                                    iv_mean         = zcl_cd_hck_stats=>mean( it_history )
                                    iv_higher_worse = is_threshold-higher_is_worse
                                    iv_flat_tol_pct = iv_flat_tol_pct ).
      RETURN.
    ENDIF.
    CASE is_threshold-baseline_mode.
      WHEN zif_cd_hck_types=>gc_baseline-zscore.
        DATA(lv_limit) = COND zif_cd_hck_types=>ty_value( WHEN is_threshold-z_limit > 0 THEN is_threshold-z_limit
                                                         ELSE gc_default_z ).
        ev_z_score = zcl_cd_hck_stats=>z_score( iv_value  = iv_value
                                                it_values = it_history ).
        IF is_threshold-higher_is_worse = abap_true.
          rv_outlier = xsdbool( ev_z_score >= lv_limit ).
        ELSE.
          rv_outlier = xsdbool( ev_z_score <= 0 - lv_limit ).
        ENDIF.
      WHEN zif_cd_hck_types=>gc_baseline-iqr.
        rv_outlier = zcl_cd_hck_stats=>is_iqr_outlier(
          iv_value           = iv_value
          it_values          = it_history
          iv_k               = COND #( WHEN is_threshold-z_limit > 0 THEN is_threshold-z_limit ELSE gc_default_k )
          iv_higher_is_worse = is_threshold-higher_is_worse ).
      WHEN OTHERS.
        rv_outlier = abap_false.
    ENDCASE.
  ENDMETHOD.


  METHOD is_flat_outlier.
    DATA(lv_adverse) = COND zif_cd_hck_types=>ty_value( WHEN iv_higher_worse = abap_true THEN iv_value - iv_mean
                                                       ELSE iv_mean - iv_value ).
    IF lv_adverse <= 0.
      RETURN.
    ENDIF.
    rv_outlier = xsdbool( lv_adverse > abs( iv_mean ) * iv_flat_tol_pct / gc_percent ).
  ENDMETHOD.

ENDCLASS.
