*&---------------------------------------------------------------------*
*& Artifact: zcl_cd_hck_report_html.clas.abap
*& Purpose:
*& Pure renderer of the morning report: mobile-friendly HTML e-mail with
*& inline CSS and RAG chips, and the CSV export lines. Every value escaped.
*& Modification log:
*& 2026-11-05 | Initial version (ops suite consolidation).
*& 2026-11-06 | Labels as class text symbols, sentences as ZCD_OPS messages, markup as constants.
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Health check - morning report renderer (HTML, CSV)</p>
"! No database, no SAP GUI: input is the report structure built by the
"! engine. Inline styles only (mail clients strip style blocks); single
"! column, max-width 760px, so it reads on a phone.
CLASS zcl_cd_hck_report_html DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    CLASS-METHODS render
      IMPORTING
        is_report      TYPE zif_cd_hck_types=>ty_report
      RETURNING
        VALUE(rv_html) TYPE string.

    CLASS-METHODS rag_chip
      IMPORTING
        iv_rag         TYPE zif_cd_ops_types=>ty_rag
      RETURNING
        VALUE(rv_html) TYPE string.

    CLASS-METHODS rag_text
      IMPORTING
        iv_rag         TYPE zif_cd_ops_types=>ty_rag
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Business name of a check category (A-E)
    CLASS-METHODS category_text
      IMPORTING
        iv_category    TYPE zif_cd_hck_types=>ty_category
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS subject
      IMPORTING
        is_report      TYPE zif_cd_hck_types=>ty_report
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS csv_header
      RETURNING
        VALUE(rv_line) TYPE string.

    "! One line per finding; a check without findings gets one line with its summary
    CLASS-METHODS render_csv
      IMPORTING
        is_report       TYPE zif_cd_hck_types=>ty_report
      RETURNING
        VALUE(rt_lines) TYPE string_table.

  PRIVATE SECTION.

    "! Markup of the e-mail (HTML / inline CSS for mail clients) - not text. Every word a
    "! reader sees is a text symbol of this class or a message of class ZCD_OPS.
    CONSTANTS:
      gc_td    TYPE string VALUE `<td style="padding:6px 8px;border-bottom:1px solid #e4e7eb;font-size:13px;">`,
      gc_th    TYPE string VALUE `<th style="padding:6px 8px;text-align:left;font-size:12px;color:#52606d;">`,
      gc_table TYPE string VALUE `<table role="presentation" width="100%" cellpadding="0" cellspacing="0">`,
      gc_h2    TYPE string VALUE `<h2 style="font-size:16px;margin:20px 0 6px 0;color:#1f2933;">`.
    CONSTANTS:
      BEGIN OF gc_html,
        page_open     TYPE string VALUE `<!DOCTYPE html><html><head><meta charset="utf-8">` &
                                        `<meta name="viewport" content="width=device-width, initial-scale=1"></head>` &
                                        `<body style="margin:0;padding:0;background:#f4f5f7;` &
                                        `font-family:Arial,Helvetica,sans-serif;color:#1f2933;">` &
                                        `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" ` &
                                        `style="max-width:760px;margin:0 auto;background:#ffffff;"><tr><td style="padding:16px;">`,
        page_close    TYPE string VALUE `</td></tr></table></body></html>`,
        h1_open       TYPE string VALUE `<h1 style="font-size:20px;margin:0 0 4px 0;">`,
        h1_close      TYPE string VALUE `</h1>`,
        h2_close      TYPE string VALUE `</h2>`,
        meta_open     TYPE string VALUE `<p style="margin:0;color:#52606d;font-size:13px;">`,
        legend_open   TYPE string VALUE `<p style="margin:20px 0 0 0;color:#7b8794;font-size:11px;">`,
        note_open     TYPE string VALUE `<p style="font-size:13px;margin:0;">`,
        p_close       TYPE string VALUE `</p>`,
        chip_open     TYPE string VALUE `<span style="display:inline-block;padding:2px 10px;border-radius:12px;font-size:12px;` &
                                        `font-weight:bold;color:#ffffff;background:`,
        attr_close    TYPE string VALUE `;">`,
        span_close    TYPE string VALUE `</span>`,
        score_open    TYPE string VALUE `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" ` &
                                        `style="margin-top:14px;"><tr><td style="padding:12px;background:#f8f9fb;border-radius:8px;">` &
                                        `<span style="font-size:34px;font-weight:bold;">`,
        unit_open     TYPE string VALUE `<span style="font-size:14px;color:#52606d;">`,
        two_spaces    TYPE string VALUE `&nbsp;&nbsp;`,
        counts_open   TYPE string VALUE `<div style="font-size:13px;margin-top:6px;">`,
        score_close   TYPE string VALUE `</div></td></tr></table>`,
        overdue_open  TYPE string VALUE `<span style="color:#c62828;font-weight:bold;">`,
        bold_open     TYPE string VALUE `<b>`,
        bold_close_br TYPE string VALUE `</b><br>`,
        tr_open       TYPE string VALUE `<tr>`,
        tr_close      TYPE string VALUE `</tr>`,
        td_close      TYPE string VALUE `</td>`,
        th_close      TYPE string VALUE `</th>`,
        table_close   TYPE string VALUE `</table>`,
      END OF gc_html,
      BEGIN OF gc_colour,
        red   TYPE string VALUE `#c62828`,
        amber TYPE string VALUE `#b26a00`,
        green TYPE string VALUE `#2e7d32`,
        grey  TYPE string VALUE `#6b7280`,
      END OF gc_colour.
    "! Machine-readable export: column names are an interface, not text
    CONSTANTS gc_csv_header TYPE string
      VALUE `REPORT_DATE;CHECK_ID;CATEGORY;PRIORITY;RAG;RUNTIME_MS;SEVERITY;CHECK_CODE;OBJECT_KEY;MESSAGE`.
    "! First characters a spreadsheet treats as a formula (CSV injection)
    CONSTANTS gc_csv_formula_start TYPE string VALUE `=+-@`.
    CONSTANTS gc_csv_number TYPE string VALUE `[-+]?[0-9]+(\.[0-9]+)?`.
    CONSTANTS gc_csv_separator TYPE string VALUE `;`.
    CONSTANTS gc_csv_quote TYPE string VALUE `"`.
    CONSTANTS gc_csv_quote_escaped TYPE string VALUE `""`.
    CONSTANTS gc_csv_text_prefix TYPE string VALUE `'`.

    CLASS-METHODS esc
      IMPORTING
        iv_text        TYPE any
      RETURNING
        VALUE(rv_text) TYPE string.

    CLASS-METHODS cell
      IMPORTING
        iv_html        TYPE string
      RETURNING
        VALUE(rv_html) TYPE string.

    CLASS-METHODS header_row
      IMPORTING
        it_titles      TYPE string_table
      RETURNING
        VALUE(rv_html) TYPE string.

    CLASS-METHODS section_scorecard
      IMPORTING
        is_report      TYPE zif_cd_hck_types=>ty_report
      RETURNING
        VALUE(rv_html) TYPE string.

    CLASS-METHODS section_pe_areas
      IMPORTING
        is_report      TYPE zif_cd_hck_types=>ty_report
      RETURNING
        VALUE(rv_html) TYPE string.

    CLASS-METHODS section_checks
      IMPORTING
        is_report      TYPE zif_cd_hck_types=>ty_report
      RETURNING
        VALUE(rv_html) TYPE string.

    CLASS-METHODS section_exceptions
      IMPORTING
        is_report      TYPE zif_cd_hck_types=>ty_report
      RETURNING
        VALUE(rv_html) TYPE string.

    CLASS-METHODS csv_field
      IMPORTING
        iv_value        TYPE any
      RETURNING
        VALUE(rv_field) TYPE string.

