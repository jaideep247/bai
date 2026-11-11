*&---------------------------------------------------------------------*
*& Artifact: zcl_ca_ops_mail_tpl_builtin.clas.abap
*& Purpose:
*& Built-in layout of the alert e-mail (the layout of the alert policy,
*& moved behind ZIF_CA_OPS_MAIL_TEMPLATE): the same content as the
*& framework's generic template ZCA_OPS_ALERT_DEFAULT - subject, run line,
*& run / job / exceptions app reference, the labelled business-context keys
*& that are known, then the consumer section and the findings table (as
*& their tokens, put in by ZCL_CA_OPS_MAIL_COMPOSER). Used when SAP e-mail
*& templates are switched off (ALERT_MAIL_RENDERER = BUILTIN) and as the
*& fallback whenever a template cannot be used. Every value is HTML-escaped;
*& labels are text symbols. Pure logic: no database, no delivery.
*& Modification log:
*& 2026-11-10 | Initial version (alert e-mail templates, user decisions 2026-11-10).
*& 2026-11-11 | Keys RUNBOOK_URL, FIRST_ACTION, CORRELATED_COUNT, ESCALATION shown when known (L16-L19).
*&---------------------------------------------------------------------*
"! <p class="shorttext synchronized">Operations framework - built-in alert e-mail layout</p>
CLASS zcl_ca_ops_mail_tpl_builtin DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.
    INTERFACES zif_ca_ops_mail_template.

  PRIVATE SECTION.
    "! Markup of the built-in layout - not text; words are text symbols / ZCA_OPS messages
    CONSTANTS:
      BEGIN OF gc_html,
        p_open       TYPE string VALUE `<p>`,
        p_close      TYPE string VALUE `</p>`,
        p_bold_open  TYPE string VALUE `<p><b>`,
        p_bold_close TYPE string VALUE `</b></p>`,
        table_open   TYPE string VALUE `<table cellpadding="2">`,
        table_close  TYPE string VALUE `</table>`,
        row_open     TYPE string VALUE `<tr><td><b>`,
        row_middle   TYPE string VALUE `</b></td><td>`,
        row_close    TYPE string VALUE `</td></tr>`,
      END OF gc_html.
    CONSTANTS gc_label_separator TYPE string VALUE `: `.

    TYPES:
      BEGIN OF ty_pair,
        label TYPE string,
        value TYPE string,
      END OF ty_pair.
    TYPES tt_pair TYPE STANDARD TABLE OF ty_pair WITH EMPTY KEY.

    "! The labelled context keys that are known (blank keys are left out)
    METHODS pairs
      IMPORTING
        is_header       TYPE zif_ca_ops_types=>ty_mail_header
      RETURNING
        VALUE(rt_pairs) TYPE tt_pair.

ENDCLASS.



CLASS zcl_ca_ops_mail_tpl_builtin IMPLEMENTATION.

  METHOD zif_ca_ops_mail_template~is_available.
    rv_available = abap_true.
  ENDMETHOD.


  METHOD zif_ca_ops_mail_template~exists.
    " the built-in layout needs no template
    rv_exists = abap_true.
  ENDMETHOD.


  METHOD zif_ca_ops_mail_template~render.
    DATA(ls_header) = is_context-header.
    DATA(lt_pairs) = pairs( ls_header ).
    DATA(lv_newline) = cl_abap_char_utilities=>newline.

    rs_rendered-subject = ls_header-subject.

    rs_rendered-html = gc_html-p_bold_open && zcl_ca_ops_util=>html_escape( ls_header-subject ) && gc_html-p_bold_close.
    IF ls_header-run_line IS NOT INITIAL.
      rs_rendered-html = rs_rendered-html
                      && gc_html-p_open && zcl_ca_ops_util=>html_escape( ls_header-run_line ) && gc_html-p_close.
    ENDIF.
    IF ls_header-reference_line IS NOT INITIAL.
      rs_rendered-html = rs_rendered-html
                      && gc_html-p_open && zcl_ca_ops_util=>html_escape( ls_header-reference_line ) && gc_html-p_close.
    ENDIF.
    IF lt_pairs IS NOT INITIAL.
      rs_rendered-html = rs_rendered-html && gc_html-table_open.
      LOOP AT lt_pairs ASSIGNING FIELD-SYMBOL(<ls_pair>).
        rs_rendered-html = rs_rendered-html && gc_html-row_open && zcl_ca_ops_util=>html_escape( <ls_pair>-label )
                        && gc_html-row_middle && zcl_ca_ops_util=>html_escape( <ls_pair>-value ) && gc_html-row_close.
      ENDLOOP.
      rs_rendered-html = rs_rendered-html && gc_html-table_close.
    ENDIF.
    " tables: the consumer section first, then the findings (tokens, replaced after rendering)
    rs_rendered-html = rs_rendered-html && condense( ls_header-table_section ) && condense( ls_header-table_main ).

    rs_rendered-text = ls_header-subject.
    IF ls_header-reference_line IS NOT INITIAL.
      rs_rendered-text = |{ rs_rendered-text }{ lv_newline }{ ls_header-reference_line }|.
    ENDIF.
    LOOP AT lt_pairs ASSIGNING <ls_pair>.
      rs_rendered-text = |{ rs_rendered-text }{ lv_newline }{ <ls_pair>-label }{ gc_label_separator }{ <ls_pair>-value }|.
    ENDLOOP.
    IF ls_header-table_section IS NOT INITIAL.
      rs_rendered-text = |{ rs_rendered-text }{ lv_newline }{ condense( ls_header-table_section ) }|.
    ENDIF.
    IF ls_header-table_main IS NOT INITIAL.
      rs_rendered-text = |{ rs_rendered-text }{ lv_newline }{ condense( ls_header-table_main ) }|.
    ENDIF.
  ENDMETHOD.


  METHOD pairs.
    DATA(lt_all) = VALUE tt_pair(
      ( label = TEXT-l01 value = condense( |{ is_header-area } { is_header-area_text }| ) )
      ( label = TEXT-l02 value = is_header-rule_id )
      ( label = TEXT-l03 value = condense( |{ is_header-severity } { is_header-severity_text }| ) )
      ( label = TEXT-l04 value = is_header-check_code )
      ( label = TEXT-l05 value = is_header-findings_total )
      ( label = TEXT-l06 value = is_header-findings_new )
      ( label = TEXT-l07 value = is_header-findings_repeated )
      ( label = TEXT-l08 value = is_header-findings_overdue )
      ( label = TEXT-l09 value = is_header-findings_held_back )
      ( label = TEXT-l10 value = is_header-due_date )
      ( label = TEXT-l11 value = is_header-owner )
      ( label = TEXT-l12 value = is_header-started_at )
      ( label = TEXT-l13 value = is_header-ended_at )
      ( label = TEXT-l14 value = is_header-amount_total )
      ( label = TEXT-l15 value = is_header-exceptions_link )
      " operations response features (2026-11-11): runbook, correlated exceptions, escalation step
      ( label = TEXT-l16 value = is_header-runbook_url )
      ( label = TEXT-l17 value = is_header-first_action )
      ( label = TEXT-l18 value = is_header-correlated_count )
      ( label = TEXT-l19 value = is_header-escalation ) ).
    LOOP AT lt_all ASSIGNING FIELD-SYMBOL(<ls_pair>).
      DATA(lv_value) = condense( <ls_pair>-value ).
      IF lv_value IS NOT INITIAL.
        INSERT VALUE #( label = condense( <ls_pair>-label ) value = lv_value ) INTO TABLE rt_pairs.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
