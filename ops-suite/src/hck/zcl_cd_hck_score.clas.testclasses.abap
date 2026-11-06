*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_score.clas.testclasses.abap
*& Purpose:
*& Unit tests of the scorecard rules: health score 0-100, overall RAG,
*& RAG per category, critical/high counts; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*&---------------------------------------------------------------------*
CLASS ltc_score DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_green TYPE zif_cd_ops_types=>ty_rag VALUE 'G',
      gc_amber TYPE zif_cd_ops_types=>ty_rag VALUE 'A',
      gc_red   TYPE zif_cd_ops_types=>ty_rag VALUE 'R',
      gc_grey  TYPE zif_cd_ops_types=>ty_rag VALUE ' '.

    DATA mt_results TYPE zif_cd_hck_types=>tt_check_result.

    METHODS setup.
    METHODS all_green_scores_hundred FOR TESTING.
    METHODS red_high_forces_red FOR TESTING.
    METHODS score_weighted_by_priority FOR TESTING.
    METHODS category_takes_worst_rag FOR TESTING.
    METHODS no_results_grey_zero FOR TESTING.
    METHODS red_counts_critical FOR TESTING.

    METHODS add_result
      IMPORTING
        iv_check_id TYPE zif_cd_hck_types=>ty_check_id
        iv_category TYPE zif_cd_hck_types=>ty_category
        iv_priority TYPE zif_cd_hck_types=>ty_priority
        iv_rag      TYPE zif_cd_ops_types=>ty_rag.

    METHODS category_row
      IMPORTING
        iv_category   TYPE zif_cd_hck_types=>ty_category
        iv_rag        TYPE zif_cd_ops_types=>ty_rag
        iv_red        TYPE i DEFAULT 0
        iv_amber      TYPE i DEFAULT 0
        iv_green      TYPE i DEFAULT 0
      RETURNING
        VALUE(rs_row) TYPE zif_cd_hck_types=>ty_category_status.

    METHODS act
      RETURNING
        VALUE(rs_summary) TYPE zif_cd_hck_types=>ty_summary.

ENDCLASS.



CLASS ltc_score IMPLEMENTATION.

  METHOD setup.
    CLEAR mt_results.
  ENDMETHOD.


  METHOD add_result.
    DATA ls_result TYPE zif_cd_hck_types=>ty_check_result.
    ls_result-check_id = iv_check_id.
    ls_result-category = iv_category.
    ls_result-priority = iv_priority.
    ls_result-rag      = iv_rag.
    INSERT ls_result INTO TABLE mt_results.
  ENDMETHOD.


  METHOD category_row.
    rs_row-category    = iv_category.
    rs_row-rag         = iv_rag.
    rs_row-red_count   = iv_red.
    rs_row-amber_count = iv_amber.
    rs_row-green_count = iv_green.
    rs_row-check_count = iv_red + iv_amber + iv_green.
  ENDMETHOD.


  METHOD act.
    rs_summary = zcl_cd_hck_score=>summarize( it_results = mt_results
                                              is_rules   = zcl_cd_hck_score=>default_rules( ) ).
  ENDMETHOD.


  " Rule: only green checks give score 100 and overall GREEN
  METHOD all_green_scores_hundred.
    TRY.
        add_result( iv_check_id = 'A1' iv_category = 'A' iv_priority = 'H' iv_rag = gc_green ).
        add_result( iv_check_id = 'E1' iv_category = 'E' iv_priority = 'L' iv_rag = gc_green ).
        DATA(ls_summary) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_summary-score exp = 100 msg = 'All green must score 100' ).
        cl_abap_unit_assert=>assert_equals( act = ls_summary-overall_rag exp = gc_green msg = 'All green must be GREEN' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: one red high-priority check makes the day RED whatever the average
  METHOD red_high_forces_red.
    TRY.
        DO 9 TIMES.
          add_result( iv_check_id = CONV #( |G{ sy-index }| ) iv_category = 'B' iv_priority = 'L' iv_rag = gc_green ).
        ENDDO.
        add_result( iv_check_id = 'A_RED' iv_category = 'A' iv_priority = 'H' iv_rag = gc_red ).
        cl_abap_unit_assert=>assert_equals( act = act( )-overall_rag
                                            exp = gc_red
                                            msg = 'A red H check must force overall RED' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: score = sum(weight * points) / sum(weight); H=3, L=1, G=100, R=0
  METHOD score_weighted_by_priority.
    TRY.
        add_result( iv_check_id = 'A1' iv_category = 'A' iv_priority = 'H' iv_rag = gc_green ).
        add_result( iv_check_id = 'E1' iv_category = 'E' iv_priority = 'L' iv_rag = gc_red ).
        DATA(ls_summary) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_summary-score exp = 75 msg = '(3*100 + 1*0) / 4 must be 75' ).
        cl_abap_unit_assert=>assert_equals( act = ls_summary-overall_rag exp = gc_amber msg = 'Score 75 must be AMBER' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: category RAG is the worst check RAG; categories without checks stay grey
  METHOD category_takes_worst_rag.
    DATA lt_exp TYPE zif_cd_hck_types=>tt_category_status.
    TRY.
        add_result( iv_check_id = 'A1' iv_category = 'A' iv_priority = 'M' iv_rag = gc_green ).
        add_result( iv_check_id = 'A2' iv_category = 'A' iv_priority = 'M' iv_rag = gc_amber ).
        add_result( iv_check_id = 'C1' iv_category = 'C' iv_priority = 'M' iv_rag = gc_red ).
        INSERT category_row( iv_category = 'A' iv_rag = gc_amber iv_amber = 1 iv_green = 1 ) INTO TABLE lt_exp.
        INSERT category_row( iv_category = 'B' iv_rag = gc_grey ) INTO TABLE lt_exp.
        INSERT category_row( iv_category = 'C' iv_rag = gc_red iv_red = 1 ) INTO TABLE lt_exp.
        INSERT category_row( iv_category = 'D' iv_rag = gc_grey ) INTO TABLE lt_exp.
        INSERT category_row( iv_category = 'E' iv_rag = gc_grey ) INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = act( )-categories
                                            exp = lt_exp
                                            msg = 'Category table A-E must carry the worst RAG and counts' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: nothing measured is not healthy - score 0, overall grey
  METHOD no_results_grey_zero.
    TRY.
        DATA(ls_summary) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_summary-score exp = 0 msg = 'No results must score 0' ).
        cl_abap_unit_assert=>assert_equals( act = ls_summary-overall_rag exp = gc_grey msg = 'No results must be grey' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: critical = red checks, high = amber checks
  METHOD red_counts_critical.
    TRY.
        add_result( iv_check_id = 'A1' iv_category = 'A' iv_priority = 'M' iv_rag = gc_red ).
        add_result( iv_check_id = 'A2' iv_category = 'A' iv_priority = 'M' iv_rag = gc_red ).
        add_result( iv_check_id = 'B1' iv_category = 'B' iv_priority = 'M' iv_rag = gc_amber ).
        DATA(ls_summary) = act( ).
        cl_abap_unit_assert=>assert_equals( act = ls_summary-critical_count exp = 2 msg = 'Two red checks are critical' ).
        cl_abap_unit_assert=>assert_equals( act = ls_summary-high_count exp = 1 msg = 'One amber check is high' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
