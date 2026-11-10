*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_score.clas.abap
*& Purpose:
*& Pure scorecard: weighted health score 0-100, overall RAG, RAG per
*& category A-E and critical/high counts from a list of check results.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Baseline warm-up checks counted apart, not scored (audit A102).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - scorecard rules (pure, no DB)</p>
"! Score = sum(weight(priority) * points(RAG)) / sum(weight), rounded.
"! Overall RAG from score bands; any red high-priority check forces RED and
"! any red check at least AMBER (an average must not hide a failure).
"! A check in baseline warm-up (A102) is counted per category, not scored.
CLASS zcl_cd_hck_score DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    "! G 100 / A 50 / R 0; weights H 3, M 2, L 1; GREEN >= 90, AMBER >= 70
    CLASS-METHODS default_rules
      RETURNING
        VALUE(rs_rules) TYPE zif_cd_hck_types=>ty_score_rules.

    CLASS-METHODS summarize
      IMPORTING
        it_results        TYPE zif_cd_hck_types=>tt_check_result
        is_rules          TYPE zif_cd_hck_types=>ty_score_rules
      RETURNING
        VALUE(rs_summary) TYPE zif_cd_hck_types=>ty_summary.

  PRIVATE SECTION.

    CLASS-METHODS weight
      IMPORTING
        iv_priority      TYPE zif_cd_hck_types=>ty_priority
        is_rules         TYPE zif_cd_hck_types=>ty_score_rules
      RETURNING
        VALUE(rv_weight) TYPE i.

    CLASS-METHODS points
      IMPORTING
        iv_rag           TYPE zif_ca_ops_types=>ty_rag
        is_rules         TYPE zif_cd_hck_types=>ty_score_rules
      RETURNING
        VALUE(rv_points) TYPE i.

ENDCLASS.



CLASS zcl_cd_hck_score IMPLEMENTATION.

  METHOD default_rules.
    rs_rules-points_green  = 100.
    rs_rules-points_amber  = 50.
    rs_rules-points_red    = 0.
    rs_rules-weight_high   = 3.
    rs_rules-weight_medium = 2.
    rs_rules-weight_low    = 1.
    rs_rules-green_min     = 90.
    rs_rules-amber_min     = 70.
  ENDMETHOD.


  METHOD summarize.
    DATA lv_weighted TYPE i.
    DATA lv_weights TYPE i.
    DATA lv_red_high TYPE abap_bool.
    DATA ls_category TYPE zif_cd_hck_types=>ty_category_status.

    DATA(lv_categories) = `ABCDE`.
    DO strlen( lv_categories ) TIMES.
      CLEAR ls_category.
      ls_category-category = substring( val = lv_categories off = sy-index - 1 len = 1 ).
      INSERT ls_category INTO TABLE rs_summary-categories.
    ENDDO.

    LOOP AT it_results INTO DATA(ls_result).
      " A102: a check in baseline warm-up is listed and counted, not scored (no verdict yet)
      IF ls_result-warmup = abap_true.
        rs_summary-warmup_count = rs_summary-warmup_count + 1.
        READ TABLE rs_summary-categories ASSIGNING FIELD-SYMBOL(<ls_warm>)
          WITH KEY category = ls_result-category.
        IF sy-subrc = 0.
          <ls_warm>-check_count  = <ls_warm>-check_count + 1.
          <ls_warm>-warmup_count = <ls_warm>-warmup_count + 1.
        ENDIF.
        CONTINUE.
      ENDIF.
      DATA(lv_weight) = weight( iv_priority = ls_result-priority
                                is_rules    = is_rules ).
      lv_weights  = lv_weights + lv_weight.
      lv_weighted = lv_weighted + lv_weight * points( iv_rag   = ls_result-rag
                                                      is_rules = is_rules ).
      CASE ls_result-rag.
        WHEN zif_ca_ops_types=>gc_rag-red.
          rs_summary-critical_count = rs_summary-critical_count + 1.
          IF ls_result-priority = zif_cd_hck_types=>gc_priority-high.
            lv_red_high = abap_true.
          ENDIF.
        WHEN zif_ca_ops_types=>gc_rag-amber.
          rs_summary-high_count = rs_summary-high_count + 1.
      ENDCASE.

      READ TABLE rs_summary-categories ASSIGNING FIELD-SYMBOL(<ls_category>)
        WITH KEY category = ls_result-category.
      IF sy-subrc <> 0.
        CLEAR ls_category.
        ls_category-category = ls_result-category.
        INSERT ls_category INTO TABLE rs_summary-categories ASSIGNING <ls_category>.
      ENDIF.
      <ls_category>-check_count = <ls_category>-check_count + 1.
      <ls_category>-rag = zcl_ca_ops_util=>worse_rag( iv_rag1 = <ls_category>-rag
                                                      iv_rag2 = ls_result-rag ).
      CASE ls_result-rag.
        WHEN zif_ca_ops_types=>gc_rag-red.
          <ls_category>-red_count = <ls_category>-red_count + 1.
        WHEN zif_ca_ops_types=>gc_rag-amber.
          <ls_category>-amber_count = <ls_category>-amber_count + 1.
        WHEN zif_ca_ops_types=>gc_rag-green.
          <ls_category>-green_count = <ls_category>-green_count + 1.
      ENDCASE.
    ENDLOOP.

    IF lv_weights = 0.
      rs_summary-overall_rag = zif_ca_ops_types=>gc_rag-grey.
      RETURN.
    ENDIF.

    " integer arithmetic rounds commercially to a whole score
    rs_summary-score = lv_weighted / lv_weights.
    rs_summary-overall_rag = COND #( WHEN rs_summary-score >= is_rules-green_min THEN zif_ca_ops_types=>gc_rag-green
                                     WHEN rs_summary-score >= is_rules-amber_min THEN zif_ca_ops_types=>gc_rag-amber
                                     ELSE zif_ca_ops_types=>gc_rag-red ).
    IF lv_red_high = abap_true.
      rs_summary-overall_rag = zif_ca_ops_types=>gc_rag-red.
    ELSEIF rs_summary-critical_count > 0.
      rs_summary-overall_rag = zcl_ca_ops_util=>worse_rag( iv_rag1 = rs_summary-overall_rag
                                                           iv_rag2 = zif_ca_ops_types=>gc_rag-amber ).
    ENDIF.
  ENDMETHOD.


  METHOD weight.
    rv_weight = SWITCH #( iv_priority
                          WHEN zif_cd_hck_types=>gc_priority-high THEN is_rules-weight_high
                          WHEN zif_cd_hck_types=>gc_priority-low  THEN is_rules-weight_low
                          ELSE is_rules-weight_medium ).
  ENDMETHOD.


  METHOD points.
    " grey (not evaluated) scores like red: unknown is not healthy
    rv_points = SWITCH #( iv_rag
                          WHEN zif_ca_ops_types=>gc_rag-green THEN is_rules-points_green
                          WHEN zif_ca_ops_types=>gc_rag-amber THEN is_rules-points_amber
                          ELSE is_rules-points_red ).
  ENDMETHOD.

ENDCLASS.
