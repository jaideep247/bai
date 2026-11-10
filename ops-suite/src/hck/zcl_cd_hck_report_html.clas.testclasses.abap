*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_report_html.clas.testclasses.abap
*& Purpose:
*& Unit tests of the morning report renderer: HTML escaping, RAG chips,
*& empty sections and CSV quoting; does not prove live SAP runtime behavior.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Baseline warm-up chip (audit A102).
*& 2026-11-06 | Modern-syntax sweep: string templates.
*&---------------------------------------------------------------------*
CLASS ltc_report_html DEFINITION FINAL FOR TESTING
  RISK LEVEL HARMLESS
  DURATION SHORT.

  PRIVATE SECTION.
    CONSTANTS:
      gc_check       TYPE zif_cd_hck_types=>ty_check_id VALUE 'A_RET_AGED',
      gc_report_date TYPE d VALUE '20261105',
      gc_hostile     TYPE string VALUE `<script>alert(1)</script> & co`.

    DATA ms_report TYPE zif_cd_hck_types=>ty_report.

    METHODS setup.
    METHODS escapes_markup_in_values FOR TESTING.
    METHODS red_chip_label_and_colour FOR TESTING.
    METHODS green_chip_label_and_colour FOR TESTING.
    METHODS grey_chip_for_unknown_rag FOR TESTING.
    METHODS empty_exceptions_say_none FOR TESTING.
    METHODS category_row_has_chip FOR TESTING.
    METHODS warmup_check_shown_apart FOR TESTING.
    METHODS csv_quotes_and_neutralises FOR TESTING.

ENDCLASS.



CLASS ltc_report_html IMPLEMENTATION.

  METHOD setup.
    DATA ls_result TYPE zif_cd_hck_types=>ty_check_result.
    DATA ls_category TYPE zif_cd_hck_types=>ty_category_status.
    CLEAR ms_report.
    ms_report-report_date = gc_report_date.
    ms_report-score       = 75.
    ms_report-overall_rag = zif_ca_ops_types=>gc_rag-amber.
    ls_category-category    = zif_cd_hck_types=>gc_category-financial.
    ls_category-rag         = zif_ca_ops_types=>gc_rag-red.
    ls_category-check_count = 1.
    ls_category-red_count   = 1.
    INSERT ls_category INTO TABLE ms_report-categories.
    ls_result-check_id = gc_check.
    ls_result-category = zif_cd_hck_types=>gc_category-financial.
    ls_result-priority = zif_cd_hck_types=>gc_priority-high.
    ls_result-rag      = zif_ca_ops_types=>gc_rag-red.
    ls_result-summary  = gc_hostile.
    INSERT ls_result INTO TABLE ms_report-results.
  ENDMETHOD.


  " Rule: every value is HTML-escaped - customizing or data can never inject markup
  METHOD escapes_markup_in_values.
    TRY.
        DATA(lv_html) = zcl_cd_hck_report_html=>render( ms_report ).
        cl_abap_unit_assert=>assert_char_cp( act = lv_html
                                             exp = '*&lt;script&gt;alert(1)&lt;/script&gt; &amp; co*'
                                             msg = 'Hostile summary must appear escaped' ).
        cl_abap_unit_assert=>assert_equals( act = find( val = lv_html sub = `<script>` )
                                            exp = -1
                                            msg = 'Raw <script> must never appear' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: red chip = white bold label RED on #c62828
  METHOD red_chip_label_and_colour.
    TRY.
        cl_abap_unit_assert=>assert_equals(
          act = zcl_cd_hck_report_html=>rag_chip( zif_ca_ops_types=>gc_rag-red )
          exp = |<span style="display:inline-block;padding:2px 10px;border-radius:12px;font-size:12px;|
             && |font-weight:bold;color:#ffffff;background:#c62828;">RED</span>|
          msg = 'Red chip markup' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: green chip = label GREEN on #2e7d32
  METHOD green_chip_label_and_colour.
    TRY.
        " CP pattern: ## is a literal #
        cl_abap_unit_assert=>assert_char_cp( act = zcl_cd_hck_report_html=>rag_chip( zif_ca_ops_types=>gc_rag-green )
                                             exp = '*background:##2e7d32;">GREEN</span>'
                                             msg = 'Green chip markup' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: a missing RAG is shown as grey N/A, never as green
  METHOD grey_chip_for_unknown_rag.
    TRY.
        cl_abap_unit_assert=>assert_char_cp( act = zcl_cd_hck_report_html=>rag_chip( zif_ca_ops_types=>gc_rag-grey )
                                             exp = '*background:##6b7280;">N/A</span>'
                                             msg = 'Grey chip markup' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: an empty exception queue is stated explicitly
  METHOD empty_exceptions_say_none.
    TRY.
        cl_abap_unit_assert=>assert_char_cp( act = zcl_cd_hck_report_html=>render( ms_report )
                                             exp = '*No open exceptions*'
                                             msg = 'Empty queue must say so' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: each category row shows its business name and RAG chip
  METHOD category_row_has_chip.
    TRY.
        cl_abap_unit_assert=>assert_char_cp( act = zcl_cd_hck_report_html=>render( ms_report )
                                             exp = '*A - Financial integrity</td>*>RED</span>*'
                                             msg = 'Category A row must carry its name and red chip' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule (A102): a check in baseline warm-up carries its own grey WARM-UP chip, not N/A or GREEN
  METHOD warmup_check_shown_apart.
    TRY.
        ms_report-results[ 1 ]-rag    = zif_ca_ops_types=>gc_rag-grey.
        ms_report-results[ 1 ]-warmup = abap_true.
        DATA(lv_html) = zcl_cd_hck_report_html=>render( ms_report ).
        cl_abap_unit_assert=>assert_char_cp( act = lv_html
                                             exp = '*background:##6b7280;">WARM-UP</span>*'
                                             msg = 'Warm-up check must show a WARM-UP chip' ).
        cl_abap_unit_assert=>assert_equals( act = find( val = lv_html sub = `">N/A</span>` )
                                            exp = -1
                                            msg = 'Warm-up is not shown as N/A' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.


  " Rule: CSV fields are quoted, inner quotes doubled, formula starts neutralised
  METHOD csv_quotes_and_neutralises.
    DATA lt_exp TYPE string_table.
    TRY.
        ms_report-results[ 1 ]-summary = `=SUM(A1);"x"`.
        INSERT zcl_cd_hck_report_html=>csv_header( ) INTO TABLE lt_exp.
        INSERT `"20261105";"A_RET_AGED";"A";"H";"R";"0";"";"";"";"'=SUM(A1);""x"""` INTO TABLE lt_exp.
        cl_abap_unit_assert=>assert_equals( act = zcl_cd_hck_report_html=>render_csv( ms_report )
                                            exp = lt_exp
                                            msg = 'CSV lines must be quoted and formula-safe' ).
      CATCH cx_root INTO DATA(lx_error).
        cl_abap_unit_assert=>fail( msg = lx_error->get_text( ) ).
    ENDTRY.
  ENDMETHOD.

ENDCLASS.