ENDCLASS.



CLASS zcl_cd_hck_report_html IMPLEMENTATION.

  METHOD render.
    rv_html = gc_html-page_open
           && gc_html-h1_open && esc( TEXT-001 ) && gc_html-h1_close
           && gc_html-meta_open
           && esc( zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-html_report_meta
                                          iv_v1    = |{ is_report-report_date DATE = ISO }|
                                          iv_v2    = is_report-run-created_by ) )
           && gc_html-p_close
           && section_scorecard( is_report )
           && section_pe_areas( is_report )
           && section_checks( is_report )
           && section_exceptions( is_report )
           && gc_html-legend_open && esc( TEXT-002 ) && ` ` && esc( TEXT-003 ) && gc_html-p_close
           && gc_html-page_close.
  ENDMETHOD.


  METHOD rag_chip.
    DATA(lv_colour) = SWITCH string( iv_rag
                                     WHEN zif_cd_ops_types=>gc_rag-red   THEN gc_colour-red
                                     WHEN zif_cd_ops_types=>gc_rag-amber THEN gc_colour-amber
                                     WHEN zif_cd_ops_types=>gc_rag-green THEN gc_colour-green
                                     ELSE gc_colour-grey ).
    rv_html = gc_html-chip_open && lv_colour && gc_html-attr_close && rag_text( iv_rag ) && gc_html-span_close.
  ENDMETHOD.


  METHOD rag_text.
    rv_text = SWITCH #( iv_rag
                        WHEN zif_cd_ops_types=>gc_rag-red   THEN TEXT-r01
                        WHEN zif_cd_ops_types=>gc_rag-amber THEN TEXT-r02
                        WHEN zif_cd_ops_types=>gc_rag-green THEN TEXT-r03
                        ELSE TEXT-r04 ).
  ENDMETHOD.


  METHOD category_text.
    rv_text = SWITCH #( iv_category
                        WHEN zif_cd_hck_types=>gc_category-financial  THEN TEXT-k01
                        WHEN zif_cd_hck_types=>gc_category-mass_run   THEN TEXT-k02
                        WHEN zif_cd_hck_types=>gc_category-exceptions THEN TEXT-k03
                        WHEN zif_cd_hck_types=>gc_category-config     THEN TEXT-k04
                        WHEN zif_cd_hck_types=>gc_category-technical  THEN TEXT-k05
                        ELSE TEXT-k06 ).
  ENDMETHOD.


  METHOD subject.
    rv_text = zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-mail_subject_1
                                     iv_v1    = |{ is_report-report_date DATE = ISO }|
                                     iv_v2    = rag_text( is_report-overall_rag )
                                     iv_v3    = is_report-score )
           && ` `
           && zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-mail_subject_2
                                     iv_v1    = is_report-critical_count
                                     iv_v2    = is_report-high_count ).
  ENDMETHOD.


  METHOD csv_header.
    rv_line = gc_csv_header.
  ENDMETHOD.


  METHOD render_csv.
    INSERT csv_header( ) INTO TABLE rt_lines.
    LOOP AT is_report-results INTO DATA(ls_result).
      DATA(lv_prefix) = csv_field( is_report-report_date ) && gc_csv_separator
                     && csv_field( ls_result-check_id ) && gc_csv_separator
                     && csv_field( ls_result-category ) && gc_csv_separator
                     && csv_field( ls_result-priority ) && gc_csv_separator
                     && csv_field( ls_result-rag ) && gc_csv_separator
                     && csv_field( ls_result-runtime_ms ) && gc_csv_separator.
      IF ls_result-findings IS INITIAL.
        INSERT lv_prefix && gc_csv_quote_escaped && gc_csv_separator
            && gc_csv_quote_escaped && gc_csv_separator
            && gc_csv_quote_escaped && gc_csv_separator
            && csv_field( ls_result-summary ) INTO TABLE rt_lines.
        CONTINUE.
      ENDIF.
      LOOP AT ls_result-findings INTO DATA(ls_finding).
        INSERT lv_prefix && csv_field( ls_finding-severity ) && gc_csv_separator
            && csv_field( ls_finding-check_code ) && gc_csv_separator
            && csv_field( ls_finding-object_key ) && gc_csv_separator
            && csv_field( ls_finding-message ) INTO TABLE rt_lines.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.


  METHOD esc.
    rv_text = zcl_cd_ops_util=>html_escape( |{ iv_text }| ).
  ENDMETHOD.


  METHOD cell.
    rv_html = gc_td && iv_html && gc_html-td_close.
  ENDMETHOD.


  METHOD header_row.
    rv_html = gc_html-tr_open.
    LOOP AT it_titles INTO DATA(lv_title).
      rv_html = rv_html && gc_th && esc( lv_title ) && gc_html-th_close.
    ENDLOOP.
    rv_html = rv_html && gc_html-tr_close.
  ENDMETHOD.


  METHOD section_scorecard.
    rv_html = gc_html-score_open && esc( is_report-score ) && gc_html-span_close
           && gc_html-unit_open && esc( TEXT-004 ) && gc_html-span_close && gc_html-two_spaces
           && rag_chip( is_report-overall_rag )
           && gc_html-counts_open
           && esc( zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-html_score_counts
                                          iv_v1    = is_report-critical_count
                                          iv_v2    = is_report-high_count ) )
           && gc_html-score_close
           && gc_h2 && esc( TEXT-005 ) && gc_html-h2_close && gc_table
           && header_row( VALUE #( ( CONV #( TEXT-c01 ) ) ( CONV #( TEXT-c02 ) ) ( CONV #( TEXT-c03 ) )
                                   ( CONV #( TEXT-c04 ) ) ( CONV #( TEXT-c05 ) ) ) ).
    LOOP AT is_report-categories INTO DATA(ls_category).
      rv_html = rv_html && gc_html-tr_open
             && cell( esc( |{ ls_category-category } - { category_text( ls_category-category ) }| ) )
             && cell( rag_chip( ls_category-rag ) )
             && cell( esc( ls_category-check_count ) )
             && cell( esc( ls_category-red_count ) )
             && cell( esc( ls_category-amber_count ) ) && gc_html-tr_close.
    ENDLOOP.
    rv_html = rv_html && gc_html-table_close.
  ENDMETHOD.


  METHOD section_pe_areas.
    IF is_report-pe_areas IS INITIAL.
      RETURN.
    ENDIF.
    rv_html = gc_h2 && esc( TEXT-006 ) && gc_html-h2_close && gc_table
           && header_row( VALUE #( ( CONV #( TEXT-c06 ) ) ( CONV #( TEXT-c07 ) ) ( CONV #( TEXT-c02 ) )
                                   ( CONV #( TEXT-c08 ) ) ( CONV #( TEXT-c09 ) ) ( CONV #( TEXT-c10 ) ) ) ).
    LOOP AT is_report-pe_areas INTO DATA(ls_pe_area).
      DATA(lv_age) = COND string( WHEN ls_pe_area-stale = abap_true
                                  THEN esc( zcl_cd_ops_util=>text( iv_msgno = zif_cd_hck_types=>gc_msg-stale_age
                                                                   iv_v1    = ls_pe_area-age_hours
                                                                   iv_v2    = ls_pe_area-max_age_hours ) )
                                  ELSE esc( ls_pe_area-age_hours ) ).
      rv_html = rv_html && gc_html-tr_open
             && cell( esc( ls_pe_area-pe_area ) )
             && cell( COND #( WHEN ls_pe_area-last_run_at IS INITIAL THEN esc( TEXT-011 )
                              ELSE esc( |{ ls_pe_area-last_run_at TIMESTAMP = ISO }| ) ) )
             && cell( rag_chip( COND #( WHEN ls_pe_area-stale = abap_true THEN zif_cd_ops_types=>gc_rag-red
                                        ELSE ls_pe_area-rag ) ) )
             && cell( esc( ls_pe_area-error_count ) )
             && cell( esc( ls_pe_area-warning_count ) )
             && cell( lv_age ) && gc_html-tr_close.
    ENDLOOP.
    rv_html = rv_html && gc_html-table_close.
  ENDMETHOD.


  METHOD section_checks.
    rv_html = gc_h2 && esc( TEXT-007 ) && gc_html-h2_close && gc_table
           && header_row( VALUE #( ( CONV #( TEXT-c11 ) ) ( CONV #( TEXT-c12 ) ) ( CONV #( TEXT-c13 ) )
                                   ( CONV #( TEXT-c02 ) ) ( CONV #( TEXT-c14 ) ) ) ).
    LOOP AT is_report-results INTO DATA(ls_result).
      rv_html = rv_html && gc_html-tr_open
             && cell( gc_html-bold_open && esc( ls_result-check_id ) && gc_html-bold_close_br
                      && esc( ls_result-description ) )
             && cell( esc( ls_result-category ) )
             && cell( esc( ls_result-priority ) )
             && cell( rag_chip( ls_result-rag ) )
             && cell( esc( ls_result-summary ) ) && gc_html-tr_close.
    ENDLOOP.
    IF is_report-results IS INITIAL.
      rv_html = rv_html && gc_html-tr_open && cell( esc( TEXT-010 ) ) && gc_html-tr_close.
    ENDIF.
    rv_html = rv_html && gc_html-table_close.
  ENDMETHOD.


  METHOD section_exceptions.
    rv_html = gc_h2 && esc( TEXT-008 ) && gc_html-h2_close.
    IF is_report-exceptions IS INITIAL.
      rv_html = rv_html && gc_html-note_open && esc( TEXT-009 ) && gc_html-p_close.
      RETURN.
    ENDIF.
    rv_html = rv_html && gc_table
           && header_row( VALUE #( ( CONV #( TEXT-c06 ) ) ( CONV #( TEXT-c15 ) ) ( CONV #( TEXT-c16 ) )
                                   ( CONV #( TEXT-c17 ) ) ( CONV #( TEXT-c18 ) ) ( CONV #( TEXT-c19 ) )
                                   ( CONV #( TEXT-c20 ) ) ) ).
    LOOP AT is_report-exceptions INTO DATA(ls_exception).
      DATA(lv_due) = esc( |{ ls_exception-due_date DATE = ISO }| ).
      IF ls_exception-overdue_days > 0.
        lv_due = |{ gc_html-overdue_open }{ lv_due } (+{ esc( ls_exception-overdue_days ) }){ gc_html-span_close }|.
      ENDIF.
      rv_html = rv_html && gc_html-tr_open
             && cell( esc( ls_exception-pe_area ) )
             && cell( esc( ls_exception-check_code ) )
             && cell( esc( ls_exception-object_key ) )
             && cell( esc( ls_exception-message ) )
             && cell( esc( ls_exception-owner ) )
             && cell( lv_due )
             && cell( esc( ls_exception-age_days ) ) && gc_html-tr_close.
    ENDLOOP.
    rv_html = rv_html && gc_html-table_close.
  ENDMETHOD.


  METHOD csv_field.
    DATA(lv_text) = condense( val = |{ iv_value }| del = ` ` ).
    " neutralise spreadsheet formulas (CSV injection)
    IF lv_text IS NOT INITIAL
       AND find_any_of( val = substring( val = lv_text len = 1 ) sub = gc_csv_formula_start ) = 0
       AND NOT matches( val = lv_text pcre = gc_csv_number ).
      lv_text = gc_csv_text_prefix && lv_text.
    ENDIF.
    rv_field = gc_csv_quote && replace( val = lv_text sub = gc_csv_quote with = gc_csv_quote_escaped occ = 0 )
            && gc_csv_quote.
  ENDMETHOD.

ENDCLASS.
